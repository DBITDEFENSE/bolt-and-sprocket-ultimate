class_name Terminator
extends Node3D
## Mondlicht's terminator (UPDATE 10 §3 Act IV, contract C6 `terminator`, T-158; data map04d.json "terminator"):
## the line between lunar day and night crawls across the relay over the act. The line is a vertical plane whose
## normal `h` points (flat) toward the Sun; it stands at `center + h * s`, and `s` runs from `from_s` (the whole
## base in day) to `to_s` (all night) over the act's rounds. Everything on the far side of the plane from the Sun is
## night: a shadow-only wall standing on the line casts the night's real shadow across the regolith under the low
## Sun (the crater's long shadow moving with it), the Sun itself (the scene's SunGate light, so the sky shader's disc
## follows) swings in azimuth and sinks, and the night side is:
##   · colder: in vacuum the suit heater strains, an extra air drain (`cold_air_drain` s of air per s, x
##     `heater_cold_mult` once the relay's heaters are on); the frost vignette on MoonSuitHud;
##   · darker: the domes' lights in a night zone drop to `zone_dim`;
##   · more dangerous: a night zone's spawns get `shadow_spawn_mult` (ZombieDirector.set_spawn_boost: +1 pressure).
## The day side of the yard is blinding without the visor (MoonSuitHud's glare veil; the `visor` action).
## The Operator comments once per zone the line crosses. Host-owned (C8): the host sets the target `s` per round and
## mirrors it; every peer glides to it over `glide_seconds` and draws the rest itself.

const ZONES_DOMED: PackedStringArray = ["A_RECEPTION", "B_CONCOURSE", "D_FULFILLMENT", "E_HALL", "F_CORE"]

var cfg: Dictionary = {}
var s: float = -80.0                 # the line's place along h (relative to center), now
var target_s: float = -80.0
var heaters_on: bool = false
var night_zones: Dictionary = {}     # zone -> true while its centre is on the night side
var crossed: Array[String] = []      # zones the Operator has spoken about
var _vo_i: int = 0
var _wall: MeshInstance3D = null
var _sun: DirectionalLight3D = null
var _sun_base: Vector3 = Vector3(0.88, 0.26, -0.31)
var _light_base: Dictionary = {}     # Light3D -> base energy
var _econ: Dictionary = {}           # zone -> the domes' lights before the heaters (economy mode), eased to 1
var _econ_target: Dictionary = {}
var _dim_k: Dictionary = {}          # zone -> current light multiplier (eased)
var _zone_t: float = 0.0
var _started: bool = false


# ---------------------------------------------------------------- pure rules (tests: test_mondlicht_u10.gd)

## The line's place for an act round: `from_s` at round 1, `to_s` at the act's last round (clamped).
static func line_s_for(act_round: int, length: int, from_s: float, to_s: float) -> float:
	var t: float = clampf(float(act_round - 1) / float(maxi(1, length - 1)), 0.0, 1.0)
	return lerpf(from_s, to_s, t)


## The act's progress 0..1 for a line position.
static func progress_of(line_s: float, from_s: float, to_s: float) -> float:
	return clampf((line_s - from_s) / maxf(0.001, to_s - from_s), 0.0, 1.0)


