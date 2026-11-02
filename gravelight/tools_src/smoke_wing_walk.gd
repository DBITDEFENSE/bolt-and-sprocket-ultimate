extends "res://gravelight/tools_src/smoke_act2_lib.gd"
## UPDATE 10 §3 (T-156): the wing walk, headless. Shut at the start (region, link and hatch closed); open_now tears
## BreachL2 off for good and opens the catwalk's navmesh and the climb link (the crawlway reaches the wingtip on
## C_FLUEGEL_L's layer); the hatch climbs out: UNCLIPPED on the deck (the HUD state); a tilt throws the unclipped
## player off: downed at the hatch's foot, up again (solo, never game over); clipped at a tether post, a tilt leaves
## them standing; a zombie climbs the link up to a player on the deck; a fall off the deck is a throw too; the
## wingtip locker gives the discount token (the next tonic tier at half price).
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_wing_walk.tscn


func _init() -> void:
	tag = "wingwalk"


func _body() -> void:
	var ww: WingWalk = get_tree().get_first_node_in_group(&"wing_walks") as WingWalk
	_check(ww != null and not ww.is_open, "the wing walk is placed and shut at the start")
	if ww == null:
		return
	var region: NavigationRegion3D = _map.find_child("Nav_WingRails", true, false) as NavigationRegion3D
	_check(region != null and region.navigation_mesh != null and region.navigation_mesh.get_polygon_count() > 4, "the catwalk has its own navmesh region (an island until the link opens)")
	var hatch: WingHatch = _g("WingHatchOut") as WingHatch
	_check(hatch != null and hatch.get_prompt(_p) == "", "the hatch has no prompt while the panel holds")
	var cl: int = 1 << 2
	_check(not _path_ok(Vector3(-30, 0, 37), Vector3(-100, 3.4, 21), cl), "no way onto the wing while shut")

	ww.open_now()
	await _frames(5)
	var panel: BreachPanel = _g("BreachL2") as BreachPanel
	_check(ww.is_open and panel != null and panel.torn and panel.is_open, "open_now tears BreachL2 off for good")
	_check(region != null and region.enabled, "the catwalk's region is on")
	_check(hatch.get_prompt(_p).contains("CLIP IN"), "the hatch prompt warns: " + hatch.get_prompt(_p).get_slice("\n", 0))
	_check(_path_ok(Vector3(-30, 0, 37), Vector3(-100, 3.4, 21), cl), "the crawlway reaches the catwalk by the climb link (C_FLUEGEL_L layer)")
	_check(_path_ok(Vector3(-40, 3.4, 40), Vector3(-112, 3.4, 26), cl), "the catwalk runs from the landing to the wingtip")

	# climb out: unclipped
	await _tp(Vector3(-40, 0, 44.0), 0.0)
	hatch.interact(_p)
	await _frames(10)
	_check(WingWalk.on_deck(ww.cfg["segments"], 3.4, _p.global_position), "the hatch puts the player on the deck (%s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
	_check(ww.state_of(1) == WingWalk.ClipState.UNCLIPPED, "on the deck: UNCLIPPED")
	_check(ww._hud_label != null and ww._hud_label.visible and ww._hud_label.text.begins_with("UNCLIPPED"), "the HUD shows the state (%s)" % (ww._hud_label.text if ww._hud_label != null else "-"))
	await _secs(2.0)
	_check(_p.global_position.z < 44.2, "the wind pushes aft on the deck")

	# a tilt throws the unclipped off
	_fc.bank_side = 1.0
	_fc.bank_now()
	await _secs(1.4)
	_check(ww.knocked == 1 and _p.downed, "a tilt throws the unclipped player off: downed (knocked %d)" % ww.knocked)
	_check(_p.global_position.distance_to(Vector3(-40, 0.1, 43.2)) < 2.0, "...at the hatch's foot, inside (%s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
	await _until(func() -> bool: return not _p.downed, 6.0)
	_check(not _p.downed and GameState.phase == GameState.Phase.PLAYING, "solo: up again after the down, the match goes on")
	await _until(func() -> bool: return not _fc.banking, 8.0)

	# clipped: the tilt does nothing
	await _tp(Vector3(-40, 0, 44.0), 0.0)
	hatch.interact(_p)
	await _frames(6)
	var cp: ClipPoint = _g("ClipPoint1") as ClipPoint
	_check(cp != null and cp.get_prompt(_p).contains("clip in"), "a tether post offers the clip (%s)" % (cp.get_prompt(_p) if cp != null else "-"))
	cp.interact(_p)
	await _frames(3)
	_check(ww.is_clipped(1) and ww._hud_label.text == "CLIPPED", "clipped in: CLIPPED")
	_fc.bank_now()
	await _secs(1.6)
	_check(not _p.downed and ww.knocked == 1 and WingWalk.on_deck(ww.cfg["segments"], 3.4, _p.global_position), "clipped, the tilt leaves the player on the deck")
	await _until(func() -> bool: return not _fc.banking, 8.0)

	# the dead climb up the link to a player on the deck (the port wing is bought: B and C_L open)
	GameState.open_zone(&"B_MITTELRUMPF")
	GameState.open_zone(&"C_FLUEGEL_L")
	await _frames(3)
	await _tp(Vector3(-45, 3.45, 36.0), 90.0)
	var z: Zombie = await _zombie_on(Vector3(-36, 0, 40))
	_check(z != null, "a ganger in the port crawlway")
	if z != null:
		var up: bool = false
		for i: int in 80:
			await _secs(0.5)
			print("[wingwalk]   ganger at %s state %d" % [str(z.global_position.snapped(Vector3.ONE * 0.1)), z.state])
			if not z.is_active() or z.global_position.y > 3.0:
				up = true
				break
		_check(up and z.is_active(), "the ganger climbs the link up onto the catwalk (y %.1f)" % z.global_position.y)
		z.take_damage(z.hp + 1.0, &"torso", &"kar98k", 1, &"bullet")

	# a fall off the deck counts as a throw
	var before: int = ww.knocked
	await _tp(Vector3(-90, 3.6, 27.0), 0.0)
	await _until(func() -> bool: return ww.knocked > before, 4.0)
	_check(ww.knocked == before + 1 and _p.downed, "walking off the deck is a fall: downed at the hatch (knocked %d)" % ww.knocked)
	await _until(func() -> bool: return not _p.downed, 6.0)

	# the wingtip locker
	var chest: WingChest = _g("WingChest") as WingChest
	_check(chest != null and chest.state == WingChest.State.SHUT, "the wingtip locker is shut")
	await _tp(Vector3(-112, 3.45, 27.5), 0.0)
	chest.interact(_p)
	await _frames(3)
	chest.interact(_p)
	await _frames(3)
	_check(chest.state == WingChest.State.EMPTY and PerkManager.has_discount_token(1), "the locker gives the discount token")
	var full: int = PerkManager.tier_price(&"ironhide_stout", 2)
	_check(PerkManager.tier_price_for(1, &"ironhide_stout", 2) == full / 2, "the token halves the next tier (%d of %d)" % [PerkManager.tier_price_for(1, &"ironhide_stout", 2), full])
	PerkManager.use_discount_token(1)
	_check(PerkManager.tier_price_for(1, &"ironhide_stout", 2) == full, "spent with one tier")
