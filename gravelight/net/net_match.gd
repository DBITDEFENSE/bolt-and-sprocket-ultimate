class_name NetMatch
extends Node
## In-match co-op replication (M7, D-064..D-070). One per networked match, a child of the MapRoot named
## "NetMatch". Every RPC arrives through the Net autoload and is handed here.
##
## Host (authority): runs the whole simulation exactly as solo play does. Teammates are Player puppets fed
## by their owners' state; zombies, rounds, Scrip, perks, the crate, power-ups and quests are simulated here
## and replicated:
##   players  30 Hz unreliable   position / yaw / pitch / flags of every player (clients send their own)
##   zombies  20 Hz unreliable   compact per-zombie transform + state (16 bytes each) + reliable events
##                               (spawn, death variant, crawler, gone)
##   managers  5 Hz              rounds, Scrip, perks, power/zones/flags, crate spot, power-up timers,
##                               co-op life states, quest state (when it changes)
##   events   reliable           EventBus signals (RELAY), world object calls, dynamic world nodes
## Client: predicts its own movement and shooting; zombies are puppets (interpolated); a shot that hits a
## puppet sends the hit + its shot ray to the host, which validates and applies the damage; uses that change
## the world (buy, repair, revive...) are requests the host runs with that player's puppet.
##
## Local session (T-031): a solo match with AI teammates also gets a NetMatch, offline. Nothing is sent; it only
## owns the co-op life-cycle rules (CoopState: last stand, bleed-out, revives, respawns, game over, spectating)
## that the RevivePoints, the co-op HUD and the MapRoot read from `Net.session`. Bots are Players with
## `is_bot` living on this machine: decisions that would go to a client's owner are applied to them directly.

const PF_CROUCH: int = 1
const PF_SPRINT: int = 2
const PF_ADS: int = 4
const PF_RELOAD: int = 8
const PF_FLOOR: int = 16
const PF_DOWNED: int = 32
const PF_SPECTATE: int = 64
const ZF_CRAWL: int = 1
const ZF_BURN: int = 2
const ZF_ENRAGED: int = 4
const ZF_LAST: int = 8
const EXTRA_ID_BASE: int = 100

## EventBus signals the host re-emits on every client: presentation (HUD, VO, music, profile stats) listens to
## these on every peer. Signals not listed are local to each peer (hit feedback, damage taken, ammo warnings,
## spawn sounds) or replicated another way (power, zones and flags through the state snapshot).
const RELAY: PackedStringArray = [
	"round_started", "round_ended", "special_round_warning", "enemy_killed", "enemy_killed_at", "boss_spawned",
	"explosion", "player_status", "player_downed", "player_revived", "self_revive", "scrip_changed",
	"purchase_made", "purchase_denied", "door_opened", "board_repaired", "ammo_bought", "weapon_acquired",
	"perk_bought", "perk_denied", "perks_lost", "crate_opened", "crate_result", "crate_drummer", "crate_moved",
	"weapon_upgraded", "powerup_spawned", "powerup_collected", "powerup_expired", "pylon_state_changed",
	"trap_activated", "radio_tuned", "quest_step_completed", "quest_completed", "quest_step_failed",
	"item_picked_up", "buildable_completed", "cylinder_played",
]
const QUEST_RELAY: PackedStringArray = ["sequence_progress", "sequence_reset", "holdout_changed"]
## Inventory calls the host may make on an owner's real WeaponHolder (WeaponHolder._forward_op).
const INV_OPS: PackedStringArray = ["give_weapon", "set_melee", "refill_grenades", "refill_weapon", "refill_all",
	"give_tactical", "remove_current", "fit_attachment", "set_kit"]   # the last two: M1911 attachments (UPDATE_04 section 6)

## The ray of the shot being resolved right now (WeaponHolder._fire), sent with hits for host validation.
static var shot_origin: Vector3 = Vector3.ZERO
static var shot_dir: Vector3 = Vector3.ZERO

var map: MapRoot
var local_player: Player
var players: Dictionary = {}       # pid -> Player
## Companions on this machine (Jakub, U02 section 6.2): pid -> Player. Not in `players` (they are no player slot),
## but their downs, revives and bleed-outs run through the same co-op rules (CoopState.companions).
var companions: Dictionary = {}
var coop: CoopState = CoopState.new()
var begun: bool = false
var _cfg: Dictionary = {}
var _delay_ms: float = 100.0
var _p_acc: float = 0.0
var _z_acc: float = 0.0
var _s_acc: float = 0.0
var _clock: Dictionary = {}        # sender key -> clock offset (ms)
var _latest: Dictionary = {}       # host: pid -> [t, pos, yaw, pitch, flags] newest state from that client
var _loaded: Dictionary = {}       # host: pid -> true once its map is ready
var _load_wait: float = 0.0
var _inv_sig: String = ""
var _inv_ammo: int = 0
var _inv_t: float = 0.0
var _zknown: Dictionary = {}       # host: net_id -> Zombie currently replicated as alive
var _zpuppets: Dictionary = {}     # client: extra net_id -> boss puppet
var _extra_counter: int = 0
var _dyn_uid: int = 0
var _dyn: Dictionary = {}          # uid -> Node (dynamic world nodes, both sides)
var _relays: Array = []            # [Object, signal name, Callable]
var _quest_hash: int = 0
var _quest_force: float = 0.0
var _spectate_cam: Camera3D = null
var _spectate_pid: int = 0
var _shut: bool = false
## Host: payload bytes sent per stream (for the co-op smoke test's bandwidth report).
var sent_bytes: Dictionary = {"players": 0, "zombies": 0, "state": 0}


func setup(map_root: MapRoot) -> void:
	map = map_root
	_cfg = GLData.table("net")
	_delay_ms = float(_cfg.get("interp_delay_ms", 100))
	local_player = map.player
	players = map.players
	for pid: Variant in players.keys():
		coop.add(int(pid))
	if Net.is_host():
		_connect_relays()
	if Net.is_authority():
		GLBus.round_started.connect(_on_round_started_host)
	else:
		Net.roster_changed.connect(_on_roster_changed_client)


