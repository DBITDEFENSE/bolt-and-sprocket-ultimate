extends "res://gravelight/tools_src/gen_map04_lib.gd"
## Generates Map 4 Act I "Werk Thalbach" (UPDATE 07, docs/MAP4_FERNFLUG.md §3): a factory town around an aircraft
## works, eight zones on the door ladder 750 → 1000 → 1250 → 1500 → 2000, the Great Hangar with the Kranich
## greybox and the crane rails, per-zone navmesh regions, lights, and every gameplay node. Source of truth.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map04a.gd
##
## Frame: +X east, +Z north (toward the hangar), y up. Everything at y = 0 except the hangar catwalks (+12).
## Zone plan (x, z):  A_SIEDLUNG 0..40 × 0..30 · B_BAHNHOF 0..40 × 30..60 · C_KANTINE -44..0 × 30..60
## · D_KIRCHPLATZ 0..40 × 60..100 · E_MONTAGE -60..0 × 60..110 · F_WINDKANAL 0..44 × 100..130
## · G_PRUEFSTAND -60..0 × 110..150 · H_HALLE -70..30 × 150..215.

const CATY: float = 12.0
## Where Skyhook Sekt goes in the wind tunnel (Phase 2 step 8; nothing is placed here yet): [pos, yaw].
const SKYHOOK_SPOT: Array = [Vector3(1.0, 0.0, 104.0), -90.0]
const CRANE_Y: float = 12.0


