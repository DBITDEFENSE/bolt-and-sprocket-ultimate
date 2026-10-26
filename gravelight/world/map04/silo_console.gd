class_name SiloConsole
extends Interactable
## The silo control room's console (UPDATE 07, docs/MAP4_FERNFLUG.md §5.9): the LANTERN rocket's ignition key
## (the Test Pilot's drop, flag `ignition_key`) turns here (`rocket_key_turned`), then the burn sequence is
## entered (Fasbender's numbers from the radar shack, flag `burn_known`; a bot can do it once heard) and the
## rocket is ready (`rocket_ready`: the gantry lift's trigger flag). The act's round clock sets all three on its
## fallback round (GroomController) so the act can never softlock. Pure rule: `stage_of`.

var _lamps: Array[MeshInstance3D] = []


## Pure: "locked" (no key), "key" (turn it), "burn" (enter the sequence; needs burn_known), "ready".
static func stage_of(flags: Dictionary) -> String:
	if flags.has(&"rocket_ready"):
		return "ready"
	if flags.has(&"rocket_key_turned"):
		return "burn"
	if flags.has(&"ignition_key"):
		return "key"
	return "locked"


func _ready() -> void:
	interact_size = Vector3(4.2, 1.4, 1.8)
	interact_offset = Vector3(0, 0.7, 0)
	super._ready()
	add_to_group(&"silo_consoles")
	GLBus.flag_changed.connect(func(_f: StringName, _v: Variant) -> void: _refresh())


func build_greybox() -> void:
	var v: Node3D = Node3D.new()
	v.name = "Visual"
	add_child(v)
	add_box(v, Vector3(4.0, 1.1, 1.5), Vector3(0, 0.55, 0), greybox_mat(Color(0.3, 0.32, 0.3)))
	add_box(v, Vector3(3.6, 0.5, 0.1), Vector3(0, 1.3, -0.5), greybox_mat(Color(0.2, 0.2, 0.22)))
	for i: int in 3:
		_lamps.append(add_box(v, Vector3(0.12, 0.12, 0.04), Vector3(-0.6 + 0.6 * float(i), 1.3, -0.56), greybox_mat(Color(0.3, 0.1, 0.1), 0.5)))
	add_label(v, "LANTERN  ·  IGNITION  ·  BURN", Vector3(0, 1.75, -0.5), 20, Color(0.9, 0.85, 0.7, 0.9))
	_refresh()


func _refresh() -> void:
	var st: String = stage_of(GameState.flags)
	var lit: int = {"locked": 0, "key": 1, "burn": 2, "ready": 3}.get(st, 0)
	for i: int in _lamps.size():
		_lamps[i].material_override = greybox_mat(Color(0.3, 1.0, 0.4), 4.0) if i < lit else greybox_mat(Color(0.3, 0.1, 0.1), 0.5)


func get_prompt(_player: Player) -> String:
	var key: String = prompt_key(&"interact")
	match stage_of(GameState.flags):
		"locked":
			return "The ignition key is missing: the test pilot has it"
		"key":
			return "Hold [%s] to turn the ignition key" % key
		"burn":
			if GameState.has_flag(&"burn_known"):
				var b: Variant = GameState.flags.get(&"burn", [])
				var txt: String = ""
				if b is Array and (b as Array).size() >= 3:
					txt = " (%d · %d · %d)" % [int(b[0]), int(b[1]), int(b[2])]
				return "Hold [%s] to enter the burn sequence%s" % [key, txt]
			return "The burn numbers are not known: the radar shack's radio, with the power on"
	return ""


func can_interact(_player: Player) -> bool:
	var st: String = stage_of(GameState.flags)
	return st == "key" or (st == "burn" and GameState.has_flag(&"burn_known"))


func hold_time(player: Player) -> float:
	var t: float = 2.0 if stage_of(GameState.flags) == "key" else 4.0
	if player != null and GameState.player_has_trait(player.player_id, &"deacon"):
		t *= float((GLData.table("player")["traits"] as Dictionary).get("deacon_work_speed_mult", 0.85))
	return t


func interact(player: Player) -> void:
	if not can_interact(player) or not Net.is_authority():
		return
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	match stage_of(GameState.flags):
		"key":
			GameState.set_flag(&"rocket_key_turned")
			feedback_2d(player, "buy", -2.0)
			AudioDirector.play_3d("chain", global_position + Vector3.UP, -2.0)
			if GameState.has_trait(&"peg"):
				GLVO.play(&"PEG_M4C_ROCKET_01")
			if hud != null:
				hud.call("show_banner", "The key turns. The console wants the burn sequence.", 4.0)
			print("[m4c] ignition key turned by P%d" % player.player_id)
		"burn":
			GameState.set_flag(&"rocket_ready")
			feedback_2d(player, "buy", -2.0)
			if hud != null:
				hud.call("show_banner", "BURN SEQUENCE ENTERED\nThe gantry lift is live.", 5.0)
			if GameState.has_trait(&"peg") and not GameState.has_flag(&"peg_delivered"):
				GLVO.play(&"HAL_M4C_LAUNCH_01")
			print("[m4c] burn sequence entered by P%d: the rocket is ready" % player.player_id)
	_refresh()
