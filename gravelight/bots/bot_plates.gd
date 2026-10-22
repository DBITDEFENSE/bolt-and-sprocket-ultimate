class_name BotPlates
extends CanvasLayer
## Bot nameplates (U02 section 5): a small plate over each AI teammate, drawn in screen space so it stays the
## same size at any distance: the name in the survivor's colour, a row of bottle caps (the bonus perk ringed in
## gold with a star), and a health bar (a red bleed-out bar while down). Hidden behind walls: each plate's line
## of sight from the camera is re-checked a few times a second (one ray per bot, staggered) and the plate fades
## out and in. Beyond max_distance_m it fades away too. Added by BotSquad; companions get one the same way.

const OCCLUDE_HZ: float = 6.0
const MAX_DISTANCE_M: float = 60.0
const MASK_LOS: int = 1 | (1 << 8)   # world | doors (BotBrain.MASK_LOS)
const PLATE_W: float = 112.0

var squad: BotSquad = null
var _canvas: Plates
var _vis: Dictionary = {}      # pid -> visible target (bool)
var _alpha: Dictionary = {}    # pid -> current alpha
var _t: float = 0.0
var _next: int = 0


func _init() -> void:
	layer = 10


func setup(s: BotSquad) -> void:
	squad = s
	_canvas = Plates.new()
	_canvas.owner_layer = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Courier New", "Consolas", "Monospace"])
	f.font_weight = 700
	_canvas.font = f
	var f2: SystemFont = SystemFont.new()
	f2.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	_canvas.cap_font = f2
	add_child(_canvas)


func _process(delta: float) -> void:
	if squad == null:
		return
	visible = GameState.phase != GameState.Phase.MENU
	_t += delta
	var brains: Array[BotBrain] = squad.brains
	if brains.is_empty():
		return
	# occlusion: one bot per tick, OCCLUDE_HZ ticks per bot per second
	if _t >= 1.0 / (OCCLUDE_HZ * float(brains.size())):
		_t = 0.0
		_next = (_next + 1) % brains.size()
		var b: BotBrain = brains[_next]
		if is_instance_valid(b) and is_instance_valid(b.player):
			_vis[b.player.player_id] = _sees(b.player)
	for b2: BotBrain in brains:
		if not is_instance_valid(b2) or not is_instance_valid(b2.player):
			continue
		var pid: int = b2.player.player_id
		var want: float = 1.0 if bool(_vis.get(pid, true)) and not b2.player.spectating else 0.0
		_alpha[pid] = move_toward(float(_alpha.get(pid, 0.0)), want, delta * 5.0)
	_canvas.queue_redraw()


## Line of sight from the camera to the plate's anchor (nothing solid in between) and within range.
func _sees(p: Player) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not p.is_inside_tree():
		return false
	var to: Vector3 = anchor_of(p)
	if cam.global_position.distance_to(to) > MAX_DISTANCE_M:
		return false
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var ex: Array[RID] = [p.get_rid()]
	var h: Player = squad.human()
	if h != null:
		ex.append(h.get_rid())
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam.global_position, to, MASK_LOS, ex)
	return space.intersect_ray(q).is_empty()


## Where the plate hangs: over the head, lower while down.
static func anchor_of(p: Player) -> Vector3:
	return p.global_position + Vector3.UP * (0.95 if p.downed else 2.12)


func alpha_of(pid: int) -> float:
	return float(_alpha.get(pid, 0.0))


## Tests / screenshots: plates visible right away (skips the fade and the first occlusion tick).
func refresh_now() -> void:
	for b: BotBrain in squad.brains:
		_vis[b.player.player_id] = _sees(b.player)
		_alpha[b.player.player_id] = 1.0 if bool(_vis[b.player.player_id]) else 0.0
	_canvas.queue_redraw()


class Plates extends Control:
	var owner_layer: BotPlates
	var font: Font
	var cap_font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null or owner_layer == null or owner_layer.squad == null:
			return
		for b: BotBrain in owner_layer.squad.brains:
			if not is_instance_valid(b) or not is_instance_valid(b.player):
				continue
			var p: Player = b.player
			var a: float = owner_layer.alpha_of(p.player_id)
			if a <= 0.01:
				continue
			var world: Vector3 = BotPlates.anchor_of(p)
			if cam.is_position_behind(world):
				continue
			var d: float = cam.global_position.distance_to(world)
			a *= clampf((BotPlates.MAX_DISTANCE_M - d) / 8.0, 0.0, 1.0)
			if a <= 0.01:
				continue
			_plate(p, cam.unproject_position(world), a)

	func _plate(p: Player, at: Vector2, a: float) -> void:
		var pid: int = p.player_id
		var w: float = BotPlates.PLATE_W
		var name_s: String = Net.display_name(pid)
		var col: Color = Net.player_color(pid)
		var perks: Array = PerkManager.owned(pid)
		var cap_r: float = 8.0
		var top: float = at.y - 40.0
		# backing
		draw_rect(Rect2(at.x - w * 0.5, top, w, 38.0), Color(0.05, 0.04, 0.03, 0.55 * a))
		draw_rect(Rect2(at.x - w * 0.5, top, 2.0, 38.0), Color(col, 0.9 * a))
		# name
		var fs: int = 13
		var nw: float = font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 0.0
		if font != null:
			draw_string_outline(font, Vector2(at.x - nw * 0.5, top + 13.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8 * a))
			draw_string(font, Vector2(at.x - nw * 0.5, top + 13.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lightened(0.25), a))
		# bottle caps, the bonus perk first
		var order: Array = []
		var bonus: StringName = PerkManager.bonus_perk(pid)
		if bonus != &"" and perks.has(bonus):
			order.append(bonus)
		for pk: Variant in perks:
			if StringName(pk) != bonus:
				order.append(StringName(pk))
		var n: int = order.size()
		var gap: float = cap_r * 2.0 + 3.0
		var x0: float = at.x - (float(n - 1) * gap) * 0.5
		for i: int in n:
			PerkCap.draw_cap(self, Vector2(x0 + float(i) * gap, top + 24.0), cap_r, order[i], order[i] == bonus, cap_font, a)
		# health / bleed-out bar
		var bar: Rect2 = Rect2(at.x - w * 0.5 + 6.0, top + 33.0, w - 12.0, 3.5)
		draw_rect(bar, Color(0, 0, 0, 0.7 * a))
		var frac: float = clampf(p.health_fraction(), 0.0, 1.0)
		var bcol: Color = Color(0.45, 0.78, 0.36, a) if frac > 0.5 else (Color(0.92, 0.72, 0.25, a) if frac > 0.25 else Color(0.9, 0.25, 0.18, a))
		var s: NetMatch = Net.session
		if p.downed and s != null and s.coop.is_downed(pid):
			var total: float = p.bleedout_seconds if p.bleedout_seconds > 0.0 else float(GLData.table("player")["bleedout_seconds"])
			frac = clampf(s.coop.bleed_left(pid) / maxf(1.0, total), 0.0, 1.0)
			bcol = Color(0.85, 0.12, 0.1, a)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), bcol)
