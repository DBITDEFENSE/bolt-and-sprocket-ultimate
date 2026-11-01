extends CanvasLayer
## Dev console (autoload "DevConsole"). Toggle with the ` key. Systems can add commands with register().

var _commands: Dictionary = {}   # name -> {fn: Callable, help: String}
var _panel: PanelContainer
var _log: RichTextLabel
var _input: LineEdit
var _history: PackedStringArray = []
var _hist_i: int = 0
var _overlays: Dictionary = {}
var _prev_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
## Co-op: commands that act on "you" act on this player (a client's commands run on the host for them).
var _ctx_pid: int = 1
## Co-op: these run on the client itself; everything else is sent to the host (quest skips included).
const LOCAL_CMDS: PackedStringArray = ["help", "god", "noclip", "goto", "fps", "zombies", "navdebug", "hp", "traits", "timescale", "net"]


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var font: Font = MenuKit.mono_font()
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size = Vector2(0, 380)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.04, 0.9)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	_panel.add_child(v)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", font)
	_log.add_theme_font_size_override("normal_font_size", MenuKit.size("hud_debug"))
	v.add_child(_log)
	_input = LineEdit.new()
	_input.add_theme_font_override("font", font)
	_input.placeholder_text = "command (type help)"
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_key)
	v.add_child(_input)
	_panel.visible = false
	_register_builtins()
	print_line("[color=#9f9]%s dev console. Type [b]help[/b].[/color]" % Game.GAME_MODE_NAME)


func register(cmd: String, fn: Callable, help: String) -> void:
	_commands[cmd] = {"fn": fn, "help": help}


func print_line(text: String) -> void:
	_log.append_text(text + "\n")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev_console"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	GameState.input_blocked = _panel.visible
	if _panel.visible:
		_prev_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_input.clear()
		_input.grab_focus()
	else:
		_input.release_focus()
		Input.mouse_mode = _prev_mouse


func is_open() -> bool:
	return _panel.visible


func _on_input_key(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		var k: InputEventKey = event as InputEventKey
		if k.physical_keycode == KEY_QUOTELEFT:
			toggle()
			_input.accept_event()
		elif k.keycode == KEY_UP and not _history.is_empty():
			_hist_i = maxi(0, _hist_i - 1)
			_input.text = _history[_hist_i]
			_input.caret_column = _input.text.length()
		elif k.keycode == KEY_DOWN and not _history.is_empty():
			_hist_i = mini(_history.size() - 1, _hist_i + 1)
			_input.text = _history[_hist_i]


func _on_submit(text: String) -> void:
	_input.clear()
	text = text.strip_edges()
	if text.is_empty():
		return
	_history.append(text)
	_hist_i = _history.size()
	print_line("> " + text)
	var cmd: String = text.split(" ", false)[0].to_lower()
	if Net.is_client() and not LOCAL_CMDS.has(cmd) and _commands.has(cmd):
		Net._rpc_console.rpc_id(1, text)
		print_line("[color=#aaa](sent to the host)[/color]")
		return
	var out: String = run(text, Net.local_player_id())
	if out != "":
		print_line(out)


## Runs one command line as `pid` and returns its output (the host runs a client's commands with this).
func run(text: String, pid: int = 1) -> String:
	var parts: PackedStringArray = text.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var cmd: String = parts[0].to_lower()
	if not _commands.has(cmd):
		return "[color=#f88]Unknown command: %s[/color]" % cmd
	_ctx_pid = pid
	var result: Variant = (_commands[cmd]["fn"] as Callable).call(parts.slice(1))
	_ctx_pid = Net.local_player_id()
	return str(result) if result != null else ""


# ---------------------------------------------------------------- built-in commands

func _player() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Player).player_id == _ctx_pid:
			return n as Player
	return get_tree().get_first_node_in_group(&"players") as Player


func _director() -> ZombieDirector:
	return get_tree().get_first_node_in_group(&"director") as ZombieDirector


