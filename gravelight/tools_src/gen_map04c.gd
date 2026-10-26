extends "res://gravelight/tools_src/gen_map04_lib.gd"
## Generates Map 4 Act III "Groom Lake, Nevada" (UPDATE 07, docs/MAP4_FERNFLUG.md §5): a dry lake bed at dawn.
## Seven zones on the ladder 750 → 1000 → 1000 → 1250 → 1500 (power) → 2000: the burning Kranich wreck (spawn),
## the open salt flat (the Burrowers' ground, the impeller core rolled out on it), the wooden hangar (the British
## crate, the relay object, Dee's cage, Hale's glass office, the hangar cradle of Peg's choice), the motor pool
## (the generator = the power, the fuel dump trap), the radar tower (the Jumpjockeys' launch points, Fasbender's
## radio), the underground lab (the specimen rooms, the Nevada stone, the Lodestone's workbench; the Test Pilot's
## arena) and the test silo (the LANTERN rocket, the Crucible, the silo console, the gantry lift = the exfil).
## Source of truth. Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map04c.gd
##
## Frame: +Z north (the buildings), +X east, y up; the salt at y = 0, the lab and the silo at LAB_Y = -6.
## Zone plan (x, z): A_WRECK -14..14 × -36..-4 · B_LAKEBED -60..60 × -4..60 · C_HANGAR 20..70 × 60..100
## · D_MOTORPOOL -70..-20 × 60..100 (+ the service lane -20..20 × 86..100) · E_RADAR 20..70 × 100..140
## · F_LAB -70..-20 × 100..150 at -6 (+ the hatch ramp from D, the cable trench from E)
## · G_SILO -70..-20 × 150..196 at -6 (the control room west, the shaft east; the rocket at (-33, 176)).

const LAB_Y: float = -6.0
const CEIL_WRECK: float = 4.2
const CEIL_HANGAR: float = 9.0
const CEIL_SHED: float = 3.4
const CEIL_LAB: float = 4.0
const CEIL_CTRL: float = 4.0
const ROCKET_X: float = -33.0
const ROCKET_Z: float = 176.0


