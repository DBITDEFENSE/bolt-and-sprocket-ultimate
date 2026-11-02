extends "res://gravelight/tools_src/gen_map04_lib.gd"
## Generates Map 4 Act IV "Mondlicht, the relay station" (UPDATE 07, docs/MAP4_FERNFLUG.md §6): the Provider's Regional
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
##
## UPDATE 09 §5.5 (T-149): the art pass. Every dome its own floor, walls, trim and light (the materials and the
## vocabulary live in detail_map04d.gd); the capsule, the relay's model, Crucible 001's bay, the yard's regolith with
## boot prints and tracks, the crater wall with the smile, the dish over the rim, the racks of suited inventory with
## their tags, the fold pad and the conveyor, the hall's ribs, caps, plates and inlays, the round Account with the
## first retained; the Sun low and hard, a star sky, the airlocks' cycles, the hall's hum. Colliders, nav blocks,
## doors, spawns, prompts and every gameplay node are unchanged (the dressing has no collider).

const D: GDScript = preload("res://gravelight/tools_src/detail_map04d.gd")
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
		# Ledger Lager (T-141): on the concourse's east wall between the Thompson and the store door; Accounts is opposite (bank.json)
		["ledger_lager", Vector3(11.45, 0, 36.6), -90.0],
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
	hide = ["NavBlock*", "Model*", "Rack*", "Conveyor*", "Capsule*", "Desk*", "Pad*", "Pilch*", "Dish*", "Smile*", "Slogan*", "Floor_Domes"]
	sky_top = Color(0.002, 0.002, 0.004)
	sky_horizon = Color(0.008, 0.008, 0.014)
	ambient = Color(0.17, 0.15, 0.26)
	fog_color = Color(0.02, 0.015, 0.03)
	moon_rot = Vector3(-62, 25, 0)   # replaced in gameplay_extra: the Sun from map04d.json earth.sun_dir (T-149)


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
	_finish_geometry()


func _reception() -> void:
	wall_x("A_S", 0.0, -12 - T * 0.5, 12 + T * 0.5, 0, CEIL_A, [], "wall")
	wall_z("A_W", -12.0, 0, 24, 0, CEIL_A, [win(8, 0)], "wall")
	wall_z("A_E", 12.0, 0, 24, 0, CEIL_A, [win(8, 0)], "wall")
	wall_x("AB", 24.0, -12 - T * 0.5, 12 + T * 0.5, 0, CEIL_A, [door(0, 0, 2.4)], "wall")
	box(geo, "DomeRoof_A", Vector3(-12.3, CEIL_A, -0.3), Vector3(12.3, CEIL_A + 0.3, 24.3), "roof", false)
	# the capsule, nose up in its cradle, and the reception desk with the bell
	box(geo, "NavBlock_Capsule", Vector3(-9.5, 0, 1.5), Vector3(-5.5, 3.5, 5.5), "metal")
	box(geo, "NavBlock_Desk", Vector3(6.0, 0, 14.0), Vector3(11.3, 1.0, 15.2), "furniture")   # clear of the Second Wind cabinet's approach (the playtest bot's errand)


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
	for b: Array in BOULDERS:
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
	for rz: float in RACK_Z:
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


## U09 s5 (T-149): each dome its own finish. The colliders keep their boxes; only their meshes change material:
## the reception white enamel, the concourse violet, the store's profiled sheet, the hall a deeper violet, the
## Account graphite-violet; every hull face that the yard sees is the outside skin, the roofs are hull on top.
func _finish_geometry() -> void:
	for p: Array in [["A_", "dm_white"], ["AB_", "dm_white"], ["B_", "dm_violet"], ["BC_", "dm_violet"], ["C_S_W", "hull"], ["CD_", "hull"],
			["D_E", "wall_d"], ["DE_", "wall_d"], ["E_", "dm_violet_hall"], ["EF_", "dm_violet_hall"], ["F_", "dm_f_wall"],
			["Hull_Airlock", "dm_offwhite"], ["DomeRoof", "hull"], ["Shaft_Wall", "dm_steel_dark"], ["Regolith", "regolith"],
			["Rim_", "rim_rock"], ["Rim_DishBase", "concrete"]]:
		D.paint(geo, str(p[0]), str(p[1]))


# ================================================================== dressing

const BOULDERS: Array = [[Vector3(-24, 0, 70), Vector3(-20, 1.6, 73)], [Vector3(18, 0, 92), Vector3(22, 1.4, 95)], [Vector3(-8, 0, 100), Vector3(-4, 1.9, 103)],
	[Vector3(30, 0, 72), Vector3(33, 1.2, 75)], [Vector3(-32, 0, 92), Vector3(-29, 2.0, 95)]]
const RACK_Z: Array = [34.0, 42.0, 50.0]
const YARD_C: Vector3 = Vector3(0, 0, 86)
const FAR_DISH: Vector3 = Vector3(64, 7.0, 146)
const CREW: Dictionary = {   # rack 2, bays 4-6: the Kranich's three (INT_M4_CREWTAGS, Wren's harness tags in Act II)
	"2_4": "RIEDL, A.\nBORDMECHANIKER\nPROVIDED 2.V.45\nRR-7 · RACK 2 · BAY 4",
	"2_5": "HAAS, W.\nBORDSCHÜTZE\nPROVIDED 2.V.45\nRR-7 · RACK 2 · BAY 5",
	"2_6": "POHL, K.\nBORDSCHÜTZE\nPROVIDED 2.V.45\nRR-7 · RACK 2 · BAY 6",
}

var _sun_dir: Vector3 = Vector3(0.88, 0.26, -0.31)


func build_dressing() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/%s.json" % json_table))
	var sd: Array = (table.get("earth", {}) as Dictionary).get("sun_dir", [0.88, 0.26, -0.31])
	_sun_dir = Vector3(float(sd[0]), float(sd[1]), float(sd[2])).normalized()
	_dress_shell()
	_dress_reception()
	_dress_concourse()
	_dress_yard()
	_dress_store()
	_dress_hall()
	_dress_account()
	print("  shadow diet: %d small/flat/ceiling pieces stop casting" % D.shadow_diet(dress, _ceil_at))
	print("  dressing triangles: %s" % D.tally(dress))
	print("  zone batches (ViewCells): %d" % D.merge_by_group(dress, map_root, _vis_group))


## A point's visibility group for ViewCells: the dome it stands in, else the yard (the crater, the dish, the smile).
func _vis_group(p: Vector3) -> String:
	for z: Array in [[-12.0, 12.0, 0.0, 24.0, "A_RECEPTION"], [-12.0, 12.0, 24.0, 60.0, "B_CONCOURSE"], [12.0, 44.0, 24.0, 60.0, "D_FULFILLMENT"],
			[12.0, 44.0, -16.0, 24.0, "E_HALL"], [14.0, 42.0, -44.0, -16.0, "F_CORE"]]:
		if p.x >= float(z[0]) and p.x <= float(z[1]) and p.z >= float(z[2]) and p.z <= float(z[3]):
			return str(z[4])
	return "C_YARD" if p.z >= 58.0 else "ALL"


## The ceiling over a point (0 in the yard and outside): the shadow diet's "near the ceiling" rule.
func _ceil_at(p: Vector3) -> float:
	for z: Array in [[-12.0, 12.0, 0.0, 24.0, CEIL_A], [-12.0, 12.0, 24.0, 60.0, CEIL_B], [12.0, 44.0, 24.0, 60.0, CEIL_D],
			[12.0, 44.0, -16.0, 24.0, CEIL_E], [14.0, 42.0, -44.0, -16.0, CEIL_F]]:
		if p.x >= float(z[0]) and p.x <= float(z[1]) and p.z >= float(z[2]) and p.z <= float(z[3]):
			return float(z[4])
	return 0.0


## Floors per dome (the shared Floor_Domes collider is hidden; an apron of regolith under the service hatches),
## the shared walls' second faces, ceilings, skirting / cornice / coves / pilasters, door and window frames.
func _dress_shell() -> void:
	D.blk(dress, Vector3(-14, -0.5, -46), Vector3(46, -0.03, 62), "regolith").set_meta("vis", "ALL")
	for f: Array in [[Vector3(-12, -0.1, 0), Vector3(12, 0, 24), "floor_a"], [Vector3(-12, -0.1, 24), Vector3(12, 0, 60), "floor_b"],
			[Vector3(12, -0.1, 24), Vector3(44, 0, 60), "floor_d"], [Vector3(12, -0.1, -16), Vector3(44, 0, 24), "floor_e"],
			[Vector3(14, -0.1, -44), Vector3(42, 0, -16), "floor_f"]]:
		D.blk(dress, f[0], f[1], str(f[2]))
	# the second face of every shared wall, and the yard side of the hulls
	D.skin(dress, D.segments(geo, "AB_"), Vector3(0, 0, 1), "dm_violet")
	D.skin(dress, D.segments(geo, "BC_"), Vector3(0, 0, 1), "hull")
	D.skin(dress, D.segments(geo, "CD_"), Vector3(0, 0, -1), "wall_d")
	D.skin(dress, D.segments(geo, "DE_"), Vector3(0, 0, -1), "dm_violet_hall")
	D.skin(dress, D.segments(geo, "EF_"), Vector3(0, 0, -1), "dm_f_wall")
	D.skin(dress, D.segments(geo, "B_E"), Vector3(1, 0, 0), "wall_d")
	# A_E and E_W stand in the same place for z 0..24 (as built): a skin on each face hides the coplanar pair
	D.skin(dress, D.segments(geo, "A_E"), Vector3(-1, 0, 0), "dm_white")
	D.skin(dress, D.segments(geo, "E_W"), Vector3(1, 0, 0), "dm_violet_hall")
	for o: Array in [["A_E", Vector3(1, 0, 0)], ["A_W", Vector3(-1, 0, 0)], ["A_S", Vector3(0, 0, -1)], ["B_W", Vector3(-1, 0, 0)], ["D_E", Vector3(1, 0, 0)],
			["E_E", Vector3(1, 0, 0)], ["F_W", Vector3(-1, 0, 0)], ["F_E", Vector3(1, 0, 0)], ["F_S", Vector3(0, 0, -1)]]:
		D.skin(dress, D.segments(geo, str(o[0])), o[1], "hull")
	# ceilings: a skin under each roof in the room's tone (the roof box itself is hull on top)
	for c: Array in [[Vector3(-12, CEIL_A - 0.02, 0), Vector3(12, CEIL_A, 24), "dm_white"], [Vector3(-12, CEIL_B - 0.02, 24), Vector3(12, CEIL_B, 60), "dm_violet_hall"],
			[Vector3(12, CEIL_D - 0.02, 24), Vector3(44, CEIL_D, 60), "dm_offwhite"], [Vector3(12, CEIL_E - 0.02, -16), Vector3(44, CEIL_E, 24), "dm_violet_deep"],
			[Vector3(14, CEIL_F - 0.02, -44), Vector3(25.5, CEIL_F, -16), "dm_graphite"], [Vector3(30.5, CEIL_F - 0.02, -44), Vector3(42, CEIL_F, -16), "dm_graphite"],
			[Vector3(25.5, CEIL_F - 0.02, -44), Vector3(30.5, CEIL_F, -32.5), "dm_graphite"], [Vector3(25.5, CEIL_F - 0.02, -27.5), Vector3(30.5, CEIL_F, -16), "dm_graphite"]]:
		D.blk(dress, c[0], c[1], str(c[2]), false)
	# trim: (wall prefix, face normal, ceiling, skirting, cornice, cove, pilaster step)
	for t: Array in [["A_W", Vector3(1, 0, 0), CEIL_A, "dm_graphite", "dm_chrome", "dm_glow_white", 4.0], ["A_E", Vector3(-1, 0, 0), CEIL_A, "dm_graphite", "dm_chrome", "dm_glow_white", 4.0],
			["A_S", Vector3(0, 0, 1), CEIL_A, "dm_graphite", "dm_chrome", "dm_glow_white", 4.0], ["AB_", Vector3(0, 0, -1), CEIL_A, "dm_graphite", "dm_chrome", "dm_glow_white", 0.0],
			["AB_", Vector3(0, 0, 1), CEIL_B, "dm_graphite", "dm_chrome", "dm_glow_violet", 0.0], ["B_W", Vector3(1, 0, 0), CEIL_B, "dm_graphite", "dm_chrome", "dm_glow_violet", 4.0],
			["B_E", Vector3(-1, 0, 0), CEIL_B, "dm_graphite", "dm_chrome", "dm_glow_violet", 4.0], ["BC_", Vector3(0, 0, -1), CEIL_B, "dm_graphite", "dm_chrome", "dm_glow_violet", 0.0],
			["D_E", Vector3(-1, 0, 0), CEIL_D, "dm_steel_dark", "dm_steel_dark", "", 4.0], ["CD_", Vector3(0, 0, -1), CEIL_D, "dm_steel_dark", "dm_steel_dark", "", 4.0],
			["DE_", Vector3(0, 0, 1), CEIL_D, "dm_steel_dark", "dm_steel_dark", "", 4.0], ["B_E", Vector3(1, 0, 0), CEIL_D, "dm_steel_dark", "dm_steel_dark", "", 4.0],
			["E_W", Vector3(1, 0, 0), CEIL_E, "dm_graphite", "dm_chrome", "dm_glow_violet_soft", 0.0], ["E_E", Vector3(-1, 0, 0), CEIL_E, "dm_graphite", "dm_chrome", "dm_glow_violet_soft", 0.0],
			["DE_", Vector3(0, 0, -1), CEIL_E, "dm_graphite", "dm_chrome", "dm_glow_violet_soft", 0.0], ["EF_", Vector3(0, 0, 1), CEIL_E, "dm_graphite", "dm_chrome", "dm_glow_violet_soft", 0.0],
			["F_W", Vector3(1, 0, 0), CEIL_F, "dm_chrome_dark", "dm_chrome", "dm_glow_violet", 3.5], ["F_E", Vector3(-1, 0, 0), CEIL_F, "dm_chrome_dark", "dm_chrome", "dm_glow_violet", 3.5],
			["F_S", Vector3(0, 0, 1), CEIL_F, "dm_chrome_dark", "dm_chrome", "dm_glow_violet", 3.5], ["EF_", Vector3(0, 0, -1), CEIL_F, "dm_chrome_dark", "dm_chrome", "dm_glow_violet", 0.0]]:
		var segs: Array = D.segments(geo, str(t[0]))
		if str(t[0]) == "DE_" and float(t[2]) == CEIL_D:
			segs = _clip_y(segs, CEIL_D)
		if str(t[0]) == "B_E" and float(t[2]) == CEIL_D:
			segs = _clip_y(segs, CEIL_D)
		D.trim(dress, segs, t[1], float(t[2]), str(t[3]), str(t[4]), str(t[5]), float(t[6]))
	# door frames (outside the openings) on both faces, and window frames on the room side
	for d: Array in doors:
		_door_frame(d[7], float(d[8]), float(d[9]))
	for w: Array in windows:
		_window_frame(w[2], float(w[3]))


