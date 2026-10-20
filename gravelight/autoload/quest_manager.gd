extends Node
## Data-driven quest step graphs (docs/EASTER_EGGS.md §1). A quest is a DAG of steps; a step becomes active
## when everything in its `requires` is complete.
## Step types: collect, sequence, flag, interact, kill_condition, kill_count, holdout, chase, build, cutscene.
## World objects talk to the QuestManager through collect() / submit() / interact() / give_item() / fail().
## Randomness: one match seed -> one derived RNG per (quest, key) (EASTER_EGGS.md §5); `quest reveal` prints it.
## Authority: quest state lives here (host-side in co-op). A co-op client loads the same definitions and seed,
## mirrors the state from the host's snapshot (apply_net_state) and never advances anything itself: steps
## triggered by any player run here on the host. Presentation actions (subtitled lines, banners, profile
## rewards) are re-run on every client (run_client_actions), and cutscene runners play there too.

signal quest_loaded(quest_id: StringName)
signal sequence_progress(quest_id: StringName, step_id: StringName, index: int)
signal sequence_reset(quest_id: StringName, step_id: StringName)
signal holdout_changed(quest_id: StringName, step_id: StringName, running: bool)

const STEP_TYPES: PackedStringArray = ["collect", "sequence", "flag", "kill_count", "interact", "kill_condition",
	"holdout", "chase", "build", "cutscene"]

var match_seed: int = 0
var pending_seed: int = -1        # `quest seed <n>`: used by the next match
var _quests: Dictionary = {}      # quest_id -> definition
var _state: Dictionary = {}       # quest_id -> {step_id -> {"status": "locked|active|complete", "progress": Variant}}
var _random: Dictionary = {}      # quest_id -> {key -> value}
var checkpoints: Dictionary = {}  # quest_id -> Array[step_id] (save points this match)
var _last_kill_weapon: StringName = &""
var _last_kill_by: int = 0
var _holdouts: Dictionary = {}    # "qid/sid" -> runtime dict
var _vo_originals: Dictionary = {} # line id -> original text (code substitutions are per match)


func _ready() -> void:
	GLBus.match_started.connect(_on_match_started)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at)
	GLBus.buildable_completed.connect(_on_buildable_completed)
	GLBus.item_picked_up.connect(_on_item_picked_up)


func _on_match_started(_m: StringName) -> void:
	clear()
	match_seed = pending_seed if pending_seed >= 0 else randi()
	pending_seed = -1
	if Net.is_online():
		return   # co-op: each player's own profile decides their egg slot (MapRoot._apply_coop_egg_slots)
	# Permanent Map 1 reward: a 5th perk slot once the main egg has been completed on this profile.
	var rewards: Dictionary = ProfileSave.profile.get("egg_rewards", {})
	for pid: int in GameState.player_ids:
		if GameState.map_id == &"map01_kaltenbrunn" and bool(rewards.get("map01_perk_slot_5", false)):
			PerkManager._bonus_slots[pid] = 1
		else:
			PerkManager._bonus_slots.erase(pid)


func clear() -> void:
	for key: Variant in _holdouts.keys():
		RoundManager.set_hold(StringName("quest_" + str(key)), false)
	_quests.clear()
	_state.clear()
	_random.clear()
	checkpoints.clear()
	_holdouts.clear()
	_restore_vo()


func load_quest(path: String) -> StringName:
	var def: Dictionary = GLData.load_json(path)
	var errors: PackedStringArray = validate(def)
	if not errors.is_empty():
		push_error("Quest %s invalid: %s" % [path, ", ".join(errors)])
		return &""
	var qid: StringName = StringName(def["id"])
	_quests[qid] = def
	_state[qid] = {}
	_random[qid] = roll_random(def.get("random", {}), match_seed, String(qid))
	_apply_vo_substitutions(qid, def)
	for step: Dictionary in def["steps"]:
		_state[qid][StringName(step["id"])] = {"status": "locked", "progress": null}
	if Net.is_authority():
		_refresh(qid)
	quest_loaded.emit(qid)
	return qid


# ---------------------------------------------------------------- seeding (EASTER_EGGS.md §5)

