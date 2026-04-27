#version 450

layout(binding = 0) buffer _SizeBuffer 
{
	int _Width;
	int _Height;
};

layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

layout(binding = 2) uniform sampler2D _Gradient3D;

layout(binding = 3) uniform sampler2D _PermTable2D;

layout(binding = 4) buffer _VoxelBuffer 
{
	float _Result[];
};

const mat3 m = mat3( 0.00,  0.80,  0.60,
                    -0.80,  0.36, -0.48,
                    -0.60, -0.48,  0.64 );

float noise(vec3 p) //Thx to Las^Mercury
{
	vec3 i = floor(p);
	vec4 a = dot(i, vec3(1., 57., 21.)) + vec4(0., 57., 21., 78.);
	vec3 f = cos((p-i)*acos(-1.))*(-.5)+.5;
	a = mix(sin(cos(a)*a),sin(cos(1.+a)*(1.+a)), f.x);
	a.xy = mix(a.xz, a.yw, f.y);
	return mix(a.x, a.y, f.z)*.5+.5;
}

float displacement( vec3 p ) //Thx to Inigo Quilez
{	
    p *= vec3(1.,.8,1.);
    float f;
    f  = 0.5000*noise( p ); p = m*p*2.01;
    f += 0.2500*noise( p); p = m*p*3.5;
    f += 0.0425*noise( p ); /*p = m*p*2.01;
    f += 0.0625*noise( p ); */
	
    return f;
}

//Distance field maps
float rock( in vec3 p)
{
	float d = length(abs(p.xy)+vec2(-220.,50.))-200.; // 2 cylinders 
	d = max(d, -p.z-250.);
    
	d = d*.2  + noise(p*.04-.75)*7. + displacement(p*.25)*2.;
    
	return d;
}
float ground( in vec3 p )
{
	return p.y-clamp(p.z*.08-5.5,-20., 0.);
}
float map( in vec3 p )
{
	return rock(p);
	//return length(p) - 10.0f;
}

float mapScaled(vec3 p, vec4 c)
{
	//return map(p / 1.0) * 1.0;
	return map(p / 0.1) * 0.1;
}

layout(local_size_x = 4u, local_size_y = 8u, local_size_z = 16u) in;
void main()
{
    uvec3 id = gl_GlobalInvocationID;
	vec3 uv = vec3(id);

	//uv *= 0.0001;

	//uncomment this for fractal noise
	//float n = fBm(uv, 4);

	//uncomment this for turbulent noise
	//float n = turbulence(uv, 4);

	//uncomment this for ridged multi fractal
	//float n = ridgedmf(uv, 4, 1.0);

	vec4 c = 0.45*cos( vec4(0.5,3.9,1.4,1.1) + _Frequency*vec4(1.2,1.7,1.3,2.5) ) - vec4(0.3,0.0,0.0,0.0);
	//vec4 c = vec4(0.4);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(25.0f, 10.0f, 0.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);

}
