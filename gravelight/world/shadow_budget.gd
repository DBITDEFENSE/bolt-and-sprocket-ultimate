class_name ShadowBudget
extends Node
## T-258 (the owner, 2026-11-15: "really bad fps ... CPU load is high, GPU load is nothing" on an RTX 5090). Map 0
## has 19 shadowed lamps, 12 of them omni lights with cube shadows: 6 shadow views each, every frame, prepared on the
## CPU in the same thread as the game. Measured on the owner's PC (perf_marks, round 15, 24 zombies, the squad):
## 33 FPS as built, 57 FPS with the omni lamps' shadows off, 60 with every shadow off; hiding the zombies and players
## or stopping animation did not help. The Shadows setting only changed the atlas size (GPU), never the views (CPU).
##
## This keeps shadows on the lamps that matter to the camera and lights the rest without one. Every RERANK_S seconds
## the map's shadowed omni / spot lamps are ranked by how far the camera stands outside each one's reach; the nearest
## keep their shadow while their shadow views fit the setting's budget (a cube omni costs 6 views, a dual-paraboloid
## omni 2, a spot 1) and they are within its distance. Below Ultra the omni lamps use dual-paraboloid shadows.
## Only lamps the map built with a shadow are touched (remembered in meta WANT); a lamp whose own script turns its
## shadow off is let go. Lights carried by a character (torches, muzzle flashes) are never touched. The browser
## profile (WebProfile) keeps its own static cap. Presentation only: no gameplay, timing or collision changes.

## [shadow views a frame, the farthest a lamp keeps its shadow (m outside its reach), cube omni shadows]
const LEVELS: Dictionary = {
	"low": [4, 20.0, false],
	"medium": [8, 30.0, false],
	"high": [14, 40.0, false],
	"ultra": [24, 60.0, true],
}
## T-266: what else the Shadows setting takes off the shadow passes below High. The census (round 15, the heaviest
## views): the sun's four cascades over 70 m redraw every caster near the camera every frame, and a fifth of a map's
## loose casters are small things (bottles, plates, handles, nails) whose shadow is a few pixels.
## [the sun's most cascades, its farthest shadow in metres (0 = as authored), the longest side in metres under which
## a thing casts no shadow (0 = everything casts)]. High and Ultra are the map as authored.
const SUN: Dictionary = {
	"low": [2, 40.0, 0.5],
	"medium": [2, 55.0, 0.25],
	"high": [4, 0.0, 0.0],
	"ultra": [4, 0.0, 0.0],
}
## The largest "small caster" any setting drops (what _scan remembers).
const SMALL_MAX_M: float = 0.5
const RERANK_S: float = 0.2
## A lamp that has its shadow keeps it until another is this much nearer (no flicker on a boundary).
const HYSTERESIS_M: float = 2.0
const WANT: StringName = &"shadow_budget_want"
const OFF: StringName = &"shadow_budget_off"
const MODE: StringName = &"shadow_budget_mode"
const SUN_BASE: StringName = &"shadow_budget_sun"
const CAST_BASE: StringName = &"shadow_budget_cast"

var map_root: Node
var level: String = "high"
var stats: Dictionary = {"lamps": 0, "on": 0, "views": 0}
var _lamps: Array[Light3D] = []
var _suns: Array[DirectionalLight3D] = []
var _small: Array = []   # [GeometryInstance3D, longest side (m)]: the casters small enough for a setting to drop
var _t: float = 0.0


static func attach(map: Node) -> ShadowBudget:
	if GLSettings.is_compat():
		return null
	var sb: ShadowBudget = ShadowBudget.new()
	sb.name = "ShadowBudget"
	sb.map_root = map
	sb.level = str(GLSettings.gfx("gfx_shadows"))
	map.add_child(sb)
	return sb


## The current map's budget, re-read from the setting (GLSettings.apply_visuals calls it).
static func refresh(tree: SceneTree, level_: String) -> void:
	var cs: Node = tree.current_scene if tree != null else null
	if cs == null:
		return
	var sb: ShadowBudget = cs.get_node_or_null("ShadowBudget") as ShadowBudget
	if sb != null:
		sb.set_level(level_)


