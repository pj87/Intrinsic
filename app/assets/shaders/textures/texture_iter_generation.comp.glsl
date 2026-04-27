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

// Noise animation - Lava
// by nimitz (twitter: @stormoid)
// https://www.shadertoy.com/view/lslXRS
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
// Contact the author for other licensing options

//Somewhat inspired by the concepts behind "flow noise"
//every octave of noise is modulated separately
//with displacement using a rotated vector field

//This is a more standard use of the flow noise
//unlike my normalized vector field version (https://www.shadertoy.com/view/MdlXRS)
//the noise octaves are actually displaced to create a directional flow

//Sinus ridged fbm is used for better effect.

// Created by inigo quilez - iq/2014
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.						    

#define iTime 1.0

// Other "Iterations" shaders:
//
// "trigonometric"   : https://www.shadertoy.com/view/Mdl3RH
// "trigonometric 2" : https://www.shadertoy.com/view/Wss3zB
// "circles"         : https://www.shadertoy.com/view/MdVGWR
// "coral"           : https://www.shadertoy.com/view/4sXGDN
// "guts"            : https://www.shadertoy.com/view/MssGW4
// "inversion"       : https://www.shadertoy.com/view/XdXGDS
// "inversion 2"     : https://www.shadertoy.com/view/4t3SzN
// "shiny"           : https://www.shadertoy.com/view/MslXz8
// "worms"           : https://www.shadertoy.com/view/ldl3W4


vec3 shape( in vec2 p )
{
	p *= 2.0;
	
	vec3 s = vec3( 0.0 );
	vec2 z = p;
	for( int i=0; i<8; i++ ) 
	{
        // transform		
		z += cos(z.yx + cos(z.yx + cos(z.yx+0.5*iTime) ) );

        // orbit traps		
		float d = dot( z-p, z-p ); 
		s.x += 1.0/(1.0+d);
		s.y += d;
		s.z += sin(atan(z.y-p.y,z.x-p.x));
		
	}
	
	return s / 8.0;
}

void main() 
{
	ivec3 id = ivec3(gl_GlobalInvocationID);

	vec2 pc = (2.0*gl_GlobalInvocationID.xy-iResolution.xy)/min(iResolution.y,iResolution.x);

	vec2 pa = pc + vec2(0.04,0.0);
	vec2 pb = pc + vec2(0.0,0.04);
	
    // shape (3 times for diferentials)	
	vec3 sc = shape( pc );
	vec3 sa = shape( pa );
	vec3 sb = shape( pb );

    // color	
	vec3 col = mix( vec3(0.08,0.02,0.15), vec3(0.6,1.1,1.6), sc.x );
	col = mix( col, col.zxy, smoothstep(-0.5,0.5,cos(0.5*iTime)) );
	col *= 0.15*sc.y;
	col += 0.4*abs(sc.z) - 0.1;

    // light	
	vec3 nor = normalize( vec3( sa.x-sc.x, 0.01, sb.x-sc.x ) );
	float dif = clamp(0.5 + 0.5*dot( nor,vec3(0.5773) ),0.0,1.0);
	col *= 1.0 + 0.7*dif*col;
	col += 0.3 * pow(nor.y,128.0);

    // vignetting	
	col *= 1.0 - 0.1*length(pc);
	
	//fragColor = vec4( col, 1.0 );
	imageStore(_TextureTex, id.xy, vec4(col, 1.0));
}