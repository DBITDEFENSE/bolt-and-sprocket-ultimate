class_name LampSway
extends Node
## Hanging lanterns that swing (Update 02 section 7, T-052): when a shell lands close the inn shudders and every
## lantern (Props.lantern's "swing_lamps" pivots) swings on its chain, its light swinging with it, then settles.
## API for other systems: LampSway.find(tree).impulse(direction, strength) for every lamp, or
## impulse_at(position, radius, direction, strength) for the ones near a point (e.g. a lamp that gets shot).
## Damped pendulums; asleep (no work) while everything hangs still.
## UPDATE 10 (T-154): cfg "group" swings another group's pivots (Totenhafen's chains and pulley blocks,
## "swing_chains"); only the default "swing_lamps" set registers as the map's LampSway.

var cfg: Dictionary = {}
var lamps: Array = []     # each: [pivot Node3D, light Light3D or null, light offset in pivot space, angle Vector2, velocity Vector2]
var _awake: bool = false


static func find(tree: SceneTree) -> LampSway:
	return tree.get_first_node_in_group(&"lamp_sway") as LampSway if tree != null else null


func setup(c: Dictionary, map_root: Node) -> void:
	cfg = c
	var grp: StringName = StringName(str(c.get("group", "swing_lamps")))
	if grp == &"swing_lamps":
		add_to_group(&"lamp_sway")
	var lights: Array[OmniLight3D] = []
	for n: Node in map_root.find_children("*", "OmniLight3D", true, false):
		lights.append(n as OmniLight3D)
	for n2: Node in get_tree().get_nodes_in_group(grp):
		var pivot: Node3D = n2 as Node3D
		if pivot == null or not map_root.is_ancestor_of(pivot):
			continue
		# the lamp's light hangs just under the lantern (gen_map00 _lamp ~0.15 m lower)
		var lantern_at: Vector3 = pivot.global_position
		var body: Node3D = pivot.get_node_or_null("LanternBody") as Node3D
		if body != null:
			lantern_at = body.global_position
		var best: OmniLight3D = null
		var best_d: float = 0.8
		for l: OmniLight3D in lights:
			var d: float = l.global_position.distance_to(lantern_at)
			if d < best_d:
				best_d = d
				best = l
		var off: Vector3 = Vector3.ZERO
		if best != null:
			off = pivot.global_transform.affine_inverse() * best.global_position
		lamps.append([pivot, best, off, Vector2.ZERO, Vector2.ZERO])


## Every lamp gets a push along `dir` (world space, horizontal part used).
func impulse(dir: Vector3, strength: float) -> void:
	for e: Array in lamps:
		_push(e, dir, strength * randf_range(0.7, 1.3))


func impulse_at(pos: Vector3, radius: float, dir: Vector3, strength: float) -> void:
	for e: Array in lamps:
		var p: Node3D = e[0]
		var d: float = p.global_position.distance_to(pos)
		if d < radius:
			_push(e, dir, strength * (1.0 - d / radius))


func _push(e: Array, dir: Vector3, s: float) -> void:
	var h: Vector2 = Vector2(dir.x, dir.z)
	if h.length() < 0.001:
		h = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	h = h.normalized()
	# swinging toward +X is a rotation about -Z, toward +Z one about +X
	e[4] = (e[4] as Vector2) + Vector2(h.y, -h.x) * s * 3.0
	_awake = true


func _process(delta: float) -> void:
	if not _awake:
		return
	var k: float = float(cfg.get("stiffness", 6.5))
	var damp: float = float(cfg.get("damping", 0.55))
	var moving: bool = false
	for e: Array in lamps:
		var pivot: Node3D = e[0]
		if not is_instance_valid(pivot):
			continue
		var a: Vector2 = e[3]
		var v: Vector2 = e[4]
		v += (-k * a - damp * v) * delta
		a += v * delta
		a = a.limit_length(0.5)
		e[3] = a
		e[4] = v
		pivot.rotation = Vector3(a.x, 0.0, a.y)
		var light: Light3D = e[1]
		if light != null and is_instance_valid(light):
			light.global_position = pivot.global_transform * (e[2] as Vector3)
		if a.length() > 0.0015 or v.length() > 0.0015:
			moving = true
	_awake = moving
