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
## UPDATE 10 Act I (T-155): the air raid's breach in the Montage's north wall and the wind tunnel's plenum hatch.
const BREACH_X: float = -55.0
const BREACH_W: float = 3.0
const HATCH_Z: float = 102.5
const HATCH_W: float = 1.6
const HATCH_H: float = 2.0


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
			"radius": 3.0, "hang_height": 6.0, "style": &"skip", "chain_m": 2.2}, Vector3(20, 0, 45.5), 0.0, Vector3(39.6, 0, 47.0), 90.0, "coal_hopper"],
		["res://gravelight/world/trap_chandelier.gd", "Trap_JigCrane", {"drop_points": PackedVector3Array([Vector3(-10, 0, 0), Vector3(0, 0, 0), Vector3(10, 0, 0)]),
			"radius": 3.5, "hang_height": 7.5, "style": &"wing", "chain_m": 1.1}, Vector3(-26, 0, 84), 0.0, Vector3(-0.4, 0, 90.0), 90.0, "jig_crane"],
		# UPDATE 10 (T-155): the rivet line runs Montage 1's south aisle (x -46.5..-1.5, z 62.4..65.6); the lever on the
		# Kraftzentrale's east wall, beside its door
		["res://gravelight/world/map04/trap_rivet_line.gd", "Trap_RivetLine", {"track_start": Vector3(-21.0, 0, 0), "track_end": Vector3(21.0, 0, 0)},
			Vector3(-24.0, 0, 64.0), 0.0, Vector3(-47.75, 0, 72.0), -90.0, "rivet_line"],
	]
	mat_map = {
		"wall": "brick", "concrete": "concrete", "ground": "concrete_floor", "cobble": "stone", "metal": "iron", "steel": "steel",
		"rust": "rust", "furniture": "furniture", "rock": "concrete", "rail": "iron", "deck": "steel_grate", "stairs": "concrete",
		"roof": "roof", "planks": "planks", "grey": "grey_paint", "lead": "lead", "glass": "glass", "yellow": "crane_yellow",
		"stucco": "stucco", "tile": "tile_floor", "beam": "beam", "machine": "machine_grey", "olive": "feldgrau",
	}
	# U09 (T-146): a distinct material per block (rendered housing, works brick, board-formed concrete, corrugated
	# sheds); materials only, every collider stays where it was. First match wins.
	mat_rules = [["CellarRoof", "concrete"], ["KraftRoof", "concrete"], ["BunkerRoof", "concrete"], ["HutRoof", "roof"], ["ParishRoof", "planks"], ["*Roof", "fl_corrugated"],
		["Platform*", "concrete"], ["Catwalk*", "fl_grate"], ["CraneRail*", "iron"], ["Ramp*", "fl_grate"], ["Pit*", "fl_concrete"],
		["Tunnel*", "fl_brick"], ["Ground", "fl_floor"], ["A_*", "fl_plaster"], ["AB_*", "fl_brick"], ["B_*", "fl_brick"], ["BD_*", "fl_brick"],
		["C_*", "fl_brick"], ["CE_*", "fl_brick"], ["D_E_*", "fl_plaster"], ["DE_W*", "fl_brick"], ["DF_*", "fl_brick"], ["E_*", "fl_brick"],
		["EG_*", "fl_brick"], ["Kraft*", "fl_brick"], ["F_*", "fl_brick"], ["FG_*", "fl_brick"], ["G_*", "fl_concrete"], ["GH_*", "fl_concrete"],
		["Bunker*", "fl_concrete"], ["H_*", "fl_concrete"], ["Shed*", "fl_corrugated"], ["Parish*", "fl_plaster"], ["Cellar*", "fl_concrete"]]
	# hidden visuals (their colliders stay): the boxes the dressing redraws (the flat roofs under the sawtooth and
	# hangar roofs, the solid rail boxes under the railings)
	hide = ["NavBlock*", "Flatcar*", "Coffin*", "Table*", "Jig*", "Fan", "Crater", "Well", "Fountain", "Tower*", "GreatDoorsBlock",
		"Impeller*", "Kranich*", "Rubble*", "MontageRoof", "HalleRoof", "Rail_*", "BreachPlug", "TunnelHatchPlug"]
	sky_top = Color(0.006, 0.008, 0.02)
	sky_horizon = Color(0.06, 0.05, 0.07)
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
	wall_x("EG", 110.0, -60 - T * 0.5, 0 + T * 0.5, 0, 9.0, [win(-44, 0), door(-30, 0), door(BREACH_X, 0, BREACH_W)], "wall")
	# UPDATE 10 (T-155): the air raid's Breach_E_apron. The gap is plugged (a world-layer collider, so the navmesh is baked
	# shut through it; its visual is the raid node's brick patch) until the raid blows it open.
	box(geo, "BreachPlug", Vector3(BREACH_X - BREACH_W * 0.5, 0, 110.0 - T * 0.5), Vector3(BREACH_X + BREACH_W * 0.5, DOOR_H, 110.0 + T * 0.5), "wall")
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
	wall_z("FG", 0.0, 100, 130, 0, 8.0, [door(122, 0), gap(HATCH_Z, 0, HATCH_W, HATCH_H)], "wall")   # also the test stands' east wall (z 110..130)
	# UPDATE 10 (T-155): the wind tunnel's plenum hatch into Montage 2, plugged (the hatch opens it while the fan runs)
	box(geo, "TunnelHatchPlug", Vector3(-T * 0.5, 0, HATCH_Z - HATCH_W * 0.5), Vector3(T * 0.5, HATCH_H, HATCH_Z + HATCH_W * 0.5), "wall")
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


# ================================================================== dressing + lights (UPDATE 09 §5, T-146)
# Everything below is non-colliding art: the colliders, the navmesh, the doors, the windows, the traps' gameplay and
# every prompt are built above and in gen_map04_lib.gd, unchanged. Detail pieces come from GenDetail
# (gen_detail_lib.gd); small trim casts no shadow; repeated pieces are BakedMultiMeshes; the rest is folded into
# StaticBatches by merge_static_meshes. Lights: every light has a fixture you can see; one key light (a shadowed
# spot) per zone; the rest shadowless; tag_light_zones() gives every light its `zone` meta and holds the cap of 6.

## The Kranich's flying-wing shell (GenDetail.wing_surface params), in the kept "Kranich" group's frame (+Z = nose,
## toward the hangar doors). It covers the act's Kranich colliders (the 20 × 40 × 3 m centre body, the 30 × 20 × 2 m
## wing blocks) and the bay notch leaves the ramp clear; the four 5 m engine blocks sit under the engine bulges.
const KRANICH_AT: Vector3 = Vector3(-20, 0, 185)
const KRANICH_WING: Dictionary = {"span": 86.0, "le_root": 26.0, "le_sweep": 0.22, "te_sweep": 0.12, "t_root": 7.0, "t_tip": 4.2,
	"tip_pow": 20.0, "base": 0.2, "body_half": 10.5, "body_h": 3.3, "body_z": Vector2(-20.5, 21.0), "notch_half": 5.0, "notch_te": -20.0}
const KRANICH_ENGINES: Array = [-30.0, -18.0, 18.0, 30.0]
const KRANICH_PAINT: String = "olive_steel"
const WARM: Color = Color(1.0, 0.72, 0.42)
## Whether the per-zone key spots cast shadows (measured against contract C4; see T-146).
const KEY_SHADOW: bool = false


func build_dressing() -> void:
	_dress_kranich()
	_dress_halle()
	_dress_montage()
	_dress_bahnhof()
	_dress_siedlung()
	_dress_kantine()
	_dress_kirchplatz()
	_dress_windkanal()
	_dress_pruefstand()
	_dress_works()
	_lights()


## A shadowless box into the dressing.
func NB(a: Vector3, b: Vector3, key: String, parent: Node3D = null) -> MeshInstance3D:
	return Props.block(parent if parent != null else dress, a, b, key, false)


## The yaw that turns a wall item's local -Z (its face) toward `out`.
func _out_yaw(out: Vector3) -> float:
	if absf(out.x) > absf(out.z):
		return -90.0 if out.x > 0.0 else 90.0
	return 180.0 if out.z > 0.0 else 0.0


## A façade's blind windows: one per (along, sill) pair, on the face line `face` (z for a wall facing ±Z, x for one
## facing ±X), facing `out`. A seeded mix: curtains, a few lit with a silhouette behind the curtain, some broken,
## shutters on the lower floors. Returns the lit windows' centres (for their spill lamps).
func _facade(g: Node3D, out: Vector3, face: float, along: Array, sills: Array, w: float, h: float, seed_v: int,
		lit_share: float = 0.1, curtain_keys: Array = ["cloth_cream", "linen", "cloth_red", "cloth_green"]) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var lit: Array = []
	var yaw: float = _out_yaw(out)
	var z_face: bool = absf(out.z) > 0.5
	for s: float in sills:
		for a: float in along:
			var pos: Vector3 = Vector3(a, s, face) if z_face else Vector3(face, s, a)
			var o: Dictionary = {"blind": true, "seed": rng.randi(), "mullions": [2, 3], "frame": "beam", "sill_key": "stucco_trim", "frost": rng.randf() < 0.35}
			var roll: float = rng.randf()
			if roll < lit_share:
				o["lit"] = WARM
				o["curtain"] = curtain_keys[rng.randi() % curtain_keys.size()]
				o["silhouette"] = rng.randf() < 0.6
				lit.append(pos + Vector3(0, h * 0.5, 0) + out.normalized() * 0.6)
			elif roll < 0.62:
				o["curtain"] = curtain_keys[rng.randi() % curtain_keys.size()]
				o["broken"] = 0.25 if rng.randf() < 0.3 else 0.0
			else:
				o["broken"] = rng.randf_range(0.3, 0.9)
			if s < 1.5 and rng.randf() < 0.5:
				o["shutters"] = true
			GenDetail.window(g, pos, yaw, w, h, o)
	return lit


## Frames round the act's barricade windows (the openings stay exactly as built: frames and sills sit outside them).
func _frame_gameplay_windows(g: Node3D, zone: String, frame_key: String) -> void:
	for w: Array in windows:
		if str(w[1]) != zone:
			continue
		var p: Vector3 = w[2]
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		GenDetail.window(g, p + inward * (T * 0.5) + Vector3(0, SILL, 0), float(w[3]) + 180.0, 1.6, WTOP - SILL, {"open": true, "frame": frame_key})


## Frames on both faces of every gameplay door in `zone` (the door node draws its own leaf).
func _frame_gameplay_doors(g: Node3D, zone_list: Array, frame_key: String) -> void:
	for d: Array in doors:
		if not zone_list.has(str(d[2])):
			continue
		var p: Vector3 = d[7]
		var n: Vector3 = Basis(Vector3.UP, deg_to_rad(float(d[8]))) * Vector3(0, 0, 1)
		for s: float in [-1.0, 1.0]:
			GenDetail.door(g, p + n * s * (T * 0.5), _out_yaw(n * s), float(d[9]), DOOR_H, {"leaf": "", "frame": frame_key, "step": false})


# ------------------------------------------------------------------ H: der Kranich

func _dress_kranich() -> void:
	# ONE kept group named "Kranich": the boarding cutscene's `kranich_takeoff` fx rolls it out and lifts it (UPDATE 07
	# §11.1). The shell is a lofted flying wing (GenDetail.flying_wing_mesh); the crown, canopy, engine bulges,
	# intakes and exhausts are primitives folded into a few meshes (GenDetail.merge_children).
	var kr: Node3D = Props.group(dress, "Kranich", KRANICH_AT)
	kr.set_meta("keep", true)
	var shell: MeshInstance3D = MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = GenDetail.flying_wing_mesh(KRANICH_WING, 48, 28)
	shell.material_override = Mats.get_mat(KRANICH_PAINT)
	kr.add_child(shell)
	Props.ball(kr, Vector3(0, 2.9, 1.0), Vector3(15.5, 5.6, 34), KRANICH_PAINT)          # the crown over the centre body
	Props.ball(kr, Vector3(0, 5.25, 11.5), Vector3(3.8, 1.9, 6.5), "glass")              # the cockpit canopy
	for cz: float in [9.6, 11.5, 13.4]:
		Props.obox(kr, Vector3(0, 5.6, cz), Vector3(3.5, 0.07, 0.07), "black_paint")
	Props.obox(kr, Vector3(0, 6.15, 11.5), Vector3(0.07, 0.07, 5.8), "black_paint")
	for ix: float in KRANICH_ENGINES:
		var le: float = float(KRANICH_WING["le_root"]) - absf(ix) * float(KRANICH_WING["le_sweep"])
		var te: float = -float(KRANICH_WING["le_root"]) + absf(ix) * float(KRANICH_WING["te_sweep"])
		Props.ball(kr, Vector3(ix, 4.0, 0), Vector3(6.8, 3.8, 14), KRANICH_PAINT)       # the engine bay bulge
		Props.obox(kr, Vector3(ix, 1.3, (le - 2.0 + 7.0) * 0.5), Vector3(2.4, 1.6, le - 2.0 - 7.0), KRANICH_PAINT)   # the intake duct fairing
		Props.cyl(kr, Vector3(ix, 1.35, le - 1.55), 1.15, 0.5, "black_paint", Vector3(90, 0, 0))    # the intake lip
		Props.cyl(kr, Vector3(ix, 1.35, le - 1.75), 0.95, 0.2, "nachtglas", Vector3(90, 0, 0))     # the impeller glow inside
		Props.cyl(kr, Vector3(ix, 0.8, te + 3.4), 0.55, 3.0, "char", Vector3(90, 0, 0))            # the exhaust, buried in the trailing edge
		Props.cyl(kr, Vector3(ix, 0.8, te + 1.88), 0.42, 0.06, "black_paint", Vector3(90, 0, 0))
	# the bomb bay's mouth over the ramp (the ramp plank is its own kept group, below)
	Props.block(kr, Vector3(-3.9, 0.3, -20.12), Vector3(3.9, 3.15, -19.98), "black_paint")
	for bx: float in [-4.0, 4.0]:
		Props.block(kr, Vector3(bx - 0.12, 0.2, -20.2), Vector3(bx + 0.12, 3.3, -19.9), "iron")
	# panel seams along the span and chord lines on the upper surface (dark strips riding the shell)
	for sx: float in [-36.0, -26.0, -12.0, 12.0, 26.0, 36.0]:
		for sz: float in [-6.0, 4.0, 12.0]:
			var hs: Vector2 = GenDetail.wing_surface(sx, sz, KRANICH_WING)
			if hs.x > 0.0:
				Props.obox(kr, Vector3(sx, hs.x + 0.02, sz), Vector3(0.05, 0.03, 6.0), "black_paint")
	# beaching trolleys under the trailing and leading edges (what it stands on)
	for tx: float in [-34.0, -14.0, 14.0, 34.0]:
		Props.block(kr, Vector3(tx - 1.0, 0.0, -4.0), Vector3(tx + 1.0, 0.22, 4.0), "iron")
	label("der KRANICH", Vector3(0, 2.4, -20.3), 180.0, 64, Color(0.85, 0.82, 0.72, 0.9), kr)
	label("W 1001", Vector3(-40.0, 3.0, 0.0), 90.0, 120, Color(0.12, 0.12, 0.12, 0.75), kr)
	GenDetail.merge_children(kr)
	var rp: Node3D = Props.group(dress, "KranichRamp", Vector3(-20, 2.05, 165))
	rp.set_meta("keep", true)
	Props.block(rp, Vector3(-3.9, -0.12, -6.3), Vector3(3.9, 0.0, 0.0), "steel_grate")
	for rx: float in [-3.85, 3.85]:
		Props.block(rp, Vector3(rx - 0.06, -0.3, -6.3), Vector3(rx + 0.06, 0.0, 0.0), "iron")
	for rz: float in [-5.4, -4.2, -3.0, -1.8, -0.6]:
		Props.block(rp, Vector3(-3.8, 0.0, rz - 0.03), Vector3(3.8, 0.03, rz + 0.03), "iron")
	# the impellers' violet glow at the intake mouths (no power needed: they are already turning over)
	for ix2: float in KRANICH_ENGINES:
		var le2: float = float(KRANICH_WING["le_root"]) - absf(ix2) * float(KRANICH_WING["le_sweep"])
		lamp(KRANICH_AT + Vector3(ix2, 1.4, le2 + 0.8), VIOLET, 1.2, 10.0, 0.08, 0.8)


# ------------------------------------------------------------------ H: the Great Hangar

