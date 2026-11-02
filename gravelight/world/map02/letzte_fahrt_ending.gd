extends Node
## Letzte Fahrt s10 (UPDATE 10 contract C3, design section 6, DECISIONS T-153): she dives at the depth mark. The shots
## play through the campaign cutscene player (ExfilCutscene with campaign.json cutscene `m2_letzte_fahrt_dive` and no
## exfil: Deacon cuts the diesels, the crew goes below and the hatches close, the wide shot in the storm with the
## Operator's only line, the dive, the cutter's lamp on the surface); U-1047's art sinks during the dive shot. Then the
## card: the Hale telegram in Peg's hand. Then the step completes (the quest's on_complete pays the rewards), the pen
## hall comes back and the match goes on (the campaign's exfil is unchanged).
## Co-op: the host's copy completes the step; every peer's copy shows the shots and the card.

var quest_id: StringName = &"map02_letzte_fahrt"
var step_id: StringName = &"s10_ending"
var params: Dictionary = {}

var _presentation: bool = false
var _was_god: bool = false
var _cut: ExfilCutscene = null
var _boat_art: Node3D = null
var _boat_y: float = 0.0
var _card: CanvasLayer = null


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)
	_presentation = Net.is_client()
	_was_god = GameState.god_mode
	if not _presentation:
		GameState.god_mode = true
	var total: float = float(params.get("seconds", 34.0))
	var scene: Node = get_tree().current_scene
	_boat_art = scene.get_node_or_null("Dressing/U1047") as Node3D if scene != null else null
	if _boat_art != null:
		_boat_y = _boat_art.position.y
	_cut = ExfilCutscene.new()
	_cut.cutscene_id = str(params.get("cutscene", "m2_letzte_fahrt_dive"))
	_cut.exfil = null
	if scene != null:
		scene.add_child(_cut)
	_at(float(params.get("dive_at", 20.0)), _dive)
	_at(total, _show_card)
	_at(total + float(params.get("card_seconds", 6.0)), _finish)


func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, t)).timeout.connect(f)


func _dive() -> void:
	AudioDirector.play_2d("hull_groan", 0.0, 0.0)
	if _boat_art != null:
		var tw: Tween = create_tween()
		tw.tween_property(_boat_art, "position:y", _boat_y - 9.0, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if not _presentation:
		GameState.set_flag(&"dived", true)
	GLBus.sail_dived.emit()


## The Hale telegram, in Peg's hand (a card over the screen).
func _show_card() -> void:
	if _cut != null and is_instance_valid(_cut):
		_cut.stop()
		_cut = null
	_card = CanvasLayer.new()
	_card.layer = 40
	add_child(_card)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(bg)
	var paper: ColorRect = ColorRect.new()
	paper.color = Color(0.86, 0.82, 0.7)
	paper.anchor_left = 0.3
	paper.anchor_right = 0.7
	paper.anchor_top = 0.36
	paper.anchor_bottom = 0.62
	_card.add_child(paper)
	var l: Label = Label.new()
	l.text = "TELEGRAMM\n\nBASEL · HALE · ON THE NEXT TIDE\n\n(Peg keeps it.)"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	paper.add_child(l)
	if not _presentation:
		GLVO.play(&"PEG_LF_TELEGRAM_01")


func _finish() -> void:
	if _boat_art != null:
		_boat_art.position.y = _boat_y
	for n: Node in get_tree().get_nodes_in_group(&"uboat_sail"):
		if n.has_method("end_presentation"):
			n.call("end_presentation")
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map != null and map.player != null and map.player.camera != null:
		map.player.camera.current = true
	if map != null and map.hud != null:
		map.hud.show_banner("LETZTE FAHRT: COMPLETE\nThe cargo is in the deep. Basel will want to know who.", 6.0)
	if not _presentation:
		GameState.god_mode = _was_god
		QuestManager.complete_step(quest_id, step_id)
	queue_free()
