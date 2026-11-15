extends Node
## Headless co-op smoke test (M7). Runs as the HOST, starts a second headless Godot as the CLIENT
## (OS.create_process) on 127.0.0.1, and both play a scripted match on Map 0:
##   1. the client buys a wall weapon (a host-validated purchase; the weapon arrives in the client's hands)
##   2. the client shoots zombies with its own weapon (client raycast -> host-validated hits -> kills)
##   3. the client goes down (last stand), the host revives them (revive point, Scrip bonus, loadout back)
##   4. the client goes down again and bleeds out (clock shortened), spectates
##   5. the round advances: round 2 reaches the client, which respawns with the starting loadout, and a
##      24-zombie horde shows up on the client
##   T-192 (UPDATE 11, Hard Truth, on by default): the bled-out client's body lies on the host as a dormant zombie in
##   Peg's risen body, the client's puppet of it lies still too (net sub state 1), it gets up at 4 s, the host puts it
##   down while clearing the round and the death crate (a NetMatch dynamic node) appears on the client.
##   T-251 (UPDATE 19): the host deals the tonic machines from a pinned seed that is not the match seed and deals again
##   once the match has begun (mirrored); at the end the client's layout (every machine's place, every crate) must be
##   the host's.
## Each side checks what it sees and reports RESULT PASS/FAIL; the host prints both and exits 0 only if both
## passed. The child is killed on every exit path; both sides have hard timeouts.
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_coop.tscn        (the host spawns the client itself)
## Silent and firewall-free: headless (dummy audio), bound to and connecting on 127.0.0.1 only.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const HOST_TIMEOUT: float = 240.0
const CLIENT_TIMEOUT: float = 220.0
const PERK_SEED_PINNED: int = 4242
const PERK_SEED_REDEAL: int = 5151

var _role: String = "host"
var _port: int = 0
var _child_pid: int = -1
var _t: float = 0.0
var _step: String = "lobby"
var _step_t: float = 0.0
var _fails: PackedStringArray = []
var _notes: PackedStringArray = []
var _kills_by_client: int = 0
var _client_result: Dictionary = {}
var _rounds_seen: Array[int] = []
var _downs_seen: Array[int] = []
var _revives_seen: Array = []
var _scrip_before: int = 0
var _target: Zombie = null
var _shots: int = 0
var _fire_cd: float = 0.0
var _saw_puppets: int = 0
var _done: bool = false
var _log_path: String = ""
var _zbytes0: int = 0
var _horde_t: float = 0.0
var _horde_seen: int = 0
var _respawn_checked: bool = false
var _ht_body_ok: bool = false      # T-192: host: the body lay there
var _saw_body: bool = false        # T-192: client: a puppet in Peg's risen body
var _saw_dormant: bool = false
var _saw_crate: bool = false
var _perk_seed_first: int = -1     # T-251: client: the deal it stood on when the match began


func _ready() -> void:
	# The driver lives on the root so it survives the scene changes (lobby -> map). Same path on both peers.
	if get_parent() != get_tree().root or name != "CoopSmoke":
		var d: Node = (load("res://gravelight/tools_src/smoke_coop.gd") as GDScript).new() as Node
		d.name = "CoopSmoke"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		set_physics_process(false)
		return
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.get_slice("=", 1)
		elif a.begins_with("--port="):
			_port = int(a.get_slice("=", 1))
	ProfileSave.path = "user://_qa_coop_%s.json" % _role
	ProfileSave.profile = ProfileSave.new_profile()
	_log_path = "user://_qa_coop_%s.log" % _role
	var f: FileAccess = FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		f.close()
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, _w: StringName, by: int) -> void:
		if by == 2:
			_kills_by_client += 1)
	GLBus.round_started.connect(func(r: int, _s: bool) -> void: _rounds_seen.append(r))
	GLBus.player_downed.connect(func(p: int) -> void: _downs_seen.append(p))
	GLBus.player_revived.connect(func(p: int, by: int) -> void: _revives_seen.append([p, by]))
	if _role == "host":
		_start_host()
	else:
		_start_client()


