shader_type spatial;
render_mode specular_disabled; // desactiva el especular por defecto (puedes cambiarlo)

uniform int steps : hint_range(1, 8) = 3;
uniform vec3 base_color : source_color = vec3(1.0);

void fragment() {
    // Color base del material (albedo)
    ALBEDO = base_color;
    // Nota: no intentamos leer variables LIGHT aquí — la iluminación se hace en light()
}

// La función light() se llama por cada luz que afecta el fragmento.
// Usa los built-ins LIGHT (vector hacia la luz), LIGHT_COLOR y ATTENUATION.
void light() {
    // N dot L: normal · dirección hacia la luz (LIGHT apunta hacia la luz)
    float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);

    // Escalonamos para obtener el efecto cel (posterize)
    float stepped = floor(NdotL * float(steps)) / float(steps);

    // Añadimos la contribución difusa multiplicando por ATTENUATION y el color de la luz
    // También multiplicamos por ALBEDO para respetar el color del material
    DIFFUSE_LIGHT += stepped * ATTENUATION * LIGHT_COLOR * ALBEDO;
}
