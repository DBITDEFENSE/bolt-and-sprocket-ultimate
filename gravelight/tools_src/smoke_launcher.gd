extends Node
## Headless smoke test for the dev launcher's Map 4 buttons (UPDATE 07, T-116; PLAY.bat → ui/dev_launcher.tscn):
##   1. the launcher builds; the four Map 4 buttons exist ("full run", "skip to Act II / III / IV"), none disabled,
##      none marked "(not built yet)"
##   2. "skip to Act II" (DevLauncher._start_act): Campaign.begin_at with the arrival kit; der Kranich loads in
##      campaign mode, round 15 next ("ACT II · 1"), the kit's guns, perks, grenades and the launcher's Scrip on
##      the human, the bots the launcher chose, the cradle beacon dormant and due at round 20
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_launcher.tscn

const TIMEOUT: float = 120.0
const WANT: Array = ["Map 4 — Fernflug (full run: Act I from round 1)", "Map 4 — skip to Act II: der Kranich (round 15)",
	"Map 4 — skip to Act III: Groom Lake (round 21)", "Map 4 — skip to Act IV: Mondlicht (round 30)"]

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_launcher.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_launcher_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	Campaign.cutscene_speed = 12.0
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	print("[launcher] %-74s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _run() -> void:
	var launcher: Control = (load("res://ui/dev_launcher.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(launcher)
	get_tree().current_scene = launcher   # _start_act swaps the current scene (the launcher goes, this node stays)
	await _frames(3)
	var buttons: Dictionary = {}
	for n: Node in launcher.find_children("*", "Button", true, false):
		buttons[(n as Button).text] = n
	for w: String in WANT:
		var b: Button = buttons.get(w) as Button
		_check(b != null, "button exists: %s" % w)
		_check(b != null and not b.disabled, "button enabled: %s" % w)
	var unbuilt: PackedStringArray = []
	for t: Variant in buttons.keys():
		if str(t).begins_with("Map 4") and str(t).contains("not built"):
			unbuilt.append(str(t))
	_check(unbuilt.is_empty(), "no Map 4 button says '(not built yet)' (%s)" % ", ".join(unbuilt))
	var bots_chosen: int = (launcher.get("_bots") as OptionButton).selected
	launcher.call("_start_act", "map04b_kranich", 15)   # the "skip to Act II" button's call
	var loaded: bool = await _until(func() -> bool:
		var m: MapRoot = get_tree().current_scene as MapRoot
		return m != null and m.map_id == &"map04b_kranich" and m.is_node_ready(), 60.0)
	_check(loaded, "skip to Act II: der Kranich loaded")
	if not loaded:
		_finish()
		return
	await get_tree().create_timer(2.0).timeout
	var map: MapRoot = get_tree().current_scene as MapRoot
	var human: Player = map.player
	_check(Campaign.active and Campaign.pending_start_for(&"map04b_kranich").is_empty(), "campaign mode on, the pending start consumed")
	_check(RoundManager.current_round == 14 and RoundManager.state == RoundManager.State.BREAK and RoundManager.act_start == 15, "round 15 is next (round %d, act start %d)" % [RoundManager.current_round, RoundManager.act_start])
	_check(RoundManager.act_label(15) == "ACT II · 1", "round 15 reads 'ACT II · 1' (" + RoundManager.act_label(15) + ")")
	var kit: Dictionary = Campaign.arrival_kit(&"map04b_kranich")
	for w2: Array in kit.get("weapons", []):
		_check(human.weapons.find_weapon(StringName(str(w2[0]))) != null, "the kit's gun %s is on the human" % str(w2[0]))
	for perk: Variant in kit.get("perks", []):
		_check(PerkManager.owned(1).has(StringName(str(perk))), "the kit's perk %s" % str(perk))
	_check(human.weapons.grenades == int(kit.get("grenades", 0)), "the kit's grenades (%d)" % human.weapons.grenades)
	_check(Economy.get_scrip(1) == DevLauncher.scrip_for_round(15), "the launcher's Scrip for round 15 (%d)" % Economy.get_scrip(1))
	_check(GameState.bot_count == BotConfig.clamp_bots(BotConfig.cfg(), bots_chosen) and get_tree().get_nodes_in_group(&"bots").size() == GameState.bot_count, "the launcher's bots (%d) are on the map" % GameState.bot_count)
	var x: ExfilPoint = get_tree().get_first_node_in_group(&"exfil_points") as ExfilPoint
	_check(x != null and x.state == ExfilPoint.State.DORMANT and x.next_round() == 20, "the autopilot cradle is dormant, due at round 20")
	_check(GameState.god_mode == false, "god mode follows the launcher's box (off)")
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[launcher] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
