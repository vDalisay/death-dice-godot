shader_type canvas_item;
render_mode unshaded;
// Luminance-preserving CRT shader with phosphor mask patterns and screen warp.
// Adapted from: https://godotshaders.com/shader/crt-with-luminance-preservation-no-scanlines/

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform int mask_type : hint_enum("Dots:1", "Aperture Grille:2", "Wide Grille:3", "Wide Soft Grille:4", "Slot Mask:5", "Null:0") = 5;
uniform float curve : hint_range(0.0, 0.5) = 0.08;
uniform float color_offset : hint_range(-0.5, 0.5) = 0.0025;
uniform float mask_brightness : hint_range(0.0, 1.0) = 0.94;
uniform float aspect : hint_range(0.5, 1.0) = 0.5625;
uniform float blend_strength : hint_range(0.0, 1.0) = 1.0;

vec2 warp(vec2 uv, float uv_aspect, float uv_curve) {
	uv -= 0.5;
	uv.x /= uv_aspect;
	float warping = dot(uv, uv) * uv_curve;
	warping -= uv_curve * 0.25;
	uv /= 1.0 - warping;
	uv.x *= uv_aspect;
	uv += 0.5;
	return uv;
}

vec3 linear_to_srgb(vec3 col) {
	return mix(
		(pow(col, vec3(1.0 / 2.4)) * 1.055) - 0.055,
		col * 12.92,
		lessThan(col, vec3(0.0031308))
	);
}

vec3 srgb_to_linear(vec3 col) {
	return mix(
		pow((col + 0.055) / 1.055, vec3(2.4)),
		col / 12.92,
		lessThan(col, vec3(0.04045))
	);
}

vec3 fetch_linear(ivec2 coords, ivec2 tex_size) {
	ivec2 safe_coords = clamp(coords, ivec2(0), tex_size - ivec2(1));
	return srgb_to_linear(texelFetch(SCREEN_TEXTURE, safe_coords, 0).rgb);
}

vec3 sample_crt(vec2 uv) {
	ivec2 tex_size = textureSize(SCREEN_TEXTURE, 0);
	vec2 tex_uv = uv * vec2(tex_size);
	int upper_y = int(tex_uv.y + 0.5) - 1;
	float center_x = floor(tex_uv.x);
	float left_x = center_x - 1.0;
	float right_x = center_x + 1.0;

	vec3 upper_a = fetch_linear(ivec2(int(left_x), upper_y), tex_size);
	vec3 upper_b = fetch_linear(ivec2(int(center_x), upper_y), tex_size);
	vec3 upper_c = fetch_linear(ivec2(int(right_x), upper_y), tex_size);
	vec3 lower_a = fetch_linear(ivec2(int(left_x), upper_y + 1), tex_size);
	vec3 lower_b = fetch_linear(ivec2(int(center_x), upper_y + 1), tex_size);
	vec3 lower_c = fetch_linear(ivec2(int(right_x), upper_y + 1), tex_size);

	vec3 beam = vec3(tex_uv.x - 0.5);
	beam.r -= color_offset;
	beam.b += color_offset;

	vec3 weight_a = smoothstep(vec3(1.0), vec3(0.0), beam - vec3(left_x));
	vec3 weight_b = smoothstep(vec3(1.0), vec3(0.0), abs(beam - vec3(center_x)));
	vec3 weight_c = smoothstep(vec3(1.0), vec3(0.0), vec3(right_x) - beam);

	vec3 upper_col = upper_a * weight_a + upper_b * weight_b + upper_c * weight_c;
	vec3 lower_col = lower_a * weight_a + lower_b * weight_b + lower_c * weight_c;

	float sawtooth = (tex_uv.y + 0.5) - float(upper_y + 1);
	sawtooth = smoothstep(0.0, 1.0, sawtooth);
	return mix(upper_col, lower_col, sawtooth);
}

vec4 generate_mask(vec2 fragcoord) {
	switch (mask_type) {
		case 1:
			{
				const vec3 pattern[4] = vec3[](vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0));
				ivec2 icoords = ivec2(fragcoord);
				return vec4(pattern[(icoords.y * 2 + icoords.x) % 4], 0.25);
			}
		case 2:
			{
				const vec3 pattern[2] = vec3[](vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 1.0));
				return vec4(pattern[int(fragcoord.x) % 2], 0.5);
			}
		case 3:
			{
				const vec3 pattern[4] = vec3[](vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0));
				return vec4(pattern[int(fragcoord.x) % 4], 0.25);
			}
		case 4:
			{
				const vec3 pattern[4] = vec3[](vec3(1.0, 0.125, 0.0), vec3(0.125, 1.0, 0.125), vec3(0.0, 0.125, 1.0), vec3(0.125, 0.0, 0.125));
				return vec4(pattern[int(fragcoord.x) % 4], 0.3125);
			}
		case 5:
			{
				const vec3 pattern[16] = vec3[](
					vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0),
					vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0),
					vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0),
					vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0)
				);
				ivec2 icoords = ivec2(fragcoord) % 4;
				return vec4(pattern[icoords.y * 4 + icoords.x], 0.375);
			}
		default:
			return vec4(vec3(1.0), 1.0);
	}
}

vec3 apply_mask(vec3 linear_color, vec2 fragcoord) {
	vec4 mask = generate_mask(fragcoord);
	linear_color *= mix(mask.w, 1.0, mask_brightness);
	vec3 target_color = linear_color / max(mask.w, 0.0001);
	vec3 primary_col = clamp(target_color, 0.0, 1.0);
	vec3 secondary = target_color - primary_col;
	secondary /= max(1.0 / max(mask.w, 0.0001) - 1.0, 0.0001);
	primary_col *= mask.rgb;
	primary_col += secondary * (1.0 - mask.rgb);
	return primary_col;
}

void fragment() {
	vec2 warped_uv = warp(SCREEN_UV, aspect, curve);
	vec3 source = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	bool outside = warped_uv.x < 0.0 || warped_uv.x > 1.0 || warped_uv.y < 0.0 || warped_uv.y > 1.0;
	if (outside) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = sample_crt(warped_uv);
		col = apply_mask(col, FRAGCOORD.xy);
		col = linear_to_srgb(col);
		COLOR = vec4(mix(source, col, blend_strength), 1.0);
	}
}