func _dress_halle() -> void:
	var g: Node3D = Props.group(dress, "HalleDress", Vector3.ZERO)
	# the south wall above the Prüfstand's 5 m wall: the hangar closes to its 20 m height (non-colliding; G is open air)
	box(dress, "HalleSouthUpper", Vector3(-60.15, 5.0, 150.0 - T * 0.5), Vector3(0.15, 20.0, 150.0 + T * 0.5), "fl_concrete", false)
	# board-formed walls: lift lines every 1.2 m and pilasters every ~8 m on the inner faces (no tie holes on walls this big)
	GenDetail.form_board(g, Vector3(-69.85, 0, 150.15), Vector3(-69.85, 20, 214.85), Vector3.RIGHT, 1.2, "fl_concrete", false)
	GenDetail.form_board(g, Vector3(29.85, 0, 150.15), Vector3(29.85, 20, 214.85), Vector3.LEFT, 1.2, "fl_concrete", false)
	GenDetail.form_board(g, Vector3(-69.85, 0, 214.85), Vector3(29.85, 20, 214.85), Vector3.FORWARD, 1.2, "fl_concrete", false)
	GenDetail.form_board(g, Vector3(-69.85, 5, 150.15), Vector3(29.85, 20, 150.15), Vector3.BACK, 1.2, "fl_concrete", false)
	for pz: float in [158.0, 166.0, 174.0, 182.0, 190.0, 198.0, 206.0]:
		for side: Array in [[-69.85, 1.0], [29.85, -1.0]]:
			var x: float = float(side[0])
			var s: float = float(side[1])
			Props.block(g, Vector3(x, 0, pz - 0.35), Vector3(x + s * 0.16, 20.0, pz + 0.35), "fl_concrete")
	for px: float in [-62.0, -50.0, -44.0, 4.0, 10.0, 22.0]:
		Props.block(g, Vector3(px - 0.35, 0, 214.85), Vector3(px + 0.35, 20.0, 214.69), "fl_concrete")
	# a plinth band and weathering: water runs from the roof, rust under the crane-rail brackets, oil on the floor
	for wall: Array in [[Vector3(-69.85, 0, 150.2), Vector3(-69.85, 0, 214.8), Vector3.RIGHT], [Vector3(29.85, 0, 150.2), Vector3(29.85, 0, 214.8), Vector3.LEFT],
			[Vector3(-69.8, 0, 214.85), Vector3(29.8, 0, 214.85), Vector3.FORWARD]]:
		GenDetail.trim(g, wall[0], wall[1], wall[2], 0.9, 0.05, "fl_floor")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8150
	for i: int in 14:
		var wz: float = rng.randf_range(152.0, 213.0)
		var west: bool = i % 2 == 0
		GenDetail.card(g, "water", Vector3(-69.84 if west else 29.84, rng.randf_range(12.0, 17.0), wz), Vector3.RIGHT if west else Vector3.LEFT, Vector2(rng.randf_range(0.8, 2.0), 7.0))
		GenDetail.rust_streak(g, Vector3(-69.84 if west else 29.84, CRANE_Y + 1.1, wz), Vector3.RIGHT if west else Vector3.LEFT, 0.5, 2.4)
	for i2: int in 10:
		GenDetail.card(g, "soot", Vector3(rng.randf_range(-66.0, 26.0), 0.012, rng.randf_range(152.0, 212.0)), Vector3.UP, Vector2(rng.randf_range(1.5, 4.0), rng.randf_range(1.0, 3.0)))
	# the floor: painted guide lines round the Kranich and to the doors, tie-down rings
	for gl: Array in [[Vector3(-66.0, 0, 157.0), Vector3(26.0, 0, 157.0)], [Vector3(-66.0, 0, 212.0), Vector3(26.0, 0, 212.0)],
			[Vector3(-66.0, 0, 157.0), Vector3(-66.0, 0, 212.0)], [Vector3(26.0, 0, 157.0), Vector3(26.0, 0, 212.0)], [Vector3(-20.0, 0, 151.0), Vector3(-20.0, 0, 158.0)]]:
		var a: Vector3 = gl[0]
		var b: Vector3 = gl[1]
		NB(Vector3(minf(a.x, b.x) - 0.08, 0.004, minf(a.z, b.z) - 0.08), Vector3(maxf(a.x, b.x) + 0.08, 0.012, maxf(a.z, b.z) + 0.08), "yellow_paint", g)
	for rx: float in [-60.0, -40.0, 0.0, 20.0]:
		for rz: float in [165.0, 205.0]:
			Props.cyl(g, Vector3(rx, 0.02, rz), 0.18, 0.04, "iron")
	# the roof: trusses spanning north-south every ~8 m, purlins, corrugated roof with a skylight strip; netting above
	for tx: float in [-66.0, -57.7, -49.4, -41.1, -32.8, -24.5, -16.2, -7.9, 0.4, 8.7, 17.0, 25.3]:
		GenDetail.truss(g, Vector3(tx, 16.0, 150.3), Vector3(tx, 16.0, 214.7), 3.6, "steel", 3.2, 0.24, 0.12, false)
	for pz2: float in [153.0, 160.0, 167.0, 174.0, 181.0, 188.0, 195.0, 202.0, 209.0]:
		GenDetail.i_beam(g, Vector3(-69.8, 19.75, pz2), Vector3(29.8, 19.75, pz2), 0.45, 0.2, "steel", Vector3.UP, false)
	for slab: Array in [[150.0, 178.0], [192.0, 215.0]]:
		GenDetail.corrugated_sheet(g, Vector3(-70.3, 20.0, float(slab[0]) - 0.3), Vector3(30.3, 20.2, float(slab[1]) + 0.3))
	GenDetail._ns(Props.block(g, Vector3(-70.0, 20.05, 178.0), Vector3(30.0, 20.1, 192.0), "glass"))
	for mx: int in 21:
		NB(Vector3(-70.0 + float(mx) * 5.0 - 0.05, 20.0, 178.0), Vector3(-70.0 + float(mx) * 5.0 + 0.05, 20.2, 192.0), "steel", g)
	GenDetail.camo_net(dress, Vector3(-78.0, 0, 142.0), Vector3(38.0, 23.0, 223.0), 1.2, 10.0, 6.0, "nsew")
	# the crane runway: rail heads and hangers to the wall on the existing crane-rail line (the Kranführer's rail)
	for side2: Array in [[-70.0, -68.5, 1.0], [30.0, 28.0, -1.0]]:
		var wx: float = float(side2[0])
		var rx2: float = float(side2[1])
		var s2: float = float(side2[2])
		for hz: float in [154.0, 162.0, 170.0, 178.0, 186.0, 194.0, 202.0, 210.0]:
			Props.strut(g, Vector3(wx + s2 * 0.15, CRANE_Y + 3.4, hz), Vector3(rx2 + 0.25, CRANE_Y + 1.62, hz), 0.12, "steel")
			NB(Vector3(wx, CRANE_Y + 1.5, hz - 0.2), Vector3(wx + s2 * 0.4, CRANE_Y + 2.0, hz + 0.2), "steel", g)
	# catwalks: grating dress over the deck, railings over the hidden rail colliders, knee braces to the wall
	for side3: Array in [[-70.0, -66.5, "W"], [26.5, 30.0, "E"]]:
		var x0: float = float(side3[0])
		var x1: float = float(side3[1])
		var edge: float = x1 if str(side3[2]) == "W" else x0
		var wall_x0: float = x0 if str(side3[2]) == "W" else x1
		GenDetail.railing(g, Vector3(edge, CATY, 171.0), Vector3(edge, CATY, 214.8), 1.05, "iron")
		var rr: Node3D = GenDetail.railing(g, Vector3(edge, 0.2, 150.5), Vector3(edge, CATY + 0.2, 171.0), 1.05, "iron", false)
		rr.name = "RampRailing"
		for kz: float in [173.0, 179.0, 185.0, 191.0, 197.0, 203.0, 209.0]:
			Props.strut(g, Vector3(wall_x0, CATY - 2.6, kz), Vector3(edge, CATY - 0.22, kz), 0.12, "steel")
			NB(Vector3(minf(wall_x0, edge), CATY - 0.4, kz - 0.06), Vector3(maxf(wall_x0, edge), CATY - 0.2, kz + 0.06), "steel", g)
		GenDetail.i_beam(g, Vector3(edge, 0.05, 150.5), Vector3(edge, CATY - 0.05, 171.0), 0.35, 0.16, "steel", Vector3.UP, false)
	# the bay ramp's rails
	for bx: float in [-24.0, -16.0]:
		GenDetail.railing(g, Vector3(bx, 0.2, 159.0), Vector3(bx, 2.2, 165.0), 1.0, "iron", false)
	# the Great Doors (a kept group the `doors` fx swings): stiffener bands and ribs, a track girder over them
	var gd: Node3D = Props.group(dress, "GreatDoors", Vector3(-20, 0, 214.6))
	gd.set_meta("keep", true)
	for sx: float in [-1.0, 1.0]:
		Props.block(gd, Vector3(sx * 0.2, 0, -0.2), Vector3(sx * 19.8, 16, 0.2), "steel")
		for by: float in [0.6, 3.2, 6.4, 9.6, 12.8, 15.6]:
			Props.block(gd, Vector3(sx * 0.2, by - 0.18, -0.32), Vector3(sx * 19.8, by + 0.18, -0.2), "iron")
		for bxx: float in [2.5, 7.5, 12.5, 17.5]:
			Props.block(gd, Vector3(sx * bxx - 0.12, 0.2, -0.3), Vector3(sx * bxx + 0.12, 15.8, -0.2), "iron")
		Props.block(gd, Vector3(sx * 0.2, 7.0, -0.22), Vector3(sx * 19.8, 8.4, -0.19), "window_dark")
		Props.stencil(gd, Vector3(sx * 10.0, 11.2, -0.33), 0.0, "HALLE 3" if sx < 0.0 else "TOR GESCHLOSSEN HALTEN", 200 if sx < 0.0 else 90, Color(0.85, 0.82, 0.7, 0.7))
	GenDetail.merge_children(gd)
	GenDetail.i_beam(g, Vector3(-41.0, 16.6, 214.45), Vector3(1.0, 16.6, 214.45), 0.9, 0.4, "steel")
	# the crane bridge at rest over the ramp (a kept group): the travelling crane with the Kranführer's cab at its east end
	var bridge: Node3D = Props.group(dress, "CraneBridge", Vector3(-20, CRANE_Y + 1.6, 158))
	bridge.set_meta("keep", true)
	GenDetail.crane_gantry(bridge, -48.0, 48.0, 0.0, 0.0, "crane_yellow", -6.0, 5.0, 1)
	Props.stencil(bridge, Vector3(0, 0.8, -1.21), 0.0, "WERK THALBACH  ·  40 t", 120, Color(0.1, 0.1, 0.1, 0.8))
	GenDetail.merge_children(bridge)
	# the tool cage (its collider is NavBlock_ToolCage): chain-link on the open sides, shelves, a sign; jerrycans and drums
	GenDetail.chain_link(g, Vector3(-62.0, 0, 150.5), Vector3(-62.0, 0, 153.5), 2.2)
	GenDetail.chain_link(g, Vector3(-66.0, 0, 153.5), Vector3(-62.0, 0, 153.5), 2.2)
	Props.shelves(g, Vector3(-64.0, 0, 150.75), 180.0, 3.2, 1.9, 0.4, 4, 21)
	GenDetail.enamel_sign(g, Vector3(-64.0, 2.5, 153.56), 180.0, "WERKZEUGAUSGABE", 1.4, 0.26)
	for jc: Vector3 in [Vector3(-63.0, 0, 152.6), Vector3(-63.4, 0, 152.2), Vector3(-64.8, 0, 152.6)]:
		_lib(g, "jerrycan", jc, 90.0)
	for dz: float in [210.6, 211.4]:
		Props.oil_drum(g, Vector3(29.35, 0, dz), "rust")
	# ground fog that reads without volumetrics (the FogVolume below is for Forward+)
	GenDetail.fog_sheets(dress, Vector3(-20, 0, 182), Vector2(96, 60), 1.3, 3, Color(0.66, 0.7, 0.8, 0.13))
	fog("HalleFog", Vector3(-20, 1.0, 182), Vector3(100, 2.4, 64), 0.08, Color(0.72, 0.76, 0.86))
	# signs
	GenDetail.enamel_sign(g, Vector3(-30.0, 3.2, 150.17), 180.0, "RAUCHEN UND OFFENES LICHT VERBOTEN", 2.4, 0.3, "enamel_white", Color(0.5, 0.06, 0.04))
	GenDetail.poster(g, Vector3(-55.0, 1.7, 150.17), 180.0, "HALLENORDNUNG", "Kein Zutritt ohne Ausweis.\nDer Kranführer hat Vorfahrt.\nTore nur auf Anweisung öffnen.", 0.5, 0.7)


## A PropLibrary prop (CC0 GLB) into `parent` at a floor position. Visual only (the library strips collision).
func _lib(parent: Node3D, key: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0) -> Node3D:
	var p: Node3D = PropLibrary.instance(key)
	if p == null:
		return null
	p.position = pos
	p.rotation.y = deg_to_rad(yaw)
	p.scale = Vector3.ONE * s
	parent.add_child(p)
	return p


# ------------------------------------------------------------------ E: Montage

func _dress_montage() -> void:
	var g: Node3D = Props.group(dress, "MontageDress", Vector3.ZERO)
	# close the 6..9 m slot over the canteen roof and the 8..9 m slot over the tunnel hall's wall
	box(dress, "MontageCloseS", Vector3(-44.15, 6.3, 60.0 - T * 0.5), Vector3(0.15, 9.0, 60.0 + T * 0.5), "fl_brick", false)
	box(dress, "MontageCloseE", Vector3(-T * 0.5, 8.0, 100.0), Vector3(T * 0.5, 9.0, 110.15), "fl_brick", false)
	# two sawtooth halls (north lights facing north), a valley girder between them, camouflage netting over both
	GenDetail.sawtooth_roof(g, Vector3(-60.0, 9.0, 60.0), Vector3(0.0, 9.0, 85.0), 5, 2.4)
	# hall 2 in three parts (UPDATE 10, T-155): the middle bay (x -38..-22) is "Hall2Roof", kept out of the batches, the
	# roof the air raid brings down (ThalbachRaid drops and hides it)
	GenDetail.sawtooth_roof(g, Vector3(-60.0, 9.0, 85.0), Vector3(-38.0, 9.0, 110.0), 5, 2.4)
	GenDetail.sawtooth_roof(g, Vector3(-22.0, 9.0, 85.0), Vector3(0.0, 9.0, 110.0), 5, 2.4)
	var h2: Node3D = Props.group(dress, "Hall2Roof", Vector3.ZERO)
	h2.set_meta("keep", true)
	GenDetail.sawtooth_roof(h2, Vector3(-38.0, 9.0, 85.0), Vector3(-22.0, 9.0, 110.0), 5, 2.4)
	for tz: float in [90.0, 100.0]:
		GenDetail.i_beam(h2, Vector3(-38.0, 8.75, tz), Vector3(-22.0, 8.75, tz), 0.4, 0.2, "steel")
	GenDetail.merge_children(h2)
	GenDetail.i_beam(g, Vector3(-60.0, 8.6, 85.0), Vector3(0.0, 8.6, 85.0), 0.8, 0.35, "steel")
	GenDetail.camo_net(dress, Vector3(-64.0, 0, 56.0), Vector3(4.0, 12.4, 114.0), 0.9, 8.0, 3.0, "nsew")
	# brick piers on the walls under each valley, and tall steel-framed factory windows high on the west wall
	for vz: float in [65.0, 70.0, 75.0, 80.0, 90.0, 95.0, 100.0, 105.0]:
		Props.block(g, Vector3(-59.85, 0, vz - 0.3), Vector3(-59.7, 9.0, vz + 0.3), "fl_brick")
		Props.block(g, Vector3(-0.15, 0, vz - 0.3), Vector3(-0.3, 9.0, vz + 0.3), "fl_brick")
	for wz: float in [67.5, 72.5, 77.5, 92.5, 97.5, 102.5]:
		GenDetail.window(g, Vector3(-59.85, 3.6, wz), -90.0, 3.0, 4.2, {"blind": true, "mullions": [4, 6], "frame": "steel", "sill_key": "concrete",
			"broken": 0.45, "glass": "glass", "seed": int(wz)})
	_frame_gameplay_windows(g, "E_MONTAGE", "steel")
	_frame_gameplay_doors(g, ["E_MONTAGE", "G_PRUEFSTAND"], "steel")
	# the floor: worn concrete; yellow safety lines round the jigs
	NB(Vector3(-59.85, 0.0, 60.15), Vector3(-0.15, 0.006, 109.85), "fl_floor", g)
	for jz: Array in [[70.0, 78.0], [94.0, 102.0]]:
		var z0: float = float(jz[0]) - 0.9
		var z1: float = float(jz[1]) + 0.9
		for e: Array in [[Vector3(-40.9, 0.007, z0), Vector3(-11.1, 0.012, z0 + 0.12)], [Vector3(-40.9, 0.007, z1 - 0.12), Vector3(-11.1, 0.012, z1)],
				[Vector3(-40.9, 0.007, z0), Vector3(-40.78, 0.012, z1)], [Vector3(-11.22, 0.007, z0), Vector3(-11.1, 0.012, z1)]]:
			NB(e[0], e[1], "yellow_paint", g)
	# the jigs (their colliders are Jig1/Jig2, 28 × 8 × 2.5 m): base beams, uprights, cradle formers, decks, ladders,
	# and in each the fighter-scale flying wing: ribs and spars, half-skinned in jig 1, barely started in jig 2
	_jig(g, 70.0, 78.0, 0.45, 1)
	_jig(g, 94.0, 102.0, 0.2, 2)
	# the gantry (its four legs are the NavBlock_Gantry boxes): portal columns, runway girders along both sides,
	# the jig crane's bridge parked over the trap line at z 84.5 (the Jig Crane trap hangs its wing section from it)
	for gx: float in [-44.0, -8.0]:
		for gz: float in [66.0, 106.0]:
			Props.block(g, Vector3(gx - 0.3, 0, gz - 0.3), Vector3(gx + 0.3, 8.4, gz + 0.3), "crane_yellow")
			NB(Vector3(gx - 0.42, 0, gz - 0.42), Vector3(gx + 0.42, 0.25, gz + 0.42), "concrete", g)
		GenDetail.i_beam(g, Vector3(gx, 8.0, 65.6), Vector3(gx, 8.0, 106.4), 0.8, 0.4, "crane_yellow")
	for gz2: float in [66.0, 106.0]:
		GenDetail.i_beam(g, Vector3(-44.3, 8.0, gz2), Vector3(-7.7, 8.0, gz2), 0.8, 0.4, "crane_yellow")
	GenDetail.crane_gantry(g, -44.0, -8.0, 84.5, 8.4, "crane_yellow", -26.0, 0.6, 0)
	# rivet rigs: guns on spring balancers hanging over the jigs; compressed-air lines along the gantry
	for rg: Vector3 in [Vector3(-34.0, 0, 74.0), Vector3(-22.0, 0, 75.0), Vector3(-17.0, 0, 72.5), Vector3(-30.0, 0, 98.0), Vector3(-20.0, 0, 99.0)]:
		Props.cable(g, Vector3(rg.x, 8.0, rg.z), Vector3(rg.x, 4.6, rg.z), 0.0, 0.012, 2, "iron")
		Props.cyl(g, Vector3(rg.x, 4.75, rg.z), 0.08, 0.25, "machine_grey")
		Props.obox(g, Vector3(rg.x, 4.35, rg.z), Vector3(0.09, 0.32, 0.16), "machine_grey", Vector3(0, 0, 12))
		Props.cable(g, Vector3(rg.x, 4.4, rg.z), Vector3(rg.x + 0.6, 8.0, rg.z + 0.4), 0.6, 0.015, 6, "rubber")
	for gx2: float in [-44.0, -8.0]:
		GenDetail.pipe_run(g, PackedVector3Array([Vector3(gx2 + 0.35, 7.4, 66.5), Vector3(gx2 + 0.35, 7.4, 105.5)]), 0.05, "iron", 4.0)
	# the hall 2 office desk (file 1): a drawing board, a lamp, papers pinned up on the north wall
	Props.obox(g, Vector3(-14.4, 1.05, 106.15), Vector3(1.1, 0.04, 0.7), "board_wood", Vector3(-25, 0, 0))
	GenDetail.lamp_fixture(g, Vector3(-13.95, 1.35, 105.4), "wall", 0.0, 0.0, "enamel_green")
	GenDetail.poster(g, Vector3(-14.4, 2.1, 109.84), 0.0, "PRÜFPLAN W 1001", "Holm 2: Nieten nachziehen.\nRippe 14 bis 19: Lehre neu einmessen.\nAbnahme: Wittkamp.", 0.6, 0.45)
	GenDetail.poster(g, Vector3(-17.2, 2.0, 109.84), 0.0, "SCHICHTPLAN", "Frühschicht 5 Uhr\nSpätschicht 14 Uhr\nNachtschicht entfällt", 0.42, 0.55, "paper", Color(0.1, 0.1, 0.12), 2.0)
	GenDetail.chalk_mark(g, Vector3(-12.5, 1.6, 109.84), 0.0, "tally", 0.35)
	# the Kraftzentrale annex (Kraft* walls, brick): its door, the generator set, the switchgear, the breaker panel
	_dress_kraftzentrale(g)
	# signs and stencils
	GenDetail.enamel_sign(g, Vector3(-22.0, 3.6, 60.17), 180.0, "MONTAGE 1", 1.6, 0.4, "enamel_white", Color(0.08, 0.12, 0.2))
	GenDetail.enamel_sign(g, Vector3(-30.0, 3.4, 109.83), 0.0, "MONTAGE 2  ·  PRÜFSTAND", 2.2, 0.36, "enamel_white", Color(0.08, 0.12, 0.2))
	GenDetail.enamel_sign(g, Vector3(-0.17, 2.8, 80.0), 90.0, "HELM TRAGEN", 1.1, 0.3, "enamel_white", Color(0.45, 0.08, 0.05))
	for i: int in 6:
		GenDetail.rust_streak(g, Vector3(-59.84, 8.7, 63.0 + float(i) * 8.0), Vector3.RIGHT, 0.6, 3.0)


