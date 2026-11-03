extends GutTest
## T-174 (the owner's follow-up to UPDATE 10): the main eggs' perk rewards. Requiem (Kaltenbrunn) grants every
## tonic and pours each to its top tier (`perks_max`); Letzte Fahrt (Totenhafen) raises every held tonic one tier
## (`tier_all`) and pays 7500 Scrip. Classic Rules keeps tiers off.

const PID: int = 1


func before_each() -> void:
	GameState.player_ids = [PID]
	PerkManager.reset_match()
	GLSettings.values["classic_rules"] = false


func after_each() -> void:
	GLSettings.values["classic_rules"] = false
	PerkManager.reset_match()


func _on_complete(quest: String) -> Array:
	var d: Dictionary = GLData.load_json("res://data/gravelight/quests/%s.json" % quest)
	return d.get("on_complete", [])


func test_requiem_pours_every_tonic_to_its_top_tier() -> void:
	var oc: Array = _on_complete("map01_requiem")
	var gi: int = -1
	var mi: int = -1
	for i: int in oc.size():
		if (oc[i] as Dictionary).has("grant_all_perks"):
			gi = i
		if (oc[i] as Dictionary).has("perks_max"):
			mi = i
	assert_true(gi >= 0 and mi > gi, "perks_max runs after grant_all_perks")
	PerkManager.grant_all(PID)
	var moved: int = PerkManager.raise_all_tiers(PID, -1)
	assert_gt(moved, 0, "some tonics have tiers to pour")
	for pk: Variant in PerkManager.owned(PID):
		var id: StringName = StringName(str(pk))
		var top: int = PerkManager.top_tier(id)
		if top > 1:
			assert_eq(PerkManager.tier_of(PID, id), top, "%s at its top tier" % id)


func test_letzte_fahrt_raises_every_held_tonic_one_tier() -> void:
	var oc: Array = _on_complete("map02_letzte_fahrt")
	var has_tier_all: bool = false
	var scrip: int = 0
	for a: Dictionary in oc:
		if a.has("tier_all"):
			has_tier_all = int(a["tier_all"]) == 1
		if a.has("scrip_all"):
			scrip = int(a["scrip_all"])
	assert_true(has_tier_all, "tier_all 1 in the rewards")
	assert_eq(scrip, 7500, "7500 Scrip to every player")
	PerkManager.grant_all(PID)
	var ids: Array = PerkManager.owned(PID)
	var before: Dictionary = {}
	for pk: Variant in ids:
		before[str(pk)] = PerkManager.tier_of(PID, StringName(str(pk)))
	PerkManager.raise_all_tiers(PID, 1)
	for pk: Variant in ids:
		var id: StringName = StringName(str(pk))
		var want: int = mini(PerkManager.top_tier(id), int(before[str(pk)]) + 1)
		assert_eq(PerkManager.tier_of(PID, id), want, "%s one tier up (capped)" % id)


func test_classic_rules_keeps_tiers_off() -> void:
	GLSettings.values["classic_rules"] = true
	PerkManager.grant_all(PID)
	assert_eq(PerkManager.raise_all_tiers(PID, -1), 0, "nothing moves under Classic Rules")
