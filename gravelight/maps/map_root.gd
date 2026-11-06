class_name MapRoot
extends Node3D
## Generic map controller. Spawns the player at a PlayerSpawn marker, adds the HUD, zombie director,
## pause and game-over screens, and starts the round loop. Each map scene's root uses this script.
##
## Co-op (M7): one Player per roster slot at PlayerSpawn1..4 (the local one has the camera and HUD, the others
## are puppets with a RevivePoint), plus the NetMatch session. The host waits for every client to finish
## loading before the first round; a client never runs the round loop, it mirrors the host.
##
## AI teammates (T-031): a solo match with GameState.bot_count > 0 spawns bot Players (is_bot, each a free
## survivor), an offline NetMatch as the local co-op session (last stand, revives, bleed-out, spectate) and a
## BotSquad that drives them. Round scaling counts a bot as bots.json scaling.bot_player_weight of a player.

@export var map_id: StringName = &"map00_crossroads"
@export var display_name: String = "Crossroads Inn"
@export var start_zone: StringName = &"TAPROOM"
@export var intro_text: String = ""
@export var quest_files: PackedStringArray = []
@export var power_on_at_start: bool = false
## Per-zone navigation (Map 1): zone -> nav layer bit; bits always walkable; zone adjacency for spawning.
@export var nav_zone_bits: Dictionary = {}
@export var nav_always_bits: Array = []
@export var zone_adjacency: Dictionary = {}
@export var auto_rounds: bool = true
## The play space's footprint on the ground (x, z; T-084, Map 0's edge wall): drops from a kill beyond it (a
## zombie shot in its spawn pocket through the invisible edge) are pulled inside it. Zero size = no edge.
@export var drop_bounds: Rect2 = Rect2()

var player: Player
var players: Dictionary = {}     # pid -> Player (solo: {1: player})
var hud: Hud
var director: ZombieDirector
var pause_menu: PauseMenu
var session: NetMatch = null
var squad: BotSquad = null
var _online: bool = false


## `p` pulled inside drop_bounds by `margin` (unchanged when the map has no bounds or `p` is already inside).
func clamp_inside(p: Vector3, margin: float = 1.5) -> Vector3:
	if drop_bounds.size.x <= 0.0 or drop_bounds.size.y <= 0.0:
		return p
	var q: Vector3 = p
	q.x = clampf(q.x, drop_bounds.position.x + margin, drop_bounds.end.x - margin)
	q.z = clampf(q.z, drop_bounds.position.y + margin, drop_bounds.end.y - margin)
	return q


