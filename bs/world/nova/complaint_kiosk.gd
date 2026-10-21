class_name ComplaintKiosk
extends StaticBody3D
## A FineTree Plaza complaint kiosk (BS_LEVELS §4.10): 3 m tall cover that, while `printing`, drops a
## "Formal Complaint" canister (ComplaintCanister) out of its slot every `interval` seconds (12 s), keeping
## at most `max_out` of its canisters on the plaza. Its top is a standing spot for the 6.5 m intake slot.
## smash() (the Algorithm's violation stamps) knocks it flat: no collision, no cover, no printing.
## kind "meter" is one of the five source fine-o-meter kiosks (same cover and smash(), never prints).

signal printed(kiosk: ComplaintKiosk, canister: ComplaintCanister)
signal smashed(kiosk: Node)

var kind: String = "complaint"
var interval: float = 12.0
var max_out: int = 2
var printing: bool = false
var is_smashed: bool = false
var printed_count: int = 0
var _t: float = 0.0
var _out: Array[ComplaintCanister] = []
var _screen: MeshInstance3D
var _parts: Array[Node] = []


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var meter: bool = kind == "meter"
	add_to_group(&"fine_o_meters" if meter else &"complaint_kiosks")
	add_to_group(&"finetree_cover")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(1.6, 3.0, 1.2)
	cs.shape = sh
	cs.position.y = 1.5
	add_child(cs)
	_parts.append(cs)
	_parts.append(LevelKit.box(self, Vector3(0, 1.5, 0), Vector3(1.6, 3.0, 1.2), "#1a2240" if meter else "#e8e2d0", false))
	_screen = LevelKit.box(self, Vector3(0, 2.2, 0.61), Vector3(1.1, 0.7, 0.03), "#3ee6ff" if meter else "#ff4d9d", false, Vector3.ZERO, 1, 1.4) as MeshInstance3D
	_parts.append(_screen)
	_parts.append(LevelKit.box(self, Vector3(0, 1.0, 0.62), Vector3(0.9, 0.18, 0.06), "#141414", false))
	_parts.append(NovaArt.neon_text(self, "bs.nova.fine_o_meter" if meter else "bs.nova.complaint_kiosk", Vector3(0, 2.75, 0.63), 0.005, "#ffd23e" if meter else "#141414"))
	if meter:
		_parts.append(NovaArt.neon_text(self, "bs.nova.fine_o_meter_screen", Vector3(0, 2.2, 0.64), 0.006, "#0e1428"))


func spout_position() -> Vector3:
	return global_transform * Vector3(0, 1.0, 1.0)


func _physics_process(delta: float) -> void:
	if not printing or is_smashed or kind == "meter":
		return
	_t += delta
	var live: Array[ComplaintCanister] = []
	for cv: Variant in _out:
		if is_instance_valid(cv) and (cv as ComplaintCanister).is_alive():
			live.append(cv as ComplaintCanister)
	_out = live
	if _t >= interval and _out.size() < max_out:
		_t = 0.0
		print_canister()


## Prints one canister now (also used by tests).
func print_canister() -> ComplaintCanister:
	var c: ComplaintCanister = ComplaintCanister.new()
	c.source_kiosk = self
	get_parent().add_child(c)
	c.global_position = spout_position()
	c.apply_central_impulse((global_transform.basis.z + Vector3.UP * 0.4).normalized() * 2.0)
	_out.append(c)
	printed_count += 1
	printed.emit(self, c)
	return c


func smash() -> void:
	if is_smashed:
		return
	is_smashed = true
	printing = false
	collision_layer = 0
	for p: Node in _parts:
		if p is Node3D:
			(p as Node3D).visible = false
	LevelKit.box(self, Vector3(0, 0.2, 0), Vector3(1.8, 0.4, 1.4), "#8a8478", false, Vector3(0, 0, 8))
	smashed.emit(self)
