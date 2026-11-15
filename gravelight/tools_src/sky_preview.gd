extends Node3D
## UPDATE 19 (T-252): the night-sky dome on its own, for tuning it without loading a map (a map takes minutes under
## llvmpipe, this takes seconds). A camera, the dome (sky_dome.gdshader) and an Environment carrying a map's grade
## (data/look/<map_id>.json through LookGrade.apply), three frames: the horizon, 32 degrees up, the moon.
##   tools/wsl_godot.sh --path . res://gravelight/tools_src/sky_preview.tscn -- --map=map00_crossroads --out=/abs/dir
##     [--shader=res://...]  another version of the dome shader; [--block]   also write the grade's `sky_dome` block to the dome (Totenhafen) instead of the Landscape colours
## Rendered tool: WSL + Xvfb only on the owner's PC (CLAUDE.md).

const SHADER: String = "res://gravelight/world/landscape/shaders/sky_dome.gdshader"


func _ready() -> void:
	var map_id: String = "map00_crossroads"
	var out: String = ""
	var block: bool = false
	var shader_path: String = SHADER
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_id = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--block":
			block = true
		elif a.begins_with("--shader="):   # another version of the dome shader (a before / after pair)
			shader_path = a.substr(9)
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.03)   # Map 0's (gen_map00 build_environment)
	env.fog_light_color = Color(0.07, 0.09, 0.15)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.adjustment_enabled = true
	we.environment = env
	add_child(we)
	LookGrade.apply(env, map_id)
	LookGrade.set_brightness(env, 0.9)   # the horror layer's darker night (T-192) as a map has it
	var moon: Vector3 = Vector3(0.36, 0.64, 0.68).normalized()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(shader_path) as Shader
	mat.set_shader_parameter("moon_dir", moon)
	var bg: Color = env.background_color
	var fog: Color = env.fog_light_color * env.fog_light_energy * Landscape.HAZE_GAIN
	var hz: Color = bg.lerp(fog, 0.8) * 0.95
	mat.set_shader_parameter("zenith", Vector3(bg.r, bg.g, bg.b) * 0.4)
	mat.set_shader_parameter("horizon", Vector3(hz.r, hz.g, hz.b))
	mat.set_shader_parameter("cloud_tint", Vector3(hz.r, hz.g, hz.b) * 0.8)
	var z8: PackedVector4Array = PackedVector4Array()
	z8.resize(8)
	mat.set_shader_parameter("flashes", z8)
	mat.set_shader_parameter("flash_cols", z8)
	var z4: PackedVector4Array = PackedVector4Array()
	z4.resize(4)
	mat.set_shader_parameter("beams", z4)
	if block:
		var d: Dictionary = LookGrade.resolved(map_id).get("sky_dome", {})
		mat.set_shader_parameter("town_strength", 0.0)
		for k: Variant in d.keys():
			if not str(k).begins_with("_") and str(k) != "moon_light":
				mat.set_shader_parameter(str(k), NightSkyDome.value_of(d[k]))
	var dome: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	dome.mesh = sm
	dome.material_override = mat
	dome.scale = Vector3(380, 380, 380)
	dome.extra_cull_margin = 16384.0
	add_child(dome)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 64.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	if out == "":
		out = ProjectSettings.globalize_path("res://.smoke_logs/sky_preview")
	DirAccess.make_dir_recursive_absolute(out)
	var views: Array = [["horizon", Vector3(-0.9, 0.12, -0.42)], ["up32", Vector3(-0.72, 0.53, -0.45)], ["moon", moon], ["zenith", Vector3(0.2, 0.95, 0.1)]]
	for v: Array in views:
		cam.look_at((v[1] as Vector3).normalized() * 10.0, Vector3.UP)
		for i: int in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var p: String = out.path_join("sky_%s_%s.png" % [map_id, v[0]])
		img.save_png(p)
		print("[sky_preview] ", p)
	get_tree().quit()
