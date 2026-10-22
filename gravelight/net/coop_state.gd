class_name CoopState
extends RefCounted
## Pure co-op life-cycle rules (GDD §3, unit-tested in tests/unit/test_coop.gd). Host-side only.
##   ALIVE -> (hp 0) DOWNED: crawls with a pistol; a teammate holding use for revive_seconds brings them back.
##   DOWNED -> (bleed-out timer hits 0) DEAD: spectates; respawns with the start loadout at the next round.
## The bleed-out timer pauses while someone is reviving (classic). The match is over when nobody is ALIVE.

enum Life { ALIVE, DOWNED, DEAD }

var players: Dictionary = {}   # pid -> {"life": Life, "bleed": float, "reviver": int}
## Companions (Jakub, U02 section 6.2): they go down, bleed out and get revived like anyone, but they never keep
## a match alive on their own (alive_count / everyone_down skip them) and never respawn (respawn_dead skips them).
var companions: Dictionary = {}   # pid -> true


func add(pid: int) -> void:
	players[pid] = {"life": Life.ALIVE, "bleed": 0.0, "reviver": 0}


func remove(pid: int) -> void:
	players.erase(pid)
	companions.erase(pid)


## A companion's life cycle (see `companions`).
func add_companion(pid: int) -> void:
	add(pid)
	companions[pid] = true


func is_companion(pid: int) -> bool:
	return companions.has(pid)


func life(pid: int) -> Life:
	return int((players.get(pid, {}) as Dictionary).get("life", Life.DEAD)) as Life


func is_alive(pid: int) -> bool:
	return players.has(pid) and life(pid) == Life.ALIVE


func is_downed(pid: int) -> bool:
	return players.has(pid) and life(pid) == Life.DOWNED


func is_dead(pid: int) -> bool:
	return players.has(pid) and life(pid) == Life.DEAD


func bleed_left(pid: int) -> float:
	return float((players.get(pid, {}) as Dictionary).get("bleed", 0.0))


func reviver_of(pid: int) -> int:
	return int((players.get(pid, {}) as Dictionary).get("reviver", 0))


## Goes down with `bleed_seconds` on the clock. Returns false if they weren't alive.
func down(pid: int, bleed_seconds: float) -> bool:
	if not is_alive(pid):
		return false
	players[pid] = {"life": Life.DOWNED, "bleed": bleed_seconds, "reviver": 0}
	return true


## A teammate finished the hold. Returns false if the target wasn't downed (already revived or bled out).
func revive(pid: int) -> bool:
	if not is_downed(pid):
		return false
	players[pid] = {"life": Life.ALIVE, "bleed": 0.0, "reviver": 0}
	return true


## Someone started (active) or stopped holding use on a downed player.
func set_reviver(pid: int, by: int, active: bool) -> void:
	if not is_downed(pid):
		return
	var p: Dictionary = players[pid]
	if active:
		p["reviver"] = by
	elif int(p["reviver"]) == by:
		p["reviver"] = 0


## Advances every bleed-out timer. Returns the pids that bled out on this tick (now DEAD).
func tick(dt: float, pause_while_reviving: bool = true) -> Array[int]:
	var out: Array[int] = []
	for pid: Variant in players.keys():
		var p: Dictionary = players[pid]
		if int(p["life"]) != Life.DOWNED:
			continue
		if pause_while_reviving and int(p["reviver"]) != 0:
			continue
		p["bleed"] = maxf(0.0, float(p["bleed"]) - dt)
		if float(p["bleed"]) <= 0.0:
			p["life"] = Life.DEAD
			p["reviver"] = 0
			out.append(int(pid))
	return out


## New round: every bled-out player comes back. Returns their pids.
func respawn_dead() -> Array[int]:
	var out: Array[int] = []
	for pid: Variant in players.keys():
		if int((players[pid] as Dictionary)["life"]) == Life.DEAD and not companions.has(int(pid)):
			players[pid] = {"life": Life.ALIVE, "bleed": 0.0, "reviver": 0}
			out.append(int(pid))
	return out


func alive_count() -> int:
	var n: int = 0
	for pid: Variant in players.keys():
		if int((players[pid] as Dictionary)["life"]) == Life.ALIVE and not companions.has(int(pid)):
			n += 1
	return n


## Game over: there are players and none of them is standing (downed and dead both count as down). A companion
## still standing does not keep the match going.
func everyone_down() -> bool:
	return players.size() > companions.size() and alive_count() == 0


## Revive hold time for a reviver whose perks give `revive_speed_mult` (Second Wind: 2x -> 2 s).
static func revive_seconds(base_seconds: float, revive_speed_mult: float) -> float:
	return base_seconds / maxf(0.01, revive_speed_mult)


## Compact form for the state snapshot: pid -> [life, bleed_left, reviver].
func to_net() -> Dictionary:
	var out: Dictionary = {}
	for pid: Variant in players.keys():
		var p: Dictionary = players[pid]
		out[int(pid)] = [int(p["life"]), snappedf(float(p["bleed"]), 0.1), int(p["reviver"])]
	return out


func from_net(d: Dictionary) -> void:
	players.clear()
	for pid: Variant in d.keys():
		var a: Array = d[pid]
		players[int(pid)] = {"life": int(a[0]), "bleed": float(a[1]), "reviver": int(a[2])}
