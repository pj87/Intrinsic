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
  float noiseParams[] = {0.02f, 2.0f, 0.5f};
} // namespace

// Static members

std::vector<std::unique_ptr<DynamicGeneratedTexture>>
    DynamicTextureGeneration::dynamicGenerationTextures;

void DynamicTextureGeneration::addDynamicGeneradtedTexture(
    const int& sizeX, const int& sizeY, const int& sizeZ,
	const Name& textureName, const Name&& textureGenerationShader,
	bool isDynamic)
{
  std::unique_ptr<DynamicGeneratedTexture> dynamicGenerationTexture =
      std::make_unique<DynamicGeneratedTexture>(
          sizeX, sizeY, sizeZ,
          std::move(textureName),
          std::move(textureGenerationShader),
		  isDynamic);

  dynamicGenerationTextures.push_back(std::move(dynamicGenerationTexture));
}

void DynamicTextureGeneration::addDynamicGeneradtedTexture(
    const int& sizeX, const int& sizeY, const int& sizeZ,
    const Name& textureSrcName, const Name& textureDstName,
    const Name&& textureGenerationShader,
    bool isDynamic)
{
  std::unique_ptr<DynamicGeneratedTexture> dynamicGenerationTexture =
      std::make_unique<DynamicGeneratedTexture>(
          sizeX, sizeY, sizeZ, std::move(textureSrcName),
          std::move(textureDstName), std::move(textureGenerationShader),
		  isDynamic);

  dynamicGenerationTextures.push_back(std::move(dynamicGenerationTexture));
}

bool DynamicTextureGeneration::isOverridenTexture(const Name& textureName)
{
  for (auto& texture : dynamicGenerationTextures)
  {
    if ((*texture->textureName) == textureName)
      return true;
  }
  return false;
}

void DynamicTextureGeneration::init() {}

void DynamicTextureGeneration::postInit() {}

void DynamicTextureGeneration::onReinitRendering() {}

void DynamicTextureGeneration::destroy() {}

void DynamicTextureGeneration::render(float p_DeltaT, CameraRef p_CameraRef) {}

} // namespace RenderPass
} // namespace Renderer
} // namespace Intrinsic
