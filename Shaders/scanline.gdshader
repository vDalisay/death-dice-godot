shader_type canvas_item;
// Full-screen CRT scanline overlay inspired by Balatro-style presentation.

uniform float line_density : hint_range(200.0, 1600.0) = 600.0;
uniform float intensity : hint_range(0.0, 0.4) = 0.24;
uniform float thickness : hint_range(0.05, 1.0) = 0.45;
uniform vec4 tint : source_color = vec4(0.03, 0.05, 0.06, 1.0);

void fragment() {
	float scan = 0.5 + 0.5 * sin(SCREEN_UV.y * line_density * 6.28318530718);
	float macro = 0.5 + 0.5 * sin(SCREEN_UV.y * line_density * 0.125 * 6.28318530718);
	float line_mask = smoothstep(1.0 - thickness, 1.0, scan);
	float alpha = mix(intensity * 0.18, intensity, line_mask);
	alpha *= mix(0.85, 1.1, macro);
	COLOR = vec4(tint.rgb, alpha);
}
