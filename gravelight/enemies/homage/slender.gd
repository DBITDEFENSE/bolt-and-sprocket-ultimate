class_name Slender
extends HomageBoss
## THE SLENDER, the Hafenwächter (HB3, docs/HOMAGE_BOSSES.md section 6; docs/U10_TOTENHAFEN_DESIGN.md section 9;
## DECISIONS T-160): the Totenhafen pens' night watchman, a tall, thin, calm, kind-faced man who walked the
## catwalks with a lantern and a ring of keys and locked every door behind him on the night of the Erwachen so the
## dead would stay in the pens. The Marke kept him walking. A person, just too long: never faceless, never a suit,
## never anything growing from his back (the originality checklist in T-160).
## Body: the MZ humanoid (ZombieBody "dockworker", thin, male) on the shared rig, about 2.6 m (the pivot scale plus
## longer upper arms and legs through the pose layer), pale with faint violet eyes that never blink; a long
## dark-grey watchman's greatcoat with brass buttons, the collar up, a scarf, a peaked cap; a brass lantern burning
## violet on a short pole (a hitbox: "lantern"), a ring of keys at the hip that jingles as he walks and goes silent
## before he strikes, the watch-book under his arm (a hitbox: "book").
## The Watch system: every player's LOGGED meter (WatchMeter) fed from their senses each step; tier whispers and
## effects; CRITICAL puts him right behind you; 100 quarantines you (SlenderEncounter's Watch Room).
## He can only be damaged while lit (a powered lamp pool, the signal tower's searchlight, a shooter within 5 m,
## frost); in the dark bullets pass through like smoke. The lantern (x2, 3% of max HP) breaks into a 6 s stun and
## relights; the book (2%) is shot out of his hands for a 4 s x1.5 window (then 30 s before it can go again).
## Moves: the Walk (1.6 m/s), the Teleport (15 m closer, only while unobserved), Mirroring, the Lantern Sweep,
## the Key Ring Lash; Shift Change below 50% (two decoys with flickering lanterns); End of Shift below 20%, once
## (every light out for 30 s, the pools off until a fuse box is held 5 s).
## He locks the Pen Hall doors and the pump stair as he walks past; a locked door re-opens for free when he leaves
## its zone, dies or leaves the map.
## Pure rules are static for the tests (lit_by_pools, in_box, door_should_unlock, phase_for).

const COAT: Color = Color(0.24, 0.25, 0.27)
const COAT_DARK: Color = Color(0.18, 0.19, 0.2)
const BRASS: Color = Color(0.72, 0.56, 0.26)
const SCARF: Color = Color(0.33, 0.3, 0.27)
const CAP: Color = Color(0.15, 0.16, 0.18)
const BOOK: Color = Color(0.3, 0.18, 0.1)
const VIOLET: Color = Color(0.7, 0.35, 1.0)
const PALE: Color = Color(1.16, 1.12, 1.2, 1.0)
const LIMB_BONES: PackedStringArray = ["LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"]

enum S { WALK, SWEEP_TELE, SWEEP, LASH_SILENCE, LASH, STUN, BOOK, MIRROR }

var meters: Dictionary = {}          # pid -> WatchMeter
var wphase: int = 1                  # 1, 2 (Shift Change), 3 (End of Shift)
var sstate: S = S.WALK
var lantern_hp: float = 0.0
var book_hp: float = 0.0
var stun_t: float = 0.0
var book_t: float = 0.0
var book_lock_t: float = 0.0
var lit: bool = false
var smoke_hits: int = 0
var lit_hits: int = 0
var lantern_breaks: int = 0
var book_drops: int = 0
var teleports: int = 0
var sweeps: int = 0
var lashes: int = 0
var mirror_stops: int = 0
var locked: Array[BuyDoor] = []
var locks_done: Array[StringName] = []
var unlocks_done: int = 0
var decoys: Array[Node3D] = []
var shift_changes: int = 0
var decoy_hits: int = 0
var end_of_shift_done: bool = false
var dark_t: float = 0.0
var pools_on: Array[bool] = []
var sat: bool = false
var muzzle_lit: bool = false
var _lcfg: Dictionary = {}
var _wcfg: Dictionary = {}
var _route_i: int = 0
var _st: float = 0.0
var _jingle_t: float = 0.0
var _silent: bool = false
var _sweep_dir: Vector3 = Vector3.ZERO
var _sweep_yaw0: float = 0.0
var _crit_seen: Dictionary = {}
var _write_t: float = 6.0
var _decoy_t: float = 0.0
var _shift_dmg: float = 0.0
var _decoy_recast: float = 0.0
var _lantern: Node3D = null
var _lamp: OmniLight3D = null
var _book: Node3D = null
var _keys: Node3D = null
var _observe: ObservedFreeze = ObservedFreeze.new()
var _death_phase: int = 0
var _dark_lights: Array = []          # [Light3D, energy] dimmed by End of Shift
var _exit_i: int = 0
var _hit_shooter: Vector3 = Vector3.INF
var _tier_said: Dictionary = {}       # pid -> highest tier whispered
var _mirror_said: bool = false
var _sweep_hit: Dictionary = {}


func _init() -> void:
	boss_key = "the_slender"


func _ready() -> void:
	super._ready()
	ecfg = GLData.table("bosses/map02")
	bcfg = HomageEncounter.block(ecfg, "the_slender")
	_lcfg = bcfg.get("lights", {})
	_wcfg = bcfg.get("watch", {})


func modelled() -> bool:
	return false


func person_id() -> String:
	return "slender"


# ================================================================== pure rules (unit-tested)