func _jig(g: Node3D, z0: float, z1: float, skin: float, n: int) -> void:
	var x0: float = -40.0
	var x1: float = -12.0
	for bz: float in [z0 + 0.35, z1 - 0.35]:
		GenDetail.i_beam(g, Vector3(x0 + 0.1, 0.2, bz), Vector3(x1 - 0.1, 0.2, bz), 0.4, 0.3, "crane_yellow")
	var ux: float = x0 + 0.3
	while ux <= x1 - 0.2:
		for uz: float in [z0 + 0.35, z1 - 0.35]:
			Props.block(g, Vector3(ux - 0.13, 0.4, uz - 0.13), Vector3(ux + 0.13, 2.5, uz + 0.13), "crane_yellow")
		GenDetail.i_beam(g, Vector3(ux, 2.35, z0 + 0.2), Vector3(ux, 2.35, z1 - 0.2), 0.3, 0.2, "crane_yellow")
		Props.obox(g, Vector3(ux, 2.6, (z0 + z1) * 0.5 + 0.6), Vector3(0.12, 0.25, 5.4), "machine_grey", Vector3(-4, 0, 0))   # the cradle former
		ux += 3.45
	# plank work decks along both long edges and a ladder at each end
	for dz: Array in [[z0 + 0.05, z0 + 0.75], [z1 - 0.75, z1 - 0.05]]:
		Props.block(g, Vector3(x0 + 0.05, 2.4, float(dz[0])), Vector3(x1 - 0.05, 2.5, float(dz[1])), "planks")
	Props.ladder(g, Vector3(x0 + 0.15, 0, (z0 + z1) * 0.5), -90.0, 2.5)
	Props.ladder(g, Vector3(x1 - 0.15, 0, (z0 + z1) * 0.5), 90.0, 2.5)
	# the wing: two half-wings meeting at x -26, leading edge along z1 - 0.6, chord running south
	var le_z: float = z1 - 0.6
	GenDetail.wing_skeleton(g, Vector3(-19.5, 3.0, le_z), 0.0, 13.0, 6.6, 2.4, skin, 1.1, "machine_grey", "chrome_worn", 0.24, false)
	GenDetail.wing_skeleton(g, Vector3(-32.5, 3.0, le_z), 0.0, 13.0, 6.6, 2.4, skin * 0.7, 1.1, "machine_grey", "chrome_worn", 0.24, true)
	# an engine on its stand by the wing root, toolboxes on the deck, chalk on an upright (the labourers' marks)
	var ez: float = z0 + 1.6
	Props.block(g, Vector3(-27.4, 2.5, ez - 0.5), Vector3(-24.6, 2.62, ez + 0.5), "crane_yellow")
	Props.cyl(g, Vector3(-26.0, 3.2, ez), 0.45, 2.6, "steel", Vector3(0, 0, 90))
	Props.cone(g, Vector3(-27.5, 3.2, ez), 0.45, 0.5, "chrome_worn", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(-24.5, 3.2, ez), 0.33, 0.5, "char", Vector3(0, 0, 90))
	_lib(g, "toolbox_metal", Vector3(-35.0, 2.5, z0 + 0.4), 10.0)
	_lib(g, "toolbox_metal", Vector3(-15.5, 2.5, z1 - 0.4), 190.0)
	GenDetail.chalk_mark(g, Vector3(-36.85, 1.2, z0 + 0.22), 0.0, "jakub", 0.3)
	if n == 2:
		GenDetail.chalk_mark(g, Vector3(-19.95, 1.3, z0 + 0.22), 0.0, "jakub", 0.28)
	Props.stencil(g, Vector3(-26.0, 1.6, z0 + 0.2), 0.0, "LEHRE %d  ·  W 1002/%d" % [n, n], 70, Color(0.1, 0.1, 0.1, 0.8))


func _dress_kraftzentrale(g: Node3D) -> void:
	GenDetail.door(g, Vector3(-47.85, 0, 68.0), -90.0, 2.0, DOOR_H, {"leaf": "iron", "steel": true, "open_deg": 170.0, "frame": "steel",
		"sign": "KRAFTZENTRALE"})
	GenDetail.door(g, Vector3(-48.15, 0, 68.0), 90.0, 2.0, DOOR_H, {"leaf": "", "frame": "steel", "step": false})
	GenDetail.enamel_sign(g, Vector3(-47.83, 1.6, 70.4), -90.0, "HOCHSPANNUNG  ·  LEBENSGEFAHR", 1.3, 0.36, "enamel_white", Color(0.55, 0.06, 0.04))
	# the generator set on NavBlock_Generator (-58..-52 × 69..73 × 1.6): a bedplate, the motor, the generator drum, the flywheel
	Props.block(g, Vector3(-57.9, 0, 69.1), Vector3(-52.1, 0.35, 72.9), "concrete")
	Props.block(g, Vector3(-57.6, 0.35, 69.6), Vector3(-55.0, 1.5, 72.4), "machine_green")
	Props.cyl(g, Vector3(-53.9, 0.95, 71.0), 0.62, 1.8, "machine_green", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(-52.6, 0.9, 71.0), 0.55, 0.22, "iron", Vector3(0, 0, 90))
	for vx: float in [-57.2, -56.4, -55.6]:
		Props.cyl(g, Vector3(vx, 1.6, 71.0), 0.12, 0.25, "iron")
	GenDetail.pipe_run(g, PackedVector3Array([Vector3(-56.4, 1.7, 71.0), Vector3(-56.4, 3.6, 71.0), Vector3(-56.4, 3.6, 73.8), Vector3(-56.4, 4.6, 73.8)]), 0.11, "rust", 1.5)
	Props.cyl(dress, Vector3(-56.4, 6.4, 73.8), 0.28, 4.0, "rust")   # the exhaust stack through the roof
	# switchgear along the north wall (behind the set), cable trays up and over to the breaker panel on the west wall
	for sx: float in [-58.8, -57.6, -56.4, -55.2, -54.0, -52.8, -51.6, -50.4]:
		Props.block(g, Vector3(sx - 0.55, 0, 74.4), Vector3(sx + 0.55, 2.2, 74.85), "machine_grey")
		Props.gauge(g, Vector3(sx, 1.7, 74.39), 180.0, 0.1)
		NB(Vector3(sx - 0.3, 0.9, 74.38), Vector3(sx + 0.3, 1.3, 74.4), "black_paint", g)
	GenDetail.cable_tray(g, Vector3(-59.5, 3.5, 74.3), Vector3(-49.0, 3.5, 74.3), 0.35, "iron", 4)
	GenDetail.cable_tray(g, Vector3(-59.5, 3.5, 74.3), Vector3(-59.5, 3.5, 64.0), 0.35, "iron", 4)
	Props.block(g, Vector3(-59.85, 0.8, 64.4), Vector3(-59.7, 2.6, 67.6), "black_paint")
	for kx: float in [64.9, 65.5, 66.1, 66.7, 67.2]:
		NB(Vector3(-59.7, 1.9, kx - 0.04), Vector3(-59.55, 2.2, kx + 0.04), "brass", g)
		Props.gauge(g, Vector3(-59.69, 1.35, kx), -90.0, 0.07)
	for i: int in 4:
		Props.cable(g, Vector3(-59.75, 2.6, 64.6 + float(i) * 0.9), Vector3(-59.75, 3.5, 64.6 + float(i) * 0.9), 0.0, 0.025, 2, "rubber")
	GenDetail.poster(g, Vector3(-59.83, 1.8, 63.3), -90.0, "BETRIEBSANWEISUNG", "1. Erregung einschalten.\n2. Hauptschalter langsam einlegen.\n3. Hallen der Reihe nach zuschalten.", 0.42, 0.6)
	GenDetail.chalk_mark(g, Vector3(-47.83, 0.9, 66.6), -90.0, "jakub", 0.25)


# ------------------------------------------------------------------ B: Bahnhof

