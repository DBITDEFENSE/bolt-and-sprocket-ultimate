class_name HomageBoss
extends Zombie
## The homage-boss framework (HB1, docs/HOMAGE_BOSSES.md section 3.2), reused by HB2 / HB3. A homage boss runs
## on the MZ body (the shared ZombieRig skeleton, the AnimationTree, foot IK, look-at, flinches) with its own
## costume pieces on bone attachments and a HomagePoseMod layer for the shapes the shared clips don't have, and
## adds on top of Zombie:
##   - data from data/gravelight/bosses/<event>.json (`bcfg` = this boss's block, `ecfg` = the whole file);
##   - HP by player count (scaled_hp: base x (1 + 0.75 x (players - 1)), the Foreman's P_hp);
##   - per-limb multipliers in boss terms (the weapon's own limb multiplier is divided back out first) and
##     state multipliers (`damage_taken_mult()`: the Hammer's airborne mallet, Alix's grief window);
##   - Death's Door doubles the damage it takes instead of killing it outright; Blackout (kill_silently) takes a
##     quarter of its max HP, never all of it;
##   - a move clock (`bstate`, `_bt`, cooldowns that shrink with each enrage step), a telegraph light;
##   - the grab helper (one per boss, break by the grabbed player's melee mash, teammates' damage, the weak
##     point, or the time limit; nobody is re-grabbed for 4 s and a held player can't be grabbed by another boss);
##   - authored deaths (no ragdoll: the Cousins' deaths are dignified), retreat, and the title / line helpers
##     (Homage Names Real / In-World, the Likeness Sheet's defaults for unfilled placeholders).
## Bosses ignore barricades, never become crawlers, and are never culled or recycled.
## Co-op: the host simulates them; a client sees the generic puppet body (no boss presentation yet, HB1 notes).
## T-092 (UPDATE_05 section 4): the body is the cousin's modelled doll (PeopleBodies "cousin_<key>": porcelain skin,
## painted cheeks and mouth, glassy eyes, stitched seams, her period clothes as the kit) on the same skeleton, so every
## shared clip, the HomagePoseMod layer, the look-at and the hitboxes work unchanged; `modelled()` tells the
## costume code to skip the primitive clothes and hair the model now carries (props, arms and the Reach's stretch
## fillers stay). A FaceDriver blinks (Alix never does) and moves the mouth on her lines.

signal died_boss(boss: HomageBoss)

enum B { ARRIVE, MOVE, TELEGRAPH, ACTIVE, RECOVER, STAGGER, SPECIAL, RETREAT, GONE }

static var _mat_cache: Dictionary = {}

var boss_key: String = ""          # "hammer" / "reach" / "alix" (a key of ecfg.bosses)
var ecfg: Dictionary = {}
var bcfg: Dictionary = {}
var event: Node = null             # the CousinsRound running the encounter (null for a lone test spawn)
var enrage_steps: int = 0
var bstate: B = B.ARRIVE
var move_id: String = ""           # the move being telegraphed / active
var moves_used: Dictionary = {}    # move id -> times used (tests, the smoke)
var retreating: bool = false
var gone: bool = false             # retreated or cleaned up (not dead)
var death_pos: Vector3 = Vector3.ZERO
var _bt: float = 0.0
var _clock: float = 0.0
var _cds: Dictionary = {}
var _hit_done: bool = false
var _pose: HomagePoseMod
var _tele_light: OmniLight3D
var _grabs: Array[Dictionary] = []
var _regrab: Dictionary = {}       # pid -> clock time until which that player can't be grabbed again
var _hum_t: float = 2.0
var _hum_mute: float = 0.0
var _death_t: float = 0.0
var _parts_built: bool = false
var _retreat_t: float = 0.0
# Squad scaling (cousins.json "bots_alone"): set by the CousinsRound while no human is on their feet.
var squad_hp_mult: float = 1.0
var squad_damage_mult: float = 1.0
var squad_cd_mult: float = 1.0
var squad_speed_mult: float = 1.0
var face: FaceDriver = null


# ================================================================== statics: data, HP, names

