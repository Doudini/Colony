shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// Terrain texture atlas (terrain variations + alpha mask row)
uniform sampler2D terrain_atlas : source_color, filter_nearest, repeat_disable;

const float TILES_PER_ROW = 16.0;
const float MASK_ROW = 10.0;

uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.5;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 base_color = texture(terrain_atlas, UV);
	vec4 transition_color = texture(terrain_atlas, UV2);

	float mask_col = floor(COLOR.r * TILES_PER_ROW + 0.5);
	vec2 tile_id = floor(UV * TILES_PER_ROW);
	float mask_row = 10.0 + floor(hash(tile_id) * 6.0);
	
	mask_col = clamp(mask_col, 0.0, TILES_PER_ROW - 1.0);
	vec2 mask_uv = vec2(
		(mask_col + fract(UV.x * TILES_PER_ROW)) / TILES_PER_ROW,
		(mask_row + fract(UV.y * TILES_PER_ROW)) / TILES_PER_ROW
	);
	float mask = texture(terrain_atlas, mask_uv).a;

	ALBEDO = mix(transition_color.rgb, base_color.rgb, mask);
	
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff; 
}
