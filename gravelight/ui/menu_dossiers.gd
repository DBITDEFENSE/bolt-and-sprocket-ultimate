class_name MenuDossiers
extends MenuScreen
## Character dossiers: level 1–10 from playing that survivor; each level opens a page.

const NAMES: Dictionary = {"dutch": "Dutch", "peg": "Peg", "deacon": "Deacon", "wren": "Wren"}

var _char: String = "dutch"
var _reader: Label


func _init() -> void:
	super._init("Dossiers")


func build() -> void:
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	for c: String in NAMES.keys():
		var b: Button = MenuKit.button(("> " if c == _char else "") + str(NAMES[c]), _select.bind(c), 22)
		b.custom_minimum_size = Vector2(170, 44)
		tabs.add_child(b)
	var lvl: int = ProfileSave.dossier_level(StringName(_char))
	var xp: int = ProfileSave.dossier_xp(StringName(_char))
	var th: Array = ProfileSave.dossier_thresholds()
	var next_txt: String = "max level"
	var frac: float = 1.0
	if lvl < th.size():
		var lo: int = int(th[lvl - 1])
		var hi: int = int(th[lvl])
		frac = float(xp - lo) / float(maxi(1, hi - lo))
		next_txt = "%d / %d XP to level %d" % [xp - lo, hi - lo, lvl + 1]
	content.add_child(MenuKit.label("%s  ·  Dossier level %d  ·  %s" % [NAMES[_char], lvl, next_txt], 22, MenuKit.GOLD))
	content.add_child(MenuKit.bar(frac, 520, MenuKit.VIOLET))
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	content.add_child(split)
	var list: VBoxContainer = VBoxContainer.new()
	list.custom_minimum_size = Vector2(520, 0)
	split.add_child(list)
	_reader = MenuKit.para("Select a page.", 19)
	_reader.custom_minimum_size = Vector2(620, 0)
	_reader.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	split.add_child(_reader)
	for page: Dictionary in ProfileSave.dossier_pages(StringName(_char)):
		var open: bool = int(page["level"]) <= lvl
		var title: String = "%d. %s" % [page["level"], page["title"]] if open else "%d. [locked: dossier level %d]" % [page["level"], page["level"]]
		var b: Button = MenuKit.button(title, _show.bind(page, open), 18)
		b.custom_minimum_size = Vector2(0, 36)
		b.focus_entered.connect(_show.bind(page, open))
		list.add_child(b)


func _select(c: String) -> void:
	_char = c
	rebuild()


func _show(page: Dictionary, open: bool) -> void:
	if open:
		_reader.text = "%s\n\n%s" % [page["title"], page["text"]]
	else:
		_reader.text = "Play as %s to raise this dossier." % NAMES[_char]
