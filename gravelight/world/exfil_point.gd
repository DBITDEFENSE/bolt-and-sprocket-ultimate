class_name ExfilPoint
extends Interactable
## The campaign exfil beacon (DECISIONS T-033): a signal lantern on a post with a painted board, spawned by
## MapRoot from the map's json "exfil" block when a campaign run is on (ExfilPoint.spawn). Dormant until the
## exfil round starts; then it lights (beacon + pulse), the Operator announces it, the HUD shows the window
## countdown in the prompt, and the squad has `window_seconds` to vote at it. Hold Use to vote: in co-op every
## living human must vote (bots follow the leader, so they gather here with them); when the vote passes the
## round stops, the dead are cleared, and the transition cutscene plays (ExfilCutscene), then the next map
## loads with everyone's kit (Campaign.snapshot -> Campaign.travel). If the window closes, the campaign
## continues on this map and the beacon lights again `retry_rounds` rounds later, so nobody is soft-locked.
## Co-op: the host decides everything and mirrors the beacon's state; a client votes through the normal
## interact request and asks to skip the cutscene through a whitelisted call (net_callable).
## Local -Z is the front (the side the squad approaches from).

enum State { DORMANT, ACTIVE, DEPARTING, DONE }

var cfg: Dictionary = {}
var state: State = State.DORMANT
var attempt: int = 0
var window_left: float = 0.0
var votes: Dictionary = {}          # pid -> true
var skip_votes: Dictionary = {}     # pid -> true (cutscene skip)
var cutscene: ExfilCutscene = null
var _lamp: OmniLight3D
var _lamp_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _board: Label3D
var _sub: Label3D
var _flare: CPUParticles3D
var _t: float = 0.0
var _warned: bool = false
var _wait_t: float = 0.0


## MapRoot: builds the map's beacon from its json (nothing when the map has no valid "exfil" block).
static func spawn(map: MapRoot) -> ExfilPoint:
	var e: Dictionary = Campaign.exfil_cfg(map.map_id)
	if e.is_empty():
		return null
	var errors: PackedStringArray = Campaign.validate_exfil(e)
	if not errors.is_empty():
		push_warning("[campaign] %s exfil block invalid: %s" % [map.map_id, ", ".join(errors)])
		return null
	var x: ExfilPoint = ExfilPoint.new()
	x.cfg = CousinsRound.adjust_exfil(map.map_id, e, HomageBoss.homage_on())   # HB1: the beacon waits for the Cousins Round
	x.name = "ExfilPoint"
	x.position = Campaign.exfil_position(e)
	x.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
	map.add_child(x)
	return x


func _ready() -> void:
	interact_size = Vector3(1.1, 2.6, 0.7)   # the post and its lamp arm (small, so the player's ray starts outside it)
	interact_offset = Vector3(0.3, 1.3, 0)
	super._ready()
	var body: StaticBody3D = StaticBody3D.new()   # nobody stands inside the post
	body.collision_layer = 1 << 8
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.3, 2.6, 0.3)
	cs.shape = box
	cs.position = Vector3(0, 1.3, 0)
	body.add_child(cs)
	add_child(body)
	add_to_group(&"exfil_points")
	GLBus.round_started.connect(_on_round_started)
	GLBus.flag_changed.connect(_on_flag_changed)
	_refresh_board()


func target_id() -> StringName:
	return StringName(str(cfg.get("target", "")))


func target_name() -> String:
	return Campaign.display_name(target_id())


func next_round() -> int:
	return Campaign.exfil_round_on(cfg, attempt, RoundManager.act_start, RoundManager.has_act())


func is_active() -> bool:
	return state == State.ACTIVE


# ---------------------------------------------------------------- look

