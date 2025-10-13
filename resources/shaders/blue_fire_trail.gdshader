shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 core_color : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.18, 0.55, 1.0, 0.65);
uniform vec4 outer_glow_color : source_color = vec4(0.3, 0.66, 1.0, 0.45);
uniform vec4 spark_color : source_color = vec4(1.0, 0.78, 0.52, 0.82);
uniform vec4 ember_color : source_color = vec4(0.96, 0.82, 0.54, 0.6);
uniform float time = 0.0;
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float distortion = 0.32;
uniform float flame_scale = 2.4;
uniform float max_radius = 64.0;
uniform float radius_multiplier : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float spark_density : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float damage_progress : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float fade_progress : hint_range(0.0, 1.0, 0.01) = 0.0;

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
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
    float shrink = clamp(radius_multiplier, 0.05, 1.0);
    float radius_norm = max(max_radius * shrink, 0.001);
    vec2 local = VERTEX.xy / radius_norm;
    float dist = length(local);
    float activity = clamp(1.0 - fade_progress, 0.0, 1.0);
    float heat = clamp(1.0 - damage_progress * 0.4, 0.3, 1.0);
    float falloff = smoothstep(1.1, 0.0, dist);
    vec2 flow_coords = local * flame_scale + vec2(time * 0.8, -time * 0.65);
    float noise_val = noise(flow_coords * 1.35);
    float swirl = sin(dist * 12.0 - time * 5.0) * 0.12;
    float wave = sin(local.x * 6.5 + time * 3.6) * 0.1;
    float flicker = sin(time * 7.0 + dot(local, vec2(5.2, 3.8))) * 0.08;
    float flame = clamp((falloff * heat) + swirl * 0.6 + wave * 0.45 + flicker + (noise_val - 0.5) * distortion + 0.1, 0.0, 1.0);
    float rim = smoothstep(0.0, 0.95, clamp(1.0 - dist, 0.0, 1.0));
    float mask = clamp(pow(flame, 1.05) * intensity * (0.7 + 0.3 * activity), 0.0, 1.0);

    vec2 ember_coords = local * (flame_scale * 0.75) + vec2(-time * 0.35, time * 0.22);
    float ember_noise = noise(ember_coords * 2.4);
    float ember_field = clamp((ember_noise - 0.45) * 2.2, 0.0, 1.0);
    ember_field *= smoothstep(1.05, 0.1, dist) * activity;

    vec2 spark_space = local * (flame_scale * 0.55) + vec2(time * 1.1, time * 1.7);
    vec2 spark_cell = floor(spark_space);
    float spark_seed = hash(spark_cell + vec2(23.17, 91.7));
    float spark_spawn = step(1.0 - clamp(spark_density, 0.0, 1.0), spark_seed);
    vec2 spark_offset = fract(spark_space) - vec2(0.5);
    float spark_shape = exp(-12.0 * dot(spark_offset, spark_offset));
    float spark_mask = spark_spawn * spark_shape * smoothstep(0.95, 0.0, dist) * activity;

    vec4 mid_color = mix(outer_glow_color, edge_color, clamp(flame, 0.0, 1.0));
    vec4 final_color = mix(mid_color, core_color, pow(rim, 1.5));
    vec4 ember_contrib = ember_color * ember_field;
    vec4 spark_contrib = spark_color * spark_mask;
    final_color.rgb = mix(final_color.rgb, ember_color.rgb, ember_field * 0.35);
    final_color += ember_contrib * 0.5 + spark_contrib;

    float alpha_scale = mask * clamp(radius_multiplier * 0.75 + 0.2, 0.0, 1.0) * (0.55 + 0.45 * activity);
    alpha_scale = clamp(alpha_scale + ember_contrib.a * 0.35 + spark_contrib.a * 0.6, 0.0, 1.0);
    final_color.a *= alpha_scale;
    COLOR = final_color;
}