func setup_tables() -> void:
	out_path = "res://gravelight/maps/map04_fernflug/map04a.tscn"
	root_name = "Map04aThalbach"
	map_id = "map04a_thalbach"
	display_name = "Fernflug — Act I: Werk Thalbach"
	start_zone = "A_SIEDLUNG"
	intro_text = "WERK THALBACH\nThuringian Forest, May 1945"
	json_table = "map04a"
	zone_bits = {"A_SIEDLUNG": 1, "B_BAHNHOF": 2, "C_KANTINE": 3, "D_KIRCHPLATZ": 4, "E_MONTAGE": 5, "F_WINDKANAL": 6,
		"G_PRUEFSTAND": 7, "H_HALLE": 8}
	adj = {"A_SIEDLUNG": ["B_BAHNHOF"], "B_BAHNHOF": ["A_SIEDLUNG", "C_KANTINE", "D_KIRCHPLATZ"], "C_KANTINE": ["B_BAHNHOF", "E_MONTAGE"],
		"D_KIRCHPLATZ": ["B_BAHNHOF", "F_WINDKANAL"], "E_MONTAGE": ["C_KANTINE", "G_PRUEFSTAND"], "F_WINDKANAL": ["D_KIRCHPLATZ", "G_PRUEFSTAND"],
		"G_PRUEFSTAND": ["E_MONTAGE", "F_WINDKANAL", "H_HALLE"], "H_HALLE": ["G_PRUEFSTAND"]}
	windows = [
		["W_A_S1", "A_SIEDLUNG", Vector3(20, 0, 0), 0.0], ["W_A_S2", "A_SIEDLUNG", Vector3(34, 0, 0), 0.0],
		["W_A_W", "A_SIEDLUNG", Vector3(0, 0, 16), 90.0], ["W_A_E", "A_SIEDLUNG", Vector3(40, 0, 16), -90.0],
		["W_B_W", "B_BAHNHOF", Vector3(0, 0, 40), 90.0], ["W_B_N", "B_BAHNHOF", Vector3(14, 0, 60), 180.0],
		["W_B_E", "B_BAHNHOF", Vector3(40, 0, 40), -90.0],
		["W_C_W", "C_KANTINE", Vector3(-44, 0, 48), 90.0], ["W_C_S", "C_KANTINE", Vector3(-22, 0, 30), 0.0],
		["W_D_E1", "D_KIRCHPLATZ", Vector3(40, 0, 70), -90.0], ["W_D_E2", "D_KIRCHPLATZ", Vector3(40, 0, 94), -90.0],
		["W_E_N", "E_MONTAGE", Vector3(-44, 0, 110), 180.0], ["W_E_W", "E_MONTAGE", Vector3(-60, 0, 90), 90.0],
		["W_F_E", "F_WINDKANAL", Vector3(44, 0, 108), -90.0], ["W_F_N", "F_WINDKANAL", Vector3(22, 0, 130), 180.0],
		["W_G_W", "G_PRUEFSTAND", Vector3(-60, 0, 118), 90.0], ["W_G_E", "G_PRUEFSTAND", Vector3(0, 0, 136), -90.0],
	]
	zone_boxes = [
		["A_SIEDLUNG", Vector3(0, -1, 0), Vector3(40, 7, 30)],
		["B_BAHNHOF", Vector3(0, -1, 30), Vector3(40, 7, 60)],
		["C_KANTINE", Vector3(-44, -1, 30), Vector3(0, 7, 60)],
		["D_KIRCHPLATZ", Vector3(0, -1, 60), Vector3(40, 7, 100)],
		["E_MONTAGE", Vector3(-60, -1, 60), Vector3(0, 7, 110)],
		["F_WINDKANAL", Vector3(0, -1, 100), Vector3(44, 7, 130)],
		["G_PRUEFSTAND", Vector3(-60, -1, 110), Vector3(0, 7, 150)],
		["H_HALLE", Vector3(-70, -1, 150), Vector3(30, 11.4, 215)],
		["H_HALLE", Vector3(-70, 11.4, 150), Vector3(-66.5, 15, 215)],   # west catwalk + its ramp top
		["H_HALLE", Vector3(26.5, 11.4, 150), Vector3(30, 15, 215)],     # east catwalk
	]
	for w: Array in windows:
		zone_boxes.append(closet_box(str(w[1]), w[2], float(w[3])))
	links = [
		[Vector3(20, 0, 29.6), Vector3(20, 0, 30.4), "B_BAHNHOF"],
		[Vector3(0.4, 0, 45), Vector3(-0.4, 0, 45), "C_KANTINE"],
		[Vector3(20, 0, 59.6), Vector3(20, 0, 60.4), "D_KIRCHPLATZ"],
		[Vector3(-22, 0, 59.6), Vector3(-22, 0, 60.4), "E_MONTAGE"],
		[Vector3(8, 0, 99.6), Vector3(8, 0, 100.4), "F_WINDKANAL"],
		[Vector3(-30, 0, 109.6), Vector3(-30, 0, 110.4), "G_PRUEFSTAND"],
		[Vector3(0.4, 0, 122), Vector3(-0.4, 0, 122), "G_PRUEFSTAND"],
		[Vector3(-30, 0, 149.6), Vector3(-30, 0, 150.4), "H_HALLE"],
		# the catwalk ramps cross the floor box / catwalk box seam at y = 11.4
		[Vector3(-68.2, 11.2, 170.6), Vector3(-68.2, 11.6, 171.4), "H_HALLE"],
		[Vector3(28.2, 11.2, 170.6), Vector3(28.2, 11.6, 171.4), "H_HALLE"],
	]
	buys = [
		["kar98k", Vector3(12.17, 1.5, 6.0), -90.0], ["m1_carbine", Vector3(36.0, 1.5, 29.83), 0.0],
		["mp40", Vector3(39.83, 1.5, 50.0), 90.0], ["thompson", Vector3(-10.0, 1.5, 59.83), 0.0],
		["m1_garand", Vector3(26.17, 1.5, 90.0), -90.0], ["stg44", Vector3(-0.17, 1.5, 80.0), 90.0],
		["bar", Vector3(-0.17, 1.5, 114.0), 90.0],
	]
	doors = [
		["Door_Bahnhof", "door_bahnhof", "B_BAHNHOF", [], "", 750, "Rail Yard", Vector3(20, 0, 30), 0.0, 2.0, false],
		["Door_Kantine", "door_kantine", "C_KANTINE", [], "", 1000, "Canteen", Vector3(0, 0, 45), 90.0, 2.0, false],
		["Door_Kirchplatz", "door_kirchplatz", "D_KIRCHPLATZ", [], "", 1000, "Church Square", Vector3(20, 0, 60), 0.0, 2.0, false],
		["Door_Montage", "door_montage", "E_MONTAGE", [], "", 1250, "Assembly Halls", Vector3(-22, 0, 60), 0.0, 2.0, false],
		["Door_Windkanal", "door_windkanal", "F_WINDKANAL", [], "", 1250, "Wind Tunnel", Vector3(8, 0, 100), 0.0, 2.0, false],
		["Door_Pruefstand", "door_pruefstand", "G_PRUEFSTAND", [], "pruefstand", 1500, "Engine Test Stands", Vector3(-30, 0, 110), 0.0, 2.0, false],
		["Door_ServiceGate", "door_pruefstand", "G_PRUEFSTAND", [], "pruefstand", 1500, "Engine Test Stands", Vector3(0, 0, 122), 90.0, 2.0, false],
		["Door_Halle", "door_halle", "H_HALLE", [], "", 2000, "The Great Hangar", Vector3(-30, 0, 150), 0.0, 3.0, true],
	]
	ammo_boxes = [
		["Siedlung", Vector3(6.0, 0, 29.48), 0.0], ["Bahnhof", Vector3(0.52, 0, 34.0), -90.0], ["Kantine", Vector3(-43.48, 0, 34.0), -90.0],
		["Montage", Vector3(-30.0, 0, 60.52), 180.0], ["Pruefstand", Vector3(-59.48, 0, 134.0), -90.0], ["Halle", Vector3(-69.48, 0, 153.0), -90.0],
	]
	grounds = [
		["A_SIEDLUNG", Vector3(30, 0, 26), 1],
		["B_BAHNHOF", Vector3(20, 0, 34), 1],
		["C_KANTINE", Vector3(-30, 0, 57), 1],
		["D_KIRCHPLATZ", Vector3(4, 0, 96), 1], ["D_KIRCHPLATZ", Vector3(36, 0, 64), 1],
		["E_MONTAGE", Vector3(-6, 0, 64), 1], ["E_MONTAGE", Vector3(-30, 0, 106), 1],
		["F_WINDKANAL", Vector3(40, 0, 126), 1],
		["G_PRUEFSTAND", Vector3(-30, 0, 113), 1], ["G_PRUEFSTAND", Vector3(-10, 0, 147), 1],
		["H_HALLE", Vector3(-60, 0, 155), 1], ["H_HALLE", Vector3(20, 0, 210), 1],
	]
	catwalks = [["H_HALLE", Vector3(-68.2, CATY, 200), true], ["H_HALLE", Vector3(28.2, CATY, 200), true]]
	perks = [
		["second_wind", Vector3(1.0, 0, 22.0), -90.0], ["ironhide_stout", Vector3(36.0, 0, 31.0), 180.0],
		["trigger_tonic", Vector3(-1.0, 0, 56.0), 90.0], ["twin_barrel", Vector3(6.0, 0, 99.0), 0.0],
		["marathon_malt", Vector3(-10.0, 0, 109.0), 0.0], ["hawkeye_brandy", Vector3(1.0, 0, 126.0), -90.0],
		["packmule_porter", Vector3(-20.0, 0, 149.0), 0.0], ["blastproof_bock", Vector3(-40.0, 0, 149.0), 0.0],
		# Ledger Lager (T-141): in the yardmaster's hut, on its far wall; the hut's south wall is the works' pay window (bank.json)
		["ledger_lager", Vector3(3.6, 0, 57.45), 0.0],
	]
	crates = [
		["Cellar", Vector3(7, 0, 3.2), 180.0, true, [Vector3(7, 0, 6), Vector3(7, 0, 12), Vector3(14, 0, 14)]],
		["Shed", Vector3(34, 0, 58.6), 0.0, true, [Vector3(34, 0, 56), Vector3(30, 0, 54), Vector3(24, 0, 50)]],
		["Parish", Vector3(36, 0, 98.6), 0.0, false, [Vector3(36, 0, 95), Vector3(34, 0, 90), Vector3(30, 0, 84)]],
		["Bunker", Vector3(-50, 0, 148.6), 0.0, false, [Vector3(-50, 0, 145), Vector3(-46, 0, 142), Vector3(-40, 0, 140)]],
	]
	player_spawns = [[Vector3(18, 0, 14), 0.0], [Vector3(22, 0, 14), 0.0], [Vector3(18, 0, 17), 0.0], [Vector3(22, 0, 17), 0.0]]
	power_switch = {"name": "Hauptschalter", "label": "the works' main breaker", "pos": Vector3(-59.0, 0, 66.0), "yaw": -90.0,
		"zone_order": ["E_MONTAGE", "C_KANTINE", "B_BAHNHOF", "A_SIEDLUNG", "D_KIRCHPLATZ", "F_WINDKANAL", "G_PRUEFSTAND", "H_HALLE"]}
	crucible = {"pos": Vector3(-58.5, 0, 146.0), "yaw": -90.0, "needs_power": true}
	armorers_bench = [Vector3(30.0, 0, 0.5 + T * 0.5 + 0.01), 0.0]
	burst_points = [Vector3(-30, 0, 70), Vector3(-30, 0, 100), Vector3(-6, 0, 64)]
	traps = [
		["res://gravelight/world/trap_chandelier.gd", "Trap_CoalHopper", {"drop_points": PackedVector3Array([Vector3(-10, 0, 0), Vector3(0, 0, 0), Vector3(10, 0, 0)]),
			"radius": 3.0, "hang_height": 6.0}, Vector3(20, 0, 45.5), 0.0, Vector3(39.6, 0, 47.0), 90.0, "coal_hopper"],
		["res://gravelight/world/trap_chandelier.gd", "Trap_JigCrane", {"drop_points": PackedVector3Array([Vector3(-10, 0, 0), Vector3(0, 0, 0), Vector3(10, 0, 0)]),
			"radius": 3.5, "hang_height": 7.5}, Vector3(-26, 0, 84), 0.0, Vector3(-0.4, 0, 90.0), 90.0, "jig_crane"],
	]
	mat_map = {
		"wall": "brick", "concrete": "concrete", "ground": "concrete_floor", "cobble": "stone", "metal": "iron", "steel": "steel",
		"rust": "rust", "furniture": "furniture", "rock": "concrete", "rail": "iron", "deck": "steel_grate", "stairs": "concrete",
		"roof": "roof", "planks": "planks", "grey": "grey_paint", "lead": "lead", "glass": "glass", "yellow": "crane_yellow",
		"stucco": "stucco", "tile": "tile_floor", "beam": "beam", "machine": "machine_grey", "olive": "feldgrau",
	}
	mat_rules = [["*Roof", "roof"], ["Platform*", "concrete"], ["Catwalk*", "steel_grate"], ["CraneRail*", "iron"], ["Ramp*", "steel_grate"],
		["Pit*", "concrete"], ["Tunnel*", "brick"], ["Ground", "concrete_floor"]]
	hide = ["NavBlock*", "Flatcar*", "Coffin*", "Table*", "Jig*", "Fan", "Crater", "Well", "Fountain", "Tower*", "GreatDoorsBlock",
		"Impeller*", "Kranich*", "Rubble*"]
	sky_top = Color(0.008, 0.01, 0.024)
	sky_horizon = Color(0.05, 0.045, 0.06)
	ambient = Color(0.24, 0.26, 0.34)
	fog_color = Color(0.1, 0.11, 0.14)
	moon_rot = Vector3(-38, -120, 0)


