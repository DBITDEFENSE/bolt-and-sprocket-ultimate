extends RefCounted
## Act II "der Kranich" dressing (UPDATE 09 section 5.3, DECISIONS T-147): the zones' pieces, fixtures and lights,
## as static functions the act generator (gen_map04b.gd) calls with itself (`g`: its `dress` node and its light
## lists power() / lamp() / shaft()). Everything here is dressing: no collider, nothing in the walkable volume below
## 2.1 m except on top of a collider the generator already makes (rack bases, the galley counter, the bunks, the
## radio desk, the engineer's station, the gun mounts, the seats, the cradle) or flush with the deck / a wall face;
## storage sits in the shell's cavities behind the wall faces (tools_src/blender/world/kranich_shell.py: the skin is
## 0.6 m behind the room face where the outside is free). Kept groups (meta keep) are the things that move:
## "flight_swing" (lamps, harness straps; FlightSky swings them with the bank), "flight_spin" (the impeller, the tape
## reels), "flight_rod" (control rods); each is merged per material into one mesh so it costs a draw call or two.

const CEIL_BAY: float = 4.83     # the bay's arch, inner flange at the crown (shell: crown 5.15 - 0.32)
const CEIL_BODY: float = 3.73
const CEIL_ROOM: float = 5.08
const CEIL_COCKPIT: float = 5.38
const SPAR_BOTTOM: float = 2.41  # the wing's main spar underside at z 37

static var _sw: int = 0


# ================================================================== small helpers

