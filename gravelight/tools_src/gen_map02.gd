extends SceneTree
## Generates Map 2 "Totenhafen" from docs/gravelight/MAPS.md (DECISIONS T-036): the collision shell, per-zone
## navmesh regions on separate navigation layers, the art dressing (procedural materials, props, weather,
## lighting, post), the tide water plane, and every gameplay node.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map02.gd
## Source of truth for the map. Layers as in gen_map01: Geometry (colliders, the navmesh source) / Dressing
## (non-colliding art) / StaticBatches (both merged per material and 22 m cell) / lights / Gameplay.
##
## Frame: +X east, +Z south, y up. The sea is north of the quay (z < 0) and south of the pen mouth (z > 84).
## Heights: quay and piers 0, lower pens -3, dock basins -6, boat interior -2 (deck +1), catwalks +4,
## tower floor +7, hall roof 12. Tide: low -4.0, high -2.2 (map02.json).

const OUT: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const SPINNER: String = "res://gravelight/maps/map01_kaltenbrunn/power_spinner.gd"
const MOON: String = "res://gravelight/maps/map01_kaltenbrunn/moon_switch.gd"
const TIDE: String = "res://gravelight/maps/map02_totenhafen/tide_controller.gd"
const T: float = 0.3
const LY: float = -3.0       # lower pens deck
const BY: float = -6.0       # dock basins
const SY: float = -2.0       # boat interior floor
const DECK: float = 1.0      # boat deck
const CATY: float = 4.0      # catwalks
const TY: float = 7.0        # signal tower floor
const ROOF: float = 12.0
const SILL: float = 0.9
const WTOP: float = 2.2
const DOOR_H: float = 2.4
const LOW_TIDE: float = -4.0
const HIGH_TIDE: float = -2.2

const ZONE_BITS: Dictionary = {
	"A_QUAY": 1, "B_CANNERY": 2, "C_WORKSHOP": 3, "D_PENHALL": 4, "E_UBOAT": 5, "F_LOWERPENS": 6, "G_SIGNAL": 7,
}
const ADJ: Dictionary = {
	"A_QUAY": ["B_CANNERY", "C_WORKSHOP"], "B_CANNERY": ["A_QUAY", "D_PENHALL"], "C_WORKSHOP": ["A_QUAY", "D_PENHALL"],
	"D_PENHALL": ["B_CANNERY", "C_WORKSHOP", "E_UBOAT", "F_LOWERPENS", "G_SIGNAL"],
	"E_UBOAT": ["D_PENHALL"], "F_LOWERPENS": ["D_PENHALL"], "G_SIGNAL": ["D_PENHALL"],
}
## Navigation / zone boxes: [zone, min, max]. Boxes must not overlap (several per zone are fine).
const ZONE_BOXES: Array = [
	["A_QUAY", Vector3(0, -1, 0), Vector3(32, 8, 30)],
	["B_CANNERY", Vector3(-30, -1, 0), Vector3(0, 8, 30)],
	["C_WORKSHOP", Vector3(32, -1, 0), Vector3(62, 8, 30)],
	["D_PENHALL", Vector3(-20, -0.3, 33), Vector3(4, 5.9, 84)],       # D0 west: pier 0, pier 1, apron, west catwalk
	["D_PENHALL", Vector3(10, -0.3, 33), Vector3(52, 5.9, 42)],       # D1 north-east apron
	["D_PENHALL", Vector3(-11, -0.3, 30), Vector3(-9, 5.9, 33)],      # the west pen passage through the slab
	["D_PENHALL", Vector3(43, -0.3, 30), Vector3(45, 5.9, 33)],       # the east pen passage
	# window closets cut into the slab get their own islands, so a window zombie's nearest navmesh is its own
	# floor (it then walks straight to the window) and never the room on the far side of the 3 m wall
	["A_QUAY", Vector3(4.45, -0.5, 30), Vector3(7.55, 3.3, 32.95)],
	["A_QUAY", Vector3(24.45, -0.5, 30), Vector3(27.55, 3.3, 32.95)],
	["D_PENHALL", Vector3(-17.55, -0.5, 30.05), Vector3(-14.45, 3.3, 33)],
	["D_PENHALL", Vector3(9.45, -0.5, 30.05), Vector3(12.55, 3.3, 33)],
	["D_PENHALL", Vector3(28.45, -0.5, 30.05), Vector3(31.55, 3.3, 33)],
	["G_SIGNAL", Vector3(43.45, 6.5, 30.05), Vector3(46.55, 10.3, 33)],
	["G_SIGNAL", Vector3(47.45, 6.5, 30.05), Vector3(50.55, 10.3, 33)],
	["D_PENHALL", Vector3(10, -0.3, 42), Vector3(46, 5.9, 50)],       # D2 apron west of the pump stair
	["D_PENHALL", Vector3(10, -0.3, 50), Vector3(52, 5.9, 84)],       # D3 east apron over the lower pens, pier 2
	["D_PENHALL", Vector3(4, -0.3, 33), Vector3(10, 5.9, 38)],        # D4 apron in front of the bow
	["D_PENHALL", Vector3(46, 2.6, 42), Vector3(52, 5.9, 50)],        # D5 east catwalk over the pump stair
	["E_UBOAT", Vector3(4, -2.6, 38), Vector3(10, 1.5, 86)],
	["F_LOWERPENS", Vector3(32, -4.0, 50), Vector3(52, -0.3, 84)],
	["F_LOWERPENS", Vector3(46, -4.0, 42), Vector3(52, 2.5, 50)],    # the pump stair
	["G_SIGNAL", Vector3(29, 5.95, 33), Vector3(52, 12, 38)],
	["G_SIGNAL", Vector3(46.6, 6.5, 38), Vector3(50.6, 10.3, 40.9)],   # T-273: the signal balcony
]
## Navigation links through doorways and across box seams: [from, to, zone whose layer gates the link].
const LINKS: Array = [
	[Vector3(0.6, 0, 15), Vector3(-0.6, 0, 15), "B_CANNERY"],
	[Vector3(31.4, 0, 15), Vector3(32.6, 0, 15), "C_WORKSHOP"],
	[Vector3(-10, 0, 29.6), Vector3(-10, 0, 30.4), "D_PENHALL"],
	[Vector3(44, 0, 29.6), Vector3(44, 0, 30.4), "D_PENHALL"],
	[Vector3(-10, 0, 32.6), Vector3(-10, 0, 33.4), "D_PENHALL"],
	[Vector3(44, 0, 32.6), Vector3(44, 0, 33.4), "D_PENHALL"],
	[Vector3(3.6, 0, 35.5), Vector3(4.4, 0, 35.5), "D_PENHALL"],
	[Vector3(9.6, 0, 35.5), Vector3(10.4, 0, 35.5), "D_PENHALL"],
	[Vector3(3.6, CATY, 34), Vector3(4.4, CATY, 34), "D_PENHALL"],
	[Vector3(9.6, CATY, 34), Vector3(10.4, CATY, 34), "D_PENHALL"],
	[Vector3(17, 0, 41.6), Vector3(17, 0, 42.4), "D_PENHALL"],
	[Vector3(42, 0, 41.6), Vector3(42, 0, 42.4), "D_PENHALL"],
	[Vector3(17, 0, 49.6), Vector3(17, 0, 50.4), "D_PENHALL"],
	[Vector3(42, 0, 49.6), Vector3(42, 0, 50.4), "D_PENHALL"],
	[Vector3(51, CATY, 41.6), Vector3(51, CATY, 42.4), "D_PENHALL"],
	[Vector3(51, CATY, 49.6), Vector3(51, CATY, 50.4), "D_PENHALL"],
	[Vector3(10.4, DECK, 58), Vector3(9.6, DECK, 58), "E_UBOAT"],
	[Vector3(49, 0, 41.6), Vector3(49, 0, 42.4), "F_LOWERPENS"],
	[Vector3(49, LY, 49.6), Vector3(49, LY, 50.4), "F_LOWERPENS"],
	[Vector3(36.3, 5.82, 34), Vector3(37.6, 6.15, 34), "G_SIGNAL"],
	[Vector3(48.6, TY, 37.3), Vector3(48.6, TY, 39.0), "G_SIGNAL"],   # T-273: through the balcony door
]

## Windows: [id, zone, floor pos on the wall line, inward yaw (Basis(UP, yaw) * +Z points into the room)].
const WINDOWS: Array = [
	["W_A_N1", "A_QUAY", Vector3(10, 0, 0), 0.0], ["W_A_N2", "A_QUAY", Vector3(24, 0, 0), 0.0],
	["W_A_S1", "A_QUAY", Vector3(6, 0, 30), 180.0], ["W_A_S2", "A_QUAY", Vector3(26, 0, 30), 180.0],
	["W_B_N", "B_CANNERY", Vector3(-22, 0, 0), 0.0], ["W_B_W1", "B_CANNERY", Vector3(-30, 0, 12), 90.0],
	["W_B_W2", "B_CANNERY", Vector3(-30, 0, 24), 90.0],
	["W_C_N", "C_WORKSHOP", Vector3(47, 0, 0), 0.0], ["W_C_E1", "C_WORKSHOP", Vector3(62, 0, 10), -90.0],
	["W_C_E2", "C_WORKSHOP", Vector3(62, 0, 22), -90.0],
	["W_D_N1", "D_PENHALL", Vector3(-16, 0, 33), 0.0], ["W_D_N2", "D_PENHALL", Vector3(11, 0, 33), 0.0],
	["W_D_N3", "D_PENHALL", Vector3(30, 0, 33), 0.0],
	["W_G_N1", "G_SIGNAL", Vector3(45, TY, 33), 0.0], ["W_G_N2", "G_SIGNAL", Vector3(49, TY, 33), 0.0],
]
## Windows whose outside is a landing stage over the water instead of a closet.
const STAGE_WINDOWS: Array = ["W_A_N1", "W_A_N2"]
## Wall-buys: [weapon, pos (wall surface), yaw so local -Z faces the room].
const BUYS: Array = [
	["kar98k", Vector3(9.83, 1.5, 13.5), 90.0], ["m1_carbine", Vector3(20.83, 1.5, 5.0), 90.0],
	["trench_gun", Vector3(-0.17, 1.5, 22.0), 90.0], ["frag", Vector3(-0.17, 1.5, 26.0), 90.0],
	["mp40", Vector3(32.17, 1.5, 20.0), -90.0], ["stg44", Vector3(32.17, 1.5, 24.0), -90.0],
	["etool", Vector3(61.83, 1.5, 20.0), 90.0],
	# the two pier boards hang on the lockers' free faces (UPDATE 07 QA, test_map02_edges: the BAR's board sat on
	# Locker1's seaward face over the basin and the Thompson's inside Locker2, both unreachable behind a collider)
	["bar", Vector3(-4.73, 1.5, 70.0), -90.0], ["thompson", Vector3(18.83, 1.5, 50.0), 90.0],
]
## Doors: [name, door_id, zone, also, link, cost, label, pos, yaw, width, needs_power]
const DOORS: Array = [
	["Door_Cannery", "door_cannery", "B_CANNERY", [], "", 1000, "Fish Cannery", Vector3(0, 0, 15), 90.0, 2.0, false],
	["Door_Workshop", "door_workshop", "C_WORKSHOP", [], "", 1000, "Torpedo Workshop", Vector3(32, 0, 15), 90.0, 2.0, false],
	["Door_PenHall_W", "door_penhall", "D_PENHALL", [], "penhall", 1500, "Pen Hall", Vector3(-10, 0, 31.5), 0.0, 2.0, false],
	["Door_PenHall_E", "door_penhall", "D_PENHALL", [], "penhall", 1500, "Pen Hall", Vector3(44, 0, 31.5), 0.0, 2.0, false],
	["Door_Gangway", "door_gangway", "E_UBOAT", [], "", 1500, "U-1047 Gangway", Vector3(14, 0, 58), 90.0, 2.0, false],
	["Door_Pumps", "door_pumps", "F_LOWERPENS", [], "", 1500, "Lower Pens", Vector3(49, 0, 42), 0.0, 3.0, false],
	["Door_Signal", "door_signal", "G_SIGNAL", [], "", 2500, "Signal Tower", Vector3(42, TY, 34), 90.0, 2.0, true],
]
## Ammo boxes (Update 02 section 4, T-049): [name, floor pos, yaw so local -Z faces the room]. Four, spread over the
## route out of the quay: the Cannery's west wall between its two windows; the Workshop's east wall north of the
## warhead cage; the Pen Hall's north apron by the west pier; the Pen Hall's east apron under the east catwalk. All
## 4 m+ from the perk machines and the Crucible (in the boat), clear of doors, windows and the trolley track.
const AMMO_BOXES: Array = [
	["Cannery", Vector3(-29.52, 0, 18.0), -90.0], ["Workshop", Vector3(61.5, 0, 13.0), 90.0],
	["PenHallWest", Vector3(0.0, 0, 33.33), 180.0], ["PenHallEast", Vector3(51.52, 0, 77.0), 90.0],
]

## Greybox colour keys -> material library keys.
## U09 s5 (T-145): the CC0 library sets (materials.json m2_*: form-board concrete, worn and wet floors, tide-stained
## pier sides, grating, tread plate, painted hull plating, corrugated and tarred roofs) instead of the one noise.
const MAT_MAP: Dictionary = {
	"wall": "m2_bunker", "concrete": "m2_bunker", "ground": "m2_floor", "pier": "m2_pier",
	"metal": "iron", "steel": "steel", "rust": "rust", "furniture": "furniture", "rock": "m2_bunker",
	"hull": "m2_hull", "hull_in": "u_interior", "lead": "lead", "rail": "iron", "deck": "m2_grate", "stairs": "m2_bunker",
	"roof": "m2_corrugated", "planks": "planks", "zinc": "m2_zinc", "cliff": "cliff", "shingle": "shingle", "grey": "grey_paint",
}
const MAT_RULES: Array = [
	["CanneryRoof", "m2_corrugated"], ["WorkshopRoof", "m2_corrugated"], ["HutRoof", "m2_tarred"], ["Pier*", "m2_pier"],
	["Apron*", "m2_floor_wet"], ["Basin*", "m2_pier"], ["Catwalk*", "m2_grate"], ["TowerFloor", "m2_floor"], ["PensFloor", "m2_floor_wet"],
	["Pens*", "m2_bunker_wet"], ["StairW", "m2_bunker_wet"], ["Gangway", "m2_grate"], ["HullDeck*", "m2_tread"], ["Hatch*", "m2_grate"],
	["HallRoof", "m2_bunker_wet"], ["HallW*", "m2_bunker_wet"], ["HallE*", "m2_bunker_wet"], ["Passage*", "m2_floor_wet"],
	["SwitchDais", "m2_tread"],
]
## Greybox visuals replaced by dressing (colliders stay).
const HIDE: Array = [
	"Rail*", "Cutter", "Hut", "Conveyor", "GutLine*", "Brine*", "Cradle*", "Lathe", "Cage*", "Pump*", "Desk*",
	"Diesel*", "CraneLeg*", "CraneOffice*", "Pallet*", "NavBlock*", "Stage", "HullSide*", "HullFloor", "HullKeel", "Bulkhead*",
	"CT_*", "Bow*", "Stern*", "SeaGrille", "Curtain", "Switchboard", "Teletype*", "Rack*", "Cot*", "Stove*",
]
const SODIUM: Color = Color(1.0, 0.66, 0.36)
const MERCURY: Color = Color(0.72, 0.84, 1.0)
const INCAND: Color = Color(1.0, 0.78, 0.55)
const RED: Color = Color(1.0, 0.22, 0.14)
const VIOLET: Color = Color(0.62, 0.28, 1.0)
const MOONLIGHT: Color = Color(0.55, 0.66, 0.95)
const SEALIGHT: Color = Color(0.5, 0.64, 0.8)
const FIRE: Color = Color(1.0, 0.55, 0.22)
## Fire barrels (lighting pass T-063): [name, floor pos]. Warm pools the players can read the dark by.
const BRAZIERS: Array = [["Quay", Vector3(29.6, 0, 23.0)], ["QuayBunker", Vector3(16.6, 0, 27.6)], ["CraneBay", Vector3(50.9, 0, 52.6)]]
## Coke stoves (lighting pass T-063): [name, floor pos, yaw so local -Z (the fire door) faces the room].
const STOVES: Array = [["Workshop", Vector3(61.0, 0, 27.8), 90.0], ["WorkshopNW", Vector3(33.0, 0, 2.2), -90.0]]
## The Armorer's Bench (UPDATE_04 section 6, T-068; the order names no Totenhafen spot, so it goes near spawn like the
## other maps): [floor position against the wall, yaw so local -Z faces the quay]. On the harbourmaster's hut's
## south face, east of its window and sign, facing the spawn.
const ARMORERS_BENCH: Array = [Vector3(16.3, 0, 17.0 + T * 0.5 + 0.01), 180.0]
## T-273 (the map detail pass): the signal balcony, a grated platform outside a new door in the tower's south wall,
## 7 m over the hall's east apron, closed by rails on its three open sides (x BALC_X0..BALC_X1, z 38.15..BALC_Z1),
## and its zip line: [name, the cable's top (2 m over the balcony, a step outside its south rail), the landing post's
## foot on the east apron]. The same numbers are in map02.json "ziplines" (test_map02_detail holds them together).
const BALC_X0: float = 46.8
const BALC_X1: float = 50.4
const BALC_Z1: float = 40.65
const BALC_DOOR_X0: float = 47.6
const BALC_DOOR_X1: float = 49.6
const ZIP_POST_H: float = 2.75
const SIGNAL_ZIP: Array = ["SignalZip", Vector3(48.6, TY + 2.0, BALC_Z1 + 0.15), Vector3(40.0, 0.0, 49.6)]
## T-273: the players' ladders at the zombies' three catwalk climb links: [name, the ladder's foot against the catwalk's
## edge (Props.ladder's pos), yaw (local -Z away from the catwalk)]. map02.json "ladders" and "climb_links" put the body's
## line 0.515 m out from pos (0.4 m off the rungs). The rails stay closed: the climb carries a body over them, as on
## Map 0's tower (T-268).
const CATWALK_LADDERS: Array = [
	["W", Vector3(-17.93, 0.0, 55.5), -90.0], ["N", Vector3(15.0, 0.0, 35.07), 180.0], ["E", Vector3(49.93, 0.0, 72.0), 90.0],
]
## Visibility groups (U09 s5, T-145; ViewCells): a static mesh, light, label or decal belongs to the first box that
## holds its centre (dressing built by a zone's _dress_* function carries that zone's group as meta "vis" and skips
## the boxes); anything in no box is "ALL" and always drawn. "DH" is the hall round U-1047's hatch and tower: the
## part of the hall the boat's interior sees up through the open hatch.
const VIS_BOXES: Array = [
	["E", Vector3(4.0, -6.0, 38.05), Vector3(10.0, 0.62, 86.7)],   # T-180: from 38.05, so the apron's edge railing (z 38) is D
	["G", Vector3(41.0, 6.5, 32.9), Vector3(52.4, 11.7, 38.4)],
	["F", Vector3(31.9, -6.5, 42.0), Vector3(52.1, -0.35, 84.7)],
	["DH", Vector3(-4.0, 0.62, 50.0), Vector3(18.0, 13.5, 76.0)],
	["D", Vector3(-23.5, -9.0, 33.0), Vector3(55.5, 13.5, 100.0)],
	["B", Vector3(-34.0, -1.0, -0.4), Vector3(0.16, 9.0, 30.0)],
	["C", Vector3(31.84, -1.0, -0.4), Vector3(66.0, 9.0, 30.0)],
	["A", Vector3(0.16, -1.0, -14.0), Vector3(31.84, 14.0, 30.0)],
]
const VIS_ZONE: Dictionary = {"A": "A_QUAY", "B": "B_CANNERY", "C": "C_WORKSHOP", "D": "D_PENHALL", "DH": "D_PENHALL",
	"E": "E_UBOAT", "F": "F_LOWERPENS", "G": "G_SIGNAL"}
## Where the camera stands -> what it can see (tested in order; outside every cell everything is drawn). The quay
## sees the cannery and the workshop through their doors and windows but not the hall (the 3 m bunker face has
## only window closets there); the cannery and the workshop see the hall through their pen passages; the boat's
## interior sees nothing outside but the hatch's column of the hall; the lower pens and the tower see the hall.
const VIEW_CELLS: Array = [
	["E_interior", Vector3(4.3, -2.7, 38.2), Vector3(9.7, 0.6, 85.9), ["E", "DH"], false],
	["E_hatch", Vector3(0.0, 0.6, 50.0), Vector3(14.0, 9.0, 74.0), ["A", "B", "C", "D", "DH", "E", "F", "G"], false],
	["F", Vector3(31.9, -6.5, 42.0), Vector3(52.1, -0.4, 84.7), ["F", "D", "DH", "G"], false],   # T-180: G seen up the pump stair
	["G", Vector3(42.1, 6.6, 33.1), Vector3(51.9, 11.0, 37.9), ["G", "D", "DH"], false],
	["passages", Vector3(-11.2, -0.5, 29.8), Vector3(45.2, 4.0, 33.2), ["A", "B", "C", "D", "DH", "F", "G"], false],
	["D", Vector3(-20.2, -6.5, 33.0), Vector3(52.2, 13.0, 100.0), ["D", "DH", "A", "B", "C", "F", "G"], false],
	["B", Vector3(-30.2, -1.0, -0.2), Vector3(0.0, 8.0, 29.85), ["B", "A", "C", "D", "DH"], true],
	["C", Vector3(32.0, -1.0, -0.2), Vector3(62.2, 8.0, 29.85), ["C", "A", "B", "D", "DH"], true],
	["A", Vector3(0.0, -1.0, -16.0), Vector3(32.0, 16.0, 29.85), ["A", "B", "C"], true],
]
const POWER_GAIN: float = 2.2
const LAMP_GAIN: float = 1.7

var map_root: Node3D
var geo: Node3D
var dress: Node3D
var gameplay: Node3D
var _count: int = 0
var _frames: int = 0
var _closets: Array = []
var _stairs: Array = []           # [axis ("z"/"x"), a0, a1 (across), low, high (along), y_low, y_high, tread, riser]
var _glow: Dictionary = {}
var _power: Array = []
var _static_lights: Array = []
var _spots: Array = []            # always-on spot lights (moon through the windows, sea light at the mouth)
var _decal_tex: Dictionary = {}
var _decals: Node3D
var _water: MeshInstance3D


func _initialize() -> void:
	map_root = Node3D.new()
	map_root.name = "Map02Totenhafen"
	get_root().add_child(map_root)
	geo = Node3D.new()
	geo.name = "Geometry"
	map_root.add_child(geo)
	dress = Node3D.new()
	dress.name = "Dressing"
	map_root.add_child(dress)
	build_quay()
	build_cannery()
	build_workshop()
	build_penhall()
	build_uboat()
	build_lowerpens()
	build_tower()
	build_closets()
	for ab: Array in AMMO_BOXES:   # the ammo boxes' footprints, so the navmesh is cut round them (hidden: NavBlock*)
		var ah: Vector3 = Vector3(0.52, 0, 0.3) if absf(float(ab[2])) != 90.0 else Vector3(0.3, 0, 0.52)
		box(geo, "NavBlock_Ammo_" + str(ab[0]), (ab[1] as Vector3) - ah, (ab[1] as Vector3) + ah + Vector3(0, 0.62, 0), "metal")
	var bp: Vector3 = ARMORERS_BENCH[0]   # the Armorer's Bench: 0.72 m out from the hut, 1.5 m along it
	box(geo, "NavBlock_ArmorersBench", bp + Vector3(-0.75, 0, 0), bp + Vector3(0.75, 0.9, 0.72), "metal")
	for sv: Array in STOVES:   # the coke stoves' footprints
		box(geo, "NavBlock_Stove_" + str(sv[0]), (sv[1] as Vector3) - Vector3(0.5, 0, 0.5), (sv[1] as Vector3) + Vector3(0.5, 1.1, 0.5), "metal")
	for br: Array in BRAZIERS:   # the fire barrels' footprints (dressed in build_dressing)
		box(geo, "NavBlock_Brazier_" + str(br[0]), (br[1] as Vector3) - Vector3(0.32, 0, 0.32), (br[1] as Vector3) + Vector3(0.32, 0.9, 0.32), "metal")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	bake_regions()
	get_root().remove_child(map_root)
	build_dressing()
	var merged: int = merge_static_meshes()
	print("merged %d static meshes into batches" % merged)
	_adopt_t273_batches()
	build_lights()
	build_gameplay()
	_prune(dress)
	_prune(geo)
	_tag_visibility(map_root)
	_add_view_cells()
	_own(map_root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(map_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://gravelight/maps/map02_totenhafen"))
		err = ResourceSaver.save(packed, OUT)
	print("Saved %s (%d boxes) err=%d" % [OUT, _count, err])
	map_root.free()
	return true


# ================================================================== helpers

func _mk(n: String, key: String) -> String:
	for r: Array in MAT_RULES:
		if n.match(str(r[0])):
			return str(r[1])
	return str(MAT_MAP.get(key, key))


func _hidden(n: String) -> bool:
	for p: String in HIDE:
		if n.match(p):
			return true
	return false


## Axis-aligned box from two corners. collide = a static collider on the "world" layer (navmesh source).
func box(parent: Node3D, n: String, a: Vector3, b: Vector3, mat_key: String, collide: bool = true) -> Node3D:
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var size: Vector3 = hi - lo
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	_count += 1
	Props.probe_geo(n, a, b, mat_key)   # (T-230: GL_PROBE_BOX names a piece seen in a render)
	var mi: MeshInstance3D = null
	if not _hidden(n):
		mi = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = Mats.get_mat(_mk(n, mat_key))
	if not collide:
		if mi == null:
			return null
		mi.name = n
		mi.position = (lo + hi) * 0.5
		parent.add_child(mi)
		return mi
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.position = (lo + hi) * 0.5
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if mi != null:
		body.add_child(mi)
	parent.add_child(body)
	return body


## Wall along X at depth z from x0..x1, y0..y1. openings: [[xa, xb, ya, yb], ...] (absolute y).
func wall_x(n: String, z: float, x0: float, x1: float, y0: float, y1: float, openings: Array, mk: String, lines: Array = []) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = x0
	var i: int = 0
	var rects: Array = []
	for o: Array in openings:
		box(geo, "%s_%d" % [n, i], Vector3(cur, y0, z - T * 0.5), Vector3(float(o[0]), y1, z + T * 0.5), mk)
		box(geo, "%s_%db" % [n, i], Vector3(float(o[0]), y0, z - T * 0.5), Vector3(float(o[1]), float(o[2]), z + T * 0.5), mk)
		box(geo, "%s_%dt" % [n, i], Vector3(float(o[0]), float(o[3]), z - T * 0.5), Vector3(float(o[1]), y1, z + T * 0.5), mk)
		rects.append([cur, float(o[0]), y0, y1])
		rects.append([float(o[0]), float(o[1]), y0, float(o[2])])
		rects.append([float(o[0]), float(o[1]), float(o[3]), y1])
		cur = float(o[1])
		i += 1
	box(geo, n + "_end", Vector3(cur, y0, z - T * 0.5), Vector3(x1, y1, z + T * 0.5), mk)
	rects.append([cur, x1, y0, y1])
	for l: Array in lines:
		for r: Array in rects:
			_line(true, z, int(l[0]), r, y0, l)


func wall_z(n: String, x: float, z0: float, z1: float, y0: float, y1: float, openings: Array, mk: String, lines: Array = []) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = z0
	var i: int = 0
	var rects: Array = []
	for o: Array in openings:
		box(geo, "%s_%d" % [n, i], Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, float(o[0])), mk)
		box(geo, "%s_%db" % [n, i], Vector3(x - T * 0.5, y0, float(o[0])), Vector3(x + T * 0.5, float(o[2]), float(o[1])), mk)
		box(geo, "%s_%dt" % [n, i], Vector3(x - T * 0.5, float(o[3]), float(o[0])), Vector3(x + T * 0.5, y1, float(o[1])), mk)
		rects.append([cur, float(o[0]), y0, y1])
		rects.append([float(o[0]), float(o[1]), y0, float(o[2])])
		rects.append([float(o[0]), float(o[1]), float(o[3]), y1])
		cur = float(o[1])
		i += 1
	box(geo, n + "_end", Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, z1), mk)
	rects.append([cur, z1, y0, y1])
	for l: Array in lines:
		for r: Array in rects:
			_line(false, x, int(l[0]), r, y0, l)


## One lining panel over a wall rect [a, b, ya, yb] on the face `side` of a wall centred on `plane`.
func _line(along_x: bool, plane: float, side: int, r: Array, y0: float, l: Array) -> void:
	var key: String = str(l[1])
	var h: float = float(l[2])
	var th: float = float(l[3])
	var ya: float = float(r[2])
	var yb: float = float(r[3])
	if h > 0.0:
		yb = minf(yb, y0 + h)
	if yb - ya < 0.02 or float(r[1]) - float(r[0]) < 0.02:
		return
	var face: float = plane + float(side) * T * 0.5
	var segs: Array = [[float(r[0]), float(r[1])]]
	for b: Array in BUYS:
		var p: Vector3 = b[1]
		var pf: float = p.z if along_x else p.x
		var pa: float = p.x if along_x else p.z
		if absf(pf - face) > 0.3 or p.y < ya - 0.8 or p.y > yb + 0.8:
			continue
		var nxt: Array = []
		for s: Array in segs:
			if pa + 0.9 <= float(s[0]) or pa - 0.9 >= float(s[1]):
				nxt.append(s)
				continue
			if pa - 0.9 > float(s[0]):
				nxt.append([float(s[0]), pa - 0.9])
			if pa + 0.9 < float(s[1]):
				nxt.append([pa + 0.9, float(s[1])])
		segs = nxt
	for s: Array in segs:
		if float(s[1]) - float(s[0]) < 0.02:
			continue
		if along_x:
			Props.block(dress, Vector3(float(s[0]), ya, face), Vector3(float(s[1]), yb, face + float(side) * th), key)
		else:
			Props.block(dress, Vector3(face, ya, float(s[0])), Vector3(face + float(side) * th, yb, float(s[1])), key)


## A thick slab along X (z0..z1 deep, x0..x1, y0..y1) with rectangular holes [xa, xb, ya, yb] through it
## (passages, window closets). Holes may overlap each other.
func slab_x(n: String, z0: float, z1: float, x0: float, x1: float, y0: float, y1: float, holes: Array, mk: String) -> void:
	var rects: Array = [[x0, x1, y0, y1]]
	for h: Array in holes:
		var nxt: Array = []
		for r: Array in rects:
			var rx0: float = float(r[0])
			var rx1: float = float(r[1])
			var ry0: float = float(r[2])
			var ry1: float = float(r[3])
			var hx0: float = float(h[0])
			var hx1: float = float(h[1])
			var hy0: float = float(h[2])
			var hy1: float = float(h[3])
			if hx1 <= rx0 or hx0 >= rx1 or hy1 <= ry0 or hy0 >= ry1:
				nxt.append(r)
				continue
			if hx0 > rx0:
				nxt.append([rx0, hx0, ry0, ry1])
			if hx1 < rx1:
				nxt.append([hx1, rx1, ry0, ry1])
			var mx0: float = maxf(rx0, hx0)
			var mx1: float = minf(rx1, hx1)
			if hy0 > ry0:
				nxt.append([mx0, mx1, ry0, hy0])
			if hy1 < ry1:
				nxt.append([mx0, mx1, hy1, ry1])
		rects = nxt
	var i: int = 0
	for r: Array in rects:
		box(geo, "%s_%d" % [n, i], Vector3(float(r[0]), float(r[2]), z0), Vector3(float(r[1]), float(r[3]), z1), mk)
		i += 1


func win(c: float, y: float) -> Array:
	return [c - 0.8, c + 0.8, y + SILL, y + WTOP]


func door(c: float, y: float, w: float = 2.0) -> Array:
	return [c - w * 0.5, c + w * 0.5, y, y + DOOR_H]