func _dress_bahnhof() -> void:
	var g: Node3D = Props.group(dress, "BahnhofDress", Vector3.ZERO)
	NB(Vector3(0.15, 0.0, 30.15), Vector3(39.85, 0.006, 59.85), "fl_yard", g)
	_frame_gameplay_windows(g, "B_BAHNHOF", "beam")
	_frame_gameplay_doors(g, ["B_BAHNHOF", "C_KANTINE", "D_KIRCHPLATZ"], "beam")
	# brick copings on the 4 m yard walls
	for c: Array in [[Vector3(-0.2, 4.0, 30.0), Vector3(0.2, 4.25, 60.0)], [Vector3(39.8, 4.0, 30.0), Vector3(40.2, 4.25, 60.0)], [Vector3(0.0, 4.0, 59.8), Vector3(40.0, 4.25, 60.2)]]:
		Props.block(g, c[0], c[1], "concrete")
	# the track under the flatcars (sunk so the rail heads are ankle-high) and the shed siding through its door
	GenDetail.rails(g, Vector3(0.3, -0.1, 49.5), Vector3(39.7, -0.1, 49.5))
	GenDetail.rails(g, Vector3(6.6, -0.1, 56.0), Vector3(28.0, -0.1, 56.0))
	for bx: float in [0.6, 39.4]:
		NB(Vector3(bx - 0.25, 0.0, 48.6), Vector3(bx + 0.25, 1.0, 50.4), "red_paint", g)   # buffer stops
	# the platform (Platform collider 4..36 × 44..47 × 0.2): a kerb, a white edge line, benches against nothing (none)
	NB(Vector3(4.0, 0.2, 46.6), Vector3(36.0, 0.215, 46.75), "enamel_white", g)
	NB(Vector3(4.0, 0.0, 46.95), Vector3(36.0, 0.21, 47.05), "stone", g)
	# the two flatcars (Flatcar1/2: 10 × 3 × 1.3 m) and their lead coffins
	for fx: float in [6.0, 20.0]:
		_flatcar(g, fx)
	for cz: float in [49.05, 49.95]:
		Props.coffin(g, Vector3(9.1, 1.3, cz), 90.0, "TH-0%d" % int(cz * 10.0 - 488.0), true)
		Props.coffin(g, Vector3(13.4, 1.3, cz), 90.0, "TH-1%d" % int(cz * 10.0 - 488.0), true)
	Props.coffin(g, Vector3(23.1, 1.3, 49.05), 90.0, "TH-21", true)
	Props.coffin(g, Vector3(27.2, 1.3, 49.5), 90.0, "TH-23", true)
	# the cracked one: lid shoved askew, the violet inside
	var cr: Node3D = Props.group(g, "CrackedCoffin", Vector3(23.1, 1.3, 49.95), 90.0)
	Props.block(cr, Vector3(-0.35, 0.1, -1.0), Vector3(0.35, 0.62, 1.0), "lead")
	GenDetail._ns(Props.block(cr, Vector3(-0.28, 0.5, -0.92), Vector3(0.28, 0.6, 0.92), "nachtglas"))
	Props.obox(cr, Vector3(0.25, 0.72, 0.2), Vector3(0.72, 0.05, 2.0), "lead", Vector3(0, 8, -14))
	for st: Vector3 in [Vector3(9.1, 1.75, 48.68), Vector3(13.4, 1.75, 48.68), Vector3(23.1, 1.75, 48.68), Vector3(27.2, 1.75, 49.13)]:
		Props.stencil(g, st, 0.0, "TOTENHAFEN", 56, Color(0.9, 0.88, 0.8, 0.8))
	lamp(Vector3(23.1, 2.3, 49.95), VIOLET, 0.9, 6.0, 0.15, 0.6)
	# the coal-hopper bridge over the platform: a truss from wall top to wall top (the Coal Hopper trap's skips hang
	# from it at the trap's own drop points), end towers on the walls, a chute
	var by: float = 8.2
	GenDetail.truss(g, Vector3(0.0, by, 45.5), Vector3(40.0, by, 45.5), 1.4, "rust", 2.5, 0.2, 0.1, true)
	GenDetail.truss(g, Vector3(0.0, by, 46.9), Vector3(40.0, by, 46.9), 1.4, "rust", 2.5, 0.2, 0.1, false)
	Props.block(g, Vector3(0.0, by + 1.35, 45.4), Vector3(40.0, by + 1.45, 47.0), "planks")
	for tx: float in [0.0, 40.0]:
		Props.block(g, Vector3(tx - 0.15, 4.25, 45.2), Vector3(tx + 0.15, by + 1.4, 47.2), "rust")
	GenDetail.railing(g, Vector3(0.2, by + 1.45, 45.45), Vector3(39.8, by + 1.45, 45.45), 1.0, "rust", false)
	Props.block(g, Vector3(38.5, by + 1.45, 45.3), Vector3(40.4, by + 3.6, 47.1), "fl_corrugated")
	# the goods shed (planks walls ShedW/ShedS, roof): corrugated cladding outside, a pitched roof, sliding doors
	GenDetail.corrugated_sheet(g, Vector3(27.78, 0.0, 52.0), Vector3(27.83, 4.0, 55.0))
	GenDetail.corrugated_sheet(g, Vector3(27.78, 0.0, 57.0), Vector3(27.83, 4.0, 60.0))
	GenDetail.corrugated_sheet(g, Vector3(28.0, 0.0, 51.78), Vector3(40.0, 4.0, 51.83))
	Props.gable_roof(g, Vector3(27.5, 4.3, 51.5), Vector3(40.4, 4.3, 60.4), 2.2, true, "fl_corrugated", false)
	for sd: Array in [[Vector3(30.0, 0.05, 51.66), Vector3(33.4, 3.5, 51.74)], [Vector3(33.6, 0.05, 51.66), Vector3(37.0, 3.5, 51.74)]]:
		Props.block(g, sd[0], sd[1], "wood_red")
	NB(Vector3(29.6, 3.6, 51.6), Vector3(37.6, 3.72, 51.75), "iron", g)
	Props.block(g, Vector3(27.72, 0.05, 57.1), Vector3(27.78, 2.6, 59.4), "wood_red")   # the side door, slid open along the wall
	NB(Vector3(27.68, 2.65, 54.6), Vector3(27.78, 2.75, 59.6), "iron", g)
	Props.stencil(g, Vector3(34.0, 3.85, 51.62), 0.0, "GÜTERSCHUPPEN", 110, Color(0.9, 0.86, 0.76, 0.8))
	# the station clock on a bracket off the shed wall, over the platform's east end
	var ck: Node3D = Props.group(g, "StationClock", Vector3(35.0, 3.1, 51.6))
	Props.strut(ck, Vector3(0, 0, 0), Vector3(0, 0, -0.9), 0.06, "iron")
	Props.cyl(ck, Vector3(0, 0, -1.05), 0.36, 0.14, "black_paint", Vector3(90, 0, 0))
	for sgn: float in [-1.0, 1.0]:
		Props.cyl(ck, Vector3(0, 0, -1.05 + sgn * 0.075), 0.31, 0.01, "enamel_white", Vector3(90, 0, 0))
		Props.obox(ck, Vector3(0.06, 0.08, -1.05 + sgn * 0.085), Vector3(0.02, 0.22, 0.005), "black_paint", Vector3(0, 0, -35))
		Props.obox(ck, Vector3(0.0, 0.11, -1.05 + sgn * 0.088), Vector3(0.016, 0.26, 0.005), "black_paint", Vector3(0, 0, 4))
	# the yardmaster's hut (Hut* walls, roof; the Lohnkasse counter and Ledger Lager inside are gameplay): cladding,
	# a pent roof, a stove pipe, a framed window and the door, the station sign, notices
	Props.gable_roof(g, Vector3(-0.4, 3.3, 49.6), Vector3(6.4, 3.3, 58.4), 1.4, false, "roof", false)
	Props.cyl(g, Vector3(1.2, 4.6, 57.4), 0.1, 2.4, "iron")
	Props.cone(g, Vector3(1.2, 5.9, 57.4), 0.18, 0.2, "iron")
	GenDetail.window(g, Vector3(6.15, 1.0, 51.8), -90.0, 1.1, 1.0, {"blind": true, "lit": WARM, "curtain": "linen", "mullions": [2, 2], "frost": true})
	GenDetail.door(g, Vector3(6.15, 0, 54.0), -90.0, 1.8, DOOR_H, {"leaf": "", "frame": "beam"})
	GenDetail.enamel_sign(g, Vector3(6.17, 2.75, 55.6), -90.0, "THALBACH WERKBAHNHOF", 1.6, 0.3, "enamel_white", Color(0.06, 0.08, 0.16))
	GenDetail.poster(g, Vector3(6.17, 1.55, 57.3), -90.0, "ÜBERSTELLUNG 2. MAI", "Arbeitskommando Thalbach:\nAbmarsch 4 Uhr, Richtung Westen.\nListe beim Fahrdienstleiter.", 0.42, 0.56)
	GenDetail.poster(g, Vector3(1.0, 1.6, 57.84), 0.0, "FRACHTBRIEF", "Absender: Totenhafen\nInhalt: Werkstoff, 14 Behälter\nNicht öffnen.", 0.36, 0.48)
	GenDetail.lamp_fixture(g, Vector3(1.4, 1.25, 57.84), "wall", 0.0, 0.0, "enamel_green")
	# Jette's desk (HutDesk): ledgers and a telephone
	Props.block(g, Vector3(0.6, 0.8, 55.7), Vector3(1.2, 0.86, 56.3), "leather")
	Props.block(g, Vector3(1.5, 0.8, 56.6), Vector3(1.9, 0.9, 56.9), "bakelite")
	# the water crane in the yard's south-west corner, the semaphore signal on the east wall top
	var wc: Node3D = Props.group(g, "WaterCrane", Vector3(1.0, 0, 31.0))
	Props.cyl(wc, Vector3(0, 1.6, 0), 0.16, 3.2, "loco_black")
	Props.cyl(wc, Vector3(0, 0.15, 0), 0.32, 0.3, "loco_black")
	Props.strut(wc, Vector3(0, 3.1, 0), Vector3(2.4, 3.1, 0.8), 0.18, "loco_black", true)
	Props.cable(wc, Vector3(2.4, 3.1, 0.8), Vector3(2.4, 2.0, 0.8), 0.0, 0.07, 3, "rubber")
	Props.ball(wc, Vector3(0, 3.25, 0), Vector3(0.36, 0.3, 0.36), "loco_black")
	var sg: Node3D = Props.group(g, "Signal", Vector3(40.0, 4.25, 33.0))
	Props.block(sg, Vector3(-0.12, 0, -0.12), Vector3(0.12, 5.5, 0.12), "iron")
	Props.obox(sg, Vector3(-0.8, 5.0, 0.0), Vector3(1.4, 0.22, 0.06), "red_paint", Vector3(0, 0, 40))
	Props.block(sg, Vector3(-0.2, 4.3, -0.15), Vector3(0.2, 4.7, 0.15), "black_paint")
	GenDetail._ns(Props.ball(sg, Vector3(-0.28, 4.5, 0.0), Vector3(0.12, 0.12, 0.12), "lamp_red_lit"))
	GenDetail._ns(Props.ball(sg, Vector3(-0.28, 4.5, -0.15), Vector3(0.12, 0.12, 0.12), "lamp_green"))
	Props.ladder(sg, Vector3(0.0, 0, 0.18), 0.0, 4.2)
	# weathering: soot from the locomotives on the walls, puddles between the sleepers, coal spill
	for i: int in 5:
		GenDetail.card(g, "soot", Vector3(39.84, 2.6, 36.0 + float(i) * 4.5), Vector3.LEFT, Vector2(2.4, 2.2))
	GenDetail.puddle(g, Vector3(14.0, 0.006, 52.6), 1.4, 0.8)
	GenDetail.puddle(g, Vector3(31.0, 0.006, 42.0), 2.0, 1.1, 30.0)
	for i2: int in 7:
		Props.ball(g, Vector3(17.0 + float(i2) * 1.3, 0.02, 45.0 + sin(float(i2)) * 0.5), Vector3(0.7, 0.08, 0.5), "coal")
	GenDetail.chalk_mark(g, Vector3(14.6, 0.95, 47.95), 0.0, "jakub", 0.26)
	Props.stencil(g, Vector3(20.0, 3.3, 59.82), 0.0, "KIRCHPLATZ  →", 70)


func _flatcar(g: Node3D, x0: float) -> void:
	var x1: float = x0 + 10.0
	Props.block(g, Vector3(x0 + 0.1, 1.1, 48.1), Vector3(x1 - 0.1, 1.3, 50.9), "planks")
	for sz: float in [48.05, 50.95]:
		Props.block(g, Vector3(x0 + 0.05, 0.75, sz - 0.08), Vector3(x1 - 0.05, 1.12, sz + 0.08), "loco_black")
		for k: int in 6:
			var px: float = x0 + 0.8 + float(k) * 1.68
			NB(Vector3(px - 0.05, 1.3, sz - 0.05), Vector3(px + 0.05, 1.65, sz + 0.05), "beam", g)
	for bx: float in [x0 + 2.0, x1 - 2.0]:
		Props.block(g, Vector3(bx - 1.0, 0.25, 48.4), Vector3(bx + 1.0, 0.75, 50.6), "loco_black")
		for wx: float in [-0.65, 0.65]:
			for wz: float in [48.62, 50.38]:
				Props.cyl(g, Vector3(bx + wx, 0.42, wz), 0.42, 0.12, "iron", Vector3(90, 0, 0))
	for ex: float in [x0 + 0.1, x1 - 0.1]:
		for bz: float in [48.6, 50.4]:
			Props.cyl(g, Vector3(ex, 0.9, bz), 0.12, 0.2, "iron", Vector3(0, 0, 90))
	Props.stencil(g, Vector3(x0 + 5.0, 0.95, 47.96), 0.0, "WERKBAHN THALBACH  ·  R %d" % int(x0), 44, Color(0.85, 0.82, 0.72, 0.8))


# ------------------------------------------------------------------ A: Siedlung

func _dress_siedlung() -> void:
	var g: Node3D = Props.group(dress, "SiedlungDress", Vector3.ZERO)
	NB(Vector3(0.15, 0.0, 0.15), Vector3(39.85, 0.006, 29.85), "fl_yard", g)
	# paving slab paths from the block doors to the works gate
	for p: Array in [[Vector3(19.0, 0.006, 0.2), Vector3(21.0, 0.012, 29.8)], [Vector3(27.0, 0.006, 0.2), Vector3(28.6, 0.012, 7.0)], [Vector3(33.0, 0.006, 21.0), Vector3(39.8, 0.012, 22.6)]]:
		NB(p[0], p[1], "stone", g)
	# block 1 (south, z = 0) and block 2 (east, x = 40): three storeys of rendered façade over the 6 m walls (the
	# upper storey is non-colliding), eaves cornices, roofs running away from the courtyard, chimneys
	box(dress, "BlockSouthUpper", Vector3(0.0, 6.0, -T * 0.5), Vector3(40.15, 9.6, T * 0.5), "fl_plaster", false)
	box(dress, "BlockEastUpper", Vector3(40.0 - T * 0.5, 6.0, 0.0), Vector3(40.0 + T * 0.5, 9.6, 30.0), "fl_plaster", false)
	GenDetail.trim(g, Vector3(0.0, 9.45, 0.15), Vector3(40.0, 9.45, 0.15), Vector3.BACK, 0.35, 0.3, "stucco_trim", true)
	GenDetail.trim(g, Vector3(39.85, 9.45, 0.0), Vector3(39.85, 9.45, 30.0), Vector3.LEFT, 0.35, 0.3, "stucco_trim", true)
	GenDetail.trim(g, Vector3(0.0, 3.05, 0.15), Vector3(40.0, 3.05, 0.15), Vector3.BACK, 0.18, 0.06, "stucco_trim")
	GenDetail.trim(g, Vector3(39.85, 3.05, 0.0), Vector3(39.85, 3.05, 30.0), Vector3.LEFT, 0.18, 0.06, "stucco_trim")
	GenDetail.trim(g, Vector3(0.0, 0.0, 0.15), Vector3(40.0, 0.0, 0.15), Vector3.BACK, 0.55, 0.05, "concrete")
	GenDetail.trim(g, Vector3(39.85, 0.0, 0.0), Vector3(39.85, 0.0, 30.0), Vector3.LEFT, 0.55, 0.05, "concrete")
	Props.gable_roof(g, Vector3(-0.5, 9.8, -9.0), Vector3(40.6, 9.8, 0.6), 4.2, true, "roof", false)
	Props.gable_roof(g, Vector3(39.4, 9.8, -0.5), Vector3(49.0, 9.8, 30.5), 4.2, false, "roof", false)
	for ch: Vector3 in [Vector3(8.0, 12.6, -2.5), Vector3(24.0, 12.6, -2.5), Vector3(43.0, 12.6, 9.0), Vector3(43.0, 12.6, 22.0)]:
		Props.block(g, ch - Vector3(0.4, 0, 0.3), ch + Vector3(0.4, 2.0, 0.3), "brick")
		Props.block(g, ch + Vector3(-0.48, 2.0, -0.38), ch + Vector3(0.48, 2.15, 0.38), "concrete")
	# the windows: three storeys, the ground floor's barricade windows framed as they are
	var lit: Array = []
	lit.append_array(_facade(g, Vector3.BACK, 0.15, [6.0, 13.0, 27.0], [0.95], 1.2, 1.4, 101, 0.0))
	lit.append_array(_facade(g, Vector3.BACK, 0.15, [6.0, 13.0, 20.0, 27.0, 34.0], [3.75, 6.75], 1.2, 1.5, 102, 0.12))
	lit.append_array(_facade(g, Vector3.LEFT, 39.85, [4.0, 10.0, 22.0, 27.0], [0.95], 1.2, 1.4, 103, 0.0))
	lit.append_array(_facade(g, Vector3.LEFT, 39.85, [4.0, 10.0, 16.0, 22.0, 27.0], [3.75, 6.75], 1.2, 1.5, 104, 0.14))
	_frame_gameplay_windows(g, "A_SIEDLUNG", "beam")
	# stair doors with their house numbers, balconies on the upper floors
	for d: Array in [[Vector3(24.0, 0, 0.15), 180.0, "Nr. 3"], [Vector3(9.5, 0, 0.15), 180.0, "Nr. 1"], [Vector3(39.85, 0, 13.0), 90.0, "Nr. 5"]]:
		GenDetail.door(g, d[0], float(d[1]), 1.2, 2.3, {"blind": true, "leaf": "planks", "frame": "stucco_trim"})
		GenDetail.enamel_sign(g, (d[0] as Vector3) + Vector3(0, 2.75, 0) + Basis(Vector3.UP, deg_to_rad(float(d[1]))) * Vector3(0, 0, -0.06), float(d[1]), str(d[2]), 0.36, 0.2, "enamel_white", Color(0.08, 0.1, 0.2))
	for b: Array in [[Vector3(16.5, 3.55, 0.15), Vector3.BACK], [Vector3(30.5, 6.55, 0.15), Vector3.BACK], [Vector3(39.85, 3.55, 13.0), Vector3.LEFT], [Vector3(39.85, 6.55, 19.0), Vector3.LEFT]]:
		_balcony(g, b[0], b[1])
	for c: Vector3 in lit:
		lamp(c, WARM, 0.45, 5.0, 0.04, 0.2)
	# the west wing (A_W): a lower wash-house with a pent roof; the works wall (AB) with its gate and the notices
	Props.block(g, Vector3(-0.15, 6.0, 0.0), Vector3(0.15, 6.3, 30.0), "concrete")
	Props.obox(g, Vector3(-3.0, 7.1, 15.0), Vector3(6.6, 0.18, 30.6), "roof", Vector3(0, 0, -16))
	_facade(g, Vector3.RIGHT, 0.15, [5.0, 10.0, 22.0, 26.5], [3.6], 1.0, 1.1, 105, 0.0)
	GenDetail.enamel_sign(g, Vector3(0.17, 2.7, 9.0), -90.0, "WASCHKÜCHE", 1.0, 0.24)
	for c2: Array in [[Vector3(-0.1, 6.0, 30.0 - 0.25), Vector3(40.1, 6.3, 30.0 + 0.25)]]:
		Props.block(g, c2[0], c2[1], "concrete")
	for px: float in [2.0, 6.0, 10.0, 14.0, 26.0, 30.0, 34.0, 38.0]:
		Props.block(g, Vector3(px - 0.25, 0, 29.8), Vector3(px + 0.25, 6.3, 29.85 - 0.0 + 0.01), "fl_brick")
	_frame_gameplay_doors(g, ["B_BAHNHOF"], "concrete")
	GenDetail.poster(g, Vector3(15.2, 1.7, 29.83), 0.0, "VOLKSSTURM", "Appell aller Männer von 16 bis 60 Jahren.\nSonntag, 6 Uhr, Werkhof Thalbach.\nMitzubringen: Decke, Essgeschirr, Spaten.", 0.5, 0.72)
	GenDetail.poster(g, Vector3(16.0, 2.55, 29.83), 0.0, "VERDUNKELN!", "ab 20 Uhr", 0.36, 0.3, "paper", Color(0.6, 0.1, 0.06), -3.0)
	GenDetail.poster(g, Vector3(24.6, 1.6, 29.83), 0.0, "LOHNAUSZAHLUNG", "Freitag, 14 Uhr\nLohnkasse am Werkbahnhof", 0.36, 0.46, "paper", Color(0.1, 0.1, 0.12), 2.0)
	# the air-raid cellar (Cellar* walls): sandbags along its north face and on its roof, the LSR arrows, a gas mask
	Props.sandbags(g, Vector3(2.3, 0, 10.32), Vector3(5.8, 0, 10.32), 3)
	Props.sandbags(g, Vector3(8.2, 0, 10.32), Vector3(11.7, 0, 10.32), 3)
	for e: Array in [[Vector3(1.9, 3.3, 1.9), Vector3(12.1, 3.3, 1.9)], [Vector3(1.9, 3.3, 10.1), Vector3(12.1, 3.3, 10.1)], [Vector3(1.9, 3.3, 1.9), Vector3(1.9, 3.3, 10.1)], [Vector3(12.1, 3.3, 1.9), Vector3(12.1, 3.3, 10.1)]]:
		Props.sandbags(g, e[0], e[1], 2)
	GenDetail.door(g, Vector3(7.0, 0, 10.15), 180.0, 1.8, DOOR_H, {"leaf": "", "frame": "concrete", "step": false})
	GenDetail.enamel_sign(g, Vector3(7.0, 2.75, 10.2), 180.0, "LUFTSCHUTZRAUM  ·  40 PERSONEN", 1.6, 0.26, "enamel_white", Color(0.1, 0.1, 0.1))
	for lsr: Array in [[Vector3(0.17, 1.9, 6.0), -90.0], [Vector3(20.0, 1.9, 0.17), 180.0], [Vector3(12.17, 1.9, 6.0), -90.0]]:
		Props.stencil(g, lsr[0], float(lsr[1]), "LSR  ←", 90, Color(0.92, 0.92, 0.88, 0.85))
	_lib(g, "stove_barrel", Vector3(2.65, 0, 9.35), 30.0)
	Props.cyl(g, Vector3(2.65, 2.0, 9.35), 0.07, 2.2, "iron")
	_lib(g, "gas_mask_hanging", Vector3(11.8, 1.9, 4.0), -90.0)
	_lib(g, "gas_mask_hanging", Vector3(11.8, 1.9, 4.6), -90.0)
	Props.shelves(g, Vector3(2.3, 0, 5.5), -90.0, 2.4, 1.8, 0.3, 3, 31)
	Props.lantern(g, Vector3(7.0, 2.2, 6.0), 3.0)
	GenDetail.poster(g, Vector3(2.17, 1.7, 3.2), -90.0, "VERHALTEN IM LUFTSCHUTZRAUM", "Ruhe bewahren.\nLicht löschen.\nDen Anweisungen des Luftschutzwarts folgen.", 0.42, 0.6)
	# the crater (Crater collider 22..28 × 20..26, 0.6 m): a rim of earth and paving, scorched bowl
	GenDetail.crater(g, Vector3(25.0, 0, 23.0), 2.25, 41, "dirt", "stone")
	# the washing lines between the posts (NavBlock_Post), stiff sheets
	for pp: Vector3 in [Vector3(14, 0, 24), Vector3(14, 0, 8), Vector3(32, 0, 8)]:
		Props.block(g, pp - Vector3(0.11, 0, 0.11), pp + Vector3(0.11, 2.4, 0.11), "beam")
		Props.block(g, pp + Vector3(-0.25, 2.25, -0.04), pp + Vector3(0.25, 2.33, 0.04), "beam")
	GenDetail.washing_line(g, Vector3(14, 2.3, 23.9), Vector3(14, 2.3, 8.1), 5, 11)
	GenDetail.washing_line(g, Vector3(14.1, 2.3, 8), Vector3(31.9, 2.3, 8), 6, 12)
	# the courtyard pump by the ammo box (the key lantern hangs over it), a cart wheel, a pram's silhouette is not
	var pump: Node3D = Props.group(g, "Pump", Vector3(8.6, 0, 29.62), 0.0)
	Props.block(pump, Vector3(-0.15, 0, -0.15), Vector3(0.15, 1.3, 0.15), "loco_black")
	Props.strut(pump, Vector3(0, 1.25, 0), Vector3(0, 1.45, -0.55), 0.05, "loco_black")
	Props.strut(pump, Vector3(0, 0.9, 0), Vector3(0, 0.75, -0.3), 0.06, "loco_black", true)
	Props.block(pump, Vector3(-0.3, 0, -0.55), Vector3(0.3, 0.12, -0.15), "stone")
	GenDetail.lamp_fixture(g, Vector3(8.6, 3.0, 29.83), "wall", 0.0, 0.0, "black_paint", "lantern_glass")
	# the child's chalk game on the courtyard, a chalk stick figure on the block's base
	GenDetail.chalk_mark(g, Vector3(32.5, 0.012, 16.0), 90.0, "hopscotch", 0.55, true)
	GenDetail.card(g, "chalk", Vector3(30.4, 0.014, 16.0), Vector3.UP, Vector2(4.6, 1.6))
	GenDetail.chalk_mark(g, Vector3(39.83, 0.3, 18.5), 90.0, "x", 0.3)
	# frost on the ground in the shade of the blocks, rust from the gutters, puddles
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4401
	for i: int in 9:
		GenDetail.frost_patch(g, Vector3(rng.randf_range(2.0, 38.0), 0.012, rng.randf_range(1.0, 6.0) if i % 2 == 0 else rng.randf_range(2.0, 28.0)), Vector3.UP, rng.randf_range(1.5, 3.5))
	for gx: float in [0.5, 19.8, 39.5]:
		Props.cyl(g, Vector3(gx, 4.8, 0.3), 0.06, 9.6, "zinc")
		GenDetail.rust_streak(g, Vector3(gx + 0.25, 9.2, 0.16), Vector3.BACK, 0.5, 4.0)
	GenDetail.puddle(g, Vector3(18.0, 0.006, 12.0), 1.8, 1.0, 15.0)
	GenDetail.puddle(g, Vector3(35.0, 0.006, 4.0), 1.2, 0.7)


