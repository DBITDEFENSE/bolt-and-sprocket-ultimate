class_name HorrorLayer
extends Node3D
## UPDATE 11 section 6 (DECISIONS T-192): grit and dread on every map, from the map's living-world file key "horror"
## (MapAmbience kind u11_horror: data/gravelight/<map>_ambience.json). Presentation only: each peer runs its own, it
## touches no gameplay, no timing, no hitbox, no navmesh, no prompt. Every block is off when its key is absent.
##
##   chant        a low chant-like drone (horror_chant_bed, our own synthesis, not a recording) on the Ambience bus,
##                rising with the round (db [low, high] from from_round to full_round), and now and then a worn
##                fragment of a modal line over it (horror_chant_frag), more often later in the night
##   bells        a church bell far off (horror_bell_far) from a bearing, every interval
##   whispers     the Returned's last words from close up: within range_m of the local player a Soviet risen says a
##                lines.json category RTN_CLOSE line (speaker RTN, subtitled; u11-5-shots writes them), or, while
##                none exists, a wordless whisper (horror_whisper) at its head
##   breath       the squad's ragged breathing when hurt (player_breath_hurt): the local player below `below` of their
##                health (faster the lower), teammates within near_m at their body
##   frost_edges  ice ferns on the screen's edges in the cold (FrostCreep's texture, one full-screen TextureRect),
##                stronger with the round; off in warm_zones and below cold_min_y (the salt mine's depths)
##   flies        flies over the dead in warm zones (zones, or "all"): a small swarm and its buzz where a body fell,
##                for seconds; the count follows the VFX quality (Effects.quality "flies"), none on low
##   decals       a small dark stain under the dead with the Gore setting on "low" (on "full" the pool is GoreFx's,
##                since the gore rework; off = none) and mud thrown up where they rise from the ground; a pool sized
##                by VFX quality; none on the Compatibility renderer (no decals there)
##   grade        a darker night: the map's own adjustment brightness x brightness_mult (through GLSettings, so the
##                player's Brightness slider still scales it) and + contrast_add
##   lamps        the lanterns gutter: the map's FlickerLight lanterns get a deeper, more frequent gutter, and now and
##                then one nearly goes out for a moment
## The Operator's jingles are untouched (the Jingles bus): the contrast is the point.

const FROST_COLOR: Color = Color(0.82, 0.9, 1.0)

var cfg: Dictionary = {}
var amb: Node = null
var round_now: int = 1
var stats: Dictionary = {"frags": 0, "bells": 0, "whispers": 0, "rtn_lines": 0, "breaths": 0, "flies": 0, "decals": 0, "gutters": 0}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bed: AudioStreamPlayer = null
var _frag_t: float = 0.0
var _bell_t: float = 0.0
var _whisper_t: float = 0.0
var _whisper_cd: float = 0.0
var _breath_t: float = 0.0
var _mate_breath: Dictionary = {}   # pid -> seconds to the next breath
var _scan_t: float = 0.0
var _frost_layer: CanvasLayer = null
var _frost_rect: TextureRect = null
var _frost_now: float = 0.0
var _frost_want: float = 0.0
var _flies: Array[Dictionary] = []  # {node, snd, left}
var _decals: Array[Decal] = []
var _nd: int = 0
var _lanterns: Array[FlickerLight] = []
var _gutter_t: float = 0.0
var _gutter: Dictionary = {}        # the light being snuffed: {light, base, left}
static var _tex_blood: ImageTexture
static var _tex_mud: ImageTexture
static var _fly_mesh: QuadMesh
static var _fly_mat: StandardMaterial3D


func setup(c: Dictionary, ambience: Node) -> void:
	cfg = c
	amb = ambience
	_rng.randomize()
	round_now = maxi(1, RoundManager.current_round)
	var ch: Dictionary = cfg.get("chant", {})
	if not ch.is_empty() and AudioDirector.has_sound(str(ch.get("bed", "horror_chant_bed"))):
		_bed = AudioDirector.make_loop_2d(str(ch.get("bed", "horror_chant_bed")), self, bed_db(round_now, ch))
		if _bed != null:
			_bed.play(_rng.randf_range(0.0, 20.0))
	_frag_t = _first(ch.get("frag", {}))
	_bell_t = _first(cfg.get("bells", {}))
	if cfg.has("frost_edges"):
		_build_frost()
	if cfg.has("decals"):
		_build_decals()
	if cfg.has("grade"):
		apply_grade(get_tree(), cfg["grade"])
	if cfg.has("lamps"):
		_find_lanterns()
	GLBus.round_started.connect(_on_round_started)
	if cfg.has("flies") or cfg.has("decals"):
		GLBus.enemy_killed_at.connect(_on_killed_at)
	if cfg.has("decals"):
		GLBus.enemy_spawned.connect(_on_spawned)


