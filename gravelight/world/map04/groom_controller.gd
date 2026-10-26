class_name GroomController
extends Node3D
## Map 4 Act III's systems (UPDATE 07, docs/MAP4_FERNFLUG.md §5; data map04c.json "groom"):
##   · the American and desert dead, as kits on pooled Gängers the controller tags on spawn (no new pooled kind):
##     BURROWERS rise at the lakebed's burrow points (ground spawns the controller walks toward the players every
##     `relocate_every` s, so they erupt beside you; the staged rise is the tell, hitboxes off until the head is out);
##     CANARIES (the lab and the hangar from act round 3: health x1.3, torso x1.5, a glass hood; a head kill
##     releases a GasCloud); JUMPJOCKEYS (the radar tower and the silo from act round 4: health x1.2, a jump rig;
##     near a launch point they leap `air_seconds` at a player: shot in the air they fall and die, a landing
##     staggers everyone within `land_radius`); BACKORDERS (from act round 5 once the relay coil is taken, max 2:
##     phased = immune and through walls, solid for `solid_seconds` to attack, forced solid by the Lodestone's lift;
##     150 Scrip)
##   · the special round DUST STORM (the director's `special_handler`): the fog closes in, Burrowers double, a
##     Resupply at the last burrow on the clear
##   · the wreck's fire (a damage zone that moves with the wind), the Lodestone parts' seeded spots when no quest
##     seeds them, the story lines (Dee, Hale, the crate, the power, the first of each enemy), Dee's free side door,
##     and the act's round-clock fallback: on `rocket_fallback_round` the key, the burn and the rocket are given
## Pure rules are static for the tests.

var cfg: Dictionary = {}
var events: Dictionary = {}
var director: ZombieDirector = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tagged: Dictionary = {}          # Zombie -> "burrower" | "canary" | "jumpjockey" | "backorder"
var jj: Dictionary = {}              # Zombie -> {cd, airborne, hp0, air_t}
var bo: Dictionary = {}              # Zombie -> {phased, solid_t, stamp}
var counts: Dictionary = {"burrower": 0, "canary": 0, "jumpjockey": 0, "backorder": 0}   # ever tagged (the smoke)
var _first: Dictionary = {}
var _pending_limb: StringName = &""
var _burrow_t: float = 0.0
var _burrow_home: Dictionary = {}    # spawn -> home position
var _fire_i: int = 0
var _fire_t: float = 0.0
var _dust_on: bool = false
var _dust_t: float = 0.0
var _env: Environment = null
var _env_base: Dictionary = {}
var _kill_plane_before: float = -15.0
var parts_seeded: Dictionary = {}    # part id -> spot id (when the controller seeded them)


# ---------------------------------------------------------------- pure rules

## A burrow point near `player_pos`: `min_m..max_m` away on a seeded bearing, kept inside the lakebed box.
static func burrow_point(player_pos: Vector3, home: Vector3, rng: RandomNumberGenerator, min_m: float, max_m: float, box_min: Vector3, box_max: Vector3) -> Vector3:
	var a: float = rng.randf_range(0.0, TAU)
	var d: float = rng.randf_range(min_m, max_m)
	var p: Vector3 = Vector3(player_pos.x + cos(a) * d, home.y, player_pos.z + sin(a) * d)
	p.x = clampf(p.x, box_min.x + 2.0, box_max.x - 2.0)
	p.z = clampf(p.z, box_min.z + 2.0, box_max.z - 2.0)
	return p


## The leap: a flat velocity that covers `from`→`to` in `air_s` (capped at `max_mps`), with the rise that lands
## after `air_s` under `g`.
static func leap_velocity(from: Vector3, to: Vector3, air_s: float, g: float = 9.8, max_mps: float = 14.0) -> Vector3:
	var d: Vector3 = to - from
	d.y = 0.0
	var flat: Vector3 = Vector3.ZERO if d.length() < 0.01 else d / maxf(0.2, air_s)
	if flat.length() > max_mps:
		flat = flat.normalized() * max_mps
	return Vector3(flat.x, 0.5 * g * air_s, flat.z)


