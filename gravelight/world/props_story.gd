class_name PropsStory
extends RefCounted
## Small story and wear props for the room-by-room polish (Update 02 section 8, T-053): meals left half eaten, a
## patrol's dropped kit, clothes, an apron on its hook, and the layers of wear (grime, soot, water stains, worn
## boards, scuffs, blown-in snow). Like Props: decorative primitives, no collision, batched by gen_map00's merge.
## Frames as in Props: `yaw` in degrees, local -Z is the prop's front unless a builder says otherwise.

# ================================================================== a table left in a hurry

## A plate on a table top at `pos` (the table's surface): a crust of bread, a spoon, sometimes a bite left.
static func plate_meal(parent: Node3D, pos: Vector3, yaw: float, eaten: float = 0.5) -> void:
	var g: Node3D = Props.group(parent, "Meal", pos, yaw)
	Props.cyl(g, Vector3(0, 0.008, 0), 0.12, 0.016, "enamel_plate")
	Props.cyl(g, Vector3(0, 0.017, 0), 0.1, 0.004, "furniture")   # the well of the plate, darker
	if eaten < 0.9:
		var len_: float = lerpf(0.16, 0.05, eaten)
		Props.obox(g, Vector3(-0.02, 0.04, 0.0), Vector3(len_, 0.045, 0.07), "bread", Vector3(0, 20, 0))
	Props.obox(g, Vector3(0.05, 0.03, 0.06), Vector3(0.03, 0.025, 0.02), "bread", Vector3(0, 70, 10))   # a crumb of crust
	Props.obox(g, Vector3(0.14, 0.02, 0.0), Vector3(0.012, 0.006, 0.16), "steel", Vector3(0, 15, 0))      # spoon


## A bowl of soup gone cold, a spoon left standing in it.
static func soup_bowl(parent: Node3D, pos: Vector3, yaw: float, full: float = 0.5) -> void:
	var g: Node3D = Props.group(parent, "Soup", pos, yaw)
	Props.cyl(g, Vector3(0, 0.035, 0), 0.075, 0.07, "enamel_plate")
	Props.cyl(g, Vector3(0, 0.02 + 0.045 * full, 0), 0.066, 0.004, "soup")
	Props.obox(g, Vector3(0.02, 0.09, 0.0), Vector3(0.01, 0.006, 0.17), "steel", Vector3(55, 30, 0))


## A tin cup (an enamel mug).
static func mug(parent: Node3D, pos: Vector3) -> void:
	Props.cyl(parent, pos + Vector3(0, 0.045, 0), 0.04, 0.09, "enamel_plate")
	Props.obox(parent, pos + Vector3(0.05, 0.05, 0), Vector3(0.012, 0.05, 0.01), "enamel_plate")


## A half loaf on a board with the knife.
static func loaf(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "Loaf", pos, yaw)
	Props.block(g, Vector3(-0.17, 0, -0.11), Vector3(0.17, 0.02, 0.11), "furniture")
	Props.ball(g, Vector3(-0.03, 0.06, 0), Vector3(0.18, 0.1, 0.12), "bread")
	Props.obox(g, Vector3(0.1, 0.03, 0.03), Vector3(0.16, 0.004, 0.02), "steel", Vector3(0, 25, 0))
	Props.obox(g, Vector3(0.02, 0.03, 0.06), Vector3(0.06, 0.016, 0.018), "beam", Vector3(0, 25, 0))


# ================================================================== the patrol's kit

## A Stahlhelm set down on its rim (or lying on its crown when `upturned`).
static func helmet(parent: Node3D, pos: Vector3, yaw: float, upturned: bool = false) -> void:
	var g: Node3D = Props.group(parent, "Helmet", pos, yaw)
	if upturned:
		g.rotation.x = PI
		g.position.y += 0.13
	var dome: MeshInstance3D = Props.ball(g, Vector3(0, 0.03, 0), Vector3(0.25, 0.26, 0.29), "helmet")
	dome.name = "Dome"
	Props.cyl(g, Vector3(0, 0.02, 0.012), 0.155, 0.025, "helmet")   # the flared skirt over the neck and ears
	Props.obox(g, Vector3(0.13, 0.008, 0.06), Vector3(0.02, 0.008, 0.26), "leather", Vector3(0, 20, 0))   # chin strap


