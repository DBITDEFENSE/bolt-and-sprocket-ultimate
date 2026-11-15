class_name SoldierKits
extends RefCounted
## T-142 (UPDATE 09 section 4): the relief squads' looks (data/gravelight/squads.json "kits"). No new Blender work: a
## soldier is a human_base body in an existing zombie kit's clothes (ZombieBody.build_dressed: soldier, villager or
## sailor) recoloured by the faction's palette, with a headgear piece from ZombieBody.gear_mesh in the faction colour
## and an optional plain armband (the Home Army's white and red; the MPs' black brassard, no lettering). No insignia.
## A look is rolled from (kit, seed) so the host and co-op clients build the same body; the tag "sq:<kit>:<seed>:<m|u>"
## travels with a risen soldier's spawn (the zombie's "person" meta, NetMatch._send_spawn) so its puppet is dressed
## the same and a soldier of an unmarked faction rises without a Marke (CANON 2.2).

const TAG_PREFIX: String = "sq:"


static func table() -> Dictionary:
	return GLData.table("squads")


static func kit(kit_id: String) -> Dictionary:
	return (table().get("kits", {}) as Dictionary).get(kit_id, {})


static func _srgb(a: Variant, fallback: Color) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2])).srgb_to_linear()
	return fallback


static func _pick_weighted(weights: Dictionary, r: float) -> String:
	var total: float = 0.0
	for k: Variant in weights.keys():
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0:
		return ""
	var x: float = r * total
	for k2: Variant in weights.keys():
		x -= maxf(0.0, float(weights[k2]))
		if x <= 0.0:
			return str(k2)
	return str(weights.keys().back())


## The look of one soldier (pure over the kit row): {kit, base, build, female, height, tone, palette, headgear,
## headgear_color, armband, seed}. Colours are linear (the kit shader's space).
static func roll_look(kit_id: String, seed_v: int, k: Dictionary = {}) -> Dictionary:
	if k.is_empty():
		k = kit(kit_id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [kit_id, seed_v])
	var base: String = _pick_weighted(k.get("bases", {"soldier": 1.0}), rng.randf())
	if base == "":
		base = "soldier"
	var builds: Array = k.get("builds", ["medium"])
	var build: String = str(builds[rng.randi() % builds.size()]) if not builds.is_empty() else "medium"
	var female: bool = rng.randf() < float(k.get("female", 0.0))
	var hs: Array = k.get("heights", [0.97, 1.03])
	var height: float = rng.randf_range(float(hs[0]), float(hs[1]))
	var tones: Array = k.get("tones", [[0.62, 0.5, 0.44]])
	var tone: Color = _srgb(tones[rng.randi() % tones.size()], Color(0.62, 0.5, 0.44)) if not tones.is_empty() else Color(0.62, 0.5, 0.44)
	var pals: Array = k.get("palettes", [])
	var palette: Dictionary = {}
	if not pals.is_empty():
		var p: Dictionary = pals[rng.randi() % pals.size()]
		for key: Variant in p.keys():
			palette[str(key)] = _srgb(p[key], Color.GRAY)
	var hair: Array = k.get("hair", [])
	if not hair.is_empty():
		palette["hair"] = _srgb(hair[rng.randi() % hair.size()], Color(0.1, 0.08, 0.07))
	var hg: Dictionary = k.get("headgear", {})
	var none_w: float = maxf(0.0, 1.0 - _sum(hg))
	var hw: Dictionary = hg.duplicate()
	hw[""] = none_w
	var headgear: String = _pick_weighted(hw, rng.randf())
	var hcol: Color = _srgb((k.get("headgear_color", {}) as Dictionary).get(headgear), Color(0, 0, 0, 0))
	if (k.get("headgear_color", {}) as Dictionary).get(headgear) == null:
		hcol = Color(0, 0, 0, 0)   # the gear's own look (a sailor's cap)
	return {"kit": kit_id, "base": base, "build": build, "female": female, "height": height, "tone": tone,
		"palette": palette, "headgear": headgear, "headgear_color": hcol, "armband": k.get("armband", {}), "seed": seed_v}


static func _sum(d: Dictionary) -> float:
	var s: float = 0.0
	for k: Variant in d.keys():
		s += maxf(0.0, float(d[k]))
	return s


static func tag_of(kit_id: String, seed_v: int, marked: bool) -> String:
	return "%s%s:%d:%s" % [TAG_PREFIX, kit_id, seed_v, "m" if marked else "u"]


static func is_tag(s: String) -> bool:
	return s.begins_with(TAG_PREFIX)


## {kit, seed, marked} from a tag; {} when it is not one.
static func parse_tag(tag: String) -> Dictionary:
	if not is_tag(tag):
		return {}
	var parts: PackedStringArray = tag.trim_prefix(TAG_PREFIX).split(":")
	if parts.size() < 3 or not parts[1].is_valid_int():
		return {}
	return {"kit": parts[0], "seed": int(parts[1]), "marked": parts[2] == "m"}


