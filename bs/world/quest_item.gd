class_name QuestItem
extends Collectible
## A side-quest collectible (sandwich, fuse, ...). Shown and collectable only while its quest is active and
## not yet full; collecting adds one to the quest through QuestBook.current.

var quest_id: String = ""
var item: String = ""


func _ready() -> void:
	super._ready()
	_refresh()


func _process(delta: float) -> void:
	super._process(delta)
	_refresh()


func _refresh() -> void:
	var book: QuestBook = QuestBook.current
	var on: bool = book != null and is_instance_valid(book) and book.state(quest_id) == QuestBook.ACTIVE
	if on != visible:
		reveal(on)


func can_collect() -> bool:
	var book: QuestBook = QuestBook.current
	return book != null and is_instance_valid(book) and book.state(quest_id) == QuestBook.ACTIVE


func _on_collect(_bolt: Node) -> void:
	QuestBook.current.add_progress(quest_id, 1)


func _make_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	if item == "sandwich":
		LevelKit.box(root, Vector3(0, -0.08, 0), Vector3(0.42, 0.09, 0.42), "#d8a85a", false)
		LevelKit.box(root, Vector3(0, 0, 0), Vector3(0.44, 0.06, 0.44), "#4a9a3a", false)
		LevelKit.box(root, Vector3(0, 0.06, 0), Vector3(0.4, 0.06, 0.4), "#c25a4a", false)
		LevelKit.box(root, Vector3(0, 0.14, 0), Vector3(0.42, 0.09, 0.42), "#d8a85a", false)
	elif item == "fuse":
		LevelKit.cylinder(root, Vector3.ZERO, 0.12, 0.42, "#ffd27a", false, "y", -1.0, 1.2)
		LevelKit.cylinder(root, Vector3(0, 0.24, 0), 0.14, 0.08, "#9aa4b4", false)
		LevelKit.cylinder(root, Vector3(0, -0.24, 0), 0.14, 0.08, "#9aa4b4", false)
	else:
		LevelKit.box(root, Vector3.ZERO, Vector3(0.36, 0.36, 0.36), "#3ee6ff", false, Vector3.ZERO, 1, 1.0)
	return root
