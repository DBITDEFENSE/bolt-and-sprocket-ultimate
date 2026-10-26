extends CanvasLayer
## Subtitles (VO_SCRIPT §1.5). Created by VOManager as its own child. Shows "SPEAKER: text" bottom-center (T-096: the
## speaker in the typewriter, the words in the bold body face, the kit's subtitle outline + shadow),
## story lines above player chatter, max 2 lines of ~42 chars per chunk; long lines are split into timed chunks.

const NAMES: Dictionary = {
	&"OPR": "THE OPERATOR", &"FAS": "FASBENDER (RADIO)", &"REI": "REINHOLT", &"LSL": "LIESL",
	&"DUT": "DUTCH", &"PEG": "PEG", &"DEA": "DEACON", &"WRN": "WREN", &"JAK": "JAKUB",
}
const COLORS: Dictionary = {
	&"OPR": Color(1.0, 0.78, 0.35), &"FAS": Color(0.62, 0.9, 0.62), &"REI": Color(0.72, 0.5, 1.0),
	&"LSL": Color(1.0, 0.7, 0.78), &"DUT": Color(0.55, 0.7, 0.9), &"PEG": Color(0.86, 0.22, 0.25),
	&"DEA": Color(0.85, 0.68, 0.3), &"WRN": Color(1.0, 1.0, 1.0), &"JAK": Color(0.72, 0.8, 0.62),
}
const STORY: Array[StringName] = [&"OPR", &"FAS", &"REI", &"LSL"]
const CHUNK_CHARS: int = 84
const MIN_CHUNK_SECONDS: float = 1.2

var _rows: Dictionary = {}   # "story" / "player" -> {label, chunks, times, t}
var _box: VBoxContainer


func _init() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_box = VBoxContainer.new()
	# Centered strip above the prompt area (ui.json hud: subtitle_width wide, subtitle_bottom up from the bottom).
	var sw: float = float(MenuKit.hud("subtitle_width", 980.0))
	var sb: float = float(MenuKit.hud("subtitle_bottom", 200.0))
	var sh: float = float(MenuKit.hud("subtitle_height", 130.0))
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -sw * 0.5
	_box.offset_right = sw * 0.5
	_box.offset_top = -(sb + sh)
	_box.offset_bottom = -sb
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(_box)
	add_child(_box)
	var font: Font = MenuKit.font("body_bold")   # the readable body face, bold, for the words
	var name_font: Font = MenuKit.type_font()
	for key: String in ["story", "player"]:
		var l: RichTextLabel = RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(sw, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("normal_font", font)
		l.add_theme_font_override("bold_font", name_font)   # the speaker's name in the typewriter
		l.add_theme_font_size_override("normal_font_size", MenuKit.size("hud_subtitle"))
		l.add_theme_font_size_override("bold_font_size", MenuKit.size("hud_subtitle"))
		MenuKit.outline(l, "subtitle")
		l.visible = false
		_box.add_child(l)
		_rows[key] = {"label": l, "chunks": PackedStringArray(), "times": PackedFloat32Array(), "i": 0, "t": 0.0, "speaker": &""}
	GLBus.vo_line_started.connect(_on_line)


## Splits text at word boundaries into chunks of at most `max_chars`.
static func chunk(text: String, max_chars: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur: String = ""
	for word: String in text.split(" ", false):
		if cur.length() + word.length() + 1 > max_chars and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = word if cur == "" else cur + " " + word
	if cur != "":
		out.append(cur)
	return out


func _on_line(_id: StringName, speaker: StringName, text: String, duration: float) -> void:
	if not bool(GLSettings.values.get("subtitles", true)):
		return
	var key: String = "story" if STORY.has(speaker) else "player"
	var row: Dictionary = _rows[key]
	var chunks: PackedStringArray = chunk(text, CHUNK_CHARS)
	var times: PackedFloat32Array = []
	var total: int = maxi(1, text.length())
	for c: String in chunks:
		times.append(maxf(MIN_CHUNK_SECONDS, duration * float(c.length()) / float(total)))
	row["chunks"] = chunks
	row["times"] = times
	row["i"] = 0
	row["t"] = times[0] if times.size() > 0 else duration
	row["speaker"] = speaker
	row["slip"] = String(_id).begins_with("op.slip")
	_show(row)


func _show(row: Dictionary) -> void:
	var l: RichTextLabel = row["label"]
	var chunks: PackedStringArray = row["chunks"]
	var i: int = int(row["i"])
	if i >= chunks.size():
		l.visible = false
		return
	var spk: StringName = row["speaker"]
	var col: Color = COLORS.get(spk, Color(0.9, 0.9, 0.9))
	var name_str: String = str(NAMES.get(spk, String(spk)))
	var body_col: String = "c07dff" if bool(row.get("slip", false)) else "ece6d6"   # a slip: Darkmatter violet
	l.text = "[center][b][color=#%s]%s:[/color][/b] [color=#%s]%s[/color][/center]" % [col.to_html(false), name_str, body_col, chunks[i].replace("[", "[lb]")]
	l.visible = true


func _process(delta: float) -> void:
	for key: Variant in _rows.keys():
		var row: Dictionary = _rows[key]
		var l: RichTextLabel = row["label"]
		if not l.visible:
			continue
		row["t"] = float(row["t"]) - delta
		if float(row["t"]) <= 0.0:
			row["i"] = int(row["i"]) + 1
			var times: PackedFloat32Array = row["times"]
			if int(row["i"]) < times.size():
				row["t"] = times[int(row["i"])]
			_show(row)
