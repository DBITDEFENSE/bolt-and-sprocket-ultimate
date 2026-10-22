extends Node
## Clip harness (Update 02 §1): drives the real Player on the Test Range through the input actions a person
## would press, in four scripted segments, so the same script can be recorded before and after a feel change:
##   1 SPRINT -> FIRE   sprint at the north wall, press and hold fire while sprint is still held
##   2 ADS STRAFE       aim, strafe right then left, tapping fire
##   3 SLIDE            sprint, crouch into a slide, fire from the hip near its end
##   4 MANTLE           walk at a 1.1 m cover block and press jump
## A caption shows the segment, the inputs held and the shots fired (GLBus.weapon_fired) so an eaten input reads.
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>/x.avi --fixed-fps 30
##         --path . res://gravelight/tools_src/clip_feel.tscn -- --tag=AFTER
## Also runs headless (no movie) and prints "[clip] seg ... shots=N" per segment and "[clip] DONE".

const SEGMENTS: Array = [
	# name, start position, yaw (deg), duration, weapon
	["1  SPRINT -> FIRE", Vector3(14.0, 0.05, 28.0), 0.0, 3.4, &"thompson"],
	["2  ADS STRAFE", Vector3(22.0, 0.05, 25.0), 0.0, 3.2, &"thompson"],
	["3  SLIDE (+ hip fire)", Vector3(14.0, 0.05, 28.0), 0.0, 3.0, &"thompson"],
	["4  MANTLE / VAULT", Vector3(10.75, 0.05, 21.2), 0.0, 3.0, &"thompson"],
]
const ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"fire",
	&"ads", &"crouch", &"jump"]

var _map: Node3D
var _p: Player
var _tag: String = "?"
var _seg: int = -1
var _t: float = 0.0
var _boot: float = 0.0
var _shots: int = 0
var _seg_shots: int = 0
var _first_shot_t: float = -1.0
var _caption: Label
var _inputs: Label
var _held: Dictionary = {}
var _taps: Dictionary = {}       # action -> frames left pressed (a tap)
var _start_z: float = 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.substr(6)
	GLSettings.values["bots"] = 0
	GLSettings.values["fov"] = 80.0
	GLSettings.values["screen_shake"] = 1.0
	GameState.god_mode = true
	_map = (load("res://gravelight/maps/test_range/test_range.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	_caption = Label.new()
	_caption.position = Vector2(40, 30)
	_caption.add_theme_font_size_override("font_size", 44)
	_caption.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 8)
	cl.add_child(_caption)
	_inputs = Label.new()
	_inputs.position = Vector2(40, 96)
	_inputs.add_theme_font_size_override("font_size", 30)
	_inputs.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_inputs.add_theme_constant_override("outline_size", 6)
	cl.add_child(_inputs)
	GLBus.weapon_fired.connect(func(_pid: int, _w: StringName, _u: bool, _o: Vector3, _d: Vector3) -> void:
		_shots += 1
		_seg_shots += 1
		if _first_shot_t < 0.0:
			_first_shot_t = _t)


func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never grab the mouse (the Player captures it on _ready)


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_inside_tree():
		return
	if _p == null:
		_p = _map.get_node_or_null("Player1") as Player
		if _p == null:
			return
		_p.set_process_unhandled_input(false)
	_boot += delta
	if _boot < 2.0:
		GameState.phase = GameState.Phase.PLAYING
		return
	GameState.phase = GameState.Phase.PLAYING
	if _seg < 0 or _t >= float(SEGMENTS[_seg][3]):
		if _seg >= 0:
			print("[clip] seg %d %s shots=%d first_shot_t=%.2f end=%s" % [_seg + 1, SEGMENTS[_seg][0], _seg_shots, _first_shot_t, _p.global_position])
		_seg += 1
		if _seg >= SEGMENTS.size():
			_release_all()
			print("[clip] DONE total_shots=%d" % _shots)
			get_tree().quit()
			return
		_begin(_seg)
	_t += delta
	_drive(_seg, _t)
	_caption.text = "%s   %s" % [_tag, SEGMENTS[_seg][0]]
	var held: PackedStringArray = []
	for a: StringName in [&"sprint", &"move_forward", &"move_left", &"move_right", &"ads", &"fire", &"crouch", &"jump"]:
		if Input.is_action_pressed(a):
			held.append(String(a).replace("move_", "").to_upper())
	_inputs.text = "held: %s\nshots: %d" % [" ".join(held), _seg_shots]
	_inputs.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if Input.is_action_pressed(&"fire") and _seg_shots == 0 else Color(0.95, 0.95, 0.95))


func _begin(i: int) -> void:
	_release_all()
	var s: Array = SEGMENTS[i]
	_t = 0.0
	_seg_shots = 0
	_first_shot_t = -1.0
	_p.global_position = s[1]
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(float(s[2]))
	_p.set("_pitch", deg_to_rad(-2.0))
	_p.crouching = false
	_p.sprinting = false
	if _p.sliding:
		_p.call("_end_slide", false)
	var h: WeaponHolder = _p.weapons
	if h.current() == null or h.current().id != s[4]:
		h.give_weapon(s[4])
	h.current().refill()
	h.set("_swap_t", 0.0)
	_start_z = _p.global_position.z


func _drive(i: int, t: float) -> void:
	match i:
		0:
			_hold(&"move_forward", t > 0.3)
			_hold(&"sprint", t > 0.3 and t < 2.6)
			_hold(&"fire", t > 1.3 and t < 2.4)
		1:
			_hold(&"ads", t > 0.2 and t < 2.9)
			_hold(&"move_right", t > 0.5 and t < 1.6)
			_hold(&"move_left", t > 1.6 and t < 2.8)
			_hold(&"fire", t > 0.7 and fmod(t, 0.36) < 0.12 and t < 2.8)
		2:
			_hold(&"move_forward", t > 0.2 and t < 2.4)
			_hold(&"sprint", t > 0.2 and t < 1.0)
			_tap(&"crouch", t > 0.9)
			_hold(&"fire", t > 1.45 and t < 2.4)
		3:
			_hold(&"move_forward", t > 0.3 and t < 2.4)
			_tap(&"jump", t > 0.62)
	_tick_taps()


func _hold(a: StringName, on: bool) -> void:
	if on and not bool(_held.get(a, false)):
		Input.action_press(a)
		_held[a] = true
	elif not on and bool(_held.get(a, false)):
		Input.action_release(a)
		_held[a] = false


## One press per segment once `when` turns true (held for 2 physics frames, then released).
func _tap(a: StringName, when: bool) -> void:
	var key: String = "%d_%s" % [_seg, a]
	if when and not _taps.has(key):
		_taps[key] = 2
		Input.action_press(a)


func _tick_taps() -> void:
	for k: Variant in _taps.keys():
		var n: int = int(_taps[k])
		if n > 0:
			n -= 1
			_taps[k] = n
			if n == 0:
				Input.action_release(StringName(str(k).substr(str(k).find("_") + 1)))


func _release_all() -> void:
	for a: StringName in ACTIONS:
		Input.action_release(a)
	_held.clear()
