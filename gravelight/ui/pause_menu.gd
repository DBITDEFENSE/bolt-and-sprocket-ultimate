class_name PauseMenu
extends CanvasLayer
## Esc / Start pauses the match. A tabbed page (T-040, tabs since Update 04 / T-066): MAP · OBJECTIVES · LOADOUT ·
## SETTINGS · QUIT, opening on MAP every time. Q / E or LB / RB switch tabs (not while typing in a text field).
##   MAP         a host slot for the pause map (Update 04 section 3): set_map_view(control), or a PauseMapView
##               class when one exists; until then a placeholder with the map, round, power and open areas.
##   OBJECTIVES  the quest log (ObjectivesView over ObjectiveLog; section 4): current objective, easter egg, side
##               quests, challenges, intel, with the spoiler setting. Selecting an entry highlights it on the MAP
##               tab (location_requested + the view's highlight_location) and offers Assign to bot.
##   LOADOUT     guns (with attachments when the weapon has them), knife, grenades, tactical, perks, Scrip, squad.
##   SETTINGS    the quick sliders, and the full tabbed MenuSettings (the main menu's) over the page.
##   QUIT        Restart / Quit (co-op: Back to lobby, End the game, Leave), each behind a confirmation.
## Solo freezes the game while it is open; co-op keeps the world running (only your input stops); Restart is the
## host's, and quitting leaves the game (the host leaving ends it for everyone).

signal quit_requested
signal restart_requested
## The tab now showing (an entry of TABS).
signal tab_changed(tab: String)
## An OBJECTIVES entry was selected (ObjectiveLog entry dictionary).
signal objective_selected(entry: Dictionary)
## "Show this on the map": the map builders' views listen (or implement highlight_location). floor_id is "" unless
## the data names one: the view picks the floor from the height.
signal location_requested(world_pos: Vector3, floor_id: StringName, label: String)

const TABS: PackedStringArray = ["MAP", "OBJECTIVES", "LOADOUT", "SETTINGS", "QUIT"]
const TAB_MAP: int = 0
const TAB_OBJECTIVES: int = 1
const TAB_LOADOUT: int = 2
const TAB_SETTINGS: int = 3
const TAB_QUIT: int = 4
const TIPS: PackedStringArray = [
	"Sprint + CROUCH slides. Crouch again to cancel, JUMP out of it to slide-jump.",
	"Hold USE at a wall gun you already own to buy ammo.",
	"The Crucible forges a gun three times: V, VV and VVV.",
	"Perk slots are capped at six (four under Classic Rules): pick the ones that fit the map.",
	"Rebuilt boards pay Scrip. Early rounds are for building.",
	"A thrown knife and a grenade both count as 'something between you and the pack'.",
]

var current_tab: int = TAB_MAP

