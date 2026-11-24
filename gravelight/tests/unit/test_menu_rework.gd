extends GutTest
## T-267, the menu rework: plain names on every menu page, Solo without the campaign's card, the Loadout's 3D view
## of every sidearm (built, framed, facing the right way), the motion helper's limits and "Reduce motion", the
## loading clip's rules (choice, minimum time, the fallback with no clip file) and the campaign-only title card.

## Words a new player would not understand: none of them may be read on a menu page (identifiers may keep them).
const OLD_WORDS: PackedStringArray = ["Muster", "Field Habit", "Dossier", "Service Record", "Commendation", "Intel Archive",
	"Citation", "Test Range", "FIELD NOTE", "Lobby code"]

var _saved_profile: Dictionary = {}
var _saved_path: String = ""
var _saved_settings: Dictionary = {}
var _saved_settings_path: String = ""


func before_each() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_menu_rework_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_saved_settings = GLSettings.values.duplicate(true)
	_saved_settings_path = GLSettings.path
	GLSettings.path = "user://_test_menu_rework_settings.cfg"
	MenuMotion.force_reduced = -1
	LoadingClips.dir_override = ""
	LoadingClips.disabled = false


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GLSettings.path))
	ProfileSave.path = _saved_path
	ProfileSave.profile = _saved_profile
	GLSettings.values = _saved_settings
	GLSettings.path = _saved_settings_path
	MenuMotion.force_reduced = -1
	LoadingClips.dir_override = ""
	LoadingClips.disabled = false
	Campaign.reset()