func shutdown() -> void:
	if _shut:
		return
	_shut = true
	for r: Array in _relays:
		var obj: Object = r[0]
		if obj.is_connected(StringName(r[1]), r[2] as Callable):
			obj.disconnect(StringName(r[1]), r[2] as Callable)
	_relays.clear()
	if GLBus.round_started.is_connected(_on_round_started_host):
		GLBus.round_started.disconnect(_on_round_started_host)
	if Net.roster_changed.is_connected(_on_roster_changed_client):
		Net.roster_changed.disconnect(_on_roster_changed_client)
	if Net.session == self:
		Net.session = null


func _exit_tree() -> void:
	shutdown()


func render_time_ms() -> float:
	return float(Time.get_ticks_msec()) - _delay_ms


## Maps a sender's clock to ours with the smallest offset seen (the least-delayed packet), drifting slowly.
func _to_local(key: String, remote_ms: float) -> float:
	var now: float = float(Time.get_ticks_msec())
	var off: float = now - remote_ms
	if not _clock.has(key) or off < float(_clock[key]):
		_clock[key] = off
	else:
		_clock[key] = lerpf(float(_clock[key]), off, 0.01)
	return remote_ms + float(_clock[key])


func _physics_process(delta: float) -> void:
	if _shut:
		return
	if Net.is_host():
		_host_tick(delta)
	elif Net.is_client():
		_client_tick(delta)
	else:
		_tick_bleed(delta)   # local session (bots): just the life-cycle clocks
	_update_spectate(delta)


# ================================================================== host

func _host_tick(delta: float) -> void:
	if not begun:
		_load_wait += delta
		if _all_loaded() or _load_wait > float(_cfg.get("load_timeout_seconds", 45.0)):
			_begin()
	_p_acc += delta
	if _p_acc >= 1.0 / float(_cfg.get("player_send_hz", 30)):
		_p_acc = 0.0
		_send_players()
	_z_acc += delta
	if _z_acc >= 1.0 / float(_cfg.get("zombie_send_hz", 20)):
		_z_acc = 0.0
		_send_zombies()
	_s_acc += delta
	if _s_acc >= 1.0 / float(_cfg.get("state_send_hz", 5)):
		_s_acc = 0.0
		_send_state(delta)
	_check_inventory(delta)
	_tick_bleed(delta)


func _tick_bleed(delta: float) -> void:
	if GameState.phase == GameState.Phase.PLAYING:
		var pause: bool = bool((GLData.table("player").get("downed", {}) as Dictionary).get("bleedout_pauses_while_reviving", true))
		for pid: int in coop.tick(delta, pause):
			_bleed_out(pid)


func _all_loaded() -> bool:
	for pid: int in Net.player_ids():
		if pid != Net.local_player_id() and not _loaded.has(pid):
			return false
	return true


func _begin() -> void:
	begun = true
	Net._rpc_begin.rpc()
	map.start_rounds()


func on_client_loaded(pid: int) -> void:
	_loaded[pid] = true


func on_player_left(pid: int) -> void:
	coop.remove(pid)
	_latest.erase(pid)
	var p: Player = players.get(pid) as Player
	players.erase(pid)
	GameState.player_ids.erase(pid)
	RoundManager.players = maxi(1, GameState.player_ids.size())
	if p != null and is_instance_valid(p):
		p.queue_free()
	if Net.is_host() and GameState.phase == GameState.Phase.PLAYING and coop.everyone_down():
		map._game_over()


func _send_players() -> void:
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.put_u32(Time.get_ticks_msec())
	var rows: Array = []
	for pid: Variant in players.keys():
		var p: Player = players[pid]
		if p.is_local:
			rows.append([int(pid), p.global_position, p.rotation.y, p.head.rotation.x, local_flags(p)])
		elif _latest.has(pid):
			var l: Array = _latest[pid]
			rows.append([int(pid), l[1], l[2], l[3], l[4]])
	b.put_u8(rows.size())
	for r: Array in rows:
		b.put_u8(int(r[0]))
		_put_state(b, r[1], float(r[2]), float(r[3]), int(r[4]))
	sent_bytes["players"] = int(sent_bytes["players"]) + b.data_array.size()
	Net._rpc_players.rpc(b.data_array)


static func _put_state(b: StreamPeerBuffer, pos: Vector3, yaw: float, pitch: float, flags: int) -> void:
	b.put_float(pos.x)
	b.put_float(pos.y)
	b.put_float(pos.z)
	b.put_float(yaw)
	b.put_float(pitch)
	b.put_u8(flags)


static func local_flags(p: Player) -> int:
	var f: int = 0
	if p.crouching or p.sliding:
		f |= PF_CROUCH
	if p.sprinting:
		f |= PF_SPRINT
	if p.weapons != null and p.weapons.ads_t > 0.5:
		f |= PF_ADS
	if p.weapons != null and p.weapons.is_reloading():
		f |= PF_RELOAD
	if p.is_on_floor():
		f |= PF_FLOOR
	if p.downed and not p.spectating:
		f |= PF_DOWNED
	if p.spectating:
		f |= PF_SPECTATE
	return f


func on_player_state(pid: int, data: PackedByteArray) -> void:
	var p: Player = players.get(pid) as Player
	if p == null or p.is_local or data.size() < 25:
		return
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.data_array = data
	var t: float = float(b.get_u32())
	var pos: Vector3 = Vector3(b.get_float(), b.get_float(), b.get_float())
	var yaw: float = b.get_float()
	var pitch: float = b.get_float()
	var flags: int = b.get_u8()
	if not pos.is_finite():
		return
	_latest[pid] = [t, pos, yaw, pitch, flags]
	p.interp.push(_to_local("p%d" % pid, t), pos, yaw, pitch, flags)


func on_inventory(pid: int, inv: Dictionary) -> void:
	var p: Player = players.get(pid) as Player
	if p == null or p.is_local:
		return
	_apply_inventory(p, inv)
	Net._rpc_inv_of.rpc(pid, inv)


