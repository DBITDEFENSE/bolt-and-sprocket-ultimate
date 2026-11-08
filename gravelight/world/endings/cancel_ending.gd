class_name CancelEnding
extends Node
## "KÜNDIGUNG", the canon ending (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §11.5, T-113; shot like film since
## T-184 on the shared CinemaDirector): the key has turned (`key_pid` at the key). The squad is played by stand-ins, the
## HUD goes, the letterbox comes in, scaled by Campaign.cutscene_speed: the insert on the key and the two-shot of whoever
## turned it (Jakub's hand beside theirs), the relay cut (a low wide under the sign as the columns go dark, the hum
## stops mid-note, the sign's last letters go out; Dutch's line), the Manager's puzzlement from below her station, the
## Earth from the yard (from the squad's backs up to the violet freezing), the stock shots (dioramas built far below
## the relay: the inn, the chapel, the pens, the canteen, London, a shot per burned city; each a dip through black, a
## slow push, the colour drained), the Operator's last line over black, the epilogue cards typed onto the black
## (data/gravelight/cards_m4.json, per the flags and who is present), Wren's count and the last word (the squad low from
## the front, the Earth over them), the saga credits as the camera tilts up to the Earth (the game's theme under them),
## then the run ends (profile: endings_seen "kuendigung", the XP, the end screen). Nobody human dies. Hold [interact]
## to skip (always; ProfileSave "seen_kuendigung" is still recorded).

var key_pid: int = 1
var cfg: Dictionary = {}
var data: Dictionary = {}
var cards_shown: int = 0
var finished: bool = false
var _dir: CinemaDirector = null
var _cam: Camera3D
var _layer: CanvasLayer
var _card_label: Label
var _credits: Label
var _dioramas: Array[EndingDiorama] = []
var _was_god: bool = false
var _was_blocked: bool = false
var _seen_before: bool = false
var _k: float = 1.0
var _dio_base: Vector3 = Vector3(400, -300, 0)

## The cards for this run: the fixed ones, a line per city by its flags, a card per character present (Peg's by
## peg_delivered). `present` are character ids; `flags` GameState.flags.
static func card_list(d: Dictionary, present: Array, flags: Dictionary, jakub: bool) -> Array[String]:
	var cards: Dictionary = d.get("cards", {})
	var cities: Dictionary = d.get("cities", {})
	var out: Array[String] = []
	for key: Variant in d.get("card_order", []):
		var k: String = str(key)
		match k:
			"city_each":
				for c: String in cities.keys():
					if c == "boston":
						continue
					var nm: String = str(cities[c])
					if bool(flags.get(StringName("bomb_%s_hit" % c), false)):
						out.append(str(cards.get("city_burned", "%s")) % nm)
					elif bool(flags.get(StringName("bomb_%s_dud" % c), false)):
						out.append(str(cards.get("city_dud", "%s")) % nm)
					elif bool(flags.get(StringName("bomb_%s_saved" % c), false)):
						out.append(str(cards.get("city_saved", "%s")) % nm)
			"peg":
				if present.has("peg"):
					out.append(str(cards.get("peg_delivered" if bool(flags.get(&"peg_delivered", false)) else "peg_resigned", "")))
			"jakub":
				if jakub:
					out.append(str(cards.get("jakub", "")))
			"dutch", "deacon", "wren", "bolt", "vendelin":
				if present.has(k):
					out.append(str(cards.get(k, "")))
			_:
				if cards.has(k):
					out.append(str(cards[k]))
	var clean: Array[String] = []
	for c2: String in out:
		if c2 != "":
			clean.append(c2)
	return clean


