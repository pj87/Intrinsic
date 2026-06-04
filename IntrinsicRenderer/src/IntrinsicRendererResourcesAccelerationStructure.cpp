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

// Precompiled header file
#include "stdafx.h"

#if defined(_INTR_FEATURE_RAY_TRACING)

namespace Intrinsic
{
namespace Renderer
{
namespace Resources
{
void AccelerationStructureManager::createResources(
    const AccelerationStructureRefArray& p_AccelStructs)
{
  for (uint32_t i = 0u; i < p_AccelStructs.size(); ++i)
  {
    AccelerationStructureRef ref = p_AccelStructs[i];

    _INTR_ASSERT(_vkAccelerationStructure(ref) == VK_NULL_HANDLE);
    _INTR_ASSERT(!_descGeometries(ref).empty() &&
                 "Geometry must be set before createResources");

    const bool isTlas =
        (_descType(ref) == AccelerationStructureType::kTopLevel);
    const VkAccelerationStructureTypeKHR asType =
        isTlas ? VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR
               : VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;

    // --- 1. Query required build sizes ---------------------------------
    VkAccelerationStructureBuildGeometryInfoKHR buildGeomInfo = {};
    buildGeomInfo.sType =
        VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
    buildGeomInfo.type = asType;
    buildGeomInfo.flags =
        VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
    if (_descAllowUpdate(ref))
      buildGeomInfo.flags |=
          VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
    buildGeomInfo.geometryCount =
        (uint32_t)_descGeometries(ref).size();
    buildGeomInfo.pGeometries = _descGeometries(ref).data();

    VkAccelerationStructureBuildSizesInfoKHR buildSizes = {};
    buildSizes.sType =
        VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR;

    RenderSystem::pfnGetAccelerationStructureBuildSizesKHR(
        RenderSystem::_vkDevice,
        VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
        &buildGeomInfo,
        _descMaxPrimitiveCounts(ref).data(),
        &buildSizes);

    _buildScratchSize(ref) = buildSizes.buildScratchSize;
    _updateScratchSize(ref) = buildSizes.updateScratchSize;

    // --- 2. Create backing buffer with device-address memory -----------
    VkBufferCreateInfo bufInfo = {};
    bufInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufInfo.size = buildSizes.accelerationStructureSize;
    bufInfo.usage = VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR |
                    VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
    bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    VkBuffer& backingBuf = _vkBackingBuffer(ref);
    VkResult result =
        vkCreateBuffer(RenderSystem::_vkDevice, &bufInfo, nullptr, &backingBuf);
    _INTR_VK_CHECK_RESULT(result);

    VkMemoryRequirements memReqs;
    vkGetBufferMemoryRequirements(RenderSystem::_vkDevice, backingBuf, &memReqs);

    // Must allocate with VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT so that
    // vkGetAccelerationStructureDeviceAddressKHR works correctly.
    VkMemoryAllocateFlagsInfo allocFlags = {};
    allocFlags.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
    allocFlags.flags = VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

    VkMemoryAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.pNext = &allocFlags;
    allocInfo.allocationSize = memReqs.size;

    // Find a suitable device-local memory type
    const VkPhysicalDeviceMemoryProperties& memProps =
        RenderSystem::_vkPhysicalDeviceMemoryProperties;
    bool found = false;
    for (uint32_t typeIdx = 0u; typeIdx < memProps.memoryTypeCount; ++typeIdx)
    {
      const bool typeMatches =
          (memReqs.memoryTypeBits & (1u << typeIdx)) != 0u;
      const bool isDeviceLocal =
          (memProps.memoryTypes[typeIdx].propertyFlags &
           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) != 0u;
      if (typeMatches && isDeviceLocal)
      {
        allocInfo.memoryTypeIndex = typeIdx;
        found = true;
        break;
      }
    }
    _INTR_ASSERT(found && "No suitable device-local memory type for AS");

    VkDeviceMemory& backingMem = _vkBackingMemory(ref);
    result = vkAllocateMemory(RenderSystem::_vkDevice, &allocInfo, nullptr,
                              &backingMem);
    _INTR_VK_CHECK_RESULT(result);

    result = vkBindBufferMemory(RenderSystem::_vkDevice, backingBuf, backingMem,
                                0u);
    _INTR_VK_CHECK_RESULT(result);

    // --- 3. Create VkAccelerationStructureKHR --------------------------
    VkAccelerationStructureCreateInfoKHR createInfo = {};
    createInfo.sType =
        VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR;
    createInfo.buffer = backingBuf;
    createInfo.offset = 0u;
    createInfo.size = buildSizes.accelerationStructureSize;
    createInfo.type = asType;

    result = RenderSystem::pfnCreateAccelerationStructureKHR(
        RenderSystem::_vkDevice, &createInfo, nullptr,
        &_vkAccelerationStructure(ref));
    _INTR_VK_CHECK_RESULT(result);

    // --- 4. Retrieve device address ------------------------------------
    VkAccelerationStructureDeviceAddressInfoKHR addrInfo = {};
    addrInfo.sType =
        VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_DEVICE_ADDRESS_INFO_KHR;
    addrInfo.accelerationStructure = _vkAccelerationStructure(ref);

    _deviceAddress(ref) =
        RenderSystem::pfnGetAccelerationStructureDeviceAddressKHR(
            RenderSystem::_vkDevice, &addrInfo);
  }
}
}
}
}

#endif // _INTR_FEATURE_RAY_TRACING
