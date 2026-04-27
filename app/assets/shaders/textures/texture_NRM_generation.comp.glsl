#version 450

layout(binding = 0, rgba8) uniform image2D _TextureTex;
layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

vec2 hash( vec2 x )  // replace this by something better
{
    const vec2 k = vec2( 0.3183099, 0.3678794 );
    x = x*k + k.yx;
    return -1.0 + 2.0*fract( 16.0 * k*fract( x.x*x.y*(x.x+x.y)) );
}

float noise( in vec2 p )
{
    vec2 i = floor( p );
    vec2 f = fract( p );
	
	vec2 u = f*f*(3.0-2.0*f);

    return mix( mix( dot( hash( i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ), 
                     dot( hash( i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
                mix( dot( hash( i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ), 
                     dot( hash( i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
}

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
	vec3 uv = vec3(id) / 1024.0;

	/*
	float f = noise( 64.0*uv.xy );

    f = 0.5 + 0.5*f;
	
	
	if (id.x < 512)
		imageStore(_TextureTex, id.xy, vec4(f, f, 1.0, 1.0));
	else
	{
		f = 0.5 + 0.5*f;
		imageStore(_TextureTex, id.xy, vec4(f, f, 1.0, 1.0));
	}
	*/
	/*
	float pct = distance(uv.xy ,vec2(0.5)) * 4.0;
	vec3 color = vec3(pct);
	
	imageStore(_TextureTex, id.xy, vec4(color.x, color.y, 1.0, 1.0));
	*/
	
	/*
	float qx = clamp(sin(uv.x * 100.0), 0.5, 1.0);
	float qy = clamp(sin(uv.y * 100.0), 0.5, 1.0);
	
	//trzeba policzyć pochodną sinusa i podjąć decyzję jaki ma być kolor
	const float dx = sin((uv.x + 0.01) * 100.0) - sin(uv.x * 100.0);
	const float dy = sin((uv.y + 0.01) * 100.0) - sin(uv.y * 100.0);
	
	if (dx > 0.01)
		imageStore(_TextureTex, id.xy, vec4(qx, qy, 1.0, 1.0));
	else
		imageStore(_TextureTex, id.xy, vec4(1.0 - qx, qy, 1.0, 1.0));
	*/
	
	float color = 0.5 + 0.5 * abs(sin(_Frequency));
	
	if (id.x % 99 == 0)
	{
		imageStore(_TextureTex, id.xy, vec4(0.9, color, 1.0, 1.0));
	}
	else if (id.x % 100 == 0)
	{
		imageStore(_TextureTex, id.xy, vec4(0.8, color, 1.0, 1.0));
	}
	else if (id.x % 101 == 0)
	{
		imageStore(_TextureTex, id.xy, vec4(0.1, color, 1.0, 1.0));
	}
	else
	{
		imageStore(_TextureTex, id.xy, vec4(0.5, color, 1.0, 1.0));
	}
}
