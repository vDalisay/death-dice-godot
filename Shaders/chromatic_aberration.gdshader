shader_type canvas_item;
// Chromatic aberration / RGB split. Driven by a uniform intensity that
// RollPhase tweens from 0→peak→0 on bust / jackpot events.

uniform float intensity : hint_range(0.0, 0.05) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 dir = UV - vec2(0.5);
	float r = texture(SCREEN_TEXTURE, SCREEN_UV + dir * intensity).r;
	float g = texture(SCREEN_TEXTURE, SCREEN_UV).g;
	float b = texture(SCREEN_TEXTURE, SCREEN_UV - dir * intensity).b;
	COLOR = vec4(r, g, b, 1.0);
}