## The stock shots: the fixed five, then one per burned city (Boston first).
static func diorama_list(d: Dictionary, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cities: Dictionary = d.get("cities", {})
	for row: Variant in d.get("dioramas", []):
		var r: Dictionary = row
		if bool(r.get("per_burned_city", false)):
			for c: String in cities.keys():
				if bool(flags.get(StringName("bomb_%s_hit" % c), false)):
					var rc: Dictionary = r.duplicate()
					rc["id"] = "city"
					rc["city"] = str(cities[c])
					rc["caption"] = str(r.get("caption", "%s")) % str(cities[c])
					out.append(rc)
		else:
			out.append(r)
	return out


static func speaker_code(character: StringName) -> String:
	return {&"dutch": "DUT", &"peg": "PEG", &"deacon": "DEA", &"wren": "WRN", &"bolt": "BLT", &"vendelin": "VEN"}.get(character, "")

func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)   # T-142: no relief squad during a cutscene
	var path: String = str(cfg.get("cards_file", "res://data/gravelight/cards_m4.json"))
	data = GLData.load_json(path) if FileAccess.file_exists(path) else {}
	_was_god = GameState.god_mode
	_was_blocked = GameState.input_blocked
	if Net.is_authority():
		GameState.god_mode = true
		RoundManager.stop()
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			dir.kill_all(true)
	GameState.input_blocked = true
	_seen_before = bool(ProfileSave.profile.get("seen_kuendigung", false))
	ProfileSave.profile["seen_kuendigung"] = true
	_k = 1.0 / maxf(0.01, Campaign.cutscene_speed)
	var map: Node = get_tree().current_scene
	_dir = CinemaDirector.make(self, {"grade": "space", "skip_after": 3.0, "far": 2000.0, "fade_in_s": 1.2, "mocap_scene": "cancel_ending",
		"music": {"stop": false, "bed": "amb_m4d_swell", "bed_db": -10.0}}, map, {"speed": Campaign.cutscene_speed, "vo": _vo})
	_dir.skip_requested.connect(_finish)
	_cam = _dir.cam
	_build_layer()
	_at(0.5, _beat_key)
	_at(10.0, _beat_relay)
	_at(22.0, _beat_manager)
	_at(30.0, _beat_earth)
	_at(40.0, _beat_dioramas)
	_at(80.0, _beat_operator)
	_at(88.0, _beat_cards)
	_at(128.0, _beat_last)
	_at(140.0, _beat_credits)
	_at(float(cfg.get("seconds", 150.0)) + 12.0, _finish)


func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, t * _k)).timeout.connect(func() -> void:
		if not finished:
			f.call())


func _console() -> Node3D:
	return get_tree().get_first_node_in_group(&"account_console") as Node3D


func _console_pos() -> Vector3:
	var c: Node3D = _console()
	return c.global_position if c != null else Vector3(28, 0, -30)


func _yard_pos() -> Vector3:
	var post: Node3D = get_tree().current_scene.find_child("EndingCam", true, false) as Node3D
	return post.global_position if post != null else Vector3(0, 2.0, 70)


func _sky_pos(from: Vector3) -> Vector3:
	var sky: Node3D = get_tree().get_first_node_in_group(&"earth_sky") as Node3D
	return sky.global_position if sky != null else from + Vector3(0, 60, 40)


static func _a(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _shot(d: Dictionary, secs: float) -> void:
	if _dir != null and is_instance_valid(_dir) and not finished:
		_dir.play_shot(d, secs)


## The epilogue cards and the credits ride over the frame (the bars, the black and the captions are the director's).
func _build_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 31
	add_child(_layer)
	_card_label = Label.new()
	_card_label.add_theme_font_override("font", MenuKit.type_font())
	_card_label.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	_card_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	_card_label.anchor_left = 0.2
	_card_label.anchor_right = 0.8
	_card_label.anchor_top = 0.35
	_card_label.anchor_bottom = 0.65
	_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_label.visible = false
	_card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card_label)
	_credits = Label.new()
	_credits.add_theme_font_override("font", MenuKit.stamp_font())
	_credits.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	_credits.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	MenuKit.outline(_credits, "menu")
	_credits.anchor_left = 0.15
	_credits.anchor_right = 0.85
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits.visible = false
	_credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_credits)


func _vo(id: String) -> void:
	if id != "" and Net.is_authority():
		GLVO.play(StringName(id))