func _apply_inventory(p: Player, inv: Dictionary) -> void:
	p.weapons.apply_net(inv)
	if p.remote_body != null:
		var w: WeaponInstance = p.weapons.current()
		p.remote_body.set_weapon(w.id if w != null else &"")


func on_fire(pid: int, data: Array) -> void:
	var p: Player = players.get(pid) as Player
	if p == null or p.is_local or data.size() < 4:
		return
	p.remote_fire(int(data[0]), StringName(str(data[1])), data[2] as Vector3, data[3] as Vector3)
	for other: int in Net.player_ids():
		if other != pid and other != Net.local_player_id():
			Net._rpc_fire_of.rpc_id(Net.peer_of(other), pid, data)


## Host-side check of a client's hit (D-066): the shooter is near where the shot started, the zombie is in
## range, and a bullet's ray passes close to where the zombie is on the host. Then the host applies it.
func on_hit(pid: int, net_id: int, dmg: float, limb: StringName, weapon_id: StringName, kind: StringName, piercing: bool, origin: Vector3, dir: Vector3) -> void:
	var shooter: Player = players.get(pid) as Player
	var z: Zombie = zombie_by_net_id(net_id)
	if shooter == null or shooter.spectating or z == null or not z.is_active():
		return
	if not validate_hit(shooter.global_position, z.global_position, origin, dir, kind, z.enemy_id == &"foreman", _cfg):
		return
	var hv: Dictionary = _cfg.get("hit_validate", {})
	dmg = clampf(dmg, 0.0, float(hv.get("max_damage_per_hit", 200000.0)))
	z.take_damage(dmg, limb, weapon_id, pid, kind, piercing)


## Pure (unit-tested): is this claimed hit plausible?
static func validate_hit(shooter_pos: Vector3, zombie_pos: Vector3, origin: Vector3, dir: Vector3, kind: StringName, big: bool, cfg: Dictionary) -> bool:
	var hv: Dictionary = cfg.get("hit_validate", {})
	if not origin.is_finite() or not dir.is_finite():
		return false
	if origin.distance_to(shooter_pos + Vector3.UP * 1.2) > float(hv.get("max_shooter_offset_m", 4.0)):
		return false
	var center: Vector3 = zombie_pos + Vector3.UP * (2.0 if big else 1.0)
	if origin.distance_to(center) > float(hv.get("max_range_m", 240.0)):
		return false
	if kind == &"bullet" and dir.length_squared() > 0.5:
		var d: Vector3 = dir.normalized()
		var to_c: Vector3 = center - origin
		var along: float = to_c.dot(d)
		if along < -1.0:
			return false
		var off: float = (to_c - d * maxf(0.0, along)).length()
		if off > float(hv.get("ray_slack_m", 2.5)) + (1.5 if big else 0.6):
			return false
	return true


func on_zombie_effect(pid: int, net_id: int, effect: StringName, a: float, b: float) -> void:
	var z: Zombie = zombie_by_net_id(net_id)
	if z == null or not z.is_active() or not players.has(pid):
		return
	match effect:
		&"ignite":
			z.ignite(a, b, pid)
		&"frost":
			z.apply_frost(a, b)
		&"stagger":
			z.force_stagger()
		&"crawl":
			z.become_crawler()


func on_shootable(pid: int, path: String, weapon_id: StringName, upgraded: bool) -> void:
	var n: Node = map.get_node_or_null(NodePath(path))
	if n != null and n.has_method("on_shot") and players.has(pid):
		WeaponHolder.notify_shot(n, weapon_id, upgraded, pid)


func on_interact(pid: int, path: String, inv: Dictionary) -> void:
	var p: Player = players.get(pid) as Player
	if p == null or p.is_local or p.downed or p.spectating:
		return
	_apply_inventory(p, inv)
	var n: Interactable = map.get_node_or_null(NodePath(path)) as Interactable
	if n == null or n.global_position.distance_to(p.global_position) > 12.0:
		push_warning("co-op: ignored a use of %s by player %d (%s)" % [path, pid, "no such node" if n == null else "too far"])
		return
	if n.can_interact(p):
		n.interact(p)
	else:
		send_player_op(pid, &"deny", [])


func on_hold(pid: int, path: String, active: bool) -> void:
	var n: Node = map.get_node_or_null(NodePath(path))
	if n is Interactable and players.has(pid):
		(n as Interactable).hold_changed(players[pid] as Player, active)


func on_player_event(pid: int, ev: StringName, _args: Array) -> void:
	var p: Player = players.get(pid) as Player
	if p == null or p.is_local:
		return
	match ev:
		&"downed":
			if p.downed or not coop.is_alive(pid):
				return
			p.downed = true
			p.last_stand = true
			GLBus.player_downed.emit(pid)   # -> MapRoot -> coop_downed(); relayed to every client


func on_fx(pid: int, kind: StringName, args: Array) -> void:
	if not players.has(pid):
		return
	if kind == &"gramophone":
		_host_gramophone(pid, args)
		return
	_show_fx(kind, args)
	if kind == &"explosion" and args.size() >= 2:
		GLBus.explosion.emit(args[0] as Vector3, float(args[1]))   # camera shake (relayed)
	for other: int in Net.player_ids():
		if other != pid and other != Net.local_player_id():
			Net._rpc_fx_of.rpc_id(Net.peer_of(other), kind, args)


## A client threw a Siren Gramophone: the real one (lure + blast) is thrown here, where the zombies are.
func _host_gramophone(pid: int, args: Array) -> void:
	if args.size() < 3:
		return
	var tid: String = str(args[2])
	var tac: Dictionary = (GLData.table("weapons").get("tactical", {}) as Dictionary).get(tid, {})
	var p: Player = players.get(pid) as Player
	if tac.is_empty() or p == null or (args[0] as Vector3).distance_to(p.global_position) > 6.0:
		return
	var g: Gramophone = Gramophone.new()
	g.cfg = tac
	g.by_player = pid
	map.add_child(g)
	g.global_position = args[0] as Vector3
	g.linear_velocity = args[1] as Vector3
	g.add_collision_exception_with(p)


