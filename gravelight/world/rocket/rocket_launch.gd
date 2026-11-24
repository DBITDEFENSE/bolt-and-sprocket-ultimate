class_name RocketLaunch
extends Node3D
## T-276: the V2 at Map 0's launch site (the map json's "rocket_launch" block; MapRocketGen places this node on the
## firing table). The rocket stands on the table with the erector arm up beside it. On a launch round (first_round,
## then every `every` rounds) the host starts the sequence `delay` s into the round and mirrors it to every peer; each
## peer then plays the same timeline from its own clock (as ShermanEvent's dive bomber does):
##   0 s        the siren, the warning banner, fuelling vapour off the rocket and the oxidiser trailer
##   arm_down   the erector arm lowers onto its trailer
##   count_at   ten seconds counted (to players near the site), a tick a second from the dugout
##   ignite_at  the preliminary stage: a small flame under the table, the roar starts
##   main_at    the main stage: the full jet, a cloud of smoke and snow, the ground shakes. Host: the dead within
##              kill_radius die (explosive, so their bodies fly), those within throw_radius are thrown and hurt; a
##              player within player_radius takes up to player_damage (half with Blastproof or Rocket Man); the
##              ground round the table burns for fire.patch_seconds (FirePatch, as the fire zombie's)
##   liftoff_at the rocket rises off the table, slowly at first, pitches over toward the east and climbs out of
##              sight trailing smoke (climb_distance(t): 0.8 t^2 + 0.06 t^3 metres along its path)
## After the launch the table stays empty with the arm down. rearm_delay s into the next round a new rocket lies on
## the lowered arm and is raised over erect_seconds (every peer, mirrored), ready for the next launch.
## A late joiner gets the standing / gone state from GameState flag "v2_state" (0 ready, 1 gone).

enum Phase { READY, SEQUENCE, GONE, ERECTING }

const FLAG: StringName = &"v2_state"

var cfg: Dictionary = {}
var phase: int = Phase.READY
var t: float = 0.0
var puppet: bool = false
var launches: int = 0          # how many sequences this node has run (smokes read it)
var last_blast: Dictionary = {}   # host: {"killed": n, "thrown": n, "players": n} at the last main stage
var rocket: Node3D
var arm_pivot: Node3D
var _flame: Node3D
var _flame_light: OmniLight3D
var _trail: GPUParticles3D
var _vapour: Array[GPUParticles3D] = []
var _roar: AudioStreamPlayer3D
var _lift_t: float = -1.0
var _pending_start: float = -1.0
var _pending_rearm: float = -1.0
var _erect_t: float = 0.0
var _siren_t: float = 0.0
var _count_shown: int = -1
var _danger_t: float = 0.0


static func block_for(map_id: StringName) -> Dictionary:
	var path: String = ClimbLink.json_path_for(map_id)
	var v: Variant = GLData.load_json(path).get("rocket_launch", {})
	return v if v is Dictionary else {}


## True when round `r` is a launch round.
static func is_launch_round(r: int, c: Dictionary) -> bool:
	var first: int = int(c.get("first_round", 6))
	var every: int = int(c.get("every", 5))
	if r < first:
		return false
	return every <= 0 and r == first or every > 0 and (r - first) % every == 0


## What the main stage does to a zombie `d` m (flat) from the table: "kill", "throw" or "".
static func blast_zombie(d: float, c: Dictionary) -> String:
	if d <= float(c.get("kill_radius", 6.0)):
		return "kill"
	if d <= float(c.get("throw_radius", 13.0)):
		return "throw"
	return ""


## Damage to a player `d` m (flat) from the table at the main stage (linear falloff to 25 % at the edge; halved for a
## player whose own explosives cannot hurt them).
static func player_damage(d: float, c: Dictionary, resistant: bool) -> float:
	var r: float = float(c.get("player_radius", 7.0))
	if d > r:
		return 0.0
	var dmg: float = float(c.get("player_damage", 45.0)) * lerpf(1.0, 0.25, clampf(d / maxf(r, 0.01), 0.0, 1.0))
	return dmg * (0.5 if resistant else 1.0)


