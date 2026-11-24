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
const D = preload("res://gravelight/tools_src/detail_map04c.gd")

var _r: RandomNumberGenerator = RandomNumberGenerator.new()


func setup_tables() -> void:
	out_path = "res://gravelight/maps/map04_fernflug/map04c.tscn"
	root_name = "Map04cGroomLake"
	map_id = "map04c_groomlake"
	display_name = "Fernflug — Act III: Groom Lake"
	start_zone = "A_WRECK"
	intro_text = "GROOM LAKE, NEVADA\nan Army Air Forces test range, 05:50\none day the maps will call it Area 51"
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
		["E_RADAR", Vector3(20, -1, 100), Vector3(70, 18, 140)],             # up to the tower's perch deck (U10 §3)
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
		# T-219: every yaw turned 180 (they faced their wall: the act was authored with the yaw sign flipped)
		["m1_carbine", Vector3(-13.83, 1.5, -30.0), -90.0], ["m1_garand", Vector3(-59.83, 1.5, 20.0), -90.0],
		["thompson", Vector3(69.83, 1.5, 72.0), 90.0], ["bar", Vector3(-69.83, 1.5, 70.0), -90.0],
		["springfield", Vector3(69.83, 1.5, 110.0), 90.0],
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
		# T-219: turned 180 (they faced their wall; the nav blocks are the same either way)
		["Wreck", Vector3(13.48, 0, -30.0), 90.0], ["Hangar", Vector3(69.48, 0, 88.0), 90.0],
		["Motorpool", Vector3(-45.0, 0, 99.48), 0.0], ["Silo", Vector3(-69.48, LAB_Y, 185.0), -90.0],
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
		# T-219: every machine but Ledger Lager turned 180 (they showed the room their backs)
		["second_wind", Vector3(-8.0, 0, -35.2), 180.0],
		["ironhide_stout", Vector3(-59.2, 0, 44.0), -90.0],
		["magpie_mead", Vector3(20.8, 0, 86.0), -90.0],
		["trigger_tonic", Vector3(-20.8, 0, 70.0), 90.0],
		["hawkeye_brandy", Vector3(20.8, 0, 120.0), -90.0],
		["twin_barrel", Vector3(-57.2, LAB_Y, 112.8), 180.0],
		["blastproof_bock", Vector3(-20.8, LAB_Y, 125.0), 90.0],
		["packmule_porter", Vector3(-69.2, LAB_Y, 170.0), -90.0],
		["skyhook_sekt", Vector3(-20.8, LAB_Y, 165.0), 90.0],
		# Ledger Lager (T-141): on the hangar's north wall, 8 m west of Dee's cage and the Range Finance Office (bank.json)
		["ledger_lager", Vector3(54.0, 0, 99.45), 0.0],
	]
	# T-274: the perk deal (perk_layout.json maps.map04c): the ten machines are dealt onto these spots each match; the
	# first ten are where they stood (the spot's back where the machine's back was, then onto its wall)
	perk_spots = [
		spot_from_perk("wreck", "second_wind"), spot_from_perk("lakebed", "ironhide_stout"),
		spot_from_perk("hangar_w", "magpie_mead"), spot_from_perk("motorpool", "trigger_tonic"),
		spot_from_perk("radar", "hawkeye_brandy"), ["lab_hall", "", Vector3(-60.25, LAB_Y, 111.0), 0.0, {}],
		spot_from_perk("lab_east", "blastproof_bock"), spot_from_perk("silo_w", "packmule_porter"),
		spot_from_perk("silo_e", "skyhook_sekt"), spot_from_perk("finance", "ledger_lager"),
		# (Twin Barrel's place by the lab's glass wall had the jamb and the work bench in it: lab_hall is on the hall's
		# south wall 3 m west.) New: the crash site's west berm wall, the lakebed side of the wreck's wall twice (Second
		# Wind's: one door from the start), the radar yard's west wall, the service lane's north wall, the lab's
		# records-room wall
		["wreck_w", "", Vector3(-13.25, 0, -22.5), -90.0, {}], ["lakebed_w", "", Vector3(-38.25, 0, -3.0), 180.0, {}],
		["lakebed_far", "", Vector3(-50.25, 0, -3.0), 180.0, {}], ["radar_w", "", Vector3(20.75, 0, 107.0), -90.0, {}],
		["service_lane", "", Vector3(-5.75, 0, 99.0), 0.0, {}], ["lab_records", "", Vector3(-62.0, LAB_Y, 136.75), 180.0, {}],
	]
	crates = [
		["Wreck", Vector3(6.0, 0, -12.0), -90.0, true, [Vector3(6, 0, -15), Vector3(0, 0, -15), Vector3(0, 0, -20)]],
		["Hangar", Vector3(26.0, 0, 76.0), 90.0, true, [Vector3(29, 0, 76), Vector3(29, 0, 70), Vector3(35, 0, 66)]],
		["Lab", Vector3(-26.0, LAB_Y, 114.0), 90.0, false, [Vector3(-29, LAB_Y, 114), Vector3(-29, LAB_Y, 120), Vector3(-35, LAB_Y, 120)]],
	]
	player_spawns = [[Vector3(-2, 0, -26), 0.0], [Vector3(2, 0, -26), 0.0], [Vector3(-2, 0, -29), 0.0], [Vector3(2, 0, -29), 0.0]]
	power_switch = {"name": "Generator", "label": "the generator", "pos": Vector3(-64.0, 0, 99.3), "yaw": 180.0,
		"zone_order": ["D_MOTORPOOL", "B_LAKEBED", "A_WRECK", "C_HANGAR", "E_RADAR", "F_LAB", "G_SILO"]}
	# T-175: yaw -90 (it was 90: the machine faced the west wall 3 m away and showed the control room its back); the bay
	# between its back and the wall is CrucibleRoom's (tanks, the feed manifold), off the navmesh
	crucible = {"pos": Vector3(-66.0, LAB_Y, 160.0), "yaw": -90.0, "needs_power": true,
		"bay": [Vector3(-69.85, LAB_Y, 157.3), Vector3(-66.8, LAB_Y, 162.7)]}
	armorers_bench = []
	burst_points = [Vector3(-45, 0, 80), Vector3(0, 0, 30), Vector3(45, 0, 80)]
	traps = [
		# U10 §3 (T-157): the fuel dump lights a 20 s wall of fire with a whump and a smoke column (was a live wire)
		["res://gravelight/world/map04/trap_fuel_dump.gd", "Trap_FuelDump", {"size": Vector3(8.0, 2.4, 1.6)}, Vector3(-27.0, 0, 90.0), 0.0, Vector3(-36.0, 0, 97.0), 180.0, "fuel_dump"],
		# U10 §3: the hangar's sliding door drops on the south doorway (a crush trap, 60 s), its lever inside by the door
		["res://gravelight/world/map04/trap_door_drop.gd", "Trap_HangarDoor", {"size": Vector3(3.2, 2.4, 2.0), "hang_y": 2.6}, Vector3(45.0, 0, 60.35), 0.0, Vector3(49.4, 0, 60.45), 180.0, "door_drop"],   # T-219: the lever yaw 180 (it faced the wall)
	]
	mat_map = {
		"wall": "planks", "concrete": "concrete", "ground": "concrete", "metal": "iron", "steel": "steel", "rust": "rust",
		"furniture": "furniture", "deck": "steel_grate", "grey": "grey_paint", "lead": "lead", "glass": "glass", "beam": "beam",
		"machine": "machine_grey", "olive": "feldgrau", "rail": "iron", "roof": "roof", "planks": "planks", "dirt": "dirt", "salt": "concrete",
		"caliche": "stone", "sand": "dirt", "stairs": "concrete",
	}
	# T-222: the lab's floor and ceilings were the dry-stone wall texture (the "Caliche*" rule): a poured floor and
	# board-formed concrete ceilings over the cut caliche walls
	# T-222: the silo's floor overlaps the lab's by 2 m at the door (z 150..152, same top): the same floor material
	# on both so the overlap shows one surface instead of a flicker between two
	# T-222: the hatch and trench ramps were the procedural "concrete" (a soft noise that smears along a slope)
	mat_rules = [["CalicheFloor", "fl_floor"], ["SiloFloor", "fl_floor"], ["HatchRamp", "fl_floor"], ["TrenchRamp", "fl_floor"], ["LabRoof", "fl_concrete"], ["HatchRoof", "fl_concrete"], ["Salt*", "concrete"], ["Tower_Base*", "concrete"], ["Hull*", "steel"], ["Wing*", "steel"], ["Caliche*", "stone"], ["Berm*", "dirt"], ["Tower*", "iron"], ["Truck*", "feldgrau"], ["Rocket*", "steel"]]
	# T-222: walls of two rooms built on the same line fought on both faces (the lab's north wall F_N under the
	# silo's G_S_W; the hangar's and the motor pool's south walls C_S / D_S over the salt berm Berm_N; the trench
	# walls against the salt slab's cut edge): each mesh
	# keeps its own room's side (the colliders, the navmesh and the table's boxes are untouched)
	visual_adjust = [["G_S_W*", Vector3(0, 0, 0.16), Vector3.ZERO], ["F_N_0", Vector3.ZERO, Vector3(0, 0, -0.16)],
		["F_N_end", Vector3.ZERO, Vector3(0, 0, -0.16)], ["C_S_*", Vector3(0, 0, 0.15), Vector3(0, 0, 0.03)],
		["D_S_*", Vector3(0, 0, 0.15), Vector3(0, 0, 0.03)], ["TrenchWallS", Vector3.ZERO, Vector3(0, 0, 0.02)], ["TrenchWallN", Vector3(0, 0, -0.02), Vector3.ZERO]]
	hide = ["NavBlock*", "Truck*", "Bomber*", "Cage*", "Office*", "Bench*", "Pit*", "Tank*", "Console*", "Rocket*", "Dish*", "Shack*", "Gantry*", "Wing*", "Tower_Mast*", "G_E*", "G_N*", "G_S_E*"]
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
	# over the silo: dressing only, and the shaft itself left open to the sky (T-148); the lab gets a lid of salt too
	box(geo, "Salt_N", Vector3(-72, -0.5, 152), Vector3(-46.3, 0, 200), "salt", false)
	box(geo, "Salt_N2", Vector3(-46.3, -0.5, 196.15), Vector3(-18, 0, 200), "salt", false)
	box(geo, "Salt_Lab", Vector3(-72, -0.5, 112.3), Vector3(-18, 0, 152), "salt", false)
	box(geo, "Salt_LabW", Vector3(-72, -0.5, 100), Vector3(-48.3, 0, 112.3), "salt", false)
	box(geo, "Salt_LabE", Vector3(-41.7, -0.5, 100), Vector3(-18, 0, 112.3), "salt", false)
	_wreck()
	_lakebed()
	_hangar()
	_motorpool()
	_radar()
	_lab()
	_silo()


