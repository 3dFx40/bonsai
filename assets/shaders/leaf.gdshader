shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float wind_strength = 0.006;
uniform float succulent = 0.0;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float sway = sin(TIME * 1.3 + world.x * 3.1 + world.z * 4.2);
    VERTEX.y += sway * wind_strength * UV.y * UV.y;
}
void fragment() {
    float midrib = 1.0 - smoothstep(0.006, 0.025, abs(UV.x - 0.5));
    float veins = 1.0 - smoothstep(0.012, 0.036, abs(sin((UV.y - abs(UV.x - 0.5) * 0.60) * 42.0)));
    float edge = smoothstep(0.15, 0.5, abs(UV.x - 0.5));
    ALBEDO = COLOR.rgb * (1.0 - edge * 0.12 + (midrib * 0.20 + veins * 0.07) * (1.0 - succulent * 0.8));
    ROUGHNESS = mix(0.48, 0.34, succulent);
    SPECULAR = 0.35;
}
