class_name BotCommandWheel
extends CanvasLayer
## The squad command wheel (U02 section 5): hold `bot_command` (default T / D-pad down) to open a radial menu of
## orders, steer with the mouse (look deltas: the mouse stays captured and the camera stops turning while the
## wheel is open) or the right stick, release to give the order to every bot (BotSquad.set_command):
## Follow me (top) / Hold here (right) / Repair barricades (bottom) / Revive priority (left). Releasing in the
## middle cancels. "Hold here" holds the spot under the crosshair (up to commands.hold_point_range_m away, on the
## navmesh), or the human's feet. The game isn't paused and nothing else is blocked: you can still move and shoot.

## True while the wheel is open (Player._pad_look leaves the stick to it).
static var capturing: bool = false

const MASK_POINT: int = 1 | (1 << 8)

var squad: BotSquad = null
var state: BotCommandState
var _canvas: Wheel
var _ccfg: Dictionary = {}


func _init() -> void:
	layer = 12


func setup(s: BotSquad) -> void:
	squad = s
	_ccfg = BotConfig.cfg().get("commands", {})
	state = BotCommandState.new(float(_ccfg.get("wheel_radius_px", 120.0)), float(_ccfg.get("wheel_deadzone_px", 28.0)), BotConfig.order_ids(BotConfig.cfg()))
	_canvas = Wheel.new()
	_canvas.wheel = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	_canvas.font = f
	add_child(_canvas)
	_canvas.hide()


func _exit_tree() -> void:
	capturing = false


func _can_open() -> bool:
	var h: Player = squad.human() if squad != null else null
	return GameState.phase == GameState.Phase.PLAYING and not GameState.input_blocked and not get_tree().paused \
		and h != null and not h.spectating and not squad.brains.is_empty()


func _input(event: InputEvent) -> void:
	if squad == null or not InputMap.has_action(&"bot_command"):
		return
	if event.is_action_pressed(&"bot_command", false, true):
		if _can_open():
			open()
		return
	if not state.is_open:
		return
	if event.is_action_released(&"bot_command", true):
		confirm()
		return
	if event is InputEventMouseMotion:
		state.look((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()   # the camera doesn't turn while picking an order


func _process(_delta: float) -> void:
	if not state.is_open:
		return
	if not _can_open():
		close()
		return
	var v: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.2) if InputMap.has_action(&"look_left") else Vector2.ZERO
	state.stick(v)
	_canvas.queue_redraw()


func open() -> void:
	state.press()
	capturing = true
	_canvas.show()
	_canvas.queue_redraw()
	AudioDirector.play_2d("ui_click", -8.0, 0.0)


func close() -> void:
	state.cancel()
	capturing = false
	_canvas.hide()


## Gives the order under the pointer (none from the middle).
func confirm() -> void:
	var cmd: StringName = state.release()
	capturing = false
	_canvas.hide()
	if cmd == &"":
		return
	AudioDirector.play_2d("ui_confirm", -6.0, 0.0)
	squad.set_command(cmd, point_target() if cmd == &"hold" else Vector3.INF)


## The navmesh spot under the crosshair within hold_point_range_m, else the human's feet.
func point_target() -> Vector3:
	var h: Player = squad.human()
	if h == null:
		return Vector3.INF
	var cam: Camera3D = h.camera
	var nav: RID = h.get_world_3d().navigation_map
	if cam != null:
		var from: Vector3 = cam.global_position
		var to: Vector3 = from - cam.global_basis.z * float(_ccfg.get("hold_point_range_m", 20.0))
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_POINT, [h.get_rid()])
		var r: Dictionary = h.get_world_3d().direct_space_state.intersect_ray(q)
		var hit: Vector3 = r["position"] if not r.is_empty() else to
		var back: Vector3 = hit + (from - hit).normalized() * 0.6
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, back)
		if p.distance_to(back) < 2.5:
			return p
	return NavigationServer3D.map_get_closest_point(nav, h.global_position)


class Wheel extends Control:
	var wheel: BotCommandWheel
	var font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if wheel == null or wheel.state == null:
			return
		var c: Vector2 = get_viewport_rect().size * 0.5
		var r: float = 175.0
		var sel: int = wheel.state.selected()
		var n: int = wheel.state.order_list.size()
		draw_circle(c, r + 8.0, Color(0.04, 0.03, 0.02, 0.62))
		for i: int in n:
			var a0: float = -PI * 0.5 + TAU * (float(i) - 0.5) / float(n)
			var a1: float = a0 + TAU / float(n)
			var pts: PackedVector2Array = [c + Vector2(cos(a0), sin(a0)) * 42.0]
			for k: int in 13:
				var a: float = lerpf(a0, a1, float(k) / 12.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			for k2: int in range(12, -1, -1):
				var a2: float = lerpf(a0, a1, float(k2) / 12.0)
				pts.append(c + Vector2(cos(a2), sin(a2)) * 42.0)
			var cmd: StringName = wheel.state.order_list[i]
			var current: bool = wheel.squad != null and wheel.squad.command == cmd
			var fill: Color = Color(0.62, 0.12, 0.09, 0.85) if i == sel else (Color(0.3, 0.26, 0.17, 0.55) if current else Color(0.16, 0.14, 0.11, 0.55))
			draw_colored_polygon(pts, fill)
			var mid: float = (a0 + a1) * 0.5
			draw_line(c + Vector2(cos(a0), sin(a0)) * 42.0, c + Vector2(cos(a0), sin(a0)) * r, Color(0.93, 0.89, 0.8, 0.35), 1.5)
			if font != null:
				var label: String = BotConfig.order_label(BotConfig.cfg(), cmd).to_upper()
				var fs: int = 17
				var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var lp: Vector2 = c + Vector2(cos(mid), sin(mid)) * (r * 0.66) + Vector2(-w * 0.5, fs * 0.35)
				if absf(cos(mid)) > 0.7:   # left / right segments: keep the label clear of the hub
					lp.x = c.x + 54.0 if cos(mid) > 0.0 else c.x - 54.0 - w
				draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
				draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.93, 0.8) if i == sel else Color(0.93, 0.89, 0.8, 0.9))
				if current:
					var tag: String = "(current)"
					var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
					draw_string(font, lp + Vector2(w * 0.5 - tw * 0.5, 16.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.86, 0.55, 0.9))
		draw_arc(c, r, 0.0, TAU, 64, Color(0.93, 0.89, 0.8, 0.5), 2.0)
		draw_arc(c, 42.0, 0.0, TAU, 32, Color(0.93, 0.89, 0.8, 0.5), 2.0)
		if font != null:
			var t: String = "SQUAD"
			var tw2: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, c + Vector2(-tw2 * 0.5, 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.93, 0.89, 0.8, 0.8))
		var pv: Vector2 = wheel.state.pointer / maxf(1.0, wheel.state.radius) * (r - 12.0)
		draw_circle(c + pv, 6.0, Color(0.95, 0.86, 0.55, 0.95))