static func in_box(p: Vector3, b: Array) -> bool:
	return b.size() == 6 and p.x >= float(b[0]) and p.y >= float(b[1]) and p.z >= float(b[2]) and p.x <= float(b[3]) and p.y <= float(b[4]) and p.z <= float(b[5])


## True when `p` stands in a lit pool ([x, y, z, r, needs_power]; `on` per pool, `power` the map's power).
static func lit_by_pools(p: Vector3, pools: Array, on: Array, power: bool, height: float = 5.0) -> bool:
	for i: int in pools.size():
		var q: Array = pools[i]
		if i < on.size() and not bool(on[i]):
			continue
		if bool(q[4]) and not power:
			continue
		if Vector2(p.x - float(q[0]), p.z - float(q[2])).length() <= float(q[3]) and p.y >= float(q[1]) - 1.0 and p.y <= float(q[1]) + height:
			return true
	return false


## A door he locked opens again once he is out of every one of its boxes and farther than unlock_m from it.
static func door_should_unlock(him: Vector3, door_pos: Vector3, boxes: Array, unlock_m: float) -> bool:
	for b: Variant in boxes:
		if in_box(him, b as Array):
			return false
	return him.distance_to(door_pos) > unlock_m


## The fight's phase from his HP fraction: 1, 2 (below 50%: Shift Change), 3 (below 20%: End of Shift).
static func phase_for(frac: float, moves: Dictionary) -> int:
	if frac < float((moves.get("end_of_shift", {}) as Dictionary).get("phase_at", 0.2)):
		return 3
	if frac < float((moves.get("shift_change", {}) as Dictionary).get("phase_at", 0.5)):
		return 2
	return 1


## True when a SpotLight3D's cone reaches `p` (range, angle; no occlusion test).
static func in_spot(light: SpotLight3D, p: Vector3) -> bool:
	if light == null or not light.is_visible_in_tree() or light.light_energy <= 0.01:
		return false
	var d: Vector3 = p - light.global_position
	if d.length() > light.spot_range:
		return false
	var fwd: Vector3 = -light.global_transform.basis.z
	return rad_to_deg(fwd.angle_to(d.normalized())) <= light.spot_angle


# ================================================================== spawn and the body

func _on_spawned() -> void:
	enemy_id = &"the_slender"
	_female = false
	_build = "thin"
	_body.mesh = ZombieBody.build_skinned("dockworker", "thin", false)
	_set_inst("inst_tint", PALE)
	_set_inst("inst_dirt", 0.15)
	_look.primary_limit_angle = deg_to_rad(95.0)
	var wp: Dictionary = bcfg.get("weak_points", {})
	lantern_hp = max_hp * float(wp.get("lantern_fraction", 0.03))
	book_hp = max_hp * float(wp.get("book_fraction", 0.02))
	pools_on.clear()
	for i: int in (_lcfg.get("pools", []) as Array).size():
		pools_on.append(true)
	meters.clear()
	_tier_said.clear()
	_crit_seen.clear()
	wphase = 1
	sstate = S.WALK
	stun_t = 0.0
	book_t = 0.0
	book_lock_t = 0.0
	sat = false
	end_of_shift_done = false
	_death_phase = 0
	_observe.include_bots = true
	_neutral()
	_pose.snap()
	if _lamp != null:
		_lamp.light_energy = 1.6


## The long limbs and the neutral shape: the pose layer keeps the upper arms and legs lengthened at all times.
func _neutral() -> void:
	for b: String in ["Spine", "Chest", "Head", "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg", "Hips"]:
		_pose.set_bone(b)
	var ls: float = float(bcfg.get("limb_scale", 1.12))
	for b2: String in LIMB_BONES:
		_pose.set_bone(b2, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, ls, 1.0))
	_pose.set_bone("Head", Vector3(0, 0, 0.22))   # the slow, curious, observing tilt
	_pose.set_bone("RightUpperArm", Vector3(0.5, 0, -0.1), Vector3.ZERO, Vector3(1.0, ls, 1.0))   # the lantern held out a little
	_pose.set_bone("LeftUpperArm", Vector3(0.15, 0, 0.12), Vector3.ZERO, Vector3(1.0, ls, 1.0))  # the book under the arm


func _arm(bone: String, rot: Vector3) -> void:
	_pose.set_bone(bone, rot, Vector3.ZERO, Vector3(1.0, float(bcfg.get("limb_scale", 1.12)), 1.0))


