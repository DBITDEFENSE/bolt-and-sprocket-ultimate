extends CinemaSet
## T-194, LAZARUS SATURDAY sets A-C (docs/CUTSCENES_LAZARUS.md §6.1): Chetverodnevo on 12 April 1930. The road runs
## along +Z from the church (its door at z 1.5, facing the road) out past the log houses; the bell tower stands
## beside the church at x 8.5. The villagers kneel across the road at z 20-24 facing their church; the brigade's
## AMO-F-15 comes up the road from z 135. Variant "spring" is shot 32: the same road in late spring with nothing
## standing (grass, nettles, four blackened sill-logs).
## Markers: ChurchDoor, Bell, BellGround, Tower, Truck, Serafim, Volkov, Keys. Effects: truck_arrive, brigade_down,
## clear_road, bell_stop, arms, bell_rope, bell_drop, bell_crack, run_out, tower_fall, dust_settle.
## Nobody is struck on screen (§1): the road is cleared by the villagers getting up and being walked aside, never
## grabbed in frame; the two hands that close on Serafim's arms at 11 are cut away from on their first movement.

var truck: Node3D
var tower: Node3D
var stump: Node3D
var bell: Node3D
var bell_crack_n: Node3D
var kneelers: Array[CinemaPerson] = []
var brigade: Array[CinemaPerson] = []
var on_truck: Array[CinemaPerson] = []
var serafim: CinemaPerson
var volkov: CinemaPerson
var head: CinemaPerson
var takers: Array[CinemaPerson] = []
var rope: Node3D
var belfry_men: Array[CinemaPerson] = []
var _wheels: Array[Node3D] = []
var _truck_moving: bool = false
const CRAFT = preload("res://gravelight/world/cinema_sets/cinema_craft.gd")
const PUDDLE = preload("res://gravelight/world/cinema_sets/puddle.gdshader")


func _build() -> void:
	var spring: bool = variant == "spring"
	env({"sky_top": [0.25, 0.29, 0.32] if not spring else [0.55, 0.62, 0.72], "sky_horizon": [0.45, 0.48, 0.49] if not spring else [0.78, 0.78, 0.74],
		"ground": [0.3, 0.28, 0.25], "ambient": [0.55, 0.6, 0.66], "ambient_e": 0.45, "fog": [0.38, 0.42, 0.43], "fog_d": 0.0025 if not spring else 0.003,
		"exposure": 1.0, "glow_t": 1.4})
	sun(Vector3(-38, -150, 0), [0.92, 0.92, 0.9] if not spring else [1.0, 0.95, 0.85], 0.55 if not spring else 0.95)
	_ground(spring)
	var spots: Array = []
	for i: int in 34:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		spots.append(Vector3(side * rng.randf_range(16.0, 30.0), 0, rng.randf_range(-30.0, 150.0)))
	for j: int in 10:
		spots.append(Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-70, -30)))
	birches(self, spots, spring)
	if spring:
		_spring()
		return
	_church()
	_tower()
	for k: int in 7:
		var z: float = 16.0 + 14.0 * float(k)
		izba(self, Vector3(-12.5, 0, z), 90.0 + rng.randf_range(-4, 4))
		izba(self, Vector3(12.5, 0, z + 6.0), -90.0 + rng.randf_range(-4, 4))
		if k % 2 == 0:
			Props.fence(self, Vector3(-8.0, 0, z - 4.0), Vector3(-8.0, 0, z + 5.0), 30 + k)
			Props.fence(self, Vector3(8.0, 0, z + 2.0), Vector3(8.0, 0, z + 11.0), 40 + k)
	Props.smoke(self, Vector3(-12.5 + 1.5, 6.4, 30.0), 0.4, 2.0, 18)
	_well(Vector3(6.5, 0, 46.0))
	_people()
	_truck()


# ---------------------------------------------------------------- the ground, the road

func _ground(spring: bool) -> void:
	var g: Node3D = group(self, "Ground")
	var mud: Material = MaterialLibrary.build("dirt", {"tint": [0.6, 0.52, 0.43], "tile_m": 1.5, "wetness": 0.3}) if not spring \
		else noisy(Color(0.2, 0.28, 0.12), Color(0.36, 0.44, 0.2), 0.12, 5.0, 0.95)
	plane(g, Vector3(0, 0, 40), Vector2(500, 500), mud)
	var road: Material = MaterialLibrary.build("dirt", {"tint": [0.42, 0.34, 0.25], "tile_m": 1.2, "wetness": 0.45})
	if spring:
		road = noisy(Color(0.3, 0.26, 0.2), Color(0.42, 0.37, 0.28), 0.2, 3.0, 0.95)
	plane(g, Vector3(0, 0.01, 72), Vector2(7.5, 136), road)
	if not spring:
		var water: ShaderMaterial = ShaderMaterial.new()
		water.shader = PUDDLE
		for rx: float in [-1.0, 1.0]:
			for r: int in 32:
				plane(g, Vector3(rx + rng.randf_range(-0.08, 0.08), 0.025, 6.0 + float(r) * 4.1), Vector2(rng.randf_range(0.2, 0.5), rng.randf_range(1.2, 4.0)), water)
		var snow: StandardMaterial3D = noisy(Color(0.66, 0.66, 0.64), Color(0.86, 0.86, 0.85), 0.5, 2.0, 0.9)
		var drifts: Array = []
		for i: int in 60:
			var side: float = -1.0 if i % 2 == 0 else 1.0
			drifts.append(xf(Vector3(side * rng.randf_range(4.4, 6.0), 0.0, rng.randf_range(6.0, 140.0)), Vector3(rng.randf_range(1.5, 3.5), 0.35, rng.randf_range(2.0, 6.0))))
		for j: int in 40:
			drifts.append(xf(Vector3(rng.randf_range(-60, 60), 0.0, rng.randf_range(-40, 150)), Vector3(rng.randf_range(2, 6), 0.3, rng.randf_range(2, 6))))
		multi(g, CRAFT.earth(1.0, 1.0, 0.5, 931), drifts, snow, "SnowInDitches")