## Whether a spawn in `zone` on act round `ar` becomes this kind (the roll against the chance, the cap).
static func kind_roll(kind_cfg: Dictionary, zone: String, ar: int, roll: float, active: int) -> bool:
	if ar < int(kind_cfg.get("from_act_round", 99)):
		return false
	var zones: Array = kind_cfg.get("zones", [])
	if not zones.is_empty() and not zones.has(zone):
		return false
	if active >= int(kind_cfg.get("max_active", 99)):
		return false
	return roll < float(kind_cfg.get("chance", 0.0))


## The Backorders need the relay coil taken (either flag) and their act round.
static func backorder_allowed(kind_cfg: Dictionary, ar: int, flags: Dictionary, active: int) -> bool:
	if ar < int(kind_cfg.get("from_act_round", 5)) or active >= int(kind_cfg.get("max_active", 2)):
		return false
	return flags.has(StringName(str(kind_cfg.get("requires_flag", "part_ls_part_coil")))) or flags.has(&"relay_coil_taken")


## The round-clock fallback: the rocket is given on `fallback_round` (act-relative) when it isn't ready.
static func rocket_fallback_due(ar: int, fallback_round: int, flags: Dictionary) -> bool:
	return ar >= fallback_round and not flags.has(&"rocket_ready")


# ---------------------------------------------------------------- setup

func _ready() -> void:
	name = "GroomController"
	add_to_group(&"groom_controller")
	_rng.randomize()
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.enemy_spawned.connect(_on_enemy_spawned)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at)
	GLBus.flag_changed.connect(_on_flag_changed)
	GLBus.zone_opened.connect(_on_zone_opened)
	GLBus.intel_found.connect(_on_intel_found)
	GLBus.power_activated.connect(_on_power)
	GLBus.buildable_completed.connect(_on_built)
	GLBus.weapon_acquired.connect(_on_weapon)
	GLBus.boss_spawned.connect(_on_boss)
	_kill_plane_before = Zombie.kill_plane_y


func _exit_tree() -> void:
	Zombie.kill_plane_y = _kill_plane_before


func _on_match_started(_map: StringName) -> void:
	cfg = _load_cfg()
	events = cfg.get("events", {})
	Zombie.kill_plane_y = float(cfg.get("kill_plane_y", -25.0))
	for n: Node in get_tree().get_nodes_in_group(&"director"):
		director = n as ZombieDirector
	if director != null and str(RoundManager.act_block_of(GameState.map_id).get("special_kind", "")) == "dust_storm":
		director.special_handler = self
	for sp: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		if sp.name.begins_with("Catwalk_B_LAKEBED"):
			_burrow_home[sp] = (sp as Node3D).global_position
	(func() -> void:
		_seed_parts()
		_vo("OPR_M4C_ARRIVE_01")
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			_squad_each("M4C_ARRIVE_01")
			_vo("OPR_M4C_ARRIVE_02"))
		get_tree().create_timer(14.0).timeout.connect(func() -> void: _vo("DEE_M4C_RADIO_01"))).call_deferred()


func _load_cfg() -> Dictionary:
	var path: String = "res://data/gravelight/%s.json" % String(GameState.map_id).get_slice("_", 0)
	if not FileAccess.file_exists(path):
		return {}
	return GLData.load_json(path).get("groom", {})


## The Lodestone's parts: the quest's `ls_parts` pick when it is loaded, else one of each part's spots, seeded.
func _seed_parts() -> void:
	if QuestManager.random_value(&"map04_kuendigung", "ls_parts") != null:
		return
	var by_part: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
		var bp: BuildablePart = n as BuildablePart
		if bp == null or bp.buildable_id != &"lodestone":
			continue
		if not by_part.has(bp.part_id):
			by_part[bp.part_id] = []
		(by_part[bp.part_id] as Array).append(bp)
	for pid: Variant in by_part.keys():
		var spots: Array = by_part[pid]
		var live: int = _rng.randi_range(0, spots.size() - 1)
		for i: int in spots.size():
			(spots[i] as BuildablePart)._set_live(i == live and not BuildablePart.has_part(pid))
		parts_seeded[pid] = (spots[live] as BuildablePart).spot_id
	if not parts_seeded.is_empty():
		print("[m4c] Lodestone parts seeded by the controller: %s" % str(parts_seeded))


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


func _banner(text: String, hold: float = 3.0) -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", text, hold)


