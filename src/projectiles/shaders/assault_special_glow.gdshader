shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float glow_intensity : hint_range(0.0, 1.5) = 0.8;
uniform float glow_size : hint_range(0.0, 0.05) = 0.008;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Sample neighboring pixels for glow effect
	vec4 glow_sample = vec4(0.0);
	float samples = 0.0;
	
	// Sample in a small radius around the current pixel
	for(float x = -glow_size; x <= glow_size; x += glow_size * 0.5) {
		for(float y = -glow_size; y <= glow_size; y += glow_size * 0.5) {
			vec2 offset = vec2(x, y);
			vec4 sample_color = texture(TEXTURE, UV + offset);
			glow_sample += sample_color;
			samples += 1.0;
		}
	}
	
	glow_sample /= samples;
	
	// Create glow based on texture alpha
	float glow_alpha = glow_sample.a * glow_intensity;
	vec3 glow_rgb = glow_color.rgb * glow_alpha;
	
	// Combine original texture with glow
	vec3 final_rgb = tex_color.rgb + glow_rgb;
	float final_alpha = max(tex_color.a, glow_alpha * 0.3);
	
	COLOR = vec4(final_rgb, final_alpha);
}