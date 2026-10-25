class_name ZombieEmerge
extends RefCounted
## The rise from the ground (T-085): a staged, varied dig-out authored as keyframes on the shared ZombieRig and
## baked by ZombieClips like every other clip. Everything a designer tunes lives in data/gravelight/enemies.json
## "emerge": the variants (fast lunge-out, standard dig, slow clawing with a pause and a second heave, face-first
## then roll, and the crawlers' elbow drag that stays down), their lengths, pick weights (biased per speed tier),
## the normalized stage times (ground bulges -> one hand -> second hand -> head out -> shoulders -> elbow plant
## -> knee -> stand -> done), the round multiplier (faster later) and the surface classes (snow / earth / stone)
## that pick the mound, spray and sounds.
##
## The stage times are the contract between the clip and the gameplay: ZombieEmerge.pose() places its keys on
## them, and Zombie fires the particles, the sounds and the hitbox enable (at "head_out": a rising zombie can be
## shot from the moment its head is out, never before) off the same table. A pose key is assembled once per
## variant (bones + the hips rotation as a quaternion + the hips offset) and sampled by eased interpolation,
## with procedural layers on top (clawing, the heave tremble, the stagger step).

const CLIP_PREFIX: String = "emerge_"
## Stage names every ground variant must have, in order (the test checks monotonic times between them).
const CORE_STAGES: PackedStringArray = ["bulge", "hand", "hand2", "head_out", "done"]
## Rig geometry the keys are authored against (anim.json skeleton, unscaled): hips 0.95, shoulders ~1.46,
## head bone 1.59 (crown ~1.75), a raised hand's wrist ~2.05 and fingertips ~2.2.
const SHOULDER_Y: float = 1.46

static var _cfg: Dictionary = {}
static var _keys: Dictionary = {}          # variant -> Array of assembled keys
static var _stage_lists: Dictionary = {}   # variant -> Array of [name, t] sorted by t
static var _mound_mesh: Mesh = null
static var _hole_mesh: Mesh = null
static var _mound_mats: Dictionary = {}
static var _hole_mats: Dictionary = {}


# ================================================================== data

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.table("enemies").get("emerge", {})
	return _cfg


## Drops the caches (tests that swap the table).
static func reset_cache() -> void:
	_cfg = {}
	_keys.clear()
	_stage_lists.clear()


## Variant names in table order ("_doc" skipped).
static func variants() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in (cfg().get("variants", {}) as Dictionary).keys():
		if str(k) != "_doc":
			out.append(str(k))
	return out


static func variant_cfg(v: String) -> Dictionary:
	var vs: Dictionary = cfg().get("variants", {})
	return vs.get(v, vs.get("standard", {}))


## Length of the variant's clip at round multiplier 1 (seconds).
static func variant_seconds(v: String) -> float:
	return float(variant_cfg(v).get("seconds", 1.4))


## Normalized stage times of a variant (name -> 0..1).
static func stages(v: String) -> Dictionary:
	return variant_cfg(v).get("stages", {})


static func stage(v: String, name: String, fallback: float) -> float:
	return float(stages(v).get(name, fallback))


