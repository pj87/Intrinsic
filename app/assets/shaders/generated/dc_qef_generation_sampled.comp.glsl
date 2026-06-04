// Dual Contouring — Stage 1: QEF solve per voxel cell.
// For each cell with at least one sign-change edge, collects up to 12
// (intersection point, surface normal) pairs and minimises the Quadratic
// Error Function to find the optimal vertex position inside the cell.
// Output: _QEFVertices[cellIdx] = vec4(x, y, z, 1.0) for active cells,
//         vec4(0) for cells with no surface crossing.
#version 450

layout(binding = 0) buffer _VoxelBuffer  { float _Voxels[]; };
layout(binding = 1) buffer _QEFBuffer    { vec4  _QEFVertices[]; };
layout(binding = 2) buffer _SizesBuffer  { int _Width; int _Height; int _Depth; int _Border; };
layout(binding = 3) buffer _TargetBuffer { float _Target; };
layout(binding = 4) uniform sampler3D _NormalsTex;

int cellIndex(int x, int y, int z)
{
    x = clamp(x, 0, _Width  - 1);
    y = clamp(y, 0, _Height - 1);
    z = clamp(z, 0, _Depth  - 1);
    return x + y * _Width + z * _Width * _Height;
}

float sdf(int x, int y, int z) { return _Voxels[cellIndex(x, y, z)]; }

// Sample the precomputed normal texture at sub-voxel position p.
// Hardware trilinear interpolation — same quality as the MC shader, zero cost.
vec3 gradientAt(vec3 p)
{
    vec3 size = vec3(_Width - 1, _Height - 1, _Depth - 1);
    return textureLod(_NormalsTex, p / size, 0.0).xyz;
}

// Cell corner offsets for the 12 edges: each pair is (corner_a, corner_b).
const ivec3 CORNERS[8] = ivec3[8](
    ivec3(0,0,0), ivec3(1,0,0), ivec3(1,1,0), ivec3(0,1,0),
    ivec3(0,0,1), ivec3(1,0,1), ivec3(1,1,1), ivec3(0,1,1)
);
const int EDGE_A[12] = int[12](0,1,2,3, 4,5,6,7, 0,1,2,3);
const int EDGE_B[12] = int[12](1,2,3,0, 5,6,7,4, 4,5,6,7);

// Solve the 3×3 symmetric normal-equation system ATA·x = ATb.
// Returns the mass-point fallback if the matrix is nearly singular.
vec3 solveQEF(mat3 ATA, vec3 ATb, vec3 massPoint)
{
    float det = determinant(ATA);
    if (abs(det) < 1e-6) return massPoint;
    return inverse(ATA) * ATb;
}

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
void main()
{
    ivec3 id  = ivec3(gl_GlobalInvocationID);
    int   idx = id.x + id.y * _Width + id.z * _Width * _Height;

    _QEFVertices[idx] = vec4(0.0);

    if (id.x >= _Width  - 1 - _Border) return;
    if (id.y >= _Height - 1 - _Border) return;
    if (id.z >= _Depth  - 1 - _Border) return;

    // Fetch the 8 corner SDF values.
    float c[8];
    for (int i = 0; i < 8; i++)
        c[i] = sdf(id.x + CORNERS[i].x, id.y + CORNERS[i].y, id.z + CORNERS[i].z);

    // Accumulate QEF normal equations.
    mat3 ATA = mat3(0.0);
    vec3 ATb = vec3(0.0);
    vec3 massPoint = vec3(0.0);
    int  crossings = 0;

    for (int e = 0; e < 12; e++)
    {
        int a = EDGE_A[e], b = EDGE_B[e];
        bool aIn = (c[a] <= _Target);
        bool bIn = (c[b] <= _Target);
        if (aIn == bIn) continue;

        float delta = c[b] - c[a];
        float t = (abs(delta) < 1e-9) ? 0.5 : clamp((_Target - c[a]) / delta, 0.0, 1.0);

        vec3 pa = vec3(id) + vec3(CORNERS[a]);
        vec3 pb = vec3(id) + vec3(CORNERS[b]);
        vec3 p  = mix(pa, pb, t);
        vec3 n  = gradientAt(p);

        // ATA += outer(n, n), ATb += n * dot(n, p)
        ATA[0][0] += n.x*n.x; ATA[1][0] += n.y*n.x; ATA[2][0] += n.z*n.x;
        ATA[0][1] += n.x*n.y; ATA[1][1] += n.y*n.y; ATA[2][1] += n.z*n.y;
        ATA[0][2] += n.x*n.z; ATA[1][2] += n.y*n.z; ATA[2][2] += n.z*n.z;
        ATb += n * dot(n, p);

        massPoint += p;
        crossings++;
    }

    if (crossings == 0) return;

    massPoint /= float(crossings);
    vec3 x = solveQEF(ATA, ATb, massPoint);
    x = clamp(x, vec3(id), vec3(id) + vec3(1.0));

    _QEFVertices[idx] = vec4(x, 1.0);
}
