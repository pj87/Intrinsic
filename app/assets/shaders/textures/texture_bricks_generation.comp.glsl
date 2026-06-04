// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// See http://www.iquilezles.org/www/articles/warp/warp.htm for details

// https://www.shadertoy.com/view/MslXz8

#version 450

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

float noise(vec2 n) {
    const vec2 d = vec2(0.0, 1.0);
    vec2 b = floor(n), f = smoothstep(vec2(0.0), vec2(1.0), fract(n));
    return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
}

float fbm(vec2 n) {
    float total = 0.0, amplitude = 1.0;
    for (int i = 0; i < 7; i++) {
        total += noise(n) * amplitude;
        n += n;
        amplitude *= 0.5;
    }
    return total;
}

#define iTime 1.0
#define iResolution vec2(2048.0, 2048)

vec3 BRICK_COLOR = vec3(192.0 / 255.0, 106.0 / 255.0, 59.0 / 255.0);
vec3 BRICK_COLOR_VARIATION = vec3( 30.0 /255.0, 20.0/255.0, 20.0/255.0);

vec3 MORTAR_COLOR = vec3(232.0 / 255.0, 216.0 / 255.0, 195.0 / 255.0);

vec2 BRICK_SIZE = vec2(0.08, 0.06);

vec2 BRICK_PCT = vec2(0.95, 0.9);

void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID);
	vec2 uv = gl_GlobalInvocationID.xy / iResolution.xy;
    
    vec2 position = uv / BRICK_SIZE;
    
    if(fract(position.y * 0.5) > 0.5)
    {
     	position.x += 0.5;   
    }
    
    position = fract(position);
    
    vec2 useBrick = step(position, BRICK_PCT);
    
    //vec3 texSample 	= texture( iChannel0, uv ).rgb;
    
    vec3 color = mix(MORTAR_COLOR, BRICK_COLOR, useBrick.x * useBrick.y) + BRICK_COLOR_VARIATION;// * texSample;
    
	// lightning++
	// draw a line, left side is fixed
    vec2 t = uv * vec2(2.0,1.0);
    float ycenter = fbm(t)*0.5;
    float diff = abs(uv.y - ycenter);
    //float c1 = 1.0 - mix(0.0,1.0,diff*200.0);
	//vec4 col = vec4(c1*0.6,0.2*c1,c1,1.0); // purple color
	float diff1 = uv.y - ycenter;
	// lightning--
	
	vec4 fragColor = vec4(0.0);
	
	if (uv.y > diff * 10.0 && uv.y < diff * 200.0)
        fragColor = vec4(color, 1.0);
    else
        fragColor = vec4(0.75, 0.75, 0.75, 1.0);
	
	imageStore(_TextureTex, id.xy, fragColor);
}
