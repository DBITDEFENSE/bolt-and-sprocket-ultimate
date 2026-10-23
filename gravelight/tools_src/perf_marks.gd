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

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const SPIKE_MS: float = 40.0

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
var _probe: bool = "--probe" in OS.get_cmdline_user_args()
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
## hide_movers (zombies and players hidden), omni_dp (dual-paraboloid omni shadows), no_spot_shadows
var _ab: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ab="):
			_ab = a.substr(5).split(",")
		elif a.begins_with("--preset="):   # low / medium / high (the default)
			GLSettings.values["graphics_preset"] = a.substr(9)
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	GameState.god_mode = true
	if _breakdown:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		get_tree().node_added.connect(_on_node_added)
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
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
			if _t > 3.0 and _map.squad != null:
				_phase = 1
				RoundManager.debug_set_round(15)
				GLConsole.call("run", "jakub join")
		1:
			if _t > 5.0:
				_phase = 2
				RoundManager.stop()
				(_map.get_node("ZombieDirector") as ZombieDirector).debug_spawn(24)
				if not ("--no-marks" in OS.get_cmdline_user_args()):
					_place_marks()
				print("[perf] round %d, bots %d, jakub %s, marks %d" % [RoundManager.current_round, GameState.bot_ids.size(),
					str(JakubCompanion.instance(get_tree()) != null), MapMarks.current().marks().size()])
		2 when _t > 8.0 and not _census_done:
			_census_done = true
			if _breakdown or not _ab.is_empty():
				_census()
			_apply_ab()
		2:
			for z: Zombie in _map.director.active_zombies():
				z.hp = maxf(z.hp, 1.0e9)
			if _probe:
				_probe_scan_t -= delta
				if _probe_scan_t <= 0.0:
					_probe_scan_t = 0.5
					_probe_scan()
			if "--ts" in OS.get_cmdline_user_args() and _t > 15.0 and _t - delta <= 15.0:
				_print_timestamps()
			if "--mm-bench" in OS.get_cmdline_user_args() and _t > 16.0 and _t - delta <= 16.0:
				_minimap_bench()
			if _t > 9.0 and _t < 24.0:
				_samples.append(delta)
				_frame_stats(delta)
			if _t >= 24.0:
				_report("in play", _samples)
				_report_breakdown()
				if _probe:
					_probe_release()
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


func _on_node_added(n: Node) -> void:
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
	var stack: Array[Node] = [_map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var s: Script = n.get_script() as Script
		if s == null:
			continue
		var has_p: bool = n.has_method(&"_process") and n.is_processing()
		var has_pp: bool = n.has_method(&"_physics_process") and n.is_physics_processing()
		if not has_p and not has_pp:
			continue
		var key: String = s.resource_path.get_file()
		if not _groups.has(key):
			_groups[key] = {"proc": [], "phys": [], "us_proc": 0.0, "us_phys": 0.0}
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
	var counting: bool = _t > 9.0 and _t < 24.0
	if counting:
		if physics:
			_probe_pframes += 1
		else:
			_probe_frames += 1
	var list_key: String = "phys" if physics else "proc"
	var us_key: String = "us_phys" if physics else "us_proc"
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
			g[us_key] = float(g[us_key]) + float(Time.get_ticks_usec() - t0)


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