func _vo(id: String) -> void:
	if id != "" and Net.is_authority():
		GLVO.play(StringName(id))


func _squad(character: StringName, id: String) -> void:
	if GameState.has_trait(character):
		_vo(id)


## One line per character in the match, `<SPK>_<suffix>` (DUT/PEG/DEA/WRN/JAK), in the match's order.
func _squad_each(suffix: String) -> void:
	for c: Array in [[&"dutch", "DUT"], [&"peg", "PEG"], [&"deacon", "DEA"], [&"wren", "WRN"], [&"jakub", "JAK"]]:
		if GameState.has_trait(c[0]):
			var id: String = "%s_%s" % [c[1], suffix]
			if GLData.load_json("res://data/gravelight/vo/lines.json").has(id):
				_vo(id)


func _once(key: String) -> bool:
	if _first.has(key):
		return false
	_first[key] = true
	return true


# ---------------------------------------------------------------- rounds

func _on_round_started(_r: int, special: bool) -> void:
	if cfg.is_empty() or not Net.is_authority():
		return
	var ar: int = RoundManager.act_round()
	if rocket_fallback_due(ar, int(events.get("rocket_fallback_round", 9)), GameState.flags):
		for f: StringName in [&"ignition_key", &"burn_known", &"rocket_key_turned", &"rocket_ready"]:
			GameState.set_flag(f)
		if not (GameState.flags.get(&"burn", []) is Array) or (GameState.flags.get(&"burn", []) as Array).is_empty():
			GameState.flags[&"burn"] = StoryRadio.burn_numbers(ar * 7919)
		_banner("The range's own clock: the console runs the burn itself. The gantry lift is live.", 5.0)
		print("[m4c] rocket fallback on act round %d" % ar)
	if special and director != null and director.special_handler == self:
		_dust_start()


func _on_round_ended(_r: int) -> void:
	_dust_end()


func _process(delta: float) -> void:
	if cfg.is_empty() or GameState.phase != GameState.Phase.PLAYING:
		return
	_prune()
	if not Net.is_authority():
		return
	_tick_burrows(delta)
	_tick_fire(delta)
	_tick_jumpjockeys(delta)
	_tick_backorders(delta)


## Tags on zombies the pool reused for something else go away with their costume.
func _prune() -> void:
	for z: Variant in tagged.keys():
		var zz: Zombie = z as Zombie
		if zz == null or not is_instance_valid(zz) or (not zz.is_active() and zz.state != Zombie.State.DEAD):
			_untag(zz)


## The hood / rig / stamp nodes go with the tag.
func _free_costume(z: Zombie) -> void:
	for key: String in ["groom_hood", "groom_rig", "groom_stamp"]:
		if not z.has_meta(key):
			continue
		var n: Node = z.get_meta(key) as Node
		if n != null and is_instance_valid(n):
			n.queue_free()
		z.remove_meta(key)


func _untag(z: Zombie) -> void:
	if z != null and is_instance_valid(z):
		_free_costume(z)
		if bo.has(z) and bool((bo[z] as Dictionary).get("phased", false)):
			_set_phased(z, false)
		if z.has_meta("groom"):
			z.remove_meta("groom")
	tagged.erase(z)
	jj.erase(z)
	bo.erase(z)


func _active_of(kind: String) -> int:
	var n: int = 0
	for z: Variant in tagged.keys():
		if str(tagged[z]) == kind and (z as Zombie).is_active():
			n += 1
	return n


# ---------------------------------------------------------------- the spawn hook: who becomes what

func _on_enemy_spawned(enemy_id: StringName, node_id: int) -> void:
	if cfg.is_empty() or not Net.is_authority() or enemy_id != &"ganger":
		return
	var z: Zombie = instance_from_id(node_id) as Zombie
	if z == null or z is HomageBoss or tagged.has(z):
		return
	var ar: int = RoundManager.act_round()
	var zone: String = String(ZoneVolume.zone_at(get_tree(), z.global_position))
	var bc: Dictionary = cfg.get("burrower", {})
	if zone == "B_LAKEBED" and z.state == Zombie.State.EMERGE and ar >= int(bc.get("from_act_round", 1)):
		make("burrower", z)
		return
	if kind_roll(cfg.get("canary", {}), zone, ar, _rng.randf(), _active_of("canary")):
		make("canary", z)
		return
	if kind_roll(cfg.get("jumpjockey", {}), zone, ar, _rng.randf(), _active_of("jumpjockey")):
		make("jumpjockey", z)
		return
	var oc: Dictionary = cfg.get("backorder", {})
	if backorder_allowed(oc, ar, GameState.flags, _active_of("backorder")) and _rng.randf() < float(oc.get("chance", 0.2)):
		make("backorder", z)


