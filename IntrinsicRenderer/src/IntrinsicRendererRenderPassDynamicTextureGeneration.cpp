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

void DynamicTextureGeneration::init()
{
  BufferRefArray buffersToCreate;
  ImageRefArray imgsToCreate;

  for (auto& texture : dynamicGenerationTextures)
  {
    BufferRef _noiseParametersRef =
        BufferManager::createBuffer(_N(_ParametersBuffer));
    {
      BufferManager::resetToDefault(_noiseParametersRef);
      BufferManager::addResourceFlags(
          _noiseParametersRef,
          Dod::Resources::ResourceFlags::kResourceVolatile);
      BufferManager::_descBufferType(_noiseParametersRef) =
          BufferType::kStorage;
      BufferManager::_descMemoryPoolType(_noiseParametersRef) =
          MemoryPoolType::kStaticStagingBuffers;
      BufferManager::_descSizeInBytes(_noiseParametersRef) =
          sizeof(noiseParams);
      BufferManager::_descInitialData(_noiseParametersRef) = noiseParams;
	}
    texture->_noiseParametersRef = _noiseParametersRef;
    buffersToCreate.push_back(_noiseParametersRef);

	if (texture->hasSourceTex)
	{
		ImageRef _textureSourceRef =
			ImageManager::getResourceByName(*texture->textureSourceName);
		texture->_textureSourceRef = _textureSourceRef;
	}

    ImageRef _textureImageRef =
        ImageManager::createImage(*texture->textureName);
    {
      ImageManager::resetToDefault(_textureImageRef);
      ImageManager::addResourceFlags(
          _textureImageRef,
		  Dod::Resources::ResourceFlags::kResourceVolatile);
      ImageManager::_descDimensions(_textureImageRef) =
          glm::uvec3((unsigned)*(texture->sizeX), (unsigned)*(texture->sizeY), 1);
      ImageManager::_descMipLevelCount(_textureImageRef) = 1u;
	  ImageManager::_descImageFormat(_textureImageRef) = Format::kR8G8B8A8UNorm;
      ImageManager::_descImageType(_textureImageRef) =
		  ImageType::kTexture;
      ImageManager::_descImageFlags(_textureImageRef) =
          ImageFlags::kUsageSampled | ImageFlags::kUsageStorage;
    }
    texture->_textureImageRef = _textureImageRef;
    imgsToCreate.push_back(_textureImageRef);
  }

  ImageManager::createResources(imgsToCreate);
  BufferManager::createResources(buffersToCreate);

  // Transition generated textures from UNDEFINED to GENERAL for first compute dispatch
  VkCommandBuffer initCmd = RenderSystem::beginTemporaryCommandBuffer();
  for (auto& texture : dynamicGenerationTextures)
  {
    ImageManager::insertImageMemoryBarrier(
        initCmd, texture->_textureImageRef,
        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);
  }
  RenderSystem::flushTemporaryCommandBuffer();
}