func _build_costume() -> void:
	# the long greatcoat: skirts to mid-shin, buttoned, collar up; nothing on his back but cloth
	costume("Chest", [
		cyl(0.21, 0.19, 0.42, Vector3(0, 0.12, 0), COAT),
		cyl(0.11, 0.15, 0.14, Vector3(0, 0.38, 0.01), COAT_DARK),   # the collar, up
		cyl(0.12, 0.13, 0.07, Vector3(0, 0.33, 0.0), SCARF),
		sph(0.018, Vector3(0, 0.25, -0.2), BRASS), sph(0.018, Vector3(0, 0.15, -0.205), BRASS),
		sph(0.018, Vector3(0, 0.05, -0.2), BRASS), sph(0.018, Vector3(0, -0.05, -0.19), BRASS),
	])
	costume("Hips", [
		cyl(0.2, 0.27, 0.62, Vector3(0, -0.22, 0.0), COAT),
		sph(0.018, Vector3(0, 0.0, -0.21), BRASS), sph(0.018, Vector3(0, -0.12, -0.23), BRASS),
		boxp(Vector3(0.42, 0.05, 0.3), Vector3(0, 0.05, 0), COAT_DARK),   # the belt
	])
	for side: String in ["Left", "Right"]:
		costume(side + "UpperLeg", [cyl(0.13, 0.15, 0.46, Vector3(0, -0.22, 0), COAT)])
		costume(side + "UpperArm", [cyl(0.075, 0.07, 0.34, Vector3(0, -0.15, 0), COAT)])
		costume(side + "LowerArm", [cyl(0.07, 0.065, 0.36, Vector3(0, -0.16, 0), COAT), cyl(0.075, 0.075, 0.05, Vector3(0, -0.3, 0), COAT_DARK)])
	# the peaked watchman's cap and the violet eyes (a real, tired face: the body's face stays visible)
	costume("Head", [
		cyl(0.12, 0.125, 0.07, Vector3(0, 0.15, 0.0), CAP),
		boxp(Vector3(0.2, 0.012, 0.09), Vector3(0, 0.12, -0.12), CAP, Vector3(-0.2, 0, 0)),   # the peak
		boxp(Vector3(0.18, 0.02, 0.012), Vector3(0, 0.14, -0.123), BRASS),   # the badge band
	])
	costume("Head", [sph(0.012, Vector3(-0.035, 0.05, -0.105), VIOLET), sph(0.012, Vector3(0.035, 0.05, -0.105), VIOLET)], 2.5)
	# the lantern on its short pole in the right hand
	var hand: BoneAttachment3D = bone_attachment("RightHand")
	_lantern = Node3D.new()
	_lantern.name = "Lantern"
	hand.add_child(_lantern)
	var pole: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 0.7
	pole.mesh = cm
	pole.material_override = mat(Color(0.3, 0.22, 0.14))
	pole.position = Vector3(0, -0.2, -0.05)
	_lantern.add_child(pole)
	var cage: MeshInstance3D = MeshInstance3D.new()
	var st: SurfaceTool = SurfaceTool.new()
	var lm: ArrayMesh = ArrayMesh.new()
	for p: Array in [boxp(Vector3(0.14, 0.02, 0.14), Vector3(0, -0.55, -0.05), BRASS), boxp(Vector3(0.12, 0.02, 0.12), Vector3(0, -0.76, -0.05), BRASS),
			cyl(0.01, 0.01, 0.2, Vector3(0.06, -0.66, 0.01), BRASS), cyl(0.01, 0.01, 0.2, Vector3(-0.06, -0.66, -0.11), BRASS)]:
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
	st.commit(lm)
	lm.surface_set_material(0, mat(BRASS, 0.0, 0.4))
	cage.mesh = lm
	_lantern.add_child(cage)
	var glass: MeshInstance3D = MeshInstance3D.new()
	var gm: BoxMesh = BoxMesh.new()
	gm.size = Vector3(0.1, 0.18, 0.1)
	glass.mesh = gm
	glass.material_override = mat(VIOLET, 3.0, 0.2)
	glass.position = Vector3(0, -0.66, -0.05)
	glass.name = "Glass"
	_lantern.add_child(glass)
	_lamp = OmniLight3D.new()
	_lamp.light_color = VIOLET
	_lamp.omni_range = float(_wcfg.get("pool_radius", 8.0))
	_lamp.light_energy = 1.6
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0, -0.66, -0.05)
	_lantern.add_child(_lamp)
	var lhb: Hitbox = Hitbox.new()
	lhb.name = "LanternHit"
	lhb.setup(self, &"lantern", Vector3(0.18, 0.26, 0.18))
	lhb.bone = "RightHand"
	lhb.position = Vector3(0, -0.66, -0.05)
	_lantern.add_child(lhb)
	_hitboxes.append(lhb)
	# the ring of keys at the left hip
	var hip: BoneAttachment3D = bone_attachment("Hips")
	_keys = Node3D.new()
	_keys.name = "Keys"
	hip.add_child(_keys)
	var kparts: Array = []
	for i: int in 10:
		var a: float = TAU * float(i) / 10.0
		kparts.append(cyl(0.006, 0.006, 0.035, Vector3(cos(a) * 0.06, sin(a) * 0.06, 0), BRASS, Vector3(0, 0, a + PI * 0.5), Vector3.ONE, 5))
	for j: int in 6:
		kparts.append(boxp(Vector3(0.012, 0.07, 0.004), Vector3(-0.04 + 0.016 * float(j), -0.09, 0.0), Color(0.55, 0.5, 0.42), Vector3(0, 0, 0.15 * float(j - 3))))
	var km: MeshInstance3D = costume("Hips", kparts)
	if km != null:
		km.reparent(_keys, false)
	_keys.position = Vector3(-0.22, -0.08, -0.02)
	# the watch-book under the left arm
	var chest: BoneAttachment3D = bone_attachment("LeftUpperArm")
	_book = Node3D.new()
	_book.name = "WatchBook"
	chest.add_child(_book)
	var bm: MeshInstance3D = MeshInstance3D.new()
	var bb: BoxMesh = BoxMesh.new()
	bb.size = Vector3(0.05, 0.26, 0.2)
	bm.mesh = bb
	bm.material_override = mat(BOOK)
	_book.add_child(bm)
	_book.position = Vector3(0.09, -0.16, 0.0)
	var bhb: Hitbox = Hitbox.new()
	bhb.name = "BookHit"
	bhb.setup(self, &"book", Vector3(0.1, 0.3, 0.24))
	bhb.bone = "LeftUpperArm"
	_book.add_child(bhb)
	_hitboxes.append(bhb)


func move_speed() -> float:
	return float(bcfg.get("speed", 1.6)) * squad_speed_mult


