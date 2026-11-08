extends "res://gravelight/tools_src/gen_map04_lib.gd"
## Generates Map 4 Act II "der Kranich, in flight" (UPDATE 07, docs/MAP4_FERNFLUG.md §4): the inside of a flying
## wing the size of a street, at night, over the Atlantic. Seven zones on the in-plane ladder 750 → 1000 → 1250
## → 1500 (the cockpit's two doors are one link group), the aft bomb bay with its six racks, the centre body with
## the galley (the Crucible bolted to its deck, the aux bus = the power), the two wing crawlspaces with their
## breach panels, the port engine room (the Bordwart's arena), the gunner blisters (the climbers' way in and the
## London window), the cockpit with the autopilot (the act's exfil). Far below the deck, a lake-bed diorama the
## crash cutscene films (`fx: crash` slides the WingDiorama). Source of truth.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map04b.gd
##
## Frame: +Z forward (the nose), aft at z = 0, +X starboard, y up; the deck at y = 0.
## Zone plan (x, z):  A_BOMBENSCHACHT -9..9 × 0..24 · B_MITTELRUMPF -9..9 × 24..54 · C_FLUEGEL_L -52..-9 × 28..46
## · C_FLUEGEL_R 9..52 × 28..46 · D_TRIEBWERK -78..-52 × 24..58 (+ the port walkway -52..-22 × 50..58)
## · E_KANZEL 52..78 × 24..58 (+ the starboard walkway 22..52 × 50..58) · F_COCKPIT -22..22 × 54..74.

const CEIL_BAY: float = 4.6
const CEIL_BODY: float = 3.6
const CEIL_WING: float = 2.2
const CEIL_ROOM: float = 4.8
const DIO_Y: float = -186.0   # the lake-bed diorama's ground
const Detail = preload("res://gravelight/tools_src/detail_map04b.gd")
## UPDATE 10 §3 (T-156): the act's set-piece data (map04b.json "flight": wing_walk, turbulence_tilt, decompression)
var flight_cfg: Dictionary = {}
var wing_box_index: int = -1
## T-147: geometry whose mesh the shell replaces (colliders kept): every wall, the lids, the deck, the old rib posts,
## the flight-deck glass box, the spars (dressing only)
const SHELL_HIDDEN: Array = ["A_S*", "A_W*", "A_E*", "AB_*", "B_W*", "B_E*", "CL_*", "CR_*", "D_S*", "D_W*", "D_E*", "D_N*", "DW_S*",
	"E_S*", "E_E*", "E_W*", "E_N*", "EW_S*", "F_W*", "F_E*", "F_S*", "BayRoof", "BodyRoof", "WingRoof*", "TriebwerkRoof", "WalkwayRoof*",
	"KanzelRoof", "CockpitRoof", "Deck", "CockpitGlass", "Spar*", "Rib*"]
## The shell's rooms: [GLB folder, zone, frame offset, frame pitch, visibility range m] (KranichShell; the offsets put the
## skin shader's rivet rows on each room's frames, tools_src/blender/world/kranich_shell.py)
const SHELL_ROOMS: Array = [
	["kranich_bay", "A_BOMBENSCHACHT", 0.75, 1.5, 95.0], ["kranich_body", "B_MITTELRUMPF", 0.75, 1.5, 95.0],
	["kranich_wing_l", "C_FLUEGEL_L", -9.0, 4.0 / 3.0, 95.0], ["kranich_wing_r", "C_FLUEGEL_R", 9.0, 4.0 / 3.0, 95.0],
	["kranich_nacelle", "D_TRIEBWERK", 0.5, 1.5, 95.0], ["kranich_kanzel", "E_KANZEL", 0.5, 1.5, 95.0],
	["kranich_cockpit", "F_COCKPIT", 0.25, 1.5, 95.0]]


