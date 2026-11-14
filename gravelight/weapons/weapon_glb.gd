class_name WeaponGLB
extends RefCounted
## Downloaded gun models as the first-person viewmodels (UPDATE_05 section 2, DECISIONS T-089).
##
## WeaponGLB.build(weapon_id, upgraded, camo, look) -> Node3D gives the same thing WeaponModels.build gives for a
## procedural gun, built from the GLB that data/gravelight/weapons/models.json maps to the id (T-087 intake):
##   frame      barrel along -Z, +Y up, origin at the right-hand grip, metres. The GLB (glTF axes, the pack's own
##              origin and scale) is normalised from its models.json `native` block: rotated so its forward axis
##              is -Z, scaled to real_length_m, and moved so the grip point (the trigger, when the converter found
##              one) sits where the procedural guns keep it; data/gravelight/weapons/model_fit.json refines every
##              gun by hand (extra_rot / extra_offset / scale, pivots, markers, hands);
##   parts      the pack's meshes become groups named with our contract (Mag, Bolt, Slide, Pump, Cover, Barrels,
##              Cylinder, Clip...), each a Node3D at its pivot (the hinge for Cover / Barrels, the part's centre
##              otherwise) holding the mesh, so WeaponHolder's reload / cycle choreography moves and turns them
##              exactly as it moves the procedural parts. A bolt rifle's Bolt gets the "Handle" child the holder
##              lifts (the whole bolt turns with it, as a real one does). Meshes a reload needs but the pack lacks
##              (a Kar98k "Mag" feed position) are empty nodes at the procedural model's position;
##   markers    Muzzle (bbox front on the bore line), SightPoint and FrontSight (Marker3Ds on the sight line: the
##              rear notch / aperture and the front post, found from the geometry's top profile and corrected in
##              model_fit), LeftHand (support hand), the metas reload / length / port / bore / grip_r /
##              grip_r_radius / lh_axis / lh_radius / cylinder / scope. Defaults come from the procedural model of
##              the same id (WeaponModels.build_greybox), so the reload kind and the hands stay what they were;
##   kit        attachments are dressed by the same M1911KitModels / WeaponKitModels code (primitives against the
##              GLB's markers; the M1911's hand-fitted parts shift by model_fit "kit_offset");
##   look       every surface runs through the shared weapon shader (WeaponShader): the Crucible version is the
##              same mesh with the Nachtglas veins turned on (section 2.6, a material, not a model), camo tints
##              the wood only.
## WeaponModels.build dispatches here when models.json has a GLB for the id and GLSettings.values["greybox_guns"]
## is not true (the A/B escape hatch); the six guns without a model keep the procedural build.
##
## Public for tools and the wonder-weapon builder: wants(id), glb_path(id), fit_for(id), normal_transform(id),
## part_bounds(id) (rig space), top_profile(root) and reload().

const MODELS_PATH: String = "res://data/gravelight/weapons/models.json"
const FIT_PATH: String = "res://data/gravelight/weapons/model_fit.json"
## models.json part key -> the contract name WeaponHolder reads.
const PART_NAMES: Dictionary = {"mag": "Mag", "bolt": "Bolt", "slide": "Slide", "pump": "Pump", "cover": "Cover",
	"barrels": "Barrels", "cylinder": "Cylinder", "clip": "Clip", "hammer": "Hammer", "trigger": "Trigger", "body": "Body",
	"stock": "Stock", "grip": "Grip", "foregrip": "Foregrip", "barrel": "Barrel", "shells": "Shells"}
## Where the trigger lands (rig space) when the grip origin is derived from the converter's trigger_center: the
## procedural pistols keep the trigger blade about 8 mm ahead of the origin and 6 mm below it.
const TRIGGER_AT: Vector3 = Vector3(0.0, -0.006, -0.008)
## Parts a vertex scan for sights / the muzzle ignores (they are not the gun's outline).
const SCAN_SKIP: PackedStringArray = ["Mag", "Clip", "Hammer", "Trigger", "Handle", "Shells", "Rocket", "Valve"]

