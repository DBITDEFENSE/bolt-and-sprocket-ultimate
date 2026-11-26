extends Node
## Performance check for Update 04 section 3 (DECISIONS T-069): Map 0 at round 15 with the minimap on, 3 bots +
## Jakub, 24 zombies (kept alive, so the squad fires the whole time), and marks in play (3 personal marks, a Danger
## mark, a Defend order and a Buy order: the in-world chalk X markers, the minimap pins, the bots' order work).
## Then the pause map opened (solo: the world frozen) to price the MAP tab itself.
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/perf_marks.tscn
## `-- --no-marks` runs the same without any mark (the A/B); `--preset=medium` (or low) measures another graphics preset. Vsync is off; it prints average FPS, the worst frame, the 1% low, the minimap's cost and the brains' cost.
## It always lists the frames over 40 ms. `-- --breakdown` adds the breakdown (T-070): the engine's times
## (the busiest second's scripts' _process and _physics_process, navigation; per frame the renderer's CPU and the
## GPU), the physics steps per frame, draw calls, a census of lights / geometry / areas, the shadowed lights (and
## which of them move), and for every slow frame what happened in it (pipeline compiles by kind, physics steps, the
## nodes that entered the tree); `--compiles` lists every frame that compiled a pipeline. Its rendering-server
## reads cost about 1 ms a frame and stall a separate render thread, so the headline numbers come from a plain run.
## `-- --probe` also times every scripted node's _process/_physics_process by script (it takes the nodes off the
## engine's own loop and calls them itself, so the totals run a little higher than a plain run): use it to find
## which scripts cost what, not for the headline numbers.
## T-139 (UPDATE 09 section 2d): `--map=<map id>` measures another map (map01_kaltenbrunn, map02_totenhafen,
## map04a_thalbach ... map04d_mondlicht; the default is Map 0); `--preset=web` the browser preset;
## `--no-webprofile` keeps WebProfile off on the Compatibility renderer (the before / after of the profile). The
## census then also lists the shadowed omni / spot lights per zone (contract C4 budget: 6 per zone).
## T-237 (the bots' frame cost and hitches): `--hitch` (run it with the engine flag `--fixed-fps 60` before the `--`,
## as tools/bot_perf.sh does: every frame is then one physics tick + one process step with no sleep, so a frame's
## wall time is the CPU work of one 60 FPS frame) keeps every frame's wall time and every script group's time per
## tick, and prints the distribution (p50 / p95 / p99 / worst, frames over 8 / 16.7 / 20 / 33 ms), the same per
## script, and the worst ticks with what ran in them (which brain thought, its action, BotProf's sections).
## `--bots=N` (0-3), `--no-companions` (no Jakub, the map's companion left waiting), `--ai=off|squad|local` (the
## planner bot), `--secs=N` (the sampled window, 15 by default), `--live` (the round keeps running: kills, spawns).
## `--round=N` sets the round (15 by default); the hitch report ends with the 1 % low, a census of what the round
## left lying about (corpses, ragdoll bones, rigid bodies, decals) and the planner bot's ask counts.
## `--ab=no_piece_warm` leaves the zombies' severed pieces to be cut in the frame that first needs each (the
## before of ZombieBody.warm_pieces, docs/perf/movement_perf_2026-11.md). `--ab=no_view_lod` (T-265) animates the
## zombies by distance only (the before of the camera's-view rate). `--vo-async` (T-265) starts voice lines as
## the windowed game does: when a loader thread has brought the file (a headless run loads it on the spot). `--seed=N` seeds the global random
## number generator before the map loads (a `--live` round then starts from the same rolls; it still plays out
## differently run to run, the loader threads' timing is not seeded).
## T-266 (the render census): `--views=<capture set>[,<set>]` stands the player at every distinct camera of those sets
## of data/gravelight/capture_cams.json in turn (the 24 zombies in a block in front of the camera, the bots behind it),
## lets each view settle and prints one `[view]` line: what the renderer drew in the colour pass and in the shadow
## passes (objects, draw calls, triangles: zeros headless) and a census of what stands in the camera's frustum (mesh
## instances, surfaces, skinned meshes, lights, shadowed lamps and their shadow views under ShadowBudget, the sun's
## cascades, shadow casters in reach of a lamp that has its shadow, particle systems, decals, transparent surfaces,
## materials and shaders). `--views-max=N` samples at most N of them evenly, `--hour=H` holds the day at hour H (`--hours=0,12`: the views once per hour in one run)
## (DayCycle.hold_hour; nothing on a map without the day), `--views-only=a,b` keeps the named cameras. It then quits.
## `--t266-ab` goes through the views twice in the one run: first with T-266's render passes switched off
## (RenderTune.set_off: the lines read "<preset>/before"), then with them on; `--t266-ab=proxies:props:occlusion+sun+lights`
## switches them on in those steps, each view counted in every step before the next view (a line reads "<preset>/-<what is still off>"); `--t266-off[=a,b]` runs without them.
## `--cheap` (software rendering under WSL: a High frame takes a minute there) makes the pixels cheap without
## changing what is drawn: the 3D scale 0.25, no MSAA / TAA / FXAA, SDFGI / SSIL / SSAO / SSR / volumetric fog / glow
## off, the shadow atlases 256 px. Objects, draw calls, lights and shadow views are the same as without it (mesh LODs
## are picked for the smaller picture, so triangles read lower than at full size: compare like with like).
## T-265 (the scripts' cost per tick): `--tank` parks the round-30 Sherman and lets it cover the yard (ShermanEvent
## .force_assist: the machine gun and the 75 mm on the dead it can see; a map without the event ignores it; with
## `--live --round=30` the round's own arrival and assault run instead and the flag is not needed), `--hour=H`
## holds the day at that hour (DayCycle.hold_hour: 12 is noon), `--boss` makes the set round a Foreman round (with
## `--live`), `--corpses` kills and respawns four of the kept 24 every second (bodies, ragdolls, gore and the
## director's refill all the time: what a late round's killing costs, at a fixed rate). `--probe-all` takes the
## probe's walk from the tree's root, not the map (the autoloads and the HUD layers outside the map count too), and
## the hitch report then splits the frame's time outside the scripts into the gap after the physics scripts (the
## physics and navigation servers' step) and the gap after the process scripts (animation, skeletons, audio, draw).
## T-281 (the lag that grows with the zombie count): `--zombies=N` keeps N zombies up instead of 24 (the pool grows
## for the bench when N is over its 32), `--mix=high` makes the horde a late round's: run / sprint tiers, every 5th a
## crawler, every 6th a burning fire zombie of the Sherman's round (its light, flames and burst; the burst kills it),
## `--kills=K` kills K of them a second spread over the second (a ragdoll and the death's listeners each, every
## damage kind in turn) and the bench puts the dead back so N stay up. The report gains a `[t281]` line: deaths,
## ragdolls built, the navigation and physics servers' counts, and the zombies' share per zombie. `--flip=<name>`
## switches one thing off and on every second inside the one run (the first 15 frames after each switch are not
## counted) and reports the frame, the scripts and the two gaps for each side apart: an A/B from one map load whose
## two sides share the machine's load second by second. Names: `t281` (Zombie.t281_opt, this task's changes) and the
## diagnostic `z_no_zcollide`, `z_no_avoid`, `z_no_dead_areas`.
## T-283 (phase 2): `--flip=t283` (Zombie.t283_opt, all of phase 2's zombie changes), `t283_skel`, `t283_rays`,
## `t283_lod` (one part each), `--ab=t283_off` (the build without them); the diagnostic `z_no_areas` (every hitbox
## area of the horde out of the physics space: what the 13 live ones cost). The report gains the frames at each
## animation rate (`[t283] animation rate`).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const SPIKE_MS: float = 40.0
const PerfViews: GDScript = preload("res://gravelight/tools_src/perf_views.gd")

