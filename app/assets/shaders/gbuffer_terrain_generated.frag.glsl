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
BINDINGS_TERRAIN;

// Input
layout(location = 0) in vec3 inNormal;
layout(location = 1) in vec3 inTangent;
layout(location = 2) in vec3 inBinormal;
layout(location = 3) in vec3 inColor;
layout(location = 4) in vec2 inUV0;
layout(location = 5) in vec3 inPosition;
layout(location = 7) in vec3 inNormalTPM;

// Output
OUTPUT

const vec4 cHashA4 = vec4 (0., 1., 57., 58.);
const vec3 cHashA3 = vec3 (1., 57., 113.);
const float cHashM = 43758.54;

vec4 Hashv4f (float p)
{
  return fract (sin (p + cHashA4) * cHashM);
}

float Noisefv2 (vec2 p)
{
  vec2 ip = floor (p);
  vec2 fp = fract (p);
  fp = fp * fp * (3. - 2. * fp);
  vec4 t = Hashv4f (dot (ip, cHashA3.xy));
  return mix (mix (t.x, t.y, fp.x), mix (t.z, t.w, fp.x), fp.y);
}

float Fbmn (vec3 p, vec3 n)
{
  vec3 s;
  float a;
  s = vec3 (0.);
  a = 1.;
  for (int i = 0; i < 5; i ++) {
    s += a * vec3 (Noisefv2 (p.yz), Noisefv2 (p.zx), Noisefv2 (p.xy));
    a *= 0.5;
    p *= 20.;
  }
  return dot (s, abs (n));
}

vec3 tex3DBlendMask(vec3 pos, vec3 nor, sampler2D s) {
    return texture( s, (pos.xz - 1.6) * 0.25).xyz*abs(nor.y);
}

vec3 tex3DGrass(vec3 pos, vec3 nor, sampler2D s) {
    return texture( s, (pos.xz - 3.0) * 5.0).xyz*abs(nor.y);
}

vec3 tex3DNormalGrass(vec3 pos, vec3 nor, sampler2D s) {
    return textureNormal( s, (pos.xz - 3.0) * 5.0).xyz*abs(nor.y);
}

vec3 tex3D(vec3 pos, vec3 nor, sampler2D s) {
    return texture( s, (pos.xz - 2.0) * 0.5).xyz*abs(nor.y);
}

vec3 tex3DNormal(vec3 pos, vec3 nor, sampler2D s) {
    return textureNormal( s, (pos.xz - 2.0) * 0.5).xyz*abs(nor.y);
}


vec3 blend(vec3 grass0, vec3 stone0, vec3 stone1, vec3 blendMask, float noise)
{
  return mix(grass0, mix(stone0, stone1, 1.0 - noise),
             clamp(blendMask.b * 3.0, 0.0, 1.0));
}

vec3 contrast(vec3 color, float contrast)
{
  return ((color.rgb - 0.5) * max(contrast, 0)) + 0.5;
}

float contrast(float color, float contrast)
{
  return ((color - 0.5) * max(contrast, 0)) + 0.5;
}

mat3 cotangent_frame( vec3 N, vec3 p, vec2 uv )
{
    // get edge vectors of the pixel triangle
    vec3 dp1 = dFdx( p );
    vec3 dp2 = dFdy( p );
    vec2 duv1 = dFdx( uv );
    vec2 duv2 = dFdy( uv );

    // solve the linear system
    vec3 dp2perp = cross( dp2, N );
    vec3 dp1perp = cross( N, dp1 );
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    // construct a scale-invariant frame 
    float invmax = inversesqrt( max( dot(T,T), dot(B,B) ) );
    return mat3( T * invmax, B * invmax, N );
}

