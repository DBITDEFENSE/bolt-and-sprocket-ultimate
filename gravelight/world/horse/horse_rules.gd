class_name HorseRules
extends RefCounted
## The rideable horse's rules as pure functions (T-240; data/gravelight/horse.json, tested by test_horse_gait.gd):
## how the pace answers the rider, how fast it may turn, when the rider may shoot, what a crowd of zombies does to
## it, what it does to a zombie it gallops through, where it may stand, where a rider may get down, who may mount.

const PATH: String = "res://data/gravelight/horse.json"

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		_table = GLData.load_json(PATH)
	return _table


static func block(key: String) -> Dictionary:
	return table().get(key, {})


## The speed (m/s) a pace asks for: 0 stand, 1 walk, 2 trot, 3 gallop, in between a blend.
static func pace_speed(pace: float, r: Dictionary) -> float:
	var s: Array = [0.0, float(r.get("walk_speed", 1.9)), float(r.get("trot_speed", 4.6)), float(r.get("gallop_speed", 9.5))]
	var p: float = clampf(pace, 0.0, 3.0)
	var i: int = mini(int(p), 2)
	return lerpf(float(s[i]), float(s[i + 1]), p - float(i))


## The pace after `dt`: forward (throttle > 0) urges it on, back reins it in, no input lets it ease to a walk on
## its own (never to a stop: that takes the reins). `cap` is the fastest pace it will give now (a crowd, a boss).
static func pace_step(pace: float, throttle: float, sprint: bool, dt: float, r: Dictionary, cap: float = 3.0) -> float:
	var p: float = pace
	if throttle > 0.1:
		p += (float(r.get("sprint_urge_per_s", 1.7)) if sprint else float(r.get("urge_per_s", 0.9))) * throttle * dt
	elif throttle < -0.1:
		p -= float(r.get("rein_per_s", 2.2)) * -throttle * dt
	else:
		var rest: float = float(r.get("ease_floor", 1.0))
		if p > rest:
			p = maxf(rest, p - float(r.get("ease_per_s", 0.22)) * dt)
	return clampf(p, 0.0, maxf(0.0, minf(3.0, cap)))


## The speed after `dt`, going toward `want` (signed): its own acceleration on the way up, a harder one coming
## down, the hardest when the rider reins in.
static func speed_step(speed: float, want: float, reining: bool, dt: float, r: Dictionary) -> float:
	var rate: float = float(r.get("accel", 3.6))
	if absf(want) < absf(speed) or (absf(speed) > 0.01 and want * speed < 0.0):
		rate = float(r.get("brake", 7.5)) if reining else float(r.get("decel", 4.5))
	return move_toward(speed, want, rate * dt)


## Radians per second it can turn at `speed`.
static func turn_rate(speed: float, r: Dictionary) -> float:
	var tr: Array = r.get("turn_rate", [1.5, 1.45, 1.15, 1.0])
	var s: float = absf(speed)
	var marks: Array = [0.0, float(r.get("walk_speed", 1.9)), float(r.get("trot_speed", 4.6)), float(r.get("gallop_speed", 9.5))]
	for i: int in 3:
		if s <= float(marks[i + 1]):
			return lerpf(float(tr[i]), float(tr[i + 1]), (s - float(marks[i])) / maxf(float(marks[i + 1]) - float(marks[i]), 0.01))
	return float(tr[3])


## The fastest it goes while turned this hard (steer -1..1): a hard turn brings a gallop down.
static func turn_speed_cap(steer: float, r: Dictionary) -> float:
	return lerpf(float(r.get("gallop_speed", 9.5)), float(r.get("turn_gallop_speed", 6.4)), clampf(absf(steer), 0.0, 1.0))


## The turn the body is making (-1..1) after `dt`, going toward the rider's `steer` with its lag.
static func steer_step(cur: float, steer: float, dt: float, r: Dictionary) -> float:
	return lerpf(cur, clampf(steer, -1.0, 1.0), 1.0 - exp(-dt / maxf(0.01, float(r.get("turn_lag_s", 0.28)))))


## True when a rider may shoot from the saddle: seated (not getting up or down) and at a trot or slower.
static func can_fire(gait: int, seated: bool, f: Dictionary) -> bool:
	return seated and gait <= int(f.get("max_gait", HorseGait.Gait.TROT))