func on_quest_request(pid: int, op: StringName, args: Array) -> void:
	if not players.has(pid) or args.size() < 3:
		return
	if op == &"call":
		var n: Node = map.get_node_or_null(NodePath(str(args[0])))
		var method: StringName = StringName(str(args[1]))
		if n != null and n.has_method(&"net_callable") and (n.call(&"net_callable") as Array).has(String(method)):
			n.callv(method, args[2] as Array)


## Host -> the owner of `pid`: a call that must run on their machine (Player._forward). A bot's "machine" is
## this one: the call lands on the bot's Player directly.
func send_player_op(pid: int, op: StringName, args: Array) -> void:
	if not Net.is_authority():
		return
	if pid == Net.local_player_id():
		_apply_op(op, args)
		return
	var p: Player = players.get(pid) as Player
	if p != null and p.is_bot:
		_apply_bot_op(p, op, args)
		return
	if not Net.is_host():
		return
	var peer: int = Net.peer_of(pid)
	if peer > 1:
		Net._rpc_op.rpc_id(peer, op, args)


## The ops a bot can receive (the rest are HUD / sound feedback a bot has no use for).
func _apply_bot_op(p: Player, op: StringName, args: Array) -> void:
	match op:
		&"hit":
			p.take_hit(float(args[0]), null)
		&"status":
			p.apply_status(StringName(str(args[0])), float(args[1]))
		&"knock":
			p.apply_knockback(args[0] as Vector3)
		&"down":
			p.down()
		&"inv":
			if args.size() >= 2 and INV_OPS.has(str(args[0])):
				p.weapons.callv(StringName(str(args[0])), args[1] as Array)
		&"revived":
			p.revive(int(args[0]))
		&"bleed":
			p.bleed_out()
		&"respawn":
			p.respawn_at(args[0] as Transform3D)


## Host: a world object changed; run the same presentation call on every client.
func world_call(node: Node, method: StringName, args: Array = []) -> void:
	if Net.is_host() and node != null and node.is_inside_tree():
		Net._rpc_world.rpc(String(map.get_path_to(node)), method, args)


## Host: a node the world spawned at runtime (power-up, the running drummer, the shard...) appears on every
## client too, with the same name and parent (so later calls and requests can find it by path).
func spawn_dynamic(node: Node3D, script_path: String, props: Dictionary) -> void:
	if not Net.is_host() or node == null or not node.is_inside_tree():
		return
	_dyn_uid += 1
	var uid: int = _dyn_uid
	node.name = "NetDyn%d" % uid
	_dyn[uid] = node
	node.tree_exiting.connect(func() -> void:
		_dyn.erase(uid)
		if not _shut and is_inside_tree():
			world_call(self, &"_dyn_free", [uid]))
	world_call(self, &"_dyn_spawn", [uid, script_path, String(map.get_path_to(node.get_parent())), props, node.global_transform])


func _dyn_spawn(uid: int, script_path: String, parent_path: String, props: Dictionary, xf: Transform3D) -> void:
	var parent: Node = map.get_node_or_null(NodePath(parent_path))
	if parent == null or not ResourceLoader.exists(script_path):
		return
	var n: Node3D = (load(script_path) as GDScript).new() as Node3D
	for k: Variant in props.keys():
		n.set(StringName(str(k)), props[k])
	n.name = "NetDyn%d" % uid
	parent.add_child(n)
	n.global_transform = xf
	_dyn[uid] = n


func _dyn_free(uid: int) -> void:
	var n: Node = _dyn.get(uid) as Node
	_dyn.erase(uid)
	if n != null and is_instance_valid(n):
		n.queue_free()


## Client (from the host): a quest action's presentation / profile parts.
func _quest_actions(a: Dictionary) -> void:
	QuestManager.run_client_actions(a)


## Client (from the host): a quest cutscene runner starts here too (presentation only, see requiem_ending.gd).
func _quest_cutscene(path: String, qid: String, sid: String, params: Dictionary) -> void:
	if not ResourceLoader.exists(path):
		return
	var runner: Node = (load(path) as GDScript).new() as Node
	runner.set("quest_id", StringName(qid))
	runner.set("step_id", StringName(sid))
	runner.set("params", params)
	map.add_child(runner)


func sfx_all(key: String, pos: Vector3, db: float = 0.0) -> void:
	if Net.is_host():
		Net._rpc_sfx.rpc(key, pos, db)


## Effects made on this peer by its own player (a grenade going off) shown to everyone else.
func local_explosion(pos: Vector3, radius: float, sound: String, db: float) -> void:
	if not Net.is_online():
		return
	var args: Array = [pos, radius, sound, db]
	if Net.is_host():
		Net._rpc_fx_of.rpc(&"explosion", args)
	else:
		Net._rpc_fx.rpc_id(1, &"explosion", args)


func on_fx_of(kind: StringName, args: Array) -> void:
	_show_fx(kind, args)


func _show_fx(kind: StringName, args: Array) -> void:
	if kind == &"explosion" and args.size() >= 4:
		var pos: Vector3 = args[0]
		Effects.explosion(pos, float(args[1]))
		AudioDirector.play_3d(str(args[2]), pos, float(args[3]), 0.08)


func local_fired(kind: int, weapon_id: StringName, origin: Vector3, end: Vector3) -> void:
	if not Net.is_online():
		return
	var data: Array = [kind, String(weapon_id), origin, end]
	if Net.is_host():
		Net._rpc_fire_of.rpc(Net.local_player_id(), data)
	else:
		Net._rpc_fire.rpc_id(1, data)


# ---------------------------------------------------------------- co-op rules (host)

## A companion joins the life cycle (offline sessions only): downed, revived, bled out; never respawned.
func add_companion(p: Player) -> void:
	companions[p.player_id] = p
	coop.add_companion(p.player_id)


func remove_companion(pid: int) -> void:
	companions.erase(pid)
	coop.remove(pid)


