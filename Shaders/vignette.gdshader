shader_type canvas_item;
// Soft edge vignette with a slow pulse for a dreamy, uneasy frame.

uniform float radius : hint_range(0.3, 1.5) = 0.85;
uniform float softness : hint_range(0.1, 1.0) = 0.45;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float pulse_strength : hint_range(0.0, 0.2) = 0.08;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float pulse = 1.0 + sin(TIME * 0.16 + centered.y * 2.4) * pulse_strength;
	float dist = length(vec2(centered.x * 0.97, centered.y * 1.08));
	float vig = smoothstep(radius, radius - softness, dist);
	float stain = 0.5 + 0.5 * sin((centered.y * 1.9 - centered.x * 1.2 - TIME * 0.05) * 6.28318530718);
	vec3 vignette_color = mix(color.rgb, vec3(0.16, 0.03, 0.04), stain * 0.14);
	COLOR = vec4(vignette_color, clamp((1.0 - vig) * intensity * pulse, 0.0, 1.0));
}