var _root: Control
var _card: Label
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _buttons: Array[Button] = []      # the focusable action buttons (Resume first)
var _settings: MenuScreen = null      # the full Settings page, or the Archive, over the pause page
var _confirm: PanelContainer = null
var _sens: HSlider
var _fov: HSlider
var _tip: Label
var _tip_t: float = 0.0
# MAP
var _map_slot: Control
var _map_view: Control = null
var _map_placeholder: Control = null
var _map_info: Label
var _map_mark: Label
var _map_default_tried: bool = false
# OBJECTIVES
var _objectives: ObjectivesView
var _obj_data: Dictionary = {}
var _obj_dirty: bool = true
var _intel_start: Array = []
var _intel_seen: Array = []
# LOADOUT
var _loadout: VBoxContainer


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_obj_data = ObjectiveLog.load_data()
	_intel_start = (ProfileSave.profile.get("intel", []) as Array).duplicate()
	GLBus.intel_found.connect(func(id: StringName) -> void:
		if not _intel_seen.has(String(id)):
			_intel_seen.append(String(id))
		_obj_dirty = true)
	GLBus.quest_step_completed.connect(func(_q: StringName, _s: StringName) -> void: _on_world_changed())
	GLBus.quest_completed.connect(func(_q: StringName) -> void: _on_world_changed())
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	MenuKit.apply_theme(_root)
	add_child(_root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side2: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side2, 26)
	_root.add_child(margin)
	MenuKit.keep_centred(margin, 40.0)   # T-100: centred on ultrawide
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	# header: PAUSED, the tabs, the match card, Resume
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	head.add_child(MenuKit.wordmark(46.0))   # T-144: the menus' masthead
	head.add_child(MenuKit.label("PAUSED", 38, MenuKit.PAPER, true))
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tabs)
	for i: int in TABS.size():
		var tb: Button = MenuKit.button(TABS[i], set_tab.bind(i), 20)
		tb.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 3))
		tb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.custom_minimum_size = Vector2(132, 42)
		tb.toggle_mode = true
		tabs.add_child(tb)
		_tab_buttons.append(tb)
	_card = MenuKit.label("", 16, MenuKit.GOLD)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_card)
	var resume: Button = MenuKit.button("Resume", toggle, 20)
	resume.alignment = HORIZONTAL_ALIGNMENT_CENTER
	resume.custom_minimum_size = Vector2(130, 42)
	head.add_child(resume)
	_buttons.append(resume)
	var hr: ColorRect = MenuKit.rule(2.0)   # T-144: the violet rule under the header
	hr.custom_minimum_size = Vector2(0, 2)
	box.add_child(hr)
	_tab_hint = MenuKit.label("", 16, MenuKit.DIM)
	box.add_child(_tab_hint)
	_refresh_tab_hint()
	# the pages
	var body: Control = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	for i2: int in TABS.size():
		var page: MarginContainer = MarginContainer.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		body.add_child(page)
		_pages.append(page)
	_build_map_page(_pages[TAB_MAP])
	_objectives = ObjectivesView.new("ledger")
	_objectives.can_assign = _can_assign
	_objectives.entry_selected.connect(_on_objective_selected)
	_objectives.locate_requested.connect(func(e: Dictionary) -> void: locate_entry(e, true))
	_objectives.assign_requested.connect(_assign_entry)
	_objectives.archive_requested.connect(func(_e: Dictionary) -> void: _open_page(MenuArchive.new()))
	_objectives.spoiler_changed.connect(func(lv: String) -> void:
		GLSettings.set_value("objective_spoilers", lv)
		_refresh_objectives())
	_pages[TAB_OBJECTIVES].add_child(_objectives)
	_build_loadout_page(_pages[TAB_LOADOUT])
	_build_settings_page(_pages[TAB_SETTINGS])
	_build_quit_page(_pages[TAB_QUIT])
	# foot
	_tip = MenuKit.para("", 17, MenuKit.DIM.lightened(0.1))
	box.add_child(_tip)
	box.add_child(MenuKit.para(_controls_line(), 16, MenuKit.DIM))
	set_tab(TAB_MAP)


# ================================================================== tabs

## Shows one tab (an index into TABS).
func set_tab(i: int) -> void:
	current_tab = posmod(i, TABS.size())
	for k: int in _pages.size():
		_pages[k].visible = k == current_tab
		_tab_buttons[k].set_pressed_no_signal(k == current_tab)
		_tab_buttons[k].text = ("▸ " if k == current_tab else "") + TABS[k]
	match current_tab:
		TAB_MAP:
			_show_map_page()
		TAB_OBJECTIVES:
			_refresh_objectives()
		TAB_LOADOUT:
			_refresh_loadout()
	tab_changed.emit(TABS[current_tab])
	if visible:
		_focus_page.call_deferred()


func tab_name() -> String:
	return TABS[current_tab]


func _focus_page() -> void:
	if current_tab == TAB_OBJECTIVES and _objectives != null:
		_objectives.focus_list()
		return
	var page: Control = _pages[current_tab]
	for n: Node in page.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree():
			c.grab_focus()
			return
	_tab_buttons[current_tab].grab_focus()


func _typing() -> bool:
	var f: Control = _root.get_viewport().gui_get_focus_owner() if _root != null and _root.is_inside_tree() else null
	return f is LineEdit or f is TextEdit


# ================================================================== MAP

func _build_map_page(page: Control) -> void:
	_map_slot = Control.new()
	_map_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(_map_slot)
	var ph: PanelContainer = MenuKit.panel()
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb: StyleBoxFlat = MenuKit.paper_box(0.96)
	sb.set_content_margin_all(18)
	ph.add_theme_stylebox_override("panel", sb)
	_map_slot.add_child(ph)
	_map_placeholder = ph
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	ph.add_child(v)
	v.add_child(_ink_label("MAP", 30, ObjectivesView.LEDGER_RED, true))
	_map_info = _ink_label("", 20, ObjectivesView.LEDGER_INK)
	_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_map_info)
	_map_mark = _ink_label("", 18, ObjectivesView.LEDGER_RED)
	_map_mark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_map_mark)
	v.add_child(_ink_label("(The full field map is still being drawn: this page holds its place.)", 15, ObjectivesView.LEDGER_FAINT))


