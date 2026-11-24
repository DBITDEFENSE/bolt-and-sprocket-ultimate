class_name MenuCharacter
extends MenuScreen
## Play > Solo and Play > Campaign: step 1 pick a character (traits + character level), step 2 pick a map
## (respecting unlocks), which starts the match.
## T-144: the maps are cards (MapCards: a 16:9 preview, the date line, the best round, the egg status). A map loads
## through the loading screen (LoadingScreen.go).
## T-267 (the owner: "cutscenes are for the campaign"): SOLO shows the maps only. Until now the campaign's card was
## the first, pre-focused card of the Solo page too, so "Solo, a character, accept" started the campaign with its
## prologue and cutscenes; the campaign is now reached only through Play > Campaign (`campaign_only`), which shows
## just its card. Step 1 shows the character under the focus in 3D beside the list (MenuModelView), a line in the
## header says which step this is, and the top row of step 2 holds the character (press to change), the loadout
## and the bots.

const CHARACTERS: Array = [
	["dutch", "Sgt. Walter \"Dutch\" Kowalczyk", "US Army Ranger", "+10% melee damage"],
	["peg", "Lt. Margaret \"Peg\" Ashworth", "SOE, mission commander", "Grenade cook timer on the HUD, +1 grenade"],
	["deacon", "Cpl. Elijah \"Deacon\" Brooks", "761st Tank Battalion mechanic", "Repairs, builds and trap cooldowns 15% faster"],
	["wren", "Zofia \"Wren\" Nowak", "Polish Home Army sniper", "+10 Scrip (the money you spend in a match) on headshot kills"],
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
## T-144: PLAY > CAMPAIGN: after the character, only the campaign card.
var campaign_only: bool = false
## T-267: the character under the focus, in 3D beside the step 1 list.
var view: MenuModelView = null
var _who: Label = null
var _who_role: Label = null
var _who_trait: Label = null
var _step: Label = null


func _init() -> void:
	super._init("Solo")
	subtitle = "Survive as many rounds as you can on one map, alone or with bots."


func _ready() -> void:
	if campaign_only:
		_title = "Campaign"
		subtitle = "The story: the maps in order, with their cutscenes. Everything you carry goes with you."
	super._ready()


func build_header() -> void:
	_step = MenuKit.label("", 20, MenuKit.GOLD)
	_step.name = "Step"
	_step.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 3))
	header.add_child(_step)


## What the step line reads (pure).
static func step_text(picked_name: String, campaign: bool) -> String:
	if picked_name == "":
		return "STEP 1 OF 2   ·   CHOOSE YOUR CHARACTER"
	return "STEP 2 OF 2   ·   %s   ·   %s" % [picked_name.to_upper(), "START THE CAMPAIGN" if campaign else "CHOOSE A MAP TO START"]


