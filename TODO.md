# TODO

## Bump displacement — temple mesh

`app/assets/shaders/meshes/temple_ruins.comp.glsl`

The noise bump is live and visible. Two parameters may need further tuning:

- **Amplitude** (`0.3` in `ruins()`) — controls how far the isosurface is displaced
  in ruins-space units. At the 64³ grid with `mapScaled(p/4)`, each unit equals
  4 voxels. Current value displaces up to ±0.15 ruins units ≈ ±0.6 voxels.
  Raise toward `0.5` for more aggressive displacement; lower toward `0.1` for
  subtlety.

- **Frequency** (`p * 2.0` inside `noise3`) — controls the spatial scale of bumps.
  Higher multiplier = smaller, denser bumps. Consider exposing both as
  `param0`/`param1` in the procedural mesh JSON so they can be tuned without
  recompiling.

The bump changes (`temple_ruins.comp.glsl` + `texture_nrm_flat_generation.comp.glsl`)
are currently **uncommitted**. They should be committed and pushed once the values
are considered final.

---

## Normal map bumpiness — temple texture

`app/assets/shaders/textures/texture_nrm_flat_generation.comp.glsl`

The Sobel-based normal generation shader has a hardcoded `bumpness = 0.5`.
This controls the Z component of the generated normal (`Z = 1 / bumpness`):
lower value → steeper normals → more pronounced bumping.

- Current: `0.5` → `Z = 2` (16× more bumpy than the original `0.03125`)
- Consider making this a parameter passed via the `_ParametersBuffer`
  (`_Frequency`/`_Lacunarity`/`_Gain` slots) so it can be driven from the
  procedural texture JSON without a shader edit.

---

## Merge `normal_generation.comp` into the marching cubes shader

`app/assets/shaders/generated/normal_generation.comp.glsl`
`app/assets/shaders/generated/geometry_generation_new.comp.glsl`
`app/assets/shaders/generated/geometry_generation_full_tbn.comp.glsl`

Currently the pipeline is three stages: voxel SDF → normal generation → marching
cubes. The normal generation pass is a dedicated compute dispatch that reads the
flat `_VoxelBuffer` and writes per-voxel gradients into a 3D `rgba16f` texture
(`_NormalsTex`). The marching cubes shader then samples this texture via
`textureLod(_NormalsTex, uv, 0)` to get hardware-interpolated normals at each
vertex's fractional edge position.

**Goal:** collapse stages 2 and 3 into a single shader, eliminating one dispatch
and one 3D texture allocation per procedural mesh.

**The key obstacle:** hardware trilinear interpolation. The marching cubes vertex
sits at a sub-voxel position (the edge-interpolated point between two voxel
corners). Sampling `_NormalsTex` gives a smoothly blended normal for free. Without
the texture, this must be replicated manually:

```glsl
// Replace: vert.normal = textureLod(_NormalsTex, uv, 0).xyz;
// With: trilinearly interpolated SDF gradient from _Voxels[]

vec3 sdfGradient(vec3 p) {
    // central differences at fractional position p
    float eps = 0.5;
    return normalize(vec3(
        sampleTrilinear(p + vec3(eps,0,0)) - sampleTrilinear(p - vec3(eps,0,0)),
        sampleTrilinear(p + vec3(0,eps,0)) - sampleTrilinear(p - vec3(0,eps,0)),
        sampleTrilinear(p + vec3(0,0,eps)) - sampleTrilinear(p - vec3(0,0,eps))
    ));
}

float sampleTrilinear(vec3 p) {
    ivec3 i = ivec3(floor(p));
    vec3  f = fract(p);
    // 8 corner reads + lerp
    ...
}
```

This replaces 1 texture sample with ~24 buffer reads (8 corners × 3 axes for
central differences). The extra cost is only paid for surface voxels (those that
pass the `edgeFlags != 0` early-out), so the practical overhead depends on surface
area, not total grid size.

**Benefits if done:**
- One fewer compute dispatch per procedural mesh per frame
- One fewer 3D rgba16f texture per mesh (saves ~6 MB at 64³ resolution)
- Potentially better normal quality — gradient computed at the actual surface
  position rather than snapped to voxel centres
- Simpler pipeline (two stages instead of three)

**Affected files:**
- `geometry_generation_new.comp.glsl` — replace `_NormalsTex` sampler with inline gradient
- `geometry_generation_full_tbn.comp.glsl` — same
- `IntrinsicRendererRenderPassDynamicMeshGeneration.cpp` — remove stage 2 dispatch
  and the `_normalsImageRef` allocation/binding
- `IntrinsicRendererRenderPassDynamicMeshGeneration.h` — remove `_normalsImageRef`
  from `DynamicGeneratedMesh`
- Procedural mesh JSON files — `normalShader` field becomes obsolete; remove it
