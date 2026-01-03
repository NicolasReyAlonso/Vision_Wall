shader_type spatial;
render_mode specular_disabled;

uniform int steps : hint_range(1, 8) = 3;
uniform vec3 base_color : source_color = vec3(1.0);
uniform sampler2D albedo_texture;

// Control de mezcla entre textura y color base (0 = solo color base, 100 = solo textura)
uniform float texture_influence : hint_range(0.0, 100.0) = 100.0;

// Control de saturación (0 = blanco y negro, 100 = saturación normal, >100 = sobresaturado)
uniform float saturation : hint_range(0.0, 200.0) = 100.0;

// Control de oscuridad de las sombras (0 = muy oscuras/negras, 100 = claras/suaves)
uniform float shadow_brightness : hint_range(0.0, 100.0) = 0.0;

// Función para ajustar la saturación
vec3 adjust_saturation(vec3 color, float sat) {
    // Calculamos la luminancia (escala de grises)
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Interpolamos entre el color gris y el color original
    return mix(vec3(luminance), color, sat);
}

void fragment() {
    // Obtenemos el color de la textura
    vec3 tex_color = texture(albedo_texture, UV).rgb;
    
    // Convertimos el slider de 0-100 a 0.0-1.0 para mix()
    float blend = texture_influence / 100.0;
    
    // Mezclamos: 0 = 100% base_color, 100 = 100% textura (SIN multiplicar por base_color)
    vec3 mixed_color = mix(base_color, tex_color, blend);
    
    // Aplicamos ajuste de saturación (convertimos de 0-200 a 0.0-2.0)
    vec3 saturated_color = adjust_saturation(mixed_color, saturation / 100.0);
    
    ALBEDO = saturated_color;
}

void light() {
    float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
    float stepped = floor(NdotL * float(steps)) / float(steps);
    
    // Convertimos shadow_brightness de 0-100 a 0.0-1.0
    float min_brightness = shadow_brightness / 100.0;
    
    // Remapeamos el valor stepped para que nunca baje del mínimo de brillo
    // stepped va de 0.0 a 1.0, lo remapeamos a min_brightness hasta 1.0
    float adjusted_light = mix(min_brightness, 1.0, stepped);
    
    DIFFUSE_LIGHT += adjusted_light * ATTENUATION * LIGHT_COLOR * ALBEDO;
}