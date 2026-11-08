class_name MenuScene
extends Node3D
## The main menu's live scene (UPDATE 09 section 7, DECISIONS T-144, contract C7): the Crossroads Inn at night in the
## snow, from outside on the west road. Real assets only, never a video:
##   - the inn's exterior, the yard, the grounds, the landscape, the sky and the snowfall: gravelight/ui/menu_inn.tscn,
##     cut out of Map 0 once by tools_src/gen_menu_scene.gd;
##   - the distant war: Map 0's own MapAmbience (artillery flashes with the boom delayed by distance, searchlights,
##     a bomber formation) on menu timings (MENU_AMBIENCE);
##   - our zombies: real skinned ZombieBody kits on the ZombieRig, driven straight by an AnimationPlayer with the
##     ZombieClips clips (no AI, no director, no spawns): WALKERS shamble along the outside of a fence toward the
##     camera's right and loop (a fade behind the end post), TEARERS work the boards at two of the inn's windows; each
##     carries its Marke glint (T-137) on the hand or the forehead;
##   - the squad by a fire barrel: PeopleBodies on PersonRig, posed in code every frame (Dutch smoking, Wren writing,
##     Deacon cleaning a Thompson across his knees, Peg checking her watch);
##   - two slow camera moves (a 40 s dolly, a 30 s angle over the squad's shoulders) cross-faded, a breathing FOV;
##   - progress hooks: Fernflug beaten (ProfileSave.fernflug_beaten) puts a violet point of light on the Moon
##     (MONDLICHT); Map 0's egg done (map00_radio) plays the radio faintly in a window.
## The web / Compatibility variant (`web`) halves the zombies, drops volumetric fog for depth fog and keeps one
## shadowed light. Budgets: <= 1200 draw calls and <= 4 shadowed lights on desktop.

signal posed(ms: int)

const INN_SCENE: String = "res://gravelight/ui/menu_inn.tscn"
const SHADOWED_MAX_DESKTOP: int = 4
const SHADOWED_MAX_WEB: int = 1
const DRAW_CALLS_MAX: int = 1200
## The shot: camera A stands on the west road, 1.5 m up, looking across at the inn's north-west corner.
const CAM_A: Vector3 = Vector3(-17.0, 1.5, -10.5)
const LOOK_A: Vector3 = Vector3(8.0, 3.4, 5.5)
const DOLLY_M: float = 2.0
const SHOT_A_S: float = 40.0
const SHOT_B_S: float = 30.0
const FADE_S: float = 1.0
const SWAY_DEG: float = 0.3
const FOV: float = 58.0
## The lane (depth, lateral from camera A, metres): the zombies walk from LANE_FROM to LANE_TO, just outside the fence.
const FENCE_DEPTH: float = 9.6
const LANE_FROM: Vector2 = Vector2(9.0, -11.0)
const LANE_TO: Vector2 = Vector2(7.6, 9.5)
const BARREL_AT: Vector2 = Vector2(12.4, 5.0)
## [kit, build, female, gait clip] per walker; the web variant keeps the first half.
const WALKERS: Array = [["soldier", "medium", false, "shamble_a"], ["villager", "thin", true, "shamble_b"],
	["miner", "heavy", false, "shamble_c"], ["soldier", "thin", false, "shamble_b"], ["villager", "medium", false, "shamble_a"],
	["miner", "medium", false, "shamble_c"]]
## [kit, build, female, window (gen_map00 _window: position, yaw), tear clip]
const TEARERS: Array = [["soldier", "heavy", false, Vector3(0.0, 0.0, 6.0), 90.0, "tear_rip"],
	["miner", "thin", false, Vector3(7.0, 0.0, 0.0), 0.0, "tear_wrench"]]
## The inn's lit windows: [position, yaw, sill, top] (gen_map00 _dress_windows_and_doors; local +Z = inside).
const WINDOWS: Array = [[Vector3(7.0, 0.0, 0.0), 0.0, 0.9, 2.2], [Vector3(17.0, 0.0, 0.0), 0.0, 0.9, 2.2],
	[Vector3(0.0, 0.0, 6.0), 90.0, 0.9, 2.2], [Vector3(4.0, 3.8, 0.0), 0.0, 0.9, 2.2], [Vector3(20.0, 3.8, 0.0), 0.0, 0.9, 2.2]]
const SILHOUETTE_WINDOW: int = 1
const RADIO_WINDOW: int = 3
const WALK_SPEED: Vector2 = Vector2(0.72, 0.9)
const MARKE_SCALE: float = 2.6

## -1 = decide (web build or Compatibility renderer), 0 = desktop, 1 = web. Set before adding to the tree.
var force_web: int = -1
## Tools (shots_menus --desktop): the variant every MenuScene picks when its own force_web is -1.
static var override_web: int = -1
var web: bool = false
var load_ms: int = -1
var walkers: Array[Node3D] = []
var tearers: Array[Node3D] = []
var squad: Dictionary = {}          # id -> PersonRig
var inn: Node3D = null
var ambience: MapAmbience = null
var camera: Camera3D = null
var mondlicht: Node3D = null
var radio_on: bool = false
var shot: int = 0                   # 0 = A (the dolly), 1 = B (over the shoulders)
var loops: int = 0                  # walkers that went round the lane (the smoke counts them)
var fernflug: bool = false
var egg_done: bool = false

var _t0: int = 0
var _t: float = 0.0
var _shot_t: float = 0.0
var _posed_sent: bool = false
var _rig_state: Dictionary = {}     # walker -> {k, speed, ap, fade}
var _fire: OmniLight3D
var _fire_base: float = 2.4
var _ember: StandardMaterial3D
var _smoke: CPUParticles3D
var _silhouette: MeshInstance3D
var _fade_layer: CanvasLayer
var _fade_rect: TextureRect
var _fade_left: float = 0.0
var _env: Environment
var _lib: AnimationLibrary
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The web / Compatibility test (contract C4: GLSettings.is_web / is_compat when present, else our own).
static func want_web() -> bool:
	return GLSettings.is_web() or GLSettings.is_compat()   # contract C4 (T-139)


