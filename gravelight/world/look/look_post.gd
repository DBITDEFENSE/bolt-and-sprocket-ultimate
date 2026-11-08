class_name LookPost
extends CanvasLayer
## UPDATE 12 section 2 (DECISIONS T-208, contract C2): the one post stack. A CanvasLayer under the HUD (layer 5, the
## old PostFx slot: every map scene already carries one, so PostFx now extends this) with one full-screen ColorRect
## that reads the screen once (look_post.gdshader): film grain, the oval vignette, lens softness and chromatic
## aberration at the frame edge only, and the projector flicker on the menu. The tonemap, the per-map grade and the
## fog (volumetric on Forward+, gated by the Volumetric fog setting) are the Environment's, set by LookGrade.
##
## Driven by data: `LookGrade.post_params(grade_id, zone)` (data/look/<map>.json `post`, the web profile's
## data/look/_web.json merged in on the Compatibility renderer), each piece switched off by its graphics setting
## (film_grain, post_vignette, post_edge_soft, post_ca). A map with no grade, or `--look=off`, keeps the pre-U12
## PostFx look (vignette 0.42 and the cold shadow lift: `legacy`), so the "before" frames are the U11 game.
## The archive-reel grade (`cinema_reel`) is section 3's own film treatment: the post stands aside there.
## Where it sits: a map (PostFx, the map's map_id), the main menu (`menu`, under the menus), a CinemaReel stage
## (inside the reel's SubViewport, under its letterbox and cards, the host map's grade). The HUD, the subtitles and
## every menu are above it and never touched. Presentation only.

const SHADER_PATH: String = "res://gravelight/world/look/look_post.gdshader"
const DEFAULT_LAYER: int = 5
## The grade's post key -> the GLSettings value that switches it (Settings > Video).
const TOGGLES: Dictionary = {"grain": "film_grain", "vignette": "post_vignette", "edge_soft": "post_edge_soft", "ca": "post_ca"}
## Grades whose film look is section 3's archive-reel treatment (the reel's own shader / the treated .ogv).
const REEL_GRADES: PackedStringArray = ["cinema_reel"]
## The pre-U12 PostFx look (a map with no grade, the "before" frames).
const LEGACY: Dictionary = {"grain": 0.0, "vignette": 0.42, "edge_soft": 0.0, "ca": 0.0, "flicker": 0.0, "legacy": 1.0}
const GROUP: StringName = &"look_post"
const GRAIN_GROUP: StringName = &"look_post_grain"   # GLSettings hides its old full-screen grain while one of these draws

## The grade this post draws ("" = the nearest ancestor's map_id).
@export var grade_id: String = ""
var zone: String = ""
var uniforms: Dictionary = {}
var _rect: ColorRect = null
var _mat: ShaderMaterial = null
static var _shader: Shader = null


func _init() -> void:
	layer = DEFAULT_LAYER


func _ready() -> void:
	add_to_group(GROUP)
	_rect = ColorRect.new()
	_rect.name = "LookPostRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = shader()
	_rect.material = _mat
	add_child(_rect)
	refresh()


func _exit_tree() -> void:
	if is_in_group(GRAIN_GROUP):
		remove_from_group(GRAIN_GROUP)
		_grain_changed()


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


## Which grade this post draws: the export, else the map it sits in.
func resolved_grade() -> String:
	if grade_id != "":
		return grade_id
	var n: Node = get_parent()
	while n != null:
		var v: Variant = n.get("map_id")
		if v != null and str(v) != "":
			return str(v)
		n = n.get_parent()
	return ""


func set_grade(id: String, zone_: String = "") -> void:
	grade_id = id
	zone = zone_
	if is_inside_tree():
		refresh()


func set_zone(zone_: String) -> void:
	if zone_ != zone:
		zone = zone_
		refresh()


## Re-reads the grade and the settings (GLSettings.apply_visuals calls it on every post after a settings change).
func refresh() -> void:
	if _mat == null:
		return
	var id: String = resolved_grade()
	uniforms = compute(id, zone, settings_toggles())
	for k: String in ["grain", "vignette", "edge_soft", "ca", "flicker", "legacy"]:
		_mat.set_shader_parameter(k, float(uniforms.get(k, 0.0)))
	var draws: bool = bool(uniforms.get("draws", false))
	_rect.visible = draws
	visible = draws
	var animated: bool = draws and (float(uniforms.get("grain", 0.0)) > 0.0 or float(uniforms.get("flicker", 0.0)) > 0.0)
	set_process(animated)
	var owns_grain: bool = draws and float(uniforms.get("legacy", 0.0)) < 0.5
	if owns_grain != is_in_group(GRAIN_GROUP):
		if owns_grain:
			add_to_group(GRAIN_GROUP)
		else:
			remove_from_group(GRAIN_GROUP)
		_grain_changed()


func _process(_dt: float) -> void:
	_mat.set_shader_parameter("frame", float(Engine.get_frames_drawn() % 100000))


func _grain_changed() -> void:
	var gs: Node = get_node_or_null(^"/root/GLSettings")
	if gs != null and gs.has_method("refresh_grain"):
		gs.call_deferred("refresh_grain")


## The player's switches: {grain, vignette, edge_soft, ca} -> on / off (all on without GLSettings).
static func settings_toggles() -> Dictionary:
	var out: Dictionary = {}
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var gs: Node = loop.root.get_node_or_null(^"GLSettings") if loop != null else null
	var vals: Dictionary = gs.get("values") if gs != null else {}
	for k: String in TOGGLES.keys():
		out[k] = bool(vals.get(TOGGLES[k], true))
	return out


## Pure: the shader's uniforms for grade `id` (and `zone`) under the player's `toggles`. `draws` false = the rect is
## hidden (a reel grade, or every piece off). No grade / `--look=off` gives the legacy PostFx look.
static func compute(id: String, zone_: String, toggles: Dictionary) -> Dictionary:
	if REEL_GRADES.has(id):
		return {"draws": false, "reel": true}
	var p: Dictionary = LookGrade.post_params(id, zone_) if id != "" else {}
	var out: Dictionary = {}
	if p.is_empty():
		out = LEGACY.duplicate()
		out["grain"] = 0.0   # the legacy grain is GLSettings' own overlay
	else:
		out = {"legacy": 0.0}
		for k: String in ["grain", "vignette", "edge_soft", "ca", "flicker"]:
			out[k] = clampf(float(p.get(k, 0.0)), 0.0, 1.0)
	for k: String in TOGGLES.keys():
		if not bool(toggles.get(k, true)):
			out[k] = 0.0
	var any: bool = float(out.get("legacy", 0.0)) > 0.0   # the legacy cold shadow lift always draws
	for k: String in ["grain", "vignette", "edge_soft", "ca", "flicker"]:
		any = any or float(out.get(k, 0.0)) > 0.0
	out["draws"] = any
	out["grade"] = id
	return out


## Adds a post for `grade` under `parent` (the menu, a cinema stage's viewport); returns it.
static func add_to(parent: Node, grade: String, layer_: int = DEFAULT_LAYER) -> LookPost:
	var lp: LookPost = LookPost.new()
	lp.name = "LookPost"
	lp.grade_id = grade
	lp.layer = layer_
	parent.add_child(lp)
	return lp