func _texts(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for n: Node in root.find_children("*", "Control", true, false):
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
			out.append((n as Button).tooltip_text)
	return out


func _assert_plain(root: Node, what: String) -> void:
	for t: String in _texts(root):
		for w: String in OLD_WORDS:
			assert_false(t.contains(w), "%s: '%s' still reads '%s'" % [what, t.substr(0, 60), w])


# ================================================================== names

func test_no_menu_page_reads_the_old_names() -> void:
	ProfileSave.profile["xp"] = 90000   # a rank with unlock lines, a prestige offer
	for kind: GDScript in [MenuMuster, MenuArchive, MenuDossiers, MenuStats, MenuChallenges, MenuCredits, MenuSettings]:
		var s: MenuScreen = kind.new() as MenuScreen
		add_child_autofree(s)
		await wait_physics_frames(2)
		_assert_plain(s, str(s.get("_title")))
	for campaign: bool in [false, true]:
		var mc: MenuCharacter = MenuCharacter.new()
		mc.campaign_only = campaign
		add_child_autofree(mc)
		await wait_physics_frames(2)
		_assert_plain(mc, "play step 1")
		mc.call("_pick", "peg")
		await wait_physics_frames(2)
		_assert_plain(mc, "play step 2")


func test_page_titles_are_the_mainstream_ones() -> void:
	var want: Dictionary = {MenuMuster: "Loadout", MenuArchive: "Collection", MenuDossiers: "Characters", MenuStats: "Stats",
		MenuChallenges: "Challenges", MenuLobby: "Co-op", MenuCharacter: "Solo"}
	for kind: GDScript in want.keys():
		var s: MenuScreen = kind.new() as MenuScreen
		assert_eq(str(s.get("_title")), str(want[kind]))
		assert_ne(s.subtitle, "", "%s says in a plain line what it is" % str(want[kind]))
		s.free()


func test_every_main_menu_link_has_a_plain_line() -> void:
	var mm: Control = (load("res://gravelight/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(mm)
	await wait_physics_frames(3)
	var hints: Dictionary = mm.get("LINK_HINTS")
	for col: String in ["main", "play", "extras", "quit"]:
		for r: Array in mm.call("column_rows", col):
			assert_true(hints.has(str(r[0])), "%s > %s has a hint line" % [col, r[0]])
			for w: String in OLD_WORDS:
				assert_false(str(r[0]).contains(w), "the link %s" % r[0])
	var hint: Label = mm.find_child("LinkHint", true, false) as Label
	assert_not_null(hint, "the hint line under the column")
	(mm.call("link", "Loadout") as Button).grab_focus()
	await wait_physics_frames(1)
	assert_eq(hint.text, str(hints["Loadout"]), "it follows the focus")


func test_unlock_lines_use_the_new_names() -> void:
	assert_true(Array(Muster.unlocks_at_rank(10)).has("Starting perk slot 2"))
	assert_eq(Muster.summary({"pistol": "m1911", "habits": []}), "M1911  ·  no starting perks")
	assert_eq(Muster.unlock_text({"unlock": [{"rank": 8}, {"dossier": 4}]}), "Rank 8 or character level 4")


# ================================================================== the play flow

func test_solo_offers_maps_only_and_campaign_only_the_campaign() -> void:
	var solo: MenuCharacter = MenuCharacter.new()
	add_child_autofree(solo)
	await wait_physics_frames(2)
	assert_not_null(solo.find_child("Character_dutch", true, false), "step 1: the characters")
	assert_true(solo.side.visible, "with the 3D view beside them")
	assert_eq(solo.view.model_key, "c|" + String(GameState.character_id), "showing the character under the focus")
	solo.call("_pick", "wren")
	await wait_physics_frames(2)
	assert_null(solo.find_child("Card_Campaign", true, false), "Solo no longer leads with the campaign's card (the owner's cutscene)")
	var grid: Node = solo.find_child("MapCards", true, false)
	assert_eq(grid.get_child_count(), MenuCharacter.MAPS.size(), "one card per map")
	assert_false(solo.side.visible, "step 2: the cards take the width")
	for n: String in ["CharacterButton", "LoadoutButton", "BotsButton", "BotSkillButton", "BotAiButton", "EggModeButton"]:
		var b: Button = solo.find_child(n, true, false) as Button
		assert_not_null(b, n)
		assert_eq(b.focus_mode, Control.FOCUS_ALL, "%s takes the focus (controller)" % n)
	var camp: MenuCharacter = MenuCharacter.new()
	camp.campaign_only = true
	add_child_autofree(camp)
	await wait_physics_frames(2)
	camp.call("_pick", "wren")
	await wait_physics_frames(2)
	assert_not_null(camp.find_child("Card_Campaign", true, false), "Play > Campaign: its card")
	assert_eq(camp.find_child("MapCards", true, false).get_child_count(), 1, "and nothing else")


func test_step_line() -> void:
	assert_true(MenuCharacter.step_text("", false).begins_with("STEP 1 OF 2"))
	assert_true(MenuCharacter.step_text("Wren", false).contains("WREN") and MenuCharacter.step_text("Wren", false).contains("MAP"))
	assert_true(MenuCharacter.step_text("Wren", true).contains("CAMPAIGN"))


func test_a_solo_start_is_not_a_campaign_and_plans_no_cutscene() -> void:
	Campaign.begin()
	MenuCharacter.prepare_match(false)
	assert_false(Campaign.active, "a single-map start clears the campaign")
	var h: Dictionary = LazarusCinema.hooks()
	for id: String in MapCards.ids():
		assert_eq(LazarusCinema.plan(id, {"campaign": false, "seen": []}, h).size(), 0, "%s solo: no cutscene" % id)
	MenuCharacter.prepare_match(true)
	assert_true(Campaign.active)
	assert_gt(LazarusCinema.plan(String(Campaign.first_map()), {"campaign": true, "fresh_start": true, "seen": []}, h).size(), 0,
		"the campaign still opens with its cutscenes")


func test_the_inn_title_card_is_the_campaigns() -> void:
	var tc: Dictionary = InnOpening.load_cfg().get("title_card", {})
	assert_false(tc.is_empty(), "the card's data is still there")
	assert_true(InnOpening.card_wanted(true, tc), "campaign: the letterbox and the place card")
	assert_false(InnOpening.card_wanted(false, tc), "solo / co-op: straight in, the HUD up")
	assert_false(InnOpening.card_wanted(true, {}))


func test_every_page_fits_the_screen() -> void:
	# (a wrapping label outside a page's scroll once made every page taller than the screen: the WSL render showed it)
	ProfileSave.profile["xp"] = 90000
	ProfileSave.profile["weapon_kills"] = {"m1911": 300}
	var screen: Vector2 = get_viewport().get_visible_rect().size
	for kind: GDScript in [MenuMuster, MenuArchive, MenuDossiers, MenuStats, MenuChallenges, MenuCredits, MenuSettings, MenuCharacter]:
		var s: MenuScreen = kind.new() as MenuScreen
		add_child_autofree(s)
		await wait_physics_frames(6)
		var page: Control = s.get("_page_root") as Control
		assert_lte(page.size.y, screen.y + 0.5, "%s is no taller than the screen (%s in %s)" % [s.get("_title"), page.size, screen])
		assert_lte(page.size.x, screen.x + 0.5, "%s is no wider than the screen (%s in %s)" % [s.get("_title"), page.size, screen])
		if s is MenuCharacter:
			s.call("_pick", "deacon")
			await wait_physics_frames(6)
			assert_lte(page.size.y, screen.y + 0.5, "the map step fits too (%s)" % page.size)
			assert_lte(page.size.x, screen.x + 0.5, "the map step is no wider (%s)" % page.size)
		if s is MenuMuster:
			for id: String in Muster.pistol_ids():   # the longest description must not push the panel off the page
				(s as MenuMuster).show_pistol(id)
				await wait_physics_frames(3)
				assert_lte(page.size.y, screen.y + 0.5, "the Loadout with %s shown (%s)" % [id, page.size])


# ================================================================== the loadout and its 3D view

func _corners(box: AABB) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in 8:
		out.append(box.get_endpoint(i))
	return out


func test_every_sidearm_is_built_and_framed() -> void:
	var view: MenuModelView = MenuModelView.new()
	add_child_autofree(view)
	await wait_physics_frames(2)
	var vp: Vector2 = Vector2(view.viewport.size)
	for id: String in Muster.pistol_ids():
		assert_true(view.show_weapon(id), "%s builds" % id)
		MenuMotion.finish(view)
		await wait_seconds(0.35)   # the swap
		assert_eq(view.model_key.get_slice("|", 1), id)
		var meshes: Array[Node] = view.model.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, "%s has meshes" % id)
		var box: AABB = MenuModelView.bounds_of(view.model)
		assert_gt(box.size.length(), 0.12, "%s is a pistol-sized thing (%.3f m)" % [id, box.size.length()])
		assert_lt(box.size.length(), 0.8, "%s: no stray far-away part in the frame (%.3f m)" % [id, box.size.length()])
		var widest: float = 0.0
		for t: float in [0.0, 1.4, 2.86, 5.0, 8.57]:   # the side view, on the way, the two ends of the swing (2.86 s, 8.57 s)
			view.set_time(t)
			var lo: Vector2 = Vector2(INF, INF)
			var hi: Vector2 = Vector2(-INF, -INF)
			for c: Vector3 in _corners(box):
				var world: Vector3 = view.pivot.global_transform * (view.model.transform * c)
				assert_false(view.camera.is_position_behind(world), "%s at %.1f s: in front of the camera" % [id, t])
				var px: Vector2 = view.camera.unproject_position(world)
				lo = lo.min(px)
				hi = hi.max(px)
			assert_true(lo.x >= 0.0 and lo.y >= 0.0 and hi.x <= vp.x and hi.y <= vp.y,
				"%s at %.1f s is not clipped (%s..%s in %s)" % [id, t, lo, hi, vp])
			widest = maxf(widest, (hi.x - lo.x) / vp.x)
		assert_gt(widest, 0.45, "%s is not tiny: %.0f%% of the view's width at its widest" % [id, widest * 100.0])
		for t2: float in [0.0, 2.86, 8.57, 20.0, 33.3]:   # never end-on: within 60 degrees of the side view
			assert_lt(absf(MenuModelView.yaw_at(t2, "spin", false) - PI * 0.5), deg_to_rad(50.0), "%s keeps its side to the camera" % id)
		# the opening view: the muzzle to the left of the grip, the gun's side to the camera
		view.set_time(0.0)
		var muzzle: Node3D = view.model.get_node_or_null("Muzzle") as Node3D
		assert_not_null(muzzle, "%s has its Muzzle marker" % id)
		if muzzle != null:
			var mx: float = view.camera.unproject_position(muzzle.global_position).x
			var gx: float = view.camera.unproject_position(view.model.global_position).x
			assert_lt(mx, gx - vp.x * 0.1, "%s opens side-on, muzzle to the left (muzzle %.0f, grip %.0f)" % [id, mx, gx])


func test_the_view_is_its_own_world_and_cheap() -> void:
	var view: MenuModelView = MenuModelView.new()
	add_child_autofree(view)
	await wait_physics_frames(1)
	assert_true(view.viewport.own_world_3d, "its own World3D: the menu's inn is not drawn twice")
	assert_ne(view.viewport.world_3d, get_viewport().world_3d)
	assert_ne(view.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "drawn while the page shows it")
	view.visible = false
	await wait_physics_frames(1)
	assert_eq(view.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "and not drawn at all once hidden (the container switches it off)")
	view.visible = true
	assert_true(view.viewport.transparent_bg)
	for l: Node in view.viewport.find_children("*", "Light3D", true, false):
		assert_false((l as Light3D).shadow_enabled, "no shadow passes")
	var env: Environment = (view.viewport.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	assert_false(env.sdfgi_enabled or env.ssao_enabled or env.glow_enabled or env.volumetric_fog_enabled or env.ssr_enabled,
		"nothing the Compatibility renderer lacks")


func test_the_m1911_shows_its_finish_and_attachment() -> void:
	var view: MenuModelView = MenuModelView.new()
	add_child_autofree(view)
	await wait_physics_frames(1)
	view.show_weapon("m1911")
	var plain: String = view.model_key
	var n0: int = view.swaps
	view.show_weapon("m1911")
	assert_eq(view.swaps, n0, "the same choice is not rebuilt")
	view.show_weapon("m1911", &"nickel", "mag:extended")
	assert_ne(view.model_key, plain, "a finish and an attachment are another model")
	assert_eq(view.swaps, n0 + 1)
	assert_gt(view.model.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_a_survivor_stands_in_the_view() -> void:
	var view: MenuModelView = MenuModelView.new(Vector2i(496, 560))
	add_child_autofree(view)
	await wait_physics_frames(1)
	for c: Array in MenuCharacter.CHARACTERS:
		assert_true(view.show_character(str(c[0])), "%s has a body" % c[0])
		assert_eq(view.mode, "sway")
	assert_almost_eq(MenuModelView.yaw_at(0.0, "sway", false), PI, 0.001, "facing the camera, not away")
	assert_lt(absf(MenuModelView.yaw_at(123.0, "sway", false) - PI), 0.7, "and never turning their back")


func test_fit_distance_and_sphere() -> void:
	var s: Dictionary = MenuModelView.sphere_of(AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)))
	assert_eq(s["center"], Vector3.ZERO)
	assert_almost_eq(float(s["radius"]), sqrt(3.0), 0.001)
	var near: float = MenuModelView.fit_distance(Vector3(0.03, 0.14, 0.22), 30.0, 1.6)
	assert_gt(MenuModelView.fit_distance(Vector3(0.06, 0.28, 0.44), 30.0, 1.6), near, "a bigger model stands further off")
	assert_gt(MenuModelView.fit_distance(Vector3(0.03, 0.14, 0.22), 30.0, 0.5), near, "a narrow view stands further off")
	assert_gt(MenuModelView.fit_distance(Vector3(0.03, 0.6, 0.22), 30.0, 1.6), near, "a tall model too")
	assert_gt(near, 0.07 / tan(deg_to_rad(15.0)), "its height fits with a margin")


func test_loadout_page_previews_and_equips() -> void:
	ProfileSave.profile["xp"] = 0
	var m: MenuMuster = MenuMuster.new("dutch")
	add_child_autofree(m)
	await wait_physics_frames(3)
	assert_not_null(m.view, "the 3D view beside the list")
	assert_eq(m.shown_pistol, "m1911", "opens on the equipped pistol")
	for id: String in Muster.pistol_ids():
		var b: Button = m.find_child("Pistol_" + id, true, false) as Button
		assert_not_null(b, "a row for %s" % id)
		assert_false(b.disabled, "%s can take the focus even when locked (to be looked at)" % id)
		b.grab_focus()
		await wait_physics_frames(1)
		assert_eq(m.shown_pistol, id, "the focus on %s shows it" % id)
		assert_eq(m.view.model_key.get_slice("|", 1), id)
	var locked: Button = m.find_child("Pistol_luger_p08", true, false) as Button
	locked.pressed.emit()
	await wait_physics_frames(2)
	assert_eq(str(Muster.loadout_for("dutch", ProfileSave.profile)["pistol"]), "m1911", "a locked pistol is not equipped")
	ProfileSave.profile["xp"] = 9000000
	var open: Button = m.find_child("Pistol_webley", true, false) as Button
	open.pressed.emit()
	await wait_physics_frames(2)
	assert_eq(str(Muster.loadout_for("dutch", ProfileSave.profile)["pistol"]), "webley", "an unlocked one is")
	assert_null(m.find_child("M1911_Finish", true, false), "the M1911's options only with the M1911")
	(m.find_child("Pistol_m1911", true, false) as Button).pressed.emit()
	await wait_physics_frames(2)
	assert_not_null(m.find_child("M1911_Finish", true, false))
	assert_not_null(m.find_child("M1911_Attachment", true, false))


func test_loadout_page_is_reachable_by_focus_alone() -> void:
	ProfileSave.profile["xp"] = 9000000
	var m: MenuMuster = MenuMuster.new("dutch")
	add_child_autofree(m)
	await wait_physics_frames(4)
	var seen: Dictionary = {}
	var f: Control = m.find_child("Tab_dutch", true, false) as Control
	for i: int in 80:
		if f == null:
			break
		seen[str(f.name)] = true
		f = f.find_valid_focus_neighbor(SIDE_BOTTOM)
	for id: String in Muster.pistol_ids():
		assert_true(seen.has("Pistol_" + id), "down reaches %s" % id)
	for id: String in Muster.habit_ids():
		assert_true(seen.has("Perk_" + id), "down reaches the perk %s" % id)
	assert_true(seen.has("M1911_Finish") or (m.find_child("M1911_Finish", true, false) as Button).disabled)


func test_stat_bars_and_option_steps() -> void:
	var w: Dictionary = {"a": {"damage": 40, "mag": 8, "rpm": 300, "reload_empty": 2.0}, "b": {"damage": 80, "mag": 6, "rpm": 150, "reload_empty": 4.0}}
	var a: Array = MenuMuster.stat_bars("a", w, PackedStringArray(["a", "b"]))
	assert_eq(a.size(), 4)
	assert_almost_eq(float(a[0]["frac"]), 0.5, 0.001, "half the best damage")
	assert_almost_eq(float(a[1]["frac"]), 1.0, 0.001)
	assert_almost_eq(float(a[3]["frac"]), 1.0, 0.001, "the quickest reload is the full bar")
	assert_almost_eq(float(MenuMuster.stat_bars("b", w, PackedStringArray(["a", "b"]))[3]["frac"]), 0.5, 0.001)
	assert_eq(str(a[3]["text"]), "2.0 s")
	var rows: Array = [{"id": "", "unlocked": true}, {"id": "blued", "unlocked": true}, {"id": "nickel", "unlocked": false}]
	assert_eq(MenuMuster.next_finish(rows, ""), "blued")
	assert_eq(MenuMuster.next_finish(rows, "blued"), "", "locked ones are skipped, the step wraps")
	assert_eq(MenuMuster.next_pick(["mag:extended", "grip:checkered"], ""), "mag:extended")
	assert_eq(MenuMuster.next_pick(["mag:extended", "grip:checkered"], "grip:checkered"), "", "back to none")


# ================================================================== motion

func test_motion_is_fast() -> void:
	for n: int in [1, 4, 12, 40]:
		assert_lte(MenuMotion.worst_case_s(n), 0.25, "%d rows settle within a quarter second" % n)
		assert_lte(MenuMotion.stagger_delay(n - 1, n), MenuMotion.STAGGER_MAX_S + 0.0001)
	assert_eq(MenuMotion.stagger_delay(0, 9), 0.0, "the first row is there at once")
	assert_gt(MenuMotion.stagger_delay(2, 9), MenuMotion.stagger_delay(1, 9), "one after another")
	assert_lte(MenuMotion.SCREEN_S, 0.25)
	assert_lte(MenuMotion.OUT_S, MenuMotion.SCREEN_S)
	assert_lte(MenuModelView.SWAP_OUT_S + MenuModelView.SWAP_IN_S, 0.25, "the model swap too")


func test_reduce_motion() -> void:
	assert_true(GLSettings.DEFAULTS.has("reduce_motion") if "DEFAULTS" in GLSettings else GLSettings.values.has("reduce_motion"), "the setting exists")
	assert_false(bool(GLSettings.values.get("reduce_motion", true)), "off by default")
	for preset: Variant in GLSettings.PRESETS.keys():
		assert_false((GLSettings.PRESETS[preset] as Dictionary).has("reduce_motion"), "not a graphics preset's business")
	assert_eq(MenuMotion.distance(24.0, true), 0.0, "no slide")
	assert_lte(MenuMotion.duration(0.2, true), MenuMotion.REDUCED_FADE_S)
	assert_eq(MenuMotion.stagger_delay(5, 9, true), 0.0, "no stagger")
	assert_eq(MenuModelView.yaw_at(0.0, "spin", true), MenuModelView.yaw_at(50.0, "spin", true), "the model stands still")
	assert_ne(MenuModelView.yaw_at(0.0, "spin", false), MenuModelView.yaw_at(2.0, "spin", false))
	GLSettings.values["reduce_motion"] = true
	assert_true(MenuMotion.reduced())
	var st: MenuSettings = MenuSettings.new()
	add_child_autofree(st)
	await wait_physics_frames(2)
	st.call("_set_tab", MenuSettings.TABS.find("Accessibility"))
	await wait_physics_frames(2)
	var found: bool = false
	for t: String in _texts(st):
		found = found or t == "Reduce motion"
	assert_true(found, "Settings > Accessibility offers it")


func test_feedback_never_blocks_a_button() -> void:
	var pressed: Array = [0]
	var b: Button = MenuKit.button("Go", func() -> void: pressed[0] += 1)
	add_child_autofree(b)
	await wait_physics_frames(1)
	assert_true(b.has_meta(MenuMotion.META_FX), "every kit button has the hover / press feedback")
	assert_eq(b.get_child_count(), 0, "kept out of the button's own children")
	for n: Node in b.get_children(true):
		assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "the feedback takes no input")
	b.modulate.a = 0.0   # mid-fade
	b.pressed.emit()
	assert_eq(pressed[0], 1, "a faded-in control already works")
	var list: VBoxContainer = VBoxContainer.new()
	add_child_autofree(list)
	for i: int in 5:
		list.add_child(MenuKit.button("row %d" % i, Callable()))
	MenuMotion.stagger(list)
	assert_eq((list.get_child(4) as Control).modulate.a, 0.0)
	MenuMotion.finish(list)
	assert_eq((list.get_child(4) as Control).modulate.a, 1.0, "a second press ends the motion at once")


# ================================================================== the loading clip

func test_when_a_clip_is_wanted() -> void:
	assert_true(LoadingClips.wanted(false, "map00_crossroads", false, false), "solo / co-op")
	assert_false(LoadingClips.wanted(true, "map00_crossroads", false, false), "never in the campaign")
	assert_false(LoadingClips.wanted(false, "map00_crossroads", true, false), "never in the browser")
	assert_false(LoadingClips.wanted(false, "map00_crossroads", false, true), "never on a curtain")
	assert_false(LoadingClips.wanted(false, "", false, false), "not without a map")
	assert_false(LoadingClips.wanted(false, "map00_crossroads", false, false, true), "the off switch")


func test_clip_choice() -> void:
	var files: PackedStringArray = LoadingClips.filter_clips(PackedStringArray(["load_02.ogv", "LICENSE.txt", "load_01.OGV", ".hidden.ogv", "notes.md"]), "res://x/")
	assert_eq(files, PackedStringArray(["res://x/load_01.OGV", "res://x/load_02.ogv"]), "only the clips, sorted")
	assert_eq(LoadingClips.pick(PackedStringArray(), "", 3), "", "no file: no clip")
	assert_eq(LoadingClips.pick(PackedStringArray(["a.ogv"]), "a.ogv", 7), "a.ogv", "one file: that one, again")
	for roll: int in 12:
		var p: String = LoadingClips.pick(files, files[0], roll)
		assert_eq(p, files[1], "never the one shown last when there is another")
	var seen: Dictionary = {}
	for roll: int in 12:
		seen[LoadingClips.pick(PackedStringArray(["a", "b", "c"]), "", roll)] = true
	assert_eq(seen.size(), 3, "every clip gets drawn")


func test_minimum_time_rule() -> void:
	assert_false(LoadingClips.may_leave(false, 99.0, true, 1.2), "never before the map is in")
	# the owner asked for 10 to 20 s of clip while it loads: it plays through once (the fade ends on its last frame)
	assert_false(LoadingClips.may_leave(true, 3.0, true, 1.2, 15.0), "a 15 s clip is not cut at 3 s")
	assert_false(LoadingClips.may_leave(true, 14.0, true, 1.2, 15.0))
	assert_true(LoadingClips.may_leave(true, 15.0 - LoadingClips.FADE_OUT_S, true, 1.2, 15.0), "it leaves as the clip ends")
	assert_false(LoadingClips.may_leave(true, 19.0, true, 1.2, 40.0), "a long clip: up to MAX_VIDEO_S")
	assert_true(LoadingClips.may_leave(true, LoadingClips.MAX_VIDEO_S, true, 1.2, 40.0))
	assert_true(LoadingClips.may_leave(true, LoadingClips.FALLBACK_VIDEO_S, true, 1.2, 0.0), "length unknown: the fallback")
	assert_true(LoadingClips.may_leave(true, 1.2, false, 1.2), "no clip (or skipped): the old minimum")
	assert_false(LoadingClips.may_leave(true, 1.1, false, 1.2))
	assert_between(LoadingClips.MAX_VIDEO_S, 10.0, 20.0, "10 to 20 s, as asked")
	assert_eq(LoadingScreen.MIN_SHOW_S, 1.2, "the plain screen's minimum is what it was")


func test_no_clip_file_is_the_old_loading_screen() -> void:
	LoadingClips.dir_override = "user://_t267_no_such_folder"
	assert_eq(LoadingClips.list().size(), 0)
	assert_eq(LoadingClips.choose(false, "map00_crossroads", false), "")
	var ls: LoadingScreen = (load(LoadingScreen.SCENE) as PackedScene).instantiate() as LoadingScreen
	add_child_autofree(ls)
	await wait_physics_frames(2)
	assert_null(ls.video, "no player")
	assert_null(ls.find_child("Video", true, false), "no video node in the tree")
	assert_eq(ls.get_child_count(), 4, "the background, the art, the grade and the text: as before T-267")
	assert_not_null(ls.find_child("Tip", true, false))
	assert_not_null(ls.find_child("MapName", true, false))


func test_a_broken_clip_file_is_no_clip() -> void:
	var dir: String = "user://_t267_bad_clips"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f: FileAccess = FileAccess.open(dir.path_join("load_01.ogv"), FileAccess.WRITE)
	f.store_string("this is not an Ogg file")
	f.close()
	LoadingClips.dir_override = dir
	assert_eq(LoadingClips.list().size(), 1, "the file is listed")
	assert_null(LoadingClips.open(LoadingClips.list()[0]), "but refused: not Ogg")
	var ls: LoadingScreen = (load(LoadingScreen.SCENE) as PackedScene).instantiate() as LoadingScreen
	add_child_autofree(ls)
	await wait_physics_frames(2)
	assert_null(ls.video, "the loading screen falls back to the plain one")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join("load_01.ogv")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func test_campaign_loads_keep_the_art_card() -> void:
	LoadingClips.dir_override = "user://_t267_no_such_folder"
	Campaign.begin()
	assert_eq(LoadingClips.choose(Campaign.active, "map00_crossroads", false), "", "(no file here anyway)")
	assert_false(LoadingClips.wanted(Campaign.active, "map01_kaltenbrunn", false, false), "the campaign's hops are its own")
