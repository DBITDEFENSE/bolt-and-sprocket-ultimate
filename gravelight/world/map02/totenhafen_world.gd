class_name TotenhafenWorld
extends RefCounted
## Totenhafen's placed machinery (UPDATE 10 contract C2, DECISIONS T-153), attached by Totenhafen: the signal-tower
## Searchlight, the Crane Drop and its lever in the crane office, and the economy pass's two new quay spawn points
## (C2 "two new quay spawn points"; named Ground_A_QUAY_* so they rise out of the water like the first two).

const QUAY_SPAWNS: Array = [Vector3(20.5, 0.0, 1.5), Vector3(6.5, 0.0, 1.5)]
const SURF_CUTTER: String = "Surf_Cutter"
const SURF_CUTTER_POS: Vector3 = Vector3(13.5, 0.0, 1.8)   # the parapet by the sea stairs, between the two quay spawns


static func attach(t: Totenhafen) -> void:
	var sl: Dictionary = t.cfg.get("searchlight", {})
	if not sl.is_empty():
		t.place(Searchlight.new(), "Searchlight", sl.get("position", [47.2, 7.0, 37.3]), float(sl.get("yaw", 180.0)))
	var cd: Dictionary = t.cfg.get("crane_drop", {})
	if not cd.is_empty():
		var trap: CraneTrap = t.place(CraneTrap.new(), "Trap_CraneDrop", cd.get("drop", [40.0, 0.0, 70.0])) as CraneTrap
		var lever: TrapLever = TrapLever.new()
		lever.trap_path = NodePath("../" + String(trap.name))
		lever.trap_id = &"crane_drop"
		t.place(lever, "Lever_CraneDrop", cd.get("lever", [44.6, 0.0, 53.4]), float(cd.get("lever_yaw", 90.0)))
	var i: int = 2
	for p: Vector3 in QUAY_SPAWNS:
		var sp: ZombieSpawn = ZombieSpawn.new()
		sp.zone_id = &"A_QUAY"
		sp.kind = &"ground"
		sp.min_round = 1
		t.place(sp, "Ground_A_QUAY_%d" % i, p)
		i += 1
	# The sea-stair spawn the living world's cutter slip opens (map02_ambience.json cutter_slip.spawn, T-154): shut
	# until the wreck has gone over the parapet (the flag, so a late joiner and a loaded match agree).
	var sc: ZombieSpawn = ZombieSpawn.new()
	sc.zone_id = &"A_QUAY"
	sc.kind = &"ground"
	sc.min_round = 1
	sc.enabled = GameState.has_flag(&"cutter_slipped")
	t.place(sc, SURF_CUTTER, SURF_CUTTER_POS)
