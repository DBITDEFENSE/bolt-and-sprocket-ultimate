class_name Muster
extends RefCounted
## The Muster (DECISIONS T-079, docs/gravelight/PROGRESSION.md): what a survivor brings into a match from outside
## it. Before a match each survivor (Dutch, Peg, Deacon, Wren: one loadout each) picks a sidearm and up to 1-3
## Field Habits, all unlocked by rank (or a career stat, challenges, the survivor's dossier). Field Habits are a
## separate system from the perk tonics bought at machines (PerkManager): small, permanent for the match, never
## bought and never lost on a down. Numbers and unlock rules: data/gravelight/muster.json.
##
## Saved in the profile (ProfileSave.profile["muster"] = {character: {"pistol": id, "habits": [ids]}}, profile v3).
## At match start MapRoot calls begin_match(): every player id gets its kit in `match_kits` (the local human's from
## the profile, sanitized against unlocks and slots; online, every peer's from the lobby roster, sent at join and
## sanitized by the host, Net._rpc_kits). Bots and Jakub have none (their own default kit); the player-bot agent
## (PlayerBot, T-071) drives the local human's Player, so it plays the human's Muster. The hooks read
## start_pistol(pid) / value(pid, key, default) / has(pid, habit).

const PATH: String = "res://data/gravelight/muster.json"

static var _cfg: Dictionary = {}
## pid -> {"pistol": String, "habits": Array[String]} for the match in progress.
static var match_kits: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(PATH)
	return _cfg


## Drops the cached table (tests, data edits).
static func reload() -> void:
	_cfg = {}


# ================================================================== catalogue

static func pistol_rows() -> Array:
	return cfg().get("pistols", [])


static func habit_rows() -> Array:
	return cfg().get("habits", [])


static func pistol_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for r: Dictionary in pistol_rows():
		out.append(str(r["id"]))
	return out


static func habit_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for r: Dictionary in habit_rows():
		out.append(str(r["id"]))
	return out


static func pistol_def(id: String) -> Dictionary:
	for r: Dictionary in pistol_rows():
		if str(r["id"]) == id:
			return r
	return {}


static func habit_def(id: String) -> Dictionary:
	for r: Dictionary in habit_rows():
		if str(r["id"]) == id:
			return r
	return {}


static func default_pistol() -> String:
	return str(cfg().get("default_pistol", "m1911"))


static func pistol_name(id: String) -> String:
	var w: Dictionary = GLData.table("weapons")["weapons"]
	return str((w.get(id, {}) as Dictionary).get("name", id))


static func habit_name(id: String) -> String:
	return str(habit_def(id).get("name", id.capitalize()))


static func max_slots() -> int:
	return int(cfg().get("max_slots", 3))


## Habit slots at a rank (pure). A Commendation (prestige) keeps every slot: see effective_rank.
static func slots_for_rank(rank_n: int, c: Dictionary = {}) -> int:
	var table: Array = (c if not c.is_empty() else cfg()).get("slots", [])
	var n: int = 0
	for row: Dictionary in table:
		if rank_n >= int(row["rank"]):
			n = maxi(n, int(row["slots"]))
	return n


## The next rank that opens a habit slot (0 when every slot is open).
static func next_slot_rank(rank_n: int) -> int:
	var best: int = 0
	for row: Dictionary in cfg().get("slots", []):
		var r: int = int(row["rank"])
		if r > rank_n and (best == 0 or r < best):
			best = r
	return best


# ================================================================== unlocks (pure on a profile dictionary)

## The rank unlock rules see: the profile's rank, or the top rank once you hold a Commendation (a prestige resets the
## rank, never what it unlocked).
static func effective_rank(profile: Dictionary) -> int:
	if int(profile.get("prestige", 0)) > 0:
		return int(ProfileSave.curve().get("max_rank", 60))
	return ProfileSave.rank_for_xp(int(profile.get("xp", 0)), ProfileSave.curve())


