class_name MarkPing
extends Node
## The ping key (Update 04 section 3, DECISIONS T-069): marks what you look at with the same logic as the pause
## map. GRAVELIGHT action "ping" (middle mouse / D-pad up; alt-fire keeps B and D-pad right), B&S "bs_ping" (G /
## Back: B&S has no bots, so its pings are personal holo pins). Made by MapMarks for the match.
##   a perk machine, wall weapon, ammo box, the crate, the Crucible, a trap, the Armorer's Bench -> "Buy this" for
##     any bot (without bots: a waypoint for you);
##   a door -> "Ping again to have a bot open this door for 1,250" (the second press within confirm_s confirms);
##   an easter-egg object / part, a power-up, the power switch -> "Collect / activate this" (the squad's egg API);
##   a wall or the floor -> "Go here" (yours);
##   a second press within double_tap_s -> that mark becomes "Danger";
##   pinging one of your marks (within remove_m) removes it.
## Tuning: data/maps/marks.json "ping".

const MASK: int = 1 | (1 << 4) | (1 << 8)   # world, interactables, doors

var marks: MapMarks = null
var action: StringName = &"ping"
var last_result: Dictionary = {}
var _last_t: int = -100000
var _last_id: int = -1
var _last_pos: Vector3 = Vector3.INF
var _door: Node = null
var _door_t: int = -100000
var _pc: Dictionary = {}


func setup(m: MapMarks) -> void:
	marks = m
	action = &"ping" if m.state == null or m.state.game == "gravelight" else &"bs_ping"
	_pc = MapMarks.cfg().get("ping", {})
	_ensure_action()


## The B&S action isn't in its bindings table: G / Back, added here when missing (GRAVELIGHT's comes from
## data/gravelight/input_defaults.json, rebindable in Settings > Controls).
func _ensure_action() -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	if action == &"bs_ping":
		var k: InputEventKey = InputEventKey.new()
		k.physical_keycode = KEY_G
		InputMap.action_add_event(action, k)
		var j: InputEventJoypadButton = InputEventJoypadButton.new()
		j.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event(action, j)
	else:
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_MIDDLE
		InputMap.action_add_event(action, mb)
		var j2: InputEventJoypadButton = InputEventJoypadButton.new()
		j2.button_index = JOY_BUTTON_DPAD_UP
		InputMap.action_add_event(action, j2)


func can_ping() -> bool:
	if marks == null or marks.state == null or not is_inside_tree() or get_tree().paused:
		return false
	if marks.state.game == "gravelight":
		if GameState.phase != GameState.Phase.PLAYING or GameState.input_blocked or BotCommandWheel.capturing:
			return false
	var body: Node3D = marks.state.local_body()
	if body == null or (body is Player and ((body as Player).spectating or (body as Player).downed)):
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action, false, true) and can_ping():
		ping()
		get_viewport().set_input_as_handled()


## What the view ray hits: {pos, normal, node} ({} nothing within range).
func look_hit() -> Dictionary:
	var ms: MapState = marks.state
	var view: Array = ms.local_view()
	var from: Vector3 = view[0]
	var fwd: Vector3 = (view[1] as Vector3).normalized()
	var body: Node3D = ms.local_body()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + fwd * float(_pc.get("range_m", 45.0)), MASK)
	q.collide_with_areas = true
	if body is CollisionObject3D:
		q.exclude = [(body as CollisionObject3D).get_rid()]
	var r: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {}
	return {"pos": r["position"], "normal": r["normal"], "node": r["collider"], "from": from, "fwd": fwd}


