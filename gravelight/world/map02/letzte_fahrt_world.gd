class_name LetzteFahrtWorld
extends Node
## Letzte Fahrt's world objects (UPDATE 10 contract C3, design section 2, DECISIONS T-153), attached by Totenhafen from
## map02.json "letzte_fahrt": the three code radios (LfRadio), the rotor machine (CipherMachine), the four log pages
## (LfPage, each at one of its two spots from the quest's seeded `log_spots`, placed when the quest loads), the three
## diesel holds (DieselHoldout), the ignition key slot and the curtain lever (QuestInteract targets `lf_key_slot` and
## `lf_curtain`), and the boat (UboatSail at the helm). When the curtain opens the dock floods to spring height.

const QUEST: StringName = &"map02_letzte_fahrt"

var t: Totenhafen
var lf: Dictionary = {}
var pages_placed: bool = false


static func attach(owner_t: Totenhafen) -> void:
	var w: LetzteFahrtWorld = LetzteFahrtWorld.new()
	w.name = "LetzteFahrt"
	owner_t.add_child(w)
	w.setup(owner_t)


func setup(owner_t: Totenhafen) -> void:
	t = owner_t
	lf = t.cfg.get("letzte_fahrt", {})
	add_to_group(&"letzte_fahrt_world")
	var radios: Dictionary = lf.get("radios", {})
	for rid: Variant in radios.keys():
		var r: LfRadio = LfRadio.new()
		r.radio_id = StringName(str(rid))
		t.place(r, "Radio_" + str(rid), radios[rid])
	if lf.has("cipher"):
		t.place(CipherMachine.new(), "CipherMachine", lf["cipher"])
	var ds: Dictionary = lf.get("diesels", {})
	for did: Variant in ds.keys():
		var c: Dictionary = ds[did]
		var d: DieselHoldout = DieselHoldout.setup_from(DieselHoldout.new(), StringName(str(did)), c)
		t.place(d, "Diesel_" + str(did), c.get("position", [0, 0, 0]), float(c.get("yaw", 0.0)))
	if lf.has("key_slot"):
		var k: QuestInteract = QuestInteract.new()
		k.target = &"lf_key_slot"
		k.label_text = "ZÜNDUNG · U-1047"
		k.prompt_text = "turn U-1047's ignition key"
		k.missing_text = "Needs: %s"
		k.flag_labels = {"boat_key": "the ignition key (the captain has it)", "lf_cipher_done": "the curtain code (the teletype)"}
		t.place(k, "KeySlot", lf["key_slot"])
		k.add_to_group(&"lf_key_slot")
	if lf.has("curtain_lever"):
		var cl: QuestInteract = QuestInteract.new()
		cl.target = &"lf_curtain"
		cl.label_text = "VORHANG"
		cl.prompt_text = "open the pen curtain"
		cl.missing_text = "Needs: %s"
		cl.flag_labels = {"lf_key_turned": "the ignition key turned in the tower"}
		t.place(cl, "CurtainLever", lf["curtain_lever"])
		cl.add_to_group(&"lf_curtain_lever")
	var boat: Dictionary = lf.get("boat", {})
	if boat.has("helm"):
		t.place(UboatSail.new(), "UboatSail", boat["helm"], float(boat.get("helm_yaw", 0.0)))
	QuestManager.quest_loaded.connect(_on_quest_loaded)
	GLBus.flag_changed.connect(_on_flag)
	if QuestManager.random_value(QUEST, "log_spots") is Dictionary:
		place_pages(QuestManager.random_value(QUEST, "log_spots"))


func _on_quest_loaded(qid: StringName) -> void:
	if qid == QUEST and not pages_placed:
		var picks: Variant = QuestManager.random_value(QUEST, "log_spots")
		place_pages(picks if picks is Dictionary else {})


## The four pages at their seeded spots (`picks`: page id -> spot name); a page without a pick takes its first spot.
func place_pages(picks: Dictionary) -> void:
	if pages_placed:
		return
	pages_placed = true
	var spots: Dictionary = lf.get("log_spots", {})
	for pid: Variant in spots.keys():
		var options: Dictionary = spots[pid]
		var name_pick: String = str(picks.get(str(pid), options.keys()[0] if not options.is_empty() else ""))
		if not options.has(name_pick):
			continue
		var p: LfPage = LfPage.new()
		p.intel_id = StringName(str(pid))
		t.place(p, "LogPage_" + str(pid), options[name_pick])


func _on_flag(flag: StringName, value: Variant) -> void:
	if flag == &"curtain_open" and bool(value):
		var tide: TideController = t.tide()
		if tide != null and Net.is_authority():
			tide.force_stage(&"spring", float(lf.get("curtain_flood_hold_s", 600.0)))
		AudioDirector.play_2d("war_crash_boom", -6.0, 0.0)
		t.banner("THE CURTAIN IS OPEN\nThe storm comes into the pen. Get aboard.", 5.0)
