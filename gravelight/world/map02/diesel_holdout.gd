class_name DieselHoldout
extends HoldoutStation
## Letzte Fahrt's three diesel holds (UPDATE 10 contracts C2 "Diesels" and C3, design section 2 s5, DECISIONS T-153;
## data map02.json "letzte_fahrt"."diesels"). Each is a HoldoutStation with its twist:
##   inj_injector  the workshop lathe turns a new injector: it runs only while the pump room is flooded ("the belt only
##                 grips wet"), x2 spawns, Kielholer at the dock door;
##   inj_battery   a battery cell lifted out of the lower pens: the lights there die while it runs (GameState flag
##                 `lights_out`; the searchlight or flashlights are the light), the pump deck floods to the knees;
##   inj_sequence  the engine room's start panel, 45 s, while the drowned pull at the hull (a hull groan and a shake
##                 every `shake_every_s`; boarders at the hatch); Brecht's sequence is called out as it runs.
## Done, it sets its GameState flag (inj_*), which completes the quest's s5a/s5b/s5c. It starts only while its step is
## active (or with no egg loaded, never). Bots hold it through a hold_zone task (anchors group diesel_<id>, start
## "interact").

const QUEST: StringName = &"map02_letzte_fahrt"

var step_id: StringName = &""
var cfg: Dictionary = {}
var _shake_t: float = 0.0
var _call_i: int = 0
var _dimmed: Array[Light3D] = []


static func setup_from(d: DieselHoldout, id: StringName, c: Dictionary) -> DieselHoldout:
	d.holdout_id = id
	d.cfg = c
	d.step_id = StringName(str(c.get("step", "")))
	d.zone_id = StringName(str(c.get("zone", "D_PENHALL")))
	d.seconds = float(c.get("seconds", 30.0))
	d.spawn_mult = float(c.get("spawn_mult", 2.0))
	d.temp_spawns = int(c.get("temp_spawns", 2))   # T-153: the engine room takes none (ring points fell in the hull walls and the basin)
	d.radius = float(c.get("radius_m", 3.5))
	var pts: PackedVector3Array = PackedVector3Array()
	for a: Variant in c.get("spawns", []):
		pts.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	d.spawn_points = pts
	d.label = {&"inj_injector": "the lathe (turn a new injector)", &"inj_battery": "the battery cell (lift it out)",
		&"inj_sequence": "the start panel (Brecht's sequence)"}.get(id, "the diesels")
	d.hud_title = {&"inj_injector": "INJECTOR", &"inj_battery": "BATTERY CELL", &"inj_sequence": "START SEQUENCE"}.get(id, "DIESEL")
	return d


func _ready() -> void:
	interact_size = Vector3(1.4, 1.6, 1.0)
	interact_offset = Vector3(0, 0.9, 0)
	super._ready()
	add_to_group(&"diesel_holdouts")
	add_to_group(StringName("diesel_" + String(holdout_id)))


func build_greybox() -> void:
	var metal: StandardMaterial3D = greybox_mat(Color(0.25, 0.26, 0.27))
	var brass: StandardMaterial3D = greybox_mat(Color(0.62, 0.48, 0.22))
	match String(holdout_id):
		"inj_injector":
			add_box(self, Vector3(0.5, 0.25, 0.25), Vector3(0, 1.0, -0.2), brass)   # the injector body in the chuck
		"inj_battery":
			add_box(self, Vector3(0.7, 0.9, 0.5), Vector3(0, 0.45, 0), greybox_mat(Color(0.12, 0.13, 0.12)))
			add_box(self, Vector3(0.1, 0.1, 0.1), Vector3(-0.2, 0.95, 0), brass)
			add_box(self, Vector3(0.1, 0.1, 0.1), Vector3(0.2, 0.95, 0), brass)
		_:
			add_box(self, Vector3(1.0, 1.2, 0.25), Vector3(0, 0.6, 0), metal)
			for i: int in 5:
				add_box(self, Vector3(0.08, 0.08, 0.06), Vector3(-0.32 + float(i) * 0.16, 1.0, -0.15), greybox_mat(Color(0.8, 0.2, 0.1), 1.2))
	var l: Label3D = add_label(self, {&"inj_injector": "EINSPRITZDÜSE", &"inj_battery": "ZELLE 7", &"inj_sequence": "ANLASSEN"}.get(holdout_id, "DIESEL"),
		Vector3(0, 1.35, -0.2), 16, Color(0.9, 0.85, 0.7))
	l.rotation.y = 0.0


func _tide() -> TideController:
	return get_tree().get_first_node_in_group(&"tide") as TideController


