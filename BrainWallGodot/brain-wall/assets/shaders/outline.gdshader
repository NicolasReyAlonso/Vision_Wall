shader_type spatial;
render_mode cull_front, unshaded;

uniform float outline_width = 0.03;
uniform vec4 outline_color : source_color = vec4(0, 0, 0, 1);

void vertex() {
    // Expande la malla hacia afuera según la normal
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}