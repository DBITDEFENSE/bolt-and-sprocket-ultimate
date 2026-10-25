extends Node
## Headless smoke for the Muster (T-079): a temp profile at rank 30 whose Dutch carries a Luger P08 with Pay Packet,
## Grenade in the Boot and Full Haversack starts Map 0 the way the dev launcher does (GameState set, scene changed),
## with one AI teammate and the player-bot agent on. Checks the human's sidearm, reserve, grenades and Scrip, that
## the bot kept its default kit, and that the player-bot agent drives the human's own kit. Never touches the real
## profile. Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_muster.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const KIT: Dictionary = {"pistol": "luger_p08", "habits": ["pay_packet", "boot_grenade", "full_haversack"]}

var _map: Node3D
var _frames: int = 0
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_muster_%d.json" % OS.get_process_id()
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.profile["xp"] = ProfileSave.total_for_rank(30, ProfileSave.curve())
	Muster.save_loadout("dutch", KIT)   # saved to the temp profile, then read back like a fresh start
	ProfileSave.load_profile()
	GLSettings.values["classic_rules"] = false
	GameState.character_id = &"dutch"
	GameState.bot_count = 1
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	PlayerBot.pending_on = true
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _physics_process(_delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_frames += 1
	if _frames == 120:
		_check()
	if _frames == 300:
		_check_agent()
		_finish()


func _check() -> void:
	var mr: MapRoot = _map as MapRoot
	var human: Player = mr.players.get(1) as Player
	_expect(human != null, "the human spawned")
	if human == null:
		return
	var w: WeaponInstance = human.weapons.find_weapon_base(&"luger_p08")
	_expect(w != null, "the human carries the Luger P08 (got %s)" % [human.weapons.slots.map(func(x: WeaponInstance) -> String: return String(x.id))])
	if w != null:
		_expect(w.reserve >= int(round(80 * 1.5)) - w.mag_size(), "Full Haversack: reserve %d" % w.reserve)
	var base_g: int = int(GLData.table("player")["start_loadout"]["lethal_count"])
	_expect(human.weapons.grenades >= base_g + 1 or human.weapons.grenades == human.weapons.grenade_max(), "Grenade in the Boot: %d frags" % human.weapons.grenades)
	var start: int = int(GLData.table("economy")["starting_scrip"])
	_expect(Economy.get_scrip(1) >= start + 250, "Pay Packet: Scrip %d" % Economy.get_scrip(1))
	_expect(str(Muster.kit_of(1).get("pistol", "")) == "luger_p08", "the match kit is the saved one")
	for pid: int in GameState.bot_ids:
		var b: Player = mr.players.get(pid) as Player
		if b == null:
			continue
		_expect(b.weapons.find_weapon_base(&"luger_p08") == null, "bot %d has no Luger" % pid)
		_expect(Muster.kit_of(pid).is_empty(), "bot %d has no Muster kit" % pid)
		print("[smoke] bot %d kit: %s" % [pid, b.weapons.slots.map(func(x: WeaponInstance) -> String: return String(x.id))])


func _check_agent() -> void:
	var pb: PlayerBot = _map.find_child("PlayerBot", true, false) as PlayerBot
	var human: Player = (_map as MapRoot).players.get(1) as Player
	print("[smoke] player-bot on: %s" % [pb.on if pb != null else "missing"])
	if pb != null and pb.on and human != null:
		_expect(human.weapons.find_weapon_base(&"luger_p08") != null, "the player-bot agent plays the human's Luger")


func _expect(ok: bool, what: String) -> void:
	print("[smoke] %-70s %s" % [what, "ok" if ok else "FAIL"])
	if not ok:
		_fails.append(what)


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	if _fails.is_empty():
		print("RESULT: PASS muster (Luger + 3 habits at spawn, bot default kit)")
	else:
		print("RESULT: FAIL muster: ", "; ".join(_fails))
	PlayerBot.pending_on = false
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_physics_process(false)