func _balcony(g: Node3D, at: Vector3, out: Vector3) -> void:
	var o: Vector3 = out.normalized()
	var side: Vector3 = Vector3(o.z, 0, -o.x)
	var lo: Vector3 = at - side * 1.1
	var hi: Vector3 = at + side * 1.1 + o * 0.9
	Props.block(g, Vector3(minf(lo.x, hi.x), at.y - 0.18, minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), at.y, maxf(lo.z, hi.z)), "concrete")
	var front: Vector3 = at + o * 0.85
	Props.railing(g, front - side * 1.05, front + side * 1.05, 0.95, "iron", 0.5)
	Props.railing(g, at - side * 1.05, front - side * 1.05, 0.95, "iron", 0.5)
	Props.railing(g, at + side * 1.05, front + side * 1.05, 0.95, "iron", 0.5)
	GenDetail.door(g, at, _out_yaw(o), 0.9, 2.1, {"blind": true, "leaf": "planks", "step": false, "frame": "beam"})


# ------------------------------------------------------------------ C: Kantine

func _dress_kantine() -> void:
	var g: Node3D = Props.group(dress, "KantineDress", Vector3.ZERO)
	NB(Vector3(-43.85, 0.0, 30.15), Vector3(-0.15, 0.008, 59.85), "fl_planks", g)
	# a painted dado and plaster above on the inner faces, a picture rail; trusses under the flat roof
	for wl: Array in [[Vector3(-43.85, 0, 30.15), Vector3(-0.15, 0, 30.15), Vector3.BACK], [Vector3(-43.85, 0, 59.85), Vector3(-0.15, 0, 59.85), Vector3.FORWARD],
			[Vector3(-43.85, 0, 30.15), Vector3(-43.85, 0, 59.85), Vector3.RIGHT], [Vector3(-0.15, 0, 30.15), Vector3(-0.15, 0, 59.85), Vector3.LEFT]]:
		GenDetail.trim(g, wl[0], wl[1], wl[2], 1.35, 0.02, "paint_green")
		GenDetail.trim(g, (wl[0] as Vector3) + Vector3(0, 1.35, 0), (wl[1] as Vector3) + Vector3(0, 1.35, 0), wl[2], 0.06, 0.04, "beam")
		GenDetail.trim(g, (wl[0] as Vector3) + Vector3(0, 1.41, 0), (wl[1] as Vector3) + Vector3(0, 1.41, 0), wl[2], 4.59, 0.015, "paint_cream")
		GenDetail.trim(g, (wl[0] as Vector3) + Vector3(0, 4.3, 0), (wl[1] as Vector3) + Vector3(0, 4.3, 0), wl[2], 0.05, 0.04, "beam")
	for tz: float in [33.0, 39.0, 45.0, 51.0, 57.0]:
		GenDetail.i_beam(g, Vector3(-43.85, 5.6, tz), Vector3(-0.15, 5.6, tz), 0.6, 0.25, "beam", Vector3.UP, false)
	_frame_gameplay_windows(g, "C_KANTINE", "beam")
	_facade(g, Vector3.BACK, 30.15, [-38.0, -32.0, -12.0, -6.0], [2.6], 1.4, 2.2, 301, 0.0, ["cloth_green"])
	# the long tables (Table38/44/50 colliders, 28 × 1.4 × 0.8 m): trestles, scrubbed tops, benches tucked under the
	# overhang within the colliders, the meal still on them
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3030
	for tz2: float in [38.0, 44.0, 50.0]:
		Props.block(g, Vector3(-38.0, 0.74, tz2 + 0.3), Vector3(-10.0, 0.8, tz2 + 1.1), "furniture")
		for lx: float in [-37.4, -31.0, -24.0, -17.0, -10.6]:
			Props.block(g, Vector3(lx - 0.05, 0, tz2 + 0.4), Vector3(lx + 0.05, 0.74, tz2 + 1.0), "beam")
		for bz: Array in [[tz2 + 0.0, tz2 + 0.28], [tz2 + 1.12, tz2 + 1.4]]:
			Props.block(g, Vector3(-37.8, 0.42, float(bz[0])), Vector3(-10.2, 0.46, float(bz[1])), "furniture")
			for lx2: float in [-37.3, -24.0, -10.7]:
				NB(Vector3(lx2 - 0.04, 0, float(bz[0]) + 0.08), Vector3(lx2 + 0.04, 0.42, float(bz[1]) - 0.08), "beam", g)
		var px: float = -37.0
		while px < -11.0:
			if rng.randf() < 0.7:
				var side: float = 0.45 if rng.randf() < 0.5 else 0.95
				PropsStory.soup_bowl(g, Vector3(px, 0.8, tz2 + side), rng.randf() * 360.0, rng.randf())
				if rng.randf() < 0.5:
					PropsStory.mug(g, Vector3(px + 0.25, 0.8, tz2 + side))
			px += rng.randf_range(0.7, 1.4)
	# the serving hatch (NavBlock_Hatch shelf in the west window): a counter, a roller shutter half up, a menu board
	Props.block(g, Vector3(-43.75, 0.88, 46.3), Vector3(-42.5, 0.92, 49.7), "zinc")
	Props.block(g, Vector3(-43.7, 2.25, 46.9), Vector3(-43.55, 2.6, 49.1), "iron")
	GenDetail.enamel_sign(g, Vector3(-43.82, 2.95, 48.0), -90.0, "ESSENSAUSGABE", 1.4, 0.26)
	GenDetail.poster(g, Vector3(-43.82, 1.7, 45.2), -90.0, "SPEISEPLAN", "Montag: Steckrübeneintopf\nDienstag: Steckrübeneintopf\nMittwoch: Graupen", 0.42, 0.58, "board_wood", Color(0.92, 0.92, 0.9))
	# the stage (NavBlock_Stage 10 × 6 × 0.25): boards, a proscenium, curtains, the radio set, the concert banner, the PA
	Props.block(g, Vector3(-43.85, 0.2, 54.0), Vector3(-34.0, 0.26, 59.85), "fl_planks")
	NB(Vector3(-34.06, 0.0, 54.0), Vector3(-34.0, 0.25, 59.85), "beam", g)
	for cx: float in [-43.5, -34.4]:
		Props.block(g, Vector3(cx - 0.25, 0.25, 59.2), Vector3(cx + 0.25, 4.6, 59.85), "cloth_green")
	Props.block(g, Vector3(-43.8, 4.0, 59.5), Vector3(-34.2, 4.6, 59.85), "cloth_green")
	Props.block(g, Vector3(-42.8, 0.25, 59.3), Vector3(-41.6, 0.95, 59.8), "furniture")
	var radio: Node3D = Props.group(g, "Radio", Vector3(-42.2, 0.95, 59.55))
	Props.block(radio, Vector3(-0.32, 0, -0.18), Vector3(0.32, 0.46, 0.18), "walnut")
	Props.block(radio, Vector3(-0.26, 0.2, -0.19), Vector3(0.26, 0.4, -0.18), "cloth_cream")
	Props.cyl(radio, Vector3(-0.17, 0.09, -0.2), 0.035, 0.03, "bakelite", Vector3(90, 0, 0))
	Props.cyl(radio, Vector3(0.17, 0.09, -0.2), 0.035, 0.03, "bakelite", Vector3(90, 0, 0))
	GenDetail._ns(Props.block(radio, Vector3(-0.1, 0.06, -0.19), Vector3(0.08, 0.12, -0.185), "gauge_lit"))
	Props.block(g, Vector3(-43.6, 4.7, 59.78), Vector3(-34.4, 5.5, 59.84), "linen")
	Props.stencil(g, Vector3(-39.0, 5.25, 59.77), 0.0, "WERKSKONZERT", 150, Color(0.14, 0.24, 0.16, 0.95))
	Props.stencil(g, Vector3(-39.0, 4.88, 59.77), 0.0, "SONNTAG 29. APRIL  ·  ES SPIELT DIE WERKSKAPELLE THALBACH", 60, Color(0.14, 0.24, 0.16, 0.95))
	var pa: Node3D = Props.group(g, "PASpeaker", Vector3(-33.6, 4.3, 59.75), 200.0)
	Props.strut(pa, Vector3(0, 0, 0), Vector3(0, 0, -0.4), 0.05, "iron")
	Props.cone(pa, Vector3(0, 0, -0.62), 0.32, 0.45, "machine_grey", Vector3(-90, 0, 0))
	Props.cyl(pa, Vector3(0, 0, -0.38), 0.12, 0.16, "black_paint", Vector3(90, 0, 0))
	Props.cable(g, Vector3(-33.6, 4.3, 59.7), Vector3(-33.6, 5.6, 59.7), 0.0, 0.015, 2, "rubber")
	# enamel signs, a coat rack of works coats by the Bahnhof door, a clock
	GenDetail.enamel_sign(g, Vector3(-0.17, 2.6, 49.0), 90.0, "GESCHIRR ZURÜCKBRINGEN", 1.5, 0.26, "enamel_white", Color(0.08, 0.12, 0.2))
	GenDetail.enamel_sign(g, Vector3(-22.0, 3.0, 59.83), 0.0, "HÄNDE WASCHEN", 1.1, 0.26, "enamel_white", Color(0.08, 0.12, 0.2))
	GenDetail.enamel_sign(g, Vector3(-22.0, 3.0, 30.17), 180.0, "KANTINE  ·  WERK THALBACH", 2.0, 0.3, "enamel_white", Color(0.08, 0.12, 0.2))
	Props.block(g, Vector3(-0.3, 1.65, 50.6), Vector3(-0.17, 1.75, 53.4), "beam")
	for hz: float in [50.9, 51.5, 52.1, 52.7, 53.2]:
		NB(Vector3(-0.32, 1.55, hz - 0.02), Vector3(-0.17, 1.7, hz + 0.02), "iron", g)
		if hz < 53.0:
			PropsStory.coat_drape(g, Vector3(-0.28, 1.68, hz), -90.0, "cloth_navy" if hz < 51.6 else "feldgrau")
	Props.cyl(g, Vector3(-22.0, 4.0, 59.82), 0.3, 0.05, "enamel_white", Vector3(90, 0, 0))
	GenDetail.chalk_mark(g, Vector3(-43.83, 0.7, 41.0), -90.0, "tally", 0.3)


# ------------------------------------------------------------------ D: Kirchplatz

