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
layout(binding = 3) uniform sampler2D albedoTex0;
layout(binding = 4) uniform sampler2D normalTex0;
layout(binding = 5) uniform sampler2D pbrTex0;
layout(binding = 6) uniform sampler2D albedoTex1;
layout(binding = 7) uniform sampler2D normalTex1;
layout(binding = 8) uniform sampler2D pbrTex1;
layout(binding = 9) uniform sampler2D albedoTex2;
layout(binding = 10) uniform sampler2D normalTex2;
layout(binding = 11) uniform sampler2D pbrTex2;
layout(binding = 12) uniform sampler2D blendMaskTex;
layout(binding = 13) uniform sampler2D noiseTex;

// Bindings
//BINDINGS_GBUFFER;
//layout(binding = 6) uniform sampler2D emissiveTex;

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
           //texture( s, pos.xz).xyz*abs(nor.y)+
           texture( s, pos.yx).xyz*abs(nor.z);
}

vec3 tex3DNormal(vec3 pos, vec3 nor, sampler2D s) {

    return textureNormal( s, pos.yz).xyz*abs(nor.x)+
           //textureNormal( s, pos.xz).xyz*abs(nor.y)+
           textureNormal( s, pos.xy).xyz*abs(nor.z);
}

vec3 tex3DBricks(vec3 pos, vec3 nor, sampler2D s) {
	/*
	pos += vec3(3.5, 0.0, 3.5);
	pos *= 0.075;
	//pos = normalize(pos);
	
    return texture( s, pos.yz).xyz*abs(nor.x)+
           //texture( s, pos.xz).xyz*abs(nor.y)+
           texture( s, pos.xy).xyz*abs(nor.z);
	*/
	
	vec2 posX = pos.zy + vec2(3.5, 0.0);
	vec2 posZ = pos.xy + vec2(3.5, 0.0);
	vec2 posY = vec2(posX.y, posZ.x);
	
	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;
	
    return texture( s, posX.xy).xyz*abs(nor.x)+
           texture( s, posY.xy).xyz*abs(nor.y)+
           texture( s, posZ.xy).xyz*abs(nor.z);
	
}

vec3 tex3DBricksNormal(vec3 pos, vec3 nor, sampler2D s) {

	vec2 posX = pos.zy + vec2(3.5, 0.0);
	vec2 posZ = pos.xy + vec2(3.5, 0.0);
	vec2 posY = vec2(posX.y, posZ.x);
	
	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;
	
    return textureNormal( s, posX.xy).xyz*abs(nor.x)+
           textureNormal( s, posY.xy).xyz*abs(nor.y)+
           textureNormal( s, posZ.xy).xyz*abs(nor.z);
}

vec3 tex3DWood(vec3 pos, vec3 nor, sampler2D s) {
	
	vec2 posX = pos.yz + vec2(7.0, 3.5);
	vec2 posZ = pos.xy + vec2(-0.5, 0.0);
	vec2 posY = vec2(posX.y + 7.0, posZ.x - 7.0);

	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;

    return texture( s, posX.xy).xyz*abs(nor.x)+
           texture( s, posY.xy).xyz*abs(nor.y)+
           texture( s, posZ.xy).xyz*abs(nor.z);
}

vec3 tex3DWoodNormal(vec3 pos, vec3 nor, sampler2D s) {

	vec2 posX = pos.yz + vec2(7.0, 3.5);
	vec2 posZ = pos.xy + vec2(-0.5, 0.0);
	vec2 posY = vec2(posX.y + 7.0, posZ.x - 7.0);

	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;

    return textureNormal( s, posX.xy).xyz*abs(nor.x)+
           textureNormal( s, posY.xy).xyz*abs(nor.y)+
           textureNormal( s, posZ.xy).xyz*abs(nor.z);
}

vec3 tex3DWall(vec3 pos, vec3 nor, sampler2D s) {

	/*
	pos += vec3(-3.5, 7.0, -3.5);
	pos *= 0.075;

    return texture( s, pos.yz).xyz*abs(nor.x)+
           //texture( s, pos.xz).xyz*abs(nor.y)+
           texture( s, pos.xy).xyz*abs(nor.z);
	*/
	
	vec2 posX = pos.yz + vec2(7.0, -3.5);
	vec2 posZ = pos.xy + vec2(-3.5, 7.0);
	vec2 posY = vec2(posX.y, posZ.x);
	
	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;

    return texture( s, posX.xy).xyz*abs(nor.x)+
           texture( s, posY.xy).xyz*abs(nor.y)+
           texture( s, posZ.xy).xyz*abs(nor.z);
	
}

