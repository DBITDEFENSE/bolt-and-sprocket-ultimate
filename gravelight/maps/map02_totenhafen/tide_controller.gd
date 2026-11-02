class_name TideController
extends Node3D
## Map 2 "Totenhafen": the tide (MAPS.md Map 2, DECISIONS T-036; Tide v2: UPDATE 10 contract C2, T-153). Data-driven
## from data/gravelight/map02.json "tide".
##
## Stages: every round has one (stage_for_round, unit-tested): `spring` on every `spring_every_rounds`-th round (from
## `min_round`), `high` on every `every_rounds`-th, `half` on the round before a high one, else `low`. At a round's
## start the water moves to the stage's y over `rise_seconds`, holds `hold_seconds[stage]`, then falls back to `low_y`
## over `fall_seconds` (the Pumpenschalter crank, PumpCrank, takes `pump_crank.shortens_by_s` off the hold). A spring
## tide also raises the sheets over `spring_flood_boxes` (the north apron and the east apron's basin edge) to
## `spring_sheet_y`, so the piers stand as dry islands. Anyone inside a wet box and under its surface wades: players
## get the `player_status` status, zombies the frost slow `zombie_slow`; the `flood_disable` / `flood_enable` spawn
## points switch; the GameState flag `flooded` is on while any box is wet (the Kielholer spawn table keys off it).
## While wet: dropped power-ups drift (`float_drift` per box) and are lost when they leave the box; the `cables` spark
## (power on): zombies in reach are stunned, players take `player_dps`.
##
## Signals on GLBus (C2): tide_stage(stage), tide_flood_begin, tide_flood_end, spring_tide(round), tide_cable_spark.
## The storm's per-stage values (spray, lightning, waves) are data for the living world: storm_for(stage).
##
## Co-op (C8): the stage follows the round number on every peer; the host decides when the water falls (the hold
## running out, the crank) and mirrors `fall_now`; the slow, the cables, the drift and the flag run on the authority.

const STAGE_LOW: StringName = &"low"
const STAGE_HALF: StringName = &"half"
const STAGE_HIGH: StringName = &"high"
const STAGE_SPRING: StringName = &"spring"

@export var config_table: String = "map02"
## The water plane the tide moves (a MeshInstance3D; its y is the surface).
@export var water_path: NodePath

var level: float = -4.0
var target: float = -4.0
var flooded: bool = false
var last_round: int = 0
## The stage the current round planned (the water may still be rising toward it or falling from it).
var stage: StringName = STAGE_LOW
## The spring sheets' surface (over the aprons) and where it is heading.
var sheet_level: float = -0.6
var sheet_target: float = -0.6
## Seconds the water still holds at the stage before it falls (authority; < 0 = no hold running).
var hold_left: float = -1.0
## Power-ups lost to the sea this match (tests and the smoke read it).
var powerups_lost: int = 0
## Cable discharges this match (tests and the smoke read it).
var cable_sparks: int = 0

var _cfg: Dictionary = {}
var _rate: float = 0.0
var _sheet_rate: float = 0.0
var _water: Node3D
var _tick: float = 0.0
var _cable_tick: float = 0.0
var _boxes: Array[AABB] = []
var _spring_boxes: Array[AABB] = []
var _sheets: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group(&"tide")
	_cfg = GLData.load_json("res://data/gravelight/%s.json" % config_table).get("tide", {})
	level = float(_cfg.get("low_y", -4.0))
	target = level
	sheet_level = float(_cfg.get("spring_sheet_low_y", -0.6))
	sheet_target = sheet_level
	_boxes = boxes_from(_cfg.get("flood_boxes", []))
	_spring_boxes = boxes_from(_cfg.get("spring_flood_boxes", []))
	_water = get_node_or_null(water_path) as Node3D
	_build_sheets()
	_apply_level()
	GLBus.round_started.connect(_on_round_started)


static func boxes_from(raw: Array) -> Array[AABB]:
	var out: Array[AABB] = []
	for b: Variant in raw:
		var lo: Array = (b as Array)[0]
		var hi: Array = (b as Array)[1]
		var a: Vector3 = Vector3(float(lo[0]), float(lo[1]), float(lo[2]))
		var c: Vector3 = Vector3(float(hi[0]), float(hi[1]), float(hi[2]))
		out.append(AABB(a, c - a))
	return out


