extends Zombie
## Gallery-only timing wrapper. No instrumentation in shipped zombie callbacks.
var callback_usec: int = 0
var animation_usec: int = 0

func _physics_process(delta: float) -> void:
	var start: int = Time.get_ticks_usec()
	super._physics_process(delta)
	callback_usec += Time.get_ticks_usec() - start

func _process(delta: float) -> void:
	var start: int = Time.get_ticks_usec()
	super._process(delta)
	var took: int = Time.get_ticks_usec() - start
	callback_usec += took
	animation_usec += took