## A block with a material key or a Material (the shell's primer from KranichShell).
static func blk(parent: Node3D, a: Vector3, b: Vector3, m: Variant, shadows: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.block(parent, a, b, "steel" if not (m is String) else str(m), shadows)
	if mi != null and m is Material:
		mi.material_override = m
	return mi


static func cy(parent: Node3D, c: Vector3, r: float, h: float, m: Variant, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.cyl(parent, c, r, h, "steel" if not (m is String) else str(m), rot)
	if mi != null and m is Material:
		mi.material_override = m
	return mi


static func ns(mi: GeometryInstance3D) -> GeometryInstance3D:
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func primer() -> Material:
	return KranichShell.frame_material()


## A kept, moving group: name, pivot, group ("flight_swing" | "flight_spin" | "flight_rod"), metas.
static func mover(g: Variant, n: String, pos: Vector3, grp: StringName, metas: Dictionary = {}, parent: Node3D = null) -> Node3D:
	var node: Node3D = Props.group(parent if parent != null else g.dress, n, pos)
	node.set_meta("keep", true)
	for k: String in metas.keys():
		node.set_meta(k, metas[k])
	node.add_to_group(grp, true)
	return node


## Merges a kept group's primitive meshes per material into one ArrayMesh each (node-local), so a moving lamp or
## strap is one or two draw calls.
static func merge_local(node: Node3D) -> void:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null:
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != node:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var key: String = "%d|%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"st": st, "mat": mi.material_override, "shadow": mi.cast_shadow}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
		victims.append(mi)
	for mi2: MeshInstance3D in victims:
		mi2.get_parent().remove_child(mi2)
		mi2.free()
	for c: Node in node.get_children():
		if c.get_class() == "Node3D" and c.get_child_count() == 0 and c.get_script() == null:
			node.remove_child(c)
			c.free()
	var i: int = 0
	for k2: String in groups.keys():
		var e: Dictionary = groups[k2]
		var arrays: Array = (e["st"] as SurfaceTool).commit_to_arrays()
		arrays[Mesh.ARRAY_TEX_UV] = null
		var am: ArrayMesh = ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Mesh%d" % i
		out.mesh = am
		out.material_override = e["mat"]
		out.cast_shadow = e["shadow"]
		node.add_child(out)
		i += 1


## A caged lamp hanging `length` below `top` on its cable; it swings with the bank. With `zone` it is a power light
## (dark until the aux bus is thrown: its bulb is a twin pendulum the generator parents under the light afterwards),
## else an always-on lamp (the emergency reds).
static func caged_lamp(g: Variant, top: Vector3, length: float, zone: String, color: Color, energy: float, range_: float,
		bulb_key: String = "bulb_warm", shadow: bool = false) -> void:
	_sw += 1
	var phase: float = float(_sw) * 1.37
	var fx: Node3D = mover(g, "SwingLamp%d" % _sw, top, &"flight_swing", {"swing_len": length, "swing_phase": phase})
	Props.cable(fx, Vector3.ZERO, Vector3(0, -length + 0.16, 0), 0.0, 0.012, 2, "iron")
	cy(fx, Vector3(0, -length + 0.14, 0), 0.075, 0.06, "iron")
	for a: float in [0.0, 90.0, 180.0, 270.0]:
		var d: Vector3 = Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 0.085
		ns(Props.obox(fx, Vector3(0, -length, 0) + d, Vector3(0.012, 0.26, 0.012), "iron"))
	ns(cy(fx, Vector3(0, -length - 0.13, 0), 0.09, 0.015, "iron"))
	ns(cy(fx, Vector3(0, -length + 0.02, 0), 0.095, 0.015, "iron"))
	merge_local(fx)
	var bulb_holder: Node3D = mover(g, "SwingBulb%d" % _sw, top, &"flight_swing", {"swing_len": length, "swing_phase": phase})
	ns(Props.ball(bulb_holder, Vector3(0, -length, 0), Vector3(0.11, 0.14, 0.11), bulb_key))
	merge_local(bulb_holder)
	var lp: Vector3 = top + Vector3(0, -length - 0.1, 0)
	if zone != "":
		bulb_holder.set_meta("power_zone", zone)
		g.power(zone, lp, range_, energy, color, shadow)
	else:
		g.lamp(lp, color, energy, range_, 0.1, 0.5, shadow)


## A caged bulkhead lamp on a wall or a frame, `yaw` facing the room (always on unless zone is given).
static func wall_lamp(g: Variant, pos: Vector3, yaw: float, zone: String, color: Color, energy: float, range_: float, glass: String = "bulb_warm") -> void:
	Props.bulkhead_lamp(g.dress, pos, yaw, glass)
	var out: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -0.3)
	if zone != "":
		g.power(zone, pos + out, range_, energy, color)
	else:
		g.lamp(pos + out, color, energy, range_, 0.08, 0.4)


## A stencilled placard (Label3D) facing `yaw`.
static func placard(g: Variant, pos: Vector3, yaw: float, text: String, px: int = 28, col: Color = Color(0.9, 0.86, 0.72, 0.8)) -> void:
	Props.stencil(g.dress, pos, yaw, text, px, col)


## Chalk on a surface (crew tallies, the marks): pale, rough.
static func chalk(g: Variant, pos: Vector3, yaw: float, text: String, px: int = 34) -> void:
	Props.stencil(g.dress, pos, yaw, text, px, Color(0.92, 0.92, 0.86, 0.7))


## Oxygen / compressed-air bottles standing in a wall cavity between two frames: x_face = the room face, s = +1 when
## the cavity is toward +X (the starboard wall), along z from z0.
static func bottles(g: Variant, x_face: float, s: float, z0: float, n: int, key: String = "enamel_green") -> void:
	for i: int in n:
		var c: Vector3 = Vector3(x_face + s * 0.3, 0.72, z0 + 0.27 * float(i))
		cy(g.dress, c, 0.11, 1.32, key)
		ns(cy(g.dress, c + Vector3(0, 0.72, 0), 0.04, 0.12, "brass"))
	blk(g.dress, Vector3(x_face + s * 0.12, 1.05, z0 - 0.15), Vector3(x_face + s * 0.16, 1.1, z0 + 0.27 * float(n) - 0.1), "iron")


# ================================================================== the act

static func dress_all(g: Variant) -> void:
	_sw = 0
	bay(g)
	body(g)
	wing(g, -1.0)
	wing(g, 1.0)
	engine_room(g)
	kanzel(g)
	walkway(g, -1.0)
	walkway(g, 1.0)
	cockpit(g)
	london_plate(g)
	signage(g)


# ---------------------------------------------------------------- A Bombenschacht

static func bay(g: Variant) -> void:
	var pm: Material = primer()
	# the six racks: a cradle on each base (the base is a collider), two posts and a shackle beam over the casing
	var n: int = 1
	for z: float in [6.0, 12.0, 18.0]:
		for sx: float in [-5.6, 5.6]:
			var x0: float = sx - 1.4
			var x1: float = sx + 1.4
			blk(g.dress, Vector3(x0, 0.0, z - 1.2), Vector3(x1, 0.5, z + 1.2), "machine_grey")
			blk(g.dress, Vector3(x0 - 0.02, 0.5, z - 1.22), Vector3(x1 + 0.02, 0.58, z + 1.22), pm)
			for dz: float in [-0.75, 0.75]:
				Props.prism(g.dress, Vector3(sx, 0.62, z + dz), Vector3(1.0, 0.16, 0.18), "iron", Vector3(180, 0, 0))
			for dz2: float in [-1.05, 1.05]:
				blk(g.dress, Vector3(sx - 0.08, 0.58, z + dz2 - 0.08), Vector3(sx + 0.08, 2.55, z + dz2 + 0.08), pm)
			blk(g.dress, Vector3(sx - 0.1, 2.4, z - 1.15), Vector3(sx + 0.1, 2.6, z + 1.15), pm)
			# sway braces from the beam to the post feet
			for dz3: float in [-1.0, 1.0]:
				Props.strut(g.dress, Vector3(sx, 2.4, z), Vector3(sx, 0.62, z + dz3 * 1.05), 0.04, "iron")
			# the rack number and the crew's chalk on the base's aisle face
			var face_x: float = x0 - 0.01 if sx > 0.0 else x1 + 0.01
			var yaw: float = 90.0 if sx > 0.0 else -90.0
			placard(g, Vector3(face_x, 0.32, z - 0.7), yaw, "%d" % n, 64, Color(0.95, 0.85, 0.3, 0.85))
			chalk(g, Vector3(face_x, 0.3, z + 0.35), yaw, ["geprüft", "IIII", "Z 7", "voll", "IIII I", "nachladen"][n - 1], 26)
			n += 1
	# the bay doors' rams under the grating (seen through it), the operating shaft along the forward bulkhead
	for sx2: float in [-1.0, 1.0]:
		for z2: float in [3.0, 9.0, 15.0, 21.0]:
			var a: Vector3 = Vector3(sx2 * 3.7, -0.12, z2)
			var b: Vector3 = Vector3(sx2 * 6.4, -0.38, z2 + 0.6)
			Props.strut(g.dress, a, b, 0.09, "machine_grey", true)
			Props.strut(g.dress, a.lerp(b, 0.45), b, 0.06, "chrome_worn", true)
		Props.pipe(g.dress, Vector3(sx2 * 4.6, -0.3, 0.6), Vector3(sx2 * 4.6, -0.3, 23.4), 0.03, "copper")
	cy(g.dress, Vector3(0, 3.1, 23.75), 0.08, 17.0, pm, Vector3(0, 0, 90))
	for sx3: float in [-6.5, -2.0, 2.0, 6.5]:
		blk(g.dress, Vector3(sx3 - 0.12, 2.95, 23.6), Vector3(sx3 + 0.12, 3.25, 23.85), "iron")
	# the ramp: a heavy plate on the aft bulkhead with its hinge, two rams, the locking dogs, the stripes
	blk(g.dress, Vector3(-3.6, 0.0, 0.15), Vector3(3.6, 4.0, 0.27), pm)
	for i: int in 7:
		blk(g.dress, Vector3(-3.4 + 1.13 * float(i), 0.1, 0.27), Vector3(-3.3 + 1.13 * float(i), 3.9, 0.31), pm)
	cy(g.dress, Vector3(0, 0.1, 0.3), 0.12, 7.4, "iron", Vector3(0, 0, 90))
	for sx4: float in [-3.9, 3.9]:
		Props.strut(g.dress, Vector3(sx4, 0.4, 0.4), Vector3(sx4, 3.6, 0.32), 0.12, "machine_grey", true)
		Props.strut(g.dress, Vector3(sx4, 0.4, 0.4), Vector3(sx4, 2.0, 0.36), 0.08, "chrome_worn", true)
		for y: float in [1.2, 2.6]:
			blk(g.dress, Vector3(sx4 - 0.25, y - 0.1, 0.27), Vector3(sx4 + 0.25, y + 0.1, 0.4), "red_paint")
	for i2: int in 9:
		blk(g.dress, Vector3(-3.6 + 0.8 * float(i2), 4.0, 0.2), Vector3(-3.2 + 0.8 * float(i2), 4.25, 0.3), "yellow_paint")
		blk(g.dress, Vector3(-3.2 + 0.8 * float(i2), 4.0, 0.2), Vector3(-2.8 + 0.8 * float(i2), 4.25, 0.3), "black_paint")
	placard(g, Vector3(0, 3.55, 0.32), 180.0, "HECKRAMPE · IM FLUG NICHT ÖFFNEN", 30)
	# the breach: a sheared shackle swinging over the torn door, the cold moon coming up through it (the key light)
	var hook: Node3D = mover(g, "BayHoleShackle", Vector3(-1.1, CEIL_BAY - 0.1, 3.1), &"flight_swing", {"swing_len": 1.6, "swing_phase": 0.4})
	Props.cable(hook, Vector3.ZERO, Vector3(0, -1.5, 0), 0.0, 0.02, 2, "iron")
	blk(hook, Vector3(-0.2, -1.75, -0.12), Vector3(0.2, -1.5, 0.12), "iron")
	Props.obox(hook, Vector3(0.15, -1.85, 0), Vector3(0.05, 0.25, 0.05), "iron", Vector3(0, 0, 30))
	merge_local(hook)
	g.shaft("BayHoleMoon", Vector3(-1.1, -3.0, 3.1), Vector3(-1.3, 4.6, 4.2), Color(0.55, 0.66, 0.95), 7.0, 9.0, 32.0, 1.5, true)
	_wind_streaks(g, Vector3(-1.1, 0.1, 3.1), Vector3(1.4, 0.1, 1.4), Vector3(0, 1, 0))
	# caged lamps: the power lights down the bay's spine, two emergency reds on the frames
	caged_lamp(g, Vector3(0, CEIL_BAY, 8.25), 0.95, "A_BOMBENSCHACHT", Color(1.0, 0.82, 0.6), 1.1, 11.0)
	caged_lamp(g, Vector3(0, CEIL_BAY, 17.25), 0.95, "A_BOMBENSCHACHT", Color(1.0, 0.82, 0.6), 1.1, 11.0)
	wall_lamp(g, Vector3(-8.83, 2.55, 4.5), -90.0, "", Game_RED(), 0.9, 9.0, "lamp_red_lit")
	wall_lamp(g, Vector3(8.83, 2.55, 19.5), 90.0, "", Game_RED(), 0.9, 9.0, "lamp_red_lit")
	wall_lamp(g, Vector3(-8.83, 2.55, 15.0), -90.0, "", Color(1.0, 0.62, 0.28), 0.6, 7.0, "lamp_amber")
	# the cavities: parachute packs, a fire extinguisher, the first-aid box, oxygen
	for z3: float in [7.5, 9.0]:
		blk(g.dress, Vector3(8.95, 0.5, z3 - 0.5), Vector3(9.35, 1.2, z3 + 0.5), "tarp")
		blk(g.dress, Vector3(-9.35, 0.5, z3 - 0.5), Vector3(-8.95, 1.2, z3 + 0.5), "tarp")
	cy(g.dress, Vector3(9.1, 0.55, 16.5), 0.1, 0.6, "red_paint")
	blk(g.dress, Vector3(-9.3, 1.3, 17.6), Vector3(-8.95, 1.7, 18.2), "enamel_white")
	placard(g, Vector3(-8.9, 1.5, 17.9), -90.0, "+", 60, Color(0.8, 0.1, 0.1, 0.9))
	bottles(g, 8.85, 1.0, 14.45, 4, "enamel_green")
	# story props: the load list on the forward bulkhead, a helmet and a glove where a crewman stood
	blk(g.dress, Vector3(4.0, 1.3, 23.8), Vector3(4.35, 1.75, 23.84), "paper")
	placard(g, Vector3(4.17, 1.82, 23.79), 0.0, "LADELISTE", 18)
	PropsStory.helmet(g.dress, Vector3(-4.6, 0.6, 18.9), 30.0, true)
	PropsStory.gasmask_can(g.dress, Vector3(4.5, 0.58, 5.2), 70.0)


static func Game_RED() -> Color:
	return Color(1.0, 0.22, 0.14)


static func _wind_streaks(g: Variant, at: Vector3, extent: Vector3, dir: Vector3) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "WindStreaks"
	p.position = at
	p.amount = 24
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	p.direction = dir
	p.spread = 12.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.01, 0.35, 0.01)
	p.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.18)
	p.material_override = m
	p.set_meta("keep", true)
	g.dress.add_child(p)


