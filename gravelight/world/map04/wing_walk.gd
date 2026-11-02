class_name WingWalk
extends Node3D
## UPDATE 10 §3 (contract C6 `wing_walk`, DECISIONS T-156): out onto the Kranich's port wing in flight.
## From act round `opens_act_round` (or `open_now()`) the leading-edge panel BreachL2 in the port crawlway is torn
## off for good: behind it a WingHatch climbs out onto `wing_rails`, a tether-rail catwalk on stanchions along the
## wing's upper skin (deck_y), aft round the engine nacelle and out to the wingtip, where a chest holds the reward
## (a perk-tier `discount_token`, and a wonder-part slot the bots/wonder worker can fill). The catwalk has its own
## navmesh region (gen_map04b: Navigation/Nav_WingRails, enabled when it opens) and a climb link at the hatch, so
## the dead follow you up; Bordschützen also come over the wing's edge (`climbers`).
##
## Clip state machine per player (host-owned, mirrored): OFF_WING -> UNCLIPPED (on the deck) -> CLIPPED (hold a
## ClipPoint 1 s; the tether runner rides the rail) -> back to OFF_WING when they climb in, fall or go down. Every
## turbulence (the FlightController's tilt, warned 3 s ahead) throws the UNCLIPPED off the wing: a down, never a
## death (co-op: a normal down at the hatch's foot; solo: a scripted down and a get-up, the match never ends on it).
## Bots never go unclipped (a bot on the deck is clipped at once). A fall off the deck counts the same as a throw.
## Data: map04b.json flight.wing_walk. Pure rules are static for the tests (`next_state`, `in_rect`, `on_deck`).

enum ClipState { OFF_WING, UNCLIPPED, CLIPPED }

const DATA: String = "res://data/gravelight/map04b.json"

var cfg: Dictionary = {}
var is_open: bool = false
var states: Dictionary = {}        # pid -> ClipState (host truth; clients hold the mirror)
var knocked: int = 0               # throws + falls this match (smoke / tests)
var climbers_spawned: int = 0
var opened_at_round: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _climb_t: float = 0.0
var _pass_t: float = 8.0
var _wind_t: float = 0.0
var _link: NavigationLink3D = null
var _hud: CanvasLayer = null
var _hud_label: Label = null
var _warn_t: float = 0.0
var _streaks: CPUParticles3D = null
var _wind_snd: AudioStreamPlayer = null
var _off_t: Dictionary = {}        # pid -> seconds off the deck while still on the wing (host)


# ---------------------------------------------------------------- pure rules

## The next clip state after `event`: "deck" (stands on the catwalk), "clip" (finished a clip-point hold),
## "leave" (climbed in / fell / went down), "turbulence" (a tilt hits). Returns [state, thrown_off].
static func next_state(state: int, event: String, is_bot: bool = false) -> Array:
	match event:
		"deck":
			if state == ClipState.OFF_WING:
				return [ClipState.CLIPPED if is_bot else ClipState.UNCLIPPED, false]
		"clip":
			if state != ClipState.OFF_WING:
				return [ClipState.CLIPPED, false]
		"leave":
			return [ClipState.OFF_WING, false]
		"turbulence":
			if state == ClipState.UNCLIPPED and not is_bot:
				return [ClipState.OFF_WING, true]
	return [state, false]


## Is (x, z) inside the rect [[x0, z0], [x1, z1]] grown by `m`?
static func in_rect(rect: Array, x: float, z: float, m: float = 0.0) -> bool:
	var a: Array = rect[0]
	var b: Array = rect[1]
	return x >= minf(float(a[0]), float(b[0])) - m and x <= maxf(float(a[0]), float(b[0])) + m \
		and z >= minf(float(a[1]), float(b[1])) - m and z <= maxf(float(a[1]), float(b[1])) + m


## Does a body at `p` stand on the catwalk (any segment, at deck height)?
static func on_deck(segments: Array, deck_y: float, p: Vector3, margin: float = 0.4) -> bool:
	if p.y < deck_y - 0.7 or p.y > deck_y + 3.0:
		return false
	for r: Array in segments:
		if in_rect(r, p.x, p.z, margin):
			return true
	return false