# ================================================================== the brain

func _tick(delta: float) -> void:
	_st += delta
	_update_lit()
	_tick_meters(delta)
	_tick_doors()
	_tick_phase(delta)
	_tick_decoys(delta)
	_tick_dark(delta)
	_tick_keys(delta)
	if book_lock_t > 0.0:
		book_lock_t -= delta
	if stun_t > 0.0:
		stun_t -= delta
		stand(delta, false)
		# groping in the dark
		_arm("LeftUpperArm", Vector3(1.2 + 0.3 * sin(_st * 4.0), 0, 0.3))
		_arm("RightUpperArm", Vector3(1.0 + 0.3 * cos(_st * 3.0), 0, -0.3))
		if stun_t <= 0.0:
			_relight_lantern()
		return
	if book_t > 0.0:
		book_t -= delta
		stand(delta, false)
		_pose.set_bone("Spine", Vector3(0.9, 0, 0))
		_arm("RightUpperArm", Vector3(1.6, 0, 0))
		if book_t <= 0.0:
			if _book != null:
				_book.show()
			book_lock_t = float((bcfg.get("weak_points", {}) as Dictionary).get("book_lock", 30.0))
			_neutral()
			sstate = S.WALK
		return
	match sstate:
		S.SWEEP_TELE:
			stand(delta)
			_arm("RightUpperArm", Vector3(lerpf(0.5, 2.6, clampf(_st / 1.0, 0.0, 1.0)), 0, -0.1))
			if _lamp != null:
				_lamp.light_energy = lerpf(1.6, 6.0, clampf(_st / 1.0, 0.0, 1.0))
			if _st >= tele_len(float(_mv("sweep").get("telegraph", 1.0))):
				sstate = S.SWEEP
				_st = 0.0
				_sweep_yaw0 = _pivot.rotation.y + deg_to_rad(float(_mv("sweep").get("arc_deg", 90.0)) * 0.5)
				_sweep_hit.clear()
				say("SLN_SWEEP_01")
		S.SWEEP:
			_halt(delta)
			var dur: float = float(_mv("sweep").get("active", 2.0))
			_pivot.rotation.y = _sweep_yaw0 - deg_to_rad(float(_mv("sweep").get("arc_deg", 90.0))) * clampf(_st / dur, 0.0, 1.0)
			if _st >= dur:
				sstate = S.WALK
				_neutral()
				if _lamp != null:
					_lamp.light_energy = 1.6
				set_cd("sweep", float(_mv("sweep").get("cooldown", 12.0)))
		S.LASH_SILENCE:
			stand(delta)
			_arm("LeftUpperArm", Vector3(0.4, 0, 0.5))   # the hand closes over the keys
			if _st >= float(_mv("lash").get("silence", 0.6)):
				sstate = S.LASH
				_st = 0.0
				_arm("RightUpperArm", Vector3(1.2, 0, 1.4))   # the backswing
		S.LASH:
			stand(delta)
			if _st >= float(_mv("lash").get("backswing", 0.4)) and not _hit_done:
				_hit_done = true
				attack_anim("swipe_r", 0.1)
				lashes += 1
				var m: Dictionary = _mv("lash")
				for p: Player in alive_players():
					if dist_to(p) <= float(m.get("range", 4.0)) and _facing(p, 80.0):
						hit_player(p, float(m.get("damage", 85)))
						p.apply_status(&"knockdown", float(m.get("stagger", 0.6)))
			if _st >= 0.9:
				_silent = false
				sstate = S.WALK
				_neutral()
				set_cd("lash", float(_mv("lash").get("cooldown", 4.0)))
		_:
			_think(delta)


func _mv(id: String) -> Dictionary:
	return (bcfg.get("moves", {}) as Dictionary).get(id, {})


func _think(delta: float) -> void:
	if target == null:
		_patrol(delta)
		return
	var dist: float = dist_to(target)
	var los: bool = has_los(target, 2.4, 1.3)
	var sight: float = float(_wcfg.get("sight_m", 40.0))
	# the Key Ring Lash: the keys go silent first (silence is the telegraph)
	if dist <= float(_mv("lash").get("range", 4.0)) and cd_ready("lash"):
		sstate = S.LASH_SILENCE
		_st = 0.0
		_hit_done = false
		_silent = true
		_face(target.global_position)
		if target.character_id == &"deacon":
			say("DEA_SLENDER_02")
		return
	if dist <= float(_mv("sweep").get("range", 18.0)) and los and cd_ready("sweep"):
		sstate = S.SWEEP_TELE
		_st = 0.0
		sweeps += 1
		moves_used["sweep"] = int(moves_used.get("sweep", 0)) + 1
		_face(target.global_position)
		sfx("glass_harmonic" if AudioDirector.has_sound("glass_harmonic") else "screamer_hum", -2.0, 1.6)
		return
	# the Teleport: only while nobody is watching, 15 m closer
	var observed: bool = _observe.update(delta, self, look_points())
	if not observed and dist > float(_mv("teleport").get("min_range", 12.0)) and cd_ready("teleport"):
		_teleport_toward(target.global_position, float(_mv("teleport").get("distance", 15.0)))
		return
	# Mirroring: in sight within 30 m, you stop, he stops
	if los and dist <= float(_mv("mirror").get("range", 30.0)) and target.velocity.length() < 0.3:
		if sstate != S.MIRROR:
			sstate = S.MIRROR
			mirror_stops += 1
			if not _mirror_said:
				_mirror_said = true
				say("SLN_MIRROR_01")
				if target.character_id == &"wren":
					get_tree().create_timer(2.0).timeout.connect(say.bind("WRN_SLENDER_01"))
		stand(delta)
		return
	if sstate == S.MIRROR:
		sstate = S.WALK
	if dist > sight and not los:
		_patrol(delta)
		return
	walk_to(target.global_position, delta)


