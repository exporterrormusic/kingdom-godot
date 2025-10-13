shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 glow_tint : source_color = vec4(1.0, 0.3, 0.23, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0, 0.01) = 1.6;
uniform float red_threshold : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float red_balance : hint_range(0.0, 1.0, 0.01) = 0.25;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec4 base_color = tex * COLOR;
    float dominant = max(0.0, base_color.r - max(base_color.g, base_color.b));
    float red_factor = smoothstep(red_threshold, 1.0, base_color.r);
    float intensity = clamp(red_factor * (dominant + red_balance), 0.0, 1.0) * base_color.a;
    vec3 emission = glow_tint.rgb * intensity * glow_strength;
    COLOR = vec4(base_color.rgb + emission, base_color.a);
}