## The Sun's direction (toward the Sun, unit) at progress `t`: the base direction's azimuth turned by `az_deg` x t
## about +Y, its elevation eased from `elev_from` to `elev_to` degrees.
static func sun_dir_at(t: float, base: Vector3, az_deg: float, elev_from: float, elev_to: float) -> Vector3:
	var flat: Vector3 = Vector3(base.x, 0.0, base.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3(1, 0, 0)
	flat = flat.rotated(Vector3.UP, deg_to_rad(az_deg * t))
	var el: float = deg_to_rad(lerpf(elev_from, elev_to, t))
	return (flat * cos(el) + Vector3.UP * sin(el)).normalized()


## The flat normal of the line (toward the Sun).
static func line_normal(sun_dir: Vector3) -> Vector3:
	var f: Vector3 = Vector3(sun_dir.x, 0.0, sun_dir.z)
	return f.normalized() if f.length_squared() > 0.0001 else Vector3(1, 0, 0)


## Signed distance of `p` from the line (> 0 day side, toward the Sun; < 0 night).
static func side_of(p: Vector3, center: Vector3, h: Vector3, line_s: float) -> float:
	return (Vector3(p.x, 0, p.z) - Vector3(center.x, 0, center.z)).dot(h) - line_s


static func is_night(p: Vector3, center: Vector3, h: Vector3, line_s: float) -> bool:
	return side_of(p, center, h, line_s) < 0.0


## Seconds of air lost per second in vacuum on the night side (0 on the day side or in pressure).
static func cold_drain(night: bool, in_vacuum: bool, drain: float, heaters: bool, heater_mult: float) -> float:
	if not night or not in_vacuum:
		return 0.0
	return drain * (heater_mult if heaters else 1.0)


## The glare veil 0..1: on the day side, out in the open, facing the Sun; nothing with the visor down.
static func glare_for(day: bool, open: bool, facing: float, visor_down: bool, from_dot: float) -> float:
	if not day or not open or visor_down:
		return 0.0
	return clampf((facing - from_dot) / maxf(0.01, 1.0 - from_dot), 0.0, 1.0)


# ---------------------------------------------------------------- setup

func _ready() -> void:
	name = "Terminator"
	add_to_group(&"terminator")
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.flag_changed.connect(_on_flag_changed)


func setup(c: Dictionary, sun_base: Vector3) -> void:
	cfg = c
	_sun_base = sun_base
	s = float(cfg.get("from_s", -80.0))
	target_s = s
	for z: String in ZONES_DOMED:
		_econ[z] = float(cfg.get("economy_dim", 0.6))
		_econ_target[z] = _econ[z]
	_started = true
	_build_wall()
	(func() -> void: _find_sun()).call_deferred()


func _on_match_started(_m: StringName) -> void:
	if cfg.is_empty():
		var path: String = "res://data/gravelight/map04d.json"
		var c: Dictionary = GLData.load_json(path).get("terminator", {})
		var e: Dictionary = GLData.load_json(path).get("earth", {})
		var sd: Array = e.get("sun_dir", [0.88, 0.26, -0.31])
		setup(c, Vector3(float(sd[0]), float(sd[1]), float(sd[2])))
	if Net.is_authority():
		_set_round_target(RoundManager.current_round, true)


func center() -> Vector3:
	var c: Array = cfg.get("center", [8.0, 0.0, 33.0])
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func progress() -> float:
	return progress_of(s, float(cfg.get("from_s", -80.0)), float(cfg.get("to_s", 66.0)))


func sun_dir() -> Vector3:
	return sun_dir_at(progress(), _sun_base, float(cfg.get("sun_azimuth_deg", 24.0)), float(cfg.get("sun_elev_from", 15.6)), float(cfg.get("sun_elev_to", 6.0)))


func normal() -> Vector3:
	return line_normal(sun_dir())


## True when `p` is on the night side of the line now.
func night_at(p: Vector3) -> bool:
	return is_night(p, center(), normal(), s)


func _find_sun() -> void:
	var map: Node = get_tree().current_scene
	if map != null:
		_sun = map.get_node_or_null(^"Moon") as DirectionalLight3D
	_apply_sun()


func _build_wall() -> void:
	if _wall != null:
		return
	_wall = MeshInstance3D.new()
	_wall.name = "NightWall"
	var bm: BoxMesh = BoxMesh.new()
	var h_m: float = float(cfg.get("wall_height", 60.0))
	bm.size = Vector3(1.0, h_m, float(cfg.get("wall_length", 420.0)))
	_wall.mesh = bm
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_wall.set_meta("vis_group", "ALL")
	add_child(_wall)
	_place_wall()


func _place_wall() -> void:
	if _wall == null:
		return
	var h: Vector3 = normal()
	var c: Vector3 = center() + h * (s + 0.6)   # just on the day side: the shadow starts on the line
	var basis: Basis = Basis(Vector3.UP, atan2(h.x, h.z) + PI * 0.5)
	_wall.global_transform = Transform3D(basis, Vector3(c.x, float(cfg.get("wall_height", 60.0)) * 0.5 - 0.5, c.z))


func _apply_sun() -> void:
	if _sun == null or not is_instance_valid(_sun):
		return
	var d: Vector3 = sun_dir()
	_sun.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP), _sun.global_position)


# ---------------------------------------------------------------- the round drives the line (host)

func _on_round_started(r: int, _special: bool) -> void:
	if Net.is_authority():
		_set_round_target(r, false)


func _set_round_target(r: int, snap: bool) -> void:
	if cfg.is_empty():
		return
	var ar: int = RoundManager.act_round(r) if RoundManager.has_act() else r
	var length: int = int(RoundManager.act_block_of(GameState.map_id).get("length_rounds", 16)) if RoundManager.has_act() else 16
	set_target(line_s_for(maxi(1, ar), length, float(cfg.get("from_s", -80.0)), float(cfg.get("to_s", 66.0))), snap)


## Host: move the line to `to` (glide unless `snap`); mirrored to every peer.
func set_target(to: float, snap: bool = false) -> void:
	_net_target(to, snap)
	Net.mirror(self, &"_net_target", [to, snap])


func _net_target(to: float, snap: bool) -> void:
	target_s = to
	if snap:
		s = to
		_place_wall()
		_apply_sun()


func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if flag == &"heaters_on" and bool(value):
		heaters_on = true
		if float(_econ_target.get("A_RECEPTION", 1.0)) < 1.0:   # loaded with the flag set (a save, a skip): all up
			for z: String in ZONES_DOMED:
				wake_dome(z)