static var _models: Dictionary = {}
static var _fit: Dictionary = {}
static var _scenes: Dictionary = {}       # glb path -> PackedScene
static var _loaded: bool = false
static var _scan_cache: Dictionary = {}   # weapon id -> {muzzle, front, rear, bbox}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_models = GLData.load_json(MODELS_PATH) if FileAccess.file_exists(MODELS_PATH) else {}
	_fit = GLData.load_json(FIT_PATH) if FileAccess.file_exists(FIT_PATH) else {}


## Drops the cached tables and scenes (tests, fit edits, the fit tool).
static func reload() -> void:
	_loaded = false
	_models = {}
	_fit = {}
	_scenes = {}
	_scan_cache = {}
	WeaponModels._templates.clear()
	_load()


static func models() -> Dictionary:
	_load()
	return _models


## The model_fit.json entry for a weapon ({} when it has none).
static func fit_for(weapon_id: StringName) -> Dictionary:
	_load()
	return (_fit.get("weapons", {}) as Dictionary).get(String(weapon_id).trim_suffix("_up"), {})


## The models.json weapon entry ({} when the id has no GLB).
static func entry(weapon_id: StringName) -> Dictionary:
	_load()
	var e: Dictionary = (_models.get("weapons", {}) as Dictionary).get(String(weapon_id).trim_suffix("_up"), {})
	return e if e.get("glb") != null else {}


## The GLB behind a weapon id ("" = none: a greybox or wonder weapon).
static func glb_path(weapon_id: StringName) -> String:
	return str(entry(weapon_id).get("glb", ""))


## True when WeaponModels.build should hand this id to the GLB path: a model is mapped and imported, and the
## greybox escape hatch (GLSettings.values["greybox_guns"]) is off.
static func wants(weapon_id: StringName) -> bool:
	var path: String = glb_path(weapon_id)
	if path == "":
		return false
	if bool(GLSettings.values.get("greybox_guns", false)):
		return false
	return ResourceLoader.exists(path)


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		var pt: int = BotProf.t()
		_scenes[path] = load(path) as PackedScene
		BotProf.add(&"gun.load", pt)
	return _scenes[path]


static func _v3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Vector3:
		return a
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## The rotation that turns the pack's forward axis onto -Z (about +Y).
static func forward_basis(forward: String) -> Basis:
	var deg: float = {"+X": 90.0, "-X": -90.0, "-Z": 0.0, "+Z": 180.0}.get(forward, 0.0)
	return Basis(Vector3.UP, deg_to_rad(deg))


## Native (glTF) -> rig space: forward rotation, model_fit extra_rot, scale to the real length, then the grip
## origin: the converter's trigger_center lands at TRIGGER_AT (plus model_fit extra_offset); without a trigger the
## pack origin goes to extra_offset.
static func normal_transform(weapon_id: StringName) -> Transform3D:
	var e: Dictionary = entry(weapon_id)
	if e.is_empty():
		return Transform3D.IDENTITY
	var n: Dictionary = e.get("native", {})
	var f: Dictionary = fit_for(weapon_id)
	var s: float = float(f.get("scale", n.get("scale", 1.0)))
	var extra: Basis = Basis.from_euler(_v3(f.get("extra_rot", [0, 0, 0])) * (PI / 180.0))
	var m: Basis = extra * forward_basis(str(n.get("forward", "-Z"))) * Basis.from_scale(Vector3.ONE * s)
	var g: Vector3 = Vector3.ZERO
	var off: Vector3 = _v3(f.get("extra_offset", [0, 0, 0]))
	if f.has("grip_native"):
		g = _v3(f["grip_native"])
	elif n.has("trigger_center"):
		g = _v3(n["trigger_center"])
		off += TRIGGER_AT
	return Transform3D(m, off - m * g)


