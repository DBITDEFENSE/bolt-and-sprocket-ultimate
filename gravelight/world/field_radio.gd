class_name FieldRadio
extends Interactable
## The requisitioned Wehrmacht field set behind the Crossroads Inn bar. Holding use opens the tuning dial;
## locking frequencies feeds the quest's `sequence` step (target = quest_target).

@export var quest_target: StringName = &"radio_m0"
@export var quest_id: StringName = &"map00_radio"
@export var notes_step: StringName = &"s1_notes"

var _dial: CanvasLayer
var _static: AudioStreamPlayer3D   # looping static (child): short bursts only, stopped by _static_left
var _static_left: float = 0.0
var _static_db: float = 0.0


func _ready() -> void:
	interact_size = Vector3(0.7, 0.6, 0.7)
	super._ready()
	_static = AudioDirector.make_loop_3d("radio_static", self)
	if _static != null:
		_static_db = _static.volume_db
	set_process(false)


func _process(delta: float) -> void:
	_static_left -= delta
	if _static_left <= 0.0:
		if _static != null:
			_static.stop()
		set_process(false)


## A burst of static for `seconds` (the radio's own looping player, so nothing leaks).
func static_burst(seconds: float, volume_db: float = 0.0) -> void:
	if _static == null:
		return
	_static.volume_db = _static_db + volume_db
	if not _static.playing:
		_static.play()
	_static_left = seconds
	set_process(true)


func build_greybox() -> void:
	# the field set: steel case, open lid, dials, headset, whip antenna (cached); its dial window glows amber
	InteractableArt.place(self, "field_radio", func(r: Node3D) -> void: InteractableArt.field_radio(r))
	var dial: MeshInstance3D = add_box(self, Vector3(0.12, 0.07, 0.01), Vector3(-0.1, 0.2, -0.162), Mats.get_mat("lamp_amber"))
	dial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.35)
	glow.light_energy = 0.35
	glow.omni_range = 1.4
	glow.position = Vector3(-0.1, 0.25, -0.35)
	add_child(glow)


func get_prompt(_player: Player) -> String:
	if QuestManager.is_complete(quest_id):
		return ""
	return "Hold [%s] to use the radio" % prompt_key(&"interact")


func can_interact(_player: Player) -> bool:
	return not QuestManager.is_complete(quest_id)


## Co-op: the dial opens on the user's machine; locked frequencies go to the host (lock_frequency()).
func net_local() -> bool:
	return true


func net_callable() -> Array:
	return ["lock_frequency"]


func interact(player: Player) -> void:
	if not QuestManager.is_step_done(quest_id, notes_step):
		GLVO.play(&"FAS_M0_IDLE_01")
		static_burst(0.8, -4.0)
		return
	if _dial != null and is_instance_valid(_dial):
		return
	AudioDirector.play_3d("radio_tune", global_position, 0.0, 0.0)
	_dial = (load("res://gravelight/ui/radio_dial.gd") as GDScript).new() as CanvasLayer
	_dial.set("radio", self)
	_dial.set("player", player)
	get_tree().current_scene.add_child(_dial)


## Called by the dial when the player locks a frequency.
func lock_frequency(freq: String) -> String:
	var res: Dictionary = QuestManager.submit(quest_target, freq)   # a client gets a prediction
	if Net.is_client():
		if Net.session != null:
			Net.session.request_call(self, &"lock_frequency", [freq])
		match str(res["result"]):
			"ok", "done":
				AudioDirector.play_3d("buy", global_position, -2.0)
			"wrong":
				AudioDirector.play_3d("deny", global_position, 4.0)
				static_burst(1.6, 6.0)
		return str(res["result"])
	match str(res["result"]):
		"ok", "done":
			GLBus.radio_tuned.emit(int(res["index"]))
			AudioDirector.play_3d("buy", global_position, -2.0)
		"wrong":
			GLBus.radio_tuned.emit(0)
			AudioDirector.play_3d("deny", global_position, 4.0)
			static_burst(1.6, 6.0)
			# The static burst draws two extra zombies.
			if RoundManager.state == RoundManager.State.ROUND:
				RoundManager.to_spawn += 2
				RoundManager.round_total += 2
	if str(res["result"]) == "done":
		_payoff()
		Net.mirror(self, &"_payoff")
	return str(res["result"])


func _payoff() -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "GLASMACHER CALLING\nKaltenbrunn is unlocked", 4.0)
	var fire: Node = get_tree().current_scene.get_node_or_null("Hearthfire")
	if fire != null:
		var tw: Tween = create_tween()
		tw.tween_property(fire, "base_energy", 0.6, 2.0)
		tw.tween_interval(6.0)
		tw.tween_property(fire, "base_energy", 2.4, 3.0)
