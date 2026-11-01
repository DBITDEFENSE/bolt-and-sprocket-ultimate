extends GutTest
## Co-op rules (M7, docs/GDD.md §3-5, D-064..D-070): player-count scaling, Scrip per player, revive and
## bleed-out timers, game over when everyone is down, hit validation, and the interpolation buffer.

var rounds: Dictionary
var player_cfg: Dictionary
var net_cfg: Dictionary


func before_all() -> void:
	rounds = GLData.load_json("res://data/gravelight/rounds.json")
	player_cfg = GLData.load_json("res://data/gravelight/player.json")
	net_cfg = GLData.load_json("res://data/gravelight/net.json")


# ---------------------------------------------------------------- scaling by player count

func test_zombie_count_scales_with_players() -> void:
	# ceil(base(r) x [1.0, 1.6, 2.2, 2.8][players]) (D-004)
	assert_eq(RoundManager.zombie_count(1, 1, rounds), 6)
	assert_eq(RoundManager.zombie_count(1, 2, rounds), 10)    # 9.6
	assert_eq(RoundManager.zombie_count(1, 3, rounds), 14)    # 13.2
	assert_eq(RoundManager.zombie_count(1, 4, rounds), 17)    # 16.8
	assert_eq(RoundManager.zombie_count(10, 1, rounds), 34)
	assert_eq(RoundManager.zombie_count(10, 4, rounds), 93)   # ceil(33.09 x 2.8)


func test_more_players_never_fewer_zombies() -> void:
	for r: int in [1, 5, 10, 20, 30]:
		var prev: int = 0
		for p: int in range(1, 5):
			var n: int = RoundManager.zombie_count(r, p, rounds)
			assert_gt(n, prev, "round %d, %d players" % [r, p])
			prev = n


func test_health_does_not_scale_with_players() -> void:
	# Classic: only the count (and the Foreman / Bellringer counts) scale; a zombie is as tough for four as for one.
	assert_eq(RoundManager.zombie_health(10, rounds), 1045)


func test_bellringer_and_foreman_scale_with_players() -> void:
	assert_gt(RoundManager.bell_count(10, 4, rounds), RoundManager.bell_count(10, 1, rounds))
	var fm: Dictionary = GLData.table("enemies")["enemies"]["foreman"]
	assert_gt(RoundManager.foreman_health(12, 4, fm), RoundManager.foreman_health(12, 1, fm))


func test_player_mult_table_covers_four_players() -> void:
	var mults: Array = rounds["count"]["player_mult"]
	assert_eq(mults.size(), int(net_cfg["max_players"]))


# ---------------------------------------------------------------- Scrip per player

func test_scrip_is_per_player() -> void:
	Economy.reset([1, 2, 3])
	Economy.award(2, 100)
	assert_eq(Economy.get_scrip(1), 500)
	assert_eq(Economy.get_scrip(2), 600)
	assert_eq(Economy.get_scrip(3), 500)
	assert_false(Economy.spend(3, &"door", 750), "can't spend a teammate's Scrip")
	assert_true(Economy.spend(2, &"door", 600))
	assert_eq(Economy.get_scrip(2), 0)
	assert_eq(Economy.get_scrip(1), 500)


func test_double_scrip_applies_to_everyone() -> void:
	Economy.reset([1, 2])
	Economy.multiplier = 2
	Economy.award(1, 50)
	Economy.award(2, 60)
	assert_eq(Economy.get_scrip(1), 600)
	assert_eq(Economy.get_scrip(2), 620)
	Economy.multiplier = 1


func test_repair_cap_is_per_player() -> void:
	Economy.reset([1, 2])
	for i: int in 60:
		Economy.award_repair(1)
	Economy.award_repair(2)
	assert_eq(Economy.get_scrip(1), 500 + 500)   # capped at 500 from repairs this round
	assert_eq(Economy.get_scrip(2), 510)


# ---------------------------------------------------------------- revive / bleed-out

func test_revive_seconds_and_second_wind() -> void:
	var base: float = float(player_cfg["revive_seconds"])
	assert_almost_eq(CoopState.revive_seconds(base, 1.0), 4.0, 0.001)
	var sw: float = float(GLData.table("perks")["perks"]["second_wind"]["effects"]["revive_speed_mult"])
	assert_almost_eq(CoopState.revive_seconds(base, sw), 4.0 / 2.3, 0.001)   # T-082: 1.74 s with Second Wind (x2.3; GDD §3's 2 s was x2.0)


