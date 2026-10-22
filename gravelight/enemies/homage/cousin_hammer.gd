class_name CousinHammer
extends HomageBoss
## The Hammer (Cousin 1; docs/HOMAGE_BOSSES.md section 4.3). Blonde braid, an oversized wool coat buttoned to the
## throat, a long wool skirt, red-and-grey knitted mittens, and the inn's splitting maul dragged one-handed.
## Moves (each with pose + sound + light):
##   - Maul drag swipe (0.5 s, 2.4 m, 50);
##   - Mallet Throw (0.9 s: the hum stops one beat, a wind-up spin, the maul head flares violet): the maul flies
##     14 m/s up to 25 m homing at <= 90 deg/s, hits on the way out AND back (45 a pass, up to 3 targets, crouch /
##     slide under it), then she catches it blind and freezes 0.3 s. While it is in the air she is unarmed: every
##     hit x1.5, a melee hit staggers her 1.2 s and the maul drops at her feet (she stoops 1 s for it, still x1.5);
##   - Ricochet Throw (enraged, after the first death; the hum stops two beats): the maul banks off two walls first;
##   - Overhead Split (0.8 s, both hands overhead, a creak): 80 in front, and a splinter zone 3 m across for 3 s
##     (move x0.6, 5 every 0.5 s);
##   - the unarmed slap while the maul is out (0.4 s, 1.8 m, 25).
## Creepy layers: the head locked on the nearest player with a 175 deg look limit, the hitch in her skip (every
## third step skips frames), the catch-freeze. Death: she sits, lays the maul across her lap, stops; 2 s later she
## topples over like a doll, stiff, in one piece (authored, no ragdoll).

const BLONDE: Color = Color(0.86, 0.74, 0.46)
const COAT: Color = Color(0.25, 0.23, 0.21)
const CUFF: Color = Color(0.33, 0.31, 0.28)
const SKIRT: Color = Color(0.2, 0.19, 0.2)
const MITTEN_RED: Color = Color(0.62, 0.12, 0.12)
const MITTEN_GREY: Color = Color(0.56, 0.56, 0.57)
const IRON: Color = Color(0.22, 0.22, 0.24)
const HAFT: Color = Color(0.4, 0.29, 0.18)
const VIOLET: Color = Color(0.7, 0.35, 1.0)

var maul_out: bool = false
var maul: Maul = null
var maul_hits: int = 0              # players hit by the maul (out + back), for tests and the smoke
var ricochets: int = 0
var catches: int = 0
var splits: int = 0
var _prop: Node3D
var _flare: MeshInstance3D
var _maul_dropped: bool = false
var _special: String = ""
var _steps: int = 0
var _jitter_t: float = 0.0
var _scrape: AudioStreamPlayer3D


func _init() -> void:
	boss_key = "hammer"


func _on_spawned() -> void:
	_look.primary_limit_angle = deg_to_rad(175.0)   # the locked head: it stays on you while the body walks away
	maul_out = false
	_maul_dropped = false
	_prop.show()
	_flare.hide()
	_special = ""
	_hum_t = 1.0


# ---------------------------------------------------------------- brain

func _tick(delta: float) -> void:
	var c: Dictionary = bcfg
	match bstate:
		B.ARRIVE:
			stand(delta)
			if _bt >= 0.6:
				_go(B.MOVE)
		B.MOVE:
			_think(delta)
		B.TELEGRAPH:
			_telegraph(delta)
		B.ACTIVE:
			stand(delta, move_id != "throw")
			if _bt >= 0.3:
				_pose.clear()
				_go(B.RECOVER)
		B.RECOVER:
			stand(delta)
			if _bt >= 0.35:
				_go(B.MOVE)
		B.STAGGER:
			_halt(delta)
			if _bt >= float(c["throw"]["stagger"]):
				if _maul_dropped:
					_special = "stoop"
					_pose.set_bone("Spine", Vector3(0.9, 0, 0))
					_pose.set_bone("RightUpperArm", Vector3(0.6, 0, 0))
					pose_anim()
					_go(B.SPECIAL)
				else:
					_go(B.MOVE)
		B.SPECIAL:
			_halt(delta)
			if _special == "catch" and _bt >= float(c["throw"]["catch_freeze"]):
				_pose.hold = false
				_special = ""
				_go(B.MOVE)
			elif _special == "stoop" and _bt >= float(c["throw"]["stoop"]):
				_pose.clear()
				_special = ""
				_maul_dropped = false
				maul_out = false
				_prop.show()
				_go(B.MOVE)