static func walker_count(is_web: bool) -> int:
	return WALKERS.size() / 2 if is_web else WALKERS.size()


static func tearer_count(is_web: bool) -> int:
	return maxi(1, TEARERS.size() / 2) if is_web else TEARERS.size()


## A point on the ground `depth` metres ahead of camera A and `lateral` to its right.
static func at(depth: float, lateral: float, y: float = 0.0) -> Vector3:
	var f: Vector3 = _fwd()
	var r: Vector3 = _right()
	var p: Vector3 = CAM_A + f * depth + r * lateral
	return Vector3(p.x, y, p.z)


static func _fwd() -> Vector3:
	var d: Vector3 = LOOK_A - CAM_A
	d.y = 0.0
	return d.normalized()


static func _right() -> Vector3:
	return _fwd().cross(Vector3.UP).normalized()


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_rng.seed = 19441223
	var fw: int = force_web if force_web >= 0 else override_web
	web = want_web() if fw < 0 else fw == 1
	fernflug = ProfileSave.fernflug_beaten()
	egg_done = ProfileSave.egg_done("map00_radio")
	var steps: Array[Callable] = [_build_inn, _build_environment, _build_set, _build_zombies, _build_squad, _build_camera,
		_build_hooks, _build_ambience, _web_profile, _enforce_budget]
	var timing: PackedStringArray = []
	for s: Callable in steps:
		var t1: int = Time.get_ticks_msec()
		s.call()
		timing.append("%s %d" % [s.get_method().trim_prefix("_build_"), Time.get_ticks_msec() - t1])
	print("[menu_scene] built in %d ms (%s)" % [Time.get_ticks_msec() - _t0, ", ".join(timing)])


# ================================================================== the set

