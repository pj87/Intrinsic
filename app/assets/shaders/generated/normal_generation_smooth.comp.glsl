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

float sampleVoxel(int x, int y, int z)
{
	x = clamp(x, 0, _Width  - 1);
	y = clamp(y, 0, _Height - 1);
	z = clamp(z, 0, _Depth  - 1);
	return _Noise[x + y * _Width + z * _Width * _Height];
}

layout(local_size_x = 6u, local_size_y = 6u, local_size_z = 6u) in;
void main()
{
    ivec3 id = ivec3(gl_GlobalInvocationID);

	// Central differences give smoother, more accurate normals than forward differences.
	float dx = sampleVoxel(id.x-1, id.y,   id.z  ) - sampleVoxel(id.x+1, id.y,   id.z  );
	float dy = sampleVoxel(id.x,   id.y-1, id.z  ) - sampleVoxel(id.x,   id.y+1, id.z  );
	float dz = sampleVoxel(id.x,   id.y,   id.z-1) - sampleVoxel(id.x,   id.y,   id.z+1);

	imageStore(_NormalTex, id, vec4(normalize(vec3(dx, dy, dz)), 0.0));
}