## A part's bounds in rig space, from the imported mesh itself (the converter's part_bounds in models.json are
## not reliable for every part), or an empty AABB when the node is not in the GLB.
static func part_bounds(weapon_id: StringName, node_name: String) -> AABB:
	var path: String = glb_path(weapon_id)
	if path == "" or not ResourceLoader.exists(path):
		return AABB()
	var inst: Node3D = _scene(path).instantiate() as Node3D
	var mi: MeshInstance3D = inst.find_child(node_name, true, false) as MeshInstance3D
	var out: AABB = AABB()
	if mi != null and mi.mesh != null:
		var rel: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != inst:
			rel = (p as Node3D).transform * rel
			p = p.get_parent()
		out = (normal_transform(weapon_id) * rel) * mi.mesh.get_aabb()
	inst.free()
	return out


## Rig-space bounds of a group's meshes ([[mesh, xf_rig, node name]] as collected by build).
static func _mesh_bounds(items: Array) -> AABB:
	var bb: AABB = AABB()
	var first: bool = true
	for item: Array in items:
		var mi: MeshInstance3D = item[0]
		if mi.mesh == null:
			continue
		var a: AABB = (item[1] as Transform3D) * mi.mesh.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	return bb


# ================================================================== build

static func build(weapon_id: StringName, is_upgraded: bool = false, camo_id: StringName = &"", look_d: Dictionary = {}) -> Node3D:
	_load()
	var base: String = String(weapon_id).trim_suffix("_up")
	var e: Dictionary = entry(StringName(base))
	var f: Dictionary = fit_for(StringName(base))
	var scene: PackedScene = _scene(str(e["glb"]))
	var inst: Node3D = scene.instantiate() as Node3D
	# the procedural twin: the reload kind, hands and metas it carried stay the defaults
	var proc: Node3D = WeaponModels.build_greybox(StringName(base), false, &"", {})
	var b: WeaponModels = WeaponModels.new()
	b.upgraded = is_upgraded or String(weapon_id).ends_with("_up")
	b.camo = camo_id
	b.look = look_d
	b.root = Node3D.new()
	b.root.name = "Model_" + base
	var root: Node3D = b.root
	for k: StringName in proc.get_meta_list():
		root.set_meta(k, proc.get_meta(k))
	root.set_meta("length", float(f.get("length", float((e.get("native", {}) as Dictionary).get("real_length_m", proc.get_meta("length", 0.6))))))
	if f.has("reload"):
		root.set_meta("reload", str(f["reload"]))
	var reload_kind: String = str(root.get_meta("reload", "mag"))
	var t: Transform3D = normal_transform(StringName(base))
	# ---- parts: every pack mesh into a contract-named group at its pivot
	var parts_rev: Dictionary = {}
	for key: String in (e.get("parts", {}) as Dictionary).keys():
		var contract: String = str(PART_NAMES.get(key, key.capitalize()))
		if key == "clip" and reload_kind == "enbloc":
			contract = "Mag"       # the en-bloc clip is what the Garand's "Mag" choreography moves
		parts_rev[str(e["parts"][key])] = contract
	var rename: Dictionary = f.get("rename", {})
	var hide: Array = f.get("hide", [])
	var pivots: Dictionary = f.get("pivots", {})
	var parents: Dictionary = f.get("parent", {})
	var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
	var groups: Dictionary = {}          # contract name -> Node3D
	var group_pivot: Dictionary = {}     # contract name -> rig-space pivot
	var by_group: Dictionary = {}        # contract name -> [[mesh, xf_rig]]
	for m: Node in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		var node_name: String = String(mi.name)
		if hide.has(node_name):
			continue
		var contract: String = str(rename.get(node_name, parts_rev.get(node_name, node_name)))
		var rel: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != inst:
			rel = (p as Node3D).transform * rel
			p = p.get_parent()
		if not by_group.has(contract):
			by_group[contract] = []
		(by_group[contract] as Array).append([mi, t * rel, node_name])
	for contract: String in by_group.keys():
		var pivot: Vector3
		# a per-part scale about a point (model_fit part_scale / part_scale_about): the Sawed-Off's barrels cut down
		var ps: Dictionary = f.get("part_scale", {})
		if ps.has(contract):
			var sc: Vector3 = _v3(ps[contract], Vector3.ONE)
			var about: Vector3 = _v3((f.get("part_scale_about", {}) as Dictionary).get(contract), _mesh_bounds(by_group[contract]).get_center())
			var sxf: Transform3D = Transform3D(Basis(), about) * Transform3D(Basis.from_scale(sc), Vector3.ZERO) * Transform3D(Basis(), -about)
			for item: Array in by_group[contract]:
				item[1] = sxf * (item[1] as Transform3D)
		var po: Dictionary = f.get("part_offset", {})
		if po.has(contract):
			# a part moved to where it belongs on the gun (the Garand's floating clip into the receiver)
			var shift: Transform3D = Transform3D(Basis(), _v3(po[contract]))
			for item: Array in by_group[contract]:
				item[1] = shift * (item[1] as Transform3D)
		var wp: Dictionary = f.get("warp", {})
		if wp.has(contract):
			for item: Array in by_group[contract]:
				_warp_mesh(item[0] as MeshInstance3D, item[1] as Transform3D, wp[contract])
		if pivots.has(contract):
			pivot = _v3(pivots[contract])
		else:
			pivot = _mesh_bounds(by_group[contract]).get_center()
		group_pivot[contract] = pivot
		var g: Node3D = Node3D.new()
		g.name = contract
		groups[contract] = g
	for contract: String in groups.keys():
		var g: Node3D = groups[contract]
		var host: Node3D = root
		var parent_pivot: Vector3 = Vector3.ZERO
		var pn: String = str(parents.get(contract, ""))
		if pn != "" and groups.has(pn):
			host = groups[pn]
			parent_pivot = group_pivot[pn]
		g.position = (group_pivot[contract] as Vector3) - parent_pivot
		host.add_child(g)
		var mesh_host: Node3D = g
		if contract == "Bolt" and reload_kind == "bolt":
			# the handle the firing hand works: lifting it turns the whole bolt about its axis
			var h: Node3D = Node3D.new()
			h.name = "Handle"
			h.rotation_degrees = Vector3(0, 0, -50)
			g.add_child(h)
			mesh_host = h
		for item: Array in by_group[contract]:
			var mi: MeshInstance3D = item[0]
			var xf: Transform3D = item[1]
			mi.owner = null
			mi.get_parent().remove_child(mi)
			mi.name = str(item[2]) if str(item[2]) != contract else "Mesh"
			mi.transform = Transform3D(Basis(), -(group_pivot[contract] as Vector3)) * xf
			if mesh_host != g:
				mi.transform = mesh_host.transform.affine_inverse() * mi.transform
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta("glb", true)
			mesh_host.add_child(mi)
	inst.free()
	_borrow(b, f, groups, group_pivot)
	# ---- markers and hands
	var scan: Dictionary = _scan(root, StringName(base), f)
	var muzzle: Vector3 = _v3(f.get("muzzle"), scan["muzzle"])
	b.marker("Muzzle", muzzle)
	var rear: Vector3 = _v3(f.get("sight_rear"), scan["rear"])
	var front: Vector3 = _v3(f.get("sight_front"), scan["front"])
	# the sights ride on the part that carries them: a pistol's Slide by default, else the root (fixed);
	# model_fit sight_rear_on / sight_front_on name another group ("root" for the gun body)
	var default_host: String = "Slide" if groups.has("Slide") else "root"
	var rear_host: Node3D = _host(root, groups, str(f.get("sight_rear_on", f.get("sights_on", default_host))))
	var front_host: Node3D = _host(root, groups, str(f.get("sight_front_on", f.get("sights_on", default_host))))
	if f.has("scope"):
		_add_scope(b, f["scope"])
	else:
		b.sight_mark("SightPoint", _into(root, rear_host, rear), rear_host)
		b.sight_mark("FrontSight", _into(root, front_host, front), front_host)
	var proc_lh: Node3D = proc.get_node_or_null("LeftHand") as Node3D
	var lh: Vector3 = _v3(f.get("left_hand"), proc_lh.position if proc_lh != null else Vector3(0, -0.02, -0.25))
	b.lhand(lh, str(f.get("lh_axis", root.get_meta("lh_axis", "z"))), float(f.get("lh_radius", root.get_meta("lh_radius", 0.024))))
	var grip_xf: Transform3D = root.get_meta("grip_r", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(0, -0.045, 0.05)))
	var lean: float = rad_to_deg(-grip_xf.basis.get_euler().x)
	b.rhand(_v3(f.get("grip_r"), grip_xf.origin), float(f.get("grip_lean", lean)), float(f.get("grip_r_radius", root.get_meta("grip_r_radius", WeaponModels.HAND_R0))))
	for key: String in ["port", "bore", "cylinder", "scope_mag", "eye_relief", "mag_dir"]:
		if f.has(key):
			root.set_meta(key if key != "scope_mag" else "scope", _v3(f[key]) if key in ["port", "mag_dir"] else f[key])
	# empty nodes for the parts a reload kind expects but the pack has no mesh for
	for part: String in ["Mag", "Bolt", "Pump", "Cover", "Barrels", "Rocket", "Valve"]:
		if root.get_node_or_null(part) == null and proc.get_node_or_null(part) != null:
			var at: Vector3 = _v3((f.get("empty", {}) as Dictionary).get(part), (proc.get_node(part) as Node3D).position)
			b.marker(part, at)
	proc.free()
	# ---- attachments, the bore, the glow; the shared shader last
	if base == "m1911":
		_m1911_kit(b, f, groups)
	elif not b.look.is_empty():
		WeaponKitModels.dress(b)
	if root.has_meta("bore") and not f.has("no_bore"):
		var mz: Vector3 = (root.get_node("Muzzle") as Node3D).position
		b.tube(float(root.get_meta("bore")), float(root.get_meta("bore")), 0.004, mz + Vector3(0, 0, 0.0015), "black")
	if b.upgraded:
		b._nachtglas_glow()
	WeaponModels.merge_static(root)
	if root.has_node("KitFlash"):
		(root.get_node("KitFlash") as Node3D).hide()
	WeaponShader.apply(root, {"upgraded": b.upgraded, "camo": camo_id, "finish": str(look_d.get("finish", "")),
		"palette": _is_palette(StringName(base)), "scale": t.basis.get_scale().x, "fit": f.get("shader", {})})
	if f.has("wonder"):
		WonderLook.finish(root, base, b.upgraded, f["wonder"])   # T-090: glass / fluid / glow surfaces, the Crucible parts and look
	return root


