class_name LadderClimb
extends Interactable
## A ladder you can climb (T-229, the owner: "make sure ladders work on all maps"). Holding Use at the foot carries the
## player up the ladder line to `to_pos`; a second LadderClimb at the head, with `down` set, carries them back. `zone`:
## when set, the ladder waits for that zone to open (the trapdoor behind the Inn's bar waits for the Old Cellar's door).
## Zombies take the same ladders by their climb links (the map json's climb_links, ClimbLink); bots cannot (their mask
## leaves the climb layers out, T-153), so a ladder is never a route a bot must take.
## T-230 (the owner: "ladder needs animation"): the climb is animated. The body steps onto the ladder's line and turns
## to face the rungs (`face_deg`), the gun goes away and both hands come up onto the rungs; it then goes up (or down)
## rung by rung: the motion pulses with each pull, the view bobs and rolls toward the pulling hand, the hands alternate
## (hold a rung as it slides past the eye, let go, reach for the next), a rung sound per rung; at the top it swings over
## the edge onto `to_pos` and the gun comes back up. The player keeps the mouse within YAW_FREE of the ladder.
## The Player is "carried" meanwhile (Player.begin_carry): no movement, fire, ADS or other interaction.
## Data-driven per map: data/gravelight/<map>.json "ladders": [{"name": "...", "pos": [x, y, z] (where the player
## stands, at the foot or at the head), "yaw": degrees (local -Z toward the player), "to": [x, y, z] (where the climb
## ends), "down": false, "zone": "OLD_CELLAR", "target": "the trapdoor", "climb_s": 2.0 (optional, else PACE),
## "line": [x, z] (the body's line on the ladder, 0.4 m off the rungs; default pos), "face": degrees (the yaw the
## climber faces; default yaw + 180), "surface": "wood" | "metal", "locked_text": "The hatch is bolted from above"}].
## MapRoot spawns them with the climb links.

const PACE: float = 1.4            # m/s up the rungs when climb_s is not given
const RUNG: float = 0.3            # the rungs' spacing (Props.ladder)
const MOUNT_S: float = 0.45        # onto the line, the hands up
const DISMOUNT_S: float = 0.5      # over the edge at the top (off the foot at the bottom)
const YAW_FREE: float = 1.25       # radians either side of the ladder the climber may look
const PULSE: float = 0.7           # how much the climb slows at each rung (0 = even, 1 = a stop per rung)
# the hands in viewmodel space (rig space, like the hip pose): a fist round a rung across the view, the palm away
const HAND_R_BASIS: Basis = Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
const HAND_L_BASIS: Basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
const HANDS_DOWN_R: Vector3 = Vector3(0.2, -0.3, -0.26)
const HANDS_DOWN_L: Vector3 = Vector3(-0.2, -0.32, -0.26)
const RUNG_OFF: float = 0.4        # the rungs this far ahead of the body's line (Props.ladder's rails are 0.42 off)
const HAND_X: float = 0.2          # the hands this far either side of the ladder's centre (the rails)
const EYE: float = 1.62            # the eye over the feet
const GRAB_Y: float = 0.17         # a hand takes the rung nearest this high over the eye...
const LET_GO_Y: float = -0.2       # ...and lets go once it has slid down to here (mirrored climbing down)
const REACH_S: float = 0.22        # a hand's move from one rung to the next

@export var down: bool = false
@export var to_pos: Vector3 = Vector3.ZERO      # where the climb ends (world)
@export var climb_s: float = -1.0               # seconds on the rungs; <= 0: from the height at PACE (0.8 s at least)
@export var zone: StringName = &""              # usable only once this zone is open ("" = always)
@export var target: String = "the ladder"       # "Hold [E] to climb up <target>"
@export var locked_text: String = "Locked"
@export var line: Vector2 = Vector2(INF, INF)   # the body's x, z on the ladder (default: this node's)
@export var face_deg: float = INF               # world yaw the climber faces on the rungs (default: this node's yaw + 180)
@export var surface: String = "wood"            # "wood" / "metal": the rung sounds
@export var rung0: float = INF                  # world y of the lowest rung (default: the foot's y + 0.15, Props.ladder)

