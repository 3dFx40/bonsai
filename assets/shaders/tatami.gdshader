shader_type spatial;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    float weave = sin(local_position.x * 450.0) * 0.025
        + sin(local_position.z * 75.0) * 0.035;
    ALBEDO = vec3(0.58, 0.55, 0.39) * (1.0 + weave);
    ROUGHNESS = 0.95;
}
