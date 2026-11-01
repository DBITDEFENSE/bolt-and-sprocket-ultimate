class_name MenuCredits
extends MenuScreen
## Credits: the team, tools, and every third-party asset with its license (docs/ASSETS.md).
## The "Art credits" section is built at runtime from data/credits_art.json, which
## `python -I tools/assets_manifest.py` generates from every assets/third_party/**/SOURCE.txt (T-087), so the
## in-game credits can never drift from the paperwork.

const TEXT: String = """{MODE}
An original homage to round-based zombies survival.

Design, code, writing: the {MODE} team
Engine: Godot Engine 4.7 (MIT license), godotengine.org
Unit tests: GUT (Godot Unit Test) 9.6, MIT license

Audio
All sound effects, stingers and ambience are original placeholder audio, synthesized in-house (tools_src/gen_sfx.gd).
Songs ("Come Along, Little Soldier", "Lanterns Down Below") and every perk jingle: original lyrics, placeholder audio.
Voice lines: original script; placeholder (subtitles only) until recorded.

Art
Greybox geometry and placeholder visuals are generated in-house. Third-party models and textures are listed in docs/ASSETS.md with their licenses and credited below.

Fonts
Stardos Stencil (stamps), Special Elite (typewriter), IBM Plex Sans and IBM Plex Mono (body and ledger figures): open-licensed families bundled under assets/third_party/google_fonts, credited below with their licences.

All characters, places, products and events are fictional.
No assets, names, audio or lore from any other commercial game are used."""

const ART_CREDITS_PATH: String = "res://data/credits_art.json"
const ART_HEADING: String = "Art credits"


func _init() -> void:
	super._init("Credits")


func build() -> void:
	content.add_child(MenuKit.para(TEXT.replace("{MODE}", Game.GAME_MODE_NAME), 20))
	var art: PackedStringArray = art_credit_lines()
	if not art.is_empty():
		content.add_child(MenuKit.label(ART_HEADING, 26, MenuKit.GOLD, true))
		content.add_child(MenuKit.para(String("\n").join(art), 18))
	var spacer: Control = Control.new()
	spacer.focus_mode = Control.FOCUS_ALL
	content.add_child(spacer)


## One line per distinct credit line in data/credits_art.json ("<credit line>" or, when several assets share
## one credit, "<credit line>: title, title, ..."). Empty when the file is missing or holds no entries.
static func art_credit_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var doc: Dictionary = art_credits_doc()
	var groups: Array = doc.get("credit_lines", [])
	for g: Variant in groups:
		if not g is Dictionary:
			continue
		var credit: String = String((g as Dictionary).get("credit", "")).strip_edges()
		if credit.is_empty():
			continue
		var titles: Array = (g as Dictionary).get("titles", [])
		if titles.size() > 1:
			var names: PackedStringArray = []
			for t: Variant in titles:
				names.append(String(t))
			out.append("%s: %s" % [credit, ", ".join(names)])
		else:
			out.append(credit)
	return out


## The parsed data/credits_art.json ({} when absent).
static func art_credits_doc() -> Dictionary:
	if not FileAccess.file_exists(ART_CREDITS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_CREDITS_PATH))
	return parsed if parsed is Dictionary else {}
