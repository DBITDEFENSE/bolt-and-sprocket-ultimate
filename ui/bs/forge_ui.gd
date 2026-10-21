class_name ForgeUI
extends CanvasLayer
## The Omega Forge screen (BS_WEAPONS §2.3-2.4). One row per owned gun: name (gold when Ω), V-level + XP, mod tiers,
## Signature Mod A / B (install 200 at V3+, swapping is free), and EVOLVE (2,000) with the reason it's not ready.
## While the evolution cutscene plays the panel hides and only SKIP shows (after the first evolution).
## Open with ForgeUI.open(tree, forge). Blocks gameplay input (BS.ui_block) and pauses the world while open
## (the Forge runs PROCESS_MODE_ALWAYS). Text by line id (data/bs/forge.json "lines", via WeaponText).

signal closed

## Tests turn this off so the world keeps ticking.
static var pause_default: bool = true

var forge: OmegaForge
var pause_world: bool = true
var _panel: PanelContainer
var _list: VBoxContainer
var _bolts: Label
var _info: Label
var _skip: Button
var _open: bool = false
var _was_paused: bool = false
var _last_sig: String = ""


static func open(tree: SceneTree, forge_: OmegaForge) -> ForgeUI:
	var ui: ForgeUI = ForgeUI.new()
	ui.forge = forge_
	ui.pause_world = pause_default
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(ui)
	return ui


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	BS.ui_block += 1
	_open = true
	if pause_world:
		_was_paused = get_tree().paused
		get_tree().paused = true
	BSStyle.free_mouse()
	EventBus.interact_prompt.emit("")
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
		if forge != null and forge.playing:
			skip()
		else:
			close()


func mgr() -> WeaponManager:
	return forge.manager() if forge != null else ForgeDebug.manager()


func _process(_dt: float) -> void:
	var playing: bool = forge != null and is_instance_valid(forge) and forge.playing
	_panel.visible = not playing
	_skip.visible = playing and forge.can_skip()
	var sig: String = "%d:%s" % [BS.bolts, str(BS.weapons.hash())]
	if sig != _last_sig and not playing:
		render()


# ------------------------------------------------------------------ build

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", BSStyle.panel(BSStyle.YELLOW, Color(0.05, 0.1, 0.07, 0.96), 22, 4))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1360, 840)
	_panel.position = Vector2(-680, -420)
	add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	v.add_child(head)
	var title: Label = BSStyle.label(WeaponText.text("bs.forge.ui.title"), 40, BSStyle.YELLOW, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_bolts = BSStyle.label("", 30, BSStyle.YELLOW, 8)
	head.add_child(_bolts)
	var plaque: Label = BSStyle.label(WeaponText.text("bs.forge.plaque"), 18, Color("#b08d3a"), 3)
	v.add_child(plaque)
	var req: Label = BSStyle.label(WeaponText.text("bs.forge.ui.req") % int(WeaponData.progression()["omega_price"]), 20, BSStyle.DIM, 3)
	v.add_child(req)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1320, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_info = BSStyle.label("", 20, Color.WHITE, 3)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(1320, 60)
	v.add_child(_info)
	var close_b: Button = BSStyle.button(WeaponText.text("bs.forge.ui.close"), BSStyle.CYAN, 22)
	close_b.pressed.connect(close)
	v.add_child(close_b)
	_skip = BSStyle.button(WeaponText.text("bs.forge.ui.skip"), BSStyle.YELLOW, 24)
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.position = Vector2(-220, -110)
	_skip.pressed.connect(skip)
	_skip.visible = false
	add_child(_skip)


## One row per owned gun, in wheel order.
func render() -> void:
	_last_sig = "%d:%s" % [BS.bolts, str(BS.weapons.hash())]
	_bolts.text = WeaponText.text("bs.forge.ui.bolts") % BS.bolts
	for c: Node in _list.get_children():
		c.queue_free()
	var m: WeaponManager = mgr()
	for id: StringName in WeaponData.ids():
		if not BS.owns(id):
			continue
		_list.add_child(_row(id, m))


func _row(id: StringName, m: WeaponManager) -> Control:
	var st: Dictionary = BS.weapons[String(id)]
	var om: bool = bool(st.get("omega", false))
	var lv: int = int(st.get("level", 1))
	var row: HBoxContainer = HBoxContainer.new()
	row.name = String(id)
	row.add_theme_constant_override("separation", 12)
	var name_l: Label = BSStyle.label(WeaponData.display_name(id, om), 22, BSStyle.YELLOW if om else WeaponData.color(id), 4)
	name_l.custom_minimum_size = Vector2(300, 0)
	row.add_child(name_l)
	row.add_child(BSStyle.label(WeaponText.text("bs.forge.ui.level") % lv, 22, BSStyle.CYAN, 4))
	var mods: Dictionary = st.get("mods", {})
	row.add_child(BSStyle.label(WeaponText.text("bs.forge.ui.mods") % [int(mods.get("dmg", 0)), int(mods.get("rate", 0)), int(mods.get("ammo", 0))], 18, Color.WHITE, 3))
	var sig: int = int(st.get("sig", -1))
	var price: int = 0 if sig >= 0 else int(WeaponData.progression()["sig_price"])
	for choice: int in 2:
		var sd: Dictionary = WeaponData.signature(id, choice)
		var b: Button = BSStyle.button(WeaponText.text("bs.forge.ui.sig_install") % [str(sd.get("name", "?")), price] if sig != choice else "✔ " + str(sd.get("name", "?")),
			BSStyle.GREEN if sig == choice else BSStyle.DIM, 16)
		b.name = "Sig%d" % choice
		b.disabled = lv < int(WeaponData.progression()["sig_unlock_level"]) or sig == choice
		b.tooltip_text = str(sd.get("desc", ""))
		b.pressed.connect(func() -> void: install(id, choice))
		b.mouse_entered.connect(func() -> void: _info.text = "%s: %s" % [str(sd.get("name", "")), str(sd.get("desc", ""))])
		row.add_child(b)
	var why: String = m.can_evolve(id) if m != null else "bs.forge.deny.01"
	var ev: Button = BSStyle.button(WeaponText.text("bs.forge.ui.evolved") if om else WeaponText.text("bs.forge.ui.evolve") % int(WeaponData.progression()["omega_price"]),
		BSStyle.YELLOW if why == "" and not om else BSStyle.DIM, 20)
	ev.name = "Evolve"
	ev.disabled = om
	ev.pressed.connect(func() -> void: evolve(id))
	ev.mouse_entered.connect(func() -> void:
		_info.text = WeaponData.omega_desc(id) if why == "" or om else WeaponText.text(why))
	row.add_child(ev)
	return row


func install(id: StringName, choice: int) -> bool:
	var m: WeaponManager = mgr()
	var ok: bool = m != null and m.install_signature(id, choice)
	if not ok and m != null and int((BS.weapons[String(id)] as Dictionary).get("level", 1)) < int(WeaponData.progression()["sig_unlock_level"]):
		_info.text = WeaponText.text("bs.forge.ui.sig_locked")
	render()
	return ok


## EVOLVE: the Forge speaks the deny line or runs the cutscene. Returns the deny line id ("" on success).
func evolve(id: StringName) -> String:
	if forge == null:
		return "bs.forge.deny.01"
	var why: String = forge.evolve(id)
	if why != "":
		_info.text = WeaponText.text(why)
	render()
	return why


func skip() -> bool:
	return forge != null and forge.skip()
