class_name GadgetManager
extends Node
## Bolt's gadget belt (BS_LEVELS §0.5). One per Bolt, a child named "Gadgets":
##   GadgetManager.attach_to(bolt) -> GadgetManager   (idempotent; a level calls it in on_level_ready)
##   GadgetManager.owns(&"tether_hook")               BS flag "gadget.<id>"
##   GadgetManager.grant(&"tether_hook")              sets the flag, saves, unlocks "bs.gadget.<id>", and adds
##                                                    the gadget to every live manager (group "gadget_managers")
##   manager.press(id = "") -> bool                   what the "gadget" input does (tests / the smoke call it)
##   manager.get_gadget(id) -> Gadget                 manager.busy() -> bool
## Gadget definitions and tuning: data/bs/gadgets.json ("gadgets", in "order"). The "gadget" action presses the
## first owned gadget in "order" (the Tether-Hook until a later planet adds a selector).
## New lines in gadgets.json "lines" are copied into VOManager here (the lead adds bs/gadgets to LINE_SOURCES).

signal gadget_added(id: StringName)
signal gadget_used(id: StringName)

const TABLE: String = "bs/gadgets"

var bolt: Bolt = null
var gadgets: Dictionary = {}      # StringName -> Gadget
var defs: Dictionary = {}
var order: PackedStringArray = []


static func attach_to(b: Bolt) -> GadgetManager:
	if b == null:
		return null
	var existing: Node = b.get_node_or_null(^"Gadgets")
	if existing is GadgetManager:
		return existing as GadgetManager
	var m: GadgetManager = GadgetManager.new()
	m.name = "Gadgets"
	m.bolt = b
	b.add_child(m)
	return m


static func owns(id: StringName) -> bool:
	return BS.flag("gadget." + String(id))


static func grant(id: StringName) -> void:
	BS.set_flag("gadget." + String(id))
	SaveProfile.unlock("bs.gadget." + String(id))     # emits EventBus.unlock_granted once
	BS.save_to_profile()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for m: Node in tree.get_nodes_in_group(&"gadget_managers"):
			(m as GadgetManager).refresh()


static func table() -> Dictionary:
	var t: Variant = Data.table(TABLE)
	return t as Dictionary if t is Dictionary else {}


## Copies gadgets.json lines into VOManager when its sources don't have them yet (like BossBase.register_lines).
static func register_lines() -> void:
	var lines: Dictionary = table().get("lines", {})
	var store: Variant = VOManager.get("_lines")
	if not store is Dictionary:
		return
	for k: Variant in lines.keys():
		if not VOManager.has_line(str(k)):
			(store as Dictionary)[str(k)] = lines[k]


func _ready() -> void:
	add_to_group(&"gadget_managers")
	process_physics_priority = 10
	var t: Dictionary = table()
	defs = t.get("gadgets", {})
	for id: Variant in t.get("order", defs.keys()):
		order.append(str(id))
	register_lines()
	if bolt == null:
		bolt = get_parent() as Bolt
	refresh()


## Adds every owned gadget that isn't on the belt yet.
func refresh() -> void:
	for id: String in order:
		if gadgets.has(StringName(id)) or not owns(StringName(id)):
			continue
		var d: Dictionary = defs.get(id, {})
		var path: String = str(d.get("script", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var s: Script = load(path) as Script
		var g: Gadget = s.new() as Gadget
		if g == null:
			continue
		g.setup(self, StringName(id), d, bolt)
		add_child(g)
		gadgets[StringName(id)] = g
		g.used.connect(func(gg: Gadget) -> void: gadget_used.emit(gg.gadget_id))
		gadget_added.emit(StringName(id))


func get_gadget(id: StringName) -> Gadget:
	return gadgets.get(id) as Gadget


func primary() -> Gadget:
	for id: String in order:
		if gadgets.has(StringName(id)):
			return gadgets[StringName(id)]
	return null


func busy() -> bool:
	for g: Variant in gadgets.values():
		if (g as Gadget).busy():
			return true
	return false


func cancel_all() -> void:
	for g: Variant in gadgets.values():
		(g as Gadget).cancel()


## The "gadget" action. `id` empty = the primary gadget.
func press(id: StringName = &"") -> bool:
	var g: Gadget = primary() if id == &"" else get_gadget(id)
	if g == null:
		return false
	return g.press()


func _physics_process(_delta: float) -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	if bolt.dead:
		cancel_all()
		return
	if not bolt.scripted.is_empty():
		if bool(bolt.scripted.get("gadget_pressed", false)):
			bolt.scripted.erase("gadget_pressed")
			press()
		return
	if bolt.input_enabled and not BS.blocked() and InputMap.has_action(&"gadget") and Input.is_action_just_pressed(&"gadget"):
		press()
