extends Node
## T-269 (docs/u21/t269_zombie_look.md): what a crowd of zombies looks like in play. Loads a map, stands 24 Gangers
## from the map's own variant table in front of a fixed camera and saves, per scene:
##   <scene>_bg.png     the empty view (tools/zombie_look_stats.py takes the crowd's pixels as the difference to it)
##   <scene>.png        the crowd at gameplay distance
##   <scene>_close.png  the front row close up
## plus look.json: every zombie's kit / build / sex and instance parameters, the surfaces and gear per zombie, and the
## renderer's draw calls with and without the crowd.
## Map 0 has three more scenes: `gore` (a severed arm in flight and on the floor, a corpse), `special` (a Glasshide,
## the Bellringer and the Foreman beside walkers) and `gallery` (every outfit of the wardrobe, eight to a picture, in
## the yard at noon; look.json lists who stands where, left to right).
##   tools/wsl_zombie_look.sh <tag> --map=map00_crossroads [--only=taproom,yard] [--count=24] [--hour-off]
## Rendered runs only under WSL + Xvfb (never a window on the owner's PC). Headless it prints the stats without pictures.

const MAPS: Dictionary = {
	"map00_crossroads": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01_kaltenbrunn": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02_totenhafen": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a_thalbach": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b_kranich": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c_groomlake": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d_mondlicht": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
## Scenes per map: [name, crowd centre, camera position, hour (-1 = the map's own night)]. A map without an entry
## gets one scene in front of the player's spawn ("start").
const SCENES: Dictionary = {
	"map00_crossroads": [
		["taproom", Vector3(20.6, 0.0, 7.0), Vector3(13.6, 1.65, 7.0), -1.0],
		["yard", Vector3(12.0, 0.0, -14.0), Vector3(4.5, 1.65, -14.0), -1.0],
		["noon", Vector3(12.0, 0.0, -14.0), Vector3(4.5, 1.65, -14.0), 12.0],
	],
}

var _out: String = ""
var _only: PackedStringArray = PackedStringArray()
var _map_id: String = "map00_crossroads"
var _count: int = 24
var _scale: float = 0.67
var _map: MapRoot
var _cam: Camera3D
var _saved: int = 0
var _report: Dictionary = {"scenes": {}}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
		elif a.begins_with("--map="):
			_map_id = a.substr(6)
		elif a.begins_with("--count="):
			_count = int(a.substr(8))
		elif a.begins_with("--scale="):
			_scale = float(a.substr(8))
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("docs/captures/t269/after/" + _map_id)
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_shots_zlook_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_shots_zlook_settings.cfg"
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.values["gore"] = "full"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	seed(4711)
	get_viewport().scaling_3d_scale = _scale
	_map = (load(str(MAPS[_map_id])) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _skip(s: float) -> void:
	if s <= 0.0:
		return
	RenderingServer.render_loop_enabled = false
	await get_tree().create_timer(s).timeout
	RenderingServer.render_loop_enabled = true
	await _frames(2)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	_hide_layers()
	if DisplayServer.get_name() == "headless":
		print("[zlook] (headless: no picture) ", name)
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	_saved += 1
	print("[zlook] ", name, "  draw calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func _draws() -> int:
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func _look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	_cam.fov = fov
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	_cam.make_current()


func _hide_layers() -> void:
	for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if not (cl is LookPost):
			(cl as CanvasLayer).visible = false


func _wants(scene: String) -> bool:
	return _only.is_empty() or _only.has(scene)


func _new_since(before: Dictionary) -> Array[Zombie]:
	var mine: Array[Zombie] = []
	for z: Zombie in _map.director.active_zombies():
		if not before.has(z):
			mine.append(z)
	return mine


func _snapshot() -> Dictionary:
	var before: Dictionary = {}
	for z: Zombie in _map.director.active_zombies():
		before[z] = true
	return before


## The zombies in `mine` stood at `spots`, facing `face`, up and still.
func _place(mine: Array[Zombie], spots: Array, face: Vector3) -> void:
	var t: float = 0.0
	while t < 9.0:
		var up: bool = true
		for z: Zombie in mine:
			if z.state == Zombie.State.EMERGE:
				up = false
		if up:
			break
		await _skip(0.25)
		t += 0.25
	for i: int in mine.size():
		var z: Zombie = mine[i]
		z.global_position = spots[i % spots.size()] as Vector3
		var d: Vector3 = face - z.global_position
		z.rotation.y = atan2(-d.x, -d.z)
		z.velocity = Vector3.ZERO
		z.set_physics_process(false)
	await get_tree().physics_frame


func _stand(spots: Array, face: Vector3) -> Array[Zombie]:
	var before: Dictionary = _snapshot()
	_map.director.spawn_burst(spots, spots.size())
	var mine: Array[Zombie] = _new_since(before)
	await _place(mine, spots, face)
	return mine


## Rows of six across the camera's view, the front row nearest, staggered so nobody hides the one behind.
func _crowd_spots(centre: Vector3, cam: Vector3, n: int) -> Array:
	var fwd: Vector3 = (centre - cam) * Vector3(1, 0, 1)
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var spots: Array = []
	for i: int in n:
		var row: int = i / 6
		var col: int = i % 6
		spots.append(centre + right * ((float(col) - 2.5) * 0.95 + (0.45 if row % 2 == 1 else 0.0)) + fwd * (float(row) * 1.25 - 1.6))
	return spots


func _describe(zs: Array[Zombie]) -> Array:
	var rows: Array = []
	for z: Zombie in zs:
		var body: MeshInstance3D = null
		for n: Node in z.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() == 2 and mi.mesh.surface_get_name(0) == "skin":
				body = mi
				break
		var meshes: int = 0
		var surfaces: int = 0
		var mats: Dictionary = {}
		for n: Node in z.find_children("*", "MeshInstance3D", true, false):
			var mi2: MeshInstance3D = n as MeshInstance3D
			if not mi2.is_visible_in_tree() or mi2.mesh == null:
				continue
			meshes += 1
			surfaces += mi2.mesh.get_surface_count()
			for si: int in mi2.mesh.get_surface_count():
				var m: Material = mi2.get_active_material(si)
				if m != null:
					mats[m.get_instance_id()] = true
		var row: Dictionary = {"kit": z.kit_name(), "build": z.build_name(), "female": z.is_female(), "enemy": String(z.enemy_id),
			"mesh_instances": meshes, "surfaces": surfaces, "materials": mats.size()}
		if body != null:
			for key: String in ["inst_tint", "inst_dirt", "inst_cloth", "inst_cloth2", "inst_accent", "inst_skin", "inst_wear"]:
				var v: Variant = body.get_instance_shader_parameter(key)
				if v != null:
					row[key] = str(v)
		if z.has_method("outfit_name"):
			row["outfit"] = str(z.call("outfit_name"))
		rows.append(row)
	return rows


func _clear() -> void:
	for z: Zombie in _map.director.active_zombies():
		z.set_physics_process(true)
		z.deactivate()
		_map.director.on_zombie_returned(z)
	await _skip(0.3)


func _crowd_scene(name: String, centre: Vector3, cam: Vector3, hour: float) -> void:
	var dc: Node = _map.find_child("DayCycle", true, false)
	if dc != null and hour >= 0.0:
		dc.call("hold_hour", hour)
		await _skip(1.5)
	var eye: Vector3 = centre + Vector3(0, 1.1, 0)
	_look(cam, eye, 62.0)
	await _shot(name + "_bg")
	var d0: int = _draws()
	var zs: Array[Zombie] = await _stand(_crowd_spots(centre, cam, _count), cam)
	await _skip(0.6)
	await _shot(name)
	var d1: int = _draws()
	_report["scenes"][name] = {"zombies": _describe(zs), "draw_calls_empty": d0, "draw_calls_crowd": d1, "count": zs.size(),
		"draw_calls_per_zombie": float(d1 - d0) / maxf(1.0, float(zs.size()))}
	# close up on the front row: hide the rest for the background, then show them
	var fwd: Vector3 = ((centre - cam) * Vector3(1, 0, 1)).normalized()
	var close_cam: Vector3 = centre - fwd * 4.3 + Vector3(0, 1.55, 0)
	for z: Zombie in zs:
		z.hide()
	_look(close_cam, centre - fwd * 1.6 + Vector3(0, 1.25, 0), 44.0)
	await _shot(name + "_close_bg")
	for z: Zombie in zs:
		z.show()
	await _shot(name + "_close")
	await _clear()
	if dc != null and hour >= 0.0:
		dc.set("held_hour", -1.0)


func _run() -> void:
	await _skip(14.0)
	RoundManager.stop()
	_map.director.kill_all(true)
	_cam = Camera3D.new()
	_map.add_child(_cam)
	var p: Player = _map.player
	var scenes: Array = SCENES.get(_map_id, [])
	if scenes.is_empty() and p != null:
		var f: Vector3 = -p.global_transform.basis.z * Vector3(1, 0, 1)
		f = f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)
		var base: Vector3 = p.global_position
		scenes = [["start", base + f * 8.5, base + f * 1.2 + Vector3(0, 1.65, 0), -1.0]]
	for s: Array in scenes:
		if _wants(str(s[0])):
			await _crowd_scene(str(s[0]), s[1], s[2], float(s[3]))
	if _map_id == "map00_crossroads":
		if p != null:
			p.global_position = Vector3(8.0, 0.2, 3.0)
		if _wants("gore"):
			await _gore_scene()
		if _wants("special"):
			await _special_scene()
		if _wants("gallery"):
			await _gallery_scene()
	var f2: FileAccess = FileAccess.open(_out.path_join("look.json"), FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify(_report, "\t"))
		f2.close()
	print("[zlook] %d pictures in %s" % [_saved, _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()


## Three walkers in the taproom: the left one loses an arm (the piece caught in the air and on the floor), the
## right one is killed (the corpse), the middle one stands for comparison.
func _gore_scene() -> void:
	var c: Vector3 = Vector3(21.6, 0.0, 6.0)
	var cam: Vector3 = Vector3(18.4, 1.5, 6.0)
	_look(cam, c + Vector3(0, 1.0, 0), 56.0)
	var spots: Array = [c + Vector3(0, 0, -1.3), c, c + Vector3(0, 0, 1.3)]
	var zs: Array[Zombie] = await _stand(spots, cam)
	await _shot("gore_00_whole")
	if zs.size() >= 3:
		ZombieGore.sever(zs[0], "LeftLowerArm", Vector3(-1.2, 2.2, 0.4))
		await _frames(4)
		await _shot("gore_01_arm_in_air")
		await _secs(1.4)
		await _shot("gore_02_arm_on_floor")
		ZombieGore.sever(zs[0], "Head", Vector3(-0.8, 2.0, -0.3))
		await _frames(5)
		await _shot("gore_03_head")
		zs[2].set_physics_process(true)
		zs[2].take_damage(zs[2].hp + 1.0, &"torso", &"m1_garand", 1, &"bullet")
		await _secs(2.6)
		await _shot("gore_04_corpse")
		_look(c + Vector3(-1.7, 1.2, 2.2), c + Vector3(0.2, 0.2, 1.5), 50.0)
		await _shot("gore_05_corpse_close")
	_report["scenes"]["gore"] = {"zombies": _describe(zs)}
	await _clear()


## A Glasshide, the Bellringer and the Foreman among walkers, as the player meets them.
func _special_scene() -> void:
	var c: Vector3 = Vector3(20.6, 0.0, 7.0)
	var cam: Vector3 = Vector3(14.4, 1.65, 7.0)
	_look(cam, c + Vector3(0, 1.1, 0), 60.0)
	var walkers: Array = []
	for i: int in 6:
		walkers.append(c + Vector3(0.4 if i % 2 == 0 else 1.5, 0.0, float(i) * 1.1 - 2.75))
	var zs: Array[Zombie] = await _stand(walkers, cam)
	var extra: Array = [[&"glasshide", c + Vector3(-1.0, 0, -1.6)], [&"bellringer", c + Vector3(-1.0, 0, 0.2)], [&"foreman", c + Vector3(-0.6, 0, 2.2)]]
	for e: Array in extra:
		var before: Dictionary = _snapshot()
		_map.director.spawn_special(e[0], 1, [e[1]])
		var got: Array[Zombie] = _new_since(before)
		if not got.is_empty():
			await _place(got, [e[1]], cam)
			zs.append_array(got)
	await _skip(0.5)
	await _shot("special_00")
	_look(c + Vector3(-4.2, 1.6, 0.3), c + Vector3(-0.6, 1.2, 0.3), 52.0)
	await _shot("special_01_close")
	_report["scenes"]["special"] = {"zombies": _describe(zs)}
	await _clear()


## Every outfit of data/gravelight/zombie_wardrobe.json on the kit that wears it, eight to a picture, at noon.
func _gallery_scene() -> void:
	if not ClassDB.class_exists("Node") or not ResourceLoader.exists("res://gravelight/enemies/zombie_wardrobe.gd"):
		return
	var dressed: bool = false   # (a build before T-269 has no outfits to show)
	for m: Dictionary in (load("res://gravelight/enemies/zombie.gd") as Script).get_script_method_list():
		if str(m["name"]) == "outfit_name":
			dressed = true
	if not dressed:
		return
	var ward: Object = load("res://gravelight/enemies/zombie_wardrobe.gd") as Object
	var cfg: Dictionary = ward.call("cfg")
	if not bool(ward.call("enabled")):
		return
	var kit_of: Dictionary = {}
	for map_id: Variant in (cfg["maps"] as Dictionary).keys():
		if not (cfg["maps"][map_id] is Dictionary):
			continue
		for kit: Variant in (cfg["maps"][map_id] as Dictionary).keys():
			if cfg["maps"][map_id][kit] is Dictionary:
				for o: Variant in (cfg["maps"][map_id][kit] as Dictionary).keys():
					if not kit_of.has(o):
						kit_of[o] = [str(map_id), str(kit)]
	var names: Array = []
	for o: Variant in (cfg["outfits"] as Dictionary).keys():
		if kit_of.has(o):
			names.append(str(o))
	var dc: Node = _map.find_child("DayCycle", true, false)
	if dc != null:
		dc.call("hold_hour", 12.0)
		await _skip(1.5)
	var centre: Vector3 = Vector3(12.0, 0.0, -14.0)
	var cam: Vector3 = Vector3(5.6, 1.5, -14.0)
	_look(cam, centre + Vector3(0, 1.0, 0), 60.0)
	var listing: Array = []
	var page: int = 0
	for start: int in range(0, names.size(), 8):
		var zs: Array[Zombie] = []
		var spots: Array = []
		var row: Array = []
		for i: int in range(start, mini(start + 8, names.size())):
			var o: String = names[i]
			var map_id: String = kit_of[o][0]
			var kit: String = kit_of[o][1]
			var before: Dictionary = _snapshot()
			var spec: Dictionary = RoundManager.take_extra_spawn()
			spec["variant"] = kit
			var at: Vector3 = centre + Vector3(0.0, 0.0, (float(i - start) - 3.5) * 0.92)
			_map.director.activate_reserved(spec, at)
			var got: Array[Zombie] = _new_since(before)
			if got.is_empty():
				continue
			var z: Zombie = got[0]
			# the first seed whose pick on that map is this outfit, then its parameters as the game would set them
			var seed_v: int = 0
			for tryv: int in 4000:
				if str(ward.call("outfit_name", map_id, kit, tryv)) == o:
					seed_v = tryv
					break
			var params: Dictionary = ward.call("look_params", map_id, kit, seed_v)
			for key: String in params.keys():
				z.call("_set_inst", key, params[key])
			zs.append(z)
			spots.append(at)
			row.append({"outfit": o, "kit": kit, "female": z.is_female(), "skin": str(ward.call("skin_name", seed_v))})
		await _place(zs, spots, cam)
		for i: int in zs.size():
			zs[i].global_position = spots[i]
		await _skip(0.5)
		await _shot("gallery_%02d" % page)
		listing.append(row)
		page += 1
		await _clear()
	_report["scenes"]["gallery"] = {"pages": listing}
	if dc != null:
		dc.set("held_hour", -1.0)
