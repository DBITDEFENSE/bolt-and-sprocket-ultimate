class_name ShopUI
extends CanvasLayer
## Blartz's shop v2 screen (openShop / renderShop / renderTradeIn / shopShowDesc / confettiBurst,
## index.html:12038-12190): tabs, deal of the day, wishlist stars + wish pin, trade-in, purchase confetti,
## Blartz's pitches by line id, item lines in the description. Rules live in ShopLogic.
## Open with ShopUI.open(tree, logic). Blocks gameplay input (BS.ui_block) while open.

signal closed

var logic: ShopLogic
var tab: String = "all"
var _bolts: Label
var _pitch: Label
var _tabs: HBoxContainer
var _deal: Label
var _list: VBoxContainer
var _desc: Label
var _pin: Label
var _fx: Control
var _pitch_t: float = 0.0
var _open: bool = false
var _was_paused: bool = false
## Freeze the world while shopping (the web build's G.state = 'shop'). Tests may turn it off.
var pause_world: bool = true


static func open(tree: SceneTree, logic_: ShopLogic = null) -> ShopUI:
	var ui: ShopUI = ShopUI.new()
	ui.logic = logic_ if logic_ != null else ShopLogic.new(tree)
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(ui)
	return ui


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	if logic == null:
		logic = ShopLogic.new(get_tree())
	logic.tree = get_tree()
	_build()
	logic.pitched.connect(_on_pitched)
	logic.purchased.connect(func(_it: Dictionary) -> void: celebrate(BSStyle.YELLOW))
	logic.sold.connect(func(_id: String, _v: int) -> void: celebrate(BSStyle.GREEN))
	BS.ui_block += 1
	_open = true
	if pause_world:
		_was_paused = get_tree().paused
		get_tree().paused = true
	BSStyle.free_mouse()
	EventBus.interact_prompt.emit("")
	logic.open_visit()
	_pitch_t = float(logic.S["pitch_interval"])
	render()


func _exit_tree() -> void:
	if _open:
		_open = false
		BS.ui_block = maxi(0, BS.ui_block - 1)
		if pause_world:
			get_tree().paused = _was_paused


func close() -> void:
	if not _open:
		return
	_open = false
	BS.ui_block = maxi(0, BS.ui_block - 1)
	if pause_world:
		get_tree().paused = _was_paused
	BSStyle.capture_mouse(get_tree())
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(dt: float) -> void:
	_pitch_t -= dt
	if _pitch_t <= 0.0:
		_pitch_t = float(logic.S["pitch_interval"])
		logic.pitch()


# ------------------------------------------------------------------ build

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BSStyle.panel(BSStyle.GREEN, Color(0.06, 0.09, 0.12, 0.96), 22, 4))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1320, 820)
	panel.position = Vector2(-660, -410)
	add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	v.add_child(head)
	var title: Label = BSStyle.label(BSText.text("html.shopTitle.001"), 40, BSStyle.GREEN, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_bolts = BSStyle.label("", 32, BSStyle.YELLOW, 8)
	head.add_child(_bolts)
	_pitch = BSStyle.label(BSText.text("html.shopPitch.001"), 22, BSStyle.GREEN, 4)
	_pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pitch.custom_minimum_size = Vector2(1280, 56)
	v.add_child(_pitch)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	v.add_child(_tabs)
	_deal = BSStyle.label("", 22, BSStyle.ORANGE, 6)
	v.add_child(_deal)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var dp: PanelContainer = PanelContainer.new()
	dp.add_theme_stylebox_override("panel", BSStyle.panel(BSStyle.CYAN))
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(dp)
	_desc = BSStyle.label(BSText.text("bs.ui.shop.browse"), 20, Color.WHITE, 3)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dp.add_child(_desc)
	var foot: HBoxContainer = HBoxContainer.new()
	v.add_child(foot)
	_pin = BSStyle.label("", 20, BSStyle.YELLOW, 4)
	_pin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_pin)
	var leave: Button = BSStyle.button(BSText.text("html.btnShopClose.001"), BSStyle.PINK)
	leave.name = "Leave"
	leave.pressed.connect(close)
	foot.add_child(leave)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)


# ------------------------------------------------------------------ render

func render() -> void:
	_bolts.text = "%s %d" % [BSText.text("bs.ui.hud.bolts"), BS.bolts]
	for c: Node in _tabs.get_children():
		c.queue_free()
	for t: Array in logic.S["tabs"]:
		var b: Button = BSStyle.button(str(t[1]), BSStyle.CYAN if tab == str(t[0]) else BSStyle.DIM, 20)
		var tid: String = str(t[0])
		b.pressed.connect(func() -> void: set_tab(tid))
		_tabs.add_child(b)
	for c: Node in _list.get_children():
		c.queue_free()
	_deal.text = ""
	if tab == "tradein":
		_render_trade()
	else:
		_render_stock()
	var pin: Dictionary = logic.wish_pin()
	_pin.text = "★ %s : %s %d" % [pin["name"], BSText.text("bs.ui.hud.bolts"), pin["price"]] if not pin.is_empty() else ""
	var first: Control = _first_focusable()
	if first != null and is_inside_tree():
		first.grab_focus.call_deferred()


