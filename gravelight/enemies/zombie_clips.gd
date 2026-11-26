class_name ZombieClips
extends RefCounted
## Shared AnimationTree and cached legacy / licensed motion library (ZOMBIE_ANIM_SPEC §1-§4, T-041).
## Existing pose functions are retained as fallback. Owner-supplied mco_ clips are imported from GLB;
## tools/blender/zombie_anim_batch.py retargets them offline onto the same ZombieRig.
## Locomotion clips carry root motion on the Root bone (forward = -Z) whose speed at time scale 1 equals the
## tier speed. Zombie matches playback to nav velocity; foot planting needs contact checks too.
##
## Tree layout (one per zombie, graph duplicated per instance so clip picks are per zombie):
##   SM (state machine: Spawn / Emerge / Climb / Barricade / Locomotion / Attack / React / Crawl / Death)
##   -> Posture (Add2, the trait pose)  -> Flinch (OneShot, additive, the directional flinch) -> output
## Each state is a nested blend tree "Anim -> TimeScale": Locomotion's Anim is a BlendSpace2D (speed x turn),
## Attack's and Crawl's a BlendSpace1D (variant / speed), the rest an Animation node whose clip is set per use.

const STATES: PackedStringArray = ["Spawn", "Emerge", "Climb", "Barricade", "Locomotion", "Attack", "React", "Crawl", "Death", "Turn"]
const FORWARD: Vector3 = Vector3(0, 0, -1)
const ATTACK_WINDUP: float = 0.45     # the baked attack timing; Zombie rescales it to its attack_windup
const ATTACK_SWING: float = 0.35
const TEAR_CYCLE: float = 1.2         # baked tear cycle; rescaled to the tear interval
const DEATH_SECONDS: float = 1.3
const MocapBank: GDScript = preload("res://gravelight/enemies/zombie_mocap.gd")

static var _lib: AnimationLibrary = null
static var _lengths: Dictionary = {}
static var _cfg: Dictionary = {}
static var _bones: PackedStringArray = []
static var _mocap: RefCounted
static var _contact_events: Dictionary = {}
static var _user_args: PackedStringArray = []
static var _user_args_read: bool = false


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.table("anim")
	return _cfg


## The shared library with every clip anim.json names, generated on first use.
static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_bones = ZombieRig.bone_names()
	_lib = AnimationLibrary.new()
	for n: String in all_clip_names():
		_lib.add_animation(n, generate(n))
	# lean-into-turn variants of every walking gait (the Locomotion blend space's side points)
	var loco: Dictionary = cfg()["clips"]["locomotion"]
	for g: String in loco.keys():
		if g == "crawl":
			continue
		for n2: String in loco[g]:
			_lib.add_animation(n2 + "_lean_l", generate(n2 + "_lean_l"))
			_lib.add_animation(n2 + "_lean_r", generate(n2 + "_lean_r"))
	_lib.add_animation("posture_none", generate("posture_none"))
	_mocap = MocapBank.new()
	_mocap.load_bank()
	for name: String in _mocap.animations:
		var clip: Animation = _mocap.animations[name]
		_lib.add_animation(name, clip)
		_lengths[name] = clip.length
	return _lib


static func mocap_info() -> Dictionary:
	library()
	return {"loaded": _mocap.metadata.keys(), "errors": _mocap.errors, "runtime_enabled": mocap_enabled()}


## The command line cannot change while the game runs: read once (these checks run per zombie per tick).
static func _user_flag(flag: String) -> bool:
	if not _user_args_read:
		_user_args = OS.get_cmdline_user_args()
		_user_args_read = true
	return flag in _user_args


static func mocap_enabled() -> bool:
	library()
	return bool(_mocap.config.get("runtime_enabled", false)) and not _user_flag("--legacy-zombies")


## A fresh checkout without the licensed local files retains the existing playable fallback.
static func locomotion_clips(tier: String) -> Array:
	library()
	var candidates: Array = _mocap.config.get("locomotion", {}).get(tier, []) if mocap_enabled() else []
	var ready: Array = candidates.filter(func(n: String) -> bool: return _mocap.animations.has(n))
	return ready if not ready.is_empty() else cfg()["clips"]["locomotion"][tier]


static func idle_clips() -> Array:
	library()
	var candidates: Array = _mocap.config.get("idle", []) if mocap_enabled() else []
	var ready: Array = candidates.filter(func(n: String) -> bool: return _mocap.animations.has(n))
	return ready if not ready.is_empty() else [cfg()["clips"]["idle"]]


static func stride_speed(clip: String, tier: String) -> float:
	library()
	return float(_mocap.metadata[clip]["speed_mps"]) if _mocap.metadata.has(clip) else float(cfg()["gait"][tier]["speed"])


static func contact_windows(clip: String) -> Dictionary:
	library()
	return _mocap.metadata.get(clip, {}).get("contact_windows", {})


static func contact_lock_config() -> Dictionary:
	library()
	return _mocap.config.get("contact_lock", {})


## Keep gameplay names/indices stable, swapping only the reviewed visual performance.
static func visual_clip(legacy: String) -> String:
	library()
	if not mocap_enabled(): return legacy
	var candidate: String = str(_mocap.config.get("visual_aliases", {}).get(legacy, legacy))
	if Zombie.t284_terror:
		# T-284: recorded takes promoted for the scare (zombie_mocap.json terror_aliases), e.g. the barricade queue reaching
		var t: String = str(_mocap.config.get("terror_aliases", {}).get(legacy, ""))
		if t != "" and _mocap.animations.has(t):
			return t
	return candidate if _mocap.animations.has(candidate) else legacy


static func hit_event_time(clip: String) -> float:
	library()
	return float(_mocap.metadata.get(visual_clip(clip), {}).get("events", {}).get("hit", -1.0))


static func death_key_pose_time(clip: String) -> float:
	library()
	return float(_mocap.config.get("death_key_pose_seconds", {}).get(visual_clip(clip), cfg()["ragdoll"]["key_pose_seconds"]))


static func death_motion_config() -> Dictionary:
	library()
	return _mocap.config.get("death_motion", {})


static func turn_config() -> Dictionary:
	library()
	return _mocap.config.get("turn", {})


static func recorded_turns_enabled() -> bool:
	var c: Dictionary = turn_config()
	return mocap_enabled() and bool(c.get("enabled", false)) and not _user_flag("--legacy-zombie-turns") and _mocap.metadata.get(c.get("left", ""), {}).has("root_yaw") and _mocap.metadata.get(c.get("right", ""), {}).has("root_yaw")


static func turn_progress(clip: String, seconds: float) -> float:
	var curve: Array = _mocap.metadata.get(clip, {}).get("root_yaw", {}).get("radians", [])
	if curve.size() < 2 or absf(float(curve.back())) < 0.001: return 0.0
	var at: float = clampf(seconds / length_of(clip), 0.0, 1.0) * float(curve.size() - 1)
	var i: int = int(at)
	return lerpf(float(curve[i]), float(curve[mini(i + 1, curve.size() - 1)]), at - float(i)) / float(curve.back())


## Recorded loops may contain several strides. Events are source contact onsets, not even halves.
static func footstep_events(clip: String) -> Array:
	if _contact_events.has(clip): return _contact_events[clip]
	var windows: Dictionary = contact_windows(clip)
	var events: Array = []
	if windows.is_empty():
		events = [{"phase": 0.0, "left": true}, {"phase": 0.5, "left": false}]
	else:
		var duration: float = length_of(clip)
		for side: String in windows:
			var intervals: Array = windows[side]
			for interval: Array in intervals:
				var start: float = float(interval[0])
				# A stance continuing across the seam has only its original onset event.
				if start < 0.0001 and float(intervals.back()[1]) >= duration - 0.0001: continue
				events.append({"phase": start / duration, "left": side == "Left"})
		events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["phase"]) < float(b["phase"]))
	_contact_events[clip] = events
	return events


static func crossed_phase(previous: float, current: float, event: float) -> bool:
	return (event > previous and event <= current) if current >= previous else (event > previous or event <= current)


static func length_of(clip: String) -> float:
	library()
	return float(_lengths.get(clip, 1.0))


static func has_clip(clip: String) -> bool:
	return library().has_animation(clip)


## Every clip name reachable from anim.json "clips".
static func all_clip_names() -> PackedStringArray:
	var out: PackedStringArray = []
	_collect(cfg()["clips"], out)
	return out


static func _collect(v: Variant, out: PackedStringArray) -> void:
	if v is String:
		if not out.has(v):
			out.append(v)
	elif v is Array:
		for e: Variant in v:
			_collect(e, out)
	elif v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			if str(k) == "_doc":
				continue
			_collect((v as Dictionary)[k], out)


