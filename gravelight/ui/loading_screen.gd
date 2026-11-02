class_name LoadingScreen
extends Control
## Shown while a map loads (UPDATE 09 section 7, DECISIONS T-144): the map's preview art full screen under a dark
## grade, its act and name, the date line, one lore line for the map and one tip (data/gravelight/tips.json), and a
## thin violet bar with the loader's progress. `LoadingScreen.go(tree, scene)` swaps to this screen and loads the
## map on a thread (ResourceLoader.load_threaded_request); MapPacks.ensure (the web build's pack fetcher, contract C4,
## T-139) runs first, its progress on the same bar (desktop: it returns at once). The screen stays at least MIN_SHOW_S so it can be read.
## Opened with no pending load (shots, tests) it just shows `demo_map`.

const SCENE: String = "res://gravelight/ui/loading_screen.tscn"
const TIPS_JSON: String = "res://data/gravelight/tips.json"
const MIN_SHOW_S: float = 1.2

static var pending: Dictionary = {}
static var _tips: Dictionary = {}

var demo_map: String = "map00_crossroads"
var map_id: String = ""
var scene_path: String = ""
var tip: String = ""
var lore: String = ""
var progress: float = 0.0
var _t: float = 0.0
var _requested: bool = false
var _done: bool = false
var _bar: ProgressBar
var _status: Label


## Swap to the loading screen and load `scene_path` behind it (map_id from MapCards when not given).
static func go(tree: SceneTree, scene: String, id: String = "", lore_override: String = "") -> void:
	if scene == "":
		return
	pending = {"scene": scene, "map_id": id if id != "" else MapCards.id_for_scene(scene), "lore": lore_override}
	tree.change_scene_to_file(SCENE)


## U10 §3 (T-157): the line for a transition (tips.json transition_lines "<from prefix>><to prefix>", e.g.
## "map04b>map04c" for the Kranich's crash), "" when it has none (the map's own lore line then).
static func transition_line(from_id: String, to_id: String) -> String:
	if from_id == "" or to_id == "":
		return ""
	var key: String = "%s>%s" % [from_id.get_slice("_", 0), to_id.get_slice("_", 0)]
	var l: Array = (cfg().get("transition_lines", {}) as Dictionary).get(key, []) as Array
	return str(l[randi() % l.size()]) if not l.is_empty() else ""


static func cfg() -> Dictionary:
	if _tips.is_empty():
		_tips = GLData.load_json(TIPS_JSON)
	return _tips


static func tips() -> Array:
	return cfg().get("tips", []) as Array


## One tip; `pick` < 0 = random.
static func pick_tip(pick: int = -1) -> String:
	var t: Array = tips()
	if t.is_empty():
		return ""
	return str(t[posmod(pick, t.size()) if pick >= 0 else randi() % t.size()])


static func lore_lines(id: String) -> Array:
	return (cfg().get("lore_lines", {}) as Dictionary).get(id, []) as Array


static func lore_line(id: String, pick: int = -1) -> String:
	var l: Array = lore_lines(id)
	if l.is_empty():
		return ""
	return str(l[posmod(pick, l.size()) if pick >= 0 else randi() % l.size()])


