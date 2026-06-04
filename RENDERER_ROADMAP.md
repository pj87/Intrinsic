# Renderer Roadmap: Vulkan Ray Tracing + DX12 Backend

Branch: `renderer_backend_abstraction`  
Goal: correctness-first — get both tracks working end-to-end before optimising.

---

## Architecture decisions (settled)

### Backend selection
- Compile-time flags, **not** virtual dispatch (DOD hot paths can't afford vtables).
- `INTR_RENDERER_BACKEND_DX12 OFF` → defines `_INTR_RENDERER_BACKEND_VULKAN` (default, no behaviour change).
- `INTR_FEATURE_RAY_TRACING OFF` → defines `_INTR_FEATURE_RAY_TRACING` when ON.
- Both are CMake `CACHE BOOL` options in `CMakeLists.txt`.

### DOD manager strategy
- **Do not** abstract the existing `*Data` structs to a virtual interface.
- For DX12: add DX12 parallel arrays to existing `*Data` structs behind `#if defined(_INTR_RENDERER_BACKEND_DX12)`. The `Dod::Ref` index is the shared handle across backends.
- For RT: new `AccelerationStructureManager` follows the existing `BufferManager` pattern exactly.

### Forwarding header
- `IntrinsicRendererBackend.h` — single include point for the active backend's render system.  
  Currently forwards to `IntrinsicRendererRenderSystem.h` on Vulkan.  
  DX12 render system will be `#include`d here in Phase 2.

### Memory allocation for AS objects
- AS backing buffers require `VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT` in `VkMemoryAllocateInfo.pNext`.  
  `GpuMemoryManager` allocates pages with `pNext = nullptr` so it cannot supply this flag.  
  Decision: allocate AS backing `VkDeviceMemory` directly (one `vkAllocateMemory` call per AS object), bypassing the page allocator. Simple and correct for Phase 1; can be optimised to a dedicated page later.

---

## Status

| Step | Status | Commit |
|------|--------|--------|
| Phase 0 — flags, `IntrinsicRendererBackend.h`, gated prerequisites | ✅ Done | `c98bb515` |
| Phase 1.1 — Vulkan 1.3 + RT extension negotiation, function pointers | ✅ Done | `48bde5ac` |
| Phase 1.2 — `AccelerationStructureManager` DOD manager | 🔶 Staged, not committed | — |
| Phase 1.3 — BLAS/TLAS build pass | ⬜ Next | — |
| Phase 1.4 — RT shader types in `GpuProgramManager` | ⬜ | — |
| Phase 1.5 — RT pipeline + SBT in `PipelineManager` | ⬜ | — |
| Phase 1.6 — `RenderPassRayTracedShadows` | ⬜ | — |
| Phase 2.1 — DX12 device + adapter | ⬜ | — |
| Phase 2.2 — DX12 swapchain | ⬜ | — |
| Phase 2.3 — Buffer/Image/Pipeline DX12 port | ⬜ | — |
| Phase 2.4 — DX12 descriptor heaps | ⬜ | — |
| Phase 2.5 — DX12 command recording | ⬜ | — |
| Phase 2.6 — First DX12 GBuffer pass | ⬜ | — |

---

## Phase 1 — Vulkan Ray Tracing

### Step 1.1 ✅ — Extension negotiation (`IntrinsicRendererRenderSystem.cpp`)

**What changed:**
- `initVkInstance`: `apiVersion` → `VK_API_VERSION_1_3` (1.2 was minimum for BDA; 1.3 adds `dynamicRendering`, `synchronization2`, `maintenance4` as core).
- `initVkDevice`:
  - Detects `VK_KHR_acceleration_structure`, `VK_KHR_ray_tracing_pipeline`, `VK_KHR_deferred_host_operations`.
  - pNext chain on `VkDeviceCreateInfo`:  
    `rtPipelineFeatures → accelStructFeatures → vk13Features → vk12Features`  
    (RT structs only prepended when all three extensions present AND `_INTR_FEATURE_RAY_TRACING` defined).
  - `vk12Features`: `bufferDeviceAddress`, `descriptorIndexing`.
  - `vk13Features`: `dynamicRendering`, `synchronization2`, `maintenance4`.
  - Loads 8 RT function pointers via `vkGetDeviceProcAddr`, sets `RenderSystem::_rtEnabled = true`.
- `RenderSystem.h`: 8 `pfn*` statics + `_rtEnabled` bool (all `#if _INTR_FEATURE_RAY_TRACING`).

**RT function pointers on `RenderSystem`:**
```
pfnCreateAccelerationStructureKHR
pfnDestroyAccelerationStructureKHR
pfnGetAccelerationStructureBuildSizesKHR
pfnCmdBuildAccelerationStructuresKHR
pfnGetAccelerationStructureDeviceAddressKHR
pfnCreateRayTracingPipelinesKHR
pfnGetRayTracingShaderGroupHandlesKHR
pfnCmdTraceRaysKHR
```

---

### Step 1.2 🔶 — `AccelerationStructureManager` (new DOD manager)

**Files changed/created:**

| File | Change |
|------|--------|
| `IntrinsicCorePrerequisites.h` | Add `_INTR_MAX_ACCELERATION_STRUCTURE_COUNT 4096u` |
| `IntrinsicRendererEnumsStructs.h` | `AccelerationStructureType::Enum {kBottomLevel, kTopLevel}`, `MemoryPoolType` += `kStaticAccelerationStructures` + `kVolatileAccelerationStructureScratch` (before `kCount`, RT-gated), `BufferType` += `kAccelerationStructure` + `kAccelerationStructureScratch` (RT-gated) |
| `IntrinsicRendererHelper.h` | `mapBufferTypeToVkUsageFlagBits`: new RT-gated cases returning correct usage flags |
| `IntrinsicRendererGpuMemoryManager.cpp` | `init()`: register the two new pool types (device-local) |
| `IntrinsicRendererResourcesAccelerationStructure.h` *(new)* | DOD manager header — see SoA layout below |
| `IntrinsicRendererResourcesAccelerationStructure.cpp` *(new)* | `createResources` + `destroyResources` |
| `IntrinsicCore/src/stdafx_renderer.h` | Add `#include "IntrinsicRendererResourcesAccelerationStructure.h"` |
| `IntrinsicRendererRenderSystem.cpp` | `initManagers()`: call `AccelerationStructureManager::init()` (RT-gated) |

**`AccelerationStructureData` SoA layout:**
```
// Description (set before createResources)
descType                  AccelerationStructureType::Enum
descGeometries            _INTR_ARRAY(VkAccelerationStructureGeometryKHR)
descBuildRangeInfos       _INTR_ARRAY(VkAccelerationStructureBuildRangeInfoKHR)
descMaxPrimitiveCounts    _INTR_ARRAY(uint32_t)
descAllowUpdate           bool

// Resources (filled by createResources)
vkAccelerationStructure   VkAccelerationStructureKHR
vkBackingBuffer           VkBuffer
vkBackingMemory           VkDeviceMemory   ← allocated directly with DEVICE_ADDRESS_BIT
buildScratchSize          VkDeviceSize     ← exposed to the build pass
updateScratchSize         VkDeviceSize
deviceAddress             VkDeviceAddress  ← from pfnGetAccelerationStructureDeviceAddressKHR
```

**`createResources` flow (per ref):**
1. Call `pfnGetAccelerationStructureBuildSizesKHR` → get `accelerationStructureSize`, `buildScratchSize`, `updateScratchSize`.
2. Create `VkBuffer` with `VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT`.
3. `vkAllocateMemory` with `VkMemoryAllocateFlagsInfo.flags = VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT` in pNext — device-local type. Bind.
4. `pfnCreateAccelerationStructureKHR`.
5. `pfnGetAccelerationStructureDeviceAddressKHR` → store in `_deviceAddress`.

**`destroyResources` flow:** `pfnDestroyAccelerationStructureKHR` → `vkDestroyBuffer` → `vkFreeMemory`.

---

### Step 1.3 ⬜ — BLAS/TLAS build pass

**New files:** `IntrinsicRendererRenderPassAccelerationStructure.h/.cpp`

**Interface:**
```cpp
struct AccelerationStructurePass {
    static void init();
    static void onReinitRendering();
    static void render(float p_DeltaT, Components::CameraRef);
    static AccelerationStructureRef _tlas;
};
```

**Frame loop insertion point** in `IntrinsicRendererRenderProcess.cpp`:
```cpp
// After DynamicMeshGeneration::render, before executeRenderSteps:
RenderPass::AccelerationStructurePass::render(p_DeltaT, camera);
```

**BLAS strategy (Phase 1, static meshes only):**
- `init()`: iterate `Components::MeshManager::_activeRefs`, create one BLAS per mesh component. One `AccelerationStructureRef` stored per mesh component (add a parallel array to `MeshData` or a side-map keyed by ref index).
- Geometry: `VkAccelerationStructureGeometryTrianglesDataKHR` from `_vertexBuffers` / `_descIndexBuffer` already on the draw calls.
- Dynamic mesh BLASes: skip for now — set `_descAllowUpdate = true` but only build once after the compute pass writes vertex data.

**TLAS strategy:**
- One TLAS created each frame (or on-demand when scene changes).
- Instance list: `VkAccelerationStructureInstanceKHR` per visible mesh, filled from `_visibleMeshComponents`.
- Instance data written to a host-visible staging buffer, then synced to device-local TLAS instance buffer before build.

**Scratch buffer:**
- One shared scratch `VkBuffer` / `VkDeviceMemory` sized to `max(buildScratchSize)` across all BLASes + TLAS.
- Allocated via `GpuMemoryManager::allocateOffset(kVolatileAccelerationStructureScratch, ...)`.  
  NOTE: scratch also needs `VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT` → same direct allocation needed. Either allocate scratch directly or extend `GpuMemoryManager` with a device-address flag per pool type.
- Reset via `GpuMemoryManager::resetPool(kVolatileAccelerationStructureScratch)` after builds.

**Render step registration:**
- Add `kRenderPassAccelerationStructure` to `RenderStepType::Enum` in `IntrinsicRendererRenderProcess.cpp`.
- Register `onReinitRendering` in `_renderStepFunctionMapping`.

---

### Step 1.4 ⬜ — RT shader types in `GpuProgramManager`

**Files to change:**
- `IntrinsicRendererEnumsStructs.h`: `GpuProgramType::Enum` += `kRayGen`, `kClosestHit`, `kMiss`, `kAnyHit`, `kIntersection` (RT-gated).
- `IntrinsicRendererHelper.h`: `mapGpuProgramTypeToEshLang()` += RT-gated cases mapping to `EShLangRayGen`, `EShLangClosestHit`, `EShLangMiss`, `EShLangAnyHit`.
- `IntrinsicRendererResourcesGpuProgram.cpp`: extend the `shaderStage` mapping in `createResources` for the new stage flags.
- `IntrinsicRendererResourcesPipelineLayout.cpp`: `reflectPipelineLayout()` — add handling for `resources.acceleration_structures` from spirv-cross (bound as `VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR`).

**Risk:** check `dependencies/glslang` version supports `EShLangRayGen`. Requires glslang ≥ 11.0 (shipped with Vulkan SDK ≥ 1.2.162). If not, update the submodule.

---

### Step 1.5 ⬜ — RT pipeline + SBT in `PipelineManager`

**Files to change:** `IntrinsicRendererResourcesPipeline.h/.cpp`

**Additions to `PipelineData` SoA (RT-gated):**
```
descRayGenProgram     GpuProgramRef
descMissPrograms      _INTR_ARRAY(GpuProgramRef)
descClosestHitPrograms _INTR_ARRAY(GpuProgramRef)
descAnyHitPrograms    _INTR_ARRAY(GpuProgramRef)
vkSbtBuffer           VkBuffer      ← SBT backing buffer
vkSbtMemory           VkDeviceMemory
vkRgenRegion          VkStridedDeviceAddressRegionKHR
vkMissRegion          VkStridedDeviceAddressRegionKHR
vkHitRegion           VkStridedDeviceAddressRegionKHR
vkCallableRegion      VkStridedDeviceAddressRegionKHR
```

**`createResources` RT branch** (detect when `descRayGenProgram` is valid):
1. Build `VkRayTracingShaderGroupCreateInfoKHR` array from stage refs.
2. Call `pfnCreateRayTracingPipelinesKHR`.
3. Query shader group handles via `pfnGetRayTracingShaderGroupHandlesKHR`.
4. Allocate SBT buffer (device-local, with `VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT`). Upload handles via staging.
5. Compute the four `VkStridedDeviceAddressRegionKHR` structs from the SBT layout.

---

### Step 1.6 ⬜ — First RT render pass: RayTracedShadows

**New files:** `IntrinsicRendererRenderPassRayTracedShadows.h/.cpp`

**New shaders:**
- `app/assets/shaders/rt_shadow.rgen.glsl` — fire one shadow ray per pixel toward the main light.
- `app/assets/shaders/rt_shadow.rmiss.glsl` — unoccluded: write 1.0 to payload.
- `app/assets/shaders/rt_shadow.rchit.glsl` — occluded: write 0.0 (minimal, can start as an empty/passthrough hit).

**Inputs:** TLAS (bound as acceleration structure descriptor), GBuffer depth texture.  
**Output:** `RT_ShadowMask` image (R8UNorm, full-res).

**`renderer_config.json` additions:**
```json
{ "name": "RT_ShadowMask", "renderSize": "kFull", "imageFormat": "R8UNorm" }
{ "type": "RenderPassRayTracedShadows" }
// + transition barriers around the step
```

**`material_pass_config.json`:** add a `BoundResources` entry that binds `RT_ShadowMask` as input to the lighting pass.

**Dispatch:** `vkCmdTraceRaysKHR(cmdBuf, &rgenRegion, &missRegion, &hitRegion, &callableRegion, width, height, 1)`.

---

## Phase 2 — DX12 Backend

Phase 2 is independent of Phase 1 after Phase 0. Both can proceed in parallel.

### Step 2.1 ⬜ — DX12 device + adapter

**New file:** `IntrinsicRendererRenderSystemDX12.cpp`

New statics on `RenderSystem` (gated by `#if _INTR_RENDERER_BACKEND_DX12`):
```cpp
static ID3D12Device*              _d3dDevice;
static ID3D12CommandQueue*        _d3dCommandQueue;
static ID3D12CommandAllocator*    _d3dCommandAllocators[2];
static ID3D12GraphicsCommandList* _d3dCommandList;
static IDXGISwapChain3*           _dxgiSwapchain;
static UINT                       _dxFrameIndex;
```

`initD3DDevice()`: `CreateDXGIFactory2` → enumerate `IDXGIAdapter1` → first hardware adapter → `D3D12CreateDevice` at `D3D_FEATURE_LEVEL_12_0`.

---

### Step 2.2 ⬜ — DX12 swapchain

`initOrUpdateDXSwapChain()`:
- `DXGI_SWAP_CHAIN_DESC1`: 2 buffers, `DXGI_FORMAT_B8G8R8A8_UNORM`, `DXGI_SWAP_EFFECT_FLIP_DISCARD`.
- RTV descriptor heap (`D3D12_DESCRIPTOR_HEAP_TYPE_RTV`).
- Wrap two backbuffer `ID3D12Resource*` as `ImageRef` entries with `kExternalImage` flag, same as the Vulkan path does with `_vkSwapchainImages`.

---

### Step 2.3 ⬜ — Resource manager DX12 port (order matters)

Port in this order to minimise dependencies:

**1. BufferManager** (`IntrinsicRendererResourcesBuffer.h/.cpp`):
- `BufferData` += `_INTR_ARRAY(ID3D12Resource*) d3dBuffer` + `_INTR_ARRAY(D3D12_GPU_VIRTUAL_ADDRESS) d3dGpuVirtualAddress` (DX12-gated).
- `createResources` DX12 path: `CreateCommittedResource` on `D3D12_HEAP_TYPE_DEFAULT` (or `UPLOAD` for uniform/dynamic). No page allocator — committed resources for now.
- `destroyResources` DX12 path: `Release()` on `ID3D12Resource`.

**2. ImageManager** (`IntrinsicRendererResourcesImage.h/.cpp`):
- `ImageData` += `_INTR_ARRAY(ID3D12Resource*) d3dTexture` + `_INTR_ARRAY(D3D12_CPU_DESCRIPTOR_HANDLE) d3dSrvHandle`.
- SRV descriptor heap lives as a `RenderSystem` static (DX12-only).

**3. PipelineManager** (`IntrinsicRendererResourcesPipeline.h/.cpp`):
- `PipelineData` += `_INTR_ARRAY(ID3D12PipelineState*) d3dPipelineState` + `_INTR_ARRAY(ID3D12RootSignature*) d3dRootSignature`.
- Shader compilation: SPIR-V → HLSL via spirv-cross HLSL backend → `D3DCompile` to DXIL.  
  **Risk:** spirv-cross HLSL output can be incorrect for complex shaders (esp. global texture descriptor arrays). Restrict Phase 2 to simple shaders initially.

**4. PipelineLayoutManager** (`IntrinsicRendererResourcesPipelineLayout.h/.cpp`):
- `PipelineLayoutData` += `_INTR_ARRAY(ID3D12RootSignature*) d3dRootSignature`.

**5. DrawCallManager** (`IntrinsicRendererResourcesDrawCall.h`):
- `DrawCallData` += `_INTR_ARRAY(UINT) d3dDescriptorHeapOffset` (DX12-gated).
- `createResources` DX12 path: allocate a range in the per-frame CBV/SRV/UAV heap instead of `vkAllocateDescriptorSets`.

---

### Step 2.4 ⬜ — DX12 descriptor management

- One large CBV/SRV/UAV heap per frame (`D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV`, shader-visible): `_INTR_MAX_DRAW_CALL_COUNT * MAX_BINDINGS_PER_DRAW` descriptors. No streaming for now (wastes memory, but simple).
- One sampler heap per frame.
- Set both heaps on the command list at frame start (`SetDescriptorHeaps`).
- `dispatchDrawCallDX12`: `SetGraphicsRootDescriptorTable` → `DrawIndexedInstanced` / `DrawInstanced`.

---

### Step 2.5 ⬜ — DX12 command recording

Mapping from the Vulkan call sites:

| Vulkan | DX12 |
|--------|------|
| `beginPrimaryCommandBuffer()` | `Reset(allocator)` + `Reset(list)` |
| `endPrimaryCommandBuffer()` | `Close()` on command list |
| `endFrame()` | `ExecuteCommandLists`, `Present`, `Signal` fence |
| `beginRenderPass(...)` | `OMSetRenderTargets` + barrier → `RENDER_TARGET` state |
| `endRenderPass(...)` | barrier → `COMMON` or SRV state |
| `dispatchComputeCall(...)` | `SetComputeRootSignature`, `SetPipelineState`, `Dispatch` |

Secondary command buffers (`_INTR_VK_SECONDARY_COMMAND_BUFFER_COUNT = 128`) have no direct DX12 equivalent (bundles are not 1:1). For DX12 backend: **assert that secondary buffer code paths are skipped**, use single direct command list for everything.

---

### Step 2.6 ⬜ — First DX12 render pass: GBuffer

Port `RenderPassGenericMesh` for a single GBuffer step to validate the full pipeline.

Checklist:
1. `dispatchDrawCallDX12()` in `IntrinsicRendererRenderSystemDX12.cpp`.
2. DX12 resource barriers in `ImageManager` replacing `insertImageMemoryBarrier`.
3. A single `RenderPassGenericMesh` step with trivial GBuffer shaders produces pixels on screen.

Remains Vulkan-only (do not port yet): RT passes, `DynamicMeshGeneration`, `VolumetricLighting`, `Clustering`.

---

## Key risks

| Risk | Mitigation |
|------|-----------|
| glslang in `dependencies/glslang` too old for `EShLangRayGen` (needs ≥ v11) | Check before Step 1.4; upgrade submodule if needed |
| spirv-cross HLSL emitter breaks on complex shaders | Limit Phase 2 to simple GBuffer shaders; avoid global texture descriptor arrays |
| Dynamic mesh BLASes need `SHADER_DEVICE_ADDRESS` on compute-generated vertex buffers | Skip dynamic BLASes in Phase 1; build static-only first |
| `_INTR_VK_SECONDARY_COMMAND_BUFFER_COUNT = 128` — no DX12 bundle equivalent | Assert DX12 skips secondary paths, single primary command list |
| scratch buffers also need `VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT` | Allocate scratch directly (same pattern as AS backing memory) OR extend `GpuMemoryManager` with a per-pool BDA flag |
| `materialPassMask` is `uint32_t` (max 32 passes); currently 19 passes | Fine for now, but do not exceed 32 total passes |

---

## File map — what exists and what is planned

```
IntrinsicRenderer/src/
  IntrinsicRendererBackend.h                          ✅ Phase 0
  IntrinsicRendererRenderSystem.h/.cpp                ✅ Phase 1.1
  IntrinsicRendererResourcesAccelerationStructure.h   🔶 Phase 1.2 (staged)
  IntrinsicRendererResourcesAccelerationStructure.cpp 🔶 Phase 1.2 (staged)
  IntrinsicRendererRenderPassAccelerationStructure.h  ⬜ Phase 1.3
  IntrinsicRendererRenderPassAccelerationStructure.cpp ⬜ Phase 1.3
  IntrinsicRendererRenderPassRayTracedShadows.h       ⬜ Phase 1.6
  IntrinsicRendererRenderPassRayTracedShadows.cpp     ⬜ Phase 1.6
  IntrinsicRendererRenderSystemDX12.cpp               ⬜ Phase 2.1

IntrinsicCore/src/
  IntrinsicCorePrerequisites.h     ✅ Phase 1.2 (_INTR_MAX_ACCELERATION_STRUCTURE_COUNT)
  stdafx_renderer.h                🔶 Phase 1.2 (staged — new #include)

app/assets/shaders/
  rt_shadow.rgen.glsl              ⬜ Phase 1.6
  rt_shadow.rmiss.glsl             ⬜ Phase 1.6
  rt_shadow.rchit.glsl             ⬜ Phase 1.6

app/config/
  renderer_config.json             ⬜ Phase 1.6 (add RT_ShadowMask image + step)
  material_pass_config.json        ⬜ Phase 1.6 (add RT shadow bound resources)

CMakeLists.txt                     ✅ Phase 0
```
