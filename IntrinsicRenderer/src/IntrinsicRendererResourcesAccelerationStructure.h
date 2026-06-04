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
namespace Resources
{
// Typedefs
typedef Dod::Ref AccelerationStructureRef;
typedef _INTR_ARRAY(AccelerationStructureRef) AccelerationStructureRefArray;

struct AccelerationStructureData
    : Dod::Resources::ResourceDataBase
{
  AccelerationStructureData()
      : Dod::Resources::ResourceDataBase(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT)
  {
    descType.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    descGeometries.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    descBuildRangeInfos.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    descMaxPrimitiveCounts.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    descAllowUpdate.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);

    vkAccelerationStructure.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    vkBackingBuffer.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    vkBackingMemory.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    buildScratchSize.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    updateScratchSize.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
    deviceAddress.resize(_INTR_MAX_ACCELERATION_STRUCTURE_COUNT);
  }

  // Description (set by callers before createResources)
  _INTR_ARRAY(AccelerationStructureType::Enum) descType;
  _INTR_ARRAY(_INTR_ARRAY(VkAccelerationStructureGeometryKHR)) descGeometries;
  _INTR_ARRAY(_INTR_ARRAY(VkAccelerationStructureBuildRangeInfoKHR))
      descBuildRangeInfos;
  _INTR_ARRAY(_INTR_ARRAY(uint32_t)) descMaxPrimitiveCounts;
  _INTR_ARRAY(bool) descAllowUpdate;

  // Resources (filled by createResources)
  _INTR_ARRAY(VkAccelerationStructureKHR) vkAccelerationStructure;
  _INTR_ARRAY(VkBuffer) vkBackingBuffer;
  _INTR_ARRAY(VkDeviceMemory) vkBackingMemory;
  _INTR_ARRAY(VkDeviceSize) buildScratchSize;
  _INTR_ARRAY(VkDeviceSize) updateScratchSize;
  _INTR_ARRAY(VkDeviceAddress) deviceAddress;
};

