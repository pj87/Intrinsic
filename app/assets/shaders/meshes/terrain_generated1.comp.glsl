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

#define pmod(a,b)    ( mod(mod((a),(b))+(b),(b)) )
#define rep(a,r)    ( pmod(((a)+(r)*.5),(r))-(r)*.5 )
#define repxz(a,r)    vec3( rep((a).x,(r)), (a).y, rep((a).z,(r)) )

float opU(float d1, float d2)
{
	return (d1 < d2) ? d1 : d2;
}

float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

const mat2 m2 = mat2(1.6,-1.2,1.2,1.6);

float noi( in vec2 p )
{
    return 0.5*(cos(6.2831*p.x) + cos(6.2831*p.y));
}

float terrainMed( vec2 p )
{
    p *= 0.0035;

    float s = 1.0;
	float t = 0.0;
	for( int i=0; i<3; i++ )
	{
        t += s*noi( p );
		s *= 0.5;// + 0.1*t;
        p = 0.97*m2*p;// + (t-0.5)*0.2;
	}
            
    return t*35.0;
}

float map( in vec3 pos, float time )
{
    float m = 0.0;
	//float h = pos.y - terrainMed(pos.xz);
	float h = pos.y + terrainMed(pos.xz) + 10.0;
	
	/*
    float sph = 100.0;
    float k = 60.0;
    float w = clamp( 0.5 + 0.5*(h-sph)/k, 0.0, 1.0 );
    h = mix( h, sph, w ) - k*w*(1.0-w);
    m = mix( m, 1.0, w ) - 1.0*w*(1.0-w);
    m = clamp(m,0.0,1.0);
	*/
	
	//pos = repxz(vec3(pos.x, h, pos.z), 300.0);
    
    //h = opU(h, sdBox(pos, vec3(2.5, 50.0, 2.5)));
	//h = opU(h, sdBox(pos, vec3(2.5, 50.0, 2.5)));
	
	return h;
	
    //return vec2( h, m );
}

float mapScaled(vec3 p, vec4 c)
{
	return map(p / 0.1, 0.0) * 0.1;
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
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(32.0f, 32.0, 32.0f), c);
	_NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = -getNormal(uv - vec3(32.0f, 32.0, 32.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);

}
