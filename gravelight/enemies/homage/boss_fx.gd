class_name BossFx
extends Node3D
## The boss effects kit (T-231, docs/BOSS_REWORK.md section 2.1): what every boss fight shares, owned by a HomageBoss
## as `fx` (the Foreman makes its own with `BossFx.make(self, dread_cfg)`). Presentation only: nothing here changes
## damage, timing, hitboxes or navigation.
##   - dread: each tenth of a second the local human's distance to the boss, the boss's facing and the line of sight
##     become a 0..1 presence level reported to DreadFx (the vignette, the desaturation, the pulse, the bed);
##     `extra_dread` adds a subclass's own (a telegraph aimed at you, a grab, a beam);
##   - stomp(): a footfall with weight: dust under the foot, the thud, a view shake on every player in range;
##   - lights_dim() / lights_flicker() / lights_restore(): the arena's lights captured and eased (FlickerLights by
##     their base_energy, so they keep flickering; LampGlow follows every light, so glass and flames dim too);
##   - emitter() / burst(): quality-scaled GPUParticles3D of a few kinds (dust, embers, motes, drips, steam, frost,
##     sparks, ash, smoke, chips, mist);
##   - hit(): a burst and a sound at the limb that was hit, by the boss's surface; a weak point flashes violet and
##     a heavy hit punches the dread layer;
##   - tele(): the telegraph light's one shape (rise, hold, snap out) with the rising sound;
##   - death_burst(): motes and light, the toll, the dread released.
## Data: the boss block's "dread" (every key optional): radius, near, surface, step_sound, step_shake, step_radius,
## look_cone_deg, bed, pulse.

const DEFAULTS: Dictionary = {
	"radius": 18.0, "near": 5.0, "surface": "flesh", "step_sound": "", "step_shake": 0.0,
	"step_radius": 14.0, "look_cone_deg": 30.0, "weak_mult": 1.5, "punch_fraction": 0.02}   # a boss opts into footfalls with step_sound / step_shake

## Emitter kinds: [color, size, lifetime, speed, gravity y, spread deg, amount, additive, shaded]
const KINDS: Dictionary = {
	"dust": [Color(0.55, 0.5, 0.42, 0.55), 0.35, 1.4, 1.2, 0.3, 40.0, 24, false, true],
	"smoke": [Color(0.25, 0.24, 0.24, 0.5), 0.6, 2.4, 0.8, 0.5, 25.0, 18, false, true],
	"embers": [Color(1.0, 0.45, 0.12, 1.0), 0.05, 1.6, 1.5, 0.8, 50.0, 30, true, false],
	"motes": [Color(0.72, 0.42, 1.0, 1.0), 0.04, 2.2, 0.5, 0.25, 70.0, 36, true, false],
	"drips": [Color(0.25, 0.3, 0.33, 0.9), 0.03, 0.9, 0.4, -6.0, 8.0, 14, false, true],
	"steam": [Color(0.8, 0.82, 0.86, 0.4), 0.3, 1.2, 1.0, 0.7, 35.0, 20, false, true],
	"frost": [Color(0.8, 0.9, 1.0, 0.8), 0.03, 1.6, 0.3, -0.15, 60.0, 24, true, false],
	"sparks": [Color(1.0, 0.75, 0.35, 1.0), 0.035, 0.5, 5.0, -9.0, 60.0, 26, true, false],
	"ash": [Color(0.3, 0.28, 0.26, 0.8), 0.05, 3.0, 0.3, -0.35, 80.0, 20, false, true],
	"chips": [Color(0.92, 0.9, 0.86, 1.0), 0.04, 0.7, 3.5, -9.0, 50.0, 18, false, true],
	"mist": [Color(0.35, 0.05, 0.06, 0.7), 0.25, 0.8, 1.6, 0.4, 40.0, 16, false, true],
}