## Turns a live Gänger into one of the act's kinds (the spawn hook, the console and the smoke).
func make(kind: String, z: Zombie) -> void:
	if z == null or not is_instance_valid(z) or tagged.has(z):
		return
	match kind:
		"burrower":
			_tag(z, "burrower")
			Effects.dirt_burst(z.global_position, "earth", 1.2, Vector3.UP, 20)
			AudioDirector.play_3d("board_slam", z.global_position, -8.0)
			if _once("burrower"):
				_vo("OPR_M4C_BURROW_01")
				_squad(&"dutch", "DUT_M4C_BURROW_01")
		"canary":
			var cc: Dictionary = cfg.get("canary", {})
			_tag(z, "canary")
			z.max_hp *= float(cc.get("health_mult", 1.3))
			z.hp = z.max_hp
			z.armor_torso_mult = float(cc.get("torso_mult", 1.5))
			var hood: Node3D = _hood()
			var head: Node3D = z.bone_attachment("Head")
			(head if head != null else z).add_child(hood)
			z.set_meta("groom_hood", hood)
			if _once("canary"):
				_vo("OPR_M4C_CANARY_01")
				_squad(&"dutch", "DUT_M4C_CANARY_01")
				_squad(&"deacon", "DEA_M4C_CANARY_01")
				_squad(&"wren", "WRN_M4C_CANARY_01")
		"jumpjockey":
			var jc: Dictionary = cfg.get("jumpjockey", {})
			_tag(z, "jumpjockey")
			z.max_hp *= float(jc.get("health_mult", 1.2))
			z.hp = z.max_hp
			var rig: Node3D = _rig()
			var spine: Node3D = z.bone_attachment("Spine")
			(spine if spine != null else z).add_child(rig)
			z.set_meta("groom_rig", rig)
			jj[z] = {"cd": float(jc.get("cooldown", 6.0)) * 0.5, "airborne": false, "hp0": z.hp, "air_t": 0.0}
			if _once("jumpjockey"):
				_vo("OPR_M4C_JUMP_01")
		"backorder":
			var oc: Dictionary = cfg.get("backorder", {})
			_tag(z, "backorder")
			var tiers: Dictionary = GLData.table("enemies")["tiers"]
			z.speed = float(tiers.get(str(oc.get("speed_tier", "walk")), 2.0))
			z.tier = StringName(str(oc.get("speed_tier", "walk")))
			var stamp: Label3D = Label3D.new()
			stamp.text = "—"
			stamp.font_size = 48
			stamp.pixel_size = 0.004
			stamp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			stamp.modulate = Color(0.85, 0.6, 1.0)
			stamp.no_depth_test = true
			stamp.position = Vector3(0, 2.0, 0)
			z.add_child(stamp)
			z.set_meta("groom_stamp", stamp)
			bo[z] = {"phased": false, "solid_t": 0.0}
			_set_phased(z, true)
			if _once("backorder"):
				_vo("OPR_M4C_BACKORDER_01")
				_squad(&"wren", "WRN_M4C_BACKORDER_01")


func _tag(z: Zombie, kind: String) -> void:
	tagged[z] = kind
	z.set_meta("groom", kind)
	counts[kind] = int(counts.get(kind, 0)) + 1


## The Canary's glass hood: a sphere round the head, lit from inside.
func _hood() -> Node3D:
	var hood: Node3D = Node3D.new()
	hood.name = "Hood"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	mi.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.5, 1.0, 0.35)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.25, 0.9)
	m.emission_energy_multiplier = 1.5
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.08, 0)
	hood.add_child(mi)
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(0.62, 0.3, 1.0)
	l.light_energy = 0.8
	l.omni_range = 2.5
	l.shadow_enabled = false
	hood.add_child(l)
	return hood


