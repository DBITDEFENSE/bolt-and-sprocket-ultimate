class_name MenuModelView
extends SubViewportContainer
## T-267 (the owner: "when you're customizing your starting pistol, you need to be able to see the pistol"): a small
## 3D stage inside a menu page. It shows the real in-game model (the sidearm exactly as WeaponHolder builds it:
## WeaponModels.build with the profile's camo, the M1911's finish and its fitted attachment; a survivor as PersonRig
## builds them), lit by its own three lights, slowly turning from side to side (a weapon swings 40 degrees either
## way about its side view, so it is never seen end-on as a sliver; a survivor 34 degrees about facing you), and
## swaps with a short fade-and-swell when the choice changes.
## Cost: a SubViewport with its OWN World3D (nothing of the menu's inn is drawn twice, nothing of this leaks into
## it), no sky, no shadows, no glow, no SDFGI / SSAO / volumetrics, so it is the same picture on Forward+ and on the
## Compatibility renderer (the browser, WSL's software GL). The viewport draws only while the container is visible
## (SubViewportContainer switches it off when hidden) and is freed with the page: a closed screen costs nothing.
## The model is framed by the upright cylinder its box turns in (`fit_distance`), so no option can be clipped or tiny
## whatever angle the turn reaches.

const VIEW_SIZE: Vector2i = Vector2i(640, 400)
const FOV: float = 30.0
const SPIN_RAD: float = 0.7             # weapons swing +-40 degrees about the side view
const SPIN_RAD_S: float = 0.55          # there and back in ~11 s
const SWAY_RAD: float = 0.6             # survivors swing +-34 degrees instead of showing their backs
const SWAY_RAD_S: float = 0.5
const SWAP_OUT_S: float = 0.09
const SWAP_IN_S: float = 0.16
const START_YAW: float = PI * 0.5 - 0.12   # the side view, the model's -Z (the muzzle) to the left and a little away
const FRONT_YAW: float = PI             # a survivor faces -Z: turned to the camera
const FILL: float = 0.9                 # how much of the frame the model's cylinder takes

var viewport: SubViewport = null
var camera: Camera3D = null
var pivot: Node3D = null               # turns; the model hangs under it, centred
var model: Node3D = null
var model_key: String = ""
var mode: String = "spin"              # "spin" (weapons) / "sway" (survivors)
var radius: float = 0.2                # the framed model's bounding sphere (m)
var box: AABB = AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))   # the framed model's box, centred
var swaps: int = 0                     # how many times the model changed (tests)
var _t: float = 0.0
var _rig: PersonRig = null
var _swap: Tween = null
var _lights: Array[Light3D] = []


func _init(view_size: Vector2i = VIEW_SIZE) -> void:
	name = "ModelView"
	stretch = true
	custom_minimum_size = Vector2(view_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	viewport = SubViewport.new()
	viewport.name = "Stage"
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.transparent_bg = true
	viewport.size = view_size
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.gui_disable_input = true
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.68, 0.74)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	# key (warm, from the upper right, toward the viewer's left), fill (cool, low, from the left), rim (from behind)
	for row: Array in [[Vector3(-38, 34, 0), Color(1.0, 0.93, 0.8), 2.2], [Vector3(-12, -58, 0), Color(0.62, 0.7, 0.95), 1.0],
			[Vector3(-22, 168, 0), Color(0.8, 0.66, 1.0), 1.3]]:
		var l: DirectionalLight3D = DirectionalLight3D.new()
		l.rotation_degrees = row[0]
		l.light_color = row[1]
		l.light_energy = row[2]
		l.shadow_enabled = false
		viewport.add_child(l)
		_lights.append(l)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.02
	camera.far = 30.0
	camera.current = true
	viewport.add_child(camera)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	viewport.add_child(pivot)
	_frame()


## The sphere that holds a box: its centre and half its diagonal (pure).
static func sphere_of(box: AABB) -> Dictionary:
	return {"center": box.get_center(), "radius": box.size.length() * 0.5}


