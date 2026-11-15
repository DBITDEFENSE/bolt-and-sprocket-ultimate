extends Node
## Dev tool (T-254, UPDATE 19): the Requisition Crate and the Crucible in their maps, the same cameras before and after.
## Renders through WSL + Xvfb only (never a window on the owner's PC):
##   tools/wsl_godot.sh --path . res://gravelight/tools_src/shots_u19_box.tscn -- --label=after [--only=map00,map01] [--what=crate,crucible]
## -> docs/captures/u19_box_crucible/<label>/<map>_<shot>.png
## Crucible (every map in --only): unpowered (where it needs the lever), powered idle, mid-forge, the offer, each from
## a front and a wide camera placed in the machine's own frame (pulled in when a wall is in the way).
## Crate (map00): the Hearth spot idle, mid-roll, the offer, empty; the Well spot (outdoors) idle; the locator from
## across the yard and from outside the inn; Herr Tamtam's exit and the arrival at the next spot.

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}

var _out: String = ""
var _label: String = "after"
var _only: PackedStringArray = ["map00", "map01", "map02"]
var _what: PackedStringArray = ["crate", "crucible"]
var _cam: Camera3D
var _map: MapRoot


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			_label = a.substr(8)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a.begins_with("--what="):
			_what = a.substr(7).split(",", false)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("docs/captures/u19_box_crucible").path_join(_label)
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_capture_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(shot_name + ".png")
	img.save_png(path)
	print("[shots_u19] ", path)


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	for key: String in _only:
		if not MAPS.has(key):
			continue
		Campaign.reset()
		_map = (load(MAPS[key]) as PackedScene).instantiate() as MapRoot
		get_tree().root.add_child(_map)
		get_tree().current_scene = _map
		GameState.god_mode = true
		await _secs(6.0)
		RoundManager.stop()
		if _map.director != null:
			_map.director.kill_all(true)
		for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if not (cl is LookPost):
				(cl as CanvasLayer).visible = false
		_cam = Camera3D.new()
		_cam.name = "ShotCamera"
		_cam.far = 1500.0
		_map.add_child(_cam)
		_cam.current = true
		if _map.player != null:
			_map.player.set_process_unhandled_input(false)
		if _what.has("crucible"):
			await _crucible(key)
		if _what.has("crate") and key == "map00":
			await _crate(key)
		_map.queue_free()
		_map = null
		await _secs(1.5)
	get_tree().quit()


## The camera at `eye` (pulled toward `target` when something solid is between them), the player parked at `feet`
## (the view cells follow the player) and hidden.
func _aim(eye: Vector3, target: Vector3, feet: Vector3, fov: float = 64.0) -> void:
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target, eye, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		eye = (hit["position"] as Vector3).lerp(target, 0.08)
	_cam.fov = fov
	_cam.global_position = eye
	_cam.look_at(target, Vector3.UP)
	if _map.player != null:
		_map.player.global_position = feet
		_map.player.velocity = Vector3.ZERO
		_map.player.visible = false
		_map.player.set_physics_process(false)


func _crucible(key: String) -> void:
	var cr: Crucible = null
	for n: Node in get_tree().get_nodes_in_group(&"crucible"):
		if n is Crucible and _map.is_ancestor_of(n):
			cr = n as Crucible
	if cr == null:
		print("[shots_u19] %s has no Crucible" % key)
		return
	var xf: Transform3D = cr.global_transform
	var feet: Vector3 = xf * Vector3(0.0, 0.05, -2.4)
	var views: Array = [
		["front", xf * Vector3(1.7, 1.65, -4.4), xf * Vector3(0.0, 1.45, 0.2), 64.0],
		["wide", xf * Vector3(-3.0, 1.75, -5.4), xf * Vector3(0.0, 1.9, 0.4), 78.0],
	]
	if cr.needs_power:
		GameState.power_on = false
		cr.call("_refresh_power")
		for v: Array in views:
			_aim(v[1], v[2], feet, v[3])
			await _secs(1.5)
			await _shot("%s_crucible_off_%s" % [key, v[0]])
	GameState.power_on = true
	GLBus.power_activated.emit()
	for v2: Array in views:
		_aim(v2[1], v2[2], feet, v2[3])
		await _secs(1.5)
		await _shot("%s_crucible_idle_%s" % [key, v2[0]])
	_aim(views[0][1], views[0][2], feet, views[0][3])
	cr.call("_forge", 1, "kar98k_up")
	await _secs(0.3)
	await _shot("%s_crucible_feed_front" % key)
	await _secs(3.2)
	await _shot("%s_crucible_forge_front" % key)
	var t: float = 0.0
	while cr.phase != Crucible.Phase.OFFERED and t < 6.0:
		await _secs(0.1)
		t += 0.1
	await _secs(0.25)
	await _shot("%s_crucible_out_front" % key)
	await _secs(1.2)
	await _shot("%s_crucible_offer_front" % key)
	_aim(views[1][1], views[1][2], feet, views[1][3])
	await _secs(0.4)
	await _shot("%s_crucible_offer_wide" % key)
	cr.call("_reset")
	await _secs(0.5)


