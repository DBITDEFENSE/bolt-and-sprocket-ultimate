class_name Kranfuehrer
extends HomageBoss
## DER KRANFÜHRER, Map 4 Act I's boss (UPDATE 07, docs/MAP4_FERNFLUG.md §3.8): the Great Hangar's night crane
## driver, fused into the gantry crane's cab 12 m up. He IS the crane: the body (the driver, the weak point) rides a
## trolley along the east crane rail; the bridge spans the hangar under him and the hook hangs from it. Phases
## (data: bosses/map04.json "kranfuehrer"): (1) CASINGS: he runs the rail and drops bomb casings on a player
## (a chain rattle telegraph, then a 2.5 m impact that hurts everyone and kills zombies); (2) at `sweep_at` HP
## he lowers the hook and SWEEPS the floor along the bridge at 3 m/s (duck under the Kranich's belly or get
## off the line); (3) at `park_at` he PARKS over the ramp and drops a RING of casings round it, and the cab is
## best reached from the crane-rail catwalks. Reward: Scrip per player, a Resupply, the `kranfuehrer_down` flag (the hangar key is
## the egg's: only a kill while he is parked over the ramp, T-114).
## He never leaves the rail; `failsafe_seconds` after spawning he retreats (a round can never softlock on him).
## Pure rules are static for the tests (`phase_of`, `next_trolley_z`, `hook_hits`, `lights_to_drop`, `is_alone`).
## T-234 (docs/BOSS_REWORK.md, docs/boss_rework/w4_fernflug.md): the cab wears rust and oil (drips under the floor), a
## violet gauge pulses on its face, the hook hangs from a real chain (two runs, short and lowered), the man sits fused
## into the seat by violet cable tubes with his eyes catching the gauge; the rail screeches while the trolley runs
## (`kran_rail_screech` loop), a casing whistles down (`kran_casing_drop`) and lands with a stomp, sparks and dust;
## every telegraph lights through the kit. The new beat: the hangar's work lights die one by one as his phases
## advance (`rework.lights_drop_fraction` of them at phase 2 and again at phase 3, never the `keep_lit` nearest the
## ramp), each guttering out with a glass pop and sparks. The squad rule: a player with no teammate within
## `rework.alone_dist` m (in a squad of two or more) is found faster: the trolley at `alone_speed_mult`, the casing's
## cooldown at `alone_cd_mult`.

enum K { RUN, TELEGRAPH_DROP, DROP, SWEEP_TELEGRAPH, SWEEP, PARK_TELEGRAPH, RING, RECOVER }

const RUST: Color = Color(0.42, 0.2, 0.1)
const OIL: Color = Color(0.08, 0.07, 0.06)
const GAUGE_VIOLET: Color = Color(0.7, 0.38, 1.0)
const AMBER: Color = Color(1.0, 0.62, 0.22)

var kcfg: Dictionary = {}
var rail: Dictionary = {}
var kstate: K = K.RUN
var trolley_z: float = 0.0
var dir_z: float = 1.0
var hook_x: float = 0.0
var hook_down: bool = false
var sweep_dir: float = 1.0
var _target_pos: Vector3 = Vector3.ZERO
var _kt: float = 0.0
var _spawn_t: float = 0.0
var phase: int = 1
var drops_done: int = 0
var sweeps_done: int = 0
var rings_done: int = 0
var _crane: Node3D = null
var _bridge: Node3D = null
var _hook: Node3D = null
var _chain_short: Node3D = null
var _chain_long: Node3D = null
var _gauge_mat: StandardMaterial3D = null
var _gauge_light: OmniLight3D = null
var _oil: GPUParticles3D = null
var _rail_loop: AudioStreamPlayer3D = null
var _rail_on: bool = false
var _title_done: bool = false
# T-234: the hangar's work lights
var work_lights: Array = []          # [OmniLight3D, base energy], the farthest from the ramp first
var _drop_queue: Array = []          # the lights still to put out
var _drop_t: float = 0.0
var lights_dropped: int = 0
var lights_phase_done: int = 1       # the phase whose drops were queued
var alone_now: bool = false          # the squad rule's state this frame (the smoke, the tests)
var _breath_t: float = 3.0
var _last_z: float = 0.0
var _hit_players: Dictionary = {}


static func table() -> Dictionary:
	return GLData.table("bosses/map04")


func _dir() -> ZombieDirector:
	return director as ZombieDirector


func boss_cfg() -> Dictionary:
	return (table().get("bosses", {}) as Dictionary).get("kranfuehrer", {})


