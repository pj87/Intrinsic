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

// https://www.shadertoy.com/view/MdyBzw
//quick hack to loop every 16 seconds (fix problems occuring when shader runs for several minutes)
#define iTime mod(iTime, 16.0)

#define PI			3.14159265359
#define HALF_PI		1.57079632679
#define TAU     	6.28318530718

#define FAST_TRACE

#define CEILING_HEIGHT			5.0
#define COLUMN_DIST				7.5
#define MAT_COL					vec3(0.5, 0.4, 0.35)

#define FOV						HALF_PI
#define CAMERA_HEIGHT			2.0
#define Z_OFFSET				iTime*COLUMN_DIST*0.25

#define DRAW_LIGHT
#define LIGHT_POSITION			vec3( sin(iTime*PI*0.125)*COLUMN_DIST*2.0, 2.0, 20.0+Z_OFFSET )
#define SHADOW_HARDNESS			50.0

#define FOG_NEAR				50.0
#define FOG_COL					vec3(0.02, 0.03, 0.04)

#define MAX_STEPS_PER_RAY   	200
#define MAX_RAY_LENGTH     		150.0
#define EPSILON					0.00001
#define SHADOW_ERROR			0.05

//#define DEBUG


///////////////////////////////////////////////////////////////////////////////////////
//	MODEL															  		 		 //
///////////////////////////////////////////////////////////////////////////////////////

//displacements (use in place of 'p' in distance function)
vec3 repeat ( vec3 p, vec3 d ) {
    return mod(p+d*0.5,d)-d*0.5;
}


//primatives
float ubox ( vec3 p, vec3 l ) {
    return length(max(abs(p)-l,0.0));
}


float ybar ( vec3 p, vec2 l ) {
    vec2 d=abs(p.xz)-l;
    return min(max(d.x,d.y),0.0)+length(max(d,0.0));
}


float ycylinder ( vec3 p, float r, float l ) {
    return max(length(p.xz)-r,abs(p.y)-l);
}


float torus ( vec3 p, float ra, float rb ) {
    return length(vec2(length(p.xz)-ra, p.y))-rb;
}


//scene (low quality to accelerate casting with FAST_TRACE)
float modellq ( vec3 p ) {
    p.x+=COLUMN_DIST*0.5;
    vec3 pr = repeat( p, vec3(COLUMN_DIST,0.0,COLUMN_DIST) );
    return min( ybar(pr,vec2(0.7)), min( CEILING_HEIGHT-p.y, p.y ));
}


//scene
float map ( vec3 p ) {
    float hr = COLUMN_DIST*0.5;
    p.x+=hr;
    
    //pillars
    vec3 pr = repeat( p, vec3(COLUMN_DIST,0.0,COLUMN_DIST) );
    float pillar = ycylinder( pr, 0.5, CEILING_HEIGHT );
	/*
    pillar = min( pillar, 	   ubox( pr-vec3(0.0,CEILING_HEIGHT-0.25,0.0), vec3(0.6,0.25,0.6) )-0.01 );
    pillar = min( pillar, 	   ubox( pr-vec3(0.0,CEILING_HEIGHT-0.05,0.0), vec3(0.6,0.0,0.6) )-0.05 );
    pillar = min( pillar, ycylinder( pr-vec3(0.0,CEILING_HEIGHT-0.65,0.0), 0.55, 0.2 ) );
    pillar = min( pillar, 	  torus( pr-vec3(0.0,CEILING_HEIGHT-0.55,0.0), 0.55, 0.05 ) );
    pillar = max( pillar, 	 -torus( pr-vec3(0.0,CEILING_HEIGHT-0.70,0.0), 0.55, 0.05 ) );
    pillar = min( pillar, ubox( pr, vec3(0.55,0.4,0.55) )-0.01 );
    pillar = min( pillar, ubox( pr, vec3(0.65,0.2,0.65) )-0.01 );
    pillar = min( pillar, ubox( pr+vec3(0.0,-0.45,0.0), vec3(0.55,0.0,0.55) )-0.05 );
    pillar = min( pillar, ycylinder( pr+vec3(0.0,-0.6,0.0), 0.55, 0.2 ) );
    pillar = min( pillar, torus( pr+vec3(0.0,-0.7,0.0), 0.55, 0.05 ) );
    pillar = max( pillar, -torus( pr+vec3(0.0,-0.6,0.0), 0.55, 0.05 ) );
    */
    //ceiling
    float ch = p.y-CEILING_HEIGHT+1.0;			//ceiling arch center height
    float pxr = mod(p.x,COLUMN_DIST)-hr;
    float pzr = mod(p.z,COLUMN_DIST)-hr;
    float ceiling = COLUMN_DIST*0.7-0.4-sqrt( ch*ch + min( pzr*pzr, pxr*pxr ) );
    float archestrim = max( ceiling-COLUMN_DIST*0.2, -ybar( vec3(pxr,p.y,pzr), vec2(hr-0.4)) );
    ceiling = min( ceiling, archestrim );
    ceiling = max( ceiling, CEILING_HEIGHT-p.y );

    return min( min( ceiling, pillar ), p.y );
}

float mapScaled(vec3 p, vec4 c)
{
	//return map2(p/0.0025f, c) * 0.0025f;
	//return map3(p/0.0025f) * 0.0025f;
	//return sponge1(p / 0.0025) * 0.0025;
	//return sponge2(p / 0.0025) * 0.0025;
	
	//return ruins(p/0.000025f) * 0.000025f;
	return map(p/4.0f) * 4.0f;
}

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
void main()
{
    uvec3 id = gl_GlobalInvocationID;
	vec3 uv = vec3(id);

	//uv *= 0.1;

	//uncomment this for fractal noise
	//float n = fBm(uv, 4);

	//uncomment this for turbulent noise
	//float n = turbulence(uv, 4);

	//uncomment this for ridged multi fractal
	//float n = ridgedmf(uv, 4, 1.0);

	vec4 c = 0.45*cos( vec4(0.5,3.9,1.4,1.1) + _Frequency*vec4(1.2,1.7,1.3,2.5) ) - vec4(0.3,0.0,0.0,0.0);
	//vec4 c = vec4(0.4);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(26.0f, 21.0f, 19.9f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(1.5), vec3(1.5, 1.5, 1.5));

	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);
    _NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = vec4(0.0);
}