## Deterministic RNG for one system of one quest.
static func derived_rng(seed_value: int, quest_id: String, key: String) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = hash("%d:%s:%s" % [seed_value, quest_id, key])
	return r


## Rolls every entry of a quest's "random" block. Kinds: pick_per_group, digits, permutation.
static func roll_random(spec: Dictionary, seed_value: int, quest_id: String) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in spec.keys():
		var e: Dictionary = spec[key]
		var r: RandomNumberGenerator = derived_rng(seed_value, quest_id, str(key))
		match str(e.get("type", "")):
			"pick_per_group":
				var picks: Dictionary = {}
				for g: Variant in (e["groups"] as Dictionary).keys():
					var options: Array = e["groups"][g]
					picks[str(g)] = str(options[r.randi_range(0, options.size() - 1)])
				out[str(key)] = picks
			"digits":
				var s: String = ""
				for i: int in int(e.get("count", 6)):
					s += str(r.randi_range(0, 9))
				out[str(key)] = s
			"permutation":
				var items: Array = (e["items"] as Array).duplicate()
				for i: int in range(items.size() - 1, 0, -1):
					var j: int = r.randi_range(0, i)
					var tmp: Variant = items[i]
					items[i] = items[j]
					items[j] = tmp
				out[str(key)] = items
	return out


func random_value(qid: StringName, key: String) -> Variant:
	return (_random.get(qid, {}) as Dictionary).get(key, null)


func reveal() -> String:
	var out: PackedStringArray = ["match seed %d" % match_seed]
	for qid: Variant in _random.keys():
		for key: Variant in (_random[qid] as Dictionary).keys():
			out.append("  %s.%s = %s" % [qid, key, str(_random[qid][key])])
	return "\n".join(out)


## Quest data can ask for spoken digits: {"vo_substitute": {"FAS_M1_CODE1_01": {"%d1%": "code:0", ...}}}
func _apply_vo_substitutions(qid: StringName, def: Dictionary) -> void:
	var subs: Dictionary = def.get("vo_substitute", {})
	for line_id: Variant in subs.keys():
		if not GLVO.lines.has(str(line_id)):
			continue
		var rec: Dictionary = GLVO.lines[str(line_id)]
		if not _vo_originals.has(str(line_id)):
			_vo_originals[str(line_id)] = str(rec["text"])
		var text: String = str(_vo_originals[str(line_id)])
		for token: Variant in (subs[line_id] as Dictionary).keys():
			var src: PackedStringArray = str(subs[line_id][token]).split(":")
			var value: String = str(random_value(qid, src[0]))
			if src.size() > 1 and value.length() > int(src[1]):
				value = value[int(src[1])]
			text = text.replace(str(token), value)
		rec["text"] = text


func _restore_vo() -> void:
	for line_id: Variant in _vo_originals.keys():
		if GLVO.lines.has(str(line_id)):
			GLVO.lines[str(line_id)]["text"] = _vo_originals[line_id]
	_vo_originals.clear()


# ---------------------------------------------------------------- queries

func has_quest(qid: StringName) -> bool:
	return _quests.has(qid)


func status(qid: StringName, step_id: StringName) -> String:
	if not _state.has(qid) or not _state[qid].has(step_id):
		return ""
	return str(_state[qid][step_id]["status"])


func is_active(qid: StringName, step_id: StringName) -> bool:
	return status(qid, step_id) == "active"


func is_step_done(qid: StringName, step_id: StringName) -> bool:
	return status(qid, step_id) == "complete"


func is_complete(qid: StringName) -> bool:
	if not _state.has(qid):
		return false
	for sid: Variant in _state[qid].keys():
		if str(_state[qid][sid]["status"]) != "complete":
			return false
	return true


func progress(qid: StringName, step_id: StringName) -> Variant:
	return _state[qid][step_id]["progress"] if _state.has(qid) and _state[qid].has(step_id) else null


func step_def(qid: StringName, sid: StringName) -> Dictionary:
	return _step(qid, sid)