# ---------------------------------------------------------------- B Mittelrumpf

static func body(g: Variant) -> void:
	var pm: Material = primer()
	# the galley on its counter (the counter is a collider, x -8.6..-5.6, z 40..46)
	blk(g.dress, Vector3(-8.6, 0.0, 40.0), Vector3(-5.6, 0.9, 46.0), "grey_paint")
	blk(g.dress, Vector3(-8.65, 0.9, 39.95), Vector3(-5.55, 0.96, 46.05), "zinc")
	for i: int in 4:
		blk(g.dress, Vector3(-5.6, 0.08, 40.25 + 1.45 * float(i)), Vector3(-5.57, 0.82, 41.55 + 1.45 * float(i)), "grey_paint")
		ns(cy(g.dress, Vector3(-5.55, 0.7, 41.4 + 1.45 * float(i)), 0.02, 0.12, "chrome_worn", Vector3(0, 0, 90)))
	blk(g.dress, Vector3(-8.5, 0.96, 41.8), Vector3(-7.7, 1.04, 43.2), "iron")                  # the hotplate
	cy(g.dress, Vector3(-8.1, 1.15, 42.5), 0.11, 0.2, "enamel_white")                             # the kettle, still warm
	ns(cy(g.dress, Vector3(-7.95, 1.18, 42.5), 0.025, 0.12, "enamel_white", Vector3(0, 0, 60)))
	PropsStory.mug(g.dress, Vector3(-6.4, 0.96, 41.2))
	PropsStory.mug(g.dress, Vector3(-6.2, 0.96, 41.5))
	PropsStory.loaf(g.dress, Vector3(-6.6, 0.96, 44.6), 20.0)
	PropsStory.mess_tin(g.dress, Vector3(-6.9, 0.96, 43.6), 10.0)
	# wall cupboards over the counter (inside its footprint), a steam wisp off the kettle
	blk(g.dress, Vector3(-8.84, 1.6, 40.2), Vector3(-8.35, 2.3, 45.8), "grey_paint")
	for i2: int in 3:
		blk(g.dress, Vector3(-8.35, 1.65, 40.3 + 1.85 * float(i2)), Vector3(-8.33, 2.25, 41.95 + 1.85 * float(i2)), "grey_paint")
	Props.smoke(g.dress, Vector3(-8.1, 1.3, 42.5), 0.05, 0.6, 6)
	wall_lamp(g, Vector3(-8.83, 2.45, 43.0), -90.0, "", Color(1.0, 0.78, 0.55), 1.0, 7.0)
	# the bunks (colliders x 5.5..8.6, z 26..28.2 and 30..32.2): two tiers, blankets, harnesses buckled over nobody
	for bz: float in [26.0, 30.0]:
		blk(g.dress, Vector3(5.5, 0.55, bz), Vector3(8.6, 0.7, bz + 2.2), pm)
		blk(g.dress, Vector3(5.6, 0.7, bz + 0.1), Vector3(8.5, 0.82, bz + 2.1), "linen")
		blk(g.dress, Vector3(5.6, 0.82, bz + 0.15), Vector3(7.6, 0.86, bz + 2.05), "cloth_navy")
		blk(g.dress, Vector3(5.5, 1.6, bz), Vector3(8.6, 1.72, bz + 2.2), pm)
		blk(g.dress, Vector3(5.6, 1.72, bz + 0.1), Vector3(8.5, 1.84, bz + 2.1), "linen")
		blk(g.dress, Vector3(7.7, 1.84, bz + 0.2), Vector3(8.4, 1.94, bz + 2.0), "cloth_cream")
		for pz: float in [bz + 0.05, bz + 2.15]:
			blk(g.dress, Vector3(5.52, 0.0, pz - 0.04), Vector3(5.6, 2.2, pz + 0.04), pm)
		for tier: float in [0.86, 1.94]:
			var strap: Node3D = mover(g, "Harness%d_%d" % [int(bz), int(tier * 10.0)], Vector3(6.6, tier + 0.02, bz + 1.1), &"flight_swing",
				{"swing_len": 0.5, "swing_phase": bz + tier})
			for dz: float in [-0.35, 0.35]:
				blk(strap, Vector3(-0.03, -0.02, dz - 0.04), Vector3(1.0, 0.0, dz + 0.04), "leather")
				ns(blk(strap, Vector3(-0.06, -0.45, dz - 0.04), Vector3(-0.03, 0.0, dz + 0.04), "leather"))
			ns(blk(strap, Vector3(-0.09, -0.5, -0.06), Vector3(-0.02, -0.4, 0.06), "chrome_worn"))
			merge_local(strap)
	# the radio room: the Bordfunk deck on the desk (x 5.6..8.6, z 46..50), the tape deck's reels turning, a chart table
	blk(g.dress, Vector3(5.6, 0.0, 46.0), Vector3(8.6, 0.75, 50.0), "grey_paint")
	blk(g.dress, Vector3(5.55, 0.75, 45.95), Vector3(8.65, 0.8, 50.05), "felt_green")
	blk(g.dress, Vector3(7.7, 0.8, 46.1), Vector3(8.6, 2.2, 49.9), "machine_grey")
	for i3: int in 3:
		var y: float = 1.05 + 0.42 * float(i3)
		blk(g.dress, Vector3(7.68, y, 46.25), Vector3(7.7, y + 0.34, 49.75), "bakelite")
		for k: int in 4:
			Props.gauge(g.dress, Vector3(7.67, y + 0.18, 46.6 + 0.85 * float(k)), 90.0, 0.07)
	ns(blk(g.dress, Vector3(7.66, 1.05, 47.1), Vector3(7.68, 1.22, 48.9), "lamp_amber"))
	for rz: float in [46.75, 47.45]:
		var reel: Node3D = mover(g, "TapeReel%d" % int(rz * 10.0), Vector3(7.62, 1.93, rz), &"flight_spin", {"spin_rps": 0.35, "spin_axis": Vector3(1, 0, 0)})
		cy(reel, Vector3.ZERO, 0.17, 0.03, "chrome_worn", Vector3(0, 0, 90))
		cy(reel, Vector3(-0.02, 0, 0), 0.12, 0.035, "bakelite", Vector3(0, 0, 90))
		for a: float in [0.0, 120.0, 240.0]:
			ns(Props.obox(reel, Vector3(-0.025, 0, 0), Vector3(0.01, 0.2, 0.03), "black_paint", Vector3(a, 0, 0)))
		merge_local(reel)
	placard(g, Vector3(7.66, 2.05, 48.6), 90.0, "BORDFUNK", 30, Color(0.95, 0.85, 0.5, 0.85))
	blk(g.dress, Vector3(6.0, 0.8, 46.4), Vector3(7.5, 0.805, 47.6), "paper_old")                 # the chart
	ns(Props.obox(g.dress, Vector3(6.7, 0.81, 47.0), Vector3(0.02, 0.005, 0.5), "black_paint", Vector3(0, 35, 0)))
	PropsStory.map_case(g.dress, Vector3(6.4, 0.8, 49.2), 80.0)
	cy(g.dress, Vector3(6.2, 0.83, 48.3), 0.1, 0.06, "bakelite")                                    # headphones
	g.lamp(Vector3(7.3, 1.2, 48.0), Color(1.0, 0.68, 0.32), 0.35, 3.5, 0.06, 0.0)
	# the wing-root carry-through: a cable trough overhead on each side, the oxygen in the cavities
	for sx: float in [-1.0, 1.0]:
		blk(g.dress, Vector3(sx * 8.1, 2.55, 24.4), Vector3(sx * 8.8, 2.6, 53.6), pm)
		for cz: float in [0.0, 0.12, 0.24]:
			Props.pipe(g.dress, Vector3(sx * (8.3 + cz), 2.65, 24.4), Vector3(sx * (8.3 + cz), 2.65, 53.6), 0.025, "rubber")
		bottles(g, sx * 8.85, sx, 50.5, 4, "enamel_green" if sx > 0.0 else "olive_steel")
	bottles(g, -8.85, -1.0, 26.45, 4, "enamel_green")
	# the Crucible's tie-down rings on the deck, the cargo net behind it
	for p: Vector3 in [Vector3(-7.4, 0.0, 33.0), Vector3(-7.4, 0.0, 35.0), Vector3(-4.6, 0.0, 33.0), Vector3(-4.6, 0.0, 35.0)]:
		ns(Props.cyl(g.dress, p + Vector3(0, 0.012, 0), 0.07, 0.024, "iron"))
	# caged lamps down the body
	caged_lamp(g, Vector3(0, CEIL_BODY, 30.75), 0.55, "B_MITTELRUMPF", Color(1.0, 0.8, 0.58), 1.0, 10.0)
	caged_lamp(g, Vector3(0, CEIL_BODY, 41.25), 0.55, "B_MITTELRUMPF", Color(1.0, 0.8, 0.58), 1.0, 10.0)
	caged_lamp(g, Vector3(0, CEIL_BODY, 50.25), 0.55, "B_MITTELRUMPF", Color(1.0, 0.8, 0.58), 1.0, 10.0)
	# the key: the Crucible's violet (casts)
	g.lamp(Vector3(-5.0, 1.6, 34.0), Color(0.62, 0.28, 1.0), 1.0, 7.0, 0.05, 0.6, true)


