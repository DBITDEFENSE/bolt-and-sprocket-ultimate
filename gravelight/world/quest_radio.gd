class_name QuestRadio
extends Interactable
## One of the 7 candidate radios for step 2a. Three are seeded live (one per zone group). Once the Core Vault
## is open (step 2a active) a live radio crackles within HEAR_M (T-181: 18 m, was 12: louder, easier to find by ear);
## using it plays its code fragment (replayable).

const QUEST: StringName = &"map01_requiem"

@export var radio_id: StringName = &""

var live: bool = false
var fragment: int = 0          # 1..3 (surface, depths, lab)
var _tick: float = 0.0
var _lamp: MeshInstance3D

const LAMP_OFF: Color = Color(0.16, 0.12, 0.08)
const HEAR_M: float = 18.0   # the crackle carries this far (the bots hear it as far: map01_requiem s2a hear_m)
var _static: AudioStreamPlayer3D   # looping crackle (child): on while calling and a player is within HEAR_M


func _ready() -> void:
	interact_size = Vector3(0.7, 0.6, 0.7)
	super._ready()
	add_to_group(&"quest_radios")
	_static = AudioDirector.make_loop_3d("radio_static", self)
	QuestManager.quest_loaded.connect(_on_quest_loaded)
	_on_quest_loaded(QUEST)


func build_greybox() -> void:
	InteractableArt.place(self, "field_radio", func(r: Node3D) -> void: InteractableArt.field_radio(r))
	# the call lamp (its own material: it blinks red while this radio is calling)
	var m: StandardMaterial3D = greybox_mat(LAMP_OFF)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp = add_box(self, Vector3(0.08, 0.08, 0.02), Vector3(-0.12, 0.2, -0.165), m)
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _on_quest_loaded(qid: StringName) -> void:
	if qid != QUEST:
		return
	live = false
	var picks: Variant = QuestManager.random_value(QUEST, "radios")
	if picks is Dictionary:
		var groups: Array = (picks as Dictionary).keys()
		groups.sort()
		for i: int in groups.size():
			if StringName(str(picks[groups[i]])) == radio_id:
				live = true
				fragment = i + 1


func _calling() -> bool:
	return live and (QuestManager.is_active(QUEST, &"s2a_radios") or QuestManager.is_step_done(QUEST, &"s2a_radios"))


func _process(delta: float) -> void:
	if not _calling():
		if _static != null and _static.playing:
			_static.stop()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = randf_range(2.5, 4.0)
		var p: Player = Net.session.local_player if Net.session != null else get_tree().get_first_node_in_group(&"players") as Player
		var near: bool = p != null and p.global_position.distance_to(global_position) < HEAR_M
		if _static != null and near != _static.playing:
			if near:
				_static.play()
			else:
				_static.stop()
		if _lamp != null:
			(_lamp.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.25, 0.15) if fmod(Time.get_ticks_msec() * 0.001, 2.0) < 1.0 else LAMP_OFF


func get_prompt(_player: Player) -> String:
	if not _calling():
		return ""
	return "Hold [%s] to listen to the radio" % prompt_key(&"interact")


func can_interact(_player: Player) -> bool:
	return _calling()


func interact(_player: Player) -> void:
	if not _calling():
		return
	GLVO.play(StringName("FAS_M1_CODE%d_01" % fragment))
	QuestManager.collect(&"quest_radio", radio_id)
	AudioDirector.play_3d("radio_tune", global_position, 0.0, 0.0)
	Net.sfx_all("radio_tune", global_position, 0.0)