## Ramp along Z between two heights (top surface follows the line between the endpoints).
func ramp_z(n: String, x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float,
		treads: String = "", risers: String = "") -> void:
	var run: float = absf(z_high - z_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var dir: float = signf(z_high - z_low)
	var basis: Basis = Basis(Vector3.RIGHT, -atan2(rise, run) * dir)
	var mid: Vector3 = Vector3((x0 + x1) * 0.5, (y_low + y_high) * 0.5, (z_low + z_high) * 0.5)
	_ramp_body(n, basis, mid, Vector3(absf(x1 - x0), 0.2, length))
	if treads != "":
		_stairs.append(["z", x0, x1, z_low, z_high, y_low, y_high, treads, risers])


## Ramp along X between two heights.
func ramp_x(n: String, z0: float, z1: float, x_low: float, x_high: float, y_low: float, y_high: float,
		treads: String = "", risers: String = "") -> void:
	var run: float = absf(x_high - x_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var dir: float = signf(x_high - x_low)
	var basis: Basis = Basis(Vector3.BACK, atan2(rise, run) * dir)
	var mid: Vector3 = Vector3((x_low + x_high) * 0.5, (y_low + y_high) * 0.5, (z0 + z1) * 0.5)
	_ramp_body(n, basis, mid, Vector3(length, 0.2, absf(z1 - z0)))
	if treads != "":
		_stairs.append(["x", z0, z1, x_low, x_high, y_low, y_high, treads, risers])


func _ramp_body(n: String, basis: Basis, mid: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.collision_layer = 1
	body.transform = Transform3D(basis, mid - (basis * Vector3.UP) * 0.1)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if not _hidden(n):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = Mats.get_mat(_mk(n, "stairs"))
		body.add_child(mi)
	geo.add_child(body)
	_count += 1


## A closet behind a window so window zombies have floor to stand on (built last, in build_closets).
func closet(window_pos: Vector3, yaw_deg: float) -> void:
	_closets.append([window_pos, yaw_deg])


func build_closets() -> void:
	for c: Array in _closets:
		var p: Vector3 = c[0]
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(c[1])))
		var out_dir: Vector3 = basis * Vector3(0, 0, -1)
		var side: Vector3 = basis * Vector3(1, 0, 0)
		var center: Vector3 = p + out_dir * 1.5
		var half_side: Vector3 = side.abs() * 1.4
		var half_out: Vector3 = out_dir.abs() * 1.4
		var lo: Vector3 = center - half_side - half_out
		var hi: Vector3 = center + half_side + half_out
		box(geo, "ClosetFloor", Vector3(lo.x, p.y - 0.5, lo.z), Vector3(hi.x, p.y, hi.z), "rock")
		box(geo, "ClosetRoof", Vector3(lo.x, p.y + 3.0, lo.z), Vector3(hi.x, p.y + 3.3, hi.z), "rock")
		var back: Vector3 = p + out_dir * 2.9
		box(geo, "ClosetBack", back - half_side - out_dir.abs() * 0.15 + Vector3(0, p.y - back.y, 0),
			back + half_side + out_dir.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")
		for s: float in [-1.0, 1.0]:
			var sp: Vector3 = center + side * 1.4 * s
			box(geo, "ClosetSide", sp - half_out - side.abs() * 0.15 + Vector3(0, p.y - sp.y, 0),
				sp + half_out + side.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")


## A hidden railing collider (dressed later with posts and rails) from a to b, h high.
func rail(n: String, a: Vector3, b: Vector3, h: float = 1.05) -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x) - 0.05, a.y, minf(a.z, b.z) - 0.05)
	var hi: Vector3 = Vector3(maxf(a.x, b.x) + 0.05, a.y + h, maxf(a.z, b.z) + 0.05)
	box(geo, n, lo, hi, "rail")


func _own(n: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = map_root
		_own(c)


## Dressing shorthands.
func B(a: Vector3, b: Vector3, key: String, shadows: bool = true) -> MeshInstance3D:
	return Props.block(dress, a, b, key, shadows)


func OB(c: Vector3, size: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.obox(dress, c, size, key, rot)


func CYL(c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.cyl(dress, c, r, h, key, rot)


func _noshadow(mi: GeometryInstance3D) -> void:
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _label(text: String, pos: Vector3, yaw: float, size: int = 40, color: Color = Color(0.85, 0.82, 0.72, 0.85), parent: Node3D = null) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation.y = deg_to_rad(yaw)
	SurfaceText.apply(l)   # T-247: the surface look (period face, lit, toned down)
	(parent if parent != null else dress).add_child(l)


# ================================================================== A_QUAY (y = 0, outdoors)

func build_quay() -> void:
	# the harbour slab (quay, cannery and workshop floors in one), the shingle beyond the parapet, the sea bed
	box(geo, "Ground", Vector3(-34, -0.5, 0), Vector3(66, 0, 30), "ground")
	box(geo, "Shingle", Vector3(-40, -0.6, -14), Vector3(70, -0.1, 0), "shingle", false)
	box(geo, "SeaBedN", Vector3(-120, -9, -140), Vector3(160, -8.5, -14), "cliff", false)
	# parapet with the two sea-stair windows (landing stages behind them) and surf steps at both ends
	wall_x("Parapet", 0.0, 2.4, 29.6, 0, 1.1, [[9.2, 10.8, 0.9, 1.1], [23.2, 24.8, 0.9, 1.1]], "concrete")
	rail("Rail_SurfW", Vector3(0, 0, 0), Vector3(2.4, 0, 0), 1.0)
	rail("Rail_SurfE", Vector3(29.6, 0, 0), Vector3(32, 0, 0), 1.0)
	for sx: float in [10.0, 24.0]:
		box(geo, "Stage_%d" % int(sx), Vector3(sx - 1.6, -0.5, -3.2), Vector3(sx + 1.6, -0.05, 0), "planks")
		# kerb rails on the stage's three open sides (hidden colliders, dressed as posts and rope in
		# _dress_windows): the shingle and the sea bed have no colliders, so a zombie shoved off a stage by the
		# pack fell through them and out of the world (UPDATE 07 QA, test_map02_edges)
		rail("Rail_StageW_%d" % int(sx), Vector3(sx - 1.6, -0.05, -3.2), Vector3(sx - 1.6, -0.05, 0), 1.0)
		rail("Rail_StageE_%d" % int(sx), Vector3(sx + 1.6, -0.05, -3.2), Vector3(sx + 1.6, -0.05, 0), 1.0)
		rail("Rail_StageN_%d" % int(sx), Vector3(sx - 1.6, -0.05, -3.2), Vector3(sx + 1.6, -0.05, -3.2), 1.0)
	# the harbourmaster's hut (timber, flat roof), door on the east side
	wall_x("HutN", 10.0, 10 - T * 0.5, 18 + T * 0.5, 0, 3.2, [], "planks")
	wall_x("HutS", 17.0, 10 - T * 0.5, 18 + T * 0.5, 0, 3.2, [], "planks")
	wall_z("HutW", 10.0, 10, 17, 0, 3.2, [], "planks")
	wall_z("HutE", 18.0, 10, 17, 0, 3.2, [door(13.5, 0, 1.8)], "planks")
	box(geo, "HutRoof", Vector3(9.7, 3.2, 9.7), Vector3(18.3, 3.45, 17.3), "concrete")
	box(geo, "HutDesk", Vector3(10.3, 0, 15.2), Vector3(12.3, 0.8, 16.7), "furniture")
	# the beached cutter against the parapet's east end
	box(geo, "Cutter", Vector3(21, 0, 2), Vector3(30, 2.6, 8), "hull")
	# the bunker face (3 m thick) across the whole harbour front, with the two pen passages, the quay-window
	# closets, the hall chutes' closets and the signal tower's closets cut through it
	slab_x("MassFace", 30.0, 33.0, -30 - T * 0.5, 62 + T * 0.5, 0, ROOF, [
		[-17.55, -14.45, 0, 3.3], [-11, -9, 0, DOOR_H], [4.45, 7.55, 0, 3.3], [9.45, 12.55, 0, 3.3],
		[24.45, 27.55, 0, 3.3], [28.45, 31.55, 0, 3.3], [43, 45, 0, DOOR_H],
		[43.45, 46.55, TY - 0.5, TY + 3.3], [47.45, 50.55, TY - 0.5, TY + 3.3]], "concrete")
	box(geo, "MassAbove", Vector3(-34, ROOF, 30), Vector3(66, 30, 33), "concrete", false)
	box(geo, "MassRoof", Vector3(-23, ROOF + 0.6, 33), Vector3(55, 30, 84.6), "concrete", false)
	box(geo, "MassW", Vector3(-23, 0, 33), Vector3(-20, ROOF + 0.6, 84.6), "concrete", false)
	box(geo, "MassE", Vector3(52, 0, 33), Vector3(55, ROOF + 0.6, 84.6), "concrete", false)
	# window frames (sill, lintel, jambs) at the inner faces of the slab windows
	for wx: float in [6.0, 26.0]:
		_slab_window(wx, 30.0, -1, 0.0)
	for wx2: float in [-16.0, 11.0, 30.0]:
		_slab_window(wx2, 33.0, 1, 0.0)
	for wx3: float in [45.0, 49.0]:
		_slab_window(wx3, 33.0, 1, TY)
	closet(Vector3(6, 0, 30), 180.0)
	closet(Vector3(26, 0, 30), 180.0)
	closet(Vector3(-16, 0, 33), 0.0)
	closet(Vector3(11, 0, 33), 0.0)
	closet(Vector3(30, 0, 33), 0.0)
	closet(Vector3(45, TY, 33), 0.0)
	closet(Vector3(49, TY, 33), 0.0)
	# the cliffs either side of the harbour and the breakwater
	box(geo, "CliffW", Vector3(-110, -9, -60), Vector3(-30 - T, 46, 30), "cliff", false)
	box(geo, "CliffE", Vector3(62 + T, -9, -60), Vector3(150, 46, 30), "cliff", false)
	# the headland behind the harbour, kept off the bunker's faces (it was coplanar with the 3 m face and MassAbove and
	# z-fought them: the face read as the cliff's blue noise, U09 audit 4.1)
	box(geo, "CliffBack", Vector3(-110, -9, 30), Vector3(-34.2, 46, 33), "cliff", false)
	box(geo, "CliffBackE", Vector3(66.2, -9, 30), Vector3(150, 46, 33), "cliff", false)
	box(geo, "CliffBackTop", Vector3(-34.2, 30.2, 30), Vector3(66.2, 46, 33), "cliff", false)
	box(geo, "Breakwater", Vector3(-20, -3, -46), Vector3(90, 1.6, -42), "pier", false)


## Sill, lintel and jambs 0.3 m deep at the inner face of a window cut through the bunker slab. dir = +1 when
## the room lies on the +Z side of the face (the hall, the tower), -1 for the quay.
func _slab_window(x: float, z_face: float, dir: int, y: float) -> void:
	var z0: float = z_face - 0.3 if dir > 0 else z_face
	var z1: float = z_face if dir > 0 else z_face + 0.3
	box(geo, "SlabSill", Vector3(x - 1.55, y, z0), Vector3(x + 1.55, y + SILL, z1), "concrete")
	box(geo, "SlabTop", Vector3(x - 1.55, y + WTOP, z0), Vector3(x + 1.55, y + 3.3, z1), "concrete")
	box(geo, "SlabJambW", Vector3(x - 1.55, y + SILL, z0), Vector3(x - 0.8, y + WTOP, z1), "concrete")
	box(geo, "SlabJambE", Vector3(x + 0.8, y + SILL, z0), Vector3(x + 1.55, y + WTOP, z1), "concrete")


# ================================================================== B_CANNERY (y = 0)

func build_cannery() -> void:
	var lw: Array = [["limewash", 0.0, 0.012]]
	wall_x("CanN", 0.0, -30 - T * 0.5, 0 + T * 0.5, 0, 6.0, [win(-22, 0)], "concrete", [[1, "limewash", 0.0, 0.012]])
	wall_z("CanW", -30.0, 0, 30, 0, 6.0, [win(12, 0), win(24, 0)], "concrete", [[1, "limewash", 0.0, 0.012]])
	wall_z("CanE", 0.0, 0, 30, 0, 6.0, [door(15, 0)], "concrete", [[-1, "limewash", 0.0, 0.012]])
	box(geo, "CanneryRoof", Vector3(-30 - T * 0.5, 6.0, 0), Vector3(T * 0.5, 6.3, 30), "roof")
	# the infirmary partition (NW corner)
	wall_z("InfE", -20.0, 0, 10, 0, 3.2, [door(6, 0, 1.8)], "planks")
	wall_x("InfS", 10.0, -30, -20 + T * 0.5, 0, 3.2, [door(-25, 0, 1.8)], "planks")
	for cz: float in [1.2, 4.0, 6.8]:
		box(geo, "Cot%d" % int(cz), Vector3(-29.6, 0, cz), Vector3(-27.6, 0.55, cz + 2.0), "furniture")
	box(geo, "Stove1", Vector3(-22.6, 0, 8.4), Vector3(-21.6, 1.2, 9.4), "metal")
	box(geo, "NavBlock_SecondWind", Vector3(-27.0, 0, 0.3), Vector3(-25.0, 2.0, 1.4), "metal")
	# the lines, the conveyor, the tanks, the pallets
	box(geo, "GutLine1", Vector3(-22, 0, 13.3), Vector3(-6, 0.95, 14.7), "zinc")
	box(geo, "GutLine2", Vector3(-22, 0, 18.3), Vector3(-6, 0.95, 19.7), "zinc")
	box(geo, "Conveyor", Vector3(-18, 0, 4.0), Vector3(-2, 1.0, 5.6), "metal")
	box(geo, "Brine1", Vector3(-28.5, 0, 22.5), Vector3(-25.5, 1.5, 25.5), "metal")
	box(geo, "Brine2", Vector3(-24.5, 0, 22.5), Vector3(-21.5, 1.5, 25.5), "metal")
	box(geo, "Pallet_Cans1", Vector3(-14, 0, 25), Vector3(-11, 1.2, 27.5), "furniture")
	box(geo, "Pallet_Cans2", Vector3(-9, 0, 25), Vector3(-6, 1.0, 27.5), "furniture")
	box(geo, "NavBlock_Marathon", Vector3(-6.0, 0, 28.6), Vector3(-4.0, 2.0, 29.9), "metal")
	closet(Vector3(-22, 0, 0), 0.0)
	closet(Vector3(-30, 0, 12), 90.0)
	closet(Vector3(-30, 0, 24), 90.0)


# ================================================================== C_WORKSHOP (y = 0)

func build_workshop() -> void:
	var lin: Array = [[1, "paint_cream", 0.0, 0.012], [1, "paint_green", 1.5, 0.02]]
	wall_x("WsN", 0.0, 32 - T * 0.5, 62 + T * 0.5, 0, 7.0, [win(47, 0)], "concrete", lin.duplicate(true))
	wall_z("WsE", 62.0, 0, 30, 0, 7.0, [win(10, 0), win(22, 0)], "concrete", [[-1, "paint_cream", 0.0, 0.012], [-1, "paint_green", 1.5, 0.02]])
	wall_z("WsW", 32.0, 0, 30, 0, 7.0, [door(15, 0)], "concrete", lin.duplicate(true))
	box(geo, "WorkshopRoof", Vector3(32 - T * 0.5, 7.0, 0), Vector3(62 + T * 0.5, 7.3, 30), "roof")
	for c: Array in [[36.0, 7.6, 1], [46.0, 7.6, 2], [36.0, 13.6, 3], [46.0, 13.6, 4]]:
		box(geo, "Cradle%d" % int(c[2]), Vector3(float(c[0]), 0, float(c[1])), Vector3(float(c[0]) + 7.0, 1.3, float(c[1]) + 1.8), "grey")
	box(geo, "Lathe", Vector3(56, 0, 5), Vector3(60, 1.3, 7), "metal")
	# the warhead store: a mesh cage in the SE corner (bars are dressing; the colliders are these walls)
	wall_z("CageW", 52.0, 16, 24, 0, 2.5, [[19.0, 21.0, 0.0, 2.4]], "metal")
	wall_x("CageN", 16.0, 52 - T * 0.5, 62, 0, 2.5, [], "metal")
	box(geo, "NavBlock_Coffin_WS", Vector3(54.9, 0, 21.9), Vector3(57.1, 0.8, 23.1), "lead")
	box(geo, "NavBlock_Coffin_WS2", Vector3(59.4, 0, 22.4), Vector3(61.6, 0.8, 23.6), "lead")
	box(geo, "NavBlock_Ironhide", Vector3(32.2, 0, 7.0), Vector3(33.4, 2.0, 9.0), "metal")
	box(geo, "NavBlock_Trigger", Vector3(39.0, 0, 0.2), Vector3(41.0, 2.0, 1.4), "metal")
	closet(Vector3(47, 0, 0), 0.0)
	closet(Vector3(62, 0, 10), -90.0)
	closet(Vector3(62, 0, 22), -90.0)


# ================================================================== D_PENHALL (piers y 0, catwalks +4)

func build_penhall() -> void:
	wall_z("HallW", -20.0, 33, 84, 0, ROOF, [], "concrete")
	wall_z("HallE", 52.0, 33, 84, BY, ROOF, [], "concrete")
	box(geo, "HallRoof", Vector3(-20 - T * 0.5, ROOF, 33), Vector3(52 + T * 0.5, ROOF + 0.6, 84), "roof")
	box(geo, "Curtain", Vector3(-20, 2.2, 84), Vector3(52, ROOF, 84.6), "metal")
	# floors: the north apron, three piers, the east apron (a slab over the lower pens), the basins
	box(geo, "ApronN", Vector3(-20, -0.5, 33), Vector3(52, 0, 38), "ground")
	box(geo, "PassageW", Vector3(-11, -0.5, 30), Vector3(-9, 0, 33), "ground")
	box(geo, "PassageE", Vector3(43, -0.5, 30), Vector3(45, 0, 33), "ground")
	box(geo, "Pier0", Vector3(-20, BY, 38), Vector3(-14, 0, 84), "pier")
	box(geo, "Pier1", Vector3(-6, BY, 38), Vector3(0, 0, 84), "pier")
	box(geo, "Pier2", Vector3(14, BY, 38), Vector3(20, 0, 84), "pier")
	box(geo, "ApronE", Vector3(32, -0.3, 50), Vector3(52, 0, 84), "ground")
	box(geo, "ApronE2", Vector3(32, BY, 38), Vector3(46, 0, 50), "pier")
	box(geo, "ApronE3", Vector3(46, BY, 38), Vector3(52, 0, 42), "pier")
	box(geo, "PensBase", Vector3(32, BY, 50), Vector3(52, LY - 0.5, 84), "pier")
	box(geo, "Basin1", Vector3(-14, BY - 0.5, 38), Vector3(-6, BY, 96), "pier")
	box(geo, "Basin2", Vector3(0, BY - 0.5, 38), Vector3(14, BY, 96), "pier")
	box(geo, "Basin3", Vector3(20, BY - 0.5, 38), Vector3(32, BY, 96), "pier")
	box(geo, "SeaBedS", Vector3(-30, -8.5, 84), Vector3(62, -8, 150), "cliff", false)
	# the pump stair: a landing in the apron, the flight down, the pit's walls
	box(geo, "StairTop", Vector3(46, -0.5, 42), Vector3(52, 0, 44), "ground")
	ramp_z("PumpStair", 46.0, 52.0, 44.0, 50.0, 0.0, LY, "concrete", "concrete")
	box(geo, "StairBase", Vector3(46, BY, 44), Vector3(52, LY - 0.5, 50), "pier")
	box(geo, "StairW", Vector3(45.7, LY, 42), Vector3(46, 2.4, 50), "concrete")
	box(geo, "StairS", Vector3(46, -0.3, 50), Vector3(52, 1.1, 50.3), "concrete")
	# catwalks (+4) along the west, north and east walls, their stairs, and the ramp up to the tower
	box(geo, "CatwalkW", Vector3(-20, CATY - 0.2, 33), Vector3(-18, CATY, 84), "deck")
	box(geo, "CatwalkN", Vector3(-20, CATY - 0.2, 33), Vector3(52, CATY, 35), "deck")
	box(geo, "CatwalkE", Vector3(50, CATY - 0.2, 33), Vector3(52, CATY, 84), "deck")
	ramp_z("StairNW", -18.0, -16.0, 46.0, 38.0, 0.0, CATY, "steel_grate", "iron")
	box(geo, "CatwalkNWTop", Vector3(-18, CATY - 0.2, 36), Vector3(-16, CATY, 38), "deck")
	ramp_z("StairE", 48.0, 50.0, 60.0, 68.0, 0.0, CATY, "steel_grate", "iron")
	box(geo, "CatwalkETop", Vector3(48, CATY - 0.2, 68), Vector3(50, CATY, 70), "deck")
	box(geo, "CatwalkN2", Vector3(27, CATY - 0.2, 35), Vector3(50, CATY, 37), "deck")
	ramp_x("TowerRamp", 33.0, 35.0, 29.0, 41.0, CATY, TY, "concrete", "concrete")
	# railings (hidden colliders, dressed): pier edges, apron edges, the north apron over the docks, catwalks
	rail("Rail_P0E", Vector3(-14, 0, 38), Vector3(-14, 0, 84))
	rail("Rail_P0S", Vector3(-20, 0, 84), Vector3(-14, 0, 84))
	rail("Rail_P1W", Vector3(-6, 0, 38), Vector3(-6, 0, 84))
	rail("Rail_P1E", Vector3(0, 0, 38), Vector3(0, 0, 84))
	rail("Rail_P1S", Vector3(-6, 0, 84), Vector3(0, 0, 84))
	rail("Rail_P2W1", Vector3(14, 0, 38), Vector3(14, 0, 57))
	rail("Rail_P2W2", Vector3(14, 0, 59), Vector3(14, 0, 84))
	rail("Rail_P2E", Vector3(20, 0, 38), Vector3(20, 0, 84))
	rail("Rail_P2S", Vector3(14, 0, 84), Vector3(20, 0, 84))
	rail("Rail_AEW", Vector3(32, 0, 38), Vector3(32, 0, 84))
	rail("Rail_AES", Vector3(32, 0, 84), Vector3(52, 0, 84))
	rail("Rail_N1", Vector3(-14, 0, 38), Vector3(-6, 0, 38))
	rail("Rail_N2", Vector3(0, 0, 38), Vector3(14, 0, 38))
	rail("Rail_N3", Vector3(20, 0, 38), Vector3(32, 0, 38))
	rail("Rail_CW1", Vector3(-18, CATY, 35), Vector3(-18, CATY, 36))
	rail("Rail_CW2", Vector3(-18, CATY, 38), Vector3(-18, CATY, 84))
	rail("Rail_CWS", Vector3(-20, CATY, 84), Vector3(-18, CATY, 84))
	rail("Rail_CN1", Vector3(-18, CATY, 35), Vector3(27, CATY, 35))
	rail("Rail_CNW", Vector3(27, CATY, 35), Vector3(27, CATY, 37))
	rail("Rail_CN1b", Vector3(27, CATY, 37), Vector3(50, CATY, 37))
	rail("Rail_CE1", Vector3(50, CATY, 37), Vector3(50, CATY, 68))
	rail("Rail_CE2", Vector3(50, CATY, 70), Vector3(50, CATY, 84))
	rail("Rail_CES", Vector3(50, CATY, 84), Vector3(52, CATY, 84))
	rail("Rail_StairNW", Vector3(-16, 0, 36), Vector3(-16, 0, 46), 5.2)
	rail("Rail_StairNWN", Vector3(-18, CATY, 36), Vector3(-16, CATY, 36))
	rail("Rail_StairE", Vector3(48, 0, 60), Vector3(48, 0, 70), 5.2)
	rail("Rail_StairES", Vector3(48, CATY, 70), Vector3(50, CATY, 70))
	rail("Rail_TR", Vector3(29, CATY, 35), Vector3(41, CATY, 35), 4.0)
	# the gangway from pier 2 up onto the boat's deck
	ramp_x("Gangway", 57.0, 59.0, 14.0, 10.0, 0.0, DECK)
	rail("Rail_GW1", Vector3(10, 0, 57), Vector3(14, 0, 57), 2.2)
	rail("Rail_GW2", Vector3(10, 0, 59), Vector3(14, 0, 59), 2.2)
	# the crane bay: gantry legs, the crane office, coffin pallets; lockers for the pier wall-buys
	for lz: float in [55.5, 63.7]:
		box(geo, "CraneLeg_W%d" % int(lz), Vector3(19.2, 0, lz), Vector3(20, 9.5, lz + 0.8), "metal")
		box(geo, "CraneLeg_E%d" % int(lz), Vector3(50.4, 0, lz), Vector3(51.2, 9.5, lz + 0.8), "metal")
	box(geo, "CraneOffice", Vector3(44, 0, 52), Vector3(50, 3.0, 57), "planks")
	for c: Array in [[36.5, 40.0], [38.6, 40.0], [36.5, 42.4], [50.0, 70.0]]:
		box(geo, "Pallet_Coffin", Vector3(float(c[0]) - 1.1, 0, float(c[1]) - 0.5), Vector3(float(c[0]) + 1.1, 0.8, float(c[1]) + 0.5), "lead")
	box(geo, "Locker1", Vector3(-5.9, 0, 69), Vector3(-4.9, 2.2, 71), "metal")
	box(geo, "Locker2", Vector3(19.0, 0, 49), Vector3(20.0, 2.2, 51), "metal")
	box(geo, "NavBlock_CrateP0", Vector3(-19.4, 0, 80.4), Vector3(-17.6, 1.0, 81.6), "metal")
	for ppx: float in [-17.0, -3.0, 17.0, 46.0]:
		for ppz: float in [50.0, 64.0, 78.0]:
			box(geo, "NavBlock_Pole", Vector3(ppx - 0.12, 0, ppz - 0.12), Vector3(ppx + 0.12, 2.0, ppz + 0.12), "metal")


# ================================================================== E_UBOAT (interior y -2, deck +1)

func build_uboat() -> void:
	var z0: float = 38.0
	var z1: float = 86.0
	box(geo, "HullKeel", Vector3(4.6, -5.6, z0), Vector3(9.4, SY - 0.5, z1), "hull")
	box(geo, "HullFloor", Vector3(4, SY - 0.5, z0), Vector3(10, SY, z1), "hull_in")
	box(geo, "HullSideW", Vector3(4, SY, z0), Vector3(4.4, DECK + 1.2, z1), "hull")
	box(geo, "HullSideE1", Vector3(9.6, SY, z0), Vector3(10, DECK + 1.2, 57), "hull")
	box(geo, "HullSideE2", Vector3(9.6, SY, 59), Vector3(10, DECK + 1.2, z1), "hull")
	box(geo, "HullSideE3", Vector3(9.6, SY, 57), Vector3(10, DECK, 59), "hull")
	box(geo, "HullDeck1", Vector3(4, 0.6, z0), Vector3(10, DECK, 61), "deck")
	box(geo, "HullDeck2", Vector3(4, 0.6, 61), Vector3(5, DECK, 66), "deck")
	box(geo, "HullDeck3", Vector3(7, 0.6, 61), Vector3(10, DECK, 66), "deck")
	# T-229: the deck aft is cut round the engine room's escape hatch (x 6.55..7.45, z 82.4..83.3) over its ladder (the
	# deck aft of z 84 is under the pen's curtain: no standing room there)
	for seg: Array in [[Vector3(4, 0.6, 66), Vector3(6.55, DECK, z1)], [Vector3(7.45, 0.6, 66), Vector3(10, DECK, z1)],
			[Vector3(6.55, 0.6, 66), Vector3(7.45, DECK, 82.4)], [Vector3(6.55, 0.6, 83.3), Vector3(7.45, DECK, z1)]]:
		box(geo, "HullDeck4", seg[0], seg[1], "deck")
	box(geo, "BowCap", Vector3(4, SY - 0.5, z0 - 0.6), Vector3(10, DECK + 1.2, z0), "hull")
	box(geo, "SternCap", Vector3(4, SY - 0.5, z1), Vector3(10, DECK + 1.2, z1 + 0.6), "hull")
	# the conning tower over the hatch, with its door to the deck on the gangway side
	box(geo, "CT_Body", Vector3(4.4, DECK, 52), Vector3(7.4, DECK + 2.6, 58), "hull")
	# the companionway down from the open hatch aft of the tower (a ramp; the deck is cut at x 5..7, z 61..66)
	ramp_z("HatchRamp", 5.0, 7.0, 61.0, 66.0, DECK, SY, "steel_grate", "iron")
	geo.get_node("HatchRamp").set_meta("vis", "DH")   # T-180: seen from the hall through the hatch as well as from inside
	rail("Rail_HatchW", Vector3(5, SY, 61), Vector3(5, SY, 66), 4.0)
	rail("Rail_HatchE", Vector3(7, SY, 61), Vector3(7, SY, 66), 4.0)
	# bulkheads with their oval doors, the diesels aft
	wall_x("Bulkhead1", 50.0, 4.4, 9.6, SY, 0.6, [door(7, SY, 1.8)], "hull_in")
	wall_x("Bulkhead2", 56.0, 4.4, 9.6, SY, 0.6, [door(7, SY, 1.8)], "hull_in")
	wall_x("Bulkhead3", 68.0, 4.4, 9.6, SY, 0.6, [door(7, SY, 1.8)], "hull_in")
	box(geo, "Diesel1", Vector3(4.4, SY, 70), Vector3(5.6, SY + 1.6, 82), "metal")
	box(geo, "Diesel2", Vector3(8.4, SY, 70), Vector3(9.6, SY + 1.6, 82), "metal")
	box(geo, "NavBlock_Crucible", Vector3(6.0, SY, 38.6), Vector3(8.0, SY + 1.6, 40.9), "metal")   # T-180: 2.4 left an island on its lid
	for bz: float in [51.0, 53.4]:
		box(geo, "Bunk%d" % int(bz), Vector3(4.4, SY, bz), Vector3(5.3, SY + 1.5, bz + 2.0), "furniture")


# ================================================================== F_LOWERPENS (y -3, floods)

func build_lowerpens() -> void:
	box(geo, "PensFloor", Vector3(32, LY - 0.5, 50), Vector3(52, LY, 84), "ground")
	box(geo, "PensN", Vector3(32, LY - 0.5, 50), Vector3(46, -0.3, 50.3), "concrete")
	for cx: float in [38.0, 46.0]:
		for cz: float in [58.0, 66.0, 74.0]:
			box(geo, "Column", Vector3(cx - 0.4, LY, cz - 0.4), Vector3(cx + 0.4, -0.3, cz + 0.4), "concrete")
	box(geo, "Pump1", Vector3(35, LY, 74), Vector3(39, LY + 1.8, 82), "metal")
	box(geo, "Pump2", Vector3(45, LY, 74), Vector3(49, LY + 1.8, 82), "metal")
	box(geo, "SwitchDais", Vector3(50.5, LY, 68.5), Vector3(52, LY + 0.3, 71.5), "metal")
	box(geo, "Desk1", Vector3(50, LY, 62), Vector3(51.9, LY + 0.8, 64), "furniture")
	box(geo, "NavBlock_CratePumps", Vector3(41.1, LY, 78.4), Vector3(42.9, LY + 1.0, 79.6), "metal")
	rail("Rail_PensW", Vector3(32, LY, 50), Vector3(32, LY, 84))
	box(geo, "SeaGrille", Vector3(32, BY, 84), Vector3(52, -0.3, 84.3), "rust")


# ================================================================== G_SIGNAL (y +7)

func build_tower() -> void:
	box(geo, "TowerFloor", Vector3(41, TY - 0.3, 33), Vector3(52, TY, 38), "concrete")
	wall_z("TowerW", 42.0, 33, 38, TY, TY + 4.0, [door(34, TY)], "concrete", [[-1, "paint_cream", 0.0, 0.012]])
	# T-273: the south window is shorter now (x 44..46.8) and a door beside it (x 47.6..49.6) gives onto the signal
	# balcony over the hall, where the zip line leaves from (SIGNAL_ZIP)
	wall_x("TowerS", 38.0, 42 - T * 0.5, 52 + T * 0.5, TY, TY + 4.0, [[44.0, 46.8, TY + 0.9, TY + 2.6], [BALC_DOOR_X0, BALC_DOOR_X1, TY, TY + DOOR_H]],
		"concrete", [[-1, "paint_cream", 0.0, 0.012]])
	box(geo, "TowerGlass", Vector3(44, TY + 0.9, 37.9), Vector3(46.8, TY + 2.6, 38.1), "glass")
	box(geo, "BalconyFloor", Vector3(BALC_X0, TY - 0.2, 38.15), Vector3(BALC_X1, TY, BALC_Z1), "deck")
	rail("Rail_BalconyW", Vector3(BALC_X0, TY, 38.15), Vector3(BALC_X0, TY, BALC_Z1))
	rail("Rail_BalconyE", Vector3(BALC_X1, TY, 38.15), Vector3(BALC_X1, TY, BALC_Z1))
	rail("Rail_BalconyS", Vector3(BALC_X0, TY, BALC_Z1), Vector3(BALC_X1, TY, BALC_Z1))
	var zp: Vector3 = SIGNAL_ZIP[2]
	box(geo, "ZipPost_SignalZip", zp + Vector3(-0.12, 0, -0.12), zp + Vector3(0.12, ZIP_POST_H + 0.15, 0.12), "metal")
	box(geo, "TowerRoof", Vector3(41, TY + 4.0, 33), Vector3(52 + T * 0.5, TY + 4.3, 38 + T * 0.5), "concrete")
	box(geo, "Teletype", Vector3(50.6, TY, 34.0), Vector3(51.8, TY + 1.0, 35.5), "metal")
	box(geo, "Rack1", Vector3(50.6, TY, 37.0), Vector3(51.9, TY + 2.2, 37.8), "metal")
	box(geo, "NavBlock_Overclock", Vector3(42.3, TY, 35.8), Vector3(43.5, TY + 2.0, 37.6), "metal")
	box(geo, "NavBlock_Hawkeye", Vector3(50.8, TY, 35.6), Vector3(52, TY + 2.0, 37.0), "metal")
	# T-141: Ledger Lager (on the crane office's south wall) and the Marinekasse's counter, teller and safe (bank.json)
	box(geo, "NavBlock_Ledger", Vector3(43.1, 0, 55.5), Vector3(44.0, 1.6, 56.7), "metal")
	var bnk: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/bank.json")) as Dictionary).get("branches", {}).get("map02", {})
	if bnk.has("nav_block"):
		var nb: Array = bnk["nav_block"]
		box(geo, "NavBlock_Bank", Vector3(float(nb[0][0]), float(nb[0][1]), float(nb[0][2])), Vector3(float(nb[1][0]), float(nb[1][1]), float(nb[1][2])), "metal")


# ================================================================== navigation

func bake_regions() -> void:
	var nav_holder: Node3D = Node3D.new()
	nav_holder.name = "Navigation"
	map_root.add_child(nav_holder)
	var base: NavigationMesh = _navmesh()
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(base, src, geo)
	var i: int = 0
	for zb: Array in ZONE_BOXES:
		var nm: NavigationMesh = _navmesh()
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		nm.filter_baking_aabb = AABB(lo, hi - lo)
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		var r: NavigationRegion3D = NavigationRegion3D.new()
		r.name = "Nav_%s_%d" % [zb[0], i]
		r.navigation_mesh = nm
		r.navigation_layers = 1 << (int(ZONE_BITS[zb[0]]) - 1)
		nav_holder.add_child(r)
		print("  %-14s box %d: %d polys" % [zb[0], i, nm.get_polygon_count()])
		i += 1
	var li: int = 0
	for l: Array in LINKS:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = "Link_%d_%s" % [li, l[2]]
		link.start_position = l[0]
		link.end_position = l[1]
		link.bidirectional = true
		link.navigation_layers = 1 << (int(ZONE_BITS[l[2]]) - 1)
		nav_holder.add_child(link)
		li += 1


func _navmesh() -> NavigationMesh:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 42.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	return nm


# ================================================================== lighting fixtures

func G(zone: String) -> Node3D:
	if not _glow.has(zone):
		var h: Node3D = Node3D.new()
		h.name = "PowerGlow_" + zone
		h.set_meta("keep", true)
		dress.add_child(h)
		_glow[zone] = h
	return _glow[zone]


func power(zone: String, pos: Vector3, range_: float, energy: float, color: Color = SODIUM, shadow: bool = false,
		spot: Dictionary = {}) -> void:
	_power.append({"zone": zone, "pos": pos, "range": range_, "energy": energy, "color": color, "shadow": shadow, "spot": spot})


func lamp(pos: Vector3, color: Color, energy: float, range_: float, flicker: float = 0.0, fog: float = 0.0, shadow: bool = false,
		speed: float = 9.0) -> void:
	_static_lights.append({"pos": pos, "color": color, "energy": energy, "range": range_, "flicker": flicker, "fog": fog,
		"shadow": shadow, "speed": speed})


## An always-on spot light from `pos` aimed at `aim` (moonlight through a window, the sea's light under the
## curtain). Shadowed spots are what shape a shaft through the volumetric fog, so keep them few.
func shaft(n: String, pos: Vector3, aim: Vector3, color: Color, energy: float, range_: float, angle: float,
		fog: float = 1.5, shadow: bool = true) -> void:
	_spots.append({"name": n, "pos": pos, "aim": aim, "color": color, "energy": energy, "range": range_, "angle": angle,
		"fog": fog, "shadow": shadow})


## Moonlight in through a window: a cold shadowed spot up in the window's closet (outside the room) aimed down
## through the opening onto the floor inside, so the boards and the frame cut the shaft.
func moon_window(id: String, energy: float = 1.0) -> void:
	for w: Array in WINDOWS:
		if str(w[0]) != id:
			continue
		var p: Vector3 = w[2]
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		shaft("MoonShaft_" + id, p - inward * 2.5 + Vector3(0, 2.75, 0), p + inward * 3.6, MOONLIGHT, 10.0 * energy, 14.0, 28.0, 3.0)


## A fire barrel: a rusted drum with a coal fire in it, flames, embers and a flickering warm light. The
## footprint's collider is a hidden NavBlock box added in _initialize (BRAZIERS), so the navmesh goes round it.
func brazier(p: Vector3) -> void:
	Props.cyl(dress, p + Vector3(0, 0.42, 0), 0.3, 0.84, "rust")
	for h: float in [0.25, 0.6]:
		Props.cyl(dress, p + Vector3(0, h, 0), 0.31, 0.03, "iron")
	_noshadow(Props.cyl(dress, p + Vector3(0, 0.8, 0), 0.27, 0.06, "ember"))
	Props.flames(dress, p + Vector3(0, 0.84, 0), 0.45, 0.7, 26)
	Props.embers(dress, p + Vector3(0, 1.0, 0), 0.2, 8)
	lamp(p + Vector3(0, 1.35, 0), FIRE, 1.6, 9.0, 0.22, 0.6, false, 7.0)


## A cast-iron coke stove with its fire door ajar (local -Z faces the room), a flue to the roof and a warm,
## flickering light that spills out of the door onto the floor.
func stove(p: Vector3, yaw: float, flue_top: float) -> void:
	var g: Node3D = Props.group(dress, "CokeStove", p, yaw)
	Props.block(g, Vector3(-0.42, 0.0, -0.42), Vector3(0.42, 0.95, 0.42), "iron")
	Props.block(g, Vector3(-0.46, 0.95, -0.46), Vector3(0.46, 1.02, 0.46), "rust")
	_noshadow(Props.block(g, Vector3(-0.22, 0.2, -0.44), Vector3(0.22, 0.52, -0.42), "ember", false))
	Props.block(g, Vector3(0.22, 0.2, -0.75), Vector3(0.25, 0.52, -0.44), "iron")
	Props.cyl(g, Vector3(0, (flue_top + 1.02) * 0.5, 0.1), 0.09, flue_top - 1.02, "iron")
	var out: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -0.9)
	lamp(p + out + Vector3(0, 0.45, 0), FIRE, 1.8, 9.0, 0.18, 0.4, false, 5.0)


## Hanging lamp: cord, enamel shade, bulb. The lit bulb belongs to the zone's power holder.
func pendant(zone: String, p: Vector3, ceil_y: float, shade: String = "enamel_green", s: float = 1.0, glow_key: String = "bulb_warm") -> void:
	_noshadow(B(p + Vector3(-0.012, 0.2 * s, -0.012), Vector3(p.x + 0.012, ceil_y, p.z + 0.012), "iron", false))
	Props.cone(dress, p + Vector3(0, 0.12 * s, 0), 0.3 * s, 0.22 * s, shade)
	_noshadow(Props.ball(dress, p, Vector3(0.12, 0.15, 0.12) * s, "bulb_off"))
	_noshadow(Props.ball(G(zone), p, Vector3(0.14, 0.17, 0.14) * s, glow_key))


## Caged bulkhead lamp on a wall (local -Z faces the room), lit with the zone's power.
func bulkhead(zone: String, p: Vector3, yaw: float, glow_key: String = "bulb_warm") -> void:
	Props.bulkhead_lamp(dress, p, yaw)
	if zone == "":
		return
	var gg: Node3D = Props.group(G(zone), "BulkheadGlow", p, yaw)
	_noshadow(Props.cyl(gg, Vector3(0, 0, -0.1), 0.1, 0.15, glow_key, Vector3(90, 0, 0)))


## Emergency lamp: a red caged lamp that is always lit, with its own light.
func emergency(p: Vector3, yaw: float, energy: float = 0.9, range_: float = 9.0, flick: float = 0.12) -> void:
	Props.bulkhead_lamp(dress, p, yaw, "emergency_red")
	var out: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -0.5)
	lamp(p + out, RED, energy * 1.3, range_ + 2.0, flick, 0.3, false, 3.0)


## Floodlight on a bracket aimed at `aim`; lens glow and a cold spot come on with the zone's power.
func flood(zone: String, p: Vector3, aim: Vector3, spot_range: float = 30.0, spot_energy: float = 5.0, angle: float = 38.0,
		color: Color = MERCURY, key_shadow: bool = false) -> void:
	var dir: Vector3 = (aim - p).normalized()
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
	var basis: Basis = Basis.looking_at(dir, up)
	var g: Node3D = Node3D.new()
	g.name = "Flood"
	g.transform = Transform3D(basis, p)
	dress.add_child(g)
	Props.block(g, Vector3(-0.32, -0.25, -0.05), Vector3(0.32, 0.25, 0.45), "machine_grey")
	Props.block(g, Vector3(-0.36, -0.29, -0.1), Vector3(0.36, 0.29, -0.04), "iron")
	_noshadow(Props.block(g, Vector3(-0.28, -0.21, -0.07), Vector3(0.28, 0.21, -0.05), "bulb_off"))
	var gg: Node3D = Node3D.new()
	gg.transform = g.transform
	G(zone).add_child(gg)
	_noshadow(Props.block(gg, Vector3(-0.29, -0.22, -0.085), Vector3(0.29, 0.22, -0.06), "flood_glass"))
	power(zone, p + dir * 0.9, 4.0, 0.15, color, false, {"dir": dir, "range": spot_range, "energy": spot_energy, "angle": angle, "color": color, "shadow": key_shadow})


## Flat radial stain projected downward.
func decal(pos: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	if _decals == null:
		_decals = Node3D.new()
		_decals.name = "Decals"
		map_root.add_child(_decals)
	var key: String = color.to_html()
	if not _decal_tex.has(key):
		var t: GradientTexture2D = GradientTexture2D.new()
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([color, Color(color.r, color.g, color.b, color.a * 0.75), Color(color.r, color.g, color.b, 0.0)])
		t.gradient = g
		_decal_tex[key] = t
	var d: Decal = Decal.new()
	d.size = size
	d.position = pos
	d.rotation.y = deg_to_rad(yaw)
	d.texture_albedo = _decal_tex[key]
	d.cull_mask = 1
	_decals.add_child(d)


## A Node3D whose children spin (pump flywheels, the signal lamp). Excluded from the global batches.
func spinner(parent: Node3D, n: String, pos: Vector3, axis: Vector3, speed: float, needs_power: bool) -> Node3D:
	var s: Node3D = Node3D.new()
	s.set_script(load(SPINNER))
	s.name = n
	s.position = pos
	s.set("axis", axis)
	s.set("speed", speed)
	s.set("needs_power", needs_power)
	s.set_meta("keep", true)
	parent.add_child(s)
	return s


## Dockside pole lamp: an iron post with a bracket and an enamel shade; the bulb is lit with the zone's power.
func _pole_lamp(zone: String, p: Vector3) -> void:
	B(p + Vector3(-0.08, 0, -0.08), p + Vector3(0.08, 4.2, 0.08), "iron")
	B(p + Vector3(-0.2, 0, -0.2), p + Vector3(0.2, 0.12, 0.2), "iron")
	Props.strut(dress, p + Vector3(0, 4.1, 0), p + Vector3(0.9, 4.4, 0), 0.07, "iron", true)
	Props.cone(dress, p + Vector3(0.9, 4.28, 0), 0.36, 0.26, "enamel_green")
	CYL(p + Vector3(0.9, 4.44, 0), 0.06, 0.08, "iron")   # T-145: the fixture's cap, a wire cage round the bulb
	for a: float in [0.0, 90.0, 180.0, 270.0]:
		var o: Vector3 = Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 0.13
		Props.strut(dress, p + Vector3(0.9, 4.18, 0) + o, p + Vector3(0.9, 3.98, 0) + o * 0.4, 0.012, "iron", true)
	CYL(p + Vector3(0.9, 4.18, 0), 0.14, 0.02, "iron")
	_noshadow(Props.ball(dress, p + Vector3(0.9, 4.12, 0), Vector3(0.14, 0.16, 0.14), "bulb_off"))
	_noshadow(Props.ball(G(zone), p + Vector3(0.9, 4.12, 0), Vector3(0.16, 0.18, 0.16), "bulb_warm"))
	power(zone, p + Vector3(0.9, 3.9, 0), 13.0, 1.1, SODIUM)


## A hurricane lantern standing at p (base), with its own small warm light.
func _hurricane(p: Vector3) -> void:
	Props.cyl(dress, p + Vector3(0, 0.03, 0), 0.07, 0.06, "rust")
	_noshadow(Props.ball(dress, p + Vector3(0, 0.15, 0), Vector3(0.11, 0.16, 0.11), "lantern_glass"))
	for a: float in [0.0, 120.0, 240.0]:
		var o: Vector3 = Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 0.065
		Props.strut(dress, p + o + Vector3(0, 0.05, 0), p + o + Vector3(0, 0.26, 0), 0.01, "rust")
	Props.cyl(dress, p + Vector3(0, 0.27, 0), 0.05, 0.03, "rust")
	Props.cable(dress, p + Vector3(-0.07, 0.28, 0), p + Vector3(0.07, 0.28, 0), -0.08, 0.006, 4, "iron")
	lamp(p + Vector3(0, 0.3, 0), Color(1.0, 0.62, 0.3), 1.2, 8.0, 0.15, 0.4, false, 6.0)


## A straight luminous-paint strip from a to b (on a floor, or a wall stripe if `wall`). T-173: the strips are
## painted on (m2_lumi: a pale paint with a faint glow, not the bright lumi_paint tube that read as a debug outline),
## and a run along X that climbs (the pump stair) is rolled to follow it instead of floating level at mid-height.
func _lumi_line(a: Vector3, b: Vector3, w: float, wall: bool = false) -> void:
	var d: Vector3 = b - a
	var mid: Vector3 = (a + b) * 0.5
	if absf(d.x) > absf(d.z):
		var roll: float = rad_to_deg(atan2(d.y, absf(d.x))) * (1.0 if d.x > 0.0 else -1.0)
		var sx: Vector3 = Vector3(d.length(), 0.012 if not wall else w, w if not wall else 0.012)
		_noshadow(Props.obox(dress, mid, sx, "m2_lumi", Vector3(0, 0, roll)))
		return
	var pitch: float = rad_to_deg(atan2(-d.y, absf(d.z))) * (1.0 if d.z > 0.0 else -1.0)
	var size: Vector3 = Vector3(w if not wall else 0.012, 0.012 if not wall else w, d.length())
	_noshadow(Props.obox(dress, mid, size, "m2_lumi", Vector3(pitch, 0, 0)))


# ================================================================== generic dressing (windows, doors, treads, rails, weather)

func _dress_windows() -> void:
	for w: Array in WINDOWS:
		var p: Vector3 = w[2]
		var yaw: float = float(w[3])
		var id: String = str(w[0])
		var g: Node3D = Props.group(dress, "WindowDress", p, yaw)
		var hw: float = 0.8
		if STAGE_WINDOWS.has(id):
			# a parapet gap onto a timber landing stage: capping stones, a ladder down to the water, rope
			Props.block(g, Vector3(-hw - 0.2, SILL - 0.06, -0.2), Vector3(hw + 0.2, SILL, 0.2), "concrete")
			Props.ladder(g, Vector3(0.9, -2.4, -0.3), 0.0, 2.3, "rust")
			for sx: float in [-1.4, 1.4]:
				Props.block(g, Vector3(sx - 0.08, -2.6, -3.1), Vector3(sx + 0.08, 0.2, -2.94), "planks")
				Props.block(g, Vector3(sx - 0.08, -2.6, -0.4), Vector3(sx + 0.08, 0.2, -0.24), "planks")
			# a rope rail on the posts round the stage's three open sides (the kerb colliders are in build_quay)
			for sx2: float in [-1.4, 1.4]:
				Props.block(g, Vector3(sx2 - 0.03, 0.1, -3.0), Vector3(sx2 + 0.03, 0.16, -0.34), "rope")
			Props.block(g, Vector3(-1.4, 0.1, -3.05), Vector3(1.4, 0.16, -2.99), "rope")
			Props.rope_coil(g, Vector3(-1.0, -0.05, -1.8), 0.3)
			continue
		var t: float = T
		var deep: bool = id.begins_with("W_A_S") or id.begins_with("W_D") or id.begins_with("W_G")
		if deep:
			t = 3.0
		# a concrete lintel and sill on both faces; steel shutters hooked back beside the hall chutes
		Props.block(g, Vector3(-hw - 0.2, WTOP, -t * 0.5 - 0.04), Vector3(hw + 0.2, WTOP + 0.24, t * 0.5 + 0.04), "bunker_concrete")
		Props.block(g, Vector3(-hw - 0.12, SILL - 0.08, -t * 0.5 - 0.14), Vector3(hw + 0.12, SILL, t * 0.5 + 0.04), "bunker_concrete")
		if id.begins_with("W_D") or id.begins_with("W_A_S"):
			for s2: float in [-1.0, 1.0]:
				var sh: Node3D = Props.group(g, "Shutter", Vector3(s2 * (hw + 0.14), SILL, t * 0.5 + 0.04), s2 * 100.0)
				Props.block(sh, Vector3(-0.03, 0, 0), Vector3(0.03, WTOP - SILL + 0.1, s2 * -0.78), "rust")
			Props.stencil(g, Vector3(0, WTOP + 0.45, t * 0.5 + 0.045), 180.0, "LÜFTUNG", 24, Color(0.85, 0.82, 0.7, 0.6))
		elif id.begins_with("W_B"):
			_noshadow(Props.block(g, Vector3(-hw - 0.08, SILL, -t * 0.5 - 0.13), Vector3(hw + 0.08, SILL + 0.07, -t * 0.5 + 0.02), "snow", false))


## Door trims (both faces) for the buyable doors and the open doorways: [pos, yaw, width, height, key, depth]
func _dress_doors() -> void:
	var trims: Array = [
		[Vector3(0, 0, 15), 90.0, 2.0, DOOR_H, "concrete", T], [Vector3(32, 0, 15), 90.0, 2.0, DOOR_H, "concrete", T],
		[Vector3(-10, 0, 31.5), 0.0, 2.0, DOOR_H, "machine_grey", 3.0], [Vector3(44, 0, 31.5), 0.0, 2.0, DOOR_H, "machine_grey", 3.0],
		[Vector3(49, 0, 42), 0.0, 3.0, DOOR_H, "machine_grey", T], [Vector3(42, TY, 34), 90.0, 2.0, DOOR_H, "machine_grey", T],
		[Vector3(18, 0, 13.5), 90.0, 1.8, DOOR_H, "beam", T], [Vector3(-20, 0, 6), 90.0, 1.8, DOOR_H, "beam", T],
		[Vector3(-25, 0, 10), 0.0, 1.8, DOOR_H, "beam", T],
	]
	for d: Array in trims:
		var g: Node3D = Props.group(dress, "DoorTrim", d[0], float(d[1]))
		var w: float = float(d[2])
		var h: float = float(d[3])
		var key: String = str(d[4])
		var t: float = float(d[5])
		for s: float in [1.0, -1.0]:
			var f: float = s * t * 0.5
			Props.block(g, Vector3(-w * 0.5 - 0.14, 0, f), Vector3(-w * 0.5, h + 0.14, f + s * 0.07), key)
			Props.block(g, Vector3(w * 0.5, 0, f), Vector3(w * 0.5 + 0.14, h + 0.14, f + s * 0.07), key)
			Props.block(g, Vector3(-w * 0.5 - 0.14, h, f), Vector3(w * 0.5 + 0.14, h + 0.18, f + s * 0.08), key)
		if key == "machine_grey":
			for s2: float in [1.0, -1.0]:
				for k: int in 5:
					Props.block(g, Vector3(-w * 0.5 + k * w * 0.25 - 0.12, h + 0.02, s2 * (t * 0.5 + 0.075)),
						Vector3(-w * 0.5 + k * w * 0.25 + 0.12, h + 0.14, s2 * (t * 0.5 + 0.085)), "yellow_paint" if k % 2 == 0 else "black_paint")
		if t > 1.0:   # the pen passages: a lined tunnel through the 3 m slab, lit by a caged lamp
			for s3: float in [-1.0, 1.0]:
				Props.block(g, Vector3(s3 * (w * 0.5 + 0.01), 0, -t * 0.5 + 0.1), Vector3(s3 * (w * 0.5 + 0.03), h, t * 0.5 - 0.1), "paint_green")
			Props.block(g, Vector3(-w * 0.5, h - 0.02, -t * 0.5 + 0.1), Vector3(w * 0.5, h, t * 0.5 - 0.1), "black_paint")


func _dress_treads() -> void:
	for s: Array in _stairs:
		var along_z: bool = str(s[0]) == "z"
		var a0: float = float(s[1])
		var a1: float = float(s[2])
		var low: float = float(s[3])
		var high: float = float(s[4])
		var y_low: float = float(s[5])
		var y_high: float = float(s[6])
		var tread: String = str(s[7])
		var riser: String = str(s[8])
		var rise: float = y_high - y_low
		var steps: int = int(ceil(absf(rise) / 0.22))
		var y_lo: float = minf(y_low, y_high)
		for k: int in steps:
			var t0: float = float(k) / float(steps)
			var t1: float = float(k + 1) / float(steps)
			var la: float = lerpf(low, high, t0)
			var lb: float = lerpf(low, high, t1)
			var yb: float = lerpf(y_low, y_high, t1)
			var lo_l: float = minf(la, lb)
			var hi_l: float = maxf(la, lb)
			var top: float = maxf(yb, lerpf(y_low, y_high, t0))
			if along_z:
				B(Vector3(a0, maxf(y_lo, top - 0.6), lo_l), Vector3(a1, top - 0.04, hi_l), riser)
				B(Vector3(a0, top - 0.04, lo_l - 0.02), Vector3(a1, top, hi_l + 0.02), tread)
			else:
				B(Vector3(lo_l, maxf(y_lo, top - 0.6), a0), Vector3(hi_l, top - 0.04, a1), riser)
				B(Vector3(lo_l - 0.02, top - 0.04, a0), Vector3(hi_l + 0.02, top, a1), tread)
			if tread == "concrete" or tread == "steel_grate":
				var nz: float = la + (lb - la) * 0.06
				if along_z:
					_noshadow(B(Vector3(a0 + 0.1, top - 0.005, nz - 0.03), Vector3(a1 - 0.1, top + 0.004, nz + 0.03), "m2_lumi", false))
				else:
					_noshadow(B(Vector3(nz - 0.03, top - 0.005, a0 + 0.1), Vector3(nz + 0.03, top + 0.004, a1 - 0.1), "m2_lumi", false))


## Posts and rails over every hidden railing collider (name Rail_*), by reading the geometry back.
func _dress_rails() -> void:
	for n: Node in geo.get_children():
		if not n.name.begins_with("Rail_"):
			continue
		var body: StaticBody3D = n as StaticBody3D
		var cs: CollisionShape3D = body.get_child(0) as CollisionShape3D
		var size: Vector3 = (cs.shape as BoxShape3D).size
		var c: Vector3 = body.position
		var base: Vector3 = Vector3(c.x, c.y - size.y * 0.5, c.z)
		var h: float = minf(size.y, 1.05)
		var key: String = "rust" if n.name.begins_with("Rail_Pens") or n.name.begins_with("Rail_Hatch") else "iron"
		if n.name.begins_with("Rail_Stair") and size.y > 2.0:
			continue   # sloped stair rails are drawn with the treads' handrails below
		if n.name == "Rail_TR" or n.name.begins_with("Rail_GW") or n.name.begins_with("Rail_Hatch"):
			continue   # T-180: sloped / guard rails in _dress_t180 (a level 1.05 m railing was buried in the slope)
		if size.x > size.z:
			Props.railing(dress, base + Vector3(-size.x * 0.5 + 0.05, 0, 0), base + Vector3(size.x * 0.5 - 0.05, 0, 0), h, key)
		else:
			Props.railing(dress, base + Vector3(0, 0, -size.z * 0.5 + 0.05), base + Vector3(0, 0, size.z * 0.5 - 0.05), h, key)
	# sloped handrails on the open side of every stair
	for s: Array in _stairs:
		var along_z: bool = str(s[0]) == "z"
		if str(s[7]) != "steel_grate" and str(s[7]) != "concrete":
			continue
		var a0: float = float(s[1])
		var a1: float = float(s[2])
		var low: float = float(s[3])
		var high: float = float(s[4])
		var y_low: float = float(s[5])
		var y_high: float = float(s[6])
		# T-180: U-1047's companionway rails rise out of the hatch: drawn with the hall round it (DH), not the hidden hold
		var vis: String = "DH" if along_z and a0 >= 4.0 and a1 <= 10.0 and minf(y_low, y_high) < 0.62 and maxf(y_low, y_high) > 0.62 else ""
		for side: float in [a0 + 0.06, a1 - 0.06]:
			var pa: Vector3 = Vector3(side, y_low + 1.0, low) if along_z else Vector3(low, y_low + 1.0, side)
			var pb: Vector3 = Vector3(side, y_high + 1.0, high) if along_z else Vector3(high, y_high + 1.0, side)
			var hr: MeshInstance3D = Props.strut(dress, pa, pb, 0.06, "iron", true)
			if vis != "" and hr != null:
				hr.set_meta("vis", vis)
			var posts: int = int(pa.distance_to(pb) / 1.4)
			for k: int in posts + 1:
				var t: float = float(k) / float(maxi(1, posts))
				var p: Vector3 = pa.lerp(pb, t)
				var post: MeshInstance3D = B(p + Vector3(-0.02, -1.0, -0.02), p + Vector3(0.02, 0, 0.02), "iron")
				if vis != "":
					post.set_meta("vis", vis)


func _dress_weather() -> void:
	var snow: Node3D = Node3D.new()
	snow.set_script(load("res://gravelight/world/snowfall.gd"))
	snow.name = "Snowfall"
	snow.set("areas", [AABB(Vector3(-30, 0, -12), Vector3(92, 14, 42)), AABB(Vector3(-20, 1, 84), Vector3(72, 12, 40))] as Array[AABB])
	snow.set("density", 1.4)
	dress.add_child(snow)
	snow.set_meta("keep", true)
	var motes: Node3D = Node3D.new()
	motes.set_script(load("res://gravelight/world/snowfall.gd"))
	motes.name = "DustMotes"
	motes.set("areas", [AABB(Vector3(-19, 0.3, 34), Vector3(70, 9, 49)), AABB(Vector3(-29, 0.3, 1), Vector3(28, 5, 28)),
		AABB(Vector3(33, 0.3, 1), Vector3(28, 6, 28)), AABB(Vector3(33, LY + 0.2, 51), Vector3(18, 2.4, 32))] as Array[AABB])
	motes.set("motes", true)
	dress.add_child(motes)
	motes.set_meta("keep", true)
	# spray at the pen mouth and over the parapet
	# (the quay parapet's two spray emitters went in the lighting pass: lit by the moon they read as brown smoke; the
	# QuaySpray fog volume carries the spray now)
	for sp: Vector3 in [Vector3(-8, 1.0, 84), Vector3(16, 1.0, 84), Vector3(40, 1.0, 84)]:
		Props.smoke(dress, sp, 3.0, 2.4, 40)


## The water: the tide plane in the pens (moved by the TideController) and the open sea off the quay.
func _dress_water() -> void:
	_water = MeshInstance3D.new()
	_water.name = "TideWater"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(80, 112)
	pm.subdivide_width = 40
	pm.subdivide_depth = 56
	_water.mesh = pm
	_water.material_override = Mats.get_mat("sea_water")
	_water.position = Vector3(16, LOW_TIDE, 94)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.set_meta("keep", true)
	map_root.add_child(_water)
	var sea: MeshInstance3D = MeshInstance3D.new()
	sea.name = "SeaWater"
	var pm2: PlaneMesh = PlaneMesh.new()
	pm2.size = Vector2(300, 150)
	pm2.subdivide_width = 60
	pm2.subdivide_depth = 30
	sea.mesh = pm2
	var rough: ShaderMaterial = (Mats.get_mat("sea_water") as ShaderMaterial).duplicate() as ShaderMaterial
	rough.set_shader_parameter("amp", 0.55)   # T-145: the Baltic in a storm off the quay, whitecaps on the swell
	rough.set_shader_parameter("chop", 1.6)
	rough.set_shader_parameter("speed", 1.4)
	rough.set_shader_parameter("foam", Color(0.72, 0.78, 0.8))
	sea.material_override = rough
	sea.position = Vector3(16, -2.0, -75)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.set_meta("keep", true)
	map_root.add_child(sea)
	# tide marks: the high-water band on every wall and pier that stands in the pens' water
	var hm: float = HIGH_TIDE
	for r: Array in [[Vector3(-13.98, hm - 0.5, 38), Vector3(-14.02, hm + 0.25, 84)], [Vector3(-6.02, hm - 0.5, 38), Vector3(-5.98, hm + 0.25, 84)],
			[Vector3(-0.02, hm - 0.5, 38), Vector3(0.02, hm + 0.25, 84)], [Vector3(13.98, hm - 0.5, 38), Vector3(14.02, hm + 0.25, 84)],
			[Vector3(19.98, hm - 0.5, 38), Vector3(20.02, hm + 0.25, 84)], [Vector3(31.98, hm - 0.5, 38), Vector3(32.02, hm + 0.25, 50)],
			[Vector3(-20, hm - 0.5, 37.98), Vector3(52, hm + 0.25, 38.02)]]:
		_noshadow(B(r[0], r[1], "tide_mark", false))
	# weed at the waterline of the piers
	for wz: float in [44.0, 56.0, 70.0, 80.0]:
		for wx: float in [-14.0, -6.0, 0.0, 14.0, 20.0, 32.0]:
			_noshadow(Props.ball(dress, Vector3(wx, hm - 0.2, wz), Vector3(0.5, 0.35, 1.2), "weed"))


# ================================================================== art dressing per zone

func build_dressing() -> void:
	_dress_water()
	_tagged(_dress_quay, "A")
	_tagged(_dress_cannery, "B")
	_tagged(_dress_workshop, "C")
	_tagged(_dress_penhall, "")   # the hall's pieces span D and DH: they take their group from where they stand
	_tagged(_dress_uboat_hull, "DH")
	_tagged(_dress_uboat, "E")
	_tagged(_dress_lowerpens, "F")
	_tagged(_dress_tower, "G")
	_tagged(_dress_u09_quay, "A")
	_tagged(_dress_u09_cannery, "B")
	_tagged(_dress_u09_workshop, "C")
	_tagged(_dress_u09_penhall, "")
	_tagged(_dress_u09_uboat, "E")
	_tagged(_dress_u09_lowerpens, "F")
	_tagged(_dress_u09_tower, "G")
	_tagged(_dress_u10_quay, "A")      # UPDATE 10 s2 (T-154): the living world's pieces
	_tagged(_dress_u10_horizon, "")
	_tagged(_dress_u10_cannery, "B")
	_tagged(_dress_u10_penhall, "")
	_tagged(_dress_u10_tower, "G")
	_tagged(_dress_u10_lowerpens, "F")
	_tagged(_dress_t273_sea, "A")      # T-273: the map detail pass (the patrol boat off the quay)
	_tagged(_dress_t273_hall, "")      # T-273: the catwalk ladders, the signal balcony and its zip line (D by their boxes)
	_dress_windows()
	_dress_doors()
	_dress_treads()
	_dress_rails()
	_dress_readability()
	_dress_weather()
	_dress_light()
	_tagged(_dress_t180, "")   # T-180: what the fitted colliders and the bulkheads look like
	_fit_colliders()           # T-180: after every piece of dressing exists, before the batches merge it


## Runs a dressing function and marks every top-level node it added under Dressing with meta "vis" = `g` (the
## visibility group its pieces belong to, whatever box their centre falls in). `g` "" leaves them to the boxes.
func _tagged(fn: Callable, g: String) -> void:
	var before: int = dress.get_child_count()
	var lights_before: int = _static_lights.size()
	var power_before: int = _power.size()
	var spots_before: int = _spots.size()
	fn.call()
	if g == "":
		return
	for i: int in range(before, dress.get_child_count()):
		if not dress.get_child(i).has_meta("vis"):   # T-180: a piece may name its own group
			dress.get_child(i).set_meta("vis", g)
	for i2: int in range(lights_before, _static_lights.size()):
		_static_lights[i2]["vis"] = g
	for i3: int in range(power_before, _power.size()):
		_power[i3]["vis"] = g
	for i4: int in range(spots_before, _spots.size()):
		_spots[i4]["vis"] = g


## The visibility group of a point (the first VIS_BOXES box holding it; "ALL" when none).
func _vis_box(p: Vector3) -> String:
	for vb: Array in VIS_BOXES:
		var lo: Vector3 = vb[1]
		var hi: Vector3 = vb[2]
		if p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y and p.z >= lo.z and p.z <= hi.z:
			return str(vb[0])
	return "ALL"


## A node's group: the nearest "vis" meta up its parents, else the box of `p` (its world centre).
func _vis_of(n: Node, p: Vector3) -> String:
	var q: Node = n
	while q != null and q != map_root:
		if q.has_meta("vis"):
			return str(q.get_meta("vis"))
		q = q.get_parent()
	return _vis_box(p)


## Lighting pass (T-063): the light that is there before the pumps run, each from a source you can see. Moonlight
## through the cannery's, workshop's and tower's windows and the hall's vents; the sea's cold light in under the
## half-lowered curtain and through the lower pens' grille; fire barrels on the quay and in the crane bay.
func _dress_light() -> void:
	for br: Array in BRAZIERS:
		brazier(br[1])
	for sv2: Array in STOVES:
		stove(sv2[1], float(sv2[2]), 7.0)
	for id: String in ["W_B_N", "W_B_W1", "W_B_W2", "W_C_N", "W_C_E1", "W_C_E2"]:
		moon_window(id, 1.0)
	for id2: String in ["W_G_N1", "W_G_N2"]:
		moon_window(id2, 0.6)
	for id3: String in ["W_D_N1", "W_D_N2", "W_D_N3"]:
		moon_window(id3, 0.8)
	# T-145: two wider sea shafts instead of four 60 m ones (C4: <= 6 shadowed lights in D)
	for mx: float in [0.0, 33.0]:
		shaft("SeaLight_Mouth", Vector3(mx, 1.9, 97.0), Vector3(mx, -0.8, 54.0), SEALIGHT, 13.0, 48.0, 46.0, 1.0)
	# lanterns the dockers left burning: warm pools between the dark stretches (on tables, crates, the floor)
	for hp: Vector3 in [Vector3(-7.0, 0.95, 19.0), Vector3(-4.0, 1.0, 4.8), Vector3(-12.5, 1.2, 26.0), Vector3(-26.5, 0, 16.5),
			Vector3(40.5, 1.3, 14.5), Vector3(58.5, 1.3, 6.0), Vector3(55.0, 0, 29.6), Vector3(50.0, 1.3, 8.5),
			Vector3(-3.0, 0, 72.0), Vector3(17.0, 0, 46.0), Vector3(25.0, 0, 36.6), Vector3(-19.2, CATY, 60.0), Vector3(51.2, CATY, 56.0),
			Vector3(50.5, LY, 75.0), Vector3(33.5, LY, 72.0), Vector3(4.0, 0, 13.0)]:
		_hurricane(hp)
	shaft("SeaLight_Grille", Vector3(42.0, -0.6, 96.0), Vector3(42.0, -8.4, 67.0), SEALIGHT, 2.5, 40.0, 14.0, 0.5)


func _dress_quay() -> void:
	# wet patches, trodden snow, drifts in the corners
	for r: Array in [[1.0, 9.5, 2.0, 9.0], [19.0, 31.5, 9.0, 29.0], [0.5, 9.5, 18.0, 29.5]]:
		_noshadow(B(Vector3(float(r[0]), 0.0, float(r[2])), Vector3(float(r[1]), 0.012, float(r[3])), "m2_floor_wet", false))   # T-145: wet patches (the trodden-snow set read as camouflage)
	# T-173: the drifts are low grey slush heaped into the corners and along the parapet (the two corner drifts were
	# single 3 m white domes standing free of the walls: in the dark they read as white discs floating over the quay)
	for d: Array in [[Vector3(0.9, -0.06, 29.3), Vector3(2.4, 0.44, 1.3)], [Vector3(0.55, -0.06, 28.1), Vector3(1.0, 0.36, 2.0)],
			[Vector3(2.4, -0.06, 29.55), Vector3(1.6, 0.3, 0.8)], [Vector3(31.1, -0.06, 29.3), Vector3(2.2, 0.4, 1.3)],
			[Vector3(31.45, -0.06, 28.2), Vector3(1.0, 0.34, 1.8)], [Vector3(14, -0.04, 9.6), Vector3(8.0, 0.3, 0.8)],
			[Vector3(4.0, -0.04, 0.75), Vector3(5.0, 0.36, 1.0)]]:
		_noshadow(Props.ball(dress, d[0], d[1], "snow_trodden"))
	_noshadow(B(Vector3(2.4, 1.1, -0.2), Vector3(29.6, 1.17, 0.2), "snow", false))
	# bollards, mooring lines, a capstan, the cutter's hawser
	for bx: float in [4.5, 14.5, 20.0, 28.0]:
		Props.bollard(dress, Vector3(bx, 0, 1.0))
	Props.cable(dress, Vector3(14.5, 0.75, 1.0), Vector3(12.0, -0.3, -3.0), 0.5, 0.04, 8, "rope")
	Props.cable(dress, Vector3(28.0, 0.75, 1.0), Vector3(24.5, 1.9, 4.0), 0.3, 0.04, 6, "rope")
	Props.rope_coil(dress, Vector3(6.2, 0, 2.6))
	Props.rope_coil(dress, Vector3(20.8, 0, 2.3), 0.35)
	# surf steps at both parapet ends, down into the water (dressing; the chains hold the player)
	for sx: float in [1.2, 30.8]:
		for k: int in 8:
			B(Vector3(sx - 1.2, -0.3 * (k + 1), -0.5 * (k + 1)), Vector3(sx + 1.2, -0.3 * k, -0.5 * k), "pier_concrete")
		Props.cable(dress, Vector3(sx - 1.2, 1.0, 0), Vector3(sx + 1.2, 1.0, 0), 0.12, 0.02, 6, "iron")
	# the harbourmaster's hut: window, lamp, sign, stove pipe, the desk and log inside, the Kar98k chalk wall
	for wp: Array in [[Vector3(14, 0, 9.85), 180.0], [Vector3(14, 0, 17.15), 0.0]]:
		var g: Node3D = Props.group(dress, "HutWindow", wp[0], float(wp[1]))
		Props.block(g, Vector3(-0.6, 1.1, -0.02), Vector3(0.6, 2.0, 0.0), "window_dark")   # T-145: no more glowing white slab
		Props.block(g, Vector3(-0.66, 1.04, -0.06), Vector3(0.66, 1.1, 0.02), "beam")
		Props.block(g, Vector3(-0.66, 2.0, -0.06), Vector3(0.66, 2.06, 0.02), "beam")
		Props.block(g, Vector3(-0.03, 1.1, -0.04), Vector3(0.03, 2.0, 0.0), "beam")
	lamp(Vector3(14, 1.6, 12.5), INCAND, 0.9, 6.0, 0.08)
	CYL(Vector3(11.0, 3.9, 11.0), 0.12, 1.4, "iron")
	Props.smoke(dress, Vector3(11.0, 4.7, 11.0), 0.15, 0.5, 10)
	Props.wall_lamp(dress, Vector3(18.15, 2.5, 15.2), -90.0)
	lamp(Vector3(18.8, 2.4, 15.2), INCAND, 1.0, 7.0, 0.1)
	B(Vector3(13.0, 2.45, 17.16), Vector3(15.0, 2.95, 17.2), "planks")
	_label("HAFENMEISTER", Vector3(14, 2.7, 17.21), 0.0, 28)
	Props.table_visual(dress, Vector3(11.3, 0, 15.95), 2.0, 1.5, 0.8)
	Props.chair(dress, Vector3(11.5, 0, 14.7), 180.0)
	Props.shelves(dress, Vector3(17.85, 0, 11.5), -90.0, 2.4, 2.2, 0.3, 3, 3)
	Props.picture(dress, Vector3(10.17, 1.8, 12.0), -90.0, 0.9, 0.6)
	Props.coat_rack(dress, Vector3(17.5, 0, 16.6))
	# T-180: the old flat-black chalk slab behind this wall-buy is gone (2.2 m of untextured black that read as a
	# texture that never loaded; the wall-buy carries its own painted board since T-094)
	# nets, crates, drums and a hand cart along the cannery side
	Props.net_pile(dress, Vector3(3.5, 0, 6.0), Vector3(3.2, 0.9, 2.6), 11)
	Props.net_pile(dress, Vector3(6.5, 0, 22.5), Vector3(2.4, 0.7, 2.0), 12)
	Props.crate(dress, Vector3(2.0, 0, 11.5), 1.0, 10.0, "FISCH")
	Props.crate(dress, Vector3(2.1, 1.0, 11.4), 0.7, -8.0)
	Props.crate(dress, Vector3(4.2, 0, 12.6), 0.8, 32.0)
	for dp: Vector3 in [Vector3(27.5, 0, 26.5), Vector3(28.4, 0, 27.4), Vector3(26.6, 0, 27.6)]:
		Props.oil_drum(dress, dp, "rust")
	Props.oil_drum(dress, Vector3(29.6, 0, 26.0), "rust", true)
	Props.cart(dress, Vector3(23.5, 0, 24.5), 20.0)
	Props.sandbags(dress, Vector3(19.5, 0, 29.2), Vector3(24.5, 0, 29.2), 2)
	# the beached cutter is DetailMap02.cutter (_dress_u09_quay); the snow along it and the M1 Carbine's chalk board
	_noshadow(B(Vector3(20.6, 0, 1.9), Vector3(21.2, 0.08, 8.2), "snow_trodden", false))   # T-180: grey slush, not a white plank
	# T-180: the old flat-black chalk slab behind this wall-buy is gone (2.2 m of untextured black that read as a
	# texture that never loaded; the wall-buy carries its own painted board since T-094)
	# the bunker face from the quay: the name, pen-passage lamps, a flood over each passage, pilasters
	B(Vector3(-5.0, 6.6, 29.6), Vector3(5.0, 7.5, 29.98), "concrete")
	_label("KRIEGSMARINE · U-BUNKER TOTENHAFEN", Vector3(0, 7.05, 29.59), 180.0, 44, Color(0.9, 0.86, 0.74, 0.9))
	for px: float in [-26.0, -18.0, 2.0, 12.0, 20.0, 36.0, 54.0]:
		B(Vector3(px - 0.5, 0, 29.4), Vector3(px + 0.5, ROOF, 30.0), "bunker_concrete")
	for dp2: Vector3 in [Vector3(-10, 3.0, 29.9), Vector3(44, 3.0, 29.9)]:
		bulkhead("A_QUAY", dp2, 180.0)
		power("A_QUAY", dp2 + Vector3(0, 0, -0.6), 9.0, 1.0, SODIUM)
	for wl: Vector3 in [Vector3(6, 3.5, 29.9), Vector3(26, 3.5, 29.9)]:   # over the vent windows (T-063): the power shows them
		bulkhead("A_QUAY", wl, 180.0)
		power("A_QUAY", wl + Vector3(0, -0.2, -0.7), 9.0, 0.9, SODIUM)
	flood("A_QUAY", Vector3(8.0, 9.5, 29.6), Vector3(12.0, 0.0, 10.0), 38.0, 9.0, 46.0, SODIUM, true)   # A's key light (T-145)
	flood("A_QUAY", Vector3(24.0, 9.5, 29.6), Vector3(22.0, 0.0, 6.0), 38.0, 9.0, 46.0, SODIUM)
	lamp(Vector3(16.0, 6.0, 15.0), Color(0.5, 0.6, 0.78), 0.6, 30.0, 0.0, 0.1)
	flood("A_QUAY", Vector3(-20.0, 9.5, 29.6), Vector3(-14.0, 0.0, 4.0), 30.0, 4.0, 42.0)
	flood("A_QUAY", Vector3(50.0, 9.5, 29.6), Vector3(46.0, 0.0, 4.0), 30.0, 4.0, 42.0)
	# the harbour beyond: the breakwater's beacon, the cannery's and workshop's roofs, chimneys and gables
	Props.gable_roof(dress, Vector3(-30.3, 6.3, -0.3), Vector3(0.3, 6.3, 30.3), 2.4, true)
	Props.gable_roof(dress, Vector3(31.7, 7.3, -0.3), Vector3(62.3, 7.3, 30.3), 2.6, true)
	CYL(Vector3(-27.0, 8.6, 20.0), 0.45, 5.0, "brick")
	Props.smoke(dress, Vector3(-27.0, 11.2, 20.0), 0.25, 0.9, 14)
	# the cliffs' faces and the town above: a few dark gables on the skyline
	for tb: Array in [[Vector3(-45, 46, -20), 8.0], [Vector3(-36, 46, 10), 6.0], [Vector3(80, 46, -10), 9.0], [Vector3(95, 46, 15), 7.0]]:
		var p: Vector3 = tb[0]
		var w: float = float(tb[1])
		_noshadow(B(p + Vector3(-w * 0.5, 0, -w * 0.4), p + Vector3(w * 0.5, w * 0.6, w * 0.4), "stucco", false))
		_noshadow(Props.prism(dress, p + Vector3(0, w * 0.6 + w * 0.2, 0), Vector3(w, w * 0.4, w * 0.8), "roof"))
	# ground spawns: the surf steps' heads
	for sp: Vector3 in [Vector3(2.0, 0.0, 2.0), Vector3(31.0, 0.0, 1.6)]:
		decal(sp + Vector3(0, 0.02, 0), Vector3(3.0, 0.5, 3.0), Color(0.05, 0.08, 0.07, 0.6))


func _dress_cannery() -> void:
	_noshadow(B(Vector3(-29.85, 0.0, 0.15), Vector3(-0.15, 0.012, 29.85), "m2_quarry", false))   # T-173: quarry tiles (the two-tone terrazzo read as a black-and-white checker)
	# roof trusses and three powered pendants over each line
	for tz: float in [4.0, 10.0, 16.0, 22.0, 28.0]:
		B(Vector3(-29.8, 5.4, tz - 0.12), Vector3(-0.2, 5.95, tz + 0.12), "beam")
		Props.strut(dress, Vector3(-29.5, 5.4, tz), Vector3(-15.0, 5.95, tz), 0.12, "beam")
		Props.strut(dress, Vector3(-0.5, 5.4, tz), Vector3(-15.0, 5.95, tz), 0.12, "beam")
	for px: float in [-20.0, -14.0, -8.0]:
		for pz: float in [14.0, 19.0]:
			pendant("B_CANNERY", Vector3(px, 3.0, pz), 5.95, "enamel_white", 1.1, "bulb_cold")
			power("B_CANNERY", Vector3(px, 2.8, pz), 8.0, 0.7, MERCURY, px == -14.0 and pz == 14.0)   # B's key light (T-145)
	pendant("B_CANNERY", Vector3(-10, 3.0, 5.0), 5.95, "enamel_white", 1.0, "bulb_cold")
	power("B_CANNERY", Vector3(-10, 2.8, 5.0), 8.0, 0.6, MERCURY)
	pendant("B_CANNERY", Vector3(-22, 3.0, 25.0), 5.95, "enamel_white", 1.0, "bulb_cold")
	power("B_CANNERY", Vector3(-22, 2.8, 25.0), 8.0, 0.6, MERCURY)
	# gutting lines: zinc tops on trestles, a gutter, knives and baskets; the conveyor with its belt and rollers
	for lz: float in [13.3, 18.3]:
		B(Vector3(-22, 0.85, lz), Vector3(-6, 0.95, lz + 1.4), "zinc")
		B(Vector3(-22, 0.95, lz + 0.55), Vector3(-6, 1.0, lz + 0.85), "tide_mark")
		for tx: float in [-21.0, -16.0, -11.0, -7.0]:
			B(Vector3(tx - 0.06, 0, lz + 0.1), Vector3(tx + 0.06, 0.85, lz + 0.22), "iron")
			B(Vector3(tx - 0.06, 0, lz + 1.18), Vector3(tx + 0.06, 0.85, lz + 1.3), "iron")
		for k: int in 5:
			var bx: float = -20.5 + k * 3.2
			Props.obox(dress, Vector3(bx, 0.97, lz + 0.3), Vector3(0.25, 0.015, 0.04), "steel", Vector3(0, 20.0 + k * 11, 0))
			_noshadow(Props.ball(dress, Vector3(bx + 1.2, 0.2, lz + 1.9), Vector3(0.6, 0.4, 0.6), "net"))
	DetailMap02.conveyor(dress, Vector3(-18.0, 0, 4.8), Vector3(-2.0, 0, 4.8), 1.5, 1.0, false)
	# brine tanks (riveted), cans on pallets and in a crate
	for tc: Vector3 in [Vector3(-27.0, 0, 24.0), Vector3(-23.0, 0, 24.0)]:
		DetailMap02.brine_tank(dress, tc, 1.45, 1.5)
	Props.can_stack(dress, Vector3(-12.5, 0, 26.25), 8, 6, 5)
	Props.can_stack(dress, Vector3(-7.5, 0, 26.25), 8, 6, 4)
	Props.crate(dress, Vector3(-2.5, 0, 27.5), 1.1, 6.0, "KONSERVEN")
	Props.crate(dress, Vector3(-17.0, 0, 28.0), 0.8, -15.0)
	Props.sack(dress, Vector3(-19.0, 0, 27.4), 30.0)
	Props.sack(dress, Vector3(-19.6, 0, 28.6), 70.0, 0.9)
	# the infirmary: cots with blankets, a screen, the stove, a cabinet, a crucifix nail-hole, the letter's cot
	for cz: float in [1.2, 4.0, 6.8]:
		Props.bed(dress, Vector3(-29.6, 0, cz), Vector3(-27.6, 0.55, cz + 2.0), "linen" if cz < 2.0 else "cloth_green")
	Props.curtain(dress, Vector3(-24.0, 0, 3.0), 90.0, 2.0, "linen")
	CYL(Vector3(-22.1, 2.05, 8.9), 0.08, 2.3, "iron")
	lamp(Vector3(-22.1, 0.9, 8.0), Color(1.0, 0.45, 0.15), 1.1, 6.0, 0.3, 0.3)
	Props.cabinet(dress, Vector3(-20.5, 0, 1.0), -90.0, 1.2, 1.8, 0.4, true)
	Props.washstand(dress, Vector3(-26.0, 0, 9.2), 180.0)
	Props.stool(dress, Vector3(-27.2, 0, 3.4))
	_label("KRANKENSTUBE", Vector3(-19.83, 2.7, 5.0), 90.0, 26)
	Props.picture(dress, Vector3(-29.83, 2.0, 8.0), -90.0, 0.4, 0.5)
	# wall-buys' chalk and the perk stands
	# T-180: the old flat-black chalk slab behind this wall-buy is gone (2.2 m of untextured black that read as a
	# texture that never loaded; the wall-buy carries its own painted board since T-094)
	# emergency lamps and a hurricane lantern on the line
	emergency(Vector3(-15.0, 3.2, 0.17), 0.0, 0.8, 9.0)
	emergency(Vector3(-29.83, 3.2, 18.0), -90.0, 0.8, 9.0)
	emergency(Vector3(-4.0, 3.2, 29.83), 180.0, 0.8, 9.0)
	_hurricane(Vector3(-13.5, 0.95, 13.6))
	_hurricane(Vector3(-20.3, 0.9, 25.4))
	Props.puddle(dress, Vector3(-15, 0.004, 16.5), 3.0, 1.6, 20.0)
	Props.puddle(dress, Vector3(-25, 0.004, 20.0), 2.0, 1.2, -30.0)
	Props.cobweb(dress, Vector3(-29.85, 5.9, 0.15), 0.0, 1.0)
	_label("FISCHKONSERVEN TOTENHAFEN", Vector3(-10, 4.6, 0.19), 0.0, 40, Color(0.75, 0.7, 0.6, 0.6))


func _dress_workshop() -> void:
	_noshadow(B(Vector3(32.15, 0.0, 0.15), Vector3(61.85, 0.012, 29.85), "m2_floor", false))
	# the gantry rail down the hall with its hoist, and the trusses
	for tz: float in [5.0, 11.0, 17.0, 23.0]:
		B(Vector3(32.2, 6.4, tz - 0.12), Vector3(61.8, 6.95, tz + 0.12), "beam")
	B(Vector3(46.8, 6.0, 0.5), Vector3(47.2, 6.4, 29.5), "iron")
	DetailMap02.chain_hoist(dress, Vector3(47.0, 5.95, 11.0), 2.2)
	# torpedoes on cradles, one slung from the hoist, shells and drums; the lathe; the tool wall
	DetailMap02.torpedo_cradle(dress, Vector3(39.5, 0, 8.5), 90.0, 7.0, true, true)
	DetailMap02.torpedo_cradle(dress, Vector3(49.5, 0, 8.5), 90.0, 7.0)
	DetailMap02.torpedo_cradle(dress, Vector3(39.5, 0, 14.5), 90.0, 7.0)
	DetailMap02.torpedo_cradle(dress, Vector3(49.5, 0, 14.5), 90.0, 6.6, true, true)
	DetailMap02.lathe(dress, Vector3(58.0, 0, 6.0), 0.0)
	Props.shelves(dress, Vector3(61.83, 0, 4.0), 90.0, 3.0, 2.4, 0.35, 4, 5)
	Props.fuse_box(dress, Vector3(61.83, 2.0, 1.2), 90.0)
	Props.pipe(dress, Vector3(61.83, 2.35, 1.2), Vector3(61.83, 6.9, 1.2), 0.03)
	for dp: Vector3 in [Vector3(33.2, 0, 27.2), Vector3(34.1, 0, 28.3), Vector3(35.3, 0, 27.4)]:
		Props.oil_drum(dress, dp, "machine_grey")
	Props.crate(dress, Vector3(33.6, 0, 3.0), 1.0, 12.0, "TORPEDO-ZÜNDER")
	Props.crate(dress, Vector3(35.6, 0, 3.4), 0.8, -20.0)
	# the warhead store: mesh walls on an angle frame, the coffins inside under a tarp, the e-tool rack
	for cz: float in [16.0, 17.5, 19.0, 21.0, 22.5, 24.0]:
		B(Vector3(51.97, 0, cz - 0.04), Vector3(52.03, 2.5, cz + 0.04), "iron")
	for cx: float in [52.0, 54.0, 56.0, 58.0, 60.0, 62.0]:
		B(Vector3(cx - 0.04, 0, 15.97), Vector3(cx + 0.04, 2.5, 16.03), "iron")
	for y: float in [0.6, 1.4, 2.2]:
		for k: int in 26:
			B(Vector3(51.985, y - 0.4, 16.05 + k * 0.3), Vector3(52.015, y + 0.4, 16.08 + k * 0.3), "iron")
			B(Vector3(52.05 + k * 0.38, y - 0.4, 15.985), Vector3(52.08 + k * 0.38, y + 0.4, 16.015), "iron")
	B(Vector3(51.9, 2.5, 15.9), Vector3(62.0, 2.6, 24.0), "iron")
	Props.coffin(dress, Vector3(60.5, 0, 23.0), 0.0, "BLST-11")
	_noshadow(Props.ball(dress, Vector3(60.5, 1.1, 23.0), Vector3(2.6, 0.7, 1.4), "tarp"))
	# T-180: the old flat-black chalk slab behind this wall-buy is gone (2.2 m of untextured black that read as a
	# texture that never loaded; the wall-buy carries its own painted board since T-094)
	_label("SPRENGKÖPFE · ZUTRITT VERBOTEN", Vector3(51.97, 2.8, 20.0), -90.0, 22, Color(0.85, 0.3, 0.2, 0.9))
	# the trolley track along the south wall
	for k: int in 44:
		B(Vector3(34.0 + k * 0.6, 0, 26.3), Vector3(34.1 + k * 0.6, 0.07, 27.7), "beam")
	for rz: float in [26.6, 27.4]:
		B(Vector3(34.0, 0.07, rz - 0.03), Vector3(60.4, 0.14, rz + 0.03), "steel")
	# (T-247: the lot number stencilled on the pen wall is gone)
	# lights: powered pendants over the cradles, a bulkhead over the pen door, emergency lamps
	for px: float in [40.0, 50.0]:
		for pz: float in [8.5, 14.5, 21.0]:
			pendant("C_WORKSHOP", Vector3(px, 3.4, pz), 6.95, "enamel_green", 1.1)
			power("C_WORKSHOP", Vector3(px, 3.2, pz), 9.0, 0.8, SODIUM)
	bulkhead("C_WORKSHOP", Vector3(47.0, 3.0, 29.83), 0.0)
	power("C_WORKSHOP", Vector3(47.0, 3.0, 29.2), 7.0, 0.6, SODIUM)
	emergency(Vector3(32.17, 3.2, 8.0), -90.0, 0.8, 9.0)
	emergency(Vector3(61.83, 3.2, 16.0), 90.0, 0.8, 9.0)
	emergency(Vector3(56.0, 3.2, 0.17), 0.0, 0.8, 9.0)
	_hurricane(Vector3(43.3, 0.76, 7.0))
	_hurricane(Vector3(57.0, 1.0, 20.5))
	Props.puddle(dress, Vector3(44, 0.004, 20.0), 2.4, 1.4, 10.0)
	decal(Vector3(58.0, 0.02, 6.0), Vector3(4.0, 0.5, 3.0), Color(0.03, 0.03, 0.03, 0.7))


func _dress_penhall() -> void:
	# pier decks: kerbs, bollards, mooring lines to the boat, cleats; the apron's crane-bay markings
	for pr: Array in [[-20.0, -14.0], [-6.0, 0.0], [14.0, 20.0]]:
		var x0: float = float(pr[0])
		var x1: float = float(pr[1])
		for bz: float in [42.0, 54.0, 66.0, 78.0]:
			Props.bollard(dress, Vector3(x0 + 0.6, 0, bz), "rust")
			Props.bollard(dress, Vector3(x1 - 0.6, 0, bz), "rust")
		_noshadow(B(Vector3(x0 + 0.1, 0.0, 38.2), Vector3(x1 - 0.1, 0.01, 83.8), "wet_concrete", false))
	for bz2: float in [42.0, 54.0, 66.0, 78.0]:
		Props.bollard(dress, Vector3(32.6, 0, bz2), "rust")
	Props.cable(dress, Vector3(-0.6, 0.75, 42.0), Vector3(4.3, 1.9, 44.0), 0.4, 0.04, 8, "rope")
	Props.cable(dress, Vector3(14.6, 0.75, 78.0), Vector3(9.7, 1.9, 80.0), 0.4, 0.04, 8, "rope")
	Props.cable(dress, Vector3(14.6, 0.75, 42.0), Vector3(9.7, 1.9, 44.0), 0.4, 0.04, 8, "rope")
	for k: int in 6:
		_noshadow(B(Vector3(38.0 + k * 2.2, 0.005, 58.0), Vector3(38.3 + k * 2.2, 0.012, 62.0), "yellow_paint", false))
	_noshadow(B(Vector3(38.0, 0.005, 58.0), Vector3(49.6, 0.012, 58.3), "yellow_paint", false))
	_noshadow(B(Vector3(38.0, 0.005, 61.7), Vector3(49.6, 0.012, 62.0), "yellow_paint", false))
	Props.stencil(dress, Vector3(44.0, 0.02, 63.0), 0.0, "BALLAST · VERLADUNG", 36, Color(0.85, 0.82, 0.7, 0.5))
	# pilasters and a cornice along the long walls, the roof's beams, a gutter of drips
	for pz: float in [40.0, 50.0, 60.0, 70.0, 80.0]:
		B(Vector3(-20.15, 0, pz - 0.6), Vector3(-19.4, ROOF, pz + 0.6), "bunker_concrete")
		B(Vector3(51.4, 0, pz - 0.6), Vector3(52.15, ROOF, pz + 0.6), "bunker_concrete")
		B(Vector3(-20, ROOF - 0.9, pz - 0.45), Vector3(52, ROOF, pz + 0.45), "bunker_concrete")
	# the pen mouth: the steel curtain (ribbed, half down), its tracks and counterweights, the sea beyond
	for k2: int in 36:
		var cx: float = -20.0 + k2 * 2.0
		B(Vector3(cx, 2.2, 84.0), Vector3(cx + 1.9, ROOF, 84.6), "m2_curtain")
		B(Vector3(cx + 1.9, 2.2, 84.05), Vector3(cx + 2.0, ROOF, 84.55), "black_paint")
	for sx: float in [-19.6, 51.6]:
		B(Vector3(sx - 0.4, 0, 83.6), Vector3(sx + 0.4, ROOF, 84.9), "iron")
	B(Vector3(-20, 2.2, 83.9), Vector3(52, 2.6, 84.7), "iron")
	_label("SPERRTOR · TOTENHAFEN", Vector3(16, 10.5, 83.95), 180.0, 60, Color(0.85, 0.82, 0.7, 0.6))
	# catwalk frames: brackets under the decks, kick plates, a few hanging hoses and coiled rope
	for bz3: int in range(36, 84, 4):
		Props.strut(dress, Vector3(-20, CATY - 1.4, float(bz3)), Vector3(-18.2, CATY - 0.25, float(bz3)), 0.1, "iron")
		Props.strut(dress, Vector3(52, CATY - 1.4, float(bz3)), Vector3(50.2, CATY - 0.25, float(bz3)), 0.1, "iron")
	for bx3: int in range(-16, 50, 4):
		Props.strut(dress, Vector3(float(bx3), CATY - 1.4, 33), Vector3(float(bx3), CATY - 0.25, 34.8), 0.1, "iron")
	B(Vector3(-18.05, CATY, 35), Vector3(-17.95, CATY + 0.12, 84), "iron")
	B(Vector3(50.0, CATY, 35), Vector3(50.1, CATY + 0.12, 84), "iron")
	Props.rope_coil(dress, Vector3(-19.0, CATY, 50.0), 0.3)
	Props.rope_coil(dress, Vector3(51.0, CATY, 74.0), 0.3)
	# the crane: a yellow gantry across the dock, trolley, hook and a coffin in the slings over the loading square
	for lz: float in [55.5, 63.7]:
		for lx: float in [19.6, 50.8]:
			B(Vector3(lx - 0.4, 0, lz), Vector3(lx + 0.4, 9.5, lz + 0.8), "crane_yellow")
			B(Vector3(lx - 0.5, 0, lz - 0.1), Vector3(lx + 0.5, 0.3, lz + 0.9), "iron")
	for gz: float in [55.9, 64.1]:
		B(Vector3(19.2, 9.5, gz - 0.5), Vector3(51.2, 10.6, gz + 0.5), "crane_yellow")
	for k3: int in 15:
		Props.strut(dress, Vector3(20.5 + k3 * 2.0, 9.5, 55.9), Vector3(22.5 + k3 * 2.0, 10.6, 55.9), 0.1, "crane_yellow")
		Props.strut(dress, Vector3(20.5 + k3 * 2.0, 9.5, 64.1), Vector3(22.5 + k3 * 2.0, 10.6, 64.1), 0.1, "crane_yellow")
	B(Vector3(38.5, 10.6, 55.4), Vector3(41.5, 11.4, 64.6), "machine_grey")
	B(Vector3(38.8, 8.9, 58.6), Vector3(41.2, 9.5, 61.4), "machine_grey")
	# the crane office: a timber cabin on the apron, lit window, the manifest's board on its west wall
	var co: Node3D = Props.group(dress, "CraneOffice", Vector3(47, 0, 54.5), 0.0)
	Props.block(co, Vector3(-3.0, 0, -2.5), Vector3(3.0, 3.0, 2.5), "planks")
	Props.block(co, Vector3(-3.1, 3.0, -2.6), Vector3(3.1, 3.2, 2.6), "tarp")
	Props.block(co, Vector3(-3.02, 1.1, -1.6), Vector3(-2.98, 2.0, 1.0), "lantern_glass")
	Props.block(co, Vector3(-3.03, 1.0, 1.4), Vector3(-2.97, 1.1, 1.7), "beam")
	Props.block(co, Vector3(-3.03, 1.1, 1.4), Vector3(-2.97, 2.0, 1.44), "beam")
	Props.block(co, Vector3(-3.03, 0, 1.4), Vector3(-2.97, 2.2, 2.4), "beam")
	Props.block(co, Vector3(-2.6, 1.0, -2.52), Vector3(2.6, 2.0, -2.49), "window_dark")
	Props.wall_lamp(co, Vector3(-3.05, 2.5, 0.0), 90.0)
	lamp(Vector3(43.3, 2.4, 54.5), INCAND, 1.0, 8.0, 0.1)
	lamp(Vector3(47.0, 1.8, 54.5), INCAND, 0.6, 5.0, 0.05)
	_label("KRANFÜHRER", Vector3(43.97, 2.75, 54.5), -90.0, 24)
	# coffins on pallets along the east apron (the colliders are the Pallet_Coffin boxes)
	Props.coffin(dress, Vector3(38.6, 0, 40.0), 0.0, "BLST-04")
	Props.coffin(dress, Vector3(36.5, 0, 42.4), 0.0, "BLST-05")
	Props.sack(dress, Vector3(34.0, 0, 44.0), 20.0)
	for dp: Vector3 in [Vector3(34.5, 0, 48.6), Vector3(35.4, 0, 49.4)]:
		Props.oil_drum(dress, dp, "rust")
	# the pier lockers (wall-buy chalk on their faces), crates on pier 0 for the crate spot
	B(Vector3(-5.9, 0, 69), Vector3(-4.9, 2.2, 71), "machine_grey")
	B(Vector3(19.0, 0, 49), Vector3(20.0, 2.2, 51), "machine_grey")
	Props.crate(dress, Vector3(-19.0, 0, 76.0), 0.9, 12.0, "U 1047")
	Props.crate(dress, Vector3(-15.2, 0, 76.4), 0.7, -20.0)
	Props.net_pile(dress, Vector3(-17.0, 0, 44.0), Vector3(2.6, 0.7, 2.0), 13)
	Props.rope_coil(dress, Vector3(-2.0, 0, 44.0), 0.5)
	Props.life_ring(dress, Vector3(-19.83, 1.6, 60.0), -90.0)
	Props.life_ring(dress, Vector3(51.83, 1.6, 44.0), 90.0)
	# the pump stair's mouth: a hazard chevron, the pit's walls lined
	for k4: int in 6:
		_noshadow(B(Vector3(46.0 + k4 * 1.0, 0.005, 41.6), Vector3(46.5 + k4 * 1.0, 0.012, 41.9), "yellow_paint" if k4 % 2 == 0 else "black_paint", false))
	_label("PUMPENRAUM", Vector3(49.0, 2.9, 41.85), 180.0, 30)
	# lights: mercury floods high on both long walls (powered), bulkheads along the catwalks, emergency reds,
	# hurricane lanterns on the piers, the north apron's pendants
	for fz: float in [44.0, 62.0, 80.0]:
		flood("D_PENHALL", Vector3(-19.6, 9.0, fz), Vector3(-10.0, 0.0, fz + 4.0), 34.0, 8.0, 50.0, SODIUM)
		flood("D_PENHALL", Vector3(51.6, 9.0, fz), Vector3(40.0, 0.0, fz - 4.0), 34.0, 8.0, 50.0)
	flood("D_PENHALL", Vector3(16.0, 11.0, 34.0), Vector3(16.0, 0.0, 60.0), 44.0, 9.0, 44.0, MERCURY, true)   # D's key light (T-145)
	for bz4: float in [40.0, 52.0, 64.0, 76.0]:
		bulkhead("D_PENHALL", Vector3(-19.83, CATY + 1.8, bz4), -90.0, "bulb_cold")
		power("D_PENHALL", Vector3(-19.2, CATY + 1.8, bz4), 7.0, 0.4, MERCURY)
		bulkhead("D_PENHALL", Vector3(51.83, CATY + 1.8, bz4), 90.0, "bulb_cold")
		power("D_PENHALL", Vector3(51.2, CATY + 1.8, bz4), 7.0, 0.4, MERCURY)
	for px: float in [-10.0, 20.0, 38.0]:
		pendant("D_PENHALL", Vector3(px, 3.0, 35.5), ROOF - 0.9, "enamel_green", 1.2)
		power("D_PENHALL", Vector3(px, 2.8, 35.5), 9.0, 0.7, SODIUM)
	for ppx: float in [-17.0, -3.0, 17.0, 42.0]:
		for ppz: float in [50.0, 64.0, 78.0]:
			_pole_lamp("D_PENHALL", Vector3(ppx + (0.0 if ppx < 40.0 else 4.0), 0, ppz))
	lamp(Vector3(16.0, 8.0, 50.0), Color(0.5, 0.6, 0.78), 1.0, 40.0, 0.0, 0.5)
	lamp(Vector3(-8.0, 6.0, 72.0), Color(0.5, 0.6, 0.78), 0.75, 26.0, 0.0, 0.3)
	lamp(Vector3(40.0, 6.0, 72.0), Color(0.5, 0.6, 0.78), 0.75, 26.0, 0.0, 0.3)
	for e: Array in [[Vector3(-19.83, 2.8, 48.0), -90.0], [Vector3(-19.83, 2.8, 70.0), -90.0], [Vector3(51.83, 2.8, 48.0), 90.0],
			[Vector3(51.83, 2.8, 78.0), 90.0], [Vector3(0.0, 2.8, 33.17), 0.0], [Vector3(36.0, 2.8, 33.17), 0.0]]:
		emergency(e[0], float(e[1]), 0.9, 11.0)
	for hp: Vector3 in [Vector3(-16.6, 0, 60.0), Vector3(-2.6, 0, 56.0), Vector3(16.4, 0, 70.0), Vector3(34.4, 0, 58.0), Vector3(44.0, 0, 46.0)]:
		_hurricane(hp)
	lamp(Vector3(16.0, 6.0, 60.0), Color(0.5, 0.62, 0.8), 0.75, 26.0, 0.0, 0.5)
	# the signal lamp on the tower's roof: a spot on the battery, turning once the pumps run (T-154's power-on beat)
	var sl: Node3D = spinner(dress, "SignalLamp", Vector3(47.0, TY + 4.65, 35.5), Vector3.UP, 0.7, true)   # T-154: it turns with the power
	DetailMap02.signal_lamp_body(sl)
	var lens: MeshInstance3D = Props.cyl(sl, Vector3(0, 0.1, -0.33), 0.26, 0.05, "signal_glass", Vector3(90, 0, 0))
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam: SpotLight3D = SpotLight3D.new()
	beam.name = "Beam"
	beam.position = Vector3(0, 0.1, -0.4)
	beam.rotation.x = deg_to_rad(-18.0)
	beam.light_color = Color(1.0, 0.92, 0.75)
	beam.light_energy = 40.0
	beam.shadow_enabled = true   # the slab and the roofs stop it (it used to sweep the workshop through its roof)
	beam.spot_range = 70.0
	beam.spot_angle = 11.0
	beam.spot_attenuation = 0.5
	beam.light_volumetric_fog_energy = 4.0
	sl.add_child(beam)
	_bake_local(sl, false)


## U-1047 from outside (U09 s5, T-145; visibility group DH: the hall and the hatch see it): a Type VII lofted to
## real section lines over the gameplay deck (DetailMap02.type_vii: saddle tanks, the casing's slots, the red lead
## below the boot-top, bow planes, twin screws and the rudder out under the curtain), the conning tower over its
## collider (DetailMap02.vii_tower: fairing, bridge, wintergarten with the flak, periscope standards, the DF loop),
## the 8.8 cm gun, the jumping wires, the spray bulwark over the deck-edge colliders, the gangway's boards.
func _dress_uboat_hull() -> void:
	var g: Node3D = Props.group(dress, "U1047", Vector3(7.0, DECK, 38.0), 0.0)
	DetailMap02.type_vii(g, 58.6, -2.6, "m2_hull", "m2_hull_red", "iron", 48.2)   # T-180: the hull holds the interior (z 38..86.1)
	DetailMap02.vii_tower(g, Vector3(-1.1, 0.0, 17.0), 1.5, 3.0, 3.4, "U 1047")
	# the jumping wire bow to the periscope standards to the stern, weed at the high-water line
	Props.cable(g, Vector3(0, 0.0, 0.4), Vector3(-1.3, 5.8, 15.0), 0.4, 0.02, 6, "iron")
	Props.cable(g, Vector3(-1.0, 5.6, 19.0), Vector3(0, 0.6, 57.0), 0.6, 0.02, 8, "iron")
	for wz: float in [4.0, 14.0, 24.0, 34.0, 44.0]:
		for sx: float in [-3.3, 3.3]:
			_noshadow(Props.ball(g, Vector3(sx, HIGH_TIDE - DECK - 0.15, wz), Vector3(0.35, 0.25, 1.8), "weed"))
	# the guard rail over the deck-edge colliders (HullSide*, BowCap, SternCap: 1.2 m above the deck). T-180: was a
	# 1.6 m flat plate bulwark all round the deck, which read as a container's wall, not a boat: now a low toe rail on
	# the casing edge, stanchions and three wires up to the colliders' top (the barrier you bump into is the one you see)
	for gl: Array in [[Vector3(4.2, 0, 38.0), Vector3(4.2, 0, 86.0)], [Vector3(9.8, 0, 38.0), Vector3(9.8, 0, 57.0)],
			[Vector3(9.8, 0, 59.0), Vector3(9.8, 0, 86.0)], [Vector3(4.2, 0, 38.0), Vector3(9.8, 0, 38.0)],
			[Vector3(4.2, 0, 86.0), Vector3(9.8, 0, 86.0)]]:
		_guard_rail(gl[0], gl[1], DECK, DECK + 1.2, "m2_hull")
	# the bow lies against the pen's head (BowCap, z 37.4..38, reaches 0.6 m past the bow's plating): timber fenders
	# and a rope bow-pudding hung over the stem fill that gap down to the apron
	for fk: int in 9:
		var fx: float = 4.3 + fk * 0.675
		B(Vector3(fx - 0.14, 0.0, 37.42), Vector3(fx + 0.14, DECK + 1.15, 37.98), "beam")
		B(Vector3(fx - 0.17, DECK + 1.0, 37.38), Vector3(fx + 0.17, DECK + 1.2, 38.0), "iron")
	for wy: float in [0.1, 0.95, 1.75]:   # walings across the fenders
		B(Vector3(4.0, wy, 37.4), Vector3(10.0, wy + 0.2, 37.46), "beam")
	Props.cable(dress, Vector3(4.2, DECK + 1.1, 37.6), Vector3(9.8, DECK + 1.1, 37.6), 0.55, 0.13, 10, "rope")
	B(Vector3(9.6, 0.6, 57.0), Vector3(10.0, DECK, 59.0), "m2_hull")
	# the gangway: plank treads and a sign; the deck's hatch coaming
	B(Vector3(10.0, DECK + 0.0, 57.0), Vector3(10.4, DECK + 0.1, 59.0), "iron")
	_label("ZUTRITT NUR MIT AUSWEIS", Vector3(14.17, 1.9, 58.0), 90.0, 20, Color(0.85, 0.3, 0.2, 0.9))
	B(Vector3(4.9, DECK, 60.9), Vector3(7.1, DECK + 0.25, 61.0), "iron")
	B(Vector3(4.9, DECK, 60.9), Vector3(5.0, DECK + 0.25, 66.1), "iron")
	B(Vector3(7.0, DECK, 60.9), Vector3(7.1, DECK + 0.25, 66.1), "iron")
	B(Vector3(4.9, DECK, 66.0), Vector3(7.1, DECK + 0.25, 66.1), "iron")
	for k: int in 10:
		B(Vector3(10.4 + k * 0.36, DECK - 0.25 * k / 10.0 * 4.0 + 0.02, 57.05), Vector3(10.6 + k * 0.36, DECK - 0.25 * k / 10.0 * 4.0 + 0.06, 58.95), "planks")


func _dress_uboat() -> void:
	# the pressure hull from inside: plating on both sides, the bow and stern bulkheads, the deckhead
	B(Vector3(4.0, SY - 0.5, 37.9), Vector3(4.4, 0.6, 86.1), "u_interior")
	B(Vector3(9.6, SY - 0.5, 37.9), Vector3(10.0, 0.6, 86.1), "u_interior")
	B(Vector3(4.0, SY - 0.5, 37.9), Vector3(10.0, 0.6, 38.4), "u_interior").set_meta("vis", "DH")   # T-180: its top shows past the bow fenders
	B(Vector3(4.0, SY - 0.5, 85.6), Vector3(10.0, 0.6, 86.1), "u_interior")
	B(Vector3(4.0, 0.6, 38.4), Vector3(10.0, 0.62, 85.6), "u_interior")
	for s3: float in [4.4, 9.6]:
		for cz: float in [50.0, 56.0, 68.0]:
			B(Vector3(s3 - 0.25, SY, cz - 0.16), Vector3(s3 + 0.25, 0.6, cz + 0.16), "u_interior")
	# the interior: ribs, pipes and valves along both sides, battle lanterns (always lit, red), white lamps
	# (powered), the torpedo tubes and the Crucible's bay forward, bunks, the control room's wheels, the diesels aft
	for k2: int in 38:
		var rz: float = 39.0 + k2 * 1.25
		B(Vector3(4.4, SY, rz - 0.05), Vector3(4.55, 0.6, rz + 0.05), "iron")
		B(Vector3(9.45, SY, rz - 0.05), Vector3(9.6, 0.6, rz + 0.05), "iron")
		if rz > 60.9 and rz < 66.1:   # T-180: the deckhead frames stop at the hatch (one crossed the companionway)
			B(Vector3(4.4, 0.45, rz - 0.05), Vector3(5.0, 0.6, rz + 0.05), "iron")
			B(Vector3(7.0, 0.45, rz - 0.05), Vector3(9.6, 0.6, rz + 0.05), "iron")
		else:
			B(Vector3(4.4, 0.45, rz - 0.05), Vector3(9.6, 0.6, rz + 0.05), "iron")
	for py: float in [-0.2, 0.1, 0.35]:
		Props.pipe(dress, Vector3(4.6, py, 38.5), Vector3(4.6, py, 85.5), 0.04, "grey_paint" if py > 0.0 else "copper")
		Props.pipe(dress, Vector3(9.4, py, 38.5), Vector3(9.4, py, 85.5), 0.04, "grey_paint" if py > 0.0 else "red_paint")
	for vz: float in [44.0, 58.0, 63.0, 72.0]:
		Props.valve_wheel(dress, Vector3(4.62, -0.5, vz), -90.0)
		Props.gauge(dress, Vector3(9.38, -0.3, vz + 1.0), 90.0, 0.12)
	_noshadow(B(Vector3(4.4, SY, 38.0), Vector3(9.6, SY + 0.012, 86.0), "steel_grate", false))
	# torpedo room: four tube doors on the forward bulkhead, chains, a torpedo in its rack
	for tc: Array in [[5.4, -1.3], [8.6, -1.3], [5.4, 0.0], [8.6, 0.0]]:
		Props.cyl(dress, Vector3(float(tc[0]), float(tc[1]), 38.45), 0.42, 0.1, "grey_paint", Vector3(90, 0, 0))
		Props.cyl(dress, Vector3(float(tc[0]), float(tc[1]), 38.5), 0.46, 0.06, "iron", Vector3(90, 0, 0))
		for k3: int in 8:
			var a: float = TAU * float(k3) / 8.0
			Props.ball(dress, Vector3(float(tc[0]) + cos(a) * 0.5, float(tc[1]) + sin(a) * 0.5, 38.45), Vector3(0.06, 0.06, 0.06), "steel")
		Props.valve_wheel(dress, Vector3(float(tc[0]), float(tc[1]), 38.4), 0.0, 0.16, "grey_paint")
	Props.torpedo(dress, Vector3(4.95, SY + 0.6, 45.5), 0.0, 6.0, false)
	Props.stencil(dress, Vector3(7.0, 0.2, 38.42), 0.0, "BUGRAUM", 22, Color(0.85, 0.82, 0.7, 0.7))
	# bunks and lockers, the control room (chart table, wheels, the periscope well), the engine room
	for bz: float in [51.0, 53.4]:
		Props.bed(dress, Vector3(4.4, SY, bz), Vector3(5.3, SY + 0.55, bz + 2.0), "cloth_green")
		Props.bed(dress, Vector3(4.4, SY + 0.9, bz), Vector3(5.3, SY + 1.4, bz + 2.0), "cloth_green")
	Props.shelves(dress, Vector3(9.45, SY, 52.0), 90.0, 2.4, 2.2, 0.3, 4, 7)
	Props.table_visual(dress, Vector3(5.1, SY, 58.5), 1.2, 1.6, 0.9)
	Props.picture(dress, Vector3(4.42, -0.4, 58.5), -90.0, 0.8, 0.5)
	CYL(Vector3(8.8, -0.7, 60.0), 0.18, 2.6, "grey_paint")
	Props.valve_wheel(dress, Vector3(8.8, -1.0, 59.0), 180.0, 0.3, "iron")
	Props.valve_wheel(dress, Vector3(8.8, -1.0, 61.0), 0.0, 0.3, "iron")
	for dx: float in [5.0, 9.0]:
		B(Vector3(dx - 0.6, SY, 70.0), Vector3(dx + 0.6, SY + 1.6, 82.0), "machine_green")
		for k4: int in 6:
			Props.cyl(dress, Vector3(dx, SY + 1.8, 71.0 + k4 * 2.0), 0.3, 0.4, "machine_grey")
			B(Vector3(dx - 0.5, SY + 0.6, 70.4 + k4 * 2.0), Vector3(dx + 0.5, SY + 0.7, 71.6 + k4 * 2.0), "iron")
	Props.stencil(dress, Vector3(7.0, 0.2, 68.42), 0.0, "MASCHINENRAUM", 22, Color(0.85, 0.82, 0.7, 0.7))
	# the escape hatch's ladder on the stern bulkhead, up through the cut in the deck (T-229: a LadderClimb at each end,
	# map02.json ladders; the zombies' climb link Ladder_EngineHatch), the coaming round the hatch and its lid thrown back
	Props.ladder(dress, Vector3(7.0, SY, 83.15), 180.0, DECK - SY + 0.35, "iron")   # the trunk ladder, stayed to the stern bulkhead
	for sx: float in [6.8, 7.2]:
		Props.strut(dress, Vector3(sx, SY + 2.6, 83.3), Vector3(sx, SY + 2.6, 85.9), 0.025, "iron", true)
		Props.strut(dress, Vector3(sx, SY + 1.0, 83.3), Vector3(sx, SY + 1.0, 85.9), 0.025, "iron", true)
	# (the hatch's deck-level pieces draw with DH: seen from the hall as well as from inside, like the companionway, T-180)
	for e: Array in [[Vector3(6.47, DECK, 82.32), Vector3(7.53, DECK + 0.3, 82.4)], [Vector3(6.47, DECK, 83.3), Vector3(7.53, DECK + 0.3, 83.38)],
			[Vector3(6.47, DECK, 82.4), Vector3(6.55, DECK + 0.3, 83.3)], [Vector3(7.45, DECK, 82.4), Vector3(7.53, DECK + 0.3, 83.3)]]:
		B(e[0], e[1], "iron").set_meta("vis", "DH")
	Props.obox(dress, Vector3(7.0, DECK + 0.72, 83.5), Vector3(0.96, 0.05, 0.96), "machine_grey", Vector3(-105, 0, 0)).set_meta("vis", "DH")   # the lid, thrown back aft
	Props.strut(dress, Vector3(6.6, DECK + 0.3, 82.35), Vector3(6.6, DECK + 1.1, 82.35), 0.03, "iron", true).set_meta("vis", "DH")   # the grab bar
	Props.strut(dress, Vector3(6.6, DECK + 1.1, 82.35), Vector3(7.4, DECK + 1.1, 82.35), 0.03, "iron", true).set_meta("vis", "DH")
	Props.strut(dress, Vector3(7.4, DECK + 1.1, 82.35), Vector3(7.4, DECK + 0.3, 82.35), 0.03, "iron", true).set_meta("vis", "DH")
	Props.stencil(dress, Vector3(7.0, DECK + 0.18, 82.31), 0.0, "NOTAUSSTIEG", 12, Color(0.85, 0.82, 0.7, 0.8)).set_meta("vis", "DH")
	# lights inside: red battle lanterns (always), white bulkheads (powered)
	for lz: float in [42.0, 48.0, 54.0, 60.0, 66.0, 74.0, 82.0]:
		Props.bulkhead_lamp(dress, Vector3(9.44, 0.3, lz), 90.0, "lamp_red_lit")
		lamp(Vector3(9.0, 0.2, lz), RED, 0.8, 7.0, 0.06, 0.35, false, 2.0)   # T-173: 1.15 / 8 m washed the hull solid red
		Props.bulkhead_lamp(dress, Vector3(4.56, 0.3, lz - 1.5), -90.0, "lamp_red_lit")   # port side too (T-063)
		lamp(Vector3(5.0, 0.2, lz - 1.5), RED, 0.55, 6.0, 0.06, 0.25, false, 2.0)
		bulkhead("E_UBOAT", Vector3(4.56, 0.3, lz + 3.0), -90.0, "bulb_cold")
		power("E_UBOAT", Vector3(5.3, -0.3, lz + 3.0), 6.5, 0.4, MERCURY)
	emergency(Vector3(5.9, DECK + 2.2, 58.33), 180.0, 0.7, 6.0)


func _dress_lowerpens() -> void:
	var y: float = LY
	# the wet deck: drains, puddles, the columns' capitals, tide marks on the walls and columns
	_noshadow(B(Vector3(32.15, y, 50.4), Vector3(51.85, y + 0.012, 83.85), "wet_concrete", false))
	for gp: Vector3 in [Vector3(36, y, 56), Vector3(42, y, 70)]:
		_noshadow(Props.cyl(dress, gp + Vector3(0, 0.006, 0), 0.9, 0.012, "steel_grate"))
		decal(gp + Vector3(0, 0.02, 0), Vector3(3.0, 0.5, 3.0), Color(0.03, 0.06, 0.05, 0.7))
	for cx: float in [38.0, 46.0]:
		for cz: float in [58.0, 66.0, 74.0]:
			B(Vector3(cx - 0.55, -0.9, cz - 0.55), Vector3(cx + 0.55, -0.3, cz + 0.55), "bunker_concrete")
			_noshadow(B(Vector3(cx - 0.41, HIGH_TIDE - 0.4, cz - 0.41), Vector3(cx + 0.41, HIGH_TIDE + 0.2, cz + 0.41), "tide_mark", false))
	_noshadow(B(Vector3(51.82, HIGH_TIDE - 0.5, 50.3), Vector3(51.84, HIGH_TIDE + 0.25, 84), "tide_mark", false))
	_noshadow(B(Vector3(32, HIGH_TIDE - 0.5, 50.31), Vector3(52, HIGH_TIDE + 0.25, 50.33), "tide_mark", false))
	Props.puddle(dress, Vector3(40, y + 0.004, 60), 4.0, 2.4, 15.0)
	Props.puddle(dress, Vector3(47, y + 0.004, 54), 2.2, 1.6, -40.0)
	# the pumps: horizontal cylinders on bedplates, a flywheel each (spin up with the power), valves, the mains
	for px: float in [37.0, 47.0]:
		var pg: Node3D = DetailMap02.pump(dress, Vector3(px, y, 78.0), 0.0)
		Props.cyl(pg, Vector3(-1.4, 1.1, 1.6), 0.09, 1.9, "steel", Vector3(0, 0, 90))   # the lay shaft out to the flywheel
		var fw: Node3D = spinner(pg, "Flywheel", Vector3(-2.3, 1.1, 1.6), Vector3(1, 0, 0), 6.0, true)
		Props.cyl(fw, Vector3.ZERO, 1.05, 0.12, "iron", Vector3(0, 0, 90))
		for k: int in 6:
			var a: float = TAU * float(k) / 6.0
			Props.obox(fw, Vector3(0, cos(a) * 0.5, sin(a) * 0.5), Vector3(0.06, 0.1, 1.0), "iron", Vector3(rad_to_deg(a), 0, 0))
		_bake_local(fw, false)
	B(Vector3(36.9, y + 2.5, 83.7), Vector3(47.1, y + 2.7, 84.0), "rust")
	_label("GEZEITENPUMPE I", Vector3(37.0, y + 2.1, 75.99), 180.0, 22)
	_label("GEZEITENPUMPE II", Vector3(47.0, y + 2.1, 75.99), 180.0, 22)
	# the Pumpenschalter's dais and conduit, the keeper's desk and lamp, a stool, the log's shelf
	B(Vector3(50.5, y, 68.5), Vector3(52, y + 0.3, 71.5), "steel_grate")
	Props.pipe(dress, Vector3(51.8, y + 1.9, 70.0), Vector3(51.8, y + 2.6, 70.0), 0.03)
	Props.pipe(dress, Vector3(51.8, y + 2.6, 70.0), Vector3(51.8, y + 2.6, 76.0), 0.03)
	Props.fuse_box(dress, Vector3(51.83, y + 2.0, 65.0), 90.0)
	Props.table_visual(dress, Vector3(50.95, y, 63.0), 1.9, 2.0, 0.8)
	Props.stool(dress, Vector3(49.3, y, 63.0))
	Props.lantern(dress, Vector3(51.4, y + 0.8, 62.5), y + 0.8)
	lamp(Vector3(51.0, y + 1.3, 62.5), INCAND, 0.8, 6.0, 0.1)
	Props.picture(dress, Vector3(51.83, y + 1.8, 61.0), 90.0, 0.5, 0.4)
	# the sea grille at the pens' mouth with weed and ice, the west railing's chain, the stair foot
	Props.grille(dress, Vector3(32.2, y, 84.1), Vector3(51.8, y, 84.1), 2.7, 0.35, "rust")
	for wx: float in [34.0, 40.0, 46.0, 50.0]:
		_noshadow(Props.ball(dress, Vector3(wx, y + 0.3, 84.0), Vector3(1.6, 0.6, 0.4), "weed"))
	_noshadow(B(Vector3(32.2, y + 2.6, 83.9), Vector3(51.8, y + 2.9, 84.2), "snow", false))
	Props.ladder(dress, Vector3(33.0, y - 2.4, 51.0), 90.0, 2.4, "rust")
	# lights: green-cased bulkheads on the columns (powered), two emergency reds, lanterns
	for cx2: float in [38.0, 46.0]:
		for cz2: float in [58.0, 74.0]:
			bulkhead("F_LOWERPENS", Vector3(cx2, y + 2.2, cz2 - 0.41), 0.0, "bulb_cold")
			power("F_LOWERPENS", Vector3(cx2, y + 1.7, cz2 - 1.3), 8.5, 0.45, MERCURY)
	bulkhead("F_LOWERPENS", Vector3(42.0, y + 2.2, 83.7), 180.0, "bulb_warm")
	power("F_LOWERPENS", Vector3(42.0, y + 2.2, 83.0), 8.0, 0.6, SODIUM)
	emergency(Vector3(51.83, y + 2.3, 56.0), 90.0, 0.9, 10.0)
	emergency(Vector3(44.0, y + 2.3, 50.33), 180.0, 0.9, 10.0)
	_hurricane(Vector3(36.7, y, 61.0))
	_hurricane(Vector3(44.0, y + 0.3, 79.0))
	lamp(Vector3(42.0, y + 1.5, 66.0), Color(0.45, 0.6, 0.65), 0.4, 20.0, 0.0, 0.3)


func _dress_tower() -> void:
	var y: float = TY
	_noshadow(B(Vector3(42.15, y, 33.15), Vector3(51.85, y + 0.012, 37.85), "m2_quarry", false))   # T-173
	# the wireless rack and the teletype, a chart table, the signal lamp's winch, the view
	var rk: Node3D = Props.group(dress, "Rack", Vector3(51.25, y, 37.4), 0.0)
	Props.block(rk, Vector3(-0.65, 0, -0.4), Vector3(0.65, 2.2, 0.4), "machine_grey")
	for k: int in 3:
		for j: int in 1:
			Props.block(rk, Vector3(-0.5, 0.3 + k * 0.65, -0.42), Vector3(0.5, 0.8 + k * 0.65, -0.4), "black_paint")
			_noshadow(Props.cyl(rk, Vector3(0.3, 0.55 + k * 0.65, -0.43), 0.05, 0.02, "gauge_lit", Vector3(90, 0, 0)))
	Props.gauge(rk, Vector3(0.0, 1.95, -0.41), 0.0, 0.14)
	DetailMap02.teletype(dress, Vector3(51.2, y, 34.75), 90.0)
	Props.table_visual(dress, Vector3(46.0, y, 34.2), 2.2, 1.2, 0.85)
	Props.chair(dress, Vector3(46.5, y, 35.3), 0.0)
	Props.shelves(dress, Vector3(45.2, y, 37.75), 180.0, 1.6, 1.4, 0.3, 2, 9)   # (T-273: moved west off the balcony door)
	Props.fuse_box(dress, Vector3(42.17, y + 2.7, 36.6), -90.0)
	# the south window: frames and a mullion in the glass (T-273: shorter, the balcony door beside it)
	for mx: float in [45.4]:
		B(Vector3(mx - 0.04, y + 0.9, 37.85), Vector3(mx + 0.04, y + 2.6, 38.15), "iron")
	B(Vector3(43.9, y + 2.6, 37.85), Vector3(46.9, y + 2.72, 38.15), "iron")
	B(Vector3(43.9, y + 0.78, 37.85), Vector3(46.9, y + 0.9, 38.15), "iron")
	_label("SIGNALSTELLE", Vector3(42.17, y + 2.9, 35.0), 90.0, 22)
	# lights: a powered pendant and a desk lamp, the rack's standby glow
	pendant("G_SIGNAL", Vector3(47.0, y + 2.6, 35.5), y + 4.0, "enamel_green", 1.0)
	power("G_SIGNAL", Vector3(47.0, y + 2.4, 35.5), 9.0, 0.9, SODIUM)
	lamp(Vector3(46.0, y + 1.2, 34.2), INCAND, 0.7, 5.0, 0.08)
	lamp(Vector3(51.0, y + 1.3, 36.6), Color(0.4, 0.9, 0.5), 0.35, 4.0, 0.2, 0.0, false, 4.0)
	emergency(Vector3(42.17, y + 3.0, 36.5), -90.0, 0.7, 7.0)


# ================================================================== U09 s5 dressing (T-145): pieces per zone

## A CC0 library prop (PropLibrary: collision-free, pivot on the floor) under Dressing.
func _prop(key: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0) -> Node3D:
	var p: Node3D = PropLibrary.instance(key)
	if p == null:
		push_warning("gen_map02: prop %s missing" % key)
		return null
	p.position = pos
	p.rotation.y = deg_to_rad(yaw)
	p.scale = Vector3(s, s, s)
	dress.add_child(p)
	return p


## Water and rust streaks down a wall face: thin dark strips from `top` down a random length, every ~`step` m
## along the face from a to b (a, b on the face; `out` = the face's outward normal, the strips stand 1 cm proud).
func _streaks(a: Vector3, b: Vector3, out: Vector3, top: float, step: float, seed_v: int, key: String = "tide_mark") -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var n: int = int(a.distance_to(b) / step)
	for k: int in n:
		var p: Vector3 = a.lerp(b, (float(k) + rng.randf_range(0.1, 0.9)) / float(maxi(1, n)))
		var w: float = rng.randf_range(0.04, 0.22)
		var len_: float = rng.randf_range(0.8, maxf(1.0, top - a.y - 0.2))
		var y0: float = top - rng.randf_range(0.0, 0.6)
		var side: Vector3 = Vector3(out.z, 0, -out.x).abs()
		var lo: Vector3 = p - side * w * 0.5 + out * 0.005
		var hi: Vector3 = p + side * w * 0.5 + out * 0.015
		_noshadow(B(Vector3(minf(lo.x, hi.x), maxf(a.y, y0 - len_), minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), y0, maxf(lo.z, hi.z)), key, false))


## Chalk on a floor: a flat label (the dockers' tally).
func _chalk_floor(text: String, pos: Vector3, yaw: float, size: int = 48) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = Color(0.88, 0.88, 0.84, 0.75)
	l.outline_size = 0
	l.position = pos
	l.rotation = Vector3(deg_to_rad(-90), deg_to_rad(yaw), 0)
	SurfaceText.apply(l, SurfaceText.CHALK)   # T-247
	dress.add_child(l)


func _dress_u09_quay() -> void:
	# the cutter: a clinker hull listing on the quay over its collider (Cutter, x 21..30, z 2..8), stern west with a
	# flat transom carrying the M1 Carbine's board
	var cg: Node3D = Props.group(dress, "CutterHull", Vector3(31.0, 0.05, 5.0), 180.0)
	cg.rotation.x = deg_to_rad(5.0)
	cg.set_meta("keep", true)   # T-154: one piece, so it can slip into the sea at round 15
	DetailMap02.cutter(cg, 10.0, 5.8, 2.4)
	Props.block(cg, Vector3(9.88, 1.0, -2.2), Vector3(10.04, 2.58, 2.2), "planks")
	Props.block(cg, Vector3(9.88, 0.3, -1.25), Vector3(10.04, 1.0, 1.25), "planks")
	Props.stencil(cg, Vector3(1.6, 1.9, -2.72), 180.0, "TOT·HAF·7", 30, Color(0.85, 0.82, 0.7, 0.75))
	Props.stencil(cg, Vector3(1.6, 1.9, 2.72), 0.0, "TOT·HAF·7", 30, Color(0.85, 0.82, 0.7, 0.75))
	var lr: Node3D = _prop("life_ring", Vector3(24.3, 2.65, 3.92), 0.0)
	if lr != null:   # it goes with the hull
		dress.remove_child(lr)
		lr.transform = cg.transform.affine_inverse() * lr.transform
		cg.add_child(lr)
	_bake_local(cg, false)
	# the harbourmaster's hut: the door hung open, shutters hooked back, a tide table, a hurricane lamp on its hook,
	# the stove pipe's rain cap, a gutter, the halyard pole on the roof's corner
	DetailMap02.hung_door(dress, Vector3(18.0, 0, 13.5), 90.0, 1.8, DOOR_H, 100.0, T * 0.5 + 0.03, "planks")
	for wp: Array in [[Vector3(14, 0, 9.85), 180.0], [Vector3(14, 0, 17.15), 0.0]]:
		var g: Node3D = Props.group(dress, "HutShutters", wp[0], float(wp[1]))
		for s: float in [-1.0, 1.0]:
			Props.block(g, Vector3(minf(s * 0.7, s * 1.32), 1.06, 0.01), Vector3(maxf(s * 0.7, s * 1.32), 2.04, 0.05), "planks")
			Props.block(g, Vector3(minf(s * 0.74, s * 1.28), 1.5, 0.05), Vector3(maxf(s * 0.74, s * 1.28), 1.6, 0.07), "beam")
	var tt: Node3D = Props.group(dress, "TideTable", Vector3(11.4, 0, 17.16), 180.0)
	Props.block(tt, Vector3(-0.55, 1.15, -0.03), Vector3(0.55, 2.05, 0.0), "beam")
	Props.block(tt, Vector3(-0.48, 1.2, -0.04), Vector3(0.48, 1.98, -0.03), "paper")
	for r: int in 6:
		Props.block(tt, Vector3(-0.44, 1.3 + r * 0.1, -0.045), Vector3(0.44, 1.305 + r * 0.1, -0.04), "black_paint", false)
	_label("GEZEITEN  JANUAR 1945", Vector3(11.4, 1.92, 17.21), 0.0, 14, Color(0.15, 0.13, 0.1, 0.95))
	_label("HW 06.12  NW 12.31  HW 18.40", Vector3(11.4, 1.62, 17.21), 0.0, 11, Color(0.15, 0.13, 0.1, 0.9))
	Props.strut(dress, Vector3(18.16, 2.3, 16.4), Vector3(18.6, 2.3, 16.4), 0.03, "iron")
	_hurricane(Vector3(18.6, 1.78, 16.4))
	CYL(Vector3(11.0, 4.65, 11.0), 0.2, 0.05, "iron")
	Props.cone(dress, Vector3(11.0, 4.78, 11.0), 0.24, 0.16, "iron")
	B(Vector3(9.6, 3.2, 9.62), Vector3(18.4, 3.32, 9.72), "iron")
	CYL(Vector3(17.75, 3.45 + 2.6, 10.25), 0.06, 5.2, "pine")
	B(Vector3(17.15, 7.7, 10.2), Vector3(18.35, 7.76, 10.3), "pine")
	Props.cable(dress, Vector3(17.8, 8.6, 10.25), Vector3(17.85, 3.6, 10.4), 0.05, 0.008, 4, "rope")
	Props.cable(dress, Vector3(17.7, 8.6, 10.25), Vector3(17.95, 3.6, 10.1), 0.25, 0.008, 6, "rope")
	# fish crates against the cannery wall, drums and jerrycans by the bunker face, a life ring on the parapet
	for k: int in 6:
		_prop("crate_wood_a", Vector3(0.75, 0.36 * (k / 2), 3.2 + (k % 2) * 0.86), 90.0 + (k % 3) * 4.0)
	_prop("barrel_steel", Vector3(25.6, 0, 28.4), 30.0)
	for jp: Vector3 in [Vector3(24.6, 0, 28.9), Vector3(24.2, 0, 28.7), Vector3(23.9, 0, 29.1)]:
		_prop("jerrycan", jp, jp.x * 37.0)
	_prop("life_ring", Vector3(17.0, 0.12, 0.24), 0.0)
	# cleats on the parapet, gulls on its coping and a bollard
	for cx: float in [8.0, 12.0, 18.0, 22.0]:
		B(Vector3(cx - 0.18, 1.17, 0.12), Vector3(cx + 0.18, 1.22, 0.2), "iron")
		B(Vector3(cx - 0.05, 1.1, 0.12), Vector3(cx + 0.05, 1.18, 0.2), "iron")
	# (the gulls are the living world's flock now, map02_ambience.json "gulls": they scatter at the first shot)
	# the bunker face: a sealed blast door with its counterweight in a track, water and rust streaks from the top
	var bd: Node3D = Props.group(dress, "BlastDoor", Vector3(16.0, 0, 29.98), 180.0)
	Props.block(bd, Vector3(-2.0, 0.0, -0.22), Vector3(2.0, 4.2, 0.0), "m2_curtain")
	for k2: int in 6:
		Props.block(bd, Vector3(-2.0, 0.4 + k2 * 0.65, -0.26), Vector3(2.0, 0.5 + k2 * 0.65, -0.22), "iron")
	for sx: float in [-2.12, 2.0]:
		Props.block(bd, Vector3(sx, 0.0, -0.3), Vector3(sx + 0.12, 4.6, 0.0), "iron")
	Props.block(bd, Vector3(-2.12, 4.5, -0.3), Vector3(2.12, 4.62, 0.0), "iron")
	Props.cyl(bd, Vector3(2.75, 5.6, -0.25), 0.32, 0.12, "iron", Vector3(90, 0, 0))
	Props.block(bd, Vector3(2.45, 2.4, -0.38), Vector3(3.05, 3.5, -0.1), "m2_curtain")
	for sx2: float in [2.38, 3.05]:
		Props.block(bd, Vector3(sx2, 0.2, -0.16), Vector3(sx2 + 0.06, 5.4, -0.04), "iron")
	Props.cable(bd, Vector3(2.75, 5.92, -0.25), Vector3(2.75, 3.5, -0.25), 0.0, 0.02, 2, "iron")
	Props.cable(bd, Vector3(2.45, 5.6, -0.25), Vector3(1.6, 4.62, -0.25), 0.0, 0.02, 2, "iron")
	Props.stencil(bd, Vector3(0, 3.6, -0.27), 180.0, "LUFTSCHUTZ · TÜR 3", 22, Color(0.85, 0.82, 0.7, 0.6))
	_streaks(Vector3(-29.0, 0.0, 29.99), Vector3(61.0, 0.0, 29.99), Vector3(0, 0, -1), ROOF - 0.3, 1.9, 4501)
	_streaks(Vector3(4.0, 0.0, 29.985), Vector3(28.0, 0.0, 29.985), Vector3(0, 0, -1), 9.2, 3.5, 4502, "rust")
	# the breakwater's two lights blinking (red to port, green to starboard), each on a small iron tower
	for bl: Array in [[Vector3(72.0, 1.6, -44.0), RED, 0.0], [Vector3(-14.0, 1.6, -44.0), Color(0.3, 1.0, 0.45), 2.0]]:
		var bp: Vector3 = bl[0]
		var red: bool = bl[1] == RED
		CYL(bp + Vector3(0, 1.0, 0), 0.3, 2.0, "red_paint" if red else "grey_paint")
		CYL(bp + Vector3(0, 2.05, 0), 0.42, 0.1, "iron")
		var blink: OmniLight3D = OmniLight3D.new()
		blink.set_script(load("res://gravelight/world/blink_light.gd"))
		blink.name = "BreakwaterLight"
		blink.position = bp + Vector3(0, 2.45, 0)
		blink.light_color = bl[1]
		blink.omni_range = 16.0
		blink.light_volumetric_fog_energy = 2.0
		blink.set("energy_on", 3.0)
		blink.set("phase", float(bl[2]))
		blink.set_meta("keep", true)
		dress.add_child(blink)
		var glass: MeshInstance3D = Props.ball(blink, Vector3.ZERO, Vector3(0.45, 0.6, 0.45), "emergency_red" if red else "gauge_lit")
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _dress_u09_cannery() -> void:
	# the line's hook rail, scale glints on the zinc, the infirmary's screen and barrel stove, a skylight row with
	# snow on the glass, steam off the stove, the cannery's delivery book on a desk
	DetailMap02.hook_rail(dress, Vector3(-21.0, 3.1, 16.5), Vector3(-7.0, 3.1, 16.5), 5.95)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5101
	for lz: float in [13.3, 18.3]:
		for k: int in 26:
			var x: float = rng.randf_range(-21.6, -6.4)
			var z: float = lz + rng.randf_range(0.1, 1.3)
			_noshadow(Props.obox(dress, Vector3(x, 0.952, z), Vector3(0.03, 0.003, 0.02), "can_tin", Vector3(0, rng.randf() * 180.0, 0)))
	DetailMap02.screen(dress, Vector3(-28.5, 0, 6.5), 0.0)
	_prop("stove_barrel", Vector3(-22.1, 0, 8.9), 30.0)
	Props.smoke(dress, Vector3(-22.1, 3.25, 8.9), 0.1, 0.6, 8)
	DetailMap02.skylights(dress, -27.0, -3.0, 16.5, 5.99, 1.6, 6)
	Props.table_visual(dress, Vector3(-3.2, 0, 9.0), 1.2, 0.7, 0.85)
	B(Vector3(-3.5, 0.85, 8.8), Vector3(-3.0, 0.9, 9.15), "leather")
	B(Vector3(-3.48, 0.9, 8.82), Vector3(-3.02, 0.905, 9.13), "paper")
	# (T-247: the ledger's 10 px title is gone)
	Props.stool(dress, Vector3(-3.2, 0, 9.8))
	_streaks(Vector3(-29.84, 0.0, 0.5), Vector3(-29.84, 0.0, 29.5), Vector3(1, 0, 0), 5.8, 2.2, 5102)
	_streaks(Vector3(-29.5, 0.0, 0.16), Vector3(-0.5, 0.0, 0.16), Vector3(0, 0, 1), 5.8, 2.4, 5103)


func _dress_u09_workshop() -> void:
	DetailMap02.tool_wall(dress, Vector3(52.5, 0, 0.16), 180.0, 4.6)
	_prop("toolbox_metal", Vector3(51.4, 0.95, 0.36), 8.0)
	_prop("toolbox_metal", Vector3(53.7, 0.95, 0.33), -12.0)
	# the welding bench against the east wall: a bench, the welding cart, gas bottles, the arc's flicker and sparks
	Props.workbench(dress, Vector3(61.25, 0, 7.6), 90.0, 2.0, 0.8)
	_prop("welding_cart", Vector3(60.0, 0, 8.6), -100.0)
	_prop("propane_tank", Vector3(60.25, 0, 6.15), 0.0)
	_prop("propane_tank", Vector3(59.85, 0, 6.3), 40.0)
	lamp(Vector3(60.8, 1.15, 7.6), Color(0.62, 0.78, 1.0), 1.1, 6.0, 0.95, 0.3, false, 24.0)
	Props.embers(dress, Vector3(61.0, 0.95, 7.6), 0.08, 10)
	# caged bulkhead lamps round the walls; the key light is the one inside the warhead cage (shadowed)
	for bl: Array in [[Vector3(32.17, 3.2, 26.0), -90.0], [Vector3(61.83, 3.2, 12.5), 90.0], [Vector3(40.0, 3.2, 0.17), 0.0]]:
		bulkhead("C_WORKSHOP", bl[0], float(bl[1]))
		var out: Vector3 = Basis(Vector3.UP, deg_to_rad(float(bl[1]))) * Vector3(0, 0, -0.6)
		power("C_WORKSHOP", (bl[0] as Vector3) + out, 8.0, 0.55, SODIUM)
	bulkhead("C_WORKSHOP", Vector3(57.0, 2.35, 16.06), 180.0)
	power("C_WORKSHOP", Vector3(57.0, 2.1, 16.9), 9.0, 0.9, SODIUM, true)
	# two more lead coffins in the cage (on BLST-11's neighbour's footprint), the warhead manifest on the mesh
	Props.coffin(dress, Vector3(56.0, 0, 22.5), 0.0, "BLST-12")
	Props.coffin(dress, Vector3(56.0, 0.76, 22.5), 0.0, "BLST-13", false)
	var mf: Node3D = Props.group(dress, "Manifest", Vector3(54.0, 0, 16.0), 0.0)
	Props.block(mf, Vector3(-0.3, 1.3, 0.04), Vector3(0.3, 1.75, 0.05), "paper")
	# (T-247: the tally's 12 px lines are gone; the sheet stays)
	_streaks(Vector3(32.16, 0.0, 0.5), Vector3(32.16, 0.0, 29.5), Vector3(1, 0, 0), 6.8, 2.6, 5201, "rust")
	_streaks(Vector3(32.5, 0.0, 29.84), Vector3(61.5, 0.0, 29.84), Vector3(0, 0, -1), 6.8, 2.2, 5202)


func _dress_u09_penhall() -> void:
	# kerbs on every dock edge (under the railings: dressing, the agents keep 0.5 m off the rails anyway)
	for k: Array in [[-14.22, -14.0, 38.2, 83.8], [-6.0, -5.78, 38.2, 83.8], [-0.22, 0.0, 38.2, 83.8], [14.0, 14.22, 38.2, 56.8],
			[14.0, 14.22, 59.2, 83.8], [19.78, 20.0, 38.2, 83.8], [32.0, 32.22, 38.2, 83.8]]:
		B(Vector3(float(k[0]), 0.0, float(k[2])), Vector3(float(k[1]), 0.1, float(k[3])), "m2_pier")
	for k2: Array in [[-14.0, -6.0], [0.0, 14.0], [20.0, 32.0]]:
		B(Vector3(float(k2[0]), 0.0, 37.78), Vector3(float(k2[1]), 0.1, 38.0), "m2_pier")
	for pr: Array in [[-20.0, -14.0], [-6.0, 0.0], [14.0, 20.0]]:
		for cz: float in [48.0, 60.0, 72.0]:
			for ex: float in [float(pr[0]) + 0.45, float(pr[1]) - 0.45]:
				B(Vector3(ex - 0.06, 0.0, cz - 0.3), Vector3(ex + 0.06, 0.12, cz + 0.3), "iron")
				B(Vector3(ex - 0.04, 0.12, cz - 0.38), Vector3(ex + 0.04, 0.17, cz + 0.38), "iron")
	# the crane's cab under the east end of the girders, its ladder down the leg, the operator's sign
	var cab: Node3D = Props.group(dress, "CraneCab", Vector3(47.5, 7.4, 60.0), 0.0)
	Props.block(cab, Vector3(-1.5, 0, -2.6), Vector3(1.5, 2.1, 2.6), "crane_yellow")
	Props.block(cab, Vector3(-1.52, 0.9, -2.4), Vector3(-1.5, 1.8, 2.4), "window_dark")
	Props.block(cab, Vector3(-1.4, 0.9, -2.62), Vector3(1.4, 1.8, -2.6), "window_dark")
	Props.block(cab, Vector3(-1.6, 2.1, -2.7), Vector3(1.6, 2.2, 2.7), "iron")
	for sz: float in [-2.0, 2.0]:
		Props.block(cab, Vector3(-0.1, 2.2, sz - 0.1), Vector3(0.1, 2.6, sz + 0.1), "iron")
	Props.stencil(cab, Vector3(0, 1.95, -2.63), 0.0, "KRAN 2 · 8 t", 26, Color(0.1, 0.08, 0.05, 0.9))
	Props.ladder(dress, Vector3(50.25, 0.0, 56.7), -90.0, 9.4, "iron")
	Props.ladder_guard(dress, Vector3(50.25, 0.0, 56.7), -90.0, 2.3)   # (T-229: the cab is nobody's floor; the crane's ladder is locked off the way they are)
	DetailMap02.hook(dress, Vector3(40.0, 3.45, 60.0), 1.4)
	for sx: float in [-0.12, 0.12]:
		Props.cable(dress, Vector3(40.0 + sx, 8.9, 60.0), Vector3(40.0 + sx, 3.6, 60.0), 0.0, 0.02, 2, "iron")
	# the storm beyond the pen mouth (a cloud card the lightning brightens), drips from the roof into the docks,
	# the dockers' chalk tally of the ballast on pier 1, puddles on the aprons, streaks down the walls
	DetailMap02.storm_card(map_root, Vector3(16.0, 12.0, 150.0), Vector2(260.0, 70.0), 180.0).name = "StormCard_Mouth"
	DetailMap02.drips(dress, Vector3(-10.0, 11.6, 62.0), Vector3(3.0, 0.1, 14.0), 15.0, 10)
	DetailMap02.drips(dress, Vector3(26.0, 11.6, 66.0), Vector3(4.0, 0.1, 14.0), 15.0, 10)
	DetailMap02.drips(dress, Vector3(-17.0, 11.6, 70.0), Vector3(2.0, 0.1, 8.0), 11.5, 8)
	_chalk_floor("BALLAST  IIII IIII IIII", Vector3(-3.0, 0.016, 47.0), 90.0)
	for pz: Array in [[Vector3(-12.0, 0.004, 35.6), 3.0, 1.2], [Vector3(24.0, 0.004, 36.2), 4.0, 1.4], [Vector3(40.0, 0.004, 70.0), 3.2, 1.8], [Vector3(-3.0, 0.004, 64.0), 2.0, 1.0]]:
		Props.puddle(dress, pz[0], float(pz[1]), float(pz[2]), 15.0)
	_streaks(Vector3(-19.84, 0.0, 33.5), Vector3(-19.84, 0.0, 83.5), Vector3(1, 0, 0), ROOF - 0.5, 2.0, 5401)
	_streaks(Vector3(51.84, 0.0, 33.5), Vector3(51.84, 0.0, 83.5), Vector3(-1, 0, 0), ROOF - 0.5, 2.0, 5402)
	_streaks(Vector3(-19.5, 0.0, 33.16), Vector3(51.5, 0.0, 33.16), Vector3(0, 0, 1), ROOF - 0.5, 2.4, 5403)
	var lf: OmniLight3D = OmniLight3D.new()
	lf.set_script(load("res://gravelight/world/lightning_flash.gd"))
	lf.name = "Lightning"
	lf.position = Vector3(16.0, 0.8, 92.0)
	lf.omni_range = 30.0
	lf.light_color = Color(0.75, 0.82, 1.0)
	lf.light_volumetric_fog_energy = 1.5
	lf.set("peak_energy", 4.0)
	lf.set("cards", [NodePath("../StormCard_Mouth"), NodePath("../StormCard_TowerW"), NodePath("../StormCard_TowerE")] as Array[NodePath])
	lf.set_meta("keep", true)
	map_root.add_child(lf)


func _dress_u09_uboat() -> void:
	for bz: float in [50.0, 56.0, 68.0]:
		DetailMap02.round_hatch(dress, Vector3(7.0, SY, bz), 0.0, 1.8, DOOR_H, 1.0 if bz != 56.0 else -1.0)
	# overhead pipe runs under the deckhead with flanges and valves; gauges on the bulkheads
	for px: float in [5.3, 8.7]:
		if px < 7.0:   # T-180: the port run breaks at the hatch (it ran through the companionway's steps)
			Props.pipe(dress, Vector3(px, 0.42, 38.6), Vector3(px, 0.42, 60.8), 0.05, "grey_paint")
			Props.pipe(dress, Vector3(px, 0.42, 66.2), Vector3(px, 0.42, 85.4), 0.05, "grey_paint")
			Props.pipe(dress, Vector3(px, 0.42, 60.8), Vector3(4.6, 0.42, 60.8), 0.05, "grey_paint")
			Props.pipe(dress, Vector3(4.6, 0.42, 60.8), Vector3(4.6, 0.42, 66.2), 0.05, "grey_paint")
			Props.pipe(dress, Vector3(4.6, 0.42, 66.2), Vector3(px, 0.42, 66.2), 0.05, "grey_paint")
		else:
			Props.pipe(dress, Vector3(px, 0.42, 38.6), Vector3(px, 0.42, 85.4), 0.05, "grey_paint")
		for fz: int in range(40, 86, 4):
			if px > 7.0 or fz < 60 or fz > 67:
				CYL(Vector3(px, 0.42, float(fz)), 0.08, 0.05, "iron", Vector3(90, 0, 0))
		for vz: float in [46.0, 62.0, 78.0]:
			Props.valve_wheel(dress, Vector3(px if px > 7.0 or vz != 62.0 else 4.75, 0.3, vz), 0.0, 0.12, "red_paint")
	for gz: float in [49.8, 55.8, 67.8]:
		Props.gauge(dress, Vector3(5.3, -0.7, gz), 180.0, 0.1)
		Props.gauge(dress, Vector3(8.7, -0.7, gz + 0.36), 0.0, 0.1)
	# the Crucible strapped in at the forward bulkhead (webbing from its shoulders to the ribs), its violet key light
	for st: Array in [[Vector3(6.1, SY + 2.2, 40.0), Vector3(4.5, SY + 0.4, 41.2)], [Vector3(7.9, SY + 2.2, 40.0), Vector3(9.5, SY + 0.4, 41.2)],
			[Vector3(6.1, SY + 1.2, 39.0), Vector3(4.5, SY + 1.9, 39.2)], [Vector3(7.9, SY + 1.2, 39.0), Vector3(9.5, SY + 1.9, 39.2)]]:
		Props.strut(dress, st[0], st[1], 0.05, "canvas")
		B((st[1] as Vector3) - Vector3(0.06, 0.06, 0.06), (st[1] as Vector3) + Vector3(0.06, 0.06, 0.06), "iron")
	lamp(Vector3(7.0, SY + 2.3, 41.8), VIOLET, 0.9, 6.0, 0.05, 0.4, true, 2.0)
	# Deacon's map and the boat's log on the control room table
	B(Vector3(4.65, SY + 0.9, 57.9), Vector3(5.55, SY + 0.905, 59.1), "paper")
	for k: int in 5:
		B(Vector3(4.7, SY + 0.906, 58.0 + k * 0.22), Vector3(5.5, SY + 0.909, 58.01 + k * 0.22), "black_paint", false)
	B(Vector3(4.9, SY + 0.905, 59.2), Vector3(5.3, SY + 0.95, 59.5), "leather")
	# (T-247: the log book's 9 px title is gone)


func _dress_u09_lowerpens() -> void:
	var y: float = LY
	# the mains along the east wall: flanged pipe, a valve, brackets
	for pr: Array in [[y + 2.4, 0.16], [y + 1.9, 0.09]]:
		Props.pipe(dress, Vector3(51.75, float(pr[0]), 51.0), Vector3(51.75, float(pr[0]), 83.0), float(pr[1]), "rust")
		for fz: int in range(52, 83, 3):
			CYL(Vector3(51.75, float(pr[0]), float(fz)), float(pr[1]) + 0.05, 0.05, "iron", Vector3(90, 0, 0))
	for bz: int in range(52, 83, 6):
		B(Vector3(51.6, y + 2.2, float(bz) - 0.04), Vector3(51.98, y + 2.26, float(bz) + 0.04), "iron")
	# the Pumpenschalter's backplate, conduit and signs; its lamp is the zone's key light (shadowed)
	B(Vector3(51.86, y + 0.3, 68.8), Vector3(51.98, y + 2.4, 71.2), "machine_grey")
	_label("PUMPENSCHALTER", Vector3(51.84, y + 2.6, 70.0), -90.0, 22, Color(0.85, 0.82, 0.7, 0.85))
	# (T-247: the small warning under the pump switch's name is gone)
	Props.pipe(dress, Vector3(51.9, y + 2.4, 70.0), Vector3(51.9, -0.4, 70.0), 0.04)
	lamp(Vector3(50.6, y + 2.5, 70.0), INCAND, 1.0, 7.0, 0.06, 0.3, true, 6.0)
	# the drowned sailors' effects by the columns, left as they were found: a sea chest, a cap, boots, a kit bag, a photograph
	Props.trunk(dress, Vector3(48.6, y, 57.6), Vector3(49.6, y + 0.5, 58.2))
	CYL(Vector3(48.9, y + 0.53, 57.9), 0.13, 0.05, "black_paint")
	CYL(Vector3(48.9, y + 0.56, 57.9), 0.15, 0.015, "black_paint")
	for bx: float in [47.7, 47.95]:
		B(Vector3(bx, y, 58.4), Vector3(bx + 0.14, y + 0.32, 58.7), "leather")
	Props.sack(dress, Vector3(47.2, y, 57.2), 40.0, 0.9)
	Props.picture(dress, Vector3(49.1, y + 0.505, 57.8), 0.0, 0.12, 0.16)
	DetailMap02.drips(dress, Vector3(40.0, -0.45, 62.0), Vector3(5.0, 0.05, 7.0), 2.5, 8)
	DetailMap02.drips(dress, Vector3(45.0, -0.45, 77.0), Vector3(4.0, 0.05, 4.0), 2.5, 6)
	_streaks(Vector3(51.84, y, 50.5), Vector3(51.84, y, 83.5), Vector3(-1, 0, 0), -0.4, 1.6, 5601)


func _dress_u09_tower() -> void:
	var y: float = TY
	# the chart on the chart table, dividers; snow blown into the two cliff embrasures and the storm beyond them
	# (cloud cards on the closets' back walls: the embrasures open onto the cliff), the sway in the gusts
	B(Vector3(45.05, y + 0.851, 33.75), Vector3(46.95, y + 0.854, 34.65), "paper")
	for k: int in 6:
		B(Vector3(45.1, y + 0.855, 33.8 + k * 0.15), Vector3(46.9, y + 0.857, 33.805 + k * 0.15), "steel", false)
	Props.strut(dress, Vector3(45.6, y + 0.86, 34.1), Vector3(45.9, y + 0.86, 34.35), 0.01, "brass", true)
	Props.strut(dress, Vector3(45.6, y + 0.86, 34.1), Vector3(45.95, y + 0.86, 34.0), 0.01, "brass", true)
	for wx: float in [45.0, 49.0]:
		Props.snow_drift(dress, Vector3(wx, y, 31.2), Vector3(2.2, 0.22, 1.4))
		var nm: String = "StormCard_TowerW" if wx < 47.0 else "StormCard_TowerE"
		DetailMap02.storm_card(map_root, Vector3(wx, y + 1.5, 30.27), Vector2(2.6, 2.9), 0.0).name = nm
	var sw: Node3D = Node3D.new()
	sw.set_script(load("res://gravelight/world/tower_sway.gd"))
	sw.name = "TowerSway"
	sw.position = Vector3(47.0, y, 35.5)
	sw.set("size", Vector3(10.0, 4.0, 5.0))
	sw.set_meta("keep", true)
	map_root.add_child(sw)
	_streaks(Vector3(42.4, y, 33.16), Vector3(51.6, y, 33.16), Vector3(0, 0, 1), y + 3.8, 1.4, 5701)


func _dress_readability() -> void:
	# luminous strips: both edges of every pier, the apron's water edge, the catwalk edges, and the pump stair
	for pr: Array in [[-20.0, -14.0], [-6.0, 0.0], [14.0, 20.0]]:
		for sx: float in [float(pr[0]) + 0.3, float(pr[1]) - 0.3]:
			_lumi_line(Vector3(sx, 0.016, 38.3), Vector3(sx, 0.016, 83.7), 0.07)
	_lumi_line(Vector3(32.3, 0.016, 38.3), Vector3(32.3, 0.016, 83.7), 0.07)
	_lumi_line(Vector3(-19.7, 0.016, 38.3), Vector3(51.7, 0.016, 38.3), 0.06)
	_lumi_line(Vector3(-18.3, CATY + 0.016, 35.3), Vector3(-18.3, CATY + 0.016, 83.7), 0.06)
	_lumi_line(Vector3(50.3, CATY + 0.016, 35.3), Vector3(50.3, CATY + 0.016, 83.7), 0.06)
	_lumi_line(Vector3(-17.7, CATY + 0.016, 35.3), Vector3(49.7, CATY + 0.016, 35.3), 0.06)
	_lumi_line(Vector3(32.3, LY + 0.016, 50.5), Vector3(32.3, LY + 0.016, 83.7), 0.07)
	_lumi_line(Vector3(29.2, CATY + 0.04, 34.7), Vector3(40.8, TY + 0.04, 34.7), 0.06)
	# depths doorways: luminous jamb strips (door, width, yaw, depth)
	for d: Array in [[Vector3(-10, 0, 31.5), 2.0, 0.0, 3.0], [Vector3(44, 0, 31.5), 2.0, 0.0, 3.0], [Vector3(49, 0, 42), 3.0, 0.0, T],
			[Vector3(14, 0, 58), 2.0, 90.0, T], [Vector3(42, TY, 34), 2.0, 90.0, T]]:
		var g: Node3D = Props.group(dress, "LumiJambs", d[0], float(d[2]))
		var hw: float = float(d[1]) * 0.5
		var face: float = float(d[3]) * 0.5 + 0.075
		for f: float in [-1.0, 1.0]:
			for side: float in [-1.0, 1.0]:
				var x: float = side * (hw + 0.07)
				_noshadow(Props.block(g, Vector3(x - 0.025, 0.15, f * face), Vector3(x + 0.025, DOOR_H - 0.1, f * (face + 0.015)), "m2_lumi", false))


# ================================================================== visibility (T-145)

## Tags every loose visual outside the batches (lights, labels, decals, particles, kept meshes and spinners) with
## its visibility group: meta "vis_group" + the persistent node group "view_cell_member" ViewCells collects. The
## top-most node of a subtree that sits in one group is tagged (its children follow it); colliders, navigation and
## gameplay nodes are never touched. Every light also gets meta "zone" (its zone id, for the census and WebProfile).
func _tag_visibility(n: Node) -> void:
	for c: Node in n.get_children():
		if c == gameplay or c == geo or c.name == "StaticBatches" or c.name == "Navigation" or c is WorldEnvironment 				or c is DirectionalLight3D or c is FogVolume or not (c is Node3D) or c.name == "Snowfall" or c.name == "DustMotes":
			continue
		var visual: bool = c is VisualInstance3D or c.has_meta("keep") or c.get_script() != null
		if not visual:
			_tag_visibility(c)
			continue
		var p: Vector3 = _xform_to_root(c as Node3D).origin
		if c is Light3D and not c.has_meta("vis"):
			var par: Node = c.get_parent()
			if par != null and par.has_meta("vis"):
				c.set_meta("vis", par.get_meta("vis"))
		var g: String = _vis_of(c, p)
		if c is Light3D and not c.has_meta("zone"):
			c.set_meta("zone", StringName(VIS_ZONE.get(g, "GLOBAL")))
		for l: Node in c.find_children("*", "Light3D", true, false):
			if not l.has_meta("zone"):
				l.set_meta("zone", c.get_meta("zone", StringName(VIS_ZONE.get(g, "GLOBAL"))))
		if g == "ALL":
			_tag_visibility(c)
			continue
		c.set_meta("vis_group", g)
		c.add_to_group(&"view_cell_member", true)


func _add_view_cells() -> void:
	var vc: Node = Node.new()
	vc.set_script(load("res://gravelight/world/view_cells.gd"))
	vc.name = "ViewCells"
	var cells: Array = []
	for c: Array in VIEW_CELLS:
		var lo: Vector3 = c[1]
		var hi: Vector3 = c[2]
		cells.append({"name": str(c[0]), "aabb": AABB(lo, hi - lo), "show": PackedStringArray(c[3]), "moon": bool(c[4])})
	vc.set("cells", cells)
	map_root.add_child(vc)


# ================================================================== batching

## Merges every static primitive mesh (collision visuals + dressing) into one ArrayMesh per
## (material, shadow mode, 22 m cell). Subtrees tagged "keep" (power glow, spinners, water) are left alone.
func merge_static_meshes() -> int:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for holder: Node in [geo, dress]:
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or _kept(mi):
				continue
			var xf: Transform3D = _xform_to_root(mi)
			var c: Vector3 = xf.origin
			var cell: Vector3i = Vector3i(floori(c.x / 22.0), floori((c.y + 7.0) / 9.0), floori(c.z / 22.0))
			if absf(c.x - 16.0) > 90.0 or absf(c.z - 40.0) > 90.0:
				cell = Vector3i(9999, 0, 0)   # the cliffs, the town, the sea bed: one batch per material
			var vg: String = _vis_of(mi, xf * mi.mesh.get_aabb().get_center())   # T-145: batches never mix visibility groups
			var key: String = "%d|%d|%s|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, cell, vg]
			if not groups.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st, "vis": vg}
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
			victims.append(mi)
	var batch_root: Node3D = Node3D.new()
	batch_root.name = "StaticBatches"
	map_root.add_child(batch_root)
	var holders: Dictionary = {}
	var i: int = 0
	for key: String in groups.keys():
		var g: Dictionary = groups[key]
		var vg2: String = str(g["vis"])
		if not holders.has(vg2):
			var h: Node3D = Node3D.new()
			h.name = "VisGroup_" + vg2
			h.set_meta("vis_group", vg2)
			batch_root.add_child(h)
			holders[vg2] = h
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Batch_%d" % i
		out.mesh = _commit(g["st"])
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		(holders[vg2] as Node3D).add_child(out)
		i += 1
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	print("  %d batches" % i)
	return victims.size()


func _commit(st: SurfaceTool) -> ArrayMesh:
	var arrays: Array = st.commit_to_arrays()
	arrays[Mesh.ARRAY_TEX_UV] = null
	var m: ArrayMesh = ArrayMesh.new()
	var flags: int = Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES if arrays[Mesh.ARRAY_TANGENT] != null else 0
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return m


func _kept(n: Node) -> bool:
	var p: Node = n
	while p != null and p != map_root:
		if p.has_meta("keep"):
			return true
		p = p.get_parent()
	return false


func _xform_to_root(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != map_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Merges the primitive meshes under `root` into per-material meshes in root's local space.
func _bake_local(root: Node3D, direct_only: bool) -> void:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	var root_inv: Transform3D = _xform_to_root(root).affine_inverse()
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null:
			continue
		if direct_only and _owner_spinner(mi, root) != root:
			continue
		var xf: Transform3D = root_inv * _xform_to_root(mi)
		var key: String = "%d" % mi.material_override.get_instance_id()
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"mat": mi.material_override, "st": st}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
		victims.append(mi)
	for key: String in groups.keys():
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Baked"
		out.mesh = _commit(groups[key]["st"])
		out.material_override = groups[key]["mat"]
		var m: Material = groups[key]["mat"]
		if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(out)
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()


func _owner_spinner(n: Node, root: Node) -> Node:
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p.has_meta("keep"):
			return p
		p = p.get_parent()
	return root


func _prune(n: Node) -> void:
	for c: Node in n.get_children():
		_prune(c)
		if c.get_class() == "Node3D" and c.get_script() == null and c.get_child_count() == 0 and not c.has_meta("keep"):
			n.remove_child(c)
			c.free()


# ================================================================== lighting

func build_lights() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var psm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.006, 0.009, 0.02)
	psm.sky_horizon_color = Color(0.04, 0.05, 0.075)
	psm.ground_bottom_color = Color(0.008, 0.01, 0.015)
	psm.ground_horizon_color = Color(0.04, 0.05, 0.075)
	psm.sun_angle_max = 4.0
	psm.sun_curve = 0.05
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.36)
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 2.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	# bounce light (High: SDFGI + SSIL + SSR; Medium keeps SSIL; Low none — settings.gd gates them)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_energy = 2.8
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.2
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.11, 0.13, 0.17)
	env.fog_density = 0.009
	env.fog_sky_affect = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.88)
	env.volumetric_fog_emission = Color(0.015, 0.019, 0.028)
	env.volumetric_fog_length = 64.0
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_ambient_inject = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	env.adjustment_contrast = 1.1
	we.environment = env
	map_root.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.set_script(load(MOON))
	moon.name = "Moon"
	moon.set("below_y", -1.0)
	moon.light_color = Color(0.5, 0.6, 0.9)
	moon.light_energy = 0.75
	moon.light_volumetric_fog_energy = 1.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(-42), deg_to_rad(-150), 0)
	map_root.add_child(moon)
	var first: Dictionary = {}
	var i: int = 0
	for e: Dictionary in _power:
		var l: OmniLight3D = OmniLight3D.new()
		var zone: String = str(e["zone"])
		l.name = "PowerLight_%s_%d" % [zone, i]
		l.position = e["pos"]
		l.omni_range = float(e["range"])
		l.omni_attenuation = 1.0
		l.light_color = e["color"]
		l.light_energy = 0.0
		l.light_volumetric_fog_energy = 0.0
		l.shadow_enabled = bool(e["shadow"])
		l.set_meta("zone", StringName(zone))
		l.set_meta("vis", str(e.get("vis", _vis_box(e["pos"]))))
		l.set_meta("energy", float(e["energy"]) * POWER_GAIN)
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
		var sp: Dictionary = e["spot"]
		if not sp.is_empty():
			var s: SpotLight3D = SpotLight3D.new()
			s.name = "Beam"
			var dir: Vector3 = sp["dir"]
			var up: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
			s.transform = Transform3D(Basis.looking_at(dir, up), Vector3.ZERO)
			s.light_color = sp.get("color", MERCURY)
			s.light_energy = float(sp["energy"]) * 1.8
			s.spot_range = float(sp["range"])
			s.spot_angle = float(sp["angle"])
			s.spot_attenuation = 0.6
			s.light_volumetric_fog_energy = 0.35
			s.shadow_enabled = bool(sp.get("shadow", false))   # T-145: one key flood per zone casts (was every third hall flood)
			s.set_meta("zone", StringName(zone))
			l.add_child(s)
		if not first.has(zone):
			first[zone] = l
		i += 1
	for zone2: String in _glow.keys():
		var holder: Node3D = _glow[zone2]
		var host: OmniLight3D = first.get(zone2) as OmniLight3D
		if host == null:
			push_warning("gen_map02: no power light for glow zone %s" % zone2)
			continue
		var groups: Dictionary = {}
		var victims: Array[MeshInstance3D] = []
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var k: String = "%d" % mi.material_override.get_instance_id()
			if not groups.has(k):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[k] = {"mat": mi.material_override, "st": st}
			(groups[k]["st"] as SurfaceTool).append_from(mi.mesh, 0, _xform_to_root(mi))
			victims.append(mi)
		var j: int = 0
		for k2: String in groups.keys():
			var out: MeshInstance3D = MeshInstance3D.new()
			out.name = "Glow_%d" % j
			out.mesh = _commit(groups[k2]["st"])
			out.material_override = groups[k2]["mat"]
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			out.transform = host.transform.affine_inverse()
			host.add_child(out)
			j += 1
		holder.get_parent().remove_child(holder)
		holder.free()
	var si: int = 0
	for e2: Dictionary in _static_lights:
		var l2: OmniLight3D = OmniLight3D.new()
		var en: float = float(e2["energy"]) * LAMP_GAIN
		if float(e2["flicker"]) > 0.0:
			l2.set_script(load("res://gravelight/world/flicker_light.gd"))
			l2.set("base_energy", en)
			l2.set("amount", float(e2["flicker"]))
			l2.set("speed", float(e2["speed"]))
		l2.name = "Lamp_%d" % si
		l2.position = e2["pos"]
		l2.light_color = e2["color"]
		l2.light_energy = en
		l2.omni_range = float(e2["range"]) * 1.25
		l2.omni_attenuation = 1.1
		l2.light_volumetric_fog_energy = float(e2["fog"])
		l2.shadow_enabled = bool(e2["shadow"])
		var vg2: String = str(e2.get("vis", _vis_box(e2["pos"])))
		l2.set_meta("vis", vg2)
		l2.set_meta("zone", StringName(VIS_ZONE.get(vg2, "GLOBAL")))
		map_root.add_child(l2)
		si += 1
	var names: Dictionary = {}
	for e3: Dictionary in _spots:
		var s3: SpotLight3D = SpotLight3D.new()
		var n3: String = str(e3["name"])
		names[n3] = int(names.get(n3, -1)) + 1
		s3.name = n3 if int(names[n3]) == 0 else "%s_%d" % [n3, int(names[n3])]
		var dir3: Vector3 = ((e3["aim"] as Vector3) - (e3["pos"] as Vector3)).normalized()
		s3.transform = Transform3D(Basis.looking_at(dir3, Vector3.UP if absf(dir3.y) < 0.95 else Vector3.FORWARD), e3["pos"])
		s3.light_color = e3["color"]
		s3.light_energy = float(e3["energy"])
		s3.spot_range = float(e3["range"])
		s3.spot_angle = float(e3["angle"])
		s3.spot_attenuation = 0.8
		s3.spot_angle_attenuation = 1.6
		s3.light_volumetric_fog_energy = float(e3["fog"])
		s3.shadow_enabled = bool(e3["shadow"])
		s3.shadow_blur = 1.5
		var vg3: String = str(e3.get("vis", _vis_box(e3["aim"])))   # a shaft lights the room it aims into
		s3.set_meta("vis", vg3)
		s3.set_meta("zone", StringName(VIS_ZONE.get(vg3, "GLOBAL")))
		map_root.add_child(s3)
	# local fog: sea mist at the pen mouth, a cold haze over the docks, drips in the pump deck, the boat's air
	_fog("MouthMist", Vector3(16, 4, 86), Vector3(74, 10, 10), 0.05, Color(0.7, 0.78, 0.85), Color(0, 0, 0))
	_fog("DockHaze", Vector3(16, 2, 60), Vector3(70, 8, 46), 0.012, Color(0.75, 0.8, 0.9), Color(0, 0, 0))
	_fog("PensDamp", Vector3(42, LY + 1.3, 67), Vector3(20, 2.6, 34), 0.03, Color(0.6, 0.75, 0.7), Color(0, 0.002, 0.002))
	_fog("QuaySpray", Vector3(16, 1.5, 2), Vector3(34, 4, 6), 0.03, Color(0.8, 0.85, 0.9), Color(0, 0, 0))
	var post: CanvasLayer = CanvasLayer.new()
	post.set_script(load("res://gravelight/ui/postfx.gd"))
	post.name = "PostFx"
	map_root.add_child(post)


