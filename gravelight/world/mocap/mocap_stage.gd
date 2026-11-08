class_name MocapStage
extends RefCounted
## T-210: the cinema player's mocap hook (one call at the end of CinemaDirector._begin_shot). For the shot that just
## began it finds the scene (the definition's `mocap_scene`, else the CinemaReel cut or the ExfilCutscene playing it),
## the shot key (the shot's `mocap`, else "shot_%02d" by its place in the timeline), and every actor on screen:
##   - the cast's stand-ins (RemoteBody): roles [character, "slot<i>", "any"];
##   - a reel stage's people (CinemaPerson): roles [person or id, "seat<i>" for the C-47 passengers, "any" for the squad].
## An actor with a clip (MocapLibrary.clip) gets a MocapModifier on its PersonRig skeleton; one already playing the
## same scene and shot key keeps playing (a two-shot of the same moment); one with no clip loses its modifier, so its
## stand-in animation is back. No library for the scene (no captures yet) = nothing happens at all.

const SQUAD: Array[String] = ["dutch", "peg", "deacon", "wren", "jakub"]


static func on_shot(d: Object, s: CinemaShot) -> void:
	if not MocapLibrary.enabled or d == null or s == null:
		return
	var scene: String = scene_id(d)
	if MocapLibrary.library(scene) == null:
		return
	var key: String = shot_key(d, s)
	var face: Variant = null
	var sq: Variant = s.raw.get("squad", {})
	if sq is Dictionary and (sq as Dictionary).has("face"):
		face = CinemaShot.v3((sq as Dictionary)["face"])
	var blend: float = s.blend if s.cut == "blend" else 0.0
	var only: Array = s.raw.get("mocap_only", []) if s.raw.get("mocap_only", []) is Array else []
	for e: Array in actors(d):
		var body: Node3D = e[0]
		var rig: PersonRig = e[1]
		if rig == null or rig.skeleton == null:
			continue
		var roles: Array = e[2]
		if not only.is_empty() and not only.has(str(roles[0])):   # (the key: only whoever turned it, and Jakub)
			roles = []
		play_on(rig.skeleton, scene, key, roles, d, s.t, blend, body, face)


## Puts the clip for `roles` on `sk` (or takes the old one off). Returns the modifier playing, or null.
static func play_on(sk: Skeleton3D, scene: String, key: String, roles: Array, d: Object, t0: float, blend: float = 0.0,
		body: Node3D = null, face: Variant = null) -> MocapModifier:
	var full: String = scene + ":" + key
	var old: MocapModifier = sk.get_node_or_null("Mocap") as MocapModifier
	if old != null and old.key == full and not roles.is_empty():
		return old
	var a: Animation = MocapLibrary.clip(scene, key, roles)
	if old != null:
		sk.remove_child(old)
		old.queue_free()
	if a == null:
		return null
	var m: MocapModifier = MocapModifier.attach(sk, a, full, d, t0, blend)
	if face is Vector3 and body != null and body.is_inside_tree():
		var to: Vector3 = (face as Vector3) - body.global_position
		if Vector2(to.x, to.z).length() > 0.05:
			m.face(atan2(-to.x, -to.z))
	if body is RemoteBody:   # the gun rides the puppet's hands, not the rig's: it would float, so it waits off screen
		var g: Node3D = body.get("_gun") as Node3D
		if g != null and g.visible:
			g.visible = false
			m.hidden.append(g)
	return m


## The cutscene id for the mocap folders.
static func scene_id(d: Object) -> String:
	var def: Dictionary = d.get("def") as Dictionary if d.get("def") is Dictionary else {}
	var v: String = str(def.get("mocap_scene", ""))
	if v != "":
		return v
	var n: Node = (d as Node).get_parent() if d is Node else null
	for _i: int in 3:
		if n == null:
			break
		if n is CinemaReel:
			var r: CinemaReel = n as CinemaReel
			return r.ids[r.index] if r.index >= 0 and r.index < r.ids.size() else ""
		if n is ExfilCutscene:
			return (n as ExfilCutscene).cutscene_id
		n = n.get_parent()
	return ""


## The shot's key: its own `mocap` name (the script-driven endings), else shot_NN by its place in the timeline.
static func shot_key(d: Object, s: CinemaShot) -> String:
	var k: String = str(s.raw.get("mocap", ""))
	if k != "":
		return k
	var shots: Array = d.get("shots") if d.get("shots") is Array else []
	var i: int = shots.find(s)
	return "shot_%02d" % (i + 1) if i >= 0 else ""


## [body, PersonRig, roles] for everyone a shot can see.
static func actors(d: Object) -> Array:
	var out: Array = []
	var cast: CinemaCast = d.get("cast") as CinemaCast
	if cast != null and is_instance_valid(cast):
		for i: int in cast.actors.size():
			var a: RemoteBody = cast.actors[i]
			if is_instance_valid(a):
				out.append([a, a.get("person") as PersonRig, [String(a.character), "slot%d" % (i + 1), "any"]])
	var stage: Node = d.get("map") as Node
	if stage is CinemaSet:
		for n: Node in stage.find_children("*", "CinemaPerson", true, false):
			var p: CinemaPerson = n as CinemaPerson
			out.append([p, p.person, roles_of(p)])
	return out


static func roles_of(p: CinemaPerson) -> Array:
	var who: String = str(p.look_row.get("person", ""))
	if who == "":
		who = p.patron_id
	var roles: Array = [who]
	if p.patron_id.begins_with("passenger_"):
		roles.append("seat%d" % (int(p.patron_id.trim_prefix("passenger_")) + 1))
	if SQUAD.has(who):
		roles.append("any")
	return roles
