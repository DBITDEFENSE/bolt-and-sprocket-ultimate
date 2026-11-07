extends Node
## T-180 (the owner: "textures aren't loading", "invisible walls you can't see" on Totenhafen): loads map02 with every
## runtime dresser (MapRoot: ZoneAmbience, MapAmbience, CrucibleRoom, Totenhafen), runs MapArtAudit and fails on
##  - any mesh without a material, a missing texture, a shader without code, an invisible or debug material, a
##    UV-mapped material on a surface without UVs (anywhere in the loaded map);
##  - a collider of the map's own (Geometry/) a survivor can walk up to with no art at it (rays from the navmesh);
##  - ViewCells hiding the art right in front of you (a hole you see through);
##  - a bought door leaving any collider in its opening.
## Also: the props' boxes are navmesh-only at runtime and their fitted colliders block; the cutter's two fitted
## colliders swap when it slips (MapAmbience cutter_slip). Colliders from shared gameplay scripts (perk machines,
## the Crucible) are printed but not failed here.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map02_art.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const MATERIAL_KINDS: Array = ["no_mesh", "empty_mesh", "no_material", "no_shader", "missing_texture", "invisible_material",
	"debug_material", "no_uv"]

var _map: Node3D
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m2art.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	print("[m2art] %-70s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _run() -> void:
	await _frames(30)
	RoundManager.stop()
	GameState.god_mode = true
	var geo: Node = _map.get_node_or_null("Geometry")
	_check(geo != null, "map02 has its Geometry")
	if geo == null:
		_finish()
		return
	# the boxes the fits replace are off at runtime, their fits on
	for nm: String in ["Cutter", "Brine1", "Cradle1", "Pump1", "CT_Body", "Rail_StairNW", "Rail_HatchW", "NavBlock_CrateP0", "NavBlock_Marathon"]:
		var b: CollisionObject3D = geo.get_node_or_null(nm) as CollisionObject3D
		_check(b != null and b.is_in_group(&"bake_only") and b.collision_layer == 0, "%s is navmesh-only at runtime" % nm)
	for nm2: String in ["Cutter_Fit", "Brine1_Fit", "Cradle1_Fit", "Pump1_Fit", "CT_Body_Fit", "Rail_StairNW_Fit", "Rail_HatchW_Fit"]:
		var f: CollisionObject3D = geo.get_node_or_null(nm2) as CollisionObject3D
		_check(f != null and f.collision_layer == 1 and f.get_child_count() > 0, "%s blocks (%d hulls)" % [nm2, f.get_child_count() if f != null else 0])
	var rem: CollisionObject3D = geo.get_node_or_null("Cutter_RemnantFit") as CollisionObject3D
	_check(rem != null and rem.collision_layer == 0, "the cutter's remnant collider waits for the slip")

	var audit: MapArtAudit = MapArtAudit.new(_map)
	audit.run(false)
	await _frames(3)
	audit.run_rays()
	audit.report("[m2art] AUDIT")
	var mats: int = 0
	var walls: PackedStringArray = []
	var other_walls: int = 0
	var holes: PackedStringArray = []
	for fd: Dictionary in audit.findings:
		var kind: String = str(fd["kind"])
		if MATERIAL_KINDS.has(kind):
			mats += 1
		elif kind == "invisible_wall":
			if str(fd["node"]).begins_with("Geometry/"):
				walls.append(str(fd["node"]))
			else:
				other_walls += 1
		elif kind == "viewcell_hides":
			holes.append(str(fd["node"]))
	_check(int(audit.stats.get("art_meshes", 0)) > 1000, "art scanned (%d meshes, %d triangles)" % [audit.stats.get("art_meshes", 0), audit.stats.get("art_tris", 0)])
	_check(int(audit.stats.get("viewpoints", 0)) > 800, "viewpoints on the navmesh (%d)" % audit.stats.get("viewpoints", 0))
	_check(mats == 0, "no mesh without a material or with a broken one (%d)" % mats)
	_check(walls.is_empty(), "no invisible wall of the map's own (%s)" % ", ".join(walls))
	_check(holes.is_empty(), "ViewCells hide nothing right in front of you (%s)" % ", ".join(holes))
	if other_walls > 0:
		print("[m2art] note: %d shared gameplay colliders reach past their art (perk machine / Crucible scripts)" % other_walls)

	# every bought door leaves its opening clear
	audit.findings.clear()
	audit.open_doors()
	await _frames(3)
	var n_doors: int = audit.door_check()
	audit.report("[m2art] DOOR")
	_check(n_doors >= 7 and audit.count("door_blocked") == 0, "%d doors bought, nothing left in an opening" % n_doors)

	# the cutter slips: the hull's collider goes with it, the remnant's comes on
	var amb: Node = _map.get_node_or_null("MapAmbience")
	_check(amb != null, "MapAmbience attached")
	if amb != null:
		amb.call("debug_trigger", "cutter_slip")
		await _frames(2)
		var cf: CollisionObject3D = geo.get_node_or_null("Cutter_Fit") as CollisionObject3D
		_check(cf != null and cf.collision_layer == 0 and rem != null and rem.collision_layer == 1, "the slip swaps the cutter's colliders")
	audit.cleanup()
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[m2art] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)