func _dress_kirchplatz() -> void:
	var g: Node3D = Props.group(dress, "KirchplatzDress", Vector3.ZERO)
	NB(Vector3(0.15, 0.0, 60.15), Vector3(39.85, 0.006, 99.85), "stone", g)
	NB(Vector3(4.0, 0.006, 64.0), Vector3(36.0, 0.01, 82.0), "fl_yard", g)
	_frame_gameplay_windows(g, "D_KIRCHPLATZ", "stucco_trim")
	_frame_gameplay_doors(g, ["D_KIRCHPLATZ", "F_WINDKANAL"], "stone")
	# the bombed church: the tower (its collider is the 12 × 14 × 14 m Tower box) rising to a broken belfry, the
	# nave's stub behind, buttresses filling the collider's corners, rubble on Rubble1
	var t: Node3D = Props.group(g, "ChurchTower", Vector3(20.0, 0, 93.0))
	Props.block(t, Vector3(-6.0, 0, -7.0), Vector3(6.0, 6.0, 7.0), "stone")
	Props.block(t, Vector3(-4.6, 6.0, -7.0), Vector3(4.6, 15.5, 2.2), "stone")
	Props.block(t, Vector3(-6.0, 6.0, 2.2), Vector3(6.0, 9.5, 7.0), "stone")
	Props.prism(t, Vector3(-3.0, 10.6, 4.6), Vector3(6.0, 2.2, 4.8), "stone")   # the nave's broken gable
	for bx: float in [-5.4, 5.4]:
		Props.prism(t, Vector3(bx, 7.4, -6.2), Vector3(1.2, 2.8, 1.6), "stone", Vector3(0, 90 if bx > 0.0 else -90, 0))
	for q: Vector3 in [Vector3(-4.6, 0, -7.0), Vector3(4.6, 0, -7.0)]:
		for k: int in 18:
			var y: float = 6.0 + float(k) * 0.52
			var wx: float = 0.55 if k % 2 == 0 else 0.35
			NB(Vector3(q.x - wx * signf(q.x) * 0.0 - 0.02 * signf(q.x), y, q.z - 0.04), Vector3(q.x - signf(q.x) * wx, y + 0.42, q.z + (0.55 if k % 2 == 1 else 0.35)), "concrete", t)
	# the west door (pointed arch, boarded), the clock (stopped), the belfry openings, the broken crown
	Props.block(t, Vector3(-1.3, 0, -7.06), Vector3(1.3, 3.4, -7.0), "black_paint")
	Props.prism(t, Vector3(0, 3.95, -7.04), Vector3(2.6, 1.1, 0.06), "black_paint")
	for pb: float in [0.6, 1.3, 2.0, 2.7]:
		Props.obox(t, Vector3(0, pb, -7.1), Vector3(2.4, 0.18, 0.05), "planks", Vector3(0, 0, 4.0 if pb < 1.5 else -3.0))
	Props.cyl(t, Vector3(0, 11.6, -7.06), 1.0, 0.1, "enamel_white", Vector3(90, 0, 0))
	Props.cyl(t, Vector3(0, 11.6, -7.02), 1.12, 0.06, "black_paint", Vector3(90, 0, 0))
	Props.obox(t, Vector3(0.18, 11.75, -7.13), Vector3(0.06, 0.55, 0.02), "black_paint", Vector3(0, 0, -30))
	Props.obox(t, Vector3(-0.1, 11.45, -7.13), Vector3(0.05, 0.75, 0.02), "black_paint", Vector3(0, 0, 160))
	for face: Array in [[Vector3(0, 0, -7.02), 0.0], [Vector3(-4.62, 0, -2.4), 90.0], [Vector3(4.62, 0, -2.4), -90.0]]:
		for ox: float in [-1.2, 1.2]:
			var c: Vector3 = (face[0] as Vector3) + Basis(Vector3.UP, deg_to_rad(float(face[1]))) * Vector3(ox, 0, 0)
			var op: Node3D = Props.group(t, "Belfry", c + Vector3(0, 13.2, 0), float(face[1]))
			Props.block(op, Vector3(-0.55, 0, -0.06), Vector3(0.55, 2.2, 0.0), "black_paint")
			Props.prism(op, Vector3(0, 2.45, -0.03), Vector3(1.1, 0.5, 0.06), "black_paint")
			for lv: float in [0.35, 0.8, 1.25, 1.7]:
				Props.obox(op, Vector3(0, lv, -0.1), Vector3(1.0, 0.06, 0.14), "planks", Vector3(30, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6066
	for i: int in 22:
		var a: float = float(i) / 22.0 * TAU
		var rp: Vector3 = Vector3(cos(a) * 4.0, 15.5 + rng.randf_range(0.0, 3.5) * (1.0 - absf(sin(a * 1.5))), sin(a) * 4.0 - 2.4)
		Props.block(t, rp - Vector3(0.6, 0, 0.5), rp + Vector3(0.6, rng.randf_range(0.5, 1.6), 0.5), "stone")
	for b: int in 4:
		Props.obox(t, Vector3(rng.randf_range(-3.0, 3.0), 16.6, rng.randf_range(-5.0, 0.0)), Vector3(0.22, 0.22, 5.5), "char", Vector3(rng.randf_range(-35, 35), rng.randf() * 180.0, rng.randf_range(-20, 20)))
	for bp: float in [-1.1, 1.1]:
		Props.block(t, Vector3(bp - 0.12, 15.5, -2.52), Vector3(bp + 0.12, 17.6, -2.28), "beam")
	Props.obox(t, Vector3(0, 17.5, -2.4), Vector3(2.6, 0.22, 0.26), "beam", Vector3(0, 0, 7))
	Props.bell(t, Vector3(0.2, 16.1, -2.4), 1.1, "brass")
	GenDetail.card(t, "soot", Vector3(0, 14.0, -7.04), Vector3.FORWARD, Vector2(6.0, 7.0))
	for rr: int in 26:
		var rp2: Vector3 = Vector3(rng.randf_range(-7.6, 7.6), 0.0, rng.randf_range(-8.9, -7.15))
		Props.obox(t, rp2 + Vector3(0, rng.randf_range(0.15, 0.5), 0), Vector3(rng.randf_range(0.4, 1.1), rng.randf_range(0.3, 0.6), rng.randf_range(0.3, 0.8)), "stone",
			Vector3(rng.randf_range(-25, 25), rng.randf() * 180.0, rng.randf_range(-25, 25)))
	# the well (Well collider 2.4 × 2.4 × 1.1): a round stone curb, a windlass roof on two posts, a bucket, the lantern
	var w: Node3D = Props.group(g, "Well", Vector3(8.0, 0, 80.0))
	Props.cyl(w, Vector3(0, 0.55, 0), 1.15, 1.1, "stone")
	GenDetail._ns(Props.cyl(w, Vector3(0, 1.08, 0), 0.92, 0.06, "black_paint"))
	for px: float in [-1.0, 1.0]:
		Props.block(w, Vector3(px - 0.08, 1.1, -0.08), Vector3(px + 0.08, 2.6, 0.08), "beam")
	Props.cyl(w, Vector3(0, 2.05, 0), 0.1, 2.0, "beam", Vector3(0, 0, 90))
	Props.gable_roof(w, Vector3(-1.2, 2.6, -0.7), Vector3(1.2, 2.6, 0.7), 0.6, true, "roof", false)
	Props.cable(w, Vector3(0.2, 2.0, 0), Vector3(0.2, 1.3, 0), 0.0, 0.012, 2, "rope")
	Props.lantern(w, Vector3(0.0, 2.25, 0.62), 2.6)
	# the fountain (Fountain collider 4 × 4 × 0.9): a round basin with ice, a column with frozen spouts and icicles
	var f: Node3D = Props.group(g, "Fountain", Vector3(30.0, 0, 72.0))
	Props.cyl(f, Vector3(0, 0.42, 0), 1.95, 0.84, "stone")
	Props.cyl(f, Vector3(0, 0.83, 0), 1.75, 0.04, "ice")
	Props.cyl(f, Vector3(0, 1.6, 0), 0.32, 1.6, "stone")
	Props.cyl(f, Vector3(0, 2.45, 0), 0.6, 0.18, "stone")
	Props.ball(f, Vector3(0, 2.75, 0), Vector3(0.5, 0.5, 0.5), "stone")
	for ia: int in 4:
		var d2: Vector3 = Vector3(cos(float(ia) * PI * 0.5), 0, sin(float(ia) * PI * 0.5))
		Props.strut(f, d2 * 0.3 + Vector3(0, 2.2, 0), d2 * 0.6 + Vector3(0, 2.15, 0), 0.06, "iron", true)
		Props.cone(f, d2 * 0.62 + Vector3(0, 1.75, 0), 0.07, 0.8, "ice", Vector3(180, 0, 0))
		Props.cone(f, d2 * 0.6 + Vector3(0, 2.3, 0) + Vector3(0, -0.05, 0), 0.05, 0.3, "ice", Vector3(180, 0, 0))
	# the parish house (Parish* walls, roof; the crate's spot inside): render and timber, a steep roof, shutters
	Props.gable_roof(g, Vector3(29.6, 4.3, 87.6), Vector3(40.4, 4.3, 100.4), 4.0, false, "roof", false)
	_facade(g, Vector3.FORWARD, 87.85, [32.0, 38.0], [1.0], 1.0, 1.3, 401, 0.5, ["linen"])
	_facade(g, Vector3.LEFT, 29.85, [91.0, 96.5], [1.0], 1.0, 1.3, 402, 0.5, ["linen"])
	GenDetail.door(g, Vector3(35.0, 0, 87.85), 0.0, 2.0, DOOR_H, {"leaf": "", "frame": "beam"})
	GenDetail.lamp_fixture(g, Vector3(36.5, 2.7, 87.85), "wall", 0.0, 0.0, "black_paint", "lantern_glass")
	GenDetail.poster(g, Vector3(33.6, 1.6, 87.83), 0.0, "PFARRAMT THALBACH", "Gottesdienst Sonntag 9 Uhr.\nTaufen und Trauungen nach Absprache.\nDie Glocke bleibt bis auf Weiteres still.", 0.5, 0.66)
	# the east houses (D_E, 5 m): upper storeys and gables over the wall; the hall's brick east face (DE_W)
	box(dress, "TownEastUpper", Vector3(40.0 - T * 0.5, 5.0, 60.0), Vector3(40.0 + T * 0.5, 8.6, 88.0), "fl_plaster", false)
	Props.gable_roof(g, Vector3(39.5, 8.6, 60.0), Vector3(48.0, 8.6, 74.0), 3.6, false, "roof", false)
	Props.gable_roof(g, Vector3(39.5, 8.6, 74.0), Vector3(48.0, 8.6, 88.0), 4.2, false, "roof", false)
	_facade(g, Vector3.LEFT, 39.85, [63.0, 66.5, 75.0, 79.0, 83.0], [5.6], 1.1, 1.4, 403, 0.2)
	_facade(g, Vector3.LEFT, 39.85, [64.0, 76.0, 80.5, 85.0], [2.0], 1.1, 1.4, 404, 0.0)
	GenDetail.trim(g, Vector3(39.85, 8.4, 60.0), Vector3(39.85, 8.4, 88.0), Vector3.LEFT, 0.3, 0.25, "stucco_trim", true)
	for wz: float in [64.0, 72.0, 80.0, 88.0, 96.0]:
		GenDetail.window(g, Vector3(0.15, 3.4, wz), -90.0, 2.4, 4.6, {"blind": true, "mullions": [3, 5], "frame": "steel", "sill_key": "concrete", "broken": 0.35, "seed": int(wz)})
	# frost and snow-melt, a blown-off roof sheet, the Fliegeralarm circles' scorch marks from earlier raids
	for i2: int in 7:
		GenDetail.frost_patch(g, Vector3(rng.randf_range(2.0, 38.0), 0.012, rng.randf_range(62.0, 98.0)), Vector3.UP, rng.randf_range(1.5, 3.0))
	for sc: Vector3 in [Vector3(12.0, 0.013, 70.0), Vector3(26.0, 0.013, 82.0), Vector3(34.0, 0.013, 64.0)]:
		GenDetail.card(g, "soot", sc, Vector3.UP, Vector2(4.5, 4.5))
	Props.obox(g, Vector3(18.0, 0.04, 75.0), Vector3(2.2, 0.03, 0.9), "fl_corrugated", Vector3(4, 33, 2))
	GenDetail.enamel_sign(g, Vector3(20.0, 3.0, 60.17), 180.0, "KIRCHPLATZ", 1.3, 0.28)


# ------------------------------------------------------------------ F: Windkanal

func _dress_windkanal() -> void:
	var g: Node3D = Props.group(dress, "WindkanalDress", Vector3.ZERO)
	NB(Vector3(0.15, 0.0, 100.15), Vector3(43.85, 0.006, 129.85), "fl_floor", g)
	_frame_gameplay_windows(g, "F_WINDKANAL", "steel")
	_frame_gameplay_doors(g, ["F_WINDKANAL"], "steel")
	for tx: float in [6.0, 14.0, 22.0, 30.0, 38.0]:
		GenDetail.truss(g, Vector3(tx, 6.4, 100.2), Vector3(tx, 6.4, 129.8), 1.5, "steel", 2.5, 0.18, 0.09, false)
	for wz: float in [104.0, 116.0, 126.0]:
		GenDetail.window(g, Vector3(43.85, 3.4, wz), 90.0, 2.0, 3.4, {"blind": true, "mullions": [3, 4], "frame": "steel", "broken": 0.3, "seed": int(wz)})
	# the horn: a brick barrel vault over the tunnel lane (TunnelS/N walls, 2.4 m) springing at 2.4 m, its bell mouth
	# flaring out to the fan's ring; the fan (Fan collider 2.9 × 9 × 7 m) is a house-sized propeller in its ring
	for k: int in 9:
		var a0: float = PI * float(k) / 9.0
		var a1: float = PI * float(k + 1) / 9.0
		var p0: Vector3 = Vector3(0, 2.4 + sin(a0) * 2.0, 115.0 + cos(a0) * 3.15)
		var p1: Vector3 = Vector3(0, 2.4 + sin(a1) * 2.0, 115.0 + cos(a1) * 3.15)
		var mid: Vector3 = (p0 + p1) * 0.5
		var seg: float = p0.distance_to(p1)
		var ang: float = rad_to_deg(atan2(p1.y - p0.y, p1.z - p0.z))
		Props.obox(g, Vector3(17.0, mid.y, mid.z), Vector3(22.0, 0.32, seg + 0.05), "fl_brick", Vector3(-ang, 0, 0))   # vault over x 6..28
		Props.obox(g, Vector3(4.6, mid.y + (mid.y - 2.4) * 0.5, 115.0 + (mid.z - 115.0) * 1.15), Vector3(3.2, 0.32, seg * 1.2), "fl_brick", Vector3(-ang, 0, 0))
	for rib: float in [8.0, 13.0, 18.0, 23.0, 27.6]:
		for k2: int in 9:
			var b0: float = PI * float(k2) / 9.0
			var b1: float = PI * float(k2 + 1) / 9.0
			Props.strut(g, Vector3(rib, 2.4 + sin(b0) * 2.22, 115.0 + cos(b0) * 3.37), Vector3(rib, 2.4 + sin(b1) * 2.22, 115.0 + cos(b1) * 3.37), 0.22, "fl_brick")
	# the fan ring and the propeller (eight blades round a violet hub), the motor housing behind it
	var fan: Node3D = Props.group(dress, "FanRing", Vector3(1.8, 3.5, 115.0))
	fan.set_meta("keep", true)   # UPDATE 10 (T-155): the WindTunnel spins it
	for k3: int in 24:
		var a2: float = TAU * float(k3) / 24.0
		var a3: float = TAU * float(k3 + 1) / 24.0
		Props.strut(fan, Vector3(0, sin(a2) * 3.45, cos(a2) * 4.45), Vector3(0, sin(a3) * 3.45, cos(a3) * 4.45), 0.35, "steel")
	for k4: int in 8:
		var a4: float = TAU * float(k4) / 8.0 + 0.2
		Props.obox(fan, Vector3(0.2, sin(a4) * 1.8, cos(a4) * 2.2), Vector3(0.08, 3.2, 0.7), "walnut", Vector3(rad_to_deg(a4) * -1.0, 0, 24))
	Props.cyl(fan, Vector3(0.3, 0, 0), 0.55, 0.7, "steel", Vector3(0, 0, 90))
	Props.cyl(fan, Vector3(0.68, 0, 0), 0.32, 0.08, "nachtglas", Vector3(0, 0, 90))
	for k5: int in 4:
		var a5: float = TAU * float(k5) / 4.0 + PI * 0.25
		Props.strut(fan, Vector3(-0.5, 0, 0), Vector3(-0.3, sin(a5) * 3.3, cos(a5) * 4.2), 0.18, "steel")
	Props.block(g, Vector3(0.2, 1.8, 113.4), Vector3(1.0, 5.2, 116.6), "machine_green")
	# the test section: steel mullions on the glass, the model on its sting (above head height), instruments
	for mz: float in [26.0, 27.5, 29.0, 30.5, 32.0, 33.5, 35.0, 36.5, 38.0]:
		NB(Vector3(mz - 0.04, 0, 117.78), Vector3(mz + 0.04, 2.4, 118.22), "steel", g)
	NB(Vector3(26.0, 2.32, 117.75), Vector3(38.0, 2.44, 118.25), "steel", g)
	Props.block(g, Vector3(30.75, 0, 114.75), Vector3(31.25, 1.2, 115.25), "steel")
	Props.strut(g, Vector3(31.0, 1.2, 115.0), Vector3(31.0, 2.05, 115.0), 0.08, "steel")
	var model: MeshInstance3D = MeshInstance3D.new()
	model.name = "KranichModel"
	model.mesh = GenDetail.flying_wing_mesh(KRANICH_WING, 18, 12)
	model.material_override = Mats.get_mat("chrome_worn")
	model.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE / 30.0), Vector3(31.0, 2.02, 115.0))
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dress.add_child(model)
	model.set_meta("keep", true)
	for gz: float in [112.2, 117.8]:
		for gx: float in [28.0, 34.0]:
			Props.gauge(g, Vector3(gx, 1.6, gz + (0.18 if gz < 115.0 else -0.18)), 180.0 if gz < 115.0 else 0.0, 0.12)
	Props.stencil(g, Vector3(32.0, 2.0, 111.82), 0.0, "MESSSTRECKE", 90, Color(0.9, 0.88, 0.8, 0.8))
	# Jette's glass office over the north side of the test section (hung from the roof trusses, a ladder up the east
	# wall): a steel deck at 2.7 m, glazing with mullions, a desk with its lamp, Wittkamp's silhouette at the glass
	var ox0: float = 30.0
	var ox1: float = 43.85
	var oz0: float = 118.35
	var oz1: float = 124.0
	Props.block(g, Vector3(ox0, 2.6, oz0), Vector3(ox1, 2.75, oz1), "steel")
	Props.block(g, Vector3(ox0, 5.4, oz0), Vector3(ox1, 5.55, oz1), "steel")
	for gl: Array in [[Vector3(ox0, 2.75, oz0), Vector3(ox1, 5.4, oz0 + 0.04)], [Vector3(ox0, 2.75, oz1 - 0.04), Vector3(ox1, 5.4, oz1)], [Vector3(ox0, 2.75, oz0), Vector3(ox0 + 0.04, 5.4, oz1)]]:
		GenDetail._ns(Props.block(g, gl[0], gl[1], "frosted"))
	var mx: float = ox0
	while mx <= ox1:
		NB(Vector3(mx - 0.04, 2.75, oz0 - 0.03), Vector3(mx + 0.04, 5.4, oz0 + 0.07), "steel", g)
		NB(Vector3(mx - 0.04, 2.75, oz1 - 0.07), Vector3(mx + 0.04, 5.4, oz1 + 0.03), "steel", g)
		mx += 1.5
	for hx: float in [ox0 + 0.2, 37.0]:
		for hz: float in [oz0 + 0.2, oz1 - 0.2]:
			Props.strut(g, Vector3(hx, 5.55, hz), Vector3(hx, 6.4, hz), 0.04, "iron", true)
	Props.block(g, Vector3(34.0, 2.75, 121.4), Vector3(36.4, 3.5, 122.6), "furniture")
	GenDetail.lamp_fixture(g, Vector3(35.6, 3.55, 122.3), "hanging", 0.0, 3.9, "enamel_green")
	GenDetail.silhouette(g, Vector3(33.2, 2.75, 118.5), 0.0, 1.78)
	GenDetail.enamel_sign(g, Vector3(37.0, 3.1, 118.3), 0.0, "BÜRO MAURER  ·  ZUTRITT NUR MIT ERLAUBNIS", 2.6, 0.24)
	Props.ladder(g, Vector3(43.7, 0, 125.4), -90.0, 2.75)
	# the hatch under the office on the east wall (the JetteHatch interactable stands in front of it)
	GenDetail.door(g, Vector3(43.85, 0.0, 124.0), 90.0, 0.9, 1.4, {"blind": true, "steel": true, "leaf": "machine_grey", "step": false, "frame": "steel"})
	# signs, pipes, the control desk by the fan control
	GenDetail.enamel_sign(g, Vector3(8.0, 3.0, 100.17), 180.0, "WINDKANAL  ·  ANLAGE 2", 1.8, 0.3)
	GenDetail.enamel_sign(g, Vector3(5.5, 2.8, 111.82), 0.0, "VORSICHT  ·  LUFTSTROM", 1.4, 0.28, "enamel_white", Color(0.5, 0.06, 0.04))
	GenDetail.pipe_run(g, PackedVector3Array([Vector3(1.0, 5.4, 113.2), Vector3(1.0, 5.4, 101.0), Vector3(43.5, 5.4, 101.0)]), 0.12, "machine_green", 3.0, 1)
	GenDetail.cable_tray(g, Vector3(5.0, 4.6, 129.7), Vector3(43.6, 4.6, 129.7), 0.3, "iron", 3)
	GenDetail.poster(g, Vector3(10.0, 1.7, 129.83), 0.0, "FLUGPLAN", "Kurs 285, Höhe 9000.\nWegpunkt 7: ?\nNicht kopieren.", 0.42, 0.56)
	GenDetail.chalk_mark(g, Vector3(6.2, 1.1, 111.85), 0.0, "jakub", 0.26)


