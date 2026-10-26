extends "res://gravelight/tools_src/gen_map04_lib.gd"
## Generates Map 4 Act IV "Mondlicht, the relay station" (UPDATE 07, docs/MAP4_FERNFLUG.md §6): Darkmatter's Regional
## Retention Relay RR-7 on the floor of a small crater, half pressurized domes, half vacuum. Six zones on the ladder
## 750 → 1000 (the yard airlock) → 1250 (the store, two ways in: one link group) → 1500 → 2000 (the Account, opened
## by the three columns): the landing dome, the concourse with the first Crucible, the regolith yard under the Earth
## (vacuum, two air posts, the leap points, the rim with the smile-crack and the dish beyond it), the fulfillment
## store, the retention hall with the three columns and NOBODY CANCELS, and the Account with the console, the first
## retained, and the Manager's station under the vacuum shaft. Source of truth.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map04d.gd
##
## Frame: +Z north (the yard, the Earth "up" the sky), +X east, y up; the domes' floors at y = 0.
## Zone plan (x, z):  A_RECEPTION -12..12 × 0..24 · B_CONCOURSE -12..12 × 24..60 · C_YARD -40..40 × 60..110
## · D_FULFILLMENT 12..44 × 24..60 · E_HALL 12..44 × -16..24 · F_CORE 14..42 × -44..-16.

const CEIL_A: float = 7.0
const CEIL_B: float = 5.0
const CEIL_D: float = 5.0
const CEIL_E: float = 9.0
const CEIL_F: float = 7.0
const RIM_H: float = 3.0


