extends Node
## Step 10 of "Requiem for Kaltenbrunn": the ending, cutscene-lite (the camera stays with the players).
## The heart collapses, the dead crumble, the lights blow out and come back, the train leaves (a banner in
## greybox), and the story lines play as subtitles. Then the step completes and the rewards land.
## Shots follow docs/VO_SCRIPT.md §7.

var quest_id: StringName = &"map01_requiem"
var step_id: StringName = &"s10_ending"
var params: Dictionary = {}

var _was_god: bool = false
## Co-op client: the host runs the ending; this copy only shows it (lights, heart, banners, shakes).
var _presentation: bool = false


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)   # T-142: no relief squad during a cutscene
	_presentation = Net.is_client()
	_was_god = GameState.god_mode
	if not _presentation:
		GameState.god_mode = true
	var total: float = float(params.get("seconds", 40.0))
	var k: float = total / 40.0
	_at(0.0, _shot_heart)
	_at(6.0 * k, _shot_collapse)
	_at(14.0 * k, _shot_montage)
	_at(22.0 * k, _shot_ledger)
	_at(28.0 * k, _shot_train)
	_at(34.0 * k, _shot_peg)
	_at(total, _finish)


func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, t)).timeout.connect(f)


func _banner(text: String, hold: float = 4.0) -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", text, hold)


func _shake(s: float) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		n.set("_shake", s)


func _heart() -> Node3D:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null("Geometry/Heart") as Node3D if scene != null else null


func _vo(id: StringName) -> void:
	if not _presentation:
		GLVO.play(id)   # relayed to the clients by VOManager


func _shot_heart() -> void:
	_vo(&"LSL_REC_HIDE_01")
	_shake(0.6)
	if _presentation:
		return
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			z.set_physics_process(false)


func _shot_collapse() -> void:
	var h: Node3D = _heart()
	if h != null:
		var tw: Tween = h.create_tween()
		tw.tween_property(h, "scale", Vector3(0.05, 0.05, 0.05), 3.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		Effects.explosion(h.global_position, 8.0)
	_shake(1.0)
	AudioDirector.play_2d("grenade_explode", 6.0, 0.0)
	# lights blow out in reverse power-on order
	var lights: Array[Node] = get_tree().get_nodes_in_group(&"power_lights")
	lights.reverse()
	var i: int = 0
	for l: Node in lights:
		var ol: OmniLight3D = l as OmniLight3D
		get_tree().create_timer(0.08 * float(i)).timeout.connect(func() -> void:
			ol.light_energy = 0.0
			ol.visible = false)  # hides the bulb/lamp glass parented under it
		i += 1


func _shot_montage() -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			Effects.blood(z.global_position + Vector3.UP, Vector3.UP)
		if not _presentation:
			dir.kill_all(true)
	_vo(&"OPR_QUEST_S9_END_01")


func _shot_ledger() -> void:
	_vo(&"OPR_QUEST_S10_01")
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		var ol: OmniLight3D = l as OmniLight3D
		ol.visible = true
		ol.light_energy = float(ol.get_meta("energy", 1.0)) * 0.6


func _shot_train() -> void:
	_banner("Rail Yard, dawn.\nA single carriage pulls out through the gates.", 5.0)
	AudioDirector.play_2d("door_open", -4.0, 0.0)
	_vo(&"REI_END_01")


func _shot_peg() -> void:
	_vo(&"REI_END_02")
	_vo(&"FAS_M1_ENDING_01")


func _finish() -> void:
	_banner("REQUIEM FOR KALTENBRUNN: COMPLETE\nTotenhafen: the trail leads north.", 6.0)
	if not _presentation:
		GameState.god_mode = _was_god
		QuestManager.complete_step(quest_id, step_id)
	queue_free()