func _fog(n: String, c: Vector3, size: Vector3, density: float, albedo: Color, emission: Color) -> void:
	var fv: FogVolume = FogVolume.new()
	fv.name = n
	fv.position = c
	fv.size = size
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var fm: FogMaterial = FogMaterial.new()
	fm.density = density
	fm.albedo = albedo
	fm.emission = emission
	fm.edge_fade = 0.3
	fv.material = fm
	map_root.add_child(fv)


# ================================================================== gameplay

func _node(script: String, n: String, props: Dictionary, pos: Vector3, yaw: float = 0.0, marker: bool = false) -> Node3D:
	var node: Node3D = Marker3D.new() if marker else Node3D.new()
	if not ResourceLoader.exists(script):
		push_warning("gen_map02: %s not found; placing a plain marker for %s" % [script, n])
		node.name = n
		node.position = pos
		node.rotation.y = deg_to_rad(yaw)
		gameplay.add_child(node)
		return node
	node.set_script(load(script))
	node.name = n
	for k: String in props.keys():
		node.set(k, props[k])
	node.position = pos
	node.rotation.y = deg_to_rad(yaw)
	gameplay.add_child(node)
	return node


func build_gameplay() -> void:
	map_root.set_script(load("res://gravelight/maps/map_root.gd"))
	map_root.set("map_id", &"map02_totenhafen")
	map_root.set("display_name", "Totenhafen")
	map_root.set("start_zone", &"A_QUAY")
	map_root.set("intro_text", "TOTENHAFEN U-BUNKER\nBaltic coast, January 1945")
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map02_letzte_fahrt.json"]))   # UPDATE 10 (T-153): Letzte Fahrt
	var bits: Dictionary = {}
	for k: String in ZONE_BITS.keys():
		bits[StringName(k)] = ZONE_BITS[k]
	map_root.set("nav_zone_bits", bits)
	var adj: Dictionary = {}
	for k: String in ADJ.keys():
		adj[StringName(k)] = ADJ[k]
	map_root.set("zone_adjacency", adj)
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	map_root.add_child(gameplay)

	var i: int = 1
	for p: Vector3 in [Vector3(24, 0, 20), Vector3(26, 0, 20), Vector3(24, 0, 22), Vector3(26, 0, 22)]:
		_node("res://gravelight/maps/player_spawn.gd", "PlayerSpawn%d" % i, {}, p, 180.0, true)
		i += 1
	var zi: int = 0
	for zb: Array in ZONE_BOXES:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		_node("res://gravelight/world/zone_volume.gd", "Zone_%s_%d" % [zb[0], zi], {"zone_id": StringName(zb[0]), "size": hi - lo},
			Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5))
		zi += 1

	for w: Array in WINDOWS:
		var wp: Vector3 = w[2]
		var bar: Node3D = _node("res://gravelight/world/barricade.gd", str(w[0]), {"window_id": StringName(str(w[0])), "zone_id": StringName(str(w[1])),
			"width": 1.6, "sill_height": SILL, "top_height": WTOP}, wp, float(w[3]))
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		var dist: float = 1.7
		var spawn_pos: Vector3 = wp - inward * dist
		_node("res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {"zone_id": StringName(str(w[1])),
			"window_path": NodePath("../" + str(w[0])), "kind": &"window"}, spawn_pos, 0.0, true)
		bar.name = str(w[0])
	# ground spawns: [zone, pos, min_round]; the catwalk points start off (the tide switches them)
	var grounds: Array = [
		["A_QUAY", Vector3(2, 0, 2), 1], ["A_QUAY", Vector3(31, 0, 1.6), 1],
		["D_PENHALL", Vector3(34, 0, 82), 1],
		["E_UBOAT", Vector3(7, SY, 84.5), 1],
		["F_LOWERPENS", Vector3(36, LY, 56), 1], ["F_LOWERPENS", Vector3(42, LY, 70), 1],
	]
	var counts: Dictionary = {}
	for g: Array in grounds:
		var zn: String = str(g[0])
		var gi: int = int(counts.get(zn, 0))
		counts[zn] = gi + 1
		_node("res://gravelight/enemies/zombie_spawn.gd", "Ground_%s_%d" % [zn, gi], {"zone_id": StringName(zn), "kind": &"ground",
			"min_round": int(g[2])}, g[1], 0.0, true)
	var ci2: int = 0
	for cp: Vector3 in [Vector3(-19, CATY, 60), Vector3(20, CATY, 34), Vector3(51, CATY, 76)]:
		_node("res://gravelight/enemies/zombie_spawn.gd", "Catwalk_D_PENHALL_%d" % ci2, {"zone_id": &"D_PENHALL", "kind": &"ground",
			"min_round": 1, "enabled": false}, cp, 0.0, true)
		ci2 += 1

	for d: Array in DOORS:
		_node("res://gravelight/world/door.gd", str(d[0]), {"door_id": StringName(d[1]), "opens_zone": StringName(d[2]),
			"also_opens": PackedStringArray(d[3]), "link_group": StringName(d[4]), "cost": int(d[5]), "label": d[6],
			"size": Vector3(float(d[9]), DOOR_H, 0.25), "requires_power": d[10]}, d[7], float(d[8]))
	for b: Array in BUYS:
		_node("res://gravelight/world/wall_buy.gd", "WallBuy_" + str(b[0]), {"weapon_id": StringName(b[0])}, b[1], float(b[2]))
	# perk machines: [perk, pos (floor), yaw so local -Z faces the room]
	var perks: Array = [
		["second_wind", Vector3(-26, 0, 0.9), 180.0], ["marathon_malt", Vector3(-5, 0, 29.3), 0.0],
		["ironhide_stout", Vector3(32.8, 0, 8), -90.0], ["trigger_tonic", Vector3(40, 0, 0.8), 180.0],
		["overclock_cordial", Vector3(42.9, TY, 36.7), -90.0], ["hawkeye_brandy", Vector3(51.4, TY, 36.3), 90.0],
		# Ledger Lager (T-141): against the crane office's west wall, 2 m south of the manifest INT_M2_03; the Marinekasse's
		# pay window is on the south wall (the east end of that wall is the foot of the east stair: kept clear)
		["ledger_lager", Vector3(43.6, 0, 56.1), 90.0],
	]
	for p: Array in perks:
		_node("res://gravelight/world/perk_machine.gd", "Perk_" + str(p[0]), {"perk_id": StringName(p[0])}, p[1], float(p[2]))
	# crate spots: [name, pos, yaw, can_start, drummer route]
	var crates: Array = [
		["Hut", Vector3(16.6, 0, 11.4), 180.0, true, [Vector3(16.6, 0, 13.5), Vector3(19.5, 0, 13.5), Vector3(19.5, 0, 22)]],
		["Warheads", Vector3(58.6, 0, 19.0), 180.0, true, [Vector3(56, 0, 20), Vector3(50, 0, 20), Vector3(44, 0, 24)]],
		["Pier0", Vector3(-18.5, 0, 81.0), 0.0, false, [Vector3(-17, 0, 78), Vector3(-17, 0, 60), Vector3(-17, 0, 40)]],
		["Pumps", Vector3(42, LY, 79.0), 0.0, false, [Vector3(42, LY, 76), Vector3(42, LY, 60), Vector3(49, LY, 52)]],
		["Teletype", Vector3(49.4, TY, 34.6), 90.0, false, [Vector3(48, TY, 35), Vector3(44, TY, 35), Vector3(43, TY, 34)]],
	]
	var ci: int = 0
	for c: Array in crates:
		_node("res://gravelight/world/mystery_crate.gd", "Crate_" + str(c[0]), {"spot_index": ci, "can_start": c[3], "spot_name": c[0],
			"drummer_route": PackedVector3Array(c[4])}, c[1], float(c[2]))
		ci += 1
	# world machinery: the Pumpenschalter, the Crucible in the boat, two traps, the tide
	_node("res://gravelight/world/power_switch.gd", "Pumpenschalter", {"config_table": "map02", "label": "the Pumpenschalter",
		"requires_flag": &"ballast_loaded", "requires_text": "The pumps want ballast on the crane first",
		"zone_order": PackedStringArray(["F_LOWERPENS", "D_PENHALL", "E_UBOAT", "G_SIGNAL", "B_CANNERY", "C_WORKSHOP", "A_QUAY"])},
		Vector3(50.9, LY + 0.3, 70.0), 90.0)
	# Ballast: the coffins a player can carry, and the crane hook that wants one before the pumps will run
	var bcfg: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/map02.json")) as Dictionary).get("ballast", {})
	var bi: int = 0
	for cs: Array in bcfg.get("coffin_spots", []):
		_node("res://gravelight/world/ballast_coffin.gd", "Coffin_%d" % bi, {"coffin_id": StringName("coffin_%d" % bi), "unit": str(cs[3]), "config_table": "map02"},
			Vector3(float(cs[0]), float(cs[1]), float(cs[2])), 0.0)
		bi += 1
	var hk: Array = bcfg.get("crane_hook", [40.0, 0.0, 60.0])
	_node("res://gravelight/world/ballast_hook.gd", "BallastHook", {"config_table": "map02", "flag": StringName(str(bcfg.get("flag", "ballast_loaded")))},
		Vector3(float(hk[0]), float(hk[1]), float(hk[2])), 0.0)
	_node("res://gravelight/world/crucible.gd", "Crucible", {"needs_power": true}, Vector3(7.0, SY, 40.0), 180.0)
	for ab2: Array in AMMO_BOXES:
		_node("res://gravelight/world/ammo_box.gd", "AmmoBox_" + str(ab2[0]), {"box_name": str(ab2[0]).to_snake_case()}, ab2[1], float(ab2[2]))
	_node("res://gravelight/world/armorers_bench.gd", "ArmorersBench", {}, ARMORERS_BENCH[0], float(ARMORERS_BENCH[1]))
	var cart: Node3D = _node("res://gravelight/world/trap_ore_cart.gd", "Trap_Trolley", {"track_start": Vector3(0, 0, 0), "track_end": Vector3(0, 0, 26)}, Vector3(34, 0, 27), 90.0)
	_node("res://gravelight/world/trap_lever.gd", "Lever_Trolley", {"trap_path": NodePath("../" + cart.name), "trap_id": &"ore_cart"}, Vector3(48.0, 0, 29.6), 0.0)
	var wire: Node3D = _node("res://gravelight/world/trap_live_wire.gd", "Trap_Grille", {"size": Vector3(6.0, 2.6, 0.6)}, Vector3(49, LY, 50.9), 0.0)
	_node("res://gravelight/world/trap_lever.gd", "Lever_Grille", {"trap_path": NodePath("../" + wire.name), "trap_id": &"live_wire"}, Vector3(44.0, LY, 50.7), 180.0)
	_node(TIDE, "Tide", {"config_table": "map02", "water_path": NodePath("../../TideWater")}, Vector3.ZERO, 0.0)
	for bp: Vector3 in [Vector3(36, LY, 56), Vector3(42, LY, 70), Vector3(34, 0, 82)]:
		var m: Marker3D = Marker3D.new()
		m.name = "BurstPoint"
		m.position = bp
		m.add_to_group(&"power_burst_points", true)
		gameplay.add_child(m)


