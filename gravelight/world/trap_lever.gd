class_name TrapLever
extends Interactable
## The lever that buys a trap (1000). The trap node it points at implements:
##   trap_name() -> String, cost() -> int, can_activate() -> bool, status_text() -> String,
##   activate(by_player: int) -> bool

@export var trap_path: NodePath
@export var trap_id: StringName = &"trap"

var _handle: Node3D
var _lamp: MeshInstance3D
var _lamp_t: float = 0.0

const STENCIL: Dictionary = {&"ore_cart": "FÖRDERWAGEN", &"live_wire": "HOCHSPANNUNG", &"chandelier": "KRONLEUCHTER"}


func _ready() -> void:
	interact_size = Vector3(0.7, 1.0, 0.3)
	interact_offset = Vector3(0, 1.1, -0.15)
	super._ready()


func trap() -> Node:
	return get_node_or_null(trap_path)


func build_greybox() -> void:
	# a hazard-striped wall switch box with a stencil plate and a ready lamp; the arm hangs from its pivot
	InteractableArt.place(self, "lever_box", func(r: Node3D) -> void: InteractableArt.lever_box(r))
	var l: Label3D = add_label(self, str(STENCIL.get(trap_id, String(trap_id).to_upper())), Vector3(0, 1.35, -0.088), 13, Color(0.95, 0.88, 0.65))
	l.outline_size = 3
	_handle = Node3D.new()
	_handle.position = Vector3(0, 1.1, -0.1)
	add_child(_handle)
	InteractableArt.place(_handle, "lever_arm", func(r: Node3D) -> void: InteractableArt.lever_arm(r))
	_lamp = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.032
	cm.bottom_radius = 0.032
	cm.height = 0.03
	_lamp.mesh = cm
	_lamp.rotation.x = PI * 0.5
	_lamp.position = Vector3(0.15, 0.9, -0.105)
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lamp.material_override = Mats.get_mat("lamp_green_off")
	add_child(_lamp)


## The ready lamp: green when the trap can be bought, red while it runs or cools down.
func _process(delta: float) -> void:
	_lamp_t -= delta
	if _lamp_t > 0.0 or _lamp == null:
		return
	_lamp_t = 0.3
	var t: Node = trap()
	var armed: bool = t != null and bool(t.call("can_activate"))
	_lamp.material_override = Mats.get_mat("lamp_green" if armed else "emergency_red")


func get_prompt(player: Player) -> String:
	var t: Node = trap()
	if t == null:
		return ""
	if not bool(t.call("can_activate")):
		return str(t.call("status_text"))
	return "Hold [%s] to activate the %s [%s]" % [prompt_key(&"interact"), t.call("trap_name"), price_str(player, int(t.call("cost")))]


func can_interact(_player: Player) -> bool:
	var t: Node = trap()
	return t != null and bool(t.call("can_activate"))


func interact(player: Player) -> void:
	var t: Node = trap()
	if t == null or not bool(t.call("can_activate")):
		return
	if not try_purchase(player, trap_id, int(t.call("cost"))):
		return
	if bool(t.call("activate", player.player_id)):
		GLBus.trap_activated.emit(trap_id, player.player_id)
		Net.mirror(t, &"activate", [player.player_id])   # the clients run the trap for show (no damage there)
		_pull()
		Net.mirror(self, &"_pull")


func _pull() -> void:
	if _handle != null:
		var tw: Tween = create_tween()
		tw.tween_property(_handle, "rotation:x", 1.4, 0.2)
		tw.tween_interval(1.5)
		tw.tween_property(_handle, "rotation:x", 0.0, 0.5)


## Shared trap helpers (static so each trap script stays standalone).
static var _traps_cache: Dictionary = {}


static func cfg_for(key: String) -> Dictionary:
	if _traps_cache.is_empty():
		_traps_cache = GLData.load_json("res://data/gravelight/traps.json")
	return _traps_cache[key]


## Cooldown after Deacon's trait (-15%) and Classic Rules.
static func cooldown_for(key: String) -> float:
	var cd: float = float(cfg_for(key)["cooldown"])
	if GameState.has_trait(&"deacon"):
		cd *= float(_traps_cache.get("deacon_cooldown_mult", 0.85))
	return cd


## Kills zombies with a trap (kind world; the activator gets the kill Scrip).
static func trap_kill(z: Zombie, damage: float, key: String, by_player: int) -> void:
	if z.is_active() and not z.puppet:
		z.take_damage(damage, &"torso", StringName("trap_" + key), by_player, &"world")