func _think(delta: float) -> void:
	if target == null:
		stand(delta, false)
		return
	var c: Dictionary = bcfg
	var d: float = dist_to(target)
	var dy: float = absf(target.global_position.y - global_position.y)
	if maul_out:
		if d <= float(c["slap"]["range"]) and dy < 1.3 and cd_ready("slap") and _clear_to(target):
			_begin("slap", float(c["slap"]["telegraph"]))
		else:
			walk_to(target.global_position, delta)
		return
	if d <= float(c["split"]["range"]) and dy < 1.3 and cd_ready("split") and _clear_to(target):
		_begin("split", float(c["split"]["telegraph"]))
	elif d <= float(c["swipe"]["range"]) and dy < 1.3 and cd_ready("swipe") and _clear_to(target):
		_begin("swipe", float(c["swipe"]["telegraph"]))
	elif d >= float(c["throw"]["min_range"]) and d <= float(c["throw"]["range"]) and cd_ready("throw") and has_los(target):
		_begin("throw", float(c["ricochet"]["telegraph"]) if enrage_steps >= 1 else float(c["throw"]["telegraph"]))
	else:
		walk_to(target.global_position, delta)


var _tele_total: float = 0.5


func _begin(id: String, telegraph: float) -> void:
	_tele_total = tele_len(telegraph)
	_go(B.TELEGRAPH, id)
	match id:
		"swipe":
			attack_anim("swipe_r", _tele_total)
			sfx("board_place", -6.0, 0.6)   # the maul lifted off the floor: the scrape stops
		"slap":
			attack_anim("swipe_l", _tele_total)
		"split":
			pose_anim()
			_pose.set_bone("LeftUpperArm", Vector3(2.9, 0, 0.25))
			_pose.set_bone("RightUpperArm", Vector3(2.9, 0, -0.25))
			_pose.set_bone("Spine", Vector3(-0.25, 0, 0))
			sfx("board_break", -2.0, 0.45)   # the creak of the haft
		"throw":
			pose_anim()
			_hum_mute = _tele_total + 0.4   # she stops humming: one beat (two when enraged) is the tell
			_pose.set_bone("RightUpperArm", Vector3(2.2, 0, -0.6))
			_pose.set_bone("Spine", Vector3(0, 0.6, 0))
			_flare.show()


func _telegraph(delta: float) -> void:
	stand(delta)
	var c: Dictionary = bcfg
	if move_id == "throw":
		# the last 0.25 s is the wind-up spin, braid swinging
		var spin_from: float = _tele_total - 0.25
		if _bt >= spin_from and not _hit_done:
			_hit_done = true
			sfx("knife_swing", 2.0, 0.55)
		if _bt >= spin_from:
			_pivot.rotation.y = lerpf(0.0, TAU, clampf((_bt - spin_from) / 0.25, 0.0, 1.0))
	if _bt < _tele_total:
		return
	_pivot.rotation.y = 0.0
	_hit_done = false
	match move_id:
		"swipe":
			set_cd("swipe", float(c["swipe"]["cooldown"]))
			_melee_hit(float(c["swipe"]["range"]), float(c["swipe"]["damage"]))
		"slap":
			set_cd("slap", float(c["slap"]["cooldown"]))
			_melee_hit(float(c["slap"]["range"]), float(c["slap"]["damage"]))
		"split":
			set_cd("split", float(c["split"]["cooldown"]))
			_pose.set_bone("LeftUpperArm", Vector3(0.9, 0, 0.1))
			_pose.set_bone("RightUpperArm", Vector3(0.9, 0, -0.1))
			_pose.set_bone("Spine", Vector3(0.5, 0, 0))
			_split()
		"throw":
			set_cd("throw", float(c["ricochet"]["cooldown"]) if enrage_steps >= 1 else float(c["throw"]["cooldown"]))
			_pose.set_bone("RightUpperArm", Vector3(1.4, 0, 0))
			_pose.set_bone("Spine", Vector3(0.15, -0.3, 0))
			_release_maul()
	_go(B.ACTIVE)