func setup_tables() -> void:
	out_path = "res://gravelight/maps/map04_fernflug/map04d.tscn"
	root_name = "Map04dMondlicht"
	map_id = "map04d_mondlicht"
	display_name = "Fernflug — Act IV: Mondlicht"
	start_zone = "A_RECEPTION"
	intro_text = "MONDLICHT\nRegional Retention Relay RR-7  ·  the Moon's near side"
	json_table = "map04d"
	zone_bits = {"A_RECEPTION": 1, "B_CONCOURSE": 2, "C_YARD": 3, "D_FULFILLMENT": 4, "E_HALL": 5, "F_CORE": 6}
	adj = {"A_RECEPTION": ["B_CONCOURSE"], "B_CONCOURSE": ["A_RECEPTION", "C_YARD", "D_FULFILLMENT"],
		"C_YARD": ["B_CONCOURSE", "D_FULFILLMENT"], "D_FULFILLMENT": ["B_CONCOURSE", "C_YARD", "E_HALL"],
		"E_HALL": ["D_FULFILLMENT", "F_CORE"], "F_CORE": ["E_HALL"]}
	windows = [
		["W_A_L", "A_RECEPTION", Vector3(-12, 0, 8), 90.0], ["W_A_R", "A_RECEPTION", Vector3(12, 0, 8), -90.0],
		["W_B_L", "B_CONCOURSE", Vector3(-12, 0, 40), 90.0], ["W_B_R", "B_CONCOURSE", Vector3(12, 0, 52), -90.0],
		["W_D_E1", "D_FULFILLMENT", Vector3(44, 0, 32), -90.0], ["W_D_E2", "D_FULFILLMENT", Vector3(44, 0, 52), -90.0],
		["W_E_E1", "E_HALL", Vector3(44, 0, 0), -90.0], ["W_E_E2", "E_HALL", Vector3(44, 0, 12), -90.0],
	]
	zone_boxes = [
		["A_RECEPTION", Vector3(-12, -1, 0), Vector3(12, CEIL_A + 1, 24)],
		["B_CONCOURSE", Vector3(-12, -1, 24), Vector3(12, CEIL_B + 1, 60)],
		["C_YARD", Vector3(-40, -1, 60), Vector3(40, 14, 110)],
		["D_FULFILLMENT", Vector3(12, -1, 24), Vector3(44, CEIL_D + 1, 60)],
		["E_HALL", Vector3(12, -1, -16), Vector3(44, CEIL_E + 1, 24)],
		["F_CORE", Vector3(14, -1, -44), Vector3(42, CEIL_F + 1, -16)],
	]
	for w: Array in windows:
		zone_boxes.append(closet_box(str(w[1]), w[2], float(w[3])))
	links = [
		[Vector3(0, 0, 23.6), Vector3(0, 0, 24.4), "B_CONCOURSE"],
		[Vector3(0, 0, 59.6), Vector3(0, 0, 60.4), "C_YARD"],
		[Vector3(11.6, 0, 42), Vector3(12.4, 0, 42), "D_FULFILLMENT"],
		[Vector3(28, 0, 60.4), Vector3(28, 0, 59.6), "D_FULFILLMENT"],
		[Vector3(28, 0, 24.4), Vector3(28, 0, 23.6), "E_HALL"],
		[Vector3(28, 0, -15.6), Vector3(28, 0, -16.4), "F_CORE"],
	]
	buys = [
		["kar98k", Vector3(-11.83, 1.5, 16.0), 90.0], ["thompson", Vector3(11.83, 1.5, 32.0), -90.0],
		["springfield", Vector3(-39.6, 1.5, 80.0), 90.0], ["bar", Vector3(43.83, 1.5, 42.0), -90.0],
	]
	doors = [
		["Door_Concourse", "door_concourse", "B_CONCOURSE", [], "", 750, "the concourse", Vector3(0, 0, 24), 0.0, 2.4, false],
		["Door_Yard", "door_yard", "C_YARD", [], "", 1000, "the yard airlock", Vector3(0, 0, 60), 0.0, 2.4, false],
		["Door_FulfillmentB", "door_fulfillment", "D_FULFILLMENT", [], "fulfillment", 1250, "the store", Vector3(12, 0, 42), 90.0, 2.0, false],
		["Door_FulfillmentY", "door_fulfillment", "D_FULFILLMENT", [], "fulfillment", 1250, "the store's airlock", Vector3(28, 0, 60), 0.0, 2.0, false],
		["Door_Hall", "door_hall", "E_HALL", [], "", 1500, "the retention hall", Vector3(28, 0, 24), 0.0, 2.4, false],
		["Door_Account", "door_account", "F_CORE", [], "", 2000, "the Account", Vector3(28, 0, -16), 0.0, 2.4, false],
	]
	ammo_boxes = [
		["Reception", Vector3(11.48, 0, 4.0), -90.0], ["Concourse", Vector3(-11.48, 0, 56.0), 90.0],
		["Store", Vector3(43.48, 0, 56.0), -90.0], ["Hall", Vector3(12.52, 0, -12.0), 90.0],
	]
	grounds = [
		["A_RECEPTION", Vector3(0, 0, 18), 1],
		["B_CONCOURSE", Vector3(0, 0, 34), 1],
		["C_YARD", Vector3(-20, 0, 80), 1], ["C_YARD", Vector3(0, 0, 96), 1], ["C_YARD", Vector3(20, 0, 80), 1],
		["D_FULFILLMENT", Vector3(36, 0, 56), 1], ["D_FULFILLMENT", Vector3(20, 0, 30), 1],
		["E_HALL", Vector3(20, 0, -8), 1], ["E_HALL", Vector3(36, 0, -8), 1],
	]
	# the yard's two leap points (the Jumpjockeys' landings; Catwalk_C_YARD_n)
	catwalks = [["C_YARD", Vector3(-30, 0, 100), true], ["C_YARD", Vector3(30, 0, 100), true]]
	perks = [
		["second_wind", Vector3(8.0, 0, 22.6), 180.0],
		["skyhook_sekt", Vector3(-11.3, 0, 30.0), 90.0], ["magpie_mead", Vector3(11.3, 0, 30.0), -90.0],
		["ironhide_stout", Vector3(12.7, 0, 50.0), 90.0], ["trigger_tonic", Vector3(43.3, 0, 28.0), -90.0],
		["hawkeye_brandy", Vector3(12.7, 0, 16.0), 90.0], ["blastproof_bock", Vector3(43.3, 0, -8.0), -90.0],
		["packmule_porter", Vector3(14.7, 0, -24.0), 90.0],
	]
	crates = [
		["Reception", Vector3(-7.0, 0, 18.0), 90.0, true, [Vector3(-7, 0, 14), Vector3(-4, 0, 12), Vector3(0, 0, 12)]],
		["Concourse", Vector3(7.0, 0, 56.0), -90.0, false, [Vector3(7, 0, 52), Vector3(4, 0, 50), Vector3(0, 0, 50)]],
	]
	player_spawns = [[Vector3(-2, 0, 6), 0.0], [Vector3(2, 0, 6), 0.0], [Vector3(-2, 0, 9), 0.0], [Vector3(2, 0, 9), 0.0]]
	power_switch = {}   # the relay runs: every machine has power from the start (MapRoot.power_on_at_start)
	crucible = {"pos": Vector3(-8.0, 0, 46.0), "yaw": 90.0, "needs_power": false}
	armorers_bench = []
	burst_points = [Vector3(0, 0, 40), Vector3(0, 0, 12), Vector3(28, 0, 40), Vector3(28, 0, 4)]
	traps = []
	mat_map = {
		"wall": "enamel_white", "concrete": "concrete", "ground": "tile_floor", "metal": "iron", "steel": "steel", "rust": "rust",
		"furniture": "furniture", "deck": "tile_floor", "grey": "grey_paint", "lead": "lead", "glass": "glass", "beam": "beam",
		"machine": "machine_grey", "regolith": "rock_floor", "rim": "rock_dark", "violet": "nachtglas", "violet_dim": "nachtglas_dim",
		"roof": "steel", "planks": "planks", "dirt": "dirt",
	}
	mat_rules = [["Rim*", "rock_dark"], ["Regolith*", "rock_floor"], ["Floor*", "tile_floor"], ["Hull*", "enamel_white"], ["Shaft*", "steel"]]
	hide = ["NavBlock*", "Model*", "Rack*", "Conveyor*", "Capsule*", "Desk*", "Pad*", "Pilch*", "Dish*", "Smile*", "Slogan*"]
	sky_top = Color(0.002, 0.002, 0.004)
	sky_horizon = Color(0.008, 0.008, 0.014)
	ambient = Color(0.17, 0.15, 0.26)
	fog_color = Color(0.02, 0.015, 0.03)
	moon_rot = Vector3(-62, 25, 0)   # the Sun, low and hard over the rim (the "Moon" light; moon_switch keeps it)