## model_fit "warp" {Part: {z0, z1, dy}} (T-098): bends a part of a one-piece mesh in rig space: every vertex behind
## z1 moves dy metres up (negative = down), easing in from nothing at z0, so a stock can take more drop below the
## sight line (the OGA STG44's comb filled the bottom of the sight picture). The mesh is copied (the imported one is
## shared by every instance of the scene); it is a visual change only, like every model_fit key.
static func _warp_mesh(mi: MeshInstance3D, xf: Transform3D, d: Dictionary) -> void:
	if mi.mesh == null:
		return
	var z0: float = float(d.get("z0", 0.0))
	var z1: float = float(d.get("z1", z0 + 0.01))
	var dy: float = float(d.get("dy", 0.0))
	var inv: Transform3D = xf.affine_inverse()
	var out: ArrayMesh = ArrayMesh.new()
	for si: int in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i: int in vs.size():
			var g: Vector3 = xf * vs[i]
			var k: float = smoothstep(z0, z1, g.z) if z1 > z0 else (1.0 if g.z >= z0 else 0.0)
			if k > 0.0:
				vs[i] = inv * (g + Vector3(0.0, dy * k, 0.0))
		arr[Mesh.ARRAY_VERTEX] = vs
		out.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(si), arr)
		out.surface_set_material(si, mi.mesh.surface_get_material(si))
		out.surface_set_name(si, mi.mesh.surface_get_name(si))
	mi.mesh = out