var _map: MapRoot
var _t: float = 0.0
var _samples: PackedFloat32Array = []
var _map_samples: PackedFloat32Array = []
var _phase: int = 0
## per-frame engine stats during the in-play window: name -> running sum, and the frame count
var _sum: Dictionary = {}
var _n: int = 0
var _phys_frames: int = 0
var _spikes: PackedStringArray = []
var _node_count: int = 0
var _compiles: Vector4i = Vector4i.ZERO
var _hitch: bool = "--hitch" in OS.get_cmdline_user_args()
var _probe: bool = _hitch or "--probe" in OS.get_cmdline_user_args()
var _live: bool = "--live" in OS.get_cmdline_user_args()
var _companions: bool = not ("--no-companions" in OS.get_cmdline_user_args())
var _round: int = 15   # `--round=N`: the round the scene is set to (what grows with the round)
var _t_end: float = 24.0
var _hour: float = -1.0   # `--hour=H` (T-265): the day held there
var _kill_t: float = 0.0  # `--corpses`: the time to the next four kills
var _probe_all: bool = "--probe-all" in OS.get_cmdline_user_args()
## --probe-all: the end of the last physics / process script pass, and the gaps to the next pass (microseconds)
var _phys_end: int = 0
var _proc_end: int = 0
var _gap_phys: PackedInt32Array = []
var _gap_proc: PackedInt32Array = []
var _gap_worst: Array = []   # [us, text]: the longest gaps after the physics scripts, with what the servers did
var _nav_iter: int = -1      # the navigation map's iteration (it counts the map's rebuilds)
var _nav_syncs: int = 0
var _gap_skip: int = 0       # the probe's own tree walk inside the current gap (taken off it)
var _win_frame: int = -1     # the physics frame the sampled window began at
## --hitch: wall microseconds per frame, the scripts' microseconds per physics tick, the worst ticks [us, text]
var _wall: PackedInt32Array = []
var _wall_prev: int = 0
var _skip_us: int = 0
var _tick_tot: PackedInt32Array = []
var _proc_tot: PackedInt32Array = []
var _worst: Array = []
var _calib: PackedInt32Array = []
var _breakdown: bool = _probe or "--breakdown" in OS.get_cmdline_user_args() or "--compiles" in OS.get_cmdline_user_args()
## --probe: script file -> {"proc": [nodes], "phys": [nodes], "us_proc": float, "us_phys": float}
var _groups: Dictionary = {}
var _probe_scan_t: float = 0.0
var _probe_frames: int = 0
var _probe_pframes: int = 0
var _census_done: bool = false
var _lights: Array = []   # [light, position at the census]: which shadowed lights move
## nodes that entered the tree since the last frame and in the frame before it (named in a spike's line)
var _added: PackedStringArray = []
var _added_prev: PackedStringArray = []
## `-- --ab=a,b` experiments (diagnosis only, they change what is drawn or run): hide_zombies, no_shadows,
## no_omni_shadows, no_dir_shadows, no_sdfgi, no_fog, no_anim, no_ssao, no_glow, no_lights, no_shadow_proxy,
## hide_movers (zombies and players hidden), omni_dp (dual-paraboloid omni shadows), no_spot_shadows, no_post (T-208)
var _ab: PackedStringArray = []
var _map_path: String = MAP
## T-220: `--pos=x,y,z,yaw` stands the player there once the 24 are up (the Kranich's wing walk: -80,3.4,21,90), with
## the flight's tilts calmed (FlightSky.calm) so the measured view never moves; empty = the spawn, as before
var _pos: PackedFloat32Array = []
const QUICK_FRAMES: int = 6
## T-139: `--quick` (software GL under Xvfb, a frame a second or slower): census at 6 s, then 6 frames sampled, quit
## (no pause-map phase). Counts (draw calls, triangles, lights) are what it is for, not timings.
var _quick: bool = "--quick" in OS.get_cmdline_user_args()
## T-266: the views still to visit [{name, pos, yaw, pitch}], the one being measured, frames spent on it
var _views: Array = []
var _views_on: bool = false
var _view_i: int = -1
var _view_f: int = 0
var _view_acc: Dictionary = {}
var _hours: PackedFloat32Array = []   # `--hours=0,12`: the views once per hour, in one run
var _ab_t266: bool = false   # `--t266-ab[=a+b:c]`: the views with T-266's passes off, then switched on step by step, in one run
var _ab_steps: Array = []    # the features switched on at each step after "before"
var _states: Array = []      # [{tag, off: PackedStringArray, rows}]: every view is counted in each of them
var _state_i: int = 0
var _view_settle: int = 9
## T-281: `--zombies=N`, `--mix=high`, `--kills=K` (see the header)
var _zcount: int = 24
var _mix: String = ""
var _kill_rate: float = 0.0
var _kill_acc: float = 0.0
var _kill_i: int = 0
var _refill_t: float = 0.0
var _deaths: int = 0
var _spawned: int = 0
var _flip: String = ""           # `--flip=<name>`
var _flip_on: bool = true        # the side being run now (on = the thing as built)
var _flip_f: int = 0             # frames since the last switch
var _flip_s: Dictionary = {}     # "<key>/<on|off>" -> Array of microseconds


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ab="):
			_ab = a.substr(5).split(",")
		elif a.begins_with("--preset="):   # low / medium / high (the default) / web
			GLSettings.values["graphics_preset"] = a.substr(9)
			for k: Variant in (GLSettings.PRESETS.get(a.substr(9), {}) as Dictionary).keys():   # T-139: the individual settings too
				GLSettings.values[str(k)] = GLSettings.PRESETS[a.substr(9)][k]
		elif a.begins_with("--map="):
			_map_path = Campaign.scene_for(StringName(a.substr(6)))
		elif a == "--no-plane":   # T-220: the A/B of der Kranich's plane pass (KranichExterior / KranichAir never build)
			KranichExterior.disabled = true
			KranichAir.disabled = true
			KranichSunset.disabled = true
			KranichInterior.disabled = true
		elif a.begins_with("--pos="):
			for v: String in a.substr(6).split(","):
				_pos.append(float(v))
		elif a == "--no-webprofile":
			GLSettings.compat_override = 0
		elif a.begins_with("--round="):
			_round = maxi(1, int(a.substr(8)))
		elif a.begins_with("--secs="):
			_t_end = 9.0 + maxf(1.0, float(a.substr(7)))
		elif a.begins_with("--hour="):
			_hour = float(a.substr(7))
		elif a.begins_with("--hours="):
			for h: String in a.substr(8).split(","):
				_hours.append(float(h))
			_hour = _hours[0]
			_hours.remove_at(0)
		elif a.begins_with("--t266-ab"):
			_ab_t266 = true
			var spec: String = a.substr(10) if a.begins_with("--t266-ab=") else "proxies+props+occlusion+sun+lights"   # steps a:b, features in a step a+b
			for st: String in spec.split(":", false):
				_ab_steps.append(st.split("+", false))
		elif a.begins_with("--zombies="):
			_zcount = maxi(0, int(a.substr(10)))
		elif a.begins_with("--mix="):
			_mix = a.substr(6)
		elif a.begins_with("--flip="):
			_flip = a.substr(7)
		elif a.begins_with("--kills="):
			_kill_rate = maxf(0.0, float(a.substr(8)))
		elif a.begins_with("--views="):
			_views_on = true
			_views = PerfViews.load_views(a.substr(8).split(","))
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--views-only="):
			_views = PerfViews.only(_views, a.substr(13).split(","))
		elif a.begins_with("--views-max="):
			_views = PerfViews.sample(_views, int(a.substr(12)))
	process_mode = Node.PROCESS_MODE_ALWAYS
	BotProf.on = _hitch
	BotProf.reset()
	if "--vo-async" in OS.get_cmdline_user_args():   # T-265: a headless run with the windowed game's voice loading
		GLVO.set("async_start", true)
	if "no_view_lod" in _ab:   # T-265: the zombies animated by distance only, as before the camera's view counted
		(load("res://gravelight/enemies/zombie.gd") as GDScript).set("view_lod", false)
	if "no_piece_warm" in _ab:   # (set through the script object: this tool also runs on a build without the switch)
		(load("res://gravelight/enemies/zombie_body.gd") as GDScript).set("piece_warm", false)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed(int(a.substr(7)))
	if "t281_off" in _ab:   # T-281: the horde-size optimisations off (the before, same build)
		(load("res://gravelight/enemies/zombie.gd") as GDScript).set("t281_opt", false)
	if "t283_off" in _ab:   # T-283: phase 2's zombie changes off (the before, same build)
		(load("res://gravelight/enemies/zombie.gd") as GDScript).set("t283_opt", false)
	if "--ab=t237_off" in OS.get_cmdline_user_args():   # T-237: the "before" side (the optimisations off, same build)
		BotProf.opt = false
		StreamWarm.enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	ProfileSave.path = "user://_perf_marks_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_perf_marks_settings.cfg"
	GLSettings.values["classic_hud"] = false
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	GameState.bot_ai_mode = "off"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--bots="):
			GameState.bot_count = clampi(int(a.substr(7)), 0, 3)
		elif a.begins_with("--ai="):
			GameState.bot_ai_mode = a.substr(5)
			GLSettings.values["bot_local_ai"] = a.substr(5) == "local"
		elif a.begins_with("--brain="):
			GLSettings.values["bot_ai_brain"] = a.substr(8)
	GameState.god_mode = true
	if _breakdown:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		get_tree().node_added.connect(_on_node_added)
	print("[perf] map %s, renderer %s, adapter %s" % [_map_path, RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	_map = (load(_map_path) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	if _probe:
		var prober: Node = Node.new()
		prober.name = "PerfProber"
		prober.set_script(_make_prober())
		prober.set("owner_perf", self)
		add_child(prober)


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _map == null or not _map.is_inside_tree() or _map.player == null:
		return
	_t += delta
	match _phase:
		0:
			if _t > 3.0 and (_map.squad != null or GameState.bot_count == 0):
				_phase = 1
				RoundManager.debug_set_round(_round)
				if "--boss" in OS.get_cmdline_user_args():
					RoundManager.next_boss = _round
				if _hour >= 0.0 and DayCycle.of(_map) != null:
					DayCycle.of(_map).hold_hour(_hour)
				if _companions:
					GLConsole.call("run", "jakub join")
					if _hitch:   # T-237: the map's own companion too (the owner's squad: 3 bots + Jakub + one more)
						for c: MapCompanion in MapCompanion.instances(get_tree()):
							if c.player != null:
								c.call("_join", 1, false)
		1:
			if _t > 5.0:
				_phase = 2
				if not _live:
					RoundManager.stop()
					_spawn_horde(_zcount)
					GLBus.enemy_killed_at.connect(func(_e: StringName, _p: Vector3, _b: int) -> void:
						if _t > 9.0 and _t < _t_end:
							_deaths += 1)
				if "--tank" in OS.get_cmdline_user_args() and _map.get_node_or_null(^"ShermanEvent") is ShermanEvent:
					(_map.get_node(^"ShermanEvent") as ShermanEvent).force_assist()
				if _pos.size() >= 3:
					var fs: Node = get_tree().get_first_node_in_group(&"flight_sky")
					if fs != null and fs.has_method("calm"):
						fs.call("calm")
					_map.player.global_position = Vector3(_pos[0], _pos[1], _pos[2])
					_map.player.velocity = Vector3.ZERO
					if _pos.size() >= 4:
						_map.player.rotation.y = deg_to_rad(_pos[3])
					print("[perf] the player stands at %s" % str(_map.player.global_position))
				if not ("--no-marks" in OS.get_cmdline_user_args()) and _map.squad != null and not _map.squad.brains.is_empty():
					_place_marks()
				print("[perf] round %d, bots %d, jakub %s, marks %d, brains %d, ai %s" % [RoundManager.current_round, GameState.bot_ids.size(),
					str(JakubCompanion.instance(get_tree()) != null), MapMarks.current().marks().size(),
					_map.squad.brains.size() if _map.squad != null else 0, GameState.bot_ai_mode])
		2 when _t > (6.0 if _quick else 8.0) and not _census_done:
			_census_done = true
			if _breakdown or not _ab.is_empty():
				_census()
			_apply_ab()
			for ta: String in OS.get_cmdline_user_args():
				if ta.begins_with("--tree="):
					PerfViews.tree(_map, ta.substr(7))
			if "--batches" in OS.get_cmdline_user_args():
				PerfViews.batches(_map)
			if "--proxy-check" in OS.get_cmdline_user_args():
				PerfViews.proxy_check(_map)
			if "--props" in OS.get_cmdline_user_args():
				PerfViews.props(_map)
			if "--casters" in OS.get_cmdline_user_args():
				PerfViews.casters(_map)
			if _hour >= 0.0 and DayCycle.of(_map) != null:
				DayCycle.of(_map).hold_hour(_hour)
				print("[perf] the day held at hour %.1f" % _hour)
		2 when _views_on and _census_done:
			_views_step()
		2:
			if not _live:
				for z: Zombie in _map.director.active_zombies():
					z.hp = maxf(z.hp, 1.0e9)
				if _hitch:   # T-237: the squad stays up too (24 zombies nobody can kill put every bot down in 15 s)
					for bp: Node in get_tree().get_nodes_in_group(&"bots"):
						(bp as Player).bot_damage_mult = 0.0
				if _kill_rate > 0.0 and _t > 9.0:
					_kill_step(delta)
				if _flip != "" and _t > 9.0:
					_flip_step()
				if _census_done and ("z_no_zcollide" in _ab or "z_no_avoid" in _ab or "z_no_dead_areas" in _ab or "z_no_areas" in _ab):
					_ab_zombies()
				if _t > 6.0 and (_kill_rate > 0.0 or _mix != ""):
					_refill_t -= delta
					if _refill_t <= 0.0:   # the dead (killed, or a fire zombie's burst) are put back so N stay up
						_refill_t = 0.25
						var up: int = _map.director.active_zombies().size()
						if up < _zcount:
							_spawn_horde(_zcount - up)
				if "--corpses" in OS.get_cmdline_user_args() and _t > 9.0:
					_kill_t -= delta
					if _kill_t <= 0.0:
						_kill_t = 1.0
						var live_z: Array = _map.director.active_zombies()
						for ki: int in mini(4, live_z.size()):
							var kz: Zombie = live_z[ki]
							kz.hp = 1.0
							kz.take_damage(50.0, [&"head", &"torso", &"arms", &"legs"][ki], &"", _map.player.player_id, &"explosive" if ki == 1 else &"bullet")
						(_map.get_node("ZombieDirector") as ZombieDirector).debug_spawn(mini(4, live_z.size()))
			if _probe:
				_probe_scan_t -= delta
				if _probe_scan_t <= 0.0:
					_probe_scan_t = 0.5
					var ts0: int = Time.get_ticks_usec()
					_probe_scan()
					_skip_us += Time.get_ticks_usec() - ts0   # the probe's own tree walk is not the game's cost
					_gap_skip += Time.get_ticks_usec() - ts0
			if "--ts" in OS.get_cmdline_user_args() and _t > 15.0 and _t - delta <= 15.0:
				_print_timestamps()
			if "--mm-bench" in OS.get_cmdline_user_args() and _t > 16.0 and _t - delta <= 16.0:
				_minimap_bench()
			if (_quick and _census_done) or (_t > 9.0 and _t < _t_end):
				if _win_frame < 0:
					_win_frame = Engine.get_physics_frames()
					if "--diag" in OS.get_cmdline_user_args():
						var ts1: int = Time.get_ticks_usec()
						_uncached = _uncached_resources()
						_skip_us += Time.get_ticks_usec() - ts1
						_gap_skip += Time.get_ticks_usec() - ts1
				_samples.append(delta)
				_built_frame_end()
				_frame_stats(delta)
				if _hitch:
					var wn: int = Time.get_ticks_usec()
					if _wall_prev != 0:
						_wall.append(maxi(0, wn - _wall_prev - _skip_us))
						_flip_add("frame", maxi(0, wn - _wall_prev - _skip_us))
					_wall_prev = wn
					_skip_us = 0
			if (_quick and _samples.size() >= QUICK_FRAMES) or (not _quick and _t >= _t_end):
				_report("in play", _samples)
				_report_breakdown()
				if _probe:
					_probe_release()
				if _hitch:
					_report_hitch()
					DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
					get_tree().quit()
					return
				if _quick:
					print("[perf] active zombies %d   GPU: %s" % [_map.director.active_zombies().size(), RenderingServer.get_video_adapter_name()])
					get_tree().quit()
					return
				_phase = 3
				_map.pause_menu.toggle()
		3:
			if _t > 26.0 and _t < 34.0:
				_map_samples.append(delta)
			if _t >= 34.0:
				_report("pause map open", _map_samples)
				var mm: Minimap = _map.find_child("Minimap", true, false) as Minimap
				if mm != null:
					print("[perf] minimap %.0f us per frame" % mm.perf_usec())
					var pr: Dictionary = mm.canvas.prof
					print("[perf]   minimap parts (us, rolling): list rebuild %.0f (4 Hz), placing icons %.0f, of which live list %.0f" % [
						float(pr["rebuild"]), float(pr["place"]), float(pr["live"])])
				if _map.squad != null:
					var ts: Dictionary = _map.squad.think_stats()
					print("[perf] brains %.3f ms per bot per frame (%d brains incl. Jakub)" % [float(ts["ms_per_bot_frame"]), _map.squad.brains.size()])
				print("[perf] active zombies %d   GPU: %s" % [_map.director.active_zombies().size(), RenderingServer.get_video_adapter_name()])
				get_tree().paused = false
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
				get_tree().quit()


func _place_marks() -> void:
	var mm: MapMarks = MapMarks.current()
	var me: Player = _map.player
	var b0: BotBrain = _map.squad.brains[0]
	for i: int in 3:
		mm.place({"kind": "go", "pos": b0.snap(me.global_position + Vector3(2.0 + i * 2.5, 0, 1.5)), "target": "me"})
	mm.place({"kind": "danger", "pos": b0.snap(me.global_position + Vector3(-3, 0, 3))})
	mm.place({"kind": "defend", "pos": b0.snap(me.global_position + Vector3(-2, 0, -2)), "target": int(GameState.bot_ids[0])})
	var wb: Node3D = _map.get_node_or_null(^"Gameplay/WallBuy_kar98k") as Node3D
	if wb != null:
		mm.place({"kind": "buy", "pos": wb.global_position, "node": wb, "target": int(GameState.bot_ids[1])})


func _report(what: String, s: PackedFloat32Array) -> void:
	if s.is_empty():
		return
	var total: float = 0.0
	var worst: float = 0.0
	var sorted: Array = Array(s)
	sorted.sort()
	for x: float in s:
		total += x
		worst = maxf(worst, x)
	var low_n: int = maxi(1, int(s.size() * 0.01))
	var low: float = 0.0
	for i: int in low_n:
		low += float(sorted[sorted.size() - 1 - i])
	low /= float(low_n)
	print("[perf] %s: avg FPS %.1f, worst frame %.1f ms, 1%% low %.1f FPS, frames %d" % [what, float(s.size()) / total, worst * 1000.0, 1.0 / low, s.size()])


# ================================================================== the breakdown (T-070)

## Pipeline compilations so far by when they happened, as one number per kind (canvas, mesh, surface, draw,
## specialization) packed in base 1000 for the spike lines; "draw" ones stall the frame that needs them.
func _pipeline_compiles() -> Vector4i:
	return Vector4i(int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)))


func _add(key: String, v: float) -> void:
	_sum[key] = float(_sum.get(key, 0.0)) + v


func _frame_stats(delta: float) -> void:
	if not _breakdown:
		if delta * 1000.0 > SPIKE_MS and _spikes.size() < 60:
			_spikes.append("t=%.2f %.1f ms" % [_t, delta * 1000.0])
		return
	var vp: RID = get_viewport().get_viewport_rid()
	var proc: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nav: float = Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	var rcpu: float = RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	var rgpu: float = RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var pf: int = Engine.get_physics_frames()
	var steps: int = pf - _phys_frames if _phys_frames > 0 else 1
	_phys_frames = pf
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var comp: Vector4i = _pipeline_compiles()
	_add("frame", delta * 1000.0)
	_add("process", proc)
	_add("physics", phys)
	_add("navigation", nav)
	_add("render cpu", rcpu)
	_add("gpu", rgpu)
	_add("physics steps", float(steps))
	_add("draw calls", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_add("objects drawn", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_add("primitives (k)", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)
	_n += 1
	var compiled: bool = comp != _compiles and "--compiles" in OS.get_cmdline_user_args()
	if (delta * 1000.0 > SPIKE_MS or compiled) and _spikes.size() < 60:
		_spikes.append("t=%.2f %.1f ms: process %.1f physics %.1f (x%d steps) nav %.1f render cpu %.1f gpu %.1f, pipeline compiles (canvas+mesh, surface, draw, specialization) %s, nodes %+d" % [
			_t, delta * 1000.0, proc, phys, steps, nav, rcpu, rgpu, str(comp - _compiles), nodes - _node_count])
		if not (_added.is_empty() and _added_prev.is_empty()):
			_spikes.append("    new nodes then: %s | before: %s" % [", ".join(_added.slice(0, 12)), ", ".join(_added_prev.slice(0, 12))])
	_compiles = comp
	_node_count = nodes
	_added_prev = _added
	_added = []


## T-265: every node that entered the tree in the sampled window, counted per frame (a count does not depend on
## how busy the machine is): the frames that built the most, and what they built.
var _built_now: int = 0
var _built_names: PackedStringArray = []
var _built_top: Array = []   # [count, text]
var _built_total: int = 0


func _built_frame_end() -> void:
	if _built_now > 0:
		_built_total += _built_now
		if _built_top.size() < 10 or _built_now > int(_built_top[_built_top.size() - 1][0]):
			_built_top.append([_built_now, "t=%.2f %d nodes: %s" % [_t, _built_now, ", ".join(_built_names)]])
			_built_top.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
			if _built_top.size() > 10:
				_built_top.resize(10)
	_built_now = 0
	_built_names = []


func _on_node_added(n: Node) -> void:
	if _hitch and _phase == 2 and _t > 9.0 and not (n.get_parent() == self):
		_built_now += 1
		if _built_names.size() < 8 and (n.get_script() != null or n is VisualInstance3D or n is AudioStreamPlayer3D or n is CollisionObject3D):
			var sc: Script = n.get_script() as Script
			var holder: Node = n.get_parent()   # the nearest scripted node above it says whose it is
			while holder != null and holder.get_script() == null and holder.get_parent() != null:
				holder = holder.get_parent()
			var hs: Script = holder.get_script() as Script if holder != null else null
			_built_names.append("%s%s in %s" % [n.name, ("(" + sc.resource_path.get_file() + ")") if sc != null else "<" + n.get_class() + ">",
				(str(holder.name) + "(" + hs.resource_path.get_file() + ")") if hs != null else "-"])
	if _phase == 2 and _added.size() < 40 and (n is VisualInstance3D or n is CanvasItem or n.get_script() != null):
		var s: Script = n.get_script() as Script
		var what: String = ""
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi: MeshInstance3D = n as MeshInstance3D
			var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
			what = " mesh %s mat %s" % [mi.mesh.get_class(), (mat.resource_name if mat.resource_name != "" else mat.get_class()) if mat != null else "-"]
		_added.append("%s:%s<%s%s>%s" % [n.get_class(), n.name, n.get_parent().name if n.get_parent() != null else "", what,
			("(" + s.resource_path.get_file() + ")") if s != null else ""])


func _report_breakdown() -> void:
	print("[perf] render thread model %s (0 unsafe, 1 safe, 2 separate), preset %s" % [str(ProjectSettings.get_setting("rendering/driver/threads/thread_model")),
		str(GLSettings.values.get("graphics_preset", "high"))])
	print("[perf] frames over %.0f ms: %d" % [SPIKE_MS, _spikes.size()])
	for s: String in _spikes:
		print("[perf]   " + s)
	if _n == 0:
		return
	var parts: PackedStringArray = []
	for k: String in _sum:
		parts.append("%s %.2f" % [k, float(_sum[k]) / float(_n)])
	print("[perf] per frame (avg): " + ", ".join(parts))
	print("[perf] physics engine %s, %d ticks/s, nodes %d" % [str(ProjectSettings.get_setting("physics/3d/physics_engine")), Engine.physics_ticks_per_second, _node_count])
	for e: Array in _lights:
		if is_instance_valid(e[0]) and (e[0] as Node3D).global_position.distance_to(e[1] as Vector3) > 0.001:
			print("[perf]   shadow light %s MOVES" % _map.get_path_to(e[0] as Node))
	if _probe:
		_report_probe()


# ================================================================== --probe: per-script cost

func _probe_scan() -> void:
	var stack: Array[Node] = [get_tree().root if _probe_all else _map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var s: Script = n.get_script() as Script
		if s == null or n == self or n.get_parent() == self:
			continue
		var has_p: bool = n.has_method(&"_process") and n.is_processing()
		var has_pp: bool = n.has_method(&"_physics_process") and n.is_physics_processing()
		if not has_p and not has_pp:
			continue
		var key: String = s.resource_path.get_file()
		if not _groups.has(key):
			_groups[key] = {"proc": [], "phys": [], "us_proc": 0.0, "us_phys": 0.0, "s_proc": [], "s_phys": []}
		var g: Dictionary = _groups[key]
		if has_p:
			n.set_process(false)
			(g["proc"] as Array).append(n)
		if has_pp:
			n.set_physics_process(false)
			(g["phys"] as Array).append(n)


func probe_tick(physics: bool, delta: float) -> void:
	if _phase != 2:
		return
	var counting: bool = (_quick and _census_done) or (_t > 9.0 and _t < _t_end)
	if counting:
		if physics:
			_probe_pframes += 1
		else:
			_probe_frames += 1
	var list_key: String = "phys" if physics else "proc"
	var us_key: String = "us_phys" if physics else "us_proc"
	var s_key: String = "s_phys" if physics else "s_proc"
	var tick_us: int = 0
	var tick_parts: Dictionary = {}
	var keep: bool = _hitch and counting
	if keep and _probe_all:
		var g0: int = Time.get_ticks_usec()
		if physics and _proc_end != 0:
			_gap_proc.append(g0 - _proc_end)
			_flip_add("after process scripts", g0 - _proc_end)
		elif not physics and _phys_end != 0:
			g0 -= _gap_skip
			_gap_skip = 0
			_gap_phys.append(g0 - _phys_end)
			_flip_add("after physics scripts", g0 - _phys_end)
			var it: int = NavigationServer3D.map_get_iteration_id(get_viewport().world_3d.navigation_map)
			var synced: bool = _nav_iter >= 0 and it != _nav_iter
			if synced:
				_nav_syncs += 1
			_nav_iter = it
			if g0 - _phys_end > 4000 and _gap_worst.size() < 400:
				_gap_worst.append([g0 - _phys_end, "t=%.2f %.2f ms%s" % [_t, (g0 - _phys_end) / 1000.0, " (the navigation map was rebuilt)" if synced else ""]])
	var b_us: PackedFloat64Array = []
	var b_th: PackedInt32Array = []
	if keep and physics:
		BotProf.begin_tick()
		# the machine's noise floor: a fixed loop of ~0.1 ms timed every tick. Its p99 / worst say how much of any
		# section's worst is the machine (preemption by other processes), not the game.
		var c0: int = Time.get_ticks_usec()
		var acc: int = 0
		for ci: int in 2000:
			acc += ci * ci
		_calib.append(Time.get_ticks_usec() - c0)
		if _map.squad != null:
			for b: BotBrain in _map.squad.brains:
				b_us.append(b.us_total)
				b_th.append(b.thinks)
	var added0: int = _added.size()
	for key: String in _groups:
		var g: Dictionary = _groups[key]
		var arr: Array = g[list_key]
		if arr.is_empty():
			continue
		var t0: int = Time.get_ticks_usec()
		var i: int = 0
		while i < arr.size():
			var n: Variant = arr[i]
			if not is_instance_valid(n) or not (n as Node).is_inside_tree():
				arr.remove_at(i)
				continue
			if (n as Node).can_process():
				if physics:
					(n as Node).call(&"_physics_process", delta)
				else:
					(n as Node).call(&"_process", delta)
			i += 1
		if counting:
			var el: int = Time.get_ticks_usec() - t0
			g[us_key] = float(g[us_key]) + float(el)
			if keep:
				(g[s_key] as Array).append(el)
				tick_us += el
				tick_parts[key] = el
	if not keep:
		return
	if physics:
		_phys_end = Time.get_ticks_usec()
	else:
		_proc_end = Time.get_ticks_usec()
	if not physics:
		_proc_tot.append(tick_us)
		_flip_add("scripts per process frame", tick_us)
		_flip_add("zombie.gd proc", int(tick_parts.get("zombie.gd", 0)))
		return
	_tick_tot.append(tick_us)
	_flip_add("scripts per physics tick", tick_us)
	_flip_add("zombie.gd phys", int(tick_parts.get("zombie.gd", 0)))
	_flip_add("bot_brain.gd phys", int(tick_parts.get("bot_brain.gd", 0)))
	if _worst.size() >= 14 and tick_us <= int(_worst[_worst.size() - 1][0]):
		return
	var keys: Array = tick_parts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(tick_parts[a]) > int(tick_parts[b]))
	var txt: PackedStringArray = []
	for k: String in keys.slice(0, 4):
		txt.append("%s %.2f" % [k.trim_suffix(".gd"), int(tick_parts[k]) / 1000.0])
	var line: String = "t=%.2f %.2f ms: %s" % [_t, tick_us / 1000.0, ", ".join(txt)]
	if _map.squad != null:
		var bt: PackedStringArray = []
		for i: int in mini(b_us.size(), _map.squad.brains.size()):
			var b: BotBrain = _map.squad.brains[i]
			bt.append("%s %.2f%s %s" % [b.player.name, (b.us_total - b_us[i]) / 1000.0, " THINK" if b.thinks != b_th[i] else "", b.action])
		line += " | brains: " + "; ".join(bt)
	var pr: String = BotProf.tick_text(7)
	if pr != "":
		line += " | " + pr
	if _added.size() > added0:   # T-265: what entered the tree during this tick's scripts (a first use shows here)
		line += " | new nodes %d: %s" % [_added.size() - added0, ", ".join(_added.slice(added0, added0 + 6))]
	_worst.append([tick_us, line])
	_worst.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	if _worst.size() > 14:
		_worst.resize(14)


func _probe_release() -> void:
	for key: String in _groups:
		var g: Dictionary = _groups[key]
		for n: Variant in g["proc"]:
			if is_instance_valid(n):
				(n as Node).set_process(true)
		for n: Variant in g["phys"]:
			if is_instance_valid(n):
				(n as Node).set_physics_process(true)


func _report_probe() -> void:
	var rows: Array = []
	var tp: float = 0.0
	var tpp: float = 0.0
	for key: String in _groups:
		var g: Dictionary = _groups[key]
		var p: float = float(g["us_proc"]) / 1000.0 / float(maxi(1, _probe_frames))
		var pp: float = float(g["us_phys"]) / 1000.0 / float(maxi(1, _probe_pframes))
		tp += p
		tpp += pp
		rows.append([key, p, pp, (g["proc"] as Array).size(), (g["phys"] as Array).size()])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) + float(a[2]) > float(b[1]) + float(b[2]))
	print("[perf] probe: %d frames, %d physics frames; scripts total: _process %.2f ms/frame, _physics_process %.2f ms/physics frame" % [
		_probe_frames, _probe_pframes, tp, tpp])
	for i: int in mini(30, rows.size()):
		var r: Array = rows[i]
		print("[perf]   %-34s process %.3f ms (%d nodes)  physics %.3f ms (%d nodes)" % [r[0], r[1], r[3], r[2], r[4]])


# ================================================================== --hitch: the distributions (T-237)

## [mean, p50, p95, p99, worst] in ms of microsecond samples.
static func dist(s: PackedInt32Array) -> Array:
	if s.is_empty():
		return [0.0, 0.0, 0.0, 0.0, 0.0]
	var a: PackedInt32Array = s.duplicate()
	a.sort()
	var tot: float = 0.0
	for x: int in a:
		tot += float(x)
	var n: int = a.size()
	return [tot / float(n) / 1000.0, a[n / 2] / 1000.0, a[mini(n - 1, int(n * 0.95))] / 1000.0, a[mini(n - 1, int(n * 0.99))] / 1000.0, a[n - 1] / 1000.0]


static func over(s: PackedInt32Array, ms: float) -> int:
	var c: int = 0
	for x: int in s:
		if float(x) > ms * 1000.0:
			c += 1
	return c


func _report_hitch() -> void:
	var w: Array = dist(_wall)
	var nb: int = _map.squad.brains.size() if _map.squad != null else 0
	print("[hitch] map %s bots %d brains %d ai %s live %s zombies %d frames %d" % [str(_map.map_id), GameState.bot_ids.size(), nb, GameState.bot_ai_mode, str(_live),
		_map.director.active_zombies().size(), _wall.size()])
	print("[hitch] frame wall ms: mean %.2f p50 %.2f p95 %.2f p99 %.2f worst %.2f | over 8 ms %d, over 16.7 ms %d, over 20 ms %d, over 33 ms %d" % [
		w[0], w[1], w[2], w[3], w[4], over(_wall, 8.0), over(_wall, 16.7), over(_wall, 20.0), over(_wall, 33.0)])
	# the slowest hundredth of the frames, as their mean (what a "1 % low" frame rate is made of), and the census
	# of what a round leaves lying about
	var ws: PackedInt32Array = _wall.duplicate()
	ws.sort()
	var ln: int = maxi(1, ws.size() / 100)
	var lsum: float = 0.0
	for i: int in ln:
		lsum += float(ws[ws.size() - 1 - i])
	var low_ms: float = lsum / float(ln) / 1000.0
	print("[hitch] 1%% low: the slowest %d frames average %.2f ms (%.0f a second, no renderer); worst %.2f ms; round %d at the end" % [
		ln, low_ms, 1000.0 / maxf(0.001, low_ms), w[4], RoundManager.current_round])
	var rag: int = 0
	var rigid: int = 0
	var decals: int = 0
	var dead: int = 0
	for n: Node in _all_nodes():
		if n is PhysicalBone3D:
			rag += 1
		elif n is RigidBody3D:
			rigid += 1
		elif n is Decal:
			decals += 1
		elif n is Zombie and (n as Zombie).state == Zombie.State.DEAD:
			dead += 1
	print("[hitch] census at the end: nodes %d, corpses %d, ragdoll bones %d, rigid bodies %d, decals %d, soldiers %d, physics objects %d, islands %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), dead, rag, rigid, decals, get_tree().get_nodes_in_group(&"soldiers").size(),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))])
	if _map.squad != null and _map.squad.has_method("planner_status"):
		print("[hitch] " + str(_map.squad.call("planner_status")))
	for pl: Node in _all_nodes():
		if pl is BotPlanner:
			print("[hitch] " + (pl as BotPlanner).status_line())
	if "--diag" in OS.get_cmdline_user_args():
		_diag()
	if GLVO.get("late_starts") != null:
		print("[hitch] work counted: voice lines whose start waited for a loader thread %d, voice files loaded in the frame that needed them %d, sound files loaded in the frame that played them %d (async voice %s)" % [
			int(GLVO.get("late_starts")), int(GLVO.get("sync_loads")), int(AudioDirector.get("sync_loads")), str(GLVO.get("async_start"))])
		print("[hitch]   sounds loaded in their frame (name@physics frame; the window began at frame %d): %s" % [_win_frame, ", ".join(AudioDirector.get("sync_log") as PackedStringArray)])
	var pbs: GDScript = load("res://gravelight/world/inn_opening/patron_body.gd") as GDScript
	if pbs.get("blend_frames") != null and int(pbs.get("blend_frames")) > 0:
		print("[hitch] work counted: the people's pose weights were stepped in %d of %d body-frames" % [int(pbs.get("blend_steps")), int(pbs.get("blend_frames"))])
	for cn: Node in _all_nodes():
		if cn is Horse and cn.get("rig_frames") != null and int(cn.get("rig_frames")) > 0:
			print("[hitch] work counted: the horse's rig was posed in %d of %d frames" % [int(cn.get("rig_ticks")), int(cn.get("rig_frames"))])
		if cn is RisenColumn and cn.get("placed_frames") != null:
			print("[hitch] work counted: the column of the Returned (%d walkers) was placed in %d frames and slept, unseen, in %d" % [(cn as RisenColumn).bodies.size(), int(cn.get("placed_frames")), int(cn.get("slept_frames"))])
	var dc: DayCycle = DayCycle.of(_map)
	if dc != null and dc.get("full_frames") != null:
		print("[hitch] work counted: the day wrote its values in %d frames and found nothing to write in %d" % [int(dc.get("full_frames")), int(dc.get("skipped_frames"))])
	if _map.squad != null:
		var looks: int = 0
		var lticks: int = 0
		for b: BotBrain in _map.squad.brains:
			if b.loco != null and b.loco.get("nav_looks") != null:
				looks += int(b.loco.get("nav_looks"))
				lticks += int(b.loco.get("_ticks"))
		if lticks > 0 and looks > 0:
			print("[hitch] work counted: the bots asked the navmesh under them %d times in %d locomotion ticks" % [looks, lticks])
	var zs: GDScript = load("res://gravelight/enemies/zombie.gd") as GDScript
	if zs.get("anim_steps") != null:   # T-265's work counters (since the map loaded), per frame of the whole run
		var fr: float = float(maxi(1, Engine.get_process_frames()))
		var af: float = float(maxi(1, int(zs.get("active_frames"))))
		print("[hitch] work counted (whole run, %d frames): zombie animation steps %d (%.1f a frame, %.0f %% of the %d zombie-frames; %.0f %% of those out of view), ticks with foot rays %d (%.1f a frame, %.0f %%)" % [
			Engine.get_process_frames(), int(zs.get("anim_steps")), int(zs.get("anim_steps")) / fr, 100.0 * int(zs.get("anim_steps")) / af, int(af),
			100.0 * int(zs.get("out_frames")) / af, int(zs.get("foot_ray_ticks")), int(zs.get("foot_ray_ticks")) / fr, 100.0 * int(zs.get("foot_ray_ticks")) / af])
	_report_t281()
	_report_flip()
	var t: Array = dist(_tick_tot)
	print("[hitch] scripts per physics tick ms: mean %.2f p50 %.2f p95 %.2f p99 %.2f worst %.2f | over 4 ms %d, over 8 ms %d, over 16.7 ms %d" % [
		t[0], t[1], t[2], t[3], t[4], over(_tick_tot, 4.0), over(_tick_tot, 8.0), over(_tick_tot, 16.7)])
	var cd: Array = dist(_calib)
	print("[hitch] noise floor (a fixed ~0.1 ms loop per tick) ms: mean %.3f p50 %.3f p95 %.3f p99 %.3f worst %.3f | over 1 ms %d of %d" % [cd[0], cd[1], cd[2], cd[3], cd[4], over(_calib, 1.0), _calib.size()])
	var pd: Array = dist(_proc_tot)
	print("[hitch] scripts per process frame ms: mean %.2f p50 %.2f p95 %.2f p99 %.2f worst %.2f" % [pd[0], pd[1], pd[2], pd[3], pd[4]])
	if _probe_all:
		var gp: Array = dist(_gap_phys)
		var gq: Array = dist(_gap_proc)
		print("[hitch] outside the scripts ms: after the physics scripts (physics, navigation servers) mean %.2f p50 %.2f p99 %.2f worst %.2f | after the process scripts (animation, skeletons, audio, draw, the tool) mean %.2f p50 %.2f p99 %.2f worst %.2f" % [
			gp[0], gp[1], gp[3], gp[4], gq[0], gq[1], gq[3], gq[4]])
		var with_sync: int = 0
		for e: Array in _gap_worst:
			if str(e[1]).ends_with(")"):
				with_sync += 1
		print("[hitch] navigation map rebuilds in the window: %d; gaps after the physics scripts over 4 ms: %d, of them with a rebuild %d" % [_nav_syncs, _gap_worst.size(), with_sync])
		_gap_worst.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
		for e: Array in _gap_worst.slice(0, 8):
			print("[hitch]   gap " + str(e[1]))
	var rows: Array = []
	for key: String in _groups:
		var g: Dictionary = _groups[key]
		for k: String in ["s_phys", "s_proc"]:
			var d: Array = dist(PackedInt32Array(g[k] as Array))
			if float(d[4]) > 0.0:
				rows.append([key + (" phys" if k == "s_phys" else " proc"), d, (g["phys" if k == "s_phys" else "proc"] as Array).size()])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1][0]) > float(b[1][0]))
	for i: int in mini(16, rows.size()):
		var d: Array = rows[i][1]
		print("[hitch]   %-36s mean %.3f p50 %.3f p95 %.3f p99 %.3f worst %.3f (%d nodes)" % [rows[i][0], d[0], d[1], d[2], d[3], d[4], rows[i][2]])
	print("[hitch] nodes built in the window: %d in %d frames; the frames that built the most:" % [_built_total, _wall.size()])
	for e: Array in _built_top:
		print("[hitch]   built " + str(e[1]))
	print("[hitch] worst ticks (scripts):")
	for e: Array in _worst:
		print("[hitch]   " + str(e[1]))
	for l: String in BotProf.report():
		print("[hitch] " + l)
	if _map.squad != null:
		for b: BotBrain in _map.squad.brains:
			print("[hitch] brain %s: %.3f ms/tick, think %.3f ms each (%d thinks), action %s" % [b.player.name, b.ms_per_frame(), b.us_think / 1000.0 / float(maxi(1, b.thinks)), b.thinks, b.action])
	print("[hitch] nodes %d, orphans %d" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])


