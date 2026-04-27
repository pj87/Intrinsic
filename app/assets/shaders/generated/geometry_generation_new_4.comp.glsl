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

struct Debug
{
	vec4 debug1;
	vec4 debug2;
};

layout(binding = 0) buffer _PositionBuffer
{
	uint _Positions[];
};
layout(binding = 1) buffer _NormalBuffer
{
	uint _Normals[];
};
layout(binding = 2) buffer _TangentBuffer
{
	uint _Tangents[];
};
layout(binding = 3) buffer _BinormalBuffer
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
layout(binding = 9) buffer _DebugBuffer
{
	Debug _DebugTuple[];
};
layout(binding = 10) uniform sampler3D _NormalsTex;
layout(binding = 11) buffer _SizesBuffer
{	
	int _Width;
	int _Height;
	int _Depth;
	int _Border;
};
layout(binding = 12) buffer _TargetBuffer
{	
	float _Target;
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

	vec3 uv = position / size;
	vert.normal = textureLod(_NormalsTex, uv, 0).xyz;

	return vert;
}

uint convert(vec2 pos0, vec2 pos1)
{
	return(packHalf2x16(pos0) << 16 | packHalf2x16(pos1));
}

void storePosition(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Positions[index] = packHalf2x16(pos1.xy);
		vec2 tmp = unpackHalf2x16(_Positions[index + 1]);
		_Positions[index + 1] = packHalf2x16(vec2(pos1.z, tmp.y));
	}
	else
	{	
		uint index = i + (i - 1) / 2;
		vec2 tmp = unpackHalf2x16(_Positions[index]);
		_Positions[index] = packHalf2x16(vec2(tmp.x, pos1.x));
		_Positions[index + 1] = packHalf2x16(vec2(pos1.y, pos1.z));
	}
}

void storeNormal(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Normals[index] = packHalf2x16(pos1.xy);
		vec2 tmp = unpackHalf2x16(_Normals[index + 1]);
		_Normals[index + 1] = packHalf2x16(vec2(pos1.z, tmp.y));
	}
	else
	{	
		uint index = i + (i - 1) / 2;
		vec2 tmp = unpackHalf2x16(_Normals[index]);
		_Normals[index] = packHalf2x16(vec2(tmp.x, pos1.x));
		_Normals[index + 1] = packHalf2x16(vec2(pos1.y, pos1.z));
	}
}

void storeBinormal(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Binormals[index] = packHalf2x16(pos1.xy);
		vec2 tmp = unpackHalf2x16(_Binormals[index + 1]);
		_Binormals[index + 1] = packHalf2x16(vec2(pos1.z, tmp.y));
	}
	else
	{	
		uint index = i + (i - 1) / 2;
		vec2 tmp = unpackHalf2x16(_Binormals[index]);
		_Binormals[index] = packHalf2x16(vec2(tmp.x, pos1.x));
		_Binormals[index + 1] = packHalf2x16(vec2(pos1.y, pos1.z));
	}
}

