extends SceneTree
## T-280: the CPU cost of the explosion effects alone, without a map (so a busy, shared machine's noise is smaller
## than in bench_explosions): the time inside Effects.explosion for 1 and for 6 blasts in one call, and the per-frame
## cost of keeping them alive (BlastFx._process, called here by hand with the engine's call switched off), as medians
## over many repetitions. Headless: the GPU's share (the particles' simulation and drawing) is not in it.
##   godot --headless --audio-driver Dummy --path . -s res://gravelight/tools_src/bench_blast_micro.gd [-- --reps=200]
## On a build before T-280 (no Effects.blast) it times the old Effects.explosion and Effects._process instead.

var _reps: int = 200


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--reps="):
			_reps = maxi(10, int(a.substr(7)))
	_run.call_deferred()


func _median(a: PackedFloat64Array) -> float:
	var s: PackedFloat64Array = a.duplicate()
	s.sort()
	return s[s.size() / 2]


func _worst(a: PackedFloat64Array) -> float:
	var s: PackedFloat64Array = a.duplicate()
	s.sort()
	return s[s.size() - 1]


func _p(a: PackedFloat64Array, q: float) -> float:
	var s: PackedFloat64Array = a.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(s.size() * q))]


func _run() -> void:
	await process_frame
	var fx: Node = root.get_node("Effects")
	var b: Node = fx.get("blast") as Node
	var ticker: Node = b if b != null else fx
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 2, 12)
	cam.make_current()
	var floor_body: StaticBody3D = StaticBody3D.new()   # ground under the blasts (the dirt, debris and ring run)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	await physics_frame
	await physics_frame
	for q: String in ["high", "low"]:
		(root.get_node("GLSettings").get("values") as Dictionary)["vfx_quality"] = q
		var one: PackedFloat64Array = PackedFloat64Array()
		var six: PackedFloat64Array = PackedFloat64Array()
		var tick1: PackedFloat64Array = PackedFloat64Array()
		var tick6: PackedFloat64Array = PackedFloat64Array()
		ticker.set_process(false)
		for r: int in _reps:
			var t0: int = Time.get_ticks_usec()
			if b != null:
				fx.call("explosion", Vector3(0, 0.3, 0), 6.0, "grenade")
			else:
				fx.call("explosion", Vector3(0, 0.3, 0), 6.0)
			one.append((Time.get_ticks_usec() - t0) / 1000.0)
			t0 = Time.get_ticks_usec()
			ticker.call("_process", 0.016)
			tick1.append((Time.get_ticks_usec() - t0) / 1000.0)
			t0 = Time.get_ticks_usec()
			for i: int in 6:
				var at: Vector3 = Vector3(cos(i * 1.047), 0.0, sin(i * 1.047)) * 2.0 + Vector3(0, 0.3, 0)
				if b != null:
					fx.call("explosion", at, 6.0, "grenade")
				else:
					fx.call("explosion", at, 6.0)
			six.append((Time.get_ticks_usec() - t0) / 1000.0)
			t0 = Time.get_ticks_usec()
			ticker.call("_process", 0.016)
			tick6.append((Time.get_ticks_usec() - t0) / 1000.0)
		ticker.set_process(true)
		print("[micro] %s %s: Effects.explosion x1 median %.3f ms (p95 %.3f, worst %.3f, first %.3f); x6 in one frame median %.3f ms (p95 %.3f, worst %.3f, first %.3f); a frame of live blasts after x1 %.3f ms, after x6 %.3f ms (medians over %d)" % [
			"after" if b != null else "before", q, _median(one), _p(one, 0.95), _worst(one), one[0], _median(six), _p(six, 0.95), _worst(six), six[0], _median(tick1), _median(tick6), _reps])
	quit()
