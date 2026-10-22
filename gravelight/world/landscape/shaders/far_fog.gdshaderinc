// Custom distance fog for the landscape beyond the play space (Update 02 section 7, T-052).
// The map's own fog (exponential, 0.022/m plus 40 m of volumetric fog) hides everything past ~120 m, so the
// layers behind the near crest use fog_disabled and this capped curve instead: they fade toward the night haze
// but never vanish, which is what makes the hills and mountains read as silhouettes in depth.
// Landscape.gd keeps the uniforms in step with the WorldEnvironment (the campaign's dawn cutscene warms it).
uniform vec3 fog_color : source_color = vec3(0.075, 0.095, 0.155);
uniform float fog_max = 0.86;
uniform float fog_k = 0.024;
uniform float fog_bias = 0.0;      // per-layer offset (the far mountains sit a little deeper in the haze)

float far_fog_amount(float dist) {
	return clamp(fog_max * (1.0 - exp(-fog_k * dist)) + fog_bias, 0.0, 0.985);
}
