extends Node
## Dev tool (T-057): Map 0's staircase, one zombie at a time. Each trial spawns a zombie of `--tier` in the stair
## vestibule or the taproom by Door 1 and puts a god-mode player upstairs (the stair head, the hall, a guest room);
## `--down` swaps them. A trial passes when the zombie gets within 2 m of the player in `--seconds` (default 22).
## Before T-057 every runner snagged on the balustrade end at the stair foot, about (3.6, 0, 14.6), and walkers
## also stopped at the stair-head seam, about (3, 3.7, 9.3). Prints the trail of any that fail, and a RESULT line.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/soak_stairs.tscn -- [--tier=run] [--down] [--trials=40]

const TARGETS: Array = [Vector3(11.5, 3.8, 4.0), Vector3(4.6, 3.8, 8.0), Vector3(4.0, 3.8, 3.4), Vector3(12.0, 3.8, 8.0)]

var map: Node3D
var player: Player
var director: ZombieDirector
var tier: StringName = &"run"
var down: bool = false
var trials: int = 40
var seconds: float = 22.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--down":
			down = true
		elif a.begins_with("--tier="):
			tier = StringName(a.substr(7))
		elif a.begins_with("--trials="):
			trials = int(a.substr(9))
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
	ProfileSave.path = "user://_soak_stairs_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	_go.call_deferred()


func _physics_process(_delta: float) -> void:
	Zombie.repath_budget = 8   # the director (which refills it) is paused: no round spawns get in the way


func _go() -> void:
	for i: int in 30:
		await get_tree().physics_frame
	GameState.god_mode = true
	player = map.get_node("Player1") as Player
	director = map.get_node("ZombieDirector") as ZombieDirector
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor:
			(n as BuyDoor).open(1)
	director.kill_all(false)
	director.set_physics_process(false)
	director.set_process(false)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var failed: int = 0
	var ran: int = 0
	for k: int in trials:
		var low: Vector3 = Vector3(rng.randf_range(4.3, 5.6), 0.0, rng.randf_range(14.5, 15.6)) if k % 2 == 0 \
			else Vector3(rng.randf_range(7.0, 10.0), 0.0, rng.randf_range(12.0, 15.2))
		var high: Vector3 = TARGETS[k % TARGETS.size()]
		var start: Vector3 = high + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5)) if down else low
		var goal: Vector3 = low if down else high
		var spec: Dictionary = RoundManager.take_extra_spawn()
		spec["tier"] = tier
		spec["health"] = 99999.0
		var z: Zombie = director._activate_at(spec, start)
		if z == null:
			continue
		ran += 1
		var t: float = 0.0
		var trail: PackedStringArray = []
		var ok: bool = false
		while t < seconds:
			player.global_position = goal
			player.velocity = Vector3.ZERO
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if int(t * 60.0) % 30 == 0:
				trail.append("%.1f %s" % [t, str(z.global_position.snapped(Vector3.ONE * 0.1))])
			if Vector2(z.global_position.x - goal.x, z.global_position.z - goal.z).length() < 2.0 and absf(z.global_position.y - goal.y) < 1.5:
				ok = true
				break
		if not ok:
			failed += 1
			print("[stairs] FAIL trial %d from %s to %s, ended at %s | %s" % [k, start.snapped(Vector3.ONE * 0.1), goal,
				z.global_position.snapped(Vector3.ONE * 0.1), " | ".join(trail.slice(maxi(0, trail.size() - 12)))])
		z.kill_silently()
		for i: int in 5:
			await get_tree().physics_frame
	print("[stairs] %s, %s: %d of %d reached the player" % [tier, "down" if down else "up", ran - failed, ran])
	print("[stairs] RESULT: %s" % ("PASS" if failed == 0 else "FAIL (%d)" % failed))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_soak_stairs_profile.json"))
	get_tree().quit(0 if failed == 0 else 1)
