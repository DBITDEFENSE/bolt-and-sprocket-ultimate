class_name ScripBonuses
extends Node
## In-match Scrip bonuses (T-078, docs/gravelight/ECONOMY.md; numbers in economy.json "bonuses"). A child of the
## Economy autoload. Host / solo only: every payment goes through Economy.grant (no Double Scrip), and each one sends
## GLBus.bonus_awarded so the HUD shows a labelled toast next to the usual +Scrip number (relayed to co-op clients).
##   round pay      every player standing when a round ends: base + per_round x round
##   clean round    extra for a round without a single hit taken, and for one without going down
##   headshot streak  every 5 headshot kills in a row
##   salvage        a kill sometimes drops dog tags (ScripTag) worth Scrip; walk near them to pick them up
## The rules are static functions, unit-tested in gravelight/tests/unit/test_scrip_bonuses.gd.

const TAG_SCRIPT: String = "res://gravelight/world/scrip_tag.gd"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hit: Dictionary = {}       # pid -> true: took a hit this round
var _downed: Dictionary = {}    # pid -> true: went down this round
var _streak: Dictionary = {}    # pid -> headshot kills in a row
var _tags_round: int = 0        # dog tags dropped this round
var _tags: Array[Node] = []
var _said: Dictionary = {}      # "what" / "pid:what" -> true: the first-of-match lines


func _ready() -> void:
	rng.randomize()
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.player_damaged.connect(_on_player_damaged)
	GLBus.player_downed.connect(_on_player_downed)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at)
	GLBus.match_started.connect(func(_m: StringName) -> void: reset())


static func cfg() -> Dictionary:
	return GLData.table("economy").get("bonuses", {})


# ---------------------------------------------------------------- pure rules (tested)

## Round pay for standing at the end of `round_number`.
static func round_pay(round_number: int, c: Dictionary) -> int:
	var rp: Dictionary = c.get("round_pay", {})
	if rp.is_empty() or round_number <= 0:
		return 0
	return mini(int(rp.get("max", 0)), int(rp.get("base", 0)) + int(rp.get("per_round", 0)) * round_number)


## The clean-round extra: [untouched part, no-down part]. A player who went down took a hit, so gets neither.
static func clean_bonus(round_number: int, hit: bool, downed: bool, c: Dictionary) -> Array[int]:
	var cr: Dictionary = c.get("clean_round", {})
	var out: Array[int] = [0, 0]
	if cr.is_empty() or round_number <= 0 or downed:
		return out
	out[1] = int(cr.get("no_down", 0))
	if not hit:
		out[0] = mini(int(cr.get("untouched_max", 999999)), int(cr.get("untouched", 0)) + int(cr.get("untouched_per_round", 0)) * round_number)
	return out


## What a headshot streak of `streak` pays when it lands on a multiple of `every` (0 otherwise).
static func streak_bonus(streak: int, c: Dictionary) -> int:
	var hs: Dictionary = c.get("headshot_streak", {})
	var every: int = int(hs.get("every", 0))
	if every <= 0 or streak <= 0 or streak % every != 0:
		return 0
	return mini(int(hs.get("max", 0)), int(hs.get("base", 0)) + int(hs.get("step", 0)) * (streak / every - 1))


## Chance that a kill on `round_number` drops dog tags.
static func tag_chance(round_number: int, c: Dictionary) -> float:
	var s: Dictionary = c.get("salvage", {})
	if s.is_empty():
		return 0.0
	if round_number >= int(s.get("late_from_round", 9999)):
		return float(s.get("chance_late", 0.0))
	return float(s.get("chance", 0.0))


## Dog tags' worth on `round_number`.
static func tag_value(round_number: int, c: Dictionary) -> int:
	var s: Dictionary = c.get("salvage", {})
	return mini(int(s.get("value_max", 0)), int(s.get("value_base", 0)) + int(s.get("value_per_round", 0)) * maxi(1, round_number))


## Whether a kill drops tags: under the round's and the map's limits, and the roll under the chance.
static func should_drop_tag(round_number: int, dropped_this_round: int, alive: int, roll: float, c: Dictionary) -> bool:
	var s: Dictionary = c.get("salvage", {})
	if s.is_empty() or dropped_this_round >= int(s.get("max_per_round", 0)) or alive >= int(s.get("max_alive", 0)):
		return false
	return roll < tag_chance(round_number, c)


# ---------------------------------------------------------------- match flow

func reset() -> void:
	_hit.clear()
	_downed.clear()
	_streak.clear()
	_tags_round = 0
	_said.clear()
	for t: Node in _tags:
		if is_instance_valid(t):
			t.queue_free()
	_tags.clear()