# ================================================================== UPDATE 10 s2 dressing (T-154): the living world's pieces

## The quay: the hut's interior, frozen spray on the parapet, the cutter's remnant (shown when it slips), the quay's
## icicles under the bunker's eaves, fish crates, the hut's wireless.
func _dress_u10_quay() -> void:
	# the hut inside: a pot-bellied stove under the pipe, a cot, the sea chart, oilskins, the wireless on the desk
	CYL(Vector3(11.0, 0.42, 11.0), 0.32, 0.84, "loco_black")
	CYL(Vector3(11.0, 0.87, 11.0), 0.36, 0.06, "iron")
	Props.pipe(dress, Vector3(11.0, 0.9, 11.0), Vector3(11.0, 3.2, 11.0), 0.07, "loco_black")
	_noshadow(B(Vector3(10.85, 0.18, 10.66), Vector3(11.15, 0.36, 10.68), "ember", false))
	lamp(Vector3(11.0, 0.4, 10.55), FIRE, 0.45, 3.5, 0.25, 0.0, false, 6.0)
	CYL(Vector3(11.15, 0.98, 11.05), 0.09, 0.16, "copper")
	Props.bed(dress, Vector3(13.0, 0, 16.0), Vector3(15.1, 0.45, 16.85), "cloth_green")
	for bx: float in [15.3, 15.48]:
		B(Vector3(bx, 0, 15.6), Vector3(bx + 0.14, 0.34, 15.9), "leather")
	var ch: Node3D = Props.group(dress, "SeaChart", Vector3(14.2, 0, 10.16), 180.0)
	Props.block(ch, Vector3(-0.8, 1.25, -0.02), Vector3(0.8, 2.3, 0.0), "paper_old")
	# the coast down the left, soundings in rows, the breakwater, a pencilled course and the pen marked
	Props.block(ch, Vector3(-0.78, 1.27, -0.022), Vector3(-0.42, 2.28, -0.021), "stucco", false)
	for k: int in 5:
		for j: int in 6:
			Props.block(ch, Vector3(-0.3 + j * 0.17, 1.4 + k * 0.17, -0.023), Vector3(-0.27 + j * 0.17, 1.41 + k * 0.17, -0.022), "black_paint", false)
	Props.obox(ch, Vector3(-0.15, 1.95, -0.023), Vector3(0.5, 0.012, 0.002), "black_paint", Vector3(0, 0, 8))
	Props.obox(ch, Vector3(0.2, 1.62, -0.023), Vector3(0.9, 0.006, 0.002), "red_paint", Vector3(0, 0, -24))
	Props.block(ch, Vector3(-0.47, 1.83, -0.024), Vector3(-0.4, 1.9, -0.023), "red_paint", false)
	B(Vector3(17.3, 0.9, 16.5), Vector3(17.7, 1.75, 16.68), "yellow_paint")
	var rs: Node3D = Props.group(dress, "Wireless", Vector3(10.85, 0.8, 16.35), 90.0)
	Props.block(rs, Vector3(-0.22, 0, -0.13), Vector3(0.22, 0.28, 0.13), "bakelite")
	Props.cyl(rs, Vector3(-0.08, 0.15, -0.135), 0.06, 0.01, "gauge_lit", Vector3(90, 0, 0))
	for kx: float in [0.06, 0.14]:
		Props.cyl(rs, Vector3(kx, 0.1, -0.14), 0.025, 0.02, "black_paint", Vector3(90, 0, 0))
	# frozen spray: ice over the parapet's coping and its landward face where the waves came over
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 15401
	var x: float = 2.6
	while x < 29.4:
		var w: float = rng.randf_range(0.8, 2.4)
		_noshadow(B(Vector3(x, 1.17, -0.17), Vector3(minf(29.5, x + w), 1.19, 0.17), "frosted", false))
		_noshadow(B(Vector3(x + 0.2, rng.randf_range(0.55, 0.85), 0.15), Vector3(minf(29.5, x + w * 0.8), 1.17, 0.17), "frosted", false))
		x += w + rng.randf_range(0.3, 1.6)
	# the cutter's remnant (hidden until the cutter slips at round 15; the living world shows CutterRemnantPieces):
	# the cradle's cribs and shores, the frame behind the M1 Carbine's board, the torn-off wheelhouse, the nets
	var rem: Node3D = Node3D.new()
	rem.name = "CutterRemnant"
	rem.position = Vector3(25.5, 0, 5.0)
	rem.set_meta("keep", true)
	dress.add_child(rem)
	var pc: Node3D = Props.group(rem, "CutterRemnantPieces", Vector3.ZERO, 0.0)
	# T-180: the cradle's cribs and shores stand from the start (the hull floated over the quay on nothing, its box
	# collider reaching past it into the air); only the wheelhouse, the transom frame and the nets wait for the slip
	var cradle: Node3D = Props.group(dress, "CutterCradle", rem.position, 0.0)
	for cx: float in [-3.0, -0.5, 2.0, 4.0]:
		Props.block(cradle, Vector3(cx - 0.35, 0, -0.5), Vector3(cx + 0.35, 0.55, 0.5), "beam")
		Props.strut(cradle, Vector3(cx, 0, -2.7), Vector3(cx, 1.5, -1.4), 0.14, "beam")
		Props.strut(cradle, Vector3(cx, 0, 2.7), Vector3(cx, 1.4, 1.5), 0.14, "beam")
		Props.block(cradle, Vector3(cx - 0.12, 0, -2.95), Vector3(cx + 0.12, 0.12, -2.45), "beam")   # the shores' foot blocks
		Props.block(cradle, Vector3(cx - 0.12, 0, 2.45), Vector3(cx + 0.12, 0.12, 2.95), "beam")
	for fz: float in [-1.4, 1.4]:
		Props.block(pc, Vector3(-4.62, 0, fz - 0.1), Vector3(-4.42, 2.45, fz + 0.1), "beam")
	Props.block(pc, Vector3(-4.62, 0.4, -1.35), Vector3(-4.46, 2.35, 1.35), "planks")
	var wh: Node3D = Props.group(pc, "TornWheelhouse", Vector3(-1.6, 0.0, 0.3), 20.0)
	wh.rotation.z = deg_to_rad(12.0)
	Props.block(wh, Vector3(-1.3, 0, -1.1), Vector3(1.3, 1.9, 1.1), "planks")
	Props.block(wh, Vector3(-1.42, 1.9, -1.22), Vector3(1.42, 2.02, 1.22), "m2_tarred")
	Props.block(wh, Vector3(-1.31, 0.9, -0.5), Vector3(-1.3, 1.5, 0.5), "window_dark")
	Props.net_pile(pc, Vector3(2.4, 0, 0.6), Vector3(2.8, 1.1, 2.6), 31)
	Props.cyl(pc, Vector3(0.6, 0.72, -1.2), 0.11, 7.0, "pine", Vector3(0, 0, 90))
	for k2: int in 6:
		Props.obox(pc, Vector3(rng.randf_range(-4.0, 4.0), 0.03, rng.randf_range(-2.6, 2.6)), Vector3(0.22, 0.05, rng.randf_range(1.2, 2.6)), "planks",
			Vector3(0, rng.randf_range(0, 180), rng.randf_range(-6, 6)))
	_bake_local(pc, false)
	# icicles under the bunker's eaves over the quay (they fall in the raid)
	var iq: Node3D = Node3D.new()
	iq.name = "IciclesQuay"
	iq.position = Vector3(16.0, 11.85, 29.72)
	iq.set_meta("keep", true)
	dress.add_child(iq)
	var ix: float = -26.0
	var si: int = 0
	while ix < 59.0:
		var ic: MeshInstance3D = DetailMap02.icicle_cluster(iq, Vector3(ix - 16.0, 0, 0), 0.0, 15410 + si)
		ic.add_to_group(&"m2_icicles", true)
		ix += rng.randf_range(5.0, 8.0)
		si += 1
	_fish_crate(Vector3(3.0, 0, 18.6), 20.0, 15420)
	_fish_crate(Vector3(8.6, 0, 25.4), -35.0, 15421)


