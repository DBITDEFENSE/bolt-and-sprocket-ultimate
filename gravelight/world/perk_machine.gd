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
var _anim: Node3D                 # idle-motion part (dome bottle, periscope head, tin sign, safe wheel)
var _anim_shape: String = ""
var _anim_t: float = 0.0


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


func is_powered() -> bool:
	return GameState.power_on or not PerkManager.needs_power(perk_id)


# ---------------------------------------------------------------- interaction

func get_prompt(player: Player) -> String:
	if _gone or _drinking:
		return ""
	match PerkManager.can_buy(player.player_id, perk_id):
		&"owned", &"gone":
			return ""
		&"no_power":
			return "Power must be activated"
		&"cap":
			return "You can only hold %d tonics" % PerkManager.cap_for(player.player_id)
	return "Hold [%s] to drink %s [%d]" % [prompt_key(&"interact"), PerkManager.display_name(perk_id), PerkManager.price(perk_id)]


func can_interact(player: Player) -> bool:
	return not _gone and not _drinking and PerkManager.can_buy(player.player_id, perk_id) == &"ok"


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if not try_purchase(player, perk_id, PerkManager.price(perk_id)):
		GLBus.perk_denied.emit(player.player_id, perk_id, &"no_scrip")
		return
	_drinking = true
	var pid: int = player.player_id
	# The dispense sound is AudioDirector's (GLBus.purchase_made -> perk_dispense at this machine).
	get_tree().create_timer(float(GLData.table("perks").get("drink_seconds", 1.2))).timeout.connect(func() -> void:
		_drinking = false
		PerkManager.grant(pid, perk_id))


# ---------------------------------------------------------------- power / retire

func _refresh_power() -> void:
	if _panel_mat == null:
		return
	var on: bool = is_powered() and not _gone
	var c: Color = _brand()
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
	return Vector3(1.0, 2.0, 0.7)


func build_greybox() -> void:
	_greybox = Node3D.new()
	_greybox.name = "Greybox"
	add_child(_greybox)
	var d: Dictionary = _data()
	var shape: String = str(d.get("shape", "cabinet"))
	var fp: Vector3 = _shape_footprint(shape)
	var brand: Color = _brand()
	var lay: Dictionary = InteractableArt.perk_layout(shape, fp)
	# the dispenser (cached per perk), and its neon/lamp glass in a lit and an unlit set (shown by power state)
	InteractableArt.place(_greybox, "perk_body_" + String(perk_id),
		func(r: Node3D) -> void: InteractableArt.perk_body(r, shape, fp, brand))
	_lit = InteractableArt.place(_greybox, "perk_lit_" + String(perk_id),
		func(r: Node3D) -> void: InteractableArt.perk_tubes(r, shape, fp, "neon:" + InteractableArt.hex(brand)), Vector3.ZERO, false)
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
	_light.light_color = brand.lightened(0.25)
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
	plate.text = "HELVETIA AUTOMATEN AG · BASEL\nRezeptur: %s" % _short_human(str(lo.get("human", "")))
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