# ---------------------------------------------------------------- C Flügel

static func wing(g: Variant, sign: float) -> void:
	var zone: String = "C_FLUEGEL_L" if sign < 0.0 else "C_FLUEGEL_R"
	var pm: Material = primer()
	# fuel cells in the cavities behind both spar webs (rubberised bags between the frames)
	var x: float = 9.0 + 4.0 / 3.0
	var k: int = 0
	while x < 51.0:
		var xa: float = sign * (x + 0.08)
		var xb: float = sign * (x + 4.0 / 3.0 - 0.08)
		if k % 2 == 0:
			blk(g.dress, Vector3(minf(xa, xb), 0.15, 27.6), Vector3(maxf(xa, xb), 1.95, 27.95), "rubber")
		if k % 3 != 1:
			blk(g.dress, Vector3(minf(xa, xb), 0.15, 46.05), Vector3(maxf(xa, xb), 1.75, 46.4), "rubber")
		x += 4.0 / 3.0
		k += 1
	# cable runs along the rear spar web, control rods on bellcranks along the front one (they slide)
	var x0: float = sign * 9.3
	var x1: float = sign * 51.7
	for i: int in 3:
		Props.pipe(g.dress, Vector3(x0, 1.95 + 0.06 * float(i), 28.2), Vector3(x1, 1.95 + 0.06 * float(i), 28.2), 0.018, "rubber")
	Props.pipe(g.dress, Vector3(x0, 2.3, 30.8), Vector3(x1, 2.3, 30.8), 0.05, "copper")          # the fuel line
	for rod_i: int in 2:
		var rod: Node3D = mover(g, "ControlRod%s%d" % ["L" if sign < 0.0 else "R", rod_i], Vector3(sign * 30.5, 2.0 + 0.1 * float(rod_i), 45.78), &"flight_rod",
			{"rod_amp": 0.07, "rod_speed": 0.6 + 0.25 * float(rod_i)})
		cy(rod, Vector3.ZERO, 0.014, 41.0, "chrome_worn", Vector3(0, 0, 90))
		merge_local(rod)
	var bx: float = 13.0
	while bx < 50.0:
		blk(g.dress, Vector3(sign * bx - 0.04, 1.92, 45.8), Vector3(sign * bx + 0.04, 2.2, 45.85), "iron")
		bx += 4.0
	# the stubs: station numbers on the corridor faces, an inspection lamp on a hook on every other one (it swings)
	var sx: float = 13.0
	var st: int = 0
	while sx < 50.0:
		var face_x: float = sign * sx - sign * 0.21
		var yaw: float = 90.0 * sign
		placard(g, Vector3(face_x, 1.75, 30.0), yaw, "SPANT %d" % (st * 3 + 3), 22)
		placard(g, Vector3(face_x, 1.75, 44.4), yaw, "NICHT BETRETEN" if st % 2 == 0 else "SPANT %d" % (st * 3 + 3), 18)
		if st % 2 == 0:
			var hl: Node3D = mover(g, "HandLamp%s%d" % ["L" if sign < 0.0 else "R", st], Vector3(face_x - sign * 0.05, 1.95, 31.0 + 0.05), &"flight_swing",
				{"swing_len": 0.35, "swing_phase": float(st) * 0.9})
			Props.cable(hl, Vector3.ZERO, Vector3(0, -0.22, 0), 0.0, 0.008, 2, "rubber")
			cy(hl, Vector3(0, -0.3, 0), 0.05, 0.14, "iron")
			ns(Props.ball(hl, Vector3(0, -0.4, 0), Vector3(0.07, 0.08, 0.07), "bulb_warm"))
			merge_local(hl)
		sx += 4.0
		st += 1
	# the lights: caged bulbs under the main spar (power), the emergency reds on the stubs, one inspection lamp casts
	for lx: float in [14.0, 24.0, 34.0, 44.0]:
		Props.bulkhead_lamp(g.dress, Vector3(sign * lx, SPAR_BOTTOM - 0.02, 37.0), 0.0, "bulb_warm")
		g.power(zone, Vector3(sign * lx, SPAR_BOTTOM - 0.3, 37.0), 11.0, 1.1, Color(1.0, 0.8, 0.58))
	wall_lamp(g, Vector3(sign * 29.0 - sign * 0.21, 1.9, 30.0), 90.0 * sign, "", Game_RED(), 0.9, 9.0, "lamp_red_lit")
	wall_lamp(g, Vector3(sign * 45.0 - sign * 0.21, 1.9, 44.2), 90.0 * sign, "", Game_RED(), 0.9, 9.0, "lamp_red_lit")
	g.lamp(Vector3(sign * 33.0, 1.55, 31.4), Color(1.0, 0.78, 0.5), 0.8, 8.0, 0.12, 0.3, true)
	# placards on the spar webs
	placard(g, Vector3(sign * 24.0, 1.45, 45.82), 0.0, "KRAFTSTOFF · RAUCHEN VERBOTEN", 26)
	placard(g, Vector3(sign * 16.0, 1.45, 28.18), 180.0, "HAUPTHOLM · NICHT BELASTEN", 24)


