extends Node
## UPDATE 10 s6 item 1 (T-162): what Zombie smoothing costs per zombie per rendered frame. 32 zombies, each stepped 100k
## frames through Zombie._smooth_visual (the whole of the added per-frame work) with smoothing off and on, plus the
## tick-side capture (_tick_prev = global_position) it needs. Prints microseconds per zombie-frame.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/bench_zombie_smooth.tscn

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	GLSettings.values["gore"] = "off"
	RoundManager.current_round = 5
	GameState.player_ids = [1]
	Economy.reset([1])
	var host: Node3D = Node3D.new()
	add_child(host)
	var spawn: ZombieSpawn = ZombieSpawn.new()
	spawn.kind = &"ground"
	host.add_child(spawn)
	var zs: Array[Zombie] = []
	for i: int in 32:
		var z: Zombie = Zombie.new()
		host.add_child(z)
		z.activate({"enemy_id": "ganger", "tier": "walk", "health": 400.0, "variant": "villager"}, spawn, null)
		z.global_position = Vector3(float(i), 0.0, 0.0)
		z._enter(Zombie.State.CHASE)
		zs.append(z)
	print("[bench_zombie_smooth] %d zombies ready" % zs.size())
	var frames: int = 3000
	for mode: bool in [false, true]:
		Zombie.smooth_motion = mode
		var t0: int = Time.get_ticks_usec()
		for f: int in frames:
			for z: Zombie in zs:
				if Zombie.smooth_motion:
					z._tick_prev = z.global_position - Vector3(0.05, 0.0, 0.0)   # (what _physics_process stores)
				z._smooth_visual(Zombie.smooth_motion)
		var us: float = float(Time.get_ticks_usec() - t0) / float(frames * zs.size())
		print("[bench_zombie_smooth] smoothing %s: %.3f us per zombie-frame" % ["ON " if mode else "off", us])
	Zombie.smooth_motion = false
	get_tree().quit(0)
