shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.1, 0.1, 0.2, 0.4);
uniform float radius : hint_range(0.0, 2.0) = 0.8;
uniform float softness : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	// Distance from middle of the screen to the edge
	float dist = distance(UV, vec2(0.5));
	// Smooth fade
	float vignette = smoothstep(radius, radius - softness, dist);
	// Adding color with new alpha (transparency)
	COLOR = vec4(vignette_color.rgb, (1.0 - vignette) * vignette_color.a);
}