## His rounds: the pen hall's catwalks, the pump stair and the quay.
func _patrol(delta: float) -> void:
	var pts: Array = (bcfg.get("route", {}) as Dictionary).get("points", [])
	if pts.is_empty():
		stand(delta, false)
		return
	var goal: Vector3 = _v(pts[_route_i % pts.size()])
	if global_position.distance_to(goal) < 1.5:
		_route_i += 1
	walk_to(goal, delta)


func _teleport_toward(to: Vector3, d: float) -> void:
	var dir: Vector3 = to - global_position
	dir.y = 0.0
	var step: float = minf(d, maxf(0.0, dir.length() - 4.0))
	var dest: Vector3 = _snap_nav(global_position + dir.normalized() * step)
	sfx("keys_jingle" if AudioDirector.has_sound("keys_jingle") else "shell_ping", -2.0, 0.8)
	global_position = dest
	velocity = Vector3.ZERO
	teleports += 1
	set_cd("teleport", float(_mv("teleport").get("cooldown", 4.0)))
	sfx("keys_jingle" if AudioDirector.has_sound("keys_jingle") else "shell_ping", -2.0, 0.9)


## Right behind a player (CRITICAL: the one teleport that happens even when observed).
func appear_behind(p: Player) -> void:
	var back: Vector3 = p.global_transform.basis.z
	back.y = 0.0
	global_position = _snap_nav(p.global_position + back.normalized() * 1.6)
	_face(p.global_position)
	teleports += 1


func _facing(p: Node3D, half_deg: float) -> bool:
	var d: Vector3 = p.global_position - global_position
	d.y = 0.0
	var f: Vector3 = -_pivot.global_transform.basis.z
	f.y = 0.0
	return d.length() < 0.5 or rad_to_deg(absf(f.angle_to(d))) <= half_deg


func _snap_nav(p: Vector3) -> Vector3:
	var w: World3D = get_world_3d()
	if w == null:
		return p
	var c: Vector3 = NavigationServer3D.map_get_closest_point(w.navigation_map, p)
	return c if c.distance_to(p) < 6.0 else p


# ================================================================== the Watch system

func meter(pid: int) -> WatchMeter:
	return meters.get(pid, null)


func _tick_meters(delta: float) -> void:
	var room_busy: bool = event != null and event.has_method("room_busy") and bool(event.call("room_busy"))
	var high_any: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		if event != null and event.has_method("in_room") and bool(event.call("in_room", p.player_id)):
			continue
		var m: WatchMeter = meters.get(p.player_id, null)
		if m == null:
			m = WatchMeter.new(_wcfg, p.is_bot)
			meters[p.player_id] = m
		var s: Dictionary = senses(p)
		var due: bool = m.tick(delta, s, room_busy)
		_tier_fx(p, m)
		if m.tier >= WatchMeter.Tier.HIGH:
			high_any = true
		if m.tier == WatchMeter.Tier.CRITICAL and not _crit_seen.get(p.player_id, false) and not room_busy:
			_crit_seen[p.player_id] = true
			appear_behind(p)
		elif m.tier < WatchMeter.Tier.CRITICAL:
			_crit_seen.erase(p.player_id)
		if due and event != null and event.has_method("quarantine"):
			event.call("quarantine", p)
	# writing in the book while walking when anyone is at HIGH (the pen scratch)
	_write_t -= delta
	if high_any and _write_t <= 0.0:
		_write_t = 9.0
		say("SLN_WRITE_01" if randf() < 0.5 else "SLN_WRITE_02")


## What a player's senses say about him this step (WatchMeter.rate's inputs).
func senses(p: Player) -> Dictionary:
	var to_p: Vector3 = p.global_position - global_position
	var d: float = to_p.length()
	var sight: float = float(_wcfg.get("sight_m", 40.0))
	var los: bool = d <= sight and has_los(p, 2.4, 1.3)
	var pool: bool = los and d <= float(_wcfg.get("pool_radius", 8.0)) and _lantern_lit()
	var sweep: bool = false
	if sstate == S.SWEEP and los:
		var f: Vector3 = -_pivot.global_transform.basis.z
		f.y = 0.0
		var flat: Vector3 = Vector3(to_p.x, 0, to_p.z)
		sweep = flat.length() <= float(_mv("sweep").get("length", 20.0)) and rad_to_deg(absf(f.angle_to(flat))) <= float(_mv("sweep").get("cone_deg", 70.0)) * 0.5
	var looking: bool = false
	if los and p.camera != null:
		var cf: Vector3 = -p.camera.global_transform.basis.z
		var tohim: Vector3 = (global_position + Vector3.UP * 2.0) - p.camera.global_position
		looking = rad_to_deg(cf.angle_to(tohim)) <= float(_wcfg.get("look_cone_deg", 12.0))
	var lit_p: bool = point_lit(p.global_position)
	var mate: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var o: Player = n as Player
		if o != null and o != p and o.is_alive() and o.global_position.distance_to(p.global_position) <= float(_wcfg.get("teammate_m", 6.0)):
			mate = true
			break
	return {"pool": pool, "sweep": sweep, "seen": los, "looking": looking, "moving": p.velocity.length() > 0.3,
		"dark": not lit_p, "lit": lit_p, "teammate": mate}


