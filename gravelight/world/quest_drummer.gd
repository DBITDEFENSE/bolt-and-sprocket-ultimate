class_name QuestDrummer
extends Node3D
## Herr Tamtam on the run (step 7). Marches along `route` (world points) for `seconds`, drumming.
## One hit drops the Nachtglas shard; reaching the end of the route means he escapes and the step resets
## (the crate then rolls the drummer again after a couple of uses, D-018).

const QUEST: StringName = &"map01_requiem"
const STEP: StringName = &"s7_drummer"

var route: PackedVector3Array = []
var seconds: float = 20.0
var target_id: StringName = &"herr_tamtam"
var _t: float = 0.0
var _total: float = 0.0
var _beat: float = 0.0
var _done: bool = false
var _body: Node3D


func _ready() -> void:
	add_to_group(&"quest_drummers")
	_body = Node3D.new()
	add_child(_body)
	InteractableArt.place(_body, "tin_drummer", func(r: Node3D) -> void: InteractableArt.tin_drummer(r))
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(0.7, 0.4, 1.0)
	l.light_energy = 1.2
	l.omni_range = 3.0
	l.position = Vector3(0, 0.5, 0)
	add_child(l)
	QuestBell.make_shot_area(self, Vector3(0.7, 0.9, 0.7), Vector3(0, 0.35, 0))
	for i: int in range(1, route.size()):
		_total += route[i - 1].distance_to(route[i])
	if not route.is_empty():
		global_position = route[0]
	if Net.is_authority():
		GLVO.play(&"OPR_QUEST_S7_START_01")   # relayed: the clients' copy (spawn_dynamic) stays quiet


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_beat -= delta
	if _beat <= 0.0:
		_beat = 0.45
		AudioDirector.play_3d("knife_hit", global_position + Vector3.UP * 0.3, -4.0, 0.15)
	_body.position.y = absf(sin(_t * 8.0)) * 0.05
	var k: float = clampf(_t / maxf(0.1, seconds), 0.0, 1.0)
	var pos: Vector3 = _along(k * _total)
	var dir: Vector3 = pos - global_position
	global_position = pos
	if dir.length_squared() > 0.0001:
		rotation.y = atan2(-dir.x, -dir.z)
	if _t >= seconds:
		if Net.is_authority():
			_escape()
		else:
			_done = true   # the host decides; its removal frees this copy


func _along(d: float) -> Vector3:
	if route.size() < 2:
		return global_position
	var left: float = d
	for i: int in range(1, route.size()):
		var seg: float = route[i - 1].distance_to(route[i])
		if left <= seg:
			return route[i - 1].lerp(route[i], left / maxf(seg, 0.001))
		left -= seg
	return route[route.size() - 1]


func on_shot(_weapon_id: StringName, _upgraded: bool, _by_player: int) -> void:
	if _done:
		return
	_done = true
	_caught_fx()
	Net.mirror(self, &"_caught_fx")
	var shard: QuestPickup = QuestPickup.new()
	shard.item_id = &"nachtglas_shard"
	shard.label = "the Nachtglas shard"
	shard.color = Color(0.55, 0.2, 1.0)
	get_parent().add_child(shard)
	shard.global_position = global_position
	if Net.replicating():
		Net.session.spawn_dynamic(shard, "res://gravelight/world/quest_pickup.gd",
			{"item_id": shard.item_id, "label": shard.label, "color": shard.color})
	queue_free()


func _caught_fx() -> void:
	_done = true
	AudioDirector.play_3d("board_break", global_position, 2.0)
	Effects.explosion(global_position + Vector3.UP * 0.3, 0.8)
	if _body != null:
		_body.hide()


func _escape() -> void:
	_done = true
	AudioDirector.play_3d("knife_hit", global_position, 4.0)
	QuestManager.fail(QUEST, STEP, &"escaped")
	# Make the next chance come quickly: the drummer comes back after a couple of crate uses.
	CrateManager.uses_until_move = maxi(CrateManager.uses_at_location + 1, int(GLData.table("crate").get("drummer_never_first_pulls_at_location", 2)) + 1)
	queue_free()
