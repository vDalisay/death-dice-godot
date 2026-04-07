shader_type canvas_item;
// Fast CRT distress static overlay for bust and machine-error moments.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.16, 0.2, 1.0);
uniform float banding : hint_range(4.0, 64.0) = 18.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tear_seed = hash(vec2(floor(TIME * 7.0), floor(uv.y * 28.0)));
	uv.x += (tear_seed - 0.5) * intensity * 0.045 * step(0.82, tear_seed);
	vec4 scene = textureLod(SCREEN_TEXTURE, uv, 0.0);
	float noise = hash(floor(uv * vec2(320.0, 180.0) + vec2(TIME * 90.0, TIME * 63.0)));
	float scan_band = sin((uv.y * banding + TIME * 22.0) * 6.28318530718) * 0.5 + 0.5;
	float grit = hash(floor(uv * vec2(96.0, 54.0) - vec2(TIME * 18.0, 0.0)));
	float flash = mix(noise, scan_band, 0.35);
	vec3 distress_tint = mix(tint.rgb, vec3(0.42, 0.62, 0.38), grit * 0.18);
	vec3 static_rgb = mix(scene.rgb, distress_tint * flash + vec3(noise * 0.85), intensity);
	static_rgb += (grit - 0.5) * intensity * 0.08;
	static_rgb = clamp(static_rgb, 0.0, 1.0);
	COLOR = vec4(static_rgb, intensity * 0.85);
}
