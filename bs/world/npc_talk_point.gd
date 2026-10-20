class_name NPCTalkPoint
extends InteractPoint
## A townsperson. Quest givers (Rusty, Mama Gasket) run their quests in order: talking plays the quest's
## intro lines and starts it, its progress line while it's under way, then the done lines and the reward.
## Denizens (no quests) bark a random line from their pool when Bolt comes within bark_radius
## (cooldown bark_cd, as spawnDenizen/updateDenizens) and on interact. Lines play through LinePlayer/VOManager.

var npc_id: String = ""
var display_name: String = ""
var quests: PackedStringArray = []
var barks: PackedStringArray = []       # line ids
var idle_line: String = ""             # said once every quest is done
var bark_radius: float = 3.4
var bark_cd: float = 12.0
var body_color: Variant = "#9a8a6a"
var lines: LinePlayer = null
var _cd: float = 0.0
var talked: PackedStringArray = []      # line ids this NPC has said (tests)


func _ready() -> void:
	super._ready()
	add_to_group(&"npcs")
	_build_body()


func _build_body() -> void:
	var g: Node3D = Node3D.new()
	g.name = "Body"
	add_child(g)
	LevelKit.cylinder(g, Vector3(0, 0.55, 0), 0.32, 1.1, body_color)
	LevelKit.box(g, Vector3(0, 1.35, 0), Vector3(0.5, 0.42, 0.44), body_color)
	LevelKit.box(g, Vector3(0, 1.38, 0.23), Vector3(0.34, 0.1, 0.02), "#ffd27a", false, Vector3.ZERO, 1, 1.4)
	if not quests.is_empty():
		var lbl: Label3D = Label3D.new()
		lbl.text = display_name
		lbl.position.y = 2.0
		lbl.pixel_size = 0.005
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		g.add_child(lbl)


func prompt_text() -> String:
	return LevelKit.text("bs.level.talk_prompt").format({"name": display_name})


func _process(delta: float) -> void:
	super._process(delta)
	_cd -= delta
	if quests.is_empty() and not barks.is_empty() and _cd <= 0.0:
		var p: Node3D = LevelKit.player(get_tree())
		if p != null and p.global_position.distance_to(global_position + Vector3(0, 1, 0)) < bark_radius:
			_cd = bark_cd
			_say([barks[randi() % barks.size()]], true)


func _do_interact(_bolt: Node) -> void:
	talk()


## One conversation step. Returns the quest id it advanced ("" for a bark).
func talk() -> String:
	var book: QuestBook = QuestBook.current
	if book != null and is_instance_valid(book):
		for qid: String in quests:
			var st: String = book.state(qid)
			if st == QuestBook.DONE:
				continue
			if st == QuestBook.NONE:
				_say(book.lines(qid, "intro"))
				book.start(qid)
			elif st == QuestBook.ACTIVE:
				_say(book.lines(qid, "prog"))
			elif st == QuestBook.READY:
				_say(book.lines(qid, "done"))
				book.turn_in(qid)
			return qid
	if idle_line != "":
		_say([idle_line])
	elif not barks.is_empty():
		_say([barks[randi() % barks.size()]], true)
	return ""


func _say(ids: PackedStringArray, as_bark: bool = false) -> void:
	talked.append_array(ids)
	if as_bark:
		# barks follow Bolt's splash-quip convention: EventBus.bark(line_id); the HUD / Sprocket present them
		for id: String in ids:
			EventBus.bark.emit(id)
		return
	if lines != null and is_instance_valid(lines):
		lines.play_lines(ids)
	else:
		for id: String in ids:
			LinePlayer.speak_now(id)
