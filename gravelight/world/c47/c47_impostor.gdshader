shader_type spatial;
// UPDATE 12 section 5 (T-211): GRAVELIGHT ONE far off, as an 8-view impostor (tools/c47/build_c47.py renders the
// atlas: views at yaw 0, 45 ... deg round the wreck, 4 x 2). A Y-axis billboard; the view nearest the camera's
// bearing in the model's own frame is drawn. Lit like a card facing the viewer, alpha scissor.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int frames = 8;
uniform int cols = 4;
uniform int rows = 2;
uniform vec4 tint : source_color = vec4(0.7, 0.72, 0.78, 1.0);

varying flat int frame_i;

void vertex() {
	vec3 cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	float yaw = atan(cam_local.x, cam_local.z);
	int k = int(round(yaw / (TAU / float(frames))));
	frame_i = (k % frames + frames) % frames;
	// face the camera round the model's Y axis
	vec3 to_cam = normalize(vec3(cam_local.x, 0.0, cam_local.z));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	VERTEX = right * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	NORMAL = to_cam;
}

void fragment() {
	int c = frame_i % cols;
	int r = frame_i / cols;
	vec2 uv = (vec2(float(c), float(r)) + UV) / vec2(float(cols), float(rows));
	vec4 t = texture(atlas, uv);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}
