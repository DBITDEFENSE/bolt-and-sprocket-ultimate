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
	_build_squad()
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


## AI teammates (T-031): 0-3 bots that take the other survivors, and their skill. Remembered in the settings.
func _build_squad() -> void:
	var c: Dictionary = BotConfig.cfg()
	var bots: int = BotConfig.clamp_bots(c, int(GLSettings.values.get("bots", 0)))
	var skill: String = str(GLSettings.values.get("bot_skill", c.get("skill_default", "regular")))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var names: Array = ["Squad: just you", "Squad: you + 1 bot", "Squad: you + 2 bots", "Squad: you + 3 bots"]
	var b: Button = MenuKit.button(str(names[mini(bots, names.size() - 1)]), func() -> void:
		GLSettings.set_value("bots", BotConfig.clamp_bots(c, (bots + 1) % (int(c.get("max_bots", 3)) + 1)))
		rebuild(), 22)
	b.custom_minimum_size = Vector2(300, 44)
	row.add_child(b)
	var s: Button = MenuKit.button("Bot skill: %s" % skill.capitalize(), func() -> void:
		GLSettings.set_value("bot_skill", BotConfig.next_skill(c, skill))
		rebuild(), 22)
	s.custom_minimum_size = Vector2(240, 44)
	s.disabled = bots <= 0
	row.add_child(s)
	if bots > 0:
		var others: Array[StringName] = BotConfig.assign_characters([_picked], bots)
		var who: PackedStringArray = []
		for ch: StringName in others:
			who.append(str(Net.DISPLAY.get(String(ch), String(ch))))
		content.add_child(MenuKit.para("%s fight alongside you: they follow, shoot, rebuild boards, buy their own guns, open doors with their own Scrip, and revive you (and you them). Zombies scale as for %d players." % [

			" and ".join(who) if who.size() <= 2 else ", ".join(who.slice(0, who.size() - 1)) + " and " + who[who.size() - 1],
			BotConfig.scaled_player_count(1, bots, c)], 16, MenuKit.DIM))


func _start(scene: String) -> void:
	if scene == "":
		return
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), int(GLSettings.values.get("bots", 0)))
	GameState.bot_skill = str(GLSettings.values.get("bot_skill", "regular"))
	get_tree().change_scene_to_file(scene)



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _picked != "":
		get_viewport().set_input_as_handled()
		_unpick()
		return
	super._unhandled_input(event)
