class_name InnSurvivors
extends Node3D
## The survivors hiding upstairs at the Crossroads Inn (T-077; data: data/gravelight/map00_survivors.json, which
## documents the rules). Builds one InnSurvivor per row, keeps them out of the world until the stair door
## (`reveal_door`) is opened, then runs the host's side: who says what, which zombies go for whom (Zombie.prey), the
## armed ones' shots, downs, deaths and rises. Every change is mirrored to co-op peers (Net.mirror, _net_*), which
## apply the same state and show the same shots and lines; the zombies are the host's and replicate as usual.

const DATA_PATH: String = "res://data/gravelight/map00_survivors.json"

var cfg: Dictionary = {}
var survivors: Dictionary = {}   # id -> InnSurvivor
var revealed: bool = false
var _lure_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func load_cfg() -> Dictionary:
	return GLData.load_json(DATA_PATH)


## Pure rules (unit-tested in test_inn_survivors.gd) ------------------------------------------------------------

## Damage of one of their shots (`head`: a head hit), from the weapon's own damage.
static func shot_damage(weapon_damage: float, head: bool, a: Dictionary) -> float:
	return weapon_damage * float(a.get("damage_mult", 1.0)) * (float(a.get("head_mult", 2.0)) if head else 1.0)


## What a swipe does: "downed" for an armed survivor brought to 0, "dead" for a hiding one, "" while they stand.
static func swipe_outcome(hp_after: float, armed: bool) -> String:
	if hp_after > 0.0:
		return ""
	return "downed" if armed else "dead"


## May a zombie at `z_pos` be drawn to a survivor at `s_pos`? Same floor, within the radius, fewer than max on them.
static func may_lure(z_pos: Vector3, s_pos: Vector3, armed: bool, already: int, a: Dictionary) -> bool:
	if already >= int(a.get("max_lured", 2)):
		return false
	if absf(z_pos.y - s_pos.y) > float(a.get("lure_floor_dy", 1.6)):
		return false
	var r: float = float(a.get("lure_radius", 8.0)) if armed else float(a.get("lure_radius_hidden", 4.5))
	return Vector2(z_pos.x - s_pos.x, z_pos.z - s_pos.z).length() <= r


## Does the fallen rise now? After rise_after seconds, only while a round is on.
static func rises_now(dead_t: float, round_on: bool, a: Dictionary) -> bool:
	return round_on and dead_t >= float(a.get("rise_after", 5.0))


# ================================================================== setup

func _ready() -> void:
	cfg = load_cfg()
	var map: MapRoot = _map()
	if cfg.is_empty() or map == null or String(map.map_id) != str(cfg.get("map", "")):
		set_physics_process(false)
		return
	_rng.seed = 7700
	for r: Dictionary in cfg.get("survivors", []):
		var s: InnSurvivor = InnSurvivor.new()
		s.setup(r, self)
		add_child(s)
		s.hp = float((cfg.get("ally", {}) as Dictionary).get("hidden_hp", 90.0))
		survivors[s.sid] = s
		PeopleBodies.warm_risen(s.sid, str(r.get("rise_variant", "villager")), bool(r.get("female", false)))   # (not in the tick they rise)
	GLBus.door_opened.connect(_on_door_opened)
	GLBus.weapon_fired.connect(_on_weapon_fired)


func _map() -> MapRoot:
	var n: Node = get_parent()
	while n != null:
		if n is MapRoot:
			return n as MapRoot
		n = n.get_parent()
	return null


func director() -> ZombieDirector:
	var map: Node = _map()
	return map.get_node_or_null("ZombieDirector") as ZombieDirector if map != null else null


func ally() -> Dictionary:
	return cfg.get("ally", {})


func _on_door_opened(door_id: StringName, _by: int) -> void:
	if String(door_id) == str(cfg.get("reveal_door", "")) and Net.is_authority():
		reveal()


