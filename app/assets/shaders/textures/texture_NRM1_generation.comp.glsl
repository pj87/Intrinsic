#version 450

layout(binding = 0, rgba8) uniform image2D _SourceTex;
layout(binding = 1, rgba8) uniform image2D _TextureTex;
layout(binding = 2) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

#define iResolution vec2(2048.0, 2048.0)

// Based on sobel operator

vec3 getNormal(in ivec2 uv)
{
	ivec2 texelStep = ivec2(1);

    float tl, l, bl, t, b, tr, r, br;
	
	tl = imageLoad(_SourceTex, uv + ivec2(-texelStep.x, -texelStep.y)).r;
	l = imageLoad(_SourceTex, uv + ivec2(-texelStep.x, 0)).r;
	bl = imageLoad(_SourceTex, uv + ivec2(-texelStep.x, texelStep.y)).r;
	t = imageLoad(_SourceTex, uv + ivec2(0, -texelStep.y)).r;
	b = imageLoad(_SourceTex, uv + ivec2(0, texelStep.y)).r;
	tr = imageLoad(_SourceTex, uv + ivec2(texelStep.x, -texelStep.y)).r;
	r = imageLoad(_SourceTex, uv + ivec2(texelStep.x, 0)).r;
	br = imageLoad(_SourceTex, uv + ivec2(texelStep.x, texelStep.y)).r;
	
	float dX = tr + 2.0 * r + br - tl - 2.0 * l - bl;
	float dY = bl + 2.0 * b + br - tl - 2.0 * t - tr;
	
	float bumpness = 0.03125;
	if (bumpness == 0.0) {
		bumpness = 0.0009765625;
	}
	vec3 normal = vec3(-dX * 255.0, dY * 255.0, 1.0 / bumpness);
	normal = normalize(normal);
    
    return normal;
}

layout(local_size_x = 1u, local_size_y = 1u, local_size_z = 1u) in;
void main()
{
    ivec3 id = ivec3(gl_GlobalInvocationID);
    
    vec3 normal = getNormal(id.xy);
    vec4 fragColor = vec4(normal.xy * 0.5 + 0.5, normal.z, 1);
	
	imageStore(_TextureTex, id.xy, fragColor);
}