# ---------------------------------------------------------------- the church and the tower

func _church() -> void:
	var c: Node3D = group(self, "Church", Vector3.ZERO)
	var grey: StandardMaterial3D = noisy(Color(0.34, 0.33, 0.31), Color(0.5, 0.49, 0.46), 0.5, 1.2, 0.95)
	box(c, Vector3(0, 0.5, -6.0), Vector3(8.0, 1.0, 16.0), "stone")                 # the stone undercroft
	box(c, Vector3(0, 3.75, -6.0), Vector3(7.2, 5.5, 15.0), grey)                   # the nave, plank-clad, weathered grey
	var logs: Array = []
	var y: float = 1.2
	while y < 6.4:
		logs.append(xf(Vector3(3.62, y, -6.0), Vector3(0.16, 15.0, 0.16), Vector3(90, 0, 0)))
		logs.append(xf(Vector3(-3.62, y, -6.0), Vector3(0.16, 15.0, 0.16), Vector3(90, 0, 0)))
		y += 0.32
	multi(c, Props.unit_cyl(), logs, grey)
	var half: float = 4.1
	var rise: float = 3.0
	var ang: float = rad_to_deg(atan2(rise, half))
	var sl: float = sqrt(half * half + rise * rise)
	box(c, Vector3(half * 0.5 - 0.05, 6.5 + rise * 0.5, -6.0), Vector3(sl, 0.18, 15.6), "shingle", Vector3(0, 0, -ang))
	box(c, Vector3(-half * 0.5 + 0.05, 6.5 + rise * 0.5, -6.0), Vector3(sl, 0.18, 15.6), "shingle", Vector3(0, 0, ang))
	var gable: PrismMesh = PrismMesh.new()
	gable.size = Vector3(8.2, rise, 0.2)
	for gz: float in [1.5, -13.5]:
		var gm: MeshInstance3D = MeshInstance3D.new()
		gm.mesh = gable
		gm.material_override = grey
		gm.position = Vector3(0, 6.5 + rise * 0.5, gz)
		c.add_child(gm)
	# the small onion dome on the ridge: dull metal, a plain wooden cross
	var dull: StandardMaterial3D = flat(Color(0.36, 0.38, 0.36), 0.55, 0.0, 0.6)
	cyl(c, Vector3(0, 10.0, -4.0), 0.75, 1.4, grey)
	ball(c, Vector3(0, 11.3, -4.0), Vector3(1.8, 2.1, 1.8), dull)
	cone(c, Vector3(0, 12.6, -4.0), 0.35, 0.02, 0.9, dull, 10)
	box(c, Vector3(0, 13.8, -4.0), Vector3(0.09, 1.6, 0.09), "furniture")
	box(c, Vector3(0, 14.15, -4.0), Vector3(0.75, 0.08, 0.08), "furniture")
	# the west porch toward the road: three steps, a floor, posts, a little gable; the double door with iron straps
	box(c, Vector3(0, 0.95, 3.0), Vector3(3.6, 0.12, 3.0), "planks")
	for s: int in 3:
		box(c, Vector3(0, 0.16 + 0.32 * float(s) - 0.1, 5.0 - 0.33 * float(s)), Vector3(2.6, 0.32, 0.4), "planks")
	for px: float in [-1.6, 1.6]:
		for pz: float in [1.8, 4.3]:
			box(c, Vector3(px, 2.6, pz), Vector3(0.18, 3.2, 0.18), grey)
	box(c, Vector3(0.95, 4.35, 3.0), Vector3(2.3, 0.12, 3.4), "shingle", Vector3(0, 0, -28))
	box(c, Vector3(-0.95, 4.35, 3.0), Vector3(2.3, 0.12, 3.4), "shingle", Vector3(0, 0, 28))
	var door: Node3D = group(c, "ChurchDoorLeaves", Vector3(0, 1.0, 1.52))
	for dx: float in [-0.46, 0.46]:
		box(door, Vector3(dx, 1.25, 0), Vector3(0.9, 2.5, 0.1), "planks")
		for sy: float in [0.4, 1.25, 2.1]:
			box(door, Vector3(dx, sy, 0.06), Vector3(0.82, 0.07, 0.02), "iron")
	cyl(door, Vector3(0.12, 1.2, 0.09), 0.07, 0.015, "iron", Vector3(90, 0, 0))
	marker("ChurchDoor", Vector3(0, 2.2, 1.6))


