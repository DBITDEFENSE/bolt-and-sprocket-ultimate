extends Node
## Step 10 of "Requiem for Kaltenbrunn": the ending. Since T-184 a real cutscene on the shared CinemaDirector (it used
## to stay in the players' view): the squad is played by stand-ins at the pit, the HUD goes, the letterbox comes in,
## and the shots follow docs/VO_SCRIPT.md section 7:
##   0  the heart: low under the cage, a slow push; Liesl's whisper
##   6  the collapse: the wide from a pillar as the heart folds in on itself (the flash, the kick), then the reverse
##      on the squad's faces as the lights blow out in reverse power-on order
##   14 the dead fall: a slow orbit round the squad in the dark, a lantern's warmth on them; the Operator's last tape
##   22 the Ledger: the power comes back at 60 %, the cabinets; "I think I was somebody. Goodnight."
##   28 the rail yard at dawn, a carriage leaving (the whistle and the steam; Reinholt)
##   34 back to the squad: the crane up and away, Reinholt's last line and Fasbender's radio
## Then the black lifts into the game, the step completes and the rewards land (unchanged). Hold [interact] to skip:
## every beat's world effect still happens (the heart, the lights, the dead, the power) before the step completes.
## Co-op client: the host runs the ending; this copy only shows it (lights, heart, shots, banners).

var quest_id: StringName = &"map01_requiem"
var step_id: StringName = &"s10_ending"
var params: Dictionary = {}

var _was_god: bool = false
var _was_blocked: bool = false
## Co-op client: the host runs the ending; this copy only shows it (lights, heart, banners, shakes).
var _presentation: bool = false
var _dir: CinemaDirector = null
var _k: float = 1.0
var _total: float = 40.0
var _h: Vector3 = Vector3(34, -11, 116)
var _beats_done: Dictionary = {}
var _done: bool = false


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)   # T-142: no relief squad during a cutscene
	_presentation = Net.is_client()
	_was_god = GameState.god_mode
	_was_blocked = GameState.input_blocked
	if not _presentation:
		GameState.god_mode = true
	GameState.input_blocked = true   # the camera is the cutscene's; this peer's player waits (as in an exfil)
	_total = float(params.get("seconds", 40.0))
	_k = _total / 40.0
	var heart: Node3D = _heart()
	if heart != null:
		_h = heart.global_position
	var map: Node = get_tree().current_scene
	_dir = CinemaDirector.make(map if map != null else self, {"grade": "salt", "skip_after": 2.0,
		"music": {"stop": true, "stinger": "stinger_special", "stinger_db": -8.0}}, map, {"speed": 1.0, "vo": func(id: String) -> void: _vo(StringName(id))})
	_dir.skip_requested.connect(_skip)
	_at(0.0, _shot_heart)
	_at(6.0 * _k, _shot_collapse)
	_at(10.5 * _k, _shot_faces)
	_at(14.0 * _k, _shot_montage)
	_at(22.0 * _k, _shot_ledger)
	_at(28.0 * _k, _shot_train)
	_at(34.0 * _k, _shot_peg)
	_at(_total - 1.4 * _k, func() -> void:
		if _dir != null and is_instance_valid(_dir):
			_dir.overlay.fade(1.0, 1.2 * _k))
	_at(_total, _finish)


func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, t)).timeout.connect(func() -> void:
		if not _done:
			f.call())


func _shake(s: float) -> void:
	if _dir != null and is_instance_valid(_dir):
		_dir.cam.impulse(s)


func _heart() -> Node3D:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null("Geometry/Heart") as Node3D if scene != null else null


func _vo(id: StringName) -> void:
	if not _presentation:
		GLVO.play(id)   # relayed to the clients by VOManager


func _p(x: float, y: float, z: float) -> Array:
	return [_h.x + x, _h.y + y, _h.z + z]


func _shot(d: Dictionary, secs: float) -> void:
	if _dir != null and is_instance_valid(_dir):
		_dir.play_shot(d, secs * _k)


func _once(key: String) -> bool:
	if _beats_done.has(key):
		return false
	_beats_done[key] = true
	return true


## The heart, low under its cage (the floor is 7 m below it); the squad at the rim.
func _shot_heart() -> void:
	if not _once("heart"):
		return
	_shot({"from": _p(1.8, -5.6, 7.0), "to": _p(1.1, -5.7, 5.4), "look": _p(0, 0.2, 0), "look_to": _p(0, 0.5, 0),
		"fov": 46, "fov_to": 38, "handheld": 0.3, "grade": "violet", "blur": 0.5,
		"squad": {"place": _p(0, -7.0, 8.6), "face": _p(0, -6.0, 0)},
		"light": {"pos": _p(0, -1.0, 2.0), "color": [0.72, 0.5, 1.0], "energy": 1.2, "range": 9.0}}, 6.0)
	_vo(&"LSL_REC_HIDE_01")
	_shake(0.35)
	if _presentation:
		return
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			z.set_physics_process(false)


