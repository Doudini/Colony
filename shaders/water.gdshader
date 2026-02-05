shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D water_texture : source_color;
uniform vec4 deep_color : source_color = vec4(0.05, 0.18, 0.38, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.35, 0.52, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float wave_speed = 0.05;
uniform float wave_scale = 2.0;
uniform float foam_strength = 0.6;

void fragment() {
	vec2 uv = UV * wave_scale;
	uv += vec2(TIME * wave_speed, TIME * wave_speed * 0.7);

	vec3 tex_color = texture(water_texture, uv).rgb;

	float shore_mask = COLOR.r;
	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, shore_mask);
	vec3 foam = foam_color.rgb * shore_mask * foam_strength;

	ALBEDO = (base_color * tex_color) + foam;
	ALPHA = 1.0;
}