## The Kranich on its belly: the fuselage interior is the spawn room (the torn hull is the windows, the aft seam
## shut, the open bay forward is the way out), the port wing torn off beside it on the salt.
func _wreck() -> void:
	wall_x("A_S", -36.0, -14 - T * 0.5, 14 + T * 0.5, 0, CEIL_WRECK, [], "steel")
	wall_z("Hull_W", -14.0, -36, -4, 0, CEIL_WRECK, [win(-20, 0)], "steel")
	wall_z("Hull_E", 14.0, -36, -4, 0, CEIL_WRECK, [win(-20, 0)], "steel")
	# the bulkhead: the lake bed door, and at x 10 a plate that the second collapse tears out (U10 §3, T-157:
	# BulkheadPlate below, a gameplay StaticBody the GroomController removes; its NavigationLink is made then)
	wall_x("AB", -4.0, -14 - T * 0.5, 14 + T * 0.5, 0, CEIL_WRECK, [door(0, 0, 2.4), door(10, 0, 2.4)], "steel")
	# the hull's ceiling (dressing), with the bomb bay torn open to the sky over its forward end (T-148)
	box(geo, "HullRoof", Vector3(-14.3, CEIL_WRECK, -36.3), Vector3(14.3, CEIL_WRECK + 0.4, -12.5), "steel", false)
	box(geo, "HullRoofW", Vector3(-14.3, CEIL_WRECK, -12.5), Vector3(-4.5, CEIL_WRECK + 0.4, -3.7), "steel", false)
	box(geo, "HullRoofE", Vector3(4.5, CEIL_WRECK, -12.5), Vector3(14.3, CEIL_WRECK + 0.4, -3.7), "steel", false)
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
	box(geo, "Shack", Vector3(58, 0, 128), Vector3(66, 3.0, 136), "planks")                 # the shack (the radio on its south face)
	# U10 §3 (T-157): the sniper perch: a grated deck round the mast at 16 m with railings (a gap over the ladder);
	# players climb by the TowerLadder, zombies by the climb link (map04c.json climb_links TowerPerch)
	box(geo, "Perch_Deck", Vector3(42.0, 15.9, 117.0), Vector3(48.0, 16.0, 123.0), "deck")
	box(geo, "Perch_RailN", Vector3(42.0, 16.0, 122.92), Vector3(48.0, 17.1, 123.0), "rail")
	box(geo, "Perch_RailE", Vector3(47.92, 16.0, 117.0), Vector3(48.0, 17.1, 123.0), "rail")
	box(geo, "Perch_RailW", Vector3(42.0, 16.0, 117.0), Vector3(42.08, 17.1, 123.0), "rail")
	box(geo, "Perch_RailSW", Vector3(42.0, 16.0, 117.0), Vector3(44.4, 17.1, 117.08), "rail")
	box(geo, "Perch_RailSE", Vector3(45.6, 16.0, 117.0), Vector3(48.0, 17.1, 117.08), "rail")
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
	box(geo, "ShaftWallW_Hi", Vector3(-46.3, LAB_Y + CEIL_CTRL, 150), Vector3(-45.7, 1.0, 196), "concrete", false)
	box(geo, "Console_Burn", Vector3(-60, LAB_Y, 178), Vector3(-56, LAB_Y + 1.1, 179.5), "machine")   # the silo console
	box(geo, "Rocket_Base", Vector3(ROCKET_X - 3.2, LAB_Y, ROCKET_Z - 3.2), Vector3(ROCKET_X + 3.2, LAB_Y + 1.0, ROCKET_Z + 3.2), "steel")
	box(geo, "Gantry_Post", Vector3(ROCKET_X + 4.0, LAB_Y, ROCKET_Z - 0.5), Vector3(ROCKET_X + 5.0, LAB_Y + 28.0, ROCKET_Z + 0.5), "metal")
	for w: Array in windows:
		if str(w[1]) == "G_SILO":
			closet(w[2], float(w[3]))


# ================================================================== dressing + lights (UPDATE 09 §5.4, T-148)

func build_dressing() -> void:
	_r.seed = 4400
	_retex_salt()
	_dress_wreck()
	_dress_lakebed()
	_dress_hangar()
	_dress_motorpool()
	_dress_radar()
	_dress_lab()
	_dress_silo()
	_dress_far()
	label("GROOM LAKE  ·  AAF TEST RANGE  ·  NO NAME YET", Vector3(45, 3.6, 59.66), 180.0, 30)
	label("MOTOR POOL", Vector3(-45, 3.2, 59.7), 180.0, 34)
	label("LANTERN", Vector3(-40, LAB_Y + 3.4, 149.7), 180.0, 40)
	_power_lights()
	_shadow_budget()
	_bake_dressing()


## C4: small dressing casts no shadow (the lib batches per material, shadow flag and cell, and every caster batch is
## drawn again in each shadow pass): only parts with a dimension over SHADOW_MIN_M keep casting (the shell, the
## roofs, the bomber, the trucks, the tower's legs, the rocket's group is kept apart and keeps its own).
const SHADOW_MIN_M: float = 1.8


func _shadow_budget() -> void:
	var off: int = 0
	for n: Node in dress.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or _kept(mi):
			continue
		var s: Vector3 = _xform_to_root(mi).basis.get_scale()
		if maxf(s.x, maxf(s.y, s.z)) < SHADOW_MIN_M:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			off += 1
	print("shadow budget: %d small dressing meshes cast no shadow" % off)


## C4: the lib batches per 22 m x 9 m cell, which split this act's ~45 dressing materials into ~600 batches (every one
## a draw call from the salt, where the whole range is in view). The dressing is baked here first, coarser: one
## ArrayMesh per material, shadow flag and 60 m cell (surface / underground), so the lib's pass only batches the
## geometry boxes. Kept groups (the rocket, the power glows) and particles stay as they are.
const BAKE_CELL: float = 60.0


func _bake_dressing() -> void:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in dress.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or mi.material_override == null or _kept(mi) or mi.mesh.get_surface_count() != 1:
			continue
		if not (mi.mesh is PrimitiveMesh or mi.mesh is ArrayMesh):
			continue
		var xf: Transform3D = _xform_to_root(mi)
		var c: Vector3 = xf.origin
		var cell: Vector3i = Vector3i(floori(c.x / BAKE_CELL), 0 if c.y > -1.5 else -1, floori(c.z / BAKE_CELL))
		if absf(c.x) > 100.0 or c.z < -60.0 or c.z > 220.0:
			cell = Vector3i(999, 0, 0)
		var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, cell]
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
		victims.append(mi)
	var holder: Node3D = Node3D.new()
	holder.name = "DressingBaked"
	holder.set_meta("keep", true)
	dress.add_child(holder)
	var i: int = 0
	for key2: String in groups.keys():
		var g: Dictionary = groups[key2]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Baked_%d" % i
		out.mesh = _commit(g["st"])
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		holder.add_child(out)
		i += 1
	for mi2: MeshInstance3D in victims:
		mi2.get_parent().remove_child(mi2)
		mi2.free()
	print("dressing baked: %d meshes into %d batches" % [victims.size(), i])


## The salt slabs get the playa material (world-space polygons); the closets behind the hangar's and the motor
## pool's windows read as plank lean-tos, the wreck's as the hull's insides.
func _retex_salt() -> void:
	var salt: ShaderMaterial = D.shader_mat("salt_flat.gdshader")
	for n: Node in geo.find_children("Salt*", "", false, false):
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = salt
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = salt
	for n2: Node in geo.find_children("Closet*", "", false, false):
		var p: Vector3 = (n2 as Node3D).position
		var key: String = ""
		if p.y > -1.0 and absf(p.x) <= 18.0 and p.z < 0.0:
			key = "wreck"
		elif p.y > -1.0:
			key = "planks"
		if key != "":
			for mi2: Node in n2.find_children("*", "MeshInstance3D", true, false):
				(mi2 as MeshInstance3D).material_override = Mats.get_mat(key)


# ------------------------------------------------------------------ A: the wreck

