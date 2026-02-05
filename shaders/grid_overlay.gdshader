shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled;

uniform float tile_size = 1.0;
uniform float line_width_px = 1.0;
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform float enabled : hint_range(0.0, 1.0, 1.0) = 1.0;

varying vec3 world_pos;

void vertex() {
	// Godot 4 uses MODEL_MATRIX instead of WORLD_MATRIX
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Corrected: Replaced 'return' with an if/else structure
	if (enabled < 0.1) {
		// If disabled, set the output to be fully transparent
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		// If enabled, run the grid calculation logic
		// World-space XZ → tile space
		vec2 p = world_pos.xz / tile_size;

		// Distance to nearest grid line
		vec2 grid = abs(fract(p - 0.5) - 0.5);

		// Screen-space derivatives → constant pixel thickness
		vec2 fw = fwidth(p);

		float line_x = smoothstep(0.0, fw.x * line_width_px, grid.x);
		float line_y = smoothstep(0.0, fw.y * line_width_px, grid.y);

		float line = 1.0 - min(line_x, line_y);

		ALBEDO = line_color.rgb;
		ALPHA = line * line_color.a;
	}
}
