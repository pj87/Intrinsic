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
BINDINGS_GBUFFER;
layout(binding = 6) uniform sampler2D emissiveTex;

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

vec3 tex3D(vec3 pos, vec3 nor, sampler2D s) {
    return texture( s, pos.yz).xyz*abs(nor.x)+
           texture( s, pos.xz).xyz*abs(nor.y)+
           texture( s, pos.xy).xyz*abs(nor.z);
}

vec3 tex3DNormal(vec3 pos, vec3 nor, sampler2D s) {
    return textureNormal( s, pos.yz).xyz*abs(nor.x)+
           textureNormal( s, pos.xz).xyz*abs(nor.y)+
           textureNormal( s, pos.xy).xyz*abs(nor.z);
}

vec4 tex3d(vec3 pos, vec3 normal)
{
	pos /= 4.0;

	// loook up brick texture, blended across xyz axis based on normal.
	vec4 texX = texture(albedoTex, pos.yz);
	vec4 texY = texture(albedoTex, pos.xz);
	vec4 texZ = texture(albedoTex, pos.xy);
	//vec4 tex = mix(texX, texZ, abs(normal.z));
	//tex = mix(tex, texY, abs(normal.y));//.zxyw;
	
	vec3 avgNormal = abs(normal);
	avgNormal / (avgNormal.x + avgNormal.y + avgNormal.z);
	
	vec4 albedo = texX * avgNormal.x + texY * avgNormal.y + texZ * avgNormal.z;
	
	return albedo;
}

vec4 tex3d_1(vec3 pos, vec3 normal)
{
	pos /= 4.0;

	// loook up brick texture, blended across xyz axis based on normal.
	vec4 texX = texture(emissiveTex, pos.yz);
	vec4 texY = texture(emissiveTex, pos.xz);
	vec4 texZ = texture(emissiveTex, pos.xy);
	//vec4 tex = mix(texX, texZ, abs(normal.z));
	//tex = mix(tex, texY, abs(normal.y));//.zxyw;
	
	vec3 avgNormal = abs(normal);
	avgNormal / (avgNormal.x + avgNormal.y + avgNormal.z);
	
	vec4 albedo = texX * avgNormal.x + texY * avgNormal.y + texZ * avgNormal.z;
	
	return albedo;
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

  GBuffer gbuffer;
  {
    gbuffer.albedo = vec4(inColor, 1.0) + vec4(mix(tex3D(inPosition, inNormalTPM, albedoTex), tex3D(inPosition / 10.0, inNormalTPM, emissiveTex), 1.0), 1.0) * uboPerInstance.colorTint;
    //gbuffer.albedo = vec4(inColor, 1.0) + mix(tex3d(inPosition, inNormalTPM), tex3d_1(inPosition, inNormalTPM), 1.0) * uboPerInstance.colorTint;
	//gbuffer.albedo = vec4(inColor, 1.0) + mix(texture(albedoTex, uv0), texture(emissiveTex, uv0), 1.0) * uboPerInstance.colorTint;
	
    gbuffer.normal = normalize(TBN * tex3DNormal(inPosition, inNormalTPM, normalTex));
	const vec2 pbr = tex3D(inPosition, inNormalTPM, pbrTex).rg;
    gbuffer.metalMask = pbr.r + uboPerMaterial.pbrBias.r;
    gbuffer.specular = uboPerMaterial.pbrBias.g;
    gbuffer.roughness = adjustRoughness(pbr.g + uboPerMaterial.pbrBias.b,
                                        uboPerMaterial.data1.x);
    gbuffer.materialBufferIdx = uboPerMaterial.data0.x;
	gbuffer.emissive = tex3D(inPosition, inNormalTPM, emissiveTex).r * 0.1;
    gbuffer.occlusion = 1.0;
  }
  writeGBuffer(gbuffer, outAlbedo, outNormal, outParameter0);
}