func _ready() -> void:
	GLSettings.activate()
	Game.set_mode(Game.Mode.GRAVELIGHT)
	get_tree().paused = false
	_online = Net.is_online() and Net.in_match
	GameState.reset_match(map_id, display_name, start_zone)
	GameState.apply_act_physics(RoundManager.act_block_of(map_id))   # Map 4 Act IV: gravity scale, slides, vacuum (T-112)
	GameState.bot_ids = []
	for n: Node in get_tree().get_nodes_in_group(&"bake_only"):
		if n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer = 0   # T-125: navmesh-bake footprints (empty crate spots) never block
	if _online:
		GameState.player_ids = Net.player_ids()
		GameState.bot_ids = Net.bot_pids()   # online bots (T-138): simulated on the host, puppets on the clients
		var chars: Dictionary = {}
		for opid: int in GameState.player_ids:
			chars[opid] = Net.character_of(opid)
		GameState.characters = chars
	else:
		GameState.player_ids = [1]
		_assign_bots()
		Campaign.on_roster(self)   # arriving by exfil: the same survivors keep their ids (T-033)
	director = ZombieDirector.new()
	director.name = "ZombieDirector"
	director.puppet_mode = _online and Net.is_client()
	director.add_to_group(&"director")
	add_child(director)
	if not nav_zone_bits.is_empty():
		director.configure_navigation(nav_zone_bits, nav_always_bits, zone_adjacency)
	ClimbLink.spawn_all(self, map_id, nav_zone_bits)   # authored climb volumes from the map's json (MZ, T-041)
	Muster.begin_match(_online)   # each human's sidearm and Field Habits for this match (T-079), before they spawn
	_spawn_players()
	MapState.attach(self, map_id)   # what the minimap / pause map know this match (Update 04, T-065)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.quit_requested.connect(_to_menu)
	pause_menu.restart_requested.connect(_restart)
	Economy.reset(GameState.player_ids)
	Muster.apply_match_start(players, not Campaign.arriving(map_id))   # Pay Packet Scrip, Field Dressing (T-079)
	GLBus.player_downed.connect(_on_player_downed)
	PerkManager.reset_match()
	Campaign.on_players_spawned(self)   # arriving by exfil: everyone's weapons, Scrip and perks come back (T-033)
	if _online:
		_apply_coop_egg_slots()
		session = NetMatch.new()
		session.name = "NetMatch"
		add_child(session)
		session.setup(self)
		Net.session = session
		var coop_hud: CanvasLayer = (load("res://gravelight/ui/coop_hud.gd") as GDScript).new() as CanvasLayer
		add_child(coop_hud)
		if Net.is_host() and not GameState.bot_ids.is_empty():
			ensure_online_squad()
	elif not GameState.bot_ids.is_empty():
		_start_bot_session()
	JakubCompanion.attach(self)   # the prisoner companion (U02 section 6.2): his cage on Map 0, or he travels with you
	PlayerBot.attach(self)   # player bot mode (T-071): off until F6 / the pause menu / `botmode on` / --botmode
	GLBus.match_started.emit(map_id)
	Campaign.restore_flags(self)   # UPDATE 07 (T-114): the acts' carried flags (london_seen, bomb_*, ...)
	BankBranch.attach(self)   # T-136: the savings bank's interest on every map, a branch on Map 0 and Kaltenbrunn
	MapCompanion.attach(self)   # T-135: one more companion per map (after the flags: Jette follows you between acts)
	ReliefSquad.attach(self)   # T-142: relief squads from the map edge (host / offline; clients get puppets)
	ExtraPeople.attach(self)   # T-143: the extra people (miners, a medic, a switchboard operator, a deserter, a widow, a courier)
	Totenhafen.attach(self)   # T-153: Totenhafen's UPDATE 10 systems (tide v2, ballast v2, the drowned, the searchlight, Letzte Fahrt)
	FirstHints.attach(self)   # T-162: first-time hints (once per profile) and the citations' watcher
	EggModeTag.attach(self)   # T-181: the Easter Egg Mode practice tag (EggMode)
	for q: String in quest_files:
		QuestManager.load_quest(q)
	Campaign.restore_quests(self)   # UPDATE 07 (T-114): the egg's progress from the act before
	_init_crate()
	_spawn_intel.call_deferred()
	if Campaign.active:
		ExfilPoint.spawn(self)   # the campaign's exfil beacon, from this map's json "exfil" block (T-033)
	if power_on_at_start:
		GameState.power_on = true
		GLBus.power_activated.emit.call_deferred()
	AudioDirector.start_ambient()
	ZoneAmbience.attach(self)   # T-145: per-zone beds + one-shots when data/gravelight/ambience/<map>.json exists
	_attach_map_ambience()   # UPDATE 10 (contract C1): the living world from data/gravelight/<map>_ambience.json
	CrucibleRoom.attach(self)   # T-175: the Crucible's room (props, lights, hum, forge fx) from data/gravelight/crucible_rooms.json
	(func() -> void: LampGlow.attach(self)).call_deferred()   # lamp glass dims with its light (T-057)
	ShadowProxies.build(self)   # the static batches' shadows drawn from a few merged depth meshes (T-070)
	var sb: Node = get_node_or_null("StaticBatches")
	if sb != null:   # T-145: batches split into ViewCells visibility groups get proxies per group (hidden with it)
		for vg: Node in sb.get_children():
			if vg.has_meta("vis_group"):
				ShadowProxies.build(self, "StaticBatches/" + String(vg.name))
	if GLSettings.is_compat():   # T-139: the browser / Compatibility profile (no SDFGI / SSIL / SSR / volumetrics, capped shadows)
		print("[WebProfile] %s: %s" % [map_id, str(WebProfile.apply(self))])
		(func() -> void: WebProfile.apply(self)).call_deferred()   # again for what spawns deferred (intel, lamp glow)
	(func() -> void: RenderWarm.run(self)).call_deferred()   # first-use shader stalls paid at load (T-070)
	if _online and Net.is_client():
		session.report_loaded()
		hud.show_banner("Rejoining the match..." if Net.rejoining else "Waiting for the host...", 2.0)
	elif _online and Net.is_host() and GameState.player_ids.size() > 1:
		hud.show_banner("Waiting for everyone to arrive...", 2.0)   # NetMatch calls start_rounds()
	else:
		start_rounds()
		if _online:
			session.begun = true