# ================================================================== tree

## Builds a zombie's AnimationTree graph. Returns the root blend tree; parameters are addressed as
## "parameters/SM/<State>/TimeScale/scale", "parameters/SM/Locomotion/Anim/blend_position", "parameters/Posture/add_amount",
## "parameters/Flinch/request".
static func build_tree_root() -> AnimationNodeBlendTree:
	var xf: Dictionary = cfg()["xfade"]
	var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var sm: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	sm.allow_transition_to_self = true
	for s: String in STATES:
		sm.add_node(s, _state_tree(s), Vector2(200 * (STATES.find(s) % 5), 150 * (STATES.find(s) / 5)))
	# Start -> Spawn, and every state reaches every other (travel picks the direct edge).
	var st: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	st.xfade_time = 0.0
	sm.add_transition("Start", "Spawn", st)
	for a: String in STATES:
		for b: String in STATES:
			if a == b:
				continue   # allow_transition_to_self covers re-entry
			var tr: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
			tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			# locomotion resumes where it left off (every zombie keeps its own stride phase); one-shots restart
			tr.reset = not (b == "Locomotion" or b == "Crawl")
			var key: String = b.to_lower()
			if b == "Locomotion" or b == "Crawl":
				key = "locomotion"
			elif b == "Attack":
				key = "attack"
			elif b == "React":
				key = "react"
			elif b == "Death":
				key = "death"
			elif b == "Emerge" or b == "Spawn":
				key = "emerge"
			tr.xfade_time = float(xf.get(key, xf.get("default", 0.15)))
			sm.add_transition(a, b, tr)
	root.add_node("SM", sm, Vector2(0, 0))
	var posture_anim: AnimationNodeAnimation = AnimationNodeAnimation.new()
	posture_anim.animation = &"posture_none"
	root.add_node("PostureAnim", posture_anim, Vector2(0, 200))
	var add: AnimationNodeAdd2 = AnimationNodeAdd2.new()
	root.add_node("Posture", add, Vector2(300, 0))
	root.connect_node("Posture", 0, "SM")
	root.connect_node("Posture", 1, "PostureAnim")
	var flinch_anim: AnimationNodeAnimation = AnimationNodeAnimation.new()
	flinch_anim.animation = &"flinch_torso"
	root.add_node("FlinchAnim", flinch_anim, Vector2(300, 200))
	var shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	shot.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
	var fl: Dictionary = cfg()["flinch"]
	shot.fadein_time = float(fl.get("fade_in", 0.04))
	shot.fadeout_time = float(fl.get("seconds", 0.25)) * 0.6
	root.add_node("Flinch", shot, Vector2(600, 0))
	root.connect_node("Flinch", 0, "Posture")
	root.connect_node("Flinch", 1, "FlinchAnim")
	root.connect_node("output", 0, "Flinch")
	return root


static func _state_tree(state: String) -> AnimationNodeBlendTree:
	var bt: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var anim: AnimationNode
	match state:
		"Locomotion":
			var bs: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
			bs.min_space = Vector2(0, -1)
			bs.max_space = Vector2(1, 1)
			bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
			bs.auto_triangles = true
			bs.sync = true
			# 0 idle, 1 gait, 2 gait lean L, 3 gait lean R, 4 turn L, 5 turn R
			bs.add_blend_point(_anim_node("idle"), Vector2(0, 0), -1, &"idle")
			bs.add_blend_point(_anim_node("walk_a"), Vector2(1, 0), -1, &"gait")
			bs.add_blend_point(_anim_node("walk_a"), Vector2(1, -1), -1, &"gait_lean_l")
			bs.add_blend_point(_anim_node("walk_a"), Vector2(1, 1), -1, &"gait_lean_r")
			bs.add_blend_point(_anim_node("turn_l"), Vector2(0, -1), -1, &"turn_l")
			bs.add_blend_point(_anim_node("turn_r"), Vector2(0, 1), -1, &"turn_r")
			anim = bs
		"Crawl":
			var bs1: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
			bs1.min_space = 0.0
			bs1.max_space = 1.0
			bs1.sync = true
			bs1.add_blend_point(_anim_node("crawl_idle"), 0.0, -1, &"crawl_idle")
			bs1.add_blend_point(_anim_node("crawl_drag"), 1.0, -1, &"crawl")
			anim = bs1
		"Attack":
			var bsa: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
			var names: Array = (cfg()["clips"]["attack"]["swipe"] as Array).duplicate()
			var ad: Dictionary = cfg()["clips"]["attack"]
			for k: String in ["lunge", "grab", "bite", "headbutt", "window"]:
				names.append(str(ad[k]))
			bsa.min_space = 0.0
			bsa.max_space = float(names.size() - 1)
			bsa.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_DISCRETE
			for i: int in names.size():
				bsa.add_blend_point(_anim_node(str(names[i])), float(i), -1, StringName(str(names[i])))
			anim = bsa
		_:
			var defaults: Dictionary = {"Spawn": "idle", "Emerge": "emerge_standard", "Climb": "vault_a", "Barricade": "tear_rip", "React": "stagger", "Death": "death_back", "Turn": "idle"}
			anim = _anim_node(str(defaults[state]))
	bt.add_node("Anim", anim, Vector2(0, 0))
	var seek: AnimationNodeTimeSeek = AnimationNodeTimeSeek.new()
	bt.add_node("TimeSeek", seek, Vector2(125, 0))
	bt.connect_node("TimeSeek", 0, "Anim")
	var ts: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	bt.add_node("TimeScale", ts, Vector2(250, 0))
	bt.connect_node("TimeScale", 0, "TimeSeek")
	bt.connect_node("output", 0, "TimeScale")
	return bt


static func _anim_node(clip: String) -> AnimationNodeAnimation:
	var n: AnimationNodeAnimation = AnimationNodeAnimation.new()
	n.animation = StringName(visual_clip(clip))
	return n


## Index of an attack clip in the Attack blend space (its blend position).
static func attack_index(clip: String) -> float:
	var names: Array = (cfg()["clips"]["attack"]["swipe"] as Array).duplicate()
	var ad: Dictionary = cfg()["clips"]["attack"]
	for k: String in ["lunge", "grab", "bite", "headbutt", "window"]:
		names.append(str(ad[k]))
	return float(maxi(0, names.find(clip)))


# ================================================================== baking

## Generates one clip by name. Looping gaits carry root motion; one-shots hold their last key.
static func generate(clip: String) -> Animation:
	var hz: float = float(cfg()["skeleton"].get("sample_hz", 30))
	var loco: Dictionary = cfg()["clips"]["locomotion"]
	var lean_dir: float = 0.0
	var base_clip: String = clip
	if clip.ends_with("_lean_l"):
		lean_dir = -1.0
		base_clip = clip.trim_suffix("_lean_l")
	elif clip.ends_with("_lean_r"):
		lean_dir = 1.0
		base_clip = clip.trim_suffix("_lean_r")
	var gait: String = ""
	for g: String in loco.keys():
		if (loco[g] as Array).has(base_clip):
			gait = g
	var a: Animation = Animation.new()
	var length: float
	var looping: bool = true
	var sampler: Callable
	if gait != "" and gait != "crawl":
		var gp: Dictionary = cfg()["gait"][gait]
		var speed: float = float(gp["speed"])
		length = 2.0 * float(gp["stride"]) / speed
		var v: Dictionary = cfg()["clip_variants"].get(base_clip, {})
		var lean_amt: float = float((cfg()["turn"]["lean_tiers"] as Dictionary).get(gait, 0.1))
		sampler = func(t: float) -> Dictionary:
			var p: Dictionary = _gait_pose(gp, v, TAU * t / length, t)
			if lean_dir != 0.0:
				# lean into the turn: the spine rolls and the hips yaw toward the inside of the curve
				p["Chest"] = (p["Chest"] as Vector3) + Vector3(0, -lean_dir * 0.1, -lean_dir * lean_amt * 1.6)
				p["Spine"] = (p["Spine"] as Vector3) + Vector3(0, 0, -lean_dir * lean_amt)
				p["Hips"] = (p["Hips"] as Vector3) + Vector3(0, -lean_dir * 0.08, -lean_dir * lean_amt * 0.5)
				p["Head"] = (p["Head"] as Vector3) + Vector3(0, -lean_dir * 0.15, lean_dir * lean_amt * 0.6)
			p["root"] = FORWARD * speed * t
			return p
	elif gait == "crawl":
		var cp: Dictionary = cfg()["gait"]["crawl"]
		var cspeed: float = float(cp["speed"])
		length = 2.0 * float(cp["stride"]) / cspeed
		var mode: String = str((cfg()["clip_variants"].get(clip, {}) as Dictionary).get("mode", "drag"))
		sampler = func(t: float) -> Dictionary:
			var p: Dictionary = _crawl_pose(mode, TAU * t / length, true)
			p["root"] = FORWARD * cspeed * t
			return p
	elif clip.begins_with("posture_") or (cfg()["clips"]["postures"] as Array).has(clip):
		length = 0.2
		sampler = func(_t: float) -> Dictionary: return _posture_pose(clip.trim_prefix("posture_"))
	elif clip.begins_with("flinch_"):
		length = float(cfg()["flinch"].get("seconds", 0.25))
		looping = false
		sampler = func(t: float) -> Dictionary: return _flinch_pose(clip.trim_prefix("flinch_"), t / length)
	else:
		looping = clip in ["idle", "crawl_idle", "window_wait", "climb_loop", "turn_l", "turn_r"]
		length = _oneshot_length(clip)
		sampler = func(t: float) -> Dictionary: return _oneshot_pose(clip, t, length)
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	var steps: int = maxi(2, int(ceil(length * hz)) + 1)
	var tracks: Dictionary = {}
	for b: String in _bones:
		var ti: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(ti, NodePath("Skel:" + b))
		a.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		tracks[b] = ti
	var hips_pos: int = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(hips_pos, NodePath("Skel:Hips"))
	var root_pos: int = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(root_pos, NodePath("Skel:Root"))
	var hips_rest: Vector3 = ZombieRig.rest_offset("Hips")
	for i: int in steps:
		var t: float = minf(length, float(i) / hz)
		if i == steps - 1:
			t = length
		var pose: Dictionary = sampler.call(t)
		for b: String in _bones:
			var e: Vector3 = pose.get(b, Vector3.ZERO)
			a.rotation_track_insert_key(tracks[b], t, Quaternion.from_euler(e))
		a.position_track_insert_key(hips_pos, t, hips_rest + (pose.get("hips_pos", Vector3.ZERO) as Vector3))
		a.position_track_insert_key(root_pos, t, pose.get("root", Vector3.ZERO) as Vector3)
	_lengths[clip] = length
	return a


