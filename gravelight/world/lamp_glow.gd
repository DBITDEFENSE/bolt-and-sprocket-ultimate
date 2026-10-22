class_name LampGlow
extends Node
## Lamp glass follows its light (T-057). The lanterns' and wall lamps' glass is an emissive material
## (Mats "lantern_glass") on meshes that know nothing about the OmniLight3D beside them, so when the Cousins round
## guttered the inn's lamps (or a Bellringer round dimmed them) the light went out and the glass kept glowing.
## At map load this binds every glass mesh to the lights within RADIUS of it, gives it its own copy of the
## material, and each frame sets the copy's emission to base x (the brightest owner's energy / its energy at load).
## The hearth's flames thin out the same way with their fire light. Lights tied to the power (meta "energy") or
## dark at load are left alone (the power code and the lit-bulb holders already handle those).

const RADIUS: float = 0.6
const FLAME_RADIUS: float = 1.2

var _glass: Array = []    # [material copy, base emission, owners: Array of [Light3D, reference energy], last k]
var _flames: Array = []   # [GPUParticles3D, owners, last k]


## Adds a LampGlow under a map root and binds its lamps. Returns it.
static func attach(root: Node3D) -> LampGlow:
	var g: LampGlow = LampGlow.new()
	g.name = "LampGlow"
	root.add_child(g)
	g.bind(root)
	return g


## The light's steady energy: a FlickerLight's base_energy (its light_energy wobbles), else light_energy.
static func energy_of(l: Light3D) -> float:
	var b: Variant = l.get("base_energy")
	return float(b) if b != null else l.light_energy


func bind(root: Node3D) -> void:
	_glass.clear()
	_flames.clear()
	var lights: Array = []
	for n: Node in root.find_children("*", "OmniLight3D", true, false):
		var l: OmniLight3D = n as OmniLight3D
		if l.has_meta("energy") or energy_of(l) <= 0.05 or _under_player(l):
			continue
		lights.append([l, energy_of(l)])
	if lights.is_empty():
		return
	var glass_mat: Material = Mats.get_mat("lantern_glass")
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var surf: int = -2   # -1 = material_override, >= 0 = that surface
		if _is_glass(mi.material_override, glass_mat):
			surf = -1
		elif mi.material_override == null:
			for s: int in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(s) == null and _is_glass(mi.mesh.surface_get_material(s), glass_mat):
					surf = s
					break
		if surf == -2:
			continue
		var src: StandardMaterial3D = (mi.material_override if surf == -1 else mi.mesh.surface_get_material(surf)) as StandardMaterial3D
		var owners: Array = _owners_near(lights, mi.global_transform * mi.get_aabb(), RADIUS)
		if owners.is_empty():
			continue
		var copy: StandardMaterial3D = src.duplicate() as StandardMaterial3D
		if surf == -1:
			mi.material_override = copy
		else:
			mi.set_surface_override_material(surf, copy)
		_glass.append([copy, copy.emission_energy_multiplier, owners, 1.0])
	for n: Node in root.find_children("Flames", "GPUParticles3D", true, false):
		var p: GPUParticles3D = n as GPUParticles3D
		var owners2: Array = _owners_near(lights, AABB(p.global_position, Vector3.ZERO), FLAME_RADIUS)
		if not owners2.is_empty():
			_flames.append([p, owners2, 1.0])


## How many glass meshes and flame emitters follow a light (tests / the smoke).
func bound_count() -> int:
	return _glass.size() + _flames.size()


## The current glow factor of the glass nearest `p` (1 = as built, 0 = dark), or -1 when none is bound there.
func glow_near(p: Vector3) -> float:
	var best: float = -1.0
	var best_d: float = INF
	for e: Array in _glass:
		for o: Array in e[2]:
			var d: float = (o[0] as Node3D).global_position.distance_to(p) if is_instance_valid(o[0]) else INF
			if d < best_d:
				best_d = d
				best = (e[0] as StandardMaterial3D).emission_energy_multiplier / maxf(0.001, float(e[1]))
	return best


func _process(_delta: float) -> void:
	for e: Array in _glass:
		var k: float = _level(e[2])
		if absf(k - float(e[3])) > 0.01:
			e[3] = k
			(e[0] as StandardMaterial3D).emission_energy_multiplier = float(e[1]) * k
	for f: Array in _flames:
		var k2: float = _level(f[1])
		if absf(k2 - float(f[2])) > 0.01 and is_instance_valid(f[0]):
			f[2] = k2
			(f[0] as GPUParticles3D).amount_ratio = clampf(k2, 0.12, 1.0)


func _level(owners: Array) -> float:
	var k: float = 0.0
	for o: Array in owners:
		var l: Light3D = o[0] as Light3D if is_instance_valid(o[0]) else null
		if l != null and l.is_visible_in_tree():
			k = maxf(k, energy_of(l) / float(o[1]))
	return clampf(k, 0.0, 1.5)


## The saved map holds its own copies of the materials, so glass is told by its look: Mats "lantern_glass"'s
## emission colour and energy.
static func _is_glass(m: Material, ref: Material) -> bool:
	var a: StandardMaterial3D = m as StandardMaterial3D
	var b: StandardMaterial3D = ref as StandardMaterial3D
	if a == null or b == null or not a.emission_enabled:
		return false
	if a == b:
		return true
	var ca: Color = a.emission
	var cb: Color = b.emission
	return absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) < 0.03 		and absf(a.emission_energy_multiplier - b.emission_energy_multiplier) < 0.05


## The lights within `radius` of a box. A much dimmer light there is something else's (the field radio's dial
## beside the bar lamp): only lights at least 40% as strong as the strongest one count.
static func _owners_near(lights: Array, box: AABB, radius: float) -> Array:
	var near: Array = []
	var top: float = 0.0
	var grown: AABB = box.grow(radius)
	for e: Array in lights:
		if grown.has_point((e[0] as Node3D).global_position):
			near.append(e)
			top = maxf(top, float(e[1]))
	return near.filter(func(e: Array) -> bool: return float(e[1]) >= top * 0.4)


static func _under_player(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p is Player:
			return true
		p = p.get_parent()
	return false
