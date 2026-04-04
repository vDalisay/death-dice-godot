shader_type canvas_item;
// Soft edge vignette. Rendered on a full-screen ColorRect.

uniform float radius : hint_range(0.3, 1.5) = 0.85;
uniform float softness : hint_range(0.1, 1.0) = 0.45;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float vig = smoothstep(radius, radius - softness, dist);
	COLOR = vec4(color.rgb, (1.0 - vig) * intensity);
}