func setup_tables() -> void:
	out_path = "res://gravelight/maps/map04_fernflug/map04b.tscn"
	root_name = "Map04bKranich"
	map_id = "map04b_kranich"
	display_name = "Fernflug — Act II: der Kranich"
	start_zone = "A_BOMBENSCHACHT"
	intro_text = "DER KRANICH\nsomewhere over the North Sea, 03:40"
	json_table = "map04b"
	zone_bits = {"A_BOMBENSCHACHT": 1, "B_MITTELRUMPF": 2, "C_FLUEGEL_L": 3, "C_FLUEGEL_R": 4, "D_TRIEBWERK": 5, "E_KANZEL": 6, "F_COCKPIT": 7}
	adj = {"A_BOMBENSCHACHT": ["B_MITTELRUMPF"], "B_MITTELRUMPF": ["A_BOMBENSCHACHT", "C_FLUEGEL_L", "C_FLUEGEL_R"],
		"C_FLUEGEL_L": ["B_MITTELRUMPF", "D_TRIEBWERK"], "C_FLUEGEL_R": ["B_MITTELRUMPF", "E_KANZEL"],
		"D_TRIEBWERK": ["C_FLUEGEL_L", "F_COCKPIT"], "E_KANZEL": ["C_FLUEGEL_R", "F_COCKPIT"], "F_COCKPIT": ["D_TRIEBWERK", "E_KANZEL"]}
	windows = [
		["W_A_L", "A_BOMBENSCHACHT", Vector3(-9, 0, 12), 90.0], ["W_A_R", "A_BOMBENSCHACHT", Vector3(9, 0, 12), -90.0],
		["W_B_L", "B_MITTELRUMPF", Vector3(-9, 0, 48), 90.0], ["W_B_R", "B_MITTELRUMPF", Vector3(9, 0, 48), -90.0],
		["W_CL_S", "C_FLUEGEL_L", Vector3(-30, 0, 28), 0.0], ["W_CR_S", "C_FLUEGEL_R", Vector3(30, 0, 28), 0.0],
		["W_D_W", "D_TRIEBWERK", Vector3(-78, 0, 30), 90.0],
	]
	zone_boxes = [
		["A_BOMBENSCHACHT", Vector3(-9, -1, 0), Vector3(9, 6, 24)],
		["B_MITTELRUMPF", Vector3(-9, -1, 24), Vector3(9, 6, 54)],
		["C_FLUEGEL_L", Vector3(-52, -1, 28), Vector3(-9, 3.0, 46)],   # T-156: stops under the wing walk's own box
		["C_FLUEGEL_R", Vector3(9, -1, 28), Vector3(52, 4, 46)],
		["D_TRIEBWERK", Vector3(-78, -1, 24), Vector3(-52, 6, 58)],
		["D_TRIEBWERK", Vector3(-52, -1, 50), Vector3(-22, 4, 58)],   # the port walkway to the cockpit
		["E_KANZEL", Vector3(52, -1, 24), Vector3(78, 6, 58)],
		["E_KANZEL", Vector3(22, -1, 50), Vector3(52, 4, 58)],        # the starboard walkway
		["F_COCKPIT", Vector3(-22, -1, 54), Vector3(22, 6, 74)],
	]
	for w: Array in windows:
		zone_boxes.append(closet_box(str(w[1]), w[2], float(w[3])))
	# T-156: the wing walk's catwalk (deck_y on stanchions) is its own nav island in C_FLUEGEL_L's layer (Nav_WingRails)
	flight_cfg = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/map04b.json")) as Dictionary).get("flight", {})
	zone_boxes.append(["C_FLUEGEL_L", Vector3(-118, 3.0, 16.5), Vector3(-38, 5.0, 46.0)])
	wing_box_index = zone_boxes.size() - 1
	links = [
		[Vector3(0, 0, 23.6), Vector3(0, 0, 24.4), "B_MITTELRUMPF"],
		[Vector3(-8.6, 0, 36), Vector3(-9.4, 0, 36), "C_FLUEGEL_L"],
		[Vector3(8.6, 0, 36), Vector3(9.4, 0, 36), "C_FLUEGEL_R"],
		[Vector3(-51.6, 0, 36), Vector3(-52.4, 0, 36), "D_TRIEBWERK"],
		[Vector3(51.6, 0, 36), Vector3(52.4, 0, 36), "E_KANZEL"],
		[Vector3(-52.4, 0, 54), Vector3(-51.6, 0, 54), "D_TRIEBWERK"],   # the engine room's corner into the walkway
		[Vector3(52.4, 0, 54), Vector3(51.6, 0, 54), "E_KANZEL"],
		[Vector3(-22.4, 0, 56), Vector3(-21.6, 0, 56), "F_COCKPIT"],
		[Vector3(22.4, 0, 56), Vector3(21.6, 0, 56), "F_COCKPIT"],
	]
	buys = [
		# T-219: every yaw here turned 180 (they faced the wall they hang on: the act was authored with the yaw sign
		# flipped; local -Z is the front, yaw 90 faces -X)
		["kar98k", Vector3(-8.83, 1.5, 6.0), -90.0], ["mp40", Vector3(8.83, 1.5, 30.0), 90.0],
		["thompson", Vector3(-30.0, 1.5, 45.83), 0.0], ["stg44", Vector3(30.0, 1.5, 45.83), 0.0],
		["bar", Vector3(66.0, 1.5, 57.83), 0.0],
	]
	doors = [
		["Door_Mittelrumpf", "door_mittelrumpf", "B_MITTELRUMPF", [], "", 750, "the centre body", Vector3(0, 0, 24), 0.0, 2.0, false],
		["Door_FluegelL", "door_fluegel_l", "C_FLUEGEL_L", [], "", 1000, "the port wing", Vector3(-9, 0, 36), 90.0, 2.0, false],
		["Door_FluegelR", "door_fluegel_r", "C_FLUEGEL_R", [], "", 1000, "the starboard wing", Vector3(9, 0, 36), 90.0, 2.0, false],
		["Door_Triebwerk", "door_triebwerk", "D_TRIEBWERK", [], "", 1250, "the port engine room", Vector3(-52, 0, 36), 90.0, 2.0, false],
		["Door_Kanzel", "door_kanzel", "E_KANZEL", [], "", 1250, "the gun blisters", Vector3(52, 0, 36), 90.0, 2.0, false],
		["Door_CockpitL", "door_cockpit", "F_COCKPIT", [], "cockpit", 1500, "the flight deck", Vector3(-22, 0, 56), 90.0, 2.0, true],
		["Door_CockpitR", "door_cockpit", "F_COCKPIT", [], "cockpit", 1500, "the flight deck", Vector3(22, 0, 56), 90.0, 2.0, true],
	]
	ammo_boxes = [
		# T-219: turned 180 (they faced their wall; the nav blocks are the same for +-90)
		["Bay", Vector3(-8.48, 0, 20.0), -90.0], ["Galley", Vector3(8.48, 0, 50.0), 90.0],
		["Triebwerk", Vector3(-77.48, 0, 44.0), -90.0], ["Kanzel", Vector3(77.48, 0, 44.0), 90.0],
	]
	grounds = [
		["A_BOMBENSCHACHT", Vector3(0, 0, 2), 1],
		["B_MITTELRUMPF", Vector3(0, 0, 40), 1],
		["D_TRIEBWERK", Vector3(-70, 0, 46), 1],
	]
	# the blister rims: the climbers' way in (E_KANZEL has no windows; its spawns are these)
	catwalks = [["E_KANZEL", Vector3(56, 0, 26), true], ["E_KANZEL", Vector3(62, 0, 26), true], ["E_KANZEL", Vector3(68, 0, 26), true], ["E_KANZEL", Vector3(74, 0, 26), true]]
	perks = [
		# T-219: every machine but Ledger Lager turned 180 (they showed the room their backs)
		["second_wind", Vector3(6.0, 0, 22.8), 0.0],
		["skyhook_sekt", Vector3(-7.8, 0, 30.0), -90.0], ["trigger_tonic", Vector3(7.8, 0, 33.6), 90.0],
		["ironhide_stout", Vector3(-24.0, 0, 44.6), 0.0], ["marathon_malt", Vector3(24.0, 0, 44.6), 0.0],
		["blastproof_bock", Vector3(-60.0, 0, 25.4), 180.0], ["hawkeye_brandy", Vector3(56.0, 0, 56.6), 0.0],
		["packmule_porter", Vector3(6.0, 0, 72.6), 0.0],
		# Ledger Lager (T-141): on the forward bulkhead of the centre body, 5 m port of the Bordkasse (bank.json)
		["ledger_lager", Vector3(-5.0, 0, 53.45), 0.0],
	]
	crates = [["Galley", Vector3(-6.0, 0, 50.0), 90.0, true, [Vector3(-6, 0, 47), Vector3(-6, 0, 44), Vector3(0, 0, 44)]],
		# T-156 (THE_BAR row 25): a second spot, the gun blisters' east wall: the drummer walks the crate across the wing
		# T-219: yaw 90 (was -90: it faced the blister wall)
		["Kanzel", Vector3(76.9, 0, 33.0), 90.0, false, [Vector3(74, 0, 33), Vector3(70, 0, 33), Vector3(66, 0, 36)]]]
	player_spawns = [[Vector3(-2, 0, 8), 0.0], [Vector3(2, 0, 8), 0.0], [Vector3(-2, 0, 11), 0.0], [Vector3(2, 0, 11), 0.0]]
	power_switch = {"name": "AuxBus", "label": "the auxiliary bus", "pos": Vector3(8.7, 0, 42.0), "yaw": -90.0,
		"zone_order": ["B_MITTELRUMPF", "A_BOMBENSCHACHT", "C_FLUEGEL_L", "C_FLUEGEL_R", "D_TRIEBWERK", "E_KANZEL", "F_COCKPIT"]}
	# T-175: yaw -90 (it was 90: the machine faced the port hull 3 m away and showed the body its back, its violet key
	# lamp lighting the back plate); now it faces the centre body and the walkway to the wing door runs behind it
	crucible = {"pos": Vector3(-6.0, 0, 34.0), "yaw": -90.0, "needs_power": true}
	armorers_bench = []
	burst_points = [Vector3(0, 0, 40), Vector3(0, 0, 12), Vector3(0, 0, 50)]
	traps = []
	mat_map = {
		"wall": "steel", "concrete": "concrete", "ground": "steel_grate", "metal": "iron", "steel": "steel", "rust": "rust",
		"furniture": "furniture", "deck": "steel_grate", "grey": "grey_paint", "lead": "lead", "glass": "glass", "beam": "beam",
		"machine": "machine_grey", "olive": "feldgrau", "rail": "iron", "roof": "steel", "planks": "planks", "dirt": "dirt", "salt": "concrete",
	}
	mat_rules = [["Deck*", "steel_grate"], ["Rib*", "iron"], ["Spar*", "iron"], ["Rack*", "iron"], ["Hull*", "steel"], ["Salt*", "concrete"],
		["Closet*", "grey_paint"]]
	hide = ["NavBlock*", "Rack*", "Seat*", "Bunk*", "Station*", "Core*", "Kettle*", "Dio*", "Salt*", "Hangar*", "Flag*"]
	# T-147: the shell (KranichShell, the Blender-built frames and skin) is what you see; the flat walls, lids, the deck,
	# the old rib posts and the glass box keep their colliders (the navmesh is baked from them) and lose their meshes
	hide.append_array(SHELL_HIDDEN)
	hide.append("WingRail*")   # T-156: the catwalk's rails are colliders; the dressing draws the stanchions and the tether tube
	sky_top = Color(0.004, 0.005, 0.012)
	sky_horizon = Color(0.03, 0.035, 0.06)
	ambient = Color(0.3, 0.2, 0.2)
	fog_color = Color(0.06, 0.05, 0.06)
	moon_rot = Vector3(-27, -27, 0)   # the moon high ahead to port: in the flight deck's glass and its brow (T-147)