## Wall segments cut to a lower ceiling (DE and B_E are taller than the store's lid).
func _clip_y(segs: Array, top: float) -> Array:
	var out: Array = []
	for s: Array in segs:
		var lo: Vector3 = s[0]
		var hi: Vector3 = s[1]
		if lo.y >= top:
			continue
		out.append([lo, Vector3(hi.x, minf(hi.y, top), hi.z)])
	return out


func _door_frame(p: Vector3, yaw: float, w: float) -> void:
	var g: Node3D = Props.group(dress, "DoorFrame", p, yaw)
	for side: float in [-1.0, 1.0]:
		var zf: float = side * (T * 0.5)
		var zo: float = side * (T * 0.5 + 0.08)
		for s: float in [-1.0, 1.0]:
			D.blk(g, Vector3(s * (w * 0.5), 0.0, minf(zf, zo)), Vector3(s * (w * 0.5 + 0.22), DOOR_H + 0.3, maxf(zf, zo)), "dm_chrome")
			D.blk(g, Vector3(s * (w * 0.5 + 0.04), 0.3, minf(zo, zo + side * 0.01)), Vector3(s * (w * 0.5 + 0.08), DOOR_H - 0.1, maxf(zo, zo + side * 0.01)), "dm_glow_violet", false)
		D.blk(g, Vector3(-w * 0.5 - 0.22, DOOR_H, minf(zf, zo)), Vector3(w * 0.5 + 0.22, DOOR_H + 0.3, maxf(zf, zo)), "dm_chrome")
		D.blk(g, Vector3(-w * 0.5, DOOR_H + 0.1, minf(zo, zo + side * 0.012)), Vector3(w * 0.5, DOOR_H + 0.16, maxf(zo, zo + side * 0.012)), "dm_glow_violet", false)
		# Darkmatter's chevrons on the threshold (flat, flush)
		for k: int in 5:
			var x0: float = -w * 0.5 + w * (float(k) + 0.25) / 5.0
			D.obx(g, Vector3(x0 + w * 0.05, 0.004, side * (T * 0.5 + 0.25)), Vector3(w * 0.1, 0.008, 0.32), "dm_glow_violet_soft", Vector3(0, 35.0 * side, 0))


func _window_frame(p: Vector3, inward_yaw: float) -> void:
	var g: Node3D = Props.group(dress, "WindowFrame", p, inward_yaw)
	var z0: float = T * 0.5
	D.blk(g, Vector3(-0.95, SILL - 0.12, z0), Vector3(0.95, SILL, z0 + 0.1), "dm_chrome")
	D.blk(g, Vector3(-0.95, WTOP, z0), Vector3(0.95, WTOP + 0.12, z0 + 0.06), "dm_chrome")
	for s: float in [-1.0, 1.0]:
		D.blk(g, Vector3(s * 0.8, SILL, z0), Vector3(s * 0.95, WTOP, z0 + 0.06), "dm_chrome")
	D.text(g, "SERVICE HATCH", Vector3(0, WTOP + 0.22, z0 + 0.03), 0.0, 22, Color(0.85, 0.82, 0.9, 0.85), 0.0, 0.003)


# ------------------------------------------------------------------ A Reception

func _dress_reception() -> void:
	# ceiling ribs across X and white luminaires between them
	for z: float in [4.0, 8.0, 12.0, 16.0, 20.0]:
		D.blk(dress, Vector3(-11.85, CEIL_A - 0.35, z - 0.12), Vector3(11.85, CEIL_A - 0.02, z + 0.12), "dm_offwhite")
	for z2: float in [6.0, 10.0, 14.0, 18.0, 22.0]:
		D.strip(dress, Vector3(-4.5, CEIL_A - 0.12, z2), 5.0, true)
		D.strip(dress, Vector3(4.5, CEIL_A - 0.12, z2), 5.0, true)
	_capsule()
	_landing_pad()
	_reception_desk()
	_airlock_reception()
	# the rack tag over the Kar98k, and the hatch numbers
	D.text(dress, "ANOMALOUS INVENTORY", Vector3(-11.83, 2.45, 16.0), 90.0, 26, Color(0.9, 0.86, 0.95, 0.9), 0.0)
	D.sign(dress, "LANDING DOME", Vector3(-11.83, 4.6, 6.5), 90.0, 4.2, 0.6, 52)
	D.sign(dress, "ARRIVALS", Vector3(11.83, 4.6, 6.5), -90.0, 3.4, 0.6, 52)
	# lights: the key falls on the capsule; strips; the airlock's violet; the desk's glow; the pad lamps
	D.spot(map_root, "KeySpot_A_Capsule", Vector3(-4.2, CEIL_A - 1.2, 7.4), Vector3(-7.5, 0.9, 3.5), D.COLD, 6.0, 12.0, 24.0, "A_RECEPTION", true)
	D.omni(map_root, "Lamp_A_Strip_1", Vector3(0, CEIL_A - 0.6, 8.0), D.COLD, 1.6, 15.0, "A_RECEPTION")
	D.omni(map_root, "Lamp_A_Strip_2", Vector3(0, CEIL_A - 0.6, 18.0), D.COLD, 1.4, 13.0, "A_RECEPTION")
	D.omni(map_root, "Lamp_A_Airlock", Vector3(0, 4.6, 22.6), VIOLET, 1.2, 8.0, "A_RECEPTION")
	D.omni(map_root, "Lamp_A_Desk", Vector3(8.6, 2.2, 13.2), D.VIOLET, 0.6, 5.0, "A_RECEPTION")
	D.omni(map_root, "Lamp_A_Pad", Vector3(-7.5, 0.4, 3.5), D.AMBER, 0.7, 6.5, "A_RECEPTION")


## The LANTERN capsule (Act III's rocket, Act IV's arrival), nose up in its cradle on the landing pad: a lathe
## body with the scorched heat shield, an open hatch with its steps, two portholes, the chute housing, three legs.
func _capsule() -> void:
	var cap: Node3D = Props.group(dress, "Capsule", Vector3(-7.5, 0, 3.5))
	var body: PackedVector2Array = PackedVector2Array([Vector2(0, 0.62), Vector2(1.1, 0.66), Vector2(1.42, 0.86), Vector2(1.48, 1.02),
		Vector2(1.4, 1.18), Vector2(0.74, 2.92), Vector2(0.64, 3.0), Vector2(0.6, 3.32), Vector2(0.42, 3.46), Vector2(0.0, 3.5)])
	D.keep(cap, "CapsuleBody", D.lathe(body, 28), Transform3D.IDENTITY, "capsule")
	var shield: PackedVector2Array = PackedVector2Array([Vector2(0, 0.58), Vector2(1.14, 0.63), Vector2(1.46, 0.84), Vector2(1.51, 1.02), Vector2(1.44, 1.2)])
	D.keep(cap, "CapsuleShield", D.lathe(shield, 28), Transform3D.IDENTITY, "capsule_scorch")
	var band: PackedVector2Array = PackedVector2Array([Vector2(1.24, 1.62), Vector2(1.06, 2.08)])
	D.keep(cap, "CapsuleBand", D.lathe(band, 28), Transform3D(Basis.IDENTITY, Vector3(0.012, 0, 0)), "capsule_paint")
	# the hatch (facing the room, +X), open on its hinge, the steps down, the portholes, the stencil
	D.obx(cap, Vector3(1.13, 1.95, 0.0), Vector3(0.06, 0.95, 0.72), "dm_black_glass", Vector3(0, 0, 21.0))
	D.obx(cap, Vector3(1.32, 1.95, 0.62), Vector3(0.7, 0.92, 0.06), "capsule", Vector3(0, -12.0, 21.0))
	for k: int in 3:
		D.blk(cap, Vector3(1.55 + 0.0 * k, 0.3 + 0.45 * float(k), -0.3), Vector3(1.85, 0.34 + 0.45 * float(k), 0.3), "dm_chrome")
	D.strut(cap, Vector3(1.85, 0.0, -0.32), Vector3(1.55, 1.45, -0.32), 0.04, "dm_chrome")
	D.strut(cap, Vector3(1.85, 0.0, 0.32), Vector3(1.55, 1.45, 0.32), 0.04, "dm_chrome")
	for zs: float in [-1.0, 1.0]:
		D.cyl(cap, Vector3(0.0, 2.35, zs * 0.95), 0.14, 0.06, "dm_chrome", Vector3(90, 0, 0))
		D.cyl(cap, Vector3(0.0, 2.35, zs * 0.985), 0.1, 0.02, "dm_black_glass", Vector3(90, 0, 0))
	Props.stencil(cap, Vector3(-0.0, 1.95, -1.17), 180.0, "LANTERN", 64, Color(0.12, 0.11, 0.1, 0.9))
	# the cradle: three legs with pads, a ring
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0 + 0.5
		var foot: Vector3 = Vector3(cos(a) * 1.85, 0.0, sin(a) * 1.85)
		D.strut(cap, foot + Vector3(0, 0.05, 0), Vector3(cos(a) * 1.05, 1.0, sin(a) * 1.05), 0.12, "dm_steel_dark")
		D.cyl(cap, foot + Vector3(0, 0.04, 0), 0.26, 0.08, "dm_steel_dark")
	# the spent chute in the corner, lines to the nose
	var chute: Node3D = Props.group(dress, "Chute", Vector3(-10.6, 0, 1.6))
	for b: Array in [[Vector3(0, 0.12, 0), Vector3(1.6, 0.3, 1.2)], [Vector3(0.5, 0.18, 0.4), Vector3(1.1, 0.34, 0.9)], [Vector3(-0.3, 0.1, 0.5), Vector3(0.9, 0.2, 0.8)]]:
		D.ball(chute, b[0], b[1], "dm_offwhite")
	for k2: int in 4:
		Props.cable(dress, Vector3(-7.5, 3.4, 3.5), Vector3(-10.4 + 0.3 * float(k2), 0.2, 1.4 + 0.2 * float(k2)), 0.6, 0.008, 6, "rubber")
	# the scorch on the pad
	D.patch(dress, Vector3(-7.5, 0, 3.5), Vector2(6.0, 6.0), 0.0, "", Vector2.ONE, Color(0.02, 0.018, 0.02, 0.8), 1.8)


## The pad the field units left lit (Darkmatter expected deliveries): a violet ring, amber lamps, a floor stencil.
func _landing_pad() -> void:
	var pad: Node3D = Props.group(dress, "LandingPad", Vector3(-7.5, 0, 3.5))
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		D.obx(pad, Vector3(cos(a) * 3.1, 0.005, sin(a) * 3.1), Vector3(0.62, 0.01, 0.1), "dm_glow_violet_soft", Vector3(0, -rad_to_deg(a) + 90.0, 0))
	for j: int in 8:
		var b: float = TAU * float(j) / 8.0 + 0.2
		D.blk(pad, Vector3(cos(b) * 3.5 - 0.09, 0.0, sin(b) * 3.5 - 0.09), Vector3(cos(b) * 3.5 + 0.09, 0.04, sin(b) * 3.5 + 0.09), "dm_glow_amber", false)
	var l: Label3D = D.text(pad, "DELIVERIES", Vector3(0.0, 0.012, 4.15), 0.0, 72, Color(0.75, 0.55, 1.0, 0.7), 1.2)
	l.rotation = Vector3(-PI * 0.5, 0.0, 0.0)