func _exit_tree() -> void:
	if GLBus.round_started.is_connected(_on_round_started):
		GLBus.round_started.disconnect(_on_round_started)
	if GLBus.enemy_killed_at.is_connected(_on_killed_at):
		GLBus.enemy_killed_at.disconnect(_on_killed_at)
	if GLBus.enemy_spawned.is_connected(_on_spawned):
		GLBus.enemy_spawned.disconnect(_on_spawned)
	_restore_gutter()


# ================================================================== pure rules (unit-tested)

## The round's share of the night, 0..1, between a block's from_round and full_round.
static func night_k(r: int, c: Dictionary) -> float:
	var a: float = float(c.get("from_round", 1))
	var b: float = float(c.get("full_round", 25))
	return clampf((float(r) - a) / maxf(1.0, b - a), 0.0, 1.0)


## The chant bed's volume at round `r` (dB): db[0] at from_round rising to db[1] at full_round; silent before.
static func bed_db(r: int, c: Dictionary) -> float:
	if r < int(c.get("from_round", 1)):
		return -80.0
	var d: Array = c.get("db", [-34.0, -22.0])
	return lerpf(float(d[0]), float(d[1]), night_k(r, c))


## The [min, max] wait to the next event of a block at round `r` (interval early, interval_late at full_round).
static func interval_at(r: int, c: Dictionary, parent: Dictionary = {}) -> Vector2:
	var k: float = night_k(r, parent if not parent.is_empty() else c)
	var a: Array = c.get("interval", [60, 120])
	var b: Array = c.get("interval_late", a)
	return Vector2(lerpf(float(a[0]), float(b[0]), k), lerpf(float(a[1]), float(b[1]), k))


## How frosted the screen edges are (0..1) at round `r`; 0 when warm.
static func frost_strength(r: int, c: Dictionary, warm: bool) -> float:
	if warm:
		return 0.0
	var s: Array = c.get("strength", [0.25, 0.55])
	return lerpf(float(s[0]), float(s[1]), night_k(r, c))


## Seconds between hurt breaths at health fraction `f` (0..1); INF when not hurt enough.
static func breath_period(f: float, c: Dictionary) -> float:
	var below: float = float(c.get("below", 0.5))
	if f >= below:
		return INF
	var e: Array = c.get("every", [3.2, 1.6])
	return lerpf(float(e[1]), float(e[0]), clampf(f / maxf(0.01, below), 0.0, 1.0))


## True for a zombie the whispers come from: a Soviet risen on its feet.
static func whisperer(z: Zombie) -> bool:
	return z != null and is_instance_valid(z) and z.is_active() and not z.is_dormant() \
		and ZombieBody.SOVIET_KITS.has(z.variant_name())


## Gore setting -> the decal under a body: "blood", "stain" (low), "" (off).
static func blood_kind(gore: String) -> String:
	match gore:
		"full":
			return "blood"
		"low":
			return "stain"
	return ""


# ================================================================== the loop

func _first(c: Dictionary) -> float:
	if c.is_empty():
		return INF
	var f: Array = c.get("first_after", [20, 50])
	return _rng.randf_range(float(f[0]), float(f[1]))


func _on_round_started(r: int, _special: bool) -> void:
	round_now = maxi(1, r)
	var ch: Dictionary = cfg.get("chant", {})
	if _bed != null:
		var tw: Tween = create_tween()
		tw.tween_property(_bed, "volume_db", bed_db(round_now, ch), 6.0)