# ---------------------------------------------------------------- D Triebwerk

static func engine_room(g: Variant) -> void:
	var pm: Material = primer()
	# the core window: the collider is a block x -77.85..-76.6 (z 34..42, y 0.8..3.2); its room face is the lead glass
	var lead: StandardMaterial3D = StandardMaterial3D.new()
	lead.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lead.albedo_color = Color(0.25, 0.18, 0.35, 0.35)
	lead.roughness = 0.05
	lead.metallic_specular = 0.9
	lead.resource_name = "lead_glass"
	var glass: MeshInstance3D = blk(g.dress, Vector3(-76.63, 0.85, 34.05), Vector3(-76.6, 3.15, 41.95), lead, false)
	glass.set_meta("keep", true)
	for z: float in [34.0, 36.0, 38.0, 40.0, 42.0]:
		blk(g.dress, Vector3(-77.85, 0.8, z - 0.09), Vector3(-76.55, 3.2, z + 0.09), "lead")
	blk(g.dress, Vector3(-77.85, 0.62, 33.9), Vector3(-76.5, 0.8, 42.1), "lead")
	blk(g.dress, Vector3(-77.85, 3.2, 33.9), Vector3(-76.5, 3.4, 42.1), "lead")
	for zb: float in [34.4, 35.6, 36.4, 37.6, 38.4, 39.6, 40.4, 41.6]:
		for yb: float in [0.72, 3.3]:
			ns(cy(g.dress, Vector3(-76.48, yb, zb), 0.03, 0.04, "iron", Vector3(0, 0, 90)))
	placard(g, Vector3(-76.48, 3.55, 38.0), -90.0, "BLEIGLAS · KERN · NICHT ÖFFNEN", 26, Color(0.95, 0.8, 0.4, 0.85))
	# beyond it, outside the shell: the impeller chamber and the core, turning, violet
	var chamber: Node3D = Props.group(g.dress, "ImpellerChamber", Vector3(-82.5, 2.0, 38.0))
	chamber.set_meta("keep", true)
	cy(chamber, Vector3.ZERO, 3.4, 9.0, "lead", Vector3(90, 0, 0))
	for zr: float in [-3.5, -1.2, 1.2, 3.5]:
		cy(chamber, Vector3(0, 0, zr), 3.3, 0.18, "iron", Vector3(90, 0, 0))
	merge_local(chamber)
	var core: Node3D = mover(g, "ImpellerCore", Vector3(-82.0, 2.0, 38.0), &"flight_spin", {"spin_rps": 0.55, "spin_axis": Vector3(0, 0, 1)})
	cy(core, Vector3.ZERO, 0.7, 7.0, "nachtglas_crystal", Vector3(90, 0, 0))
	for b: int in 7:
		var a: float = 360.0 / 7.0 * float(b)
		Props.obox(core, Vector3(cos(deg_to_rad(a)) * 1.55, sin(deg_to_rad(a)) * 1.55, 0.0), Vector3(1.7, 0.12, 5.2), "chrome_worn", Vector3(0, 0, a + 18.0))
	ns(Props.ball(core, Vector3.ZERO, Vector3(1.2, 1.2, 1.2), "nachtglas"))
	merge_local(core)
	# the key: the core's violet through the glass (casts), its glow on the floor, heat rising off the window
	g.lamp(Vector3(-75.6, 2.2, 38.0), Color(0.62, 0.28, 1.0), 2.0, 14.0, 0.15, 1.2, true)
	g.lamp(Vector3(-80.5, 2.0, 38.0), Color(0.7, 0.35, 1.0), 2.4, 6.0, 0.2, 0.0)
	_heat(g, Vector3(-75.8, 1.2, 38.0))
	# the engineer's station on its collider (x -75.5..-73.5, z 36.5..39.5): a console, gauges, levers, an intercom
	blk(g.dress, Vector3(-75.5, 0.0, 36.5), Vector3(-73.5, 1.05, 39.5), "machine_grey")
	Props.prism(g.dress, Vector3(-74.5, 1.2, 38.0), Vector3(2.0, 0.3, 3.0), "machine_grey", Vector3(0, 90, 0))
	for k: int in 5:
		Props.gauge(g.dress, Vector3(-73.48, 0.85, 36.9 + 0.55 * float(k)), -90.0, 0.09)
	for k2: int in 4:
		Props.strut(g.dress, Vector3(-74.3, 1.2, 37.2 + 0.5 * float(k2)), Vector3(-74.0, 1.55, 37.2 + 0.5 * float(k2)), 0.025, "chrome_worn", true)
		ns(Props.ball(g.dress, Vector3(-74.0, 1.58, 37.2 + 0.5 * float(k2)), Vector3(0.06, 0.06, 0.06), "red_paint"))
	cy(g.dress, Vector3(-75.3, 1.4, 39.2), 0.06, 0.6, "brass")                                       # the speaking tube
	blk(g.dress, Vector3(-74.9, 1.36, 36.7), Vector3(-74.5, 1.37, 37.2), "paper")                    # the engineer's log
	# the rib frames (colliders x -66 / -62 / -58, z 25.6..27.2): box-section, painted
	for i: int in 3:
		var rx: float = -66.0 + 4.0 * float(i)
		blk(g.dress, Vector3(rx, 0.0, 25.6), Vector3(rx + 0.4, 4.4, 27.2), pm)
		placard(g, Vector3(rx + 0.41, 2.2, 26.4), -90.0, "SPANT %d" % (40 + 4 * i), 22)
	# pipes: coolant from the chamber through the outboard wall, along the ceiling to the station and aft
	for py: float in [2.5, 2.75]:
		Props.pipe(g.dress, Vector3(-77.72, py, 24.6), Vector3(-77.72, py, 33.6), 0.09, "copper")
		Props.pipe(g.dress, Vector3(-77.72, py, 42.4), Vector3(-77.72, py, 57.4), 0.09, "copper")
	Props.pipe(g.dress, Vector3(-76.5, 3.6, 38.6), Vector3(-74.5, 3.6, 38.6), 0.07, "copper")
	Props.pipe(g.dress, Vector3(-74.5, 3.6, 38.6), Vector3(-74.5, 1.4, 38.6), 0.06, "copper")
	for vz: float in [28.0, 44.0, 52.0]:
		Props.valve_wheel(g.dress, Vector3(-77.62, 2.25, vz), -90.0, 0.2, "red_paint")
	for sx: float in [-70.0, -60.0]:
		Props.pipe(g.dress, Vector3(sx, 4.6, 24.6), Vector3(sx, 4.6, 57.4), 0.12, "iron")
	# lights: caged lamps from the arch (power; the Bordwart's overspeed kills them)
	caged_lamp(g, Vector3(-65.0, CEIL_ROOM, 32.0), 1.0, "D_TRIEBWERK", Color(1.0, 0.82, 0.6), 1.2, 12.0)
	caged_lamp(g, Vector3(-65.0, CEIL_ROOM, 50.0), 1.0, "D_TRIEBWERK", Color(1.0, 0.82, 0.6), 1.2, 12.0)
	wall_lamp(g, Vector3(-77.83, 2.8, 47.0), -90.0, "", Game_RED(), 0.8, 8.0, "lamp_red_lit")
	# cavities: tool lockers and spares
	for cz: float in [28.25, 44.75, 46.25]:
		blk(g.dress, Vector3(-78.4, 0.0, cz - 0.6), Vector3(-77.9, 1.9, cz + 0.6), "machine_grey")


