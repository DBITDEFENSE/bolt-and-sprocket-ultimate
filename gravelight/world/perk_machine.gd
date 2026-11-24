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
	ArtCollider.fit(self, self, _body)   # T-188: hulls of the cabinet's art, not the 2.4 m box over its rounded top
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
	return "Hold [%s] to drink %s [%s]" % [prompt_key(&"interact"), PerkManager.display_name(perk_id), price_str(player, PerkManager.price(perk_id))]


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
			return "Hold [%s] to brew %s [%s]\n%s" % [prompt_key(&"interact"), nm, price_str(player, PerkManager.tier_price_for(pid, perk_id, next)) + (" · discount token" if PerkManager.has_discount_token(pid) else ""),
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
	_cab_dispense()
	_ledger_drawer()
	if perk_id == PerkManager.OVERCLOCK and AudioDirector.has_sound("perk_overclock_capoff"):
		# the signature cap-off: a capacitor whine, a fat ZAP and the two-tone bee-boop (JINGLES.md section 10)
		get_tree().create_timer(1.1).timeout.connect(func() -> void:
			AudioDirector.play_3d("perk_overclock_capoff", global_position + Vector3.UP * 1.2, -2.0, 0.03))
	get_tree().create_timer(float(GLData.table("perks").get("drink_seconds", 1.2))).timeout.connect(func() -> void:
		_drinking = false
		PerkManager.grant(pid, perk_id))


## T-127: a tonic for a companion (Jakub), paid from `payer_pid`'s Scrip at the normal price: the same checks for
## him (cap, owned, power), the same drink beat and jingle, then PerkManager.grant to him. Returns &"ok" or why not
## (&"owned", &"cap", &"no_power", &"gone", &"busy", &"no_scrip"); a refusal changes nothing.
func sell_to_companion(companion: Player, payer_pid: int) -> StringName:
	if companion == null or not companion.is_companion:
		return &"gone"
	if _gone or _drinking:
		return &"busy"
	var cid: int = companion.player_id
	var st: StringName = PerkManager.can_buy(cid, perk_id)
	if st != &"ok":
		return st
	if not Economy.spend(payer_pid, perk_id, PerkManager.price(perk_id)):
		return &"no_scrip"
	AudioDirector.play_3d("buy", global_position, -4.0)
	Net.sfx_all("buy", global_position, -4.0)
	_drinking = true
	_play_jingle()
	_cab_dispense()
	get_tree().create_timer(float(GLData.table("perks").get("drink_seconds", 1.2))).timeout.connect(func() -> void:
		_drinking = false
		PerkManager.grant(cid, perk_id))
	return &"ok"


## The next tier of a tonic the player carries: pay, the same drink beat and jingle, then PerkManager.set_tier.
func _brew_tier(player: Player) -> void:
	var pid: int = player.player_id
	var next: int = PerkManager.tier_of(pid, perk_id) + 1
	if not try_purchase(player, StringName("%s_t%d" % [perk_id, next]), PerkManager.tier_price_for(pid, perk_id, next)):
		GLBus.perk_denied.emit(pid, perk_id, &"no_scrip")
		return
	PerkManager.use_discount_token(pid)   # UPDATE 10 (T-156): the wing walk's token, spent with the tier
	_drinking = true
	_play_jingle()
	_cab_dispense()
	_ledger_drawer()
	get_tree().create_timer(float(GLData.table("perks").get("drink_seconds", 1.2))).timeout.connect(func() -> void:
		_drinking = false
		PerkManager.set_tier(pid, perk_id, next)
		if next >= PerkManager.permanent_tier():
			_tier4_flourish()
			Net.mirror(self, &"_tier4_flourish"))


## U08 (T-129): a tonic made permanent: the tier IV sting over the jingle, a gold light that swells and fades
## round the cabinet, and the cabinet's punch (every peer).
func _tier4_flourish() -> void:
	_gild_register()
	AudioDirector.play_3d("perk_tier4_sting", global_position + Vector3.UP * 1.6, 0.0, 0.0)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.35)
	glow.omni_range = 5.0
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	glow.position = Vector3(0, 1.8, -0.6)
	add_child(glow)
	var tw: Tween = create_tween()
	tw.tween_property(glow, "light_energy", 6.0, 0.25)
	tw.tween_property(glow, "light_energy", 0.0, 1.4)
	tw.tween_callback(glow.queue_free)
	var base: Vector3 = scale
	var punch: Tween = create_tween()
	punch.tween_property(self, "scale", base * 1.04, 0.08)
	punch.tween_property(self, "scale", base, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- power / retire

func _refresh_power() -> void:
	if _panel_mat == null:
		return
	var on: bool = is_powered() and not _gone
	var c: Color = _neon()
	_panel_mat.emission = c if on else Color(0.35, 0.15, 0.55)
	_panel_mat.emission_energy_multiplier = 2.5 if on else 0.22
	if _sign != null:
		# T-247 (the owner: "bright ... boxed labels over perk machines"): the name is paint on the board, lit by the
		# machine's own glow when the power is on; never an HDR colour of its own any more
		_sign.modulate = SurfaceText.tone(Color(c.lightened(0.45), 1.0) if on else Color(0.3, 0.25, 0.35, 0.8))
	if _cab_neon != null:
		_cab_refresh(on, c)
		return
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
		"glider": return Vector3(0.8, 2.4, 0.7)   # Skyhook Sekt (T-105): a glider fuselage on its tail
		"bandit": return Vector3(0.9, 2.3, 0.65)  # Magpie Mead (T-105): the Allied-painted cabinet with the bandit lever
		"register": return Vector3(1.0, 2.2, 0.75)   # Ledger Lager (T-141): the brass cash register with the tally drum
		"rocket": return Vector3(1.0, 2.1, 0.9)   # Rocket Man (T-276): a rocket on its fins, under the dugout's 2.2 m ceiling
	return Vector3(1.0, 2.0, 0.7)


## The cabinet (UPDATE_05 section 5, T-094): the tonic's own model (WorldArt "perk_<id>", built by
## tools_src/blender/world/perk_cabinets.py) with its PerkCap medallion and stamp-lettered name on the sign, its
## bottle, its idle motion; the procedural one when the model isn't there.
func build_greybox() -> void:
	if not _build_cabinet():
		_build_procedural()


func _build_procedural() -> void:
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
	# (T-247: the tube round the name board glows soft, glow_soft 1.4, not the full neon 4.5 that bloomed into a white box)
	_lit = InteractableArt.place(_greybox, "perk_lit_" + String(perk_id),
		func(r: Node3D) -> void: InteractableArt.perk_tubes(r, shape, fp, "glow_soft:" + InteractableArt.hex(neon)), Vector3.ZERO, false)
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
		"glider":
			# Skyhook Sekt: the two-blade propeller on the nose, ticking round a quarter turn now and then, spinning
			# when someone near it jumps (T-105)
			_anim = Node3D.new()
			_anim.position = Vector3(0, 2.52, -fp.z * 0.5 - 0.02)
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_glider_prop", func(r: Node3D) -> void: InteractableArt.glider_prop(r), Vector3.ZERO, false)
			GLBus.player_jumped.connect(_on_player_jumped)
		"bandit":
			# Magpie Mead: the one-armed-bandit lever (pulled on dispense) and the three reels in the window
			_anim = Node3D.new()
			_anim.position = Vector3(fp.x * 0.5 + 0.06, 1.3, -fp.z * 0.25)
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_bandit_lever", func(r: Node3D) -> void: InteractableArt.bandit_lever(r), Vector3.ZERO, false)
			_needle = Node3D.new()
			_needle.position = (lay["win"] as Vector3) + Vector3(0, 0, 0.06)
			_greybox.add_child(_needle)
			InteractableArt.place(_needle, "perk_bandit_reels", func(r: Node3D) -> void: InteractableArt.bandit_reels(r), Vector3.ZERO, false)
			GLBus.perk_bought.connect(func(_pid: int, pk: StringName) -> void:
				if pk == perk_id:
					_reel_spin = 2.5)
		"register":
			# Ledger Lager: the tally drum on the posts (turns a digit for every Scrip its holder earns, even unpowered),
			# a card ZAHLTAG in the paper-roll window; a gold drum once a tier IV was brewed here
			_anim = Node3D.new()
			_anim.position = Vector3(0, 1.98, 0.0)
			_greybox.add_child(_anim)
			InteractableArt.place(_anim, "perk_register_drum", func(r: Node3D) -> void: InteractableArt.register_drum(r), Vector3.ZERO, false)
			var zt: Label3D = add_label(_greybox, "ZAHLTAG", (lay["win"] as Vector3) + Vector3(0, -0.12, -0.05), 12, Color(0.12, 0.08, 0.05, 1.0))
			zt.outline_size = 0
			GLBus.scrip_changed.connect(_on_scrip_tally)
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
			_arc_next = randf_range(1.5, 4.0)
			GLBus.overclock_burst.connect(_on_overclock_burst)
	_anim_shape = shape
	set_process(_anim != null)


## Idle motion (JINGLES.md): Second Wind's dome bottle turns, Hawkeye's periscope watches the nearest player,
## Packmule's tin sign swings, Blastproof's wheel gives a quarter turn now and then. Powered machines only
## (the sign swings regardless).
func _process(delta: float) -> void:
	if _cab_neon != null:
		if not _gone:
			_cab_idle(delta)
		return
	if _anim == null or _gone:
		return
	_anim_t += delta
	var on: bool = is_powered()
	match _anim_shape:
		"glider":
			_cab_next -= delta
			_tick_glider(delta, on)
			return
		"bandit":
			_cab_next -= delta
			_tick_bandit(delta, on)
			return
		"register":
			_tick_register(delta)
			return
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


var _prop_spin: float = 0.0      # Skyhook's propeller: rad/s, decays
var _reel_spin: float = 0.0      # Magpie's reels: seconds of spin left


## Skyhook Sekt: a jump within 6 m spins the propeller up (T-105).
func _on_player_jumped(_pid: int, at: Vector3) -> void:
	if at.distance_to(global_position) <= 6.0:
		_prop_spin = 18.0


func _tick_glider(delta: float, on: bool) -> void:
	if _anim == null:
		return
	_prop_spin = maxf(0.0, _prop_spin - 9.0 * delta)
	if on and _cab_next <= 0.0:
		_cab_next = randf_range(6.0, 10.0)
		_prop_spin = maxf(_prop_spin, 4.0)   # the idle quarter-turn tick
	_anim.rotation.z += (_prop_spin + (0.4 if on else 0.0)) * delta


## Ledger Lager (T-141): the drum turns a tenth of a turn (one digit plate) for every earning of the holder.
## It runs with the power off: it is the Ledger's own counter.
var _drum_target: float = 0.0

func _on_scrip_tally(pid: int, _total: int, delta: int) -> void:
	if delta > 0 and not Economy.moving and PerkManager.has_perk(pid, perk_id):
		_drum_target = minf(_drum_target + TAU / 10.0, TAU)
		var now: float = Time.get_ticks_msec() / 1000.0
		if now >= _tally_sfx_at and is_inside_tree() and AudioDirector.has_sound("perk_ledger_tally"):
			_tally_sfx_at = now + 0.18
			AudioDirector.play_3d("perk_ledger_tally", global_position + Vector3.UP * 1.9, -6.0)


var _tally_sfx_at: float = 0.0


## The cash drawer's bell when this machine pours (Ledger Lager only).
func _ledger_drawer() -> void:
	if perk_id == &"ledger_lager" and AudioDirector.has_sound("perk_ledger_drawer"):
		AudioDirector.play_3d("perk_ledger_drawer", global_position + Vector3.UP * 0.9, -2.0)


func _tick_register(delta: float) -> void:
	if _anim == null:
		return
	var step: float = minf(_drum_target, 14.0 * delta)
	_anim.rotation.x += step
	_drum_target -= step


## Ledger Lager IV brewed here: the drum's plates turn to gold (T-141).
func _gild_register() -> void:
	if _anim == null or _anim_shape != "register":
		return
	for c: Node in _anim.get_children():
		c.queue_free()
	InteractableArt.place(_anim, "perk_register_drum_gold", func(r: Node3D) -> void: InteractableArt.register_drum(r, true), Vector3.ZERO, false)


func _tick_bandit(delta: float, on: bool) -> void:
	if _anim != null:
		var pull: float = clampf(_reel_spin, 0.0, 1.0)
		_anim.rotation.x = -0.9 * pull
	if _needle != null and on:
		_reel_spin = maxf(0.0, _reel_spin - delta)
		if _reel_spin > 0.0 or _cab_next <= 0.0:
			if _cab_next <= 0.0:
				_cab_next = randf_range(4.0, 7.0)
			for c: Node in _needle.get_children():
				(c as Node3D).rotation.x += (6.0 if _reel_spin > 0.0 else 0.6) * delta


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
var _panel_side: int = 0


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
	plate.position = Vector3(0, 0.09, front_z)
	plate.rotation.y = PI   # Label3D faces +Z; the front is -Z
	SurfaceText.apply(plate, SurfaceText.PRINT)   # T-247: engraved brass, lit by the room, no outline
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
	_build_panel()
	# the maker's plate as something you can read (T-075): a thin box just in front of the machine's own, at its foot
	var plaque: LorePlaque = LorePlaque.new()
	plaque.name = "MakersPlatePlaque"
	plaque.lore_key = "perk." + String(perk_id)
	plaque.interact_size = Vector3(minf(0.8, fp.x), 0.34, 0.12)
	plaque.interact_offset = Vector3(0, 0.17, -(fp.z * 0.5 + 0.33))
	add_child(plaque)



## The fine-print panel: on the machine's back (side 0), or, where the machine stands with its back on a wall
## (a flush PerkSpot, T-255), on its local +X (1) or -X (-1) side.
func _build_panel() -> void:
	var old: Node = get_node_or_null("FinePrintPanel")
	if old != null:
		remove_child(old)
		old.queue_free()
	if FinePrintReader.lore(perk_id).is_empty():
		return
	var fp: Vector3 = _footprint
	var panel: FinePrintPanel = FinePrintPanel.new()
	panel.name = "FinePrintPanel"
	panel.perk_id = perk_id
	var barrel: bool = str(_data().get("shape", "cabinet")) == "barrel"
	# its -Z (reader side) points out of the machine: out of its back, or out of the side it hangs on
	var out: Vector3 = Vector3(0, 0, 1) if _panel_side == 0 else Vector3(float(_panel_side), 0, 0)
	var half: float = fp.z * 0.5 if _panel_side == 0 else fp.x * 0.5
	panel.width = fp.x if _panel_side == 0 else fp.z
	panel.position = out * (half + 0.03)
	if barrel:
		# 2026-11-12: a flat 0.62 m plate stood up to 0.18 m off the barrel's curve (the owner's "beige panel"): a
		# narrower plate sits on the staves (the barrel's widest band is 0.98 of its half-width)
		panel.width = 0.54
		panel.read_width = fp.x
		panel.position = out * (fp.x * 0.5 * 0.98 + 0.012)
	if _panel_side != 0:
		panel.read_width = maxf(0.3, (0.54 if barrel else fp.z) - 0.3)   # (short of the front corner, where the buy prompt's box is)
	panel.rotation.y = atan2(-out.x, -out.z)
	add_child(panel)


## T-255: PerkLayout tells the machine which way its spot leaves open for the fine print (see _build_panel).
func set_panel_side(side: int) -> void:
	side = clampi(side, -1, 1)
	if side == _panel_side:
		return
	_panel_side = side
	if is_inside_tree():
		_build_panel()


## The cabinet's depth (front to back), for PerkSpot.stand_transform.
func depth() -> float:
	return _footprint.z


## T-255: how far a flush PerkSpot stood this machine back from its own origin (PerkSpot.stand_offset). The bots'
## approach point is 1 m past interact_offset (BotBrain._front_of), and the navmesh in front of a spot is cut for the
## deepest machine: a 0.6 m cabinet stood 0.3 m back had its approach point on the very edge of the navmesh (0.03 to
## 0.16 m off it), and a bot sent there could stand a step short of it for good (smoke_bots_shop_m0: the companion
## 500 s at Second Wind on the stable's spot). So interact_offset is measured from the spot's front line, which puts
## the approach point where it is for a cabinet on the spot's origin. Only the property moves: the use box the
## player aims at (the Area built in _ready) stays on the cabinet's face.
func set_stand_back(back: float) -> void:
	interact_offset = Vector3(0, 1.0, -(_footprint.z * 0.5 + 0.12 + maxf(0.0, back)))


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



# ------------------------------------------------------------------ the cabinet model (UPDATE_05 section 5, T-094)

## Small lines under the stamp-lettered name (JINGLES.md): [text, x offset from the text centre, y offset].
const CAB_SUBLINES: Dictionary = {
	"ironhide_stout": ["Stout · Stark · Standhaft", 0.0, -0.105],
	"twin_barrel": ["Bitters", 0.0, -0.1],
	"overclock_cordial": ["Cordial", 0.0, -0.085],
	"skyhook_sekt": ["Leicht · Lieber · Landen", 0.0, -0.1],
	"magpie_mead": ["Nothing on this range goes to waste", 0.0, -0.1],
}
const CAP_PX: int = 256

var _cab: Node3D = null                 # the model (also _greybox, so a retiring Second Wind sinks it)
var _cab_neon: MeshInstance3D = null    # the tubes and the lamp globe: lit / dark
var _cab_parts: Dictionary = {}         # idle part name -> Node3D
var _cab_rest: Dictionary = {}          # idle part name -> its rest Transform3D
var _cab_dispense_node: Node3D = null
var _cab_cap: Sprite3D = null
var _cab_glow_mat: StandardMaterial3D = null   # Blastproof's starburst, Overclock's coil
var _cab_t: float = 0.0
var _cab_next: float = 2.0              # the next steam puff / pistol shot / rattle
var _cab_on: float = 0.0                # how long the current flash has left
var _cab_side: int = 0
var _cab_steam: CPUParticles3D = null


func _build_cabinet() -> bool:
	var art: Node3D = WorldArt.instance("perk_" + String(perk_id), "Greybox")
	if art == null:
		return false
	_cab = art
	_greybox = art
	add_child(art)
	var d: Dictionary = _data()
	var shape: String = str(d.get("shape", "cabinet"))
	var fp: Vector3 = _shape_footprint(shape)
	var brand: Color = _brand()
	var neon: Color = _neon()
	var lay: Dictionary = InteractableArt.perk_layout(shape, fp)
	_cab_neon = WorldArt.mesh_of(WorldArt.part(art, "Neon"))
	if _cab_neon != null:
		_cab_neon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panel_mat = greybox_mat(brand.darkened(0.3), 0.35)
	var back: MeshInstance3D = WorldArt.mesh_of(WorldArt.part(art, "Backlight"))
	if back != null:
		back.material_override = _panel_mat
		back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.name = "PerkGlow"
	_light.light_color = neon.lightened(0.25)
	_light.light_energy = 0.9
	_light.omni_range = 3.2
	_light.position = Vector3(0, minf(fp.y * 0.75, 1.6), -fp.z * 0.5 - 0.45)
	_light.visible = false
	art.add_child(_light)
	# the sign: the PerkCap medallion at the board's left end, the name in the stamp face beside it
	var sc: Vector3 = lay["sign"]
	var ss: Vector2 = lay["sign_size"]
	var cap_r: float = minf(0.115, ss.y * 0.5 - 0.03)
	var cap_anchor: Node3D = WorldArt.part(art, "CapAnchor")
	var cap_at: Vector3 = cap_anchor.position if cap_anchor != null else Vector3(sc.x + ss.x * 0.5 - cap_r - 0.05, sc.y, sc.z - 0.01)
	_cab_cap = _make_cap(cap_at, cap_r)
	var text: String = str(d.get("sign", d.get("name", perk_id)))
	# the cap is at the board's +X end (the viewer's left); the name fills the rest (Blastproof's starburst takes the
	# far end for "Bock")
	var left: float = sc.x - ss.x * 0.5 + 0.06 + (0.34 if shape == "safe" else 0.0)
	var text_w: float = sc.x + ss.x * 0.5 - cap_r * 2.0 - 0.12 - left
	var sub: Array = CAB_SUBLINES.get(String(perk_id), [])
	# as big as the board allows (readability first): the stamp face measured, capped by the board's height
	var stamp: Font = MenuKit.font("stamp")
	var w100: float = maxf(1.0, stamp.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x) * 0.004 / 100.0
	# the stamp face is wide: condense it (down to 72%) before shrinking it, so the name fills the board's height
	var fs_h: int = int(ss.y * (0.48 if not sub.is_empty() else 0.62) / 0.004)
	var cond: float = clampf(text_w * 0.96 / (w100 * float(fs_h)), 0.72, 1.0)
	var font: int = clampi(int(text_w * 0.96 / (w100 * cond)), 18, fs_h)
	var text_y: float = sc.y + (0.03 if not sub.is_empty() else 0.0)
	_sign = add_label(art, text, Vector3(left + text_w * 0.5, text_y, sc.z - 0.004), font)
	_sign.font = stamp
	_sign.scale.x = cond
	if not sub.is_empty():
		var sl: Label3D = add_label(art, str(sub[0]), Vector3(left + text_w * 0.5 + float(sub[1]), sc.y + float(sub[2]) + 0.03, sc.z - 0.006), 14,
			Color(neon.lightened(0.6), 1.0) * 1.3)
		sl.font = MenuKit.font("type")
	var price: Label3D = add_label(art, "%s  %d" % [d.get("name", perk_id), PerkManager.price(perk_id)], (lay["price"] as Vector3) + Vector3(0, 0, -0.035), 17, Color(1, 0.93, 0.75, 0.95))
	price.font = MenuKit.font("type")
	# the moving parts
	for pn: String in ["Arm", "Bellows", "Dome", "Paws", "PompL", "PompR", "FlashL", "FlashR", "Belt", "RollerL", "RollerR", "Head",
			"EyePlate", "Sign", "Gear", "Wheel", "Burst", "Arc", "Needle", "Coil"]:
		var p: Node3D = WorldArt.part(art, pn)
		if p != null:
			_cab_parts[pn] = p
			_cab_rest[pn] = p.transform
	for fl: String in ["FlashL", "FlashR", "Arc"]:
		if _cab_parts.has(fl):
			(_cab_parts[fl] as Node3D).visible = false
	_cab_dispense_node = WorldArt.part(art, "Dispense")
	if _cab_dispense_node != null:
		_cab_dispense_node.visible = false
	for gn: String in ["Burst", "Coil"]:
		if _cab_parts.has(gn):
			_cab_glow_mat = StandardMaterial3D.new()
			_cab_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if gn == "Burst" else BaseMaterial3D.SHADING_MODE_PER_PIXEL
			_cab_glow_mat.albedo_color = Color(1.0, 0.78, 0.2) if gn == "Burst" else Color(0.35, 0.15, 0.5, 0.5)
			_cab_glow_mat.emission_enabled = true
			_cab_glow_mat.emission = Color(1.0, 0.7, 0.15) if gn == "Burst" else Color("#c07dff")
			if gn == "Coil":
				_cab_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_cab_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var gm: MeshInstance3D = WorldArt.mesh_of(_cab_parts[gn])
			if gm != null:
				gm.material_override = _cab_glow_mat
				gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match shape:
		"wagon":
			if _cab_parts.has("Sign"):
				var porter: Label3D = add_label(_cab_parts["Sign"], "Porter", Vector3(0, -0.18, -0.012), 16, Color(0.12, 0.1, 0.06, 1.0))
				porter.font = MenuKit.font("stamp")
				porter.outline_size = 0
		"safe":
			if _cab_parts.has("Burst"):
				var bock: Label3D = add_label(_cab_parts["Burst"], "Bock", Vector3(0, -0.01, -0.012), 22, Color(0.14, 0.06, 0.02, 1.0))
				bock.font = MenuKit.font("stamp")
				bock.outline_size = 0
		"coil":
			_anim = _cab_parts.get("Arc")
			_needle = _cab_parts.get("Needle")
			if _needle != null:
				_needle.rotation.z = NEEDLE_LEER
			var gz: float = -fp.z * 0.5 - 0.05
			for mark: Array in [["LEER", 0.21, 1.74], ["HALB", 0.0, 1.86], ["VOLL", -0.21, 1.74]]:   # viewer's left to right
				var ml: Label3D = add_label(art, str(mark[0]), Vector3(float(mark[1]), float(mark[2]), gz), 10, Color(0.12, 0.08, 0.05, 1.0))
				ml.outline_size = 0
			_arc_next = randf_range(1.5, 4.0)
			GLBus.overclock_burst.connect(_on_overclock_burst)
		"barrel":
			var sa: Node3D = WorldArt.part(art, "SteamAnchor")
			if sa != null:
				_cab_steam = _make_steam(sa.position)
				art.add_child(_cab_steam)
	_anim_shape = shape
	_cab_next = randf_range(1.0, 4.0)
	set_process(true)
	return true


## The tonic's bottle cap as the sign's medallion: PerkCap (the HUD's renderer, T-082) drawn once into a texture.
func _make_cap(at: Vector3, radius: float) -> Sprite3D:
	var vp: SubViewport = SubViewport.new()
	vp.name = "CapViewport"
	vp.size = Vector2i(CAP_PX, CAP_PX)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cap: PerkCap = PerkCap.new()
	cap.perk_id = perk_id
	cap.font = MenuKit.font("stamp")
	cap.position = Vector2.ZERO
	cap.size = Vector2(CAP_PX, CAP_PX)
	vp.add_child(cap)
	add_child(vp)
	var s: Sprite3D = Sprite3D.new()
	s.name = "PerkCapSign"
	s.texture = vp.get_texture()
	s.pixel_size = radius * 2.0 / float(CAP_PX) * 1.08
	s.shaded = false
	s.double_sided = false
	s.position = at
	s.rotation.y = PI   # Sprite3D faces +Z; the front is -Z
	s.set_meta("perk", perk_id)
	s.set_meta("glyph", PerkCap.has_glyph(perk_id))
	_cab.add_child(s)
	return s


func _make_steam(at: Vector3) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Steam"
	p.position = at
	p.emitting = false
	p.one_shot = true
	p.amount = 14
	p.lifetime = 1.4
	p.explosiveness = 0.7
	p.direction = Vector3(1, 0.6, 0)
	p.spread = 18.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, 0.35, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.85, 0.85, 0.88, 0.28)
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _cab_refresh(on: bool, c: Color) -> void:
	# T-247 (the owner: the "bright ... boxed labels over perk machines"): the tube round the name board glows soft
	# (glow_soft, 1.4) instead of the full neon (4.5) that bloomed into a white box in the dark
	_cab_neon.material_override = Mats.get_mat("glow_soft:" + InteractableArt.hex(c)) if on else Mats.get_mat("neon_off")
	_light.visible = on
	if _cab_cap != null:
		_cab_cap.modulate = Color(1.25, 1.25, 1.25) if on else Color(0.32, 0.3, 0.36)
	if _cab_glow_mat != null:
		_cab_glow_mat.emission_energy_multiplier = 0.0 if not on else (0.3 if _anim_shape == "safe" else 1.2)
	if not on:
		for pn: String in ["FlashL", "FlashR", "Arc"]:
			if _cab_parts.has(pn):
				(_cab_parts[pn] as Node3D).visible = false


