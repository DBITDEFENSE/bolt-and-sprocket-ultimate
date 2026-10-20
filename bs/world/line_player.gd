class_name LinePlayer
extends Node
## Plays dialogue line ids one after another through VOManager (subtitle + voice; silent headless).
## Lines VOManager does not know (level-owned bs.* ids registered with LevelKit) are shown as subtitles.
## Non-blocking: gameplay continues while a conversation plays.

signal finished

var _queue: PackedStringArray = []
var _wait: float = 0.0
var playing: bool = false
var history: PackedStringArray = []     # every line id played (tests read this)


func play_lines(ids: PackedStringArray) -> void:
	_queue.append_array(ids)
	if not playing:
		playing = true
		_wait = 0.0


func play_line(id: String) -> void:
	play_lines(PackedStringArray([id]))


func clear() -> void:
	_queue.clear()
	playing = false


func _process(delta: float) -> void:
	if not playing:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if _queue.is_empty():
		playing = false
		finished.emit()
		return
	var id: String = _queue[0]
	_queue.remove_at(0)
	_wait = _speak(id)


## Returns how long the line stays up.
static func speak_now(id: String) -> float:
	var t: String = LevelKit.text(id)
	if VOManager.has_line(id):
		VOManager.play(id)
	else:
		EventBus.subtitle.emit("", t, Color.WHITE, 1.2 + t.length() * 0.055)
	return 1.2 + t.length() * 0.055


func _speak(id: String) -> float:
	history.append(id)
	return speak_now(id)
