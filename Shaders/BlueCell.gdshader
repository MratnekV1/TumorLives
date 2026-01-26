shader_type canvas_item;

uniform sampler2D dissolve_texture : source_color;
uniform float dissolve_value : hint_range(0,1);
uniform float burn_size: hint_range(0.0, 1.0, 0.01);
uniform vec4 burn_color: source_color;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment(){
    vec4 main_texture = texture(TEXTURE, UV);
    vec4 noise_texture = texture(dissolve_texture, UV);

	float is_solid = step(alpha_threshold, main_texture.a);

	// This is needed to avoid keeping a small burn_color dot with dissolve being 0 or 1
	// is there another way to do it?
	float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
	float threshold = smoothstep(noise_texture.x - burn_size_step, noise_texture.x, dissolve_value);
    float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, dissolve_value);

	vec3 final_rgb = mix(burn_color.rgb, main_texture.rgb, border);

	COLOR.a = main_texture.a * threshold * is_solid;
	COLOR.rgb = final_rgb;
}