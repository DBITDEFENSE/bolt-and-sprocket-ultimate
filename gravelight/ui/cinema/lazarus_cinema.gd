class_name LazarusCinema
extends Node
## T-194 (UPDATE 11 "LAZARUS", work order §5): the LAZARUS cutscenes in a match, host-driven the way the campaign
## hops are (ExfilCutscene, T-033/T-184): every peer plays its own CinemaReel on its own clock; the host decides what
## plays and when (`Net.mirror`), a skip is the co-op vote (every human holds [interact]; a client asks the host
## through a whitelisted call, `net_callable`), and the host's end ends everyone's (a client whose copy is done first
## waits on black). Data: cutscenes_lazarus.json "hooks"; the rule is `plan()` (pure, unit-tested):
##   a new campaign on its first map (Map 0)       FOURTH DAY, then GRAVELIGHT ONE, then the match start as built
##   the campaign arriving at Kaltenbrunn           STAUB, then the arrival grace and its banner
##   a match on Map 0 / Kaltenbrunn outside the campaign: their cutscene the first time this profile starts one
##   ("standalone_rule": once | always | never), the Archive replays them any time
##   a dev start mid-campaign (begin_at a later act), a campaign arrival anywhere else: nothing
## While a reel plays the round's intro clock is held (RoundManager.break_left) on the host, the players' input is
## blocked, and Map 0's opening (InnOpening: its settled-view clock, its title card) waits for it, so the opening
## then runs exactly as built from the player's own eyes. Also the Moscow 1953 card after KÜNDIGUNG (`epilogue`).
## Headless runs (unit tests, the smokes, the tools) never start one on their own: `force` turns them on.

signal ended(ids: Array)

const NODE_NAME: String = "LazarusCinema"

static var force: bool = false
## Tools: these ids instead of the plan on the next match start (the smokes, the clip tool).
static var force_ids: Array = []
## T-203: the next match start plays nothing (Play.bat's quick map buttons drop you straight in; the cutscenes have
## their own buttons and play in a campaign). force_ids wins over it.
static var skip_next: bool = false

var reel: CinemaReel = null
var playing: Array = []
var skip_votes: Dictionary = {}
var history: Array = []          # ids played (or skipped) on this map
var _hold: float = -1.0
var _hold_set: bool = false
var _was_blocked: bool = false
var _banner: String = ""
var _on_done: Array[Callable] = []


static func enabled() -> bool:
	return force or DisplayServer.get_name() != "headless"


static func hooks() -> Dictionary:
	return CinemaLibrary.data().get("hooks", {})


## Every peer (MapRoot._ready): the node the host's calls land on, at the same path everywhere.
static func attach(map: Node) -> LazarusCinema:
	var n: LazarusCinema = map.get_node_or_null(NODE_NAME) as LazarusCinema
	if n != null:
		return n
	n = LazarusCinema.new()
	n.name = NODE_NAME
	map.add_child(n)
	return n


static func of(map: Node) -> LazarusCinema:
	return map.get_node_or_null(NODE_NAME) as LazarusCinema if map != null else null