func _dress_wreck() -> void:
	D.kranich_shell(dress)
	D.torn_wing(dress)
	D.intakes(dress)
	D.torn_ribs(dress, -17.2, D.wing_le(-17.2) - 0.4, D.wing_te(-17.2) + 0.6, -1.0, func(x: float, z: float) -> float: return D.shell_top(x, z), 31)
	D.torn_ribs(dress, -18.0, -13.8, -30.8, 1.0, func(_x: float, z: float) -> float: return 2.5 * D.naca((-13.6 - z) / 17.4), 37)
	# the black salt: 50 m of burn round the hull, laid north by the wind
	# (the black salt itself is drawn by the salt material: salt_flat.gdshader's scorch slots, T-148)
	D.debris_field(dress, Vector3(0, 0, -24), 58.0, 34.0, 80, 4401,
		[Rect2(Vector2(-14.6, -36.6), Vector2(29.2, 33.0)), Rect2(Vector2(-61, -4.3), Vector2(122, 70))])
	# inside: frames and stringers on the hull walls, ribs over the roof, the bay's ribs across the hole
	for i: int in 13:
		var z: float = -35.0 + 2.5 * float(i)
		if absf(z + 20.0) < 1.2:
			continue
		for sx: float in [-13.78, 13.78]:
			B(Vector3(sx - 0.08, 0, z - 0.09), Vector3(sx + 0.08, CEIL_WRECK, z + 0.09), "steel")
		if z > -12.5 and z < -4.5:
			continue
		B(Vector3(-13.85, CEIL_WRECK - 0.22, z - 0.08), Vector3(13.85, CEIL_WRECK, z + 0.08), "steel")
	for sy: float in [1.1, 2.3, 3.4]:
		for sx2: float in [-13.83, 13.83]:
			B(Vector3(sx2 - 0.04, sy - 0.04, -35.8), Vector3(sx2 + 0.04, sy + 0.04, -21.2), "iron")
			B(Vector3(sx2 - 0.04, sy - 0.04, -18.8), Vector3(sx2 + 0.04, sy + 0.04, -4.3), "iron")
	for bx: float in [-3.0, 0.0, 3.0]:
		Props.strut(dress, Vector3(bx, CEIL_WRECK + 0.3, -12.5), Vector3(bx + _r.randf_range(-0.4, 0.4), D.shell_top(bx, -4.2) - 0.4, -4.1), 0.16, "steel")
	for bz: float in [-11.0, -8.0, -5.5]:
		OB(Vector3(0, CEIL_WRECK + 0.5, bz), Vector3(9.4, 0.18, 0.14), "steel", Vector3(0, 0, _r.randf_range(-6.0, 6.0)))
	# the fallen bomb racks (over their NavBlock bases) with the casings still in them
	for i2: int in 2:
		var rz: float = -28.0 + 8.0 * float(i2)
		for side: float in [-1.0, 1.0]:
			var cx: float = side * 7.5
			B(Vector3(cx - 1.5, 0, rz - 1.0), Vector3(cx + 1.5, 0.12, rz + 1.0), "steel")
			for rx: float in [cx - 1.4, cx + 1.4]:
				B(Vector3(rx - 0.06, 0.12, rz - 1.0), Vector3(rx + 0.06, 0.7, rz + 1.0), "steel")
			CYL(Vector3(cx, 0.4, rz - 0.45), 0.28, 2.6, "lead", Vector3(0, 0, 90))
			CYL(Vector3(cx, 0.4, rz + 0.45), 0.28, 2.6, "lead", Vector3(0, 0, 90))
			_noshadow(CYL(Vector3(cx, 0.4, rz + 0.45), 0.29, 0.05, "nachtglas_dim", Vector3(0, 0, 90)))
	# hanging cable runs and a torn oxygen line, a crew seat on its back, papers
	for cz: float in [-30.0, -22.0, -14.0]:
		Props.cable(dress, Vector3(-11, CEIL_WRECK - 0.1, cz), Vector3(-6, CEIL_WRECK - 0.2, cz + 3.0), 1.4, 0.03, 6, "rubber")
		Props.cable(dress, Vector3(10, CEIL_WRECK - 0.1, cz + 1.0), Vector3(12.5, 1.6, cz + 2.0), 0.4, 0.025, 5, "rubber")
	for ob: Vector3 in [Vector3(-12.6, 0, -33.5), Vector3(-12.2, 0, -33.2), Vector3(12.4, 0, -10.5)]:
		CYL(ob + Vector3(0, 0.6, 0), 0.12, 1.2, "olive_steel")
	OB(Vector3(4.0, 0.25, -31.0), Vector3(0.6, 0.5, 0.7), "leather", Vector3(70, 25, 0))
	for k: int in 9:
		_noshadow(OB(Vector3(_r.randf_range(-11, 11), 0.022, _r.randf_range(-34, -6)), Vector3(0.21, 0.004, 0.3), "paper", Vector3(0, _r.randf_range(0, 360), 0)))
	# the fires on the wreck (static: the wing roots and the torn wing burn all act); smoke columns into the sky
	for fp: Vector3 in [Vector3(-17.6, 0.6, -22), Vector3(-26, 1.5, -26), Vector3(18, D.shell_top(18, -22) - 0.2, -22), Vector3(9.0, D.shell_top(9, -30) - 0.2, -30)]:
		Props.flames(dress, fp, 3.4, 3.2, 44)
		Props.embers(dress, fp + Vector3(0, 0.5, 0), 2.0, 14)
		lamp(fp + Vector3(0, 1.4, 0), FIRE, 2.2, 13.0, 0.35, 1.0)
	Props.smoke(dress, Vector3(-20, 3.0, -24), 4.0, 22.0, 40)
	Props.smoke(dress, Vector3(16, 6.0, -24), 3.0, 20.0, 34)
	Props.embers(dress, Vector3(0, 0.3, -12), 6.0, 20)
	# the moving fire (the GroomController's damage point, made visible): flames, smoke, heat shimmer, the key light
	var fx: Node3D = Node3D.new()
	fx.name = "WreckFireFx"
	fx.set_script(load("res://gravelight/world/map04/wreck_fire_fx.gd"))
	var pts: PackedVector3Array = PackedVector3Array([Vector3(-18, 0, -22), Vector3(18, 0, -22), Vector3(0, 0, -10)])
	fx.set("points", pts)
	fx.set("visual", PackedVector3Array([Vector3(-17.6, 0.4, -21.0), Vector3(18.5, D.shell_top(18.5, -21) - 0.1, -21.0), Vector3(0.0, 0.05, -10.0)]))
	fx.position = Vector3(0.0, 0.05, -10.0)
	Props.flames(fx, Vector3.ZERO, 2.6, 3.6, 46)
	Props.smoke(fx, Vector3(0, 2.0, 0), 1.4, 9.0, 24)
	Props.embers(fx, Vector3(0, 0.6, 0), 1.2, 12)
	var shim: MeshInstance3D = MeshInstance3D.new()
	shim.name = "HeatShimmer"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(4.0, 5.5)
	shim.mesh = q
	shim.position = Vector3(0, 3.0, 0)
	shim.material_override = D.shader_mat("heat_shimmer.gdshader")
	shim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(shim)
	var fl: OmniLight3D = OmniLight3D.new()
	fl.name = "FireKey"
	fl.set_script(load("res://gravelight/world/flicker_light.gd"))
	fl.set("base_energy", 2.6 * LAMP_GAIN)
	fl.set("amount", 0.4)
	fl.set("speed", 9.0)
	fl.set("fire", true)
	fl.light_color = FIRE
	fl.light_energy = 2.6 * LAMP_GAIN
	fl.omni_range = 16.0
	fl.position = Vector3(0, 1.6, 0)
	fl.shadow_enabled = true
	fl.light_volumetric_fog_energy = 1.0
	fl.set_meta("zone", &"A_WRECK")
	fx.add_child(fl)
	extra_root_nodes.append(fx)
	# torn manifest pinned by a casing at the bay (story prop placement is MapRoot's; this is the loose sheet)
	_noshadow(OB(Vector3(-7.0, 0.73, -20.4), Vector3(0.3, 0.004, 0.4), "paper_old", Vector3(0, 18, 0)))


# ------------------------------------------------------------------ B: the lake bed

func _dress_lakebed() -> void:
	# the range markers on their NavBlock posts, numbered; more of them marching off over the berm
	var nums: Array = ["1", "2", "3", "4", "5"]
	for i: int in 5:
		D.range_marker(dress, Vector3(-40.0 + 20.0 * float(i), 0, 30.0), nums[i])
	for j: int in 6:
		D.range_marker(dress, Vector3(-75.0 - 28.0 * float(j), 0, 30.0 + 6.0 * float(j)), "")
		D.range_marker(dress, Vector3(75.0 + 28.0 * float(j), 0, 18.0 - 4.0 * float(j)), "")
	# the impeller core's crater: a rim of thrown salt and a gouge back to where it hit
	for k: int in 10:
		var a: float = TAU * float(k) / 10.0
		var p: Vector3 = Vector3(20, 0, 20) + Vector3(cos(a), 0, sin(a)) * 3.4
		Props.ball(dress, p, Vector3(2.2, 0.7, 1.4), "concrete_floor").rotation.y = -a
	B(Vector3(17.0, 0.0, 17.0), Vector3(23.0, 0.4, 23.0), "dirt")
	var gouge: Material = _track_mat(Color(0.42, 0.36, 0.3, 0.75))
	D.tyre_tracks(dress, [Vector3(6, 0, -2.0), Vector3(12, 0, 7), Vector3(18, 0, 15.5)], 0.9, gouge, 0.02)   # T-222: over the tracks it crosses
	lamp(Vector3(20, 1.2, 17), VIOLET, 1.4, 8.0, 0.15, 0.6)
	# tyre tracks: the range's trucks between the motor pool, the hangar and the wreck
	var tracks: Material = _track_mat(Color(0.5, 0.46, 0.4, 0.5))
	D.tyre_tracks(dress, [Vector3(-45, 0, 59), Vector3(-40, 0, 46), Vector3(-25, 0, 36), Vector3(0, 0, 33), Vector3(25, 0, 38), Vector3(42, 0, 50), Vector3(45, 0, 59)], 1.8, tracks)
	D.tyre_tracks(dress, [Vector3(-45, 0, 59), Vector3(-36, 0, 30), Vector3(-18, 0, 8), Vector3(-6, 0, -2)], 1.8, tracks)
	D.tyre_tracks(dress, [Vector3(45, 0, 59), Vector3(36, 0, 28), Vector3(16, 0, 6), Vector3(6, 0, -2)], 1.6, tracks)
	# the berm: a timber revetment on its inner face, the earth sloping away outside, scrub on the slope
	# (west and east heap earth outside; the north line is the buildings' walls and the south the wreck's ground)
	for b: Array in [[Vector3(-60, 0, -4), Vector3(-60, 0, 60), Vector3(-1, 0, 0), true], [Vector3(60, 0, -4), Vector3(60, 0, 60), Vector3(1, 0, 0), true],
			[Vector3(-20, 0, 60), Vector3(20, 0, 60), Vector3(0, 0, 1), false], [Vector3(-60, 0, -4), Vector3(-14.4, 0, -4), Vector3(0, 0, -1), false],
			[Vector3(14.4, 0, -4), Vector3(60, 0, -4), Vector3(0, 0, -1), false]]:
		_berm(b[0], b[1], b[2], 2.0, bool(b[3]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4413
	for s: int in 60:
		var side: int = s % 4
		var p2: Vector3
		match side:
			0: p2 = Vector3(rng.randf_range(-78, -63), 0, rng.randf_range(-40, 98))
			1: p2 = Vector3(rng.randf_range(63, 80), 0, rng.randf_range(-40, 98))
			2: p2 = Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-48, -38))
			_: p2 = Vector3(rng.randf_range(-18, 18), 0, rng.randf_range(62, 84))
		D.scrub(dress, p2, rng.randf_range(0.6, 1.3), 900 + s)
	# the range flag on the hangar apron (two-ring disc)
	CYL(Vector3(10, 4.0, 64), 0.08, 8.0, "iron")
	B(Vector3(10.1, 6.8, 63.98), Vector3(12.1, 8.0, 64.02), "grey_paint")
	# the lamp posts at the north berm's two gates (the power floods)
	for gx: float in [-47.6, 47.6]:
		CYL(Vector3(gx, 3.0, 59.55), 0.1, 6.0, "beam")
		D.floodlight(dress, Vector3(gx + signf(-gx) * 0.2, 5.9, 59.2), 180.0, 25.0)
	# the dust storm: sweep cards rolling across the salt, the grit round the camera (DustStormFx follows the round)
	var dust: Node3D = Node3D.new()
	dust.name = "DustStormFx"
	dust.set_script(load("res://gravelight/world/map04/dust_storm_fx.gd"))
	var dmat: ShaderMaterial = D.shader_mat("dust_sheet.gdshader", {"amount": 0.0})
	var drng: RandomNumberGenerator = RandomNumberGenerator.new()
	drng.seed = 4421
	for i3: int in 7:
		var sheet: MeshInstance3D = MeshInstance3D.new()
		sheet.name = "Sweep%d" % i3
		var sq: QuadMesh = QuadMesh.new()
		sq.size = Vector2(80.0, 18.0)
		sheet.mesh = sq
		sheet.material_override = dmat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.position = Vector3(-110.0 + 32.0 * float(i3), 8.5, drng.randf_range(-10.0, 110.0))
		sheet.rotation_degrees = Vector3(0, 90.0 + drng.randf_range(-20, 20), 0)
		sheet.visible = false
		dust.add_child(sheet)
	var grit: GPUParticles3D = GPUParticles3D.new()
	grit.name = "Grit"
	grit.amount = 260
	grit.lifetime = 2.5
	grit.emitting = false
	grit.visibility_aabb = AABB(Vector3(-30, -6, -30), Vector3(60, 16, 60))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 4, 18)
	pm.direction = Vector3(1, 0, 0.2)
	pm.spread = 15.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 14.0
	pm.gravity = Vector3(0, -0.3, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.color = Color(0.8, 0.7, 0.55, 0.5)
	grit.process_material = pm
	var gq: QuadMesh = QuadMesh.new()
	gq.size = Vector2(0.5, 0.18)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	gm.vertex_color_use_as_albedo = true
	gm.albedo_color = Color(0.85, 0.75, 0.6, 0.35)
	gq.material = gm
	grit.draw_pass_1 = gq
	grit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.add_child(grit)
	extra_root_nodes.append(dust)


## A berm side: plank revetment and posts on the inner face (within 0.1 m of the wall), and with `slope` the earth
## heaped behind it on the far side (a prism outside, never toward the walkable ground).
func _berm(a: Vector3, b: Vector3, out: Vector3, h: float, slope: bool = true) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	var along: Vector3 = d / length
	var along_z: bool = absf(along.z) > 0.5
	var inner: Vector3 = -out * (T * 0.5 + 0.03)
	OB((a + b) * 0.5 + inner + Vector3(0, h * 0.5, 0), Vector3(0.05, h, length) if along_z else Vector3(length, h, 0.05), "planks")
	var n: int = maxi(1, int(length / 4.0))
	for i: int in n + 1:
		var p: Vector3 = a + along * (length * float(i) / float(n)) + inner * 1.6
		B(p + Vector3(-0.09, 0, -0.09), p + Vector3(0.09, h + 0.15, 0.09), "beam")
	if slope:
		var c: Vector3 = (a + b) * 0.5 + out * (T * 0.5 + 2.4) + Vector3(0, (h + 0.1) * 0.5 - 0.02, 0)
		Props.prism(dress, c, Vector3(4.8, h + 0.1, length + 4.0), "dirt", Vector3(0, 0.0 if along_z else 90.0, 0))


## Tyre tracks and the core's gouge: an opaque strip a shade darker than the crust (alpha cards are unreliable in
## the Compatibility renderer); the colour's alpha only darkens it.
func _track_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.84, 0.8).lerp(Color(c.r, c.g, c.b), c.a)
	m.roughness = 1.0
	return m


