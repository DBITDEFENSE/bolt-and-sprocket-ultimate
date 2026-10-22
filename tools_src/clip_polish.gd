extends Node
## Dev tool: a short clip of Map 0's reactive dressing (Update 02 section 8, T-053): bottles on the bar's back shelf
## shot one after another, a lantern knocked swinging, the curtains in a gust, bullet holes staying in the wall,
## footprints left across the snow outside, and a guest-room door swinging as someone comes through. A free camera;
## the HUD off; shots are the real shot ray (WeaponHolder's mask) handed to DecorHit, with a tracer. Record with the
## movie maker, off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>/polish.avi --fixed-fps 30 --quit-after 900 --path . res://tools_src/clip_polish.tscn
var map: Node3D
var cam: Camera3D
var player: Player


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ProfileSave.path = "user://_clip_polish_profile.json"
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shoot(from: Vector3, to: Vector3) -> void:
	var dir: Vector3 = (to - from).normalized()
	var exclude: Array[RID] = []
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	for i: int in 6:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, WeaponHolder.MASK_SHOT, exclude)
		q.collide_with_areas = true
		var res: Dictionary = space.intersect_ray(q)
		if res.is_empty():
			return
		var col: Object = res["collider"]
		if DecorHit.is_decor(col):
			DecorHit.hit(col, res["position"], dir)
			exclude.append((col as CollisionObject3D).get_rid())
			continue
		Effects.tracer(from, res["position"])
		Effects.impact(res["position"], res["normal"], GunFx.surface_of(col, res["position"], res["normal"], space), col)
		return


func _run() -> void:
	await _wait(1.5)
	player = map.get("player") as Player
	player.set_physics_process(false)
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(n.name) != "PostFx":
			(n as CanvasLayer).visible = false
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		(d as BuyDoor).open(1)
	cam = Camera3D.new()
	cam.fov = 70
	map.add_child(cam)
	cam.make_current()
	# 1. the bar's back shelf: bottles shot one by one along the 1 m board
	cam.global_position = Vector3(8.6, 1.55, 5.3)
	cam.look_at(Vector3(4.8, 1.2, 5.3))
	await _wait(1.2)
	var bar: ShatterSet = map.get_node("Reactive/Glass_Bar") as ShatterSet
	var muzzle: Vector3 = Vector3(8.4, 1.45, 5.6)
	for i: int in range(22, 40, 2):
		var it: Array = bar.items[i]
		_shoot(muzzle, bar.to_global(it[0]) + Vector3(0, 0.12, 0))
		await _wait(0.35)
	await _wait(0.8)
	# 2. a lantern knocked swinging
	cam.global_position = Vector3(10.0, 1.5, 7.0)
	cam.look_at(Vector3(14.0, 2.6, 8.0))
	await _wait(0.6)
	_shoot(Vector3(10.2, 1.5, 7.2), Vector3(14.0, 2.6, 8.0))
	await _wait(3.0)
	# 3. the north windows' curtains in a gust; then holes stitched into the wall beside the window
	cam.global_position = Vector3(17.0, 1.6, 4.0)
	cam.look_at(Vector3(17.0, 1.5, 0.0))
	var amb: Node = map.get_node_or_null("MapAmbience")
	if amb != null and amb.has_method("_start_gust"):
		amb.call("_start_gust")
	await _wait(2.0)
	for k: int in 8:
		_shoot(Vector3(17.6, 1.5, 3.6), Vector3(18.6 + k * 0.12, 1.3 + sin(k) * 0.2, 0.15))
		await _wait(0.12)
	await _wait(2.0)
	# 4. footprints across the snow in front of the inn
	cam.global_position = Vector3(-4.0, 4.0, -12.0)
	cam.look_at(Vector3(-8.0, 0.0, -6.0))
	var a: Vector3 = Vector3(-12.0, 0.05, -4.0)
	var b: Vector3 = Vector3(-4.0, 0.05, -10.0)
	var t: float = 0.0
	while t < 5.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		player.velocity = (b - a) / 5.0
		player.global_position = a.lerp(b, t / 5.0)
	await _wait(1.0)
	# 5. a guest-room door swinging as someone comes through
	cam.global_position = Vector3(14.0, 5.4, 8.8)
	cam.look_at(Vector3(11.6, 4.8, 5.5))
	await _wait(1.0)
	a = Vector3(11.75, 3.85, 9.0)
	b = Vector3(11.75, 3.85, 3.5)
	t = 0.0
	while t < 2.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		player.velocity = (b - a) / 2.5
		player.global_position = a.lerp(b, t / 2.5)
	player.global_position = Vector3(11.75, 3.85, 2.0)
	await _wait(4.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_clip_polish_profile.json"))
	get_tree().quit()
