// Dual Contouring — Stage 2: quad emission.
// Each cell owns its +X, +Y and +Z edges. For each owned edge with a sign
// change, the four cells sharing that edge contribute their QEF vertices to
// form a quad (two triangles).  Each cell reserves 18 output vertex slots
// (3 edges × 6 vertices).  Inactive edges leave their slots zeroed so the
// GPU clips the resulting degenerate triangles.
//
// Output vertex layout is identical to geometry_generation_new.comp.glsl:
// packed half-float positions/normals/tangents/binormals, one uint per UV.
#version 450

layout(binding = 0) buffer _PositionBuffer  { uint _Positions[]; };
layout(binding = 1) buffer _NormalBuffer    { uint _Normals[]; };
layout(binding = 2) buffer _TangentBuffer   { uint _Tangents[]; };
layout(binding = 3) buffer _BinormalBuffer  { uint _Binormals[]; };
layout(binding = 4) buffer _Uv0Buffer       { uint _UV0s[]; };
layout(binding = 5) buffer _ColorBuffer     { uint _Colors[]; };
layout(binding = 6) buffer _QEFBuffer       { vec4 _QEFVertices[]; };
layout(binding = 7) buffer _VoxelBuffer     { float _Voxels[]; };
layout(binding = 8) uniform sampler3D _NormalsTex;
layout(binding = 9) buffer _SizesBuffer     { int _Width; int _Height; int _Depth; int _Border; };
layout(binding = 10) buffer _TargetBuffer   { float _Target; };

// ---- Same half-float packing helpers as geometry_generation_new.comp.glsl ----
// Separate store functions per buffer — GLSL does not allow passing storage
// buffer arrays by reference.
void storePosition(uint i, vec3 p) {
    if (i % 2u == 0u) {
        uint idx = i + i / 2u;
        _Positions[idx]     = packHalf2x16(p.xy);
        vec2 tmp = unpackHalf2x16(_Positions[idx + 1u]);
        _Positions[idx + 1u] = packHalf2x16(vec2(p.z, tmp.y));
    } else {
        uint idx = i + (i - 1u) / 2u;
        vec2 tmp = unpackHalf2x16(_Positions[idx]);
        _Positions[idx]      = packHalf2x16(vec2(tmp.x, p.x));
        _Positions[idx + 1u] = packHalf2x16(p.yz);
    }
}
void storeNormal(uint i, vec3 n) {
    if (i % 2u == 0u) {
        uint idx = i + i / 2u;
        _Normals[idx]     = packHalf2x16(n.xy);
        vec2 tmp = unpackHalf2x16(_Normals[idx + 1u]);
        _Normals[idx + 1u] = packHalf2x16(vec2(n.z, tmp.y));
    } else {
        uint idx = i + (i - 1u) / 2u;
        vec2 tmp = unpackHalf2x16(_Normals[idx]);
        _Normals[idx]      = packHalf2x16(vec2(tmp.x, n.x));
        _Normals[idx + 1u] = packHalf2x16(n.yz);
    }
}
void storeTangent(uint i, vec3 t) {
    if (i % 2u == 0u) {
        uint idx = i + i / 2u;
        _Tangents[idx]     = packHalf2x16(t.xy);
        vec2 tmp = unpackHalf2x16(_Tangents[idx + 1u]);
        _Tangents[idx + 1u] = packHalf2x16(vec2(t.z, tmp.y));
    } else {
        uint idx = i + (i - 1u) / 2u;
        vec2 tmp = unpackHalf2x16(_Tangents[idx]);
        _Tangents[idx]      = packHalf2x16(vec2(tmp.x, t.x));
        _Tangents[idx + 1u] = packHalf2x16(t.yz);
    }
}
void storeBinormal(uint i, vec3 b) {
    if (i % 2u == 0u) {
        uint idx = i + i / 2u;
        _Binormals[idx]     = packHalf2x16(b.xy);
        vec2 tmp = unpackHalf2x16(_Binormals[idx + 1u]);
        _Binormals[idx + 1u] = packHalf2x16(vec2(b.z, tmp.y));
    } else {
        uint idx = i + (i - 1u) / 2u;
        vec2 tmp = unpackHalf2x16(_Binormals[idx]);
        _Binormals[idx]      = packHalf2x16(vec2(tmp.x, b.x));
        _Binormals[idx + 1u] = packHalf2x16(b.yz);
    }
}
void storeUV(uint i, vec2 uv) { _UV0s[i] = packHalf2x16(uv); }