func start_block(player: Player) -> String:
	var base: String = super.start_block(player)
	if base != "":
		return base
	if step_id == &"" or not QuestManager.is_active(QUEST, step_id):
		return "" if QuestManager.is_step_done(QUEST, step_id) else "Not yet. (Brecht's log says what this is for.)"
	if other_diesel_running(self, get_tree()):
		# T-153: one engine job at a time (the bots started two holds at once, split up under x2 spawns each and
		# were all downed; two holds also double the round's pressure for players)
		return "One engine job at a time: finish the other first."
	if bool(cfg.get("needs_flood", false)):
		var t: TideController = _tide()
		if t == null or not t.flooded:
			return "The lathe's belt slips dry. It only grips when the pump room floods."
	return ""


## Is another of the three diesel holds running?
static func other_diesel_running(me: Node, tree: SceneTree) -> bool:
	for n: Node in tree.get_nodes_in_group(&"holdout_stations"):
		if n != me and n is DieselHoldout and (n as DieselHoldout).state == HoldoutStation.State.RUNNING:
			return true
	return false


func get_prompt(player: Player) -> String:
	if state == State.DONE or (step_id != &"" and QuestManager.is_step_done(QUEST, step_id)):
		return ""
	return super.get_prompt(player)


func can_interact(player: Player) -> bool:
	return super.can_interact(player) and step_id != &"" and QuestManager.is_active(QUEST, step_id)


func _on_started() -> void:
	_shake_t = float(cfg.get("shake_every_s", 6.0))
	_call_i = 0
	if bool(cfg.get("lights_out", false)):
		_lights(false)
		if Net.is_authority():
			GameState.set_flag(&"lights_out", true)
	if holdout_id == &"inj_injector":
		AudioDirector.play_3d("lift_winch", global_position + Vector3.UP, 0.0, 0.0)
	if Net.is_authority():
		GLVO.play_category(&"OPR", "LF_DIESEL_START", 0.8)


func _twist_tick(delta: float) -> void:
	if bool(cfg.get("hull_pull", false)):
		_shake_t -= delta
		if _shake_t <= 0.0:
			_shake_t = float(cfg.get("shake_every_s", 6.0))
			GLBus.explosion.emit(global_position + Vector3(0, 0, 8.0), 4.0)   # the hull lurches (a screen shake)
			AudioDirector.play_3d("hull_groan", global_position, 2.0, 0.1)
			Net.mirror(self, &"_groan")
			var dir: ZombieDirector = _director()
			if dir != null and not spawn_points.is_empty():
				dir.spawn_burst(Array(spawn_points), 1)
	var calls: Array = cfg.get("calls", [])
	if not calls.is_empty():
		var due: int = int(floor(progress * float(calls.size()) + 0.0001))
		if due > _call_i and _call_i < calls.size():
			var t: Totenhafen = Totenhafen.of(get_tree())
			if t != null:
				t.banner(str(calls[_call_i]), 2.0)
			Net.mirror(self, &"_call", [_call_i])
			_call_i += 1


func _groan() -> void:
	AudioDirector.play_3d("hull_groan", global_position, 2.0, 0.1)


func _call(i: int) -> void:
	var calls: Array = cfg.get("calls", [])
	var t: Totenhafen = Totenhafen.of(get_tree())
	if t != null and i < calls.size():
		t.banner(str(calls[i]), 2.0)


func _completed() -> void:
	_restore()
	AudioDirector.play_3d("diesel_start" if holdout_id == &"inj_sequence" else "lift_winch", global_position + Vector3.UP, 4.0, 0.0)
	if Net.is_authority():
		GameState.set_flag(holdout_id, true)
		if holdout_id == &"inj_sequence":
			GLVO.play(&"DEA_LF_DIESELS_01")


func _failed() -> void:
	_restore()


func _restore() -> void:
	if bool(cfg.get("lights_out", false)):
		_lights(true)
		if Net.is_authority():
			GameState.set_flag(&"lights_out", false)


## The lower pens go dark while the cell is out (lights with zone meta F_LOWERPENS), and come back after.
func _lights(on: bool) -> void:
	if not on:
		_dimmed.clear()
		for n: Node in get_tree().get_nodes_in_group(&"power_lights"):
			var l: Light3D = n as Light3D
			if l != null and l.visible and str(l.get_meta("zone", "")) == String(zone_id):
				l.visible = false
				_dimmed.append(l)
		var root: Node = get_tree().current_scene
		if root != null:
			for l2: Node in root.find_children("*", "Light3D", true, false):
				var ll: Light3D = l2 as Light3D
				if ll.visible and str(ll.get_meta("zone", "")) == String(zone_id) and not _dimmed.has(ll):
					ll.visible = false
					_dimmed.append(ll)
	else:
		for l: Light3D in _dimmed:
			if is_instance_valid(l):
				l.visible = true
		_dimmed.clear()
