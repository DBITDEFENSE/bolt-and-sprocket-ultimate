class_name RisenColumn
extends Node3D
## UPDATE 11 (T-192, work order section 6): the Soviet risen, the Returned, walking west in a loose column, as
## presentation only. Real skinned bodies (ZombieBody's Soviet kits on the ZombieRig, the frost skin, the milky eyes,
## their wound, a hat rolled from the kit) driven straight by an AnimationPlayer on the shamble clips with the root
## motion stripped, moved along the line from `from` to `to` and looping, with a dissolve at both ends. No AI, no
## director, no collision, no hitboxes, not in any group the game or the bots look at: nothing can target it and it
## never blocks anything. Used by Map 0's MapAmbience kind `risen_column` (the war on the landscape), the main menu's
## treeline lane, and the U11 cutscenes.
##
## From a script (a cutscene, a tool):
##   var col: RisenColumn = RisenColumn.make({"from": Vector3(80, 0, -40), "to": Vector3(-60, 0, -55), "count": 10})
##   some_parent.add_child(col)          # builds on _ready; set col.paused = true to freeze the walk
## cfg keys (all optional): from, to (Vector3 or [x, y, z]), count (8), speed ([0.55, 0.8] m/s), width (lane half
## width, 2.5 m), kits ({"soviet": 0.55, "soviet_tunic": 0.25, "soviet_burial": 0.2}), ground ("terrain": snap y to
## Map 0's LandscapeTerrain.height; "flat": keep from/to's y), seed, fade (the share of the line that dissolves at
## each end, 0.06), loop (true; false = walk once and stop at `to`), visible_m (the bodies' visibility range end, 0 =
## always), shadows (false).

const DEFAULT_KITS: Dictionary = {"soviet": 0.55, "soviet_tunic": 0.25, "soviet_burial": 0.2}
const CLIPS: PackedStringArray = ["shamble_a", "shamble_b", "shamble_c"]
const CLIP_SPEED: float = 1.3   # the shamble clips are authored at 1.3 m/s (anim.json gait.shamble)

var cfg: Dictionary = {}
var bodies: Array[Node3D] = []
var paused: bool = false
var loops: int = 0
var _state: Array[Dictionary] = []   # per body: {k, speed, side, phase, fade}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _a: Vector3
var _b: Vector3
static var _lib: AnimationLibrary


static func make(c: Dictionary) -> RisenColumn:
	var col: RisenColumn = RisenColumn.new()
	col.name = "RisenColumn"
	col.cfg = c
	return col


static func _v3(v: Variant, fallback: Vector3) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback


## The kit for a roll in 0..1 over the weights (pure; the tests and the director share the rule).
static func pick_kit(weights: Dictionary, roll: float) -> String:
	var total: float = 0.0
	for k: Variant in weights.keys():
		total += float(weights[k])
	var r: float = roll * maxf(total, 0.0001)
	for k2: Variant in weights.keys():
		r -= float(weights[k2])
		if r <= 0.0:
			return str(k2)
	return str(weights.keys().back()) if not weights.is_empty() else "soviet"


func _ready() -> void:
	_rng.seed = int(cfg.get("seed", 1944))
	_a = _v3(cfg.get("from", Vector3(10, 0, 0)), Vector3(10, 0, 0))
	_b = _v3(cfg.get("to", Vector3(-10, 0, 0)), Vector3(-10, 0, 0))
	build()


## Builds (or rebuilds) the bodies.
func build() -> void:
	for z: Node3D in bodies:
		z.queue_free()
	bodies.clear()
	_state.clear()
	_asleep = false   # (new bodies' animation players start running: the next unseen frame rests them again)
	_unseen_dt = 0.0
	ZombieBody.ensure_globals()
	var n: int = maxi(0, int(cfg.get("count", 8)))
	var sp: Array = cfg.get("speed", [0.55, 0.8])
	var kits: Dictionary = cfg.get("kits", DEFAULT_KITS)
	for i: int in n:
		var kit: String = pick_kit(kits, _rng.randf())
		var kd: Dictionary = (GLData.table("anim")["kits"] as Dictionary).get(kit, {})
		var builds: Array = kd.get("builds", ["medium"])
		var build_id: String = str(builds[_rng.randi() % builds.size()])
		var female: bool = _rng.randf() < float(kd.get("female", 0.0))
		var z: Node3D = body(kit, build_id, female, CLIPS[_rng.randi() % CLIPS.size()], 7700 + i, _rng, bool(cfg.get("shadows", false)), float(cfg.get("visible_m", 0.0)))
		add_child(z)
		var speed: float = _rng.randf_range(float(sp[0]), float(sp[1]))
		(z.get_node("AP") as AnimationPlayer).speed_scale = speed / CLIP_SPEED
		_state.append({"k": float(i) / float(maxi(1, n)) + _rng.randf_range(-0.02, 0.02), "speed": speed,
			"side": _rng.randf_range(-1.0, 1.0) * float(cfg.get("width", 2.5)), "phase": _rng.randf() * TAU, "fade": -1.0})
		bodies.append(z)
	_place_all(0.0)


