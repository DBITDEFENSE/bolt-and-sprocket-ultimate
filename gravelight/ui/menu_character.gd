class_name MenuCharacter
extends MenuScreen
## Play: pick a survivor (traits + dossier level), then a map (respecting unlocks).

const CHARACTERS: Array = [
	["dutch", "Sgt. Walter \"Dutch\" Kowalczyk", "US Army Ranger", "+10% melee damage"],
	["peg", "Lt. Margaret \"Peg\" Ashworth", "SOE, mission commander", "Grenade cook timer on the HUD, +1 grenade"],
	["deacon", "Cpl. Elijah \"Deacon\" Brooks", "761st Tank Battalion mechanic", "Repairs, builds and trap cooldowns 15% faster"],
	["wren", "Zofia \"Wren\" Nowak", "Polish Home Army sniper", "+10 Scrip on headshot kills"],
]
const MAPS: Array = [
	["map00_crossroads", "Crossroads Inn", "res://gravelight/maps/map00_crossroads/map00.tscn", "Always open."],
	["map01_kaltenbrunn", "Kaltenbrunn", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", "Reach round 10 at the inn, or answer the radio."],
	["map02_totenhafen", "Totenhafen", "", "Complete \"Requiem for Kaltenbrunn\", or reach round 30 at Kaltenbrunn."],
]

var _picked: String = ""


func _init() -> void:
	super._init("Choose your survivor")


func build() -> void:
	if _picked == "":
		_build_characters()
	else:
		_build_maps()


func _build_characters() -> void:
	var classic: bool = bool(GLSettings.values.get("classic_rules", false))
	content.add_child(MenuKit.para("Traits are %s (Classic Rules in Settings turns them off)." % ("OFF" if classic else "on"), 18, MenuKit.DIM))
	for c: Array in CHARACTERS:
		var id: String = c[0]
		var lvl: int = ProfileSave.dossier_level(StringName(id))
		var b: Button = MenuKit.button("%s\n    %s  ·  Trait: %s  ·  Dossier %d/10" % [c[1], c[2], c[3], lvl], _pick.bind(id), 22)
		b.custom_minimum_size = Vector2(0, 92)
		content.add_child(b)


func _pick(id: String) -> void:
	_picked = id
	GameState.character_id = StringName(id)
	rebuild()


func _build_maps() -> void:
	content.add_child(MenuKit.para("Survivor: %s" % _picked.capitalize(), 20, MenuKit.GOLD))
	for m: Array in MAPS:
		var id: StringName = StringName(m[0])
		var open: bool = ProfileSave.is_map_unlocked(id)
		var best: int = ProfileSave.best_round(id)
		var text: String = str(m[1])
		if open and best > 0:
			text += "   (best: round %d)" % best
		if not open:
			text += "   [locked] " + str(m[3])
		elif str(m[2]) == "":
			text += "   [unlocked: coming soon]"
		var b: Button = MenuKit.button(text, _start.bind(str(m[2])), 24, "ui_confirm")
		b.disabled = not open or str(m[2]) == ""
		content.add_child(b)
	content.add_child(MenuKit.button("Back to survivors", _unpick, 20, ""))


func _unpick() -> void:
	AudioDirector.play_2d("ui_back", 0.0, 0.0)
	_picked = ""
	rebuild()


func _start(scene: String) -> void:
	if scene == "":
		return
	get_tree().change_scene_to_file(scene)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _picked != "":
		get_viewport().set_input_as_handled()
		_unpick()
		return
	super._unhandled_input(event)