static func row(level_: String) -> Array:
	return LEVELS.get(level_, LEVELS["high"]) as Array


static func sun_row(level_: String) -> Array:
	return SUN.get(level_, SUN["high"]) as Array


## The sun's [shadow mode, farthest shadow] for an authored pair under a setting's row (pure, unit-tested): never
## more cascades or a longer reach than the map was built with.
static func sun_for(base_mode: int, base_dist: float, r: Array) -> Array:
	var mode: int = base_mode
	if int(r[0]) < 4 and base_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
		mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var dist: float = base_dist
	if float(r[1]) > 0.0:
		dist = minf(base_dist, float(r[1]))
	return [mode, dist]


## Shadow views one lamp costs a frame.
static func cost(l: Light3D, cube: bool) -> int:
	if l is OmniLight3D:
		return 6 if cube else 2
	return 1


## Which lamps keep their shadow. `entries`: [{"d": metres outside its reach, "cost": views, "on": has it now}],
## any order. Nearest first while the views fit `budget` and d <= max_d; a lamp that has it now counts HYSTERESIS_M
## nearer. Returns one bool per entry, in the entries' order. Pure (unit-tested).
static func pick(entries: Array, budget: int, max_d: float) -> Array[bool]:
	var order: Array = range(entries.size())
	var eff: PackedFloat32Array = PackedFloat32Array()
	for e: Dictionary in entries:
		eff.append(float(e["d"]) - (HYSTERESIS_M if bool(e.get("on", false)) else 0.0))
	order.sort_custom(func(a: int, b: int) -> bool: return eff[a] < eff[b])
	var out: Array[bool] = []
	out.resize(entries.size())
	out.fill(false)
	var used: int = 0
	for i: int in order:
		if eff[i] > max_d:
			break
		var c: int = int(entries[i]["cost"])
		if used + c <= budget:
			out[i] = true
			used += c
	return out


func _ready() -> void:
	_scan.call_deferred()
	get_tree().node_added.connect(_on_node_added)


func set_level(level_: String) -> void:
	level = level_
	_apply_mode()
	_apply_sun()
	_apply_small()
	_rerank()


func _scan() -> void:
	if map_root == null or not is_instance_valid(map_root):
		return
	for n: Node in map_root.find_children("*", "Light3D", true, false):
		_consider(n)
		if n is DirectionalLight3D:
			n.set_meta(SUN_BASE, [(n as DirectionalLight3D).directional_shadow_mode, (n as DirectionalLight3D).directional_shadow_max_distance])
			_suns.append(n as DirectionalLight3D)
	for n: Node in map_root.find_children("*", "GeometryInstance3D", true, false):
		_consider_small(n)
	_apply_mode()
	_apply_sun()
	_apply_small()
	_rerank()


func _on_node_added(n: Node) -> void:
	if (n is OmniLight3D or n is SpotLight3D) and map_root != null and map_root.is_ancestor_of(n):
		_consider.call_deferred(n)   # after its own _ready has set its shadow
	elif n is GeometryInstance3D and float(_tune_row()[2]) > 0.0 and map_root != null and map_root.is_ancestor_of(n):
		_late_small.call_deferred(n)   # (only on the settings that drop small casters: High and Ultra pay nothing here)


func _late_small(n: Variant) -> void:   # (untyped: the node may have been freed again before this deferred call)
	if is_instance_valid(n) and (n as Node).is_inside_tree() and _consider_small(n as Node):
		_set_small(_small[_small.size() - 1], float(_tune_row()[2]))


## Remembers a caster small enough for a setting to drop. True when it was added.
func _consider_small(n: Node) -> bool:
	var gi: GeometryInstance3D = n as GeometryInstance3D
	if gi == null or gi.has_meta(CAST_BASE) or gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		return false
	if gi is GPUParticles3D or gi is CPUParticles3D or gi is MultiMeshInstance3D or not gi.is_inside_tree():
		return false
	var side: float = (gi.global_transform * gi.get_aabb()).get_longest_axis_size()
	if side <= 0.0 or side >= SMALL_MAX_M:
		return false
	gi.set_meta(CAST_BASE, true)
	_small.append([gi, side])
	return true


