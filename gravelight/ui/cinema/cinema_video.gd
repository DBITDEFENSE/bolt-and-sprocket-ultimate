class_name CinemaVideo
extends CanvasLayer
## T-209 (UPDATE 12 s3): the cinema_video shot type. A cutscene definition plays video on its own timeline in two
## ways, both read by CinemaDirector:
##   a shot with `video` ("res://....ogv"; `video_from` seconds into the clip, `video_graded` when the clip is
##   already graded by tools/cinema/archive_reel.py) plays that clip for the length of the shot;
##   the definition's `videos` track ([{t0, t1, path, offset, id, graded}], what CinemaArchive gives a reel for its
##   built clips) plays each clip over its span, whatever in-engine shots run under it.
## The director's clock drives it (`at(t)` from CinemaDirector.step): the player starts at the span's own offset, runs at
## the cutscene's speed, and is put back on the clock when it drifts (a seek), so every peer's copy shows the frame its
## own director is at (online, each peer plays its own copy on the host's schedule, the way every shot does). Video and
## in-engine shots mix in one definition: the in-engine shots under a video keep running (their lines, cards, sounds,
## Gore), only their picture is covered (and the 3D of the director's viewport is switched off while it is); before and
## after a span the in-engine picture is back, so a reel can cut straight into gameplay at its end. Layer 7: over the 3D
## and the grade (6), under CinemaFilm's black and cards (8-9) and the treatment (29), under the frame (30: hold to skip).
## A clip that does not load is noted in `failed` and its span plays the in-engine shots.

const LAYER: int = 7
const DRIFT: float = 0.3

var track: Array = []
var speed: float = 1.0
var current: int = -1
var player: VideoStreamPlayer = null
var played: PackedStringArray = []   # every span shown (tests, smokes)
var failed: PackedStringArray = []
var seeks: int = 0
var _box: AspectRatioContainer = null
var _bg: ColorRect = null
var _3d_was: bool = false
var _3d_held: bool = false


## Every video of a definition in time order: the `videos` track and the shots' own `video`.
static func track_of(def: Dictionary, shots: Array[CinemaShot]) -> Array:
	var out: Array = []
	for v: Variant in def.get("videos", []):
		if v is Dictionary and str((v as Dictionary).get("path", "")) != "":
			out.append((v as Dictionary).duplicate())
	for s: CinemaShot in shots:
		var p: String = str(s.raw.get("video", ""))
		if p != "":
			out.append({"t0": s.t, "t1": s.t + s.dur, "path": p, "offset": float(s.raw.get("video_from", 0.0)),
				"id": p.get_file().get_basename(), "graded": bool(s.raw.get("video_graded", false))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t0"]) < float(b["t0"]))
	return out


## The span playing at `t` (-1: none).
static func index_at(tr: Array, t: float) -> int:
	for i: int in tr.size():
		var e: Dictionary = tr[i]
		if t >= float(e["t0"]) and t < float(e["t1"]):
			return i
	return -1


static func make(parent: Node, tr: Array, spd: float) -> CinemaVideo:
	var v: CinemaVideo = CinemaVideo.new()
	v.name = "CinemaVideo"
	v.track = tr
	v.speed = maxf(0.01, spd)
	parent.add_child(v)
	return v


## A clip as a stream: an imported / exported resource, or a raw .ogv on disk (user://, a test folder).
static func load_stream(path: String) -> VideoStream:
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is VideoStream:
			return r as VideoStream
	if FileAccess.file_exists(path):
		var s: VideoStreamTheora = VideoStreamTheora.new()
		s.file = path
		return s
	return null


func _ready() -> void:
	layer = LAYER
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = AspectRatioContainer.new()   # the clips are 16:9 (pillarboxed inside); any window shape keeps them true
	_box.ratio = 16.0 / 9.0
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = VideoStreamPlayer.new()
	player.name = "Player"
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.bus = &"Master"
	_box.add_child(player)


## The director's clock: show the span at `t` (or none), keep the player on it.
func at(t: float) -> void:
	var i: int = index_at(track, t)
	if i != current:
		_switch(i, t)
	if current >= 0 and player.is_playing():
		var want: float = _local(t)
		if absf(player.stream_position - want) > DRIFT * maxf(1.0, speed):
			player.stream_position = want
			seeks += 1


## Is a clip covering the picture now (CinemaFilm then skips the grade it already has)?
func showing() -> bool:
	return current >= 0 and _bg.visible


func showing_graded() -> bool:
	return showing() and bool((track[current] as Dictionary).get("graded", false))


func current_id() -> String:
	return str((track[current] as Dictionary).get("id", "")) if current >= 0 else ""


func _local(t: float) -> float:
	var e: Dictionary = track[current]
	return maxf(0.0, t - float(e["t0"]) + float(e.get("offset", 0.0)))


func _switch(i: int, t: float) -> void:
	current = i
	if i < 0:
		player.stop()
		_cover(false)
		return
	var e: Dictionary = track[i]
	var st: VideoStream = load_stream(str(e["path"]))
	if st == null:
		push_warning("[cinema] no video %s: the span plays in-engine" % str(e["path"]))
		if not failed.has(str(e["path"])):
			failed.append(str(e["path"]))
		current = -1
		player.stop()
		_cover(false)
		return
	player.stream = st
	player.speed_scale = speed
	player.play()
	var want: float = _local(t)
	if want > 0.05:
		player.stream_position = want
	_cover(true)
	played.append(str(e.get("id", e["path"])))


## The clip covers the picture: the director's viewport stops drawing 3D under it (back when it goes).
func _cover(on: bool) -> void:
	_bg.visible = on
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	if on and not _3d_held:
		_3d_held = true
		_3d_was = vp.disable_3d
		vp.disable_3d = true
	elif not on and _3d_held:
		_3d_held = false
		vp.disable_3d = _3d_was


func _exit_tree() -> void:
	if _3d_held:
		_cover(false)
	if player != null:
		player.stop()
