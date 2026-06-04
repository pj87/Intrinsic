#version 450

layout(binding = 0, rgba8) uniform image2D _TextureTex;
layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

float circle(in vec2 _st, in float _radius){
    vec2 dist = _st-vec2(0.5);
	return 1.-smoothstep(_radius-(_radius*0.01),
                         _radius+(_radius*0.01),
                         dot(dist,dist)*4.0);
}

layout(local_size_x = 1u, local_size_y = 1u, local_size_z = 1u) in;
void main()
{
    ivec3 id = ivec3(gl_GlobalInvocationID);	
	vec3 uv = vec3(id) / 2048.0;
	
	float pct = distance(uv.xy ,vec2(0.5)) * 2.0 + abs(sin(_Frequency));
	vec3 color = vec3(pct);
	
	imageStore(_TextureTex, id.xy, vec4(color.x, color.y, 1.0, 1.0));
	
}