## Is a player on any wing walk's deck? (FlightController skips them for the tilt's push: the wing has its own wind.)
static func on_wing_any(tree: SceneTree, p: Node3D) -> bool:
	if tree == null or p == null:
		return false
	for n: Node in tree.get_nodes_in_group(&"wing_walks"):
		var ww: WingWalk = n as WingWalk
		if ww != null and ww.is_open and on_deck(ww.cfg.get("segments", []), float(ww.cfg.get("deck_y", 3.4)), p.global_position):
			return true
	return false


static func v3(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr != null and arr.size() >= 3 else Vector3.ZERO


# ---------------------------------------------------------------- setup

func _ready() -> void:
	add_to_group(&"wing_walks")
	_rng.randomize()
	var d: Dictionary = GLData.load_json(DATA)
	cfg = (d.get("flight", {}) as Dictionary).get("wing_walk", {})
	if not GLBus.round_started.is_connected(_on_round_started):
		GLBus.round_started.connect(_on_round_started)
	_set_region(false)
	_build_link()
	_build_hud()
	_build_streaks()
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "wingwalk", _cmd, "wingwalk open|status|clip|throw: the Kranich's wing walk (T-156)")


func _region() -> NavigationRegion3D:
	for root: Node in [get_parent(), get_tree().current_scene]:
		if root == null:
			continue
		var r: Node = root.find_child("Nav_WingRails", true, false)
		if r is NavigationRegion3D:
			return r as NavigationRegion3D
	return null


## The catwalk's region stays enabled (an island nothing reaches while shut): toggling NavigationRegion3D.enabled
## off and on again left its polygons unreachable on 4.7 (paths snapped into the crawlway below), so the climb link
## is the gate.
func _set_region(on: bool) -> void:
	if _link != null:
		_link.enabled = on


## The dead's way up: a climb link from the crawlway floor under the hatch to the landing (ClimbLink's meta).
func _build_link() -> void:
	if cfg.is_empty():
		return
	_link = NavigationLink3D.new()
	_link.name = "WingClimb"
	_link.start_position = v3(cfg.get("link_from", [-40, 0, 43.8]))
	_link.end_position = v3(cfg.get("link_to", [-40, 3.4, 43.6]))
	_link.bidirectional = true
	var bits: Variant = get_tree().current_scene.get("nav_zone_bits") if get_tree().current_scene != null else null
	var bit: int = 3
	if bits is Dictionary and (bits as Dictionary).has(&"C_FLUEGEL_L"):
		bit = int((bits as Dictionary)[&"C_FLUEGEL_L"])
	_link.navigation_layers = 1 << (bit - 1)
	_link.set_meta(ClimbLink.META, true)
	_link.enabled = false
	add_child(_link)


func _on_round_started(_r: int, _special: bool) -> void:
	if not Net.is_authority() or is_open or cfg.is_empty():
		return
	if RoundManager.act_round() >= int(cfg.get("opens_act_round", 2)):
		open_now()


# ---------------------------------------------------------------- opening

## The strafing run that tears the port crawlway's leading-edge panel off: the wing walk opens (host; mirrored).
func open_now() -> void:
	if is_open:
		return
	if Net.is_authority():
		var fc: Node = get_tree().get_first_node_in_group(&"flight_controller")
		var panel: Node = _find(str(cfg.get("panel", "BreachL2")))
		if panel != null and panel.has_method("tear"):
			panel.call("tear", (fc.get("cfg") as Dictionary).get("breach", {}) if fc != null else {})
		var sky: Node = get_tree().get_first_node_in_group(&"flight_sky")
		if sky != null and sky.has_method("spawn_pass"):
			sky.call("spawn_pass", true)
		GLVO.play(StringName(str(cfg.get("vo_open", "PA_M4B_WING_01"))))
		GLVO.play_category(&"DEA", "M4B_WING", 0.6)
	_opened()
	Net.mirror(self, &"_opened")


func _opened() -> void:
	if is_open:
		return
	is_open = true
	opened_at_round = RoundManager.current_round
	_set_region(true)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", str(cfg.get("banner", "THE PORT WING IS OPEN\nClimb out at the torn panel · clip in at the tether posts")), 4.0)
	for n: Node in get_tree().get_nodes_in_group(&"wing_hatches"):
		n.call("set_open", true)
	print("[wingwalk] open (round %d)" % RoundManager.current_round)


func _find(n: String) -> Node:
	for root: Node in [get_parent(), get_tree().current_scene]:
		if root == null:
			continue
		var f: Node = root.find_child(n, true, false)
		if f != null:
			return f
	return null


