class_name PowerSwitch
extends Interactable
## The Hauptschalter (Map 1, Generator Hall). Free to throw. Runs the power-on sequence (MAPS.md):
## lever + shake, power flag + GLBus.power_activated, Operator line, lights sweeping zone by zone,
## then a burst of zombies at the "power_burst_points".
## Lights: OmniLight3D nodes in group "power_lights" with meta "zone" (and optional meta "energy").

@export var zone_order: PackedStringArray = ["G_GENERATOR", "F_CHAPEL", "H_LAB", "I_CORE", "E_LIFT",
	"D_BARRACKS", "C_ADMIN", "B_RAILYARD", "A_MINEHEAD"]

## Which data/gravelight/<table>.json holds this map's "power" block (map00: the Crossroads cellar lever).
@export var config_table: String = "map01"
## What the prompt calls it.
@export var label: String = "the Hauptschalter"
## Optional: the switch refuses until this GameState flag is set (Map 2: `ballast_loaded`, the crane hook).
@export var requires_flag: StringName = &""
@export var requires_text: String = "The crane wants ballast first"

var _thrown: bool = false
var _lever: Node3D
var _lamps: Array[MeshInstance3D] = []   # [AUS (red), EIN (green)]
var _beacon: OmniLight3D                 # a red glow that marks the switch in the dark hall, green once thrown


func _ready() -> void:
	add_to_group(&"power_switch")
	# wraps the front and sides of the panel, so it can be thrown from an angle, not only dead-on (T-028)
	interact_size = Vector3(1.8, 1.8, 0.9)
	interact_offset = Vector3(0, 1.0, -0.3)
	super._ready()
	# Lights start dark until the switch is thrown (unless power is already on).
	for n: Node in get_tree().get_nodes_in_group(&"power_lights"):
		var l: Light3D = n as Light3D
		if l == null:
			continue
		if not l.has_meta("energy"):
			l.set_meta("energy", l.light_energy)
		if not GameState.power_on:
			l.light_energy = 0.0
			l.visible = false


func build_greybox() -> void:
	# a main breaker cabinet (cached): gauges, fuses, a name board, and the big lever on its quadrant (right flank)
	InteractableArt.place(self, "power_switch_body", func(r: Node3D) -> void: InteractableArt.power_switch_body(r))
	add_label(self, "HAUPTSCHALTER", Vector3(0, 1.76, -0.226), 26, Color(1, 0.85, 0.5))
	_lever = Node3D.new()
	_lever.position = Vector3(0.69, 1.0, -0.02)
	add_child(_lever)
	InteractableArt.place(_lever, "power_switch_lever", func(r: Node3D) -> void: InteractableArt.power_lever(r))
	# AUS / EIN lamps: the red one burns on the battery until the switch is thrown
	for i: int in 2:
		var lamp: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 0.04
		lamp.mesh = cm
		lamp.rotation.x = PI * 0.5
		lamp.position = Vector3(-0.14 + i * 0.28, 0.88, -0.255)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps.append(lamp)
		var l: Label3D = add_label(self, "AUS" if i == 0 else "EIN", Vector3(-0.14 + i * 0.28, 0.77, -0.232), 14, Color(0.95, 0.9, 0.8, 0.9))
		l.outline_size = 4
	_beacon = OmniLight3D.new()
	_beacon.position = Vector3(0, 1.1, -0.7)
	_beacon.omni_range = 4.5
	_beacon.light_energy = 0.7
	add_child(_beacon)
	GLBus.power_activated.connect(_refresh_lamps)
	_refresh_lamps()


func _refresh_lamps() -> void:
	var on: bool = GameState.power_on
	if _lamps.size() == 2:
		_lamps[0].material_override = Mats.get_mat("lamp_red_off" if on else "emergency_red")
		_lamps[1].material_override = Mats.get_mat("lamp_green" if on else "lamp_green_off")
	if _beacon != null:
		_beacon.light_color = Color(0.5, 1.0, 0.55) if on else Color(1.0, 0.2, 0.12)
		_beacon.light_energy = 0.35 if on else 0.7


func get_prompt(_player: Player) -> String:
	if _thrown or GameState.power_on:
		return ""
	if requires_flag != &"" and not GameState.has_flag(requires_flag):
		return requires_text
	return "Hold [%s] to throw %s" % [prompt_key(&"interact"), label]


func can_interact(_player: Player) -> bool:
	if requires_flag != &"" and not GameState.has_flag(requires_flag):
		return false
	return not _thrown and not GameState.power_on


func interact(player: Player) -> void:
	if _thrown or GameState.power_on:
		return
	_thrown = true
	run_sequence(player.player_id)


## The full power-on event. Public so the dev console / quest skips can call it.
func run_sequence(_by_player: int = 0) -> void:
	var cfg: Dictionary = _cfg()
	_thrown = true
	_sequence_visual()
	Net.mirror(self, &"_sequence_visual")
	GLBus.explosion.emit(global_position, 1.0)   # camera shake only (no damage path)
	GameState.power_on = true
	GameState.set_flag(&"power_on", true)
	GLBus.power_activated.emit()
	get_tree().create_timer(float(cfg["vo_delay"])).timeout.connect(func() -> void:
		GLVO.play(StringName(str(cfg["vo_line"]))))
	get_tree().create_timer(float(cfg["burst_delay"])).timeout.connect(_burst.bind(int(cfg["burst_count"])))


## Lever, clunk and the lights sweeping zone by zone (every peer; co-op clients get it from the host).
func _sequence_visual() -> void:
	var cfg: Dictionary = _cfg()
	_thrown = true
	if _lever != null:
		var tw: Tween = create_tween()
		tw.tween_property(_lever, "rotation:x", 1.6, 0.25).set_trans(Tween.TRANS_BACK)
	AudioDirector.play_3d("door_open", global_position + Vector3.UP, 4.0, 0.0)
	var t: float = float(cfg["light_sweep_start"])
	for zone: String in zone_order:
		get_tree().create_timer(t).timeout.connect(_light_zone.bind(StringName(zone)))
		t += float(cfg["light_zone_gap"])


static var _map01: Dictionary = {}


## data/map01.json isn't in the Data autoload's table list, so it's loaded here once.
static func map01() -> Dictionary:
	if _map01.is_empty():
		_map01 = GLData.load_json("res://data/gravelight/map01.json")
	return _map01


func _cfg() -> Dictionary:
	if config_table == "map01":
		return map01()["power"]
	return GLData.load_json("res://data/gravelight/%s.json" % config_table)["power"]


func _light_zone(zone: StringName) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"power_lights"):
		var l: Light3D = n as Light3D
		if l == null or StringName(str(l.get_meta("zone", ""))) != zone:
			continue
		var target: float = float(l.get_meta("energy", 1.0))
		l.visible = true
		var tw: Tween = l.create_tween()
		tw.tween_property(l, "light_energy", target, 0.08)
		tw.tween_property(l, "light_energy", 0.0, 0.08)
		tw.tween_property(l, "light_energy", target, 0.08)
		tw.tween_property(l, "light_energy", 0.0, 0.1)
		tw.tween_property(l, "light_energy", target, 0.15)


func _burst(count: int) -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var points: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"power_burst_points"):
		points.append((n as Node3D).global_position)
	if not points.is_empty():
		dir.spawn_burst(points, count)