## Pays a bonus and tells the HUD. Host / solo only (Economy.grant is a no-op elsewhere).
func pay(pid: int, kind: StringName, amount: int, label: String) -> void:
	if amount <= 0 or not Net.is_authority():
		return
	Economy.grant(pid, amount)
	GLBus.bonus_awarded.emit(pid, kind, amount, label)
	_first_lines(pid, kind)


## The Operator's line the first time a match pays a kind of bonus, and a survivor's own line on their first tags.
func _first_lines(pid: int, kind: StringName) -> void:
	var cat: String = {&"untouched": "BONUS_CLEAN", &"headshot_streak": "BONUS_STREAK", &"salvage": "BONUS_SALVAGE"}.get(kind, "")
	if cat == "":
		return
	if not _said.has(cat):
		_said[cat] = true
		GLVO.play_category(&"OPR", cat, 1.0)
	if kind == &"salvage" and not _said.has("%d:salvage" % pid):
		_said["%d:salvage" % pid] = true
		GLVO.say_as(pid, cat, 1.0)


## Player.take_hit on the host for a co-op client's survivor (their health is applied on their own machine, so the
## host never sees player_damaged for them): the hit still spoils their clean round.
func note_hit(pid: int) -> void:
	_hit[pid] = true


func _on_round_started(_r: int, _special: bool) -> void:
	_hit.clear()
	_downed.clear()
	_tags_round = 0


func _on_player_damaged(pid: int, amount: float) -> void:
	if amount > 0.0:
		_hit[pid] = true


func _on_player_downed(pid: int) -> void:
	_downed[pid] = true
	_hit[pid] = true
	_streak[pid] = 0


func _on_round_ended(r: int) -> void:
	if not Net.is_authority() or GameState.phase != GameState.Phase.PLAYING:
		return
	var c: Dictionary = cfg()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.is_companion or p.spectating or p.downed or not Economy.has_account(p.player_id):
			continue
		var pid: int = p.player_id
		pay(pid, &"round_pay", round_pay(r, c), "ROUND %d PAY" % r)
		var clean: Array[int] = clean_bonus(r, bool(_hit.get(pid, false)), bool(_downed.get(pid, false)), c)
		if clean[0] > 0:
			pay(pid, &"untouched", clean[0], "UNTOUCHED")
		if clean[1] > 0:
			pay(pid, &"no_down", clean[1], "ON YOUR FEET")


func _on_enemy_killed(_enemy_id: StringName, limb: StringName, _weapon_id: StringName, by_player: int) -> void:
	if by_player <= 0 or not Net.is_authority():
		return
	if limb != &"head":
		_streak[by_player] = 0
		return
	var s: int = int(_streak.get(by_player, 0)) + 1
	_streak[by_player] = s
	var bonus: int = streak_bonus(s, cfg())
	if bonus > 0:
		pay(by_player, &"headshot_streak", bonus, "%d HEADSHOTS RUNNING" % s)


func _on_enemy_killed_at(_enemy_id: StringName, position: Vector3, by_player: int) -> void:
	if by_player <= 0 or not Net.is_authority() or GameState.phase != GameState.Phase.PLAYING:
		return
	_tags = _tags.filter(func(t: Node) -> bool: return is_instance_valid(t) and t.is_inside_tree())
	var c: Dictionary = cfg()
	var r: int = maxi(1, RoundManager.current_round)
	if not should_drop_tag(r, _tags_round, _tags.size(), rng.randf(), c):
		return
	var t: Node3D = spawn_tag(position, tag_value(r, c))
	if t != null:
		_tags_round += 1


## Drops dog tags worth `value` at `position` (the dev console and tests call it too).
func spawn_tag(position: Vector3, value: int) -> Node3D:
	var parent: Node = _map_node()
	if parent == null or not Net.is_authority():
		return null
	var tag: Node3D = (load(TAG_SCRIPT) as GDScript).new() as Node3D
	tag.set("value", value)
	parent.add_child(tag)
	tag.global_position = position + Vector3.UP * 0.35
	tag.connect(&"collected", _on_tag_collected.bind(value))
	_tags.append(tag)
	if Net.replicating():
		Net.session.spawn_dynamic(tag, TAG_SCRIPT, {"value": value})
	return tag


func _on_tag_collected(by_player: int, value: int) -> void:
	pay(by_player, &"salvage", value, "DOG TAGS")


func tags_alive() -> int:
	return _tags.filter(func(t: Node) -> bool: return is_instance_valid(t)).size()


func _map_node() -> Node:
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir != null and dir.get_parent() != null:
		return dir.get_parent()
	return get_tree().current_scene
