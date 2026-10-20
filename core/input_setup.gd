class_name InputSetup
extends RefCounted
## Registers every action from data/input_defaults.json (plus any user overrides) in the InputMap at startup.
## Called by Game._ready(). Remapping UI (M9) edits SaveProfile.doc["input_overrides"] and calls apply().

const PAD_BUTTONS: Dictionary = {
	"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y,
	"LEFT_SHOULDER": JOY_BUTTON_LEFT_SHOULDER, "RIGHT_SHOULDER": JOY_BUTTON_RIGHT_SHOULDER,
	"LEFT_STICK": JOY_BUTTON_LEFT_STICK, "RIGHT_STICK": JOY_BUTTON_RIGHT_STICK,
	"START": JOY_BUTTON_START, "BACK": JOY_BUTTON_BACK,
	"DPAD_UP": JOY_BUTTON_DPAD_UP, "DPAD_DOWN": JOY_BUTTON_DPAD_DOWN, "DPAD_LEFT": JOY_BUTTON_DPAD_LEFT, "DPAD_RIGHT": JOY_BUTTON_DPAD_RIGHT,
}
const PAD_AXES: Dictionary = {
	"LEFT_X": JOY_AXIS_LEFT_X, "LEFT_Y": JOY_AXIS_LEFT_Y, "RIGHT_X": JOY_AXIS_RIGHT_X, "RIGHT_Y": JOY_AXIS_RIGHT_Y,
	"TRIGGER_LEFT": JOY_AXIS_TRIGGER_LEFT, "TRIGGER_RIGHT": JOY_AXIS_TRIGGER_RIGHT,
}
const MOUSE: Dictionary = {"LEFT": MOUSE_BUTTON_LEFT, "RIGHT": MOUSE_BUTTON_RIGHT, "MIDDLE": MOUSE_BUTTON_MIDDLE,
	"WHEEL_UP": MOUSE_BUTTON_WHEEL_UP, "WHEEL_DOWN": MOUSE_BUTTON_WHEEL_DOWN}
const SPECIAL_KEYS: Dictionary = {"Ctrl": KEY_CTRL, "Shift": KEY_SHIFT, "Space": KEY_SPACE, "Tab": KEY_TAB,
	"Escape": KEY_ESCAPE, "Enter": KEY_ENTER, "QuoteLeft": KEY_QUOTELEFT}


static func apply(overrides: Dictionary = {}) -> void:
	var doc: Variant = Data.table("input_defaults")
	if not (doc is Dictionary):
		return
	var actions: Dictionary = (doc as Dictionary)["actions"]
	for action: String in actions.keys():
		var spec: Dictionary = (actions[action] as Dictionary).duplicate(true)
		if overrides.has(action):
			spec.merge(overrides[action] as Dictionary, true)
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		for k: Variant in spec.get("kb", []):
			var e: InputEventKey = InputEventKey.new()
			e.physical_keycode = SPECIAL_KEYS.get(str(k), OS.find_keycode_from_string(str(k)))
			InputMap.action_add_event(action, e)
		for b: Variant in spec.get("pad", []):
			var j: InputEventJoypadButton = InputEventJoypadButton.new()
			j.button_index = PAD_BUTTONS[str(b)]
			InputMap.action_add_event(action, j)
		for ax: Variant in spec.get("axis", []):
			var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
			m.axis = PAD_AXES[str((ax as Array)[0])]
			m.axis_value = float((ax as Array)[1])
			InputMap.action_add_event(action, m)
		for mb: Variant in spec.get("mouse", []):
			var mm: InputEventMouseButton = InputEventMouseButton.new()
			mm.button_index = MOUSE[str(mb)]
			InputMap.action_add_event(action, mm)
