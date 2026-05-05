#version 450

layout(binding = 0, RGBA8) uniform image2D _TextureTex;
layout(binding = 1) buffer _ParametersBuffer
{
    float _Frequency;
    float _Lacunarity;
    float _Gain;
};

#define iResolution vec2(512.0, 512.0)

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),          hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main()
{
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = vec2(id) / iResolution;

    // Wood grain: rings along X, distorted by low-freq noise
    float distort = noise(uv * 3.0) * 0.4 + noise(uv * 7.0) * 0.15;
    float grain   = sin((uv.x + distort) * 38.0) * 0.5 + 0.5;
    float fine    = noise(uv * 96.0) * 0.12;

    // Plank lines
    float plankY  = fract(uv.y * 6.0);
    float seam    = 1.0 - smoothstep(0.0, 0.04, plankY) * smoothstep(1.0, 0.96, plankY);

    vec3 light = vec3(0.66, 0.44, 0.22);
    vec3 dark  = vec3(0.38, 0.22, 0.10);
    vec3 wood  = mix(dark, light, clamp(grain + fine, 0.0, 1.0));
    wood *= (1.0 - seam * 0.4);

    imageStore(_TextureTex, id, vec4(wood, 1.0));
}