## A press of the ping key: see the class doc. Returns the MapMarks.place result (or {ok, removed / confirm}).
func ping() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	var h: Dictionary = look_hit()
	var res: Dictionary = {}
	if h.is_empty():
		_feedback("Nothing there to mark.")
		return {"ok": false, "reason": "nothing"}
	var node: Node = h.get("node") as Node
	var gl: bool = marks.state.game == "gravelight"
	var c: Dictionary = MarkTargets.classify(node) if gl else {"kind": "go", "sub": "", "label": "", "price": 0, "node": null}
	# a second press on the same door confirms it
	if gl and str(c.get("sub", "")) == "door" and c.get("node") == _door and now - _door_t <= int(float(_pc.get("confirm_s", 3.0)) * 1000.0):
		_door = null
		res = marks.place({"kind": "buy", "pos": (c["node"] as Node3D).global_position, "node": c["node"], "target": "any", "confirmed": true, "label": str(c["label"])})
		_report(res, "Open the %s" % str(c["label"]))
		return res
	# double-tap: the last ping becomes Danger
	if now - _last_t <= int(float(_pc.get("double_tap_s", 0.35)) * 1000.0) and _last_pos != Vector3.INF:
		var at: Vector3 = _last_pos
		if _last_id > 0:
			marks.remove(_last_id, "replaced")
		_last_t = -100000
		_last_id = -1
		res = marks.place({"kind": "danger", "pos": at, "label": _zone(at)})
		_report(res, "Danger")
		return res
	var floor_pos: Vector3 = _floor_point(h)
	# pinging one of your marks takes it off
	var near: Dictionary = marks.nearest(floor_pos, float(_pc.get("remove_m", 1.4)))
	if near.is_empty() and c.get("node") is Node3D:
		near = marks.nearest((c["node"] as Node3D).global_position, float(_pc.get("remove_m", 1.4)))
	if not near.is_empty() and (int(near.get("owner", -1)) == Net.local_player_id() or bool(near.get("order", false))):
		marks.remove(int(near["id"]))
		_last_t = now
		_last_id = -1
		_last_pos = Vector3.INF
		_feedback("Mark removed.")
		return {"ok": true, "removed": true}
	var bots: bool = marks.has_bots()
	var kind: String = MarkTargets.mark_kind(c) if gl else "go"
	var spec: Dictionary = {"kind": kind, "pos": floor_pos, "label": str(c.get("label", ""))}
	if c.get("node") is Node3D:
		spec["node"] = c["node"]
		spec["pos"] = (c["node"] as Node3D).global_position
	match kind:
		"buy":
			if str(c.get("sub", "")) == "door" and bots:
				_door = c["node"]
				_door_t = now
				_last_t = now
				_last_pos = floor_pos
				_last_id = -1
				_feedback("%s  ·  Ping again to have a bot open it" % MarkTargets.door_question(int(c.get("price", 0))))
				return {"ok": false, "confirm": true, "reason": "confirm"}
			spec["target"] = "any" if bots else "me"
		"collect":
			spec["target"] = "any" if bots else "me"
		_:
			spec["kind"] = "go"
			spec["target"] = "me"
			spec["label"] = _zone(floor_pos)
	res = marks.place(spec)
	_last_t = now
	_last_pos = floor_pos
	_last_id = int(res.get("id", -1)) if bool(res.get("ok", false)) else -1
	_report(res, MapMarks.kind_name(str(spec["kind"])))
	return res


## The floor spot under what was hit: a wall or a machine gives the floor in front of it (the navmesh when there is
## one).
func _floor_point(h: Dictionary) -> Vector3:
	var p: Vector3 = h["pos"]
	var n: Vector3 = h.get("normal", Vector3.UP)
	var probe: Vector3 = p + n * 0.6 if n.y < 0.6 else p
	var body: Node3D = marks.state.local_body()
	if body != null and body.is_inside_tree():
		var nav: RID = body.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(nav) > 0:
			var q: Vector3 = NavigationServer3D.map_get_closest_point(nav, probe)
			if q.distance_to(probe) < 3.0:
				return q
		var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.3, probe + Vector3.DOWN * 6.0, 1)
		var r: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(down)
		if not r.is_empty():
			return r["position"]
	return probe


func _zone(p: Vector3) -> String:
	var z: String = marks.state.data.zone_label_at(p)
	return z if z != "" else "Here"


func _report(res: Dictionary, what: String) -> void:
	last_result = res
	if bool(res.get("ok", false)):
		var pid: int = int(res.get("pid", -1))
		var who: String = ""
		if pid > 0:
			who = "  ·  " + ("Jakub" if pid == 9 else Net.display_name(pid))
			var st: String = marks.status_of(pid)
			if st != "":
				who += ": " + st
		_feedback("%s%s%s" % [what, ("  ·  " + str(res.get("label", ""))) if str(res.get("label", "")) != "" and str(res.get("label", "")) != what else "", who])
	else:
		_feedback("Can't mark that: %s" % str(res.get("reason", "")))


func _feedback(text: String) -> void:
	if marks.state.game == "gravelight":
		AudioDirector.play_2d("ui_click", -8.0, 0.0)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud == null and marks.state.level_root != null:
		var h2: Variant = marks.state.level_root.get("hud")
		hud = h2 as Node
	if hud != null and hud.has_method("show_banner"):
		if marks.state.game == "gravelight":
			hud.call("show_banner", text, 1.8)
		else:
			hud.call("show_banner", "MARK", text, 1.8)