## A canteen-and-mess-tin set: the kidney-shaped tin with its lid off, a fork.
static func mess_tin(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "MessTin", pos, yaw)
	Props.ball(g, Vector3(0, 0.04, 0), Vector3(0.18, 0.08, 0.12), "helmet")
	Props.cyl(g, Vector3(0, 0.07, 0), 0.075, 0.006, "soup")
	Props.ball(g, Vector3(0.17, 0.012, 0.05), Vector3(0.17, 0.024, 0.11), "helmet")   # the lid beside it


## The fluted gas-mask canister on its strap, lying on the floor.
static func gasmask_can(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "GasMaskCan", pos, yaw)
	Props.cyl(g, Vector3(0, 0.06, 0), 0.06, 0.27, "helmet", Vector3(90, 0, 0))
	for z: float in [-0.08, 0.0, 0.08]:
		Props.cyl(g, Vector3(0, 0.06, z), 0.063, 0.012, "iron", Vector3(90, 0, 0))
	Props.obox(g, Vector3(0.1, 0.005, 0.0), Vector3(0.02, 0.006, 0.5), "leather", Vector3(0, 35, 0))


## A leather map case, open, its flap hanging.
static func map_case(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "MapCase", pos, yaw)
	Props.block(g, Vector3(-0.13, 0, -0.1), Vector3(0.13, 0.03, 0.1), "leather")
	Props.obox(g, Vector3(0, 0.03, -0.17), Vector3(0.26, 0.006, 0.14), "leather", Vector3(-12, 0, 0))
	Props.block(g, Vector3(-0.1, 0.03, -0.06), Vector3(0.06, 0.034, 0.06), "paper")


## A Feldgrau greatcoat dropped over a chair back or a bench: a slumped drape.
static func coat_drape(parent: Node3D, pos: Vector3, yaw: float, key: String = "feldgrau") -> void:
	var g: Node3D = Props.group(parent, "CoatDrape", pos, yaw)
	Props.obox(g, Vector3(0, 0, 0), Vector3(0.48, 0.07, 0.22), key, Vector3(0, 0, 0))
	Props.obox(g, Vector3(0, -0.28, 0.1), Vector3(0.46, 0.55, 0.05), key, Vector3(-12, 0, 0))
	Props.obox(g, Vector3(0, -0.25, -0.1), Vector3(0.42, 0.5, 0.05), key, Vector3(10, 0, 0))
	Props.obox(g, Vector3(0.24, -0.2, 0.0), Vector3(0.07, 0.45, 0.07), key, Vector3(0, 0, -8))   # a sleeve


# ================================================================== the family's things

## Lene's apron on an iron hook (`pos` = the hook on the wall face; the apron hangs in front, local -Z out).
static func apron_on_hook(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "Apron", pos, yaw)
	Props.block(g, Vector3(-0.015, -0.02, -0.06), Vector3(0.015, 0.02, 0.0), "iron")    # hook
	Props.obox(g, Vector3(0, -0.07, -0.05), Vector3(0.012, 0.12, 0.012), "apron", Vector3(10, 0, 0))   # neck loop
	Props.obox(g, Vector3(0, -0.24, -0.045), Vector3(0.24, 0.24, 0.015), "apron", Vector3(4, 0, 0))     # bib
	Props.obox(g, Vector3(0, -0.66, -0.05), Vector3(0.46, 0.62, 0.018), "apron", Vector3(3, 0, 1.5))    # skirt
	Props.obox(g, Vector3(0, -0.6, -0.065), Vector3(0.2, 0.16, 0.01), "apron", Vector3(3, 0, 0))        # pocket
	for s: float in [-1.0, 1.0]:   # the ties hanging down
		Props.obox(g, Vector3(s * 0.2, -0.55, -0.04), Vector3(0.025, 0.45, 0.006), "apron", Vector3(0, 0, s * 6.0))


