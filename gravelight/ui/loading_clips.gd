class_name LoadingClips
extends RefCounted
## T-267 (the owner: "for the solo or whatever squad, have it loading in, just have like a simple video of like 10
## seconds, 20 seconds while it loads"): the short clips the loading screen plays behind its text while a Solo or
## Co-op map loads. Drop Ogg Theora files (the only video Godot plays) into assets/video/loading/ (load_01.ogv ...,
## 1280x720, 24-30 fps, 10-20 s, with the folder's LICENSE.txt and SOURCE.txt); every *.ogv there is in the draw.
## The rules, all pure and unit-tested (test_menu_rework):
##   wanted      a clip plays for a single-map match (Solo, Co-op), never in the Campaign (its loads keep the map's
##               art card, and its cutscenes are its own), never on a curtain (the endings), never in the browser
##               build (a pack fetch and a software Theora decode on one thread);
##   pick        one clip at random, not the one shown last time when there is another;
##   may_leave   the match starts when the map has loaded AND the clip has played through once (its length, at
##               most MAX_VIDEO_S; FALLBACK_VIDEO_S when the stream cannot say), or LoadingScreen.MIN_SHOW_S without a
##               clip. Accept (Enter / pad A) cuts it short once the map is in; a load longer than the clip loops it.
##               (T-267 left after MIN_VIDEO_S, 3 s: on a fast PC the owner saw three seconds of a fifteen-second clip
##               and read it as "the Higgsfield clips didn't work"; he had asked for 10 to 20 s while it loads.)
## No clip file (a fresh checkout, the browser build, a missing folder): `list` is empty and the loading screen is
## exactly what it was before T-267. Nothing about the clip is synced in co-op: every peer draws its own.

const DIR: String = "res://assets/video/loading/"
const EXT: String = "ogv"
const MIN_VIDEO_S: float = 3.0
## A clip plays through once, up to this long (the owner: "a simple Higgsfield video of 10 seconds, 20 seconds").
const MAX_VIDEO_S: float = 20.0
## When the stream cannot report its length.
const FALLBACK_VIDEO_S: float = 12.0
const FADE_IN_S: float = 0.4
const FADE_OUT_S: float = 0.35
## The names tried when a directory cannot be listed (an exported pack that does not list plain files).
const PROBE_MAX: int = 24

## Tools and tests: another folder (res://, user:// or absolute), and a switch that turns clips off.
static var dir_override: String = ""
static var disabled: bool = false
static var _last: String = ""


static func clip_dir() -> String:
	var d: String = dir_override if dir_override != "" else DIR
	return d if d.ends_with("/") else d + "/"


## Is a clip wanted for this load at all? (pure)
static func wanted(campaign_active: bool, map_id: String, is_web: bool, is_curtain: bool, is_off: bool = false) -> bool:
	return not is_off and not campaign_active and not is_web and not is_curtain and map_id != ""


## The *.ogv files of `names`, sorted, as full paths under `dir` (pure).
static func filter_clips(names: PackedStringArray, dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for n: String in names:
		if n.get_extension().to_lower() == EXT and not n.begins_with("."):
			out.append(dir.path_join(n))
	out.sort()
	return out


## Every clip in the folder ([] when it does not exist or holds none).
static func list() -> PackedStringArray:
	var dir: String = clip_dir()
	var names: PackedStringArray = []
	var da: DirAccess = DirAccess.open(dir)
	if da != null:
		names = da.get_files()
	var out: PackedStringArray = filter_clips(names, dir)
	if out.is_empty():   # an exported pack: the files load by name even where the folder does not list
		for i: int in range(1, PROBE_MAX + 1):
			var p: String = dir.path_join("load_%02d.%s" % [i, EXT])
			if FileAccess.file_exists(p):
				out.append(p)
	return out


## One of `files` by `roll` (any non-negative number), skipping `last` when there is another choice (pure).
static func pick(files: PackedStringArray, last: String, roll: int) -> String:
	if files.is_empty():
		return ""
	var pool: PackedStringArray = []
	for f: String in files:
		if f != last or files.size() == 1:
			pool.append(f)
	return pool[posmod(roll, pool.size())]


## The clip for this load ("" = none: show the plain loading screen).
static func choose(campaign_active: bool, map_id: String, is_curtain: bool) -> String:
	if not wanted(campaign_active, map_id, OS.has_feature("web"), is_curtain, disabled):
		return ""
	var p: String = pick(list(), _last, randi())
	if p != "":
		_last = p
	return p


## How long the screen stays up at least (pure).
static func min_show_s(has_clip: bool, base_s: float, clip_s: float = 0.0) -> float:
	if not has_clip:
		return base_s
	var whole: float = minf(clip_s if clip_s > 0.0 else FALLBACK_VIDEO_S, MAX_VIDEO_S)
	return maxf(maxf(base_s, MIN_VIDEO_S), whole - FADE_OUT_S)   # the fade to black ends on the clip's last frame


## May the match start now? (pure)
static func may_leave(loaded: bool, shown_s: float, has_clip: bool, base_s: float, clip_s: float = 0.0) -> bool:
	return loaded and shown_s >= min_show_s(has_clip, base_s, clip_s)


## The stream for a clip file, or null when it cannot be opened.
static func open(path: String) -> VideoStream:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != "OggS":   # not an Ogg container: the plain screen
		push_warning("LoadingClips: %s is not an Ogg Theora file, skipped" % path)
		return null
	f.close()
	# by name, not by type: a build whose engine was made without the Theora module (a trimmed web template) still
	# loads this script, and simply has no clips
	if not ClassDB.class_exists(&"VideoStreamTheora") or not ClassDB.can_instantiate(&"VideoStreamTheora"):
		return null
	var s: VideoStream = ClassDB.instantiate(&"VideoStreamTheora") as VideoStream
	if s == null:
		return null
	s.set("file", path)
	return s
