shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// Terrain texture atlas (with alpha masks baked into each tile)
uniform sampler2D terrain_atlas : source_color, filter_nearest, repeat_disable;

void fragment() {
	// Sample the terrain atlas - UV comes from marching squares calculation
	vec4 tex_sample = texture(terrain_atlas, UV);

	ALBEDO = tex_sample.rgb;
	ALPHA = tex_sample.a;

	// Optional: slight darkening at edges for depth perception
	float edge_darken = smoothstep(0.0, 0.5, tex_sample.a);
	ALBEDO *= mix(0.9, 1.0, edge_darken);
}