## How much of the gait's motion reaches the rider's aim.
static func fire_sway(gait: int, f: Dictionary) -> float:
	match gait:
		HorseGait.Gait.WALK:
			return float(f.get("sway_walk", 0.6))
		HorseGait.Gait.TROT:
			return float(f.get("sway_trot", 1.0))
	return 0.25


## The fastest pace it will give with `zombies` crowding it and a horse boss `boss_dist` metres off.
static func pace_cap(zombies: int, boss_dist: float, c: Dictionary, bf: Dictionary) -> float:
	var cap: float = 3.0
	var over: int = zombies - int(c.get("free", 1))
	if over > 0:
		cap = maxf(float(c.get("min_pace", 1.4)), 3.0 - float(c.get("pace_per", 0.5)) * float(over))
	if boss_dist <= float(bf.get("radius", 14.0)):
		cap = minf(cap, float(bf.get("max_pace", 1.0)))
	return cap


## 0..1: how hard it shies (the pose, the snort): from the crowd, all the way near a boss.
static func shy_level(zombies: int, boss_dist: float, c: Dictionary, bf: Dictionary) -> float:
	var k: float = clampf(float(zombies) / maxf(1.0, float(c.get("shy_at", 3))), 0.0, 1.0)
	if boss_dist <= float(bf.get("radius", 14.0)):
		k = maxf(k, 1.0 - 0.4 * boss_dist / maxf(1.0, float(bf.get("radius", 14.0))))
	return k


## What galloping through a zombie does: {} when too slow or still cooling down, else {damage, push, push_s, slow}.
static func trample(speed: float, cooldown_left: float, t: Dictionary) -> Dictionary:
	if absf(speed) < float(t.get("speed_min", 6.0)) or cooldown_left > 0.0:
		return {}
	return {"damage": float(t.get("damage", 90)), "push": float(t.get("push", 7.0)), "push_s": float(t.get("push_s", 0.5)), "slow": float(t.get("slow", 0.35))}


## True when it may stand at a spot in `zone` (one of its zones, open) at height `y` (near its rail's).
static func may_stand(zone: StringName, zone_open: bool, y: float, home_y: float, zones: Array, b: Dictionary) -> bool:
	if zone == &"" or not zone_open:
		return false
	var ok: bool = false
	for z: Variant in zones:
		if StringName(str(z)) == zone:
			ok = true
	return ok and y <= home_y + float(b.get("y_up", 0.9)) and y >= home_y - float(b.get("y_down", 0.6))


## Who may get on: a live human on their feet, not carried by anything, and nobody in the saddle. Bots never.
static func may_mount(has_rider: bool, alive: bool, downed: bool, is_bot: bool, carried: bool) -> bool:
	return not has_rider and alive and not downed and not is_bot and not carried


## Where a rider may get down, in the horse's frame, best first: the near (left) side, the off side, then further
## out and behind. The horse picks the first that is free.
static func dismount_offsets() -> Array[Vector3]:
	return [Vector3(-1.15, 0, -0.1), Vector3(1.15, 0, -0.1), Vector3(-1.2, 0, 0.9), Vector3(1.2, 0, 0.9),
		Vector3(-1.7, 0, -0.1), Vector3(1.7, 0, -0.1), Vector3(0, 0, 2.1), Vector3(-1.2, 0, -1.2), Vector3(1.2, 0, -1.2)]


## True when it should set off for its rail: nobody on it for `idle_s`, and not there already.
static func home_due(idle: float, dist: float, has_rider: bool, h: Dictionary) -> bool:
	return not has_rider and idle >= float(h.get("idle_s", 25.0)) and dist > float(h.get("arrive_m", 0.5))


## A puppet's heading (a peer that only sees the rider move): toward where the rider is going, when they are moving.
static func puppet_yaw(yaw: float, vel: Vector3, dt: float) -> float:
	var flat: Vector2 = Vector2(vel.x, vel.z)
	if flat.length() < 0.6:
		return yaw
	return lerp_angle(yaw, atan2(-vel.x, -vel.z), 1.0 - exp(-dt * 6.0))