## Phase by HP fraction: 1 casings, 2 the sweep, 3 parked over the ramp.
static func phase_of(hp_fraction: float, phases: Dictionary) -> int:
	if hp_fraction <= float(phases.get("park_at", 0.3)):
		return 3
	if hp_fraction <= float(phases.get("sweep_at", 0.6)):
		return 2
	return 1


## The trolley's next z running toward `want_z` at `speed`, clamped to the rail.
static func next_trolley_z(z: float, want_z: float, speed: float, delta: float, z_min: float, z_max: float) -> float:
	return clampf(move_toward(z, clampf(want_z, z_min, z_max), speed * delta), z_min, z_max)


## True when a body at `p` is hit by the hook sweeping at `hook` (within half_width along z, under `height`, on the bridge's span).
static func hook_hits(hook: Vector3, p: Vector3, half_width: float, height: float, x_min: float, x_max: float) -> bool:
	return absf(p.z - hook.z) <= half_width and p.y < hook.y + height and p.x >= x_min and p.x <= x_max


## T-234: how many of `lit` work lights (of `total`) a phase step puts out: `fraction` of the total, rounded up,
## never below `keep_lit` left burning.
static func lights_to_drop(total: int, lit: int, fraction: float, keep_lit: int) -> int:
	if total <= 0 or lit <= keep_lit:
		return 0
	var want: int = int(ceil(float(total) * clampf(fraction, 0.0, 1.0)))
	return clampi(mini(want, lit - keep_lit), 0, lit)


## T-234: a player at `p` is alone when the squad has others and none of them stands within `dist` m (flat).
static func is_alone(p: Vector3, others: Array, dist: float) -> bool:
	if others.is_empty():
		return false
	for o: Variant in others:
		var q: Vector3 = o as Vector3
		if Vector2(q.x - p.x, q.z - p.z).length() <= dist:
			return false
	return true


func _ready() -> void:
	super._ready()
	boss_key = "kranfuehrer"
	ecfg = table()
	kcfg = boss_cfg()
	bcfg = kcfg
	rail = kcfg.get("rail", {})


func modelled() -> bool:
	return false


func person_id() -> String:
	return "kranfuehrer"


func rcfg() -> Dictionary:
	return kcfg.get("rework", {})


## The base dresses a cousin (a thin woman, porcelain pale); he is a works fitter: a man in the technician's kit.
func _on_spawned() -> void:
	_female = false
	_build = "medium"
	_body.mesh = ZombieBody.build_skinned("technician", "medium", false)
	_set_inst("inst_tint", Color(0.92, 0.9, 0.9, 1.0))


## Brings the crane in: the driver on the trolley at the rail's near end.
func spawn_crane(_at: Vector3, health: float) -> void:
	spawn_homage(Vector3(float(rail.get("x", 28.0)), float(rail.get("y", 12.0)), float(rail.get("z_min", 156.0))), health)
	enemy_id = &"kranfuehrer"
	collision_mask = 0
	trolley_z = float(rail.get("z_min", 156.0))
	_last_z = trolley_z
	hook_x = (float(rail.get("bridge_x_min", -68.0)) + float(rail.get("bridge_x_max", 28.0))) * 0.5
	kstate = K.RUN
	_kt = 0.0
	_spawn_t = 0.0
	phase = 1
	lights_phase_done = 1
	_drop_queue.clear()
	_set_inst("inst_dirt", 0.65)   # oil
	_build_crane()
	_gather_work_lights()
	RoundManager.reserve_alive(1)
	if not _title_done:
		_title_done = true
		var hud: BossHud = BossHud.new()
		_map().add_child(hud)
		hud.title_card(str(kcfg.get("title", "DER KRANFÜHRER")), str(kcfg.get("subtitle", "the crane driver")), "MAI 1945  ·  WERK THALBACH")
		hud.add_bar("kranfuehrer", self, str(kcfg.get("title", "DER KRANFÜHRER")), str(kcfg.get("subtitle", "")))
		if str(kcfg.get("spawn_vo", "")) != "":
			GLVO.play(StringName(str(kcfg["spawn_vo"])))


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


# ================================================================== the model (T-234)