## The Jumpjockey's rig: a pack on the spine with a violet exhaust lamp.
func _rig() -> Node3D:
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	Interactable.add_box(rig, Vector3(0.36, 0.5, 0.22), Vector3(0, 0.1, 0.2), Interactable.greybox_mat(Color(0.35, 0.33, 0.3)))
	var ex: MeshInstance3D = Interactable.add_box(rig, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.2, 0.26), Interactable.greybox_mat(Color(0.6, 0.3, 1.0), 4.0))
	ex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(0.62, 0.3, 1.0)
	l.light_energy = 0.6
	l.omni_range = 2.0
	l.shadow_enabled = false
	l.position = Vector3(0, -0.2, 0.3)
	rig.add_child(l)
	return rig


# ---------------------------------------------------------------- deaths: the hood gas, the Backorder's price

func _on_enemy_killed(_enemy_id: StringName, limb: StringName, _weapon_id: StringName, _by_player: int) -> void:
	_pending_limb = limb


func _on_enemy_killed_at(_enemy_id: StringName, pos: Vector3, by_player: int) -> void:
	if cfg.is_empty():
		return
	var limb: StringName = _pending_limb
	_pending_limb = &""
	for z: Variant in tagged.keys():
		var zz: Zombie = z as Zombie
		if zz == null or not is_instance_valid(zz) or zz.has_meta("groom_dead"):
			continue   # the signals come before the state turns DEAD: the position is the match
		if zz.global_position.distance_to(pos) > 0.6:
			continue
		zz.set_meta("groom_dead", true)
		var kind: String = str(tagged[z])
		if kind == "canary" and limb == &"head":
			GasCloud.spawn(_map(), pos, cfg.get("canary", {}))
		elif kind == "backorder" and by_player > 0:
			Economy.award(by_player, int((cfg.get("backorder", {}) as Dictionary).get("kill_scrip", 150)))
		_free_costume(zz)
		if bo.has(zz) and bool((bo[zz] as Dictionary).get("phased", false)):
			_set_phased(zz, false)
		return


# ---------------------------------------------------------------- Burrowers: the points walk toward the players

func _tick_burrows(delta: float) -> void:
	_burrow_t -= delta
	if _burrow_t > 0.0 or director == null:
		return
	var bc: Dictionary = cfg.get("burrower", {})
	_burrow_t = float(bc.get("relocate_every", 3.0))
	var on_salt: Array[Vector3] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and ZoneVolume.zone_at(get_tree(), p.global_position) == &"B_LAKEBED":
			on_salt.append(p.global_position)
	var box_min: Vector3 = Vector3(-60, 0, -4)
	var box_max: Vector3 = Vector3(60, 0, 60)
	var i: int = 0
	for sp: Variant in _burrow_home.keys():
		var spn: Node3D = sp as Node3D
		if spn == null or not is_instance_valid(spn):
			continue
		var home: Vector3 = _burrow_home[sp]
		if on_salt.is_empty():
			spn.global_position = home
		else:
			var pp: Vector3 = on_salt[i % on_salt.size()]
			var pt: Vector3 = burrow_point(pp, home, _rng, float(bc.get("near_min_m", 6.0)), float(bc.get("near_max_m", 12.0)), box_min, box_max)
			var snapped: Vector3 = director._snap(pt)
			if snapped.distance_to(pt) < 1.5 and ZoneVolume.zone_at(get_tree(), snapped) == &"B_LAKEBED":
				spn.global_position = snapped
		i += 1


# ---------------------------------------------------------------- the wreck's fire

func _tick_fire(delta: float) -> void:
	var fc: Dictionary = cfg.get("fire", {})
	var pts: Array = fc.get("points", [])
	if pts.is_empty():
		return
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = float(fc.get("move_every", 40.0))
		_fire_i = (_fire_i + 1) % pts.size()
	var p: Array = pts[_fire_i]
	var at: Vector3 = Vector3(float(p[0]), float(p[1]), float(p[2]))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = n as Player
		if pl != null and pl.is_alive() and Vector2(pl.global_position.x - at.x, pl.global_position.z - at.z).length() <= float(fc.get("radius", 4.0)):
			pl.take_hit(float(fc.get("dps", 10.0)) * delta, self)


