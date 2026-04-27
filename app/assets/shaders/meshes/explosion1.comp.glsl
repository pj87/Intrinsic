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

#define iTime _Frequency

// https://www.shadertoy.com/view/WdtXzj

//creates a rotation matrix for a given angle
mat2 rot(float a){
    float c=cos(a);
    float s=sin(a);
    return mat2(c,-s,s,c);
}

//smooth minimum functions for both floats and vec3s
float smin(float a, float b, float h){
    float k=clamp((a-b)/h*.5+.5,0.,1.);
    return mix(a,b,k)-k*(1.-k)*h;
}

vec3 smin(vec3 a, vec3 b, float h){
    vec3 k=clamp((a-b)/h*.5+.5,0.,1.);
    return mix(a,b,k)-k*(1.-k)*h;
}

//creates the space folding so that two spheres can appear like this.
vec3 kifs(vec3 p, float t){
    //spreads them out exponentially - exploding
    float s=-2.+4.6*exp(fract((iTime + 2.0)*.25));
    //rotate and fold space a few times by a decreasing amount
    for(int i=0;i<4;i++){
        p.xz*=rot(t+float(i));
        p.xy*=rot(.7*(t+float(i)));
        p=smin(p,-p,-3.);
        p-=s;
        s*=.7;
    }
    return p;
}

//distance field
float at=0.;//for the colour
float map(vec3 p){
    vec3 p1=kifs(p,iTime*.1);
    vec3 p2=kifs(p+vec3(2.,2.,-3.),iTime*.13);
    //two sphere sdfs
    float d1=length(p1)-1.5;
    float d2=length(p2)-1.4;
    float m1=smin(d1,d2,-1.);
    at+=.075/(.15+abs(m1));//colouring effect
    return m1;
}

float mapScaled(vec3 p, vec4 c)
{
	//return map2(p/25.0f, c) * 25.0f;
	//return map3(p/0.0025f) * 0.0025f;
	
	return map(p/0.5f) * 0.5f;
}

layout(local_size_x = 6u, local_size_y = 6u, local_size_z = 6u) in;
void main()
{
    uvec3 id = gl_GlobalInvocationID;
	vec3 uv = vec3(id);

	//uv *= 1.0;

	//uncomment this for fractal noise
	//float n = fBm(uv, 4);

	//uncomment this for turbulent noise
	//float n = turbulence(uv, 4);

	//uncomment this for ridged multi fractal
	//float n = ridgedmf(uv, 4, 1.0);

	vec4 c = 0.45*cos( vec4(0.5,3.9,1.4,1.1) + _Frequency*vec4(1.2,1.7,1.3,2.5) ) - vec4(0.3,0.0,0.0,0.0);
	//vec4 c = vec4(0.4);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(20.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);
	_NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = vec4(0.);
}