## The man: fused into the seat by violet cable tubes from his spine, oil on his skin, cracks where the metal
## meets him, eyes that catch the gauge.
func _build_costume() -> void:
	var violet: Color = Color(0.5, 0.25, 0.8)
	cable("Spine", [Vector3(-0.08, 0.05, 0.12), Vector3(-0.14, -0.05, 0.3), Vector3(-0.18, -0.25, 0.42)], 0.022, violet, 1.4, GAUGE_VIOLET)
	cable("Spine", [Vector3(0.08, 0.12, 0.12), Vector3(0.15, 0.0, 0.3), Vector3(0.2, -0.2, 0.44)], 0.022, violet, 1.4, GAUGE_VIOLET)
	cable("Chest", [Vector3(0.0, 0.18, 0.1), Vector3(0.0, 0.1, 0.3), Vector3(0.0, -0.1, 0.42)], 0.018, Color(0.2, 0.18, 0.17), 0.0)
	cracks("Chest", 8, 0.19, -0.05, 0.25, GAUGE_VIOLET, 1.4, 11)
	wet(0.3)
	eye_glow(Color(0.85, 0.6, 1.0), 1.0, 4.5)
	# the driver's cap and goggles pushed up, leather on the hands
	costume("Head", [HomageBoss.sph(0.16, Vector3(0, 0.08, 0), Color(0.16, 0.14, 0.12)), HomageBoss.boxp(Vector3(0.2, 0.05, 0.08), Vector3(0, 0.17, -0.06), Color(0.1, 0.09, 0.08))], 0.0)
	for side: String in ["Left", "Right"]:
		costume(side + "Hand", [HomageBoss.sph(0.06, Vector3(0, -0.02, 0), Color(0.22, 0.14, 0.08), Vector3(1.0, 0.8, 1.2))], 0.0)