# ================================================================== geometry

func build_geometry() -> void:
	# one ground slab under the whole works, and the land beyond it
	box(geo, "Ground", Vector3(-70, -0.5, 0), Vector3(44, 0, 215), "ground")
	box(geo, "Land", Vector3(-260, -0.6, -200), Vector3(260, -0.1, 420), "dirt", false)
	_siedlung()
	_bahnhof()
	_kantine()
	_kirchplatz()
	_montage()
	_windkanal()
	_pruefstand()
	_halle()


func _siedlung() -> void:
	# the two housing blocks' facades (6 m) round the courtyard; windows on the outer faces
	wall_x("A_S", 0.0, 0 - T * 0.5, 40 + T * 0.5, 0, 6.0, [win(20, 0), win(34, 0)], "wall")
	wall_z("A_W", 0.0, 0, 30, 0, 6.0, [win(16, 0)], "wall")
	wall_z("A_E", 40.0, 0, 30, 0, 6.0, [win(16, 0)], "wall")
	wall_x("AB", 30.0, 0 - T * 0.5, 40 + T * 0.5, 0, 6.0, [door(20, 0)], "wall")
	# the air-raid cellar: a bunker room in block 1's ground floor (the crate's start spot)
	wall_z("CellarE", 12.0, 2, 10, 0, 3.0, [], "concrete")
	wall_x("CellarN", 10.0, 2 - T * 0.5, 12 + T * 0.5, 0, 3.0, [door(7, 0, 1.8)], "concrete")
	wall_z("CellarW", 2.0, 2, 10, 0, 3.0, [], "concrete")
	wall_x("CellarS", 2.0, 2 - T * 0.5, 12 + T * 0.5, 0, 3.0, [], "concrete")
	box(geo, "CellarRoof", Vector3(1.7, 3.0, 1.7), Vector3(12.3, 3.3, 10.3), "concrete")
	# the bomb crater (a rim) and the washing-line posts
	box(geo, "Crater", Vector3(22, 0, 20), Vector3(28, 0.6, 26), "dirt")
	for p: Vector3 in [Vector3(14, 0, 24), Vector3(14, 0, 8), Vector3(32, 0, 8)]:
		box(geo, "NavBlock_Post", p - Vector3(0.12, 0, 0.12), p + Vector3(0.12, 2.4, 0.12), "metal")
	for w: Array in windows:
		if str(w[1]) == "A_SIEDLUNG":
			closet(w[2], float(w[3]))