static func cfg() -> Dictionary:
	return GLData.table("bosses/cousins")


static func likeness() -> Dictionary:
	return GLData.table("bosses/likeness")


## HP = base x (1 + step x (players - 1)); players is the round scaling's count (bots at their weight), min 1.
static func scaled_hp(base: float, players: int, step: float = 0.75) -> float:
	return base * (1.0 + step * float(maxi(1, players) - 1))


static func homage_on() -> bool:
	return bool(GLSettings.values.get("homage_bosses", true))


static func names_real() -> bool:
	return str(GLSettings.values.get("homage_names", "real")) != "world"


## "[LIKE_THIS]" is an unfilled Likeness Sheet placeholder: never shown.
static func is_placeholder(s: String) -> bool:
	return s.begins_with("[") and s.ends_with("]")


## A Likeness Sheet slot's real first name (the default while the sheet holds a placeholder).
static func real_name(slot: String) -> String:
	var b: Dictionary = (likeness().get("bosses", {}) as Dictionary).get(slot, {})
	var n: String = str(b.get("real_name", ""))
	if n == "" or is_placeholder(n):
		n = str(b.get("real_name_default", ""))
	return n


static func in_world_name(slot: String) -> String:
	var b: Dictionary = (likeness().get("bosses", {}) as Dictionary).get(slot, {})
	return str(b.get("in_world_name", slot))


## [big line, small line] for the title card and the bar: Real = "MARA" over "THE HAMMER"; In-World = the
## in-world name alone (no real name anywhere on screen, D13).
static func title_for(slot: String, real: bool) -> PackedStringArray:
	var world: String = in_world_name(slot).to_upper()
	if not real:
		return PackedStringArray([world, ""])
	return PackedStringArray([real_name(slot).to_upper(), world])


## The name a boss's subtitles carry (Homage Names).
static func speaker_name(slot: String, real: bool) -> String:
	return real_name(slot).to_upper() if real else in_world_name(slot).to_upper()


## A cached greybox material for a costume colour.
static func mat(c: Color, emit: float = 0.0, rough: float = 0.9) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%.2f" % [c.to_html(true), emit, rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mat_cache[key] = m
	return m


# ================================================================== setup

func _ready() -> void:
	super._ready()
	add_to_group(&"homage_bosses")
	if not puppet and Net.is_authority():
		GameState.set_flag(&"boss_fight", true)   # T-142: no relief squad during a boss fight
	ecfg = cfg()
	bcfg = (ecfg["bosses"] as Dictionary).get(boss_key, {})
	_pose = HomagePoseMod.new()
	_pose.name = "HomagePose"
	_skel.add_child(_pose)
	_tele_light = OmniLight3D.new()
	_tele_light.light_color = Color(0.7, 0.35, 1.0)
	_tele_light.omni_range = 4.0
	_tele_light.light_energy = 0.0
	_tele_light.shadow_enabled = false
	_tele_light.position = Vector3(0, 0.1, -0.25)
	bone_attachment("Chest").add_child(_tele_light)


