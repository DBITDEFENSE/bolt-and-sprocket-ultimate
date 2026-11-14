extends SceneTree
## Generates Map 1 "Kaltenbrunn" from docs/MAPS.md: the collision shell, per-zone navmesh regions on separate
## navigation layers, an art-dressing pass (procedural materials, props, weather, lighting, post), and every
## gameplay node.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map01.gd
## Source of truth for the map (D-024). Vertical distances are compressed (D-043):
## surface y = 0, depths (Chapel/Generator/Lab) y = -12, the Core y = -18.
##
## Layers are kept apart on purpose (as in gen_map00):
##   - build_surface() .. build_closets(): the collision shell ("Geometry"). Only its StaticBodies feed the
##     navmesh bake, and node names/collisions are unchanged from the greybox.
##   - build_dressing(): everything decorative ("Dressing"), non-colliding, so the art never changes navigation.
##     Greybox stand-in visuals listed in HIDE keep their colliders but are redrawn by the dressing pass.
##   - Lamps that need power put their glowing parts in a per-zone holder that ends up parented under that
##     zone's power light, so the PowerSwitch's light sweep turns them on with the light (no extra script).
## Static meshes are merged into per-material batches at bake time (merge_static_meshes).
##
## Frame: +X east, +Z south. Yard north wall at z = 0.

const OUT: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const SPINNER: String = "res://gravelight/maps/map01_kaltenbrunn/power_spinner.gd"
const GRADE: String = "res://gravelight/maps/map01_kaltenbrunn/depth_grade.gd"
const T: float = 0.3
const DY: float = -12.0      # depths floor
const CY: float = -18.0      # core floor
const SILL: float = 0.9
const WTOP: float = 2.2
const DOOR_H: float = 2.4
const DW: float = 2.6        # a doorway's width (door()'s default, the Door nodes' size.x)

## Nav layer bit per zone (1-based).
const ZONE_BITS: Dictionary = {
	"A_MINEHEAD": 1, "B_RAILYARD": 2, "C_ADMIN": 3, "D_BARRACKS": 4, "E_LIFT": 5, "M_STAIRS": 6,
	"F_CHAPEL": 7, "G_GENERATOR": 8, "H_LAB": 9, "I_CORE": 10,
}
const ADJ: Dictionary = {
	"A_MINEHEAD": ["B_RAILYARD", "C_ADMIN"], "B_RAILYARD": ["A_MINEHEAD", "D_BARRACKS"],
	"C_ADMIN": ["A_MINEHEAD", "D_BARRACKS"], "D_BARRACKS": ["B_RAILYARD", "C_ADMIN", "E_LIFT", "M_STAIRS"],
	"E_LIFT": ["D_BARRACKS", "F_CHAPEL"], "M_STAIRS": ["D_BARRACKS", "F_CHAPEL"],
	"F_CHAPEL": ["E_LIFT", "M_STAIRS", "G_GENERATOR", "I_CORE"], "G_GENERATOR": ["F_CHAPEL", "H_LAB", "I_CORE"],
	"H_LAB": ["G_GENERATOR", "I_CORE"], "I_CORE": ["F_CHAPEL", "G_GENERATOR", "H_LAB"],
}
## Navigation / zone boxes: [zone, min, max]. Boxes must not overlap.
const ZONE_BOXES: Array = [
	["A_MINEHEAD", Vector3(0, -1, 0), Vector3(40, 9, 32)],
	["B_RAILYARD", Vector3(40, -1, 14), Vector3(60, 9, 48)],
	["C_ADMIN", Vector3(-16, -1, 8), Vector3(0, 9, 32)],
	["D_BARRACKS", Vector3(-16, -1, 32), Vector3(40, 9, 46)],
	["E_LIFT", Vector3(20, -13, 46), Vector3(30, 9, 60)],
	["M_STAIRS", Vector3(-16, -13, 46), Vector3(-4, 5, 60)],
	["F_CHAPEL", Vector3(-16, -13, 60), Vector3(40, 3, 90)],
	["G_GENERATOR", Vector3(40, -13, 60), Vector3(84, -1, 82)],
	["H_LAB", Vector3(52, -13, 82), Vector3(102, -7, 98)],
	["I_CORE", Vector3(17, -19, 82), Vector3(77, -12.4, 139)],
]
## Navigation links through every doorway: [from, to, zone whose layer gates the link].
## Regions are baked per zone, so their edges stop short of the door; links bridge the gap.
const LINKS: Array = [
	[Vector3(38.8, 0, 25), Vector3(41.2, 0, 25), "B_RAILYARD"],
	[Vector3(1.2, 0, 25), Vector3(-1.2, 0, 25), "C_ADMIN"],
	[Vector3(-8, 0, 30.6), Vector3(-8, 0, 33.4), "D_BARRACKS"],
	[Vector3(41.2, 0, 40), Vector3(38.8, 0, 40), "D_BARRACKS"],
	[Vector3(25, 0, 44.6), Vector3(25, 0, 47.4), "E_LIFT"],
	[Vector3(-10, 0, 44.6), Vector3(-10, 0, 47.2), "M_STAIRS"],
	[Vector3(-12, -12, 58.6), Vector3(-12, -12, 61.4), "M_STAIRS"],
	[Vector3(25, -12, 58.6), Vector3(25, -12, 61.4), "E_LIFT"],
	[Vector3(38.6, -12, 72), Vector3(41.4, -12, 72), "G_GENERATOR"],
	[Vector3(60, -12, 80.6), Vector3(60, -12, 83.4), "H_LAB"],
	[Vector3(20, -12, 88.6), Vector3(20, -12.7, 91.4), "I_CORE"],
	[Vector3(44.5, -12, 80.6), Vector3(44.5, -12.7, 84.2), "I_CORE"],
	[Vector3(74, -12, 96.6), Vector3(74, -12.7, 99.8), "I_CORE"],
]

## Windows: [id, zone, floor pos on the wall line, inward yaw].
const WINDOWS: Array = [
	["W_A_N1", "A_MINEHEAD", Vector3(8, 0, 0), 0.0], ["W_A_N2", "A_MINEHEAD", Vector3(32, 0, 0), 0.0],
	["W_A_W", "A_MINEHEAD", Vector3(0, 0, 4), 90.0], ["W_A_E", "A_MINEHEAD", Vector3(40, 0, 7), -90.0],
	["W_B_N1", "B_RAILYARD", Vector3(45, 0, 14), 0.0], ["W_B_N2", "B_RAILYARD", Vector3(55, 0, 14), 0.0],
	["W_B_S", "B_RAILYARD", Vector3(50, 0, 48), 180.0],
	["W_C_N", "C_ADMIN", Vector3(-8, 0, 8), 0.0], ["W_C_UN", "C_ADMIN", Vector3(-8, 3.8, 8), 0.0],
	["W_C_BAL", "C_ADMIN", Vector3(0, 3.8, 14), -90.0],
	["W_D_W", "D_BARRACKS", Vector3(-16, 0, 39), 90.0], ["W_D_S1", "D_BARRACKS", Vector3(-2, 0, 46), 180.0],
	["W_D_S2", "D_BARRACKS", Vector3(14, 0, 46), 180.0],
	["W_E", "E_LIFT", Vector3(30, 0, 51), -90.0],
	["W_F_W", "F_CHAPEL", Vector3(-16, DY, 72), 90.0], ["W_F_S1", "F_CHAPEL", Vector3(-6, DY, 90), 180.0],
	["W_F_S2", "F_CHAPEL", Vector3(32, DY, 90), 180.0], ["W_F_N", "F_CHAPEL", Vector3(8, DY, 60), 0.0],
	["W_G_N1", "G_GENERATOR", Vector3(52, DY, 60), 0.0], ["W_G_N2", "G_GENERATOR", Vector3(76, DY, 60), 0.0],
	["W_H_N", "H_LAB", Vector3(93, DY, 82), 0.0], ["W_H_E1", "H_LAB", Vector3(102, DY, 85), -90.0],
	["W_H_E2", "H_LAB", Vector3(102, DY, 95), -90.0], ["W_H_S", "H_LAB", Vector3(56, DY, 98), 180.0],
]
## Wall-buys: [weapon, pos (wall surface), yaw so local -Z faces the room]. Wall linings leave these bare.
const BUYS: Array = [
	["kar98k", Vector3(8, 1.5, 10.02), 180.0], ["m1_carbine", Vector3(33, 1.5, 10.02), 180.0],
	["gewehr43", Vector3(-12, 1.5, 8.17), 180.0],
	["mp40", Vector3(59.83, 1.5, 36), 90.0], ["frag", Vector3(59.83, 1.5, 42), 90.0],
	["trench_gun", Vector3(-4, 1.5, 32.17), 180.0],
	["bar", Vector3(-15.83, DY + 1.5, 78), -90.0],
	["stg44", Vector3(56, DY + 1.5, 81.83), 0.0], ["etool", Vector3(51, DY + 1.5, 81.83), 0.0],
]
## Perk machines: [perk, pos (floor), yaw so local -Z faces the room]. T-226: their footprints are baked into the navmesh
## (build_perk_blocks, as Map 0 has done since T-027), and Skyhook Sekt stands in the Core Vault: the installers set the
## ELEVATION cabinet (Consignment W.T., Werk Thalbach's) under the north wall between the two ramp doors, where the lab's
## cable run comes down, a few metres from the Crucible's apron.
const PERKS: Array = [
	["second_wind", Vector3(-15.2, 0, 14), -90.0], ["ironhide_stout", Vector3(24, 0, 32.8), 180.0],
	["marathon_malt", Vector3(2, DY, 60.8), 180.0], ["twin_barrel", Vector3(34, DY, 60.8), 180.0],
	["trigger_tonic", Vector3(68, DY, 81.2), 0.0],
	["hawkeye_brandy", Vector3(55, DY, 88.8), 180.0], ["packmule_porter", Vector3(96, DY, 88.8), 180.0],
	["blastproof_bock", Vector3(64, DY, 97.2), 0.0],
	# Overclock Cordial (T-034): in the Generator Hall, wired into the north-wall switchgear in the gap between
	# the first two panel sections (x 59.5-61), facing the turbines. The hall's own bus feeds the coil.
	["overclock_cordial", Vector3(60.25, DY, 60.45), 180.0],
	# Ledger Lager (T-141): the pay office's original cabinet, bolted beside Fenske's desk wall, 3 m north of
	# Second Wind and the Bergmannskasse's counter (the bank branch is at z 15.75..20.75)
	["ledger_lager", Vector3(-15.2, 0, 11.0), -90.0],
	["skyhook_sekt", Vector3(34.5, CY, 101.6), 180.0],   # T-226: the Core Vault's north wall, between the F and G ramp doors
]
## Same as PerkMachine._shape_footprint (that script needs the autoloads, which a --script run doesn't have). Keep in step.
const MACHINE_FOOTPRINTS: Dictionary = {
	"barrel": Vector3(1.2, 1.9, 1.2), "cabinet": Vector3(0.8, 2.3, 0.6), "crate": Vector3(1.0, 2.0, 0.65),
	"twin": Vector3(1.2, 2.1, 0.6), "teardrop": Vector3(1.0, 2.4, 0.9), "periscope": Vector3(0.9, 1.8, 0.65),
	"wagon": Vector3(1.7, 1.7, 0.85), "safe": Vector3(1.1, 1.9, 0.95), "coil": Vector3(0.8, 2.3, 0.6),
	"register": Vector3(1.0, 2.2, 0.75), "glider": Vector3(0.8, 2.4, 0.7), "bandit": Vector3(0.9, 2.3, 0.65),
}
## T-226: the Core Vault's solid dressing (hidden colliders drawn by _dress_core): the installers' bench and crates in the
## east wall's south corner, the cable drums by the G ramp door, oil drums in the north-east corner. [name, min, max].
const CORE_PROPS: Array = [
	["CorePropBench", Vector3(48.15, CY, 127.6), Vector3(48.85, CY + 0.95, 129.4)],
	["CorePropCrates", Vector3(47.8, CY, 129.6), Vector3(48.85, CY + 1.6, 130.7)],
	["CorePropDrums", Vector3(47.9, CY, 105.4), Vector3(48.85, CY + 0.95, 107.0)],
	["CorePropCableDrums", Vector3(40.0, CY, 101.3), Vector3(41.3, CY + 1.2, 102.6)],
]
## T-239 (the owner: "make sure the maps feel smooth and everything looks logically placed"): every floor prop that reads
## solid IS solid. Until now most of the dressing had no collider (the ore carts, the drums and braziers, the desks, the
## bunks' foot lockers, the mess benches, the hoist motor, the lab's gurneys and cabinets, the votive racks...): a player
## and every zombie walked straight through them (gravelight/tools_src/probe_snags lists them as GHOST). Each has a hidden
## collider here ([name, low corner, high corner], built before the bake so the navmesh goes round it) and stands where
## it does not catch a player moving backwards: against a wall with the collider carried to the wall face (no pocket
## behind it), in a corner, or as one flush block with its neighbour. Small things (a lantern, a bucket, a coal heap, a
## chair pushed under its desk) stay visual. docs/u15/t239_kaltenbrunn_pass.md has the list by zone.
const SOLID_PROPS: Array = [
	# A_MINEHEAD: the spur's carts on the north wall, the crates by the winding house door, the night shift's drums on the
	# east wall, the crate and the sandbags under the Administration's balcony
	["Prop_A_SpurCarts", Vector3(12.4, 0, 0.15), Vector3(16.3, 1.15, 1.65)],
	["Prop_A_SpurCart3", Vector3(26.55, 0, 0.15), Vector3(28.65, 1.15, 1.9)],
	["Prop_A_ShedCrates", Vector3(27.0, 0, 4.25), Vector3(28.0, 1.5, 5.25)],
	["Prop_A_EastDrums", Vector3(39.18, 0, 11.92), Vector3(39.85, 0.92, 13.88)],
	["Prop_A_WestCrate", Vector3(0.15, 0, 9.9), Vector3(1.08, 0.8, 10.8)],
	["Prop_A_WestSandbags", Vector3(0.15, 0, 10.8), Vector3(0.95, 0.48, 13.6)],
	# B_RAILYARD: the two ore carts on track 3, the coal in the north-east corner
	["Prop_B_OreCarts", Vector3(56.35, 0, 34.2), Vector3(57.65, 1.3, 38.1)],
	["Prop_B_CoalHeap", Vector3(57.55, 0, 14.15), Vector3(59.85, 0.75, 16.4)],
	["Prop_B_LocoBuffers", Vector3(50.6, 0, 25.3), Vector3(54.4, 1.4, 26.0)],   # the locomotive's buffer beam, 0.7 m ahead of its body's collider
	# C_ADMIN: the safe in the lobby's north-east corner, the clerks' desks against the walls; upstairs Reinholt's desk, the
	# cabinets, the plan table and the waiting bench, Fasbender's cot in the radio room
	["Prop_C_Safe", Vector3(-1.3, 0, 8.15), Vector3(-0.15, 1.1, 9.2)],
	["Prop_C_DeskN", Vector3(-4.8, 0, 8.15), Vector3(-3.2, 0.78, 9.4)],
	["Prop_C_DeskE1", Vector3(-1.4, 0, 11.8), Vector3(-0.15, 0.78, 13.4)],
	["Prop_C_DeskE2", Vector3(-1.4, 0, 17.2), Vector3(-0.15, 0.78, 18.8)],
	["Prop_C_OfficeDesk", Vector3(-7.05, 3.8, 25.55), Vector3(-4.95, 4.58, 26.78)],
	["Prop_C_UpperCabinets", Vector3(-9.5, 3.8, 31.25), Vector3(-6.5, 5.3, 31.85)],
	["Prop_C_PlanTable", Vector3(-1.55, 3.8, 21.6), Vector3(-0.15, 4.7, 24.4)],
	["Prop_C_UpperBench", Vector3(-7.5, 3.8, 16.15), Vector3(-3.5, 4.27, 16.6)],
	["Prop_C_Cot", Vector3(-6.1, 3.8, 8.15), Vector3(-4.0, 4.35, 9.15)],
	# D_BARRACKS: the lockers on the north wall, the quartermaster's shelf, the stove in its corner (the foot lockers and
	# the mess benches are built from their loops in build_solid_props)
	["Prop_D_Lockers", Vector3(0.6, 0, 32.15), Vector3(6.55, 1.9, 32.67)],
	["Prop_D_QmShelf", Vector3(-15.85, 0, 34.5), Vector3(-15.3, 2.2, 37.5)],
	["Prop_D_Stove", Vector3(-15.85, 0, 44.5), Vector3(-14.55, 1.0, 45.85)],
	# E_LIFT: the hoist motor in the lift house's corner
	["Prop_E_HoistMotor", Vector3(27.6, 0, 53.6), Vector3(29.85, 1.4, 55.85)],
	# F_CHAPEL: the altar's steps either side of the reliquary, the four votive racks
	["Prop_F_AltarStepsW", Vector3(6.4, DY, 81.0), Vector3(10.0, DY + 0.33, 82.0)],
	["Prop_F_AltarStepsW2", Vector3(6.4, DY, 81.5), Vector3(10.0, DY + 0.66, 82.0)],
	["Prop_F_AltarStepsE", Vector3(14.0, DY, 81.0), Vector3(17.6, DY + 0.33, 82.0)],
	["Prop_F_AltarStepsE2", Vector3(14.0, DY, 81.5), Vector3(17.6, DY + 0.66, 82.0)],
	["Prop_F_VotiveW1", Vector3(-15.85, DY, 68.1), Vector3(-15.08, DY + 0.85, 69.5)],
	["Prop_F_VotiveW2", Vector3(-15.85, DY, 79.1), Vector3(-15.08, DY + 0.85, 80.5)],
	["Prop_F_VotiveE1", Vector3(39.08, DY, 64.3), Vector3(39.85, DY + 0.85, 65.7)],
	["Prop_F_VotiveE2", Vector3(39.08, DY, 84.5), Vector3(39.85, DY + 0.85, 85.9)],
	# G_GENERATOR: the drums and the crate in the south-west corner (they stood in the vault ramp's blast door)
	["Prop_G_SwDrums", Vector3(40.15, DY, 79.55), Vector3(41.95, DY + 0.95, 81.85)],
	# H_LAB: cabinets, gurneys, trolleys, the hall's crate and benches, the operating table, the coils, the cold store
	["Prop_H_Cabinet1", Vector3(62.8, DY, 82.15), Vector3(65.2, DY + 2.1, 82.7)],
	["Prop_H_Gurney1", Vector3(62.25, DY, 87.05), Vector3(64.35, DY + 0.85, 87.85)],
	["Prop_H_Trolley1", Vector3(56.1, DY, 82.15), Vector3(56.9, DY + 0.85, 82.8)],
	["Prop_H_HallCrate", Vector3(52.15, DY, 90.95), Vector3(53.05, DY + 0.8, 91.85)],
	["Prop_H_HallBench1", Vector3(64.85, DY, 91.4), Vector3(67.15, DY + 0.47, 91.85)],
	["Prop_H_HallBench2", Vector3(85.35, DY, 91.4), Vector3(87.65, DY + 0.47, 91.85)],
	["Prop_H_Cabinet2", Vector3(83.15, DY, 83.8), Vector3(83.85, DY + 2.1, 86.2)],
	["Prop_H_OpTable", Vector3(78.1, DY, 84.9), Vector3(81.1, DY + 0.97, 86.1)],
	["Prop_H_CoilN", Vector3(52.15, DY, 93.1), Vector3(52.9, DY + 1.5, 93.9)],
	["Prop_H_CoilS", Vector3(52.15, DY, 95.6), Vector3(52.9, DY + 1.5, 96.4)],
	["Prop_H_IntakeBench", Vector3(68.15, DY, 94.05), Vector3(68.6, DY + 0.47, 96.95)],
	["Prop_H_Gurney2", Vector3(92.45, DY, 97.05), Vector3(94.55, DY + 0.85, 97.85)],
	["Prop_H_Gurney3", Vector3(97.85, DY, 97.05), Vector3(99.95, DY + 0.85, 97.85)],
	["Prop_H_Fridge", Vector3(100.9, DY, 92.15), Vector3(101.85, DY + 2.0, 93.6)],
	# I_CORE: the Ledger's lectern, stood in front of the drawers
	["Prop_I_Lectern", Vector3(33.6, CY, 136.75), Vector3(34.4, CY + 1.15, 137.5)],
	# the 0.7 m slot between the Crucible and the south-east pillar (a body fitted it exactly: 11 sweeps of probe_snags
	# wedged there) is closed by the installers' crates; the alcove behind is entered from the south, 2 m wide
	["Prop_I_CrucibleGap", Vector3(45.05, CY, 125.3), Vector3(45.95, CY + 1.3, 126.0)],
]
## T-239: the round ones ([name, centre on the floor, radius, height]): a capsule slides round a drum where a box's corner
## would stop it dead. The west brazier by the Administration door, the water crane's column, the three Resonance Pylons
## (a 2.6 m lattice mast on a concrete foot that the squad ran through during its own holdout).
const SOLID_ROUND: Array = [
	["Prop_A_WestBrazier", Vector3(0.62, 0, 20.4), 0.32, 0.92],
	["Prop_A_EastBrazier", Vector3(38.86, 0, 12.9), 0.32, 0.92],
	["Prop_B_WaterCrane", Vector3(47.2, 0, 47.3), 0.3, 3.4],
	["Prop_A_Pylon", Vector3(20, 0, 21.5), 0.45, 1.0],   # (the foot and the mast's lower bay; shots pass the lattice above)
	["Prop_F_Pylon", Vector3(-2, DY, 84), 0.45, 1.0],
	["Prop_H_Pylon", Vector3(60, DY, 95), 0.45, 1.0],
]
## T-239: the Hauptschalter's dais (SwitchDais, a 0.3 m step 1.85 m out of the north wall in the Generator Hall's north
## lane) is skirted by a ramp DAIS_SKIRT wide on its three open sides: a player backing along the wall walks up and over it
## instead of stopping dead on an ankle-high edge (the worst LOW finding of probe_snags: 199 sweeps).
const DAIS_SKIRT: float = 0.55

## Ammo boxes (Update 02 section 4, T-049): [name, floor pos, yaw so local -Z faces the room]. One per zone the brief
## names, each on a bare wall 4 m+ from any perk machine or the Crucible, clear of windows, doors and the ore-cart
## track and the dressing: the Rail Yard's west wall between its two doors; the bunk room's north wall by the
## trench-gun chalk (west of the lockers); the Chapel's east wall between a pilaster and the side-altar niche; the
## Lab's south-middle (intake) room, on its east wall.
const AMMO_BOXES: Array = [
	["Yard", Vector3(20.0, 0, 31.52), 0.0],   # T-123: the spawn yard's own, on its bare south wall
	["RailYard", Vector3(40.48, 0, 32.5), -90.0], ["Barracks", Vector3(-1.6, 0, 32.48), 180.0],
	["SaltChapel", Vector3(39.43, DY, 78.5), 90.0], ["LabWing", Vector3(83.5, DY, 95.0), 90.0],
]
## T-225 (the owner: "rework the starting area on map 2"): the squad starts inside the WASCHKAUE, the miners' changing
## house built against the yard's south wall (x KAUE_X0..KAUE_X1, z KAUE_Z0..the wall; brick, a flat roof at KAUE_H under
## the 4 m wall), open to the yard through two wide doorways in its north face either side of a pier. Inside: the benches
## along the west and east walls, the lockers and the stove on the south wall, the tag board and the lamp rack, and the
## clothes baskets on their chains under the roof (every miner's clothes went up on a chain while he was below; the ones
## still hanging are the men still down there). Lit before the power by the stove and the lanterns. The four spawns
## face north out of the doorways at the headframe. Zone A_MINEHEAD, no door of its own; the headframe loop's 6 m south
## lane (z 20..26) is untouched, the lane west of it (x 0..4) keeps the ground spawn at (3, 29) and the way to the
## Administration door.
const KAUE_X0: float = 4.0
const KAUE_X1: float = 16.0
const KAUE_Z0: float = 26.0
const KAUE_H: float = 3.4
const KAUE_DOORS: Array = [[4.6, 9.0], [11.0, 15.4]]   # the two doorways' x spans in the north face (the pier x 9..11)
const KAUE_BACK: float = 4.0   # the lean-to roof meets the yard wall at its top; its eaves are the front wall's top (KAUE_H)
const KAUE_ZW: float = 31.85   # the yard wall's inner face

## T-123: the spawn yard's solid props (drawn by _dress_yard_south): [collider name, low corner, high corner].
## Built before the bake (build_yard_prop_blocks) so the navmesh goes round them. T-225: the Kaue's furniture is here
## too (benches, lockers, the stove, the lamp rack), and the brazier moved out to the lane by the Administration door.
const YARD_PROPS: Array = [
	["YardPropLockers", Vector3(4.7, 0, 31.35), Vector3(9.1, 1.9, 31.85)],
	["YardPropStove", Vector3(9.75, 0, 30.3), Vector3(10.55, 1.25, 31.85)],   # (T-239: to the wall; the pocket behind it held a player)
	["YardPropRack", Vector3(13.6, 0, 31.45), Vector3(15.3, 1.9, 31.85)],
	["YardPropSled", Vector3(16.25, 0, 29.9), Vector3(17.05, 0.55, 31.3)],   # (T-239: in the corner against the Kaue's wall; it stood 0.85 m off it)
	["YardPropTimber", Vector3(22.4, 0, 30.6), Vector3(26.6, 0.95, 31.85)],
	["YardPropSet", Vector3(27.4, 0, 31.35), Vector3(29.6, 2.6, 31.85)],
	["YardPropBench", Vector3(30.45, 0, 31.0), Vector3(32.55, 0.95, 31.85)],
	["YardPropCart", Vector3(34.0, 0, 30.2), Vector3(36.0, 1.1, 31.6)],
	["YardPropCrates", Vector3(36.6, 0, 30.9), Vector3(38.45, 0.9, 31.85)],   # (T-239: the stack's own footprint; the top crate is YardPropCratesTop)
	["YardPropCratesTop", Vector3(37.05, 0.9, 31.1), Vector3(37.75, 1.55, 31.85)],
]

## T-225: the Kaue's own benches (hidden colliders drawn by _dress_kaue), inside it along its west and east walls; the
## test's rules for them are the Kaue's (inside its walls, clear of its doorways and spawns), not T-123's wall rules.
const KAUE_PROPS: Array = [
	# (T-239: both run to the back wall. They stopped 0.95 m short of it, leaving a 0.55 m pocket in each back corner between
	# the bench's end, the wall and the lockers / the lamp rack: PAUL, 1.3 x a man, came to rest on the west bench's end
	# there in smoke_paul, off the floor at y 0.25, and could not walk out)
	["KauePropBenchW", Vector3(KAUE_X0 + 0.15, 0, 27.2), Vector3(KAUE_X0 + 0.6, 0.45, KAUE_ZW)],
	["KauePropBenchE", Vector3(KAUE_X1 - 0.6, 0, 27.2), Vector3(KAUE_X1 - 0.15, 0.45, KAUE_ZW)],
]

## The Armorer's Bench (UPDATE_04 section 6, T-068): [floor position against the wall, yaw so local -Z faces the yard].
## At the gatehouse, against its east face north of the Kar98k corner, clear of the shelf by its door.
const ARMORERS_BENCH: Array = [Vector3(12.01, 0, 8.8), -90.0]

## Greybox colour keys -> material library keys (world/materials.gd).
const MAT_MAP: Dictionary = {
	"wall": "stucco", "brick": "brick", "concrete": "concrete", "salt": "halite", "rock": "rock_dark", "snow": "snow",
	"floor_wood": "floorboards", "floor_stone": "rock_floor", "metal": "iron", "roof": "roof", "furniture": "furniture",
	"stairs": "concrete", "rail": "steel", "wreck": "rust", "lab": "paint_cream", "nachtglas": "nachtglas", "pew": "furniture",
	"turbine": "machine_green",
}
## Per-node material overrides (String.match patterns, first match wins).
const MAT_RULES: Array = [
	["ChapelRoof", "halite"], ["ChapelFloor", "halite_floor"], ["ChapelN*", "concrete"], ["ChapelE*", "concrete"],
	["SaltColumn", "halite_carved"],
	["GenRoof", "concrete"], ["GenFloor", "concrete_floor"], ["SwitchDais", "steel_grate"],
	["LabRoof", "paint_cream"], ["LabFloor", "tile_floor"], ["MorgueDrawers", "steel"],
	["CoreRoof", "rock_dark"], ["CoreFloor", "rock_floor"], ["PitRim", "machine_grey"],
	["LedgerRoof", "concrete"], ["LedgerFloor", "concrete_floor"], ["LedgerCabinets", "machine_grey"],
	["LiftBayRoof", "concrete"], ["LiftBayFloor", "concrete_floor"], ["LiftFloor*", "concrete_floor"], ["LiftHouseRoof", "concrete"],
	["CorrHFloor", "rock_floor"], ["CorrHRoof", "rock_dark"], ["Ramp?Roof", "rock_dark"], ["Ramp?", "rock_floor"],
	["StairPit", "concrete_floor"], ["StairRoof", "concrete"],
	["AdminURoof", "plaster"], ["AdminPart*", "plaster_upper"], ["AdminRail", "iron"],
	["AdminNLedge", "roof"], ["BalconyLedge", "planks"],
	["BarrRoof", "planks"], ["Barr*", "planks"], ["BunkMess*", "planks"],
	["TowerBase", "concrete"], ["Closet*", "halite"],
	["KaueRoof", "concrete"], ["Kaue*", "brick"],
]
## Greybox visuals replaced by dressing (colliders stay). Also the faces of walls that coincide with a
## neighbour's wall (the neighbour's visual is kept, and the hidden side gets a lining instead).
const HIDE: Array = [
	"YardProp*",   # T-123: the yard's props are drawn by _dress_yard_south; these are their colliders
	"YardS_*", "YardW_1*", "YardW_end", "AdminGS_*", "BarrE_*", "LiftHouseN_*", "LedgerN_*",
	"Rail", "TowerLeg", "TowerHead", "SnowMound?", "Drift", "Boxcar", "Locomotive", "LocoCab", "BufferStop", "SignalBox",
	"Gate", "FilingA", "Bunk", "MessTable", "ServingLine", "Pews", "Altar", "AltarTop", "Bell", "Font", "ChandelierVis",
	"Confessional", "Turbine", "Catwalk", "Tank", "NurseryBed", "AdminStairs", "FlightA", "FlightB", "FlightC",
	"NavBlock_Ammo*", "NavBlock_ArmorersBench", "NavBlock_Perk*", "CoreProp*", "KaueProp*", "KaueRoof", "NavBlock_Kaue*",
	"Prop_*", "AdminStairString*", "DaisSkirt",   # T-239: the solid dressing's colliders; the stair strings are drawn as panelled walls
]
const SODIUM: Color = Color(1.0, 0.66, 0.36)
const INCAND: Color = Color(1.0, 0.78, 0.55)
const FLOOD: Color = Color(1.0, 0.84, 0.64)    # incandescent floods: warm pools on the moon-blue snow (T-062)
const CHAPEL_LAMP: Color = Color(1.0, 0.75, 0.5)   # the salt chandeliers: warm white, so the salt reads pale
const LAB_LAMP: Color = Color(1.0, 0.84, 0.66)   # the lab's enamel pendants: a whiter, clinical incandescent
const AMBER: Color = Color(1.0, 0.52, 0.16)    # the glowing cracks in the Nachtglas (GDD 17: violet with amber cracks)
const RED: Color = Color(1.0, 0.22, 0.14)
const VIOLET: Color = Color(0.62, 0.28, 1.0)
const POWER_GAIN: float = 2.2      # power-light energy scale (the specs below are relative)
const LAMP_GAIN: float = 1.7       # always-on lamp energy scale

var map_root: Node3D
var geo: Node3D
var dress: Node3D
var gameplay: Node3D
var _count: int = 0
var _frames: int = 0
var _closets: Array = []
var _stairs: Array = []           # [x0, x1, z_low, z_high, y_low, y_high, tread key, riser key]
var _glow: Dictionary = {}        # zone -> Node3D holder of glowing (powered) parts
var _power: Array = []            # power light specs (Dictionary)
var _static_lights: Array = []    # always-on light specs (Dictionary)
var _decal_tex: Dictionary = {}
var _decals: Node3D


func _initialize() -> void:
	map_root = Node3D.new()
	map_root.name = "Map01Kaltenbrunn"
	get_root().add_child(map_root)
	geo = Node3D.new()
	geo.name = "Geometry"
	map_root.add_child(geo)
	dress = Node3D.new()   # a sibling of Geometry: the bake parses Geometry only
	dress.name = "Dressing"
	map_root.add_child(dress)
	build_surface()
	build_stairs_and_lift()
	build_chapel()
	build_generator()
	build_lab()
	build_core()
	build_closets()
	build_ammo_blocks()
	build_yard_prop_blocks()
	build_perk_blocks()
	build_core_prop_blocks()
	build_solid_props()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	bake_regions()
	get_root().remove_child(map_root)
	build_dressing()
	_dress_buy_lamps()
	if _audit_wall_buys() > 0:   # T-227: never save a scene with a chalk hidden behind the dressing
		push_error("gen_map01: a wall-buy is blocked; the scene was NOT saved")
		map_root.free()
		return true
	var merged: int = merge_static_meshes()
	print("merged %d static meshes into batches" % merged)
	build_lights()
	build_landscape()
	build_gameplay()
	_prune(dress)
	_prune(geo)
	_own(map_root)
	var named: int = _name_noise_textures(map_root)
	print("named %d noise textures" % named)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(map_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://gravelight/maps/map01_kaltenbrunn"))
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
## The visual uses the shared unit box + a library material; HIDE'd names get no visual (dressing redraws them).
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
## lines: lining panels (dressing) [[side +1/-1 (face toward +Z/-Z), key, height (0 = full), thickness], ...].
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
## Panels skip the strip around a wall-buy on that face, so chalk outlines stay visible.
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


## Rectangular room shell (4 walls), openings per side: {"n": [...], "s": [...], "w": [...], "e": [...]}.
## lin / lout: linings on the inner / outer faces, [[key, height (0 = full), thickness], ...].
func room(n: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, op: Dictionary, mk: String, roof: bool,
		floor_mk: String = "", lin: Array = [], lout: Array = []) -> void:
	wall_x(n + "N", z0, x0 - T * 0.5, x1 + T * 0.5, y0, y1, op.get("n", []), mk, _sides(lin, lout, 1))
	wall_x(n + "S", z1, x0 - T * 0.5, x1 + T * 0.5, y0, y1, op.get("s", []), mk, _sides(lin, lout, -1))
	wall_z(n + "W", x0, z0, z1, y0, y1, op.get("w", []), mk, _sides(lin, lout, 1))
	wall_z(n + "E", x1, z0, z1, y0, y1, op.get("e", []), mk, _sides(lin, lout, -1))
	if roof:
		box(geo, n + "Roof", Vector3(x0 - T * 0.5, y1, z0 - T * 0.5), Vector3(x1 + T * 0.5, y1 + 0.3, z1 + T * 0.5), "roof")
	if floor_mk != "":
		box(geo, n + "Floor", Vector3(x0, y0 - 0.5, z0), Vector3(x1, y0, z1), floor_mk)


func _sides(lin: Array, lout: Array, inner: int) -> Array:
	var out: Array = []
	for l: Array in lin:
		out.append([inner, l[0], l[1], l[2]])
	for l2: Array in lout:
		out.append([-inner, l2[0], l2[1], l2[2]])
	return out


## Window opening helper: [a, b, sill_y, top_y] around center c on a floor at y.
func win(c: float, y: float) -> Array:
	return [c - 0.8, c + 0.8, y + SILL, y + WTOP]


func door(c: float, y: float, w: float = 2.6) -> Array:
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
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.collision_layer = 1
	body.transform = Transform3D(basis, mid - (basis * Vector3.UP) * 0.1)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(absf(x1 - x0), 0.2, length)
	cs.shape = shape
	body.add_child(cs)
	if not _hidden(n):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = shape.size
		mi.material_override = Mats.get_mat(_mk(n, "stairs"))
		body.add_child(mi)
	geo.add_child(body)
	_count += 1
	if treads != "":
		_stairs.append([x0, x1, z_low, z_high, y_low, y_high, treads, risers])


## A closet behind a depths/upper window so window zombies have floor to stand on.
func closet(window_pos: Vector3, yaw_deg: float) -> void:
	_closets.append([window_pos, yaw_deg])


## T-239: every code-built NoiseTexture2D a material in the scene uses gets a scene id made from what it is (its noise and
## its colour ramp), so the id is the same after every regeneration. The look pass keys its per-texture fixes
## (data/look/_materials.json tex_fix, written by tools/look/material_audit) by "<scene>::<id>": with the ids the saver
## hands out those keys went stale at each regeneration, and where an old id came back on another texture that texture
## took the other's fix (the pit-prop timber, "pine", took a red paint's 0.07 saturation: grey bunks, mess benches and
## pit props on the owner's renderer, bright green ones in the WSL captures). Returns how many it named.
func _name_noise_textures(root: Node) -> int:
	var seen: Dictionary = {}
	var used: Dictionary = {}
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var mats: Array = []
		var gi: GeometryInstance3D = n as GeometryInstance3D
		if gi.material_override != null:
			mats.append(gi.material_override)
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mesh: Mesh = (gi as MeshInstance3D).mesh
			for s: int in mesh.get_surface_count():
				mats.append((gi as MeshInstance3D).get_surface_override_material(s))
				mats.append(mesh.surface_get_material(s))
		for m: Variant in mats:
			if not (m is BaseMaterial3D):
				continue
			for prop: String in ["albedo_texture", "normal_texture", "roughness_texture", "detail_albedo", "emission_texture"]:
				var t: Variant = (m as BaseMaterial3D).get(prop)
				if not (t is NoiseTexture2D) or seen.has(t):
					continue
				seen[t] = true
				var nt: NoiseTexture2D = t
				var sig: String = "%d|%d|%s|%s" % [nt.width, nt.height, str(nt.as_normal_map), str(nt.bump_strength)]
				if nt.noise is FastNoiseLite:
					var fn: FastNoiseLite = nt.noise
					sig += "|%d|%d|%s|%d|%d|%s|%d" % [fn.seed, fn.noise_type, str(fn.frequency), fn.fractal_octaves, fn.cellular_return_type,
						str(fn.cellular_jitter), fn.cellular_distance_function]
				if nt.color_ramp != null:
					sig += "|" + str(nt.color_ramp.offsets) + str(nt.color_ramp.colors)
				var id: String = "NoiseTexture2D_m1%s" % sig.md5_text().substr(0, 8)
				while used.has(id):
					id += "x"
				used[id] = true
				nt.resource_scene_unique_id = id
	return used.size()


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


# ================================================================== surface (y = 0)

func build_surface() -> void:
	# Ground: the surface play area, with no slab over the lift shaft / stair house.
	box(geo, "Ground", Vector3(-40, -0.5, -25), Vector3(100, 0, 46), "snow")
	box(geo, "GroundS1", Vector3(-4, -0.5, 46), Vector3(20, 0, 52), "snow")
	box(geo, "GroundS2", Vector3(30, -0.5, 46), Vector3(46, 0, 58), "snow")
	box(geo, "GroundS3", Vector3(46, -0.5, 46), Vector3(62, 0, 52), "snow")
	# A_MINEHEAD yard walls (4 m brick, open sky)
	room("Yard", 0, 40, 0, 32, 0, 4.0, {
		"n": [win(8, 0), win(32, 0)],
		"w": [win(4, 0), door(25, 0)],
		"e": [win(7, 0), door(25, 0)],
	}, "brick", false)
	box(geo, "Gate", Vector3(18, 0, -0.6), Vector3(22, 4.5, -0.3), "metal")
	box(geo, "Gatehouse", Vector3(4, 0, 4), Vector3(12, 3.5, 10), "brick")
	box(geo, "CoalShed", Vector3(28, 0, 4), Vector3(38, 3.0, 10), "brick")
	box(geo, "TowerBase", Vector3(15, 0, 10), Vector3(25, 6, 20), "concrete")
	for corner: Vector2 in [Vector2(15.5, 10.5), Vector2(24.5, 10.5), Vector2(15.5, 19.5), Vector2(24.5, 19.5)]:
		box(geo, "TowerLeg", Vector3(corner.x - 0.4, 6, corner.y - 0.4), Vector3(corner.x + 0.4, 28, corner.y + 0.4), "metal", false)
	box(geo, "TowerHead", Vector3(15, 26, 10), Vector3(25, 29, 20), "metal", false)
	box(geo, "SnowMound1", Vector3(35, 0, 1), Vector3(39, 0.4, 5), "snow", false)
	box(geo, "SnowMound2", Vector3(1, 0, 27), Vector3(3.7, 0.4, 31), "snow", false)   # (short of the Kaue's west wall, T-225)
	build_kaue()
	# C_ADMIN (x -16..0, z 8..32): ground floor 0..3.5, upper 3.8..7. Plaster + wainscot inside, a plinth outside.
	room("AdminG", -16, 0, 8, 32, 0, 3.5, {
		"n": [win(-8, 0)],
		"e": [door(25, 0)],
		"s": [door(-8, 0)],
	}, "wall", false, "", [["plaster", 0.0, 0.012], ["wainscot", 1.1, 0.025]], [["concrete", 0.6, 0.05]])
	room("AdminU", -16, 0, 8, 32, 3.8, 7.0, {
		"n": [win(-8, 3.8)],
		"e": [win(14, 3.8)],
	}, "wall", true, "", [["plaster_upper", 0.0, 0.012], ["wainscot", 1.0, 0.025]])
	# upper floor slab with a stairwell hole (x -15..-12, z 21..28)
	box(geo, "AdminSlab1", Vector3(-16, 3.5, 8), Vector3(0, 3.8, 21), "floor_wood")
	box(geo, "AdminSlab2", Vector3(-12, 3.5, 21), Vector3(0, 3.8, 28), "floor_wood")
	box(geo, "AdminSlab3", Vector3(-16, 3.5, 28), Vector3(0, 3.8, 32), "floor_wood")
	ramp_z("AdminStairs", -15.2, -12.2, 28.0, 21.0, 0.0, 3.8, "furniture", "beam")
	box(geo, "AdminRail", Vector3(-12.2, 3.8, 21), Vector3(-12.0, 4.8, 27.5), "metal")
	# UPDATE 07 QA (T-107): closed stair strings on both sides of the Admin stairs. The bake used to run the navmesh
	# over the ramp's low east edge (0.27 m at z 27.5, under max_climb), so paths entered the stairs from the side
	# and a bot stood against the ramp's face for minutes ("lost 956 s" at (-11.8, 0, 27.4)); with the strings the
	# navmesh enters the stairs only at their foot and head.
	box(geo, "AdminStairStringE", Vector3(-12.25, 0, 21.0), Vector3(-12.05, 3.5, 28.3), "furniture")
	box(geo, "AdminStairStringW", Vector3(-15.35, 0, 21.0), Vector3(-15.15, 3.5, 28.3), "furniture")
	box(geo, "Switchboard", Vector3(-6, 0, 29.5), Vector3(-1, 2.2, 31.6), "furniture")
	box(geo, "FilingA", Vector3(-15.6, 0, 9), Vector3(-14.3, 1.6, 10.45), "furniture")   # (T-226: one cabinet; Ledger Lager stood inside the second since T-141)
	wall_x("AdminPart", 16.0, -16, -2.5, 3.8, 7.0, [door(-9, 3.8, 1.6)], "wall", [[1, "wainscot", 1.0, 0.025], [-1, "wainscot", 1.0, 0.025]])
	box(geo, "RadioDesk", Vector3(-15.5, 3.8, 9), Vector3(-13, 4.6, 12), "furniture")
	# balcony ledge in the yard (zombies climb onto it to reach the upper east window)
	box(geo, "BalconyLedge", Vector3(0.15, 3.5, 12), Vector3(2.6, 3.8, 16), "roof")
	box(geo, "AdminNLedge", Vector3(-10, 3.5, 5.5), Vector3(-6, 3.8, 7.85), "roof")
	# B_RAILYARD (x 40..60, z 14..48), open sky
	room("Rail", 40, 60, 14, 48, 0, 4.0, {
		"n": [win(45, 0), win(55, 0)],
		"s": [win(50, 0)],
		"w": [door(25, 0), door(40, 0)],
	}, "brick", false)
	for x: float in [43.3, 44.7, 51.3, 52.7]:
		box(geo, "Rail", Vector3(x - 0.06, 0, 14.2), Vector3(x + 0.06, 0.12, 47.8), "rail", false)
	box(geo, "Boxcar", Vector3(55.5, 0, 18), Vector3(58.5, 3.4, 30), "wreck")
	box(geo, "Locomotive", Vector3(50.5, 0, 26), Vector3(54.5, 3.8, 40), "metal")
	box(geo, "LocoCab", Vector3(50.5, 3.8, 36), Vector3(54.5, 4.8, 40), "metal", false)
	box(geo, "BufferStop", Vector3(42.5, 0, 47), Vector3(45.5, 1.0, 47.8), "metal")
	box(geo, "SignalBox", Vector3(57.5, 0, 44.5), Vector3(59.8, 1.0, 47.8), "wall")
	# (T-239: drawn only, and 0.3 m deep. As a collider it was a 10 cm board at hip height standing 0.5 m into the 3 m lane
	# between the gatehouse and the headframe, beside the Armorer's Bench: 39 sweeps of probe_snags stopped on it)
	box(geo, "GatehouseShelf", Vector3(12.0, 0.9, 6.4), Vector3(12.3, 1.0, 7.6), "furniture", false)
	# D_BARRACKS & MESS (x -16..40, z 32..46): timber hut, plank-lined inside
	room("Barr", -16, 40, 32, 46, 0, 4.0, {
		"n": [door(-8, 0)],
		"w": [win(39, 0)],
		"s": [win(-2, 0), win(14, 0), door(-10, 0), door(25, 0)],
		"e": [door(40, 0)],
	}, "wall", true, "", [["planks", 0.0, 0.012]])
	# the Yard's south wall coincides with the Barracks' north wall from x 0..40 (its visual is hidden).
	wall_z("BunkMess", 8.0, 32, 46, 0, 4.0, [[38.0, 41.0, 0.0, 2.6]], "wall")
	for bx: float in [-11.5, -6.0, -0.5, 4.0]:
		box(geo, "Bunk", Vector3(bx, 0, 40), Vector3(bx + 2.0, 1.8, 44), "furniture")
	for i: int in 3:
		box(geo, "MessTable", Vector3(12 + i * 8, 0, 37), Vector3(17 + i * 8, 0.8, 38.5), "furniture")
	box(geo, "ServingLine", Vector3(30, 0, 44.6), Vector3(38, 1.0, 45.6), "furniture")
	# E_LIFT house (x 20..30, z 46..56), floor with the shaft hole (x 23..27, z 49..53)
	room("LiftHouse", 20, 30, 46, 56, 0, 6.0, {"n": [door(25, 0)], "e": [win(51, 0)]}, "brick", true, "", [["brick", 0.0, 0.012]])
	box(geo, "LiftFloorN", Vector3(20, -0.5, 46), Vector3(30, 0, 49), "concrete")
	box(geo, "LiftFloorS", Vector3(20, -0.5, 53), Vector3(30, 0, 56), "concrete")
	box(geo, "LiftFloorW", Vector3(20, -0.5, 49), Vector3(23, 0, 53), "concrete")
	box(geo, "LiftFloorE", Vector3(27, -0.5, 49), Vector3(30, 0, 53), "concrete")
	# drifts outside the yard for silhouette
	box(geo, "Drift", Vector3(-30, 0, -10), Vector3(-20, 1.2, 0), "snow", false)


# ================================================================== maintenance stairs + lift shaft

func build_stairs_and_lift() -> void:
	# Stair house x -16..-4, z 46..60, from y 0 down to -12 in three switchback flights.
	wall_z("StairW", -16.0, 46, 60, DY, 4.0, [], "concrete", [[1, "paint_green", 1.4, 0.015]])
	wall_z("StairE", -4.0, 46, 60, DY, 4.0, [], "concrete", [[-1, "paint_green", 1.4, 0.015]])
	wall_x("StairS", 60.0, -16, -4, DY, 4.0, [door(-12, DY, 3.0)], "concrete", [[-1, "paint_green", 1.4, 0.015]])
	box(geo, "StairRoof", Vector3(-16.2, 4.0, 46), Vector3(-3.8, 4.3, 60.2), "roof")
	wall_x("StairN", 46.0, -16, -4, DY, -0.5, [], "concrete", [[1, "paint_green", 1.4, 0.015]])
	box(geo, "StairPit", Vector3(-12.1, DY - 0.5, 48), Vector3(-4, DY, 54), "concrete")
	box(geo, "StairTop", Vector3(-16, -0.5, 46), Vector3(-4, 0, 48), "concrete")
	ramp_z("FlightA", -15.7, -12.3, 54.0, 48.0, -4.0, 0.0, "concrete", "concrete")
	box(geo, "Landing1", Vector3(-16, -4.5, 54), Vector3(-4, -4.0, 57), "concrete")
	ramp_z("FlightB", -9.0, -5.0, 48.0, 54.0, -8.0, -4.0, "concrete", "concrete")
	box(geo, "Landing2", Vector3(-16, -8.5, 46), Vector3(-4, -8.0, 48), "concrete")
	ramp_z("FlightC", -15.7, -12.3, 54.0, 48.0, DY, -8.0, "concrete", "concrete")
	box(geo, "Landing3", Vector3(-16, DY - 0.5, 54), Vector3(-4, DY, 60), "concrete")
	# Rails keep players from dropping off the landings into the stairwell void.
	box(geo, "Wall_A_C", Vector3(-12.3, DY, 48), Vector3(-12.1, -4.5, 54), "concrete")
	# Lift shaft (x 22.8..27.2, z 48.8..53.2) from -12 to 0, and the arrival bay south into the Chapel.
	wall_z("ShaftW", 22.7, 48.8, 53.2, DY, -0.5, [], "concrete")
	wall_z("ShaftE", 27.3, 48.8, 53.2, DY, -0.5, [], "concrete")
	wall_x("ShaftN", 48.7, 22.7, 27.3, DY, -0.5, [], "concrete")
	room("LiftBay", 21, 29, 53.2, 60, DY, DY + 3.5, {"n": [[23.0, 27.0, DY, DY + 3.5]], "s": [door(25, DY, 4.0)]}, "concrete", true, "concrete",
		[["paint_green", 1.4, 0.015]])
	wall_x("ShaftS", 53.2, 22.7, 27.3, DY + 3.5, -0.5, [], "concrete")
	box(geo, "ShaftPit", Vector3(21, DY - 1.5, 48.8), Vector3(29, DY - 1.0, 53.2), "concrete")


# ================================================================== F_CHAPEL (y -12)

func build_chapel() -> void:
	var y: float = DY
	# The N and E walls coincide with the stair house / lift bay / Generator walls (concrete); every inner
	# face is lined with dressed salt.
	room("Chapel", -16, 40, 60, 90, y, y + 14.0, {
		"n": [door(-12, y, 3.0), door(25, y, 4.0), win(8, y)],
		"w": [win(72, y)],
		"s": [win(-6, y), win(32, y), door(20, y, 4.0)],
		"e": [door(72, y)],
	}, "salt", true, "salt", [["halite", 0.0, 0.03]])
	for bx: float in [-10.0, 2.0, 14.0, 26.0]:
		box(geo, "Pews", Vector3(bx, y, 64), Vector3(bx + 8, y + 0.9, 78), "pew")
	box(geo, "Altar", Vector3(6, y, 82), Vector3(18, y + 1.0, 88), "salt")
	box(geo, "AltarTop", Vector3(10, y + 1.0, 84), Vector3(14, y + 1.6, 86), "salt", false)
	box(geo, "Bell", Vector3(11, y + 9.5, 84), Vector3(13, y + 12, 86), "metal", false)
	box(geo, "Font", Vector3(11.4, y, 61.2), Vector3(12.6, y + 1.0, 62.4), "salt")
	for x: float in [-4.0, 10.0, 24.0, 34.0]:
		box(geo, "SaltColumn", Vector3(x - 0.7, y, 79.5), Vector3(x + 0.7, y + 14.0, 80.9), "salt")
	for cz: float in [66.0, 71.0, 76.0]:
		box(geo, "ChandelierVis", Vector3(11.0, y + 8.5, cz - 1.0), Vector3(13.0, y + 10.0, cz + 1.0), "salt", false)
	box(geo, "Confessional", Vector3(-16, y, 81), Vector3(-14.6, y + 2.5, 84.4), "pew")
	closet(Vector3(-16, y, 72), 90.0)
	closet(Vector3(-6, y, 90), 180.0)
	closet(Vector3(32, y, 90), 180.0)
	closet(Vector3(8, y, 60), 0.0)


# ================================================================== G_GENERATOR (y -12)

func build_generator() -> void:
	var y: float = DY
	room("Gen", 40, 84, 60, 82, y, y + 10.0, {
		"n": [win(52, y), win(76, y)],
		"s": [door(44.5, y, 5.0), door(60, y)],
		"w": [door(72, y)],
	}, "concrete", true, "concrete", [["black_paint", 1.56, 0.01], ["paint_green", 1.5, 0.02]])
	for tx: float in [45.0, 58.0, 71.0]:
		box(geo, "Turbine", Vector3(tx, y, 67), Vector3(tx + 9, y + 5.0, 73), "turbine")
	box(geo, "Catwalk", Vector3(44, y + 5.5, 74), Vector3(81, y + 5.7, 75.5), "metal", false)
	box(geo, "SwitchDais", Vector3(44.5, y, 60.15), Vector3(48.5, y + 0.3, 62.0), "metal")
	box(geo, "Workbench", Vector3(40.3, y, 60.3), Vector3(43.0, y + 1.0, 62.0), "furniture")
	box(geo, "ForemanDesk", Vector3(80.5, y, 60.4), Vector3(83.6, y + 0.9, 62.0), "furniture")
	closet(Vector3(52, y, 60), 0.0)
	closet(Vector3(76, y, 60), 0.0)


# ================================================================== H_LAB (y -12)

func build_lab() -> void:
	var y: float = DY
	var h: float = y + 3.5
	var tiles_in: Array = [["tile_wall", 1.6, 0.015]]
	# Outer shell x 52..102, z 82..98. The north wall is shared with the Generator for x 52..84.
	wall_x("LabN", 82.0, 84, 102 + T * 0.5, y, h, [win(93, y)], "lab", [[1, tiles_in[0][0], 1.6, 0.015]])
	wall_x("LabS", 98.0, 52 - T * 0.5, 102 + T * 0.5, y, h, [win(56, y), door(74, y, 4.0)], "lab", [[-1, "tile_wall", 1.6, 0.015]])
	wall_z("LabW", 52.0, 82, 98, y, h, [], "lab", [[1, "tile_wall", 1.6, 0.015]])
	wall_z("LabE", 102.0, 82, 98, y, h, [win(85, y), win(95, y)], "lab", [[-1, "tile_wall", 1.6, 0.015]])
	box(geo, "LabRoof", Vector3(52, h, 82), Vector3(102, h + 0.3, 98), "roof")
	box(geo, "LabFloor", Vector3(52, y - 0.5, 82), Vector3(102, y, 98), "lab")
	# Rooms: north row z 82..88, hall z 88..92, south row z 92..98
	var both: Array = [[1, "tile_wall", 1.6, 0.015], [-1, "tile_wall", 1.6, 0.015]]
	wall_x("LabHallN", 88.0, 52, 102, y, h, [door(60, y), door(76, y), door(93, y)], "lab", both.duplicate(true))
	wall_x("LabHallS", 92.0, 52, 102, y, h, [door(60, y), door(76, y), door(93, y)], "lab", both.duplicate(true))
	for x: float in [68.0, 84.0]:
		wall_z("LabRoomN", x, 82, 88, y, h, [], "lab", both.duplicate(true))
		wall_z("LabRoomS", x, 92, 98, y, h, [], "lab", both.duplicate(true))
	for tz: Array in [[52.5, 83.0], [52.5, 85.5], [65.5, 83.0]]:
		box(geo, "Tank", Vector3(float(tz[0]), y, float(tz[1])), Vector3(float(tz[0]) + 2.0, y + 2.6, float(tz[1]) + 2.0), "nachtglas", true)
	box(geo, "FasbenderBench", Vector3(70, y, 82.4), Vector3(74, y + 1.0, 83.6), "furniture")
	# (T-239: a child's cot, 2.0 x 1.1 m with its rail at 1.0 m; the greybox was a 4 x 2.5 m slab and the bars a cage round it)
	box(geo, "NurseryBed", Vector3(87.0, y, 82.3), Vector3(89.0, y + 1.0, 83.4), "furniture")
	box(geo, "IntakeBoard", Vector3(77.5, y + 1.0, 97.6), Vector3(83.5, y + 2.8, 97.8), "furniture", false)
	box(geo, "MorgueDrawers", Vector3(85, y, 93), Vector3(88.5, y + 2.5, 97.6), "metal")
	box(geo, "NurseryDresser", Vector3(99, y, 86), Vector3(101.5, y + 1.0, 87.6), "furniture")
	box(geo, "IntakeTable", Vector3(70, y, 93), Vector3(72.5, y + 0.9, 94.5), "furniture")
	closet(Vector3(93, y, 82), 0.0)
	closet(Vector3(102, y, 85), -90.0)
	closet(Vector3(102, y, 95), -90.0)
	closet(Vector3(56, y, 98), 180.0)


# ================================================================== I_CORE (y -18) and its three ramps

func build_core() -> void:
	var y: float = CY
	room("Core", 19, 49, 101, 131, y, y + 12.0, {
		"n": [door(20, y, 4.0), door(44.5, y, 5.0)],
		"e": [door(115, y, 4.0)],
		"s": [door(34, y, 4.0)],
	}, "rock", true, "floor_stone")
	# pit with a railing wall and the Nachtglas heart above it. "Geometry/Heart" is a plain Node3D (the
	# Requiem ending scales it away); the dressing pass hangs the crystal heart under it.
	box(geo, "PitRim", Vector3(29, y, 111), Vector3(39, y + 1.1, 121), "metal")
	var heart: Node3D = Node3D.new()
	heart.name = "Heart"
	heart.position = Vector3(34, y + 7, 116)
	heart.set_meta("keep", true)
	geo.add_child(heart)
	_count += 1
	for c: Vector2 in [Vector2(23, 105), Vector2(45, 105), Vector2(23, 127), Vector2(45, 127)]:
		box(geo, "Pillar", Vector3(c.x - 1, y, c.y - 1), Vector3(c.x + 1, y + 12, c.y + 1), "rock")
	room("Ledger", 28, 40, 131, 139, y, y + 5.0, {"n": [door(34, y, 4.0)]}, "concrete", true, "concrete", [["concrete", 0.0, 0.012]])
	box(geo, "LedgerCabinets", Vector3(29, y, 137.5), Vector3(39, y + 2.6, 138.7), "metal")
	# F ramp: Chapel crypt (z 90, y -12) -> Core north (z 101, y -18)
	wall_z("RampFW", 17.5, 90, 101, y, DY + 3.0, [], "rock")
	wall_z("RampFE", 22.5, 90, 101, y, DY + 3.0, [], "rock")
	box(geo, "RampFRoof", Vector3(17.5, DY + 3.0, 90), Vector3(22.5, DY + 3.3, 101), "roof")
	ramp_z("RampF", 18.0, 22.0, 101.0, 90.0, y, DY)
	# (2026-11-12: the ramp runs 1.5 m west of the Core's west wall at x 19; its foot left a slit there into the void)
	wall_x("RampFFoot", 101.0, 17.35, 19.0, y, DY + 3.0, [], "rock")
	# G ramp: Generator south (z 82, y -12) -> Core north (z 101)
	wall_z("RampGW", 41.5, 82, 101, y, DY + 3.0, [], "rock")
	wall_z("RampGE", 47.5, 82, 101, y, DY + 3.0, [], "rock")
	box(geo, "RampGRoof", Vector3(41.5, DY + 3.0, 82), Vector3(47.5, DY + 3.3, 101), "roof")
	ramp_z("RampG", 42.0, 47.0, 101.0, 82.0, y, DY)
	# H ramp: Lab south (z 98, y -12) -> (z 112, y -18), then west along z 112..118 into the Core east door
	wall_z("RampHW", 71.5, 98, 112, y, DY + 3.0, [], "rock")
	wall_z("RampHE", 76.5, 98, 118, y, DY + 3.0, [], "rock")
	box(geo, "RampHRoof", Vector3(71.5, DY + 3.0, 98), Vector3(76.5, DY + 3.3, 112), "roof")
	ramp_z("RampH", 72.0, 76.0, 112.0, 98.0, y, DY)
	wall_x("CorrHN", 112.0, 49, 71.5, y, y + 3.5, [], "rock")
	wall_x("CorrHS", 118.0, 49, 76.5, y, y + 3.5, [], "rock")
	box(geo, "CorrHFloor", Vector3(49, y - 0.5, 112), Vector3(76.5, y, 118), "floor_stone")
	box(geo, "CorrHRoof", Vector3(49, y + 3.5, 112), Vector3(76.5, y + 3.8, 118), "roof")
	# 2026-11-12 (the owner's screenshot: a mine tunnel ending in "a box of sky"): the H ramp's roof is at DY + 3 and the
	# corridor's at y + 3.5, 5.5 m lower; nothing closed the step between them where the ramp meets the corridor (z 112),
	# so from the ramp and the corridor's east end you looked over the corridor's roof into the void and the sky dome.
	# A rock header wall fills it (found by tools: drawn-geometry rays from every walkable point, see DECISIONS T-241).
	wall_x("RampHHead", 112.0, 71.5, 76.5, y + 3.5, DY + 3.0, [], "rock")


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
		# back wall and two side walls
		var back: Vector3 = p + out_dir * 2.9
		box(geo, "ClosetBack", back - half_side + Vector3(0, 0, 0) - out_dir.abs() * 0.15 + Vector3(0, p.y - back.y, 0),
			back + half_side + out_dir.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")
		for s: float in [-1.0, 1.0]:
			var sp: Vector3 = center + side * 1.4 * s
			box(geo, "ClosetSide", sp - half_out - side.abs() * 0.15 + Vector3(0, p.y - sp.y, 0),
				sp + half_out + side.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")


## T-123: the yard props' hidden colliders (YARD_PROPS), in the Geometry the bake parses.
func build_yard_prop_blocks() -> void:
	for yp: Array in YARD_PROPS + KAUE_PROPS:
		box(geo, str(yp[0]), yp[1], yp[2], "furniture")


## T-226: the perk machines' footprints as hidden colliders (they make their own runtime bodies after the bake), so the
## navmesh goes round them instead of into them (T-027 on Map 0); capped under the agent height so no block leaves a
## walkable island on top of itself (T-051).
func build_perk_blocks() -> void:
	var pdata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perks.json"))["perks"]
	for pk: Array in PERKS:
		var fp: Vector3 = MACHINE_FOOTPRINTS.get(str((pdata[str(pk[0])] as Dictionary).get("shape", "cabinet")), Vector3(1.0, 2.0, 0.7))
		if absf(float(pk[2])) == 90.0:
			fp = Vector3(fp.z, fp.y, fp.x)
		var c: Vector3 = pk[1]
		box(geo, "NavBlock_Perk_" + str(pk[0]), c - Vector3(fp.x * 0.5, 0, fp.z * 0.5), c + Vector3(fp.x * 0.5, minf(fp.y, 1.6), fp.z * 0.5), "metal")


## T-226: the Core Vault's solid dressing (CORE_PROPS), baked.
func build_core_prop_blocks() -> void:
	for cp: Array in CORE_PROPS:
		box(geo, str(cp[0]), cp[1], cp[2], "metal")


## T-239: the solid dressing's hidden colliders (SOLID_PROPS, SOLID_ROUND), the bunks' foot lockers and the mess tables'
## benches (flush with the bunk / table they belong to, so a body slides along one face), and the dais' skirt.
func build_solid_props() -> void:
	for sp: Array in SOLID_PROPS:
		box(geo, str(sp[0]), sp[1], sp[2], "furniture")
	for bx: float in [-11.5, -6.0, -0.5, 4.0]:
		box(geo, "Prop_D_FootLockers", Vector3(bx, 0, 39.3), Vector3(bx + 2.0, 0.5, 40.0), "furniture")
	for i: int in 3:
		var x0: float = 12.0 + i * 8.0
		box(geo, "Prop_D_MessBenches", Vector3(x0, 0, 36.2), Vector3(x0 + 5.0, 0.47, 39.3), "furniture")   # (the table's length: one outline)
	for sr: Array in SOLID_ROUND:
		round_body(str(sr[0]), sr[1], float(sr[2]), float(sr[3]))
	# the dais' skirt: one convex wedge round the 0.3 m step (its foot DAIS_SKIRT out on the west, south and east sides)
	var a: Vector3 = Vector3(44.5, DY, 60.15)
	var b: Vector3 = Vector3(48.5, DY + 0.3, 62.0)
	var pts: PackedVector3Array = PackedVector3Array([
		Vector3(a.x - DAIS_SKIRT, a.y, a.z), Vector3(b.x + DAIS_SKIRT, a.y, a.z), Vector3(b.x + DAIS_SKIRT, a.y, b.z + DAIS_SKIRT),
		Vector3(a.x - DAIS_SKIRT, a.y, b.z + DAIS_SKIRT), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)])
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "DaisSkirt"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	hull.points = pts
	cs.shape = hull
	body.add_child(cs)
	geo.add_child(body)
	_count += 1


## T-239: a hidden upright cylinder collider on the world layer (a drum, a column, a mast): `at` is its foot's centre.
func round_body(n: String, at: Vector3, radius: float, height: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.position = at + Vector3(0, height * 0.5, 0)
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	geo.add_child(body)
	_count += 1


## T-225: the WASCHKAUE's shell (see KAUE_*): brick walls west, east and north (two wide doorways either side of the pier,
## under 0.5 m lintels) up to the flat roof below the yard wall's coping; the yard's own south wall is its back wall. Its
## furniture is YARD_PROPS' hidden colliders (the benches, the lockers, the stove, the lamp rack), drawn by _dress_kaue.
func build_kaue() -> void:
	var zw: float = 32.0 - T * 0.5   # the yard wall's inner face
	wall_z("KaueW", KAUE_X0, KAUE_Z0, zw, 0, KAUE_H, [], "brick")
	wall_z("KaueE", KAUE_X1, KAUE_Z0, zw, 0, KAUE_H, [], "brick")
	var ops: Array = []
	for d: Array in KAUE_DOORS:
		ops.append([float(d[0]), float(d[1]), 0.0, KAUE_H - 0.5])
	wall_x("KaueN", KAUE_Z0, KAUE_X0 - T * 0.5, KAUE_X1 + T * 0.5, 0, KAUE_H, ops, "brick")
	box(geo, "KaueRoof", Vector3(KAUE_X0 - T * 0.5, KAUE_H, KAUE_Z0 - T * 0.5), Vector3(KAUE_X1 + T * 0.5, KAUE_H + 0.2, zw), "concrete")
	# the night shift's brazier in front of the pier (its light is the facade's before the power); a hidden collider so
	# the navmesh goes round the drum (the headframe loop's lane loses 0.7 m of its 6 at one point)
	# (T-239: carried to the front wall: the 0.55 m slot between the drum and the pier wedged a player backing along it)
	box(geo, "NavBlock_KaueBrazier", Vector3(9.65, 0, 24.6), Vector3(10.35, 1.0, KAUE_Z0 - T * 0.5), "metal")


## The ammo boxes' footprints as hidden colliders, so the navmesh is cut round them (the boxes are placed in
## build_gameplay and make their own runtime collision).
func build_ammo_blocks() -> void:
	for ab: Array in AMMO_BOXES:
		var h: Vector3 = Vector3(0.52, 0, 0.3) if absf(float(ab[2])) != 90.0 else Vector3(0.3, 0, 0.52)
		var p: Vector3 = ab[1]
		box(geo, "NavBlock_Ammo_" + str(ab[0]), p - h, p + h + Vector3(0, 0.62, 0), "metal")
	var bp: Vector3 = ARMORERS_BENCH[0]   # the Armorer's Bench: 0.72 m out from the gatehouse, 1.5 m along it
	box(geo, "NavBlock_ArmorersBench", bp + Vector3(0, 0, -0.75), bp + Vector3(0.72, 0.9, 0.75), "metal")


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


# ================================================================== art dressing: fixtures

## Holder for one zone's powered glow parts (merged under that zone's first power light later).
func G(zone: String) -> Node3D:
	if not _glow.has(zone):
		var h: Node3D = Node3D.new()
		h.name = "PowerGlow_" + zone
		h.set_meta("keep", true)
		dress.add_child(h)
		_glow[zone] = h
	return _glow[zone]


## Registers a power light (OmniLight3D in group "power_lights", dark until its zone's sweep).
func power(zone: String, pos: Vector3, range_: float, energy: float, color: Color = SODIUM, shadow: bool = false,
		spot: Dictionary = {}, fog: float = -1.0) -> void:
	_power.append({"zone": zone, "pos": pos, "range": range_, "energy": energy, "color": color, "shadow": shadow, "spot": spot,
		"fog": fog})


## Registers an always-on light.
func lamp(pos: Vector3, color: Color, energy: float, range_: float, flicker: float = 0.0, fog: float = 0.0, shadow: bool = false,
		speed: float = 9.0) -> void:
	_static_lights.append({"pos": pos, "color": color, "energy": energy, "range": range_, "flicker": flicker, "fog": fog,
		"shadow": shadow, "speed": speed})


## Hanging lamp: cord, enamel shade, bulb. The lit bulb belongs to the zone's power holder.
func pendant(zone: String, p: Vector3, ceil_y: float, shade: String = "enamel_green", s: float = 1.0, glow_key: String = "bulb_warm") -> void:
	_noshadow(B(p + Vector3(-0.012, 0.2 * s, -0.012), Vector3(p.x + 0.012, ceil_y, p.z + 0.012), "iron", false))
	Props.cone(dress, p + Vector3(0, 0.12 * s, 0), 0.3 * s, 0.22 * s, shade)
	_noshadow(Props.ball(dress, p, Vector3(0.12, 0.15, 0.12) * s, "bulb_off"))
	_noshadow(Props.ball(G(zone), p, Vector3(0.14, 0.17, 0.14) * s, glow_key))


## Caged bulkhead lamp on a wall (local -Z faces the room).
func bulkhead(zone: String, p: Vector3, yaw: float, glow_key: String = "bulb_warm") -> void:
	var g: Node3D = Props.group(dress, "Bulkhead", p, yaw)
	Props.block(g, Vector3(-0.12, -0.12, -0.04), Vector3(0.12, 0.12, 0.0), "iron")
	Props.cyl(g, Vector3(0, 0, -0.1), 0.09, 0.14, "bulb_off", Vector3(90, 0, 0))
	for a: float in [0.0, 60.0, 120.0]:
		Props.obox(g, Vector3(0, 0, -0.12), Vector3(0.22, 0.015, 0.2), "iron", Vector3(0, 0, a))
	if zone == "":
		return
	var gg: Node3D = Props.group(G(zone), "BulkheadGlow", p, yaw)
	_noshadow(Props.cyl(gg, Vector3(0, 0, -0.1), 0.1, 0.15, glow_key, Vector3(90, 0, 0)))


## Emergency lamp: a red caged lamp that is always lit, with its own light.
func emergency(p: Vector3, yaw: float, energy: float = 0.9, range_: float = 9.0, flick: float = 0.12) -> void:
	var g: Node3D = Props.group(dress, "Emergency", p, yaw)
	Props.block(g, Vector3(-0.1, -0.1, -0.04), Vector3(0.1, 0.1, 0.0), "iron")
	_noshadow(Props.cyl(g, Vector3(0, 0, -0.1), 0.08, 0.14, "emergency_red", Vector3(90, 0, 0)))
	for a: float in [0.0, 90.0]:
		Props.obox(g, Vector3(0, 0, -0.11), Vector3(0.2, 0.015, 0.18), "iron", Vector3(0, 0, a))
	var out: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -0.5)
	lamp(p + out, RED, energy * 1.3, range_ + 2.0, flick, 0.0, false, 3.0)


## Floodlight on a bracket aimed at `aim`; lens glow and a cold spot come on with the zone's power.
func flood(zone: String, p: Vector3, aim: Vector3, spot_range: float = 30.0, spot_energy: float = 5.0, angle: float = 38.0) -> void:
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
	_noshadow(Props.block(gg, Vector3(-0.29, -0.22, -0.085), Vector3(0.29, 0.22, -0.06), "bulb_warm"))
	power(zone, p + dir * 0.6, 7.0, 0.8, FLOOD, false, {"dir": dir, "range": spot_range, "energy": spot_energy, "angle": angle}, 0.3)


## Gooseneck yard lamp on a wall bracket (local -Z faces the yard): an enamel shade over a sodium bulb that
## comes on with the zone's power, and its warm pool on the snow.
func goose(zone: String, p: Vector3, yaw: float, energy: float = 1.4, range_: float = 10.0) -> void:
	var g: Node3D = Props.group(dress, "Gooseneck", p, yaw)
	Props.block(g, Vector3(-0.08, -0.25, -0.03), Vector3(0.08, 0.1, 0.0), "iron")
	Props.strut(g, Vector3(0, 0, -0.03), Vector3(0, 0.25, -0.45), 0.035, "iron")
	Props.strut(g, Vector3(0, 0.25, -0.45), Vector3(0, 0.12, -0.8), 0.035, "iron")
	Props.cone(g, Vector3(0, 0.05, -0.8), 0.28, 0.2, "enamel_green")
	_noshadow(Props.ball(g, Vector3(0, -0.04, -0.8), Vector3(0.1, 0.12, 0.1), "bulb_off"))
	var gg: Node3D = Props.group(G(zone), "GooseGlow", p, yaw)
	_noshadow(Props.ball(gg, Vector3(0, -0.04, -0.8), Vector3(0.12, 0.14, 0.12), "sodium"))
	var out: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, -0.3, -0.85)
	power(zone, p + out, range_, energy, SODIUM, false, {}, 0.5)


## Flat radial stain/decal projected downward.
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


## A Node3D whose children spin (flywheels, the heart). Excluded from the global batches.
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


# ================================================================== art dressing

func build_dressing() -> void:
	_dress_ground()
	_dress_yard()
	_dress_headframe()
	_dress_hoist_house()
	_dress_yard_south()
	_dress_admin()
	_dress_barracks()
	_dress_railyard()
	_dress_lifthouse()
	_dress_stairwell()
	_dress_chapel()
	_dress_generator()
	_dress_lab()
	_dress_core()
	_dress_ramps()
	_dress_windows()
	_dress_doors()
	_dress_treads()
	_dress_readability()
	_dress_weather()


func _dress_ground() -> void:
	# trodden paths through the yard, round the headframe and out to both doors
	for r: Array in [[12.2, 15.0, 0.2, 31.8], [25.0, 27.8, 0.2, 31.8], [0.2, 39.8, 21.5, 28.5], [15.0, 25.0, 20.0, 23.0],
			[2.0, 12.2, 10.0, 12.5], [27.8, 39.8, 10.0, 12.0]]:
		_noshadow(B(Vector3(float(r[0]), 0.0, float(r[2])), Vector3(float(r[1]), 0.012, float(r[3])), "snow_trodden", false))
	# Rail yard: walkway between the tracks, ballast beds under them
	_noshadow(B(Vector3(45.6, 0.0, 14.2), Vector3(50.4, 0.012, 47.8), "snow_trodden", false))
	for cx: float in [44.0, 52.0, 57.0]:
		_noshadow(B(Vector3(cx - 1.6, 0.0, 14.2), Vector3(cx + 1.6, 0.04, 47.8), "ballast", false))
	# interior floors on the surface (the ground slab is the floor there)
	B(Vector3(-15.85, 0.0, 8.15), Vector3(-0.15, 0.015, 31.85), "floorboards")
	B(Vector3(-15.85, 0.0, 32.15), Vector3(39.85, 0.015, 45.85), "floorboards")
	# drifts against the yard walls and outside
	var drifts: Array = [
		[Vector3(3.5, 0, 0.7), Vector3(4.5, 0.6, 1.6)], [Vector3(36.2, 0, 0.6), Vector3(4.0, 0.5, 1.3)],
		[Vector3(0.6, 0, 1.2), Vector3(1.4, 0.5, 2.4)], [Vector3(39.3, 0, 30.5), Vector3(1.6, 0.5, 3.0)],
		[Vector3(1.0, 0, 30.6), Vector3(2.0, 0.5, 2.4)], [Vector3(59.3, 0, 15.5), Vector3(1.6, 0.5, 2.5)],
		[Vector3(-25, 0, -5), Vector3(12, 2.4, 10)], [Vector3(10, 0, -4), Vector3(16, 1.8, 6)], [Vector3(30, 0, -3), Vector3(14, 1.4, 4)],
		[Vector3(62, 0, 30), Vector3(4, 1.6, 30)], [Vector3(-19, 0, 20), Vector3(5, 1.6, 20)], [Vector3(50, 0, 10), Vector3(16, 1.6, 6)],
		[Vector3(2, 0, 49.5), Vector3(8, 1.0, 4)], [Vector3(35, 0, 54), Vector3(10, 1.2, 6)], [Vector3(53, 0, 50.5), Vector3(14, 1.0, 3)],
		[Vector3(12, 0, 49.5), Vector3(10, 0.9, 3.5)],
	]
	for d: Array in drifts:
		Props.snow_drift(dress, d[0], d[1])


func _coping_and_wire(a: Vector3, b: Vector3, out: Vector3, wire: bool) -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x) - 0.25, 4.0, minf(a.z, b.z) - 0.25)
	var hi: Vector3 = Vector3(maxf(a.x, b.x) + 0.25, 4.12, maxf(a.z, b.z) + 0.25)
	B(lo, hi, "concrete")
	_noshadow(B(lo + Vector3(0.03, 0.12, 0.03), hi + Vector3(-0.03, 0.06, -0.03), "snow", false))
	if wire:
		var off: Vector3 = out.normalized() * 0.12
		Props.barbed_wire(dress, a + Vector3(0, 4.12, 0) + off, b + Vector3(0, 4.12, 0) + off, out, 0.75)


func _dress_yard() -> void:
	_coping_and_wire(Vector3(0, 0, 0), Vector3(40, 0, 0), Vector3(0, 0, -1), true)
	_coping_and_wire(Vector3(40, 0, 0), Vector3(40, 0, 14), Vector3(1, 0, 0), true)
	_coping_and_wire(Vector3(40, 0, 14), Vector3(40, 0, 48), Vector3(1, 0, 0), false)
	_coping_and_wire(Vector3(0, 0, 0), Vector3(0, 0, 8), Vector3(-1, 0, 0), true)
	_coping_and_wire(Vector3(40, 0, 14), Vector3(60, 0, 14), Vector3(0, 0, -1), true)
	_coping_and_wire(Vector3(60, 0, 14), Vector3(60, 0, 48), Vector3(1, 0, 0), true)
	_coping_and_wire(Vector3(40, 0, 48), Vector3(60, 0, 48), Vector3(0, 0, 1), true)
	# the yard's west wall north of the Admin Block (its greybox piece is hidden with the shared part)
	B(Vector3(-0.15, 0, 4.8), Vector3(0.15, 4.0, 8.0), "brick")
	# gate pillars and the mine's name board, seen over the north wall
	for gx: float in [17.1, 22.9]:
		B(Vector3(gx - 0.5, 0, -1.2), Vector3(gx + 0.5, 5.0, 0.0), "brick")
		B(Vector3(gx - 0.6, 5.0, -1.3), Vector3(gx + 0.6, 5.25, 0.1), "concrete")
		_noshadow(Props.ball(dress, Vector3(gx, 5.45, -0.6), Vector3(0.36, 0.36, 0.36), "lantern_glass"))
		lamp(Vector3(gx, 5.45, -0.1), Color(1.0, 0.68, 0.38), 0.7, 6.0, 0.08)
	B(Vector3(17.6, 4.55, -0.95), Vector3(22.4, 5.35, -0.8), "planks")
	_noshadow(B(Vector3(17.6, 5.35, -0.97), Vector3(22.4, 5.42, -0.78), "snow", false))
	_label("SALZBERGWERK KALTENBRUNN", Vector3(20, 4.95, -0.79), 0.0, 44, Color(0.9, 0.86, 0.74, 0.9))
	# Gatehouse: flat roof with a lip, chimney, lit windows, door
	B(Vector3(3.8, 3.5, 3.8), Vector3(12.2, 3.6, 10.2), "concrete")
	_noshadow(B(Vector3(3.85, 3.6, 3.85), Vector3(12.15, 3.67, 10.15), "snow", false))
	B(Vector3(4.3, 3.5, 4.3), Vector3(5.3, 4.9, 5.3), "brick")
	Props.smoke(dress, Vector3(4.8, 5.0, 4.8), 0.2, 0.6, 12)
	for wx: float in [5.2, 10.8]:
		B(Vector3(wx - 0.55, 1.15, 10.0), Vector3(wx + 0.55, 2.25, 10.05), "concrete")
		_noshadow(B(Vector3(wx - 0.45, 1.25, 10.04), Vector3(wx + 0.45, 2.15, 10.07), "lantern_glass", false))
		B(Vector3(wx - 0.03, 1.25, 10.05), Vector3(wx + 0.03, 2.15, 10.09), "beam")
		B(Vector3(wx - 0.6, 1.1, 10.0), Vector3(wx + 0.6, 1.17, 10.25), "concrete")
	B(Vector3(3.95, 0.0, 6.4), Vector3(4.0, 2.2, 7.6), "planks")
	Props.wall_lamp(dress, Vector3(3.95, 2.45, 8.0), 90.0)
	lamp(Vector3(3.2, 2.3, 8.0), Color(1.0, 0.68, 0.38), 1.0, 7.0, 0.1)
	_label("WACHE", Vector3(8, 2.75, 10.03), 0.0, 36, Color(0.85, 0.82, 0.72, 0.8))
	# Winding-engine house (the old coal shed): gable roof, a tall stack, high windows
	B(Vector3(27.7, 3.0, 3.7), Vector3(38.3, 3.1, 10.3), "concrete")
	Props.gable_roof(dress, Vector3(27.7, 3.1, 3.7), Vector3(38.3, 3.1, 10.3), 1.4, true)
	CYL(Vector3(36.8, 7.0, 5.0), 0.5, 8.0, "brick")
	CYL(Vector3(36.8, 11.1, 5.0), 0.58, 0.25, "concrete")
	Props.smoke(dress, Vector3(36.8, 11.3, 5.0), 0.3, 1.0, 20)
	for wx2: float in [30.0, 36.3]:
		B(Vector3(wx2 - 0.6, 1.7, 10.0), Vector3(wx2 + 0.6, 2.6, 10.05), "concrete")
		_noshadow(B(Vector3(wx2 - 0.5, 1.8, 10.04), Vector3(wx2 + 0.5, 2.5, 10.07), "window_dark", false))
	B(Vector3(27.95, 0, 6.2), Vector3(28.0, 2.3, 7.8), "planks")
	_label("FÖRDERMASCHINE", Vector3(33, 2.75, 10.03), 0.0, 32, Color(0.85, 0.82, 0.72, 0.8))
	# narrow-gauge spur along the north wall with ore carts
	for k: int in 31:
		var sx: float = 10.6 + k * 0.62
		B(Vector3(sx - 0.07, 0.0, 0.45), Vector3(sx + 0.07, 0.07, 1.55), "beam")
	for rz: float in [0.72, 1.28]:
		B(Vector3(10.5, 0.07, rz - 0.03), Vector3(29.8, 0.14, rz + 0.03), "rust")
	Props.ore_cart(dress, Vector3(13.4, 0.07, 1.0), 90.0)
	Props.ore_cart(dress, Vector3(15.3, 0.07, 1.0), 90.0)
	# (T-239, all of these over their Prop_A_* colliders: the third cart stands on the spur, tipped toward the yard with its
	# salt spilled beside it, not across the rails with a knee-high heap in the lane to the ground spawn)
	Props.ore_cart(dress, Vector3(27.6, 0.07, 1.0), 90.0, "ore_salt", 12.0)
	_noshadow(Props.ball(dress, Vector3(27.7, 0.0, 2.0), Vector3(1.7, 0.26, 0.8), "ore_salt"))
	# the night shift's drums against the east wall, their brazier (an upright open drum: it lay on its side under its own
	# flames) at the row's yard end
	for dp: Vector3 in [Vector3(39.52, 0, 12.25), Vector3(39.52, 0, 12.9), Vector3(39.52, 0, 13.55)]:
		Props.oil_drum(dress, dp, "rust")
	Props.oil_drum(dress, Vector3(38.86, 0, 12.9), "rust")   # (Prop_A_EastBrazier, round, against the row)
	Props.flames(dress, Vector3(38.86, 0.92, 12.9), 0.42, 0.55, 20)
	Props.embers(dress, Vector3(38.86, 1.1, 12.9), 0.2, 8)
	lamp(Vector3(38.4, 1.6, 12.9), Color(1.0, 0.5, 0.2), 2.0, 9.0, 0.35, 0.6)
	# crates by the winding house door, against its wall (they stood 0.75 m off it in the 3 m lane)
	Props.crate(dress, Vector3(27.5, 0, 4.75), 0.9, 3.0, "SALZ")
	Props.crate(dress, Vector3(27.55, 0.9, 4.75), 0.6, -12.0)
	# under the Administration's balcony: a crate and a sandbag wall, one line against the wall
	Props.crate(dress, Vector3(0.62, 0, 10.35), 0.8, 3.0)
	Props.sandbags(dress, Vector3(0.55, 0, 10.9), Vector3(0.55, 0, 13.5), 2)
	# the brazier in the lane by the Administration door (Prop_A_WestBrazier, a round collider): against the wall between
	# the window and the door's canopy, under the gooseneck
	Props.oil_drum(dress, Vector3(0.62, 0, 20.4), "rust")
	Props.flames(dress, Vector3(0.62, 0.92, 20.4), 0.45, 0.6, 22)
	Props.embers(dress, Vector3(0.62, 1.1, 20.4), 0.2, 8)
	lamp(Vector3(1.1, 1.6, 20.4), Color(1.0, 0.5, 0.2), 2.4, 10.0, 0.35, 0.6)
	# the gatehouse lane (the Armorer's Bench) and the corner behind the winding house (a ground spawn, two windows) had
	# no light of their own before the power: a lantern on the gatehouse's east wall and one on the north wall
	Props.wall_lamp(dress, Vector3(12.03, 2.45, 5.6), -90.0)
	lamp(Vector3(12.8, 2.3, 5.6), Color(1.0, 0.68, 0.38), 1.0, 7.0, 0.1)
	Props.wall_lamp(dress, Vector3(34.5, 2.45, 0.17), 180.0)
	lamp(Vector3(34.5, 2.3, 0.9), Color(1.0, 0.68, 0.38), 1.0, 8.0, 0.1)
	# sodium goosenecks on the yard walls (dark until the sweep reaches the yard)
	for gn: Array in [[Vector3(12.0, 3.5, 0.15), 180.0], [Vector3(28.0, 3.5, 0.15), 180.0], [Vector3(39.85, 3.5, 18.0), 90.0],
			[Vector3(18.6, 3.4, 31.85), 0.0], [Vector3(31.0, 3.4, 31.85), 0.0], [Vector3(0.15, 3.0, 21.0), -90.0],
			[Vector3(6.8, KAUE_H - 0.3, KAUE_Z0 - 0.22), 0.0], [Vector3(13.2, KAUE_H - 0.3, KAUE_Z0 - 0.22), 0.0]]:   # (T-225: the Kaue's front, on its lintel band)
		goose("A_MINEHEAD", gn[0], float(gn[1]))


## T-123: the headframe's base (TowerBase, a bare 10 x 10 x 6 m concrete block) dressed as the hoist house: a brick
## plinth, corner pilasters and a cornice, barred high windows, the shaft's signal box and conduit, the notices. Visual
## only and flush to the faces (0.12 m at most), so the collider, the navmesh and the headframe loop are unchanged.
func _dress_hoist_house() -> void:
	var x0: float = 15.0
	var x1: float = 25.0
	var z0: float = 10.0
	var z1: float = 20.0
	B(Vector3(x0 - 0.06, 0.0, z0 - 0.06), Vector3(x1 + 0.06, 0.9, z1 + 0.06), "brick")
	B(Vector3(x0 - 0.08, 0.9, z0 - 0.08), Vector3(x1 + 0.08, 0.98, z1 + 0.08), "concrete")
	B(Vector3(x0 - 0.12, 5.55, z0 - 0.12), Vector3(x1 + 0.12, 6.0, z1 + 0.12), "concrete")
	_noshadow(B(Vector3(x0 - 0.1, 6.0, z0 - 0.1), Vector3(x1 + 0.1, 6.06, z1 + 0.1), "snow", false))
	for cx: float in [x0, x1]:
		for cz: float in [z0, z1]:
			var sx: float = -1.0 if cx == x0 else 1.0
			var sz: float = -1.0 if cz == z0 else 1.0
			B(Vector3(minf(cx + sx * 0.1, cx - sx * 0.5), 0.98, minf(cz + sz * 0.1, cz - sz * 0.5)),
				Vector3(maxf(cx + sx * 0.1, cx - sx * 0.5), 5.55, maxf(cz + sz * 0.1, cz - sz * 0.5)), "brick")
	# barred high windows: two on each side face and on the south face either side of the stencil
	var wins: Array = [   # [centre on the face, outward normal]
		[Vector3(16.6, 3.9, z1), Vector3(0, 0, 1)], [Vector3(23.4, 3.9, z1), Vector3(0, 0, 1)],
		[Vector3(x0, 3.9, 12.6), Vector3(-1, 0, 0)], [Vector3(x0, 3.9, 17.4), Vector3(-1, 0, 0)],
		[Vector3(x1, 3.9, 12.6), Vector3(1, 0, 0)], [Vector3(x1, 3.9, 17.4), Vector3(1, 0, 0)],
	]
	for w: Array in wins:
		var c: Vector3 = w[0]
		var nrm: Vector3 = w[1]
		var along: Vector3 = Vector3(absf(nrm.z), 0, absf(nrm.x))   # the face's horizontal direction
		B(c - along * 0.55 + Vector3(0, -0.8, 0), c + along * 0.55 + Vector3(0, 0.8, 0) + nrm * 0.08, "concrete")
		_noshadow(B(c - along * 0.45 + Vector3(0, -0.7, 0) + nrm * 0.07, c + along * 0.45 + Vector3(0, 0.7, 0) + nrm * 0.1, "window_dark", false))
		for k: int in 4:
			var bp: Vector3 = c + along * (-0.33 + 0.22 * k) + nrm * 0.11
			B(bp + Vector3(-0.015, -0.7, -0.015), bp + Vector3(0.015, 0.7, 0.015), "iron")
		B(c - along * 0.6 + Vector3(0, -0.88, 0), c + along * 0.6 + Vector3(0, -0.8, 0) + nrm * 0.12, "concrete")
	# south face (the side the squad starts on): the shaft-signal box, its conduit and bell, the closure notice
	Props.fuse_box(dress, Vector3(23.6, 1.6, z1), 180.0, 0.6, 0.8)
	Props.pipe(dress, Vector3(23.75, 2.0, z1 + 0.06), Vector3(23.75, 5.5, z1 + 0.06), 0.035, "iron")
	CYL(Vector3(23.1, 2.55, z1 + 0.1), 0.13, 0.16, "brass")
	B(Vector3(23.05, 2.7, z1), Vector3(23.15, 2.78, z1 + 0.12), "iron")
	B(Vector3(15.7, 1.05, z1), Vector3(17.25, 1.95, z1 + 0.05), "planks")
	_noshadow(B(Vector3(15.8, 1.12, z1 + 0.05), Vector3(17.15, 1.88, z1 + 0.06), "paper", false))
	_label("SEILFAHRT\nEINGESTELLT", Vector3(16.47, 1.5, z1 + 0.07), 0.0, 22, Color(0.2, 0.17, 0.14, 0.95))
	# north face: a lintel over the iron door, the warning, a bulkhead lamp
	B(Vector3(18.4, 2.4, z0 - 0.1), Vector3(21.6, 2.65, z0), "concrete")
	_label("BETRETEN VERBOTEN", Vector3(20.0, 2.95, z0 - 0.02), 180.0, 30, Color(0.85, 0.82, 0.72, 0.85))
	Props.bulkhead_lamp(dress, Vector3(20.0, 3.45, z0), 0.0)
	# east face: the cable conduit to the winding engine
	Props.pipe(dress, Vector3(x1 + 0.06, 0.98, 15.0), Vector3(x1 + 0.06, 5.5, 15.0), 0.05, "iron")
	Props.pipe(dress, Vector3(x1 + 0.06, 0.98, 15.3), Vector3(x1 + 0.06, 5.5, 15.3), 0.035, "iron")


## T-123 / T-225: the yard's south side, where the squad starts. T-123 dressed the bare wall (the tag board, the lamp
## rack, pit props, a workbench, a tipped ore cart, crates); T-225 built the WASCHKAUE over the west half of it (see
## KAUE_*, _dress_kaue) and moved the brazier out to the lane by the Administration door. East of the Kaue: the squad's
## sled with its kit by the east doorway, the yard's ammo box under its lantern, the pit props and the spare set, the
## workbench under the gooseneck, the tipped ore cart in its salt, crates and sacks in the corner. Every solid prop has a
## hidden YardProp* collider (YARD_PROPS), baked into the navmesh.
func _dress_yard_south() -> void:
	var wz: float = 31.85   # the south wall's yard face
	_dress_kaue()
	# the squad's sled against the wall east of the Kaue (over YardPropSled): iron runners, slats, the kit crate from the
	# inn, a rolled blanket and a coil of rope; their trail trodden in from the gate, down the gatehouse lane to the west
	# doorway (the night shift's brazier in the lane by the Admin door is _dress_yard's)
	for sx: float in [16.37, 16.93]:   # (T-239: the sled stands in the corner against the Kaue's wall, 0.75 m west)
		OB(Vector3(sx, 0.08, 30.6), Vector3(0.05, 0.1, 1.5), "iron")
	B(Vector3(16.3, 0.16, 30.0), Vector3(17.0, 0.21, 31.2), "planks")
	Props.crate(dress, Vector3(16.65, 0.21, 30.65), 0.55, 5.0, "KREUZWEG")
	OB(Vector3(16.65, 0.86, 31.0), Vector3(0.5, 0.2, 0.2), "cloth_red", Vector3(0, 8, 0))
	Props.rope_coil(dress, Vector3(16.65, 0.21, 30.15), 0.14)
	_noshadow(OB(Vector3(16.75, 0.006, 5.85), Vector3(1.3, 0.012, 11.3), "snow_trodden", Vector3(0, -34.95, 0)))
	_noshadow(B(Vector3(12.85, 0.0, 10.4), Vector3(14.15, 0.012, 21.2), "snow_trodden", false))
	_noshadow(OB(Vector3(10.15, 0.006, 23.4), Vector3(1.3, 0.012, 8.2), "snow_trodden", Vector3(0, -54.4, 0)))
	# a lantern over the yard's ammo box (unpowered, like the gatehouse's)
	Props.wall_lamp(dress, Vector3(20.0, 2.4, wz), 0.0)
	lamp(Vector3(20.0, 2.2, 31.1), Color(1.0, 0.68, 0.38), 1.2, 8.0, 0.08)
	# a stack of pit props (timber for the roof sets below) and a spare set stood against the wall
	for layer: int in 3:
		var n: int = 4 - layer
		for li2: int in n:
			var lz: float = 30.85 + (li2 + layer * 0.5) * 0.3
			CYL(Vector3(24.5, 0.15 + layer * 0.27, lz), 0.14, 4.0, "pine", Vector3(0, 0, 90))
	for stx: float in [22.5, 26.5]:
		B(Vector3(stx - 0.06, 0, 30.6), Vector3(stx + 0.06, 1.0, 30.72), "beam")
	Props.pit_prop(dress, Vector3(28.5, 0, 31.6), 0.0, 2.2, 2.4)
	# (T-239: lagging boards stood inside the set, so the frame its collider closes reads closed)
	for lb: int in 6:
		OB(Vector3(27.78 + lb * 0.29, 1.0, 31.68 - (lb % 2) * 0.05), Vector3(0.26, 2.0 - (lb % 3) * 0.12, 0.04), "planks", Vector3(-4, 0, 0))
	# the workbench under the gooseneck, picks and shovels on a board over it
	Props.workbench(dress, Vector3(31.5, 0, 31.45), 0.0, 2.0, 0.7)
	B(Vector3(30.6, 1.25, wz - 0.04), Vector3(32.4, 2.15, wz), "planks")
	for tx: float in [30.9, 31.5, 32.1]:
		Props.strut(dress, Vector3(tx, 1.3, wz - 0.08), Vector3(tx, 2.05, wz - 0.08), 0.035, "pine", true)
	B(Vector3(30.7, 1.95, wz - 0.12), Vector3(31.1, 2.02, wz - 0.05), "iron")
	B(Vector3(31.3, 1.95, wz - 0.12), Vector3(31.7, 2.02, wz - 0.05), "iron")
	B(Vector3(31.97, 1.25, wz - 0.12), Vector3(32.23, 1.5, wz - 0.06), "iron")
	# a tipped ore cart that spilled its salt
	Props.ore_cart(dress, Vector3(35.0, 0.0, 30.9), 90.0, "", 14.0)
	_noshadow(Props.ball(dress, Vector3(33.6, 0.0, 30.5), Vector3(1.1, 0.32, 0.9), "ore_salt"))
	_noshadow(Props.ball(dress, Vector3(34.6, 0.0, 29.9), Vector3(0.8, 0.2, 0.6), "ore_salt"))
	# crates and sacks in the corner (the drift beyond them is the old one)
	# (T-239: stacked square to the wall with the sacks on top of the bottom row; two sacks stood loose in front of it)
	Props.crate(dress, Vector3(37.07, 0, 31.38), 0.9, 2.0, "SALZ")
	Props.crate(dress, Vector3(38.0, 0, 31.4), 0.86, -3.0)
	Props.crate(dress, Vector3(37.4, 0.9, 31.48), 0.62, 9.0)
	Props.sack(dress, Vector3(38.05, 0.86, 31.45), 70.0, 0.9)
	# a trodden strip along the wall: the squad's way from the Kaue's east door to the box and the bench
	_noshadow(B(Vector3(16.3, 0.0, 28.6), Vector3(36.5, 0.012, 30.6), "snow_trodden", false))


## T-225 (touched up after the owner's look): the Waschkaue inside and out. Its shell is build_kaue's; the flat slab is
## hidden and the roof drawn as a lean-to against the yard wall (zinc sheets under snow, the eaves on the front wall's
## top with rafter tails, a fascia, a gutter and downpipes, barge boards on the gables, brick wedges closing the gable
## walls under the slope, the stove's brick stack through it). The front: a plinth, corner pilasters, one lintel band
## over both doorways, a string course under the eaves, steel sliding doors slid back over the pier on their rail, the
## name on a board over the pier, a lantern on a bracket at each corner and the night shift's brazier before the pier
## (the yard before the power was a black box with two black holes). Lit windows in the gable ends. Inside: the floor
## and its drain, the boarded underside of the lean-to on its rafters, the benches with boots and a lunch pail, the
## lockers (two hanging open, a jacket in one), the stove with its glow, the coal and the poker, the tag board (a brass
## tag per man; the empty hooks the men still down there), the lamp rack, the clothes baskets on their chains under the
## rafters (the high ones hauled up, their men below), the wash trough and shift board on the pier, the broom and bucket,
## the hurricane lanterns on the benches, the lantern over the lockers (the spawn lit before the power) and the two
## enamel pendants that come on with the yard.
func _dress_kaue() -> void:
	var x0: float = KAUE_X0 + 0.15
	var x1: float = KAUE_X1 - 0.15
	var z0: float = KAUE_Z0 + 0.15
	var zf: float = KAUE_Z0 - 0.15   # the front face
	var wz: float = KAUE_ZW
	var slope: float = (KAUE_BACK - KAUE_H) / (wz - zf)
	var ang: float = rad_to_deg(atan(slope))
	# ---- the roof: sheets on the slope with an overhang at the front and the sides, snow, the fascia and rafter tails,
	# a gutter and two downpipes, barge boards, the brick wedges over the gable walls, the stack
	var zr0: float = zf - 0.45
	var r_len: float = (wz - zr0) / cos(atan(slope))
	var r_mid: Vector3 = Vector3(10.0, _kaue_roof_y((zr0 + wz) * 0.5), (zr0 + wz) * 0.5)
	OB(r_mid, Vector3(12.9, 0.06, r_len), "zinc", Vector3(-ang, 0, 0))
	_noshadow(OB(r_mid + Vector3(0, 0.08, 0), Vector3(12.8, 0.1, r_len * 0.98), "snow", Vector3(-ang, 0, 0)))
	for k: int in 7:   # the sheets' seams
		var sx: float = 4.0 + k * 2.0
		OB(Vector3(sx, r_mid.y + 0.035, r_mid.z), Vector3(0.05, 0.03, r_len), "iron", Vector3(-ang, 0, 0))
	OB(Vector3(10.0, _kaue_roof_y(zr0) - 0.08, zr0 + 0.02), Vector3(12.9, 0.2, 0.04), "planks")   # the fascia
	for k2: int in 13:   # the rafter tails under the overhang
		OB(Vector3(4.0 + k2 * 1.0, _kaue_roof_y(zf - 0.22) - 0.12, zf - 0.22), Vector3(0.08, 0.14, 0.5), "beam", Vector3(-ang, 0, 0))
	CYL(Vector3(10.0, _kaue_roof_y(zr0) - 0.2, zr0 - 0.02), 0.07, 12.9, "zinc", Vector3(0, 0, 90))   # the gutter
	for dx: float in [3.7, 16.3]:
		Props.pipe(dress, Vector3(dx, _kaue_roof_y(zr0) - 0.2, zr0 - 0.02), Vector3(dx, 0.35, zr0 + 0.1), 0.045, "zinc")
		Props.pipe(dress, Vector3(dx, 0.35, zr0 + 0.1), Vector3(dx + (0.25 if dx < 10.0 else -0.25), 0.1, zr0 + 0.1), 0.045, "zinc")
	for bx: float in [3.57, 16.43]:   # barge boards
		OB(Vector3(bx, r_mid.y - 0.1, r_mid.z), Vector3(0.04, 0.2, r_len), "planks", Vector3(-ang, 0, 0))
	for wx: float in [KAUE_X0, KAUE_X1]:   # the brick wedges that close the gable walls under the slope
		_wedge_z(Vector3(wx, KAUE_H, (zf + wz) * 0.5), wz - zf, KAUE_BACK - KAUE_H, T, "brick")
	B(Vector3(9.85, KAUE_H - 0.2, 30.4), Vector3(10.45, 5.0, 31.0), "brick")   # the stove's stack
	B(Vector3(9.78, 5.0, 30.33), Vector3(10.52, 5.12, 31.07), "concrete")
	CYL(Vector3(10.15, 5.3, 30.7), 0.09, 0.4, "iron")
	Props.smoke(dress, Vector3(10.15, 5.55, 30.7), 0.15, 0.6, 10)
	# ---- the front: plinth, corner pilasters, the lintel band, the string course, the name board, the sliding doors
	# (T-239: the plinth stops at the doorways; it ran across both of them as a 0.45 m kerb the squad walked through)
	for ps: Array in [[3.75, float(KAUE_DOORS[0][0])], [float(KAUE_DOORS[0][1]), float(KAUE_DOORS[1][0])], [float(KAUE_DOORS[1][1]), 16.25]]:
		B(Vector3(float(ps[0]), 0, zf - 0.08), Vector3(float(ps[1]), 0.45, zf), "concrete")
	for px: Array in [[3.75, 4.25], [15.75, 16.25]]:
		B(Vector3(float(px[0]), 0.45, zf - 0.15), Vector3(float(px[1]), KAUE_H, zf), "brick")
		B(Vector3(float(px[0]) - 0.03, 0.45, zf - 0.18), Vector3(float(px[1]) + 0.03, 0.53, zf), "concrete")
	B(Vector3(3.75, 0, zf - 0.1), Vector3(3.85, 0.45, wz), "concrete")
	B(Vector3(16.15, 0, zf - 0.1), Vector3(16.25, 0.45, wz), "concrete")
	B(Vector3(3.75, KAUE_H - 0.5, zf - 0.07), Vector3(16.25, KAUE_H - 0.24, zf), "concrete")   # the lintel band over both doorways
	for d: Array in KAUE_DOORS:   # the doorways' inner lintels and reveals
		B(Vector3(float(d[0]) - 0.2, KAUE_H - 0.5, z0 - 0.02), Vector3(float(d[1]) + 0.2, KAUE_H - 0.26, z0 + 0.06), "concrete")
		for rx: float in [float(d[0]), float(d[1])]:
			B(Vector3(rx - 0.06, 0, zf), Vector3(rx + 0.06, KAUE_H - 0.5, z0), "concrete")
	B(Vector3(3.75, KAUE_H - 0.18, zf - 0.05), Vector3(16.25, KAUE_H - 0.1, zf), "concrete")   # the string course under the eaves
	B(Vector3(8.3, KAUE_H - 0.48, zf - 0.13), Vector3(11.7, KAUE_H - 0.04, zf - 0.07), "planks")   # the name board
	_label("WASCHKAUE", Vector3(10.0, KAUE_H - 0.26, zf - 0.135), 180.0, 30, Color(0.85, 0.82, 0.72, 0.9))
	# the sliding doors: a rail on brackets along the front, two steel leaves slid back over the pier (one from each
	# doorway, on their own planes), their hangers and wheels, a handle each
	B(Vector3(4.5, KAUE_H - 0.62, zf - 0.2), Vector3(15.5, KAUE_H - 0.56, zf - 0.14), "iron")
	var bx2: float = 4.6
	while bx2 < 15.5:
		B(Vector3(bx2 - 0.03, KAUE_H - 0.64, zf - 0.14), Vector3(bx2 + 0.03, KAUE_H - 0.54, zf), "iron")
		bx2 += 1.2
	for leaf: Array in [[8.95, zf - 0.32], [9.05, zf - 0.40]]:   # [west x, face z]
		var lx: float = float(leaf[0])
		var lz: float = float(leaf[1])
		B(Vector3(lx, 0.08, lz), Vector3(lx + 2.0, 2.62, lz + 0.05), "machine_grey")
		for fy: Array in [[0.08, 0.16], [2.54, 2.62], [1.3, 1.36]]:
			B(Vector3(lx - 0.01, float(fy[0]), lz - 0.015), Vector3(lx + 2.01, float(fy[1]), lz + 0.065), "iron")
		for fx: float in [lx, lx + 1.93]:
			B(Vector3(fx - 0.01, 0.08, lz - 0.015), Vector3(fx + 0.08, 2.62, lz + 0.065), "iron")
		for hx: float in [lx + 0.4, lx + 1.6]:
			B(Vector3(hx - 0.03, 2.5, lz + 0.05), Vector3(hx + 0.03, KAUE_H - 0.6, zf - 0.17), "iron")
			CYL(Vector3(hx, KAUE_H - 0.56, zf - 0.17), 0.07, 0.03, "steel", Vector3(0, 0, 90))
		var hxx: float = lx + 0.3 if lx < 9.0 else lx + 1.7
		B(Vector3(hxx - 0.02, 1.1, lz - 0.06), Vector3(hxx + 0.02, 1.5, lz), "iron")
	# the corner lanterns on their brackets, the night shift's brazier before the pier (over NavBlock_KaueBrazier)
	for cx: float in [4.0, 16.0]:
		Props.strut(dress, Vector3(cx, 2.4, zf - 0.15), Vector3(cx, 2.36, zf - 0.55), 0.03, "iron")
		Props.strut(dress, Vector3(cx, 2.1, zf - 0.15), Vector3(cx, 2.34, zf - 0.5), 0.02, "iron")
		_hurricane(Vector3(cx, 2.02, zf - 0.55), 1.0)
	Props.oil_drum(dress, Vector3(10.0, 0, 24.95), "rust")
	Props.flames(dress, Vector3(10.0, 0.92, 24.95), 0.42, 0.55, 20)
	Props.embers(dress, Vector3(10.0, 1.1, 24.95), 0.2, 8)
	lamp(Vector3(10.0, 1.6, 24.95), Color(1.0, 0.5, 0.2), 2.2, 10.0, 0.35, 0.6)
	_noshadow(B(Vector3(9.0, 0.0, 24.0), Vector3(11.0, 0.012, 25.6), "snow_trodden", false))
	# ---- the gable windows: a steel three-light with bars in each end wall, lit from inside; its frame on the inner face
	for side: Array in [[KAUE_X0 - 0.15, -1.0], [KAUE_X1 + 0.15, 1.0]]:
		var fx2: float = float(side[0])
		var o: float = float(side[1])
		var wa: Vector3 = Vector3(fx2, 1.7, 28.5)
		var wb: Vector3 = Vector3(fx2 + o * 0.08, 2.5, 29.7)
		B(Vector3(minf(wa.x, wb.x), wa.y - 0.1, wa.z - 0.1), Vector3(maxf(wa.x, wb.x), wb.y + 0.1, wb.z + 0.1), "concrete")
		_noshadow(B(Vector3(minf(fx2 + o * 0.07, fx2 + o * 0.1), 1.75, 28.55), Vector3(maxf(fx2 + o * 0.07, fx2 + o * 0.1), 2.45, 29.65), "lantern_glass", false))
		for mz: float in [28.9, 29.3]:
			B(Vector3(minf(fx2 + o * 0.1, fx2 + o * 0.12), 1.75, mz - 0.015), Vector3(maxf(fx2 + o * 0.1, fx2 + o * 0.12), 2.45, mz + 0.015), "iron")
		B(Vector3(minf(fx2 + o * 0.1, fx2 + o * 0.12), 2.08, 28.55), Vector3(maxf(fx2 + o * 0.1, fx2 + o * 0.12), 2.12, 29.65), "iron")
		B(Vector3(minf(fx2, fx2 + o * 0.14), 1.58, 28.4), Vector3(maxf(fx2, fx2 + o * 0.14), 1.7, 29.8), "concrete")   # the sill
		lamp(Vector3(fx2 + o * 0.5, 2.1, 29.1), Color(1.0, 0.7, 0.4), 0.7, 5.0, 0.08)
		var ix: float = fx2 - o * T   # the inner face
		B(Vector3(minf(ix, ix - o * 0.06), 1.6, 28.4), Vector3(maxf(ix, ix - o * 0.06), 2.6, 29.8), "beam")
		_noshadow(B(Vector3(minf(ix - o * 0.02, ix - o * 0.07), 1.7, 28.5), Vector3(maxf(ix - o * 0.02, ix - o * 0.07), 2.5, 29.7), "window_dark", false))
		B(Vector3(minf(ix - o * 0.07, ix - o * 0.09), 1.7, 29.08), Vector3(maxf(ix - o * 0.07, ix - o * 0.09), 2.5, 29.12), "beam")
	# ---- inside: the floor and its drain, the boarded underside of the lean-to on its rafters, the wall plates
	_noshadow(B(Vector3(x0, 0.0, z0), Vector3(x1, 0.012, wz), "concrete_floor", false))
	_noshadow(CYL(Vector3(10.15, 0.014, 29.2), 0.3, 0.004, "steel_grate"))
	var c_mid: Vector3 = Vector3(10.0, _kaue_roof_y((z0 + wz) * 0.5) - 0.07, (z0 + wz) * 0.5)
	var c_len: float = (wz - z0) / cos(atan(slope))
	_noshadow(OB(c_mid, Vector3(x1 - x0, 0.03, c_len), "planks", Vector3(-ang, 0, 0)))
	for jx: float in [4.65, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 15.35]:
		OB(Vector3(jx, c_mid.y - 0.16, c_mid.z), Vector3(0.1, 0.16, c_len), "beam", Vector3(-ang, 0, 0))
	B(Vector3(x0, KAUE_H - 0.5, z0), Vector3(x1, KAUE_H - 0.26, z0 + 0.08), "beam")   # the front wall plate over the lintels
	B(Vector3(x0, KAUE_BACK - 0.3, wz - 0.1), Vector3(x1, KAUE_BACK - 0.08, wz), "beam")   # the back plate on the yard wall
	# the benches (over KauePropBenchW / E), boots and a lunch pail under the west one, clogs under the east one
	for bx: Array in [[x0, x0 + 0.45], [x1 - 0.45, x1]]:
		B(Vector3(float(bx[0]), 0.4, 27.2), Vector3(float(bx[1]), 0.45, wz), "planks")
		for bz: float in [27.4, 28.85, 30.3, 31.7]:
			B(Vector3(float(bx[0]) + 0.05, 0, bz - 0.03), Vector3(float(bx[1]) - 0.05, 0.4, bz + 0.03), "beam")
	for k3: int in 2:
		OB(Vector3(x0 + 0.22, 0.12, 28.1 + k3 * 0.16), Vector3(0.3, 0.24, 0.11), "leather", Vector3(0, -8 + k3 * 16, 0))
	CYL(Vector3(x0 + 0.25, 0.1, 29.6), 0.09, 0.2, "zinc")
	for k4: int in 2:
		OB(Vector3(x1 - 0.22, 0.06, 30.1 + k4 * 0.15), Vector3(0.28, 0.12, 0.1), "beam", Vector3(0, 5, 0))
	# the lockers (over YardPropLockers): eleven steel doors, vents and handles, two hanging open, a jacket in one
	B(Vector3(4.7, 0, 31.35), Vector3(9.1, 1.9, wz), "machine_grey")
	for k5: int in 11:
		var lx2: float = 4.7 + k5 * 0.4
		if k5 == 3 or k5 == 8:
			B(Vector3(lx2 + 0.03, 0.08, 31.36), Vector3(lx2 + 0.37, 1.84, 31.4), "black_paint")
			OB(Vector3(lx2 + 0.37, 0.96, 31.15), Vector3(0.03, 1.76, 0.36), "machine_green", Vector3(0, 70, 0))
			if k5 == 3:
				OB(Vector3(lx2 + 0.2, 1.3, 31.5), Vector3(0.28, 0.7, 0.12), "feldgrau")
		else:
			B(Vector3(lx2 + 0.02, 0.05, 31.33), Vector3(lx2 + 0.38, 1.85, 31.35), "machine_green")
			for vy: float in [0.3, 0.38, 1.6, 1.68]:
				B(Vector3(lx2 + 0.1, vy, 31.325), Vector3(lx2 + 0.3, vy + 0.03, 31.33), "black_paint")
		B(Vector3(lx2 + 0.3, 0.95, 31.31), Vector3(lx2 + 0.34, 1.05, 31.33), "steel")
		_label(str(k5 + 1), Vector3(lx2 + 0.2, 1.75, 31.32), 180.0, 12, Color(0.9, 0.88, 0.8, 0.8))
	# the stove (over YardPropStove): a cast-iron drum on its plate, the flue up into the stack, the fire door's glow,
	# the coal scuttle and the poker; its warm light is the one the spawn has before the power
	CYL(Vector3(10.15, 0.04, 30.7), 0.4, 0.08, "iron")
	CYL(Vector3(10.15, 0.68, 30.7), 0.3, 1.0, "iron")
	CYL(Vector3(10.15, 1.21, 30.7), 0.34, 0.06, "iron")
	CYL(Vector3(10.15, 2.5, 30.7), 0.08, 2.6, "iron")
	_noshadow(B(Vector3(10.0, 0.35, 30.385), Vector3(10.3, 0.55, 30.4), "ember"))
	for gy: float in [0.4, 0.47]:
		B(Vector3(10.0, gy, 30.38), Vector3(10.3, gy + 0.015, 30.385), "iron")
	Props.embers(dress, Vector3(10.15, 0.5, 30.3), 0.1, 6)
	lamp(Vector3(10.15, 0.9, 29.9), Color(1.0, 0.5, 0.2), 2.2, 10.0, 0.3, 0.5)
	# (T-239: the stove stands on a brick hearth out from the wall with its coal box behind it, and the scuttle beside the
	# box: YardPropStove now reaches the wall, and the scuttle stood loose in the middle of the floor)
	B(Vector3(9.7, 0.0, 30.25), Vector3(10.6, 0.04, wz), "brick")
	B(Vector3(9.78, 0.04, 31.2), Vector3(10.52, 0.62, wz), "planks")
	for cbx: float in [9.78, 10.47]:
		B(Vector3(cbx, 0.04, 31.18), Vector3(cbx + 0.05, 0.66, 31.24), "beam")
	_noshadow(Props.ball(dress, Vector3(10.15, 0.62, 31.5), Vector3(0.66, 0.2, 0.5), "coal"))
	CYL(Vector3(9.45, 0.2, 31.55), 0.16, 0.4, "iron")
	Props.ball(dress, Vector3(9.45, 0.4, 31.55), Vector3(0.26, 0.1, 0.26), "coal")
	Props.strut(dress, Vector3(10.75, 0.0, 31.8), Vector3(10.9, 1.1, 31.6), 0.02, "iron", true)
	# the miners' tag board: a brass tag on a hook per man; the empty hooks are the men still down there
	B(Vector3(11.0, 1.15, wz - 0.06), Vector3(13.2, 2.3, wz), "planks")
	B(Vector3(10.95, 2.3, wz - 0.1), Vector3(13.25, 2.38, wz), "beam")
	_label("MARKENKONTROLLE", Vector3(12.1, 2.55, wz - 0.02), 180.0, 26, Color(0.85, 0.82, 0.72, 0.85))
	var trng: RandomNumberGenerator = RandomNumberGenerator.new()
	trng.seed = 1938
	for row: int in 4:
		for col: int in 10:
			var tp: Vector3 = Vector3(11.2 + col * 0.2, 2.1 - row * 0.24, wz - 0.06)
			B(tp + Vector3(-0.008, 0.02, -0.04), tp + Vector3(0.008, 0.05, 0.0), "iron")
			if trng.randf() < 0.35:
				continue
			_noshadow(B(tp + Vector3(-0.035, -0.06, -0.035), tp + Vector3(0.035, 0.02, -0.02), "brass"))
	# the lamp rack (over YardPropRack): two shelves of miners' lamps
	for rx2: float in [13.65, 15.25]:
		B(Vector3(rx2 - 0.04, 0, 31.47), Vector3(rx2 + 0.04, 1.9, wz), "beam")
	for sy: float in [0.95, 1.55]:
		B(Vector3(13.6, sy, 31.47), Vector3(15.3, sy + 0.04, wz), "planks")
		for li: int in 6:
			var lx3: float = 13.8 + li * 0.27
			if (li + int(sy * 10.0)) % 4 == 0:
				continue   # a lamp gone with its man
			CYL(Vector3(lx3, sy + 0.14, 31.66), 0.06, 0.2, "brass")
			_noshadow(CYL(Vector3(lx3, sy + 0.27, 31.66), 0.045, 0.06, "lantern_glass"))
	# the clothes baskets on their chains under the rafters: two rows over a bar each; the high ones are still down there
	for row2: Array in [[28.1, 0], [29.9, 1]]:
		var bz2: float = float(row2[0])
		var ry: float = _kaue_roof_y(bz2) - 0.3
		B(Vector3(x0, ry - 0.04, bz2 - 0.04), Vector3(x1, ry + 0.04, bz2 + 0.04), "iron")
		for k6: int in 9:
			var bx3: float = 5.2 + k6 * 1.3
			if absf(bx3 - 10.15) < 0.75 and bz2 > 29.0:
				continue   # the stove's flue
			var high: bool = (k6 + int(row2[1])) % 3 == 0
			var by: float = ry - 0.45 if high else 2.6
			Props.strut(dress, Vector3(bx3, ry, bz2), Vector3(bx3, by, bz2), 0.02, "iron", true)
			CYL(Vector3(bx3, by - 0.15, bz2), 0.21, 0.3, "steel_grate")   # the wire basket
			CYL(Vector3(bx3, by - 0.3, bz2), 0.22, 0.02, "iron")
			CYL(Vector3(bx3, by, bz2), 0.23, 0.02, "iron")
			for a: float in [0.0, 90.0]:
				OB(Vector3(bx3, by - 0.15, bz2), Vector3(0.015, 0.3, 0.015), "iron", Vector3(0, a, 0))
			if high:
				continue
			if k6 % 2 == 0:
				OB(Vector3(bx3 + 0.12, by - 0.45, bz2), Vector3(0.26, 0.4, 0.1), "feldgrau" if k6 % 4 == 0 else "cloth_navy", Vector3(0, 20, 6))
			else:
				OB(Vector3(bx3, by - 0.02, bz2 + 0.05), Vector3(0.12, 0.26, 0.3), "leather", Vector3(0, 30, 0))
	for k7: int in 6:   # the chains' cleats along the west wall
		B(Vector3(x0, 1.55, 27.4 + k7 * 0.6), Vector3(x0 + 0.08, 1.65, 27.5 + k7 * 0.6), "iron")
	# the wash trough on the pier, its taps and pipe; the shift board over it
	B(Vector3(9.1, 0.78, z0), Vector3(10.9, 0.86, z0 + 0.42), "zinc")
	B(Vector3(9.12, 0.8, z0 + 0.02), Vector3(10.88, 0.9, z0 + 0.4), "puddle")
	for lz2: float in [9.2, 10.8]:
		B(Vector3(lz2 - 0.03, 0, z0 + 0.1), Vector3(lz2 + 0.03, 0.78, z0 + 0.16), "iron")
	B(Vector3(9.1, 1.18, z0), Vector3(10.9, 1.22, z0 + 0.04), "iron")
	for tx2: float in [9.5, 10.0, 10.5]:
		CYL(Vector3(tx2, 1.08, z0 + 0.08), 0.02, 0.22, "brass")
		OB(Vector3(tx2, 0.98, z0 + 0.14), Vector3(0.03, 0.03, 0.14), "brass")
	B(Vector3(9.4, 1.6, z0), Vector3(10.6, 2.3, z0 + 0.04), "black_paint")
	B(Vector3(9.36, 1.56, z0), Vector3(10.64, 1.6, z0 + 0.06), "beam")
	B(Vector3(9.36, 2.3, z0), Vector3(10.64, 2.34, z0 + 0.06), "beam")
	_label("SCHICHT III - 23. XII.", Vector3(10.0, 2.1, z0 + 0.05), 0.0, 20, Color(0.9, 0.9, 0.86, 0.85))
	# (T-247: the timetable's small print under the shift board is gone)
	# the broom and the bucket in the north-east corner, a coat on the wall, duckboards along the benches
	Props.strut(dress, Vector3(15.55, 0.02, 26.6), Vector3(15.75, 1.45, 26.35), 0.025, "pine", true)
	OB(Vector3(15.5, 0.03, 26.7), Vector3(0.3, 0.06, 0.1), "straw_floor", Vector3(0, -30, 0))
	CYL(Vector3(15.35, 0.15, 27.0), 0.14, 0.3, "zinc")
	OB(Vector3(x1 - 0.08, 1.5, 28.4), Vector3(0.1, 0.9, 0.42), "cloth_navy", Vector3(0, 0, 0))
	for dxx: Array in [[x0 + 0.5, x0 + 1.3], [x1 - 1.3, x1 - 0.5]]:
		for sz: int in 7:
			B(Vector3(float(dxx[0]), 0.012, 27.3 + sz * 0.5), Vector3(float(dxx[1]), 0.042, 27.42 + sz * 0.5), "planks")
	# light: two hurricane lanterns on the benches, the lantern over the lockers, the two pendants that come on with the yard
	_hurricane(Vector3(x0 + 0.22, 0.45, 27.4), 0.9)
	_hurricane(Vector3(x1 - 0.22, 0.45, 30.7), 0.9)
	Props.wall_lamp(dress, Vector3(7.0, 2.5, wz), 0.0)
	lamp(Vector3(7.0, 2.3, 31.1), Color(1.0, 0.68, 0.38), 1.3, 9.0, 0.08)
	for pxx: float in [7.0, 13.0]:
		pendant("A_MINEHEAD", Vector3(pxx, KAUE_H - 0.95, 29.0), _kaue_roof_y(29.0) - 0.1, "enamel_green")
		power("A_MINEHEAD", Vector3(pxx, KAUE_H - 1.05, 29.0), 8.0, 1.1, INCAND)


## The Kaue's lean-to roof line at z (the eaves at the front wall, KAUE_BACK at the yard wall).
func _kaue_roof_y(z: float) -> float:
	return KAUE_H + (KAUE_BACK - KAUE_H) * clampf((z - (KAUE_Z0 - 0.15)) / (KAUE_ZW - (KAUE_Z0 - 0.15)), 0.0, 1.0)


## A right-triangle wedge along Z (a gable wall's top under a lean-to): base at c.y, rising to c.y + h at the +Z end.
func _wedge_z(c: Vector3, len_z: float, h: float, thick: float, key: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PrismMesh = PrismMesh.new()
	pm.size = Vector3.ONE
	pm.left_to_right = 1.0
	mi.mesh = pm
	mi.material_override = Mats.get_mat(key)
	mi.position = c + Vector3(0, h * 0.5, 0)
	mi.rotation_degrees = Vector3(0, -90, 0)
	mi.scale = Vector3(len_z, h, thick)
	dress.add_child(mi)


func _dress_headframe() -> void:
	var base: Array = [Vector2(15.5, 10.5), Vector2(24.5, 10.5), Vector2(24.5, 19.5), Vector2(15.5, 19.5)]
	var top: Array = [Vector2(17.0, 12.0), Vector2(23.0, 12.0), Vector2(23.0, 18.0), Vector2(17.0, 18.0)]
	var y0: float = 6.0
	var y1: float = 27.0
	var tiers: int = 4
	for i: int in 4:
		var bp: Vector2 = base[i]
		var tp: Vector2 = top[i]
		Props.strut(dress, Vector3(bp.x, y0, bp.y), Vector3(tp.x, y1, tp.y), 0.55, "iron")
		B(Vector3(bp.x - 0.6, y0, bp.y - 0.6), Vector3(bp.x + 0.6, y0 + 0.3, bp.y + 0.6), "concrete")
	for t: int in tiers + 1:
		var f: float = float(t) / float(tiers)
		var y: float = lerpf(y0, y1, f)
		for i2: int in 4:
			var a: Vector2 = (base[i2] as Vector2).lerp(top[i2], f)
			var b: Vector2 = (base[(i2 + 1) % 4] as Vector2).lerp(top[(i2 + 1) % 4], f)
			Props.strut(dress, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), 0.3, "iron")
			if t < tiers:
				var f2: float = float(t + 1) / float(tiers)
				var y2: float = lerpf(y0, y1, f2)
				var a2: Vector2 = (base[i2] as Vector2).lerp(top[i2], f2)
				var b2: Vector2 = (base[(i2 + 1) % 4] as Vector2).lerp(top[(i2 + 1) % 4], f2)
				Props.strut(dress, Vector3(a.x, y, a.y), Vector3(b2.x, y2, b2.y), 0.14, "iron")
				Props.strut(dress, Vector3(b.x, y, b.y), Vector3(a2.x, y2, a2.y), 0.14, "iron")
	# head platform, railing and the two sheave wheels (axles along Z, ropes run east to the engine house)
	B(Vector3(16.4, 27.0, 11.4), Vector3(23.6, 27.4, 18.6), "steel_grate")
	for e: Array in [[Vector3(16.4, 27.4, 11.4), Vector3(23.6, 27.4, 11.4)], [Vector3(23.6, 27.4, 11.4), Vector3(23.6, 27.4, 18.6)],
			[Vector3(23.6, 27.4, 18.6), Vector3(16.4, 27.4, 18.6)], [Vector3(16.4, 27.4, 18.6), Vector3(16.4, 27.4, 11.4)]]:
		Props.strut(dress, (e[0] as Vector3) + Vector3(0, 1.0, 0), (e[1] as Vector3) + Vector3(0, 1.0, 0), 0.06, "iron")
	for wz: float in [13.6, 16.4]:
		var hub: Vector3 = Vector3(20.0, 30.0, wz)
		var r: float = 2.2
		var prev: Vector3 = hub + Vector3(r, 0, 0)
		for k: int in 20:
			var ang: float = TAU * float(k + 1) / 20.0
			var p: Vector3 = hub + Vector3(cos(ang) * r, sin(ang) * r, 0)
			Props.strut(dress, prev, p, 0.2, "iron")
			prev = p
		for k2: int in 6:
			var ang2: float = TAU * float(k2) / 6.0
			Props.strut(dress, hub, hub + Vector3(cos(ang2) * r, sin(ang2) * r, 0), 0.09, "iron")
		CYL(hub, 0.3, 0.5, "iron", Vector3(90, 0, 0))
		for sx: float in [-1.0, 1.0]:
			Props.strut(dress, Vector3(20.0 + sx * 2.4, 27.4, wz), hub, 0.22, "iron")
		# ropes: down the shaft and across to the winding engine
		Props.strut(dress, Vector3(17.8, 30.0, wz), Vector3(17.8, 6.0, wz), 0.05, "iron", true)
		Props.strut(dress, Vector3(21.2, 31.9, wz), Vector3(28.2, 2.6, 6.2 + (wz - 13.6) * 0.5), 0.05, "iron", true)
	# raking back-legs to the engine house roof
	Props.strut(dress, Vector3(23.0, 27.0, 12.4), Vector3(33.6, 3.5, 5.2), 0.45, "iron")
	Props.strut(dress, Vector3(23.0, 27.0, 17.6), Vector3(33.6, 3.5, 8.8), 0.45, "iron")
	Props.strut(dress, Vector3(27.0, 17.6, 9.6), Vector3(27.0, 17.6, 10.4), 0.3, "iron")
	# the shaft collar on top of the tower base: snow, hatch, stencil, a girder for the bell
	_noshadow(B(Vector3(15.05, 6.0, 10.05), Vector3(24.95, 6.08, 19.95), "snow", false))
	B(Vector3(17.2, 6.0, 12.2), Vector3(22.8, 6.5, 17.8), "iron")
	B(Vector3(17.6, 6.5, 12.6), Vector3(22.4, 6.55, 17.4), "black_paint")
	B(Vector3(17.5, 2.0, 20.0), Vector3(22.5, 2.05, 20.05), "yellow_paint")
	_label("SCHACHT II", Vector3(20, 3.6, 20.05), 0.0, 90, Color(0.85, 0.82, 0.72, 0.85))
	B(Vector3(18.6, 0.0, 9.95), Vector3(21.4, 2.4, 10.0), "iron")
	# floodlights on the frame (powered)
	flood("A_MINEHEAD", Vector3(20.0, 22.0, 18.6), Vector3(17.0, 0.0, 28.0), 38.0, 3.2, 26.0)
	flood("A_MINEHEAD", Vector3(20.0, 22.0, 11.4), Vector3(22.0, 0.0, 2.0), 34.0, 2.6, 26.0)
	flood("A_MINEHEAD", Vector3(4.0, 4.6, 0.45), Vector3(10.0, 0.0, 14.0), 22.0, 3.0, 45.0)
	flood("A_MINEHEAD", Vector3(36.0, 4.6, 0.45), Vector3(31.0, 0.0, 16.0), 22.0, 3.0, 45.0)
	for fp: Vector3 in [Vector3(4.0, 4.12, 0.3), Vector3(36.0, 4.12, 0.3)]:
		Props.strut(dress, fp, fp + Vector3(0, 0.45, 0.1), 0.08, "iron")


func _dress_admin() -> void:
	# exterior: cornice between the floors, eaves, gable roof and chimneys
	B(Vector3(-16.45, 3.45, 7.55), Vector3(0.45, 3.85, 7.85), "stucco_trim")
	B(Vector3(0.15, 3.45, 7.55), Vector3(0.45, 3.85, 32.0), "stucco_trim")
	B(Vector3(-16.45, 3.45, 7.55), Vector3(-16.15, 3.85, 32.0), "stucco_trim")
	B(Vector3(-16.5, 6.9, 7.5), Vector3(0.5, 7.3, 32.5), "stucco_trim")
	Props.gable_roof(dress, Vector3(-16.8, 7.3, 7.2), Vector3(0.8, 7.3, 32.8), 3.2, false)
	for cp: Vector3 in [Vector3(-12.5, 7.3, 12.0), Vector3(-3.5, 7.3, 27.0)]:
		B(cp + Vector3(-0.45, 0, -0.45), cp + Vector3(0.45, 3.8, 0.45), "brick")
		B(cp + Vector3(-0.55, 3.8, -0.55), cp + Vector3(0.55, 4.0, 0.55), "concrete")
	Props.smoke(dress, Vector3(-12.5, 11.4, 12.0), 0.2, 0.7, 14)
	# fake windows that give the facade its rhythm (exterior face only): [pos on the face, yaw facing out]
	var fakes: Array = [
		[Vector3(-13, 0, 7.85), 180.0], [Vector3(-3, 0, 7.85), 180.0], [Vector3(-13, 3.8, 7.85), 180.0], [Vector3(-3, 3.8, 7.85), 180.0],
		[Vector3(0.15, 0, 12.0), 90.0], [Vector3(0.15, 0, 18.0), 90.0], [Vector3(0.15, 3.8, 20.0), 90.0], [Vector3(0.15, 3.8, 26.0), 90.0],
		[Vector3(-16.15, 0, 14.0), -90.0], [Vector3(-16.15, 0, 22.0), -90.0], [Vector3(-16.15, 3.8, 14.0), -90.0], [Vector3(-16.15, 3.8, 24.0), -90.0],
	]
	var fi: int = 0
	for f: Array in fakes:
		var g: Node3D = Props.group(dress, "FakeWindow", f[0], float(f[1]))   # local +Z = outward
		var pane: MeshInstance3D = Props.block(g, Vector3(-0.8, SILL, 0.0), Vector3(0.8, WTOP, 0.02), "window_dark")
		# the rooms with an oil lamp burning show it at the glass (night lamp, upstairs lantern, the filing room)
		if fi in [0, 5, 7] and pane != null:
			pane.material_override = _lit_window()
			_noshadow(pane)
		fi += 1
		Props.block(g, Vector3(-0.04, SILL, 0.0), Vector3(0.04, WTOP, 0.05), "beam")
		Props.block(g, Vector3(-0.8, (SILL + WTOP) * 0.5 - 0.03, 0.0), Vector3(0.8, (SILL + WTOP) * 0.5 + 0.03, 0.05), "beam")
		_admin_surround(g, true)
	# door canopy and sign on the yard side
	B(Vector3(0.15, 2.65, 23.4), Vector3(1.3, 2.8, 26.6), "roof")
	_noshadow(B(Vector3(0.2, 2.8, 23.45), Vector3(1.28, 2.86, 26.55), "snow", false))
	for bz: float in [23.6, 26.4]:
		Props.strut(dress, Vector3(0.15, 2.0, bz), Vector3(1.2, 2.66, bz), 0.07, "iron")
	_label("VERWALTUNG", Vector3(0.18, 3.1, 25.0), 90.0, 40)
	Props.wall_lamp(dress, Vector3(0.17, 2.3, 23.2), -90.0)
	lamp(Vector3(0.9, 2.2, 23.2), Color(1.0, 0.68, 0.38), 0.9, 8.0, 0.1)
	# balcony brackets and railing; the north canopy's brackets
	for bz2: float in [12.3, 14.0, 15.7]:
		Props.strut(dress, Vector3(0.15, 2.7, bz2), Vector3(2.4, 3.5, bz2), 0.12, "beam")
	for e: Array in [[Vector3(2.5, 3.8, 12.05), Vector3(2.5, 3.8, 15.95)], [Vector3(0.2, 3.8, 12.05), Vector3(2.5, 3.8, 12.05)],
			[Vector3(0.2, 3.8, 15.95), Vector3(2.5, 3.8, 15.95)]]:
		Props.strut(dress, (e[0] as Vector3) + Vector3(0, 0.95, 0), (e[1] as Vector3) + Vector3(0, 0.95, 0), 0.05, "iron")
		var n: int = int((e[0] as Vector3).distance_to(e[1]) / 0.5)
		for k: int in n + 1:
			var p: Vector3 = (e[0] as Vector3).lerp(e[1], float(k) / float(maxi(1, n)))
			B(p + Vector3(-0.015, 0, -0.015), p + Vector3(0.015, 0.95, 0.015), "iron")
	_noshadow(B(Vector3(0.2, 3.8, 12.05), Vector3(2.55, 3.86, 15.95), "snow", false))
	for bx: float in [-9.6, -6.4]:
		Props.strut(dress, Vector3(bx, 2.8, 7.85), Vector3(bx, 3.5, 5.7), 0.1, "beam")
	_noshadow(B(Vector3(-9.95, 3.8, 5.55), Vector3(-6.05, 3.87, 7.8), "snow", false))
	# ground floor: ceiling beams, filing cabinets, desks, the safe, maps
	for bz3: float in [10.5, 13.5, 16.5, 19.5, 23.0, 26.0, 29.5]:
		var x0: float = -12.0 if (bz3 > 21.0 and bz3 < 28.0) else -15.85
		B(Vector3(x0, 3.28, bz3 - 0.12), Vector3(-0.15, 3.5, bz3 + 0.12), "beam")
		B(Vector3(-15.85, 6.78, bz3 - 0.1), Vector3(-0.15, 7.0, bz3 + 0.1), "beam")
	B(Vector3(-1.62, 6.65, 8.15), Vector3(-1.38, 7.0, 15.85), "beam")   # rafter for the balcony bell
	for fz: Array in [[9.0, 10.45]]:   # (T-226: the second cabinet, z 10.55..12, was drawn through Ledger Lager's register)
		B(Vector3(-15.6, 0, float(fz[0])), Vector3(-14.3, 1.6, float(fz[1])), "machine_grey")
		for k2: int in 4:
			var dy: float = 0.15 + k2 * 0.38
			B(Vector3(-14.3, dy, float(fz[0]) + 0.08), Vector3(-14.27, dy + 0.32, float(fz[1]) - 0.08), "machine_green")
			B(Vector3(-14.27, dy + 0.2, (float(fz[0]) + float(fz[1])) * 0.5 - 0.1), Vector3(-14.24, dy + 0.23, (float(fz[0]) + float(fz[1])) * 0.5 + 0.1), "brass")
	# (T-239: the clerks' desks stand against the walls with their chairs pushed in (Prop_C_Desk*): one under the map on the
	# north wall, two along the east wall under the windows. They stood loose in the middle of the lobby, one of them in
	# front of the Bergmannskasse's counter, and nobody collided with any of them. The safe is in the corner.)
	for dp: Array in [[Vector3(-4.0, 0, 8.62), 0.0], [Vector3(-0.62, 0, 12.6), -90.0], [Vector3(-0.62, 0, 18.0), -90.0]]:
		_desk(dp[0], float(dp[1]), 1.5, 0.52)
	B(Vector3(-1.3, 0, 8.2), Vector3(-0.2, 1.1, 9.2), "iron")
	Props.gauge(dress, Vector3(-0.75, 0.75, 9.22), 180.0, 0.1)
	_dress_admin_stair_strings()
	Props.picture(dress, Vector3(-3.0, 2.1, 8.2), 180.0, 2.4, 1.4)
	Props.picture(dress, Vector3(-15.8, 2.2, 18.5), -90.0, 1.0, 0.8)
	Props.coat_rack(dress, Vector3(-0.45, 0, 21.4))
	Props.gauge(dress, Vector3(-0.2, 2.6, 19.5), 90.0, 0.2)
	_label("AMT KALTENBRUNN", Vector3(-3.5, 2.75, 29.45), 180.0, 26, Color(0.9, 0.8, 0.55, 0.85))
	for k3: int in 5:
		B(Vector3(-5.8 + k3 * 1.0, 0.9, 29.45), Vector3(-5.0 + k3 * 1.0, 1.95, 29.48), "black_paint")
	# upper floor: the radio room (north) and Reinholt's office (south)
	B(Vector3(-15.3, 4.6, 11.0), Vector3(-14.3, 5.1, 11.9), "machine_grey")
	Props.gauge(dress, Vector3(-14.8, 4.85, 10.98), 0.0, 0.07)
	Props.gauge(dress, Vector3(-14.55, 4.85, 10.98), 0.0, 0.05)
	B(Vector3(-15.9, 4.6, 9.2), Vector3(-15.6, 5.6, 9.8), "machine_green")
	Props.picture(dress, Vector3(-9.0, 5.6, 8.2), 180.0, 2.0, 1.2)
	Props.chair(dress, Vector3(-13.7, 3.8, 10.5), 90.0)
	_desk(Vector3(-6.0, 3.8, 26.0), 0.0, 2.0, 0.54)   # (T-239: one chair, pushed in; a second stood behind it facing the wall)
	_dress_admin_upper()
	B(Vector3(-11.0, 3.81, 22.0), Vector3(-3.0, 3.825, 29.0), "rug")
	B(Vector3(-15.85, 3.8, 22.0), Vector3(-15.45, 5.9, 26.0), "furniture")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for shelf: int in 4:
		var sy: float = 4.0 + shelf * 0.5
		B(Vector3(-15.85, sy - 0.03, 22.0), Vector3(-15.45, sy, 26.0), "beam")
		var z: float = 22.1
		while z < 25.8:
			var bw: float = rng.randf_range(0.05, 0.1)
			var key: String = ["cloth_red", "cloth_green", "linen", "furniture"][rng.randi() % 4]
			B(Vector3(-15.8, sy, z), Vector3(-15.5, sy + rng.randf_range(0.3, 0.42), z + bw), key)
			z += bw + 0.01
	Props.picture(dress, Vector3(-0.2, 5.5, 24.0), 90.0, 1.2, 0.9)
	# lamps (powered) + the old emergency lantern
	pendant("C_ADMIN", Vector3(-8, 2.95, 13.0), 3.28, "enamel_white")
	pendant("C_ADMIN", Vector3(-8, 2.95, 24.0), 3.28, "enamel_white")
	pendant("C_ADMIN", Vector3(-8, 6.45, 12.0), 6.78, "enamel_white")
	pendant("C_ADMIN", Vector3(-8, 6.45, 24.0), 6.78, "enamel_white")
	power("C_ADMIN", Vector3(-8, 2.8, 13.0), 10.0, 1.4, INCAND)
	power("C_ADMIN", Vector3(-8, 2.8, 24.0), 10.0, 1.4, INCAND)
	power("C_ADMIN", Vector3(-8, 6.3, 12.0), 9.0, 1.5, INCAND)
	power("C_ADMIN", Vector3(-8, 6.3, 24.0), 10.0, 1.5, INCAND)
	# a green banker's lamp on the upstairs desk (comes on with the Admin sweep)
	CYL(Vector3(-6.75, 4.6, 25.85), 0.07, 0.03, "brass")
	CYL(Vector3(-6.75, 4.75, 25.85), 0.012, 0.3, "brass")
	Props.cone(dress, Vector3(-6.75, 4.92, 25.85), 0.14, 0.1, "enamel_green")
	_noshadow(Props.ball(dress, Vector3(-6.75, 4.86, 25.85), Vector3(0.07, 0.05, 0.07), "bulb_off"))
	_noshadow(Props.ball(G("C_ADMIN"), Vector3(-6.75, 4.86, 25.85), Vector3(0.08, 0.06, 0.08), "bulb_warm"))
	power("C_ADMIN", Vector3(-6.75, 4.75, 25.75), 6.0, 0.9, INCAND, false, {}, 0.3)
	Props.lantern(dress, Vector3(-8.0, 2.6, 18.0), 3.28)
	lamp(Vector3(-8.0, 2.45, 18.0), Color(1.0, 0.7, 0.4), 1.1, 9.0, 0.08)
	_hurricane(Vector3(-14.95, 1.6, 10.5), 1.0)
	Props.wall_lamp(dress, Vector3(-15.8, 2.3, 18.5), -90.0)
	lamp(Vector3(-15.1, 2.2, 18.5), Color(1.0, 0.68, 0.38), 0.9, 8.0, 0.1)
	Props.wall_lamp(dress, Vector3(-11.4, 2.3, 31.8), 0.0)
	lamp(Vector3(-11.4, 2.2, 31.1), Color(1.0, 0.68, 0.38), 0.9, 8.0, 0.1)
	Props.wall_lamp(dress, Vector3(-0.2, 2.3, 21.6), 90.0)   # (T-239: the lobby's east side by the yard door was unlit)
	lamp(Vector3(-0.9, 2.2, 21.6), Color(1.0, 0.68, 0.38), 0.9, 8.0, 0.1)
	Props.lantern(dress, Vector3(-4.0, 6.1, 28.0), 6.78)
	lamp(Vector3(-4.0, 5.95, 28.0), Color(1.0, 0.7, 0.4), 1.1, 9.0, 0.08)


## T-239: the Administration stairs' closed strings (AdminStairStringE / W, T-107's colliders: 3.5 m slabs the height of the
## room, drawn until now as two bare dark boards 7 m long: the big black block in the middle of the lobby). They are the
## walls of a boxed staircase: plaster over a wainscot like the room's own walls, a skirting and a chair rail, a timber
## post at each end, and the opening's head trimmed at the stair foot.
func _dress_admin_stair_strings() -> void:
	for sx: Array in [[-12.25, -12.05], [-15.35, -15.15]]:
		var xa: float = float(sx[0])
		var xb: float = float(sx[1])
		for f: Array in [[xa, -1.0], [xb, 1.0]]:
			var fx: float = float(f[0])
			var o: float = float(f[1])
			B(Vector3(minf(fx, fx + o * 0.012), 0.0, 21.0), Vector3(maxf(fx, fx + o * 0.012), 3.5, 28.3), "plaster")
			B(Vector3(minf(fx, fx + o * 0.03), 0.0, 21.0), Vector3(maxf(fx, fx + o * 0.03), 1.1, 28.3), "wainscot")
			B(Vector3(minf(fx, fx + o * 0.045), 1.1, 21.0), Vector3(maxf(fx, fx + o * 0.045), 1.16, 28.3), "beam")
			B(Vector3(minf(fx, fx + o * 0.04), 0.0, 21.0), Vector3(maxf(fx, fx + o * 0.04), 0.12, 28.3), "beam")
		for pz: Array in [[28.22, 28.42], [20.95, 21.1]]:
			B(Vector3(xa - 0.05, 0.0, float(pz[0])), Vector3(xb + 0.05, 3.5, float(pz[1])), "beam")
	B(Vector3(-15.4, 3.3, 28.22), Vector3(-12.0, 3.5, 28.42), "beam")   # the head of the stair's opening at its foot
	# T-239 follow-up: the lobby face of the east wall was 7 x 2 m of bare plaster. What a mine office hangs by its stairs
	# (drawn only, at most 8 cm off the face): the shift board with a brass tally per man on its hook, the wall clock, the
	# framed plan of the workings, the notice board with its pinned papers, and a lantern over the shift board.
	var fx: float = -12.038
	B(Vector3(fx, 1.45, 21.6), Vector3(fx + 0.03, 2.8, 24.0), "planks")
	for fr: Array in [[1.41, 1.45], [2.8, 2.84], [2.5, 2.53]]:
		B(Vector3(fx, float(fr[0]), 21.56), Vector3(fx + 0.045, float(fr[1]), 24.04), "beam")
	for fz: float in [21.56, 24.0]:
		B(Vector3(fx, 1.41, fz), Vector3(fx + 0.045, 2.84, fz + 0.04), "beam")
	_label("SCHICHTTAFEL", Vector3(fx + 0.05, 2.66, 22.8), 90.0, 26, Color(0.9, 0.86, 0.74, 0.9))
	for ci: int in 3:
		_label(["FRÜH", "MITTAG", "NACHT"][ci], Vector3(fx + 0.05, 2.42, 22.0 + ci * 0.8), 90.0, 14, Color(0.9, 0.86, 0.74, 0.8))
	var srng: RandomNumberGenerator = RandomNumberGenerator.new()
	srng.seed = 1944
	for col: int in 12:
		for row: int in 5:
			var hp: Vector3 = Vector3(fx + 0.03, 2.28 - row * 0.17, 21.78 + col * 0.19 + (0.06 if col >= 4 else 0.0) + (0.06 if col >= 8 else 0.0))
			B(hp + Vector3(0, 0.0, -0.006), hp + Vector3(0.03, 0.02, 0.006), "iron")
			if srng.randf() < (0.25 if col >= 8 else 0.7):   # the night shift's hooks are mostly bare: they went down
				_noshadow(B(hp + Vector3(0.012, -0.075, -0.03), hp + Vector3(0.022, 0.0, 0.03), "brass"))
	Props.wall_lamp(dress, Vector3(-12.03, 3.05, 22.8), -90.0)
	lamp(Vector3(-11.4, 2.9, 22.8), Color(1.0, 0.68, 0.38), 0.8, 6.0, 0.1)
	# the clock (stopped) over the plan
	CYL(Vector3(fx + 0.04, 2.95, 25.3), 0.2, 0.07, "furniture", Vector3(0, 0, 90))
	_noshadow(CYL(Vector3(fx + 0.078, 2.95, 25.3), 0.17, 0.006, "paper", Vector3(0, 0, 90)))
	_noshadow(OB(Vector3(fx + 0.085, 3.0, 25.3), Vector3(0.004, 0.11, 0.012), "black_paint"))
	_noshadow(OB(Vector3(fx + 0.085, 2.96, 25.345), Vector3(0.004, 0.012, 0.1), "black_paint", Vector3(20, 0, 0)))
	# the plan of the workings: a frame, the sheet, the levels and the shafts inked on it
	B(Vector3(fx, 1.55, 24.45), Vector3(fx + 0.04, 2.6, 26.15), "furniture")
	_noshadow(B(Vector3(fx + 0.04, 1.62, 24.52), Vector3(fx + 0.046, 2.53, 26.08), "paper", false))
	for lv: int in 3:
		_noshadow(B(Vector3(fx + 0.046, 2.3 - lv * 0.25, 24.65), Vector3(fx + 0.049, 2.312 - lv * 0.25, 25.95 - lv * 0.2), "black_paint", false))
	for sh: float in [24.9, 25.55]:
		_noshadow(B(Vector3(fx + 0.046, 1.8, sh), Vector3(fx + 0.049, 2.45, sh + 0.012), "black_paint", false))
	_noshadow(B(Vector3(fx + 0.046, 1.78, 25.2), Vector3(fx + 0.049, 1.9, 25.5), "red_paint", false))
	# (T-247: the mine plan's 12 px caption is gone)
	# the notice board: orders, the ration list, a torn poster
	B(Vector3(fx, 1.5, 26.6), Vector3(fx + 0.03, 2.55, 27.9), "linen")
	for nf: Array in [[1.46, 1.5], [2.55, 2.59]]:
		B(Vector3(fx, float(nf[0]), 26.56), Vector3(fx + 0.045, float(nf[1]), 27.94), "beam")
	for nz: float in [26.56, 27.9]:
		B(Vector3(fx, 1.46, nz), Vector3(fx + 0.045, 2.59, nz + 0.04), "beam")
	for np: Array in [[26.72, 2.2, 0.26, 0.3, 4.0], [27.05, 2.25, 0.22, 0.28, -3.0], [27.4, 2.15, 0.3, 0.4, 2.0], [26.8, 1.8, 0.3, 0.22, -5.0],
			[27.2, 1.78, 0.2, 0.26, 6.0], [27.62, 1.72, 0.2, 0.3, -2.0]]:
		_noshadow(Props.obox(dress, Vector3(fx + 0.034, float(np[1]), float(np[0]) + float(np[2]) * 0.5), Vector3(0.004, float(np[3]), float(np[2])),
			"paper", Vector3(float(np[4]), 0, 0)))
	# (T-247: the notice board's 12 px heading is gone; the sheets on it stay)


## T-239: the Administration's upper floor was a 16 x 16 m room with one desk on a rug, and the radio room an empty
## floor with a table in a corner. Reinholt's office gets what an office has, all of it against the walls (Prop_C_*
## colliders): a row of filing cabinets on the south wall, the plan table under the picture on the east wall with the
## mine's sections rolled on it, a waiting bench against the partition; Fasbender's radio room gets the cot he slept on
## (MAPS.md: "his cot, his ashtray, and a half-written letter") and the lantern he wrote by, which is also the room's
## light before the power (the room and the balcony window beside it were black).
func _dress_admin_upper() -> void:
	var y: float = 3.8
	for k: int in 3:   # the filing cabinets (as the ground floor's)
		var x0: float = -9.5 + k * 1.0
		B(Vector3(x0 + 0.02, y, 31.25), Vector3(x0 + 0.98, y + 1.5, 31.85), "machine_grey")
		for dr: int in 4:
			var dy: float = y + 0.1 + dr * 0.35
			B(Vector3(x0 + 0.08, dy, 31.22), Vector3(x0 + 0.92, dy + 0.3, 31.25), "machine_green")
			B(Vector3(x0 + 0.4, dy + 0.18, 31.19), Vector3(x0 + 0.6, dy + 0.21, 31.22), "brass")
	B(Vector3(-9.3, y + 1.5, 31.4), Vector3(-8.7, y + 1.52, 31.8), "paper")
	# the plan table: a heavy top on two trestle ends, a drawer rail, rolled sections and an open one held by a rule
	B(Vector3(-1.55, y + 0.82, 21.6), Vector3(-0.15, y + 0.9, 24.4), "furniture")
	for tz: float in [21.75, 24.25]:
		B(Vector3(-1.45, y, tz - 0.06), Vector3(-0.25, y + 0.82, tz + 0.06), "furniture")
	B(Vector3(-1.5, y + 0.62, 21.8), Vector3(-1.46, y + 0.8, 24.2), "furniture")
	B(Vector3(-1.4, y + 0.9, 22.3), Vector3(-0.35, y + 0.905, 23.7), "paper")
	B(Vector3(-1.3, y + 0.905, 22.35), Vector3(-1.24, y + 0.925, 23.65), "brass")
	for rk: int in 4:
		CYL(Vector3(-0.42 - rk * 0.07, y + 0.94, 23.9 - rk * 0.03), 0.035, 0.9, "paper", Vector3(0, 90, 90))
	# the waiting bench against the partition
	B(Vector3(-7.5, y + 0.4, 16.17), Vector3(-3.5, y + 0.45, 16.6), "furniture")
	B(Vector3(-7.5, y + 0.45, 16.16), Vector3(-3.5, y + 0.95, 16.2), "furniture")
	for bx: float in [-7.4, -5.5, -3.6]:
		B(Vector3(bx - 0.04, y, 16.2), Vector3(bx + 0.04, y + 0.4, 16.58), "furniture")
	# Fasbender's cot under the north wall, east of the window; his lantern on the radio desk
	B(Vector3(-6.1, y + 0.28, 8.2), Vector3(-4.0, y + 0.33, 9.1), "iron")
	for cl: Vector2 in [Vector2(-6.07, 8.23), Vector2(-4.03, 8.23), Vector2(-6.07, 9.07), Vector2(-4.03, 9.07)]:
		B(Vector3(cl.x - 0.025, y, cl.y - 0.025), Vector3(cl.x + 0.025, y + 0.5, cl.y + 0.025), "iron")
	B(Vector3(-6.05, y + 0.33, 8.24), Vector3(-4.05, y + 0.43, 9.06), "linen")
	B(Vector3(-5.5, y + 0.43, 8.23), Vector3(-4.04, y + 0.48, 9.07), "feldgrau")
	B(Vector3(-6.02, y + 0.43, 8.35), Vector3(-5.6, y + 0.52, 8.95), "linen")
	_hurricane(Vector3(-13.3, y + 0.8, 9.7), 1.2)


func _desk(p: Vector3, yaw: float, w: float = 1.5, chair_z: float = 0.7) -> void:
	var g: Node3D = Props.group(dress, "Desk", p, yaw)
	Props.block(g, Vector3(-w * 0.5, 0.72, -0.4), Vector3(w * 0.5, 0.78, 0.4), "furniture")
	Props.block(g, Vector3(-w * 0.5, 0, -0.38), Vector3(-w * 0.5 + 0.45, 0.72, 0.38), "furniture")
	Props.block(g, Vector3(w * 0.5 - 0.06, 0, -0.38), Vector3(w * 0.5, 0.72, 0.38), "furniture")
	Props.block(g, Vector3(-0.25, 0.78, -0.25), Vector3(0.2, 0.92, 0.05), "black_paint")
	Props.block(g, Vector3(0.3, 0.78, -0.2), Vector3(0.6, 0.79, 0.2), "paper")
	Props.block(g, Vector3(-0.6, 0.78, 0.05), Vector3(-0.35, 0.8, 0.3), "paper")
	Props.chair(g, Vector3(0, 0, chair_z), 0.0)


## Stucco surround, sill and green shutters for an admin window (local +Z = outward when `outward`).
func _admin_surround(g: Node3D, outward: bool) -> void:
	var s: float = 1.0 if outward else -1.0
	var f: float = 0.0
	Props.block(g, Vector3(-0.98, SILL - 0.12, f), Vector3(0.98, SILL, f + s * 0.16), "stucco_trim")
	Props.block(g, Vector3(-0.98, WTOP, f), Vector3(0.98, WTOP + 0.22, f + s * 0.08), "stucco_trim")
	for sx: float in [-1.0, 1.0]:
		Props.block(g, Vector3(sx * 0.8 - 0.09, SILL, f), Vector3(sx * 0.8 + 0.09, WTOP, f + s * 0.06), "stucco_trim")
		var sh: Node3D = Props.group(g, "Shutter", Vector3(sx * 0.98, SILL, f + s * 0.03), 0.0)
		sh.rotation.y = deg_to_rad(sx * s * -15.0)
		Props.block(sh, Vector3(minf(0.0, sx * 0.78), 0, -0.025), Vector3(maxf(0.0, sx * 0.78), WTOP - SILL, 0.025), "shutter_green")
	var cap: MeshInstance3D = Props.block(g, Vector3(-0.92, SILL, f + s * 0.02), Vector3(0.92, SILL + 0.07, f + s * 0.15), "snow", false)
	_noshadow(cap)


func _dress_barracks() -> void:
	# roof: a gable over the hut (east of the Admin Block) and a lean-to against the Admin Block
	Props.gable_roof(dress, Vector3(0.15, 4.3, 31.5), Vector3(40.6, 4.3, 46.5), 2.2, true)
	var lean: MeshInstance3D = OB(Vector3(-8.2, 4.95, 39.2), Vector3(16.8, 0.25, 14.6), "roof", Vector3(5.1, 0, 0))
	lean.name = "LeanTo"
	_noshadow(OB(Vector3(-8.2, 5.1, 39.2), Vector3(16.6, 0.08, 14.4), "snow", Vector3(5.1, 0, 0)))
	B(Vector3(-16.4, 4.0, 45.85), Vector3(0.15, 4.4, 46.4), "beam")
	B(Vector3(-16.4, 4.0, 31.6), Vector3(-16.15, 4.3, 46.4), "beam")
	# exterior corner posts / sill beam of the timber hut
	for cx: float in [-16.15, 40.15]:
		for cz: float in [31.85, 46.15]:
			B(Vector3(cx - 0.15, 0, cz - 0.15), Vector3(cx + 0.15, 4.0, cz + 0.15), "beam")
	B(Vector3(0.15, 0, 31.8), Vector3(40.2, 0.35, 31.85), "beam")
	_label("UNTERKUNFT  ·  KANTINE", Vector3(20.0, 3.3, 31.83), 180.0, 40)
	# ceiling beams, posts
	for bx: float in [-12.0, -4.0, 4.0, 12.0, 20.0, 28.0, 36.0]:
		B(Vector3(bx - 0.12, 3.75, 32.15), Vector3(bx + 0.12, 4.0, 45.85), "beam")
	for bz: float in [35.5, 42.0]:
		B(Vector3(-15.85, 3.62, bz - 0.12), Vector3(39.85, 3.95, bz + 0.12), "beam")
	# bunks: two-tier timber frames on the bunk colliders (the upper mattress top is the collider top, 1.8)
	for bx2: float in [-11.5, -6.0, -0.5, 4.0]:
		for c: Vector2 in [Vector2(bx2 + 0.05, 40.05), Vector2(bx2 + 1.95, 40.05), Vector2(bx2 + 0.05, 43.95), Vector2(bx2 + 1.95, 43.95)]:
			B(Vector3(c.x - 0.05, 0, c.y - 0.05), Vector3(c.x + 0.05, 1.95, c.y + 0.05), "pine")
		for ty: float in [0.3, 1.45]:
			B(Vector3(bx2, ty, 40.0), Vector3(bx2 + 2.0, ty + 0.1, 44.0), "pine")
			B(Vector3(bx2 + 0.1, ty + 0.1, 40.1), Vector3(bx2 + 1.9, ty + 0.3, 43.9), "linen")
			B(Vector3(bx2 + 0.08, ty + 0.3, 41.2), Vector3(bx2 + 1.92, ty + 0.35, 43.92), "cloth_green")
			B(Vector3(bx2 + 0.3, ty + 0.3, 40.2), Vector3(bx2 + 1.7, ty + 0.4, 40.75), "linen")
		# (T-239: two foot lockers a bunk, one a man, the bunk's own width (Prop_D_FootLockers): one narrow trunk stood
		# at each bunk's foot with nothing to collide with)
		Props.trunk(dress, Vector3(bx2 + 0.04, 0, 39.34), Vector3(bx2 + 0.97, 0.48, 39.98))
		Props.trunk(dress, Vector3(bx2 + 1.03, 0, 39.34), Vector3(bx2 + 1.96, 0.48, 39.98))
	# lockers along the north wall, a quartermaster's shelf in the NW corner
	for lx: int in 6:
		var x: float = 0.6 + lx * 1.0
		B(Vector3(x, 0, 32.17), Vector3(x + 0.95, 1.9, 32.65), "machine_green")
		for vy: float in [1.5, 1.6, 1.7]:
			B(Vector3(x + 0.3, vy, 32.65), Vector3(x + 0.65, vy + 0.03, 32.67), "black_paint")
	B(Vector3(-15.85, 0, 34.5), Vector3(-15.35, 2.2, 37.5), "pine")
	for sy: float in [0.6, 1.2, 1.8]:
		B(Vector3(-15.85, sy, 34.5), Vector3(-15.3, sy + 0.05, 37.5), "planks")
		Props.crate(dress, Vector3(-15.55, sy + 0.05, 35.2 + sy), 0.4, 10.0)
	# stove (always burning), its flue, a coal scuttle
	CYL(Vector3(-15.0, 0.45, 45.0), 0.38, 0.9, "loco_black")
	CYL(Vector3(-15.0, 0.95, 45.0), 0.42, 0.1, "iron")
	_noshadow(B(Vector3(-14.7, 0.25, 44.85), Vector3(-14.6, 0.45, 45.15), "ember", false))
	CYL(Vector3(-15.0, 2.5, 45.0), 0.09, 3.0, "iron")
	lamp(Vector3(-14.3, 0.6, 45.0), Color(1.0, 0.45, 0.15), 2.0, 9.0, 0.3)
	# (T-239: the stove stands on a sheet-iron plate in its corner with the coal in a box between it and the wall)
	B(Vector3(-15.85, 0.0, 44.5), Vector3(-14.55, 0.02, 45.85), "iron")
	B(Vector3(-15.83, 0.02, 44.52), Vector3(-15.5, 0.5, 45.0), "planks")
	_noshadow(Props.ball(dress, Vector3(-15.66, 0.5, 44.76), Vector3(0.3, 0.14, 0.42), "coal"))
	# mess: trestle tables, benches, crockery; the serving line
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	for i: int in 3:
		var x0: float = 12.0 + i * 8.0
		B(Vector3(x0, 0.72, 37.0), Vector3(x0 + 5.0, 0.8, 38.5), "planks")
		for lx2: float in [x0 + 0.4, x0 + 4.6]:
			B(Vector3(lx2 - 0.05, 0, 37.2), Vector3(lx2 + 0.05, 0.72, 38.3), "pine")
		for bz2: float in [36.35, 39.15]:
			B(Vector3(x0 + 0.2, 0.42, bz2 - 0.15), Vector3(x0 + 4.8, 0.47, bz2 + 0.15), "planks")
			for lx3: float in [x0 + 0.5, x0 + 4.5]:
				B(Vector3(lx3 - 0.04, 0, bz2 - 0.12), Vector3(lx3 + 0.04, 0.42, bz2 + 0.12), "pine")
		for k: int in 6:
			var mp: Vector3 = Vector3(x0 + 0.5 + rng.randf() * 4.0, 0.8, 37.2 + rng.randf() * 1.1)
			CYL(mp + Vector3(0, 0.06, 0), 0.05, 0.12, "stein" if k % 2 == 0 else "iron")
	B(Vector3(30, 0, 44.6), Vector3(38, 0.95, 45.6), "planks")
	B(Vector3(29.95, 0.95, 44.55), Vector3(38.05, 1.0, 45.65), "steel")
	for kx: float in [31.0, 33.0, 34.8]:
		CYL(Vector3(kx, 1.25, 45.1), 0.32, 0.5, "steel")
		CYL(Vector3(kx, 1.52, 45.1), 0.34, 0.04, "iron")
	B(Vector3(30, 1.7, 45.55), Vector3(38, 1.74, 45.85), "planks")
	for tx: int in 14:
		CYL(Vector3(30.3 + tx * 0.55, 1.84, 45.7), 0.07, 0.2, "brass" if tx % 3 == 0 else "iron")
	# lights: wagon-wheel chandelier over the mess, pendants elsewhere
	var hub: Vector3 = Vector3(24.0, 3.75, 39.0)
	var prev: Vector3 = hub + Vector3(0.9, 0, 0)
	for k2: int in 16:
		var ang: float = TAU * float(k2 + 1) / 16.0
		var p: Vector3 = hub + Vector3(cos(ang) * 0.9, 0, sin(ang) * 0.9)
		Props.strut(dress, prev, p, 0.07, "beam")
		prev = p
	for k3: int in 6:
		var a3: float = TAU * float(k3) / 6.0
		var bp: Vector3 = hub + Vector3(cos(a3) * 0.9, 0.08, sin(a3) * 0.9)
		Props.strut(dress, hub, bp - Vector3(0, 0.08, 0), 0.05, "beam")
		_noshadow(Props.ball(dress, bp, Vector3(0.09, 0.11, 0.09), "bulb_off"))
		_noshadow(Props.ball(G("D_BARRACKS"), bp, Vector3(0.11, 0.13, 0.11), "bulb_warm"))
	B(Vector3(23.9, 3.7, 38.9), Vector3(24.1, 4.0, 39.1), "iron")
	for pp: Vector3 in [Vector3(-12.0, 3.3, 37.0), Vector3(-4.0, 3.3, 37.0), Vector3(2.0, 3.3, 37.0), Vector3(14.0, 3.3, 41.0), Vector3(34.0, 3.3, 41.0)]:
		pendant("D_BARRACKS", pp, 4.0)
	power("D_BARRACKS", Vector3(-8.0, 3.1, 37.0), 11.0, 1.3, INCAND)
	power("D_BARRACKS", Vector3(2.0, 3.1, 37.0), 11.0, 1.3, INCAND)
	power("D_BARRACKS", Vector3(24.0, 3.4, 39.0), 14.0, 1.5, INCAND)
	power("D_BARRACKS", Vector3(34.0, 3.1, 41.0), 9.0, 1.1, INCAND)
	for ln: Array in [[Vector3(-4.0, 2.8, 42.6), 3.62], [Vector3(17.0, 2.8, 35.5), 3.62], [Vector3(30.0, 2.8, 42.6), 4.0],
			[Vector3(-12.0, 2.8, 35.5), 3.62], [Vector3(6.0, 2.8, 35.5), 3.62], [Vector3(34.0, 2.8, 35.5), 3.62]]:
		Props.lantern(dress, ln[0], float(ln[1]))
		lamp((ln[0] as Vector3) + Vector3(0, -0.15, 0), Color(1.0, 0.7, 0.4), 1.15, 9.0, 0.08)
	for ht: Vector3 in [Vector3(14.6, 0.8, 37.75), Vector3(31.2, 0.8, 37.6)]:
		_hurricane(ht, 0.9)
	# signs over the stair and lift doors (inside, on the south wall)
	_label("TREPPE  ·  SOHLE I", Vector3(-10.0, 2.75, 45.83), 180.0, 30)
	_label("AUFZUG  ·  SCHACHT III", Vector3(25.0, 2.75, 45.83), 180.0, 30)


func _dress_railyard() -> void:
	# sleepers and rails (track 1 matches the ore-cart trap's own rails, gauge 0.9; tracks 2/3 standard gauge)
	var tracks: Array = [[44.0, 0.45, 15.4, 46.9], [52.0, 0.72, 14.4, 47.6], [57.0, 0.72, 14.4, 47.6]]
	for t: Array in tracks:
		var cx: float = float(t[0])
		var half: float = float(t[1])
		var z: float = float(t[2]) - 0.6
		while z < float(t[3]) + 0.6:
			B(Vector3(cx - half - 0.5, 0.0, z - 0.12), Vector3(cx + half + 0.5, 0.11, z + 0.12), "beam")
			z += 0.72
		for s: float in [-1.0, 1.0]:
			var rx: float = cx + s * half
			B(Vector3(rx - 0.05, 0.04, 14.2), Vector3(rx + 0.05, 0.19, 47.8), "rust")
			B(Vector3(rx - 0.04, 0.19, 14.2), Vector3(rx + 0.04, 0.22, 47.8), "steel")
	# boxcar on track 3 (collider 55.5..58.5 x 18..30, top 3.4; a bell may sit on its roof at 3.75)
	B(Vector3(55.5, 1.0, 18.0), Vector3(58.5, 3.15, 30.0), "wood_red")
	B(Vector3(55.6, 0.85, 18.1), Vector3(58.4, 1.0, 29.9), "loco_black")
	B(Vector3(55.4, 3.15, 17.9), Vector3(58.6, 3.3, 30.1), "iron")
	_noshadow(B(Vector3(55.5, 3.3, 18.0), Vector3(58.5, 3.38, 30.0), "snow", false))
	for sz: float in [18.0, 19.5, 21.0, 26.0, 27.5, 29.0, 30.0]:
		for sx: float in [55.47, 58.53]:
			B(Vector3(sx - 0.03, 1.0, sz - 0.05), Vector3(sx + 0.03, 3.15, sz + 0.05), "loco_black")
	for bz: float in [20.2, 27.8]:
		B(Vector3(56.1, 0.35, bz - 1.2), Vector3(57.9, 0.85, bz + 1.2), "loco_black")
		for wz: float in [bz - 0.8, bz + 0.8]:
			for wx: float in [56.28, 57.72]:
				CYL(Vector3(wx, 0.45, wz), 0.43, 0.12, "loco_black", Vector3(0, 0, 90))
	for ez: float in [17.75, 30.25]:
		for ex: float in [56.2, 57.8]:
			CYL(Vector3(ex, 1.05, ez), 0.17, 0.5, "steel", Vector3(90, 0, 0))
	# open sliding door on the west side (the crate stands in front of it)
	_noshadow(B(Vector3(55.46, 1.05, 22.4), Vector3(55.5, 3.0, 24.6), "window_dark", false))
	B(Vector3(55.3, 1.0, 24.6), Vector3(55.42, 3.1, 26.8), "wood_red")
	B(Vector3(55.28, 3.05, 21.8), Vector3(55.42, 3.12, 27.4), "iron")
	_label("KALTENBRUNN 41 117", Vector3(58.55, 2.6, 20.6), 90.0, 34, Color(0.85, 0.82, 0.72, 0.7))
	# locomotive on track 2 (collider 50.5..54.5 x 26..40, top 3.8; cab to 4.8)
	B(Vector3(50.7, 1.05, 26.0), Vector3(54.3, 1.25, 40.0), "loco_black")
	CYL(Vector3(52.5, 2.4, 31.4), 1.15, 9.2, "loco_black", Vector3(90, 0, 0))
	CYL(Vector3(52.5, 2.4, 26.55), 1.22, 0.7, "loco_black", Vector3(90, 0, 0))
	CYL(Vector3(52.5, 2.4, 26.17), 0.9, 0.08, "iron", Vector3(90, 0, 0))
	for bz2: float in [28.5, 31.5, 34.5]:
		CYL(Vector3(52.5, 2.4, bz2), 1.18, 0.1, "steel", Vector3(90, 0, 0))
	CYL(Vector3(52.5, 3.85, 27.4), 0.32, 1.0, "loco_black")
	CYL(Vector3(52.5, 4.35, 27.4), 0.38, 0.12, "loco_black")
	CYL(Vector3(52.5, 3.7, 31.0), 0.42, 0.6, "loco_black")
	Props.ball(dress, Vector3(52.5, 4.0, 31.0), Vector3(0.84, 0.4, 0.84), "loco_black")
	CYL(Vector3(52.5, 3.65, 33.6), 0.3, 0.5, "loco_black")
	_noshadow(OB(Vector3(52.5, 3.56, 31.4), Vector3(0.9, 0.06, 8.6), "snow"))
	for sx2: float in [50.75, 54.25]:
		B(Vector3(sx2 - 0.03, 1.4, 26.3), Vector3(sx2 + 0.03, 3.5, 28.6), "loco_black")
	for wz2: float in [29.2, 31.4, 33.6, 35.8]:
		for wx2: float in [51.15, 53.85]:
			CYL(Vector3(wx2, 0.72, wz2), 0.7, 0.14, "loco_black", Vector3(0, 0, 90))
			CYL(Vector3(wx2 + signf(wx2 - 52.5) * 0.08, 0.72, wz2), 0.22, 0.05, "red_paint", Vector3(0, 0, 90))
	for wx3: float in [51.15, 53.85]:
		CYL(Vector3(wx3, 0.45, 27.3), 0.44, 0.12, "loco_black", Vector3(0, 0, 90))
		B(Vector3(wx3 + signf(wx3 - 52.5) * 0.12 - 0.03, 0.62, 29.2), Vector3(wx3 + signf(wx3 - 52.5) * 0.12 + 0.03, 0.78, 35.8), "steel")
	B(Vector3(50.6, 0.85, 25.75), Vector3(54.4, 1.4, 26.05), "red_paint")
	B(Vector3(50.7, 0.22, 25.5), Vector3(54.3, 0.85, 25.75), "loco_black")   # (T-239: the pilot plate under the beam, Prop_B_LocoBuffers)
	B(Vector3(52.35, 0.9, 25.35), Vector3(52.65, 1.1, 25.75), "steel")
	for bx: float in [51.4, 53.6]:
		CYL(Vector3(bx, 1.1, 25.55), 0.17, 0.45, "steel", Vector3(90, 0, 0))
	_noshadow(Props.ball(dress, Vector3(52.5, 3.2, 25.95), Vector3(0.28, 0.28, 0.14), "bulb_off"))
	# cab (z 36..40): walls with window holes, roof with snow
	B(Vector3(50.6, 1.25, 36.0), Vector3(54.4, 2.6, 40.0), "loco_black")
	for cx: Array in [[50.6, 51.1], [53.9, 54.4]]:
		B(Vector3(float(cx[0]), 2.6, 36.0), Vector3(float(cx[1]), 4.5, 40.0), "loco_black")
	B(Vector3(51.1, 2.6, 36.0), Vector3(53.9, 4.5, 36.3), "loco_black")
	_noshadow(B(Vector3(50.58, 2.9, 37.0), Vector3(50.62, 3.9, 38.6), "window_dark", false))
	_noshadow(B(Vector3(54.38, 2.9, 37.0), Vector3(54.42, 3.9, 38.6), "window_dark", false))
	B(Vector3(50.4, 4.5, 35.8), Vector3(54.6, 4.75, 40.3), "loco_black")
	_noshadow(B(Vector3(50.45, 4.75, 35.85), Vector3(54.55, 4.83, 40.25), "snow", false))
	_label("52 4471", Vector3(50.58, 2.0, 38.0), -90.0, 40, Color(0.75, 0.72, 0.62, 0.8))
	# buffer stop at the end of track 1
	B(Vector3(42.6, 0.0, 47.0), Vector3(45.4, 1.0, 47.7), "beam")
	B(Vector3(42.4, 0.6, 46.85), Vector3(45.6, 0.95, 47.05), "red_paint")
	for bsx: float in [43.0, 45.0]:
		Props.strut(dress, Vector3(bsx, 0.1, 46.0), Vector3(bsx, 0.95, 47.0), 0.1, "rust")
	_noshadow(Props.ball(dress, Vector3(44.0, 1.25, 47.3), Vector3(0.22, 0.22, 0.1), "emergency_red"))
	# signal box lever frame (collider top 1.0; a radio may sit on it at z 46)
	B(Vector3(57.5, 0, 44.5), Vector3(59.8, 0.95, 47.8), "machine_green")
	B(Vector3(57.45, 0.95, 44.45), Vector3(59.85, 1.0, 47.85), "steel")
	for k: int in 6:
		var lz: float = 44.75 + k * 0.17
		Props.obox(dress, Vector3(59.4, 1.35, lz), Vector3(0.04, 0.75, 0.04), "red_paint" if k % 2 == 0 else "steel", Vector3(-12, 0, 0))
	_label("STELLWERK", Vector3(57.48, 0.6, 46.1), -90.0, 26)
	# parked carts, a coal heap, a water crane
	Props.ore_cart(dress, Vector3(57.0, 0.22, 35.2), 0.0)
	Props.ore_cart(dress, Vector3(57.0, 0.22, 37.1), 0.0, "coal")
	# (T-239: the coal lies heaped into the corner behind a plank (Prop_B_CoalHeap); the water crane stands by the south
	# wall clear of the window (Prop_B_WaterCrane, round): it stood in the walkway between the tracks and nobody hit it)
	Props.ball(dress, Vector3(58.75, 0.0, 15.2), Vector3(2.5, 1.5, 2.5), "coal")
	B(Vector3(57.5, 0.0, 14.2), Vector3(57.56, 0.55, 16.4), "planks")
	B(Vector3(57.5, 0.0, 16.36), Vector3(59.8, 0.55, 16.42), "planks")
	CYL(Vector3(47.2, 1.7, 47.3), 0.18, 3.4, "loco_black")
	Props.strut(dress, Vector3(47.2, 3.3, 47.3), Vector3(48.6, 3.3, 46.6), 0.14, "loco_black")
	Props.strut(dress, Vector3(48.6, 3.3, 46.6), Vector3(48.7, 2.2, 46.5), 0.1, "rubber", true)
	CYL(Vector3(47.2, 0.15, 47.3), 0.4, 0.3, "loco_black")
	# floodlights on the walls (powered)
	flood("B_RAILYARD", Vector3(40.35, 4.7, 22.0), Vector3(50.0, 0.0, 27.0), 28.0, 4.0, 45.0)
	flood("B_RAILYARD", Vector3(59.65, 4.7, 40.0), Vector3(48.0, 0.0, 37.0), 28.0, 4.0, 45.0)
	for fp: Vector3 in [Vector3(40.3, 4.12, 22.0), Vector3(59.7, 4.12, 40.0)]:
		Props.strut(dress, fp, fp + Vector3(0, 0.6, 0), 0.08, "iron")
	Props.wall_lamp(dress, Vector3(40.17, 2.4, 44.0), -90.0)
	lamp(Vector3(40.9, 2.3, 44.0), Color(1.0, 0.68, 0.38), 0.8, 8.0, 0.1)
	# (T-239: the east lane (both chalks) and the north-east corner behind the boxcar were black before the power)
	Props.wall_lamp(dress, Vector3(59.83, 2.5, 39.0), 90.0)
	lamp(Vector3(59.1, 2.35, 39.0), Color(1.0, 0.68, 0.38), 1.0, 8.5, 0.1)
	Props.wall_lamp(dress, Vector3(57.4, 2.5, 14.17), 180.0)
	lamp(Vector3(57.4, 2.35, 14.9), Color(1.0, 0.68, 0.38), 0.9, 8.0, 0.1)
	# a hurricane lantern left on the ballast by the locomotive's cab, the signal frame's red hand lamp
	_hurricane(Vector3(49.4, 0.0, 38.6), 1.3)
	_noshadow(Props.ball(dress, Vector3(58.6, 1.12, 47.4), Vector3(0.12, 0.14, 0.12), "emergency_red"))
	lamp(Vector3(58.4, 1.4, 47.0), RED, 0.5, 6.0, 0.1, 0.0, false, 3.0)
	for gn: Array in [[Vector3(40.15, 3.5, 33.0), -90.0], [Vector3(59.85, 3.5, 22.0), 90.0], [Vector3(50.0, 3.5, 14.15), 180.0]]:
		goose("B_RAILYARD", gn[0], float(gn[1]))


func _dress_lifthouse() -> void:
	# brick above the barracks roof where the shared wall's visual is hidden; roof snow
	B(Vector3(19.85, 4.0, 45.85), Vector3(30.15, 6.0, 46.15), "brick")
	_noshadow(B(Vector3(19.85, 6.3, 45.85), Vector3(30.15, 6.38, 56.15), "snow", false))
	B(Vector3(19.75, 6.0, 45.75), Vector3(30.25, 6.3, 56.25), "concrete")
	# winding gear: beams under the roof, a sheave over the shaft, the hoist motor
	for bz: float in [50.0, 52.0]:
		B(Vector3(20.15, 5.5, bz - 0.12), Vector3(29.85, 5.85, bz + 0.12), "iron")
	var hub: Vector3 = Vector3(25.0, 4.95, 51.0)
	var prev: Vector3 = hub + Vector3(0, 0, 0.75)
	for k: int in 16:
		var a: float = TAU * float(k + 1) / 16.0
		var p: Vector3 = hub + Vector3(0, sin(a) * 0.75, cos(a) * 0.75)
		Props.strut(dress, prev, p, 0.1, "iron")
		prev = p
	CYL(hub, 0.12, 4.0, "steel", Vector3(0, 0, 90))
	B(Vector3(27.6, 0.0, 53.6), Vector3(29.7, 1.4, 55.7), "machine_green")
	CYL(Vector3(28.65, 1.8, 54.65), 0.45, 1.6, "iron", Vector3(0, 0, 90))
	Props.gauge(dress, Vector3(28.65, 1.0, 53.58), 0.0, 0.1)
	Props.strut(dress, Vector3(28.65, 2.25, 54.65), Vector3(25.0, 5.7, 51.0), 0.04, "iron", true)
	# safety rails on both open sides of the shaft
	for sx: float in [22.85, 27.15]:
		for pz: float in [49.0, 51.0, 53.0]:
			B(Vector3(sx - 0.03, 0, pz - 0.03), Vector3(sx + 0.03, 1.1, pz + 0.03), "yellow_paint")
		B(Vector3(sx - 0.03, 1.05, 49.0), Vector3(sx + 0.03, 1.1, 53.0), "yellow_paint")
		B(Vector3(sx - 0.03, 0.55, 49.0), Vector3(sx + 0.03, 0.6, 53.0), "yellow_paint")
	# guide rails and buntons down the shaft (fake depth: the fog volume hides the bottom)
	for gx: float in [22.86, 27.14]:
		for gz: float in [49.6, 52.4]:
			B(Vector3(gx - 0.06, DY, gz - 0.07), Vector3(gx + 0.06, 0.0, gz + 0.07), "steel")
		var yb: float = DY + 1.0
		while yb < -0.5:
			B(Vector3(gx - 0.05, yb, 48.85), Vector3(gx + 0.05, yb + 0.18, 53.15), "iron")
			yb += 2.5
	# lamps: one under the roof (powered), one in the arrival bay (powered), the bay's emergency lamp
	pendant("E_LIFT", Vector3(25.0, 4.6, 54.6), 6.0, "enamel_green")
	power("E_LIFT", Vector3(25.0, 4.4, 54.6), 9.0, 1.3)
	bulkhead("E_LIFT", Vector3(25.0, DY + 3.1, 59.8), 0.0)
	power("E_LIFT", Vector3(25.0, DY + 3.0, 58.6), 8.0, 1.2)
	emergency(Vector3(21.17, DY + 2.6, 57.0), -90.0, 0.7, 6.0)
	Props.wall_lamp(dress, Vector3(28.83, DY + 2.3, 56.4), 90.0)   # (T-239: the arrival bay had only the red lamp)
	lamp(Vector3(28.2, DY + 2.2, 56.4), Color(1.0, 0.68, 0.38), 0.9, 7.0, 0.1)
	_hurricane(Vector3(28.2, 1.4, 54.0), 1.1)
	Props.wall_lamp(dress, Vector3(20.17, 2.4, 53.0), -90.0)
	lamp(Vector3(20.9, 2.3, 53.0), Color(1.0, 0.68, 0.38), 1.0, 8.0, 0.1)
	_label("PERSONENAUFZUG — HÖCHSTENS 8 MANN", Vector3(29.83, 2.0, 50.0), -90.0, 24)


func _dress_stairwell() -> void:
	# pipes and a cable run down the north-west corner, level stencils, emergency lamps
	for px: Array in [[-15.7, "copper", 0.07], [-15.45, "rust", 0.1], [-15.2, "rubber", 0.04]]:
		CYL(Vector3(float(px[0]), -4.0, 46.25), float(px[2]), 16.0, str(px[1]))
	for yb: float in [-10.0, -6.0, -2.0, 2.0]:
		B(Vector3(-15.85, yb, 46.15), Vector3(-15.0, yb + 0.06, 46.4), "iron")
	_label("SOHLE I  ·  SALZKAPELLE", Vector3(-7.0, DY + 2.3, 59.83), 180.0, 36, Color(0.85, 0.82, 0.72, 0.8))
	_label("↓  SOHLE I", Vector3(-4.17, -2.0, 55.5), -90.0, 40, Color(0.85, 0.82, 0.72, 0.8))
	_label("TAGESSOHLE", Vector3(-10.0, 2.8, 46.17), 0.0, 34, Color(0.85, 0.82, 0.72, 0.8))
	# landing edges painted yellow
	for e: Array in [[Vector3(-16, -4.0, 54.0), Vector3(-4, -3.99, 54.12)], [Vector3(-16, -8.0, 47.88), Vector3(-4, -7.99, 48.0)],
			[Vector3(-16, DY, 54.0), Vector3(-12.3, DY + 0.01, 54.12)]]:
		B(e[0], e[1], "yellow_paint")
	emergency(Vector3(-4.17, -1.6, 52.0), 90.0, 0.8, 10.0)
	emergency(Vector3(-9.0, DY + 2.8, 59.83), 0.0, 0.8, 8.0)
	emergency(Vector3(-15.83, -6.0, 55.5), -90.0, 0.6, 8.0)
	bulkhead("", Vector3(-10.0, 3.2, 46.17), 180.0)
	for hl: Vector3 in [Vector3(-5.0, -4.0, 56.5), Vector3(-6.0, -8.0, 46.6), Vector3(-5.0, DY, 58.8), Vector3(-15.4, -4.0, 56.6)]:
		_hurricane(hl, 1.3)
	for bh: Array in [[Vector3(-15.83, -1.4, 55.5), -90.0], [Vector3(-4.17, -5.4, 47.0), 90.0], [Vector3(-4.17, DY + 2.6, 57.5), 90.0]]:
		bulkhead("E_LIFT", bh[0], float(bh[1]), "sodium")
		power("E_LIFT", (bh[0] as Vector3) + Basis(Vector3.UP, deg_to_rad(float(bh[1]))) * Vector3(0, -0.2, -0.6), 10.0, 1.2, SODIUM, false, {}, 0.4)
	lamp(Vector3(-10.0, 3.0, 46.8), Color(1.0, 0.7, 0.42), 0.8, 7.0, 0.06)
	# pit props at the foot of the stairs
	Props.pit_prop(dress, Vector3(-12.0, DY, 59.6), 0.0, 3.4, 2.5)


func _dress_chapel() -> void:
	var y: float = DY
	var carved: String = "halite_carved"
	# plinth and cornice round the hall (on the lined faces)
	for r: Array in [[Vector3(-15.97, y, 60.2), Vector3(-15.75, y + 0.45, 89.8)], [Vector3(39.75, y, 60.2), Vector3(39.97, y + 0.45, 70.9)], [Vector3(39.75, y, 73.1), Vector3(39.97, y + 0.45, 89.8)]]:
		B(r[0], r[1], carved)
	for xs: Array in [[-15.8, -6.9], [-5.1, 17.9], [22.1, 31.1], [32.9, 39.8]]:
		B(Vector3(float(xs[0]), y, 89.62), Vector3(float(xs[1]), y + 0.45, 89.82), carved)
	B(Vector3(-15.82, y + 7.6, 60.18), Vector3(39.82, y + 7.75, 60.35), carved)
	B(Vector3(-15.82, y + 7.6, 89.65), Vector3(39.82, y + 7.75, 89.82), carved)
	B(Vector3(-15.82, y + 7.6, 60.18), Vector3(-15.65, y + 7.75, 89.82), carved)
	B(Vector3(39.65, y + 7.6, 60.18), Vector3(39.82, y + 7.75, 89.82), carved)
	B(Vector3(-15.82, y + 8.0, 60.18), Vector3(39.82, y + 8.45, 60.55), carved)
	B(Vector3(-15.82, y + 8.0, 89.45), Vector3(39.82, y + 8.45, 89.82), carved)
	B(Vector3(-15.82, y + 8.0, 60.18), Vector3(-15.45, y + 8.45, 89.82), carved)
	B(Vector3(39.45, y + 8.0, 60.18), Vector3(39.82, y + 8.45, 89.82), carved)
	# pilasters: [pos on the lined face, yaw facing the room]
	var pil: Array = []
	for x: float in [-7.0, -1.0, 5.0, 11.0, 17.0, 21.0, 30.0, 37.5]:
		pil.append([Vector3(x, y, 60.18), 0.0])
	for x2: float in [-12.0, -2.0, 2.0, 5.5, 17.3, 25.0, 28.5, 36.5]:
		pil.append([Vector3(x2, y, 89.82), 180.0])
	for z: float in [63.0, 67.5, 75.5, 86.5]:
		pil.append([Vector3(-15.82, y, z), 90.0])
	for z2: float in [63.0, 67.5, 76.5, 86.5]:
		pil.append([Vector3(39.82, y, z2), -90.0])
	for p: Array in pil:
		var g: Node3D = Props.group(dress, "Pilaster", p[0], float(p[1]))   # local +Z = into the room
		Props.block(g, Vector3(-0.42, 0, 0), Vector3(0.42, 7.6, 0.28), carved)
		Props.block(g, Vector3(-0.55, 0, 0), Vector3(0.55, 0.55, 0.4), carved)
		Props.block(g, Vector3(-0.55, 7.1, 0), Vector3(0.55, 7.6, 0.42), carved)
		Props.block(g, Vector3(-0.12, 0.7, 0.28), Vector3(0.12, 6.9, 0.33), carved)
		# a sconce on every pilaster (powered with the chapel)
		Props.block(g, Vector3(-0.06, 3.0, 0.28), Vector3(0.06, 3.3, 0.5), "brass")
		_noshadow(Props.ball(g, Vector3(0, 3.42, 0.48), Vector3(0.11, 0.15, 0.11), "bulb_off"))
		var gg: Node3D = Props.group(G("F_CHAPEL"), "SconceGlow", p[0], float(p[1]))
		_noshadow(Props.ball(gg, Vector3(0, 3.42, 0.48), Vector3(0.13, 0.17, 0.13), "bulb_warm"))
	# ceiling ribs (coffers)
	for rx: float in [-10.0, -2.0, 6.0, 18.0, 26.0, 34.0]:
		B(Vector3(rx - 0.3, y + 13.3, 60.15), Vector3(rx + 0.3, y + 14.0, 89.85), carved)
	for rz: float in [65.0, 70.5, 76.0, 82.0, 87.0]:
		B(Vector3(-15.85, y + 13.4, rz - 0.25), Vector3(39.85, y + 14.0, rz + 0.25), carved)
	# relief panels between pilasters
	var reliefs: Array = [
		[Vector3(-15.82, y + 2.9, 71.5), 90.0, 6.2, 3.8, 1], [Vector3(-15.82, y + 2.9, 81.0), 90.0, 6.4, 3.8, 2],
		[Vector3(39.82, y + 2.9, 72.0), -90.0, 6.4, 3.8, 3], [Vector3(39.82, y + 4.0, 81.5), -90.0, 6.4, 3.0, 4],
		[Vector3(2.0, y + 2.9, 60.18), 0.0, 4.6, 3.6, 5], [Vector3(25.5, y + 3.3, 60.18), 0.0, 6.4, 3.4, 6],
		[Vector3(-4.0, y + 2.9, 60.18), 0.0, 4.6, 3.6, 7],
		[Vector3(-7.0, y + 2.9, 89.82), 180.0, 7.0, 3.8, 8], [Vector3(32.5, y + 2.9, 89.82), 180.0, 5.4, 3.8, 9],
	]
	for rl: Array in reliefs:
		_relief(rl[0], float(rl[1]), float(rl[2]), float(rl[3]), int(rl[4]))
	# salt columns: base, corner rolls, astragal and capital
	for cx: float in [-4.0, 10.0, 24.0, 34.0]:
		B(Vector3(cx - 0.76, y, 79.44), Vector3(cx + 0.76, y + 0.6, 80.96), carved)   # (T-239: the base is the collider's; it stood 0.25 m proud all round)
		B(Vector3(cx - 1.0, y + 12.9, 79.2), Vector3(cx + 1.0, y + 13.9, 81.2), carved)
		B(Vector3(cx - 0.85, y + 7.6, 79.35), Vector3(cx + 0.85, y + 7.85, 81.05), carved)
		for c: Vector2 in [Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.7, 0.7)]:
			CYL(Vector3(cx + c.x, y + 7.0, 80.2 + c.y), 0.16, 12.6, carved)
		Props.crystal_cluster(dress, Vector3(cx + 0.55, y + 0.6, 80.8), int(cx * 13.0) + 101, 0.5, "salt_crystal")
	# pews (7 per block on the pew colliders)
	for bx: float in [-10.0, 2.0, 14.0, 26.0]:
		for k: int in 7:
			var z0: float = 64.0 + k * 2.0
			B(Vector3(bx + 0.05, y + 0.42, z0 + 0.55), Vector3(bx + 7.95, y + 0.5, z0 + 1.15), "furniture")
			B(Vector3(bx + 0.05, y + 0.5, z0 + 1.1), Vector3(bx + 7.95, y + 0.95, z0 + 1.2), "furniture")
			B(Vector3(bx + 0.05, y + 0.12, z0 + 0.15), Vector3(bx + 7.95, y + 0.2, z0 + 0.35), "furniture")
			for ex: float in [bx + 0.0, bx + 7.92]:
				B(Vector3(ex, y, z0 + 0.45), Vector3(ex + 0.08, y + 0.98, z0 + 1.25), "beam")
			B(Vector3(bx + 0.1, y, z0 + 0.6), Vector3(bx + 7.9, y + 0.42, z0 + 0.66), "beam")
	# floor: a darker salt runner down the aisle and round the altar
	_noshadow(B(Vector3(10.3, y, 60.6), Vector3(13.7, y + 0.012, 81.0), "halite", false))
	_noshadow(B(Vector3(-15.0, y, 78.6), Vector3(39.0, y + 0.012, 79.2), "halite", false))
	# the altar: dais, carved front, table with cloth, candles; the great relief behind it
	B(Vector3(6.0, y, 82.0), Vector3(18.0, y + 0.92, 88.0), carved)
	B(Vector3(5.9, y + 0.92, 81.9), Vector3(18.1, y + 1.0, 88.1), carved)
	for k2: int in 5:
		var px: float = 7.0 + k2 * 2.5
		B(Vector3(px - 0.9, y + 0.15, 81.88), Vector3(px + 0.9, y + 0.8, 81.95), "halite")
		B(Vector3(px - 0.7, y + 0.25, 81.85), Vector3(px + 0.7, y + 0.7, 81.88), carved)
	# (T-239: the steps are solid (Prop_F_AltarSteps*) and stop 2 m either side of the reliquary: 4 m of clear floor in front
	# of it instead of 2.8 between two flights nobody could stand on)
	for sx: Array in [[6.4, 10.0], [14.0, 17.6]]:
		B(Vector3(float(sx[0]), y, 81.0), Vector3(float(sx[1]), y + 0.33, 82.0), carved)
		B(Vector3(float(sx[0]), y + 0.33, 81.5), Vector3(float(sx[1]), y + 0.66, 82.0), carved)
	B(Vector3(10.0, y + 1.0, 84.0), Vector3(14.0, y + 1.6, 86.0), carved)
	B(Vector3(9.9, y + 1.6, 83.9), Vector3(14.1, y + 1.63, 86.1), "linen")
	B(Vector3(10.6, y + 1.05, 83.86), Vector3(13.4, y + 1.6, 83.9), "cloth_red")
	for cxp: float in [10.4, 11.2, 12.8, 13.6]:
		CYL(Vector3(cxp, y + 1.78, 85.6), 0.05, 0.3, "brass")
		_noshadow(CYL(Vector3(cxp, y + 2.02, 85.6), 0.03, 0.18, "candle"))
	for sxp: float in [7.0, 17.0]:
		CYL(Vector3(sxp, y + 1.9, 87.2), 0.06, 1.8, "brass")
		CYL(Vector3(sxp, y + 1.05, 87.2), 0.25, 0.1, "brass")
		for o: float in [-0.3, 0.0, 0.3]:
			_noshadow(CYL(Vector3(sxp + o, y + 2.95, 87.2), 0.035, 0.22, "candle"))
		B(Vector3(sxp - 0.35, y + 2.78, 87.17), Vector3(sxp + 0.35, y + 2.82, 87.23), "brass")
	lamp(Vector3(12.0, y + 2.6, 85.2), Color(1.0, 0.62, 0.3), 2.0, 11.0, 0.18, 0.6)
	lamp(Vector3(7.0, y + 3.3, 87.0), Color(1.0, 0.62, 0.3), 0.6, 5.0, 0.2)
	lamp(Vector3(17.0, y + 3.3, 87.0), Color(1.0, 0.62, 0.3), 0.6, 5.0, 0.2)
	_altar_relief(y)
	# bell yoke (the scripted bell hangs below it) and its chains
	B(Vector3(10.4, y + 11.75, 84.8), Vector3(13.6, y + 12.1, 85.2), "beam")
	for chx: float in [10.8, 13.2]:
		_noshadow(B(Vector3(chx - 0.03, y + 12.1, 84.97), Vector3(chx + 0.03, y + 14.0, 85.03), "iron"))
	# standing candelabras halfway down the centre aisle (warm light on the aisle and pews before the power)
	for fz: Array in [[9.7, 63.72], [14.3, 63.72]]:   # (T-239: at the pew blocks' corners; they stood loose in the cross aisle)
		var fp: Vector3 = Vector3(float(fz[0]), y, float(fz[1]))
		CYL(fp + Vector3(0, 0.8, 0), 0.05, 1.6, "brass")
		CYL(fp + Vector3(0, 0.05, 0), 0.22, 0.1, "brass")
		_noshadow(CYL(fp + Vector3(0, 1.72, 0), 0.03, 0.2, "candle"))
		lamp(fp + Vector3(0, 2.0, 0), Color(1.0, 0.62, 0.3), 1.0, 8.0, 0.2, 0.4)
	for cdx: float in [10.25, 13.75]:
		CYL(Vector3(cdx, y + 0.8, 71.0), 0.05, 1.6, "brass")
		CYL(Vector3(cdx, y + 0.05, 71.0), 0.22, 0.1, "brass")
		B(Vector3(cdx, y + 1.6, 70.7), Vector3(cdx + 0.04, y + 1.64, 71.3), "brass")
		for o2: float in [-0.25, 0.0, 0.25]:
			_noshadow(CYL(Vector3(cdx, y + 1.75, 71.0 + o2), 0.03, 0.2, "candle"))
		lamp(Vector3(cdx, y + 2.1, 71.0), Color(1.0, 0.62, 0.3), 1.2, 9.0, 0.2, 0.4)
	# font
	CYL(Vector3(12.0, y + 0.35, 61.8), 0.3, 0.7, carved)
	CYL(Vector3(12.0, y + 0.85, 61.8), 0.58, 0.3, carved)
	_noshadow(CYL(Vector3(12.0, y + 0.98, 61.8), 0.48, 0.05, "window_dark"))
	# confessional (top at 2.5: a cylinder can rest on it)
	B(Vector3(-15.85, y, 81.0), Vector3(-14.6, y + 0.1, 84.4), "furniture")
	B(Vector3(-15.85, y + 2.38, 80.95), Vector3(-14.55, y + 2.5, 84.45), "furniture")
	for cz: float in [81.0, 82.1, 83.3, 84.35]:
		B(Vector3(-15.85, y, cz - 0.05), Vector3(-14.6, y + 2.38, cz + 0.05), "beam")
	B(Vector3(-15.85, y + 0.1, 81.05), Vector3(-15.75, y + 2.38, 84.35), "furniture")
	B(Vector3(-14.68, y + 1.0, 82.15), Vector3(-14.6, y + 2.38, 83.25), "furniture")
	for cz2: Array in [[81.05, 82.05], [83.35, 84.3]]:
		B(Vector3(-14.66, y + 0.25, float(cz2[0])), Vector3(-14.62, y + 2.2, float(cz2[1])), "cloth_red")
	# side altar niche for the crate (east wall)
	for nz: float in [80.5, 83.5]:
		B(Vector3(39.4, y, nz - 0.2), Vector3(39.82, y + 3.2, nz + 0.2), carved)
	B(Vector3(39.4, y + 3.2, 80.3), Vector3(39.82, y + 3.6, 83.7), carved)
	B(Vector3(39.5, y + 1.25, 80.7), Vector3(39.82, y + 1.32, 83.3), carved)
	for ncz: float in [81.0, 81.6, 82.4, 83.0]:
		_noshadow(CYL(Vector3(39.66, y + 1.45, ncz), 0.03, 0.22, "candle"))
	lamp(Vector3(39.0, y + 1.8, 82.0), Color(1.0, 0.62, 0.3), 0.6, 5.0, 0.2)
	# salt crystals growing at the wall feet and on the cornice
	var spots: Array = [Vector3(-15.3, y, 60.8), Vector3(39.3, y, 60.8), Vector3(-15.3, y, 89.2), Vector3(39.3, y, 89.2),
		Vector3(-15.4, y, 65.3), Vector3(-15.4, y, 88.0), Vector3(39.4, y, 69.0), Vector3(39.4, y, 87.5), Vector3(30.0, y, 89.4),
		Vector3(-9.0, y, 89.4), Vector3(-15.5, y + 8.45, 74.0), Vector3(39.5, y + 8.45, 70.0), Vector3(5.0, y + 8.45, 89.6)]
	var si: int = 0
	for sp: Vector3 in spots:
		Props.crystal_cluster(dress, sp, 500 + si, 0.9 if sp.y < y + 1.0 else 0.6, "salt_crystal")
		si += 1
	# decorative salt chandeliers over the side aisles (powered) + the four chapel power lights
	for cp: Vector3 in [Vector3(0.0, y + 8.6, 68.0), Vector3(0.0, y + 8.6, 75.5), Vector3(24.0, y + 8.6, 68.0), Vector3(24.0, y + 8.6, 75.5)]:
		_salt_chandelier(cp, y + 14.0)
		power("F_CHAPEL", cp + Vector3(0, -0.4, 0), 17.0, 1.7, CHAPEL_LAMP, false, {}, 0.6)
	power("F_CHAPEL", Vector3(12.0, y + 6.0, 85.0), 14.0, 1.8, CHAPEL_LAMP, false, {}, 0.5)
	power("F_CHAPEL", Vector3(12.0, y + 7.6, 66.0), 18.0, 1.4, CHAPEL_LAMP, false, {}, 0.5)
	power("F_CHAPEL", Vector3(12.0, y + 7.6, 76.0), 18.0, 1.4, CHAPEL_LAMP, false, {}, 0.5)
	# votive racks: warm pools in the dark nave before the power comes on
	# (T-239: solid (Prop_F_Votive*) and between the pilasters: two of the four stood inside a pilaster's shaft)
	for vr: Array in [[Vector3(-15.3, y, 68.8), 90.0], [Vector3(-15.3, y, 79.8), 90.0], [Vector3(39.3, y, 65.0), -90.0], [Vector3(39.3, y, 85.2), -90.0]]:
		var vg: Node3D = Props.group(dress, "Votive", vr[0], float(vr[1]))
		Props.block(vg, Vector3(-0.7, 0, -0.2), Vector3(0.7, 0.8, 0.2), "iron")
		for row: int in 2:
			Props.block(vg, Vector3(-0.7, 0.8 + row * 0.25, -0.2 + row * 0.12), Vector3(0.7, 0.84 + row * 0.25, 0.2), "iron")
			for k: int in 7:
				_noshadow(Props.cyl(vg, Vector3(-0.6 + k * 0.2, 0.92 + row * 0.25, 0.0 + row * 0.08), 0.025, 0.12, "candle"))
		lamp((vr[0] as Vector3) + Basis(Vector3.UP, deg_to_rad(float(vr[1]))) * Vector3(0, 1.3, 0.6), Color(1.0, 0.6, 0.28), 1.3, 8.0, 0.2, 0.5)
	# timber frames at the doorways (crossbeam at 2.6: the lift-side bell hangs just above it)
	Props.pit_prop(dress, Vector3(-12.0, y, 60.42), 0.0, 3.5, 2.5)
	Props.pit_prop(dress, Vector3(25.0, y, 60.42), 0.0, 4.5, 2.5)
	Props.pit_prop(dress, Vector3(39.55, y, 72.0), 90.0, DW + 0.6, 2.5)   # (T-239: its legs stand either side of the doorway; at 2.6 they stood in it)
	Props.pit_prop(dress, Vector3(20.0, y, 89.55), 0.0, 4.6, 3.1)
	emergency(Vector3(-9.6, y + 2.9, 60.36), 180.0, 1.0, 10.0)
	emergency(Vector3(22.2, y + 2.9, 60.36), 180.0, 0.9, 9.0)
	emergency(Vector3(22.6, y + 3.4, 89.64), 0.0, 0.7, 8.0)


## A carved bas-relief panel: a recessed field in a frame with two or three figures (local -Z faces the room
## after the 180° flip, so build toward +Z = into the room with the group yaw = facing yaw).
func _relief(pos: Vector3, yaw: float, w: float, h: float, seed_v: int) -> void:
	var carved: String = "halite_carved"
	var g: Node3D = Props.group(dress, "Relief", pos, yaw)   # local +Z = into the room
	Props.block(g, Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, h, 0.05), "halite")
	Props.block(g, Vector3(-w * 0.5 - 0.15, -0.15, 0), Vector3(w * 0.5 + 0.15, 0.0, 0.18), carved)
	Props.block(g, Vector3(-w * 0.5 - 0.15, h, 0), Vector3(w * 0.5 + 0.15, h + 0.2, 0.2), carved)
	for s: float in [-1.0, 1.0]:
		Props.block(g, Vector3(s * w * 0.5 - 0.15, 0, 0), Vector3(s * w * 0.5 + 0.15, h, 0.18), carved)
	Props.block(g, Vector3(-w * 0.5, 0.0, 0.05), Vector3(w * 0.5, 0.18, 0.14), carved)   # ground line
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var n: int = 2 if w < 5.0 else 3
	for i: int in n:
		var fx: float = -w * 0.5 + w * (float(i) + 0.5) / float(n) + rng.randf_range(-0.25, 0.25)
		var f: Node3D = Node3D.new()
		f.position = Vector3(fx, 0.18, 0.06)
		f.scale = Vector3(1, 1, 0.35)   # flattened into the wall
		g.add_child(f)
		var tall: float = rng.randf_range(2.1, 2.6)
		Props.cone(f, Vector3(0, tall * 0.36, 0), 0.38, tall * 0.72, carved)
		Props.ball(f, Vector3(0, tall * 0.8, 0), Vector3(0.36, 0.42, 0.36), carved)
		Props.ball(f, Vector3(0, tall * 0.9, -0.02), Vector3(0.42, 0.18, 0.42), carved)   # cap
		var pose: int = rng.randi() % 3
		match pose:
			0:   # a miner swinging a pick
				Props.strut(f, Vector3(-0.2, tall * 0.62, 0), Vector3(0.45, tall * 0.92, 0.1), 0.12, carved)
				Props.strut(f, Vector3(0.45, tall * 0.92, 0.1), Vector3(0.75, tall * 0.55, 0.1), 0.08, carved)
				Props.strut(f, Vector3(0.95, tall * 1.02, 0.1), Vector3(0.55, tall * 0.5, 0.1), 0.07, carved)
			1:   # a figure holding up a lamp
				Props.strut(f, Vector3(0.2, tall * 0.62, 0), Vector3(0.4, tall * 1.02, 0.1), 0.11, carved)
				Props.ball(f, Vector3(0.42, tall * 1.08, 0.1), Vector3(0.2, 0.26, 0.2), carved)
				Props.strut(f, Vector3(-0.2, tall * 0.62, 0), Vector3(-0.3, tall * 0.35, 0.05), 0.1, carved)
			_:   # hands together, head bowed
				Props.strut(f, Vector3(-0.2, tall * 0.62, 0), Vector3(0.0, tall * 0.55, 0.25), 0.1, carved)
				Props.strut(f, Vector3(0.2, tall * 0.62, 0), Vector3(0.0, tall * 0.55, 0.25), 0.1, carved)
	# an arch of rays over the scene
	for k: int in 7:
		var a: float = PI * (0.15 + 0.7 * float(k) / 6.0)
		Props.strut(g, Vector3(cos(a) * w * 0.3, h - 0.25 - sin(a) * 0.1, 0.06), Vector3(cos(a) * w * 0.42, h - 0.1, 0.06), 0.06, carved)


func _altar_relief(y: float) -> void:
	var carved: String = "halite_carved"
	var g: Node3D = Props.group(dress, "AltarRelief", Vector3(12.0, y + 1.2, 89.82), 180.0)   # local +Z = into the room
	Props.block(g, Vector3(-5.4, 0, 0), Vector3(5.4, 8.2, 0.05), "halite")
	Props.block(g, Vector3(-5.6, -0.2, 0), Vector3(5.6, 0.0, 0.25), carved)
	Props.block(g, Vector3(-5.6, 8.2, 0), Vector3(5.6, 8.5, 0.3), carved)
	for s: float in [-1.0, 1.0]:
		Props.block(g, Vector3(s * 5.4 - 0.2, 0, 0), Vector3(s * 5.4 + 0.2, 8.2, 0.25), carved)
		# twisted columns either side of the cross
		for k: int in 12:
			Props.ball(g, Vector3(s * 4.3, 0.4 + k * 0.6, 0.22), Vector3(0.42, 0.62, 0.42), carved)
	Props.block(g, Vector3(-0.32, 0.6, 0.05), Vector3(0.32, 7.3, 0.45), carved)
	Props.block(g, Vector3(-2.0, 5.3, 0.05), Vector3(2.0, 5.9, 0.45), carved)
	var c: Vector3 = Vector3(0, 5.6, 0.12)
	var prev: Vector3 = c + Vector3(1.55, 0, 0)
	for k2: int in 24:
		var a: float = TAU * float(k2 + 1) / 24.0
		var p: Vector3 = c + Vector3(cos(a) * 1.55, sin(a) * 1.55, 0)
		Props.strut(g, prev, p, 0.14, carved)
		prev = p
	for k3: int in 16:
		var a2: float = TAU * float(k3) / 16.0
		Props.strut(g, c + Vector3(cos(a2) * 1.7, sin(a2) * 1.7, 0), c + Vector3(cos(a2) * 2.5, sin(a2) * 2.5, 0), 0.07, carved)
	# kneeling figures
	for s2: float in [-1.0, 1.0]:
		var f: Node3D = Node3D.new()
		f.position = Vector3(s2 * 2.6, 0.2, 0.08)
		f.scale = Vector3(1, 1, 0.4)
		g.add_child(f)
		Props.cone(f, Vector3(0, 0.75, 0), 0.5, 1.5, carved)
		Props.ball(f, Vector3(-s2 * 0.1, 1.65, 0), Vector3(0.42, 0.48, 0.42), carved)
		Props.strut(f, Vector3(-s2 * 0.1, 1.3, 0), Vector3(-s2 * 0.45, 1.55, 0.2), 0.12, carved)
	# Nachtglas set into the cross: the only colour in the hall
	_noshadow(Props.block(g, Vector3(-0.18, 5.42, 0.45), Vector3(0.18, 5.78, 0.5), "nachtglas_dim"))


func _salt_chandelier(c: Vector3, ceil_y: float) -> void:
	_noshadow(B(c + Vector3(-0.025, 0.4, -0.025), Vector3(c.x + 0.025, ceil_y, c.z + 0.025), "iron", false))
	var r: float = 1.1
	var prev: Vector3 = c + Vector3(r, 0, 0)
	for k: int in 14:
		var a: float = TAU * float(k + 1) / 14.0
		var p: Vector3 = c + Vector3(cos(a) * r, 0, sin(a) * r)
		Props.strut(dress, prev, p, 0.07, "brass")
		prev = p
	for k2: int in 4:
		var a2: float = TAU * float(k2) / 4.0
		Props.strut(dress, c + Vector3(0, 0.4, 0), c + Vector3(cos(a2) * r, 0, sin(a2) * r), 0.03, "iron")
	for k3: int in 14:
		var a3: float = TAU * (float(k3) + 0.5) / 14.0
		var dp: Vector3 = c + Vector3(cos(a3) * r, -0.32, sin(a3) * r)
		_noshadow(Props.hexcol(dress, dp, 0.05, 0.5, "salt_crystal"))
		if k3 % 2 == 0:
			var bp: Vector3 = c + Vector3(cos(a3) * r, 0.12, sin(a3) * r)
			_noshadow(Props.ball(dress, bp, Vector3(0.08, 0.12, 0.08), "bulb_off"))
			_noshadow(Props.ball(G("F_CHAPEL"), bp, Vector3(0.1, 0.14, 0.1), "bulb_warm"))
	_noshadow(Props.cone(dress, c + Vector3(0, -0.5, 0), 0.35, 1.0, "salt_crystal", Vector3(180, 0, 0)))
	_noshadow(Props.cone(G("F_CHAPEL"), c + Vector3(0, -0.5, 0), 0.36, 1.02, "salt_crystal_lit", Vector3(180, 0, 0)))


func _dress_generator() -> void:
	var y: float = DY
	# turbines: plinth, generator drum, exciter, flywheel (spins up with the power), terminal box
	var gi: int = 1
	for tx: float in [45.0, 58.0, 71.0]:
		B(Vector3(tx, y, 67.0), Vector3(tx + 9.0, y + 0.7, 73.0), "concrete")
		for e: Array in [[Vector3(tx - 0.6, y, 66.4), Vector3(tx + 9.6, y + 0.01, 66.5)], [Vector3(tx - 0.6, y, 73.5), Vector3(tx + 9.6, y + 0.01, 73.6)],
				[Vector3(tx - 0.6, y, 66.4), Vector3(tx - 0.5, y + 0.01, 73.6)], [Vector3(tx + 9.5, y, 66.4), Vector3(tx + 9.6, y + 0.01, 73.6)]]:
			_noshadow(B(e[0], e[1], "yellow_paint", false))
		CYL(Vector3(tx + 5.2, y + 2.75, 70.0), 2.05, 4.6, "machine_green", Vector3(0, 0, 90))
		for bx: float in [tx + 3.0, tx + 5.2, tx + 7.4]:
			CYL(Vector3(bx, y + 2.75, 70.0), 2.1, 0.16, "iron", Vector3(0, 0, 90))
		for ex: float in [tx + 2.8, tx + 7.6]:
			CYL(Vector3(ex, y + 2.75, 70.0), 1.75, 0.3, "machine_grey", Vector3(0, 0, 90))
		CYL(Vector3(tx + 8.35, y + 2.2, 70.0), 0.95, 1.2, "machine_green", Vector3(0, 0, 90))
		for fz: float in [68.0, 72.0]:
			B(Vector3(tx + 3.2, y + 0.7, fz - 0.35), Vector3(tx + 7.2, y + 1.2, fz + 0.35), "machine_grey")
		CYL(Vector3(tx + 5.0, y + 2.6, 70.0), 0.22, 8.4, "steel", Vector3(0, 0, 90))
		for px: float in [tx + 0.6, tx + 2.3]:
			B(Vector3(px - 0.3, y + 0.7, 69.4), Vector3(px + 0.3, y + 2.4, 70.6), "machine_grey")
		B(Vector3(tx + 4.2, y + 4.75, 69.2), Vector3(tx + 6.2, y + 5.15, 70.8), "machine_grey")
		for ix: float in [tx + 4.6, tx + 5.2, tx + 5.8]:
			CYL(Vector3(ix, y + 5.35, 70.0), 0.09, 0.4, "enamel_white")
			Props.cable(dress, Vector3(ix, y + 5.55, 70.0), Vector3(ix + 0.3, y + 9.6, 63.0 + (ix - tx) * 0.3), 0.8, 0.05)
		B(Vector3(tx + 4.4, y + 2.4, 67.9), Vector3(tx + 6.0, y + 2.9, 67.92), "brass")
		_label("GENERATOR %s  ·  1938" % ["I", "II", "III"][gi - 1], Vector3(tx + 5.2, y + 2.65, 67.88), 180.0, 20, Color(0.15, 0.1, 0.05, 0.95))
		Props.gauge(dress, Vector3(tx + 3.6, y + 3.8, 68.15), 20.0, 0.16)
		Props.gauge(dress, Vector3(tx + 6.8, y + 3.8, 68.15), -20.0, 0.16)
		var fw: Node3D = spinner(dress, "Flywheel%d" % gi, Vector3(tx + 1.45, y + 2.6, 70.0), Vector3(1, 0, 0), 2.6 + gi * 0.3, true)
		var prev: Vector3 = Vector3(0, 0, 2.3)
		for k: int in 22:
			var a: float = TAU * float(k + 1) / 22.0
			var p: Vector3 = Vector3(0, sin(a) * 2.3, cos(a) * 2.3)
			Props.strut(fw, prev, p, 0.42, "iron")
			prev = p
		for k2: int in 6:
			var a2: float = TAU * float(k2) / 6.0
			Props.strut(fw, Vector3.ZERO, Vector3(0, sin(a2) * 2.2, cos(a2) * 2.2), 0.18, "machine_grey")
		Props.cyl(fw, Vector3.ZERO, 0.45, 0.55, "machine_grey", Vector3(0, 0, 90))
		Props.block(fw, Vector3(-0.23, 1.9, -0.2), Vector3(0.23, 2.3, 0.2), "red_paint")
		_bake_local(fw, false)
		gi += 1
	# catwalk (deck height 5.7, hung from the ceiling), its railings and a ladder at the east end
	B(Vector3(44.0, y + 5.5, 74.0), Vector3(81.0, y + 5.7, 75.5), "steel_grate")
	for sz: float in [73.95, 75.55]:
		B(Vector3(44.0, y + 5.35, sz - 0.05), Vector3(81.0, y + 5.7, sz + 0.05), "iron")
		var x: float = 44.0
		while x <= 81.01:
			B(Vector3(x - 0.025, y + 5.7, sz - 0.025), Vector3(x + 0.025, y + 6.75, sz + 0.025), "iron")
			x += 1.5
		B(Vector3(44.0, y + 6.72, sz - 0.03), Vector3(81.0, y + 6.78, sz + 0.03), "iron")
		B(Vector3(44.0, y + 6.2, sz - 0.02), Vector3(81.0, y + 6.24, sz + 0.02), "iron")
		var hx: float = 46.0
		while hx < 81.0:
			_noshadow(B(Vector3(hx - 0.02, y + 6.78, sz - 0.02), Vector3(hx + 0.02, y + 10.0, sz + 0.02), "iron"))
			hx += 6.0
	for lz: float in [75.6, 76.1]:
		B(Vector3(81.25, y, lz - 0.03), Vector3(81.31, y + 6.7, lz + 0.03), "iron")
	var ry: float = y + 0.3
	while ry < y + 5.7:
		B(Vector3(81.25, ry, 75.6), Vector3(81.31, ry + 0.04, 76.1), "iron")
		ry += 0.3
	# ceiling trusses, crane runway on corbels, the gantry crane and its hook
	for tx2: float in [44.0, 50.0, 56.0, 62.0, 68.0, 74.0, 80.0]:
		B(Vector3(tx2 - 0.15, y + 9.4, 60.15), Vector3(tx2 + 0.15, y + 10.0, 81.85), "iron")
		B(Vector3(tx2 - 0.3, y + 9.35, 60.15), Vector3(tx2 + 0.3, y + 9.45, 81.85), "iron")
	for rz: float in [60.6, 81.4]:
		B(Vector3(40.15, y + 7.55, rz - 0.3), Vector3(83.85, y + 7.85, rz + 0.3), "iron")
		var cx: float = 43.0
		while cx < 84.0:
			B(Vector3(cx - 0.3, y + 6.9, rz - 0.4), Vector3(cx + 0.3, y + 7.55, rz + 0.4), "concrete")
			cx += 6.0
	B(Vector3(63.4, y + 7.85, 60.6), Vector3(64.6, y + 8.55, 81.4), "yellow_paint")
	B(Vector3(63.2, y + 8.55, 69.2), Vector3(64.8, y + 9.1, 70.8), "machine_grey")
	_noshadow(B(Vector3(63.96, y + 6.3, 69.96), Vector3(64.04, y + 7.85, 70.04), "iron"))
	B(Vector3(63.7, y + 5.9, 69.8), Vector3(64.3, y + 6.3, 70.2), "yellow_paint")
	Props.strut(dress, Vector3(64.0, y + 5.9, 70.0), Vector3(64.0, y + 5.5, 70.25), 0.08, "iron")
	_label("20 t", Vector3(64.61, y + 8.2, 74.0), 90.0, 40, Color(0.1, 0.08, 0.05, 0.9))
	# north wall: the Hauptschalter's marble panel and the switchboards (gauges and indicator lamps)
	B(Vector3(44.0, y + 0.3, 60.15), Vector3(49.0, y + 3.9, 60.32), "stucco_trim")
	B(Vector3(43.9, y + 3.9, 60.15), Vector3(49.1, y + 4.1, 60.4), "machine_grey")
	_label("HAUPTSCHALTER", Vector3(46.5, y + 3.6, 60.34), 0.0, 46, Color(0.15, 0.1, 0.05, 0.95))
	for gx: float in [44.6, 45.6, 47.4, 48.4]:
		Props.gauge(dress, Vector3(gx, y + 2.9, 60.33), 180.0, 0.2)
	for kx: float in [44.5, 48.5]:
		B(Vector3(kx - 0.25, y + 1.4, 60.32), Vector3(kx + 0.25, y + 2.2, 60.36), "machine_grey")
		Props.strut(dress, Vector3(kx, y + 1.8, 60.38), Vector3(kx, y + 2.15, 60.6), 0.05, "copper")
	for seg: Array in [[54.0, 59.5], [61.0, 66.5], [67.5, 73.5]]:
		var x0: float = float(seg[0])
		var x1: float = float(seg[1])
		B(Vector3(x0, y, 60.15), Vector3(x1, y + 2.5, 60.65), "machine_grey")
		B(Vector3(x0, y + 2.5, 60.15), Vector3(x1, y + 2.6, 60.75), "iron")
		var gxp: float = x0 + 0.5
		while gxp < x1 - 0.3:
			Props.gauge(dress, Vector3(gxp, y + 2.0, 60.66), 180.0, 0.14)
			_noshadow(Props.ball(dress, Vector3(gxp, y + 1.55, 60.66), Vector3(0.07, 0.07, 0.04), "bulb_off"))
			_noshadow(Props.ball(G("G_GENERATOR"), Vector3(gxp, y + 1.55, 60.67), Vector3(0.08, 0.08, 0.05),
				"emergency_red" if int(gxp) % 3 == 0 else "gauge_lit"))
			B(Vector3(gxp - 0.05, y + 1.0, 60.65), Vector3(gxp + 0.05, y + 1.2, 60.72), "black_paint")
			gxp += 0.9
	# big cables from the switch panel up the wall and over to the turbines; a tray along the north wall
	for k3: int in 3:
		var cx2: float = 45.3 + k3 * 0.6
		CYL(Vector3(cx2, y + 7.0, 60.25), 0.07, 6.2, "rubber")
		Props.cable(dress, Vector3(cx2, y + 9.9, 60.3), Vector3(49.0 + k3 * 13.0, y + 9.0, 69.0), 0.9, 0.07)
	B(Vector3(40.15, y + 6.0, 60.15), Vector3(83.85, y + 6.05, 60.55), "iron")
	for k4: int in 4:
		_noshadow(CYL(Vector3(62.0, y + 6.12, 60.25 + k4 * 0.09), 0.04, 43.7, "rubber", Vector3(0, 0, 90)))
	# pipes high on the south wall
	for pp: Array in [[y + 6.6, 0.16, "rust"], [y + 7.0, 0.1, "copper"]]:
		CYL(Vector3(62.0, float(pp[0]), 81.45), float(pp[1]), 43.7, str(pp[2]), Vector3(0, 0, 90))
	var bxp: float = 42.0
	while bxp < 84.0:
		B(Vector3(bxp - 0.05, y + 6.4, 81.3), Vector3(bxp + 0.05, y + 7.15, 81.85), "iron")
		bxp += 4.0
	# workbench corner: tool board over the bench
	B(Vector3(40.19, y + 1.3, 60.4), Vector3(40.24, y + 2.6, 62.6), "planks")
	for tz: float in [60.7, 61.1, 61.5, 61.9, 62.3]:
		Props.obox(dress, Vector3(40.28, y + 1.95, tz), Vector3(0.04, 0.55, 0.05), "iron", Vector3(0, 0, 8))
	B(Vector3(40.3, y + 0.95, 60.3), Vector3(43.0, y + 1.0, 62.0), "steel")
	# the Foreman's corner: desk lamp, papers, a chalk board
	B(Vector3(80.5, y + 0.9, 60.4), Vector3(83.6, y + 0.93, 62.0), "machine_grey")
	B(Vector3(81.0, y + 0.93, 61.3), Vector3(81.5, y + 0.95, 61.8), "paper")
	CYL(Vector3(83.1, y + 1.15, 60.7), 0.03, 0.45, "iron")
	Props.cone(dress, Vector3(83.1, y + 1.4, 60.85), 0.12, 0.15, "enamel_green")
	_noshadow(Props.ball(G("G_GENERATOR"), Vector3(83.1, y + 1.33, 60.85), Vector3(0.08, 0.08, 0.08), "bulb_warm"))
	B(Vector3(83.8, y + 1.2, 63.5), Vector3(83.85, y + 2.6, 66.5), "black_paint")
	_label("SCHICHTPLAN", Vector3(83.78, y + 2.35, 65.0), -90.0, 26, Color(0.8, 0.8, 0.75, 0.7))
	Props.chair(dress, Vector3(82.0, y, 62.6), 180.0)
	# drums and crates in the south-west corner; oil stains
	# (T-239: all of it in the corner west of the vault ramp's blast door (Prop_G_SwDrums). The crate stood 0.5 m in front
	# of the door's west leaf and a drum on its jamb.)
	for dp: Vector3 in [Vector3(41.6, y, 81.45), Vector3(41.6, y, 80.75), Vector3(40.6, y, 80.2), Vector3(41.35, y, 80.0)]:
		Props.oil_drum(dress, dp, "machine_green")
	Props.crate(dress, Vector3(40.68, y, 81.33), 0.9, 3.0)
	# the dais' skirt (DaisSkirt): chequer plate ramps on its three open sides, a painted edge
	var da: Vector3 = Vector3(44.5, y, 60.15)
	var db: Vector3 = Vector3(48.5, y + 0.3, 62.0)
	var sl: float = sqrt(DAIS_SKIRT * DAIS_SKIRT + 0.09)
	var sa: float = rad_to_deg(atan2(0.3, DAIS_SKIRT))
	OB(Vector3((da.x + db.x) * 0.5, y + 0.15, db.z + DAIS_SKIRT * 0.5), Vector3(db.x - da.x, 0.02, sl), "steel_grate", Vector3(sa, 0, 0))
	OB(Vector3(da.x - DAIS_SKIRT * 0.5, y + 0.15, (da.z + db.z) * 0.5), Vector3(sl, 0.02, db.z - da.z), "steel_grate", Vector3(0, 0, sa))
	OB(Vector3(db.x + DAIS_SKIRT * 0.5, y + 0.15, (da.z + db.z) * 0.5), Vector3(sl, 0.02, db.z - da.z), "steel_grate", Vector3(0, 0, -sa))
	for cxs: Array in [[da.x, -1.0], [db.x, 1.0]]:   # the two corner pieces (a hip each)
		var hx: float = float(cxs[0])
		var ho: float = float(cxs[1])
		OB(Vector3(hx + ho * DAIS_SKIRT * 0.5, y + 0.15, db.z + DAIS_SKIRT * 0.5), Vector3(sl, 0.02, sl), "steel_grate", Vector3(sa * 0.72, 0, -ho * sa * 0.72))
	for ed: Array in [[Vector3(da.x, db.y, db.z - 0.04), Vector3(db.x, db.y + 0.005, db.z)], [Vector3(da.x, db.y, da.z), Vector3(da.x + 0.04, db.y + 0.005, db.z)],
			[Vector3(db.x - 0.04, db.y, da.z), Vector3(db.x, db.y + 0.005, db.z)]]:
		_noshadow(B(ed[0], ed[1], "yellow_paint", false))
	# the catwalk's ladder is shut (T-229's rule: a drawn ladder that is no climb gets a chain and a tag)
	Props.ladder_chain(dress, Vector3(81.28, y, 75.85), 90.0)
	# the Foreman's lantern on his desk: the hall's east end had only the red lamps before the power
	_hurricane(Vector3(81.3, y + 0.93, 60.75), 1.2)
	for st: Array in [[Vector3(52.0, y, 70.0), 2.6], [Vector3(64.0, y, 74.5), 1.8], [Vector3(77.0, y, 65.0), 2.2], [Vector3(42.5, y, 79.5), 1.6]]:
		decal(st[0], Vector3(float(st[1]), 1.0, float(st[1]) * 0.7), Color(0.02, 0.02, 0.015, 0.75), float(st[1]) * 40.0)
	# lights: industrial pendants hung from the trusses (powered), emergency lamps
	for lp: Vector3 in [Vector3(50.0, y + 7.2, 64.0), Vector3(62.0, y + 7.2, 64.0), Vector3(74.0, y + 7.2, 64.0),
			Vector3(50.0, y + 7.2, 77.5), Vector3(62.0, y + 7.2, 77.5), Vector3(74.0, y + 7.2, 77.5)]:
		pendant("G_GENERATOR", lp, y + 9.35, "enamel_green", 1.7, "sodium")
	power("G_GENERATOR", Vector3(50.0, y + 6.9, 64.0), 16.0, 2.0, SODIUM, false, {}, 0.5)
	power("G_GENERATOR", Vector3(74.0, y + 6.9, 64.0), 16.0, 2.0, SODIUM, false, {}, 0.5)
	power("G_GENERATOR", Vector3(50.0, y + 6.9, 77.5), 16.0, 1.8, SODIUM, false, {}, 0.5)
	power("G_GENERATOR", Vector3(74.0, y + 6.9, 77.5), 16.0, 1.8, SODIUM, false, {}, 0.5)
	power("G_GENERATOR", Vector3(62.0, y + 6.9, 70.0), 14.0, 1.6, SODIUM, false, {}, 0.5)
	emergency(Vector3(42.5, y + 2.8, 60.33), 180.0, 1.0, 10.0)
	emergency(Vector3(83.83, y + 2.8, 78.0), 90.0, 0.8, 10.0)


func _dress_lab() -> void:
	var y: float = DY
	# the Generator wall seen from the lab's north rooms: cream paint over tiles
	for r: Array in [[52.0, 59.0, y, y + 3.5], [59.0, 61.0, y + DOOR_H, y + 3.5], [61.0, 84.0, y, y + 3.5]]:
		_line(true, 82.0, 1, r, y, [1, "paint_cream", 0.0, 0.012])
		_line(true, 82.0, 1, r, y, [1, "tile_wall", 1.6, 0.025])
	# skirting and a dado rail along the tiles (hall)
	# (T-239: the rail stops at the six doorways; it ran across every one of them as a bar at eye height)
	for hz: Array in [[88.15, 1], [91.85, -1]]:
		for hx: Array in [[52.15, 60.0 - DW * 0.5 - 0.14], [60.0 + DW * 0.5 + 0.14, 76.0 - DW * 0.5 - 0.14], [76.0 + DW * 0.5 + 0.14, 93.0 - DW * 0.5 - 0.14],
				[93.0 + DW * 0.5 + 0.14, 101.85]]:
			B(Vector3(float(hx[0]), y + 1.6, float(hz[0])), Vector3(float(hx[1]), y + 1.66, float(hz[0]) + float(hz[1]) * 0.05), "enamel_green")
	# specimen tanks
	var ti: int = 0
	for tz: Array in [[53.5, 84.0], [53.5, 86.5], [66.5, 84.0]]:
		var c: Vector3 = Vector3(float(tz[0]), y, float(tz[1]))
		CYL(c + Vector3(0, 0.18, 0), 0.98, 0.36, "machine_grey")
		CYL(c + Vector3(0, 2.45, 0), 0.98, 0.3, "machine_grey")
		_noshadow(CYL(c + Vector3(0, 1.38, 0), 0.92, 1.8, "glass"))
		_noshadow(CYL(c + Vector3(0, 1.22, 0), 0.86, 1.6, "nachtglas_liquid"))
		for k: int in 4:
			var a: float = TAU * float(k) / 4.0 + 0.4
			B(c + Vector3(cos(a) * 0.95 - 0.03, 0.36, sin(a) * 0.95 - 0.03), c + Vector3(cos(a) * 0.95 + 0.03, 2.3, sin(a) * 0.95 + 0.03), "iron")
		Props.ball(dress, c + Vector3(0.1, 1.3, 0.05), Vector3(0.45, 0.6, 0.4), "black_paint")
		Props.ball(dress, c + Vector3(0.05, 1.75, 0.0), Vector3(0.26, 0.3, 0.26), "black_paint")
		for px: float in [-0.5, 0.5]:
			CYL(c + Vector3(px, 3.05, 0), 0.06, 0.9, "copper")
		Props.gauge(dress, c + Vector3(0.0, 0.2, 0.98), 180.0, 0.08)
		_bubbles(c + Vector3(0, 0.5, 0), 0.6)
		# the tanks' glow stays close to the glass (deep violet bleeding onto the tiles), not a room-wide wash (T-062)
		lamp(c + Vector3(0, 1.5, 0), Color(0.58, 0.22, 1.0), 1.5, 6.0, 0.08, 0.2, false, 2.0)
		ti += 1
	# specimen room: cabinet on the generator wall, a gurney, instrument trolley
	Props.cabinet(dress, Vector3(64.0, y, 82.45), 180.0, 2.4, 2.1, 0.45)
	# (T-239: the gurney against the hall wall east of the door, the trolley against the generator wall (Prop_H_Gurney1,
	# Prop_H_Trolley1); both stood loose in the room between its two doors and nobody collided with either)
	Props.gurney(dress, Vector3(63.3, y, 87.45), 90.0, true)
	_trolley(Vector3(56.5, y, 82.5))
	# a crate of specimen jars left in the hall's west end on the way to the cold store: their violet is the
	# corridor's cool light before the power (T-062 second pass)
	Props.crate(dress, Vector3(52.6, y, 91.4), 0.8, 4.0)
	for jx: Array in [[52.4, 91.25], [52.8, 91.55], [52.7, 91.15]]:
		_noshadow(CYL(Vector3(float(jx[0]), y + 0.95, float(jx[1])), 0.11, 0.3, "glass"))
		_noshadow(CYL(Vector3(float(jx[0]), y + 0.92, float(jx[1])), 0.09, 0.22, "nachtglas_liquid"))
	lamp(Vector3(53.2, y + 1.3, 91.0), Color(0.58, 0.22, 1.0), 1.2, 9.0, 0.08, 0.2, false, 2.0)
	_hurricane(Vector3(56.3, y + 0.83, 82.42), 0.9)
	# Fasbender's laboratory: bench top and glassware, operating table under the big lamp
	B(Vector3(69.95, y + 0.95, 82.35), Vector3(74.05, y + 1.02, 83.65), "enamel_white")
	Props.bottles(dress, Vector3(70.3, y + 1.02, 82.8), Vector3(73.7, y + 1.02, 82.8), 12, 21)
	Props.cabinet(dress, Vector3(83.4, y, 85.0), 90.0, 2.4, 2.1, 0.45)
	# (T-239: the operating table is a table: a top on a pedestal with a foot plate, a crank and a head rest, its instrument
	# trolley at its head (Prop_H_OpTable, one block). It was a steel box under a sheet, 1.5 m from the cabinet; it stands
	# half a metre west so the way round it is 2 m.)
	B(Vector3(79.5, y, 85.2), Vector3(80.5, y + 0.05, 85.8), "steel")
	CYL(Vector3(80.0, y + 0.42, 85.5), 0.14, 0.74, "steel")
	CYL(Vector3(80.0, y + 0.74, 85.5), 0.2, 0.1, "machine_grey")
	B(Vector3(79.0, y + 0.79, 85.05), Vector3(81.0, y + 0.85, 85.95), "steel")
	B(Vector3(78.95, y + 0.85, 84.95), Vector3(81.05, y + 0.92, 86.05), "enamel_white")
	B(Vector3(79.1, y + 0.92, 85.0), Vector3(80.95, y + 0.97, 86.0), "linen")
	for dz: float in [84.94, 86.04]:   # the sheet hangs down both long sides
		B(Vector3(79.0, y + 0.3, dz), Vector3(81.0, y + 0.93, dz + 0.02), "linen")
	B(Vector3(78.94, y + 0.3, 84.95), Vector3(78.96, y + 0.93, 86.05), "linen")
	B(Vector3(80.75, y + 0.97, 85.3), Vector3(81.0, y + 1.05, 85.7), "leather")
	Props.strut(dress, Vector3(80.0, y + 0.6, 85.5), Vector3(80.0, y + 0.6, 85.05), 0.03, "steel", true)
	CYL(Vector3(80.0, y + 0.6, 85.02), 0.07, 0.03, "black_paint", Vector3(90, 0, 0))
	_noshadow(B(Vector3(79.7, y + 0.97, 85.2), Vector3(80.1, y + 0.975, 85.5), "cloth_red", false))
	CYL(Vector3(80.0, y + 3.05, 85.5), 0.03, 0.9, "iron")
	Props.cone(dress, Vector3(80.0, y + 2.5, 85.5), 0.55, 0.3, "enamel_white")
	_noshadow(CYL(Vector3(80.0, y + 2.34, 85.5), 0.38, 0.03, "bulb_off"))
	_noshadow(Props.cyl(G("H_LAB"), Vector3(80.0, y + 2.33, 85.5), 0.4, 0.035, "bulb_warm"))
	_trolley(Vector3(78.5, y, 85.5))
	Props.chair(dress, Vector3(72.0, y, 83.9), 180.0)
	# nursery: iron crib with bars, a small chair, toy blocks, a frieze above the tiles
	# (T-239: a child's cot against the wall, 2.0 x 1.1 m (NurseryBed): the bars stood round a 3.9 x 2.4 m platform, a cage
	# in the middle of the room; a folded blanket and a small pillow on it)
	B(Vector3(87.05, y + 0.32, 82.35), Vector3(88.95, y + 0.42, 83.35), "steel")
	B(Vector3(87.1, y + 0.42, 82.4), Vector3(88.9, y + 0.56, 83.3), "linen")
	B(Vector3(87.9, y + 0.56, 82.42), Vector3(88.88, y + 0.6, 83.28), "cloth_red")
	B(Vector3(87.14, y + 0.56, 82.55), Vector3(87.5, y + 0.64, 83.15), "linen")
	for e: Array in [[Vector3(87.05, y, 82.35), Vector3(88.95, y, 82.35)], [Vector3(87.05, y, 83.35), Vector3(88.95, y, 83.35)],
			[Vector3(87.05, y, 82.35), Vector3(87.05, y, 83.35)], [Vector3(88.95, y, 82.35), Vector3(88.95, y, 83.35)]]:
		var n: int = int((e[0] as Vector3).distance_to(e[1]) / 0.18)
		for k2: int in n + 1:
			var p: Vector3 = (e[0] as Vector3).lerp(e[1], float(k2) / float(n))
			B(p + Vector3(-0.012, 0, -0.012), p + Vector3(0.012, 1.0, 0.012), "steel")
		B((e[0] as Vector3) + Vector3(-0.02, 0.98, -0.02), (e[1] as Vector3) + Vector3(0.02, 1.03, 0.02), "steel")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 91
	for k3: int in 7:
		var bp: Vector3 = Vector3(92.5 + rng.randf() * 3.0, y, 85.5 + rng.randf() * 1.8)
		Props.obox(dress, bp + Vector3(0, 0.06, 0), Vector3(0.12, 0.12, 0.12), ["red_paint", "shutter_green", "yellow_paint", "linen"][k3 % 4],
			Vector3(0, rng.randf() * 90.0, 0))
	Props.chair(dress, Vector3(97.5, y, 84.0), -30.0)
	var fx: float = 84.3
	while fx < 101.7:
		if fx > 91.9 and fx < 93.9:
			fx += 0.4
			continue
		B(Vector3(fx, y + 1.7, 82.17), Vector3(fx + 0.25, y + 1.85, 82.19), ["red_paint", "shutter_green", "yellow_paint"][int(fx * 4.0) % 3])
		fx += 0.4
	_noshadow(B(Vector3(87.985, y + 1.75, 82.835), Vector3(88.015, y + 3.5, 82.865), "iron"))   # the mobile over the cot
	for mk: int in 4:
		var ma: float = TAU * float(mk) / 4.0
		Props.strut(dress, Vector3(88.0, y + 1.76, 82.85), Vector3(88.0 + cos(ma) * 0.3, y + 1.72, 82.85 + sin(ma) * 0.3), 0.01, "iron", true)
		_noshadow(Props.ball(dress, Vector3(88.0 + cos(ma) * 0.3, y + 1.62, 82.85 + sin(ma) * 0.3), Vector3(0.1, 0.1, 0.1), "linen"))
	# hall: room signs over the doors, benches
	var signs: Array = [[60.0, 88.0, "PRÄPARATE"], [76.0, 88.0, "LABOR · DR. F."], [93.0, 88.0, "KINDERSTATION"],
		[60.0, 92.0, "RESONANZ"], [76.0, 92.0, "AUFNAHME"], [93.0, 92.0, "KÜHLRAUM"]]
	for sg: Array in signs:
		var face: float = float(sg[1]) + (0.17 if float(sg[1]) < 90.0 else -0.17)
		B(Vector3(float(sg[0]) - 0.8, y + 2.55, face - 0.02), Vector3(float(sg[0]) + 0.8, y + 2.85, face + 0.02), "enamel_white")
		_label(str(sg[2]), Vector3(float(sg[0]), y + 2.7, face + (0.03 if float(sg[1]) < 90.0 else -0.03)), 0.0 if float(sg[1]) < 90.0 else 180.0,
			24, Color(0.1, 0.1, 0.1, 0.95))
	for bx: float in [66.0, 86.5]:
		Props.bench(dress, Vector3(bx, y, 91.6), 0.0, 2.2)
	# resonance room: copper coils on the west wall, cables to the pylon
	for cz: float in [93.5, 96.0]:
		B(Vector3(52.2, y, cz - 0.4), Vector3(52.9, y + 0.4, cz + 0.4), "machine_grey")
		for k4: int in 9:
			CYL(Vector3(52.55, y + 0.5 + k4 * 0.18, cz), 0.32, 0.08, "copper")
		_noshadow(CYL(Vector3(52.55, y + 1.3, cz), 0.12, 1.6, "nachtglas_dim"))
		Props.cable(dress, Vector3(52.9, y + 0.2, cz), Vector3(59.5, y + 0.05, 95.0), 0.0, 0.04, 6)
	# intake: typewriter, papers and tags on the board, waiting bench
	B(Vector3(70.2, y + 0.9, 93.1), Vector3(70.9, y + 1.05, 93.6), "black_paint")
	B(Vector3(71.8, y + 0.9, 94.0), Vector3(72.3, y + 0.92, 94.4), "paper")
	for k5: int in 26:
		var px2: float = 77.8 + rng.randf() * 5.4
		var py: float = y + 1.15 + rng.randf() * 1.45
		if absf(px2 - 80.0) < 0.35 and absf(py - (y + 1.4)) < 0.3:
			continue
		Props.obox(dress, Vector3(px2, py, 97.58), Vector3(0.2, 0.26, 0.01), "paper", Vector3(0, 0, rng.randf_range(-8, 8)))
	B(Vector3(77.4, y + 0.95, 97.55), Vector3(83.6, y + 1.0, 97.85), "furniture")
	B(Vector3(77.4, y + 2.8, 97.55), Vector3(83.6, y + 2.85, 97.85), "furniture")
	Props.bench(dress, Vector3(68.38, y, 95.5), 90.0, 2.8)   # (T-239: against the wall, Prop_H_IntakeBench)
	Props.chair(dress, Vector3(71.2, y, 92.4), 0.0)
	# cold store: drawer fronts with handles, refrigeration pipe (a bell can hang from it), sheeted gurneys
	for dz: int in 3:
		for dyy: int in 3:
			var zc: float = 93.6 + dz * 1.33
			var yc: float = y + 0.45 + dyy * 0.8
			B(Vector3(88.5, yc - 0.33, zc - 0.58), Vector3(88.53, yc + 0.33, zc + 0.58), "steel")
			B(Vector3(88.53, yc - 0.03, zc - 0.25), Vector3(88.58, yc + 0.03, zc + 0.25), "brass")
	CYL(Vector3(93.0, y + 3.3, 96.5), 0.09, 17.6, "steel", Vector3(0, 0, 90))
	_noshadow(CYL(Vector3(97.5, y + 3.3, 96.5), 0.11, 6.0, "salt_crystal", Vector3(0, 0, 90)))
	CYL(Vector3(93.0, y + 3.1, 97.0), 0.06, 17.6, "copper", Vector3(0, 0, 90))
	# (T-239: both gurneys in a row along the south wall (Prop_H_Gurney2 / 3); one stood across the middle of the room)
	Props.gurney(dress, Vector3(93.5, y, 97.45), 90.0, true)
	Props.gurney(dress, Vector3(98.9, y, 97.45), 90.0, true)
	B(Vector3(100.9, y, 92.4), Vector3(101.85, y + 2.0, 93.6), "machine_grey")
	# stains
	for st: Array in [[Vector3(80.0, y, 86.4), 1.2], [Vector3(93.6, y, 96.4), 1.6], [Vector3(62.0, y, 90.0), 1.0], [Vector3(55.0, y, 84.7), 1.4]]:
		decal(st[0], Vector3(float(st[1]), 0.8, float(st[1]) * 0.8), Color(0.18, 0.03, 0.02, 0.55), float(st[1]) * 70.0)
	# lights (powered): a pendant per room and three in the hall
	var lamps: Array = [[Vector3(60.0, y + 2.75, 85.0), 8.0], [Vector3(76.0, y + 2.75, 84.6), 8.0], [Vector3(93.0, y + 2.75, 85.2), 8.0],
		[Vector3(57.0, y + 2.75, 90.0), 0.0], [Vector3(76.0, y + 2.75, 90.0), 9.0], [Vector3(95.0, y + 2.75, 90.0), 8.0],
		[Vector3(60.0, y + 2.75, 95.0), 8.0], [Vector3(76.0, y + 2.75, 95.0), 8.0], [Vector3(93.0, y + 2.75, 95.0), 8.0]]
	for lp: Array in lamps:
		pendant("H_LAB", lp[0], y + 3.5, "enamel_white")
		if float(lp[1]) > 0.0:
			power("H_LAB", (lp[0] as Vector3) + Vector3(0, -0.2, 0), float(lp[1]), 1.15, LAB_LAMP, false, {}, 0.3)
	power("H_LAB", Vector3(80.0, y + 2.1, 85.5), 5.0, 1.0, Color(0.95, 0.95, 1.0))
	emergency(Vector3(68.0, y + 2.75, 88.17), 180.0, 0.8, 9.0)
	emergency(Vector3(86.0, y + 2.75, 91.83), 0.0, 0.6, 8.0)


func _trolley(p: Vector3) -> void:
	B(p + Vector3(-0.35, 0.8, -0.25), p + Vector3(0.35, 0.83, 0.25), "steel")
	B(p + Vector3(-0.35, 0.3, -0.25), p + Vector3(0.35, 0.33, 0.25), "steel")
	for c: Vector2 in [Vector2(-0.32, -0.22), Vector2(0.32, -0.22), Vector2(-0.32, 0.22), Vector2(0.32, 0.22)]:
		B(p + Vector3(c.x - 0.015, 0.05, c.y - 0.015), p + Vector3(c.x + 0.015, 0.83, c.y + 0.015), "steel")
	for k: int in 4:
		Props.obox(dress, p + Vector3(-0.2 + k * 0.13, 0.84, 0.0), Vector3(0.02, 0.01, 0.18), "steel", Vector3(0, k * 10.0, 0))
	CYL(p + Vector3(0.22, 0.9, 0.1), 0.05, 0.14, "bottle_amber")


func _bubbles(pos: Vector3, extent: float) -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Bubbles"
	p.position = pos
	p.amount = 14
	p.lifetime = 2.4
	p.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 3, 2))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extent * 0.5, 0.05, extent * 0.5)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 5.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.1, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = Props._particle_mat(Color(0.8, 0.6, 1.0), Color(0.6, 0.3, 1.0), 2.0, true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dress.add_child(p)


func _dress_core() -> void:
	var y: float = CY
	# pillars: iron bands
	for c: Vector2 in [Vector2(23, 105), Vector2(45, 105), Vector2(23, 127), Vector2(45, 127)]:
		for by: float in [y + 0.5, y + 6.0, y + 11.2]:
			B(Vector3(c.x - 1.06, by, c.y - 1.06), Vector3(c.x + 1.06, by + 0.3, c.y + 1.06), "iron")
	# the pit: a black void with glowing cracks inside a riveted rim, railing on top
	_noshadow(B(Vector3(29.35, y + 1.1, 111.35), Vector3(38.65, y + 1.115, 120.65), "black_paint", false))
	for e: Array in [[Vector3(29.0, y, 110.95), Vector3(39.0, y, 110.95)], [Vector3(29.0, y, 121.05), Vector3(39.0, y, 121.05)],
			[Vector3(28.95, y, 111.0), Vector3(28.95, y, 121.0)], [Vector3(39.05, y, 111.0), Vector3(39.05, y, 121.0)]]:
		var n: int = int((e[0] as Vector3).distance_to(e[1]) / 0.5)
		for k2: int in n + 1:
			var rp: Vector3 = (e[0] as Vector3).lerp(e[1], float(k2) / float(n))
			_noshadow(B(rp + Vector3(-0.03, 0.22, -0.03), rp + Vector3(0.03, 0.28, 0.03), "steel"))
			_noshadow(B(rp + Vector3(-0.03, 0.82, -0.03), rp + Vector3(0.03, 0.88, 0.03), "steel"))
		B((e[0] as Vector3) + Vector3(-0.03, 0.4, -0.03), (e[1] as Vector3) + Vector3(0.03, 0.7, 0.03), "yellow_paint")
	for rc: Vector2 in [Vector2(29.2, 111.2), Vector2(38.8, 111.2), Vector2(29.2, 120.8), Vector2(38.8, 120.8), Vector2(34.0, 111.2),
			Vector2(34.0, 120.8), Vector2(29.2, 116.0), Vector2(38.8, 116.0)]:
		B(Vector3(rc.x - 0.04, y + 1.1, rc.y - 0.04), Vector3(rc.x + 0.04, y + 2.05, rc.y + 0.04), "iron")
	for e2: Array in [[Vector3(29.2, y + 2.05, 111.2), Vector3(38.8, y + 2.05, 111.2)], [Vector3(29.2, y + 2.05, 120.8), Vector3(38.8, y + 2.05, 120.8)],
			[Vector3(29.2, y + 2.05, 111.2), Vector3(29.2, y + 2.05, 120.8)], [Vector3(38.8, y + 2.05, 111.2), Vector3(38.8, y + 2.05, 120.8)]]:
		Props.strut(dress, e2[0], e2[1], 0.06, "iron")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1945
	for k3: int in 14:
		var a3: float = TAU * float(k3) / 14.0 + rng.randf_range(-0.1, 0.1)
		var start: Vector3 = Vector3(34.0 + cos(a3) * 1.0, y + 1.12, 116.0 + sin(a3) * 1.0)
		_vein(start, Vector3(cos(a3), 0, sin(a3)), 3.6, rng, y + 1.12, Rect2(29.4, 111.4, 9.2, 9.2), 0, _amber_vein())
	for k4: int in 6:
		var a4: float = TAU * float(k4) / 6.0 + 0.3
		Props.crystal_cluster(dress, Vector3(34.0 + cos(a4) * 3.0, y + 1.1, 116.0 + sin(a4) * 3.0), 700 + k4, 1.6, "nachtglas_crystal")
	# floor veins: from the pit out across the vault, one leading to the Crucible
	for k5: int in 16:
		var a5: float = TAU * float(k5) / 16.0 + rng.randf_range(-0.12, 0.12)
		var st: Vector3 = Vector3(34.0 + cos(a5) * 5.4, y + 0.004, 116.0 + sin(a5) * 5.4)
		_vein(st, Vector3(cos(a5), 0, sin(a5)), rng.randf_range(3.0, 7.0), rng, y + 0.004, Rect2(19.4, 101.4, 29.2, 29.2), 0,
			_amber_vein() if k5 % 3 == 0 else null)
	_vein(Vector3(39.2, y + 0.004, 118.0), Vector3(1.0, 0, 0.8).normalized(), 7.5, rng, y + 0.004, Rect2(19.4, 101.4, 29.2, 29.2))
	# the heart: a crystal mass in an iron cage, hung on chains (lives under Geometry/Heart)
	var heart: Node3D = geo.get_node("Heart") as Node3D
	var core: Node3D = spinner(heart, "HeartCrystals", Vector3.ZERO, Vector3.UP, 0.18, false)
	Props.crystal_cluster(core, Vector3(0, -1.6, 0), 4471, 3.6, "nachtglas_crystal")
	Props.crystal_cluster(core, Vector3(0, 1.4, 0), 4472, 2.6, "nachtglas_crystal", Vector3.DOWN)
	Props.ball(core, Vector3.ZERO, Vector3(2.2, 3.0, 2.2), "nachtglas_crystal")
	for k6: int in 8:
		var a6: float = TAU * float(k6) / 8.0
		var prev: Vector3 = Vector3(0, 3.0, 0)
		for s: int in 8:
			var t: float = float(s + 1) / 8.0
			var ang: float = PI * t
			var rr: float = sin(ang) * 2.6
			var p6: Vector3 = Vector3(cos(a6) * rr, cos(ang) * 3.0, sin(a6) * rr)
			Props.strut(heart, prev, p6, 0.14, "iron")
			prev = p6
	for ry: float in [-1.5, 0.0, 1.5]:
		var rr2: float = sqrt(maxf(0.0, 1.0 - (ry / 3.0) * (ry / 3.0))) * 2.6
		var prev2: Vector3 = Vector3(rr2, ry, 0)
		for k7: int in 16:
			var a7: float = TAU * float(k7 + 1) / 16.0
			var p7: Vector3 = Vector3(cos(a7) * rr2, ry, sin(a7) * rr2)
			Props.strut(heart, prev2, p7, 0.12, "iron")
			prev2 = p7
	for ch: Vector2 in [Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(-1.2, 1.2), Vector2(1.2, 1.2)]:
		_noshadow(Props.strut(dress, Vector3(34.0 + ch.x * 0.4, y + 10.0, 116.0 + ch.y * 0.4), Vector3(34.0 + ch.x * 3.0, y + 12.0, 116.0 + ch.y * 3.0), 0.08, "iron"))
	_heart_cracks(core)
	_core_crystals(heart)
	_bake_local(heart, true)
	_bake_local(core, false)
	# crystal formations: wall feet and hanging from the roof
	# (T-239: they grow at the wall feet, at most a body's width into the room: sized 1.2 to 2.4 they leaned up to 1.4 m
	# into the ring the squad runs round the pit, two of them stood free beside the pillars (one filled the view between
	# the south-east pillar and the installers' bench), and nobody collided with any. The two by the pillars are on the
	# west and south walls.)
	var walls: Array = [Vector3(26.5, y, 101.45), Vector3(31.0, y, 101.45), Vector3(38.0, y, 101.45), Vector3(48.55, y, 108.5),
		Vector3(48.55, y, 120.0), Vector3(22.5, y, 130.55), Vector3(40.5, y, 130.55), Vector3(27.5, y, 130.55), Vector3(19.45, y, 128.5),
		Vector3(19.45, y, 116.5), Vector3(19.45, y, 106.0), Vector3(19.45, y, 111.5), Vector3(44.8, y, 130.55)]
	var wi: int = 0
	for wp: Vector3 in walls:
		Props.crystal_cluster(dress, wp, 800 + wi, rng.randf_range(0.8, 1.25), "nachtglas_crystal" if wi % 3 != 1 else "nachtglas_dim")
		# the bright clusters bleed violet into the rock round them (T-062)
		if wi % 3 != 1 and wi % 2 == 0:
			var inward: Vector3 = (Vector3(34.0, y, 116.0) - wp).normalized()
			lamp(wp + inward * 0.8 + Vector3(0, 1.0, 0), Color(0.66, 0.22, 1.0), 0.7, 6.5, 0.12, 0.3, false, 1.3)
		wi += 1
	for cp: Vector3 in [Vector3(27, y + 12, 108), Vector3(41, y + 12, 108), Vector3(27, y + 12, 124), Vector3(41, y + 12, 124),
			Vector3(34, y + 12, 104), Vector3(22, y + 12, 117), Vector3(46, y + 12, 112)]:
		Props.crystal_cluster(dress, cp, 900 + wi, rng.randf_range(1.0, 1.8), "nachtglas_dim", Vector3.DOWN)
		wi += 1
	# the Crucible's setting: a riveted back plate, iron columns, a crystal crown, pipes to the heart
	B(Vector3(48.6, y, 121.4), Vector3(48.85, y + 5.2, 126.6), "machine_grey")
	for bz: float in [121.6, 126.4]:
		B(Vector3(47.9, y, bz - 0.3), Vector3(48.6, y + 4.6, bz + 0.3), "iron")
	B(Vector3(47.8, y + 4.6, 121.2), Vector3(48.7, y + 5.1, 126.8), "iron")
	for rv: int in 9:
		for rh: int in 2:
			var rvp: Vector3 = Vector3(48.58, y + 0.5 + rv * 0.52, 122.4 + rh * 3.2)
			_noshadow(B(rvp - Vector3(0.04, 0.04, 0.04), rvp + Vector3(0.04, 0.04, 0.04), "steel"))
	Props.crystal_cluster(dress, Vector3(48.2, y + 5.1, 124.0), 1001, 1.6, "nachtglas_crystal")
	_core_crystals(dress)
	CYL(Vector3(46.4, y + 7.9, 124.0), 0.14, 7.6, "copper")
	Props.cable(dress, Vector3(46.4, y + 11.6, 124.0), Vector3(36.5, y + 11.0, 117.5), 0.6, 0.09, 10, "copper")
	Props.cable(dress, Vector3(46.0, y + 11.4, 123.6), Vector3(36.0, y + 10.6, 117.0), 1.0, 0.06, 10)
	_noshadow(CYL(Vector3(43.8, y + 0.008, 124.0), 1.3, 0.016, "steel_grate"))
	_noshadow(CYL(Vector3(43.8, y + 0.012, 124.0), 1.0, 0.016, "nachtglas_dim"))
	lamp(Vector3(44.6, y + 1.4, 124.0), Color(1.0, 0.55, 0.25), 0.9, 6.0, 0.25)
	# the Ledger: archive drawers, a lectern with the book, shelves of ledgers
	for dz: int in 10:
		for dy: int in 4:
			B(Vector3(29.1 + dz * 1.0, y + 0.15 + dy * 0.62, 137.47), Vector3(29.95 + dz * 1.0, y + 0.7 + dy * 0.62, 137.5), "machine_green")
			B(Vector3(29.4 + dz * 1.0, y + 0.4 + dy * 0.62, 137.44), Vector3(29.65 + dz * 1.0, y + 0.45 + dy * 0.62, 137.47), "brass")
	# (T-239: the lectern stands in front of the drawers (Prop_I_Lectern), a turned post on a foot under its desk)
	B(Vector3(33.65, y, 136.8), Vector3(34.35, y + 0.08, 137.45), "furniture")
	B(Vector3(33.85, y + 0.08, 136.98), Vector3(34.15, y + 0.95, 137.28), "furniture")
	B(Vector3(33.7, y + 0.95, 136.85), Vector3(34.3, y + 1.0, 137.42), "furniture")
	OB(Vector3(34.0, y + 1.1, 137.1), Vector3(0.9, 0.08, 0.7), "furniture", Vector3(-20, 0, 0))
	OB(Vector3(34.0, y + 1.18, 137.1), Vector3(0.8, 0.06, 0.6), "paper", Vector3(-20, 0, 0))
	for sx: float in [28.17, 39.83]:
		for sy: float in [0.6, 1.3, 2.0, 2.7]:
			B(Vector3(minf(sx, sx + signf(34.0 - sx) * 0.4), y + sy, 132.0), Vector3(maxf(sx, sx + signf(34.0 - sx) * 0.4), y + sy + 0.04, 136.5), "beam")
			B(Vector3(minf(sx, sx + signf(34.0 - sx) * 0.35), y + sy + 0.04, 132.1), Vector3(maxf(sx, sx + signf(34.0 - sx) * 0.35), y + sy + 0.42, 136.4),
				"cloth_red" if sy < 1.5 else "furniture")
	pendant("I_CORE", Vector3(34.0, y + 3.9, 134.5), y + 5.0, "enamel_green")
	power("I_CORE", Vector3(34.0, y + 3.7, 134.5), 9.0, 1.2, INCAND)
	# power: the vault's violet floods come on with the sweep
	power("I_CORE", Vector3(34.0, y + 9.0, 116.0), 30.0, 2.4, Color(0.62, 0.26, 1.0), false, {}, 1.0)
	power("I_CORE", Vector3(44.0, y + 4.0, 124.0), 8.0, 1.2, Color(1.0, 0.6, 0.35))
	_dress_core_installers(y)


## T-226 (the owner: "the pack a punch area in map 2 needs work, more details and a perk machine down there"): the Core
## Vault's working detail round the Crucible and Skyhook's cabinet. The installers' corner on the east wall south of the
## Crucible's setting (CORE_PROPS colliders): the bench with its vice, a gauge and the tool board, the crates of retained
## items, a hose coil; oil drums in the north-east corner, the cable drum by the G ramp door; the resonance instruments:
## four brass gauge stands on the pit rim, cabled up to the cage; the conduit from the F ramp door along the north wall
## past the junction box over the cabinet and on down the east wall to the Crucible's plate; caged lamps on the four
## pillars and over the cabinet (power) and a red emergency lamp at each of the four doors (always on); a jib crane on
## the east wall with its chain and hook over the Crucible's apron; salt crust and puddles at the wall feet; and
## luminous-paint guide lines on the floor from every door round the pit to the Crucible (_dress_core_guides).
func _dress_core_installers(y: float) -> void:
	Props.workbench(dress, Vector3(48.5, y, 128.5), 90.0, 1.8, 0.7)
	B(Vector3(48.7, y + 1.3, 127.7), Vector3(48.84, y + 2.2, 129.3), "planks")
	for tz: float in [127.9, 128.25, 128.6, 128.95, 129.2]:
		Props.strut(dress, Vector3(48.66, y + 1.4, tz), Vector3(48.66, y + 2.05, tz), 0.03, "iron", true)
	B(Vector3(48.55, y + 2.1, 127.8), Vector3(48.7, y + 2.15, 129.2), "iron")
	B(Vector3(48.25, y + 0.95, 127.75), Vector3(48.55, y + 1.2, 128.0), "iron")
	Props.gauge(dress, Vector3(48.6, y + 1.05, 128.8), 90.0, 0.1)
	Props.crate(dress, Vector3(45.5, y, 125.66), 0.66, 2.0, "R-E 7")   # (T-239, Prop_I_CrucibleGap: between the Crucible and the pillar)
	Props.crate(dress, Vector3(45.52, y + 0.66, 125.66), 0.6, -6.0)
	Props.crate(dress, Vector3(48.3, y, 130.15), 0.95, 4.0, "R-E 7")
	Props.crate(dress, Vector3(48.35, y + 0.95, 130.1), 0.6, -12.0, "RETAINED")
	Props.rope_coil(dress, Vector3(47.5, y, 130.55), 0.3)
	Props.oil_drum(dress, Vector3(48.35, y, 105.75), "rust")
	Props.oil_drum(dress, Vector3(48.35, y, 106.55), "machine_grey")
	CYL(Vector3(40.65, y + 0.6, 101.95), 0.6, 0.5, "beam", Vector3(90, 0, 0))
	CYL(Vector3(40.65, y + 0.6, 101.95), 0.46, 0.44, "rubber", Vector3(90, 0, 0))
	# the resonance instruments on the pit rim
	for gp: Vector2 in [Vector2(31.5, 111.2), Vector2(36.5, 111.2), Vector2(31.5, 120.8), Vector2(36.5, 120.8)]:
		var base: Vector3 = Vector3(gp.x, y + 1.1, gp.y)
		for k: int in 3:
			var a: float = TAU * float(k) / 3.0
			Props.strut(dress, base + Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), base + Vector3(0, 1.0, 0), 0.03, "iron", true)
		CYL(base + Vector3(0, 1.05, 0), 0.08, 0.1, "brass")
		Props.gauge(dress, base + Vector3(0, 1.25, 0), 0.0 if gp.y < 116.0 else 180.0, 0.13)
		var toward: Vector3 = (Vector3(gp.x, 0, gp.y) - Vector3(34.0, 0, 116.0)).normalized()
		Props.cable(dress, base + Vector3(0, 1.3, 0), Vector3(34.0, y + 8.0, 116.0) + toward * 2.6, 0.5, 0.025, 8, "rubber")
	# conduit: the north wall from the F ramp door to the east wall (over the G ramp door), the junction box over Skyhook's
	# cabinet, then down the east wall to the Crucible's plate
	Props.pipe(dress, Vector3(22.2, y + 2.8, 101.3), Vector3(48.7, y + 2.8, 101.3), 0.04, "iron")
	Props.pipe(dress, Vector3(48.7, y + 2.8, 101.3), Vector3(48.7, y + 2.8, 121.0), 0.04, "iron")
	Props.pipe(dress, Vector3(48.7, y + 2.8, 121.0), Vector3(48.7, y + 4.8, 121.35), 0.04, "iron")
	Props.fuse_box(dress, Vector3(36.2, y + 2.2, 101.16), 180.0, 0.45, 0.6)
	Props.pipe(dress, Vector3(36.2, y + 2.5, 101.3), Vector3(36.2, y + 2.8, 101.3), 0.03, "iron")
	Props.pipe(dress, Vector3(36.0, y + 2.2, 101.4), Vector3(34.9, y + 2.42, 101.5), 0.03, "iron")
	# caged lamps on the pillars and over the cabinet (power), red lamps at the four doors (always on)
	for bl: Array in [[Vector3(24.02, y + 2.5, 105.0), -90.0], [Vector3(43.98, y + 2.5, 105.0), 90.0], [Vector3(24.02, y + 2.5, 127.0), -90.0],
			[Vector3(43.98, y + 2.5, 127.0), 90.0], [Vector3(34.5, y + 2.75, 101.17), 180.0]]:
		bulkhead("I_CORE", bl[0], float(bl[1]))
		var o: Vector3 = Basis(Vector3.UP, deg_to_rad(float(bl[1]))) * Vector3(0, 0, -0.3)
		power("I_CORE", (bl[0] as Vector3) + o, 7.0, 1.0, INCAND)
	emergency(Vector3(23.4, y + 2.7, 101.4), 180.0)
	emergency(Vector3(41.2, y + 2.7, 101.4), 180.0)
	emergency(Vector3(48.6, y + 2.7, 112.3), 90.0)
	emergency(Vector3(31.4, y + 2.7, 130.6), 0.0)
	# the jib crane over the Crucible's apron
	CYL(Vector3(48.45, y + 2.9, 119.3), 0.14, 5.8, "iron")
	Props.strut(dress, Vector3(48.45, y + 5.5, 119.3), Vector3(44.2, y + 5.5, 122.8), 0.16, "iron")
	Props.strut(dress, Vector3(48.45, y + 6.3, 119.3), Vector3(44.4, y + 5.55, 122.65), 0.08, "iron")
	Props.strut(dress, Vector3(44.4, y + 5.45, 122.65), Vector3(44.4, y + 3.4, 122.65), 0.03, "iron", true)
	OB(Vector3(44.4, y + 3.25, 122.65), Vector3(0.14, 0.3, 0.1), "iron")
	Props.strut(dress, Vector3(44.4, y + 3.1, 122.65), Vector3(44.55, y + 2.95, 122.65), 0.04, "iron", true)
	# salt crust at the wall feet, puddles
	# (T-239: the "salt crust" is gone: four bright white 1.8 m discs lying on the dark floor, the kind of piece the owner
	# called floating white discs on Totenhafen)
	Props.puddle(dress, Vector3(26.0, y, 112.0), 1.6, 1.1, 20.0)
	Props.puddle(dress, Vector3(42.0, y, 128.0), 1.4, 1.0, -15.0)
	_dress_core_guides(y)


## T-226: luminous-paint guide lines (the readability pass's Leuchtfarbe, _lumi_line) on the Core's floor from each of the
## four doors, round the pit, to the Crucible's apron.
func _dress_core_guides(y: float) -> void:
	var f: float = y + 0.035
	for seg: Array in [[Vector3(21.5, f, 102.8), Vector3(41.0, f, 109.0)], [Vector3(41.0, f, 109.0), Vector3(42.0, f, 120.5)],
			[Vector3(43.0, f, 103.0), Vector3(42.5, f, 121.4)], [Vector3(47.9, f, 117.0), Vector3(45.2, f, 122.2)],
			[Vector3(34.0, f, 130.4), Vector3(42.0, f, 126.0)], [Vector3(42.0, f, 126.0), Vector3(44.0, f, 123.0)]]:
		_lumi_line(seg[0], seg[1], 0.07)


var _amber: StandardMaterial3D
var _litwin: StandardMaterial3D


## A curtained window with an oil lamp somewhere behind it (Map 1's own: dimmer and warmer than lantern glass).
func _lit_window() -> StandardMaterial3D:
	if _litwin == null:
		_litwin = StandardMaterial3D.new()
		_litwin.albedo_color = Color(0.08, 0.05, 0.03)
		_litwin.roughness = 0.4
		_litwin.emission_enabled = true
		_litwin.emission = Color(1.0, 0.6, 0.3)
		_litwin.emission_energy_multiplier = 1.1
	return _litwin
var _core_mats: Dictionary = {}


## The vault's Nachtglas is Map 1's own deep violet (the shared keys read lavender under the vault's light):
## swaps the shared crystal materials under `root` for it, in the Core only (z > 100, below the depths floor).
func _core_crystals(root: Node3D) -> void:
	if _core_mats.is_empty():
		var c: StandardMaterial3D = StandardMaterial3D.new()
		c.albedo_color = Color(0.22, 0.05, 0.4)
		c.roughness = 0.12
		c.metallic_specular = 1.0
		c.emission_enabled = true
		c.emission = Color(0.62, 0.1, 1.0)
		c.emission_energy_multiplier = 0.42
		var d: StandardMaterial3D = c.duplicate() as StandardMaterial3D
		d.albedo_color = Color(0.06, 0.015, 0.12)
		d.emission = Color(0.5, 0.08, 0.85)
		d.emission_energy_multiplier = 0.25
		_core_mats[Mats.get_mat("nachtglas_crystal")] = c
		_core_mats[Mats.get_mat("nachtglas_dim")] = d
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.material_override == null or not _core_mats.has(mi.material_override):
			continue
		var o: Vector3 = _xform_to_root(mi).origin
		if o.z > 100.5 and o.y < -5.0:
			mi.material_override = _core_mats[mi.material_override]


## Amber cracks running over the heart's crystal mass (they turn with it).
func _heart_cracks(core: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4473
	var r: Vector3 = Vector3(1.12, 1.52, 1.12)
	for k: int in 16:
		var th: float = rng.randf_range(0.5, 2.6)
		var ph: float = rng.randf_range(0.0, TAU)
		var prev: Vector3 = Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * r - Vector3(0, 0.0, 0)
		for s: int in 5:
			th = clampf(th + rng.randf_range(-0.3, 0.3), 0.3, 2.8)
			ph += rng.randf_range(-0.35, 0.35)
			var p: Vector3 = Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * r
			var mi: MeshInstance3D = Props.strut(core, prev * 1.06, p * 1.06, 0.06, "nachtglas_vein")
			if mi != null:
				mi.material_override = _amber_vein()
				_noshadow(mi)
			prev = p


## The amber of the Nachtglas cracks (Map 1's own material: the shared nachtglas keys stay violet).
func _amber_vein() -> StandardMaterial3D:
	if _amber == null:
		_amber = StandardMaterial3D.new()
		_amber.roughness = 0.6
		_amber.albedo_color = AMBER
		_amber.emission_enabled = true
		_amber.emission = AMBER
		_amber.emission_energy_multiplier = 3.0
	return _amber


## A branching glowing crack across a floor, clipped to a rectangle (x, z).
func _vein(start: Vector3, dir: Vector3, length: float, rng: RandomNumberGenerator, fy: float, clip: Rect2, depth: int = 0,
		mat: Material = null) -> void:
	var p: Vector3 = start
	var d: Vector3 = dir.normalized()
	var left: float = length
	while left > 0.0:
		var step: float = minf(left, rng.randf_range(0.35, 0.9))
		d = (d.rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))).normalized()
		var q: Vector3 = p + d * step
		if not clip.has_point(Vector2(q.x, q.z)):
			return
		var mi: MeshInstance3D = Props.strut(dress, Vector3(p.x, fy, p.z), Vector3(q.x, fy, q.z), 0.035 if depth == 0 else 0.022, "nachtglas_vein")
		if mi != null:
			var bb: Basis = mi.transform.basis
			mi.transform = Transform3D(Basis(bb.x, bb.y, bb.z * 0.25), mi.transform.origin)
			_noshadow(mi)
			if mat != null:
				mi.material_override = mat
		if depth < 1 and rng.randf() < 0.25:
			_vein(q, d.rotated(Vector3.UP, rng.randf_range(-1.0, 1.0)), left * 0.5, rng, fy, clip, depth + 1, mat)
		p = q
		left -= step


func _dress_ramps() -> void:
	# pit props along the three ramps and the H corridor; narrow-gauge rails down the Generator ramp
	var ramps: Array = [[17.5, 22.5, 90.0, 101.0, DY, CY, "I_CORE"], [41.5, 47.5, 82.0, 101.0, DY, CY, "I_CORE"],
		[71.5, 76.5, 98.0, 112.0, DY, CY, "I_CORE"]]
	for r: Array in ramps:
		var x0: float = float(r[0])
		var x1: float = float(r[1])
		var z0: float = float(r[2])
		var z1: float = float(r[3])
		var z: float = z0 + 1.2
		while z < z1 - 0.8:
			var t: float = (z - z0) / (z1 - z0)
			var fy: float = lerpf(float(r[4]), float(r[5]), t)
			for sx: float in [x0 + 0.3, x1 - 0.3]:
				CYL(Vector3(sx, (fy + DY + 3.0) * 0.5, z), 0.14, DY + 3.0 - fy, "pine")
			B(Vector3(x0 + 0.15, DY + 2.7, z - 0.15), Vector3(x1 - 0.15, DY + 3.0, z + 0.15), "pine")
			z += 2.6
		var mid_t: float = 0.5
		var mz: float = lerpf(z0, z1, mid_t)
		var my: float = lerpf(float(r[4]), float(r[5]), mid_t)
		bulkhead("I_CORE", Vector3(x0 + 0.17, my + 2.4, mz), -90.0, "sodium")
		power("I_CORE", Vector3(x0 + 0.8, my + 2.3, mz), 9.0, 1.2)
		var tz: float = lerpf(z0, z1, 0.25)
		var ty: float = lerpf(float(r[4]), float(r[5]), 0.25)
		bulkhead("I_CORE", Vector3(x1 - 0.17, ty + 2.2, tz), 90.0, "sodium")
		power("I_CORE", Vector3(x1 - 0.8, ty + 2.1, tz), 8.0, 1.0)
		# unpowered: a lantern left halfway down, and the heart's violet climbing the ramp from the vault door
		_hurricane(Vector3(x0 + 0.55, lerpf(float(r[4]), float(r[5]), 0.45) - 0.05, lerpf(z0, z1, 0.45)), 0.9)
		lamp(Vector3((x0 + x1) * 0.5, float(r[5]) + 1.6, z1 - 1.2), Color(0.58, 0.2, 1.0), 0.9, 8.0, 0.1, 0.3, false, 1.4)
		emergency(Vector3(x1 - 0.17, float(r[4]) + 2.4, z0 + 1.0), 90.0, 0.6, 7.0)
	for rx: float in [44.05, 44.95]:
		Props.strut(dress, Vector3(rx, DY + 0.06, 82.2), Vector3(rx, CY + 0.06, 100.8), 0.06, "rust")
	var sz: float = 82.6
	while sz < 100.6:
		var sy: float = lerpf(DY, CY, (sz - 82.0) / 19.0)
		OB(Vector3(44.5, sy + 0.02, sz), Vector3(1.4, 0.08, 0.2), "beam", Vector3(rad_to_deg(atan2(6.0, 19.0)), 0, 0))
		sz += 0.8
	var cx: float = 50.5
	while cx < 71.0:
		for cz: float in [112.3, 117.7]:
			CYL(Vector3(cx, CY + 1.75, cz), 0.14, 3.5, "pine")
		B(Vector3(cx - 0.15, CY + 3.2, 112.15), Vector3(cx + 0.15, CY + 3.5, 117.85), "pine")
		cx += 3.0
	bulkhead("I_CORE", Vector3(60.0, CY + 2.6, 112.17), 180.0, "sodium")
	power("I_CORE", Vector3(60.0, CY + 2.4, 113.0), 9.0, 1.1)
	emergency(Vector3(66.0, CY + 2.6, 117.83), 0.0, 0.6, 7.0)


## Readability before power (D-063). The depths stay dark and red, but a player can find the way and see a
## zombie at ~15 m: more battery emergency lamps and a few hurricane lanterns, a dim red fill in the Generator
## Hall, and luminous-paint guide strips (period air-raid Leuchtfarbe) along the ramps, the depths stair flights and
## the depths doorways. All decorative and non-colliding.
func _dress_readability() -> void:
	var y: float = DY
	# Generator Hall: emergency lamps all round the walls (they already burn at the NW and E walls)
	for e: Array in [[Vector3(64.0, y + 2.8, 60.33), 180.0], [Vector3(52.0, y + 2.8, 81.67), 0.0], [Vector3(76.5, y + 2.8, 81.67), 0.0],
			[Vector3(40.17, y + 2.8, 66.0), -90.0], [Vector3(40.17, y + 2.8, 78.5), -90.0], [Vector3(83.83, y + 2.8, 66.0), 90.0]]:
		emergency(e[0], float(e[1]), 0.9, 10.0)
	# a broad, shadowless red fill between the turbines (the emergency lamps' bounce)
	lamp(Vector3(56.0, y + 6.0, 75.5), Color(1.0, 0.42, 0.3), 1.1, 18.0, 0.0)
	lamp(Vector3(72.0, y + 6.0, 64.5), Color(1.0, 0.42, 0.3), 1.1, 18.0, 0.0)
	lamp(Vector3(46.0, y + 5.0, 66.0), Color(1.0, 0.42, 0.3), 0.8, 14.0, 0.0)
	# hurricane lanterns left on the turbine plinths and the crates by the shift crews
	for lp: Vector3 in [Vector3(53.5, y + 0.7, 67.35), Vector3(66.5, y + 0.7, 72.65), Vector3(71.5, y + 0.7, 67.35), Vector3(40.68, y + 0.9, 81.33),
			Vector3(40.6, y + 1.0, 60.6), Vector3(47.6, y + 0.7, 72.7), Vector3(60.4, y + 0.7, 72.7)]:
		_hurricane(lp, 1.1)
	# the shift's lantern left on the floor by the Hauptschalter's dais (the switch reads in the dark)
	_hurricane(Vector3(44.1, y, 62.9), 1.4)
	# Chapel: emergency lamps on the long walls and the south wall
	for e2: Array in [[Vector3(-15.83, y + 2.9, 75.0), -90.0], [Vector3(39.83, y + 2.9, 66.0), 90.0], [Vector3(39.83, y + 2.9, 84.0), 90.0],
			[Vector3(2.0, y + 3.0, 89.64), 0.0]]:
		emergency(e2[0], float(e2[1]), 0.8, 9.0)
	# a dim bounce over the pews (the nave is 56 m wide and its chandeliers need the power): the votive racks'
	# and the altar candles' amber off the salt, with only a little of the emergency red in it (T-062)
	for fx: float in [0.0, 24.0]:
		lamp(Vector3(fx, y + 5.5, 72.0), Color(1.0, 0.56, 0.34), 1.05, 15.0, 0.0)
	# Core ramps and the H corridor: luminous strips on both floor edges and a stripe along both walls at hip height
	var ramps: Array = [[17.5, 22.5, 90.0, 101.0], [41.5, 47.5, 82.0, 101.0], [71.5, 76.5, 98.0, 112.0]]
	for r: Array in ramps:
		var x0: float = float(r[0])
		var x1: float = float(r[1])
		var z0: float = float(r[2])
		var z1: float = float(r[3])
		var za: float = z0 + 0.25
		var zb: float = z1 - 0.15
		var ya: float = lerpf(DY, CY, (za - z0) / (z1 - z0))
		var yb: float = lerpf(DY, CY, (zb - z0) / (z1 - z0))
		for sx: float in [x0 + 0.62, x1 - 0.62]:
			_lumi_line(Vector3(sx, ya + 0.035, za), Vector3(sx, yb + 0.035, zb), 0.07)
		for wx: float in [x0 + 0.17, x1 - 0.17]:
			_lumi_line(Vector3(wx, ya + 1.0, za), Vector3(wx, yb + 1.0, zb), 0.05, true)
	for sz: float in [112.6, 117.4]:
		_lumi_line(Vector3(49.5, CY + 0.035, sz), Vector3(76.0, CY + 0.035, sz), 0.07)
	# stair flights below ground: luminous dashes at both ends of every second tread's nosing
	for s: Array in _stairs:
		if float(s[4]) > -1.0 or str(s[6]) != "concrete":
			continue
		var steps: int = int(ceil((float(s[5]) - float(s[4])) / 0.22))
		for k: int in steps:
			if k % 2 == 1:
				continue
			var t0: float = float(k) / float(steps)
			var t1: float = float(k + 1) / float(steps)
			var za: float = lerpf(float(s[2]), float(s[3]), t0)
			var zb: float = lerpf(float(s[2]), float(s[3]), t1)
			var yb: float = lerpf(float(s[4]), float(s[5]), t1)
			var nz: float = za + (zb - za) * 0.06
			for e: Array in [[float(s[0]) + 0.08, float(s[0]) + 0.42], [float(s[1]) - 0.42, float(s[1]) - 0.08]]:
				_noshadow(B(Vector3(float(e[0]), yb + 0.004, nz - 0.025), Vector3(float(e[1]), yb + 0.012, nz + 0.025), "lumi_paint", false))
	# depths doorways: luminous jamb strips on both faces (door, width, yaw)
	for d: Array in [[Vector3(40, y, 72), 2.6, 90.0, true], [Vector3(60, y, 82), 2.6, 0.0, true], [Vector3(44.5, y, 82), 5.0, 0.0, true],
			[Vector3(25, y, 60), 4.0, 0.0, false], [Vector3(-12, y, 60), 3.0, 0.0, false], [Vector3(20, y, 90), 4.0, 0.0, false],
			[Vector3(74, y, 98), 4.0, 0.0, true], [Vector3(20, CY, 101), 4.0, 0.0, true], [Vector3(44.5, CY, 101), 5.0, 0.0, true],
			[Vector3(49, CY, 115), 4.0, 90.0, true]]:
		var g: Node3D = Props.group(dress, "LumiJambs", d[0], float(d[2]))
		var hw: float = float(d[1]) * 0.5
		var trimmed: bool = bool(d[3])
		var face: float = T * 0.5 + (0.075 if trimmed else 0.004)
		for f: float in [-1.0, 1.0]:
			for side: float in [-1.0, 1.0]:
				var x: float = side * (hw + (0.07 if trimmed else 0.06))
				_noshadow(Props.block(g, Vector3(x - 0.025, 0.15, f * face), Vector3(x + 0.025, DOOR_H - 0.1, f * (face + 0.015)), "lumi_paint", false))


## A straight luminous-paint strip from a to b (on a floor, or a wall stripe if `wall`).
func _lumi_line(a: Vector3, b: Vector3, w: float, wall: bool = false) -> void:
	var d: Vector3 = b - a
	var mid: Vector3 = (a + b) * 0.5
	var pitch: float = rad_to_deg(atan2(-d.y, absf(d.z))) * (1.0 if d.z > 0.0 else -1.0)
	var yaw: float = 90.0 if absf(d.x) > absf(d.z) else 0.0
	var size: Vector3 = Vector3(w if not wall else 0.012, 0.012 if not wall else w, d.length())
	if yaw != 0.0:
		size = Vector3(d.length(), size.y, w)
		_noshadow(Props.obox(dress, mid, size, "lumi_paint"))
		return
	_noshadow(Props.obox(dress, mid, size, "lumi_paint", Vector3(pitch, 0, 0)))


## A hurricane lantern standing at p (base), with its own small warm light.
func _hurricane(p: Vector3, energy: float = 0.8) -> void:
	Props.cyl(dress, p + Vector3(0, 0.03, 0), 0.07, 0.06, "rust")
	_noshadow(Props.ball(dress, p + Vector3(0, 0.15, 0), Vector3(0.11, 0.16, 0.11), "lantern_glass"))
	for a: float in [0.0, 120.0, 240.0]:
		var o: Vector3 = Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 0.065
		Props.strut(dress, p + o + Vector3(0, 0.05, 0), p + o + Vector3(0, 0.26, 0), 0.01, "rust")
	Props.cyl(dress, p + Vector3(0, 0.27, 0), 0.05, 0.03, "rust")
	Props.cable(dress, p + Vector3(-0.07, 0.28, 0), p + Vector3(0.07, 0.28, 0), -0.08, 0.006, 4, "iron")
	lamp(p + Vector3(0, 0.3, 0), Color(1.0, 0.62, 0.3), energy, 6.5, 0.15, 0.0, false, 6.0)


## Window frames per zone style (local +Z = inside, as the window table's inward yaw).
func _dress_windows() -> void:
	for w: Array in WINDOWS:
		var p: Vector3 = w[2]
		var yaw: float = float(w[3])
		var zone: String = str(w[1])
		var g: Node3D = Props.group(dress, "WindowDress", p, yaw)
		var hw: float = 0.8
		match zone:
			"C_ADMIN":
				var outer: Node3D = Props.group(g, "Outer", Vector3(0, 0, -T * 0.5), 180.0)
				_admin_surround(outer, true)
				Props.block(g, Vector3(-hw - 0.1, SILL - 0.05, T * 0.5), Vector3(hw + 0.1, SILL, T * 0.5 + 0.15), "beam")
			"D_BARRACKS":
				for s: float in [1.0, -1.0]:
					var f: float = s * T * 0.5
					Props.block(g, Vector3(-hw - 0.12, SILL - 0.04, f), Vector3(-hw, WTOP + 0.12, f + s * 0.06), "beam")
					Props.block(g, Vector3(hw, SILL - 0.04, f), Vector3(hw + 0.12, WTOP + 0.12, f + s * 0.06), "beam")
					Props.block(g, Vector3(-hw - 0.12, WTOP, f), Vector3(hw + 0.12, WTOP + 0.14, f + s * 0.07), "beam")
				Props.block(g, Vector3(-hw - 0.15, SILL - 0.06, -T * 0.5 - 0.2), Vector3(hw + 0.15, SILL, T * 0.5 + 0.12), "beam")
				_noshadow(Props.block(g, Vector3(-hw - 0.1, SILL, -T * 0.5 - 0.18), Vector3(hw + 0.1, SILL + 0.06, -T * 0.5 - 0.02), "snow", false))
				for s2: float in [-1.0, 1.0]:
					var sh: Node3D = Props.group(g, "Shutter", Vector3(s2 * (hw + 0.14), SILL, -T * 0.5 - 0.04), s2 * 105.0)
					Props.block(sh, Vector3(-0.03, 0, 0), Vector3(0.03, WTOP - SILL + 0.1, s2 * -0.78), "planks")
			"F_CHAPEL":
				Props.pit_prop(g, Vector3(0, 0, T * 0.5 + 0.2), 0.0, 2.2, WTOP + 0.1)
				Props.crystal_cluster(g, Vector3(-0.5, SILL, 0.0), int(p.x * 7.0 + p.z), 0.4, "salt_crystal")
			"G_GENERATOR", "H_LAB":
				var key: String = "machine_grey" if zone == "G_GENERATOR" else "enamel_white"
				var f2: float = T * 0.5
				Props.block(g, Vector3(-hw - 0.1, SILL - 0.06, f2), Vector3(hw + 0.1, SILL, f2 + 0.1), key)
				Props.block(g, Vector3(-hw - 0.1, WTOP, f2), Vector3(hw + 0.1, WTOP + 0.12, f2 + 0.06), key)
				for s3: float in [-1.0, 1.0]:
					Props.block(g, Vector3(s3 * hw - 0.06, SILL, f2), Vector3(s3 * hw + 0.06, WTOP, f2 + 0.06), key)
			_:   # brick: concrete lintel and sill, snow outside
				Props.block(g, Vector3(-hw - 0.2, WTOP, -T * 0.5 - 0.04), Vector3(hw + 0.2, WTOP + 0.24, T * 0.5 + 0.04), "concrete")
				Props.block(g, Vector3(-hw - 0.12, SILL - 0.08, -T * 0.5 - 0.14), Vector3(hw + 0.12, SILL, T * 0.5 + 0.04), "concrete")
				_noshadow(Props.block(g, Vector3(-hw - 0.08, SILL, -T * 0.5 - 0.13), Vector3(hw + 0.08, SILL + 0.07, -T * 0.5 + 0.02), "snow", false))


## Door trims (both faces) for the buyable doors and the open doorways.
func _dress_doors() -> void:
	var trims: Array = [
		# (T-239: every trim is its doorway's width, DW. The 2.6 m doorways carried 2.0 m trims: on a shut door they read as a
		# frame laid on the leaf, and once the door was bought both jamb strips hung in the open doorway 0.16 m off the wall,
		# as they always did in the lab's six open doorways. The Administration's upstairs trim stood a metre east of its
		# doorway (x -8 for the opening at x -9), one jamb in the middle of the opening.)
		[Vector3(40, 0, 25), 90.0, DW, DOOR_H, "concrete"], [Vector3(0, 0, 25), 90.0, DW, DOOR_H, "stucco_trim"],
		[Vector3(-8, 0, 32), 0.0, DW, DOOR_H, "beam"], [Vector3(40, 0, 40), 90.0, DW, DOOR_H, "concrete"],
		[Vector3(25, 0, 46), 0.0, DW, DOOR_H, "machine_grey"], [Vector3(-10, 0, 46), 0.0, DW, DOOR_H, "machine_grey"],
		[Vector3(-9, 3.8, 16), 0.0, 1.6, DOOR_H, "beam"],
		[Vector3(40, DY, 72), 90.0, DW, DOOR_H, "machine_grey"], [Vector3(60, DY, 82), 0.0, DW, DOOR_H, "machine_grey"],
		[Vector3(44.5, DY, 82), 0.0, 5.0, DOOR_H, "machine_grey"],
		[Vector3(60, DY, 88), 0.0, DW, DOOR_H, "enamel_white"], [Vector3(76, DY, 88), 0.0, DW, DOOR_H, "enamel_white"],
		[Vector3(93, DY, 88), 0.0, DW, DOOR_H, "enamel_white"], [Vector3(60, DY, 92), 0.0, DW, DOOR_H, "enamel_white"],
		[Vector3(76, DY, 92), 0.0, DW, DOOR_H, "enamel_white"], [Vector3(93, DY, 92), 0.0, DW, DOOR_H, "enamel_white"],
		[Vector3(74, DY, 98), 0.0, 4.0, DOOR_H, "machine_grey"],
		[Vector3(20, CY, 101), 0.0, 4.0, DOOR_H, "iron"], [Vector3(44.5, CY, 101), 0.0, 5.0, DOOR_H, "iron"],
		[Vector3(49, CY, 115), 90.0, 4.0, DOOR_H, "iron"], [Vector3(34, CY, 131), 0.0, 4.0, DOOR_H, "iron"],
	]
	for d: Array in trims:
		var g: Node3D = Props.group(dress, "DoorTrim", d[0], float(d[1]))
		var w: float = float(d[2])
		var h: float = float(d[3])
		var key: String = str(d[4])
		for s: float in [1.0, -1.0]:
			var f: float = s * T * 0.5
			Props.block(g, Vector3(-w * 0.5 - 0.14, 0, f), Vector3(-w * 0.5, h + 0.14, f + s * 0.07), key)
			Props.block(g, Vector3(w * 0.5, 0, f), Vector3(w * 0.5 + 0.14, h + 0.14, f + s * 0.07), key)
			Props.block(g, Vector3(-w * 0.5 - 0.14, h, f), Vector3(w * 0.5 + 0.14, h + 0.18, f + s * 0.08), key)
		if key == "machine_grey" or key == "iron":
			for s2: float in [1.0, -1.0]:
				for k: int in 5:
					Props.block(g, Vector3(-w * 0.5 + k * w * 0.25 - 0.12, h + 0.02, s2 * (T * 0.5 + 0.075)),
						Vector3(-w * 0.5 + k * w * 0.25 + 0.12, h + 0.14, s2 * (T * 0.5 + 0.085)), "yellow_paint" if k % 2 == 0 else "black_paint")


func _dress_treads() -> void:
	for s: Array in _stairs:
		var x0: float = float(s[0])
		var x1: float = float(s[1])
		var z_low: float = float(s[2])
		var z_high: float = float(s[3])
		var y_low: float = float(s[4])
		var y_high: float = float(s[5])
		var rise: float = y_high - y_low
		var steps: int = int(ceil(rise / 0.22))
		for k: int in steps:
			var t0: float = float(k) / float(steps)
			var t1: float = float(k + 1) / float(steps)
			var za: float = lerpf(z_low, z_high, t0)
			var zb: float = lerpf(z_low, z_high, t1)
			var yb: float = lerpf(y_low, y_high, t1)
			B(Vector3(x0, maxf(y_low, yb - 0.6), minf(za, zb)), Vector3(x1, yb - 0.04, maxf(za, zb)), str(s[7]))
			B(Vector3(x0, yb - 0.04, minf(za, zb) - 0.02), Vector3(x1, yb, maxf(za, zb) + 0.02), str(s[6]))
			if str(s[6]) == "concrete":
				var nz: float = za + (zb - za) * 0.06
				B(Vector3(x0, yb - 0.005, nz - 0.04), Vector3(x1, yb + 0.004, nz + 0.04), "yellow_paint")
		# a pipe handrail on the +X side
		var rail_x: float = x1 - 0.06
		var mid: Vector3 = Vector3(rail_x, (y_low + y_high) * 0.5 + 0.95, (z_low + z_high) * 0.5)
		var rail_len: float = Vector2(z_high - z_low, rise).length()
		var ang: float = rad_to_deg(atan2(rise, absf(z_high - z_low))) * (1.0 if z_high < z_low else -1.0)
		Props.obox(dress, mid, Vector3(0.05, 0.05, rail_len), "iron" if str(s[6]) == "concrete" else "furniture", Vector3(ang, 0, 0))
		var posts: int = int(rail_len / 1.2)
		for k2: int in posts + 1:
			var t: float = float(k2) / float(maxi(1, posts))
			B(Vector3(rail_x - 0.02, lerpf(y_low, y_high, t), lerpf(z_low, z_high, t) - 0.02),
				Vector3(rail_x + 0.02, lerpf(y_low, y_high, t) + 0.95, lerpf(z_low, z_high, t) + 0.02), "iron")


## UPDATE 10 section 5 (T-161): the living world beyond the yard. The .tscn only carries the Landscape node (MapRoot adds the MapAmbience from map01_ambience.json):
## KaltenLandscape builds the valley, ridges, forest, rail line, cable car and siren at load time (the old prism
## mountains and cone firs of _dress_mountains are gone); MapAmbience runs the sky, the war and the reactive details
## from data/gravelight/map01_ambience.json. Neither collides.
func build_landscape() -> void:
	var land: Node3D = Node3D.new()
	land.set_script(load("res://gravelight/world/landscape/kalten_landscape.gd"))
	land.name = "Landscape"
	map_root.add_child(land)


func _dress_weather() -> void:
	var snow: Node3D = Node3D.new()
	snow.set_script(load("res://gravelight/world/snowfall.gd"))
	snow.name = "Snowfall"
	snow.set("areas", [AABB(Vector3(0.5, 0, 0.5), Vector3(39, 14, 31)), AABB(Vector3(40.5, 0, 14.5), Vector3(19, 14, 33)),
		AABB(Vector3(-22, 0, -16), Vector3(90, 16, 15)), AABB(Vector3(-36, 0, 0), Vector3(19, 16, 46)),
		AABB(Vector3(61, 0, 0), Vector3(16, 16, 50))] as Array[AABB])
	snow.set("density", 1.2)
	dress.add_child(snow)
	snow.set_meta("keep", true)
	var motes: Node3D = Node3D.new()
	motes.set_script(load("res://gravelight/world/snowfall.gd"))
	motes.name = "DustMotes"
	motes.set("areas", [AABB(Vector3(-15, DY + 0.5, 61), Vector3(54, 9, 28)), AABB(Vector3(41, DY + 0.5, 61), Vector3(42, 8, 20)),
		AABB(Vector3(53, DY + 0.3, 83), Vector3(48, 3, 14)), AABB(Vector3(20, CY + 0.5, 102), Vector3(28, 10, 28)),
		AABB(Vector3(-15, 0.3, 33), Vector3(54, 3.4, 12))] as Array[AABB])
	motes.set("motes", true)
	dress.add_child(motes)
	motes.set_meta("keep", true)


# ================================================================== the wall-buy audit (T-227)

## T-227: a bracket lamp over every chalk outline (its light is the BuyLight build_gameplay makes).
func _dress_buy_lamps() -> void:
	for b: Array in BUYS:
		var out: Vector3 = Basis(Vector3.UP, deg_to_rad(float(b[2]))) * Vector3(0, 0, -1)
		Props.wall_lamp(dress, (b[1] as Vector3) + Vector3(0, 0.95, 0) - out * 0.03, float(b[2]))


## T-227 (the owner: "make sure all wall weapon buys look good on both maps"): before the batching, every wall-buy's front
## is checked against everything drawn: nothing may stand in the 1.8 x 1.2 m window in front of the chalk out to 1 m (the
## board, the gun and its label are WallBuy's own, built at load), and the chalk must hang on a collider (a world box
## within 0.1 m behind its plane), never float. The lamps are by construction (one BuyLight per entry). One line per buy;
## returns the number of blocked or floating ones. (The same check is gen_map00's.)
func _audit_wall_buys() -> int:
	var bad: int = 0
	var meshes: Array = []
	for root: Node3D in [dress, geo]:
		meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	var bodies: Array = geo.find_children("*", "StaticBody3D", true, false)
	for b: Array in BUYS:
		var pos: Vector3 = b[1]
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(b[2])))
		var out: Vector3 = basis * Vector3(0, 0, -1)
		var side: Vector3 = basis * Vector3(1, 0, 0)
		var c1: Vector3 = pos + out * 0.03 - side * 0.9 + Vector3(0, -0.6, 0)
		var c2: Vector3 = pos + out * 1.0 + side * 0.9 + Vector3(0, 0.6, 0)
		var win: AABB = AABB(c1.min(c2), (c2 - c1).abs())
		var hits: PackedStringArray = []
		for n: Node in meshes:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			var ab: AABB = _xform_to_root(mi) * mi.get_aabb()
			if ab.intersects(win) and ab.intersection(win).get_volume() > 0.0005:
				hits.append("%s(%s @ %s)" % [mi.name, mi.get_parent().name, str(ab.get_center().snapped(Vector3(0.01, 0.01, 0.01)))])
		var behind: Vector3 = pos - out * 0.08
		var on_wall: bool = false
		for n2: Node in bodies:
			var body: StaticBody3D = n2 as StaticBody3D
			for c: Node in body.get_children():
				var cs: CollisionShape3D = c as CollisionShape3D
				if cs == null or not (cs.shape is BoxShape3D):
					continue
				var lp: Vector3 = (_xform_to_root(body) * cs.transform).affine_inverse() * behind
				var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
				if absf(lp.x) <= half.x and absf(lp.y) <= half.y and absf(lp.z) <= half.z:
					on_wall = true
					break
			if on_wall:
				break
		var ok: bool = hits.is_empty() and on_wall
		print("WALLBUY_AUDIT %-12s %s%s%s" % [str(b[0]), "clear" if ok else "BLOCKED", "" if on_wall else " (nothing behind the chalk)", "" if hits.is_empty() else ": " + ", ".join(hits)])
		if not ok:
			bad += 1
	return bad


# ================================================================== batching

## Merges every static primitive mesh (collision visuals + dressing) into one ArrayMesh per
## (material, shadow mode, 12 m cell). Materials are world-triplanar, so baking transforms into vertices
## keeps the texturing identical. Subtrees tagged "keep" (power glow, spinners, the heart) are left alone.
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
			var cell: Vector3i = Vector3i(floori(c.x / 22.0), floori((c.y + 3.0) / 9.0), floori(c.z / 22.0))
			if absf(c.x - 30.0) > 120.0 or absf(c.z - 40.0) > 120.0:
				cell = Vector3i(9999, 0, 0)   # the far mountains and forest: one batch per material
			var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, cell]
			if not groups.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st}
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
			victims.append(mi)
	var batch_root: Node3D = Node3D.new()
	batch_root.name = "StaticBatches"
	map_root.add_child(batch_root)
	var i: int = 0
	for key: String in groups.keys():
		var g: Dictionary = groups[key]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Batch_%d" % i
		out.mesh = _commit(g["st"])
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		batch_root.add_child(out)
		i += 1
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	print("  %d batches" % i)
	return victims.size()


## Commits a batch without UVs (every merged material is triplanar or untextured) and with compressed
## vertex attributes, which keeps the saved scene a fraction of the size.
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


## The nearest ancestor of n (up to and including root) that has the "keep" meta.
func _owner_spinner(n: Node, root: Node) -> Node:
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p.has_meta("keep"):
			return p
		p = p.get_parent()
	return root


## Frees plain, empty Node3D groups left behind by the batching (smaller scene, faster load).
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
	we.set_script(load(GRADE))   # ambient / far fog / exposure follow the camera's depth (surface, depths, core)
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var psm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.008, 0.011, 0.024)
	psm.sky_horizon_color = Color(0.05, 0.06, 0.09)
	psm.ground_bottom_color = Color(0.01, 0.012, 0.018)
	psm.ground_horizon_color = Color(0.05, 0.06, 0.09)
	psm.sun_angle_max = 4.0
	psm.sun_curve = 0.05
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Flat fill is the surface value here; depth_grade.gd swaps it per level and cuts it while SDFGI runs.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.40)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.4
	# Bounce light (T-062): SDFGI on High (sodium pools warm the salt, Nachtglas tints the vault), SSIL on Medium+.
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_energy = 1.0
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.085, 0.095, 0.13)
	env.fog_density = 0.009
	env.fog_sky_affect = 0.4
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.75, 0.78, 0.88)
	env.volumetric_fog_emission = Color(0.008, 0.009, 0.014)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_anisotropy = 0.45
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.1
	we.environment = env
	map_root.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.set_script(load("res://gravelight/maps/map01_kaltenbrunn/moon_switch.gd"))
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.8   # T-062: a firmer moon (shadows on the snow) over less flat fill
	moon.light_volumetric_fog_energy = 0.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	map_root.add_child(moon)
	# Power lights (dark until the Hauptschalter's sweep reaches their zone): omni + optional spot child.
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
		var fog_e: float = float(e.get("fog", -1.0))
		l.light_volumetric_fog_energy = fog_e if fog_e >= 0.0 else (1.0 if zone == "I_CORE" else 0.25)
		l.shadow_enabled = bool(e["shadow"])
		l.set_meta("zone", StringName(zone))
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
			s.light_color = FLOOD
			s.light_energy = float(sp["energy"]) * 1.5
			s.spot_range = float(sp["range"])
			s.spot_angle = float(sp["angle"])
			s.spot_attenuation = 0.6
			s.light_volumetric_fog_energy = 0.3
			s.shadow_enabled = zone == "A_MINEHEAD" and i % 2 == 0
			l.add_child(s)
		if not first.has(zone):
			first[zone] = l
		i += 1
	# glowing (powered) parts ride under the zone's first power light, so they show with it
	for zone2: String in _glow.keys():
		var holder: Node3D = _glow[zone2]
		var host: OmniLight3D = first.get(zone2) as OmniLight3D
		if host == null:
			push_warning("gen_map01: no power light for glow zone %s" % zone2)
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
	# Always-on lights: emergency lamps, fires, candles, the tanks' Nachtglas
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
		map_root.add_child(l2)
		si += 1
	# the heart: a slow violet pulse that casts the cage's shadow over the vault
	var hl: OmniLight3D = OmniLight3D.new()
	hl.set_script(load("res://gravelight/world/flicker_light.gd"))
	hl.set("base_energy", 3.4)
	hl.set("amount", 0.3)
	hl.set("speed", 1.6)
	hl.name = "HeartGlow"
	hl.position = Vector3(34, CY + 7.0, 116)
	hl.light_color = Color(0.62, 0.24, 1.0)
	hl.light_energy = 3.4
	hl.omni_range = 26.0
	hl.light_volumetric_fog_energy = 2.4   # the heart's halo in the vault haze (T-062 second pass)
	hl.shadow_enabled = true
	map_root.add_child(hl)
	# the pit: amber light leaking up out of the cracks under the heart (warms the cage's underside and the rim)
	var pl: OmniLight3D = OmniLight3D.new()
	pl.set_script(load("res://gravelight/world/flicker_light.gd"))
	pl.set("base_energy", 4.5)
	pl.set("amount", 0.2)
	pl.set("speed", 1.1)
	pl.name = "PitGlow"
	pl.position = Vector3(34, CY + 1.4, 116)
	pl.light_color = AMBER
	pl.light_energy = 4.5
	pl.omni_range = 11.0
	pl.omni_attenuation = 1.0
	pl.light_volumetric_fog_energy = 0.8
	map_root.add_child(pl)
	# local fog: violet haze in the vault, a dark throat down the lift shaft, a little salt dust in the chapel
	_fog("VaultFog", Vector3(34, CY + 5, 116), Vector3(30, 10, 30), 0.022, Color(0.72, 0.55, 1.0), Color(0.03, 0.0, 0.06))
	_fog("ShaftFog", Vector3(25, DY + 5.5, 51), Vector3(4.4, 11, 4.4), 0.5, Color(0.1, 0.1, 0.12), Color(0, 0, 0))
	_fog("ChapelHaze", Vector3(12, DY + 5, 75), Vector3(56, 10, 30), 0.012, Color(1.0, 0.92, 0.9), Color(0, 0, 0))
	_fog("StairHaze", Vector3(-10, -6, 53), Vector3(12, 12, 14), 0.02, Color(0.9, 0.9, 0.95), Color(0, 0, 0))
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
		push_warning("gen_map01: %s not found yet; placing a plain marker for %s" % [script, n])
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
	map_root.set("map_id", &"map01_kaltenbrunn")
	map_root.set("display_name", "Kaltenbrunn")
	map_root.set("start_zone", &"A_MINEHEAD")
	map_root.set("intro_text", "KALTENBRUNN SALT MINE\nUpper Silesia, December 1944")
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map01_requiem.json",
		"res://data/gravelight/quests/map01_song.json", "res://data/gravelight/quests/map01_wren_tag.json"]))
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
	# T-225: the squad starts in the Waschkaue, facing north out of its two doorways at the headframe
	for p: Vector3 in [Vector3(7, 0, 28.3), Vector3(13, 0, 28.3), Vector3(7, 0, 29.7), Vector3(13, 0, 29.7)]:
		_node("res://gravelight/maps/player_spawn.gd", "PlayerSpawn%d" % i, {}, p, 0.0, true)
		i += 1
	# zone volumes
	var zi: int = 0
	for zb: Array in ZONE_BOXES:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		_node("res://gravelight/world/zone_volume.gd", "Zone_%s_%d" % [zb[0], zi], {"zone_id": StringName(zb[0]), "size": hi - lo},
			Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5))
		zi += 1

	# windows: [id, zone, floor pos on the wall line, inward yaw]
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
	# ground spawns: [zone, pos, min_round]
	var grounds: Array = [
		["A_MINEHEAD", Vector3(37, 0, 3), 4], ["A_MINEHEAD", Vector3(3, 0, 29), 4],
		["B_RAILYARD", Vector3(57.7, 0, 31), 6], ["D_BARRACKS", Vector3(36, 0, 36), 8],
		["F_CHAPEL", Vector3(0, DY, 88), 5], ["F_CHAPEL", Vector3(24, DY, 88), 5],
		["G_GENERATOR", Vector3(50, DY, 64), 4], ["G_GENERATOR", Vector3(78, DY, 79), 4],
		["H_LAB", Vector3(96, DY, 95.5), 6], ["H_LAB", Vector3(55, DY, 94), 6],
		["I_CORE", Vector3(21, CY, 110), 1], ["I_CORE", Vector3(47, CY, 108), 1], ["I_CORE", Vector3(21, CY, 122), 1],
	]
	var gi: int = 0
	for g: Array in grounds:
		_node("res://gravelight/enemies/zombie_spawn.gd", "Ground_%s_%d" % [g[0], gi], {"zone_id": StringName(g[0]), "kind": &"ground",
			"min_round": int(g[2])}, g[1], 0.0, true)
		gi += 1

	# doors: [name, door_id, zone, also, link, cost, label, pos, yaw, width, needs_power]
	var doors: Array = [
		["Door_RailYard", "door_a_b", "B_RAILYARD", [], "", 750, "Rail Yard", Vector3(40, 0, 25), 90.0, 2.6, false],
		["Door_Admin", "door_a_c", "C_ADMIN", [], "", 1000, "Administration", Vector3(0, 0, 25), 90.0, 2.6, false],
		["Door_Barracks_C", "door_barracks", "D_BARRACKS", [], "barracks", 1250, "Barracks", Vector3(-8, 0, 32), 0.0, 2.6, false],
		["Door_Barracks_B", "door_barracks", "D_BARRACKS", [], "barracks", 1250, "Barracks", Vector3(40, 0, 40), 90.0, 2.6, false],
		["Door_Lift", "door_lift", "E_LIFT", ["F_CHAPEL"], "", 1250, "Lift", Vector3(25, 0, 46), 0.0, 2.6, false],
		["Door_Stairs", "door_stairs", "M_STAIRS", ["F_CHAPEL"], "", 1500, "Maintenance Stairs", Vector3(-10, 0, 46), 0.0, 2.6, false],
		["Door_Generator", "door_gen", "G_GENERATOR", [], "", 1500, "Generator Hall", Vector3(40, DY, 72), 90.0, 2.6, false],
		["Door_Lab", "door_lab", "H_LAB", [], "", 2000, "Laboratory Wing", Vector3(60, DY, 82), 0.0, 2.6, true],
	]
	for d: Array in doors:
		_node("res://gravelight/world/door.gd", str(d[0]), {"door_id": StringName(d[1]), "opens_zone": StringName(d[2]),
			"also_opens": PackedStringArray(d[3]), "link_group": StringName(d[4]), "cost": int(d[5]), "label": d[6],
			"size": Vector3(float(d[9]), DOOR_H, 0.25), "requires_power": d[10]}, d[7], float(d[8]))

	# wall-buys, each with a small warm lamp over its chalk so the buys read at a glance before the power (T-227, as Map 0's;
	# the lamp's bracket is drawn by _dress_buy_lamps)
	for b: Array in BUYS:
		_node("res://gravelight/world/wall_buy.gd", "WallBuy_" + str(b[0]), {"weapon_id": StringName(b[0])}, b[1], float(b[2]))
		var bl: OmniLight3D = OmniLight3D.new()
		bl.name = "BuyLight_" + str(b[0])
		bl.light_color = Color(1.0, 0.8, 0.55)
		bl.light_energy = 0.6
		bl.omni_range = 1.8
		bl.position = (b[1] as Vector3) + Basis(Vector3.UP, deg_to_rad(float(b[2]))) * Vector3(0, 0.75, -0.5)
		gameplay.add_child(bl)

	# perk machines (PERKS; their footprints are baked, build_perk_blocks)
	for p: Array in PERKS:
		_node("res://gravelight/world/perk_machine.gd", "Perk_" + str(p[0]), {"perk_id": StringName(p[0])}, p[1], float(p[2]))

	# crate spots: [name, pos, yaw, can_start]
	var crates: Array = [
		["Boxcar", Vector3(54.6, 0, 24), 90.0, true, [Vector3(53.5, 0, 24), Vector3(48, 0, 24), Vector3(48, 0, 44)]],
		["Mess", Vector3(34, 0, 41), 0.0, true, [Vector3(34, 0, 40), Vector3(34, 0, 35.5), Vector3(12, 0, 35.5)]],
		["SideAltar", Vector3(38.2, DY, 82), 90.0, false, [Vector3(37, DY, 82), Vector3(30, DY, 84.5), Vector3(22, DY, 84.5)]],
		["GenCatwalk", Vector3(82.6, DY, 78), 90.0, false, [Vector3(81.5, DY, 78), Vector3(82, DY, 63), Vector3(70, DY, 62.5)]],
		["Fasbender", Vector3(76, DY, 83.4), 180.0, false, [Vector3(76, DY, 85), Vector3(76, DY, 90), Vector3(64, DY, 90)]],
	]
	var ci: int = 0
	for c: Array in crates:
		_node("res://gravelight/world/mystery_crate.gd", "Crate_" + str(c[0]), {"spot_index": ci, "can_start": c[3], "spot_name": c[0],
			"drummer_route": PackedVector3Array(c[4])}, c[1], float(c[2]))
		ci += 1

	# world machinery (M3 nodes; see world/*.gd)
	_node("res://gravelight/world/power_switch.gd", "Hauptschalter", {}, Vector3(46.5, DY + 0.3, 61.2), 180.0)
	_node("res://gravelight/world/pylon.gd", "Pylon_A", {"pylon_id": &"a", "zone_id": &"A_MINEHEAD", "radius": 8.0}, Vector3(20, 0, 21.5), 180.0)
	_node("res://gravelight/world/pylon.gd", "Pylon_F", {"pylon_id": &"f", "zone_id": &"F_CHAPEL", "radius": 8.0}, Vector3(-2, DY, 84), 90.0)
	_node("res://gravelight/world/pylon.gd", "Pylon_H", {"pylon_id": &"h", "zone_id": &"H_LAB", "radius": 8.0}, Vector3(60, DY, 95), 0.0)
	for bd: Array in [["BlastDoor_F", Vector3(4.0, 3.0, 0.4), Vector3(20, DY, 90.0)], ["BlastDoor_G", Vector3(5.0, 3.0, 0.4), Vector3(44.5, DY, 82.0)],
			["BlastDoor_H", Vector3(4.0, 3.0, 0.4), Vector3(74, DY, 98.0)]]:
		var bdn: Node3D = _node("res://gravelight/world/blast_door.gd", str(bd[0]), {"size": bd[1]}, bd[2], 0.0)
		_blast_door_visual(bdn, bd[1])
	_node("res://gravelight/world/lift.gd", "Lift", {"top_y": 0.0, "bottom_y": DY, "zone_id": &"E_LIFT", "cage_size": Vector3(4, 3, 4)}, Vector3(25, 0, 51), 0.0)
	var cart: Node3D = _node("res://gravelight/world/trap_ore_cart.gd", "Trap_OreCart", {"track_start": Vector3(0, 0, 0), "track_end": Vector3(0, 0, 31)}, Vector3(44, 0, 15.5), 0.0)
	_node("res://gravelight/world/trap_lever.gd", "Lever_OreCart", {"trap_path": NodePath("../" + cart.name), "trap_id": &"ore_cart"}, Vector3(41.0, 0, 46.6), 0.0)
	var wire: Node3D = _node("res://gravelight/world/trap_live_wire.gd", "Trap_LiveWire", {"size": Vector3(4.0, 3.0, 6.0)}, Vector3(69, DY, 70), 0.0)
	_node("res://gravelight/world/trap_lever.gd", "Lever_LiveWire", {"trap_path": NodePath("../" + wire.name), "trap_id": &"live_wire"}, Vector3(73.5, DY, 76.5), 0.0)
	var chand: Node3D = _node("res://gravelight/world/trap_chandelier.gd", "Trap_Chandelier", {"drop_points": PackedVector3Array([Vector3(0, 0, -5), Vector3(0, 0, 0), Vector3(0, 0, 5)])}, Vector3(12, DY, 71), 0.0)
	_node("res://gravelight/world/trap_lever.gd", "Lever_Chandelier", {"trap_path": NodePath("../" + chand.name), "trap_id": &"chandelier"}, Vector3(14.5, DY, 61.8), 180.0)
	_node("res://gravelight/world/crucible.gd", "Crucible", {}, Vector3(46.2, CY, 124), 90.0)
	for ab2: Array in AMMO_BOXES:
		_node("res://gravelight/world/ammo_box.gd", "AmmoBox_" + str(ab2[0]), {"box_name": str(ab2[0]).to_snake_case()}, ab2[1], float(ab2[2]))
	_node("res://gravelight/world/armorers_bench.gd", "ArmorersBench", {}, ARMORERS_BENCH[0], float(ARMORERS_BENCH[1]))
	build_quest_objects()
	# power-on burst points (G and F ground)
	for bp: Vector3 in [Vector3(50, DY, 64), Vector3(78, DY, 79), Vector3(0, DY, 88), Vector3(24, DY, 88)]:
		var m: Marker3D = Marker3D.new()
		m.name = "BurstPoint"
		m.position = bp
		m.add_to_group(&"power_burst_points", true)
		gameplay.add_child(m)


## Art for a BlastDoor (it uses a child named "Visual" instead of its greybox, and slides it up to open).
func _blast_door_visual(bd: Node3D, size: Vector3) -> void:
	var v: Node3D = Node3D.new()
	v.name = "Visual"
	bd.add_child(v)
	var w: float = size.x
	var h: float = size.y
	var t: float = size.z
	Props.block(v, Vector3(-w * 0.5, 0, -t * 0.5), Vector3(w * 0.5, h, t * 0.5), "machine_grey")
	for s: float in [-1.0, 1.0]:
		var f: float = s * t * 0.5
		for k: int in int(w / 0.5):
			var x0: float = -w * 0.5 + k * 0.5
			Props.block(v, Vector3(x0, 0.0, f), Vector3(x0 + 0.5, 0.35, f + s * 0.02), "yellow_paint" if k % 2 == 0 else "black_paint")
		for ry: float in [0.9, 1.9, 2.8]:
			Props.block(v, Vector3(-w * 0.5, ry, f), Vector3(w * 0.5, ry + 0.12, f + s * 0.04), "iron")
		Props.cyl(v, Vector3(0, h * 0.55, f + s * 0.05), 0.42, 0.06, "nachtglas_dim", Vector3(90, 0, 0))
		Props.cyl(v, Vector3(0, h * 0.55, f + s * 0.07), 0.5, 0.04, "iron", Vector3(90, 0, 0))
		for k2: int in 6:
			var a: float = TAU * float(k2) / 6.0
			Props.ball(v, Vector3(cos(a) * 0.62, h * 0.55 + sin(a) * 0.62, f + s * 0.05), Vector3(0.08, 0.08, 0.08), "steel")
	_bake_local(v, false)


# ================================================================== Requiem for Kaltenbrunn + side eggs (M4)

func build_quest_objects() -> void:
	# Totenglocke parts: 3 candidate spots per part; only the seeded one shows in a match.
	var parts: Array = [
		["tg_part_bell", "boxcar", Vector3(55.0, 0, 21)], ["tg_part_bell", "signal_box", Vector3(56.8, 0, 46)],
		["tg_part_bell", "locomotive_cab", Vector3(52.5, 0, 41.2)],
		["tg_part_frame", "top_bunk", Vector3(-10.5, 1.8, 42)], ["tg_part_frame", "quartermaster_cage", Vector3(-14.6, 0, 33.6)],
		["tg_part_frame", "mess_stage", Vector3(38.6, 0, 33.6)],
		["tg_part_crank", "bell_tower_base", Vector3(4.5, DY, 88.6)], ["tg_part_crank", "sacristy", Vector3(36.5, DY, 88.6)],
		["tg_part_crank", "confessional", Vector3(-14.0, DY, 82.7)],
	]
	for pt: Array in parts:
		_node("res://gravelight/world/buildable_part.gd", "Part_%s_%s" % [pt[0], pt[1]], {"part_id": StringName(pt[0]), "spot_id": StringName(pt[1])}, pt[2], 0.0)
	_node("res://gravelight/world/workbench.gd", "Workbench", {}, Vector3(41.65, DY, 62.0), 180.0)
	# Fasbender's radios (7 candidates, 3 live): [id, pos, yaw]
	var radios: Array = [
		["radio_admin_switch", Vector3(-1.6, 2.2, 30.2), 0.0], ["radio_admin_fasbender", Vector3(-14.2, 4.6, 10.5), -90.0],
		["radio_rail_signalbox", Vector3(58.6, 1.0, 46.0), 90.0], ["radio_mess_kitchen", Vector3(37.0, 1.0, 45.1), 0.0],
		["radio_chapel_confessional", Vector3(-14.3, DY, 85.2), -90.0], ["radio_gen_foreman_desk", Vector3(82.0, DY + 0.9, 61.2), 180.0],
		["radio_lab_intake", Vector3(71.2, DY + 0.9, 93.7), 0.0],
	]
	for r: Array in radios:
		_node("res://gravelight/world/quest_radio.gd", "Radio_" + str(r[0]), {"radio_id": StringName(r[0])}, r[1], float(r[2]))
	_node("res://gravelight/world/switchboard.gd", "Switchboard", {}, Vector3(-3.5, 0, 29.5), 0.0)
	# Die Totenglocke over the altar, and the Four Bells' candidate spots (one per note group). T-181: the gatehouse's
	# bell hangs from the front lip of its roof over the WACHE sign (it sat in the middle of the flat roof, out of
	# sight from the ground and behind the slab for every round: the bots fired 30-70 times and never rang it).
	_node("res://gravelight/world/quest_bell.gd", "ChapelBell", {"kind": &"chapel", "bell_id": &"chapel_bell", "size": 2.0}, Vector3(12, DY + 10.7, 85), 0.0)
	var bells: Array = [
		["n1", "bell_tower_girder", Vector3(20, 6.5, 19.5)], ["n1", "bell_gatehouse_roof", Vector3(8, 3.15, 10.55)],
		["n1", "bell_boxcar_roof", Vector3(57, 3.75, 24)],
		["n2", "bell_balcony_rafters", Vector3(-1.5, 6.4, 14)], ["n2", "bell_mess_chandelier", Vector3(24, 3.4, 39)],
		["n2", "bell_bunk_beam", Vector3(-4, 3.4, 42)],
		["n3", "bell_chapel_chute", Vector3(8, DY + 2.7, 60.6)], ["n3", "bell_turbine_catwalk", Vector3(75, DY + 6.2, 74.7)],
		["n3", "bell_lift_crossbeam", Vector3(25, DY + 2.9, 60.6)],
		["n4", "bell_specimen_tank", Vector3(66.5, DY + 2.9, 84)], ["n4", "bell_nursery_window", Vector3(93, DY + 2.6, 82.5)],
		["n4", "bell_coldstore_pipe", Vector3(90, DY + 3.1, 96.5)],
	]
	for b: Array in bells:
		_node("res://gravelight/world/quest_bell.gd", "Bell_" + str(b[1]), {"kind": &"small", "bell_id": StringName(b[1]), "note": StringName(b[0]), "size": 0.4}, b[2], 0.0)
	_node("res://gravelight/world/altar_reliquary.gd", "Altar", {}, Vector3(12, DY, 81.8), 0.0)
	# Hidden song: three cylinders (fixed spots) and the phonograph in Reinholt's office.
	var cyls: Array = [["Cylinder1", Vector3(12.25, 1.0, 7.0), "REI_CYL1_01"], ["Cylinder2", Vector3(-15.3, DY + 2.5, 82.7), "REI_CYL2_01"],
		["Cylinder3", Vector3(100.2, DY + 1.0, 86.8), "REI_CYL3_01"]]
	for c: Array in cyls:
		_node("res://gravelight/world/quest_pickup.gd", str(c[0]), {"collect_tag": &"cylinder", "label": "the phonograph cylinder",
			"vo_line": StringName(c[2]), "color": Color(0.85, 0.7, 0.35)}, c[1], 0.0)
	_node("res://gravelight/world/phonograph.gd", "Phonograph", {}, Vector3(-14.0, 3.8, 30.0), -90.0)
	# Wren's brother's tag on the Intake board.
	_node("res://gravelight/world/quest_pickup.gd", "Tag_KB4471", {"interact_target": &"kb4471", "label": "tag KB-4471",
		"exchange_line": &"TAG_KB4471_01", "glint_for": &"wren", "color": Color(0.75, 0.75, 0.7)}, Vector3(80, DY + 1.4, 97.4), 0.0)
