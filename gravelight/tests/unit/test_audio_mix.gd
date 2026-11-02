extends GutTest
## UPDATE 10 s6 item 5 (T-162): the audio mix data. gravelight/tools_src/amb_loudness.py (run with python + numpy +
## scipy + ffmpeg) is the loudness gate (beds 8 dB under a footstep, VO 6 dB over a bed); this test pins the data it
## writes: music.ambient_trim_db names real maps, is never positive, AudioDirector applies it to the map-wide bed,
## and no zone bed of any ambience file is louder than 0 dB.

const AMB_DIR: String = "res://data/gravelight/ambience/"


func _music() -> Dictionary:
	return GLData.load_json("res://data/gravelight/audio.json")["music"]


func test_trim_names_real_maps_and_never_boosts() -> void:
	var m: Dictionary = _music()
	var trims: Dictionary = m.get("ambient_trim_db", {})
	assert_gt(trims.size(), 0, "the old maps' beds are trimmed")
	for id: String in trims:
		assert_true((m["ambient"] as Dictionary).has(id), "%s has a map bed" % id)
		assert_lte(float(trims[id]), 0.0, "%s: a trim, not a boost" % id)


func test_director_applies_the_trim() -> void:
	var ad: Node = load("res://gravelight/autoload/audio_director.gd").new()
	ad.bank = {"music": {"ambient_db": [-6.0, -2.0], "ambient_trim_db": {"mapx": -12.0}}}
	ad._map_id = &"mapx"
	ad.intensity = 1.0
	assert_almost_eq(ad._ambient_db(), -14.0, 0.01, "-2 dB top, minus the map's 12 dB trim")
	ad._map_id = &"other"
	assert_almost_eq(ad._ambient_db(), -2.0, 0.01, "no trim for a map without one")
	ad.free()


func test_zone_beds_are_not_boosted() -> void:
	for f: String in DirAccess.get_files_at(AMB_DIR):
		if not f.ends_with(".json"):
			continue
		var amb: Dictionary = GLData.load_json(AMB_DIR + f)
		for zone: String in amb.get("zones", {}):
			assert_lte(float(amb["zones"][zone].get("db", 0.0)), 0.0, "%s %s" % [f, zone])