vec3 tex3DWallNormal(vec3 pos, vec3 nor, sampler2D s) {

	vec2 posX = pos.yz + vec2(7.0, -3.5);
	vec2 posZ = pos.xy + vec2(-3.5, 7.0);
	vec2 posY = vec2(posX.y, posZ.x);
	
	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;

    return textureNormal( s, posX.xy).xyz*abs(nor.x)+
           textureNormal( s, posY.xy).xyz*abs(nor.y)+
           textureNormal( s, posZ.xy).xyz*abs(nor.z);
}

vec3 tex3DFloor(vec3 pos, vec3 nor, sampler2D s) {
	
	vec2 posX = pos.yz + vec2(0.325, -3.5);
	vec2 posZ = pos.xy + vec2(-7.45, 7.0);
	vec2 posY = vec2(posZ.x, posX.y);

	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;

    return texture( s, posX.xy).xyz*abs(nor.x)+
           //texture( s, posY.xy).xyz*abs(nor.y)+
           texture( s, posZ.xy).xyz*abs(nor.z);
	
}

vec3 tex3DFloorNormal(vec3 pos, vec3 nor, sampler2D s) {

	vec2 posX = pos.yz + vec2(0.325, -3.5);
	vec2 posZ = pos.xy + vec2(-7.45, 7.0);
	vec2 posY = vec2(posZ.x, posX.y);

	posX *= 0.075;
	posY *= 0.075;
	posZ *= 0.075;

    return textureNormal( s, posX.xy).xyz*abs(nor.x)+
           textureNormal( s, posY.xy).xyz*abs(nor.y)+
           textureNormal( s, posZ.xy).xyz*abs(nor.z);
}

vec3 tex3DBlendMask(vec3 pos, vec3 nor, sampler2D s) {
    return texture( s, (pos.yz - 1.6) * 0.25).xyz*abs(nor.x)+
		   texture( s, (pos.xz - 1.6) * 0.25).xyz*abs(nor.y)+
		   texture( s, (pos.xy - 1.6) * 0.25).xyz*abs(nor.z);
}

vec3 blend(vec3 grass0, vec3 stone0, vec3 stone1, vec3 blendMask, float noise)
{
  return mix(grass0, mix(stone0, stone1, 1.0 - noise),
             clamp(blendMask.b * 3.0, 0.0, 1.0));
}

vec3 blend(vec3 stone0, vec3 stone1, vec3 blendMask, float noise)
{
  return mix(stone0, stone1,
             clamp(blendMask.b * 3.0, 0.0, 1.0));
}

vec3 stain(vec3 stone0, vec3 stone1, vec3 blendMask, float noise)
{
	if (blendMask.b * noise > 0.15)
		return stone0;
	
	return stone1;// * noise;
}

bool isWindow(vec3 pos)
{
	// windows
	if (inPosition.y > 0.25 && inPosition.y < 0.65 &&
		(inPosition.x > -0.05 && inPosition.x < 0.35 || 
		inPosition.x > -1.05 && inPosition.x < -0.65 || 
		inPosition.z > -0.85 && inPosition.z < -0.45 || 
		inPosition.z > -0.25 && inPosition.z < 0.15 || 
		inPosition.z > 1.95 && inPosition.z < 2.35))
		return true;
		
	return false;
}

bool isWindowGlass(vec3 pos)
{
	// windows
	if (inPosition.y > 0.3 && inPosition.y < 0.6 &&
		(inPosition.x > 0.0 && inPosition.x < 0.3 || 
		inPosition.x > -1.0 && inPosition.x < -0.7 || 
		inPosition.z > -0.8 && inPosition.z < -0.5 || 
		inPosition.z > -0.2 && inPosition.z < 0.1 || 
		inPosition.z > 2.0 && inPosition.z < 2.3))
		return true;
		
	return false;
}

