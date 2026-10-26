class_name SolarFlare
extends Node3D
## Map 4 Act IV's special round, "SOLAR FLARE" (UPDATE 07, docs/MAP4_FERNFLUG.md §6.9): in place of the Bellringer
## round the yard's air posts fail for the round, the Earth flickers, and the Suited pour over the crater rim: every
## `interval_seconds` a wave of `per_wave` rises on the `rim_points` (data: map04d.json "solar_flare") while the
## round's queue lasts; with the yard still shut they come up through the `fallback_points` in the pressurized domes
## instead (plain Gängers: the suits are for the vacuum). Clearing the round drops a Resupply on the last wave's
## point (`director._last_bell_pos`). In the Retained state (T-113) the posts are dead already and the round is
## called a DUST STORM. The director's `special_handler` hook calls `tick_special(delta)`.

var director: ZombieDirector = null
var cfg: Dictionary = {}
var _t: float = 0.0
var _started: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var waves_fired: int = 0
var posts_failed: bool = false


func _ready() -> void:
	name = "SolarFlare"
	_rng.randomize()
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	(func() -> void:
		cfg = _load_cfg()
		for n: Node in get_tree().get_nodes_in_group(&"director"):
			director = n as ZombieDirector
		if director != null and _applies():
			director.special_handler = self).call_deferred()


func _load_cfg() -> Dictionary:
	var path: String = "res://data/gravelight/%s.json" % String(GameState.map_id).get_slice("_", 0)
	if not FileAccess.file_exists(path):
		return {}
	return GLData.load_json(path).get("solar_flare", {})


func _applies() -> bool:
	return not cfg.is_empty() and str(RoundManager.act_block_of(GameState.map_id).get("special_kind", "")) == "solar_flare"


## The points a wave uses: the rim when the yard is open, else the fallback points in open zones. [point, in_vacuum].
static func wave_points(rim: Array, yard_open: bool, fallback: Dictionary, open_zones: Dictionary) -> Array:
	var out: Array = []
	if yard_open:
		for p: Array in rim:
			out.append([Vector3(float(p[0]), float(p[1]), float(p[2])), true])
		return out
	for z: String in fallback.keys():
		if not open_zones.has(StringName(z)) and not open_zones.has(z):
			continue
		for p2: Array in fallback[z]:
			out.append([Vector3(float(p2[0]), float(p2[1]), float(p2[2])), false])
	return out


func _on_round_started(_r: int, special: bool) -> void:
	if not special or not _applies() or director == null:
		return
	_started = true
	_t = 2.0
	waves_fired = 0
	if not GameState.retained:
		AirPost.set_all(get_tree(), false)
		posts_failed = true
	var sky: Node = get_tree().get_first_node_in_group(&"earth_sky")
	if sky != null and sky.has_method("flicker"):
		sky.call("flicker", 4.0)
	if str(cfg.get("vo_start", "")) != "":
		GLVO.play(StringName(str(cfg["vo_start"])))
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", str(cfg.get("retained_banner", "DUST STORM")) if GameState.retained else str(cfg.get("banner", "SOLAR FLARE")), 3.0)


func _on_round_ended(_r: int) -> void:
	if _started:
		if str(cfg.get("vo_end", "")) != "":
			GLVO.play(StringName(str(cfg["vo_end"])))
		if posts_failed and not GameState.retained:
			AirPost.set_all(get_tree(), true)
	posts_failed = false
	_started = false


func tick_special(delta: float) -> void:
	if not _started or director == null:
		return
	_t -= delta
	if _t > 0.0 or not RoundManager.can_spawn():
		return
	_t = float(cfg.get("interval_seconds", 6.0))
	var yard: StringName = StringName(str(cfg.get("yard_zone", "C_YARD")))
	var pts: Array = wave_points(cfg.get("rim_points", []), GameState.is_zone_open(yard), cfg.get("fallback_points", {}), GameState.open_zones)
	if pts.is_empty():
		return
	waves_fired += 1
	var n: int = int(cfg.get("per_wave", 3))
	var last: Vector3 = Vector3.INF
	for i: int in n:
		if not RoundManager.can_spawn():
			break
		var e: Array = pts[(waves_fired * 7 + i) % pts.size()]
		var at: Vector3 = (e[0] as Vector3) + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
		var kind: StringName = &"suited" if bool(e[1]) and director._map_allows(&"suited") else &"ganger"
		var spec: Dictionary = director._spec_for(kind, RoundManager.take_spawn())
		spec["variant"] = str(cfg.get("kit", "soldier"))
		if not (GLData.table("anim")["kits"] as Dictionary).has(spec["variant"]):
			spec["variant"] = "soldier"
		if not bool(e[1]):
			spec["tier"] = StringName(str(cfg.get("tier", "jog")))
		if director._activate_at(spec, director._snap(at)) == null:
			RoundManager.requeue()
		else:
			last = at
	if last != Vector3.INF:
		director._last_bell_pos = last
		AudioDirector.play_3d("board_slam", last + Vector3.UP, -4.0, 0.5)
