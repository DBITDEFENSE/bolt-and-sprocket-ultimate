class_name PerkMachine
extends Interactable
## A Helvetia Automaten AG tonic dispenser. Origin: floor center; local -Z is the front (faces the player).
## Procedural art per perk (InteractableArt, data/perks.json "shape"/"color", JINGLES.md); a "Visual" child replaces it.
## Buying spends Scrip immediately; the perk applies after a short drink beat.

@export var perk_id: StringName = &"ironhide_stout"

var _drinking: bool = false
var _gone: bool = false
var _body: StaticBody3D
var _greybox: Node3D
var _panel_mat: StandardMaterial3D
var _sign: Label3D
var _footprint: Vector3 = Vector3(1.0, 2.0, 0.7)
var _lit: MeshInstance3D          # neon tubes + lamp globe, lit
var _unlit: MeshInstance3D        # the same glass, dark
var _light: OmniLight3D
var _anim: Node3D                 # idle-motion part (dome bottle, periscope head, tin sign, safe wheel, coil arc)
var _anim_shape: String = ""
var _anim_t: float = 0.0
# Overclock Cordial (shape "coil"): the arc snaps every 3-7 s, the gauge needle rests at LEER and swings to VOLL
# when a burst lands within 6 m (JINGLES.md section 10, WEAPONS.md section 20.2).
const NEEDLE_LEER: float = -1.05   # +Z rotation points the needle to -X, the viewer's right; LEER is on the left
const NEEDLE_VOLL: float = 1.05
const GAUGE_RANGE: float = 6.0
var _needle: Node3D = null
var _needle_target: float = NEEDLE_LEER
var _needle_hold: float = 0.0
var _arc_next: float = 2.0
var _arc_on: float = 0.0


func _ready() -> void:
	_footprint = _shape_footprint(str(_data().get("shape", "cabinet")))
	interact_size = Vector3(_footprint.x + 0.3, 1.8, 0.25)
	interact_offset = Vector3(0, 1.0, -(_footprint.z * 0.5 + 0.12))
	super._ready()
	add_to_group(&"perk_machines")
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = _footprint
	cs.shape = box
	cs.position = Vector3(0, _footprint.y * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)
	GLBus.power_activated.connect(_refresh_power)
	_build_lore()
	if perk_id == &"second_wind":
		PerkManager.second_wind_retired.connect(_retire)
	_refresh_power()


func _data() -> Dictionary:
	return GLData.table("perks")["perks"].get(String(perk_id), {})


func _brand() -> Color:
	return Color(str(_data().get("color", "#d8b84a")))


## The neon / lamp colour: the brand colour unless perks.json gives a separate "neon" (Overclock's violet spark).
func _neon() -> Color:
	var d: Dictionary = _data()
	return Color(str(d.get("neon", d.get("color", "#d8b84a"))))


func is_powered() -> bool:
	return GameState.power_on or not PerkManager.needs_power(perk_id)


# ---------------------------------------------------------------- interaction

func get_prompt(player: Player) -> String:
	if _gone or _drinking:
		return ""
	match PerkManager.can_buy(player.player_id, perk_id):
		&"owned":
			return _upgrade_prompt(player)
		&"gone":
			return ""
		&"no_power":
			return "Power must be activated" + _plate_line()
		&"cap":
			return "You can only hold %d tonics" % PerkManager.cap_for(player.player_id) + _plate_line()
	return "Hold [%s] to drink %s [%d]" % [prompt_key(&"interact"), PerkManager.display_name(perk_id), PerkManager.price(perk_id)]


## The maker's plate one-liner under a prompt that has nothing to sell (MachineLore, PERKS_LORE.md).
func _plate_line() -> String:
	var line: String = MachineLore.plate(MachineLore.here(), "perk." + String(perk_id))
	return ("\n" + line) if line != "" else ""