var climbs: int = 0                             # the smokes count these
var _busy: Dictionary = {}                      # player id -> the climb's state (see climb)


func _ready() -> void:
	interact_size = Vector3(1.2, 2.0, 1.0)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"ladders")
	set_physics_process(false)


func get_prompt(_player: Player) -> String:
	if not _open():
		return locked_text
	return "Hold [%s] to climb %s %s" % [prompt_key(&"interact"), "down" if down else "up", target]


func can_interact(player: Player) -> bool:
	return _open() and player != null and player.is_alive() and not bool(player.get("downed")) and not _busy.has(player.player_id) and player.carry == null


func hold_time(_player: Player) -> float:
	return 0.4


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	climb(player)


## The climb moves the user's own body: it runs on their machine (co-op), like the other movement.
func net_local() -> bool:
	return true


func _open() -> bool:
	return zone == &"" or GameState.is_zone_open(zone)


## The body's x, z while on the rungs.
func line_pos() -> Vector2:
	return line if line.is_finite() else Vector2(global_position.x, global_position.z)


## The yaw the climber faces on the rungs (world).
func face_yaw() -> float:
	return deg_to_rad(face_deg) if is_finite(face_deg) else global_rotation.y + PI


## The lowest rung's world y.
func rung_base() -> float:
	return rung0 if is_finite(rung0) else minf(global_position.y, to_pos.y) + 0.15


## The rung nearest world y.
func rung_near(y: float) -> float:
	return rung_base() + roundf((y - rung_base()) / RUNG) * RUNG


## The direction the climber faces and their right, on the rungs.
func face_dir() -> Vector3:
	var f: float = face_yaw()
	return Vector3(-sin(f), 0.0, -cos(f))


## Where a hand grips: on the rung at world y, `side` +1 right / -1 left of the ladder's centre.
func grip_world(y: float, side: float) -> Vector3:
	var l2: Vector2 = line_pos()
	var fd: Vector3 = face_dir()
	return Vector3(l2.x, y, l2.y) + fd * RUNG_OFF + fd.cross(Vector3.UP) * (side * HAND_X)


## Seconds on the rungs for a climb from `from_y`.
func climb_seconds(from_y: float) -> float:
	if climb_s > 0.0:
		return climb_s
	return maxf(0.8, absf(to_pos.y - from_y) / PACE)


## The whole climb for a start at `from_y`: onto the ladder, the rungs, off at the end.
func ride_seconds(from_y: float) -> float:
	return MOUNT_S + climb_seconds(from_y) + DISMOUNT_S


## True while `player` is on this ladder.
func is_climbing(player: Player) -> bool:
	return player != null and _busy.has(player.player_id)


## Starts the climb: the Player is carried (begin_carry) and this node moves them every physics frame (_tick).
func climb(player: Player) -> void:
	climbs += 1
	var from: Vector3 = player.global_position
	var eye: float = from.y + EYE
	var r0: float = rung_near(eye + 0.1)
	_busy[player.player_id] = {
		"p": player, "t": 0.0, "from": from, "climb": climb_seconds(from.y),
		"rungs": maxi(1, roundi(absf(to_pos.y - from.y) / RUNG)), "yaw0": player.rotation.y,
		"pitch_k": -0.26 if down else 0.14, "gun": false,
		"held": [r0, r0 - RUNG], "prev": [r0, r0 - RUNG], "reach": [1.0, 1.0]}   # right hand a rung above the left
	player.begin_carry(self)
	if player.weapons != null:
		player.weapons.set_hands(&"climb")
		player.weapons.hands_shoulder = 0.1
	set_physics_process(true)
	AudioDirector.play_3d(_rung_sound(), from + Vector3.UP * 0.5, -4.0)