## The Player for an id: a match player, else a companion.
func player_of(pid: int) -> Player:
	var p: Player = players.get(pid) as Player
	return p if p != null else companions.get(pid) as Player

## A player went down (MapRoot._on_player_downed in co-op): perks are lost, the bleed-out clock starts.
func coop_downed(pid: int) -> void:
	PerkManager.on_player_downed(pid)
	var bleed: float = float(GLData.table("player")["bleedout_seconds"])
	var dp: Player = player_of(pid)
	if dp != null and dp.bleedout_seconds > 0.0:
		bleed = dp.bleedout_seconds   # a companion's own clock (U02 section 6: Jakub bleeds out after 60 s)
	coop.down(pid, bleed)
	if coop.everyone_down():
		map._game_over()


## A teammate finished a revive hold (RevivePoint.interact, on the host).
func coop_revive(target_pid: int, by_pid: int) -> void:
	if not coop.revive(target_pid):
		return
	var t: Player = player_of(target_pid)
	if t == null:
		return
	if t.is_local or t.is_bot:
		t.revive(by_pid)   # a bot gets up here (it announces player_revived itself, like the local player)
	else:
		t.downed = false
		t.last_stand = false
		send_player_op(target_pid, &"revived", [by_pid])
		GLBus.player_revived.emit(target_pid, by_pid)
	Economy.award(by_pid, int(GLData.table("economy")["revive_bonus"]))


func _bleed_out(pid: int) -> void:
	var t: Player = player_of(pid)
	if t == null:
		return
	if t.is_local:
		_apply_op(&"bleed", [])
	elif t.is_bot:
		t.bleed_out()
	else:
		t.spectating = true
		send_player_op(pid, &"bleed", [])
	if coop.everyone_down() and GameState.phase == GameState.Phase.PLAYING:
		map._game_over()


func _on_round_started_host(_round_number: int, _special: bool) -> void:
	for pid: int in coop.respawn_dead():
		var t: Player = players.get(pid) as Player
		if t == null:
			continue
		var xf: Transform3D = map.spawn_transform(pid)
		if t.is_local:
			_apply_op(&"respawn", [xf])
		elif t.is_bot:
			t.respawn_at(xf)
		else:

			t.downed = false
			t.spectating = false
			t.last_stand = false
			t.global_transform = xf
			t.interp.snap(float(Time.get_ticks_msec()), xf.origin, xf.basis.get_euler().y)
			send_player_op(pid, &"respawn", [xf])


# ---------------------------------------------------------------- relays (host)

func _connect_relays() -> void:
	var fns: Array[Callable] = [_relay0, _relay1, _relay2, _relay3, _relay4]
	for s: Dictionary in GLBus.get_signal_list():
		var sn: String = str(s["name"])
		if not RELAY.has(sn):
			continue
		var n: int = (s["args"] as Array).size()
		var cb: Callable = fns[n].bind(StringName(sn))
		GLBus.connect(sn, cb)
		_relays.append([GLBus, sn, cb])
	for s2: Dictionary in QuestManager.get_signal_list():
		var qn: String = str(s2["name"])
		if not QUEST_RELAY.has(qn):
			continue
		var cb2: Callable = fns[(s2["args"] as Array).size()].bind(StringName("q:" + qn))
		QuestManager.connect(qn, cb2)
		_relays.append([QuestManager, qn, cb2])


func _relay0(sn: StringName) -> void:
	_relay(sn, [])


func _relay1(a: Variant, sn: StringName) -> void:
	_relay(sn, [a])


func _relay2(a: Variant, b: Variant, sn: StringName) -> void:
	_relay(sn, [a, b])


func _relay3(a: Variant, b: Variant, c: Variant, sn: StringName) -> void:
	_relay(sn, [a, b, c])


func _relay4(a: Variant, b: Variant, c: Variant, d: Variant, sn: StringName) -> void:
	_relay(sn, [a, b, c, d])


func _relay(sn: StringName, args: Array) -> void:
	if not _shut:
		Net._rpc_event.rpc(sn, args)


# ---------------------------------------------------------------- state snapshot (host)

func _send_state(delta_since: float) -> void:
	var d: Dictionary = {
		"r": [int(RoundManager.state), RoundManager.current_round, RoundManager.is_special_round, RoundManager.to_spawn,
			RoundManager.alive, RoundManager.round_total, RoundManager.players],
		"sc": Economy._scrip, "mu": Economy.multiplier,
		"pk": PerkManager._owned, "bs": PerkManager._bonus_slots,
		"pt": [PerkManager._tiers, PerkManager.unlocked_tiers()],   # perk tiers + the host's unlocks (T-075)
		"sw": [PerkManager.solo_self_revives_left, PerkManager.second_wind_gone],
		"pw": GameState.power_on, "z": GameState.open_zones.keys(), "f": GameState.flags,
		"cr": CrateManager.location_index, "pu": PowerupManager._timers,
		"co": coop.to_net(),
		"ph": int(GameState.phase),
	}
	_quest_force -= delta_since
	var qh: int = hash([QuestManager._state, QuestManager.checkpoints])
	if qh != _quest_hash or _quest_force <= 0.0:
		_quest_hash = qh
		_quest_force = 2.0
		d["q"] = QuestManager.net_state()
	sent_bytes["state"] = int(sent_bytes["state"]) + var_to_bytes(d).size()
	Net._rpc_state.rpc(d)


# ---------------------------------------------------------------- zombies (host)

func zombie_by_net_id(net_id: int) -> Zombie:
	if map.director == null:
		return null
	if net_id >= 0 and net_id < map.director._pool.size():
		return map.director._pool[net_id]
	if Net.is_host():
		for z: Zombie in map.director._extras:
			if is_instance_valid(z) and z.net_id == net_id:
				return z
		return null
	return _zpuppets.get(net_id) as Zombie


func next_extra_id() -> int:
	_extra_counter = (_extra_counter + 1) % 150
	return EXTRA_ID_BASE + _extra_counter