## Brings the boss in at `at` with `health` (already scaled). Subclasses call this, then dress themselves.
func spawn_homage(at: Vector3, health: float) -> void:
	net_died = false
	enemy_id = StringName(str(bcfg.get("boss_id", "cousin")))
	_cfg = Zombie.kind_config(&"ganger")
	max_hp = health
	hp = health
	squad_hp_mult = 1.0
	squad_damage_mult = 1.0
	squad_cd_mult = 1.0
	squad_speed_mult = 1.0
	tier = StringName(str(bcfg.get("tier", "walk")))
	speed = float(bcfg.get("speed", 2.0))
	armor_torso_mult = 1.0
	is_crawler = false
	_reset_presentation()
	_set_crawl_pose(false)
	_apply_variant("villager")
	_female = true
	_build = "thin"
	if modelled():
		_body.mesh = PeopleBodies.mesh(person_id())
		if face == null:
			face = FaceDriver.attach(_body, person_id())
			var slot: String = {"hammer": "cousin_1", "reach": "cousin_2", "alix": "cousin_3"}.get(boss_key, "")
			if slot != "":
				face.speakers = PackedStringArray([speaker_name(slot, true), speaker_name(slot, false)])
	else:
		_body.mesh = ZombieBody.build_skinned("villager", "thin", true)
	for g: MeshInstance3D in _gear:
		g.hide()
	set_posture("none", 0.0)
	_pivot.scale = Vector3.ONE * float(bcfg.get("height", 1.0))
	_set_inst("inst_tint", Color(1.0, 1.0, 1.0, 1.0) if modelled() else Color(1.12, 1.1, 1.12, 1.0))   # porcelain pallor
	_set_inst("inst_dirt", 0.1)
	for k: String in ["glass", "glass_arm", "lantern"]:
		(_kind_nodes[k] as Node3D).hide()
	_lantern_light.light_energy = 0.0
	if not _parts_built:
		_parts_built = true
		_build_costume()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = at
	_agent.avoidance_enabled = false
	_agent.max_speed = speed
	_look.primary_limit_angle = deg_to_rad(float(bcfg.get("look_limit_deg", 75.0)))
	state = State.CHASE
	bstate = B.ARRIVE
	_bt = 0.0
	enrage_steps = 0
	retreating = false
	gone = false
	_grabs.clear()
	_cds.clear()
	_pose.hold = false
	_pose.clear()
	_pose.snap()
	_tree_locomotion(true)
	_on_spawned()


## The people id of this cousin's modelled body (T-092).
func person_id() -> String:
	return "cousin_" + boss_key


## True when the cousin wears her modelled body (a built GLB, not `-- --legacy-people`).
func modelled() -> bool:
	return PeopleBodies.available(person_id())


## Subclass hooks.
func _build_costume() -> void:
	pass


func _on_spawned() -> void:
	pass


## A costume piece: [primitive, Transform3D, Color] parts, one surface per colour, on a bone attachment.
func costume(bone: String, parts: Array, emit: float = 0.0) -> MeshInstance3D:
	var at: Node3D = bone_attachment(bone)
	if at == null:
		return null
	var groups: Dictionary = {}
	for p: Array in parts:
		var c: Color = p[2]
		var key: String = c.to_html(true)
		if not groups.has(key):
			groups[key] = [c, []]
		((groups[key] as Array)[1] as Array).append(p)
	var mesh: ArrayMesh = ArrayMesh.new()
	for key: Variant in groups.keys():
		var st: SurfaceTool = SurfaceTool.new()
		for p: Array in (groups[key] as Array)[1]:
			st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat((groups[key] as Array)[0] as Color, emit))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	at.add_child(mi)
	return mi


static func cyl(top: float, bottom: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, segs: int = 10) -> Array:
	var p: Array = ZombieBody._cyl(top, bottom, h, pos, "", rot, scl, segs)
	p[2] = c
	return p


static func sph(r: float, pos: Vector3, c: Color, scl: Vector3 = Vector3.ONE, hemi: bool = false) -> Array:
	var p: Array = ZombieBody._sph(r, pos, "", scl, hemi, 10)
	p[2] = c
	return p