void main()
{
  //const mat3 TBN = mat3(inTangent, inBinormal, inNormal);
  const mat3 TBN = cotangent_frame(inNormal, inPosition, inUV0);

  const vec2 uv0 = UV0_TRANSFORM_ANIMATED(inUV0);
  const vec2 uv0Raw = UV0(inUV0);

  float value = min (1.25 * Fbmn (1.0 * inPosition, vec3(.1)), 1.);

  const vec4 albedo0 = vec4(tex3DGrass(inPosition, inNormalTPM, albedoTex0), 1.0);
  const vec3 normal0 = tex3DNormalGrass(inPosition, inNormalTPM, normalTex0);
  const vec3 pbr0 = tex3DGrass(inPosition, inNormalTPM, pbrTex0).rgg;

  const vec4 albedo1 = vec4(tex3D(inPosition, inNormalTPM, albedoTex1), 1.0);
  const vec3 normal1 = tex3DNormal(inPosition, inNormalTPM, normalTex1);
  const vec3 pbr1 = tex3D(inPosition, inNormalTPM, pbrTex1).rgg;

  //const vec4 albedo2 = vec4(tex3D(inPosition * 0.25, inNormalTPM, albedoTex2), 1.0);
  const vec4 albedo2 = vec4(value, value, value, 1.0);
  const vec3 normal2 = tex3DNormal(inPosition * 0.25, inNormalTPM, normalTex2);
  const vec3 pbr2 = tex3D(inPosition * 0.1, inNormalTPM, pbrTex2).rgg;

  float noise = clamp(tex3D(inPosition * 10.0, inNormalTPM, noiseTex).r, 0.0, 1.0);
  vec3 blendMask = tex3DBlendMask(inPosition, inNormalTPM, blendMaskTex).rgb;
  //vec3 blendMask = texture(blendMaskTex, uv0 * 1.0).rgb;
  
  vec3 albedo = blend(albedo0.rgb * 1.0, albedo1.rgb * 1.0, albedo2.rgb * 0.0, blendMask, noise);
  vec3 normal = blend(normal0.rgb * 1.0, normal1.rgb * 1.0, normal2.rgb * 0.0, blendMask, noise);
  vec2 pbr = blend(pbr0.rgb * 1.0, pbr1.rgb * 1.0, pbr2.rgb * 0.0, blendMask, noise).rg;
  
  //vec3 albedo = pbr0.rgb;
  //vec3 albedo = albedo1.rgb;
  //vec3 albedo = normal0.rgb * 0.9 + albedo0.rgb * 0.1;
  //vec3 normal = vec3(0.0);
  //vec2 pbr = vec2(0.0);
  
  /*
  //vec3 albedo = blend(normal0.rgb * 1.0, albedo1.rgb * 1.0, albedo2.rgb * 0.0, blendMask, noise);
  //vec3 albedo = normal2.rgb;
  //vec3 albedo = pbr2.rgb;
  //vec3 albedo = vec3(noise);
  vec3 albedo = blendMask.rgb;
  vec3 normal = vec3(0.0);
  vec2 pbr = vec2(0.0);
  */
  
  float occlusion =
      clamp(mix(clamp(noise * 5.0, 0.0, 1.0) * blendMask.b, 1.0 - blendMask.r,
                clamp((1.0 - blendMask.g) * 2.0 - 0.9, 0.0, 1.0)) *
                    2.0 +
                0.2,
            0.0, 1.0);
  albedo *= occlusion;
  
  GBuffer gbuffer;
  {
    gbuffer.albedo = vec4(albedo, 1.0) * uboPerInstance.colorTint;
    gbuffer.normal = normalize(TBN * normal);
    gbuffer.metalMask = pbr.r + uboPerMaterial.pbrBias.r;
    gbuffer.specular = 0.5 + uboPerMaterial.pbrBias.g;
    gbuffer.roughness = pbr.g + uboPerMaterial.pbrBias.b;
    gbuffer.materialBufferIdx = uboPerMaterial.data0.x;
    gbuffer.occlusion = 1.0;
    gbuffer.emissive = 0.0;
  }
  writeGBuffer(gbuffer, outAlbedo, outNormal, outParameter0);
}