# ------------------------------------------------------------------ C: the hangar

func _dress_hangar() -> void:
	B(Vector3(20.15, 0, 60.15), Vector3(69.85, 0.015, 99.85), "floorboards")
	# the wooden hangar: posts round the walls, king-post trusses every 5 m, the pitched shingle roof, the gables
	for z: float in [62.5, 67.5, 72.5, 77.5, 82.5, 87.5, 92.5, 97.5]:
		D.truss(dress, 20.0, 70.0, z, CEIL_HANGAR, 4.0)
		for sx: float in [20.27, 69.73]:
			if absf(z - 70.0) < 1.4 or absf(z - 80.0) < 1.4 or absf(z - 93.0) < 1.6 or absf(z - 72.0) < 1.0 or absf(z - 86.0) < 1.2 or absf(z - 88.0) < 1.0:
				continue
			B(Vector3(sx - 0.12, 0, z - 0.12), Vector3(sx + 0.12, CEIL_HANGAR, z + 0.12), "beam")
	for x: float in [25.0, 35.0, 55.0, 65.0]:
		for wz: float in [60.27, 99.73]:
			if (wz > 99.0 and (absf(x - 30.0) < 1.5 or absf(x - 54.0) < 1.5)):
				continue
			B(Vector3(x - 0.12, 0, wz - 0.12), Vector3(x + 0.12, CEIL_HANGAR, wz + 0.12), "beam")
	var slope: float = rad_to_deg(atan2(4.0, 25.0))
	OB(Vector3(32.5, CEIL_HANGAR + 2.08, 80.0), Vector3(25.8, 0.22, 41.4), "roof", Vector3(0, 0, slope))
	OB(Vector3(57.5, CEIL_HANGAR + 2.08, 80.0), Vector3(25.8, 0.22, 41.4), "roof", Vector3(0, 0, -slope))
	for pz: float in [60.0, 100.0]:
		Props.prism(dress, Vector3(45.0, CEIL_HANGAR + 2.0, pz), Vector3(50.6, 4.0, 0.3), "planks")
	for px: float in [26.0, 32.0, 38.0, 52.0, 58.0, 64.0]:
		var py: float = CEIL_HANGAR + 4.0 * (1.0 - absf(px - 45.0) / 25.0) - 0.2
		B(Vector3(px - 0.1, py - 0.2, 60.2), Vector3(px + 0.1, py, 99.8), "beam")
	B(Vector3(44.85, CEIL_HANGAR + 3.7, 60.2), Vector3(45.15, CEIL_HANGAR + 4.0, 99.8), "beam")
	# the big sliding doors on the south face, shut, the wicket at the real door; their rail
	D.sliding_leaf(dress, Vector3(37.25, 0, 59.78), 12.5, 8.2, 180.0)
	D.sliding_leaf(dress, Vector3(52.75, 0, 59.78), 12.5, 8.2, 180.0)
	B(Vector3(29.0, 8.35, 59.62), Vector3(61.0, 8.55, 59.84), "iron")
	# the bomber on its jacks (fills the Bomber collider 38..52 × 72..92)
	D.bomber(dress, Vector3(45, 0, 82))
	# Hale's glass office (the Office collider) and Dee's supply cage (NavBlock_Cage; the bank's window stays clear)
	D.glass_office(dress, Vector3(22, 0, 92), Vector3(36, 3, 100))
	D.supply_cage(dress, Vector3(62, 0, 92), Vector3(70, 2.4, 100))
	lamp(Vector3(66, 1.6, 96), INCAND, 1.0, 7.0, 0.04, 0.3)            # Dee's lamp in the cage
	lamp(Vector3(29.5, 1.1, 96.1), INCAND, 1.1, 9.0, 0.0, 0.2, true)    # Hale's desk lamp, never off (the hangar's key)
	# the relay object under its tarp: a bell-sized uplink on a cradle, the tarp half pulled back
	B(Vector3(58.5, 0, 64.5), Vector3(61.5, 0.35, 67.5), "olive_steel")
	Props.bell(dress, Vector3(60, 2.0, 66), 1.9, "nachtglas_dim")
	_noshadow(B(Vector3(58.9, 0.35, 64.9), Vector3(61.1, 0.5, 67.1), "nachtglas"))
	for t: Array in [[Vector3(59.2, 1.55, 66.0), Vector3(1.9, 0.05, 3.1), Vector3(0, 0, 48)], [Vector3(58.7, 0.75, 66.0), Vector3(0.06, 1.5, 3.0), Vector3(0, 0, 4)],
			[Vector3(60.8, 2.05, 66.0), Vector3(1.4, 0.05, 2.6), Vector3(0, 0, -20)], [Vector3(61.2, 0.08, 66.0), Vector3(0.6, 0.16, 3.0), Vector3(0, 0, 0)]]:
		OB(t[0], t[1], "canvas", t[2])
	for rp: Vector3 in [Vector3(58.6, 0, 64.6), Vector3(61.4, 0, 67.4)]:
		Props.cable(dress, rp + Vector3(0, 0.1, 0), Vector3(60, 2.1, 66), 0.2, 0.02, 4, "rope")
	lamp(Vector3(60, 2.6, 66), VIOLET, 1.6, 10.0, 0.12, 0.8)
	# the British crate (NavBlock_Crate): planks, battens, the lid ajar, the diamond and the London address
	B(Vector3(22.5, 0, 63.0), Vector3(25.5, 1.3, 65.0), "planks")
	for bx: float in [22.6, 24.0, 25.4]:
		B(Vector3(bx - 0.08, 0, 62.95), Vector3(bx + 0.08, 1.3, 63.0), "board_wood")
	OB(Vector3(24.0, 1.38, 64.1), Vector3(3.1, 0.08, 2.1), "planks", Vector3(-6, 4, 0))
	Props.stencil(dress, Vector3(24.0, 0.85, 62.94), 0.0, "D / LANTERN  ·  LONDON", 28)
	Props.stencil(dress, Vector3(24.0, 0.55, 62.94), 0.0, "CONSIGNEE  MR L. HALE  ·  GROOM LAKE", 16)
	Props.stencil(dress, Vector3(20.3, 2.2, 86.0), 90.0, "U.S. ARMY  ·  LOCALIZED", 24)
	# workbenches (Bench_C1 along the west wall; the honey stands on it), a tool board, the second bench
	Props.workbench(dress, Vector3(22.5, 0, 69.0), 90.0, 5.8, 1.0)
	B(Vector3(20.16, 1.2, 66.4), Vector3(20.22, 2.4, 71.6), "board_wood")
	for k: int in 7:
		B(Vector3(20.22, 1.5 + 0.12 * float(k % 3), 66.8 + 0.7 * float(k)), Vector3(20.3, 1.8 + 0.12 * float(k % 3), 66.9 + 0.7 * float(k)), "iron")
	Props.workbench(dress, Vector3(27.0, 0, 90.0), 0.0, 3.0, 0.8)
	# parts racks along the east wall (clear of the Thompson at z 72 and the ammo box at 88)
	Props.shelves(dress, Vector3(69.6, 0, 76.0), -90.0, 4.0, 2.4, 0.6, 4, 51)
	Props.shelves(dress, Vector3(69.6, 0, 64.5), -90.0, 4.0, 2.4, 0.6, 4, 53)
	for dz: float in [94.5, 95.3]:
		Props.oil_drum(dress, Vector3(57.0, 0, dz), "olive_drab")
	# the burn barrel (Peg's orders go into it) in the north-west corner behind the office
	brazier(Vector3(21.0, 0, 99.0))


