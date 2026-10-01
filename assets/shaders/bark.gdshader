shader_type spatial;
render_mode diffuse_burley;
uniform vec4 bark_color : source_color = vec4(0.40, 0.34, 0.26, 1.0);
varying vec3 local_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { local_position = VERTEX; }
void fragment() {
    float grain = noise(vec2(UV.x * 70.0, UV.y * 9.0));
    float fissure = smoothstep(0.70, 0.91, grain);
    float mottling = noise(vec2(local_position.x + local_position.z, local_position.y) * 23.0);
    ALBEDO = bark_color.rgb * COLOR.rgb * (0.96 + (mottling - 0.5) * 0.15 - fissure * 0.17);
    ROUGHNESS = 0.92;
}
