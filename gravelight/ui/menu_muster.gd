class_name MenuMuster
extends MenuScreen
## The Loadout (T-079 "the Muster"; the player reads LOADOUT since T-267, the class, the data file and the profile
## keys keep their names): each survivor's kit for the next match, the starting pistol and the Starting Perks (the
## data's "habits": 1 slot at rank 1, 2 at rank 10, 3 at rank 25). Changes save to the profile at once
## (Muster.save_loadout) and apply from the next match, from every way in (the Play flow, co-op, the dev launcher).
## Opened from the main menu, from Play after choosing a character, and from the co-op lobby.
## T-267 (the owner: "when you're customizing your starting pistol, you need to be able to see the pistol"): the page
## is a list on the left and a fixed panel on the right (MenuScreen.build_side) with the pistol in 3D (MenuModelView:
## the model the match puts in your hand, with the profile's camo and, on the M1911, its finish and fitted
## attachment), its name, four stat bars and its description. Moving the focus over a pistol shows that pistol, also
## a locked one; pressing equips it. The M1911's finish and attachment (they were in Settings > Gameplay) are chosen
## here, on the model. The rank and what it unlocks next sit in the header.

const NAMES: Dictionary = {"dutch": "Dutch", "peg": "Peg", "deacon": "Deacon", "wren": "Wren"}
const SIDE_W: float = 660.0
const VIEW_SIZE: Vector2i = Vector2i(636, 340)
## [label, weapons.json key, higher is better]
const STAT_ROWS: Array = [["Damage", "damage", true], ["Magazine", "mag", true], ["Fire rate", "rpm", true], ["Reload", "reload_empty", false]]

var character: String = "dutch"
var view: MenuModelView = null
## The pistol the panel shows right now (the focused row's, else the equipped one).
var shown_pistol: String = ""
var _note: String = ""
var _info_name: Label = null
var _info_tag: Label = null
var _info_desc: Label = null
var _bars: Dictionary = {}       # stat key -> [ProgressBar, Label]


func _init(for_character: String = "") -> void:
	super._init("Loadout")
	subtitle = "Your starting pistol and starting perks, one set per character. Used in Solo, Co-op and the Campaign."
	character = for_character if NAMES.has(for_character) else String(GameState.character_id)
	if not NAMES.has(character):
		character = "dutch"


# ================================================================== the fixed parts

func build_header() -> void:
	var r: int = ProfileSave.rank()
	var p: int = ProfileSave.prestige()
	var c: Dictionary = ProfileSave.curve()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "RankRow"
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	row.add_child(MenuKit.label("Rank %d%s" % [r, ("   ·   Prestige %d" % p) if p > 0 else ""], 26, MenuKit.INK.lightened(0.3), true))
	var bar: ProgressBar = MenuKit.bar(ProfileSave.rank_progress(), 320)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	if r < int(c.get("max_rank", 60)):
		var into: int = int(ProfileSave.profile.get("xp", 0)) - ProfileSave.total_for_rank(r, c)
		row.add_child(MenuKit.label("%d / %d XP to rank %d" % [into, ProfileSave.xp_to_next(r, c), r + 1], 18, MenuKit.DIM))
	var next: PackedStringArray = []
	for u: Dictionary in Muster.upcoming(r if p == 0 else int(c.get("max_rank", 60)), 3):
		next.append("rank %d: %s" % [int(u["rank"]), u["text"]])
	if not next.is_empty():
		var nl: Label = MenuKit.para("Next unlocks   " + "   ·   ".join(next), 18, MenuKit.VIOLET.lightened(0.15))
		nl.name = "NextUnlocks"
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF   # one line (see MenuScreen's subtitle)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		header.add_child(nl)


