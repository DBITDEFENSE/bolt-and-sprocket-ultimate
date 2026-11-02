class_name SlenderDecoy
extends Node3D
## Shift Change's other two watchmen (HB3, docs/HOMAGE_BOSSES.md section 6.4; DECISIONS T-160): a tall greatcoat
## silhouette with a lantern that FLICKERS (the real one's is steady: read the light, don't spray). They walk with
## his timing and do no damage; shooting one logs the shooter +15 ("Wrong lantern. Noted."). They dissolve after
## 25 s or when the real one takes 5% of his max HP in light (Slender._clear_decoys).

var boss: Slender = null
var hits: int = 0
var _light: OmniLight3D
var _t: float = 0.0
var _hb: Hitbox


func _ready() -> void:
	var coat: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.36
	cm.height = 2.1
	coat.mesh = cm
	coat.material_override = HomageBoss.mat(Slender.COAT)
	coat.position = Vector3(0, 1.05, 0)
	add_child(coat)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.3
	head.mesh = sm
	head.material_override = HomageBoss.mat(Color(0.8, 0.78, 0.8))
	head.position = Vector3(0, 2.3, 0)
	add_child(head)
	var cap: MeshInstance3D = MeshInstance3D.new()
	var capm: CylinderMesh = CylinderMesh.new()
	capm.top_radius = 0.15
	capm.bottom_radius = 0.16
	capm.height = 0.08
	cap.mesh = capm
	cap.material_override = HomageBoss.mat(Slender.CAP)
	cap.position = Vector3(0, 2.45, 0)
	add_child(cap)
	var lantern: MeshInstance3D = MeshInstance3D.new()
	var lb: BoxMesh = BoxMesh.new()
	lb.size = Vector3(0.12, 0.2, 0.12)
	lantern.mesh = lb
	lantern.material_override = HomageBoss.mat(Slender.VIOLET, 2.0)
	lantern.position = Vector3(0.45, 1.2, -0.25)
	add_child(lantern)
	_light = OmniLight3D.new()
	_light.light_color = Slender.VIOLET
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	_light.position = lantern.position
	add_child(_light)
	_hb = Hitbox.new()
	_hb.setup(boss, &"decoy", Vector3(0.7, 2.4, 0.7))   # owned by him (hitscan only hits Zombies): limb "decoy"
	_hb.position = Vector3(0, 1.2, 0)
	add_child(_hb)


func _physics_process(delta: float) -> void:
	_t += delta
	# the flicker that gives them away
	_light.light_energy = 1.6 * (0.35 + 0.65 * absf(sin(_t * 9.0 + sin(_t * 23.0))))
	if boss == null or not is_instance_valid(boss) or not boss.is_active():
		queue_free()
		return
	var tgt: Node3D = boss.target
	if tgt == null:
		return
	var d: Vector3 = tgt.global_position - global_position
	d.y = 0.0
	if d.length() > 3.0:
		global_position += d.normalized() * boss.move_speed() * delta
		look_at(global_position + d.normalized(), Vector3.UP)