## The tier words and the creeping effects (all scale with "reduce screen effects" through the status FX).
func _tier_fx(p: Player, m: WatchMeter) -> void:
	var said: int = int(_tier_said.get(p.player_id, 0))
	if m.tier > said:
		_tier_said[p.player_id] = m.tier
		if p.is_local and not p.is_bot:
			say(WatchMeter.TIER_LINES[m.tier])
		if m.tier == WatchMeter.Tier.HIGH and p.character_id == &"dutch" and p.is_local:
			say("DUT_SLENDER_02")
	elif m.tier < said:
		_tier_said[p.player_id] = m.tier
	if m.tier >= WatchMeter.Tier.MEDIUM and (p.is_local or p.is_bot):
		p.apply_status(&"logged", 0.25)


## Shots in the echoing pen hall log the shooter (SlenderEncounter forwards GLBus.weapon_fired).
func on_shot(pid: int, at: Vector3) -> void:
	var m: WatchMeter = meters.get(pid, null)
	if m == null:
		return
	for z: Variant in _wcfg.get("noisy_zones", []):
		var zone: String = str(z)
		if zone == "D_PENHALL" and in_box(at, [-20.0, -0.5, 33.0, 52.0, 7.0, 84.0]):
			m.on_shot()


# ================================================================== light: the only way to hurt him

func _lantern_lit() -> bool:
	return stun_t <= 0.0 and _death_phase == 0


## Real light at a point: a powered pool that is on (not out for End of Shift), a searchlight's cone.
func point_lit(p: Vector3) -> bool:
	if dark_t > 0.0:
		return false
	if lit_by_pools(p, _lcfg.get("pools", []), pools_on, GameState.power_on, float(_lcfg.get("pool_height", 5.0))):
		return true
	for path: Variant in _lcfg.get("searchlight_nodes", []):
		var m: Node = _map_root()
		var l: SpotLight3D = m.get_node_or_null("Dressing/" + str(path)) as SpotLight3D if m != null else null
		if l == null and m != null:
			l = m.find_child(str(path).get_file(), true, false) as SpotLight3D
		if in_spot(l, p):
			return true
	for n: Node in get_tree().get_nodes_in_group(&"searchlights"):
		if n.has_method("lights_point") and bool(n.call("lights_point", p)):
			return true
	for f: Node in get_tree().get_nodes_in_group(&"flares"):
		var fl: Node3D = f as Node3D
		if fl != null and fl.global_position.distance_to(p) <= float(fl.get_meta("light_radius", 12.0)):
			return true
	return false


func _update_lit() -> void:
	lit = point_lit(global_position + Vector3.UP * 1.2) or _frost_t > 0.0


func is_lit() -> bool:
	return lit


## The lantern pip on his bar: lit amber when he can be hurt.
func gauge_value() -> float:
	return 1.0 if lit else 0.0


func _map_root() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n


# ================================================================== damage

func damage_taken_mult() -> float:
	if book_t > 0.0:
		return float((bcfg.get("weak_points", {}) as Dictionary).get("book_mult", 1.5))
	return 1.0


func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	if puppet:
		return super.take_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)
	if not is_active() or retreating:
		return false
	var wp: Dictionary = bcfg.get("weak_points", {})
	if limb == &"decoy":
		if by_player > 0:
			on_decoy_shot(by_player)
		return false
	if limb == &"lantern":
		if stun_t > 0.0:
			return false
		lantern_hp -= amount
		if event != null and event.has_method("on_lantern_hit"):
			event.call("on_lantern_hit", by_player)
		if lantern_hp <= 0.0:
			_break_lantern()
		return super.take_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)
	if limb == &"book":
		if book_t > 0.0 or book_lock_t > 0.0:
			return false
		book_hp -= amount
		if book_hp <= 0.0:
			_drop_book()
		return false
	# in the dark, bullets pass through him like smoke
	var near: bool = false
	var shooter: Vector3 = _attacker_pos(by_player)
	if shooter != Vector3.INF and shooter.distance_to(global_position) <= float(wp.get("muzzle_m", 5.0)) and kind == &"bullet":
		near = true
	if not (lit or near or kind == &"world" or kind == &"debug"):
		smoke_hits += 1
		_smoke_puff()
		if smoke_hits == 1 and event != null and event.has_method("on_smoke_hit"):
			event.call("on_smoke_hit")
		return false
	lit_hits += 1
	if not decoys.is_empty():
		_shift_dmg += amount
		if _shift_dmg >= max_hp * float(_mv("shift_change").get("break_fraction", 0.05)):
			_clear_decoys()
	return super.take_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)


func _attacker_pos(pid: int) -> Vector3:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p.global_position
	return Vector3.INF


func _smoke_puff() -> void:
	sfx("impact_soft" if AudioDirector.has_sound("impact_soft") else "shell_ping", -8.0, 0.6)


## No flinch: he is patient (the small stagger is in the anim list as a reaction only to the lantern break).
func _play_flinch(_limb: StringName, _side: String) -> void:
	pass


func _break_lantern() -> void:
	var wp: Dictionary = bcfg.get("weak_points", {})
	stun_t = float(wp.get("lantern_stun", 6.0))
	lantern_breaks += 1
	sstate = S.STUN
	_silent = false
	if _lamp != null:
		_lamp.light_energy = 0.0
	var g: Node = _lantern.get_node_or_null("Glass") if _lantern != null else null
	if g != null:
		(g as Node3D).hide()
	sfx("glass_shatter" if AudioDirector.has_sound("glass_shatter") else "impact_flesh", 2.0, 1.2)
	say("SLN_LANTERN_01")
	print("[slender] the lantern breaks: stunned %.0f s" % stun_t)