static func _oneshot_length(clip: String) -> float:
	var c: Dictionary = cfg()
	if clip.begins_with("swipe") or clip in ["lunge", "grab", "crawl_bite", "headbutt", "window_swipe"]:
		return ATTACK_WINDUP + ATTACK_SWING
	if clip.begins_with("tear_"):
		return TEAR_CYCLE
	if clip.begins_with("death"):
		return DEATH_SECONDS
	if ZombieEmerge.is_ground_clip(clip):
		return ZombieEmerge.variant_seconds(ZombieEmerge.variant_of_clip(clip))   # the rise from the ground (T-085)
	match clip:
		"idle", "crawl_idle", "window_wait":
			return 2.4
		"turn_l", "turn_r":
			return 0.8
		"vault_a", "vault_b":
			return 1.1
		"drop_down":
			return 0.9
		"emerge_portal":
			return float(c["emerge"]["portal_seconds"])
		"emerge_ceiling":
			return float(c["emerge"]["ceiling_seconds"])
		"emerge_wade":
			return float(c["emerge"]["water_seconds"])
		"climb_loop":
			return 1.0
		"climb_mantle":
			return float(c["climb"]["mantle_seconds"])
		"stagger":
			return 0.45
		"knockdown_front", "knockdown_back":
			return float(c["knockdown"]["down_seconds"])
		"getup_front", "getup_back":
			return float(c["knockdown"]["getup_seconds"])
		"fall_crawl":
			return 0.7
	return 1.0


# ================================================================== pose helpers

static func _lerp(a: Vector3, b: Vector3, k: float) -> Vector3:
	return a.lerp(b, clampf(k, 0.0, 1.0))


static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Rest pose with the standing defaults (arms hang with a slight bend, head a little forward).
static func _rest() -> Dictionary:
	return {
		"Head": Vector3(0.15, 0, 0), "Jaw": Vector3(0.12, 0, 0),
		"LeftUpperArm": Vector3(1.0, 0, -0.08), "RightUpperArm": Vector3(1.0, 0, 0.08),
		"LeftLowerArm": Vector3(0.3, 0, 0), "RightLowerArm": Vector3(0.3, 0, 0),
		"LeftLowerLeg": Vector3(-0.06, 0, 0), "RightLowerLeg": Vector3(-0.06, 0, 0),
		"hips_pos": Vector3.ZERO,
	}


## Tilts the whole body about the point on the ground under the hips (a fall). pitch > 0 = backward.
static func _body_tilt(p: Dictionary, pitch: float, roll: float, yaw: float, lift: float = 0.0) -> void:
	var hips_rest: Vector3 = ZombieRig.rest_offset("Hips")
	var b: Basis = Basis.from_euler(Vector3(pitch, yaw, roll))
	p["Hips"] = Vector3(pitch, yaw, roll) + (p.get("Hips", Vector3.ZERO) as Vector3)
	p["hips_pos"] = (b * hips_rest) - hips_rest + Vector3(0, lift, 0) + (p.get("hips_pos", Vector3.ZERO) as Vector3)


static func _gait_pose(g: Dictionary, v: Dictionary, p: float, t: float) -> Dictionary:
	var r: Dictionary = _rest()
	var hip_a: float = float(g["hip"]) * float(v.get("hip", 1.0))
	var knee_a: float = float(g["knee"])
	var lean: float = float(g["lean"]) + float(v.get("stoop", 0.0))
	var bob: float = float(g["bob"])
	var mode: int = int(g["arms"])
	var sway: float = float(v.get("sway", 0.06))
	var swing: float = float(v.get("arm_swing", 0.2))
	var tl: float = sin(p) * hip_a
	var tr: float = sin(p + PI) * hip_a
	var kl: float = -knee_a * maxf(0.0, cos(p)) - 0.08
	var kr: float = -knee_a * maxf(0.0, cos(p + PI)) - 0.08
	if int(v.get("drag", 0)) == 1:
		kr *= 0.25
	var hips_roll: float = sin(p) * sway
	var hips_y: float = -bob * (0.5 + 0.5 * cos(2.0 * p))
	var ch_y: float = sin(p) * 0.12
	var ch_z: float = -sin(p) * sway * 0.8
	var sl: Vector3 = Vector3(1.0, 0, -0.08)
	var sr: Vector3 = Vector3(1.0, 0, 0.08)
	var el: float = 0.3
	var er: float = 0.3
	var hd_x: float = 0.15 + float(v.get("head", 0.0))
	var hd_z: float = 0.0
	var jaw: float = 0.2
	var up: float = float(v.get("arms_up", 0.0))
	match mode:
		0:
			sl.x = 0.55 + sin(p) * swing
			sr.x = 0.45 - sin(p) * swing
			el = 0.35
			er = 0.25
		1:
			sl.x = 1.25 + up + sin(p * 0.5 + 1.0) * swing
			sr.x = 1.2 + up - sin(p * 0.5) * swing
			el = 0.3
			er = 0.4
		2:
			sl.x = 1.3 + up + sin(p) * swing
			sr.x = 1.3 + up - sin(p) * swing
			el = 0.75
			er = 0.75
		3:
			sl.x = 1.5 + up + sin(p) * swing
			sr.x = 1.5 + up - sin(p) * swing
			el = 0.95
			er = 0.95
			hd_x -= 0.15
		4:
			var fl: float = float(v.get("flail", 1.0))
			sl.x = 1.4 + sin(p * 1.7) * swing
			sr.x = 1.4 + sin(p * 1.7 + 2.1) * swing
			sl.z = -0.3 + sin(p * 2.3) * 0.3 * fl
			sr.z = 0.3 + sin(p * 2.1) * 0.3 * fl
			el = 1.0 + sin(p * 3.1) * 0.4 * fl
			er = 1.0 + cos(p * 2.7) * 0.4 * fl
			hd_z = sin(t * 17.0) * 0.12 * fl
			jaw = 0.55
	r["Hips"] = Vector3(0, 0, hips_roll)
	r["hips_pos"] = Vector3(0, hips_y, 0)
	r["Spine"] = Vector3(-lean * 0.35, ch_y * 0.4, ch_z * 0.5)
	r["Chest"] = Vector3(-lean * 0.65, ch_y, ch_z)
	r["Neck"] = Vector3(lean * 0.55, 0, 0)
	r["Head"] = Vector3(hd_x, 0, hd_z)
	r["Jaw"] = Vector3(jaw * 0.6, 0, 0)
	r["LeftUpperLeg"] = Vector3(tl, 0, 0.03)
	r["RightUpperLeg"] = Vector3(tr, 0, -0.03)
	r["LeftLowerLeg"] = Vector3(kl, 0, 0)
	r["RightLowerLeg"] = Vector3(kr, 0, 0)
	# feet stay level with the ground through the step (counter the hip + knee), toes down on the swing
	r["LeftFoot"] = Vector3(-(tl + kl) * 0.8 - 0.1 * maxf(0.0, sin(p)), 0, 0)
	r["RightFoot"] = Vector3(-(tr + kr) * 0.8 - 0.1 * maxf(0.0, sin(p + PI)), 0, 0)
	r["LeftUpperArm"] = sl
	r["RightUpperArm"] = sr
	r["LeftLowerArm"] = Vector3(el, 0, 0)
	r["RightLowerArm"] = Vector3(er, 0, 0)
	return r