## Every drawn mesh under `root`, in root's space.
static func bounds_of(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		var shown: bool = true
		while p != null and p != root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
				shown = shown and (p as Node3D).visible
			p = p.get_parent()
		if not shown:
			continue
		var b: AABB = xf * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## How far the camera stands back from a box turning about its upright axis: the cylinder it sweeps (radius = half
## the box's diagonal on the ground plane, its height) fills FILL of the view, its near side included (pure).
static func fit_distance(size: Vector3, fov_deg: float, aspect: float) -> float:
	var half_v: float = deg_to_rad(fov_deg) * 0.5
	var half_h: float = atan(tan(half_v) * aspect)
	var r: float = maxf(0.01, Vector2(size.x, size.z).length() * 0.5)
	var h: float = maxf(0.01, size.y * 0.5)
	return maxf(r / tan(half_h), h / tan(half_v)) / FILL + r


func _frame() -> void:
	var asp: float = float(viewport.size.x) / float(maxi(1, viewport.size.y))
	var d: float = fit_distance(box.size, FOV, asp)
	camera.position = Vector3(0.0, 0.0, d)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	camera.near = maxf(0.01, d - radius * 2.0)
	camera.far = d + radius * 4.0


## The sidearm `weapon_id` as the match will hand it over: `finish` and `pick` ("slot:option") apply to the M1911
## only (M1911Kit.apply_start, the same call WeaponHolder makes), the camo is the profile's.
func show_weapon(weapon_id: String, finish: StringName = &"", pick: String = "") -> bool:
	var key: String = "w|%s|%s|%s" % [weapon_id, finish, pick]
	if key == model_key:
		return true
	var w: WeaponInstance = WeaponInstance.create(StringName(weapon_id))
	if w == null:
		return false
	M1911Kit.apply_start(w, pick, finish)
	w.refresh_kit()
	var camo: StringName = ProfileSave.camo_for(w.base_id())
	var m: Node3D = WeaponModels.build(w.base_id(), false, camo, WeaponKitModels.look_of(w))
	if m == null:
		return false
	for n: Node in m.find_children("*", "Light3D", true, false):   # a kit's flashlight would light the stage
		(n as Light3D).visible = false
	var kf: Node3D = m.get_node_or_null("KitFlash") as Node3D
	if kf != null:
		kf.hide()
	_rig = null
	mode = "spin"
	_swap_to(m, key)
	return true


## A survivor (dutch / peg / deacon / wren), standing, breathing, turning a little to each side.
func show_character(id: String) -> bool:
	var key: String = "c|" + id
	if key == model_key:
		return true
	var holder: Node3D = Node3D.new()
	holder.name = "Survivor_" + id
	var rig: PersonRig = PersonRig.new()
	holder.add_child(rig)
	if not rig.setup(id):
		holder.free()
		return false
	_rig = rig
	mode = "sway"
	_swap_to(holder, key)
	_pose(0.0)
	return true


func _swap_to(m: Node3D, key: String) -> void:
	var old: Node3D = model
	model = m
	model_key = key
	swaps += 1
	if _swap != null and _swap.is_valid():
		_swap.kill()
	for ch: Node in pivot.get_children():   # an earlier swap cut short
		if ch != old:
			ch.queue_free()
	pivot.add_child(m)
	if _rig != null:
		_pose(0.0)
	var mbox: AABB = bounds_of(m)
	if _rig != null:   # a skinned body: a standing person's box, feet on the origin
		mbox = AABB(Vector3(-0.36, 0.0, -0.22), Vector3(0.72, 1.86, 0.44))
	var s: Dictionary = sphere_of(mbox)
	m.position = -(s["center"] as Vector3)
	var reduced: bool = MenuMotion.reduced()
	if old == null or not is_inside_tree() or reduced:
		if old != null:
			old.queue_free()
		radius = maxf(0.05, float(s["radius"]))
		box = AABB(-mbox.size * 0.5, mbox.size)
		_frame()
		pivot.scale = Vector3.ONE
		modulate.a = 1.0
		return
	m.visible = false
	_swap = create_tween()
	_swap.tween_property(self, "modulate:a", 0.0, SWAP_OUT_S)
	_swap.tween_callback(func() -> void:
		if is_instance_valid(old):
			old.queue_free()
		if is_instance_valid(m):
			m.visible = true
		radius = maxf(0.05, float(s["radius"]))
		box = AABB(-mbox.size * 0.5, mbox.size)
		_frame()
		_t = 0.0
		pivot.scale = Vector3.ONE * 0.9)
	_swap.tween_property(self, "modulate:a", 1.0, SWAP_IN_S)
	_swap.parallel().tween_property(pivot, "scale", Vector3.ONE, SWAP_IN_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The turn at `t` seconds: a weapon swings either side of its side view, a survivor either side of facing you; a
## still view with reduced motion (pure).
static func yaw_at(t: float, view_mode: String, is_reduced: bool) -> float:
	if view_mode == "sway":
		return FRONT_YAW if is_reduced else FRONT_YAW + sin(t * SWAY_RAD_S) * SWAY_RAD
	return START_YAW if is_reduced else START_YAW + sin(t * SPIN_RAD_S) * SPIN_RAD


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	pivot.rotation.y = yaw_at(_t, mode, MenuMotion.reduced())
	if _rig != null and is_instance_valid(_rig):
		_pose(_t)


func _pose(t: float) -> void:
	if _rig == null or not is_instance_valid(_rig):
		return
	var breathe: float = sin(t * 1.7) * 0.006
	var hips: Vector3 = Vector3(0.0, 0.95 + breathe, 0.0)
	var chest: Basis = Basis.from_euler(Vector3(0.03, sin(t * 0.21) * 0.05, 0.0))
	var head: Basis = Basis.from_euler(Vector3(-0.04, sin(t * 0.33) * 0.18, 0.0))
	_rig.drive({"hips": hips, "chest": chest, "head": head, "legs": [[0.04, -0.06], [-0.05, -0.1]],
		"hands": [null, null], "poles": [Vector3(-0.6, -1.0, 0.3), Vector3(0.7, -0.6, 0.2)], "plant": true})


## Sets the turn to `t` seconds (the capture tool's fixed angles).
func set_time(t: float) -> void:
	_t = t
	pivot.rotation.y = yaw_at(_t, mode, MenuMotion.reduced())