func build_side() -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.name = "CharacterPanel"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.045, 0.72)
	sb.border_color = MenuKit.BRASS_DARK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(520, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	view = MenuModelView.new(Vector2i(496, 560))
	view.name = "CharacterView"
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(view)
	_who = MenuKit.label("", 30, MenuKit.PAPER, true)
	_who.name = "CharacterName"
	_who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_who.custom_minimum_size = Vector2(490, 0)
	v.add_child(_who)
	_who_role = MenuKit.label("", 20, MenuKit.DIM.lightened(0.15))
	v.add_child(_who_role)
	_who_trait = MenuKit.para("", 19, MenuKit.GOLD)
	_who_trait.custom_minimum_size = Vector2(490, 0)
	v.add_child(_who_trait)
	return p


func build() -> void:
	if _step != null:
		_step.text = step_text(str(Net.DISPLAY.get(_picked, _picked.capitalize())) if _picked != "" else "", campaign_only)
	if side != null:
		side.visible = _picked == ""   # the map cards take the whole width; a hidden view draws nothing
	if _picked == "":
		_build_characters()
	else:
		_build_maps()


func _build_characters() -> void:
	var classic: bool = bool(GLSettings.values.get("classic_rules", false))
	var last: String = String(GameState.character_id)
	var focus_me: Button = null
	for c: Array in CHARACTERS:
		var id: String = c[0]
		var lvl: int = ProfileSave.dossier_level(StringName(id))
		var b: Button = MenuKit.button("%s\n    %s  ·  Character level %d/10\n    Trait: %s" % [c[1], c[2], lvl, c[3]], _pick.bind(id), 22)
		b.name = "Character_" + id
		b.custom_minimum_size = Vector2(0, 118)
		b.focus_entered.connect(show_character.bind(id))
		b.mouse_entered.connect(show_character.bind(id))
		content.add_child(b)
		if id == last:
			focus_me = b
	content.add_child(MenuKit.para("Each character has one trait and levels up as you play them (Classic Rules in Settings turns traits %s)." % ("back on: they are OFF now" if classic else "off"), 18, MenuKit.DIM))
	show_character(last if focus_me != null else str(CHARACTERS[0][0]))
	focus_target = focus_me   # the character you played last is under the focus


## The side panel: character `id` in 3D with their name, role and trait.
func show_character(id: String) -> void:
	if view == null:
		return
	for c: Array in CHARACTERS:
		if str(c[0]) == id:
			view.show_character(id)
			_who.text = str(c[1])
			_who_role.text = str(c[2])
			_who_trait.text = "Trait: " + str(c[3])
			return


func _pick(id: String) -> void:
	_picked = id
	GameState.character_id = StringName(id)
	rebuild(false, true)


func _build_maps() -> void:
	_build_muster()   # T-144: the character, the loadout and the bots share one row, so both rows of cards fit at 1080p
	_build_squad()
	# T-144: one card per map (MapCards). T-267: the campaign's card only on the Campaign page (T-033: the inn, then
	# exfil at round 10 to Kaltenbrunn and at round 30 onward, kit and all)
	var grid: GridContainer = GridContainer.new()
	grid.name = "MapCards"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	if campaign_only:
		var first: String = String(Campaign.first_map())
		var camp: Button = MapCards.card("CAMPAIGN", "The Road North", "Crossroads Inn  >  Kaltenbrunn  >  Totenhafen",
			MapCards.preview(first), [["LEAVE AT ROUND 10, THEN 30", MenuKit.GOLD]], _start.bind(Campaign.scene_for(Campaign.first_map()), true))
		camp.name = "Card_Campaign"
		grid.add_child(camp)
		content.add_child(MenuKit.para("Hold the inn to round 10, then take the exfil beacon (your way out) with everything you carry. Round 30 at Kaltenbrunn opens the road north. The story's cutscenes play here, and only here.", 18, MenuKit.DIM))
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
	_build_egg_mode(bottom)
	# the first open card has the focus: a map and accept starts the match
	for card: Node in grid.get_children():
		if not (card as Button).disabled:
			focus_target = card as Button
			break


## T-181 Easter Egg Mode (EggMode): a practice match for the egg, few or no zombies, no profile progress.
func _build_egg_mode(row: HBoxContainer) -> void:
	var cur: int = maxi(0, EggMode.MODES.find(EggMode.mode_of(GLSettings.values)))
	var b: Button = MenuKit.button("Easter Egg Mode: %s" % EggMode.MODE_LABELS[cur], func() -> void:
		GLSettings.set_value(EggMode.SETTING, EggMode.MODES[(cur + 1) % EggMode.MODES.size()])
		rebuild(true), 20)
	b.name = "EggModeButton"
	b.custom_minimum_size = Vector2(320, 44)
	b.tooltip_text = "Practice a map's easter egg (its hidden quest) with few or no zombies. No XP, challenges or rewards."
	row.add_child(b)
	row.add_child(MenuKit.label("Practice the map's hidden quest: its own enemies still come; no XP, challenges or rewards" if cur > 0
		else "Practice mode for a map's hidden quest (few or no zombies)", 18, MenuKit.DIM))


## The top row of step 2: the character (press to change), then their loadout (T-079: the starting pistol and the
## starting perks) and the way to change it before the match.
func _build_muster() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TopRow"
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var who: Button = MenuKit.button("Character: %s  (change)" % str(Net.DISPLAY.get(_picked, _picked.capitalize())), _unpick, 20, "")
	who.name = "CharacterButton"
	who.custom_minimum_size = Vector2(0, 44)
	row.add_child(who)
	var kit: Dictionary = Muster.loadout_for(_picked, ProfileSave.profile)
	var b: Button = MenuKit.button("Loadout: " + Muster.summary(kit), _open_muster, 20)
	b.name = "LoadoutButton"
	b.custom_minimum_size = Vector2(0, 44)
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	if Muster.classic_rules():
		row.add_child(MenuKit.label("(Classic Rules: off)", 18, MenuKit.DIM))


func _open_muster() -> void:
	var m: MenuMuster = MenuMuster.new(_picked)
	add_child(m)
	m.closed.connect(func() -> void: if is_inside_tree(): rebuild(true))


func _unpick() -> void:
	AudioDirector.play_2d("ui_back", 0.0, 0.0)
	_picked = ""
	rebuild(false, true)


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
	var names: Array = ["Bots: none", "Bots: 1 teammate", "Bots: 2 teammates", "Bots: 3 teammates"]
	var b: Button = MenuKit.button(str(names[mini(bots, names.size() - 1)]), func() -> void:
		GLSettings.set_value("bots", BotConfig.clamp_bots(c, (bots + 1) % (int(c.get("max_bots", 3)) + 1)))
		rebuild(true), 20)
	b.name = "BotsButton"
	b.custom_minimum_size = Vector2(250, 44)
	row.add_child(b)
	var s: Button = MenuKit.button("Bot skill: %s" % skill.capitalize(), func() -> void:
		GLSettings.set_value("bot_skill", BotConfig.next_skill(c, skill))
		rebuild(true), 20)
	s.name = "BotSkillButton"
	s.custom_minimum_size = Vector2(230, 44)
	s.disabled = bots <= 0
	row.add_child(s)
	var brain: String = BotConfig.brain_setting(GLSettings.values)   # T-217: off / auto / builtin / small / small_cpu / large
	var ai: Button = MenuKit.button("Bot AI: %s" % str(BotConfig.AI_BRAIN_LABELS.get(brain, brain)), func() -> void:
		BotConfig.set_brain(BotConfig.next_brain(brain))
		rebuild(true), 20)
	ai.name = "BotAiButton"
	ai.custom_minimum_size = Vector2(280, 44)
	ai.tooltip_text = "Which brain the planning bot uses. Built-in: works on any PC, no download. Small / Large: a local model through Ollama (Small uses ~3 GB of video memory, Large ~17 GB; CPU only uses none but thinks slower). Auto picks Small, or CPU only on a low-end GPU."
	ai.disabled = bots <= 0
	row.add_child(ai)
	if bots > 0:
		var others: Array[StringName] = BotConfig.assign_characters([_picked], bots)
		var who: PackedStringArray = []
		for ch: StringName in others:
			who.append(str(Net.DISPLAY.get(String(ch), String(ch))))
		content.add_child(MenuKit.para("%s fight alongside you: they follow, shoot, rebuild boards, buy their own guns, open doors with their own money, and revive you (and you them). They spawn with a Thompson, Ironhide Stout and Second Wind. With Bot AI on, %s plans its own objectives (power, perks, guns, doors, boards): Built-in works on any PC; the model brains need Ollama and fall back to Built-in without it. Zombies scale as for %d players." % [

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