## Metres flown along the climb path `secs` after the rocket leaves the table.
static func climb_distance(secs: float) -> float:
	var s: float = maxf(secs, 0.0)
	return 0.8 * s * s + 0.06 * s * s * s


## A point `s` m along the climb path from the base's start (local to the table, y up): straight up for the first
## 18 m, then pitching over toward +X (east) to 50 degrees from the vertical by 700 m. Integrated in 2 m steps.
static func path_point(s: float) -> Vector3:
	var p: Vector3 = Vector3.ZERO
	var done: float = 0.0
	while done < s:
		var step: float = minf(2.0, s - done)
		var pitch: float = deg_to_rad(clampf((done - 18.0) / 700.0, 0.0, 1.0) * 50.0)
		p += Vector3(sin(pitch), cos(pitch), 0.0) * step
		done += step
	return p


static func path_pitch(s: float) -> float:
	return deg_to_rad(clampf((s - 18.0) / 700.0, 0.0, 1.0) * 50.0)


static func attach(map: Node) -> RocketLaunch:
	return map.get_node_or_null("Gameplay/RocketLaunch") as RocketLaunch


func _ready() -> void:
	add_to_group(&"rocket_launch")
	var m: Node = _map()
	cfg = block_for(m.get("map_id") if m != null and m.get("map_id") != null else &"map00_crossroads")
	puppet = Net.is_client()
	_build_rocket_on_table()
	arm_pivot = Node3D.new()
	arm_pivot.name = "Erector"
	arm_pivot.position = RocketSite.HINGE_LOCAL
	add_child(arm_pivot)
	arm_pivot.add_child(V2Model.erector_arm())
	_ambience()
	if cfg.is_empty():
		return
	if not puppet:
		GLBus.round_started.connect(_on_round_started)
		GameState.set_flag(FLAG, 0)
	else:
		GLBus.flag_changed.connect(_on_flag)
		if int(GameState.flags.get(FLAG, 0)) == 1:
			_show_gone()
	GLConsole.register("v2", _cmd, "v2 launch|rearm|status: the V2 at the forest clearing (T-276)")


func _exit_tree() -> void:
	if GLConsole.get("_commands") is Dictionary:
		var cmds: Dictionary = GLConsole.get("_commands")
		if cmds.has("v2") and (cmds["v2"]["fn"] as Callable).get_object() == self:
			cmds.erase("v2")


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n


## The site's own sound: the generator trailer's engine, the wind in the spruces over the clearing (every peer).
func _ambience() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for row: Array in [["ambient_map01_generator", RocketSite.GEN_LOCAL, -4.0], ["wind_howl", Vector3(-4.0, 6.0, 0.0), -8.0]]:
		var n: Node3D = Node3D.new()
		n.name = "Amb_" + str(row[0])
		n.position = row[1]
		add_child(n)
		var pl: AudioStreamPlayer3D = AudioDirector.make_loop_3d(str(row[0]), n, float(row[2]))
		if pl != null:
			pl.play()


func _build_rocket_on_table() -> void:
	if rocket != null and is_instance_valid(rocket):
		rocket.queue_free()
	rocket = V2Model.rocket()
	rocket.position = Vector3(0, RocketSite.TABLE_TOP, 0)
	add_child(rocket)


# ================================================================== host: when

func _on_round_started(r: int, _special: bool) -> void:
	if phase == Phase.READY and is_launch_round(r, cfg):
		_pending_start = float(cfg.get("delay", 20.0))
	elif phase == Phase.GONE:
		_pending_rearm = float(cfg.get("rearm_delay", 15.0))