## Beyond the walls: the cliff town (ruined façades and the church with its bell), the lighthouse at the end of the
## breakwater, the harbour cranes, the burning freighter and the destroyer out at sea, the dead U-boat half sunk off
## the breakwater, a storm bank on the north horizon with its own lightning (the cranes stand black against it).
func _dress_u10_horizon() -> void:
	DetailMap02.cliff_church(dress, Vector3(-40.0, 46.0, -30.0), -90.0, "CliffBellPivot")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 15430
	var k: int = 0
	for fz: float in [-50.0, -38.0, -18.0, -6.0, 6.0, 18.0]:
		DetailMap02.ruined_facade(dress, Vector3(-33.2, 46.0, fz), -90.0, rng.randf_range(6.5, 10.0), rng.randf_range(6.5, 10.0), 15431 + k)
		k += 1
	for fz2: float in [-48.0, -34.0, -20.0, -5.0, 10.0, 22.0]:
		DetailMap02.ruined_facade(dress, Vector3(65.4, 46.0, fz2), 90.0, rng.randf_range(6.5, 10.0), rng.randf_range(6.5, 10.0), 15440 + k)
		k += 1
	for fp: Vector3 in [Vector3(-33.6, 48.5, -18.0), Vector3(65.8, 49.0, 10.0)]:
		Props.flames(dress, fp, 2.4, 3.4, 26)
		Props.smoke(dress, fp + Vector3(0, 4, 0), 2.0, 9.0, 16)
	DetailMap02.lighthouse(dress, Vector3(88.0, 1.6, -44.0), 16.0)
	DetailMap02.gantry_crane(dress, Vector3(10.0, 1.6, -44.0), 0.0, 20.0, 14.0)
	DetailMap02.gantry_crane(dress, Vector3(52.0, 1.6, -44.0), 180.0, 22.0, 16.0)
	DetailMap02.burning_freighter(dress, Vector3(-80.0, -2.0, -138.0), 15.0, 70.0)
	DetailMap02.destroyer(dress, Vector3(122.0, -2.0, -126.0), 200.0)
	var ub: Node3D = Props.group(dress, "DeadUBoat", Vector3(34.0, -3.4, -57.0), 75.0)
	ub.rotation = Vector3(deg_to_rad(-9.0), deg_to_rad(75.0), deg_to_rad(21.0))
	DetailMap02.type_vii(ub, 46.0, -2.6, "rust", "m2_hull_red")
	DetailMap02.vii_tower(ub, Vector3(-1.0, 0.0, 13.0), 1.4, 2.6, 3.0, "")
	DetailMap02.storm_card(map_root, Vector3(16.0, 22.0, -152.0), Vector2(380.0, 74.0), 0.0).name = "StormCard_North"
	var lf: OmniLight3D = OmniLight3D.new()
	lf.set_script(load("res://gravelight/world/lightning_flash.gd"))
	lf.name = "Lightning_North"
	lf.position = Vector3(16.0, 40.0, -110.0)
	lf.omni_range = 170.0
	lf.omni_attenuation = 0.6
	lf.light_color = Color(0.75, 0.82, 1.0)
	lf.light_volumetric_fog_energy = 0.6
	lf.set("peak_energy", 2.2)
	lf.set("cards", [NodePath("../StormCard_North")] as Array[NodePath])
	lf.set_meta("keep", true)
	map_root.add_child(lf)