void DynamicTextureGeneration::postInit()
{
  PipelineRefArray pipelinesToCreate;
  PipelineLayoutRefArray pipelineLayoutsToCreate;
  ComputeCallRefArray computeCallsToCreate;

  for (auto& texture : dynamicGenerationTextures)
  {
    PipelineLayoutRef pipelineLayoutTexture;
    {
      pipelineLayoutTexture =
          PipelineLayoutManager::createPipelineLayout(_N(TextureGeneration));
      PipelineLayoutManager::resetToDefault(pipelineLayoutTexture);

      GpuProgramManager::reflectPipelineLayout(
          1u, {GpuProgramManager::getResourceByName(*(texture->shaders[0]))},
          pipelineLayoutTexture);
      pipelineLayoutsToCreate.push_back(pipelineLayoutTexture);
    }

    {
      PipelineRef _pipelineTextureRef =
          PipelineManager::createPipeline(_N(TextureGeneration));
      PipelineManager::resetToDefault(_pipelineTextureRef);
      PipelineManager::_descComputeProgram(_pipelineTextureRef) =
          GpuProgramManager::getResourceByName(*(texture->shaders[0]));
      PipelineManager::_descPipelineLayout(_pipelineTextureRef) =
          pipelineLayoutTexture;
      texture->_pipelineTextureRef = _pipelineTextureRef;
      pipelinesToCreate.push_back(_pipelineTextureRef);
    }

    const glm::uvec3 computeDim =
		glm::uvec3(texture->sizes[0], texture->sizes[1], texture->sizes[2]);

    ComputeCallRef _computeCallTextureRef =
        ComputeCallManager::createComputeCall(_N(TextureGeneration));
    {
      ComputeCallManager::resetToDefault(_computeCallTextureRef);
      ComputeCallManager::addResourceFlags(
          _computeCallTextureRef, Dod::Resources::ResourceFlags::kResourceVolatile);
      ComputeCallManager::_descDimensions(_computeCallTextureRef) =
          glm::uvec3(computeDim);
      ComputeCallManager::_descPipeline(_computeCallTextureRef) =
          texture->_pipelineTextureRef;

	  if (texture->hasSourceTex)
	  {
		  ComputeCallManager::bindImage(
			  _computeCallTextureRef, _N(_SourceTex), GpuProgramType::kCompute,
			  texture->_textureSourceRef, Samplers::kNearestRepeat);
	  }

      ComputeCallManager::bindImage(
          _computeCallTextureRef, _N(_TextureTex), GpuProgramType::kCompute,
          texture->_textureImageRef, Samplers::kNearestRepeat);
      ComputeCallManager::bindBuffer(
          _computeCallTextureRef, _N(_ParametersBuffer),
          GpuProgramType::kCompute, texture->_noiseParametersRef,
          UboType::kPerInstanceCompute,
          BufferManager::_descSizeInBytes(texture->_noiseParametersRef));
    }
    texture->_computeCallTextureRef = _computeCallTextureRef;
    computeCallsToCreate.push_back(_computeCallTextureRef);
  }

  PipelineLayoutManager::createResources(pipelineLayoutsToCreate);
  PipelineManager::createResources(pipelinesToCreate);
  ComputeCallManager::createResources(computeCallsToCreate);
}

void DynamicTextureGeneration::onReinitRendering()
{
  VkCommandBuffer initCmd = RenderSystem::beginTemporaryCommandBuffer();
  for (auto& texture : dynamicGenerationTextures)
  {
    ImageManager::insertImageMemoryBarrier(
        initCmd, texture->_textureImageRef,
        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        VK_PIPELINE_STAGE_ALL_COMMANDS_BIT);
    texture->isCalled = true;
    texture->counter = 0;
  }
  RenderSystem::flushTemporaryCommandBuffer();
}

void DynamicTextureGeneration::destroy() {}

// <-

_INTR_INLINE static void updateDataMemory(void* p_Data, BufferRef bufferRef,
                                          uint32_t p_Size, uint32_t p_Offset)
{
  memcpy((uint8_t*)BufferManager::getGpuMemory(bufferRef) + p_Offset, p_Data,
         p_Size);
}

void DynamicTextureGeneration::render(float p_DeltaT, CameraRef p_CameraRef)
{
  _INTR_PROFILE_CPU("Render Pass", "Render Dynamic Geometry Generation");
  _INTR_PROFILE_GPU("Dynamic Geometry Generation");

  noiseParams[0] += p_DeltaT * 0.1f;

  for (auto& texture : dynamicGenerationTextures)
  {
    if (texture->isDynamic)
	{
      BufferRef buffer = texture->_noiseParametersRef;
      updateDataMemory(noiseParams, buffer,
                       BufferManager::_descSizeInBytes(buffer), 0);
	}
	else
	{
	  if (texture->isCalled && texture->counter > 2)
		continue;
	}

    VkCommandBuffer primaryCmdBuffer = RenderSystem::getPrimaryCommandBuffer();

    // UNDEFINED as oldLayout is always valid — compute shader writes the entire
    // texture so discarding previous contents is safe.
    ImageManager::insertImageMemoryBarrier(texture->_textureImageRef,
        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
        VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);

    if (texture->hasSourceTex)
    {
      ImageManager::insertImageMemoryBarrier(texture->_textureSourceRef,
          VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
          VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
          VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);
    }

    RenderSystem::dispatchComputeCall(texture->_computeCallTextureRef,
                                      primaryCmdBuffer);

    ImageManager::insertImageMemoryBarrier(texture->_textureImageRef,
        VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);

    if (texture->hasSourceTex)
    {
      ImageManager::insertImageMemoryBarrier(texture->_textureSourceRef,
          VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
          VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
          VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT);
    }

    texture->isCalled = true;
    texture->counter++;
  }
}

} // namespace RenderPass
} // namespace Renderer
} // namespace Intrinsic
