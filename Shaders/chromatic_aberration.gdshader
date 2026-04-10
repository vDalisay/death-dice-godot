shader_type canvas_item;
// Chromatic aberration / RGB split. Driven by a uniform intensity that
// RollPhase tweens from 0→peak→0 on bust / jackpot events.

uniform float intensity : hint_range(0.0, 0.05) = 0.0;
uniform float ambient_intensity : hint_range(0.0, 0.01) = 0.0;
uniform float ambient_drift : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float edge = smoothstep(0.08, 0.92, length(centered) * 1.6);
	float ambient_wave = 0.5 + 0.5 * sin(TIME * 0.22 + UV.y * 3.4 - UV.x * 1.8);
	float ambient = ambient_intensity * mix(0.55, 1.1, ambient_wave) * mix(0.4, 1.0, edge);
	float total_intensity = intensity + ambient;
	vec2 drift = vec2(
		sin(TIME * 0.19 + UV.y * 6.0),
		cos(TIME * 0.16 - UV.x * 4.8)
	) * ambient_drift * ambient_intensity * 0.5;
	vec2 dir = centered + drift;
	float r = texture(SCREEN_TEXTURE, SCREEN_UV + dir * total_intensity).r;
	float g = texture(SCREEN_TEXTURE, SCREEN_UV).g;
	float b = texture(SCREEN_TEXTURE, SCREEN_UV - dir * total_intensity).b;
	COLOR = vec4(r, g, b, 1.0);
}