## A purchase: the tonic's bottle drops into the hatch and is gone when the drink beat ends (drink_seconds).
func _cab_dispense() -> void:
	if _cab_dispense_node == null or not is_inside_tree():
		return
	var n: Node3D = _cab_dispense_node
	var home: Vector3 = n.position
	n.position = home + Vector3(0, 0.14, 0.06)
	n.visible = true
	var secs: float = float(GLData.table("perks").get("drink_seconds", 1.2))
	var tw: Tween = create_tween()
	tw.tween_property(n, "position", home, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, secs - 0.5))
	tw.tween_property(n, "position", home + Vector3(0, 0.05, -0.18), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		n.visible = false
		n.position = home)


func _cab_part(pn: String) -> Node3D:
	return _cab_parts.get(pn) as Node3D


## Idle motion per cabinet (JINGLES.md): powered machines only, except Packmule's swinging tin sign.
func _cab_idle(delta: float) -> void:
	_cab_t += delta
	var on: bool = is_powered()
	var t: float = _cab_t
	if _anim_shape == "wagon" and _cab_parts.has("Sign"):
		_cab_part("Sign").rotation.z = sin(t * 1.3) * 0.08
	if not on:
		if _anim_shape == "coil":
			_tick_coil(delta, false)
		return
	if _anim_shape != "coil" and _light != null:
		_light.light_energy = 0.9 * (0.9 + 0.1 * sin(t * 1.7))   # the lamp breathes
	_cab_next -= delta
	match _anim_shape:
		"glider":
			_tick_glider(delta, on)
		"bandit":
			_tick_bandit(delta, on)
		"barrel":
			# Fassl flexes, slow and proud; the side valve puffs every ~8 s
			var arm: Node3D = _cab_part("Arm")
			if arm != null:
				arm.transform = (_cab_rest["Arm"] as Transform3D) * Transform3D(Basis(Vector3.BACK, -0.45 * (0.5 - 0.5 * cos(t * 1.2))), Vector3.ZERO)
			if _cab_next <= 0.0:
				_cab_next = randf_range(7.0, 9.0)
				if _cab_steam != null:
					_cab_steam.restart()
		"cabinet":
			var dome: Node3D = _cab_part("Dome")
			if dome != null:
				dome.rotation.y += delta * 0.6
			# the bellows wheezes like slow breathing every 5 s
			var bel: Node3D = _cab_part("Bellows")
			if bel != null:
				var k: float = fmod(t, 5.0)
				var br: float = sin(clampf(k / 1.6, 0.0, 1.0) * PI)
				bel.transform = (_cab_rest["Bellows"] as Transform3D) * Transform3D(Basis.from_scale(Vector3(1.0, 1.0 - 0.3 * br, 1.0)), Vector3.ZERO)
		"crate":
			# Flitzi's paws blur on their cam; the sign letters flicker now and then
			var paws: Node3D = _cab_part("Paws")
			if paws != null:
				paws.transform = (_cab_rest["Paws"] as Transform3D) * Transform3D(Basis(Vector3.BACK, sin(t * 38.0) * 0.22), Vector3.ZERO)
			if _cab_next <= 0.0:
				_cab_next = randf_range(0.6, 1.6)
				_cab_on = 0.06
			if _sign != null and _cab_on > 0.0:
				_cab_on -= delta
				_sign.modulate.a = 0.35 if _cab_on > 0.0 else float(SurfaceText.MAX_ALPHA[SurfaceText.PAINT])
		"twin":
			# Pomp fires his pistols in turns: a kick and a cap-gun flash
			if _cab_next <= 0.0:
				_cab_next = randf_range(1.1, 1.8)
				_cab_side = 1 - _cab_side
				_cab_on = 0.18
			_cab_on = maxf(0.0, _cab_on - delta)
			for i: int in 2:
				var nm: String = "L" if i == 0 else "R"
				var arm2: Node3D = _cab_part("Pomp" + nm)
				var fl: Node3D = _cab_part("Flash" + nm)
				var firing: bool = i == _cab_side and _cab_on > 0.0
				if arm2 != null:
					arm2.transform = (_cab_rest["Pomp" + nm] as Transform3D) * Transform3D(Basis(Vector3.RIGHT, 0.35 * (_cab_on / 0.18) if firing else 0.0), Vector3.ZERO)
				if fl != null:
					fl.visible = firing and _cab_on > 0.11
		"teardrop":
			# the treadmill under the winged boot rolls on
			var belt: Node3D = _cab_part("Belt")
			if belt != null:
				belt.position = (_cab_rest["Belt"] as Transform3D).origin + Vector3(-fmod(t * 0.1, 0.025), 0, 0)
			for rn: String in ["RollerL", "RollerR"]:
				var r: Node3D = _cab_part(rn)
				if r != null:
					r.rotation.z += delta * 4.5
		"periscope":
			var head: Node3D = _cab_part("Head")
			if head != null:
				var pl: Node3D = get_tree().get_first_node_in_group(&"players") as Node3D
				if pl != null:
					var to: Vector3 = head.global_position - pl.global_position
					var want: float = atan2(to.x, to.z) - global_rotation.y
					head.rotation.y = lerp_angle(head.rotation.y, want, clampf(delta * 1.5, 0.0, 1.0))
			var eye: Node3D = _cab_part("EyePlate")
			if eye != null:
				eye.position = (_cab_rest["EyePlate"] as Transform3D).origin + Vector3(clampf(sin(t * 0.7) * 1.6, -1.0, 1.0) * 0.007, 0, 0)
		"wagon":
			# the gear on the rack rattles in short bursts
			var gear: Node3D = _cab_part("Gear")
			if gear != null:
				if _cab_next <= 0.0:
					_cab_next = randf_range(3.0, 6.0)
					_cab_on = 0.45
				_cab_on = maxf(0.0, _cab_on - delta)
				var j: Vector3 = Vector3(randf_range(-1, 1), absf(randf_range(-1, 1)), randf_range(-1, 1)) * 0.004 if _cab_on > 0.0 else Vector3.ZERO
				gear.position = (_cab_rest["Gear"] as Transform3D).origin + j
		"safe":
			var wheel: Node3D = _cab_part("Wheel")
			if wheel != null:
				var k2: float = fmod(t, 9.0)
				wheel.rotation.z = -floorf(t / 9.0) * PI * 0.5 - (smoothstep(8.4, 9.0, k2) * PI * 0.5)
			# the cartoon explosion sign flashes: a double blink every couple of seconds
			if _cab_glow_mat != null:
				var k3: float = fmod(t, 2.2)
				var lit: bool = k3 < 0.12 or (k3 > 0.24 and k3 < 0.36)
				_cab_glow_mat.emission_energy_multiplier = 3.0 if lit else 0.3
		"coil":
			_tick_coil(delta, true)
			if _cab_glow_mat != null:
				_cab_glow_mat.emission_energy_multiplier = (0.8 + 0.4 * sin(t * 2.3)) * (3.0 if _arc_on > 0.0 else 1.0)
