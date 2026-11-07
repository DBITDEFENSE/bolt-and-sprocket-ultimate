class_name CinemaCast
extends Node3D
## T-184: the squad as actors for a cutscene. The local player has no body of their own (a first-person camera and
## the viewmodel), and the bots' brains are paused, so a free camera used to find a floating gun and frozen
## mannequins. For the length of a cutscene every squad member (humans, bots, Jakub and the map companions) is
## played by a stand-in RemoteBody, built like their own (PersonRig, FaceDriver, their gun), standing where they
## stood; the real bodies and the viewmodel are hidden and come back in `release()`. The stand-ins do what the shot
## asks (`direct`): turn to face a point, walk a few metres (the walk cycle from their speed), idle with their
## fidgets (Wren's notebook, Peg's watch, Dutch's back, Deacon's tap). Presentation only, on every peer for itself:
## nothing here moves a Player, a collider or anything the network sends; the next map or the match never sees it.

var actors: Array[RemoteBody] = []
var _who: Array[Player] = []
var _goals: Dictionary = {}          # RemoteBody -> {"to": Vector3, "speed": float}
var _faces: Dictionary = {}          # RemoteBody -> yaw it turns to
var _hidden: Array[Node3D] = []
var _view: Node3D = null
## Where a shot can aim at the group (`target: "@squad"`): their centre at chest height, kept up to date.
var centre_node: Node3D = null


## Casts everyone in the players group who stands (alive, not spectating) under `parent`. `max_n` caps the cast.
static func gather(parent: Node, max_n: int = 6) -> CinemaCast:
	var c: CinemaCast = CinemaCast.new()
	c.name = "CinemaCast"
	parent.add_child(c)
	c._cast(max_n)
	return c


func _cast(max_n: int) -> void:
	centre_node = Node3D.new()
	centre_node.name = "SquadCentre"
	add_child(centre_node)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_inside_tree() or not p.visible or not p.is_alive() or bool(p.get("spectating")):
			continue
		if actors.size() >= max_n:
			break
		var b: RemoteBody = RemoteBody.new()
		b.name = "StandIn_%d" % p.player_id
		add_child(b)
		b.setup(p.character_id if p.character_id != &"" else GameState.character_of(p.player_id), p.player_id)
		var w: WeaponInstance = p.weapons.current() if p.weapons != null else null
		if w != null:
			b.set_weapon(w.id)
		b.set("calm", true)
		var tag: Node3D = b.get("_tag") as Node3D
		if tag != null:
			tag.visible = false
		b.global_position = p.global_position
		b.rotation.y = p.global_rotation.y
		actors.append(b)
		_who.append(p)
		if p.remote_body != null:
			p.remote_body.cinema_hidden = true
			p.remote_body.visible = false
			_hidden.append(p.remote_body)
		if p.is_local and not p.is_bot and p.weapons != null and p.weapons.visible:
			p.weapons.visible = false
			_view = p.weapons
	_place_centre()


## The stand-in for a player id (null when not cast).
func actor_of(pid: int) -> RemoteBody:
	for i: int in _who.size():
		if is_instance_valid(_who[i]) and _who[i].player_id == pid:
			return actors[i]
	return null


