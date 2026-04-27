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

float GetLuminance(in ivec2 uv){
	vec3 col = imageLoad(_SourceTex, uv).rgb;

	return dot(col,vec3(0.2126729,0.7151522,0.0721750));
}

layout(local_size_x = 1u, local_size_y = 1u, local_size_z = 1u) in;
void main()
{
    ivec3 id = ivec3(gl_GlobalInvocationID);
    
	float luminance = GetLuminance(id.xy);
	
	//vec4 fragColor = vec4(luminance, smoothstep(1.,0.,luminance*1.6), 0.0, 1.0);
	//vec4 fragColor = vec4(step(luminance, 0.5), smoothstep(1.,0.,luminance*1.6), 0.0, 1.0);
	vec4 fragColor = vec4(step(luminance, 0.5), luminance, 0.0, 1.0);
	
	// Maybe this version is better????
	//vec4 fragColor = vec4(smoothstep(1.,0.,luminance*1.6), luminance, 0.0, 1.0);
	
	imageStore(_TextureTex, id.xy, fragColor);
}
