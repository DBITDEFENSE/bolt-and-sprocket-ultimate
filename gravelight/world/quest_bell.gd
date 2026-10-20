class_name QuestBell
extends Node3D
## Shootable bells for "Requiem for Kaltenbrunn".
##  kind "chapel": die Totenglocke over the altar. Shooting it with an upgraded weapon lights it amber for 90 s
##    (75 s co-op), which is what step 4 needs; if the Foreman isn't around, lighting it summons him 20 s later
##    (once per round). It can be relit after a 60 s cooldown.
##  kind "small": one of the Four Bells (step 6). Only the seeded candidate for its note exists in a match.
## Shots arrive through WeaponHolder.shootable_of(): an Area3D on the hitbox layer, with on_shot() here.

const NOTE_PITCH: Dictionary = {&"n1": 1.0, &"n2": 1.189, &"n3": 1.335, &"n4": 1.498}
## Each note has its own tuned bell recording (the pitches above are only the fallback for missing ones).
const NOTE_SOUND: Dictionary = {&"n1": "quest_bell_1", &"n2": "quest_bell_2", &"n3": "quest_bell_3", &"n4": "quest_bell_4"}
const QUEST: StringName = &"map01_requiem"

@export var kind: StringName = &"small"
@export var bell_id: StringName = &""
@export var note: StringName = &"n1"
@export var size: float = 0.5

var target_id: StringName = &""
var lit: bool = false
var _active: bool = true
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _area: Area3D
var _lit_left: float = 0.0
var _cooldown: float = 0.0
var _summon_left: float = -1.0
var _summoned_round: int = -1


func _ready() -> void:
	target_id = bell_id if bell_id != &"" else StringName(name)
	add_to_group(&"quest_bells")
	var bronze: StandardMaterial3D = Interactable.greybox_mat(Color(0.56, 0.4, 0.18))
	bronze.metallic = 0.85
	bronze.roughness = 0.38
	_glow_mat = bronze
	# a cast bell (crown, waist, sound bow, lip) in this bell's own bronze (it glows when lit), crown loop and clapper
	var h: float = size
	var mi: MeshInstance3D = InteractableArt.place(self, "qbell_%d" % int(h * 100.0), func(r: Node3D) -> void: InteractableArt.quest_bell_body(r, h))
	mi.material_override = bronze
	InteractableArt.place(self, "qbell_fit_%d" % int(h * 100.0), func(r: Node3D) -> void: InteractableArt.quest_bell_fittings(r, h))
	_light = OmniLight3D.new()
	_light.omni_range = 3.0 + size * 2.0
	_light.light_energy = 0.0
	add_child(_light)
	_area = make_shot_area(self, Vector3(size * 1.6, size * 1.3, size * 1.6), Vector3.ZERO)
	QuestManager.quest_loaded.connect(_on_quest_loaded)
	QuestManager.sequence_reset.connect(_on_sequence_reset)
	_on_quest_loaded(QUEST)


## An Area3D on the zombie_hitbox layer (hitscan and projectiles see it; nothing else does).
static func make_shot_area(parent: Node3D, box_size: Vector3, offset: Vector3) -> Area3D:
	var a: Area3D = Area3D.new()
	a.collision_layer = 1 << 3
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = box_size
	cs.shape = box
	cs.position = offset
	a.add_child(cs)
	parent.add_child(a)
	return a


func _on_quest_loaded(qid: StringName) -> void:
	if qid != QUEST or kind != &"small":
		return
	var picks: Variant = QuestManager.random_value(QUEST, "bells")
	_active = picks is Dictionary and StringName(str((picks as Dictionary).get(String(note), ""))) == bell_id
	visible = _active
	_area.collision_layer = (1 << 3) if _active else 0


func _process(delta: float) -> void:
	if kind != &"chapel" or not Net.is_authority():
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if lit:
		_lit_left -= delta
		if _lit_left <= 0.0:
			_set_lit(false)
			_cooldown = float(_cfg().get("bell_relight_cooldown", 60.0))
	if _summon_left > 0.0:
		_summon_left -= delta
		if _summon_left <= 0.0 and lit and not QuestManager.boss_alive(&"foreman"):
			var at: Array = _cfg().get("foreman_summon_point", [25, -12, 63])
			QuestManager.summon_boss(&"foreman", Vector3(float(at[0]), float(at[1]), float(at[2])))


func _cfg() -> Dictionary:
	return (GLData.table("map01") as Dictionary).get("requiem", {})


func on_shot(_weapon_id: StringName, upgraded: bool, _by_player: int) -> void:
	if not _active:
		return
	ring()
	Net.mirror(self, &"ring")
	if kind == &"chapel":
		if upgraded and not lit and _cooldown <= 0.0:
			_set_lit(true)
		return
	var res: Dictionary = QuestManager.submit(&"four_bells", String(note))
	if str(res["result"]) == "ok" or str(res["result"]) == "done":
		_glow(true)
		Net.mirror(self, &"_glow", [true])


func ring() -> void:
	if kind == &"chapel":
		AudioDirector.play_3d("bell_toll", global_position, 4.0, 0.0)
	else:
		_play_note(note, global_position, 0.0)


## A tuned note: its own bell recording, or the shared bell pitched to the note if that one is missing.
static func _play_note(n: StringName, at: Vector3, volume_db: float) -> void:
	var key: String = str(NOTE_SOUND.get(n, "quest_bell_1"))
	if AudioDirector.has_sound(key):
		AudioDirector.play_3d(key, at, volume_db, 0.0)
		return
	var p: AudioStreamPlayer3D = AudioDirector.play_3d("quest_bell_1", at, volume_db, 0.0)
	if p != null:
		p.pitch_scale = float(NOTE_PITCH.get(n, 1.0))


func _set_lit(on: bool) -> void:
	lit = on
	GameState.set_flag(&"chapel_bell_lit", on)
	_glow(on)
	Net.mirror(self, &"_net_lit", [on])
	if on:
		_lit_left = float(_cfg().get("bell_lit_solo", 90.0)) if GameState.is_solo() else float(_cfg().get("bell_lit_coop", 75.0))
		GLVO.play(&"OPR_QUEST_S4_BELL_LIT_01")
		if not QuestManager.boss_alive(&"foreman") and _summoned_round != RoundManager.current_round:
			_summoned_round = RoundManager.current_round
			_summon_left = float(_cfg().get("foreman_summon_delay", 20.0))


## Co-op client: the host lit (or the light ran out on) the Chapel bell.
func _net_lit(on: bool) -> void:
	lit = on
	_glow(on)


func _glow(on: bool) -> void:
	_glow_mat.emission_enabled = on
	_glow_mat.emission = Color(1.0, 0.65, 0.2) if kind == &"chapel" else Color(0.65, 0.3, 1.0)
	_glow_mat.emission_energy_multiplier = 3.0
	_light.light_color = _glow_mat.emission
	_light.light_energy = 2.0 if on else 0.0


func _on_sequence_reset(qid: StringName, sid: StringName) -> void:
	if qid == QUEST and sid == &"s6_bells" and kind == &"small":
		_glow(false)


## Plays a melody (array of note ids) as pitched ticks: the music box and the bells share the notes.
static func play_melody(host: Node, notes: Array, at: Vector3) -> void:
	var i: int = 0
	for n: Variant in notes:
		var nid: StringName = StringName(str(n))
		host.get_tree().create_timer(0.55 * float(i) + 0.05).timeout.connect(func() -> void: _play_note(nid, at, -4.0))
		i += 1
