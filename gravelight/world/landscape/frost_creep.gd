class_name FrostCreep
extends Node3D
## Frost creeping over the inn's windows as the night goes on (Update 02 section 7, T-052): a crust of frost on the
## inside of every walled window's opening (the yard's fence gaps have no glass to frost), thickest round the frame
## and clear in the middle so the view out stays open, its opacity rising with the round and jumping when the hearth
## dies. One shared material; the texture is drawn once in code.

var cfg: Dictionary = {}
var level: float = 0.0
var decals: Array[MeshInstance3D] = []   # the frost panes (one shared material)
var _mat: StandardMaterial3D
static var _tex: ImageTexture


## How frosted the panes are at round `r` (0..max), plus the boost once the fire is out.
static func frost_at(r: int, c: Dictionary, fire_out: bool) -> float:
	var full: float = float(c.get("full_round", 12))
	var f: float = lerpf(float(c.get("start", 0.15)), float(c.get("max", 0.8)), clampf(float(r - 1) / maxf(1.0, full - 1.0), 0.0, 1.0))
	if fire_out:
		f += float(c.get("fire_out_boost", 0.25))
	return clampf(f, 0.0, 1.0)


## Ice-fern texture: branching crystal strokes grown in from the edges, alpha heaviest at the rim.
static func texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.9, 1.0, 0.0))
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.09
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.seed = 3
	var soft: FastNoiseLite = FastNoiseLite.new()
	soft.frequency = 0.03
	soft.seed = 9
	for y: int in n:
		for x: int in n:
			var u: float = float(x) / float(n - 1)
			var v: float = float(y) / float(n - 1)
			var edge: float = minf(minf(u, 1.0 - u), minf(v, 1.0 - v))   # 0 at the rim, 0.5 in the middle
			# a frame of frost: thick on the wall round the opening and over the frame, thinning into the middle
			var reach: float = 0.08 + 0.1 * (soft.get_noise_2d(x, y) * 0.5 + 0.5)
			var rim: float = 1.0 - smoothstep(0.02, reach, edge)
			rim *= smoothstep(0.0, 0.03, edge)   # soft outer edge
			var fern: float = clampf(-noise.get_noise_2d(x, y), 0.0, 1.0)
			var a: float = rim * (0.55 + 0.45 * smoothstep(0.1, 0.6, fern))
			img.set_pixel(x, y, Color(0.82, 0.88, 0.98, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


func setup(c: Dictionary) -> void:
	cfg = c
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = texture()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1, 1, 1, 0)
	_mat.roughness = 0.35
	_mat.metallic_specular = 0.8
	_mat.emission_enabled = true
	_mat.emission = Color(0.55, 0.62, 0.75)
	_mat.emission_energy_multiplier = 0.08
	_mat.emission_texture = texture()
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for b: Node in get_tree().get_nodes_in_group(&"barricades"):
		var bar: Node3D = b as Node3D
		if bar == null or StringName(str(bar.get("zone_id"))) == &"YARD":
			continue
		var sill: float = float(bar.get("sill_height"))
		var top: float = float(bar.get("top_height"))
		var w: float = float(bar.get("width"))
		# a crust of frost on the inside of the opening, over the frame and the boards' ends (local +Z is inward)
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(w + 0.36, top - sill + 0.32)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Frost"
		mi.mesh = q
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_transform = Transform3D(bar.global_transform.basis.orthonormalized(), bar.global_position + Vector3(0, (sill + top) * 0.5, 0)) 			* Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.17))
		decals.append(mi)
	apply(0.0)


func apply(f: float) -> void:
	level = f
	if _mat != null:
		_mat.albedo_color = Color(1, 1, 1, f)
	for d: MeshInstance3D in decals:
		d.visible = f > 0.01


## Eases toward `target` over a few seconds (called every frame by MapAmbience).
func ease_to(target: float, delta: float) -> void:
	if absf(target - level) < 0.002:
		return
	apply(move_toward(level, target, delta * 0.05))