## The squad's centre (where a shot can look), or `fallback` with nobody cast.
func centre(fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if actors.is_empty():
		return fallback
	var c: Vector3 = Vector3.ZERO
	for a: RemoteBody in actors:
		c += a.global_position
	return c / float(actors.size())


## A shot's direction for the cast: {"place": [x, y, z]} first stands the group there (a loose wedge facing `face`,
## hidden by the cut); {"face": [x, y, z]} turns everyone toward a point; {"walk": [dx, dy, dz], "speed": m/s} walks
## everyone that far (each keeps their place in the group); {"walk_to": [x, y, z]} walks the group's centre there.
func direct(d: Dictionary) -> void:
	if d.is_empty():
		return
	var face: Variant = d.get("face", null)
	if d.has("place"):
		var at: Vector3 = CinemaShot.v3(d["place"])
		var fwd: Vector3 = (CinemaShot.v3(face) - at) if face != null else Vector3.FORWARD
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var spots: Array[Vector3] = wedge(at, fwd, actors.size(), float(d.get("spread", 1.1)))
		for j: int in actors.size():
			actors[j].global_position = spots[j]
			actors[j].rotation.y = atan2(-fwd.x, -fwd.z)
			_faces.erase(actors[j])
			_goals.erase(actors[j])
	var spd: float = float(d.get("speed", 1.35))
	var off: Vector3 = Vector3.ZERO
	if d.has("walk"):
		off = CinemaShot.v3(d["walk"])
	elif d.has("walk_to"):
		off = CinemaShot.v3(d["walk_to"]) - centre()
	off.y = 0.0
	var i: int = 0
	for a: RemoteBody in actors:
		if face != null:
			var fp: Vector3 = CinemaShot.v3(face)
			var to: Vector3 = fp - a.global_position
			if Vector2(to.x, to.z).length() > 0.05:
				_faces[a] = atan2(-to.x, -to.z)
		if off.length() > 0.05:
			# a loose file: the ones at the back start a beat later and walk a touch slower
			_goals[a] = {"to": a.global_position + off, "speed": spd * (1.0 - 0.06 * float(i % 3)), "wait": 0.25 * float(i)}
		i += 1


func _place_centre() -> void:
	if centre_node != null and not actors.is_empty():
		centre_node.global_position = centre() + Vector3.UP * 1.35


## A loose wedge of `n` spots round `at` facing `fwd`: the first in front, the rest staggered behind to either side.
## Pure.
static func wedge(at: Vector3, fwd: Vector3, n: int, spread: float) -> Array[Vector3]:
	var side: Vector3 = fwd.cross(Vector3.UP)
	var out: Array[Vector3] = []
	for j: int in n:
		var row: int = (j + 1) / 2
		var sgn: float = 1.0 if j % 2 == 1 else -1.0
		var lateral: float = 0.0 if j == 0 else sgn * spread * (0.7 + 0.25 * float(row))
		out.append(at - fwd * (0.9 * float(row)) + side * lateral)
	return out


func _process(delta: float) -> void:
	_place_centre()
	for a: RemoteBody in actors:
		if not is_instance_valid(a):
			continue
		var speed: float = 0.0
		if _goals.has(a):
			var g: Dictionary = _goals[a]
			g["wait"] = float(g.get("wait", 0.0)) - delta
			if float(g["wait"]) <= 0.0:
				var to: Vector3 = (g["to"] as Vector3) - a.global_position
				to.y = 0.0
				var step: float = float(g["speed"]) * delta
				if to.length() <= step:
					a.global_position += to
					_goals.erase(a)
				else:
					a.global_position += to.normalized() * step
					speed = float(g["speed"])
					_faces[a] = atan2(-to.x, -to.z)
		if _faces.has(a):
			a.rotation.y = lerp_angle(a.rotation.y, float(_faces[a]), clampf(delta * 4.0, 0.0, 1.0))
		a.update_pose(delta, speed, 0.0, 0)


## The cutscene is over: the stand-ins go, the real bodies and the viewmodel come back.
func release() -> void:
	_unhide()
	_hidden.clear()
	if _view != null and is_instance_valid(_view):
		_view.visible = true
	_view = null
	for a: RemoteBody in actors:
		if is_instance_valid(a):
			a.queue_free()
	actors.clear()
	_who.clear()
	queue_free()


func _unhide() -> void:
	for h: Node3D in _hidden:
		if is_instance_valid(h):
			(h as RemoteBody).cinema_hidden = false
			h.visible = true


func _exit_tree() -> void:
	_unhide()
	if _view != null and is_instance_valid(_view):
		_view.visible = true
