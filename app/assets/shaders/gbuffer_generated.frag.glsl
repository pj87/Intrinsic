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

#version 450

#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable
#extension GL_GOOGLE_include_directive : enable

#include "lib_math.glsl"
#include "gbuffer.inc.glsl"

// Ubos
PER_MATERIAL_UBO;
PER_INSTANCE_UBO;

// Bindings
BINDINGS_GBUFFER;
layout(binding = 6) uniform sampler2D emissiveTex;

// Input
layout(location = 0) in vec3 inNormal;
layout(location = 1) in vec3 inTangent;
layout(location = 2) in vec3 inBinormal;
layout(location = 3) in vec3 inColor;
layout(location = 4) in vec2 inUV0;
layout(location = 5) in vec3 inPosition;
layout(location = 6) in vec3 inViewPosition;
layout(location = 7) in vec3 inNormalTPM;

// Output
OUTPUT

vec3 tex3D(vec3 pos, vec3 nor, sampler2D s) {
    return texture( s, pos.yz).xyz*abs(nor.x)+
           texture( s, pos.xz).xyz*abs(nor.y)+
           texture( s, pos.xy).xyz*abs(nor.z);
}

void main()
{
  vec3 geoNormal  = normalize(-inNormal);
  vec3 geoNormalM = normalize(cross(dFdx(inPosition), dFdy(inPosition)));
  vec3 _triW = abs(geoNormalM);
  _triW /= (_triW.x + _triW.y + _triW.z + 0.0001);
  vec3 _pos = inPosition;

  GBuffer gbuffer;
  {
    vec3 _albedo = texture(albedoTex, _pos.yz).rgb * _triW.x +
                   texture(albedoTex, _pos.xz).rgb * _triW.y +
                   texture(albedoTex, _pos.xy).rgb * _triW.z;
    gbuffer.albedo = vec4(_albedo, 1.0) * uboPerInstance.colorTint;
    gbuffer.normal = geoNormal;
    const vec2 pbr = tex3D(inPosition, geoNormalM, pbrTex).rg;
    gbuffer.metalMask = pbr.r + uboPerMaterial.pbrBias.r;
    gbuffer.specular = uboPerMaterial.pbrBias.g;
    gbuffer.roughness = adjustRoughness(pbr.g + uboPerMaterial.pbrBias.b,
                                        uboPerMaterial.data1.x);
    gbuffer.materialBufferIdx = uboPerMaterial.data0.x;
    gbuffer.emissive = tex3D(inPosition, geoNormalM, emissiveTex).r * 0.1;
    gbuffer.occlusion = 1.0;
  }
  writeGBuffer(gbuffer, outAlbedo, outNormal, outParameter0);
}
