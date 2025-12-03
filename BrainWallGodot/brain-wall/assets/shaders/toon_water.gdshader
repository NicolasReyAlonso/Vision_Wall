shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform vec4 albedo : source_color = vec4(0.0, 0.204, 0.961, 0.6);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

uniform float toon_steps : hint_range(1, 8) = 3;      // Cantidad de bandas de luz
uniform float toon_specular_steps : hint_range(1, 8) = 2; // Brillos toony
uniform float rim_strength : hint_range(0.0, 3.0) = 1.0;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.5;

uniform float saturation_boost : hint_range(0.0, 2.0) = 1.2;

uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);
uniform float uv1_blend_sharpness = 1.0;

// ---------------------------------------

varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;

// Triplanar normal
void vertex() {
    vec3 normal = NORMAL;

    TANGENT = normalize(
        vec3(0.0, 0.0, -1.0) * abs(normal.x) +
        vec3(1.0, 0.0,  0.0) * abs(normal.y) +
        vec3(1.0, 0.0,  0.0) * abs(normal.z)
    );

    BINORMAL = normalize(
        vec3(0.0, 1.0,  0.0) * abs(normal.x) +
        vec3(0.0, 0.0, -1.0) * abs(normal.y) +
        vec3(0.0, 1.0,  0.0) * abs(normal.z)
    );

    uv1_power_normal = pow(abs(NORMAL), vec3(uv1_blend_sharpness));
    uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));

    uv1_triplanar_pos = VERTEX * uv1_scale + uv1_offset + vec3(TIME * 0.1);
    uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

// Triplanar
vec4 triplanar_texture(sampler2D tex, vec3 weights, vec3 pos) {
    vec4 s = vec4(0.0);
    s += texture(tex, pos.xy) * weights.z;
    s += texture(tex, pos.xz) * weights.y;
    s += texture(tex, pos.zy * vec2(-1.0, 1.0)) * weights.x;
    return s;
}

// ---------------------------------------

void fragment() {
    // Triplanar albedo
    vec4 tex_col = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos);

    // Color base
    vec3 color = albedo.rgb * tex_col.rgb;

    // Boost de saturación cartoon
    color = mix(vec3(dot(color, vec3(0.3, 0.59, 0.11))), color, saturation_boost);

    ALBEDO = color;

    ALPHA = albedo.a * tex_col.a;

    // Normales
    vec3 nrm = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos).rgb;
    NORMAL_MAP = nrm;
    NORMAL_MAP_DEPTH = normal_scale;
}

// ---------------------------------------
// Iluminación Toon
// ---------------------------------------

void light() {
    // Luz básica toon (por bandas)
    float NdL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
    float toon_light = floor(NdL * toon_steps) / toon_steps;

    // Specular Toon
 	vec3 H = normalize(LIGHT + VIEW); // half-vector manual
	float NdH = clamp(dot(NORMAL, H), 0.0, 1.0);

    float toon_spec = floor(pow(NdH, 32.0) * toon_specular_steps) / toon_specular_steps;

    // Rim-light estilo caricatura
    float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
    rim = smoothstep(rim_threshold, 1.0, rim) * rim_strength;

    // Mezcla final
    DIFFUSE_LIGHT += toon_light * LIGHT_COLOR * ATTENUATION * ALBEDO;
    SPECULAR_LIGHT += toon_spec * LIGHT_COLOR * ATTENUATION;
    DIFFUSE_LIGHT += rim * ALBEDO * 0.5;
}
