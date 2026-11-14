class_name RetentionColumn
extends Interactable
## One of the three retention columns in the hall (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.6, T-113): a
## lattice pylon of Nachtglas with a cap and a terms plate that quotes one of Vendelin's fine-print panels
## (`panel_key`). Hold Use for `read_seconds` (map04d.json "columns"): the reader reads the panel aloud (the
## speaker's `TERMS_READ_<index>` line, or the Operator's `OPR_M4D_TERMS_<index>` when no survivor can), the cap
## lifts, the lattice goes dark and the flag `column_<index>_dark` is set (the MondlichtController drops a letter
## off the sign and opens the Account at three). A Lodestone shot at the cap (`cap_lifted_<index>`) lifts the cap
## first and shortens the hold to `lifted_read_seconds`. Bots read too (their voice); every read wakes the dead.

@export var column_id: StringName = &"column_1"
@export var index: int = 1
@export var panel_key: String = "panel.skyhook_sekt"

var dark: bool = false
var cap_lifted: bool = false
var cfg: Dictionary = {}
var _cap: Node3D
var _glow: OmniLight3D
var _lattice: Array[MeshInstance3D] = []
var _hum: AudioStreamPlayer3D = null


func _ready() -> void:
	interact_size = Vector3(2.4, 2.2, 2.4)
	interact_offset = Vector3(0, 1.1, 0)
	super._ready()
	add_to_group(&"retention_columns")
	cfg = _load_cfg()
	GLBus.weapon_fired.connect(_on_weapon_fired)
	if AudioDirector.has_sound("hum"):
		_hum = AudioDirector.make_loop_3d("hum", self, -10.0)


func _load_cfg() -> Dictionary:
	var path: String = "res://data/gravelight/%s.json" % String(GameState.map_id).get_slice("_", 0)
	if GameState.map_id == &"" or not FileAccess.file_exists(path):
		return {}
	return GLData.load_json(path).get("columns", {})


func build_greybox() -> void:
	var lat: Node3D = Node3D.new()
	lat.name = "Lattice"
	add_child(lat)
	var h: float = 6.0
	for c: Vector2 in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]:
		_lattice.append(Props.strut(lat, Vector3(c.x, 0.0, c.y), Vector3(c.x * 0.6, h, c.y * 0.6), 0.08, "nachtglas"))
	for k: int in 5:
		var y: float = 1.0 + 1.1 * float(k)
		var s: float = 0.6 - 0.07 * float(k)
		_lattice.append(Props.strut(lat, Vector3(-s, y, -s), Vector3(s, y, s), 0.05, "nachtglas"))
		_lattice.append(Props.strut(lat, Vector3(s, y, -s), Vector3(-s, y, s), 0.05, "nachtglas"))
	Props.block(lat, Vector3(-0.9, 0.0, -0.9), Vector3(0.9, 0.25, 0.9), "steel")
	_cap = Node3D.new()
	_cap.name = "Cap"
	_cap.position = Vector3(0, h, 0)
	add_child(_cap)
	# the cap (U09 s5, T-149): a chrome capital in steps, the violet glass drum with an amber crack, the finial
	Props.block(_cap, Vector3(-0.62, 0.0, -0.62), Vector3(0.62, 0.12, 0.62), "chrome")
	Props.block(_cap, Vector3(-0.5, 0.12, -0.5), Vector3(0.5, 0.42, 0.5), "nachtglas_dim")
	Props.block(_cap, Vector3(-0.56, 0.42, -0.56), Vector3(0.56, 0.52, 0.56), "chrome")
	for s: float in [-1.0, 1.0]:
		Props.obox(_cap, Vector3(s * 0.12, 0.27, 0.505), Vector3(0.03, 0.26, 0.01), "nachtglas_vein", Vector3(0, 0, s * 22.0))
	Props.block(_cap, Vector3(-0.2, 0.52, -0.2), Vector3(0.2, 0.62, 0.2), "steel")
	Props.obox(_cap, Vector3(0, 0.84, 0), Vector3(0.3, 0.3, 0.3), "nachtglas", Vector3(45, 0, 45))
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, 3.0, 0)
	_glow.light_color = Color(0.62, 0.3, 1.0)
	_glow.light_energy = 1.8
	_glow.omni_range = 9.0
	_glow.light_volumetric_fog_energy = 1.0
	_glow.shadow_enabled = false
	add_child(_glow)
	# the terms plate: a brass plate on a chrome lectern at the plinth's front, facing +Z (the nave's way in),
	# tilted to the reader, the text large enough to read from the hold distance (U09 s5, T-149)
	var stand: MeshInstance3D = add_box(self, Vector3(0.08, 0.95, 0.08), Vector3(0, 0.475, 0.84), Mats.get_mat("chrome"))
	stand.name = "PlateStand"
	var plate: Node3D = Node3D.new()
	plate.name = "Plate"
	plate.position = Vector3(0, 1.05, 0.9)
	plate.rotation_degrees.x = -35.0
	add_child(plate)
	var pm: StandardMaterial3D = StandardMaterial3D.new()
	pm.albedo_color = Color(0.66, 0.53, 0.28)
	pm.metallic = 0.7
	pm.roughness = 0.4
	add_box(plate, Vector3(0.86, 0.5, 0.025), Vector3.ZERO, pm)
	add_box(plate, Vector3(0.9, 0.035, 0.035), Vector3(0, 0.265, 0.0), Mats.get_mat("chrome"))
	add_box(plate, Vector3(0.9, 0.035, 0.035), Vector3(0, -0.265, 0.0), Mats.get_mat("chrome"))
	var l: Label3D = add_label(plate, "TERMS · %s of III\n%s" % [["I", "II", "III"][clampi(index - 1, 0, 2)], _panel_title()], Vector3(0, 0.02, 0.0135), 24, Color(0.12, 0.08, 0.04, 1.0), SurfaceText.PRINT)
	l.pixel_size = 0.0021
	l.outline_size = 0
	l.width = 380.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var num: Label3D = add_label(self, ["I", "II", "III"][clampi(index - 1, 0, 2)], Vector3(0, 4.2, 1.0), 64, Color(0.75, 0.55, 1.0, 0.9))
	num.pixel_size = 0.008