## One presentation body of the Returned: the rig, the skinned Soviet kit, its wound, a hat from the kit's
## gear_one_of, and an AnimationPlayer on `clip` (root motion stripped). Static so the menu and cutscenes can make
## single ones.
static func body(kit: String, build_id: String, female: bool, clip: String, seed_id: int, rng: RandomNumberGenerator,
		shadows: bool = false, visible_m: float = 0.0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Returned_%s" % kit
	root.set_meta("kit", kit)
	var skel: Skeleton3D = ZombieRig.build_skeleton()
	skel.name = "Skel"
	root.add_child(skel)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = ZombieBody.build_skinned(kit, build_id, female)
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = skel.create_skin_from_rest_transforms()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if visible_m > 0.0:
		mi.visibility_range_end = visible_m
	var kd: Dictionary = (GLData.table("anim")["kits"] as Dictionary).get(kit, {})
	var fr: Array = kd.get("frost", [0.4, 0.8])
	mi.set_instance_shader_parameter("inst_frost", rng.randf_range(float(fr[0]), float(fr[1])))
	mi.set_instance_shader_parameter("inst_dirt", rng.randf_range(0.3, 0.7))
	# the wound it died of (the same site rule as the game's bodies)
	var site: StringName = ZombieBody.wound_site_for(seed_id, kit)
	if site != &"":
		var ws: Array = ZombieBody.WOUND_SITES[site]
		var att: BoneAttachment3D = BoneAttachment3D.new()
		att.bone_name = str(ws[0])
		skel.add_child(att)
		var w: MeshInstance3D = MeshInstance3D.new()
		w.name = "Wound"
		w.mesh = ZombieBody.wound_mesh()
		w.position = ws[1]
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if visible_m > 0.0:
			w.visibility_range_end = visible_m * 0.5
		att.add_child(w)
		root.set_meta("wound_site", site)
	var one_of: Dictionary = kd.get("gear_one_of", {})
	var roll: float = rng.randf()
	for piece: String in one_of.keys():
		roll -= float(one_of[piece])
		if roll < 0.0:
			var spec: Array = ZombieBody.gear_mesh(piece, female)
			var gat: BoneAttachment3D = BoneAttachment3D.new()
			gat.bone_name = str(spec[0])
			skel.add_child(gat)
			var g: MeshInstance3D = MeshInstance3D.new()
			g.name = "Gear_" + piece
			g.mesh = spec[1]
			g.cast_shadow = mi.cast_shadow
			if visible_m > 0.0:
				g.visibility_range_end = visible_m
			gat.add_child(g)
			break
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AP"
	ap.root_node = NodePath("..")
	ap.add_animation_library(&"", clip_library())
	root.add_child(ap)
	if ap.has_animation(clip):
		ap.play(clip)
		ap.seek(rng.randf_range(0.0, ap.current_animation_length), true)
	return root


## The shamble clips only, generated from anim.json without root motion, looping (shared by every column).
static func clip_library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	if ZombieClips._bones.is_empty():
		ZombieClips._bones = ZombieRig.bone_names()
	for n: String in CLIPS:
		if not ZombieClips.all_clip_names().has(n):
			continue
		var src: Animation = ZombieClips._lib.get_animation(n) if ZombieClips._lib != null and ZombieClips._lib.has_animation(n) else ZombieClips.generate(n)
		var a: Animation = src.duplicate(true) as Animation
		var root_t: int = a.find_track(NodePath("Skel:Root"), Animation.TYPE_POSITION_3D)
		if root_t >= 0:
			a.remove_track(root_t)
		a.loop_mode = Animation.LOOP_LINEAR
		_lib.add_animation(n, a)
	return _lib


## T-265: a column the camera does not look toward stands still: its walkers are not placed and their animation
## players do not run (a dozen skinned bodies animated every frame of the match, on Map 0, wherever the player
## was looking, the cellar included). The time it was not looked at is handed to the first frame it is: every
## walker is then where it would have walked to. No camera (a headless run): as before.
var _unseen_dt: float = 0.0
var _asleep: bool = false
## Frames placed / frames slept (the measuring tools).
var placed_frames: int = 0
var slept_frames: int = 0


func _process(delta: float) -> void:
	if paused or bodies.is_empty():
		return
	if Zombie.view_lod and is_inside_tree() and Zombie.view_camera(get_viewport()) and _unseen():
		_unseen_dt += delta
		slept_frames += 1
		if not _asleep:
			_asleep = true
			_run_players(false)
		return
	if _asleep:
		_asleep = false
		_run_players(true)
	placed_frames += 1
	_place_all(delta + _unseen_dt)
	_unseen_dt = 0.0


## Is the whole lane from `from` to `to` outside the camera's view? The walkers are spread along all of it, so it
## is looked at as LANE_BALLS balls in a row (each a stretch of the line, the lane's width and a body's height).
const LANE_BALLS: int = 8


func _unseen() -> bool:
	return lane_unseen(to_global(_a) - Zombie.vl_pos, to_global(_b) - Zombie.vl_pos, float(cfg.get("width", 2.5)) + 3.0, Zombie.vl_fwd, Zombie.vl_cos)


## Pure: the line from `a` to `b` (both from the camera), `pad` wide, is wholly outside the view cone.
static func lane_unseen(a: Vector3, b: Vector3, pad: float, fwd: Vector3, cone_cos: float, balls: int = LANE_BALLS) -> bool:
	var r: float = a.distance_to(b) / float(2 * balls) + pad
	for i: int in balls:
		if not Zombie.sphere_out_of_view(a.lerp(b, (float(i) + 0.5) / float(balls)), r, fwd, cone_cos):
			return false
	return true


func _run_players(on: bool) -> void:
	for z: Node3D in bodies:
		var ap: AnimationPlayer = z.get_node_or_null(^"AP") as AnimationPlayer
		if ap != null:
			ap.active = on


func _place_all(delta: float) -> void:
	var length: float = maxf(1.0, _a.distance_to(_b))
	var dir: Vector3 = (_b - _a).normalized()
	var side_dir: Vector3 = dir.cross(Vector3.UP).normalized()
	var fade_k: float = float(cfg.get("fade", 0.06))
	var loop_on: bool = bool(cfg.get("loop", true))
	var terrain: bool = str(cfg.get("ground", "flat")) == "terrain"
	for i: int in bodies.size():
		var z: Node3D = bodies[i]
		var st: Dictionary = _state[i]
		var k: float = float(st["k"]) + float(st["speed"]) * delta / length
		if k >= 1.0:
			if loop_on:
				loops += int(k)   # (more than one lap when the column was not looked at for long: T-265)
				k = fposmod(k, 1.0)
			else:
				k = 1.0
		st["k"] = k
		var p: Vector3 = _a.lerp(_b, clampf(k, 0.0, 1.0)) + side_dir * (float(st["side"]) + sin(k * 11.0 + float(st["phase"])) * 0.3)
		if terrain:
			p.y = LandscapeTerrain.height(p.x, p.z)   # (the column sits at the map's origin: from / to are map points)
		z.position = p
		z.rotation.y = atan2(-dir.x, -dir.z) + sin(k * 7.0 + float(st["phase"])) * 0.08
		var fade: float = 0.0
		if fade_k > 0.0:
			fade = clampf((k - (1.0 - fade_k)) / fade_k, 0.0, 1.0) + clampf((fade_k * 0.5 - k) / (fade_k * 0.5), 0.0, 1.0)
		if absf(fade - float(st["fade"])) > 0.01:
			st["fade"] = fade
			(z.get_node("Skel/Body") as MeshInstance3D).set_instance_shader_parameter("inst_dissolve", fade)
			z.visible = fade < 0.99
