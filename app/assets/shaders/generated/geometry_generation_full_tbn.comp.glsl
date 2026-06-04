// https://gamedev.stackexchange.com/questions/51399/what-are-normal-tangent-and-binormal-vectors-and-how-are-they-used
// http://blog.db-in.com/calculating-normals-and-tangent-space/
// https://answers.unity.com/questions/731821/how-do-i-calculate-the-uvs-for-a-procedurally-gene.html
// https://forum.unity.com/threads/going-crazy-on-uv-calculation-for-procedural-mesh.246872/

#version 450

struct Vert
{
	vec4 position;
	vec3 normal;
	vec3 binormal;
	vec3 tangent;
	vec2 uv0;
};


layout(binding = 0) coherent buffer _PositionBuffer
{
	uint _Positions[];
};
layout(binding = 1) coherent buffer _NormalBuffer
{
	uint _Normals[];
};
layout(binding = 2) coherent buffer _TangentBuffer
{
	uint _Tangents[];
};
layout(binding = 3) coherent buffer _BinormalBuffer
{
	uint _Binormals[];
};
layout(binding = 4) buffer _Uv0Buffer
{
	uint _UV0s[];
};
layout(binding = 5) buffer _ColorBuffer
{
    uint _Colors[];
};
layout(binding = 6) buffer _CubeEdgeBuffer
{
	int _CubeEdgeFlags[];
};
layout(binding = 7) buffer _TriangleConnectionBuffer
{
	int _TriangleConnectionTable[];
};
layout(binding = 8) buffer _VoxelBuffer
{
	float _Voxels[];
};
layout(binding = 9) uniform sampler3D _NormalsTex;
layout(binding = 10) buffer _SizesBuffer
{
	int _Width;
	int _Height;
	int _Depth;
	int _Border;
};
layout(binding = 11) buffer _TargetBuffer
{
	float _Target;
};
layout(binding = 12) buffer _CountBuffer
{
	uint _VertexCount;
};

// edgeConnection lists the index of the endpoint vertices for each of the 12 edges of the cube
ivec2 edgeConnection[12] = {ivec2(0, 1), ivec2(1, 2), ivec2(2, 3), ivec2(3, 0),
						    ivec2(4, 5), ivec2(5, 6), ivec2(6, 7), ivec2(7, 4),
                            ivec2(0, 4), ivec2(1, 5), ivec2(2, 6), ivec2(3, 7)};

// edgeDirection lists the direction vector (vertex1-vertex0) for each edge in the cube
vec3 edgeDirection[12] =
{
	vec3(1.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f), vec3(-1.0f, 0.0f, 0.0f), vec3(0.0f, -1.0f, 0.0f),
	vec3(1.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f), vec3(-1.0f, 0.0f, 0.0f), vec3(0.0f, -1.0f, 0.0f),
	vec3(0.0f, 0.0f, 1.0f), vec3(0.0f, 0.0f, 1.0f), vec3(0.0f, 0.0f, 1.0f),  vec3(0.0f, 0.0f, 1.0f)
};							

// vertexOffset lists the positions, relative to vertex0, of each of the 8 vertices of a cube
vec3 vertexOffset[8] =
{
	vec3(0, 0, 0), vec3(1, 0, 0), vec3(1, 1, 0), vec3(0, 1, 0),
	vec3(0, 0, 1), vec3(1, 0, 1), vec3(1, 1, 1), vec3(0, 1, 1)
};

void FillCube(uint x, uint y, uint z, out float cube[8])
{
	cube[0] = _Voxels[x + y * _Width + z * _Width * _Height];
	cube[1] = _Voxels[(x + 1) + y * _Width + z * _Width * _Height];
	cube[2] = _Voxels[(x + 1) + (y + 1) * _Width + z * _Width * _Height];
	cube[3] = _Voxels[x + (y + 1) * _Width + z * _Width * _Height];

	cube[4] = _Voxels[x + y * _Width + (z + 1) * _Width * _Height];
	cube[5] = _Voxels[(x + 1) + y * _Width + (z + 1) * _Width * _Height];
	cube[6] = _Voxels[(x + 1) + (y + 1) * _Width + (z + 1) * _Width * _Height];
	cube[7] = _Voxels[x + (y + 1) * _Width + (z + 1) * _Width * _Height];
}

// GetOffset finds the approximate point of intersection of the surface
// between two points with the values v1 and v2
float GetOffset(float v1, float v2)
{
	float delta = v2 - v1;
	return (delta == 0.0f) ? 0.5f : (_Target - v1) / delta;
}

Vert CreateVertex(vec3 position, vec3 centre, vec3 size)
{
	Vert vert;
	vert.position = vec4(position - centre, 1.0);

	vec3 uv = (position + centre) / size;
	vert.normal = textureLod(_NormalsTex, uv, 0).xyz;

	return vert;
}