static func _idle_pose(t: float, phase: float = 0.0) -> Dictionary:
	var r: Dictionary = _rest()
	r["Hips"] = Vector3(0, 0, sin(t * 1.3 + phase) * 0.04)
	r["Spine"] = Vector3(-0.05, 0, 0)
	r["Chest"] = Vector3(-0.09 + sin(t * 0.9 + phase) * 0.04, 0, 0)
	r["Neck"] = Vector3(0.08, 0, 0)
	r["Head"] = Vector3(0.15, 0, sin(t * 0.7 + phase) * 0.08)
	r["LeftUpperArm"] = Vector3(0.95 + sin(t * 1.1) * 0.06, 0, -0.08)
	r["RightUpperArm"] = Vector3(0.9 + sin(t * 1.2 + 1.0) * 0.06, 0, 0.08)
	return r


## Crawler: the body pitched onto its belly (the thighs are hidden by the gore layer), arms pulling.
static func _crawl_pose(mode: String, p: float, moving: bool) -> Dictionary:
	var r: Dictionary = _rest()
	var c: float = sin(p) if moving else 0.0
	var scuttle: bool = mode == "scuttle"
	_body_tilt(r, -1.35, 0.0, 0.0, -0.58)
	# T-091: _body_tilt pivots at the feet (the deaths fall over them), which left the crawl pose's hips 0.38 m
	# under the floor and a metre ahead of the body (the rendered crawlers were invisible). A crawler lies on its
	# belly: hips 0.17 m up, a little behind the capsule centre so the chest and head sit over it.
	r["hips_pos"] = Vector3(0, 0.17 - ZombieRig.rest_offset("Hips").y, 0.3)
	r["Hips"] = (r["Hips"] as Vector3) + Vector3(0, 0, c * 0.1)
	r["Spine"] = Vector3(0.1, 0, 0)
	r["Chest"] = Vector3(0.15 + (c * 0.12 if scuttle else 0.0), 0, 0)
	r["Neck"] = Vector3(0.9, 0, 0)
	r["Head"] = Vector3(0.35, 0, 0)
	r["Jaw"] = Vector3(0.5, 0, 0)
	if scuttle:
		r["LeftUpperArm"] = Vector3(2.2 + c * 0.75, 0, -0.5)
		r["RightUpperArm"] = Vector3(2.2 - c * 0.75, 0, 0.5)
		r["LeftLowerArm"] = Vector3(0.2 + maxf(0.0, -c) * 1.1, 0, 0)
		r["RightLowerArm"] = Vector3(0.2 + maxf(0.0, c) * 1.1, 0, 0)
	else:
		r["LeftUpperArm"] = Vector3(2.5 + c * 0.55, 0, -0.35)
		r["RightUpperArm"] = Vector3(2.5 - c * 0.55, 0, 0.35)
		r["LeftLowerArm"] = Vector3(0.25 + maxf(0.0, -c) * 0.9, 0, 0)
		r["RightLowerArm"] = Vector3(0.25 + maxf(0.0, c) * 0.9, 0, 0)
	r["LeftUpperLeg"] = Vector3(-0.2, 0, 0.1)
	r["RightUpperLeg"] = Vector3(-0.2, 0, -0.1)
	return r


static func _posture_pose(posture: String) -> Dictionary:
	var r: Dictionary = {}
	match posture:
		"limp_l":
			r["LeftLowerLeg"] = Vector3(-0.22, 0, 0)
			r["LeftUpperLeg"] = Vector3(0.1, 0, 0.1)
			r["Hips"] = Vector3(0, 0, -0.07)
			r["Chest"] = Vector3(0, 0, 0.1)
		"limp_r":
			r["RightLowerLeg"] = Vector3(-0.22, 0, 0)
			r["RightUpperLeg"] = Vector3(0.1, 0, -0.1)
			r["Hips"] = Vector3(0, 0, 0.07)
			r["Chest"] = Vector3(0, 0, -0.1)
		"hunch":
			r["Spine"] = Vector3(-0.18, 0, 0)
			r["Chest"] = Vector3(-0.28, 0, 0)
			r["Neck"] = Vector3(0.35, 0, 0)
			r["Head"] = Vector3(0.1, 0, 0)
		"hang_arm_l":
			r["LeftUpperArm"] = Vector3(-0.9, 0.3, -0.25)
			r["LeftLowerArm"] = Vector3(-0.25, 0, 0)
			r["Chest"] = Vector3(0, 0, 0.06)
		"hang_arm_r":
			r["RightUpperArm"] = Vector3(-0.9, -0.3, 0.25)
			r["RightLowerArm"] = Vector3(-0.25, 0, 0)
			r["Chest"] = Vector3(0, 0, -0.06)
		"broken_neck":
			r["Neck"] = Vector3(0.1, 0.4, 0.55)
			r["Head"] = Vector3(-0.2, 0.3, 0.3)
		"drag_foot_l":
			r["LeftUpperLeg"] = Vector3(-0.15, 0, 0.06)
			r["LeftLowerLeg"] = Vector3(0.05, 0, 0)
			r["LeftFoot"] = Vector3(0.5, 0, 0)
		"drag_foot_r":
			r["RightUpperLeg"] = Vector3(-0.15, 0, -0.06)
			r["RightLowerLeg"] = Vector3(0.05, 0, 0)
			r["RightFoot"] = Vector3(0.5, 0, 0)
	return r


## Additive directional flinch (0..1 normalized time; a snap at 0.3 then settles back).
static func _flinch_pose(zone: String, k: float) -> Dictionary:
	var w: float = sin(clampf(k, 0.0, 1.0) * PI)
	w = w * w if k > 0.3 else w
	var r: Dictionary = {}
	match zone:
		"head":
			r["Head"] = Vector3(-0.55 * w, 0.25 * w, 0.2 * w)
			r["Neck"] = Vector3(-0.2 * w, 0, 0)
		"torso":
			r["Chest"] = Vector3(0.3 * w, 0.2 * w, 0)
			r["Spine"] = Vector3(0.15 * w, 0, 0)
			r["Head"] = Vector3(-0.25 * w, 0, 0)
		"arm_l":
			r["LeftUpperArm"] = Vector3(0.5 * w, 0, -0.6 * w)
			r["LeftLowerArm"] = Vector3(0.4 * w, 0, 0)
			r["Chest"] = Vector3(0, 0.2 * w, 0.12 * w)
		"arm_r":
			r["RightUpperArm"] = Vector3(0.5 * w, 0, 0.6 * w)
			r["RightLowerArm"] = Vector3(0.4 * w, 0, 0)
			r["Chest"] = Vector3(0, -0.2 * w, -0.12 * w)
		"leg_l":
			r["LeftUpperLeg"] = Vector3(0.3 * w, 0, 0.1 * w)
			r["LeftLowerLeg"] = Vector3(-0.5 * w, 0, 0)
			r["Hips"] = Vector3(0, 0, -0.08 * w)
		"leg_r":
			r["RightUpperLeg"] = Vector3(0.3 * w, 0, -0.1 * w)
			r["RightLowerLeg"] = Vector3(-0.5 * w, 0, 0)
			r["Hips"] = Vector3(0, 0, 0.08 * w)
	return r


# ================================================================== one-shots