func _register_builtins() -> void:
	register("help", _cmd_help, "List commands")
	register("give_scrip", _cmd_give_scrip, "give_scrip <n>: add Scrip (default 10000)")
	register("round", _cmd_round, "round <n>: skip so the next round is n")
	register("god", _cmd_god, "Toggle god mode")
	register("noclip", _cmd_noclip, "Toggle noclip (fly with move keys + jump)")
	register("spawn", _cmd_spawn, "spawn [ganger] [n]: spawn zombies now")
	register("kill_all", _cmd_kill_all, "Kill every active zombie (no Scrip)")
	register("crawlers", _cmd_crawlers, "Turn active zombies into crawlers")
	register("give", _cmd_give, "give <weapon_id>: e.g. give mp40")
	register("refill", _cmd_refill, "Refill all ammo and grenades")
	register("open_doors", _cmd_open_doors, "Open every door")
	register("power_on", _cmd_power_on, "Turn the power on (runs the Hauptschalter sequence on Map 1)")
	register("pylons", _cmd_pylons, "Attune every Resonance Pylon (opens the Core Vault)")
	register("goto", _cmd_goto, "goto <zone>: teleport to a zone (A..I, e.g. goto F)")
	register("give_perks", _cmd_give_perks, "Give every perk (ignores cap, power, cost)")
	register("perk", _cmd_perk, "perk <id>: give one perk, e.g. perk ironhide_stout")
	register("perk_tier", _cmd_perk_tier, "perk_tier <id> <2|3>: set a carried perk's tier (no cost, no gate)")
	register("perk_mastery", _cmd_perk_mastery, "perk_mastery <id|all> <points>: add mastery (unlocks tiers)")
	register("powerup", _cmd_powerup, "powerup <id>: resupply|deaths_door|double_scrip|blackout|fortify|clearance")
	register("crate_move", _cmd_crate_move, "Move the Requisition Crate now")
	register("crate", _cmd_crate, "crate <weapon_id>: the next crate pull gives this weapon")
	register("fps", _cmd_fps, "Toggle FPS counter")
	register("zombies", _cmd_zombies, "Toggle live zombie count")
	register("navdebug", _cmd_navdebug, "Toggle navmesh debug drawing")
	register("timescale", _cmd_timescale, "timescale <x>")
	register("hp", _cmd_hp, "Show player health")
	register("traits", _cmd_traits, "traits [dutch|peg|deacon|wren]: set character for trait testing")
	register("quest", _cmd_quest, "quest list|skip <q> <step>|skipto <q> <step>|reset <q> [step]|reveal|seed <n>")
	register("exfil", _cmd_exfil, "exfil now|status: light the map's campaign beacon now (UPDATE 07)")
	register("act", _cmd_act, "act <1-4>: start Map 4 at that act (campaign mode, the act's arrival kit)")
	register("renewal", _cmd_renewal, "renewal now|clock: Map 4 Act IV: the bad ending now, or start its clock (UPDATE 07)")
	register("cancel", _cmd_cancel, "cancel now: Map 4 Act IV: the key turns, the canon ending runs (UPDATE 07)")
	register("campaign", _cmd_campaign, "campaign begin <map_id> [round]: start a campaign run there")
	register("boss", _cmd_boss, "boss <foreman|screamer>: summon a boss in front of you")
	register("spawn_boss", _cmd_spawn_boss, "spawn_boss cousins|hammer|reach|alix: start the Cousins Round now (Map 0), or one cousin alone")
	register("cousins", _cmd_cousins, "cousins [status|kill <hammer|reach|alix|all>|bored]: the Cousins Round")
	register("homage", _cmd_homage, "homage on|off: the Homage Bosses setting (this session)")
	register("homage_names", _cmd_homage_names, "homage_names real|world: the Homage Names setting (this session)")
	register("spawn_special", _cmd_spawn_special, "spawn_special <ganger|glasshide|bellringer|foreman|screamer> [n]")
	register("special_round", _cmd_special_round, "Make the next round a Bellringer round")
	register("bell_lit", _cmd_bell_lit, "Light the Chapel bell (as if shot with an upgraded weapon)")
	register("net", _cmd_net, "Co-op status: mode, your slot, the squad")
	MapDevCommands.register_all(self)   # bake_minimap / minimap (Update 04, T-065)


func _cmd_help(_a: PackedStringArray) -> String:
	var keys: Array = _commands.keys()
	keys.sort()
	var out: PackedStringArray = []
	for k: Variant in keys:
		out.append("  %-12s %s" % [k, _commands[k]["help"]])
	return "
".join(out)


