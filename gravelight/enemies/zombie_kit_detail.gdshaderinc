// Triplanar normal detail using a derivative tangent frame for each rest-space projection.
// This follows skinned deformation without introducing another vertex attribute or UV seam.
// Fragment VERTEX/NORMAL are view-space (Godot spatial shader reference).
vec3 tri_detail_orm(sampler2D tex, vec3 p, vec3 weights, float scale) {
	return texture(tex, p.yz * scale).rgb * weights.x + texture(tex, p.xz * scale).rgb * weights.y + texture(tex, p.xy * scale).rgb * weights.z;
}

vec3 detail_normal(sampler2D tex, vec2 uv, vec3 normal, vec3 view_pos, float strength) {
	vec2 xy = (texture(tex, uv).rg * 2.0 - 1.0) * strength;
	vec3 map = vec3(xy, sqrt(max(0.0001, 1.0 - dot(xy, xy)))); // BC5 stores only RG.
	vec3 dx = dFdx(view_pos);
	vec3 dy = dFdy(view_pos);
	vec2 ux = dFdx(uv);
	vec2 uy = dFdy(uv);
	vec3 px = cross(dy, normal);
	vec3 py = cross(normal, dx);
	vec3 tangent = px * ux.x + py * uy.x;
	vec3 bitangent = px * ux.y + py * uy.y;
	float scale = inversesqrt(max(max(dot(tangent, tangent), dot(bitangent, bitangent)), 0.0000000000000001));
	return normalize(tangent * (map.x * scale) + bitangent * (map.y * scale) + normal * map.z);
}

vec3 tri_detail_normal(sampler2D tex, vec3 p, vec3 weights, vec3 normal, vec3 view_pos, float scale, float strength) {
	return normalize(detail_normal(tex, p.yz * scale, normal, view_pos, strength) * weights.x
		+ detail_normal(tex, p.xz * scale, normal, view_pos, strength) * weights.y
		+ detail_normal(tex, p.xy * scale, normal, view_pos, strength) * weights.z);
}