# ------------------------------------------------------------------ D: the motor pool

func _dress_motorpool() -> void:
	B(Vector3(-69.85, 0, 60.15), Vector3(-20.15, 0.015, 99.85), "dirt")
	B(Vector3(-20.15, 0, 86.15), Vector3(19.85, 0.015, 99.85), "dirt")
	# the open yard behind a board fence: posts inside the walls, a lean-to carport over the trucks
	for x: float in [-66.0, -62.0, -58.0, -54.0, -50.0, -40.0, -36.0, -32.0, -28.0, -24.0]:
		B(Vector3(x - 0.09, 0, 60.18), Vector3(x + 0.09, CEIL_SHED + 0.2, 60.36), "beam")
	for z: float in [64.0, 68.0, 72.0, 76.0, 84.0, 88.0]:
		B(Vector3(-69.82, 0, z - 0.09), Vector3(-69.66, CEIL_SHED + 0.2, z + 0.09), "beam")
		B(Vector3(-20.34, 0, z - 0.09), Vector3(-20.18, CEIL_SHED + 0.2, z + 0.09), "beam")
	for cp: Vector3 in [Vector3(-61.8, 0, 71.8), Vector3(-56.2, 0, 71.8), Vector3(-39.8, 0, 71.8), Vector3(-34.2, 0, 71.8)]:
		B(cp + Vector3(-0.12, 0, -0.12), cp + Vector3(0.12, 3.15, 0.12), "beam")
	B(Vector3(-63.0, 3.0, 71.65), Vector3(-33.0, 3.3, 71.95), "beam")
	OB(Vector3(-48.0, 3.28, 66.0), Vector3(31.0, 0.12, 12.4), "iron", Vector3(-1.6, 0, 0))
	for rx: float in [-62.0, -56.0, -50.0, -46.0, -40.0, -34.0]:
		Props.strut(dress, Vector3(rx, 3.3, 60.3), Vector3(rx, 3.1, 71.8), 0.16, "beam")
	# the trucks (generic 1940s cargo trucks: the star, ARMY and a number) and what fills their colliders' width
	D.truck(dress, Vector3(-60.4, 0, 68.0), 180.0, "4-7721")
	D.truck(dress, Vector3(-38.3, 0, 68.0), 180.0, "4-7735", false)
	B(Vector3(-58.9, 0, 64.6), Vector3(-56.25, 1.5, 71.4), "canvas")
	for rz: float in [65.4, 67.4, 69.4, 71.0]:
		Props.cable(dress, Vector3(-58.95, 1.5, rz), Vector3(-56.2, 1.5, rz), 0.08, 0.02, 3, "rope")
	for dz: float in [64.9, 65.6, 66.3, 67.0, 70.6, 71.3]:
		for dx: float in [-35.9, -35.2]:
			Props.oil_drum(dress, Vector3(dx, 0, dz), "olive_drab")
	Props.crate(dress, Vector3(-35.5, 0, 68.8), 1.1, 6.0, "")
	Props.crate(dress, Vector3(-35.5, 1.1, 68.8), 0.8, -12.0, "")
	# the fuel dump (Tank_Fuel collider -31..-23 × 92..98): the tank on saddles, the drums, the cans, the sign
	D.fuel_tank(dress, Vector3(-27.0, 0, 96.6), 7.0, 0.95)
	for row: int in 3:
		for col: int in 6:
			Props.oil_drum(dress, Vector3(-30.3 + 1.25 * float(col), 0, 92.5 + 0.7 * float(row)), "red_paint" if (row + col) % 3 == 0 else "rust")
	for dx2: float in [-30.0, -28.5, -27.0]:
		Props.oil_drum(dress, Vector3(dx2, 0, 91.0), "rust")
	for j: int in 6:
		D.jerrycan(dress, Vector3(-24.0 + 0.2 * float(j), 0, 91.6), 90.0)
	CYL(Vector3(-22.6, 1.0, 91.4), 0.04, 2.0, "iron")
	B(Vector3(-23.2, 1.6, 91.38), Vector3(-22.0, 2.2, 91.42), "enamel_white")
	Props.stencil(dress, Vector3(-22.6, 1.9, 91.36), 0.0, "NO SMOKING", 30, Color(0.7, 0.1, 0.08, 0.95))
	# the generator shed (NavBlock_GenShed -70..-58 × 90..98.4): a plank south wall, a half wall east, a tin roof
	B(Vector3(-70.0, 0, 90.0), Vector3(-58.0, 2.6, 90.15), "planks")
	B(Vector3(-58.15, 0, 90.0), Vector3(-58.0, 1.0, 98.4), "planks")
	for pz: float in [90.1, 94.2, 98.3]:
		B(Vector3(-58.15, 0, pz - 0.08), Vector3(-58.0, 2.75, pz + 0.08), "beam")
	OB(Vector3(-64.0, 2.95, 94.2), Vector3(12.4, 0.1, 8.8), "iron", Vector3(4.0, 0, 0))
	D.generator_set(dress, Vector3(-64.5, 0, 94.0))
	Props.cable(dress, Vector3(-64, 2.6, 98.4), Vector3(-45, 3.0, 100), 0.4, 0.04, 8, "rubber")
	Props.bulkhead_lamp(dress, Vector3(-60.0, 2.4, 98.3), 180.0, "bulb_warm")
	lamp(Vector3(-60.0, 2.2, 97.6), INCAND, 1.6, 11.0, 0.05, 0.4, true)
	# the hatch at the north wall: hazard stripes round the opening, the sign
	for k: int in 8:
		var y: float = 0.3 * float(k)
		for hx: float in [-46.85, -43.15]:
			B(Vector3(hx - 0.15, y, 99.8), Vector3(hx + 0.15, y + 0.3, 99.86), "yellow_paint" if k % 2 == 0 else "black_paint")
	for k2: int in 10:
		var xx: float = -46.5 + 0.3 * float(k2)
		B(Vector3(xx - 0.15, 2.4, 99.8), Vector3(xx + 0.15, 2.65, 99.86), "yellow_paint" if k2 % 2 == 0 else "black_paint")
	Props.stencil(dress, Vector3(-45.0, 2.95, 99.79), 0.0, "LAB  ·  AUTHORIZED PERSONNEL", 26)
	# outside the fence (between the buildings, seen from the salt): a third truck and a utility car
	D.truck(dress, Vector3(-9.0, 0, 72.0), 200.0, "4-7748")
	D.utility_car(dress, Vector3(6.0, 0, 70.0), 160.0)


# ------------------------------------------------------------------ E: the radar tower

func _dress_radar() -> void:
	B(Vector3(20.15, 0, 100.15), Vector3(69.85, 0.015, 139.85), "dirt")
	# the lattice tower over its step (the launch points stay on the step's corners), the riser, the dish
	D.lattice_tower(dress, Vector3(45, 1.0, 120), 1.9, 0.9, 15.0, 6, "iron")
	B(Vector3(44.1, 1.0, 119.1), Vector3(45.9, 16.0, 120.9), "steel")
	for y: float in [3.0, 6.0, 9.0, 12.0, 15.0]:
		B(Vector3(44.05, y - 0.06, 119.05), Vector3(45.95, y + 0.06, 120.95), "black_paint")
	# the riser through the perch deck to the dish's yoke (the dish sits high enough to turn over heads on the deck)
	CYL(Vector3(45, 18.6, 120), 0.45, 5.2, "iron")
	# the dish turns once the power is on (U10 §3, T-157: RadarDish rotates this group; kept out of the bake)
	var dish: Node3D = D.dish(dress, Vector3(45, 22.0, 120), 4.0, 2.6, Vector3(0.8, 0.45, -0.4), "olive_drab")  # grey_paint vanished into the dawn sky in the captures
	dish.name = "RadarDish"
	dish.set_meta("keep", true)
	CYL(Vector3(46.2, 23.0, 121.2), 0.05, 10.0, "iron")
	_noshadow(Props.ball(dress, Vector3(46.2, 28.1, 121.2), Vector3(0.28, 0.32, 0.28), "lamp_red_lit"))
	Props.cable(dress, Vector3(45, 16, 120), Vector3(62, 3.0, 132), 1.5, 0.03, 10, "rubber")
	# the shack (Shack collider 58..66 × 128..136): plank walls, the gable roof, the door, a lit window, the aerial
	B(Vector3(58, 0, 128), Vector3(66, 3.0, 136), "planks")
	Props.gable_roof(dress, Vector3(57.6, 3.0, 127.6), Vector3(66.4, 3.0, 136.4), 1.4, true, "roof", false)
	for p: Array in [[Vector3(59.0, 0, 127.94), Vector3(60.2, 2.1, 127.98), "board_wood"], [Vector3(63.0, 1.0, 127.94), Vector3(64.6, 2.0, 127.98), "window_dark"]]:
		B(p[0], p[1], p[2])
	_noshadow(B(Vector3(63.15, 1.1, 127.92), Vector3(64.45, 1.9, 127.95), "bulb_warm"))
	CYL(Vector3(60, 4.5, 130), 0.03, 3.0, "iron")
	CYL(Vector3(65.4, 6.0, 135.4), 0.05, 6.0, "iron")
	Props.sandbags(dress, Vector3(57.6, 0, 128.2), Vector3(57.6, 0, 135.8), 3)
	Props.bulkhead_lamp(dress, Vector3(61.0, 2.6, 127.9), 180.0, "bulb_warm")
	# the rise: rocks and scrub, kept off the lanes (along the berms and round the tower's foot)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4431
	for s: int in 36:
		var p2: Vector3
		match s % 3:
			0: p2 = Vector3(rng.randf_range(21.2, 24.0), 0, rng.randf_range(101, 133))
			1: p2 = Vector3(rng.randf_range(24, 68), 0, rng.randf_range(137.2, 139.2))
			_: p2 = Vector3(rng.randf_range(66.5, 68.8), 0, rng.randf_range(101, 117))
		if s % 4 == 0:
			OB(p2 + Vector3(0, 0.15, 0), Vector3(rng.randf_range(0.4, 1.0), 0.35, rng.randf_range(0.4, 0.9)), "rock", Vector3(0, rng.randf_range(0, 360), rng.randf_range(-8, 8)))
		else:
			D.scrub(dress, p2, rng.randf_range(0.5, 1.0), 1200 + s)
	for b: Array in [[Vector3(20, 0, 140), Vector3(70, 0, 140), Vector3(0, 0, 1)], [Vector3(70, 0, 100), Vector3(70, 0, 140), Vector3(1, 0, 0)]]:
		_berm(b[0], b[1], b[2], 2.0, true)
	# the warning light on the dish mast (red, blinking, no shadow), the shack lamp (the key), the work flood
	lamp(Vector3(46.2, 27.6, 121.2), RED, 2.0, 22.0, 0.6, 0.5, false, 2.2)
	lamp(Vector3(61.0, 2.2, 127.3), INCAND, 1.0, 6.0, 0.05, 0.3, true)    # the key: the shack door lamp (shadowed, short)
	D.floodlight(dress, Vector3(45.0, 6.2, 117.4), 180.0, 30.0)


