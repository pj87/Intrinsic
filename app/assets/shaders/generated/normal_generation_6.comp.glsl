#version 450

layout(binding = 0) buffer _NoiseBuffer 
{
	float _Noise[];
};
layout(binding = 1, rgba16f) uniform image3D _NormalTex;

layout(binding = 2) buffer _SizeBuffer 
{
	int _Width;
	int _Height;
	int _Depth;
	int _Border;
};

layout(local_size_x = 6u, local_size_y = 6u, local_size_z = 6u) in;
void main()
{
    ivec3 id = ivec3(gl_GlobalInvocationID);
	
	float v = _Noise[id.x + id.y * _Width + id.z * _Width * _Height];
	
	float dx = v - _Noise[(id.x+1) + id.y * _Width + id.z * _Width * _Height];
	
	float dy = v -_Noise[id.x + (id.y+1) * _Width + id.z * _Width * _Height];
	
	float dz = v -_Noise[id.x + id.y * _Width + (id.z+1) * _Width * _Height];
	

	imageStore(_NormalTex, id, vec4(normalize(vec3(dx,dy,dz)), 0.0));
}