func _reception_desk() -> void:
	var desk: Node3D = Props.group(dress, "Desk", Vector3(8.65, 0, 14.6))
	D.blk(desk, Vector3(-2.6, 0.0, -0.55), Vector3(2.6, 0.08, 0.55), "dm_graphite")
	D.blk(desk, Vector3(-2.62, 0.08, -0.58), Vector3(2.62, 0.94, 0.58), "dm_white")
	D.blk(desk, Vector3(-2.65, 0.94, -0.65), Vector3(2.65, 1.0, 0.65), "dm_black_glass")
	D.blk(desk, Vector3(-2.66, 0.92, -0.66), Vector3(2.66, 0.95, -0.64), "dm_chrome")
	D.blk(desk, Vector3(-2.6, 0.66, -0.6), Vector3(2.6, 0.69, -0.585), "dm_glow_violet", false)
	D.logo(desk, Vector3(-1.6, 0.4, -0.595), 0.34)
	D.text(desk, "RECEPTION", Vector3(0.2, 0.4, -0.592), 180.0, 52, Color(0.25, 0.14, 0.4, 1.0), 0.0)
	Props.bell(desk, Vector3(1.8, 1.0, 0), 0.18, "brass")
	# a tented card by the bell, a terminal at the far end
	D.obx(desk, Vector3(1.25, 1.07, -0.25), Vector3(0.24, 0.14, 0.01), "dm_graphite", Vector3(-20, 180, 0))
	D.text(desk, "PLEASE RING\nFOR ASSISTANCE", Vector3(1.25, 1.07, -0.262), 180.0, 14, Color(0.85, 0.75, 1.0, 1.0), 1.2, 0.0025).rotate_object_local(Vector3.RIGHT, deg_to_rad(20.0))
	D.blk(desk, Vector3(2.15, 1.0, 0.2), Vector3(2.55, 1.04, 0.5), "dm_graphite")
	D.obx(desk, Vector3(2.35, 1.26, 0.38), Vector3(0.46, 0.32, 0.03), "dm_black_glass", Vector3(-8, 0, 0))
	D.obx(desk, Vector3(2.35, 1.26, 0.362), Vector3(0.4, 0.26, 0.01), "dm_glow_screen", Vector3(-8, 0, 0))
	# the hanging sign over it, both faces
	for y: float in [0.0, 180.0]:
		D.sign(dress, "RECEPTION", Vector3(8.65, 3.4, 14.6 + (0.03 if y == 0.0 else -0.03)), y, 3.0, 0.6, 56)
	for xs: float in [-1.2, 1.2]:
		D.strut(dress, Vector3(8.65 + xs, 3.72, 14.6), Vector3(8.65 + xs, CEIL_A - 0.35, 14.6), 0.015, "dm_chrome")


## The reception airlock (the concourse door): frames, the cycle panel, the welcome sign over it.
func _airlock_reception() -> void:
	D.sign(dress, "WELCOME, VALUED CUSTOMERS", Vector3(0, 4.4, 23.82), 180.0, 8.2, 1.0, 76)
	_cycle_panel(Vector3(2.15, 1.35, 23.82), 180.0)
	_cycle_panel(Vector3(-2.15, 1.35, 24.18), 0.0)


func _cycle_panel(p: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(dress, "CyclePanel", p, yaw)
	D.blk(g, Vector3(-0.22, -0.32, -0.05), Vector3(0.22, 0.32, 0.0), "dm_graphite")
	D.blk(g, Vector3(-0.17, -0.02, 0.0), Vector3(0.17, 0.24, 0.008), "dm_glow_screen", false)
	D.blk(g, Vector3(-0.12, -0.24, 0.0), Vector3(-0.02, -0.14, 0.02), "dm_glow_red", false)
	D.blk(g, Vector3(0.02, -0.24, 0.0), Vector3(0.12, -0.14, 0.02), "dm_glow_violet", false)
	D.text(g, "CYCLE", Vector3(0, 0.11, 0.012), 0.0, 18, Color(0.85, 0.75, 1.0, 1.0), 1.4, 0.003)


# ------------------------------------------------------------------ B Concourse

func _dress_concourse() -> void:
	# the light channel down the hall and the cross ribs
	for z: float in [28.0, 34.0, 40.0, 46.0, 52.0, 56.0]:
		D.blk(dress, Vector3(-11.85, CEIL_B - 0.3, z - 0.1), Vector3(11.85, CEIL_B - 0.02, z + 0.1), "dm_violet_deep")
	for x: float in [-3.5, 3.5]:
		for z0: float in [26.5, 41.0]:
			D.strip(dress, Vector3(x, CEIL_B - 0.1, z0 + 6.5), 12.5, false, "dm_glow_violet")
	# slogans: lit signage in the house type, high on the walls (the localized language the squad can read)
	D.sign(dress, "REGIONAL RETENTION RELAY RR-7", Vector3(0, 3.7, 24.18), 0.0, 8.4, 0.9, 64)
	D.sign(dress, "EXCEPTIONAL RETENTION", Vector3(-11.83, 3.55, 50.0), 90.0, 6.2, 0.8, 60)
	D.sign(dress, "WE'LL TAKE CARE OF EVERYTHING", Vector3(11.83, 3.55, 35.0), -90.0, 7.4, 0.8, 60)
	D.sign(dress, "THANK YOU FOR YOUR CONTINUED ENGAGEMENT", Vector3(-11.83, 3.55, 29.5), 90.0, 8.4, 0.7, 50)
	D.sign(dress, "WE DELIVER BEFORE YOU ASK", Vector3(11.83, 3.55, 54.5), -90.0, 6.4, 0.8, 58)
	D.sign(dress, "FULFILLMENT  ›", Vector3(11.83, 3.0, 42.0), -90.0, 3.4, 0.55, 46)
	D.sign(dress, "THE YARD  ·  PLEASE FASTEN YOUR SUIT", Vector3(0, 3.55, 58.15), 180.0, 7.4, 0.7, 50)
	D.text(dress, "AIR IS PROVIDED AS A COURTESY", Vector3(0, 3.0, 58.14), 180.0, 30, Color(0.85, 0.78, 0.95, 0.9), 1.0)
	_relay_model()
	_crucible_bay()
	# the prototype cabinets' plates (INT_M4_RELAY: "cabinets 2-3")
	D.text(dress, "PROTOTYPE CABINET 2", Vector3(-11.83, 2.45, 30.0), 90.0, 24, Color(0.85, 0.82, 0.9, 0.9), 0.0)
	D.text(dress, "PROTOTYPE CABINET 3", Vector3(11.83, 2.45, 30.0), -90.0, 24, Color(0.85, 0.82, 0.9, 0.9), 0.0)
	# two lobby benches against the west wall (the wait is long)
	for bz: float in [51.4, 53.6]:
		D.blk(dress, Vector3(-11.85, 0.42, bz - 0.95), Vector3(-11.3, 0.48, bz + 0.95), "dm_graphite")
		for lz: float in [-0.8, 0.8]:
			D.blk(dress, Vector3(-11.8, 0.0, bz + lz - 0.04), Vector3(-11.35, 0.42, bz + lz + 0.04), "dm_chrome")
	_airlock_yard()
	# lights: violet strips, the model's key, the Crucible's bay
	for i: int in 3:
		D.omni(map_root, "Lamp_B_Strip_%d" % i, Vector3(0, CEIL_B - 0.5, 30.0 + 12.0 * float(i)), VIOLET, 2.4, 15.0, "B_CONCOURSE")
	for wx: float in [-8.5, 8.5]:
		D.omni(map_root, "Lamp_B_Wash_%d" % int(wx), Vector3(wx, 3.4, 44.0), Color(0.78, 0.7, 1.0), 1.3, 11.0, "B_CONCOURSE")
	D.spot(map_root, "KeySpot_B_Model", Vector3(0, CEIL_B - 0.25, 35.5), Vector3(0, 1.2, 39.0), D.COLD, 5.0, 9.0, 34.0, "B_CONCOURSE", true)
	D.spot(map_root, "KeySpot_B_Crucible", Vector3(-6.5, CEIL_B - 0.25, 46.0), Vector3(-8.0, 0.8, 46.0), D.VIOLET, 4.0, 8.0, 32.0, "B_CONCOURSE", false)
	D.omni(map_root, "Lamp_B_Airlock", Vector3(0, 3.0, 57.2), D.COLD, 0.8, 7.0, "B_CONCOURSE")


## The relay in miniature under glass (the minimap's floor plan, in-world): the domes, the yard, the rim, the dish,
## a violet thread to a little Earth painted the wrong colour (INT_M4_RELAY's note).
func _relay_model() -> void:
	var g: Node3D = Props.group(dress, "Model", Vector3(0, 0, 39.0))
	D.blk(g, Vector3(-1.55, 0.0, -1.55), Vector3(1.55, 0.06, 1.55), "dm_chrome_dark")
	D.blk(g, Vector3(-1.5, 0.06, -1.5), Vector3(1.5, 1.0, 1.5), "dm_graphite")
	D.blk(g, Vector3(-1.52, 0.86, -1.52), Vector3(1.52, 0.9, 1.52), "dm_glow_violet", false)
	D.blk(g, Vector3(-1.55, 1.0, -1.55), Vector3(1.55, 1.06, 1.55), "dm_chrome")
	D.blk(g, Vector3(-1.48, 1.06, -1.48), Vector3(1.48, 1.08, 1.48), "dm_black_glass")
	# the case: glass, chrome posts and lid
	D.blk(g, Vector3(-1.5, 1.08, -1.5), Vector3(1.5, 2.2, 1.5), "dm_glass")
	for c: Vector2 in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		D.blk(g, Vector3(c.x - 0.03, 1.06, c.y - 0.03), Vector3(c.x + 0.03, 2.22, c.y + 0.03), "dm_chrome")
	D.blk(g, Vector3(-1.53, 2.2, -1.53), Vector3(1.53, 2.24, 1.53), "dm_chrome")
	# the plan at 1:60 (world x,z -> model (x-2)/60, (z-33)/60), y on the deck
	var m: Node3D = Props.group(g, "Plan", Vector3(0, 1.08, 0))
	var s: float = 1.0 / 60.0
	var to_m: Callable = func(wx: float, wz: float) -> Vector3: return Vector3((wx - 2.0) * s, 0.0, (wz - 33.0) * s)
	D.blk(m, to_m.call(-42.0, 60.0) + Vector3(0, 0.0, 0), to_m.call(42.0, 112.0) + Vector3(0, 0.02, 0), "regolith")
	for dm: Array in [[0.0, 12.0, 24.0, 24.0, 7.0], [0.0, 42.0, 24.0, 36.0, 5.0], [28.0, 42.0, 32.0, 36.0, 5.0], [28.0, 4.0, 32.0, 40.0, 9.0], [28.0, -30.0, 28.0, 28.0, 7.0]]:
		var cpos: Vector3 = to_m.call(float(dm[0]), float(dm[1]))
		D.blk(m, cpos - Vector3(float(dm[2]) * s * 0.5, 0.0, float(dm[3]) * s * 0.5), cpos + Vector3(float(dm[2]) * s * 0.5, float(dm[4]) * s, float(dm[3]) * s * 0.5), "dm_white")
		D.ball(m, cpos + Vector3(0, float(dm[4]) * s, 0), Vector3(float(dm[2]) * s * 0.9, 0.08, float(dm[3]) * s * 0.9), "dm_offwhite")
	for r: Array in [[Vector3(-42, 0, 60), Vector3(-40, 3, 112)], [Vector3(40, 0, 60), Vector3(42, 3, 112)], [Vector3(-42, 0, 110), Vector3(42, 3, 112)]]:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		D.blk(m, to_m.call(a.x, a.z), to_m.call(b.x, b.z) + Vector3(0, b.y * s * 2.0, 0), "rim_rock")
	var dish: Vector3 = to_m.call(35.0, 101.0)
	D.strut(m, dish, dish + Vector3(0, 0.12, 0), 0.008, "dm_chrome")
	D.cone(m, dish + Vector3(0, 0.15, 0), 0.06, 0.04, "dish", Vector3(180, 0, 0))
	var earth: Vector3 = Vector3(-0.3, 0.98, 0.95)
	D.ball(m, earth, Vector3.ONE * 0.16, "capsule_paint")   # the little Earth: painted ochre, not blue
	D.strut(m, dish + Vector3(0, 0.15, 0), earth, 0.006, "dm_glow_violet")
	D.strut(m, earth + Vector3(0, 0.08, 0), Vector3(earth.x, 1.12, earth.z), 0.003, "dm_chrome")
	# the plate's bracket off the plinth's south face (INT_M4_RELAY rests on it)
	D.obx(g, Vector3(0, 1.05, -1.95), Vector3(0.62, 0.03, 0.42), "dm_chrome", Vector3(-12, 0, 0))
	D.blk(g, Vector3(-0.04, 0.95, -1.75), Vector3(0.04, 1.04, -1.5), "dm_chrome")


## Crucible 001: the original violet unit (MOD. R-E · PAT. PEND. BLZ-40417 · UNIT 001), a lit alcove and its plaque.
func _crucible_bay() -> void:
	D.blk(dress, Vector3(-11.85, 0.2, 44.3), Vector3(-11.82, 3.4, 47.7), "dm_glow_violet_soft", false)
	D.blk(dress, Vector3(-11.85, 0.15, 44.15), Vector3(-11.75, 0.2, 47.85), "dm_chrome")
	D.blk(dress, Vector3(-11.85, 3.4, 44.15), Vector3(-11.75, 3.48, 47.85), "dm_chrome")
	for zz: float in [44.15, 47.75]:
		D.blk(dress, Vector3(-11.85, 0.15, zz), Vector3(-11.75, 3.48, zz + 0.1), "dm_chrome")
	for i: int in 20:
		var a: float = TAU * float(i) / 20.0
		D.obx(dress, Vector3(-8.0 + cos(a) * 1.7, 0.005, 46.0 + sin(a) * 1.7), Vector3(0.5, 0.01, 0.07), "dm_glow_violet_soft", Vector3(0, -rad_to_deg(a) + 90.0, 0))
	var plq: Node3D = Props.group(dress, "Plaque", Vector3(-11.82, 1.55, 48.6), 90.0)
	D.blk(plq, Vector3(-0.42, -0.22, -0.03), Vector3(0.42, 0.22, 0.0), "dm_graphite")
	D.blk(plq, Vector3(-0.44, -0.24, -0.035), Vector3(0.44, -0.22, 0.005), "dm_chrome")
	D.blk(plq, Vector3(-0.44, 0.22, -0.035), Vector3(0.44, 0.24, 0.005), "dm_chrome")
	D.text(plq, "FORGE UNIT 001", Vector3(0, 0.1, 0.004), 0.0, 30, Color(0.9, 0.82, 1.0, 1.0), 1.2, 0.003)
	D.text(plq, "MOD. R-E  ·  PAT. PEND. BLZ-40417  ·  UNIT 001", Vector3(0, -0.06, 0.004), 0.0, 16, Color(0.85, 0.8, 0.9, 1.0), 1.0, 0.003)


## The yard airlock's vestibule: header over the frames, chevrons on the floor, ports, the cycle panel.
func _airlock_yard() -> void:
	D.blk(dress, Vector3(-1.6, DOOR_H + 0.3, 58.2), Vector3(1.6, DOOR_H + 0.75, 59.7), "dm_chrome")
	D.blk(dress, Vector3(-1.6, DOOR_H + 0.35, 58.18), Vector3(1.6, DOOR_H + 0.42, 58.2), "dm_glow_violet", false)
	for x: float in [-1.62, 1.6]:
		D.blk(dress, Vector3(x, 0.0, 58.2), Vector3(x + 0.02, DOOR_H + 0.3, 59.7), "dm_chrome")
	for i: int in 6:
		D.obx(dress, Vector3(-1.0 + 0.4 * float(i), 0.004, 58.95), Vector3(0.14, 0.008, 1.3), "dm_glow_violet_soft", Vector3(0, 30.0, 0))
	for sx: float in [-1.0, 1.0]:
		D.cyl(dress, Vector3(sx * 2.8, 1.7, 58.18), 0.22, 0.04, "dm_chrome", Vector3(90, 0, 0))
		D.cyl(dress, Vector3(sx * 2.8, 1.7, 58.16), 0.16, 0.02, "dm_black_glass", Vector3(90, 0, 0))
	_cycle_panel(Vector3(-2.6, 1.3, 58.18), 180.0)
	D.sign(dress, "MONDLICHT  ·  RR-7", Vector3(0, CEIL_B - 1.0, 60.19), 0.0, 5.6, 0.8, 64)


# ------------------------------------------------------------------ C Yard

func _dress_yard() -> void:
	# boot prints on the loop: the airlocks to the oval, the oval past both air posts
	var path: Array = [Vector3(0, 0, 60.6), Vector3(0, 0, 72.0)]
	_print_path(path, "moon-footprints-01/moon_footprints_01", 1.7)
	_print_path([Vector3(28, 0, 60.6), Vector3(21, 0, 76.0)], "moon-footprints-01/moon_footprints_01", 1.7)
	var oval: Array = []
	for k: int in 13:
		var a: float = TAU * float(k) / 12.0
		oval.append(Vector3(cos(a) * 24.0, 0.0, 86.0 + sin(a) * 14.0))
	_print_path(oval, "moon-footprints-01/moon_footprints_01", 1.7)
	# the field units' tracks from the airlock to the dish's foundation and on to the rim
	_print_path([Vector3(-2.5, 0, 61.0), Vector3(14.0, 0, 80.0), Vector3(31.0, 0, 97.0)], "moon-track-01/moon_track_01", 2.0)
	_print_path([Vector3(2.5, 0, 61.0), Vector3(20.0, 0, 78.0), Vector3(38.0, 0, 96.5)], "moon-track-01/moon_track_01", 2.0)
	# scattered stones (ankle high, no collider) and the boulders' broken edges
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7404
	var stones: Node3D = Props.group(dress, "Stones", Vector3.ZERO)
	for i: int in 70:
		var p: Vector3 = Vector3(rng.randf_range(-38.0, 38.0), 0.0, rng.randf_range(63.0, 108.0))
		if absf(p.x) < 4.0 and p.z < 75.0:
			continue
		var sz: float = rng.randf_range(0.12, 0.42)
		D.obx(stones, p + Vector3(0, sz * 0.25, 0), Vector3(sz, sz * 0.6, sz * rng.randf_range(0.7, 1.3)), "rim_rock",
			Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360), rng.randf_range(-20, 20)))
	for b: Array in BOULDERS:
		_boulder_chunks(b[0], b[1], rng)
	_rim(rng)
	_crater_wall(rng)
	_far_dish()
	_dish_foundation()
	_smile()
	_air_post_dressing(Vector3(-24, 0, 84))
	_air_post_dressing(Vector3(24, 0, 84))
	_dome_caps()
	_shadow_shells()
	# the yard's light: the Sun (the scene's Moon node, set in gameplay_extra), earthshine, the smile's glow
	fog("YardDust", Vector3(0, 0.5, 85), Vector3(80, 1.2, 50), 0.008, Color(0.6, 0.6, 0.65))
	D.omni(map_root, "Lamp_C_Earthshine", Vector3(0, 14.0, 88.0), Color(0.5, 0.62, 0.95), 0.32, 75.0, "C_YARD")
	D.omni(map_root, "Lamp_C_Smile", Vector3(0, 36.0, 204.0), VIOLET, 3.5, 50.0, "C_YARD")
	D.omni(map_root, "Lamp_C_DishWarning", FAR_DISH + Vector3(2.4, 17.4, 2.4), Color(1.0, 0.15, 0.1), 1.2, 8.0, "C_YARD")