func build_greybox() -> void:
	# our post, arm, signal lantern and board (UPDATE_05 section 5, T-094); greybox boxes when the model is absent
	var art: Node3D = WorldArt.instance("exfil_beacon", "Model")
	if art != null:
		add_child(art)
	var post_mat: StandardMaterial3D = greybox_mat(Color(0.3, 0.24, 0.18))
	if art == null:
		add_box(self, Vector3(0.16, 2.6, 0.16), Vector3(0, 1.3, 0), post_mat)
		add_box(self, Vector3(0.9, 0.08, 0.08), Vector3(0.3, 2.45, 0), post_mat)   # the arm
	var hood: StandardMaterial3D = greybox_mat(Color(0.12, 0.12, 0.13))
	if art == null:
		add_box(self, Vector3(0.36, 0.06, 0.36), Vector3(0.7, 2.42, 0), hood)
	_lamp_mat = greybox_mat(Color(1.0, 0.55, 0.2), 0.15)
	var glass: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	glass.mesh = sm
	glass.material_override = _lamp_mat
	glass.position = Vector3(0.7, 2.25, 0)
	add_child(glass)
	var b: Dictionary = Campaign.cfg().get("beacon", {})
	var lc: Array = b.get("light_color", [1.0, 0.5, 0.18])
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(float(lc[0]), float(lc[1]), float(lc[2]))
	_lamp.light_energy = float(b.get("dormant_energy", 0.0))
	_lamp.omni_range = float(b.get("light_range", 11.0))
	_lamp.position = Vector3(0.7, 2.2, 0)
	_lamp.shadow_enabled = false
	add_child(_lamp)
	# the ground ring the squad stands in
	var ring: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.02
	ring.mesh = cm
	_ring_mat = greybox_mat(Color(0.95, 0.45, 0.15), 0.0)
	_ring_mat.albedo_color.a = 0.65
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = _ring_mat
	ring.position = Vector3(0, 0.012, -0.9)
	add_child(ring)
	# the painted board on the post
	var board_mat: StandardMaterial3D = greybox_mat(Color(0.82, 0.78, 0.66))
	if art == null:
		add_box(self, Vector3(1.3, 0.42, 0.05), Vector3(0, 1.75, -0.1), board_mat)
	_board = add_label(self, str(cfg.get("label", "EXFIL")), Vector3(0, 1.84, -0.14), 24, Color(0.2, 0.15, 0.1))
	_sub = add_label(self, "", Vector3(0, 1.66, -0.14), 16, Color(0.3, 0.2, 0.12))
	_flare = CPUParticles3D.new()
	_flare.emitting = false
	_flare.amount = 36
	_flare.lifetime = 1.6
	_flare.position = Vector3(0.7, 2.3, 0)
	_flare.direction = Vector3(0, 1, 0)
	_flare.spread = 25.0
	_flare.initial_velocity_min = 0.6
	_flare.initial_velocity_max = 1.8
	_flare.gravity = Vector3(0, 0.4, 0)
	var em: SphereMesh = SphereMesh.new()
	em.radius = 0.02
	em.height = 0.04
	em.material = greybox_mat(Color(1.0, 0.7, 0.3), 6.0)
	_flare.mesh = em
	add_child(_flare)


func _refresh_board() -> void:
	if _sub == null:
		return
	match state:
		State.DORMANT:
			_sub.text = "to %s  ·  opens at round %d" % [target_name().to_upper(), next_round()]
		State.ACTIVE:
			_sub.text = "to %s  ·  %d:%02d" % [target_name().to_upper(), int(window_left) / 60, int(window_left) % 60]
		_:
			_sub.text = "DEPARTING"


