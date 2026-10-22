class_name BotCommandState
extends RefCounted
## The squad command wheel's state (U02 section 5), pure so it is unit-tested: press opens it, look deltas (mouse)
## or a stick direction move the pointer inside `radius`, the segment under the pointer is the selection
## (BotConfig.wheel_index; nothing inside `deadzone`), release closes it and returns the chosen order id (from
## `order_list`, the data-driven bots.json commands.orders) or &"" when nothing was picked; cancel closes it
## without one.

var is_open: bool = false
var pointer: Vector2 = Vector2.ZERO
var radius: float = 120.0
var deadzone: float = 28.0
var order_list: Array[StringName] = []
var segments: int = 0


func _init(radius_px: float = 120.0, deadzone_px: float = 28.0, ids: Array[StringName] = BotConfig.COMMANDS) -> void:
	radius = radius_px
	deadzone = deadzone_px
	order_list = ids.duplicate()
	segments = order_list.size()


func press() -> void:
	is_open = true
	pointer = Vector2.ZERO


## A mouse delta (screen pixels, -y up on screen is negative y).
func look(rel: Vector2) -> void:
	if not is_open:
		return
	pointer += rel
	if pointer.length() > radius:
		pointer = pointer.normalized() * radius


## A stick direction (a controller): points straight at that segment while held past half way.
func stick(v: Vector2) -> void:
	if is_open and v.length() > 0.5:
		pointer = v.normalized() * radius


func selected() -> int:
	return BotConfig.wheel_index(pointer, segments, deadzone) if is_open else -1


func selected_command() -> StringName:
	var i: int = selected()
	return order_list[i] if i >= 0 and i < order_list.size() else &""


func release() -> StringName:
	var cmd: StringName = selected_command()
	cancel()
	return cmd


func cancel() -> void:
	is_open = false
	pointer = Vector2.ZERO