## Host: start the sequence now (mirrored).
func begin_launch() -> void:
	if puppet or phase == Phase.SEQUENCE:
		return
	if phase != Phase.READY:   # (the console on an empty table: put a rocket up at once)
		net_ready()
	_pending_start = -1.0
	net_begin()
	if Net.replicating():
		Net.mirror(self, &"net_begin", [])


## Host: raise a new rocket now (mirrored).
func begin_rearm() -> void:
	if puppet or phase != Phase.GONE:
		return
	_pending_rearm = -1.0
	net_rearm()
	if Net.replicating():
		Net.mirror(self, &"net_rearm", [])


# ================================================================== every peer: the timeline

func net_begin() -> void:
	phase = Phase.SEQUENCE
	t = 0.0
	_lift_t = -1.0
	_count_shown = -1
	_siren_t = 0.0
	launches += 1
	arm_pivot.rotation.z = 0.0
	if rocket == null or not is_instance_valid(rocket):
		_build_rocket_on_table()
	_banner(str(cfg.get("banner", "V2 LAUNCH AT THE FOREST CLEARING")), str(cfg.get("banner_small", "Stand clear of the firing table")))
	_set_vapour(true)


func net_rearm() -> void:
	phase = Phase.ERECTING
	_erect_t = 0.0
	arm_pivot.rotation.z = PI * 0.5
	if rocket != null and is_instance_valid(rocket):
		rocket.queue_free()
	rocket = V2Model.rocket()
	arm_pivot.add_child(rocket)
	rocket.position = Vector3(V2Model.AXIS_OFF, RocketSite.TABLE_TOP - RocketSite.HINGE_LOCAL.y, 0)


## Every peer: a rocket standing on the table, the arm up (the end of an erection; a console launch on an empty table).
func net_ready() -> void:
	phase = Phase.READY
	arm_pivot.rotation.z = 0.0
	if rocket == null or not is_instance_valid(rocket) or rocket.get_parent() != self:
		if rocket != null and is_instance_valid(rocket):
			rocket.queue_free()
		_build_rocket_on_table()
	if not puppet:
		GameState.set_flag(FLAG, 0)


func _process(delta: float) -> void:
	if not puppet:
		if _pending_start >= 0.0 and RoundManager.state == RoundManager.State.ROUND:
			_pending_start -= delta
			if _pending_start < 0.0:
				begin_launch()
		if _pending_rearm >= 0.0:
			_pending_rearm -= delta
			if _pending_rearm < 0.0:
				begin_rearm()
	match phase:
		Phase.SEQUENCE:
			_tick_sequence(delta)
		Phase.ERECTING:
			_erect_t += delta
			var secs: float = float(cfg.get("erect_seconds", 24.0))
			var k: float = clampf(_erect_t / maxf(secs, 0.1), 0.0, 1.0)
			arm_pivot.rotation.z = PI * 0.5 * (1.0 - smoothstep(0.0, 1.0, k))
			if k >= 1.0:
				net_ready()


func _crossed(at: float, prev: float) -> bool:
	return prev < at and t >= at