func _melee_hit(reach: float, dmg: float) -> void:
	if target != null and target.is_alive() and dist_to(target) <= reach + 0.5 and absf(target.global_position.y - global_position.y) < 1.4 and _clear_to(target):
		hit_player(target, dmg)


func _split() -> void:
	splits += 1
	var c: Dictionary = bcfg["split"]
	var fwd: Vector3 = -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for p: Player in alive_players():
		var to: Vector3 = p.global_position - global_position
		to.y = 0.0
		if to.length() <= float(c["range"]) + 0.4 and (to.length() < 0.6 or fwd.dot(to.normalized()) > 0.3) and absf(p.global_position.y - global_position.y) < 1.4:
			hit_player(p, float(c["damage"]))
	var z: SplinterZone = SplinterZone.new()
	z.cfg = c
	z.status = StringName(str((ecfg.get("status", {}) as Dictionary).get("splinters", "splinters")))
	z.boss = self
	get_parent().add_child(z)
	z.global_position = global_position + fwd * 1.4
	sfx("board_break", 6.0, 0.7)
	sfx("grenade_explode", -8.0, 1.6)
	GLBus.explosion.emit(z.global_position, 0.1)
	if randf() < 0.4:
		say("HAM_WOOD_01")


func _release_maul() -> void:
	var c: Dictionary = bcfg["throw"]
	maul = Maul.new()
	maul.boss = self
	maul.cfg = c
	maul.aim = target
	maul.bounces = int(bcfg["ricochet"]["bounces"]) if enrage_steps >= 1 else 0
	get_parent().add_child(maul)
	var hand: Vector3 = global_position + Vector3.UP * 1.35 - global_basis.z * 0.45   # let go at shoulder height, in front
	maul.global_position = hand
	var to: Vector3 = (target.global_position + Vector3.UP * 1.25 - hand) if target != null else -global_basis.z
	maul.out_limit = minf(float(c["range"]), to.length() + 2.5)
	maul.vel = to.normalized() * float(c["speed"])
	maul_out = true
	_prop.hide()
	_flare.hide()
	say("HAM_THROW_01")


func hand_pos() -> Vector3:
	var h: Node3D = bone_attachment("RightHand")
	return h.global_position if h != null else global_position + Vector3.UP * 1.0


## The maul came home: the blind catch, a giggle cut dead, and 0.3 s of perfect stillness.
func on_maul_caught() -> void:
	maul = null
	if not is_active():
		return
	catches += 1
	maul_out = false
	_prop.show()
	if bstate == B.STAGGER or _maul_dropped:
		return
	if randf() < 0.35:
		say("HAM_CATCH_01")
	_special = "catch"
	_pose.clear()
	_pose.hold = true
	_go(B.SPECIAL)


func damage_taken_mult() -> float:
	return float(bcfg["throw"]["airborne_mult"]) if maul_out else 1.0


func _on_damaged(_amount: float, _limb: StringName, _by: int, kind: StringName) -> void:
	# unarmed: a melee hit staggers her and the maul drops where she stands
	if kind == &"melee" and maul_out and bstate != B.STAGGER and is_active():
		_pose.hold = false
		_pose.clear()
		_special = ""
		if maul != null and is_instance_valid(maul):
			maul.drop_at(global_position + global_basis.x * 0.6)
		_maul_dropped = true
		_react_clip = str(_anim["clips"]["react"]["stagger"])
		_react_len = float(bcfg["throw"]["stagger"])
		state = State.STAGGER
		_tree_play("React", _react_clip, ZombieClips.length_of(_react_clip) / _react_len)
		_go(B.STAGGER)


func _on_enraged() -> void:
	say("HAM_ENRAGE_01")


func _tele_glow() -> float:
	if bstate == B.TELEGRAPH:
		return 3.5 if move_id == "throw" or move_id == "split" else 1.5
	return 0.0


# ---------------------------------------------------------------- presentation

func _process(delta: float) -> void:
	if _jitter_t > 0.0:
		_jitter_t -= delta
		return   # the hitch: frames skipped, the pose held
	super._process(delta)