void storeTangent(uint i, vec3 pos1)
{
	if (i % 2 == 0)
	{
		uint index = i + i / 2;
		_Tangents[index] = packHalf2x16(pos1.xy);
		vec2 tmp = unpackHalf2x16(_Tangents[index + 1]);
		_Tangents[index + 1] = packHalf2x16(vec2(pos1.z, tmp.y));
	}
	else
	{	
		uint index = i + (i - 1) / 2;
		vec2 tmp = unpackHalf2x16(_Tangents[index]);
		_Tangents[index] = packHalf2x16(vec2(tmp.x, pos1.x));
		_Tangents[index + 1] = packHalf2x16(vec2(pos1.y, pos1.z));
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
				
layout(local_size_x = 4u, local_size_y = 4u, local_size_z = 4u) in;
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

	for (int i = 0; i < 15; i++) {
		storePosition(idx * 15 + i, vec3(0.0));
	}

	vec3 pos = vec3(id);
	vec3 centre = vec3(_Width, 0, _Depth) / 2.0;

	float cube[8];
	FillCube(id.x, id.y, id.z, cube);

	int i = 0;
	int flagIndex = 0;
	vec3 edgeVertex[12];

	//Find which vertices are inside of the surface and which are outside
	for (i = 0; i < 8; i++)
	{
		_DebugTuple[idx].debug1 = vec4(cube[0], cube[1], cube[2], cube[3]);
		_DebugTuple[idx].debug2 = vec4(cube[4], cube[5], cube[6], cube[7]);
		if (cube[i] <= _Target) flagIndex |= 1 << i;
	}

	//Find which edges are intersected by the surface
	int edgeFlags = _CubeEdgeFlags[flagIndex];
	
	// no connections, return
	if (edgeFlags == 0) return;
	
	//Find the point of intersection of the surface with each edge
	for (i = 0; i < 12; i++)
	{
		//if there is an intersection on this edge
		if ((edgeFlags & (1 << i)) != 0)
		{
			float offset = GetOffset(cube[edgeConnection[i].x], cube[edgeConnection[i].y]);

			edgeVertex[i] = pos + (vertexOffset[edgeConnection[i].x] + offset * edgeDirection[i]);
		}
	}

	vec3 size = vec3(_Width - 1, _Height - 1, _Depth - 1);
	
	//Save the triangles that were found. There can be up to five per cube
	for (i = 0; i < 5; i++)
	{
		vec3 position;
		vec2 uvX;
		vec2 uvY;
		vec2 uvZ;
		vec2 uv;
		
		//If the connection table is not -1 then this a triangle.
		if (_TriangleConnectionTable[flagIndex * 16 + 3 * i] >= 0)
		{	
			//packHalf2x16
			vec4 color = vec4(sin(id.x / 10.0), cos(id.y / 10.0), sin(id.z / 10.0), 1.0);
			position = edgeVertex[_TriangleConnectionTable[flagIndex * 16 + (3 * i + 0)]];
			Vert v0 = CreateVertex(position, centre, size);
			uvX = clamp((v0.position.yz + _Width / 2.0) / _Width, vec2(0.0), vec2(1.0));
			uvY = clamp((v0.position.xz + _Height / 2.0) / _Height, vec2(0.0), vec2(1.0));
			uvZ = clamp((v0.position.xy + _Depth / 2.0) / _Depth, vec2(0.0), vec2(1.0));
			uv = mix(uvX, uvZ, abs(v0.normal.z));
			uv = mix(uv, uvY, abs(v0.normal.y));
			storePosition(idx * 15 + (3 * i + 0), v0.position.xyz / 10.0);
			storeNormal(idx * 15 + (3 * i + 0), v0.normal);
			//storeColor(idx * 15 + (3 * i + 0), vec4(0.2 * sin(v0.position.xyz), 1.0));
			storeUV(idx * 15 + (3 * i + 0), uv);
			
			position = edgeVertex[_TriangleConnectionTable[flagIndex * 16 + (3 * i + 1)]];
			Vert v1 = CreateVertex(position, centre, size);
			uvX = clamp((v1.position.yz + _Width / 2.0) / _Width, vec2(0.0), vec2(1.0));
			uvY = clamp((v1.position.xz + _Height / 2.0) / _Height, vec2(0.0), vec2(1.0));
			uvZ = clamp((v1.position.xy + _Depth / 2.0) / _Depth, vec2(0.0), vec2(1.0));
			uv = mix(uvX, uvZ, abs(v1.normal.z));
			uv = mix(uv, uvY, abs(v1.normal.y));
			storePosition(idx * 15 + (3 * i + 1), v1.position.xyz / 10.0);
			storeNormal(idx * 15 + (3 * i + 1), v1.normal);
			//storeColor(idx * 15 + (3 * i + 1), vec4(0.2 * sin(v1.position.xyz), 1.0));
			storeUV(idx * 15 + (3 * i + 1), uv);
			
			position = edgeVertex[_TriangleConnectionTable[flagIndex * 16 + (3 * i + 2)]];
			Vert v2 = CreateVertex(position, centre, size);
			uvX = clamp((v2.position.yz + _Width / 2.0) / _Width, vec2(0.0), vec2(1.0));
			uvY = clamp((v2.position.xz + _Height / 2.0) / _Height, vec2(0.0), vec2(1.0));
			uvZ = clamp((v2.position.xy + _Depth / 2.0) / _Depth, vec2(0.0), vec2(1.0));
			uv = mix(uvX, uvZ, abs(v2.normal.z));
			uv = mix(uv, uvY, abs(v2.normal.y));
			storePosition(idx * 15 + (3 * i + 2), v2.position.xyz / 10.0);
			storeNormal(idx * 15 + (3 * i + 2), v2.normal);
			//storeColor(idx * 15 + (3 * i + 2), vec4(0.2 * sin(v2.position.xyz), 1.0));
			storeUV(idx * 15 + (3 * i + 2), uv);
			
			vec3 tangent0 = normalize(v0.position.xyz - v2.position.xyz);
			vec3 tangent1 = normalize(v1.position.xyz - v2.position.xyz);
			vec3 tangent2 = normalize(v1.position.xyz - v0.position.xyz);
			
			vec3 binormal0 = normalize(cross(v0.position.xyz, tangent0));
			vec3 binormal1 = normalize(cross(v1.position.xyz, tangent1));
			vec3 binormal2 = normalize(cross(v2.position.xyz, tangent2));
			
			storeBinormal(idx * 15 + (3 * i + 0), binormal0);
			storeTangent(idx * 15 + (3 * i + 0), tangent0);
			//storeUV(idx * 15 + (3 * i + 0), CreateVertex(position, centre, size).normal);
			
			storeBinormal(idx * 15 + (3 * i + 1), binormal1);
			storeTangent(idx * 15 + (3 * i + 1), tangent1);
			//storeUV(idx * 15 + (3 * i + 1), CreateVertex(position, centre, size).normal);
			
			storeBinormal(idx * 15 + (3 * i + 2), binormal2);
			storeTangent(idx * 15 + (3 * i + 2), tangent2);
			//storeUV(idx * 15 + (3 * i + 2), CreateVertex(position, centre, size).normal);
		}
	}
}