# ------------------------------------------------------------------ pure rules (unit-tested)

## Is `round_number` a flood round (high or spring)? Kept from v1: the smokes and the forecast read it.
static func is_high_round(round_number: int, cfg: Dictionary) -> bool:
	var every: int = maxi(1, int(cfg.get("every_rounds", 3)))
	return round_number >= int(cfg.get("min_round", 3)) and round_number % every == 0


static func warns_next(round_number: int, cfg: Dictionary) -> bool:
	return not is_high_round(round_number, cfg) and is_high_round(round_number + 1, cfg)


static func is_spring_round(round_number: int, cfg: Dictionary) -> bool:
	var every: int = int(cfg.get("spring_every_rounds", 0))
	return every > 0 and round_number >= int(cfg.get("min_round", 3)) and round_number % every == 0


## The stage a round plans: spring > high > half (the round before a high one) > low.
static func stage_for_round(round_number: int, cfg: Dictionary) -> StringName:
	if is_spring_round(round_number, cfg):
		return STAGE_SPRING
	if is_high_round(round_number, cfg):
		return STAGE_HIGH
	if warns_next(round_number, cfg) and round_number >= 1:
		return STAGE_HALF
	return STAGE_LOW


## The water's y for a stage (`stages` in the data; low is `low_y`).
static func stage_y(stage_name: StringName, cfg: Dictionary) -> float:
	for s: Variant in cfg.get("stages", []):
		if StringName(str((s as Dictionary).get("name", ""))) == stage_name:
			return float((s as Dictionary).get("y", cfg.get("low_y", -4.0)))
	if stage_name == STAGE_HIGH:
		return float(cfg.get("high_y", -2.2))
	return float(cfg.get("low_y", -4.0))


## Seconds a stage holds before the water falls (0 = it stays until the next round re-plans).
static func hold_for(stage_name: StringName, cfg: Dictionary) -> float:
	return float((cfg.get("hold_seconds", {}) as Dictionary).get(String(stage_name), 0.0))


## The crank's effect on a running hold: what is left after one completed crank (never below 0).
static func after_crank(hold_left_s: float, cfg: Dictionary) -> float:
	var by: float = float((cfg.get("pump_crank", {}) as Dictionary).get("shortens_by_s", 40.0))
	return maxf(0.0, hold_left_s - by)


## The storm's values for a stage: {spray, lightning_interval, wave_height} (the living world reads these).
static func storm_for(stage_name: StringName, cfg: Dictionary) -> Dictionary:
	var st: Dictionary = cfg.get("storm", {})
	var key: String = String(stage_name)
	return {
		"spray": float((st.get("spray_intensity_by_stage", {}) as Dictionary).get(key, 0.0)),
		"lightning_interval": float((st.get("lightning_interval_by_stage", {}) as Dictionary).get(key, 0.0)),
		"wave_height": float((st.get("wave_height_by_stage", {}) as Dictionary).get(key, 0.0)),
	}


## The next spring tide at or after `round_number` (0 when the schedule has none).
static func next_spring(round_number: int, cfg: Dictionary) -> int:
	var every: int = int(cfg.get("spring_every_rounds", 0))
	if every <= 0:
		return 0
	var r: int = maxi(round_number, int(cfg.get("min_round", 3)))
	return int(ceil(float(r) / float(every))) * every


# ------------------------------------------------------------------ the round's plan

func _on_round_started(round_number: int, _special: bool) -> void:
	on_round(round_number)