func setup_tables() -> void:
	out_path = "res://gravelight/maps/map04_fernflug/map04c.tscn"
	root_name = "Map04cGroomLake"
	map_id = "map04c_groomlake"
	display_name = "Fernflug — Act III: Groom Lake"
	start_zone = "A_WRECK"
	intro_text = "GROOM LAKE, NEVADA\nan Army Air Forces test range, 05:50"
	json_table = "map04c"
	zone_bits = {"A_WRECK": 1, "B_LAKEBED": 2, "C_HANGAR": 3, "D_MOTORPOOL": 4, "E_RADAR": 5, "F_LAB": 6, "G_SILO": 7}
	adj = {"A_WRECK": ["B_LAKEBED"], "B_LAKEBED": ["A_WRECK", "C_HANGAR", "D_MOTORPOOL"],
		"C_HANGAR": ["B_LAKEBED", "D_MOTORPOOL", "E_RADAR"], "D_MOTORPOOL": ["B_LAKEBED", "C_HANGAR", "F_LAB"],
		"E_RADAR": ["C_HANGAR", "F_LAB"], "F_LAB": ["D_MOTORPOOL", "E_RADAR", "G_SILO"], "G_SILO": ["F_LAB"]}
	windows = [
		["W_A_L", "A_WRECK", Vector3(-14, 0, -20), 90.0], ["W_A_R", "A_WRECK", Vector3(14, 0, -20), -90.0],
		["W_C_W", "C_HANGAR", Vector3(20, 0, 70), 90.0], ["W_C_E", "C_HANGAR", Vector3(70, 0, 80), -90.0], ["W_C_N", "C_HANGAR", Vector3(30, 0, 100), 180.0],
		["W_D_W", "D_MOTORPOOL", Vector3(-70, 0, 80), 90.0], ["W_D_N", "D_MOTORPOOL", Vector3(-60, 0, 100), 180.0],
		["W_E_E", "E_RADAR", Vector3(70, 0, 120), -90.0],
		["W_F_1", "F_LAB", Vector3(-70, LAB_Y, 120), 90.0], ["W_F_3", "F_LAB", Vector3(-70, LAB_Y, 144), 90.0],
		["W_G_N", "G_SILO", Vector3(-30, LAB_Y, 196), 180.0],
	]
	zone_boxes = [
		["A_WRECK", Vector3(-14, -1, -36), Vector3(14, 6, -4)],
		["B_LAKEBED", Vector3(-60, -1, -4), Vector3(60, 6, 60)],
		["C_HANGAR", Vector3(20, -1, 60), Vector3(70, 12, 100)],
		["D_MOTORPOOL", Vector3(-70, -1, 60), Vector3(-20, 6, 100)],
		["D_MOTORPOOL", Vector3(-20, -1, 86), Vector3(20, 6, 100)],        # the service lane to the hangar's side door
		["E_RADAR", Vector3(20, -1, 100), Vector3(70, 8, 140)],
		["F_LAB", Vector3(-70, LAB_Y - 1, 100), Vector3(-20, 6, 150)],       # the hall, the rooms and the hatch ramp
		["F_LAB", Vector3(-20, LAB_Y - 1, 134), Vector3(20, 2, 140)],        # the cable trench from the radar tower
		["G_SILO", Vector3(-70, LAB_Y - 1, 150), Vector3(-20, 40, 196)],
	]
	for w: Array in windows:
		zone_boxes.append(closet_box(str(w[1]), w[2], float(w[3])))
	links = [
		[Vector3(0, 0, -4.4), Vector3(0, 0, -3.6), "B_LAKEBED"],
		[Vector3(45, 0, 59.6), Vector3(45, 0, 60.4), "C_HANGAR"],
		[Vector3(-45, 0, 59.6), Vector3(-45, 0, 60.4), "D_MOTORPOOL"],
		[Vector3(20.4, 0, 93), Vector3(19.6, 0, 93), "D_MOTORPOOL"],       # the side door, hangar → lane
		[Vector3(45, 0, 99.6), Vector3(45, 0, 100.4), "E_RADAR"],
		[Vector3(-45, 0, 99.0), Vector3(-45, 0, 100.8), "F_LAB"],           # the hatch at the ramp's head (the pool's mesh stops short of the wall)
		[Vector3(-19.6, 0, 93), Vector3(-20.4, 0, 93), "D_MOTORPOOL"],       # the lane into the motor pool (two boxes of one zone)
		[Vector3(-45, LAB_Y, 111.6), Vector3(-45, LAB_Y, 112.4), "F_LAB"],  # the ramp's foot into the hall
		[Vector3(20.4, 0, 137), Vector3(19.6, 0, 137), "F_LAB"],            # the trench's head
		[Vector3(-19.6, LAB_Y, 137), Vector3(-20.4, LAB_Y, 137), "F_LAB"],  # the trench's foot into the hall
		[Vector3(-40, LAB_Y, 149.6), Vector3(-40, LAB_Y, 150.4), "G_SILO"],
	]
	buys = [
		["m1_carbine", Vector3(-13.83, 1.5, -30.0), 90.0], ["m1_garand", Vector3(-59.83, 1.5, 20.0), 90.0],
		["thompson", Vector3(69.83, 1.5, 72.0), -90.0], ["bar", Vector3(-69.83, 1.5, 70.0), 90.0],
		["springfield", Vector3(69.83, 1.5, 110.0), -90.0],
	]
	doors = [
		["Door_Lakebed", "door_lakebed", "B_LAKEBED", [], "", 750, "the lake bed", Vector3(0, 0, -4), 0.0, 2.4, false],
		["Door_Hangar", "door_hangar", "C_HANGAR", [], "", 1000, "the hangar", Vector3(45, 0, 60), 0.0, 3.0, false],
		["Door_Motorpool", "door_motorpool", "D_MOTORPOOL", [], "", 1000, "the motor pool", Vector3(-45, 0, 60), 0.0, 3.0, false],
		["Door_Side", "door_side", "D_MOTORPOOL", [], "", 1000, "the hangar's side door", Vector3(20, 0, 93), 90.0, 2.0, false],
		["Door_Radar", "door_radar", "E_RADAR", [], "", 1250, "the radar tower", Vector3(45, 0, 100), 0.0, 2.4, false],
		["Door_Lab", "door_lab", "F_LAB", [], "lab", 1500, "the laboratory hatch", Vector3(-45, 0, 100), 0.0, 3.0, true],
		["Door_Trench", "door_lab", "F_LAB", [], "lab", 1500, "the cable trench", Vector3(20, 0, 137), 90.0, 2.4, true],
		["Door_Silo", "door_silo", "G_SILO", [], "", 2000, "the test silo", Vector3(-40, LAB_Y, 150), 0.0, 3.0, false],
	]
	ammo_boxes = [
		["Wreck", Vector3(13.48, 0, -30.0), -90.0], ["Hangar", Vector3(69.48, 0, 88.0), -90.0],
		["Motorpool", Vector3(-45.0, 0, 99.48), 180.0], ["Silo", Vector3(-69.48, LAB_Y, 185.0), 90.0],
	]
	grounds = [
		["A_WRECK", Vector3(0, 0, -30), 1],
		["B_LAKEBED", Vector3(-50, 0, 50), 1], ["B_LAKEBED", Vector3(50, 0, 10), 1],
		["C_HANGAR", Vector3(30, 0, 94), 1],
		["D_MOTORPOOL", Vector3(-45, 0, 76), 1],
		["E_RADAR", Vector3(30, 0, 132), 1],
		["F_LAB", Vector3(-30, LAB_Y, 120), 1],
		["G_SILO", Vector3(-60, LAB_Y, 190), 1],
	]
	# the Burrowers' points: ground spawns on the salt the GroomController walks toward the players (Catwalk_B_LAKEBED_n)
	catwalks = []
	for p: Vector3 in [Vector3(-30, 0, 12), Vector3(0, 0, 20), Vector3(30, 0, 12), Vector3(-30, 0, 40), Vector3(0, 0, 48), Vector3(30, 0, 40)]:
		catwalks.append(["B_LAKEBED", p, true])
	perks = [
		["second_wind", Vector3(-8.0, 0, -35.2), 0.0],
		["ironhide_stout", Vector3(-59.2, 0, 44.0), 90.0],
		["magpie_mead", Vector3(20.8, 0, 86.0), 90.0],
		["trigger_tonic", Vector3(-20.8, 0, 70.0), -90.0],
		["hawkeye_brandy", Vector3(20.8, 0, 120.0), 90.0],
		["twin_barrel", Vector3(-57.2, LAB_Y, 112.8), 0.0],
		["blastproof_bock", Vector3(-20.8, LAB_Y, 125.0), -90.0],
		["packmule_porter", Vector3(-69.2, LAB_Y, 170.0), 90.0],
		["skyhook_sekt", Vector3(-20.8, LAB_Y, 165.0), -90.0],
	]
	crates = [
		["Wreck", Vector3(6.0, 0, -12.0), -90.0, true, [Vector3(6, 0, -15), Vector3(0, 0, -15), Vector3(0, 0, -20)]],
		["Hangar", Vector3(26.0, 0, 76.0), 90.0, true, [Vector3(29, 0, 76), Vector3(29, 0, 70), Vector3(35, 0, 66)]],
		["Lab", Vector3(-26.0, LAB_Y, 114.0), 90.0, false, [Vector3(-29, LAB_Y, 114), Vector3(-29, LAB_Y, 120), Vector3(-35, LAB_Y, 120)]],
	]
	player_spawns = [[Vector3(-2, 0, -26), 0.0], [Vector3(2, 0, -26), 0.0], [Vector3(-2, 0, -29), 0.0], [Vector3(2, 0, -29), 0.0]]
	power_switch = {"name": "Generator", "label": "the generator", "pos": Vector3(-64.0, 0, 99.3), "yaw": 180.0,
		"zone_order": ["D_MOTORPOOL", "B_LAKEBED", "A_WRECK", "C_HANGAR", "E_RADAR", "F_LAB", "G_SILO"]}
	crucible = {"pos": Vector3(-66.0, LAB_Y, 160.0), "yaw": 90.0, "needs_power": true}
	armorers_bench = []
	burst_points = [Vector3(-45, 0, 80), Vector3(0, 0, 30), Vector3(45, 0, 80)]
	traps = [
		["res://gravelight/world/trap_live_wire.gd", "Trap_FuelDump", {"size": Vector3(8.0, 2.4, 1.2)}, Vector3(-27.0, 0, 90.0), 0.0, Vector3(-36.0, 0, 97.0), 180.0, "fuel_dump"],
	]
	mat_map = {
		"wall": "planks", "concrete": "concrete", "ground": "concrete", "metal": "iron", "steel": "steel", "rust": "rust",
		"furniture": "furniture", "deck": "steel_grate", "grey": "grey_paint", "lead": "lead", "glass": "glass", "beam": "beam",
		"machine": "machine_grey", "olive": "feldgrau", "rail": "iron", "roof": "roof", "planks": "planks", "dirt": "dirt", "salt": "concrete",
		"caliche": "stone", "sand": "dirt", "stairs": "concrete",
	}
	mat_rules = [["Salt*", "concrete"], ["Hull*", "steel"], ["Wing*", "steel"], ["Caliche*", "stone"], ["Berm*", "dirt"], ["Tower*", "iron"], ["Truck*", "feldgrau"], ["Rocket*", "steel"]]
	hide = ["NavBlock*", "Truck*", "Bomber*", "Cage*", "Office*", "Bench*", "Pit*", "Tank*", "Console*", "Rocket*", "Dish*", "Shack*", "Gantry*"]
	sky_top = Color(0.32, 0.46, 0.74)
	sky_horizon = Color(0.96, 0.74, 0.5)
	ambient = Color(0.62, 0.6, 0.64)
	fog_color = Color(0.82, 0.74, 0.66)
	moon_rot = Vector3(-11, -78, 0)   # the sun, just up over the eastern mountains