## The first round's intro timer starts (host / solo).
func start_rounds() -> void:
	RoundManager.start_game(scaled_player_count())
	Campaign.on_rounds_started(self)   # arriving by exfil: the round count continues after an arrival grace (T-033)
	if not auto_rounds:
		RoundManager.stop()
	if intro_text != "":
		hud.show_banner(intro_text, 3.5)


## Client: the host says everyone is in.
func on_net_begin() -> void:
	if intro_text != "":
		hud.show_banner(intro_text, 3.5)


## Players the round scaling sees: humans count 1 each, bots a fraction (BotConfig.scaled_player_count).
func scaled_player_count() -> int:
	var bots: int = GameState.bot_ids.size()
	return BotConfig.scaled_player_count(GameState.player_ids.size() - bots, bots, BotConfig.cfg(), int(GLData.table("net").get("max_players", 4)))


## Solo: the bots the menu asked for take the survivors the human didn't pick (ids 2..).
func _assign_bots() -> void:
	var n: int = BotConfig.clamp_bots(BotConfig.cfg(), GameState.bot_count)
	if n <= 0:
		GameState.characters = {}
		return
	GameState.characters = {1: GameState.character_id}
	for ch: StringName in BotConfig.assign_characters([GameState.character_id], n):
		var pid: int = GameState.player_ids.size() + 1
		GameState.player_ids.append(pid)
		GameState.bot_ids.append(pid)
		GameState.characters[pid] = ch


## Solo with bots: the offline session that owns the co-op life-cycle, the co-op HUD, and the squad's brains.
func _start_bot_session() -> void:
	session = NetMatch.new()
	session.name = "NetMatch"
	add_child(session)
	session.setup(self)
	Net.session = session
	session.begun = true
	var coop_hud: CanvasLayer = (load("res://gravelight/ui/coop_hud.gd") as GDScript).new() as CanvasLayer
	add_child(coop_hud)
	squad = BotSquad.new()
	squad.name = "BotSquad"
	add_child(squad)
	squad.setup(self)


## Online host (T-138): the squad that drives the host's bots (the lobby's fill_bots slots, and a dropped client's
## body while it is away). Created on first need; the session already exists.
func ensure_online_squad() -> BotSquad:
	if squad == null:
		squad = BotSquad.new()
		squad.name = "BotSquad"
		add_child(squad)
		squad.setup(self)
	return squad


## A companion joins a solo match that has no bots (U02 section 6.2): the offline session (his downs, revives and
## bleed-out; the human keeps the solo rules) and an empty BotSquad for his brain. No co-op HUD. Returns the squad.
func ensure_companion_session() -> BotSquad:
	if _online:
		return ensure_online_squad() if Net.is_host() else null   # T-138: companions run on the host online
	if session == null:
		session = NetMatch.new()
		session.name = "NetMatch"
		add_child(session)
		session.setup(self)
		Net.session = session
		session.begun = true
	if squad == null:
		squad = BotSquad.new()
		squad.name = "BotSquad"
		add_child(squad)
		squad.setup(self)
	return squad