func _send_zombies() -> void:
	var dir: ZombieDirector = map.director
	if dir == null:
		return
	var act: Array[Zombie] = dir.active_zombies()
	var now_ids: Dictionary = {}
	for z: Zombie in act:
		if z.net_id < 0:
			continue
		now_ids[z.net_id] = true
		if not _zknown.has(z.net_id) or _zknown[z.net_id] != z:
			_zknown[z.net_id] = z
			_send_spawn(z)
	for id: Variant in _zknown.keys():
		if not now_ids.has(id):
			var gone: Zombie = _zknown[id] as Zombie
			_zknown.erase(id)
			if gone != null and is_instance_valid(gone) and not gone.net_died:
				Net._rpc_zev.rpc(int(id), &"gone", [])
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.put_u32(Time.get_ticks_msec())
	var n: int = mini(255, now_ids.size())
	b.put_u8(n)
	var written: int = 0
	for z2: Zombie in act:
		if z2.net_id < 0 or written >= n:
			continue
		written += 1
		b.put_u8(z2.net_id)
		b.put_float(z2.global_position.x)
		b.put_float(z2.global_position.y)
		b.put_float(z2.global_position.z)
		b.put_u16(int(roundf(wrapf(z2.rotation.y, -PI, PI) / PI * 32767.0)) + 32768)
		b.put_u8(int(z2.state))
		b.put_u8(z2.net_sub_state())
		var f: int = 0
		if z2.is_crawler:
			f |= ZF_CRAWL
		if z2.is_burning():
			f |= ZF_BURN
		if z2.is_last:
			f |= ZF_LAST
		if z2 is Foreman and (z2 as Foreman).enraged:
			f |= ZF_ENRAGED
		b.put_u8(f)
		b.put_u8(clampi(int(ceil(255.0 * z2.hp / maxf(1.0, z2.max_hp))), 0, 255))
	sent_bytes["zombies"] = int(sent_bytes["zombies"]) + b.data_array.size()
	Net._rpc_zsnap.rpc(b.data_array)


func _send_spawn(z: Zombie) -> void:
	var kind_class: int = 1 if z is Foreman else (2 if z is Screamer else 0)
	Net._rpc_zev.rpc(z.net_id, &"spawn", [String(z.enemy_id), String(z.tier), z.variant_name(), z.max_hp, z.global_position,
		z.rotation.y, int(z.state), kind_class, z.net_sub_state()])


## Host: a zombie died (Zombie._die). The death variant goes to the clients so the fall matches.
func zombie_died(z: Zombie, limb: StringName, kind: StringName, death_kind: int, side: float, head_pop: bool) -> void:
	z.net_died = true
	if z.net_id >= 0:
		_zknown.erase(z.net_id)
		Net._rpc_zev.rpc(z.net_id, &"die", [String(limb), String(kind), death_kind, side, head_pop, z.global_position])


func zombie_event(z: Zombie, ev: StringName, args: Array) -> void:
	if z.net_id >= 0 and Net.is_host():
		Net._rpc_zev.rpc(z.net_id, ev, args)


# ================================================================== client

func _client_tick(delta: float) -> void:
	_p_acc += delta
	if _p_acc >= 1.0 / float(_cfg.get("player_send_hz", 30)) and local_player != null:
		_p_acc = 0.0
		var b: StreamPeerBuffer = StreamPeerBuffer.new()
		b.put_u32(Time.get_ticks_msec())
		_put_state(b, local_player.global_position, local_player.rotation.y, local_player.head.rotation.x, local_flags(local_player))
		Net._rpc_pstate.rpc_id(1, b.data_array)
	_check_inventory(delta)


func report_loaded() -> void:
	Net._rpc_loaded.rpc_id(1)


func on_begin() -> void:
	begun = true
	map.on_net_begin()


func report_downed() -> void:
	Net._rpc_pev.rpc_id(1, &"downed", [])


func request_interact(target: Interactable) -> void:
	Net._rpc_interact.rpc_id(1, String(map.get_path_to(target)), local_player.weapons.to_net())


func request_hold(target: Interactable, active: bool) -> void:
	Net._rpc_hold.rpc_id(1, String(map.get_path_to(target)), active)


## Client: run a whitelisted method on a world node on the host (switchboard plugs, radio frequencies).
func request_call(node: Node, method: StringName, args: Array) -> void:
	Net._rpc_quest.rpc_id(1, &"call", [String(map.get_path_to(node)), String(method), args])


func send_hit(z: Zombie, dmg: float, limb: StringName, weapon_id: StringName, kind: StringName, piercing: bool) -> void:
	var origin: Vector3 = shot_origin
	var dir: Vector3 = shot_dir
	if dir == Vector3.ZERO and local_player != null:
		origin = local_player.camera.global_position
		dir = ((z.global_position + Vector3.UP) - origin).normalized()
	Net._rpc_hit.rpc_id(1, z.net_id, dmg, limb, weapon_id, kind, piercing, origin, dir)


func send_zombie_effect(z: Zombie, effect: StringName, a: float = 0.0, b: float = 0.0) -> void:
	Net._rpc_zfx.rpc_id(1, z.net_id, effect, a, b)


func send_shootable(target: Node, weapon_id: StringName, upgraded: bool) -> void:
	Net._rpc_shot.rpc_id(1, String(map.get_path_to(target)), weapon_id, upgraded)


func _check_inventory(delta: float) -> void:
	if local_player == null or local_player.weapons == null:
		return
	_inv_t += delta
	var sig: Array = local_player.weapons.net_signature()
	var structural: bool = str(sig[0]) != _inv_sig
	var ammo: bool = int(sig[1]) != _inv_ammo
	if not structural and not (ammo and _inv_t >= float(_cfg.get("inventory_ammo_send_seconds", 0.5))):
		return
	_inv_sig = str(sig[0])
	_inv_ammo = int(sig[1])
	_inv_t = 0.0
	var inv: Dictionary = local_player.weapons.to_net()
	if Net.is_host():
		Net._rpc_inv_of.rpc(Net.local_player_id(), inv)
	else:
		Net._rpc_inv.rpc_id(1, inv)


