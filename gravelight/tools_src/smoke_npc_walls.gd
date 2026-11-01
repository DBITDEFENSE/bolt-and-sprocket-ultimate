extends Node
## T-143 headless smoke: nobody stands pressed against a wall. Runs NpcWallProbe on Map 0 and Kaltenbrunn for 4 game
## minutes at x4 with 3 bots, the human on player bot mode and every companion in the match (Jakub, Trudi, Ammer), and
## FAILS if any NPC or bot walks into a wall and goes nowhere for 3 s (it wants to move, moved under 5 cm and has a
## wall within 40 cm of its edge ahead), or if any person's place (survivors' hiding places and posts, companions'
## spots, the extra people and their items) is off the navmesh or against a wall, or a survivor's walk clips one.
## One RESULT line. Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_npc_walls.tscn
## [-- --minutes=4 --speed=4 --only=map01]

var minutes: float = 4.0
var speed: float = 4.0
var only: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = float(a.substr(10))
		elif a.begins_with("--speed="):
			speed = float(a.substr(8))
		elif a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	var pressed: int = 0
	var spots: int = 0
	var bodies: int = 0
	for m: String in ["map00", "map01"]:
		if only != "" and only != m:
			continue
		var probe: NpcWallProbe = NpcWallProbe.new()
		probe.map_name = m
		probe.minutes = minutes
		probe.speed = speed
		probe.bots = 3
		probe.companions = true
		add_child(probe)
		await probe.run()
		pressed += probe.offenders.size()
		spots += probe.static_issues.size()
		bodies += probe.watched.size()
		for o: Dictionary in probe.offenders:
			print("[npc-walls-smoke] %s PRESSED %s" % [m, str(o["text"])])
		for s: String in probe.static_issues:
			print("[npc-walls-smoke] %s SPOT %s" % [m, s])
		if probe.map != null and is_instance_valid(probe.map):
			probe.map.queue_free()
		probe.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Engine.time_scale = 1.0
	var ok: bool = pressed == 0 and spots == 0 and bodies > 0
	print("[npc-walls-smoke] RESULT: %s (%d pressed, %d spot issues, %d bodies watched)" % ["PASS" if ok else "FAIL", pressed, spots, bodies])
	get_tree().quit(0 if ok else 1)
