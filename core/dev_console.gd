class_name DevConsole
extends CanvasLayer
## Developer console, toggled with the `console` action (` key). Type a verb and arguments; `help` lists
## them. `host` is the running level (a BSLevel in Bolt & Sprocket); `mode` picks which verb set is live.
## Gravelight verbs are registered too: they run the host's console_<verb>() when the host has it and
## otherwise print "not in this mode". execute(line) returns the output (tests use it directly).

signal executed(line: String, output: String)

var host: Node = null
var mode: StringName = &"bs"
var is_open: bool = false
var history: PackedStringArray = []
var _verbs: Dictionary = {}       # verb -> [Callable(args: PackedStringArray) -> String, help]
var _panel: PanelContainer
var _log: Label
var _line_edit: LineEdit


func _init() -> void:
	_register()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", BSStyle.panel(Color(0.5, 1, 0.6), Color(0, 0, 0, 0.82), 6, 2))
	_panel.position = Vector2(20, 20)
	_panel.custom_minimum_size = Vector2(1100, 420)
	add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	_panel.add_child(v)
	_log = BSStyle.label("", 16, Color(0.7, 1, 0.75), 0)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.clip_text = true
	v.add_child(_log)
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "help"
	_line_edit.add_theme_font_size_override("font_size", 18)
	_line_edit.text_submitted.connect(_on_submit)
	v.add_child(_line_edit)
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"console"):
		toggle()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# the LineEdit swallows keys, so catch the toggle key here while it has focus
	if is_open and event is InputEventKey and (event as InputEventKey).pressed and event.is_action(&"console"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	is_open = not is_open
	_panel.visible = is_open
	if is_open:
		BS.ui_block += 1
		BSStyle.free_mouse()
		_line_edit.clear()
		_line_edit.grab_focus.call_deferred()
	else:
		BS.ui_block = maxi(0, BS.ui_block - 1)
		BSStyle.capture_mouse(get_tree())


func _exit_tree() -> void:
	if is_open:
		is_open = false
		BS.ui_block = maxi(0, BS.ui_block - 1)


func _on_submit(line: String) -> void:
	_line_edit.clear()
	execute(line)


func _print(s: String) -> void:
	history.append(s)
	if history.size() > 200:
		history = history.slice(history.size() - 200)
	if _log != null:
		_log.text = "\n".join(history.slice(maxi(0, history.size() - 18)))


## Runs one console line and returns its output.
func execute(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var verb: String = parts[0].to_lower()
	var args: PackedStringArray = parts.slice(1)
	var out: String
	if not _verbs.has(verb):
		out = "unknown command: %s (try help)" % verb
	else:
		out = str((_verbs[verb][0] as Callable).call(args))
	_print("> " + line)
	if out != "":
		_print(out)
	executed.emit(line, out)
	return out


func _add(verb: String, fn: Callable, help: String) -> void:
	_verbs[verb] = [fn, help]


func verbs() -> PackedStringArray:
	return PackedStringArray(_verbs.keys())


# ------------------------------------------------------------------ verbs

func _register() -> void:
	_add("help", _help, "help - list commands")
	_add("bolts", _bolts, "bolts <n> - give (or take, if negative) bolts")
	_add("give", _give, "give <weapon_id|all> - give a weapon")
	_add("level", _level, "level <weapon_id> <1-5> - set a weapon's V-level")
	_add("omega", _omega, "omega <weapon_id|all> - mark a weapon as Omega-evolved")
	_add("god", _god, "god [on|off] - toggle god mode")
	_add("tp", _tp, "tp <x> <y> <z> - teleport Bolt")
	_add("warp", _warp, "warp <level_id|res://scene.tscn> - load a planet (bs/planets/<id>/<id>.tscn)")
	_add("spawn", _spawn, "spawn <enemy_id> [count] - spawn an enemy 6 m in front of Bolt")
	_add("cutscene", _cutscene, "cutscene <id> - play a cutscene")
	_add("beat", _beat, "beat <id> - play a story beat (even if seen)")
	_add("quest", _quest, "quest <quest_id> [steps] - advance a side quest")
	_add("flag", _flag, "flag <id> [0|1] - set a story flag")
	_add("super", _super, "super - own Super Sprocket and fill the meter")
	_add("heal", _heal, "heal - full HP")
	_add("kill", _kill, "kill - kill every enemy")
	_add("complete", _complete, "complete - complete the level")
	_add("fps", _fps, "fps - toggle the FPS counter")
	_add("enemies", _enemies, "enemies - toggle the enemy counter")
	for gl: String in ["points", "round", "perk", "pap", "box", "power", "zombies"]:
		var v: String = gl
		_add(v, func(a: PackedStringArray) -> String: return _gravelight(v, a), "%s - Gravelight" % v)


func _help(_a: PackedStringArray) -> String:
	var lines: PackedStringArray = []
	var keys: Array = _verbs.keys()
	keys.sort()
	for k: Variant in keys:
		lines.append(str(_verbs[k][1]))
	return "\n".join(lines)


func _bs_only() -> String:
	return "" if mode == &"bs" else BSText.text("bs.ui.console.not_in_mode", "not in this mode")


func _bolt() -> Bolt:
	if host != null and "bolt" in host and host.get("bolt") is Bolt:
		return host.get("bolt") as Bolt
	return get_tree().get_first_node_in_group(&"player") as Bolt if is_inside_tree() else null


func _weapon_ids() -> PackedStringArray:
	if Data.has_table("bs/weapons"):
		var w: Dictionary = Data.table("bs/weapons") as Dictionary
		return PackedStringArray(w.get("order", (w.get("weapons", {}) as Dictionary).keys()))
	return PackedStringArray()


func _bolts(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty() or not a[0].is_valid_int():
		return "usage: bolts <n>"
	BS.add_bolts(a[0].to_int())
	return "bolts = %d" % BS.bolts


func _give(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty():
		return "usage: give <weapon_id|all>"
	var ids: PackedStringArray = _weapon_ids() if a[0] == "all" else PackedStringArray([a[0]])
	if a[0] != "all" and not _weapon_ids().is_empty() and not (a[0] in _weapon_ids()):
		return "unknown weapon: %s" % a[0]
	var b: Bolt = _bolt()
	var wm: Node = b.get_node_or_null("Weapons") if b != null else null
	for id: String in ids:
		if wm != null and wm.has_method("give"):
			wm.call("give", StringName(id))      # WeaponManager: builds the gun node and fills its ammo
		else:
			BS.give_weapon(StringName(id))
	return "gave %s" % ", ".join(ids)


func _level(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.size() < 2 or not a[1].is_valid_int():
		return "usage: level <weapon_id> <1-5>"
	if not BS.owns(StringName(a[0])):
		BS.give_weapon(StringName(a[0]))
	var lv: int = clampi(a[1].to_int(), 1, 5)
	var w: Dictionary = BS.weapons[a[0]]
	w["level"] = lv
	if Data.has_table("bs/weapons"):
		var th: Array = ((Data.table("bs/weapons") as Dictionary).get("progression", {}) as Dictionary).get("xp_thresholds", [])
		if th.size() >= lv:
			w["xp"] = int(th[lv - 1])
	EventBus.weapon_leveled.emit(StringName(a[0]), lv)
	return "%s is V%d" % [a[0], lv]


func _omega(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty():
		return "usage: omega <weapon_id|all>"
	var ids: PackedStringArray = PackedStringArray(BS.weapon_order) if a[0] == "all" else PackedStringArray([a[0]])
	var b: Bolt = _bolt()
	var wm: Node = b.get_node_or_null("Weapons") if b != null else null
	for id: String in ids:
		if not BS.owns(StringName(id)):
			BS.give_weapon(StringName(id))
		if wm != null and wm.has_method("evolve") and wm.has_method("give"):
			wm.call("give", StringName(id))
			wm.call("evolve", StringName(id), true)
		(BS.weapons[id] as Dictionary)["omega"] = true
	return "omega: %s" % ", ".join(ids)


func _god(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	BS.god_mode = (a[0] == "on") if not a.is_empty() else not BS.god_mode
	return "god mode %s" % ("ON" if BS.god_mode else "OFF")


func _tp(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.size() < 3 or not (a[0].is_valid_float() and a[1].is_valid_float() and a[2].is_valid_float()):
		return "usage: tp <x> <y> <z>"
	var b: Bolt = _bolt()
	if b == null:
		return "no Bolt in this scene"
	b.global_position = Vector3(a[0].to_float(), a[1].to_float(), a[2].to_float())
	b.last_safe = b.global_position
	b.motor.vel = Vector3.ZERO
	if b.camera != null:
		b.camera.snap_to(b)
	return "teleported to %s" % str(b.global_position)


static func level_path(id: String) -> String:
	return id if id.begins_with("res://") else "res://bs/planets/%s/%s.tscn" % [id, id]


func _warp(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty():
		return "usage: warp <level_id>"
	var p: String = level_path(a[0])
	if not ResourceLoader.exists(p):
		return "no such level: %s" % p
	if is_open:
		toggle()
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(p)
	return "warping to %s" % p


## EnemySpawner (enemy builder): an autoload node or a class with a static spawn(id, pos) -> Node3D.
static func enemy_spawner() -> Object:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var n: Node = tree.root.get_node_or_null("EnemySpawner") if tree != null else null
	if n != null and n.has_method("spawn"):
		return n
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c["class"]) == "EnemySpawner":
			var s: Script = load(str(c["path"])) as Script
			if s != null:
				return s
	return null


func _spawn(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty():
		return "usage: spawn <enemy_id> [count]"
	var sp: Object = enemy_spawner()
	if sp == null:
		return "EnemySpawner is not available yet"
	var b: Bolt = _bolt()
	var at: Vector3 = Vector3.ZERO
	if b != null:
		var f: Vector3 = Vector3(sin(b.motor.yaw), 0, cos(b.motor.yaw))
		at = b.global_position + f * 6.0
	var n: int = maxi(1, a[1].to_int()) if a.size() > 1 and a[1].is_valid_int() else 1
	var made: int = 0
	for i: int in n:
		var parent: Node = host if host != null else get_tree().current_scene
		var e: Variant = sp.call("spawn", StringName(a[0]), at + Vector3(float(i) * 1.5, 0, 0), parent)
		if e != null:
			made += 1
	return "spawned %d x %s" % [made, a[0]]


func _cutscene(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty():
		return "usage: cutscene <id>"
	if not CutscenePlayer.has_scene(a[0]):
		return "no such cutscene: %s" % a[0]
	if host == null or not host.has_method("play_cutscene"):
		return "no level to play it in"
	if is_open:
		toggle()
	host.call("play_cutscene", a[0])
	return "playing %s" % a[0]


func _beat(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty():
		return "usage: beat <id>"
	if host == null or not host.has_method("story_beat"):
		return "no level to play it in"
	BS.flags.erase("beat." + a[0])
	if is_open:
		toggle()
	return "playing %s" % a[0] if bool(host.call("story_beat", a[0])) else "no such beat: %s" % a[0]


## Advances a side quest's step count in SaveProfile.doc["bs"]["quests"] and emits quest_progress /
## quest_done (a quest system, when one exists, can listen to those or expose complete_step()).
func _quest(a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	if a.is_empty():
		return "usage: quest <quest_id> [steps]"
	var id: String = a[0]
	var steps: int = a[1].to_int() if a.size() > 1 and a[1].is_valid_int() else 1
	var qm: Node = get_tree().get_first_node_in_group(&"quests") if is_inside_tree() else null
	if qm != null and qm.has_method("complete_step"):
		for i: int in steps:
			qm.call("complete_step", id)
		return "quest %s +%d" % [id, steps]
	var need: int = -1
	var qs: Variant = Data.table("bs/story/quests")
	if qs is Array:
		for q: Variant in qs:
			if str((q as Dictionary).get("id", "")) == id:
				need = int((q as Dictionary).get("n", 1))
	if need < 0:
		return "no such quest: %s" % id
	var store: Dictionary = (SaveProfile.doc["bs"] as Dictionary)["quests"]
	var st: Dictionary = store.get(id, {"count": 0, "done": false})
	st["count"] = mini(need, int(st["count"]) + steps)
	EventBus.quest_progress.emit(id, int(st["count"]), need)
	if int(st["count"]) >= need and not bool(st["done"]):
		st["done"] = true
		EventBus.quest_done.emit(id)
	store[id] = st
	return "quest %s %d/%d%s" % [id, st["count"], need, " DONE" if st["done"] else ""]


func _flag(a: PackedStringArray) -> String:
	if a.is_empty():
		return "usage: flag <id> [0|1]"
	var v: bool = a.size() < 2 or a[1] != "0"
	BS.set_flag(a[0], v)
	return "%s = %s" % [a[0], v]


func _super(_a: PackedStringArray) -> String:
	if _bs_only() != "":
		return _bs_only()
	BS.super_owned = true
	BS.super_meter = 1.0
	EventBus.super_meter_changed.emit(1.0)
	return "Super Sprocket charged"


func _heal(_a: PackedStringArray) -> String:
	var b: Bolt = _bolt()
	if b == null:
		return "no Bolt in this scene"
	b.heal(b.max_hp)
	return "hp = %d" % int(b.hp)


func _kill(_a: PackedStringArray) -> String:
	if not is_inside_tree():
		return "not in a scene"
	var n: int = 0
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		if e.is_in_group(&"props") or not e.has_method("take_damage") or not e.call("is_alive"):
			continue
		var h: Combat.Hit = Combat.Hit.make(1.0e6)
		h.weapon_id = &"console"
		e.call("take_damage", h)
		n += 1
	return "killed %d" % n


func _complete(_a: PackedStringArray) -> String:
	if host == null or not host.has_method("complete_level"):
		return "no level to complete"
	if is_open:
		toggle()
	host.call("complete_level")
	return "level complete"


func _hud() -> Node:
	return host.get("hud") as Node if host != null and "hud" in host else null


func _fps(_a: PackedStringArray) -> String:
	var h: Node = _hud()
	if h == null:
		return "no HUD"
	h.set("show_fps", not bool(h.get("show_fps")))
	return "fps %s" % ("ON" if h.get("show_fps") else "OFF")


func _enemies(_a: PackedStringArray) -> String:
	var h: Node = _hud()
	if h == null:
		return "no HUD"
	h.set("show_enemies", not bool(h.get("show_enemies")))
	return "enemy count %s" % ("ON" if h.get("show_enemies") else "OFF")


func _gravelight(verb: String, a: PackedStringArray) -> String:
	if mode == &"gravelight" and host != null and host.has_method("console_" + verb):
		return str(host.call("console_" + verb, a))
	return BSText.text("bs.ui.console.not_in_mode", "not in this mode")
