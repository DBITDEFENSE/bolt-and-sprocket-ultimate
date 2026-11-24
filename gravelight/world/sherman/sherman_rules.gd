class_name ShermanRules
extends RefCounted
## The Sherman's judgement and its driving as pure rules (T-261; numbers in data/gravelight/sherman.json "assist" and
## "drive", the grounds in the map json's "sherman_event"): which of the dead the 75 mm and the machine gun take, where
## the turret watches with nothing to shoot, how the hull answers the throttle and the steer, where it may stand, who
## may climb in, what the tracks do to the dead. ShermanTank gathers the world (who is where, what it sees) and asks
## here; tests/unit/test_sherman.gd holds the rules to their word.
##
## One of the dead, as the gunner sees it, is a Dictionary:
##   pos (Vector3)   where it stands
##   ok (bool)       it can be shot now: in range, in sight, not still rising
##   lay (bool)      the gun may be laid on it: as ok, or still rising in sight (a pack coming up out of the ground
##                   is laid on while it rises; the shell waits until one of them is up)
##   under (bool)    hugging the hull, under the guns
##   fire (bool)     a burning one (it bursts where it dies)
##   boss (bool)     the round's boss
##   on_hull (bool)  it is going for the tank itself
##   hp (float)      0..1 of its health left

const HULL_HALF_W: float = 1.31
const HULL_BOW: float = -2.97
const HULL_STERN: float = 3.05


# ================================================================== geometry

static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## How far `p` is from the segment a..b (the line of fire).
static func lane_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	return Geometry3D.get_closest_point_to_segment(p, a, b).distance_to(p)


static func nearest(p: Vector3, pts: Array) -> float:
	var best: float = INF
	for q: Vector3 in pts:
		best = minf(best, q.distance_to(p))
	return best


## How far `p` is outside the hull's flat footprint (0 inside it).
static func hull_dist(hull: Transform3D, p: Vector3) -> float:
	var l: Vector3 = hull.affine_inverse() * p
	var dx: float = maxf(0.0, absf(l.x) - HULL_HALF_W)
	var dz: float = maxf(0.0, maxf(HULL_BOW - l.z, l.z - HULL_STERN))
	return Vector2(dx, dz).length()


# ================================================================== the 75 mm

## What one of the dead is worth to a shell: a burning one and the boss are worth a shell alone.
static func shell_weight(e: Dictionary, a: Dictionary) -> float:
	if bool(e.get("boss", false)):
		return float(a.get("gun_weight_boss", 3.0))
	if bool(e.get("fire", false)):
		return float(a.get("gun_weight_fire", 2.5))
	if bool(e.get("on_hull", false)):
		return float(a.get("gun_weight_on_hull", 1.25))
	return 1.0


## The shell's worth at `at`: every one of the dead within its radius, whole within gun_cluster_m (a pack), a quarter
## at the edge.
static func shell_score(at: Vector3, dead: Array, a: Dictionary) -> float:
	var r: float = float(a.get("gun_radius", 6.0))
	var inner: float = float(a.get("gun_cluster_m", 4.0))
	var s: float = 0.0
	for e: Dictionary in dead:
		var d: float = (e["pos"] as Vector3).distance_to(at)
		if d > r:
			continue
		var k: float = 1.0 if d <= inner else lerpf(1.0, 0.25, (d - inner) / maxf(0.01, r - inner))
		s += shell_weight(e, a) * k
	return s


## May a shell burst at `at`? Never within gun_player_clear_m of a player, never with a player within gun_lane_m of
## its line from the muzzle, never within gun_min_m of the hull (its own blast, and the gun cannot be laid that low),
## never where a burning one in its blast would burst within fire_clear_m of a player or against the hull.
static func shell_allowed(at: Vector3, dead: Array, players: Array, hull: Transform3D, muzzle: Vector3, a: Dictionary) -> bool:
	if flat(at, hull.origin) < float(a.get("gun_min_m", 9.0)) or flat(at, hull.origin) > float(a.get("range", 45.0)):
		return false
	for p: Vector3 in players:
		if p.distance_to(at) < float(a.get("gun_player_clear_m", 8.0)):
			return false
		if lane_dist(p + Vector3.UP * 1.0, muzzle, at) < float(a.get("gun_lane_m", 2.0)):
			return false
	var r: float = float(a.get("gun_radius", 6.0))
	var fc: float = float(a.get("fire_clear_m", 5.0))
	for e: Dictionary in dead:
		if not bool(e.get("fire", false)) or (e["pos"] as Vector3).distance_to(at) > r:
			continue
		if nearest(e["pos"], players) < fc or hull_dist(hull, e["pos"]) < float(a.get("fire_hull_clear_m", 2.5)):
			return false
	return true