## Ink on the ledger page: no outline (MenuKit "paper"); body text in the sans, headers in the stamp face.
func _ink_label(text: String, size: int, color: Color, stamp: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", MenuKit.stamp_font() if stamp else MenuKit.body_font())
	l.add_theme_font_size_override("font_size", MenuKit.px(size))
	l.add_theme_color_override("font_color", color)
	MenuKit.outline(l, "paper")
	return l


## The MAP tab's content (the Update 04 section 3 pause map). Replaces the placeholder; the view fills the tab.
## Optional on the view: highlight_location(world_pos: Vector3, floor_id: StringName, label: String),
## highlight_locations(points: Array[Vector3], floor_id, label), refresh() (called each time the tab opens).
func set_map_view(view: Control) -> void:
	if _map_view != null and is_instance_valid(_map_view) and _map_view != view:
		_map_view.queue_free()
	_map_view = view
	if _map_placeholder != null:
		_map_placeholder.visible = view == null
	if view != null:
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		view.process_mode = Node.PROCESS_MODE_ALWAYS
		if view.get_parent() != _map_slot:
			if view.get_parent() != null:
				view.get_parent().remove_child(view)
			_map_slot.add_child(view)


func map_view() -> Control:
	return _map_view


## A PauseMapView class (when a map builder adds one) is made once, on the first MAP tab: .new(), then
## bind_pause_menu(self) when it has it.
func _try_default_map_view() -> void:
	if _map_default_tried or _map_view != null:
		return
	_map_default_tried = true
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "PauseMapView":
			var s: Script = load(str(c["path"])) as Script
			var v: Object = s.new() if s != null and s.can_instantiate() else null
			if v is Control:
				set_map_view(v as Control)
				if v.has_method("bind_pause_menu"):
					v.call("bind_pause_menu", self)
			elif v != null and not (v is RefCounted):
				(v as Object).free()
			return


func _show_map_page() -> void:
	_try_default_map_view()
	if _map_view != null and is_instance_valid(_map_view):
		if _map_view.has_method("refresh"):
			_map_view.call("refresh")
		return
	var open: PackedStringArray = []
	for z: Variant in GameState.open_zones.keys():
		if bool(GameState.open_zones[z]):
			open.append(str(z).replace("_", " ").capitalize())
	var exfil: String = ""
	for n: Node in get_tree().get_nodes_in_group(&"exfil_points"):
		if n.has_method("is_active") and bool(n.call("is_active")):
			exfil = "\nThe exfil is open: %s." % str(n.call("target_name")) if n.has_method("target_name") else "\nThe exfil is open."
	_map_info.text = "%s\nRound %d  ·  Power: %s\nOpen: %s%s" % [_map_name(), RoundManager.current_round,
		"ON" if GameState.power_on else "off", ", ".join(open) if not open.is_empty() else "-", exfil]


## Highlights a place on the MAP tab (and tells anyone listening). switch_to_map jumps to the tab.
func show_location(world_pos: Vector3, floor_id: StringName = &"", label: String = "", switch_to_map: bool = false, points: Array[Vector3] = []) -> void:
	location_requested.emit(world_pos, floor_id, label)
	if _map_view != null and is_instance_valid(_map_view):
		if points.size() > 1 and _map_view.has_method("highlight_locations"):
			_map_view.call("highlight_locations", points, floor_id, label)
		elif _map_view.has_method("highlight_location"):
			_map_view.call("highlight_location", world_pos, floor_id, label)
	elif _map_mark != null:
		_map_mark.text = "Marked: %s  (x %d, z %d, height %d m)" % [label, roundi(world_pos.x), roundi(world_pos.z), roundi(world_pos.y)]
	if switch_to_map:
		set_tab(TAB_MAP)


# ================================================================== OBJECTIVES

## The match's intel so far: picked up this match, or filed by a quest since the match began.
func match_intel_ids() -> Array:
	var out: Array = _intel_seen.duplicate()
	for id: Variant in ProfileSave.profile.get("intel", []):
		if not _intel_start.has(id) and not out.has(str(id)):
			out.append(str(id))
	return out


## The log as the tab would draw it now (tools and tests use it too).
func build_objectives() -> Dictionary:
	var snap: Dictionary = ObjectiveSnapshot.gravelight(get_tree(), match_intel_ids())
	var log: Dictionary = ObjectiveLog.build(snap, _obj_data, str(GLSettings.values.get("objective_spoilers", ObjectiveLog.HINTS)))
	quote_setup_lines(log)
	return log


## T-086: a current step's "said" line id becomes the words the tab quotes (lines.json text, tags stripped) and
## the speaker's subtitle name; a step without one, or an unknown id, quotes nothing.
static func quote_setup_lines(log: Dictionary) -> void:
	var names: Dictionary = (load("res://gravelight/ui/subtitles.gd") as GDScript).get_script_constant_map().get("NAMES", {})
	for sec: Variant in log.get("sections", []):
		for e: Variant in (sec as Dictionary).get("entries", []):
			var ed: Dictionary = e as Dictionary
			var id: String = str(ed.get("said", ""))
			if id == "" or not GLVO.lines.has(id):
				continue
			var rec: Dictionary = GLVO.lines[id]
			ed["quote"] = GLVO.strip_tags(str(rec.get("text", ""))).strip_edges()
			ed["quote_by"] = str(names.get(StringName(str(rec.get("speaker", ""))), str(rec.get("speaker", ""))))


func _refresh_objectives() -> void:
	if _objectives == null:
		return
	_obj_dirty = false
	_objectives.show_log(build_objectives())


func _on_world_changed() -> void:
	_obj_dirty = true
	if visible and current_tab == TAB_OBJECTIVES:
		_refresh_objectives.call_deferred()


func _on_objective_selected(e: Dictionary) -> void:
	objective_selected.emit(e)
	if bool(e.get("locatable", false)):
		locate_entry(e, false)


## Finds an entry's place in the scene and highlights it on the MAP tab.
func locate_entry(e: Dictionary, switch_to_map: bool) -> void:
	var pts: Array[Vector3] = ObjectiveSnapshot.locate(_scene_root(), e)
	if pts.is_empty():
		if switch_to_map:
			_objectives.set_feedback("Not on the map yet.")
		return
	var label: String = str(e.get("title", "")).trim_prefix("▸ ").trim_prefix("✔ ")
	if label.length() > 60:
		label = label.substr(0, 57) + "..."
	show_location(pts[0], StringName(str(e.get("floor", ""))), label, switch_to_map, pts)


func _scene_root() -> Node:
	var p: Node = get_parent()
	return p if p != null else get_tree().current_scene


func _squad() -> Node:
	return get_tree().get_first_node_in_group(&"bot_squad")


## Assign to bot applies when the squad's easter-egg API (Update 04 section 5) says this step can go to a bot.
func _can_assign(e: Dictionary) -> bool:
	var sq: Node = _squad()
	if sq == null or str(e.get("quest_id", "")) == "" or not sq.has_method("ee_can_assign"):
		return false
	return bool(sq.call("ee_can_assign", StringName(str(e["quest_id"])), StringName(str(e["step_id"]))))


func _assign_entry(e: Dictionary) -> void:
	var sq: Node = _squad()
	if sq == null or not sq.has_method("ee_assign"):
		_objectives.set_feedback("No bot can take that.")
		return
	var res: Variant = sq.call("ee_assign", StringName(str(e["quest_id"])), StringName(str(e["step_id"])), -1)
	var d: Dictionary = res if res is Dictionary else {"ok": bool(res)}
	if bool(d.get("ok", false)):
		_objectives.set_feedback(str(d.get("reason", "")) if str(d.get("reason", "")) != "" else "A bot is on it.")
	else:
		_objectives.set_feedback("Can't: %s" % str(d.get("reason", "no bot is free")))


# ================================================================== LOADOUT

func _build_loadout_page(page: Control) -> void:
	var p: PanelContainer = MenuKit.panel()
	page.add_child(p)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	p.add_child(scroll)
	_loadout = VBoxContainer.new()
	_loadout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout.add_theme_constant_override("separation", 6)
	scroll.add_child(_loadout)


func _local_player() -> Player:
	var me: int = Net.local_player_id()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == me and not p.is_bot:
			return p
	var mp: Variant = _scene_root().get("player") if _scene_root() != null else null
	return mp as Player


func _refresh_loadout() -> void:
	if _loadout == null:
		return
	for c: Node in _loadout.get_children():
		_loadout.remove_child(c)
		c.queue_free()
	var me: int = Net.local_player_id()
	_loadout.add_child(MenuKit.label("%s Scrip" % _thousands(Economy.get_scrip(me)), 28, MenuKit.GOLD, true))
	var p: Player = _local_player()
	var wt: Dictionary = GLData.table("weapons")
	_loadout.add_child(MenuKit.label("WEAPONS", 20, MenuKit.VIOLET, true))
	if p == null or p.weapons == null:
		_loadout.add_child(MenuKit.label("(no survivor)", 18, MenuKit.DIM))
	else:
		var h: WeaponHolder = p.weapons
		for i: int in h.slots.size():
			var w: WeaponInstance = h.slots[i]
			var line: String = "%s%s   %d / %d" % ["▸ " if i == h.current_index else "   ", str(w.data.get("name", w.id)) + str(w.tier_cfg().get("suffix", "")), w.mag, w.reserve]
			if w.upgraded:
				line += "   (Crucible)"
			var b: Button = MenuKit.button(line, Callable(), 19)
			_loadout.add_child(b)
			var att: String = attachment_text(w)
			if att != "":
				_loadout.add_child(MenuKit.label("        " + att, 16, MenuKit.DIM))
		if h.slots.is_empty():
			_loadout.add_child(MenuKit.label("   no gun in hand", 18, MenuKit.DIM))
		var melee: String = str((wt.get("melee", {}) as Dictionary).get(String(h.melee_id), {}).get("name", h.melee_id))
		var lethal: Dictionary = wt.get("lethal", {})
		var lname: String = str((lethal.values()[0] as Dictionary).get("name", "Grenade")) if not lethal.is_empty() else "Grenade"
		var tac: String = "none"
		if h.tactical_id != &"" and h.tactical_count > 0:
			tac = "%s × %d" % [str((wt.get("tactical", {}) as Dictionary).get(String(h.tactical_id), {}).get("name", h.tactical_id)), h.tactical_count]
		_loadout.add_child(MenuKit.label("KIT", 20, MenuKit.VIOLET, true))
		_loadout.add_child(MenuKit.label("   Melee: %s   ·   Lethal: %s × %d   ·   Tactical: %s" % [melee, lname, h.grenades, tac], 18))
	_loadout.add_child(MenuKit.label("PERKS  (%d / %d slots)" % [PerkManager.capped_count(me), PerkManager.cap_for(me)], 20, MenuKit.VIOLET, true))
	var md: MapData = MapData.for_map(GameState.map_id) if GameState.map_id != &"" and MapData.exists(GameState.map_id) else null
	if MapState.current() != null and MapState.current().data != null:
		md = MapState.current().data   # T-251: this match's rows (the machines stand where the deal put them)
	for pk: Variant in (GLData.table("perks")["perks"] as Dictionary).keys():
		_loadout.add_child(perk_row(me, StringName(str(pk)), md))
	if not GameState.bot_ids.is_empty():
		_loadout.add_child(MenuKit.label("SQUAD", 20, MenuKit.VIOLET, true))
		for bid: int in GameState.bot_ids:
			var gun: String = ""
			for n: Node in get_tree().get_nodes_in_group(&"players"):
				var bp: Player = n as Player
				if bp != null and bp.player_id == bid and bp.weapons != null and bp.weapons.current() != null:
					gun = bp.weapons.current().display_name()
			var sq: HBoxContainer = HBoxContainer.new()
			sq.add_theme_constant_override("separation", 6)
			# T-183: the squad panel shows no numbers any more; the kills live here and on the scoreboard (hold Ctrl)
			var bsq: BotSquad = get_tree().get_first_node_in_group(&"bot_squad") as BotSquad
			var kills: String = ("  ·  %d kills" % int(bsq.kills.get(bid, 0))) if bsq != null else ""
			sq.add_child(MenuKit.label("   %s: %s Scrip%s%s   " % [str(GameState.character_of(bid)).capitalize(), _thousands(Economy.get_scrip(bid)),
				kills, ("  ·  " + gun) if gun != "" else ""], 17, MenuKit.DIM))
			var bonus: StringName = PerkManager.bonus_perk(bid)
			var order: Array = PerkManager.owned(bid).duplicate()
			if bonus != &"" and order.has(bonus):
				order.erase(bonus)
				order.push_front(bonus)
			for bpk: Variant in order:
				var bc: PerkCap = PerkCap.new()
				bc.custom_minimum_size = Vector2(26, 26)
				bc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				bc.perk_id = StringName(bpk)
				bc.bonus = StringName(bpk) == bonus
				bc.tier = PerkManager.tier_of(bid, StringName(bpk))
				bc.font = MenuKit.stamp_font()
				bc.tooltip_text = PerkManager.tier_name(StringName(bpk), bc.tier)
				sq.add_child(bc)
			_loadout.add_child(sq)


## One tonic on the LOADOUT tab's perk list (T-082): the cap (full colour with its tier band when held, greyed when
## not), the name line (perk_line for a held tonic) and the description; an unheld tonic adds its price and where its
## machine stands on this map (the MapData perk POI's zone). A flat button, so a controller can walk the list.
func perk_row(pid: int, perk_id: StringName, md: MapData) -> Control:
	var owned: bool = PerkManager.has_perk(pid, perk_id)
	var tier: int = PerkManager.tier_of(pid, perk_id)
	var b: Button = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", MenuKit.type_font())
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10.0
	h.offset_right = -10.0
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 16)
	b.add_child(h)
	var cap: PerkCap = PerkCap.new()
	cap.custom_minimum_size = Vector2(54, 54)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.perk_id = perk_id
	cap.tier = tier
	cap.bonus = PerkManager.is_bonus(pid, perk_id)
	cap.dim = not owned
	cap.font = MenuKit.stamp_font()
	h.add_child(cap)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var desc: String = perk_desc(perk_id)
	if owned:
		v.add_child(_row_label(perk_line(pid, perk_id), 19, MenuKit.PAPER, true))
		v.add_child(_row_label(desc, 16, MenuKit.PAPER))
		if tier >= 2:
			v.add_child(_row_label("%s: %s" % [PerkManager.tier_mark(tier), str(PerkManager.tier_data(perk_id, tier).get("desc", ""))], 15, MenuKit.GOLD))
	else:
		v.add_child(_row_label(PerkManager.display_name(perk_id), 19, MenuKit.DIM, true))
		v.add_child(_row_label(desc, 16, MenuKit.DIM))
		v.add_child(_row_label(perk_where(perk_id, md), 15, MenuKit.DIM))
	b.custom_minimum_size = Vector2(0, maxf(62.0, v.get_combined_minimum_size().y + 12.0))
	b.tooltip_text = "%s\n%s" % [PerkManager.display_name(perk_id), desc]
	return b


