// Copyright 2017 Benjamin Glatzel
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

// Single include point for the active rendering backend.
//
// _INTR_RENDERER_BACKEND_VULKAN  — default; set by CMake unless DX12 is on.
// _INTR_RENDERER_BACKEND_DX12   — Direct3D 12 backend (Windows only).
//
// Render pass and resource manager code that needs to call backend API
// (beginFrame, endFrame, dispatchDrawCall, beginRenderPass, …) should include
// this header rather than IntrinsicRendererRenderSystem.h directly, so that
// future per-backend implementation headers can be swapped in here.

#if defined(_INTR_RENDERER_BACKEND_VULKAN)
#include "IntrinsicRendererRenderSystem.h"
#elif defined(_INTR_RENDERER_BACKEND_DX12)
// DX12 render system header will be added here in Phase 2.
// #include "IntrinsicRendererRenderSystemDX12.h"
#else
#error "No rendering backend defined. Set _INTR_RENDERER_BACKEND_VULKAN or _INTR_RENDERER_BACKEND_DX12."
#endif
