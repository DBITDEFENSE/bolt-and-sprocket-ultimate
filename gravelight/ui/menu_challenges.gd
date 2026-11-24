class_name MenuChallenges
extends MenuScreen
## Active challenges per map (3 each, rotating) and the cosmetics they and ranks unlock (equip here).

const MAPS: Array = [["map00_crossroads", "Crossroads Inn"], ["map01_kaltenbrunn", "Kaltenbrunn"]]
const KIND_NAMES: Dictionary = {"calling_card": "Calling cards", "emblem": "Emblems", "cap_style": "Bottle-cap styles",
	"menu_theme": "Menu themes", "stamp_ink": "Round-stamp inks"}


func _init() -> void:
	super._init("Challenges")
	subtitle = "Goals that pay XP. Ranks and challenges unlock the rewards at the bottom: equip them here."


func build() -> void:
	for m: Array in MAPS:
		content.add_child(MenuKit.label(str(m[1]), 26, MenuKit.VIOLET, true))
		for cid: Variant in ProfileSave.active_challenges(StringName(m[0])):
			var c: Dictionary = ProfileSave.challenge_def(str(cid))
			var prog: int = ProfileSave.challenge_progress(str(cid))
			var target: int = int(c["target"])
			var h: HBoxContainer = HBoxContainer.new()
			h.add_theme_constant_override("separation", 14)
			var b: Button = MenuKit.button("%s: %s  (%s, %d XP)" % [c["name"], c["desc"], "one match" if str(c.get("scope", "")) == "match" else "career", int(c.get("xp", 0))], Callable(), 18)
			b.custom_minimum_size = Vector2(900, 36)
			h.add_child(b)
			h.add_child(MenuKit.bar(float(prog) / float(maxi(1, target)), 180))
			h.add_child(MenuKit.label("%d/%d" % [mini(prog, target), target], 18, MenuKit.GOLD))
			content.add_child(h)
	content.add_child(MenuKit.label("Completed: %d" % (ProfileSave.profile.get("challenges_done", []) as Array).size(), 18, MenuKit.DIM))
	# cosmetics
	var by_kind: Dictionary = {}
	for u: Dictionary in ProfileSave.unlock_rows():
		if ProfileSave.is_unlocked(str(u["id"])):
			var k: String = str(u["kind"])
			if not by_kind.has(k):
				by_kind[k] = []
			(by_kind[k] as Array).append(u)
	for c2: Dictionary in GLData.load_json("res://data/gravelight/progression.json")["challenges"]["pool"]:
		if c2.has("card") and ProfileSave.is_unlocked(str(c2["card"])):
			if not by_kind.has("calling_card"):
				by_kind["calling_card"] = []
			(by_kind["calling_card"] as Array).append({"id": c2["card"], "kind": "calling_card", "name": c2["name"]})
	content.add_child(MenuKit.label("Rewards", 26, MenuKit.VIOLET, true))
	if by_kind.is_empty():
		content.add_child(MenuKit.para("Nothing unlocked yet. Ranks and challenges unlock calling cards, emblems and more.", 18, MenuKit.DIM))
	var equipped: Dictionary = ProfileSave.profile.get("equipped", {})
	for k: String in by_kind.keys():
		content.add_child(MenuKit.label(str(KIND_NAMES.get(k, k)), 20, MenuKit.GOLD))
		for u: Dictionary in by_kind[k]:
			var on: bool = str(equipped.get(k, "")) == str(u["id"])
			content.add_child(MenuKit.button(("[equipped] " if on else "") + str(u["name"]), _equip.bind(k, str(u["id"])), 18))


func _equip(kind: String, item_id: String) -> void:
	if not ProfileSave.profile.has("equipped"):
		ProfileSave.profile["equipped"] = {}
	ProfileSave.profile["equipped"][kind] = item_id
	ProfileSave.save_profile()
	rebuild()