# ================================================================== geometry

func build_geometry() -> void:
	# the domes' floor, the yard's regolith, the hulls as walls, lids as non-colliding roofs
	box(geo, "Floor_Domes", Vector3(-14, -0.5, -46), Vector3(46, 0, 62), "ground")
	box(geo, "Regolith", Vector3(-42, -0.5, 60), Vector3(42, 0, 112), "regolith")
	_reception()
	_concourse()
	_yard()
	_fulfillment()
	_hall()
	_core()


func _reception() -> void:
	wall_x("A_S", 0.0, -12 - T * 0.5, 12 + T * 0.5, 0, CEIL_A, [], "wall")
	wall_z("A_W", -12.0, 0, 24, 0, CEIL_A, [win(8, 0)], "wall")
	wall_z("A_E", 12.0, 0, 24, 0, CEIL_A, [win(8, 0)], "wall")
	wall_x("AB", 24.0, -12 - T * 0.5, 12 + T * 0.5, 0, CEIL_A, [door(0, 0, 2.4)], "wall")
	box(geo, "DomeRoof_A", Vector3(-12.3, CEIL_A, -0.3), Vector3(12.3, CEIL_A + 0.3, 24.3), "roof", false)
	# the capsule, nose up in its cradle, and the reception desk with the bell
	box(geo, "NavBlock_Capsule", Vector3(-9.5, 0, 1.5), Vector3(-5.5, 3.5, 5.5), "metal")
	box(geo, "NavBlock_Desk", Vector3(4.0, 0, 19.0), Vector3(9.0, 1.0, 20.2), "furniture")