func _tower() -> void:
	tower = group(self, "Tower", Vector3(8.5, 0, -1.0))
	var t: Node3D = group(tower, "TowerBody", Vector3.ZERO)
	var grey: StandardMaterial3D = noisy(Color(0.3, 0.29, 0.27), Color(0.46, 0.45, 0.42), 0.5, 1.2, 0.95)
	box(t, Vector3(0, 4.0, 0), Vector3(3.4, 8.0, 3.4), grey)
	for cx: float in [-1.6, 1.6]:
		for cz: float in [-1.6, 1.6]:
			box(t, Vector3(cx, 9.3, cz), Vector3(0.22, 2.6, 0.22), grey)
	box(t, Vector3(0, 8.05, 0), Vector3(3.6, 0.15, 3.6), "planks")
	for r: int in 4:   # the belfry rail
		var a: float = float(r) * 90.0
		box(t, Vector3(cos(deg_to_rad(a)) * 1.6, 8.9, sin(deg_to_rad(a)) * 1.6), Vector3(0.08, 0.08, 3.3), grey, Vector3(0, a + 90.0, 0))
	box(t, Vector3(0, 10.6, 0), Vector3(3.8, 0.2, 3.8), grey)
	cone(t, Vector3(0, 13.0, 0), 2.75, 0.06, 4.6, "shingle", 8)
	box(t, Vector3(0, 15.6, 0), Vector3(0.07, 1.0, 0.07), "furniture")
	box(t, Vector3(0, 15.85, 0), Vector3(0.5, 0.06, 0.06), "furniture")
	box(t, Vector3(0, 10.2, 0), Vector3(2.8, 0.2, 0.25), "beam")   # the yoke beam
	bell = group(self, "Bell", Vector3(8.5, 9.55, -1.0))
	var bronze: StandardMaterial3D = flat(Color(0.34, 0.26, 0.16), 0.42, 0.0, 0.75)
	cone(bell, Vector3(0, -0.05, 0), 0.36, 0.2, 0.62, bronze, 18)
	ball(bell, Vector3(0, 0.26, 0), Vector3(0.42, 0.24, 0.42), bronze)
	cone(bell, Vector3(0, -0.4, 0), 0.4, 0.36, 0.1, bronze, 18)
	box(bell, Vector3(0, 0.46, 0), Vector3(0.5, 0.12, 0.14), "iron")
	bell_crack_n = box(bell, Vector3(0.0, -0.08, 0.31), Vector3(0.025, 0.5, 0.03), flat(Color(0.03, 0.02, 0.01), 1.0), Vector3(0, 0, 12), "Crack")
	bell_crack_n.visible = false
	marker("BellGround", Vector3(8.0, 0.3, 4.8))
	# T-206: the rope runs from the bell down to the first hauler's hands (8.2, 1.2, 8.1), then along the line of men
	rope = group(self, "Rope", Vector3.ZERO)
	cyl(rope, Vector3(8.35, 5.35, 3.65), 0.02, 12.2, "rope", Vector3(-47, 0, 0))
	cyl(rope, Vector3(8.17, 1.2, 9.25), 0.02, 2.4, "rope", Vector3(-90, 0, 0))
	rope.visible = false
	stump = group(self, "TowerStump", Vector3(8.5, 0, -1.0))
	box(stump, Vector3(0, 0.8, 0), Vector3(3.4, 1.6, 3.4), "char")
	for k: int in 6:
		box(stump, Vector3(rng.randf_range(-1.4, 1.4), 1.6 + rng.randf_range(0, 0.6), rng.randf_range(-1.4, 1.4)), Vector3(0.18, rng.randf_range(0.6, 1.4), 0.18), "char",
			Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
	stump.visible = false
	for k2: int in 2:   # the two men working the yoke on the rail
		var bm: CinemaPerson = person(self, "belfry_%d" % k2, look_of("brigade_%s" % ["a", "b"][k2]), Vector3(8.5 + (-0.9 if k2 == 0 else 0.9), 8.12, -1.0 + 0.6), 0.0, "hold")
		bm.hold_lift = 0.9
		bm.visible = false
		belfry_men.append(bm)


func _well(p: Vector3) -> void:
	var w: Node3D = group(self, "Well", p)
	box(w, Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 1.2), _log_mat())
	box(w, Vector3(0, 2.0, 1.6), Vector3(0.2, 4.0, 0.2), "beam")
	box(w, Vector3(0, 3.4, 0.4), Vector3(0.1, 0.1, 6.5), "beam", Vector3(-28, 0, 0))


# ---------------------------------------------------------------- the people