static func boxp(size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> Array:
	var p: Array = ZombieBody._box(size, pos, "", rot)
	p[2] = c
	return p


# ================================================================== the move clock

func speed_mult() -> float:
	return 1.0 + float(ecfg.get("enrage_speed_step", 0.2)) * float(enrage_steps)


func move_speed() -> float:
	return float(bcfg.get("speed", 2.0)) * speed_mult() * squad_speed_mult


## A move's cooldown, shortened by the enrage steps (+20% attack speed each), longer while the squad is bots alone.
func cd_for(seconds: float) -> float:
	return seconds / speed_mult() * squad_cd_mult


## Squad scaling: health, damage, cooldowns and speed for the squad fighting (1.0 = the normal scaling). Health
## keeps its fraction, so the bar doesn't jump: max_hp and hp are both rescaled from the unscaled max.
func set_squad_scale(hp_m: float, dmg_m: float, cd_m: float, spd_m: float) -> void:
	var f: float = hp_fraction()
	var base: float = max_hp / maxf(0.0001, squad_hp_mult)
	squad_hp_mult = hp_m
	squad_damage_mult = dmg_m
	squad_cd_mult = cd_m
	squad_speed_mult = spd_m
	max_hp = base * hp_m
	if hp > 0.0:
		hp = maxf(1.0, max_hp * f)


func cd_ready(id: String) -> bool:
	return float(_cds.get(id, 0.0)) <= 0.0


func set_cd(id: String, seconds: float) -> void:
	_cds[id] = cd_for(seconds)


func _go(s: B, id: String = "") -> void:
	bstate = s
	_bt = 0.0
	_hit_done = false
	if id != "":
		move_id = id
		if s == B.TELEGRAPH:
			moves_used[id] = int(moves_used.get(id, 0)) + 1


## A telegraph's length at the current enrage step (wind-ups speed up with attack speed, but never under 0.5 s).
func tele_len(seconds: float) -> float:
	return maxf(minf(0.5, seconds), seconds / speed_mult())


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	if state == State.INACTIVE:
		return
	if state == State.DEAD:
		_state_t += delta
		_update_dead(delta)
		return
	_clock += delta
	_bt += delta
	_hum_mute = maxf(0.0, _hum_mute - delta)
	for k: Variant in _cds.keys():
		_cds[k] = maxf(0.0, float(_cds[k]) - delta)
	_update_burn(delta)
	if _frost_t > 0.0:
		_frost_t -= delta
	if not is_active():
		return
	if bstate == B.RETREAT:
		_tick_retreat(delta)
		return
	target = _nearest_player()
	_grab_tick(delta)
	_tick(delta)
	_tele_light.light_energy = move_toward(_tele_light.light_energy, _tele_glow(), delta * 12.0)
	_update_audio(delta)
	_update_senses(delta)


## Subclasses: the boss's brain for one physics step.
func _tick(_delta: float) -> void:
	pass


## Telegraph light level (the "light" of pose + sound + light).
func _tele_glow() -> float:
	return 3.0 if bstate == B.TELEGRAPH else 0.0


## Walks toward `goal` on the navmesh at the boss's speed (locomotion clip time-matched by Zombie._animate).
func walk_to(goal: Vector3, delta: float, spd: float = -1.0) -> void:
	if state != State.CHASE:
		state = State.CHASE
		_tree_locomotion(true)
	_nav_move(goal, move_speed() if spd < 0.0 else spd, delta, 0.35)


func stand(delta: float, face_target: bool = true) -> void:
	_halt(delta)
	if face_target and target != null:
		_face(target.global_position)


## Plays a swing clip timed so its hit frame lands at `windup` seconds (state ATTACK keeps the tree on it).
func attack_anim(clip: String, windup: float) -> void:
	state = State.ATTACK
	_tree.set("parameters/SM/Attack/Anim/blend_position", ZombieClips.attack_index(clip))
	_tree_play("Attack", clip, ZombieClips.ATTACK_WINDUP / maxf(0.05, windup))


## Holds a still pose (the idle clip) while posing with the HomagePoseMod.
func pose_anim() -> void:
	state = State.ATTACK
	if _tree_state != "Spawn":
		_tree_play("Spawn", "idle", 1.0)


func dist_to(p: Node3D) -> float:
	return Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()


func has_los(p: Node3D, from_h: float = 1.4, to_h: float = 1.2) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * from_h,
		p.global_position + Vector3.UP * to_h, 1 | (1 << 8), [get_rid(), p.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func alive_players() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			out.append(p)
	return out


## Hits a player for `amount` (x the boss's damage_mult: Alix's double damage; x the squad scaling).
func hit_player(p: Player, amount: float) -> void:
	if p != null and p.is_alive():
		p.take_hit(amount * float(bcfg.get("damage_mult", 1.0)) * squad_damage_mult, self)


## World-space points ObservedFreeze rays at (head and chest).
func look_points() -> Array:
	var out: Array = []
	for b: String in ["Head", "Chest"]:
		var at: Node3D = bone_attachment(b)
		out.append(at.global_position if at != null else global_position + Vector3.UP * 1.4)
	return out


# ================================================================== enrage, retreat

## A cousin died: one enrage step (+20% move and attack speed, stacking) and the new move it unlocks.
func enrage() -> void:
	enrage_steps += 1
	_on_enraged()


func _on_enraged() -> void:
	pass


## Leaves without dying (the fail-safe): the subclass may play its exit; the base sinks out of sight.
func retreat() -> void:
	if not is_active():
		return
	retreating = true
	_release_all_grabs("retreat")
	_go(B.RETREAT)
	state = State.ATTACK
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	_on_retreat()


func _on_retreat() -> void:
	pass


func _tick_retreat(delta: float) -> void:
	_halt(delta)
	_pivot.position.y = lerpf(0.0, -2.0, clampf((_bt - 0.6) / 1.4, 0.0, 1.0))
	if _bt >= 2.2:
		_vanish()


## Out of the match without a kill event (retreated, or the round's cleanup of a body).
func _vanish() -> void:
	gone = true
	sync_fight_flag(get_tree(), self)
	_release_all_grabs("gone")
	bstate = B.GONE
	deactivate()
	if director != null:
		director.call("on_zombie_returned", self)


## T-142: GameState's `boss_fight` flag = any homage boss still in the fight (not `leaving`, not gone, not dead).
static func sync_fight_flag(tree: SceneTree, leaving: Node) -> void:
	if tree == null or not Net.is_authority():
		return
	var on: bool = false
	for n: Node in tree.get_nodes_in_group(&"homage_bosses"):
		var b: HomageBoss = n as HomageBoss
		if b != null and b != leaving and not b.gone and not b.puppet and b.state != State.DEAD and b.state != State.INACTIVE:
			on = true
	if GameState.has_flag(&"boss_fight") != on:
		GameState.set_flag(&"boss_fight", on)


## The round's cleanup: a body (or anything left) goes away now.
func cleanup() -> void:
	if state == State.INACTIVE:
		return
	_vanish()


# ================================================================== damage

## The weapon's default limb multiplier (weapons.json default_limb_mults): divided back out of hitscan hits so
## the boss's own table decides (a head shot: weapon x4 -> boss x2; the wrist / palm are not in the weapon table).
static func weapon_limb_mult(limb: StringName) -> float:
	return float((GLData.table("weapons").get("default_limb_mults", {}) as Dictionary).get(String(limb), 1.0))


func limb_mult(limb: StringName) -> float:
	return float((bcfg.get("limb_mult", {}) as Dictionary).get(String(limb), 1.0))


## State multipliers (the Hammer's airborne mallet, Alix's grief window). 1.0 by default.
func damage_taken_mult() -> float:
	return 1.0


## Boss terms for one hit (pure, so it can be tested): the weapon's limb multiplier is replaced by the boss's,
## then the state multiplier, then Death's Door doubles it.
static func boss_damage(amount: float, limb: StringName, kind: StringName, boss_limb_mult: float, state_mult: float, deaths_door: bool) -> float:
	var a: float = amount
	if kind == &"bullet":
		a = a / maxf(0.01, weapon_limb_mult(limb)) * boss_limb_mult
	elif limb == &"wrist" or limb == &"palm":
		a *= boss_limb_mult
	a *= state_mult
	if deaths_door and kind != &"world":
		a *= 2.0
	return a


func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	if puppet:
		return _puppet_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)
	var side: String = _hit_side(limb)
	last_hit_bone = ""
	if not is_active() or retreating:
		return false
	var dmg: float = boss_damage(amount, limb, kind, limb_mult(limb), damage_taken_mult(), GameState.has_flag(&"deaths_door"))
	hp -= dmg
	GLBus.enemy_damaged.emit(enemy_id, limb, dmg, by_player)
	if kind == &"bullet":
		AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.2, 0.0, 0.0)
	_grab_damage(dmg, limb, by_player, kind)
	_on_damaged(dmg, limb, by_player, kind)
	if hp <= 0.0:
		hp = 0.0
		_boss_die(limb, weapon_id, by_player, kind)
		return true
	if by_player > 0 and kind != &"fire":
		Economy.award(by_player, int(GLData.table("economy")["hit_nonlethal"]))
	if kind != &"fire" and kind != &"world":
		_play_flinch(limb, side)
	return false