func _mesh_box(parent: Node3D, center: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	bm.material = m
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = bm
	mi.position = center
	parent.add_child(mi)
	return mi


## A run of chain links between two local points (torus links turned alternately) on `parent`, with the hook at
## its end (a shank and a bill).
func _chain_run(parent: Node3D, from: Vector3, to: Vector3, radius: float) -> Node3D:
	var holder: Node3D = Node3D.new()
	parent.add_child(holder)
	var d: Vector3 = to - from
	var links: int = maxi(2, int(d.length() / (radius * 1.7)))
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = radius * 0.5
	tor.outer_radius = radius
	tor.rings = 8
	tor.ring_segments = 10
	var mesh: ArrayMesh = ArrayMesh.new()
	var st: SurfaceTool = SurfaceTool.new()
	var dn: Vector3 = d.normalized()
	var basis0: Basis = Basis.looking_at(dn, Vector3.UP if absf(dn.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT)
	for i: int in links:
		var t: float = (float(i) + 0.5) / float(links)
		var b: Basis = basis0 * Basis(Vector3.FORWARD, PI * 0.5 * float(i % 2)) * Basis(Vector3.RIGHT, PI * 0.5)
		st.append_from(tor, 0, Transform3D(b, from + d * t))
	st.commit(mesh)
	mesh.surface_set_material(0, HomageBoss.mat_ex(Color(0.3, 0.28, 0.26), 0.45, 0.85))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	holder.add_child(mi)
	var hk: Node3D = Node3D.new()
	hk.position = to
	holder.add_child(hk)
	var iron: StandardMaterial3D = HomageBoss.mat_ex(Color(0.22, 0.2, 0.19), 0.5, 0.8)
	_mesh_box(hk, Vector3(0, -0.25, 0), Vector3(0.14, 0.5, 0.14), iron)
	_mesh_box(hk, Vector3(0.18, -0.55, 0), Vector3(0.5, 0.14, 0.14), iron)
	_mesh_box(hk, Vector3(0.38, -0.4, 0), Vector3(0.14, 0.4, 0.14), iron)
	_mesh_box(hk, Vector3(0.0, -0.08, 0.075), Vector3(0.1, 0.16, 0.01), HomageBoss.mat_ex(RUST, 0.95, 0.1))
	return holder


## The crane itself: the trolley cab round the driver (rust, oil, the violet gauge), the bridge under the rail, the
## hook on its chain (a short run while he runs the rail, a lowered one for the sweep).
func _build_crane() -> void:
	if _crane != null:
		return
	_crane = Node3D.new()
	_crane.name = "Crane"
	add_child(_crane)
	var cab: Node3D = Props.group(_crane, "Cab", Vector3(0, 0, 0))
	Props.block(cab, Vector3(-1.4, -0.3, -1.4), Vector3(1.4, -0.1, 1.4), "crane_yellow")
	Props.block(cab, Vector3(-1.4, -0.1, -1.4), Vector3(-1.25, 2.2, 1.4), "crane_yellow")
	Props.block(cab, Vector3(-1.4, 2.2, -1.4), Vector3(1.4, 2.4, 1.4), "crane_yellow")
	Props.block(cab, Vector3(-1.4, -0.1, -1.4), Vector3(1.4, 1.0, -1.25), "crane_yellow")
	Props.block(cab, Vector3(-1.4, -0.1, 1.25), Vector3(1.4, 1.0, 1.4), "crane_yellow")
	# T-234: rust where the water ran, oil down the front, the seat he is fused into, the controls under his hands
	var rust: StandardMaterial3D = HomageBoss.mat_ex(RUST, 0.95, 0.1)
	var oil: StandardMaterial3D = HomageBoss.mat_ex(OIL, 0.12, 0.3)
	for e: Array in [[Vector3(-1.33, 0.2, -0.6), Vector3(0.02, 0.6, 0.5)], [Vector3(-1.33, 0.9, 0.7), Vector3(0.02, 0.5, 0.35)],
			[Vector3(0.4, 0.5, -1.33), Vector3(0.6, 0.9, 0.02)], [Vector3(-0.8, 0.15, 1.33), Vector3(0.5, 0.45, 0.02)],
			[Vector3(0.9, 2.31, -0.9), Vector3(0.8, 0.02, 0.6)], [Vector3(-0.3, -0.31, 0.5), Vector3(1.2, 0.02, 0.7)]]:
		_mesh_box(cab, e[0], e[1], rust)
	for e: Array in [[Vector3(-0.2, 0.3, -1.34), Vector3(0.18, 0.7, 0.01)], [Vector3(0.7, 0.2, -1.34), Vector3(0.1, 0.5, 0.01)],
			[Vector3(0.1, -0.09, 0.3), Vector3(1.1, 0.01, 0.9)]]:
		_mesh_box(cab, e[0], e[1], oil)
	var seat: StandardMaterial3D = HomageBoss.mat_ex(Color(0.2, 0.17, 0.14), 0.8, 0.0)
	_mesh_box(cab, Vector3(0, 0.55, 0.42), Vector3(0.5, 0.06, 0.45), seat)
	_mesh_box(cab, Vector3(0, 1.0, 0.62), Vector3(0.5, 0.9, 0.08), seat)
	var iron: StandardMaterial3D = HomageBoss.mat_ex(Color(0.25, 0.24, 0.23), 0.5, 0.8)
	_mesh_box(cab, Vector3(0, 0.9, -0.45), Vector3(0.9, 0.08, 0.3), iron)
	for x: float in [-0.25, 0.25]:
		_mesh_box(cab, Vector3(x, 1.08, -0.45), Vector3(0.03, 0.3, 0.03), iron)
		_mesh_box(cab, Vector3(x, 1.24, -0.45), Vector3(0.06, 0.06, 0.06), HomageBoss.mat_ex(Color(0.1, 0.09, 0.08), 0.4, 0.0))
	# the gauge: its own material (it pulses) and a weak violet light on the cab's face
	_gauge_mat = StandardMaterial3D.new()
	_gauge_mat.albedo_color = Color(0.1, 0.06, 0.14)
	_gauge_mat.emission_enabled = true
	_gauge_mat.emission = GAUGE_VIOLET
	_gauge_mat.emission_energy_multiplier = 1.5
	_gauge_mat.roughness = 0.2
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.16
	cm.height = 0.04
	cm.radial_segments = 16
	cm.material = _gauge_mat
	var gauge: MeshInstance3D = MeshInstance3D.new()
	gauge.mesh = cm
	gauge.position = Vector3(0.0, 1.55, -1.38)
	gauge.rotation.x = PI * 0.5
	cab.add_child(gauge)
	_mesh_box(cab, Vector3(0.0, 1.55, -1.36), Vector3(0.44, 0.44, 0.03), HomageBoss.mat_ex(Color(0.14, 0.13, 0.12), 0.6, 0.6))
	_gauge_light = OmniLight3D.new()
	_gauge_light.light_color = GAUGE_VIOLET
	_gauge_light.light_energy = 0.9
	_gauge_light.omni_range = 5.0
	_gauge_light.shadow_enabled = false
	_gauge_light.position = Vector3(0, 1.5, -1.9)
	cab.add_child(_gauge_light)
	_oil = BossFx.emitter("drips", cab, Vector3(0.5, -0.32, 0.6), 0.8)
	_oil.emitting = true
	_bridge = Props.group(_crane, "Bridge", Vector3(0, -0.4, 0))
	var span: float = float(rail.get("bridge_x_max", 28.0)) - float(rail.get("bridge_x_min", -68.0))
	Props.block(_bridge, Vector3(-span - 1.5, 0.0, -0.5), Vector3(1.5, 0.8, 0.5), "crane_yellow")
	for i: int in 6:
		_mesh_box(_bridge, Vector3(-span * (float(i) + 0.5) / 6.0, 0.4, -0.51), Vector3(1.6, 0.5, 0.02), rust)
	_hook = Props.group(_crane, "Hook", Vector3(hook_x - global_position.x, -0.4, 0))
	var drop_long: float = float(kcfg.get("sweep", {}).get("height", 2.0)) + 9.0
	_chain_short = _chain_run(_hook, Vector3.ZERO, Vector3(0, -1.6, 0), 0.06)
	_chain_long = _chain_run(_hook, Vector3.ZERO, Vector3(0, -drop_long, 0), 0.06)
	_chain_long.visible = false
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.3)
	glow.light_energy = 1.2
	glow.omni_range = 10.0
	glow.position = Vector3(0, 1.5, 0)
	_crane.add_child(glow)
	_rail_loop = AudioDirector.make_loop_3d("kran_rail_screech", _crane, float(rcfg().get("rail_loop_db", -6.0)))


## The hangar's work lights (the power lights of H_HALLE), the farthest from the ramp first: those die first.
func _gather_work_lights() -> void:
	work_lights.clear()
	var ramp_z: float = float(rail.get("ramp_z", 162.0))
	var rows: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"power_lights"):
		var l: OmniLight3D = n as OmniLight3D
		if l == null or String(l.get_meta("zone", "")) != "H_HALLE" or l.light_energy <= 0.0:
			continue
		rows.append([l, l.light_energy, absf(l.global_position.z - ramp_z)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	for r: Array in rows:
		work_lights.append([r[0], r[1]])


## T-234: the phase advanced: queue the next share of the work lights to die.
func _queue_light_drops() -> void:
	var lit: int = 0
	for e: Array in work_lights:
		var l: OmniLight3D = e[0] as OmniLight3D
		if is_instance_valid(l) and l.light_energy > 0.0 and not _drop_queue.has(e):
			lit += 1
	var n: int = lights_to_drop(work_lights.size(), lit, float(rcfg().get("lights_drop_fraction", 0.35)), int(rcfg().get("keep_lit", 3)))
	for e: Array in work_lights:
		if n <= 0:
			break
		var l: OmniLight3D = e[0] as OmniLight3D
		if is_instance_valid(l) and l.light_energy > 0.0 and not _drop_queue.has(e):
			_drop_queue.append(e)
			n -= 1
	_drop_t = 0.6


func _tick_light_drops(delta: float) -> void:
	if _drop_queue.is_empty():
		return
	_drop_t -= delta
	if _drop_t > 0.0:
		return
	_drop_t = float(rcfg().get("drop_gap", 1.1))
	var e: Array = _drop_queue.pop_front()
	var l: OmniLight3D = e[0] as OmniLight3D
	if not is_instance_valid(l):
		return
	lights_dropped += 1
	var base: float = float(e[1])
	var tw: Tween = create_tween()
	tw.tween_property(l, "light_energy", base * 1.5, 0.08)
	tw.tween_property(l, "light_energy", base * 0.15, 0.12)
	tw.tween_property(l, "light_energy", base * 1.1, 0.1)
	tw.tween_property(l, "light_energy", 0.0, 0.25)
	var at: Vector3 = l.global_position
	BossFx.burst("sparks", at, get_tree(), 1.2, 1.0)
	BossFx.burst("chips", at, get_tree(), 0.6, 0.8)
	AudioDirector.play_3d("boss_hit_glass", at, 2.0, 0.08)
	fx.shake_all(at, 0.12, 12.0)


## The work lights back (a death or a retreat), if the works still have power.
func _restore_work_lights() -> void:
	_drop_queue.clear()
	if not GameState.power_on:
		return
	for e: Array in work_lights:
		var l: OmniLight3D = e[0] as OmniLight3D
		if is_instance_valid(l):
			var tw: Tween = create_tween()
			tw.tween_property(l, "light_energy", float(e[1]), 2.5)


func _hook_world() -> Vector3:
	var hy: float = global_position.y - 0.4 - (float(kcfg.get("sweep", {}).get("height", 2.0)) + 9.0 if hook_down else 1.6)
	return Vector3(hook_x, hy, trolley_z)


func _set_hook_visual() -> void:
	if _hook == null:
		return
	_hook.position.x = hook_x - global_position.x
	if _chain_short != null:
		_chain_short.visible = not hook_down
	if _chain_long != null:
		_chain_long.visible = hook_down


func _process(_delta: float) -> void:
	if _gauge_mat == null or not is_active():
		return
	# the gauge pulses, faster as the phases advance; a telegraph pins it bright
	var rate: float = 1.2 + 0.8 * float(phase - 1)
	var k: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_clock * TAU * rate * 0.5))
	if kstate in [K.TELEGRAPH_DROP, K.SWEEP_TELEGRAPH, K.PARK_TELEGRAPH]:
		k = 1.0
	_gauge_mat.emission_energy_multiplier = 0.8 + 2.4 * k
	if _gauge_light != null:
		_gauge_light.light_energy = 0.4 + 1.2 * k