func describe() -> String:
	var out: PackedStringArray = []
	for qid: Variant in _quests.keys():
		out.append("%s:" % qid)
		for step: Dictionary in _quests[qid]["steps"]:
			var sid: StringName = StringName(step["id"])
			var extra: String = ("  [%s]" % step["debug_skip"]) if step.has("debug_skip") else ""
			out.append("  %-18s %-9s %s%s" % [sid, status(qid, sid), str(progress(qid, sid)), extra])
	return "\n".join(out)


## Is a chase step for this actor active right now? (the crate asks before a drummer move)
func is_chase_armed(actor: StringName) -> Array:
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "chase"):
			if StringName(str(step["params"].get("actor", ""))) == actor:
				return [StringName(qid), StringName(step["id"])]
	return []


# ---------------------------------------------------------------- items

func has_item(item_id: StringName) -> bool:
	return GameState.has_flag(StringName("item_" + String(item_id)))


func give_item(item_id: StringName, by_player: int = 1) -> void:
	if not Net.is_authority():
		return
	GameState.set_flag(StringName("item_" + String(item_id)), true)
	GLBus.item_picked_up.emit(item_id, by_player)


func take_item(item_id: StringName) -> void:
	if not Net.is_authority():
		return
	GameState.set_flag(StringName("item_" + String(item_id)), false)


# ---------------------------------------------------------------- inputs from the world

## A tagged item was picked up (notes, radios heard, cylinders...). Returns true if a step used it.
func collect(tag: StringName, item_id: StringName) -> bool:
	if not Net.is_authority():
		return false
	var used: bool = false
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "collect"):
			if StringName(step["params"]["tag"]) != tag:
				continue
			var st: Dictionary = _state[qid][StringName(step["id"])]
			var got: Array = st["progress"] if st["progress"] is Array else []
			if got.has(item_id):
				continue
			got.append(item_id)
			st["progress"] = got
			used = true
			_run_actions(qid, step.get("on_item", []))
			if got.size() >= int(step["params"]["count"]):
				_complete(qid, StringName(step["id"]))
	return used


## An ordered input on a target (radio frequency, switchboard digit, bell note). Returns
## {"result": "ok"|"wrong"|"done"|"inactive", "index": n} where index = inputs accepted so far.
func submit(target: StringName, value: String) -> Dictionary:
	if not Net.is_authority():
		return predict_submit(target, value)
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "sequence"):
			if StringName(step["params"]["target"]) != target:
				continue
			var sid: StringName = StringName(step["id"])
			var st: Dictionary = _state[qid][sid]
			var idx: int = int(st["progress"]) if st["progress"] != null else 0
			var expected: Array = sequence_inputs(qid, sid)
			if str(expected[idx]) == value:
				idx += 1
				st["progress"] = idx
				sequence_progress.emit(qid, sid, idx)
				if idx >= expected.size():
					_complete(qid, sid)
					return {"result": "done", "index": idx}
				_run_actions(qid, step.get("on_input_ok", []))
				return {"result": "ok", "index": idx}
			st["progress"] = 0
			var reset: Dictionary = step.get("reset", {})
			_run_actions(qid, reset.get("actions", []))
			sequence_reset.emit(qid, sid)
			GLBus.quest_step_failed.emit(qid, sid, &"wrong_input")
			return {"result": "wrong", "index": 0}
	return {"result": "inactive", "index": 0}


## The expected inputs of a sequence step: literal "inputs", or "inputs_from" a random value.
func sequence_inputs(qid: StringName, sid: StringName) -> Array:
	var p: Dictionary = _step(qid, sid).get("params", {})
	if p.has("inputs"):
		return p["inputs"]
	var v: Variant = random_value(qid, str(p.get("inputs_from", "")))
	if v is String:
		var out: Array = []
		for c: String in (v as String):
			out.append(c)
		return out
	return v if v is Array else []


## Interacting with a quest target (altar, crucible, phonograph, tag...). Returns true if a step used it.
func interact(target: StringName, by_player: int = 1) -> bool:
	if not Net.is_authority():
		return false
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "interact"):
			var p: Dictionary = step["params"]
			if StringName(p["target"]) != target:
				continue
			if p.has("requires_item") and not has_item(StringName(p["requires_item"])):
				continue
			_complete(qid, StringName(step["id"]))
			return true
		for step2: Dictionary in _active_steps(qid, "holdout"):
			if StringName(str(step2["params"].get("start_target", ""))) == target and not _holdouts.has("%s/%s" % [qid, step2["id"]]):
				_start_holdout(qid, StringName(step2["id"]))
				return true
	return false


