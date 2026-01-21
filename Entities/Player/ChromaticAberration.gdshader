shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float offset : hint_range(0.0, 5.0) = 1.5; // Strenght of effect

void fragment() {
    vec2 shift = vec2(offset) * SCREEN_PIXEL_SIZE;
    
    float r = texture(screen_texture, SCREEN_UV + shift).r;
    float g = texture(screen_texture, SCREEN_UV).g;
    float b = texture(screen_texture, SCREEN_UV - shift).b;
    
    COLOR = vec4(r, g, b, 1.0);
}