func _set_small(e: Array, under: float) -> void:
	var gi: GeometryInstance3D = e[0] as GeometryInstance3D
	var want: int = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if float(e[1]) < under else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if gi.cast_shadow != want:
		gi.cast_shadow = want as GeometryInstance3D.ShadowCastingSetting


## The SUN row in force: the setting's, or High's (the map as authored) when T-266's passes are switched off.
func _tune_row() -> Array:
	return sun_row(level if RenderTune.on("sun") else "high")


func _apply_small() -> void:
	var under: float = float(_tune_row()[2])
	var live: Array = []
	var off: int = 0
	for e: Array in _small:
		if not is_instance_valid(e[0]):
			continue
		live.append(e)
		_set_small(e, under)
		if float(e[1]) < under:
			off += 1
	_small = live
	stats["small_off"] = off


func _apply_sun() -> void:
	var r: Array = _tune_row()
	for sun: DirectionalLight3D in _suns:
		if not is_instance_valid(sun):
			continue
		var base: Array = sun.get_meta(SUN_BASE)
		var want: Array = sun_for(int(base[0]), float(base[1]), r)
		sun.directional_shadow_mode = int(want[0]) as DirectionalLight3D.ShadowMode
		sun.directional_shadow_max_distance = float(want[1])


func _consider(n: Variant) -> void:   # (untyped: a deferred call may arrive after the node was freed)
	if not is_instance_valid(n) or not (n is OmniLight3D or n is SpotLight3D) or n.has_meta(WANT):
		return
	var l: Light3D = n as Light3D
	if not l.shadow_enabled or WebProfile._on_actor(l):
		return
	l.set_meta(WANT, true)
	if l is OmniLight3D:
		l.set_meta(MODE, (l as OmniLight3D).omni_shadow_mode)
		(l as OmniLight3D).omni_shadow_mode = _omni_mode(l)
	_lamps.append(l)


func _omni_mode(l: Light3D) -> int:
	if bool(row(level)[2]):
		return int(l.get_meta(MODE, OmniLight3D.SHADOW_CUBE))
	return OmniLight3D.SHADOW_DUAL_PARABOLOID


func _apply_mode() -> void:
	for l: Light3D in _lamps:
		if is_instance_valid(l) and l is OmniLight3D:
			(l as OmniLight3D).omni_shadow_mode = _omni_mode(l)


func _process(delta: float) -> void:
	_t += delta
	if _t >= RERANK_S:
		_t = 0.0
		_rerank()


func _rerank() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var eye: Vector3 = cam.global_position
	var cube: bool = bool(row(level)[2])
	var live: Array[Light3D] = []
	var entries: Array = []
	for l: Light3D in _lamps:
		if not is_instance_valid(l) or not l.is_inside_tree():
			continue
		if not l.shadow_enabled and not l.has_meta(OFF):
			continue   # its own script turned the shadow off: let it go
		live.append(l)
		if not l.is_visible_in_tree():
			entries.append({"d": INF, "cost": cost(l, cube), "on": false})
			continue
		var reach: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
		entries.append({"d": maxf(0.0, eye.distance_to(l.global_position) - reach), "cost": cost(l, cube), "on": l.shadow_enabled})
	_lamps = live
	var r: Array = row(level)
	var keep: Array[bool] = pick(entries, int(r[0]), float(r[1]))
	var on: int = 0
	var views: int = 0
	for i: int in live.size():
		var l: Light3D = live[i]
		if keep[i]:
			if not l.shadow_enabled:
				l.shadow_enabled = true
			if l.has_meta(OFF):
				l.remove_meta(OFF)
			on += 1
			views += int(entries[i]["cost"])
		elif l.shadow_enabled:
			l.shadow_enabled = false
			l.set_meta(OFF, true)
	stats["lamps"] = live.size()
	stats["on"] = on
	stats["views"] = views
