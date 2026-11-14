extends GutTest
## T-245 (the owner: "MAKE TRUDI BE ABLE TO GET PERKS, ALLOW THEM TO ALSO HAVE WONDER WEAPONS, THAT GOES FOR ANY OTHER
## BOTS LIKE HER"): every companion (the four map companions and Jakub) takes a wonder weapon from your hands and may
## pull the Requisition Crate; a calm companion drinks a tonic mid-round from its own Scrip; its damage_taken follows
## its armour tonic; the bots fire every wonder weapon in the data through a branch made for it; the squad panel shows
## a companion's own Scrip.

func _companions() -> Dictionary:
	return MapCompanion.table().get("companions", {})


func test_no_companion_refuses_a_wonder_weapon() -> void:
	for cid: Variant in _companions().keys():
		var refused: Array = (_companions()[cid] as Dictionary).get("refuses_classes", [])
		assert_false(refused.has("wonder"), "%s takes a wonder weapon" % cid)
		assert_eq(JakubCompanion.offer_rule(2, &"wonder", false, refused), "", "%s: the offer rule lets it through" % cid)
	var jr: Array = JakubCompanion.cfg().get("refuses_classes", [])
	assert_false(jr.has("wonder"), "Jakub takes a wonder weapon too")
	assert_eq(JakubCompanion.offer_rule(2, &"wonder", false, jr), "")
	assert_eq(JakubCompanion.offer_rule(1, &"wonder", false, jr), "only_gun", "still never your only gun")


func test_companions_may_pull_the_crate() -> void:
	var p: Dictionary = BotAIData.personality("jakub")
	assert_gt(float((p.get("actions", {}) as Dictionary).get("crate", 0.0)), 0.0, "the companions' personality pulls the crate")
	for cid: Variant in _companions().keys():
		assert_eq(str((_companions()[cid] as Dictionary).get("personality", "")), "jakub", "%s uses that personality" % cid)
	var b: Dictionary = MapCompanion.table().get("brain", {})
	assert_true(bool(b.get("perks", false)) and bool(b.get("shopping", false)), "map companions buy tonics and shop (T-177)")


func test_damage_taken_follows_the_armour_tonic() -> void:
	var t: Dictionary = MapCompanion.table()
	assert_almost_eq(MapCompanion.damage_mult_for([], t), 0.6, 0.001, "no tonics: the old 0.6")
	assert_almost_eq(MapCompanion.damage_mult_for([&"second_wind", &"ledger_lager"], t), 0.6, 0.001, "tonics with no armour: 0.6")
	assert_almost_eq(MapCompanion.damage_mult_for([&"ironhide_stout"], t), 1.0, 0.001, "Ironhide Stout: a squad bot's 1.0")
	assert_almost_eq(MapCompanion.damage_mult_for(["ironhide_stout"], t), 1.0, 0.001, "(String ids too)")
	for a: Variant in t.get("armour_tonics", []):
		assert_true((GLData.table("perks")["perks"] as Dictionary).has(str(a)), "%s is a tonic" % a)
		assert_gt(float(((GLData.table("perks")["perks"] as Dictionary)[str(a)] as Dictionary).get("effects", {}).get("max_health", 0.0)), 100.0,
			"%s raises max health (the reason the 0.6 goes)" % a)


func test_calm_mid_round_tonic_rule() -> void:
	var e: Dictionary = BotAIData.table("economy")
	assert_true(BotEconomy.companion_tonic_now(e, true, 0.0), "calm: a tonic")
	assert_true(BotEconomy.companion_tonic_now(e, true, 0.29))
	assert_false(BotEconomy.companion_tonic_now(e, true, 0.3), "a fight on: it covers the one it follows")
	assert_false(BotEconomy.companion_tonic_now(e, false, 0.0), "perks off: never")
	assert_false(BotEconomy.companion_tonic_now({"companion_tonics": {"mid_round": false}}, true, 0.0), "the data can turn it off")


func test_every_wonder_weapon_has_a_bot_fire_branch() -> void:
	var n: int = 0
	for wid: Variant in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		var w: WeaponInstance = WeaponInstance.create(StringName(str(wid)))
		if w == null or w.weapon_class() != &"wonder":
			continue
		n += 1
		var handled: bool = w.data.has("bell") or w.data.has("harpoon") or w.data.has("gravity") or BotAim.wonder_bolt(w)
		assert_true(handled, "%s: the bot fires it through its own branch" % wid)
	assert_gt(n, 3, "the wonder weapons are in the data")
	assert_true(BotAim.wonder_bolt(WeaponInstance.create(&"ashlight")), "the Ashlight flies as a bolt")
	assert_true(BotAim.wonder_bolt(WeaponInstance.create(&"elmsfeuer")), "the Elmsfeuer too")
	assert_false(BotAim.wonder_bolt(WeaponInstance.create(&"panzerschreck")), "a rocket keeps the old trace")
	assert_false(BotAim.wonder_bolt(WeaponInstance.create(&"thompson")))


func test_companion_tonic_talk_data() -> void:
	var t: Dictionary = MapCompanion.table()
	assert_true(bool(t.get("tonics", false)), "Talk can send a map companion for a tonic")
	assert_gt(float(t.get("tonic_range_m", 0.0)), 20.0)
	assert_ne(str(t.get("ask_joined", "")), "", "the card's line once it is with you")


func test_squad_panel_shows_a_companions_own_scrip() -> void:
	PerkManager.reset_match()
	GameState.player_ids = [1, 2]
	Economy.reset([1, 2])
	var s: NetMatch = NetMatch.new()
	for pid: int in [1, 2]:
		s.players[pid] = null
		s.coop.add(pid)
	s.companions[10] = null
	s.coop.add_companion(10)
	s.companions[11] = null
	s.coop.add_companion(11)
	Economy.award(10, 130)   # a kill opens its account (T-177)
	var by: Dictionary = {}
	for r: Dictionary in CoopHud.squad_rows(s, 1):
		by[int(r["pid"])] = r
	assert_eq(int(by[10]["scrip"]), Economy.get_scrip(10), "a companion with its own Scrip shows it")
	assert_eq(CoopHud.SquadPanel.scrip_text(by[10]), "ǂ%d" % Economy.get_scrip(10))
	assert_eq(int(by[11]["scrip"]), -1, "one with no account yet shows none")
	s.free()
	PerkManager.reset_match()
	GameState.player_ids = [1]
	Economy.reset([1])


## Online (T-138): a client's card can send the host's companion for a tonic (the whitelisted answer, as Jakub's).
func test_the_tonic_answer_is_whitelisted_online() -> void:
	var mc: MapCompanion = MapCompanion.new()
	assert_true(mc.net_callable().has("net_by_choose"))
	assert_true(mc.net_callable().has("net_by_choose_tonic"))
	assert_false(bool(mc.tonic_offer(null).get("ok", true)), "no tonic for nobody (and none before it joins)")
	mc.free()