func _process(delta: float) -> void:
	var ch: Dictionary = cfg.get("chant", {})
	var fr: Dictionary = ch.get("frag", {})
	if not fr.is_empty() and round_now >= int(ch.get("from_round", 1)):
		_frag_t -= delta
		if _frag_t <= 0.0:
			var iv: Vector2 = interval_at(round_now, fr, ch)
			_frag_t = _rng.randf_range(iv.x, iv.y)
			var d: Array = fr.get("db", [-30.0, -18.0])
			AudioDirector.play_2d(str(fr.get("sound", "horror_chant_frag")), lerpf(float(d[0]), float(d[1]), night_k(round_now, ch)), 0.0)
			stats["frags"] = int(stats["frags"]) + 1
	var be: Dictionary = cfg.get("bells", {})
	if not be.is_empty():
		_bell_t -= delta
		if _bell_t <= 0.0:
			var iv2: Vector2 = interval_at(round_now, be)
			_bell_t = _rng.randf_range(iv2.x, iv2.y)
			_far_bell(be)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		_scan(0.25)
	_update_frost(delta)
	_update_flies(delta)
	_update_gutter(delta)


func _local() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_local and not p.is_bot:
			return p
	return null


func _far_bell(be: Dictionary) -> void:
	var br: Array = be.get("bearings", [0, 360])
	var b: float = _rng.randf_range(float(br[0]), float(br[1]))
	var at: Vector3 = LandscapeTerrain.at_bearing(b, float(be.get("radius", 260.0)))
	var key: String = str(be.get("sound", "horror_bell_far"))
	var db: float = float(be.get("db", -10.0))
	if amb != null and amb.has_method("far_sound"):
		amb.call("far_sound", key, at, db)
	else:
		AudioDirector.play_2d(key, db)
	stats["bells"] = int(stats["bells"]) + 1


## The every-quarter-second checks: whispers, breathing, the frost's warm / cold.
func _scan(dt: float) -> void:
	var me: Player = _local()
	_whisper_cd = maxf(0.0, _whisper_cd - dt)
	var wh: Dictionary = cfg.get("whispers", {})
	if me != null and not wh.is_empty() and _whisper_cd <= 0.0 and not me.spectating:
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			var rng_m: float = float(wh.get("range_m", 3.5))
			for z: Zombie in dir.active_zombies():
				if whisperer(z) and z.global_position.distance_to(me.global_position) < rng_m:
					_whisper(z, wh)
					break
	var bh: Dictionary = cfg.get("breath", {})
	if not bh.is_empty():
		_breath_scan(me, bh, dt)
	var fe: Dictionary = cfg.get("frost_edges", {})
	if not fe.is_empty():
		var warm: bool = me == null or me.spectating or _is_warm(me.global_position, fe)
		_frost_want = frost_strength(round_now, fe, warm)


func _whisper(z: Zombie, wh: Dictionary) -> void:
	var cd: Array = wh.get("cooldown_s", [7.0, 14.0])
	_whisper_cd = _rng.randf_range(float(cd[0]), float(cd[1]))
	stats["whispers"] = int(stats["whispers"]) + 1
	if GLVO.play_category(StringName(str(wh.get("speaker", "RTN"))), str(wh.get("category", "RTN_CLOSE"))):
		stats["rtn_lines"] = int(stats["rtn_lines"]) + 1
		return
	AudioDirector.play_3d(str(wh.get("fallback", "horror_whisper")), z.global_position + Vector3.UP * 1.55, float(wh.get("fallback_db", -4.0)), 0.04)


func _breath_scan(me: Player, bh: Dictionary, dt: float) -> void:
	var key: String = str(bh.get("sound", "player_breath_hurt"))
	if me != null and me.is_alive() and not me.spectating:
		var per: float = breath_period(0.15 if me.downed else me.health_fraction(), bh)
		if per < INF:
			_breath_t -= dt
			if _breath_t <= 0.0:
				_breath_t = per * _rng.randf_range(0.9, 1.1)
				AudioDirector.play_2d(key, float(bh.get("db", -6.0)), 0.04)
				stats["breaths"] = int(stats["breaths"]) + 1
		else:
			_breath_t = minf(_breath_t, 0.6)
	var near: float = float(bh.get("near_m", 6.0))
	if near <= 0.0:
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p == me or p.spectating or not p.is_inside_tree():
			continue
		var per2: float = breath_period(0.15 if p.downed else p.health_fraction(), bh)
		if per2 == INF or me == null or p.global_position.distance_to(me.global_position) > near:
			_mate_breath.erase(p.player_id)
			continue
		var left: float = float(_mate_breath.get(p.player_id, _rng.randf_range(0.2, per2))) - dt
		if left <= 0.0:
			left = per2 * _rng.randf_range(0.9, 1.15)
			AudioDirector.play_3d(key, p.global_position + Vector3.UP * (0.5 if p.downed else 1.55), float(bh.get("mate_db", -8.0)), 0.06)
		_mate_breath[p.player_id] = left


