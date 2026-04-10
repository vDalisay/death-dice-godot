shader_type canvas_item;
// Soft edge vignette with a slow pulse for a dreamy, uneasy frame.

uniform float radius : hint_range(0.3, 1.5) = 0.85;
uniform float softness : hint_range(0.1, 1.0) = 0.45;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float pulse_strength : hint_range(0.0, 0.2) = 0.08;
uniform float bruise_strength : hint_range(0.0, 0.5) = 0.2;
uniform float drift_strength : hint_range(0.0, 0.4) = 0.1;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 drifted = centered;
	drifted.x += sin(TIME * 0.09 + centered.y * 3.2) * drift_strength * 0.03;
	drifted.y += cos(TIME * 0.07 - centered.x * 2.6) * drift_strength * 0.02;
	float pulse = 1.0 + sin(TIME * 0.14 + centered.y * 2.1) * pulse_strength;
	float dist = length(vec2((drifted.x + drift_strength * 0.08) * 0.95, drifted.y * 1.12));
	float vig = smoothstep(radius, radius - softness, dist);
	float stain = 0.5 + 0.5 * sin((drifted.y * 1.9 - drifted.x * 1.2 - TIME * 0.05) * 6.28318530718);
	float bruise = 0.5 + 0.5 * sin((drifted.x * 2.6 + drifted.y * 2.1 + TIME * 0.04) * 6.28318530718);
	float edge_bias = smoothstep(0.32, 0.94, dist) * smoothstep(0.1, 0.9, centered.x + 0.55);
	vec3 vignette_color = mix(color.rgb, vec3(0.16, 0.03, 0.04), stain * 0.12 + bruise_strength * bruise * 0.24);
	vignette_color = mix(vignette_color, vec3(0.02, 0.08, 0.07), (1.0 - stain) * drift_strength * 0.22);
	float alpha = (1.0 - vig) * intensity * pulse;
	alpha += edge_bias * bruise_strength * 0.12;
	COLOR = vec4(vignette_color, clamp(alpha, 0.0, 1.0));
}