func _concourse() -> void:
	wall_z("B_W", -12.0, 24, 60, 0, CEIL_B, [win(40, 0)], "wall")
	wall_z("B_E", 12.0, 24, 60, 0, CEIL_B, [door(42, 0, 2.0), win(52, 0)], "wall")
	wall_x("BC", 60.0, -12 - T * 0.5, 12 + T * 0.5, 0, CEIL_B, [door(0, 0, 2.4)], "wall")
	box(geo, "DomeRoof_B", Vector3(-12.3, CEIL_B, 23.7), Vector3(12.3, CEIL_B + 0.3, 60.3), "roof", false)
	# the relay's model under glass (the lobby ring runs round it)
	box(geo, "NavBlock_Model", Vector3(-1.6, 0, 37.4), Vector3(1.6, 1.1, 40.6), "furniture")
	# the airlock vestibule's inner frames (a nav pinch at the yard door)
	box(geo, "Hull_AirlockL", Vector3(-4, 0, 58.2), Vector3(-1.6, CEIL_B, 59.7), "wall")
	box(geo, "Hull_AirlockR", Vector3(1.6, 0, 58.2), Vector3(4, CEIL_B, 59.7), "wall")


func _yard() -> void:
	# the crater rim: a low wall of rock on three sides, the domes' hulls on the fourth
	box(geo, "Rim_W", Vector3(-42, 0, 60), Vector3(-40, RIM_H, 112), "rim")
	box(geo, "Rim_E", Vector3(40, 0, 60), Vector3(42, RIM_H, 112), "rim")
	box(geo, "Rim_N", Vector3(-42, 0, 110), Vector3(42, RIM_H, 112), "rim")
	wall_x("C_S_W", 60.0, -40, -12 + T * 0.5, 0, CEIL_B, [], "wall")
	wall_x("CD", 60.0, 12 - T * 0.5, 44 + T * 0.5, 0, CEIL_D, [door(28, 0, 2.0)], "wall")
	# boulders and the dish's foundation: cover in the open
	for b: Array in [[Vector3(-24, 0, 70), Vector3(-20, 1.6, 73)], [Vector3(18, 0, 92), Vector3(22, 1.4, 95)], [Vector3(-8, 0, 100), Vector3(-4, 1.9, 103)],
			[Vector3(30, 0, 72), Vector3(33, 1.2, 75)], [Vector3(-32, 0, 92), Vector3(-29, 2.0, 95)]]:
		box(geo, "Rim_Boulder", b[0], b[1], "rim")
	box(geo, "Rim_DishBase", Vector3(32, 0, 98), Vector3(38, 2.2, 104), "rim")
	# the edge: a tall invisible wall over the rim keeps the slow jumps inside the yard
	for e: Array in [[Vector3(-42.5, RIM_H, 60), Vector3(-42, 40, 112)], [Vector3(42, RIM_H, 60), Vector3(42.5, 40, 112)], [Vector3(-42.5, RIM_H, 112), Vector3(42.5, 40, 112.5)],
			[Vector3(-42.5, CEIL_B, 59.5), Vector3(-12, 40, 60)], [Vector3(12, CEIL_D, 59.5), Vector3(42.5, 40, 60)], [Vector3(-12.3, CEIL_B + 0.3, 59.5), Vector3(12.3, 40, 60)]]:
		box(geo, "NavBlock_Edge", e[0], e[1], "metal")


func _fulfillment() -> void:
	wall_z("D_E", 44.0, 24, 60, 0, CEIL_D, [win(32, 0), win(52, 0)], "wall")
	wall_x("DE", 24.0, 12 - T * 0.5, 44 + T * 0.5, 0, CEIL_E, [door(28, 0, 2.4)], "wall")
	box(geo, "DomeRoof_D", Vector3(11.7, CEIL_D, 23.7), Vector3(44.3, CEIL_D + 0.3, 60.3), "roof", false)
	# the racks of suited inventory (three aisles) and the conveyor along the north wall
	for rz: float in [34.0, 42.0, 50.0]:
		box(geo, "NavBlock_Rack", Vector3(17, 0, rz - 0.6), Vector3(39, 2.4, rz + 0.6), "metal")
	box(geo, "NavBlock_Conveyor", Vector3(16, 0, 54.2), Vector3(40, 0.9, 55.6), "metal")


