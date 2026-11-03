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
# Story beats (T-086): the context the running actions see ({sid, n: items / inputs so far, by: player id}) and
# the actions waiting for their moment ("after" seconds, or "on_vo" a line's start).
var _ctx: Dictionary = {}
var _pending: Array[Dictionary] = []
var _t: float = 0.0


func _ready() -> void:
	GLBus.match_started.connect(_on_match_started)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at)
	GLBus.buildable_completed.connect(_on_buildable_completed)
	GLBus.item_picked_up.connect(_on_item_picked_up)
	GLBus.vo_line_started.connect(_on_vo_started)
	GLBus.zone_opened.connect(_on_zone_opened_step)   # UPDATE 07 (T-115): flag steps that wait on a zone


func _on_match_started(_m: StringName) -> void:
	clear()
	match_seed = pending_seed if pending_seed >= 0 else randi()
	pending_seed = -1
	if Net.is_online():
		return   # co-op: each player's own profile decides their egg slot (MapRoot._apply_coop_egg_slots)
	# Permanent Map 1 reward: an extra perk slot (cap + 1) once the main egg has been completed on this profile.
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
	if GameState.has_flag(&"holdout"):
		GameState.set_flag(&"holdout", false)
	_pending.clear()
	_ctx = {}
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
	# UPDATE 07 (T-114): a quest spanning Map 4's acts marks the steps of earlier acts done when an act is entered
	# by a skip (the launcher's "skip to Act n"): a step's "act" is the act it lives on; the carry (apply_carry)
	# restores the real progress on a campaign arrival instead.
	# (the map's own block, not RoundManager.act: at load time that still holds the act before)
	var here: int = int(RoundManager.act_block_of(GameState.map_id).get("index", 0))
	for step2: Dictionary in def["steps"]:
		if step2.has("act") and here > 0 and int(step2["act"]) < here:
			_state[qid][StringName(step2["id"])]["status"] = "complete"
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
			"cipher":   # T-153 (Letzte Fahrt): three radios' 4-letter code groups and the order they are keyed
				var c: Dictionary = roll_cipher(e, r)
				out[str(key)] = c
				out[str(key) + "_inputs"] = c["inputs"]
	return out