# ================================================================== geometry

func build_geometry() -> void:
	# the deck under everything the squad can walk, the hull skin as walls, roofs as non-colliding lids
	box(geo, "Deck", Vector3(-80, -0.5, -2), Vector3(80, 0, 76), "deck")
	_bay()
	_body()
	_wing(-1.0)
	_wing(1.0)
	_triebwerk()
	_kanzel()
	_cockpit()
	_diorama()
	_wing_walk()


func _bay() -> void:
	# the aft bay: the closed ramp seam (aft), the hatches in the sides, the racks in two rows
	wall_x("A_S", 0.0, -9 - T * 0.5, 9 + T * 0.5, 0, CEIL_BAY, [], "wall")
	wall_z("A_W", -9.0, 0, 24, 0, CEIL_BAY, [win(12, 0)], "wall")
	wall_z("A_E", 9.0, 0, 24, 0, CEIL_BAY, [win(12, 0)], "wall")
	wall_x("AB", 24.0, -9 - T * 0.5, 9 + T * 0.5, 0, CEIL_BAY, [door(0, 0)], "wall")
	box(geo, "BayRoof", Vector3(-9.3, CEIL_BAY, -0.3), Vector3(9.3, CEIL_BAY + 0.3, 24.3), "roof", false)
	for i: int in 3:
		var z: float = 6.0 + 6.0 * float(i)
		# the rack bases sit 2 m off the side walls: the hatch-repair lane past them stays clear (the Act II playtest)
		box(geo, "Rack%dL" % (i + 1), Vector3(-7.0, 0, z - 1.2), Vector3(-4.2, 0.6, z + 1.2), "steel")
		box(geo, "Rack%dR" % (i + 1), Vector3(4.2, 0, z - 1.2), Vector3(7.0, 0.6, z + 1.2), "steel")
	for w: Array in windows:
		if str(w[1]) == "A_BOMBENSCHACHT":
			closet(w[2], float(w[3]))