func _hall() -> void:
	wall_z("E_W", 12.0, -16, 24, 0, CEIL_E, [], "wall")
	wall_z("E_E", 44.0, -16, 24, 0, CEIL_E, [win(0, 0), win(12, 0)], "wall")
	wall_x("EF", -16.0, 12 - T * 0.5, 44 + T * 0.5, 0, CEIL_E, [door(28, 0, 2.4)], "wall")
	box(geo, "DomeRoof_E", Vector3(11.7, CEIL_E, -16.3), Vector3(44.3, CEIL_E + 0.3, 24.3), "roof", false)
	# the three columns' plinths (the RetentionColumn nodes stand on them; the loop runs round them)
	for cx: float in [18.0, 28.0, 38.0]:
		box(geo, "NavBlock_Column", Vector3(cx - 1.0, 0, 3.0), Vector3(cx + 1.0, 0.3, 5.0), "metal")


func _core() -> void:
	wall_z("F_W", 14.0, -44, -16, 0, CEIL_F, [], "wall")
	wall_z("F_E", 42.0, -44, -16, 0, CEIL_F, [], "wall")
	wall_x("F_S", -44.0, 14 - T * 0.5, 42 + T * 0.5, 0, CEIL_F, [], "wall")
	# the roof with the vacuum shaft over the console (a hole 2.5 m across at (28, -30))
	box(geo, "DomeRoof_F_W", Vector3(13.7, CEIL_F, -44.3), Vector3(25.5, CEIL_F + 0.3, -15.7), "roof", false)
	box(geo, "DomeRoof_F_E", Vector3(30.5, CEIL_F, -44.3), Vector3(42.3, CEIL_F + 0.3, -15.7), "roof", false)
	box(geo, "DomeRoof_F_S", Vector3(25.5, CEIL_F, -44.3), Vector3(30.5, CEIL_F + 0.3, -32.5), "roof", false)
	box(geo, "DomeRoof_F_N", Vector3(25.5, CEIL_F, -27.5), Vector3(30.5, CEIL_F + 0.3, -15.7), "roof", false)
	for s: Array in [[Vector3(25.5, CEIL_F, -32.5), Vector3(30.5, CEIL_F + 6.0, -32.2)], [Vector3(25.5, CEIL_F, -27.8), Vector3(30.5, CEIL_F + 6.0, -27.5)],
			[Vector3(25.5, CEIL_F, -32.5), Vector3(25.8, CEIL_F + 6.0, -27.5)], [Vector3(30.2, CEIL_F, -32.5), Vector3(30.5, CEIL_F + 6.0, -27.5)]]:
		box(geo, "Shaft_Wall", s[0], s[1], "steel", false)
	box(geo, "NavBlock_Console", Vector3(27.0, 0, -30.6), Vector3(29.0, 1.1, -29.4), "metal")
	box(geo, "NavBlock_Pilch", Vector3(26.5, 0, -41.0), Vector3(29.5, 0.5, -38.5), "metal")
	box(geo, "NavBlock_Pad", Vector3(34.5, 0, -40.0), Vector3(39.5, 0.25, -35.0), "metal")


# ================================================================== dressing