# ================================================================== geometry

func build_geometry() -> void:
	# the salt slab, with the underground footprint left out (the lab, the silo and the cable trench are below it)
	box(geo, "Salt_S", Vector3(-80, -0.5, -50), Vector3(80, 0, 100), "salt")
	box(geo, "Salt_E1", Vector3(-18, -0.5, 100), Vector3(80, 0, 134), "salt")
	box(geo, "Salt_E2", Vector3(20, -0.5, 134), Vector3(80, 0, 150), "salt")
	box(geo, "Salt_E3", Vector3(-18, -0.5, 140), Vector3(20, 0, 150), "salt")
	box(geo, "Salt_W", Vector3(-80, -0.5, 100), Vector3(-72, 0, 200), "salt")
	box(geo, "Salt_N", Vector3(-72, -0.5, 152), Vector3(-18, 0, 200), "salt", false)   # over the silo: dressing only, the shaft is open
	_wreck()
	_lakebed()
	_hangar()
	_motorpool()
	_radar()
	_lab()
	_silo()
	_mountains()


## The Kranich on its belly: the fuselage interior is the spawn room (the torn hull is the windows, the aft seam
## shut, the open bay forward is the way out), the port wing torn off beside it on the salt.
func _wreck() -> void:
	wall_x("A_S", -36.0, -14 - T * 0.5, 14 + T * 0.5, 0, CEIL_WRECK, [], "steel")
	wall_z("Hull_W", -14.0, -36, -4, 0, CEIL_WRECK, [win(-20, 0)], "steel")
	wall_z("Hull_E", 14.0, -36, -4, 0, CEIL_WRECK, [win(-20, 0)], "steel")
	wall_x("AB", -4.0, -14 - T * 0.5, 14 + T * 0.5, 0, CEIL_WRECK, [door(0, 0, 2.4)], "steel")
	box(geo, "HullRoof", Vector3(-14.3, CEIL_WRECK, -36.3), Vector3(14.3, CEIL_WRECK + 0.4, -3.7), "steel", false)
	# the rack bases came down with it (cover in the spawn room)
	for i: int in 2:
		var z: float = -28.0 + 8.0 * float(i)
		box(geo, "NavBlock_RackL%d" % i, Vector3(-9.0, 0, z - 1.0), Vector3(-6.0, 0.7, z + 1.0), "steel")
		box(geo, "NavBlock_RackR%d" % i, Vector3(6.0, 0, z - 1.0), Vector3(9.0, 0.7, z + 1.0), "steel")
	# the torn port wing on the salt outside (never walkable: it lies west of the hull)
	box(geo, "WingTorn", Vector3(-52, 0, -30), Vector3(-16, 2.2, -14), "steel")
	box(geo, "WingTornTip", Vector3(-62, 0, -24), Vector3(-52, 1.2, -18), "steel")
	# the starboard wing still on, low, sloping away east
	box(geo, "WingStbd", Vector3(16, 0, -30), Vector3(50, 1.6, -16), "steel")
	for w: Array in windows:
		if str(w[1]) == "A_WRECK":
			closet(w[2], float(w[3]))


## The open salt flat: a berm all round so nothing walks off the range, the range markers, the impeller core's
## crater, the hull's shadow. The six burrow points are ZombieSpawns (the Catwalk table).
func _lakebed() -> void:
	wall_z("Berm_W", -60.0, -4, 60, 0, 2.0, [], "dirt")
	wall_z("Berm_E", 60.0, -4, 60, 0, 2.0, [], "dirt")
	wall_x("Berm_S_W", -4.0, -60 - T * 0.5, -14 + T * 0.5, 0, 2.0, [], "dirt")
	wall_x("Berm_S_E", -4.0, 14 - T * 0.5, 60 + T * 0.5, 0, 2.0, [], "dirt")
	wall_x("Berm_N", 60.0, -60 - T * 0.5, 60 + T * 0.5, 0, 2.0, [door(-45, 0, 3.0), door(45, 0, 3.0)], "dirt")
	for i: int in 5:
		var x: float = -40.0 + 20.0 * float(i)
		box(geo, "NavBlock_Marker%d" % i, Vector3(x - 0.3, 0, 29.7), Vector3(x + 0.3, 1.6, 30.3), "grey")
	box(geo, "NavBlock_Crater", Vector3(17.0, 0, 17.0), Vector3(23.0, 0.4, 23.0), "dirt")   # where the core came to rest