func _body() -> void:
	# the centre body: the galley (port), the radio room and bunks (starboard), the aux bus, the forward bulkhead
	wall_z("B_W", -9.0, 24, 54, 0, CEIL_BODY, [door(36, 0), win(48, 0)], "wall")
	wall_z("B_E", 9.0, 24, 54, 0, CEIL_BODY, [door(36, 0), win(48, 0)], "wall")
	box(geo, "BodyRoof", Vector3(-9.3, CEIL_BODY, 23.7), Vector3(9.3, CEIL_BODY + 0.3, 54.3), "roof", false)
	box(geo, "NavBlock_Galley", Vector3(-8.6, 0, 40), Vector3(-5.6, 1.0, 46), "furniture")   # the galley counter
	box(geo, "Kettle", Vector3(-8.2, 1.0, 42.4), Vector3(-7.6, 1.4, 43.0), "steel")
	for bz: float in [26.0, 30.0]:
		box(geo, "Bunk%d" % int(bz), Vector3(5.5, 0, bz), Vector3(8.6, 0.7, bz + 2.2), "furniture")
	box(geo, "NavBlock_Radio", Vector3(5.6, 0, 46), Vector3(8.6, 1.1, 50), "machine")   # the Bordfunk's tape deck
	for w: Array in windows:
		if str(w[1]) == "B_MITTELRUMPF":
			closet(w[2], float(w[3]))


## One wing crawlspace: a low corridor along the spar with a rib frame every 4 m (posts you can stand between),
## a hatch in the trailing-edge wall and two breach panels in the leading-edge wall (dressing; the BreachPanel
## nodes sit on them). sign = -1 port, +1 starboard.
func _wing(sign: float) -> void:
	var tag: String = "L" if sign < 0.0 else "R"
	var x_in: float = 9.0 * sign
	var x_out: float = 52.0 * sign
	var x0: float = minf(x_in, x_out)
	var x1: float = maxf(x_in, x_out)
	wall_x("C%s_S" % tag, 28.0, x0 - T * 0.5, x1 + T * 0.5, 0, CEIL_WING, [win(30.0 * sign, 0)], "wall")
	wall_x("C%s_N" % tag, 46.0, x0 - T * 0.5, x1 + T * 0.5, 0, CEIL_WING, [], "wall")
	box(geo, "WingRoof%s" % tag, Vector3(x0 - 0.3, CEIL_WING, 27.7), Vector3(x1 + 0.3, CEIL_WING + 0.3, 46.3), "roof", false)
	var rx: float = x_in + 4.0 * sign
	while absf(rx) < 50.0:
		box(geo, "Rib%s_%d_a" % [tag, int(absf(rx))], Vector3(rx - 0.2, 0, 28.3), Vector3(rx + 0.2, CEIL_WING, 31.0), "metal")
		box(geo, "Rib%s_%d_b" % [tag, int(absf(rx))], Vector3(rx - 0.2, 0, 43.0), Vector3(rx + 0.2, CEIL_WING, 45.7), "metal")
		rx += 4.0 * sign
	box(geo, "Spar%s" % tag, Vector3(x0, CEIL_WING - 0.4, 36.8), Vector3(x1, CEIL_WING, 37.2), "metal", false)
	for w: Array in windows:
		if str(w[1]) == ("C_FLUEGEL_" + tag):
			closet(w[2], float(w[3]))


func _triebwerk() -> void:
	# the port engine room: the core window in the outboard wall, the engineer's station, the inspection shaft chute
	wall_x("D_S", 24.0, -78 - T * 0.5, -52 + T * 0.5, 0, CEIL_ROOM, [], "wall")
	wall_z("D_W", -78.0, 24, 58, 0, CEIL_ROOM, [win(30, 0)], "wall")
	wall_z("D_E", -52.0, 24, 50, 0, CEIL_ROOM, [door(36, 0)], "wall")
	wall_x("D_N", 58.0, -78 - T * 0.5, -22 + T * 0.5, 0, CEIL_ROOM, [], "wall")
	wall_x("DW_S", 50.0, -52 - T * 0.5, -22 + T * 0.5, 0, CEIL_WING, [], "wall")   # the walkway's inboard wall
	box(geo, "TriebwerkRoof", Vector3(-78.3, CEIL_ROOM, 23.7), Vector3(-51.7, CEIL_ROOM + 0.3, 58.3), "roof", false)
	box(geo, "WalkwayRoofL", Vector3(-52.3, CEIL_WING, 49.7), Vector3(-21.7, CEIL_WING + 0.3, 58.3), "roof", false)
	box(geo, "CoreWindow", Vector3(-78 + T * 0.5, 0.8, 34), Vector3(-76.6, 3.2, 42), "glass")
	box(geo, "NavBlock_Station", Vector3(-75.5, 0, 36.5), Vector3(-73.5, 1.3, 39.5), "machine")   # the engineer's station
	for i: int in 3:
		box(geo, "NavBlock_RibD%d" % i, Vector3(-66 + 4.0 * float(i), 0, 25.6), Vector3(-65.6 + 4.0 * float(i), CEIL_ROOM, 27.2), "metal")
	for w: Array in windows:
		if str(w[1]) == "D_TRIEBWERK":
			closet(w[2], float(w[3]))