## The zombie kit a risen soldier is activated with (its body is replaced right after; this picks the rig's clips).
static func zombie_variant(tag: String) -> String:
	var t: Dictionary = parse_tag(tag)
	if t.is_empty():
		return tag if (GLData.table("anim")["kits"] as Dictionary).has(tag) else "soldier"
	return str(roll_look(str(t["kit"]), int(t["seed"])).get("base", "soldier"))


## Has worker threads merge this look's two bodies (living, and risen for when it dies) and warms the zombie body
## its rise is activated on and its severed pieces are cut from; bodies_ready says when the living one is in.
static func request_bodies(look: Dictionary) -> void:
	var base: String = str(look.get("base", "soldier"))
	var build: String = str(look.get("build", "medium"))
	var female: bool = bool(look.get("female", false))
	for living: bool in [true, false]:
		ZombieBody.request_dressed(base, build, female, look.get("tone", Color(0.62, 0.5, 0.44)), look.get("palette", {}), living)


static func bodies_ready(looks: Array) -> bool:
	for l: Variant in looks:
		var look: Dictionary = l
		if not ZombieBody.dressed_ready(str(look.get("base", "soldier")), str(look.get("build", "medium")), bool(look.get("female", false)),
				look.get("tone", Color(0.62, 0.5, 0.44)), look.get("palette", {}), true):
			return false
	return true


static func body_mesh(look: Dictionary, living: bool) -> ArrayMesh:
	return ZombieBody.build_dressed(str(look.get("base", "soldier")), str(look.get("build", "medium")), bool(look.get("female", false)),
		look.get("tone", Color(0.62, 0.5, 0.44)), look.get("palette", {}), living)


static func _flat_mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## The look's headgear and armband as MeshInstance3Ds, each parented to the node `attach_at.call(bone)` returns.
## Living soldiers get the two-tone armband; `risen` hangs the plain pieces only (they are pooled zombie gear).
static func add_gear(look: Dictionary, attach_at: Callable, risen: bool = false) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var female: bool = bool(look.get("female", false))
	var hg: String = str(look.get("headgear", ""))
	if hg != "":
		var spec: Array = ZombieBody.gear_mesh(hg, female)
		var at: Node3D = attach_at.call(str(spec[0])) as Node3D
		if at != null:
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "SquadHeadgear"
			mi.mesh = spec[1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var c: Color = look.get("headgear_color", Color(0, 0, 0, 0))
			if c.a > 0.0:
				mi.material_override = _flat_mat(c, 0.6 if hg == "helmet" else 0.9)
			at.add_child(mi)
			out.append(mi)
	var ab: Dictionary = look.get("armband", {})
	if not ab.is_empty() and not risen:
		var spec2: Array = ZombieBody.gear_mesh("armband", female)
		var at2: Node3D = attach_at.call(str(spec2[0])) as Node3D
		if at2 != null:
			var band: MeshInstance3D = MeshInstance3D.new()
			band.name = "SquadArmband"
			band.mesh = spec2[1]
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var m: ArrayMesh = spec2[1]
			for si: int in m.get_surface_count():
				# the band, and its patch where the Wiederkehr mark would sit (never that mark here)
				var key: String = "patch" if m.surface_get_name(si) == "emblem" else "band"
				band.set_surface_override_material(si, _flat_mat(_srgb(ab.get(key, ab.get("band")), Color.WHITE)))
			at2.add_child(band)
			out.append(band)
	return out


## A pooled zombie getting up as this soldier: the risen body (the zombie base, dead skin, violet eyes) in the same
## clothes and colours, the rolled gear hidden, the soldier's headgear on its head, no Marke for an unmarked faction.
## Kept as the zombie's "person" meta so the co-op spawn event dresses the puppet the same (NetMatch._send_spawn).
static func dress_risen(z: Zombie, tag: String) -> void:
	var t: Dictionary = parse_tag(tag)
	if z == null or t.is_empty():
		return
	var look: Dictionary = roll_look(str(t["kit"]), int(t["seed"]))
	var mi: MeshInstance3D = z.get("_body") as MeshInstance3D
	if mi != null:
		var m: ArrayMesh = body_mesh(look, false)
		if m != null:
			mi.mesh = m
			mi.set_surface_override_material(0, null)
	for g: Variant in (z.get("_gear") as Array):
		(g as Node3D).hide()
	z.set("_build", str(look.get("build", "medium")))
	z.set("_female", bool(look.get("female", false)))
	z.set_meta("person", tag)
	z.dress_squad_gear(look)
	if not bool(t["marked"]):
		z.clear_marke()
