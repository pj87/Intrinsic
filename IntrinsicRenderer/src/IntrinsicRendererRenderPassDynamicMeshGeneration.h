// Copyright 2020-2021 Paweł Jastrzębski
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

#define _IS_OVERRIDEN_MESH(name) Intrinsic::Renderer::RenderPass::DynamicMeshGeneration::isOverridenMesh(name)
#define _IS_DYNAMIC_MESH(name)                                               \
  Intrinsic::Renderer::RenderPass::DynamicMeshGeneration::isDynamicMesh(     \
      name)
#define _GET_INDICES_NUMBER(name)                                               \
  Intrinsic::Renderer::RenderPass::DynamicMeshGeneration::getIndicesNumber(    \
      name)
#define _GET_INDIRECT_BUFFER(name)                                               \
  Intrinsic::Renderer::RenderPass::DynamicMeshGeneration::getIndirectBuffer(    \
      name)

namespace Intrinsic
{
namespace Renderer
{
namespace RenderPass
{

// Forward declarations
typedef Dod::Ref BufferRef;
typedef _INTR_ARRAY(BufferRef) BufferRefArray;
typedef Dod::Ref ImageRef;
typedef _INTR_ARRAY(ImageRef) ImageRefArray;
typedef Dod::Ref PipelineRef;
typedef _INTR_ARRAY(PipelineRef) PipelineRefArray;
typedef Dod::Ref ComputeCallRef;
typedef _INTR_ARRAY(ComputeCallRef) ComputeCallRefArray;

struct DynamicGeneratedMesh
{
  DynamicGeneratedMesh(const int& sizeX, const int& sizeY,
					   const int& sizeZ, const Name& meshName,
                       const Name&& voxelGenerationShader,
                       const Name&& normalGenerationShader,
					   const Name&& geometryGenerationShader,
					   bool isDynamic, float firstParam,
					   float secondParam, int localSize)
  {
    this->meshName = std::make_unique<Name>(meshName);
    this->isDynamic = isDynamic;
    this->localSize = localSize;

	sizes[0] = sizeX;
    sizes[1] = sizeY;
    sizes[2] = sizeZ;
    sizes[3] = 1;

    // redundant
    this->sizeX = &sizes[0];
    this->sizeY = &sizes[1];
    this->sizeZ = &sizes[2];

	this->params[0] = 0.0;
	this->params[1] = firstParam;
    this->params[2] = secondParam;

    shaders.push_back(std::make_unique<Name>(voxelGenerationShader));
    shaders.push_back(std::make_unique<Name>(normalGenerationShader));
    shaders.push_back(std::make_unique<Name>(geometryGenerationShader));
  }

  std::vector<std::unique_ptr<Name>> shaders;
  std::unique_ptr<Name> meshName;

  BufferRef _positionBufferRef;
  BufferRef _normalBufferRef;
  BufferRef _binormalBufferRef;
  BufferRef _tangentBufferRef;
  BufferRef _colorBufferRef;
  BufferRef _uv0BufferRef;
  BufferRef _debugBufferRef;
  BufferRef _voxelBufferRef;
  BufferRef _voxelNormalBufferRef;
  BufferRef _cubeEdgeFlagsBufferRef;
  BufferRef _triangleConnectionBufferRef;
  BufferRef _sizesBufferRef;
  BufferRef _targetBufferRef;
  BufferRef _noiseParametersRef;
  BufferRef _vertexCountBufferRef;

  ImageRef _normalsImageRef;
  ImageRef _gradient3dImageRef;
  ImageRef _permTable2dImageRef;

  PipelineRef _pipelinePolygonizationRef;
  PipelineRef _pipelineVoxelGenerationRef;
  PipelineRef _pipelineNormalRef;

  ComputeCallRef _computeCallMarchingCubesRef;
  ComputeCallRef _computeCallVoxelGenerationRef;
  ComputeCallRef _computeCallNormalRef;

  float params[3];

  int renderCounter = 0;
  int updateCounter = 0;
  unsigned indicesNumber = 0;
  unsigned maxIndices = 0;  // grid*15, never changes after init
  bool isCalled = false;
  bool isDynamic;
  bool needsRecompute = true;  // cleared after first dispatch, set by update()
  int *sizeX, *sizeY, *sizeZ;
  int sizes[4];
  int localSize;
  float firstParam, secondParam;
};

struct DynamicMeshGeneration
{
  static std::vector<std::unique_ptr<DynamicGeneratedMesh>>
      dynamicGenerationMeshes;

  static void addDynamicGeneratedMesh(const int& sizeX, const int& sizeY, const int& sizeZ,
									   const Name&, const Name&&, const Name&&,
                                       const Name&&, bool isDynamic = true,
									   float firstParam = 0.0, float secondParam = 0.0,
									   int localSize = 6);

  static float getVoxel(DynamicGeneratedMesh& mesh, int x, int y, int z);
  static glm::vec3 getNormal(DynamicGeneratedMesh& mesh, int x, int y, int z);
  static void aquireVoxelsAndNormals(DynamicGeneratedMesh& mesh);

  static bool isOverridenMesh(const Name&);
  static bool isDynamicMesh(const Name&);
  static unsigned getIndicesNumber(const Name& meshName);
  static VkBuffer getIndirectBuffer(const Name& meshName);

  static void init();
  static void onReinitRendering();

  static void postInit();
  static void destroy();

  static void update(const Name& name, const float& p_DeltaT);
  static void update(float p_DeltaT);
  static void render(float p_DeltaT, Components::CameraRef p_CameraRef);
  static void moveEntities(const Name& name, const float& p_DeltaT,
						   const float& offset);
};
}
}
}