## Can this target do something right now? (for prompts)
func interact_ready(target: StringName) -> bool:
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "interact"):
			var p: Dictionary = step["params"]
			if StringName(p["target"]) == target and (not p.has("requires_item") or has_item(StringName(p["requires_item"]))):
				return true
		for step2: Dictionary in _active_steps(qid, "holdout"):
			if StringName(str(step2["params"].get("start_target", ""))) == target and not _holdouts.has("%s/%s" % [qid, step2["id"]]):
				return true
	return false


## A step failed in a recoverable way (drummer escaped, holdout abandoned, Foreman killed in the wrong place).
func fail(qid: StringName, sid: StringName, reason: StringName) -> void:
	if not Net.is_authority():
		return
	var step: Dictionary = _step(qid, sid)
	if step.is_empty():
		return
	if str(step["type"]) != "kill_condition":
		_state[qid][sid]["progress"] = null
	_run_actions(qid, (step.get("fail", {}) as Dictionary).get(String(reason), (step.get("fail", {}) as Dictionary).get("default", [])))
	GLBus.quest_step_failed.emit(qid, sid, reason)


func _on_enemy_killed(_enemy_id: StringName, _limb: StringName, weapon_id: StringName, by_player: int) -> void:
	_last_kill_weapon = weapon_id
	_last_kill_by = by_player


func _on_enemy_killed_at(enemy_id: StringName, pos: Vector3, by_player: int) -> void:
	if not Net.is_authority():
		return
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "kill_count"):
			if by_player <= 0:
				continue
			var p: Dictionary = step["params"]
			if p.has("weapon"):
				var weapons: Array = p["weapon"] if p["weapon"] is Array else [p["weapon"]]
				if not weapons.has(String(_last_kill_weapon)):
					continue
			if p.has("center"):
				var c: Array = p["center"]
				if pos.distance_to(Vector3(float(c[0]), float(c[1]), float(c[2]))) > float(p.get("radius", 15.0)):
					if not bool(_state[qid][StringName(step["id"])].get("warned", false)):
						_state[qid][StringName(step["id"])]["warned"] = true
						_run_actions(qid, step.get("on_out_of_range", []))
					continue
			var st: Dictionary = _state[qid][StringName(step["id"])]
			st["progress"] = (int(st["progress"]) if st["progress"] != null else 0) + 1
			if int(st["progress"]) >= kill_target(step):
				_complete(qid, StringName(step["id"]))
		for step2: Dictionary in _active_steps(qid, "kill_condition"):
			var p2: Dictionary = step2["params"]
			if StringName(p2["enemy"]) != enemy_id:
				continue
			var zone_ok: bool = not p2.has("zone") or ZoneVolume.zone_at(get_tree(), pos) == StringName(p2["zone"])
			var flag_ok: bool = not p2.has("world_flag") or GameState.has_flag(StringName(p2["world_flag"]))
			if zone_ok and flag_ok:
				_complete(qid, StringName(step2["id"]))
			else:
				fail(StringName(qid), StringName(step2["id"]), &"conditions_unmet")


func kill_target(step: Dictionary) -> int:
	var p: Dictionary = step["params"]
	return int(p["count"]) + int(p.get("per_extra_player", 0)) * maxi(0, GameState.player_ids.size() - 1)


func _on_buildable_completed(buildable_id: StringName, _by: int) -> void:
	if not Net.is_authority():
		return
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "build"):
			if StringName(step["params"]["buildable"]) == buildable_id:
				_complete(qid, StringName(step["id"]))


func _on_item_picked_up(item_id: StringName, _by: int) -> void:
	if not Net.is_authority():
		return
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "chase"):
			if StringName(str(step["params"].get("item", ""))) == item_id:
				_complete(qid, StringName(step["id"]))


## GameState calls this when a flag changes.
func on_flag(flag: StringName) -> void:
	if not Net.is_authority():
		return
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "flag"):
			if StringName(step["params"]["flag"]) == flag:
				_complete(qid, StringName(step["id"]))