static func _heat(g: Variant, at: Vector3) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "HeatShimmer"
	p.position = at
	p.amount = 20
	p.lifetime = 2.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, 0.6, 3.6)
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 15.0
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.7
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.5, 0.9)
	p.mesh = qm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.7, 0.45, 1.0, 0.05)
	p.material_override = m
	p.set_meta("keep", true)
	g.dress.add_child(p)


# ---------------------------------------------------------------- E Kanzel

static func kanzel(g: Variant) -> void:
	var pm: Material = primer()
	for bx: float in [56.0, 62.0, 68.0, 74.0]:
		# the mount on its collider (x bx±0.4, z 24.3..25.6, y 0..1.2): a pedestal, a ring, twin guns through the blister
		cy(g.dress, Vector3(bx, 0.55, 25.0), 0.3, 1.1, pm)
		cy(g.dress, Vector3(bx, 1.12, 24.95), 0.38, 0.08, "iron")
		blk(g.dress, Vector3(bx - 0.25, 1.15, 24.6), Vector3(bx + 0.25, 1.4, 25.4), "machine_grey")
		for gx: float in [-0.1, 0.1]:
			cy(g.dress, Vector3(bx + gx, 1.45, 24.2), 0.035, 1.6, "black_paint", Vector3(90, 0, 0))
			ns(cy(g.dress, Vector3(bx + gx, 1.45, 23.35), 0.05, 0.12, "black_paint", Vector3(90, 0, 0)))
		blk(g.dress, Vector3(bx - 0.18, 1.3, 25.1), Vector3(bx + 0.18, 1.6, 25.55), "black_paint")   # the receiver
		blk(g.dress, Vector3(bx + 0.25, 0.6, 24.5), Vector3(bx + 0.4, 0.9, 25.0), "olive_drab")    # the ammo can
		for j: int in 6:
			ns(Props.obox(g.dress, Vector3(bx + 0.3, 0.95 + 0.06 * float(j), 24.85 - 0.04 * float(j)), Vector3(0.12, 0.02, 0.05), "brass", Vector3(30, 0, 0)))
		blk(g.dress, Vector3(bx - 0.22, 0.9, 25.25), Vector3(bx + 0.22, 0.98, 25.6), "leather")     # the gunner's saddle
		# spent casings on the grating round the mount
		for c: int in 5:
			ns(cy(g.dress, Vector3(bx - 0.5 + 0.23 * float(c), 0.02, 25.9 + 0.11 * float(c % 2)), 0.008, 0.06, "brass", Vector3(0, 0, 90)))
		# the moonlight through the dome (no shadow)
		g.shaft("BlisterMoon", Vector3(bx, 3.6, 21.0), Vector3(bx, 0.0, 27.5), Color(0.55, 0.66, 0.95), 3.0, 9.0, 24.0, 1.0, false)
	placard(g, Vector3(74.0, 3.2, 24.2), 180.0, "HECKKANZEL", 26)
	# caged lamps (power), the reds
	caged_lamp(g, Vector3(65.0, CEIL_ROOM, 32.0), 1.0, "E_KANZEL", Color(1.0, 0.82, 0.6), 1.1, 12.0)
	caged_lamp(g, Vector3(65.0, CEIL_ROOM, 50.0), 1.0, "E_KANZEL", Color(1.0, 0.82, 0.6), 1.1, 12.0)
	wall_lamp(g, Vector3(77.83, 2.8, 40.0), 90.0, "", Game_RED(), 0.8, 8.0, "lamp_red_lit")
	# ammunition boxes and belts in the cavities, a parachute bin
	for cz: float in [29.75, 31.25, 37.25, 38.75]:
		blk(g.dress, Vector3(77.95, 0.0, cz - 0.5), Vector3(78.4, 0.5, cz + 0.5), "olive_drab")
		blk(g.dress, Vector3(77.95, 0.5, cz - 0.45), Vector3(78.35, 0.95, cz + 0.45), "olive_drab")
	blk(g.dress, Vector3(77.95, 0.4, 51.7), Vector3(78.4, 1.4, 52.8), "tarp")
	for pz: float in [34.0, 46.0]:
		for py: float in [2.5 + 0.25 * (pz - 34.0) / 12.0]:
			Props.pipe(g.dress, Vector3(77.72, py, 24.6), Vector3(77.72, py, 57.4), 0.05, "rubber")


