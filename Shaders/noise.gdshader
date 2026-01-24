shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable, filter_nearest;
uniform sampler2D color_ramp: filter_linear;
uniform float density: hint_range(0.0, 1.0) = 0.25;
uniform vec2 speed = vec2(0.02, 0.01);

void fragment() {
	vec2 uv = UV + speed * TIME;
	float noise = texture(noise_texture, uv).r;

	float fog = clamp(noise * 2.0 - 1.0, 0.0, 1.0);
	vec4 ramp_color = texture(color_ramp, vec2(noise, 0.0));
	COLOR = ramp_color;

	COLOR.a *= fog * density;
}