## A strip of feathered patches along a polyline (one patch per leg, a little longer than the leg so they blend).
func _print_path(pts: Array, tex: String, width: float) -> void:
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d: Vector3 = b - a
		var yaw: float = rad_to_deg(atan2(d.x, d.z))
		D.patch(dress, (a + b) * 0.5, Vector2(width, d.length() + 1.4), yaw, tex, Vector2(width, width), Color(0.84, 0.84, 0.86, 0.95), 0.6)


func _boulder_chunks(lo: Vector3, hi: Vector3, rng: RandomNumberGenerator) -> void:
	var c: Vector3 = (lo + hi) * 0.5
	var sz: Vector3 = hi - lo
	for k: int in 4:
		var off: Vector3 = Vector3(rng.randf_range(-0.35, 0.35) * sz.x, 0.0, rng.randf_range(-0.35, 0.35) * sz.z)
		var s: Vector3 = Vector3(sz.x * rng.randf_range(0.45, 0.7), sz.y * rng.randf_range(0.5, 0.75), sz.z * rng.randf_range(0.45, 0.7))
		var rk: MeshInstance3D = D.ball(dress, Vector3(c.x + off.x, hi.y - s.y * 0.25, c.z + off.z), s, "rim_rock")
		rk.rotation = Vector3(deg_to_rad(rng.randf_range(-14, 14)), rng.randf_range(0, TAU), deg_to_rad(rng.randf_range(-14, 14)))
	for side: float in [-1.0, 1.0]:
		var bz: float = c.z + side * sz.z * 0.5
		var bulge: MeshInstance3D = D.ball(dress, Vector3(c.x + rng.randf_range(-0.6, 0.6), sz.y * 0.45, bz), Vector3(sz.x * 0.8, sz.y * 0.95, 0.5), "rim_rock")
		bulge.rotation.y = rng.randf_range(-0.25, 0.25)
	for k2: int in 3:
		var p: Vector3 = Vector3(rng.randf_range(lo.x - 0.3, hi.x + 0.3), 0.0, rng.randf_range(lo.z - 0.3, hi.z + 0.3))
		var pb: MeshInstance3D = D.ball(dress, p + Vector3(0, 0.12, 0), Vector3(0.7, 0.4, 0.55) * rng.randf_range(0.6, 1.2), "rim_rock")
		pb.rotation.y = rng.randf_range(0, TAU)


## The crater rim: broken slabs on top of the three rim walls and leaning against their outsides (the inner face
## stays within a hand's breadth of the collider).
func _rim(rng: RandomNumberGenerator) -> void:
	var runs: Array = [[Vector3(-41.0, 0, 61.0), Vector3(-41.0, 0, 111.0)], [Vector3(41.0, 0, 61.0), Vector3(41.0, 0, 111.0)], [Vector3(-41.0, 0, 111.0), Vector3(41.0, 0, 111.0)]]
	for r: Array in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var n: int = int((b - a).length() / 3.2)
		for i: int in n:
			var p: Vector3 = a.lerp(b, clampf((float(i) + 0.5 + rng.randf_range(-0.4, 0.4)) / float(n), 0.0, 1.0))
			var h: float = rng.randf_range(0.4, 2.4)
			if rng.randf() < 0.3:
				var st: MeshInstance3D = D.ball(dress, p + Vector3(rng.randf_range(-1.0, 1.0), RIM_H + h * 0.9, 0), Vector3(1.6, 1.0, 1.4) * rng.randf_range(0.7, 1.3), "rim_rock")
				st.rotation = Vector3(deg_to_rad(rng.randf_range(-20, 20)), rng.randf_range(0, TAU), 0)
			var top: MeshInstance3D = D.ball(dress, p + Vector3(0, RIM_H + h * 0.15, 0), Vector3(rng.randf_range(2.8, 4.2), h * 1.4, rng.randf_range(2.0, 2.8)), "rim_rock")
			top.rotation = Vector3(deg_to_rad(rng.randf_range(-10, 10)), rng.randf_range(0, PI), deg_to_rad(rng.randf_range(-12, 12)))
			var out: Vector3 = Vector3(signf(p.x) if absf(p.x) > 40.5 else 0.0, 0.0, 1.0 if p.z > 110.5 else 0.0)
			var lean: MeshInstance3D = D.ball(dress, p + out * 2.4 + Vector3(0, 1.0, 0), Vector3(4.2, 3.6, 3.0), "rim_rock")
			lean.rotation = Vector3(deg_to_rad(rng.randf_range(-8, 8)), rng.randf_range(0, PI), deg_to_rad(rng.randf_range(-15, 15)))


## The crater's far wall: tilted slabs in a ring north, east and west of the yard, rising to a ragged skyline,
## a few peaks behind. It gives the yard a horizon (and the smile a wall to be cracked into).
func _crater_wall(rng: RandomNumberGenerator) -> void:
	var g: Node3D = Props.group(dress, "CraterWall", Vector3.ZERO)
	for i: int in 26:
		var t: float = deg_to_rad(-25.0 + 230.0 * float(i) / 25.0)
		var r: float = 92.0 + rng.randf_range(-6.0, 8.0)
		var dir: Vector3 = Vector3(cos(t), 0.0, sin(t))
		var p: Vector3 = YARD_C + dir * r
		var yaw: float = rad_to_deg(atan2(dir.x, dir.z))
		var w: float = r * deg_to_rad(230.0 / 25.0) * 1.35
		var slab: MeshInstance3D = D.obx(g, p + Vector3(0, 10.0, 0), Vector3(w, 2.0, 60.0), "regolith_far", Vector3.ZERO)
		slab.basis = Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-32.0 + rng.randf_range(-5, 5))) * Basis.from_scale(Vector3(w, 2.0, 60.0))
		slab.position = p + dir * 14.0 + Vector3(0, 12.0, 0)
		for k3: int in 2:
			var along: float = rng.randf_range(2.0, 26.0)
			var ridge: MeshInstance3D = D.ball(g, p + dir * along + Vector3(0, along * 0.62 - 3.0, 0), Vector3(rng.randf_range(10, 22), rng.randf_range(4, 9), rng.randf_range(8, 16)), "rim_rock" if k3 == 0 else "regolith_far")
			ridge.rotation = Vector3(deg_to_rad(rng.randf_range(-10, 10)), rng.randf_range(0, TAU), deg_to_rad(rng.randf_range(-10, 10)))
	for k: int in 6:
		var t2: float = deg_to_rad(20.0 + 140.0 * float(k) / 5.0)
		var p2: Vector3 = YARD_C + Vector3(cos(t2), 0.0, sin(t2)) * rng.randf_range(150.0, 190.0)
		D.ball(g, p2 + Vector3(0, 8.0, 0), Vector3(rng.randf_range(60, 90), rng.randf_range(44, 70), rng.randf_range(50, 80)), "regolith_far")


