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

#include <random>
#include <algorithm>

#define _IS_INSTANCED_MESH(name)                                               \
  Intrinsic::Renderer::PseudoInstancing::isInstancedMesh(name)

#define _INSTANCED_MESH_SIZE(name)                                               \
  Intrinsic::Renderer::PseudoInstancing::getMeshSizes(name)

typedef Dod::Ref BufferRef;
typedef _INTR_ARRAY(BufferRef) BufferRefArray;

namespace Intrinsic
{
namespace Renderer
{

struct Voxel
{
  float x, y, z;
};

typedef struct
{
  std::unique_ptr<Name> name;
  unsigned int sizeX, sizeZ;
  unsigned int vertexNum;
  float probability;
  uint16_t* tempVexrtexBuffer;
  BufferRef vertexBufferRef;
} InstancedMesh;

struct PseudoInstancing
{
public:
  static void addPseudoInstancingMesh(Name&&, const unsigned&, 
	  const unsigned&, const float&);

  static bool isInstancedMesh(const Name&);

  static std::unique_ptr<InstancedMesh>&
	  getMeshSizes(const Name&);

  static void generateInstances();

  template <class Iter>
  static void fillWithRandomFloatValues(Iter start, Iter end, float probability)
  {
    static std::random_device rd;  // you only need to initialize it once
    static std::mt19937 mte(rd()); // this is a relative big object to create

    std::uniform_real_distribution<float> dist(0.0f, 1.0f);

    std::generate(start, end, [&]() { return dist(mte) < probability; });
  }

  static std::vector<Voxel> voxels;
  static std::vector<Voxel> normals;

  static void populateMeshes();

private:
  static std::vector<std::unique_ptr<InstancedMesh>>
      meshes;

  static std::vector<std::unique_ptr<InstancedMesh>>&
	  getMeshes();
};
}
}
