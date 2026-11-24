class_name WebProfile
extends RefCounted
## UPDATE 09 section 2c/2d (DECISIONS T-139, contract C4): the browser / Compatibility-renderer profile of a scene.
## MapRoot._ready and the menu's 3D backdrop call `WebProfile.apply(root)` when GLSettings.is_compat():
##   - no SDFGI / SSIL / SSR / volumetric fog: a map that wanted volumetric fog gets depth fog of the same colour
##     (the Compatibility renderer has none of those; FogVolumes are hidden: they would do nothing),
##   - directional shadows reach SHADOW_DIST_M (40 m) at most in 2 cascades (not 4), MSAA off,
##   - at most MAX_SHADOWED_PER_ZONE (4) shadowed omni / spot lights per zone (ZoneVolume; lights outside every zone
##     count as one more zone): the ones nearest the players' spawn keep their shadow, the rest light without one;
##     the omni lights that keep one use cube shadows: the Compatibility renderer has no dual-paraboloid mode (T-139
##     set it to save shadow renders; Godot 4.7 rejects it there and the lamp cast none, T-266), and ShadowBudget
##     prices a cube at 6 views, so fewer omnis keep a shadow on this renderer,
##   - zombie animation LOD distances halved (anim.json lod: Zombie.anim_lod_scale),
##   - particle amounts halved (GPUParticles3D.amount_ratio; Effects' bursts through Effects.particles_k; the
##     snowfall's layers through Snowfall.density_scale).
## Texture sizes are capped at export time (addons/gl_web_export). Idempotent: a second apply changes nothing more.
## Nothing here touches gameplay: no collider, hitbox, navmesh, timer or prompt.

const SHADOW_DIST_M: float = 40.0
const MAX_SHADOWED_PER_ZONE: int = 4
const PARTICLE_RATIO: float = 0.5
const ANIM_LOD_SCALE: float = 0.5
const DONE_META: StringName = &"gl_web_profile"


