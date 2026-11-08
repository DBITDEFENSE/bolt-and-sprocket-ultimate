class_name MenuCharacter
extends MenuScreen
## Play: pick a survivor (traits + dossier level), then a map (respecting unlocks).
## T-144: the maps are cards (MapCards: a 16:9 preview, the date line, the best round, the egg status), the campaign
## is the first card; `campaign_only` (the main menu's PLAY > CAMPAIGN) shows just the campaign. A map loads through
## the loading screen (LoadingScreen.go: its preview, a tip and a lore line).

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
## T-144: PLAY > CAMPAIGN: after the survivor, only the campaign card.
var campaign_only: bool = false


func _init() -> void:
	super._init("Choose your survivor")


func _ready() -> void:
	if campaign_only:
		_title = "Campaign: choose your survivor"
	super._ready()


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
	_build_muster()   # T-144: the survivor, the Muster and the squad share one row, so both rows of cards fit at 1080p
	_build_squad()
	# T-144: one card per map (MapCards), the campaign first (T-033: the inn, then exfil at round 10 to Kaltenbrunn
	# and at round 30 onward, kit and all)
	var grid: GridContainer = GridContainer.new()
	grid.name = "MapCards"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	var first: String = String(Campaign.first_map())
	var camp: Button = MapCards.card("CAMPAIGN", "The Road North", "Crossroads Inn  >  Kaltenbrunn  >  Totenhafen",
		MapCards.preview(first), [["ROUND 10 EXFIL, THEN 30", MenuKit.GOLD]], _start.bind(Campaign.scene_for(Campaign.first_map()), true))
	camp.name = "Card_Campaign"
	grid.add_child(camp)
	if campaign_only:
		content.add_child(MenuKit.para("Hold the inn to round 10, then take the exfil beacon with everything you carry. Round 30 at Kaltenbrunn opens the road north.", 18, MenuKit.DIM))
	else:
		for m: Array in MAPS:
			var id: String = str(m[0])
			var c: Button = MapCards.map_card(id, _start.bind(str(m[2])))
			if str(m[2]) == "":
				c.disabled = true
			grid.add_child(c)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.name = "BottomRow"
	bottom.add_theme_constant_override("separation", 14)
	content.add_child(bottom)
	bottom.add_child(MenuKit.button("Back to survivors", _unpick, 20, ""))
	_build_egg_mode(bottom)


## T-181 Easter Egg Mode (EggMode): a practice match for the egg, few or no zombies, no profile progress.
func _build_egg_mode(row: HBoxContainer) -> void:
	var cur: int = maxi(0, EggMode.MODES.find(EggMode.mode_of(GLSettings.values)))
	var b: Button = MenuKit.button("Easter Egg Mode: %s" % EggMode.MODE_LABELS[cur], func() -> void:
		GLSettings.set_value(EggMode.SETTING, EggMode.MODES[(cur + 1) % EggMode.MODES.size()])
		rebuild(), 20)
	b.name = "EggModeButton"
	b.custom_minimum_size = Vector2(320, 40)
	row.add_child(b)
	if cur > 0:
		row.add_child(MenuKit.label("Practice: the egg's own enemies still come; no XP, challenges or egg rewards", 16, MenuKit.DIM))


## The Muster (T-079): this survivor's sidearm and Field Habits, and the way to change them before the match.
func _build_muster() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TopRow"
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var who: Label = MenuKit.label(Net.DISPLAY.get(_picked, _picked.capitalize()), 24, MenuKit.GOLD)
	who.custom_minimum_size = Vector2(110, 0)
	row.add_child(who)
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
	var row: HBoxContainer = content.get_node_or_null("TopRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
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
	var brain: String = BotConfig.brain_setting(GLSettings.values)   # T-217: off / auto / builtin / small / small_cpu / large
	var ai: Button = MenuKit.button("Bot AI: %s" % str(BotConfig.AI_BRAIN_LABELS.get(brain, brain)), func() -> void:
		BotConfig.set_brain(BotConfig.next_brain(brain))
		rebuild(), 22)
	ai.custom_minimum_size = Vector2(300, 44)
	ai.tooltip_text = "Which brain the planning bot uses. Built-in: works on any PC, no download. Small / Large: a local model through Ollama (Small uses ~3 GB of video memory, Large ~17 GB; CPU only uses none but thinks slower). Auto picks Small, or CPU only on a low-end GPU."
	ai.disabled = bots <= 0
	row.add_child(ai)
	if bots > 0:
		var others: Array[StringName] = BotConfig.assign_characters([_picked], bots)
		var who: PackedStringArray = []
		for ch: StringName in others:
			who.append(str(Net.DISPLAY.get(String(ch), String(ch))))
		content.add_child(MenuKit.para("%s fight alongside you: they follow, shoot, rebuild boards, buy their own guns, open doors with their own Scrip, and revive you (and you them). They spawn with a Thompson, Ironhide Stout and Second Wind. With Bot AI on, %s plans its own objectives (power, perks, guns, doors, boards): Built-in works on any PC; the model brains need Ollama and fall back to Built-in without it. Zombies scale as for %d players." % [

			" and ".join(who) if who.size() <= 2 else ", ".join(who.slice(0, who.size() - 1)) + " and " + who[who.size() - 1],
			who[clampi(int((c.get("local_ai", {}) as Dictionary).get("bot_index", 0)), 0, who.size() - 1)] if not who.is_empty() else "one bot",
			BotConfig.scaled_player_count(1, bots, c)], 16, MenuKit.DIM))


func _start(scene: String, campaign: bool = false) -> void:
	if scene == "":
		return
	prepare_match(campaign)
	LoadingScreen.go(get_tree(), scene)   # T-144: the map's art, a tip and a lore line; it awaits MapPacks.ensure (T-139) first


## Everything a match start sets before the loading screen: the bots from the settings and the campaign chain (or
## single-map play). Shared with the crash probe (probe_campaign_start, T-216) so it always tests this exact path.
static func prepare_match(campaign: bool) -> void:
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), int(GLSettings.values.get("bots", 0)))
	GameState.bot_skill = BotConfig.skill_key(BotConfig.cfg(), str(GLSettings.values.get("bot_skill", "veteran")))
	GameState.bot_ai_mode = BotConfig.ai_mode_from_settings(GLSettings.values, GameState.bot_count)
	if campaign:
		Campaign.begin()
	else:
		Campaign.reset()   # single-map play: no beacon, no chain



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _picked != "" and get_children().filter(func(n: Node) -> bool: return n is MenuMuster).is_empty():
		get_viewport().set_input_as_handled()
		_unpick()
		return
	super._unhandled_input(event)