## True when `target` stands alone (the squad rule; a squad of one is never "alone": nothing to be apart from).
func _target_alone() -> bool:
	if target == null:
		return false
	var others: Array = []
	for p: Player in alive_players():
		if p != target:
			others.append(p.global_position)
	return is_alone(target.global_position, others, float(rcfg().get("alone_dist", 12.0)))


func _tick(delta: float) -> void:
	_spawn_t += delta
	_kt += delta
	if _spawn_t > float(ecfg.get("failsafe_seconds", 360.0)) and not retreating:
		retreat()
		return
	var new_phase: int = phase_of(hp_fraction(), kcfg.get("phases", {}))
	if new_phase != phase:
		phase = new_phase
	while lights_phase_done < phase:
		lights_phase_done += 1
		_queue_light_drops()
		sfx("boss_roar_low", -6.0, 0.8)
	_tick_light_drops(delta)
	alone_now = _target_alone()
	var speed: float = float(rail.get("speed", 3.0)) * squad_speed_mult * (float(rcfg().get("alone_speed_mult", 1.3)) if alone_now else 1.0)
	var z_min: float = float(rail.get("z_min", 156.0))
	var z_max: float = float(rail.get("z_max", 212.0))
	var want_z: float = trolley_z
	var casing_cd_mult: float = float(rcfg().get("alone_cd_mult", 0.75)) if alone_now else 1.0
	match kstate:
		K.RUN:
			# run the rail toward the nearest player's z (phase 3: toward the ramp); begin a move when its clock is ready
			if phase == 3:
				want_z = float(rail.get("ramp_z", 162.0))
			elif target != null:
				want_z = target.global_position.z
			trolley_z = next_trolley_z(trolley_z, want_z, speed, delta, z_min, z_max)
			if phase == 3 and absf(trolley_z - want_z) < 0.5 and cd_ready("ring"):
				if not GameState.has_flag(&"under_ramp"):
					GameState.set_flag(&"under_ramp")   # the egg's kill condition (T-114): he dies parked over the ramp
				kstate = K.PARK_TELEGRAPH
				_kt = 0.0
				bstate = B.TELEGRAPH
				sfx("chain", 0.0, 0.8)
				fx.tele(Color(1.0, 0.4, 0.2), 5.0, float(kcfg.get("ring", {}).get("telegraph", 1.8)))
			elif phase == 2 and cd_ready("sweep") and target != null and absf(trolley_z - want_z) < 2.0:
				kstate = K.SWEEP_TELEGRAPH
				_kt = 0.0
				bstate = B.TELEGRAPH
				sweep_dir = 1.0 if target.global_position.x > hook_x else -1.0
				sfx("chain", 0.0, 0.7)
				fx.tele(GAUGE_VIOLET, 4.5, float(kcfg.get("sweep", {}).get("telegraph", 1.2)))
			elif phase != 3 and cd_ready("casing") and target != null and absf(trolley_z - want_z) < 1.5:
				kstate = K.TELEGRAPH_DROP
				_kt = 0.0
				bstate = B.TELEGRAPH
				var lead: float = float(kcfg.get("casing", {}).get("lead", 0.6))
				_target_pos = target.global_position + Vector3(target.velocity.x, 0, target.velocity.z) * lead
				_target_pos.x = clampf(_target_pos.x, float(rail.get("bridge_x_min", -68.0)), float(rail.get("bridge_x_max", 28.0)))
				_target_pos.z = trolley_z
				hook_x = _target_pos.x
				sfx("chain", 0.0, 1.0)
				fx.tele(AMBER, 4.0, float(kcfg.get("casing", {}).get("telegraph", 1.6)))
		K.TELEGRAPH_DROP:
			if _kt >= float(kcfg.get("casing", {}).get("telegraph", 1.6)):
				kstate = K.DROP
				_kt = 0.0
				bstate = B.ACTIVE
				AudioDirector.play_3d("kran_casing_drop", Vector3(_target_pos.x, global_position.y - 2.0, trolley_z), 2.0, 0.05)
		K.DROP:
			if _kt >= float(kcfg.get("casing", {}).get("fall_seconds", 0.9)):
				_impact(Vector3(_target_pos.x, _target_pos.y, _target_pos.z), float(kcfg.get("casing", {}).get("radius", 2.5)),
					float(kcfg.get("casing", {}).get("damage", 150)), float(kcfg.get("casing", {}).get("zombie_damage", 4000)))
				drops_done += 1
				moves_used["casing"] = int(moves_used.get("casing", 0)) + 1
				set_cd("casing", float(kcfg.get("casing", {}).get("cooldown", 5.0)) * casing_cd_mult)
				kstate = K.RECOVER
				_kt = 0.0
				bstate = B.RECOVER
		K.SWEEP_TELEGRAPH:
			if _kt >= float(kcfg.get("sweep", {}).get("telegraph", 1.2)):
				kstate = K.SWEEP
				hook_down = true
				hook_x = float(rail.get("bridge_x_min", -68.0)) if sweep_dir > 0.0 else float(rail.get("bridge_x_max", 28.0))
				_kt = 0.0
				bstate = B.ACTIVE
				sfx("chain", 3.0, 0.6)
				if _rail_loop != null:
					_rail_loop.pitch_scale = 0.7
		K.SWEEP:
			var sw: Dictionary = kcfg.get("sweep", {})
			hook_x += sweep_dir * float(sw.get("speed", 3.0)) * squad_speed_mult * delta
			var hk: Vector3 = _hook_world()
			if fmod(_kt, 0.5) < delta:
				BossFx.burst("sparks", hk + Vector3(0, -0.6, 0), get_tree(), 0.5, 0.8)
			for p: Player in alive_players():
				if hook_hits(hk, p.global_position, float(sw.get("half_width", 1.5)), float(sw.get("height", 2.0)), float(rail.get("bridge_x_min", -68.0)), float(rail.get("bridge_x_max", 28.0))) and not _hit_players.has(p.player_id):
					_hit_players[p.player_id] = true
					hit_player(p, float(sw.get("damage", 90)))
					AudioDirector.play_3d("boss_hit_iron", p.global_position + Vector3.UP, 2.0)
			if _dir() != null:
				for z: Zombie in _dir().active_zombies():
					if z != self and z.is_active() and hook_hits(hk, z.global_position, float(sw.get("half_width", 1.5)), float(sw.get("height", 2.0)), float(rail.get("bridge_x_min", -68.0)), float(rail.get("bridge_x_max", 28.0))):
						z.take_damage(4000.0, &"torso", &"kranfuehrer", 0, &"melee")
			if hook_x <= float(rail.get("bridge_x_min", -68.0)) or hook_x >= float(rail.get("bridge_x_max", 28.0)):
				hook_down = false
				_hit_players.clear()
				sweeps_done += 1
				moves_used["sweep"] = int(moves_used.get("sweep", 0)) + 1
				set_cd("sweep", float(sw.get("cooldown", 7.0)))
				kstate = K.RECOVER
				_kt = 0.0
				bstate = B.RECOVER
		K.PARK_TELEGRAPH:
			if _kt >= float(kcfg.get("ring", {}).get("telegraph", 1.8)):
				kstate = K.RING
				_kt = 0.0
				bstate = B.ACTIVE
		K.RING:
			var rg: Dictionary = kcfg.get("ring", {})
			var center: Vector3 = Vector3(hook_x, 0.0, trolley_z)
			var n: int = int(rg.get("count", 6))
			AudioDirector.play_3d("kran_casing_drop", center + Vector3.UP * 6.0, 4.0, 0.05)
			for i: int in n:
				var a: float = TAU * float(i) / float(n)
				_impact(center + Vector3(cos(a), 0, sin(a)) * float(rg.get("radius", 9.0)), float(rg.get("impact_radius", 2.5)),
					float(rg.get("damage", 150)), float(rg.get("zombie_damage", 4000)))
			rings_done += 1
			moves_used["ring"] = int(moves_used.get("ring", 0)) + 1
			set_cd("ring", float(rg.get("cooldown", 8.0)))
			kstate = K.RECOVER
			_kt = 0.0
			bstate = B.RECOVER
		K.RECOVER:
			if _kt >= 0.8:
				kstate = K.RUN
				bstate = B.MOVE
	global_position = Vector3(float(rail.get("x", 28.0)), float(rail.get("y", 12.0)), trolley_z)
	velocity = Vector3.ZERO
	if target != null:
		_face(Vector3(target.global_position.x, global_position.y, target.global_position.z))
	_set_hook_visual()
	_tick_rail_sound(delta)