func build_dressing() -> void:
	# the relay's house light: violet strips and cold white; the reception desk's bell; the yard's earthshine
	lamp(Vector3(0, CEIL_A - 0.5, 12), MERCURY, 1.2, 16.0, 0.0, 0.4)
	lamp(Vector3(0, CEIL_A - 1.0, 21), VIOLET, 0.8, 10.0, 0.05, 0.5)
	for bz: float in [30.0, 42.0, 54.0]:
		lamp(Vector3(0, CEIL_B - 0.4, bz), VIOLET, 1.1, 12.0, 0.03, 0.6)
	lamp(Vector3(-8, 2.6, 46), MERCURY, 0.7, 7.0, 0.0, 0.2)   # the Crucible's bay
	for dz: float in [32.0, 50.0]:
		lamp(Vector3(28, CEIL_D - 0.4, dz), MERCURY, 1.1, 14.0, 0.02, 0.3)
	lamp(Vector3(28, CEIL_D - 0.6, 41), VIOLET, 0.6, 8.0)
	for ex: float in [20.0, 36.0]:
		lamp(Vector3(ex, CEIL_E - 0.8, 12), VIOLET, 1.0, 14.0, 0.04, 0.9)
		lamp(Vector3(ex, CEIL_E - 0.8, -6), VIOLET, 1.0, 14.0, 0.04, 0.9)
	lamp(Vector3(28, CEIL_F - 0.6, -24), VIOLET, 1.4, 16.0, 0.06, 1.0)
	lamp(Vector3(28, CEIL_F - 0.8, -39), MERCURY, 0.6, 10.0)
	lamp(Vector3(0, 12.0, 85), MOONLIGHT, 0.5, 70.0, 0.0, 0.0)   # earthshine over the yard
	shaft("SunShaft", Vector3(-30, 30, 130), Vector3(0, 0, 85), Color(1.0, 0.97, 0.9), 6.0, 90.0, 40.0, 0.2, true)
	fog("YardDust", Vector3(0, 1.0, 85), Vector3(80, 2.5, 50), 0.012, Color(0.6, 0.6, 0.65))
	fog("HallHum", Vector3(28, 4.0, 4), Vector3(32, 8.0, 40), 0.03, Color(0.5, 0.35, 0.7), Color(0.05, 0.02, 0.08))
	# the capsule (nose up in its cradle), the desk's bell, the slogans
	var cap: Node3D = Props.group(dress, "Capsule", Vector3(-7.5, 0, 3.5))
	Props.cyl(cap, Vector3(0, 1.6, 0), 1.4, 3.2, "steel")
	Props.cone(cap, Vector3(0, 3.9, 0), 1.4, 1.4, "steel")
	for i: int in 3:
		Props.strut(cap, Vector3(cos(TAU * float(i) / 3.0) * 1.8, 0, sin(TAU * float(i) / 3.0) * 1.8), Vector3(cos(TAU * float(i) / 3.0) * 1.0, 1.2, sin(TAU * float(i) / 3.0) * 1.0), 0.1, "iron")
	var desk: Node3D = Props.group(dress, "Desk", Vector3(6.5, 0, 19.6))
	Props.block(desk, Vector3(-2.5, 0, -0.6), Vector3(2.5, 1.0, 0.6), "enamel_white")
	Props.bell(desk, Vector3(1.8, 1.0, 0), 0.18, "brass")
	label("WELCOME, VALUED CUSTOMERS", Vector3(0, CEIL_A - 1.2, 23.7), 180.0, 48, Color(0.85, 0.6, 1.0, 0.95))
	label("ANOMALOUS INVENTORY", Vector3(-11.7, 2.4, 16.0), 90.0, 18, Color(0.9, 0.85, 0.7, 0.8))
	label("REGIONAL RETENTION RELAY RR-7", Vector3(0, CEIL_B - 0.6, 24.3), 0.0, 36)
	label("EXCEPTIONAL RETENTION", Vector3(-11.7, 3.4, 48.0), 90.0, 32, Color(0.85, 0.6, 1.0, 0.9))
	label("WE'LL TAKE CARE OF EVERYTHING", Vector3(11.7, 3.4, 36.0), -90.0, 32, Color(0.85, 0.6, 1.0, 0.9))
	label("FULFILLMENT", Vector3(12.3, CEIL_D - 0.6, 42.0), -90.0, 36)
	label("RETENTION HALL", Vector3(28, CEIL_E - 0.8, 23.7), 180.0, 44)
	label("THE ACCOUNT", Vector3(28, CEIL_F - 0.8, -16.3), 0.0, 40, Color(0.85, 0.6, 1.0, 0.95))
	# the relay's model under glass: the domes in miniature, the dish, a violet thread to a tiny Earth
	var model: Node3D = Props.group(dress, "Model", Vector3(0, 1.1, 39))
	for m: Array in [[Vector3(-0.6, 0, -1.2), 0.35], [Vector3(-0.6, 0, -0.4), 0.3], [Vector3(0.2, 0, -0.4), 0.3], [Vector3(0.2, 0, -1.1), 0.3], [Vector3(0.2, 0, -1.7), 0.28]]:
		Props.ball(model, m[0] + Vector3(0, float(m[1]) * 0.6, 0), Vector3.ONE * float(m[1]) * 2.0, "enamel_white")
	Props.cone(model, Vector3(0.9, 0.3, 0.9), 0.25, 0.3, "steel")
	Props.ball(model, Vector3(0, 0.9, 0.9), Vector3.ONE * 0.3, "nachtglas")
	Props.block(model, Vector3(-1.5, 0.0, -2.0), Vector3(1.5, 1.4, 1.5), "glass")
	# the store: the suited inventory on the racks (boxes in Darkmatter violet, a PERPETUAL stencil), the conveyor's rollers
	for rz: float in [34.0, 42.0, 50.0]:
		var rack: Node3D = Props.group(dress, "Rack", Vector3(28, 0, rz))
		for i: int in 9:
			var x: float = -10.0 + 2.5 * float(i)
			Props.block(rack, Vector3(x - 0.45, 0.3, -0.45), Vector3(x + 0.45, 2.2, 0.45), "nachtglas_dim")
			Props.ball(rack, Vector3(x, 2.45, 0), Vector3(0.6, 0.6, 0.6), "glass")
	label("PERPETUAL", Vector3(28, 2.9, 34.7), 180.0, 24, Color(0.85, 0.6, 1.0, 0.8))
	var conv: Node3D = Props.group(dress, "Conveyor", Vector3(28, 0.9, 54.9))
	for i: int in 12:
		Props.cyl(conv, Vector3(-11.0 + 2.0 * float(i), 0, 0), 0.12, 1.3, "steel", Vector3(90, 0, 0))
	# the hall: the nave's ribs
	for rz2: float in [-10.0, 0.0, 10.0, 20.0]:
		Props.strut(dress, Vector3(12.3, 0, rz2), Vector3(28, CEIL_E - 0.2, rz2), 0.25, "steel")
		Props.strut(dress, Vector3(43.7, 0, rz2), Vector3(28, CEIL_E - 0.2, rz2), 0.25, "steel")
	# the Account: the first retained under the floor glass, the pad, the shaft's violet throat
	var pilch: Node3D = Props.group(dress, "Pilch", Vector3(28, 0, -39.75))
	Props.block(pilch, Vector3(-1.5, 0.0, -1.25), Vector3(1.5, 0.5, 1.25), "glass")
	Props.block(pilch, Vector3(-0.25, 0.05, -0.9), Vector3(0.25, 0.35, 0.9), "feldgrau")   # the miner
	Props.ball(pilch, Vector3(0, 0.25, 1.0), Vector3(0.3, 0.3, 0.3), "feldgrau")
	Props.strut(pilch, Vector3(0.3, 0.3, 0), Vector3(0.9, 0.42, -0.1), 0.05, "feldgrau")   # the hand
	for i: int in 4:
		Props.strut(pilch, Vector3(0, 0.45, 0), Vector3(cos(float(i) * 1.6) * 1.2, 0.48, sin(float(i) * 1.6) * 1.1), 0.02, "nachtglas")
	label("PILCH, J.  ·  KB  ·  11.XI.38", Vector3(28, 0.55, -41.0), 180.0, 16, Color(0.9, 0.85, 0.7, 0.9))
	var pad: Node3D = Props.group(dress, "Pad", Vector3(37, 0, -37.5))
	Props.cyl(pad, Vector3(0, 0.12, 0), 2.4, 0.24, "machine_grey")
	Props.cyl(pad, Vector3(0, 0.26, 0), 2.0, 0.04, "nachtglas")
	_noshadow(CYL(Vector3(28, CEIL_F + 3.0, -30), 1.2, 6.0, "nachtglas_dim"))
	# the yard: the dish on its foundation, the smile-crack far over the rim, the field units' tracks
	var dish: Node3D = Props.group(dress, "Dish", Vector3(35, 2.2, 101))
	Props.cyl(dish, Vector3(0, 2.0, 0), 0.3, 4.0, "steel")
	Props.cone(dish, Vector3(0, 4.6, 0), 3.2, 1.2, "steel")
	var smile: Node3D = Props.group(dress, "Smile", Vector3(0, 2.0, 150))
	for i: int in 9:
		var a: float = -0.9 + 0.225 * float(i)
		Props.block(smile, Vector3(-22.0 + 5.0 * float(i), -cos(a) * 3.0, -0.5), Vector3(-17.5 + 5.0 * float(i), -cos(a) * 3.0 + 0.6, 0.5), "nachtglas")
	lamp(Vector3(0, 4.0, 148), VIOLET, 2.5, 50.0, 0.1, 1.5)
	for i: int in 6:
		Props.block(dress, Vector3(-30 + 10.0 * float(i), 0.0, 64.0), Vector3(-29.6 + 10.0 * float(i), 0.03, 108.0), "rock_dark")
	label("MONDLICHT  ·  RR-7", Vector3(0, CEIL_B + 0.8, 60.6), 0.0, 40, Color(0.85, 0.6, 1.0, 0.9))