## The cannery: cans that ride the belt once the power jolts the conveyor (one mesh, scrolled by its spacing), a
## fish crate by the line.
func _dress_u10_cannery() -> void:
	var cg: Node3D = Node3D.new()
	cg.name = "ConveyorCans"
	cg.position = Vector3(-10.0, 0, 4.8)
	cg.rotation.y = deg_to_rad(90.0)
	cg.set_meta("keep", true)
	dress.add_child(cg)
	var parts: Array = []
	for k: int in int(16.0 / 0.3) - 1:
		parts.append([Props.unit_cyl(), Transform3D(Basis.from_scale(Vector3(0.1, 0.11, 0.1)), Vector3(0, 1.06, -8.0 + 0.15 + k * 0.3))])
	var cans: MeshInstance3D = MeshInstance3D.new()
	cans.name = "Cans"
	cans.mesh = DetailMap02.merged(parts, "can_tin")
	cg.add_child(cans)
	_fish_crate(Vector3(-24.0, 0, 25.6), 10.0, 15450)


## The pen hall: caged pendants on long flexes that swing in the raid, chains and pulley blocks from the roof that
## swing in the wind and after impacts, the dust points under the roof, icicles under the west catwalk, a fish
## crate on the bow apron.
func _dress_u10_penhall() -> void:
	for pp: Vector3 in [Vector3(-12.0, 7.6, 36.5), Vector3(2.0, 7.6, 36.5), Vector3(18.0, 7.6, 38.0), Vector3(30.0, 7.4, 40.5),
			Vector3(-17.0, 7.6, 56.0), Vector3(17.0, 7.6, 54.0), Vector3(-3.0, 7.6, 64.0), Vector3(24.0, 7.6, 76.0)]:
		DetailMap02.swing_pendant(dress, pp, ROOF)
		power("D_PENHALL", pp + Vector3(0, -0.2, 0), 10.0, 0.55, SODIUM)
	var s: int = 0
	for cp: Vector3 in [Vector3(-10.0, 6.4, 46.0), Vector3(-10.0, 5.6, 74.0), Vector3(7.0, 7.0, 35.6), Vector3(26.0, 6.0, 46.0),
			Vector3(26.0, 5.2, 70.0), Vector3(-17.0, 6.2, 41.0), Vector3(36.0, 6.6, 44.0)]:
		_bake_local(DetailMap02.hanging_chain(dress, cp, ROOF, 15460 + s), false)
		s += 1
	var dp: Node3D = Node3D.new()
	dp.name = "DustPoints"
	map_root.add_child(dp)
	for dx: float in [-16.0, -8.0, 0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0]:
		for dz: float in [40.0, 50.0, 60.0, 70.0, 80.0]:
			var m: Marker3D = Marker3D.new()
			m.name = "Dust"
			m.position = Vector3(dx, ROOF - 0.4, dz)
			m.add_to_group(&"m2_dust_points", true)
			dp.add_child(m)
	var ih: Node3D = Node3D.new()
	ih.name = "IciclesHall"
	ih.position = Vector3(-18.6, CATY - 0.08, 60.0)
	ih.set_meta("keep", true)
	dress.add_child(ih)
	var i: int = 0
	for iz: float in [41.0, 47.5, 53.0, 59.0, 66.5, 72.0, 79.0]:
		var ic: MeshInstance3D = DetailMap02.icicle_cluster(ih, Vector3(0, 0, iz - 60.0), 0.0, 15470 + i)
		ic.add_to_group(&"m2_icicles", true)
		i += 1
	_fish_crate(Vector3(7.6, 0, 35.2), 60.0, 15480)