## The hangar: a wooden barn with a cannibalized bomber in the middle (loop 2 is the ring round it), Dee's cage in
## the north-east corner, Hale's glass office along the north wall, the relay object under its tarp, the crate.
func _hangar() -> void:
	wall_x("C_S", 60.0, 20 - T * 0.5, 70 + T * 0.5, 0, CEIL_HANGAR, [door(45, 0, 3.0)], "wall")
	wall_x("C_N", 100.0, 20 - T * 0.5, 70 + T * 0.5, 0, CEIL_HANGAR, [door(45, 0, 2.4), win(30, 0)], "wall")
	wall_z("C_W", 20.0, 60, 100, 0, CEIL_HANGAR, [win(70, 0), door(93, 0)], "wall")
	wall_z("C_E", 70.0, 60, 100, 0, CEIL_HANGAR, [win(80, 0)], "wall")
	box(geo, "HangarRoof", Vector3(19.7, CEIL_HANGAR, 59.7), Vector3(70.3, CEIL_HANGAR + 0.4, 100.3), "roof", false)
	box(geo, "Bomber", Vector3(38, 0, 72), Vector3(52, 3.0, 92), "olive")                  # the cannibalized bomber's body
	box(geo, "BomberWingL", Vector3(26, 2.2, 80), Vector3(38, 2.8, 84), "olive", false)
	box(geo, "BomberWingR", Vector3(52, 2.2, 80), Vector3(64, 2.8, 84), "olive", false)
	box(geo, "NavBlock_Cage", Vector3(62, 0, 92), Vector3(70, 2.4, 100), "metal")           # Dee's supply cage (she is inside)
	box(geo, "Office", Vector3(22, 0, 92), Vector3(36, 3.0, 100), "glass")                   # Hale's glass office, sealed
	box(geo, "NavBlock_Relay", Vector3(58.5, 0, 64.5), Vector3(61.5, 2.0, 67.5), "machine")  # the relay object under its tarp
	box(geo, "NavBlock_Crate", Vector3(22.5, 0, 63.0), Vector3(25.5, 1.4, 65.0), "planks")   # the British crate
	box(geo, "Bench_C1", Vector3(22, 0, 66), Vector3(23, 0.9, 72), "furniture")
	for w: Array in windows:
		if str(w[1]) == "C_HANGAR":
			closet(w[2], float(w[3]))


## The motor pool: two trucks, the fuel dump, the generator shed (the power), the lane east to the hangar's side
## door, the hatch at the north wall that goes down to the lab.
func _motorpool() -> void:
	wall_x("D_S", 60.0, -70 - T * 0.5, -20 + T * 0.5, 0, CEIL_SHED, [door(-45, 0, 3.0)], "wall")
	wall_z("D_W", -70.0, 60, 100, 0, CEIL_SHED, [win(80, 0)], "wall")
	wall_z("D_E", -20.0, 60, 86, 0, CEIL_SHED, [], "wall")
	wall_x("D_N", 100.0, -70 - T * 0.5, 20 + T * 0.5, 0, CEIL_SHED, [door(-45, 0, 3.0), win(-60, 0)], "wall")
	wall_x("Lane_S", 86.0, -20 - T * 0.5, 20 + T * 0.5, 0, CEIL_SHED, [], "wall")
	box(geo, "MotorpoolRoof", Vector3(-70.3, CEIL_SHED, 59.7), Vector3(-19.7, CEIL_SHED + 0.3, 100.3), "roof", false)
	box(geo, "Truck1", Vector3(-62, 0, 64), Vector3(-56, 2.4, 72), "olive")
	box(geo, "Truck2", Vector3(-40, 0, 64), Vector3(-34, 2.4, 72), "olive")
	box(geo, "Tank_Fuel", Vector3(-31, 0, 92), Vector3(-23, 1.8, 98), "rust")                # the fuel dump
	box(geo, "NavBlock_GenShed", Vector3(-70, 0, 90), Vector3(-58, 2.6, 98.4), "machine")   # the generator (the switch on its south face)
	for w: Array in windows:
		if str(w[1]) == "D_MOTORPOOL":
			closet(w[2], float(w[3]))


## The radar tower on its rise: the lattice base, the dish, the shack with the radio, the cable trench's head.
func _radar() -> void:
	wall_x("E_N", 140.0, 20 - T * 0.5, 70 + T * 0.5, 0, 2.0, [], "dirt")
	wall_z("E_W", 20.0, 100, 140, 0, 2.6, [door(137, 0, 2.4)], "dirt")   # the trench door: a berm with the opening cut
	wall_z("E_E", 70.0, 100, 140, 0, 2.0, [win(120, 0)], "dirt")
	box(geo, "Tower_Base", Vector3(42, 0, 117), Vector3(48, 1.0, 123), "metal")             # a step (the launch points stand on it)
	box(geo, "Tower_Mast", Vector3(44, 1.0, 119), Vector3(46, 18.0, 121), "metal")
	box(geo, "Dish", Vector3(40, 16.0, 118), Vector3(50, 16.6, 122), "grey", false)
	box(geo, "Shack", Vector3(58, 0, 128), Vector3(66, 3.0, 136), "planks")                 # the shack (the radio on its south face)
	for w: Array in windows:
		if str(w[1]) == "E_RADAR":
			closet(w[2], float(w[3]))