func _people() -> void:
	var looks: Array = ["villager_a", "villager_b", "villager_c", "villager_d", "villager_e", "villager_f"]
	var i: int = 0
	for row: int in 3:
		var n: int = [8, 7, 5][row]
		for k: int in n:
			var x: float = -3.2 + 6.4 * (float(k) + (0.5 if row == 1 else 0.0)) / float(n - 1) + rng.randf_range(-0.2, 0.2)
			var z: float = 20.0 + float(row) * 1.6 + rng.randf_range(-0.3, 0.3)
			var lk: Dictionary = look_of(looks[(i + row) % looks.size()])
			if i % 7 == 3:
				lk["height"] = 0.62   # a child held by the shoulders
			var p: CinemaPerson = person(self, "villager_%d" % i, lk, Vector3(x, 0, z), rng.randf_range(-8, 8), "kneel" if lk.get("height", 1.0) > 0.7 else "stand")
			kneelers.append(p)
			i += 1
	serafim = person(self, "serafim", look_of("serafim"), Vector3(0, 1.0, 2.4), 180.0, "hold")
	serafim.name = "Serafim"
	var keys: Node3D = _keys()
	serafim.in_hand(keys, true, Vector3(0, -0.07, -0.03))
	volkov = person(self, "volkov_1930", look_of("volkov_1930"), Vector3(0.9, 0, 33.0), 0.0, "stand")
	volkov.name = "Volkov"
	volkov.visible = false
	head = person(self, "brigade_head", look_of("brigade_head"), Vector3(-1.2, 0, 32.0), 0.0, "stand")
	head.visible = false
	var bl: Array = ["brigade_a", "brigade_b", "brigade_c", "brigade_d"]
	for b: int in 8:
		var bp: CinemaPerson = person(self, "brigade_%d" % b, look_of(bl[b % 4]), Vector3(-2.6 + 0.8 * float(b), 0, 30.0 + float(b % 3) * 0.8), 180.0, "stand")
		bp.visible = false
		brigade.append(bp)
	for t: int in 2:
		var tp: CinemaPerson = person(self, "taker_%d" % t, look_of(bl[t]), Vector3(-1.6 if t == 0 else 1.6, 1.0, 3.6), 0.0 if t == 0 else 0.0, "stand")
		tp.visible = false
		takers.append(tp)


func _keys() -> Node3D:
	var k: Node3D = Node3D.new()
	k.name = "Keys"
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.035
	ring.outer_radius = 0.045
	var rm: MeshInstance3D = MeshInstance3D.new()
	rm.mesh = ring
	rm.material_override = flat(Color(0.2, 0.19, 0.18), 0.5, 0.0, 0.8)
	rm.rotation_degrees = Vector3(90, 0, 0)
	k.add_child(rm)
	for j: int in 4:
		box(k, Vector3(-0.04 + 0.027 * float(j), -0.08, 0.0), Vector3(0.012, 0.11, 0.006), flat(Color(0.18, 0.17, 0.16), 0.5, 0.0, 0.8), Vector3(0, 0, -12 + 8 * j))
	return k


# ---------------------------------------------------------------- the truck (an AMO-F-15, 1.5 t, canvas back)

func _truck() -> void:
	truck = group(self, "Truck", Vector3(0, 0, 135.0), 0.0)
	var body: Node3D = group(truck, "TruckBody")
	var olive: StandardMaterial3D = noisy(Color(0.2, 0.22, 0.17), Color(0.3, 0.31, 0.24), 1.0, 0.8, 0.8)
	box(body, Vector3(0, 0.75, -0.2), Vector3(0.9, 0.18, 5.6), "iron")          # the frame
	box(body, Vector3(0, 1.15, -2.35), Vector3(0.95, 0.75, 1.3), olive)         # the bonnet
	box(body, Vector3(0, 1.2, -3.02), Vector3(0.85, 0.85, 0.06), "iron")         # the radiator
	box(body, Vector3(0, 1.75, -1.15), Vector3(1.6, 1.3, 1.1), olive)            # the cab
	box(body, Vector3(0, 2.0, -1.72), Vector3(1.3, 0.5, 0.04), "glass")         # the windscreen
	box(body, Vector3(0, 2.45, -1.15), Vector3(1.75, 0.08, 1.3), olive)
	box(body, Vector3(0, 1.15, 1.25), Vector3(2.0, 0.12, 3.1), "planks")         # the bed
	for sx: float in [-1.0, 1.0]:
		box(body, Vector3(sx, 1.45, 1.25), Vector3(0.06, 0.5, 3.1), "planks")
		box(body, Vector3(sx * 1.05, 1.0, -2.3), Vector3(0.3, 0.06, 1.0), olive, Vector3(0, 0, sx * -25))   # mudguards
	box(body, Vector3(0, 2.3, 1.25), Vector3(2.05, 0.06, 3.1), "tarp")        # the canvas over its bows, rolled back
	for bz: float in [0.0, 1.25, 2.5]:
		box(body, Vector3(0, 1.9, bz), Vector3(2.05, 0.8, 0.05), "tarp")
	for wz: float in [-2.3, 1.7]:
		for wx: float in [-0.95, 0.95]:
			var wh: Node3D = group(truck, "Wheel", Vector3(wx, 0.48, wz))
			cyl(wh, Vector3.ZERO, 0.48, 0.18, "rubber", Vector3(0, 0, 90))
			cyl(wh, Vector3(0.0, 0, 0), 0.22, 0.2, "iron", Vector3(0, 0, 90))
			_wheels.append(wh)
	for sx2: float in [-0.75, 0.75]:   # two plain red cloths on poles tied to the cab: cloth, nothing on them
		box(body, Vector3(sx2, 2.9, -1.0), Vector3(0.04, 1.8, 0.04), "furniture")
		var red: StandardMaterial3D = flat(Color(0.5, 0.05, 0.04), 0.95)
		red.cull_mode = BaseMaterial3D.CULL_DISABLED
		card(body, Vector3(sx2 + sx2 * 0.45, 3.45, -1.0), Vector2(0.9, 0.6), red, 90.0 + sx2 * 6.0)
	for k: int in 4:
		var p: CinemaPerson = person(truck, "on_truck_%d" % k, look_of(["brigade_a", "brigade_b", "brigade_c", "brigade_d"][k]), Vector3(-0.55 + 0.37 * float(k), 1.21, 1.0 + 0.3 * float(k % 2)), 0.0, "stand")
		on_truck.append(p)
	box(body, Vector3(0.4, 1.4, 2.2), Vector3(0.45, 0.3, 0.3), "furniture")   # the wooden box, handed down with care


