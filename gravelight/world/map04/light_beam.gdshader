shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// A searchlight beam (UPDATE 09 section 5.3, DECISIONS T-147; our own): an open cone mesh, additive, brightest at
// its foot and along its axis, fading up its length (UV.y = 0 at the lamp, 1 at the tip) and at its silhouette.

uniform vec4 beam_color : source_color = vec4(0.75, 0.82, 1.0, 1.0);
uniform float intensity = 0.35;

varying vec3 vnrm;
varying vec3 vview;

void vertex() {
	vnrm = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vview = normalize(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float edge = pow(abs(dot(normalize(vnrm), normalize(vview))), 1.5);
	ALBEDO = beam_color.rgb * intensity * (1.0 - along) * (1.0 - along) * edge;
}