func _tick_sequence(delta: float) -> void:
	var prev: float = t
	t += delta
	var ignite: float = float(cfg.get("ignite_at", 32.0))
	var main: float = float(cfg.get("main_at", 34.0))
	var lift: float = float(cfg.get("liftoff_at", 35.0))
	var site: Vector3 = global_position
	# the siren every 9 s until the main stage
	if t < main:
		_siren_t -= delta
		if _siren_t <= 0.0:
			_siren_t = 9.0
			AudioDirector.play_3d(str(cfg.get("siren_sound", "a1_siren")), site + RocketSite.BUNKER_LOCAL + Vector3(0, 2.0, 0), 4.0)
	# the arm lowers
	var arm_at: float = float(cfg.get("arm_down_at", 6.0))
	var arm_s: float = float(cfg.get("arm_down_seconds", 9.0))
	if t >= arm_at and t <= arm_at + arm_s + delta:
		arm_pivot.rotation.z = PI * 0.5 * smoothstep(0.0, 1.0, clampf((t - arm_at) / arm_s, 0.0, 1.0))
	# the count
	var count_at: float = float(cfg.get("count_at", 22.0))
	if t >= count_at and t < count_at + 10.0:
		var n: int = 10 - int(floor(t - count_at))
		if n != _count_shown:
			_count_shown = n
			AudioDirector.play_3d("ui_tick", site + RocketSite.BUNKER_LOCAL, 6.0)
			_count_banner(n)
	if _crossed(ignite, prev):
		_set_vapour(false)
		_flame_on(0.35)
		_roar = AudioDirector.make_loop_3d(str(cfg.get("roar_sound", "m4d_vent_roar")), rocket, 6.0)
		if _roar != null:
			_roar.play()
		BossFx.burst("smoke", site + Vector3(0, 0.5, 0), get_tree(), 1.5, 2.0)
	if _crossed(main, prev):
		_flame_on(1.0)
		AudioDirector.play_3d(str(cfg.get("ignite_sound", "m4d_pad_launch")), site + Vector3(0, 1.0, 0), 8.0)
		AudioDirector.play_3d("explosion_large", site + Vector3(0, 0.5, 0), 3.0)
		for k: int in 4:
			var a: float = TAU * float(k) / 4.0 + 0.4
			BossFx.burst("smoke", site + Vector3(cos(a) * 3.5, 0.6, sin(a) * 3.5), get_tree(), 2.5, 3.0)
			Effects.dirt_burst(site + Vector3(cos(a) * 2.5, 0.2, sin(a) * 2.5), &"snow", 2.0, Vector3(cos(a), 0.6, sin(a)), 24)
		ShermanEvent.shake_players(get_tree(), site, float(cfg.get("shake", 1.2)), float(cfg.get("shake_radius", 70.0)))
		FirePatch.spawn(get_tree(), site, cfg.get("fire", {}), not puppet)
		if not puppet:
			_blast(site)
	if _crossed(lift, prev):
		_lift_t = 0.0
		rocket.top_level = true
		rocket.global_transform = Transform3D(Basis.IDENTITY, site + Vector3(0, RocketSite.TABLE_TOP, 0))
		_trail = _make_trail(rocket)
	if _lift_t >= 0.0:
		_lift_t += delta
		var s: float = climb_distance(_lift_t)
		var p: Vector3 = path_point(s)
		var pitch: float = path_pitch(s)
		if rocket != null and is_instance_valid(rocket) and rocket.visible:
			rocket.global_transform = Transform3D(Basis(Vector3(0, 0, 1), -pitch), site + Vector3(0, RocketSite.TABLE_TOP, 0) + p)
			if _lift_t < 6.0 and Engine.get_process_frames() % 6 == 0:
				ShermanEvent.shake_players(get_tree(), site, 0.25 * (1.0 - _lift_t / 6.0), 50.0)
			if _flame != null and is_instance_valid(_flame):
				_flame.scale.y = 9.0 * randf_range(0.9, 1.08)
			if s > float(cfg.get("vanish_m", 380.0)):
				_vanish()
	if not puppet:
		_danger_t -= delta
		if _danger_t <= 0.0 and t > count_at - 6.0 and t < lift + 8.0:
			_danger_t = 0.5
			_post_danger(site)
	if t >= lift + float(cfg.get("gone_after", 34.0)):
		_vanish()
		phase = Phase.GONE
		if not puppet:
			GameState.set_flag(FLAG, 1)