uint convert(vec2 pos0, vec2 pos1)
{
	return(packHalf2x16(pos0) << 16 | packHalf2x16(pos1));
}

// Each vertex occupies 1.5 uint32s in the packed half-float buffer.
// The uint32 at the boundary between an even vertex i and odd vertex i+1 is
// shared: LOW16 = i.z, HIGH16 = (i+1).x.  When writing from concurrent GPU
// invocations those two halves must be set with atomics to avoid a race.
void storePosition(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Positions[index] = packHalf2x16(pos1.xy);
		// LOW16 of shared word = our z; HIGH16 belongs to the next vertex.
		atomicAnd(_Positions[index + 1], 0xFFFF0000u);
		atomicOr (_Positions[index + 1], packHalf2x16(vec2(pos1.z, 0.0)));
	}
	else
	{
		uint index = i + (i - 1) / 2;
		// HIGH16 of shared word = our x; LOW16 belongs to the previous vertex.
		atomicAnd(_Positions[index], 0x0000FFFFu);
		atomicOr (_Positions[index], packHalf2x16(vec2(0.0, pos1.x)));
		_Positions[index + 1] = packHalf2x16(pos1.yz);
	}
}

void storeNormal(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Normals[index] = packHalf2x16(pos1.xy);
		atomicAnd(_Normals[index + 1], 0xFFFF0000u);
		atomicOr (_Normals[index + 1], packHalf2x16(vec2(pos1.z, 0.0)));
	}
	else
	{
		uint index = i + (i - 1) / 2;
		atomicAnd(_Normals[index], 0x0000FFFFu);
		atomicOr (_Normals[index], packHalf2x16(vec2(0.0, pos1.x)));
		_Normals[index + 1] = packHalf2x16(pos1.yz);
	}
}

void storeBinormal(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Binormals[index] = packHalf2x16(pos1.xy);
		atomicAnd(_Binormals[index + 1], 0xFFFF0000u);
		atomicOr (_Binormals[index + 1], packHalf2x16(vec2(pos1.z, 0.0)));
	}
	else
	{
		uint index = i + (i - 1) / 2;
		atomicAnd(_Binormals[index], 0x0000FFFFu);
		atomicOr (_Binormals[index], packHalf2x16(vec2(0.0, pos1.x)));
		_Binormals[index + 1] = packHalf2x16(pos1.yz);
	}
}

void storeTangent(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Tangents[index] = packHalf2x16(pos1.xy);
		atomicAnd(_Tangents[index + 1], 0xFFFF0000u);
		atomicOr (_Tangents[index + 1], packHalf2x16(vec2(pos1.z, 0.0)));
	}
	else
	{
		uint index = i + (i - 1) / 2;
		atomicAnd(_Tangents[index], 0x0000FFFFu);
		atomicOr (_Tangents[index], packHalf2x16(vec2(0.0, pos1.x)));
		_Tangents[index + 1] = packHalf2x16(pos1.yz);
	}
}

void storeUV(uint i, vec2 pos1)
{
	_UV0s[i] = packHalf2x16(pos1.xy);
}

void storeColor(uint i, vec4 p_Color)
{  
  _Colors[i] = packUnorm4x8(vec4(p_Color.b, p_Color.g, p_Color.r, p_Color.a));
}
				