func _log(msg: String) -> void:
	var line: String = "[coop:%s] %s" % [_role, msg]
	print(line)
	var f: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()


func _fail(msg: String) -> void:
	_fails.append(msg)
	_log("FAIL: " + msg)


func _goto(step: String) -> void:
	_log("step -> " + step)
	_step = step
	_step_t = 0.0


# ================================================================== host

func _start_host() -> void:
	if _port <= 0:
		var r: RandomNumberGenerator = RandomNumberGenerator.new()
		r.randomize()
		_port = r.randi_range(27100, 27900)
	GameState.character_id = &"dutch"
	if Net.host_game(_port, "127.0.0.1") != OK:
		_fail("couldn't host on 127.0.0.1:%d (%s)" % [_port, Net.last_error])
		_finish()
		return
	var exe: String = OS.get_executable_path()
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://gravelight/tools_src/smoke_coop.tscn",
		"--", "--role=client", "--port=%d" % _port]
	_child_pid = OS.create_process(exe, args)
	if _child_pid <= 0:
		_fail("couldn't start the client process")
		_finish()
		return
	_log("hosting on 127.0.0.1:%d, client process %d" % [_port, _child_pid])


func _host_tick(_delta: float) -> void:
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map == null and _step != "lobby" and _step != "loading":
		return
	match _step:
		"lobby":
			if Net.roster.size() >= 2 and Net.all_ready():
				_log("client joined as %s; starting the match" % Net.display_name(2))
				PerkLayout.forced_seed = PERK_SEED_PINNED   # T-251: the host's deal is not the match seed's: the client must follow the host
				Net.start_match(MAP)
				_goto("loading")
			elif _step_t > 60.0:
				_fail("the client never joined/readied (roster %d)" % Net.roster.size())
				_finish()
		"loading":
			if map != null and map.session != null and map.session.begun:
				GameState.god_mode = true   # the host's own player stays up (the client's god mode is its own)
				# T-251: the tonic machines' deal. The host dealt from a pinned seed (the client's own first deal was from
				# the match seed: the state snapshot puts it right); now the host deals again and mirrors it
				var pl: PerkLayout = PerkLayout.current(get_tree())
				if pl == null or pl.seed_value != PERK_SEED_PINNED:
					_fail("the host did not deal its perk machines from the pinned seed (%s)" % (str(pl.seed_value) if pl != null else "no layout"))
				else:
					_log("perk layout: pinned seed %d (the match seed is %d); re-dealing from %d" % [pl.seed_value, QuestManager.match_seed, PERK_SEED_REDEAL])
					pl.reshuffle(PERK_SEED_REDEAL)
				_goto("wait_client")
			elif _step_t > 60.0:
				_fail("the match never began on the host")
				_finish()
		"wait_client":
			# the client drives steps 1-3; the host watches and does the revive when asked
			if _step_t > 150.0:
				_fail("timed out waiting for the client's steps")
				_finish()
		"revive":
			var s: NetMatch = map.session
			var puppet: Player = s.players.get(2) as Player
			if puppet == null:
				_fail("no puppet for player 2")
				_finish()
				return
			if not s.coop.is_downed(2):
				if _step_t > 10.0:
					_fail("host never saw player 2 downed")
					_finish()
				return
			_scrip_before = Economy.get_scrip(1)
			var me: Player = map.player
			me.global_position = puppet.global_position + Vector3(1.0, 0.2, 0.0)
			var rp: RevivePoint = puppet.get_node("Revive") as RevivePoint
			if not rp.can_interact(me):
				_fail("host can't revive player 2 (revive point refused)")
			me.use_interactable(rp)
			if not s.coop.is_alive(2):
				_fail("revive didn't bring player 2 back on the host")
			if Economy.get_scrip(1) < _scrip_before + 100:
				_fail("no revive bonus (host Scrip %d -> %d)" % [_scrip_before, Economy.get_scrip(1)])
			_qa_send("revived", {})
			_goto("wait_bleed")
		"wait_bleed":
			# the client goes down again; this time nobody helps (the clock is shortened for the test)
			var s2: NetMatch = map.session
			if s2.coop.is_downed(2) and _step_t > 0.5:
				if float((s2.coop.players[2] as Dictionary)["bleed"]) > 1.5:
					(s2.coop.players[2] as Dictionary)["bleed"] = 1.0
			if s2.coop.is_dead(2):
				_log("player 2 bled out")
				var body: Zombie = s2.hard_truth.body_of(2) if s2.hard_truth != null else null
				_ht_body_ok = body != null and body.is_dormant()
				_log("Hard Truth: body %s (dormant %s, person %s)" % [str(body != null), str(_ht_body_ok), str(body.get_meta("person", "")) if body != null else "-"])
				_goto("advance")
			elif _step_t > 30.0:
				_fail("player 2 never bled out")
				_goto("advance")
		"advance":
			# kill everything as it spawns until round 2 starts
			for z: Zombie in map.director.active_zombies():
				z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
			if RoundManager.current_round >= 2:
				_log("round %d on the host" % RoundManager.current_round)
				_qa_send("round2", {"round": RoundManager.current_round})
				map.director.debug_spawn(24)   # a full horde for the client to see (snapshot load check)
				_zbytes0 = int(map.session.sent_bytes["zombies"])
				_goto("wait_result")
			elif _step_t > 90.0:
				_fail("the round never advanced (round %d, alive %d, queued %d)" % [RoundManager.current_round, RoundManager.alive, RoundManager.to_spawn])
				_finish()
		"wait_result":
			_horde_t += _delta
			if not _client_result.is_empty():
				_host_report(map)
			elif _step_t > 40.0:
				_fail("no result from the client")
				_finish()


