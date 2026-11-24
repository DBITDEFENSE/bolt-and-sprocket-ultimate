class_name RenderTune
extends RefCounted
## T-266 (the owner: "we need to optimize, we need to make this playable on macOS SteamOS. the frame rate still sucks
## at times"): the switches over the render-load passes of T-266, so a tool can run the same build, and the same
## loaded map, with and without each of them. Each pass and its counted gain: docs/perf/t266_render_2026-11.md.
##   proxies    ShadowProxies' wider merge (textured-library batches, far cut-offs, ViewCells groups, every container)
##   props      PropShadows: one shadow draw per static prop mesh instead of one per material
##   occlusion  OcclusionWalls: the batches' big faces as occluders, so rooms behind walls are not drawn (Low / Medium)
##   sun        ShadowBudget's per-setting sun (cascades, reach) and small casters (Low / Medium)
##   lights     LightRange: the lamps' draw distance (Low / Medium)
## `-- --t266-off` on the command line switches all of them off (the map as it was before), `--t266-off=props,sun`
## the named ones. Play never touches this.

const FEATURES: PackedStringArray = ["proxies", "props", "occlusion", "sun", "lights"]

static var off: PackedStringArray = _from_cmdline()
## True unless every pass is switched off (tests set it).
static var enabled: bool:
	get:
		return off.size() < FEATURES.size()
	set(v):
		off = PackedStringArray() if v else FEATURES.duplicate()


static func _from_cmdline() -> PackedStringArray:
	for a: String in OS.get_cmdline_user_args():
		if a == "--t266-off":
			return FEATURES.duplicate()
		if a.begins_with("--t266-off="):
			return a.substr(11).split(",", false)
	return PackedStringArray()


static func on(feature: String) -> bool:
	return not off.has(feature)


## Switches passes on a loaded map (tools: perf_marks --t266-ab and the capture tool measure and shoot the same map,
## loaded once, each way). `off_now`: the features to have off. Not for play: it rebuilds the shadow proxies.
static func set_off(map_root: Node, off_now: PackedStringArray) -> void:
	if map_root == null or not map_root.is_inside_tree():
		off = off_now
		return
	PropShadows.undo(map_root)
	ShadowProxies.undo_all(map_root)
	off = off_now
	ShadowProxies.build_all(map_root)
	PropShadows.build(map_root)
	OcclusionWalls.refresh(map_root)
	var vc: Node = map_root.get_node_or_null("ViewCells")
	if vc is ViewCells:
		(vc as ViewCells).apply({})   # everything shown and the moon as authored, so collect reads the base state
		(vc as ViewCells).collect()   # the proxies are its members too
	var sb: ShadowBudget = map_root.get_node_or_null("ShadowBudget") as ShadowBudget
	if sb != null:
		sb.set_level(sb.level)


static func set_enabled(map_root: Node, on_: bool) -> void:
	set_off(map_root, PackedStringArray() if on_ else FEATURES.duplicate())