func _process(delta: float) -> void:
	super._process(delta)
	if _truck_moving:
		for w: Node3D in _wheels:
			w.rotation.x -= delta * 2.6


# ---------------------------------------------------------------- the effects

## Shot 4-5: the truck comes up the road slowly, slithering, and stops short of the kneeling line.
func fx_truck_arrive(secs: float) -> void:
	truck.position = Vector3(0, 0, 135.0)
	_truck_moving = true
	var tw: Tween = tween_to(truck, "position:z", 40.0, secs * 1.6, Tween.TRANS_SINE, Tween.EASE_OUT)
	var wob: Tween = create_tween().set_loops(int(secs * 1.5))
	wob.tween_property(truck, "rotation:y", deg_to_rad(1.6), 0.45)
	wob.tween_property(truck, "rotation:y", deg_to_rad(-1.4), 0.5)
	if tw != null:
		tw.finished.connect(func() -> void:
			_truck_moving = false
			truck.rotation.y = 0.0)


## Shot 5: the truck stands; the brigade is down in the road, Volkov from the cab.
## T-206: they come down the truck's far side and walk round its nose at a brisk 1.5 m/s (a waypoint clear of the
## bonnet and the wheels, which the old straight paths walked through), Volkov from the cab's near door at a walk,
## looking at the kneeling road and then, quickly, away from it.
const BRIGADE_SPOTS: Array = [[-3.2, 34.0], [-2.3, 33.4], [-1.5, 34.6], [-0.6, 33.2], [0.3, 34.4], [1.1, 33.6], [1.9, 34.8], [-1.0, 35.6]]


func fx_brigade_down(_secs: float) -> void:
	truck.position = Vector3(0, 0, 40.0)
	truck.rotation.y = 0.0
	_truck_moving = false
	for k: int in on_truck.size():
		var op: CinemaPerson = on_truck[k]
		later(0.25 * float(k), func() -> void: op.visible = false)
	for b: int in brigade.size():
		var bp: CinemaPerson = brigade[b]
		var spot: Array = BRIGADE_SPOTS[b]
		bp.visible = true
		bp.position = Vector3(-1.75 - 0.3 * float(b % 2), 0, 39.6 + 0.4 * float(b % 5))   # down on the truck's far side
		bp.rotation.y = 0.0
		bp.set_pose(&"stand")
		bp.look_ahead()
		bp.reset_motion()
		var wp: Vector3 = Vector3(-2.0 - 0.15 * float(b % 3), 0, 36.3 - 0.2 * float(b % 2))
		var leg1: Tween = bp.walk_to(wp, 1.5, 0.35 * float(b % 4))
		if leg1 != null:
			leg1.finished.connect(func() -> void: bp.walk_to(Vector3(float(spot[0]), 0, float(spot[1])), 1.4))
	volkov.visible = true
	volkov.position = Vector3(1.55, 0, 38.6)
	volkov.rotation.y = 0.0
	volkov.set_pose(&"stand")
	volkov.reset_motion()
	volkov.walk_to(Vector3(1.45, 0, 34.8), 0.95, 1.2)
	later(1.5, func() -> void: volkov.look_toward(Vector3(0.0, 0.9, 22.0)))   # the kneeling road
	later(3.4, func() -> void: volkov.look_toward(Vector3(-1.5, 1.5, 34.0)))   # and quickly away from it, to the men
	head.visible = true
	head.position = Vector3(-1.5, 0, 38.6)
	head.rotation.y = 0.0
	head.reset_motion()
	head.walk_to(Vector3(-1.3, 0, 35.2), 1.1, 0.3)