## The 75 mm's target: the place among the dead it can shoot where a shell is worth most ({} = hold fire). A shell is
## fired for a pack, a burning one, the boss (gun_min_score), or one alone far off (gun_lone_m); a little more for the
## ones nearer the hull. With `near`, only places within near_m of it (the pack already laid on, followed as it
## moves). Returns {"at": Vector3, "score": float}.
static func pick_shell(dead: Array, players: Array, hull: Transform3D, muzzle: Vector3, a: Dictionary, near: Vector3 = Vector3.INF, near_m: float = 0.0) -> Dictionary:
	var best: Dictionary = {}
	var best_s: float = 0.0
	var need: float = float(a.get("gun_min_score", 2.0))
	var rng_m: float = float(a.get("range", 45.0))
	for e: Dictionary in dead:
		if not bool(e.get("lay", e.get("ok", false))) or bool(e.get("under", false)):
			continue
		var at: Vector3 = e["pos"]
		if near != Vector3.INF and flat(at, near) > near_m:
			continue
		if not shell_allowed(at, dead, players, hull, muzzle, a):
			continue
		var s: float = shell_score(at, dead, a)
		var lone: bool = flat(at, hull.origin) >= float(a.get("gun_lone_m", 18.0))
		if s < need and not lone:
			continue
		s *= 1.0 + 0.3 * clampf(1.0 - flat(at, hull.origin) / maxf(1.0, rng_m), 0.0, 1.0)
		if s > best_s:
			best_s = s
			best = {"at": at, "score": s}
	return best


## Is one of the dead that can be shot now (`ok`) within the shell's radius of `at`? (A shell laid on a rising pack
## is not fired into empty snow.)
static func shell_has_target(at: Vector3, dead: Array, a: Dictionary) -> bool:
	var r: float = float(a.get("gun_radius", 6.0))
	for e: Dictionary in dead:
		if bool(e.get("ok", false)) and (e["pos"] as Vector3).distance_to(at) <= r:
			return true
	return false


## Seconds until the gun is loaded again, as a 0..1 share done.
static func reload_frac(left: float, reload: float) -> float:
	return clampf(1.0 - left / maxf(0.01, reload), 0.0, 1.0)


# ================================================================== the machine gun

## How much the machine gun wants one of the dead (-INF = never): not what it cannot see or what is under the guns,
## not within mg_player_clear_m of a player, not a burning one that would burst on a player or on the hull. Then: the
## nearer the better, a burning one while it is still far from everyone first, the boss, what is going for the hull,
## what is closing on a player, what is already hurt (finish it rather than start on another).
static func mg_score(e: Dictionary, players: Array, hull: Transform3D, a: Dictionary) -> float:
	if not bool(e.get("ok", false)) or bool(e.get("under", false)):
		return -INF
	var pos: Vector3 = e["pos"]
	var np: float = nearest(pos, players)
	if np < float(a.get("mg_player_clear_m", 1.5)):
		return -INF
	if bool(e.get("fire", false)) and (np < float(a.get("fire_clear_m", 5.0)) or hull_dist(hull, pos) < float(a.get("fire_hull_clear_m", 2.5))):
		return -INF
	var d: float = flat(pos, hull.origin)
	var s: float = 10.0 * clampf(1.0 - d / maxf(1.0, float(a.get("range", 45.0))), 0.0, 1.0)
	if bool(e.get("fire", false)):
		s += float(a.get("mg_bonus_fire", 6.0))
	if bool(e.get("boss", false)):
		s += float(a.get("mg_bonus_boss", 2.0))
	if bool(e.get("on_hull", false)):
		s += float(a.get("mg_bonus_on_hull", 3.0))
	s += float(a.get("mg_bonus_hurt", 4.0)) * (1.0 - clampf(float(e.get("hp", 1.0)), 0.0, 1.0))
	s += float(a.get("mg_bonus_player", 3.0)) * clampf(1.0 - np / 10.0, 0.0, 1.0)
	return s


