class_name SoundHunter
extends RefCounted
## How a desert stalker hears (UPDATE 10 §3 Act III, contract C6 `dust_storm`, DECISIONS T-157). In the haboob the
## act's stalkers (the Burrowers and the surface Gängers the GroomController marks while the storm runs) cannot see:
## they hunt by sound. Each one has a `hear_radius` (map04c.json groom.dust_storm.hear.radius_m); a player who
## sprints or has fired in the last `fire_window_s` is LOUD and is heard at `loud_mult` × that radius; walking is
## quiet (heard only inside the plain radius, which is about arm's reach plus a stride). A stalker that hears
## someone takes them as its target and remembers where it heard them; one that hears nobody walks to the last
## heard position and waits there. The rules are static (unit-tested); the per-zombie state lives on the Zombie
## (`hunt_by_sound`, `heard_at`, `hear_radius_m`) and the chase reads it through `Zombie._update_sound_hunt`.

## player_id -> msec of the last shot (the GroomController feeds it from GLBus.weapon_fired).
static var last_fire_ms: Dictionary = {}
## The window a shot stays loud for, and the loud multiplier (set from the map's json at match start).
static var fire_window_s: float = 1.5
static var loud_mult: float = 3.0


static func reset() -> void:
	last_fire_ms.clear()
	fire_window_s = 1.5
	loud_mult = 3.0


static func configure(hear_cfg: Dictionary) -> void:
	fire_window_s = float(hear_cfg.get("fire_window_s", 1.5))
	loud_mult = float(hear_cfg.get("loud_mult", 3.0))


static func note_fire(player_id: int, now_ms: int = -1) -> void:
	last_fire_ms[player_id] = Time.get_ticks_msec() if now_ms < 0 else now_ms


## True when a shot from `player_id` is still ringing at `now_ms`.
static func fired_recently(player_id: int, now_ms: int, window_s: float) -> bool:
	if not last_fire_ms.has(player_id):
		return false
	return float(now_ms - int(last_fire_ms[player_id])) <= window_s * 1000.0


## A player is loud while sprinting or right after a shot.
static func is_loud(sprinting: bool, fired: bool) -> bool:
	return sprinting or fired


## The distance a stalker with `base_m` hears a player at: × `mult` when the player is loud.
static func hear_radius(base_m: float, loud: bool, mult: float) -> float:
	return base_m * (mult if loud else 1.0)


## Heard: within the radius on the flat, and not a whole floor apart (the lab is below the salt).
static func can_hear(listener: Vector3, source: Vector3, radius_m: float, floor_tol_m: float = 3.0) -> bool:
	if absf(source.y - listener.y) > floor_tol_m:
		return false
	return Vector2(source.x - listener.x, source.z - listener.z).length() <= radius_m


## The nearest player `z` hears right now, or null (the per-frame query; `players` are the live Player nodes).
static func heard_player(z: Node3D, base_m: float, players: Array) -> Node3D:
	var now: int = Time.get_ticks_msec()
	var best: Node3D = null
	var best_d: float = INF
	for n: Variant in players:
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var loud: bool = is_loud(p.sprinting, fired_recently(p.player_id, now, fire_window_s))
		var r: float = hear_radius(base_m, loud, loud_mult)
		if not can_hear(z.global_position, p.global_position, r):
			continue
		var d: float = z.global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best