func test_bleed_out_after_the_timer() -> void:
	var c: CoopState = CoopState.new()
	c.add(1)
	c.add(2)
	var bleed: float = float(player_cfg["bleedout_seconds"])
	assert_true(c.down(2, bleed))
	assert_false(c.down(2, bleed), "can't go down twice")
	var out: Array[int] = []
	for i: int in 44:
		out.append_array(c.tick(1.0))
	assert_true(out.is_empty())
	assert_true(c.is_downed(2))
	out = c.tick(1.5)
	assert_eq(out, [2] as Array[int])
	assert_true(c.is_dead(2))
	assert_false(c.revive(2), "too late once bled out")


func test_bleed_out_pauses_while_reviving() -> void:
	var c: CoopState = CoopState.new()
	c.add(1)
	c.add(2)
	c.down(2, 10.0)
	c.set_reviver(2, 1, true)
	assert_true(c.tick(30.0).is_empty(), "the clock stops while someone holds use")
	assert_almost_eq(c.bleed_left(2), 10.0, 0.001)
	c.set_reviver(2, 3, false)   # someone else letting go doesn't matter
	assert_eq(c.reviver_of(2), 1)
	c.set_reviver(2, 1, false)
	c.tick(4.0)
	assert_almost_eq(c.bleed_left(2), 6.0, 0.001)
	assert_true(c.revive(2))
	assert_true(c.is_alive(2))


func test_bleed_out_does_not_pause_when_disabled() -> void:
	var c: CoopState = CoopState.new()
	c.add(1)
	c.down(1, 5.0)
	c.set_reviver(1, 2, true)
	assert_eq(c.tick(6.0, false), [1] as Array[int])


func test_respawn_next_round() -> void:
	var c: CoopState = CoopState.new()
	for pid: int in [1, 2, 3]:
		c.add(pid)
	c.down(2, 1.0)
	c.tick(2.0)
	c.down(3, 45.0)
	assert_eq(c.respawn_dead(), [2] as Array[int], "only the bled-out come back; the downed stay down")
	assert_true(c.is_alive(2))
	assert_true(c.is_downed(3))


# ---------------------------------------------------------------- game over

func test_game_over_when_everyone_is_down() -> void:
	var c: CoopState = CoopState.new()
	c.add(1)
	c.add(2)
	assert_false(c.everyone_down())
	c.down(1, 45.0)
	assert_false(c.everyone_down(), "one standing is enough")
	c.down(2, 45.0)
	assert_true(c.everyone_down(), "all downed = the match ends, even with bleed-out time left")


func test_game_over_counts_bled_out_as_down() -> void:
	var c: CoopState = CoopState.new()
	c.add(1)
	c.add(2)
	c.down(1, 1.0)
	c.tick(2.0)
	assert_false(c.everyone_down())
	c.down(2, 45.0)
	assert_true(c.everyone_down())


func test_leaving_player_doesnt_block_game_over() -> void:
	var c: CoopState = CoopState.new()
	c.add(1)
	c.add(2)
	c.down(1, 45.0)
	c.remove(2)
	assert_true(c.everyone_down())
	assert_false(CoopState.new().everyone_down(), "an empty match isn't over")


func test_coop_state_round_trips_for_clients() -> void:
	var c: CoopState = CoopState.new()
	c.add(1)
	c.add(2)
	c.down(2, 12.34)
	c.set_reviver(2, 1, true)
	var d: CoopState = CoopState.new()
	d.from_net(c.to_net())
	assert_true(d.is_downed(2))
	assert_true(d.is_alive(1))
	assert_eq(d.reviver_of(2), 1)
	assert_almost_eq(d.bleed_left(2), 12.3, 0.11)


# ---------------------------------------------------------------- host hit validation (D-066)

func test_hit_validation() -> void:
	var shooter: Vector3 = Vector3(0, 0, 0)
	var zombie: Vector3 = Vector3(0, 0, -20)
	var eye: Vector3 = Vector3(0, 1.6, 0)
	var dir: Vector3 = ((zombie + Vector3.UP) - eye).normalized()
	assert_true(NetMatch.validate_hit(shooter, zombie, eye, dir, &"bullet", false, net_cfg))
	# a ray pointing the other way
	assert_false(NetMatch.validate_hit(shooter, zombie, eye, -dir, &"bullet", false, net_cfg))
	# a ray that passes 10 m to the side
	var side: Vector3 = ((zombie + Vector3(10, 1, 0)) - eye).normalized()
	assert_false(NetMatch.validate_hit(shooter, zombie, eye, side, &"bullet", false, net_cfg))
	# a shot that claims to start far from where the shooter is
	assert_false(NetMatch.validate_hit(shooter, zombie, eye + Vector3(30, 0, 0), dir, &"bullet", false, net_cfg))
	# out of range
	assert_false(NetMatch.validate_hit(shooter, Vector3(0, 0, -500), eye, Vector3.FORWARD, &"bullet", false, net_cfg))
	# explosions / melee carry no meaningful ray, only the range checks
	assert_true(NetMatch.validate_hit(shooter, zombie, eye, Vector3.ZERO, &"explosive", false, net_cfg))
	# latency: the host's zombie is a couple of metres off the client's ray
	var lag: Vector3 = zombie + Vector3(1.5, 0, 0)
	assert_true(NetMatch.validate_hit(shooter, lag, eye, dir, &"bullet", false, net_cfg))


