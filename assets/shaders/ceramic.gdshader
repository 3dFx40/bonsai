shader_type spatial;
uniform vec4 glaze_color : source_color = vec4(0.20, 0.29, 0.26, 1.0);
uniform float matte = 0.0;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    vec3 p = local_position;
    float speckle = sin(p.x * 337.0) * sin(p.y * 297.0) * sin(p.z * 311.0);
    float wash = sin(p.x * 9.0 + p.z * 7.0 + sin(p.y * 23.0)) * 0.035;
    ALBEDO = glaze_color.rgb * (0.96 + wash + speckle * mix(0.025, 0.08, matte));
    ROUGHNESS = mix(0.26, 0.88, matte) + speckle * 0.025;
    SPECULAR = mix(0.65, 0.18, matte);
}
