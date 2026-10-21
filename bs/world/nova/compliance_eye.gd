class_name ComplianceEye
extends Node3D
## An HOA Compliance Eye (BS_LEVELS §4.4-4.5): a camera on a pole that watches a 14 m, 40° cone (horizontal).
## HOACompliance asks sees(point) while Bolt sprints, jumps on a walkway or fights; a logged violation makes
## the district's lamps flash and its walkways reverse. The eye is a mallet-throw target `(B)`: BoltMelee
## calls on_mallet(bolt) (group "mallet_switches"), which blinds it for `blind_time` seconds (20 s): it logs
## nothing and its cone goes dark. `watches` lists the violation kinds it reports ("sprint", "walkway_jump",
## "fight", "jump"); the clubhouse rules-board eyes each watch one rule.

signal blinded(eye: ComplianceEye)
signal logged(eye: ComplianceEye, kind: String)

var eye_id: String = ""
var district: String = ""
var look: Vector3 = Vector3.ZERO           # world point the eye watches (sets its yaw)
var view_range: float = 14.0
var cone_deg: float = 40.0
var blind_time: float = 20.0
var height: float = 3.6
var watches: PackedStringArray = ["sprint", "walkway_jump", "fight"]
var on_violation: Array = []                # data actions the director runs when this eye logs
var once: bool = false                      # on_violation runs only the first time
var blind_t: float = 0.0
var log_count: int = 0
var _head: Node3D
var _lens: MeshInstance3D
var _cone: MeshInstance3D
var _body: StaticBody3D
var _alert_t: float = 0.0
var _t: float = 0.0
var _state: int = -1


func _ready() -> void:
	add_to_group(&"compliance_eyes")
	add_to_group(&"mallet_switches")
	LevelKit.cylinder(self, Vector3(0, 0.1, 0), 0.3, 0.2, "#232838", true)
	LevelKit.cylinder(self, Vector3(0, height * 0.5, 0), 0.09, height, "#5a6377", true)
	_head = Node3D.new()
	_head.position = Vector3(0, height + 0.2, 0)
	add_child(_head)
	var flat: Vector3 = Vector3(look.x, 0, look.z) - Vector3(global_position.x, 0, global_position.z)
	if flat.length() > 0.1:
		_head.rotation.y = atan2(-flat.x, -flat.z)
	_body = LevelKit.box(_head, Vector3.ZERO, Vector3(0.7, 0.55, 0.9), "#d8dee9", true) as StaticBody3D
	LevelKit.box(_head, Vector3(0, 0.36, 0.1), Vector3(0.9, 0.08, 1.1), "#3a4658", false)
	_lens = LevelKit.cylinder(_head, Vector3(0, 0, -0.48), 0.2, 0.08, "#ffd23e", false, "z", -1.0, 2.4) as MeshInstance3D
	# view cone on the ground plane, apex at the head (visual only)
	var r: float = view_range * tan(deg_to_rad(cone_deg * 0.5))
	_cone = NovaArt.cone(_head, Vector3(0, -0.2, -view_range * 0.5), r, view_range, "#ffd23e", 0.03, 1.0)
	_cone.rotation_degrees = Vector3(-90, 0, 0)
	_cone.scale = Vector3(1.0, 1.0, 0.35)
	NovaArt.neon_text(self, "bs.nova.eye_label", Vector3(0, height - 0.6, 0.12), 0.006, "#ffd23e")


func head_position() -> Vector3:
	return _head.global_position if _head != null else global_position + Vector3(0, height, 0)


func forward() -> Vector3:
	return -_head.global_transform.basis.z if _head != null else Vector3.FORWARD


func is_blind() -> bool:
	return blind_t > 0.0


func watches_kind(kind: String) -> bool:
	return kind in watches


## Inside the horizontal view cone, within range, with a clear line of sight.
func sees(p: Vector3) -> bool:
	if is_blind() or not is_inside_tree():
		return false
	var h: Vector3 = head_position()
	var to_p: Vector3 = Vector3(p.x - h.x, 0, p.z - h.z)
	var dist: float = to_p.length()
	if dist > view_range or dist < 0.2:
		return dist < 0.2
	var f: Vector3 = forward()
	f = Vector3(f.x, 0, f.z).normalized()
	if rad_to_deg(f.angle_to(to_p.normalized())) > cone_deg * 0.5:
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(h, p, 1)
	if _body != null:
		q.exclude = [_body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Mallet throw: blind for blind_time.
func on_mallet(_bolt: Node) -> void:
	if is_blind():
		return
	blind_t = blind_time
	blinded.emit(self)


## Called by HOACompliance when this eye reports a violation.
func note_violation(kind: String) -> void:
	log_count += 1
	_alert_t = 1.0
	logged.emit(self, kind)


func _process(delta: float) -> void:
	_t += delta
	blind_t = maxf(0.0, blind_t - delta)
	_alert_t = maxf(0.0, _alert_t - delta)
	var st: int = 2 if is_blind() else (1 if _alert_t > 0.0 and fmod(_t, 0.2) < 0.12 else 0)
	if st == _state:
		return
	_state = st
	_cone.visible = st != 2
	_lens.material_override = LevelKit.mat(["#ffd23e", "#ff2a3a", "#2a2f3a"][st], [2.4, 3.0, 0.0][st])
	_cone.material_override = NovaArt.glow("#ff2a3a" if st == 1 else "#ffd23e", 0.08 if st == 1 else 0.03)