# ------------------------------------------------------------------ F: the lab

func _dress_lab() -> void:
	# the specimen rooms: framed glass on every jamb, a steel header over each open front, cracked panes in room 2
	for i: int in 3:
		var z0: float = 112.0 + 12.0 * float(i)
		D.glass_front(dress, -58.0, z0 + 0.3, z0 + 3.0, LAB_Y, CEIL_LAB, i == 1)
		D.glass_front(dress, -58.0, z0 + 9.0, z0 + 11.7, LAB_Y, CEIL_LAB, false)
		B(Vector3(-58.2, LAB_Y + CEIL_LAB - 0.35, z0 + 3.0), Vector3(-57.8, LAB_Y + CEIL_LAB, z0 + 9.0), "steel")
		Props.stencil(dress, Vector3(-57.75, LAB_Y + CEIL_LAB - 0.18, z0 + 6.0), -90.0, "SPECIMEN %d" % (i + 1), 26, Color(0.9, 0.9, 0.85, 0.9))
		Props.gurney(dress, Vector3(-64, LAB_Y, z0 + 5.0), 90.0, i != 1)
		Props.cabinet(dress, Vector3(-69.5, LAB_Y, z0 + 9.0), 90.0, 1.2, 1.8, 0.5)
		# the hazmat suits on their hooks, the drain, the room's caged lamp
		for hz: float in [z0 + 2.0, z0 + 3.0]:
			B(Vector3(-69.85, LAB_Y + 1.0, hz - 0.25), Vector3(-69.55, LAB_Y + 1.85, hz + 0.25), "paint:#9a8a3a")
			_noshadow(Props.ball(dress, Vector3(-69.6, LAB_Y + 2.1, hz), Vector3(0.36, 0.42, 0.36), "glass"))
		B(Vector3(-64.4, LAB_Y, z0 + 8.6), Vector3(-63.6, LAB_Y + 0.012, z0 + 9.4), "steel_grate")
		Props.bulkhead_lamp(dress, Vector3(-69.8, LAB_Y + 3.0, z0 + 6.0), -90.0, "bulb_cold")
	# the Nevada stone's pit (room 2): a lead rim, the stone's crystals, the hoist over it
	for r: Array in [[Vector3(-67.0, LAB_Y, 128.0), Vector3(-61.0, LAB_Y + 0.5, 128.4)], [Vector3(-67.0, LAB_Y, 133.6), Vector3(-61.0, LAB_Y + 0.5, 134.0)],
			[Vector3(-67.0, LAB_Y, 128.0), Vector3(-66.6, LAB_Y + 0.5, 134.0)], [Vector3(-61.4, LAB_Y, 128.0), Vector3(-61.0, LAB_Y + 0.5, 134.0)]]:
		B(r[0], r[1], "lead")
	_noshadow(B(Vector3(-66.5, LAB_Y + 0.5, 128.5), Vector3(-61.5, LAB_Y + 1.4, 133.5), "nachtglas"))
	Props.crystal_cluster(dress, Vector3(-64.0, LAB_Y + 0.45, 131.0), 4441, 1.3, "nachtglas_crystal")
	D.pit_crane(dress, Vector3(-64.0, LAB_Y, 131.0), 7.0, 3.6)
	lamp(Vector3(-64, LAB_Y + 2.4, 131), VIOLET, 2.2, 16.0, 0.15, 1.2, true)
	fog("PitGlow", Vector3(-64, LAB_Y + 2.0, 131), Vector3(14, 4.0, 24), 0.05, Color(0.5, 0.35, 0.7), Color(0.08, 0.02, 0.12))
	# the workbench at the hall's head (Bench_Work): the bench, the vice, the notes on the wall, the lamp
	Props.workbench(dress, Vector3(-60.0, LAB_Y, 113.0), 0.0, 4.0, 1.0)
	for k: int in 6:
		_noshadow(OB(Vector3(-61.6 + 0.6 * float(k), LAB_Y + 1.6 + 0.25 * float(k % 2), 112.17), Vector3(0.42, 0.56, 0.01), "paper_old" if k % 2 == 0 else "paper", Vector3(0, 0, _r.randf_range(-6, 6))))
	B(Vector3(-56.6, LAB_Y + 1.0, 112.15), Vector3(-53.6, LAB_Y + 2.6, 112.2), "felt_green")
	Props.stencil(dress, Vector3(-55.1, LAB_Y + 2.1, 112.22), 180.0, "TM-SOL3-002  ·  11 AUG 44  ·  NOT A BOLIDE", 16, Color(0.9, 0.9, 0.85, 0.8))
	Props.cone(dress, Vector3(-58.6, LAB_Y + 1.25, 112.8), 0.16, 0.2, "enamel_green")
	Props.stencil(dress, Vector3(-45.0, LAB_Y + 3.2, 112.2), 0.0, "PROJECT LANTERN  ·  SPECIMEN WING", 30)
	# the hall: tube fittings under the rafters, a cable tray and pipes along the east wall, sample crates
	for i2: int in 4:
		var rz: float = 116.0 + 8.0 * float(i2)
		for tx: float in [-50.0, -30.0]:
			B(Vector3(tx - 1.2, LAB_Y + CEIL_LAB - 0.62, rz - 0.08), Vector3(tx + 1.2, LAB_Y + CEIL_LAB - 0.5, rz + 0.08), "iron")
			_noshadow(B(Vector3(tx - 1.1, LAB_Y + CEIL_LAB - 0.67, rz - 0.04), Vector3(tx + 1.1, LAB_Y + CEIL_LAB - 0.62, rz + 0.04), "bulb_cold"))
	for py: float in [LAB_Y + 3.3, LAB_Y + 3.55]:
		Props.pipe(dress, Vector3(-20.4, py, 113.0), Vector3(-20.4, py, 135.6), 0.06, "iron")
		Props.pipe(dress, Vector3(-20.4, py, 138.4), Vector3(-20.4, py, 149.6), 0.06, "iron")
	B(Vector3(-20.6, LAB_Y + 2.8, 113.0), Vector3(-20.2, LAB_Y + 2.86, 149.6), "steel_grate")
	for c: Vector3 in [Vector3(-22.0, LAB_Y, 116.0), Vector3(-22.0, LAB_Y, 117.2), Vector3(-22.4, LAB_Y + 0.8, 116.6)]:
		Props.crate(dress, c, 0.8, 8.0)


# ------------------------------------------------------------------ G: the silo

func _dress_silo() -> void:
	# the LANTERN rocket (kept whole so the launch fx can lift it) on its launch ring
	var rk: Node3D = Props.group(dress, "Rocket", Vector3(ROCKET_X, LAB_Y + 1.0, ROCKET_Z))
	rk.set_meta("keep", true)
	D.lantern_rocket(rk)
	B(Vector3(ROCKET_X - 3.2, LAB_Y, ROCKET_Z - 3.2), Vector3(ROCKET_X + 3.2, LAB_Y + 1.0, ROCKET_Z + 3.2), "concrete")
	CYL(Vector3(ROCKET_X, LAB_Y + 1.02, ROCKET_Z), 2.7, 0.06, "steel")
	for ha: float in [45.0, 135.0, 225.0, 315.0]:
		var d: Vector3 = Vector3(cos(deg_to_rad(ha)), 0, sin(deg_to_rad(ha)))
		Props.strut(dress, Vector3(ROCKET_X, LAB_Y + 1.0, ROCKET_Z) + d * 3.0, Vector3(ROCKET_X, LAB_Y + 1.9, ROCKET_Z) + d * 2.0, 0.22, "black_paint")
	B(Vector3(ROCKET_X - 1.4, LAB_Y + 0.97, ROCKET_Z - 1.4), Vector3(ROCKET_X + 1.4, LAB_Y + 1.01, ROCKET_Z + 1.4), "steel_grate")
	# the service gantry (over the Gantry_Post collider), its lift cage and swing arms
	D.gantry(dress, Vector3(ROCKET_X + 4.5, LAB_Y, ROCKET_Z), 28.0, Vector3(ROCKET_X, LAB_Y, ROCKET_Z))
	# the shaft's walls as seen (T-148): the G_E / G_N / G_S_E colliders run up to y 30 for the act's kill volume, but
	# their meshes are hidden and the concrete is drawn only to a 1 m parapet at the shaft's mouth, so from the
	# salt the rocket and the gantry rise out of the ground instead of a 30 m slab
	var sc: String = "bunker_concrete"
	B(Vector3(-20.15, LAB_Y, 150.0), Vector3(-19.85, 1.0, 196.0), sc)
	B(Vector3(-70.15, LAB_Y, 195.85), Vector3(-30.8, 1.0, 196.15), sc)
	B(Vector3(-29.2, LAB_Y, 195.85), Vector3(-19.85, 1.0, 196.15), sc)
	B(Vector3(-30.8, LAB_Y, 195.85), Vector3(-29.2, LAB_Y + SILL, 196.15), sc)
	B(Vector3(-30.8, LAB_Y + WTOP, 195.85), Vector3(-29.2, 1.0, 196.15), sc)
	B(Vector3(-34.15, LAB_Y, 150.01), Vector3(-19.85, 1.0, 150.15), sc)   # T-222: the shaft side only (it fought the lab wall F_N)
	B(Vector3(-46.3, LAB_Y + CEIL_CTRL, 149.85), Vector3(-34.15, 1.0, 150.15), sc)
	for rl: Array in [[Vector3(-46.0, 1.0, 150.0), Vector3(-20.0, 1.0, 150.0)], [Vector3(-20.0, 1.0, 150.0), Vector3(-20.0, 1.0, 196.0)],
			[Vector3(-20.0, 1.0, 196.0), Vector3(-46.0, 1.0, 196.0)], [Vector3(-46.0, 1.0, 196.0), Vector3(-46.0, 1.0, 150.0)]]:
		Props.railing(dress, rl[0], rl[1], 1.0, "yellow_paint", 2.0)
	# the shaft: form-board seams up the walls, the silo doors lying open on the salt, floodlights on the rim
	for yi: int in range(-3, 0, 3):
		var y: float = float(yi)
		B(Vector3(-45.7, y, 150.2), Vector3(-45.64, y + 0.08, 195.8), "grime")
		B(Vector3(-20.2, y, 150.2), Vector3(-20.15, y + 0.08, 195.8), "grime")
		B(Vector3(-45.8, y, 195.8), Vector3(-20.2, y + 0.08, 195.85), "grime")
	OB(Vector3(-53.0, 0.9, 173.0), Vector3(12.6, 0.5, 45.0), "olive_steel", Vector3(0, 0, 8))
	OB(Vector3(-13.0, 0.9, 173.0), Vector3(12.6, 0.5, 45.0), "olive_steel", Vector3(0, 0, -8))
	for fpos: Array in [[Vector3(-20.6, 1.6, 160.0), 110.0], [Vector3(-20.6, 1.6, 192.0), 70.0], [Vector3(-45.4, 1.6, 192.0), -70.0]]:
		D.floodlight(dress, fpos[0], float(fpos[1]), 35.0)
	shaft("GantryFlood", Vector3(-21.2, 1.4, 160.5), Vector3(ROCKET_X, LAB_Y + 8.0, ROCKET_Z), SODIUM, 7.0, 45.0, 32.0, 1.2, true)
	# the control room: relay racks on the west wall, the desk with the teletype, the clock, the burn board
	B(Vector3(-69.85, LAB_Y, 150.15), Vector3(-46.15, LAB_Y + 0.015, 195.85), "tile_floor")
	B(Vector3(-69.85, LAB_Y + CEIL_CTRL - 0.03, 150.15), Vector3(-46.15, LAB_Y + CEIL_CTRL, 195.85), "plaster_upper")
	B(Vector3(-45.85, LAB_Y, 150.15), Vector3(-20.15, LAB_Y + 0.015, 195.85), "bunker_concrete")
	for rz: float in [174.0, 176.0, 178.0, 190.0, 192.0]:
		B(Vector3(-69.85, LAB_Y, rz - 0.9), Vector3(-69.2, LAB_Y + 2.2, rz + 0.9), "machine_grey")
		for ly: float in [0.6, 1.2, 1.8]:
			_noshadow(B(Vector3(-69.2, LAB_Y + ly, rz - 0.5), Vector3(-69.18, LAB_Y + ly + 0.06, rz - 0.3), "lamp_green" if int(rz + ly * 10.0) % 3 == 0 else "lamp_amber"))
	Props.table_visual(dress, Vector3(-52.0, LAB_Y, 186.0), 2.4, 1.0, 0.78)
	B(Vector3(-52.6, LAB_Y + 0.78, 185.7), Vector3(-51.6, LAB_Y + 1.1, 186.3), "machine_green")
	Props.chair(dress, Vector3(-52.0, LAB_Y, 187.0), 180.0)
	Props.chair(dress, Vector3(-58.0, LAB_Y, 176.4), 0.0)
	CYL(Vector3(-58.0, LAB_Y + 3.0, 195.83), 0.3, 0.06, "enamel_white", Vector3(90, 0, 0))
	B(Vector3(-63.0, LAB_Y + 1.0, 195.8), Vector3(-60.0, LAB_Y + 2.6, 195.85), "felt_green")
	Props.stencil(dress, Vector3(-61.5, LAB_Y + 2.1, 195.78), 0.0, "BURN  __ · __ · __", 30, Color(0.92, 0.92, 0.88, 0.85))
	for gx: float in [-59.5, -58.3, -57.1]:
		Props.gauge(dress, Vector3(gx, LAB_Y + 1.15, 178.6), 0.0)
	Props.stencil(dress, Vector3(-69.8, LAB_Y + 2.6, 160.0), 90.0, "THE FOURTH UNIT  ·  olive drab, badly", 22)