## Host: the main stage's blast.
func _blast(site: Vector3) -> void:
	var killed: int = 0
	var thrown: int = 0
	var hurt: int = 0
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if z == null or not is_instance_valid(z) or not z.is_active():
				continue
			var off: Vector3 = z.global_position - site
			off.y = 0.0
			match blast_zombie(off.length(), cfg):
				"kill":
					if z.take_damage(maxf(RoundManager.current_health() * 4.0, 5000.0), &"torso", &"v2_launch", 0, &"explosive"):
						killed += 1
				"throw":
					var away: Vector3 = off.normalized() if off.length() > 0.1 else Vector3.RIGHT
					z.external_push(away * float(cfg.get("throw_speed", 9.0)) + Vector3.UP * 3.0, 0.6, 0, &"v2_launch", float(cfg.get("throw_land_damage", 60.0)))
					thrown += 1
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = n as Player
		if pl == null or not pl.is_alive():
			continue
		var po: Vector3 = pl.global_position - site
		po.y = 0.0
		var dmg: float = 0.0 if PerkManager.v2_immune(pl.player_id) else player_damage(po.length(), cfg, pl.has_explosive_immunity())
		if dmg > 0.0:
			pl.take_hit(dmg, self)
			pl.apply_knockback(po.normalized() * 6.0 if po.length() > 0.1 else Vector3.RIGHT * 6.0)
			hurt += 1
	last_blast = {"killed": killed, "thrown": thrown, "players": hurt}


func _post_danger(site: Vector3) -> void:
	var m: Node = _map()
	var squad: Object = m.get("squad") if m != null else null
	if squad == null or not squad.has_method("time"):
		return
	var bb: Object = squad.get("blackboard")
	if bb == null or not bb.has_method("add_danger"):
		return
	bb.call("add_danger", site, float(cfg.get("player_radius", 7.0)) + 1.0, 8.0, float(squad.call("time")) + 0.6, "v2_launch")


# ================================================================== looks

func _set_vapour(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if on and _vapour.is_empty():
		for spot: Vector3 in [Vector3(0.9, RocketSite.TABLE_TOP + 6.5, 0.0), Vector3(-0.8, RocketSite.TABLE_TOP + 3.0, 0.4)]:
			var e: GPUParticles3D = BossFx.emitter("steam", self, spot, 1.6)
			if e != null:
				e.emitting = true
				_vapour.append(e)
		var lox: Vector3 = RocketSite.LOX_LOCAL + Vector3(2.6, 3.4, 0.45)
		var e2: GPUParticles3D = BossFx.emitter("steam", self, lox, 1.2)
		if e2 != null:
			e2.emitting = true
			_vapour.append(e2)
	elif not on:
		for e3: GPUParticles3D in _vapour:
			if is_instance_valid(e3):
				e3.emitting = false
				var tw: SceneTreeTimer = get_tree().create_timer(6.0)
				tw.timeout.connect(e3.queue_free)
		_vapour.clear()


## The jet under the rocket: an emissive cone (scale k of the full main-stage jet), flames, a strong orange light.
func _flame_on(k: float) -> void:
	if rocket == null or not is_instance_valid(rocket):
		return
	if _flame == null or not is_instance_valid(_flame):
		_flame = Node3D.new()
		_flame.name = "Jet"
		rocket.add_child(_flame)
		var core: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.05
		cm.height = 1.0
		core.mesh = cm
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.72, 0.35, 0.9)
		mat.disable_receive_shadows = true
		core.material_override = mat
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.name = "Core"
		core.position = Vector3(0, -0.5, 0)
		_flame.add_child(core)
		var outer: MeshInstance3D = core.duplicate() as MeshInstance3D
		outer.name = "Outer"
		var m2: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		m2.albedo_color = Color(1.0, 0.4, 0.12, 0.45)
		outer.material_override = m2
		outer.scale = Vector3(1.5, 1.0, 1.5)
		_flame.add_child(outer)
		_flame_light = OmniLight3D.new()
		_flame_light.name = "JetLight"
		_flame_light.light_color = Color(1.0, 0.6, 0.25)
		_flame_light.omni_range = 40.0
		_flame_light.shadow_enabled = false
		_flame_light.position = Vector3(0, -2.0, 0)
		rocket.add_child(_flame_light)
	var length: float = lerpf(1.5, 9.0, k)
	_flame.scale = Vector3(lerpf(0.6, 1.0, k), length, lerpf(0.6, 1.0, k))
	_flame_light.light_energy = lerpf(2.0, 9.0, k)