func _on_damaged(_amount: float, _limb: StringName, _by_player: int, _kind: StringName) -> void:
	pass


func hp_fraction() -> float:
	return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)


func become_crawler() -> void:
	pass


func recycle() -> void:
	pass


func force_stagger() -> void:
	pass


## Blackout and the console's kill_all: a boss shrugs off an instant kill (a quarter of its max HP instead).
func kill_silently() -> void:
	if not puppet and is_active():
		take_damage(max_hp * 0.25, &"torso", &"none", 0, &"world")


## Tests / dev: dies now (counts as a kill by `by_player`).
func debug_kill(by_player: int = 1) -> void:
	if is_active():
		take_damage(hp + max_hp + 1.0, &"torso", &"debug", by_player, &"world")


func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, _kind: StringName) -> void:
	state = State.DEAD
	_state_t = 0.0
	_death_t = 0.0
	bstate = B.GONE
	death_pos = global_position
	collision_layer = 0
	collision_mask = LAYER_WORLD
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	velocity = Vector3.ZERO
	_safe_vel = Vector3.ZERO
	_release_all_grabs("death")
	_tele_light.light_energy = 0.0
	var scrip: int = int(bcfg.get("kill_scrip_per_player", 0))
	if scrip > 0:
		for pid: int in GameState.player_ids:
			Economy.grant(pid, scrip)
	_look.active = false
	_modifier.ik_weight = 0.0
	_pose.hold = false
	GLBus.enemy_killed.emit(enemy_id, &"head" if limb == &"head" else limb, weapon_id, by_player)
	GLBus.enemy_killed_at.emit(enemy_id, global_position, by_player)
	_start_authored_death()
	sync_fight_flag(get_tree(), self)
	died_boss.emit(self)
	# the encounter hears it first (the last cousin's clear and rewards), then the round count: her slot can be
	# the one that ends the round
	if event != null and event.has_method("on_cousin_died"):
		event.call("on_cousin_died", self)
	RoundManager.on_zombie_died()