var boss: Node3D = null              # the HomageBoss (or the Foreman)
var cfg: Dictionary = {}
var extra_dread: float = 0.0         # a subclass's own addition this frame (0..1)
var dread_id: StringName = &"boss"
var _acc: float = 0.0
var _lights: Array = []              # [Light3D, base, is_flicker]
var _light_tw: Tween = null
var _flicker_t: float = 0.0
var _restoring: bool = false        # lights_restore is easing them back: no longer held dimmed
var _flicker_depth: float = 0.0
var _level_now: float = 1.0
var _tele_tw: Tween = null
var _flash_tw: Tween = null
var _last_report: Player = null
var _hit_ms: int = -100000           # the last hit burst / weak-point flash (throttled, see hit())
var _weak_ms: int = -100000

const HIT_GAP_MS: int = 70           # at most one hit burst + sound per boss in this time
const WEAK_GAP_MS: int = 140

static var _quad_cache: Dictionary = {}
static var _pm_cache: Dictionary = {}          # "kind@scale" -> ParticleProcessMaterial (shared, never edited after)
## Lights some kit holds dimmed: instance id -> [Light3D, true base energy, holders]. Two bosses dimming the same
## lamp share the one true base, and the lamp goes back to it when the last holder lets go.
static var _held: Dictionary = {}


## Builds the kit under `owner_boss` and returns it.
static func make(owner_boss: Node3D, dread_cfg: Dictionary, id: StringName = &"boss") -> BossFx:
	var fx: BossFx = BossFx.new()
	fx.name = "BossFx"
	fx.boss = owner_boss
	fx.dread_id = id
	fx.cfg = DEFAULTS.duplicate()
	for k: Variant in dread_cfg.keys():
		fx.cfg[k] = dread_cfg[k]
	owner_boss.add_child(fx)
	return fx


func _ready() -> void:
	set_physics_process(true)


func _exit_tree() -> void:
	release_dread()
	# the boss is leaving the tree (freed after a kill, a retreat or the round's cleanup): a tween of this node dies
	# with it, so the lights it still holds are eased back by the tree instead
	if not _lights.is_empty():
		var mine: Array = _take_lights()
		_ease_back(mine, _level_now, 1.5, get_tree())
		_level_now = 1.0
		_flicker_t = 0.0


## The id this kit reports under: the boss's id and this instance, so two bosses of one kind are two reporters.
func report_id() -> StringName:
	return StringName("%s#%d" % [dread_id, get_instance_id()])


## The boss's own "dread" block (a subclass whose data is not the base's table calls this after super._ready()).
func configure(dread_cfg: Dictionary) -> void:
	cfg = DEFAULTS.duplicate()
	for k: Variant in dread_cfg.keys():
		cfg[k] = dread_cfg[k]


func c(key: String) -> float:
	return float(cfg.get(key, DEFAULTS.get(key, 0.0)))


# ================================================================== dread

## The local human player (null headless / bots only).
static func local_human(tree: SceneTree) -> Player:
	for n: Node in tree.get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_local and not (n as Player).is_bot and not (n as Player).bot_driven:
			return n as Player
	return null


