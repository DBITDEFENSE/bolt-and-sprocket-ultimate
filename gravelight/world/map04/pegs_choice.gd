class_name PegsChoice
extends CanvasLayer
## Peg's choice (UPDATE 07, docs/MAP4_FERNFLUG.md §5.6): the impeller core is at Hale's hatch. Hand it over, or
## keep it for the rocket. No time limit; the decider is whoever plays Peg, else the first human; bots never choose
## (U08: but in Full Partner the default, KEEP, is taken when the decider is away, down, or the bot-mode agent).
## The runner is a panel with two buttons (keys 1 / 2 too) on the decider's machine; `choose()` is the one entry
## (the console, the tests and the host's mirror use it). Flags: `peg_resigned` (keep, canon) or `peg_delivered`.
## The lines: the Operator's and Hale's on open, the squad's on the decision (only the characters in the match).

const KEEP: String = "keep"
const DELIVER: String = "deliver"

var decider: int = 1
var chosen: String = ""
var _on_choice: Callable
var _panel: PanelContainer
var _insist_t: float = 20.0
var _was_captured: bool = false


## Pure: who decides, from the characters in the match: Peg's player if a human plays her, else the first human.
static func decider_of(characters: Dictionary, humans: Array) -> int:
	for pid: Variant in characters.keys():
		if StringName(str(characters[pid])) == &"peg" and humans.has(int(pid)):
			return int(pid)
	return int(humans[0]) if not humans.is_empty() else 1


## Pure: the flag a choice sets.
static func flag_for(opt: String) -> StringName:
	return &"peg_resigned" if opt == KEEP else &"peg_delivered"


## Opens the choice on every machine; `on_choice(opt)` runs on the host once decided.
static func start(tree: SceneTree, on_choice: Callable) -> PegsChoice:
	var pc: PegsChoice = PegsChoice.new()
	pc.name = "PegsChoice"
	pc._on_choice = on_choice
	pc.layer = 31
	tree.root.add_child(pc)
	return pc


func _ready() -> void:
	var chars: Dictionary = {}
	for pid: int in GameState.player_ids:
		chars[pid] = GameState.character_of(pid)
	decider = decider_of(chars, GameState.human_ids())
	if _is_mine():
		_build()
	GLVO.play(&"OPR_M4C_CHOICE_01")
	GLVO.play(&"HAL_M4C_CHOICE_01")
	if GameState.has_trait(&"dutch"):
		GLVO.play(&"DEE_M4C_HALE_01")


func decider_label() -> String:
	return "P%d decides" % decider


func _is_mine() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == decider:
			return p.is_local
	return decider == 1


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchors_preset = Control.PRESET_CENTER
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -150
	_panel.offset_bottom = 150
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	var title: Label = Label.new()
	title.text = "THE ENGINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	col.add_child(title)
	var body: Label = Label.new()
	body.text = "Mr. Hale, through the glass: \"Hand it through the hatch and your orders are complete. Every one of them.\"\nThe orders say so. The rocket could run on it instead."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	col.add_child(row)
	var b1: Button = Button.new()
	b1.text = "[1]  Hand it over"
	b1.pressed.connect(func() -> void: choose(DELIVER))
	row.add_child(b1)
	var b2: Button = Button.new()
	b2.text = "[2]  Keep it for the rocket"
	b2.pressed.connect(func() -> void: choose(KEEP))
	row.add_child(b2)
	var foot: Label = Label.new()
	foot.text = "Peg's call. There is no clock on it."
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.modulate = Color(1, 1, 1, 0.6)
	col.add_child(foot)
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	b2.grab_focus()


## U08 (T-131): the story choice's default pick, so a bot squad can finish the egg. Only with Bot Easter-Egg Help on
## Full Partner, and only when the decider can't decide: down, out of the match, or played by the bot-mode agent.
## After DEFAULT_AFTER_S of that it takes KEEP (Peg resigns: the canon pick). A present human always decides.
const DEFAULT_AFTER_S: float = 20.0
var _default_t: float = 0.0


static func default_due(mode: String, decider_away: bool, agent: bool, waited_s: float) -> bool:
	return mode == "full" and (decider_away or agent) and waited_s >= DEFAULT_AFTER_S


func _decider_state() -> Array:
	var away: bool = true
	var agent: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == decider:
			away = p.downed or p.spectating
	var map: Node = get_tree().current_scene
	var sq: BotSquad = map.get("squad") as BotSquad if map != null else null
	if sq != null and sq.player_bot != null and is_instance_valid(sq.player_bot) and sq.player_bot.player.player_id == decider:
		agent = true
	return [away, agent]


func _process(delta: float) -> void:
	if chosen != "":
		return
	if Net.is_authority():
		var ds: Array = _decider_state()
		_default_t = (_default_t + delta) if (bool(ds[0]) or bool(ds[1])) else 0.0
		if default_due(str(GLSettings.values.get("bot_ee_help", "full")), bool(ds[0]), bool(ds[1]), _default_t):
			print("[pegs_choice] the default pick (keep): the decider can't decide")
			choose(KEEP)
			return
	_insist_t -= delta
	if _insist_t <= 0.0:
		_insist_t = INF
		GLVO.play(&"HAL_M4C_CHOICE_02")


func _unhandled_input(event: InputEvent) -> void:
	if chosen != "" or _panel == null:
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_1 or k.keycode == KEY_KP_1:
		choose(DELIVER)
	elif k.keycode == KEY_2 or k.keycode == KEY_KP_2:
		choose(KEEP)


## The decision (any machine may call it; the host applies it and mirrors to the rest).
func choose(opt: String) -> void:
	if chosen != "" or (opt != KEEP and opt != DELIVER):
		return
	if not Net.is_authority():
		Net.mirror(self, &"choose", [opt])   # a client's decider: the host decides on their word
		return
	_apply(opt)
	Net.mirror(self, &"_apply", [opt])


func _apply(opt: String) -> void:
	if chosen != "":
		return
	chosen = opt
	if Net.is_authority():
		GameState.set_flag(flag_for(opt))
		GameState.set_flag(&"peg_choice_done")
	_say_lines(opt)
	if _panel != null:
		_panel.queue_free()
		_panel = null
		if _was_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Net.is_authority() and _on_choice.is_valid():
		_on_choice.call(opt)
	print("[m4c] Peg's choice: %s" % opt)
	get_tree().create_timer(2.0).timeout.connect(queue_free)


func _say_lines(opt: String) -> void:
	if opt == KEEP:
		_squad(&"peg", "PEG_M4C_RESIGN_01")
		GLVO.play(&"HAL_M4C_RESIGN_01")
		_squad(&"dutch", "DUT_M4C_RESIGN_01")
		_squad(&"wren", "WRN_M4C_RESIGN_01")
	else:
		_squad(&"peg", "PEG_M4C_DELIVER_01")
		GLVO.play(&"HAL_M4C_DELIVER_01")
	_squad(&"deacon", "DEA_M4C_HALE_01")
	_squad(&"bolt", "SPR_M4C_HALE_01")
	_squad(&"vendelin", "VEN_M4C_CABINET_02")


static func _squad(character: StringName, id: String) -> void:
	if GameState.has_trait(character):
		GLVO.play(StringName(id))