func _caption_show(text: String, hold: float) -> void:
	if _dir != null and is_instance_valid(_dir):
		_dir.overlay.speed = Campaign.cutscene_speed
		_dir.overlay.caption(text, hold)


func _present_characters() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and not p.is_companion and p.is_alive():
			var c: String = String(GameState.character_of(p.player_id))
			if not out.has(c):
				out.append(c)
	return out


func _jakub_present() -> bool:
	return get_tree().get_first_node_in_group(&"jakub") != null


# ---------------------------------------------------------------- beats

## Shot 3: the hand on the key, the character's cancel line; Jakub's hand beside it. The insert on the console, then
## the two-shot of whoever turned it (and Jakub at their side) from across the desk.
func _beat_key() -> void:
	var c: StringName = GameState.character_of(key_pid)
	var code: String = speaker_code(c)
	var at: Vector3 = _console_pos()
	_shot({"from": _a(at + Vector3(-1.1, 1.3, 1.25)), "to": _a(at + Vector3(-0.85, 1.22, 0.95)), "look": _a(at + Vector3(0.2, 1.05, 0.1)),
		"fov": 40, "fov_to": 34, "handheld": 0.3, "blur": 0.7, "grade": "space", "mocap": "key", "mocap_only": [String(c), "jakub"],
		"squad": {"place": _a(at + Vector3(0.0, 0.0, 1.15)), "face": _a(at + Vector3(0, 1.2, 0)), "spread": 0.75},
		"light": {"pos": _a(at + Vector3(0.0, 1.6, 0.6)), "color": [1.0, 0.85, 0.65], "energy": 0.9, "range": 3.0}}, 4.5)
	get_tree().create_timer(4.5 * _k).timeout.connect(func() -> void:
		_shot({"from": _a(at + Vector3(1.7, 1.55, -1.6)), "to": _a(at + Vector3(1.45, 1.5, -1.35)), "look": _a(at + Vector3(-0.2, 1.45, 1.1)),
			"target": "@squad", "fov": 44, "fov_to": 40, "handheld": 0.25, "blur": 0.5, "mocap": "key", "mocap_only": [String(c), "jakub"]}, 5.5))
	if code == "BLT":
		_vo("BLT_M4D_CANCEL_01")
		get_tree().create_timer(3.0 * _k).timeout.connect(func() -> void: _vo("SPR_M4D_CANCEL_01"))
	elif code != "":
		_vo("%s_M4D_CANCEL_01" % code)
	if _jakub_present():
		get_tree().create_timer(4.0 * _k).timeout.connect(func() -> void: _vo("JAK_M4D_KEY_01"))
	_caption_show("The key turns.", 4.0)
	get_tree().create_timer(2.2 * _k).timeout.connect(func() -> void:
		AudioDirector.play_3d("door_open", at + Vector3.UP, 0.0, 0.0)
		if _cam != null:
			(_cam as CinemaCamera).impulse(0.25))