## A tonic you already carry: its next tier (DECISIONS T-075), or why not yet.
func _upgrade_prompt(player: Player) -> String:
	var pid: int = player.player_id
	var next: int = PerkManager.tier_of(pid, perk_id) + 1
	var nm: String = PerkManager.tier_name(perk_id, next)
	match PerkManager.can_upgrade(pid, perk_id):
		&"ok":
			return "Hold [%s] to brew %s [%d]\n%s" % [prompt_key(&"interact"), nm, PerkManager.tier_price(perk_id, next),
				PerkManager.tier_data(perk_id, next).get("desc", "")]
		&"no_power":
			return "%s: power must be activated" % nm
		&"round":
			return "%s pours from round %d" % [nm, PerkManager.tier_min_round(next)]
		&"locked":
			return "%s locked · mastery %d / %d\nFight with %s in you to unlock it" % [nm, PerkManager.mastery(perk_id),
				PerkManager.mastery_needed(next), PerkManager.display_name(perk_id)]
	return ""


func can_interact(player: Player) -> bool:
	if _gone or _drinking:
		return false
	var st: StringName = PerkManager.can_buy(player.player_id, perk_id)
	return st == &"ok" or (st == &"owned" and PerkManager.can_upgrade(player.player_id, perk_id) == &"ok")


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if PerkManager.has_perk(player.player_id, perk_id):
		_brew_tier(player)
		return
	if not try_purchase(player, perk_id, PerkManager.price(perk_id)):
		GLBus.perk_denied.emit(player.player_id, perk_id, &"no_scrip")
		return
	_drinking = true
	var pid: int = player.player_id
	# The dispense sound is AudioDirector's (GLBus.purchase_made -> perk_dispense at this machine).
	_play_jingle()
	if perk_id == PerkManager.OVERCLOCK and AudioDirector.has_sound("perk_overclock_capoff"):
		# the signature cap-off: a capacitor whine, a fat ZAP and the two-tone bee-boop (JINGLES.md section 10)
		get_tree().create_timer(1.1).timeout.connect(func() -> void:
			AudioDirector.play_3d("perk_overclock_capoff", global_position + Vector3.UP * 1.2, -2.0, 0.03))
	get_tree().create_timer(float(GLData.table("perks").get("drink_seconds", 1.2))).timeout.connect(func() -> void:
		_drinking = false
		PerkManager.grant(pid, perk_id))


## The next tier of a tonic the player carries: pay, the same drink beat and jingle, then PerkManager.set_tier.
func _brew_tier(player: Player) -> void:
	var pid: int = player.player_id
	var next: int = PerkManager.tier_of(pid, perk_id) + 1
	if not try_purchase(player, StringName("%s_t%d" % [perk_id, next]), PerkManager.tier_price(perk_id, next)):
		GLBus.perk_denied.emit(pid, perk_id, &"no_scrip")
		return
	_drinking = true
	_play_jingle()
	get_tree().create_timer(float(GLData.table("perks").get("drink_seconds", 1.2))).timeout.connect(func() -> void:
		_drinking = false
		PerkManager.set_tier(pid, perk_id, next))


# ---------------------------------------------------------------- power / retire

func _refresh_power() -> void:
	if _panel_mat == null:
		return
	var on: bool = is_powered() and not _gone
	var c: Color = _neon()
	_panel_mat.emission = c if on else Color(0.35, 0.15, 0.55)
	_panel_mat.emission_energy_multiplier = 2.5 if on else 0.22
	if _sign != null:
		_sign.modulate = Color(c.lightened(0.55), 1.0) * 1.6 if on else Color(0.3, 0.25, 0.35, 0.8)
	if _lit != null:
		_lit.visible = on
		_unlit.visible = not on
		_light.visible = on