func build_side() -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.name = "PistolPanel"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.045, 0.72)
	sb.border_color = MenuKit.BRASS_DARK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(SIDE_W, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var kicker: Label = MenuKit.label("STARTING PISTOL", 18, MenuKit.VIOLET.lightened(0.2))
	kicker.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 5))
	v.add_child(kicker)
	view = MenuModelView.new(VIEW_SIZE)
	view.name = "PistolView"
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(view)
	_info_name = MenuKit.label("", 34, MenuKit.PAPER, true)
	_info_name.name = "PistolName"
	v.add_child(_info_name)
	_info_tag = MenuKit.label("", 19, MenuKit.GOLD)
	_info_tag.name = "PistolTag"
	_info_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_tag.custom_minimum_size = Vector2(SIDE_W - 30.0, 0)
	v.add_child(_info_tag)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Stats"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for row: Array in STAT_ROWS:
		var l: Label = MenuKit.label(str(row[0]), 19, MenuKit.DIM.lightened(0.15))
		l.custom_minimum_size = Vector2(120, 0)
		grid.add_child(l)
		var b: ProgressBar = MenuKit.bar(0.0, 340.0, MenuKit.GOLD.darkened(0.15))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(b)
		var val: Label = MenuKit.label("", 19, MenuKit.PAPER)
		val.add_theme_font_override("font", MenuKit.mono_font())
		grid.add_child(val)
		_bars[str(row[1])] = [b, val]
	_info_desc = MenuKit.para("", 19, MenuKit.PAPER.darkened(0.08))
	_info_desc.name = "PistolDesc"
	_info_desc.custom_minimum_size = Vector2(SIDE_W - 30.0, 0)
	v.add_child(_info_desc)
	return p


# ================================================================== the list

func build() -> void:
	var prof: Dictionary = ProfileSave.profile
	if Muster.classic_rules():
		content.add_child(MenuKit.para("Classic Rules is on (Settings): everyone starts with the plain M1911 and no starting perks. Your choices are kept for when it's off.", 18, MenuKit.INK.lightened(0.35)))
	# character tabs: one kit each
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	for c: String in NAMES.keys():
		var b: Button = MenuKit.button(("> " if c == character else "") + str(NAMES[c]), _select.bind(c), 22)
		b.name = "Tab_" + c
		b.custom_minimum_size = Vector2(170, 44)
		tabs.add_child(b)
	var kit: Dictionary = Muster.loadout_for(character, prof)
	content.add_child(MenuKit.label("%s  ·  Character level %d  ·  %s" % [NAMES[character], ProfileSave.dossier_level(StringName(character)), Muster.summary(kit)], 20, MenuKit.GOLD))
	if _note != "":
		content.add_child(MenuKit.para(_note, 18, MenuKit.INK.lightened(0.35)))
	_build_pistols(kit, prof)
	_build_habits(kit, prof)
	var spacer: Control = Control.new()
	spacer.focus_mode = Control.FOCUS_ALL   # lets a controller scroll to the bottom
	content.add_child(spacer)
	show_pistol(str(kit["pistol"]))


func _build_pistols(kit: Dictionary, prof: Dictionary) -> void:
	content.add_child(_heading("Starting pistol", "The sidearm you spawn with. Move over a pistol to see it; press to equip it. The M1911 also takes a finish and one fitted attachment."))
	for row: Dictionary in Muster.pistol_rows():
		var id: String = str(row["id"])
		var open: bool = Muster.pistol_unlocked(id, prof, character)
		var on: bool = str(kit["pistol"]) == id
		var text: String = "%s%s%s" % ["> " if on else "   ", Muster.pistol_name(id),
			"   ·   EQUIPPED" if on else ("" if open else "   ·   LOCKED: " + Muster.unlock_text(row))]
		var b: Button = MenuKit.button(text, _pick_pistol.bind(id), 22)
		b.name = "Pistol_" + id
		b.custom_minimum_size = Vector2(0, 50)
		_wrap(b)
		b.set_meta("locked", not open)
		if not open:   # still focusable, so a locked pistol can be looked at; the press says why not
			b.add_theme_color_override("font_color", MenuKit.DIM)
			b.add_theme_color_override("font_focus_color", MenuKit.DIM.lightened(0.2))
			b.add_theme_color_override("font_hover_color", MenuKit.DIM.lightened(0.2))
		b.focus_entered.connect(show_pistol.bind(id))
		b.mouse_entered.connect(show_pistol.bind(id))
		content.add_child(b)
		if id == "m1911" and on:
			_build_m1911()   # its finish and attachment, right under it