static func _host(root: Node3D, groups: Dictionary, name: String) -> Node3D:
	return groups[name] as Node3D if groups.has(name) else root


## A point in root space expressed in `host`'s space (host is root or a direct part group of it).
static func _into(root: Node3D, host: Node3D, p: Vector3) -> Vector3:
	if host == root:
		return p
	var xf: Transform3D = host.transform
	var n: Node = host.get_parent()
	while n != null and n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf.affine_inverse() * p


## True for the OpenGameArt palette guns (one flat 8x8 colour texture: the shader must add the detail).
static func _is_palette(weapon_id: StringName) -> bool:
	return str(entry(weapon_id).get("source", "")) == "opengameart"


## Parts borrowed from another converted asset (model_fit "borrow": {Contract: {asset, node, forward, scale,
## offset}}): the OGA M1A1's stick magazine on the Sketchfab 1928 Thompson, for instance. The borrowed mesh is
## normalised with the donor's own axes and scale and placed by `offset` (rig space).
static func _borrow(b: WeaponModels, f: Dictionary, groups: Dictionary, group_pivot: Dictionary) -> void:
	var bw: Dictionary = f.get("borrow", {})
	if bw.is_empty():
		return
	for contract: String in bw.keys():
		var d: Dictionary = bw[contract]
		var a: Dictionary = (_models.get("assets", {}) as Dictionary).get(str(d.get("asset", "")), {})
		if a.is_empty() or not ResourceLoader.exists(str(a.get("glb", ""))):
			continue
		var donor: Node3D = _scene(str(a["glb"])).instantiate() as Node3D
		var src: MeshInstance3D = donor.find_child(str(d.get("node", contract)), true, false) as MeshInstance3D
		if src == null:
			donor.free()
			continue
		var n: Dictionary = a.get("native", {})
		var s: float = float(d.get("scale", n.get("scale", 1.0)))
		var m: Basis = Basis.from_euler(_v3(d.get("extra_rot", [0, 0, 0])) * (PI / 180.0)) * forward_basis(str(n.get("forward", "-Z"))) * Basis.from_scale(Vector3.ONE * s)
		# the donor part's own centre goes to `offset`
		var pb: Dictionary = a.get("part_bounds", {})
		var centre: Vector3 = Vector3.ZERO
		if pb.has(str(src.name)):
			centre = (_v3(pb[str(src.name)][0]) + _v3(pb[str(src.name)][1])) * 0.5
		var at: Vector3 = _v3(d.get("offset", [0, 0, 0]))
		var g: Node3D = groups.get(contract) as Node3D
		if g == null:
			g = Node3D.new()
			g.name = contract
			g.position = at
			b.root.add_child(g)
			groups[contract] = g
			group_pivot[contract] = at
		var mi: MeshInstance3D = src.duplicate() as MeshInstance3D
		mi.name = "Borrowed"
		mi.transform = Transform3D(m, at - m * centre - (group_pivot[contract] as Vector3))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("glb", true)
		g.add_child(mi)
		donor.free()