// ---- Helpers ----------------------------------------------------------------

int cellIndex(int x, int y, int z)
{
    x = clamp(x, 0, _Width  - 1);
    y = clamp(y, 0, _Height - 1);
    z = clamp(z, 0, _Depth  - 1);
    return x + y * _Width + z * _Width * _Height;
}

float voxelAt(int x, int y, int z) { return _Voxels[cellIndex(x, y, z)]; }

vec3 normalAt(vec3 pos, vec3 size)
{
    return textureLod(_NormalsTex, pos / size, 0.0).xyz;
}

// Emit one triangle into 3 consecutive vertex slots starting at baseSlot.
void emitTri(uint s, vec3 p0, vec3 p1, vec3 p2,
             vec3 n0, vec3 n1, vec3 n2,
             vec3 centre, vec3 size)
{
    vec3 t = normalize(p1 - p0 + vec3(1e-9));
    vec3 b = normalize(cross(p0, t));

    storePosition(s,     (p0 - centre) / 10.0);
    storePosition(s + 1u,(p1 - centre) / 10.0);
    storePosition(s + 2u,(p2 - centre) / 10.0);
    storeNormal  (s,     n0); storeNormal  (s + 1u, n1); storeNormal  (s + 2u, n2);
    storeTangent (s,     t);  storeTangent (s + 1u, t);  storeTangent (s + 2u, t);
    storeBinormal(s,     b);  storeBinormal(s + 1u, b);  storeBinormal(s + 2u, b);
    storeUV(s,     p0.xy / size.xy);
    storeUV(s + 1u,p1.xy / size.xy);
    storeUV(s + 2u,p2.xy / size.xy);
}

// Emit a quad as two triangles into slots [base, base+6).
// Vertices p0..p3 are in CCW order when viewed from outside.
// flip = true reverses winding (inside→outside sign is reversed).
void emitQuad(uint base,
              vec3 p0, vec3 p1, vec3 p2, vec3 p3,
              vec3 n0, vec3 n1, vec3 n2, vec3 n3,
              bool flip, vec3 centre, vec3 size)
{
    if (!flip) {
        emitTri(base,      p0, p1, p2, n0, n1, n2, centre, size);
        emitTri(base + 3u, p0, p2, p3, n0, n2, n3, centre, size);
    } else {
        emitTri(base,      p0, p2, p1, n0, n2, n1, centre, size);
        emitTri(base + 3u, p0, p3, p2, n0, n3, n2, centre, size);
    }
}

