shader_type spatial;
uniform vec4 wood_color : source_color = vec4(0.28, 0.19, 0.12, 1.0);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    vec3 p = local_position;
    float wave = p.z * 115.0 + sin(p.x * 2.8 + p.z * 13.0) * 3.0;
    float grain = sin(wave) * 0.025 + sin(wave * 0.37) * 0.035;
    ALBEDO = wood_color.rgb * (1.0 + grain);
    ROUGHNESS = 0.64 + grain * 0.6;
}
