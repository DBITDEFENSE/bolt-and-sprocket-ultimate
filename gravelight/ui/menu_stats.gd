class_name MenuStats
extends MenuScreen
## Service record: rank, Commendations (prestige), career stats, best rounds, weapon mastery.

const STAT_NAMES: Array = [["matches", "Matches"], ["kills", "Kills"], ["headshots", "Headshots"], ["downs", "Times downed"],
	["revives", "Revives"], ["eggs", "Easter eggs completed"], ["rounds", "Rounds survived (total)"], ["scrip", "Scrip earned"],
	["boards", "Boards rebuilt"], ["doors", "Doors opened"]]
const CAMO_NAMES: Dictionary = {"": "-", "olive_drab": "Olive Drab", "winter": "Winter", "bronze": "Bronze", "silver": "Silver",
	"gold": "Gold", "nachtglas": "Nachtglas"}

var _confirm: bool = false


func _init() -> void:
	super._init("Service Record")


func build() -> void:
	var r: int = ProfileSave.rank()
	var p: int = ProfileSave.prestige()
	content.add_child(MenuKit.label("Rank %d%s" % [r, ("   ·   Commendation %d" % p) if p > 0 else ""], 30, MenuKit.INK.lightened(0.3), true))
	content.add_child(MenuKit.bar(ProfileSave.rank_progress(), 520))
	content.add_child(MenuKit.label("Lifetime XP: %d" % int(ProfileSave.profile.get("xp_lifetime", 0)), 18, MenuKit.DIM))
	if ProfileSave.can_prestige():
		if _confirm:
			content.add_child(MenuKit.para("Accept a Commendation? Your rank resets to 1. Unlocks, dossiers, camos and stats are kept.", 20, MenuKit.GOLD))
			var h: HBoxContainer = HBoxContainer.new()
			h.add_child(MenuKit.button("Yes, reset my rank", _do_prestige, 22, "ui_confirm"))
			h.add_child(MenuKit.button("No", _cancel_prestige, 22, "ui_back"))
			content.add_child(h)
		else:
			content.add_child(MenuKit.button("Accept a Commendation (prestige)", _ask_prestige, 22))
	var stats: Dictionary = ProfileSave.profile.get("stats", {})
	content.add_child(MenuKit.label("Career", 26, MenuKit.VIOLET, true))
	var g: GridContainer = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 60)
	content.add_child(g)
	for s: Array in STAT_NAMES:
		g.add_child(MenuKit.label(str(s[1]), 20))
		g.add_child(MenuKit.label(str(int(stats.get(s[0], 0))), 20, MenuKit.GOLD))
	g.add_child(MenuKit.label("Best round: Crossroads Inn", 20))
	g.add_child(MenuKit.label(str(ProfileSave.best_round(&"map00_crossroads")), 20, MenuKit.GOLD))
	g.add_child(MenuKit.label("Best round: Kaltenbrunn", 20))
	g.add_child(MenuKit.label(str(ProfileSave.best_round(&"map01_kaltenbrunn")), 20, MenuKit.GOLD))
	var fav: String = ProfileSave.favorite_weapon()
	g.add_child(MenuKit.label("Favorite weapon", 20))
	g.add_child(MenuKit.label(_weapon_name(fav) if fav != "" else "-", 20, MenuKit.GOLD))
	content.add_child(MenuKit.label("Weapon mastery", 26, MenuKit.VIOLET, true))
	content.add_child(MenuKit.para("Camos: Olive Drab 100 · Winter 250 · Bronze 500 · Silver 1000 · Gold 2000 kills. Gold on every weapon unlocks Nachtglas for all.", 17, MenuKit.DIM))
	var mg: GridContainer = GridContainer.new()
	mg.columns = 3
	mg.add_theme_constant_override("h_separation", 50)
	content.add_child(mg)
	for w: Variant in GLData.table("weapons")["weapons"].keys():
		var id: StringName = StringName(str(w))
		mg.add_child(MenuKit.label(_weapon_name(str(w)), 18))
		mg.add_child(MenuKit.label("%d kills" % ProfileSave.weapon_kills(id), 18, MenuKit.DIM))
		mg.add_child(MenuKit.label(str(CAMO_NAMES.get(String(ProfileSave.camo_for(id)), "-")), 18, MenuKit.GOLD))
	if content.get_child_count() > 0:
		var spacer: Control = Control.new()
		spacer.focus_mode = Control.FOCUS_ALL   # lets a controller scroll the long page
		content.add_child(spacer)


func _weapon_name(id: String) -> String:
	var w: Dictionary = GLData.table("weapons")
	if w["weapons"].has(id):
		return str(w["weapons"][id]["name"])
	if w["melee"].has(id):
		return str(w["melee"][id]["name"])
	return id


func _ask_prestige() -> void:
	_confirm = true
	rebuild()


func _cancel_prestige() -> void:
	_confirm = false
	rebuild()


func _do_prestige() -> void:
	ProfileSave.do_prestige()
	_confirm = false
	rebuild()