## True when ANY condition of `rules` holds (an empty list is always unlocked).
static func rules_met(rules: Array, profile: Dictionary, character: String) -> bool:
	if rules.is_empty():
		return true
	for r: Dictionary in rules:
		if r.has("rank") and effective_rank(profile) >= int(r["rank"]):
			return true
		if r.has("stat") and int((profile.get("stats", {}) as Dictionary).get(str(r["stat"]), 0)) >= int(r.get("min", 0)):
			return true
		if r.has("challenges") and (profile.get("challenges_done", []) as Array).size() >= int(r["challenges"]):
			return true
		if r.has("dossier") and character != "":
			var dx: int = int((profile.get("dossiers", {}) as Dictionary).get(character, 0))
			if ProfileSave.dossier_level_for(dx, ProfileSave.dossier_thresholds()) >= int(r["dossier"]):
				return true
	return false


static func pistol_unlocked(id: String, profile: Dictionary, character: String = "") -> bool:
	var d: Dictionary = pistol_def(id)
	return not d.is_empty() and rules_met(d.get("unlock", []), profile, character)


static func habit_unlocked(id: String, profile: Dictionary, character: String = "") -> bool:
	var d: Dictionary = habit_def(id)
	return not d.is_empty() and rules_met(d.get("unlock", []), profile, character)


static func slots_for(profile: Dictionary) -> int:
	return clampi(slots_for_rank(effective_rank(profile)), 0, max_slots())


