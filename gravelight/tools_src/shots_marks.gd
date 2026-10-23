extends Node
## Screenshots of the pause map and its marks (Update 04 section 3, DECISIONS T-069). Off-screen and silent, every
## audio bus muted, the mouse never captured; its own throwaway profile.
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_marks.tscn -- --out=C:/dir --map=map01|map00
## map01 (Kaltenbrunn, 3 bots, the power on, every area seen): the MAP tab with marks and the squad's order lines,
## zoomed in, a hover tooltip, the empty-spot radial, BUY THIS on a perk, the who-picker, the door question, then
## the in-world chalk X marks. map00: the same at the Crossroads Inn.

const MAPS: Dictionary = {"map00": "res://gravelight/maps/map00_crossroads/map00.tscn", "map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"}

var _out: String = "user://shots"
var _which: String = "map01"
var _map: MapRoot = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--map="):
			_which = a.substr(6)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	DirAccess.make_dir_recursive_absolute(_out)
	ProfileSave.path = "user://_shots_marks_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_shots_marks_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _shot(label: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("%s_%s.png" % [_which, label]))
	print("[shots] ", _which, " ", label)


func _node(path: String) -> Node:
	return _map.get_node_or_null(NodePath(path))


func _first(cls: String) -> Node:
	var all: Array[Node] = _map.find_children("*", cls, true, false)
	return all[0] if not all.is_empty() else null


