class_name RenewalEnding
extends Node
## "AUTO-RENEWAL", the bad ending (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §11.6, §6.8, T-113): the renewal
## clock ran out (or the act's fallback round came) before the key turned. ~40 s in the player's own view (a
## letterbox, no camera move), scaled by Campaign.cutscene_speed: the Operator's "Your plan has been renewed", the
## Manager's line, the Earth's night side going violet edge to edge, the squad's lines by presence, the card. Then
## the RETAINED state: GameState.retained (the HUD's violet tint, perks never lost on a down, no Second Wind, the
## dead one step tougher, the air posts dead, every round a Dust Storm), the Manager folds, the main egg is closed,
## the Archive files the ending as RENEWED, and the match goes on until the squad falls. Non-canon.

var cfg: Dictionary = {}
var finished: bool = false
var _layer: CanvasLayer
var _card: Label
var _k: float = 1.0
var _was_god: bool = false


## The Retained state's rules, pure: perks kept on a down, Second Wind gone, dust storms, dead posts.
static func retained_rules() -> Dictionary:
	return {"perks_kept_on_down": true, "second_wind": false, "special_every_round": true, "air_posts": false, "egg_closed": true}


func _ready() -> void:
	_k = 1.0 / maxf(0.01, Campaign.cutscene_speed)
	_was_god = GameState.god_mode
	if Net.is_authority():
		GameState.god_mode = true
	_build_layer()
	_at(0.2, _beat_timer)
	_at(5.0, _beat_manager)
	_at(12.0, _beat_earth)
	_at(24.0, _beat_squad)
	_at(32.0, _beat_card)
	_at(float(cfg.get("seconds", 40.0)), _finish)


func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, t * _k)).timeout.connect(f)


func _build_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.9
		bar.anchor_bottom = 0.1 if top else 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bar)
	_card = Label.new()
	_card.add_theme_font_override("font", MenuKit.stamp_font())
	_card.add_theme_font_size_override("font_size", MenuKit.size("display"))
	_card.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	MenuKit.outline(_card, "menu")
	_card.anchor_left = 0.1
	_card.anchor_right = 0.9
	_card.anchor_top = 0.38
	_card.anchor_bottom = 0.62
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card)


func _vo(id: String) -> void:
	if id != "" and Net.is_authority():
		GLVO.play(StringName(id))


func _shake(s: float) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		n.set("_shake", s)


func _beat_timer() -> void:
	_vo("OPR_M4D_RENEW_01")
	_shake(0.6)
	AudioDirector.play_2d("grenade_explode", -10.0, 0.0)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "0:00", 2.5)


func _beat_manager() -> void:
	_vo("WIV_M4D_RENEW_01")


func _beat_earth() -> void:
	var sky: Node = get_tree().get_first_node_in_group(&"earth_sky")
	if sky != null and sky.has_method("renew"):
		sky.call("renew")
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "The night side goes violet, edge to edge.", 5.0)


## The squad: Dutch first, then Peg (her answer), then the others, 2.5 s apart; the HUDs tint.
func _beat_squad() -> void:
	var present: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and not p.is_companion and p.is_alive():
			var c: String = String(GameState.character_of(p.player_id))
			if not present.has(c):
				present.append(c)
	var order: Array = ["dutch", "peg", "deacon", "wren"]
	var i: int = 0
	for c2: String in order:
		if not present.has(c2):
			continue
		var id: String = "%s_M4D_RENEW_01" % CancelEnding.speaker_code(StringName(c2))
		get_tree().create_timer((0.2 + 2.5 * float(i)) * _k).timeout.connect(func() -> void: _vo(id))
		i += 1
	if Net.is_authority():
		GameState.retained = true   # the tint comes on; the rules apply at the card


func _beat_card() -> void:
	var titles: Dictionary = (GLData.load_json("res://data/gravelight/cards_m4.json") if FileAccess.file_exists("res://data/gravelight/cards_m4.json") else {}).get("titles", {})
	_card.text = "%s\n%s" % [str(titles.get("renewal", "AUTO-RENEWAL")), str(titles.get("renewal_sub", "the match continues."))]
	_card.visible = true
	_card.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8 * _k)
	tw.tween_interval(5.0 * _k)
	tw.tween_property(_card, "modulate:a", 0.0, 1.0 * _k)


## The Retained state begins; the match goes on.
func _finish() -> void:
	if finished:
		return
	finished = true
	if Net.is_authority():
		GameState.god_mode = _was_god
		apply_retained(get_tree())
		ProfileSave.note_ending(str(cfg.get("profile_id", "renewed")))
		GameState.set_flag(&"egg_closed")
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", "RETAINED\nYour tonics stay. Nothing is required of you.", 5.0)
	GLBus.flag_changed.emit(&"renewal_ending_done", true)
	queue_free()


## The rules: no Second Wind, the posts dead, a storm every round, the Manager folded, the console dark.
static func apply_retained(tree: SceneTree) -> void:
	GameState.retained = true
	for pid: int in GameState.player_ids:
		if PerkManager.has_perk(pid, &"second_wind"):
			PerkManager.remove(pid, &"second_wind")
	AirPost.set_all(tree, false)
	RoundManager.force_special_next()
	var cb: Callable = Callable(RenewalEnding, &"_storm_next")
	if not GLBus.round_ended.is_connected(cb):
		GLBus.round_ended.connect(cb)
	var ctl: Node = tree.get_first_node_in_group(&"mondlicht_controller")
	if ctl != null:
		var boss: Node = ctl.get("boss")
		if boss != null and is_instance_valid(boss) and boss.has_method("escalate") and not bool(boss.get("escalated")):
			boss.call("escalate")
	var console: Node = tree.get_first_node_in_group(&"account_console")
	if console != null:
		console.set("state", AccountConsole.C.DONE)


static func _storm_next(_r: int) -> void:
	if GameState.retained and GameState.phase == GameState.Phase.PLAYING:
		RoundManager.force_special_next()
	elif not GameState.retained:
		var cb: Callable = Callable(RenewalEnding, &"_storm_next")
		if GLBus.round_ended.is_connected(cb):
			GLBus.round_ended.disconnect(cb)
