class_name ShaftGrateLever
extends Interactable
## The vent lever on the Account's west wall (UPDATE 10 §3 Act IV, T-158; data map04d.json "shaft_grate"): pay
## `cost`, the grate by the door opens for `open_seconds`, then `cooldown` s. Group `shaft_grate_lever` (the bots'
## trap use, C7). The Operator calls it once.

@export var grate_path: NodePath

var cfg: Dictionary = {}
var cool_left: float = 0.0
var uses: int = 0
var _said: bool = false
var _lamp: OmniLight3D


func _ready() -> void:
	interact_size = Vector3(1.2, 1.8, 0.8)
	interact_offset = Vector3(0, 1.2, 0.3)
	super._ready()
	add_to_group(&"shaft_grate_lever")
	cfg = GLData.load_json("res://data/gravelight/map04d.json").get("shaft_grate", {})


func build_greybox() -> void:
	add_box(self, Vector3(0.7, 1.2, 0.2), Vector3(0, 1.3, 0.1), greybox_mat(Color(0.16, 0.16, 0.19)))
	add_box(self, Vector3(0.08, 0.6, 0.08), Vector3(0.15, 1.2, -0.08), greybox_mat(Color(0.85, 0.65, 0.2), 0.4))
	add_box(self, Vector3(0.5, 0.12, 0.02), Vector3(0, 1.82, -0.01), greybox_mat(Color(0.95, 0.75, 0.3), 1.0))
	var lb: Label3D = add_label(self, "VENT\nSHAFT 1", Vector3(0, 2.15, -0.02), 22, Color(0.95, 0.8, 0.45, 0.95))
	lb.rotation_degrees.y = 180.0
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 1.85, -0.35)
	_lamp.light_color = Color(0.3, 1.0, 0.45)
	_lamp.light_energy = 0.5
	_lamp.omni_range = 2.5
	_lamp.shadow_enabled = false
	add_child(_lamp)


func grate() -> ShaftGrate:
	var g: ShaftGrate = get_node_or_null(grate_path) as ShaftGrate if not grate_path.is_empty() else null
	return g if g != null else get_tree().get_first_node_in_group(&"shaft_grate") as ShaftGrate


func get_prompt(player: Player) -> String:
	if player == null:
		return ""
	var g: ShaftGrate = grate()
	if g != null and g.is_open():
		return "The vent is open"
	if cool_left > 0.0:
		return "The vent is cycling (%d s)" % int(ceil(cool_left))
	return "Hold [%s] to open the vent %s" % [prompt_key(&"interact"), price_str(player, int(cfg.get("cost", 1000)))]


func can_interact(player: Player) -> bool:
	var g: ShaftGrate = grate()
	return player != null and g != null and not g.is_open() and cool_left <= 0.0


func hold_time(_player: Player) -> float:
	return 0.6


func interact(player: Player) -> void:
	if not can_interact(player) or not Net.is_authority():
		return
	if not try_purchase(player, &"shaft_grate", int(cfg.get("cost", 1000))):
		return
	pull()


## Host: open the grate (also the smoke and the bots).
func pull() -> void:
	var g: ShaftGrate = grate()
	if g == null:
		return
	uses += 1
	var secs: float = float(cfg.get("open_seconds", 8.0))
	g.open_for(secs)
	cool_left = secs + float(cfg.get("cooldown", 60.0))
	Net.mirror(self, &"_net_cool", [cool_left])
	if not _said:
		_said = true
		GLVO.play(StringName(str(cfg.get("vo", "OPR_M4D_SHAFT_01"))))
	print("[m4d] the vent opens (%d)" % uses)


func _net_cool(c: float) -> void:
	cool_left = c


func _process(delta: float) -> void:
	cool_left = maxf(0.0, cool_left - delta)
	if _lamp != null:
		_lamp.light_color = Color(0.3, 1.0, 0.45) if cool_left <= 0.0 else Color(1.0, 0.3, 0.2)