## The stair door is open: they are in the room, scared (host; mirrored).
func reveal() -> void:
	if revealed:
		return
	revealed = true
	Net.mirror(self, &"_net_reveal")
	for s: InnSurvivor in survivors.values():
		set_state(s, InnSurvivor.State.HIDING)
		s.next_scared = _rng.randf_range(2.0, 5.0)


func _net_reveal() -> void:
	revealed = true


# ================================================================== state changes (host -> everyone)

func set_state(s: InnSurvivor, st: InnSurvivor.State) -> void:
	s.apply_state(st, s.global_position, s.rotation.y)
	Net.mirror(self, &"_net_state", [s.sid, int(st), s.global_position, s.rotation.y])


func _net_state(id: String, st: int, at: Vector3, yaw: float) -> void:
	var s: InnSurvivor = survivors.get(id) as InnSurvivor
	if s != null:
		s.apply_state(st as InnSurvivor.State, at, yaw)


## A player paid: the survivor takes the rifle, stands and goes to their post.
func arm(s: InnSurvivor, pid: int) -> void:
	if s.state != InnSurvivor.State.HIDING:
		return
	s.armed_by = pid
	s.hp = float(ally().get("hp", 220.0))
	set_state(s, InnSurvivor.State.WALKING)
	say(s, "armed")
	print("[survivors] %s armed by player %d" % [s.sid, pid])


func revive(s: InnSurvivor, _pid: int) -> void:
	if s.state != InnSurvivor.State.DOWNED:
		return
	s.hp = float(ally().get("hp", 220.0)) * float(ally().get("revive_hp_frac", 0.6))
	set_state(s, InnSurvivor.State.ARMED)


func on_struck(s: InnSurvivor, by: Node) -> void:
	s.body.struck(by)
	Net.mirror(self, &"_net_hit", [s.sid])
	var out: String = swipe_outcome(s.hp, s.state != InnSurvivor.State.HIDING)
	if out == "downed":
		s.bleed_left = float(ally().get("bleed_seconds", 25.0))
		set_state(s, InnSurvivor.State.DOWNED)
		say(s, "downed")
	elif out == "dead":
		kill(s)
	elif _rng.randf() < 0.5:
		say(s, "hurt")


func _net_hit(id: String) -> void:
	var s: InnSurvivor = survivors.get(id) as InnSurvivor
	if s != null:
		s.body.struck(null)


func kill(s: InnSurvivor) -> void:
	if s.state == InnSurvivor.State.DEAD or s.state == InnSurvivor.State.RISEN:
		return
	set_state(s, InnSurvivor.State.DEAD)
	say(s, "death")
	AudioDirector.play_3d("player_hurt", s.global_position + Vector3.UP * 1.0, 1.0)
	Net.sfx_all("player_hurt", s.global_position + Vector3.UP * 1.0, 1.0)
	print("[survivors] %s died (%s)" % [s.sid, "armed" if s.armed_by > 0 else "hiding"])


## The fallen (host, every frame): the warning a beat before, then the rise. Never silent.
func tick_dead(s: InnSurvivor) -> void:
	var a: Dictionary = ally()
	var round_on: bool = RoundManager.state == RoundManager.State.ROUND
	if not s.warned() and round_on and s.dead_t >= float(a.get("rise_after", 5.0)) - float((cfg.get("squad_turn_line", {}) as Dictionary).get("delay", 1.2)) - 0.8:
		s.set_warned()
		_turn_warning(s)
		Net.mirror(self, &"_net_turn_warning", [s.sid])
	if rises_now(s.dead_t, round_on, a):
		_rise(s)


func _turn_warning(s: InnSurvivor) -> void:
	AudioDirector.play_3d("zombie_groan", s.global_position + Vector3.UP * 0.5, 3.0, 0.1)
	var who: String = str(s.row.get("name", s.display)).get_slice(" ", 0)
	GLBus.vo_line_started.emit(&"SURV_TURNING", StringName(s.display), "[%s is turning]" % who, 2.5)
	if Net.is_authority():
		var sq: Dictionary = cfg.get("squad_turn_line", {})
		get_tree().create_timer(0.4).timeout.connect(func() -> void: GLVO.squad_say(str(sq.get("category", "INN_SURV_TURN")), 1.0))