## A cipher roll (UPDATE 10 C3, T-153): {groups: {radio: "KXRT"}, order: [radio ids in keying order], inputs: [the
## groups' first letters in that order], depth: "<n> FADEN", curtain: "<4 letters>"}. Letters skip I/O/Q (the
## rotor wheels' stencils are easy to read), and the three first letters are distinct.
static func roll_cipher(e: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var alpha: String = str(e.get("alphabet", "ABCDEFGHJKLMNPRSTUVWXYZ"))
	var radios: Array = (e.get("radios", []) as Array).duplicate()
	var groups: Dictionary = {}
	var used_first: Dictionary = {}
	for rid: Variant in radios:
		var g: String = ""
		for i: int in int(e.get("length", 4)):
			var ch: String = alpha[r.randi_range(0, alpha.length() - 1)]
			while i == 0 and used_first.has(ch):
				ch = alpha[r.randi_range(0, alpha.length() - 1)]
			if i == 0:
				used_first[ch] = true
			g += ch
		groups[str(rid)] = g
	for i: int in range(radios.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var tmp: Variant = radios[i]
		radios[i] = radios[j]
		radios[j] = tmp
	var inputs: Array = []
	for rid2: Variant in radios:
		inputs.append(str(groups[str(rid2)])[0])
	var curtain: String = ""
	for i: int in 4:
		curtain += alpha[r.randi_range(0, alpha.length() - 1)]
	return {"groups": groups, "order": radios, "inputs": inputs, "depth": "%d FADEN" % r.randi_range(38, 64), "curtain": curtain}


func random_value(qid: StringName, key: String) -> Variant:
	return (_random.get(qid, {}) as Dictionary).get(key, null)


## Every seeded value of one quest (a copy; the OBJECTIVES tab's Full Guide and map highlights read it).
func random_values(qid: StringName) -> Dictionary:
	return (_random.get(qid, {}) as Dictionary).duplicate(true)


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

## The quests loaded this match (for the bots' objective planner).
func quest_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for qid: Variant in _quests.keys():
		out.append(StringName(qid))
	return out


## A quest's step definitions, in file order.
func steps_of(qid: StringName) -> Array:
	return (_quests.get(qid, {}) as Dictionary).get("steps", [])


## A loaded quest's whole definition ({} unknown): the bots read its "bot_knowledge" block (T-067).
func definition(qid: StringName) -> Dictionary:
	return _quests.get(qid, {})


func display_name_of(qid: StringName) -> String:
	return str((_quests.get(qid, {}) as Dictionary).get("display_name", qid))


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
## `by_player`: who took it (0 unknown): the step's on_item beats can give that survivor the line (T-086).
func collect(tag: StringName, item_id: StringName, by_player: int = 0) -> bool:
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
			_ctx = {"sid": StringName(step["id"]), "n": got.size(), "by": by_player}
			_run_actions(qid, step.get("on_item", []))
			if got.size() >= int(step["params"]["count"]):
				_complete(qid, StringName(step["id"]))
			_ctx = {}
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
				_ctx = {"sid": sid, "n": idx, "by": 0}
				_run_actions(qid, step.get("on_input_ok", []))
				_ctx = {}
				return {"result": "ok", "index": idx}
			st["progress"] = 0
			var reset: Dictionary = step.get("reset", {})
			_ctx = {"sid": sid, "n": idx, "by": 0}
			_run_actions(qid, reset.get("actions", []))
			_ctx = {}
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
			if not flags_met(p):
				continue
			_ctx = {"sid": StringName(step["id"]), "n": -1, "by": by_player}
			_complete(qid, StringName(step["id"]))
			_ctx = {}
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
			if StringName(p["target"]) == target and (not p.has("requires_item") or has_item(StringName(p["requires_item"]))) and flags_met(p):
				return true
		for step2: Dictionary in _active_steps(qid, "holdout"):
			if StringName(str(step2["params"].get("start_target", ""))) == target and not _holdouts.has("%s/%s" % [qid, step2["id"]]):
				return true
	return false


## UPDATE 07 (T-114): an interact step may also wait on world flags ("requires_flags": [names]): the Kranich's ramp
## takes the hangar key and the door code. Pure for the tests.
static func flags_met_in(p: Dictionary, flags: Dictionary) -> bool:
	for f: Variant in p.get("requires_flags", []):
		if not bool(flags.get(StringName(str(f)), false)):
			return false
	return true


func flags_met(p: Dictionary) -> bool:
	return flags_met_in(p, GameState.flags)


## The flags an interact target still needs (for prompts: "needs the hangar key").
func missing_flags(target: StringName) -> PackedStringArray:
	var out: PackedStringArray = []
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "interact"):
			var p: Dictionary = step["params"]
			if StringName(p["target"]) != target:
				continue
			for f: Variant in p.get("requires_flags", []):
				if not GameState.has_flag(StringName(str(f))):
					out.append(str(f))
	return out


# ---------------------------------------------------------------- carry across Map 4's acts (UPDATE 07, T-114)

## What the campaign carries to `next_map` for every quest whose "maps" list names it: the steps already done,
## the rolled randoms (the hangar code stays the same code on the Kranich) and the step progress.
func carry_snapshot(next_map: StringName) -> Dictionary:
	var out: Dictionary = {}
	for qid: Variant in _quests.keys():
		var maps: Array = _quests[qid].get("maps", [])
		if not maps.has(String(next_map)):
			continue
		var done: Array = []
		var prog: Dictionary = {}
		for sid: Variant in _state[qid].keys():
			var st: Dictionary = _state[qid][sid]
			if str(st.get("status", "")) == "complete":
				done.append(String(sid))
			elif st.get("progress") != null:
				prog[String(sid)] = st["progress"]
		out[String(qid)] = {"done": done, "progress": prog, "random": _random[qid].duplicate(true), "checkpoints": checkpoints.get(qid, []).duplicate()}
	return out


## On the next act, after its quests loaded: the carried steps are done (silently: their beats already played),
## the randoms are the same, the progress of the open steps is back. Steps that are open again get their on_start.
func apply_carry(data: Dictionary) -> void:
	for qk: Variant in data.keys():
		var qid: StringName = StringName(str(qk))
		if not _quests.has(qid):
			continue
		var d: Dictionary = data[qk]
		if d.has("random"):
			_random[qid] = (d["random"] as Dictionary).duplicate(true)
			_apply_vo_substitutions(qid, _quests[qid])
		for sid: Variant in d.get("done", []):
			if _state[qid].has(StringName(str(sid))):
				_state[qid][StringName(str(sid))]["status"] = "complete"
		for sid2: Variant in (d.get("progress", {}) as Dictionary).keys():
			if _state[qid].has(StringName(str(sid2))):
				_state[qid][StringName(str(sid2))]["progress"] = (d["progress"] as Dictionary)[sid2]
		if d.has("checkpoints"):
			checkpoints[qid] = (d["checkpoints"] as Array).duplicate()
		if Net.is_authority():
			_refresh(qid)


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
			# UPDATE 07 (T-114): kills in a zone, while a world flag holds (the wind tunnel running)
			if p.has("zone") and ZoneVolume.zone_at(get_tree(), pos) != StringName(str(p["zone"])):
				continue
			if p.has("world_flag") and not GameState.has_flag(StringName(str(p["world_flag"]))):
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
			if flag_step_satisfied(step["params"], flag):
				_complete(qid, StringName(step["id"]))


## A zone opened: flag steps with params.zone complete (UPDATE 07, T-115: the yard's airlock).
func _on_zone_opened_step(_zone: StringName) -> void:
	if not Net.is_authority():
		return
	for qid: Variant in _quests.keys():
		for step: Dictionary in _active_steps(qid, "flag"):
			if step["params"].has("zone") and flag_step_satisfied(step["params"]):
				_complete(qid, StringName(step["id"]))


## Is a `flag` step's condition met? params: {"flag": f} (f is set), {"any": [f...]} (one set), {"all": [f...]}
## (every one set), {"zone": id} (the zone is open). `just` is the flag that just changed (so a step waiting on
## that flag completes even before GameState has it... it does: on_flag runs after the set), unused otherwise.
static func flag_step_satisfied(params: Dictionary, just: StringName = &"") -> bool:
	if params.has("flag"):
		return GameState.has_flag(StringName(params["flag"])) or StringName(params["flag"]) == just
	if params.has("any"):
		for f: Variant in params["any"]:
			if GameState.has_flag(StringName(str(f))) or StringName(str(f)) == just:
				return true
		return false
	if params.has("all"):
		for f: Variant in params["all"]:
			if not (GameState.has_flag(StringName(str(f))) or StringName(str(f)) == just):
				return false
		return true
	if params.has("zone"):
		return GameState.is_zone_open(StringName(params["zone"]))
	return false


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
	GameState.set_flag(&"holdout", true)   # T-142: no relief squad during a holdout
	holdout_changed.emit(qid, sid, true)


func _end_holdout(key: String) -> void:
	RoundManager.set_hold(StringName("quest_" + key), false)
	var h: Dictionary = _holdouts[key]
	_holdouts.erase(key)
	if _holdouts.is_empty() and GameState.has_flag(&"holdout"):
		GameState.set_flag(&"holdout", false)
	holdout_changed.emit(h["qid"], h["sid"], false)


func _process(delta: float) -> void:
	if not Net.is_authority():
		return
	_t += delta
	_tick_pending()
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
				_ctx = {"sid": sid, "n": 0, "by": 0}
				_run_actions(qid, step.get("on_start", []))
				_ctx = {}
				if str(step["type"]) == "flag" and flag_step_satisfied(step["params"]):
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
	GameState.hold_flag_while(&"cutscene", runner)   # T-142: the runner's lifetime is the cutscene
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child.call_deferred(runner)


func _complete(qid: StringName, sid: StringName) -> void:
	if is_step_done(qid, sid):
		return
	_state[qid][sid]["status"] = "complete"
	var step: Dictionary = _step(qid, sid)
	_ctx = {"sid": sid, "n": -1, "by": 0}
	_run_actions(qid, step.get("on_complete", []))
	_ctx = {}
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
## {"banner": text} (with "banner_s": seconds on screen, default 3; T-173) {"grant_all_perks": true} {"perks_max": true} {"tier_all": n} (T-174) {"egg_reward": key} {"profile_list": [key, value]}
## {"summon_boss": [enemy_id, x, y, z]} {"shake": strength}
## Story beats (T-086, EASTER_EGGS.md 1.2): {"vo_squad": category} one random standing survivor says it, never
## over the radio / the Operator (with "exclude_last": true someone other than the last squad speaker);
## {"vo_actor": category} the survivor who did it (collect's by_player), else the squad; {"hold": [category, s]}
## keeps that survivor's category quiet for s seconds (the generic INTEL line under the note's own words);
## "patience": s drops a squad beat still waiting for the story channel after that long (a note's words go
## stale); {"vo_retire": [ids]} scheduled lines the story moved past. Any action also takes the filters / timers
## "at_n": n (only when the step's count is n: the first note, the second lock), "while_active": step id (dropped
## once that step is complete, at the time it would run), "after" / "delay": seconds (runs that much later) and
## "on_vo": line id (runs when that line starts, plus "after"; with "after_end" that much after it ends;
## "expire_s" runs it anyway when the line never comes, default never).
func _run_actions(qid: StringName, actions: Array) -> void:
	for a: Dictionary in actions:
		if a.has("at_n") and int(a["at_n"]) != int(_ctx.get("n", -1)):
			continue
		if a.has("while_active") and not is_active(qid, StringName(str(a["while_active"]))):
			continue
		if a.has("after") or a.has("on_vo") or a.has("delay"):
			var when: Dictionary = {"qid": qid, "a": a, "by": int(_ctx.get("by", 0)), "due": INF, "expire": INF}
			if a.has("on_vo"):
				when["on_vo"] = str(a["on_vo"])
				if a.has("expire_s"):
					when["expire"] = _t + float(a["expire_s"])
				# the same reaction scheduled again (a lock made twice after a reset) replaces the one still waiting
				for i: int in range(_pending.size() - 1, -1, -1):
					var o: Dictionary = _pending[i]
					if o["qid"] == qid and str(o.get("on_vo", "")) == str(a["on_vo"]) and (o["a"] as Dictionary).hash() == a.hash():
						_pending.remove_at(i)
			else:
				when["due"] = _t + float(a.get("after", a.get("delay", 0.0)))
			_pending.append(when)
			continue
		_do_action(qid, a, int(_ctx.get("by", 0)))


## The pending beats: an "after" action when its time comes, an "on_vo" action once its line started (or expired).
func _tick_pending() -> void:
	if _pending.is_empty():
		return
	var keep: Array[Dictionary] = []
	for w: Dictionary in _pending:
		var due: float = float(w["due"])
		if due == INF and _t >= float(w["expire"]):
			due = _t
		if _t < due:
			keep.append(w)
			continue
		var a: Dictionary = w["a"]
		if a.has("while_active") and not is_active(w["qid"], StringName(str(a["while_active"]))):
			continue
		_do_action(w["qid"], a, int(w["by"]))
	_pending = keep


func _on_vo_started(line_id: StringName, _speaker: StringName, _text: String, dur: float) -> void:
	for w: Dictionary in _pending:
		if str(w.get("on_vo", "")) == String(line_id) and float(w["due"]) == INF:
			var a: Dictionary = w["a"]
			w["due"] = _t + float(a.get("after", 0.0)) + (dur + float(a["after_end"]) if a.has("after_end") else 0.0)


## Beats waiting for their moment (tests): [{qid, a, by, due, expire, on_vo?}].
func pending_beats() -> Array[Dictionary]:
	return _pending


## Tests: advance the beat clock (the pending "after" / "on_vo" actions).
func advance(delta: float) -> void:
	_t += delta
	_tick_pending()


func _do_action(qid: StringName, a: Dictionary, by: int) -> void:
	if Net.replicating():
		var pres: Dictionary = client_subset(a)
		if not pres.is_empty():
			if pres.has("vo_actor"):
				pres["by"] = by
			Net.mirror(Net.session, &"_quest_actions", [pres])
	if a.has("flag"):
		GameState.set_flag(StringName(a["flag"]), true)
	if a.has("exfil_now"):   # UPDATE 07: light the map's act beacon before its round (the boarding, the autopilot)
		for x: Node in get_tree().get_nodes_in_group(&"exfil_points"):
			x.call("trigger_now")
	if a.has("act_event"):   # UPDATE 07 (T-114): the egg fires an act's clock event early (the London window, the bomb run)
		for ac: Node in get_tree().get_nodes_in_group(&"act_controllers"):
			ac.call("fire_event", StringName(str(a["act_event"])))
	if a.has("scrip_all"):   # T-153: the egg's Scrip to every player (Economy.grant: the earn multiplier applies)
		for pid4: int in GameState.player_ids:
			Economy.grant(pid4, int(a["scrip_all"]))
	if a.has("tier_gift"):   # T-153: one held tonic per player goes up `n` tiers (the lowest-tier one; capped by the perk)
		for pid5: int in GameState.player_ids:
			var best: StringName = &""
			var best_t: int = 99
			for pk: Variant in PerkManager.owned(pid5):
				var tt: int = PerkManager.tier_of(pid5, StringName(str(pk)))
				if tt < best_t:
					best_t = tt
					best = StringName(str(pk))
			if best != &"":
				PerkManager.set_tier(pid5, best, best_t + int(a["tier_gift"]))
	if a.has("perks_max"):   # T-174: every held tonic of every player to its top tier (Requiem's reward)
		for pid6: int in GameState.player_ids:
			PerkManager.raise_all_tiers(pid6, -1)
	if a.has("tier_all"):   # T-174: every held tonic of every player up `n` tiers (capped per tonic)
		for pid7: int in GameState.player_ids:
			PerkManager.raise_all_tiers(pid7, int(a["tier_all"]))
	if a.has("perk_tier_grant"):   # UPDATE 07 (T-114): [perk, tier] free for the match: owners now, buyers when they drink
		var pg: Array = a["perk_tier_grant"]
		GameState.set_flag(StringName("perk_tier_free_" + str(pg[0])), int(pg[1]))
		for pid3: int in GameState.player_ids:
			if PerkManager.has_perk(pid3, StringName(str(pg[0]))) and PerkManager.tier_of(pid3, StringName(str(pg[0]))) < int(pg[1]):
				PerkManager.set_tier(pid3, StringName(str(pg[0])), int(pg[1]))
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
			hud.call("show_banner", str(a["banner"]), float(a.get("banner_s", 3.0)))
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
	if a.has("dossier_page"):   # UPDATE 07 (T-115): every character in the match reaches at least this dossier page
		var page: int = int(a["dossier_page"])
		var dos: Dictionary = ProfileSave.profile.get("dossiers", {})
		var present: Array = GameState.characters.values() if GameState.characters is Dictionary else []
		present.append(GameState.character_id)   # solo: everyone is character_id
		for cid: Variant in present:
			if str(cid) == "":
				continue
			# "dossiers" holds dossier XP, not a page: reaching page N means the XP threshold of level N
			# (it wrote the bare page number, a no-op for anyone with a dossier already past 10 XP)
			var th: Array = ProfileSave.dossier_thresholds()
			var need: int = int(th[clampi(page, 1, th.size()) - 1]) if not th.is_empty() else page
			dos[str(cid)] = maxi(int(dos.get(str(cid), 0)), need)
		ProfileSave.profile["dossiers"] = dos
		ProfileSave.save_profile()
	if a.has("summon_boss"):
		var sb: Array = a["summon_boss"]
		summon_boss(StringName(str(sb[0])), Vector3(float(sb[1]), float(sb[2]), float(sb[3])))
	if a.has("shake"):
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			n.set("_shake", float(a["shake"]))
	if a.has("vo_squad") or a.has("vo_actor"):
		_say_beat(a, by)
	if a.has("vo_retire"):
		for id2: Variant in a["vo_retire"]:
			GLVO.retire(StringName(str(id2)))


## A squad story beat on this peer: the actor (by) or one random survivor, after the story channel is quiet.
func _say_beat(a: Dictionary, by: int) -> void:
	var cat: String = str(a.get("vo_actor", a.get("vo_squad", "")))
	var pid: int = by if a.has("vo_actor") and by > 0 else 0
	var exclude: int = GLVO.last_said_pid if bool(a.get("exclude_last", false)) else -1
	if a.has("hold") and pid > 0:
		var h: Array = a["hold"]
		GLVO.hold_category(GLVO.speaker_of(pid), str(h[0]), float(h[1]))
	GLVO.say_story_beat(pid, cat, 0.0, exclude, float(a.get("patience", 90.0)))   # ("delay" already passed in _pending)


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
	for k: String in ["vo_category", "vo_player", "unlock_map", "xp", "archive", "egg_reward", "profile_list", "banner", "shake",
			"vo_squad", "vo_actor", "exclude_last", "hold", "delay", "vo_retire", "banner_s"]:
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
			hud.call("show_banner", str(a["banner"]), float(a.get("banner_s", 3.0)))
	if a.has("shake"):
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			n.set("_shake", float(a["shake"]))
	if a.has("vo_squad") or a.has("vo_actor"):
		_say_beat(a, int(a.get("by", 0)))
	if a.has("vo_retire"):
		for id2: Variant in a["vo_retire"]:
			GLVO.retire(StringName(str(id2)))


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
		elif str(step["type"]) == "flag":
			var fp: Dictionary = step.get("params", {})
			if not (fp.has("flag") or fp.has("any") or fp.has("all") or fp.has("zone")):
				errors.append("flag step %s names no flag/any/all/zone" % step["id"])
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
			if (str(k) == "vo" or str(k) == "on_vo") and v is String:
				out.append(v)
			elif (str(k) == "vo_list" or str(k) == "vo_retire") and v is Array:
				for id: Variant in v:
					out.append(str(id))
			else:
				out.append_array(referenced_vo(v))
	elif def is Array:
		for e: Variant in def:
			out.append_array(referenced_vo(e))
	return out
