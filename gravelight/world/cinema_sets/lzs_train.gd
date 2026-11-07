extends CinemaSet
## T-194, LAZARUS SATURDAY set H (§6.1): a hard-class compartment on the Moscow train at night, April 1930: varnished
## wooden benches facing each other across it (x -0.8 and +0.8, running along z), a luggage rack, a lamp swinging on
## its chain, the window at the end (z -1.3) with snow going by and the dark birches, the door behind (z +1.3).
## Volkov upright on the left bench, cap off, the grey lead case on his knees and both arms round it.
## Markers: Volkov, Case, Window. Effects: none (the lamp swings and the night goes by on their own).

var lamp_pivot: Node3D
var window_mat: ShaderMaterial
var _t: float = 0.0

const WINDOW_SHADER: String = """
shader_type spatial;
render_mode unshaded;
uniform float t = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec3 c = mix(vec3(0.02, 0.025, 0.045), vec3(0.08, 0.09, 0.13), uv.y);
	// the birches going by: dark posts at random spacing, scrolling fast
	float x = uv.x * 6.0 + t * 2.4;
	float cell = floor(x);
	float f = fract(x);
	float w = 0.04 + 0.05 * h(vec2(cell, 3.0));
	float tree = step(abs(f - 0.5), w) * step(0.35 + 0.3 * h(vec2(cell, 9.0)), 1.0 - uv.y + 0.6);
	c = mix(c, vec3(0.01, 0.01, 0.012), tree * 0.85);
	// snow: streaks across, faster near
	for (int i = 0; i < 3; i++) {
		vec2 g = vec2(uv.x * (40.0 + float(i) * 25.0) + t * (18.0 + float(i) * 14.0), uv.y * (22.0 + float(i) * 9.0) - t * 1.5);
		vec2 id = floor(g);
		vec2 fr = fract(g);
		float s = step(0.86, h(id + float(i) * 7.0)) * smoothstep(0.3, 0.0, length((fr - 0.5) * vec2(0.35, 1.4)));
		c += vec3(0.5, 0.52, 0.58) * s * (0.25 + 0.2 * float(i));
	}
	ALBEDO = c;
}
"""


func _build() -> void:
	env({"bg": [0.0, 0.0, 0.0], "ambient": [0.3, 0.26, 0.2], "ambient_e": 0.18, "glow_t": 1.1})
	var varnish: StandardMaterial3D = noisy(Color(0.26, 0.15, 0.07), Color(0.38, 0.23, 0.11), 1.2, 0.6, 0.35)
	box(self, Vector3(0, -0.05, 0), Vector3(2.4, 0.1, 2.8), "floorboards")
	box(self, Vector3(0, 2.45, 0), Vector3(2.4, 0.1, 2.8), varnish)
	for sx: float in [-1.2, 1.2]:
		box(self, Vector3(sx, 1.2, 0), Vector3(0.08, 2.5, 2.8), varnish)
		box(self, Vector3(sx * 0.68, 0.22, 0), Vector3(0.62, 0.44, 2.6), varnish)   # the bench's box
		box(self, Vector3(sx * 0.68, 0.46, 0), Vector3(0.6, 0.05, 2.6), varnish)    # the slats
		box(self, Vector3(sx * 0.94, 0.85, 0), Vector3(0.06, 0.8, 2.6), varnish)    # the back
		box(self, Vector3(sx * 0.82, 1.95, 0), Vector3(0.36, 0.03, 2.6), "rope")    # the luggage rack
	box(self, Vector3(0, 1.2, -1.4), Vector3(2.4, 2.5, 0.08), varnish)
	box(self, Vector3(0, 1.2, 1.4), Vector3(2.4, 2.5, 0.08), varnish)
	box(self, Vector3(0.0, 1.15, 1.35), Vector3(0.8, 2.0, 0.03), "walnut")       # the door
	cyl(self, Vector3(0.3, 1.1, 1.32), 0.02, 0.12, "brass", Vector3(0, 0, 90))
	# the window: the night going by
	var sh: Shader = Shader.new()
	sh.code = WINDOW_SHADER
	window_mat = ShaderMaterial.new()
	window_mat.shader = sh
	var win: MeshInstance3D = card(self, Vector3(0, 1.35, -1.355), Vector2(1.2, 0.85), window_mat, 0.0, "Window")
	win.position.z = -1.355
	for wy: float in [0.92, 1.78]:
		box(self, Vector3(0, wy, -1.35), Vector3(1.3, 0.06, 0.04), varnish)
	box(self, Vector3(0, 0.88, -1.32), Vector3(1.3, 0.05, 0.14), varnish)
	# the lamp on its chain, swinging with the train
	lamp_pivot = group(self, "LampPivot", Vector3(0, 2.4, 0.2))
	cyl(lamp_pivot, Vector3(0, -0.2, 0), 0.006, 0.4, "brass")
	cone(lamp_pivot, Vector3(0, -0.45, 0), 0.09, 0.06, 0.18, glow(Color(1.0, 0.78, 0.48), 1.6), 10)
	var l: OmniLight3D = omni(lamp_pivot, Vector3(0, -0.5, 0), [1.0, 0.74, 0.44], 1.4, 5.0)
	l.set_meta("flicker", 1.4)
	l.add_to_group(&"cinema_flicker")
	# Volkov with the case
	var v: CinemaPerson = person(self, "volkov", look_of("volkov_train"), Vector3(-0.72, 0.0, -0.25), -90.0, "sit_hold")
	v.name = "Volkov"
	v.hold_lift = 0.45
	var case: Node3D = group(self, "Case", Vector3(-0.38, 0.62, -0.25))
	lead_case(case, false)
	case.rotation_degrees = Vector3(0, 90, 0)
	var cap: Node3D = group(self, "CapOnBench", Vector3(-0.7, 0.5, 0.5))
	cyl(cap, Vector3.ZERO, 0.13, 0.06, "#3a3f4a")


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if lamp_pivot != null:
		lamp_pivot.rotation.z = sin(_t * 1.7) * 0.12 + sin(_t * 0.6) * 0.04
		lamp_pivot.rotation.x = sin(_t * 1.1 + 1.0) * 0.05
	if window_mat != null:
		window_mat.set_shader_parameter("t", _t)
