extends Node3D
## Dev tool (headless): measures gun feel numerically for every weapon.
##   godot --headless --path . res://gravelight/tools_src/feel_probe.tscn
## Per weapon: shots fired in 2 s of held trigger at 30/60/144 fps vs the data rpm (auto) — cadence must not
## depend on frame rate; camera recoil peak and how much is left 0.5 s after the last shot; viewmodel kick
## peak and settle; that a semi-auto click 0.08 s early is buffered; that nothing goes NaN.
## Prints "[feel] RESULT PASS|FAIL".

var _p: Player
var _fails: int = 0


func _ready() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(40, 1, 40)
	cs.shape = bs
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	_p = Player.new()
	add_child(_p)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_p.set_physics_process(false)
	await get_tree().process_frame
	GameState.god_mode = true
	var ids: Array = (GLData.table("weapons")["weapons"] as Dictionary).keys()
	for id: Variant in ids:
		_probe(StringName(str(id)))
	_probe(&"mp40_up")
	_probe(&"kar98k_up")
	print("[feel] RESULT %s (%d problems)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("[feel] FAIL ", what)


func _reset(id: StringName) -> WeaponInstance:
	var h: WeaponHolder = _p.weapons
	h.give_weapon(id)
	h.current_index = h.slots.find(h.find_weapon(id))
	h.call("_rebuild_gun")
	var w: WeaponInstance = h.current()
	w.reserve = 9999
	w.mag = 9999 if w.data.has("stream") or w.mag_size() > 0 else w.mag
	h.set("_swap_t", 0.0)
	h.set("_fire_cd", 0.0)
	_p.set("_rk", Vector2.ZERO)
	_p.set("_rk_v", Vector2.ZERO)
	_p.set("_pitch", 0.0)
	return w


func _probe(id: StringName) -> void:
	var w: WeaponInstance = _reset(id)
	var row: Dictionary = w.data
	if row.has("bell"):
		return
	var rpm: float = w.f("rpm", 300.0)
	var auto: bool = w.fire_mode == "auto"
	var line: String = "%-14s %-8s rpm %4d" % [id, w.weapon_class(), int(rpm)]
	# cadence at three frame rates
	for fps: int in [30, 60, 144]:
		w = _reset(id)
		var dt: float = 1.0 / float(fps)
		var shots: int = 0
		var t: float = 0.0
		var prev: int = w.mag
		while t < 2.0:
			_p.weapons.tick(dt, {"fire_pressed": true, "fire_held": true} if auto else {"fire_pressed": true, "fire_held": true})
			if w.mag < prev:
				shots += prev - w.mag
			prev = w.mag
			w.mag = maxi(w.mag, 50)
			prev = w.mag
			t += dt
		var expect: float = rpm / 60.0 * 2.0
		line += "  %dfps:%d" % [fps, shots]
		if auto and not row.has("stream"):
			_check(absf(float(shots) - expect) <= maxf(2.0, expect * 0.04), "%s cadence at %d fps: %d shots, expected ~%.0f" % [id, fps, shots, expect])
	# recoil response: one shot, then watch the camera spring for 0.6 s at 60 fps
	w = _reset(id)
	_p.weapons.tick(1.0 / 60.0, {"fire_pressed": true, "fire_held": true})
	var peak: float = 0.0
	var vm_peak: float = 0.0
	var vm: Node3D = _p.weapons.get("_vm")
	var hip: Vector3 = _p.weapons.get("_hip")
	for i: int in 36:
		_p.weapons.tick(1.0 / 60.0, {})
		_p.call("_update_camera", 1.0 / 60.0)
		var rk: Vector2 = _p.get("_rk")
		peak = maxf(peak, rk.x)
		vm_peak = maxf(vm_peak, (_p.weapons.get("_vk_p") as Vector3).length())
		_check(not is_nan(rk.x) and not is_nan(vm.position.x), "%s NaN in recoil" % id)
	var left: float = (_p.get("_rk") as Vector2).x
	line += "  cam peak %.2f deg (left %.2f)  vm kick %.1f mm" % [rad_to_deg(peak), rad_to_deg(left), vm_peak * 1000.0]
	if not row.has("stream"):
		_check(peak > 0.0, "%s: no camera kick" % id)
		_check(absf(left) < peak * 0.35 + 0.0005, "%s: camera recoil not recovering (%.3f of %.3f)" % [id, left, peak])
	# semi-auto buffer: a click 0.08 s before the gun is ready still fires
	if not auto and not row.has("stream") and 60.0 / rpm > 0.12:
		w = _reset(id)
		_p.weapons.tick(1.0 / 60.0, {"fire_pressed": true, "fire_held": true})
		var m0: int = w.mag
		_p.weapons.set("_fire_cd", 0.08)
		_p.weapons.tick(1.0 / 60.0, {"fire_pressed": true, "fire_held": true})
		for i: int in 8:
			_p.weapons.tick(1.0 / 60.0, {"fire_held": true})
		_check(w.mag == m0 - 1, "%s: early semi-auto click was dropped" % id)
	print("[feel] ", line)