func _spawn_players() -> void:
	var local_pid: int = Net.local_player_id() if _online else 1
	for pid: int in GameState.player_ids:
		var p: Player = Player.new()
		p.player_id = pid
		p.is_local = pid == local_pid
		p.is_bot = GameState.is_bot(pid) and not (_online and Net.is_client())   # a client sees the host's bots as puppets
		p.name = "Player%d" % pid
		add_child(p)
		p.global_transform = spawn_transform(pid)
		players[pid] = p
		if p.is_local:
			player = p
		if _online or p.is_bot or not GameState.bot_ids.is_empty():
			var rp: RevivePoint = RevivePoint.new()

			rp.name = "Revive"
			rp.owner_player = p
			p.add_child(rp)
	if player == null:   # can't happen, but never leave the map without a camera
		player = players[GameState.player_ids[0]]


## Spawn marker for a player id: PlayerSpawn<pid> when the map has one, else the first marker.
func spawn_transform(pid: int) -> Transform3D:
	var spawns: Array[Node] = get_tree().get_nodes_in_group(&"player_spawns")
	if spawns.is_empty():
		var n: Node3D = get_node_or_null("PlayerSpawn1") as Node3D
		return n.global_transform if n != null else Transform3D.IDENTITY
	var want: String = "PlayerSpawn%d" % pid
	for s: Node in spawns:
		if s.name == want:
			return (s as Node3D).global_transform
	return (spawns[(pid - 1) % spawns.size()] as Node3D).global_transform


## Co-op: each player's own profile decides their Map 1 egg perk slot (the roster carries it), D-069.
func _apply_coop_egg_slots() -> void:
	if not Net.is_host() or map_id != &"map01_kaltenbrunn":
		return
	for pid: int in GameState.player_ids:
		if bool((Net.roster.get(pid, {}) as Dictionary).get("egg_slot", false)):
			PerkManager.add_bonus_slot(pid)


## The story-prop / intel key of a map that keeps it in its json ("map_key", Map 4's acts: "4a".."4d"); "?" when none.
static func json_map_key(id: StringName) -> String:
	var path: String = "res://data/gravelight/%s.json" % String(id).get_slice("_", 0)
	if not FileAccess.file_exists(path):
		return "?"
	return str(GLData.load_json(path).get("map_key", "?"))


## 3-5 Intel Archive pickups per match at random reachable spots inside the map's zones (not already found).
## Intel is personal: in co-op every peer places and finds its own (IntelPickup.net_local).
## Rows marked "placement": "fixed" (LORE.md section 13.1) are hand-placed StoryProps instead, always present.
func _spawn_intel() -> void:
	if map_id == &"test_range":
		return
	var map_key: String = "0" if map_id == &"map00_crossroads" else ("1" if map_id == &"map01_kaltenbrunn" else ("2" if map_id == &"map02_totenhafen" else json_map_key(map_id)))
	StoryProp.spawn_all(self, map_key)
	var pool: Array = []
	for row: Dictionary in GLData.load_json("res://data/gravelight/intel.json").get("intel", []):
		var m: String = str(row.get("map", ""))
		var id: String = str(row["id"])
		if str(row.get("placement", "")) in ["fixed", "companion", "quest"]:   # companion: filed by Jakub (his letter); quest: filed by a quest step (T-156) or an egg (T-153); never spawned
			continue
		if (m == map_key or m == "all") and not ProfileSave.has_intel(id):
			if id == "INT_GEN_02" and ProfileSave.dossier_level(&"peg") < 5:
				continue
			pool.append(row)
	pool.shuffle()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rid: RID = get_world_3d().navigation_map
	var count: int = mini(pool.size(), randi_range(3, 5))
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < 200:
		tries += 1
		var p: Vector3 = NavigationServer3D.map_get_random_point(rid, 0x7FFFFFFF, true)
		if ZoneVolume.zone_at(get_tree(), p) == &"" or p.distance_to(player.global_position) < 6.0:
			continue
		var row: Dictionary = pool[placed]
		var n: IntelPickup = IntelPickup.new()
		n.intel_id = StringName(str(row["id"]))
		n.title = str(row.get("title", "Intel"))
		n.kind = str(row.get("type", "DOC"))
		n.name = "Intel_%s" % str(row["id"])
		add_child(n)
		n.global_position = p
		placed += 1


