shader_type canvas_item;
// Subtle CRT-style barrel distortion pass.

uniform float strength : hint_range(0.0, 0.08) = 0.02;
uniform float edge_fade : hint_range(0.0, 0.3) = 0.06;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float radius2 = dot(centered, centered);
	vec2 distorted = centered * (1.0 + strength * radius2);
	vec2 sample_uv = distorted * 0.5 + 0.5;

	vec4 scene = textureLod(SCREEN_TEXTURE, sample_uv, 0.0);
	float edge = smoothstep(1.0, 1.0 - edge_fade, max(abs(centered.x), abs(centered.y)));
	COLOR = vec4(scene.rgb * edge, scene.a);
}
