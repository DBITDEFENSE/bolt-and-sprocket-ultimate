class_name LightRange
extends RefCounted
## T-266: how far a lamp is drawn, by the Level of detail setting (gfx_lod). The maps light every room with its own
## small omni / spot lamps and none of them had a draw distance: the census found 118 to 176 lamps in the camera's
## frustum on the Inn, Kaltenbrunn and Totenhafen, most of them behind walls or down a mine 60 m away, each one more
## light the clustered renderer bins and every pixel in its reach shades. On Low and Medium a lamp now fades out over
## the last quarter of its draw distance (Light3D.distance_fade_*, its shadow with it); High and Ultra are the maps as
## authored. Lamps a character carries (torches, muzzle flashes) and lamps that already fade are left alone.
## The authored state is kept in meta "light_range_base", so changing the setting in a match re-applies from it.

## Metres from the camera at which a lamp is gone (0 = never).
const END_M: Dictionary = {"low": 36.0, "medium": 56.0, "high": 0.0, "ultra": 0.0}
const BASE: StringName = &"light_range_base"


static func end_for(lod: String) -> float:
	return float(END_M.get(lod, 0.0))


## [fade begin, fade length] for a lamp of `reach` metres under a draw distance `end_m` (pure, unit-tested): the
## lamp's own reach is added, so a pool of light is still whole when its near edge is at the distance.
static func fade_for(end_m: float, reach: float) -> Vector2:
	var far: float = end_m + maxf(0.0, reach)
	return Vector2(far * 0.75, far * 0.25)


## Applies the draw distance to every omni / spot lamp under `map_root`. Returns how many fade now.
static func apply(map_root: Node, end_m: float) -> int:
	if map_root == null or GLSettings.is_compat():   # (the Compatibility renderer has no distance fade)
		return 0
	var n: int = 0
	for c: Node in map_root.find_children("*", "Light3D", true, false):
		if consider(c as Light3D, end_m):
			n += 1
	return n


## One lamp (also for lamps that join the map later). True when it fades now.
static func consider(l: Light3D, end_m: float) -> bool:
	if l == null or l is DirectionalLight3D:
		return false
	if not l.has_meta(BASE):
		if l.distance_fade_enabled or WebProfile._on_actor(l):
			return false
		l.set_meta(BASE, true)
	if end_m <= 0.0 or not RenderTune.on("lights"):
		l.distance_fade_enabled = false
		return false
	var reach: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
	var f: Vector2 = fade_for(end_m, reach)
	l.distance_fade_enabled = true
	l.distance_fade_begin = f.x
	l.distance_fade_length = f.y
	l.distance_fade_shadow = f.x
	return true


## The current scene's map, re-applied from the setting (DetailRange.refresh calls it: the same setting).
static func refresh(tree: SceneTree, lod: String) -> void:
	var cs: Node = tree.current_scene if tree != null else null
	if cs is MapRoot:
		apply(cs, end_for(lod))
