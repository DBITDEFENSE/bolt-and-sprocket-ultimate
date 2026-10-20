class_name MenuCredits
extends MenuScreen
## Credits: the team, tools, and every third-party asset with its license (docs/ASSETS.md).

const TEXT: String = """GRAVELIGHT
An original homage to round-based zombies survival.

Design, code, writing: the GRAVELIGHT team
Engine: Godot Engine 4.7 (MIT license), godotengine.org
Unit tests: GUT (Godot Unit Test) 9.6, MIT license

Audio
All sound effects, stingers and ambience are original placeholder audio, synthesized in-house (tools_src/gen_sfx.gd).
Songs ("Come Along, Little Soldier", "Lanterns Down Below") and every perk jingle: original lyrics, placeholder audio.
Voice lines: original script; placeholder (subtitles only) until recorded.

Art
Greybox geometry and placeholder visuals are generated in-house. Third-party models and textures are listed in docs/ASSETS.md with their licenses as they are added.

Fonts
System fonts (Stencil / Impact, Courier New) during development. Bundled OFL fonts arrive with the art pass.

All characters, places, products and events are fictional.
No assets, names, audio or lore from any other commercial game are used."""


func _init() -> void:
	super._init("Credits")


func build() -> void:
	content.add_child(MenuKit.para(TEXT, 20))
	var spacer: Control = Control.new()
	spacer.focus_mode = Control.FOCUS_ALL
	content.add_child(spacer)