## The machine gun's target: the index in `dead` of the best one with a clear line from the coax (no player within
## mg_lane_m of it), -1 for none. The one it is already on (`current`) keeps a little, so it does not flit.
static func pick_mg(dead: Array, players: Array, hull: Transform3D, coax: Vector3, a: Dictionary, current: int = -1) -> int:
	var best: int = -1
	var best_s: float = -INF
	for i: int in dead.size():
		var e: Dictionary = dead[i]
		var s: float = mg_score(e, players, hull, a)
		if s == -INF:
			continue
		var blocked: bool = false
		for p: Vector3 in players:
			if lane_dist(p + Vector3.UP * 1.0, coax, (e["pos"] as Vector3) + Vector3.UP * 1.0) < float(a.get("mg_lane_m", 1.0)):
				blocked = true
				break
		if blocked:
			continue
		if i == current:
			s += float(a.get("mg_stick", 2.0))
		if s > best_s:
			best_s = s
			best = i
	return best


# ================================================================== the watch

## Where the turret looks with nothing to shoot: the heaviest sector of the dead round the hull (hull-frame yaw in
## radians, 0 = over the bow; the nearer count more, the burning double), NAN when none is about. `dead` may hold
## what it cannot see or shoot yet (the ones still rising, the ones behind a wall: the crew hears them).
static func watch_yaw(dead: Array, hull: Transform3D, a: Dictionary) -> float:
	var n: int = maxi(4, int(a.get("watch_sectors", 12)))
	var reach: float = float(a.get("watch_m", 60.0))
	var w: PackedFloat32Array = PackedFloat32Array()
	w.resize(n)
	var sx: PackedFloat32Array = PackedFloat32Array()
	sx.resize(n)
	var sz: PackedFloat32Array = PackedFloat32Array()
	sz.resize(n)
	var inv: Transform3D = hull.affine_inverse()
	for e: Dictionary in dead:
		var l: Vector3 = inv * (e["pos"] as Vector3)
		var d: float = Vector2(l.x, l.z).length()
		if d > reach or d < 0.5:
			continue
		var yaw: float = atan2(-l.x, -l.z)
		var k: int = int(floor(fposmod(yaw + PI / float(n), TAU) / (TAU / float(n)))) % n
		var wt: float = (2.0 if bool(e.get("fire", false)) else 1.0) / (d + 5.0)
		w[k] += wt
		sx[k] += sin(yaw) * wt
		sz[k] += cos(yaw) * wt
	var best: int = -1
	for k2: int in n:
		if w[k2] > 0.0 and (best < 0 or w[k2] > w[best]):
			best = k2
	if best < 0:
		return NAN
	return atan2(sx[best], sz[best])


## The yaw the turret keeps when the grounds are empty: it turns between watch_yaws_deg, watch_dwell_s on each.
static func scan_yaw(t: float, a: Dictionary) -> float:
	var yaws: Array = a.get("watch_yaws_deg", [0.0, 180.0])
	if yaws.is_empty():
		return 0.0
	var dwell: float = maxf(1.0, float(a.get("watch_dwell_s", 7.0)))
	return deg_to_rad(float(yaws[int(floor(t / dwell)) % yaws.size()]))


# ================================================================== driving

## One step of the tracks: the speed answers the throttle (-1..1; slower backwards, slower in a turn), the hull turns
## with the steer (-1..1, right positive): on the spot at pivot_rate_deg, less sharply at speed (turn_rate_deg).
## Returns {"speed": m/s forward, "yaw_rate": rad/s (positive = to the left, as rotation.y counts)}.
static func drive_step(speed: float, throttle: float, steer: float, dt: float, d: Dictionary) -> Dictionary:
	throttle = clampf(throttle, -1.0, 1.0)
	steer = clampf(steer, -1.0, 1.0)
	var top: float = float(d.get("speed", 3.2))
	var want: float = throttle * (top if throttle >= 0.0 else float(d.get("reverse_speed", 1.6)))
	want *= 1.0 - float(d.get("turn_slow", 0.35)) * absf(steer)
	var gaining: bool = absf(want) > absf(speed) and signf(want) == signf(speed) or (absf(speed) < 0.05 and absf(want) > 0.0)
	var rate: float = float(d.get("accel", 1.6)) if gaining else float(d.get("brake", 3.0))
	var out: float = move_toward(speed, want, rate * dt)
	var k: float = clampf(absf(out) / maxf(0.1, top), 0.0, 1.0)
	var turn: float = deg_to_rad(lerpf(float(d.get("pivot_rate_deg", 34.0)), float(d.get("turn_rate_deg", 24.0)), k))
	return {"speed": out, "yaw_rate": -steer * turn}