## Plain-English unlock text for a row ("Rank 8 or dossier level 4").
static func unlock_text(row: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r: Dictionary in row.get("unlock", []):
		if r.has("rank"):
			parts.append("rank %d" % int(r["rank"]))
		elif r.has("stat"):
			parts.append("%d %s (career)" % [int(r.get("min", 0)), str(r["stat"]).replace("_", " ")])
		elif r.has("challenges"):
			parts.append("%d challenges done" % int(r["challenges"]))
		elif r.has("dossier"):
			parts.append("dossier level %d" % int(r["dossier"]))
	var s: String = " or ".join(parts)
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else "Always open"


## What reaching `rank_n` opens (names, for the game-over unlock list): pistols, habits and slots whose rank rule
## is exactly that rank.
static func unlocks_at_rank(rank_n: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for r: Dictionary in pistol_rows():
		for u: Dictionary in r.get("unlock", []):
			if int(u.get("rank", -1)) == rank_n and rank_n > 1:
				out.append("Sidearm: %s" % pistol_name(str(r["id"])))
	for h: Dictionary in habit_rows():
		for u2: Dictionary in h.get("unlock", []):
			if int(u2.get("rank", -1)) == rank_n and rank_n > 1:
				out.append("Field Habit: %s" % str(h.get("name", h["id"])))
	for s: Dictionary in cfg().get("slots", []):
		if int(s["rank"]) == rank_n and rank_n > 1:
			out.append("Field Habit slot %d" % int(s["slots"]))
	return out


# ================================================================== loadouts

## A loadout with only known ids, no repeats, at most `slots` habits ({"pistol", "habits"}). Pure.
static func clean(kit: Variant, slots: int) -> Dictionary:
	var d: Dictionary = kit if kit is Dictionary else {}
	var pistol: String = str(d.get("pistol", ""))
	if not pistol_ids().has(pistol):
		pistol = default_pistol()
	var habits: Array = []
	var known: PackedStringArray = habit_ids()
	for h: Variant in (d.get("habits", []) if d.get("habits", []) is Array else []):
		if habits.size() >= slots:
			break
		if known.has(str(h)) and not habits.has(str(h)):
			habits.append(str(h))
	return {"pistol": pistol, "habits": habits}


## The saved loadout of `character` with locked items dropped and the habits cut to the open slots.
static func loadout_for(character: String, profile: Dictionary) -> Dictionary:
	var saved: Dictionary = (profile.get("muster", {}) as Dictionary).get(character, {})
	var k: Dictionary = clean(saved, max_slots())
	if not pistol_unlocked(str(k["pistol"]), profile, character):
		k["pistol"] = default_pistol()
	var open: Array = []
	for h: Variant in k["habits"]:
		if habit_unlocked(str(h), profile, character) and open.size() < slots_for(profile):
			open.append(h)
	k["habits"] = open
	return k


## The loadout with `habit` put on (or taken off when it is on). Returns {"kit": new loadout, "result": "on" | "off"
## | "full" (no free slot) | "locked" | "unknown"}. Pure; `profile` decides what is unlocked and the slots.
static func toggle_habit(kit: Dictionary, habit: String, profile: Dictionary, character: String) -> Dictionary:
	var k: Dictionary = clean(kit, max_slots())
	var hs: Array = k["habits"]
	if hs.has(habit):
		hs.erase(habit)
		return {"kit": k, "result": "off"}
	if habit_def(habit).is_empty():
		return {"kit": k, "result": "unknown"}
	if not habit_unlocked(habit, profile, character):
		return {"kit": k, "result": "locked"}
	if hs.size() >= slots_for(profile):
		return {"kit": k, "result": "full"}
	hs.append(habit)
	return {"kit": k, "result": "on"}


## The loadout with `pistol` as the sidearm, or unchanged when it is locked / unknown. Pure.
static func set_pistol(kit: Dictionary, pistol: String, profile: Dictionary, character: String) -> Dictionary:
	var k: Dictionary = clean(kit, max_slots())
	if pistol_unlocked(pistol, profile, character):
		k["pistol"] = pistol
	return k


## One line for menus: "Walther P38 · Pay Packet, Whetstone".
static func summary(kit: Dictionary) -> String:
	var names: PackedStringArray = []
	for h: Variant in kit.get("habits", []):
		names.append(habit_name(str(h)))
	return "%s  ·  %s" % [pistol_name(str(kit.get("pistol", default_pistol()))), ", ".join(names) if not names.is_empty() else "no Field Habits"]


## The next few things rank opens, nearest first: [{rank, text}] (sidearms, habits, habit slots, then the cosmetic
## unlocks of progression.json), for the Muster's "next" list.
static func upcoming(rank_n: int, count: int = 4) -> Array:
	var rows: Array = []
	for r: Dictionary in pistol_rows():
		for u: Dictionary in r.get("unlock", []):
			if int(u.get("rank", 0)) > rank_n:
				rows.append({"rank": int(u["rank"]), "text": "Sidearm: " + pistol_name(str(r["id"]))})
	for h: Dictionary in habit_rows():
		for u2: Dictionary in h.get("unlock", []):
			if int(u2.get("rank", 0)) > rank_n:
				rows.append({"rank": int(u2["rank"]), "text": "Field Habit: " + str(h.get("name", h["id"]))})
	for s: Dictionary in cfg().get("slots", []):
		if int(s["rank"]) > rank_n:
			rows.append({"rank": int(s["rank"]), "text": "Field Habit slot %d" % int(s["slots"])})
	for c: Dictionary in ProfileSave.unlock_rows():
		if c.has("rank") and int(c["rank"]) > rank_n:
			rows.append({"rank": int(c["rank"]), "text": str(c.get("name", c["id"])) + " (%s)" % str(c.get("kind", "")).replace("_", " ")})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) < int(b["rank"]))
	return rows.slice(0, count)


## Saves a survivor's loadout in ProfileSave.profile (and writes the profile). Returns the stored, cleaned loadout.
static func save_loadout(character: String, kit: Dictionary) -> Dictionary:
	var prof: Dictionary = ProfileSave.profile
	if not prof.has("muster") or not (prof["muster"] is Dictionary):
		prof["muster"] = {}
	(prof["muster"] as Dictionary)[character] = clean(kit, max_slots())
	ProfileSave.save_profile()
	return loadout_for(character, prof)


## Every survivor's loadout from the local profile, as sent to a co-op host at join (Net._rpc_kits).
static func profile_kits() -> Dictionary:
	var out: Dictionary = {}
	for c: String in ["dutch", "peg", "deacon", "wren"]:
		out[c] = loadout_for(c, ProfileSave.profile)
	return out