func fire_point() -> Vector3:
	var pts: Array = (cfg.get("fire", {}) as Dictionary).get("points", [])
	if pts.is_empty():
		return Vector3.INF
	var p: Array = pts[_fire_i]
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


# ---------------------------------------------------------------- Jumpjockeys: the leap

func _near_launch(pos: Vector3, within: float) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"launch_points"):
		if (n as Node3D).global_position.distance_to(pos) <= within:
			return true
	return false


func _tick_jumpjockeys(delta: float) -> void:
	var jc: Dictionary = cfg.get("jumpjockey", {})
	for z: Variant in jj.keys():
		var zz: Zombie = z as Zombie
		if zz == null or not is_instance_valid(zz) or not zz.is_active():
			continue
		var d: Dictionary = jj[z]
		if bool(d["airborne"]):
			d["air_t"] = float(d["air_t"]) + delta
			if zz.hp < float(d["hp0"]) - 0.5 and zz.state != Zombie.State.DEAD:
				# shot in the air: the rig fails, it falls and dies
				zz.take_damage(zz.hp + 1.0, &"torso", &"fall", 0, &"explosive", true)
				d["airborne"] = false
				continue
			if not zz.is_pushed() or float(d["air_t"]) > 3.0:
				d["airborne"] = false
				_land(zz, jc)
			continue
		d["cd"] = float(d["cd"]) - delta
		if float(d["cd"]) > 0.0 or zz.state != Zombie.State.CHASE or zz.target == null:
			continue
		var to: Vector3 = zz.target.global_position
		var dist: float = Vector2(to.x - zz.global_position.x, to.z - zz.global_position.z).length()
		if dist < float(jc.get("leap_min_m", 6.0)) or dist > float(jc.get("leap_max_m", 20.0)):
			continue
		if not _near_launch(zz.global_position, float(jc.get("launch_near_m", 6.0))) and float(d["cd"]) > -8.0:
			continue   # it waits for a launch point a while, then leaps from where it stands
		leap(zz, to)


## One leap at `to` (the console and the smoke call it too).
func leap(z: Zombie, to: Vector3) -> void:
	var jc: Dictionary = cfg.get("jumpjockey", {})
	var air: float = float(jc.get("air_seconds", 1.6))
	var v: Vector3 = leap_velocity(z.global_position, to, air)
	z.external_push(v, air + 0.2)
	if not z.is_pushed():
		return
	var d: Dictionary = jj.get(z, {"cd": 0.0, "airborne": false, "hp0": z.hp, "air_t": 0.0})
	d["airborne"] = true
	d["hp0"] = z.hp
	d["air_t"] = 0.0
	d["cd"] = float(jc.get("cooldown", 6.0))
	jj[z] = d
	AudioDirector.play_3d("zombie_sprint", z.global_position + Vector3.UP, 2.0)
	Effects.shatter(z.global_position + Vector3.UP * 0.6, Color(0.6, 0.3, 1.0), 10, 3.0)


func _land(z: Zombie, jc: Dictionary) -> void:
	Effects.dust_puff(z.global_position, "earth", 12)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: Vector3 = p.global_position - z.global_position
		if Vector2(d.x, d.z).length() <= float(jc.get("land_radius", 2.0)) and absf(d.y) < 2.0:
			p.take_hit(float(jc.get("land_damage", 30.0)), z)
			d.y = 0.0
			p.external_push((d.normalized() if d.length() > 0.1 else Vector3.FORWARD) * float(jc.get("land_push", 4.0)) + Vector3(0, 1.5, 0), 0.3, &"push")


# ---------------------------------------------------------------- Backorders: phased through the walls

func _set_phased(z: Zombie, on: bool) -> void:
	var d: Dictionary = bo.get(z, {"phased": false, "solid_t": 0.0})
	d["phased"] = on
	bo[z] = d
	z.set_physics_process(not on)
	z.collision_layer = 0 if on else Zombie.LAYER_ZBODY
	for hb: Hitbox in z._hitboxes:
		hb.collision_layer = 0 if on else Hitbox.LAYER_HITBOX
	z._set_inst("inst_tint", Color(0.55, 0.35, 1.0, 0.35) if on else Color(1.0, 0.85, 1.25, 1.0))
	var stamp: Label3D = (z.get_meta("groom_stamp") as Label3D) if z.has_meta("groom_stamp") else null
	if stamp != null and is_instance_valid(stamp):
		stamp.visible = not on
	if not on:
		AudioDirector.play_3d("bellringer_lantern", z.global_position + Vector3.UP, -4.0)


