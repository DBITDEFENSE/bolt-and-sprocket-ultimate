class_name RocketSite
extends RefCounted
## T-276: the launch site's few numbers the runtime needs (the generator, MapRocketGen in tools_src, places the
## pieces; these must agree with it: test_rocket_site checks). Local to the firing table's centre on the snow.

## The firing table's centre on the snow (world) and the height its ring stands at (the rocket's base).
const TABLE: Vector3 = Vector3(108.0, 0.0, 40.0)
const TABLE_TOP: float = 1.45
## The erector arm's hinge, local to the table.
const HINGE_LOCAL: Vector3 = Vector3(-1.9, 1.75, 0.0)
## The oxidiser trailer's centre, local to the table (its vent stack vapours while the rocket is fuelled).
const LOX_LOCAL: Vector3 = Vector3(-10.5, 0.0, -11.5)
## The dugout (for the siren and the count's ticks), local to the table.
const BUNKER_LOCAL: Vector3 = Vector3(9.5, 1.0, -14.0)
## The generator trailer, local to the table (its engine runs all match).
const GEN_LOCAL: Vector3 = Vector3(8.5, 1.0, 14.0)