/*
vec4 tex3d(vec3 pos, vec3 normal)
{
	pos /= 4.0;

	// loook up brick texture, blended across xyz axis based on normal.
	vec4 texX = texture(albedoTex0, pos.yz);
	vec4 texY = texture(albedoTex0, pos.xz);
	vec4 texZ = texture(albedoTex0, pos.xy);
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
*/
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

  vec3 blendMask = tex3DBlendMask(inPosition, inNormalTPM, blendMaskTex).rgb;
  float noise = clamp(tex3D(inPosition * 10.0, inNormalTPM, noiseTex).r, 0.0, 1.0);
  float noise1 = clamp(tex3D(inPosition * 1.0, inNormalTPM, noiseTex).r, 0.0, 1.0);
  
  vec3 albedoDef = tex3D(inPosition, inNormalTPM, albedoTex0);
  
  vec3 albedo0 = tex3DBricks(inPosition, inNormalTPM, albedoTex0);
  vec3 albedo1 = tex3DWall(inPosition, inNormalTPM, albedoTex0);
  vec3 albedo2 = tex3DWood(inPosition, inNormalTPM, albedoTex0) * 0.25;
  vec3 albedo3 = tex3DFloor(inPosition, inNormalTPM, albedoTex0);
  vec3 albedo4 = tex3D(inPosition, inNormalTPM, albedoTex1);
  vec3 albedo5 = tex3D(inPosition, inNormalTPM, albedoTex2) * 0.1;
  
  vec3 normalDef = tex3DNormal(inPosition, inNormalTPM, normalTex0);
  
  vec3 normal0 = tex3DBricksNormal(inPosition, inNormalTPM, normalTex0);
  vec3 normal1 = tex3DWallNormal(inPosition, inNormalTPM, normalTex0);
  vec3 normal2 = tex3DWoodNormal(inPosition, inNormalTPM, normalTex0);
  vec3 normal3 = tex3DFloorNormal(inPosition, inNormalTPM, normalTex0);
  vec3 normal4 = tex3D(inPosition, inNormalTPM, normalTex1);
  vec3 normal5 = tex3D(inPosition, inNormalTPM, normalTex2) * 0.1;
  
  vec3 pbrDef = tex3DNormal(inPosition, inNormalTPM, pbrTex0);
  
  vec3 pbr0 = tex3DBricks(inPosition, inNormalTPM, pbrTex0);
  vec3 pbr1 = tex3DWall(inPosition, inNormalTPM, pbrTex0);
  vec3 pbr2 = tex3DWood(inPosition, inNormalTPM, pbrTex0);
  vec3 pbr3 = tex3DFloor(inPosition, inNormalTPM, pbrTex0);
  vec3 pbr4 = tex3D(inPosition, inNormalTPM, pbrTex1);
  vec3 pbr5 = tex3D(inPosition, inNormalTPM, pbrTex2) * 0.1;
  
  vec3 albedo = stain(albedo0.rgb * 1.0, albedo1.rgb * 1.0, blendMask, noise1);
  vec3 pbr = stain(pbr0.rgb * 1.0, pbr1.rgb * 1.0, blendMask, noise1);
  vec3 normal = normal0.rgb;
  
  float emissive = 0.1;
  
  //vec3 normal = blend(normal0.rgb * 1.0, normal1.rgb * 1.0, blendMask, noise);
  //vec3 pbr = blend(pbr0.rgb * 1.0, pbr1.rgb * 1.0, blendMask, noise);

  GBuffer gbuffer;
  {   
   //door
	if (inPosition.y < 0.7 && inPosition.z > 0.8 && inPosition.z < 1.3 && inPosition.x < -2.0 || isWindow(inPosition))
	{
		albedo = albedo2.rgb + albedo5.rgb;
		normal = normal2 + normal5;
		pbr = pbr2 + pbr5;
	}
	/*
	else if (inPosition.y < 0.8 && inPosition.x < -2.1)
	{
		// collumns
		//albedo = vec3(1.0, 1.0, 0.0);
		//normal = vec3(0.0);
		//pbr = vec3(0.0);
		
		//albedo = albedo2.rgb;
		//normal = normal2;
		//pbr = pbr2;
	}
	*/
	// roof
	else if (inPosition.y < 0.85)
	{
		//gbuffer.albedo = vec4(inColor, 1.0) + vec4(tex3D(inPosition, inNormalTPM, albedoTex0), 1.0) * uboPerInstance.colorTint;
		//gbuffer.albedo = vec4(albedo.rgb, 1.0);
		//gbuffer.normal = normal;
		//gbuffer.pbr = pbr;
	}
	else
	{
		albedo = albedo4;
		normal = normal4;
		pbr = pbr4;
	}
	
	if(isWindowGlass(inPosition))
	{
		
		albedo = albedo1.rgb;
		normal = normal1.rgb;
		pbr = pbr1.rgb;
		emissive = 1.0;
		
	}
	
	gbuffer.albedo = vec4(albedo, 1.0);
	gbuffer.normal = normal;
	const vec2 pbr = pbr.rg;
    gbuffer.metalMask = pbr.r + uboPerMaterial.pbrBias.r;
    gbuffer.specular = uboPerMaterial.pbrBias.g;
    gbuffer.roughness = adjustRoughness(pbr.g + uboPerMaterial.pbrBias.b,
                                        uboPerMaterial.data1.x);
    gbuffer.materialBufferIdx = uboPerMaterial.data0.x;
	gbuffer.emissive = emissive;
    gbuffer.occlusion = 1.0;
  }
  writeGBuffer(gbuffer, outAlbedo, outNormal, outParameter0);
}