## The rail screeches while the trolley runs (higher when he hunts someone alone), quiet when it stands.
func _tick_rail_sound(delta: float) -> void:
	var moving: bool = absf(trolley_z - _last_z) > 0.001
	_last_z = trolley_z
	if _rail_loop == null:
		return
	if moving and not _rail_on:
		_rail_on = true
		_rail_loop.play()
	elif not moving and _rail_on:
		_rail_on = false
		_rail_loop.stop()
	if _rail_on and kstate != K.SWEEP:
		_rail_loop.pitch_scale = move_toward(_rail_loop.pitch_scale, 1.25 if alone_now else 1.0, delta * 0.8)
		fx.extra_dread = maxf(fx.extra_dread, 0.08)


func _impact(at: Vector3, radius: float, damage: float, zombie_damage: float) -> void:
	AudioDirector.play_3d("boss_stomp", at + Vector3.UP, 6.0, 0.08)
	AudioDirector.play_3d("boss_hit_iron", at + Vector3.UP, 4.0, 0.1)
	BossFx.burst("sparks", at + Vector3.UP * 0.4, get_tree(), 1.6, 1.3)
	BossFx.burst("dust", at + Vector3.UP * 0.3, get_tree(), 2.0, 1.8)
	Effects.scorch(at, 1.6)
	for p: Player in alive_players():
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= radius and absf(p.global_position.y - at.y) < 3.0:
			hit_player(p, damage)
	fx.shake_all(at, 0.5, 20.0)
	if _dir() != null:
		for z: Zombie in _dir().active_zombies():
			if z != self and z.is_active() and Vector2(z.global_position.x - at.x, z.global_position.z - at.z).length() <= radius and absf(z.global_position.y - at.y) < 3.0:
				z.take_damage(zombie_damage, &"torso", &"kranfuehrer", 0, &"explosive")
	# a casing left on the floor (dressing, cleared with the round)
	var casing: MeshInstance3D = Props.cyl(_map() as Node3D if _map() is Node3D else self, at + Vector3(0, 0.35, 0), 0.35, 2.0, "steel", Vector3(0, 0, 90))
	if casing != null:
		casing.add_to_group(&"map04_casings")
		get_tree().create_timer(40.0).timeout.connect(func() -> void:
			if is_instance_valid(casing):
				casing.queue_free())