func _host_report(map: MapRoot) -> void:
	var s: NetMatch = map.session
	var secs: float = maxf(1.0, _t)
	_log("bandwidth host->each client: players %.1f KB/s, zombies %.1f KB/s, state %.1f KB/s (payload)" % [
		float(s.sent_bytes["players"]) / secs / 1024.0, float(s.sent_bytes["zombies"]) / secs / 1024.0,
		float(s.sent_bytes["state"]) / secs / 1024.0])
	if _horde_t > 0.5:
		_log("horde: %d zombies alive, zombie snapshots %.1f KB/s while it was up" % [map.director.active_zombies().size(),
			float(int(s.sent_bytes["zombies"]) - _zbytes0) / _horde_t / 1024.0])
	if _kills_by_client < 2:
		_fail("host credited the client with %d kills (need 2)" % _kills_by_client)
	if not _downs_seen.has(2):
		_fail("host never got player_downed(2)")
	var ht: HardTruth = s.hard_truth
	if not _ht_body_ok:
		_fail("Hard Truth: no dormant body on the host when player 2 bled out")
	elif ht == null or int(ht.stats["rises"]) < 1 or int(ht.stats["crates"]) < 1:
		_fail("Hard Truth: the body never rose / was put down with a crate (%s)" % (str(ht.stats) if ht != null else "no rule"))
	else:
		_log("Hard Truth on the host: %s" % str(ht.stats))
	# T-251: both peers stand every tonic machine in the same place
	var mine: String = perk_signature(get_tree())
	var theirs: String = str(_client_result.get("perk_sig", ""))
	if int(_client_result.get("perk_seed", -1)) != PERK_SEED_REDEAL or theirs != mine or mine == "":
		_fail("perk layout: host and client disagree (host seed %d, client seed %s)
  host   %s
  client %s" % [PERK_SEED_REDEAL, str(_client_result.get("perk_seed", "?")), mine, theirs])
	else:
		_log("perk layout: host and client agree on seed %d (12 machines, the client's first deal was seed %s)" % [PERK_SEED_REDEAL, str(_client_result.get("perk_seed_first", "?"))])
	var c_pass: bool = bool(_client_result.get("pass", false))
	for f: Variant in _client_result.get("fails", []):
		_fails.append("client: " + str(f))
	for n: Variant in _client_result.get("notes", []):
		_log("client: " + str(n))
	if not c_pass and (_client_result.get("fails", []) as Array).is_empty():
		_fails.append("client reported FAIL")
	_finish()


# ================================================================== client

func _start_client() -> void:
	GameState.character_id = &"peg"
	Net.joined.connect(func() -> void:
		_log("joined as player %d" % Net.local_player_id())
		Net.set_ready(true))
	Net.join_failed.connect(func(reason: String) -> void:
		_fail("join failed: " + reason)
		_finish())
	if Net.join_game("127.0.0.1", _port) != OK:
		_fail("couldn't start connecting: " + Net.last_error)
		_finish()


func _client_tick(delta: float) -> void:
	var map: MapRoot = get_tree().current_scene as MapRoot
	if _step != "lobby" and not Net.is_online():
		_fail("lost the connection to the host during '%s'" % _step)
		_finish()
		return
	var me: Player = map.player if map != null else null
	if map != null and map.director != null and _step != "lobby":
		for zz: Zombie in map.director.active_zombies():
			if str(zz.get_meta("person", "")) == "peg":
				_saw_body = true
				if zz.is_dormant():
					_saw_dormant = true
		if not _saw_crate and not get_tree().get_nodes_in_group(&"fallen_crates").is_empty():
			_saw_crate = true
			_notes.append("Hard Truth: the death crate reached the client (%s)" % str((get_tree().get_nodes_in_group(&"fallen_crates")[0] as FallenCrate).owner_name))
	match _step:
		"lobby":
			if map != null and map.session != null and map.session.begun and me != null:
				GameState.god_mode = true   # survive until the scripted down
				var pl0: PerkLayout = PerkLayout.current(get_tree())
				_perk_seed_first = pl0.seed_value if pl0 != null else -1
				_goto("buy")
			elif _step_t > 90.0:
				_fail("never got into the match")
				_finish()
		"buy":
			var wb: WallBuy = map.find_child("WallBuy_kar98k", true, false) as WallBuy
			if wb == null:
				_fail("no Kar98k wall-buy on Map 0")
				_finish()
				return
			# walk up to it (teleport), let the host's puppet catch up, then use it
			me.global_position = wb.global_position - wb.global_basis.z * 1.0 - Vector3.UP * 1.0
			if _step_t < 1.0:
				return
			_scrip_before = Economy.get_scrip(Net.local_player_id())
			me.use_interactable(wb)
			_goto("buy_wait")
		"buy_wait":
			if me.weapons.find_weapon_base(&"kar98k") != null:
				if _notes.is_empty():
					_notes.append("wall-buy arrived in %.2f s" % _step_t)
				if _step_t > 0.4 and Economy.get_scrip(Net.local_player_id()) != _scrip_before - wb_price(map):
					_fail("Scrip after the buy %d (expected %d)" % [Economy.get_scrip(Net.local_player_id()), _scrip_before - wb_price(map)])
				if _step_t > 0.4:
					_goto("hunt")
			elif _step_t > 8.0:
				_fail("the Kar98k never arrived")
				_goto("hunt")
		"hunt":
			_hunt(map, me, delta)
		"down":
			GameState.god_mode = false
			me.take_hit(99999.0, null)
			if not me.downed or not me.last_stand:
				_fail("didn't enter the last stand")
			var pistol: WeaponInstance = me.weapons.current()
			if pistol == null or pistol.weapon_class() != &"pistol":
				_fail("no pistol in the last stand")
			_goto("down_wait")
		"down_wait":
			if map.session.coop.is_downed(Net.local_player_id()) and _downs_seen.has(Net.local_player_id()):
				_qa_send("downed", {})
				_goto("revive_wait")
			elif _step_t > 10.0:
				_fail("the host never confirmed the down")
				_qa_send("downed", {})
				_goto("revive_wait")
		"revive_wait":
			if not me.downed:
				if me.weapons.find_weapon_base(&"kar98k") == null:
					_fail("the loadout didn't come back after the revive")
				var rv: bool = false
				for e: Array in _revives_seen:
					if int(e[0]) == Net.local_player_id() and int(e[1]) == 1:
						rv = true
				if not rv and _step_t > 1.0:
					_fail("no player_revived(2, by 1) relayed")
				if rv or _step_t > 1.0:
					_notes.append("revived after %.2f s" % _step_t)
					_goto("down2")
		"down2":
			if _step_t < 1.0:
				return
			me.take_hit(99999.0, null)
			_goto("bleed_wait")
		"bleed_wait":
			if me.spectating:
				_notes.append("bled out -> spectating after %.1f s" % _step_t)
				GameState.god_mode = true
				_goto("round_wait")
			elif _step_t > 30.0:
				_fail("never bled out / spectated")
				GameState.god_mode = true
				_goto("round_wait")
			elif _step_t > 20.0:
				_fail("never revived")
				_goto("round_wait")
		"round_wait":
			if _rounds_seen.has(2) and RoundManager.current_round >= 2:
				if not _respawn_checked and _step_t > 0.0:
					if me.spectating or me.downed:
						if _step_t > 20.0:
							_fail("not respawned at round 2")
							_respawn_checked = true
						return
					_respawn_checked = true
					var w: WeaponInstance = me.weapons.current()
					if w == null or w.id != &"m1911" or me.weapons.find_weapon_base(&"kar98k") != null:
						_fail("respawn loadout wrong (%s)" % (str(w.id) if w != null else "empty hands"))
					else:
						_notes.append("respawned at round 2 with the starting loadout")
				var n: int = 0
				for z: Zombie in map.director.active_zombies():
					if z.puppet and z.interp != null and not z.interp.is_empty():
						n += 1
				_horde_seen = maxi(_horde_seen, n)
				if _horde_seen >= 20 or _step_t > 60.0:
					_notes.append("round 2 reached the client (rounds seen %s); up to %d zombie puppets at once" % [str(_rounds_seen), _horde_seen])
					if not (_saw_body and _saw_dormant):
						_fail("Hard Truth: the client never saw Peg's body lying (body %s, dormant %s)" % [str(_saw_body), str(_saw_dormant)])
					if not _saw_crate:
						_fail("Hard Truth: the death crate never reached the client")
					if _horde_seen < 20:
						_fail("the 24-zombie horde didn't show up on the client (saw %d)" % _horde_seen)
					_client_finish()
			elif _step_t > 100.0:
				_fail("round 2 never reached the client (rounds seen %s, mirrored %d)" % [str(_rounds_seen), RoundManager.current_round])
				_client_finish()


func wb_price(map: MapRoot) -> int:
	var wb: WallBuy = map.find_child("WallBuy_kar98k", true, false) as WallBuy
	return wb.price() if wb != null else 0


## Step 2: stand near a zombie puppet with a clear line, aim at its head, and fire the local weapon.
func _hunt(map: MapRoot, me: Player, delta: float) -> void:
	var act: Array[Zombie] = map.director.active_zombies()
	_saw_puppets = maxi(_saw_puppets, act.size())
	if _kills_by_client >= 2:
		me.set_physics_process(true)
		_notes.append("client kills: %d (saw up to %d zombie puppets)" % [_kills_by_client, _saw_puppets])
		_goto("down")
		return
	if _step_t > 100.0:
		me.set_physics_process(true)
		_fail("killed only %d zombies in 100 s (saw %d puppets)" % [_kills_by_client, _saw_puppets])
		_goto("down")
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_active():
		_target = null
		for z: Zombie in act:
			if z.state == Zombie.State.CHASE or z.state == Zombie.State.TEAR or z.state == Zombie.State.TO_WINDOW or z.state == Zombie.State.WAIT_WINDOW:
				_target = z
				break
		if _target == null:
			return
		_shots = 0
	# keep a clear 3 m line to it (try 8 directions), then aim the camera at the head
	me.set_physics_process(false)
	var head: Vector3 = _target.global_position + Vector3.UP * 1.62
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	var best: Vector3 = Vector3.INF
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		var spot: Vector3 = _target.global_position + Vector3(cos(a), 0, sin(a)) * 3.0
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.62, head, 1 | (1 << 8))
		if space.intersect_ray(q).is_empty():
			best = spot
			break
	if best == Vector3.INF:
		best = _target.global_position + Vector3(0, 0, 3.0)
	me.global_position = best
	me.velocity = Vector3.ZERO
	var eye: Vector3 = best + Vector3.UP * 1.62
	var d: Vector3 = head - eye
	me.rotation.y = atan2(-d.x, -d.z)
	me.head.position.y = 1.62
	me.head.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	_fire_cd -= delta
	var fire: bool = _fire_cd <= 0.0
	if fire:
		_fire_cd = 0.45
		_shots += 1
	var w: WeaponInstance = me.weapons.current()
	if w != null and w.mag <= 0 and w.reserve <= 0:
		me.weapons.refill_all()
	me.weapons.tick(delta, {"fire_pressed": fire, "fire_held": fire, "ads": true, "sprinting": false})
	if _shots > 25:
		_target = null   # stubborn target: pick another