## `--diag`: every script, scene, shader, model, texture and sound of the project that is not in the engine's
## resource cache (res://gravelight, res://core, res://assets, res://data).
var _uncached: PackedStringArray = []
const DIAG_EXT: PackedStringArray = ["gd", "tscn", "scn", "gdshader", "tres", "res", "glb", "png", "jpg", "wav", "ogg"]


func _uncached_resources() -> PackedStringArray:
	var out: PackedStringArray = []
	var stack: PackedStringArray = ["res://gravelight", "res://core", "res://assets", "res://data"]
	while not stack.is_empty():
		var dir: String = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var da: DirAccess = DirAccess.open(dir)
		if da == null:
			continue
		for sub: String in da.get_directories():
			if not sub.begins_with("."):
				stack.append(dir + "/" + sub)
		for f: String in da.get_files():
			if DIAG_EXT.has(f.get_extension()) and not ResourceLoader.has_cached(dir + "/" + f):
				out.append(dir + "/" + f)
	return out


## `--diag` (T-265): what a whole-map search costs here (find_children by class, as several scripts make at run
## time), and which animation players and trees are running, by the node they sit under.
func _diag() -> void:
	var first: PackedStringArray = []
	for path: String in _uncached:
		if ResourceLoader.has_cached(path):
			first.append(path.trim_prefix("res://"))
	print("[diag] resources that came into the cache during the window (first loaded in play, on the main thread or a loader thread): %d" % first.size())
	var by_ext: Dictionary = {}
	for path: String in first:
		by_ext[path.get_extension()] = int(by_ext.get(path.get_extension(), 0)) + 1
	print("[diag]   by kind: %s" % str(by_ext))
	for path: String in first:
		if not (path.get_extension() in ["wav", "ogg"]):
			print("[diag]   first load: " + path)
	var t0: int = Time.get_ticks_usec()
	var n: int = 0
	for i: int in 5:
		n = _map.find_children("*", "Interactable", true, false).size()
	var t1: int = Time.get_ticks_usec()
	for i: int in 5:
		get_tree().get_nodes_in_group(&"players")
	print("[diag] find_children(\"*\", \"Interactable\") over the map: %.2f ms each (%d found, %d nodes in the tree)" % [(t1 - t0) / 5000.0, n, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	var by: Dictionary = {}
	for node: Node in _all_nodes():
		var on: bool = false
		var what: String = node.get_class()
		if node is AnimationPlayer:
			on = (node as AnimationPlayer).is_playing() and (node as AnimationPlayer).active
		elif node is AnimationTree:
			on = (node as AnimationTree).active
		elif node is GPUParticles3D:
			on = (node as GPUParticles3D).emitting
		elif node is AudioStreamPlayer3D:
			on = (node as AudioStreamPlayer3D).playing
		else:
			continue
		if not on:
			continue
		var top: Node = node
		while top.get_parent() != null and top.get_parent() != _map and top.get_parent() != get_tree().root:
			top = top.get_parent()
		var key: String = "%s under %s" % [what, top.name]
		by[key] = int(by.get(key, 0)) + 1
	var keys: Array = by.keys()
	keys.sort()
	for k: String in keys:
		print("[diag]   running: %s x%d" % [k, by[k]])


## The probe's own loop: a child node, so it runs in both the process and the physics step.
static func _make_prober() -> GDScript:
	var gs: GDScript = GDScript.new()
	gs.source_code = "extends Node\nvar owner_perf: Node\nfunc _ready() -> void:\n\tprocess_mode = Node.PROCESS_MODE_ALWAYS\nfunc _process(delta: float) -> void:\n\towner_perf.probe_tick(false, delta)\nfunc _physics_process(delta: float) -> void:\n\towner_perf.probe_tick(true, delta)\n"
	gs.reload()
	return gs


# ================================================================== census and A/B experiments (diagnosis)

func _all_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


func _census() -> void:
	var counts: Dictionary = {}
	for n: Node in _all_nodes():
		var k: String = n.get_class()
		if n is Light3D:
			var l: Light3D = n as Light3D
			k += " shadow" if l.shadow_enabled else ""
			k += "" if l.is_visible_in_tree() else " hidden"
		elif n is GeometryInstance3D:
			k = "Geometry" + (" (no shadow)" if (n as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else "")
			k += "" if (n as Node3D).is_visible_in_tree() else " hidden"
		elif n is Area3D:
			var ar: Area3D = n as Area3D
			k = "Area3D" + (" monitoring mask %d" % ar.collision_mask if ar.monitoring else "") + (" layer %d" % ar.collision_layer)
		elif not (n is AnimationMixer or n is NavigationAgent3D or n is CollisionObject3D or n is RayCast3D or n is GPUParticles3D or n is CPUParticles3D or n is AudioStreamPlayer3D or n is Skeleton3D):
			continue
		counts[k] = int(counts.get(k, 0)) + 1
	var casters: Dictionary = {}   # the shadow casters by the map's top-level child they sit under
	for n: Node in _all_nodes():
		if n is GeometryInstance3D and (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (n as Node3D).is_visible_in_tree() and _map.is_ancestor_of(n):
			var top: Node = n
			while top.get_parent() != _map:
				top = top.get_parent()
			var tk: String = str(top.name) + ("/" + str(n.get_parent().name) if n.get_parent() != top and n.get_parent() != _map else "")
			casters[tk] = int(casters.get(tk, 0)) + 1
	var ck: Array = casters.keys()
	ck.sort_custom(func(a: String, b: String) -> bool: return int(casters[a]) > int(casters[b]))
	var cparts: PackedStringArray = []
	for k2: String in ck.slice(0, 25):
		cparts.append("%s %d" % [k2, casters[k2]])
	print("[perf] shadow casters by place: " + ", ".join(cparts))
	var keys: Array = counts.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: String in keys:
		parts.append("%s %d" % [k, counts[k]])
	print("[perf] census: " + ", ".join(parts))
	for n: Node in _all_nodes():
		if n is Light3D and (n as Light3D).shadow_enabled and (n as Light3D).is_visible_in_tree() and not (n is DirectionalLight3D):
			var l: Light3D = n as Light3D
			var rng: float = float(l.get("omni_range")) if l is OmniLight3D else float(l.get("spot_range"))
			var mode: String = ("cube" if int(l.get("omni_shadow_mode")) == 1 else "dual parab.") if l is OmniLight3D else "spot"
			_lights.append([l, l.global_position])
			print("[perf]   shadow light %s (%s, %s, range %.1f, energy %.2f, at %s, script %s)" % [_map.get_path_to(l), l.get_class(), mode, rng, l.light_energy,
				str(l.global_position.snapped(Vector3.ONE * 0.1)), (l.get_script() as Script).resource_path.get_file() if l.get_script() != null else "-"])
	var per_zone: Dictionary = {}
	for e: Array in _lights:
		var z: String = str(ZoneVolume.zone_at(get_tree(), (e[0] as Node3D).global_position))
		per_zone[z if z != "" else "(outside)"] = int(per_zone.get(z if z != "" else "(outside)", 0)) + 1
	var zparts: PackedStringArray = []
	var zmax: int = 0
	for z2: String in per_zone:
		zparts.append("%s %d" % [z2, per_zone[z2]])
		zmax = maxi(zmax, int(per_zone[z2]))
	print("[perf] shadowed omni/spot lights: %d, per zone: %s (most %d, budget 6)" % [_lights.size(), ", ".join(zparts), zmax])
	var env: Environment = _env()
	if env != null:
		print("[perf] env: sdfgi %s ssao %s ssil %s ssr %s glow %s fog %s vol fog %s" % [env.sdfgi_enabled, env.ssao_enabled, env.ssil_enabled, env.ssr_enabled, env.glow_enabled, env.fog_enabled, env.volumetric_fog_enabled])


func _env() -> Environment:
	var we: WorldEnvironment = _map.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null:
		return we.environment
	return get_viewport().world_3d.environment if get_viewport().world_3d != null else null


func _apply_ab() -> void:
	if _ab.is_empty():
		return
	print("[perf] A/B: " + ",".join(_ab))
	if "zsmooth" in _ab:   # T-162: the zombies' render-rate smoothing on (it is off headless), to price it with --probe
		Zombie.smooth_motion = true
	if "no_post" in _ab:   # T-208: the post stack off (LookPost / PostFx), to price the one full-screen pass
		for lp: Node in get_tree().get_nodes_in_group(&"look_post"):
			(lp as CanvasLayer).visible = false
	if "no_shadow_proxy" in _ab:   # the batches cast their own shadows again (before T-070's ShadowProxies)
		ShadowProxies.undo(_map)
	var env: Environment = _env()
	for n: Node in _all_nodes():
		if n is Light3D:
			var l: Light3D = n as Light3D
			if "no_shadows" in _ab or ("no_omni_shadows" in _ab and not (l is DirectionalLight3D)) or ("no_dir_shadows" in _ab and l is DirectionalLight3D):
				l.shadow_enabled = false
			if "no_lights" in _ab and not (l is DirectionalLight3D):
				l.visible = false
		if ("hide_zombies" in _ab or "hide_movers" in _ab) and n is Zombie:
			(n as Node3D).visible = false
		if "hide_movers" in _ab and n is Player:
			(n as Node3D).visible = false
		if "omni_dp" in _ab and n is OmniLight3D:
			(n as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		if "no_spot_shadows" in _ab and n is SpotLight3D:
			(n as SpotLight3D).shadow_enabled = false
		if "no_anim" in _ab and n is AnimationMixer and _is_under_zombie(n):
			(n as AnimationMixer).active = false
	if env != null:
		if "no_sdfgi" in _ab:
			env.sdfgi_enabled = false
		if "no_fog" in _ab:
			env.volumetric_fog_enabled = false
		if "no_ssao" in _ab:
			env.ssao_enabled = false
			env.ssil_enabled = false
		if "no_glow" in _ab:
			env.glow_enabled = false


func _is_under_zombie(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p is Zombie:
			return true
		p = p.get_parent()
	return false


## `-- --ts`: the rendering device's captured timestamps of one frame (names, CPU and GPU ms from the first).
func _print_timestamps() -> void:
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd == null:
		return
	var n: int = rd.get_captured_timestamps_count()
	print("[perf] timestamps: %d (frame %d)" % [n, rd.get_captured_timestamps_frame()])
	if n == 0:
		return
	var c0: int = rd.get_captured_timestamp_cpu_time(0)
	var g0: int = rd.get_captured_timestamp_gpu_time(0)
	for i: int in n:
		print("[perf]   %-40s cpu %.3f gpu %.3f" % [rd.get_captured_timestamp_name(i), (rd.get_captured_timestamp_cpu_time(i) - c0) / 1000.0, (rd.get_captured_timestamp_gpu_time(i) - g0) / 1000000.0])


## `-- --mm-bench`: the minimap's parts timed in a tight loop (200 calls each, no frame noise), microseconds per call.
func _minimap_bench() -> void:
	var mm: Minimap = _map.find_child("Minimap", true, false) as Minimap
	if mm == null:
		return
	var ms: MapState = MapState.current()
	var n: int = 200
	var t0: int = Time.get_ticks_usec()
	for i: int in n:
		ms.set("_live_frame", -1)
		ms.live_icons()
	var t1: int = Time.get_ticks_usec()
	for i: int in n:
		mm.canvas.call("_place_icons")
	var t2: int = Time.get_ticks_usec()
	for i: int in n:
		mm.canvas.call("_rebuild_static")
	var t3: int = Time.get_ticks_usec()
	for i: int in n:
		mm.call("_process", 0.0)
	var t4: int = Time.get_ticks_usec()
	print("[perf] minimap bench (us per call): live list %.1f, place icons (list cached) %.1f, static rebuild %.1f, minimap+canvas _process %.1f; live icons %d" % [
		(t1 - t0) / float(n), (t2 - t1) / float(n), (t3 - t2) / float(n), (t4 - t3) / float(n), ms.live_icons().size()])


# ================================================================== --views: the render census per camera (T-266)

func _views_step() -> void:
	for z: Zombie in _map.director.active_zombies():
		z.hp = maxf(z.hp, 1.0e9)
	# A software-rendered frame takes 10 s and more, but the game's clock moves at most 4 physics steps (67 ms) a
	# frame: a new view gets 9 frames (0.6 s: ShadowBudget's 0.2 s re-rank, Kaltenbrunn's moon switch 0.25 s, DayCycle's
	# roof check), another state of the same view 3 (RenderTune.set_off applies at once), then one frame is counted.
	var settle: int = (_view_settle if _quick else 30)
	var counted: int = 1 if _quick else 2
	if _states.is_empty():
		_build_states()
	if _view_i < 0 or _view_f >= settle + counted:
		if _view_i >= 0:
			_view_done()
			_state_i += 1
		_view_settle = 3
		if _view_i < 0 or _state_i >= _states.size():   # the next view (each view is counted in every state before moving on,
			_view_i += 1                                 # so a pair is seconds apart and the living map has not moved on)
			_state_i = 0
			_view_settle = 9
		_view_f = 0
		_view_acc = {}
		if _view_i >= _views.size():
			for st: Dictionary in _states:
				print("[views] %s%s h%s:" % [str(GLSettings.values.get("graphics_preset", "high")), st["tag"], ("%.0f" % _hour) if _hour >= 0.0 else "-"])
				PerfViews.summary(st["rows"])
				st["rows"] = []
			if not _hours.is_empty() and DayCycle.of(_map) != null:
				_hour = _hours[0]
				_hours.remove_at(0)
				DayCycle.of(_map).hold_hour(_hour)
				print("[perf] the day held at hour %.1f" % _hour)
				_view_i = -1
				return
			print("[perf] active zombies %d   GPU: %s" % [_map.director.active_zombies().size(), RenderingServer.get_video_adapter_name()])
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
			get_tree().quit()
			_views_on = false
			_phase = 9
			return
		if _states.size() > 1:
			RenderTune.set_off(_map, PackedStringArray(_states[_state_i]["off"]))
	var v: Dictionary = _views[_view_i]
	if "--cheap" in OS.get_cmdline_user_args():
		_cheap_pixels()
	var cc: Camera3D = get_viewport().get_camera_3d()
	if cc is CinemaCamera and cc.get_parent() is CinemaDirector:   # a set piece playing at this round: back to the player's eye
		(cc.get_parent() as CinemaDirector).release(true)
	PerfViews.stand(_map, v)   # every frame: nothing drifts while the view settles
	_view_f += 1
	if _view_f > settle:
		PerfViews.add_render(_view_acc, get_viewport())


## The states every view is counted in: the build as it runs, or with `--t266-ab` T-266's passes all off ("/before"),
## then switched on step by step.
func _build_states() -> void:
	if not _ab_t266:
		_states = [{"tag": "" if RenderTune.off.is_empty() else "/-" + "-".join(RenderTune.off), "off": RenderTune.off.duplicate(), "rows": []}]
		return
	var off: PackedStringArray = RenderTune.FEATURES.duplicate()
	_states = [{"tag": "/before", "off": off.duplicate(), "rows": []}]
	for step: PackedStringArray in _ab_steps:
		for f: String in step:
			if off.has(f):
				off.remove_at(off.find(f))
		_states.append({"tag": ("/-" + "-".join(off)) if not off.is_empty() else "", "off": off.duplicate(), "rows": []})


func _view_done() -> void:
	var v: Dictionary = _views[_view_i]
	var st: Dictionary = _states[_state_i]
	var row: Dictionary = PerfViews.census(_map, get_viewport().get_camera_3d())
	for k: String in _view_acc:
		row[k] = float(_view_acc[k]) / (1.0 if _quick else 2.0)
	row["name"] = v["name"]
	(st["rows"] as Array).append(row)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to((v["pos"] as Vector3) + Vector3.UP * 1.6) > 1.5:
		print("[view] NOTE %s: the camera is at %s (%s), not at the view" % [v["name"], str(cam.global_position.snapped(Vector3.ONE * 0.1)), str(cam.get_path())])
	print("[view] %s %s%s h%s %s at %s | %s" % [str(_map.map_id), str(GLSettings.values.get("graphics_preset", "high")), st["tag"],
		("%.0f" % _hour) if _hour >= 0.0 else "-", v["name"], str(v["pos"]), PerfViews.line(row)])


## `--cheap`: see the header. Applied at every view (GLSettings.apply_visuals may run again in between).
func _cheap_pixels() -> void:
	var vp: Viewport = get_viewport()
	vp.scaling_3d_scale = 0.25
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.positional_shadow_atlas_size = 256
	RenderingServer.directional_shadow_atlas_set_size(256, true)
	var env: Environment = _env()
	if env != null:
		env.sdfgi_enabled = false
		env.ssil_enabled = false
		env.ssao_enabled = false
		env.ssr_enabled = false
		env.volumetric_fog_enabled = false
		env.glow_enabled = false


# ================================================================== T-281: the horde's size

## Puts `n` more zombies up at the director's spawns (as `debug_spawn`), growing the pool first if it has too few
## free bodies; with `--mix=high` the specs are a late round's (see the header).
func _spawn_horde(n: int) -> void:
	var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
	var free: Array = dir.get("_free")
	var pool: Array = dir.get("_pool")
	# the pool is grown once, before the window, with room for the dead still lying (so no body is built in the window)
	var want: int = n if _spawned > 0 else n + (24 if _kill_rate > 0.0 or _mix != "" else 0)
	while free.size() < want:
		var z: Zombie = Zombie.new()
		z.name = "ZombieX%02d" % pool.size()
		z.director = dir
		z.net_id = pool.size()
		dir.add_child(z)
		pool.append(z)
		free.append(z)
	if _mix == "":
		dir.debug_spawn(n)
		_spawned += n
		return
	var fire_cfg: Dictionary = (GLData.load_json("res://data/gravelight/sherman.json") as Dictionary).get("fire_zombie", {})
	for i: int in n:
		var sp: ZombieSpawn = dir.call("_choose_spawn") as ZombieSpawn
		if sp == null or free.is_empty():
			return
		RoundManager.to_spawn += 1
		var spec: Dictionary = RoundManager.take_spawn()
		spec["variant"] = dir.call("_pick_variant")
		var k: int = _spawned
		_spawned += 1
		spec["tier"] = [&"run", &"sprint", &"jog", &"run", &"sprint"][k % 5]
		if k % 5 == 4:
			spec["crawler"] = true
		var z2: Zombie = free.pop_back()
		z2.activate(spec, sp, dir.call("_any_player") as Player)
		if k % 6 == 5 and not fire_cfg.is_empty():
			FireZombie.make(z2, fire_cfg, null, true)


## `--kills=K`: K kills a second, spread over the second, each with another damage kind and hit part.
func _kill_step(delta: float) -> void:
	_kill_acc += _kill_rate * delta
	while _kill_acc >= 1.0:
		_kill_acc -= 1.0
		var live_z: Array = _map.director.active_zombies()
		if live_z.is_empty():
			return
		var kz: Zombie = live_z[_kill_i % live_z.size()]
		var ki: int = _kill_i % 4
		_kill_i += 1
		kz.hp = 1.0
		kz.take_damage(50.0, [&"head", &"torso", &"arms", &"legs"][ki], &"", _map.player.player_id, &"explosive" if ki == 1 else &"bullet")


func _report_t281() -> void:
	var zs: Array = _map.director.active_zombies()
	var agents: int = int(Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT))
	print("[t281] zombies %d (asked %d, mix %s, kills %.1f/s), deaths in the window %d, nav agents %d, nav maps %d, physics active %d, islands %d, pairs %d" % [
		zs.size(), _zcount, _mix if _mix != "" else "-", _kill_rate, _deaths, agents,
		int(Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS)), int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)), int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))])
	# what one zombie hands the renderer (counted from the tree: the render side's CPU cost per body, not timed here)
	var geo: int = 0
	var surf: int = 0
	var skinned: int = 0
	var casters: int = 0
	var cast_surf: int = 0
	var lights: int = 0
	var shadow_lights: int = 0
	var particles: int = 0
	var areas: int = 0
	var areas_live: int = 0
	var mats: Dictionary = {}
	for z: Zombie in zs:
		var stack: Array[Node] = [z]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c: Node in n.get_children():
				stack.append(c)
			if n is Area3D:
				areas += 1
				if (n as Area3D).collision_layer != 0:
					areas_live += 1
			if n is Light3D and (n as Light3D).is_visible_in_tree():
				lights += 1
				if (n as Light3D).shadow_enabled:
					shadow_lights += 1
			if n is GPUParticles3D and (n as GPUParticles3D).emitting:
				particles += 1
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
				continue
			geo += 1
			var sc: int = mi.mesh.get_surface_count()
			surf += sc
			if mi.skin != null:
				skinned += 1
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				casters += 1
				cast_surf += sc
			for si: int in sc:
				var m: Material = mi.get_active_material(si)
				if m != null:
					mats[m.get_instance_id()] = true
	var zsc: GDScript = load("res://gravelight/enemies/zombie.gd") as GDScript
	if zsc.get("lod_frames") != null:
		var lf: PackedInt64Array = zsc.get("lod_frames")
		var lt: float = maxf(1.0, float(lf[0] + lf[1] + lf[2] + lf[3]))
		print("[t283] animation rate (zombie-frames, whole run): full %d (%.0f %%), half %d (%.0f %%), a quarter by distance %d (%.0f %%), a quarter out of view %d (%.0f %%) (t283_opt %s)" % [
			lf[0], 100.0 * lf[0] / lt, lf[1], 100.0 * lf[1] / lt, lf[2], 100.0 * lf[2] / lt, lf[3], 100.0 * lf[3] / lt, str(zsc.get("t283_opt"))])
	if zsc.get("halt_skips") != null:
		print("[t281] work counted (whole run): halted slides skipped at rest %d, feet whose two rays were kept %d (t281_opt %s)" % [int(zsc.get("halt_skips")), int(zsc.get("foot_ray_reuses")), str(zsc.get("t281_opt"))])
	var rgs: GDScript = load("res://gravelight/enemies/zombie_ragdoll.gd") as GDScript
	if rgs.get("built") != null:
		print("[t281] work counted (whole run): ragdoll rigs built new %d, taken from the kept ones %d" % [int(rgs.get("built")), int(rgs.get("reused"))])
	var nz: float = float(maxi(1, zs.size()))
	print("[t281] per zombie (of %d up): visible meshes %.1f, surfaces %.1f (draw calls in the colour pass), skinned %.2f, shadow casters %.1f with %.1f surfaces (draw calls in every shadow view they stand in), lights %.2f (%.2f shadowed), particle systems %.2f, areas %.1f (%.1f with a layer); %d distinct materials over the horde" % [
		zs.size(), geo / nz, surf / nz, skinned / nz, casters / nz, cast_surf / nz, lights / nz, shadow_lights / nz, particles / nz, areas / nz, areas_live / nz, mats.size()])


