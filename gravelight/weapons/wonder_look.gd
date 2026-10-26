class_name WonderLook
extends RefCounted
## The wonder weapons' own look and moving parts (UPDATE_05 section 2, DECISIONS T-090). The models are ours
## (tools_src/blender/wonder/<id>.py -> assets/ours/wonder/<id>/model.glb) and WeaponGLB builds them like any GLB gun
## (models.json source "ours" + a model_fit.json entry); this class adds what a conventional gun doesn't have:
##   finish(root, base, upgraded, cfg)   called by WeaponGLB.build after the shared weapon shader: the GLB surfaces
##       whose material is named glass / fluid / glow / coil_glow / emitter / arc / runes / halo / orb get our shaders
##       (assets/ours/wonder/shaders/), the Crucible-only parts (model_fit wonder.crucible_parts: the Ashlight Corona's
##       Halo, Mitternacht's Runes, Kugelblitz's Orb) show only on the upgraded weapon, and every baked body surface
##       goes into wonder_body.gdshader (the painted maps as baked: the shared gun shader would make the painted steel,
##       porcelain and rope read as gun metal), with the weapon's own Crucible look when upgraded (model_fit
##       wonder.upgraded.shader: Mitternacht's midnight-blue patina; veins are available, no weapon uses them) instead of the shared
##       Nachtglas veins. Same mesh, a material and toggled parts (section 2.6).
##   tick(holder, model, delta)          called by WeaponHolder._animate every frame for a model with meta "wonder":
##       drives the parts from the holder's existing state, never the other way round (no timing lives here):
##         ashlight     the capsule's fluid level = the magazine fraction (smoothed), its surface sloshes on a spring
##                      from the gun's motion, flashes on a shot; the gauge Needle reads the charge; the coil core
##                      and the emitter flare on a shot; the Corona's Halo turns; a fresh capsule in the reload hand
##                      is full;
##         totenglocke  (the Bell vibration and the Crank wind are Totenglocke.pose_parts) the striker Hammer cocks
##                      back over the wind and snaps onto the bell on the toll, the Clapper swings with the ring, the
##                      ratchet Pawl clicks over the crank's teeth, Mitternacht's Runes flare with the ring;
##         elmsfeuer    the discharge Arc flickers (a burst on a shot), the ammeter Dial reads the charge and climbs
##                      with the crank on a reload, the coil core crawls, Kugelblitz's Orb swirls;
##   reload_crank(holder, p, lh_home)    the Sankt-Elmsfeuer's "crank" reload (the magneto: the support hand winds the
##       Crank five turns between 15 % and 85 % of the reload; the reload time is still the data's);
##   gramophone_visual()                 the thrown Siren Gramophone's model (gramophone.gd spins its Record and turns
##       its Crank while it plays).

const SHADER_DIR: String = "res://assets/ours/wonder/shaders/"
const GLOW_MODES: Dictionary = {"glow": 0, "emitter": 0, "coil_glow": 1, "arc": 2, "runes": 3, "orb": 4, "halo": 5}
const GRAMOPHONE_GLB: String = "res://assets/ours/wonder/gramophone/model.glb"

static var _shaders: Dictionary = {}
static var _mats: Dictionary = {}          # key -> Material


static func _shader(n: String) -> Shader:
	if not _shaders.has(n):
		_shaders[n] = load(SHADER_DIR + n + ".gdshader") as Shader
	return _shaders[n]


static func _col(a: Variant, fallback: Color) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if (a as Array).size() > 3 else 1.0)
	return fallback


## The name a GLB surface's material had (the special materials are matched by it).
static func surface_name(mi: MeshInstance3D, si: int) -> String:
	var m: Material = mi.mesh.surface_get_material(si)
	return String(m.resource_name) if m != null else ""


