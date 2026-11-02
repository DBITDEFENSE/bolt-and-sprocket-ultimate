extends GutTest
## Fernflug Act I's art pass (UPDATE 09 §5, T-146): the Kranich's flying-wing shell covers the act's Kranich
## colliders; the kept groups the boarding cutscene moves are still there; every light carries a zone and no zone
## has more than 6 shadowed lights (contract C4); the traps wear the Thalbach art; the sky node is placed; the
## zone ambience file names real beds for the act's real zones.

const SCENE: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const GEN: String = "res://gravelight/tools_src/gen_map04a.gd"

var _root: Node = null


func before_all() -> void:
	_root = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)


func after_all() -> void:
	if _root != null:
		_root.free()


func test_kranich_shell_covers_its_colliders() -> void:
	var gen: GDScript = load(GEN) as GDScript
	var p: Dictionary = gen.get_script_constant_map()["KRANICH_WING"]
	var at: Vector3 = gen.get_script_constant_map()["KRANICH_AT"]
	# [lo, hi] of each collider in the Kranich's frame (KranichBody, KranichWingL/R from build_geometry)
	var blocks: Array = [[Vector3(-30, 0, 165), Vector3(-10, 3.0, 205)], [Vector3(-60, 0, 175), Vector3(-30, 2.0, 195)], [Vector3(-10, 0, 175), Vector3(20, 2.0, 195)]]
	var worst: float = 99.0
	for b: Array in blocks:
		var lo: Vector3 = (b[0] as Vector3) - at
		var hi: Vector3 = (b[1] as Vector3) - at
		for i: int in 11:
			for j: int in 11:
				var x: float = lerpf(lo.x + 0.05, hi.x - 0.05, float(i) / 10.0)
				var z: float = lerpf(lo.z + 0.05, hi.z - 0.05, float(j) / 10.0)
				var s: Vector2 = GenDetail.wing_surface(x, z, p)
				worst = minf(worst, s.x - hi.y)
				assert_true(s.x >= hi.y - 0.05, "the shell covers the collider at (%.1f, %.1f): top %.2f vs %.2f" % [x, z, s.x, hi.y])
	gut.p("Kranich shell clearance over its colliders: %.2f m (worst)" % worst)
	# the ramp (x -24..-16, z 159..165) stays outside the shell's bay notch
	for rx: float in [-23.5, -20.0, -16.5]:
		for rz: float in [159.5, 162.0, 164.5]:
			assert_eq(GenDetail.wing_surface(rx - at.x, rz - at.z, p), Vector2(-1, -1), "the ramp at (%.1f, %.1f) is clear of the shell" % [rx, rz])


func test_kept_groups_for_the_boarding_cutscene() -> void:
	for n: String in ["Kranich", "KranichRamp", "GreatDoors", "CraneBridge"]:
		var node: Node = _root.find_child(n, true, false)
		assert_not_null(node, "%s is in the scene" % n)
		if node != null:
			assert_true(node.has_meta("keep"), "%s is kept out of the batching (an fx moves it)" % n)
			assert_gt(node.get_child_count(), 0, "%s has its art" % n)


func test_every_light_has_a_zone_and_the_shadow_cap_holds() -> void:
	var per_zone: Dictionary = {}
	var lights: int = 0
	for n: Node in _root.find_children("*", "Light3D", true, false):
		if n is DirectionalLight3D:
			continue
		lights += 1
		assert_true(n.has_meta("zone"), "%s has a zone meta" % n.name)
		if (n as Light3D).shadow_enabled:
			var z: String = str(n.get_meta("zone", ""))
			per_zone[z] = int(per_zone.get(z, 0)) + 1
	assert_gt(lights, 40, "the act is lit")
	for z2: String in per_zone.keys():
		assert_lte(int(per_zone[z2]), 6, "zone %s has at most 6 shadowed lights" % z2)
	var keys: Dictionary = {}
	for k: Node in _root.find_children("Key*", "SpotLight3D", true, false):
		keys[str(k.get_meta("zone", ""))] = true
	assert_eq(keys.size(), 8, "every zone has its key light (a spot from a fixture you can see)")


func test_traps_wear_the_works_art() -> void:
	var hopper: Node = _root.find_child("Trap_CoalHopper", true, false)
	var crane: Node = _root.find_child("Trap_JigCrane", true, false)
	assert_not_null(hopper)
	assert_not_null(crane)
	if hopper != null and crane != null:
		assert_eq(hopper.get("style"), &"skip")
		assert_eq(crane.get("style"), &"wing")
		assert_eq(float(hopper.get("hang_height")), 6.0, "the hopper's drop is unchanged")
		assert_eq(float(crane.get("hang_height")), 7.5, "the crane's drop is unchanged")


func test_sky_and_dressing_batches() -> void:
	assert_not_null(_root.find_child("ThalbachSky", true, false), "the sky node is placed")
	var db: Node = _root.find_child("DressBatches", true, false)
	assert_not_null(db, "the dressing is batched")
	if db != null:
		assert_between(db.get_child_count(), 100, 700, "the dressing folds into a few hundred batches")


func test_zone_ambience_names_real_beds_and_zones() -> void:
	var amb: Dictionary = GLData.load_json("res://data/gravelight/ambience/map04a.json")
	var zones: Dictionary = amb.get("zones", {})
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map04a.json")
	var audio: Dictionary = GLData.load_json("res://data/gravelight/audio.json").get("sounds", {})
	assert_eq(zones.size(), (cfg["zones"] as Dictionary).size(), "one entry per zone")
	for z: String in zones.keys():
		assert_true((cfg["zones"] as Dictionary).has(z), "%s is a map04a zone" % z)
		var e: Dictionary = zones[z]
		assert_true(audio.has(str(e["bed"])), "%s's bed %s is in audio.json" % [z, e["bed"]])
		for f: String in (audio[str(e["bed"])] as Dictionary).get("files", []):
			assert_true(FileAccess.file_exists(f) or ResourceLoader.exists(f), "%s exists" % f)
		for o: Dictionary in e.get("oneshots", []):
			assert_true(audio.has(str(o["key"])), "one-shot %s exists" % o["key"])
			assert_eq((o["every_s"] as Array).size(), 2)