## Starts loading the set on a thread (the Terms & Conditions hub calls it, so the menu opens on a cached set).
static func preload_set() -> void:
	if ResourceLoader.has_cached(INN_SCENE) or not ResourceLoader.exists(INN_SCENE):
		return
	if ResourceLoader.load_threaded_get_status(INN_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(INN_SCENE, "PackedScene", true)


func _build_inn() -> void:
	var ps: PackedScene = null
	if ResourceLoader.load_threaded_get_status(INN_SCENE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ps = ResourceLoader.load_threaded_get(INN_SCENE) as PackedScene   # the hub's preload (waits if still loading)
	if ps == null:
		ps = load(INN_SCENE) as PackedScene
	if ps == null:
		push_error("MenuScene: %s missing (run tools_src/gen_menu_scene.gd)" % INN_SCENE)
		inn = Node3D.new()
		add_child(inn)
		return
	inn = ps.instantiate() as Node3D
	# the Moon over the inn in shot A: the sky dome draws it along the light's +Z (Landscape reads it on build)
	var moon: DirectionalLight3D = inn.get_node_or_null("Moon") as DirectionalLight3D
	if moon != null:
		var md: Vector3 = moon_dir()
		moon.global_transform = Transform3D(Basis.looking_at(-md, Vector3.UP), Vector3.ZERO)
		moon.light_color = Color(0.56, 0.66, 0.95)
		moon.light_energy = 0.42
		moon.shadow_enabled = true
		moon.directional_shadow_max_distance = 45.0
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		moon.light_volumetric_fog_energy = 0.6
	var snow: Node = inn.get_node_or_null("Snowfall")
	if snow != null:
		var c: Vector3 = at(10.0, 0.0)
		snow.set("areas", [AABB(Vector3(c.x - 22.0, 0.0, c.z - 22.0), Vector3(44.0, 16.0, 44.0))] as Array[AABB])
		snow.set("density", 0.45 if web else 0.9)
	add_child(inn)


## The direction from the scene to the Moon: above the inn, a little right of the frame's centre.
static func moon_dir() -> Vector3:
	var f: Vector3 = _fwd()
	var r: Vector3 = _right()
	return (f * cos(deg_to_rad(26.0)) + r * 0.2 + Vector3.UP * sin(deg_to_rad(26.0))).normalized()


func _build_environment() -> void:
	var we: WorldEnvironment = inn.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		inn.add_child(we)
	_env = (we.environment.duplicate() as Environment) if we.environment != null else Environment.new()
	we.environment = _env
	_env.sdfgi_enabled = false
	_env.ssil_enabled = false
	_env.ssr_enabled = false
	_env.ssao_enabled = not web
	_env.glow_enabled = true
	_env.glow_intensity = 0.9
	_env.glow_bloom = 0.08
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.07, 0.085, 0.13)
	_env.fog_density = 0.012 if not web else 0.02
	_env.fog_height = 1.6
	_env.fog_height_density = 0.2
	_env.volumetric_fog_enabled = not web
	if not web:
		_env.volumetric_fog_density = 0.018
		_env.volumetric_fog_albedo = Color(0.72, 0.76, 0.88)
		_env.volumetric_fog_length = 60.0
		# the ground fog low over the yard and the road
		var fv: FogVolume = FogVolume.new()
		fv.name = "GroundFog"
		fv.size = Vector3(60.0, 1.4, 50.0)
		fv.position = at(14.0, 0.0, 0.3)
		var fm: FogMaterial = FogMaterial.new()
		fm.density = 0.22
		fm.albedo = Color(0.78, 0.82, 0.92)
		fm.height_falloff = 1.6
		fm.edge_fade = 0.5
		fv.material = fm
		add_child(fv)
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 0.85
	LookGrade.apply(_env, "menu")   # UPDATE 12 (T-207): the archive-reel look, data/look/menu.json


func _build_set() -> void:
	var g: Node3D = Node3D.new()
	g.name = "MenuSet"
	add_child(g)
	# the rail fence the zombies walk along, between the camera and the squad
	var fa: Vector3 = at(FENCE_DEPTH + 0.6, -13.0)
	var fb: Vector3 = at(FENCE_DEPTH - 1.0, 12.0)
	Props.fence(g, fa, fb, 4401)
	# the end post the walkers fade behind, a dead tree beside it
	var end_post: Vector3 = at(LANE_TO.x - 0.6, LANE_TO.y + 0.4)
	Props.cyl(g, end_post + Vector3(0, 0.9, 0), 0.14, 1.8, "beam")
	Props.dead_tree(g, at(LANE_TO.x + 1.4, LANE_TO.y + 2.6), 4402, 6.5)
	# the fire barrel, the crates the two sit on
	var b: Vector3 = at(BARREL_AT.x, BARREL_AT.y)
	Props.oil_drum(g, b, "rust")
	Props.flames(g, b + Vector3(0, 0.9, 0), 0.45, 0.55, 18 if web else 30)
	Props.embers(g, b + Vector3(0, 1.0, 0), 0.3, 10 if web else 16)
	Props.smoke(g, b + Vector3(0, 1.4, 0), 0.25, 1.4, 10)
	_fire = OmniLight3D.new()
	_fire.name = "BarrelFire"
	_fire.position = b + Vector3(0, 1.25, 0)
	_fire.light_color = Color(1.0, 0.56, 0.24)
	_fire.light_energy = _fire_base
	_fire.omni_range = 8.0
	_fire.omni_attenuation = 1.4
	_fire.shadow_enabled = not web
	_fire.light_volumetric_fog_energy = 0.4
	g.add_child(_fire)
	Props.crate(g, _squad_spot("wren") + _fwd() * 0.06 - Vector3(0, 0, 0), 0.46, 20.0)
	Props.crate(g, _squad_spot("deacon"), 0.46, -12.0)
	Props.snow_drift(g, at(FENCE_DEPTH + 1.8, -4.0), Vector3(3.0, 0.35, 1.6))
	Props.snow_drift(g, at(FENCE_DEPTH - 0.6, 6.0), Vector3(2.4, 0.3, 1.2))
	_build_windows(g)


## Warm amber panes behind the inn's windows (the curtains hang in front of them), a spill light outside each lit
## face, the silhouette that crosses one of them, and the boards at the two windows the zombies work on.
func _build_windows(g: Node3D) -> void:
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_texture = _window_texture()
	glow.albedo_color = Color(1.0, 0.72, 0.38)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.62, 0.28)
	glow.emission_energy_multiplier = 4.5
	glow.emission_texture = glow.albedo_texture
	glow.disable_fog = false
	for i: int in WINDOWS.size():
		var w: Array = WINDOWS[i]
		var wg: Node3D = Node3D.new()
		wg.name = "WindowGlow%d" % i
		wg.position = w[0]
		wg.rotation.y = deg_to_rad(float(w[1]))
		g.add_child(wg)
		var sill: float = float(w[2])
		var top: float = float(w[3])
		var pane: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(1.9, top - sill + 0.4)
		pane.mesh = q
		pane.material_override = glow
		pane.position = Vector3(0.0, (sill + top) * 0.5, 0.02)
		pane.rotation.y = PI   # the quad faces +Z; the pane faces out (-Z)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wg.add_child(pane)
		if i == SILHOUETTE_WINDOW:
			_silhouette = MeshInstance3D.new()
			var sq: QuadMesh = QuadMesh.new()
			sq.size = Vector2(0.75, 1.15)
			_silhouette.mesh = sq
			var sm: StandardMaterial3D = StandardMaterial3D.new()
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.albedo_texture = _silhouette_texture()
			sm.albedo_color = Color(0.05, 0.035, 0.03, 0.92)
			_silhouette.material_override = sm
			_silhouette.position = Vector3(0.0, sill + 0.5, 0.45)
			_silhouette.rotation.y = PI
			_silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wg.add_child(_silhouette)
	# the warm spill on the snow under the north and west faces (no shadows: inside the light budget)
	for sp: Array in [[Vector3(7.0, 1.6, -1.3), 2.0], [Vector3(17.0, 1.6, -1.3), 1.6], [Vector3(-1.3, 1.6, 6.0), 1.8]]:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "WindowSpill"
		l.position = sp[0]
		l.light_color = Color(1.0, 0.66, 0.34)
		l.light_energy = float(sp[1])
		l.omni_range = 4.6
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.8
		g.add_child(l)
	# the boards the tearers pull at
	for t: Array in TEARERS:
		var bg: Node3D = Node3D.new()
		bg.name = "Boards"
		bg.position = t[3]
		bg.rotation.y = deg_to_rad(float(t[4]))
		g.add_child(bg)
		for k: int in 3:
			Props.obox(bg, Vector3(0.0, 1.15 + k * 0.38, -0.22), Vector3(2.0, 0.17, 0.05), "planks", Vector3(0, 0, [8.0, -5.0, 12.0][k]))


func _window_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in 64:
		for x: int in 64:
			var u: float = float(x) / 63.0
			var v: float = float(y) / 63.0
			# a lamp-lit room: brighter low and toward the middle, two dim window bars
			var k: float = 0.55 + 0.45 * (1.0 - absf(u - 0.5) * 1.6) * (0.6 + 0.4 * v)
			if absf(u - 0.5) < 0.025 or absf(v - 0.42) < 0.025:
				k *= 0.35
			img.set_pixel(x, y, Color(k, k, k, 1.0))
	return ImageTexture.create_from_image(img)


