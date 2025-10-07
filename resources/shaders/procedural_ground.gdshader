shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.24, 0.33, 0.26, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.16, 0.22, 0.18, 1.0);
uniform vec4 accent_color : source_color = vec4(0.48, 0.56, 0.46, 1.0);
uniform float noise_scale = 6.0;
uniform float detail_strength = 0.35;
uniform float wave_strength = 0.18;
uniform float wave_speed = 0.6;
uniform float patchwork_strength = 0.4;
uniform float color_variation = 0.25;
uniform float wind_strength = 0.4;
uniform float time_flow = 0.0;
uniform float snow_cover = 0.0;
uniform float snow_brightness = 1.0;
uniform vec3 snow_tint_color = vec3(0.86, 0.92, 1.0);
uniform float snow_tint_strength = 0.08;
uniform float snow_shadow_strength = 0.18;
uniform float snow_drift_scale = 0.6;
uniform float snow_crust_strength = 0.3;
uniform float snow_ice_highlight = 0.22;
uniform float snow_sparkle_intensity = 0.2;
uniform sampler2D snow_imprint_texture : source_color;
uniform vec2 snow_imprint_texel_size = vec2(0.0, 0.0);
uniform float snow_imprint_strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float result = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < 4; i++) {
		result += amplitude * noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	return result;
}

void fragment() {
	vec2 coords = UV * noise_scale;
	float base_noise = fbm(coords + vec2(0.0, time_flow * wave_speed));
	float detail_noise = noise(coords * 2.0 + vec2(time_flow * wind_strength));
	float patch_noise = noise(coords * 0.5 + vec2(time_flow * 0.25));

	float blend = mix(base_noise, detail_noise, detail_strength);
	blend = mix(blend, patch_noise, patchwork_strength);

	vec4 layer_color = mix(base_color, secondary_color, blend);
	float accent_mask = smoothstep(0.55, 0.8, blend + detail_noise * 0.5);
	layer_color = mix(layer_color, accent_color, accent_mask * color_variation);

	float subtle_wave = sin((UV.x + UV.y + time_flow * wave_speed) * 6.283) * wave_strength;
	layer_color.rgb += subtle_wave * 0.06;

	vec3 ground_color = layer_color.rgb;
	vec3 final_color = ground_color;

	float cover = clamp(snow_cover, 0.0, 1.0);
	if (cover > 0.001) {
		float drift_scale = max(snow_drift_scale, 0.01);
		float drift_noise = fbm(coords * drift_scale + vec2(time_flow * wind_strength * 0.12, 0.0));
		float drift_mask = smoothstep(0.2, 0.85, drift_noise);
		float crust_mask = smoothstep(0.65, 0.95, drift_noise);
		vec3 snow_color = snow_tint_color * snow_brightness;
		snow_color = mix(snow_color, snow_color + vec3(0.12, 0.16, 0.22) * snow_tint_strength, crust_mask);
		float shade = (drift_noise - 0.5) * snow_shadow_strength;
		snow_color -= shade;
		snow_color = clamp(snow_color, 0.0, 1.2);

		float imprint_sample = 0.5;
		if (snow_imprint_strength > 0.0 && snow_imprint_texel_size.x > 0.0 && snow_imprint_texel_size.y > 0.0) {
			vec2 texel = snow_imprint_texel_size;
			float center = texture(snow_imprint_texture, UV).r;
			float right = texture(snow_imprint_texture, UV + vec2(texel.x, 0.0)).r;
			float left = texture(snow_imprint_texture, UV - vec2(texel.x, 0.0)).r;
			float up = texture(snow_imprint_texture, UV + vec2(0.0, texel.y)).r;
			float down = texture(snow_imprint_texture, UV - vec2(0.0, texel.y)).r;
			float diag1 = texture(snow_imprint_texture, UV + vec2(texel.x, texel.y)).r;
			float diag2 = texture(snow_imprint_texture, UV + vec2(-texel.x, texel.y)).r;
			float diag3 = texture(snow_imprint_texture, UV + vec2(texel.x, -texel.y)).r;
			float diag4 = texture(snow_imprint_texture, UV + vec2(-texel.x, -texel.y)).r;
			imprint_sample = (center * 4.0 + (right + left + up + down) * 2.0 + (diag1 + diag2 + diag3 + diag4)) / 16.0;
		}
		float imprint_bias = (imprint_sample - 0.5) * snow_imprint_strength;
		float accumulation = max(imprint_bias, 0.0);
		float removal = max(-imprint_bias, 0.0);
		float cover_multiplier = clamp(1.0 + accumulation * 1.8 - removal * 2.6, 0.0, 2.2);
		float cover_amount = clamp(cover * drift_mask * cover_multiplier, 0.0, 1.0);

		snow_color += vec3(0.22, 0.27, 0.34) * accumulation * snow_ice_highlight;
		snow_color -= vec3(0.18, 0.15, 0.12) * removal;
		vec3 carved_ground = ground_color - vec3(0.18, 0.16, 0.11) * removal;
		carved_ground = clamp(carved_ground, 0.0, 1.0);
		final_color = mix(carved_ground, snow_color, cover_amount);

		if (snow_imprint_texel_size.x > 0.0 && snow_imprint_texel_size.y > 0.0) {
			vec2 grad = vec2(
				texture(snow_imprint_texture, UV + vec2(snow_imprint_texel_size.x, 0.0)).r - imprint_sample,
				texture(snow_imprint_texture, UV + vec2(0.0, snow_imprint_texel_size.y)).r - imprint_sample
			);
			float ridge = clamp(length(grad) * 6.0, 0.0, 1.0);
			final_color += vec3(0.1, 0.14, 0.19) * accumulation * ridge;
			final_color -= vec3(0.18, 0.15, 0.12) * removal * ridge;
		}

		float ice_mask = smoothstep(0.78, 0.98, drift_noise);
		final_color += vec3(0.25, 0.28, 0.35) * ice_mask * snow_ice_highlight * cover_amount;
		float sparkle_noise = noise(coords * 14.0 + vec2(time_flow * (0.6 + wind_strength * 0.4)));
		float sparkle = pow(max(0.0, sparkle_noise), 12.0) * snow_sparkle_intensity * cover_amount;
		final_color += vec3(sparkle);
	}

	COLOR = vec4(final_color, layer_color.a);
}