## The tide's reaction to a round starting (public so tools can drive it).
func on_round(round_number: int) -> void:
	last_round = round_number
	var low: float = float(_cfg.get("low_y", -4.0))
	var prev_stage: StringName = stage
	stage = stage_for_round(round_number, _cfg)
	var y: float = stage_y(stage, _cfg)
	var rise: float = maxf(1.0, float(_cfg.get("rise_seconds", 24.0)))
	if y > level + 0.001:
		target = y
		_rate = absf(y - level) / rise
		if stage == STAGE_SPRING:
			_announce("vo_spring", "banner_spring")
		elif stage == STAGE_HIGH:
			_announce("vo_rising", "banner_rising")
	elif y < level - 0.001 or target > y + 0.001:
		target = y
		_rate = absf(level - y) / maxf(1.0, float(_cfg.get("fall_seconds", 24.0)))
		if level > low + 0.5:
			_announce("vo_falling", "banner_falling")
	else:
		target = y
	# the spring sheets over the aprons
	var sheet_low: float = float(_cfg.get("spring_sheet_low_y", -0.6))
	sheet_target = float(_cfg.get("spring_sheet_y", 0.35)) if stage == STAGE_SPRING else sheet_low
	_sheet_rate = absf(sheet_target - sheet_level) / (rise if stage == STAGE_SPRING else maxf(1.0, float(_cfg.get("fall_seconds", 24.0))))
	var hold: float = hold_for(stage, _cfg)
	hold_left = rise + hold if hold > 0.0 and stage != STAGE_LOW else -1.0
	if warns_next(round_number, _cfg):
		if is_spring_round(round_number + 1, _cfg):
			_announce("vo_spring_warn", "banner_spring_warn")
		else:
			_announce("vo_warn", "banner_warn")
	if stage != prev_stage:
		GLBus.tide_stage.emit(stage)
	if stage == STAGE_SPRING:
		GLBus.spring_tide.emit(round_number)


## Letzte Fahrt (s8, the curtain): the water goes to `stage_name` now and holds `hold_s` (0 = until the next round
## re-plans). Every peer runs it (the host mirrors).
func force_stage(stage_name: StringName, hold_s: float = 0.0) -> void:
	var y: float = stage_y(stage_name, _cfg)
	var rise: float = maxf(1.0, float(_cfg.get("rise_seconds", 24.0)))
	target = y
	_rate = absf(y - level) / rise
	if stage_name == STAGE_SPRING:
		sheet_target = float(_cfg.get("spring_sheet_y", 0.35))
		_sheet_rate = absf(sheet_target - sheet_level) / rise
	hold_left = rise + hold_s if hold_s > 0.0 else -1.0
	if stage != stage_name:
		stage = stage_name
		GLBus.tide_stage.emit(stage)
	if Net.is_authority():
		Net.mirror(self, &"force_stage", [stage_name, hold_s])


## The host's call: the water goes out now (the hold ran out or the crank finished it). Every peer runs it.
func fall_now() -> void:
	hold_left = -1.0
	var low: float = float(_cfg.get("low_y", -4.0))
	if level <= low + 0.001 and target <= low + 0.001 and sheet_level <= float(_cfg.get("spring_sheet_low_y", -0.6)) + 0.001:
		return
	var fall: float = maxf(1.0, float(_cfg.get("fall_seconds", 24.0)))
	target = low
	_rate = absf(level - low) / fall
	sheet_target = float(_cfg.get("spring_sheet_low_y", -0.6))
	_sheet_rate = absf(sheet_level - sheet_target) / fall
	_announce("vo_falling", "banner_falling")
	if stage != STAGE_LOW:
		stage = STAGE_LOW
		GLBus.tide_stage.emit(stage)


## A completed crank (PumpCrank, authority): the hold shortens; at zero the water falls.
func crank_completed() -> void:
	if not Net.is_authority():
		return
	if hold_left < 0.0:
		fall_now()
		Net.mirror(self, &"fall_now")
		return
	hold_left = after_crank(hold_left, _cfg)
	if hold_left <= 0.0:
		fall_now()
		Net.mirror(self, &"fall_now")


## Is a flood up that the crank can act on?
func can_crank() -> bool:
	return flooded and target > float(_cfg.get("low_y", -4.0)) + 0.001


func _announce(vo_key: String, banner_key: String) -> void:
	var banner: String = str(_cfg.get(banner_key, ""))
	if banner != "":
		var root: Node = get_parent()
		while root != null and not (root is MapRoot):
			root = root.get_parent()
		if root != null and (root as MapRoot).hud != null:
			(root as MapRoot).hud.show_banner(banner, 3.5)
	var lines: Array = _cfg.get(vo_key, [])
	if lines.is_empty() or not is_inside_tree():
		return
	var line: String = str(lines[randi_range(0, lines.size() - 1)])
	var delay: float = float(_cfg.get("vo_delay", 2.5))
	get_tree().create_timer(delay).timeout.connect(func() -> void: GLVO.play(StringName(line)))


