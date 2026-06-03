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

#define _IS_OVERRIDEN_TEXTURE(name) Intrinsic::Renderer::RenderPass::DynamicTextureGeneration::isOverridenTexture(name)

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

struct DynamicGeneratedTexture
{
  DynamicGeneratedTexture(const int& sizeX, const int& sizeY,
					   const int& sizeZ, const Name& textureName,
					   const Name&& textureGenerationShader,
					   bool isDynamic)
  {
    this->textureName = std::make_unique<Name>(textureName);
    this->isDynamic = isDynamic;
    this->hasSourceTex = false;

	sizes[0] = sizeX;
    sizes[1] = sizeY;
    sizes[2] = sizeZ;
    sizes[3] = 1;

    // redundant
    this->sizeX = &sizes[0];
    this->sizeY = &sizes[1];
    this->sizeZ = &sizes[2];

    shaders.push_back(std::make_unique<Name>(textureGenerationShader));
  }

  DynamicGeneratedTexture(const int& sizeX, const int& sizeY, const int& sizeZ,
                          const Name& textureSrcName, const Name& textureDstName,
                          const Name&& textureGenerationShader, bool isDynamic)
  {
    this->textureSourceName = std::make_unique<Name>(textureSrcName);
    this->textureName = std::make_unique<Name>(textureDstName);
    this->isDynamic = isDynamic;
    this->hasSourceTex = true;

    sizes[0] = sizeX;
    sizes[1] = sizeY;
    sizes[2] = sizeZ;
    sizes[3] = 1;

    // redundant
    this->sizeX = &sizes[0];
    this->sizeY = &sizes[1];
    this->sizeZ = &sizes[2];

    shaders.push_back(std::make_unique<Name>(textureGenerationShader));
  }

  std::vector<std::unique_ptr<Name>> shaders;
  std::unique_ptr<Name> textureName;
  std::unique_ptr<Name> textureSourceName;

  ImageRef _textureImageRef;
  ImageRef _textureSourceRef;
  BufferRef _noiseParametersRef;
  PipelineRef _pipelineTextureRef;
  ComputeCallRef _computeCallTextureRef;

  int counter = 0;
  bool isCalled = false;
  bool isDynamic;
  bool hasSourceTex = false;
  int *sizeX, *sizeY, *sizeZ;
  int sizes[4];
};

struct DynamicTextureGeneration
{
  static std::vector<std::unique_ptr<DynamicGeneratedTexture>>
      dynamicGenerationTextures;

  static void addDynamicGeneradtedTexture(const int& sizeX, const int& sizeY,
                                          const int& sizeZ,
										  const Name&,const Name&&,
										  bool isDynamic = true);

  static void addDynamicGeneradtedTexture(const int& sizeX, const int& sizeY,
                                          const int& sizeZ, const Name&,
                                          const Name&, const Name&&, bool isDynamic = true);

  static bool isOverridenTexture(const Name&);

  static void loadFromMultipleFiles(const char* p_Path);

  static void init();
  static void onReinitRendering();

  static void postInit();
  static void destroy();

  static void render(float p_DeltaT, Components::CameraRef p_CameraRef);
};
}
}
}