## Runners (cutscenes) and world objects finish their own steps through this.
func complete_step(qid: StringName, sid: StringName) -> void:
	if Net.is_authority() and is_active(qid, sid):
		_complete(qid, sid)


# ---------------------------------------------------------------- holdouts (Heartstorm)

func holdout_state(qid: StringName, sid: StringName) -> Dictionary:
	return _holdouts.get("%s/%s" % [qid, sid], {})


func _start_holdout(qid: StringName, sid: StringName) -> void:
	var key: String = "%s/%s" % [qid, sid]
	_holdouts[key] = {"qid": qid, "sid": sid, "t": 0.0, "empty": 0.0, "wave_t": 2.0, "fired": {}}
	RoundManager.set_hold(StringName("quest_" + key), true)
	_run_actions(qid, _step(qid, sid).get("on_holdout_start", []))
	holdout_changed.emit(qid, sid, true)


func _end_holdout(key: String) -> void:
	RoundManager.set_hold(StringName("quest_" + key), false)
	var h: Dictionary = _holdouts[key]
	_holdouts.erase(key)
	holdout_changed.emit(h["qid"], h["sid"], false)


func _process(delta: float) -> void:
	if not Net.is_authority():
		return
	for key: Variant in _holdouts.keys():
		var h: Dictionary = _holdouts[key]
		var qid: StringName = h["qid"]
		var sid: StringName = h["sid"]
		var p: Dictionary = _step(qid, sid).get("params", {})
		h["t"] = float(h["t"]) + delta
		var t: float = float(h["t"])
		# timed lines / events: {"5": [actions], ...}
		var timeline: Dictionary = p.get("timeline", {})
		for mark: Variant in timeline.keys():
			if t >= float(mark) and not (h["fired"] as Dictionary).has(mark):
				h["fired"][mark] = true
				_run_actions(qid, timeline[mark])
		# waves
		h["wave_t"] = float(h["wave_t"]) - delta
		if float(h["wave_t"]) <= 0.0:
			h["wave_t"] = float(p.get("wave_every", 8.0))
			_spawn_wave(p)
		# abort if every player leaves the zone (or is down) for too long
		var inside: bool = false
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var pl: Player = n as Player
			if pl != null and pl.is_alive() and ZoneVolume.zone_at(get_tree(), pl.global_position) == StringName(p.get("zone", "")):
				inside = true
		h["empty"] = 0.0 if inside else float(h["empty"]) + delta
		if float(h["empty"]) >= float(p.get("abort_after", 10.0)):
			_end_holdout(str(key))
			fail(qid, sid, &"abandoned")
			continue
		if t >= float(p.get("duration", 120.0)):
			_end_holdout(str(key))
			_complete(qid, sid)


func _spawn_wave(p: Dictionary) -> void:
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir == null:
		return
	var pts: Array = []
	for v: Variant in p.get("points", []):
		var a: Array = v
		pts.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	var solo: bool = GameState.is_solo()
	var special: String = str(p.get("wave_special", ""))
	var n_special: int = int(p.get("wave_special_solo", 3)) if solo else int(p.get("wave_special_coop", 5))
	if special != "" and dir.has_method("spawn_special"):
		dir.call("spawn_special", StringName(special), n_special, pts)
	elif dir.has_method("spawn_burst"):
		dir.call("spawn_burst", pts, n_special)
	if dir.has_method("spawn_burst"):
		dir.call("spawn_burst", pts, int(p.get("wave_gangers", 3)))


## Summons a boss (other systems provide ZombieDirector.summon_boss); falls back to a tough Gänger stand-in.
func summon_boss(enemy_id: StringName, at: Vector3) -> void:
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir == null:
		return
	if dir.has_method("summon_boss"):
		dir.call("summon_boss", enemy_id, at)
		return
	# Fallback (no boss implementation): a Gänger wearing the boss's id so quest kill checks still work.
	var before: Array = (dir as ZombieDirector).active_zombies()
	(dir as ZombieDirector).spawn_burst([at], 1)
	for z: Zombie in (dir as ZombieDirector).active_zombies():
		if not before.has(z):
			z.enemy_id = enemy_id
			z.max_hp *= 3.0
			z.hp = z.max_hp
			var restore: Callable = func(_e: StringName, _l: StringName, _w: StringName, _b: int) -> void: pass
			restore = func(e: StringName, _l: StringName, _w: StringName, _b: int) -> void:
				if e == enemy_id and not z.is_active():
					z.enemy_id = &"ganger"
					GLBus.enemy_killed.disconnect(restore)
			GLBus.enemy_killed.connect(restore, CONNECT_DEFERRED)
	GLBus.boss_spawned.emit(enemy_id)