## T-281 diagnosis only (they change what the zombies do; never for a before / after): `--ab=z_no_zcollide` (the
## zombies' bodies do not collide with each other), `z_no_avoid` (no avoidance: each walks its own path velocity),
## `z_no_dead_areas` (the hitboxes without a collision layer taken out of the physics space). Kept each frame:
## the zombie's own code sets these again on state changes.
var _z_areas: Dictionary = {}


func _ab_zombies() -> void:
	for z: Zombie in _map.director.active_zombies():
		if "z_no_zcollide" in _ab:
			z.collision_mask &= ~Zombie.LAYER_ZBODY
		if "z_no_avoid" in _ab:
			var ag: NavigationAgent3D = z.get("_agent") as NavigationAgent3D
			if ag != null and ag.avoidance_enabled:
				ag.avoidance_enabled = false
		if "z_no_areas" in _ab:
			if not _z_areas.has(z):
				_z_areas[z] = z.find_children("*", "Area3D", true, false)
			for c: Node in _z_areas[z]:
				if (c as Area3D).process_mode != Node.PROCESS_MODE_DISABLED:
					(c as Area3D).process_mode = Node.PROCESS_MODE_DISABLED
		if "z_no_dead_areas" in _ab:
			if not _z_areas.has(z):
				_z_areas[z] = z.find_children("*", "Area3D", true, false)
			for c: Node in _z_areas[z]:
				var ar: Area3D = c as Area3D
				var want: Node.ProcessMode = Node.PROCESS_MODE_DISABLED if ar.collision_layer == 0 else Node.PROCESS_MODE_INHERIT
				if ar.process_mode != want:
					ar.process_mode = want