func _process(delta: float) -> void:
	var moved: bool = false
	if absf(level - target) > 0.0005:
		level = move_toward(level, target, _rate * delta)
		moved = true
	if absf(sheet_level - sheet_target) > 0.0005:
		sheet_level = move_toward(sheet_level, sheet_target, maxf(0.01, _sheet_rate) * delta)
		moved = true
	if moved:
		_apply_level()
	var now_flooded: bool = _main_wet() or _sheet_wet()
	if now_flooded != flooded:
		flooded = now_flooded
		_switch_spawns()
		if flooded:
			GLBus.tide_flood_begin.emit()
		else:
			GLBus.tide_flood_end.emit()
		if Net.is_authority():
			GameState.set_flag(&"flooded", flooded)
	if Net.is_authority() and hold_left > 0.0:
		hold_left -= delta
		if hold_left <= 0.0:
			fall_now()
			Net.mirror(self, &"fall_now")


func _main_wet() -> bool:
	var low: float = float(_cfg.get("low_y", -4.0))
	var high: float = float(_cfg.get("high_y", -2.2))
	return level > low + (high - low) * 0.5


func _sheet_wet() -> bool:
	var lo: float = float(_cfg.get("spring_sheet_low_y", -0.6))
	return not _spring_boxes.is_empty() and sheet_level > lo + 0.5


func _apply_level() -> void:
	if _water != null:
		_water.position.y = level
	for s: MeshInstance3D in _sheets:
		s.position.y = sheet_level
		s.visible = sheet_level > float(_cfg.get("spring_sheet_low_y", -0.6)) + 0.05


## The spring sheets: one water plane per spring box (the tide water's material when there is one).
func _build_sheets() -> void:
	var mat: Material = null
	var wm: MeshInstance3D = _water as MeshInstance3D
	if wm != null:
		mat = wm.material_override if wm.material_override != null else (wm.mesh.surface_get_material(0) if wm.mesh != null and wm.mesh.get_surface_count() > 0 else null)
	if mat == null:
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.albedo_color = Color(0.08, 0.13, 0.15, 0.82)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.roughness = 0.08
		sm.metallic = 0.3
		mat = sm
	var i: int = 0
	for b: AABB in _spring_boxes:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "SpringSheet%d" % i
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(b.size.x, b.size.z)
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		mi.global_position = Vector3(b.position.x + b.size.x * 0.5, sheet_level, b.position.z + b.size.z * 0.5)
		mi.visible = false
		_sheets.append(mi)
		i += 1


## Is this world position standing in the flood (inside a wet box and under its surface)?
func is_wading(p: Vector3) -> bool:
	if level >= float(_cfg.get("wade_min_y", -99.0)) and level + 0.4 >= p.y:
		for b: AABB in _boxes:
			if b.has_point(p):
				return true
	if _sheet_wet() and sheet_level + 0.4 >= p.y:
		for b: AABB in _spring_boxes:
			if b.has_point(p):
				return true
	return false


## Which flood box (flood_boxes then spring_flood_boxes) holds `p` while it is wet, -1 = none.
func wet_box_index(p: Vector3) -> int:
	if level >= float(_cfg.get("wade_min_y", -99.0)) and _main_wet():
		for i: int in _boxes.size():
			if _boxes[i].has_point(p) and level + 0.6 >= p.y:
				return i
	if _sheet_wet():
		for j: int in _spring_boxes.size():
			if _spring_boxes[j].has_point(p) and sheet_level + 0.6 >= p.y:
				return _boxes.size() + j
	return -1


## The water surface's y at `p` (the sheet over the aprons when it is up there, else the tide level).
func surface_at(p: Vector3) -> float:
	if _sheet_wet():
		for b: AABB in _spring_boxes:
			if b.has_point(Vector3(p.x, b.position.y + 0.1, p.z)):
				return sheet_level
	return level


func _physics_process(delta: float) -> void:
	_tick -= delta
	_cable_tick -= delta
	if _tick <= 0.0:
		var step: float = float(_cfg.get("slow_tick_seconds", 0.35))
		_tick = step
		_wade_tick(step)
	if flooded and Net.is_authority():
		if bool(_cfg.get("float_powerups", false)):
			_drift_powerups(delta)
		if _cable_tick <= 0.0:
			_cable_tick = float(_cfg.get("cable_tick_seconds", 0.5))
			_cables_tick(_cable_tick)


func _wade_tick(step: float) -> void:
	if _boxes.is_empty() and _spring_boxes.is_empty():
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


