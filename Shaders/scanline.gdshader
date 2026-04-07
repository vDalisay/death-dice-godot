shader_type canvas_item;
// Full-screen CRT scanline overlay with drifting lines and analog-horror haze.

uniform float line_density : hint_range(200.0, 1600.0) = 600.0;
uniform float intensity : hint_range(0.0, 0.4) = 0.24;
uniform float thickness : hint_range(0.05, 1.0) = 0.45;
uniform float drift_speed : hint_range(0.0, 0.08) = 0.018;
uniform float roll_strength : hint_range(0.0, 1.0) = 0.34;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.28;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec4 tint : source_color = vec4(0.03, 0.05, 0.06, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float drifted_y = uv.y + TIME * drift_speed;
	drifted_y += sin((uv.x * 3.2 + TIME * 0.45) * 6.28318530718) * 0.0015;
	float scan = 0.5 + 0.5 * sin(drifted_y * line_density * 6.28318530718);
	float macro = 0.5 + 0.5 * sin((drifted_y * line_density * 0.11 - TIME * 0.85) * 6.28318530718);
	float line_mask = smoothstep(1.0 - thickness, 1.0, scan);
	float sweep = 0.5 + 0.5 * sin((uv.y * 1.75 - TIME * 0.12) * 6.28318530718);
	float haze = 0.5 + 0.5 * sin((uv.y * 2.1 + uv.x * 0.65 + TIME * 0.08) * 6.28318530718);
	float grain = hash(floor((uv + vec2(TIME * 0.015, TIME * 0.09)) * vec2(640.0, 360.0)));
	float edge = smoothstep(0.38, 0.92, length(uv - vec2(0.5)) * 1.55);
	float alpha = mix(intensity * 0.2, intensity * 1.02, line_mask);
	alpha *= mix(0.85, 1.1, macro);
	alpha += sweep * roll_strength * 0.07;
	alpha += haze * haze_strength * 0.05;
	alpha += grain * grime_strength * 0.035;
	alpha += edge * grime_strength * 0.04;
	alpha = clamp(alpha, 0.0, 0.52);

	vec3 color = tint.rgb;
	vec3 phosphor_tint = vec3(0.66, 0.83, 0.74);
	vec3 bruise_tint = vec3(0.19, 0.05, 0.06);
	color = mix(color, phosphor_tint, sweep * haze_strength * 0.14);
	color = mix(color, bruise_tint, edge * grime_strength * 0.32);
	color += (grain - 0.5) * grime_strength * 0.04;
	color = clamp(color, 0.0, 1.0);
	COLOR = vec4(color, alpha);
}