# ================================================================== gameplay

func build_gameplay_extra() -> void:
	map_root.set("power_on_at_start", true)
	_node("res://gravelight/maps/map04_fernflug/mondlicht_controller.gd", "MondlichtController", {}, Vector3.ZERO)
	_node("res://gravelight/enemies/map04/solar_flare.gd", "SolarFlare", {}, Vector3.ZERO)
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/%s.json" % json_table))
	# the yard's volumes are vacuum (every C_YARD box, closets excluded: there are none)
	for n: Node in gameplay.get_children():
		if n is ZoneVolume and (n as ZoneVolume).zone_id == &"C_YARD":
			n.set("vacuum", true)
			n.set("roam", true)
	# the Earth over the yard
	var e: Dictionary = table.get("earth", {})
	var ep: Array = e.get("position", [0.0, 230.0, 95.0])
	_node("res://gravelight/world/map04/earth_sky.gd", "EarthSky", {"radius": float(e.get("radius", 48.0)), "cfg": e},
		Vector3(float(ep[0]), float(ep[1]), float(ep[2])))
	# the yard's air posts
	_node("res://gravelight/world/map04/air_post.gd", "AirPost_1", {"radius": 2.0}, Vector3(-24, 0, 84))
	_node("res://gravelight/world/map04/air_post.gd", "AirPost_2", {"radius": 2.0}, Vector3(24, 0, 84))
	# the three columns and the sign
	var col: Dictionary = table.get("columns", {})
	var ids: Array = col.get("ids", ["column_1", "column_2", "column_3"])
	var pos: Array = col.get("positions", [[18, 0, 4], [28, 0, 4], [38, 0, 4]])
	var panels: Array = col.get("panels", ["panel.skyhook_sekt", "panel.magpie_mead", "panel.fine_print_fernet"])
	for i: int in ids.size():
		var p: Array = pos[i]
		_node("res://gravelight/world/map04/retention_column.gd", "Column_%d" % (i + 1), {"column_id": StringName(str(ids[i])), "index": i + 1,
			"panel_key": str(panels[i])}, Vector3(float(p[0]), float(p[1]) + 0.3, float(p[2])), 0.0)
	var sg: Dictionary = col.get("sign", {})
	var sp: Array = sg.get("position", [28.0, 6.4, -15.6])
	_node("res://gravelight/world/map04/cancel_sign.gd", "CancelSign", {"text": str(sg.get("text", "NOBODY CANCELS")), "stages": sg.get("stages", [])},
		Vector3(float(sp[0]), float(sp[1]), float(sp[2])), 0.0)
	# the Account: the console, the Manager's station and the crew's pad as markers, the shaft
	_node("res://gravelight/world/map04/account_console.gd", "AccountConsole", {}, Vector3(28, 0, -30), 0.0)
	for m: Array in [["ManagerStation", Vector3(28, 0, -34)], ["CrewPad", Vector3(37, 0.3, -37.5)], ["VacuumShaft", Vector3(28, CEIL_F, -30)], ["EndingCam", Vector3(0, 2.0, 70)]]:
		var mk: Marker3D = Marker3D.new()
		mk.name = str(m[0])
		mk.position = m[1]
		gameplay.add_child(mk)
	# the Account's door opens with the columns
	var d: Node = gameplay.get_node_or_null("Door_Account")
	if d != null:
		d.set("requires_flag", &"account_open")
		d.set("requires_text", "The Account is closed: read the terms")
	# no air outside: the environment's fog is the domes' only (a thin haze), the volumetric fog stays low
	var we: WorldEnvironment = map_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.fog_density = 0.002
		we.environment.volumetric_fog_density = 0.006
		we.environment.fog_sky_affect = 0.0