## The variant's stages sorted by time: Array of [name: String, t: float].
static func stage_list(v: String) -> Array:
	if _stage_lists.has(v):
		return _stage_lists[v]
	var out: Array = []
	for k: Variant in stages(v).keys():
		if str(k) != "_doc":
			out.append([str(k), float(stages(v)[k])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	_stage_lists[v] = out
	return out


static func clip_for(v: String) -> String:
	return CLIP_PREFIX + v


static func variant_of_clip(clip: String) -> String:
	return clip.trim_prefix(CLIP_PREFIX)


## True for the ground variants' clips (the portal step, chute drop and wade-up stay in ZombieClips).
static func is_ground_clip(clip: String) -> bool:
	return clip.begins_with(CLIP_PREFIX) and variants().has(variant_of_clip(clip))


## Picks a variant: the table weights times the tier's multipliers (runners and sprinters lunge out, shamblers
## claw), drawn from `rng` so a seeded match replays the same rises. Crawlers always drag out on their elbows.
static func pick(rng: RandomNumberGenerator, tier: StringName, crawler: bool) -> String:
	var vs: Dictionary = cfg().get("variants", {})
	if crawler and vs.has("crawler"):
		return "crawler"
	var mult: Dictionary = (cfg().get("tier_weight_mult", {}) as Dictionary).get(String(tier), {})
	var names: PackedStringArray = []
	var weights: PackedFloat32Array = []
	var total: float = 0.0
	for v: String in variants():
		if v == "crawler":
			continue
		var w: float = float((vs[v] as Dictionary).get("weight", 0.0)) * float(mult.get(v, 1.0))
		if w <= 0.0:
			continue
		names.append(v)
		weights.append(w)
		total += w
	if names.is_empty():
		return "standard"
	var roll: float = rng.randf() * total
	for i: int in names.size():
		roll -= weights[i]
		if roll <= 0.0:
			return names[i]
	return names[names.size() - 1]


## Round scaling of every ground rise (faster later): a linear ramp between two rounds (enemies.json
## emerge.round_scale), applied as a multiplier to the variant's seconds.
static func round_multiplier(round_number: int) -> float:
	var rs: Dictionary = cfg().get("round_scale", {})
	var r0: float = float(rs.get("start_round", 1))
	var r1: float = float(rs.get("end_round", 20))
	var m0: float = float(rs.get("start", 1.0))
	var m1: float = float(rs.get("end", 0.7))
	if r1 <= r0:
		return m1
	return lerpf(m0, m1, clampf((float(round_number) - r0) / (r1 - r0), 0.0, 1.0))


## Average rise length over the variants at round multiplier 1 (the tests keep it near the old 1.4 s window).
static func mean_seconds(tier: StringName = &"walk") -> float:
	var vs: Dictionary = cfg().get("variants", {})
	var mult: Dictionary = (cfg().get("tier_weight_mult", {}) as Dictionary).get(String(tier), {})
	var total: float = 0.0
	var acc: float = 0.0
	for v: String in variants():
		if v == "crawler":
			continue
		var w: float = float((vs[v] as Dictionary).get("weight", 0.0)) * float(mult.get(v, 1.0))
		total += w
		acc += w * variant_seconds(v)
	return acc / maxf(0.0001, total)


## Mound / spray / sound class for a footstep-style surface name ("snow", "wood", "stone"...; "" = unknown) on
## a map: enemies.json emerge.surface_classes, else the map's default (Map 0 snow, Map 1 earth).
static func surface_class(surface: String, map_id: StringName) -> String:
	var classes: Dictionary = cfg().get("surface_classes", {})
	if surface != "" and classes.has(surface):
		return str(classes[surface])
	var by_map: Dictionary = cfg().get("surface_by_map", {})
	return str(by_map.get(String(map_id), by_map.get("default", "earth")))


## Bank key for a cue ("burst", "dig", "settle") on a surface class; stone shares the earth samples.
static func sound_key(cue: String, surface: String) -> String:
	var snd: Dictionary = cfg().get("sounds", {})
	var per: Dictionary = snd.get(cue, {})
	return str(per.get(surface, per.get("earth", "")))


# ================================================================== the mound and the hole (shared meshes)

static func mound_mesh() -> Mesh:
	if _mound_mesh == null:
		var m: SphereMesh = SphereMesh.new()
		m.radius = 1.0
		m.height = 1.0
		m.is_hemisphere = true
		m.radial_segments = 14
		m.rings = 5
		_mound_mesh = m
	return _mound_mesh


static func hole_mesh() -> Mesh:
	if _hole_mesh == null:
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 0.02
		c.radial_segments = 16
		c.rings = 0
		_hole_mesh = c
	return _hole_mesh


static func mound_material(surface: String) -> StandardMaterial3D:
	if _mound_mats.has(surface):
		return _mound_mats[surface]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.roughness = 1.0
	match surface:
		"snow":
			m.albedo_color = Color(0.86, 0.9, 0.96)
		"stone":
			m.albedo_color = Color(0.4, 0.39, 0.37)
		_:
			m.albedo_color = Color(0.24, 0.17, 0.11)
	_mound_mats[surface] = m
	return m


static func hole_material(surface: String) -> StandardMaterial3D:
	if _hole_mats.has(surface):
		return _hole_mats[surface]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.roughness = 1.0
	match surface:
		"snow":
			m.albedo_color = Color(0.3, 0.34, 0.42)
		"stone":
			m.albedo_color = Color(0.12, 0.12, 0.12)
		_:
			m.albedo_color = Color(0.08, 0.055, 0.035)
	_hole_mats[surface] = m
	return m


# ================================================================== poses

## The pose of a ground variant at normalized time k (0..1): the baked clip samples this.
static func pose(v: String, k: float) -> Dictionary:
	var keys: Array = _assembled(v)
	k = clampf(k, 0.0, 1.0)
	var i: int = 0
	while i + 1 < keys.size() and k >= float((keys[i + 1] as Dictionary)["t"]):
		i += 1
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[mini(i + 1, keys.size() - 1)]
	var span: float = float(b["t"]) - float(a["t"])
	var f: float = clampf((k - float(a["t"])) / span, 0.0, 1.0) if span > 0.0001 else 1.0
	f = _ease_mode(f, str(b.get("ease", "smooth")))
	var r: Dictionary = {}
	var ba: Dictionary = a["bones"]
	var bb: Dictionary = b["bones"]
	for bone: Variant in ba.keys():
		r[bone] = (ba[bone] as Vector3).lerp(bb.get(bone, ba[bone]) as Vector3, f)
	var q: Quaternion = (a["hips_q"] as Quaternion).slerp(b["hips_q"] as Quaternion, f)
	r["Hips"] = q.get_euler()
	r["hips_pos"] = (a["hips_pos"] as Vector3).lerp(b["hips_pos"] as Vector3, f)
	_layers(v, k, r)
	return r


static func _ease_mode(f: float, mode: String) -> float:
	match mode:
		"burst":   # held, then sudden: the hand breaks the crust right at the stage time
			return f * f * f * f
		"heave":   # a slow strain that jerks free at the end
			return f * f * f
		"snap":    # quick, then settles
			return 1.0 - (1.0 - f) * (1.0 - f)
		"linear":
			return f
	return f * f * (3.0 - 2.0 * f)


## The posture in the hole every key starts from: arms by the sides, chin up, legs straight.
static func _base() -> Dictionary:
	var r: Dictionary = ZombieClips._rest()
	r.erase("hips_pos")
	r["LeftUpperArm"] = Vector3(0.25, 0, -0.1)
	r["RightUpperArm"] = Vector3(0.25, 0, 0.1)
	r["LeftLowerArm"] = Vector3(0.2, 0, 0)
	r["RightLowerArm"] = Vector3(0.2, 0, 0)
	r["Head"] = Vector3(-0.15, 0, 0)
	r["Jaw"] = Vector3(0.3, 0, 0)
	r["Chest"] = Vector3(-0.05, 0, 0)
	for b: String in ["Spine", "Neck", "LeftUpperLeg", "RightUpperLeg", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
		r[b] = Vector3.ZERO
	return r


## One authored key. t: a stage name (resolved from the variant's table) or a number. sink: metres the whole body
## sits below the ground. pitch/spin: a tilt forward (negative) and a roll about the body's long axis, about the
## feet ("about" = "feet", a fall) or the hips ("hips": the feet swing, the trunk stays over the hole).
static func _k(t: Variant, ease: String, sink: float, bones: Dictionary, pitch: float = 0.0, spin: float = 0.0, about: String = "hips", lift: float = 0.0) -> Dictionary:
	return {"t": t, "ease": ease, "sink": sink, "bones": bones, "pitch": pitch, "spin": spin, "about": about, "lift": lift}


## A key straight from a full pose dictionary (the idle at the end, the crawl pose the crawlers end in).
static func _k_raw(t: Variant, ease: String, full: Dictionary, sink: float = 0.0) -> Dictionary:
	return {"t": t, "ease": ease, "raw": full, "sink": sink}


static func _assembled(v: String) -> Array:
	if _keys.has(v):
		return _keys[v]
	var out: Array = []
	var hips_rest: Vector3 = ZombieRig.rest_offset("Hips")
	var st: Dictionary = stages(v)
	for key: Dictionary in _authored(v):
		var t: float = float(st.get(key["t"], key["t"])) if key["t"] is String else float(key["t"])
		var bones: Dictionary = {}
		var q: Quaternion = Quaternion.IDENTITY
		var pos: Vector3 = Vector3(0, -float(key.get("sink", 0.0)), 0)
		if key.has("raw"):
			var full: Dictionary = key["raw"]
			bones = _base()
			for b: Variant in full.keys():
				if str(b) == "Hips":
					q = Quaternion.from_euler(full[b] as Vector3)
				elif str(b) == "hips_pos":
					pos += full[b] as Vector3
				elif str(b) != "root":
					bones[b] = full[b]
		else:
			bones = _base()
			for b: Variant in (key["bones"] as Dictionary).keys():
				bones[b] = (key["bones"] as Dictionary)[b]
			var pitch: float = float(key.get("pitch", 0.0))
			var spin: float = float(key.get("spin", 0.0))
			if pitch != 0.0 or spin != 0.0:
				var bas: Basis = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, spin)
				q = bas.get_rotation_quaternion()
				if str(key.get("about", "hips")) == "feet":
					pos += bas * hips_rest - hips_rest
			pos.y += float(key.get("lift", 0.0))
		out.append({"t": t, "ease": str(key.get("ease", "smooth")), "bones": bones, "hips_q": q, "hips_pos": pos})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	_keys[v] = out
	return out


# ------------------------------------------------------------------ shared key poses

## The right hand bursting up (the left arm still down).
static func _p_buried() -> Dictionary:
	return {"RightUpperArm": Vector3(3.0, 0, 0.2), "RightLowerArm": Vector3(0.1, 0, 0), "RightHand": Vector3(-0.3, 0, 0)}


static func _p_hand() -> Dictionary:
	return {"RightUpperArm": Vector3(3.05, 0, 0.25), "RightLowerArm": Vector3(0.05, 0, 0), "RightHand": Vector3(-0.8, 0, 0.2)}


## Both hands out: the left straight up, the right already bent and raking the rim.
static func _p_hand2() -> Dictionary:
	return {"LeftUpperArm": Vector3(2.95, 0, -0.3), "LeftLowerArm": Vector3(0.1, 0, 0), "LeftHand": Vector3(-0.8, 0, -0.2),
		"RightUpperArm": Vector3(2.5, 0, 0.5), "RightLowerArm": Vector3(0.9, 0, 0), "RightHand": Vector3(-0.6, 0, 0),
		"Head": Vector3(-0.3, 0, 0), "Jaw": Vector3(0.5, 0, 0)}


## Head and shoulders breaking the surface: arms spread on the rim, face up, screaming.
static func _p_head() -> Dictionary:
	return {"Head": Vector3(-0.6, 0, 0), "Neck": Vector3(-0.2, 0, 0), "Jaw": Vector3(0.9, 0, 0),
		"LeftUpperArm": Vector3(1.5, 0, -0.9), "RightUpperArm": Vector3(1.5, 0, 0.9),
		"LeftLowerArm": Vector3(0.5, 0, 0), "RightLowerArm": Vector3(0.5, 0, 0),
		"LeftHand": Vector3(-0.5, 0, 0), "RightHand": Vector3(-0.5, 0, 0), "Chest": Vector3(-0.2, 0.15, 0)}


## The chest out, hips at the rim: pushing down on the ground, the torso twisting as one shoulder leads.
static func _p_shoulders() -> Dictionary:
	return {"Chest": Vector3(-0.45, 0.35, 0.1), "Spine": Vector3(-0.25, 0, 0), "Head": Vector3(-0.2, -0.2, 0), "Jaw": Vector3(0.6, 0, 0),
		"LeftUpperArm": Vector3(1.1, 0, -0.5), "RightUpperArm": Vector3(1.1, 0, 0.5),
		"LeftLowerArm": Vector3(0.25, 0, 0), "RightLowerArm": Vector3(0.25, 0, 0),
		"LeftHand": Vector3(-0.3, 0, 0), "RightHand": Vector3(-0.3, 0, 0),
		"RightUpperLeg": Vector3(0.6, 0, -0.05), "RightLowerLeg": Vector3(-1.2, 0, 0)}


## The left elbow planted flat, the trunk rolling over it, the right knee coming up inside the hole.
static func _p_elbow() -> Dictionary:
	return {"Chest": Vector3(-0.6, -0.3, 0.25), "Spine": Vector3(-0.3, 0, 0), "Head": Vector3(-0.3, -0.3, 0), "Jaw": Vector3(0.5, 0, 0),
		"LeftUpperArm": Vector3(1.3, 0, -0.9), "LeftLowerArm": Vector3(1.5, 0, 0), "LeftHand": Vector3(-0.2, 0, 0),
		"RightUpperArm": Vector3(0.9, 0, 0.4), "RightLowerArm": Vector3(0.15, 0, 0), "RightHand": Vector3(-0.4, 0, 0),
		"RightUpperLeg": Vector3(1.5, 0, -0.1), "RightLowerLeg": Vector3(-2.2, 0, 0), "LeftUpperLeg": Vector3(0.1, 0, 0.05)}


## Up on one knee, the right foot planted in front, both hands on the ground.
static func _p_knee() -> Dictionary:
	return {"Chest": Vector3(-0.7, 0, 0), "Spine": Vector3(-0.3, 0, 0), "Head": Vector3(-0.3, 0, 0), "Jaw": Vector3(0.4, 0, 0),
		"LeftUpperArm": Vector3(1.2, 0, -0.45), "RightUpperArm": Vector3(1.2, 0, 0.45),
		"LeftLowerArm": Vector3(0.3, 0, 0), "RightLowerArm": Vector3(0.3, 0, 0),
		"LeftHand": Vector3(-0.2, 0, 0), "RightHand": Vector3(-0.2, 0, 0),
		"RightUpperLeg": Vector3(1.6, 0, -0.1), "RightLowerLeg": Vector3(-1.5, 0, 0), "RightFoot": Vector3(-0.1, 0, 0),
		"LeftUpperLeg": Vector3(0.1, 0, 0.05), "LeftLowerLeg": Vector3(-0.2, 0, 0)}


## The lurch to standing: the right leg extending, the left knee pulled high out of the hole, arms swinging up.
static func _p_stand() -> Dictionary:
	return {"Chest": Vector3(-0.4, 0, 0), "Spine": Vector3(-0.15, 0, 0), "Head": Vector3(-0.2, 0, 0), "Jaw": Vector3(0.4, 0, 0),
		"LeftUpperArm": Vector3(1.5, 0, -0.3), "RightUpperArm": Vector3(1.5, 0, 0.3),
		"LeftLowerArm": Vector3(0.6, 0, 0), "RightLowerArm": Vector3(0.6, 0, 0),
		"RightUpperLeg": Vector3(0.3, 0, -0.05), "RightLowerLeg": Vector3(-0.5, 0, 0),
		"LeftUpperLeg": Vector3(1.0, 0, 0.05), "LeftLowerLeg": Vector3(-1.6, 0, 0), "LeftFoot": Vector3(0.3, 0, 0)}


## The slow variant's sag: stuck at the rim, arms slack, head lolling forward.
static func _p_pause() -> Dictionary:
	return {"Chest": Vector3(-0.3, 0.1, 0), "Spine": Vector3(-0.1, 0, 0), "Head": Vector3(0.45, 0.2, 0.1), "Jaw": Vector3(0.2, 0, 0),
		"LeftUpperArm": Vector3(1.3, 0, -0.6), "RightUpperArm": Vector3(1.3, 0, 0.6),
		"LeftLowerArm": Vector3(0.3, 0, 0), "RightLowerArm": Vector3(0.3, 0, 0)}


## The second heave: a hard jerk up with the right knee driving.
static func _p_heave2() -> Dictionary:
	return {"Chest": Vector3(-0.5, -0.3, 0.1), "Spine": Vector3(-0.2, 0, 0), "Head": Vector3(-0.5, 0, 0), "Jaw": Vector3(0.9, 0, 0),
		"LeftUpperArm": Vector3(1.0, 0, -0.5), "RightUpperArm": Vector3(1.0, 0, 0.5),
		"LeftLowerArm": Vector3(0.2, 0, 0), "RightLowerArm": Vector3(0.2, 0, 0),
		"RightUpperLeg": Vector3(1.3, 0, -0.1), "RightLowerLeg": Vector3(-2.0, 0, 0)}


## The fast variant's lunge out of the hole: body thrown forward, arms reaching.
static func _p_lunge() -> Dictionary:
	return {"Chest": Vector3(-0.5, 0, 0), "Spine": Vector3(-0.2, 0, 0), "Head": Vector3(-0.3, 0, 0), "Jaw": Vector3(0.7, 0, 0),
		"LeftUpperArm": Vector3(1.8, 0, -0.3), "RightUpperArm": Vector3(1.8, 0, 0.3),
		"LeftLowerArm": Vector3(0.5, 0, 0), "RightLowerArm": Vector3(0.5, 0, 0),
		"RightUpperLeg": Vector3(0.5, 0, -0.05), "RightLowerLeg": Vector3(-0.7, 0, 0),
		"LeftUpperLeg": Vector3(0.9, 0, 0.05), "LeftLowerLeg": Vector3(-1.4, 0, 0)}


## Face-first out of the hole: reaching ahead to drag the body out.
static func _p_reach(upper: float, lower: float, spread: float) -> Dictionary:
	return {"Head": Vector3(-0.55, 0, 0), "Neck": Vector3(-0.2, 0, 0), "Jaw": Vector3(0.8, 0, 0),
		"LeftUpperArm": Vector3(upper, 0, -spread), "RightUpperArm": Vector3(upper, 0, spread),
		"LeftLowerArm": Vector3(lower, 0, 0), "RightLowerArm": Vector3(lower, 0, 0),
		"LeftHand": Vector3(-0.5, 0, 0), "RightHand": Vector3(-0.5, 0, 0), "Chest": Vector3(-0.1, 0, 0)}


## On its side after the roll, legs tucking under, the lower arm pushing the ground.
static func _p_side() -> Dictionary:
	return {"Chest": Vector3(-0.3, 0, 0), "Spine": Vector3(-0.15, 0, 0), "Head": Vector3(-0.2, 0.3, 0), "Jaw": Vector3(0.5, 0, 0),
		"LeftUpperArm": Vector3(1.5, 0, -0.3), "LeftLowerArm": Vector3(1.2, 0, 0),
		"RightUpperArm": Vector3(0.6, 0, 0.8), "RightLowerArm": Vector3(0.4, 0, 0),
		"LeftUpperLeg": Vector3(1.2, 0, 0.1), "LeftLowerLeg": Vector3(-1.6, 0, 0),
		"RightUpperLeg": Vector3(1.0, 0, -0.1), "RightLowerLeg": Vector3(-1.4, 0, 0)}


## Kneeling at the rim after the roll: the right knee under, the left foot planted.
static func _p_kneel() -> Dictionary:
	return {"Chest": Vector3(-0.5, 0.1, 0), "Spine": Vector3(-0.2, 0, 0), "Head": Vector3(-0.3, 0, 0), "Jaw": Vector3(0.4, 0, 0),
		"LeftUpperArm": Vector3(0.8, 0, -0.3), "RightUpperArm": Vector3(0.8, 0, 0.3),
		"LeftLowerArm": Vector3(0.2, 0, 0), "RightLowerArm": Vector3(0.2, 0, 0),
		"RightUpperLeg": Vector3(1.3, 0, -0.1), "RightLowerLeg": Vector3(-2.0, 0, 0),
		"LeftUpperLeg": Vector3(0.9, 0, 0.1), "LeftLowerLeg": Vector3(-1.3, 0, 0)}


## Crawler: elbows planted ahead, pulling the trunk out over the rim.
static func _p_elbows_drag() -> Dictionary:
	return {"Head": Vector3(-0.4, 0, 0), "Neck": Vector3(0.3, 0, 0), "Jaw": Vector3(0.7, 0, 0), "Chest": Vector3(-0.3, 0, 0),
		"LeftUpperArm": Vector3(1.7, 0, -0.6), "RightUpperArm": Vector3(1.7, 0, 0.6),
		"LeftLowerArm": Vector3(1.3, 0, 0), "RightLowerArm": Vector3(1.3, 0, 0),
		"LeftHand": Vector3(-0.3, 0, 0), "RightHand": Vector3(-0.3, 0, 0)}


# ------------------------------------------------------------------ the variants' key lists

static func _authored(v: String) -> Array:
	var idle: Dictionary = ZombieClips._idle_pose(0.0)
	match v:
		"fast":
			return [
				_k("bulge", "smooth", 2.35, _p_buried()),
				_k("hand", "burst", 2.0, _p_hand()),
				_k("hand2", "burst", 1.8, _p_hand2()),
				_k("head_out", "heave", 1.3, _p_head()),
				_k("shoulders", "heave", 0.85, _p_shoulders()),
				_k("elbow", "snap", 0.6, _p_elbow()),
				_k("knee", "snap", 0.4, _p_knee()),
				_k("stand", "snap", 0.0, _p_lunge()),
				_k_raw("done", "smooth", idle),
			]
		"slow":
			return [
				_k("bulge", "smooth", 2.35, _p_buried()),
				_k("hand", "burst", 2.05, _p_hand()),
				_k("hand2", "burst", 1.9, _p_hand2()),
				_k("head_out", "heave", 1.4, _p_head()),
				_k("shoulders", "smooth", 1.0, _p_shoulders()),
				_k("pause", "smooth", 1.12, _p_pause()),
				_k("heave2", "heave", 0.7, _p_heave2()),
				_k("elbow", "snap", 0.62, _p_elbow()),
				_k("knee", "smooth", 0.42, _p_knee()),
				_k("stand", "snap", 0.05, _p_stand()),
				_k_raw("done", "smooth", idle),
			]
		"roll":
			return [
				_k("bulge", "smooth", 2.35, _p_buried()),
				_k("hand", "burst", 2.0, _p_hand()),
				_k("hand2", "burst", 1.85, _p_hand2()),
				_k("head_out", "heave", 1.39, _p_reach(2.4, 0.4, 0.5), -0.55),
				_k("shoulders", "heave", 1.05, _p_reach(1.9, 0.9, 0.7), -0.95),
				_k("flat", "smooth", 0.85, _p_reach(2.6, 0.6, 0.6), -1.45),
				_k("roll", "smooth", 0.85, _p_side(), -1.35, -1.4),
				_k("knee", "snap", 0.5, _p_kneel(), -0.5, -0.3),
				_k("stand", "snap", 0.05, _p_stand(), -0.1),
				_k_raw("done", "smooth", idle),
			]
		"crawler":
			var crawl: Dictionary = ZombieClips._crawl_pose("drag", 0.0, false)
			return [
				_k("bulge", "smooth", 2.35, _p_buried()),
				_k("hand", "burst", 2.0, _p_hand()),
				_k("hand2", "burst", 1.85, _p_hand2()),
				_k("head_out", "heave", 1.35, _p_reach(2.3, 0.6, 0.5), -0.45),
				_k("elbow", "snap", 1.1, _p_elbows_drag(), -0.85),
				_k_raw("flat", "smooth", crawl),
				_k_raw("done", "smooth", crawl),
			]
	# standard
	return [
		_k("bulge", "smooth", 2.35, _p_buried()),
		_k("hand", "burst", 2.0, _p_hand()),
		_k("hand2", "burst", 1.88, _p_hand2()),
		_k("head_out", "heave", 1.35, _p_head()),
		_k("shoulders", "smooth", 0.95, _p_shoulders()),
		_k("elbow", "snap", 0.7, _p_elbow()),
		_k("knee", "smooth", 0.45, _p_knee()),
		_k("stand", "snap", 0.05, _p_stand()),
		_k_raw("done", "smooth", idle),
	]


# ------------------------------------------------------------------ procedural layers

## 1 inside [a, b] with soft edges of `edge`, 0 outside.
static func _window(k: float, a: float, b: float, edge: float = 0.04) -> float:
	if b <= a:
		return 0.0
	return clampf((k - a) / edge, 0.0, 1.0) * clampf((b - k) / edge, 0.0, 1.0)


static func _add(r: Dictionary, bone: String, d: Vector3) -> void:
	r[bone] = (r.get(bone, Vector3.ZERO) as Vector3) + d


static func _layers(v: String, k: float, r: Dictionary) -> void:
	var t: float = k * variant_seconds(v)
	var hand: float = stage(v, "hand", 0.1)
	var hand2: float = stage(v, "hand2", 0.25)
	var head: float = stage(v, "head_out", 0.4)
	var shoulders: float = stage(v, "shoulders", stage(v, "elbow", head + 0.12))
	var stand: float = stage(v, "stand", -1.0)
	# clawing: each hand rakes the rim from its burst until the head is out
	var claw_r: float = _window(k, hand, head + 0.06, 0.02)
	var claw_l: float = _window(k, hand2, head + 0.06, 0.02)
	if claw_r > 0.0:
		_add(r, "RightUpperArm", Vector3(sin(t * 13.0) * 0.22 * claw_r, 0, 0))
		_add(r, "RightLowerArm", Vector3((0.5 + 0.5 * sin(t * 13.0 + 1.2)) * 0.35 * claw_r, 0, 0))
		_add(r, "RightHand", Vector3(sin(t * 13.0 + 2.0) * 0.4 * claw_r, 0, 0))
	if claw_l > 0.0:
		_add(r, "LeftUpperArm", Vector3(sin(t * 12.0 + 0.7) * 0.22 * claw_l, 0, 0))
		_add(r, "LeftLowerArm", Vector3((0.5 + 0.5 * sin(t * 12.0 + 1.9)) * 0.35 * claw_l, 0, 0))
		_add(r, "LeftHand", Vector3(sin(t * 12.0 + 2.7) * 0.4 * claw_l, 0, 0))
	# the heave: a strain tremble through the trunk while the head and chest tear free (and the second heave)
	var heave: float = _window(k, hand2 + (head - hand2) * 0.5, shoulders, 0.05)
	var heave2: float = stage(v, "heave2", -1.0)
	if heave2 > 0.0:
		heave = maxf(heave, _window(k, stage(v, "pause", heave2 - 0.1), heave2 + 0.04, 0.03))
	if heave > 0.0:
		_add(r, "Chest", Vector3(sin(t * 31.0) * 0.035 * heave, 0, sin(t * 23.0) * 0.03 * heave))
		_add(r, "Head", Vector3(0, 0, sin(t * 27.0) * 0.05 * heave))
		r["Jaw"] = Vector3(maxf((r.get("Jaw", Vector3.ZERO) as Vector3).x, 0.85 * heave), 0, 0)
	# the slow one hangs at the rim and shudders, head lolling
	var pause_t: float = stage(v, "pause", -1.0)
	if pause_t > 0.0:
		var hang: float = _window(k, pause_t - 0.02, heave2 - 0.02, 0.03)
		if hang > 0.0:
			_add(r, "Head", Vector3(sin(t * 2.3) * 0.12 * hang, 0, sin(t * 1.7) * 0.1 * hang))
			_add(r, "Chest", Vector3(sin(t * 19.0) * 0.02 * hang, 0, 0))
	# the stagger step out of the hole: a dip and a lurch forward that settles into the idle at the end
	if stand > 0.0 and k > stand:
		var f: float = clampf((k - stand) / maxf(0.01, 1.0 - stand), 0.0, 1.0)
		var s: float = sin(f * PI)
		var m: float = 1.8 if v == "fast" else 1.0
		r["hips_pos"] = (r["hips_pos"] as Vector3) + Vector3(0, -0.06 * s * m, -0.14 * s * m)
		_add(r, "Chest", Vector3(-0.25 * s * m, 0.1 * s, 0.08 * s))
		_add(r, "Head", Vector3(-0.2 * s, 0, 0))
		_add(r, "LeftUpperArm", Vector3(0.4 * s * m, 0, -0.15 * s))
		_add(r, "RightUpperArm", Vector3(0.5 * s * m, 0, 0.15 * s))
	# crawlers drag out with alternating pulls once the elbows are planted
	if v == "crawler":
		var drag: float = _window(k, stage(v, "elbow", 0.5), 1.0, 0.03)
		if drag > 0.0:
			var c: float = sin(t * 6.0)
			_add(r, "LeftUpperArm", Vector3(c * 0.4 * drag, 0, 0))
			_add(r, "RightUpperArm", Vector3(-c * 0.4 * drag, 0, 0))
			_add(r, "LeftLowerArm", Vector3(maxf(0.0, -c) * 0.5 * drag, 0, 0))
			_add(r, "RightLowerArm", Vector3(maxf(0.0, c) * 0.5 * drag, 0, 0))