func on_players(data: PackedByteArray) -> void:
	if data.size() < 5:
		return
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.data_array = data
	var t: float = _to_local("h", float(b.get_u32()))
	var n: int = b.get_u8()
	for i: int in n:
		if b.get_available_bytes() < 22:
			return
		var pid: int = b.get_u8()
		var pos: Vector3 = Vector3(b.get_float(), b.get_float(), b.get_float())
		var yaw: float = b.get_float()
		var pitch: float = b.get_float()
		var flags: int = b.get_u8()
		var p: Player = players.get(pid) as Player
		if p != null and not p.is_local and p.interp != null:
			p.interp.push(t, pos, yaw, pitch, flags)


func on_inventory_of(pid: int, inv: Dictionary) -> void:
	var p: Player = players.get(pid) as Player
	if p != null and not p.is_local:
		_apply_inventory(p, inv)


func on_fire_of(pid: int, data: Array) -> void:
	var p: Player = players.get(pid) as Player
	if p != null and not p.is_local and data.size() >= 4:
		p.remote_fire(int(data[0]), StringName(str(data[1])), data[2] as Vector3, data[3] as Vector3)


func on_op(op: StringName, args: Array) -> void:
	_apply_op(op, args)


## Runs a host decision on the local player (client: from an RPC; host: for its own player).
func _apply_op(op: StringName, args: Array) -> void:
	var p: Player = local_player
	if p == null:
		return
	Net.applying = true
	match op:
		&"hit":
			p.take_hit(float(args[0]), null)
		&"status":
			p.apply_status(StringName(str(args[0])), float(args[1]))
		&"knock":
			p.apply_knockback(args[0] as Vector3)
		&"down":
			p.down()
		&"inv":
			if args.size() >= 2 and INV_OPS.has(str(args[0])):
				p.weapons.callv(StringName(str(args[0])), args[1] as Array)
		&"deny":
			AudioDirector.play_2d("deny", -2.0)
			p.flash_prompt_denied()
		&"revived":
			p.revive(int(args[0]))
		&"bleed":
			p.bleed_out()
			_start_spectate()
		&"respawn":
			p.respawn_at(args[0] as Transform3D)
			_stop_spectate()
		&"banner":
			if map.hud != null:
				map.hud.show_banner(str(args[0]), float(args[1]))
		&"intel":
			GLBus.intel_found.emit(StringName(str(args[0])))
		&"sfx2d":
			AudioDirector.play_2d(str(args[0]), float(args[1]))
	Net.applying = false


## Host or client: tell one player something (a banner, an intel find, a 2D sound) on their own screen.
func notify_player(pid: int, op: StringName, args: Array) -> void:
	if pid == Net.local_player_id():
		_apply_op(op, args)
	elif Net.is_host():
		send_player_op(pid, op, args)


func on_event(sn: StringName, args: Array) -> void:
	Net.applying = true
	var s: String = String(sn)
	if s.begins_with("q:"):
		QuestManager.callv("emit_signal", [StringName(s.substr(2))] + args)
	else:
		if sn == &"crate_moved" and args.size() > 0:
			CrateManager.location_index = int(args[0])
		GLBus.callv("emit_signal", [sn] + args)
	Net.applying = false


func on_state(d: Dictionary) -> void:
	Net.applying = true
	var r: Array = d.get("r", [])
	if r.size() >= 7:
		RoundManager.state = int(r[0]) as RoundManager.State
		RoundManager.current_round = int(r[1])
		RoundManager.is_special_round = bool(r[2])
		RoundManager.to_spawn = int(r[3])
		RoundManager.alive = int(r[4])
		RoundManager.round_total = int(r[5])
		RoundManager.players = int(r[6])
	var sc: Dictionary = d.get("sc", {})
	for pid: Variant in sc.keys():
		Economy._scrip[int(pid)] = int(sc[pid])
	Economy.multiplier = int(d.get("mu", 1))
	var pk: Dictionary = d.get("pk", {})
	for pid2: Variant in pk.keys():
		var now: Array = (pk[pid2] as Array).duplicate()
		var before: Array = PerkManager.owned(int(pid2))
		if now != before:
			PerkManager._owned[int(pid2)] = now
			GLBus.perks_changed.emit(int(pid2))
	for pid3: Variant in PerkManager._owned.keys():
		if not pk.has(pid3) and not (PerkManager._owned[pid3] as Array).is_empty():
			PerkManager._owned[pid3] = []
			GLBus.perks_changed.emit(int(pid3))
	var bs: Dictionary = d.get("bs", {})
	PerkManager._bonus_slots = bs.duplicate()
	var pt: Array = d.get("pt", [{}, {}])
	if pt.size() >= 2:
		var tiers_now: Dictionary = (pt[0] as Dictionary).duplicate(true)
		if tiers_now != PerkManager._tiers:
			var changed: Array = []
			for k: Variant in tiers_now.keys() + PerkManager._tiers.keys():
				if not changed.has(int(k)) and tiers_now.get(k, {}) != PerkManager._tiers.get(k, {}):
					changed.append(int(k))
			PerkManager._tiers = tiers_now
			for cpid: Variant in changed:
				GLBus.perks_changed.emit(int(cpid))
		PerkManager.host_unlocks = (pt[1] as Dictionary).duplicate()

	var sw: Array = d.get("sw", [3, false])
	PerkManager.solo_self_revives_left = int(sw[0])
	PerkManager.second_wind_gone = bool(sw[1])
	if bool(d.get("pw", false)) and not GameState.power_on:
		GameState.power_on = true
		GLBus.power_activated.emit()
	for z: Variant in d.get("z", []):
		GameState.open_zone(StringName(str(z)))
	var flags: Dictionary = d.get("f", {})
	for k: Variant in flags.keys():
		if GameState.flags.get(k) != flags[k]:
			GameState.set_flag(StringName(str(k)), flags[k])
	for k2: Variant in GameState.flags.keys():
		if not flags.has(k2):
			GameState.flags.erase(k2)
	var cr: int = int(d.get("cr", -1))
	if cr != CrateManager.location_index:
		CrateManager.location_index = cr
		for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
			n.call("refresh")
	PowerupManager._timers = (d.get("pu", {}) as Dictionary).duplicate()
	coop.from_net(d.get("co", {}))
	if d.has("q"):
		QuestManager.apply_net_state(d["q"] as Dictionary)
	Net.applying = false


