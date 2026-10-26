class_name CasingPool
extends Node3D
## Ejected casings with the real cartridge models (UPDATE 05 section 6, T-095): the OpenGameArt "Ultimate Low Poly
## Guns" cartridge set (assets/third_party/opengameart/pichuliru-cartridges/model.glb, CC-BY, 15 named cases in
## metres with the case axis along +Y). Each case becomes one MultiMesh (re-centred, axis turned to +Z) with
## PER_KIND instances, so a belt of MG42 brass is one draw call per kind; each live casing is a kinematic arc
## (gravity, drag, spin, one small bounce off the floor found by a ray at ejection, then it lies still) and the
## first bounce plays a metallic tink when the sample exists. The weapon decides the case through
## models.json extras.cartridges.casing_for; the holder's casing kind (pistol / rifle / shell) is the fallback.
## Preallocated; nothing is created per shot. Owned by Effects; eject through Effects.casing().

var cfg: Dictionary = {}
var per_kind: int = 16
var life: float = 2.4
var bounce: float = 0.3
var casing_for: Dictionary = {}       # weapon base id -> case node name
var kind_default: Dictionary = {}     # pistol / rifle / shell -> case node name
var _mm: Dictionary = {}              # node name -> MultiMesh
var _state: Dictionary = {}           # node name -> Array of state Dictionaries
var _next: Dictionary = {}
var _live: int = 0
var _tink_t: float = 0.0
var _tink_key: String = ""
var _tink_gap: float = 0.05
var _skip: int = 0
## Casings thrown (tests / the dev overlay).
var ejected: int = 0
var loaded_from_glb: bool = false


func setup(casing_cfg: Dictionary, models_extras: Dictionary) -> void:
	cfg = casing_cfg
	per_kind = maxi(1, int(cfg.get("per_kind", 16)))
	life = float(cfg.get("life", 2.4))
	bounce = float(cfg.get("bounce", 0.3))
	kind_default = cfg.get("kind_default", {})
	_tink_key = str(cfg.get("tink", ""))
	_tink_gap = float(cfg.get("tink_min_gap", 0.05))
	var cart: Dictionary = models_extras.get("cartridges", {})
	casing_for = cart.get("casing_for", {})
	var nodes: Array = cart.get("nodes", [])
	var meshes: Dictionary = _load_meshes(str(cfg.get("glb", cart.get("glb", ""))))
	loaded_from_glb = not meshes.is_empty()
	var wanted: Array = nodes.duplicate()
	for k: String in kind_default.keys():
		if not wanted.has(kind_default[k]):
			wanted.append(kind_default[k])
	for node_name: String in wanted:
		var mesh: Mesh = meshes.get(node_name, null)
		if mesh == null:
			mesh = _fallback_mesh(node_name)
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = per_kind
		for i: int in per_kind:
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "Casings_" + node_name
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))
		add_child(mmi)
		_mm[node_name] = mm
		var states: Array = []
		for i: int in per_kind:
			states.append({"t": 0.0, "p": Vector3.ZERO, "v": Vector3.ZERO, "b": Basis(), "spin": Vector3.ZERO, "floor": -1000.0, "hit": false})
		_state[node_name] = states
		_next[node_name] = 0


## The case node for a weapon id (its base id when upgraded), else the kind's default, else the rifle default.
func node_for(weapon_id: StringName, kind: String) -> String:
	var id: String = String(weapon_id)
	if id != "":
		if casing_for.has(id):
			return str(casing_for[id])
		var weapons: Dictionary = GLData.table("weapons")
		var up: Dictionary = weapons.get("upgraded", {})
		if up.has(id):
			var base: String = str((up[id] as Dictionary).get("base", id))
			if casing_for.has(base):
				return str(casing_for[base])
		var row: Dictionary = (weapons.get("weapons", {}) as Dictionary).get(id, {})
		if row.has("base") and casing_for.has(str(row["base"])):
			return str(casing_for[str(row["base"])])
	return str(kind_default.get(kind, kind_default.get("rifle", "7_62x54mmR")))


## Throws one casing from `from` with world velocity `vel`, oriented by `basis` (case axis = local Z);
## `casings_k` < 1 (the quality row) drops every other one.
func eject(node_name: String, from: Vector3, vel: Vector3, basis: Basis, casings_k: float = 1.0) -> void:
	if not _mm.has(node_name):
		node_name = str(kind_default.get("rifle", ""))
		if not _mm.has(node_name):
			return
	if casings_k < 0.99:
		_skip += 1
		if _skip % 2 == 0:
			return
	ejected += 1
	var i: int = int(_next[node_name])
	_next[node_name] = (i + 1) % per_kind
	var c: Dictionary = (_state[node_name] as Array)[i]
	c["t"] = life
	c["p"] = from
	c["v"] = vel
	c["b"] = basis.orthonormalized()
	c["spin"] = Vector3(randf_range(-18, 18), randf_range(-6, 6), randf_range(-25, 25))
	c["floor"] = _floor_below(from)
	c["hit"] = false
	_live += 1