func _client_finish() -> void:
	var plc: PerkLayout = PerkLayout.current(get_tree())
	_qa_send("result", {"pass": _fails.is_empty(), "fails": Array(_fails), "notes": Array(_notes),
		"perk_seed": plc.seed_value if plc != null else -1, "perk_seed_first": _perk_seed_first, "perk_sig": perk_signature(get_tree())})
	_log("RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL"))
	_done = true
	# give the reliable message a moment, then leave
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		Net.leave("")
		get_tree().quit(0 if _fails.is_empty() else 1))


# ================================================================== shared

## T-251: where every tonic machine stands on this peer ("id:x,y,z,yaw" in id order), and which spots show a crate.
static func perk_signature(tree: SceneTree) -> String:
	var rows: PackedStringArray = []
	for n: Node in tree.get_nodes_in_group(&"perk_machines"):
		var pm: PerkMachine = n as PerkMachine
		rows.append("%s:%.2f,%.2f,%.2f,%d" % [pm.perk_id, pm.global_position.x, pm.global_position.y, pm.global_position.z, int(round(rad_to_deg(pm.global_rotation.y)))])
	rows.sort()
	var free: PackedStringArray = []
	for s: Node in tree.get_nodes_in_group(&"perk_spots"):
		if (s as PerkSpot).is_free():
			free.append(String((s as PerkSpot).spot_id))
	free.sort()
	return "; ".join(rows) + " | crates: " + ",".join(free)