## Presence level for a player at `d` metres, with `facing` (the boss looks their way) and `los`.
static func dread_level(d: float, near: float, radius: float, facing: bool, los: bool, extra: float) -> float:
	var k: float = clampf(1.0 - (d - near) / maxf(radius - near, 0.1), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	k *= 0.7 + (0.3 if los else 0.0)
	if facing and los:
		k = minf(1.0, k * 1.15 + 0.05)
	return clampf(k + extra, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_acc += delta
	if _flicker_t > 0.0:
		_flicker_t -= delta
		var ending: bool = _flicker_t <= 0.0   # the last frame writes the plain level back, not a guttered value
		for e: Array in _lights:
			if not is_instance_valid(e[0]):    # a lamp freed mid-fight (a shield-cell, a shot-out bulb)
				continue
			var l: Light3D = e[0]
			var g: float = 1.0
			if not ending:
				g = 1.0 - _flicker_depth * maxf(0.0, FlickerLight.wobble(float(Time.get_ticks_msec()) * 0.013 + float(l.get_instance_id() % 97), 0.9, 0.3, 0.9) - 0.4)
			_write_light(e, _level_now * clampf(g, 0.0, 1.2))
	if _acc < 0.1:
		return
	_acc = 0.0
	if boss == null or not is_instance_valid(boss) or not boss.is_inside_tree():
		return
	var p: Player = local_human(get_tree())
	if p == null:
		return
	var alive: bool = not bool(boss.get("gone"))
	if alive and boss.has_method("is_active"):
		alive = bool(boss.call("is_active"))
	if not alive:
		release_dread()
		return
	var d: float = boss.global_position.distance_to(p.global_position)
	var to_p: Vector3 = p.global_position - boss.global_position
	to_p.y = 0.0
	var fwd: Vector3 = -boss.global_basis.z
	fwd.y = 0.0
	var facing: bool = to_p.length() > 0.01 and fwd.length() > 0.01 and rad_to_deg(fwd.normalized().angle_to(to_p.normalized())) < c("look_cone_deg")
	var los: bool = boss.has_los(p) if boss.has_method("has_los") else true
	var lvl: float = dread_level(d, c("near"), c("radius"), facing, los, extra_dread)
	extra_dread = 0.0
	var dfx: DreadFx = DreadFx.of(p)
	if dfx != null:
		_last_report = p
		if lvl > 0.0:
			dfx.report(report_id(), lvl, facing and los)
		else:
			dfx.release(report_id())


func release_dread() -> void:
	if _last_report != null and is_instance_valid(_last_report):
		var dfx: DreadFx = _last_report.get_node_or_null("DreadFx") as DreadFx
		if dfx != null:
			dfx.release(report_id())


# ================================================================== footfalls

## A footfall with weight at `at`: dust, the thud, a view shake on every player within `radius` (falling with
## distance, scaled by the Screen Shake setting through the player's own shake).
func stomp(at: Vector3, strength: float = -1.0, sound: String = "", radius: float = -1.0) -> void:
	if strength < 0.0:
		strength = c("step_shake")
	if radius < 0.0:
		radius = c("step_radius")
	if sound == "":
		sound = str(cfg.get("step_sound", ""))
	if strength <= 0.0 and sound == "":
		return
	Effects.dust_puff(at + Vector3.UP * 0.05, "ground", 8)
	if sound != "":
		AudioDirector.play_3d(sound, at, 0.0)
	shake_all(at, strength, radius)


## True when this boss's data opts into footfalls.
func has_footfalls() -> bool:
	return c("step_shake") > 0.0 or str(cfg.get("step_sound", "")) != ""


## A view shake on every local player within `radius` of `at`.
func shake_all(at: Vector3, strength: float, radius: float) -> void:
	if strength <= 0.0 or radius <= 0.0:
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_local and not (n as Player).is_bot:
			var p: Player = n as Player
			var d: float = p.global_position.distance_to(at)
			if d < radius:
				var k: float = strength * (1.0 - d / radius)
				p.set("_shake", maxf(float(p.get("_shake")), k))


# ================================================================== the arena's lights

## The map this boss stands in (a MapRoot ancestor, else the scene).
func map_root() -> Node:
	var n: Node = boss
	while n != null:
		if n is MapRoot:
			return n
		n = n.get_parent()
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


## Captures every light within `radius` of `center` (not the boss's own, not `no_dim`) and eases them to
## `base * level` over `seconds`. Call again with another level; lights_restore() brings them back.
func lights_dim(center: Vector3, radius: float, level: float, seconds: float = 1.5) -> void:
	if _lights.is_empty():
		var root: Node = map_root()
		if root == null:
			return
		for n: Node in root.find_children("*", "Light3D", true, false):
			var l: Light3D = n as Light3D
			if l == null or boss.is_ancestor_of(l) or l.has_meta("no_dim"):
				continue
			if l.global_position.distance_to(center) > radius:
				continue
			var id: int = l.get_instance_id()
			var held: Variant = _held.get(id)
			if held is Array and is_instance_valid((held as Array)[0]) and (held as Array)[0] == l:
				# another boss holds this lamp dimmed: its energy now is not its base
				(held as Array)[2] = int((held as Array)[2]) + 1
				_lights.append([l, float((held as Array)[1]), l is FlickerLight])
				continue
			if l.light_energy <= 0.0:
				continue
			var base: float = (l as FlickerLight).base_energy if l is FlickerLight else l.light_energy
			_held[id] = [l, base, 1]
			_lights.append([l, base, l is FlickerLight])
	_restoring = false
	_fade_lights(level, seconds)


static func _write_light(e: Array, k: float) -> void:
	if not is_instance_valid(e[0]):
		return
	var l: Light3D = e[0]
	if bool(e[2]):
		(l as FlickerLight).base_energy = float(e[1]) * k
	else:
		l.light_energy = float(e[1]) * k


func _fade_lights(level: float, seconds: float) -> void:
	if _light_tw != null and _light_tw.is_valid():
		_light_tw.kill()
	_light_tw = create_tween()
	_light_tw.tween_method(func(k: float) -> void:
		_level_now = k
		if _flicker_t > 0.0:
			return
		for e: Array in _lights:
			_write_light(e, k), _level_now, level, maxf(0.05, seconds))


## The captured lights gutter for `seconds` (depth 0..1: how far they dip).
func lights_flicker(seconds: float, depth: float = 0.7) -> void:
	_flicker_t = seconds
	_flicker_depth = clampf(depth, 0.0, 1.0)


## Every captured light back to its base over `seconds`, then forgotten. The lights stay captured while they ease,
## so a lights_dim() during the restore turns the fade round from where it is and keeps the true bases.
func lights_restore(seconds: float = 2.0) -> void:
	if _lights.is_empty():
		return
	_flicker_t = 0.0
	# a lamp another boss also holds is let go at once and left at that boss's level
	var mine: Array = []
	for e: Array in _lights:
		if not is_instance_valid(e[0]):
			continue
		var held: Variant = _held.get((e[0] as Light3D).get_instance_id())
		if held is Array and int((held as Array)[2]) > 1:
			(held as Array)[2] = int((held as Array)[2]) - 1
		else:
			mine.append(e)
	_lights = mine
	if _lights.is_empty():
		if _light_tw != null and _light_tw.is_valid():
			_light_tw.kill()
		_level_now = 1.0
		return
	_fade_lights(1.0, seconds)
	_restoring = true
	var tw: Tween = _light_tw
	tw.finished.connect(func() -> void:
		if _light_tw != tw:
			return   # a later dim or restore took over
		for e: Array in _take_lights():
			_write_light(e, 1.0)
		_level_now = 1.0)


## Lets go of every captured light and returns the ones nobody else holds (the caller writes those back).
func _take_lights() -> Array:
	var free_now: Array = []
	for e: Array in _lights:
		if not is_instance_valid(e[0]):
			continue
		var id: int = (e[0] as Light3D).get_instance_id()
		var held: Variant = _held.get(id)
		if held is Array and int((held as Array)[2]) > 1:
			(held as Array)[2] = int((held as Array)[2]) - 1   # the other boss still holds it: its level stands
			continue
		_held.erase(id)
		free_now.append(e)
	_lights = []
	_restoring = false
	for id: Variant in _held.keys():   # lamps freed while held
		if not is_instance_valid((_held[id] as Array)[0]):
			_held.erase(id)
	return free_now


## Eases `lights` from `from` to their bases on a tween of the tree (no node owns it: it outlives the boss).
static func _ease_back(lights: Array, from: float, seconds: float, tree: SceneTree) -> void:
	if lights.is_empty():
		return
	if tree == null or seconds <= 0.0:
		for e: Array in lights:
			_write_light(e, 1.0)
		return
	var tw: Tween = tree.create_tween()
	tw.tween_method(func(k: float) -> void:
		for e: Array in lights:
			_write_light(e, k), from, 1.0, seconds)


## How many lights the kit holds dimmed (tests / smokes).
func dimmed_count() -> int:
	return 0 if _restoring else _lights.size()


# ================================================================== emitters

static func _quad(kind: String) -> QuadMesh:
	if _quad_cache.has(kind):
		return _quad_cache[kind]
	var k: Array = KINDS.get(kind, KINDS["dust"])
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(float(k[1]), float(k[1]))
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = k[0]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if bool(k[7]):
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(k[0].r, k[0].g, k[0].b)
		m.emission_energy_multiplier = 2.0
	elif not bool(k[8]):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_quad_cache[kind] = q
	return q


## A continuous emitter of `kind` under `parent` at `pos` (local), scaled by `scale` (size and reach) and the VFX
## quality. Off until `.emitting = true`.
static func emitter(kind: String, parent: Node3D, pos: Vector3 = Vector3.ZERO, scale: float = 1.0) -> GPUParticles3D:
	if not KINDS.has(kind):
		push_warning("BossFx: unknown emitter kind '%s' (dust instead)" % kind)
		kind = "dust"
	var k: Array = KINDS[kind]
	var e: GPUParticles3D = GPUParticles3D.new()
	e.name = "Fx_" + kind
	e.position = pos
	e.amount = maxi(2, int(roundf(float(k[6]) * Effects.particles_k() * scale)))
	e.lifetime = float(k[2])
	e.emitting = false
	e.local_coords = false
	e.draw_pass_1 = _quad(kind)
	e.process_material = _process_mat(kind, scale)
	e.visibility_aabb = AABB(Vector3(-4, -4, -4) * scale, Vector3(8, 8, 8) * scale)
	parent.add_child(e)
	return e


## The process material of a kind at a scale: built once and shared (a hit burst is made many times a second).
static func _process_mat(kind: String, scale: float) -> ParticleProcessMaterial:
	var key: String = "%s@%.2f" % [kind, scale]
	if _pm_cache.has(key):
		return _pm_cache[key]
	var k: Array = KINDS[kind]
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = float(k[5])
	pm.initial_velocity_min = float(k[3]) * 0.6 * scale
	pm.initial_velocity_max = float(k[3]) * 1.3 * scale
	pm.gravity = Vector3(0, float(k[4]), 0)
	pm.scale_min = 0.6 * scale
	pm.scale_max = 1.4 * scale
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12 * scale
	pm.damping_min = 0.2
	pm.damping_max = 0.8
	pm.color = k[0]
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	_pm_cache[key] = pm
	return pm


## A one-shot burst of `kind` at `at` (world), freed when done.
static func burst(kind: String, at: Vector3, tree: SceneTree, amount_scale: float = 1.0, size_scale: float = 1.0) -> void:
	if tree == null or tree.current_scene == null:
		return
	var holder: Node3D = Node3D.new()
	holder.top_level = true
	tree.current_scene.add_child(holder)
	holder.global_position = at
	var e: GPUParticles3D = emitter(kind, holder, Vector3.ZERO, size_scale)
	e.amount = maxi(2, int(roundf(float(e.amount) * amount_scale)))
	e.one_shot = true
	e.explosiveness = 0.9
	e.emitting = true
	tree.create_timer(e.lifetime + 0.3).timeout.connect(holder.queue_free)


# ================================================================== hits, telegraphs, death

## The world position of a limb's hitbox on the boss (the first hitbox of that limb; the chest when unknown).
func limb_pos(limb: StringName) -> Vector3:
	var hbs: Variant = boss.get("_hitboxes")
	if hbs is Array:
		for hb: Variant in hbs:
			if hb is Node3D and str(hb.get("limb")) == String(limb):
				return (hb as Node3D).global_position
	return boss.global_position + Vector3.UP * 1.3


## The burst kind of a surface. Flesh is blood: only with the Gore setting on full (dust otherwise).
static func hit_kind(surface: String, blood: bool) -> String:
	var kind: String = {"porcelain": "chips", "iron": "sparks", "flesh": "mist", "glass": "motes", "cloth": "dust"}.get(surface, "mist")
	if kind == "mist" and not blood:
		kind = "dust"
	return kind


## A hit landed: a burst by the boss's surface at the limb, its sound; a weak point flashes violet; a heavy hit
## punches the dread layer. `mult` is the boss's limb multiplier for the hit (>= weak_mult = a weak point).
## Throttled per boss (HIT_GAP_MS / WEAK_GAP_MS): four automatics on one boss make one burst, not forty.
func hit(limb: StringName, amount: float, mult: float = 1.0, max_hp: float = 1.0) -> void:
	var now: int = Time.get_ticks_msec()
	var at: Vector3 = limb_pos(limb)
	var surface: String = str(cfg.get("surface", "flesh"))
	if now - _hit_ms >= HIT_GAP_MS:
		_hit_ms = now
		burst(hit_kind(surface, ZombieGore.blood_allowed()), at, get_tree(), 0.6, 0.8)
		AudioDirector.play_3d("boss_hit_" + surface, at, -6.0)
	if mult >= c("weak_mult") and now - _weak_ms >= WEAK_GAP_MS:
		_weak_ms = now
		burst("motes", at, get_tree(), 0.8, 1.0)
		AudioDirector.play_3d("boss_weakpoint_hit", at, -2.0)
		_weak_flash()
	if max_hp > 0.0 and amount / max_hp >= c("punch_fraction"):
		var p: Player = local_human(get_tree())
		if p != null:
			var dfx: DreadFx = DreadFx.of(p)
			if dfx != null:
				dfx.punch(clampf(amount / max_hp * 12.0, 0.3, 1.0))


## True while tele()'s shape (or the weak-point flash) runs: the boss's own telegraph glow leaves the light alone.
func tele_active() -> bool:
	return (_tele_tw != null and _tele_tw.is_valid() and _tele_tw.is_running()) or (_flash_tw != null and _flash_tw.is_valid() and _flash_tw.is_running())


## The weak point's violet flash on the telegraph light. Never over a telegraph (the tell matters more), and the
## light's colour is put back after.
func _weak_flash() -> void:
	var light: Variant = boss.get("_tele_light")
	if not (light is Light3D) or tele_active():
		return
	var l: Light3D = light as Light3D
	if l.light_energy > 0.05:
		return   # the boss's own telegraph glow is up
	var was: Color = l.light_color
	l.light_color = Color(0.72, 0.42, 1.0)
	_flash_tw = create_tween()
	_flash_tw.tween_property(l, "light_energy", 3.0, 0.08)
	_flash_tw.tween_property(l, "light_energy", 0.0, 0.17)
	_flash_tw.tween_callback(func() -> void:
		if is_instance_valid(l):
			l.light_color = was)


## The telegraph light's shape: a rise to `energy` over a third of `seconds`, a hold, a snap out; `rise_sound`
## plays boss_telegraph_rise with it. HomageBoss leaves the light to this shape while it runs (tele_active()).
func tele(color: Color, energy: float, seconds: float, rise_sound: bool = true) -> void:
	var light: Variant = boss.get("_tele_light")
	if not (light is Light3D):
		return
	var l: Light3D = light as Light3D
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	l.light_color = color
	if _tele_tw != null and _tele_tw.is_valid():
		_tele_tw.kill()
	_tele_tw = create_tween()
	_tele_tw.tween_property(l, "light_energy", energy, maxf(0.05, seconds * 0.35)).set_trans(Tween.TRANS_QUAD)
	_tele_tw.tween_interval(maxf(0.0, seconds * 0.55))
	_tele_tw.tween_property(l, "light_energy", 0.0, maxf(0.03, seconds * 0.1))
	if rise_sound and seconds >= 0.4:
		AudioDirector.play_3d("boss_telegraph_rise", boss.global_position + Vector3.UP * 1.4, -4.0, 0.03)


## The death: motes and a light that fades, the toll, the dread let go.
func death_burst(at: Vector3, color: Color = Color(0.72, 0.42, 1.0)) -> void:
	burst("motes", at + Vector3.UP * 1.0, get_tree(), 2.5, 1.6)
	burst("ash", at + Vector3.UP * 1.2, get_tree(), 1.5, 1.4)
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = color
	l.omni_range = 9.0
	l.light_energy = 4.0
	l.shadow_enabled = false
	l.top_level = true
	add_child(l)
	l.global_position = at + Vector3.UP * 1.2
	var tw: Tween = create_tween()
	tw.tween_property(l, "light_energy", 0.0, 2.5).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(l.queue_free)
	AudioDirector.play_3d("boss_death_toll", at, 0.0, 0.02)
	release_dread()


# ================================================================== model helpers' nodes (HomageBoss.strips / eye_glow)

## Hanging strips that sway with the body's motion: each a thin box hinged at its top, tilted against the
## attachment's velocity and settling on a spring; a little wind of its own so they never hang dead.
class SwayStrips extends Node3D:
	var _strips: Array[MeshInstance3D] = []
	var _ang: Array[Vector2] = []     # tilt (x about the side axis, z about the forward axis)
	var _vel: Array[Vector2] = []
	var _phase: Array[float] = []
	var _last: Vector3 = Vector3.INF
	var _t: float = 0.0

	func build(count: int, length: float, width: float, m: Material, spread: float, seed_v: int) -> void:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_v
		for i: int in count:
			var piv: Node3D = Node3D.new()
			piv.position = Vector3(rng.randf_range(-spread, spread) * 0.5, 0.0, rng.randf_range(-spread, spread) * 0.25)
			add_child(piv)
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			var len_: float = length * rng.randf_range(0.7, 1.2)
			bm.size = Vector3(width * rng.randf_range(0.7, 1.3), len_, 0.006)
			bm.material = m
			mi.mesh = bm
			mi.position = Vector3(0, -len_ * 0.5, 0)
			mi.rotation.y = rng.randf_range(-0.6, 0.6)
			piv.add_child(mi)
			_strips.append(mi)
			_ang.append(Vector2.ZERO)
			_vel.append(Vector2.ZERO)
			_phase.append(rng.randf_range(0.0, TAU))
		set_process(true)

	func _process(delta: float) -> void:
		if _strips.is_empty():
			return
		_t += delta
		var gp: Vector3 = global_position
		var v: Vector3 = Vector3.ZERO
		if _last.is_finite() and delta > 0.0:
			v = (gp - _last) / delta
		_last = gp
		var lv: Vector3 = global_basis.inverse() * v   # the body's motion in the strips' frame
		for i: int in _strips.size():
			var piv: Node3D = _strips[i].get_parent() as Node3D
			var target: Vector2 = Vector2(clampf(-lv.z * 0.25, -1.0, 1.0), clampf(lv.x * 0.25, -1.0, 1.0))
			target += Vector2(sin(_t * 1.7 + _phase[i]), cos(_t * 1.3 + _phase[i] * 0.7)) * 0.06
			var a: Vector2 = _ang[i]
			var w: Vector2 = _vel[i]
			w += (-(a - target) * 28.0 - w * 2.0 * 0.45 * sqrt(28.0)) * delta
			a += w * delta
			_ang[i] = a
			_vel[i] = w
			piv.rotation = Vector3(a.x, 0.0, a.y)


## Two emissive beads at the eye sockets and a weak light between them; blinks (both beads off a tenth of a
## second) every `blink_s` seconds with a little jitter; 0 = never (Alix).
class EyeGlow extends Node3D:
	var lit: bool = true:
		set(v):
			lit = v
			_apply()
	var color: Color = Color(0.72, 0.42, 1.0):
		set(v):
			color = v
			_apply()
	var energy: float = 1.2
	var blink_s: float = 0.0
	var _beads: Array[MeshInstance3D] = []
	var _light: OmniLight3D = null
	var _mat: StandardMaterial3D = null
	var _blink_t: float = 0.0
	var _shut: float = 0.0

	func build(c: Color, e: float, blink: float, sockets: Array) -> void:
		color = c
		energy = e
		blink_s = blink
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.012
		sp.height = 0.024
		sp.radial_segments = 8
		sp.rings = 4
		sp.material = _mat
		for s: Variant in sockets:
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = sp
			mi.position = s as Vector3
			add_child(mi)
			_beads.append(mi)
		_light = OmniLight3D.new()
		_light.omni_range = 1.6
		_light.omni_attenuation = 1.6
		_light.shadow_enabled = false
		_light.position = Vector3(0, 0.09, -0.16)
		add_child(_light)
		_blink_t = blink_s
		_apply()
		set_process(blink_s > 0.0)

	func _apply() -> void:
		if _mat == null:
			return
		var on: bool = lit and _shut <= 0.0
		_mat.albedo_color = color if on else Color(0.05, 0.05, 0.06)
		_mat.emission_enabled = on
		_mat.emission = color
		_mat.emission_energy_multiplier = energy * 1.6
		if _light != null:
			_light.light_color = color
			_light.light_energy = energy * 0.35 if on else 0.0

	func _process(delta: float) -> void:
		if _shut > 0.0:
			_shut -= delta
			if _shut <= 0.0:
				_apply()
			return
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_t = blink_s * randf_range(0.7, 1.4)
			_shut = 0.1
			_apply()