layout(local_size_x = 6u, local_size_y = 6u, local_size_z = 6u) in;
void main()
{	
	uvec3 id = gl_GlobalInvocationID;
	uint idx = id.x + id.y * _Width + id.z * _Width * _Height;
	
	//Dont generate verts at the edge as they dont have 
	//neighbours to make a cube from and the normal will 
	//not be correct around border.
	if (id.x >= _Width - 1 - _Border) return;
	if (id.y >= _Height - 1 - _Border) return;
	if (id.z >= _Depth - 1 - _Border) return;

	vec3 pos = vec3(id);
	vec3 centre = vec3(_Width, _Height, _Depth) / 2.0;

	float cube[8];
	FillCube(id.x, id.y, id.z, cube);

	int i = 0;
	int flagIndex = 0;
	vec3 edgeVertex[12];

	for (i = 0; i < 8; i++)
	{
		if (cube[i] <= _Target) flagIndex |= 1 << i;
	}

	int edgeFlags = _CubeEdgeFlags[flagIndex];
	if (edgeFlags == 0) return;

	for (i = 0; i < 12; i++)
	{
		if ((edgeFlags & (1 << i)) != 0)
		{
			float offset = GetOffset(cube[edgeConnection[i].x], cube[edgeConnection[i].y]);
			edgeVertex[i] = pos + (vertexOffset[edgeConnection[i].x] + offset * edgeDirection[i]);
		}
	}

	vec3 size = vec3(_Width - 1, _Height - 1, _Depth - 1);

	// Write each real triangle to a compact slot obtained via atomicAdd.
	// This eliminates sparse zero-position slots and lets the draw call use
	// the exact vertex count without CPU readback or compaction.
	for (i = 0; i < 5; i++)
	{
		if (_TriangleConnectionTable[flagIndex * 16 + 3 * i] < 0) continue;

		vec3 position = edgeVertex[_TriangleConnectionTable[flagIndex * 16 + (3 * i + 0)]];
		Vert v0 = CreateVertex(position, centre, size);
		vec2 uvX = clamp((v0.position.yz + _Width  / 2.0) / _Width,  vec2(0.0), vec2(1.0));
		vec2 uvY = clamp((v0.position.xz + _Height / 2.0) / _Height, vec2(0.0), vec2(1.0));
		vec2 uvZ = clamp((v0.position.xy + _Depth  / 2.0) / _Depth,  vec2(0.0), vec2(1.0));
		vec2 uv0 = mix(mix(uvX, uvZ, abs(v0.normal.z)), uvY, abs(v0.normal.y));

		position = edgeVertex[_TriangleConnectionTable[flagIndex * 16 + (3 * i + 1)]];
		Vert v1 = CreateVertex(position, centre, size);
		uvX = clamp((v1.position.yz + _Width  / 2.0) / _Width,  vec2(0.0), vec2(1.0));
		uvY = clamp((v1.position.xz + _Height / 2.0) / _Height, vec2(0.0), vec2(1.0));
		uvZ = clamp((v1.position.xy + _Depth  / 2.0) / _Depth,  vec2(0.0), vec2(1.0));
		vec2 uv1 = mix(mix(uvX, uvZ, abs(v1.normal.z)), uvY, abs(v1.normal.y));

		position = edgeVertex[_TriangleConnectionTable[flagIndex * 16 + (3 * i + 2)]];
		Vert v2 = CreateVertex(position, centre, size);
		uvX = clamp((v2.position.yz + _Width  / 2.0) / _Width,  vec2(0.0), vec2(1.0));
		uvY = clamp((v2.position.xz + _Height / 2.0) / _Height, vec2(0.0), vec2(1.0));
		uvZ = clamp((v2.position.xy + _Depth  / 2.0) / _Depth,  vec2(0.0), vec2(1.0));
		vec2 uv2 = mix(mix(uvX, uvZ, abs(v2.normal.z)), uvY, abs(v2.normal.y));

		// UV-based tangent: solve dPos = T*dU + B*dV for the triangle.
		vec3 dp1 = v1.position.xyz - v0.position.xyz;
		vec3 dp2 = v2.position.xyz - v0.position.xyz;
		vec2 duv1 = uv1 - uv0;
		vec2 duv2 = uv2 - uv0;
		float det = duv1.x * duv2.y - duv1.y * duv2.x;
		vec3 triTangent;
		if (abs(det) > 1e-6)
			triTangent = normalize((dp1 * duv2.y - dp2 * duv1.y) / det);
		else
			triTangent = normalize(dp1);

		// Gram-Schmidt: project tangent perpendicular to each vertex normal.
		vec3 tangent0  = normalize(triTangent - dot(triTangent, v0.normal) * v0.normal);
		vec3 tangent1  = normalize(triTangent - dot(triTangent, v1.normal) * v1.normal);
		vec3 tangent2  = normalize(triTangent - dot(triTangent, v2.normal) * v2.normal);
		vec3 binormal0 = cross(v0.normal, tangent0);
		vec3 binormal1 = cross(v1.normal, tangent1);
		vec3 binormal2 = cross(v2.normal, tangent2);

		uint slot = atomicAdd(_VertexCount, 3u);
		storePosition(slot + 0u, v0.position.xyz / 10.0);
		storeNormal   (slot + 0u, v0.normal);
		storeUV       (slot + 0u, uv0);
		storeBinormal (slot + 0u, binormal0);
		storeTangent  (slot + 0u, tangent0);

		storePosition(slot + 1u, v1.position.xyz / 10.0);
		storeNormal   (slot + 1u, v1.normal);
		storeUV       (slot + 1u, uv1);
		storeBinormal (slot + 1u, binormal1);
		storeTangent  (slot + 1u, tangent1);

		storePosition(slot + 2u, v2.position.xyz / 10.0);
		storeNormal   (slot + 2u, v2.normal);
		storeUV       (slot + 2u, uv2);
		storeBinormal (slot + 2u, binormal2);
		storeTangent  (slot + 2u, tangent2);
	}
}
