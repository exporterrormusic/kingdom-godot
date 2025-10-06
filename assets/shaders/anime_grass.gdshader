shader_type canvas_item;

render_mode blend_mix, unshaded;

uniform float world_scale : hint_range(0.001, 0.05, 0.001) = 0.012;
uniform float blade_density : hint_range(0.5, 5.0) = 1.8;
uniform float blade_width : hint_range(0.02, 0.4) = 0.18;
uniform float layer_count : hint_range(4.0, 36.0) = 18.0;
uniform float sway_speed : hint_range(0.2, 4.0) = 1.25;
uniform float sway_amplitude : hint_range(0.0, 24.0) = 11.0;
uniform float flicker_strength : hint_range(0.0, 0.8) = 0.25;
uniform vec4 sky_color : source_color = vec4(0.08, 0.12, 0.18, 1.0);
uniform vec4 grass_light : source_color = vec4(0.42, 0.82, 0.52, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.12, 0.34, 0.18, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 452.12));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float triangular(float x) {
	return abs(fract(x) - 0.5) * 2.0;
}

void fragment() {
	vec2 world_uv = WORLD_POSITION.xy * world_scale;
	vec2 cell = floor(world_uv);
	vec2 local_uv = fract(world_uv);

	float height_gradient = smoothstep(0.0, 1.0, local_uv.y);
	vec3 base_color = mix(grass_dark.rgb, grass_light.rgb, height_gradient);

	float layer_accum = 0.0;
	float layer_weight = 0.0;

	for (float i = 0.0; i < layer_count; i += 1.0) {
		float layer = i / layer_count;
		float parallax = mix(0.25, 1.0, layer);
		float density = blade_density * mix(1.0, 1.8, layer);
		vec2 layer_uv = vec2(world_uv.x * density, local_uv.y + layer * 0.35);
		float sway = sin(TIME * sway_speed * mix(0.6, 1.2, layer) + world_uv.x * 2.2 + layer * 19.8);
		float sway_offset = sway * sway_amplitude * (1.0 - layer);
		layer_uv.x += sway_offset * 0.01;

		float blade_line = triangular(layer_uv.x);
		float blade = smoothstep(blade_width, blade_width * 0.2, blade_line);

		vec2 noise_sample = cell + vec2(layer * 17.0, i * 11.3);
		float noise_factor = hash(noise_sample);
		float flicker = sin(TIME * (1.8 + noise_factor * 1.7) + layer * 5.2);
		blade *= 0.7 + flicker * flicker_strength;

		layer_accum += blade * parallax;
		layer_weight += parallax;
	}

	float blade_mix = 0.0;
	if (layer_weight > 0.0) {
		blade_mix = clamp(layer_accum / layer_weight, 0.0, 1.5);
	}

	vec3 grass_color = mix(base_color, grass_light.rgb, clamp(blade_mix, 0.0, 1.0));

	float sky_blend = smoothstep(0.0, 0.1, local_uv.y);
	vec3 final_color = mix(sky_color.rgb, grass_color, sky_blend);

	COLOR = vec4(final_color, 1.0);
}