# ---------------------------------------------------------------- clip state (host truth)

func state_of(pid: int) -> int:
	return int(states.get(pid, ClipState.OFF_WING))


func is_clipped(pid: int) -> bool:
	return state_of(pid) == ClipState.CLIPPED


## A ClipPoint's hold finished (host).
func clip(p: Player) -> void:
	if p == null or not on_deck(cfg.get("segments", []), float(cfg.get("deck_y", 3.4)), p.global_position):
		return   # only on the deck (a tether post stands on it)
	var r: Array = next_state(state_of(p.player_id), "deck" if state_of(p.player_id) == ClipState.OFF_WING else "clip", p.is_bot)
	if int(r[0]) == ClipState.UNCLIPPED:
		r = next_state(int(r[0]), "clip", p.is_bot)
	_set_state(p.player_id, int(r[0]))
	AudioDirector.play_3d("reload_end", p.global_position + Vector3.UP, 0.0)


func _set_state(pid: int, st: int) -> void:
	if state_of(pid) == st:
		return
	states[pid] = st
	if Net.is_authority():
		Net.mirror(self, &"_state_mirror", [pid, st])


func _state_mirror(pid: int, st: int) -> void:
	states[pid] = st


# ---------------------------------------------------------------- the tick

func _physics_process(delta: float) -> void:
	if not is_open:
		return
	_warn_t = maxf(0.0, _warn_t - delta)
	_tick_local(delta)
	if not Net.is_authority():
		return
	var segs: Array = cfg.get("segments", [])
	var deck_y: float = float(cfg.get("deck_y", 3.4))
	var anyone: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null:
			continue
		var pid: int = p.player_id
		var st: int = state_of(pid)
		var on: bool = p.is_alive() and on_deck(segs, deck_y, p.global_position)
		if on:
			anyone = true
			_off_t.erase(pid)
			if st == ClipState.OFF_WING:
				_set_state(pid, int(next_state(st, "deck", p.is_bot)[0]))
			elif p.is_bot and st == ClipState.UNCLIPPED:
				_set_state(pid, ClipState.CLIPPED)
		elif st != ClipState.OFF_WING:
			# off the deck: climbed back in (the hatch puts them at its foot), or went over the side and is falling
			# (below the deck, anywhere but the hatch's foot); in the air above the deck for a moment is neither
			var off: float = float(_off_t.get(pid, 0.0)) + delta
			_off_t[pid] = off
			if not p.is_alive() or _near_hatch_foot(p.global_position):
				_set_state(pid, ClipState.OFF_WING)
				_off_t.erase(pid)
			elif p.global_position.y < deck_y - 1.2:
				_off_t.erase(pid)
				throw_off(p, "fell")
			elif off > 3.0:
				_set_state(pid, ClipState.OFF_WING)
				_off_t.erase(pid)
	if anyone:
		_wind(delta)
		_tick_climbers(delta)
		_tick_passes(delta)


func _near_hatch_foot(p: Vector3) -> bool:
	return p.distance_to(v3(cfg.get("hatch_foot", [-40, 0.1, 43.2]))) < 2.5 and p.y < 1.0


## The wind on the deck: a steady aft push (less for the clipped: the tether takes it).
func _wind(delta: float) -> void:
	_wind_t -= delta
	if _wind_t > 0.0:
		return
	_wind_t = 0.25
	var w: Vector3 = v3(cfg.get("wind_dir", [0, 0, -1])).normalized() * float(cfg.get("wind_mps", 0.7))
	var segs: Array = cfg.get("segments", [])
	var deck_y: float = float(cfg.get("deck_y", 3.4))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and on_deck(segs, deck_y, p.global_position) and not p.is_pushed():
			p.external_push(w * (0.4 if is_clipped(p.player_id) else 1.0), 0.3, &"push")


## Bordschützen come over the wing's edge while somebody is out there (they draw from the round's queue).
func _tick_climbers(delta: float) -> void:
	var cc: Dictionary = cfg.get("climbers", {})
	_climb_t -= delta
	if _climb_t > 0.0:
		return
	_climb_t = float(cc.get("every_s", 16.0))
	var fc: Node = get_tree().get_first_node_in_group(&"flight_controller")
	if fc == null or not fc.has_method("spawn_climber"):
		return
	var pts: Array = cc.get("points", [])
	if pts.is_empty() or _wing_zombies() >= int(cc.get("max", 3)):
		return
	var z: Zombie = fc.call("spawn_climber", v3(pts[_rng.randi_range(0, pts.size() - 1)])) as Zombie
	if z != null:
		z.set_meta("wing_climber", true)
		climbers_spawned += 1