func _process(delta: float) -> void:
	_tink_t -= delta
	if _live <= 0:
		return
	_live = 0
	for node_name: String in _state.keys():
		var mm: MultiMesh = _mm[node_name]
		var states: Array = _state[node_name]
		for i: int in states.size():
			var c: Dictionary = states[i]
			var t: float = float(c["t"])
			if t <= 0.0:
				continue
			t -= delta
			c["t"] = t
			if t <= 0.0:
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				continue
			_live += 1
			var v: Vector3 = c["v"]
			var p: Vector3 = c["p"]
			var floor_y: float = float(c["floor"])
			if p.y > floor_y + 0.004 or v.y > 0.0:
				v.y -= 9.8 * delta
				v *= 1.0 - 0.6 * delta
				p += v * delta
				var spin: Vector3 = c["spin"]
				if spin.length_squared() > 0.0001:
					c["b"] = ((c["b"] as Basis) * Basis(spin.normalized(), spin.length() * delta)).orthonormalized()
				if p.y < floor_y:
					p.y = floor_y + 0.004
					if v.y < -0.8:
						v = Vector3(v.x * 0.45, -v.y * bounce, v.z * 0.45)
						c["spin"] = (c["spin"] as Vector3) * 0.5
						if not bool(c["hit"]):
							c["hit"] = true
							_tink(p)
					else:
						v = Vector3.ZERO
						c["spin"] = Vector3.ZERO
						# lie flat: the case axis (local Z) drops into the floor plane
						var b: Basis = c["b"]
						var z: Vector3 = b.z
						z.y = 0.0
						if z.length_squared() > 0.01:
							c["b"] = Basis.looking_at(z.normalized(), Vector3.UP)
				c["v"] = v
				c["p"] = p
			var scale_k: float = 1.0 if t > 0.3 else maxf(0.0, t / 0.3)   # sinks away over its last 0.3 s
			mm.set_instance_transform(i, Transform3D((c["b"] as Basis).scaled(Vector3.ONE * scale_k), p))


func _tink(at: Vector3) -> void:
	if _tink_key == "" or _tink_t > 0.0:
		return
	if not AudioDirector.has_sound(_tink_key):
		return
	_tink_t = _tink_gap
	AudioDirector.play_3d(_tink_key, at, -14.0, 0.12)


func _floor_below(at: Vector3) -> float:
	if not is_inside_tree():
		return at.y - 1.5
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.5, 1)
	var res: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return float((res["position"] as Vector3).y) if not res.is_empty() else at.y - 3.5


## Live casings (tests).
func live_count() -> int:
	return _live


func kinds() -> Array:
	return _mm.keys()


## The GLB's cases as re-centred meshes (case axis +Y -> +Z, the laid-out row offsets removed), keyed by node name.
static func _load_meshes(glb: String) -> Dictionary:
	var out: Dictionary = {}
	if glb == "" or not ResourceLoader.exists(glb):
		return out
	var ps: PackedScene = load(glb) as PackedScene
	if ps == null:
		return out
	var inst: Node = ps.instantiate()
	for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var holder: Node = mi
		var node_name: String = String(mi.name)
		if holder.get_parent() != null and holder.get_parent() != inst and mi.mesh.get_surface_count() > 0 and not _looks_like_case(node_name):
			node_name = String(holder.get_parent().name)
		var aabb: AABB = mi.mesh.get_aabb()
		var centre: Vector3 = aabb.get_center()
		var rot: Basis = Basis(Vector3.RIGHT, PI * 0.5)   # +Y -> +Z
		var xf: Transform3D = Transform3D(rot, rot * (-centre))
		var st: SurfaceTool = SurfaceTool.new()
		var mesh: ArrayMesh = ArrayMesh.new()
		for s: int in mi.mesh.get_surface_count():
			st.clear()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(mi.mesh, s, xf)
			st.commit(mesh)
			var mat: Material = mi.get_active_material(s)
			if mat != null:
				mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		out[node_name] = mesh
	inst.free()
	return out


static func _looks_like_case(n: String) -> bool:
	return n.contains("mm") or n.contains("ACP") or n.contains("Gauge") or n.contains("Magnum") or n.contains("Lapua") or n.contains("BMG") or n.contains("LR")


## Without the GLB (a missing import): a brass cylinder along +Z sized from the node name's family.
static func _fallback_mesh(node_name: String) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var brass: StandardMaterial3D = WeaponModels.base_mat("brass")
	var length: float = 0.03
	var radius: float = 0.005
	if node_name.begins_with("12_"):
		length = 0.07
		radius = 0.01
	elif node_name.begins_with("7_") or node_name.begins_with("50_") or node_name.begins_with("338"):
		length = 0.055
		radius = 0.006
	var cm: CylinderMesh = CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius * 0.9
	cm.height = length
	cm.radial_segments = 8
	cm.rings = 1
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(cm, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	st.commit(mesh)
	mesh.surface_set_material(0, brass)
	return mesh