## Shot 6: out of focus behind Serafim, the people in the road get up and are walked to its edge (no one is struck).
## T-206: each stands (the rise blends), turns to the roadside and walks there at about a metre a second instead of
## sliding sideways across the ruts.
func fx_clear_road(_secs: float) -> void:
	for k: int in kneelers.size():
		var p: CinemaPerson = kneelers[k]
		var side: float = -1.0 if p.position.x < 0.0 else 1.0
		var goal: Vector3 = Vector3(side * (5.4 + 0.6 * float(k % 3)), 0, p.position.z + 0.3 * float(k % 3) - 0.3)
		later(0.4 + 0.25 * float(k % 6), func() -> void:
			p.set_pose(&"stand")
			p.walk_to(goal, 0.9 + 0.1 * float(k % 3), 0.5))
	for b: int in brigade.size():
		var bp: CinemaPerson = brigade[b]
		bp.walk_to(Vector3(bp.position.x, 0, 29.5 + float(b % 3)), 1.0, 0.2 * float(b % 3))


## Shot 7-10: the road is empty; Volkov and the brigade head at the porch steps.
func fx_at_the_door(_secs: float) -> void:
	for k: int in kneelers.size():
		var p: CinemaPerson = kneelers[k]
		p.set_pose(&"stand")
		p.position = Vector3((-1.0 if k % 2 == 0 else 1.0) * (5.6 + 0.5 * float(k % 4)), 0, 18.0 + float(k % 5) * 1.2)
		p.rotation.y = PI * 0.5 * (1.0 if k % 2 == 0 else -1.0)
		p.look_ahead()
		p.reset_motion()
	volkov.position = Vector3(0.45, 0, 5.9)
	volkov.rotation.y = 0.0
	volkov.set_pose(&"writing")
	volkov.head_yaw = 0.0
	volkov.head_down = 0.32   # reading his paper
	volkov.reset_motion()
	head.position = Vector3(-1.1, 0, 6.6)
	head.rotation.y = CinemaPerson.yaw_to(Vector3(0, 0, 1.6) - head.position)   # facing the door
	head.look_ahead()
	head.reset_motion()
	for b: int in brigade.size():
		brigade[b].position = Vector3(-3.0 + 0.9 * float(b), 0, 9.5 + float(b % 2))
		brigade[b].rotation.y = 0.0
		brigade[b].set_pose(&"stand")
		brigade[b].look_ahead()
		brigade[b].reset_motion()
	serafim.look_ahead()   # to the road, over the lens


## Shot 7: Serafim raises his free hand, palm down, toward the road: get up, go home.
func fx_serafim_palm(_secs: float) -> void:
	serafim.set_pose(&"palm")


## Shot 8-11: the keys again, held, not a fist. T-206: Serafim looks down at the young man on the step; Volkov reads
## his paper, then looks up at him for the formal part.
func fx_serafim_hold(_secs: float) -> void:
	serafim.set_pose(&"hold")
	serafim.look_toward(Vector3(0.45, 1.6, 5.9))
	later(0.9, func() -> void: volkov.look_toward(Vector3(0.0, 2.55, 2.4)))


## Shot 9 (the reverse): the brigade head's line at 4.6 s; Volkov glances at him and back.
func fx_reverse(_secs: float) -> void:
	serafim.look_toward(Vector3(0.45, 1.6, 5.9))
	head.look_toward(Vector3(0.0, 2.55, 2.4))
	later(4.4, func() -> void: volkov.look_toward(Vector3(-1.1, 1.6, 6.6)))
	later(7.0, func() -> void: volkov.look_toward(Vector3(0.0, 2.55, 2.4)))


## Shot 10: Volkov turns to the brigade head and keeps his voice down.
func fx_volkov_turns(secs: float) -> void:
	volkov.set_pose(&"stand")
	volkov.look_ahead()
	volkov.turn_to(CinemaPerson.yaw_to(head.position - volkov.position), minf(1.0, secs * 0.15))
	head.look_toward(Vector3(0.45, 1.6, 5.9))
	serafim.look_toward(Vector3(0.45, 1.6, 5.9))


## Shot 11: two of them step in from either side. The cut comes on the first movement.
func fx_arms(secs: float) -> void:
	for t: int in takers.size():
		var tp: CinemaPerson = takers[t]
		tp.visible = true
		tp.position = Vector3(-1.5 if t == 0 else 1.5, 1.0, 3.3)
		tp.rotation.y = deg_to_rad(-50.0 if t == 0 else 50.0)
		tp.reset_motion()
		tp.walk_to(Vector3(-0.55 if t == 0 else 0.55, 1.0, 2.75), 0.8, secs * 0.55, false)