static func _oneshot_pose(clip: String, t: float, length: float) -> Dictionary:
	var k: float = clampf(t / maxf(0.001, length), 0.0, 1.0)
	match clip:
		"idle":
			return _idle_pose(t)
		"crawl_idle":
			var ci: Dictionary = _crawl_pose("drag", 0.0, false)
			ci["Head"] = Vector3(0.35 + sin(t * 2.0) * 0.08, sin(t * 1.3) * 0.2, 0)
			return ci
		"window_wait":
			var ww: Dictionary = _idle_pose(t)
			ww["LeftUpperArm"] = Vector3(1.6 + sin(t * 5.0) * 0.2, 0, -0.2)
			ww["RightUpperArm"] = Vector3(1.45 + cos(t * 4.6) * 0.2, 0, 0.2)
			ww["LeftLowerArm"] = Vector3(0.4, 0, 0)
			ww["RightLowerArm"] = Vector3(0.5, 0, 0)
			ww["Jaw"] = Vector3(0.4, 0, 0)
			return ww
		"turn_l", "turn_r":
			return _turn_pose(-1.0 if clip == "turn_l" else 1.0, k)
	if clip.begins_with("swipe") or clip in ["lunge", "grab", "crawl_bite", "headbutt", "window_swipe"]:
		return _attack_pose(clip, t)
	if clip.begins_with("tear_"):
		return _tear_pose(clip, t, k)
	if clip.begins_with("death"):
		return _death_pose(clip, t, k)
	if ZombieEmerge.is_ground_clip(clip):
		return ZombieEmerge.pose(ZombieEmerge.variant_of_clip(clip), k)   # staged dig-outs (T-085)
	match clip:
		"vault_a", "vault_b":
			return _vault_pose(clip, k)
		"drop_down":
			return _drop_pose(k)
		"emerge_portal", "emerge_ceiling", "emerge_wade":
			return _emerge_pose(clip, t, k)
		"climb_loop":
			return _climb_pose(t)
		"climb_mantle":
			return _mantle_pose(k)
		"stagger":
			return _stagger_pose(k)
		"knockdown_front", "knockdown_back":
			return _knockdown_pose(clip == "knockdown_front", k)
		"getup_front", "getup_back":
			return _getup_pose(clip == "getup_front", k)
		"fall_crawl":
			return _fall_crawl_pose(k)
	return _rest()