func _init_crate() -> void:
	var spots: Array = get_tree().get_nodes_in_group(&"crate_spots")
	if spots.is_empty():
		return
	spots.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("spot_index")) < int(b.get("spot_index")))
	if not (_online and Net.is_client()):
		CrateManager.choose_start(spots)   # a client gets the spot from the host's state
	for s: Node in spots:
		s.call("refresh")


func _exit_tree() -> void:
	RoundManager.stop()
	AudioDirector.stop_all_music()
	if GLBus.player_downed.is_connected(_on_player_downed):
		GLBus.player_downed.disconnect(_on_player_downed)
	if session != null:
		session.shutdown()


func _player_spawn() -> Node3D:
	var spawns: Array[Node] = get_tree().get_nodes_in_group(&"player_spawns")
	if spawns.is_empty():
		return get_node_or_null("PlayerSpawn1") as Node3D
	return spawns[0] as Node3D


func _on_player_downed(pid: int) -> void:
	if not Net.is_authority():
		return   # a client hears this relayed from the host, which already decided
	if JakubCompanion.is_companion_pid(pid) or MapCompanion.is_companion_pid(pid):
		if session != null:
			session.coop_downed(pid)   # a companion's own bleed-out clock, in solo too (he is no player)
		return
	# Solo Second Wind: self-revive and keep the other perks.
	if GameState.is_solo() and PerkManager.try_self_revive(pid):
		player.begin_self_revive(float(GLData.table("player").get("self_revive_seconds", 3.5)))
		return
	if not GameState.is_solo() and session != null:
		session.coop_downed(pid)   # co-op: perks lost, bleed-out clock, game over when nobody is standing
		return
	PerkManager.on_player_downed(pid)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Player).is_alive() and not (n as Player).is_companion:
			return   # (a companion standing never keeps a solo match going)
	_game_over()


func _game_over() -> void:
	if GameState.phase == GameState.Phase.GAME_OVER:
		return
	var st: Dictionary = GameState.stats.duplicate()
	st[&"players"] = GameState.player_stats.duplicate(true)   # T-144: the ledger's per-player rows
	if session != null and Net.is_host():
		Net._rpc_game_over.rpc(st, GameState.elapsed_seconds())
	show_game_over(st, GameState.elapsed_seconds())


## Ends the match on this peer (the host's call, or the host's word on a client).
func show_game_over(stats: Dictionary, elapsed: float) -> void:
	if GameState.phase == GameState.Phase.GAME_OVER:
		return
	GameState.phase = GameState.Phase.GAME_OVER
	RoundManager.stop()
	AudioDirector.stop_all_music()
	AudioDirector.play_stinger("game_over", 0.0)
	GLBus.game_over.emit(stats)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var go: GameOverScreen = GameOverScreen.new()
	add_child(go)
	go.show_stats(stats, display_name, elapsed)
	go.restart_requested.connect(_restart)
	go.menu_requested.connect(_to_menu)


func _restart() -> void:
	get_tree().paused = false
	if _online:
		if Net.is_host():
			Net.start_match(Net.map_scene)   # everyone again, same map
		return
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	GameState.phase = GameState.Phase.MENU
	if _online:
		if Net.is_host():
			Net.return_to_lobby()   # everyone back to the lobby
			return
		Net.leave("")
	get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn")


## UPDATE 10 contract C1: every map may have a living-world file next to Map 0's (`<prefix>_ambience.json`, where the
## prefix is the map id up to its first underscore: map01, map02, map04a...). Map 0's scene already carries its own
## MapAmbience node from gen_map00 (config_path map00_ambience.json), so this only adds one when the scene has none and
## the file exists. Presentation only: MapAmbience never touches gameplay.
func _attach_map_ambience() -> void:
	if get_node_or_null(^"MapAmbience") != null:
		return
	var prefix: String = str(map_id).get_slice("_", 0)
	var path: String = "res://data/gravelight/%s_ambience.json" % prefix
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return
	var amb: MapAmbience = MapAmbience.new()
	amb.name = "MapAmbience"
	amb.config_path = path
	add_child(amb)