## Subclasses: the death pose (default: the knee clip, then held).
func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)


## The body stays (Alix holds a dead cousin's hand) until the round's cleanup, or 120 s as a safety.
func _update_dead(delta: float) -> void:
	_death_t += delta
	_death_tick(delta)
	if _death_t > _hold_after() and not _pose.hold:
		_pose.hold = true
	if _death_t > 120.0:
		_vanish()


func _death_tick(_delta: float) -> void:
	pass


## When the death pose freezes (the doll stillness), seconds after the death.
func _hold_after() -> float:
	return ZombieClips.DEATH_SECONDS + 0.1


# ================================================================== grabs (section 3.6)

## True when `p` may be grabbed: alive, not held by anyone, not inside the 4 s re-grab lock.
func can_grab(p: Player) -> bool:
	if p == null or not p.is_alive():
		return false
	if float(_regrab.get(p.player_id, -INF)) > _clock:
		return false
	var st: Dictionary = ecfg.get("status", {})
	if p.has_status(StringName(str(st.get("grab", "boss_grab")))) or p.has_status(StringName(str(st.get("held", "held_hand")))):
		return false
	for g: Dictionary in _grabs:
		if g["p"] == p:
			return false
	return true


## Starts a grab. need: {"mash": presses, "team": damage by teammates, "weak": damage to the weak point,
## "max": seconds}. weak_limbs: the hitbox limbs that count as the grabbing limb / weak point.
func grab_start(p: Player, kind: String, need: Dictionary, weak_limbs: Array, status_key: String = "grab") -> Dictionary:
	var g: Dictionary = {"p": p, "pid": p.player_id, "kind": kind, "t": 0.0, "max": float(need.get("max", 6.0)),
		"mash": 0, "mash_need": int(need.get("mash", 6)), "team": 0.0, "team_need": float(need.get("team", 250.0)),
		"weak": 0.0, "weak_need": float(need.get("weak", INF)), "weak_limbs": weak_limbs,
		"status": StringName(str((ecfg.get("status", {}) as Dictionary).get(status_key, "boss_grab"))), "broken": ""}
	_grabs.append(g)
	p.apply_status(g["status"], 0.3)
	return g


