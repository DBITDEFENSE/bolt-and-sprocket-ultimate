class_name ChandelierTrap
extends Node3D
## Chandelier Drop (Map 1, Salt Chapel). Once per round, the salt-crystal chandeliers over drop_points
## (local floor positions) crash down, killing everything within `radius` of each. They're back next round.

const KEY: String = "chandelier"

@export var drop_points: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -6), Vector3.ZERO, Vector3(0, 0, 6)])
@export var radius: float = 4.0
@export var hang_height: float = 9.0
## Art only (UPDATE 09, T-146): "crystal" the salt-crystal chandeliers (Map 1); "skip" a coal skip on two chains
## (Fernflug Act I's Coal Hopper); "wing" a riveted wing section on a sling (Act I's Jig Crane). The drop, the
## radius, the timing and the kill are the same for every style.
@export var style: StringName = &"crystal"
## Art only: how far the skip's / the wing section's chain runs up to its crane (the crystal style keeps its 6 m).
@export var chain_m: float = 6.0

var used_this_round: bool = false
var _falling: bool = false
var _t: float = 0.0
var _by: int = 0
var _chandeliers: Array[Node3D] = []


## Pure: may the trap fire? (once per round)
static func can_fire(used: bool, falling: bool) -> bool:
	return not used and not falling


func _ready() -> void:
	add_to_group(&"traps")
	for p: Vector3 in drop_points:
		var ch: Node3D = Node3D.new()
		add_child(ch)
		ch.position = p + Vector3.UP * hang_height
		match style:
			&"skip":
				_skip_art(ch, chain_m)
				_fold(ch)
			&"wing":
				_wing_art(ch, chain_m)
				_fold(ch)
			_:
				Props.crystal_chandelier(ch, 6.0)   # salt-crystal art (world/props.gd); the chain runs up 6 m
				var glow: OmniLight3D = OmniLight3D.new()
				glow.light_color = Color(0.9, 0.85, 1.0)
				glow.omni_range = 6.0
				glow.light_energy = 0.6
				ch.add_child(glow)
		_chandeliers.append(ch)
	GLBus.round_ended.connect(func(_r: int) -> void: reset())


## Folds the primitive meshes under `n` into one mesh per material (a skip or a wing section is one or two draw
## calls instead of a dozen). The materials are world-triplanar, so dropping UVs costs nothing.
static func _fold(n: Node3D) -> void:
	var buckets: Dictionary = {}
	for c: Node in n.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null or not (mi.mesh is PrimitiveMesh) or mi.material_override == null:
			continue
		var k: int = mi.material_override.get_instance_id()
		if not buckets.has(k):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			buckets[k] = [st, mi.material_override]
		(buckets[k][0] as SurfaceTool).append_from(mi.mesh, 0, mi.transform)
		n.remove_child(mi)
		mi.queue_free()
	for k2: int in buckets.keys():
		var arrays: Array = (buckets[k2][0] as SurfaceTool).commit_to_arrays()
		arrays[Mesh.ARRAY_TEX_UV] = null
		var m: ArrayMesh = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out: MeshInstance3D = MeshInstance3D.new()
		out.mesh = m
		out.material_override = buckets[k2][1]
		n.add_child(out)


## A riveted coal skip (1.6 × 1.1 × 0.9) heaped with coal, hung from its bail on two chains that run up `chain` m.
static func _skip_art(parent: Node3D, chain: float) -> void:
	Props.block(parent, Vector3(-0.8, 0.0, -0.55), Vector3(0.8, 0.85, 0.55), "rust")
	Props.block(parent, Vector3(-0.84, 0.75, -0.59), Vector3(0.84, 0.9, 0.59), "iron")
	for sx: float in [-0.5, 0.0, 0.5]:
		Props.block(parent, Vector3(sx - 0.03, 0.05, -0.57), Vector3(sx + 0.03, 0.85, 0.57), "iron")
	Props.ball(parent, Vector3(0, 0.9, 0), Vector3(1.4, 0.45, 0.95), "coal")
	for sx2: float in [-0.82, 0.82]:
		Props.block(parent, Vector3(sx2 - 0.03, 0.5, -0.05), Vector3(sx2 + 0.03, 1.6, 0.05), "iron")
		Props.cable(parent, Vector3(sx2, 1.6, 0), Vector3(sx2 * 0.2, chain, 0), 0.0, 0.025, 4, "iron")
	Props.block(parent, Vector3(-0.85, 1.55, -0.05), Vector3(0.85, 1.65, 0.05), "iron")