## Pure: which cutscenes a match start plays. ctx: {campaign, arriving_from ("" = not an arrival), fresh_start (a
## campaign begun on its first map at round 1), seen (ids this profile has seen)}.
static func plan(map_id: String, ctx: Dictionary, cfg: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var h: Dictionary = cfg.get(map_id, {})
	if h.is_empty():
		return out
	var from: String = str(ctx.get("arriving_from", ""))
	var ids: Array = []
	if bool(ctx.get("campaign", false)):
		if from != "":
			ids = (h.get("arrival_from", {}) as Dictionary).get(from, [])
		elif bool(ctx.get("fresh_start", false)):
			# T-203: the prologue opens the first campaign a profile starts (not the menu); then the campaign's own
			ids = []
			var seen0: Array = ctx.get("seen", [])
			for f: Variant in h.get("campaign_first", []):
				if not seen0.has(str(f)):
					ids.append(f)
			ids.append_array(h.get("campaign_start", []))
	else:
		var rule: String = str(h.get("standalone_rule", "once"))
		var seen: Array = ctx.get("seen", [])
		for id: Variant in h.get("standalone", []):
			if rule == "always" or (rule == "once" and not seen.has(str(id))):
				ids.append(id)
	for id2: Variant in ids:
		out.append(str(id2))
	return out


## MapRoot.start_rounds, before Campaign.on_rounds_started consumes the arrival: what this start is.
static func context(map: MapRoot) -> Dictionary:
	var arr: Dictionary = Campaign._arrival
	var from: String = str(arr.get("from", "")) if not arr.is_empty() and str(arr.get("to", "")) == String(map.map_id) else ""
	var fresh: bool = Campaign.active and from == "" and String(map.map_id) == String(Campaign.first_map()) \
		and int(Campaign._pending_start.get("round", 1)) <= 1
	return {"campaign": Campaign.active, "arriving_from": from, "fresh_start": fresh, "round": int(arr.get("round", 0)),
		"seen": ProfileSave.profile.get("cutscenes_seen", [])}


## MapRoot.start_rounds (the host / solo), after the round's intro has been set: plays what the plan says.
static func on_rounds_started(map: MapRoot, ctx: Dictionary) -> void:
	var n: LazarusCinema = of(map)
	if n == null:
		return
	if CinemaTheatre.replay_id != "":
		n._replay_exfil(map)
		return
	var skip: bool = skip_next and force_ids.is_empty()
	skip_next = false
	if skip or not enabled():
		return
	var ids: Array[String] = []
	if not force_ids.is_empty():
		for f: Variant in force_ids:
			ids.append(str(f))
		force_ids = []
	else:
		ids = plan(String(map.map_id), ctx, hooks())
	if ids.is_empty():
		return
	if str(ctx.get("arriving_from", "")) != "":
		n._banner = str(Campaign.cfg().get("arrival_banner", "%s\nRound %d")) % [map.display_name.to_upper(), Campaign.arrival_round(int(ctx.get("round", 0)))]
	n.begin(ids)


## The host / solo: plays `ids` on every peer.
func begin(ids: Array) -> void:
	if not Net.is_authority() or reel != null:
		return
	Net.mirror(self, &"_net_begin", [ids])
	_begin(ids)


func _net_begin(ids: Array) -> void:
	_begin(ids)


func _begin(ids: Array) -> void:
	if reel != null:
		return
	var map: MapRoot = get_parent() as MapRoot
	playing = ids.duplicate()
	skip_votes.clear()
	_was_blocked = GameState.input_blocked
	GameState.input_blocked = true
	_hold_set = false
	reel = CinemaReel.play(self, ids, {"map": map, "speed": Campaign.cutscene_speed, "roster": _roster(map),
		"auto_skip": not (Net.is_online() and GameState.human_ids().size() > 1), "hold_at_end": Net.is_client()})
	reel.cut_started.connect(func(_i: int, _id: String) -> void:
		skip_votes.clear()
		_refresh_skip())
	reel.cut_ended.connect(func(_i: int, id: String, _s: bool) -> void:
		history.append(id)
		CinemaTheatre.note_seen(id))
	reel.skip_pressed.connect(request_skip_local)
	reel.finished.connect(_on_reel_finished)
	print("[cinema] %s plays %s (%s)" % [String(map.map_id) if map != null else "?", ", ".join(PackedStringArray(ids)), "host" if Net.is_host() else ("client" if Net.is_client() else "solo")])


## The passengers for GRAVELIGHT ONE: the humans in player-id order, then the bots (CinemaLibrary.seat_roster fills
## the four seats).
static func _roster(map: MapRoot) -> Array:
	var out: Array = []
	var humans: Array[int] = GameState.human_ids()
	humans.sort()
	for pid: int in humans:
		out.append(String(GameState.character_of(pid)))
	var bots: Array = GameState.bot_ids.duplicate()
	bots.sort()
	for b: Variant in bots:
		out.append(String(GameState.character_of(int(b))))
	if out.is_empty() and map != null:
		out.append(String(GameState.character_id))
	return out


func _process(_delta: float) -> void:
	if reel == null or not Net.is_authority():
		return
	if not _hold_set:
		_hold_set = true
		_hold = RoundManager.break_left
	if RoundManager.state == RoundManager.State.BREAK:
		RoundManager.break_left = maxf(RoundManager.break_left, maxf(0.5, _hold))   # the intro waits for the reel


# ---------------------------------------------------------------- skip (the co-op vote)

## The local human held [interact]. Solo (or alone online): the reel skipped already. Co-op: a vote for this cut.
func request_skip_local() -> void:
	if reel == null:
		return
	if not Net.is_online() or GameState.human_ids().size() <= 1:
		return
	if Net.is_client():
		if Net.session != null:
			Net.session.request_call(self, &"request_skip", [Net.local_player_id(), reel.index])
		return
	request_skip(Net.local_player_id(), reel.index)


func net_callable() -> Array:
	return ["request_skip"]


func request_skip(pid: int, cut_i: int) -> void:
	if not Net.is_authority() or reel == null or reel.index != cut_i or GameState.is_bot(pid):
		return
	skip_votes[pid] = true
	Net.mirror(self, &"_set_skip_votes", [skip_votes.keys()])
	if skip_votes.size() >= GameState.human_ids().size():
		Net.mirror(self, &"_net_skip", [cut_i])
		_net_skip(cut_i)
	else:
		_refresh_skip()


func _set_skip_votes(who: Array) -> void:
	skip_votes.clear()
	for p: Variant in who:
		skip_votes[int(p)] = true
	_refresh_skip()


func _net_skip(cut_i: int) -> void:
	if reel != null and reel.index == cut_i:
		reel.skip_current()


func _refresh_skip() -> void:
	if reel == null or reel.director == null or reel.director.overlay == null:
		return
	var humans: int = GameState.human_ids().size()
	reel.director.overlay.skip_note = "(%d/%d ready)" % [skip_votes.size(), humans] if Net.is_online() and humans > 1 else ""


# ---------------------------------------------------------------- the end

func _on_reel_finished() -> void:
	if Net.is_authority():
		Net.mirror(self, &"_net_end")
	_end_local()


## The host's reel is over: so is this one (a client still playing, or waiting on black).
func _net_end() -> void:
	if reel != null and not reel.done:
		reel.end_now()   # (its finished signal runs _end_local)
	elif reel == null and not _on_done.is_empty():
		_run_done()


func _end_local() -> void:
	reel = null
	GameState.input_blocked = _was_blocked
	var map: MapRoot = get_parent() as MapRoot
	if _banner != "" and map != null and map.hud != null:
		map.hud.show_banner(_banner, 4.0)
	_banner = ""
	ProfileSave.save_profile()
	var ids: Array = playing
	playing = []
	ended.emit(ids)
	_run_done()


func _run_done() -> void:
	var cbs: Array[Callable] = _on_done.duplicate()
	_on_done.clear()
	for c: Callable in cbs:
		if c.is_valid():
			c.call()


func is_playing() -> bool:
	return reel != null


## The Moscow 1953 card after KÜNDIGUNG's credits (cancel_ending.gd): plays it (the host's call; a client waits for
## the host's), then `then` (the end screen). A peer whose host never sends it goes on after `wait` seconds.
static func epilogue(map: Node, then: Callable, wait: float = 45.0) -> void:
	var n: LazarusCinema = of(map)
	if n == null or not enabled() or not CinemaLibrary.has_cut("epilogue_1953"):
		then.call()
		return
	if n.history.has("epilogue_1953") and n.reel == null:
		then.call()
		return
	n._on_done.append(then)
	if Net.is_authority():
		n.begin(["epilogue_1953"])
	elif n.is_inside_tree():
		n.get_tree().create_timer(wait).timeout.connect(func() -> void:
			if is_instance_valid(n) and n.reel == null and not n._on_done.is_empty():
				n._run_done())


# ---------------------------------------------------------------- the Archive's replay of a campaign hop

func _replay_exfil(map: MapRoot) -> void:
	var cut_id: String = CinemaTheatre.replay_id
	CinemaTheatre.replay_id = ""
	RoundManager.stop()
	if map.director != null:
		map.director.kill_all(true)
	GameState.god_mode = true
	GameState.input_blocked = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if not is_instance_valid(map):
			return
		var ec: ExfilCutscene = ExfilCutscene.new()
		ec.name = "ExfilCutscene"
		ec.cutscene_id = cut_id
		map.add_child(ec)
		var back: Callable = func() -> void:
			GameState.input_blocked = false
			GameState.god_mode = false
			CinemaTheatre.open_gallery = true
			Campaign.reset()
			get_tree().change_scene_to_file.call_deferred(CinemaTheatre.MENU)
		ec.ended.connect(back, CONNECT_ONE_SHOT)
		ec.skipped.connect(back, CONNECT_ONE_SHOT))