# ---------------------------------------------------------------- the walkways to the flight deck

static func walkway(g: Variant, sign: float) -> void:
	var zone: String = "D_TRIEBWERK" if sign < 0.0 else "E_KANZEL"
	caged_lamp(g, Vector3(sign * 37.0, 2.43, 54.0), 0.2, zone, Color(1.0, 0.8, 0.58), 0.9, 10.0)
	wall_lamp(g, Vector3(sign * 44.0, 1.85, 57.83), 0.0, "", Game_RED(), 0.8, 8.0, "lamp_red_lit")
	for i: int in 3:
		Props.pipe(g.dress, Vector3(sign * 51.5, 1.9 + 0.07 * float(i), 57.8), Vector3(sign * 22.6, 1.9 + 0.07 * float(i), 57.8), 0.02, "rubber")
	placard(g, Vector3(sign * 24.0, 1.8, 50.18), 180.0, "ZUM FLUGDECK  ▸" if sign < 0.0 else "◂  ZUM FLUGDECK", 26)


# ---------------------------------------------------------------- F Cockpit

static func cockpit(g: Variant) -> void:
	var pm: Material = primer()
	# the two seats on their colliders (x ±1.8 ± 0.5, z 69.5..70.7): pan, tall back, headrest, harness over nobody
	for sx: float in [-1.8, 1.8]:
		blk(g.dress, Vector3(sx - 0.35, 0.0, 69.8), Vector3(sx + 0.35, 0.45, 70.4), pm)
		blk(g.dress, Vector3(sx - 0.42, 0.45, 69.55), Vector3(sx + 0.42, 0.6, 70.5), "leather")
		blk(g.dress, Vector3(sx - 0.42, 0.6, 70.4), Vector3(sx + 0.42, 1.6, 70.65), "leather")
		blk(g.dress, Vector3(sx - 0.2, 1.6, 70.45), Vector3(sx + 0.2, 1.85, 70.62), "leather")
		for ax: float in [-0.48, 0.42]:
			blk(g.dress, Vector3(sx + ax, 0.6, 69.6), Vector3(sx + ax + 0.06, 0.82, 70.45), pm)
		var strap: Node3D = mover(g, "SeatHarness%d" % int(sx * 10.0), Vector3(sx, 1.55, 70.36), &"flight_swing", {"swing_len": 0.6, "swing_phase": sx})
		for dx: float in [-0.18, 0.18]:
			ns(blk(strap, Vector3(dx - 0.035, -0.95, -0.03), Vector3(dx + 0.035, 0.0, 0.0), "leather"))
		ns(blk(strap, Vector3(-0.08, -1.0, -0.05), Vector3(0.08, -0.88, 0.0), "chrome_worn"))
		merge_local(strap)
		# the control column and the rudder pedals in front of the seat
		cy(g.dress, Vector3(sx, 0.45, 71.3), 0.04, 0.9, "black_paint")
		blk(g.dress, Vector3(sx - 0.2, 0.88, 71.27), Vector3(sx + 0.2, 0.93, 71.33), "black_paint")
		for px: float in [-0.2, 0.2]:
			blk(g.dress, Vector3(sx + px - 0.07, 0.0, 72.4), Vector3(sx + px + 0.07, 0.12, 72.7), "iron")
	# the instrument panel against the glass sill (thin, so a player at the glass never stands in it), lit dials
	blk(g.dress, Vector3(-4.2, 0.0, 73.45), Vector3(4.2, 1.15, 73.85), "black_paint")
	blk(g.dress, Vector3(-4.3, 1.15, 73.2), Vector3(4.3, 1.25, 73.85), "leather")                  # the glare shield
	var dial: StandardMaterial3D = StandardMaterial3D.new()
	dial.albedo_color = Color(0.85, 0.95, 0.8)
	dial.emission_enabled = true
	dial.emission = Color(0.45, 0.95, 0.6)
	dial.emission_energy_multiplier = 1.6
	dial.resource_name = "dial_lit"
	for row: int in 3:
		for col: int in 12:
			var dx2: float = -3.6 + 0.65 * float(col)
			var dy: float = 0.35 + 0.27 * float(row)
			ns(cy(g.dress, Vector3(dx2, dy, 73.44), 0.1, 0.015, dial, Vector3(90, 0, 0)))
			ns(cy(g.dress, Vector3(dx2, dy, 73.435), 0.115, 0.01, "brass", Vector3(90, 0, 0)))
	# the throttle quadrant between the seats (on the cradle's collider row) and the autopilot cradle
	blk(g.dress, Vector3(-0.6, 0.0, 65.4), Vector3(0.6, 0.85, 66.6), "machine_grey")
	blk(g.dress, Vector3(-0.62, 0.85, 65.38), Vector3(0.62, 0.95, 66.62), pm)
	var strap_m: StandardMaterial3D = StandardMaterial3D.new()
	strap_m.albedo_color = Color(0.45, 0.15, 0.75)
	strap_m.emission_enabled = true
	strap_m.emission = Color(0.55, 0.2, 1.0)
	strap_m.emission_energy_multiplier = 1.2
	strap_m.resource_name = "violet_strap"
	blk(g.dress, Vector3(-0.64, 0.0, 65.92), Vector3(0.64, 0.97, 66.08), strap_m)
	_cog(g, Vector3(0, 0.96, 66.0))
	placard(g, Vector3(0, 0.6, 65.37), 0.0, "SELBSTSTEUERUNG", 22, Color(0.95, 0.85, 0.5, 0.85))
	# the key: the strap's violet (casts), the instrument glow, a lamp from the arch
	g.lamp(Vector3(0, 1.4, 65.2), Color(0.62, 0.28, 1.0), 0.8, 6.0, 0.08, 0.4, true)
	caged_lamp(g, Vector3(0, CEIL_COCKPIT, 60.25), 1.1, "F_COCKPIT", Color(1.0, 0.82, 0.6), 1.0, 12.0)
	# the flight engineer's panel on the port bulkhead (in the flat range by the door: flush) and charts
	for i: int in 6:
		Props.gauge(g.dress, Vector3(-21.8, 1.4 + 0.3 * float(i % 2), 59.3 + 0.4 * float(i)), -90.0, 0.08)
	placard(g, Vector3(0, 4.0, 54.18), 180.0, "FLUGDECK", 40)


