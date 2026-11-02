class_name TotenhafenBallast
extends Node
## Ballast v2's bookkeeping (UPDATE 10 contract C2, design section 3, DECISIONS T-153), attached by Totenhafen:
## places the sea-stairs BallastDump, answers the two choices (the Operator pleased or snippy, a squad member's line,
## the Scrip bonus is the hook's, +1 Glasshide next round per dump via RoundManager.extra_spawn), leaves the
## Undertow's shard on the stairs after the third dump, sets `lf_ballast_done` once three are dumped and one loaded
## (Letzte Fahrt's s1), and puts gone coffins back on free pallets after `respawn_seconds` so both choices stay open.
## Authority only for the decisions; peers mirror the respawns.

const CODES: Dictionary = {&"dutch": "DUT", &"peg": "PEG", &"deacon": "DEA", &"wren": "WRN"}

var t: Totenhafen
var dump: BallastDump
var shard_spawned: bool = false
var _bcfg: Dictionary = {}
var _tick: float = 0.0
var _spot_i: int = 0


static func attach(owner_t: Totenhafen) -> void:
	var b: TotenhafenBallast = TotenhafenBallast.new()
	b.name = "Ballast"
	owner_t.add_child(b)
	b.setup(owner_t)


func setup(owner_t: Totenhafen) -> void:
	t = owner_t
	add_to_group(&"totenhafen_ballast")
	_bcfg = t.cfg.get("ballast", {})
	if _bcfg.has("dump"):
		dump = t.place(BallastDump.new(), "BallastDump", _bcfg["dump"], float(_bcfg.get("dump_yaw", 180.0))) as BallastDump
	GLBus.ballast_loaded.connect(_on_loaded)
	GLBus.ballast_dumped.connect(_on_dumped)


## Pure (tested): is the egg's ballast thread done?
static func choice_done(loaded: int, dumped: int) -> bool:
	return loaded >= 1 and dumped >= 3


## Pure (tested): which squad line plays: the preferred character's when they are in the match, else the first
## present character's, else the first line. `lines` are ids like "DUT_BALLAST_LOAD_01".
static func pick_line(lines: Array, present_codes: Array, prefer: String) -> String:
	if lines.is_empty():
		return ""
	for l: Variant in lines:
		if str(l).begins_with(prefer + "_") and present_codes.has(prefer):
			return str(l)
	for l: Variant in lines:
		if present_codes.has(str(l).get_slice("_", 0)):
			return str(l)
	return str(lines[0])


func _present_codes() -> Array:
	var out: Array = []
	for pid: int in GameState.player_ids:
		var c: String = CODES.get(GameState.character_of(pid), "")
		if c != "" and not out.has(c):
			out.append(c)
	return out


func _counts() -> Array:
	return [int(GameState.flags.get(&"ballast_loaded", 0)), int(GameState.flags.get(&"ballast_dumped", 0))]


func _on_loaded(total: int, _pid: int) -> void:
	if not Net.is_authority():
		return
	if total > 1:
		GLVO.play_category(&"OPR", "BALLAST_LOAD")
	var line: String = pick_line(_bcfg.get("squad_load", []), _present_codes(), "DUT")
	if line != "":
		get_tree().create_timer(3.0).timeout.connect(func() -> void: GLVO.play(StringName(line)))
	_check_done()


func _on_dumped(total: int, _pid: int) -> void:
	if not Net.is_authority():
		return
	GLVO.play_category(&"OPR", "BALLAST_DUMP")
	RoundManager.extra_spawn(&"glasshide", int(_bcfg.get("glasshide_per_dump", 1)))
	var line: String = ""
	if total == 3 and _present_codes().has("PEG"):
		line = str(_bcfg.get("squad_dump_third", ""))
	if line == "":
		line = pick_line(_bcfg.get("squad_dump", []), _present_codes(), "DEA")
	if line != "":
		get_tree().create_timer(3.2).timeout.connect(func() -> void: GLVO.play(StringName(line)))
	if total >= int(_bcfg.get("shard_after_dumps", 3)) and not shard_spawned:
		spawn_shard()
		Net.mirror(self, &"spawn_shard")
	_check_done()


func _check_done() -> void:
	var c: Array = _counts()
	if choice_done(int(c[0]), int(c[1])) and not GameState.has_flag(&"lf_ballast_done"):
		GameState.set_flag(&"lf_ballast_done", true)


## The Undertow's shard on the sea stairs (every peer; fork-built UndertowParts places it).
func spawn_shard() -> void:
	if shard_spawned:
		return
	shard_spawned = true
	var path: String = "res://gravelight/world/map02/undertow_parts.gd"
	if ResourceLoader.exists(path):
		var s: GDScript = load(path) as GDScript
		if s != null and Totenhafen._has_static(s, "spawn_shard"):
			s.call(&"spawn_shard", t)
	t.banner("Something glints on the sea stairs", 3.0)


func _process(delta: float) -> void:
	if not Net.is_authority():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	var wait_ms: int = int(float(_bcfg.get("respawn_seconds", 20.0)) * 1000.0)
	for n: Node in get_tree().get_nodes_in_group(&"ballast_coffins"):
		var c: BallastCoffin = n as BallastCoffin
		if c == null or not c.delivered or Time.get_ticks_msec() - c.gone_at_ms < wait_ms:
			continue
		var spot: Array = free_spot(c)
		if spot.is_empty():
			continue
		var pos: Vector3 = Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
		var unit: String = str(spot[3]) if spot.size() > 3 else c.unit
		c.respawn_at(pos, unit)
		Net.mirror(c, &"respawn_at", [pos, unit])


## A pallet spot with no coffin on it (round-robin from coffin_spots), [] when every pallet is taken.
func free_spot(_for: BallastCoffin) -> Array:
	var spots: Array = (_bcfg.get("coffin_spots", []) as Array) + (_bcfg.get("pallet_spots", []) as Array)
	for k: int in spots.size():
		var s: Array = spots[(_spot_i + k) % spots.size()]
		var p: Vector3 = Vector3(float(s[0]), float(s[1]), float(s[2]))
		var taken: bool = false
		for n: Node in get_tree().get_nodes_in_group(&"ballast_coffins"):
			var c: BallastCoffin = n as BallastCoffin
			if c != null and not c.delivered and c.carrier == 0 and c.global_position.distance_to(p) < 1.5:
				taken = true
				break
		if not taken:
			_spot_i = (_spot_i + k + 1) % spots.size()
			return s
	return []