func _kanzel() -> void:
	# the gunner blisters along the trailing edge (domes in the south wall; the rims are the climbers' way in)
	wall_x("E_S", 24.0, 52 - T * 0.5, 78 + T * 0.5, 0, CEIL_ROOM, [], "wall")
	wall_z("E_E", 78.0, 24, 58, 0, CEIL_ROOM, [], "wall")
	wall_z("E_W", 52.0, 24, 50, 0, CEIL_ROOM, [door(36, 0)], "wall")
	wall_x("E_N", 58.0, 22 - T * 0.5, 78 + T * 0.5, 0, CEIL_ROOM, [], "wall")
	wall_x("EW_S", 50.0, 22 - T * 0.5, 52 + T * 0.5, 0, CEIL_WING, [], "wall")
	box(geo, "KanzelRoof", Vector3(51.7, CEIL_ROOM, 23.7), Vector3(78.3, CEIL_ROOM + 0.3, 58.3), "roof", false)
	box(geo, "WalkwayRoofR", Vector3(21.7, CEIL_WING, 49.7), Vector3(52.3, CEIL_WING + 0.3, 58.3), "roof", false)
	for bx: float in [56.0, 62.0, 68.0, 74.0]:
		box(geo, "NavBlock_Gun%d" % int(bx), Vector3(bx - 0.4, 0, 24.3), Vector3(bx + 0.4, 1.2, 25.6), "steel")   # the gun mount under each dome


func _cockpit() -> void:
	wall_z("F_W", -22.0, 50, 74, 0, CEIL_ROOM, [door(56, 0)], "wall")
	wall_z("F_E", 22.0, 50, 74, 0, CEIL_ROOM, [door(56, 0)], "wall")
	wall_x("F_S", 54.0, -22 - T * 0.5, 22 + T * 0.5, 0, CEIL_ROOM, [], "wall")   # also the body's forward bulkhead
	box(geo, "CockpitGlass", Vector3(-22, 0, 74 - T * 0.5), Vector3(22, CEIL_ROOM, 74 + T * 0.5), "glass")
	box(geo, "CockpitRoof", Vector3(-22.3, CEIL_ROOM, 53.7), Vector3(22.3, CEIL_ROOM + 0.3, 74.3), "roof", false)
	for sx: float in [-1.8, 1.8]:
		box(geo, "Seat%d" % int(sx * 10.0), Vector3(sx - 0.5, 0, 69.5), Vector3(sx + 0.5, 1.1, 70.7), "furniture")
	box(geo, "NavBlock_Cradle", Vector3(-0.6, 0, 65.4), Vector3(0.6, 1.0, 66.6), "machine")   # the autopilot's cradle (the beacon stands here)


## T-156: the wing walk's catwalk: a grating deck on stanchions deck_y up, along `segments`, railed along `rails`
## (both colliders: the deck is navmesh source for the wing's own box, the rails keep you on it; the turbulence
## is what throws you over).
func _wing_walk() -> void:
	var ww: Dictionary = flight_cfg.get("wing_walk", {})
	if ww.is_empty():
		return
	var dy: float = float(ww.get("deck_y", 3.4))
	var i: int = 0
	for r: Array in ww.get("segments", []):
		var a: Array = r[0]
		var b: Array = r[1]
		box(geo, "WingDeck_%d" % i, Vector3(float(a[0]), dy - 0.12, float(a[1])), Vector3(float(b[0]), dy, float(b[1])), "deck")
		i += 1
	var j: int = 0
	for rl: Array in ww.get("rails", []):
		rail("WingRail_%d" % j, Vector3(float(rl[0]), dy, float(rl[1])), Vector3(float(rl[2]), dy, float(rl[3])), 1.05)
		j += 1


## The lake bed far below the deck: what the crash cutscene films (never reachable; no navmesh, hidden from the bake).
func _diorama() -> void:
	box(geo, "SaltFlat", Vector3(-400, DIO_Y - 0.5, -400), Vector3(400, DIO_Y, 400), "salt", false)
	box(geo, "HangarDio", Vector3(0, DIO_Y, -20), Vector3(30, DIO_Y + 10, 10), "planks", false)
	box(geo, "FlagPole", Vector3(-10.1, DIO_Y, -30.1), Vector3(-9.9, DIO_Y + 8, -29.9), "metal", false)
	box(geo, "FlagDio", Vector3(-9.9, DIO_Y + 7.0, -30.05), Vector3(-7.9, DIO_Y + 8, -29.95), "grey", false)


# ================================================================== dressing + lights

func build_dressing() -> void:
	# T-147 (UPDATE 09 s5.3): the shell (frames, riveted skin, stringers, bulkheads, floors) is KranichShell's GLBs,
	# the outside is FlightSky; the zones' pieces, fixtures and lights are detail_map04b.gd
	# (loaded, not referenced by class: FlightSky uses autoloads, which a --script run cannot compile against)
	var shell: Node3D = Node3D.new()
	shell.set_script(load("res://gravelight/world/map04/kranich_shell.gd"))
	shell.name = "Shell"
	shell.set("rooms", SHELL_ROOMS)
	extra_root_nodes.append(shell)
	var sky: Node3D = Node3D.new()
	sky.set_script(load("res://gravelight/world/map04/flight_sky.gd"))
	sky.name = "FlightSky"
	extra_root_nodes.append(sky)
	Detail.dress_all(self)
	power("F_COCKPIT", Vector3(0, 1.4, 72.7), 12.0, 1.3, Color(0.5, 0.9, 0.6))   # the instrument glow
	# (T-219: the painted backing plates that hid the wall guns' labels behind the wall face are gone: the buys faced
	# the wall then; turned round, their labels face the cabin and a plate in front of them would cover them)
	_wing_walk_dressing()
	fog("CoreHeat", Vector3(-70, 2.0, 40), Vector3(16, 4.0, 30), 0.05, Color(0.5, 0.35, 0.7), Color(0.08, 0.02, 0.12))
	# the wing diorama for the crash: a flat wing, kept so the fx can slide it (FlightSky hides it until the crash)
	var wd: Node3D = Props.group(dress, "WingDiorama", Vector3(0, DIO_Y + 14.0, -130))
	wd.set_meta("keep", true)
	Props.block(wd, Vector3(-30, 0, -8), Vector3(30, 2.0, 8), "steel")
	Props.block(wd, Vector3(-8, 0, -14), Vector3(8, 4.0, 14), "steel")
	for ix: float in [-22.0, -12.0, 12.0, 22.0]:
		Props.cyl(wd, Vector3(ix, 2.6, 0), 1.6, 3.5, "steel")