func grabs() -> Array[Dictionary]:
	return _grabs


func _grab_tick(delta: float) -> void:
	for g: Dictionary in _grabs.duplicate():
		var p: Player = g["p"]
		g["t"] = float(g["t"]) + delta
		if p == null or not is_instance_valid(p) or not p.is_alive():
			grab_release(g, "down")
			continue
		if float(g["t"]) >= float(g["max"]):
			grab_release(g, "time")
			continue
		p.apply_status(g["status"], 0.3)


## Pulls a held player toward `to` at `spd` m/s (local and bot players; a remote co-op player is held, not dragged).
func drag_player(p: Player, to: Vector3, spd: float, delta: float, stop_at: float = 1.2) -> void:
	if p == null or not (p.is_local or p.is_bot):
		return
	var d: Vector3 = to - p.global_position
	d.y = 0.0
	if d.length() <= stop_at:
		return
	p.move_and_collide(d.normalized() * minf(spd * delta, d.length() - stop_at))


func _grab_damage(amount: float, limb: StringName, by_player: int, kind: StringName) -> void:
	for g: Dictionary in _grabs.duplicate():
		var weak: bool = (g["weak_limbs"] as Array).has(limb)
		if weak:
			g["weak"] = float(g["weak"]) + amount
		if by_player == int(g["pid"]):
			if kind == &"melee":
				g["mash"] = int(g["mash"]) + 1
		elif by_player > 0:
			g["team"] = float(g["team"]) + (amount if weak else amount * 0.5)
		if int(g["mash"]) >= int(g["mash_need"]):
			grab_release(g, "mash")
		elif float(g["weak"]) >= float(g["weak_need"]):
			grab_release(g, "weak")
		elif float(g["team"]) >= float(g["team_need"]):
			grab_release(g, "team")


func grab_release(g: Dictionary, reason: String) -> void:
	if not _grabs.has(g):
		return
	_grabs.erase(g)
	g["broken"] = reason
	_regrab[int(g["pid"])] = _clock + float(g.get("lock", 4.0))
	_on_grab_released(g, reason)


func _release_all_grabs(reason: String) -> void:
	for g: Dictionary in _grabs.duplicate():
		grab_release(g, reason)


func _on_grab_released(_g: Dictionary, _reason: String) -> void:
	pass


# ================================================================== presentation helpers

## A boss line: the baked VO when lines.json has it, else its subtitle (cousins.json lines) silently.
func say(line_id: String) -> void:
	if event != null and event.has_method("say"):
		event.call("say", line_id, self)


func sfx(n: String, db: float = 0.0, pitch: float = 1.0, at: Vector3 = Vector3.INF) -> AudioStreamPlayer3D:
	var pos: Vector3 = at if at != Vector3.INF else global_position + Vector3.UP * 1.4
	var p: AudioStreamPlayer3D = AudioDirector.play_3d(n, pos, db, 0.02)
	if p != null and pitch != 1.0:
		p.pitch_scale = pitch
	return p


## The humming (the trio's rhyme, the Hammer's stops before a throw): a lullaby hummed wrong, positional.
func _update_audio(delta: float) -> void:
	if not is_active() or _hum_mute > 0.0:
		return
	_hum_t -= delta
	if _hum_t <= 0.0:
		_hum_t = randf_range(2.6, 4.2)
		var dead: int = event.call("dead_count") if event != null and event.has_method("dead_count") else 0
		sfx("screamer_hum", -4.0 - 3.0 * float(dead), _hum_pitch())


func _hum_pitch() -> float:
	return 1.0


## Bosses never play the horde's footsteps on stairs etc. through the base (each one decides).
func _footstep(left: bool) -> void:
	super._footstep(left)


# ================================================================== co-op (host simulates; HB1 has no boss puppet)

func net_sub_state() -> int:
	return int(bstate)