func _process(delta: float) -> void:
	_t += delta
	if state == State.ACTIVE:
		var b: Dictionary = Campaign.cfg().get("beacon", {})
		var k: float = 0.5 + 0.5 * sin(_t * TAU * float(b.get("pulse_hz", 1.4)))
		if _lamp != null:
			_lamp.light_energy = float(b.get("light_energy", 5.0)) * (0.55 + 0.45 * k)
		if _lamp_mat != null:
			_lamp_mat.emission_energy_multiplier = 2.0 + 6.0 * k
		if _ring_mat != null:
			_ring_mat.emission_energy_multiplier = 0.4 + 1.2 * k
		window_left = maxf(0.0, window_left - delta)
		_refresh_board()
		if Net.is_authority():
			_wait_t -= delta
			if not _warned and window_left <= float(Campaign.cfg().get("window_warning_seconds", 20.0)):
				_warned = true
				_hud_banner("EXFIL closes in %d seconds" % int(window_left), 2.5)
				Net.mirror(self, &"_hud_banner", ["EXFIL closes in %d seconds" % int(window_left), 2.5])
			if _wait_t <= 0.0 and not votes.is_empty() and votes.size() < _needed():
				_wait_t = 25.0
				GLVO.play(StringName(str(cfg.get("vo_wait", ""))))
			if window_left <= 0.0:
				_miss()
				Net.mirror(self, &"_miss")


# ---------------------------------------------------------------- rounds

func _on_round_started(round_number: int, _special: bool) -> void:
	if not Net.is_authority() or state != State.DORMANT:
		return
	if round_number >= next_round():
		_activate()
		Net.mirror(self, &"_activate")


## UPDATE 07: the beacon can be lit by a flag before its round (`trigger_flag` in the exfil block; the main egg's
## boarding step sets it through the quest action {"exfil_now": true}, which calls trigger_now on every beacon).
func _on_flag_changed(flag: StringName, value: Variant) -> void:
	var tf: String = str(cfg.get("trigger_flag", ""))
	if tf == "" or String(flag) != tf or not bool(value):
		return
	trigger_now()


## Lights the beacon now whatever the round (authority; mirrored). No-op unless dormant.
func trigger_now() -> void:
	if not Net.is_authority() or state != State.DORMANT:
		return
	_activate()
	Net.mirror(self, &"_activate")


## The beacon lights (host, then every peer). The exfil's zone opens for free when the data says so.
func _activate() -> void:
	state = State.ACTIVE
	votes.clear()
	_warned = false
	_wait_t = 12.0
	window_left = float(cfg.get("window_seconds", 90.0))
	if _flare != null:
		_flare.emitting = true
	_refresh_board()
	AudioDirector.play_3d("buy", global_position + Vector3.UP * 2.0, 2.0)
	_hud_banner("EXFIL AVAILABLE: %s\nHold the beacon to leave for %s  ·  %d s" % [str(cfg.get("label", "the beacon")), target_name(), int(window_left)], 5.0)
	if Net.is_authority():
		if bool(cfg.get("opens_zone", false)):
			_open_zone_doors()
		GLVO.play(StringName(str(cfg.get("vo_open", ""))))
	print("[campaign] exfil beacon lit at round %d (attempt %d, %d s)" % [RoundManager.current_round, attempt, int(window_left)])


## Nobody is locked out of the exfil: the doors into its zone open at no cost (the Operator unbars the way).
func _open_zone_doors() -> void:
	var zone: StringName = StringName(str(cfg.get("zone", "")))
	if zone == &"" or GameState.is_zone_open(zone):
		return
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and not d.is_open and (d.opens_zone == zone or d.also_opens.has(String(zone))):
			d.open(0)
	GameState.open_zone(zone)


## The window closed: the beacon goes dark and the campaign goes on here, next chance in retry_rounds.
func _miss() -> void:
	if state != State.ACTIVE:
		return
	state = State.DORMANT
	attempt += 1
	votes.clear()
	if _flare != null:
		_flare.emitting = false
	if _lamp != null:
		_lamp.light_energy = float((Campaign.cfg().get("beacon", {}) as Dictionary).get("dormant_energy", 0.0))
	if _lamp_mat != null:
		_lamp_mat.emission_energy_multiplier = 0.15
	if _ring_mat != null:
		_ring_mat.emission_energy_multiplier = 0.0
	_refresh_board()
	_hud_banner("Exfil missed. The beacon lights again at round %d." % next_round(), 4.0)
	if Net.is_authority():
		GLVO.play(StringName(str(cfg.get("vo_missed", ""))))
	print("[campaign] exfil window closed; next at round %d" % next_round())