## The underground lab: the hatch ramp down from the motor pool, the long hall (the Test Pilot's arena, rafters
## over it), three specimen rooms along the west side with open glass fronts, the Nevada stone's pit in the
## middle room, the workbench at the hall's head, the cable trench ramp down from the radar tower on the east.
func _lab() -> void:
	box(geo, "CalicheFloor", Vector3(-72, LAB_Y - 0.5, 98), Vector3(-18, LAB_Y, 152), "caliche")
	# the hatch ramp: from the motor pool's north door (y 0, z 100) down to the hall (y -6, z 112)
	ramp_z("HatchRamp", -48.0, -42.0, 100.0, 112.0, 0.0, LAB_Y)
	box(geo, "HatchWallW", Vector3(-48.3, LAB_Y - 0.5, 100), Vector3(-48, 3.0, 112), "caliche")
	box(geo, "HatchWallE", Vector3(-42, LAB_Y - 0.5, 100), Vector3(-41.7, 3.0, 112), "caliche")
	box(geo, "HatchRoof", Vector3(-48.3, 3.0, 100), Vector3(-41.7, 3.4, 112.3), "caliche", false)
	# the hall and the rooms (walls from the lab floor up to the ceiling)
	wall_x("F_S_W", 112.0, -70 - T * 0.5, -48 + T * 0.5, LAB_Y, LAB_Y + CEIL_LAB, [], "caliche")
	wall_x("F_S_E", 112.0, -42 - T * 0.5, -20 + T * 0.5, LAB_Y, LAB_Y + CEIL_LAB, [], "caliche")
	wall_z("F_W", -70.0, 112, 150, LAB_Y, LAB_Y + CEIL_LAB, [win(120, LAB_Y), win(144, LAB_Y)], "caliche")
	wall_z("F_E", -20.0, 112, 150, LAB_Y, LAB_Y + CEIL_LAB, [door(137, LAB_Y, 2.4)], "caliche")
	wall_x("F_N", 150.0, -70 - T * 0.5, -20 + T * 0.5, LAB_Y, LAB_Y + CEIL_LAB, [door(-40, LAB_Y, 3.0)], "caliche")
	box(geo, "LabRoof", Vector3(-70.3, LAB_Y + CEIL_LAB, 111.7), Vector3(-19.7, LAB_Y + CEIL_LAB + 0.4, 150.3), "caliche", false)
	# the specimen rooms: x -70..-58, three along z (124 and 136 are the dividing walls)
	for zd: float in [124.0, 136.0]:
		box(geo, "RoomWall%d" % int(zd), Vector3(-70, LAB_Y, zd - 0.15), Vector3(-58, LAB_Y + CEIL_LAB, zd + 0.15), "caliche")
	for i: int in 3:
		var z0: float = 112.0 + 12.0 * float(i)
		box(geo, "NavBlock_GlassJamb%d" % i, Vector3(-58.2, LAB_Y, z0 + 0.3), Vector3(-57.8, LAB_Y + CEIL_LAB, z0 + 3.0), "glass")
		box(geo, "NavBlock_GlassJamb%db" % i, Vector3(-58.2, LAB_Y, z0 + 9.0), Vector3(-57.8, LAB_Y + CEIL_LAB, z0 + 11.7), "glass")
	box(geo, "Pit", Vector3(-67, LAB_Y, 128), Vector3(-61, LAB_Y + 0.5, 134), "lead")           # the Nevada stone's pit (room 2)
	box(geo, "Bench_Work", Vector3(-62, LAB_Y, 112.5), Vector3(-58, LAB_Y + 0.9, 113.5), "furniture")   # the workbench stands here
	for i: int in 4:
		var rz: float = 116.0 + 8.0 * float(i)
		box(geo, "Rafter%d" % i, Vector3(-58, LAB_Y + CEIL_LAB - 0.5, rz - 0.2), Vector3(-20, LAB_Y + CEIL_LAB, rz + 0.2), "beam", false)
	# the cable trench: from the radar rise (y 0, x 20) down to the hall's east door (y -6, x -20), a cut 6 m wide
	ramp_x("TrenchRamp", 134.0, 140.0, -20.0, 20.0, LAB_Y, 0.0)
	box(geo, "TrenchWallS", Vector3(-20, LAB_Y - 0.5, 133.7), Vector3(20, 2.0, 134), "caliche")
	box(geo, "TrenchWallN", Vector3(-20, LAB_Y - 0.5, 140), Vector3(20, 2.0, 140.3), "caliche")
	for w: Array in windows:
		if str(w[1]) == "F_LAB":
			closet(w[2], float(w[3]))


## The test silo: the corridor from the lab, the control room (the Crucible, the console), the shaft with the
## LANTERN rocket on its gantry and the lift at its foot; the shaft is open to the sky.
func _silo() -> void:
	box(geo, "SiloFloor", Vector3(-72, LAB_Y - 0.5, 150), Vector3(-18, LAB_Y, 198), "concrete")
	wall_z("G_W", -70.0, 150, 196, LAB_Y, LAB_Y + CEIL_CTRL, [], "concrete")
	wall_z("G_E", -20.0, 150, 196, LAB_Y, 30.0, [], "concrete")
	wall_x("G_N", 196.0, -70 - T * 0.5, -20 + T * 0.5, LAB_Y, 30.0, [win(-30, LAB_Y)], "concrete")
	wall_x("G_S_W", 150.0, -70 - T * 0.5, -46 + T * 0.5, LAB_Y, LAB_Y + CEIL_CTRL, [], "concrete")   # the lab's north wall carries the door at -40
	wall_x("G_S_E", 150.0, -34 - T * 0.5, -20 + T * 0.5, LAB_Y, 30.0, [], "concrete")
	wall_z("Ctrl_E", -46.0, 156, 196, LAB_Y, LAB_Y + CEIL_CTRL, [door(166, LAB_Y, 2.4), door(186, LAB_Y, 2.4)], "concrete")   # control room | shaft
	box(geo, "CtrlRoof", Vector3(-70.3, LAB_Y + CEIL_CTRL, 149.7), Vector3(-45.7, LAB_Y + CEIL_CTRL + 0.4, 196.3), "concrete", false)
	box(geo, "ShaftWallW_Hi", Vector3(-46.3, LAB_Y + CEIL_CTRL, 150), Vector3(-45.7, 30.0, 196), "concrete", false)
	box(geo, "Console_Burn", Vector3(-60, LAB_Y, 178), Vector3(-56, LAB_Y + 1.1, 179.5), "machine")   # the silo console
	box(geo, "Rocket_Base", Vector3(ROCKET_X - 3.2, LAB_Y, ROCKET_Z - 3.2), Vector3(ROCKET_X + 3.2, LAB_Y + 1.0, ROCKET_Z + 3.2), "steel")
	box(geo, "Gantry_Post", Vector3(ROCKET_X + 4.0, LAB_Y, ROCKET_Z - 0.5), Vector3(ROCKET_X + 5.0, LAB_Y + 28.0, ROCKET_Z + 0.5), "metal")
	for w: Array in windows:
		if str(w[1]) == "G_SILO":
			closet(w[2], float(w[3]))


