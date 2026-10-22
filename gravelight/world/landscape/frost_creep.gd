class_name FrostCreep
extends Node3D
## Frost creeping over the inn's windows as the night goes on (Update 02 section 7, T-052): a decal on the inside
## of every walled window (the yard's fence gaps have no glass to frost), feathery crystals thickest at the frame's
## edges, its opacity rising with the round and jumping when the hearth dies. The texture is drawn once in code.

var cfg: Dictionary = {}
var level: float = 0.0
var decals: Array[Decal] = []
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
			var reach: float = 0.16 + 0.14 * (soft.get_noise_2d(x, y) * 0.5 + 0.5)
			var rim: float = 1.0 - smoothstep(0.0, reach, edge)
			var fern: float = clampf(noise.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
			var a: float = rim * (0.35 + 0.65 * smoothstep(0.35, 0.75, fern))
			img.set_pixel(x, y, Color(0.82, 0.88, 0.98, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


func setup(c: Dictionary) -> void:
	cfg = c
	for b: Node in get_tree().get_nodes_in_group(&"barricades"):
		var bar: Node3D = b as Node3D
		if bar == null or StringName(str(bar.get("zone_id"))) == &"YARD":
			continue
		var sill: float = float(bar.get("sill_height"))
		var top: float = float(bar.get("top_height"))
		var w: float = float(bar.get("width"))
		var d: Decal = Decal.new()
		d.name = "Frost"
		d.texture_albedo = texture()
		d.size = Vector3(w + 0.5, 0.7, top - sill + 0.45)
		d.normal_fade = 0.35
		d.upper_fade = 0.15
		d.lower_fade = 0.15
		d.cull_mask = 1
		d.modulate = Color(1, 1, 1, 0.0)
		add_child(d)
		# local +Z of a barricade points into the room; the decal projects along its own -Y, so its +Y faces in
		var bx: Basis = bar.global_transform.basis.orthonormalized()
		var inward: Vector3 = bx.z
		d.global_transform = Transform3D(Basis(bx.x, inward, bx.x.cross(inward)), bar.global_position + Vector3(0, (sill + top) * 0.5, 0) + inward * 0.12)
		decals.append(d)
	apply(0.0)


func apply(f: float) -> void:
	level = f
	for d: Decal in decals:
		d.modulate = Color(1, 1, 1, f)
		d.visible = f > 0.01


## Eases toward `target` over a few seconds (called every frame by MapAmbience).
func ease_to(target: float, delta: float) -> void:
	if absf(target - level) < 0.002:
		return
	apply(move_toward(level, target, delta * 0.05))