func _relight_lantern() -> void:
	lantern_hp = max_hp * float((bcfg.get("weak_points", {}) as Dictionary).get("lantern_fraction", 0.03))
	if _lamp != null:
		_lamp.light_energy = 1.6
	var g: Node = _lantern.get_node_or_null("Glass") if _lantern != null else null
	if g != null:
		(g as Node3D).show()
	_neutral()
	sstate = S.WALK


func _drop_book() -> void:
	var wp: Dictionary = bcfg.get("weak_points", {})
	book_t = float(wp.get("book_window", 4.0))
	book_drops += 1
	book_hp = max_hp * float(wp.get("book_fraction", 0.02))
	if _book != null:
		_book.hide()
	say("SLN_BOOK_01")
	print("[slender] the book is shot out of his hands: x1.5 for %.0f s" % book_t)


# ================================================================== doors

## Locks the listed doors within lock_radius as he passes; re-opens each for free once he leaves its zone.
func _tick_doors() -> void:
	var dc: Dictionary = bcfg.get("doors", {})
	var m: Node = _map_root()
	if m == null:
		return
	for e: Variant in dc.get("list", []):
		var spec: Dictionary = e
		var d: BuyDoor = m.find_child(str(spec.get("node", "")), true, false) as BuyDoor
		if d == null:
			continue
		if not d.boss_locked:
			if d.global_position.distance_to(global_position) <= float(dc.get("lock_radius", 4.5)) and not _player_in_doorway(d):
				lock_door(d)
		elif locked.has(d) and door_should_unlock(global_position, d.global_position, spec.get("boxes", []), float(dc.get("unlock_m", 9.0))):
			unlock_door(d)


func lock_door(d: BuyDoor) -> void:
	if d == null or d.boss_locked:
		return
	d.boss_lock()
	locked.append(d)
	locks_done.append(StringName(d.name))
	sfx("key_turn" if AudioDirector.has_sound("key_turn") else "door_creak", 2.0, 0.7, d.global_position + Vector3.UP)
	print("[slender] locks %s" % d.name)


func unlock_door(d: BuyDoor) -> void:
	if d == null or not d.boss_locked:
		return
	d.boss_unlock()
	locked.erase(d)
	unlocks_done += 1
	print("[slender] %s opens again" % d.name)


func unlock_all() -> void:
	for d: BuyDoor in locked.duplicate():
		if is_instance_valid(d):
			unlock_door(d)
	locked.clear()


func _player_in_doorway(d: BuyDoor) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Node3D = n as Node3D
		if p != null and p.global_position.distance_to(d.global_position) < 1.6:
			return true
	return false


# ================================================================== phases: Shift Change, End of Shift

func _tick_phase(_delta: float) -> void:
	var ph: int = phase_for(hp_fraction(), bcfg.get("moves", {}))
	if ph > wphase:
		wphase = ph
		if ph >= 2 and shift_changes == 0:
			shift_change()
		if ph >= 3 and not end_of_shift_done:
			end_of_shift()


func shift_change() -> void:
	_clear_decoys()
	shift_changes += 1
	_shift_dmg = 0.0
	var sc: Dictionary = _mv("shift_change")
	_decoy_t = float(sc.get("seconds", 25.0))
	_decoy_recast = float(sc.get("recast", 40.0))
	for i: int in int(sc.get("decoys", 2)):
		var dcy: SlenderDecoy = SlenderDecoy.new()
		dcy.boss = self
		dcy.name = "SlenderDecoy%d" % i
		get_parent().add_child(dcy)
		var side: Vector3 = Vector3(cos(TAU * float(i) / 2.0), 0, sin(TAU * float(i) / 2.0)) * 5.0
		dcy.global_position = _snap_nav(global_position + side)
		decoys.append(dcy)
	say("SLN_DECOY_01")
	if event != null and event.has_method("on_shift_change"):
		event.call("on_shift_change")
	print("[slender] Change of shift: %d decoys" % decoys.size())


func _tick_decoys(delta: float) -> void:
	if decoys.is_empty():
		if wphase >= 2 and shift_changes > 0:
			_decoy_recast -= delta
			if _decoy_recast <= 0.0:
				shift_change()
		return
	_decoy_t -= delta
	_decoy_recast -= delta
	if _decoy_t <= 0.0:
		_clear_decoys()


func _clear_decoys() -> void:
	for d: Node3D in decoys:
		if is_instance_valid(d):
			d.queue_free()
	decoys.clear()


## A decoy was shot: +15 LOGGED to the shooter.
func on_decoy_shot(pid: int) -> void:
	decoy_hits += 1
	var m: WatchMeter = meters.get(pid, null)
	if m != null:
		m.on_decoy_hit()
	say("SLN_DECOY_SHOT_01")


## Lights out: every light on the map dims for 30 s and the pools stay off until a fuse box is held.
func end_of_shift() -> void:
	end_of_shift_done = true
	var eos: Dictionary = _mv("end_of_shift")
	dark_t = float(eos.get("dark_seconds", 30.0))
	for i: int in pools_on.size():
		pools_on[i] = false
	_dark_lights.clear()
	var m: Node = _map_root()
	if m != null:
		for l: Node in m.find_children("*", "Light3D", true, false):
			var light: Light3D = l as Light3D
			if light == null or light == _lamp or light is DirectionalLight3D or is_ancestor_of(light):
				continue
			if light.light_energy > 0.0:
				_dark_lights.append([light, light.light_energy])
				light.light_energy = 0.0
	say("SLN_DARK_01")
	if event != null and event.has_method("on_end_of_shift"):
		event.call("on_end_of_shift")
	print("[slender] End of Shift: %d lights out, the pools off" % _dark_lights.size())