// ---- Main -------------------------------------------------------------------

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
void main()
{
    ivec3 id = ivec3(gl_GlobalInvocationID);

    vec3 size   = vec3(_Width - 1, _Height - 1, _Depth - 1);
    vec3 centre = vec3(_Width, 0, _Depth) / 2.0;

    uint cellIdx = uint(id.x + id.y * _Width + id.z * _Width * _Height);
    uint base    = cellIdx * 18u;   // 3 edges × 6 vertices = 18 slots per cell

    // Clear all 18 slots so unused slots produce degenerate (zero-area) triangles.
    for (uint i = 0u; i < 18u; i++) storePosition(base + i, vec3(0.0));

    if (id.x >= _Width  - 1 - _Border) return;
    if (id.y >= _Height - 1 - _Border) return;
    if (id.z >= _Depth  - 1 - _Border) return;

    float v000 = voxelAt(id.x,     id.y,     id.z    );
    float v100 = voxelAt(id.x + 1, id.y,     id.z    );
    float v010 = voxelAt(id.x,     id.y + 1, id.z    );
    float v001 = voxelAt(id.x,     id.y,     id.z + 1);

    uint edgeBase = 0u;

    // ---- Edge +X: (id) → (id+1,0,0) ----------------------------------------
    // Shared by cells (x,y,z), (x,y-1,z), (x,y-1,z-1), (x,y,z-1)
    if ((v000 <= _Target) != (v100 <= _Target))
    {
        int ay = id.y - 1, az = id.z - 1;
        if (ay >= 0 && az >= 0)
        {
            vec4 q0 = _QEFVertices[cellIndex(id.x, id.y,  id.z )];
            vec4 q1 = _QEFVertices[cellIndex(id.x, ay,    id.z )];
            vec4 q2 = _QEFVertices[cellIndex(id.x, ay,    az   )];
            vec4 q3 = _QEFVertices[cellIndex(id.x, id.y,  az   )];
            if (q0.w > 0.5 && q1.w > 0.5 && q2.w > 0.5 && q3.w > 0.5)
            {
                vec3 n0 = normalAt(q0.xyz, size), n1 = normalAt(q1.xyz, size);
                vec3 n2 = normalAt(q2.xyz, size), n3 = normalAt(q3.xyz, size);
                // flip when the low-x side is solid (surface normal faces -X)
                emitQuad(base + edgeBase,
                         q0.xyz, q1.xyz, q2.xyz, q3.xyz,
                         n0, n1, n2, n3,
                         (v000 <= _Target), centre, size);
            }
        }
        edgeBase += 6u;
    }

    // ---- Edge +Y: (id) → (id,+1,0) ------------------------------------------
    // Shared by cells (x,y,z), (x-1,y,z), (x-1,y,z-1), (x,y,z-1)
    if ((v000 <= _Target) != (v010 <= _Target))
    {
        int ax = id.x - 1, az = id.z - 1;
        if (ax >= 0 && az >= 0)
        {
            vec4 q0 = _QEFVertices[cellIndex(id.x, id.y, id.z )];
            vec4 q1 = _QEFVertices[cellIndex(ax,   id.y, id.z )];
            vec4 q2 = _QEFVertices[cellIndex(ax,   id.y, az   )];
            vec4 q3 = _QEFVertices[cellIndex(id.x, id.y, az   )];
            if (q0.w > 0.5 && q1.w > 0.5 && q2.w > 0.5 && q3.w > 0.5)
            {
                vec3 n0 = normalAt(q0.xyz, size), n1 = normalAt(q1.xyz, size);
                vec3 n2 = normalAt(q2.xyz, size), n3 = normalAt(q3.xyz, size);
                // flip when the low-y side is outside
                emitQuad(base + edgeBase,
                         q0.xyz, q1.xyz, q2.xyz, q3.xyz,
                         n0, n1, n2, n3,
                         (v000 > _Target), centre, size);
            }
        }
        edgeBase += 6u;
    }

    // ---- Edge +Z: (id) → (id,0,+1) ------------------------------------------
    // Shared by cells (x,y,z), (x-1,y,z), (x-1,y-1,z), (x,y-1,z)
    if ((v000 <= _Target) != (v001 <= _Target))
    {
        int ax = id.x - 1, ay = id.y - 1;
        if (ax >= 0 && ay >= 0)
        {
            vec4 q0 = _QEFVertices[cellIndex(id.x, id.y, id.z)];
            vec4 q1 = _QEFVertices[cellIndex(ax,   id.y, id.z)];
            vec4 q2 = _QEFVertices[cellIndex(ax,   ay,   id.z)];
            vec4 q3 = _QEFVertices[cellIndex(id.x, ay,   id.z)];
            if (q0.w > 0.5 && q1.w > 0.5 && q2.w > 0.5 && q3.w > 0.5)
            {
                vec3 n0 = normalAt(q0.xyz, size), n1 = normalAt(q1.xyz, size);
                vec3 n2 = normalAt(q2.xyz, size), n3 = normalAt(q3.xyz, size);
                // flip when the low-z side is solid (surface normal faces -Z)
                emitQuad(base + edgeBase,
                         q0.xyz, q1.xyz, q2.xyz, q3.xyz,
                         n0, n1, n2, n3,
                         (v000 <= _Target), centre, size);
            }
        }
    }
}