func _tick_backorders(delta: float) -> void:
	var oc: Dictionary = cfg.get("backorder", {})
	for z: Variant in bo.keys():
		var zz: Zombie = z as Zombie
		if zz == null or not is_instance_valid(zz) or not zz.is_active() or zz.state == Zombie.State.DEAD:
			continue
		var d: Dictionary = bo[z]
		if zz.is_lifted():
			if bool(d["phased"]):
				_set_phased(zz, false)
				d["solid_t"] = float(oc.get("solid_seconds", 2.5))
			continue
		if bool(d["phased"]):
			var t: Player = zz.target if zz.target != null and is_instance_valid(zz.target) and zz.target.is_alive() else zz._nearest_player()
			if t == null:
				continue
			zz.target = t
			var to: Vector3 = t.global_position
			var flat: Vector3 = Vector3(to.x - zz.global_position.x, 0, to.z - zz.global_position.z)
			var dist: float = flat.length()
			if dist > 0.05:
				var step: float = minf(dist, zz.speed * delta)
				zz.global_position += flat.normalized() * step
				zz.global_position.y = lerpf(zz.global_position.y, to.y, minf(1.0, delta * 2.0))
				zz._face(to)
			if dist <= float(oc.get("solidify_at_m", 2.2)) and director != null and director._snap(zz.global_position).distance_to(zz.global_position) < 0.8:
				_set_phased(zz, false)
				d["solid_t"] = float(oc.get("solid_seconds", 2.5))
				zz._enter(Zombie.State.CHASE)
				var stamp: Label3D = (zz.get_meta("groom_stamp") as Label3D) if zz.has_meta("groom_stamp") else null
				if stamp != null and is_instance_valid(stamp):
					stamp.text = str(Economy.get_scrip(t.player_id))
		else:
			d["solid_t"] = float(d["solid_t"]) - delta
			if float(d["solid_t"]) <= 0.0 and zz.state in [Zombie.State.CHASE, Zombie.State.ATTACK, Zombie.State.STAGGER]:
				_set_phased(zz, true)


# ---------------------------------------------------------------- DUST STORM (the special round)

func _dust_start() -> void:
	var dc: Dictionary = cfg.get("dust_storm", {})
	_dust_on = true
	_dust_t = 1.0
	_banner(str(dc.get("banner", "DUST STORM")), 4.0)
	_vo(str(dc.get("vo_start", "")))
	var root: Node = _map()
	for n: Node in root.find_children("*", "WorldEnvironment", true, false):
		_env = (n as WorldEnvironment).environment
	if _env != null:
		_env_base = {"fog": _env.fog_density, "color": _env.fog_light_color, "vol": _env.volumetric_fog_density}
		var c: Array = dc.get("fog_color", [0.78, 0.68, 0.5])
		var tw: Tween = create_tween()
		tw.tween_property(_env, "fog_density", float(dc.get("fog_density", 0.06)), 4.0)
		tw.parallel().tween_property(_env, "fog_light_color", Color(float(c[0]), float(c[1]), float(c[2])), 4.0)
		tw.parallel().tween_property(_env, "volumetric_fog_density", 0.05, 4.0)


func _dust_end() -> void:
	if not _dust_on:
		return
	_dust_on = false
	var dc: Dictionary = cfg.get("dust_storm", {})
	_vo(str(dc.get("vo_end", "")))
	if _env != null and not _env_base.is_empty():
		var tw: Tween = create_tween()
		tw.tween_property(_env, "fog_density", float(_env_base["fog"]), 3.0)
		tw.parallel().tween_property(_env, "fog_light_color", _env_base["color"], 3.0)
		tw.parallel().tween_property(_env, "volumetric_fog_density", float(_env_base["vol"]), 3.0)