## T-156: what the wing walk shows outside: the outer wing panels port and starboard (the skin's primer), the
## trailing-edge aprons, the catwalk's stanchions and the tether rail, the port wingtip's navigation light.
func _wing_walk_dressing() -> void:
	var ww: Dictionary = flight_cfg.get("wing_walk", {})
	if ww.is_empty():
		return
	var dy: float = float(ww.get("deck_y", 3.4))
	var skin: Material = KranichShell.frame_material()
	var panels: Array = []
	for sx: float in [-1.0, 1.0]:
		panels.append([Vector3(-100.0, 2.72, 12.0), Vector3(-80.6, 3.08, 46.0), sx])
		panels.append([Vector3(-122.0, 2.74, 15.0), Vector3(-100.0, 3.06, 40.0), sx])
		panels.append([Vector3(-130.0, 2.76, 18.0), Vector3(-122.0, 3.04, 32.0), sx])
		panels.append([Vector3(-80.6, 2.72, 14.0), Vector3(-46.0, 2.92, 23.9), sx])
	for pn: Array in panels:
		var lo: Vector3 = pn[0]
		var hi: Vector3 = pn[1]
		if float(pn[2]) > 0.0:
			var t: float = lo.x
			lo.x = -hi.x
			hi.x = -t
		var mi: MeshInstance3D = Props.block(dress, lo, hi, "steel", false)
		if mi != null and skin != null:
			mi.material_override = skin
	# fairings over the window closets whose roofs (3.3 m) stand above the wing skin (2.85 m) next to the walk
	for w: Array in windows:
		if not ["W_CL_S", "W_CR_S", "W_D_W"].has(str(w[0])):
			continue
		var cb: Array = closet_box(str(w[1]), w[2], float(w[3]))
		var lo3: Vector3 = cb[1]
		var hi3: Vector3 = cb[2]
		var fm: MeshInstance3D = Props.block(dress, Vector3(lo3.x - 0.25, 2.7, lo3.z - 0.25), Vector3(hi3.x + 0.25, 3.36, hi3.z + 0.25), "steel", false)
		if fm != null and skin != null:
			fm.material_override = skin
	# stanchions every ~3 m under the rails, the tether rail itself is the rail's top bar (a brass-yellow tube)
	for rl: Array in ww.get("rails", []):
		var a: Vector3 = Vector3(float(rl[0]), dy, float(rl[1]))
		var b: Vector3 = Vector3(float(rl[2]), dy, float(rl[3]))
		var n: int = maxi(1, int(a.distance_to(b) / 3.0))
		for k: int in n + 1:
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			Props.cyl(dress, p + Vector3(0, 0.52, 0), 0.03, 1.05, "iron")
		var mid: Vector3 = (a + b) * 0.5 + Vector3(0, 1.05, 0)
		var seg_len: float = a.distance_to(b)
		var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
		Props.cyl(dress, mid, 0.025, seg_len, "yellow_paint", Vector3(0, 0, 90) if along_x else Vector3(90, 0, 0))
	for r: Array in ww.get("segments", []):
		var a2: Array = r[0]
		var b2: Array = r[1]
		var lo2: Vector3 = Vector3(float(a2[0]), 0, float(a2[1]))
		var hi2: Vector3 = Vector3(float(b2[0]), 0, float(b2[1]))
		var along: bool = absf(hi2.x - lo2.x) >= absf(hi2.z - lo2.z)
		var len2: float = absf(hi2.x - lo2.x) if along else absf(hi2.z - lo2.z)
		for k2: int in int(len2 / 4.0) + 1:
			var c: Vector3 = Vector3(lerpf(lo2.x, hi2.x, 0.5), 0, lerpf(lo2.z, hi2.z, 0.5))
			if along:
				c.x = minf(lo2.x, hi2.x) + 2.0 + 4.0 * float(k2)
			else:
				c.z = minf(lo2.z, hi2.z) + 2.0 + 4.0 * float(k2)
			Props.block(dress, Vector3(c.x - 0.06, 2.85, c.z - 0.06), Vector3(c.x + 0.06, dy - 0.12, c.z + 0.06), "iron", false)
	lamp(Vector3(-129.5, 3.3, 25.0), Color(1.0, 0.15, 0.1), 1.2, 6.0)   # the port wingtip's navigation light
	lamp(Vector3(129.5, 3.3, 25.0), Color(0.2, 1.0, 0.35), 1.0, 6.0)    # starboard


