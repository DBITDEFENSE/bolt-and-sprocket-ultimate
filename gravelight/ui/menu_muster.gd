class_name MenuMuster
extends MenuScreen
## The Muster (T-079): rank, the XP bar and what the next ranks open, then each survivor's kit for the next match:
## the sidearm and the Field Habits (1 slot at rank 1, 2 at rank 10, 3 at rank 25). Changes save to the profile at
## once (Muster.save_loadout) and apply from the next match, from every way in (the Play flow, co-op, the dev
## launcher). Opened from the main menu, from Play after choosing a survivor, and from the co-op lobby.

const NAMES: Dictionary = {"dutch": "Dutch", "peg": "Peg", "deacon": "Deacon", "wren": "Wren"}

var character: String = "dutch"
var _note: String = ""


func _init(for_character: String = "") -> void:
	super._init("Muster")
	character = for_character if NAMES.has(for_character) else String(GameState.character_id)
	if not NAMES.has(character):
		character = "dutch"


func build() -> void:
	var prof: Dictionary = ProfileSave.profile
	_build_rank()
	if Muster.classic_rules():
		content.add_child(MenuKit.para("Classic Rules is on (Settings): everyone starts with the plain M1911 and no Field Habits. Your choices are kept for when it's off.", 18, MenuKit.INK.lightened(0.35)))
	content.add_child(MenuKit.para("Field Habits are what a soldier brings from the line: small, yours for the whole match, never bought and never lost on a down. They are not the perk tonics in the machines.", 16, MenuKit.DIM))
	# survivor tabs: one kit each
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	for c: String in NAMES.keys():
		var b: Button = MenuKit.button(("> " if c == character else "") + str(NAMES[c]), _select.bind(c), 22)
		b.custom_minimum_size = Vector2(170, 44)
		tabs.add_child(b)
	var kit: Dictionary = Muster.loadout_for(character, prof)
	content.add_child(MenuKit.label("%s  ·  Dossier level %d  ·  %s" % [NAMES[character], ProfileSave.dossier_level(StringName(character)), Muster.summary(kit)], 20, MenuKit.GOLD))
	if _note != "":
		content.add_child(MenuKit.para(_note, 18, MenuKit.INK.lightened(0.35)))
	_build_pistols(kit, prof)
	_build_habits(kit, prof)
	var spacer: Control = Control.new()
	spacer.focus_mode = Control.FOCUS_ALL   # lets a controller scroll to the bottom
	content.add_child(spacer)


func _build_rank() -> void:
	var r: int = ProfileSave.rank()
	var p: int = ProfileSave.prestige()
	var c: Dictionary = ProfileSave.curve()
	content.add_child(MenuKit.label("Rank %d%s" % [r, ("   ·   Commendation %d" % p) if p > 0 else ""], 30, MenuKit.INK.lightened(0.3), true))
	content.add_child(MenuKit.bar(ProfileSave.rank_progress(), 520))
	if r < int(c.get("max_rank", 60)):
		var into: int = int(ProfileSave.profile.get("xp", 0)) - ProfileSave.total_for_rank(r, c)
		content.add_child(MenuKit.label("%d / %d XP to rank %d   ·   XP comes from kills, rounds survived, revives, doors, challenges, intel and the easter eggs" % [
			into, ProfileSave.xp_to_next(r, c), r + 1], 16, MenuKit.DIM))
	var next: PackedStringArray = []
	for u: Dictionary in Muster.upcoming(r if p == 0 else int(c.get("max_rank", 60)), 4):
		next.append("rank %d: %s" % [int(u["rank"]), u["text"]])
	if not next.is_empty():
		content.add_child(MenuKit.para("Next: " + "   ·   ".join(next), 17, MenuKit.VIOLET))


func _build_pistols(kit: Dictionary, prof: Dictionary) -> void:
	content.add_child(MenuKit.label("Sidearm", 26, MenuKit.VIOLET, true))
	var w: Dictionary = GLData.table("weapons")["weapons"]
	for row: Dictionary in Muster.pistol_rows():
		var id: String = str(row["id"])
		var d: Dictionary = w.get(id, {})
		var open: bool = Muster.pistol_unlocked(id, prof, character)
		var on: bool = str(kit["pistol"]) == id
		var stats: String = "dmg %d · %d rds · %d rpm · reload %.1f s" % [int(d.get("damage", 0)), int(d.get("mag", 0)), int(d.get("rpm", 0)), float(d.get("reload_empty", 0.0))]
		var text: String = "%s%s   (%s)\n    %s" % ["> " if on else "   ", Muster.pistol_name(id), stats,
			str(row.get("desc", "")) if open else "[locked] " + Muster.unlock_text(row)]
		var b: Button = MenuKit.button(text, _pick_pistol.bind(id), 18)
		b.custom_minimum_size = Vector2(0, 66)
		b.disabled = not open
		content.add_child(b)


func _build_habits(kit: Dictionary, prof: Dictionary) -> void:
	var slots: int = Muster.slots_for(prof)
	var nxt: int = Muster.next_slot_rank(Muster.effective_rank(prof))
	content.add_child(MenuKit.label("Field Habits   %d / %d slots%s" % [(kit["habits"] as Array).size(), slots,
		("   (next slot at rank %d)" % nxt) if nxt > 0 else ""], 26, MenuKit.VIOLET, true))
	for row: Dictionary in Muster.habit_rows():
		var id: String = str(row["id"])
		var open: bool = Muster.habit_unlocked(id, prof, character)
		var on: bool = (kit["habits"] as Array).has(id)
		var text: String = "%s %s\n    %s" % ["[x]" if on else "[ ]", str(row.get("name", id)),
			str(row.get("desc", "")) if open else "[locked] " + Muster.unlock_text(row)]
		var b: Button = MenuKit.button(text, _toggle.bind(id), 18)
		b.custom_minimum_size = Vector2(0, 62)
		b.disabled = not open and not on
		content.add_child(b)


func _select(c: String) -> void:
	character = c
	_note = ""
	rebuild()


func _pick_pistol(id: String) -> void:
	var prof: Dictionary = ProfileSave.profile
	Muster.save_loadout(character, Muster.set_pistol(Muster.loadout_for(character, prof), id, prof, character))
	_note = ""
	rebuild()


func _toggle(id: String) -> void:
	var prof: Dictionary = ProfileSave.profile
	var res: Dictionary = Muster.toggle_habit(Muster.loadout_for(character, prof), id, prof, character)
	match str(res["result"]):
		"full":
			_note = "Every Field Habit slot is taken: take one off first."
		"locked":
			_note = "Not unlocked yet."
		_:
			_note = ""
			Muster.save_loadout(character, res["kit"])
	rebuild()
