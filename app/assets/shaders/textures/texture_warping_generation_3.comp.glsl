// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// See http://www.iquilezles.org/www/articles/warp/warp.htm for details

// https://www.shadertoy.com/view/4s23zz

#version 450

layout(binding = 0, RGBA8) uniform image2D _TextureTex;
layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

#define iTime 1.0
#define iResolution vec2(2048.0, 2048.0)

// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// See http://www.iquilezles.org/www/articles/warp/warp.htm for details

// undefine this on old/slow computers
#define SLOW_NORMAL

vec2 hash2( float n )
{
    return fract(sin(vec2(n,n+1.0))*vec2(13.5453123,31.1459123));
}

float hash1( vec2 p )
{
    p  = 50.0*fract( p*0.3183099 );
    return fract( p.x*p.y*(p.x+p.y) );
}

//==========================================================================================
// noises
//==========================================================================================
float noise( in vec2 x )
{
    vec2 p = floor(x);
    vec2 w = fract(x);
    vec2 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    
#if 0
    p *= 0.3183099;
    float kx0 = 50.0*fract( p.x );
    float kx1 = 50.0*fract( p.x+0.3183099 );
    float ky0 = 50.0*fract( p.y );
    float ky1 = 50.0*fract( p.y+0.3183099 );

    float a = fract( kx0*ky0*(kx0+ky0) );
    float b = fract( kx1*ky0*(kx1+ky0) );
    float c = fract( kx0*ky1*(kx0+ky1) );
    float d = fract( kx1*ky1*(kx1+ky1) );
#else
    float a = hash1(p+vec2(0,0));
    float b = hash1(p+vec2(1,0));
    float c = hash1(p+vec2(0,1));
    float d = hash1(p+vec2(1,1));
#endif
    
    return ( a + (b-a)*u.x + (c-a)*u.y + (a - b - c + d)*u.x*u.y );
}

const mat2 mtx = mat2( 0.80,  0.60, -0.60,  0.80 );

float fbm4( vec2 p )
{
    float f = 0.0;

    f += 0.5000*(-1.0+2.0*noise( p )); p = mtx*p*2.02;
    f += 0.2500*(-1.0+2.0*noise( p )); p = mtx*p*2.03;
    f += 0.1250*(-1.0+2.0*noise( p )); p = mtx*p*2.01;
    f += 0.0625*(-1.0+2.0*noise( p ));

    return f/0.9375;
}

float fbm6( vec2 p )
{
    float f = 0.0;

    f += 0.500000*noise( p ); p = mtx*p*2.02;
    f += 0.250000*noise( p ); p = mtx*p*2.03;
    f += 0.125000*noise( p ); p = mtx*p*2.01;
    f += 0.062500*noise( p ); p = mtx*p*2.04;
    f += 0.031250*noise( p ); p = mtx*p*2.01;
    f += 0.015625*noise( p );

    return f/0.96875;
}

vec2 fbm4_2( vec2 p )
{
    return vec2( fbm4(p+vec2(1.0)), fbm4(p+vec2(6.2)) );
}

vec2 fbm6_2( vec2 p )
{
    return vec2( fbm6(p+vec2(9.2)), fbm6(p+vec2(5.7)) );
}


float func( vec2 q, out vec2 o, out vec2 n )
{
    q += 0.05*sin(vec2(0.11,0.13)*iTime + length( q )*4.0);
    
    q *= 0.7 + 0.2*cos(0.05*iTime);

    o = 0.5 + 0.5*fbm4_2( q );
    
    o += 0.02*sin(vec2(0.11,0.13)*iTime*length( o ));

    n = fbm6_2( 4.0*o );

    vec2 p = q + 2.0*n + 1.0;

    float f = 0.5 + 0.5*fbm4( 2.0*p );

    f = mix( f, f*f*f*3.5, f*abs(n.x) );

    f *= 1.0-0.5*pow( 0.5+0.5*sin(8.0*p.x)*sin(8.0*p.y), 8.0 );

    return f;
}

float funcs( in vec2 q )
{
    vec2 t1, t2;
    return func(q,t1,t2);
}


void main()
{
	
    vec2 of = vec2(0.0);//hash2( float(iTime)*1113.1 + fragCoord.x + fragCoord.y*119.1 );

	ivec3 id = ivec3(gl_GlobalInvocationID);	
    //vec3 uv = vec3(id) / 2048.0;
	
	vec2 p = gl_GlobalInvocationID.xy / iResolution.xy;
	vec2 q = (-iResolution.xy + 2.0*(gl_GlobalInvocationID.xy+of)) /iResolution.y;
	
    vec2 o, n;
    float f = func(q * 10.0, o, n);
    vec3 col = vec3(0.0);


    col = mix( vec3(0.2,0.1,0.4), vec3(0.3,0.05,0.05), f );
    col = mix( col, vec3(0.9,0.9,0.9), dot(n,n) );
    col = mix( col, vec3(0.5,0.2,0.2), 0.5*o.y*o.y );


    col = mix( col, vec3(0.0,0.2,0.4), 0.5*smoothstep(1.2,1.3,abs(n.y)+abs(n.x)) );

    col *= f*2.0;
    
#ifdef SLOW_NORMAL
    vec2 ex = vec2( 1.0 / iResolution.x, 0.0 );
    vec2 ey = vec2( 0.0, 1.0 / iResolution.y );
	vec3 nor = normalize( vec3( funcs(q+ex) - f, ex.x, funcs(q+ey) - f ) );
#else
    vec3 nor = normalize( vec3( dFdx(f)*iResolution.x, 1.7, dFdy(f)*iResolution.y ) );	
#endif
    vec3 lig = normalize( vec3( 0.9, -0.2, -0.4 ) );
    float dif = clamp( 0.3+0.7*dot( nor, lig ), 0.0, 1.0 );

    vec3 bdrf;
    bdrf  = vec3(0.85,0.90,0.95)*(nor.y*0.5+0.5);
    bdrf += vec3(0.15,0.10,0.05)*dif;

    bdrf  = vec3(0.85,0.90,0.95)*(nor.y*0.5+0.5);
    bdrf += vec3(0.15,0.10,0.05)*dif;

    col *= bdrf;

    col = vec3(1.0)-col;

    col = col*col;

    col *= vec3(1.2,1.25,1.2);
	
	col *= 0.5 + 0.5 * sqrt(16.0*p.x*p.y*(1.0-p.x)*(1.0-p.y));
	
	//fragColor = vec4( col, 1.0 );
	imageStore(_TextureTex, id.xy, vec4(col, 1.0));
}