func _rung_sound() -> String:
	return "footstep_metal" if surface == "metal" else "footstep_wood"


func _physics_process(delta: float) -> void:
	for pid: Variant in _busy.keys():
		_tick(pid, _busy[pid], delta)
	if _busy.is_empty():
		set_physics_process(false)


## The hands on the real rungs: each holds its rung while the body moves past it, lets go once the rung has slid to
## LET_GO_Y under the eye (climbing down: once it has risen to GRAB_Y over it) and reaches for the rung nearest the
## other end of that range, over REACH_S (a rung sound as it lands). Returns [right, left] grip points (world).
func _tick_hands(st: Dictionary, eye: float, delta: float) -> Array:
	var out: Array = []
	for h: int in 2:
		var side: float = 1.0 if h == 0 else -1.0
		var held: Array = st["held"]
		var prev: Array = st["prev"]
		var reach: Array = st["reach"]
		var d: float = float(held[h]) - eye
		if float(reach[h]) >= 1.0 and ((not down and d < LET_GO_Y) or (down and d > GRAB_Y)):
			prev[h] = held[h]
			held[h] = rung_near(eye + (GRAB_Y if not down else LET_GO_Y))
			reach[h] = 0.0
		if float(reach[h]) < 1.0:
			reach[h] = minf(1.0, float(reach[h]) + delta / REACH_S)
			if float(reach[h]) >= 1.0:
				AudioDirector.play_3d(_rung_sound(), grip_world(float(held[h]), side), -10.0)
		var w: float = smoothstep(0.0, 1.0, float(reach[h]))
		var g: Vector3 = grip_world(lerpf(float(prev[h]), float(held[h]), w), side)
		g -= face_dir() * (0.06 * sin(w * PI))   # the hand comes off the ladder a little on its way
		out.append(g)
	return out


