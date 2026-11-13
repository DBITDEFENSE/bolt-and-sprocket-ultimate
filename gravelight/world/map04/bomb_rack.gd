class_name BombRack
extends Interactable
## One of the Kranich's six bomb racks (UPDATE 07, docs/MAP4_FERNFLUG.md §4.6). Tagged with a city; a chalk mark
## (three strokes and a hook) on the seeded duds. During the bomb run the FlightController drops the racks in
## order; a player (or a bot standing by it) jams the shackle with a hold before the drop and the rack stays.
## States: armed → dropped | jammed | dud (a dropped, marked rack). The FlightController writes the flags.

enum R { ARMED, DROPPED, JAMMED, DUD }

@export var rack_index: int = 1
@export var city: String = "BOSTON"

var state: R = R.ARMED
var marked: bool = false
var run_on: bool = false
var jam_hold: float = 2.5
var _casing: Node3D
var _tag: Label3D
var _chalk: Label3D
var _bot_hold: Dictionary = {}   # pid -> seconds held


func _ready() -> void:
	interact_size = Vector3(2.8, 2.0, 2.6)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"bomb_racks")
	_casing = Props.group(self, "Casing", Vector3(0, 1.1, 0))
	Props.cyl(_casing, Vector3.ZERO, 0.45, 2.2, "steel", Vector3(0, 0, 90))
	Props.block(_casing, Vector3(-0.2, 0.45, -0.3), Vector3(0.2, 0.75, 0.3), "iron")   # the shackle
	_tag = Label3D.new()
	_tag.text = "%d · %s" % [rack_index, city]
	_tag.font_size = 36
	_tag.pixel_size = 0.004
	_tag.position = Vector3(0, 1.9, 0)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.modulate = Color(0.85, 0.82, 0.72)
	add_child(_tag)
	_chalk = Label3D.new()
	_chalk.text = "||| ⌐"
	_chalk.font_size = 48
	_chalk.pixel_size = 0.004
	_chalk.position = Vector3(0, 0.7, 0.5)
	_chalk.modulate = Color(0.95, 0.95, 0.9)
	_chalk.visible = false
	add_child(_chalk)


func set_marked(m: bool) -> void:
	marked = m
	if _chalk != null:
		_chalk.visible = m


func is_decided() -> bool:
	return state != R.ARMED


## The autopilot releases this rack: it falls through the open bay doors.
func drop() -> void:
	if state != R.ARMED:
		return
	state = R.DUD if marked else R.DROPPED
	AudioDirector.play_3d("board_slam", global_position + Vector3.UP, 4.0, -0.5)
	if _casing != null:
		var tw: Tween = create_tween()
		tw.tween_property(_casing, "position:y", -40.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: _casing.visible = false)
	_tag.modulate = Color(0.6, 0.2, 0.2) if state == R.DROPPED else Color(0.6, 0.6, 0.5)
	# T-221: the trailer moment (KranichSunset: the hatch's light, the casing falling away under the hull); visual only
	get_tree().call_group(&"bomb_drop_fx", "on_rack_dropped", self)


func jam(by_player: int) -> void:
	if state != R.ARMED:
		return
	state = R.JAMMED
	_tag.modulate = Color(0.4, 0.8, 0.5)
	AudioDirector.play_3d("board_repair", global_position + Vector3.UP, 3.0, 0.3)
	print("[bombrun] rack %d (%s) jammed by P%d" % [rack_index, city, by_player])
	if Net.is_authority():
		var fc: Node = get_tree().get_first_node_in_group(&"flight_controller")
		if fc != null:
			fc.call("rack_jammed", self)


func get_prompt(_player: Player) -> String:
	if not run_on or state != R.ARMED:
		return ""
	return "Hold [%s] to jam rack %d  ·  %s%s" % [prompt_key(&"interact"), rack_index, city, "  (chalk: a dud)" if marked else ""]


func can_interact(player: Player) -> bool:
	return run_on and state == R.ARMED and not player.downed


func hold_time(player: Player) -> float:
	var t: float = jam_hold
	if player != null and GameState.player_has_trait(player.player_id, &"deacon"):
		t *= float((GLData.table("player")["traits"] as Dictionary).get("deacon_work_speed_mult", 0.85))
	return t


func interact(player: Player) -> void:
	if not Net.is_authority() or not can_interact(player):
		return
	jam(player.player_id)
	feedback_2d(player, "buy", -2.0)
	Net.mirror(self, &"jam", [player.player_id])


## A bot standing by an armed rack during the run works the shackle too (the FlightController ticks this).
func bot_tick(bot: Player, delta: float) -> void:
	if not run_on or state != R.ARMED or bot == null or not bot.is_alive():
		return
	if bot.global_position.distance_to(global_position) > 2.4:
		_bot_hold.erase(bot.player_id)
		return
	_bot_hold[bot.player_id] = float(_bot_hold.get(bot.player_id, 0.0)) + delta
	if float(_bot_hold[bot.player_id]) >= hold_time(bot):
		jam(bot.player_id)
		Net.mirror(self, &"jam", [bot.player_id])