## Applies the profile under `root` (and to the viewport's own environment). Returns what it changed, for logs and
## tests: {"env": n, "fog": "depth"/"kept"/"", "dir_lights": n, "shadows_off": n, "shadowed_kept": n,
## "particles": n, "fog_volumes": n}.
static func apply(root: Node) -> Dictionary:
	var out: Dictionary = {"env": 0, "fog": "", "dir_lights": 0, "shadows_off": 0, "shadowed_kept": 0, "particles": 0, "fog_volumes": 0}
	if root == null:
		return out
	Zombie.anim_lod_scale = ANIM_LOD_SCALE
	Snowfall.density_scale = PARTICLE_RATIO
	var envs: Array[Environment] = []
	for n: Node in root.find_children("*", "WorldEnvironment", true, false):
		var we: WorldEnvironment = n as WorldEnvironment
		if we.environment != null:
			envs.append(we.environment)
	if root is WorldEnvironment and (root as WorldEnvironment).environment != null:
		envs.append((root as WorldEnvironment).environment)
	for env: Environment in envs:
		var r: String = environment(env)
		out["env"] = int(out["env"]) + 1
		if r != "":
			out["fog"] = r
	if root.is_inside_tree():
		var vp: Viewport = root.get_viewport()
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_DISABLED
	var spawn: Vector3 = _spawn_point(root)
	var by_zone: Dictionary = {}   # zone id -> [lights]
	for n: Node in root.find_children("*", "", true, false):
		if n is DirectionalLight3D:
			var dl: DirectionalLight3D = n as DirectionalLight3D
			if dl.directional_shadow_max_distance > SHADOW_DIST_M:
				dl.directional_shadow_max_distance = SHADOW_DIST_M
			if dl.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
				dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			out["dir_lights"] = int(out["dir_lights"]) + 1
		elif n is OmniLight3D or n is SpotLight3D:
			var l: Light3D = n as Light3D
			if l.shadow_enabled and not _on_actor(l):
				var z: StringName = _zone_of(root, l.global_position if l.is_inside_tree() else l.position)
				if not by_zone.has(z):
					by_zone[z] = []
				(by_zone[z] as Array).append(l)
		elif n is GPUParticles3D:
			var p: GPUParticles3D = n as GPUParticles3D
			if not p.has_meta(DONE_META):
				p.set_meta(DONE_META, p.amount_ratio)
				p.amount_ratio = float(p.get_meta(DONE_META)) * PARTICLE_RATIO
				out["particles"] = int(out["particles"]) + 1
		elif n is FogVolume:
			if (n as FogVolume).visible:
				(n as FogVolume).visible = false
				out["fog_volumes"] = int(out["fog_volumes"]) + 1
	for z: Variant in by_zone:
		var r2: Vector2i = cap_shadows(by_zone[z] as Array, spawn, MAX_SHADOWED_PER_ZONE)
		out["shadowed_kept"] = int(out["shadowed_kept"]) + r2.x
		out["shadows_off"] = int(out["shadows_off"]) + r2.y
		for l: Variant in by_zone[z]:
			if l is OmniLight3D and (l as OmniLight3D).shadow_enabled:
				(l as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	return out


## The environment part: effects off, volumetric fog -> depth fog of its colour. Returns "depth" when depth fog was
## made, "kept" when the map's own fog stays (thickened a little for the lost volumetrics), "" when there was none.
static func environment(env: Environment) -> String:
	if env == null:
		return ""
	var wanted_vol: bool = bool(env.get_meta(&"gl_want_volumetric_fog", env.volumetric_fog_enabled))
	if env.has_meta(DONE_META):
		return str(env.get_meta(DONE_META))
	for fx: String in ["sdfgi", "ssil", "ssr", "volumetric_fog", "ssao"]:
		var key: String = "gl_want_" + fx
		if not env.has_meta(key):
			env.set_meta(key, bool(env.get(fx + "_enabled")))   # GLSettings' gate remembers the map's wish the same way
		env.set(fx + "_enabled", false)
	var r: String = ""
	if wanted_vol:
		if env.fog_enabled:
			env.fog_density = env.fog_density * 1.3
			r = "kept"
		else:
			var lit: Color = env.volumetric_fog_albedo * env.ambient_light_color * clampf(env.ambient_light_energy, 0.05, 1.0)
			lit = lit + env.volumetric_fog_emission * env.volumetric_fog_emission_energy
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_light_color = Color(lit.r, lit.g, lit.b, 1.0)
			env.fog_light_energy = 1.0
			env.fog_depth_begin = 4.0
			env.fog_depth_end = clampf(2.5 / maxf(env.volumetric_fog_density, 0.001), 30.0, 300.0)
			env.fog_depth_curve = 1.0
			env.fog_density = 0.75   # depth mode: the most the fog hides in the distance
			r = "depth"
	env.set_meta(DONE_META, r)
	return r


## Keeps the shadow on the `keep` lights nearest `spawn`, turns it off on the rest. Returns (kept, turned off). Pure
## over the lights (the unit test drives it on a synthetic scene).
static func cap_shadows(lights: Array, spawn: Vector3, keep: int) -> Vector2i:
	var on: Array = lights.filter(func(l: Variant) -> bool: return l is Light3D and (l as Light3D).shadow_enabled)
	on.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return _pos(a).distance_squared_to(spawn) < _pos(b).distance_squared_to(spawn))
	var off: int = 0
	for i: int in on.size():
		if i >= keep:
			(on[i] as Light3D).shadow_enabled = false
			(on[i] as Light3D).set_meta(DONE_META, true)
			off += 1
	return Vector2i(mini(on.size(), keep), off)


static func _pos(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


## The zone a position is in: the ZoneVolumes under `root` (same rule as ZoneVolume.zone_at: the first that holds it).
static func _zone_of(root: Node, p: Vector3) -> StringName:
	if root.is_inside_tree():
		return ZoneVolume.zone_at(root.get_tree(), p)
	for n: Node in root.find_children("*", "ZoneVolume", true, false):
		var zv: ZoneVolume = n as ZoneVolume
		if zv.contains(p):
			return zv.zone_id
	return &""


## Lights carried by a player, bot, zombie or companion (torches, muzzle flashes) are left alone: they move.
static func _on_actor(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p is CharacterBody3D:
			return true
		p = p.get_parent()
	return false


static func _spawn_point(root: Node) -> Vector3:
	var pl: Variant = root.get("player") if root is MapRoot else null
	if pl is Node3D and is_instance_valid(pl) and (pl as Node3D).is_inside_tree():
		return (pl as Node3D).global_position
	for n: Node in root.find_children("*", "", true, false):
		if n.get_script() != null and (n.get_script() as Script).get_global_name() == &"PlayerSpawn":
			return _pos(n as Node3D)
	return Vector3.ZERO