## T-273 (the map detail pass): the patrol boat V 1507 lying to two buoys 20 m off the parapet, bow to the west, its
## port side and number to the quay: the landmark under open sky that round 30's dive bomber comes down on
## (map02.json sherman_event: stuka_target on its wheelhouse, stuka_hit_show its fire). Out of every visibility box but
## tagged with the quay's group, so it is drawn only where the quay is (not from the boat's interior, the lower pens or
## the tower). No collider: nobody reaches it (the parapet and the stages' kerb rails hold the quay).
const PATROL_BOAT: Array = [Vector3(16.0, -2.0, -20.0), 90.0]


func _dress_t273_sea() -> void:
	DetailMap02.patrol_boat(dress, PATROL_BOAT[0], float(PATROL_BOAT[1]))
	# one mesh per material and shadow mode for the whole boat (the 22 m batching cells would cut it into some forty
	# draw calls); _adopt_t273_batches hangs them in the quay's batch group once the batches exist
	GenDetail.merge_children(dress.get_node("PatrolBoat") as Node3D)


## T-273: the hall's new climbs. The three catwalk ladders (CATWALK_LADDERS: iron rung ladders against the catwalks'
## edges, stayed to the deck's underside, a foot plate on the floor; the LadderClimbs and the climb links are
## map02.json's) and the signal balcony's dressing: the door's frame and its rolled-up steel shutter, two beams under
## the grating and two tie rods up to the tower's roof, the zip line's post and arm over the south rail with a marker
## lamp (emissive, no light), the cable down to its landing post on the east apron, the post's stay and cap, a coil of
## rope (SIGNAL_ZIP; the trolley is the ZipLine's own).
func _dress_t273_hall() -> void:
	for cl: Array in CATWALK_LADDERS:
		var lp: Vector3 = cl[1]
		var ly: float = float(cl[2])
		Props.ladder(dress, lp, ly, CATY + 0.9, "iron")
		var st: Node3D = Props.group(dress, "LadderStays", lp, ly)
		for sx: float in [-0.2, 0.2]:
			Props.block(st, Vector3(sx - 0.025, CATY - 0.42, -0.12), Vector3(sx + 0.025, CATY - 0.36, 0.09), "iron")
			Props.block(st, Vector3(sx - 0.06, 0.0, -0.17), Vector3(sx + 0.06, 0.02, -0.06), "iron")
	# the balcony: the door's jambs and lintel, the shutter rolled up in its box over the door
	for jx: float in [BALC_DOOR_X0 - 0.06, BALC_DOOR_X1]:
		B(Vector3(jx, TY, 37.83), Vector3(jx + 0.06, TY + DOOR_H, 38.17), "iron")
	B(Vector3(BALC_DOOR_X0 - 0.06, TY + DOOR_H, 37.83), Vector3(BALC_DOOR_X1 + 0.06, TY + DOOR_H + 0.08, 38.17), "iron")
	B(Vector3(BALC_DOOR_X0 - 0.15, TY + DOOR_H + 0.08, 38.15), Vector3(BALC_DOOR_X1 + 0.15, TY + DOOR_H + 0.42, 38.47), "grey_paint")
	_noshadow(B(Vector3(BALC_DOOR_X0, TY + DOOR_H - 0.06, 38.17), Vector3(BALC_DOOR_X1, TY + DOOR_H + 0.08, 38.2), "black_paint", false))
	for bx: float in [BALC_X0 + 0.25, BALC_X1 - 0.25]:
		B(Vector3(bx - 0.08, TY - 0.45, 38.15), Vector3(bx + 0.08, TY - 0.2, BALC_Z1), "steel")
		Props.strut(dress, Vector3(bx, TY + 4.0, 38.25), Vector3(bx, TY + 1.05, BALC_Z1 - 0.1), 0.035, "iron", true)
	# the zip line: its post and arm, the marker lamp, the cable, the landing post's cap and stay, a coil of rope
	var top: Vector3 = SIGNAL_ZIP[1]
	var foot: Vector3 = SIGNAL_ZIP[2]
	var post_top: Vector3 = foot + Vector3(0, ZIP_POST_H, 0)
	var flat: Vector3 = Vector3(foot.x - top.x, 0, foot.z - top.z).normalized()
	var side: Vector3 = Vector3(-flat.z, 0, flat.x)
	var mast: Vector3 = Vector3(top.x, TY, BALC_Z1 - 0.03)
	B(mast + Vector3(-0.05, 0, -0.05), mast + Vector3(0.05, top.y - TY + 0.3, 0.05), "iron")
	Props.strut(dress, mast + Vector3(0, top.y - TY + 0.06, 0), top + Vector3(0, 0.06, 0), 0.06, "iron")
	B(top + Vector3(-0.08, -0.1, -0.08), top + Vector3(0.08, 0.1, 0.08), "iron")
	_noshadow(B(mast + Vector3(-0.06, top.y - TY + 0.3, -0.06), mast + Vector3(0.06, top.y - TY + 0.48, 0.06), "lamp_red_lit", false))
	Props.cable(dress, top, post_top, 0.3, 0.022, 20, "iron")
	B(post_top + Vector3(-0.09, -0.08, -0.09), post_top + Vector3(0.09, 0.08, 0.09), "iron")
	var stay: Vector3 = foot + flat * 1.6
	_noshadow(Props.strut(dress, post_top + Vector3(0, -0.2, 0), stay, 0.02, "iron"))
	_noshadow(B(stay + Vector3(-0.1, 0, -0.1), stay + Vector3(0.1, 0.25, 0.1), "iron"))
	_noshadow(B(foot + side * 0.1 + Vector3(-0.06, 2.0, -0.06), foot + side * 0.1 + Vector3(0.06, 2.18, 0.06), "lamp_red_lit", false))
	Props.rope_coil(dress, foot + side * 0.45 - flat * 0.3, 0.14)


