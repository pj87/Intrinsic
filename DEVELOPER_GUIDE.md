# Intrinsic Engine — Developer Guide

Practical reference for day-to-day work with the engine. Assumes the project
builds and runs. See `README.md` / `GETTING_STARTED.md` for initial setup.

---

## Table of Contents

1. [Project Layout](#1-project-layout)
2. [Build & Run](#2-build--run)
3. [World & Entity System](#3-world--entity-system)
4. [Components Reference](#4-components-reference)
5. [Material System](#5-material-system)
6. [Shader System](#6-shader-system)
7. [Render Passes](#7-render-passes)
   - 7.1 [Frame execution flow](#71-frame-execution-flow)
   - 7.2 [Resource creation patterns](#72-resource-creation-patterns)
   - 7.3 [The two dispatch patterns](#73-the-two-dispatch-patterns)
   - 7.4 [Adding a render pass: complete walkthrough](#74-adding-a-render-pass-complete-walkthrough)
   - 7.5 [Image memory barriers — rules](#75-image-memory-barriers--rules)
   - 7.6 [Accessing a render target from another pass](#76-accessing-a-render-target-from-another-pass)
8. [Shadows & Volumetric Lighting](#8-shadows--volumetric-lighting)
   - 8.1 [Shadow system overview](#81-shadow-system-overview)
   - 8.2 [Frame order](#82-frame-order-for-shadows-and-volumetric-lighting)
   - 8.3 [PSSM cascade setup](#83-pssm-cascade-setup)
   - 8.4 [Shadow rendering pass](#84-shadow-rendering-pass)
   - 8.5 [ESM generation](#85-esm-exponential-shadow-map-generation)
   - 8.6 [Shadow sampling](#86-shadow-sampling-at-runtime)
   - 8.7 [Volumetric lighting architecture](#87-volumetric-lighting-architecture)
   - 8.8 [Accumulation compute](#88-accumulation-compute--volumetric_lightingcompglsl)
   - 8.9 [Scattering compute](#89-scattering-compute--volumetric_lighting_scatteringcompglsl)
   - 8.10 [Applying in lighting pass](#810-applying-volumetric-lighting-in-the-lighting-pass)
   - 8.11 [Tuning parameters](#811-tuning-shadows-and-volumetric-fog)
   - 8.12 [Custom fog / shadow casters](#812-adding-a-custom-fog-volume-or-shadow-caster)
9. [Camera & Frustum System](#9-camera--frustum-system)
   - 9.1 [Data model](#91-data-model)
   - 9.2 [CameraComponent properties](#92-cameracomponent-properties)
   - 9.3 [Matrix update](#93-matrix-update--cameramanagerupdatefrustumsandmatrices)
   - 9.4 [FrustumManager::prepareForRendering](#94-frustummanagerprepareforrendering)
   - 9.5 [FrustumData fields](#95-frustumdata--all-stored-matrices-and-planes)
   - 9.6 [Frustum planes and corners](#96-frustum-planes)
   - 9.7 [Frustum culling](#97-frustum-culling--frustummanagercullnodes)
   - 9.8 [Active camera](#98-active-camera)
   - 9.9 [CameraController component](#99-cameracontroller-component)
   - 9.10 [Custom projection matrix](#910-custom-projection-matrix)
10. [GPU Resource Reference](#10-gpu-resource-reference)
    - 10.1 [Buffer](#101-buffer)
    - 10.2 [GpuProgram (shader)](#102-gpuprogram-shader)
    - 10.3 [PipelineLayout](#103-pipelinelayout)
    - 10.4 [Pipeline](#104-pipeline)
    - 10.5 [RenderPass](#105-renderpass)
    - 10.6 [Framebuffer](#106-framebuffer)
    - 10.7 [DrawCall](#107-drawcall)
    - 10.8 [ComputeCall](#108-computecall)
    - 10.9 [Dependency graph](#109-dependency-graph--who-owns-what)
11. [Example: Forward Transparent Pass](#11-example-forward-transparent-pass)
12. [Example: Ray Tracing Pass](#12-example-ray-tracing-pass)
13. [Asset Pipeline](#13-asset-pipeline)
14. [Lua Scripting](#14-lua-scripting)
15. [Procedural Systems](#15-procedural-systems)
16. [Physics](#16-physics)
17. [Debugging & Profiling](#17-debugging--profiling)
18. [Common Recipes](#18-common-recipes)

---

## 1. Project Layout

```
Intrinsic/
├── IntrinsicCore/          # Engine core: ECS, world, input, physics, scripting
│   └── src/
├── IntrinsicRenderer/      # Vulkan renderer: all render passes, GPU resources
│   └── src/
├── IntrinsicEd/            # Qt5 editor (Windows only)
│   └── src/
├── IntrinsicAssetManagement/  # FBX importer, texture processor
│   └── src/
├── Intrinsic/              # Standalone game entry point (main.cpp + game states)
│   └── src/
├── app/
│   ├── assets/
│   │   └── shaders/        # All GLSL shader source files
│   ├── config/
│   │   ├── renderer_config.json       # Images, framebuffers, render pass graph
│   │   └── material_pass_config.json  # Material pass definitions
│   ├── managers/
│   │   ├── materials/      # *.material.json
│   │   ├── meshes/         # *.mesh.json
│   │   ├── gpu_programs/   # *.gpu_program.json
│   │   ├── images/         # *.image.json
│   │   └── scripts/        # *.script.json
│   ├── scripts/            # Lua scripts
│   ├── worlds/             # *.world.json
│   └── settings.json
├── cmake/                  # FindXxx.cmake modules
└── dependencies/           # Vendored third-party libs (GLM, RapidJSON, etc.)
```

### Key source file naming

| Prefix | Meaning |
|--------|---------|
| `IntrinsicCore*` | Core engine (no renderer dependency) |
| `IntrinsicRenderer*` | Renderer (Vulkan, GPU resources) |
| `IntrinsicRendererRenderPass*` | A specific render pass |
| `IntrinsicRendererResources*` | A GPU resource manager (Image, Buffer, Pipeline, …) |
| `CComponents::` / `CResources::` | Core component / resource namespace |
| `RResources::` | Renderer resource namespace |

---

## 2. Build & Run

### CMake configuration

```bash
mkdir build && cd build
cmake .. -G "Visual Studio 17 2022" -A x64
```

Useful CMake options:

| Option | Default | Purpose |
|--------|---------|---------|
| `INTR_BUILD_STANDALONE_APP` | ON | Build `Intrinsic.exe` |
| `INTR_BUILD_INTRINSICED` | ON | Build `IntrinsicEd.exe` (requires Qt5) |
| `INTR_USE_MICROPROFILE` | ON | Enable GPU/CPU profiler (Windows only) |
| `INTR_FINAL_BUILD` | OFF | Strip editor code, enable full optimizations |

### Runtime working directory

Both executables expect the working directory to be `app/`. Either set it in the
VS project properties or launch from there:

```
cd app
../build/Release/Intrinsic.exe
```

### Settings

`app/settings.json` controls startup behaviour:

```json
{
  "initialGameState": "Editing",   // "Main" for game, "Editing" for editor
  "rendererConfig": "renderer_config.json",
  "startupWorld": "Default"
}
```

---

## 3. World & Entity System

### Architecture

Entities are just a **name**. All data lives in **components**. Every component
has a corresponding `*Manager` static class that holds all instances in flat
parallel arrays (Structure of Arrays — cache-friendly). References to components
are 32-bit generational handles (`Ref` = 24-bit index + 8-bit generation counter)
that automatically invalidate after the component is destroyed.

### World files

Worlds are stored as JSON arrays in `app/worlds/`. Each element is one node:

```json
[
  {
    "name": "MyObject",
    "offsetToParent": -1,
    "propertyEntries": [
      {
        "type": "Node",
        "properties": {
          "localPos": [0.0, 0.0, 0.0],
          "localOrient": [0.0, 0.0, 0.0, 1.0],
          "localSize": [1.0, 1.0, 1.0]
        }
      },
      {
        "type": "Mesh",
        "properties": {
          "meshName": "my_mesh",
          "materialName": "my_material"
        }
      }
    ]
  }
]
```

`offsetToParent` is the index offset from the current element to its parent
(-1 means root). Children must appear after their parent in the array.

### Loading / saving worlds in code

```cpp
// Load
World::loadWorld("Default");          // loads app/worlds/Default.world.json

// Save (editor)
World::saveWorld("Default");

// Create entity at runtime
Entity::EntityRef entity = Entity::EntityManager::createEntity(Name("MyThing"));
NodeRef node = NodeManager::createComponent(entity);
NodeManager::setPosition(node, glm::vec3(0, 10, 0));
NodeManager::rebuildTreeAndUpdateTransforms();
```

### Entity lookup

```cpp
Entity::EntityRef ref = Entity::EntityManager::getEntityByName(Name("MyThing"));
NodeRef node = NodeManager::getComponentForEntity(ref);
MeshRef mesh = MeshManager::getComponentForEntity(ref);   // may be invalid
```

Always validate before use:
```cpp
if (!node.isValid()) { /* entity has no Node component */ }
```

### Transform helpers (NodeManager)

```cpp
NodeManager::getPosition(nodeRef);           // world position
NodeManager::getWorldTransform(nodeRef);     // glm::mat4
NodeManager::setPosition(nodeRef, pos);
NodeManager::setOrientation(nodeRef, quat);
NodeManager::setSize(nodeRef, scale);
NodeManager::rebuildTreeAndUpdateTransforms();  // must call after bulk changes
```

### Parenting

```cpp
// In world JSON: set offsetToParent
// In code:
NodeManager::attachChild(parentRef, childRef);
NodeManager::detachChild(parentRef, childRef);
```

---

## 4. Components Reference

### Node

Every entity in the scene must have a Node component. It stores the spatial
transform and connects the entity into the scene hierarchy.

| Property | Type | Description |
|----------|------|-------------|
| `localPos` | vec3 | Local position relative to parent |
| `localOrient` | quat (xyzw) | Local rotation |
| `localSize` | vec3 | Local scale |
| `visibilityMask` | uint32 | Bitmask for visibility culling |

Key constants: `NodeManager::_maxNodeCount = 10240`

### Mesh

Attaches renderable geometry to a node. The mesh asset and material are looked
up by name at load time.

| Property | Type | Description |
|----------|------|-------------|
| `meshName` | string | Filename stem in `app/managers/meshes/` |
| `materialName` | string | Filename stem in `app/managers/materials/` |

Changing the mesh at runtime:
```cpp
MeshManager::setMeshName(meshRef, Name("new_mesh"));
MeshManager::updateMeshData(meshRef);  // reloads vertex/index data
```

### Camera

```json
{
  "type": "Camera",
  "properties": {
    "fov": 60.0,
    "nearPlane": 0.1,
    "farPlane": 5000.0
  }
}
```

The active camera is set by `World::setActiveCamera(cameraRef)`. The renderer
reads it each frame from `World::getActiveCamera()`.

### Light

```json
{
  "type": "Light",
  "properties": {
    "lightType": 0,
    "color": [1.0, 0.95, 0.8],
    "intensity": 100.0,
    "radius": 20.0
  }
}
```

| `lightType` | Meaning |
|-------------|---------|
| 0 | Point light |
| 1 | Directional (sun) |

The directional light direction is derived from the node's orientation.

### Decal

Projected decal. Requires the decal render pass to be active.

```json
{
  "type": "Decal",
  "properties": {
    "materialName": "decal_material",
    "thickness": 1.0
  }
}
```

### RigidBody

```json
{
  "type": "RigidBody",
  "properties": {
    "rigidBodyType": 0,
    "mass": 1.0,
    "shapeType": 1
  }
}
```

| `rigidBodyType` | Meaning |
|-----------------|---------|
| 0 | Static |
| 1 | Dynamic |
| 2 | Kinematic |

| `shapeType` | Meaning |
|-------------|---------|
| 0 | Sphere |
| 1 | Box (uses node scale) |
| 2 | Capsule |
| 3 | Convex hull (from mesh) |

### Script

```json
{
  "type": "Script",
  "properties": {
    "scriptName": "camera"
  }
}
```

References a file in `app/managers/scripts/` which points to a Lua file in
`app/scripts/`. See [Section 9](#9-lua-scripting).

### IrradianceProbe / SpecularProbe

Baked IBL probes. Place them in the scene and bake from the editor
(`Renderer → Bake Irradiance Probes`). Probe data is stored alongside the
world file.

```json
{
  "type": "IrradianceProbe",
  "properties": {
    "radius": 50.0,
    "priority": 0
  }
}
```

### PostEffectVolume

Overrides global post-processing parameters within a volume.

```json
{
  "type": "PostEffectVolume",
  "properties": {
    "postEffectName": "my_post_effect",
    "blendRange": 5.0
  }
}
```

---

## 5. Material System

### Material JSON file

Located in `app/managers/materials/`, one file per material:

```json
{
  "name": "my_material",
  "albedoTextureName": "my_albedo",
  "normalTextureName": "my_normal",
  "pbrTextureName": "my_pbr",
  "emissiveTextureName": "",
  "emissiveIntensity": 0.0,
  "roughnessBias": 0.0,
  "metallicBias": 0.0,
  "specularBias": 0.0,
  "uvOffsetScale": [0.0, 0.0, 1.0, 1.0],
  "uvAnimation": [0.0, 0.0],
  "translucencyThickness": 0.0,
  "materialPassMask": 3
}
```

### Texture packing convention

The PBR texture (`*_pbr`) packs three channels:

| Channel | Data |
|---------|------|
| R | Metallic |
| G | Roughness |
| B | Ambient Occlusion |

This is the standard metallic-roughness workflow (same as glTF).

### `materialPassMask`

Bitmask that selects which render passes consume this material:

| Bit | Pass |
|-----|------|
| 0 (0x01) | GBuffer (opaque geometry) |
| 1 (0x02) | Shadow |
| 2 (0x04) | PerPixelPicking |
| 3 (0x08) | Transparency / custom |

A typical opaque material uses `3` (GBuffer + Shadow).

### Image JSON file

Located in `app/managers/images/`:

```json
{
  "name": "my_albedo",
  "fileName": "textures/my_albedo.dds",
  "samplerName": "LinearRepeat",
  "addressModeU": 0,
  "addressModeV": 0,
  "generateMipmaps": true
}
```

Textures must be in DDS format (BC1–BC7). Use the asset management tools or
`texconv.exe` from the DirectX Texture Tool to convert.

### GPU Program JSON file

Located in `app/managers/gpu_programs/`:

```json
{
  "name": "gbuffer_default",
  "shaderFileName": "gbuffer.vert.glsl",
  "entryPoint": "main",
  "defines": [],
  "programType": 0
}
```

| `programType` | Stage |
|---------------|-------|
| 0 | Vertex |
| 1 | Fragment |
| 2 | Compute |
| 3 | Geometry |

---

## 6. Shader System

### File naming convention

```
app/assets/shaders/
├── gbuffer.vert.glsl              # G-Buffer vertex shader (standard mesh)
├── gbuffer.frag.glsl              # G-Buffer fragment shader (standard mesh)
├── gbuffer_*.vert/frag.glsl       # Variant G-Buffer shaders (foliage, terrain, water, etc.)
├── lighting.frag.glsl             # Deferred lighting (fullscreen)
├── shadow.vert.glsl               # Shadow map vertex shader
├── post_*.glsl                    # Post-processing (bloom stages, combine, etc.)
├── volumetric_lighting*.comp.glsl # Volumetric lighting compute
├── lib_buffers.glsl               # MaterialParameters struct + MATERIAL_BUFFER macro
├── lib_lighting.glsl              # PBR lighting functions
├── lib_clustering.glsl            # Light/probe cluster lookup
├── lib_math.glsl                  # Math helpers (encodeNormal, linearizeDepth, etc.)
├── lib_noise.glsl                 # Simplex noise, fbm
├── lib_vol_lighting.glsl          # Volumetric lighting helpers
├── ubos.inc.glsl                  # Per-pass PerInstance UBO macros + PerFrame macro
├── gbuffer.inc.glsl               # G-Buffer fragment UBO macros, GBuffer struct, writeGBuffer()
├── gbuffer_vertex.inc.glsl        # G-Buffer vertex UBO macro + INPUT() vertex attributes
└── SMAA.h                         # SMAA anti-aliasing implementation
```

### Common includes

```glsl
#include "ubos.inc.glsl"       // per-pass PerInstance UBOs, PER_FRAME_DATA macro
#include "gbuffer.inc.glsl"    // G-Buffer fragment UBO, GBuffer struct, texture helpers
#include "gbuffer_vertex.inc.glsl"  // G-Buffer vertex UBO, vertex input attributes
#include "lib_math.glsl"       // encodeNormal, linearizeDepth, unproject, etc.
#include "lib_lighting.glsl"   // PBR BRDF functions
#include "lib_clustering.glsl" // getClusterIndex, iterateLights, etc.
#include "lib_noise.glsl"      // simplex2, simplex3, fbm
#include "lib_buffers.glsl"    // MaterialParameters, MATERIAL_BUFFER macro
```

### Uniform buffer system

#### Architecture overview

The engine manages **three physically distinct GPU buffers**, each with a different
lifetime, allocation strategy, and update cadence. All three are
`VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC` — a single large VkBuffer shared
across all draw calls, with a per-draw-call dynamic offset supplied at
`vkCmdBindDescriptorSets` time.

```
┌─────────────────────────────────────────────────────────────────────┐
│  _perInstanceUniformBuffer  (host-visible, ring-allocated)          │
│  Two buffer slots (double-buffered)                                 │
│  ┌──────────────────────────────┐  ┌────────────────────────────┐  │
│  │ slot 0 (GPU reads last frame)│  │ slot 1 (CPU writes this   │  │
│  │   small: 512 B × 4096 blocks │  │  frame — swaps each frame) │  │
│  │   large: 2048 B × 256 blocks │  └────────────────────────────┘  │
│  └──────────────────────────────┘                                   │
│                                                                     │
│  Allocation: lock-free block allocator, reset every frame           │
│  Updated by: MeshManager::updatePerInstanceData (every frame)       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  _perMaterialUniformBuffer  (device-local + staging)                │
│  256 B × _INTR_MAX_MATERIAL_COUNT blocks, static layout             │
│  One block per material, allocated once at material creation        │
│  Updated by: MaterialManager::updateResourcesGpu (on change only)  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  _perFrameUniformBuffer  (host-visible)                             │
│  512 B × swapchain_count × 2 (vertex slot + fragment slot)         │
│  Double-buffered per swapchain image                                │
│  Updated by: UniformManager::updatePerFrameData (once per frame)   │
└─────────────────────────────────────────────────────────────────────┘
```

Constants from `IntrinsicRendererPrerequisites.h`:

```cpp
_INTR_VK_PER_INSTANCE_DATA_BUFFER_COUNT   = 2    // double-buffer slot count
_INTR_VK_PER_INSTANCE_BLOCK_SMALL_SIZE    = 512  bytes
_INTR_VK_PER_INSTANCE_BLOCK_SMALL_COUNT   = 4096 // == _INTR_MAX_DRAW_CALL_COUNT
_INTR_VK_PER_INSTANCE_BLOCK_LARGE_SIZE    = 2048 bytes
_INTR_VK_PER_INSTANCE_BLOCK_LARGE_COUNT   = 256
_INTR_VK_PER_FRAME_BLOCK_SIZE             = 512  bytes
_INTR_VK_PER_MATERIAL_BLOCK_SIZE          = 256  bytes
_INTR_VK_PER_MATERIAL_BLOCK_COUNT         = _INTR_MAX_MATERIAL_COUNT
```

#### The UboType enum

`IntrinsicRendererEnumsStructs.h` defines seven `UboType` values. You supply one
of these when you call `DrawCallManager::bindBuffer` to route data into the
correct physical buffer and binding slot:

| UboType | Physical buffer | Binding | GLSL stage |
|---------|----------------|---------|-----------|
| `kPerInstanceVertex` | `_perInstanceUniformBuffer` | 0 | vertex |
| `kPerInstanceFragment` | `_perInstanceUniformBuffer` | 1 | fragment |
| `kPerInstanceCompute` | `_perInstanceUniformBuffer` | 0 | compute |
| `kPerMaterialVertex` | `_perMaterialUniformBuffer` | varies | vertex |
| `kPerMaterialFragment` | `_perMaterialUniformBuffer` | 2 (gbuffer) | fragment |
| `kPerFrameVertex` | `_perFrameUniformBuffer` | varies | vertex |
| `kPerFrameFragment` | `_perFrameUniformBuffer` | varies | fragment |

#### Data flow: per-instance (every frame, per draw call)

Per-instance data is re-uploaded every frame — the ring allocator hands out a new
block offset each time `allocateAndUpdateUniformMemory` is called:

```cpp
// C++ side (simplified from DrawCallManager::allocateAndUpdateUniformMemory):
MeshPerInstanceDataVertex vsData;
vsData.worldMatrix         = node.worldMatrix;
vsData.worldViewProjMatrix = cam.viewProj * node.worldMatrix;
// ... fill remaining fields ...

// Allocate a 512 B block from the current ring buffer slot:
uint32_t dynOffset = allocatePerInstanceDataMemory(kSmallBlock);

// Copy into host-visible GPU memory at that offset:
memcpy(&_perInstanceMemory[dynOffset], &vsData, sizeof(vsData));

// At draw time, the offset is supplied as a dynamic offset:
// vkCmdBindDescriptorSets(..., 1, &dynamicOffset);
```

At frame end, `UniformManager::onFrameEnded()` resets the allocator for the
current slot and advances to the next slot. The GPU is still reading the
**previous slot** while the CPU writes the **current slot** — this is the
double-buffering.

#### Data flow: per-material (allocated once, updated on change)

Material data is uploaded via a staging buffer the first time a material is
created and only re-uploaded when material properties change (e.g., the user
edits a material in the editor):

```cpp
// Called once at material creation and on property change:
MaterialManager::updateResourcesGpu(materialRef);
// → memcpy via staging buffer → _perMaterialUniformBuffer at fixed offset
```

The fixed offset is stored in `MaterialManager::_perMaterialDataFragmentOffset`.
At draw time, `DrawCallManager::allocateUniformMemory` reads this stored offset
and passes it as the dynamic offset for the `kPerMaterialFragment` slot — no
per-frame CPU work needed.

#### Data flow: per-frame (once per frame, at camera switch)

The per-frame buffer holds global rendering state: view/projection matrices, sky
model coefficients, sun direction, etc. It is written once per frame by
`UniformManager::updatePerFrameData()`:

```cpp
PerFrameDataFragment& data = getPerFrameDataFragment(swapchainIdx);
data.viewMatrix    = cam.viewMatrix;
data.invProjMatrix = glm::inverse(cam.projMatrix);
data.sunLightDirVS = cam.viewMatrix * world.sunDir;
// ... fill sky coefficients, SH bands, etc. ...
```

Two sub-slots exist per swapchain image: one for the vertex stage
(`kPerFrameVertex`) and one for the fragment stage (`kPerFrameFragment`).
The dynamic offset for each is returned by
`getDynamicOffsetForPerFrameDataFragment()` /
`getDynamicOffsetForPerFrameDataVertex()`.

#### Why `PER_INSTANCE_UBO` has the same name in two files

The macro name `PER_INSTANCE_UBO` is defined twice with **different content and
different binding numbers**:

- `gbuffer_vertex.inc.glsl` → `layout(binding = 0) uniform PerInstance { mat4 matrices..., vec4 data0 } uboPerInstance`
- `gbuffer.inc.glsl` → `layout(binding = 1) uniform PerInstance { vec4 colorTint, camParams, data0 } uboPerInstance`

This is intentional. The two files are always used in **separate shader stages**
(one in the `.vert.glsl`, the other in the `.frag.glsl`) and are never both
included in the same compilation unit. Since GLSL processes each stage
independently, there is no name collision at compile time.

At the C++ side both still map to the **same physical buffer** — the dynamic
offsets just point to different regions:
- binding 0 offset → `MeshPerInstanceDataVertex` struct
- binding 1 offset → `MeshPerInstanceDataFragment` struct

Both offsets come from the same `allocateAndUpdateUniformMemory` call, which
allocates two consecutive blocks and returns two dynamic offsets.

---

The rest of this section documents the GLSL macros that expose each buffer from
shader code. Each pass defines its own `PerInstance` block with only the data it
needs. Use the macros — never declare uniform blocks by hand in shader files.

#### G-Buffer vertex shader — `gbuffer_vertex.inc.glsl`

`PER_INSTANCE_UBO` expands to `layout(binding = 0) uniform PerInstance { ... } uboPerInstance`

C++ counterpart: `MeshPerInstanceDataVertex` (filled by `MeshManager::updatePerInstanceData`)

```glsl
// gbuffer.vert.glsl — include the vertex inc, then invoke the macro:
#include "gbuffer_vertex.inc.glsl"

PER_INSTANCE_UBO;   // expands to: layout(binding = 0) uniform PerInstance { ... } uboPerInstance

// Fields available as uboPerInstance.*:
mat4  worldMatrix
mat4  worldViewProjMatrix
mat4  worldViewMatrix
mat4  viewProjMatrix
mat4  viewMatrix
vec4  data0
//    data0.y = distToCamera (world-space distance from camera)
//    data0.w = totalTimePassed (seconds since engine start)
```

#### G-Buffer fragment shader — `gbuffer.inc.glsl`

> **Warning — name collision:** `gbuffer.inc.glsl` also defines a macro called
> `PER_INSTANCE_UBO`, but it expands to a **different** struct at **binding 1**
> (not binding 0). The two macros have the same name because they are always
> used in separate shader stages — never include both files in the same shader.

Two UBOs are used in G-Buffer fragment shaders: one per-instance (mesh data) and
one per-material (material params). Both are declared with macros.

`PER_INSTANCE_UBO` (from `gbuffer.inc.glsl`) → `layout(binding = 1) uniform PerInstance { ... } uboPerInstance`

C++ counterpart: `MeshPerInstanceDataFragment`

```glsl
// gbuffer.frag.glsl — include the fragment inc, then invoke the macro:
#include "gbuffer.inc.glsl"

PER_INSTANCE_UBO;   // expands to: layout(binding = 1) uniform PerInstance { ... } uboPerInstance
                    // NOTE: binding 1, not 0 — different from the vertex version

// uboPerInstance.*:
vec4  colorTint      // RGBA tint applied to albedo; set via MeshManager::_descColorTint
vec4  camParams
//    camParams.x = nearPlane
//    camParams.y = farPlane
//    camParams.z = 1 / nearPlane
//    camParams.w = 1 / farPlane
vec4  data0
//    data0.x = dayNightFactor (World::_currentDayNightFactor, 0=night, 1=day)
//    data0.y = distToCamera
//    data0.z = nodeRef._id cast to float (used for per-object effects)
//    data0.w = totalTimePassed
```

In fragment shaders both macros are declared together — the standard pattern from
`gbuffer.frag.glsl` is:

```glsl
#include "gbuffer.inc.glsl"

// Both macros in this order — PER_MATERIAL first, then PER_INSTANCE:
PER_MATERIAL_UBO;   // → layout(binding = 2) uniform PerMaterial { ... } uboPerMaterial
PER_INSTANCE_UBO;   // → layout(binding = 1) uniform PerInstance { ... } uboPerInstance

BINDINGS_GBUFFER;   // → albedoTex(3), normalTex(4), pbrTex(5)
layout(binding = 6) uniform sampler2D emissiveTex;   // declared manually
```

The order of the macro invocations in the GLSL source does not matter for
correctness (each expands to an explicit `binding = N` declaration), but the
codebase consistently puts `PER_MATERIAL_UBO` before `PER_INSTANCE_UBO`.

Full binding layout for a standard G-Buffer shader pair:

| Binding | Stage | Macro / declaration | C++ struct |
|---------|-------|---------------------|-----------|
| 0 | Vertex | `PER_INSTANCE_UBO` from `gbuffer_vertex.inc.glsl` | `MeshPerInstanceDataVertex` |
| 1 | Fragment | `PER_INSTANCE_UBO` from `gbuffer.inc.glsl` | `MeshPerInstanceDataFragment` |
| 2 | Fragment | `PER_MATERIAL_UBO` from `gbuffer.inc.glsl` | material data (MaterialManager) |
| 3 | Fragment | `BINDINGS_GBUFFER` | albedoTex |
| 4 | Fragment | `BINDINGS_GBUFFER` | normalTex |
| 5 | Fragment | `BINDINGS_GBUFFER` | pbrTex |
| 6 | Fragment | manual | emissiveTex |

`PER_MATERIAL_UBO` → `layout(binding = 2) uniform PerMaterial { ... } uboPerMaterial`

C++ counterpart: material data uploaded by `MaterialManager`

```glsl
PER_MATERIAL_UBO;

// uboPerMaterial.*:
vec4  uvOffsetScale    // .xy = UV offset,  .zw = UV scale
vec4  uvAnimation      // .xy = UV scroll speed (used by UV0_TRANSFORM_ANIMATED)
vec4  pbrBias          // .x = metallicBias, .y = specularBias, .z = roughnessBias
vec4  waterParams      // water-specific ripple/foam parameters
uvec4 data0
//    data0.x = materialBufferIdx — index into MaterialBuffer SSBO for runtime params
vec4  data1
//    data1.x = avgNormalLength — used by adjustRoughness() for specular AA
```

Texture bindings in G-Buffer fragment shaders (`BINDINGS_GBUFFER` macro):

```glsl
BINDINGS_GBUFFER;
// expands to:
layout(binding = 3) uniform sampler2D albedoTex;
layout(binding = 4) uniform sampler2D normalTex;   // BC5: RG → reconstruct Z
layout(binding = 5) uniform sampler2D pbrTex;      // R=metallic, G=roughness, B=AO
// binding 6 is emissiveTex (declared manually in gbuffer.frag.glsl)
```

For terrain shaders use `BINDINGS_TERRAIN` instead (3 texture layers, bindings 3–13).

#### UV transform helpers (gbuffer.inc.glsl)

```glsl
// With UV offset/scale and time-based animation (most common)
vec2 uv0 = UV0_TRANSFORM_ANIMATED(inUV0);

// With offset/scale only, no animation
vec2 uv0 = UV0_TRANSFORM(inUV0);

// Raw flip (just V-flip)
vec2 uv0 = UV0(inUV0);
```

#### G-Buffer output (`OUTPUT` macro + `writeGBuffer`)

```glsl
OUTPUT  // declares: out vec4 outAlbedo, outNormal, outParameter0

// Fill the GBuffer struct and write it:
GBuffer gbuffer;
gbuffer.albedo           = ...;   // vec4 RGBA
gbuffer.normal           = ...;   // vec3 world-space normal (normalized)
gbuffer.roughness        = ...;   // 0..1
gbuffer.specular         = 0.5;   // fixed for most materials
gbuffer.metalMask        = ...;   // 0..1
gbuffer.materialBufferIdx = uboPerMaterial.data0.x;
gbuffer.emissive         = ...;   // scalar intensity
gbuffer.occlusion        = 1.0;   // or sample from AO texture
writeGBuffer(gbuffer, outAlbedo, outNormal, outParameter0);
```

G-Buffer layout (what each render target stores):

| Attachment | R | G | B | A |
|------------|---|---|---|---|
| `GBufferAlbedo` (R16G16B16A16F) | albedo.r | albedo.g | albedo.b | albedo.a |
| `GBufferNormal` (R16G16B16A16F) | encoded normal X | encoded normal Y | specular | roughness |
| `GBufferParameter0` (R16G16B16A16F) | metalMask | materialBufferIdx | occlusion | emissive |
| `GBufferDepth` | depth | – | – | – |

Normal encoding is octahedral (see `encodeNormal` / `decodeNormal` in `lib_math.glsl`).

#### Per-frame data for lighting/post passes — `ubos.inc.glsl`

Used by the deferred lighting pass (`lighting.frag.glsl`) and other fullscreen passes.
Include with `#include "ubos.inc.glsl"` then use `PER_FRAME_DATA(binding)`.

`PER_FRAME_DATA(x)` → `layout(binding = x) uniform PerFrame { ... } uboPerFrame`

C++ counterpart: `RenderProcess::PerFrameDataFrament` (note: typo in original code)

```glsl
PER_FRAME_DATA(1);   // binding number varies per pass

// uboPerFrame.*:
mat4  viewMatrix
mat4  invProjMatrix
mat4  invViewMatrix

vec4  skyModelConfigs[7]        // Preetham sky model coefficients
vec4  skyModelRadiances         // sky radiance
vec4  sunLightDirVS             // sun direction in view space
vec4  sunLightDirWS             // sun direction in world space
vec4  skyLightSH[7]             // spherical harmonics coefficients for sky irradiance
vec4  sunLightColorAndIntensity // .xyz = color, .w = intensity

vec4  postParams0
//    postParams0.w = fog/atmosphere density parameter
```

#### Per-pass PerInstance UBOs for post-processing — `ubos.inc.glsl`

Each fullscreen post pass uses a different macro. Use the matching one in your shader:

| Macro | Pass | Key fields |
|-------|------|-----------|
| `PER_INSTANCE_DATA_PRE_COMBINE` | Pre-combine / SSAO | invViewMatrix, invProjMatrix, invViewProjMatrix, camPosition, camParams, postParams0 |
| `PER_INSTANCE_DATA_POST_COMBINE` | Post-combine / tone mapping | haltonSamples, camParams, postParams0 |
| `PER_INSTANCE_DATA_SSAO_TEMP_REPROJ` | SSAO temporal reprojection | invViewProjMatrix, invProjMatrix, projMatrix, prevViewMatrix |
| `PER_INSTANCE_DATA_SSAO_HBAO` | SSAO HBAO | invProjMatrix |
| `PER_INSTANCE_DATA_BLUR` | Blur passes | blurParams (direction + radius), camParams |
| `PER_INSTANCE_DATA_SMAA_VERT` | SMAA vertex | backbufferSize |
| `PER_INSTANCE_DATA_SMAA_FRAG` | SMAA fragment | backbufferSize (binding 1) |

`camParams` in pre/post-combine passes:
- `.x` = nearPlane, `.y` = farPlane, `.z` = 1/nearPlane, `.w` = 1/farPlane

`postParams0` meaning depends on the pass — check `UniformManager::_uniformDataSource`
and the pass-specific C++ fill code.

#### Lighting pass PerInstance UBO — `lighting.frag.glsl`

The deferred lighting pass declares its own `PerInstance` block (not via a macro):

```glsl
layout(binding = 0) uniform PerInstance {
  mat4  shadowViewProjMatrix[MAX_SHADOW_MAP_COUNT];  // PSSM shadow matrices
  vec4  nearFarWidthHeight;   // frustum parameters for shadow PCF
  vec4  nearFar;              // .x = near, .y = far (linear depth)
  vec4  data0;
  //    data0.x = time (TaskManager::_totalTimePassed)
  //    data0.y = globalIrradianceFactor (Clustering::_globalIrradianceFactor)
  //    data0.z = globalSpecularFactor   (Clustering::_globalSpecularFactor)
  //    data0.w = currentDayNightTime    (World::_currentTime)
} uboPerInstance;
```

#### Material buffer SSBO — `lib_buffers.glsl`

Runtime material parameters (translucency, emissive intensity, flags) are stored
in a large SSBO indexed by `materialBufferIdx` from the G-Buffer:

```glsl
#include "lib_buffers.glsl"

MATERIAL_BUFFER;   // expands to: buffer MaterialBuffer { MaterialParameters materialParameters[]; }

// In fragment shader (lighting pass), look up parameters for the current pixel:
uint matIdx = uint(gbuffer_materialBufferIdx);
MaterialParameters matParams = materialParameters[matIdx];
float thickness = matParams.translucencyThickness;
float emissive  = matParams.emissiveIntensity;
```

### Adding a new shader

1. Create `app/assets/shaders/my_shader.frag.glsl`
2. Create `app/managers/gpu_programs/my_shader_frag.gpu_program.json`
3. Reference the GPU program from your material or pass pipeline

Shaders are compiled from GLSL to SPIR-V at startup (via `glslang`). Compile
errors appear in the console. There is no offline pre-compilation step required
for development.

---

## 7. Render Passes

### 7.1 Frame execution flow

`RenderProcess::Default::renderFrame()` runs every frame:

```
1. RenderSystem::resizeSwapChain()          – handle window resize
2. RenderSystem::beginFrame()               – acquire swapchain image, begin primary cmd buf
3. Culling phase:
   a. Update cameras and build frustums
   b. Shadow::prepareFrustums()             – split camera frustum into PSSM slices
   c. CameraManager::updateFrustumsAndMatrices()
   d. FrustumManager::cullNodes()           – per-frustum AABB culling
   e. MeshManager::collectDrawCallsAndMeshComponents()
   f. UniformManager::resetAllocator()
4. executeRenderSteps(p_DeltaT)             – dispatch each step from renderer_config.json
5. RenderSystem::endFrame()                 – submit, present
```

`executeRenderSteps` iterates `_renderSteps` (parsed from JSON). For each step it
either dispatches a generic pass directly (`GenericFullscreen`, `GenericMesh`,
`GenericBlur`, `ImageMemoryBarrier`, `SwitchCamera`) or looks up the specialized
pass in `_renderStepFunctionMapping` and calls its `render()`.

**Culling and draw calls are pre-built before the render steps run.** The render
steps read from `RenderProcess::Default::_activeFrustums` and the corresponding
draw call lists — they do not cull themselves.

#### Task parallelism in draw call collection

`collectDrawCallsAndMeshComponents` schedules one `DrawCallCollectionParallelTaskSet`
per material pass. enkiTS can split a single task set across multiple worker threads
by calling `ExecuteRange` concurrently with non-overlapping `p_Range` values.
All those concurrent calls share the same output vector
(`_visibleDrawCallsPerMaterialPass[frustIdx][materialPassIdx]`), so any `push_back`
from multiple threads simultaneously is a data race that corrupts the vector.

**The fix applied here:** set `m_MinRange = m_SetSize` on every task set whose
`ExecuteRange` writes to a shared container. This tells enkiTS the entire work must
run as one partition — only one thread executes `ExecuteRange`, so no concurrent
writes occur. Different material-pass task sets still run in parallel with each other
(they have separate output vectors); only the within-one-pass split is disabled.

**General rule:** if you add a new `ITaskSet` whose `ExecuteRange` pushes to any
shared vector, either set `m_MinRange = m_SetSize` or use a per-thread scratch vector
and merge the results after `WaitforTaskSet`. Never call `push_back` on the same
vector from two concurrent `ExecuteRange` invocations of the same task set.

#### enkiTS TaskScheduler — full API reference

Intrinsic uses **enkiTS** (`dependencies/enkits/`) as its work-stealing parallel
task scheduler. The public API lives in `dependencies/enkits/src/TaskScheduler.h`.

##### Scheduler lifecycle

```cpp
enki::TaskScheduler scheduler;

// Creates (hardware_threads - 1) worker threads.
// The main thread becomes thread 0 and also participates in work.
scheduler.Initialize();

// Graceful shutdown: finishes all in-flight work, then joins workers.
scheduler.WaitforAllAndShutdown();
```

`GetNumTaskThreads()` returns the total number of threads that can execute tasks —
worker threads **plus** the main thread. Use this to size per-thread scratch buffers.

##### ITaskSet — the unit of parallel work

```cpp
struct MyTask : enki::ITaskSet
{
    // Optional: set m_SetSize and m_MinRange before AddTaskSetToPipe.
    // ITaskSet(uint32_t setSize, uint32_t minRange) initializes both.

    void ExecuteRange(enki::TaskSetPartition p_Range,
                      uint32_t              p_ThreadNum) override;
};
```

| Field / method | Meaning |
|---|---|
| `m_SetSize` | Total number of work items (like a loop `[0, m_SetSize)`). |
| `m_MinRange` | Minimum items per partition. enkiTS will not split a partition smaller than this. |
| `GetIsComplete()` | Returns true once all partitions have finished. |

enkiTS splits the range `[0, m_SetSize)` into partitions of at least `m_MinRange`
items and schedules them across available threads. Each partition triggers one call
to `ExecuteRange` with:

```cpp
struct TaskSetPartition { uint32_t start; uint32_t end; };
// Covers work items [start, end) — never overlapping between concurrent calls.
```

`p_ThreadNum` is the index of the calling thread (0 = main thread). It is intended
for indexing **per-thread scratch buffers**, not for changing which data items are
processed (that is determined by `p_Range`).

##### Submitting and waiting

```cpp
scheduler.AddTaskSetToPipe(&myTask); // enqueue; may start immediately

// Cooperative wait: the calling thread helps execute tasks while waiting.
// This means the main thread can call ExecuteRange — never assume only
// worker threads run it.
scheduler.WaitforTaskSet(&myTask);

scheduler.WaitforAll(); // wait for every queued task
```

##### Grain size and thread safety

When `m_SetSize == m_MinRange` (or when there is only one work item), enkiTS runs
the entire task as a single partition on one thread — `ExecuteRange` is called
exactly once. This is the safest option when the callback writes to a shared
container.

When `m_SetSize > m_MinRange`, multiple threads can call `ExecuteRange`
simultaneously with **non-overlapping** but **concurrent** invocations. Any shared
mutable state touched from `ExecuteRange` must be protected. Common patterns:

| Scenario | Recommended approach |
|---|---|
| Output to a shared `std::vector` | Set `m_MinRange = m_SetSize` to force a single partition. |
| Each item is independent (no shared output) | Leave `m_MinRange` at default (1). |
| Need parallel throughput + shared output | Allocate one output vector **per thread** (`GetNumTaskThreads()` entries), fill them inside `ExecuteRange` using `p_ThreadNum`, then merge after `WaitforTaskSet`. |

##### Profiler hooks

```cpp
enki::ProfilerCallbacks cb;
cb.threadStart = [](uint32_t threadNum) { /* thread started */ };
cb.threadStop  = [](uint32_t threadNum) { /* thread stopping */ };
cb.waitStart   = [](uint32_t threadNum) { /* about to block/help */ };
cb.waitStop    = [](uint32_t threadNum) { /* resumed after wait */ };
scheduler.SetProfilerCallbacks(&cb);
```

All callbacks fire on the thread they describe. Use them to push/pop GPU or CPU
profiler zones per worker thread.

Default pass order:

```
RenderPassDynamicGeometryGeneration   – voxel + marching cubes compute
RenderPassDynamicTextureGeneration    – procedural texture compute
RenderPassGeometryGeneration          – static procedural geometry
SwitchCamera → ActiveCamera
RenderPassMarchingCubes               – render computed mesh geometry
RenderPassShadow                      – depth-only shadow maps (PSSM)
RenderPassVolumetricLighting          – ESM + scatter accumulation (compute)
RenderPassClustering                  – light culling + deferred lighting (fullscreen)
GenericMesh "GBuffer"                 – fills GBufferAlbedo/Normal/Parameter0/Depth
RenderPassBloom                       – lum downsample → blur → composite (compute)
GenericFullscreen "PostCombine"       – tone mapping + SMAA
RenderPassPerPixelPicking             – off-screen pick buffer (editor only)
RenderPassDebug                       – wireframes, AABBs, probes
```

---

### 7.2 Resource creation patterns

Every GPU resource follows the same three-step pattern:

```cpp
// 1. Allocate a named slot in the resource pool
ImageRef img = ImageManager::createImage(_N(MyImage));

// 2. Reset to defaults, then fill in your descriptor
ImageManager::resetToDefault(img);
ImageManager::addResourceFlags(img, Dod::Resources::ResourceFlags::kResourceVolatile);
ImageManager::_descDimensions(img)   = glm::uvec3(width, height, 1u);
ImageManager::_descImageFormat(img)  = Format::kR16G16B16A16Float;
ImageManager::_descImageType(img)    = ImageType::kTexture;
ImageManager::_descImageFlags(img)   = ImageFlags::kUsageAttachment
                                     | ImageFlags::kUsageSampled;

// 3. Batch-create (allocates VkImage, VkDeviceMemory, VkImageView)
ImageRefArray toCreate = { img };
ImageManager::createResources(toCreate);
```

`kResourceVolatile` marks resources that must be recreated on reinit
(resolution-dependent). Static resources (shadow maps, LUTs) omit this flag.

Key `ImageFlags`:

| Flag | Meaning |
|------|---------|
| `kUsageAttachment` | Can be used as color/depth attachment |
| `kUsageSampled` | Can be read in shaders via sampler |
| `kUsageStorage` | Can be bound as `image2D` in compute |

Key `Format` values (matching Vulkan formats):

| Constant | Format |
|----------|--------|
| `kR8G8B8A8UNorm` | `VK_FORMAT_R8G8B8A8_UNORM` |
| `kR16G16B16A16Float` | `VK_FORMAT_R16G16B16A16_SFLOAT` |
| `kR32SFloat` | `VK_FORMAT_R32_SFLOAT` |
| `kDepth` | Depth format chosen by `RenderSystem::_depthStencilFormatToUse` |

---

### 7.3 The two dispatch patterns

#### Graphics pass (rasterization)

```cpp
// 1. Transition the color attachment to writable
ImageManager::insertImageMemoryBarrier(
    _outputImageRef,
    VK_IMAGE_LAYOUT_UNDEFINED,
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

// 2. Begin render pass
VkClearValue clears[2];
clears[0].color        = {{0.f, 0.f, 0.f, 1.f}};
clears[1].depthStencil = {1.f, 0u};
RenderSystem::beginRenderPass(_renderPassRef, _framebufferRef,
                              VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS,
                              2u, clears);

// 3. Queue draw calls (they run in secondary cmd buffers in parallel)
DrawCallDispatcher::queueDrawCalls(visibleDrawCalls, _renderPassRef, _framebufferRef);

// OR for a single fullscreen triangle / quad:
RenderSystem::beginRenderPass(_renderPassRef, _framebufferRef,
                              VK_SUBPASS_CONTENTS_INLINE, 1u, clears);
RenderSystem::dispatchDrawCall(_fullscreenDrawCallRef,
                               RenderSystem::getPrimaryCommandBuffer());

// 4. End render pass
RenderSystem::endRenderPass(_renderPassRef);

// 5. Transition to readable for later passes
ImageManager::insertImageMemoryBarrier(
    _outputImageRef,
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
    VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
```

#### Compute pass

```cpp
VkCommandBuffer cmd = RenderSystem::getPrimaryCommandBuffer();

// 1. Transition storage images to GENERAL
ImageManager::insertImageMemoryBarrier(
    _outputImageRef,
    VK_IMAGE_LAYOUT_UNDEFINED,
    VK_IMAGE_LAYOUT_GENERAL,
    VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);

// 2. Upload per-dispatch uniforms
MyPerInstanceData data = { width, height, time };
ComputeCallManager::updateUniformMemory(
    {_computeCallRef}, &data, sizeof(data));

// 3. Dispatch
RenderSystem::dispatchComputeCall(_computeCallRef, cmd);

// 4. Transition output to readable
ImageManager::insertImageMemoryBarrier(
    _outputImageRef,
    VK_IMAGE_LAYOUT_GENERAL,
    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
    VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
```

---

### 7.4 Adding a render pass: complete walkthrough

**Every file that must be touched:**

| File | What to add |
|------|------------|
| `IntrinsicRendererRenderPassMyPass.h` | struct declaration |
| `IntrinsicRendererRenderPassMyPass.cpp` | implementation |
| `IntrinsicRenderer/CMakeLists.txt` | add to source list |
| `IntrinsicRendererRenderProcess.h` | `#include` the new header |
| `IntrinsicRendererRenderProcess.cpp` | enum value, type mapping, function mapping |
| `app/config/renderer_config.json` | add render step |

#### Step 1 — Header

```cpp
// IntrinsicRendererRenderPassMyPass.h
#pragma once
#include "IntrinsicRendererRenderProcess.h"

namespace Intrinsic { namespace Renderer { namespace RenderPass {

struct MyPass
{
  static void init();
  static void onReinitRendering();
  static void destroy();
  static void render(float p_DeltaT,
                     Components::CameraRef p_CameraRef);

  // Static resources (lifetime = renderer lifetime)
  static PipelineLayoutRef _pipelineLayoutRef;
  static PipelineRef       _pipelineRef;

  // Volatile resources (recreated on reinit)
  static ImageRef        _outputImageRef;
  static FramebufferRef  _framebufferRef;
  static RenderPassRef   _renderPassRef;
  static DrawCallRef     _drawCallRef;
};

}}} // namespace
```

#### Step 2 — Implementation skeleton

```cpp
// IntrinsicRendererRenderPassMyPass.cpp
#include "stdafx.h"
#include "IntrinsicRendererRenderPassMyPass.h"

using namespace RResources;
using namespace CComponents;

namespace Intrinsic { namespace Renderer { namespace RenderPass {

// Static member definitions
PipelineLayoutRef MyPass::_pipelineLayoutRef;
PipelineRef       MyPass::_pipelineRef;
ImageRef          MyPass::_outputImageRef;
FramebufferRef    MyPass::_framebufferRef;
RenderPassRef     MyPass::_renderPassRef;
DrawCallRef       MyPass::_drawCallRef;

// -----------------------------------------------------------------------
// init() — called once at startup.
// Create only resources that do NOT depend on the backbuffer resolution:
// pipelines, pipeline layouts, static images, static buffers.
// -----------------------------------------------------------------------
void MyPass::init()
{
  PipelineLayoutRefArray layoutsToCreate;
  PipelineRefArray       pipesToCreate;

  // --- Pipeline layout (reflects binding slots from the shader) ---
  _pipelineLayoutRef = PipelineLayoutManager::createPipelineLayout(_N(MyPass));
  PipelineLayoutManager::resetToDefault(_pipelineLayoutRef);
  GpuProgramManager::reflectPipelineLayout(
      8u,   // max descriptor set count
      { GpuProgramManager::getResourceByName(_N(my_pass.vert)),
        GpuProgramManager::getResourceByName(_N(my_pass.frag)) },
      _pipelineLayoutRef);
  layoutsToCreate.push_back(_pipelineLayoutRef);

  PipelineLayoutManager::createResources(layoutsToCreate);

  // --- Graphics pipeline ---
  _pipelineRef = PipelineManager::createPipeline(_N(MyPass));
  PipelineManager::resetToDefault(_pipelineRef);
  PipelineManager::_descVertexProgram(_pipelineRef) =
      GpuProgramManager::getResourceByName(_N(my_pass.vert));
  PipelineManager::_descFragmentProgram(_pipelineRef) =
      GpuProgramManager::getResourceByName(_N(my_pass.frag));
  PipelineManager::_descPipelineLayout(_pipelineRef) = _pipelineLayoutRef;
  PipelineManager::_descDepthStencilState(_pipelineRef) =
      DepthStencilStates::kDefaultNoWrite;   // read depth, don't write
  PipelineManager::_descRasterizationState(_pipelineRef) =
      RasterizationStates::kDefault;
  // _descRenderPass and _descVertexLayout are filled in onReinitRendering
  // because the render pass object references a resolution-dependent format
  pipesToCreate.push_back(_pipelineRef);

  PipelineManager::createResources(pipesToCreate);
}

// -----------------------------------------------------------------------
// onReinitRendering() — called at startup (after init) AND after every
// window resize / renderer config reload.
// Create/recreate everything that depends on backbuffer dimensions.
// -----------------------------------------------------------------------
void MyPass::onReinitRendering()
{
  // -- Destroy old volatile resources --
  {
    ImageRefArray      imgDel;
    FramebufferRefArray fbDel;
    RenderPassRefArray  rpDel;
    DrawCallRefArray    dcDel;

    if (_outputImageRef.isValid()) imgDel.push_back(_outputImageRef);
    if (_framebufferRef.isValid()) fbDel.push_back(_framebufferRef);
    if (_renderPassRef.isValid())  rpDel.push_back(_renderPassRef);
    if (_drawCallRef.isValid())    dcDel.push_back(_drawCallRef);

    ImageManager::destroyImagesAndResources(imgDel);
    FramebufferManager::destroyFramebuffersAndResources(fbDel);
    RenderPassManager::destroyRenderPassesAndResources(rpDel);
    DrawCallManager::destroyDrawCallsAndResources(dcDel);
  }

  const glm::uvec2 res = RenderSystem::_backbufferDimensions;

  // -- Output image --
  _outputImageRef = ImageManager::createImage(_N(MyPassOutput));
  {
    ImageManager::resetToDefault(_outputImageRef);
    ImageManager::addResourceFlags(
        _outputImageRef, Dod::Resources::ResourceFlags::kResourceVolatile);
    ImageManager::_descMemoryPoolType(_outputImageRef) =
        MemoryPoolType::kResolutionDependentImages;
    ImageManager::_descDimensions(_outputImageRef) = glm::uvec3(res, 1u);
    ImageManager::_descImageFormat(_outputImageRef) =
        Format::kR16G16B16A16Float;
    ImageManager::_descImageFlags(_outputImageRef) =
        ImageFlags::kUsageAttachment | ImageFlags::kUsageSampled;
  }
  ImageManager::createResources({ _outputImageRef });

  // -- Render pass (describes load/store ops and attachment formats) --
  _renderPassRef = RenderPassManager::createRenderPass(_N(MyPass));
  {
    RenderPassManager::resetToDefault(_renderPassRef);
    AttachmentDescription colorAtt = {
        (uint8_t)Format::kR16G16B16A16Float,
        AttachmentFlags::kClearOnLoad };
    RenderPassManager::_descAttachments(_renderPassRef).push_back(colorAtt);
    // Add depth attachment read-only if you need it:
    // AttachmentDescription depthAtt = {
    //     (uint8_t)RenderSystem::_depthStencilFormatToUse,
    //     AttachmentFlags::kLoadFromPreviousPass };
    // RenderPassManager::_descAttachments(_renderPassRef).push_back(depthAtt);
  }
  RenderPassManager::createResources({ _renderPassRef });

  // -- Framebuffer --
  _framebufferRef = FramebufferManager::createFramebuffer(_N(MyPass));
  {
    FramebufferManager::resetToDefault(_framebufferRef);
    FramebufferManager::addResourceFlags(
        _framebufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
    FramebufferManager::_descDimensions(_framebufferRef) = res;
    FramebufferManager::_descRenderPass(_framebufferRef) = _renderPassRef;
    FramebufferManager::_descAttachedImages(_framebufferRef)
        .push_back(AttachmentInfo(_outputImageRef));
    // .push_back(AttachmentInfo(gbufferDepthRef));  // if depth read
  }
  FramebufferManager::createResources({ _framebufferRef });

  // -- Wire render pass into the pipeline --
  PipelineManager::_descRenderPass(_pipelineRef) = _renderPassRef;
  PipelineManager::createResources({ _pipelineRef });

  // -- Draw call (fullscreen triangle — no vertex buffer needed) --
  _drawCallRef = DrawCallManager::createDrawCall(_N(MyPass));
  {
    DrawCallManager::resetToDefault(_drawCallRef);
    DrawCallManager::addResourceFlags(
        _drawCallRef, Dod::Resources::ResourceFlags::kResourceVolatile);
    DrawCallManager::_descPipeline(_drawCallRef)       = _pipelineRef;
    DrawCallManager::_descVertexCount(_drawCallRef)    = 3u;  // fullscreen tri
    DrawCallManager::_descFramebuffer(_drawCallRef)    = _framebufferRef;
    DrawCallManager::_descRenderPass(_drawCallRef)     = _renderPassRef;

    // Bind per-frame uniform
    DrawCallManager::bindBuffer(
        _drawCallRef, _N(PerInstance),
        GpuProgramType::kFragment,
        UniformManager::_perInstanceUniformBuffer,
        UboType::kPerInstanceFragment,
        sizeof(MyPerInstanceData));

    // Bind input textures from earlier passes
    DrawCallManager::bindImage(
        _drawCallRef, _N(sceneTex),
        GpuProgramType::kFragment,
        ImageManager::getResourceByName(_N(Scene)),   // output of Clustering pass
        Samplers::kLinearClamp);

    DrawCallManager::bindImage(
        _drawCallRef, _N(depthTex),
        GpuProgramType::kFragment,
        ImageManager::getResourceByName(_N(GBufferDepth)),
        Samplers::kNearestClamp);
  }
  DrawCallManager::createResources({ _drawCallRef });

  // -- Initial layout transition (needed before first render call) --
  VkCommandBuffer tmpCmd = RenderSystem::beginTemporaryCommandBuffer();
  ImageManager::insertImageMemoryBarrier(
      _outputImageRef,
      VK_IMAGE_LAYOUT_UNDEFINED,
      VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
      VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
      VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
  RenderSystem::flushTemporaryCommandBuffer();
}

// -----------------------------------------------------------------------
// destroy() — cleanup at shutdown
// -----------------------------------------------------------------------
void MyPass::destroy()
{
  PipelineManager::destroyPipelinesAndResources({ _pipelineRef });
  PipelineLayoutManager::destroyPipelineLayoutsAndResources(
      { _pipelineLayoutRef });
}

// -----------------------------------------------------------------------
// render() — called every frame
// -----------------------------------------------------------------------
void MyPass::render(float p_DeltaT, Components::CameraRef p_CameraRef)
{
  _INTR_PROFILE_CPU("Render Pass", "My Pass");
  _INTR_PROFILE_GPU("My Pass");

  VkCommandBuffer cmd = RenderSystem::getPrimaryCommandBuffer();

  // Update per-instance data
  MyPerInstanceData perInstance;
  perInstance.time     = TaskManager::_totalTimePassed;
  perInstance.invRes   = glm::vec2(1.f) / glm::vec2(RenderSystem::_backbufferDimensions);

  DrawCallManager::allocateAndUpdateUniformMemory(
      { _drawCallRef }, nullptr, 0u, &perInstance, sizeof(perInstance));

  // Transition output to writable
  ImageManager::insertImageMemoryBarrier(
      _outputImageRef,
      VK_IMAGE_LAYOUT_UNDEFINED,
      VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
      VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
      VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

  // Render
  VkClearValue clear;
  clear.color = {{0.f, 0.f, 0.f, 1.f}};
  RenderSystem::beginRenderPass(_renderPassRef, _framebufferRef,
                                VK_SUBPASS_CONTENTS_INLINE, 1u, &clear);
  RenderSystem::dispatchDrawCall(_drawCallRef, cmd);
  RenderSystem::endRenderPass(_renderPassRef);

  // Transition to readable
  ImageManager::insertImageMemoryBarrier(
      _outputImageRef,
      VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
      VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
      VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
      VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
}

}}} // namespace
```

#### Step 3 — Register in RenderProcess

In `IntrinsicRendererRenderProcess.cpp`:

```cpp
// 1. Add to RenderStepType::Enum
namespace RenderStepType {
enum Enum {
  // ... existing values ...
  kRenderPassMyPass        // ADD THIS
};
}

// 2. Add to _renderStepTypeMapping
_INTR_HASH_MAP(Name, RenderStepType::Enum) _renderStepTypeMapping = {
  // ... existing entries ...
  { "RenderPassMyPass", RenderStepType::kRenderPassMyPass },  // ADD THIS
};

// 3. Add to _renderStepFunctionMapping
_INTR_HASH_MAP(RenderStepType::Enum, RenderPassInterface) _renderStepFunctionMapping = {
  // ... existing entries ...
  { RenderStepType::kRenderPassMyPass,
    { RenderPass::MyPass::render, RenderPass::MyPass::onReinitRendering } },
};
```

Also add `init()` and `destroy()` calls in `RenderProcess::init()` and
`RenderProcess::destroy()`.

In `IntrinsicRendererRenderProcess.h` add:
```cpp
#include "IntrinsicRendererRenderPassMyPass.h"
```

#### Step 4 — renderer_config.json

```json
"renderSteps": [
  ...,
  { "type": "RenderPassMyPass" },
  ...
]
```

Place it **after** any passes that produce images you bind as inputs (e.g. after
`RenderPassClustering` if you read `Scene`).

#### Step 5 — Shaders

```glsl
// app/assets/shaders/my_pass.vert.glsl
#version 450
#include "lib_buffers.glsl"

// Fullscreen triangle — no input vertices needed.
// The vertex shader generates clip-space positions from gl_VertexIndex.
void main() {
  vec2 uv = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
  gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}
```

```glsl
// app/assets/shaders/my_pass.frag.glsl
#version 450
#include "lib_buffers.glsl"

layout(set = 0, binding = 0) uniform PerInstance {
  vec2 invRes;
  float time;
} uPerInstance;

layout(set = 1, binding = 0) uniform sampler2D sceneTex;
layout(set = 1, binding = 1) uniform sampler2D depthTex;

layout(location = 0) out vec4 outColor;

void main() {
  vec2 uv    = gl_FragCoord.xy * uPerInstance.invRes;
  vec4 scene = texture(sceneTex, uv);
  outColor   = scene;
}
```

Create the GPU program JSON files in `app/managers/gpu_programs/`:

```json
// my_pass_vert.gpu_program.json
{ "name": "my_pass.vert", "shaderFileName": "my_pass.vert.glsl",
  "entryPoint": "main", "programType": 0 }

// my_pass_frag.gpu_program.json
{ "name": "my_pass.frag", "shaderFileName": "my_pass.frag.glsl",
  "entryPoint": "main", "programType": 1 }
```

---

### 7.5 Image memory barriers — rules

```
oldLayout = UNDEFINED is always valid as srcLayout.
The driver discards content and transitions to newLayout.
Use it at the start of every frame for every attachment you're about to write.
```

| Transition | srcStage | dstStage |
|------------|----------|----------|
| init / first use | `TOP_OF_PIPE` | target stage |
| after compute write | `COMPUTE_SHADER_BIT` | consumer stage |
| after color attachment write | `COLOR_ATTACHMENT_OUTPUT_BIT` | consumer stage |
| after depth write | `LATE_FRAGMENT_TESTS_BIT` | consumer stage |
| after transfer | `TRANSFER_BIT` | consumer stage |

`TOP_OF_PIPE` and `BOTTOM_OF_PIPE` must always have access masks `= 0`
(the helper zeroes them automatically since commit `fd363ee7`).

---

### 7.6 Accessing a render target from another pass

```cpp
// In init() — the image was declared in renderer_config.json
// or created by an earlier pass's onReinitRendering()
_gbufferDepthRef = ImageManager::getResourceByName(_N(GBufferDepth));
_sceneRef        = ImageManager::getResourceByName(_N(Scene));
```

The `Name` (`_N(...)`) must match the `"name"` field in the image's
`ImageManager::createImage()` call or its `renderer_config.json` entry.

---

## 8. Shadows & Volumetric Lighting

### 8.1 Shadow system overview

The engine uses **Parallel Split Shadow Mapping (PSSM)** with **Exponential Shadow Maps (ESM)**.
Four cascades cover the visible range from the camera near plane out to 3000 world units.

Key constants from `IntrinsicRendererPrerequisites.h`:

```cpp
_INTR_PSSM_SPLIT_COUNT    = 4   // cascade count
_INTR_MAX_SHADOW_MAP_COUNT = 4
```

Shadow map resolution: **1536 × 1536** per cascade (stored as a `sampler2DArray`
with 4 layers).

### 8.2 Frame order for shadows and volumetric lighting

```
1. RenderPassShadow::render()              – depth to shadow array (4 layers)
2. ESM generation (esm_generate.frag)      – depth → exponential domain (256×256)
3. ESM blur horizontal + vertical          – gaussian smooth of ESM texture
4. VolumetricLighting accumulation         – compute: fill 160×90×128 volume
5. VolumetricLighting scattering           – compute: ray-march & integrate volume
6. Lighting pass                           – final shading, reads shadows + volume
```

### 8.3 PSSM cascade setup

`RenderPassShadow::calculateFrustumForSplit()` computes one orthographic
view-projection matrix per cascade:

```
split 0: near = 0.1,   far ≈ 25     (high detail)
split 1: near ≈ 25,    far ≈ 100
split 2: near ≈ 100,   far ≈ 400
split 3: near ≈ 400,   far = 3000   (low detail)
```

The near/far values follow a quadratic distribution controlled by
`splitDistance = 5.0f`. To change the cascade distribution, adjust this constant
in `IntrinsicRendererRenderPassShadow.cpp`.

**Texel snapping** is applied to each cascade's orthographic projection to
prevent shadow edge swimming when the camera moves.

Each cascade matrix is stored in
`FrustumManager::_viewProjectionMatrix(shadowFrustumRef)` and is consumed by the
lighting and volumetric passes via the per-instance UBO:

```cpp
// MeshPerInstanceDataLighting (lighting pass)
glm::mat4 shadowViewProjMatrix[_INTR_MAX_SHADOW_MAP_COUNT];
```

### 8.4 Shadow rendering pass

`IntrinsicRendererRenderPassShadow.cpp` / `shadow.vert.glsl`

Each cascade is rendered with its own viewport into a different array layer.
The geometry is culled against each shadow frustum independently.

Three material passes are drawn per cascade:

| Material pass | Shader pair | Notes |
|---------------|-------------|-------|
| `Shadow` | `shadow.vert` (no frag) | Depth-only for opaque geometry |
| `ShadowFoliage` | `shadow_foliage.vert` + `shadow_foliage.frag` | Wind animation + alpha test |
| `ShadowGrass` | `shadow_foliage.vert` + `shadow_foliage.frag` | Same shaders, grass-tuned constants |

Sorting is **front-to-back** for early-Z rejection.

Shadow bias is a vertex-level normal offset: each vertex is displaced
`0.07 * worldNormal` along its world-space normal before projection.

### 8.5 ESM (Exponential Shadow Map) generation

Raw depth is hard to filter — ESM transforms it into a space where blurring
produces smooth penumbrae without light-leak artifacts.

**`esm_generate.frag.glsl`** — runs once per cascade layer, outputs to
`ShadowBufferExp` (256×256, `R32G32B32A32Float`):

```glsl
vec2 warpDepth(float depth) {
  depth = 2.0 * depth - 1.0;           // map [0,1] → [-1,1]
  return vec2(
    exp( 300.0 * depth),               // positive exponent
    -exp(-20.0 * depth)                // negative exponent
  );
}
```

Each output pixel stores `vec4(e+, e-, e+², e-²)` from a 2×2 depth gather.

The two exponent constants control shadow quality:
- **300.0** — shadow hardness at the caster boundary
- **20.0** — suppresses light-leak in penumbra areas

To get softer shadows reduce 300.0; to reduce light-leak increase 20.0.

**`esm_blur.frag.glsl`** — separable horizontal-then-vertical Gaussian,
radius = 5 texels, ping-pong between `ShadowBufferExp` and
`ShadowBufferExpPingPong`.

### 8.6 Shadow sampling at runtime

`lib_lighting.glsl` provides two sampling paths:

#### ESM path — `calculateShadowESM()`

```glsl
float calculateShadowESM(vec4 moments, float shadowDepth) {
  vec2 warpedDepth = warpDepth(shadowDepth);
  return clamp(moments.x / warpedDepth.x, 0.0, 1.0);
}
```

Used by the volumetric accumulation compute and the lighting pass.

#### PCF path — `witnessPCF()`

Weighted 9-tap Poisson disk with hardware PCF (`sampler2DArrayShadow`).
Used as fallback for surfaces without ESM support.

#### Cascade selection — `findBestFittingSplit()`

```glsl
uint findBestFittingSplit(vec3 posVS, out vec4 posLS,
                          in mat4 shadowViewProjMatrix[MAX_SHADOW_MAP_COUNT])
{
  for (uint i = 0u; i < PSSM_SPLIT_COUNT; ++i) {
    vec4 ls = shadowViewProjMatrix[i] * vec4(posVS, 1.0);
    ls.xyz /= ls.w;
    ls.xy = ls.xy * 0.5 + 0.5;
    if (ls.x >= 0.0 && ls.x <= 1.0 && ls.y >= 0.0 && ls.y <= 1.0) {
      posLS = ls;
      return i;
    }
  }
  return uint(-1);
}
```

At cascade boundaries (within 10% of the split edge) the result is blended
between two adjacent cascades to hide the seam.

### 8.7 Volumetric lighting architecture

The volumetric system fills a **3D texture volume** in front of the camera and
then ray-marches through it during the lighting pass.

```
Volume dimensions: 160 × 90 × 128 voxels
Near plane:        1.0 world units
Far plane:         500.0 world units
Depth distribution: non-linear, exponent 3.0 (close cells are thinner)
```

Two compute shaders process the volume each frame.

### 8.8 Accumulation compute — `volumetric_lighting.comp.glsl`

**Thread dispatch**: one thread per voxel column, 8×8 thread groups in XY.

For each voxel cell the shader computes:

1. **Temporal reprojection**
   - Projects the cell's world position to last frame's screen space.
   - If the reprojected UV is in-bounds, blends 85% previous frame + 15% current.
   - Discards history for out-of-bounds or newly visible cells.

2. **Temporal super-sampling**
   - Jitters the cell position by up to ±0.5 using Halton samples
     (`uboPerInstance.haltonSamples`).

3. **Density**
   ```glsl
   float density = densityFactor * layerThickness;
   // Height attenuation: fog thins above reference height (700 units)
   density *= exp(-heightAttenuationFactor * max(cellPosWS.y - heightRefPosWS.y, 0.0));
   ```
   `densityFactor` = `scatteringDayNight * _globalScatteringFactor`
   — time-of-day and user-configurable intensity.

4. **Sun contribution**
   - Transforms cell position to shadow space with `findBestFittingSplit()`.
   - Reads ESM shadow buffer.
   - Applies `clamp(calculateShadowESM(...) * 1.1 - 0.1, 0.0, 1.0)` to boost
     contrast at the shadow boundary.

5. **Sky contribution**
   - Evaluates spherical harmonics irradiance for the view ray direction.

6. **Local lights and irradiance probes**
   - Uses the same clustering grid as the deferred lighting pass.
   - Evaluates point light attenuation (inverse-square with sphere radius cutoff).

7. **Output**: `vec4(density * lighting, density)` into `VolumetricLightingBuffer`.

### 8.9 Scattering compute — `volumetric_lighting_scattering.comp.glsl`

Integrates the accumulation buffer along the view ray (near → far):

```glsl
vec4 accum(vec4 prev, vec4 next) {
  vec3 light = prev.rgb + clamp(exp(-prev.a), 0.0, 1.0) * next.rgb;
  return vec4(light, prev.a + next.a);
}
```

`exp(-prev.a)` is the transmittance — how much light from farther cells
reaches the camera after passing through the fog accumulated so far.
Thicker fog (higher `.a`) blocks more light from behind it.

Output goes to `VolumetricLightingScatteringBuffer` (same 3D texture dimensions).

### 8.10 Applying volumetric lighting in the lighting pass

`lighting.frag.glsl` samples the scattering volume at the end of the shading
pipeline:

```glsl
// Project fragment to volume UV
vec3 volUV = vec3(screenUV, linearDepth / VOLUMETRIC_LIGHTING_RANGE_FAR);
vec4 scatter = texture(volLightScatteringTex, volUV);

// Compose: scene colour attenuated by fog + in-scattered light
vec3 result = sceneColour * clamp(exp(-scatter.a), 0.0, 1.0) + scatter.rgb;
```

### 8.11 Tuning shadows and volumetric fog

| Parameter | Location | Effect |
|-----------|----------|--------|
| Shadow cascade distribution | `splitDistance` in `RenderPassShadow.cpp` | Higher = more cascades pushed far |
| Shadow max distance | `maxShadowDistance` | Far plane of last cascade |
| Shadow map resolution | `glm::uvec2(1536)` in same file | Increase for sharper shadows, costs VRAM |
| ESM hardness | constant `300.0` in `esm_generate.frag` | Lower = softer edge |
| ESM light-leak | constant `20.0` in `esm_generate.frag` | Higher = less leak |
| ESM blur radius | `5.0` in `esm_blur.frag` | Wider = softer penumbra |
| Fog density (runtime) | `_globalScatteringFactor` in `VolumetricLighting.cpp` | Master fog density knob |
| Fog height falloff | `heightAttenuationFactor = 0.025` | Higher = fog thins faster with altitude |
| Fog height reference | `heightRefPosWS.y = 700` | World-Y above which fog starts thinning |
| Volume near/far | `VOLUMETRIC_LIGHTING_RANGE_NEAR/FAR` in `volumetric_lighting.inc.glsl` | Volumetric depth range |
| Volume depth slices | `VOLUME_DEPTH 128` in same file | More slices = less banding, more cost |
| Temporal blend | constant `0.85` in accumulation shader | Higher = less noise, more ghosting |

### 8.12 Adding a custom fog volume or shadow caster

**New shadow caster** — assign the material pass `Shadow` (or `ShadowFoliage` for
alpha-tested foliage) to any mesh material. The shadow pass already renders all
geometry with those material passes; no C++ changes required.

**Custom per-object fog volume** — the density formula in the accumulation compute
shader is a simple function of world-space cell position. You can add a check
there to boost density inside an AABB or sphere:

```glsl
// Inside volumetric_lighting.comp.glsl density block:
vec3 toVolCenter = cellPosWS - myFogVolumeCenter;
if (dot(toVolCenter, toVolCenter) < myFogVolumeRadius * myFogVolumeRadius)
  density *= myFogVolumeDensityMultiplier;
```

The fog volume parameters would need to be passed in via the per-instance UBO
(`PerInstanceData::data0.w` has a free slot as of the current code).

---

## 9. Camera & Frustum System

### 9.1 Data model

The camera system is split across two types: a **component** (`CameraManager`) and
a **resource** (`FrustumManager`). Each camera component owns exactly one frustum.
All other consumers of view/projection matrices (render passes, shadow pass,
volumetric lighting) work with `FrustumRef` directly — they never reach back to
the camera component.

```
Entity
 └── NodeComponent      – world position and orientation
 └── CameraComponent    – fov, near/far, owns a FrustumRef
         │
         ▼
     FrustumRef          – all computed matrices + culling planes + corners
```

The active camera for the current frame is stored in `World::_activeCamera`
(a `CameraRef`). The renderer reads it at the start of each frame via
`World::_activeCamera` or `World::getActiveCamera()`.

### 9.2 CameraComponent properties

Serialised fields (from `compileDescriptor`/`initFromDescriptor`):

| Field | Default | JSON key |
|-------|---------|----------|
| `_descFov` | `glm::radians(75.0f)` | `"fov"` (in degrees in JSON) |
| `_descNearPlane` | `1.0f` | `"nearPlane"` |
| `_descFarPlane` | `10000.0f` | `"farPlane"` |

Access via:

```cpp
float fov   = CameraManager::_descFov(camRef);         // radians
float near  = CameraManager::_descNearPlane(camRef);
float far   = CameraManager::_descFarPlane(camRef);
```

### 9.3 Matrix update — `CameraManager::updateFrustumsAndMatrices()`

Called once per frame before any render pass runs. For each camera in the list:

```cpp
// 1. Read world transform from the camera's Node component
glm::vec3 pos     = NodeManager::_worldPosition(nodeRef);
glm::quat rot     = NodeManager::_worldOrientation(nodeRef);

// 2. Derive forward and up vectors (engine convention: +Z forward, +Y up)
forward = rot * glm::vec3(0, 0, 1);
up      = rot * glm::vec3(0, 1, 0);

// 3. Save previous view matrix (used for temporal reprojection)
_prevViewMatrix(cam) = _viewMatrix(cam);

// 4. Build view matrix
_viewMatrix(cam) = glm::lookAt(pos, pos + forward, up);

// 5. Build projection matrix
_projectionMatrix(cam) = computeCustomProjMatrix(cam, near, far);
```

`computeCustomProjMatrix` applies a Y-flip to match Vulkan's NDC (+Y is down):

```cpp
glm::mat4 CameraManager::computeCustomProjMatrix(CameraRef p_Ref, float p_Near, float p_Far)
{
  const float aspect = backbufferWidth / (float)backbufferHeight;
  return glm::scale(glm::vec3(1, -1, 1))   // flip Y for Vulkan
       * glm::perspective(_descFov(p_Ref), aspect, p_Near, p_Far);
}
```

After this call the frustum data is still incomplete — derived matrices and
culling planes are computed by `FrustumManager::prepareForRendering()`.

### 9.4 FrustumManager::prepareForRendering()

Derives all secondary data from the view and projection matrices set by the
camera update:

```
viewProjectionMatrix        = projMatrix * viewMatrix
invViewMatrix               = inverse(viewMatrix)
invProjectionMatrix         = inverse(projMatrix)
invViewProjectionMatrix     = inverse(viewProjectionMatrix)
frustumWorldPosition        = viewMatrix[3]   (camera world position)
frustumPlanesViewSpace      = extractFrustumPlanes(viewProjectionMatrix)
frustumCornersViewSpace     = extractFrustumsCorners(invProjectionMatrix)
frustumCornersWorldSpace    = extractFrustumsCorners(invViewProjectionMatrix)
```

This is called for **all active frustums at once** — camera frustums plus the
four shadow cascade frustums.

### 9.5 FrustumData — all stored matrices and planes

`IntrinsicCoreResourcesFrustum.h` / `FrustumData`:

| Field | Type | Set by | Description |
|-------|------|--------|-------------|
| `descViewMatrix` | `mat4` | `CameraManager::updateFrustumsAndMatrices` | View matrix (current frame) |
| `descPrevViewMatrix` | `mat4` | Same | View matrix from previous frame (temporal) |
| `descProjectionMatrix` | `mat4` | Same | Projection matrix (Y-flipped for Vulkan) |
| `descNearFarPlaneDistances` | `vec2` | Same | `.x = near, .y = far` |
| `descProjectionType` | `uint8_t` | Same | `kPerspective` or `kOrthographic` |
| `invViewMatrix` | `mat4` | `prepareForRendering` | Camera-to-world transform |
| `invProjectionMatrix` | `mat4` | Same | Clip-to-view transform |
| `viewProjectionMatrix` | `mat4` | Same | Combined VP matrix |
| `invViewProjectionMatrix` | `mat4` | Same | Clip-to-world transform |
| `frustumWorldPosition` | `vec3` | Same | Camera world position |
| `frustumPlanesViewSpace` | `FrustumPlanes` | Same | 6 culling planes in view space |
| `frustumCornersViewSpace` | `FrustumCorners` | Same | 8 corners in view space |
| `frustumCornersWorldSpace` | `FrustumCorners` | Same | 8 corners in world space |

Access pattern from render passes (via `CameraManager` convenience wrappers):

```cpp
glm::mat4& view    = CameraManager::_viewMatrix(camRef);
glm::mat4& invView = CameraManager::_inverseViewMatrix(camRef);
glm::mat4& proj    = CameraManager::_projectionMatrix(camRef);
glm::mat4& vp      = CameraManager::_viewProjectionMatrix(camRef);
glm::mat4& invVP   = CameraManager::_inverseViewProjectionMatrix(camRef);
glm::mat4& prevV   = CameraManager::_prevViewMatrix(camRef);
```

Or directly through `FrustumManager` if you have a `FrustumRef`:

```cpp
FrustumRef fr = CameraManager::_frustum(camRef);
glm::mat4& vp = FrustumManager::_viewProjectionMatrix(fr);
```

### 9.6 Frustum planes

`FrustumPlanes` stores 6 planes extracted from the view-projection matrix using
Gribb-Hartmann method (column-major, direct extraction):

| Index | Enum | |
|-------|------|-|
| 0 | `FrustumPlane::kNear` | |
| 1 | `FrustumPlane::kFar` | |
| 2 | `FrustumPlane::kLeft` | |
| 3 | `FrustumPlane::kRight` | |
| 4 | `FrustumPlane::kTop` | |
| 5 | `FrustumPlane::kBottom` | |

Each plane is a normal `n` (vec3) + scalar `d` (float). A point `p` is inside
the frustum if `dot(n[i], p) + d[i] >= 0` for all 6 planes.

`FrustumCorners` stores 8 corners (NDC cube back-projected through the inverse
matrix):

```
kNearTopRight=0, kNearTopLeft=1, kNearBottomLeft=2, kNearBottomRight=3
kFarTopRight=4,  kFarTopLeft=5,  kFarBottomLeft=6,  kFarBottomRight=7
```

The third person camera controller uses the near four corners to sweep rays for
collision detection with the environment.

### 9.7 Frustum culling — `FrustumManager::cullNodes()`

Culling runs in parallel using enkiTS (`CullingParallelTaskSet`).

For each active frustum × each active node:

1. Read the node's world bounding sphere (`NodeManager::_worldBoundingSphere`).
2. SIMD test: pack 4 frustum planes into `__m128` registers, test the sphere
   against all 6 planes using multiply-add (`_mm_madd`-style).
3. Set or clear the corresponding bit in `NodeManager::_visibilityMask(nodeRef)`.

Each frustum occupies one bit in the visibility mask (frustum 0 = bit 0, frustum
1 = bit 1, ...). The camera frustum is always frustum 0 when set up as the first
entry in `p_ActiveFrustums`. The shadow cascade frustums follow.

A node is visible to a frustum when its bit is **set** in the mask. Mesh
collection (`MeshManager::collectDrawCallsAndMeshComponents`) filters by the
camera frustum bit before building draw call lists.

A `#define USE_NAIVE_CULLING` in `IntrinsicCoreResourcesFrustum.cpp` switches to
a scalar fallback (plane-by-plane dot product loop) for debugging.

### 9.8 Active camera

`World::_activeCamera` holds the single `CameraRef` used by the renderer.

```cpp
// Set active camera (e.g. in a game state or Lua):
World::setActiveCamera(camRef);

// Read in a render pass:
CameraRef cam = World::_activeCamera;
```

The renderer (`RenderProcess.cpp`) reads this at frame start and resolves named
camera references from `renderer_config.json` — the special name `"ActiveCamera"`
always maps to `World::_activeCamera`.

### 9.9 CameraController component

A `CameraController` component drives a camera's `Node` transform each frame via
`CameraControllerManager::updateControllers()`. Two modes:

#### `kFirstPerson`

- Reads `_descTargetEulerAngles` (set externally, e.g. from input).
- Clamps vertical pitch to `±π/2`.
- Smoothly slerps the node orientation toward the target at `rotationSpeed = 4`.
- Optionally snaps position to a named target entity's eye height
  (`0.8 * AABB.max.y` above origin).

#### `kThirdPerson`

- Follows a named target entity (`_descTargetObjectName`).
- Maintains a fixed distance of **10 world units** behind and above the target.
- Auto-rotates behind the target after **2 seconds** of no input.
- **Camera collision**: sweeps 4 PhysX rays from the near frustum corners toward
  the camera position; if any ray hits geometry the camera is pulled in to
  `max(hitDistance, 2.0)` units from the target.
- Smoothly interpolates position (`movementSpeed = 4`) and orientation
  (`rotationSpeed = 4`).

Serialised fields:

| JSON key | Type | Default |
|----------|------|---------|
| `"cameraControllerType"` | enum | `"ThirdPerson"` |
| `"targetObjectName"` | string | `""` |
| `"targetEulerAngles"` | vec3 | `(0,0,0)` |

`targetEulerAngles` is written every frame by the input handler and read by the
controller — it is the primary way to rotate the camera from Lua or C++ game code:

```cpp
CameraControllerRef ctrl = CameraControllerManager::getComponentForEntity(camEntity);
CameraControllerManager::_descTargetEulerAngles(ctrl) += glm::vec3(pitchDelta, yawDelta, 0);
```

### 9.10 Custom projection matrix

To temporarily override the projection (e.g. for oblique near-clip, custom FOV,
or an off-axis stereo render) write directly to the frustum's description fields
before `prepareForRendering()` is called:

```cpp
FrustumRef fr = CameraManager::_frustum(camRef);

// Custom near/far for a specific pass:
glm::mat4 customProj = CameraManager::computeCustomProjMatrix(camRef, 0.5f, 500.0f);
FrustumManager::_descProjectionMatrix(fr) = customProj;
FrustumManager::_descNearFarPlaneDistances(fr) = glm::vec2(0.5f, 500.0f);

// prepareForRendering() will recompute all derived matrices from this
FrustumManager::prepareForRendering({fr});
```

For orthographic frustums (used by shadow cascades):
```cpp
FrustumManager::_descProjectionType(fr) = ProjectionType::kOrthographic;
FrustumManager::_descProjectionMatrix(fr) = glm::ortho(left, right, bottom, top, near, far);
```

---

## 10. GPU Resource Reference

Every GPU object in the engine is managed through the same `Ref`-based SoA
pattern. You call `createX()` to get a handle, fill its `desc*` fields, call
`createResources()` to allocate the Vulkan objects, and `destroyResources()` /
`destroyX()` to clean up. The sections below cover each resource type.

### 10.1 Buffer

`BufferManager` (`IntrinsicRendererResourcesBuffer.h`)

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descBufferType` | `BufferType::Enum` | `kVertex`, `kIndex16`, `kIndex32`, `kUniform`, `kStorage` |
| `_descMemoryPoolType` | `MemoryPoolType::Enum` | Which GPU memory pool to allocate from (see table below) |
| `_descSizeInBytes` | `uint32_t` | Buffer size |
| `_descInitialData` | `void*` | Optional pointer to CPU data to upload at creation; may be `nullptr` |

**MemoryPoolType values:**

| Value | Use case |
|-------|---------|
| `kStaticBuffers` | Device-local, written once (mesh data, material UBOs) |
| `kStaticStagingBuffers` | Host-visible mapping; CPU writes here, GPU reads directly (uniform ring buffers) |
| `kResolutionDependentBuffers` | Device-local, re-created on swapchain resize |
| `kResolutionDependentStagingBuffers` | Host-visible, re-created on resize |
| `kVolatileStagingBuffers` | Transient upload staging, reused each frame |

**Full lifecycle example — a storage buffer for SSBO data:**

```cpp
// --- in init() ---
_myBufferRef = BufferManager::createBuffer(_N(MyBuffer));
BufferManager::resetToDefault(_myBufferRef);
BufferManager::_descBufferType(_myBufferRef)     = BufferType::kStorage;
BufferManager::_descMemoryPoolType(_myBufferRef) = MemoryPoolType::kStaticBuffers;
BufferManager::_descSizeInBytes(_myBufferRef)    = sizeof(MyData) * MAX_ITEMS;
BufferManager::_descInitialData(_myBufferRef)    = nullptr;  // upload later
BufferManager::createResources({_myBufferRef});

// --- writing to a host-visible buffer (staging pool) each frame ---
uint8_t* gpuMem = BufferManager::getGpuMemory(_myBufferRef);
memcpy(gpuMem, myData, dataSize);

// --- inserting a buffer memory barrier ---
BufferManager::insertBufferMemoryBarrier(
    _myBufferRef,
    VK_ACCESS_HOST_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT,
    VK_PIPELINE_STAGE_HOST_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);

// --- in destroy() ---
BufferManager::destroyBuffersAndResources({_myBufferRef});
```

`getGpuMemory()` asserts that the buffer is in a host-visible pool
(`_mappedMemory != nullptr`) — only use it for staging or uniform pools.

### 10.2 GpuProgram (shader)

`GpuProgramManager` (`IntrinsicRendererResourcesGpuProgram.h`)

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descGpuProgramName` | `string` | GLSL source filename without path, e.g. `"my_pass.comp.glsl"` |
| `_descGpuProgramType` | `GpuProgramType::Enum` | `kVertex`, `kFragment`, `kGeometry`, `kCompute`, `kControl`, `kEvaluation` |
| `_descEntryPoint` | `string` | Usually `"main"` |
| `_descPreprocessorDefines` | `string` | Space-separated `#define` list, e.g. `"ENABLE_FOG USE_PCF"` |

**Example:**

```cpp
_myCompRef = GpuProgramManager::createGpuProgram(_N(MyPass));
GpuProgramManager::resetToDefault(_myCompRef);
GpuProgramManager::_descGpuProgramName(_myCompRef) = "my_pass.comp.glsl";
GpuProgramManager::_descGpuProgramType(_myCompRef) = GpuProgramType::kCompute;
GpuProgramManager::_descEntryPoint(_myCompRef)     = "main";
GpuProgramManager::createResources({_myCompRef});
// Compiles GLSL → SPIR-V at this point via glslang
```

### 10.3 PipelineLayout

`PipelineLayoutManager` (`IntrinsicRendererResourcesPipelineLayout.h`)

A pipeline layout describes the descriptor set layout and push constants.
The engine auto-reflects bindings from SPIR-V — you only need to enumerate
the binding slots explicitly when working with dynamic UBOs.

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descBindingDescs` | `array<BindingDescription>` | List of binding slots; usually populated by `GpuProgramManager::reflectPipelineLayout()` |

In practice, nearly all render passes call `reflectPipelineLayout` rather than
filling binding descriptions manually:

```cpp
_myPipelineLayoutRef = PipelineLayoutManager::createPipelineLayout(_N(MyPass));
PipelineLayoutManager::resetToDefault(_myPipelineLayoutRef);

// Auto-reflect from the compute shader's SPIR-V:
GpuProgramManager::reflectPipelineLayout(
    8u,                        // max bindings to discover
    {_myCompRef},              // list of GpuProgramRefs
    _myPipelineLayoutRef);

PipelineLayoutManager::createResources({_myPipelineLayoutRef});
```

### 10.4 Pipeline

`PipelineManager` (`IntrinsicRendererResourcesPipeline.h`)

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descPipelineLayout` | `PipelineLayoutRef` | Layout from PipelineLayoutManager |
| `_descComputeProgram` | `GpuProgramRef` | Compute shader (compute pipeline only) |
| `_descVertexProgram` | `GpuProgramRef` | Vertex shader (graphics pipeline only) |
| `_descFragmentProgram` | `GpuProgramRef` | Fragment shader |
| `_descGeometryProgram` | `GpuProgramRef` | Geometry shader (optional) |
| `_descRenderPass` | `RenderPassRef` | Required for graphics pipelines |
| `_descVertexLayout` | `VertexLayoutRef` | Required for graphics pipelines |
| `_descDepthStencilState` | `DepthStencilStates::Enum` | See table below |
| `_descRasterizationState` | `RasterizationStates::Enum` | See table below |
| `_descBlendStates` | `array<BlendStates::Enum>` | One entry per color attachment |
| `_descInputAssemblyState` | `InputAssemblyStates::Enum` | `kTriangleList`, `kLineList` |
| `_descViewportRenderSize` | `RenderSize::Enum` | `kFull`, `kHalf`, `kQuarter`, `kCustom` |
| `_descScissorRenderSize` | `RenderSize::Enum` | Same options |

**DepthStencilStates:**

| Value | Depth test | Depth write |
|-------|-----------|------------|
| `kDefault` | Yes (less) | Yes |
| `kDefaultNoWrite` | Yes (less) | No |
| `kDefaultNoDepthTest` | No | Yes |
| `kDefaultNoDepthTestAndWrite` | No | No |

**RasterizationStates:**

| Value | Cull mode |
|-------|-----------|
| `kDefault` | Back-face culling |
| `kInvertedCulling` | Front-face culling |
| `kDoubleSided` | No culling |
| `kWireframe` | No culling, wireframe fill |

**BlendStates:**

| Value | Behaviour |
|-------|-----------|
| `kDefault` | Opaque (blend disabled) |
| `kAlphaBlend` | Standard src-alpha / one-minus-src-alpha |

**Compute pipeline example:**

```cpp
_myPipelineRef = PipelineManager::createPipeline(_N(MyPass));
PipelineManager::resetToDefault(_myPipelineRef);
PipelineManager::_descComputeProgram(_myPipelineRef) = _myCompRef;
PipelineManager::_descPipelineLayout(_myPipelineRef) = _myPipelineLayoutRef;
PipelineManager::createResources({_myPipelineRef});
```

**Graphics pipeline example (additional fields):**

```cpp
PipelineManager::_descVertexProgram(_myPipelineRef)      = _myVertRef;
PipelineManager::_descFragmentProgram(_myPipelineRef)     = _myFragRef;
PipelineManager::_descRenderPass(_myPipelineRef)          = _myRenderPassRef;
PipelineManager::_descVertexLayout(_myPipelineRef)        = _myVertexLayoutRef;
PipelineManager::_descDepthStencilState(_myPipelineRef)   = DepthStencilStates::kDefault;
PipelineManager::_descRasterizationState(_myPipelineRef)  = RasterizationStates::kDefault;
PipelineManager::_descBlendStates(_myPipelineRef)         = {BlendStates::kDefault};
PipelineManager::_descViewportRenderSize(_myPipelineRef)  = RenderSize::kFull;
```

### 10.5 RenderPass

`RenderPassManager` (`IntrinsicRendererResourcesRenderPass.h`)

A `RenderPass` describes the attachment formats and their load/store ops.
The `Framebuffer` (section 10.6) binds actual `ImageView`s to those slots.

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descAttachments` | `array<AttachmentDescription>` | One entry per color/depth attachment |

`AttachmentDescription` (from `IntrinsicRendererEnumsStructs.h`) holds
`format`, `loadOp`, `storeOp`, `initialLayout`, `finalLayout`, and a
`clearColor`/`clearDepth` value.

```cpp
_myRenderPassRef = RenderPassManager::createRenderPass(_N(MyPass));
RenderPassManager::resetToDefault(_myRenderPassRef);

AttachmentDescription colorAttachment;
colorAttachment.format        = Format::kB10G11R11UFloat;
colorAttachment.loadOp        = AttachmentLoadOp::kLoad;    // or kClear / kDontCare
colorAttachment.storeOp       = AttachmentStoreOp::kStore;
colorAttachment.initialLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
colorAttachment.finalLayout   = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
RenderPassManager::_descAttachments(_myRenderPassRef).push_back(colorAttachment);

AttachmentDescription depthAttachment;
depthAttachment.format        = Format::kD32SFloat;
depthAttachment.loadOp        = AttachmentLoadOp::kLoad;
depthAttachment.storeOp       = AttachmentStoreOp::kDontCare;
depthAttachment.initialLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
depthAttachment.finalLayout   = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
RenderPassManager::_descAttachments(_myRenderPassRef).push_back(depthAttachment);

RenderPassManager::createResources({_myRenderPassRef});
```

### 10.6 Framebuffer

`FramebufferManager` (`IntrinsicRendererResourcesFramebuffer.h`)

Binds specific image views to a `RenderPass`. Re-create in
`onReinitRendering()` whenever images are resolution-dependent.

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descRenderPass` | `RenderPassRef` | Must match the render pass used at draw time |
| `_descAttachedImages` | `array<AttachmentInfo>` | One entry per attachment in the render pass |
| `_descDimensions` | `glm::uvec2` | Width × height in pixels |

`AttachmentInfo` holds an `ImageRef` and the array layer / mip level to use.

```cpp
_myFramebufferRef = FramebufferManager::createFramebuffer(_N(MyPass));
FramebufferManager::resetToDefault(_myFramebufferRef);
FramebufferManager::_descRenderPass(_myFramebufferRef)   = _myRenderPassRef;
FramebufferManager::_descDimensions(_myFramebufferRef)   =
    RenderSystem::_backbufferDimensions;

AttachmentInfo colorInfo;
colorInfo.imageRef  = ImageManager::getResourceByName(_N(Scene));
colorInfo.arrayLayer = 0u;
colorInfo.mipLevel   = 0u;
FramebufferManager::_descAttachedImages(_myFramebufferRef).push_back(colorInfo);

AttachmentInfo depthInfo;
depthInfo.imageRef   = ImageManager::getResourceByName(_N(GBufferDepth));
FramebufferManager::_descAttachedImages(_myFramebufferRef).push_back(depthInfo);

FramebufferManager::createResources({_myFramebufferRef});
```

### 10.7 DrawCall

`DrawCallManager` (`IntrinsicRendererResourcesDrawCall.h`)

A `DrawCall` groups everything needed for one `vkCmdDraw` / `vkCmdDrawIndexed`
dispatch: pipeline, vertex/index buffers, descriptor bindings, and uniform data.

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descPipeline` | `PipelineRef` | Pipeline to bind |
| `_descVertexBuffers` | `array<BufferRef>` | Vertex buffer(s) |
| `_descIndexBuffer` | `BufferRef` | Index buffer; invalid = non-indexed draw |
| `_descVertexCount` | `uint32_t` | For non-indexed draws |
| `_descIndexCount` | `uint32_t` | For indexed draws |
| `_descInstanceCount` | `uint32_t` | Usually 1 |
| `_descBindInfos` | `array<BindingInfo>` | Texture/buffer descriptor bindings |
| `_descMaterial` | `Dod::Ref` | Material ref (for per-material UBO offset lookup) |
| `_descMaterialPass` | `uint8_t` | Material pass index |
| `_descIsProceduralMesh` | `uint8_t` | Non-zero for procedurally generated (marching cubes) meshes |
| `_descProceduralIndirectBuffer` | `VkBuffer` | Indirect draw buffer for dynamic procedural meshes; `VK_NULL_HANDLE` for static ones |

**Procedural mesh draw path:**

`DrawCallDispatcher` reads `_descIsProceduralMesh` directly instead of doing a
name lookup into the procedural mesh list. When set:
- `_descProceduralIndirectBuffer != VK_NULL_HANDLE` → `vkCmdDrawIndirect` (dynamic mesh, vertex count written by GPU)
- `_descProceduralIndirectBuffer == VK_NULL_HANDLE` → `vkCmdDraw` with `_descVertexCount` (static generated mesh)

Both fields are set each frame in the dynamic mesh per-frame update loop
(`DynamicMeshGeneration.cpp`) alongside the vertex buffer rebind. They default to
`0` / `VK_NULL_HANDLE` via `resetToDefault`, so regular meshes are unaffected.

**Binding helpers:**

```cpp
// Bind a combined image+sampler at the named slot:
DrawCallManager::bindImage(dcRef, _N(albedoTex),
    BindingType::kImageAndSamplerCombined, imageRef, samplerIdx, 0u);

// Bind a storage image (for compute read/write):
DrawCallManager::bindImage(dcRef, _N(output0Tex),
    BindingType::kStorageImage, imageRef, 0u, 0u);

// Bind a dynamic UBO (per-instance vertex data):
DrawCallManager::bindBuffer(dcRef, _N(PerInstance),
    BindingType::kUniformBufferDynamic,
    UniformManager::_perInstanceUniformBuffer,
    UboType::kPerInstanceVertex,
    sizeof(MyPerInstanceDataVertex));
```

**Per-frame update loop:**

```cpp
// Allocate ring-buffer slot and copy data:
DrawCallManager::allocateAndUpdateUniformMemory(
    dcRef,
    &vsData, sizeof(vsData),
    &fsData, sizeof(fsData));
```

### 10.8 ComputeCall

`ComputeCallManager` (`IntrinsicRendererResourcesComputeCall.h`)

Equivalent of `DrawCall` but for compute dispatches.

**Description fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `_descPipeline` | `PipelineRef` | Compute pipeline |
| `_descBindInfos` | `array<BindingInfo>` | Texture/buffer/UBO bindings |
| `_descDimensions` | `glm::uvec3` | Thread group count (X, Y, Z) |

```cpp
_myComputeCallRef = ComputeCallManager::createComputeCall(_N(MyPass));
ComputeCallManager::resetToDefault(_myComputeCallRef);
ComputeCallManager::_descPipeline(_myComputeCallRef)    = _myPipelineRef;
ComputeCallManager::_descDimensions(_myComputeCallRef)  = glm::uvec3(
    (backbufferW + 7) / 8,    // ceil(W / localSizeX)
    (backbufferH + 7) / 8,
    1u);

// Bind images and buffers using the same helpers as DrawCall:
ComputeCallManager::bindImage(_myComputeCallRef, _N(inputTex),
    BindingType::kSampledImage, inputImageRef, linearSamplerIdx, 0u);
ComputeCallManager::bindImage(_myComputeCallRef, _N(outputTex),
    BindingType::kStorageImage, outputImageRef, 0u, 0u);

ComputeCallManager::createResources({_myComputeCallRef});
```

**Dispatch at render time:**

```cpp
ComputeCallManager::allocateAndUpdateUniformMemory(_myComputeCallRef, &data, sizeof(data));
DrawCallDispatcher::queueComputeCall(_myComputeCallRef, primaryCmdBuf);
```

### 10.9 Dependency graph — full lifecycle

#### Static dependency graph

```
GpuProgram ──────────────────────────────────┐
                                             ↓
PipelineLayout  ←── (reflected from SPIR-V) ─┤
                                             ↓
                                          Pipeline ──────────────┐
                                                                 ↓
Image ──┐                                                     DrawCall
        ↓                                                     ComputeCall
     Framebuffer ←── RenderPass ←── Pipeline
        ↑
     Image (depth attachment, from another pass or own)
```

Who references whom (= who must exist first, who must be destroyed first):

| Resource | References (must exist before) | Referenced by (must die before) |
|----------|-------------------------------|--------------------------------|
| `GpuProgram` | — | `PipelineLayout`, `Pipeline` |
| `PipelineLayout` | `GpuProgram`(s) | `Pipeline` |
| `Pipeline` | `PipelineLayout`, `GpuProgram`(s), `RenderPass`, `VertexLayout` | `DrawCall`, `ComputeCall` |
| `RenderPass` | — | `Pipeline`, `Framebuffer` |
| `Image` | — | `Framebuffer`, `DrawCall`/`ComputeCall` bindings |
| `Buffer` | — | `DrawCall`/`ComputeCall` bindings |
| `Framebuffer` | `RenderPass`, `Image`(s) | — |
| `DrawCall` | `Pipeline`, `Buffer`(s), `Image`(s) | — |
| `ComputeCall` | `Pipeline`, `Buffer`(s), `Image`(s) | — |

**Destruction order** must be the reverse of creation:

```
1. DrawCall / ComputeCall   (reference Pipeline, Images, Buffers)
2. Framebuffer              (references RenderPass, Images)
3. Pipeline                 (references PipelineLayout, RenderPass)
4. PipelineLayout           (references GpuPrograms)
5. RenderPass               (no live references)
6. Buffer / Image           (no live references at this point)
7. GpuProgram               (usually left alive — loaded globally)
```

#### The three lifecycle groups

Not all resources are created in the same function. The engine splits
resources into three stability tiers based on whether they need to be
recreated on swapchain resize:

**Tier 1 — permanent** (created in `init()`, destroyed in `destroy()`):

These objects do not depend on backbuffer resolution and survive any number
of swapchain resizes untouched.

| Resource type | Why it's permanent |
|---------------|-------------------|
| `GpuProgram` | SPIR-V bytecode, no resolution data |
| `PipelineLayout` | Descriptor set layout, no resolution data |
| `Pipeline` | References layout + programs; viewport is dynamic |
| Fixed-size `Buffer` | Size is constant (e.g. a 4-byte luminance accumulation SSBO) |

**Tier 2 — resolution-dependent** (destroyed + recreated in `onReinitRendering()`):

These objects encode the backbuffer size either directly (image dimensions,
framebuffer dimensions) or indirectly (a `ComputeCall` that binds a
resolution-dependent image gets its descriptor set invalidated when that
image is recreated).

| Resource type | Why it's resolution-dependent |
|---------------|------------------------------|
| `Image` with `kResolutionDependentImages` pool | Pixel dimensions baked in at allocation |
| `Framebuffer` | Stores `VkImageView` — always references a specific `Image` |
| `DrawCall` / `ComputeCall` | `VkDescriptorSet` contains `VkImageView` handles — invalid after image recreation |

**Tier 3 — per-frame** (rebuilt every frame inside `render()`):

These are not stored as named refs at all — they are ring-allocated and
reset each frame by `UniformManager::onFrameEnded()`.

| What | Mechanism |
|------|-----------|
| Per-instance UBO data | `allocateAndUpdateUniformMemory` / `updateUniformMemory` |
| Per-frame UBO data | `UniformManager::updatePerFrameData` |

#### `kResourceVolatile` flag

```cpp
ImageManager::addResourceFlags(ref, Dod::Resources::ResourceFlags::kResourceVolatile);
```

Marking a resource `kResourceVolatile` tells the resource manager that this
ref is temporary — it will not be iterated by `createAllResources()` /
`destroyResources(_activeRefs)` at the global level. Use it for every
resource you manage yourself in `onReinitRendering()`. Without it the ref
would also appear in global teardown passes and be double-freed.

All resolution-dependent images and all compute/draw calls created in
`onReinitRendering()` should be marked volatile. Fixed-size buffers created
in `init()` are also typically marked volatile so the global pool doesn't
manage them separately.

#### Canonical pattern — compute pass (Bloom as reference)

```cpp
// ─── Permanent refs (file-scope anonymous namespace) ─────────────────
PipelineRef         _brightLumPipelineRef;
BufferRef           _lumBuffer;           // fixed-size SSBO

// ─── Resolution-dependent refs ────────────────────────────────────────
ImageRef            _brightImageRef;
ComputeCallRef      _lumComputeCallRef;

// ─────────────────────────────────────────────────────────────────────
void MyPass::init()
{
  // 1. Fixed-size buffers
  _lumBuffer = BufferManager::createBuffer(_N(MyLumBuffer));
  BufferManager::resetToDefault(_lumBuffer);
  BufferManager::addResourceFlags(_lumBuffer, ResourceFlags::kResourceVolatile);
  BufferManager::_descBufferType(_lumBuffer)     = BufferType::kStorage;
  BufferManager::_descMemoryPoolType(_lumBuffer) = MemoryPoolType::kStaticBuffers;
  BufferManager::_descSizeInBytes(_lumBuffer)    = sizeof(float);
  BufferManager::createResources({_lumBuffer});

  // 2. GpuProgram is loaded globally — just look it up by name
  GpuProgramRef compProg =
      GpuProgramManager::getResourceByName("my_pass.comp");

  // 3. PipelineLayout — reflect from SPIR-V
  PipelineLayoutRef pl = PipelineLayoutManager::createPipelineLayout(_N(MyPass));
  PipelineLayoutManager::resetToDefault(pl);
  GpuProgramManager::reflectPipelineLayout(32u, {compProg}, pl);
  PipelineLayoutManager::createResources({pl});

  // 4. Pipeline
  _brightLumPipelineRef = PipelineManager::createPipeline(_N(MyPass));
  PipelineManager::resetToDefault(_brightLumPipelineRef);
  PipelineManager::_descComputeProgram(_brightLumPipelineRef) = compProg;
  PipelineManager::_descPipelineLayout(_brightLumPipelineRef) = pl;
  PipelineManager::createResources({_brightLumPipelineRef});
}

// ─────────────────────────────────────────────────────────────────────
void MyPass::onReinitRendering()
{
  // Destroy old resolution-dependent resources (guard with isValid())
  if (_brightImageRef.isValid())
    ImageManager::destroyImagesAndResources({_brightImageRef});

  if (_lumComputeCallRef.isValid())
  {
    ComputeCallManager::destroyResources({_lumComputeCallRef});
    ComputeCallManager::destroyComputeCall(_lumComputeCallRef);
  }

  // Recreate image at new backbuffer size
  const glm::uvec2 dim = RenderSystem::_backbufferDimensions / 2u;

  _brightImageRef = ImageManager::createImage(_N(MyBright));
  ImageManager::resetToDefault(_brightImageRef);
  ImageManager::addResourceFlags(_brightImageRef, ResourceFlags::kResourceVolatile);
  ImageManager::_descMemoryPoolType(_brightImageRef) =
      MemoryPoolType::kResolutionDependentImages;
  ImageManager::_descDimensions(_brightImageRef) = glm::uvec3(dim, 1u);
  ImageManager::_descImageFormat(_brightImageRef) = Format::kR16G16B16A16Float;
  ImageManager::_descImageType(_brightImageRef)   = ImageType::kTexture;
  ImageManager::_descImageFlags(_brightImageRef) &= ~ImageFlags::kUsageAttachment;
  ImageManager::_descImageFlags(_brightImageRef) |=  ImageFlags::kUsageStorage;
  ImageManager::createResources({_brightImageRef});

  // Recreate compute call (its descriptor set points to the new image)
  _lumComputeCallRef = ComputeCallManager::createComputeCall(_N(MyPass));
  ComputeCallManager::resetToDefault(_lumComputeCallRef);
  ComputeCallManager::addResourceFlags(_lumComputeCallRef, ResourceFlags::kResourceVolatile);
  ComputeCallManager::_descPipeline(_lumComputeCallRef)   = _brightLumPipelineRef;
  ComputeCallManager::_descDimensions(_lumComputeCallRef) =
      glm::uvec3((dim.x + 7u) / 8u, (dim.y + 7u) / 8u, 1u);

  ComputeCallManager::bindBuffer(
      _lumComputeCallRef, _N(PerInstance), GpuProgramType::kCompute,
      UniformManager::_perInstanceUniformBuffer,
      UboType::kPerInstanceCompute, sizeof(MyPerInstanceData));
  ComputeCallManager::bindImage(
      _lumComputeCallRef, _N(outputTex), GpuProgramType::kCompute,
      _brightImageRef, Samplers::kInvalidSampler);
  ComputeCallManager::bindImage(
      _lumComputeCallRef, _N(inputTex), GpuProgramType::kCompute,
      ImageManager::getResourceByName(_N(Scene)), Samplers::kLinearRepeat);

  ComputeCallManager::createResources({_lumComputeCallRef});
}

// ─────────────────────────────────────────────────────────────────────
void MyPass::destroy()
{
  // Destroy only Tier-1 (permanent) resources in reverse creation order:
  PipelineManager::destroyPipelinesAndResources({_brightLumPipelineRef});
  // PipelineLayout: destroyPipelineLayoutsAndResources({pl});
  // Buffer:
  BufferManager::destroyBuffersAndResources({_lumBuffer});
  // GpuPrograms are global — do not destroy them here
}
```

#### Graphics pass — additional resources

A graphics pass additionally manages a `RenderPass` and `Framebuffer`.
Both are resolution-dependent when the framebuffer size tracks the backbuffer,
but `RenderPass` itself (just attachment format descriptions) never changes
and can live in `init()`. Only the `Framebuffer` must go into `onReinitRendering()`.

```
init()
  └── RenderPass        ← format descriptors only, survives resize
  └── Pipeline          ← references RenderPass (but not Framebuffer)

onReinitRendering()
  └── destroy Framebuffer
  └── destroy DrawCalls
  └── recreate Images (if resolution-dependent)
  └── recreate Framebuffer  ← now binds new ImageViews
  └── recreate DrawCalls    ← now bind new ImageRefs

destroy()
  └── Pipeline
  └── RenderPass
  └── (Images / Framebuffer already gone from onReinitRendering)
```

#### `destroyResources` vs `destroy*AndResources`

| Helper | What it frees | When to use |
|--------|--------------|-------------|
| `destroyResources({ref})` | Vulkan object only; pool slot stays alive | Resize: keep the ref, rebuild Vulkan object next frame |
| `destroy*AndResources({ref})` | Vulkan object + pool slot | Full teardown in `destroy()` or when the ref is never needed again |

The canonical resize pattern for a single resource:

```cpp
// In onReinitRendering():
ImageManager::destroyImagesAndResources({_myImageRef}); // free slot
_myImageRef = ImageManager::createImage(_N(MyImage));   // fresh slot
// ... fill desc fields ...
ImageManager::createResources({_myImageRef});
```

#### Common mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Creating a `ComputeCall` in `init()` that binds a resolution-dependent image | Descriptor set holds stale `VkImageView` after resize → GPU crash | Move `ComputeCall` to `onReinitRendering()` |
| Forgetting `kResourceVolatile` on images created in `onReinitRendering()` | Double-free on shutdown: global teardown tries to destroy an already-gone image | Always call `addResourceFlags(ref, kResourceVolatile)` |
| Calling `destroyImagesAndResources` without an `isValid()` guard | Assert / crash on first call before the image has ever been created | Guard with `if (ref.isValid())` |
| Destroying a `Pipeline` before the `DrawCall`/`ComputeCall` that references it | Vulkan validation error: descriptor set references destroyed pipeline | Always destroy draw/compute calls first |
| Using `MemoryPoolType::kStaticBuffers` for a per-frame host-visible write | No mapped memory — `getGpuMemory()` asserts | Use `kStaticStagingBuffers` for host-visible |

---

## 11. Example: Forward Transparent Pass

A forward pass renders geometry that cannot be deferred (transparent objects,
alpha-blended surfaces). It reads the filled G-Buffer depth for depth testing and
writes color additively over the existing lighting result.

### What changes versus the generic pass above

- Uses the **existing G-Buffer depth** as a read-only depth attachment.
- Writes over the **existing `Scene` image** (additive or alpha blend) rather
  than a new image.
- Iterates visible draw calls tagged with a **new material pass** `ForwardTransparent`.
- Needs a **blend state** set to additive or source-alpha.
- **No clear** — loads the previous content of the `Scene` attachment.

### New material pass

Add to `app/config/material_pass_config.json`:

```json
{
  "name": "ForwardTransparent",
  "materialPassId": 16
}
```

Materials that should render in this pass set `materialPassMask |= (1 << 4)` (bit 4).
In the material JSON:

```json
{ "materialPassMask": 17 }   // 0x01 (GBuffer) | 0x10 (ForwardTransparent)
```

Or for transparent-only materials that skip the G-Buffer:

```json
{ "materialPassMask": 16 }
```

### Header

```cpp
// IntrinsicRendererRenderPassForwardTransparent.h
struct ForwardTransparent
{
  static void init();
  static void onReinitRendering();
  static void destroy();
  static void render(float p_DeltaT, Components::CameraRef p_CameraRef);

  static PipelineLayoutRef _pipelineLayoutRef;  // reflects forward.vert + forward.frag
  // No volatile image — we write into the existing Scene image
  static RenderPassRef  _renderPassRef;
  static FramebufferRef _framebufferRef;
};
```

### init() — create pipeline with alpha blend

```cpp
void ForwardTransparent::init()
{
  // Pipeline layout
  _pipelineLayoutRef = PipelineLayoutManager::createPipelineLayout(
      _N(ForwardTransparent));
  PipelineLayoutManager::resetToDefault(_pipelineLayoutRef);
  GpuProgramManager::reflectPipelineLayout(
      8u,
      { GpuProgramManager::getResourceByName(_N(forward_transparent.vert)),
        GpuProgramManager::getResourceByName(_N(forward_transparent.frag)) },
      _pipelineLayoutRef);
  PipelineLayoutManager::createResources({ _pipelineLayoutRef });

  // Pipeline — no depth write, back-to-front expected from caller,
  // source-alpha blending
  PipelineRef pip = PipelineManager::createPipeline(_N(ForwardTransparent));
  PipelineManager::resetToDefault(pip);
  PipelineManager::_descVertexProgram(pip) =
      GpuProgramManager::getResourceByName(_N(forward_transparent.vert));
  PipelineManager::_descFragmentProgram(pip) =
      GpuProgramManager::getResourceByName(_N(forward_transparent.frag));
  PipelineManager::_descPipelineLayout(pip)      = _pipelineLayoutRef;
  PipelineManager::_descDepthStencilState(pip)   = DepthStencilStates::kDefaultNoWrite;
  PipelineManager::_descBlendStates(pip).clear();
  PipelineManager::_descBlendStates(pip).push_back(BlendStates::kAlphaBlend);
  // _descRenderPass set in onReinitRendering after the render pass is created
  PipelineManager::createResources({ pip });
}
```

### onReinitRendering() — share Scene + GBufferDepth

```cpp
void ForwardTransparent::onReinitRendering()
{
  // Cleanup
  if (_renderPassRef.isValid())
    RenderPassManager::destroyRenderPassesAndResources({ _renderPassRef });
  if (_framebufferRef.isValid())
    FramebufferManager::destroyFramebuffersAndResources({ _framebufferRef });

  ImageRef sceneRef  = ImageManager::getResourceByName(_N(Scene));
  ImageRef depthRef  = ImageManager::getResourceByName(_N(GBufferDepth));

  // Render pass: LOAD existing color (no clear), depth READ-ONLY
  _renderPassRef = RenderPassManager::createRenderPass(_N(ForwardTransparent));
  {
    RenderPassManager::resetToDefault(_renderPassRef);
    // Color attachment — load existing content (no clear flag)
    AttachmentDescription colorAtt = {
        (uint8_t)Format::kR16G16B16A16Float,
        AttachmentFlags::kLoadFromPreviousPass };
    // Depth attachment — read-only (test but don't write)
    AttachmentDescription depthAtt = {
        (uint8_t)RenderSystem::_depthStencilFormatToUse,
        AttachmentFlags::kLoadFromPreviousPass };
    RenderPassManager::_descAttachments(_renderPassRef).push_back(colorAtt);
    RenderPassManager::_descAttachments(_renderPassRef).push_back(depthAtt);
  }
  RenderPassManager::createResources({ _renderPassRef });

  // Framebuffer — attach the existing Scene and GBufferDepth images
  _framebufferRef = FramebufferManager::createFramebuffer(_N(ForwardTransparent));
  {
    FramebufferManager::resetToDefault(_framebufferRef);
    FramebufferManager::addResourceFlags(
        _framebufferRef, Dod::Resources::ResourceFlags::kResourceVolatile);
    FramebufferManager::_descDimensions(_framebufferRef) =
        RenderSystem::_backbufferDimensions;
    FramebufferManager::_descRenderPass(_framebufferRef)  = _renderPassRef;
    FramebufferManager::_descAttachedImages(_framebufferRef)
        .push_back(AttachmentInfo(sceneRef));
    FramebufferManager::_descAttachedImages(_framebufferRef)
        .push_back(AttachmentInfo(depthRef));
  }
  FramebufferManager::createResources({ _framebufferRef });

  // Wire the render pass into the pipeline
  PipelineManager::_descRenderPass(_pipelineRef) = _renderPassRef;
  PipelineManager::createResources({ _pipelineRef });
}
```

### render()

```cpp
void ForwardTransparent::render(float p_DeltaT,
                                Components::CameraRef p_CameraRef)
{
  _INTR_PROFILE_CPU("Render Pass", "Forward Transparent");
  _INTR_PROFILE_GPU("Forward Transparent");

  ImageRef sceneRef = ImageManager::getResourceByName(_N(Scene));
  ImageRef depthRef = ImageManager::getResourceByName(_N(GBufferDepth));

  // Collect draw calls for the ForwardTransparent material pass
  static DrawCallRefArray visibleDCs;
  visibleDCs.clear();
  RenderProcess::Default::getVisibleDrawCalls(
      p_CameraRef, 0u,
      MaterialManager::getMaterialPassId(_N(ForwardTransparent)))
      .copy(visibleDCs);

  if (visibleDCs.empty()) return;   // nothing to draw this frame

  // Sort back-to-front for correct alpha blending
  DrawCallManager::sortDrawCallsBackToFront(visibleDCs);

  // Upload per-instance data for each visible mesh
  Components::MeshManager::updatePerInstanceData(p_CameraRef, 0u);
  Components::MeshManager::updateUniformData(visibleDCs);

  // Scene was left in SHADER_READ_ONLY by Clustering; bring it back to COLOR_ATTACHMENT
  ImageManager::insertImageMemoryBarrier(
      sceneRef,
      VK_IMAGE_LAYOUT_UNDEFINED,
      VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
      VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
      VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

  // Depth must be readable for depth test
  ImageManager::insertImageMemoryBarrier(
      depthRef,
      VK_IMAGE_LAYOUT_UNDEFINED,
      VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL,
      VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
      VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT);

  // No clear values — we LOAD both attachments
  RenderSystem::beginRenderPass(
      _renderPassRef, _framebufferRef,
      VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS);

  DrawCallDispatcher::queueDrawCalls(visibleDCs, _renderPassRef, _framebufferRef);

  RenderSystem::endRenderPass(_renderPassRef);

  // Transition Scene back to readable for post-processing
  ImageManager::insertImageMemoryBarrier(
      sceneRef,
      VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
      VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
      VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
      VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
}
```

### Placement in renderer_config.json

```json
{ "type": "RenderPassClustering" },
{ "type": "RenderPassForwardTransparent" },   // AFTER Clustering, BEFORE Bloom
{ "type": "RenderPassBloom" },
```

---

## 12. Example: Ray Tracing Pass

Ray tracing requires `VK_KHR_ray_tracing_pipeline` (and its dependencies). The
engine as shipped does not include it — the steps below describe how you would
add it from scratch. This is a significant addition, not a one-afternoon task.

### New Vulkan extensions required

These must all be enabled at device creation time in `IntrinsicRendererRenderSystem.cpp`:

```cpp
// Required chain (order matters — each depends on the previous)
"VK_KHR_deferred_host_operations"
"VK_KHR_buffer_device_address"       // also needs feature flag
"VK_KHR_acceleration_structure"
"VK_KHR_ray_tracing_pipeline"
"VK_EXT_descriptor_indexing"         // likely already present
```

In `RenderSystem::init()` where extensions are enumerated and enabled:

```cpp
// Feature chain — must be linked via pNext
VkPhysicalDeviceBufferDeviceAddressFeatures bufferDeviceAddressFeatures = {
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES };
bufferDeviceAddressFeatures.bufferDeviceAddress = VK_TRUE;

VkPhysicalDeviceAccelerationStructureFeaturesKHR accelFeatures = {
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR };
accelFeatures.accelerationStructure = VK_TRUE;
accelFeatures.pNext = &bufferDeviceAddressFeatures;

VkPhysicalDeviceRayTracingPipelineFeaturesKHR rtFeatures = {
    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR };
rtFeatures.rayTracingPipeline = VK_TRUE;
rtFeatures.pNext = &accelFeatures;

// Chain into VkDeviceCreateInfo::pNext
deviceCreateInfo.pNext = &rtFeatures;
```

Also query `VkPhysicalDeviceRayTracingPipelinePropertiesKHR` to get
`shaderGroupHandleSize` and `shaderGroupBaseAlignment` (needed for the SBT).

Load the function pointers (they are extension functions, not in the Vulkan core):

```cpp
auto vkCreateAccelerationStructureKHR =
    (PFN_vkCreateAccelerationStructureKHR)
    vkGetDeviceProcAddr(device, "vkCreateAccelerationStructureKHR");
// ... vkDestroyAccelerationStructureKHR
// ... vkGetAccelerationStructureBuildSizesKHR
// ... vkCmdBuildAccelerationStructuresKHR
// ... vkGetAccelerationStructureDeviceAddressKHR
// ... vkCreateRayTracingPipelinesKHR
// ... vkGetRayTracingShaderGroupHandlesKHR
// ... vkCmdTraceRaysKHR
```

Store them as static members on `RenderSystem` for other passes to use.

### Pass structure overview

```
init()
 ├── createShadersAndPipeline()    – raygen, miss, closest-hit SPIR-V → pipeline
 └── createShaderBindingTable()    – SBT buffer with aligned handles

onReinitRendering()
 └── (re)create output image

buildBLAS()                        – called once per mesh (or on mesh change)
 └── one VkAccelerationStructureKHR per mesh (triangle geometry)

buildTLAS()                        – called every frame (or when scene changes)
 └── one VkAccelerationStructureKHR with N instances pointing to BLASes

render()
 ├── buildTLAS()                   – or update if only transforms changed
 ├── updateDescriptorSet()         – bind TLAS + output image + G-Buffer inputs
 ├── insertImageMemoryBarrier()    – output UNDEFINED → GENERAL
 ├── vkCmdTraceRaysKHR()           – dispatch rays
 └── insertImageMemoryBarrier()    – output GENERAL → SHADER_READ_ONLY_OPTIMAL
```

### Building a BLAS

A BLAS (Bottom-Level Acceleration Structure) represents the triangle geometry of
one mesh. Build it once and cache it in a `BufferRef` or a
`VkAccelerationStructureKHR` stored alongside the mesh data.

```cpp
void buildBLAS(MeshRef meshRef)
{
  // Get the vertex and index buffers for this mesh
  BufferRef vbRef = MeshManager::_vertexBuffer(meshRef);
  BufferRef ibRef = MeshManager::_indexBuffer(meshRef);

  // Describe the triangle geometry
  VkAccelerationStructureGeometryKHR geometry = {};
  geometry.sType        = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
  geometry.geometryType = VK_GEOMETRY_TYPE_TRIANGLES_KHR;
  geometry.flags        = VK_GEOMETRY_OPAQUE_BIT_KHR;

  auto& tris = geometry.geometry.triangles;
  tris.sType         = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR;
  tris.vertexFormat  = VK_FORMAT_R16G16B16_SFLOAT;  // packed half-float positions
  tris.vertexData.deviceAddress =
      getBufferDeviceAddress(RenderSystem::_vkDevice, BufferManager::_vkBuffer(vbRef));
  tris.vertexStride  = sizeof(uint16_t) * 4;  // xyz + padding
  tris.maxVertex     = MeshManager::_vertexCount(meshRef) - 1;
  tris.indexType     = VK_INDEX_TYPE_UINT32;
  tris.indexData.deviceAddress =
      getBufferDeviceAddress(RenderSystem::_vkDevice, BufferManager::_vkBuffer(ibRef));

  uint32_t primitiveCount = MeshManager::_indexCount(meshRef) / 3;

  // Query required sizes
  VkAccelerationStructureBuildGeometryInfoKHR buildInfo = {};
  buildInfo.sType         = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
  buildInfo.type          = VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
  buildInfo.flags         = VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
  buildInfo.geometryCount = 1u;
  buildInfo.pGeometries   = &geometry;

  VkAccelerationStructureBuildSizesInfoKHR sizes = {
      VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR };
  vkGetAccelerationStructureBuildSizesKHR(
      RenderSystem::_vkDevice,
      VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
      &buildInfo, &primitiveCount, &sizes);

  // Allocate BLAS buffer and scratch buffer
  // (use BufferManager with STORAGE_BIT | VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR)
  VkBuffer blasBuffer   = allocateBuffer(sizes.accelerationStructureSize,
      VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR);
  VkBuffer scratchBuffer = allocateBuffer(sizes.buildScratchSize,
      VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT);

  // Create the AS object
  VkAccelerationStructureCreateInfoKHR createInfo = {};
  createInfo.sType  = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR;
  createInfo.buffer = blasBuffer;
  createInfo.size   = sizes.accelerationStructureSize;
  createInfo.type   = VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;

  VkAccelerationStructureKHR blas;
  vkCreateAccelerationStructureKHR(RenderSystem::_vkDevice, &createInfo, nullptr, &blas);

  // Build on the GPU
  buildInfo.dstAccelerationStructure  = blas;
  buildInfo.scratchData.deviceAddress = getBufferDeviceAddress(RenderSystem::_vkDevice,
                                                               scratchBuffer);
  VkAccelerationStructureBuildRangeInfoKHR rangeInfo = { primitiveCount };
  const VkAccelerationStructureBuildRangeInfoKHR* pRangeInfo = &rangeInfo;

  VkCommandBuffer cmd = RenderSystem::beginTemporaryCommandBuffer();
  vkCmdBuildAccelerationStructuresKHR(cmd, 1u, &buildInfo, &pRangeInfo);
  RenderSystem::flushTemporaryCommandBuffer();

  // Store blas handle alongside mesh data (add a static map or extend MeshData)
  _blasMap[meshRef] = blas;
}
```

### Building a TLAS every frame

A TLAS (Top-Level Acceleration Structure) contains one instance per visible
object, each pointing to a BLAS and carrying a world transform.

```cpp
void buildTLAS(Components::CameraRef p_CameraRef)
{
  // Collect visible mesh instances
  const DrawCallRefArray& dcs =
      RenderProcess::Default::getVisibleDrawCalls(p_CameraRef, 0u,
          MaterialManager::getMaterialPassId(_N(GBufferDefault)));

  _INTR_ARRAY(VkAccelerationStructureInstanceKHR) instances;
  for (DrawCallRef dc : dcs)
  {
    MeshRef mesh    = DrawCallManager::_descMesh(dc);
    NodeRef node    = DrawCallManager::_descNode(dc);
    glm::mat4 world = NodeManager::getWorldTransform(node);

    VkAccelerationStructureInstanceKHR inst = {};
    // VkTransformMatrixKHR is a row-major 3x4 matrix
    memcpy(&inst.transform, glm::value_ptr(glm::transpose(world)), sizeof(inst.transform));
    inst.instanceCustomIndex                    = instances.size();  // gl_InstanceCustomIndexEXT
    inst.mask                                   = 0xFF;
    inst.instanceShaderBindingTableRecordOffset = 0u;  // offset into hit group table
    inst.flags                                  = VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
    inst.accelerationStructureReference         =
        getAccelerationStructureAddress(RenderSystem::_vkDevice, _blasMap[mesh]);

    instances.push_back(inst);
  }

  // Upload instance data to a device-visible buffer, then build TLAS
  // (pattern identical to BLAS build — query sizes, allocate, vkCmdBuildAccelerationStructuresKHR)
  // For dynamic scenes use VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_BUILD_BIT_KHR
  // or UPDATE mode if only transforms changed.
}
```

### Creating the RT pipeline

```cpp
void createRTPipeline()
{
  // Load SPIR-V shader modules
  VkShaderModule raygenModule = loadSPIRV("rt_raygen.rgen.spv");
  VkShaderModule missModule   = loadSPIRV("rt_miss.rmiss.spv");
  VkShaderModule chitModule   = loadSPIRV("rt_chit.rchit.spv");

  VkPipelineShaderStageCreateInfo stages[3];
  stages[0] = makeStage(raygenModule, VK_SHADER_STAGE_RAYGEN_BIT_KHR,   "main");
  stages[1] = makeStage(missModule,   VK_SHADER_STAGE_MISS_BIT_KHR,     "main");
  stages[2] = makeStage(chitModule,   VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR, "main");

  // Shader groups: one per logical entry point
  VkRayTracingShaderGroupCreateInfoKHR groups[3] = {};
  // Raygen group (general type)
  groups[0].sType              = VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
  groups[0].type               = VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR;
  groups[0].generalShader      = 0;  // index into stages[]
  groups[0].closestHitShader   = VK_SHADER_UNUSED_KHR;
  groups[0].anyHitShader       = VK_SHADER_UNUSED_KHR;
  groups[0].intersectionShader = VK_SHADER_UNUSED_KHR;
  // Miss group
  groups[1] = groups[0];
  groups[1].generalShader = 1;
  // Hit group (triangles type)
  groups[2].sType              = VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
  groups[2].type               = VK_RAY_TRACING_SHADER_GROUP_TYPE_TRIANGLES_HIT_GROUP_KHR;
  groups[2].generalShader      = VK_SHADER_UNUSED_KHR;
  groups[2].closestHitShader   = 2;  // index into stages[]
  groups[2].anyHitShader       = VK_SHADER_UNUSED_KHR;
  groups[2].intersectionShader = VK_SHADER_UNUSED_KHR;

  VkRayTracingPipelineCreateInfoKHR pipelineCI = {};
  pipelineCI.sType                        = VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_CREATE_INFO_KHR;
  pipelineCI.stageCount                   = 3u;
  pipelineCI.pStages                      = stages;
  pipelineCI.groupCount                   = 3u;
  pipelineCI.pGroups                      = groups;
  pipelineCI.maxPipelineRayRecursionDepth = 1u;  // 1 = primary rays only (no reflections)
  pipelineCI.layout                       = _rtPipelineLayout;

  vkCreateRayTracingPipelinesKHR(RenderSystem::_vkDevice,
      VK_NULL_HANDLE, RenderSystem::_vkPipelineCache,
      1u, &pipelineCI, nullptr, &_rtPipeline);
}
```

### Creating the Shader Binding Table (SBT)

The SBT is a GPU buffer containing one aligned handle per shader group.

```cpp
void createSBT()
{
  // Query hardware handle size and alignment from device properties
  uint32_t handleSize      = _rtProperties.shaderGroupHandleSize;
  uint32_t handleAlignment = _rtProperties.shaderGroupHandleAlignment;
  uint32_t groupCount      = 3u;  // raygen + miss + hit

  uint32_t sbtStride = alignUp(handleSize, handleAlignment);
  uint32_t sbtSize   = groupCount * sbtStride;

  // Get raw handles from the pipeline
  std::vector<uint8_t> handles(groupCount * handleSize);
  vkGetRayTracingShaderGroupHandlesKHR(
      RenderSystem::_vkDevice, _rtPipeline,
      0u, groupCount, handles.size(), handles.data());

  // Allocate a host-visible, device-addressable buffer
  // Must have VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR
  //           | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT
  _sbtBuffer = allocateSBTBuffer(sbtSize);
  uint8_t* mapped = mapSBTBuffer(_sbtBuffer);

  // Copy each handle at the correct aligned offset
  for (uint32_t i = 0; i < groupCount; ++i)
    memcpy(mapped + i * sbtStride, handles.data() + i * handleSize, handleSize);

  unmapSBTBuffer(_sbtBuffer);

  // Store strided device address regions for dispatch
  VkDeviceAddress sbtBase = getBufferDeviceAddress(RenderSystem::_vkDevice, _sbtBuffer);
  _raygenRegion   = { sbtBase + 0 * sbtStride, sbtStride, sbtStride };
  _missRegion     = { sbtBase + 1 * sbtStride, sbtStride, sbtStride };
  _hitRegion      = { sbtBase + 2 * sbtStride, sbtStride, sbtStride };
  _callableRegion = {};  // no callable shaders
}
```

### render()

```cpp
void RayTracing::render(float p_DeltaT, Components::CameraRef p_CameraRef)
{
  _INTR_PROFILE_CPU("Render Pass", "Ray Tracing");
  _INTR_PROFILE_GPU("Ray Tracing");

  VkCommandBuffer cmd = RenderSystem::getPrimaryCommandBuffer();

  // Rebuild TLAS for this frame's visible geometry
  buildTLAS(p_CameraRef);

  // Transition output image to GENERAL (storage write)
  ImageManager::insertImageMemoryBarrier(
      _rtOutputImageRef,
      VK_IMAGE_LAYOUT_UNDEFINED,
      VK_IMAGE_LAYOUT_GENERAL,
      VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
      VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR);

  // Bind pipeline and descriptor sets
  vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR, _rtPipeline);
  vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR,
      _rtPipelineLayout, 0u, 1u, &_rtDescriptorSet, 0u, nullptr);

  // Dispatch rays — one ray per pixel
  const glm::uvec2 res = RenderSystem::_backbufferDimensions;
  vkCmdTraceRaysKHR(cmd,
      &_raygenRegion, &_missRegion, &_hitRegion, &_callableRegion,
      res.x, res.y, 1u);

  // Transition result to readable so it can be composited
  ImageManager::insertImageMemoryBarrier(
      _rtOutputImageRef,
      VK_IMAGE_LAYOUT_GENERAL,
      VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
      VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
      VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
}
```

### Minimal raygen shader

```glsl
// app/assets/shaders/rt_raygen.rgen.glsl
#version 460
#extension GL_EXT_ray_tracing : require
#include "lib_buffers.glsl"   // PerFrameData with invViewProjMatrix, camPos

layout(set = 0, binding = 0) uniform accelerationStructureEXT topLevelAS;
layout(set = 0, binding = 1, rgba16f) uniform image2D outputImage;

layout(location = 0) rayPayloadEXT vec4 payload;

void main()
{
  // Reconstruct ray from screen pixel
  vec2 uv = (vec2(gl_LaunchIDEXT.xy) + 0.5) / vec2(gl_LaunchSizeEXT.xy);
  vec2 ndc = uv * 2.0 - 1.0;

  vec4 rayOriginH    = uPerFrame.invViewProjMatrix * vec4(ndc, 0.0, 1.0);
  vec4 rayEndH       = uPerFrame.invViewProjMatrix * vec4(ndc, 1.0, 1.0);
  vec3 rayOrigin     = rayOriginH.xyz / rayOriginH.w;
  vec3 rayDir        = normalize(rayEndH.xyz / rayEndH.w - rayOrigin);

  payload = vec4(0.0);

  traceRayEXT(
      topLevelAS,
      gl_RayFlagsOpaqueEXT,   // ray flags
      0xFF,                   // cull mask
      0u,                     // sbtRecordOffset
      0u,                     // sbtRecordStride
      0u,                     // miss index
      rayOrigin,
      0.001,                  // tMin
      rayDir,
      10000.0,                // tMax
      0                       // payload location
  );

  imageStore(outputImage, ivec2(gl_LaunchIDEXT.xy), payload);
}
```

### Placement in renderer_config.json

```json
{ "type": "RenderPassClustering" },
{ "type": "RenderPassRayTracing" },          // after deferred lighting
{ "type": "GenericFullscreen",               // composite RT result over scene
    "name": "RTComposite",
    "fragmentGpuProgram": "rt_composite.frag",
    "inputs": [
      ["Image", "Scene",        "sceneTex",    "Fragment", "LinearClamp"],
      ["Image", "RTOutput",     "rtTex",       "Fragment", "LinearClamp"],
      ["Image", "GBufferDepth", "depthTex",    "Fragment", "NearestClamp"]
    ],
    "outputs": [ ["Scene"] ]
},
{ "type": "RenderPassBloom" },
```

### Practical notes on adding RT to this engine

- **Buffer device addresses**: every BLAS and TLAS scratch buffer needs
  `VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT`. The current `BufferManager` would
  need a new `BufferType` or usage flag for this. The simplest approach is to add
  a `kRaytracingBuffer` enum value and handle it in the buffer creation code.
- **BLAS lifecycle**: BLASes should be rebuilt when a mesh is loaded/unloaded.
  Hook into `MeshManager::createResources` / `destroyResources`.
- **TLAS update vs. rebuild**: if only transforms change, use
  `VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR` and rebuild with
  `mode = VK_BUILD_ACCELERATION_STRUCTURE_MODE_UPDATE_KHR`. This is ~10× faster
  than a full rebuild.
- **Descriptor layout**: the TLAS is bound as
  `VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR`. The output image is
  `VK_DESCRIPTOR_TYPE_STORAGE_IMAGE`. These cannot use the existing
  `GpuProgramManager::reflectPipelineLayout` (which does not know about RT
  descriptor types) — you'll need to build the descriptor set layout manually
  with `vkCreateDescriptorSetLayout`.
- **Shadow/AO**: if you only want RT for shadows or ambient occlusion rather than
  full path tracing, `maxPipelineRayRecursionDepth = 1` and a single closest-hit
  shader that writes 0.0/1.0 (occluded/visible) is sufficient — much cheaper than
  full GI.

---

## 13. Asset Pipeline

### Mesh import

1. Export model from your DCC tool as FBX
2. Place in the assets source folder
3. In IntrinsicEd: **Asset Management → Import FBX**
4. The importer generates:
   - `app/managers/meshes/<name>.mesh.json`
   - Cooked binary mesh data (positions, normals, UVs, tangents)
   - PhysX collision mesh if requested

The `.mesh.json` file records sub-mesh count, vertex count, and material slot
names. The material slot names must match material files of the same name in
`app/managers/materials/`.

### Texture import

Textures must be converted to DDS before the engine can load them:

- **BC1** — RGB, no alpha, smallest (for albedo without transparency)
- **BC3** — RGBA (for albedo with alpha / cutout)
- **BC5** — RG (for normal maps — store X and Y, reconstruct Z in shader)
- **BC7** — high-quality RGBA (for important albedos, UI)

Use Microsoft `texconv.exe`:
```
texconv -f BC7_UNORM -o app/assets/textures/ my_texture.png
```

Then create `app/managers/images/my_texture.image.json` pointing to the DDS file.

### Procedurally generated textures

Some textures are generated at runtime by compute shaders
(`DynamicTextureGeneration` pass). They are defined in `RenderSystem.cpp`
via `addDynamicGeneratedTexture()` and reference a compute shader. Generated
textures are registered in the bindless array automatically.

### Physics mesh cooking

PhysX requires a pre-cooked convex hull for `shapeType = 3`. The cooking happens
in `IntrinsicAssetManagement` during FBX import. If you update a mesh and need
to re-cook: re-import through the editor or call
`AssetManagement::cookPhysicsMesh(meshRef)` in code.

---

## 14. Lua Scripting

### Script component setup

1. Create `app/scripts/my_script.lua`
2. Create `app/managers/scripts/my_script.script.json`:

```json
{ "name": "my_script", "scriptFileName": "scripts/my_script.lua" }
```

3. Add a Script component to your entity:

```json
{ "type": "Script", "properties": { "scriptName": "my_script" } }
```

### Script lifecycle

```lua
-- Called once when the entity is spawned
function onCreate(entityRef)
  -- store entity ref for later use
  myEntity = entityRef
end

-- Called every frame
function tick(entityRef, deltaT)
  local node = Node.getComponent(entityRef)
  local pos  = Node.getPosition(node)
  Node.setPosition(node, pos + glm.vec3(0, deltaT, 0))
  Node.rebuildTransforms()
end

-- Called when the entity is destroyed
function onDestroy(entityRef)
end
```

### Exposed engine API

**Entity:**
```lua
local ref = Entity.getEntityByName("MyObject")
local name = Entity.getName(ref)
```

**Node:**
```lua
local node = Node.getComponent(entityRef)
Node.getPosition(node)              -- returns glm.vec3
Node.setPosition(node, vec3)
Node.getOrientation(node)           -- returns glm.quat
Node.setOrientation(node, quat)
Node.getSize(node)
Node.setSize(node, vec3)
Node.rebuildTransforms()            -- required after bulk changes
```

**Camera:**
```lua
local cam = Camera.getComponent(entityRef)
Camera.setFov(cam, 75.0)
```

**Input:**
```lua
if Input.isKeyPressed(Key.W) then ... end
if Input.isMouseButtonPressed(MouseButton.Left) then ... end
local dx, dy = Input.getMouseDelta()
```

**GLM math in Lua:**
```lua
local v = glm.vec3(1, 0, 0)
local q = glm.quat(glm.vec3(0, math.pi, 0))   -- from euler angles
local m = glm.mat4(1.0)
```

---

## 15. Procedural Systems

### Compute pipeline overview

`DynamicMeshGeneration` runs a multi-stage compute pipeline per procedural mesh.
Two algorithms are supported, selected per mesh via the `.procedural_mesh.json`
config:

**Marching Cubes (MC)** — 3 stages, used by Julia and Mandelbulb (64³ grid, localSize 8):

```
Stage 1 — voxel shader        writes SDF density into _VoxelBuffer (flat float[])
Stage 2 — normal_generation   reads _VoxelBuffer, writes per-voxel gradients
                               into a 3D rgba16f texture (_NormalsTex)
Stage 3 — geometry_generation reads _VoxelBuffer + samples _NormalsTex,
                               writes packed vertex data into position/normal/
                               tangent/binormal/uv0/color buffers
```

MC meshes with `isDynamic: true` (Julia) write the vertex count via `atomicAdd`
into `_CountBuffer` and draw with `vkCmdDrawIndirect`. Static MC meshes (Mandelbulb)
use a pre-counted `vkCmdDraw`.

**Dual Contouring (DC)** — 4 stages, used by Temple and ProceduralHouse (64³ grid):

```
Stage 1 — voxel shader        writes SDF into _VoxelBuffer
Stage 2 — normal_generation   writes per-voxel gradients into _NormalsTex
Stage 3 — dc_qef_generation   solves a QEF per active cell, stores the optimal
                               vertex position into _QEFBuffer
                               (vec4(x,y,z,active) per cell)
Stage 4 — dc_geometry         emits up to 3 quads (18 vertex slots) per active
                               cell into the same vertex attribute buffers as MC
```

DC meshes always use static draw (`vkCmdDraw` with `gridCells × 18` slots). Both
algorithms produce identical vertex buffer layouts and are rendered by the same
G-Buffer fragment shaders.

The normal generation stage is shared by both algorithms. The geometry shader reads
normals via `textureLod(_NormalsTex, uv, 0)` for hardware trilinear interpolation.

### Procedural mesh JSON format

Each mesh is defined in `app/managers/procedural_meshes/*.procedural_mesh.json`:

```json
{
  "name": "Julia",
  "properties": {
    "sizeX": 64, "sizeY": 64, "sizeZ": 64,
    "voxelShader": "julia.comp",
    "normalShader": "normal_generation_smooth.comp",
    "geometryShader": "geometry_generation_full_tbn.comp",
    "isDynamic": true,
    "param0": 0.0,
    "localSize": 8
  }
}
```

For DC meshes, add a fourth `dcQEFShader` field — its presence switches the engine
to the 4-stage DC pipeline:

```json
"dcQEFShader": "dc_qef_generation_analytical.comp"
```

Adding a new procedural mesh requires only a JSON file — no C++ recompile needed.

### Active shader variants

| Shader | Used by | Notes |
|--------|---------|-------|
| `generated/geometry_generation_full_tbn.comp.glsl` | Julia, Mandelbulb | MC, atomicAdd vertex count |
| `generated/dc_geometry_generation.comp.glsl` | Temple, ProceduralHouse | DC quad emission |
| `generated/dc_qef_generation_analytical.comp.glsl` | Temple, ProceduralHouse | DC QEF solve via trilinear SDF gradient |
| `generated/normal_generation_smooth.comp.glsl` | Julia, Mandelbulb | |
| `generated/normal_generation.comp.glsl` | Temple, ProceduralHouse | |

### Static procedural meshes — GBufferGeneratedFlat

Static procedural meshes (Temple, ProceduralHouse) use the `GBufferGeneratedFlat`
material pass. Their geometry is generated once by the DC compute pipeline and
rendered with a fixed G-Buffer fragment shader.

#### Material pass

Materials using this pass are in `app/managers/materials/`. Two materials currently
use it:

| Material | Albedo | Shadow | Notes |
|----------|--------|--------|-------|
| `temple` | `Temple_GEN` | ✓ | cellular voronoi texture with Sobel normal map |
| `procedural_house` | `ProceduralHouse_GEN` | ✗ | tri-planar wood/roof blend |

`temple` includes `Shadow` in its `materialPassMask` so it casts shadows.
`procedural_house` does not — it receives shadows but does not cast them.

#### Vertex attributes

Both `geometry_generation_full_tbn.comp.glsl` (MC) and `dc_geometry_generation.comp.glsl`
(DC) write the same vertex buffer layout:

| Attribute | Location | Content | Used in frag? |
|-----------|----------|---------|--------------|
| `inNormal` | 0 | SDF gradient in view space (**inward-pointing** — see below) | ✓ |
| `inTangent` | 1 | Random triangle edge direction | ✗ |
| `inBinormal` | 2 | `cross(position, tangent)` | ✗ |
| `inColor` | 3 | — | ✗ |
| `inUV0` | 4 | Triplanar UV blend, precomputed | ✗ |
| `inPosition` | 5 | Model-space position (`voxelPos / 10.0`) | ✓ |
| `inViewPosition` | 6 | View-space position | ✓ |
| `inNormalTPM` | 7 | Model-space normal (same gradient, no view transform) | ✗ |

`inViewPosition` is computed in the vertex shader and passed separately so that
`cotangent_frame(N, p, uv)` receives `N` and `p` in the **same coordinate space**
(both view-space). The worldViewMatrix is not available in the fragment-side UBO.

#### Inward-pointing normals

The SDF voxel buffer is stored as `−SDF` (negated). Consequently the SDF gradient
(stored in `_NormalsTex` and read into `inNormal`) points **inward** into the
surface. The fragment shader corrects this with `reflect()`:

```glsl
// Blended tangent-space normal from the three triplanar faces:
vec3 n = normalize(nX * _triW.x + nY * _triW.y + nZ * _triW.z);
// reflect() flips the base (inward) direction outward while preserving
// the tangential perturbation from the normal map:
gbuffer.normal = reflect(n, inNormal);
```

`reflect(n, inNormal)` = `n - 2·dot(n, inNormal)·inNormal`. For a flat surface
where `n ≈ inNormal`, this reduces to `−inNormal` (outward). For a perturbed
normal the tangential component is preserved.

#### Triplanar texture mapping

World-space position (`inPosition`, which is voxel coordinate divided by 10)
doubles as UV for all texture samples. The geometric normal for blend weights is
recomputed from screen-space derivatives — it is not taken from the vertex
attribute:

```glsl
vec3 geoNormalM = normalize(cross(dFdx(inPosition), dFdy(inPosition)));
vec3 _triW = abs(geoNormalM);
_triW /= (_triW.x + _triW.y + _triW.z + 0.0001);
```

Three separate TBN matrices are built — one per triplanar face — each using the
correct 2D UV slice for that face. Using a single TBN causes degenerate UV
derivatives for off-axis surfaces (e.g. near-zero dFdx/dFdy for Z-facing geometry
when using Y-projected UVs), which produces visible streak artifacts.

```glsl
const mat3 TBN_X = cotangent_frame(inNormal, inViewPosition, inPosition.yz);
const mat3 TBN_Y = cotangent_frame(inNormal, inViewPosition, inPosition.xz);
const mat3 TBN_Z = cotangent_frame(inNormal, inViewPosition, inPosition.yx);
```

Each face samples the normal map independently with its own TBN, then the results
are blended before the `reflect()` call.

#### Temple bump displacement

`temple_ruins.comp.glsl` applies value-noise bump displacement to every SDF
primitive before evaluating the signed distance:

```glsl
float o = (noise3(p * 2.0) - 0.5) * 0.3;
```

`noise3` is an inline 3D value noise built from a `hash3` + trilinear interpolation
(no external dependency). The amplitude `0.3` is in ruins-space units; with the
64³ grid and `mapScaled(p/4)`, this displaces the isosurface by up to ±0.15 ruins
units ≈ ±0.6 voxels — enough to be visible at marching cubes resolution.

The normal map bumpiness is controlled separately by `bumpness` in
`texture_nrm_flat_generation.comp.glsl` (currently `0.5`). Lower values → flatter
normals (higher Z component = `1/bumpness`); higher values → more pronounced bumps.

#### Emissive caution

The shader hardcodes `emissiveTex * 0.1`. If `emissiveTextureName` is `"white"`,
every pixel emits a constant 0.1 regardless of lighting, causing a visible glow.
Use `emissiveTextureName: "black"` or zero the emissive in the shader to suppress
this.

#### Position scale (/ 10)

Marching cubes vertices are generated at integer voxel coordinates. The geometry
generation shader divides all positions by 10 before writing to the vertex buffer
(`storePosition(slot, v0.position.xyz / 10.0)`). This brings voxel-grid
coordinates into a reasonable model-space range. The same scale factor controls
texture tiling frequency — a larger divisor = coarser texture tiling.

#### Specular default

`gbuffer_generated_flat.frag.glsl` sets `gbuffer.specular = 0.5 + uboPerMaterial.pbrBias.g`.
The baseline of 0.5 corresponds to ~4% reflectance at normal incidence — the
standard dielectric default in the G-Buffer.

#### Albedo source

Albedo is sampled triplanarly from `albedoTex`. The emissive texture is used
**only** for `gbuffer.emissive` at a multiplier of 0.1:

```glsl
gbuffer.albedo   = triplanar(albedoTex, ...) * colorTint;
gbuffer.emissive = triplanar(emissiveTex, ...).r * 0.1;
```

#### Vertex inputs

The shader takes three vertex inputs: `inNormal` (view-space SDF gradient),
`inPosition` (model-space, used as triplanar UV), and `inViewPosition`
(view-space position, passed to `cotangent_frame` so that `N` and `p` are in
the same coordinate space).

---

### Legacy temple shader (old engine)

`gbuffer_temple.frag.glsl` from the original engine is preserved at
`C:\Users\pj\Documents\Programowanie\Intrinsic\app\assets\shaders\gbuffer_temple.frag.glsl`.
It was replaced by `gbuffer_generated_flat.frag.glsl` because it contained
several correctness bugs.

#### Bug 1 — Albedo was sampled from emissiveTex

```glsl
// Old shader (line 122):
gbuffer.albedo = vec4(inColor, 1.0)
    + vec4(mix(tex3D(inPosition, inNormalTPM, albedoTex),
               tex3D(inPosition / 10.0, inNormalTPM, emissiveTex), 1.0), 1.0)
    * uboPerInstance.colorTint;
```

`mix(a, b, 1.0)` always returns `b`, so `albedoTex` was silently discarded.
The albedo was being read from `emissiveTex` at 1/10th UV scale, plus `inColor`
(which the compute shader writes as zero). The temple albedo texture was never
sampled.

#### Bug 2 — Single TBN caused streak artifacts

```glsl
// Old shader (line 116):
const mat3 TBN = cotangent_frame(inNormal, inPosition, inUV0);
```

A single cotangent frame using the precomputed `inUV0` gives degenerate
`dFdx`/`dFdy` derivatives for off-axis faces — near-zero derivatives for
Z-facing geometry when using Y-projected UVs, producing visible streak artifacts.
The current shader builds three separate TBN matrices, one per projection axis
(see [Triplanar texture mapping](#triplanar-texture-mapping)).

Additionally, `inPosition` (model-space) was passed as `p` while `inNormal`
(view-space) was passed as `N` — a coordinate space mismatch inside
`cotangent_frame`.

#### Bug 3 — No inward-normal correction

```glsl
// Old shader (line 127):
gbuffer.normal = normalize(TBN * tex3DNormal(inPosition, inNormalTPM, normalTex));
```

The SDF gradient stored in `inNormal` / `inNormalTPM` is inward-pointing (the
voxel buffer stores `−SDF`). The old shader wrote this directly as the surface
normal without flipping it. The current shader corrects this with `reflect()`
(see [Inward-pointing normals](#inward-pointing-normals)).

#### Bug 4 — Zero specular

```glsl
// Old shader (line 130):
gbuffer.specular = uboPerMaterial.pbrBias.g;  // defaults to 0.0
```

With no baseline, specular highlights were black for the default material
configuration. The current shader uses `0.5 + pbrBias.g`.

#### Bug 5 — Dead code with silent no-op

```glsl
// Old shader (lines 67-68, inside tex3d()):
vec3 avgNormal = abs(normal);
avgNormal / (avgNormal.x + avgNormal.y + avgNormal.z);  // result discarded
```

The normalization divides `avgNormal` but discards the result (missing `=`
assignment), so `avgNormal` is the raw absolute normal throughout. The functions
`tex3d` and `tex3d_1` that contain this code are never called from `main()`.

### Pseudo-instancing

`PseudoInstancing` handles large numbers of the same mesh (e.g. grass, trees)
by duplicating mesh vertices in a single oversized vertex buffer, avoiding
per-instance draw call overhead. Instances are placed by `populateMeshes()` which
reads voxel heightmap data.

To register a mesh for pseudo-instancing:
```cpp
PseudoInstancing::addPseudoInstancingMesh(
    Name("grass_blade"),
    64,   // grid X
    64,   // grid Z
    0.8f  // placement probability
);
```

`generateInstances()` must be called once after the vertex buffer is created to
bake the transformed positions into GPU memory. This is a CPU-side operation.

---

## 16. Physics

The engine uses **NVIDIA PhysX 3.x**. Physics runs as part of the task system
and updates node transforms after the simulation step.

### Setting up a rigid body

```json
[
  {
    "name": "PhysicsBox",
    "offsetToParent": -1,
    "propertyEntries": [
      { "type": "Node",      "properties": { "localPos": [0, 10, 0], "localSize": [1, 1, 1] } },
      { "type": "Mesh",      "properties": { "meshName": "cube" } },
      { "type": "RigidBody", "properties": { "rigidBodyType": 1, "shapeType": 1, "mass": 1.0 } }
    ]
  }
]
```

### Runtime physics API

```cpp
RigidBodyRef rb = RigidBodyManager::getComponentForEntity(entityRef);

// Apply forces
RigidBodyManager::applyForce(rb, glm::vec3(0, 500, 0));
RigidBodyManager::applyImpulse(rb, glm::vec3(0, 10, 0));

// Change kinematic target
RigidBodyManager::setKinematicTarget(rb, worldTransform);

// Query velocity
glm::vec3 vel = RigidBodyManager::getLinearVelocity(rb);
```

### Character controller

The `CharacterController` component wraps PhysX's `PxController` for
first/third-person movement. It handles step-climbing and sliding automatically.

```cpp
CharacterControllerRef cc = CharacterControllerManager::getComponentForEntity(entityRef);
CharacterControllerManager::move(cc, displacement, deltaT);
bool grounded = CharacterControllerManager::isGrounded(cc);
```

---

## 17. Debugging & Profiling

### Vulkan validation layers

Enable by running with the Vulkan SDK validation layers active. On Windows:

```
set VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
Intrinsic.exe
```

Validation errors print to stderr and to the engine log. The most common
categories encountered in this codebase:

| VUID | Meaning |
|------|---------|
| `VkWriteDescriptorSet-descriptorType-00339` | Bound image lacks `STORAGE_BIT` |
| `VkDescriptorImageInfo-imageLayout-00344` | Image in wrong layout for descriptor |
| Access mask violations | Non-zero masks with `TOP_OF_PIPE`/`BOTTOM_OF_PIPE` |

### Microprofile (CPU + GPU profiling)

Available in non-final builds on Windows. Open the profile UI:

```
http://localhost:1338
```

Add markers in C++ code:
```cpp
MICROPROFILE_SCOPEI("Renderer", "MyPass", 0xFF0000);
```

GPU timing markers:
```cpp
// Uses VK_EXT_debug_marker — only available with the validation layers active
vkCmdDebugMarkerBeginEXT(cmdBuf, &markerInfo);
// ... commands ...
vkCmdDebugMarkerEndEXT(cmdBuf);
```

### Engine log macros

```cpp
_INTR_LOG_INFO("Loaded %d meshes", count);
_INTR_LOG_WARNING("Texture not found: %s", name.getString().c_str());
_INTR_LOG_ERROR("Fatal: %s", msg);
```

### Debug render pass

The `Debug` render pass can overlay wireframe AABBs, frustums, and physics
shapes. Toggle categories at runtime:

```cpp
// Toggle AABB visualization
Debug::Settings::showAABBs = !Debug::Settings::showAABBs;
```

### Common crash sites

- **Stale Ref after destroy**: a `Ref` becomes invalid once its component or
  entity is destroyed. Always check `.isValid()` before use.
- **`rebuildTreeAndUpdateTransforms()` not called**: transform changes do not
  propagate until this is called. Forgetting it leaves world matrices stale.
- **Descriptor set update on in-flight image**: updating a descriptor while the
  GPU is reading from it is UB. Either double-buffer or sync with a fence.
- **Concurrent `push_back` in a parallel task set**: enkiTS splits an `ITaskSet`
  across threads when `m_SetSize > m_MinRange`. If every concurrent `ExecuteRange`
  call appends to the same `std::vector`, you get a data race that silently corrupts
  the vector's size, leading to an out-of-bounds crash later (typically in
  `UniformUpdateParallelTaskSet` when it indexes the visible draw call list with a
  stale `m_SetSize`). Set `m_MinRange = m_SetSize` to prevent splitting, or use a
  per-thread accumulation vector merged after `WaitforTaskSet`. See section 7.1 for
  the full explanation.

---

## 18. Common Recipes

### Spawn an entity at runtime

```cpp
// Create entity
Entity::EntityRef entity = Entity::EntityManager::createEntity(Name("Explosion"));

// Add node component
NodeRef node = NodeManager::createComponent(entity);
NodeManager::setPosition(node, spawnPosition);

// Add mesh component
MeshRef mesh = MeshManager::createComponent(entity);
MeshManager::setMeshName(mesh, Name("explosion_sphere"));
MeshManager::setMaterialName(mesh, Name("explosion_material"));

// Register mesh in the renderer
MeshManager::createResources(mesh);

// Update transforms
NodeManager::rebuildTreeAndUpdateTransforms();
```

### Destroy an entity and its components

```cpp
NodeRef node = NodeManager::getComponentForEntity(entity);
MeshRef mesh = MeshManager::getComponentForEntity(entity);

if (mesh.isValid()) {
    MeshManager::destroyResources(mesh);
    MeshManager::destroyComponent(mesh);
}
NodeManager::destroyComponent(node);
Entity::EntityManager::destroyEntity(entity);
NodeManager::rebuildTreeAndUpdateTransforms();
```

### Move the active camera

```cpp
NodeRef camNode = NodeManager::getComponentForEntity(
    CameraManager::getEntity(World::getActiveCamera()));

NodeManager::setPosition(camNode, newPos);
NodeManager::setOrientation(camNode, newOrientation);
NodeManager::rebuildTreeAndUpdateTransforms();
```

### Add a new compute pass that writes to a texture

```cpp
// In init():
GpuProgramRef computeProg = GpuProgramManager::getResourceByName(Name("my_compute"));

ImageDesc imgDesc;
imgDesc.width = 512;
imgDesc.height = 512;
imgDesc.format = VK_FORMAT_R8G8B8A8_UNORM;
imgDesc.imageUsageFlags = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
_myOutputImage = ImageManager::createImage(imgDesc);

// Transition to GENERAL so compute can write
// (use a one-time command buffer — see RenderProcess.cpp for the pattern)

// In render():
ImageManager::insertImageMemoryBarrier(
    _myOutputImage,
    VK_IMAGE_LAYOUT_UNDEFINED,
    VK_IMAGE_LAYOUT_GENERAL,
    VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);

// dispatch...

ImageManager::insertImageMemoryBarrier(
    _myOutputImage,
    VK_IMAGE_LAYOUT_GENERAL,
    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
    VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
```

### Read back a GPU buffer to CPU

```cpp
// Buffer must be created with HOST_VISIBLE | HOST_COHERENT
void* ptr = BufferManager::mapMemory(bufferRef);
memcpy(cpuData, ptr, dataSize);
BufferManager::unmapMemory(bufferRef);
```

### Save / restore a world region

```cpp
// Save a subtree starting from node
_INTR_ARRAY(Node) snapshot;
World::cloneNodeTree(rootNode, snapshot);

// Restore (destroy current, re-create from snapshot)
World::destroyNodeTree(rootNode);
World::restoreNodeTree(snapshot);
```

---

## Appendix: Pool Sizes

If you hit assertion failures about running out of slots, increase these
constants in `IntrinsicCorePrerequisites.h` and rebuild:

| Constant | Default | Component |
|----------|---------|-----------|
| `_INTR_MAX_NODE_COUNT` | 10240 | Node |
| `_INTR_MAX_MESH_COUNT` | 10240 | Mesh |
| `_INTR_MAX_CAMERA_COUNT` | 1024 | Camera |
| `_INTR_MAX_LIGHT_COUNT` | 1024 | Light |
| `_INTR_MAX_RIGID_BODY_COUNT` | 1024 | RigidBody |
| `_INTR_MAX_SCRIPT_COUNT` | 1024 | Script |
| `_INTR_MAX_DECAL_COUNT` | 1024 | Decal |
| `_INTR_MAX_DRAW_CALL_COUNT` | 4096 | DrawCall |
| `_INTR_MAX_PIPELINE_COUNT` | 512 | Pipeline |
| `_INTR_MAX_IMAGE_COUNT` | 4096 | Image |
| `_INTR_MAX_BUFFER_COUNT` | 2048 | Buffer |
