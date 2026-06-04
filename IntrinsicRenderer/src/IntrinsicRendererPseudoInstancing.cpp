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

using namespace RResources;
using namespace CComponents;
using namespace CResources;

namespace Intrinsic
{
namespace Renderer
{

std::vector<std::unique_ptr<InstancedMesh>>
    PseudoInstancing::meshes;

std::vector<Voxel> PseudoInstancing::voxels;
std::vector<Voxel> PseudoInstancing::normals;

void PseudoInstancing::addPseudoInstancingMesh(Name&& name,
                                               const unsigned& sizeX,
                                               const unsigned& sizeZ,
                                               const float& probability)
{
  std::unique_ptr<InstancedMesh> mesh = std::make_unique<InstancedMesh>();
  mesh->name = std::make_unique<Name>(name);
  mesh->sizeX = sizeX;
  mesh->sizeZ = sizeZ;
  mesh->vertexNum = 0;
  mesh->probability = probability;
  mesh->tempVexrtexBuffer = nullptr;
  mesh->vertexBufferRef = BufferRef();

  meshes.push_back(std::move(mesh));
}

bool PseudoInstancing::isInstancedMesh(const Name& meshName)
{
  for (auto& i : Intrinsic::Renderer::PseudoInstancing::meshes)
  {
    const Name& name = *(i->name);

    if (meshName == name)
      return true;
  }

  return false;
}

std::vector<std::unique_ptr<InstancedMesh>>& PseudoInstancing::getMeshes()
{
  return meshes;
}

std::unique_ptr<InstancedMesh>&
PseudoInstancing::getMeshSizes(const Name& meshName)
{
  for (auto& i : Intrinsic::Renderer::PseudoInstancing::meshes)
  {
    const Name& name = *(i->name);

    if (meshName == name)
      return i;
  }
  _INTR_ASSERT(false && "getMeshSizes: mesh not found");
  return meshes.front();
}

void transformPosition(uint16_t* srcBuffer, uint16_t* dstBuffer, unsigned int i,
                       float angle, glm::vec3& rot, glm::vec3 trans, glm::vec3& scale, glm::vec3& offset)
{
  uint16_t* src0 = &srcBuffer[i];
  uint16_t* src1 = &srcBuffer[i + 1];
  uint16_t* src2 = &srcBuffer[i + 2];

  float result0 = glm::unpackHalf1x16(*src0);
  float result1 = glm::unpackHalf1x16(*src1);
  float result2 = glm::unpackHalf1x16(*src2);

  glm::vec4 offset4 = glm::vec4(offset.x, offset.y, offset.z, 0.0);

  glm::vec4 pos = glm::vec4(result0, result1, result2, 1.0) - offset4;

  glm::mat4 rotation = glm::rotate(angle, rot);
  
  glm::mat4 dimention = glm::scale(scale);
  
  trans *= 0.1f;

  glm::mat4 translation =
      glm::translate(trans);

  glm::vec4 result = translation * rotation * dimention * pos;
  result += offset4;

  uint16_t* dst0 = &dstBuffer[i];
  uint16_t* dst1 = &dstBuffer[i + 1];
  uint16_t* dst2 = &dstBuffer[i + 2];

  *dst0 = glm::packHalf1x16(result.x);
  *dst1 = glm::packHalf1x16(result.y);
  *dst2 = glm::packHalf1x16(result.z);
}

int getIndex(int x, int z, int sizeX, int numMeshVertices)
{
  int index = 3 * numMeshVertices * (z * sizeX + x);

  return index;
}

glm::vec3 getOffset(uint16_t* srcBuffer, int i1, int i2)
{
  uint16_t* src0 = &srcBuffer[i1];
  uint16_t* src1 = &srcBuffer[i1 + 1];
  uint16_t* src2 = &srcBuffer[i1 + 2];

  float srcX = glm::unpackHalf1x16(*src0);
  float srcY = glm::unpackHalf1x16(*src1);
  float srcZ = glm::unpackHalf1x16(*src2);

  uint16_t* dst0 = &srcBuffer[i2];
  uint16_t* dst1 = &srcBuffer[i2 + 1];
  uint16_t* dst2 = &srcBuffer[i2 + 2];

  float dstX = glm::unpackHalf1x16(*dst0);
  float dstY = glm::unpackHalf1x16(*dst1);
  float dstZ = glm::unpackHalf1x16(*dst2);

  return glm::vec3(dstX - srcX, dstY - srcY, dstZ - srcZ);
}

void transformMesh(int x, int y, int sizeX, int numMeshVertices,
                   uint16_t* srcBuffer, uint16_t* dstBuffer, float angle,
                   glm::vec3& rot, glm::vec3& trans, glm::vec3 scale)
{
  int ref = getIndex(0, y, sizeX, numMeshVertices);
  int start = getIndex(x, y, sizeX, numMeshVertices);
  int end = getIndex(x + 1, y, sizeX, numMeshVertices);

  glm::vec3 offset = getOffset(srcBuffer, ref, start);

  for (int i = start; i < end; i += 3)
  {
    transformPosition(srcBuffer, dstBuffer, i, angle, rot, trans, scale, offset);
  }
}

void PseudoInstancing::populateMeshes()
{
  if (voxels.size() == 0)
    return;

  static std::random_device rd;  // you only need to initialize it once
  static std::mt19937 mte(rd()); // this is a relative big object to create

  std::uniform_real_distribution<float> dist(-0.005f, 0.005f);

  char buffer[256];

  int j = 0;
  int i = 0;
  for (i = 0; i < 270;)
  {
    sprintf(buffer, "PJTerrain%d", i);
    Name name = std::move(buffer);

    //_INTR_LOG_WARNING("%s", name.getString().c_str());

    Entity::EntityRef entityRef = Entity::EntityManager::getEntityByName(name);
    NodeRef nodeRef = NodeManager::getComponentForEntity(entityRef);

    if (!nodeRef.isValid())
    {
      i++;
      continue;
    }

	//_INTR_LOG_WARNING("%f %f %f", voxels[j].x, voxels[j].y, voxels[j].z);

    if (voxels[j].y < 32.0)
    {
      j += 4;
      continue;
    }

    //_INTR_LOG_WARNING("Ustawiam %s", name.getString().c_str());
    
    NodeManager::setSize(nodeRef,
                         glm::vec3(0.01, 0.01 + dist(mte), 0.01));

	//NodeManager::setSize(nodeRef, glm::vec3(0.04, 0.04, 0.04));

    glm::vec3 position =
        glm::vec3(127.0 * (voxels[j].x - 32.0),
                  127.0 * (voxels[j].y - 0.5 * (1.0 - normals[j].y)),
				  127.0 * (voxels[j].z - 32.0));
	
    NodeManager::setPosition(nodeRef, position);
    
    const glm::vec3 euler =
        glm::vec3(normals[j].x * 0.5, normals[j].y * 0.5, normals[j].z * 0.5);

    NodeManager::setOrientation(nodeRef, glm::quat(euler));
	
    Components::NodeManager::rebuildTreeAndUpdateTransforms();

    j += 4;
    i++;

	//sprintf(buffer, "PJTerrain%d", i - 500);
	//Name newName = Name(buffer);
    //Entity::EntityManager::rename(entityRef, newName);
  }
}

void PseudoInstancing::generateInstances()
{
  for (auto& mesh : Intrinsic::Renderer::PseudoInstancing::meshes)
  {
	  uint16_t* _vertexBufferGpuMemory = 
		  (uint16_t*)BufferManager::getGpuMemory(mesh->vertexBufferRef);

	  int sizeX = mesh->sizeX;
	  int sizeZ = mesh->sizeZ;
	  int vertexNum = mesh->vertexNum;

	  static std::random_device rd; // you only need to initialize it once
      static std::mt19937 mte(rd()); // this is a relative big object to create

      std::uniform_real_distribution<float> height(0.8f, 1.2f);
      std::uniform_real_distribution<float> rot(0.0f, 2.0f * 3.1415f);

	  for (int x = 0; x < sizeX; x++)
		for (int z = 0; z < sizeZ; z++)
		{
          glm::vec3 scale = glm::vec3(glm::vec3(1.0, height(mte), 1.0));

		  transformMesh(x, z, sizeX, vertexNum, mesh->tempVexrtexBuffer,
						_vertexBufferGpuMemory, rot(mte),
			  glm::vec3(0.0, 1.0, 0.0),
			  glm::vec3(static_cast<float>(x - sizeX / 2) * 50.0, 0.0,
				  static_cast<float>(z - sizeZ / 2) * 50.0), scale);
		}

	  BufferManager::updateResources(
		  mesh->vertexBufferRef, reinterpret_cast<void*>(_vertexBufferGpuMemory));
  }
}

} // namespace Renderer
} // namespace Intrinsic