func _run() -> void:
	if _which == "bs":
		await _run_bs()
		get_tree().quit()
		return
	_map = (load(MAPS[_which]) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _frames(120)
	RoundManager.stop()
	for z: Variant in (_map.director.active_zombies() if _map.director != null else []):
		(z as Node).queue_free()
	GameState.power_on = true
	GLBus.power_activated.emit()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and _which == "map00" and (d.door_id == &"door_cellar" or d.door_id == &"door_stable"):
			d.open(1)
	var ms: MapState = MapState.current()
	ms.discover_all()
	for pid: int in GameState.bot_ids:
		Economy.grant(pid, 1800)
	Economy.grant(1, 4000)
	await _frames(30)
	var mm: MapMarks = MapMarks.current()
	var me: Player = _map.player
	var bots: Array = GameState.bot_ids
	# marks: yours, the squad's, orders for the bots (one short of Scrip)
	mm.place({"kind": "go", "pos": me.global_position + Vector3(3, 0, 2), "target": "me", "label": ms.data.zone_label_at(me.global_position)})
	mm.place({"kind": "note", "pos": me.global_position + Vector3(-4, 0, 5), "target": "me", "label": "Loop here"})
	var perks: Array[Node] = _map.find_children("*", "PerkMachine", true, false)
	var pk_far: PerkMachine = null
	var pk_near: PerkMachine = null
	for p: Node in perks:
		var pm: PerkMachine = p as PerkMachine
		if PerkManager.has_perk(int(bots[0]), pm.perk_id) or PerkManager.has_perk(int(bots[1]), pm.perk_id):
			continue
		if pk_near == null or pm.global_position.distance_to(me.global_position) < pk_near.global_position.distance_to(me.global_position):
			pk_far = pk_near if pk_far == null else pk_far
			pk_near = pm
		elif pk_far == null:
			pk_far = pm
	if pk_near != null:
		mm.place({"kind": "buy", "pos": pk_near.global_position, "node": pk_near, "target": int(bots[0])})
	if pk_far != null:
		_set_scrip(int(bots[1]), 400)
		mm.place({"kind": "buy", "pos": pk_far.global_position, "node": pk_far, "target": int(bots[1])})
	mm.place({"kind": "defend", "pos": me.global_position + Vector3(-2, 0, -3), "target": int(bots[2])})
	var doors: Array[Node] = get_tree().get_nodes_in_group(&"doors")
	for dn: Node in doors:
		var d2: BuyDoor = dn as BuyDoor
		if d2 != null and not d2.is_open:
			mm.place({"kind": "danger", "pos": d2.global_position + d2.global_basis.z * 2.0, "label": "Behind the %s" % d2.label})
			break
	await _frames(60)
	# the pause map
	_map.pause_menu.toggle()
	await _frames(10)
	var view: PauseMapView = _map.pause_menu.map_view() as PauseMapView
	view.refresh()
	await _frames(10)
	await _shot("pause_map")
	view.canvas.zoom = minf(PauseMapView.ZOOM_MAX, view.canvas.zoom * 2.6)
	view.canvas.center = Vector2(me.global_position.x, me.global_position.z)
	view.set_floor(ms.local_floor())
	await _frames(10)
	await _shot("pause_map_zoom")
	# hover a perk machine (or the nearest POI)
	var hover_at: Vector2 = Vector2.ZERO
	if pk_near != null:
		view.set_floor(ms.data.floor_at(pk_near.global_position + Vector3.UP * 0.2))
		view.canvas.center = Vector2(pk_near.global_position.x, pk_near.global_position.z) + Vector2(4, 2)
		await _frames(8)
		hover_at = view.canvas.world_to_canvas(pk_near.global_position)
		view.cursor = hover_at
		view._hover_update()
		await _shot("pause_map_hover")
		view.click(hover_at)
		await _shot("radial_buy")
		view.radial.choose_id("buy")
		await _shot("who_picker")
		view._close_popups()
		view.pending = {}
	# an empty spot: the radial
	view.set_floor(ms.local_floor())
	view.canvas.center = Vector2(me.global_position.x, me.global_position.z)
	await _frames(8)
	var empty_at: Vector2 = view.canvas.world_to_canvas(me.global_position + Vector3(4.0, 0, -1.0))
	view.cursor = empty_at
	view.click(empty_at)
	await _shot("radial_empty")
	view._close_popups()
	view.pending = {}
	# a door: the question
	for dn2: Node in doors:
		var d3: BuyDoor = dn2 as BuyDoor
		if d3 == null or d3.is_open:
			continue
		view.set_floor(ms.data.floor_at(d3.global_position + Vector3.UP * 0.2))
		view.canvas.center = Vector2(d3.global_position.x, d3.global_position.z)
		await _frames(8)
		var dat: Vector2 = view.canvas.world_to_canvas(d3.global_position)
		view.click(dat)
		if view.radial.visible and view.radial.choose_id("buy"):
			view.pick_target("any")
			await _shot("door_confirm")
			view.confirm_dialog(false)
		view._close_popups()
		break
	_map.pause_menu.toggle()
	await _frames(20)
	# in the world: chalk X marks round the player
	mm.clear()
	var base: Vector3 = me.global_position
	var fwd: Vector3 = -me.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side: Vector3 = fwd.cross(Vector3.UP)
	var b0: BotBrain = _map.squad.brains[0]
	mm.place({"kind": "go", "pos": b0.snap(base + fwd * 3.5 + side * 2.2), "target": "me", "label": "Loop here"})
	mm.place({"kind": "danger", "pos": b0.snap(base + fwd * 6.5 - side * 2.6), "label": "Window"})
	mm.place({"kind": "defend", "pos": b0.snap(base + fwd * 10.0 + side * 1.0), "target": int(bots[2])})
	if pk_near != null:
		mm.place({"kind": "buy", "pos": pk_near.global_position, "node": pk_near, "target": int(bots[0])})
	await _frames(20)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 70.0
	_map.add_child(cam)
	cam.global_position = base - fwd * 2.0 + Vector3.UP * 3.4
	cam.look_at(base + fwd * 6.0, Vector3.UP)
	for b: BotBrain in _map.squad.brains:
		b.player.global_position = b.snap(base - fwd * 3.0 + side * (b.index - 1) * 1.5)   # out of the picture
	cam.make_current()
	get_tree().paused = false
	await _frames(600)   # the intro card and the bots' acknowledgement pings fade first
	await _shot("world_chalk_x")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[shots] done -> ", _out)
	get_tree().paused = false
	get_tree().quit()


## B&S (Scrapheap Junction): personal holo pins from the ping key, the pause panel's MAP in the holo skin.
func _run_bs() -> void:
	SaveProfile.path = "user://_shots_marks_bs.json"
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BSLevel.pending_cutscene = ""
	var lvl: Node = (load("res://bs/planets/scrapheap/scrapheap.tscn") as PackedScene).instantiate()
	lvl.set("play_arrival", false)
	get_tree().root.add_child(lvl)
	get_tree().current_scene = lvl
	await _frames(60)
	var mm: MapMarks = MapMarks.current()
	if mm == null:
		print("[shots] bs: no MapMarks")
		return
	var bolt: Node3D = lvl.get("bolt") as Node3D
	var fwd: Vector3 = -bolt.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	mm.place({"kind": "go", "pos": bolt.global_position + fwd * 5.0, "target": "me", "label": "Meet here"})
	mm.place({"kind": "danger", "pos": bolt.global_position + fwd * 9.0 + fwd.cross(Vector3.UP) * 3.0, "label": "Turret"})
	var r: Dictionary = mm.ping.ping() if mm.ping.can_ping() else {}
	print("[shots] bs ping: ", r)
	await _frames(30)
	await _shot("bs_holo_pins")
	MapState.current().discover_all()   # the shot shows the whole planet (in play the holo map fills in as you explore)
	var pm: BSPauseMenu = lvl.get("pause_menu") as BSPauseMenu
	pm.open()
	pm.open_map()
	await _frames(12)
	await _shot("bs_pause_map")
	pm.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveProfile.path))


func _set_scrip(pid: int, n: int) -> void:
	var have: int = Economy.get_scrip(pid)
	if have > n:
		Economy.spend(pid, &"qa", have - n)
	elif have < n:
		Economy.grant(pid, n - have)