func _silhouette_texture() -> ImageTexture:
	var img: Image = Image.create(48, 72, false, Image.FORMAT_RGBA8)
	for y: int in 72:
		for x: int in 48:
			var px: float = float(x) - 23.5
			var head: bool = Vector2(px, float(y) - 14.0).length() < 8.5
			var neck: bool = absf(px) < 4.0 and y >= 20 and y < 27
			var shoulders: bool = y >= 26 and absf(px) < 21.0 - maxf(0.0, 32.0 - float(y)) * 1.6
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if head or neck or shoulders else 0.0))
	return ImageTexture.create_from_image(img)


# ================================================================== the zombies

func _clip_library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var names: Array[String] = []
	for w: Array in WALKERS:
		names.append(str(w[3]))
	for t: Array in TEARERS:
		names.append(str(t[5]))
	names.append("idle")
	if ZombieClips._bones.is_empty():
		ZombieClips._bones = ZombieRig.bone_names()   # generate() samples these; library() would bake all ~100 clips
	for n: String in names:
		if _lib.has_animation(n) or not ZombieClips.all_clip_names().has(n):
			continue
		# only the clips the menu plays, generated straight from anim.json (the game's whole library is not needed)
		var src: Animation = ZombieClips._lib.get_animation(n) if ZombieClips._lib != null and ZombieClips._lib.has_animation(n) else ZombieClips.generate(n)
		var a: Animation = src.duplicate(true) as Animation
		var root_t: int = a.find_track(NodePath("Skel:Root"), Animation.TYPE_POSITION_3D)
		if root_t >= 0:
			a.remove_track(root_t)   # the root motion: MenuScene moves the body down the lane itself
		a.loop_mode = Animation.LOOP_LINEAR   # the tear clips are one-shots in the game; here they repeat
		_lib.add_animation(n, a)
	return _lib


## One zombie body: the rig, the skinned kit, its Marke glint and an AnimationPlayer on clip `clip`.
func _zombie(kit: String, build: String, female: bool, clip: String, net_id: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Zombie_%s" % kit
	var skel: Skeleton3D = ZombieRig.build_skeleton()
	root.add_child(skel)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ZombieBody.build_skinned(kit, build, female)
	skel.add_child(body)
	body.skeleton = NodePath("..")
	body.skin = skel.create_skin_from_rest_transforms()
	body.set_instance_shader_parameter("inst_dirt", _rng.randf_range(0.25, 0.6))
	body.set_instance_shader_parameter("inst_frost", _rng.randf_range(0.1, 0.35))
	var mk: Dictionary = (GLData.table("enemies") as Dictionary).get("marke", {})
	var site: StringName = ZombieBody.marke_site_for(net_id, float(mk.get("hand_chance", 0.6)))
	var ms: Array = ZombieBody.MARKE_SITES[site]
	var att: BoneAttachment3D = BoneAttachment3D.new()
	att.name = "MarkeAt"
	att.bone_name = str(ms[0])
	skel.add_child(att)
	var gl: MeshInstance3D = MeshInstance3D.new()
	gl.name = "MarkeGlint"
	gl.mesh = ZombieBody.marke_glint_mesh()
	gl.position = ms[1]
	gl.scale = Vector3.ONE * MARKE_SCALE   # a menu-distance glint: the bead is 1.5 cm in the game
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(gl)
	root.set_meta("marke_site", site)
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AP"
	ap.root_node = NodePath("..")
	ap.add_animation_library(&"", _clip_library())
	root.add_child(ap)
	if ap.has_animation(clip):
		ap.play(clip)
		ap.seek(_rng.randf_range(0.0, ap.current_animation_length), true)
	return root


func _build_zombies() -> void:
	ZombieBody.ensure_globals()
	var n: int = walker_count(web)
	for i: int in n:
		var w: Array = WALKERS[i]
		var z: Node3D = _zombie(str(w[0]), str(w[1]), bool(w[2]), str(w[3]), 9100 + i)
		add_child(z)
		var speed: float = _rng.randf_range(WALK_SPEED.x, WALK_SPEED.y)
		var ap: AnimationPlayer = z.get_node("AP") as AnimationPlayer
		ap.speed_scale = speed / 1.3   # the shamble clips are authored at 1.3 m/s (anim.json gait.shamble)
		_rig_state[z] = {"k": float(i) / float(n), "speed": speed, "fade": 0.0}
		walkers.append(z)
		_place_walker(z, 0.0)
	for j: int in tearer_count(web):
		var t: Array = TEARERS[j]
		var z2: Node3D = _zombie(str(t[0]), str(t[1]), bool(t[2]), str(t[5]), 9200 + j)
		var wpos: Vector3 = t[3]
		var yaw: float = deg_to_rad(float(t[4]))
		var out: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.62)
		z2.position = wpos + out
		z2.rotation.y = yaw + PI   # the body faces -Z: turn it to face the window (local +Z of the window = inside)
		(z2.get_node("AP") as AnimationPlayer).speed_scale = _rng.randf_range(0.8, 1.0)
		add_child(z2)
		tearers.append(z2)


func _lane_length() -> float:
	return at(LANE_FROM.x, LANE_FROM.y).distance_to(at(LANE_TO.x, LANE_TO.y))


func _place_walker(z: Node3D, delta: float) -> void:
	var st: Dictionary = _rig_state[z]
	var k: float = float(st["k"]) + float(st["speed"]) * delta / maxf(1.0, _lane_length())
	if k >= 1.0:
		k -= 1.0
		loops += 1
	st["k"] = k
	var a: Vector3 = at(LANE_FROM.x, LANE_FROM.y)
	var b: Vector3 = at(LANE_TO.x, LANE_TO.y)
	var p: Vector3 = a.lerp(b, k)
	# a little weave so the line never looks laid out with a ruler
	p += _fwd() * sin(k * 9.0 + float(walkers.find(z)) * 1.7) * 0.25
	z.position = p
	var dir: Vector3 = (b - a).normalized()
	z.rotation.y = atan2(-dir.x, -dir.z) + sin(_t * 0.4 + k * 5.0) * 0.06
	# the fade behind the end post (and back in at the start, off the left of the frame)
	var fade: float = clampf((k - 0.94) / 0.05, 0.0, 1.0) + clampf((0.03 - k) / 0.03, 0.0, 1.0)
	if absf(fade - float(st["fade"])) > 0.01:
		st["fade"] = fade
		var body: MeshInstance3D = z.get_node("Skel/Body") as MeshInstance3D
		body.set_instance_shader_parameter("inst_dissolve", fade)
		z.visible = fade < 0.99


