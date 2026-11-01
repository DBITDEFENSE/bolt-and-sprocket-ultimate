class_name SoldierBody
extends RemoteBody
## T-142: a relief-squad soldier seen in the world: RemoteBody's procedural puppet (walk / run, the gun in both hands
## aimed with the pitch, reload, downed, the revive kneel, muzzle flash, tracer and gunfire) drawing a dressed body
## instead of a named person (SoldierKits: an existing zombie kit's clothes on the living human base, the faction
## palette, the faction headgear and armband on the rig's bones). No nameplate, no bot hooks, no perk or buy actions.

var look: Dictionary = {}


func setup_soldier(lk: Dictionary, sid: int, weapon: StringName) -> void:
	look = lk
	character = &"soldier"
	pid = sid
	_rng.seed = int(lk.get("seed", 0)) + sid
	var build: String = str(lk.get("build", "medium"))
	_build = {"width": 1.08 if build == "heavy" else (0.92 if build == "thin" else 1.0), "stance": 0.11, "gun_drop": 0.02,
		"lean": 0.03, "fidget": ""}
	var pal: Dictionary = lk.get("palette", {})
	var cloth: Color = (pal.get("cloth", Color(0.3, 0.3, 0.25)) as Color).linear_to_srgb()
	var cloth2: Color = (pal.get("cloth2", cloth) as Color).linear_to_srgb()
	var head: Color = lk.get("headgear_color", Color(0, 0, 0, 0))
	if head.a <= 0.0:
		head = cloth2
	else:
		head = head.linear_to_srgb()
	var skin: Color = (lk.get("tone", Color(0.62, 0.5, 0.44)) as Color).linear_to_srgb()
	_mats = {
		"jacket": _mat(cloth), "trousers": _mat(cloth2), "head": _mat(head), "skin": _mat(skin),
		"accent": _mat(cloth2), "boot": _mat(Color(0.12, 0.09, 0.07)), "strap": _mat(Color(0.3, 0.26, 0.17)),
		"glove": _mat(Color(0.22, 0.17, 0.12)), "metal": _mat(Color(0.32, 0.33, 0.34), 0.45, 0.7),
		"canvas": _mat(Color(0.38, 0.35, 0.24)), "white": _mat(Color(0.93, 0.92, 0.88)), "glass": _mat(Color(0.25, 0.15, 0.08), 0.3),
		"paper": _mat(Color(0.85, 0.8, 0.66)), "wood": _mat(Color(0.48, 0.34, 0.2)), "scarf": _mat(Color(0.42, 0.16, 0.14)),
		"grease": _mat(Color(0.12, 0.11, 0.1)), "net": _mat(Color(0.2, 0.22, 0.14)),
		"stubble": _mat(Color(0.3, 0.27, 0.25)), "shirt": _mat(Color(0.42, 0.37, 0.3)), "bandage": _mat(Color(0.86, 0.83, 0.76)),
	}
	var hg: String = str(lk.get("headgear", ""))
	_build_body("helmet" if hg == "helmet" else ("beret" if hg == "beret" else ("cap" if hg != "" else "knit")))
	_build_person()
	if _tag != null:
		_tag.visible = false
	set_weapon(weapon)


func _make_person_rig() -> PersonRig:
	var m: ArrayMesh = SoldierKits.body_mesh(look, true)
	if m == null:
		return null
	var p: PersonRig = PersonRig.new()
	if not p.setup_mesh(m, float(look.get("height", 1.0)), "squad_" + str(look.get("kit", ""))):
		p.free()
		return null
	SoldierKits.add_gear(look, func(bone: String) -> Node3D: return p.attachment(bone))
	return p


func _ai() -> bool:
	return true   # calm comes from the soldier (no co-op revive hints, no nameplate)
