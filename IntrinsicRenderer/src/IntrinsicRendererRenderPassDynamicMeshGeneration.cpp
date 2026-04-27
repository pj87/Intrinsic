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

// Precompiled header file
#include "stdafx.h"
#include <random>
#include <fstream>

using namespace RResources;
using namespace CComponents;
using namespace CResources;

namespace Intrinsic
{
namespace Renderer
{
namespace RenderPass
{
namespace
{
  // (lookup tables and compute call helpers added in subsequent commits)
} // namespace

// Static members

std::vector<std::unique_ptr<DynamicGeneratedMesh>>
    DynamicMeshGeneration::dynamicGenerationMeshes;

std::vector<std::unique_ptr<Name>> pseudoInstancedMeshes;

void DynamicMeshGeneration::addDynamicGeneratedMesh(
    const int& sizeX, const int& sizeY, const int& sizeZ,
	const Name& meshName, const Name&& voxelGenerationShader,
    const Name&& normalGenerationShader, const Name&& geometryGenerationShader,
	bool isDynamic, float firstParam, float secondParam)
{
  std::unique_ptr<DynamicGeneratedMesh> dynamicGenerationMesh =
      std::make_unique<DynamicGeneratedMesh>(
          sizeX, sizeY, sizeZ,
          std::move(meshName), std::move(voxelGenerationShader),
          std::move(normalGenerationShader),
          std::move(geometryGenerationShader),
		  isDynamic, firstParam, secondParam);

  dynamicGenerationMeshes.push_back(std::move(dynamicGenerationMesh));
}

bool DynamicMeshGeneration::isOverridenMesh(const Name& meshName)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    if ((*mesh->meshName) == meshName)
      return true;
  }
  return false;
}

bool DynamicMeshGeneration::isDynamicMesh(const Name& meshName)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    if ((*mesh->meshName) == meshName)
      return mesh->isDynamic;
  }
  return false;
}

unsigned DynamicMeshGeneration::getIndicesNumber(const Name& meshName)
{
  for (auto& mesh : dynamicGenerationMeshes)
  {
    if ((*mesh->meshName) == meshName)
      return mesh->indicesNumber;
  }
  return 0u;
}

void DynamicMeshGeneration::init() {}

void DynamicMeshGeneration::postInit() {}

void DynamicMeshGeneration::onReinitRendering() {}

void DynamicMeshGeneration::destroy() {}

static void obfuscateMesh(DynamicGeneratedMesh& mesh) {}

void DynamicMeshGeneration::render(float p_DeltaT, CameraRef p_CameraRef) {}

void DynamicMeshGeneration::update(const Name& name, const float& p_DeltaT) {}

void DynamicMeshGeneration::update(float p_DeltaT) {}

void DynamicMeshGeneration::moveEntities(const Name& name,
                                         const float& p_DeltaT,
                                         const float& offset) {}

void DynamicMeshGeneration::aquireVoxelsAndNormals(DynamicGeneratedMesh& mesh) {}

float DynamicMeshGeneration::getVoxel(DynamicGeneratedMesh& mesh,
                                      int x, int y, int z)
{
  return 0.0f;
}

glm::vec3 DynamicMeshGeneration::getNormal(DynamicGeneratedMesh& mesh,
                                           int x, int y, int z)
{
  return glm::vec3(0.0f);
}

} // namespace RenderPass
} // namespace Renderer
} // namespace Intrinsic