func boss_alive(enemy_id: StringName) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"bosses"):
		if n.get("enemy_id") == enemy_id and n.has_method("is_active") and bool(n.call("is_active")):
			return true
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if z.enemy_id == enemy_id:
				return true
	return false


# ---------------------------------------------------------------- graph

func _active_steps(qid: Variant, type: String) -> Array:
	var out: Array = []
	for step: Dictionary in _quests[qid]["steps"]:
		if str(step["type"]) == type and is_active(qid, StringName(step["id"])):
			out.append(step)
	return out


func _refresh(qid: StringName) -> void:
	var changed: bool = true
	while changed:
		changed = false
		for step: Dictionary in _quests[qid]["steps"]:
			var sid: StringName = StringName(step["id"])
			if status(qid, sid) != "locked":
				continue
			var ready: bool = true
			for r: Variant in step.get("requires", []):
				if not is_step_done(qid, StringName(r)):
					ready = false
			if ready:
				_state[qid][sid]["status"] = "active"
				changed = true
				_run_actions(qid, step.get("on_start", []))
				if str(step["type"]) == "flag" and GameState.has_flag(StringName(step["params"]["flag"])):
					_complete(qid, sid)
				elif str(step["type"]) == "cutscene":
					_start_cutscene(qid, sid)


func _start_cutscene(qid: StringName, sid: StringName) -> void:
	var p: Dictionary = _step(qid, sid).get("params", {})
	var path: String = str(p.get("runner", ""))
	if path == "" or not ResourceLoader.exists(path):
		_complete(qid, sid)
		return
	if Net.replicating():
		Net.mirror(Net.session, &"_quest_cutscene", [path, String(qid), String(sid), p])
	var runner: Node = (load(path) as GDScript).new() as Node
	runner.set("quest_id", qid)
	runner.set("step_id", sid)
	runner.set("params", p)
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child.call_deferred(runner)


func _complete(qid: StringName, sid: StringName) -> void:
	if is_step_done(qid, sid):
		return
	_state[qid][sid]["status"] = "complete"
	var step: Dictionary = _step(qid, sid)
	_run_actions(qid, step.get("on_complete", []))
	GLBus.quest_step_completed.emit(qid, sid)
	_refresh(qid)
	if is_complete(qid):
		_run_actions(qid, _quests[qid].get("on_complete", []))
		GLBus.quest_completed.emit(qid)


func _step(qid: StringName, sid: StringName) -> Dictionary:
	if not _quests.has(qid):
		return {}
	for step: Dictionary in _quests[qid]["steps"]:
		if StringName(step["id"]) == sid:
			return step
	return {}