## The transmitter dish beyond the north-east rim: a lattice tower, a paraboloid aimed at the Earth, the feed on
## its tripod, a warning lamp, and the faint violet thread of the retention signal running up to the Earth.
func _far_dish() -> void:
	var g: Node3D = Props.group(dress, "Dish", FAR_DISH)
	var top: float = 15.0
	var legs: Array = [Vector2(-4.5, -4.5), Vector2(4.5, -4.5), Vector2(4.5, 4.5), Vector2(-4.5, 4.5)]
	for c: Vector2 in legs:
		D.strut(g, Vector3(c.x, -6.0, c.y), Vector3(c.x * 0.3, top, c.y * 0.3), 0.32, "dm_steel_dark")
	for k: int in 6:
		var y0: float = -4.0 + 3.2 * float(k)
		var y1: float = y0 + 3.2
		var s0: float = lerpf(1.0, 0.3, (y0 + 6.0) / (top + 6.0))
		var s1: float = lerpf(1.0, 0.3, (y1 + 6.0) / (top + 6.0))
		for e: int in 4:
			var a: Vector2 = legs[e]
			var b: Vector2 = legs[(e + 1) % 4]
			D.strut(g, Vector3(a.x * s0, y0, a.y * s0), Vector3(b.x * s0, y0, b.y * s0), 0.16, "dm_steel_dark")
			D.strut(g, Vector3(a.x * s0, y0, a.y * s0), Vector3(b.x * s1, y1, b.y * s1), 0.1, "dm_steel_dark")
	D.blk(g, Vector3(-2.2, top, -2.2), Vector3(2.2, top + 1.2, 2.2), "dm_steel_dark")
	var earth_pos: Vector3 = Vector3(-10.0, 150.0, 255.0)
	var axis: Vector3 = (earth_pos - (FAR_DISH + Vector3(0, top + 2.0, 0))).normalized()
	var basis: Basis = Basis(Quaternion(Vector3.UP, axis))
	var hub: Vector3 = Vector3(0, top + 2.4, 0)
	D.keep(g, "DishFace", D.paraboloid(12.0, 3.6, 32, 8), Transform3D(basis, hub), "dish")
	var f: float = 12.0 * 12.0 / (4.0 * 3.6)
	var focus: Vector3 = hub + axis * f
	for i: int in 3:
		var a2: float = TAU * float(i) / 3.0
		var rim: Vector3 = hub + basis * Vector3(cos(a2) * 11.6, 3.4, sin(a2) * 11.6)
		D.strut(g, rim, focus, 0.14, "dm_steel_dark")
	D.ball(g, focus, Vector3.ONE * 1.1, "dm_steel_dark")
	D.ball(g, focus + axis * 0.5, Vector3.ONE * 0.55, "dm_glow_violet")
	D.ball(g, Vector3(0, top + 1.5, 0) - axis * 3.0, Vector3(3.0, 2.0, 3.0), "dm_steel_dark")
	D.ball(g, Vector3(2.4, top + 2.0, 2.4), Vector3.ONE * 0.4, "dm_glow_red")
	# the thread to the Earth: a long, faint, additive beam (no collider, no shadow)
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.name = "RetentionBeam"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.18
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	beam.mesh = cm
	var bm: StandardMaterial3D = StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.35, 0.18, 0.55, 1.0)
	bm.disable_fog = true
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var start: Vector3 = FAR_DISH + focus
	var end: Vector3 = earth_pos - axis * 58.0
	var length: float = (end - start).length()
	beam.transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)) * Basis.from_scale(Vector3(1, length, 1)), (start + end) * 0.5)
	beam.set_meta("keep", true)
	dress.add_child(beam)
	# the feed's cable over the rim to the yard's foundation
	Props.cable(dress, Vector3(35.0, 2.3, 101.0), Vector3(41.5, 3.6, 107.0), 0.4, 0.09, 8, "rubber")
	Props.cable(dress, Vector3(41.5, 3.6, 107.0), FAR_DISH + Vector3(-2.5, -5.5, -3.0), 1.5, 0.09, 10, "rubber")


## The dish's foundation in the yard (Rim_DishBase): a concrete ring with its bolts, a relay mast and a small
## repeater dish looking out over the rim, the junction box, the feed's stencil.
func _dish_foundation() -> void:
	var g: Node3D = Props.group(dress, "DishBase", Vector3(35.0, 2.2, 101.0))
	D.cyl(g, Vector3(0, 0.15, 0), 2.7, 0.3, "concrete")
	D.cyl(g, Vector3(0, 0.32, 0), 2.1, 0.04, "dm_steel_dark")
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		D.cyl(g, Vector3(cos(a) * 2.4, 0.38, sin(a) * 2.4), 0.06, 0.16, "dm_chrome_dark")
	for c: Vector2 in [Vector2(-0.8, -0.7), Vector2(0.8, -0.7), Vector2(0.0, 0.9)]:
		D.strut(g, Vector3(c.x, 0.3, c.y), Vector3(c.x * 0.15, 6.5, c.y * 0.15), 0.1, "dm_steel_dark")
	for y: float in [2.0, 4.0]:
		D.cyl(g, Vector3(0, y, 0), 0.65 * (1.0 - y / 8.0), 0.06, "dm_steel_dark")
	var axis: Vector3 = (FAR_DISH + Vector3(0, 17.0, 0) - Vector3(35.0, 9.0, 101.0)).normalized()
	D.keep(g, "RepeaterDish", D.paraboloid(1.6, 0.5, 18, 4), Transform3D(Basis(Quaternion(Vector3.UP, axis)), Vector3(0, 6.9, 0)), "dish")
	D.blk(g, Vector3(1.4, 0.3, -1.6), Vector3(2.1, 1.3, -1.2), "dm_graphite")
	D.blk(g, Vector3(1.5, 0.95, -1.62), Vector3(1.7, 1.05, -1.6), "dm_glow_violet", false)
	Props.stencil(g, Vector3(0.0, -0.9, -3.01), 180.0, "RR-7  ·  FEED 2", 56, Color(0.85, 0.82, 0.9, 0.7))


## The smile-crack in the far wall, north: a grin of violet glass veined with amber, a kilometre's stare.
func _smile() -> void:
	var g: Node3D = Props.group(dress, "Smile", Vector3(0, 30.0, 214.0))
	# the group lies on the crater wall's slope (local Y up the slope, local Z out toward the yard)
	g.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0.906, 0.423), Vector3(0, 0.423, -0.906))
	D.blk(g, Vector3(-40, -16, -2.6), Vector3(40, 14, -0.4), "rim_rock")
	var n: int = 16
	for i: int in n:
		var u: float = -1.0 + 2.0 * float(i) / float(n - 1)
		var x: float = u * 26.0
		var y: float = 9.0 - (1.0 - u * u) * 7.0
		var u2: float = -1.0 + 2.0 * float(i + 1) / float(n - 1)
		var dy: float = (9.0 - (1.0 - u2 * u2) * 7.0) - y
		var ang: float = rad_to_deg(atan2(dy, 52.0 / float(n - 1)))
		D.obx(g, Vector3(x, y, -0.3), Vector3(3.9, 2.0 + 1.3 * (1.0 - absf(u)), 1.2), "dm_glow_violet", Vector3(0, 0, ang))
		if i % 2 == 0:
			D.obx(g, Vector3(x + 0.6, y + 0.2, 0.35), Vector3(2.4, 0.3, 0.2), "dm_glow_amber", Vector3(0, 0, ang + 8.0))


## Each air post: a grated pad under its ring, a pylon with the sign both ways, a hose to the post, a beacon.
func _air_post_dressing(p: Vector3) -> void:
	var g: Node3D = Props.group(dress, "AirPostDress", p)
	D.cyl(g, Vector3(0, 0.01, 0), 2.35, 0.02, "dm_steel_dark")
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		D.obx(g, Vector3(cos(a) * 2.3, 0.022, sin(a) * 2.3), Vector3(0.5, 0.01, 0.08), "dm_glow_white", Vector3(0, -rad_to_deg(a) + 90.0, 0))
	var side: float = -1.0 if p.x < 0.0 else 1.0
	var py: Vector3 = Vector3(side * 2.7, 0, 0)
	D.blk(g, py + Vector3(-0.18, 0, -0.5), py + Vector3(0.18, 3.0, 0.5), "dm_offwhite")
	D.blk(g, py + Vector3(-0.2, 2.2, -0.52), py + Vector3(0.2, 2.9, 0.52), "dm_graphite")
	for f: float in [-1.0, 1.0]:
		D.text(g, "AIR", py + Vector3(f * 0.205, 2.62, 0), 90.0 * f, 64, Color(0.6, 0.85, 1.0, 1.0), 1.6)
		D.text(g, "INCLUDED IN YOUR PLAN", py + Vector3(f * 0.205, 2.36, 0), 90.0 * f, 18, Color(0.75, 0.85, 1.0, 1.0), 1.3, 0.003)
	D.cyl(g, py + Vector3(0, 3.1, 0), 0.12, 0.2, "dm_glow_white")
	D.cyl(g, py + Vector3(-side * 0.25, 1.1, 0), 0.32, 0.18, "dm_steel_dark", Vector3(0, 0, 90))
	Props.cable(g, py + Vector3(-side * 0.3, 1.0, 0), Vector3(side * 0.3, 0.9, 0), 0.35, 0.03, 8, "rubber")


## Shadow-only shells (never drawn): a 2 m slab over each lid and 1 m slabs outside the east and south hulls. The
## lids are 0.3 m; with the Sun this low the shadow map lost them and light leaked down the hall's west wall in teeth.
func _shadow_shells() -> void:
	for d: Array in [[Vector3(-12.3, CEIL_A, -0.3), Vector3(12.3, CEIL_A, 24.3)], [Vector3(-12.3, CEIL_B, 23.7), Vector3(12.3, CEIL_B, 60.3)],
			[Vector3(11.7, CEIL_D, 23.7), Vector3(44.3, CEIL_D, 60.3)], [Vector3(11.7, CEIL_E, -16.3), Vector3(44.3, CEIL_E, 24.3)],
			[Vector3(13.7, CEIL_F, -44.3), Vector3(25.5, CEIL_F, -15.7)], [Vector3(30.5, CEIL_F, -44.3), Vector3(42.3, CEIL_F, -15.7)],
			[Vector3(25.5, CEIL_F, -44.3), Vector3(30.5, CEIL_F, -32.5)], [Vector3(25.5, CEIL_F, -27.5), Vector3(30.5, CEIL_F, -15.7)]]:
		var lo: Vector3 = d[0]
		var hi: Vector3 = d[1]
		_shadow_only(Vector3(lo.x, lo.y + 0.3, lo.z), Vector3(hi.x, hi.y + 2.3, hi.z))
	for e: Array in [[Vector3(12.3, 0, -0.3), Vector3(13.3, CEIL_A + 2.3, 24.3)], [Vector3(44.3, 0, 23.7), Vector3(45.3, CEIL_D + 2.3, 60.3)],
			[Vector3(44.3, 0, -16.3), Vector3(45.3, CEIL_E + 2.3, 24.3)], [Vector3(42.3, 0, -44.3), Vector3(43.3, CEIL_F + 2.3, -15.7)],
			[Vector3(-12.3, 0, -1.3), Vector3(12.3, CEIL_A + 2.3, -0.3)], [Vector3(13.7, 0, -45.3), Vector3(42.3, CEIL_F + 2.3, -44.3)]]:
		_shadow_only(e[0], e[1])


func _shadow_only(a: Vector3, b: Vector3) -> void:
	var mi: MeshInstance3D = D.blk(dress, a, b, "dm_graphite")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.set_meta("vis", "ALL")   # the Sun needs them wherever the camera is


