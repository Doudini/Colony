shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Terrain texture atlas (terrain variations + alpha mask row)
uniform sampler2D terrain_atlas : source_color, filter_nearest, repeat_disable;

// Cliff texture (tiled rock face)
uniform sampler2D cliff_texture : source_color, filter_linear, repeat_enable;
uniform float cliff_tex_scale : hint_range(0.1, 10.0, 0.1) = 2.0;

const float TILES_PER_ROW = 16.0;
const float MASK_ROW = 9.0;

uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.5;

// Slope thresholds for cliff blending
uniform float cliff_slope_start : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float cliff_slope_end : hint_range(0.0, 1.0, 0.01) = 0.35;

// Cliff color tint (used when no cliff_texture assigned)
uniform vec4 cliff_color : source_color = vec4(0.45, 0.38, 0.32, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// Sample terrain atlas (same as flat terrain_blend shader)
	vec4 base_color = texture(terrain_atlas, UV);
	vec4 transition_color = texture(terrain_atlas, UV2);

	float mask_col = floor(COLOR.r * TILES_PER_ROW + 0.5);
	mask_col = clamp(mask_col, 0.0, TILES_PER_ROW - 1.0);
	vec2 mask_uv = vec2(
		(mask_col + fract(UV.x * TILES_PER_ROW)) / TILES_PER_ROW,
		(MASK_ROW + fract(UV.y * TILES_PER_ROW)) / TILES_PER_ROW
	);
	float mask = texture(terrain_atlas, mask_uv).a;

	vec3 terrain_color = mix(transition_color.rgb, base_color.rgb, mask);

	// Slope-based cliff blending using world normal
	float slope = normalize(world_normal).y; // 1.0 = flat, 0.0 = vertical

	// Triplanar-style cliff texturing for steep surfaces
	vec3 abs_normal = abs(normalize(world_normal));
	vec2 cliff_uv;
	if (abs_normal.x > abs_normal.z) {
		cliff_uv = world_pos.zy * cliff_tex_scale * 0.5;
	} else {
		cliff_uv = world_pos.xy * cliff_tex_scale * 0.5;
	}

	vec3 cliff_col = texture(cliff_texture, cliff_uv).rgb;
	// If cliff texture is default white (not assigned), use tint color instead
	float cliff_tex_avg = (cliff_col.r + cliff_col.g + cliff_col.b) / 3.0;
	if (cliff_tex_avg > 0.95) {
		cliff_col = cliff_color.rgb;
	}

	// Blend between terrain and cliff based on slope
	float cliff_blend = smoothstep(cliff_slope_start, cliff_slope_end, slope);
	ALBEDO = mix(terrain_color, cliff_col, cliff_blend);

	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;

	// Add some roughness variation based on slope
	ROUGHNESS = mix(0.85, 0.95, cliff_blend);
}