## Shot 4: the relay. The columns go dark, the hum stops mid-note, the sign's last letters go out, the miner's hand stops.
## A low wide of the hall under the sign, pushing in slowly as it goes dark.
func _beat_relay() -> void:
	var cols: Array[Node] = get_tree().get_nodes_in_group(&"retention_columns")
	cols.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("index")) < int(b.get("index")))
	var i: int = 0
	for col: Node in cols:
		var cn: Node = col
		get_tree().create_timer((0.6 + 1.2 * float(i)) * _k).timeout.connect(func() -> void:
			if is_instance_valid(cn) and not bool(cn.get("dark")):
				cn.call("read_terms", 0)
			if _cam != null:
				(_cam as CinemaCamera).impulse(0.12))
		i += 1
	get_tree().create_timer(4.5 * _k).timeout.connect(func() -> void:
		AudioDirector.stop_all_music()
		for n: Node in get_tree().get_nodes_in_group(&"retention_columns"):
			var hum: Node = n.get("_hum")
			if hum != null and is_instance_valid(hum):
				(hum as AudioStreamPlayer3D).stop()
		var sign: Node = get_tree().get_first_node_in_group(&"cancel_sign")
		if sign != null:
			sign.call("lights_out")
		if _cam != null:
			(_cam as CinemaCamera).impulse(0.3))
	var hall: Node3D = get_tree().get_first_node_in_group(&"cancel_sign") as Node3D
	var hp: Vector3 = hall.global_position if hall != null else _console_pos() + Vector3(0, 6, -10)
	_shot({"from": _a(hp + Vector3(1.5, -2.6, 25.0)), "to": _a(hp + Vector3(0.6, -2.3, 19.0)), "look": _a(hp + Vector3(0, -1.6, 0)),
		"look_to": _a(hp + Vector3(0, -2.2, 0)), "fov": 54, "fov_to": 46, "handheld": 0.16, "grade": "violet", "cut": "dip", "blend": 0.6}, 12.0)
	_caption_show("The columns go dark, one, two, three. The hum stops mid-note. Under the floor glass, the first retained miner's hand stops moving.", 10.0)
	if _present_characters().has("dutch"):
		get_tree().create_timer(7.0 * _k).timeout.connect(func() -> void: _vo("DUT_M4D_PILCH_02"))


## Shot 5: the Manager, folded; her puzzlement. Low, from below her station, the console's lights going to standby.
func _beat_manager() -> void:
	var st: Node3D = get_tree().current_scene.find_child("ManagerStation", true, false) as Node3D
	var sp: Vector3 = st.global_position if st != null else _console_pos() + Vector3(0, 0, -4)
	_shot({"from": _a(sp + Vector3(-2.6, 0.7, 4.2)), "to": _a(sp + Vector3(-2.1, 0.75, 3.5)), "look": _a(sp + Vector3(0, 2.0, 0)),
		"fov": 42, "fov_to": 38, "handheld": 0.12, "grade": "space", "cut": "dip", "blend": 0.5}, 8.0)
	_vo("WIV_M4D_END_01")
	_caption_show("The unit's lights go to standby.", 6.0)


## Shot 6: the Earth from the yard: the violet freezes, then fades city by city. From the squad's backs up to the sky.
func _beat_earth() -> void:
	var y: Vector3 = _yard_pos()
	var sky: Vector3 = _sky_pos(y)
	var up: Vector3 = (sky - y).normalized()
	var flat: Vector3 = Vector3(up.x, 0, up.z).normalized() if Vector2(up.x, up.z).length() > 0.05 else Vector3.FORWARD
	_shot({"from": _a(y - flat * 3.2 + Vector3(0.6, -0.4, 0)), "to": _a(y - flat * 3.6 + Vector3(0.3, -0.7, 0)),
		"look": _a(y + flat * 6.0 + Vector3(0, 0.2, 0)), "look_to": _a(sky), "look_ease": "quint",
		"fov": 50, "fov_to": 60, "handheld": 0.12, "grade": "violet", "cut": "dip", "blend": 0.8, "mocap": "earth",
		"squad": {"place": _a(y + flat * 1.2 + Vector3(0, -2.0, 0)), "face": _a(sky)}}, 10.0)
	var sk: Node = get_tree().get_first_node_in_group(&"earth_sky")
	if sk != null and sk.has_method("cut"):
		sk.call("cut")
	_caption_show("The violet on the night side freezes. Then it fades, city by city.", 9.0)


