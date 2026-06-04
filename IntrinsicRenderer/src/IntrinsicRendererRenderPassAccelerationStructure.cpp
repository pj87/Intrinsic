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
namespace RenderPass
{

using namespace Resources;

// ---------------------------------------------------------------------------
// Static member definitions
// ---------------------------------------------------------------------------

AccelerationStructureRef AccelerationStructurePass::_tlas;
_INTR_ARRAY(AccelerationStructureRef) AccelerationStructurePass::_blasPerMeshComp;
VkBuffer AccelerationStructurePass::_scratchBuffer = VK_NULL_HANDLE;
VkDeviceMemory AccelerationStructurePass::_scratchMemory = VK_NULL_HANDLE;
VkBuffer AccelerationStructurePass::_instanceBuffer = VK_NULL_HANDLE;
VkDeviceMemory AccelerationStructurePass::_instanceMemory = VK_NULL_HANDLE;
void* AccelerationStructurePass::_instanceMappedMemory = nullptr;
bool AccelerationStructurePass::_blasesBuilt = false;

// ---------------------------------------------------------------------------
// File-local helpers
// ---------------------------------------------------------------------------

namespace
{
// Allocate a VkBuffer + VkDeviceMemory with VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT.
// Always uses the first memory type that satisfies p_RequiredProps.
void allocateDirectBuffer(VkDeviceSize p_Size, VkBufferUsageFlags p_Usage,
                          VkMemoryPropertyFlags p_RequiredProps,
                          VkBuffer& p_OutBuffer, VkDeviceMemory& p_OutMemory,
                          void** p_OutMapped = nullptr)
{
  VkBufferCreateInfo bufInfo = {};
  bufInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  bufInfo.size = p_Size;
  bufInfo.usage = p_Usage | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

  _INTR_VK_CHECK_RESULT(
      vkCreateBuffer(RenderSystem::_vkDevice, &bufInfo, nullptr, &p_OutBuffer));

  VkMemoryRequirements memReqs;
  vkGetBufferMemoryRequirements(RenderSystem::_vkDevice, p_OutBuffer, &memReqs);

  VkMemoryAllocateFlagsInfo flagsInfo = {};
  flagsInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
  flagsInfo.flags = VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

  VkMemoryAllocateInfo allocInfo = {};
  allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  allocInfo.pNext = &flagsInfo;
  allocInfo.allocationSize = memReqs.size;

  const VkPhysicalDeviceMemoryProperties& memProps =
      RenderSystem::_vkPhysicalDeviceMemoryProperties;

  bool found = false;
  for (uint32_t i = 0u; i < memProps.memoryTypeCount; ++i)
  {
    if ((memReqs.memoryTypeBits & (1u << i)) &&
        (memProps.memoryTypes[i].propertyFlags & p_RequiredProps) ==
            p_RequiredProps)
    {
      allocInfo.memoryTypeIndex = i;
      found = true;
      break;
    }
  }
  _INTR_ASSERT(found && "No suitable memory type for direct buffer");

  _INTR_VK_CHECK_RESULT(vkAllocateMemory(RenderSystem::_vkDevice, &allocInfo,
                                         nullptr, &p_OutMemory));
  _INTR_VK_CHECK_RESULT(
      vkBindBufferMemory(RenderSystem::_vkDevice, p_OutBuffer, p_OutMemory, 0u));

  if (p_OutMapped)
  {
    _INTR_VK_CHECK_RESULT(vkMapMemory(RenderSystem::_vkDevice, p_OutMemory, 0u,
                                      memReqs.size, 0u, p_OutMapped));
  }
}

void freeDirectBuffer(VkBuffer& p_Buffer, VkDeviceMemory& p_Memory)
{
  if (p_Buffer != VK_NULL_HANDLE)
  {
    vkDestroyBuffer(RenderSystem::_vkDevice, p_Buffer, nullptr);
    p_Buffer = VK_NULL_HANDLE;
  }
  if (p_Memory != VK_NULL_HANDLE)
  {
    vkFreeMemory(RenderSystem::_vkDevice, p_Memory, nullptr);
    p_Memory = VK_NULL_HANDLE;
  }
}

VkDeviceAddress getBufferDeviceAddress(VkBuffer p_Buffer)
{
  VkBufferDeviceAddressInfo info = {};
  info.sType = VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
  info.buffer = p_Buffer;
  return vkGetBufferDeviceAddress(RenderSystem::_vkDevice, &info);
}

// Insert a memory barrier between AS builds (write → read within AS build stage)
// or from AS build to RT shader stage.
void insertAsBarrier(VkCommandBuffer p_Cmd,
                     VkPipelineStageFlags p_DstStage,
                     VkAccessFlags p_DstAccess)
{
  VkMemoryBarrier barrier = {};
  barrier.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
  barrier.srcAccessMask = VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR;
  barrier.dstAccessMask = p_DstAccess;

  vkCmdPipelineBarrier(p_Cmd,
                       VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR,
                       p_DstStage, 0u, 1u, &barrier, 0u, nullptr, 0u, nullptr);
}
} // anonymous namespace

// ---------------------------------------------------------------------------
// AccelerationStructurePass implementation
// ---------------------------------------------------------------------------

void AccelerationStructurePass::_destroyAll()
{
  // Destroy TLAS
  if (_tlas.isValid())
  {
    AccelerationStructureRefArray toDestroy = {_tlas};
    AccelerationStructureManager::destroyAccelerationStructuresAndResources(
        toDestroy);
    _tlas = AccelerationStructureRef();
  }

  // Destroy BLASes
  AccelerationStructureRefArray blasesToDestroy;
  for (uint32_t i = 0u; i < _blasPerMeshComp.size(); ++i)
  {
    if (_blasPerMeshComp[i].isValid())
      blasesToDestroy.push_back(_blasPerMeshComp[i]);
  }
  if (!blasesToDestroy.empty())
    AccelerationStructureManager::destroyAccelerationStructuresAndResources(
        blasesToDestroy);
  _blasPerMeshComp.clear();

  // Destroy scratch and instance buffers
  freeDirectBuffer(_scratchBuffer, _scratchMemory);
  if (_instanceMappedMemory && _instanceMemory != VK_NULL_HANDLE)
    vkUnmapMemory(RenderSystem::_vkDevice, _instanceMemory);
  _instanceMappedMemory = nullptr;
  freeDirectBuffer(_instanceBuffer, _instanceMemory);

  _blasesBuilt = false;
}

// ---------------------------------------------------------------------------

void AccelerationStructurePass::init()
{
  _INTR_LOG_INFO("Initializing Acceleration Structure Pass...");

  _blasPerMeshComp.resize(_INTR_MAX_MESH_COMPONENT_COUNT);

  // Allocate instance buffer for TLAS (host-visible, persistently mapped).
  const VkDeviceSize instanceBufSize =
      _INTR_MAX_MESH_COMPONENT_COUNT *
      sizeof(VkAccelerationStructureInstanceKHR);

  allocateDirectBuffer(
      instanceBufSize,
      VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR,
      VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
      _instanceBuffer, _instanceMemory, &_instanceMappedMemory);
}

// ---------------------------------------------------------------------------

void AccelerationStructurePass::onReinitRendering()
{
  _destroyAll();
  _blasPerMeshComp.resize(_INTR_MAX_MESH_COMPONENT_COUNT);

  // Re-allocate instance buffer
  const VkDeviceSize instanceBufSize =
      _INTR_MAX_MESH_COMPONENT_COUNT *
      sizeof(VkAccelerationStructureInstanceKHR);
  allocateDirectBuffer(
      instanceBufSize,
      VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR,
      VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
      _instanceBuffer, _instanceMemory, &_instanceMappedMemory);

  // Build BLASes for all active mesh components (static geometry only).
  VkDeviceSize maxScratchNeeded = 0u;

  AccelerationStructureRefArray newBlases;

  for (uint32_t mIdx = 0u;
       mIdx < Components::MeshManager::getActiveResourceCount(); ++mIdx)
  {
    Components::MeshRef meshCompRef =
        Components::MeshManager::getActiveResourceAtIndex(mIdx);

    Resources::MeshRef meshRef = Resources::MeshManager::getResourceByName(
        Components::MeshManager::_descMeshName(meshCompRef));
    if (!meshRef.isValid())
      continue;

    const uint32_t subMeshCount =
        (uint32_t)Resources::MeshManager::_descPositionsPerSubMesh(meshRef)
            .size();
    if (subMeshCount == 0u)
      continue; // procedural mesh — no CPU position data

    // Collect geometry for all submeshes.
    AccelerationStructureRef blasRef =
        AccelerationStructureManager::createAccelerationStructure(
            Components::MeshManager::_descMeshName(meshCompRef));
    AccelerationStructureManager::resetToDefault(blasRef);
    AccelerationStructureManager::_descType(blasRef) =
        AccelerationStructureType::kBottomLevel;

    for (uint32_t sub = 0u; sub < subMeshCount; ++sub)
    {
      const auto& positions =
          Resources::MeshManager::_descPositionsPerSubMesh(meshRef)[sub];
      const auto& indices =
          Resources::MeshManager::_descIndicesPerSubMesh(meshRef)[sub];
      if (positions.empty() || indices.empty())
        continue;

      const VertexBuffersPerSubMeshArray& vtxBufs =
          Resources::MeshManager::_vertexBuffersPerSubMesh(meshRef);
      const IndexBufferPerSubMeshArray& idxBufs =
          Resources::MeshManager::_indexBufferPerSubMesh(meshRef);

      if (sub >= vtxBufs.size() || sub >= idxBufs.size())
        continue;
      if (vtxBufs[sub].empty() || !idxBufs[sub].isValid())
        continue;

      const Dod::Ref posBufRef = vtxBufs[sub][0]; // slot 0 = position
      const Dod::Ref idxBufRef = idxBufs[sub];

      VkBuffer posBuf = BufferManager::_vkBuffer(posBufRef);
      VkBuffer idxBuf = BufferManager::_vkBuffer(idxBufRef);
      if (posBuf == VK_NULL_HANDLE || idxBuf == VK_NULL_HANDLE)
        continue;

      // Determine index type from buffer type.
      const bool isIdx16 =
          (BufferManager::_descBufferType(idxBufRef) == BufferType::kIndex16);
      const VkIndexType idxType =
          isIdx16 ? VK_INDEX_TYPE_UINT16 : VK_INDEX_TYPE_UINT32;
      const uint32_t primitiveCount = (uint32_t)(indices.size() / 3u);

      VkAccelerationStructureGeometryTrianglesDataKHR triData = {};
      triData.sType =
          VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR;
      triData.vertexFormat = VK_FORMAT_R32G32B32_SFLOAT; // glm::vec3
      triData.vertexData.deviceAddress = getBufferDeviceAddress(posBuf);
      triData.vertexStride = sizeof(glm::vec3);
      triData.maxVertex = (uint32_t)positions.size() - 1u;
      triData.indexType = idxType;
      triData.indexData.deviceAddress = getBufferDeviceAddress(idxBuf);

      VkAccelerationStructureGeometryKHR geom = {};
      geom.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
      geom.geometryType = VK_GEOMETRY_TYPE_TRIANGLES_KHR;
      geom.geometry.triangles = triData;
      geom.flags = VK_GEOMETRY_OPAQUE_BIT_KHR;

      VkAccelerationStructureBuildRangeInfoKHR range = {};
      range.primitiveCount = primitiveCount;

      AccelerationStructureManager::_descGeometries(blasRef).push_back(geom);
      AccelerationStructureManager::_descBuildRangeInfos(blasRef).push_back(
          range);
      AccelerationStructureManager::_descMaxPrimitiveCounts(blasRef).push_back(
          primitiveCount);
    }

    if (AccelerationStructureManager::_descGeometries(blasRef).empty())
    {
      AccelerationStructureManager::destroyAccelerationStructure(blasRef);
      continue;
    }

    // Allocate the AS storage (queries sizes, creates backing buffer + AS).
    AccelerationStructureRefArray oneRef = {blasRef};
    AccelerationStructureManager::createResources(oneRef);

    _blasPerMeshComp[meshCompRef._id] = blasRef;
    newBlases.push_back(blasRef);

    maxScratchNeeded = std::max(
        maxScratchNeeded,
        AccelerationStructureManager::_buildScratchSize(blasRef));
  }

  if (newBlases.empty())
  {
    _INTR_LOG_WARNING("AccelerationStructurePass: no static BLASes built.");
    return;
  }

  // --- Build BLASes via temporary command buffer ----------------------------
  // One build at a time, reusing the scratch buffer (barrier between each).

  allocateDirectBuffer(
      maxScratchNeeded,
      VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
      VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
      _scratchBuffer, _scratchMemory);

  const VkDeviceAddress scratchAddr = getBufferDeviceAddress(_scratchBuffer);

  VkCommandBuffer buildCmd = RenderSystem::beginTemporaryCommandBuffer();

  for (uint32_t i = 0u; i < newBlases.size(); ++i)
  {
    AccelerationStructureRef blasRef = newBlases[i];

    VkAccelerationStructureBuildGeometryInfoKHR buildInfo = {};
    buildInfo.sType =
        VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
    buildInfo.type = VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
    buildInfo.flags =
        VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
    buildInfo.mode = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
    buildInfo.dstAccelerationStructure =
        AccelerationStructureManager::_vkAccelerationStructure(blasRef);
    buildInfo.geometryCount =
        (uint32_t)AccelerationStructureManager::_descGeometries(blasRef).size();
    buildInfo.pGeometries =
        AccelerationStructureManager::_descGeometries(blasRef).data();
    buildInfo.scratchData.deviceAddress = scratchAddr;

    const VkAccelerationStructureBuildRangeInfoKHR* pRanges =
        AccelerationStructureManager::_descBuildRangeInfos(blasRef).data();

    RenderSystem::pfnCmdBuildAccelerationStructuresKHR(buildCmd, 1u, &buildInfo,
                                                       &pRanges);

    // Barrier: this BLAS write must complete before the next build reads it
    // (needed for TLAS build that follows, and for sequential BLAS reuse of
    // scratch).
    insertAsBarrier(buildCmd,
                    VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR,
                    VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR);
  }

  RenderSystem::flushTemporaryCommandBuffer();

  _blasesBuilt = true;
  _INTR_LOG_INFO("AccelerationStructurePass: built %u BLASes.",
                 (uint32_t)newBlases.size());

  // --- Create TLAS AS storage -----------------------------------------------
  // Sized for the maximum possible instance count.

  _tlas = AccelerationStructureManager::createAccelerationStructure(_N(TLAS));
  AccelerationStructureManager::resetToDefault(_tlas);
  AccelerationStructureManager::_descType(_tlas) =
      AccelerationStructureType::kTopLevel;

  VkAccelerationStructureGeometryInstancesDataKHR instancesData = {};
  instancesData.sType =
      VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
  instancesData.arrayOfPointers = VK_FALSE;
  instancesData.data.deviceAddress = getBufferDeviceAddress(_instanceBuffer);

  VkAccelerationStructureGeometryKHR tlasGeom = {};
  tlasGeom.sType = VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
  tlasGeom.geometryType = VK_GEOMETRY_TYPE_INSTANCES_KHR;
  tlasGeom.geometry.instances = instancesData;

  AccelerationStructureManager::_descGeometries(_tlas).push_back(tlasGeom);
  AccelerationStructureManager::_descMaxPrimitiveCounts(_tlas).push_back(
      _INTR_MAX_MESH_COMPONENT_COUNT);

  {
    AccelerationStructureRefArray tlasArr = {_tlas};
    AccelerationStructureManager::createResources(tlasArr);
  }

  // Grow scratch if TLAS needs more than BLASes did.
  const VkDeviceSize tlasScratch =
      AccelerationStructureManager::_buildScratchSize(_tlas);
  if (tlasScratch > maxScratchNeeded)
  {
    freeDirectBuffer(_scratchBuffer, _scratchMemory);
    allocateDirectBuffer(tlasScratch,
                         VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                         VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                         _scratchBuffer, _scratchMemory);
  }
}

// ---------------------------------------------------------------------------

void AccelerationStructurePass::render(float /*p_DeltaT*/,
                                       Components::CameraRef /*p_CameraRef*/)
{
  if (!_blasesBuilt || !_tlas.isValid())
    return;

  // --- Collect instances ----------------------------------------------------
  uint32_t instanceCount = 0u;
  auto* instances =
      static_cast<VkAccelerationStructureInstanceKHR*>(_instanceMappedMemory);

  for (uint32_t mIdx = 0u;
       mIdx < Components::MeshManager::getActiveResourceCount() &&
       instanceCount < _INTR_MAX_MESH_COMPONENT_COUNT;
       ++mIdx)
  {
    Components::MeshRef meshCompRef =
        Components::MeshManager::getActiveResourceAtIndex(mIdx);

    if (!_blasPerMeshComp[meshCompRef._id].isValid())
      continue;

    const VkDeviceAddress blasAddr = AccelerationStructureManager::_deviceAddress(
        _blasPerMeshComp[meshCompRef._id]);

    // World transform: glm::mat4 (column-major) → VkTransformMatrixKHR (row-major 3×4)
    Components::NodeRef nodeRef = Components::NodeManager::getComponentForEntity(
        Components::MeshManager::_entity(meshCompRef));

    VkTransformMatrixKHR xfm = {};
    if (nodeRef.isValid())
    {
      const glm::mat4& m = Components::NodeManager::_worldMatrix(nodeRef);
      for (int row = 0; row < 3; ++row)
        for (int col = 0; col < 4; ++col)
          xfm.matrix[row][col] = m[col][row];
    }
    else
    {
      // Identity
      xfm.matrix[0][0] = xfm.matrix[1][1] = xfm.matrix[2][2] = 1.0f;
    }

    VkAccelerationStructureInstanceKHR& inst = instances[instanceCount];
    inst = {};
    inst.transform = xfm;
    inst.instanceCustomIndex = meshCompRef._id & 0x00FFFFFFu;
    inst.mask = 0xFFu;
    inst.instanceShaderBindingTableRecordOffset = 0u;
    inst.flags =
        VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
    inst.accelerationStructureReference = blasAddr;

    ++instanceCount;
  }

  if (instanceCount == 0u)
    return;

  // --- Build TLAS -----------------------------------------------------------
  VkCommandBuffer cmd = RenderSystem::getPrimaryCommandBuffer();

  const VkDeviceAddress scratchAddr = getBufferDeviceAddress(_scratchBuffer);
  const VkDeviceAddress instanceAddr = getBufferDeviceAddress(_instanceBuffer);

  // Update instance buffer address in geometry (device address may have
  // changed if we re-allocated; keep it fresh).
  AccelerationStructureManager::_descGeometries(_tlas)[0]
      .geometry.instances.data.deviceAddress = instanceAddr;

  VkAccelerationStructureBuildGeometryInfoKHR buildInfo = {};
  buildInfo.sType =
      VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
  buildInfo.type = VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
  buildInfo.flags = VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
  buildInfo.mode = VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
  buildInfo.dstAccelerationStructure =
      AccelerationStructureManager::_vkAccelerationStructure(_tlas);
  buildInfo.geometryCount = 1u;
  buildInfo.pGeometries =
      AccelerationStructureManager::_descGeometries(_tlas).data();
  buildInfo.scratchData.deviceAddress = scratchAddr;

  VkAccelerationStructureBuildRangeInfoKHR range = {};
  range.primitiveCount = instanceCount;
  const VkAccelerationStructureBuildRangeInfoKHR* pRange = &range;

  RenderSystem::pfnCmdBuildAccelerationStructuresKHR(cmd, 1u, &buildInfo,
                                                     &pRange);

  // Barrier: TLAS write must complete before RT shaders read it.
  insertAsBarrier(cmd,
                  VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
                  VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR);
}

}
}
}

#endif // _INTR_FEATURE_RAY_TRACING