## Wraps the special surfaces, toggles the Crucible parts, applies the weapon's own upgraded look. See the class doc.
static func finish(root: Node3D, base: String, upgraded: bool, cfg: Dictionary) -> void:
	root.set_meta("wonder", base)
	var up: Dictionary = cfg.get("upgraded", {}) if upgraded else {}
	var mats: Dictionary = cfg.get("materials", {})
	for part: String in cfg.get("crucible_parts", []):
		var n: Node3D = root.get_node_or_null(part) as Node3D
		if n != null:
			n.visible = upgraded
	# points the drivers need on a part (model_fit wonder.part_metas {Part: {meta: [x,y,z]}}: the crank knob)
	var pm: Dictionary = cfg.get("part_metas", {})
	for part2: String in pm.keys():
		var pn: Node3D = root.get_node_or_null(part2) as Node3D
		if pn != null:
			for k: String in (pm[part2] as Dictionary).keys():
				pn.set_meta(k, WeaponGLB._v3(pm[part2][k]))
	var up_shader: Dictionary = up.get("shader", {}) if upgraded else {}
	for c: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not mi.has_meta("glb"):
			continue
		for si: int in mi.mesh.get_surface_count():
			var nm: String = surface_name(mi, si)
			if nm == "glass":
				mi.set_surface_override_material(si, _glass(base, mats.get("glass", {})))
			elif nm == "fluid":
				mi.set_surface_override_material(si, _fluid(base, mi, si, mats.get("fluid", {}), up))
			elif GLOW_MODES.has(nm):
				mi.set_surface_override_material(si, _glow(base, nm, mi, si, mats.get(nm, {}), up))
			else:
				var src: StandardMaterial3D = mi.mesh.surface_get_material(si) as StandardMaterial3D
				if src != null:
					mi.set_surface_override_material(si, _body(base, src, up_shader))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The baked body in wonder_body.gdshader (its maps as baked; the shared gun shader would read the painted steel, the
## porcelain and the rope as gun metal), with this weapon's own Crucible parameters when upgraded (model_fit
## wonder.upgraded.shader: patina [r,g,b,a], patina_rough, veins). Cached per source material + look.
static func _body(base: String, src: StandardMaterial3D, params: Dictionary) -> ShaderMaterial:
	var key: String = "body|%s|%d|%s" % [base, src.get_instance_id(), JSON.stringify(params)]
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("wonder_body")
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	if src.normal_texture != null:
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("normal_depth", src.normal_scale)
	var orm: Texture2D = src.metallic_texture if src.metallic_texture != null else (src.roughness_texture if src.roughness_texture != null else src.ao_texture)
	if orm != null:
		m.set_shader_parameter("orm_tex", orm)
	m.set_shader_parameter("frost", maxf(0.0, WeaponShader.frost))
	for k: String in params.keys():
		var v: Variant = params[k]
		if v is Array:
			m.set_shader_parameter(k, _col(v, Color.WHITE))
		else:
			m.set_shader_parameter(k, float(v))
	_mats[key] = m
	return m


## Keeps every wonder material's frost on the map's value (WeaponShader owns it; a map change moves it).
static func _sync_frost() -> void:
	var f: float = maxf(0.0, WeaponShader.frost)
	if is_equal_approx(f, _frost):
		return
	_frost = f
	for m: Material in _mats.values():
		(m as ShaderMaterial).set_shader_parameter("frost", f)


static var _frost: float = -1.0


static func _glass(base: String, d: Dictionary) -> ShaderMaterial:
	var key: String = "glass|" + base
	if _mats.has(key):
		var g: ShaderMaterial = _mats[key]
		g.set_shader_parameter("frost", maxf(0.0, WeaponShader.frost))
		return g
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("wonder_glass")
	m.set_shader_parameter("tint", _col(d.get("tint"), Color(0.82, 0.86, 0.84)))
	m.set_shader_parameter("refraction", float(d.get("refraction", 0.012)))
	m.set_shader_parameter("frost", maxf(0.0, WeaponShader.frost))
	m.render_priority = 1
	_mats[key] = m
	return m


static func _surface_aabb(mi: MeshInstance3D, si: int) -> AABB:
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
	var bb: AABB = AABB(v[0], Vector3.ZERO) if v.size() > 0 else AABB()
	for p: Vector3 in v:
		bb = bb.expand(p)
	return bb


static func _fluid(base: String, mi: MeshInstance3D, si: int, d: Dictionary, up: Dictionary) -> ShaderMaterial:
	var key: String = "fluid|%s|%s" % [base, not up.is_empty()]
	if _mats.has(key):
		return _mats[key]
	var bb: AABB = _surface_aabb(mi, si)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("wonder_fluid")
	m.set_shader_parameter("center", bb.get_center())
	m.set_shader_parameter("radius", minf(bb.size.x, bb.size.y) * 0.5)
	m.set_shader_parameter("glow", _col(up.get("fluid_color", d.get("color")), Color(0.55, 0.2, 1.0)))
	_mats[key] = m
	return m


static func _glow(base: String, nm: String, mi: MeshInstance3D, si: int, d: Dictionary, up: Dictionary) -> ShaderMaterial:
	var key: String = "glow|%s|%s|%s" % [base, nm, not up.is_empty()]
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("wonder_glow")
	m.set_shader_parameter("mode", int(GLOW_MODES[nm]))
	var cols: Dictionary = up.get("colors", {})
	m.set_shader_parameter("color", _col(cols.get(nm, d.get("color")), Color(0.55, 0.2, 1.0)))
	m.set_shader_parameter("hot", _col(d.get("hot"), Color(0.95, 0.85, 1.0)))
	m.set_shader_parameter("strength", float(d.get("strength", 2.5)) * float((up.get("strength", {}) as Dictionary).get(nm, 1.0)))
	m.set_shader_parameter("center", _surface_aabb(mi, si).get_center())
	_mats[key] = m
	return m


## Drops the material cache (tests, shader edits).
static func reset() -> void:
	_mats.clear()
	_shaders.clear()


# ================================================================== part drivers

## Per-model driver state (kept on the model: a rebuilt gun starts fresh).
static func _state(model: Node3D) -> Dictionary:
	if not model.has_meta("wonder_state"):
		model.set_meta("wonder_state", {"level": -1.0, "n": Vector3.UP, "nv": Vector3.ZERO, "prev_basis": Basis(), "prev_pos": Vector3.ZERO,
			"vel": Vector3.ZERO, "first": true, "flash": 0.0, "mag": -1, "strike": 0.0, "vibe_prev": 0.0, "cock": 0.0, "clock": 0.0,
			"dial": -1.0, "pawl": 0.0})
	return model.get_meta("wonder_state")


## Called by WeaponHolder._animate (after the part reset and the bell pose, before the reload animation).
static func tick(holder: WeaponHolder, model: Node3D, delta: float) -> void:
	var w: WeaponInstance = holder.current()
	if w == null or model == null:
		return
	_sync_frost()
	var s: Dictionary = _state(model)
	s["clock"] = float(s["clock"]) + delta
	var frac: float = clampf(float(w.mag) / maxf(1.0, float(w.mag_size())), 0.0, 1.0)
	# a shot: the holder's own flash timer, or the magazine dropping (the bell's tolls)
	var shot: bool = float(holder._flash_t) > 0.0 and float(s["flash"]) < 0.05
	if int(s["mag"]) >= 0 and w.mag < int(s["mag"]):
		shot = true
	s["mag"] = w.mag
	s["flash"] = 1.0 if shot else maxf(0.0, float(s["flash"]) - delta * 5.0)
	var energy: float = float((WeaponGLB.fit_for(w.base_id()).get("wonder", {}) as Dictionary).get("upgraded", {}).get("energy", 1.6)) if w.upgraded else 1.0
	match String(model.get_meta("wonder", "")):
		"ashlight":
			_tick_ashlight(holder, model, w, s, frac, energy, delta)
		"totenglocke":
			_tick_bell(holder, model, w, s, energy, delta)
		"elmsfeuer":
			_tick_elmsfeuer(holder, model, w, s, frac, energy, delta)
		"lodestone":
			_tick_lodestone(holder, model, w, s, frac, energy, delta)


## The fluid surface's up in mesh space: gravity and the gun's acceleration (the viewmodel's own motion: turns,
## the raise, sprinting, recoil) through a damped spring, so the liquid lags and sloshes. Returns the spring speed.
static func _slosh(model: Node3D, s: Dictionary, delta: float) -> float:
	var gb: Basis = model.global_basis.orthonormalized()
	var pos: Vector3 = model.global_position
	if bool(s["first"]) or delta <= 0.0:
		s["first"] = false
		s["prev_pos"] = pos
		s["n"] = (gb.inverse() * Vector3.UP).normalized()
		return 0.0
	var vel: Vector3 = (pos - (s["prev_pos"] as Vector3)) / delta
	var acc: Vector3 = (vel - (s["vel"] as Vector3)) / delta
	s["prev_pos"] = pos
	s["vel"] = vel
	# the liquid's "up" is against gravity plus the acceleration it resists (clamped: a teleport is not a slosh)
	var g: Vector3 = Vector3.UP * 9.8 + acc.limit_length(30.0) * 0.6
	var target: Vector3 = (gb.inverse() * g).normalized()
	var n: Vector3 = s["n"]
	var nv: Vector3 = s["nv"]
	nv += (target - n) * 140.0 * delta
	nv *= exp(-7.0 * delta)
	n = (n + nv * delta).normalized()
	s["n"] = n
	s["nv"] = nv
	return nv.length()


static func _tick_ashlight(holder: WeaponHolder, model: Node3D, w: WeaponInstance, s: Dictionary, frac: float, energy: float, delta: float) -> void:
	var lvl: float = float(s["level"])
	lvl = frac if lvl < 0.0 else move_toward(lvl, frac, delta * 1.5)
	s["level"] = lvl
	var speed: float = _slosh(model, s, delta)
	var flash: float = float(s["flash"])
	var mag: Node3D = model.get_node_or_null("Mag") as Node3D
	if mag != null:
		for c: Node in mag.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c as MeshInstance3D
			mi.set_instance_shader_parameter("level", lvl)
			mi.set_instance_shader_parameter("surf_n", s["n"])
			mi.set_instance_shader_parameter("wobble", clampf(speed * 0.6, 0.0, 1.0))
			mi.set_instance_shader_parameter("flash", flash)
			mi.set_instance_shader_parameter("energy", energy)
	# the fresh capsule in the support hand (the holder's reload prop is a copy of the Mag) is full
	var prop: Node3D = holder._prop
	if prop != null and is_instance_valid(prop) and holder._prop_kind == "capsule":
		for c2: Node in prop.find_children("*", "MeshInstance3D", true, false):
			var pm: MeshInstance3D = c2 as MeshInstance3D
			pm.set_instance_shader_parameter("level", 1.0)
			pm.set_instance_shader_parameter("surf_n", s["n"])
			pm.set_instance_shader_parameter("energy", energy)
	var body: MeshInstance3D = model.get_node_or_null("Body/Mesh") as MeshInstance3D
	if body == null:
		body = _first_mesh(model.get_node_or_null("Body"))
	if body != null:
		body.set_instance_shader_parameter("energy", energy * (0.75 + 0.5 * lvl))
		body.set_instance_shader_parameter("flash", flash)
	var needle: Node3D = model.get_node_or_null("Needle") as Node3D
	if needle != null:
		var jitter: float = sin(float(s["clock"]) * 37.0) * 0.02 * (0.3 + flash)
		needle.rotation.x = deg_to_rad(lerpf(110.0, -110.0, lvl)) + jitter
	var halo: Node3D = model.get_node_or_null("Halo") as Node3D
	if halo != null and halo.visible:
		halo.rotation.z = fmod(halo.rotation.z + delta * (0.9 + flash * 6.0), TAU)
		var hm: MeshInstance3D = _first_mesh(halo)
		if hm != null:
			hm.set_instance_shader_parameter("energy", energy)
			hm.set_instance_shader_parameter("flash", flash)


static func _tick_bell(holder: WeaponHolder, model: Node3D, w: WeaponInstance, s: Dictionary, energy: float, delta: float) -> void:
	var bell: Totenglocke = holder._bell
	var hold: float = 0.0
	var ready: bool = false
	var vibe: float = 0.0
	var crank_a: float = 0.0
	if bell != null:
		var b: Dictionary = w.data.get("bell", {})
		hold = bell.wind_progress(b)
		ready = bell._great_ready
		vibe = bell._vibe_amp * pow(bell._vibe_t / maxf(0.01, bell._vibe_total), 1.5)
		crank_a = bell._crank_a
	# a new ring: the vibration jumped up -> the striker hammer snaps onto the bell
	if vibe > float(s["vibe_prev"]) + 0.15:
		s["strike"] = 1.0
	s["vibe_prev"] = vibe
	s["strike"] = maxf(0.0, float(s["strike"]) - delta * 4.0)
	var cock: float = float(s["cock"])
	var want: float = clampf(hold * 1.15, 0.0, 1.0) if bell != null and bell.is_winding() else 0.0
	cock = move_toward(cock, want, delta * (3.0 if want > cock else 14.0))
	s["cock"] = cock
	var hammer: Node3D = model.get_node_or_null("Hammer") as Node3D
	if hammer != null:
		var strike: float = float(s["strike"])
		var hit: float = sin(clampf(strike, 0.0, 1.0) * PI) if strike > 0.0 else 0.0
		# the arm lies along the left side and pivots about y at the crossbar: cocked swings the head out, away from
		# the bell; the strike swings it back in onto the sound bow
		var ang: float = deg_to_rad(28.0) * cock - deg_to_rad(3.0) * hit
		if ready:
			ang += sin(float(s["clock"]) * 70.0) * 0.012
		hammer.rotation = Vector3(0.0, ang, 0.0)
	var clapper: Node3D = model.get_node_or_null("Clapper") as Node3D
	if clapper != null:
		var t: float = float(s["clock"])
		clapper.rotation = Vector3(sin(t * 9.0) * 0.35 * minf(vibe, 1.2), 0.0, sin(t * 7.3 + 0.7) * 0.25 * minf(vibe, 1.2))
	var pawl: Node3D = model.get_node_or_null("Pawl") as Node3D
	var crank: Node3D = model.get_node_or_null("Crank") as Node3D
	if pawl != null and crank != null:
		# twelve teeth on the ratchet: the pawl rides up each tooth and drops
		var a: float = absf(crank.rotation.x)
		var tooth: float = fmod(a * 12.0 / TAU, 1.0)
		pawl.rotation = Vector3(deg_to_rad(14.0) * tooth, 0.0, 0.0)
	var runes: Node3D = model.get_node_or_null("Runes") as Node3D
	if runes != null and runes.visible:
		var rm: MeshInstance3D = _first_mesh(runes)
		if rm != null:
			rm.set_instance_shader_parameter("energy", energy * (1.0 + 10.0 * minf(vibe, 1.5) + 3.0 * hold))
			rm.set_instance_shader_parameter("flash", clampf(vibe, 0.0, 1.0))


static func _tick_elmsfeuer(holder: WeaponHolder, model: Node3D, w: WeaponInstance, s: Dictionary, frac: float, energy: float, delta: float) -> void:
	var flash: float = float(s["flash"])
	var charge: float = frac
	if holder.is_reloading():
		var p: float = 1.0 - holder._reload_t / maxf(0.05, holder._reload_total)
		charge = lerpf(frac, 1.0, smoothstep(0.15, 0.85, p))
	var dial_v: float = float(s["dial"])
	dial_v = charge if dial_v < 0.0 else move_toward(dial_v, charge, delta * 2.5)
	s["dial"] = dial_v
	var dial: Node3D = model.get_node_or_null("Dial") as Node3D
	if dial != null:
		var kick: float = flash * 0.35
		dial.rotation.x = deg_to_rad(lerpf(100.0, -100.0, clampf(dial_v - kick, 0.0, 1.0))) + sin(float(s["clock"]) * 41.0) * 0.012
	var arc: Node3D = model.get_node_or_null("Arc") as Node3D
	if arc != null:
		# the gap only arcs while there is charge; it stutters, and a shot throws it wide
		var on: bool = w.mag > 0 and (randf() > 0.22 or flash > 0.0)
		arc.visible = on
		if on:
			var am: MeshInstance3D = _first_mesh(arc)
			arc.rotation.z = randf() * TAU
			arc.scale = Vector3.ONE * (1.0 + flash * 0.6 + randf() * 0.15)
			if am != null:
				am.set_instance_shader_parameter("energy", energy * (0.6 + 0.6 * frac))
				am.set_instance_shader_parameter("flash", flash)
	var body: MeshInstance3D = _first_mesh(model.get_node_or_null("Body"))
	if body != null:
		body.set_instance_shader_parameter("energy", energy * (0.4 + 0.8 * dial_v))
		body.set_instance_shader_parameter("flash", flash)
	var orb: Node3D = model.get_node_or_null("Orb") as Node3D
	if orb != null and orb.visible:
		orb.rotation = Vector3(float(s["clock"]) * 2.1, float(s["clock"]) * 3.3, 0.0)
		orb.scale = Vector3.ONE * (0.9 + 0.12 * sin(float(s["clock"]) * 11.0) + flash * 0.5)
		var om: MeshInstance3D = _first_mesh(orb)
		if om != null:
			om.set_instance_shader_parameter("energy", energy)
			om.set_instance_shader_parameter("flash", flash)


## The Lodestone (T-105): the lens's glow follows the charges left and the fling wind-up; the holder's
## Lodestone.pose_parts already spins the Sphere, opens the Cradle and lights the Coil, so this only drives the
## shader parameters (energy, flash) on the glass and the coil's emissive mesh.
static func _tick_lodestone(holder: WeaponHolder, model: Node3D, _w: WeaponInstance, s: Dictionary, frac: float, energy: float, _delta: float) -> void:
	var lode: Lodestone = holder._lode
	var charge: float = lode.charge() if lode != null else 0.0
	var holding: float = lode.ring_open() if lode != null else 0.0
	var sphere: Node3D = model.get_node_or_null("Sphere") as Node3D
	if sphere != null:
		var sm: MeshInstance3D = _first_mesh(sphere)
		if sm != null:
			sm.set_instance_shader_parameter("energy", energy * (0.4 + 1.2 * frac + 2.0 * holding + 3.0 * charge))
			sm.set_instance_shader_parameter("flash", clampf(float(s["flash"]) + charge, 0.0, 1.0))
	var coil: Node3D = model.get_node_or_null("Coil") as Node3D
	if coil != null:
		var cm: MeshInstance3D = _first_mesh(coil)
		if cm != null:
			cm.set_instance_shader_parameter("energy", energy * (0.2 + 4.0 * charge))


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n == null:
		return null
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		return c as MeshInstance3D
	return null


# ================================================================== the Sankt-Elmsfeuer's crank reload

## Left-hand target (gun space) during the "crank" reload: reach the magneto's knob, wind it five turns, let go.
## The crank turns about its own x axis; its knob sits at the Crank node's meta "handle" (crank space).
static func reload_crank(holder: WeaponHolder, p: float, lh_home: Vector3) -> Variant:
	var crank: Node3D = holder._part("Crank")
	if crank == null:
		return null
	var k: float = clampf((p - 0.15) / 0.7, 0.0, 1.0)
	var ang: float = TAU * 5.0 * (k * k * (3.0 - 2.0 * k))
	crank.rotation.x = -ang
	var handle_local: Vector3 = crank.get_meta("handle", Vector3(0.045, 0.045, 0.0))
	var handle: Vector3 = crank.position + Basis(Vector3.RIGHT, -ang) * handle_local
	if p < 0.15:
		return lh_home.lerp(handle, smoothstep(0.0, 1.0, p / 0.15))
	if p > 0.85:
		return handle.lerp(lh_home, smoothstep(0.0, 1.0, (p - 0.85) / 0.15))
	return handle


# ================================================================== the Siren Gramophone (a world object)

static var _gramo_scene: PackedScene = null
## Where each moving part of the gramophone turns (its own frame: tools_src/blender/wonder/gramophone.py's markers).
const GRAMOPHONE_PIVOTS: Dictionary = {"Record": Vector3(0.0, 0.0595, 0.012), "Crank": Vector3(0.145, -0.03, 0.05),
	"Tonearm": Vector3(0.105, 0.045, 0.105)}


## The gramophone model (nodes Body, Record, Crank, Tonearm, Lid), or null before the asset is imported. The moving
## parts are re-hung on pivot nodes (named as the part) at their axles, so turning a part turns it in place.
static func gramophone_visual() -> Node3D:
	if _gramo_scene == null:
		if not ResourceLoader.exists(GRAMOPHONE_GLB):
			return null
		_gramo_scene = load(GRAMOPHONE_GLB) as PackedScene
	if _gramo_scene == null:
		return null
	var n: Node3D = _gramo_scene.instantiate() as Node3D
	n.name = "Visual"
	for part: String in GRAMOPHONE_PIVOTS.keys():
		var src: Node3D = n.find_child(part, true, false) as Node3D
		if src == null:
			continue
		var piv: Node3D = Node3D.new()
		var at: Vector3 = GRAMOPHONE_PIVOTS[part]
		var parent: Node = src.get_parent()
		src.owner = null
		for d: Node in src.find_children("*", "", true, false):
			d.owner = null
		parent.remove_child(src)
		src.name = part + "Mesh"
		piv.name = part
		piv.position = at
		parent.add_child(piv)
		piv.add_child(src)
		src.position -= at
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n