func _bahnhof() -> void:
	wall_z("B_W", 0.0, 30, 60, 0, 4.0, [win(40, 0), door(45, 0)], "wall")
	wall_z("B_E", 40.0, 30, 60, 0, 4.0, [win(40, 0)], "wall")
	wall_x("BD", 60.0, 0 - T * 0.5, 40 + T * 0.5, 0, 4.0, [win(14, 0), door(20, 0)], "wall")
	# the platform (a step the navmesh climbs), the two flatcars with the lead coffins
	box(geo, "Platform", Vector3(4, 0, 44), Vector3(36, 0.2, 47), "concrete")
	box(geo, "Flatcar1", Vector3(6, 0, 48), Vector3(16, 1.3, 51), "steel")
	box(geo, "Flatcar2", Vector3(20, 0, 48), Vector3(30, 1.3, 51), "steel")
	box(geo, "Coffin1", Vector3(8, 1.3, 48.6), Vector3(10.2, 2.1, 50.4), "lead")
	box(geo, "Coffin2", Vector3(22, 1.3, 48.6), Vector3(24.2, 2.1, 50.4), "lead")
	# the goods shed (NE) and the yardmaster's hut (NW)
	wall_z("ShedW", 28.0, 52, 60, 0, 4.0, [door(56, 0)], "planks")
	wall_x("ShedS", 52.0, 28 - T * 0.5, 40 + T * 0.5, 0, 4.0, [], "planks")
	box(geo, "ShedRoof", Vector3(27.7, 4.0, 51.7), Vector3(40.3, 4.3, 60.3), "roof")
	wall_z("HutE", 6.0, 50, 58, 0, 3.0, [door(54, 0, 1.8)], "planks")
	wall_x("HutS", 50.0, 0 - T * 0.5, 6 + T * 0.5, 0, 3.0, [], "planks")
	wall_x("HutN", 58.0, 0 - T * 0.5, 6 + T * 0.5, 0, 3.0, [], "planks")
	box(geo, "HutRoof", Vector3(-0.3, 3.0, 49.7), Vector3(6.3, 3.3, 58.3), "roof")
	box(geo, "HutDesk", Vector3(0.4, 0, 55.5), Vector3(2.4, 0.8, 57.5), "furniture")
	for w: Array in windows:
		if str(w[1]) == "B_BAHNHOF":
			closet(w[2], float(w[3]))


func _kantine() -> void:
	wall_x("C_S", 30.0, -44 - T * 0.5, 0 + T * 0.5, 0, 6.0, [win(-22, 0)], "wall")
	wall_z("C_W", -44.0, 30, 60, 0, 6.0, [win(48, 0)], "wall")
	wall_x("CE", 60.0, -44 - T * 0.5, 0 + T * 0.5, 0, 6.0, [door(-22, 0)], "wall")
	box(geo, "CanteenRoof", Vector3(-44.3, 6.0, 29.7), Vector3(0.3, 6.3, 60.3), "roof")
	for tz: float in [38.0, 44.0, 50.0]:
		box(geo, "Table%d" % int(tz), Vector3(-38, 0, tz), Vector3(-10, 0.8, tz + 1.4), "furniture")
	box(geo, "NavBlock_Stage", Vector3(-44, 0, 54), Vector3(-34, 0.25, 60), "planks")
	box(geo, "NavBlock_Hatch", Vector3(-43.7, 0.9, 46.5), Vector3(-42.6, 1.0, 49.5), "furniture")
	for w: Array in windows:
		if str(w[1]) == "C_KANTINE":
			closet(w[2], float(w[3]))


