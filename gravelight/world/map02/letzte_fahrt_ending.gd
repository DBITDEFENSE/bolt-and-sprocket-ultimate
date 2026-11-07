extends Node
## Letzte Fahrt s10 (UPDATE 10 contract C3, design section 6, DECISIONS T-153, T-184): she dives at the depth mark. The
## shots play through the campaign cutscene player (ExfilCutscene with campaign.json cutscene `m2_letzte_fahrt_dive`
## and no exfil, on the shared CinemaDirector: Deacon cuts the diesels, the crew goes below and the hatches close, the
## wide shot in the storm with the Operator's only line, the dive, the cutter's lamp on the surface); U-1047's art
## sinks during the dive shot. Then the card: the Hale telegram in Peg's hand, typed onto the paper. Then the step
## completes (the quest's on_complete pays the rewards), the pen hall comes back and the match goes on (the
## campaign's exfil is unchanged). Hold [interact] to skip: the dive happens at once (its flag and signal as ever) and
## the card comes up; a second hold skips the card.
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
var _card_skip: CinemaOverlay = null
var _t: float = 0.0
var _total: float = 34.0
var _dive_at: float = 20.0
var _card_s: float = 6.0
var _dived: bool = false
var _carded: bool = false
var _done: bool = false


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)
	_presentation = Net.is_client()
	_was_god = GameState.god_mode
	if not _presentation:
		GameState.god_mode = true
	_total = float(params.get("seconds", 34.0))
	_dive_at = float(params.get("dive_at", 20.0))
	_card_s = float(params.get("card_seconds", 6.0))
	var scene: Node = get_tree().current_scene
	_boat_art = scene.get_node_or_null("Dressing/U1047") as Node3D if scene != null else null
	if _boat_art != null:
		_boat_y = _boat_art.position.y
	_cut = ExfilCutscene.new()
	_cut.cutscene_id = str(params.get("cutscene", "m2_letzte_fahrt_dive"))
	_cut.exfil = null
	_cut.skipped.connect(_skip)
	if scene != null:
		scene.add_child(_cut)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if not _dived and _t >= _dive_at:
		_dive()
	if not _carded and _t >= _total:
		_show_card()
	if _t >= _total + _card_s:
		_finish()


## Hold to skip: straight to the dive and the card (a second hold during the card ends it).
func _skip() -> void:
	if not _dived:
		_dive()
	_t = maxf(_t, _total)


func _dive() -> void:
	_dived = true
	AudioDirector.play_2d("hull_groan", 0.0, 0.0)
	if _boat_art != null:
		var tw: Tween = create_tween()
		tw.tween_property(_boat_art, "position:y", _boat_y - 9.0, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if not _presentation:
		GameState.set_flag(&"dived", true)
	GLBus.sail_dived.emit()


## The Hale telegram, in Peg's hand: the paper over black, the words typed onto it.
func _show_card() -> void:
	_carded = true
	if _cut != null and is_instance_valid(_cut):
		_cut.stop()
		_cut = null
	_card = CanvasLayer.new()
	_card.layer = 40
	add_child(_card)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.94)   # the dive faded to black: the card's ground stays black, no HUD flash
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(bg)
	var paper: ColorRect = ColorRect.new()
	paper.color = Color(0.86, 0.82, 0.7)
	paper.anchor_left = 0.3
	paper.anchor_right = 0.7
	paper.anchor_top = 0.33
	paper.anchor_bottom = 0.64
	paper.rotation = deg_to_rad(-1.2)
	paper.modulate.a = 0.0
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(paper)
	var rule: ColorRect = ColorRect.new()   # the post office's printed band
	rule.color = Color(0.55, 0.16, 0.14, 0.85)
	rule.anchor_right = 1.0
	rule.anchor_top = 0.16
	rule.anchor_bottom = 0.16
	rule.offset_bottom = 3.0
	paper.add_child(rule)
	var head: Label = Label.new()
	head.text = "TELEGRAMM"
	head.add_theme_font_override("font", MenuKit.stamp_font())
	head.add_theme_font_size_override("font_size", MenuKit.px(40))
	head.add_theme_color_override("font_color", Color(0.25, 0.1, 0.08))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.anchor_right = 1.0
	head.anchor_top = 0.02
	head.anchor_bottom = 0.16
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paper.add_child(head)
	var l: Label = Label.new()
	l.text = "BASEL  ·  HALE  ·  ON THE NEXT TIDE\n\n(Peg keeps it.)"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	l.anchor_top = 0.2
	l.anchor_bottom = 1.0
	l.add_theme_font_override("font", MenuKit.type_font())
	l.add_theme_font_size_override("font_size", MenuKit.px(30))
	l.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	l.visible_ratio = 0.0
	paper.add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(bg, "color:a", 0.94, 0.6)
	tw.parallel().tween_property(paper, "modulate:a", 1.0, 0.8).set_delay(0.3)
	tw.tween_callback(func() -> void: AudioDirector.play_2d("teletype_print", -6.0, 0.0))
	tw.tween_property(l, "visible_ratio", 1.0, 1.8)
	_card_skip = CinemaOverlay.new()   # "hold to skip" over the card as well
	_card_skip.skip_after = 0.8
	_card_skip.frame_layer = 41
	add_child(_card_skip)
	_card_skip.skip.connect(func() -> void: _t = maxf(_t, _total + _card_s))
	if not _presentation:
		GLVO.play(&"PEG_LF_TELEGRAM_01")


func _finish() -> void:
	if _done:
		return
	_done = true
	if _boat_art != null:
		_boat_art.position.y = _boat_y
	for n: Node in get_tree().get_nodes_in_group(&"uboat_sail"):
		if n.has_method("end_presentation"):
			n.call("end_presentation")
	if _cut != null and is_instance_valid(_cut):
		_cut.stop()
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map != null and map.player != null and map.player.camera != null:
		map.player.camera.current = true
	if map != null and map.hud != null:
		map.hud.show_banner("LETZTE FAHRT: COMPLETE\nThe cargo is in the deep. Basel will want to know who.", 6.0)
	if not _presentation:
		GameState.god_mode = _was_god
		QuestManager.complete_step(quest_id, step_id)
	queue_free()