## T-147: every light carries a `zone` meta (contract C4: <= 6 shadowed per zone); the swinging bulbs go under their
## power light (dark until the aux bus is thrown); the batches get a visibility range (the far rooms are not drawn).
func _finish_lights() -> void:
	var lights: Array[Node] = map_root.find_children("*", "Light3D", true, false)
	var shadowed: Dictionary = {}
	for n: Node in lights:
		var l: Light3D = n as Light3D
		if not l.has_meta("zone"):
			l.set_meta("zone", StringName(_zone_of(l.global_position if l.is_inside_tree() else _pos_in_root(l))) if not (l is DirectionalLight3D) else &"SKY")
		if l is OmniLight3D:
			(l as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_CUBE   # Compatibility has no dual paraboloid
		if l.shadow_enabled and not (l is DirectionalLight3D):
			var zk: String = str(l.get_meta("zone"))
			shadowed[zk] = int(shadowed.get(zk, 0)) + 1
	print("  shadowed lights per zone: %s" % str(shadowed))
	for n2: Node in dress.find_children("SwingBulb*", "Node3D", true, false):
		var zone: String = str(n2.get_meta("power_zone", ""))
		if zone == "":
			continue
		var best: Node3D = null
		var bd: float = 1e9
		var at: Vector3 = (n2 as Node3D).position
		for n3: Node in lights:
			if n3.is_in_group(&"power_lights") and str(n3.get_meta("zone", "")) == zone:
				var d: float = (n3 as Node3D).position.distance_to(at)
				if d < bd:
					bd = d
					best = n3 as Node3D
		if best != null and bd < 2.5:
			var xf: Transform3D = (n2 as Node3D).transform
			n2.get_parent().remove_child(n2)
			best.add_child(n2)
			(n2 as Node3D).transform = best.transform.affine_inverse() * xf
	var batches: Node = map_root.get_node_or_null("StaticBatches")
	if batches != null:
		for c: Node in batches.get_children():
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi != null and mi.mesh != null and mi.mesh.get_aabb().size.length() < 60.0:
				mi.visibility_range_end = 80.0
				mi.visibility_range_end_margin = 6.0


func _pos_in_root(n: Node3D) -> Vector3:
	return _xform_to_root(n).origin


## The zone a point lies in (the zone boxes), else the nearest box's zone.
func _zone_of(p: Vector3) -> String:
	var best: String = start_zone
	var bd: float = 1e9
	for zb: Array in zone_boxes:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		var q: Vector3 = Vector3(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y), clampf(p.z, lo.z, hi.z))
		var d: float = q.distance_to(p)
		if d < bd:
			bd = d
			best = str(zb[0])
	return best


func build_gameplay_extra() -> void:
	_node("res://gravelight/maps/map04_fernflug/act_controller.gd", "ActController", {}, Vector3.ZERO)
	_node("res://gravelight/world/map04/flight_controller.gd", "FlightController", {}, Vector3.ZERO)
	# the main egg continues aboard (UPDATE 07, T-114): the three crew tags (s7a) at the bunks, the radio room, a blister
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map04_kuendigung.json",
		"res://data/gravelight/quests/map04b_crew_tags.json"]))   # T-156: the side quest anyone can do
	for t: Array in [["Tag1", "I", "Riedl, A.", Vector3(7.0, 0.72, 27.0)], ["Tag2", "II", "Haas, W.", Vector3(7.0, 0.72, 31.2)], ["Tag3", "III", "Pohl, K.", Vector3(62.0, 0.1, 25.6)]]:
		_node("res://gravelight/world/quest_note.gd", str(t[0]), {"tag": &"crew_tag", "item_id": StringName("tag_%s" % str(t[1]).to_lower()), "numeral": str(t[1]),
			"kind": "tag", "note_text": str(t[2])}, t[3], 0.0)
	# the breach panels in the wings' leading-edge walls (two a side)
	for bp: Array in [["BreachL1", "C_FLUEGEL_L", Vector3(-20, 0, 46), 180.0], ["BreachL2", "C_FLUEGEL_L", Vector3(-40, 0, 46), 180.0],
			["BreachR1", "C_FLUEGEL_R", Vector3(20, 0, 46), 180.0], ["BreachR2", "C_FLUEGEL_R", Vector3(40, 0, 46), 180.0]]:
		_node("res://gravelight/world/map04/breach_panel.gd", str(bp[0]), {"panel_id": StringName(str(bp[0]).to_lower()), "zone_id": StringName(str(bp[1]))}, bp[2], float(bp[3]))
	# the six bomb racks (the run's targets), rack 1 aft-most port, then starboard, forward
	var cities: Array = ["BOSTON", "PROVIDENCE", "NEW HAVEN", "NEW YORK", "PHILADELPHIA", "WASHINGTON"]
	var i: int = 0
	for z: float in [6.0, 12.0, 18.0]:
		for sx: float in [-5.6, 5.6]:
			_node("res://gravelight/world/map04/bomb_rack.gd", "Rack%d" % (i + 1), {"rack_index": i + 1, "city": str(cities[i])}, Vector3(sx, 0, z), 90.0 if sx < 0.0 else -90.0)
			i += 1
	# the cockpit door waits for the autopilot key (the Bordwart's drop, or the act-round fallback)
	for n: String in ["Door_CockpitL", "Door_CockpitR"]:
		var d: Node = gameplay.get_node_or_null(n)
		if d != null:
			d.set("requires_flag", &"autopilot_key")
			d.set("requires_text", "The flight deck is locked: the engineer has the key")
	# the London window's camera post (a marker the runner reads)
	var cam: Marker3D = Marker3D.new()
	cam.name = "LondonCam"
	cam.position = Vector3(74, 1.5, 25.4)
	gameplay.add_child(cam)
	# T-147: the breach panels show the night through the shell's holes when they blow
	for bp2: Node in gameplay.get_children():
		if bp2.name.begins_with("Breach"):
			bp2.set("see_through", true)
	_set_pieces_u10()
	_finish_lights()


# ================================================================== UPDATE 10 §3 (T-156): the act's new set-pieces