## The procedural M73B1-style scope (the Springfield's) on a GLB that has none: model_fit "scope": {y, z0 (eyepiece),
## z1 (objective), mag}. SightPoint / FrontSight go to the eyepiece / objective, meta "scope" turns on the HUD picture.
static func _add_scope(b: WeaponModels, d: Dictionary) -> void:
	var y: float = float(d.get("y", 0.09))
	var z0: float = float(d.get("z0", 0.126))
	var z1: float = float(d.get("z1", -0.236))
	var zc: float = (z0 + z1) * 0.5
	var r: float = float(d.get("r", 0.012))
	b.tube(r, r, absf(z1 - z0) - 0.1, Vector3(0, y, zc), "black")
	b.tube(r + 0.008, r, 0.06, Vector3(0, y, z1 + 0.03), "black")
	b.tube(r + 0.0045, r, 0.05, Vector3(0, y, z0 - 0.026), "black")
	var base_y: float = float(d.get("base_y", y - 0.03))
	for z: float in [zc - 0.07, zc + 0.07]:
		b.tube(r + 0.004, r + 0.004, 0.014, Vector3(0, y, z), "black")
		b.box(Vector3(0.016, y - base_y, 0.014), Vector3(0, (y + base_y) * 0.5, z), "black")
	b.box(Vector3(0.018, 0.012, 0.03), Vector3(0, y + 0.002, zc), "black")
	b.tube(r + 0.0035, r + 0.0035, 0.002, Vector3(0, y, z0), "glass")
	b.tube(r + 0.007, r + 0.007, 0.002, Vector3(0, y, z1), "glass")
	b.scope_sight(Vector3(0, y, z0), Vector3(0, y, z1))
	b.root.set_meta("scope", float(d.get("mag", 4.0)))


