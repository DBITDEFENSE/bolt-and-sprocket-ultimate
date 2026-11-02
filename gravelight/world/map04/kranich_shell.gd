class_name KranichShell
extends Node3D
## Der Kranich's inner shell at load time (UPDATE 09 section 5.3, DECISIONS T-147). The generator (gen_map04b.gd)
## places one of these with a row per room; it instances the room's GLB (tools_src/blender/world/kranich_shell.py ->
## assets/ours/world/kranich_<room>/model.glb, in the act's own frame, so every room sits at the origin), maps the
## shell's material slots and sets each room's visibility range, so the .tscn holds only this node and its table,
## never copies of the meshes. Visual only: the generator's colliders and navmesh are untouched.
##
## Slots: kskin = the riveted skin (kranich_skin.gdshader on the CC0 plate, the rivet rows on the room's frame lines),
## kframe = frames / stringers / coamings (the same primer, no rivets, a little darker), kgrate = catwalk grating
## (grating.gdshader, alpha-scissored), kglass = perspex (its own mesh, no shadows), kdark = the sub-floor; lib_* and
## mats_* slots are WorldArt's. The skin casts double-sided shadows so the moon only comes in where the shell is open.

## [[folder: String, zone: String, frame_offset: float, frame_pitch: float, visibility_end_m: float], ...]
@export var rooms: Array = []
@export var build_on_ready: bool = true

const SKIN_SHADER: String = "res://gravelight/world/map04/kranich_skin.gdshader"
const GRATE_SHADER: String = "res://gravelight/world/map04/grating.gdshader"

var built: bool = false
static var _mats: Dictionary = {}


func _ready() -> void:
	if build_on_ready:
		build()


func build() -> void:
	if built:
		return
	built = true
	for r: Array in rooms:
		var folder: String = str(r[0])
		var inst: Node3D = WorldArt.instance(folder, folder)
		if inst == null:
			push_warning("KranichShell: %s has no imported GLB" % folder)
			continue
		add_child(inst)
		var skin: Material = skin_material(float(r[2]), float(r[3]))
		var vis: float = float(r[4]) if r.size() > 4 else 0.0
		for mi: MeshInstance3D in WorldArt.meshes(inst):
			_remap(mi, skin)
			mi.set_meta("zone", StringName(str(r[1])))
			# only the skin casts (double-sided: it is the envelope the moon must not cross); the frames and floors sit
			# inside it and would only multiply the shadow passes (contract C4's triangle budget)
			if mi.name.begins_with("Skin") and not mi.name.contains("Glass"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			else:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if vis > 0.0:
				mi.visibility_range_end = vis
				mi.visibility_range_end_margin = 6.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _remap(mi: MeshInstance3D, skin: Material) -> void:
	if mi.mesh == null:
		return
	for s: int in mi.mesh.get_surface_count():
		var cur: Material = mi.mesh.surface_get_material(s)
		var slot: String = cur.resource_name if cur != null else ""
		var m: Material = null
		match slot:
			"kskin":
				m = skin
			"kframe":
				m = frame_material()
			"kgrate":
				m = grate_material()
			"kglass":
				m = glass_material()
			"kdark":
				m = dark_material()
		if m != null:
			mi.set_surface_override_material(s, m)


## The riveted skin for a room whose frames stand at frame_offset + k * frame_pitch (metres along the frame axis).
static func skin_material(frame_offset: float = 0.75, frame_pitch: float = 1.5) -> Material:
	var key: String = "skin_%.3f_%.3f" % [frame_offset, frame_pitch]
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = _skin_base()
	if m == null:
		return Mats.get_mat("grey_paint")
	m.set_shader_parameter("frame_offset", frame_offset)
	m.set_shader_parameter("frame_pitch", frame_pitch)
	m.resource_name = "kranich_" + key
	_mats[key] = m
	return m


## Frames, stringers and coamings: the primer a shade darker, no rivet rows.
static func frame_material() -> Material:
	if _mats.has("frame"):
		return _mats["frame"]
	var m: ShaderMaterial = _skin_base()
	if m == null:
		return Mats.get_mat("grey_paint")
	m.set_shader_parameter("rivets", false)
	m.set_shader_parameter("primer", Color(0.33, 0.35, 0.31))
	m.set_shader_parameter("tile_m", 1.6)
	m.set_shader_parameter("metal", 0.08)
	m.resource_name = "kranich_frame"
	_mats["frame"] = m
	return m


static func _skin_base() -> ShaderMaterial:
	var sh: Shader = load(SKIN_SHADER) as Shader
	var alb: Texture2D = MaterialLibrary.texture("kranich_skin", "albedo")
	if sh == null or alb == null:
		return null
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo_tex", alb)
	m.set_shader_parameter("normal_tex", MaterialLibrary.texture("kranich_skin", "normal"))
	m.set_shader_parameter("orm_tex", MaterialLibrary.texture("kranich_skin", "orm"))
	return m


static func grate_material() -> Material:
	if _mats.has("grate"):
		return _mats["grate"]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(GRATE_SHADER) as Shader
	m.resource_name = "kranich_grate"
	_mats["grate"] = m
	return m


## Perspex: clear, a little blue, scuffed (transparent; never casts).
static func glass_material() -> Material:
	if _mats.has("glass"):
		return _mats["glass"]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.62, 0.7, 0.78, 0.13)
	m.roughness = 0.08
	m.metallic_specular = 0.8
	m.resource_name = "kranich_perspex"
	_mats["glass"] = m
	return m


static func dark_material() -> Material:
	if _mats.has("dark"):
		return _mats["dark"]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.035, 0.036, 0.034)
	m.roughness = 0.9
	m.resource_name = "kranich_dark"
	_mats["dark"] = m
	return m


## Drops the material cache (tests).
static func reset() -> void:
	_mats = {}