## T-273: the patrol boat's folded meshes into StaticBatches/VisGroup_A (the batch container the shadow proxies and
## the view cells already work on; T-266: no new container), in map space.
func _adopt_t273_batches() -> void:
	var boat: Node3D = dress.get_node_or_null("PatrolBoat") as Node3D
	var vg: Node3D = map_root.get_node_or_null("StaticBatches/VisGroup_A") as Node3D
	if boat == null or vg == null:
		push_error("gen_map02: the patrol boat or VisGroup_A is missing")
		return
	var i: int = 0
	for c: Node in boat.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null:
			continue
		var xf: Transform3D = boat.transform * mi.transform
		boat.remove_child(mi)
		mi.transform = xf
		mi.name = "Batch_Boat_%d" % i
		vg.add_child(mi)
		i += 1


## The signal tower: rain streaking down the two embrasures' glass in front of the storm cards.
func _dress_u10_tower() -> void:
	for wx: float in [45.0, 49.0]:
		DetailMap02.rain_card(map_root, Vector3(wx, TY + 1.5, 30.45), Vector2(2.6, 2.9), 0.0)


## A spilling fish crate with its box baked to one mesh (the fish stay separate: they slide out).
func _fish_crate(pos: Vector3, yaw: float, seed_v: int) -> void:
	var g: Node3D = DetailMap02.fish_crate(dress, pos, yaw, seed_v)
	_bake_local(g.get_node("Box") as Node3D, false)


## The lower pens' columns (T-154): from the pump deck they stood in front of the pumps as plain grey boxes (the U09
## captures' "pump reads as a box"): a plinth, chamfered arrises, a painted band with the column's number, a cable
## conduit up the back. Dressing round the unchanged colliders.
func _dress_u10_lowerpens() -> void:
	var n: int = 1
	for cx: float in [38.0, 46.0]:
		for cz: float in [58.0, 66.0, 74.0]:
			var c: Vector3 = Vector3(cx, LY, cz)
			B(c + Vector3(-0.48, 0, -0.48), c + Vector3(0.48, 0.22, 0.48), "bunker_concrete")
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					Props.obox(dress, c + Vector3(sx * 0.4, 1.35, sz * 0.4), Vector3(0.09, 2.3, 0.09), "concrete", Vector3(0, 45, 0))
			_noshadow(B(c + Vector3(-0.41, 1.0, -0.41), c + Vector3(0.41, 1.35, 0.41), "enamel_white", false))
			_noshadow(B(c + Vector3(-0.415, 1.08, -0.415), c + Vector3(0.415, 1.12, 0.415), "black_paint", false))
			for face: Array in [[Vector3(0, 1.55, -0.42), 0.0], [Vector3(0, 1.55, 0.42), 180.0]]:
				_label("S %d" % n, c + (face[0] as Vector3), float(face[1]), 30, Color(0.95, 0.93, 0.85, 0.9))
			Props.pipe(dress, c + Vector3(0.3, 0.22, 0.43), c + Vector3(0.3, 2.65, 0.43), 0.035, "grey_paint")
			n += 1


# ================================================================== T-180: colliders that match their art

## Prop colliders (greybox boxes the dressing replaced, HIDE) whose art is smaller than the box: the box stays in the
## navmesh bake (group bake_only: MapRoot switches its layer off at runtime, so no baked path moves) and a convex hull
## of the dressing inside it (the box grown by `pad`) blocks players, zombies and shots instead. [name pattern, pad]
const FIT: Array = [["Brine*", 0.3], ["Pallet_Cans*", 0.3], ["Cradle*", 0.3], ["Lathe", 0.3], ["Pump1", 0.35], ["Pump2", 0.35],
	["CT_Body", 0.3], ["Stove1", 0.3], ["GutLine*", 0.3], ["Conveyor", 0.3]]
## NavBlocks under things that carry a collider of their own (the perk machines, the Crucible, the crate spots, the
## bank's counter, the ammo boxes, the Armorer's Bench): navmesh only, so an empty crate spot or the half metre round
## a machine is not an invisible box.
const BAKE_ONLY: Array = ["NavBlock_SecondWind", "NavBlock_Marathon", "NavBlock_Ironhide", "NavBlock_Trigger", "NavBlock_Overclock",
	"NavBlock_Hawkeye", "NavBlock_Ledger", "NavBlock_Bank", "NavBlock_Crate*", "NavBlock_Ammo_*", "NavBlock_ArmorersBench", "NavBlock_Crucible"]
## The tall railing colliders beside stairs and ramps (5.2 m beside the catwalk stairs, 4 m along the tower ramp and
## U-1047's companionway): an invisible wall under the flight and above the handrail. Each becomes bake_only and is
## replaced by what you see: a grating panel under the flight (from the floor to the steps' underside) and a band
## along the handrail. [rail, axis the flight runs along, the rail's line (x or z), [under-flight polygons (u, y)],
## [band polygons (u, y)]]; u is the coordinate along the axis.
const RAIL_FITS: Array = [
	["Rail_StairNW", "z", -16.0, [[[36.0, 0.0], [38.0, 0.0], [38.0, 3.8], [36.0, 3.8]], [[38.0, 0.0], [44.8, 0.0], [38.0, 3.4]]],
		[[[46.0, -0.1], [38.0, 3.9], [38.0, 5.15], [46.0, 1.15]], [[36.0, 3.9], [38.0, 3.9], [38.0, 5.15], [36.0, 5.15]]]],
	["Rail_StairE", "z", 48.0, [[[68.0, 0.0], [70.0, 0.0], [70.0, 3.8], [68.0, 3.8]], [[61.2, 0.0], [68.0, 0.0], [68.0, 3.4]]],
		[[[60.0, -0.1], [68.0, 3.9], [68.0, 5.15], [60.0, 1.15]], [[68.0, 3.9], [70.0, 3.9], [70.0, 5.15], [68.0, 5.15]]]],
	["Rail_TR", "x", 35.0, [[[31.4, 4.0], [41.0, 4.0], [41.0, 6.4]]],
		[[[29.0, 3.9], [41.0, 6.9], [41.0, 8.0], [29.0, 5.15]]]],
	["Rail_HatchW", "z", 5.0, [[[61.0, -2.0], [65.0, -2.0], [61.0, 0.4]]],
		[[[61.0, 0.9], [66.0, -2.1], [66.0, -0.85], [61.0, 2.0]], [[61.0, 0.95], [66.0, 0.95], [66.0, 2.0], [61.0, 2.0]]]],
	["Rail_HatchE", "z", 7.0, [[[61.0, -2.0], [65.0, -2.0], [61.0, 0.4]]],
		[[[61.0, 0.9], [66.0, -2.1], [66.0, -0.85], [61.0, 2.0]], [[61.0, 0.95], [66.0, 0.95], [66.0, 2.0], [61.0, 2.0]]]],
]


func _fit_colliders() -> void:
	var fits: int = 0
	for n: Node in geo.get_children():
		var body: StaticBody3D = n as StaticBody3D
		if body == null:
			continue
		var nm: String = String(n.name)
		for bo: String in BAKE_ONLY:
			if nm.match(bo):
				body.add_to_group(&"bake_only", true)
		for f: Array in FIT:
			if not nm.match(str(f[0])):
				continue
			var bb: AABB = _body_aabb(body).grow(float(f[1]))
			var pts: Array = _art_points(dress, bb, true)
			if pts.is_empty():
				push_warning("T-180: no art inside %s, its box stays" % nm)
				continue
			body.add_to_group(&"bake_only", true)
			_fit_body(nm + "_Fit", pts, 1)
			fits += 1
	# the cutter: its hull and the cradle until it slips at round 15, then the cradle and the remnant
	# (map02_ambience.json cutter_slip swaps the two bodies' layers)
	var cut: StaticBody3D = geo.get_node_or_null("Cutter") as StaticBody3D
	var hull: Node3D = dress.get_node_or_null("CutterHull") as Node3D
	var rem: Node3D = dress.get_node_or_null("CutterRemnant") as Node3D
	var cradle: Node3D = dress.get_node_or_null("CutterCradle") as Node3D
	if cut != null and hull != null and rem != null and cradle != null:
		var cb: AABB = _body_aabb(cut).grow(0.4)
		var cr: Array = _art_points(cradle, cb, false)
		var hp: Array = _art_points(hull, cb, false)
		hp.append_array(cr)
		var rp: Array = _art_points(rem, cb, false)
		rp.append_array(cr)
		cut.add_to_group(&"bake_only", true)
		_fit_body("Cutter_Fit", hp, 1)
		_fit_body("Cutter_RemnantFit", rp, 0)
		fits += 2
	# the tall rails beside the flights
	for rf: Array in RAIL_FITS:
		var rb: Node = geo.get_node_or_null(str(rf[0]))
		if rb == null:
			continue
		rb.add_to_group(&"bake_only", true)
		var shapes: Array = []
		for poly: Array in rf[3]:
			shapes.append(_prism_points(poly, str(rf[1]), float(rf[2]), 0.1))
		for poly2: Array in rf[4]:
			shapes.append(_prism_points(poly2, str(rf[1]), float(rf[2]), 0.1))
		_fit_body(str(rf[0]) + "_Fit", shapes, 1)
		fits += 1
	print("T-180: %d fitted colliders" % fits)


## The world AABB of a generator box body (axis-aligned BoxShape3D children).
func _body_aabb(body: StaticBody3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in body.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		var a: AABB = AABB(body.position + cs.position - sz * 0.5, sz)
		out = a if first else out.merge(a)
		first = false
	return out


## The parts of the meshes under `holder` inside `bb`, as point sets (root space): every connected piece of a mesh
## (a box, a cylinder, one strake; the generator's per-material bakes hold many) is one set, clipped to `bb`, so the
## fitted collider is a hull per piece and the gaps between pieces stay open. `own_only`: only meshes mostly inside
## `bb` and taller than 5 cm (a prop's parts, not the floor, a wall or a decal crossing it). Pieces under 4 points or
## flatter than 2 cm (labels, glass, stencils) are left out.
func _art_points(holder: Node, bb: AABB, own_only: bool) -> Array:
	var out: Array = []
	for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var xf: Transform3D = _xform_to_root(mi)
		var ab: AABB = xf * mi.mesh.get_aabb()
		if not ab.intersects(bb):
			continue
		if own_only:
			if ab.size.y < 0.05:
				continue
			var ab2: AABB = AABB(ab.position, ab.size.max(Vector3(0.01, 0.01, 0.01)))
			if ab2.intersection(bb).get_volume() < 0.5 * ab2.get_volume():
				continue
		var faces: PackedVector3Array = mi.mesh.get_faces()
		for i: int in faces.size():
			faces[i] = xf * faces[i]
		for part: PackedVector3Array in _pieces(faces):
			var pts: PackedVector3Array = PackedVector3Array()
			var lo: Vector3 = Vector3.INF
			var hi: Vector3 = -Vector3.INF
			for w: Vector3 in part:
				if bb.has_point(w):
					pts.append(w)
					lo = lo.min(w)
					hi = hi.max(w)
			if pts.size() >= 4 and (hi - lo)[(hi - lo).min_axis_index()] >= 0.02:
				out.append(pts)
	return out


## The connected pieces of a triangle soup (triangles sharing a vertex, on a 1 mm grid), each as its unique points.
static func _pieces(faces: PackedVector3Array) -> Array:
	var parent: Array[int] = []
	var ids: Dictionary = {}
	var pts: PackedVector3Array = PackedVector3Array()
	var tri_ids: PackedInt32Array = PackedInt32Array()
	for v: Vector3 in faces:
		var key: Vector3i = Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
		var id: int = ids.get(key, -1)
		if id < 0:
			id = pts.size()
			ids[key] = id
			pts.append(v)
			parent.append(id)
		tri_ids.append(id)
	for t: int in tri_ids.size() / 3:
		var a: int = _root(parent, tri_ids[t * 3])
		for k: int in [1, 2]:
			var b: int = _root(parent, tri_ids[t * 3 + k])
			if a != b:
				parent[b] = a
	var groups: Dictionary = {}
	for i: int in pts.size():
		var r: int = _root(parent, i)
		if not groups.has(r):
			groups[r] = PackedVector3Array()
		var g: PackedVector3Array = groups[r]
		g.append(pts[i])
		groups[r] = g
	return groups.values()


static func _root(parent: Array[int], x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


## A static body on the world layer (or off: `layer` 0) holding one convex hull per point set.
func _fit_body(n: String, sets: Array, layer: int) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta("t180_fit", true)
	for pts: Variant in sets:
		var v: PackedVector3Array = pts
		while v.size() % 3 != 0:
			v.append(v[0])
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		var am: ArrayMesh = ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = am.create_convex_shape(true, false)
		body.add_child(cs)
	geo.add_child(body)


## A convex polygon given as (u, y) pairs on the plane x = c (axis "z") or z = c (axis "x"), extruded `t` thick: its
## corner points (the first face, then the second, in the polygon's order).
func _prism_points(poly: Array, axis: String, c: float, t: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for s: float in [-t * 0.5, t * 0.5]:
		for q: Array in poly:
			out.append(Vector3(c + s, float(q[1]), float(q[0])) if axis == "z" else Vector3(float(q[0]), float(q[1]), c + s))
	return out


## A thin panel (a convex polygon (u, y) on the plane x = c / z = c, `t` thick) as a closed mesh under Dressing, its
## origin at the polygon's centre so the visibility boxes find it.
func _panel(n: String, poly: Array, axis: String, c: float, t: float, key: String) -> MeshInstance3D:
	var pts: PackedVector3Array = _prism_points(poly, axis, c, t)
	var k: int = poly.size()
	var cen: Vector3 = Vector3.ZERO
	for p: Vector3 in pts:
		cen += p
	cen /= float(pts.size())
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = []
	for i: int in range(1, k - 1):   # the two caps, fanned
		faces.append([pts[0], pts[i], pts[i + 1]])
		faces.append([pts[k], pts[k + i + 1], pts[k + i]])
	for i2: int in k:   # the rim
		var j: int = (i2 + 1) % k
		faces.append([pts[i2], pts[k + i2], pts[k + j]])
		faces.append([pts[i2], pts[k + j], pts[j]])
	for f: Array in faces:
		var a: Vector3 = (f[0] as Vector3) - cen
		var b: Vector3 = (f[1] as Vector3) - cen
		var d: Vector3 = (f[2] as Vector3) - cen
		var nrm: Vector3 = (b - a).cross(d - a).normalized()
		if nrm.dot((a + b + d) / 3.0) < 0.0:   # outward from the centre (the prism is convex)
			var tmp: Vector3 = b
			b = d
			d = tmp
			nrm = -nrm
		# Godot's front faces wind clockwise seen from outside
		for p2: Vector3 in [a, d, b]:
			st.set_normal(nrm)
			st.add_vertex(p2)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = Mats.get_mat(key)
	mi.position = cen
	dress.add_child(mi)
	return mi


## A guard rail along a -> b (their y ignored): a toe strip on the floor (`toe` key, "" for none), stanchions and
## three wires from `y0` up to `y1`.
func _guard_rail(a: Vector3, b: Vector3, y0: float, y1: float, toe: String = "") -> void:
	var a0: Vector3 = Vector3(a.x, y0, a.z)
	var b0: Vector3 = Vector3(b.x, y0, b.z)
	var d: Vector3 = b0 - a0
	var along_x: bool = absf(d.x) > absf(d.z)
	if toe != "":
		var w: Vector3 = Vector3(0, 0, 0.07) if along_x else Vector3(0.07, 0, 0)
		B(a0.min(b0) - w, a0.max(b0) + w + Vector3(0, 0.12, 0), toe)
	var posts: int = maxi(1, int(ceil(d.length() / 1.4)))
	for k: int in posts + 1:
		var p: Vector3 = a0 + d * (float(k) / float(posts))
		B(p + Vector3(-0.03, 0.0, -0.03), Vector3(p.x + 0.03, y1, p.z + 0.03), "iron")
	for h: float in [0.36, 0.68, 1.0]:
		var y: float = lerpf(y0, y1, h)
		Props.strut(dress, Vector3(a0.x, y, a0.z), Vector3(b0.x, y, b0.z), 0.025 if h < 1.0 else 0.04, "iron", true)


## The art of the T-180 fits and guard rails: grating panels under the flights, the hatch's guard rail, the
## gangway's canvas screens, the catwalk stairs' landings, U-1047's bulkheads.
func _dress_t180() -> void:
	for rf: Array in RAIL_FITS:
		var nm: String = str(rf[0])
		var k: int = 0
		for poly: Array in rf[3]:
			_panel("%s_Infill%d" % [nm, k], poly, str(rf[1]), float(rf[2]), 0.04, "m2_grate")
			# a steel angle round the panel's edge
			var c: float = float(rf[2])
			for i: int in poly.size():
				var q0: Array = poly[i]
				var q1: Array = poly[(i + 1) % poly.size()]
				var p0: Vector3 = Vector3(c, float(q0[1]), float(q0[0])) if str(rf[1]) == "z" else Vector3(float(q0[0]), float(q0[1]), c)
				var p1: Vector3 = Vector3(c, float(q1[1]), float(q1[0])) if str(rf[1]) == "z" else Vector3(float(q1[0]), float(q1[1]), c)
				Props.strut(dress, p0, p1, 0.06, "rust" if nm.begins_with("Rail_Hatch") else "iron")
			k += 1
	# the catwalk stairs' top landings had no railing on their open side (the 5.2 m box stood there unseen)
	Props.railing(dress, Vector3(-16.0, CATY, 36.05), Vector3(-16.0, CATY, 37.95), 1.05, "iron", 1.0)
	Props.railing(dress, Vector3(48.0, CATY, 68.05), Vector3(48.0, CATY, 69.95), 1.05, "iron", 1.0)
	# U-1047's hatch: a guard rail up to the colliders' top on the deck (the coaming alone was 25 cm)
	for hx: float in [5.0, 7.0]:
		_guard_rail(Vector3(hx, 0, 61.0), Vector3(hx, 0, 66.0), DECK + 0.25, 2.0)
	# the gangway (Rail_GW1/2, 2.2 m over a 0..1 m ramp): canvas screens laced to stanchions, a sloped handrail
	for gz: float in [57.0, 59.0]:
		_panel("GangwayScreen", [[14.0, 0.05], [10.0, 1.05], [10.0, 2.2], [14.0, 2.2]], "x", gz, 0.03, "canvas")
		var inward: float = 0.06 if gz < 58.0 else -0.06
		for gx: float in [14.0, 12.67, 11.33, 10.0]:
			var ty: float = lerpf(0.0, DECK, (14.0 - gx) / 4.0)
			B(Vector3(gx - 0.03, ty, gz - 0.05), Vector3(gx + 0.03, 2.25, gz + 0.05), "iron")
		Props.strut(dress, Vector3(14.0, 2.22, gz), Vector3(10.0, 2.22, gz), 0.04, "rope", true)
		Props.strut(dress, Vector3(14.0, 1.0, gz + inward), Vector3(10.0, 2.0, gz + inward), 0.045, "iron", true)
	_bulkheads()


## U-1047's three watertight bulkheads (Bulkhead1..3, z 50 / 56 / 68): the colliders were never drawn, only the
## oval door rims and strips at the hull, so you looked straight through the wall beside the door you had to use.
## Plating on both faces round an oval cut-out the size of the rim, stiffeners, rivets and a builder's plate.
func _bulkheads() -> void:
	var cx: float = 7.0
	var cy: float = SY + DOOR_H * 0.5
	var rx: float = 0.9 + 0.12
	var ry: float = DOOR_H * 0.5 + 0.1
	var n: int = 32
	for bz: float in [50.0, 56.0, 68.0]:
		for f: float in [-0.15, 0.15]:
			var nz: float = signf(f)
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var ring: Array = []
			var outer: Array = []
			for k: int in n + 1:
				var a: float = TAU * float(k) / float(n)
				var dir: Vector2 = Vector2(cos(a) * rx, sin(a) * ry)
				var p: Vector2 = Vector2(cx, cy) + dir
				p.y = maxf(p.y, SY)
				ring.append(p)
				# the plating's edge (x 4.4 .. 9.6, y SY .. 0.6) out along the same direction, snapped to its corners
				# near them so the fan covers the whole plate
				var tx: float = (2.6 / absf(dir.x)) if absf(dir.x) > 0.0001 else 1e9
				var ty: float = ((0.6 - cy) / dir.y) if dir.y > 0.0001 else (((SY - cy) / dir.y) if dir.y < -0.0001 else 1e9)
				var q: Vector2 = Vector2(cx, cy) + dir * minf(tx, ty)
				outer.append(Vector2(clampf(q.x, 4.4, 9.6), clampf(q.y, SY, 0.6)))
			var corners: Array = [Vector2(9.6, 0.6), Vector2(4.4, 0.6), Vector2(4.4, SY), Vector2(9.6, SY)]
			var quads: Array = []
			for k2: int in n:
				quads.append([ring[k2], outer[k2], outer[k2 + 1], ring[k2 + 1]])
				# a corner of the plate between two rays: one more triangle to it
				for cn: Vector2 in corners:
					var o0: Vector2 = outer[k2]
					var o1: Vector2 = outer[k2 + 1]
					if (is_equal_approx(o0.x, cn.x) and is_equal_approx(o1.y, cn.y)) or (is_equal_approx(o0.y, cn.y) and is_equal_approx(o1.x, cn.x)):
						quads.append([o0, cn, o1, o1])
			for qd: Array in quads:
				for t: Array in [[qd[0], qd[1], qd[2]], [qd[0], qd[2], qd[3]]]:
					var v0: Vector2 = t[0]
					var v1: Vector2 = t[1]
					var v2: Vector2 = t[2]
					var cr: float = (v1 - v0).cross(v2 - v0)
					if absf(cr) < 0.00001:
						continue
					# clockwise seen from the face's side (+z face seen from +z: negative cross in x-right, y-up)
					var order: Array = [v0, v1, v2] if (cr < 0.0) == (nz > 0.0) else [v0, v2, v1]
					for v: Vector2 in order:
						st.set_normal(Vector3(0, 0, nz))
						st.add_vertex(Vector3(v.x - cx, v.y - cy, f))
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "Bulkhead%dPlate" % int(bz)
			mi.mesh = st.commit()
			mi.material_override = Mats.get_mat("u_interior")
			mi.position = Vector3(cx, cy, bz)
			dress.add_child(mi)
			# stiffeners clear of the cut-out, a seam strap under the deckhead and its rivets
			var z_in: float = bz + f + 0.04 * nz
			B(Vector3(4.89, SY, minf(bz + f, z_in)), Vector3(5.01, 0.6, maxf(bz + f, z_in)), "grey_paint")
			B(Vector3(8.99, SY, minf(bz + f, z_in)), Vector3(9.11, 0.6, maxf(bz + f, z_in)), "grey_paint")
			B(Vector3(4.4, 0.42, minf(bz + f, z_in)), Vector3(9.6, 0.52, maxf(bz + f, z_in)), "grey_paint")
			for rv: int in 18:
				Props.ball(dress, Vector3(4.62 + rv * 0.28, 0.33, bz + f + 0.02 * nz), Vector3(0.035, 0.035, 0.02), "iron")
		var plate: Vector3 = Vector3(5.6, -0.2, bz - 0.16)
		B(plate - Vector3(0.18, 0.1, 0.01), plate + Vector3(0.18, 0.1, 0.0), "brass")
