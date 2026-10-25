extends CanvasLayer
## Owned perks as bottle caps in a row above the round stamp (bottom-left). Added by PerkManager per match.
## Each cap is drawn by PerkCap.draw_cap (T-082: the tonic's glyph on its crimped cap, the single cap renderer).
## Upgraded tonics (T-075) carry their tier on a brass band under the glyph (II / III; the crimp turns gold at III),
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
	var i: int = 0
	for perk_id: Variant in PerkManager.owned(player_id):
		var cap: BottleCap = BottleCap.new()
		cap.perk_id = StringName(perk_id)
		cap.tier = PerkManager.tier_of(player_id, StringName(perk_id))
		cap.font = _font
		cap.size = Vector2(CAP_SIZE, CAP_SIZE)
		cap.position = Vector2(i * (CAP_SIZE + GAP), 0)
		cap.tooltip_text = PerkManager.tier_name(StringName(perk_id), cap.tier)
		_row.add_child(cap)
		cap.pop()
		i += 1
	_layout()


class BottleCap extends Control:
	var font: Font
	var perk_id: StringName = &""
	var tier: int = 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func pop() -> void:
		pivot_offset = Vector2(27, 27)
		scale = Vector2(1.6, 1.6)
		var tw: Tween = create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		PerkCap.draw_cap(self, size * 0.5, size.x * 0.5, perk_id, false, font, 1.0, tier)