## The collapse: the wide from a pillar, the heart folds in on itself, the flash, the lights blow out.
func _shot_collapse() -> void:
	if not _once("collapse"):
		return
	_shot({"from": _p(8.5, -1.5, 13.0), "to": _p(7.5, -1.9, 11.8), "look": _p(0, -1.5, 0), "look_to": _p(0, -2.5, 1.0),
		"fov": 54, "fov_to": 50, "handheld": 0.22, "shake": [[0.15, 0.9], [2.8, 0.4]], "grade": "violet"}, 4.5)
	var h: Node3D = _heart()
	if h != null:
		var tw: Tween = h.create_tween()
		tw.tween_property(h, "scale", Vector3(0.05, 0.05, 0.05), 3.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		Effects.explosion(h.global_position, 8.0)
	AudioDirector.play_2d("grenade_explode", 6.0, 0.0)
	AudioDirector.play_2d("crucible_roar", 0.0, 0.0)
	# lights blow out in reverse power-on order
	var lights: Array[Node] = get_tree().get_nodes_in_group(&"power_lights")
	lights.reverse()
	var i: int = 0
	for l: Node in lights:
		var ol: OmniLight3D = l as OmniLight3D
		get_tree().create_timer(0.08 * float(i)).timeout.connect(func() -> void:
			if is_instance_valid(ol):
				ol.light_energy = 0.0
				ol.visible = false)  # hides the bulb/lamp glass parented under it
		i += 1


## The reverse: the squad's faces in the dark, the last violet light on them.
func _shot_faces() -> void:
	if not _once("faces"):
		return
	_shot({"from": _p(0.6, -5.4, 4.2), "to": _p(0.4, -5.3, 4.8), "look": _p(0, -5.6, 8.6), "target": "@squad",
		"fov": 40, "fov_to": 36, "handheld": 0.35, "grade": "night", "blur": 0.6,
		"light": {"pos": _p(0, -4.5, 5.0), "color": [0.6, 0.45, 1.0], "energy": 0.9, "range": 6.0}}, 3.5)


## The dead fall: a slow orbit round the squad in the dark, a lantern's warmth on them.
func _shot_montage() -> void:
	if not _once("montage"):
		return
	_shot({"move": "orbit", "from": _p(-3.4, -5.4, 12.6), "look": _p(0, -5.8, 8.6), "sweep": -38.0,
		"fov": 48, "handheld": 0.2, "grade": "night", "cut": "dip", "blend": 0.6,
		"light": {"pos": _p(-1.2, -5.2, 9.6), "color": [1.0, 0.7, 0.42], "energy": 1.3, "range": 6.0}}, 8.0)
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			Effects.blood(z.global_position + Vector3.UP, Vector3.UP)
		if not _presentation:
			dir.kill_all(true)
	_vo(&"OPR_QUEST_S9_END_01")


## The Ledger: the power comes back at 60 %, over the cabinets.
func _shot_ledger() -> void:
	if not _once("ledger"):
		return
	_shot({"from": _p(-3.2, -5.4, 16.4), "to": _p(-2.0, -5.5, 17.6), "look": _p(1.0, -6.0, 22.0), "look_to": _p(1.4, -5.9, 22.2),
		"fov": 50, "fov_to": 44, "handheld": 0.18, "grade": "salt", "cut": "dip", "blend": 0.5}, 6.0)
	_vo(&"OPR_QUEST_S10_01")
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		var ol: OmniLight3D = l as OmniLight3D
		ol.visible = true
		ol.light_energy = float(ol.get_meta("energy", 1.0)) * 0.6


## The rail yard at dawn: a single carriage pulls out through the gates (heard, and told in the caption).
func _shot_train() -> void:
	if not _once("train"):
		return
	_shot({"from": [41.5, 7.5, 11.0], "to": [43.5, 6.2, 14.0], "arc": 0.6, "look": [56.0, 1.6, 26.0], "look_to": [57.0, 1.4, 22.0],
		"fov": 52, "fov_to": 46, "handheld": 0.12, "grade": "dawn", "cut": "dip", "blend": 0.8,
		"caption": {"text": "Rail Yard, dawn. A single carriage pulls out through the gates.", "at": 0.6, "hold": 5.0}}, 6.0)
	if AudioDirector.has_sound("a1_train_whistle"):
		AudioDirector.play_2d("a1_train_whistle", -8.0, 0.0)
	if AudioDirector.has_sound("a1_train_steam"):
		get_tree().create_timer(0.9).timeout.connect(func() -> void: AudioDirector.play_2d("a1_train_steam", -6.0, 0.0))
	AudioDirector.play_2d("door_open", -4.0, 0.0)
	_vo(&"REI_END_01")


## Back with the squad: the crane up and away from them, Reinholt's last line and Fasbender's radio.
func _shot_peg() -> void:
	if not _once("peg"):
		return
	_shot({"from": _p(0.4, -5.3, 12.6), "to": _p(0.0, -1.8, 14.4), "arc": 0.6, "look": _p(0, -5.6, 8.6), "look_to": _p(0, -6.0, 6.0),
		"fov": 46, "fov_to": 52, "handheld": 0.14, "grade": "salt", "cut": "dip", "blend": 0.6,
		"squad": {"place": _p(0, -7.0, 8.6), "face": _p(0, -6.0, 0)}}, 6.0)
	_vo(&"REI_END_02")
	_vo(&"FAS_M1_ENDING_01")


## Hold to skip: every beat's world effect lands at once, then the ending finishes.
func _skip() -> void:
	if _done:
		return
	var h: Node3D = _heart()
	if h != null and not _beats_done.has("collapse"):
		h.scale = Vector3(0.05, 0.05, 0.05)
	_beats_done["collapse"] = true
	if not _beats_done.has("heart") and not _presentation:
		var d0: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if d0 != null:
			for z: Zombie in d0.active_zombies():
				z.set_physics_process(false)
	if not _beats_done.has("montage"):
		_beats_done["montage"] = true
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null and not _presentation:
			dir.kill_all(true)
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		var ol: OmniLight3D = l as OmniLight3D
		ol.visible = true
		ol.light_energy = float(ol.get_meta("energy", 1.0)) * 0.6
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _dir != null and is_instance_valid(_dir):
		_dir.release(true)
	GameState.input_blocked = _was_blocked
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "REQUIEM FOR KALTENBRUNN: COMPLETE\nTotenhafen: the trail leads north.", 6.0)
	if not _presentation:
		GameState.god_mode = _was_god
		QuestManager.complete_step(quest_id, step_id)
	queue_free()
