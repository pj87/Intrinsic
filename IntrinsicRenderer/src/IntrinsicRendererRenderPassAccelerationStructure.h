// Copyright 2020-2026 Paweł Jastrzębski
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma once

#if defined(_INTR_FEATURE_RAY_TRACING)

namespace Intrinsic
{
namespace Renderer
{
namespace RenderPass
{
struct AccelerationStructurePass
{
  static void init();
  static void onReinitRendering();
  static void render(float p_DeltaT, Components::CameraRef p_CameraRef);

  // TLAS used by RT render passes as a bound descriptor.
  static Resources::AccelerationStructureRef _tlas;

private:
  static void _destroyAll();

  // Per-mesh-component BLAS, indexed by meshCompRef._id.
  // Invalid ref means no BLAS for that component (procedural or not loaded).
  static _INTR_ARRAY(Resources::AccelerationStructureRef) _blasPerMeshComp;

  // Scratch buffer reused across all AS builds.
  static VkBuffer       _scratchBuffer;
  static VkDeviceMemory _scratchMemory;

  // Host-visible instance buffer for TLAS geometry input.
  static VkBuffer       _instanceBuffer;
  static VkDeviceMemory _instanceMemory;
  static void*          _instanceMappedMemory;

  static bool _blasesBuilt;
};
}
}
}

#endif // _INTR_FEATURE_RAY_TRACING
