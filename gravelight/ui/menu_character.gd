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
	["map02_totenhafen", "Totenhafen", "res://gravelight/maps/map02_totenhafen/map02.tscn", "Complete \"Requiem for Kaltenbrunn\", or reach round 30 at Kaltenbrunn."],
	["map04a_thalbach", "Fernflug — Act I: Werk Thalbach", "res://gravelight/maps/map04_fernflug/map04a.tscn", "Reach round 40 at Totenhafen."],
	["map04b_kranich", "Fernflug — Act II: der Kranich", "res://gravelight/maps/map04_fernflug/map04b.tscn", "Board the Kranich at Werk Thalbach (act round 15)."],
	["map04c_groomlake", "Fernflug — Act III: Groom Lake", "res://gravelight/maps/map04_fernflug/map04c.tscn", "Rip out the Kranich's autopilot (act round 20)."],
	["map04d_mondlicht", "Fernflug — Act IV: Mondlicht", "res://gravelight/maps/map04_fernflug/map04d.tscn", "Ride the rocket from Groom Lake (act round 30)."],
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
	_build_muster()
	_build_squad()
	# The campaign (T-033): the inn, then exfil at round 10 to Kaltenbrunn and at round 30 onward, kit and all.
	var camp: Button = MenuKit.button("Campaign   ·   Crossroads Inn  >  Kaltenbrunn  >  Totenhafen", _start.bind(Campaign.scene_for(Campaign.first_map()), true), 24, "ui_confirm")
	camp.custom_minimum_size = Vector2(0, 64)
	content.add_child(camp)
	content.add_child(MenuKit.para("Hold the inn to round 10, then take the exfil beacon with everything you carry. Round 30 at Kaltenbrunn opens the road north.", 16, MenuKit.DIM))
	content.add_child(MenuKit.label("Single map", 22, MenuKit.PAPER))
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


## The Muster (T-079): this survivor's sidearm and Field Habits, and the way to change them before the match.
func _build_muster() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var kit: Dictionary = Muster.loadout_for(_picked, ProfileSave.profile)
	var b: Button = MenuKit.button("Muster: " + Muster.summary(kit), _open_muster, 20)
	b.custom_minimum_size = Vector2(0, 44)
	row.add_child(b)
	if Muster.classic_rules():
		row.add_child(MenuKit.label("(Classic Rules: off)", 18, MenuKit.DIM))


func _open_muster() -> void:
	var m: MenuMuster = MenuMuster.new(_picked)
	add_child(m)
	m.closed.connect(func() -> void: if is_inside_tree(): rebuild())


func _unpick() -> void:
	AudioDirector.play_2d("ui_back", 0.0, 0.0)
	_picked = ""
	rebuild()


## AI teammates (T-031): 0-3 bots that take the other survivors, and their skill. Remembered in the settings.
func _build_squad() -> void:
	var c: Dictionary = BotConfig.cfg()
	var bots: int = BotConfig.clamp_bots(c, int(GLSettings.values.get("bots", 0)))
	var skill: String = BotConfig.skill_key(c, str(GLSettings.values.get("bot_skill", c.get("skill_default", "veteran"))))
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
	var ai_on: bool = bool(GLSettings.values.get("bot_local_ai", true))
	var ai: Button = MenuKit.button("Local AI bot: %s" % ("On" if ai_on else "Off"), func() -> void:
		GLSettings.set_value("bot_local_ai", not ai_on)
		rebuild(), 22)
	ai.custom_minimum_size = Vector2(240, 44)
	ai.disabled = bots <= 0
	row.add_child(ai)
	if bots > 0:
		var others: Array[StringName] = BotConfig.assign_characters([_picked], bots)
		var who: PackedStringArray = []
		for ch: StringName in others:
			who.append(str(Net.DISPLAY.get(String(ch), String(ch))))
		content.add_child(MenuKit.para("%s fight alongside you: they follow, shoot, rebuild boards, buy their own guns, open doors with their own Scrip, and revive you (and you them). They spawn with a Thompson, Ironhide Stout and Second Wind. With the local AI on, %s runs on a local model (Ollama) and works the map's tasks and easter egg on its own. Zombies scale as for %d players." % [

			" and ".join(who) if who.size() <= 2 else ", ".join(who.slice(0, who.size() - 1)) + " and " + who[who.size() - 1],
			who[clampi(int((c.get("local_ai", {}) as Dictionary).get("bot_index", 0)), 0, who.size() - 1)] if not who.is_empty() else "one bot",
			BotConfig.scaled_player_count(1, bots, c)], 16, MenuKit.DIM))


func _start(scene: String, campaign: bool = false) -> void:
	if scene == "":
		return
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), int(GLSettings.values.get("bots", 0)))
	GameState.bot_skill = BotConfig.skill_key(BotConfig.cfg(), str(GLSettings.values.get("bot_skill", "veteran")))
	GameState.bot_ai_mode = BotConfig.ai_mode_from_settings(GLSettings.values, GameState.bot_count)
	if campaign:
		Campaign.begin()
	else:
		Campaign.reset()   # single-map play: no beacon, no chain
	get_tree().change_scene_to_file(scene)



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _picked != "" and get_children().filter(func(n: Node) -> bool: return n is MenuMuster).is_empty():
		get_viewport().set_input_as_handled()
		_unpick()
		return
	super._unhandled_input(event)