func _wing_zombies() -> int:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return 0
	var n: int = 0
	for z: Zombie in dir.active_zombies():
		if z.is_active() and on_deck(cfg.get("segments", []), float(cfg.get("deck_y", 3.4)), z.global_position, 1.0):
			n += 1
	return n


## Fighters strafing close: a pass low over the wing every so often while someone is out on it (FlightSky's hook).
func _tick_passes(delta: float) -> void:
	_pass_t -= delta
	if _pass_t > 0.0:
		return
	_pass_t = _rng.randf_range(float((cfg.get("fighters", {}) as Dictionary).get("every_min", 18.0)), float((cfg.get("fighters", {}) as Dictionary).get("every_max", 30.0)))
	_close_pass(v3(cfg.get("chest", [-112, 3.4, 27])))
	Net.mirror(self, &"_close_pass", [v3(cfg.get("chest", [-112, 3.4, 27]))])


func _close_pass(near: Vector3) -> void:
	var sky: Node = get_tree().get_first_node_in_group(&"flight_sky")
	if sky != null and sky.has_method("spawn_pass_near"):
		sky.call("spawn_pass_near", near)


# ---------------------------------------------------------------- turbulence and throws

## The FlightController's warning 3 s ahead of a tilt: the unclipped on the deck see it.
func on_turbulence_warning() -> void:
	if not is_open:
		return
	_warn_flash()
	Net.mirror(self, &"_warn_flash")


func _warn_flash() -> void:
	_warn_t = 3.0


## A tilt starts (host): every unclipped human on the deck goes over the side a moment in.
func on_turbulence(_seconds: float) -> void:
	if not is_open or not Net.is_authority():
		return
	var delay: float = float(cfg.get("throw_after_s", 0.9))
	var segs: Array = cfg.get("segments", [])
	var deck_y: float = float(cfg.get("deck_y", 3.4))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or not on_deck(segs, deck_y, p.global_position):
			continue
		if bool(next_state(state_of(p.player_id), "turbulence", p.is_bot)[1]):
			get_tree().create_timer(delay).timeout.connect(func() -> void:
				if is_instance_valid(p) and p.is_alive() and state_of(p.player_id) == ClipState.UNCLIPPED:
					throw_off(p, "turbulence"))


## Over the side (host decides): the tether line that is not clipped is the safety line at the hatch's foot. The
## body ends at the foot of the hatch, downed; never dead and never out of the match.
func throw_off(p: Player, why: String) -> void:
	if p == null or not Net.is_authority():
		return
	_set_state(p.player_id, ClipState.OFF_WING)
	knocked += 1
	print("[wingwalk] %s thrown off (%s)" % [p.name, why])
	if p.is_bot:
		_land_and_down(p)
	elif p.is_local or not Net.is_online():
		_land_and_down(p)
	else:
		Net.mirror(self, &"_thrown_mirror", [p.player_id])
	GLVO.say_as(p.player_id, "M4B_WING_FALL", 0.8)


func _thrown_mirror(pid: int) -> void:
	if pid != Net.local_player_id():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_local:
			_land_and_down(p)


## On the owner's machine: the body is hauled in at the hatch's foot and goes down (co-op: a real down a teammate
## revives; solo with no teammates: a scripted down that gets up after solo_down_s; the match goes on either way).
func _land_and_down(p: Player) -> void:
	p.global_position = v3(cfg.get("hatch_foot", [-40, 0.1, 43.2]))
	p.velocity = Vector3.ZERO
	p.set("_shake", 0.9)
	if p.is_local:
		AudioDirector.play_2d("player_hurt", 0.0, 0.0)
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", str(cfg.get("thrown_banner", "THROWN OFF THE WING\nthe safety line hauled you in")), 3.0)
	if GameState.god_mode and not p.is_bot:
		return   # god mode (the dev launcher, smokes): hauled in, not downed
	if GameState.is_solo() and not p.is_bot:
		solo_down(p)
	else:
		p.down()