## The mountains like cut paper round the horizon (never reachable).
func _mountains() -> void:
	for i: int in 9:
		var x: float = -200.0 + 50.0 * float(i)
		var h: float = 40.0 + 25.0 * float((i * 7) % 4)
		box(geo, "Mtn_N%d" % i, Vector3(x, -1, 300 + float(i % 3) * 20.0), Vector3(x + 60, h, 340 + float(i % 3) * 20.0), "caliche", false)
		box(geo, "Mtn_S%d" % i, Vector3(x, -1, -300), Vector3(x + 60, h * 0.8, -260), "caliche", false)
	for j: int in 6:
		var z: float = -250.0 + 90.0 * float(j)
		box(geo, "Mtn_E%d" % j, Vector3(260, -1, z), Vector3(300, 35.0 + 20.0 * float(j % 3), z + 80), "caliche", false)
		box(geo, "Mtn_W%d" % j, Vector3(-300, -1, z), Vector3(-260, 45.0 + 20.0 * float((j + 1) % 3), z + 80), "caliche", false)


# ================================================================== dressing + lights

func build_dressing() -> void:
	# the wreck burns: fire and smoke over the torn wing root, embers in the bay; the fire's damage zone is the
	# GroomController's (map04c.json "fire")
	for fp: Vector3 in [Vector3(-18, 1.0, -22), Vector3(-26, 1.5, -26), Vector3(18, 1.0, -22)]:
		Props.flames(dress, fp, 4.0, 3.5, 50)
		Props.smoke(dress, fp + Vector3(0, 2.0, 0), 3.0, 14.0, 30)
		lamp(fp + Vector3(0, 1.5, 0), FIRE, 2.4, 14.0, 0.35, 1.2)
	Props.embers(dress, Vector3(0, 0.3, -12), 6.0, 20)
	# the range flag with the two-ring disc on the hangar's apron
	Props.cyl(dress, Vector3(10, 4.0, 64), 0.08, 8.0, "iron")
	Props.block(dress, Vector3(10.1, 6.8, 63.98), Vector3(12.1, 8.0, 64.02), "grey_paint")
	# the hangar: the bomber's cockpit glass, the cage's wire, the office's desk lamp, the relay object's hum light,
	# the tarp, the olive-drab repaint on the cabinets (chalk), the chalk-marked crate
	_noshadow(B(Vector3(44, 2.2, 90), Vector3(46, 3.4, 92.2), "glass"))
	Props.grille(dress, Vector3(62, 0, 92), Vector3(70, 0, 92), 2.4, 0.3, "iron")
	Props.grille(dress, Vector3(62, 0, 92), Vector3(62, 0, 100), 2.4, 0.3, "iron")
	lamp(Vector3(66, 1.6, 96), INCAND, 1.0, 7.0, 0.04, 0.3)   # Dee's lamp in the cage
	lamp(Vector3(29, 2.4, 96), INCAND, 0.9, 8.0, 0.0, 0.2)    # Hale's desk lamp, never off
	_noshadow(B(Vector3(58.6, 0.4, 64.6), Vector3(61.4, 1.9, 67.4), "nachtglas"))
	lamp(Vector3(60, 2.6, 66), VIOLET, 1.6, 10.0, 0.12, 0.8)
	Props.block(dress, Vector3(57.8, 2.0, 63.8), Vector3(62.2, 2.2, 68.2), "cloth_red")     # the tarp, thrown back
	Props.stencil(dress, Vector3(24.0, 1.45, 63.95), 0.0, "D / LANTERN  ·  LONDON", 28)
	Props.stencil(dress, Vector3(20.3, 2.2, 86.0), 90.0, "U.S. ARMY  ·  LOCALIZED", 24)
	Props.workbench(dress, Vector3(27.0, 0, 90.0), 0.0, 3.0, 0.8)
	# the motor pool: drums at the dump, cable from the generator, the hatch's warning stripes
	for dx: float in [-30.0, -28.5, -27.0]:
		Props.oil_drum(dress, Vector3(dx, 0, 91.0), "rust")
	Props.cable(dress, Vector3(-64, 2.6, 98.4), Vector3(-45, 3.0, 100), 0.4, 0.04, 8, "rubber")
	Props.stencil(dress, Vector3(-45.0, 2.8, 99.95), 0.0, "LAB  ·  AUTHORIZED PERSONNEL", 26)
	# the radar: the lattice struts, the dish cable, the shack's aerial
	for sx: float in [42.0, 48.0]:
		for sz: float in [117.0, 123.0]:
			Props.strut(dress, Vector3(sx, 1.0, sz), Vector3(45, 16, 120), 0.12, "iron")
	Props.cable(dress, Vector3(45, 16, 120), Vector3(62, 3.0, 132), 1.5, 0.03, 10, "rubber")
	Props.cyl(dress, Vector3(60, 4.5, 130), 0.03, 3.0, "iron")
	# the lab: Nachtglas light from the pit (the generator died with the range; the stone lights the rooms)
	_noshadow(B(Vector3(-66.5, LAB_Y + 0.5, 128.5), Vector3(-61.5, LAB_Y + 1.4, 133.5), "nachtglas"))
	lamp(Vector3(-64, LAB_Y + 2.4, 131), VIOLET, 2.2, 16.0, 0.15, 1.2)
	fog("PitGlow", Vector3(-64, LAB_Y + 2.0, 131), Vector3(14, 4.0, 24), 0.05, Color(0.5, 0.35, 0.7), Color(0.08, 0.02, 0.12))
	for i: int in 3:
		var z0: float = 112.0 + 12.0 * float(i)
		Props.gurney(dress, Vector3(-64, LAB_Y, z0 + 5.0), 90.0, i != 1)
		Props.cabinet(dress, Vector3(-69.5, LAB_Y, z0 + 9.0), 90.0, 1.2, 1.8, 0.5)
	Props.stencil(dress, Vector3(-45.0, LAB_Y + 3.2, 112.2), 0.0, "PROJECT LANTERN  ·  SPECIMEN WING", 30)
	# the silo: the LANTERN rocket (kept whole so the launch fx can lift it), the gantry arms, the console's dials,
	# the Crucible's olive paint (chalk on the control room wall), the shaft's sky
	var rk: Node3D = Props.group(dress, "Rocket", Vector3(ROCKET_X, LAB_Y + 1.0, ROCKET_Z))
	rk.set_meta("keep", true)
	Props.cyl(rk, Vector3(0, 11.0, 0), 2.4, 22.0, "steel")
	Props.cone(rk, Vector3(0, 24.5, 0), 2.4, 5.0, "steel")
	for fa: float in [0.0, 90.0, 180.0, 270.0]:
		var dir: Vector3 = Vector3(cos(deg_to_rad(fa)), 0, sin(deg_to_rad(fa)))
		Props.prism(rk, dir * 3.0 + Vector3(0, 2.0, 0), Vector3(1.4, 4.0, 0.3), "steel", Vector3(0, -fa, 0))
	Props.block(rk, Vector3(-2.45, 12.0, -0.6), Vector3(-2.35, 13.2, 0.6), "red_paint")   # the two-ring disc, red field
	Props.stencil(rk, Vector3(-2.5, 9.0, 0), 90.0, "LANTERN", 40)
	for gy: float in [LAB_Y + 8.0, LAB_Y + 16.0, LAB_Y + 24.0]:
		Props.strut(dress, Vector3(ROCKET_X + 4.5, gy, ROCKET_Z), Vector3(ROCKET_X + 2.6, gy, ROCKET_Z), 0.15, "iron")
	for gx: float in [-59.5, -58.3, -57.1]:
		Props.gauge(dress, Vector3(gx, LAB_Y + 1.15, 178.6), 0.0)
	Props.stencil(dress, Vector3(-69.8, LAB_Y + 2.6, 160.0), 90.0, "THE FOURTH UNIT  ·  olive drab, badly", 22)
	label("GROOM LAKE  ·  AAF TEST RANGE  ·  NO NAME YET", Vector3(45, 3.6, 59.7), 180.0, 30)
	label("MOTOR POOL", Vector3(-45, 3.2, 59.7), 180.0, 34)
	label("LANTERN", Vector3(-40, LAB_Y + 3.4, 149.7), 180.0, 40)
	# power lights (the generator): the hangar's floods, the motor pool's bulbs, the tower's lamp, the lab's tubes,
	# the silo's work lights; the wreck and the salt get the dawn and the fire
	for zp: Array in [
			["A_WRECK", Vector3(0, CEIL_WRECK - 0.6, -20)],
			["B_LAKEBED", Vector3(-45, 4.0, 58)], ["B_LAKEBED", Vector3(45, 4.0, 58)],
			["C_HANGAR", Vector3(30, CEIL_HANGAR - 1.0, 70)], ["C_HANGAR", Vector3(60, CEIL_HANGAR - 1.0, 70)], ["C_HANGAR", Vector3(30, CEIL_HANGAR - 1.0, 92)], ["C_HANGAR", Vector3(60, CEIL_HANGAR - 1.0, 86)],
			["D_MOTORPOOL", Vector3(-58, CEIL_SHED - 0.5, 68)], ["D_MOTORPOOL", Vector3(-36, CEIL_SHED - 0.5, 84)], ["D_MOTORPOOL", Vector3(0, CEIL_SHED - 0.5, 93)],
			["E_RADAR", Vector3(45, 3.0, 110)], ["E_RADAR", Vector3(62, 3.4, 127)],
			["F_LAB", Vector3(-50, LAB_Y + CEIL_LAB - 0.6, 118)], ["F_LAB", Vector3(-30, LAB_Y + CEIL_LAB - 0.6, 128)], ["F_LAB", Vector3(-40, LAB_Y + CEIL_LAB - 0.6, 142)], ["F_LAB", Vector3(0, 1.4, 137)],
			["G_SILO", Vector3(-58, LAB_Y + CEIL_CTRL - 0.6, 160)], ["G_SILO", Vector3(-58, LAB_Y + CEIL_CTRL - 0.6, 184)], ["G_SILO", Vector3(-30, LAB_Y + 6.0, 160)], ["G_SILO", Vector3(-30, LAB_Y + 6.0, 190)]]:
		var zone: String = str(zp[0])
		var pos: Vector3 = zp[1]
		if zone == "F_LAB":
			power(zone, pos, 12.0, 0.8, Color(0.75, 0.95, 0.85))   # the lab's tubes, greenish
		elif zone == "B_LAKEBED" or zone == "E_RADAR" or zone == "G_SILO" and pos.x > -46.0:
			power(zone, pos, 16.0, 1.0, SODIUM)                    # the outdoor floods
		else:
			pendant(zone, pos, pos.y + 0.6, "enamel_green", 1.1)