## A section of wing (a 5 m panel of ribs under a half skin) on a four-leg sling that runs up `chain` m.
static func _wing_art(parent: Node3D, chain: float) -> void:
	Props.block(parent, Vector3(-2.5, 0.0, -0.9), Vector3(2.5, 0.06, 0.9), "chrome_worn")
	Props.block(parent, Vector3(-2.5, 0.42, -0.6), Vector3(2.5, 0.46, 0.7), "chrome_worn")
	for i: int in 6:
		var x: float = -2.4 + float(i) * 0.96
		Props.block(parent, Vector3(x - 0.02, 0.0, -0.85), Vector3(x + 0.02, 0.44, 0.85), "machine_grey")
	for f: float in [-0.45, 0.35]:
		Props.block(parent, Vector3(-2.5, 0.05, f - 0.05), Vector3(2.5, 0.42, f + 0.05), "machine_grey")
	var apex: float = clampf(chain * 0.6, 0.7, 2.2)
	for c: Vector3 in [Vector3(-2.2, 0.46, -0.6), Vector3(2.2, 0.46, -0.6), Vector3(-2.2, 0.46, 0.6), Vector3(2.2, 0.46, 0.6)]:
		Props.strut(parent, c, Vector3(0, apex, 0), 0.03, "iron", true)
	if chain > apex + 0.05:
		Props.strut(parent, Vector3(0, apex, 0), Vector3(0, chain, 0), 0.05, "iron", true)
	Props.ball(parent, Vector3(0, apex + 0.05, 0), Vector3(0.22, 0.3, 0.12), "crane_yellow")


func trap_name() -> String:
	return "Chandelier Drop"


func cost() -> int:
	return int(TrapLever.cfg_for(KEY)["cost"])


func can_activate() -> bool:
	return can_fire(used_this_round, _falling)


func status_text() -> String:
	return "The chandeliers are down until next round"


func activate(by_player: int) -> bool:
	if not can_activate():
		return false
	used_this_round = true
	_falling = true
	_t = 0.0
	_by = by_player
	AudioDirector.play_3d("board_break", global_position + Vector3.UP * hang_height, 6.0, 0.0)
	return true


func _physics_process(delta: float) -> void:
	if not _falling:
		return
	var c: Dictionary = TrapLever.cfg_for(KEY)
	var fall: float = float(c["fall_seconds"])
	_t += delta
	var k: float = clampf(_t / fall, 0.0, 1.0)
	for i: int in _chandeliers.size():
		_chandeliers[i].position.y = drop_points[i].y + hang_height * (1.0 - k * k) + 0.4 * k
	if k < 1.0:
		return
	_falling = false
	AudioDirector.play_3d("chandelier_crash", global_position + Vector3.UP, 4.0, 0.0)   # one crash for the set
	for i: int in _chandeliers.size():
		var at: Vector3 = to_global(drop_points[i])
		Effects.explosion(at + Vector3.UP * 0.5, radius)
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if _near(z.global_position, at):
					TrapLever.trap_kill(z, float(c["zombie_damage"]), KEY, _by)
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if Net.is_authority() and p != null and p.is_alive() and _near(p.global_position, at):
				p.take_hit(float(c["player_damage"]), self)
	if Net.is_authority():
		GLBus.explosion.emit(global_position, radius * 2.0)


func _near(p: Vector3, at: Vector3) -> bool:
	return Vector2(p.x - at.x, p.z - at.z).length() <= radius and absf(p.y - at.y) < 3.0


## Bots keep out (BotBrain._in_trap): true while the chandeliers fall and `p` is under one (a metre of margin).
func danger_contains(p: Vector3) -> bool:
	if not _falling:
		return false
	for dp: Vector3 in drop_points:
		var at: Vector3 = to_global(dp)
		if Vector2(p.x - at.x, p.z - at.z).length() <= radius + 1.0 and absf(p.y - at.y) < 3.0:
			return true
	return false


## Next round: the chandeliers are hoisted back up.
func reset() -> void:
	used_this_round = false
	_falling = false
	for i: int in _chandeliers.size():
		_chandeliers[i].position = drop_points[i] + Vector3.UP * hang_height
