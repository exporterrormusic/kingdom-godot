shader_type canvas_item;

uniform float time_flow = 0.0;
uniform float density = 0.6;
uniform vec2 wind_direction = vec2(0.35, -0.55);
uniform float petal_scale = 1.0;
uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform float world_scale = 0.0021;
uniform vec4 primary_color : source_color = vec4(1.0, 0.78, 0.88, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.62, 0.8, 1.0);
uniform float twinkle_strength = 0.35;
uniform float drift_amplitude = 0.55;

const float TAU = 6.283185307179586;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p + 19.19), hash(p + 73.31));
}

mat2 rotation(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(c, -s, s, c);
}

float petal_mask(vec2 p, float aspect, float radius, float softness) {
	vec2 q = vec2(p.x, p.y * aspect);
	float dist = length(q);
	float edge = smoothstep(radius + softness, radius, dist);
	return edge;
}

vec4 petal_layer(vec2 uv, float scale, float seed, float radius, float softness, float weight) {
	vec2 grid = (uv + vec2(seed * 11.0, seed * 19.0)) * scale;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	vec2 random_offset = hash2(cell + seed * 1.37);
	float angle = random_offset.x * TAU;
	float aspect = mix(0.55, 0.82, random_offset.y);
	vec2 center = random_offset;
	float swirl = sin(time_flow * 0.65 + dot(cell, vec2(0.27, 0.19))) * drift_amplitude;
	vec2 drift = vec2(
		sin(time_flow * 0.42 + random_offset.x * 9.31),
		cos(time_flow * 0.36 + random_offset.y * 7.13)
	) * (0.18 + swirl * 0.12);
	center += drift;
	vec2 petal_pos = rotation(angle) * (local - center);
	petal_pos.x += sin(time_flow * 0.18 + cell.y * 0.75 + seed * 2.1) * 0.08;
	petal_pos.y += cos(time_flow * 0.16 + cell.x * 0.53 + seed * 1.7) * 0.06;
	float mask = petal_mask(petal_pos, aspect, radius, softness);
	if (mask <= 0.0) {
		return vec4(0.0);
	}
	float twinkle = 1.0 + twinkle_strength * (sin(time_flow * (0.8 + random_offset.x * 2.6) + random_offset.y * 11.2) * 0.5 + 0.5);
	float highlight = smoothstep(0.0, 0.8, mask) * twinkle;
	vec3 tint = mix(primary_color.rgb, secondary_color.rgb, random_offset.x * 0.7);
	vec3 color = mix(tint, vec3(1.0), clamp(random_offset.y * 0.35 + 0.2, 0.0, 0.6));
	float alpha = mask * weight;
	return vec4(color * highlight * alpha, alpha);
}

void fragment() {
	vec2 camera_world = world_offset + SCREEN_UV * view_size;
	float scale_factor = max(petal_scale, 0.001);
	vec2 uv = camera_world * (world_scale / scale_factor);
	vec2 dir = normalize(vec2(wind_direction.x, clamp(wind_direction.y, -1.0, 1.0)));
	vec2 flow = dir * time_flow * 0.24;

	vec4 layer_far = petal_layer(uv + flow * 0.35, 6.5, 17.31, 0.25, 0.1, 0.32);
	vec4 layer_mid = petal_layer(uv + flow * 0.6, 10.0, 43.9, 0.22, 0.085, 0.52);
	vec4 layer_near = petal_layer(uv + flow, 16.5, 81.77, 0.2, 0.07, 0.9);

	vec4 combined = layer_far + layer_mid + layer_near;
	float coverage = clamp(combined.a, 0.0, 1.0);
	float alpha = clamp(coverage * density, 0.0, 0.24);
	vec3 color = vec3(0.0);
	if (combined.a > 0.0001) {
		color = combined.rgb / combined.a;
	}
	vec3 highlight = mix(color, vec3(1.0), 0.02);
	float petal_alpha = clamp(primary_color.a, 0.0, 0.6);
	COLOR = vec4(highlight, alpha * petal_alpha);
}