func _retire() -> void:
	_gone = true
	area.collision_layer = 0
	_body.collision_layer = 0
	_refresh_power()
	var target: Node3D = get_node_or_null("Visual") as Node3D
	if target == null:
		target = _greybox
	if target != null:
		var tw: Tween = create_tween()
		tw.tween_property(target, "position:y", -_footprint.y - 0.2, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(target.hide)


# ---------------------------------------------------------------- greybox

static func _shape_footprint(shape: String) -> Vector3:
	match shape:
		"barrel": return Vector3(1.2, 1.9, 1.2)
		"cabinet": return Vector3(0.8, 2.3, 0.6)
		"crate": return Vector3(1.0, 2.0, 0.65)
		"twin": return Vector3(1.2, 2.1, 0.6)
		"teardrop": return Vector3(1.0, 2.4, 0.9)
		"periscope": return Vector3(0.9, 1.8, 0.65)
		"wagon": return Vector3(1.7, 1.7, 0.85)
		"safe": return Vector3(1.1, 1.9, 0.95)
		"coil": return Vector3(0.8, 2.3, 0.6)   # Overclock Cordial: the cabinet footprint (Map 0 placement relies on it)
	return Vector3(1.0, 2.0, 0.7)


func build_greybox() -> void:
	_greybox = Node3D.new()
	_greybox.name = "Greybox"
	add_child(_greybox)
	var d: Dictionary = _data()
	var shape: String = str(d.get("shape", "cabinet"))
	var fp: Vector3 = _shape_footprint(shape)
	var brand: Color = _brand()
	var neon: Color = _neon()
	var lay: Dictionary = InteractableArt.perk_layout(shape, fp)
	# the dispenser (cached per perk), and its neon/lamp glass in a lit and an unlit set (shown by power state)
	InteractableArt.place(_greybox, "perk_body_" + String(perk_id),
		func(r: Node3D) -> void: InteractableArt.perk_body(r, shape, fp, brand))
	_lit = InteractableArt.place(_greybox, "perk_lit_" + String(perk_id),
		func(r: Node3D) -> void: InteractableArt.perk_tubes(r, shape, fp, "neon:" + InteractableArt.hex(neon)), Vector3.ZERO, false)
	_unlit = InteractableArt.place(_greybox, "perk_unlit_" + shape,
		func(r: Node3D) -> void: InteractableArt.perk_tubes(r, shape, fp, "neon_off"), Vector3.ZERO, false)
	# the backlight behind the bottles: faint Nachtglas violet unpowered, the brand colour when powered
	_panel_mat = greybox_mat(brand.darkened(0.3), 0.35)
	var wc: Vector3 = lay["win"]
	var ws: Vector2 = lay["win_size"]
	var panel: MeshInstance3D
	if bool(lay.get("round", false)):
		panel = _cyl(ws.x * 0.52, 0.02, wc + Vector3(0, 0, 0.13), _panel_mat)
		panel.rotation.x = PI * 0.5
	else:
		panel = add_box(_greybox, Vector3(ws.x * 0.98, ws.y * 0.98, 0.02), wc + Vector3(0, 0, 0.13), _panel_mat)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.name = "PerkGlow"
	_light.light_color = neon.lightened(0.25)
	_light.light_energy = 0.9
	_light.omni_range = 3.2
	_light.position = Vector3(0, minf(fp.y * 0.75, 1.6), -fp.z * 0.5 - 0.45)
	_light.visible = false
	_greybox.add_child(_light)
	# neon sign text (sized to the board) and the name/price plate
	var text: String = str(d.get("sign", d.get("name", perk_id)))
	var ss: Vector2 = lay["sign_size"]
	var font: int = clampi(int((ss.x - 0.14) / (maxf(1.0, float(text.length())) * 0.0026)), 22, 42)
	_sign = add_label(_greybox, text, lay["sign"], font)
	_sign.outline_modulate = Color(0, 0, 0, 0.9)
	add_label(_greybox, "%s  %d" % [d.get("name", perk_id), PerkManager.price(perk_id)], (lay["price"] as Vector3) + Vector3(0, 0, -0.035), 17, Color(1, 0.93, 0.75, 0.95))
	# moving parts
	match shape:
		"cabinet":
			_anim = Node3D.new()
			_anim.position = Vector3(0, 1.93, 0)
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_dome_bottle_" + String(perk_id), func(r: Node3D) -> void: InteractableArt.dome_bottle(r, brand))
		"periscope":
			_anim = Node3D.new()
			_anim.position = Vector3(0, 2.5, 0.12)
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_periscope_head", func(r: Node3D) -> void: InteractableArt.periscope_head(r))
		"wagon":
			_anim = Node3D.new()
			_anim.position = Vector3(-fp.x * 0.5 - 0.22, 1.29, -fp.z * 0.5 + 0.02)
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_porter_sign", func(r: Node3D) -> void: InteractableArt.porter_sign(r))
			var porter: Label3D = add_label(_anim, "Porter", Vector3(0, -0.18, -0.012), 16, Color(0.12, 0.1, 0.06, 1.0))
			porter.outline_size = 0
		"safe":
			_anim = Node3D.new()
			_anim.position = Vector3(0.24, 0.98, -fp.z * 0.5 - 0.09)
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_safe_wheel", func(r: Node3D) -> void: InteractableArt.safe_wheel(r))
		"coil":
			# the arc (shown for a flash every few seconds) at the coil's top turn
			_anim = Node3D.new()
			_anim.position = Vector3(0, 2.43, 0.05)
			_anim.visible = false
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_coil_arc", func(r: Node3D) -> void: InteractableArt.coil_arc(r), Vector3.ZERO, false)
			# the gauge needle on the dial above the porthole
			_needle = Node3D.new()
			_needle.position = Vector3(0, 1.62, -fp.z * 0.5 - 0.05)
			_needle.rotation.z = NEEDLE_LEER
			_greybox.add_child(_needle)
			InteractableArt.place(_needle, "perk_gauge_needle", func(r: Node3D) -> void: InteractableArt.gauge_needle(r), Vector3.ZERO, false)
			var gz: float = -fp.z * 0.5 - 0.05
			for mark: Array in [["LEER", 0.21, 1.74], ["HALB", 0.0, 1.86], ["VOLL", -0.21, 1.74]]:   # viewer's left to right
				var ml: Label3D = add_label(_greybox, str(mark[0]), Vector3(float(mark[1]), float(mark[2]), gz), 10, Color(0.12, 0.08, 0.05, 1.0))
				ml.outline_size = 0
			# "Cordial" in a smaller, friendlier line under the zigzag capitals
			var sub: Label3D = add_label(_greybox, "Cordial", (lay["sign"] as Vector3) + Vector3(0, -0.085, -0.01), 14, Color(neon.lightened(0.6), 1.0) * 1.3)
			sub.outline_modulate = Color(0, 0, 0, 0.9)
			_arc_next = randf_range(1.5, 4.0)
			GLBus.overclock_burst.connect(_on_overclock_burst)
	_anim_shape = shape
	set_process(_anim != null)


## Idle motion (JINGLES.md): Second Wind's dome bottle turns, Hawkeye's periscope watches the nearest player,
## Packmule's tin sign swings, Blastproof's wheel gives a quarter turn now and then. Powered machines only
## (the sign swings regardless).
func _process(delta: float) -> void:
	if _anim == null or _gone:
		return
	_anim_t += delta
	var on: bool = is_powered()
	match _anim_shape:
		"cabinet":
			if on:
				_anim.rotation.y += delta * 0.6
		"periscope":
			if on:
				var p: Node3D = get_tree().get_first_node_in_group(&"players") as Node3D
				if p != null:
					var to: Vector3 = _anim.global_position - p.global_position
					var want: float = atan2(to.x, to.z) - global_rotation.y
					_anim.rotation.y = lerp_angle(_anim.rotation.y, want, clampf(delta * 1.5, 0.0, 1.0))
		"wagon":
			_anim.rotation.z = sin(_anim_t * 1.3) * 0.08
		"safe":
			if on:
				var k: float = fmod(_anim_t, 9.0)
				_anim.rotation.z = -floorf(_anim_t / 9.0) * PI * 0.5 - (smoothstep(8.4, 9.0, k) * PI * 0.5)
		"coil":
			_tick_coil(delta, on)


## Overclock Cordial idle: the coil arcs on a randomized 3-7 s timer (a violet flash on the lamp light), the
## needle twitches near LEER and swings to VOLL for a moment after a nearby burst. Unpowered, nothing moves.
func _tick_coil(delta: float, on: bool) -> void:
	if not on:
		_anim.visible = false
		if _needle != null:
			_needle.rotation.z = NEEDLE_LEER
		return
	if _arc_on > 0.0:
		_arc_on -= delta
		if _arc_on <= 0.0:
			_anim.visible = false
			_light.light_energy = 0.9
		else:
			_anim.rotation.y = randf_range(-0.4, 0.4)
	else:
		_arc_next -= delta
		if _arc_next <= 0.0:
			_arc_next = randf_range(3.0, 7.0)
			_arc_on = randf_range(0.06, 0.14)
			_anim.visible = true
			_light.light_energy = 2.4
			if AudioDirector.has_sound("perk_overclock_arc"):
				AudioDirector.play_3d("perk_overclock_arc", global_position + Vector3.UP * 2.4, -10.0, 0.1)
	if _needle != null:
		if _needle_hold > 0.0:
			_needle_hold -= delta
			if _needle_hold <= 0.0:
				_needle_target = NEEDLE_LEER
		var jitter: float = sin(_anim_t * 11.0) * 0.03 + sin(_anim_t * 2.3) * 0.04
		var want: float = _needle_target + (jitter if _needle_target == NEEDLE_LEER else 0.0)
		_needle.rotation.z = lerpf(_needle.rotation.z, want, clampf(delta * (14.0 if _needle_hold > 0.0 else 3.0), 0.0, 1.0))


func _on_overclock_burst(_player: int, at: Vector3, spent: float, _radius: float) -> void:
	if _gone or not is_powered() or global_position.distance_to(at) > GAUGE_RANGE:
		return
	_needle_target = lerpf(NEEDLE_LEER, NEEDLE_VOLL, clampf(spent, 0.0, 1.0))
	_needle_hold = 1.2
	_arc_next = minf(_arc_next, 0.2)


## The machine's jingle, if its key exists in audio.json ("jingle_<perk_id>"). Played at the cabinet on the
## Jingles bus after a purchase. Overclock's ends on the cracked F-sharp until the profile holds fp_ch5_done,
## then the resolved pressing plays (JINGLES.md section 10).
func _play_jingle() -> void:
	var key: String = "jingle_" + String(perk_id)
	if _fine_print_done() and AudioDirector.has_sound(key + "_resolved"):
		key += "_resolved"
	if AudioDirector.has_sound(key):
		AudioDirector.play_3d(key, global_position + Vector3.UP * 1.6, 0.0, 0.0)


func _cyl(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	_greybox.add_child(mi)
	return mi


# ------------------------------------------------------------------ T&C section 11.2: plate, stencil, back panel

const STENCIL_COLOR: Color = Color("#c07dff")
const STENCIL_RANGE: float = 8.0
const STENCIL_CONE_DEG: float = 30.0      # half of the 60-degree flash cone
const STENCIL_HOLD: float = 1.2
const STENCIL_FADE: float = 0.4

var _stencil: Label3D = null
var _stencil_t: float = 0.0
var _stencil_always: bool = false


## Maker's plate (front), the plan-ID stencil under the enamel (front, low), and the fine-print panel (back).
func _build_lore() -> void:
	var lo: Dictionary = FinePrintReader.lore(perk_id)
	if lo.is_empty():
		return
	var fp: Vector3 = _footprint
	var front_z: float = -(fp.z * 0.5) - 0.02
	var plate: Label3D = Label3D.new()
	plate.name = "MakersPlate"
	var human: String = str(lo.get("human", ""))
	if human.to_lower().begins_with("no human"):
		# Overclock: the only Plan with no human behind the formula. The plate says so, in Vendelin's words.
		plate.text = "HELVETIA AUTOMATEN AG · BASEL\nPrototyp · Rezeptur: ein Freund"
	else:
		plate.text = "HELVETIA AUTOMATEN AG · BASEL\nRezeptur: %s" % _short_human(human)
	plate.font_size = 20
	plate.pixel_size = 0.0018
	plate.modulate = Color(0.85, 0.72, 0.42)
	plate.outline_size = 4
	plate.outline_modulate = Color(0.1, 0.07, 0.03)
	plate.position = Vector3(0, 0.09, front_z)
	plate.rotation.y = PI   # Label3D faces +Z; the front is -Z
	add_child(plate)
	_stencil = Label3D.new()
	_stencil.name = "PlanStencil"
	_stencil.text = "%s · %s" % [lo.get("plan_id", ""), str(lo.get("plan_name", "")).split(" (")[0]]
	_stencil.font_size = 26
	_stencil.pixel_size = 0.0016
	_stencil.modulate = Color(STENCIL_COLOR, 0.0)
	_stencil.outline_size = 0
	_stencil.position = Vector3(0, 0.25, front_z - 0.004)
	_stencil.rotation.y = PI
	if perk_id == PerkManager.OVERCLOCK:
		_stencil.rotation.z = 0.07   # stenciled in haste on the night of 17-18 March 1945: slightly crooked
	add_child(_stencil)
	_stencil_always = _fine_print_done()
	if _stencil_always:
		_stencil.modulate.a = 0.55
	else:
		GLBus.weapon_fired.connect(_on_weapon_fired)
	var panel: FinePrintPanel = FinePrintPanel.new()
	panel.name = "FinePrintPanel"
	panel.perk_id = perk_id
	panel.width = fp.x
	panel.position = Vector3(0, 0, fp.z * 0.5 + 0.03)
	panel.rotation.y = PI   # its -Z (reader side) points out of the machine's back
	add_child(panel)
	# the maker's plate as something you can read (T-075): a thin box just in front of the machine's own, at its foot
	var plaque: LorePlaque = LorePlaque.new()
	plaque.name = "MakersPlatePlaque"
	plaque.lore_key = "perk." + String(perk_id)
	plaque.interact_size = Vector3(minf(0.8, fp.x), 0.34, 0.12)
	plaque.interact_offset = Vector3(0, 0.17, -(fp.z * 0.5 + 0.33))
	add_child(plaque)



static func _short_human(h: String) -> String:
	h = h.split(" (")[0].split(",")[0].strip_edges().trim_suffix(".")
	return h.substr(0, 1).to_upper() + h.substr(1)


## The Fine Print completed (the shared T&C profile holds the unlock).
static func _fine_print_done() -> bool:
	var sp: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/SaveProfile") if Engine.get_main_loop() is SceneTree else null
	if sp == null:
		return false
	var doc: Dictionary = sp.get("doc")
	return (doc.get("unlocks", []) as Array).has("fp_ch5_done")


func _on_weapon_fired(_pid: int, _weapon: StringName, upgraded: bool, origin: Vector3, dir: Vector3) -> void:
	if not upgraded or _stencil == null:
		return
	var to: Vector3 = _stencil.global_position - origin
	if to.length() > STENCIL_RANGE or to.length() < 0.01:
		return
	if rad_to_deg(dir.angle_to(to)) > STENCIL_CONE_DEG:
		return
	var first: bool = _stencil_t <= 0.0 and _stencil.modulate.a <= 0.01
	_stencil_t = STENCIL_HOLD + STENCIL_FADE
	if first:
		GLBus.intel_found.emit(StringName("plan." + String(perk_id)))
		var key: String = "stencil_hint_shown"
		if not bool(ProfileSave.profile.get(key, false)):
			ProfileSave.profile[key] = true
			var hud: Node = get_tree().get_first_node_in_group(&"hud")
			if hud != null:
				hud.call("show_banner", "A stencil under the enamel.", 2.2)


func _physics_process(delta: float) -> void:
	if _stencil == null or _stencil_always or _stencil_t <= 0.0:
		return
	_stencil_t -= delta
	_stencil.modulate.a = clampf(_stencil_t / STENCIL_FADE, 0.0, 1.0) * 0.9