func _kirchplatz() -> void:
	wall_z("D_E", 40.0, 60, 100, 0, 5.0, [win(70, 0), win(94, 0)], "wall")
	wall_z("DE_W", 0.0, 60, 100, 0, 9.0, [], "wall")   # also the assembly halls' east wall
	wall_x("DF", 100.0, 0 - T * 0.5, 44 + T * 0.5, 0, 8.0, [door(8, 0)], "wall")
	# the bombed tower (solid, 14 m, rubble skirt), the well, the fountain
	box(geo, "Tower", Vector3(14, 0, 86), Vector3(26, 14, 100), "stone")
	box(geo, "Rubble1", Vector3(12, 0, 84), Vector3(28, 0.9, 86), "stone")
	box(geo, "Well", Vector3(6.8, 0, 78.8), Vector3(9.2, 1.1, 81.2), "stone")
	box(geo, "Fountain", Vector3(28, 0, 70), Vector3(32, 0.9, 74), "stone")
	# the parish house (NE corner)
	wall_z("ParishW", 30.0, 88, 100, 0, 4.0, [], "planks")
	wall_x("ParishS", 88.0, 30 - T * 0.5, 40 + T * 0.5, 0, 4.0, [door(35, 0)], "planks")
	box(geo, "ParishRoof", Vector3(29.7, 4.0, 87.7), Vector3(40.3, 4.3, 100.3), "roof")
	for w: Array in windows:
		if str(w[1]) == "D_KIRCHPLATZ":
			closet(w[2], float(w[3]))


func _montage() -> void:
	wall_x("E_S", 60.0, -60 - T * 0.5, -44 - T * 0.5, 0, 9.0, [], "wall")
	wall_z("E_W", -60.0, 60, 110, 0, 9.0, [win(90, 0)], "wall")
	wall_x("EG", 110.0, -60 - T * 0.5, 0 + T * 0.5, 0, 9.0, [win(-44, 0), door(-30, 0)], "wall")
	box(geo, "MontageRoof", Vector3(-60.3, 9.0, 59.7), Vector3(0.3, 9.3, 110.3), "roof", false)
	# the two jigs with the half-built little wings, the gantry legs
	box(geo, "Jig1", Vector3(-40, 0, 70), Vector3(-12, 2.5, 78), "steel")
	box(geo, "Jig2", Vector3(-40, 0, 94), Vector3(-12, 2.5, 102), "steel")
	for gx: float in [-44.0, -8.0]:
		for gz: float in [66.0, 106.0]:
			box(geo, "NavBlock_Gantry", Vector3(gx - 0.3, 0, gz - 0.3), Vector3(gx + 0.3, 8.8, gz + 0.3), "steel")
	# the Kraftzentrale annex: the power house, its breaker inside
	wall_z("KraftE", -48.0, 60, 75, 0, 4.0, [door(68, 0)], "concrete")
	wall_x("KraftN", 75.0, -60 - T * 0.5, -48 + T * 0.5, 0, 4.0, [], "concrete")
	box(geo, "KraftRoof", Vector3(-60.3, 4.0, 59.7), Vector3(-47.7, 4.3, 75.3), "concrete")
	box(geo, "NavBlock_Generator", Vector3(-58, 0, 69), Vector3(-52, 1.6, 73), "machine")
	box(geo, "NavBlock_DeskE", Vector3(-15.0, 0, 105.2), Vector3(-13.8, 0.8, 106.0), "furniture")   # hall 2's office desk: Fernflug file 1 (T-114)
	for w: Array in windows:
		if str(w[1]) == "E_MONTAGE":
			closet(w[2], float(w[3]))


func _windkanal() -> void:
	wall_z("F_E", 44.0, 100, 130, 0, 8.0, [win(108, 0)], "wall")
	wall_x("F_N", 130.0, 0 - T * 0.5, 44 + T * 0.5, 0, 8.0, [win(22, 0)], "wall")
	wall_z("FG", 0.0, 100, 130, 0, 8.0, [door(122, 0)], "wall")   # also the test stands' east wall (z 110..130)
	box(geo, "WindkanalRoof", Vector3(-0.3, 8.0, 99.7), Vector3(44.3, 8.3, 130.3), "roof", false)
	# the tunnel: a brick horn the length of the hall, open at both ends, the test section's glass wall
	wall_z("TunnelS", 112.0, 6, 38, 0, 2.4, [], "wall")   # along x at z=112... built as x-walls below
	geo.get_child(geo.get_child_count() - 1).free()
	wall_x("TunnelS", 112.0, 6, 38, 0, 2.4, [], "wall")
	wall_x("TunnelN", 118.0, 6, 26, 0, 2.4, [], "wall")
	box(geo, "TunnelGlass", Vector3(26, 0, 118 - T * 0.5), Vector3(38, 2.4, 118 + T * 0.5), "glass")
	box(geo, "Fan", Vector3(0.3, 0, 110.5), Vector3(3.2, 7.0, 119.5), "steel")
	box(geo, "NavBlock_Sting", Vector3(30.6, 0, 114.6), Vector3(31.4, 1.2, 115.4), "steel")
	box(geo, "NavBlock_DeskF", Vector3(40.4, 0, 120.6), Vector3(41.6, 0.8, 121.4), "furniture")   # the tunnel office's hatch desk: file 2 (T-114)
	for w: Array in windows:
		if str(w[1]) == "F_WINDKANAL":
			closet(w[2], float(w[3]))


