extends RefCounted
## Small post-blend horizontal contact correction. Source contact windows drive every lock;
## no gait poses or timing are synthesized. Vertical terrain adaptation stays in BodyModifier.
var pins: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var intervals: Array[int] = [-1, -1]
var previous_clip: String = ""
var correction: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]

func reset() -> void:
	intervals = [-1, -1]
	correction = [Vector3.ZERO, Vector3.ZERO]
	previous_clip = ""

## The corrections of the last apply() again, on a pose that has been rebuilt since (a frame on which the zombie's
## animation did not advance but its skeleton pass ran).
func reapply(sk: Skeleton3D, solver: ZombieBodyModifier) -> void:
	for i: int in 2:
		if correction[i].length_squared() <= 0.00000001: continue
		var side: String = "Left" if i == 0 else "Right"
		var fi: int = sk.find_bone(side + "Foot")
		if fi < 0: continue
		solver.solve_foot_target(sk, side, sk.to_local(sk.to_global(sk.get_bone_global_pose(fi).origin) + correction[i]))

func apply(sk: Skeleton3D, solver: ZombieBodyModifier, clip: String, time: float, dt: float, config: Dictionary) -> void:
	if clip != previous_clip: reset()
	previous_clip = clip
	var windows: Dictionary = ZombieClips.contact_windows(clip)
	var max_correction: float = float(config["max_correction_m"])
	var release_seconds: float = float(config["release_seconds"])
	for i: int in 2:
		var side: String = "Left" if i == 0 else "Right"
		var fi: int = sk.find_bone(side + "Foot")
		if fi < 0: continue
		var foot: Transform3D = sk.get_bone_global_pose(fi)
		var toe: Vector3 = sk.global_transform * (foot * Vector3(0, -0.06, -0.15))
		var active_interval: int = -1
		var spans: Array = windows.get(side, [])
		for w: int in spans.size():
			if time >= float(spans[w][0]) and time <= float(spans[w][1]):
				active_interval = w
				break
		if active_interval >= 0:
			if intervals[i] != active_interval: pins[i] = toe
			var offset: Vector3 = pins[i] - toe
			offset.y = 0.0
			# A teleport, shove or unreachable turn releases immediately; never stretch the leg.
			if offset.length() > max_correction:
				pins[i] = toe
				offset = Vector3.ZERO
			correction[i] = offset
		else:
			correction[i] = correction[i].move_toward(Vector3.ZERO, max_correction * dt / maxf(release_seconds, 0.001))
		intervals[i] = active_interval
		if correction[i].length_squared() > 0.00000001:
			var target: Vector3 = sk.to_local(sk.to_global(foot.origin) + correction[i])
			solver.solve_foot_target(sk, side, target)