# ------------------------------------------------------------------ the far world: salt to the horizon, the ridges

func _dress_far() -> void:
	var salt: ShaderMaterial = D.shader_mat("salt_flat.gdshader")
	# the lake bed beyond the play space (four cards round its slabs, so the shaft and the trench stay open)
	for r: Array in [[Vector2(-330, -260), Vector2(330, -50)], [Vector2(-330, 200), Vector2(330, 420)], [Vector2(-330, -50), Vector2(-80, 200)], [Vector2(80, -50), Vector2(330, 200)]]:
		D.ground_card(dress, "SaltFar", r[0], r[1], -0.03, salt, 6)
	# two ridge rings round the lake (inside the 400 m camera far plane from every zone)
	var centre: Vector3 = Vector3(0, 0, 80)
	D.ridge_ring(dress, "RidgeNear", centre, 205.0, 30.0, 6.0, 26.0, 4451,
		D.shader_mat("desert_ridge.gdshader", {"rock": Color(0.36, 0.29, 0.28), "foot": Color(0.22, 0.2, 0.22), "haze": Color(0.36, 0.38, 0.5), "haze_k": 0.005, "top_y": 26.0, "storm_k": 0.0, "storm_col": Color(0.74, 0.65, 0.5)}))
	D.ridge_ring(dress, "RidgeFar", centre, 262.0, 50.0, 18.0, 52.0, 4457,
		D.shader_mat("desert_ridge.gdshader", {"rock": Color(0.26, 0.23, 0.29), "foot": Color(0.2, 0.19, 0.26), "haze": Color(0.42, 0.44, 0.58), "haze_k": 0.006, "haze_max": 0.6, "top_y": 52.0, "storm_k": 0.0, "storm_col": Color(0.74, 0.65, 0.5)}))


# ------------------------------------------------------------------ the power lights (the generator's sweep)

func _power_lights() -> void:
	# the wreck's cabin lamp, the gate floods, the hangar's pendants from the trusses, the motor pool's wall
	# lamps, the tower's work flood and the shack's lamp, the lab's tubes, the silo's work lights
	pendant("A_WRECK", Vector3(0, CEIL_WRECK - 0.6, -20), CEIL_WRECK, "enamel_green", 1.1)
	for gx: float in [-47.4, 47.4]:
		power("B_LAKEBED", Vector3(gx, 5.6, 58.9), 16.0, 1.0, SODIUM)
	for hp: Vector3 in [Vector3(30, 7.4, 70), Vector3(60, 7.4, 70), Vector3(30, 7.4, 87.5), Vector3(60, 7.4, 86)]:
		pendant("C_HANGAR", hp, CEIL_HANGAR, "enamel_green", 1.5)
	for wp: Array in [[Vector3(-58.0, 2.75, 72.6), 180.0], [Vector3(-20.5, 2.75, 78.0), 90.0], [Vector3(0.0, 2.75, 86.5), 180.0], [Vector3(-69.5, 2.75, 80.0), -90.0]]:
		Props.bulkhead_lamp(dress, wp[0], float(wp[1]), "bulb_warm")
		power("D_MOTORPOOL", (wp[0] as Vector3) + Vector3(0, -0.2, 0), 11.0, 0.9, INCAND)
	power("E_RADAR", Vector3(45.0, 6.0, 116.9), 18.0, 1.0, SODIUM)
	power("E_RADAR", Vector3(61.0, 2.4, 127.4), 9.0, 0.8, INCAND)
	for lp: Vector3 in [Vector3(-50, LAB_Y + CEIL_LAB - 0.75, 116), Vector3(-30, LAB_Y + CEIL_LAB - 0.75, 132), Vector3(-50, LAB_Y + CEIL_LAB - 0.75, 140), Vector3(0, 1.4, 137)]:
		power("F_LAB", lp, 12.0, 0.8, Color(0.75, 0.95, 0.85))
	pendant("G_SILO", Vector3(-58, LAB_Y + CEIL_CTRL - 0.6, 160), LAB_Y + CEIL_CTRL, "enamel_green", 1.1)
	pendant("G_SILO", Vector3(-58, LAB_Y + CEIL_CTRL - 0.6, 184), LAB_Y + CEIL_CTRL, "enamel_green", 1.1)
	power("G_SILO", Vector3(-21.4, 1.2, 160.0), 22.0, 1.0, SODIUM)
	power("G_SILO", Vector3(-21.4, 1.2, 192.0), 22.0, 1.0, SODIUM)
	_t222_lights()


## T-222 (the Fernflug lighting pass): the hull, the hangar, the hatch, the trench, the lab and the silo were black
## inside (frame means 3-20 of 255). Every added light is a fixture you can see and casts no shadow: the range's
## battery emergency lamps (caged bulkheads, always on, dim, warm), the lab's specimen-room cages lit on the power
## (they were drawn but gave no light), more wall lamps down the hatch ramp, along the trench and in the silo, two
## more pendants and two floods on the cannibalized bomber in the hangar. Lights and fixtures only.
const T222_EMERGENCY: Array = [
	# [pos on the wall face, yaw the lamp faces (0 = -Z, -90 = +X)]
	[Vector3(-13.85, 3.0, -30.0), -90.0], [Vector3(-13.85, 3.0, -12.0), -90.0], [Vector3(13.85, 3.0, -30.0), 90.0], [Vector3(13.85, 3.0, -12.0), 90.0],   # the hull
	[Vector3(20.15, 3.2, 66.0), -90.0], [Vector3(20.15, 3.2, 84.0), -90.0], [Vector3(69.85, 3.2, 70.0), 90.0], [Vector3(69.85, 3.2, 86.0), 90.0],   # the hangar
	[Vector3(-60.0, 2.6, 60.15), 180.0], [Vector3(-30.0, 2.6, 60.15), 180.0], [Vector3(-30.0, 2.6, 99.85), 0.0], [Vector3(-10.0, 2.6, 86.15), 180.0],   # the motor pool
	[Vector3(10.0, 2.6, 86.15), 180.0],
	[Vector3(-47.85, 0.6, 103.0), -90.0], [Vector3(-42.15, -2.6, 109.0), 90.0],   # the hatch ramp
	[Vector3(-16.0, LAB_Y + 2.4, 134.15), 180.0],   # the trench's foot
	[Vector3(-20.15, LAB_Y + 2.8, 120.0), 90.0], [Vector3(-20.15, LAB_Y + 2.8, 146.0), 90.0], [Vector3(-53.0, LAB_Y + 2.8, 112.15), 180.0],   # the lab hall
	[Vector3(-69.85, LAB_Y + 2.8, 156.0), -90.0], [Vector3(-69.85, LAB_Y + 2.8, 178.0), -90.0],   # the control room
	[Vector3(-7.0, 3.0, -35.85), 180.0], [Vector3(7.0, 3.0, -35.85), 180.0], [Vector3(-7.0, 3.0, -4.15), 0.0],   # the hull's ends
	[Vector3(42.0, 4.2, 59.99), 0.0], [Vector3(48.0, 4.2, 59.99), 0.0], [Vector3(19.85, 3.4, 90.0), 90.0],   # outside: the hangar's doors
	[Vector3(-48.5, 2.9, 59.99), 0.0], [Vector3(-41.5, 2.9, 59.99), 0.0],   # outside: the motor pool's door
]