## Shot 12: daylight again; the rope up to the bell, two men at the yoke, Serafim on his knees in the road between two
## of the brigade, praying (his sleeve torn at the cuff, nobody holding him now). T-206: the camera starts on Serafim
## and tilts up the rope; three of the brigade haul it, facing the tower, their hands on it.
func fx_bell_rope(_secs: float) -> void:
	for tp: CinemaPerson in takers:
		tp.visible = false
	rope.visible = true
	for bm: CinemaPerson in belfry_men:
		bm.visible = true
	serafim.position = Vector3(3.3, 0, 7.2)
	serafim.rotation.y = deg_to_rad(-20.0)
	serafim.set_pose(&"pray")
	serafim.look_ahead()
	serafim.reset_motion()
	for b: int in 2:   # the two who keep him there, either side, facing him
		brigade[b].position = Vector3(2.3 if b == 0 else 4.3, 0, 7.6)
		brigade[b].rotation.y = deg_to_rad(-90.0 if b == 0 else 90.0)
		brigade[b].set_pose(&"stand")
		brigade[b].look_toward(Vector3(3.3, 1.1, 7.2))
		brigade[b].reset_motion()
	for b2: int in range(2, 5):   # the haulers on the rope, facing the tower
		brigade[b2].position = Vector3(8.2, 0, 8.4 + float(b2 - 2))
		brigade[b2].rotation.y = 0.0
		brigade[b2].set_pose(&"hold")
		brigade[b2].hold_lift = 0.5
		brigade[b2].hold_width = 0.06
		brigade[b2].look_toward(Vector3(8.5, 9.5, -1.0))
		brigade[b2].reset_motion()
	for b3: int in range(5, brigade.size()):   # the rest watching from the road (clear of where the bell comes down)
		brigade[b3].position = Vector3(1.0 + 1.1 * float(b3 % 3), 0, 11.0 + 0.9 * float(b3))
		brigade[b3].rotation.y = 0.0
		brigade[b3].set_pose(&"stand")
		brigade[b3].look_toward(Vector3(8.5, 9.5, -1.0))
		brigade[b3].reset_motion()
	volkov.position = Vector3(-1.5, 0, 12.0)
	volkov.set_pose(&"writing")
	volkov.rotation.y = deg_to_rad(-30.0)
	volkov.head_down = 0.3
	volkov.reset_motion()