## A list row whose text wraps instead of widening the page (the list shares the width with the pistol's panel).
static func _wrap(b: Button) -> void:
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## The M1911's finish and fitted attachment (M1911Kit: unlocked by lifetime M1911 kills). Each button steps to the
## next unlocked choice, so a controller needs no drop-down; the model shows the choice at once.
func _build_m1911() -> void:
	var kills: int = ProfileSave.weapon_kills(&"m1911")
	var rows: Array = M1911Kit.finish_rows(kills)
	var cur: StringName = M1911Kit.equipped_finish()
	var cur_name: String = "Standard"
	var open_n: int = 0
	var next_lock: String = ""
	for r: Dictionary in rows:
		if bool(r["unlocked"]):
			open_n += 1
			if StringName(str(r["id"])) == cur:
				cur_name = str(r["name"])
		elif next_lock == "":
			next_lock = "next: %s at %d kills" % [str(r["name"]), int(r["kills"])]
	var fin: Button = MenuKit.button("        Finish: %s    (press to change; %d of %d unlocked%s)" % [cur_name, open_n, rows.size(),
		(", " + next_lock) if next_lock != "" else ""], _next_finish, 19)
	fin.name = "M1911_Finish"
	_wrap(fin)
	fin.disabled = open_n <= 1
	fin.focus_entered.connect(show_pistol.bind("m1911"))
	content.add_child(fin)
	var pick: String = M1911Kit.equipped_pick()
	var pick_name: String = "None"
	if pick != "":
		var parts: PackedStringArray = pick.split(":")
		pick_name = M1911Kit.option_name(parts[0], parts[1])
	var can: bool = M1911Kit.pick_unlocked(kills)
	var pk: Button = MenuKit.button("        Fitted attachment: %s    (%s)" % [pick_name,
		"press to change" if can else "unlocks at %d M1911 kills; you have %d" % [M1911Kit.pick_kills(), kills]], _next_pick, 19)
	pk.name = "M1911_Attachment"
	_wrap(pk)
	pk.disabled = not can
	pk.focus_entered.connect(show_pistol.bind("m1911"))
	content.add_child(pk)


func _build_habits(kit: Dictionary, prof: Dictionary) -> void:
	var slots: int = Muster.slots_for(prof)
	var nxt: int = Muster.next_slot_rank(Muster.effective_rank(prof))
	content.add_child(_heading("Starting perks   %d / %d slots%s" % [(kit["habits"] as Array).size(), slots,
		("   (next slot at rank %d)" % nxt) if nxt > 0 else ""],
		"Small bonuses you bring into every match. Free, yours for the whole match, never lost when you go down. The perk machines in a match are separate."))
	for row: Dictionary in Muster.habit_rows():
		var id: String = str(row["id"])
		var open: bool = Muster.habit_unlocked(id, prof, character)
		var on: bool = (kit["habits"] as Array).has(id)
		var text: String = "%s %s\n      %s" % ["[x]" if on else "[ ]", str(row.get("name", id)),
			str(row.get("desc", "")) if open else "LOCKED: " + Muster.unlock_text(row)]
		var b: Button = MenuKit.button(text, _toggle.bind(id), 19)
		b.name = "Perk_" + id
		b.custom_minimum_size = Vector2(0, 66)
		_wrap(b)
		b.disabled = not open and not on
		b.focus_entered.connect(_show_equipped)
		content.add_child(b)


## A section heading with its plain line under it.
static func _heading(title: String, plain: String) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	v.add_child(MenuKit.label(title, 26, MenuKit.VIOLET, true))
	v.add_child(MenuKit.para(plain, 18, MenuKit.DIM.lightened(0.1)))
	return v


# ================================================================== the panel

## The four bars for a pistol against the best of the pistols on offer: [{key, label, text, frac}] (pure given the
## weapons table; a faster reload is a longer bar).
static func stat_bars(id: String, weapons: Dictionary, ids: PackedStringArray) -> Array:
	var out: Array = []
	var d: Dictionary = weapons.get(id, {})
	for row: Array in STAT_ROWS:
		var key: String = str(row[1])
		var v: float = float(d.get(key, 0.0))
		var best: float = 0.0
		var least: float = INF
		for other: String in ids:
			var ov: float = float((weapons.get(other, {}) as Dictionary).get(key, 0.0))
			best = maxf(best, ov)
			if ov > 0.0:
				least = minf(least, ov)
		var frac: float = 0.0
		if bool(row[2]):
			frac = v / best if best > 0.0 else 0.0
		else:
			frac = least / v if v > 0.0 and least < INF else 0.0
		var text: String = "%.1f s" % v if key == "reload_empty" else ("%d rpm" % int(v) if key == "rpm" else ("%d rounds" % int(v) if key == "mag" else "%d" % int(v)))
		out.append({"key": key, "label": str(row[0]), "text": text, "frac": clampf(frac, 0.0, 1.0)})
	return out