# ================================================================== the squad

## Where each of the four stands or sits round the barrel (depth, lateral offsets from BARREL_AT).
static func _squad_offset(id: String) -> Vector2:
	match id:
		"dutch":
			return Vector2(-0.35, 1.05)
		"peg":
			return Vector2(-0.45, -1.0)
		"wren":
			return Vector2(0.95, -0.85)
		"deacon":
			return Vector2(0.95, 0.95)
	return Vector2.ZERO


static func _squad_spot(id: String) -> Vector3:
	var o: Vector2 = _squad_offset(id)
	return at(BARREL_AT.x + o.x, BARREL_AT.y + o.y)


func _build_squad() -> void:
	var barrel: Vector3 = at(BARREL_AT.x, BARREL_AT.y)
	for id: String in ["dutch", "peg", "wren", "deacon"]:
		var holder: Node3D = Node3D.new()
		holder.name = "Squad_" + id
		add_child(holder)
		holder.position = _squad_spot(id)
		var rig: PersonRig = PersonRig.new()
		holder.add_child(rig)
		if not rig.setup(id):
			push_warning("MenuScene: no body for %s" % id)
			continue
		squad[id] = rig
		# facing: the standing two turn to the fire, the sitting two to the camera's side of it
		var target: Vector3 = barrel if id in ["dutch", "peg"] else barrel.lerp(CAM_A, 0.35)
		target.y = 0.0
		var d: Vector3 = target - holder.position
		holder.rotation.y = atan2(-d.x, -d.z)
		_props_for(id, rig)
	_pose_squad()


func _props_for(id: String, rig: PersonRig) -> void:
	match id:
		"dutch":
			var hand: BoneAttachment3D = rig.attachment("RightHand")
			var cig: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.0045
			cm.bottom_radius = 0.0045
			cm.height = 0.07
			cig.mesh = cm
			var paper: StandardMaterial3D = StandardMaterial3D.new()
			paper.albedo_color = Color(0.92, 0.9, 0.84)
			cig.material_override = paper
			cig.position = Vector3(0.0, -0.09, -0.03)
			cig.rotation = Vector3(PI * 0.5, 0, 0)
			hand.add_child(cig)
			var tip: MeshInstance3D = MeshInstance3D.new()
			var tm: SphereMesh = SphereMesh.new()
			tm.radius = 0.006
			tm.height = 0.012
			tip.mesh = tm
			_ember = StandardMaterial3D.new()
			_ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ember.albedo_color = Color(1.0, 0.4, 0.12)
			_ember.emission_enabled = true
			_ember.emission = Color(1.0, 0.38, 0.1)
			_ember.emission_energy_multiplier = 3.0
			tip.material_override = _ember
			tip.position = Vector3(0.0, -0.09, -0.068)
			hand.add_child(tip)
			_smoke = CPUParticles3D.new()
			_smoke.name = "CigaretteSmoke"
			_smoke.amount = 14
			_smoke.lifetime = 2.6
			_smoke.local_coords = false
			_smoke.direction = Vector3(0, 1, 0)
			_smoke.spread = 8.0
			_smoke.gravity = Vector3(0.06, 0.12, 0)
			_smoke.initial_velocity_min = 0.08
			_smoke.initial_velocity_max = 0.16
			_smoke.scale_amount_min = 0.6
			_smoke.scale_amount_max = 1.4
			var sq: QuadMesh = QuadMesh.new()
			sq.size = Vector2(0.05, 0.05)
			var smm: StandardMaterial3D = StandardMaterial3D.new()
			smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			smm.albedo_texture = Snowfall.flake_texture()
			smm.albedo_color = Color(0.75, 0.76, 0.8, 0.16)
			smm.vertex_color_use_as_albedo = true
			sq.material = smm
			_smoke.mesh = sq
			var ramp: Gradient = Gradient.new()
			ramp.set_color(0, Color(1, 1, 1, 0.7))
			ramp.set_color(1, Color(1, 1, 1, 0.0))
			_smoke.color_ramp = ramp
			_smoke.position = Vector3(0.0, -0.09, -0.07)
			hand.add_child(_smoke)
		"wren":
			var lh: BoneAttachment3D = rig.attachment("LeftHand")
			Props.obox(lh, Vector3(0.0, -0.08, -0.02), Vector3(0.14, 0.012, 0.19), "leather")
			Props.obox(lh, Vector3(0.0, -0.072, -0.02), Vector3(0.13, 0.006, 0.18), "paper")
			var rh: BoneAttachment3D = rig.attachment("RightHand")
			Props.obox(rh, Vector3(0.0, -0.08, -0.04), Vector3(0.008, 0.008, 0.13), "beam", Vector3(20, 0, 0))
		"deacon":
			var gun: Node3D = WeaponModels.build(&"thompson")
			if gun != null:
				gun.name = "Thompson"
				# across his knees: the gun's -Z (muzzle) to his left, lying on the thighs
				gun.position = Vector3(0.05, 0.62, -0.32)
				gun.rotation = Vector3(0.0, PI * 0.5, deg_to_rad(8.0))
				(rig.get_parent() as Node3D).add_child(gun)
			var rh2: BoneAttachment3D = rig.attachment("RightHand")
			Props.obox(rh2, Vector3(0.0, -0.1, -0.02), Vector3(0.11, 0.05, 0.08), "linen")
		"peg":
			var wrist: BoneAttachment3D = rig.attachment("LeftHand")
			Props.cyl(wrist, Vector3(0.0, -0.02, -0.035), 0.017, 0.006, "brass", Vector3(90, 0, 0))


