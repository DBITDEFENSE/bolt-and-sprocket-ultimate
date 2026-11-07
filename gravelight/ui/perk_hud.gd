extends CanvasLayer
## Owned perks as bottle caps in a row above the round stamp (bottom-left). Added by PerkManager per match.
## Each cap is drawn by PerkCap.draw_cap (T-082: the tonic's glyph on its crimped cap, the single cap renderer).
## Upgraded tonics (T-075) carry their tier on a brass band under the glyph (II / III; the crimp turns gold at III),
## and a cap pops when one of its tier effects fires (PerkManager.perk_proc). T-096: the row sits on the HUD grid
## (ui.json hud: margin, perk_cap, perk_gap, perk_row_gap over the stamp) with a soft shadow under each cap.
## T-183 (the owner: "the perk circles on the screen are a little bit too big"): perk_cap 54 -> 40 px at 1080p, the
## gap 10 -> 8 (six caps: 364 -> 280 px wide); the tier band's numeral still shows (it needs a 30 px cap).

var player_id: int = 1
var _row: Control
var _font: Font
var _cap_size: float = 40.0
var _gap: float = 8.0


func _init() -> void:
	layer = 11


func _ready() -> void:
	_font = MenuKit.stamp_font()
	_cap_size = float(MenuKit.hud("perk_cap", 40.0))
	_gap = float(MenuKit.hud("perk_gap", 8.0))
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(_row)
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


## The row's top-left: the HUD margin from the left, above the round stamp (stamp height ~ the stamp size x 1.3
## plus its border) by perk_row_gap.
func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var m: Vector2 = MenuKit.hud_margin(vp)
	var stamp_h: float = float(MenuKit.size("hud_stamp")) * 1.3 + float(MenuKit.hud("stamp_border", 5)) * 2.0 + 8.0
	_row.position = Vector2(m.x + 2.0, vp.y - m.y - stamp_h - float(MenuKit.hud("perk_row_gap", 14.0)) - _cap_size)


func _rebuild() -> void:
	for c: Node in _row.get_children():
		c.queue_free()
	var i: int = 0
	for perk_id: Variant in PerkManager.owned(player_id):
		var cap: BottleCap = BottleCap.new()
		cap.perk_id = StringName(perk_id)
		cap.tier = PerkManager.tier_of(player_id, StringName(perk_id))
		cap.sealed = PerkManager.is_sealed(player_id, StringName(perk_id))
		cap.font = _font
		cap.size = Vector2(_cap_size, _cap_size)
		cap.position = Vector2(i * (_cap_size + _gap), 0)
		cap.tooltip_text = PerkManager.tier_name(StringName(perk_id), cap.tier)
		_row.add_child(cap)
		cap.pop()
		i += 1
	_layout()


class BottleCap extends Control:
	var font: Font
	var perk_id: StringName = &""
	var tier: int = 1
	var sealed: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func pop() -> void:
		pivot_offset = size * 0.5
		scale = Vector2(1.6, 1.6)
		var tw: Tween = create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var r: float = size.x * 0.5
		draw_circle(size * 0.5 + Vector2(1.5, 3.0), r + 1.0, Color(0, 0, 0, 0.45))   # the drop shadow (snow)
		# the gold ring: a tonic kept through a down (a tonic bottle's measure, T-121), as on a bot's bonus perk
		PerkCap.draw_cap(self, size * 0.5, r, perk_id, sealed, font, 1.0, tier)
