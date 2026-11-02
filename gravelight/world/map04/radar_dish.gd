class_name RadarDish
extends Node3D
## The radar tower's dish (UPDATE 10 §3 Act III, contract C6 `radar_ping`, DECISIONS T-157). Dead until the
## generator's power is on; then the dish (the generator's "RadarDish" group, kept out of the dressing bake) turns
## at `turn_dps`, and every `every_s` seconds the host sends one ping: `GLBus.radar_ping(seconds)` on every peer
## (Net.mirror) marks every zombie on the minimap and the pause map for `seconds` (MapState) and the minimap draws a
## sweep; a sweep sound at the dish and a quiet one on the HUD. Data: map04c.json "radar".
## The timer rule is static (unit-tested).

@export var config_table: String = "map04c"
@export var dish_name: String = "RadarDish"

var cfg: Dictionary = {}
var powered: bool = false
var pings: int = 0                   # the smoke
var turned_deg: float = 0.0
var _dish: Node3D = null
var _dish_basis: Basis = Basis.IDENTITY
var _since: float = 0.0              # seconds powered
var _next_at: float = INF            # _since at which the next ping goes out
var _spin: float = 0.0               # the dish's turn speed now (spins up)


## Seconds-powered of the first ping and every one after: first_after_s, then every_s apart.
static func ping_times(first_after: float, every: float, count: int) -> Array[float]:
	var out: Array[float] = []
	for i: int in count:
		out.append(first_after + every * float(i))
	return out


## True when the ping due at `next_at` has come by `since` (the timer's one rule).
static func ping_due(since: float, next_at: float) -> bool:
	return since >= next_at


func _ready() -> void:
	add_to_group(&"radar_dish")
	var path: String = "res://data/gravelight/%s.json" % config_table
	if FileAccess.file_exists(path):
		cfg = GLData.load_json(path).get("radar", {})
	GLBus.power_activated.connect(_on_power)
	(func() -> void:
		var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		_dish = root.find_child(dish_name, true, false) as Node3D
		if _dish != null:
			_dish_basis = _dish.basis
		if GameState.power_on:
			_on_power()).call_deferred()


func _on_power() -> void:
	if powered or cfg.is_empty():
		return
	powered = true
	_since = 0.0
	_next_at = float(cfg.get("first_after_s", 8.0))
	if AudioDirector.has_sound("radar_motor"):
		AudioDirector.play_3d("radar_motor", global_position, -2.0)


func _process(delta: float) -> void:
	if not powered:
		return
	_spin = move_toward(_spin, float(cfg.get("turn_dps", 36.0)), delta * 12.0)
	turned_deg += _spin * delta
	if _dish != null and is_instance_valid(_dish):
		_dish.basis = Basis(Vector3.UP, deg_to_rad(turned_deg)) * _dish_basis
	_since += delta
	if Net.is_authority() and ping_due(_since, _next_at):
		_next_at += float(cfg.get("every_s", 60.0))
		ping(float(cfg.get("seconds", 10.0)))


## One ping (the host; the console and the smoke call it too): every peer marks every zombie for `seconds`.
func ping(seconds: float) -> void:
	_ping_local(seconds)
	Net.mirror(self, &"_ping_local", [seconds])


func _ping_local(seconds: float) -> void:
	pings += 1
	GLBus.radar_ping.emit(seconds)
	if AudioDirector.has_sound("radar_sweep"):
		AudioDirector.play_3d("radar_sweep", global_position, 2.0)
		AudioDirector.play_2d("radar_sweep", -14.0)
	if pings == 1:
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", str(cfg.get("first_banner", "RADAR: every contact on your map")), 3.0)


## The dev console: the next ping in `s` seconds.
func debug_next_ping_in(s: float) -> void:
	_next_at = _since + s


## The capture tool / console: power the dish (if dark) and ping now.
func debug_ping_now() -> void:
	if not powered:
		_on_power()
	ping(float(cfg.get("seconds", 10.0)))