func _tick(pid: Variant, st: Dictionary, delta: float) -> void:
	var p: Player = st["p"] as Player
	if p == null or not is_instance_valid(p) or not p.is_alive() or p.carry != self:
		if p != null and is_instance_valid(p) and p.carry == self:
			p.end_carry(self)   # downed on the rungs: the body is left where it is, physics takes it
		_busy.erase(pid)
		return
	st["t"] = float(st["t"]) + delta
	var t: float = st["t"]
	var l2: Vector2 = line_pos()
	var from: Vector3 = st["from"]
	var y0: float = from.y
	var dy: float = to_pos.y - y0
	var t1: float = MOUNT_S
	var t2: float = t1 + float(st["climb"])
	var t3: float = t2 + DISMOUNT_S
	var face: float = face_yaw()
	var pos: Vector3
	var head: Vector3 = Vector3.ZERO
	var roll: float = 0.0
	var pitch: float = 0.0
	var pk: float = st["pitch_k"]
	var hr: Vector3 = HANDS_DOWN_R
	var hl: Vector3 = HANDS_DOWN_L
	var grips: Array = [grip_world(float((st["held"] as Array)[0]), 1.0), grip_world(float((st["held"] as Array)[1]), -1.0)]
	if t < t1:
		# onto the line (a down climb steps out over the edge, the rail or the hatch's rim), turning to the rungs
		var a: float = smoothstep(0.0, 1.0, t / t1)
		pos = from.lerp(Vector3(l2.x, y0, l2.y), a)
		if down:
			pos.y += 0.45 * sin(a * PI)
		p.rotation.y = lerp_angle(float(st["yaw0"]), face, a)
		pitch = pk * a
		head.y = -0.03 * sin(a * PI)
		p.global_position = pos   # (the hands are aimed from where the eye is now)
		if p.weapons != null:
			hr = HANDS_DOWN_R.lerp(p.weapons.vm_target(grips[0]), a)
			hl = HANDS_DOWN_L.lerp(p.weapons.vm_target(grips[1]), a)
	elif t < t2:
		# the rungs: the body rises in pulls (slow at each rung, quick between), the view bobs and rolls toward the
		# pulling hand, the hands alternate; a rung sound per rung
		var k: float = (t - t1) / float(st["climb"])
		var n: int = st["rungs"]
		var s: float = k - PULSE * sin(TAU * n * k) / (TAU * n)
		pos = Vector3(l2.x, y0 + dy * s, l2.y)
		var ph: float = n * k
		head.y = 0.03 * sin(TAU * ph)
		head.x = 0.02 * sin(PI * ph)
		roll = deg_to_rad(1.4) * sin(PI * ph)
		pitch = pk
		var d: float = wrapf(p.rotation.y - face, -PI, PI)
		if absf(d) > YAW_FREE:
			p.rotation.y = face + clampf(d, -YAW_FREE, YAW_FREE)
		p.global_position = pos
		grips = _tick_hands(st, pos.y + EYE, delta)
		if p.weapons != null:
			hr = p.weapons.vm_target(grips[0])
			hl = p.weapons.vm_target(grips[1])
	elif t < t3:
		# off: up and over the edge onto to_pos (an up climb), a step back off the foot (a down climb); the gun rises
		var c: float = smoothstep(0.0, 1.0, (t - t2) / DISMOUNT_S)
		pos = Vector3(l2.x, to_pos.y, l2.y).lerp(to_pos, c)
		if not down:
			pos.y += 0.3 * sin(c * PI)
		pitch = pk * (1.0 - c)
		head.y = -0.05 * sin(c * PI)
		p.global_position = pos
		if p.weapons != null:
			hr = p.weapons.vm_target(grips[0]).lerp(HANDS_DOWN_R, c)
			hl = p.weapons.vm_target(grips[1]).lerp(HANDS_DOWN_L, c)
		if c > 0.5 and not bool(st["gun"]) and p.weapons != null:
			st["gun"] = true
			p.weapons.set_hands(&"")
	else:
		p.global_position = to_pos
		p.velocity = Vector3.ZERO
		p.end_carry(self)
		p.land_dip(2.2 if down else 1.6)
		_busy.erase(pid)
		return
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.carry_head = head
	p.carry_roll = roll
	p.carry_pitch = pitch
	if p.weapons != null:
		p.weapons.hand_r = Transform3D(HAND_R_BASIS, hr)
		p.weapons.hand_l = Transform3D(HAND_L_BASIS, hl)


## Spawns every ladder the map's json lists under `root` (a "Ladders" holder). Returns them.
static func spawn_all(root: Node3D, map_id: StringName) -> Array[LadderClimb]:
	var out: Array[LadderClimb] = []
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return out
	var rows: Array = GLData.load_json(path).get("ladders", [])
	if rows.is_empty():
		return out
	var holder: Node3D = Node3D.new()
	holder.name = "Ladders"
	root.add_child(holder)
	var i: int = 0
	for row: Dictionary in rows:
		var l: LadderClimb = LadderClimb.new()
		l.name = str(row.get("name", "Ladder_%d" % i))
		l.down = bool(row.get("down", false))
		l.to_pos = ClimbLink._v3(row.get("to", [0, 0, 0]))
		l.climb_s = float(row.get("climb_s", -1.0))
		l.zone = StringName(str(row.get("zone", "")))
		l.target = str(row.get("target", "the ladder"))
		l.locked_text = str(row.get("locked_text", "Locked"))
		l.surface = str(row.get("surface", "wood"))
		if row.has("rung0"):
			l.rung0 = float(row["rung0"])
		if row.has("line"):
			var ln: Array = row["line"]
			l.line = Vector2(float(ln[0]), float(ln[1]))
		if row.has("face"):
			l.face_deg = float(row["face"])
		l.position = ClimbLink._v3(row.get("pos", [0, 0, 0]))
		l.rotation.y = deg_to_rad(float(row.get("yaw", 0.0)))
		holder.add_child(l)
		out.append(l)
		i += 1
	return out
