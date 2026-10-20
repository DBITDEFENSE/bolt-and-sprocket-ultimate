extends Node
## Global identity and mode switching. GAME_TITLE is the single place the working title lives.

const GAME_TITLE: String = "TERMS & CONDITIONS"
const VERSION: String = "0.0.1-m0"

enum Mode { MENU, BOLT_AND_SPROCKET, GRAVELIGHT, FINE_PRINT }

var mode: Mode = Mode.MENU


func set_mode(m: Mode) -> void:
	if m == mode:
		return
	mode = m
	EventBus.mode_changed.emit(m)
