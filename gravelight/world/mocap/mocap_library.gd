class_name MocapLibrary
extends RefCounted
## UPDATE 12 section 4 (T-210): the phone-mocap clips for the in-engine cutscenes. tools/mocap.sh build writes one
## AnimationLibrary per cutscene to res://assets/ours/mocap/<scene>/mocap_<scene>.res, its animations named
## "<shot>_<role>" (data/gravelight/mocap/shots.json: gravelight_one/shot_04_seat1, cancel_ending/last_wren), each a
## position track on Skeleton3D:Hips and a rotation track per driven ZombieRig bone, in the skeleton's own units (the
## rig at scale 1; PersonRig scales the skeleton by the person's height). `clip()` is the lookup MocapStage uses on
## every shot: no library or no clip = null, and the stand-in keeps its procedural animation. Pure data + cache.

const DIR: String = "res://assets/ours/mocap"
const TRACK_NODE: String = "Skeleton3D"

## Off (tests, the --no-mocap tool flag): every lookup misses, so every shot plays its stand-in animation.
static var enabled: bool = true
## A test can point the lookup at its own libraries: scene id -> AnimationLibrary (wins over the files).
static var overrides: Dictionary = {}
static var _libs: Dictionary = {}


static func path_of(scene: String) -> String:
	return "%s/%s/mocap_%s.res" % [DIR, scene, scene]


## The scene's library, or null (cached, misses too).
static func library(scene: String) -> AnimationLibrary:
	if not enabled or scene == "":
		return null
	if overrides.has(scene):
		return overrides[scene] as AnimationLibrary
	if _libs.has(scene):
		return _libs[scene] as AnimationLibrary
	var lib: AnimationLibrary = null
	var p: String = path_of(scene)
	if ResourceLoader.exists(p):
		lib = load(p) as AnimationLibrary
	_libs[scene] = lib
	return lib


static func reload() -> void:
	_libs.clear()


## The first clip found for `roles` (a character id, then its seat / slot, then "any"), or null.
static func clip(scene: String, shot: String, roles: Array) -> Animation:
	var lib: AnimationLibrary = library(scene)
	if lib == null:
		return null
	for r: Variant in roles:
		var n: StringName = StringName("%s_%s" % [shot, str(r)])
		if lib.has_animation(n):
			return lib.get_animation(n)
	return null


## A clip JSON (tools/mocap/mocaplib.write_clip: fps, length, bones, hips [[x, y, z]...], rot {bone: [[x, y, z, w]...]},
## root, stats, source) as an Animation. tools/mocap/mocap_import.gd saves these into the scene's library.
static func animation_from_clip(d: Dictionary) -> Animation:
	var a: Animation = Animation.new()
	var fps: float = maxf(1.0, float(d.get("fps", 30.0)))
	var hips: Array = d.get("hips", [])
	var n: int = hips.size()
	a.length = maxf(1.0 / fps, float(n - 1) / fps)
	a.loop_mode = Animation.LOOP_NONE
	a.step = 1.0 / fps
	var tp: int = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tp, NodePath("%s:Hips" % TRACK_NODE))
	for i: int in n:
		var h: Array = hips[i]
		a.position_track_insert_key(tp, float(i) / fps, Vector3(float(h[0]), float(h[1]), float(h[2])))
	var rot: Dictionary = d.get("rot", {})
	for b: Variant in d.get("bones", rot.keys()):
		var keys: Array = rot.get(b, [])
		if keys.is_empty():
			continue
		var tr: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, NodePath("%s:%s" % [TRACK_NODE, str(b)]))
		for i2: int in keys.size():
			var q: Array = keys[i2]
			a.rotation_track_insert_key(tr, float(i2) / fps, Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized())
	a.set_meta(&"root", str(d.get("root", "mocap")))
	a.set_meta(&"source", str(d.get("source", "")))
	a.set_meta(&"stats", d.get("stats", {}))
	return a


## The bone each track of a clip drives: {track index: bone name} (Hips' position track included).
static func tracks_of(a: Animation) -> Dictionary:
	var out: Dictionary = {}
	for i: int in a.get_track_count():
		var p: NodePath = a.track_get_path(i)
		if p.get_subname_count() > 0:
			out[i] = str(p.get_concatenated_subnames())
	return out
