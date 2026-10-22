extends Node
## Update 02 section 7 (T-052) clip: from the Carters' Yard looking north-east over the burning wreck at round 8, a
## bomber stream crosses, one is hit and goes down trailing smoke behind the hills, the crash flash, the boom ~7 s
## later and the squad's line; a flare and a barrage on the horizon meanwhile. Record silently, off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>/s7_sky.avi \
##     --fixed-fps 30 --quit-after 900 --path . res://gravelight/tools_src/clip_sky.tscn
## (Movie maker records the game's own audio track when the driver allows; the clip is encoded without audio.)

var map: Node3D
var cam: Camera3D
var amb: MapAmbience
var _t: float = 0.0
var _step: int = 0
var _flight: SkyFlight


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ProfileSave.path = "user://_clip_sky_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if map == null or not map.is_inside_tree():
		return
	_t += delta
	if _step == 0 and _t > 0.6:
		_step = 1
		var p: Player = map.get("player") as Player
		if p != null:
			p.process_mode = Node.PROCESS_MODE_DISABLED
			p.visible = false
		var hud: Node = map.get("hud") as Node
		if hud != null:
			hud.set("visible", false)
		cam = Camera3D.new()
		cam.fov = 72
		cam.far = 400.0
		map.add_child(cam)
		cam.make_current()
		cam.global_position = Vector3(30.5, 2.0, 41.0)
		cam.look_at(cam.global_position + LandscapeTerrain.dir_of(52.0) * 100.0 + Vector3(0, 27, 0))
		amb = map.get_node_or_null("MapAmbience") as MapAmbience
		RoundManager.current_round = 8
		if amb != null:
			amb.debug_set_round(8)
	elif _step == 1 and _t > 1.5 and amb != null:
		_step = 2
		_flight = amb.spawn_bombers(52.0 + 90.0, 0.0, 12)
		var c: Vector3 = cam.global_position + LandscapeTerrain.dir_of(52.0) * 240.0
		_flight.position = Vector3(c.x, cam.global_position.y + 105.0, c.z) - _flight.heading * 150.0
		_flight.start = _flight.position - _flight.heading * 200.0
		amb.spawn_flare(30.0, 120.0)
	elif _step == 2 and _t > 9.0:
		_step = 3
		if is_instance_valid(_flight) and _flight.planes.size() > 4:
			amb.plane_down_done = false
			amb._shoot_down(_flight, 4)
	elif _step == 3 and _t > 14.0:
		_step = 4
		for k: int in 4:
			amb.shell(95.0 + k * 6.0, 3.5 + k * 0.4)