func _net_turn_warning(id: String) -> void:
	var s: InnSurvivor = survivors.get(id) as InnSurvivor
	if s != null:
		_turn_warning(s)


func _rise(s: InnSurvivor) -> void:
	var dir: ZombieDirector = director()
	var at: Vector3 = s.global_position
	var yaw: float = s.rotation.y
	set_state(s, InnSurvivor.State.RISEN)
	if dir == null:
		return
	var spec: Dictionary = RoundManager.take_extra_spawn()
	spec["variant"] = str(s.row.get("rise_variant", "villager"))
	spec["female"] = bool(s.row.get("female", false))
	var z: Zombie = dir.activate_reserved(spec, at)
	if z == null:
		RoundManager.release_alive(1)
		return
	z.global_position = at
	z.rotation.y = yaw
	PeopleBodies.dress_risen(z, s.sid)   # T-092: the same person gets up
	z.rise_from_floor(float(ally().get("rise_getup_seconds", 2.4)))
	s.risen_zombie = z
	print("[survivors] %s rose" % s.sid)


## One shot (host): a hit roll, the damage to the zombie (no Scrip: by_player 0), the visuals for everyone.
func shoot(s: InnSurvivor, z: Zombie) -> void:
	var a: Dictionary = ally()
	var w: Dictionary = (GLData.table("weapons").get("weapons", {}) as Dictionary).get(str((cfg.get("arm", {}) as Dictionary).get("weapon", "kar98k")), {})
	var aim: Vector3 = z.global_position + Vector3.UP * 1.3
	var hit: bool = _rng.randf() < float(a.get("hit_chance", 0.8))
	var head: bool = hit and _rng.randf() < float(a.get("head_chance", 0.3))
	var to: Vector3 = aim + (Vector3.ZERO if hit else Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.3, 0.6), _rng.randf_range(-0.8, 0.8)))
	s.show_shot(to)
	Net.mirror(self, &"_net_shot", [s.sid, to])
	if hit and z.is_active():
		if z.take_damage(shot_damage(float(w.get("damage", 100.0)), head, a), &"head" if head else &"torso", StringName(str((cfg.get("arm", {}) as Dictionary).get("weapon", "kar98k"))), 0, &"bullet"):
			s.kills += 1
	if s.fight_line_ready() and _rng.randf() < float(a.get("fight_line_chance", 0.25)):
		say(s, "fight")


func _net_shot(id: String, to: Vector3) -> void:
	var s: InnSurvivor = survivors.get(id) as InnSurvivor
	if s != null:
		s.show_shot(to)


# ================================================================== the host's loop: lines and lures

func _physics_process(delta: float) -> void:
	if not revealed or not Net.is_authority():
		return
	_lure_t -= delta
	if _lure_t <= 0.0:
		_lure_t = float(ally().get("lure_every", 0.4))
		_lure()
	for s: InnSurvivor in survivors.values():
		if s.state != InnSurvivor.State.HIDING:
			continue
		s.next_scared -= delta
		if s.next_scared <= 0.0 and _player_near(s):
			var ev: Array = ally().get("scared_every", [9.0, 15.0])
			s.next_scared = _rng.randf_range(float(ev[0]), float(ev[1]))
			if not s.said_reveal:
				s.said_reveal = true
				say(s, "reveal")
			else:
				say(s, "scared")


func _player_near(s: InnSurvivor) -> bool:
	var r: float = float(ally().get("line_near", 7.0))
	var map: MapRoot = _map()
	if map == null:
		return false
	for p: Player in map.players.values():
		if is_instance_valid(p) and p.is_alive() and absf(p.global_position.y - s.global_position.y) < 2.0 and p.global_position.distance_to(s.global_position) <= r:
			return true
	return false


