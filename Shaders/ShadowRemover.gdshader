shader_type canvas_item;

// Próg przezroczystości - co uznajemy za cień (np. 0.4)
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;
// Jak głęboko od góry szukać cienia (0.0 - 1.0)
uniform float cutoff_height : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    // Pobieramy kolor tekstury
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Tworzymy kopię koloru wejściowego (z modulate ze skryptu)
    vec4 final_color = COLOR;
    
    // Nadpisujemy kanał alfa tylko jeśli spełnione są warunki
    if (UV.y < cutoff_height) {
        if (tex_color.a < alpha_threshold) {
            final_color.a = 0.0;
        } else {
            // Zachowaj alfę tekstury pomnożoną przez modulate
            final_color.a = tex_color.a * COLOR.a;
        }
    } else {
        // Standardowe zachowanie dla reszty sprite'a
        final_color.a = tex_color.a * COLOR.a;
    }

    // Przypisujemy wynik - teraz kolor (RGB) pozostaje nietknięty
    COLOR = final_color;
}