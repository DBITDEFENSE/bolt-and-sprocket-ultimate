shader_type sky;
// Der Kranich's night (UPDATE 09 section 5.3, DECISIONS T-147; our own): the sky behind every window, blister and
// breach. A deep blue-black gradient, a hard star field (no stars in the radiance pass, so the interior's reflections
// stay dark), the moon's disc and halo where the act's Moon light comes from (LIGHT0), the haze under the horizon
// that the ground plane fades into (FlightSky keeps them the same colour so the far plane never shows), the violet
// glow to the east after the London window (`east_glow`), and the dawn for the crash (`dawn`).

uniform vec4 top_color : source_color = vec4(0.012, 0.018, 0.045, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.07, 0.09, 0.16, 1.0);
uniform vec4 haze_color : source_color = vec4(0.06, 0.075, 0.12, 1.0);
uniform vec4 moon_color : source_color = vec4(0.92, 0.94, 1.0, 1.0);
uniform float moon_size = 0.022;          // radians
uniform float star_density : hint_range(0.0, 1.0) = 0.6;
uniform float star_gain = 6.0;
uniform float east_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 east_color : source_color = vec4(0.32, 0.1, 0.45, 1.0);
uniform float dawn : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dawn_color : source_color = vec4(0.95, 0.55, 0.3, 1.0);
uniform float flash : hint_range(0.0, 4.0) = 0.0;   // flak / searchlight wash over the lower sky

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color.rgb, top_color.rgb, pow(clamp(h, 0.0, 1.0), 0.45));
	} else {
		col = mix(horizon_color.rgb, haze_color.rgb, clamp(-h * 6.0, 0.0, 1.0));
	}
	// the east (+X, starboard) turns violet after London; dawn warms the horizon ahead and low
	float east = clamp(d.x * 0.5 + 0.5, 0.0, 1.0);
	col += east_color.rgb * east_glow * pow(east, 3.0) * exp(-abs(h) * 5.0);
	col = mix(col, mix(col, dawn_color.rgb * 0.6, exp(-abs(h) * 4.0)), dawn);
	col += vec3(0.25, 0.22, 0.3) * flash * exp(-max(-h, 0.0) * 3.0) * 0.08;
	if (!AT_CUBEMAP_PASS) {
		// stars: one candidate per cell of a cube-ish grid on the sphere, twinkling
		if (h > -0.05) {
			vec3 g = d * 170.0;
			vec3 cell = floor(g);
			float rnd = hash13(cell);
			if (rnd > 1.0 - star_density * 0.12) {
				vec3 c = cell + vec3(hash13(cell + 1.7), hash13(cell + 3.1), hash13(cell + 5.9));
				float dist = length(g - c);
				float tw = 0.75 + 0.25 * sin(TIME * (1.5 + rnd * 4.0) + rnd * 40.0);
				float s = smoothstep(0.42, 0.0, dist) * tw * (0.3 + 0.7 * fract(rnd * 17.0));
				col += vec3(0.85, 0.9, 1.0) * s * star_gain * smoothstep(-0.05, 0.12, h) * (1.0 - dawn);
			}
		}
		if (LIGHT0_ENABLED) {
			float a = acos(clamp(dot(d, LIGHT0_DIRECTION), -1.0, 1.0));
			float disc = smoothstep(moon_size, moon_size * 0.92, a);
			// a few maria
			vec3 mp = d - LIGHT0_DIRECTION;
			float maria = 0.82 + 0.18 * sin(mp.x * 400.0) * sin(mp.y * 350.0 + 1.0);
			col = mix(col, moon_color.rgb * 1.6 * maria, disc);
			col += moon_color.rgb * 0.3 * exp(-a * 6.0) * (1.0 - dawn);
		}
	}
	COLOR = col;
}