func _spot(index: int) -> MysteryCrate:
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		if (n as MysteryCrate).spot_index == index and _map.is_ancestor_of(n):
			return n as MysteryCrate
	return null


func _go(index: int) -> void:
	CrateManager.location_index = index
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		(n as MysteryCrate).refresh()


func _crate(key: String) -> void:
	var hearth: MysteryCrate = _spot(0)
	var well: MysteryCrate = _spot(3)
	if hearth == null:
		return
	var xf: Transform3D = hearth.global_transform
	var eye: Vector3 = xf * Vector3(1.25, 1.45, -2.7)
	var tgt: Vector3 = xf * Vector3(0.0, 0.62, 0.0)
	var feet: Vector3 = xf * Vector3(0.0, 0.05, -2.2)
	_go(0)
	_aim(eye, tgt, feet)
	await _secs(1.5)
	await _shot("%s_crate_idle" % key)
	_aim(xf * Vector3(-0.5, 1.2, -1.5), xf * Vector3(0.05, 0.45, 0.0), feet, 58.0)
	await _secs(0.6)
	await _shot("%s_crate_idle_close" % key)
	_aim(eye, tgt + Vector3(0, 0.3, 0), feet)
	hearth.call("_net_open", 1, "ppsh41")
	await _secs(0.35)
	await _shot("%s_crate_open" % key)
	await _secs(2.0)
	await _shot("%s_crate_roll" % key)
	var t: float = 0.0
	while hearth.phase != MysteryCrate.Phase.OFFERED and t < 6.0:
		await _secs(0.05)
		t += 0.05
	await _secs(0.12)
	await _shot("%s_crate_settle" % key)
	await _secs(1.3)
	await _shot("%s_crate_offer" % key)
	hearth.call("_close")
	await _secs(1.2)
	# Herr Tamtam: the exit at the Hearth, the arrival at the next spot
	hearth.call("_net_open", 1, String(CrateManager.DRUMMER))
	await _secs(1.4)
	await _shot("%s_crate_drummer" % key)
	await _secs(1.2)
	await _shot("%s_crate_sinking" % key)
	await _secs(1.7)
	_go(3)
	GLBus.crate_moved.emit(3)
	await _secs(1.0)
	_aim(eye, tgt, feet)
	await _secs(0.5)
	await _shot("%s_crate_empty" % key)
	_aim(xf * Vector3(-0.5, 1.2, -1.5), xf * Vector3(0.05, 0.45, 0.0), feet, 58.0)
	await _secs(0.5)
	await _shot("%s_crate_empty_close" % key)
	if well != null:
		var wx: Transform3D = well.global_transform
		_aim(wx * Vector3(1.4, 1.5, -3.0), wx * Vector3(0.0, 0.8, 0.0), wx * Vector3(0.0, 0.05, -2.4))
		await _secs(1.5)
		await _shot("%s_crate_well_idle" % key)
		_aim(wx * Vector3(-3.5, 1.7, -7.0), wx * Vector3(0.0, 3.0, 0.0), wx * Vector3(0.0, 0.05, -6.0), 70.0)
		await _secs(1.0)
		await _shot("%s_crate_well_mid" % key)
		# the locator from across the map (eye height, looking over the yard)
		var wp: Vector3 = wx.origin
		for far: Array in [["a", xf.origin + Vector3(26.0, 1.7, -30.0) - wp], ["b", Vector3(16.0, 1.7, 9.0)], ["c", Vector3(-9.0, 1.7, -14.0)]]:
			var e2: Vector3 = wp + (far[1] as Vector3)
			_cam.fov = 64.0
			_cam.global_position = e2
			_cam.look_at(wp + Vector3(0, 7.0, 0), Vector3.UP)
			_map.player.global_position = Vector3(e2.x, 0.2, e2.z)
			await _secs(1.2)
			await _shot("%s_locator_well_%s" % [key, far[0]])
	# the crate back indoors: what the locator shows from outside the inn and from across the taproom
	_go(0)
	await _secs(0.8)
	for far2: Array in [["a", Vector3(34.0, 1.7, -12.0)], ["b", Vector3(26.0, 1.7, -30.0)]]:
		var e3: Vector3 = xf.origin + (far2[1] as Vector3)
		_cam.fov = 64.0
		_cam.global_position = e3
		_cam.look_at(xf.origin + Vector3(0, 9.0, 0), Vector3.UP)
		_map.player.global_position = Vector3(e3.x, 0.2, e3.z)
		await _secs(1.2)
		await _shot("%s_locator_hearth_%s" % [key, far2[0]])
	_aim(xf * Vector3(5.0, 1.6, -9.0), xf * Vector3(0.0, 1.0, 0.0), xf * Vector3(0.0, 0.05, -4.0), 70.0)
	await _secs(1.0)
	await _shot("%s_locator_hearth_room" % key)