func _is_warm(at: Vector3, c: Dictionary) -> bool:
	if at.y < float(c.get("cold_min_y", -INF)):
		return true
	var z: String = String(ZoneVolume.zone_at(get_tree(), at))
	return (c.get("warm_zones", []) as Array).has(z)


# ================================================================== frost on the screen edges

func _build_frost() -> void:
	_frost_layer = CanvasLayer.new()
	_frost_layer.name = "HorrorFrost"
	_frost_layer.layer = 4   # under the PostFx film look (5) and the HUD
	add_child(_frost_layer)
	_frost_rect = TextureRect.new()
	_frost_rect.texture = FrostCreep.texture()
	_frost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frost_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frost_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost_rect.modulate = Color(FROST_COLOR.r, FROST_COLOR.g, FROST_COLOR.b, 0.0)
	_frost_layer.add_child(_frost_rect)


func _update_frost(delta: float) -> void:
	if _frost_rect == null:
		return
	_frost_now = move_toward(_frost_now, _frost_want, delta * float((cfg.get("frost_edges", {}) as Dictionary).get("fade_per_s", 0.25)))
	_frost_rect.modulate.a = _frost_now if GameState.phase == GameState.Phase.PLAYING else 0.0
	_frost_rect.visible = _frost_rect.modulate.a > 0.005


func frost_alpha() -> float:
	return _frost_rect.modulate.a if _frost_rect != null else 0.0


# ================================================================== flies and decals

func _on_killed_at(_enemy_id: StringName, at: Vector3, _by: int) -> void:
	var fl: Dictionary = cfg.get("flies", {})
	if not fl.is_empty() and _flies_allowed(at, fl):
		_spawn_flies(at, fl)
	var dc: Dictionary = cfg.get("decals", {})
	if not dc.is_empty():
		var kind: String = blood_kind(ZombieGore.level())
		# The gore rework (docs/gore/gore_rework_2026-11.md): with Gore on "full" the pool under a body is GoreFx's
		# (it spreads, dries, is trodden through and is one draw call; it also exists on the Compatibility renderer).
		# This layer's projected decal stays for "low" (the small dark stain) so the two never lie on top of each other.
		if kind == "stain":
			_place_decal(at, kind, dc)


func _on_spawned(_enemy_id: StringName, node_id: int) -> void:
	var z: Zombie = instance_from_id(node_id) as Zombie
	if z == null or not is_instance_valid(z) or z.state != Zombie.State.EMERGE:
		return
	var dc: Dictionary = cfg.get("decals", {})
	if bool(dc.get("mud", true)) and _rng.randf() < float(dc.get("mud_chance", 0.6)):
		_place_decal(z.global_position, "mud", dc)


func _flies_allowed(at: Vector3, fl: Dictionary) -> bool:
	if fly_cap() <= 0:
		return false
	if bool(fl.get("all", false)):
		return true
	return (fl.get("zones", []) as Array).has(String(ZoneVolume.zone_at(get_tree(), at)))


## How many swarms the VFX quality allows (the block's max_by_quality; none on low).
func fly_cap() -> int:
	var by: Dictionary = (cfg.get("flies", {}) as Dictionary).get("max_by_quality", {"low": 0, "medium": 2, "high": 4})
	return int(by.get(str(GLSettings.values.get("vfx_quality", "high")), 2))


func _spawn_flies(at: Vector3, fl: Dictionary) -> void:
	var slot: Dictionary = {}
	if _flies.size() < fly_cap():
		var p: CPUParticles3D = CPUParticles3D.new()
		p.name = "Flies"
		p.amount = int(fl.get("amount", 14))
		p.lifetime = 0.9
		p.preprocess = 0.5
		p.local_coords = true
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.45
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.1
		p.orbit_velocity_min = 0.6
		p.orbit_velocity_max = 1.4
		p.damping_min = 0.5
		p.damping_max = 1.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.0
		p.mesh = _fly_quad()
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		slot = {"node": p, "snd": AudioDirector.make_loop_3d(str(fl.get("sound", "horror_flies_loop")), p, float(fl.get("db", -6.0))), "left": 0.0}
		_flies.append(slot)
	else:
		# the oldest swarm moves on
		var best: int = 0
		for i: int in _flies.size():
			if float(_flies[i]["left"]) < float(_flies[best]["left"]):
				best = i
		if _flies.is_empty():
			return
		slot = _flies[best]
	var node: CPUParticles3D = slot["node"]
	node.global_position = at + Vector3.UP * 0.55
	node.emitting = true
	node.show()
	if slot["snd"] != null:
		(slot["snd"] as AudioStreamPlayer3D).play()
	slot["left"] = float(fl.get("seconds", 14.0))
	stats["flies"] = int(stats["flies"]) + 1