func _panel_title() -> String:
	match panel_key:
		"panel.skyhook_sekt":
			return "CONDITIONS OF USE: SKYHOOK SEKT"
		"panel.magpie_mead":
			return "CONDITIONS OF USE: MAGPIE MEAD"
		_:
			return "CONDITIONS OF USE: FINE PRINT FERNET"


func get_prompt(player: Player) -> String:
	if dark:
		return ""
	if player == null:
		return ""
	return "Hold [%s] to read the terms (%d of 3)%s" % [prompt_key(&"interact"), index, "\nThe cap is lifted: a short read" if cap_lifted else ""]


func can_interact(_player: Player) -> bool:
	return not dark


func hold_time(_player: Player) -> float:
	return float(cfg.get("lifted_read_seconds", 1.0)) if cap_lifted else float(cfg.get("read_seconds", 4.0))


func interact(player: Player) -> void:
	if dark:
		return
	read_terms(player.player_id if player != null else 0)


## The reading: the speaker's line, else the Operator's; the cap lifts, the lattice goes dark, the flag is set.
func read_terms(pid: int) -> void:
	if dark:
		return
	dark = true
	var cat: String = "TERMS_READ_%d" % index
	var spoke: bool = false
	if pid > 0:
		spoke = GLVO.say_as(pid, cat, 1.0)
	if not spoke:
		GLVO.play(StringName("OPR_M4D_TERMS_%d" % index))
	lift_cap()
	for m: MeshInstance3D in _lattice:
		if is_instance_valid(m):
			m.material_override = Mats.get_mat("nachtglas_dim")
	if _glow != null:
		var tw: Tween = create_tween()
		tw.tween_property(_glow, "light_energy", 0.0, 1.6)
	if _hum != null and is_instance_valid(_hum):
		_hum.stop()
	AudioDirector.play_3d("board_slam", global_position + Vector3.UP * 2.0, -2.0, 0.6)
	GameState.set_flag(StringName("column_%d_dark" % index))
	GLBus.flag_changed.emit(StringName("column_%d_dark" % index), true)


## The cap rises (a Lodestone lift, or the read itself).
func lift_cap() -> void:
	if cap_lifted:
		return
	cap_lifted = true
	GameState.set_flag(StringName("cap_lifted_%d" % index))
	if _cap != null:
		var tw: Tween = create_tween()
		tw.tween_property(_cap, "position:y", _cap.position.y + 1.4, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## True when a shot from `origin` along `dir` passes within `r` of the cap at `cap_pos` (the Lodestone's lift ray).
static func ray_near(origin: Vector3, dir: Vector3, cap_pos: Vector3, r: float, max_dist: float = 12.0) -> bool:
	var d: Vector3 = dir.normalized()
	var to: Vector3 = cap_pos - origin
	var t: float = to.dot(d)
	if t < 0.0 or t > max_dist:
		return false
	return (to - d * t).length() <= r


func _on_weapon_fired(_player: int, weapon_id: StringName, _upgraded: bool, origin: Vector3, direction: Vector3) -> void:
	if dark or cap_lifted or not String(weapon_id).begins_with("lodestone") or _cap == null:
		return
	if ray_near(origin, direction, _cap.global_position + Vector3.UP * 0.4, 1.4):
		lift_cap()
		AudioDirector.play_3d("door_open", _cap.global_position, -4.0, 0.3)
