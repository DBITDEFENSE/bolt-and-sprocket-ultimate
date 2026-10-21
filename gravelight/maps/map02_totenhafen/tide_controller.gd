class_name TideController
extends Node3D
## Map 2 "Totenhafen": the tide (MAPS.md Map 2, DECISIONS T-036). Data-driven from data/gravelight/map02.json
## "tide": on every round divisible by `every_rounds` (from `min_round`) the Pen Hall water rises from `low_y` to
## `high_y` over `rise_seconds`, and falls again over `fall_seconds` when the next round starts. While the water is
## up, anyone inside a `flood_boxes` AABB and below the surface wades: players get the `player_status` status
## effect (enemies.json "status", refreshed every tick), zombies the frost slow `zombie_slow`; the `flood_disable`
## spawn points go off and the `flood_enable` ones come on. The Operator reads the forecast the round before
## (`vo_warn`), then `vo_rising` / `vo_falling`, with a HUD banner each time.
##
## Presentation follows the round number on every peer (the water is the same height for everyone); the slow and
## the spawn switches only matter on the authority, where zombies are driven.

@export var config_table: String = "map02"
## The water plane the tide moves (a MeshInstance3D; its y is the surface).
@export var water_path: NodePath

var level: float = -4.0
var target: float = -4.0
var flooded: bool = false
var last_round: int = 0

var _cfg: Dictionary = {}
var _rate: float = 0.0
var _water: Node3D
var _tick: float = 0.0
var _boxes: Array[AABB] = []


func _ready() -> void:
	add_to_group(&"tide")
	_cfg = GLData.load_json("res://data/gravelight/%s.json" % config_table).get("tide", {})
	level = float(_cfg.get("low_y", -4.0))
	target = level
	for b: Variant in _cfg.get("flood_boxes", []):
		var lo: Array = (b as Array)[0]
		var hi: Array = (b as Array)[1]
		var a: Vector3 = Vector3(float(lo[0]), float(lo[1]), float(lo[2]))
		var c: Vector3 = Vector3(float(hi[0]), float(hi[1]), float(hi[2]))
		_boxes.append(AABB(a, c - a))
	_water = get_node_or_null(water_path) as Node3D
	_apply_level()
	GLBus.round_started.connect(_on_round_started)


## Pure schedule rules (unit-tested): is `round_number` a high-tide round, and is the next one.
static func is_high_round(round_number: int, cfg: Dictionary) -> bool:
	var every: int = maxi(1, int(cfg.get("every_rounds", 3)))
	return round_number >= int(cfg.get("min_round", 3)) and round_number % every == 0


static func warns_next(round_number: int, cfg: Dictionary) -> bool:
	return not is_high_round(round_number, cfg) and is_high_round(round_number + 1, cfg)


func _on_round_started(round_number: int, _special: bool) -> void:
	on_round(round_number)


## The tide's reaction to a round starting (public so tools can drive it).
func on_round(round_number: int) -> void:
	last_round = round_number
	var low: float = float(_cfg.get("low_y", -4.0))
	var high: float = float(_cfg.get("high_y", -2.2))
	if is_high_round(round_number, _cfg):
		target = high
		_rate = absf(high - low) / maxf(1.0, float(_cfg.get("rise_seconds", 24.0)))
		_announce("vo_rising", "banner_rising")
	elif target > low + 0.001 or level > low + 0.001:
		target = low
		_rate = absf(high - low) / maxf(1.0, float(_cfg.get("fall_seconds", 24.0)))
		_announce("vo_falling", "banner_falling")
	if warns_next(round_number, _cfg):
		_announce("vo_warn", "banner_warn")


func _announce(vo_key: String, banner_key: String) -> void:
	var banner: String = str(_cfg.get(banner_key, ""))
	if banner != "":
		var root: Node = get_parent()
		while root != null and not (root is MapRoot):
			root = root.get_parent()
		if root != null and (root as MapRoot).hud != null:
			(root as MapRoot).hud.show_banner(banner, 3.5)
	var lines: Array = _cfg.get(vo_key, [])
	if lines.is_empty():
		return
	var line: String = str(lines[randi_range(0, lines.size() - 1)])
	var delay: float = float(_cfg.get("vo_delay", 2.5))
	get_tree().create_timer(delay).timeout.connect(func() -> void: GLVO.play(StringName(line)))


func _process(delta: float) -> void:
	if absf(level - target) > 0.0005:
		level = move_toward(level, target, _rate * delta)
		_apply_level()
	var low: float = float(_cfg.get("low_y", -4.0))
	var high: float = float(_cfg.get("high_y", -2.2))
	var now_flooded: bool = level > low + (high - low) * 0.5
	if now_flooded != flooded:
		flooded = now_flooded
		_switch_spawns()


func _apply_level() -> void:
	if _water != null:
		_water.position.y = level


## Is this world position standing in the flood (inside a flood box and under the surface)?
func is_wading(p: Vector3) -> bool:
	if level + 0.4 < p.y:
		return false
	for b: AABB in _boxes:
		if b.has_point(p):
			return true
	return false


func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	var step: float = float(_cfg.get("slow_tick_seconds", 0.35))
	_tick = step
	if _boxes.is_empty():
		return
	var status: StringName = StringName(str(_cfg.get("player_status", "wading")))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = n as Player
		if pl != null and pl.is_alive() and is_wading(pl.global_position):
			pl.apply_status(status, step * 2.0)
	if not Net.is_authority():
		return
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var slow: float = float(_cfg.get("zombie_slow", 0.45))
	for z: Zombie in dir.active_zombies():
		if is_wading(z.global_position):
			z.apply_frost(slow, step * 2.0)


func _switch_spawns() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp == null:
			continue
		if (_cfg.get("flood_disable", []) as Array).has(String(sp.name)):
			sp.enabled = not flooded
		elif (_cfg.get("flood_enable", []) as Array).has(String(sp.name)):
			sp.enabled = flooded