func _update_flies(delta: float) -> void:
	for s: Dictionary in _flies:
		if float(s["left"]) <= 0.0:
			continue
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) <= 0.0:
			(s["node"] as CPUParticles3D).emitting = false
			(s["node"] as CPUParticles3D).hide()
			if s["snd"] != null:
				(s["snd"] as AudioStreamPlayer3D).stop()


static func _fly_quad() -> QuadMesh:
	if _fly_mesh != null:
		return _fly_mesh
	_fly_mesh = QuadMesh.new()
	_fly_mesh.size = Vector2(0.012, 0.008)
	_fly_mat = StandardMaterial3D.new()
	_fly_mat.albedo_color = Color(0.03, 0.03, 0.025)
	_fly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fly_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fly_mat.billboard_keep_scale = true
	_fly_mesh.material = _fly_mat
	return _fly_mesh


func _build_decals() -> void:
	if GLSettings.is_compat():
		return   # the Compatibility renderer draws no decals
	var dc: Dictionary = cfg.get("decals", {})
	var pool: Dictionary = dc.get("pool", {"low": 6, "medium": 14, "high": 24})
	var n: int = int(pool.get(str(GLSettings.values.get("vfx_quality", "high")), 14))
	for i: int in n:
		var d: Decal = Decal.new()
		d.name = "Grit"
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.distance_fade_enabled = true
		d.distance_fade_begin = float(dc.get("fade_begin_m", 35.0))
		d.distance_fade_length = 10.0
		d.cull_mask = 1
		d.hide()
		add_child(d)
		_decals.append(d)


func _place_decal(at: Vector3, kind: String, dc: Dictionary) -> void:
	if _decals.is_empty():
		return
	var d: Decal = _decals[_nd]
	_nd = (_nd + 1) % _decals.size()
	var sz: Array = dc.get(kind + "_size", [0.9, 1.6] if kind == "blood" else ([0.5, 0.8] if kind == "stain" else [0.8, 1.3]))
	var w: float = _rng.randf_range(float(sz[0]), float(sz[1]))
	d.size = Vector3(w, 1.6, w)
	d.texture_albedo = mud_texture() if kind == "mud" else blood_texture()
	d.modulate = Color(0.45, 0.4, 0.4, 0.85) if kind == "stain" else Color(1, 1, 1, 0.92)
	d.global_position = at + Vector3(0, 0.5, 0)
	d.rotation = Vector3(0, _rng.randf() * TAU, 0)
	d.show()
	stats["decals"] = int(stats["decals"]) + 1


func decal_count() -> int:
	var n: int = 0
	for d: Decal in _decals:
		if d.visible:
			n += 1
	return n


## A pool of dark, half-frozen blood: an irregular blotch with darker clots, alpha soft at the edge. Drawn once.
static func blood_texture() -> ImageTexture:
	if _tex_blood == null:
		_tex_blood = _splat(91, Color(0.22, 0.015, 0.02), Color(0.08, 0.005, 0.01), 0.42)
	return _tex_blood


## Mud and slush thrown up by a body digging out of the ground.
static func mud_texture() -> ImageTexture:
	if _tex_mud == null:
		_tex_mud = _splat(57, Color(0.2, 0.15, 0.1), Color(0.1, 0.075, 0.05), 0.36)
	return _tex_mud