## Every third step hitches (the AnimJitter idea: held poses at 12 fps for a step) and the maul head scrapes.
func _footstep(left: bool) -> void:
	super._footstep(left)
	_steps += 1
	if _steps % 3 == 0 and bstate == B.MOVE:
		_jitter_t = 0.17
	if not maul_out and _steps % 2 == 0:
		sfx("board_place", -12.0, 0.5, global_position + global_basis.x * 0.3)


func _hum_pitch() -> float:
	return 0.92


func _start_authored_death() -> void:
	_tree_play("Death", "death_sit", 1.0)
	_pose.clear()
	_pose.set_bone("LeftUpperArm", Vector3(0.7, 0, 0.2))
	_pose.set_bone("RightUpperArm", Vector3(0.7, 0, -0.2))
	if maul != null and is_instance_valid(maul):
		maul.drop_at(global_position + global_basis.x * 0.6)
	_prop.show()
	say("HAM_DEATH_01")


## 2 s still, then the slow doll topple: stiff, all in one piece.
func _death_tick(_delta: float) -> void:
	var t: float = _death_t - (ZombieClips.DEATH_SECONDS + 2.0)
	if t > 0.0:
		var k: float = clampf(t / 1.6, 0.0, 1.0)
		_pivot.rotation.z = lerpf(0.0, 1.35, k * k)


func _build_costume() -> void:
	# hair: blonde, one long braid down the back (frost in it)
	costume("Head", [
		sph(0.138, Vector3(0, 0.105, 0.012), BLONDE, Vector3(1.0, 1.0, 1.05), true),
		boxp(Vector3(0.25, 0.15, 0.05), Vector3(0, 0.06, 0.1), BLONDE),
		boxp(Vector3(0.045, 0.13, 0.17), Vector3(0.118, 0.07, 0.01), BLONDE),
		boxp(Vector3(0.045, 0.13, 0.17), Vector3(-0.118, 0.07, 0.01), BLONDE)])
	var braid: Array = []
	for i: int in 6:
		braid.append(sph(0.036 - 0.003 * float(i), Vector3(0, 0.36 - 0.075 * float(i), 0.14 + 0.006 * float(i)), BLONDE.darkened(0.05 * float(i % 2))))
	braid.append(cyl(0.02, 0.02, 0.03, Vector3(0, -0.08, 0.17), MITTEN_RED))   # the tie
	costume("Chest", braid)
	# the oversized man's wool overcoat, buttoned to the throat
	var coat: Array = [
		cyl(0.205, 0.225, 0.37, Vector3(0, 0.15, 0.005), COAT, Vector3.ZERO, Vector3(1.0, 1.0, 0.7)),
		cyl(0.078, 0.095, 0.075, Vector3(0, 0.31, 0), COAT),
		sph(0.075, Vector3(-0.2, 0.27, 0), COAT, Vector3(1.0, 0.7, 1.0)),
		sph(0.075, Vector3(0.2, 0.27, 0), COAT, Vector3(1.0, 0.7, 1.0))]
	for k: int in 4:
		coat.append(sph(0.013, Vector3(0, 0.26 - 0.085 * float(k), -0.162), IRON))
	costume("Chest", coat)
	costume("Spine", [cyl(0.205, 0.215, 0.26, Vector3(0, 0.1, 0.005), COAT, Vector3.ZERO, Vector3(1.05, 1.0, 0.78))])
	costume("Hips", [
		cyl(0.235, 0.33, 0.52, Vector3(0, -0.21, 0.005), COAT, Vector3.ZERO, Vector3(1.06, 1.0, 0.94)),   # the coat's skirts to the knee
		cyl(0.21, 0.355, 0.82, Vector3(0, -0.4, 0.0), SKIRT, Vector3.ZERO, Vector3(1.06, 1.0, 0.94))])      # the long wool skirt
	for side: String in ["Left", "Right"]:
		costume(side + "UpperArm", [cyl(0.068, 0.062, 0.32, Vector3(0, -0.15, 0), COAT)])
		costume(side + "LowerArm", [cyl(0.06, 0.066, 0.26, Vector3(0, -0.12, 0), COAT), cyl(0.074, 0.074, 0.07, Vector3(0, -0.23, 0), CUFF)])
		costume(side + "Hand", [sph(0.058, Vector3(0, -0.065, 0), MITTEN_RED, Vector3(0.9, 1.15, 0.8)),
			cyl(0.05, 0.05, 0.035, Vector3(0, -0.015, 0), MITTEN_GREY),
			sph(0.024, Vector3(0.045 * (1.0 if side == "Right" else -1.0), -0.045, -0.03), MITTEN_GREY)])
		costume(side + "Foot", [boxp(Vector3(0.1, 0.12, 0.2), Vector3(0, -0.02, -0.03), IRON.darkened(0.3))])   # laced winter boots
	# the splitting maul, dragged head-down from the right mitten
	var hand: Node3D = bone_attachment("RightHand")
	_prop = Node3D.new()
	_prop.name = "Maul"
	hand.add_child(_prop)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _mesh_of([cyl(0.022, 0.024, 0.78, Vector3(0, -0.4, 0), HAFT),
		boxp(Vector3(0.1, 0.13, 0.27), Vector3(0, -0.8, 0.0), IRON),
		boxp(Vector3(0.06, 0.1, 0.06), Vector3(0, -0.8, -0.16), IRON.lightened(0.15), Vector3(0.6, 0, 0))])
	_prop.add_child(mi)
	_flare = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(0.11, 0.14, 0.28)
	_flare.mesh = fm
	_flare.material_override = HomageBoss.mat(VIOLET, 4.0)
	_flare.position = Vector3(0, -0.8, 0)
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prop.add_child(_flare)


