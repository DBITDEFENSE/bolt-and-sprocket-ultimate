class_name AdsRange
extends CanvasLayer
## "Weapon range — ADS check" (Update 02 §2, T-047): the Test Range with a gun list you cycle through by hand,
## a center dot that shows while aiming (the sights must sit on it) and a line naming the gun, its ADS zoom and
## eye relief. Keys: ] next gun, [ previous gun. The dev launcher starts it with:
##   AdsRange.launch(get_tree())                         # every gun, base then upgraded
##   AdsRange.launch(get_tree(), ["thompson", "mp40"])   # just these
## or, to go through its own start-up path (character, bots, god mode): AdsRange.arm([...]) and then start
## the Test Range scene as usual. The automated version of this check is tools/ads_check.sh.

const RANGE_SCENE: String = "res://gravelight/maps/test_range/test_range.tscn"

static var _pending: PackedStringArray = []

var guns: PackedStringArray = []
var _i: int = 0
var _player: Player
var _label: Label
var _dot: Control


## Starts the Test Range with the ADS-check overlay and `gun_ids` (empty = every gun).
static func launch(tree: SceneTree, gun_ids: Array = []) -> void:
	arm(gun_ids)
	GameState.god_mode = true
	tree.change_scene_to_file(RANGE_SCENE)


## Queues the overlay for the next match start (the Test Range scene must be started by the caller).
static func arm(gun_ids: Array = []) -> void:
	_pending = PackedStringArray(gun_ids)
	if _pending.is_empty():
		_pending = AdsRange.all_gun_ids()
	if not GLBus.match_started.is_connected(AdsRange._on_match_started):
		GLBus.match_started.connect(AdsRange._on_match_started, CONNECT_ONE_SHOT)


## Every gun id: the weapons table, then the upgraded table.
static func all_gun_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	var t: Dictionary = GLData.table("weapons")
	for k: Variant in (t["weapons"] as Dictionary).keys():
		out.append(str(k))
	for k2: Variant in (t.get("upgraded", {}) as Dictionary).keys():
		out.append(str(k2))
	return out


static func _on_match_started(_map_id: StringName) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var r: AdsRange = AdsRange.new()
	r.guns = _pending
	_pending = PackedStringArray()
	tree.current_scene.add_child.call_deferred(r)


func _ready() -> void:
	layer = 50
	_dot = _Dot.new()
	_dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dot)
	_label = Label.new()
	_label.position = Vector2(16, 44)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_equip.call_deferred(0)


func _find_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Player).is_local and not n.is_in_group(&"bots"):
			return n as Player
	return null


func _equip(i: int) -> void:
	if guns.is_empty():
		return
	_i = posmod(i, guns.size())
	_player = _find_player()
	if _player == null:
		return
	var h: WeaponHolder = _player.weapons
	h.slots.clear()
	h.give_weapon(StringName(guns[_i]))
	h.current_index = 0


func _unhandled_key_input(e: InputEvent) -> void:
	var k: InputEventKey = e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_BRACKETRIGHT:
		_equip(_i + 1)
	elif k.keycode == KEY_BRACKETLEFT:
		_equip(_i - 1)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		return
	var h: WeaponHolder = _player.weapons
	var w: WeaponInstance = h.current()
	_dot.visible = h.ads_t > 0.95 and not h.scoped()
	if w != null:
		_label.text = "ADS range  %d/%d  %s (%s)   zoom %.2f  eye relief %.2f m   [ / ] cycle guns" % [_i + 1, guns.size(),
			String(w.data.get("name", w.id)), String(w.id), h.ads_zoom(w), float(WeaponHolder.feel_for(w).get("eye_relief", 0.0))]


## The aim point the sights must sit on.
class _Dot extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 2.0, Color(1.0, 0.15, 0.1, 0.95))