func _hud_banner(text: String, hold: float) -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", text, hold)


# ---------------------------------------------------------------- the vote

## Humans who must vote: everyone on their feet (downed players can't reach the beacon; the bled-out wait).
func _needed() -> int:
	var n: int = 0
	var s: NetMatch = Net.session
	for pid: int in GameState.human_ids():
		if s == null or s.coop.is_alive(pid):
			n += 1
	return maxi(1, n)


## UPDATE 07 (the Kranich's autopilot): an exfil may need a flag before anyone can touch it (`requires_flag`,
## `requires_text`) and may have a first stage (`stage_flag`: the first hold sets it, `stage_prompt`, `stage_hold`,
## `vo_stage`), after which the usual vote follows; `hold_seconds` overrides the vote's hold.
func _needs_flag() -> bool:
	var f: String = str(cfg.get("requires_flag", ""))
	return f != "" and not GameState.has_flag(StringName(f))


func _in_stage() -> bool:
	var f: String = str(cfg.get("stage_flag", ""))
	return f != "" and not GameState.has_flag(StringName(f))


func get_prompt(player: Player) -> String:
	if state != State.ACTIVE:
		return ""
	var key: String = prompt_key(&"interact")
	if _needs_flag():
		return str(cfg.get("requires_text", "Locked"))
	if _in_stage():
		return str(cfg.get("stage_prompt", "Hold [%s]")).replace("%s", key)
	var clock: String = "%d:%02d" % [int(window_left) / 60, int(window_left) % 60]
	var need: int = _needed()
	if votes.has(player.player_id):
		return "Waiting for the squad (%d/%d)  ·  %s" % [votes.size(), need, clock]
	if need > 1:
		return "Hold [%s] to vote: exfil to %s (%d/%d)  ·  %s" % [key, target_name(), votes.size(), need, clock]
	return "Hold [%s] to exfil to %s  ·  %s" % [key, target_name(), clock]


func can_interact(player: Player) -> bool:
	return state == State.ACTIVE and not _needs_flag() and not votes.has(player.player_id) and not player.downed


func hold_time(player: Player) -> float:
	var base: float = float(cfg.get("hold_seconds", Campaign.cfg().get("vote_hold_seconds", 1.5)))
	if _in_stage():
		base = float(cfg.get("stage_hold", base))
	if player != null and GameState.player_has_trait(player.player_id, &"deacon"):
		base *= float((GLData.table("player")["traits"] as Dictionary).get("deacon_work_speed_mult", 0.85))   # Good Hands
	return base


func interact(player: Player) -> void:
	if not Net.is_authority() or state != State.ACTIVE or _needs_flag():
		return
	if _in_stage():
		GameState.set_flag(StringName(str(cfg["stage_flag"])))
		feedback_2d(player, "buy", -2.0)
		if str(cfg.get("vo_stage", "")) != "":
			GLVO.play(StringName(str(cfg["vo_stage"])))
		print("[campaign] exfil stage '%s' done by P%d" % [str(cfg["stage_flag"]), player.player_id])
		return
	votes[player.player_id] = true
	Net.mirror(self, &"_set_votes", [votes.keys()])
	feedback_2d(player, "buy", -2.0)
	print("[campaign] exfil vote by P%d (%d/%d)" % [player.player_id, votes.size(), _needed()])
	if votes.size() >= _needed():
		_depart()


func _set_votes(who: Array) -> void:
	votes.clear()
	for pid: Variant in who:
		votes[int(pid)] = true


# ---------------------------------------------------------------- departure (host / solo)

