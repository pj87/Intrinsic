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

#define iTime 1.0
#define iResolution vec2(2048.0, 2048)

// Created by inigo quilez - iq/2015
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID);
    vec2 pos = 256.0*gl_GlobalInvocationID.xy/iResolution.x + iTime;

    vec3 col = vec3(0.0);
    for( int i=0; i<6; i++ ) 
    {
        vec2 a = floor(pos);
        vec2 b = fract(pos);
        
        vec4 w = fract((sin(a.x*7.0+31.0*a.y + 0.01*iTime)+vec4(0.035,0.01,0.0,0.7))*13.545317); // randoms
                
        col += w.xyz *                                   // color
               smoothstep(0.45,0.55,w.w) *               // intensity
               sqrt( 16.0*b.x*b.y*(1.0-b.x)*(1.0-b.y) ); // pattern
        
        pos /= 2.0; // lacunarity
        col /= 2.0; // attenuate high frequencies
    }
    
    col = pow( 2.5*col, vec3(1.0,1.0,0.7) );    // contrast and color shape
    
    imageStore(_TextureTex, id.xy, vec4(col, 1.0));
}
