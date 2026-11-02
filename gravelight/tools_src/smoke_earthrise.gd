extends "res://gravelight/tools_src/smoke_m4d_u10_base.gd"
## UPDATE 10 §3 Act IV (T-158): the Earthrise beats, headless. The violet spread grows with the act's rounds; then
## the Kündigung's cancel steps (s15_columns, s16_account, s17_manager, s18_cancel) are walked to in order and each
## one takes a quarter of the spread away (the city points shrink with it); the Operator and Wren notice; the last
## (CANCEL) turns the night side dark blue.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_earthrise.tscn

const Q: StringName = &"map04_kuendigung"


func _init() -> void:
	TAG = "earthrise"
	BOTS = 3   # Wren is in the squad


## Completes every active step of the quest until `sid` is done (the chain's earlier steps first). Max 40 passes.
func _walk_to(sid: StringName) -> bool:
	for pass_i: int in 40:
		if QuestManager.is_step_done(Q, sid):
			return true
		var moved: bool = false
		for s: Variant in QuestManager.steps_of(Q):
			var id: StringName = StringName(str((s as Dictionary).get("id", "")))
			if QuestManager.is_active(Q, id):
				QuestManager.complete_step(Q, id)
				moved = true
				break
		await _frames(2)
		if not moved:
			break
	return QuestManager.is_step_done(Q, sid)


func _body() -> void:
	var sky: EarthSky = _first(&"earth_sky") as EarthSky
	_check(sky != null and (sky.cfg.get("reverse_steps", []) as Array).size() == 4, "the Earth reads four cancel steps (map04d.json earth.reverse_steps)")
	if sky == null:
		return
	_check(QuestManager.has_quest(Q), "the Kündigung is loaded on the Moon")
	GLBus.round_started.emit(38, false)   # act round 9 (not a meteor round)
	await _frames(5)
	var full: float = sky.base_spread
	_check(full > 0.25 and is_equal_approx(sky.spread, full), "act round 9: the violet spreads (%.2f of the night side)" % full)
	var steps: Array = sky.cfg["reverse_steps"]
	for i: int in steps.size():
		var ok: bool = await _walk_to(StringName(str(steps[i])))
		await _frames(5)
		var want: float = EarthSky.reversed_spread(full, i + 1, steps.size())
		_check(ok and sky.steps_done == i + 1 and absf(sky.spread - want) < 0.03, "step %s done: the spread reverses to %.2f (%.2f)" % [str(steps[i]), want, sky.spread])
		if i == 0:
			var both: bool = await _until(func() -> bool: return _said("OPR_M4D_EARTH_DIM_01") and _said("WRN_M4D_EARTH_DIM_01"), 30.0)
			_check(both, "the Operator and Wren notice the first reversal (%s)" % str(_vo.slice(-4)))
	_check(sky.dark_blue, "CANCEL: the night side goes dark blue")
	var second: bool = await _until(func() -> bool: return _said("WRN_M4D_EARTH_DIM_02") and _said("OPR_M4D_EARTH_DIM_02"), 40.0)
	_check(second, "their second lines as it dims (%s)" % str(_vo.slice(-6)))