## Solo: down on the deck for solo_down_s, then up with full health (no Second Wind spent, no game over).
func solo_down(p: Player) -> void:
	if p.downed:
		return
	p.downed = true
	p.velocity = Vector3.ZERO
	var head: Node3D = p.get("head") as Node3D
	var cam: Node3D = p.get("camera") as Node3D
	if head != null:
		var tw: Tween = p.create_tween()
		tw.tween_property(head, "position:y", 0.35, 0.6).set_trans(Tween.TRANS_QUAD)
		if cam != null:
			tw.parallel().tween_property(cam, "rotation:z", 0.5, 0.6)
	get_tree().create_timer(float((cfg.get("knock", {}) as Dictionary).get("solo_down_s", 4.0))).timeout.connect(func() -> void:
		if is_instance_valid(p) and p.downed:
			p.revive(p.player_id))


# ---------------------------------------------------------------- the local view: HUD state, wind streaks

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 11
	add_child(_hud)
	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 26)
	_hud_label.add_theme_constant_override("outline_size", 6)
	_hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hud_label.anchor_left = 0.5
	_hud_label.anchor_right = 0.5
	_hud_label.anchor_top = 0.72
	_hud_label.offset_left = -300
	_hud_label.offset_right = 300
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.visible = false
	_hud.add_child(_hud_label)


func _build_streaks() -> void:
	_streaks = CPUParticles3D.new()
	_streaks.name = "WindStreaks"
	_streaks.amount = 90
	_streaks.lifetime = 0.7
	_streaks.emitting = false
	_streaks.local_coords = false
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(9, 3, 2)
	_streaks.direction = Vector3(0, 0, -1)
	_streaks.spread = 4.0
	_streaks.gravity = Vector3.ZERO
	_streaks.initial_velocity_min = 28.0
	_streaks.initial_velocity_max = 40.0
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.015, 0.015, 1.6)
	_streaks.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.82, 0.95, 0.35)
	_streaks.material_override = m
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streaks)


func _local_player() -> Player:
	var map: Node = get_tree().current_scene
	var p: Variant = map.get("player") if map != null else null
	return p as Player if p is Player else null


func _tick_local(_delta: float) -> void:
	var p: Player = _local_player()
	if p == null or _hud_label == null:
		return
	var on: bool = p.is_alive() and on_deck(cfg.get("segments", []), float(cfg.get("deck_y", 3.4)), p.global_position)
	_hud_label.visible = on
	if _streaks != null:
		_streaks.emitting = on
		if on:
			_streaks.global_position = p.global_position + Vector3(0, 1.4, 14)
	_wind_audio(on)
	if not on:
		return
	if is_clipped(p.player_id):
		_hud_label.text = "CLIPPED"
		_hud_label.modulate = Color(0.55, 0.95, 0.6)
	else:
		var flash: bool = _warn_t > 0.0 and fmod(_warn_t, 0.4) < 0.2
		_hud_label.text = "UNCLIPPED · TURBULENCE! CLIP IN" if _warn_t > 0.0 else "UNCLIPPED · hold [%s] at a tether post" % Interactable.prompt_key(&"interact")
		_hud_label.modulate = Color(1.0, 0.35, 0.25) if flash else Color(1.0, 0.75, 0.3)


func _wind_audio(on: bool) -> void:
	if on and _wind_snd == null:
		var key: String = str(cfg.get("wind_sound", "wind_howl"))
		if not AudioDirector.has_sound(key):
			key = "kranich_wind_gust" if AudioDirector.has_sound("kranich_wind_gust") else ""
		if key != "":
			_wind_snd = AudioDirector.play_2d(key, -4.0, 0.0)
	elif not on and _wind_snd != null:
		if is_instance_valid(_wind_snd):
			_wind_snd.stop()
		_wind_snd = null


# ---------------------------------------------------------------- dev console

func _cmd(a: PackedStringArray) -> String:
	var p: Player = _local_player()
	match a[0] if a.size() > 0 else "status":
		"open":
			open_now()
		"clip":
			clip(p)
		"throw":
			throw_off(p, "console")
	return "wing walk: %s, %s, knocked %d, climbers %d" % ["open" if is_open else "shut",
		["off the wing", "UNCLIPPED", "CLIPPED"][state_of(p.player_id if p != null else 1)], knocked, climbers_spawned]
