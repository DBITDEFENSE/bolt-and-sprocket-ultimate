class_name DetailRange
## T-223 (the owner: "the rendering distance is short, there's like this hexagon around the player where assets like
## grates and other stuff don't load properly"). The generators cut small geometry off at a fixed distance for speed:
## Werk Thalbach's dressing batches (40 x 40 m cells, culled whole at 58 / 90 m from the cell's centre, instanced
## details at 45 m, props at 35 m, text at 30 m) and every Kranich static batch under 60 m (the walkway grating,
## rails, fittings) at 80 m. Whole cells switching off leave a jagged ring round the player. This scales those cut-offs
## with the Level of detail setting (gfx_lod): Low keeps the authored distances, Ultra draws three times as far.
##
## Only plain cut-offs are touched (an end distance and no begin): LOD chains that swap one mesh for another (the
## C-47's impostors, the forest's mesh pines and cards) keep their pairs. Only under the generators' containers
## (CONTAINERS), so nothing a script builds at run time with its own ranges is changed. The authored distance is
## kept in meta "range_base", so changing the setting in a match re-applies from it.

const CONTAINERS: PackedStringArray = ["StaticBatches", "DressBatches", "Dressing", "Dress"]
const SCALE: Dictionary = {"low": 1.0, "medium": 1.5, "high": 2.25, "ultra": 3.0}


## The cut-off multiplier for a gfx_lod value (pure, unit-tested). Unknown -> high.
static func factor(lod: String) -> float:
	return float(SCALE.get(lod, SCALE["high"]))


## The new [end, margin] for an authored [end, margin] (pure).
static func scaled(base_end: float, base_margin: float, f: float) -> Vector2:
	return Vector2(base_end * f, base_margin * f)


## Applies `f` to every plain cut-off under the map's generator containers. Returns how many were set.
static func apply(map_root: Node, f: float) -> int:
	if map_root == null:
		return 0
	var n: int = 0
	for cname: String in CONTAINERS:
		var holder: Node = map_root.get_node_or_null(NodePath(cname))
		if holder == null:
			continue
		for c: Node in holder.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = c as GeometryInstance3D
			if gi.visibility_range_begin > 0.0:
				continue   # one end of an LOD chain
			var base: Vector2
			if gi.has_meta("range_base"):
				base = gi.get_meta("range_base")
			elif gi.visibility_range_end > 0.0:
				base = Vector2(gi.visibility_range_end, gi.visibility_range_end_margin)
				gi.set_meta("range_base", base)
			else:
				continue
			var s: Vector2 = scaled(base.x, base.y, f)
			gi.visibility_range_end = s.x
			gi.visibility_range_end_margin = s.y
			n += 1
	return n


## The current scene's map, re-applied from the setting (GLSettings.apply_visuals calls it).
static func refresh(tree: SceneTree, lod: String) -> void:
	var cs: Node = tree.current_scene if tree != null else null
	if cs is MapRoot:
		apply(cs, factor(lod))