func _tele_glow() -> float:
	return 4.0 if kstate in [K.TELEGRAPH_DROP, K.SWEEP_TELEGRAPH, K.PARK_TELEGRAPH] else 0.0


## No Cousins' hum: the man's breath between moves, through the cab's open window.
func _update_audio(delta: float) -> void:
	_breath_t -= delta
	if _breath_t <= 0.0 and kstate in [K.RUN, K.RECOVER]:
		_breath_t = float(rcfg().get("breath_every", 5.0)) * randf_range(0.8, 1.3)
		sfx("boss_breath", -9.0, 0.9)


func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
	hook_down = false
	_set_hook_visual()
	if _rail_loop != null:
		_rail_loop.stop()
	if _oil != null:
		_oil.emitting = false
	if _gauge_mat != null:
		_gauge_mat.emission_energy_multiplier = 0.0
	if _gauge_light != null:
		_gauge_light.light_energy = 0.0
	BossFx.burst("sparks", global_position + Vector3(0, 1.2, -1.3), get_tree(), 2.0, 1.4)
	BossFx.burst("smoke", global_position + Vector3(0, 1.5, 0), get_tree(), 2.0, 1.6)
	for d: Variant in kcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), Vector3(hook_x, 0.3, trolley_z))
	if str(kcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(kcfg["flag"])))
	if str(kcfg.get("death_vo", "")) != "":
		GLVO.play(StringName(str(kcfg["death_vo"])))
	get_tree().create_timer(2.0).timeout.connect(_restore_work_lights)
	if is_instance_valid(_crane):
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if is_instance_valid(_crane):
				_crane.visible = false)


func _on_retreat() -> void:
	# the reserve_alive of the spawn and the take_extra_spawn count: a death pays the latter in HomageBoss._boss_die,
	# a retreat has no death, and the round could never end on it (T-109)
	RoundManager.release_alive(2)
	if _rail_loop != null:
		_rail_loop.stop()
	_restore_work_lights()
	if GameState.has_flag(&"under_ramp"):
		GameState.set_flag(&"under_ramp", false)   # back to the rails: the egg's condition resets, nothing is lost


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)