## Floating power-ups: a drop in a wet box drifts with the box's current and is lost past its edge.
func _drift_powerups(delta: float) -> void:
	var speed: float = float(_cfg.get("drift_mps", 0.55))
	var drifts: Array = _cfg.get("float_drift", [])
	for n: Node in get_tree().get_nodes_in_group(&"powerups"):
		var pu: Node3D = n as Node3D
		if pu == null or pu.is_queued_for_deletion():
			continue
		var bi: int = pu.get_meta(&"tide_box", -1)
		var here: int = wet_box_index(pu.global_position)
		if here < 0 and bi < 0:
			continue
		if here < 0:
			# it was floating and drifted out of its box: the sea has it
			lose_powerup(pu)
			Net.mirror(self, &"lose_powerup_at", [pu.global_position])
			continue
		pu.set_meta(&"tide_box", here)
		var d: Vector3 = Vector3(0, 0, 1)
		if here < drifts.size():
			var a: Array = drifts[here]
			d = Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		pu.global_position += d * speed * delta
		pu.global_position.y = surface_at(pu.global_position) + 0.35


## Drift maths for the tests: where a drop starting at `p` in box `b` is after `t` seconds, and whether it is lost.
static func drift_result(p: Vector3, b: AABB, dir: Vector3, speed: float, t: float) -> Dictionary:
	var q: Vector3 = p + dir.normalized() * speed * t
	return {"position": q, "lost": not b.has_point(Vector3(q.x, b.position.y + b.size.y * 0.5, q.z))}


func lose_powerup(pu: Node3D) -> void:
	powerups_lost += 1
	AudioDirector.play_3d("water_splash", pu.global_position, -4.0, 0.0)
	if pu.has_signal(&"expired") and Net.is_authority():
		pu.emit_signal(&"expired")
	pu.queue_free()


## A client: the drop nearest `p` went to the sea.
func lose_powerup_at(p: Vector3) -> void:
	var best: Node3D = null
	var bd: float = 3.0
	for n: Node in get_tree().get_nodes_in_group(&"powerups"):
		var pu: Node3D = n as Node3D
		if pu != null and pu.global_position.distance_to(p) < bd:
			bd = pu.global_position.distance_to(p)
			best = pu
	if best != null:
		powerups_lost += 1
		best.queue_free()


## The sparking cables: live while their spot is wet (and the power is on): stun wading zombies, hurt players.
func _cables_tick(step: float) -> void:
	if bool(_cfg.get("cables_need_power", true)) and not GameState.power_on:
		return
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	for c: Variant in _cfg.get("cables", []):
		var cd: Dictionary = c
		var pa: Array = cd.get("pos", [0, 0, 0])
		var cp: Vector3 = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		if not is_wading(cp + Vector3.UP * 0.1):
			continue
		var r: float = float(cd.get("radius_m", 2.5))
		var fired: bool = false
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if z.global_position.distance_to(cp) <= r and is_wading(z.global_position):
					cable_stun(z, float(cd.get("stun_s", 2.0)))
					fired = true
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var pl: Player = n as Player
			if pl != null and pl.is_alive() and pl.global_position.distance_to(cp) <= r and is_wading(pl.global_position):
				pl.take_hit(float(_cfg.get("player_dps", 12.0)) * step, self)
				fired = true
		if fired:
			cable_sparks += 1
			spark(StringName(str(cd.get("id", "cable"))), cp)
			Net.mirror(self, &"spark", [StringName(str(cd.get("id", "cable"))), cp])


## A cable stun on one zombie: it stops dead (a full frost slow plus a stagger).
static func cable_stun(z: Zombie, seconds: float) -> void:
	z.apply_frost(1.0, seconds)
	z.force_stagger()
	z.set_meta(&"cable_stunned_until", Time.get_ticks_msec() + int(seconds * 1000.0))


## Presentation on every peer: the crackle (the flash is the living world's, from GLBus.tide_cable_spark).
func spark(cable_id: StringName, p: Vector3) -> void:
	AudioDirector.play_3d("wire_zap", p, -6.0, 0.0)
	GLBus.tide_cable_spark.emit(cable_id, p)


func _switch_spawns() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp == null:
			continue
		if (_cfg.get("flood_disable", []) as Array).has(String(sp.name)):
			sp.enabled = not flooded
		elif (_cfg.get("flood_enable", []) as Array).has(String(sp.name)):
			sp.enabled = flooded
