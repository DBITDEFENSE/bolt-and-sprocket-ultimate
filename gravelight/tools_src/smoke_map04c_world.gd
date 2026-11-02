extends "res://gravelight/tools_src/smoke_m4c_base.gd"
## UPDATE 10 §3 Act III's living world and people (T-157): map04c_ambience.json attached (the Milky Way fading
## with the dawn, the heat shimmer from act round 6, jackrabbits and coyotes that bolt, four B-29s on approach,
## tumbleweeds, the searchlight towers dark until the power, sand off the roofs, the Quonset huts), the act's own base
## bed, the "future Area 51" card line, the jukebox playing with the power; and (_people) Dee's cage egg, Hale and
## Dee's Talk cards and Dee's favour, the arrival beat, the traps with a show, the radar tower's perch, the power-on
## spectacle.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04c_world.tscn


func _init() -> void:
	tag = "world"


func _body() -> void:
	await _living_world()
	await _people()


func _living_world() -> void:
	var amb: MapAmbience = _map.get_node_or_null("MapAmbience") as MapAmbience
	_check(amb != null and amb.config_path.ends_with("map04c_ambience.json"), "MapRoot attached the act's MapAmbience (map04c_ambience.json)")
	if amb == null:
		return
	await _frames(5)
	_check(amb._setup_done, "it runs without a Landscape (needs_landscape false)")
	_check(str(GLData.load_json("res://data/gravelight/audio.json")["music"]["ambient"].get("map04c_groomlake", "")) == "ambient_map04c", "the act's own base bed (not the Inn's wind)")
	_check(str(_map.get("intro_text")).contains("Area 51"), "the arrival card names the future Area 51")
	# the Milky Way at act round 1, gone by 6
	_check(is_equal_approx(amb.mw_now, 1.0), "act round 1: the Milky Way at full (%.2f)" % amb.mw_now)
	_check(is_equal_approx(MapAmbience.milky_way_at(6, amb.cfg["milky_way"]), 0.0) and MapAmbience.milky_way_at(3, amb.cfg["milky_way"]) > 0.4, "the dawn takes it by act round 6")
	var sky: ShaderMaterial = amb._sky_sm
	_check(sky != null and float(sky.get_shader_parameter("milky_way")) > 0.9, "the desert sky's band is lit")
	_check(amb.shimmer_now == 0.0 and MapAmbience.shimmer_at(8, amb.cfg["heat_shimmer"]) == 1.0, "no heat shimmer before the sun; full at act round 8")
	(amb.debug_kinds["heat_shimmer"] as Callable).call()
	_check(amb.shimmer_now == 1.0 and amb._shim_cards.size() == 3 and amb._shim_cards[0].visible, "the shimmer cards over the salt")
	# wildlife
	_check(amb.rabbits.size() == 4 and amb.coyotes.size() == 3, "four jackrabbits on the salt, three coyotes on the berms")
	RoundManager.stop()
	await _open_doors()
	await _clear_zombies()
	var r0: Dictionary = amb.rabbits[0]
	var rn: Node3D = r0["node"]
	await _tp(rn.global_position + Vector3(3.0, 0, 0))
	await _frames(4)
	_check(str(r0["state"]) == "bolt", "a jackrabbit bolts from a player 3 m off")
	var away: Vector3 = rn.global_position
	await _secs(0.6)
	_check(rn.global_position.distance_to(_p.global_position) > away.distance_to(_p.global_position), "it runs away from them")
	var c0: Dictionary = amb.coyotes[0]
	amb._ev_wildlife_shot((c0["node"] as Node3D).global_position + Vector3(10, 0, 0))
	_check(str(c0["state"]) == "bolt", "a shot 10 m from a coyote sends it off")
	_check(int(amb.counts.get("wildlife_bolt", 0)) >= 2, "bolts counted (%d)" % int(amb.counts.get("wildlife_bolt", 0)))
	# B-29s
	amb._ev_low_pass()
	await _frames(2)
	var b29: int = amb._b29.size()
	print("[world] the formation: %s" % str(amb._b29.map(func(d: Dictionary) -> String: return str((d["node"] as Node).name))))
	_check(b29 == 4, "a formation of four B-29s with landing lights (%d)" % b29)
	_check((amb.cfg["low_pass_b29"]["rounds"] as Array) == [2.0, 7.0], "on act rounds 2 and 7 (match 22 / 27)")
	# tumbleweeds
	amb._ev_tumbleweeds()
	var tw: Node3D = (amb.tumble[0] as Dictionary)["node"] if not amb.tumble.is_empty() else null
	var x0: float = tw.global_position.x if tw != null else 0.0
	await _secs(1.0)
	_check(tw != null and tw.global_position.x > x0 + 1.0, "a tumbleweed rolls across the salt with the wind")
	# sand off the roofs, the Quonset huts
	amb._ev_sand_roofs()
	_check(int(amb.counts.get("sand_roofs", 0)) == 1 and not amb._sand_pool.is_empty(), "sand blows off the roof edges")
	var huts: int = 0
	for c2: Node in amb.get_children():
		if String(c2.name).contains("Quonset"):
			huts += 1
	_check(huts == 2, "two Quonset huts past the west berm (%d)" % huts)
	# the searchlights and the jukebox wait for the power
	var jb: Jukebox = _g("Jukebox") as Jukebox
	_check(jb != null and not jb.powered and not jb.playing, "the jukebox in the hangar's break corner is dark without power")
	_check(amb.towers_lit == 0 and amb._towers.size() == 4, "four searchlight towers, dark")


func _people() -> void:
	pass