## Actions: {"flag": name} {"vo": id} {"vo_list": [ids]} {"vo_category": [speaker, category]} {"vo_player": category}
## {"save_point": true} {"unlock_map": id} {"xp": n} {"archive": id} {"item": id} {"take_item": id}
## {"banner": text} {"grant_all_perks": true} {"egg_reward": key} {"profile_list": [key, value]}
## {"summon_boss": [enemy_id, x, y, z]} {"shake": strength}
func _run_actions(qid: StringName, actions: Array) -> void:
	for a: Dictionary in actions:
		if Net.replicating():
			var pres: Dictionary = client_subset(a)
			if not pres.is_empty():
				Net.mirror(Net.session, &"_quest_actions", [pres])
		if a.has("flag"):
			GameState.set_flag(StringName(a["flag"]), true)
		if a.has("vo"):
			GLVO.play(StringName(a["vo"]))
		if a.has("vo_list"):
			for id: Variant in a["vo_list"]:
				GLVO.play(StringName(str(id)))
		if a.has("vo_category"):
			var vc: Array = a["vo_category"]
			GLVO.play_category(StringName(str(vc[0])), str(vc[1]), 1.0)
		if a.has("vo_player"):
			GLVO.say_player(str(a["vo_player"]), 1.0)
		if a.has("save_point"):
			if not checkpoints.has(qid):
				checkpoints[qid] = []
			(checkpoints[qid] as Array).append(qid)
		if a.has("unlock_map"):
			ProfileSave.unlock_map(StringName(a["unlock_map"]))
		if a.has("xp"):
			ProfileSave.add_xp(int(a["xp"]))
		if a.has("archive"):
			ProfileSave.add_intel(StringName(a["archive"]))
		if a.has("item"):
			give_item(StringName(a["item"]))
		if a.has("take_item"):
			take_item(StringName(a["take_item"]))
		if a.has("banner"):
			var hud: Node = get_tree().get_first_node_in_group(&"hud")
			if hud != null:
				hud.call("show_banner", str(a["banner"]), 3.0)
		if a.has("grant_all_perks"):
			for pid: int in GameState.player_ids:
				PerkManager.grant_all(pid)
		if a.has("egg_reward"):
			if not ProfileSave.profile.has("egg_rewards"):
				ProfileSave.profile["egg_rewards"] = {}
			ProfileSave.profile["egg_rewards"][str(a["egg_reward"])] = true
			if str(a["egg_reward"]) == "map01_perk_slot_5":
				for pid: int in GameState.player_ids:
					PerkManager._bonus_slots[pid] = 1
			ProfileSave.save_profile()
		if a.has("profile_list"):
			var pl: Array = a["profile_list"]
			var list: Array = ProfileSave.profile.get(str(pl[0]), [])
			if not list.has(pl[1]):
				list.append(pl[1])
			ProfileSave.profile[str(pl[0])] = list
			ProfileSave.save_profile()
		if a.has("summon_boss"):
			var sb: Array = a["summon_boss"]
			summon_boss(StringName(str(sb[0])), Vector3(float(sb[1]), float(sb[2]), float(sb[3])))
		if a.has("shake"):
			for n: Node in get_tree().get_nodes_in_group(&"players"):
				n.set("_shake", float(a["shake"]))


# ---------------------------------------------------------------- debug

func debug_complete(qid: StringName, sid: StringName) -> bool:
	if not Net.is_authority() or not _state.has(qid) or not _state[qid].has(sid):
		return false
	_complete(qid, sid)
	return true


## Completes every prerequisite of a step (recursively) so the step becomes active.
func debug_skipto(qid: StringName, sid: StringName) -> bool:
	var step: Dictionary = _step(qid, sid)
	if step.is_empty():
		return false
	for r: Variant in step.get("requires", []):
		debug_skipto(qid, StringName(r))
		debug_complete(qid, StringName(r))
	return true


func debug_reset(qid: StringName, sid: StringName = &"") -> void:
	if not Net.is_authority() or not _quests.has(qid):
		return
	if sid != &"":
		if _state[qid].has(sid):
			_state[qid][sid] = {"status": "locked", "progress": null}
	else:
		for s: Variant in _state[qid].keys():
			_state[qid][s] = {"status": "locked", "progress": null}
	_refresh(qid)


# ---------------------------------------------------------------- co-op (M7)

## Host -> clients: everything a client needs to show the quest (prompts, glows, HUD) without running it.
func net_state() -> Dictionary:
	return {"s": _state, "c": checkpoints, "h": _holdouts}


func apply_net_state(d: Dictionary) -> void:
	_state = (d.get("s", {}) as Dictionary).duplicate(true)
	checkpoints = (d.get("c", {}) as Dictionary).duplicate(true)
	_holdouts = (d.get("h", {}) as Dictionary).duplicate(true)