struct AccelerationStructureManager
    : Dod::Resources::ResourceManagerBase<AccelerationStructureData,
                                          _INTR_MAX_ACCELERATION_STRUCTURE_COUNT>
{
  _INTR_INLINE static void init()
  {
    _INTR_LOG_INFO("Inititializing Acceleration Structure Manager...");
    Dod::Resources::ResourceManagerBase<
        AccelerationStructureData,
        _INTR_MAX_ACCELERATION_STRUCTURE_COUNT>::_initResourceManager();
  }

  // <-

  _INTR_INLINE static AccelerationStructureRef
  createAccelerationStructure(const Name& p_Name)
  {
    return Dod::Resources::ResourceManagerBase<
        AccelerationStructureData,
        _INTR_MAX_ACCELERATION_STRUCTURE_COUNT>::_createResource(p_Name);
  }

  // <-

  _INTR_INLINE static void
  resetToDefault(AccelerationStructureRef p_Ref)
  {
    _descType(p_Ref) = AccelerationStructureType::kBottomLevel;
    _descGeometries(p_Ref).clear();
    _descBuildRangeInfos(p_Ref).clear();
    _descMaxPrimitiveCounts(p_Ref).clear();
    _descAllowUpdate(p_Ref) = false;
  }

  // <-

  _INTR_INLINE static void
  destroyAccelerationStructure(AccelerationStructureRef p_Ref)
  {
    Dod::Resources::ResourceManagerBase<
        AccelerationStructureData,
        _INTR_MAX_ACCELERATION_STRUCTURE_COUNT>::_destroyResource(p_Ref);
  }

  // <-

  _INTR_INLINE static void createAllResources()
  {
    destroyResources(_activeRefs);
    createResources(_activeRefs);
  }

  // <-

  static void
  createResources(const AccelerationStructureRefArray& p_AccelStructs);

  // <-

  _INTR_INLINE static void
  destroyResources(const AccelerationStructureRefArray& p_AccelStructs)
  {
    for (uint32_t i = 0u; i < p_AccelStructs.size(); ++i)
    {
      AccelerationStructureRef ref = p_AccelStructs[i];

      VkAccelerationStructureKHR& as = _vkAccelerationStructure(ref);
      if (as != VK_NULL_HANDLE)
      {
        RenderSystem::pfnDestroyAccelerationStructureKHR(
            RenderSystem::_vkDevice, as, nullptr);
        as = VK_NULL_HANDLE;
      }

      VkBuffer& buf = _vkBackingBuffer(ref);
      if (buf != VK_NULL_HANDLE)
      {
        vkDestroyBuffer(RenderSystem::_vkDevice, buf, nullptr);
        buf = VK_NULL_HANDLE;
      }

      VkDeviceMemory& mem = _vkBackingMemory(ref);
      if (mem != VK_NULL_HANDLE)
      {
        vkFreeMemory(RenderSystem::_vkDevice, mem, nullptr);
        mem = VK_NULL_HANDLE;
      }

      _deviceAddress(ref) = 0u;
      _buildScratchSize(ref) = 0u;
      _updateScratchSize(ref) = 0u;
    }
  }

  // <-

  _INTR_INLINE static void destroyAccelerationStructuresAndResources(
      const AccelerationStructureRefArray& p_AccelStructs)
  {
    destroyResources(p_AccelStructs);
    for (uint32_t i = 0u; i < p_AccelStructs.size(); ++i)
      destroyAccelerationStructure(p_AccelStructs[i]);
  }

  // Description accessors
  _INTR_INLINE static AccelerationStructureType::Enum&
  _descType(AccelerationStructureRef p_Ref)
  {
    return _data.descType[p_Ref._id];
  }
  _INTR_INLINE static _INTR_ARRAY(VkAccelerationStructureGeometryKHR) &
  _descGeometries(AccelerationStructureRef p_Ref)
  {
    return _data.descGeometries[p_Ref._id];
  }
  _INTR_INLINE static _INTR_ARRAY(
      VkAccelerationStructureBuildRangeInfoKHR) &
  _descBuildRangeInfos(AccelerationStructureRef p_Ref)
  {
    return _data.descBuildRangeInfos[p_Ref._id];
  }
  _INTR_INLINE static _INTR_ARRAY(uint32_t) &
  _descMaxPrimitiveCounts(AccelerationStructureRef p_Ref)
  {
    return _data.descMaxPrimitiveCounts[p_Ref._id];
  }
  _INTR_INLINE static bool& _descAllowUpdate(AccelerationStructureRef p_Ref)
  {
    return _data.descAllowUpdate[p_Ref._id];
  }

  // Resource accessors
  _INTR_INLINE static VkAccelerationStructureKHR&
  _vkAccelerationStructure(AccelerationStructureRef p_Ref)
  {
    return _data.vkAccelerationStructure[p_Ref._id];
  }
  _INTR_INLINE static VkBuffer&
  _vkBackingBuffer(AccelerationStructureRef p_Ref)
  {
    return _data.vkBackingBuffer[p_Ref._id];
  }
  _INTR_INLINE static VkDeviceMemory&
  _vkBackingMemory(AccelerationStructureRef p_Ref)
  {
    return _data.vkBackingMemory[p_Ref._id];
  }
  _INTR_INLINE static VkDeviceSize&
  _buildScratchSize(AccelerationStructureRef p_Ref)
  {
    return _data.buildScratchSize[p_Ref._id];
  }
  _INTR_INLINE static VkDeviceSize&
  _updateScratchSize(AccelerationStructureRef p_Ref)
  {
    return _data.updateScratchSize[p_Ref._id];
  }
  _INTR_INLINE static VkDeviceAddress&
  _deviceAddress(AccelerationStructureRef p_Ref)
  {
    return _data.deviceAddress[p_Ref._id];
  }
};
}
}
}

#endif // _INTR_FEATURE_RAY_TRACING
