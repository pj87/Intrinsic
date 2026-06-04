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

float fbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 6; i++)
    {
        v += a * noise(p);
        p *= 2.1;
        a *= 0.5;
    }
    return v;
}

void main()
{
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = vec2(id) / iResolution;

    float f = fbm(uv * 6.0 + fbm(uv * 3.0) * 2.5);
    float detail = noise(uv * 48.0) * 0.08;
    float crack = smoothstep(0.48, 0.5, abs(fract(uv.x * 8.0 + fbm(uv * 2.0)) - 0.5));

    vec3 light = vec3(0.62, 0.57, 0.50);
    vec3 dark  = vec3(0.30, 0.27, 0.22);
    vec3 stone = mix(dark, light, clamp(f + detail, 0.0, 1.0));
    stone *= (1.0 - crack * 0.35);

    imageStore(_TextureTex, id, vec4(stone, 1.0));
}