## Shots 7a–7f: the stock shots, built far below the relay, 6–8 s each: a dip through black into each, a slow push in,
## the colour drained like an old newsreel.
func _beat_dioramas() -> void:
	var list: Array[Dictionary] = diorama_list(data, GameState.flags)
	var t: float = 0.0
	var i: int = 0
	for row: Dictionary in list:
		var r: Dictionary = row
		var at: Vector3 = _dio_base + Vector3(0, 0, 60.0 * float(i))
		var d: EndingDiorama = EndingDiorama.build(get_tree().current_scene, str(r.get("id", "inn")), at)
		_dioramas.append(d)
		var secs: float = float(r.get("seconds", 6.0))
		var cap: String = str(r.get("caption", ""))
		get_tree().create_timer(maxf(0.01, t * _k)).timeout.connect(func() -> void:
			if not is_instance_valid(d) or finished:
				return
			var from: Vector3 = d.global_position + d.cam_pos
			var lk: Vector3 = d.global_position + d.cam_look
			_shot({"from": _a(from), "to": _a(from.lerp(lk, 0.14)), "look": _a(lk), "fov": 50, "fov_to": 46,
				"handheld": 0.1, "grade": "memory", "cut": "dip", "blend": 0.7}, secs)
			d.settle(_k)
			_caption_show(cap, secs))
		t += secs
		i += 1
		if t > 40.0:
			break


## Shot 8: black; the Operator's last line, the first unscripted thing it has ever said.
func _beat_operator() -> void:
	if _dir != null:
		_dir.overlay.speed = Campaign.cutscene_speed
		_dir.overlay.fade(1.0, 1.5)
	get_tree().create_timer(1.6 * _k).timeout.connect(func() -> void: _vo("OPR_M4D_LAST_01"))


## Shot 9: the epilogue cards, typed onto the black, ~4 s each.
func _beat_cards() -> void:
	var cards: Array[String] = card_list(data, _present_characters(), GameState.flags, _jakub_present())
	var per: float = 40.0 / maxf(1.0, float(cards.size()))
	_card_label.visible = true
	var i: int = 0
	for c: String in cards:
		var text: String = c
		get_tree().create_timer(maxf(0.01, per * float(i) * _k)).timeout.connect(func() -> void:
			if finished:
				return
			_card_label.text = text
			_card_label.modulate.a = 0.0
			_card_label.visible_ratio = 0.0
			cards_shown += 1
			var tw: Tween = create_tween()
			tw.tween_property(_card_label, "modulate:a", 1.0, 0.4 * _k)
			tw.parallel().tween_property(_card_label, "visible_ratio", 1.0, clampf(0.025 * float(text.length()), 0.4, 1.6) * _k)
			tw.tween_interval(maxf(0.1, per - 1.4) * _k)
			tw.tween_property(_card_label, "modulate:a", 0.0, 0.5 * _k))
		i += 1


## Shot 10: the yard; Wren's count, then the last word. The squad from the front, low, the Earth over their heads.
func _beat_last() -> void:
	_card_label.visible = false
	if _dir != null:
		_dir.overlay.fade(0.0, 1.5)
	var y: Vector3 = _yard_pos()
	var sky: Vector3 = _sky_pos(y)
	var flat: Vector3 = Vector3(sky.x - y.x, 0, sky.z - y.z).normalized() if Vector2(sky.x - y.x, sky.z - y.z).length() > 0.5 else Vector3.FORWARD
	var place: Vector3 = y + flat * 1.2 + Vector3(0, -2.0, 0)
	_shot({"from": _a(place + flat * 4.2 + Vector3(0.4, 0.5, 0)), "to": _a(place + flat * 3.6 + Vector3(0.3, 0.45, 0)),
		"look": _a(place + Vector3(0, 1.5, 0)), "look_to": _a(place + Vector3(0, 1.9, 0)), "target": "@squad", "target_offset": [0, 0.4, 0],
		"fov": 44, "fov_to": 40, "handheld": 0.16, "grade": "violet", "blur": 0.4, "mocap": "last",
		"squad": {"place": _a(place), "face": _a(place + flat * 6.0)}}, 12.0)
	var present: Array = _present_characters()
	if present.has("wren"):
		_vo("WRN_M4D_END_01")
	if present.has("dutch"):
		get_tree().create_timer((5.0 if present.has("wren") else 1.0) * _k).timeout.connect(func() -> void: _vo("DUT_M4D_LASTWORD_01"))
	_caption_show("Sixty-three. ...and one.", 6.0)