## The director's special-round hook: Burrowers rise in packs at the burrow points nearest a player, twice as
## often as the normal interval; the last burrow is where the Resupply lands.
func tick_special(delta: float) -> void:
	if not _dust_on:
		_dust_start()
	if director == null:
		return
	_dust_t -= delta
	if _dust_t > 0.0 or not RoundManager.can_spawn():
		return
	var dc: Dictionary = cfg.get("dust_storm", {})
	_dust_t = float(dc.get("spawn_gap", 2.0))
	var points: Array[Node3D] = []
	for sp: Variant in _burrow_home.keys():
		if is_instance_valid(sp) and (sp as ZombieSpawn).is_active(RoundManager.current_round):
			points.append(sp as Node3D)
	if points.is_empty():
		return
	for i: int in int(dc.get("burrow_pack", 2)):
		if not RoundManager.can_spawn():
			break
		var at: Vector3 = points[_rng.randi_range(0, points.size() - 1)].global_position
		var spec: Dictionary = RoundManager.take_spawn()
		spec["variant"] = str((cfg.get("burrower", {}) as Dictionary).get("kit", "technician"))
		var z: Zombie = director._activate_at(spec, director._snap(at))
		if z == null:
			RoundManager.requeue()
			break
		director._last_bell_pos = at
		if not tagged.has(z):
			_tag(z, "burrower")
			Effects.dirt_burst(at, "earth", 1.2, Vector3.UP, 20)


# ---------------------------------------------------------------- story

func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if not bool(value) or cfg.is_empty():
		return
	match flag:
		&"dee_radio_done":
			var side: BuyDoor = get_parent().get_node_or_null("Door_Side") as BuyDoor
			if side != null and not side.is_open and Net.is_authority():
				side.open(0)
				_vo("DEE_M4C_DOOR_01")
		&"slammed_once":
			if _once("slam"):
				_vo("OPR_M4C_LODESTONE_01")


func _on_zone_opened(zone_id: StringName) -> void:
	if cfg.is_empty():
		return
	if zone_id == &"C_HANGAR" and _once("hangar"):
		_vo("HAL_M4C_GLASS_01")
		_squad(&"peg", "PEG_M4C_HALE_01")
		_vo("OPR_M4C_HALE_01")
		_squad(&"dutch", "DUT_M4C_DEE_01")
		_squad(&"deacon", "DEA_M4C_ARRIVE_01")
		_squad(&"bolt", "SPR_M4C_RELAY_01")
		_squad(&"vendelin", "VEN_M4C_CABINET_01")


func _on_intel_found(intel_id: StringName) -> void:
	if cfg.is_empty():
		return
	if intel_id == &"INT_M4_MANIFEST" and _once("manifest"):
		_squad(&"dutch", "DUT_M4C_CRATE_01")
		_squad(&"peg", "PEG_M4C_CRATE_01")
		_vo("HAL_M4C_GLASS_02")
		_squad(&"wren", "WRN_M4C_CRATE_01")
		_squad(&"dutch", "DUT_M4C_CRATE_02")
		_squad(&"peg", "PEG_M4C_CRATE_02")
	elif intel_id == &"INT_M4_PROGRAM" and _once("program"):
		_vo("HAL_M4C_GLASS_03")
		_vo("DEE_M4C_RADIO_04")


func _on_power() -> void:
	if cfg.is_empty():
		return
	_vo("DEE_M4C_POWER_01")
	_squad(&"deacon", "DEA_M4C_POWER_01")
	_vo("OPR_M4C_POWER_01")


func _on_built(buildable_id: StringName, _by: int) -> void:
	if buildable_id == &"lodestone" and _once("built"):
		_vo("DEE_M4C_LODESTONE_01")
		_squad(&"deacon", "DEA_M4C_BUILD_01")


func _on_weapon(_player: int, weapon_id: StringName, _source: StringName) -> void:
	if weapon_id == &"lodestone" and _once("lodestone"):
		_squad(&"deacon", "DEA_M4C_LODESTONE_01")


func _on_boss(enemy_id: StringName) -> void:
	if enemy_id == &"testpilot" and _once("pilot"):
		_vo("DEE_M4C_PILOT_01")
		_squad(&"dutch", "DUT_M4C_PILOT_01")
		_squad(&"peg", "PEG_M4C_PILOT_01")
		_squad(&"wren", "WRN_M4C_PILOT_01")