## The M1911's hand-fitted attachments (M1911KitModels, built for the procedural pistol): one slot at a time, every
## node a slot adds shifted by model_fit "kit_offset" {slot: [x,y,z]} (or one [x,y,z] for all) so it sits on the
## OGA pistol: the barrel parts by the muzzle's difference, the magazine and grip parts by the grip's.
static func _m1911_kit(b: WeaponModels, f: Dictionary, groups: Dictionary) -> void:
	if b.look.is_empty():
		return
	var full: Dictionary = b.look
	var kit: Dictionary = full.get("kit", {})
	var ko: Variant = f.get("kit_offset", {})
	var sl: Node3D = groups.get("Slide") as Node3D
	var hosts: Array = [b.root]
	if sl != null:
		hosts.append(sl)
	if b.root.get_node_or_null("Mag") != null:
		hosts.append(b.root.get_node("Mag"))
	for slot: String in ["sights", "mag", "barrel", "grip", "ammo", "finish"]:
		var opt: String = str(full.get("finish", "")) if slot == "finish" else str(kit.get(slot, ""))
		if opt == "":
			continue
		var off: Vector3 = _v3(ko.get(slot, [0, 0, 0])) if ko is Dictionary else _v3(ko)
		var before: Dictionary = {}
		for h: Node3D in hosts:
			before[h] = h.get_children().duplicate()
		var mz: Node3D = b.root.get_node_or_null("Muzzle") as Node3D
		var mz_before: Vector3 = mz.position if mz != null else Vector3.ZERO
		var front_off: Vector3 = _v3((f.get("kit_offset_front", {}) as Dictionary).get(slot, [0, 0, 0]))
		var marks: Dictionary = {}
		for mn: String in ["SightPoint", "FrontSight"]:
			var mk: Node3D = b.root.find_child(mn, true, false) as Node3D
			if mk != null:
				marks[mn] = [mk, mk.position]
		# a look with only this slot (the finish keeps the kit so the inlay rule sees it)
		b.look = {"kit": {slot: opt} if slot != "finish" else {}, "finish": full.get("finish", "") if slot == "finish" else "", "sig": full.get("sig", ""), "id": full.get("id", "")}
		if slot == "sights":
			if sl != null:
				M1911KitModels.build_sights(b, sl, 0.051)
		else:
			M1911KitModels.dress(b)
		for h: Node3D in hosts:
			# the kit code builds in the procedural pistol's frame, where the Slide and Mag groups sit at the origin:
			# a part under a group here also undoes that group's offset. Parts ahead of the dust cover (z < -0.08,
			# the front sight) take kit_offset_front on top: the OGA slide is shorter than ours.
			var shift: Vector3 = off - (h.position if h != b.root else Vector3.ZERO)
			for c: Node in h.get_children():
				if not (before[h] as Array).has(c) and c is Node3D:
					var cn: Node3D = c as Node3D
					cn.position += shift + (front_off if cn.position.z < -0.08 else Vector3.ZERO)
		for mn: String in marks.keys():
			var mk2: Node3D = marks[mn][0]
			if is_instance_valid(mk2) and mk2.position != marks[mn][1]:
				var hs: Vector3 = off - ((mk2.get_parent() as Node3D).position if mk2.get_parent() != b.root else Vector3.ZERO)
				mk2.position += hs + (front_off if mk2.position.z < -0.08 else Vector3.ZERO)
		if mz != null and mz.position != mz_before:
			mz.position += off
	b.look = full


