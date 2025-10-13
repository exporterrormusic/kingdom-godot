shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.6;
uniform float softness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 centered = UV * 2.0 - vec2(1.0);
	float dist = length(centered);
	float edge = smoothstep(inner_radius, inner_radius + softness, dist);
	float alpha = clamp(edge * vignette_strength, 0.0, 1.0);
	COLOR = vec4(tint.rgb, tint.a * alpha);
}
