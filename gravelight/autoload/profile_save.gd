extends Node
## Meta-progression profile (user://gravelight_profile.json): versioned, migrated step by step, written atomically.
## Rank 1–60 + Commendations (prestige), character dossiers, weapon mastery camos, rotating challenges,
## the Intel Archive, stats, and map unlocks. XP earned during a match is held in `cur_match` and committed
## when the match ends (game over, quitting to the menu, or restarting), so the game-over screen can show it.

const PATH: String = "user://gravelight_profile.json"
const CURRENT_VERSION: int = 3
const LOCAL_PLAYER: int = 1   # solo player id; in co-op the local id comes from Net (local_id())

var profile: Dictionary = {}
var path: String = PATH   # tests point this elsewhere
## The match in progress (empty when none). See _on_match_started().
var cur_match: Dictionary = {}
## What the last finished match earned, for the game-over screen.
var last_summary: Dictionary = {}

var _prog: Dictionary = {}
var _dossiers: Dictionary = {}
var _intel: Dictionary = {}     # id -> row


func _ready() -> void:
	_prog = GLData.load_json("res://data/gravelight/progression.json")
	_dossiers = GLData.load_json("res://data/gravelight/dossiers.json")
	for row: Dictionary in GLData.load_json("res://data/gravelight/intel.json").get("intel", []):
		_intel[str(row["id"])] = row
	_add_cabinet_rows()
	for row: Dictionary in MachineLore.archive_rows():   # maker's plates, the Crucibles, the chalk (T-075)
		_intel[str(row["id"])] = row
	load_profile()
	GLBus.match_started.connect(_on_match_started)
	GLBus.game_over.connect(_on_game_over)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.player_damaged.connect(_on_player_damaged)
	GLBus.player_downed.connect(_on_player_downed)
	GLBus.player_revived.connect(_on_player_revived)
	GLBus.door_opened.connect(_on_door_opened)
	GLBus.perk_bought.connect(_on_perk_bought)
	GLBus.board_repaired.connect(_on_board_repaired)
	GLBus.crate_opened.connect(_on_crate_opened)
	GLBus.powerup_collected.connect(_on_powerup_collected)
	GLBus.weapon_upgraded.connect(_on_weapon_upgraded)
	GLBus.quest_step_completed.connect(_on_quest_step)
	GLBus.quest_completed.connect(_on_quest_completed)
	GLBus.intel_found.connect(_on_intel_found)


func _process(_delta: float) -> void:
	# Quitting to the menu ends the match without a game-over: commit what was earned.
	if not cur_match.is_empty() and bool(cur_match.get("active", false)) and GameState.phase == GameState.Phase.MENU:
		finish_match()


# ================================================================== profile shape & migrations

static func new_profile() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"xp": 0, "xp_lifetime": 0, "rank": 1, "prestige": 0,
		"dossiers": {"dutch": 0, "peg": 0, "deacon": 0, "wren": 0},
		"weapon_kills": {},
		"maps_unlocked": ["map00_crossroads"],
		"best_round": {},
		"intel": [],
		"stats": _default_stats(),
		"egg_rewards": {},
		"unlocked": [],
		"equipped": {"calling_card": "", "emblem": "", "cap_style": "", "menu_theme": ""},
		"challenges": {},
		"challenge_career": {},
		"challenges_done": [],
		"muster": _default_muster(),
	}


## The Muster (T-079, Muster): each survivor's sidearm and Field Habits; everyone starts with the M1911, no habits.
static func _default_muster() -> Dictionary:
	var out: Dictionary = {}
	for c: String in ["dutch", "peg", "deacon", "wren"]:
		out[c] = {"pistol": "m1911", "habits": []}
	return out


static func _default_stats() -> Dictionary:
	return {"matches": 0, "kills": 0, "headshots": 0, "downs": 0, "revives": 0, "eggs": 0, "scrip": 0,
		"rounds": 0, "boards": 0, "doors": 0}