## One frame of the four's procedural poses (PersonRig.drive, the same solver RemoteBody and PatronBody use).
func _pose_squad() -> void:
	var t: float = _t
	for id: String in squad.keys():
		var rig: PersonRig = squad[id]
		var breathe: float = sin(t * 1.7 + float(id.length())) * 0.006
		match id:
			"dutch":
				# a drag every ~7 s: the hand comes up, the ember brightens, the smoke goes on
				var cyc: float = fmod(t + 2.0, 7.0)
				var drag: float = smoothstep(0.0, 0.8, cyc) * (1.0 - smoothstep(2.2, 3.0, cyc))
				var hips: Vector3 = Vector3(0.0, 0.95 + breathe, 0.0)
				var chest: Basis = Basis.from_euler(Vector3(0.04, sin(t * 0.21) * 0.06, 0.0))
				var head: Basis = Basis.from_euler(Vector3(-0.05 + drag * 0.08, sin(t * 0.17) * 0.35, 0.0))
				var rh: Vector3 = _chest_pt(hips, chest, Vector3(0.21, -0.02, -0.12).lerp(Vector3(0.05, 0.58, -0.16), drag))
				rig.drive({"hips": hips, "chest": chest, "head": head, "legs": [[0.04, -0.06], [-0.05, -0.12]],
					"hands": [null, rh], "poles": [Vector3(-0.6, -1.0, 0.3), Vector3(0.7, -0.6, 0.2)], "plant": true})
				if _ember != null:
					_ember.emission_energy_multiplier = 2.0 + 9.0 * smoothstep(1.0, 1.8, cyc) * (1.0 - smoothstep(1.8, 2.6, cyc))
			"peg":
				# her watch every ~12 s
				var wc: float = fmod(t + 5.0, 12.0)
				var look: float = smoothstep(0.0, 0.6, wc) * (1.0 - smoothstep(1.9, 2.5, wc))
				var hips2: Vector3 = Vector3(0.0, 0.95 + breathe, 0.0)
				var chest2: Basis = Basis.from_euler(Vector3(0.02 - look * 0.06, 0.0, 0.0))
				var head2: Basis = Basis.from_euler(Vector3(-0.05 - look * 0.5, sin(t * 0.13) * 0.25 * (1.0 - look) - look * 0.15, 0.0))
				var lh: Vector3 = _chest_pt(hips2, chest2, Vector3(-0.23, -0.2, -0.02).lerp(Vector3(-0.04, 0.32, -0.3), look))
				var rh2: Vector3 = _chest_pt(hips2, chest2, Vector3(0.18, -0.08, 0.02))   # a hand on her belt
				rig.drive({"hips": hips2, "chest": chest2, "head": head2, "legs": [[-0.03, -0.05], [0.06, -0.1]],
					"hands": [lh, rh2], "poles": [Vector3(-0.8, -0.8, 0.1), Vector3(0.8, -0.6, 0.4)], "plant": true})
			"wren":
				# head down over the notebook, the pencil moving, a page now and then
				var hips3: Vector3 = Vector3(0.0, 0.5 + breathe * 0.5, 0.06)
				var chest3: Basis = Basis.from_euler(Vector3(-0.32, 0.05, 0.0))
				var head3: Basis = Basis.from_euler(Vector3(-0.45 + sin(t * 0.3) * 0.04, 0.08, 0.0))
				var write: Vector3 = Vector3(sin(t * 6.3) * 0.022 + fmod(t * 0.05, 0.06), 0.0, cos(t * 4.1) * 0.012)
				var lh3: Vector3 = _chest_pt(hips3, chest3, Vector3(-0.06, -0.02, -0.36))
				var rh3: Vector3 = _chest_pt(hips3, chest3, Vector3(0.04, 0.0, -0.37) + write)
				rig.drive({"hips": hips3, "chest": chest3, "head": head3, "legs": [[1.5, -1.45], [1.45, -1.55]],
					"hands": [lh3, rh3], "poles": [Vector3(-0.8, -0.6, 0.1), Vector3(0.8, -0.6, 0.1)], "plant": true})
			"deacon":
				# working the Thompson with a rag, the left hand steadying it
				var hips4: Vector3 = Vector3(0.0, 0.5 + breathe * 0.5, 0.06)
				var chest4: Basis = Basis.from_euler(Vector3(-0.28, -0.04, 0.0))
				var head4: Basis = Basis.from_euler(Vector3(-0.4, -0.1 + sin(t * 0.25) * 0.06, 0.0))
				var rub: float = sin(t * 2.4) * 0.1
				var lh4: Vector3 = _chest_pt(hips4, chest4, Vector3(-0.2, -0.08, -0.36))
				var rh4: Vector3 = _chest_pt(hips4, chest4, Vector3(0.06 + rub, -0.05 + absf(rub) * 0.1, -0.4))
				rig.drive({"hips": hips4, "chest": chest4, "head": head4, "legs": [[1.5, -1.5], [1.42, -1.46]],
					"hands": [lh4, rh4], "poles": [Vector3(-0.8, -0.6, 0.1), Vector3(0.8, -0.6, 0.1)], "plant": true})


## A point in the chest's frame (PatronBody's convention: the chest sits 0.12 m above the hips) in the pivot's.
static func _chest_pt(hips: Vector3, chest: Basis, local: Vector3) -> Vector3:
	return hips + chest * (Vector3(0.0, 0.12, 0.0) + local)


