class_name RenewalEnding
extends Node
## "AUTO-RENEWAL", the bad ending (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §11.6, §6.8, T-113): the renewal
## clock ran out (or the act's fallback round came) before the key turned. ~40 s, scaled by Campaign.cutscene_speed,
## mostly in the player's own view (the match goes on around them, so the HUD stays and the hands stay theirs): the
## letterbox slides in with a kick on "Your plan has been renewed", the Manager's line, then (T-184) one insert: the
## camera leaves for the yard and looks up as the Earth's night side goes violet edge to edge (8 s; input waits, hold
## [interact] to cut back early), the grade going violet with it; back in their eyes for the squad's lines by
## presence, and the AUTO-RENEWAL card in the title-card treatment. Then the RETAINED state: GameState.retained (the
## HUD's violet tint, perks never lost on a down, no Second Wind, the dead one step tougher, the air posts dead,
## every round a Dust Storm), the Manager folds, the main egg is closed, the Archive files the ending as RENEWED, and
## the match goes on until the squad falls. Non-canon.

const INSERT_S: float = 8.0

var cfg: Dictionary = {}
var finished: bool = false
var _dir: CinemaDirector = null
var _k: float = 1.0
var _was_god: bool = false
var _was_blocked: bool = false
var _in_insert: bool = false


## The Retained state's rules, pure: perks kept on a down, Second Wind gone, dust storms, dead posts.
static func retained_rules() -> Dictionary:
	return {"perks_kept_on_down": true, "second_wind": false, "special_every_round": true, "air_posts": false, "egg_closed": true}


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)   # T-142: no relief squad during a cutscene
	_k = 1.0 / maxf(0.01, Campaign.cutscene_speed)
	_was_god = GameState.god_mode
	_was_blocked = GameState.input_blocked
	if Net.is_authority():
		GameState.god_mode = true
	var map: Node = get_tree().current_scene
	_dir = CinemaDirector.make(map if map != null else self, {"grade": "neutral", "fade_in_s": 0.0, "music": {"stop": false}}, map,
		{"speed": Campaign.cutscene_speed, "cast": false, "hide_hud": false, "camera_now": false, "vo": _vo})
	_dir.overlay.skip_enabled = false   # the player's hands are their own outside the insert ([interact] buys)
	_dir.skip_requested.connect(_end_insert)
	_at(0.2, _beat_timer)
	_at(5.0, _beat_manager)
	_at(12.0, _beat_earth)
	_at(12.0 + INSERT_S, _end_insert)
	_at(24.0, _beat_squad)
	_at(32.0, _beat_card)
	_at(float(cfg.get("seconds", 40.0)), _finish)


func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, t * _k)).timeout.connect(func() -> void:
		if not finished:
			f.call())


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
	AudioDirector.play_stinger("stinger_special", -6.0)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "0:00", 2.5)


func _beat_manager() -> void:
	_vo("WIV_M4D_RENEW_01")


## The insert: the yard, looking up as the night side goes violet. Input waits for its 8 s (god mode is on).
func _beat_earth() -> void:
	var sky: Node3D = get_tree().get_first_node_in_group(&"earth_sky") as Node3D
	if sky != null and sky.has_method("renew"):
		sky.call("renew")
	var post: Node3D = get_tree().current_scene.find_child("EndingCam", true, false) as Node3D
	var y: Vector3 = post.global_position if post != null else Vector3(0, 2.0, 70)
	var sp: Vector3 = sky.global_position if sky != null else y + Vector3(0, 60, 40)
	var flat: Vector3 = Vector3(sp.x - y.x, 0, sp.z - y.z).normalized() if Vector2(sp.x - y.x, sp.z - y.z).length() > 0.5 else Vector3.FORWARD
	_in_insert = true
	_dir.overlay.hide_hud(get_tree().current_scene)   # the Earth without a crosshair over it
	GameState.input_blocked = true
	_dir.overlay.skip_enabled = true
	_dir.play_shot({"from": [y.x - flat.x * 2.0, y.y - 0.6, y.z - flat.z * 2.0], "to": [y.x - flat.x * 2.6, y.y - 0.9, y.z - flat.z * 2.6],
		"look": [y.x + flat.x * 8.0, y.y + 0.5, y.z + flat.z * 8.0], "look_to": [sp.x, sp.y, sp.z], "look_ease": "quint",
		"fov": 52, "fov_to": 62, "handheld": 0.12, "grade": "violet", "grade_s": 5.0,
		"caption": {"text": "The night side goes violet, edge to edge.", "at": 1.5, "hold": 5.5}}, INSERT_S)


## Back in the player's eyes (the violet stays in the grade, softer, until the card).
func _end_insert() -> void:
	if not _in_insert:
		return
	_in_insert = false
	GameState.input_blocked = _was_blocked
	_dir.overlay.skip_enabled = false
	_dir.back_to_player()
	_dir.overlay.restore_hud()
	_dir.overlay.grade({"exposure": 1.0, "contrast": 1.05, "saturation": 0.9, "tint": [1.0, 0.93, 1.06], "vignette": 0.3}, 1.5)


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


## The card, in the arrival cards' treatment, violet.
func _beat_card() -> void:
	var titles: Dictionary = (GLData.load_json("res://data/gravelight/cards_m4.json") if FileAccess.file_exists("res://data/gravelight/cards_m4.json") else {}).get("titles", {})
	_dir.overlay.title_card(str(titles.get("renewal", "AUTO-RENEWAL")), str(titles.get("renewal_sub", "the match continues.")), "", 6.5)
	AudioDirector.play_stinger("stinger_round_end_special", -6.0)


## The Retained state begins; the match goes on.
func _finish() -> void:
	if finished:
		return
	finished = true
	if _in_insert:
		_end_insert()
	GameState.input_blocked = _was_blocked
	if _dir != null and is_instance_valid(_dir):
		_dir.release(true)   # (under the map: the bars slide out after this node is gone)
	if Net.is_authority():
		GameState.god_mode = _was_god
		apply_retained(get_tree())
		ProfileSave.note_ending(str(cfg.get("profile_id", "renewed")))
		GameState.set_flag(&"egg_closed")
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", "RETAINED\nYour tonics stay. Nothing is required of you.", 5.0)
	GLBus.flag_changed.emit(&"renewal_ending_done", true)
	# UPDATE 10 (T-158): the act's card falls as a curtain between the renewal and the Retained match
	LoadingScreen.curtain(get_tree().current_scene, "map04d_mondlicht", "ending_renewed", 3.0, "RETAINED")
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