func _tick_dark(delta: float) -> void:
	if dark_t <= 0.0:
		return
	dark_t -= delta
	if dark_t <= 0.0:
		# the 30 s are over: the other lights come back; the pools stay off until their fuse box is held
		for e: Array in _dark_lights:
			if is_instance_valid(e[0]):
				(e[0] as Light3D).light_energy = float(e[1])
		_dark_lights.clear()


## A fuse box was held 5 s: its pools light again (and he can be hurt in them).
func relight_pools(indices: Array) -> void:
	for i: Variant in indices:
		if int(i) < pools_on.size():
			pools_on[int(i)] = true


func _tick_keys(delta: float) -> void:
	_jingle_t -= delta
	if _silent or velocity.length() < 0.2:
		return
	if _jingle_t <= 0.0:
		_jingle_t = 0.55
		sfx("keys_jingle" if AudioDirector.has_sound("keys_jingle") else "shell_ping", -10.0, randf_range(1.4, 1.7))


## Dev / smoke: walk him to a point now (bypassing the brain for `seconds`).
func debug_walk_to(p: Vector3) -> void:
	global_position = _snap_nav(p)
	velocity = Vector3.ZERO


func debug_sweep() -> void:
	target = _nearest_player()
	_cds.erase("sweep")
	sstate = S.SWEEP_TELE
	_st = 0.0
	sweeps += 1
	if target != null:
		_face(target.global_position)


# ================================================================== the fail-safe and the death

func _on_retreat() -> void:
	say("SLN_LEAVE_01")
	_clear_decoys()
	unlock_all()
	_exit_i = 0
	collision_mask = 0


## He walks to the quay's surf steps and off the edge into the storm.
func _tick_retreat(delta: float) -> void:
	var pts: Array = (bcfg.get("exit", {}) as Dictionary).get("points", [])
	if _exit_i >= pts.size():
		_vanish()
		return
	var goal: Vector3 = _v(pts[_exit_i])
	var d: Vector3 = goal - global_position
	var spd: float = 5.0 if _exit_i == 0 else 1.6
	if d.length() < 0.3:
		_exit_i += 1
		return
	_face(goal)
	global_position += d.normalized() * minf(d.length(), spd * delta)
	velocity = Vector3.ZERO
	if _bt > 40.0:
		_vanish()


func _start_authored_death() -> void:
	_death_phase = 1
	_clear_decoys()
	unlock_all()
	_tree_play("Spawn", "idle", 1.0)
	_pose.set_bone("Head", Vector3(-0.6, 0, 0))   # he looks at the sky
	print("[slender] he stops and looks at the sky")


## The death (section 6.8): the sky; the book closed and set down; the lantern on top; blown out; the last line;
## he sits down against the pillar and stays there, at peace, for the rest of the match. Nothing targets him.
func _death_tick(_delta: float) -> void:
	var t: float = _death_t
	if t >= 2.0 and _death_phase == 1:
		_death_phase = 2
		_arm("LeftUpperArm", Vector3(1.2, 0, 0.3))   # closes the book
		_pose.set_bone("Spine", Vector3(0.5, 0, 0))
	if t >= 3.5 and _death_phase == 2:
		_death_phase = 3
		_set_down_props()
	if t >= 5.0 and _death_phase == 3:
		_death_phase = 4
		if _lamp != null:
			_lamp.light_energy = 0.0   # blown out
		sfx("lantern_out" if AudioDirector.has_sound("lantern_out") else "door_creak", -4.0, 1.6)
		say("SLN_DEATH_01")
	if t >= 7.5 and _death_phase == 4:
		_death_phase = 5
		sat = true
		_pose.set_bone("Spine", Vector3(-0.2, 0, 0))
		_pose.set_bone("Head", Vector3(0.35, 0, 0.15))   # eyes closed, head down a little
		_pose.set_bone("LeftUpperLeg", Vector3(1.5, 0, 0.1))
		_pose.set_bone("RightUpperLeg", Vector3(1.5, 0, -0.1))
		_arm("LeftUpperArm", Vector3(0.2, 0, 0.1))
		_arm("RightUpperArm", Vector3(0.2, 0, -0.1))
		_pivot.position.y = -0.55
		if event != null and event.has_method("on_slender_sat"):
			event.call("on_slender_sat", global_position)


## The book on the quay with the cold lantern on top of it (they stay with him).
func _set_down_props() -> void:
	if _book != null:
		_book.reparent(get_parent(), true)
		_book.global_position = global_position + (-_pivot.global_transform.basis.z) * 0.7 + Vector3.UP * 0.03
		_book.rotation = Vector3(0, _pivot.rotation.y, PI * 0.5)
		_book.show()
		for c: Node in _book.get_children():
			if c is Hitbox:
				(c as Hitbox).collision_layer = 0
	if _lantern != null:
		var keep: Node3D = _lantern
		keep.reparent(get_parent(), true)
		keep.global_position = global_position + (-_pivot.global_transform.basis.z) * 0.7 + Vector3.UP * 0.75
		keep.rotation = Vector3.ZERO
		for c2: Node in keep.get_children():
			if c2 is Hitbox:
				(c2 as Hitbox).collision_layer = 0


func _hold_after() -> float:
	return 9999.0


## He stays for the rest of the match (no 120 s cleanup).
func _update_dead(delta: float) -> void:
	_death_t += delta
	_death_tick(delta)


func _v(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr != null and arr.size() >= 3 else Vector3.ZERO