## A long Sunday dress on a wooden hanger (`pos` = the hanger's hook): buttoned, long-sleeved, high-necked,
## ankle-length (the period clothing rule, HOMAGE_BOSSES 1.2). Local -Z is its front.
static func dress_on_hanger(parent: Node3D, pos: Vector3, yaw: float, key: String = "cloth_navy") -> void:
	var g: Node3D = Props.group(parent, "Dress", pos, yaw)
	Props.obox(g, Vector3(0, -0.03, 0), Vector3(0.01, 0.06, 0.01), "iron")
	Props.obox(g, Vector3(0, -0.07, 0), Vector3(0.4, 0.025, 0.03), "furniture")         # hanger
	Props.obox(g, Vector3(0, -0.1, -0.01), Vector3(0.09, 0.06, 0.07), "cloth_cream")   # the high collar
	Props.obox(g, Vector3(0, -0.32, 0), Vector3(0.36, 0.42, 0.1), key)                 # bodice
	for s: float in [-1.0, 1.0]:
		Props.obox(g, Vector3(s * 0.2, -0.38, 0.0), Vector3(0.07, 0.52, 0.08), key, Vector3(0, 0, s * 4.0))   # sleeves
		Props.obox(g, Vector3(s * 0.21, -0.65, 0.0), Vector3(0.06, 0.04, 0.07), "cloth_cream")              # cuffs
	for k: int in 5:   # the button placket
		Props.cyl(g, Vector3(0, -0.16 - k * 0.075, -0.052), 0.008, 0.005, "brass", Vector3(90, 0, 0))
	Props.obox(g, Vector3(0, -0.55, 0), Vector3(0.32, 0.04, 0.1), "beam")              # a narrow belt
	Props.obox(g, Vector3(0, -0.77, 0), Vector3(0.4, 0.4, 0.12), key)                  # the skirt, flaring...
	Props.obox(g, Vector3(0, -1.15, 0), Vector3(0.5, 0.4, 0.14), key)                  # ...to the ankle
	Props.obox(g, Vector3(0, -1.33, 0), Vector3(0.52, 0.04, 0.15), "beam")             # a hem band


## A cardigan folded at the foot of a bed (`pos` on the blanket), one sleeve hanging over the edge (+Z).
static func cardigan_folded(parent: Node3D, pos: Vector3, yaw: float, key: String = "cloth_cream") -> void:
	var g: Node3D = Props.group(parent, "Cardigan", pos, yaw)
	Props.block(g, Vector3(-0.22, 0, -0.16), Vector3(0.22, 0.05, 0.16), key)
	Props.obox(g, Vector3(0.1, -0.12, 0.2), Vector3(0.07, 0.3, 0.05), key, Vector3(-20, 0, 0))


## A pair of shoes side by side (`pos` on the floor; toes toward -Z).
static func shoes(parent: Node3D, pos: Vector3, yaw: float, key: String = "leather") -> void:
	var g: Node3D = Props.group(parent, "Shoes", pos, yaw)
	for s: float in [-0.055, 0.055]:
		Props.block(g, Vector3(s - 0.04, 0, -0.12), Vector3(s + 0.04, 0.055, 0.12), key)
		Props.block(g, Vector3(s - 0.042, 0, 0.06), Vector3(s + 0.042, 0.1, 0.12), key)   # heel counter / ankle


