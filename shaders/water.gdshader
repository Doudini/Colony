shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_alpha_prepass;

uniform sampler2D water_texture : source_color;
uniform vec4 deep_color : source_color = vec4(0.05, 0.18, 0.38, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.35, 0.52, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float wave_speed = 0.05;
uniform float wave_scale = 2.0;
uniform float foam_strength = 0.6;
uniform float base_alpha = 0.55;
uniform float fresnel_power = 4.0;
uniform float fresnel_alpha_boost = 0.25;

void fragment() {
	vec2 uv = UV * wave_scale;
	uv += vec2(TIME * wave_speed, TIME * wave_speed * 0.7);

	vec3 tex_color = texture(water_texture, uv).rgb;

	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, 0.5);
	vec3 foam = foam_color.rgb * foam_strength * 0.15;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	float alpha = clamp(base_alpha + fresnel * fresnel_alpha_boost, 0.0, 1.0);

	ALBEDO = (base_color * tex_color) + foam;
	ALPHA = alpha;
}