func on_zombie_snapshot(data: PackedByteArray) -> void:
	if data.size() < 5 or map.director == null:
		return
	var b: StreamPeerBuffer = StreamPeerBuffer.new()
	b.data_array = data
	var t: float = _to_local("h", float(b.get_u32()))
	var n: int = b.get_u8()
	for i: int in n:
		if b.get_available_bytes() < 18:
			return
		var id: int = b.get_u8()
		var pos: Vector3 = Vector3(b.get_float(), b.get_float(), b.get_float())
		var yaw: float = (float(b.get_u16()) - 32768.0) / 32767.0 * PI
		var st: int = b.get_u8()
		var sub: int = b.get_u8()
		var f: int = b.get_u8()
		var hp: int = b.get_u8()
		var z: Zombie = zombie_by_net_id(id)
		if z == null or not z.puppet or not z.is_active() or z.interp == null:
			continue
		z.interp.push(t, pos, yaw, 0.0, st | (f << 8), sub | (hp << 8))


func on_zombie_event(net_id: int, ev: StringName, args: Array) -> void:
	if map.director == null:
		return
	Net.applying = true
	match ev:
		&"spawn":
			var z: Zombie = _puppet_for(net_id, int(args[7]))
			if z != null:
				z.puppet_activate(StringName(str(args[0])), StringName(str(args[1])), str(args[2]), float(args[3]),
					args[4] as Vector3, float(args[5]), int(args[6]), int(args[8]), local_player)
		&"die":
			var zd: Zombie = zombie_by_net_id(net_id)
			if zd != null and zd.puppet:
				zd.puppet_die(StringName(str(args[0])), StringName(str(args[1])), int(args[2]), float(args[3]), bool(args[4]), args[5] as Vector3)
		&"crawl":
			var zc: Zombie = zombie_by_net_id(net_id)
			if zc != null and zc.puppet and zc.is_active():
				zc.become_crawler()
		&"gone":
			var zg: Zombie = zombie_by_net_id(net_id)
			if zg != null and zg.puppet:
				zg.puppet_gone()
		&"fx":
			var zf: Zombie = zombie_by_net_id(net_id)
			if zf != null and zf.puppet:
				zf.puppet_fx(StringName(str(args[0])), args.slice(1))
	Net.applying = false


func _puppet_for(net_id: int, kind_class: int) -> Zombie:
	var dir: ZombieDirector = map.director
	if net_id < dir._pool.size():
		return dir._pool[net_id]
	var have: Zombie = _zpuppets.get(net_id) as Zombie
	if have != null and is_instance_valid(have):
		if (kind_class == 1) == (have is Foreman) and (kind_class == 2) == (have is Screamer):
			return have
		have.queue_free()
	var z: Zombie = dir.make_puppet_extra(kind_class)
	z.net_id = net_id
	_zpuppets[net_id] = z
	return z


func on_world_event(path: String, method: StringName, args: Array) -> void:
	var n: Node = map.get_node_or_null(NodePath(path)) if path != "." else map
	if n == null or not n.has_method(method):
		return
	Net.applying = true
	n.callv(method, args)
	Net.applying = false


func on_game_over(stats: Dictionary, elapsed: float) -> void:
	map.show_game_over(stats, elapsed)


func _on_roster_changed_client() -> void:
	for pid: Variant in players.keys():
		if not Net.roster.has(int(pid)) and int(pid) != Net.local_player_id():
			var p: Player = players[pid] as Player
			players.erase(pid)
			GameState.player_ids.erase(int(pid))
			if p != null and is_instance_valid(p):
				p.queue_free()


# ================================================================== spectating (bled out)

func _start_spectate() -> void:
	if _spectate_cam == null or not is_instance_valid(_spectate_cam):
		_spectate_cam = Camera3D.new()
		_spectate_cam.name = "SpectateCam"
		_spectate_cam.far = 400.0
		map.add_child(_spectate_cam)
	_spectate_cam.global_transform = local_player.camera.global_transform
	_spectate_cam.current = true
	_spectate_pid = 0


func _stop_spectate() -> void:
	if _spectate_cam != null and is_instance_valid(_spectate_cam):
		_spectate_cam.queue_free()
	_spectate_cam = null
	_spectate_pid = 0
	if local_player != null:
		local_player.camera.current = true


func spectate_name() -> String:
	return Net.display_name(_spectate_pid) if _spectate_pid != 0 else ""


func _update_spectate(delta: float) -> void:
	if _spectate_cam == null or not is_instance_valid(_spectate_cam) or local_player == null:
		return
	var cands: Array[int] = []
	for pid: Variant in players.keys():
		var p: Player = players[pid]
		if not p.is_local and not p.spectating:
			cands.append(int(pid))
	cands.sort()
	if cands.is_empty():
		return
	if not cands.has(_spectate_pid):
		_spectate_pid = cands[0]
	elif Input.is_action_just_pressed(&"fire") and not GameState.input_blocked:
		_spectate_pid = cands[(cands.find(_spectate_pid) + 1) % cands.size()]
	var t: Player = players[_spectate_pid]
	var eye: Vector3 = t.head.global_position
	var back: Vector3 = t.global_basis.z
	var want: Vector3 = eye + back * 2.4 + Vector3.UP * 0.6 + t.global_basis.x * 0.5
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, want, 1 | (1 << 8))
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		want = (hit["position"] as Vector3).lerp(eye, 0.15)
	var k: float = clampf(delta * 8.0, 0.0, 1.0)
	_spectate_cam.global_position = _spectate_cam.global_position.lerp(want, k)
	var look: Vector3 = eye - t.global_basis.z * 6.0
	if _spectate_cam.global_position.distance_squared_to(look) > 0.01:
		_spectate_cam.look_at(look, Vector3.UP)