## The dawn: the lib's night sky and moon become the desert's first sun; the fog thins to the horizon.
func build_lights() -> void:
	super.build_lights()
	var sun: DirectionalLight3D = map_root.get_node_or_null("Moon") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(1.0, 0.86, 0.7)
		sun.light_energy = 1.5
		sun.directional_shadow_max_distance = 120.0
	var we: WorldEnvironment = map_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.fog_density = 0.0035
		we.environment.volumetric_fog_density = 0.006
		we.environment.volumetric_fog_albedo = Color(0.95, 0.88, 0.8)
		we.environment.volumetric_fog_emission = Color(0.06, 0.045, 0.03)
		we.environment.ambient_light_energy = 0.9
		we.environment.adjustment_saturation = 0.85


func build_gameplay_extra() -> void:
	_node("res://gravelight/maps/map04_fernflug/act_controller.gd", "ActController", {}, Vector3.ZERO)
	_node("res://gravelight/world/map04/groom_controller.gd", "GroomController", {}, Vector3.ZERO)
	# the Jumpjockeys' launch points: the tower step's corners and the gantry post's foot
	for lp: Array in [["Launch_Tower_1", Vector3(42.5, 1.0, 117.5)], ["Launch_Tower_2", Vector3(47.5, 1.0, 117.5)], ["Launch_Tower_3", Vector3(47.5, 1.0, 122.5)],
			["Launch_Gantry", Vector3(ROCKET_X + 5.5, LAB_Y, ROCKET_Z + 1.5)]]:
		var m: Marker3D = Marker3D.new()
		m.name = str(lp[0])
		m.position = lp[1]
		m.add_to_group(&"launch_points", true)
		gameplay.add_child(m)
	# the Lodestone's parts: two candidate spots each, one live per match (the quest's `ls_parts` pick, or the
	# controller's seeded pick when the quest is not loaded); the workbench at the hall's head
	for pt: Array in [
			["ls_part_coil", "relay_object", Vector3(60.0, 0, 62.8)], ["ls_part_coil", "bomber_bay", Vector3(45.0, 0, 70.8)],
			["ls_part_cradle", "dish_gimbal", Vector3(45.0, 1.0, 120.0)], ["ls_part_cradle", "shack", Vector3(62.0, 0, 127.2)],
			["ls_part_lens", "stone_port", Vector3(-60.2, LAB_Y, 131.0)], ["ls_part_lens", "specimen_3", Vector3(-64.0, LAB_Y, 146.0)]]:
		_node("res://gravelight/world/buildable_part.gd", "Part_%s_%s" % [pt[0], pt[1]], {"part_id": StringName(pt[0]), "spot_id": StringName(pt[1]), "buildable_id": &"lodestone"}, pt[2], 0.0)
	_node("res://gravelight/world/workbench.gd", "Workbench", {"buildable_id": &"lodestone"}, Vector3(-60.0, LAB_Y, 114.2), 0.0)
	# the story objects: Dee's radio on the cage's counter, the radar shack's radio, the impeller core on the salt,
	# the hangar cradle (Hale's hatch: Peg's choice) and the rocket's cradle, the silo console, Dee's cage items
	_node("res://gravelight/world/map04/story_radio.gd", "DeeRadio", {"radio_id": &"dee_radio", "label": "Dee's radio",
		"lines": PackedStringArray(["DEE_M4C_RADIO_02", "DEE_M4C_RADIO_03", "DEE_M4C_RADIO_04", "DEE_M4C_RADIO_05"]), "flag": &"dee_radio_done"}, Vector3(61.6, 0, 96.0), -90.0)
	_node("res://gravelight/world/map04/story_radio.gd", "RadarRadio", {"radio_id": &"radar_radio", "label": "the shack's radio",
		"lines": PackedStringArray(["FAS_M4C_RADIO_01", "FAS_M4C_RADIO_02", "FAS_M4C_RADIO_03", "FAS_M4C_RADIO_04"]), "flag": &"burn_known",
		"requires_power": true, "reveals_burn": true}, Vector3(62.0, 0, 127.6), 180.0)
	_node("res://gravelight/world/map04/carry_object.gd", "ImpellerCore", {"carry_id": &"impeller_core", "label": "the impeller core",
		"deliver_to": &"hangar_cradle"}, Vector3(20.0, 0.4, 16.5), 0.0)
	_node("res://gravelight/world/map04/carry_cradle.gd", "HangarCradle", {"cradle_id": &"hangar_cradle", "accepts": &"impeller_core",
		"label": "the office hatch", "choice": true}, Vector3(36.4, 0, 96.0), -90.0)
	_node("res://gravelight/world/map04/carry_cradle.gd", "RocketCradle", {"cradle_id": &"rocket_cradle", "accepts": &"impeller_core",
		"label": "the rocket's engine bay", "delivered_flag": &"core_in_rocket"}, Vector3(ROCKET_X - 3.6, LAB_Y, ROCKET_Z - 3.0), 90.0)
	_node("res://gravelight/world/map04/silo_console.gd", "SiloConsole", {}, Vector3(-58.0, LAB_Y, 177.6), 180.0)
	for ci: Array in [["casing", Vector3(-7.5, 0, -16.0), "DEE_M4C_CAGE_01", "a Nachtglas casing from the bay"],
			["bomber_coil", Vector3(51.6, 0, 92.4), "DEE_M4C_CAGE_02", "the bomber's coil"],
			["honey", Vector3(23.2, 0.9, 69.0), "DEE_M4C_CAGE_03", "the beekeeper's honey"]]:
		_node("res://gravelight/world/map04/cage_item.gd", "CageItem_%s" % str(ci[0]), {"item_id": StringName(str(ci[0])), "line": str(ci[2]), "label": str(ci[3])}, ci[1], 0.0)
	# the fixed Archive documents (StoryProp rows in story_props.json, map "4c") are spawned by MapRoot
	# the hangar's side door is Dee's (her radio opens it for free); the lab needs the generator (the table's flag)
	var side: Node = gameplay.get_node_or_null("Door_Side")
	if side != null:
		side.set("label", "the hangar's side door (Dee's)")
	# the Test Pilot's drag point on the lakebed and the lab hall's leap anchors (markers the boss reads)
	for an: Array in [["PilotAnchor_Hall", Vector3(-40, LAB_Y, 130)], ["PilotAnchor_Lake", Vector3(0, 0, 30)], ["PilotAnchor_Lake2", Vector3(-30, 0, 20)]]:
		var a: Marker3D = Marker3D.new()
		a.name = str(an[0])
		a.position = an[1]
		gameplay.add_child(a)
