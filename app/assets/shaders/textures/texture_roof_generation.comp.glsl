// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// See http://www.iquilezles.org/www/articles/warp/warp.htm for details

// https://www.shadertoy.com/view/MslXz8

#version 450

#define iTime 1.0
#define iResolution vec2(2048.0, 2048.0)
//#define iResolution vec2(4096.0, 4096)

layout(binding = 0, RGBA8) uniform image2D _TextureTex;
layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

// https://www.shadertoy.com/view/Mds3W7
// Lightning shader
// rand,noise,fmb functions from https://www.shadertoy.com/view/Xsl3zN
// jerome

float rand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

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

float fan(vec2 uv)
{
    uv *= 1.0002;
    float l = (length(uv) - 0.5);
	vec2 corner = sign(vec2(uv.x, -abs(uv.y))) * vec2(0.5, 0.3);
    float x = max(0.5 - length (uv - corner), .0);
    x = smoothstep(0.0, 0.001, x);
    l = smoothstep(0.0, 0.001, l);
    l = max(l, x);
    
    float col = floor(l * 0.01);
    
    float n = noise(uv * 1.) * 1.0;
	return n - clamp(l, 0.0, n);
}

vec3 textureRoof(vec2 uv)
{
	uv *= 10.0;
	uv.yx = vec2(1.0, 0.) - uv.xy;
	
    vec3 color = vec3(0.0);
    
    vec2 uvmod = vec2(1.001, 1.001);
    
    float n1 = noise(uv * 5.0);
	float n2 = noise(uv * 5.0);
    
	vec3 col1 = vec3(0.45, 0.52, 0.85) * n1;
	vec3 col2 = vec3(0.25, 0.32, 0.65) * n2;
	
    for (int i = 0; i < 2; ++i)
    {
        vec2 _uv = uv + float(i) * uvmod * 0.5;
        _uv = (mod(_uv, uvmod) / uvmod) * uvmod * 1.0;
        _uv -= vec2(0.5, .0);
        
		vec3 c = vec3(fan(_uv * 0.9));
		
		if (i == 0)
			c.rgb *= col1 * 0.25 * n1;
		if (i == 1)
			c.rgb *= col2 * 0.25 * n2;
		
        color += c.rgb;
		
    }
    
	color = clamp(color, 0.0, 1.0);

	vec2 col3 = vec2(noise(floor(uv))) * 10.0;
	// Producing the scale tile.
    return color * col3.xyx * 2.0;
}

void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID);
	vec2 uv = gl_GlobalInvocationID.xy / iResolution.xy;
	
	vec4 fragColor = vec4(0.0);
	
	fragColor = vec4(textureRoof(uv), 1.0);
	imageStore(_TextureTex, id.xy, fragColor);
}
