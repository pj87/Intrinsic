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

layout(binding = 5) buffer _VoxelNormalBuffer
{
	vec4 _NormalResult[];
};

#define MAX_MARCHING_STEPS 256
#define MAX_DIST 6. // far
#define EPSILON 0.001
#define PI 3.1415926535

float random(vec2 p)
{
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}


vec3 noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);

  vec2 df = 20.0*f*f*(f*(f-2.0)+1.0);
  f = f*f*f*(f*(f*6.-15.)+10.);

  float a = random(i + vec2(0.5));
  float b = random(i + vec2(1.5, 0.5));
  float c = random(i + vec2(.5, 1.5));
  float d = random(i + vec2(1.5, 1.5));

  float k = a - b - c + d;
  float n = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);

  return vec3(n, vec2(b - a + k * f.y, c - a + k * f.x) * df);
}

mat2 terrainProps = mat2(0.8,-0.4, 0.5,0.8);
float fbmM(vec2 p) {
  vec2 df = vec2(0.0);
  float f = 0.0;
  float w = 0.5;

  for (int i = 0; i < 3; i++) {
    vec3 n = noise(p);
    df += n.yz;
    f += abs(w * n.x / (1.0 + dot(df, df)));
    w *= 0.5;
    p = 2. * terrainProps * p;
  }
  return f;
}

float map(vec3 p) {
    float scene = p.y;
    
    float h = fbmM(p.xz) * 1.4;	
    scene -= h;

  	return scene;
}

float mapScaled(vec3 p, vec4 c)
{
	return map(p / 20.0) * 20.0;
}

vec4 getNormal( in vec3 pos, vec4 c)
{
    vec3  eps = vec3(.001,0.0,0.0);
    vec3 nor;
    nor.x = mapScaled(pos+eps.xyy, c) - mapScaled(pos-eps.xyy, c);
    nor.y = mapScaled(pos+eps.yxy, c) - mapScaled(pos-eps.yxy, c);
    nor.z = mapScaled(pos+eps.yyx, c) - mapScaled(pos-eps.yyx, c);
    return vec4(normalize(nor), 0.0);
}

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
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
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(25.0f, 10.0f, 0.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f, 1.0f, 100.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(_Lacunarity, 32.0, _Gain), c);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(_Lacunarity, 32.0, _Gain), c);
	_NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = -getNormal(uv - vec3(32.0f, 32.0, 32.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);

}
