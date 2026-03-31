shader_type canvas_item;
// Subtle CRT scanline overlay. Rendered on a full-screen ColorRect.

uniform float line_count : hint_range(100.0, 800.0) = 320.0;
uniform float intensity : hint_range(0.0, 0.3) = 0.06;

void fragment() {
	float scan = sin(UV.y * line_count * 3.14159) * 0.5 + 0.5;
	float darken = mix(1.0, 1.0 - intensity, scan);
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - darken));
}
