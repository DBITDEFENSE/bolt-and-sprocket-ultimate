class_name MoonSuitHud
extends CanvasLayer
## Mondlicht's suit overlay for the local player (UPDATE 10 §3 Act IV, T-158; presentation only, hud.gd untouched):
##   · FROST: on the terminator's night side in vacuum the visor frosts at the edges (weaker once the heaters run)
##     and a HEATER STRAIN line sits under the AIR gauge (the extra drain shows on the gauge itself);
##   · GLARE: on the day side of the open yard, facing the low Sun, a white veil blinds you unless the VISOR is down;
##   · the VISOR: the `visor` action (H by default) toggles a gold sun visor; down, the glare is gone but the night
##     side reads darker through it. Its state shows while you are in vacuum;
##   · SENT TO ORBIT: the count of zombies the Lodestone threw off the Moon (MoonLowG.orbit_count).
## Pure rule (tests): `frost_for`.

var player: Player = null
var visor_down: bool = false
var frost: float = 0.0
var glare: float = 0.0
var _frost_rect: TextureRect
var _glare_rect: ColorRect
var _visor_rect: ColorRect
var _state: Label
var _orbit: Label
var _t: float = 0.0
var _hint_said: bool = false


static func frost_for(night: bool, in_vacuum: bool, heaters: bool) -> float:
	if not night or not in_vacuum:
		return 0.0
	return 0.3 if heaters else 0.7


func _ready() -> void:
	layer = 5
	name = "MoonSuitHud"
	add_to_group(&"moon_suit_hud")
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_frost_rect = TextureRect.new()
	_frost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost_rect.stretch_mode = TextureRect.STRETCH_SCALE
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.85, 0.93, 1.0, 0.0))
	g.set_color(1, Color(0.9, 0.96, 1.0, 0.95))
	g.add_point(0.55, Color(0.8, 0.9, 1.0, 0.0))
	g.add_point(0.8, Color(0.82, 0.92, 1.0, 0.45))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 256
	_frost_rect.texture = gt
	_frost_rect.modulate.a = 0.0
	root.add_child(_frost_rect)
	_visor_rect = ColorRect.new()
	_visor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visor_rect.color = Color(0.55, 0.38, 0.08, 0.0)
	root.add_child(_visor_rect)
	_glare_rect = ColorRect.new()
	_glare_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glare_rect.color = Color(1.0, 0.98, 0.94, 0.0)
	var cm: CanvasItemMaterial = CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glare_rect.material = cm
	root.add_child(_glare_rect)
	_state = _label(root, 0.5, 64, Color(0.78, 0.88, 1.0))
	_orbit = _label(root, 1.0, 150, Color(0.85, 0.62, 1.0))
	_orbit.offset_left = -330
	_orbit.offset_right = -24
	_orbit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _label(root: Control, anchor_x: float, top: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", MenuKit.stamp_font())
	l.add_theme_font_size_override("font_size", MenuKit.size("hud_nade"))
	l.add_theme_color_override("font_color", col)
	MenuKit.outline(l, "stamp")
	l.anchor_left = anchor_x
	l.anchor_right = anchor_x
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = top
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func set_visor(down: bool) -> void:
	if visor_down == down:
		return
	visor_down = down
	AudioDirector.play_2d("m4d_visor", -6.0, 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(&"visor") and event.is_action_pressed(&"visor") and player != null and not GameState.input_blocked:
		set_visor(not visor_down)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		var map: Node = get_tree().current_scene
		player = map.get("player") as Player if map != null else null
		if player == null:
			return
	var term: Terminator = get_tree().get_first_node_in_group(&"terminator") as Terminator
	var night: bool = term != null and term.night_at(player.global_position)
	var heaters: bool = term != null and term.heaters_on
	var vac: bool = player.in_vacuum
	frost = move_toward(frost, frost_for(night, vac, heaters), delta * 0.4)
	_frost_rect.modulate.a = frost
	var want_glare: float = 0.0
	var cam: Camera3D = get_viewport().get_camera_3d()
	if term != null and cam != null:
		var fwd: Vector3 = -cam.global_transform.basis.z
		var open: bool = ZoneVolume.vacuum_at(get_tree(), player.global_position)
		want_glare = Terminator.glare_for(not night, open, fwd.dot(term.sun_dir()), visor_down, float(term.cfg.get("glare_from_dot", 0.35)))
		want_glare *= float(term.cfg.get("glare_max", 0.82))
	glare = move_toward(glare, want_glare, delta * (3.0 if want_glare > glare else 1.5))
	_glare_rect.color.a = glare
	var tint: float = 0.0
	if visor_down and vac:
		tint = 0.34 if night else 0.16
	_visor_rect.color.a = move_toward(_visor_rect.color.a, tint, delta * 2.0)
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.2
	var key: String = Interactable.prompt_key(&"visor") if InputMap.has_action(&"visor") else "H"
	var lines: PackedStringArray = []
	if vac:
		lines.append("VISOR %s  [%s]" % ["DOWN" if visor_down else "UP", key])
		if night:
			lines.append("HEATER STRAIN" if not heaters else "HEATER ON")
	_state.text = "\n".join(lines)
	if vac and glare > 0.3 and not _hint_said and Net.is_authority():
		_hint_said = true
		var g: Node = get_tree().get_first_node_in_group(&"mondlicht_controller")
		if g != null and g.has_method("glare_hint"):
			g.call("glare_hint")
	var lg: Node = get_tree().get_first_node_in_group(&"moon_lowg")
	var n: int = int(lg.get("orbit_count")) if lg != null else 0
	_orbit.text = "SENT TO ORBIT  %d" % n if n > 0 else ""