static func _turn_pose(side: float, k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(k * 0.8)
	var s: float = sin(k * TAU)
	r["Hips"] = Vector3(0, -side * 0.12 * s, 0)
	r["LeftUpperLeg"] = Vector3(0.25 * maxf(0.0, s) * (1.0 if side < 0.0 else 0.3), 0, 0.05)
	r["RightUpperLeg"] = Vector3(0.25 * maxf(0.0, -s) * (1.0 if side > 0.0 else 0.3), 0, -0.05)
	r["LeftLowerLeg"] = Vector3(-0.3 * maxf(0.0, s), 0, 0)
	r["RightLowerLeg"] = Vector3(-0.3 * maxf(0.0, -s), 0, 0)
	r["Chest"] = Vector3(-0.1, side * 0.15 * s, 0)
	r["Head"] = Vector3(0.1, side * 0.3, 0)
	return r


static func _attack_pose(clip: String, t: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var w: float = ATTACK_WINDUP
	var k: float = clampf(t / w, 0.0, 1.0)
	var k2: float = clampf((t - w) / 0.16, 0.0, 1.0)
	var set: float = clampf((t - w - 0.16) / 0.19, 0.0, 1.0)
	match clip:
		"swipe_l", "swipe_r":
			var sgn: float = -1.0 if clip == "swipe_l" else 1.0
			var arm: String = "LeftUpperArm" if sgn < 0.0 else "RightUpperArm"
			var fore: String = "LeftLowerArm" if sgn < 0.0 else "RightLowerArm"
			r[arm] = _lerp(_lerp(Vector3(1.0, 0, sgn * 0.08), Vector3(2.75, sgn * 0.6, sgn * 0.9), _ease(k)), Vector3(0.45, -sgn * 0.6, -sgn * 0.5), k2)
			r[fore] = Vector3(lerpf(lerpf(0.3, 0.9, k), 0.15, k2), 0, 0)
			r["Chest"] = Vector3(-0.09 + 0.22 * k - 0.45 * k2, -sgn * 0.35 * k + sgn * 0.6 * k2, 0)
			r["Jaw"] = Vector3(0.6, 0, 0)
		"swipe_double":
			r["LeftUpperArm"] = _lerp(_lerp(Vector3(1.0, 0, -0.08), Vector3(2.75, 0, -0.5), _ease(k)), Vector3(0.45, 0, -0.1), k2)
			r["RightUpperArm"] = _lerp(_lerp(Vector3(1.0, 0, 0.08), Vector3(2.6, 0, 0.5), _ease(k)), Vector3(0.55, 0, 0.1), k2)
			r["LeftLowerArm"] = Vector3(lerpf(lerpf(0.3, 0.9, k), 0.15, k2), 0, 0)
			r["RightLowerArm"] = Vector3(lerpf(lerpf(0.3, 0.9, k), 0.15, k2), 0, 0)
			r["Chest"] = Vector3(-0.09 + 0.22 * k - 0.45 * k2, 0.25 * k2, 0)
			r["Jaw"] = Vector3(0.6, 0, 0)
		"swipe_over":
			r["LeftUpperArm"] = _lerp(_lerp(Vector3(1.0, 0, -0.08), Vector3(3.1, 0, -0.3), _ease(k)), Vector3(0.3, 0, -0.2), k2)
			r["RightUpperArm"] = _lerp(_lerp(Vector3(1.0, 0, 0.08), Vector3(3.1, 0, 0.3), _ease(k)), Vector3(0.3, 0, 0.2), k2)
			r["LeftLowerArm"] = Vector3(lerpf(0.3, 1.3, k) * (1.0 - k2) + 0.1 * k2, 0, 0)
			r["RightLowerArm"] = r["LeftLowerArm"]
			r["Spine"] = Vector3(0.2 * k - 0.35 * k2, 0, 0)
			r["Chest"] = Vector3(-0.09 + 0.35 * k - 0.6 * k2, 0, 0)
			r["Head"] = Vector3(-0.3 * k + 0.5 * k2, 0, 0)
			r["Jaw"] = Vector3(0.6, 0, 0)
		"lunge":
			# crouch in the windup, then a leap: body forward, arms out
			r["LeftUpperLeg"] = Vector3(0.6 * k - 0.4 * k2, 0, 0.05)
			r["RightUpperLeg"] = Vector3(0.6 * k - 0.4 * k2, 0, -0.05)
			r["LeftLowerLeg"] = Vector3(-1.0 * k + 0.7 * k2, 0, 0)
			r["RightLowerLeg"] = Vector3(-1.0 * k + 0.7 * k2, 0, 0)
			r["hips_pos"] = Vector3(0, -0.25 * k + 0.1 * k2, 0)
			r["Chest"] = Vector3(-0.35 * k - 0.3 * k2, 0, 0)
			r["LeftUpperArm"] = _lerp(_lerp(Vector3(1.0, 0, -0.08), Vector3(1.4, 0, -0.5), k), Vector3(2.6, 0, -0.3), k2)
			r["RightUpperArm"] = _lerp(_lerp(Vector3(1.0, 0, 0.08), Vector3(1.4, 0, 0.5), k), Vector3(2.6, 0, 0.3), k2)
			r["LeftLowerArm"] = Vector3(0.8 - 0.6 * k2, 0, 0)
			r["RightLowerArm"] = Vector3(0.8 - 0.6 * k2, 0, 0)
			r["Head"] = Vector3(-0.2, 0, 0)
			r["Jaw"] = Vector3(0.6, 0, 0)
		"grab":
			r["LeftUpperArm"] = _lerp(Vector3(1.0, 0, -0.08), Vector3(2.4, 0.2, -0.25), _ease(k))
			r["RightUpperArm"] = _lerp(Vector3(1.0, 0, 0.08), Vector3(2.4, -0.2, 0.25), _ease(k))
			r["LeftLowerArm"] = Vector3(0.3 + 0.5 * k + 0.6 * k2, 0, 0)
			r["RightLowerArm"] = Vector3(0.3 + 0.5 * k + 0.6 * k2, 0, 0)
			r["LeftHand"] = Vector3(0.6 * k2, 0, 0)
			r["RightHand"] = Vector3(0.6 * k2, 0, 0)
			r["Chest"] = Vector3(-0.09 - 0.25 * k - 0.2 * k2, 0, 0)
			r["Head"] = Vector3(0.1 - 0.4 * k2, 0, 0)
			r["Jaw"] = Vector3(0.7, 0, 0)
		"crawl_bite":
			r = _crawl_pose("drag", 0.0, false)
			r["Chest"] = Vector3(0.15 - 0.3 * k + 0.6 * k2, 0, 0)
			r["Neck"] = Vector3(0.9 - 0.5 * k2, 0, 0)
			r["Head"] = Vector3(0.35 - 0.3 * k + 0.4 * k2, 0, 0)
			r["Jaw"] = Vector3(0.9 * k - 0.8 * k2, 0, 0)
			r["LeftUpperArm"] = Vector3(2.5 - 0.4 * k2, 0, -0.35)
			r["RightUpperArm"] = Vector3(2.5 - 0.4 * k2, 0, 0.35)
		"headbutt":
			r["Chest"] = Vector3(-0.09 + 0.45 * k - 0.9 * k2, 0, 0)
			r["Spine"] = Vector3(0.2 * k - 0.4 * k2, 0, 0)
			r["Neck"] = Vector3(0.1 + 0.3 * k - 0.7 * k2, 0, 0)
			r["Head"] = Vector3(-0.4 * k + 0.6 * k2, 0, 0)
			r["Jaw"] = Vector3(0.7, 0, 0)
		"window_swipe":
			r["RightUpperArm"] = _lerp(_lerp(Vector3(1.0, 0, 0.08), Vector3(1.9, 0, 0.1), _ease(k)), Vector3(1.4, -0.7, -0.2), k2)
			r["RightLowerArm"] = Vector3(lerpf(0.3, 0.1, k), 0, 0)
			r["LeftUpperArm"] = Vector3(1.6, 0, -0.3)
			r["LeftLowerArm"] = Vector3(0.5, 0, 0)
			r["Chest"] = Vector3(-0.3 - 0.25 * k, -0.2 * k + 0.4 * k2, 0)
			r["Spine"] = Vector3(-0.15, 0, 0)
			r["Jaw"] = Vector3(0.6, 0, 0)
	# settle back toward the stance in the last part of the swing
	if set > 0.0:
		var base: Dictionary = _idle_pose(0.0)
		for key: String in base.keys():
			if key != "hips_pos" and r.has(key):
				r[key] = _lerp(r[key] as Vector3, base[key] as Vector3, set * 0.6)
	return r


static func _tear_pose(clip: String, _t: float, k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var yank: float = maxf(0.0, 1.0 - absf(k - 0.62) / 0.14)   # the rip lands at 62% of the cycle
	var s: float = sin(k * TAU)
	match clip:
		"tear_rip":
			r["LeftUpperArm"] = Vector3(1.6 + s * 0.18, 0, -0.15)
			r["RightUpperArm"] = Vector3(1.6 - s * 0.18, 0, 0.15)
			r["LeftLowerArm"] = Vector3(0.5 - s * 0.3, 0, 0)
			r["RightLowerArm"] = Vector3(0.5 + s * 0.3, 0, 0)
			r["Chest"] = Vector3(-0.25 + s * 0.12 + yank * 0.4, 0, 0)
			r["Spine"] = Vector3(-0.1 + yank * 0.2, 0, 0)
		"tear_wrench":
			r["LeftUpperArm"] = Vector3(1.7, 0, -0.2 + s * 0.3)
			r["RightUpperArm"] = Vector3(1.7, 0, 0.2 + s * 0.3)
			r["LeftLowerArm"] = Vector3(0.6, 0, 0)
			r["RightLowerArm"] = Vector3(0.6, 0, 0)
			r["Chest"] = Vector3(-0.2 + yank * 0.3, s * 0.35, s * 0.1)
			r["Hips"] = Vector3(0, s * 0.1, 0)
		"tear_slam":
			var wind: float = sin(k * TAU) * 0.5 + 0.5
			r["Chest"] = Vector3(-0.1 - wind * 0.4 + yank * 0.6, -0.3 * wind, 0.25 * wind)
			r["Spine"] = Vector3(-0.05 - wind * 0.15, 0, 0)
			r["RightUpperArm"] = Vector3(0.5 + wind * 0.6, 0, 0.6)
			r["LeftUpperArm"] = Vector3(1.2, 0, -0.4)
			r["hips_pos"] = Vector3(0, -0.04 * wind, -0.08 * yank)
	r["Jaw"] = Vector3(0.5, 0, 0)
	r["Head"] = Vector3(0.1 + yank * 0.2, 0, 0)
	return r


static func _vault_pose(clip: String, k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var up: float = _ease(clampf(k / 0.5, 0.0, 1.0))
	var over: float = _ease(clampf((k - 0.5) / 0.5, 0.0, 1.0))
	if clip == "vault_a":
		# one knee up onto the sill, then the other leg swings over
		r["LeftUpperLeg"] = Vector3(1.45 * up - 1.2 * over, 0, 0.1)
		r["LeftLowerLeg"] = Vector3(-1.6 * up + 1.3 * over, 0, 0)
		r["RightUpperLeg"] = Vector3(-0.15 * up + 1.2 * over, 0, -0.1)
		r["RightLowerLeg"] = Vector3(-0.3 * up - 0.9 * over, 0, 0)
		r["Chest"] = Vector3(-0.75 * up + 0.4 * over, 0.2 * up, 0)
		r["Spine"] = Vector3(-0.3 * up + 0.15 * over, 0, 0)
	else:
		# a head-first dive over the boards, legs trailing
		r["Chest"] = Vector3(-1.1 * up + 0.9 * over, 0, 0)
		r["Spine"] = Vector3(-0.5 * up + 0.4 * over, 0, 0)
		r["LeftUpperLeg"] = Vector3(0.4 * up - 0.9 * over, 0, 0.12)
		r["RightUpperLeg"] = Vector3(0.7 * up - 0.9 * over, 0, -0.12)
		r["LeftLowerLeg"] = Vector3(-0.8 * up + 0.5 * over, 0, 0)
		r["RightLowerLeg"] = Vector3(-1.0 * up + 0.6 * over, 0, 0)
		r["hips_pos"] = Vector3(0, 0.1 * up - 0.3 * over, 0)
	r["LeftUpperArm"] = Vector3(1.0 + 1.3 * up - 1.2 * over, 0, -0.2)
	r["RightUpperArm"] = Vector3(1.1 + 1.2 * up - 1.1 * over, 0, 0.2)
	r["LeftLowerArm"] = Vector3(0.2 + 0.5 * over, 0, 0)
	r["RightLowerArm"] = Vector3(0.2 + 0.5 * over, 0, 0)
	r["Head"] = Vector3(-0.2 * up + 0.3 * over, 0, 0)
	return r


static func _drop_pose(k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var fall: float = _ease(clampf(k / 0.6, 0.0, 1.0))
	var land: float = sin(clampf((k - 0.6) / 0.4, 0.0, 1.0) * PI)
	r["LeftUpperLeg"] = Vector3(0.4 * fall + 0.7 * land, 0, 0.08)
	r["RightUpperLeg"] = Vector3(0.3 * fall + 0.7 * land, 0, -0.08)
	r["LeftLowerLeg"] = Vector3(-0.5 * fall - 1.1 * land, 0, 0)
	r["RightLowerLeg"] = Vector3(-0.4 * fall - 1.1 * land, 0, 0)
	r["hips_pos"] = Vector3(0, -0.3 * land, 0)
	r["Chest"] = Vector3(-0.3 * fall - 0.3 * land, 0, 0)
	r["LeftUpperArm"] = Vector3(1.0 + 1.5 * fall - 1.0 * land, 0, -0.5 * fall)
	r["RightUpperArm"] = Vector3(1.0 + 1.5 * fall - 1.0 * land, 0, 0.5 * fall)
	return r


## The non-ground emerges (the ground dig-outs are ZombieEmerge, T-085).
static func _emerge_pose(clip: String, t: float, k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var rise: float = _ease(k)
	match clip:
		"emerge_portal":
			# a step through the violet door: arms spread, head up, a long stride
			var step: float = sin(k * PI)
			r["LeftUpperArm"] = Vector3(1.3 * (1.0 - rise) + 1.0 * rise, 0, -1.1 * (1.0 - rise) - 0.08)
			r["RightUpperArm"] = Vector3(1.3 * (1.0 - rise) + 1.0 * rise, 0, 1.1 * (1.0 - rise) + 0.08)
			r["LeftUpperLeg"] = Vector3(0.7 * step, 0, 0.05)
			r["LeftLowerLeg"] = Vector3(-0.9 * step, 0, 0)
			r["Head"] = Vector3(-0.35 * (1.0 - rise), 0, 0)
			r["Chest"] = Vector3(0.15 * (1.0 - rise), 0, 0)
			r["Jaw"] = Vector3(0.7, 0, 0)
		"emerge_ceiling":
			# dropping from a chute: tucked, then the landing crouch
			var fall: float = _ease(clampf(k / 0.45, 0.0, 1.0))
			var land: float = sin(clampf((k - 0.45) / 0.55, 0.0, 1.0) * PI)
			r["hips_pos"] = Vector3(0, 3.0 * (1.0 - fall) - 0.35 * land, 0)
			r["LeftUpperLeg"] = Vector3(0.9 * (1.0 - fall) + 0.8 * land, 0, 0.1)
			r["RightUpperLeg"] = Vector3(0.9 * (1.0 - fall) + 0.8 * land, 0, -0.1)
			r["LeftLowerLeg"] = Vector3(-1.3 * (1.0 - fall) - 1.2 * land, 0, 0)
			r["RightLowerLeg"] = Vector3(-1.3 * (1.0 - fall) - 1.2 * land, 0, 0)
			r["Chest"] = Vector3(-0.4 * land, 0, 0)
			r["LeftUpperArm"] = Vector3(2.2 * (1.0 - fall) + 1.0 * fall, 0, -0.3)
			r["RightUpperArm"] = Vector3(2.2 * (1.0 - fall) + 1.0 * fall, 0, 0.3)
		"emerge_wade":
			# wading up the surf steps: body low in the water, arms pushing the surface aside
			r["hips_pos"] = Vector3(0, -1.1 * (1.0 - rise), 0)
			r["Chest"] = Vector3(-0.35 * (1.0 - rise) - 0.09, 0, 0)
			r["LeftUpperArm"] = Vector3(1.9 + sin(t * 3.0) * 0.3, 0, -0.9 * (1.0 - rise) - 0.1)
			r["RightUpperArm"] = Vector3(1.9 + cos(t * 3.2) * 0.3, 0, 0.9 * (1.0 - rise) + 0.1)
			r["LeftLowerArm"] = Vector3(0.5, 0, 0)
			r["RightLowerArm"] = Vector3(0.5, 0, 0)
			var step: float = sin(t * 4.0)
			r["LeftUpperLeg"] = Vector3(0.5 * maxf(0.0, step), 0, 0.05)
			r["RightUpperLeg"] = Vector3(0.5 * maxf(0.0, -step), 0, -0.05)
			r["LeftLowerLeg"] = Vector3(-0.7 * maxf(0.0, step), 0, 0)
			r["RightLowerLeg"] = Vector3(-0.7 * maxf(0.0, -step), 0, 0)
			r["Head"] = Vector3(-0.2, 0, 0)
	return r


static func _climb_pose(t: float) -> Dictionary:
	var r: Dictionary = _rest()
	var p: float = t * TAU
	var s: float = sin(p)
	r["Chest"] = Vector3(-0.35, 0, s * 0.08)
	r["Spine"] = Vector3(-0.15, 0, 0)
	r["Head"] = Vector3(-0.5, 0, 0)
	r["LeftUpperArm"] = Vector3(2.4 + s * 0.5, 0, -0.3)
	r["RightUpperArm"] = Vector3(2.4 - s * 0.5, 0, 0.3)
	r["LeftLowerArm"] = Vector3(0.6 - s * 0.4, 0, 0)
	r["RightLowerArm"] = Vector3(0.6 + s * 0.4, 0, 0)
	r["LeftUpperLeg"] = Vector3(0.9 - s * 0.6, 0, 0.15)
	r["RightUpperLeg"] = Vector3(0.9 + s * 0.6, 0, -0.15)
	r["LeftLowerLeg"] = Vector3(-1.2 + s * 0.5, 0, 0)
	r["RightLowerLeg"] = Vector3(-1.2 - s * 0.5, 0, 0)
	r["hips_pos"] = Vector3(0, 0, 0.18)
	return r


static func _mantle_pose(k: float) -> Dictionary:
	var r: Dictionary = _climb_pose(0.0)
	var e: float = _ease(k)
	var base: Dictionary = _idle_pose(0.0)
	r["Chest"] = Vector3(-0.9 * (1.0 - e) - 0.09 * e, 0, 0)
	r["Spine"] = Vector3(-0.3 * (1.0 - e), 0, 0)
	r["LeftUpperLeg"] = Vector3(1.4 * (1.0 - e), 0, 0.1)
	r["RightUpperLeg"] = Vector3(0.3 * (1.0 - e), 0, -0.1)
	r["LeftLowerLeg"] = Vector3(-1.5 * (1.0 - e) - 0.06, 0, 0)
	r["hips_pos"] = Vector3(0, -0.2 * (1.0 - e), 0.18 * (1.0 - e))
	for key: String in ["LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Head"]:
		r[key] = _lerp(r[key] as Vector3, base[key] as Vector3, e)
	return r


static func _stagger_pose(k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var w: float = sin(clampf(k, 0.0, 1.0) * PI)
	r["Chest"] = Vector3(-0.09 + 0.4 * w, 0.3 * w, 0)
	r["Head"] = Vector3(0.15 - 0.45 * w, 0, 0)
	r["LeftUpperArm"] = Vector3(0.35 + 0.6 * (1.0 - w), 0, -0.3 * w)
	r["RightUpperArm"] = Vector3(0.5 + 0.5 * (1.0 - w), 0, 0.3 * w)
	r["LeftUpperLeg"] = Vector3(-0.35 * w, 0, 0.05)
	r["RightUpperLeg"] = Vector3(0.2 * w, 0, -0.05)
	r["LeftLowerLeg"] = Vector3(-0.3 * w, 0, 0)
	r["hips_pos"] = Vector3(0, -0.05 * w, 0.12 * w)
	return r


static func _knockdown_pose(front: bool, k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var e: float = _ease(clampf(k / 0.55, 0.0, 1.0))
	var sgn: float = -1.0 if front else 1.0
	_body_tilt(r, sgn * 1.5 * e, 0.0, 0.0, 0.0)
	r["LeftUpperArm"] = Vector3(2.4 * e + 1.0 * (1.0 - e), 0, -0.8 * e)
	r["RightUpperArm"] = Vector3(2.4 * e + 1.0 * (1.0 - e), 0, 0.8 * e)
	r["LeftLowerArm"] = Vector3(0.9 * e, 0, 0)
	r["RightLowerArm"] = Vector3(0.9 * e, 0, 0)
	r["LeftUpperLeg"] = Vector3((0.4 if front else -0.3) * e, 0, 0.1)
	r["RightUpperLeg"] = Vector3((0.2 if front else 0.5) * e, 0, -0.15)
	r["LeftLowerLeg"] = Vector3(-0.6 * e, 0, 0)
	r["RightLowerLeg"] = Vector3(-0.3 * e, 0, 0)
	r["Head"] = Vector3((0.4 if front else -0.6) * e, 0.2 * e, 0)
	return r


static func _getup_pose(front: bool, k: float) -> Dictionary:
	var r: Dictionary = _knockdown_pose(front, 1.0)
	var e: float = _ease(k)
	var base: Dictionary = _idle_pose(0.0)
	var sgn: float = -1.0 if front else 1.0
	# push up through a kneel: the tilt unwinds while the knees come under the body
	r["Hips"] = Vector3(sgn * 1.5 * (1.0 - e), 0, 0)
	var hips_rest: Vector3 = ZombieRig.rest_offset("Hips")
	var b: Basis = Basis.from_euler(r["Hips"] as Vector3)
	var kneel: float = sin(e * PI)
	r["hips_pos"] = (b * hips_rest) - hips_rest + Vector3(0, -0.4 * kneel, 0)
	r["LeftUpperLeg"] = Vector3(1.4 * kneel, 0, 0.1)
	r["RightUpperLeg"] = Vector3(1.0 * kneel, 0, -0.1)
	r["LeftLowerLeg"] = Vector3(-2.2 * kneel - 0.06, 0, 0)
	r["RightLowerLeg"] = Vector3(-1.6 * kneel - 0.06, 0, 0)
	for key: String in ["LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Head", "Chest", "Spine"]:
		r[key] = _lerp(r[key] as Vector3, base[key] as Vector3, e)
	return r


## Losing a leg at a run: a stumble forward that ends in the crawl pose.
static func _fall_crawl_pose(k: float) -> Dictionary:
	var a: Dictionary = _idle_pose(0.0)
	var c: Dictionary = _crawl_pose("drag", 0.0, false)
	var e: float = _ease(k)
	var stumble: float = sin(clampf(k / 0.5, 0.0, 1.0) * PI)
	var r: Dictionary = {}
	for key: String in c.keys():
		r[key] = _lerp(a.get(key, Vector3.ZERO) as Vector3, c[key] as Vector3, e)
	r["LeftUpperArm"] = (r["LeftUpperArm"] as Vector3) + Vector3(1.2 * stumble, 0, -0.4 * stumble)
	r["RightUpperArm"] = (r["RightUpperArm"] as Vector3) + Vector3(1.2 * stumble, 0, 0.4 * stumble)
	r["Head"] = (r["Head"] as Vector3) + Vector3(-0.4 * stumble, 0, 0)
	return r


## Deaths: the authored fall to the key pose (ragdoll takes over after anim.json ragdoll.key_pose_seconds).
static func _death_pose(clip: String, t: float, _k: float) -> Dictionary:
	var r: Dictionary = _idle_pose(0.0)
	var e: float = _ease(clampf(t / 0.75, 0.0, 1.0))
	var fast: float = _ease(clampf(t / 0.35, 0.0, 1.0))
	match clip:
		"death_head_snap":
			r["Head"] = Vector3(-1.1 * fast, 0.4 * fast, 0.5 * fast)
			r["Neck"] = Vector3(-0.4 * fast, 0, 0)
			_body_tilt(r, 1.5 * _ease(clampf((t - 0.15) / 0.6, 0.0, 1.0)), 0.0, 0.0, 0.0)
			r["LeftUpperArm"] = Vector3(2.4 * e + 1.0, 0, -0.9 * e)
			r["RightUpperArm"] = Vector3(2.0 * e + 1.0, 0, 1.0 * e)
		"death_gut":
			var fold: float = _ease(clampf(t / 0.4, 0.0, 1.0))
			var drop: float = _ease(clampf((t - 0.35) / 0.5, 0.0, 1.0))
			r["Spine"] = Vector3(-0.6 * fold, 0, 0)
			r["Chest"] = Vector3(-0.7 * fold, 0, 0)
			r["LeftUpperArm"] = Vector3(0.3, 0.4 * fold, -0.3)
			r["RightUpperArm"] = Vector3(0.3, -0.4 * fold, 0.3)
			r["LeftLowerArm"] = Vector3(1.6 * fold, 0, 0)
			r["RightLowerArm"] = Vector3(1.6 * fold, 0, 0)
			r["LeftUpperLeg"] = Vector3(1.4 * drop, 0, 0.1)
			r["RightUpperLeg"] = Vector3(1.3 * drop, 0, -0.1)
			r["LeftLowerLeg"] = Vector3(-2.3 * drop, 0, 0)
			r["RightLowerLeg"] = Vector3(-2.2 * drop, 0, 0)
			_body_tilt(r, -1.25 * _ease(clampf((t - 0.6) / 0.5, 0.0, 1.0)), 0.0, 0.0, -0.45 * drop)
		"death_spin":
			_body_tilt(r, 0.0, 1.45 * e, 0.6 * _ease(clampf(t / 0.5, 0.0, 1.0)) + 1.2 * e, 0.0)
			r["Chest"] = Vector3(-0.2, 0.5, 0)
			r["LeftUpperArm"] = Vector3(1.6, 0, -1.2 * e)
			r["RightUpperArm"] = Vector3(0.6, 0, 0.6 * e)
			r["Head"] = Vector3(0.1, 0.5 * e, 0.3 * e)
		"death_knee":
			var kneel: float = _ease(clampf(t / 0.35, 0.0, 1.0))
			var fwd: float = _ease(clampf((t - 0.45) / 0.5, 0.0, 1.0))
			r["LeftUpperLeg"] = Vector3(1.4 * kneel, 0, 0.1)
			r["RightUpperLeg"] = Vector3(1.3 * kneel, 0, -0.1)
			r["LeftLowerLeg"] = Vector3(-2.3 * kneel, 0, 0)
			r["RightLowerLeg"] = Vector3(-2.2 * kneel, 0, 0)
			r["LeftUpperArm"] = Vector3(0.2, 0, -0.2)
			r["RightUpperArm"] = Vector3(0.1, 0, 0.2)
			r["Head"] = Vector3(0.6 * kneel, 0, 0.3 * kneel)
			_body_tilt(r, -1.25 * fwd, 0.0, 0.0, -0.42 * kneel - 0.2 * fwd)
		"death_back":
			_body_tilt(r, 1.5 * e, 0.0, 0.0, 0.0)
			r["LeftUpperLeg"] = Vector3(0.6 * e, 0, 0.1)
			r["RightUpperLeg"] = Vector3(0.2 * e, 0, -0.15)
			r["LeftLowerLeg"] = Vector3(-0.9 * e, 0, 0)
			r["LeftUpperArm"] = Vector3(2.4 * e + 1.0 * (1.0 - e), 0, -0.9 * e)
			r["RightUpperArm"] = Vector3(2.0 * e + 1.0 * (1.0 - e), 0, 1.0 * e)
			r["Head"] = Vector3(-0.5 * e, 0.3 * e, 0)
		"death_faceplant":
			_body_tilt(r, -1.5 * e, 0.0, 0.0, 0.0)
			r["LeftUpperArm"] = Vector3(0.3, 0, -0.3)
			r["RightUpperArm"] = Vector3(2.6 * e + 1.0 * (1.0 - e), 0, 0.4)
			r["Head"] = Vector3(0.3 * e, -0.5 * e, 0.2 * e)
			r["LeftLowerLeg"] = Vector3(-0.4 * e, 0, 0)
		"death_sit":
			var sit: float = _ease(clampf(t / 0.5, 0.0, 1.0))
			var slump: float = _ease(clampf((t - 0.45) / 0.6, 0.0, 1.0))
			r["LeftUpperLeg"] = Vector3(1.5 * sit, 0, 0.2)
			r["RightUpperLeg"] = Vector3(1.4 * sit, 0, -0.25)
			r["LeftLowerLeg"] = Vector3(-1.3 * sit, 0, 0)
			r["RightLowerLeg"] = Vector3(-0.9 * sit, 0, 0)
			r["Chest"] = Vector3(-0.5 * slump, 0.2 * slump, 0.3 * slump)
			r["Head"] = Vector3(0.7 * slump, 0, 0.4 * slump)
			r["LeftUpperArm"] = Vector3(0.6, 0, -0.5)
			r["RightUpperArm"] = Vector3(0.5, 0, 0.5)
			_body_tilt(r, 0.35 * sit, 0.3 * slump, 0.0, -0.7 * sit)
		"death_tumble":
			# a sprinter's momentum carries it over: a forward roll that ends on the back
			var roll: float = _ease(clampf(t / 0.7, 0.0, 1.0))
			_body_tilt(r, -1.5 * roll - 1.6 * _ease(clampf((t - 0.5) / 0.6, 0.0, 1.0)), 0.0, 0.2 * roll, 0.15 * sin(roll * PI))
			r["hips_pos"] = (r["hips_pos"] as Vector3) + Vector3(0, 0, -0.5 * roll)
			r["Spine"] = Vector3(-0.4 * roll, 0, 0)
			r["Chest"] = Vector3(-0.5 * roll, 0, 0)
			r["LeftUpperLeg"] = Vector3(1.0 * roll, 0, 0.1)
			r["RightUpperLeg"] = Vector3(0.8 * roll, 0, -0.1)
			r["LeftLowerLeg"] = Vector3(-1.2 * roll, 0, 0)
			r["RightLowerLeg"] = Vector3(-1.0 * roll, 0, 0)
			r["LeftUpperArm"] = Vector3(2.5 * roll, 0, -0.6 * roll)
			r["RightUpperArm"] = Vector3(2.5 * roll, 0, 0.6 * roll)
		"death_headless":
			# the body takes two more steps, arms reaching, then folds backward
			var walk: float = clampf(t / 0.7, 0.0, 1.0)
			var p: float = walk * TAU
			r["LeftUpperLeg"] = Vector3(sin(p) * 0.45, 0, 0.05)
			r["RightUpperLeg"] = Vector3(-sin(p) * 0.45, 0, -0.05)
			r["LeftLowerLeg"] = Vector3(-0.5 * maxf(0.0, cos(p)) - 0.08, 0, 0)
			r["RightLowerLeg"] = Vector3(-0.5 * maxf(0.0, -cos(p)) - 0.08, 0, 0)
			r["LeftUpperArm"] = Vector3(1.8, 0, -0.3)
			r["RightUpperArm"] = Vector3(1.7, 0, 0.3)
			r["root"] = FORWARD * 0.9 * walk
			var fold: float = _ease(clampf((t - 0.7) / 0.5, 0.0, 1.0))
			_body_tilt(r, 1.5 * fold, 0.0, 0.0, 0.0)
		"death_crawl":
			r = _crawl_pose("drag", 0.0, false)
			r["LeftUpperArm"] = Vector3(2.2 * e + 2.5 * (1.0 - e), 0, -0.6 * e - 0.35 * (1.0 - e))
			r["RightUpperArm"] = Vector3(1.8 * e + 2.5 * (1.0 - e), 0, 0.7 * e + 0.35 * (1.0 - e))
			r["Neck"] = Vector3(-0.2 * e + 0.9 * (1.0 - e), 0, 0.4 * e)
	r["Jaw"] = Vector3(0.5, 0, 0)
	return r