func set_tab(t: String) -> void:
	tab = t
	render()


func _render_stock() -> void:
	var items: Array[Dictionary] = logic.items_for_tab(tab)
	if tab == "all":
		for it: Dictionary in items:
			if it["deal"]:
				_deal.text = BSText.text("bs.ui.shop.deal") % str(it["name"])
	if tab == "cosmetic":
		_list.add_child(BSStyle.label(BSText.text("bs.ui.shop.style_closed"), 20, BSStyle.DIM, 3))
	for it: Dictionary in items:
		_list.add_child(_row(it))


func _row(it: Dictionary) -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var txt: String = str(it["name"])
	if it["max_tier"] > 0:
		var shown: int = int(it["tier"]) if it["kind"] == "mallet" else int(it["tier"])
		txt += "   " + "★".repeat(shown) + "☆".repeat(maxi(0, int(it["max_tier"]) - shown))
	var price: String
	if not it["available"]:
		price = BSText.text("bs.ui.shop.coming_soon")
	elif it["maxed"]:
		price = "MAX"
	elif it["deal"]:
		price = "-25%%  %d → %d" % [it["was"], it["price"]]
	else:
		price = str(it["price"])
	var b: Button = BSStyle.button("%s      %s" % [txt, price], BSStyle.ORANGE if it["deal"] else BSStyle.YELLOW, 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not it["available"]
	b.set_meta(&"item_id", it["id"])
	var id: String = it["id"]
	b.pressed.connect(func() -> void: buy(id))
	b.focus_entered.connect(func() -> void: _show_desc(id))
	b.mouse_entered.connect(func() -> void: _show_desc(id))
	h.add_child(b)
	if not it["maxed"] and it["available"]:
		var star: Button = BSStyle.button("★" if logic.is_wished(id) else "☆", BSStyle.YELLOW, 22)
		star.pressed.connect(func() -> void:
			logic.toggle_wish(id)
			render())
		h.add_child(star)
	return h


func _render_trade() -> void:
	_list.add_child(BSStyle.label(BSText.text("misc.renderTradeIn.01"), 18, BSStyle.DIM, 3))
	var rows: Array[Dictionary] = logic.trade_in_list()
	if rows.is_empty():
		_list.add_child(BSStyle.label(BSText.text("misc.renderTradeIn.02"), 18, Color(0.48, 0.53, 0.6), 3))
	for r: Dictionary in rows:
		var b: Button = BSStyle.button("%s      +%d" % [r["name"], r["value"]], BSStyle.GREEN, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id: String = r["id"]
		b.pressed.connect(func() -> void:
			logic.sell(id)
			render())
		_list.add_child(b)


func _show_desc(item_id: String) -> void:
	var it: Dictionary = logic.find(item_id)
	if it.is_empty():
		_desc.text = BSText.text("bs.ui.shop.browse")
		return
	var t: String = "%s\n\n%s" % [it["name"], logic.describe(it)]
	var il: String = ShopLogic.item_line(str(it["kind"]))
	if il != "" and it["available"]:
		t += "\n\nBlartz: " + BSText.text(il)
	_desc.text = t


func buy(item_id: String) -> Dictionary:
	var r: Dictionary = logic.buy(item_id)
	render()
	return r


func _on_pitched(line_id: String) -> void:
	_pitch.text = BSText.text(line_id)
	_pitch_t = float(logic.S["pitch_interval"])


func _first_focusable() -> Control:
	for row: Node in _list.get_children():
		if row is Button and not (row as Button).disabled:
			return row as Control
		for c: Node in row.get_children():
			if c is Button and not (c as Button).disabled:
				return c as Control
	return _tabs.get_child(0) as Control if _tabs.get_child_count() > 0 else null


## Purchase celebration: confetti burst from the middle of the screen + Sprocket cheers.
func celebrate(hint: Color) -> void:
	get_tree().call_group(&"sprocket", &"set_mood", &"happy", 3.0)
	var cols: Array[Color] = [BSStyle.YELLOW, BSStyle.CYAN, BSStyle.PINK, Color("#9dff5a"), hint]
	var vp: Vector2 = Vector2(1920, 1080)
	for i: int in 16:
		var c: ColorRect = ColorRect.new()
		c.color = cols[i % cols.size()]
		c.size = Vector2(12, 18)
		c.position = vp * Vector2(0.5, 0.42)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(c)
		var tw: Tween = c.create_tween()
		tw.set_parallel(true)
		tw.tween_property(c, "position", c.position + Vector2(randf_range(-260, 260), randf_range(-160, 220)), 0.9).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation", randf_range(-6.0, 6.0), 0.9)
		tw.tween_property(c, "modulate:a", 0.0, 0.9)
		tw.chain().tween_callback(c.queue_free)