func _cmd_give_scrip(a: PackedStringArray) -> String:
	var n: int = int(a[0]) if a.size() > 0 else 10000
	Economy.grant(_ctx_pid, n)
	return "Gave %d Scrip" % n


func _cmd_round(a: PackedStringArray) -> String:
	if a.is_empty():
		return "usage: round <n>"
	var d: ZombieDirector = _director()
	if d != null:
		for z: Zombie in d.active_zombies():
			z.deactivate()
			d.on_zombie_returned(z)
	RoundManager.debug_set_round(int(a[0]))
	return "Next round: %d" % int(a[0])


func _cmd_exfil(a: PackedStringArray) -> String:
	var pts: Array[Node] = get_tree().get_nodes_in_group(&"exfil_points")
	if pts.is_empty():
		return "No campaign beacon on this map (start it in campaign mode: `act <n>` or `campaign begin <map>`)."
	if not a.is_empty() and a[0] == "now":
		for x: Node in pts:
			x.call("trigger_now")
		return "Beacon lit."
	var x0: Node = pts[0]
	return "Beacon %s: state %s, next round %d" % [str(x0.get("cfg").get("label", "")), str(x0.get("state")), int(x0.call("next_round"))]


const ACT_MAPS: Array = ["map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]
const ACT_ROUNDS: Array = [1, 15, 21, 30]


func _cmd_act(a: PackedStringArray) -> String:
	if a.is_empty() or not a[0].is_valid_int() or int(a[0]) < 1 or int(a[0]) > 4:
		return "usage: act <1-4>"
	var i: int = int(a[0]) - 1
	var map_id: StringName = StringName(str(ACT_MAPS[i]))
	if not Campaign.scene_exists(map_id):
		return "Act %d (%s) is not built yet." % [i + 1, map_id]
	Campaign.begin_at(map_id, int(ACT_ROUNDS[i]), Campaign.arrival_kit(map_id))
	get_tree().change_scene_to_file.call_deferred(Campaign.scene_for(map_id))
	return "Starting %s at round %d." % [map_id, int(ACT_ROUNDS[i])]


func _mondlicht() -> Node:
	return get_tree().get_first_node_in_group(&"mondlicht_controller")


func _cmd_renewal(a: PackedStringArray) -> String:
	var ctl: Node = _mondlicht()
	if ctl == null:
		return "Not on Mondlicht (Map 4 Act IV)."
	var sub: String = a[0] if a.size() > 0 else "now"
	if sub == "clock":
		ctl.call("begin_renewal_clock")
		return "The renewal clock runs: %.0f s." % float(ctl.get("renewal_left"))
	ctl.call("start_renewal")
	return "Your plan has been renewed."


func _cmd_cancel(a: PackedStringArray) -> String:
	var ctl: Node = _mondlicht()
	if ctl == null:
		return "Not on Mondlicht (Map 4 Act IV)."
	if a.size() > 0 and a[0] != "now":
		return "usage: cancel now"
	var p: Player = _player()
	GameState.set_flag(&"manager_escalated")
	var console: Node = get_tree().get_first_node_in_group(&"account_console")
	if console != null and console.has_method("turn_key"):
		console.call("turn_key", p.player_id if p != null else 1)
	else:
		ctl.call("start_cancel", p.player_id if p != null else 1)
	return "The key turns. Nobody cancels... except you."


func _cmd_campaign(a: PackedStringArray) -> String:
	if a.size() < 2 or a[0] != "begin":
		return "usage: campaign begin <map_id> [round]"
	var map_id: StringName = StringName(a[1])
	if not Campaign.scene_exists(map_id):
		return "No scene for %s." % map_id
	var r: int = int(a[2]) if a.size() > 2 and a[2].is_valid_int() else 1
	Campaign.begin_at(map_id, r, Campaign.arrival_kit(map_id))
	get_tree().change_scene_to_file.call_deferred(Campaign.scene_for(map_id))
	return "Campaign run: %s at round %d." % [map_id, r]


func _cmd_god(_a: PackedStringArray) -> String:
	GameState.god_mode = not GameState.god_mode
	return "God mode %s" % ("ON" if GameState.god_mode else "off")


func _cmd_noclip(_a: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "No player"
	p.noclip = not p.noclip
	p.collision_mask = 0 if p.noclip else Player.MASK_MOVE
	return "Noclip %s" % ("ON" if p.noclip else "off")


func _cmd_spawn(a: PackedStringArray) -> String:
	var d: ZombieDirector = _director()
	if d == null:
		return "No director"
	var n: int = 1
	if a.size() > 0 and a[a.size() - 1].is_valid_int():
		n = int(a[a.size() - 1])
	d.debug_spawn(n)
	return "Spawned %d ganger" % n


func _cmd_kill_all(_a: PackedStringArray) -> String:
	var d: ZombieDirector = _director()
	if d != null:
		d.kill_all(true)
	return "Killed all"


func _cmd_crawlers(_a: PackedStringArray) -> String:
	var d: ZombieDirector = _director()
	if d != null:
		for z: Zombie in d.active_zombies():
			z.become_crawler()
	return "Every active zombie is now a crawler"


func _cmd_give(a: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or a.is_empty():
		return "usage: give <weapon_id>"
	var weps: Dictionary = GLData.table("weapons")
	if QUEST_ITEMS.has(a[0]):
		QuestManager.give_item(StringName(a[0]), _ctx_pid)
		return "Gave quest item " + a[0]
	if a[0].begins_with("tg_part_") or a[0].begins_with("ls_part_"):   # the Totenglocke's and the Lodestone's parts (T-105)
		GameState.set_flag(StringName("part_" + a[0]), true)
		GLBus.item_picked_up.emit(StringName(a[0]), _ctx_pid)
		return "Gave part " + a[0]
	if a[0] == "lodestone_parts" or a[0] == "totenglocke_parts":   # every part of a buildable at once
		var bid: StringName = StringName(a[0].trim_suffix("_parts"))
		for pid: Variant in BuildablePart.parts_of(bid):
			GameState.set_flag(StringName("part_" + String(pid)), true)
			GLBus.item_picked_up.emit(StringName(pid), _ctx_pid)
		return "Gave every %s part" % bid
	if weps["weapons"].has(a[0]) or (weps.get("upgraded", {}) as Dictionary).has(a[0]):
		p.weapons.give_weapon(StringName(a[0]))
	elif weps["melee"].has(a[0]):
		p.weapons.set_melee(StringName(a[0]))
	else:
		return "Unknown weapon. Options: " + ", ".join(PackedStringArray(weps["weapons"].keys()))
	return "Gave " + a[0]


const QUEST_ITEMS: PackedStringArray = ["overseers_key", "music_box", "nachtglas_shard"]


func _cmd_quest(a: PackedStringArray) -> String:
	if a.is_empty() or a[0] == "list":
		return QuestManager.describe()
	match a[0]:
		"reveal":
			return QuestManager.reveal()
		"seed":
			if a.size() < 2:
				return "match seed %d" % QuestManager.match_seed
			QuestManager.pending_seed = int(a[1])
			if Net.is_online():
				return "Seed %d is used by the next match" % int(a[1])
			get_tree().reload_current_scene()
			return "Restarting with seed %d" % int(a[1])
		"skip":
			if a.size() < 3:
				return "usage: quest skip <quest> <step>"
			return "ok" if QuestManager.debug_complete(StringName(a[1]), StringName(a[2])) else "no such quest/step"
		"skipto":
			if a.size() < 3:
				return "usage: quest skipto <quest> <step>"
			return "ok" if QuestManager.debug_skipto(StringName(a[1]), StringName(a[2])) else "no such quest/step"
		"reset":
			if a.size() < 2:
				return "usage: quest reset <quest> [step]"
			QuestManager.debug_reset(StringName(a[1]), StringName(a[2]) if a.size() > 2 else &"")
			return "reset"
	return "usage: quest list|skip|skipto|reset|reveal|seed"


func _cmd_boss(a: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "No player"
	var id: StringName = StringName(a[0]) if a.size() > 0 else &"foreman"
	QuestManager.summon_boss(id, p.global_position - p.global_basis.z * 8.0)
	return "Summoned " + String(id)


func _cousins() -> CousinsRound:
	var d: ZombieDirector = _director()
	return d.cousins if d != null else null


func _cmd_spawn_boss(a: PackedStringArray) -> String:
	var which: String = a[0] if a.size() > 0 else "cousins"
	var c: Dictionary = HomageBoss.cfg()
	if which == "cousins":
		var cr: CousinsRound = _cousins()
		if cr == null:
			return "The Cousins live on %s (Crossroads Inn); this is %s" % [str(c.get("map", "map00_crossroads")), String(GameState.map_id)]
		return cr.start_now()
	if not ["hammer", "reach", "alix"].has(which):
		return "usage: spawn_boss cousins|hammer|reach|alix"
	var p: Player = _player()
	if p == null:
		return "No player"
	QuestManager.summon_boss(StringName(which), p.global_position - p.global_basis.z * 8.0)
	return "Summoned %s alone" % which


func _cmd_cousins(a: PackedStringArray) -> String:
	var cr: CousinsRound = _cousins()
	if cr == null:
		return "No Cousins Round on this map"
	var sub: String = a[0] if a.size() > 0 else "status"
	match sub:
		"kill":
			var who: String = a[1] if a.size() > 1 else "all"
			for k: String in CousinsRound.KEYS:
				var b: HomageBoss = cr.boss(k)
				if b != null and (who == "all" or who == k):
					b.debug_kill(_ctx_pid)
			return cr.status()
		"bored":
			cr.retreat()
			return cr.status()
	return cr.status()


func _cmd_homage(a: PackedStringArray) -> String:
	if a.size() > 0:
		GLSettings.values["homage_bosses"] = a[0] != "off"
	return "Homage Bosses %s" % ("ON" if HomageBoss.homage_on() else "off")


func _cmd_homage_names(a: PackedStringArray) -> String:
	if a.size() > 0:
		GLSettings.values["homage_names"] = "world" if a[0].begins_with("w") or a[0] == "in-world" else "real"
	return "Homage Names: %s" % ("Real" if HomageBoss.names_real() else "In-World")


func _cmd_spawn_special(a: PackedStringArray) -> String:
	var d: ZombieDirector = _director()
	var p: Player = _player()
	if d == null or p == null or a.is_empty():
		return "usage: spawn_special <id> [n]"
	var n: int = int(a[1]) if a.size() > 1 else 3
	if not d.has_method("spawn_special"):
		return "spawn_special is not available"
	var made: Variant = d.call("spawn_special", StringName(a[0]), n, [p.global_position - p.global_basis.z * 8.0])
	return "Spawned %s %s" % [str(made), a[0]]


func _cmd_special_round(_a: PackedStringArray) -> String:
	if RoundManager.has_method("force_special_next"):
		RoundManager.call("force_special_next")
		return "Next round is a Bellringer round"
	return "Special rounds are not available"


func _cmd_bell_lit(_a: PackedStringArray) -> String:
	for b: Node in get_tree().get_nodes_in_group(&"quest_bells"):
		if b.get("kind") == &"chapel":
			b.call("on_shot", &"m1911_up", true, _ctx_pid)
			return "The Chapel bell is lit"
	return "No Chapel bell on this map"


func _cmd_refill(_a: PackedStringArray) -> String:
	var p: Player = _player()
	if p != null:
		p.weapons.refill_all()
	return "Ammo and grenades refilled"


func _cmd_open_doors(_a: PackedStringArray) -> String:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		(n as BuyDoor).open(0)
	return "All doors open"


func _cmd_power_on(_a: PackedStringArray) -> String:
	var sw: Node = get_tree().get_first_node_in_group(&"power_switch")
	if sw != null and sw.has_method("run_sequence"):
		sw.call("run_sequence", 1)
		return "Hauptschalter thrown"
	GameState.power_on = true
	GameState.set_flag(&"power_on", true)
	GLBus.power_activated.emit()
	return "Power on"


func _cmd_pylons(_a: PackedStringArray) -> String:
	var n: int = 0
	for p: Node in get_tree().get_nodes_in_group(&"pylons"):
		if p.has_method("debug_attune"):
			p.call("debug_attune")
			n += 1
	return "Attuned %d pylons" % n


const GOTO: Dictionary = {
	"A": Vector3(10, 0.2, 24), "B": Vector3(48, 0.2, 40), "C": Vector3(-8, 0.2, 18), "D": Vector3(20, 0.2, 40),
	"E": Vector3(25, 0.2, 47.5), "F": Vector3(12, -11.8, 70), "G": Vector3(62, -11.8, 77), "H": Vector3(77, -11.8, 90),
	"I": Vector3(34, -17.8, 106),
}


func _cmd_goto(a: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or a.is_empty() or not GOTO.has(a[0].to_upper()):
		return "usage: goto A|B|C|D|E|F|G|H|I (Map 1)"
	p.global_position = GOTO[a[0].to_upper()]
	p.velocity = Vector3.ZERO
	return "Moved to " + a[0].to_upper()


func _cmd_give_perks(_a: PackedStringArray) -> String:
	PerkManager.grant_all(_ctx_pid)
	return "All perks granted"


func _cmd_perk(a: PackedStringArray) -> String:
	if a.is_empty():
		return "usage: perk <id>. Options: " + ", ".join(PackedStringArray(GLData.table("perks")["perks"].keys()))
	PerkManager.grant(_ctx_pid, StringName(a[0]))
	return "Gave " + a[0]


func _cmd_perk_tier(a: PackedStringArray) -> String:
	if a.size() < 2:
		return "usage: perk_tier <id> <2|3>"
	if not PerkManager.has_perk(_ctx_pid, StringName(a[0])):
		PerkManager.grant(_ctx_pid, StringName(a[0]))
	PerkManager.set_tier(_ctx_pid, StringName(a[0]), int(a[1]))
	return "%s is now tier %d" % [a[0], PerkManager.tier_of(_ctx_pid, StringName(a[0]))]


func _cmd_perk_mastery(a: PackedStringArray) -> String:
	if a.size() < 2:
		return "usage: perk_mastery <id|all> <points>"
	var ids: Array = GLData.table("perks")["perks"].keys() if a[0] == "all" else [a[0]]
	for id: Variant in ids:
		PerkManager.add_mastery(StringName(str(id)), int(a[1]))
	return "Mastery added"


func _cmd_powerup(a: PackedStringArray) -> String:
	if a.size() > 0 and PowerupManager.force_drop(StringName(a[0])):
		return "Dropped " + a[0]
	return "usage: powerup resupply|deaths_door|double_scrip|blackout|fortify|clearance"


func _cmd_crate_move(_a: PackedStringArray) -> String:
	CrateManager.debug_move()
	return "Crate moved to spot %d" % CrateManager.location_index


func _cmd_crate(a: PackedStringArray) -> String:
	if a.is_empty():
		return "usage: crate <weapon_id|drummer>"
	CrateManager.debug_next = StringName(a[0])
	return "Next crate pull: " + a[0]


func _cmd_fps(_a: PackedStringArray) -> String:
	return _toggle_overlay(&"fps")


func _cmd_zombies(_a: PackedStringArray) -> String:
	return _toggle_overlay(&"zombies")


func _cmd_navdebug(_a: PackedStringArray) -> String:
	var on: bool = not NavigationServer3D.get_debug_enabled()
	NavigationServer3D.set_debug_enabled(on)
	get_tree().debug_navigation_hint = on
	return "Navmesh debug %s" % ("ON" if on else "off")


func _cmd_timescale(a: PackedStringArray) -> String:
	Engine.time_scale = clampf(float(a[0]) if a.size() > 0 else 1.0, 0.05, 8.0)
	return "Time scale %.2f" % Engine.time_scale


func _cmd_hp(_a: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "No player"
	return "HP %.0f / %.0f" % [p.hp, p.max_hp]


func _cmd_traits(a: PackedStringArray) -> String:
	if a.size() > 0:
		GameState.character_id = StringName(a[0])
	return "Character: %s (traits %s)" % [GameState.character_id, "on" if GameState.traits_enabled() else "off"]


func _cmd_net(_a: PackedStringArray) -> String:
	if not Net.is_online():
		return "Offline (solo)"
	var out: PackedStringArray = ["%s, you are player %d" % ["HOST" if Net.is_host() else "CLIENT", Net.local_player_id()]]
	for pid: int in Net.player_ids():
		var r: Dictionary = Net.roster[pid]
		out.append("  P%d %-7s peer %d %s" % [pid, Net.display_name(pid), int(r.get("peer", 0)), "ready" if bool(r.get("ready", false)) else ""])
	return "\n".join(out)


func _toggle_overlay(key: StringName) -> String:
	var on: bool = not bool(_overlays.get(key, false))
	_overlays[key] = on
	GLBus.dev_overlay_toggled.emit(key, on)
	return "%s overlay %s" % [key, "ON" if on else "off"]
