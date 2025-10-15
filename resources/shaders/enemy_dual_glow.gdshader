shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 core_tint : source_color = vec4(1.0, 0.42, 0.26, 1.0);
uniform vec4 rim_tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0, 0.01) = 1.2;
uniform float rim_strength : hint_range(0.0, 4.0, 0.01) = 0.9;
uniform float luma_bias : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float rim_softness : hint_range(0.05, 0.6, 0.01) = 0.24;
uniform float pulse_speed : hint_range(0.0, 12.0, 0.01) = 2.8;
uniform float pulse_amplitude : hint_range(0.0, 1.0, 0.01) = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 base_color = tex * COLOR;
	float alpha = base_color.a;
	if (alpha <= 0.001) {
		COLOR = base_color;
	} else {
		float luminance = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));
		float max_c = max(base_color.r, max(base_color.g, base_color.b));
		float min_c = min(base_color.r, min(base_color.g, base_color.b));
		float saturation = max_c - min_c;
		float energy = mix(luminance, saturation, luma_bias) * glow_strength;
		float rim_mask = smoothstep(0.0, rim_softness, 1.0 - tex.a);
		float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amplitude;

		vec3 emission_core = core_tint.rgb * energy * pulse;
		vec3 emission_rim = rim_tint.rgb * rim_mask * rim_strength * pulse;
		vec3 final_rgb = base_color.rgb + (emission_core + emission_rim) * alpha;

		COLOR = vec4(final_rgb, alpha);
	}
}