## Upgrades an older profile one version at a time. Add a step per schema change.
static func migrate(data: Dictionary) -> Dictionary:
	var v: int = int(data.get("version", 0))
	if v < 1:
		var fresh: Dictionary = new_profile()
		fresh.merge(data, true)
		fresh["version"] = 1
		data = fresh
		v = 1
	if v < 2:
		data = _migrate_to_2(data)
	if int(data.get("version", 0)) < 3:
		data = _migrate_to_3(data)
	return data


## v2 adds lifetime XP, unlocks/equipped cosmetics, challenges, and full stats. v1 dossier values become XP.
static func _migrate_to_2(data: Dictionary) -> Dictionary:
	var fresh: Dictionary = new_profile()
	for k: String in fresh.keys():
		if not data.has(k):
			data[k] = fresh[k]
	if int(data.get("xp_lifetime", 0)) < int(data.get("xp", 0)):
		data["xp_lifetime"] = int(data.get("xp", 0))
	var stats: Dictionary = data.get("stats", {})
	for sk: String in _default_stats().keys():
		if not stats.has(sk):
			stats[sk] = 0
	data["stats"] = stats
	var dos: Dictionary = data.get("dossiers", {})
	for c: String in ["dutch", "peg", "deacon", "wren"]:
		dos[c] = int(dos.get(c, 0))
	data["dossiers"] = dos
	data["version"] = 2
	return data


## v3 adds the Muster (T-079): every survivor's sidearm and Field Habits, defaulting to the M1911 and none.
static func _migrate_to_3(data: Dictionary) -> Dictionary:
	var m: Dictionary = data.get("muster", {}) if data.get("muster", {}) is Dictionary else {}
	for c: String in ["dutch", "peg", "deacon", "wren"]:
		if not (m.get(c, null) is Dictionary):
			m[c] = {"pistol": "m1911", "habits": []}
	data["muster"] = m
	data["version"] = 3
	return data


func load_profile() -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	profile = migrate(parsed) if parsed is Dictionary else new_profile()


