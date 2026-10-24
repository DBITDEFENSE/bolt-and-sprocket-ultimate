extends CanvasLayer
## Owned perks as bottle caps in a row above the round stamp (bottom-left). Added by PerkManager per match.
## Upgraded tonics (T-075) carry their tier on a brass band under the letters (II / III; the crimp turns gold at III),
## and a cap pops when one of its tier effects fires (PerkManager.perk_proc).

const CAP_SIZE: float = 54.0
const GAP: float = 10.0

var player_id: int = 1
var _row: Control
var _font: SystemFont


func _init() -> void:
	layer = 11


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	GLBus.perks_changed.connect(_on_perks_changed)
	PerkManager.perk_proc.connect(_on_perk_proc)
	get_viewport().size_changed.connect(_layout)
	_rebuild()


func _on_perks_changed(pid: int) -> void:
	if pid == player_id:
		_rebuild()


func _on_perk_proc(pid: int, perk_id: StringName, _effect: StringName) -> void:
	if pid != player_id:
		return
	for c: Node in _row.get_children():
		if c is BottleCap and (c as BottleCap).perk_id == perk_id and not c.is_queued_for_deletion():
			(c as BottleCap).pop()


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_row.position = Vector2(60, vp.y - 230)


func _rebuild() -> void:
	for c: Node in _row.get_children():
		c.queue_free()
	var perks: Dictionary = GLData.table("perks")["perks"]
	var i: int = 0
	for perk_id: Variant in PerkManager.owned(player_id):
		var d: Dictionary = perks.get(String(perk_id), {})
		var cap: BottleCap = BottleCap.new()
		cap.color = Color(str(d.get("color", "#c0a040")))
		cap.abbr = str(d.get("abbr", "??"))
		cap.perk_id = StringName(perk_id)
		cap.tier = PerkManager.tier_of(player_id, StringName(perk_id))
		cap.mark = PerkManager.tier_mark(cap.tier)
		cap.font = _font
		cap.size = Vector2(CAP_SIZE, CAP_SIZE)
		cap.position = Vector2(i * (CAP_SIZE + GAP), 0)
		cap.tooltip_text = PerkManager.tier_name(StringName(perk_id), cap.tier)
		_row.add_child(cap)
		cap.pop()
		i += 1
	_layout()


class BottleCap extends Control:
	var color: Color = Color.GOLD
	var abbr: String = ""
	var font: Font
	var perk_id: StringName = &""
	var tier: int = 1
	var mark: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func pop() -> void:
		pivot_offset = Vector2(27, 27)
		scale = Vector2(1.6, 1.6)
		var tw: Tween = create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.5
		# crimped edge: a ring of small teeth
		var teeth: PackedVector2Array = []
		for i: int in 42:
			var a: float = TAU * float(i) / 42.0
			var rr: float = r if i % 2 == 0 else r - 3.0
			teeth.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(teeth, Color(0.86, 0.68, 0.26) if tier >= 3 else color.darkened(0.35))
		draw_circle(c, r - 4.0, color)
		draw_arc(c, r - 9.0, 0.0, TAU, 32, color.lightened(0.35), 2.0)
		if font != null:
			var fs: int = 20
			var w: float = font.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var up: float = 5.0 if mark != "" else 0.0
			draw_string(font, c + Vector2(-w * 0.5, fs * 0.36 - up), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(0.08, 0.06, 0.05) if color.get_luminance() > 0.45 else Color(0.95, 0.92, 0.85))
			if mark != "":
				# the tier band: a brass strip across the lower cap with the Roman numeral
				var band: Rect2 = Rect2(c + Vector2(-r * 0.62, r * 0.28), Vector2(r * 1.24, 12.0))
				draw_rect(band, Color(0.78, 0.62, 0.26) if tier < 3 else Color(1.0, 0.84, 0.36))
				draw_rect(band, Color(0.25, 0.17, 0.06), false, 1.0)
				var ms: int = 11
				var mw: float = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
				draw_string(font, Vector2(c.x - mw * 0.5, band.position.y + 10.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, ms, Color(0.12, 0.08, 0.03))

