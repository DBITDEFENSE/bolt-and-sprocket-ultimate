class_name StreamWarm
extends RefCounted
## T-237: loads audio files in the background before they are first played. AudioDirector and the voice manager
## load a sound the first time it plays, on the main thread: 2 to 17 ms each for a sound effect, 2 to 11 ms for a
## voice line, in the frame that plays it. With a squad of bots firing, stepping, buying and talking, those first
## plays come all through a match, and each one was a hitch. This asks the engine's loader threads for the files
## a few at a time (add(), then tick() once a frame) and keeps a reference to each loaded stream, so the later
## load() by the manager is a cache hit. Nothing changes for a file that is played before its turn comes (it is
## loaded on the spot, as before) or that fails to load here.
## Not in the browser build (no loader threads there, and its memory is tight): `enabled` is false on the web.

static var enabled: bool = not OS.has_feature("web") and OS.get_environment("CZ_T237_OFF") == ""

## Files asked for at once.
var in_flight_max: int = 3
## Keep whatever loads, not only audio streams (the squad's weapon models: BotSquad._warm_models).
var any_resource: bool = false
## path -> the loaded stream (the reference that keeps it in the engine's resource cache).
var kept: Dictionary = {}

var _queue: PackedStringArray = []
var _next: int = 0
var _flight: PackedStringArray = []
var _asked: Dictionary = {}


## Queues a file (once).
func add(path: String) -> void:
	if not enabled or path == "" or _asked.has(path):
		return
	_asked[path] = true
	_queue.append(path)


func busy() -> bool:
	return _next < _queue.size() or not _flight.is_empty()


## Files still waiting or loading.
func pending() -> int:
	return _queue.size() - _next + _flight.size()


## Once a frame: takes in what finished loading, asks for the next files.
func tick() -> void:
	var i: int = 0
	while i < _flight.size():
		var p: String = _flight[i]
		var st: int = ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			i += 1
			continue
		_flight.remove_at(i)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var r: Resource = ResourceLoader.load_threaded_get(p)
			if r is AudioStream or (any_resource and r != null):
				kept[p] = r
	while _flight.size() < in_flight_max and _next < _queue.size():
		var q: String = _queue[_next]
		_next += 1
		if ResourceLoader.exists(q) and ResourceLoader.load_threaded_request(q) == OK:
			_flight.append(q)
	if _next >= _queue.size() and _next > 0:
		_queue = PackedStringArray()
		_next = 0