## An open suitcase with folded things in it (`pos` on its resting surface; the lid stands up at +Z).
static func suitcase_open(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "Suitcase", pos, yaw)
	Props.block(g, Vector3(-0.3, 0, -0.2), Vector3(0.3, 0.13, 0.2), "leather")
	Props.block(g, Vector3(-0.27, 0.13, -0.17), Vector3(0.27, 0.131, 0.17), "linen")
	Props.block(g, Vector3(-0.25, 0.13, -0.15), Vector3(0.0, 0.17, 0.12), "cloth_cream")
	Props.block(g, Vector3(0.02, 0.13, -0.14), Vector3(0.25, 0.16, 0.13), "cloth_navy")
	Props.obox(g, Vector3(0, 0.3, 0.23), Vector3(0.6, 0.36, 0.05), "leather", Vector3(-12, 0, 0))   # the lid
	for x: float in [-0.2, 0.2]:
		Props.block(g, Vector3(x - 0.025, 0.03, -0.205), Vector3(x + 0.025, 0.08, -0.198), "brass")


## Alix's red ribbon, untied, beside a hairbrush (`pos` on a surface).
static func ribbon_and_brush(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "Ribbon", pos, yaw)
	Props.obox(g, Vector3(-0.04, 0.003, 0), Vector3(0.26, 0.004, 0.03), "ribbon_red", Vector3(0, 18, 0))
	Props.obox(g, Vector3(0.09, 0.003, 0.05), Vector3(0.16, 0.004, 0.028), "ribbon_red", Vector3(0, -40, 0))
	Props.block(g, Vector3(0.05, 0, -0.12), Vector3(0.16, 0.03, -0.06), "furniture")   # the brush back
	Props.block(g, Vector3(0.16, 0.005, -0.1), Vector3(0.26, 0.02, -0.08), "furniture")   # its handle


## A straw tick rolled up with a blanket round it, standing in a corner.
static func rolled_mattress(parent: Node3D, pos: Vector3) -> void:
	Props.cyl(parent, pos + Vector3(0, 0.45, 0), 0.17, 0.9, "linen")
	Props.cyl(parent, pos + Vector3(0, 0.45, 0), 0.18, 0.3, "cloth_red")


# ================================================================== wear

## A thin stain layer on an axis-aligned face. `a`/`b` are the min/max corners of the layer (make one axis ~0.004
## thick, a hair off the surface). Never casts shadows.
static func stain(parent: Node3D, a: Vector3, b: Vector3, key: String) -> MeshInstance3D:
	return Props.block(parent, a, b, key, false)


## Snow blown in through a broken window: a thin fan of snow on the floor under it (`pos` = the floor at the wall
## line under the window's middle, `inward` = into the room, horizontal) and a rime on the inside sill.
static func snow_blown_in(parent: Node3D, pos: Vector3, inward: Vector3, sill_y: float, wall_t: float = 0.3) -> void:
	var yaw: float = rad_to_deg(atan2(inward.x, inward.z))
	var g: Node3D = Props.group(parent, "SnowIn", pos, yaw)   # local +Z = into the room
	# soft, overlapping flattened ovals (not boxes: a straight edge reads as paper)
	Props._noshadow(Props.ball(g, Vector3(0, 0.014, wall_t * 0.5 + 0.4), Vector3(1.4, 0.006, 0.75), "snow_dust"))
	var fan: MeshInstance3D = Props._noshadow(Props.ball(g, Vector3(0.2, 0.017, wall_t * 0.5 + 0.85), Vector3(0.75, 0.006, 0.45), "snow_dust"))
	fan.rotation.y = deg_to_rad(25)
	Props._noshadow(Props.ball(g, Vector3(-0.3, 0.0, wall_t * 0.5 + 0.1), Vector3(0.55, 0.11, 0.24), "snow"))   # a little drift at the wall foot
	Props._noshadow(Props.ball(g, Vector3(0, sill_y + 0.004, wall_t * 0.5 + 0.06), Vector3(1.5, 0.012, 0.2), "snow_dust"))