## The hull's footprint for the ground rules: its corners, the middle of each side, bow, stern and centre.
static func footprint(hull: Transform3D, grow: float = 0.0) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var w: float = HULL_HALF_W + grow
	for z: float in [HULL_BOW - grow, 0.0, HULL_STERN + grow]:
		for x: float in [-w, 0.0, w]:
			out.append(hull * Vector3(x, 0.0, z))
	return out


## Is the flat point inside one of `boxes` ([x0, z0, x1, z1] each)? No boxes: everywhere.
static func in_boxes(p: Vector3, boxes: Array) -> bool:
	if boxes.is_empty():
		return true
	for b: Variant in boxes:
		var v: Array = b
		if p.x >= float(v[0]) and p.x <= float(v[2]) and p.z >= float(v[1]) and p.z <= float(v[3]):
			return true
	return false


## Is the flat point inside one of the kept-clear discs ([x, z, r] each: the yard's gate)?
static func in_no_go(p: Vector3, discs: Array) -> bool:
	for c: Variant in discs:
		var v: Array = c
		if Vector2(p.x - float(v[0]), p.z - float(v[1])).length() < float(v[2]):
			return true
	return false


## May the hull stand at `hull`? Every point of its footprint inside the driving boxes and outside the kept-clear
## discs, and (where `zones` gives the zone under each point, in footprint order) in one of the driving zones. This
## is the rule that keeps it out of the yard, off the inn and on the map; what it meets on the way (a wall, a cart, a
## player) is the tank's own check.
static func may_stand(hull: Transform3D, zones: Array, g: Dictionary) -> bool:
	var pts: PackedVector3Array = footprint(hull)
	# drive_no_go_hull [[x, z, r]]: nothing of the hull's rectangle within r (the sample points are about 3 m apart
	# along the hull, so a small drive_no_go disc fits between them; merge review 2026-11-24, Kaltenbrunn's exfil beacon)
	for d: Variant in g.get("drive_no_go_hull", []):
		var a: Array = d
		if hull_dist(hull, Vector3(float(a[0]), 0.0, float(a[1]))) < float(a[2]):
			return false
	var allowed: Array = g.get("drive_zones", [])
	for i: int in pts.size():
		if not in_boxes(pts[i], g.get("drive_boxes", [])) or in_no_go(pts[i], g.get("drive_no_go", [])):
			return false
		if not allowed.is_empty() and i < zones.size() and not allowed.has(String(zones[i])):
			return false
	return true


## May this player climb in? The tank parked and running, the hatch free, its crew not driven below; a living human
## on their feet with their hands free.
static func may_mount(drivable: bool, wreck: bool, has_driver: bool, locked: bool, alive: bool, downed: bool, is_bot: bool, carried: bool) -> bool:
	return drivable and not wreck and not has_driver and not locked and alive and not downed and not is_bot and not carried


## The dead under the tracks: at crush_min_speed or more (either way), once the last one's cooldown is over.
## {} = nothing; else {"damage_frac": share of the round's health, "slow": share of the speed it costs}.
static func crush(speed: float, cooldown_left: float, d: Dictionary) -> Dictionary:
	if absf(speed) < float(d.get("crush_min_speed", 1.0)) or cooldown_left > 0.0:
		return {}
	return {"damage_frac": float(d.get("crush_damage_frac", 1.2)), "slow": float(d.get("crush_slow", 0.3))}


## Is one of the dead at hull-frame `l` under the end of the hull that leads (the bow going forward, the stern
## backing)?
static func under_tracks(l: Vector3, speed: float, d: Dictionary) -> bool:
	var m: float = float(d.get("crush_margin_m", 0.2))
	if absf(l.x) > HULL_HALF_W + m or l.z < HULL_BOW - m or l.z > HULL_STERN + m or absf(l.y) > 1.5:
		return false
	return l.z <= 0.5 if speed > 0.0 else l.z >= -0.5


## Driven outside the assault the dead cannot wreck it: its health stops at 1 and the driver is put out (true) while
## the crew makes it good. In the assault it is the boss bar and it burns at 0.
static func driven_out(hp_after: float, in_assault: bool) -> bool:
	return not in_assault and hp_after <= 1.0


## A client driver's reported place is taken when it is no more than a drive step's worth (with slack for the
## network) from where the host has the hull; else the host's stands.
static func plausible_move(from: Vector3, to: Vector3, dt: float, d: Dictionary) -> bool:
	return flat(from, to) <= float(d.get("speed", 3.2)) * maxf(dt, 0.05) * 2.0 + float(d.get("net_slack_m", 1.5))