func _qa_send(what: String, data: Dictionary) -> void:
	if Net.is_online():
		rpc("_qa", what, data)


@rpc("any_peer", "call_remote", "reliable")
func _qa(what: String, data: Dictionary) -> void:
	_log("got '%s'" % what)
	if _role == "host":
		match what:
			"downed":
				_goto("revive")
			"result":
				_client_result = data
	else:
		match what:
			"revived":
				pass   # the client watches its own state


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_step_t += delta
	if _role == "host":
		if _t > HOST_TIMEOUT:
			_fail("host timeout in step '%s'" % _step)
			_finish()
			return
		_host_tick(delta)
		if _client_result.is_empty() and _child_pid > 0 and _t > 5.0 and not OS.is_process_running(_child_pid) and _step != "lobby":
			_fail("the client process exited early")
			_finish()
	else:
		if _t > CLIENT_TIMEOUT:
			_fail("client timeout in step '%s'" % _step)
			_client_finish()
			return
		_client_tick(delta)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _role != "host":
		_client_finish()
		return
	_kill_child()
	var ok: bool = _fails.is_empty()
	if not ok:
		var f: FileAccess = FileAccess.open("user://_qa_coop_client.log", FileAccess.READ)
		if f != null:
			print("[coop] --- client log ---")
			print(f.get_as_text())
			f.close()
	for f2: String in _fails:
		print("[coop] FAIL: " + f2)
	print("[coop] RESULT: %s" % ("PASS" if ok else "FAIL"))
	Net.leave("")
	get_tree().quit(0 if ok else 1)


func _kill_child() -> void:
	if _child_pid > 0 and OS.is_process_running(_child_pid):
		OS.kill(_child_pid)
	_child_pid = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _role == "host":
			_kill_child()