# ------------------------------------------------------------------ G: Prüfstand

func _dress_pruefstand() -> void:
	var g: Node3D = Props.group(dress, "PruefstandDress", Vector3.ZERO)
	NB(Vector3(-59.85, 0.0, 110.15), Vector3(-0.15, 0.006, 149.85), "fl_floor", g)
	_frame_gameplay_windows(g, "G_PRUEFSTAND", "steel")
	# board-formed walls (tie holes here: these are small and close), concrete copings
	GenDetail.form_board(g, Vector3(-59.85, 0, 110.2), Vector3(-59.85, 5, 149.8), Vector3.RIGHT, 0.6, "fl_concrete", true)
	GenDetail.form_board(g, Vector3(-0.15, 0, 130.2), Vector3(-0.15, 5, 149.8), Vector3.LEFT, 0.6, "fl_concrete", false)
	for c: Array in [[Vector3(-60.25, 5.0, 110.0), Vector3(-59.75, 5.25, 150.0)], [Vector3(-0.25, 5.0, 130.0), Vector3(0.25, 5.25, 150.0)]]:
		Props.block(g, c[0], c[1], "concrete")
	# the ring road's lines, oil and soot
	for lz: Array in [[Vector3(-56.0, 0.007, 120.5), Vector3(-4.0, 0.012, 120.65)], [Vector3(-56.0, 0.007, 135.35), Vector3(-4.0, 0.012, 135.5)]]:
		NB(lz[0], lz[1], "enamel_white", g)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7111
	for i: int in 9:
		GenDetail.card(g, "soot", Vector3(rng.randf_range(-56.0, -4.0), 0.012, rng.randf_range(113.0, 148.0)), Vector3.UP, Vector2(rng.randf_range(1.5, 3.5), rng.randf_range(1.2, 2.5)))
	# the four test stands (Pit1..4 colliders, 8 × 8 × 1 m): a concrete plinth with a sunken bed, a thrust frame,
	# three burnt engines and in pit 4 the Nachtglas impeller on its stand, still humming
	var px: float = -52.0
	for i2: int in 4:
		var c2: Vector3 = Vector3(px + 4.0, 1.0, 128.0)
		GenDetail.trim(g, Vector3(px, 0.98, 124.0), Vector3(px + 8.0, 0.98, 124.0), Vector3.FORWARD, 0.12, 0.08, "steel")
		NB(Vector3(px + 0.8, 1.0, 124.8), Vector3(px + 7.2, 1.012, 131.2), "black_paint", g)
		for fz: float in [125.2, 130.8]:
			GenDetail.i_beam(g, Vector3(px + 1.0, 1.15, fz), Vector3(px + 7.0, 1.15, fz), 0.3, 0.2, "steel")
		for fx: float in [px + 1.2, px + 6.8]:
			Props.strut(g, Vector3(fx, 1.0, 125.2), Vector3(fx, 3.4, 128.0), 0.18, "steel")
			Props.strut(g, Vector3(fx, 1.0, 130.8), Vector3(fx, 3.4, 128.0), 0.18, "steel")
		GenDetail.i_beam(g, Vector3(px + 1.2, 3.4, 128.0), Vector3(px + 6.8, 3.4, 128.0), 0.35, 0.22, "steel")
		if i2 < 3:
			# a burnt jet engine slung from the frame: blackened casing, a split intake, scorch on the bed
			Props.cyl(g, c2 + Vector3(0, 1.4, 0), 0.62, 4.6, "char", Vector3(0, 0, 90))
			Props.cone(g, c2 + Vector3(-2.6, 1.4, 0), 0.62, 0.7, "rust", Vector3(0, 0, 90))
			Props.cyl(g, c2 + Vector3(2.5, 1.4, 0), 0.45, 0.5, "black_paint", Vector3(0, 0, 90))
			for ring: float in [-1.4, 0.0, 1.4]:
				Props.cyl(g, c2 + Vector3(ring, 1.4, 0), 0.66, 0.08, "rust", Vector3(0, 0, 90))
			GenDetail.card(g, "soot", c2 + Vector3(0, 0.02, 0), Vector3.UP, Vector2(6.0, 5.0))
			if i2 == 1:
				Props.obox(g, c2 + Vector3(0.6, 0.25, 1.6), Vector3(1.4, 0.06, 0.9), "char", Vector3(10, 40, 6))
			_lib(g, "jerrycan", Vector3(px + 7.4, 1.0, 124.6), 25.0)
		else:
			# pit 4: the impeller on its stand, violet, turning over
			Props.block(g, c2 + Vector3(-0.8, 0, -0.8), c2 + Vector3(0.8, 0.8, 0.8), "machine_grey")
			Props.cyl(g, c2 + Vector3(0, 1.9, 0), 1.25, 1.1, "steel", Vector3(0, 0, 90))
			GenDetail._ns(Props.cyl(g, c2 + Vector3(-0.58, 1.9, 0), 1.05, 0.06, "nachtglas", Vector3(0, 0, 90)))
			GenDetail._ns(Props.cyl(g, c2 + Vector3(0.58, 1.9, 0), 1.05, 0.06, "nachtglas", Vector3(0, 0, 90)))
			for k: int in 6:
				var a: float = TAU * float(k) / 6.0
				Props.obox(g, c2 + Vector3(-0.62, 1.9 + sin(a) * 0.55, cos(a) * 0.55), Vector3(0.04, 0.9, 0.22), "chrome_worn", Vector3(rad_to_deg(-a), 0, 20))
			GenDetail.card(g, "frost", c2 + Vector3(0, 0.02, 0), Vector3.UP, Vector2(5.0, 5.0))
		Props.stencil(g, Vector3(px + 4.0, 0.6, 123.97), 0.0, "STAND %d" % (i2 + 1), 110, Color(0.9, 0.88, 0.8, 0.8))
		px += 12.0
	# the blast wall (NavBlock_BlastWall 52 × 0.6 × 3 m): form boards, a coping, warning stencils, the floods on it
	GenDetail.form_board(g, Vector3(-56.0, 0, 133.98), Vector3(-4.0, 3.0, 133.98), Vector3.FORWARD, 0.3, "fl_concrete", false)
	GenDetail.form_board(g, Vector3(-56.0, 0, 134.62), Vector3(-4.0, 3.0, 134.62), Vector3.BACK, 0.3, "fl_concrete", false)
	Props.block(g, Vector3(-56.1, 3.0, 133.9), Vector3(-3.9, 3.15, 134.7), "concrete")
	for sx: float in [-48.0, -30.0, -12.0]:
		Props.stencil(g, Vector3(sx, 1.8, 133.96), 0.0, "ACHTUNG  ·  PRÜFLAUF", 120, Color(0.85, 0.15, 0.08, 0.85))
	for fl: float in [-42.0, -30.0, -18.0]:
		var fb: Node3D = Props.group(g, "Flood", Vector3(fl, 3.15, 134.3))
		Props.block(fb, Vector3(-0.08, 0, -0.08), Vector3(0.08, 1.4, 0.08), "iron")
		GenDetail.lamp_fixture(fb, Vector3(0, 1.4, -0.1), "flood", 0.0)
	# the control bunker (Bunker* walls; the Crucible inside): observation slits, a periscope, a steel door, cables
	GenDetail.door(g, Vector3(-47.85, 0, 144.0), -90.0, 2.0, DOOR_H, {"leaf": "iron", "steel": true, "open_deg": 170.0, "frame": "steel", "sign": "MESSBUNKER"})
	for sl: Array in [[Vector3(-47.84, 2.2, 140.5), -90.0], [Vector3(-47.84, 2.2, 147.5), -90.0], [Vector3(-54.0, 2.2, 137.84), 0.0]]:
		var s2: Node3D = Props.group(g, "Slit", sl[0], float(sl[1]))
		Props.block(s2, Vector3(-0.9, -0.15, -0.06), Vector3(0.9, 0.15, 0.0), "black_paint")
		Props.block(s2, Vector3(-1.0, 0.15, -0.14), Vector3(1.0, 0.25, 0.0), "iron")
		Props.block(s2, Vector3(-1.0, -0.25, -0.14), Vector3(1.0, -0.15, 0.0), "iron")
	Props.cyl(g, Vector3(-52.0, 5.0, 141.0), 0.15, 1.5, "iron")
	Props.block(g, Vector3(-52.25, 5.6, 140.6), Vector3(-51.75, 5.9, 141.0), "iron")
	GenDetail.pipe_run(g, PackedVector3Array([Vector3(-47.8, 3.6, 139.0), Vector3(-30.0, 3.6, 139.0), Vector3(-30.0, 3.6, 134.8)]), 0.07, "rubber", 6.0)
	# inside: the instrument wall (west), the desk (NavBlock_DeskG), a phone, notices
	for ix: float in [140.0, 141.2, 142.4, 143.6]:
		Props.block(g, Vector3(-59.85, 0.9, ix - 0.5), Vector3(-59.55, 2.4, ix + 0.5), "machine_grey")
		Props.gauge(g, Vector3(-59.54, 1.9, ix - 0.2), -90.0, 0.09)
		Props.gauge(g, Vector3(-59.54, 1.9, ix + 0.2), -90.0, 0.09)
		GenDetail._ns(Props.block(g, Vector3(-59.56, 1.2, ix - 0.3), Vector3(-59.54, 1.5, ix + 0.3), "gauge_lit"))
	Props.block(g, Vector3(-58.2, 0.78, 146.6), Vector3(-57.0, 0.82, 147.4), "felt_green")
	GenDetail.poster(g, Vector3(-59.83, 1.7, 148.6), -90.0, "BESATZUNG", "Prüfstand 4: Besatzung gestellt.\nKeine Namen eintragen.", 0.4, 0.5)
	GenDetail.poster(g, Vector3(-48.4, 1.6, 138.17), 180.0, "PRÜFLAUF NUR MIT FREIGABE", "", 0.5, 0.3, "paper", Color(0.6, 0.08, 0.05))
	GenDetail.chalk_mark(g, Vector3(-4.6, 1.0, 133.97), 0.0, "jakub", 0.28)
	# the hangar's 20 m wall rises behind the 5 m wall here; its foot gets a drift of grit and two drums
	for dx: float in [-58.9, -58.1]:
		Props.oil_drum(g, Vector3(dx, 0, 111.0), "rust")


# ------------------------------------------------------------------ the works: sky, braziers, signs, the far world

func _dress_works() -> void:
	# fire barrels the dead left burning
	for p: Vector3 in [Vector3(20, 0, 24), Vector3(34, 0, 38), Vector3(10, 0, 66), Vector3(-30, 0, 118)]:
		brazier(p)
	# the sky: searchlights sweeping a cloud deck, the dawn that never comes, the forest ridges round the valley
	var sky: Node3D = Node3D.new()
	sky.name = "ThalbachSky"
	sky.add_to_group(&"thalbach_sky", true)
	sky.set_script(load("res://gravelight/world/map04/thalbach_sky.gd"))
	sky.set("bases", PackedVector3Array([Vector3(-66, 10, 64), Vector3(42, 10, 32), Vector3(36, 22, 212), Vector3(-74, 24, 150)]))
	extra_root_nodes.append(sky)
	# the searchlight towers themselves (lamp drums on lattice masts outside the works' walls)
	for b: Vector3 in [Vector3(-66, 10, 64), Vector3(42, 10, 32), Vector3(36, 22, 212), Vector3(-74, 24, 150)]:
		Props.block(dress, Vector3(b.x - 0.5, -0.5, b.z - 0.5), Vector3(b.x + 0.5, b.y - 0.6, b.z + 0.5), "steel")
		Props.block(dress, Vector3(b.x - 1.2, b.y - 0.7, b.z - 1.2), Vector3(b.x + 1.2, b.y - 0.55, b.z + 1.2), "fl_grate")
		Props.cyl(dress, b, 0.75, 0.9, "machine_grey", Vector3(60, 0, 0))
		GenDetail._ns(Props.cyl(dress, b + Vector3(0, 0.3, 0.2), 0.68, 0.05, "flood_glass", Vector3(60, 0, 0)))
	# stencils and signs (the old labels, kept where they were)
	label("WERK THALBACH", Vector3(20, 4.2, 29.7), 180.0, 56)
	label("KANTINE", Vector3(-22, 4.0, 30.3), 0.0, 48)
	label("MONTAGE 1 · 2", Vector3(-22, 7.0, 60.3), 0.0, 48)
	label("WINDKANAL", Vector3(8, 5.0, 100.3), 0.0, 48)
	label("PRÜFSTAND", Vector3(-30, 4.2, 110.3), 0.0, 48)
	label("HALLE", Vector3(-30, 4.4, 150.3), 0.0, 48)
	# UPDATE 10 (T-155): two flak towers on the skyline, the air raid's guns (map04a.json raid.flak_towers are their tops):
	# board-formed concrete, four corner gun platforms, no markings
	for ft: Vector3 in [Vector3(-118.0, 0.0, 30.0), Vector3(100.0, 0.0, 190.0)]:
		Props.block(dress, ft + Vector3(-7.0, -0.5, -7.0), ft + Vector3(7.0, 32.0, 7.0), "fl_concrete")
		Props.block(dress, ft + Vector3(-8.0, 32.0, -8.0), ft + Vector3(8.0, 33.2, 8.0), "fl_concrete")
		for cx: float in [-6.0, 6.0]:
			for cz: float in [-6.0, 6.0]:
				Props.cyl(dress, ft + Vector3(cx, 34.0, cz), 2.0, 1.6, "fl_concrete")
				Props.cyl(dress, ft + Vector3(cx, 35.2, cz), 0.5, 0.8, "machine_grey")
				Props.cyl(dress, ft + Vector3(cx + 0.9, 36.0, cz), 0.12, 2.6, "steel", Vector3(0, 0, -55))
	# the works' chimney behind the Kraftzentrale and a water tower beyond the Siedlung: skyline silhouettes
	Props.cyl(dress, Vector3(-66.0, 14.0, 78.0), 1.4, 28.0, "fl_brick")
	Props.cyl(dress, Vector3(-66.0, 28.2, 78.0), 1.6, 0.6, "concrete")
	Props.cyl(dress, Vector3(54.0, 9.0, -12.0), 0.5, 18.0, "steel")
	Props.cyl(dress, Vector3(54.0, 19.5, -12.0), 4.0, 4.5, "fl_brick")
	Props.cone(dress, Vector3(54.0, 22.6, -12.0), 4.4, 1.8, "roof")


# ------------------------------------------------------------------ lights