func _pruefstand() -> void:
	wall_z("G_W", -60.0, 110, 150, 0, 5.0, [win(118, 0)], "concrete")
	wall_z("G_E", 0.0, 130, 150, 0, 5.0, [win(136, 0)], "concrete")
	wall_x("GH", 150.0, -60 - T * 0.5, 0 + T * 0.5, 0, 5.0, [door(-30, 0, 3.0)], "concrete")
	# four engine pits in a row behind the blast wall; pit 4 holds the live impeller
	var px: float = -52.0
	for i: int in 4:
		box(geo, "Pit%d" % (i + 1), Vector3(px, 0, 124), Vector3(px + 8, 1.0, 132), "concrete")
		px += 12.0
	box(geo, "NavBlock_BlastWall", Vector3(-56, 0, 134), Vector3(-4, 3.0, 134.6), "concrete")
	# the control bunker with the Crucible
	wall_z("BunkerE", -48.0, 138, 150, 0, 4.0, [door(144, 0)], "concrete")
	wall_x("BunkerS", 138.0, -60 - T * 0.5, -48 + T * 0.5, 0, 4.0, [], "concrete")
	box(geo, "BunkerRoof", Vector3(-60.3, 4.0, 137.7), Vector3(-47.7, 4.3, 150.3), "concrete")
	box(geo, "NavBlock_DeskG", Vector3(-58.2, 0, 146.6), Vector3(-57.0, 0.8, 147.4), "furniture")   # the bunker's desk: file 3 (T-114)
	for w: Array in windows:
		if str(w[1]) == "G_PRUEFSTAND":
			closet(w[2], float(w[3]))


func _halle() -> void:
	# the Great Hangar: 100 × 65 m, 20 m walls, the doors in the north wall (a block collider; dressed as doors)
	wall_x("H_S", 150.0, -70 - T * 0.5, -60 - T * 0.5, 0, 20.0, [], "concrete")
	wall_x("H_S2", 150.0, 0 + T * 0.5, 30 + T * 0.5, 0, 20.0, [], "concrete")
	wall_z("H_W", -70.0, 150, 215, 0, 20.0, [], "concrete")
	wall_z("H_E", 30.0, 150, 215, 0, 20.0, [], "concrete")
	wall_x("H_N", 215.0, -70 - T * 0.5, 30 + T * 0.5, 0, 20.0, [[-40.0, 0.0, 0.0, 16.0]], "concrete")
	box(geo, "GreatDoorsBlock", Vector3(-40, 0, 215 - T * 0.5), Vector3(0, 16, 215 + T * 0.5), "steel")
	box(geo, "HalleRoof", Vector3(-70.3, 20.0, 149.7), Vector3(30.3, 20.4, 215.3), "roof", false)
	# the Kranich: centre body, two wings, the ramp up into the aft bay (its top meets the body)
	box(geo, "KranichBody", Vector3(-30, 0, 165), Vector3(-10, 3.0, 205), "steel")
	box(geo, "KranichWingL", Vector3(-60, 0, 175), Vector3(-30, 2.0, 195), "steel")
	box(geo, "KranichWingR", Vector3(-10, 0, 175), Vector3(20, 2.0, 195), "steel")
	ramp_z("Ramp_Bay", -24.0, -16.0, 159.0, 165.0, 0.0, 2.0)
	rail("Rail_RampW", Vector3(-24, 0.2, 159), Vector3(-24, 2.2, 165), 1.0)
	rail("Rail_RampE", Vector3(-16, 0.2, 159), Vector3(-16, 2.2, 165), 1.0)
	for ix: float in [-50.0, -38.0, -2.0, 10.0]:
		box(geo, "Impeller%d" % int(ix), Vector3(ix - 2.5, 0, 182.5), Vector3(ix + 2.5, 5.0, 187.5), "steel")
	# the catwalks (+12) along both long walls with their ramps up from the south corners, the crane rails
	for side: Array in [[-70.0, -66.5, "W"], [26.5, 30.0, "E"]]:
		var x0: float = float(side[0])
		var x1: float = float(side[1])
		var s: String = str(side[2])
		box(geo, "Catwalk" + s, Vector3(x0, CATY - 0.2, 171), Vector3(x1, CATY, 215), "deck")
		ramp_z("Ramp_Catwalk" + s, x0, x1, 150.5, 171.0, 0.0, CATY)
		rail("Rail_Catwalk" + s, Vector3(x1 if s == "W" else x0, CATY, 171), Vector3(x1 if s == "W" else x0, CATY, 215), 1.05)
		rail("Rail_Ramp" + s, Vector3(x1 if s == "W" else x0, 0.2, 150.5), Vector3(x1 if s == "W" else x0, CATY + 0.2, 171), 1.05)
		box(geo, "CraneRail" + s, Vector3(x0 + 1.5, CRANE_Y + 1.2, 152), Vector3(x0 + 2.0, CRANE_Y + 1.6, 213), "metal", false)
	# the tool cage by the south-west corner (the ammo box's wall)
	box(geo, "NavBlock_ToolCage", Vector3(-66, 0, 150.5), Vector3(-62, 2.2, 153.5), "metal")


# ================================================================== dressing + lights

