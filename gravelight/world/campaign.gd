class_name Campaign
extends RefCounted
## The campaign chain (DECISIONS T-033): Map 0 -> Map 1 -> Map 2, joined by exfil beacons. Static state that
## survives a scene change, and the pure rules around it (unit-tested in tests/unit/test_campaign.gd).
##
##   active   a campaign run is in progress: MapRoot spawns the map's ExfilPoint (data: <map>.json "exfil")
##   carry    the payload for the map being loaded: every player's character, weapons (ammo, upgraded state),
##            Scrip, perks, grenades/tactical, plus the round, the special/boss schedule and the match stats.
##            The host builds it at departure (snapshot) and every peer gets a copy (Net.travel); MapRoot
##            consumes it on arrival (on_roster / on_players_spawned / on_rounds_started).
##
## Single-map play (the menu's map buttons, the lobby's map list) never sets `active`, so it has no beacon
## and plays exactly as before.

const PATH_DATA: String = "res://data/gravelight/"

static var active: bool = false
static var carry: Dictionary = {}
## Tests / tools: cutscene timers run this many times faster (1 = real time).
static var cutscene_speed: float = 1.0
static var _arrival: Dictionary = {}


static func cfg() -> Dictionary:
	return GLData.table("campaign")


static func reset() -> void:
	active = false
	carry = {}
	_arrival = {}


## Starts a campaign run from the first map of the chain (the menu's "Campaign" button).
static func begin() -> void:
	reset()
	active = true


static func chain() -> Array:
	return cfg().get("chain", [])


static func first_map() -> StringName:
	var c: Array = chain()
	return StringName(str(c[0])) if not c.is_empty() else &"map00_crossroads"


## The scene a map id loads (campaign.json "scenes", else the folder convention). "" when unknown.
static func scene_for(map_id: StringName) -> String:
	var scenes: Dictionary = cfg().get("scenes", {})
	if scenes.has(String(map_id)):
		return str(scenes[String(map_id)])
	var short: String = String(map_id).get_slice("_", 0)
	return "res://gravelight/maps/%s/%s.tscn" % [map_id, short]


static func display_name(map_id: StringName) -> String:
	return str((cfg().get("display_names", {}) as Dictionary).get(String(map_id), String(map_id)))


## True when the map a run would travel to exists in this build (the third map may still be in the works).
static func scene_exists(map_id: StringName) -> bool:
	var path: String = scene_for(map_id)
	return path != "" and ResourceLoader.exists(path)


## A map's "exfil" block (data/gravelight/<map00>.json), {} when the map has none.
static func exfil_cfg(map_id: StringName) -> Dictionary:
	var short: String = String(map_id).get_slice("_", 0)
	var d: Dictionary = GLData.load_json(PATH_DATA + short + ".json")
	return d.get("exfil", {})