func _lights() -> void:
	# moonlight through the sheds' windows (shadowless here: the key lights below cast)
	for id: String in ["W_C_W", "W_C_S", "W_E_W", "W_F_E", "W_F_N", "W_E_N"]:
		for w: Array in windows:
			if str(w[0]) == id:
				var p: Vector3 = w[2]
				var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
				shaft("MoonShaft_" + id, p - inward * 2.5 + Vector3(0, 2.75, 0), p + inward * 3.6, MOONLIGHT, 8.0, 14.0, 28.0, 3.0, false)
	# the key light per zone: one shadowed spot from a fixture you can see
	shaft("KeyA_PumpLantern", Vector3(8.6, 2.85, 29.4), Vector3(12.0, 0.0, 24.0), INCAND, 5.5, 13.0, 55.0, 0.6, true)
	shaft("KeyB_HopperLamp", Vector3(20.0, 8.0, 46.2), Vector3(17.0, 0.0, 47.5), SODIUM, 6.0, 20.0, 62.0, 0.5, KEY_SHADOW)
	shaft("KeyC_StageLamp", Vector3(-35.5, 5.4, 50.0), Vector3(-39.0, 0.3, 57.0), INCAND, 6.5, 16.0, 40.0, 0.5, true)
	shaft("KeyD_WellLantern", Vector3(8.0, 2.2, 80.62), Vector3(9.0, 0.0, 83.0), INCAND, 4.5, 10.0, 70.0, 0.6, true)
	shaft("KeyE_GantryFlood", Vector3(-28.0, 8.1, 84.5), Vector3(-26.0, 2.5, 74.0), MERCURY, 7.0, 24.0, 55.0, 0.6, KEY_SHADOW)
	shaft("KeyF_OfficeLamp", Vector3(31.0, 2.55, 118.6), Vector3(31.0, 0.0, 114.0), INCAND, 5.0, 9.0, 70.0, 0.5, true)
	shaft("KeyG_BlastFlood", Vector3(-30.0, 4.3, 134.2), Vector3(-30.0, 1.0, 127.0), MERCURY, 7.0, 22.0, 75.0, 0.5, KEY_SHADOW)
	shaft("KeyH_CraneFlood", Vector3(-20.0, CRANE_Y + 1.1, 158.6), Vector3(-20.0, 0.0, 163.0), MERCURY, 8.0, 26.0, 50.0, 0.6, true)
	# other always-on light sources (lanterns, glows), shadowless
	lamp(Vector3(8.6, 2.9, 29.45), INCAND, 0.6, 5.0, 0.12, 0.3)
	lamp(Vector3(8.0, 2.15, 80.6), INCAND, 0.6, 5.0, 0.12, 0.3)
	lamp(Vector3(7.0, 2.1, 6.0), INCAND, 0.8, 7.0, 0.1, 0.2)                 # the cellar lantern
	lamp(Vector3(-12.0, 2.9, 128.0), VIOLET, 1.6, 12.0, 0.1, 1.0)            # the live impeller in pit 4
	lamp(Vector3(3.2, 3.5, 115.0), VIOLET, 0.9, 8.0, 0.06, 0.6)              # the fan hub's Nachtglas glow
	lamp(Vector3(40.0, 8.7, 33.0), RED, 0.5, 4.0, 0.0, 0.2)                  # the signal lamp
	lamp(Vector3(35.6, 3.4, 122.3), INCAND, 0.7, 6.0, 0.05, 0.3)             # Jette's desk lamp
	lamp(Vector3(-20.0, 2.2, 164.2), SODIUM, 1.0, 8.0, 0.05, 0.5)            # the Kranich's bay light over the ramp
	for sk: float in [-30.0, 5.0]:
		shaft("SkylightShaft", Vector3(sk, 21.5, 185.0), Vector3(sk + 3.0, 0.0, 186.0), MOONLIGHT, 3.0, 26.0, 18.0, 2.0, false)
	# power lights: each at a fixture's bulb (the fixture is drawn here), shadowless
	var pz: Array = [
		["A_SIEDLUNG", "wall", Vector3(13.0, 5.4, 0.16), 180.0, SODIUM, 18.0, 1.0], ["A_SIEDLUNG", "wall", Vector3(39.84, 5.4, 25.0), 90.0, SODIUM, 18.0, 1.0],
		["B_BAHNHOF", "hanging", Vector3(12.0, 7.4, 46.2), 0.0, SODIUM, 18.0, 1.1], ["B_BAHNHOF", "hanging", Vector3(28.0, 7.4, 46.2), 0.0, SODIUM, 18.0, 1.1],
		["B_BAHNHOF", "wall", Vector3(27.83, 2.9, 53.5), 90.0, INCAND, 10.0, 0.9], ["B_BAHNHOF", "hanging", Vector3(3.0, 2.6, 54.0), 0.0, INCAND, 8.0, 0.8],
		["C_KANTINE", "hanging", Vector3(-31.0, 4.6, 41.0), 0.0, INCAND, 11.0, 1.1], ["C_KANTINE", "hanging", Vector3(-17.0, 4.6, 41.0), 0.0, INCAND, 11.0, 1.1],
		["C_KANTINE", "hanging", Vector3(-31.0, 4.6, 48.0), 0.0, INCAND, 11.0, 1.1], ["C_KANTINE", "hanging", Vector3(-17.0, 4.6, 48.0), 0.0, INCAND, 11.0, 1.1],
		["D_KIRCHPLATZ", "wall", Vector3(36.5, 2.65, 87.75), 0.0, INCAND, 12.0, 1.0], ["D_KIRCHPLATZ", "wall", Vector3(0.16, 5.0, 74.0), -90.0, SODIUM, 18.0, 1.0],
		["D_KIRCHPLATZ", "wall", Vector3(39.84, 4.2, 66.0), 90.0, SODIUM, 16.0, 0.9],
		["E_MONTAGE", "hanging", Vector3(-33.0, 6.6, 74.0), 0.0, MERCURY, 18.0, 1.7], ["E_MONTAGE", "hanging", Vector3(-19.0, 6.6, 74.0), 0.0, MERCURY, 18.0, 1.7],
		["E_MONTAGE", "hanging", Vector3(-33.0, 6.6, 98.0), 0.0, MERCURY, 18.0, 1.7], ["E_MONTAGE", "hanging", Vector3(-19.0, 6.6, 98.0), 0.0, MERCURY, 18.0, 1.7],
		["E_MONTAGE", "hanging", Vector3(-54.0, 3.4, 67.0), 0.0, INCAND, 9.0, 1.0],
		["F_WINDKANAL", "hanging", Vector3(14.0, 6.0, 106.0), 0.0, MERCURY, 14.0, 1.1], ["F_WINDKANAL", "hanging", Vector3(14.0, 6.0, 124.0), 0.0, MERCURY, 14.0, 1.1],
		["F_WINDKANAL", "hanging", Vector3(38.0, 4.9, 121.0), 0.0, INCAND, 8.0, 0.9],
		["G_PRUEFSTAND", "flood_on_wall", Vector3(-42.0, 4.35, 134.2), 0.0, MERCURY, 18.0, 1.1], ["G_PRUEFSTAND", "flood_on_wall", Vector3(-18.0, 4.35, 134.2), 0.0, MERCURY, 18.0, 1.1],
		["G_PRUEFSTAND", "hanging", Vector3(-54.0, 3.4, 144.0), 0.0, INCAND, 9.0, 1.0],
	]
	for e: Array in pz:
		var zone: String = str(e[0])
		var kind: String = str(e[1])
		var pos: Vector3 = e[2]
		var bulb: Vector3 = pos
		if kind == "hanging":
			var ceil_y: float = {"B_BAHNHOF": 8.2, "C_KANTINE": 5.6, "E_MONTAGE": 8.0, "F_WINDKANAL": 6.4, "G_PRUEFSTAND": 4.0}.get(zone, pos.y + 1.0)
			if zone == "B_BAHNHOF" and pos.y < 3.0:
				ceil_y = 3.0
			if zone == "F_WINDKANAL" and pos.y < 5.0:
				ceil_y = 5.4
			bulb = GenDetail.lamp_fixture(dress, pos, "hanging", 0.0, ceil_y, "enamel_green" if zone != "E_MONTAGE" else "machine_grey", "bulb_warm")
		elif kind == "wall":
			bulb = GenDetail.lamp_fixture(dress, pos, "wall", float(e[3]), 0.0, "black_paint", "bulb_warm")
		else:
			bulb = pos   # the flood heads on the blast wall are drawn with the wall
		power(zone, bulb, float(e[5]), float(e[6]), e[4])
	# the hangar's high bays: a reflector lamp on a rod from each truss, a wide beam down
	for hp: Vector3 in [Vector3(-45, 15.2, 165), Vector3(5, 15.2, 165), Vector3(-45, 15.2, 200), Vector3(5, 15.2, 200), Vector3(-20, 15.2, 182)]:
		var hb: Vector3 = GenDetail.lamp_fixture(dress, hp, "hanging", 0.0, 16.0, "machine_grey", "bulb_cold")
		power("H_HALLE", hb, 40.0, 1.6, MERCURY, false, {"dir": Vector3.DOWN, "energy": 2.0, "range": 40.0, "angle": 50.0})


## Detail materials whose batches fade out with distance (contract C4: the dressing must fit the draw-call and
## triangle budgets). Tier 1 (small things: paper, paint, bulbs, cloth) at 38 m; tier 2 (frames, trim, panes) at 70 m.
const DETAIL_NEAR: Array = ["paper", "paper_old", "enamel_white", "black_paint", "brass", "bakelite", "gauge_face", "gauge_lit", "yellow_paint",
	"red_paint", "lamp_red_lit", "lamp_green", "bulb_warm", "bulb_cold", "cloth_red", "cloth_green", "cloth_cream", "cloth_navy", "linen", "leather",
	"walnut", "felt_green", "board_wood", "zinc", "rope", "coal", "lantern_glass", "flood_glass", "rubber", "ice", "wood_red", "shutter_green",
	"machine_green", "sandbag", "lead", "nachtglas", "puddle", "snow", "feldgrau", "enamel_green", "frosted"]
const DETAIL_FAR: Array = ["beam", "stucco_trim", "glass", "window_dark", "char", "machine_grey", "loco_black", "rust", "furniture", "chrome_worn"]


## The finishing pass over the dressing (before the static batching): only big pieces (two sides of 2 m or more:
## walls, slabs, roofs, the tower) cast shadows; text never does and fades at 30 m; instanced details and the CC0
## props fade at 45 / 35 m. Kept groups (the Kranich, the crane, the doors) keep their own settings.
func _finish_dressing() -> void:
	for n: Node in dress.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		if gi is Label3D:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gi.visibility_range_end = 30.0
			continue
		if _kept(gi) and not (gi is MultiMeshInstance3D):
			continue
		if gi is MultiMeshInstance3D:
			gi.visibility_range_end = 45.0
			gi.visibility_range_end_margin = 5.0
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh is PrimitiveMesh:
			var s: Vector3 = _xform_to_root(gi).basis.get_scale().abs()
			var big: int = (1 if s.x >= 2.0 else 0) + (1 if s.y >= 2.0 else 0) + (1 if s.z >= 2.0 else 0)
			if big < 2:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gi.visibility_range_end = 35.0


func merge_static_meshes() -> int:
	_finish_dressing()
	var pre: int = _premerge_dressing(40.0, 12.0)
	return super.merge_static_meshes() + pre


## Folds the dressing's primitive meshes into "DressBatches": one mesh per material, shadow mode and 40 × 12 × 40 m
## cell (coarser than the lib's 22 m cells, which stay for the walls: the dressing has many small materials, so
## fewer, bigger batches keep the draw calls down). Each batch sits at its cell's centre (its vertices are local),
## so a visibility range measures from where the batch is; detail materials fade (DETAIL_NEAR / DETAIL_FAR).
func _premerge_dressing(cell: float, cell_y: float) -> int:
	var near_ids: Dictionary = {}
	var far_ids: Dictionary = {}
	for k: String in DETAIL_NEAR:
		near_ids[Mats.get_mat(k).get_instance_id()] = true
	for k2: String in DETAIL_FAR:
		far_ids[Mats.get_mat(k2).get_instance_id()] = true
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in dress.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or _kept(mi):
			continue
		var xf: Transform3D = _xform_to_root(mi)
		var c: Vector3 = xf.origin
		var ci: Vector3i = Vector3i(floori(c.x / cell), floori((c.y + 4.0) / cell_y), floori(c.z / cell))
		var centre: Vector3 = Vector3((float(ci.x) + 0.5) * cell, (float(ci.y) + 0.5) * cell_y - 4.0, (float(ci.z) + 0.5) * cell)
		var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, ci]
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st, "centre": centre}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, Transform3D(Basis.IDENTITY, -centre) * xf)
		victims.append(mi)
	var holder: Node3D = Node3D.new()
	holder.name = "DressBatches"
	holder.set_meta("keep", true)
	map_root.add_child(holder)
	var i: int = 0
	var faded: int = 0
	for key2: String in groups.keys():
		var gr: Dictionary = groups[key2]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "DressBatch_%d" % i
		out.mesh = _commit(gr["st"])
		out.material_override = gr["mat"]
		out.cast_shadow = gr["shadow"]
		out.position = gr["centre"]
		var id: int = (gr["mat"] as Material).get_instance_id()
		if near_ids.has(id):
			out.visibility_range_end = 38.0 + cell * 0.5
			out.visibility_range_end_margin = 4.0
			faded += 1
		elif far_ids.has(id):
			out.visibility_range_end = 70.0 + cell * 0.5
			out.visibility_range_end_margin = 6.0
			faded += 1
		holder.add_child(out)
		i += 1
	for mi2: MeshInstance3D in victims:
		mi2.get_parent().remove_child(mi2)
		mi2.free()
	print("  dressing: %d meshes into %d batches (%d fade with distance)" % [victims.size(), i, faded])
	return victims.size()


func build_lights() -> void:
	super.build_lights()
	var counts: Dictionary = tag_light_zones(6)
	print("  shadowed lights per zone: %s" % str(counts))
	# the moon: two shadow splits are enough over a works this size (half the directional shadow passes)
	var moon: DirectionalLight3D = map_root.get_node_or_null("Moon") as DirectionalLight3D
	if moon != null:
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		moon.directional_shadow_max_distance = 60.0


## UPDATE 10 Act I (T-155): the base bake, then what the air raid and the wind tunnel switch on at runtime (all
## disabled in the scene): Nav_E_MONTAGE_raid (the Montage zone box baked again with the raid's rubble in it: the
## route through Door_Pruefstand is gone), Link_Breach_E_apron (Montage 2 -> the test stands through the blown
## wall; the test stands' layer) and Link_TunnelHatch (the Windkanal <-> Montage 2 through the plenum hatch; the
## Windkanal's layer). The regions the base bake makes are untouched (same names, same polygons).
func bake_regions() -> void:
	super.bake_regions()
	var nav: Node3D = map_root.get_node("Navigation") as Node3D
	var raid: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/map04a.json")) as Dictionary).get("raid", {})
	var rb: Array = raid.get("rubble_box", [])
	if rb.size() >= 2:
		var lo_r: Vector3 = Vector3(float(rb[0][0]), float(rb[0][1]), float(rb[0][2]))
		var hi_r: Vector3 = Vector3(float(rb[1][0]), float(rb[1][1]), float(rb[1][2]))
		# the heap as three stacked slabs: Recast treats one 2.2 m box as hollow (the gap under its top is taller than an
		# agent, so the floor inside stays walkable); slabs under 1.75 m leave no gap anything fits in
		var tmps: Array[Node3D] = []
		var y0: float = lo_r.y
		for y1: float in [lo_r.y + 0.8, lo_r.y + 1.6, hi_r.y]:
			tmps.append(box(geo, "RaidRubbleBake", Vector3(lo_r.x, y0, lo_r.z), Vector3(hi_r.x, y1, hi_r.z), "concrete"))
			y0 = y1
		var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(_navmesh(), src, geo)
		# and as a carving obstruction (grown by the agent radius): the heap's footprint is cut out of the floor for sure
		var g_r: float = 0.5
		src.add_projected_obstruction(PackedVector3Array([Vector3(lo_r.x - g_r, lo_r.y, lo_r.z - g_r), Vector3(hi_r.x + g_r, lo_r.y, lo_r.z - g_r),
			Vector3(hi_r.x + g_r, lo_r.y, hi_r.z + g_r), Vector3(lo_r.x - g_r, lo_r.y, hi_r.z + g_r)]), lo_r.y - 0.5, hi_r.y - lo_r.y + 1.0, true)
		for zb: Array in zone_boxes:
			if str(zb[0]) != "E_MONTAGE":
				continue
			var lo: Vector3 = zb[1]
			var hi: Vector3 = zb[2]
			var nm: NavigationMesh = _navmesh()
			nm.filter_baking_aabb = AABB(lo, hi - lo)
			NavigationServer3D.bake_from_source_geometry_data(nm, src)
			var r: NavigationRegion3D = NavigationRegion3D.new()
			r.name = "Nav_E_MONTAGE_raid"
			r.navigation_mesh = nm
			r.navigation_layers = 1 << (int(zone_bits["E_MONTAGE"]) - 1)
			r.enabled = false
			nav.add_child(r)
			print("  E_MONTAGE after the raid: %d polys" % nm.get_polygon_count())
			break
		for tmp: Node3D in tmps:
			geo.remove_child(tmp)
			tmp.free()
	for l: Array in [["Link_Breach_E_apron", Vector3(BREACH_X, 0, 109.25), Vector3(BREACH_X, 0, 110.75), "G_PRUEFSTAND"],
			["Link_TunnelHatch", Vector3(-0.75, 0, HATCH_Z), Vector3(0.75, 0, HATCH_Z), "F_WINDKANAL"]]:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = str(l[0])
		link.start_position = l[1]
		link.end_position = l[2]
		link.bidirectional = true
		link.navigation_layers = 1 << (int(zone_bits[l[3]]) - 1)
		link.enabled = false
		nav.add_child(link)


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
	# ---- UPDATE 10 Act I (T-155): the air raid (act round 8), its breach door, the wind tunnel's plenum hatch
	_node("res://gravelight/world/map04/thalbach_raid.gd", "AirRaid", {}, Vector3.ZERO)
	_node("res://gravelight/world/map04/breach_door.gd", "Breach_E_apron", {"door_id": &"door_pruefstand", "opens_zone": &"G_PRUEFSTAND",
		"link_group": &"pruefstand", "cost": 1500, "label": "Engine Test Stands", "size": Vector3(BREACH_W, DOOR_H, 0.25)}, Vector3(BREACH_X, 0, 110.0), 0.0)
	_node("res://gravelight/world/map04/tunnel_hatch.gd", "TunnelHatch", {"width": HATCH_W, "height": HATCH_H}, Vector3(0.0, 0, HATCH_Z), 0.0)