func _depart() -> void:
	if state != State.ACTIVE:
		return
	state = State.DEPARTING
	if str(cfg.get("done_flag", "")) != "":   # UPDATE 07 (T-114): the egg's step for this transition (the autopilot ripped out)
		GameState.set_flag(StringName(str(cfg["done_flag"])))
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map == null:
		map = get_parent() as MapRoot
	var payload: Dictionary = Campaign.snapshot(map, target_id(), str(cfg.get("cutscene", "")))
	var errors: PackedStringArray = Campaign.validate_payload(payload, GLData.table("weapons"))
	if not errors.is_empty():
		push_warning("[campaign] payload: %s" % ", ".join(errors))
	Campaign.carry = payload
	RoundManager.stop()
	if map.director != null:
		map.director.kill_all(true)
	Net.mirror(self, &"_begin_cutscene", [payload])
	_begin_cutscene(payload)


## Every peer: the round is over for this map; the transition plays (the host's copy decides when it ends).
func _begin_cutscene(payload: Dictionary) -> void:
	state = State.DEPARTING
	Campaign.carry = payload
	skip_votes.clear()
	if _flare != null:
		_flare.emitting = false
	_refresh_board()
	GameState.god_mode = true
	GameState.input_blocked = true
	ProfileSave.unlock_map(target_id())
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		var brain: Node = n.get_node_or_null("Brain")
		if brain != null:
			brain.set_physics_process(false)
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map == null:
		map = get_parent() as MapRoot
	cutscene = ExfilCutscene.new()
	cutscene.name = "ExfilCutscene"
	cutscene.cutscene_id = str(cfg.get("cutscene", ""))
	cutscene.exfil = self
	map.add_child(cutscene)
	print("[campaign] departing %s for %s (%s)" % [map.map_id, target_id(), cutscene.cutscene_id])


## The local human wants to skip (ExfilCutscene, after skip_after_seconds). Solo: now. Co-op: every human.
func request_skip_local() -> void:
	if Net.is_client():
		if Net.session != null:
			Net.session.request_call(self, &"request_skip", [Net.local_player_id()])
		return
	request_skip(Net.local_player_id())


func net_callable() -> Array:
	return ["request_skip"]


func request_skip(pid: int) -> void:
	if not Net.is_authority() or state != State.DEPARTING:
		return
	if GameState.is_bot(pid):
		return
	skip_votes[pid] = true
	var need: int = GameState.human_ids().size()
	Net.mirror(self, &"_set_skip_votes", [skip_votes.keys()])
	if skip_votes.size() >= need:
		finish_travel()
	elif cutscene != null:
		cutscene.refresh_skip()


func _set_skip_votes(who: Array) -> void:
	skip_votes.clear()
	for pid: Variant in who:
		skip_votes[int(pid)] = true
	if cutscene != null:
		cutscene.refresh_skip()


## The cutscene ended (or everyone skipped): load the next map with the payload, or, when the target scene
## is not in this build yet, end the run on the "campaign continues" screen (every peer).
func finish_travel() -> void:
	if not Net.is_authority() or state != State.DEPARTING:
		return
	state = State.DONE
	var payload: Dictionary = Campaign.carry
	if Campaign.scene_exists(target_id()):
		Campaign.travel(payload, get_tree())
		return
	push_warning("[campaign] target map %s has no scene yet (%s): the campaign continues later" % [target_id(), Campaign.scene_for(target_id())])
	Net.mirror(self, &"_show_end", [payload])
	_show_end(payload)


func _show_end(payload: Dictionary) -> void:
	state = State.DONE
	if cutscene != null and is_instance_valid(cutscene):
		cutscene.stop()
	var map: MapRoot = get_tree().current_scene as MapRoot
	if map == null:
		map = get_parent() as MapRoot
	GameState.phase = GameState.Phase.GAME_OVER   # the run is over on this build; the profile commits
	RoundManager.stop()
	AudioDirector.stop_all_music()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var screen: CampaignEndScreen = CampaignEndScreen.new()
	map.add_child(screen)
	screen.show_run(payload, target_name(), map)