## The heaters' spectacle: one dome's lights come up to full.
func wake_dome(z: String) -> void:
	_econ_target[z] = 1.0


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if not _started:
		return
	if absf(target_s - s) > 0.001:
		var rate: float = maxf(1.0, absf(target_s - s)) / maxf(0.5, float(cfg.get("glide_seconds", 20.0)))
		s = move_toward(s, target_s, rate * delta)
		_place_wall()
		_apply_sun()
	for z: String in _econ.keys():
		_econ[z] = move_toward(float(_econ[z]), float(_econ_target.get(z, 1.0)), delta * 0.8)
	_zone_t -= delta
	if _zone_t <= 0.0:
		_zone_t = 0.5
		_update_zones()
	_update_lights(delta)
	_drain_air(delta)


func _zone_centre(z: String) -> Vector3:
	var zc: Dictionary = cfg.get("zone_centres", {})
	var a: Array = zc.get(z, [0, 0, 0])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _update_zones() -> void:
	var zc: Dictionary = cfg.get("zone_centres", {})
	for z: String in zc.keys():
		var night: bool = night_at(_zone_centre(z))
		if night == bool(night_zones.get(z, false)):
			continue
		night_zones[z] = night
		if not Net.is_authority():
			continue
		var dir: Node = get_tree().get_first_node_in_group(&"director")
		if dir != null and dir.has_method("set_spawn_boost"):
			dir.call("set_spawn_boost", StringName(z), float(cfg.get("shadow_spawn_mult", 1.5)) if night else 1.0)
		if night and not crossed.has(z):
			crossed.append(z)
			_cross_line(z, spoke_this_tick)
			spoke_this_tick = true
	spoke_this_tick = false


var spoke_this_tick: bool = false
var crossings_spoken: int = 0


## A zone falls into night: its flag; the Operator's line, one per crossing (zones crossed in the same moment, as
## after a skip, share one line so they don't flood the story channel).
func _cross_line(z: String, quiet: bool = false) -> void:
	var ids: Array = cfg.get("vo_cross", [])
	if not ids.is_empty() and not quiet:
		GLVO.play(StringName(str(ids[_vo_i % ids.size()])))
		_vo_i += 1
		crossings_spoken += 1
	print("[m4d] the terminator crosses %s (s %.1f)" % [z, s])
	GameState.set_flag(StringName("night_%s" % z.to_lower()))


## The domes' lights: economy-dim until the heaters, and `zone_dim` in a night zone (eased; HumPulse lights through
## their base_energy so their breathing stays).
func _update_lights(delta: float) -> void:
	var map: Node = get_tree().current_scene
	if map == null:
		return
	if _light_base.is_empty():
		for c: Node in map.get_children():
			var l: Light3D = c as Light3D
			if l == null or l is DirectionalLight3D or not l.has_meta("zone"):
				continue
			if not ZONES_DOMED.has(String(l.get_meta("zone"))):
				continue
			var base: Variant = l.get("base_energy")
			_light_base[l] = float(base) if base != null else l.light_energy
		if _light_base.is_empty():
			_light_base[null] = 0.0   # nothing to drive; don't scan again
	var dim: float = float(cfg.get("zone_dim", 0.55))
	for z: String in ZONES_DOMED:
		var want: float = (dim if bool(night_zones.get(z, false)) else 1.0)
		_dim_k[z] = move_toward(float(_dim_k.get(z, 1.0)), want, delta * 0.25)
	for l: Variant in _light_base.keys():
		var li: Light3D = l as Light3D
		if li == null or not is_instance_valid(li):
			continue
		var zn: String = String(li.get_meta("zone"))
		var k: float = float(_dim_k.get(zn, 1.0)) * float(_econ.get(zn, 1.0))
		var e: float = float(_light_base[l]) * k
		if li.get("base_energy") != null:
			li.set("base_energy", e)
		else:
			li.light_energy = e


## The suit heater's strain: an extra air drain in vacuum on the night side, for the players this peer simulates.
func _drain_air(delta: float) -> void:
	var drain: float = float(cfg.get("cold_air_drain", 0.6))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.in_vacuum or not p.is_alive():
			continue
		if not (p.is_local or (p.is_bot and Net.is_authority())):
			continue
		var d: float = cold_drain(night_at(p.global_position), true, drain, heaters_on, float(cfg.get("heater_cold_mult", 0.4)))
		if d > 0.0:
			p.air = maxf(0.0, p.air - d * delta)


## Console / smoke: put the line at act progress `t` (0..1) now.
func debug_progress(t: float) -> void:
	var to: float = lerpf(float(cfg.get("from_s", -80.0)), float(cfg.get("to_s", 66.0)), clampf(t, 0.0, 1.0))
	set_target(to, true)
	_update_zones()


## Captures (capture.gd `call:Terminator:capture_dusk`): the line part-way over the yard / most of the relay dark.
func capture_dusk() -> void:
	debug_progress(0.4)


func capture_night() -> void:
	debug_progress(0.75)
