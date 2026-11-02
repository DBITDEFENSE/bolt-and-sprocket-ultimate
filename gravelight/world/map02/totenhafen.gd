class_name Totenhafen
extends Node
## Totenhafen's UPDATE 10 systems (contracts C2-C4, DECISIONS T-153), attached at runtime by MapRoot so map02.tscn
## stays the generator's (U09 section 5 architecture: dress, don't re-lay the map). Every node is placed from
## data/gravelight/map02.json under Gameplay with a fixed name, so the host's Net.mirror paths match on every peer.
## Owns: the pump crank (Tide v2), Ballast v2 (the dump, coffin respawn, the counters' VO and rewards), the
## searchlight, the Crane Drop, the Undertow's parts and bench, Letzte Fahrt's world objects (radios, the cipher
## machine, the log pages, the diesels, the key, the curtain, the boat), the Kielholer controller and the first
## pickup VO. Other systems find these through their groups.

const MAP_JSON: String = "res://data/gravelight/map02.json"

var map: MapRoot
var gameplay: Node3D
var cfg: Dictionary = {}
var _said_once: Dictionary = {}


static func attach(m: MapRoot) -> void:
	if not String(m.map_id).begins_with("map02"):
		return
	var t: Totenhafen = Totenhafen.new()
	t.name = "Totenhafen"
	m.add_child(t)
	t.setup(m)


static func of(tree: SceneTree) -> Totenhafen:
	return tree.get_first_node_in_group(&"totenhafen") as Totenhafen


func setup(m: MapRoot) -> void:
	add_to_group(&"totenhafen")
	map = m
	cfg = GLData.load_json(MAP_JSON)
	gameplay = m.get_node_or_null("Gameplay") as Node3D
	if gameplay == null:
		gameplay = Node3D.new()
		gameplay.name = "Gameplay"
		m.add_child(gameplay)
	_place_tide_systems()
	_place_optional("res://gravelight/world/map02/totenhafen_ballast.gd")
	_place_optional("res://gravelight/world/map02/totenhafen_world.gd")
	_place_optional("res://gravelight/world/map02/kielholer_controller.gd")
	_place_optional("res://gravelight/world/map02/undertow_parts.gd")
	_place_optional("res://gravelight/world/map02/letzte_fahrt_world.gd")
	GLBus.weapon_acquired.connect(_on_weapon_acquired)


## A sibling module with a static attach(totenhafen) (kept in separate files so the parts stay reviewable).
func _place_optional(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var s: GDScript = load(path) as GDScript
	if s != null and _has_static(s, "attach"):
		s.call(&"attach", self)
	elif s != null:
		var n: Object = s.new()
		if n is Node:
			(n as Node).name = path.get_file().get_basename().to_pascal_case()
			add_child(n as Node)
			if n.has_method(&"setup"):
				n.call(&"setup", self)


static func _has_static(s: GDScript, fn: String) -> bool:
	for m: Dictionary in s.get_script_method_list():
		if str(m.get("name", "")) == fn:
			return true
	return false


## Add a node under Gameplay at a data position [x, y, z(, yaw)].
func place(n: Node3D, node_name: String, pos: Variant, yaw_deg: float = 0.0) -> Node3D:
	n.name = node_name
	var p: Vector3 = Vector3.ZERO
	if pos is Vector3:
		p = pos
	elif pos is Array and (pos as Array).size() >= 3:
		var a: Array = pos
		p = Vector3(float(a[0]), float(a[1]), float(a[2]))
		if a.size() >= 4:
			yaw_deg = float(a[3])
	n.position = p
	n.rotation.y = deg_to_rad(yaw_deg)
	gameplay.add_child(n)
	return n


func _place_tide_systems() -> void:
	var pc: Dictionary = (cfg.get("tide", {}) as Dictionary).get("pump_crank", {})
	if not pc.is_empty():
		place(PumpCrank.new(), "PumpCrank", pc.get("position", [51.4, 0.0, 43.2]), float(pc.get("yaw", -90.0)))


func tide() -> TideController:
	return get_tree().get_first_node_in_group(&"tide") as TideController


func banner(text: String, hold: float = 3.0) -> void:
	if map != null and map.hud != null and text != "":
		map.hud.show_banner(text, hold)


## Once per match per key (first pickups, the first sight of a system).
func once(key: String) -> bool:
	if _said_once.has(key):
		return false
	_said_once[key] = true
	return true


## The first pickup of the Undertow: that character's line (C4: *_WONDER_UNDERTOW_01).
func _on_weapon_acquired(pid: int, weapon_id: StringName, _source: StringName) -> void:
	if not Net.is_authority():
		return
	var base: String = String(weapon_id)
	if not base.begins_with("undertow"):
		return
	if not once("undertow_%d" % pid):
		return
	var ch: StringName = GameState.character_of(pid)
	var code: String = {&"dutch": "DUT", &"peg": "PEG", &"deacon": "DEA", &"wren": "WRN"}.get(ch, "")
	if code != "":
		GLVO.play(StringName("%s_WONDER_UNDERTOW_01" % code))
