#version 450

layout(binding = 0) buffer _SizeBuffer 
{
	int _Width;
	int _Height;
	int _Depth;
	int _Border;
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

vec3 fmod(vec3 x, float y)
{
	return (x - y * trunc(x/y));
}

vec3 fade(vec3 t)
{
	return t * t * t * (t * (t * 6 - 15) + 10);
}

vec4 perm2d(vec2 uv)
{
	return textureLod(_PermTable2D, uv, 0);
}

float gradperm(float x, vec3 p)
{
	vec3 g = textureLod(_Gradient3D, vec2(x, 0), .0).rgb * 2.0 - 1.0;
	return dot(g, p);
}
						
float inoise(vec3 p)
{
	vec3 P = fmod(floor(p), 256.0);	// FIND UNIT CUBE THAT CONTAINS POINT
  	p -= floor(p);                  // FIND RELATIVE X,Y,Z OF POINT IN CUBE.
	vec3 f = fade(p);               // COMPUTE FADE CURVES FOR EACH OF X,Y,Z.

	P = P / 256.0;
	const float one = 1.0 / 256.0;
	
    // HASH COORDINATES OF THE 8 CUBE CORNERS
	vec4 AA = perm2d(P.xy) + P.z;
 
	// AND ADD BLENDED RESULTS FROM 8 CORNERS OF CUBE
  	return mix( mix( mix( gradperm(AA.x, p ),  
                             gradperm(AA.z, p + vec3(-1, 0, 0) ), f.x),
                       mix( gradperm(AA.y, p + vec3(0, -1, 0) ),
                             gradperm(AA.w, p + vec3(-1, -1, 0) ), f.x), f.y),
                             
                 mix( mix( gradperm(AA.x+one, p + vec3(0, 0, -1) ),
                             gradperm(AA.z+one, p + vec3(-1, 0, -1) ), f.x),
                       mix( gradperm(AA.y+one, p + vec3(0, -1, -1) ),
                             gradperm(AA.w+one, p + vec3(-1, -1, -1) ), f.x), f.y), f.z);
}

// fractal sum, range -1.0 - 1.0
float fBm(vec3 p, int octaves)
{
	float freq = _Frequency, amp = 0.5;
	float sum = 0;	
	for(int i = 0; i < octaves; i++) 
	{
		sum += inoise(p * freq) * amp;
		freq *= _Lacunarity;
		amp *= _Gain;
	}
	return sum;
}

// fractal abs sum, range 0.0 - 1.0
float turbulence(vec3 p, int octaves)
{
	float sum = 0;
	float freq = _Frequency, amp = 1.0;
	for(int i = 0; i < octaves; i++) 
	{
		sum += abs(inoise(p*freq))*amp;
		freq *= _Lacunarity;
		amp *= _Gain;
	}
	return sum;
}

// Ridged multifractal, range 0.0 - 1.0
// See "Texturing & Modeling, A Procedural Approach", Chapter 12
float ridge(float h, float offset)
{
    h = abs(h);
    h = offset - h;
    h = h * h;
    return h;
}

float ridgedmf(vec3 p, int octaves, float offset)
{
	float sum = 0;
	float freq = _Frequency, amp = 0.5;
	float prev = 1.0;
	for(int i = 0; i < octaves; i++) 
	{
		float n = ridge(inoise(p*freq), offset);
		sum += n*amp*prev;
		prev = n;
		freq *= _Lacunarity;
		amp *= _Gain;
	}
	return sum;
}

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
void main()
{
    uvec3 id = gl_GlobalInvocationID;
	vec3 uv = vec3(id);

	//uncomment this for fractal noise
	float n = fBm(uv, 4);

	//uncomment this for turbulent noise
	//float n = turbulence(uv, 4);

	//uncomment this for ridged multi fractal
	//float n = ridgedmf(uv, 4, 1.0);
	
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = n;

}