## The Werk's fictional mark on the autopilot's lid: a crane in a cog (docs/MAP4_FERNFLUG.md rule 2).
static func _cog(g: Variant, c: Vector3) -> void:
	var grp: Node3D = Props.group(g.dress, "WerkMark", c)
	ns(cy(grp, Vector3(0, 0.005, 0), 0.24, 0.01, "brass"))
	ns(cy(grp, Vector3(0, 0.012, 0), 0.17, 0.008, "black_paint"))
	for t: int in 12:
		var a: float = TAU * float(t) / 12.0
		ns(Props.obox(grp, Vector3(cos(a) * 0.27, 0.005, sin(a) * 0.27), Vector3(0.06, 0.01, 0.05), "brass", Vector3(0, -rad_to_deg(a), 0)))
	# the crane: a neck and a head in brass on the black disc
	ns(Props.obox(grp, Vector3(0.0, 0.018, 0.02), Vector3(0.03, 0.006, 0.22), "brass", Vector3(0, 20, 0)))
	ns(Props.obox(grp, Vector3(-0.05, 0.018, -0.1), Vector3(0.09, 0.006, 0.03), "brass", Vector3(0, -10, 0)))
	ns(Props.obox(grp, Vector3(0.06, 0.018, 0.08), Vector3(0.12, 0.006, 0.05), "brass", Vector3(0, 35, 0)))


# ---------------------------------------------------------------- London from altitude (the window's plate)

## The LondonPlate (london_window.gd finds it by name, lights it and bursts over it): the city's blocks with a few
## lit windows, the river, barrage balloons on their cables over it. Kept (never batched), at the generator's place.
static func london_plate(g: Variant) -> void:
	var ld: Node3D = Props.group(g.dress, "LondonPlate", Vector3(74, -40, -120))
	ld.set_meta("keep", true)
	Props.block(ld, Vector3(-60, -0.5, -60), Vector3(60, 0, 60), "black_paint")
	var lit: StandardMaterial3D = StandardMaterial3D.new()
	lit.albedo_color = Color(0.2, 0.15, 0.1)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.7, 0.4)
	lit.emission_energy_multiplier = 0.8
	lit.resource_name = "london_window_lit"
	var river: StandardMaterial3D = StandardMaterial3D.new()
	river.albedo_color = Color(0.03, 0.04, 0.06)
	river.roughness = 0.05
	river.metallic = 0.5
	river.resource_name = "london_river"
	for i: int in 40:
		var hx: float = -55.0 + 2.8 * float(i)
		var dz: float = -40.0 + float((i * 13) % 70)
		var h: float = 1.0 + float((i * 7) % 5) * 0.8
		if absf(dz - 10.0 * sin(hx * 0.05)) < 7.0:
			continue
		Props.block(ld, Vector3(hx, 0, dz), Vector3(hx + 2.0, h, dz + 3.0), "grey_paint")
		if i % 3 == 0:
			blk(ld, Vector3(hx + 0.4, h * 0.4, dz - 0.01), Vector3(hx + 0.8, h * 0.4 + 0.3, dz), lit)
	for k: int in 12:
		var x0: float = -60.0 + 10.0 * float(k)
		blk(ld, Vector3(x0, 0.01, 10.0 * sin(x0 * 0.05) - 4.0), Vector3(x0 + 10.5, 0.03, 10.0 * sin(x0 * 0.05) + 4.0), river)
	for b: int in 5:
		var bp: Vector3 = Vector3(-40.0 + 20.0 * float(b), 18.0 + float(b % 2) * 6.0, -20.0 + float((b * 17) % 40))
		Props.ball(ld, bp, Vector3(3.2, 1.4, 1.4), "grey_paint")
		Props.cable(ld, bp, Vector3(bp.x, 0.0, bp.z), 0.0, 0.03, 2, "iron")


# ---------------------------------------------------------------- signs

static func signage(g: Variant) -> void:
	g.label("BOMBENSCHACHT", Vector3(0, 3.4, 23.84), 180.0, 40)
	g.label("MITTELRUMPF", Vector3(0, 3.0, 24.16), 0.0, 40)
	g.label("TRIEBWERK · BACKBORD", Vector3(-52.16, 2.6, 36), 90.0, 36)
	g.label("KANZEL", Vector3(52.16, 2.6, 36), -90.0, 36)
	placard(g, Vector3(-8.84, 1.95, 36.0), -90.0, "FLÜGEL · BACKBORD", 24)
	placard(g, Vector3(8.84, 1.95, 36.0), 90.0, "FLÜGEL · STEUERBORD", 24)
