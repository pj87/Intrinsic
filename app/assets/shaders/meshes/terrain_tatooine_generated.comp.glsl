#version 450

layout(binding = 0) buffer _SizeBuffer 
{
	int _Width;
	int _Height;
};

layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

layout(binding = 2) uniform sampler2D _Gradient3D;

layout(binding = 3) uniform sampler2D _PermTable2D;

layout(binding = 4) buffer _VoxelBuffer 
{
	float _Result[];
};

layout(binding = 5) buffer _VoxelNormalBuffer
{
	vec4 _NormalResult[];
};

// Created by inigo quilez - iq/2014
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

//-----------------------------------------------------------------------------------

#define LOWDETAIL
//#define HIGH_QUALITY_NOISE

float hash1( float n )
{
    return fract( n*17.0*fract( n*0.3183099 ) );
}

float hash1( vec2 p )
{
    p  = 50.0*fract( p*0.3183099 );
    return fract( p.x*p.y*(p.x+p.y) );
}

float n(vec3 p)
{
    float x = mod(dot(p,vec3(1,11,73)),256.);
    return sin(x*cos(x*100.));
}

float noise1(vec3 p)
{
    vec3 ip = floor(p);
    p -= ip;
    return
        mix(
        	mix(
                mix(n(ip),n(ip+vec3(1,0,0)),p.x),
                mix(n(ip+vec3(0,1,0)),n(ip+vec3(1,1,0)), p.x), p.y),
        	mix(
                mix(n(ip+vec3(0,0,1)),n(ip+vec3(1,0,1)),p.x),
                mix(n(ip+vec3(0,1,1)),n(ip+vec3(1,1,1)),p.x), p.y), p.z)        ;
}

vec2 random2(vec2 st){
    st = vec2( dot(st,vec2(127.1,311.7)),
              dot(st,vec2(269.5,183.3)) );
    return -1.0 + 2.0*fract(sin(st)*43758.5453123);
}

// Gradient Noise by Inigo Quilez - iq/2013
// https://www.shadertoy.com/view/XdXGW8
// https://thebookofshaders.com/edit.php#11/2d-gnoise.frag
/*
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    vec2 u = f*f*(3.0-2.0*f);

    return mix( mix( dot( random2(i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ),
                     dot( random2(i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
                mix( dot( random2(i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ),
                     dot( random2(i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
}
*/

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
    
    return -1.0+2.0*( a + (b-a)*u.x + (c-a)*u.y + (a - b - c + d)*u.x*u.y );
}

//-----------------------------------------------------------------------------------
const mat3 m = mat3( 0.00,  0.80,  0.60,
                    -0.80,  0.36, -0.48,
                    -0.60, -0.48,  0.64 );

float displacement( vec3 p )
{
    float f;
    f  = 0.5000*noise1( p ); p = m*p*2.02;
    f += 0.2500*noise1( p ); p = m*p*2.03;
    f += 0.1250*noise1( p ); p = m*p*2.01;
	#ifndef LOWDETAIL
    f += 0.0625*noise1( p ); 
	#endif
    return f;
}

vec4 texcube( sampler2D sam, in vec3 p, in vec3 n )
{
	vec4 x = texture( sam, p.yz );
	vec4 y = texture( sam, p.zx );
	vec4 z = texture( sam, p.xy );
	return (x*abs(n.x) + y*abs(n.y) + z*abs(n.z))/(abs(n.x)+abs(n.y)+abs(n.z));
}

//-----------------------------------------------------------------------------------

float terrain( in vec2 q )
{
	//float th = smoothstep( 0.0, 0.7, textureLod( iChannel0, 0.001*q, 0.0 ).x );
	//float th = textureLod( iChannel0, 0.001*q, 0.0 ).x;
	//float th = noise(.5 * q) * 0.25;
	//float th = noise(0.1 * q);
	float th = noise(0.5 * q) * 0.25;
	//float th = noise(0.1 * q);
	//float th = smoothstep( 0.0, 0.7, noise(1.*q) * 1.5 );
    //float rr = smoothstep( 0.1, 0.5, textureLod( iChannel1, 2.0*0.03*q, 0.0 ).y );
	float h = 1.9;
	#ifndef LOWDETAIL
	//h += -0.15 + (1.0-0.6*rr)*(1.5-1.0*th) * 0.3*(1.0-textureLod( iChannel0, 0.04*q*vec2(1.2,0.5), 0.0 ).x);
	#endif
	h += th*7.0;
    //h += 0.3*rr;
    return -h;
}

vec4 map( in vec3 p )
{
	float h = terrain( p.xz );
	float dis = displacement( 0.25*p*vec3(1.0,4.0,1.0) );
	dis *= 3.0;
	return vec4( (dis + p.y-h)*0.25, p.x, h, 0.0 );
}

float mapScaled(vec3 p, vec4 c)
{
	return map(p / 6.0).x * 6.0;
	//return length(p) - 20.0;
}

vec4 getNormal( in vec3 pos, vec4 c)
{
    vec3  eps = vec3(.001,0.0,0.0);
    vec3 nor;
    nor.x = mapScaled(pos+eps.xyy, c) - mapScaled(pos-eps.xyy, c);
    nor.y = mapScaled(pos+eps.yxy, c) - mapScaled(pos-eps.yxy, c);
    nor.z = mapScaled(pos+eps.yyx, c) - mapScaled(pos-eps.yyx, c);
    return vec4(normalize(nor), 0.0);
}

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
void main()
{
    uvec3 id = gl_GlobalInvocationID;
	vec3 uv = vec3(id);

	//uv *= 0.0001;

	//uncomment this for fractal noise
	//float n = fBm(uv, 4);

	//uncomment this for turbulent noise
	//float n = turbulence(uv, 4);

	//uncomment this for ridged multi fractal
	//float n = ridgedmf(uv, 4, 1.0);

	vec4 c = 0.45*cos( vec4(0.5,3.9,1.4,1.1) + _Frequency*vec4(1.2,1.7,1.3,2.5) ) - vec4(0.3,0.0,0.0,0.0);
	//vec4 c = vec4(0.4);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(25.0f, 10.0f, 0.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f, 1.0f, 100.0f), c);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(_Lacunarity - 32.0, 32.0, _Gain), c);
	_NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = -getNormal(uv - vec3(32.0f, 32.0, 32.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);

}