func _lured_on(s: InnSurvivor) -> Array[Zombie]:
	var out: Array[Zombie] = []
	var dir: ZombieDirector = director()
	if dir == null:
		return out
	for z: Zombie in dir.active_zombies():
		if z.prey == s:
			out.append(z)
	return out


## Zombies upstairs that are chasing someone go for a survivor close by instead (Zombie.prey).
func _lure() -> void:
	var dir: ZombieDirector = director()
	if dir == null:
		return
	var a: Dictionary = ally()
	var counts: Dictionary = {}
	var zs: Array[Zombie] = dir.active_zombies()
	for z: Zombie in zs:
		if z.prey is InnSurvivor:
			counts[z.prey] = int(counts.get(z.prey, 0)) + 1
	for z2: Zombie in zs:
		if z2.prey != null or z2.state != Zombie.State.CHASE:
			continue
		var best: InnSurvivor = null
		var best_d: float = INF
		for s: InnSurvivor in survivors.values():
			if not s.is_catchable():
				continue
			if not may_lure(z2.global_position, s.global_position, s.state != InnSurvivor.State.HIDING, int(counts.get(s, 0)), a):
				continue
			var d: float = z2.global_position.distance_squared_to(s.global_position)
			# a player right on top of the zombie keeps it
			if z2.target != null and is_instance_valid(z2.target) and z2.global_position.distance_squared_to(z2.target.global_position) < minf(d, 2.25):
				continue
			if d < best_d:
				best = s
				best_d = d
		if best != null:
			z2.prey = best
			counts[best] = int(counts.get(best, 0)) + 1


## Gunfire: a hiding survivor nearby ducks (every peer sees its own); the host may give it a line.
func _on_weapon_fired(_pid: int, _w: StringName, _up: bool, origin: Vector3, _dir: Vector3) -> void:
	if not revealed:
		return
	for s: InnSurvivor in survivors.values():
		if s.on_gunfire(origin) and Net.is_authority() and _rng.randf() < 0.5:
			say(s, "flinch")


# ================================================================== lines

## A survivor's line from their `lines` table (host; mirrored so every peer hears the same one).
func say(s: InnSurvivor, kind: String) -> void:
	var pool: Array = (s.row.get("lines", {}) as Dictionary).get(kind, [])
	if pool.is_empty():
		return
	var id: String = str(pool[_rng.randi_range(0, pool.size() - 1)])
	_say_line(s, id)
	Net.mirror(self, &"_net_say", [s.sid, id])


func _net_say(sid_: String, id: String) -> void:
	var s: InnSurvivor = survivors.get(sid_) as InnSurvivor
	if s != null:
		_say_line(s, id)


## The subtitle under their name, and the baked voice at them when there is one.
func _say_line(s: InnSurvivor, line_id: String) -> void:
	var rec: Dictionary = GLVO.lines.get(line_id, {})
	if rec.is_empty():
		return
	var text: String = GLVO.strip_tags(str(rec.get("text", "")))
	var dur: float = GLVO.duration_for(text, GLVO.rules)
	var path: String = GLVO.audio_path(StringName(line_id))
	GLVO.when_ready(path, _voice_line.bind(s, line_id, text, dur, path))   # T-265: when its file is in memory


func _voice_line(who: Variant, line_id: String, text: String, dur: float, path: String) -> void:
	if not is_instance_valid(who):
		return   # (gone while the file loaded)
	var s: InnSurvivor = who as InnSurvivor
	if path != "":
		var stream: AudioStream = GLVO.load_stream(path)
		if stream != null:
			var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			p.bus = GLVO.bus_for_line(StringName(line_id))   # T-205
			p.stream = stream
			p.unit_size = 5.0
			p.max_distance = 40.0
			p.position = Vector3(0, 1.0, 0)
			s.add_child(p)
			p.play()
			p.finished.connect(p.queue_free)
			dur = maxf(dur, stream.get_length())
	GLBus.vo_line_started.emit(StringName(line_id), StringName(s.display), text, dur)
