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

const float PI = 3.14159265359;
#define CEILING_HEIGHT			5.0
#define COLUMN_DIST				7.5

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


//scene
float model ( vec3 p ) {
    float hr = COLUMN_DIST*0.5;
    p.x+=hr;
    
    //pillars
    vec3 pr = repeat( p, vec3(COLUMN_DIST,0.0,COLUMN_DIST) );
    float pillar = ycylinder( pr, 0.5, CEILING_HEIGHT );
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
	return model(p / 3.0) * 3.0;
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
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(10.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);

}