# ---------------------------------------------------------------- interpolation

func test_interp_buffer_blends_and_holds() -> void:
	var b: InterpBuffer = InterpBuffer.new()
	assert_false(b.sample(0.0))
	b.push(1000.0, Vector3(0, 0, 0), 0.0, 0.0, 1)
	b.push(1100.0, Vector3(10, 0, 0), 1.0, 0.5, 2)
	assert_true(b.sample(1050.0))
	assert_almost_eq(b.pos.x, 5.0, 0.001)
	assert_almost_eq(b.yaw, 0.5, 0.001)
	assert_almost_eq(b.pitch, 0.25, 0.001)
	b.sample(990.0)
	assert_almost_eq(b.pos.x, 0.0, 0.001)
	# past the newest sample: a short extrapolation, then hold
	b.sample(1150.0)
	assert_almost_eq(b.pos.x, 15.0, 0.001)
	b.sample(5000.0)
	assert_almost_eq(b.pos.x, 20.0, 0.001, "extrapolation is capped")
	# out-of-order samples are ignored
	b.push(1050.0, Vector3(99, 0, 0), 0.0, 0.0, 0)
	b.sample(1100.0)
	assert_almost_eq(b.pos.x, 10.0, 0.001)


func test_interp_yaw_wraps_the_short_way() -> void:
	var b: InterpBuffer = InterpBuffer.new()
	b.push(0.0, Vector3.ZERO, PI - 0.1, 0.0, 0)
	b.push(100.0, Vector3.ZERO, -PI + 0.1, 0.0, 0)
	b.sample(50.0)
	assert_almost_eq(absf(b.yaw), PI, 0.01)


# ---------------------------------------------------------------- inventory replication

func test_inventory_round_trip() -> void:
	var owner: WeaponHolder = WeaponHolder.new()
	owner.mirror = true   # no viewmodel needed for the data side
	owner.setup(null)
	owner.slots = [WeaponInstance.create(&"mp40"), WeaponInstance.create(&"kar98k_up")]
	owner.slots[0].mag = 7
	owner.current_index = 1
	owner.grenades = 3
	var copy: WeaponHolder = WeaponHolder.new()
	copy.mirror = true
	copy.setup(null)
	copy.apply_net(owner.to_net())
	assert_eq(copy.slots.size(), 2)
	assert_eq(copy.slots[0].id, &"mp40")
	assert_eq(copy.slots[0].mag, 7)
	assert_true(copy.slots[1].upgraded)
	assert_eq(copy.current_index, 1)
	assert_eq(copy.grenades, 3)
	assert_eq(owner.net_signature()[0], copy.net_signature()[0])
	owner.free()
	copy.free()


# ---------------------------------------------------------------- online roster with bots (T-138)

func test_bots_in_the_roster_dont_block_ready_and_are_named() -> void:
	var saved: Dictionary = Net.roster.duplicate(true)
	var saved_slots: int = Net.slots
	Net.roster = {1: {"peer": 1, "character": "dutch", "ready": true, "name": "Hosty"},
		2: {"peer": 77, "character": "wren", "ready": false, "name": "Clienta"},
		3: {"peer": 0, "character": "peg", "ready": false, "bot": true, "name": "Bot"}}
	assert_false(Net.all_ready(), "a human who isn't ready holds up the start")
	(Net.roster[2] as Dictionary)["ready"] = true
	assert_true(Net.all_ready(), "a bot never holds up the start")
	var bots: Array[int] = Net.bot_pids()
	assert_eq(bots.size(), 1)
	assert_eq(bots[0], 3)
	assert_eq(Net.human_pids().size(), 2)
	assert_true(Net.is_bot_pid(3))
	assert_false(Net.is_bot_pid(2))
	assert_eq(Net.player_name(2), "Clienta")
	assert_string_contains(Net.player_name(3), "Bot")
	assert_eq(Net.peer_of(3), 0, "a bot has no network peer")
	Net.slots = 3
	assert_eq(Net.max_slots(), 3, "the lobby's max_players caps the slots")
	Net.slots = 9
	assert_eq(Net.max_slots(), int(net_cfg["max_players"]), "never more than net.json allows")
	Net.slots = saved_slots
	Net.roster = saved


func test_offline_is_never_webrtc() -> void:
	assert_false(Net.is_webrtc())
	assert_eq(Net.transport, Net.Transport.ENET)