## The domes seen from the yard: a shallow cap over each lid (above the ceiling, so nothing shows inside).
func _dome_caps() -> void:
	var hemi: SphereMesh = SphereMesh.new()
	hemi.radius = 0.5
	hemi.height = 0.5
	hemi.is_hemisphere = true
	hemi.radial_segments = 24
	hemi.rings = 6
	for c: Array in [[Vector3(0, CEIL_A + 0.3, 12), Vector3(23.0, 7.0, 23.0)], [Vector3(0, CEIL_B + 0.3, 42), Vector3(23.0, 6.0, 35.0)],
			[Vector3(28, CEIL_D + 0.3, 42), Vector3(31.0, 6.0, 35.0)], [Vector3(28, CEIL_E + 0.3, 4), Vector3(31.0, 8.0, 39.0)]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = hemi
		mi.position = c[0]
		mi.scale = c[1]
		mi.material_override = D.mat("hull")
		mi.set_meta("vis", "ALL")   # seen from the yard over the other domes
		dress.add_child(mi)
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0
			var sc: Vector3 = c[1]
			D.strut(dress, (c[0] as Vector3) + Vector3(cos(a) * sc.x * 0.5, 0.0, sin(a) * sc.z * 0.5), (c[0] as Vector3) + Vector3(0, sc.y * 0.5, 0), 0.18, "dm_chrome_dark").set_meta("vis", "ALL")


# ------------------------------------------------------------------ D Fulfillment

func _dress_store() -> void:
	# exposed trusses across the store, cold strips along the aisles
	for x: float in [16.0, 20.0, 24.0, 28.0, 32.0, 36.0, 40.0]:
		D.blk(dress, Vector3(x - 0.1, CEIL_D - 0.45, 24.15), Vector3(x + 0.1, CEIL_D - 0.02, 59.85), "dm_steel_dark")
		D.blk(dress, Vector3(x - 0.04, CEIL_D - 0.9, 24.15), Vector3(x + 0.04, CEIL_D - 0.45, 59.85), "dm_steel_dark")
	for z: float in [29.0, 38.0, 46.0, 53.0]:
		D.strip(dress, Vector3(28.0, CEIL_D - 0.95, z), 22.0, true, "dm_glow_white")
	# painted aisle lines and bay numbers
	for z2: float in [36.0, 40.0, 44.0, 48.0, 32.0, 52.0]:
		D.blk(dress, Vector3(16.5, 0.0, z2 - 0.04), Vector3(39.5, 0.006, z2 + 0.04), "dm_glow_violet_soft", false)
	for ri: int in RACK_Z.size():
		_rack(ri + 1, float(RACK_Z[ri]))
	_fold_pad(Vector3(36.5, 0, 28.8))
	_conveyor()
	D.sign(dress, "FULFILLMENT", Vector3(28.0, 3.5, 24.17), 0.0, 5.0, 0.8, 72)
	D.sign(dress, "RETURNS ARE NOT ACCEPTED", Vector3(43.83, 3.5, 47.0), -90.0, 6.0, 0.6, 44, D.COLD, false)
	D.text(dress, "STORE AIRLOCK", Vector3(28.0, 3.0, 59.82), 180.0, 40, Color(0.85, 0.9, 1.0, 0.95), 1.2)
	# lights: cold white over the aisles, the pad's violet key, one aisle key
	D.omni(map_root, "Lamp_D_Cold_1", Vector3(28, CEIL_D - 1.2, 31.0), D.COLD, 2.0, 15.0, "D_FULFILLMENT")
	D.omni(map_root, "Lamp_D_Cold_2", Vector3(28, CEIL_D - 1.2, 46.0), D.COLD, 2.0, 15.0, "D_FULFILLMENT")
	D.omni(map_root, "Lamp_D_Cold_3", Vector3(28, CEIL_D - 1.2, 56.0), D.COLD, 1.4, 12.0, "D_FULFILLMENT")
	D.spot(map_root, "KeySpot_D_Pad", Vector3(36.5, CEIL_D - 0.3, 28.8), Vector3(36.5, 0.0, 28.8), D.VIOLET, 6.0, 7.0, 38.0, "D_FULFILLMENT", true)
	D.spot(map_root, "KeySpot_D_Aisle", Vector3(15.5, CEIL_D - 0.3, 38.0), Vector3(36.0, 0.5, 38.0), D.COLD, 4.0, 26.0, 26.0, "D_FULFILLMENT", false)


## One rack of suited inventory: steel uprights, a top rail with hangers, a suit in each bay facing south, a tag
## on each wrist. Bays 4-6 of rack 2 are the Kranich's three, by name (INT_M4_CREWTAGS). Still, tagged, upright.
func _rack(n: int, rz: float) -> void:
	var g: Node3D = Props.group(dress, "Rack", Vector3(0, 0, rz))
	for i: int in 10:
		var x: float = 17.05 + 21.9 * float(i) / 9.0
		for zs: float in [-0.55, 0.55]:
			D.blk(g, Vector3(x - 0.05, 0.0, zs - 0.05), Vector3(x + 0.05, 2.38, zs + 0.05), "dm_steel_dark")
	for zs2: float in [-0.55, 0.55]:
		D.blk(g, Vector3(17.0, 2.3, zs2 - 0.05), Vector3(39.0, 2.38, zs2 + 0.05), "dm_steel_dark")
		D.blk(g, Vector3(17.0, 0.12, zs2 - 0.04), Vector3(39.0, 0.2, zs2 + 0.04), "dm_steel_dark")
	D.blk(g, Vector3(17.0, 2.22, -0.03), Vector3(39.0, 2.27, 0.03), "dm_chrome")
	for b: int in 9:
		var cx: float = 17.05 + 21.9 * (float(b) + 0.5) / 9.0
		_suit(g, Vector3(cx, 0.2, 0.0), n, b + 1)
		D.text(g, "%d·%d" % [n, b + 1], Vector3(cx, 2.34, -0.61), 180.0, 22, Color(0.85, 0.9, 1.0, 0.9), 0.0, 0.003)
	D.sign(g, "RACK %d" % n, Vector3(16.9, 2.0, 0.0), -90.0, 1.1, 0.4, 44, D.COLD, false)
	if n == 2:
		# the tag board at the rack's west end (INT_M4_CREWTAGS rests on its shelf)
		D.blk(g, Vector3(16.75, 0.88, -0.75), Vector3(17.05, 0.92, -0.25), "dm_chrome")
		D.blk(g, Vector3(16.95, 0.92, -0.75), Vector3(17.02, 1.6, -0.25), "dm_graphite")


## A pressure suit on a hanger, facing -Z: boots, legs, torso with the PERPETUAL stencil, the pack, arms, gloves,
## a helmet with its visor, and a tag on a string at the right wrist.
func _suit(g: Node3D, p: Vector3, rack: int, bay: int) -> void:
	var s: Node3D = Props.group(g, "Suit", p)
	for lx: float in [-0.12, 0.12]:
		D.blk(s, Vector3(lx - 0.08, 0.0, -0.14), Vector3(lx + 0.08, 0.12, 0.1), "suit_dark")
		D.blk(s, Vector3(lx - 0.085, 0.12, -0.08), Vector3(lx + 0.085, 0.86, 0.08), "suit")
		D.blk(s, Vector3(lx - 0.09, 0.42, -0.095), Vector3(lx + 0.09, 0.5, 0.09), "suit_dark")
	D.blk(s, Vector3(-0.24, 0.86, -0.15), Vector3(0.24, 1.5, 0.14), "suit")
	D.blk(s, Vector3(-0.25, 1.08, -0.16), Vector3(0.25, 1.14, 0.15), "suit_violet")
	D.blk(s, Vector3(-0.2, 0.92, 0.14), Vector3(0.2, 1.42, 0.32), "suit_dark")
	D.blk(s, Vector3(-0.1, 1.2, -0.158), Vector3(0.1, 1.3, -0.15), "dm_glow_violet_soft", false)
	for ax: float in [-1.0, 1.0]:
		D.strut(s, Vector3(ax * 0.28, 1.45, 0.0), Vector3(ax * 0.32, 0.92, -0.02), 0.075, "suit")
		D.blk(s, Vector3(ax * 0.32 - 0.05, 0.8, -0.07), Vector3(ax * 0.32 + 0.05, 0.92, 0.03), "suit_dark")
	D.cyl(s, Vector3(0, 1.53, 0), 0.13, 0.06, "dm_chrome_dark")
	D.ball(s, Vector3(0, 1.72, 0.0), Vector3(0.36, 0.38, 0.36), "suit")
	D.ball(s, Vector3(0, 1.72, -0.07), Vector3(0.27, 0.22, 0.24), "visor")
	D.strut(s, Vector3(0, 1.9, 0), Vector3(0, 2.02, 0), 0.015, "dm_chrome")
	var key: String = "%d_%d" % [rack, bay]
	var tag_text: String = CREW.get(key, "INVENTORY\nRR-7 · RACK %d · BAY %d\nPERPETUAL" % [rack, bay])
	D.strut(s, Vector3(0.33, 0.82, -0.08), Vector3(0.33, 0.68, -0.12), 0.006, "tag")
	D.blk(s, Vector3(0.23, 0.53, -0.125), Vector3(0.43, 0.68, -0.12), "tag")
	D.text(s, tag_text, Vector3(0.33, 0.605, -0.127), 180.0, 12, Color(0.12, 0.1, 0.08, 1.0), 0.0, 0.0012)
	if CREW.has(key):
		D.text(s, "PERPETUAL", Vector3(0, 1.0, -0.152), 180.0, 22, Color(0.85, 0.6, 1.0, 0.95), 0.0, 0.0024)
		D.obx(s, Vector3(0.33, 0.52, -0.128), Vector3(0.06, 0.02, 0.004), "dm_glow_amber", Vector3(0, 0, 20))   # three strokes and a hook, scratched
	else:
		D.text(s, "PERPETUAL", Vector3(0, 1.0, -0.152), 180.0, 22, Color(0.75, 0.55, 0.95, 0.8), 0.0, 0.0024)


## The fold pad the inventory arrived on: a graphite disc, a chrome rim, the violet ring, the emitters, the amber
## fold-scar, the emitter ring overhead.
func _fold_pad(p: Vector3) -> void:
	var g: Node3D = Props.group(dress, "FoldPad", p)
	D.cyl(g, Vector3(0, 0.012, 0), 2.1, 0.024, "dm_graphite")
	D.cyl(g, Vector3(0, 0.01, 0), 2.22, 0.02, "dm_chrome")
	for i: int in 28:
		var a: float = TAU * float(i) / 28.0
		D.obx(g, Vector3(cos(a) * 1.75, 0.026, sin(a) * 1.75), Vector3(0.36, 0.006, 0.08), "dm_glow_violet", Vector3(0, -rad_to_deg(a) + 90.0, 0))
	for k: int in 5:
		D.obx(g, Vector3(-0.8 + 0.4 * float(k), 0.027, -0.2 + 0.18 * sin(float(k) * 1.7)), Vector3(0.42, 0.006, 0.05), "dm_glow_amber", Vector3(0, 30.0 * sin(float(k) * 2.1), 0))
	for e: int in 4:
		var b: float = TAU * float(e) / 4.0 + PI * 0.25
		var q: Vector3 = Vector3(cos(b) * 2.45, 0, sin(b) * 2.45)
		D.cyl(g, q + Vector3(0, 0.35, 0), 0.08, 0.7, "dm_chrome")
		D.obx(g, q + Vector3(0, 0.82, 0), Vector3(0.16, 0.26, 0.16), "dm_glow_violet", Vector3(0, 45, 45))
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 1.9
	tm.outer_radius = 2.05
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position = Vector3(0, CEIL_D - 0.9, 0)
	ring.material_override = D.mat("dm_glow_violet")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(ring)
	for h: int in 3:
		var c: float = TAU * float(h) / 3.0
		D.strut(g, Vector3(cos(c) * 1.98, CEIL_D - 0.9, sin(c) * 1.98), Vector3(cos(c) * 1.98, CEIL_D, sin(c) * 1.98), 0.03, "dm_chrome")
	var fl: Label3D = D.text(g, "FOLD PAD  ·  INBOUND", Vector3(0, 0.03, 2.55), 0.0, 40, Color(0.75, 0.55, 1.0, 0.85), 1.2)
	fl.rotation = Vector3(-PI * 0.5, 0, 0)


## The conveyor along the north wall: side rails, legs, the belt, the hoods at both ends, parcels that move.
func _conveyor() -> void:
	var g: Node3D = Props.group(dress, "Conveyor", Vector3(28, 0, 54.9))
	D.blk(g, Vector3(-12.0, 0.84, -0.55), Vector3(12.0, 0.88, 0.55), "rubber")
	for zs: float in [-0.66, 0.66]:
		D.blk(g, Vector3(-12.0, 0.7, zs - 0.04), Vector3(12.0, 0.98, zs + 0.04), "dm_steel_dark")
	for i: int in 13:
		var x: float = -12.0 + 2.0 * float(i)
		for zs2: float in [-0.6, 0.6]:
			D.blk(g, Vector3(x - 0.04, 0.0, zs2 - 0.04), Vector3(x + 0.04, 0.7, zs2 + 0.04), "dm_steel_dark")
	for i2: int in 48:
		D.cyl(g, Vector3(-11.8 + 0.5 * float(i2), 0.8, 0), 0.04, 1.2, "dm_chrome_dark", Vector3(90, 0, 0))
	for ex: float in [-12.0, 11.0]:
		D.blk(g, Vector3(ex, 0.88, -0.7), Vector3(ex + 1.0, 2.0, 0.7), "dm_graphite")
		for k: int in 6:
			D.blk(g, Vector3(ex + (1.0 if ex > 0.0 else 0.0) - 0.01, 0.9, -0.6 + 0.2 * float(k)), Vector3(ex + (1.0 if ex > 0.0 else 0.0) + 0.01, 1.85, -0.43 + 0.2 * float(k)), "rubber")
	D.text(g, "OUTBOUND", Vector3(11.5, 2.1, -0.71), 180.0, 30, Color(0.85, 0.9, 1.0, 0.95), 1.2)
	# the parcels (a ConveyorRun moves them; kept out of the batches)
	var run: Node3D = Node3D.new()
	run.name = "ConveyorRun"
	run.set_script(load("res://gravelight/world/map04/conveyor_run.gd"))
	run.set("length", 22.0)
	run.position = Vector3(28, 0.88, 54.9)
	run.set_meta("keep", true)
	dress.add_child(run)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5501
	for j: int in 9:
		var sz: Vector3 = Vector3(rng.randf_range(0.4, 0.7), rng.randf_range(0.3, 0.55), rng.randf_range(0.4, 0.75))
		var holder: Node3D = Node3D.new()
		holder.name = "Parcel_%d" % j
		holder.position = Vector3(-10.5 + 2.45 * float(j), 0.0, rng.randf_range(-0.12, 0.12))
		holder.rotation.y = rng.randf_range(-0.2, 0.2)
		holder.set_meta("parcel", true)
		run.add_child(holder)
		D.blk(holder, Vector3(-sz.x * 0.5, 0.0, -sz.z * 0.5), Vector3(sz.x * 0.5, sz.y, sz.z * 0.5), "parcel_violet" if j % 3 == 0 else "parcel")
		if j % 3 == 0:
			D.blk(holder, Vector3(-sz.x * 0.5 - 0.002, sz.y * 0.4, -0.04), Vector3(sz.x * 0.5 + 0.002, sz.y * 0.5, 0.04), "dm_glow_amber", false)


# ------------------------------------------------------------------ E Retention Hall

func _dress_hall() -> void:
	# the nave: pilasters up the walls and pointed ribs to the ridge (above every head), frosted glass between
	for rz: float in [-10.0, -2.0, 6.0, 14.0, 22.0]:
		for side: float in [-1.0, 1.0]:
			var wx: float = 28.0 + side * 15.85
			D.blk(dress, Vector3(wx - 0.2, 0.0, rz - 0.25), Vector3(wx + 0.2, 6.0, rz + 0.25), "dm_violet_deep")
			D.blk(dress, Vector3(wx - 0.24, 0.0, rz - 0.28), Vector3(wx + 0.24, 0.3, rz + 0.28), "dm_chrome")
			D.blk(dress, Vector3(wx - side * 0.21 - 0.012, 0.6, rz - 0.06), Vector3(wx - side * 0.21 + 0.012, 5.6, rz + 0.06), "dm_glow_violet_soft", false)
			D.strut(dress, Vector3(wx, 6.0, rz), Vector3(28.0, CEIL_E - 0.1, rz), 0.34, "dm_violet_deep")
			D.strut(dress, Vector3(wx - side * 0.2, 5.9, rz), Vector3(28.0, CEIL_E - 0.32, rz), 0.06, "dm_glow_violet_soft")
	for gz: float in [-6.0, 2.0, 10.0, 18.0]:
		for side2: float in [-1.0, 1.0]:
			var ob: MeshInstance3D = D.obx(dress, Vector3(28.0 + side2 * 7.9, 7.45, gz), Vector3(16.6, 0.04, 7.4), "dm_glass_violet", Vector3(0, 0, -side2 * rad_to_deg(atan2(2.9, 15.7))))
			ob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# floor inlays: the nave runner and a ring round each column with its spokes
	for x: float in [26.9, 29.1]:
		D.blk(dress, Vector3(x - 0.04, 0.0, -15.8), Vector3(x + 0.04, 0.006, 23.8), "dm_glow_violet_soft", false)
	D.blk(dress, Vector3(26.95, 0.0, -15.8), Vector3(29.05, 0.003, 23.8), "dm_violet_deep")
	for cx: float in [18.0, 28.0, 38.0]:
		for i: int in 24:
			var a: float = TAU * float(i) / 24.0
			D.obx(dress, Vector3(cx + cos(a) * 2.3, 0.005, 4.0 + sin(a) * 2.3), Vector3(0.62, 0.01, 0.08), "dm_glow_violet_soft", Vector3(0, -rad_to_deg(a) + 90.0, 0))
		for k: int in 8:
			var b: float = TAU * float(k) / 8.0
			D.obx(dress, Vector3(cx + cos(b) * 3.1, 0.004, 4.0 + sin(b) * 3.1), Vector3(1.4, 0.008, 0.05), "dm_chrome", Vector3(0, -rad_to_deg(b), 0))
		# the plinth dressed: chrome edge, a violet underglow, the number on the floor
		D.blk(dress, Vector3(cx - 1.04, 0.0, 2.96), Vector3(cx + 1.04, 0.31, 5.04), "dm_graphite")
		D.blk(dress, Vector3(cx - 1.06, 0.28, 2.94), Vector3(cx + 1.06, 0.32, 5.06), "dm_chrome")
		D.blk(dress, Vector3(cx - 1.07, 0.02, 2.93), Vector3(cx + 1.07, 0.06, 5.07), "dm_glow_violet", false)
	# NOBODY CANCELS: the panel behind the letters, the flanking light blades
	D.blk(dress, Vector3(15.5, 5.0, -15.84), Vector3(40.5, 7.9, -15.8), "dm_graphite")
	D.blk(dress, Vector3(15.4, 7.9, -15.85), Vector3(40.6, 8.0, -15.76), "dm_chrome")
	D.blk(dress, Vector3(15.4, 4.9, -15.85), Vector3(40.6, 5.0, -15.76), "dm_chrome")
	D.blk(dress, Vector3(16.0, 5.06, -15.8), Vector3(40.0, 5.1, -15.77), "dm_glow_violet", false)
	for bx: float in [14.2, 41.8]:
		D.blk(dress, Vector3(bx - 0.3, 0.4, -15.84), Vector3(bx + 0.3, 8.2, -15.78), "dm_glow_violet_soft", false)
		D.blk(dress, Vector3(bx - 0.36, 0.3, -15.85), Vector3(bx + 0.36, 0.4, -15.74), "dm_chrome")
	D.sign(dress, "RETENTION HALL", Vector3(28, 3.6, 23.83), 180.0, 5.4, 0.8, 70)
	D.text(dress, "RETENTION HALL", Vector3(28, 3.4, 24.17), 0.0, 48, Color(0.85, 0.6, 1.0, 0.9), 1.2)
	# the pendants on the ridge (their lights breathe with the hum: HumPulse in gameplay_extra)
	for p: Vector3 in [Vector3(20, 0, 12), Vector3(36, 0, 12), Vector3(20, 0, -6), Vector3(36, 0, -6)]:
		D.strut(dress, Vector3(p.x, CEIL_E - 0.3, p.z), Vector3(p.x, CEIL_E - 1.2, p.z), 0.02, "dm_chrome")
		D.cyl(dress, Vector3(p.x, CEIL_E - 1.45, p.z), 0.22, 0.5, "dm_glass_violet")
		D.cyl(dress, Vector3(p.x, CEIL_E - 1.45, p.z), 0.12, 0.42, "dm_glow_violet")
		D.cyl(dress, Vector3(p.x, CEIL_E - 1.17, p.z), 0.25, 0.06, "dm_chrome")
	fog("HallHum", Vector3(28, 4.0, 4), Vector3(32, 8.0, 40), 0.03, Color(0.5, 0.35, 0.7), Color(0.05, 0.02, 0.08))
	D.spot(map_root, "KeySpot_E_Column", Vector3(28, CEIL_E - 0.4, 14.0), Vector3(28, 3.0, 4.0), D.VIOLET, 6.0, 16.0, 30.0, "E_HALL", true)
	D.omni(map_root, "Lamp_E_Sign", Vector3(28, 4.4, -13.5), VIOLET, 1.2, 10.0, "E_HALL")


# ------------------------------------------------------------------ F The Account

func _dress_account() -> void:
	var c: Vector3 = Vector3(28, 0, -30)
	# the round room on a square plan: pendentives in the corners above head height, a ring beam and cove at the
	# ceiling, radial ribs from the shaft, concentric rings in the floor
	for q: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var corner: Vector3 = c + Vector3(q.x * 13.85, 0, q.y * 13.85)
		var mid: Vector3 = corner - Vector3(q.x, 0, q.y) * 2.4
		var yaw: float = rad_to_deg(atan2(q.x, q.y))
		var pend: MeshInstance3D = D.obx(dress, mid + Vector3(0, 5.6, 0), Vector3(6.8, 2.8, 0.2), "dm_f_wall", Vector3.ZERO)
		pend.basis = Basis(Vector3.UP, deg_to_rad(yaw + 90.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.0)) * Basis.from_scale(Vector3(6.8, 2.8, 0.2))
		D.obx(dress, mid + Vector3(0, 4.3, 0) + Vector3(q.x, 0, q.y) * 0.7, Vector3(6.4, 0.08, 0.1), "dm_chrome", Vector3(0, yaw + 90.0, 0))
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 12.6
	tm.outer_radius = 13.2
	tm.rings = 48
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position = c + Vector3(0, CEIL_F - 0.35, 0)
	ring.scale = Vector3(1, 0.6, 1)
	ring.material_override = D.mat("dm_chrome_dark")
	dress.add_child(ring)
	var cove: MeshInstance3D = MeshInstance3D.new()
	var tm2: TorusMesh = TorusMesh.new()
	tm2.inner_radius = 12.35
	tm2.outer_radius = 12.5
	tm2.rings = 48
	tm2.ring_segments = 4
	cove.mesh = tm2
	cove.position = c + Vector3(0, CEIL_F - 0.6, 0)
	cove.material_override = D.mat("dm_glow_violet")
	cove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dress.add_child(cove)
	for k: int in 12:
		var a: float = TAU * float(k) / 12.0
		D.strut(dress, c + Vector3(cos(a) * 3.2, CEIL_F - 0.15, sin(a) * 3.2), c + Vector3(cos(a) * 12.7, CEIL_F - 0.3, sin(a) * 12.7), 0.22, "dm_chrome_dark")
	for r: float in [4.6, 8.0, 12.0]:
		var n: int = int(r * 6.0)
		for i: int in n:
			var b: float = TAU * float(i) / float(n)
			D.obx(dress, c + Vector3(cos(b) * r, 0.004, sin(b) * r), Vector3(TAU * r / float(n) * 0.82, 0.008, 0.07 if r < 12.0 else 0.12),
				"dm_chrome" if r != 8.0 else "dm_glow_violet_soft", Vector3(0, -rad_to_deg(b) + 90.0, 0))
	# the dish's foundation ring around the shaft (the Account sits under it): concrete, bolts, the shaft's throat
	for i2: int in 16:
		var a2: float = TAU * float(i2) / 16.0
		D.obx(dress, c + Vector3(cos(a2) * 4.1, CEIL_F - 0.55, sin(a2) * 4.1), Vector3(1.75, 1.0, 1.4), "concrete", Vector3(0, -rad_to_deg(a2) + 90.0, 0))
		D.cyl(dress, c + Vector3(cos(a2) * 3.5, CEIL_F - 1.1, sin(a2) * 3.5), 0.07, 0.12, "dm_chrome_dark")
	for y: float in [CEIL_F + 1.0, CEIL_F + 3.0, CEIL_F + 5.0]:
		var th: MeshInstance3D = MeshInstance3D.new()
		var tt: TorusMesh = TorusMesh.new()
		tt.inner_radius = 1.95
		tt.outer_radius = 2.15
		tt.rings = 20
		tt.ring_segments = 4
		th.mesh = tt
		th.position = c + Vector3(0, y, 0)
		th.material_override = D.mat("dm_glow_violet")
		th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dress.add_child(th)
	# the console's dais: a flat disc, conduits in the floor to the first retained and the crew pad
	D.cyl(dress, c + Vector3(0, 0.006, 0), 2.2, 0.012, "dm_black_glass")
	D.cyl(dress, c + Vector3(0, 0.004, 0), 2.32, 0.008, "dm_chrome")
	for dst: Vector3 in [Vector3(28, 0, -38.4), Vector3(34.6, 0, -36.0)]:
		var d: Vector3 = dst - c
		D.obx(dress, c + d * 0.5 + Vector3(0, 0.006, 0), Vector3(0.09, 0.008, d.length() - 4.0), "dm_glow_violet", Vector3(0, rad_to_deg(atan2(d.x, d.z)), 0))
	D.cyl(dress, Vector3(28, 0.004, -34), 1.2, 0.008, "dm_graphite")
	D.cyl(dress, Vector3(28, 0.003, -34), 1.28, 0.006, "dm_glow_violet_soft")
	_first_retained()
	_crew_pad()
	D.sign(dress, "THE ACCOUNT", Vector3(28, 3.5, -16.17), 0.0, 4.6, 0.8, 70)
	D.sign(dress, "THE ACCOUNT", Vector3(28, 3.6, -15.83), 180.0, 4.6, 0.8, 70)
	# lights: the shaft's key on the console, the vitrine's downlight, the room's violet
	D.spot(map_root, "KeySpot_F_Shaft", Vector3(28, CEIL_F + 5.6, -30), Vector3(28, 0.0, -30), D.COLD, 9.0, 16.0, 22.0, "F_CORE", true)
	D.omni(map_root, "Lamp_F_Room", Vector3(28, CEIL_F - 0.8, -24), VIOLET, 2.6, 18.0, "F_CORE")
	for q: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		D.omni(map_root, "Lamp_F_Wash_%d_%d" % [int(q.x), int(q.y)], Vector3(28 + q.x * 10.5, 4.6, -30 + q.y * 10.5), Color(0.66, 0.5, 1.0), 1.1, 9.0, "F_CORE")
	D.omni(map_root, "Lamp_F_Retained", Vector3(28.3, 0.3, -39.3), Color(0.7, 0.6, 1.0), 0.5, 2.2, "F_CORE")
	D.omni(map_root, "Lamp_F_Vitrine", Vector3(28, 2.6, -39.75), D.COLD, 0.7, 6.0, "F_CORE")
	D.omni(map_root, "Lamp_F_Pad", Vector3(37, 0.8, -37.5), VIOLET, 0.8, 6.0, "F_CORE")


## The first retained: Jan Pilch under the floor glass (a raised vitrine, frosted over him, clear over his hand),
## covered to the chest, the tag on the rim; the violet threads the relay draws from his hand.
func _first_retained() -> void:
	var g: Node3D = Props.group(dress, "Pilch", Vector3(28, 0, -39.75))
	# the vitrine's walls (hollow: he lies inside, under the glass), its floor
	D.blk(g, Vector3(-1.5, 0.0, -1.25), Vector3(1.5, 0.42, -1.13), "dm_graphite")
	D.blk(g, Vector3(-1.5, 0.0, 1.13), Vector3(1.5, 0.42, 1.25), "dm_graphite")
	D.blk(g, Vector3(-1.5, 0.0, -1.13), Vector3(-1.38, 0.42, 1.13), "dm_graphite")
	D.blk(g, Vector3(1.38, 0.0, -1.13), Vector3(1.5, 0.42, 1.13), "dm_graphite")
	D.blk(g, Vector3(-1.38, 0.0, -1.13), Vector3(1.38, 0.06, 1.13), "dm_graphite")
	D.blk(g, Vector3(-1.38, 0.06, -1.13), Vector3(1.38, 0.09, 1.13), "dm_violet_deep")
	for r: Array in [[Vector3(-1.52, 0.42, -1.27), Vector3(1.52, 0.47, -1.13)], [Vector3(-1.52, 0.42, 1.13), Vector3(1.52, 0.47, 1.27)],
			[Vector3(-1.52, 0.42, -1.13), Vector3(-1.38, 0.47, 1.13)], [Vector3(1.38, 0.42, -1.13), Vector3(1.52, 0.47, 1.13)]]:
		D.blk(g, r[0], r[1], "dm_chrome")   # the rim: a frame, not a lid
	D.blk(g, Vector3(-1.4, 0.46, -1.15), Vector3(1.4, 0.5, 0.25), "dm_frosted")
	D.blk(g, Vector3(-1.4, 0.46, 0.25), Vector3(1.4, 0.5, 1.15), "dm_glass")
	D.blk(g, Vector3(-1.42, 0.47, 0.22), Vector3(1.42, 0.5, 0.28), "dm_chrome")
	# the miner, lying north-south, head to the south, under a grey cloth to the chest
	D.blk(g, Vector3(-0.32, 0.1, -1.0), Vector3(0.32, 0.3, 0.55), "miner")
	D.ball(g, Vector3(0, 0.22, -1.0), Vector3(0.24, 0.2, 0.28), "skin_pale")
	D.blk(g, Vector3(-0.36, 0.14, -0.7), Vector3(0.36, 0.33, 0.6), "suit_dark")
	D.strut(g, Vector3(0.3, 0.25, 0.1), Vector3(0.42, 0.27, 0.52), 0.07, "miner")
	# the hand at the clear pane (RetainedHand curls the fingers; kept out of the batches)
	var hand: Node3D = Node3D.new()
	hand.name = "Hand"
	hand.set_script(load("res://gravelight/world/map04/retained_hand.gd"))
	hand.position = Vector3(28.42, 0.28, -39.75 + 0.6)
	hand.set_meta("keep", true)
	dress.add_child(hand)
	D.blk(hand, Vector3(-0.06, -0.025, -0.05), Vector3(0.06, 0.025, 0.07), "skin_pale")
	for f: int in 4:
		var finger: Node3D = Node3D.new()
		finger.position = Vector3(-0.045 + 0.03 * float(f), 0.0, 0.07)
		finger.set_meta("finger", 0.8 + 0.1 * float(f))
		hand.add_child(finger)
		D.blk(finger, Vector3(-0.011, -0.012, 0.0), Vector3(0.011, 0.012, 0.075 - 0.008 * absf(float(f) - 1.5)), "skin_pale")
	var thumb: Node3D = Node3D.new()
	thumb.position = Vector3(-0.065, 0.0, 0.02)
	thumb.rotation.y = 0.6
	thumb.set_meta("finger", 0.5)
	hand.add_child(thumb)
	D.blk(thumb, Vector3(-0.012, -0.012, 0.0), Vector3(0.012, 0.012, 0.055), "skin_pale")
	for i: int in 5:
		var a: float = -0.9 + 0.45 * float(i)
		D.strut(g, Vector3(0.42, 0.3, 0.62), Vector3(0.42 + cos(a) * 0.9, 0.4, 0.62 + sin(a) * 0.5), 0.006, "dm_glow_violet_soft")
	# the tag on the rim, engraved
	D.blk(g, Vector3(-0.55, 0.47, -1.27), Vector3(0.55, 0.5, -1.2), "dm_chrome")
	D.text(g, "PILCH, J.  ·  KB  ·  11.XI.38", Vector3(0, 0.485, -1.275), 180.0, 18, Color(0.15, 0.12, 0.2, 1.0), 0.0, 0.0028)


## The crew's pad (the Kranich's crew come through it in COLLECTIONS): a smaller fold pad on its low dais.
func _crew_pad() -> void:
	var g: Node3D = Props.group(dress, "Pad", Vector3(37, 0, -37.5))
	D.cyl(g, Vector3(0, 0.12, 0), 2.45, 0.24, "dm_graphite")
	D.cyl(g, Vector3(0, 0.245, 0), 2.5, 0.01, "dm_chrome")
	for i: int in 20:
		var a: float = TAU * float(i) / 20.0
		D.obx(g, Vector3(cos(a) * 1.8, 0.252, sin(a) * 1.8), Vector3(0.5, 0.006, 0.08), "dm_glow_violet", Vector3(0, -rad_to_deg(a) + 90.0, 0))
	var cl: Label3D = D.text(g, "COLLECTIONS", Vector3(0, 0.26, 2.0), 0.0, 36, Color(0.75, 0.55, 1.0, 0.8), 1.2)
	cl.rotation = Vector3(-PI * 0.5, 0, 0)


# ================================================================== gameplay

func build_gameplay_extra() -> void:
	map_root.set("power_on_at_start", true)
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map04_kuendigung.json", "res://data/gravelight/quests/map04d_smile.json"]))   # T-115
	# the smile side egg (docs/MAP4_FERNFLUG.md §9.2): a marker at the crater rim, in the vacuum, under the Earth
	_node("res://gravelight/world/quest_interact.gd", "SmileMarker", {"target": &"smile_marker", "label_text": "THE RIM", "prompt_text": "look at the crack",
		"missing_text": "Locked: %s"}, Vector3(0.0, 0.0, 104.0), 180.0)
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
	for dd: Array in doors:
		var dn: Node = gameplay.get_node_or_null(str(dd[0]))
		if dn != null:
			dn.set("art_style", &"steel")
	_presentation()


## U09 s5 (T-149): the Sun, the sky, the airlocks' cycles, the hall's hum, and `zone` meta on every light.
func _presentation() -> void:
	# the Sun: the scene's "Moon" light, low over the east rim, hard and white (long shadows across the yard)
	var sun: DirectionalLight3D = map_root.get_node_or_null("Moon") as DirectionalLight3D
	if sun != null:
		# the Sun gate (moon_switch's idea): off inside the shelled domes away from the yard airlocks
		sun.set_script(load("res://gravelight/world/map04/sun_gate.gd"))
		sun.set("indoor_rects", [[-12.0, 12.0, 0.0, 60.0], [12.0, 44.0, -16.0, 60.0], [14.0, 42.0, -44.0, -16.0]])
		sun.set("door_points", PackedVector3Array([Vector3(0, 0, 60), Vector3(28, 0, 60)]))
		sun.transform = Transform3D(Basis.looking_at(-_sun_dir, Vector3.UP), Vector3.ZERO)
		sun.light_color = Color(1.0, 0.97, 0.92)
		sun.light_energy = 1.45
		sun.light_volumetric_fog_energy = 0.3
		sun.directional_shadow_max_distance = 90.0
		sun.shadow_blur = 0.4
		sun.set_meta("zone", &"C_YARD")
	# the sky: black, hard stars, the Sun's disc where the light comes from
	var we: WorldEnvironment = map_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null and we.environment.sky != null:
		var sky_mat: ShaderMaterial = ShaderMaterial.new()
		sky_mat.shader = load("res://gravelight/world/map04/moon_sky.gdshader") as Shader
		we.environment.sky.sky_material = sky_mat
	# the airlocks: the cycle (lamps, beacon, hiss, vapour) layered on the doors
	_node("res://gravelight/world/map04/airlock_cycle.gd", "AirlockCycle_Reception", {"zone_id": &"B_CONCOURSE", "width": 2.4}, Vector3(0, 0, 24), 0.0)
	_node("res://gravelight/world/map04/airlock_cycle.gd", "AirlockCycle_Yard", {"zone_id": &"C_YARD", "width": 2.4, "vacuum_side": true}, Vector3(0, 0, 60), 0.0)
	_node("res://gravelight/world/map04/airlock_cycle.gd", "AirlockCycle_Store", {"zone_id": &"D_FULFILLMENT", "width": 2.0, "vacuum_side": true}, Vector3(28, 0, 60), 0.0)
	# the hall's hum: the nave pendants' lights breathe with it (they stop when the relay is cut)
	var hp: Script = load("res://gravelight/world/map04/hum_pulse.gd") as Script
	var i: int = 0
	for p: Vector3 in [Vector3(20, CEIL_E - 1.6, 12), Vector3(36, CEIL_E - 1.6, 12), Vector3(20, CEIL_E - 1.6, -6), Vector3(36, CEIL_E - 1.6, -6)]:
		var l: OmniLight3D = D.omni(map_root, "HumPulse_%d" % i, p, VIOLET, 1.7, 14.0, "E_HALL", false, hp)
		l.set("base_energy", 1.7)
		l.set("phase", 0.7 * float(i))
		i += 1
	var shadowed: Dictionary = D.tag_lights(map_root, zone_boxes, "C_YARD")
	print("  shadowed lights per zone: %s" % [shadowed])
	# ViewCells: each dome shows itself and what its doors open onto; the act's lights follow their zone
	for c: Node in map_root.get_children():
		if c is Light3D and not (c is DirectionalLight3D) and c.has_meta("zone"):
			c.set_meta("vis_group", str(c.get_meta("zone")))
			c.add_to_group(&"view_cell_member", true)
	var vc: Node = Node.new()
	vc.set_script(load("res://gravelight/world/view_cells.gd"))
	vc.name = "ViewCells"
	var cells: Array = []
	for cdef: Array in [["A_RECEPTION", Vector3(-12, -5, 0), Vector3(12, 60, 24), ["A_RECEPTION", "B_CONCOURSE", "C_YARD"]],
			["B_CONCOURSE", Vector3(-12, -5, 24), Vector3(12, 60, 60), ["A_RECEPTION", "B_CONCOURSE", "C_YARD", "D_FULFILLMENT"]],
			["D_FULFILLMENT", Vector3(12, -5, 24), Vector3(44, 60, 60), ["B_CONCOURSE", "C_YARD", "D_FULFILLMENT", "E_HALL"]],
			["E_HALL", Vector3(12, -5, -16), Vector3(44, 60, 24), ["D_FULFILLMENT", "E_HALL", "F_CORE"]],
			["F_CORE", Vector3(14, -5, -44), Vector3(42, 60, -16), ["E_HALL", "F_CORE"]],
			["C_YARD", Vector3(-45, -5, 60), Vector3(45, 200, 115), ["B_CONCOURSE", "C_YARD", "D_FULFILLMENT"]]]:
		var lo: Vector3 = cdef[1]
		var hi: Vector3 = cdef[2]
		cells.append({"name": str(cdef[0]), "aabb": AABB(lo, hi - lo), "show": PackedStringArray(cdef[3]), "moon": true})
	vc.set("cells", cells)
	map_root.add_child(vc)
