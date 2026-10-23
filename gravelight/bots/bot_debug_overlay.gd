class_name BotDebugOverlay
extends Node3D
## The AI debug overlay (Update 03 section 9; dev console `ai_debug 1`, `ai_debug heat`, `ai_debug panel`,
## `ai_debug 0`). Above each bot: its current action, its top three action scores, its role, its target; its
## path line (the locomotion layer's debug_path()) and a line to its target. A blackboard panel lists the claimed
## tasks, the known zombies, the route and the roles. The threat heatmap colours the floor round each bot by the
## threat its perception knows of (green calm .. red).

const HEAT_R: int = 8          # cells each way round a bot
const HEAT_CELL: float = 1.0
const REFRESH_S: float = 0.25

var squad: BotSquad
var enabled: bool = false
var heatmap: bool = false
var panel_on: bool = true
var _labels: Dictionary = {}    # pid -> Label3D
var _lines: MeshInstance3D
var _imm: ImmediateMesh
var _heat: MultiMeshInstance3D
var _panel: CanvasLayer
var _panel_label: Label
var _t: float = 0.0


func setup(s: BotSquad) -> void:
	squad = s
	_imm = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _imm
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.no_depth_test = true
	_lines.material_override = lm
	add_child(_lines)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(HEAT_CELL * 0.92, HEAT_CELL * 0.92)
	mm.mesh = quad
	mm.instance_count = (HEAT_R * 2 + 1) * (HEAT_R * 2 + 1) * 4
	mm.visible_instance_count = 0
	_heat = MultiMeshInstance3D.new()
	_heat.multimesh = mm
	var hm: StandardMaterial3D = StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.vertex_color_use_as_albedo = true
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_heat.material_override = hm
	add_child(_heat)
	_panel = CanvasLayer.new()
	_panel.layer = 90
	add_child(_panel)
	_panel_label = Label.new()
	_panel_label.position = Vector2(16, 120)
	_panel_label.add_theme_font_size_override("font_size", 14)
	_panel_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_panel_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_panel_label.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_panel_label)
	set_enabled(false)


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	_panel.visible = on and panel_on
	for l: Variant in _labels.values():
		(l as Label3D).visible = on


func _process(delta: float) -> void:
	if not enabled or squad == null:
		return
	_panel.visible = panel_on
	_panel_label.position.x = 16.0 if Minimap.layout_rect.size.x <= 0.0 or Minimap.layout_rect.position.x > 400.0 else Minimap.layout_rect.end.x + 16.0   # beside the minimap
	_t -= delta
	_draw_lines()
	if _t > 0.0:
		return
	_t = REFRESH_S
	for b: BotBrain in squad.brains:
		if not is_instance_valid(b) or not is_instance_valid(b.player):
			continue
		var l: Label3D = _labels.get(b.player.player_id)
		if l == null:
			l = Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.fixed_size = true
			l.pixel_size = 0.0012
			l.font_size = 26
			l.outline_size = 6
			l.modulate = Color(0.75, 1.0, 0.75)
			add_child(l)
			_labels[b.player.player_id] = l
		l.global_position = b.player.global_position + Vector3.UP * (2.2 + 0.28 * float(b.index % 3))
		l.text = label_text(b)
	if panel_on:
		var lines: PackedStringArray = ["BLACKBOARD (t %.0fs)" % squad.time()]
		lines.append_array(squad.blackboard.describe(squad.time()))
		var ts: Dictionary = squad.think_stats()
		lines.append("brain cost %.3f ms/bot/frame, think %.3f ms" % [float(ts["ms_per_bot_frame"]), float(ts["ms_per_think"])])
		_panel_label.text = "\n".join(lines)
	_update_heat()


## The text over a bot: action, role, target, top three scores.
static func label_text(b: BotBrain) -> String:
	var tops: PackedStringArray = []
	for t: Variant in b.top3:
		tops.append("%s %.2f" % [str((t as Array)[0]), float((t as Array)[1])])
	var tgt: String = "-"
	if b.aim != null and b.aim.target != null and is_instance_valid(b.aim.target):
		tgt = "%s %.0fm%s" % [b.aim.target.enemy_id, b.aim.target.global_position.distance_to(b.player.global_position), " head" if b.aim.aim_head else ""]
	return "%s %s [%s] -> %s  threat %.2f\n%s" % [Net.display_name(b.player.player_id), b.action.to_upper(), b.role if b.role != "" else "-",
		tgt, b.perception.pressure if b.perception != null else 0.0, "  ".join(tops)]


func _draw_lines() -> void:
	_imm.clear_surfaces()
	var any: bool = false
	for b: BotBrain in squad.brains:
		if not is_instance_valid(b) or b.loco == null:
			continue
		var path: PackedVector3Array = b.loco.debug_path()
		if path.size() >= 2:
			if not any:
				_imm.surface_begin(Mesh.PRIMITIVE_LINES)
				any = true
			for i: int in range(1, path.size()):
				_imm.surface_set_color(Color(0.3, 0.8, 1.0))
				_imm.surface_add_vertex(path[i - 1] + Vector3.UP * 0.1)
				_imm.surface_set_color(Color(0.3, 0.8, 1.0))
				_imm.surface_add_vertex(path[i] + Vector3.UP * 0.1)
		if b.aim != null and b.aim.target != null and is_instance_valid(b.aim.target):
			if not any:
				_imm.surface_begin(Mesh.PRIMITIVE_LINES)
				any = true
			_imm.surface_set_color(Color(1.0, 0.35, 0.25))
			_imm.surface_add_vertex(b.aim.eye())
			_imm.surface_set_color(Color(1.0, 0.35, 0.25))
			_imm.surface_add_vertex(b.aim.aim_point(b.aim.target))
	if any:
		_imm.surface_end()


func _update_heat() -> void:
	var mm: MultiMesh = _heat.multimesh
	if not heatmap:
		mm.visible_instance_count = 0
		return
	var n: int = 0
	for b: BotBrain in squad.brains:
		if not is_instance_valid(b) or b.perception == null or b.player.spectating:
			continue
		var c: Vector3 = b.player.global_position
		for ix: int in range(-HEAT_R, HEAT_R + 1):
			for iz: int in range(-HEAT_R, HEAT_R + 1):
				if n >= mm.instance_count:
					break
				var p: Vector3 = Vector3(snappedf(c.x, HEAT_CELL) + ix * HEAT_CELL, c.y + 0.06, snappedf(c.z, HEAT_CELL) + iz * HEAT_CELL)
				var th: float = clampf(b.perception.threat_near(p, 4.0) / 2.0, 0.0, 1.0)
				mm.set_instance_transform(n, Transform3D(Basis(), p))
				mm.set_instance_color(n, Color(th, 1.0 - th, 0.15, 0.12 + 0.4 * th))
				n += 1
	mm.visible_instance_count = n