## Shows pistol `id` in the panel: the model (with the M1911's finish and attachment), the name, whether it is
## equipped or what unlocks it, the bars and the description.
func show_pistol(id: String) -> void:
	if view == null or id == "":
		return
	var prof: Dictionary = ProfileSave.profile
	var is_m1911: bool = id == "m1911"
	view.show_weapon(id, M1911Kit.equipped_finish() if is_m1911 else &"", M1911Kit.equipped_pick() if is_m1911 else "")
	var changed: bool = id != shown_pistol
	shown_pistol = id
	var row: Dictionary = Muster.pistol_def(id)
	var kit: Dictionary = Muster.loadout_for(character, prof)
	_info_name.text = Muster.pistol_name(id)
	if str(kit["pistol"]) == id:
		_info_tag.text = "EQUIPPED"
		_info_tag.add_theme_color_override("font_color", MenuKit.GOLD)
	elif Muster.pistol_unlocked(id, prof, character):
		_info_tag.text = "Unlocked. Press to equip."
		_info_tag.add_theme_color_override("font_color", MenuKit.PAPER.darkened(0.15))
	else:
		_info_tag.text = "LOCKED   ·   " + Muster.unlock_text(row)
		_info_tag.add_theme_color_override("font_color", MenuKit.INK.lightened(0.35))
	_info_desc.text = str(row.get("desc", ""))
	var w: Dictionary = GLData.table("weapons")["weapons"]
	for s: Dictionary in stat_bars(id, w, Muster.pistol_ids()):
		var pair: Array = _bars.get(str(s["key"]), [])
		if pair.is_empty():
			continue
		(pair[1] as Label).text = str(s["text"])
		var pb: ProgressBar = pair[0] as ProgressBar
		if changed and is_inside_tree() and not MenuMotion.reduced():
			pb.create_tween().tween_property(pb, "value", float(s["frac"]), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			pb.value = float(s["frac"])


func _show_equipped() -> void:
	show_pistol(str(Muster.loadout_for(character, ProfileSave.profile)["pistol"]))


# ================================================================== changes

func _select(c: String) -> void:
	character = c
	_note = ""
	rebuild(true)


func _pick_pistol(id: String) -> void:
	var prof: Dictionary = ProfileSave.profile
	if not Muster.pistol_unlocked(id, prof, character):
		_note = "%s is locked: %s." % [Muster.pistol_name(id), Muster.unlock_text(Muster.pistol_def(id)).to_lower()]
		rebuild(true)
		show_pistol(id)
		return
	Muster.save_loadout(character, Muster.set_pistol(Muster.loadout_for(character, prof), id, prof, character))
	_note = ""
	AudioDirector.play_2d("ui_confirm", -4.0, 0.0)
	rebuild(true)


## The next unlocked finish after the equipped one (pure): `rows` from M1911Kit.finish_rows.
static func next_finish(rows: Array, current: String) -> String:
	var open: PackedStringArray = []
	for r: Dictionary in rows:
		if bool(r["unlocked"]):
			open.append(str(r["id"]))
	if open.is_empty():
		return current
	return open[(open.find(current) + 1) % open.size()]


## The next attachment choice after `current` ("" = none comes first; pure).
static func next_pick(choices: Array, current: String) -> String:
	var all: PackedStringArray = [""]
	for c: Variant in choices:
		all.append(str(c))
	return all[(all.find(current) + 1) % all.size()]


func _next_finish() -> void:
	var kills: int = ProfileSave.weapon_kills(&"m1911")
	M1911Kit.set_finish(StringName(next_finish(M1911Kit.finish_rows(kills), String(M1911Kit.equipped_finish()))))
	rebuild(true)


func _next_pick() -> void:
	M1911Kit.set_loadout_pick(next_pick(M1911Kit.pick_choices(), M1911Kit.equipped_pick()))
	rebuild(true)


func _toggle(id: String) -> void:
	var prof: Dictionary = ProfileSave.profile
	var res: Dictionary = Muster.toggle_habit(Muster.loadout_for(character, prof), id, prof, character)
	match str(res["result"]):
		"full":
			_note = "Every perk slot is taken: take one off first."
		"locked":
			_note = "Not unlocked yet."
		_:
			_note = ""
			Muster.save_loadout(character, res["kit"])
	rebuild(true)
