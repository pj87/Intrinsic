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

float sphere(vec3 p)
{
    vec3 q = fract(p+0.5) * 2.0 - 1.0;
	return 1.3 - length(q);  
}

float map(vec3 p)
{
	return min(sphere(p), sphere(p+0.5));
}

float mapScaled(vec3 p, vec4 c)
{
	return map(p / 30.0) * 30.0;
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