# ================================================================== camera, hooks, ambience

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	camera.fov = FOV
	camera.near = 0.08
	camera.far = 900.0
	camera.current = true
	add_child(camera)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = -1   # over the 3D, under every menu
	add_child(_fade_layer)
	_fade_rect = TextureRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)
	LookPost.add_to(self, "menu", -2)   # UPDATE 12 (T-208): the archive grain, vignette and flicker, under the fade and every menu
	_place_camera()


## Shot A dollies DOLLY_M to the right over SHOT_A_S; shot B looks over the squad's shoulders at the lane.
func _place_camera() -> void:
	var r: Vector3 = _right()
	var k: float = clampf(_shot_t / (SHOT_A_S if shot == 0 else SHOT_B_S), 0.0, 1.0)
	var e: float = k * k * (3.0 - 2.0 * k)
	var sway: Vector3 = Vector3(sin(_t * 0.37), sin(_t * 0.23 + 1.0), 0.0) * deg_to_rad(SWAY_DEG)
	var pos: Vector3
	var look: Vector3
	if shot == 0:
		pos = CAM_A + r * DOLLY_M * e
		look = LOOK_A + r * DOLLY_M * e
	else:
		var from: Vector3 = at(BARREL_AT.x + 3.4, BARREL_AT.y + 1.6, 1.62)
		var to: Vector3 = at(LANE_FROM.x - 0.6, 1.0, 1.05)
		pos = from + (to - from).normalized() * 0.8 * e
		look = to + r * (-1.5 + 3.0 * e)
	camera.global_transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	camera.rotate_object_local(Vector3.RIGHT, sway.x)
	camera.rotate_object_local(Vector3.UP, sway.y)
	camera.fov = FOV + sin(_t * 0.42) * 0.7


## The cut between the two shots: a snapshot of the last frame fades out over the new angle (desktop); the web
## variant (a read-back is slow in a browser) dips through the night colour instead.
func _cut() -> void:
	var tex: Texture2D = null
	if not web and DisplayServer.get_name() != "headless":
		var img: Image = get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		var g: GradientTexture2D = GradientTexture2D.new()
		var gr: Gradient = Gradient.new()
		gr.set_color(0, Color(0.01, 0.012, 0.02))
		gr.set_color(1, Color(0.01, 0.012, 0.02))
		g.gradient = gr
		tex = g
	_fade_rect.texture = tex
	_fade_rect.modulate.a = 1.0
	_fade_rect.visible = true
	_fade_left = FADE_S
	shot = 1 - shot
	_shot_t = 0.0


func _build_hooks() -> void:
	# MONDLICHT: a violet point of light on the Moon, with a faint halo
	mondlicht = Node3D.new()
	mondlicht.name = "Mondlicht"
	mondlicht.visible = fernflug
	add_child(mondlicht)
	var md: Vector3 = moon_dir()
	mondlicht.position = CAM_A + md * 260.0 + _right() * 1.5
	for layer: Array in [[6.0, 1.0, 4.0, false], [30.0, 0.35, 1.5, true]]:
		var q: MeshInstance3D = MeshInstance3D.new()
		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(float(layer[0]), float(layer[0]))
		q.mesh = qm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if bool(layer[3]) else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.disable_fog = true
		m.albedo_texture = Snowfall.flake_texture()
		var vc: Color = ZombieBody.MARKE_COLOR if bool(layer[3]) else Color(0.56, 0.24, 0.98)   # the core deep enough to read on the white Moon
		m.albedo_color = Color(vc.r, vc.g, vc.b, float(layer[1]))
		m.emission_enabled = true
		m.emission = ZombieBody.MARKE_COLOR
		m.emission_energy_multiplier = float(layer[2])
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mondlicht.add_child(q)
	# the radio in the window (Map 0's egg done): faint, and only while the menu stands
	radio_on = egg_done
	if radio_on:
		var w: Array = WINDOWS[RADIO_WINDOW]
		var p: Vector3 = (w[0] as Vector3) + Vector3(0.0, 1.5, 0.6)
		_radio.call_deferred(p)


func _radio(p: Vector3) -> void:
	if not is_inside_tree():
		return
	AudioDirector.play_3d("gramophone_record", p, -16.0, 0.0)
	AudioDirector.play_3d("radio_static", p, -26.0, 0.0)


## Map 0's distant war on the menu's timings (MapAmbience reads its cfg on a deferred setup, so the overrides land).
func _build_ambience() -> void:
	ambience = MapAmbience.new()
	ambience.name = "MenuAmbience"
	inn.add_child(ambience)
	var c: Dictionary = ambience.cfg
	_patch(c, "artillery", {"first_after": [2, 5], "interval": [8, 20], "interval_late": [8, 20], "km": [4.0, 8.0], "km_late": [4.0, 8.0],
		"bearings": [95, 165], "barrage_chance": 0.1, "barrage_chance_late": 0.1})
	_patch(c, "bombers", {"first_after": [14, 22], "interval": [80, 100], "interval_late": [80, 100], "count": [3, 5],
		"altitude": [110, 140], "headings": [190, 230], "offset": [-60, 40]})
	for off: String in ["fighters", "cookoff", "dog"]:
		_patch(c, off, {"first_after": [99999, 99999], "interval": [99999, 99999], "interval_late": [99999, 99999]})
	# T-192 (UPDATE 11 section 6): the far front's flares on the eastern horizon, often
	_patch(c, "flares", {"min_round": 1, "first_after": [5, 10], "interval": [18, 32], "interval_late": [18, 32], "bearings": [55, 150], "radius": [150, 230]})
	_patch(c, "plane_down", {"min_round": 9999})
	_patch(c, "intensity", {"start_round": 1, "full_round": 99})
	c.erase("risen_column")   # Map 0's far column is the game's; the menu has its own lane at the treeline
	c.erase("horror")         # the match's grit (frost, breathing, flies) is not the menu's; it keeps only the chant
	_build_risen()
	_build_chant()


