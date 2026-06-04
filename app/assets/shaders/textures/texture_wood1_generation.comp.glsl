// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// See http://www.iquilezles.org/www/articles/warp/warp.htm for details

// https://www.shadertoy.com/view/4tyGzz

#version 450

layout(binding = 0, RGBA8) uniform image2D _TextureTex;
layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

#define iTime 1.0
#define iResolution vec2(2048.0, 2048)

// Created by genis sole - 2017
// License Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International.

// Noise
vec2 random(vec2 st)
{
    st = vec2( dot(st,vec2(127.1,311.7)),
              dot(st,vec2(269.5,183.3)) );
    return -1.0 + 2.0*fract(sin(st)*43758.5453123);
}

float noise(vec2 st)
{
    vec2 f = fract(st);
    vec2 i = floor(st);
    
    vec2 u = f * f * f * (f * (f * 6. - 15.) + 10.);
    
    float r = mix( mix( dot( random(i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ),
                     dot( random(i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
                mix( dot( random(i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ),
                     dot( random(i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
    return r * .5 + .5;
}


float fbm(vec2 st)
{
    float value = 0.;
    float amplitude = .5;
    float frequency = 0.;
    
    for (int i = 0; i < 8; i++)
    {
        value += amplitude * noise(st);
        st *= 2.;
        amplitude *= .5;
    }
    
    return value;
}

vec3 textureWood(vec2 uv)
{
    uv.x *= .6;
    
    float no = noise(vec2(1.2, 2.4) + uv * 6.);

    float n0 = .6 + .4 * smoothstep(
        .24,
        0.55,
        fbm(vec2(uv.x * 10., uv.y * 30.) + vec2(15.0, 10.0)));
    uv += no;
    float n1 = fbm(vec2(uv.x * 5., uv.y * 20.) + vec2(2.0, 2.0));
    float n2 = smoothstep(
        1.0,
        0.3,
        fbm(vec2(uv.x * 1., uv.y * 10.)));
    
    vec3 col = n0 * n1 * n2 * vec3(1.92, 1.4, 1.15);
    return pow(col, vec3(2.1));
}

vec3 textureWall(vec2 uv)
{
    vec2 iuv = floor(uv * 10.0);
    vec3 col = clamp(smoothstep(0.14, 0.65, noise(uv * 10.4) * fbm(uv * 18.0)) + .9, 0.0, 1.0) * vec3(0.5);
    return col;
}

vec3 textureFloor(vec2 uv)
{
    vec2 iuv = floor(uv * 10.0);
    float v = float(mod(iuv.x + iuv.y, 2.0) <= 0.01);
    vec3 col = vec3(0.4 + 0.5 * v) * fbm(uv * 15.5) * vec3(0.75, 0.68, 0.591);
    return col;
}

void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID);
	vec2 uv = gl_GlobalInvocationID.xy / iResolution.xy;
	
	uv *= 5.5;
	
	//vec3 fragColor = textureFloor(uv);
    vec3 fragColor = textureWood(uv);
	//vec3 fragColor = textureWall(uv);

	imageStore(_TextureTex, id.xy, vec4(fragColor, 1.0));
}
