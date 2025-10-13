shader_type canvas_item;

render_mode unshaded, blend_add;

uniform vec4 fill_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float edge_softness = 0.0;
uniform float intensity = 1.0;

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0);
	float dist = length(uv);
	float edge_start = clamp(1.0 - edge_softness, 0.0, 1.0);
	float edge = edge_softness <= 0.0 ? step(1.0, dist) : smoothstep(edge_start, 1.0, dist);
	float core = max(0.0, 1.0 - edge);
	float boosted_intensity = max(intensity, 1.0);
	float alpha = clamp(fill_color.a * core * boosted_intensity, 0.0, 1.0);
	vec3 rgb = fill_color.rgb * core * boosted_intensity;
	COLOR = vec4(rgb, alpha);
}