## Shot 11: the saga credits over the Earth from the yard: the camera tilts up off the squad to the Earth and holds.
func _beat_credits() -> void:
	var y: Vector3 = _yard_pos()
	var sky: Vector3 = _sky_pos(y)
	_shot({"move": "static", "from": _a(y + Vector3(0, -0.6, 0)), "look": _a(y + (sky - y).normalized() * 8.0 + Vector3(0, -2.0, 0)), "look_to": _a(sky),
		"look_ease": "sine", "fov": 58, "fov_to": 52, "handheld": 0.08, "grade": "space", "cut": "dip", "blend": 1.0, "mocap": "credits"}, 24.0)
	var lines: Array = data.get("credits", [])
	var text: String = ""
	for l: Variant in lines:
		text += str(l) + "\n"
	_credits.text = text
	_credits.visible = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_credits.position = Vector2(vp.x * 0.15, vp.y)
	_credits.size = Vector2(vp.x * 0.7, 0)
	var tw: Tween = create_tween()
	tw.tween_property(_credits, "position:y", -_credits.get_combined_minimum_size().y - 40.0, 20.0 * _k)
	if AudioDirector.has_sound("music_fernflug"):
		AudioDirector.play_music("music_fernflug", -2.0)
	elif AudioDirector.has_sound("music_menu"):
		AudioDirector.play_music("music_menu", -4.0)   # the game's own theme under the saga's credits


func _finish() -> void:
	if finished:
		return
	finished = true
	for d: EndingDiorama in _dioramas:
		if is_instance_valid(d):
			d.queue_free()
	GameState.input_blocked = _was_blocked
	if Net.is_authority():
		GameState.god_mode = _was_god
		ProfileSave.note_ending(str(cfg.get("profile_id", "kuendigung")))
		ProfileSave.add_xp(int(cfg.get("xp", 40000)))
		GameState.set_flag(&"kuendigung_done")
		GameState.phase = GameState.Phase.GAME_OVER
		RoundManager.stop()
	GLBus.flag_changed.emit(&"cancel_ending_done", true)
	# T-194 (UPDATE 11): the Moscow 1953 card (cutscenes_lazarus.json epilogue_1953) after the credits, then the end
	# screen; the ending's own frame and words leave first so the card has the screen to itself
	if _dir != null and is_instance_valid(_dir):
		_dir.queue_free()
		_dir = null
	if _layer != null:
		_layer.visible = false
	var scene: Node = get_tree().current_scene
	LazarusCinema.epilogue(scene, func() -> void:
		if not is_instance_valid(self) or not is_inside_tree():
			return
		_show_end_screen()
		# UPDATE 10 (T-158): the act's card falls as the curtain over the end screen, then lifts
		LoadingScreen.curtain(scene, "map04d_mondlicht", "ending_kuendigung", 4.0 * _k, "KÜNDIGUNG"))


func _show_end_screen() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var titles: Dictionary = data.get("titles", {})
	var screen: CanvasLayer = CanvasLayer.new()
	screen.layer = 40
	get_tree().current_scene.add_child(screen)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuKit.apply_theme(bg)
	screen.add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(760, 0)
	box.position = Vector2(-380, -200)
	box.add_theme_constant_override("separation", 16)
	MenuKit.apply_theme(box)
	screen.add_child(box)
	var title: Label = Label.new()
	title.text = str(titles.get("cancel", "KÜNDIGUNG"))
	title.add_theme_font_override("font", MenuKit.stamp_font())
	title.add_theme_font_size_override("font_size", MenuKit.size("display"))
	MenuKit.outline(title, "menu")
	title.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub: Label = Label.new()
	sub.text = "%s\nThe relay is cut. On Earth, the dead stop walking.\nRound %d. Nobody cancels... except you." % [str(titles.get("cancel_sub", "")), RoundManager.current_round]
	sub.add_theme_font_override("font", MenuKit.body_font())
	sub.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	sub.add_theme_color_override("font_color", Color(0.62, 0.45, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(MenuKit.button("To the menu", func() -> void:
		get_tree().paused = false
		GameState.phase = GameState.Phase.MENU
		get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn"), 22, "ui_confirm"))
	queue_free()
