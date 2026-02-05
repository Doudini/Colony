shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// Alpha mask texture (16 masks in a row)
uniform sampler2D alpha_mask_texture : source_color, filter_linear, repeat_disable;

// Optional terrain base texture (tileable)
uniform sampler2D terrain_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_terrain_texture = false;

// How much the terrain texture tiles within each game tile
uniform float texture_scale : hint_range(0.1, 10.0) = 1.0;

varying vec2 world_uv;
varying vec4 vertex_color;

void vertex() {
	// Pass world position for terrain texture tiling
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * texture_scale * 0.1;
	// Pass vertex color
	vertex_color = COLOR;
}

void fragment() {
	// Get terrain color from vertex color or texture
	vec3 terrain_color;
	if (use_terrain_texture) {
		terrain_color = texture(terrain_texture, world_uv).rgb;
	} else {
		terrain_color = vertex_color.rgb;
	}

	// Sample alpha mask
	// UV contains coordinates within the mask (0-1 for the selected mask tile)
	vec4 mask_sample = texture(alpha_mask_texture, UV);
	float alpha = mask_sample.a;

	ALBEDO = terrain_color;
	ALPHA = alpha;

	// Slight darkening at edges for depth perception
	float edge_darken = smoothstep(0.0, 0.5, alpha);
	ALBEDO *= mix(0.85, 1.0, edge_darken);
}