func build_dressing() -> void:
	# the Kranich's visible body (non-colliding) as ONE kept group named "Kranich" so the boarding cutscene's
	# `kranich_takeoff` fx can roll it out and lift it (UPDATE 07 §11.1): the hump of the centre body, the wings'
	# thickness taper, the intake rims; the ramp plank is its own kept group "KranichRamp", hinged at the top edge,
	# so the `ramp` fx swings it shut
	var kr: Node3D = Props.group(dress, "Kranich", Vector3(-20, 0, 185))
	kr.set_meta("keep", true)
	Props.block(kr, Vector3(-10, 3.0, -20), Vector3(10, 8.0, 18), "steel")
	Props.block(kr, Vector3(-7, 8.0, -13), Vector3(7, 12.0, 13), "steel")
	Props.block(kr, Vector3(-40, 2.0, -7), Vector3(-10, 3.6, 7), "steel")
	Props.block(kr, Vector3(10, 2.0, -7), Vector3(40, 3.6, 7), "steel")
	Props.block(kr, Vector3(-40, 0.0, -10), Vector3(-10, 2.0, 10), "steel")
	Props.block(kr, Vector3(10, 0.0, -10), Vector3(40, 2.0, 10), "steel")
	Props.block(kr, Vector3(-10, 0.0, -20), Vector3(10, 3.0, 20), "steel")
	for ix: float in [-30.0, -18.0, 18.0, 30.0]:
		Props.cyl(kr, Vector3(ix, 2.5, 0), 2.5, 5.0, "steel")
		Props.cyl(kr, Vector3(ix, 5.0, 0), 2.3, 1.0, "nachtglas")   # the intake rim glow
		lamp(Vector3(ix - 20.0, 3.0, 180), VIOLET, 1.2, 10.0, 0.08, 0.8)
	var rp: Node3D = Props.group(dress, "KranichRamp", Vector3(-20, 2.05, 165))
	rp.set_meta("keep", true)
	Props.block(rp, Vector3(-3.9, -0.12, -6.3), Vector3(3.9, 0.0, 0.0), "steel_grate")
	label("der KRANICH", Vector3(-20, 9.0, 163.5), 180.0, 72, Color(0.85, 0.82, 0.72, 0.9))
	# the hangar doors (dressing panels that `fx: doors` swings down), the crane bridge at rest, fog on the floor
	var gd: Node3D = Props.group(dress, "GreatDoors", Vector3(-20, 0, 214.6))
	gd.set_meta("keep", true)
	for sx: float in [-1.0, 1.0]:
		Props.block(gd, Vector3(sx * 0.2, 0, -0.2), Vector3(sx * 19.8, 16, 0.2), "steel")
	var bridge: Node3D = Props.group(dress, "CraneBridge", Vector3(-20, CRANE_Y + 1.6, 158))
	bridge.set_meta("keep", true)
	Props.block(bridge, Vector3(-48, 0, -0.5), Vector3(48, 0.8, 0.5), "crane_yellow")
	Props.block(bridge, Vector3(44, -2.6, -1.2), Vector3(48, 0, 1.2), "crane_yellow")   # the cab at the east end
	fog("HalleFog", Vector3(-20, 1.0, 182), Vector3(100, 2.4, 64), 0.08, Color(0.72, 0.76, 0.86))
	# searchlights sweeping the clouds from the works' corners (shadowless spots aimed up)
	for sp: Array in [[Vector3(-66, 6, 64), Vector3(-30, 60, 120)], [Vector3(42, 6, 32), Vector3(10, 60, 110)]]:
		shaft("Searchlight", sp[0], sp[1], MERCURY, 6.0, 90.0, 10.0, 2.0, false)
	# lamps the dead left burning, fire barrels in the yards, moonlight through the sheds' windows
	for p: Vector3 in [Vector3(20, 0, 24), Vector3(34, 0, 38), Vector3(10, 0, 66), Vector3(-30, 0, 118)]:
		brazier(p)
	for id: String in ["W_C_W", "W_C_S", "W_E_W", "W_F_E", "W_F_N", "W_E_N"]:
		moon_window(id, 0.8)
	# power lights: pendants per hall, floods in the yards, the hangar's banks
	for zp: Array in [
			["A_SIEDLUNG", Vector3(10, 4.5, 15)], ["A_SIEDLUNG", Vector3(30, 4.5, 15)], ["A_SIEDLUNG", Vector3(7, 2.6, 6)],
			["B_BAHNHOF", Vector3(20, 3.6, 45)], ["B_BAHNHOF", Vector3(34, 3.4, 56)], ["B_BAHNHOF", Vector3(3, 2.6, 54)],
			["C_KANTINE", Vector3(-30, 4.8, 45)], ["C_KANTINE", Vector3(-14, 4.8, 45)], ["C_KANTINE", Vector3(-39, 3.5, 57)],
			["D_KIRCHPLATZ", Vector3(10, 4.5, 75)], ["D_KIRCHPLATZ", Vector3(34, 3.4, 94)], ["D_KIRCHPLATZ", Vector3(30, 4.5, 66)],
			["E_MONTAGE", Vector3(-26, 7.5, 74)], ["E_MONTAGE", Vector3(-26, 7.5, 98)], ["E_MONTAGE", Vector3(-54, 3.4, 67)],
			["F_WINDKANAL", Vector3(22, 6.5, 106)], ["F_WINDKANAL", Vector3(22, 6.5, 124)], ["F_WINDKANAL", Vector3(32, 3.2, 115)],
			["G_PRUEFSTAND", Vector3(-30, 4.5, 118)], ["G_PRUEFSTAND", Vector3(-30, 4.5, 142)], ["G_PRUEFSTAND", Vector3(-54, 3.4, 144)],
			["H_HALLE", Vector3(-45, 16, 165)], ["H_HALLE", Vector3(5, 16, 165)], ["H_HALLE", Vector3(-45, 16, 200)], ["H_HALLE", Vector3(5, 16, 200)],
			["H_HALLE", Vector3(-20, 16, 182)]]:
		var zone: String = str(zp[0])
		var pos: Vector3 = zp[1]
		if zone == "H_HALLE":
			power(zone, pos, 40.0, 1.6, MERCURY, false, {"dir": Vector3.DOWN, "energy": 2.0, "range": 40.0, "angle": 50.0})
		elif zone in ["A_SIEDLUNG", "B_BAHNHOF", "D_KIRCHPLATZ", "G_PRUEFSTAND"]:
			power(zone, pos, 18.0, 1.1, SODIUM)
		else:
			pendant(zone, pos, pos.y + 1.5, "enamel_green", 1.3)
	# the live impeller in pit 4: a violet glow with no power needed
	_noshadow(CYL(Vector3(-16, 1.4, 128), 2.2, 0.8, "nachtglas"))
	lamp(Vector3(-16, 2.6, 128), VIOLET, 1.6, 12.0, 0.1, 1.0)
	# stencils and signs
	label("WERK THALBACH", Vector3(20, 4.2, 29.7), 180.0, 56)
	label("KANTINE", Vector3(-22, 4.0, 30.3), 0.0, 48)
	label("MONTAGE 1 · 2", Vector3(-22, 7.0, 60.3), 0.0, 48)
	label("WINDKANAL", Vector3(8, 5.0, 100.3), 0.0, 48)
	label("PRÜFSTAND", Vector3(-30, 4.2, 110.3), 0.0, 48)
	label("HALLE", Vector3(-30, 4.4, 150.3), 0.0, 48)


