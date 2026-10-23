extends GutTest
## Update 04 sections 1-2 (DECISIONS T-065): the map's orientation, end to end. The project frame is +X east, +Z
## south (north = -Z), Godot yaw 0 faces north and -PI/2 faces east. Pins: the baked image is neither mirrored nor
## turned (real pixels of Map 0's cellar floor), MapData's uv, MapCanvas north-up and turn-with-you (turning right
## brings what was on the right to the top, never mirrored), the bezel letters agree with the map, and MapState's
## yaws (first-person camera; B&S chase camera and Bolt's atan2(x, z) motor yaw).

class FakeRoot extends Node3D:
	var player: Node3D = null

var md: MapData


func before_each() -> void:
	MapData.clear_cache()
	md = MapData.for_map(&"map00_crossroads")


func _alpha_at(img: Image, x: float, z: float) -> float:
	var p: Vector2 = md.world_to_pixel(Vector3(x, 0, z))
	return img.get_pixel(int(p.x), int(p.y)).a


func test_uv_east_is_right_south_is_down() -> void:
	var a: Vector2 = md.world_to_uv(Vector3(10, 0, 10))
	assert_gt(md.world_to_uv(Vector3(20, 0, 10)).x, a.x, "east (+X) is to the right in the image")
	assert_lt(md.world_to_uv(Vector3(10, 0, 0)).y, a.y, "north (-Z) is up in the image")


func test_baked_image_is_not_mirrored_or_turned() -> void:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(md.floor_image_path(0)))   # the cellar floor
	assert_gt(_alpha_at(img, 30, 25), 0.5, "the Helvetia cellar (x 24-36, z 19-31) is drawn where it is")
	assert_gt(_alpha_at(img, 14, 4), 0.5, "the Old Cellar under the taproom (x 0-24, z 0-16) is drawn where it is")
	var c: Vector2 = md.world_rect.get_center()
	assert_lt(_alpha_at(img, 2.0 * c.x - 30.0, 25), 0.5, "nothing at the cellar's east-west mirror")
	assert_lt(_alpha_at(img, 14, 2.0 * c.y - 4.0), 0.5, "nothing at the old cellar's north-south mirror")
	var ground: Image = Image.load_from_file(ProjectSettings.globalize_path(md.floor_image_path(1)))
	assert_gt(_alpha_at(ground, 20, 28), 0.5, "the stable (z 22-34) is south of the taproom on the ground floor")


func test_canvas_north_up() -> void:
	var c: MapCanvas = _canvas()
	c.heading = 0.0
	var mid: Vector2 = c.world_to_canvas(Vector3(10, 0, 10))
	assert_almost_eq(c.world_to_canvas(Vector3(20, 0, 10)) - mid, Vector2(40, 0), Vector2(0.01, 0.01), "east is right")
	assert_almost_eq(c.world_to_canvas(Vector3(10, 0, 0)) - mid, Vector2(0, -40), Vector2(0.01, 0.01), "north is up")
	assert_almost_eq(Minimap.cardinal_dir(0, 0.0), Vector2(0, -1), Vector2(0.001, 0.001), "N on top of the bezel")
	assert_almost_eq(Minimap.cardinal_dir(1, 0.0), Vector2(1, 0), Vector2(0.001, 0.001), "E on the right")


func test_canvas_turns_with_the_player_without_mirroring() -> void:
	var c: MapCanvas = _canvas()
	var east_yaw: float = MapState.yaw_of(Vector3(1, 0, 0))
	assert_almost_eq(east_yaw, -PI * 0.5, 0.0001, "Godot yaw facing east")
	c.heading = east_yaw
	var mid: Vector2 = c.world_to_canvas(Vector3(10, 0, 10))
	assert_almost_eq(c.world_to_canvas(Vector3(20, 0, 10)) - mid, Vector2(0, -40), Vector2(0.01, 0.01), "facing east: east is ahead (up)")
	assert_almost_eq(c.world_to_canvas(Vector3(10, 0, 20)) - mid, Vector2(40, 0), Vector2(0.01, 0.01), "facing east: south is on the right")
	assert_almost_eq(c.world_to_canvas(Vector3(10, 0, 0)) - mid, Vector2(-40, 0), Vector2(0.01, 0.01), "facing east: north is on the left")
	for k: int in 4:
		var world: Vector3 = Vector3([0, 1, 0, -1][k], 0, [-1, 0, 1, 0][k])
		var on_map: Vector2 = (c.world_to_canvas(Vector3(10, 0, 10) + world * 4.0) - mid).normalized()
		assert_almost_eq(Minimap.cardinal_dir(k, c.heading), on_map, Vector2(0.001, 0.001), "bezel letter %d sits where the map draws it" % k)
	# turning right (north -> east): what was on the right comes to the top
	c.heading = 0.0
	var right_before: Vector2 = c.world_to_canvas(Vector3(20, 0, 10)) - mid
	assert_gt(right_before.x, 0.0)
	c.heading = east_yaw
	assert_lt((c.world_to_canvas(Vector3(20, 0, 10)) - mid).y, 0.0, "after turning right it is up")


func test_view_yaw_and_facing() -> void:
	var root: FakeRoot = FakeRoot.new()
	add_child_autofree(root)
	var body: Node3D = Node3D.new()
	root.add_child(body)
	root.player = body
	var ms: MapState = MapState.new()
	ms.setup(md, root, "gravelight")
	root.add_child(ms)
	assert_almost_eq(ms.view_yaw(), 0.0, 0.0001, "no camera, body facing -Z: yaw 0, N at the top")
	body.rotation.y = -PI * 0.5
	assert_almost_eq(ms.view_yaw(), -PI * 0.5, 0.0001, "body turned to face east")
	assert_almost_eq(Vector2(-sin(ms.facing_yaw()), -cos(ms.facing_yaw())), Vector2(1, 0), Vector2(0.0001, 0.0001), "the arrow faces east")
	var g0: float = MapState.bs_yaw_to_godot(0.0)
	assert_almost_eq(Vector2(-sin(g0), -cos(g0)), Vector2(0, 1), Vector2(0.0001, 0.0001), "B&S motor yaw 0 faces +Z (south)")
	var m: float = 0.7
	var g: float = MapState.bs_yaw_to_godot(m)
	assert_almost_eq(Vector2(-sin(g), -cos(g)), Vector2(sin(m), cos(m)), Vector2(0.0001, 0.0001), "B&S facing converts without a mirror")


func _canvas() -> MapCanvas:
	var c: MapCanvas = MapCanvas.new()
	add_child_autofree(c)
	c.size = Vector2(200, 200)
	c.center = Vector2(10, 10)
	c.zoom = 4.0
	return c