## A client's guess at what submit() will answer (UIs give feedback right away); the host decides. The local
## progress moves on optimistically so quick inputs predict well; the next snapshot corrects it.
func predict_submit(target: StringName, value: String) -> Dictionary:
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "sequence"):
			if StringName(step["params"]["target"]) != target:
				continue
			var sid: StringName = StringName(step["id"])
			var st: Dictionary = _state[qid][sid]
			var idx: int = int(st["progress"]) if st["progress"] != null else 0
			var expected: Array = sequence_inputs(qid, sid)
			if idx < expected.size() and str(expected[idx]) == value:
				st["progress"] = idx + 1
				return {"result": "done" if idx + 1 >= expected.size() else "ok", "index": idx + 1}
			st["progress"] = 0
			return {"result": "wrong", "index": 0}
	return {"result": "inactive", "index": 0}


## The parts of an action every player sees or keeps: lines picked per peer, banners, shakes, profile rewards.
static func client_subset(a: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ["vo_category", "vo_player", "unlock_map", "xp", "archive", "egg_reward", "profile_list", "banner", "shake"]:
		if a.has(k):
			out[k] = a[k]
	return out


## Client: one action's presentation and profile parts (the host ran the rest).
func run_client_actions(a: Dictionary) -> void:
	if a.has("vo_category"):
		var vc: Array = a["vo_category"]
		GLVO.play_category(StringName(str(vc[0])), str(vc[1]), 1.0)
	if a.has("vo_player"):
		GLVO.say_player(str(a["vo_player"]), 1.0)
	if a.has("unlock_map"):
		ProfileSave.unlock_map(StringName(a["unlock_map"]))
	if a.has("xp"):
		ProfileSave.add_xp(int(a["xp"]))
	if a.has("archive"):
		ProfileSave.add_intel(StringName(a["archive"]))
	if a.has("egg_reward"):
		if not ProfileSave.profile.has("egg_rewards"):
			ProfileSave.profile["egg_rewards"] = {}
		ProfileSave.profile["egg_rewards"][str(a["egg_reward"])] = true
		ProfileSave.save_profile()
	if a.has("profile_list"):
		var pl: Array = a["profile_list"]
		var list: Array = ProfileSave.profile.get(str(pl[0]), [])
		if not list.has(pl[1]):
			list.append(pl[1])
		ProfileSave.profile[str(pl[0])] = list
		ProfileSave.save_profile()
	if a.has("banner"):
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", str(a["banner"]), 3.0)
	if a.has("shake"):
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			n.set("_shake", float(a["shake"]))


# ---------------------------------------------------------------- validation

## Returns a list of problems: missing fields, unknown types, unknown requires, cycles.
static func validate(def: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not def.has("id") or not def.has("steps"):
		errors.append("missing id/steps")
		return errors
	var ids: Dictionary = {}
	for step: Dictionary in def["steps"]:
		if not step.has("id") or not step.has("type"):
			errors.append("step without id/type")
			continue
		ids[str(step["id"])] = step
		if not STEP_TYPES.has(str(step["type"])):
			errors.append("unknown type %s" % step["type"])
	for step: Dictionary in def["steps"]:
		for r: Variant in step.get("requires", []):
			if not ids.has(str(r)):
				errors.append("%s requires unknown %s" % [step.get("id", "?"), r])
	var visiting: Dictionary = {}
	var done: Dictionary = {}
	for sid: Variant in ids.keys():
		if _has_cycle(str(sid), ids, visiting, done):
			errors.append("cycle through %s" % sid)
			break
	return errors


static func _has_cycle(sid: String, ids: Dictionary, visiting: Dictionary, done: Dictionary) -> bool:
	if done.has(sid):
		return false
	if visiting.has(sid):
		return true
	visiting[sid] = true
	for r: Variant in (ids[sid] as Dictionary).get("requires", []):
		if ids.has(str(r)) and _has_cycle(str(r), ids, visiting, done):
			return true
	visiting.erase(sid)
	done[sid] = true
	return false


## Every VO id referenced anywhere in a quest definition (for tests).
static func referenced_vo(def: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if def is Dictionary:
		for k: Variant in (def as Dictionary).keys():
			var v: Variant = def[k]
			if str(k) == "vo" and v is String:
				out.append(v)
			elif str(k) == "vo_list" and v is Array:
				for id: Variant in v:
					out.append(str(id))
			else:
				out.append_array(referenced_vo(v))
	elif def is Array:
		for e: Variant in def:
			out.append_array(referenced_vo(e))
	return out
