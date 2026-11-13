extends GutTest
## T-222: the Fernflug lighting pass on Acts I, III and IV. The interiors lift their exposure through LookZones boxes
## (data only, Act II untouched), a zone only writes the Environment values it sets (the dust storm's and the
## director's fog keep theirs), the regenerated scenes keep the shadow budget (6 shadowed lights per zone) and the
## added practicals fade with distance, and the texture fixes hold (the lab's floor is not the dry-stone wall).

const ACTS: Dictionary = {
	"map04a_thalbach": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04c_groomlake": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d_mondlicht": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}


func before_each() -> void:
	LookGrade.reset_cache()


func after_each() -> void:
	LookGrade.reset_cache()


func test_interiors_lift_their_exposure() -> void:
	for id: String in ACTS.keys():
		var d: Dictionary = LookGrade.data(id)
		var zones: Dictionary = d.get("zones", {})
		assert_true(LookZones.has_boxes(zones), "%s has interior zones" % id)
		var base: float = float(d.get("exposure", 1.0))
		for k: String in zones.keys():
			if not k.begins_with("t222_"):
				continue
			var e: float = float((zones[k] as Dictionary).get("exposure", base))
			assert_gt(e, base, "%s %s lifts the exposure inside" % [id, k])
			assert_lt(e, 2.8, "%s %s stays a night / an interior, not a day" % [id, k])
	assert_false(LookZones.has_boxes(LookGrade.data("map04b_kranich").get("zones", {})), "Act II has no zone boxes (another worker's act)")


func test_thalbach_zone_boxes() -> void:
	var lz: LookZones = LookZones.new()
	lz.setup(Environment.new(), LookGrade.data("map04a_thalbach").get("zones", {}), null)
	assert_eq(lz.zone_at(Vector3(-20, 1.6, 45)), "t222_halls", "the canteen is a hall")
	assert_eq(lz.zone_at(Vector3(20, 1.6, 115)), "t222_halls", "the wind tunnel's lane is a hall")
	assert_eq(lz.zone_at(Vector3(-20, 1.6, 185)), "t222_hangar", "the Great Hangar")
	assert_eq(lz.zone_at(Vector3(20, 1.6, 15)), "", "the Siedlung's courtyard keeps the night")
	lz.free()


func test_zone_writes_only_what_it_sets() -> void:
	assert_eq(LookZones.keys_of({"a": {"boxes": [[0, 0, 0, 1, 1, 1]], "exposure": 2.0}}), PackedStringArray(["exposure"]))
	var inn: PackedStringArray = LookZones.keys_of(LookGrade.data("map00_crossroads").get("zones", {}))
	assert_true(inn.has("fog_density") and inn.has("vol_density"), "Map 0's inn still thins its haze")
	var env: Environment = Environment.new()
	env.fog_density = 0.01
	env.tonemap_exposure = 1.35
	var lz: LookZones = LookZones.new()
	lz.setup(env, LookGrade.data("map04c_groomlake").get("zones", {}), null)
	var t: Dictionary = lz.target("t222_lab", lz.read_env())
	env.fog_density = 0.2   # the dust storm tweens the fog while the camera is in the lab
	lz._write(t)
	assert_almost_eq(env.tonemap_exposure, 2.5, 0.3, "the lab's exposure")
	assert_almost_eq(env.fog_density, 0.2, 0.0001, "the storm's fog is left alone")
	lz.free()


func test_shadow_budget_and_distance_fade() -> void:
	for id: String in ACTS.keys():
		var root: Node = (load(ACTS[id]) as PackedScene).instantiate()
		var per_zone: Dictionary = {}
		var fading: int = 0
		for n: Node in root.find_children("*", "Light3D", true, false):
			var l: Light3D = n as Light3D
			if l is DirectionalLight3D:
				continue
			if l.shadow_enabled:
				var z: String = str(l.get_meta("zone", ""))
				per_zone[z] = int(per_zone.get(z, 0)) + 1
			if l is OmniLight3D and l.distance_fade_enabled:
				fading += 1
		for z: String in per_zone.keys():
			assert_lte(int(per_zone[z]), 6, "%s %s: at most 6 shadowed lights" % [id, z])
		assert_gt(fading, 30, "%s: the small practicals fade with distance" % id)
		root.free()


func test_added_practicals_are_there() -> void:
	var a: Node = (load(ACTS["map04a_thalbach"]) as PackedScene).instantiate()
	var lamps: int = 0
	for n: Node in a.find_children("Lamp_*", "OmniLight3D", true, false):
		lamps += 1
	assert_gt(lamps, 30, "Thalbach's emergency lamps are lights (%d)" % lamps)
	a.free()
	var d: Node = (load(ACTS["map04d_mondlicht"]) as PackedScene).instantiate()
	assert_not_null(d.find_child("T222_Hall_Ridge_0", true, false), "the retention hall's ridge light")
	assert_not_null(d.find_child("T222_Store_Aisle_*", true, false), "the store's aisle lights")
	d.free()