static func _row_label(text: String, size: int, color: Color, stamp: bool = false) -> Label:
	var l: Label = MenuKit.label(text, size, color, stamp) if stamp or size >= 19 else MenuKit.para(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## The tonic's one-line description (perks.json "desc").
static func perk_desc(perk_id: StringName) -> String:
	return str(PerkManager.perk_data(perk_id).get("desc", ""))


## "2,500 Scrip  ·  Helvetia Cellar" for a tonic not held: its price here (solo / co-op) and the zone of its machine
## on this map from the map's data; "gone" once the solo Second Wind cabinet has left; "no cabinet on this map"
## when the map has none.
static func perk_where(perk_id: StringName, md: MapData) -> String:
	if perk_id == &"second_wind" and PerkManager.second_wind_gone:
		return "gone: the cabinet has poured its last"
	var s: String = "%s Scrip" % _thousands(PerkManager.price(perk_id))
	if md == null:
		return s
	for poi: Dictionary in md.pois_of_type("perk"):
		var pd: Dictionary = poi.get("data", {})
		if str(pd.get("perk_id", "")) == String(perk_id) or str(poi.get("id", "")).ends_with("Perk_" + String(perk_id)):
			var zone: String = md.zone_label_at(poi["pos"] as Vector3)
			return s + ("  ·  " + zone if zone != "" else "")
	return s + "  ·  no cabinet on this map"


## One carried tonic on the LOADOUT tab (T-075): its name at its tier, the bonus mark, and the next tier's state
## ("II at round 8 · 3500", "III locked · mastery 340 / 1200", "max").
static func perk_line(pid: int, perk_id: StringName) -> String:
	var t: int = PerkManager.tier_of(pid, perk_id)
	var s: String = PerkManager.tier_name(perk_id, t) + ("  (bonus)" if PerkManager.is_bonus(pid, perk_id) else "") 		+ ("  (kept on a down)" if PerkManager.is_sealed(pid, perk_id) else "")
	var next: int = t + 1
	if PerkManager.tier_data(perk_id, next).is_empty():
		return s + ("  ·  max" if t > 1 else "")
	var mark: String = PerkManager.tier_mark(next)
	if not PerkManager.tier_unlocked(perk_id, next):
		return s + "  ·  %s locked, mastery %d / %d" % [mark, PerkManager.mastery(perk_id), PerkManager.mastery_needed(next)]
	return s + "  ·  %s from round %d, %d Scrip" % [mark, PerkManager.tier_min_round(next), PerkManager.tier_price(perk_id, next)]


## The weapon's attachments in words, when the weapon has any (Update 04 section 6 adds them to the M1911):
## attachment_labels() if it has it, else an `attachments` Dictionary (slot -> id) or Array.
static func attachment_text(w: Object) -> String:
	if w == null:
		return ""
	if w.has_method("attachment_labels"):
		var lab: Variant = w.call("attachment_labels")
		if lab is Array or lab is PackedStringArray:
			return ", ".join(PackedStringArray(Array(lab).map(func(x: Variant) -> String: return str(x))))
	var a: Variant = w.get("attachments")
	if a is Dictionary and not (a as Dictionary).is_empty():
		var parts: PackedStringArray = []
		for k: Variant in (a as Dictionary).keys():
			if str(a[k]) != "":
				parts.append("%s: %s" % [str(k).capitalize(), str(a[k]).replace("_", " ").capitalize()])
		return ", ".join(parts)
	if a is Array and not (a as Array).is_empty():
		return ", ".join(PackedStringArray((a as Array).map(func(x: Variant) -> String: return str(x).replace("_", " ").capitalize())))
	return ""


static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ================================================================== SETTINGS

func _build_settings_page(page: Control) -> void:
	var p: PanelContainer = MenuKit.panel()
	page.add_child(p)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	p.add_child(right)
	var all: Button = MenuKit.button("All settings  (Gameplay, Controls, Audio, Video, Accessibility)", _open_settings, 22)
	right.add_child(all)
	_buttons.append(all)
	right.add_child(HSeparator.new())
	right.add_child(MenuKit.label("Quick settings", 18, MenuKit.PAPER, true))
	_sens = MenuKit.slider(0.1, 4.0, 0.05, GLSettings.get_f("sensitivity"), func(v: float) -> void: GLSettings.set_value("sensitivity", v))
	right.add_child(MenuKit.row("Mouse sensitivity", _sens, 260.0))
	_fov = MenuKit.slider(65.0, 110.0, 1.0, GLSettings.get_f("fov"), func(v: float) -> void: GLSettings.set_value("fov", v))
	right.add_child(MenuKit.row("Field of view", _fov, 260.0))
	right.add_child(MenuKit.row("Screen shake", MenuKit.slider(0.0, 1.5, 0.05, float(GLSettings.values.get("screen_shake", 1.0)),
		func(v: float) -> void: GLSettings.set_value("screen_shake", v)), 260.0))
	var lv: int = maxi(0, ObjectiveLog.LEVELS.find(ObjectiveLog.level(GLSettings.values.get("objective_spoilers", ObjectiveLog.HINTS))))
	right.add_child(MenuKit.row("Objective spoilers", MenuKit.options(ObjectiveLog.LEVEL_NAMES, lv, func(i: int) -> void:
		GLSettings.set_value("objective_spoilers", ObjectiveLog.LEVELS[i])
		_obj_dirty = true), 260.0))
	right.add_child(MenuKit.check("Subtitles", bool(GLSettings.values.get("subtitles", true)), func(on: bool) -> void: GLSettings.set_value("subtitles", on)))
	right.add_child(MenuKit.check("Hint mode (show the next objective)", bool(GLSettings.values.get("hint_mode", false)), func(on: bool) -> void: GLSettings.set_value("hint_mode", on)))
	right.add_child(MenuKit.check("Classic Rules (no character traits)", bool(GLSettings.values.get("classic_rules", false)), func(on: bool) -> void: GLSettings.set_value("classic_rules", on)))
	_add_bot_mode_check.call_deferred(right)   # T-071 (the map attaches its PlayerBot after this menu is built)


## T-071: player bot mode (an agent plays your survivor; any move or shot takes over).
func _add_bot_mode_check(right: VBoxContainer) -> void:
	var pb: PlayerBot = PlayerBot.of(get_tree()) if is_inside_tree() else null
	if pb == null or not is_instance_valid(right):
		return
	right.add_child(HSeparator.new())
	var bm: CheckButton = MenuKit.check("Bot mode: the agent plays your survivor (%s; move or shoot to take over)" % pb.key_label(), pb.is_on(),
		func(on: bool) -> void: pb.set_on(on, "pause menu"))
	right.add_child(bm)
	pb.changed.connect(func(on: bool, _why: String) -> void:
		if is_instance_valid(bm):
			bm.set_pressed_no_signal(on))


# ================================================================== QUIT

func _build_quit_page(page: Control) -> void:
	var p: PanelContainer = MenuKit.panel()
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(p)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	p.add_child(left)
	left.add_child(MenuKit.label("Leave the match?", 22, MenuKit.PAPER, true))
	if not Net.is_client():
		_add_button(left, "Restart" if not Net.is_online() else "Restart (everyone)",
			_confirm_then.bind("Restart the match?", func() -> void: restart_requested.emit()))
	if Net.is_host():
		_add_button(left, "Back to lobby (everyone)", _confirm_then.bind("Send everyone back to the lobby?", func() -> void: quit_requested.emit()))
		_add_button(left, "End the game", _confirm_then.bind("End the game for everyone?", func() -> void:
			Net.leave("")
			get_tree().paused = false
			GameState.phase = GameState.Phase.MENU
			get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn")))
	else:
		_add_button(left, "Quit to menu" if not Net.is_online() else "Leave the game",
			_confirm_then.bind("Quit to the menu? The match is lost.", func() -> void: quit_requested.emit()))
	_add_button(left, "Back to the match", toggle)


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b: Button = MenuKit.button(text, cb, 24)
	b.custom_minimum_size = Vector2(380, 46)
	parent.add_child(b)
	_buttons.append(b)
	return b


## T-144: a field note from data/gravelight/tips.json (the loading screens' tips), the built-in list as a fallback.
static func _pick_tip() -> String:
	var t: String = LoadingScreen.pick_tip()
	return "FIELD NOTE  ·  " + (t if t != "" else TIPS[randi() % TIPS.size()])


func _controls_line() -> String:
	var parts: PackedStringArray = []
	for pair: Array in [["sprint", "Sprint"], ["crouch", "Crouch / slide"], ["interact", "Use / buy"], ["melee", "Knife"], ["lethal", "Grenade"], ["swap_weapon", "Swap"]]:
		parts.append("%s %s" % [GLSettings.binding_label(StringName(str(pair[0])), false), pair[1]])
	return "  ·  ".join(parts)


func _map_name() -> String:
	return str(GameState.get("map_display_name")) if GameState.get("map_display_name") != null and str(GameState.get("map_display_name")) != "" else String(GameState.map_id)


func _refresh_card() -> void:
	var st: Dictionary = GameState.get("stats") if GameState.get("stats") is Dictionary else {}
	var me: int = Net.local_player_id()   # 1 offline / host; a co-op client sees its own Scrip
	_card.text = "%s  ·  Round %d\n%s Scrip  ·  %d kills (%d heads)  ·  %s" % [_map_name(), RoundManager.current_round, _thousands(Economy.get_scrip(me)),
		int(st.get(&"kills", 0)), int(st.get(&"headshots", 0)), _elapsed()]
	if _sens != null:
		_sens.set_value_no_signal(GLSettings.get_f("sensitivity"))
	if _fov != null:
		_fov.set_value_no_signal(GLSettings.get_f("fov"))
	_tip.text = _pick_tip()


func _elapsed() -> String:
	var ms: int = Time.get_ticks_msec() - int(GameState.get("_start_msec")) if GameState.get("_start_msec") != null else 0
	var s: int = maxi(0, ms / 1000)
	return "%d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------- settings + confirmations

func _open_settings() -> void:
	_open_page(MenuSettings.new())


## A full-screen menu page (Settings, the Archive) over the pause page; Back returns to the same tab.
func _open_page(screen: MenuScreen) -> void:
	if _settings != null and is_instance_valid(_settings):
		screen.free()
		return
	_settings = screen
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings)
	_root.visible = false                      # the page takes the whole screen
	_settings.closed.connect(func() -> void:
		_settings = null
		_root.visible = true
		_refresh_card()
		set_tab(current_tab))


func _confirm_then(question: String, cb: Callable) -> void:
	if _confirm != null and is_instance_valid(_confirm):
		return
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_confirm = MenuKit.panel(Vector2(460, 0))
	center.add_child(_confirm)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_confirm.add_child(v)
	v.add_child(MenuKit.label(question, 22, MenuKit.PAPER, true))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var yes: Button = MenuKit.button("Yes", func() -> void:
		center.queue_free()
		_confirm = null
		cb.call(), 22)
	yes.custom_minimum_size = Vector2(200, 44)
	row.add_child(yes)
	var no: Button = MenuKit.button("No", func() -> void:
		center.queue_free()
		_confirm = null
		_focus_page(), 22, "ui_back")
	no.custom_minimum_size = Vector2(200, 44)
	row.add_child(no)
	no.grab_focus()


# ---------------------------------------------------------------- open / close

func _unhandled_input(event: InputEvent) -> void:
	if visible and _settings == null and _confirm == null and not _typing():
		var step: int = 0
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var kc: Key = (event as InputEventKey).physical_keycode
			if kc == KEY_Q:
				step = -1
			elif kc == KEY_E:
				step = 1
		elif event is InputEventJoypadButton and event.is_pressed():
			var jb: JoyButton = (event as InputEventJoypadButton).button_index
			if jb == JOY_BUTTON_LEFT_SHOULDER:
				step = -1
			elif jb == JOY_BUTTON_RIGHT_SHOULDER:
				step = 1
		if step != 0:
			set_tab(current_tab + step)
			AudioDirector.play_2d("ui_click", 0.0, 0.0)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"pause") and GameState.phase == GameState.Phase.PLAYING:
		if visible and _settings != null and is_instance_valid(_settings):
			return     # the settings page's own Back handles Esc
		if visible and _confirm != null and is_instance_valid(_confirm):
			_confirm.get_parent().queue_free()
			_confirm = null
			get_viewport().set_input_as_handled()
			return
		toggle()
		get_viewport().set_input_as_handled()


## T-264: the line under the header names the device in use (it always said Escape, with a controller too).
var _tab_hint: Label = null


func _refresh_tab_hint() -> void:
	if not is_instance_valid(_tab_hint):
		return
	var pad: bool = GLSettings.using_pad
	_tab_hint.text = "%s switch tabs   ·   %s resumes" % ["LB / RB" if pad else "Q / E or LB / RB",
		MenuSettings.pad_name(GLSettings.binding_label(&"pause", true)) if pad else GLSettings.binding_label(&"pause", false)]


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_tab_hint()
	if Net.is_online():
		GameState.input_blocked = visible   # co-op never stops the world
	else:
		get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_refresh_card()
		set_tab(TAB_MAP)                     # Update 04 section 3: the pause page opens on the map
	else:
		if _settings != null and is_instance_valid(_settings):
			_settings.queue_free()
			_settings = null
		_root.visible = true
		if _confirm != null and is_instance_valid(_confirm):
			_confirm.get_parent().queue_free()
			_confirm = null


func _process(delta: float) -> void:
	if not visible or _tip == null:
		return
	_tip_t += delta
	if _tip_t > 9.0:
		_tip_t = 0.0
		_tip.text = _pick_tip()