func _ready() -> void:
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:   # the scene root, or under a CanvasLayer / a plain Node (tools, tests): sized to the viewport
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		get_viewport().size_changed.connect(_fit)
		_fit()
	MenuKit.apply_theme(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var lore_override: String = ""
	if not pending.is_empty():
		scene_path = str(pending.get("scene", ""))
		map_id = str(pending.get("map_id", ""))
		lore_override = str(pending.get("lore", ""))
		pending = {}
	if map_id == "":
		map_id = demo_map
	tip = pick_tip()
	lore = lore_override if lore_override != "" else lore_line(lore_key if lore_key != "" else map_id)
	_build()
	if curtain_s > 0.0:
		_curtain_run()
	elif scene_path != "":
		_begin.call_deferred()


# ---- UPDATE 10 (T-158): transitions as events ----
# preload_scene: an exfil cutscene starts the next act loading on a thread while it plays (ExfilPoint), so the card
# that follows only waits for what is left; `_begin` reuses that request instead of asking again.
# curtain: the same card dropped over a scene as a curtain (the endings: the act's art, its name, a lore line keyed
# `lore_key`, `status` in place of the bar) for `curtain_s` seconds, then it lifts and frees itself.

static var preloaded: String = ""

var lore_key: String = ""
var curtain_s: float = 0.0
var curtain_status: String = ""


## Starts loading `path` on a thread now (an exfil cutscene's start). Safe to call twice.
static func preload_scene(path: String) -> bool:
	if path == "" or preloaded == path or not ResourceLoader.exists(path):
		return preloaded == path
	if ResourceLoader.load_threaded_request(path, "PackedScene", true) != OK:
		return false
	preloaded = path
	return true


## Drops the card for `id` over `parent` as a curtain (CanvasLayer `layer`) for `seconds`, lore from `lore_key`.
static func curtain(parent: Node, id: String, lore_key_: String, seconds: float, status: String = "", layer: int = 40) -> CanvasLayer:
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = layer
	cl.name = "Curtain"
	parent.add_child(cl)
	var ls: LoadingScreen = (load(SCENE) as PackedScene).instantiate() as LoadingScreen
	ls.map_id = id
	ls.lore_key = lore_key_
	ls.curtain_s = maxf(0.2, seconds)
	ls.curtain_status = status
	cl.add_child(ls)
	return cl


func _curtain_run() -> void:
	_done = true
	if _status != null:
		_status.text = curtain_status
	if _bar != null:
		_bar.visible = false
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, minf(0.8, curtain_s * 0.25))
	tw.tween_interval(curtain_s)
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func() -> void:
		var p: Node = get_parent()
		if p is CanvasLayer:
			p.queue_free()
		else:
			queue_free())


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.01, 0.012, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art: TextureRect = TextureRect.new()
	art.name = "Art"
	art.texture = MapCards.preview(map_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.78, 0.78, 0.82)
	add_child(art)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.02, 0.15))
	g.set_color(1, Color(0.0, 0.0, 0.02, 0.92))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.35)
	gt.fill_to = Vector2(0.0, 1.0)
	var grade: TextureRect = TextureRect.new()
	grade.texture = gt
	grade.stretch_mode = TextureRect.STRETCH_SCALE
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 96 if side in ["left", "right"] else 72)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var r: Dictionary = MapCards.row(map_id)
	var kick: Label = MenuKit.label(str(r.get("kicker", Game.GAME_MODE_NAME)), 22, MenuKit.VIOLET.lightened(0.2))
	kick.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 6))
	col.add_child(kick)
	var title: Label = MenuKit.text("display", str(r.get("name", map_id)).to_upper(), MenuKit.PAPER, "stamp")
	title.name = "MapName"
	col.add_child(title)
	col.add_child(MenuKit.label(str(r.get("date", "")), 24, MenuKit.DIM.lightened(0.15)))
	if lore != "":
		var lo: Label = MenuKit.para(lore, 24, MenuKit.PAPER.darkened(0.08))
		lo.name = "Lore"
		lo.custom_minimum_size = Vector2(1100, 0)
		lo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(lo)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	col.add_child(gap)
	var tip_row: HBoxContainer = HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 18)
	col.add_child(tip_row)
	tip_row.add_child(MenuKit.rule(52.0))
	var tip_col: VBoxContainer = VBoxContainer.new()
	tip_row.add_child(tip_col)
	var tl: Label = MenuKit.label("FIELD NOTE", 18, MenuKit.VIOLET.lightened(0.2))
	tl.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 5))
	tip_col.add_child(tl)
	var tp: Label = MenuKit.para(tip, 22, MenuKit.PAPER.darkened(0.1))
	tp.name = "Tip"
	tp.custom_minimum_size = Vector2(1100, 0)
	tip_col.add_child(tp)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	col.add_child(foot)
	_status = MenuKit.label("LOADING", 20, MenuKit.DIM)
	_status.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 4))
	_status.custom_minimum_size = Vector2(180, 0)
	foot.add_child(_status)
	_bar = MenuKit.bar(0.0, 900.0, MenuKit.VIOLET)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.custom_minimum_size = Vector2(900, 4)
	foot.add_child(_bar)


func _begin() -> void:
	# T-139 (contract C4): the browser build fetches the map's packs first; its progress drives this bar
	if MapPacks.pending():
		_status.text = "FETCHING"
		MapPacks.progress.connect(_on_pack_progress)
	var ok: bool = await MapPacks.ensure(scene_path)
	if MapPacks.progress.is_connected(_on_pack_progress):
		MapPacks.progress.disconnect(_on_pack_progress)
	if not ok:
		_status.text = "THE MAP COULD NOT BE FETCHED"
		_done = true
		await get_tree().create_timer(3.0).timeout
		if is_inside_tree():
			get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn")
		return
	if not is_inside_tree():
		return
	# T-158 / T-157: the exfil cutscene already started this load (LoadingScreen.preload_scene, via Campaign.preload_next)
	if preloaded == scene_path or Campaign.preloading == scene_path:
		preloaded = ""
		Campaign.preloading = ""
		_status.text = "LOADING"
		_requested = true
		return
	var err: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if err != OK:
		push_warning("LoadingScreen: threaded load refused (%d), loading %s directly" % [err, scene_path])
		_done = true
		get_tree().change_scene_to_file(scene_path)
		return
	_status.text = "LOADING"
	_requested = true


func _on_pack_progress(_pack: String, fraction: float, _bytes: int, _total: int) -> void:
	if _bar != null:
		_bar.value = fraction


func _process(delta: float) -> void:
	_t += delta
	if _status != null and not _done:
		_status.text = _status.text.rstrip(".") + ".".repeat(int(_t * 2.0) % 4)
	if not _requested or _done:
		return
	var prog: Array = []
	var st: int = ResourceLoader.load_threaded_get_status(scene_path, prog)
	if not prog.is_empty():
		progress = float(prog[0])
		_bar.value = progress
	if st == ResourceLoader.THREAD_LOAD_LOADED and _t >= MIN_SHOW_S:
		_done = true
		var ps: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
		_bar.value = 1.0
		get_tree().change_scene_to_packed.call_deferred(ps)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		push_warning("LoadingScreen: threaded load failed for %s, loading it directly" % scene_path)
		get_tree().change_scene_to_file.call_deferred(scene_path)