func _v(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _set_pieces_u10() -> void:
	const W: String = "res://gravelight/world/map04/"
	# the aux bus becomes its own findable board (AuxBus, a PowerSwitch): same place, same zone order and table
	var ab: Node = gameplay.get_node_or_null("AuxBus")
	if ab != null:
		var zo: PackedStringArray = ab.get("zone_order")
		var lbl: String = str(ab.get("label"))
		var tbl: String = str(ab.get("config_table"))
		ab.set_script(load(W + "aux_bus.gd"))
		ab.set("zone_order", zo)
		ab.set("label", lbl)
		ab.set("config_table", tbl)
		(ab as Node3D).rotation.y = deg_to_rad(90.0)   # its face toward the cabin (the old yaw turned it to the wall)
	# the wing walk: its region gets a name the WingWalk finds, the hatches, the tether posts, the wingtip locker
	var nav: Node = map_root.get_node_or_null("Navigation")
	if nav != null and wing_box_index >= 0:
		var r: Node = nav.get_node_or_null("Nav_C_FLUEGEL_L_%d" % wing_box_index)
		if r != null:
			r.name = "Nav_WingRails"
	var ww: Dictionary = flight_cfg.get("wing_walk", {})
	if not ww.is_empty():
		_node(W + "wing_walk.gd", "WingWalk", {}, Vector3.ZERO)
		_node(W + "wing_hatch.gd", "WingHatchOut", {"direction": "out", "to_pos": _v(ww["landing"]), "to_yaw": 0.0}, _v(ww["hatch"]), 0.0)
		_node(W + "wing_hatch.gd", "WingHatchIn", {"direction": "in", "to_pos": _v(ww["hatch_foot"]), "to_yaw": 0.0}, _v(ww["hatch_in"]), 0.0)
		var ci: int = 1
		for cp: Array in ww.get("clip_points", []):
			_node(W + "clip_point.gd", "ClipPoint%d" % ci, {"clip_hold": float(ww.get("clip_hold", 1.0))}, _v(cp), 0.0)
			ci += 1
		_node(W + "wing_chest.gd", "WingChest", {"wonder_slot": str(ww.get("wonder_slot", "undertow_class"))}, _v(ww["chest"]), float(ww.get("chest_yaw", 0.0)))
	# the crew's tags side quest (map04b_crew_tags.json): the radio room's roster board and the Bordfunk's tape deck
	_node("res://gravelight/world/quest_interact.gd", "CrewRoster", {"target": &"crew_roster", "label_text": "BESATZUNGSLISTE",
		"prompt_text": "read the crew's tags against the roster", "missing_text": "The roster: three names rubbed out", "size": Vector3(1.0, 1.6, 0.5)},
		Vector3(8.7, 0, 44.6), 90.0)
	_node("res://gravelight/world/quest_interact.gd", "BordfunkReel", {"target": &"bordfunk_reel", "label_text": "BORDFUNK · BAND",
		"prompt_text": "play the last reel on the Bordfunk", "missing_text": "The tape deck: a reel marked with three names", "size": Vector3(1.0, 1.4, 0.6)},
		Vector3(5.3, 0, 48.0), -90.0)
	# the bay doors as a lever trap (traps.json bay_doors): the lever on the bay's forward bulkhead, starboard
	var bd: Node3D = _node(W + "bay_doors_trap.gd", "Trap_BayDoors", {}, Vector3(0, 0, 12.0), 0.0)
	_node("res://gravelight/world/trap_lever.gd", "Lever_BayDoors", {"trap_path": NodePath("../" + bd.name), "trap_id": &"bay_doors"}, Vector3(5.0, 0, 23.75), 0.0)
	# T-156: Riedl's intercom (ExtraPeople "riedl" talks here until act round 4) and Ruhland's Talk point at the Bordkasse
	var ic: Node3D = Node3D.new()
	ic.name = "RiedlIntercom"
	ic.position = Vector3(8.82, 0, 39.2)
	gameplay.add_child(ic)
	Props.block(ic, Vector3(-0.06, 1.25, -0.16), Vector3(0.0, 1.6, 0.16), "machine_grey")
	Props.cyl(ic, Vector3(-0.09, 1.42, 0.0), 0.035, 0.22, "black_paint", Vector3(90, 0, 0))
	var icl: Label3D = Label3D.new()
	icl.text = "SPRECHANLAGE\nMASCHINE"
	icl.font_size = 12
	icl.pixel_size = 0.004
	icl.position = Vector3(-0.07, 1.72, 0)
	icl.rotation.y = -PI * 0.5
	icl.modulate = Color(0.9, 0.85, 0.65)
	ic.add_child(icl)
	# the tilt's loose cargo
	var si: int = 1
	for sl: Dictionary in (flight_cfg.get("turbulence_tilt", {}) as Dictionary).get("sliders", []):
		_node(W + "tilt_slider.gd", "Slider%d_%s" % [si, str(sl.get("kind", "crate"))], {"kind": str(sl.get("kind", "crate"))}, _v(sl["at"]), 0.0)
		si += 1
	# the decompression breaches (the bay's aft ramp seam, the starboard crawlway's leading edge) and their rails
	# (an Interactable's front is its local -Z: yaw 0 faces -Z, 90 faces -X, -90 faces +X, 180 faces +Z)
	var bay: Node3D = _node(W + "decompression.gd", "DecompBay", {}, Vector3(0, 0, 0.3), 180.0)
	var stb: Node3D = _node(W + "decompression.gd", "DecompStarboard", {}, Vector3(30, 0, 45.75), 0.0)
	for g: Array in [["GripBay1", Vector3(-8.6, 0, 3.0), -90.0, bay], ["GripBay2", Vector3(8.6, 0, 3.0), 90.0, bay],
			["GripBay3", Vector3(-8.6, 0, 8.5), -90.0, bay], ["GripBay4", Vector3(8.6, 0, 8.5), 90.0, bay],
			["GripStb1", Vector3(26.0, 0, 45.7), 0.0, stb], ["GripStb2", Vector3(34.0, 0, 45.7), 0.0, stb],
			["GripStb3", Vector3(24.0, 0, 28.3), 180.0, stb], ["GripStb4", Vector3(36.0, 0, 28.3), 180.0, stb]]:
		_node(W + "rail_grip.gd", str(g[0]), {"breach_path": NodePath("../" + (g[3] as Node).name)}, g[1], float(g[2]))