## Writes to a temp file then renames, so a crash mid-write can't corrupt the profile.
func save_profile() -> void:
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("ProfileSave: cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(profile, "  "))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


func _ensure_shape() -> void:
	if int(profile.get("version", 0)) < CURRENT_VERSION or not profile.has("challenges"):
		profile = migrate(profile)


# ================================================================== maps

func is_map_unlocked(map_id: StringName) -> bool:
	return (profile.get("maps_unlocked", []) as Array).has(String(map_id))


func unlock_map(map_id: StringName) -> void:
	if not is_map_unlocked(map_id):
		if not profile.has("maps_unlocked"):
			profile["maps_unlocked"] = []
		(profile["maps_unlocked"] as Array).append(String(map_id))
		if not cur_match.is_empty():
			(cur_match["unlocks"] as Array).append("Map unlocked: %s" % map_id)
		save_profile()


func best_round(map_id: StringName) -> int:
	return int((profile.get("best_round", {}) as Dictionary).get(String(map_id), 0))


# ================================================================== rank & prestige

func curve() -> Dictionary:
	return _prog.get("rank_curve", {"base": 800, "linear": 120, "quad": 6, "max_rank": 60})


static func xp_to_next(rank_n: int, c: Dictionary) -> int:
	var k: int = rank_n - 1
	return int(c["base"]) + int(c["linear"]) * k + int(c["quad"]) * k * k


## Total XP needed to reach `rank_n` from rank 1.
static func total_for_rank(rank_n: int, c: Dictionary) -> int:
	var t: int = 0
	for n: int in range(1, rank_n):
		t += xp_to_next(n, c)
	return t


static func rank_for_xp(xp: int, c: Dictionary) -> int:
	var r: int = 1
	var t: int = 0
	var max_r: int = int(c.get("max_rank", 60))
	while r < max_r:
		var need: int = xp_to_next(r, c)
		if t + need > xp:
			break
		t += need
		r += 1
	return r


func rank() -> int:
	return rank_for_xp(int(profile.get("xp", 0)), curve())


func prestige() -> int:
	return int(profile.get("prestige", 0))


## 0..1 progress toward the next rank (1.0 at max rank).
func rank_progress() -> float:
	var c: Dictionary = curve()
	var r: int = rank()
	if r >= int(c["max_rank"]):
		return 1.0
	var into: int = int(profile.get("xp", 0)) - total_for_rank(r, c)
	return clampf(float(into) / float(xp_to_next(r, c)), 0.0, 1.0)


func can_prestige() -> bool:
	return rank() >= int(curve()["max_rank"]) and prestige() < int(_prog.get("max_prestige", 10))


## Resets rank to 1 for the next Commendation emblem. Returns false if not allowed.
func do_prestige() -> bool:
	if not can_prestige():
		return false
	profile["prestige"] = prestige() + 1
	profile["xp"] = 0
	profile["rank"] = 1
	for c: Dictionary in _prog.get("commendations", []):
		if int(c["prestige"]) == prestige():
			_grant_unlock(str(c["id"]))
	save_profile()
	return true


func _apply_xp(amount: int) -> Array:
	var before: int = rank()
	profile["xp"] = int(profile.get("xp", 0)) + amount
	profile["xp_lifetime"] = int(profile.get("xp_lifetime", 0)) + amount
	var after: int = rank()
	profile["rank"] = after
	var ups: Array = []
	for r: int in range(before + 1, after + 1):
		ups.append(r)
		for u: Dictionary in _prog.get("unlocks", []):
			if int(u["rank"]) == r:
				_grant_unlock(str(u["id"]))
		if not cur_match.is_empty() and prestige() == 0:
			(cur_match["unlocks"] as Array).append_array(Array(Muster.unlocks_at_rank(r)))   # sidearms, Field Habits, slots
	return ups


func unlock_rows() -> Array:
	return _prog.get("unlocks", []) + _prog.get("commendations", [])


func is_unlocked(item_id: String) -> bool:
	return (profile.get("unlocked", []) as Array).has(item_id)


func _grant_unlock(item_id: String) -> void:
	if item_id == "" or is_unlocked(item_id):
		return
	(profile["unlocked"] as Array).append(item_id)
	if not cur_match.is_empty():
		(cur_match["unlocks"] as Array).append(_unlock_name(item_id))


func _unlock_name(item_id: String) -> String:
	for u: Dictionary in unlock_rows():
		if str(u["id"]) == item_id:
			return str(u["name"])
	for ch: Dictionary in _challenge_pool():
		if str(ch.get("card", "")) == item_id:
			return "Calling card: " + str(ch["name"])
	return item_id


## XP from quests, challenges etc. During a match it shows on the game-over screen; otherwise it applies now.
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	if not cur_match.is_empty() and bool(cur_match.get("active", false)):
		cur_match["xp"] = int(cur_match["xp"]) + amount
	else:
		_apply_xp(amount)


func _xp_table() -> Dictionary:
	return _prog.get("xp", {})


# ================================================================== dossiers

func dossier_thresholds() -> Array:
	return _dossiers.get("xp_levels", [0, 3000, 8000, 15000, 25000, 38000, 55000, 75000, 100000, 130000])


static func dossier_level_for(xp: int, thresholds: Array) -> int:
	var lvl: int = 0
	for t: Variant in thresholds:
		if xp >= int(t):
			lvl += 1
	return clampi(lvl, 1, thresholds.size())


func dossier_xp(character: StringName) -> int:
	return int((profile.get("dossiers", {}) as Dictionary).get(String(character), 0))


func dossier_level(character: StringName) -> int:
	return dossier_level_for(dossier_xp(character), dossier_thresholds())


func dossier_pages(character: StringName) -> Array:
	return (_dossiers.get("characters", {}) as Dictionary).get(String(character), [])


# ================================================================== weapon mastery

static func base_weapon(weapon_id: StringName) -> String:
	return String(weapon_id).trim_suffix("_up")


func weapon_kills(weapon_id: StringName) -> int:
	return int((profile.get("weapon_kills", {}) as Dictionary).get(base_weapon(weapon_id), 0))


static func camo_tier(kills: int, thresholds: Array) -> StringName:
	var best: StringName = &""
	for t: Dictionary in thresholds:
		if kills >= int(t["kills"]):
			best = StringName(t["id"])
	return best


## True once every base weapon has reached Gold.
func nachtglas_unlocked() -> bool:
	var th: Array = _prog["camos"]["thresholds"]
	var gold: int = int(th[th.size() - 1]["kills"])
	var weps: Dictionary = GLData.table("weapons")["weapons"]
	for w: Variant in weps.keys():
		if bool((weps[w] as Dictionary).get("muster_sidearm", false)):
			continue   # the Muster's optional sidearms (T-079) don't hold the meta camo back
		if weapon_kills(StringName(str(w))) < gold:
			return false
	return true


## The best camo earned for a weapon: "" (none), olive_drab … gold, or nachtglas (the meta reward).
func camo_for(weapon_id: StringName) -> StringName:
	if nachtglas_unlocked():
		return &"nachtglas"
	return camo_tier(weapon_kills(weapon_id), _prog["camos"]["thresholds"])


func favorite_weapon() -> String:
	var best: String = ""
	var best_k: int = 0
	var wk: Dictionary = profile.get("weapon_kills", {})
	for w: Variant in wk.keys():
		if int(wk[w]) > best_k:
			best_k = int(wk[w])
			best = str(w)
	return best


# ================================================================== intel

func add_intel(intel_id: StringName) -> void:
	var list: Array = profile.get("intel", [])
	if not list.has(String(intel_id)):
		list.append(String(intel_id))
		profile["intel"] = list


## Helvetia cabinets in the Archive (T&C section 11.2): each machine's fine-print panel ("panel.<perk>", filed
## when read) with the story of the human behind the formula, and its plan-ID stencil ("plan.<perk>", filed when
## an upgraded muzzle flash reveals it). The eight standard perks and Overclock Cordial (in the game since T-034);
## Fine Print Fernet joins when it ships with Helvetia Works.
const CABINET_PERKS: PackedStringArray = ["ironhide_stout", "second_wind", "trigger_tonic", "twin_barrel",
	"marathon_malt", "hawkeye_brandy", "packmule_porter", "blastproof_bock", "overclock_cordial", "skyhook_sekt", "magpie_mead"]


func _add_cabinet_rows() -> void:
	var lore: Dictionary = GLData.load_json("res://data/gravelight/perk_lore.json").get("perks", {})
	var strip: RegEx = RegEx.create_from_string("\\[/?[a-z]+\\]")
	for pid: String in CABINET_PERKS:
		var lo: Dictionary = lore.get(pid, {})
		if lo.is_empty():
			continue
		var panel: String = strip.sub("\n".join(PackedStringArray((lo.get("panel", []) as Array).map(func(x: Variant) -> String: return str(x)))), "", true)
		var story: String = strip.sub(str(lo.get("human_story", "")), "", true)
		_intel["panel." + pid] = {"id": "panel." + pid, "title": "Conditions of Use: %s" % lo.get("name", pid), "type": "PANEL",
			"map": "cabinets", "text": "%s\n\nTHE FORMULA: %s\n%s" % [panel, lo.get("human", ""), story]}
		_intel["plan." + pid] = {"id": "plan." + pid, "title": "Vitality Plan: %s" % str(lo.get("plan_name", "")).split(" (")[0], "type": "STENCIL",
			"map": "cabinets", "text": "%s · %s\n\nA stencil under the enamel of the %s cabinet, matte violet on bare steel.\n\nSee also: The Fine Print, Chapter 3." % [
				lo.get("plan_id", ""), lo.get("plan_name", ""), lo.get("name", pid)]}


func intel_rows() -> Array:
	return _intel.values()


func has_intel(intel_id: String) -> bool:
	return (profile.get("intel", []) as Array).has(intel_id)


func _on_intel_found(intel_id: StringName) -> void:
	if _intel.has(String(intel_id)) and not has_intel(String(intel_id)):
		add_xp(int(_xp_table().get("intel", 150)))
	add_intel(intel_id)


# ================================================================== challenges

func _challenge_pool() -> Array:
	return _prog.get("challenges", {}).get("pool", [])


func challenge_def(cid: String) -> Dictionary:
	for c: Dictionary in _challenge_pool():
		if str(c["id"]) == cid:
			return c
	return {}


## Active challenge ids for a map, topping the list up to 3 from the pool.
func active_challenges(map_id: StringName) -> Array:
	_ensure_shape()
	var key: String = String(map_id)
	var all: Dictionary = profile["challenges"]
	var list: Array = all.get(key, [])
	var want: int = int(_prog.get("challenges", {}).get("active_per_map", 3))
	var done: Array = profile.get("challenges_done", [])
	var candidates: Array = []
	for c: Dictionary in _challenge_pool():
		var maps: Array = c.get("maps", ["any"])
		if (maps.has(key) or maps.has("any")) and not done.has(str(c["id"])) and not list.has(str(c["id"])):
			candidates.append(str(c["id"]))
	candidates.shuffle()
	while list.size() < want and not candidates.is_empty():
		list.append(candidates.pop_back())
	all[key] = list
	return list


## Progress for display: career progress from the profile, match progress from the current match.
func challenge_progress(cid: String) -> int:
	var c: Dictionary = challenge_def(cid)
	if str(c.get("scope", "career")) == "match":
		return int((cur_match.get("challenge_progress", {}) as Dictionary).get(cid, 0)) if not cur_match.is_empty() else 0
	return int((profile.get("challenge_career", {}) as Dictionary).get(cid, 0))


## Pure filter check (tests use it). info: weapon_id, weapon_class, headshot, melee.
static func challenge_matches(c: Dictionary, event: String, info: Dictionary, match_state: Dictionary) -> bool:
	if str(c["event"]) != event:
		return false
	var f: Dictionary = c.get("filter", {})
	if f.has("headshot") and bool(info.get("headshot", false)) != bool(f["headshot"]):
		return false
	if f.has("melee") and bool(info.get("melee", false)) != bool(f["melee"]):
		return false
	if f.has("weapon_prefix") and not str(info.get("weapon_id", "")).begins_with(str(f["weapon_prefix"])):
		return false
	if f.has("weapon_class") and str(info.get("weapon_class", "")) != str(f["weapon_class"]):
		return false
	if f.has("weapon_in") and not (f["weapon_in"] as Array).has(str(info.get("weapon_id", ""))):
		return false
	if bool(f.get("no_perks", false)) and bool(match_state.get("perks", false)):
		return false
	if bool(f.get("no_doors", false)) and bool(match_state.get("doors", false)):
		return false
	return true


func _challenge_event(event: String, info: Dictionary = {}, amount: int = 1) -> void:
	if cur_match.is_empty() or not bool(cur_match.get("active", false)):
		return
	var map_id: StringName = StringName(cur_match["map"])
	for cid: Variant in active_challenges(map_id).duplicate():
		var c: Dictionary = challenge_def(str(cid))
		if c.is_empty() or not challenge_matches(c, event, info, cur_match):
			continue
		var target: int = int(c["target"])
		var value: int
		if str(c.get("scope", "career")) == "match":
			var mp: Dictionary = cur_match["challenge_progress"]
			value = maxi(int(mp.get(cid, 0)), amount) if event == "round" else int(mp.get(cid, 0)) + amount
			mp[cid] = value
		else:
			var cp: Dictionary = profile["challenge_career"]
			value = int(cp.get(cid, 0)) + amount
			cp[cid] = value
		if value >= target:
			_complete_challenge(str(cid), map_id)


func _complete_challenge(cid: String, map_id: StringName) -> void:
	var c: Dictionary = challenge_def(cid)
	var list: Array = profile["challenges"].get(String(map_id), [])
	list.erase(cid)
	(profile["challenges_done"] as Array).append(cid)
	add_xp(int(c.get("xp", 1000)))
	if c.has("card"):
		_grant_unlock(str(c["card"]))
	(cur_match["challenges"] as Array).append(str(c.get("name", cid)))
	active_challenges(map_id)   # tops the list back up


# ================================================================== match tracking

## The player id whose events count for this profile (1 solo; the local co-op slot online).
func local_id() -> int:
	return Net.local_player_id()


func _tracked() -> bool:
	return not cur_match.is_empty() and bool(cur_match.get("active", false))


func _on_match_started(map_id: StringName) -> void:
	if _tracked():
		finish_match()
	_ensure_shape()
	last_summary = {}
	var no_prog: Array = _prog.get("no_progress_maps", [])
	cur_match = {
		"active": not no_prog.has(String(map_id)),
		"map": String(map_id), "character": String(GameState.character_id),
		"xp": 0, "kills": 0, "headshots": 0, "revives": 0, "weapon_kills": {},
		"perks": false, "doors": false, "special": false, "special_damage": false,
		"challenge_progress": {}, "challenges": [], "unlocks": [],
	}
	if bool(cur_match["active"]):
		active_challenges(map_id)
	_apply_egg_rewards(map_id)


## Map 1 main-egg reward: a permanent extra perk slot on that map (the profile key keeps its old "slot_5" name).
func _apply_egg_rewards(map_id: StringName) -> void:
	var eggs: Dictionary = profile.get("egg_rewards", {})
	var has_slot: bool = bool(eggs.get("map01_requiem", false)) or bool(eggs.get("map01_perk_slot_5", false))
	if map_id == &"map01_kaltenbrunn" and has_slot and "_bonus_slots" in PerkManager:
		var slots: Dictionary = PerkManager.get("_bonus_slots")
		slots[local_id()] = 1


func _on_enemy_killed(_enemy_id: StringName, limb: StringName, weapon_id: StringName, by_player: int) -> void:
	if not _tracked() or by_player != local_id():
		return
	var head: bool = limb == &"head"
	var x: Dictionary = _xp_table()
	cur_match["xp"] = int(cur_match["xp"]) + int(x.get("headshot_kill", 15) if head else x.get("kill", 10))
	cur_match["kills"] = int(cur_match["kills"]) + 1
	if head:
		cur_match["headshots"] = int(cur_match["headshots"]) + 1
	var base: String = base_weapon(weapon_id)
	var weps: Dictionary = GLData.table("weapons")
	var cls: String = ""
	if weps["weapons"].has(base):
		cls = str(weps["weapons"][base].get("class", ""))
	if weps["weapons"].has(base) or weps["melee"].has(base):
		var wk: Dictionary = cur_match["weapon_kills"]
		wk[base] = int(wk.get(base, 0)) + 1
	var melee: bool = weps["melee"].has(base)
	_challenge_event("kill", {"weapon_id": String(weapon_id), "weapon_class": cls, "headshot": head, "melee": melee})


func _on_round_started(round_number: int, is_special: bool) -> void:
	# Map 1 unlocks on reaching round 10 at the inn (or the radio quest); Map 2 on round 30 at Kaltenbrunn.
	for target: Variant in (_prog.get("map_unlock_rounds", {}) as Dictionary).keys():
		var rule: Dictionary = _prog["map_unlock_rounds"][target]
		if String(GameState.map_id) == str(rule["from"]) and round_number >= int(rule["round"]):
			unlock_map(StringName(str(target)))
	if not _tracked():
		return
	if round_number > 1:
		cur_match["xp"] = int(cur_match["xp"]) + int(_xp_table().get("round_mult", 50)) * (round_number - 1)
	cur_match["special"] = is_special
	cur_match["special_damage"] = false
	_challenge_event("round", {}, round_number)


func _on_round_ended(_round_number: int) -> void:
	if _tracked() and bool(cur_match["special"]) and not bool(cur_match["special_damage"]):
		_challenge_event("special_clean")


func _on_player_damaged(player: int, amount: float) -> void:
	if _tracked() and player == local_id() and amount > 0.0:
		cur_match["special_damage"] = true


func _on_player_downed(_player: int) -> void:
	pass


func _on_board_repaired(_w: StringName, by: int) -> void:
	if by == local_id():
		_challenge_event("boards")


func _on_crate_opened(p: int) -> void:
	if p == local_id():
		_challenge_event("crate")


func _on_powerup_collected(_id: StringName, by: int) -> void:
	if by == local_id():
		_challenge_event("powerup")


func _on_weapon_upgraded(p: int, _w: StringName) -> void:
	if p == local_id():
		_challenge_event("upgrade")


func _on_quest_step(_q: StringName, _s: StringName) -> void:
	add_xp(int(_xp_table().get("egg_step", 500)))


func _on_player_revived(player: int, by_player: int) -> void:
	if _tracked() and by_player == local_id() and player != by_player:
		cur_match["xp"] = int(cur_match["xp"]) + int(_xp_table().get("revive", 100))
		cur_match["revives"] = int(cur_match["revives"]) + 1


func _on_door_opened(_door: StringName, by_player: int) -> void:
	if not _tracked():
		return
	cur_match["doors"] = true
	if by_player == local_id():
		cur_match["xp"] = int(cur_match["xp"]) + int(_xp_table().get("door", 25))
		_challenge_event("doors")


func _on_perk_bought(player: int, _perk: StringName) -> void:
	if _tracked() and player == local_id():
		cur_match["perks"] = true


func _on_quest_completed(quest_id: StringName) -> void:
	var eggs: Dictionary = _prog.get("main_eggs", {})
	if not eggs.has(String(quest_id)):
		return
	add_xp(int(_xp_table().get("egg_complete", 10000)))
	if not profile.has("egg_rewards"):
		profile["egg_rewards"] = {}
	profile["egg_rewards"][String(quest_id)] = true
	profile["stats"]["eggs"] = int(profile["stats"].get("eggs", 0)) + 1
	var rule: Dictionary = eggs[String(quest_id)]
	if rule.has("unlock_map"):
		unlock_map(StringName(str(rule["unlock_map"])))
	save_profile()


func _on_game_over(_stats: Dictionary) -> void:
	finish_match()


## Commits the cur_match: stats, best round, mastery, XP → rank/dossier, map unlocks. Fills `last_summary`.
func finish_match() -> void:
	var gstats: Dictionary = GameState.stats
	var map_key: String = String(GameState.map_id)
	var r: int = int(gstats.get(&"round", 0))
	if not profile.has("best_round"):
		profile["best_round"] = {}
	if map_key != "" and r > int(profile["best_round"].get(map_key, 0)):
		profile["best_round"][map_key] = r
	if cur_match.is_empty() or not bool(cur_match.get("active", false)):
		cur_match = {}
		save_profile()
		return
	cur_match["active"] = false
	var st: Dictionary = profile["stats"]
	st["matches"] = int(st.get("matches", 0)) + 1
	st["kills"] = int(st.get("kills", 0)) + int(cur_match["kills"])
	st["headshots"] = int(st.get("headshots", 0)) + int(cur_match["headshots"])
	st["downs"] = int(st.get("downs", 0)) + int(gstats.get(&"downs", 0))
	st["revives"] = int(st.get("revives", 0)) + int(cur_match["revives"])
	st["scrip"] = int(st.get("scrip", 0)) + int(gstats.get(&"scrip_earned", 0))
	st["rounds"] = int(st.get("rounds", 0)) + r
	st["boards"] = int(st.get("boards", 0)) + int(gstats.get(&"boards", 0))
	st["doors"] = int(st.get("doors", 0)) + int(gstats.get(&"doors", 0))
	var wk: Dictionary = profile["weapon_kills"]
	for w: Variant in (cur_match["weapon_kills"] as Dictionary).keys():
		wk[w] = int(wk.get(w, 0)) + int(cur_match["weapon_kills"][w])
	var earned: int = int(cur_match["xp"])
	var rank_before: int = rank()
	var prog_before: float = rank_progress()
	var ch: String = str(cur_match["character"])
	var dos_before: int = dossier_level(StringName(ch))
	var ups: Array = _apply_xp(earned)
	profile["dossiers"][ch] = dossier_xp(StringName(ch)) + earned
	last_summary = {
		"xp": earned, "rank_before": rank_before, "rank_after": rank(), "progress_before": prog_before,
		"progress_after": rank_progress(), "rank_ups": ups, "prestige": prestige(),
		"challenges": (cur_match["challenges"] as Array).duplicate(), "unlocks": (cur_match["unlocks"] as Array).duplicate(),
		"character": ch, "dossier_before": dos_before, "dossier_after": dossier_level(StringName(ch)),
	}
	cur_match = {}
	save_profile()
