class_name LipSync
extends RefCounted
## UPDATE 12 section 4 (T-210): mouth cues for the voice lines. tools/mocap.sh lipsync runs Rhubarb Lip Sync (MIT,
## the release binary fetched into the git-ignored tools/dl_rhubarb/) over each line's ElevenLabs take and writes
## data/gravelight/vo/lipsync/<LINE_ID>.json: {"id", "duration", "source", "cues": [[start s, shape], ...]} with
## Rhubarb's shapes A-H and X (when Rhubarb could not run, "source" says "amplitude" and the cues come from the take's
## loudness: X / B / C / D only). FaceDriver reads them on GLBus.vo_line_started: a line with cues moves the mouth on
## them, a line without keeps the old syllable flap. Shapes become two numbers the faces can show:
##   jaw   the people.json `jaw_open` blend shape, or the Jaw bone on a head with no blend shapes (LipSyncBones);
##   wide  added to `smile` at half weight (the mouth corners out for EE / S / T / F), on the bone fallback a small
##         lift of the head (the "brow" beat on open vowels).
## Pure apart from the file cache.

const DIR: String = "res://data/gravelight/vo/lipsync/"
## Rhubarb's mouth shapes as (jaw, wide). A: M B P closed; B: most consonants, teeth together; C: EH / AE open;
## D: AA wide open; E: AO / ER rounded; F: UW / OW / W puckered; G: F / V teeth on the lip; H: L; X: rest.
const SHAPES: Dictionary = {
	"A": Vector2(0.0, 0.0), "B": Vector2(0.14, 0.32), "C": Vector2(0.4, 0.2), "D": Vector2(0.75, 0.1),
	"E": Vector2(0.34, 0.0), "F": Vector2(0.12, 0.0), "G": Vector2(0.09, 0.18), "H": Vector2(0.3, 0.1), "X": Vector2(0.0, 0.0),
}
## How long a shape takes to turn into the next (coarticulation): the mouth is already moving at a cue's start.
const XFADE: float = 0.06

static var _cache: Dictionary = {}
## Off: every line uses the old syllable flap (a test or a tool can turn the cues off).
static var enabled: bool = true


static func path_of(line_id: String) -> String:
	return DIR + line_id + ".json"


## A line's cues [[t, shape], ...] (the last entry is [duration, "X"]), or [] when none were made.
static func cues(line_id: String) -> Array:
	if not enabled or line_id == "":
		return []
	if _cache.has(line_id):
		return _cache[line_id]
	var out: Array = []
	var p: String = path_of(line_id)
	if FileAccess.file_exists(p):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if j is Dictionary:
			for c: Variant in (j as Dictionary).get("cues", []):
				if c is Array and (c as Array).size() >= 2:
					out.append([float(c[0]), str(c[1])])
			if not out.is_empty():
				out.append([float((j as Dictionary).get("duration", float(out[-1][0]))), "X"])
	_cache[line_id] = out
	return out


static func clear_cache() -> void:
	_cache.clear()


## When the cues end (the line's duration), 0 with none.
static func length_of(c: Array) -> float:
	return float(c[-1][0]) if not c.is_empty() else 0.0


## The shape playing at `t` (binary search over the cue starts).
static func shape_at(c: Array, t: float) -> String:
	if c.is_empty() or t < float(c[0][0]) or t >= length_of(c):
		return "X"
	var lo: int = 0
	var hi: int = c.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if float(c[mid][0]) <= t:
			lo = mid
		else:
			hi = mid - 1
	return str(c[lo][1])


## The mouth at `t` as (jaw, wide): the cue's shape, eased in from the one before over XFADE.
static func mouth_at(c: Array, t: float) -> Vector2:
	if c.is_empty() or t >= length_of(c) or t < 0.0:
		return Vector2.ZERO
	var lo: int = 0
	var hi: int = c.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if float(c[mid][0]) <= t:
			lo = mid
		else:
			hi = mid - 1
	var cur: Vector2 = SHAPES.get(str(c[lo][1]), Vector2.ZERO)
	var since: float = t - float(c[lo][0])
	if lo == 0 or since >= XFADE:
		return cur
	var prev: Vector2 = SHAPES.get(str(c[lo - 1][1]), Vector2.ZERO)
	return prev.lerp(cur, smoothstep(0.0, 1.0, since / XFADE))
