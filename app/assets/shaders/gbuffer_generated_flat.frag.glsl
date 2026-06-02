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
layout(location = 5) in vec3 inPosition;
layout(location = 6) in vec3 inViewPosition;

// Output
OUTPUT

vec3 tex3D(vec3 pos, vec3 nor, sampler2D s) {
    return texture(s, pos.yz).xyz * abs(nor.x) +
           texture(s, pos.xz).xyz * abs(nor.y) +
           texture(s, pos.xy).xyz * abs(nor.z);
}

vec3 tex3DNormal(vec3 pos, vec3 nor, sampler2D s) {
    return textureNormal(s, pos.yz) * abs(nor.x) +
           textureNormal(s, pos.xz) * abs(nor.y) +
           textureNormal(s, pos.xy) * abs(nor.z);
}

mat3 cotangent_frame(vec3 N, vec3 p, vec2 uv) {
    vec3 dp1 = dFdx(p);
    vec3 dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = dFdy(uv);
    vec3 dp2perp = cross(dp2, N);
    vec3 dp1perp = cross(N, dp1);
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;
    float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
    return mat3(T * invmax, B * invmax, N);
}

void main()
{
  vec3 geoNormalM = normalize(cross(dFdx(inPosition), dFdy(inPosition)));
  vec3 _triW = abs(geoNormalM);
  _triW /= (_triW.x + _triW.y + _triW.z + 0.0001);
  vec3 _pos = inPosition;

  // Per-face TBNs: each uses the UV coords for that projection face so the
  // cotangent frame correctly maps tangent-space normals to view space.
  const mat3 TBN_X = cotangent_frame(inNormal, inViewPosition, inPosition.yz);
  const mat3 TBN_Y = cotangent_frame(inNormal, inViewPosition, inPosition.xz);
  const mat3 TBN_Z = cotangent_frame(inNormal, inViewPosition, inPosition.yx);

  GBuffer gbuffer;
  {
    vec3 _albedo = texture(albedoTex, _pos.yz).rgb * _triW.x +
                   texture(albedoTex, _pos.xz).rgb * _triW.y +
                   texture(albedoTex, _pos.xy).rgb * _triW.z;
    gbuffer.albedo = vec4(_albedo, 1.0) * uboPerInstance.colorTint;
    vec3 nX = TBN_X * textureNormal(normalTex, inPosition.yz).xyz;
    vec3 nY = TBN_Y * textureNormal(normalTex, inPosition.xz).xyz;
    vec3 nZ = TBN_Z * textureNormal(normalTex, inPosition.yx).xyz;
    // SDF voxels are stored as -SDF, so the gradient (inNormal) is inward.
    // Reflect about the tangent plane to flip base direction outward while
    // preserving the tangential bump perturbation.
    vec3 n = normalize(nX * _triW.x + nY * _triW.y + nZ * _triW.z);
    gbuffer.normal = reflect(n, inNormal);
    const vec2 pbr = tex3D(inPosition, geoNormalM, pbrTex).rg;
    gbuffer.metalMask = pbr.r + uboPerMaterial.pbrBias.r;
    gbuffer.specular = 0.5 + uboPerMaterial.pbrBias.g;
    gbuffer.roughness = adjustRoughness(pbr.g + uboPerMaterial.pbrBias.b,
                                        uboPerMaterial.data1.x);
    gbuffer.materialBufferIdx = uboPerMaterial.data0.x;
    gbuffer.emissive = tex3D(inPosition, geoNormalM, emissiveTex).r * 0.1;
    gbuffer.occlusion = 1.0;
  }
  writeGBuffer(gbuffer, outAlbedo, outNormal, outParameter0);
}
