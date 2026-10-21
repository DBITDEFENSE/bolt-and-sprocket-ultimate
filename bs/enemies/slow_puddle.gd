class_name SlowPuddle
extends Node3D
## A lingering ground zone that SLOWS Bolt while he stands in it (BS_ENEMIES §6 SLOWED): the Lifeguard Bot's
## "NO RUNNING" puddle (r2.6, 3 s, -30%). Optional tick damage (`tick_dmg` every `tick_every`). Silent.

var r: float = 2.6
var life: float = 3.0
var mult: float = 0.7
var key: StringName = &"puddle"
var tick_dmg: float = 0.0
var tick_every: float = 0.5
var source: Node = null
var bolt_inside: bool = false
var _tick: float = 0.0
var _mat: StandardMaterial3D


static func spawn(parent: Node, at: Vector3, r_: float, life_: float, slow_frac: float, key_: StringName,
		opts: Dictionary = {}) -> SlowPuddle:
	var p: SlowPuddle = SlowPuddle.new()
	p.r = r_
	p.life = life_
	p.mult = 1.0 - slow_frac
	p.key = key_
	p.tick_dmg = float(opts.get("tick_dmg", 0.0))
	p.source = opts.get("source", null)
	parent.add_child(p)
	p.global_position = Vector3(at.x, EnemyFx.floor_y(p, at, at.y) + 0.04, at.z)
	return p


func _ready() -> void:
	add_to_group(&"enemy_hazards")
	_mat = EnemyFx.glow(Color("#3ec8ff"), 0.45)
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.03
	cm.radial_segments = 24
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat
	add_child(mi)
	var lbl: Label3D = Label3D.new()
	lbl.text = "NO RUNNING"
	lbl.font_size = 48
	lbl.pixel_size = 0.006
	lbl.modulate = Color("#d42f2f")
	lbl.rotation.x = -PI / 2
	lbl.position.y = 0.05
	add_child(lbl)


func contains(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < r and absf(p.y - global_position.y) < 2.2


func _physics_process(delta: float) -> void:
	life -= delta
	_tick -= delta
	_mat.albedo_color.a = 0.45 * clampf(life, 0.0, 1.0)
	var bolt: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	bolt_inside = bolt != null and bool(bolt.call("is_alive")) and contains(bolt.global_position)
	if bolt_inside:
		var d: PlayerDebuffs = PlayerDebuffs.of(bolt)
		if d != null:
			d.slow(key, mult, 0.2)
		if tick_dmg > 0.0 and _tick <= 0.0:
			_tick = tick_every
			EnemyBase.hurt_player(bolt, Combat.Hit.make(tick_dmg, Combat.Type.KINETIC, source), source)
	if life <= 0.0:
		queue_free()
