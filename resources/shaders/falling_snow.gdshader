shader_type canvas_item;

uniform float time_flow = 0.0;
uniform float density = 0.6;
uniform vec2 wind_direction = vec2(0.35, -1.0);
uniform float flake_scale = 1.0;
uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform float world_scale = 0.0025;
uniform float twinkle_strength = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


float snow_layer(vec2 uv, float scale, float seed, float radius, float softness, float swirl_strength, float twinkle_speed) {
	vec2 grid = (uv + vec2(seed * 17.0, seed * 31.0)) * scale;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	vec2 random_offset = vec2(hash(cell + seed), hash(cell + seed + 19.1));
	float sparkle_phase = time_flow * twinkle_speed + random_offset.x * 11.3 + random_offset.y * 7.9;
	float sparkle = 1.0 + twinkle_strength * (sin(sparkle_phase) * 0.5 + 0.5);
	vec2 swirl = vec2(
		sin(time_flow * 0.55 + random_offset.x * 6.283) * swirl_strength,
		cos(time_flow * 0.7 + random_offset.y * 6.283) * swirl_strength
	);
	vec2 flake = clamp(random_offset + swirl * 0.6, 0.0, 1.0);
	vec2 diff = local - flake;
	float dist = length(diff);
	float base = smoothstep(radius + softness, radius, dist);
	return base * sparkle;
}

void fragment() {
	vec2 camera_world = world_offset + SCREEN_UV * view_size;
	vec2 uv = camera_world * (world_scale / max(flake_scale, 0.001));
	vec2 dir = normalize(vec2(wind_direction.x, clamp(wind_direction.y, -1.0, 1.0)));
	float base_speed = 0.35;
	vec2 flow_step = dir * time_flow * base_speed;
	float layer1 = snow_layer(uv + flow_step * 1.3, 16.0, 13.37, 0.12, 0.06, 0.024, 0.85);
	float layer2 = snow_layer(uv + flow_step * 1.0, 10.0, 37.91, 0.084, 0.042, 0.018, 0.6);
	float layer3 = snow_layer(uv + flow_step * 0.8, 6.0, 71.25, 0.056, 0.03, 0.012, 0.45);
	float near_weight = 0.82;
	float mid_weight = 0.58;
	float far_weight = 0.38;
	float combined = layer1 * near_weight + layer2 * mid_weight + layer3 * far_weight;
	float alpha = clamp(combined * density, 0.0, 0.8);
	vec3 tint = vec3(0.92, 0.96, 1.0);
	vec3 color = tint * combined * 0.6;
	COLOR = vec4(clamp(color, 0.0, 1.0), alpha);
}