static func _mesh_of(parts: Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for p: Array in parts:
		var st: SurfaceTool = SurfaceTool.new()
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, HomageBoss.mat(p[2] as Color))
	return mesh


# ================================================================== the thrown maul

## The boomerang: out along the aim (homing <= turn_deg / s, banking off walls when ricochet bounces are left),
## then home to her hand on a curve that comes back from the side. Hits each player once per pass (out, back),
## at chest height, so crouching / sliding ducks it. A loop hum while it flies (the off-screen audio tell).
class Maul extends Node3D:
	var boss: CousinHammer
	var cfg: Dictionary
	var aim: Player
	var vel: Vector3 = Vector3.FORWARD
	var bounces: int = 0
	var out_limit: float = 20.0
	var returning: bool = false
	var dropped: bool = false
	var travelled: float = 0.0
	var t: float = 0.0
	var _hit_out: Dictionary = {}
	var _hit_back: Dictionary = {}
	var _loop: AudioStreamPlayer3D
	var _spin: Node3D

	func _ready() -> void:
		_spin = Node3D.new()
		add_child(_spin)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = CousinHammer._mesh_of([HomageBoss.cyl(0.024, 0.024, 0.78, Vector3(0, 0.25, 0), CousinHammer.HAFT),
			HomageBoss.boxp(Vector3(0.1, 0.13, 0.27), Vector3(0, -0.15, 0), CousinHammer.IRON)])
		_spin.add_child(mi)
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = CousinHammer.VIOLET
		l.light_energy = 1.6
		l.omni_range = 3.0
		l.shadow_enabled = false
		_spin.add_child(l)
		_loop = AudioDirector.make_loop_3d("wire_buzz", self, -2.0)
		if _loop != null:
			_loop.pitch_scale = 0.7
			_loop.play()

	func _physics_process(delta: float) -> void:
		if boss == null or not is_instance_valid(boss):
			queue_free()
			return
		if dropped:
			global_position.y = move_toward(global_position.y, _floor_y + 0.12, delta * 6.0)
			_spin.rotation = _spin.rotation.lerp(Vector3(0, 0, PI * 0.5), clampf(delta * 8.0, 0.0, 1.0))
			if not boss.is_active() or not boss._maul_dropped:
				queue_free()
			return
		t += delta
		var spd: float = float(cfg["speed"])
		if not returning:
			if aim != null and is_instance_valid(aim) and aim.is_alive() and bounces == int(boss.bcfg["ricochet"]["bounces"]) * int(boss.enrage_steps >= 1):
				var want: Vector3 = (aim.global_position + Vector3.UP * 1.25 - global_position).normalized() * spd
				vel = _turn(vel, want, deg_to_rad(float(cfg["turn_deg"])) * delta)
			var step: Vector3 = vel * delta
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, global_position + step * 1.5, 1 | (1 << 8))
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				if bounces > 0:
					bounces -= 1
					boss.ricochets += 1
					vel = vel.bounce((hit["normal"] as Vector3).normalized())
					global_position = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.15
					AudioDirector.play_3d("board_slam", global_position, -2.0)
					_hit_out.clear()   # a fresh line after each bank
				else:
					_begin_return()
			else:
				global_position += step
				travelled += step.length()
				if travelled >= out_limit:
					_begin_return()
		else:
			var to: Vector3 = boss.hand_pos() - global_position
			if to.length() < 0.9 or t > float(cfg["max_flight"]) or not boss.is_active():
				_caught()
				return
			vel = _turn(vel, to.normalized() * spd * 1.1, deg_to_rad(220.0) * delta)
			global_position += vel * delta   # the return rounds corners: it doesn't stop for a wall
		_spin.rotate_object_local(Vector3.RIGHT, delta * 20.0)
		_hits()

	var _floor_y: float = 0.0

	func _begin_return() -> void:
		returning = true
		vel = vel.rotated(Vector3.UP, deg_to_rad(75.0) * (1.0 if randf() < 0.5 else -1.0))

	func _hits() -> void:
		var hit_set: Dictionary = _hit_back if returning else _hit_out
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or not p.is_alive() or hit_set.has(p.player_id) or hit_set.size() >= int(cfg["max_targets"]):
				continue
			if p.crouching or p.sliding:
				continue   # it flies at chest height: duck it
			if (p.global_position + Vector3.UP * 1.25).distance_to(global_position) <= float(cfg["hit_radius"]):
				hit_set[p.player_id] = true
				boss.maul_hits += 1
				boss.hit_player(p, float(cfg["damage"]))

	func drop_at(pos: Vector3) -> void:
		dropped = true
		if _loop != null:
			_loop.stop()
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.0, pos + Vector3.DOWN * 3.0, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		_floor_y = (hit["position"] as Vector3).y if not hit.is_empty() else pos.y
		global_position = Vector3(pos.x, maxf(global_position.y, _floor_y + 0.3), pos.z)
		AudioDirector.play_3d("board_slam", global_position, -4.0)

	func _caught() -> void:
		if _loop != null:
			_loop.stop()
		boss.on_maul_caught()
		queue_free()

	static func _turn(v: Vector3, want: Vector3, max_rad: float) -> Vector3:
		var a: float = v.angle_to(want)
		if a <= max_rad or a < 0.0001:
			return want
		var axis: Vector3 = v.cross(want)
		if axis.length_squared() < 1e-8:
			return v.normalized() * want.length()
		return v.normalized().rotated(axis.normalized(), max_rad) * want.length()