## T-192: the chant bed under the menu theme (our own synthesis, the Ambience bus), low and steady.
const CHANT_DB: float = -31.0
var chant: AudioStreamPlayer = null


func _build_chant() -> void:
	if not AudioDirector.has_sound("horror_chant_bed"):
		return
	chant = AudioDirector.make_loop_2d("horror_chant_bed", self, CHANT_DB)
	if chant != null:
		chant.play(_rng.randf_range(0.0, 30.0))


## T-192: the Soviet risen (the Returned) walking past the fence at the treeline, behind the Marke-lit walkers: a
## RisenColumn (presentation only) on its own lane in camera A's frame (RISEN_FROM / RISEN_TO: depth, lateral m).
const RISEN_FROM: Vector2 = Vector2(31.0, -30.0)
const RISEN_TO: Vector2 = Vector2(19.0, -8.5)
const RISEN_COUNT: int = 5
var risen: RisenColumn = null


static func risen_count(is_web: bool) -> int:
	return maxi(2, RISEN_COUNT / 2) if is_web else RISEN_COUNT


func _build_risen() -> void:
	var kits: Dictionary = ((GLData.table("enemies") as Dictionary).get("soviet_risen", {}) as Dictionary).get("kits", RisenColumn.DEFAULT_KITS)
	risen = RisenColumn.make({"from": at(RISEN_FROM.x, RISEN_FROM.y), "to": at(RISEN_TO.x, RISEN_TO.y), "count": risen_count(web),
		"speed": [0.5, 0.7], "width": 1.6, "ground": "flat", "seed": 1930, "fade": 0.12, "kits": kits})
	add_child(risen)
	risen.position = Vector3.ZERO


static func _patch(c: Dictionary, key: String, over: Dictionary) -> void:
	var sec: Dictionary = (c.get(key, {}) as Dictionary).duplicate(true)
	for k: Variant in over.keys():
		sec[k] = over[k]
	c[key] = sec


# ================================================================== budgets

## T-139's browser profile on the real Compatibility renderer (depth fog, capped shadows, halved particles); a forced
## web variant on the desktop (tests, shots) skips it, since it also sets global LOD and snow scales.
func _web_profile() -> void:
	if web and GLSettings.is_compat():
		WebProfile.apply(self)


## Shadowed lights stay inside the budget: the Moon and the barrel first, then nothing else casts.
func _enforce_budget() -> void:
	var cap: int = SHADOWED_MAX_WEB if web else SHADOWED_MAX_DESKTOP
	var keep: Array[Light3D] = []
	var moon: Light3D = inn.get_node_or_null("Moon") as Light3D
	if moon != null and moon.shadow_enabled:
		keep.append(moon)
	if _fire != null and _fire.shadow_enabled:
		keep.append(_fire)
	for l: Node in find_children("*", "Light3D", true, false):
		var li: Light3D = l as Light3D
		if li.shadow_enabled and not keep.has(li):
			keep.append(li)
	for i: int in keep.size():
		if i >= cap:
			keep[i].shadow_enabled = false


func shadowed_lights() -> int:
	var n: int = 0
	for l: Node in find_children("*", "Light3D", true, false):
		if (l as Light3D).shadow_enabled and (l as Light3D).is_visible_in_tree():
			n += 1
	return n


## The scene's numbers for the census and the tests (draw calls come from the renderer and are 0 headless).
func census() -> Dictionary:
	var lights: int = find_children("*", "Light3D", true, false).size()
	return {"web": web, "walkers": walkers.size(), "tearers": tearers.size(), "zombies": walkers.size() + tearers.size(),
		"risen": risen.bodies.size() if risen != null else 0, "chant": chant != null and chant.playing,
		"squad": squad.size(), "lights": lights, "shadowed_lights": shadowed_lights(),
		"meshes": find_children("*", "MeshInstance3D", true, false).size(),
		"multimeshes": find_children("*", "MultiMeshInstance3D", true, false).size(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"volumetric_fog": _env != null and _env.volumetric_fog_enabled, "sdfgi": _env != null and _env.sdfgi_enabled,
		"mondlicht": mondlicht != null and mondlicht.visible, "radio": radio_on, "load_ms": load_ms}


# ================================================================== the loop

func _process(delta: float) -> void:
	_t += delta
	_shot_t += delta
	for z: Node3D in walkers:
		_place_walker(z, delta)
	_pose_squad()
	if _fire != null:
		var n: float = sin(_t * 11.0) * 0.5 + sin(_t * 17.3 + 1.2) * 0.3 + sin(_t * 5.1) * 0.4
		_fire.light_energy = _fire_base * (1.0 + 0.12 * n)
	if _silhouette != null:
		# someone crossing the room now and then, pausing by the window
		var sc: float = fmod(_t, 26.0)
		_silhouette.position.x = clampf(lerpf(-1.6, 1.6, smoothstep(4.0, 12.0, sc)) - lerpf(0.0, 3.2, smoothstep(17.0, 24.0, sc)) + 0.0, -1.6, 1.6)
	RenderingServer.global_shader_parameter_set("gl_hum", 0.55 + 0.45 * sin(_t * 1.3))
	if _fade_left > 0.0:
		_fade_left -= delta
		_fade_rect.modulate.a = clampf(_fade_left / FADE_S, 0.0, 1.0)
		if _fade_left <= 0.0:
			_fade_rect.visible = false
	if _shot_t >= (SHOT_A_S if shot == 0 else SHOT_B_S):
		_cut()
	_place_camera()
	if not _posed_sent:
		_posed_sent = true
		load_ms = Time.get_ticks_msec() - _t0
		print("[menu_scene] first frame with the zombies posed after %d ms (%s variant)" % [load_ms, "web" if web else "desktop"])
		posed.emit(load_ms)