# ================================================================== geometry scans

## Where the geometry says the muzzle and the sights are (rig space), from a vertex scan of the normalised gun:
## muzzle = the centre of the front 3 cm of the barrel; FrontSight = the highest point in the front quarter;
## SightPoint = the highest point behind it, on the receiver (a pistol: the rear fifth; a long gun: the stretch
## between the front quarter and the stock). model_fit overrides any of them. Cached per id.
static func _scan(root: Node3D, weapon_id: StringName, f: Dictionary) -> Dictionary:
	if _scan_cache.has(weapon_id):
		return _scan_cache[weapon_id]
	var pts: PackedVector3Array = _outline_vertices(root)
	var bb: AABB = AABB()
	for i: int in pts.size():
		bb = AABB(pts[i], Vector3.ZERO) if i == 0 else bb.expand(pts[i])
	var L: float = maxf(0.05, bb.size.z)
	var zf: float = bb.position.z
	var zb: float = bb.end.z
	var long_gun: bool = L > 0.5
	var muzzle_sum: Vector3 = Vector3.ZERO
	var muzzle_n: int = 0
	var front: Vector3 = Vector3(0, -INF, 0)
	var rear: Vector3 = Vector3(0, -INF, 0)
	var rear_z0: float = zf + L * (0.25 if long_gun else 0.5)
	var rear_z1: float = zb - L * (float(f.get("stock_share", 0.3)) if long_gun else 0.0)
	for p: Vector3 in pts:
		if p.z < zf + 0.03:
			muzzle_sum += p
			muzzle_n += 1
		if p.z < zf + L * 0.25 and absf(p.x) < 0.012 and p.y > front.y:
			front = p
		if p.z >= rear_z0 and p.z <= rear_z1 and absf(p.x) < 0.012 and p.y > rear.y:
			rear = p
	var muzzle: Vector3 = muzzle_sum / float(maxi(1, muzzle_n))
	muzzle.z = zf
	muzzle.x = 0.0
	if front.y == -INF:
		front = Vector3(0, muzzle.y + 0.02, zf + 0.02)
	if rear.y == -INF:
		rear = Vector3(0, front.y, zb - L * 0.35)
	front.x = 0.0
	rear.x = 0.0
	var out: Dictionary = {"muzzle": muzzle, "front": front, "rear": rear, "bbox": bb}
	_scan_cache[weapon_id] = out
	return out


## Every vertex of the gun's fixed outline (rig space): the GLB meshes except the parts in SCAN_SKIP.
static func _outline_vertices(root: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for c: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not mi.has_meta("glb"):
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		var bad: bool = false
		while p != null and p != root:
			if SCAN_SKIP.has(String(p.name)):
				bad = true
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		if bad:
			continue
		for si: int in mi.mesh.get_surface_count():
			var vs: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vs:
				out.append(xf * v)
	return out


## The top profile of a built gun: [[z, max y, part]] per 1 cm bin from the muzzle back (the fit tool prints it so
## the sights can be read off the geometry).
static func top_profile(root: Node3D, bin: float = 0.01) -> Array:
	var best: Dictionary = {}
	for c: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not mi.has_meta("glb"):
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		var part: String = ""
		while p != null and p != root:
			part = String(p.name) if part == "" or String(p.name) != "Handle" else part
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		for si: int in mi.mesh.get_surface_count():
			for v: Vector3 in (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var g: Vector3 = xf * v
				if absf(g.x) > 0.015:
					continue
				var k: int = floori(g.z / bin)
				if not best.has(k) or g.y > float((best[k] as Array)[1]):
					best[k] = [k * bin, g.y, part]
	var keys: Array = best.keys()
	keys.sort()
	var out: Array = []
	for k: int in keys:
		out.append(best[k])
	return out