## `--flip=<name>`: one side a second, the first 15 frames after a switch left out (the change settling).
func _flip_step() -> void:
	_flip_f += 1
	if _flip_f >= 60:
		_flip_f = 0
		_flip_on = not _flip_on
		_flip_apply()


func _flip_apply() -> void:
	match _flip:
		"t281":
			Zombie.t281_opt = _flip_on
		"t283":
			Zombie.t283_opt = _flip_on
		"t283_skel":
			Zombie.t283_skel = _flip_on
		"t283_rays":
			Zombie.t283_rays = _flip_on
		"t283_lod":
			Zombie.t283_lod = _flip_on
		"z_no_areas":
			if _flip_on:
				if not _ab.has(_flip):
					_ab.append(_flip)
			else:
				if _ab.has(_flip):
					_ab.remove_at(_ab.find(_flip))
				for z: Node in _z_areas.keys():   # back as built: the zombie's own layers decide (the dead boxes stay out)
					if is_instance_valid(z):
						for c: Node in _z_areas[z]:
							var ar: Area3D = c as Area3D
							ar.process_mode = Node.PROCESS_MODE_DISABLED if (ar.collision_layer == 0 and Zombie.t281_opt) else Node.PROCESS_MODE_INHERIT
		"z_no_zcollide", "z_no_avoid", "z_no_dead_areas":
			if _flip_on:
				if not _ab.has(_flip):
					_ab.append(_flip)
			else:
				if _ab.has(_flip):
					_ab.remove_at(_ab.find(_flip))
				for z: Zombie in _map.director.active_zombies():   # back as built
					if _flip == "z_no_zcollide":
						z.collision_mask |= Zombie.LAYER_ZBODY
					elif _flip == "z_no_avoid" and z.state == Zombie.State.CHASE:
						(z.get("_agent") as NavigationAgent3D).avoidance_enabled = true
					elif _flip == "z_no_dead_areas" and _z_areas.has(z):
						for c: Node in _z_areas[z]:
							(c as Area3D).process_mode = Node.PROCESS_MODE_INHERIT


