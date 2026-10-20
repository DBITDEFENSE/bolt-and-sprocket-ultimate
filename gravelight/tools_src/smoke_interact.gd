extends Node
## Scripted gameplay QA for Map 0: drives the real Player with simulated input and checks results.
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_interact.tscn

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _explosions: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	GLBus.explosion.connect(func(_pos: Vector3, _r: float) -> void: _explosions += 1)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _secs(seconds)
	Input.action_release(action)
	await _frames(2)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _place(pos: Vector3, yaw_deg: float, pitch_deg: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw_deg)
	_p.set("_pitch", deg_to_rad(pitch_deg))
	await _frames(3)


func _check(cond: bool, what: String) -> void:
	print("[qa] %-52s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _run() -> void:
	await _frames(10)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	GameState.god_mode = true
	Economy.grant(1, 4500)   # 5000 total

	# 1. Wall-buy (Kar98k on the taproom west wall, 200)
	await _place(Vector3(1.3, 0, 8.6), 90.0)
	_check(_p.prompt_text.contains("Kar98k"), "wall-buy prompt shows: " + _p.prompt_text)
	var before: int = Economy.get_scrip(1)
	await _hold(&"interact", 0.6)
	_check(_p.weapons.find_weapon(&"kar98k") != null, "bought Kar98k")
	_check(Economy.get_scrip(1) == before - 200, "charged 200 Scrip")
	_check(_p.weapons.current().id == &"kar98k", "switched to the new weapon")

	# 2. Door (Upstairs, 750)
	await _place(Vector3(4.6, 0, 15.1), 90.0)
	_check(_p.prompt_text.contains("Upstairs"), "door prompt shows: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _hold(&"interact", 0.6)
	_check(GameState.is_zone_open(&"UPSTAIRS"), "door opened the UPSTAIRS zone")
	_check(Economy.get_scrip(1) == before - 750, "charged 750 Scrip")
	await _secs(1.0)
	await _place(Vector3(4.6, 0, 15.1), 90.0)
	Input.action_press(&"move_forward")
	await _secs(1.2)
	Input.action_release(&"move_forward")
	_check(_p.global_position.x < 2.9, "can walk through the opened door (x=%.2f)" % _p.global_position.x)

	# 3. Barricade repair (east window)
	var win: Barricade = _map.get_node("Gameplay/W_TAP_E") as Barricade
	win.tear_board()
	win.tear_board()
	win.tear_board()
	_check(win.boards == 3, "zombie API tore 3 boards")
	await _place(Vector3(22.7, 0, 8.0), -90.0, -10.0)
	_check(_p.prompt_text.contains("rebuild"), "repair prompt shows: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _hold(&"interact", 2.4)
	_check(win.boards == 6, "repaired back to 6 boards (got %d)" % win.boards)
	_check(Economy.get_scrip(1) == before + 30, "earned 10 Scrip per board")

	# 4. Shooting: a zombie standing 6 m in front, aim at the chest
	await _tap(&"weapon_1")
	await _secs(0.6)
	await _place(Vector3(14, 0, 12), 0.0, -4.0)
	_dir.debug_spawn(1)
	await _frames(2)
	var z: Zombie = _dir.active_zombies()[0]
	z.set_physics_process(false)
	z.global_position = Vector3(14, 0, 6)
	z.rotation.y = 0.0
	await _frames(3)
	var hp0: float = z.hp
	var mag0: int = _p.weapons.current().mag
	await _tap(&"fire")
	await _frames(5)
	_check(_p.weapons.current().mag == mag0 - 1, "firing used one round")
	_check(z.hp < hp0 or not z.is_active(), "bullet damaged the zombie (%.0f -> %.0f)" % [hp0, z.hp])

	# 5. Reload
	await _secs(0.4)
	var w: WeaponInstance = _p.weapons.current()
	await _tap(&"reload")
	await _secs(3.5)
	_check(w.mag == w.mag_size(), "reload refilled the magazine (%d/%d)" % [w.mag, w.mag_size()])

	# 6. Knife: zombie right in front
	if not z.is_active():
		_dir.debug_spawn(1)
		await _frames(2)
		z = _dir.active_zombies()[0]
		z.set_physics_process(false)
	z.global_position = Vector3(14, 0, 10.6)
	await _frames(3)
	var hp1: float = z.hp
	await _tap(&"melee")
	await _secs(0.7)
	_check(z.hp < hp1 or not z.is_active(), "knife hit the zombie")

	# 7. Grenade: cook briefly and throw
	var nades: int = _p.weapons.grenades
	await _place(Vector3(14, 0, 12), 0.0, 10.0)
	await _hold(&"lethal", 0.3)
	_check(_p.weapons.grenades == nades - 1, "threw a grenade")
	await _secs(4.5)
	_check(_explosions >= 1, "grenade exploded")

	# 8. Downed -> game over (solo)
	GameState.god_mode = false
	_p.take_hit(500.0, null)
	await _secs(0.5)
	_check(GameState.phase == GameState.Phase.GAME_OVER, "solo down ends the game")

	print("[qa] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