## Shot 13: the bell swings out over the rail on the rope and drops. T-206: the rope goes with the bell (the haulers
## let it run and step back), not left hanging in the air.
func fx_bell_drop(secs: float) -> void:
	bell.position = Vector3(8.5, 9.55, -1.0)
	bell.rotation = Vector3.ZERO
	var tw: Tween = create_tween()
	tw.tween_property(bell, "position", Vector3(8.4, 9.75, 1.0), secs * 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(bell, "rotation:x", deg_to_rad(22.0), secs * 0.35)
	tw.tween_interval(secs * 0.12)
	tw.tween_callback(func() -> void:
		rope.visible = false
		for b2: int in range(2, 5):
			brigade[b2].set_pose(&"stand")
			brigade[b2].walk_to(brigade[b2].position + Vector3(0.3, 0, 1.6), 1.6, 0.0, false))
	tw.tween_property(bell, "position", Vector3(8.0, 0.32, 4.8), secs * 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(bell, "rotation", Vector3(deg_to_rad(8.0), 0.3, deg_to_rad(-14.0)), secs * 0.24)
	tw.tween_callback(func() -> void:
		dust(self, Vector3(8.0, 0.2, 4.8), Color(0.3, 0.25, 0.18, 0.8), 1.2, 1.2, 1.6, 18, 0.6).emitting = true)


## Shot 14: on the ground it cracks: one dead note and a seam up its waist; mud on the bronze.
func fx_bell_crack(_secs: float) -> void:
	bell.position = Vector3(8.0, 0.32, 4.8)
	bell.rotation = Vector3(deg_to_rad(8.0), 0.3, deg_to_rad(-14.0))
	rope.visible = false
	later(0.3, func() -> void:
		bell_crack_n.visible = true
		dust(self, Vector3(8.0, 0.25, 4.8), Color(0.25, 0.2, 0.14, 0.9), 0.6, 1.8, 1.2, 14, 0.3).emitting = true)


## Shot 15: the box has gone in; the men come running out of the porch and the road is cleared back. T-206: they run
## (the run pose, 3 m/s), Volkov walks back fast with his board, nobody is left standing under the tower.
func fx_run_out(_secs: float) -> void:
	bell_crack_n.visible = true
	bell.position = Vector3(8.0, 0.32, 4.8)
	rope.visible = false
	for bm: CinemaPerson in belfry_men:
		bm.visible = false
	for b: int in brigade.size():
		var bp: CinemaPerson = brigade[b]
		bp.position = Vector3(-1.0 + 0.5 * float(b % 4), 0, 4.0 + 0.4 * float(b))
		bp.rotation.y = PI
		bp.set_pose(&"run")
		bp.look_ahead()
		bp.reset_motion()
		var tw: Tween = bp.walk_to(Vector3(bp.position.x + 0.3 * float(b % 3) - 0.3, 0, 24.0 + float(b)), 3.0, 0.12 * float(b), false)
		if tw != null:
			tw.finished.connect(func() -> void:
				bp.set_pose(&"stand")
				bp.turn_to(0.0, 0.5))
	volkov.position = Vector3(-1.5, 0, 12.0)
	volkov.rotation.y = PI
	volkov.set_pose(&"writing")
	volkov.head_down = 0.0
	volkov.reset_motion()
	var vt: Tween = volkov.walk_to(Vector3(-1.8, 0, 27.0), 2.2, 0.4, false)
	if vt != null:
		vt.finished.connect(func() -> void: volkov.turn_to(0.0, 0.5))
	serafim.position = Vector3(3.2, 0, 14.0)
	serafim.rotation.y = 0.0
	serafim.set_pose(&"kneel")
	serafim.look_toward(Vector3(8.5, 8.0, -1.0))
	serafim.reset_motion()


## Shot 16: the charge takes the base: the tower leans, folds at the belfry and goes down toward the road, and the dust
## rolls up the road toward the camera.
func fx_tower_fall(secs: float) -> void:
	tower.rotation = Vector3.ZERO
	tower.visible = true
	stump.visible = false
	later(secs * 0.12, func() -> void:
		var flash: OmniLight3D = omni(self, Vector3(8.5, 1.0, 0.0), [1.0, 0.75, 0.5], 9.0, 18.0)
		tween_to(flash, "light_energy", 0.0, 0.5, Tween.TRANS_EXPO, Tween.EASE_OUT)
		dust(self, Vector3(8.5, 1.0, -1.0), Color(0.48, 0.46, 0.42, 0.95), 4.0, 3.5, 5.0, 40, 2.2).emitting = true)
	var tw: Tween = create_tween()
	tw.tween_interval(secs * 0.18)
	tw.tween_property(tower, "rotation:x", deg_to_rad(15.0), secs * 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tower, "rotation:x", deg_to_rad(84.0), secs * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		tower.visible = false
		stump.visible = true
		for k: int in 5:
			dust(self, Vector3(8.0 + rng.randf_range(-2, 2), 1.0, 3.0 + 3.0 * float(k)), Color(0.55, 0.53, 0.5, 0.95), 7.0, 2.4, 7.0, 30, 3.0).emitting = true
		_roll_plume(secs * 0.4))


func _roll_plume(secs: float) -> void:
	var plume: GPUParticles3D = dust(self, Vector3(6.0, 1.5, 12.0), Color(0.6, 0.58, 0.55, 0.9), 12.0, 1.0, 9.0, 40, 6.0)
	plume.emitting = true
	tween_to(plume, "position:z", 70.0, maxf(1.0, secs * 2.5), Tween.TRANS_LINEAR)


## Shot 17: through the thinning dust: the stump, Serafim on his knees in the road coughing, Volkov writing on his
## board. T-206: Volkov stands in the road a few metres from him (the old spot by the truck was 80 degrees out of
## frame), writing, looks up at Serafim on his line and, after a moment, back down at the board.
func fx_dust_settle(_secs: float) -> void:
	tower.visible = false
	stump.visible = true
	dust(self, Vector3(6.0, 1.5, 16.0), Color(0.62, 0.6, 0.57, 0.55), 10.0, 0.5, 9.0, 24, 9.0).emitting = true
	serafim.position = Vector3(1.6, 0, 18.0)
	serafim.rotation.y = deg_to_rad(140.0)
	serafim.set_pose(&"kneel")
	serafim.head_down = 0.35
	serafim.head_yaw = 0.0
	serafim.reset_motion()
	later(2.4, func() -> void: serafim.look_toward(Vector3(3.6, 1.6, 24.5)))   # his line is to Volkov
	volkov.position = Vector3(3.6, 0, 24.5)
	volkov.rotation.y = CinemaPerson.yaw_to(serafim.position - Vector3(3.6, 0, 24.5))
	volkov.set_pose(&"writing")
	volkov.head_yaw = 0.0
	volkov.head_down = 0.35
	volkov.reset_motion()
	later(3.0, func() -> void: volkov.look_toward(Vector3(1.6, 1.1, 18.0)))
	later(6.4, func() -> void:
		volkov.head_yaw = 0.0
		volkov.head_down = 0.35)
	head.position = Vector3(5.4, 0, 26.5)
	head.rotation.y = deg_to_rad(200.0)
	head.set_pose(&"stand")
	head.look_ahead()
	head.reset_motion()
	for b: int in brigade.size():
		brigade[b].position = Vector3(-4.0 + 1.0 * float(b), 0, 28.0 + float(b % 3))
		brigade[b].rotation.y = 0.0
		brigade[b].set_pose(&"stand")
		brigade[b].reset_motion()


# ---------------------------------------------------------------- spring (shot 32): nothing stands

func _spring() -> void:
	var nettles: Array = []
	for i: int in 260:
		nettles.append(xf(Vector3(rng.randf_range(-40, 40), 0.25, rng.randf_range(-30, 120)), Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.4, 0.9), rng.randf_range(0.5, 1.4))))
	multi(self, Props.unit_sphere(), nettles, noisy(Color(0.16, 0.24, 0.1), Color(0.3, 0.4, 0.16), 2.0, 0.6, 0.9), "Nettles")
	for k: int in 4:   # four blackened sill-logs where the church stood
		cyl(self, Vector3(-3.0 + 2.0 * float(k), 0.18, -4.0 + rng.randf_range(-3, 3)), 0.2, rng.randf_range(4.0, 7.0), "char", Vector3(90, rng.randf_range(-30, 30), 0))