## The Overhead Split's splinter zone: 3 m across for 3 s, move x0.6 and 5 damage every 0.5 s while inside.
class SplinterZone extends Node3D:
	var cfg: Dictionary
	var status: StringName = &"splinters"
	var boss: HomageBoss
	var _t: float = 0.0
	var _tick: float = 0.0

	func _ready() -> void:
		var r: float = float(cfg["zone_radius"])
		var mi: MeshInstance3D = MeshInstance3D.new()
		var parts: Array = [HomageBoss.cyl(r, r, 0.02, Vector3(0, 0.02, 0), Color(0.3, 0.22, 0.14))]
		for k: int in 14:
			var a: float = float(k) * 2.4
			var rr: float = r * (0.25 + 0.7 * fmod(float(k) * 0.37, 1.0))
			parts.append(HomageBoss.boxp(Vector3(0.05, 0.05, 0.4), Vector3(cos(a) * rr, 0.06, sin(a) * rr), Color(0.5, 0.38, 0.24), Vector3(0.3, a, 0.4)))
		mi.mesh = CousinHammer._mesh_of(parts)
		add_child(mi)

	func _physics_process(delta: float) -> void:
		_t += delta
		_tick -= delta
		var r: float = float(cfg["zone_radius"])
		var tick_now: bool = _tick <= 0.0
		if tick_now:
			_tick = float(cfg["zone_tick"])
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or not p.is_alive():
				continue
			var d: Vector3 = p.global_position - global_position
			if Vector2(d.x, d.z).length() <= r and absf(d.y) < 1.0:
				p.apply_status(status, 0.3)
				if tick_now and boss != null and is_instance_valid(boss):
					boss.hit_player(p, float(cfg["zone_damage"]))
		if _t >= float(cfg["zone_seconds"]):
			queue_free()
