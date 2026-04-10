shader_type canvas_item;
// Fast CRT distress static overlay for bust and machine-error moments.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.16, 0.2, 1.0);
uniform float banding : hint_range(4.0, 64.0) = 18.0;
uniform float tear_strength : hint_range(0.0, 1.0) = 0.6;
uniform float block_strength : hint_range(0.0, 1.0) = 0.35;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tear_seed = hash(vec2(floor(TIME * 7.0), floor(uv.y * 28.0)));
	float strip_gate = smoothstep(0.72, 0.98, 0.5 + 0.5 * sin(TIME * 9.0 + uv.y * 31.0));
	uv.x += (tear_seed - 0.5) * intensity * tear_strength * 0.06 * max(step(0.8, tear_seed), strip_gate * 0.5);
	float block_noise = hash(floor((uv + vec2(TIME * 0.7, -TIME * 0.35)) * vec2(42.0, 28.0)));
	float block_gate = step(0.83, block_noise) * block_strength * intensity;
	vec2 smear_uv = uv + vec2((block_noise - 0.5) * 0.085 * block_gate, 0.0);
	vec4 scene = textureLod(SCREEN_TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)), 0.0);
	vec3 smeared_scene = textureLod(SCREEN_TEXTURE, clamp(smear_uv, vec2(0.0), vec2(1.0)), 0.0).rgb;
	float noise = hash(floor(uv * vec2(320.0, 180.0) + vec2(TIME * 90.0, TIME * 63.0)));
	float scan_band = sin((uv.y * banding + TIME * 22.0) * 6.28318530718) * 0.5 + 0.5;
	float grit = hash(floor(uv * vec2(96.0, 54.0) - vec2(TIME * 18.0, 0.0)));
	float block_scan = hash(floor(uv * vec2(28.0, 18.0) + vec2(TIME * 13.0, -TIME * 9.0)));
	float flash = mix(noise, scan_band, 0.35);
	vec3 distress_tint = mix(tint.rgb, vec3(0.3, 0.58, 0.48), grit * 0.22 + block_scan * 0.12);
	vec3 corrupted_scene = mix(scene.rgb, smeared_scene, block_gate);
	vec3 digital_blocks = distress_tint * mix(flash, block_scan, 0.45) + vec3(noise * 0.78);
	vec3 static_rgb = mix(corrupted_scene, digital_blocks, intensity * 0.82);
	static_rgb += (grit - 0.5) * intensity * 0.06;
	static_rgb += (block_noise - 0.5) * block_gate * 0.18;
	static_rgb = clamp(static_rgb, 0.0, 1.0);
	COLOR = vec4(static_rgb, intensity * 0.85);
}
