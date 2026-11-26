extends "res://gravelight/tools_src/shots_zombie_look.gd"
## T-284 (the owner: "MAKE THE ZOMBIES MORE TERRIFYING"): the scare in pictures, Map 0 at its own night. Built on T-269's
## shot tool (the map, the camera, the crowd placing). Every scene is taken with Zombie.t284_terror off, then on:
##   faces_off / faces_on     three walkers close up in the yard: the eyes, the rot, the wet
##   taproom_off / taproom_on twelve at gameplay distance in the dark taproom (do the eyes read from across a room?)
##   sight_00..07             one walker's first sight: the head snap and the arm jerk, a frame every ~0.1 s
##   horde_off / horde_on     sixteen round the player: the horde moment's fog and lamp flicker
##   tools/wsl_zombie_terror.sh <tag>      (frames in docs/captures/t284/<tag>/; a clip of the run beside them)
## Rendered runs only under WSL + Xvfb (never a window on the owner's PC).


func _run() -> void:
	await _skip(14.0)
	RoundManager.stop()
	_map.director.kill_all(true)
	_cam = Camera3D.new()
	_map.add_child(_cam)
	var p: Player = _map.player
	if _wants("faces"):
		await _faces()
	if _wants("taproom"):
		await _taproom()
	if _wants("sight"):
		await _sight()
	if _wants("horde"):
		await _horde(p)
	print("[zlook] %d pictures in %s" % [_saved, _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()


func _set_terror(zs: Array[Zombie], on: bool) -> void:
	Zombie.t284_terror = on
	for z: Zombie in zs:
		z._apply_look()
	await _frames(2)


func _faces() -> void:
	var c: Vector3 = Vector3(12.0, 0.0, -14.0)
	var cam: Vector3 = Vector3(9.6, 1.62, -14.0)
	var spots: Array = [c + Vector3(0, 0, -0.75), c + Vector3(0.5, 0, 0.0), c + Vector3(0, 0, 0.75)]
	var zs: Array[Zombie] = await _stand(spots, cam)
	for z: Zombie in zs:   # (their senses are off while placed: the heads look at the camera by hand)
		var lt: Node3D = z.get("_look_target") as Node3D
		var la: LookAtModifier3D = z.get("_look") as LookAtModifier3D
		if lt != null and la != null:
			lt.global_position = cam
			la.active = true
	await _frames(8)
	_look(cam, c + Vector3(0, 1.55, 0), 34.0)
	await _set_terror(zs, false)
	await _shot("faces_off")
	await _set_terror(zs, true)
	await _shot("faces_on")
	await _clear()


func _taproom() -> void:
	var c: Vector3 = Vector3(20.6, 0.0, 7.0)
	var cam: Vector3 = Vector3(13.6, 1.65, 7.0)
	var zs: Array[Zombie] = await _stand(_crowd_spots(c, cam, 12), cam)
	_look(cam, c + Vector3(0, 1.3, 0), 58.0)
	await _set_terror(zs, false)
	await _shot("taproom_off")
	await _set_terror(zs, true)
	await _shot("taproom_on")
	await _clear()


## One walker 3 m from the camera, its physics on so the springs and the look-at work, its target the player at the
## camera: the first sight played by hand at a known moment, then a frame every few drawn frames.
func _sight() -> void:
	var c: Vector3 = Vector3(12.0, 0.0, -14.0)
	var cam: Vector3 = Vector3(8.6, 1.62, -13.2)
	var zs: Array[Zombie] = await _stand([c], cam + Vector3(0, 0, -2.5))
	if zs.is_empty():
		return
	var z: Zombie = zs[0]
	await _set_terror(zs, true)
	z._terror_seen = true   # (played by hand below, at a known frame)
	var p: Player = _map.player
	if p != null:
		p.global_position = Vector3(cam.x, 0.2, cam.z)
		z.target = p
	_look(cam, c + Vector3(0, 1.4, 0), 40.0)
	z.set_physics_process(true)   # (its senses: the look-at follows the target)
	z._enter(Zombie.State.CHASE)
	await _frames(6)
	await _shot("sight_00")
	z._first_sight(ZombieTerror.sec("first_sight"))
	for i: int in range(1, 8):
		await _shot("sight_%02d" % i)
	await _clear()


func _horde(p: Player) -> void:
	if p == null:
		return
	var at: Vector3 = Vector3(12.0, 0.0, -14.0)
	p.global_position = at + Vector3(0, 0.2, 0)
	var cam: Vector3 = at + Vector3(-1.2, 1.62, 3.5)
	var spots: Array = []
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0
		spots.append(at + Vector3(sin(a), 0, cos(a)) * (3.0 + 2.5 * float(i % 3) / 2.0))
	var zs: Array[Zombie] = await _stand(spots, at)
	_look(cam, at + Vector3(0, 1.2, -4.0), 62.0)
	Zombie.t284_terror = false
	await _skip(1.0)
	await _shot("horde_off")
	Zombie.t284_terror = true
	for z: Zombie in zs:
		z._apply_look()
	# the director's ZombieTerror counts every 0.25 s: let it see the crowd and ease the fog in
	await _secs(3.0)
	await _shot("horde_on")
	var t: ZombieTerror = _map.director.get("terror") as ZombieTerror
	print("[zlook] horde: in a horde moment %s, near %d, moments %d" % [str(t.in_horde() if t != null else false), t.near_count if t != null else -1, ZombieTerror.horde_moments])
	await _clear()