func build_gameplay_extra() -> void:
	# the act controller (the hangar unlock, the boss schedule) and the Fliegeralarm special round
	_node("res://gravelight/maps/map04_fernflug/act_controller.gd", "ActController", {}, Vector3.ZERO)
	_node("res://gravelight/enemies/map04/fliegeralarm.gd", "Fliegeralarm", {}, Vector3.ZERO)
	# the Great Hangar waits for the works' power AND the act's unlock (the files, or act round halle_open_round)
	var halle: Node = gameplay.get_node_or_null("Door_Halle")
	if halle != null:
		halle.set("requires_flag", &"halle_unlocked")
		halle.set("requires_text", "The hangar is sealed: find the Fernflug files")
	# the main egg "Kündigung" and the side egg "Jette's logbook" (UPDATE 07, T-114; docs/MAP4_FERNFLUG.md §9)
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map04_kuendigung.json", "res://data/gravelight/quests/map04a_jette.json"]))
	# the three Fernflug files (each shows two digits of the PA extension, seeded per match)
	var files: Array = [["File1", "I", Vector3(-14.4, 0.82, 105.6), 0], ["File2", "II", Vector3(41.0, 0.82, 121.0), 2], ["File3", "III", Vector3(-57.6, 0.82, 147.0), 4]]
	for i: int in files.size():
		var f: Array = files[i]
		_node("res://gravelight/world/quest_note.gd", str(f[0]), {"tag": &"fernflug_file", "item_id": StringName("file_%d" % (i + 1)), "numeral": str(f[1]),
			"kind": "file", "set_flag": StringName("file_%d" % (i + 1)), "random_key": "map04_kuendigung:files", "digit_from": int(f[3]), "digit_count": 2,
			"note_text": "??"}, f[2], 0.0)
	# the canteen stage's PA switchboard: dial the three files' extensions in order (s3)
	_node("res://gravelight/world/switchboard.gd", "PASwitchboard", {"target": &"pa_switchboard", "quest": &"map04_kuendigung", "step": &"s3_pa_line",
		"sign": "WERK THALBACH  ·  HAUSANLAGE", "prompt_text": "dial the office line"}, Vector3(-39.0, 0.0, 53.2), 0.0)
	# the wind tunnel's fan control (s4; also a trap)
	_node("res://gravelight/world/map04/wind_tunnel.gd", "WindTunnel", {"lo": Vector3(6, 0, 112), "hi": Vector3(38, 2.4, 118)}, Vector3(4.6, 0, 121.0), 90.0)
	# the Kranich's ramp: the boarding step (s6) needs the hangar key and the door code
	_node("res://gravelight/world/quest_interact.gd", "RampSwitch", {"target": &"kranich_ramp", "label_text": "DER KRANICH · LADERAMPE", "prompt_text": "board the Kranich",
		"missing_text": "The ramp is locked: it needs %s", "flag_labels": {"hangar_key": "the hangar key", "hangar_code_known": "the door code"}}, Vector3(-20.0, 0, 160.5), 180.0)
	# Jette's logbook: three glider models and the office hatch
	for m: Array in [["Glider1", "I", "the canteen stage", Vector3(-36.0, 0.3, 54.3)], ["Glider2", "II", "the hall 2 jig", Vector3(-42.0, 0.1, 96.0)], ["Glider3", "III", "the test-section glass", Vector3(33.0, 0.1, 119.6)]]:
		_node("res://gravelight/world/quest_note.gd", str(m[0]), {"tag": &"glider_model", "item_id": StringName("glider_%s" % str(m[1]).to_lower()), "numeral": str(m[1]),
			"kind": "model", "note_text": str(m[2])}, m[3], 0.0)
	_node("res://gravelight/world/quest_interact.gd", "JetteHatch", {"target": &"jette_hatch", "label_text": "WINDKANAL · BÜRO MAURER", "prompt_text": "put the models on Jette's desk",
		"missing_text": "The hatch is shut: %s", "flag_labels": {}, "size": Vector3(1.0, 1.6, 1.0)}, Vector3(43.2, 0, 124.0), -90.0)
