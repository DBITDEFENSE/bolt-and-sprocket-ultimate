class_name FirstHints
extends Node
## UPDATE 10 s6 item 7 (DECISIONS T-162; data/gravelight/hints.json): first-time hints, once per profile
## (ProfileSave.profile["hints_seen"][key]), shown as the HUD banner. The same node is the watcher that turns the new
## systems' state into events for the citations (data/gravelight/citations.json): the wing walk, the spring tide, the
## Lodestone's orbit count, a special round surviving, a boss kill, a quest done. MapRoot attaches one per map
## (every peer: hints and citations are the local player's own).
## Polled twice a second (nothing here is time-critical); a node that does not exist (the searchlight until the
## Totenhafen systems land) never fires its hint.

const PATH: String = "res://data/gravelight/hints.json"
const POLL_S: float = 0.5

var map: MapRoot = null
var _poll: float = 0.0
var _age: float = 0.0
var _special_now: bool = false
var _special_round: int = -1
var _spring_round: int = -1
var _wing_given: bool = false
var shown: PackedStringArray = []   # keys shown this match (tests)


static func attach(map_root: MapRoot) -> FirstHints:
	if map_root == null:
		return null
	var fh: FirstHints = FirstHints.new()
	fh.name = "FirstHints"
	map_root.add_child(fh)
	fh.setup(map_root)
	return fh


func setup(map_root: MapRoot) -> void:
	map = map_root
	add_to_group(&"first_hints")
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.quest_completed.connect(_on_quest_completed)
	if GLBus.has_signal(&"spring_tide"):   # T-153's spring tide: the citation is earned when the round it floods ends
		GLBus.connect(&"spring_tide", _on_spring_tide)


# ------------------------------------------------------------------ pure rules (the tests)

static func table() -> Dictionary:
	return GLData.load_json(PATH).get("hints", {})


static func seen(key: String) -> bool:
	return bool((ProfileSave.profile.get("hints_seen", {}) as Dictionary).get(key, false))


static func mark(key: String) -> void:
	if not (ProfileSave.profile.get("hints_seen", null) is Dictionary):
		ProfileSave.profile["hints_seen"] = {}
	ProfileSave.profile["hints_seen"][key] = true
	ProfileSave.save_profile()


## Does this hint belong to `map_id`? (the hint's `map` is a prefix: map04b matches map04b_kranich.)
static func on_map(row: Dictionary, map_id: String) -> bool:
	return map_id.begins_with(str(row.get("map", "\u0000")))


## Is the condition `when` met, given the nodes the caller found (`node`, may be null) and the player's distance to the
## nearest one (`dist`, INF when none) and the clock?
static func met(when: Dictionary, node: Node, dist: float, age_s: float, special: bool) -> bool:
	match str(when.get("kind", "")):
		"prop":
			if node == null:
				return false
			var v: Variant = node.get(str(when.get("prop", "")))
			if v is bool:
				return v
			if v is float or v is int:
				return float(v) > float(when.get("min", 0.0))
			return v != null
		"near":
			return node != null and dist <= float(when.get("m", 4.0))
		"exists":
			return node != null and age_s >= float(when.get("after_s", 0.0))
		"special_round":
			return special
	return false


## Shows hint `key` if it is unseen and on this map. Returns true when it was shown now.
func try_show(key: String) -> bool:
	var row: Dictionary = table().get(key, {})
	if row.is_empty() or seen(key) or map == null or not on_map(row, String(map.map_id)):
		return false
	mark(key)
	shown.append(key)
	if row.has("card"):
		ProfileSave.add_intel(StringName("ARC_HINT_" + key.to_upper()))   # the Archive keeps the rule
	if map.hud != null:
		map.hud.show_banner(str(row.get("text", "")), float(row.get("hold", 6.0)))
	return true


# ------------------------------------------------------------------ the watcher

func _process(delta: float) -> void:
	_age += delta
	_poll += delta
	if _poll < POLL_S or map == null or map.player == null:
		return
	_poll = 0.0
	var tbl: Dictionary = table()
	for key: String in tbl:
		var row: Dictionary = tbl[key]
		if seen(key) or not on_map(row, String(map.map_id)):
			continue
		var when: Dictionary = row.get("when", {})
		var node: Node = null
		var dist: float = INF
		if when.has("group"):
			for n: Node in get_tree().get_nodes_in_group(StringName(str(when["group"]))):
				var d: float = INF
				if n is Node3D:
					d = (n as Node3D).global_position.distance_to(map.player.global_position)
				if node == null or d < dist:
					node = n
					dist = d
		if met(when, node, dist, _age, _special_now):
			try_show(key)
	_poll_citations()


func _poll_citations() -> void:
	var info: Dictionary = {"map": String(map.map_id)}
	if not _wing_given:
		var ww: Node = get_tree().get_first_node_in_group(&"wing_walks")
		if ww != null and ww.has_method("state_of") and int(ww.call("state_of", map.player.player_id)) != 0:
			_wing_given = true
			Citations.fire("wing_walk", info)
	var lg: Node = get_tree().get_first_node_in_group(&"moon_lowg")
	if lg != null:
		var n: int = int(lg.get("orbit_count"))
		if n > 0:
			info["count"] = n
			Citations.fire("orbit", info)


func _on_round_started(round_number: int, special: bool) -> void:
	_special_now = special
	if special:
		_special_round = round_number


func _on_round_ended(round_number: int) -> void:
	if map == null:
		return
	var info: Dictionary = {"map": String(map.map_id)}
	if round_number == _special_round:
		_special_round = -1
		_special_now = false
		Citations.fire("special_survived", info)
	if round_number == _spring_round:
		_spring_round = -1
		Citations.fire("spring_tide", info)


func _on_spring_tide(round_number: int) -> void:
	_spring_round = round_number


func _on_enemy_killed(enemy_id: StringName, _limb: StringName, _weapon: StringName, _by: int) -> void:
	if map != null:
		Citations.fire("boss_killed", {"map": String(map.map_id), "enemy": String(enemy_id)})


func _on_quest_completed(quest_id: StringName) -> void:
	if map != null:
		Citations.fire("quest", {"map": String(map.map_id), "quest": String(quest_id)})
