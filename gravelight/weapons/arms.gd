class_name Arms
extends RefCounted
## Per-character first-person arms (UPDATE_05 section 2 "Arms", T-089): the hand, forearm and sleeve meshes
## WeaponHolder puts on its two-bone IK rig, loaded from assets/ours/arms/<character>.glb (made by
## tools_src/blender/arms/make_arms.py in exactly the frames of the procedural arms in WeaponModels, so the IK,
## the sway and the reload choreography are untouched):
##   hand(left, grip_radius, pose)  "fist" / "trigger" (right: index finger on the trigger) / "open" (left: a looser
##                                  cup for a handguard), the nearest of three grip radii (14 / 19 / 27 mm);
##   forearm()                      the cuff piece (origin = wrist, +Y up the forearm);
##   sleeve()                       a unit sleeve tube the holder stretches between wrist, elbow and shoulder.
## The character is GameState.character_of(the holder's player) (Dutch, Peg, Deacon, Wren, Bolt, Vendelin;
## docs/gravelight/CHARACTERS.md). A character without a set falls back to Dutch's; without any GLB (or with
## GLSettings "greybox_arms") the procedural WeaponModels arms are used, so nothing depends on the files.

const DIR: String = "res://assets/ours/arms/"
const FALLBACK: StringName = &"dutch"
const RADII: Dictionary = {"s": 0.014, "m": 0.019, "l": 0.027}

static var _scenes: Dictionary = {}     # character -> Node3D (the instantiated GLB, kept as a mesh library)
static var _missing: Dictionary = {}    # character -> true when the GLB is absent


## The arms set a player uses: their survivor's, or Dutch's when that survivor has no set yet.
static func character_for(player: Player) -> StringName:
	var ch: StringName = GameState.character_of(player.player_id) if player != null else GameState.character_id
	if ch == &"" or not available(ch):
		return FALLBACK if available(FALLBACK) else &""
	return ch


## True when a GLB for this character is in the project (and imported).
static func available(ch: StringName) -> bool:
	if bool(GLSettings.values.get("greybox_arms", false)):
		return false
	if _missing.has(ch):
		return false
	if _scenes.has(ch):
		return true
	var path: String = DIR + String(ch) + ".glb"
	if not ResourceLoader.exists(path):
		if not MapPacks.pending():   # T-139: in the browser the arms arrive with a game pack; don't remember a miss before
			_missing[ch] = true
		return false
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		_missing[ch] = true
		return false
	_scenes[ch] = ps.instantiate()
	return true


static func _mesh(ch: StringName, node_name: String) -> Mesh:
	if not available(ch):
		return null
	var n: MeshInstance3D = (_scenes[ch] as Node).find_child(node_name, true, false) as MeshInstance3D
	return n.mesh if n != null else null


static func _radius_key(r: float) -> String:
	var best: String = "m"
	var best_d: float = INF
	for k: String in RADII.keys():
		var d: float = absf(float(RADII[k]) - r)
		if d < best_d:
			best_d = d
			best = k
	return best


## A hand mesh in the fist frame (origin = centre of the gripped part, grip axis +Y, palm +X for the right hand).
## null when the character has no set (the holder then uses WeaponModels.hand_mesh).
static func hand(ch: StringName, left: bool, grip_radius: float, pose: String = "fist") -> Mesh:
	var p: String = pose
	if left and p == "trigger":
		p = "fist"
	if not left and p == "open":
		p = "fist"
	return _mesh(ch, "Hand%s_%s_%s" % ["L" if left else "R", p, _radius_key(grip_radius)])


## The forearm cuff piece (origin = wrist, +Y up the forearm), or null.
static func forearm(ch: StringName) -> Mesh:
	return _mesh(ch, "Forearm")


## The unit sleeve tube (height 1 along Y, centred), or null.
static func sleeve(ch: StringName) -> Mesh:
	return _mesh(ch, "Sleeve")


## The wrist point of a hand in its frame: the same as the procedural hand's, so the IK chain is unchanged.
static func hand_wrist(left: bool, grip_radius: float) -> Vector3:
	return WeaponModels.hand_wrist(left, grip_radius)


## Drops the cached sets (tests, regenerated GLBs).
static func reset() -> void:
	for n: Node in _scenes.values():
		n.free()
	_scenes.clear()
	_missing.clear()
