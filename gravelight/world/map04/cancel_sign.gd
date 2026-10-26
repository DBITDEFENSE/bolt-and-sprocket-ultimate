class_name CancelSign
extends Node3D
## NOBODY CANCELS, three metres high, at the end of the retention hall (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md
## §6.6, T-113): one Label3D per letter so a letter can fall when a column goes dark (map04d.json "columns".sign:
## `stages` is the text after 0..3 dark columns; a letter that became a space drops to the floor and rings).
## The cancel ending puts the last letters out (`lights_out`).

@export var text: String = "NOBODY CANCELS"
@export var letter_height: float = 3.0

@export var stages: Array = []
var stage: int = 0
var _letters: Array[Label3D] = []
var _lamp: OmniLight3D


## The sign's text after `dark_count` columns went dark.
static func stage_text(stages_list: Array, dark_count: int) -> String:
	if stages_list.is_empty():
		return ""
	return str(stages_list[clampi(dark_count, 0, stages_list.size() - 1)])


func _ready() -> void:
	add_to_group(&"cancel_sign")
	var w: float = letter_height * 0.62
	var n: int = text.length()
	for i: int in n:
		var l: Label3D = Label3D.new()
		l.text = text[i]
		l.font_size = 160
		l.pixel_size = letter_height / 160.0 * 0.78
		l.modulate = Color(0.85, 0.6, 1.0, 1.0)
		l.outline_size = 12
		l.outline_modulate = Color(0.25, 0.08, 0.4, 1.0)
		l.position = Vector3((float(i) - float(n - 1) * 0.5) * w, 0, 0)
		l.shaded = false
		add_child(l)
		_letters.append(l)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, -0.5, 1.5)
	_lamp.light_color = Color(0.7, 0.4, 1.0)
	_lamp.light_energy = 2.5
	_lamp.omni_range = 16.0
	_lamp.light_volumetric_fog_energy = 1.2
	_lamp.shadow_enabled = false
	add_child(_lamp)


## The sign after `dark_count` dark columns: the letters that became spaces fall.
func set_stage(dark_count: int) -> void:
	var want: String = stage_text(stages, dark_count) if not stages.is_empty() else text
	if want.length() != text.length():
		return
	stage = dark_count
	for i: int in text.length():
		var l: Label3D = _letters[i]
		if want[i] == " " and l.text != " " and l.text != "":
			_drop(l)


func _drop(l: Label3D) -> void:
	var fall: float = global_position.y - 0.5
	var tw: Tween = create_tween()
	tw.tween_property(l, "position:y", -fall, 0.9 / maxf(0.2, sqrt(GameState.gravity_scale))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "rotation:z", deg_to_rad(randf_range(-40.0, 40.0)), 0.9)
	tw.tween_callback(func() -> void:
		AudioDirector.play_3d("board_slam", l.global_position, 2.0, 0.4)
		for pn: Node in get_tree().get_nodes_in_group(&"players"):
			if (pn as Node3D).global_position.distance_to(l.global_position) < 20.0:
				pn.set("_shake", 0.25))


## The ending: whatever is left of the sign goes out.
func lights_out() -> void:
	for l: Label3D in _letters:
		l.modulate = Color(0.2, 0.15, 0.25, 0.8)
		l.outline_modulate = Color(0.05, 0.03, 0.08, 1.0)
	if _lamp != null:
		_lamp.light_energy = 0.0


func lit_letters() -> int:
	var c: int = 0
	for l: Label3D in _letters:
		if l.text != " " and l.position.y > -0.5:
			c += 1
	return c