static func _splat(seed_v: int, col: Color, clot: Color, radius: float) -> ImageTexture:
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.045
	var fine: FastNoiseLite = FastNoiseLite.new()
	fine.seed = seed_v + 7
	fine.frequency = 0.16
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var drops: Array[Vector3] = []
	for i: int in 9:
		var a: float = rng.randf() * TAU
		var rr: float = rng.randf_range(0.36, 0.48)
		drops.append(Vector3(0.5 + cos(a) * rr, 0.5 + sin(a) * rr, rng.randf_range(0.015, 0.035)))
	for y: int in n:
		for x: int in n:
			var u: float = float(x) / float(n)
			var v: float = float(y) / float(n)
			var d: float = Vector2(u - 0.5, v - 0.5).length()
			var edge: float = radius + 0.09 * noise.get_noise_2d(float(x), float(y))
			var a2: float = clampf((edge - d) / 0.05, 0.0, 1.0)
			for dr: Vector3 in drops:
				a2 = maxf(a2, clampf((dr.z - Vector2(u - dr.x, v - dr.y).length()) / 0.01, 0.0, 1.0))
			var k: float = clampf(0.5 + 0.5 * fine.get_noise_2d(float(x), float(y)), 0.0, 1.0)
			var c: Color = col.lerp(clot, k * k)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a2 * (0.75 + 0.25 * k)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ================================================================== the grade and the lamps

## A darker night on the map's WorldEnvironment (once): its own adjustment brightness x brightness_mult through
## GLSettings' brightness base (the player's slider still scales it), contrast + contrast_add.
static func apply_grade(tree: SceneTree, g: Dictionary) -> WorldEnvironment:
	var we: WorldEnvironment = null
	for n: Node in tree.root.find_children("*", "WorldEnvironment", true, false):
		we = n as WorldEnvironment
		break
	if we == null or we.environment == null:
		return null
	var env: Environment = we.environment
	if env.has_meta("gl_horror_grade"):
		return we
	env.set_meta("gl_horror_grade", true)
	if not env.has_meta("gl_base_brightness"):
		env.set_meta("gl_base_brightness", env.adjustment_brightness if env.adjustment_enabled else 1.0)
	env.set_meta("gl_base_brightness", float(env.get_meta("gl_base_brightness")) * float(g.get("brightness_mult", 0.9)))
	env.set_meta("gl_horror_mult", float(g.get("brightness_mult", 0.9)))   # T-207: the look grade folds it into its own base
	if not env.adjustment_enabled:
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.0
		env.adjustment_saturation = 1.0
	env.adjustment_contrast += float(g.get("contrast_add", 0.04))
	var b: float = clampf(float(GLSettings.values.get("brightness", 1.0)), 0.6, 1.5)
	env.adjustment_brightness = float(env.get_meta("gl_base_brightness")) * b
	return we


func _find_lanterns() -> void:
	var lc: Dictionary = cfg.get("lamps", {})
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	for n: Node in root.find_children("*", "FlickerLight", true, false):
		var f: FlickerLight = n as FlickerLight
		if f == null or f.fire:
			continue
		f.configure(false, 1.0, 1.0, float(lc.get("gutter_threshold", 0.55)), float(lc.get("gutter_depth", 0.75)))
		_lanterns.append(f)
	_gutter_t = _rng.randf_range(4.0, 10.0)


func _update_gutter(delta: float) -> void:
	if _lanterns.is_empty():
		return
	if not _gutter.is_empty():
		_gutter["left"] = float(_gutter["left"]) - delta
		var fl: FlickerLight = _gutter["light"] as FlickerLight if is_instance_valid(_gutter["light"]) else null
		if fl == null or float(_gutter["left"]) <= 0.0:
			_restore_gutter()
		else:
			# two or three catches as it fights back
			fl.base_energy = float(_gutter["base"]) * (0.12 + 0.5 * maxf(0.0, sin(float(_gutter["left"]) * 21.0)) * 0.4)
		return
	_gutter_t -= delta
	if _gutter_t > 0.0:
		return
	var lc: Dictionary = cfg.get("lamps", {})
	var iv: Array = lc.get("snuff_every", [8.0, 20.0])
	_gutter_t = _rng.randf_range(float(iv[0]), float(iv[1]))
	var f2: FlickerLight = _lanterns[_rng.randi() % _lanterns.size()]
	if not is_instance_valid(f2) or not f2.is_visible_in_tree():
		return
	_gutter = {"light": f2, "base": f2.base_energy, "left": _rng.randf_range(0.35, 0.9)}
	stats["gutters"] = int(stats["gutters"]) + 1


func _restore_gutter() -> void:
	if _gutter.is_empty():
		return
	var fl: Variant = _gutter["light"]
	if is_instance_valid(fl):
		(fl as FlickerLight).base_energy = float(_gutter["base"])
	_gutter = {}