func _make_trail(parent: Node3D) -> GPUParticles3D:
	if DisplayServer.get_name() == "headless":
		return null
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Trail"
	p.amount = 220
	p.lifetime = 14.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-450, -50, -450), Vector3(900, 600, 900))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0.4, 0.15, 0.0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	pm.scale_curve = Props._curve_tex([[0.0, 0.3], [1.0, 1.0]])
	pm.color_ramp = Props._ramp_tex([[0.0, Color(1.0, 0.7, 0.35, 0.9)], [0.05, Color(0.85, 0.83, 0.8, 0.75)], [1.0, Color(0.7, 0.7, 0.72, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(5, 5)
	var m: StandardMaterial3D = Props._particle_mat(Color(0, 0, 0), Color(0, 0, 0), 0.0, false)
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, -0.5, 0)
	parent.add_child(p)
	p.emitting = true
	return p


## The rocket out of sight: its jet off, it hidden, its trail left hanging where it was until the smoke has gone.
func _vanish() -> void:
	if rocket == null or not is_instance_valid(rocket) or not rocket.visible:
		return
	if _roar != null and is_instance_valid(_roar):
		_roar.stop()
	if _trail != null and is_instance_valid(_trail):
		var xf: Transform3D = _trail.global_transform
		_trail.get_parent().remove_child(_trail)
		add_child(_trail)
		_trail.top_level = true
		_trail.global_transform = xf
		_trail.emitting = false
		get_tree().create_timer(15.0).timeout.connect(_trail.queue_free)
		_trail = null
	rocket.visible = false
	_lift_t = -1.0


## A client joining after a launch: the table empty, the arm down.
func _show_gone() -> void:
	phase = Phase.GONE
	arm_pivot.rotation.z = PI * 0.5
	if rocket != null and is_instance_valid(rocket):
		rocket.visible = false


func _on_flag(flag: StringName, value: Variant) -> void:
	if flag != FLAG or phase == Phase.SEQUENCE or phase == Phase.ERECTING:
		return
	if int(value) == 1:
		_show_gone()
	elif phase == Phase.GONE:
		net_ready()


func _banner(text: String, small: String) -> void:
	var m: Node = _map()
	var hud: Object = m.get("hud") if m != null else null
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", "%s\n%s" % [text, small] if small != "" else text, 4.0)


## The count to the local player near the site (within count_radius of the table).
func _count_banner(n: int) -> void:
	var m: Node = _map()
	var me: Node3D = m.get("player") if m != null else null
	if me == null or me.global_position.distance_to(global_position) > float(cfg.get("count_radius", 60.0)):
		return
	var hud: Object = m.get("hud")
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", ("V2  ·  %d" % n) if n > 0 else "V2  ·  IGNITION", 0.95)


# ================================================================== the dev console

func _cmd(a: PackedStringArray) -> String:
	var what: String = a[0] if not a.is_empty() else "status"
	match what:
		"launch":
			if puppet:
				return "Only the host can launch."
			begin_launch()
			return "V2: the sequence has begun (%d s to lift-off)." % int(float(cfg.get("liftoff_at", 35.0)))
		"rearm":
			if phase != Phase.GONE:
				return "V2: a rocket is already up (or on its way)."
			begin_rearm()
			return "V2: a new rocket is being raised."
		_:
			return "V2: phase %s, t %.1f, launches %d, next launch rounds: first %d, every %d." % [Phase.keys()[phase], t, launches,
				int(cfg.get("first_round", 6)), int(cfg.get("every", 5))]