## Problems with an exfil block (empty = valid). Pure, so the data can be checked in a test.
static func validate_exfil(e: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if int(e.get("round", 0)) < 1:
		errors.append("round must be 1+")
	if str(e.get("target", "")) == "":
		errors.append("target map id missing")
	var pos: Variant = e.get("position")
	if not (pos is Array) or (pos as Array).size() != 3:
		errors.append("position must be [x, y, z]")
	if float(e.get("window_seconds", 0.0)) <= 0.0:
		errors.append("window_seconds must be > 0")
	if int(e.get("retry_rounds", 0)) < 1:
		errors.append("retry_rounds must be 1+")
	if str(e.get("cutscene", "")) == "":
		errors.append("cutscene id missing")
	return errors


static func exfil_position(e: Dictionary) -> Vector3:
	var p: Array = e.get("position", [0.0, 0.0, 0.0])
	return Vector3(float(p[0]), float(p[1]), float(p[2])) if p.size() >= 3 else Vector3.ZERO


## The round the beacon lights on attempt `attempt` (0 = the first): round, then every retry_rounds after a
## missed window, so nobody is soft-locked by one bad round.
static func exfil_round(e: Dictionary, attempt: int) -> int:
	return int(e.get("round", 10)) + maxi(0, attempt) * int(e.get("retry_rounds", 3))


## The round the next map starts on: the round the squad left on, plus one.
static func arrival_round(left_on: int) -> int:
	return maxi(1, left_on) + 1


## A carried schedule entry (next special / boss round) that already passed is pushed past the arrival round
## with the same gap it would have had, so Bellringers and the Foreman keep their rhythm across maps.
static func carried_schedule(next_round: int, arrival: int, gap_min: int, gap_max: int, rng: RandomNumberGenerator) -> int:
	return RoundManager.carried_schedule(next_round, arrival, gap_min, gap_max, rng)


# ---------------------------------------------------------------- serialization

## One player's kit: character, both weapons with ammo (an upgraded weapon keeps its upgraded id), the melee,
## grenades, the tactical (Siren Gramophone), Scrip, perks and bonus perk slots.
static func serialize_player(p: Player) -> Dictionary:
	var pid: int = p.player_id
	var inv: Dictionary = p.weapons.to_net() if p.weapons != null else {}
	if p.weapons != null and p.weapons.in_last_stand():
		inv = stash_to_net(p.weapons)   # a downed player leaves with the kit they put away, not the crawl pistol
	var perks: Array = []
	for perk: Variant in PerkManager.owned(pid):
		perks.append(String(perk))
	return {
		"pid": pid,
		"character": String(GameState.character_of(pid)),
		"bot": p.is_bot,
		"inv": inv,
		"scrip": Economy.get_scrip(pid),
		"perks": perks,
		"bonus_slots": int(PerkManager._bonus_slots.get(pid, 0)),
	}


## The loadout a last-stand player stashed (WeaponHolder.enter_last_stand), in to_net() shape.
static func stash_to_net(w: WeaponHolder) -> Dictionary:
	var stash: Dictionary = w._last_stand_stash
	var s: Array = []
	for sw: Variant in stash.get("slots", []):
		var wi: WeaponInstance = sw as WeaponInstance
		s.append([String(wi.id), wi.mag, wi.reserve, wi.fire_mode, wi.underbarrel_active, wi.underbarrel_ammo])
	return {"s": s, "c": int(stash.get("current", 0)), "m": String(w.melee_id), "g": w.grenades, "t": String(w.tactical_id), "tc": w.tactical_count}


## The whole payload (host / solo): every player, the round, the schedules, the stats, the roster.
static func snapshot(map: MapRoot, target: StringName, cutscene_id: String) -> Dictionary:
	var players: Dictionary = {}
	for pid: Variant in map.players.keys():
		players[int(pid)] = serialize_player(map.players[pid] as Player)
	var chars: Dictionary = {}
	for pid2: Variant in GameState.characters.keys():
		chars[int(pid2)] = String(GameState.characters[pid2])
	return {
		"from": String(map.map_id),
		"to": String(target),
		"cutscene": cutscene_id,
		"round": RoundManager.current_round,
		"next_special": RoundManager.next_special,
		"next_boss": RoundManager.next_boss,
		"players": players,
		"stats": GameState.stats.duplicate(),
		"elapsed": GameState.elapsed_seconds(),
		"bot_ids": GameState.bot_ids.duplicate(),
		"bot_count": GameState.bot_count,
		"bot_skill": GameState.bot_skill,
		"character_id": String(GameState.character_id),
		"characters": chars,
		"god_mode": GameState.god_mode,
	}


## Every weapon id in the payload exists in the weapons tables (a stale save could not), the round is sane.
static func validate_payload(d: Dictionary, weapons: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if int(d.get("round", 0)) < 1:
		errors.append("round must be 1+")
	if str(d.get("to", "")) == "":
		errors.append("target missing")
	var base: Dictionary = weapons.get("weapons", {})
	var up: Dictionary = weapons.get("upgraded", {})
	for pid: Variant in (d.get("players", {}) as Dictionary).keys():
		var p: Dictionary = (d["players"] as Dictionary)[pid]
		for e: Variant in (p.get("inv", {}) as Dictionary).get("s", []):
			var wid: String = str((e as Array)[0])
			if not base.has(wid) and not up.has(wid):
				errors.append("player %s carries unknown weapon %s" % [str(pid), wid])
	return errors


## Is this weapon entry (to_net shape) an upgraded (Crucible) weapon?
static func entry_is_upgraded(entry: Array, weapons: Dictionary) -> bool:
	return (weapons.get("upgraded", {}) as Dictionary).has(str(entry[0]))


# ---------------------------------------------------------------- travel (host / solo)

## Sets the static state and loads the target. Online: the host sends everyone (Net.travel).
static func travel(payload: Dictionary, tree: SceneTree) -> void:
	var target: StringName = StringName(str(payload.get("to", "")))
	var scene: String = scene_for(target)
	carry = payload
	prepare_state(payload)
	if Net.is_host():
		Net.travel(scene, payload)
		return
	tree.paused = false
	tree.change_scene_to_file(scene)


## Before the new map's MapRoot runs: the squad composition it will rebuild (bots, skill, survivors).
static func prepare_state(payload: Dictionary) -> void:
	active = true
	GameState.bot_count = int(payload.get("bot_count", GameState.bot_count))
	GameState.bot_skill = str(payload.get("bot_skill", GameState.bot_skill))
	GameState.character_id = StringName(str(payload.get("character_id", GameState.character_id)))


# ---------------------------------------------------------------- arrival (MapRoot hooks)

## Is the carried payload for this map?
static func arriving(map_id: StringName) -> bool:
	return active and not carry.is_empty() and str(carry.get("to", "")) == String(map_id)


## MapRoot, offline, after _assign_bots(): the same survivors keep the same player ids.
static func on_roster(map: MapRoot) -> void:
	if not arriving(map.map_id) or Net.is_online():
		return
	var chars: Dictionary = carry.get("characters", {})
	if chars.is_empty():
		return
	for pid: Variant in chars.keys():
		if GameState.characters.has(int(pid)) or int(pid) == 1:
			GameState.characters[int(pid)] = StringName(str(chars[pid]))


## MapRoot, after the players, Economy and PerkManager are set up: everyone's kit comes back.
## Every peer restores the player it owns (its local human; the authority also its bots); a teammate's puppet
## gets its inventory from its owner over the usual inventory stream. Scrip and perks are the authority's.
static func on_players_spawned(map: MapRoot) -> void:
	if not arriving(map.map_id):
		return
	_arrival = carry.duplicate(true)
	carry = {}
	GameState.input_blocked = false   # the departure froze everyone for the cutscene
	GameState.god_mode = bool(_arrival.get("god_mode", false))
	var players: Dictionary = _arrival.get("players", {})
	for pid: Variant in map.players.keys():
		var p: Player = map.players[pid] as Player
		var d: Dictionary = players.get(int(pid), players.get(str(pid), {}))
		if d.is_empty():
			continue
		if p.is_local or (p.is_bot and Net.is_authority()):
			restore_loadout(p, d.get("inv", {}))
		if Net.is_authority():
			restore_account(int(pid), d)
	if Net.is_authority():
		var stats: Dictionary = _arrival.get("stats", {})
		for k: Variant in stats.keys():
			if k != &"round" and k != "round":
				GameState.stats[StringName(str(k))] = stats[k]
		GameState.credit_elapsed(float(_arrival.get("elapsed", 0.0)))
	ProfileSave.unlock_map(map.map_id)
	print("[campaign] arrived at %s from %s: round %d next, %d players restored" % [map.map_id, str(_arrival.get("from", "?")),
		arrival_round(int(_arrival.get("round", 0))), players.size()])


static func restore_loadout(p: Player, inv: Dictionary) -> void:
	if p.weapons == null or inv.is_empty():
		return
	p.weapons.apply_carry(inv)
	if p.remote_body != null:
		var w: WeaponInstance = p.weapons.current()
		p.remote_body.set_weapon(w.id if w != null else &"")


static func restore_account(pid: int, d: Dictionary) -> void:
	var scrip: int = int(d.get("scrip", Economy.get_scrip(pid)))
	Economy._scrip[pid] = scrip
	GLBus.scrip_changed.emit(pid, scrip, 0)
	var perks: Array = []
	for perk: Variant in d.get("perks", []):
		if not PerkManager.perk_data(StringName(str(perk))).is_empty():
			perks.append(StringName(str(perk)))
	var bonus: int = int(d.get("bonus_slots", 0))
	if bonus > 0:
		PerkManager._bonus_slots[pid] = maxi(bonus, int(PerkManager._bonus_slots.get(pid, 0)))
	PerkManager._owned[pid] = perks
	GLBus.perks_changed.emit(pid)


## MapRoot.start_rounds (host / solo), after RoundManager.start_game: the round count continues. The first
## round on the new map (round N+1) waits arrival_grace_seconds instead of the usual intro.
static func on_rounds_started(map: MapRoot) -> void:
	if _arrival.is_empty() or str(_arrival.get("to", "")) != String(map.map_id):
		return
	var left_on: int = int(_arrival.get("round", 0))
	RoundManager.resume_at(left_on, int(_arrival.get("next_special", 0)), int(_arrival.get("next_boss", 0)),
		float(cfg().get("arrival_grace_seconds", 14.0)))
	if map.hud != null:
		map.hud.show_banner(str(cfg().get("arrival_banner", "%s\nRound %d")) % [map.display_name.to_upper(), arrival_round(left_on)], 4.0)
	_arrival = {}