func _t222_lights() -> void:
	for e: Array in T222_EMERGENCY:
		var p: Vector3 = e[0]
		var yaw: float = float(e[1])
		Props.bulkhead_lamp(dress, p, yaw, "bulb_warm")
		var out: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -1)
		lamp(p + out * 0.35, INCAND, 1.1, 10.0, 0.05, 0.0, false, 3.0)   # no volumetric fog share (cheaper, no haze halo on every wall lamp)
	# the hangar: two more pendants over the bomber's nose and tail, two floods on the bomber from the side walls
	for hp: Vector3 in [Vector3(45, 7.4, 64), Vector3(45, 7.4, 96), Vector3(26, 7.4, 78), Vector3(64, 7.4, 78), Vector3(54, 7.4, 94)]:
		pendant("C_HANGAR", hp, CEIL_HANGAR, "enamel_green", 1.5)
	for hf: Array in [[Vector3(20.4, 6.5, 76.0), -90.0], [Vector3(69.6, 6.5, 76.0), 90.0]]:
		var fb: Vector3 = GenDetail.lamp_fixture(dress, hf[0], "flood", float(hf[1]), 0.0, "machine_grey", "bulb_warm")
		power("C_HANGAR", fb, 12.0, 0.8, SODIUM, false, {"dir": (Vector3(45, 1.5, 82) - fb).normalized(), "energy": 2.6, "range": 40.0, "angle": 28.0, "color": SODIUM})
	# the lab: the specimen rooms' caged lamps light on the power; two more tubes over the hall's ends
	for i: int in 3:
		power("F_LAB", Vector3(-69.4, LAB_Y + 3.0, 112.0 + 12.0 * float(i) + 6.0), 11.0, 1.2, Color(0.75, 0.95, 0.85))
	for lp: Vector3 in [Vector3(-30, LAB_Y + CEIL_LAB - 0.75, 116), Vector3(-30, LAB_Y + CEIL_LAB - 0.75, 146), Vector3(-50, LAB_Y + CEIL_LAB - 0.75, 128),
			Vector3(-40, LAB_Y + CEIL_LAB - 0.75, 122), Vector3(-40, LAB_Y + CEIL_LAB - 0.75, 138), Vector3(-24, LAB_Y + CEIL_LAB - 0.75, 126),
			Vector3(-24, LAB_Y + CEIL_LAB - 0.75, 142)]:
		_noshadow(B(lp + Vector3(-0.9, 0.35, -0.08), lp + Vector3(0.9, 0.45, 0.08), "neon_off"))
		_noshadow(Props.block(G("F_LAB"), lp + Vector3(-0.85, 0.3, -0.05), lp + Vector3(0.85, 0.35, 0.05), "bulb_cold"))
		power("F_LAB", lp, 12.0, 0.8, Color(0.75, 0.95, 0.85))
	# the silo door: a lamp over it on the lab side (always on, it is where the hall leads)
	Props.bulkhead_lamp(dress, Vector3(-40.0, LAB_Y + 3.3, 149.85), 0.0, "bulb_warm")
	lamp(Vector3(-40.0, LAB_Y + 3.3, 149.5), INCAND, 1.0, 9.0, 0.03, 0.15, false, 3.0)
	# the hatch ramp and the trench: wall lamps on the power sweep
	for wl: Array in [[Vector3(-42.15, 1.4, 102.0), 90.0], [Vector3(-47.85, -1.6, 107.0), -90.0], [Vector3(-42.15, -3.6, 111.0), 90.0]]:
		power("F_LAB", GenDetail.lamp_fixture(dress, wl[0], "wall", float(wl[1]), 0.0, "black_paint", "bulb_warm"), 8.0, 0.8, INCAND)
	for tx: float in [-8.0, 4.0, 16.0]:
		var ty: float = LAB_Y + (tx + 20.0) / 40.0 * absf(LAB_Y) + 1.7
		power("F_LAB", GenDetail.lamp_fixture(dress, Vector3(tx, ty, 134.15), "wall", 180.0, 0.0, "black_paint", "bulb_warm"), 9.0, 0.8, INCAND)
	pendant("G_SILO", Vector3(-58, LAB_Y + CEIL_CTRL - 0.6, 172), LAB_Y + CEIL_CTRL, "enamel_green", 1.1)   # the console's own lamp
	# the silo: wall lamps on the control room's shaft side
	for sz: float in [158.0, 176.0, 194.0]:
		power("G_SILO", GenDetail.lamp_fixture(dress, Vector3(-45.85, LAB_Y + 3.0, sz), "wall", -90.0, 0.0, "black_paint", "bulb_warm"), 12.0, 1.0, SODIUM)


## The blue hour: the desert sky shader replaces the lib's procedural sky, the sun sits just over the eastern
## ridge (low, rose-gold, the lake bed's one shadowed key), the fog thins to a pale lavender haze that the sky
## mostly ignores (fog_sky_affect low, raised by DustStormFx during a storm). Then every light gets its zone meta
## (from the zone boxes) and the shadowed lights per zone are counted against the C4 cap.
func build_lights() -> void:
	super.build_lights()
	var glow: Vector3 = Vector3(0.97, 0.0, 0.22).normalized()
	var sun_dir: Vector3 = (glow + Vector3(0, 0.11, 0)).normalized()
	var sun: DirectionalLight3D = map_root.get_node_or_null("Moon") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(1.0, 0.76, 0.6)
		sun.light_energy = 1.25
		sun.directional_shadow_max_distance = 80.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.transform = Transform3D(Basis.looking_at(-sun_dir, Vector3.UP), Vector3(0, 50, 0))
		sun.set_meta("zone", &"B_LAKEBED")
	var we: WorldEnvironment = map_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.shader = load(D.SH + "desert_sky.gdshader") as Shader
		sm.set_shader_parameter("glow_dir", Vector3(glow.x, 0.06, glow.z))
		sm.set_shader_parameter("exposure", 0.62)
		env.sky.sky_material = sm
		env.fog_light_color = Color(0.6, 0.62, 0.72)
		env.fog_density = 0.0028
		env.fog_sky_affect = 0.12
		env.volumetric_fog_density = 0.005
		env.volumetric_fog_albedo = Color(0.82, 0.84, 0.92)
		env.volumetric_fog_emission = Color(0.03, 0.035, 0.05)
		env.ambient_light_color = Color(0.5, 0.56, 0.74)
		env.ambient_light_energy = 0.8
		env.adjustment_saturation = 0.95
	_zone_meta_and_count()
	print("  T-222: %d small lights fade with distance" % fade_small_lights())


func _zone_of(p: Vector3) -> StringName:
	for zb: Array in zone_boxes:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		if p.x >= lo.x and p.x <= hi.x and p.y >= lo.y - 1.0 and p.y <= hi.y + 6.0 and p.z >= lo.z and p.z <= hi.z:
			return StringName(str(zb[0]))
	var best: String = start_zone
	var bd: float = INF
	for zb2: Array in zone_boxes:
		var c: Vector3 = ((zb2[1] as Vector3) + (zb2[2] as Vector3)) * 0.5
		var d: float = c.distance_to(p)
		if d < bd:
			bd = d
			best = str(zb2[0])
	return StringName(best)


func _zone_meta_and_count() -> void:
	var shadowed: Dictionary = {}
	for n: Node in map_root.find_children("*", "Light3D", true, false):
		var l: Light3D = n as Light3D
		if not l.has_meta("zone"):
			var p: Vector3 = _xform_to_root(l).origin
			l.set_meta("zone", _zone_of(p))
		if l.shadow_enabled and not (l is DirectionalLight3D):
			var z: String = str(l.get_meta("zone"))
			shadowed[z] = int(shadowed.get(z, 0)) + 1
	print("shadowed lights per zone: ", shadowed)
	for z2: String in shadowed.keys():
		if int(shadowed[z2]) > 6:
			push_error("gen_map04c: %s has %d shadowed lights (C4 cap 6)" % [z2, int(shadowed[z2])])


func build_gameplay_extra() -> void:
	_node("res://gravelight/maps/map04_fernflug/act_controller.gd", "ActController", {}, Vector3.ZERO)
	_node("res://gravelight/world/map04/groom_controller.gd", "GroomController", {}, Vector3.ZERO)
	# U10 §3 (T-157): the bulkhead plate the second wreck collapse tears out (fills the AB wall's x 10 opening)
	box(gameplay, "BulkheadPlate", Vector3(8.8, 0, -4.0 - T * 0.5), Vector3(11.2, 2.4, -4.0 + T * 0.5), "steel")
	# U10 §3: the radar's controller at the dish (turns it, pings the minimap when powered)
	_node("res://gravelight/world/map04/radar_dish.gd", "RadarController", {}, Vector3(45, 22.0, 120))
	# U10 §3: the radar tower's ladder, foot and top (the sniper perch on the 16 m deck)
	_node("res://gravelight/world/map04/tower_ladder.gd", "TowerLadder_Foot", {"down": false, "to_pos": Vector3(45.0, 16.05, 118.1)}, Vector3(45.0, 1.0, 116.7), 180.0)
	_node("res://gravelight/world/map04/tower_ladder.gd", "TowerLadder_Top", {"down": true, "to_pos": Vector3(45.0, 0.05, 116.2)}, Vector3(45.0, 16.0, 117.6), 180.0)
	# U10 §3: the jukebox in the hangar's break corner (by the bench), plays our own tune once the power is on
	_node("res://gravelight/world/map04/jukebox.gd", "Jukebox", {}, Vector3(20.55, 0, 76.0), -90.0)
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
	# T-219: yaw 180 at z 113.5 (was 0 at 114.2: the node is the bench's front edge and the bench runs to its local +Z,
	# so it pointed its tools and parts 0.9 m north of Bench_Work, in the air, and showed the hall its back; now its
	# back edge is Bench_Work's north edge and the parts lie on the bench)
	_node("res://gravelight/world/workbench.gd", "Workbench", {"buildable_id": &"lodestone"}, Vector3(-60.0, LAB_Y, 113.5), 180.0)
	# the story objects: Dee's radio on the cage's counter, the radar shack's radio, the impeller core on the salt,
	# the hangar cradle (Hale's hatch: Peg's choice) and the rocket's cradle, the silo console, Dee's cage items
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map04_kuendigung.json", "res://data/gravelight/quests/map04c_cage.json"]))   # T-115: the egg's Act III steps, Dee's yard rule
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