func _flip_add(key: String, us: int) -> void:
	if _flip == "" or _flip_f < 15 or not (_t > 9.0 and _t < _t_end):
		return
	var k: String = key + ("/on" if _flip_on else "/off")
	if not _flip_s.has(k):
		_flip_s[k] = []   # (a plain Array: a packed one taken out of the dictionary is a copy)
	(_flip_s[k] as Array).append(us)


func _report_flip() -> void:
	if _flip == "":
		return
	var what: String = "on = the diagnostic applied, off = as built"
	if _flip == "t281":
		what = "on = as built (Zombie.t281_opt true), off = the T-281 changes off"
	elif _flip.begins_with("t283"):
		what = "on = as built (Zombie.%s true), off = that T-283 part off" % ("t283_opt" if _flip == "t283" else _flip)
	print("[flip] %s: %s; ms" % [_flip, what])
	print("[flip]   columns: mean / p50 / p95 / p99 / 1%% worst (the mean of the slowest hundredth) / max, then the samples")
	for key: String in ["frame", "scripts per physics tick", "scripts per process frame", "zombie.gd phys", "zombie.gd proc", "bot_brain.gd phys", "after physics scripts", "after process scripts"]:
		var parts: PackedStringArray = []
		for side: String in ["on", "off"]:
			var samples: PackedInt32Array = PackedInt32Array(_flip_s.get(key + "/" + side, []) as Array)
			var d: Array = dist(samples)
			var srt: PackedInt32Array = samples.duplicate()
			srt.sort()
			var ln: int = maxi(1, srt.size() / 100)
			var low: float = 0.0
			for li: int in mini(ln, srt.size()):
				low += float(srt[srt.size() - 1 - li])
			low = low / float(ln) / 1000.0
			parts.append("%s %.3f / %.3f / %.3f / %.3f / %.3f / %.3f (%d)" % [side, d[0], d[1], d[2], d[3], low, d[4], samples.size()])
		print("[flip]   %-28s %s" % [key, " | ".join(parts)])