## Host side: what a peer sent, structurally checked (known ids, the slot cap). The host trusts the peer's rank.
static func sanitize_kits(kits: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (kits is Dictionary):
		return out
	for c: Variant in (kits as Dictionary).keys():
		if ["dutch", "peg", "deacon", "wren"].has(str(c)):
			out[str(c)] = clean((kits as Dictionary)[c], max_slots())
	return out


# ================================================================== the match

## MapRoot._ready, before the players spawn: every player id's kit for this match. Solo: the local human (id 1)
## from the profile; bots get none. Online: each roster slot's kit for the survivor it plays.
static func begin_match(online: bool) -> void:
	match_kits = {}
	if classic_rules():
		return
	if online:
		for pid: Variant in Net.roster.keys():
			var kits: Dictionary = (Net.roster[pid] as Dictionary).get("kits", {})
			var ch: String = String(Net.character_of(int(pid)))
			if int(pid) == Net.local_player_id():
				match_kits[int(pid)] = loadout_for(ch, ProfileSave.profile)   # our own: the profile, fresh
			elif kits.has(ch):
				match_kits[int(pid)] = clean(kits[ch], max_slots())
		return
	match_kits[1] = loadout_for(String(GameState.character_id), ProfileSave.profile)


## Classic Rules (Settings) turns the Muster off too, as it does the survivors' traits: the plain M1911 kit.
static func classic_rules() -> bool:
	return bool(GLSettings.values.get("classic_rules", false))


static func kit_of(pid: int) -> Dictionary:
	return match_kits.get(pid, {})


static func has(pid: int, habit: String) -> bool:
	return (kit_of(pid).get("habits", []) as Array).has(habit)


## The pistol `pid` starts with (the default for bots, Jakub and anyone without a kit).
static func start_pistol(pid: int) -> StringName:
	var p: String = str(kit_of(pid).get("pistol", ""))
	var t: Dictionary = GLData.table("weapons")["weapons"]
	return StringName(p) if p != "" and t.has(p) else StringName(str(GLData.table("player")["start_loadout"]["primary"]))


## The combined effect `key` of `pid`'s habits: *_mult keys multiply, numbers add, a string replaces.
static func value(pid: int, key: String, default: Variant) -> Variant:
	var v: Variant = default
	for h: Variant in kit_of(pid).get("habits", []):
		var eff: Dictionary = habit_def(str(h)).get("effects", {})
		if not eff.has(key):
			continue
		var e: Variant = eff[key]
		if e is String:
			v = e
		elif key.ends_with("_mult"):
			v = float(v) * float(e)
		else:
			v = (float(v) + float(e)) if (v is float or e is float) else int(v) + int(e)
	return v


## A float effect (the common case).
static func mult(pid: int, key: String) -> float:
	return float(value(pid, key, 1.0))


## Start of a fresh match (MapRoot, authority, after Economy.reset, never on a campaign arrival): the Scrip bonus and
## each player's bleed-out clock.
static func apply_match_start(players: Dictionary, grant_scrip: bool) -> void:
	for pid: Variant in players.keys():
		var p: Player = players[pid] as Player
		if p == null or kit_of(int(pid)).is_empty():
			continue
		var bonus: float = float(value(int(pid), "bleedout_bonus_s", 0.0))
		if bonus > 0.0 and p.bleedout_seconds <= 0.0:
			p.bleedout_seconds = float(GLData.table("player")["bleedout_seconds"]) + bonus
		var s: int = int(value(int(pid), "start_scrip", 0))
		if grant_scrip and s > 0 and Net.is_authority():
			Economy.grant_raw(int(pid), s)   # a starting kit is no earning (T-141)


## A starting (or respawn) loadout in WeaponHolder: reserve, grenades and the tactical from the habits.
static func apply_start_kit(holder: WeaponHolder, pid: int) -> void:
	if kit_of(pid).is_empty() or holder.slots.is_empty():
		return
	var w: WeaponInstance = holder.slots[0]
	var rm: float = mult(pid, "start_reserve_mult")
	if rm != 1.0:
		w.reserve = int(round(float(w.reserve) * rm))
	holder.grenades = mini(holder.grenade_max(), holder.grenades + int(value(pid, "start_grenades", 0)))
	var tac: String = str(value(pid, "start_tactical", ""))
	if tac != "":
		holder.tactical_id = StringName(tac)
		holder.tactical_count = maxi(holder.tactical_count, 1)
