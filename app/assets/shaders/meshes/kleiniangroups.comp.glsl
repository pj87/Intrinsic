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

#define iTime _Frequency

// https://www.shadertoy.com/view/MtjXDh

const float PI = 3.14159265;
const float angle = 60.0;
const float fov = angle * 0.5 * PI / 180.0;
const vec3  cPos = vec3(0.0, 0.0, 500.0);
const vec3 lightDir = vec3(-0.577, 0.577, 0.577);

const vec3 spherePos1 = vec3(300, 300, 0);
const vec3 spherePos2 = vec3(300, -300, 0);
const vec3 spherePos3 = vec3(-300, 300, 0);
const vec3 spherePos4 = vec3(-300, -300, 0);
const vec3 spherePos5 = vec3(0, 0, 424.26);
const vec3 spherePos6 = vec3(0, 0, -424.26);
const float sphereR = 300.;

vec3 rotate(vec3 p, float angle, vec3 axis){
  vec3 a = normalize(axis);
  float s = sin(angle);
  float c = cos(angle);
  float r = 1.0 - c;
  mat3 m = mat3(
      a.x * a.x * r + c,
      a.y * a.x * r + a.z * s,
      a.z * a.x * r - a.y * s,
      a.x * a.y * r - a.z * s,
      a.y * a.y * r + c,
      a.z * a.y * r + a.x * s,
      a.x * a.z * r + a.y * s,
      a.y * a.z * r - a.x * s,
      a.z * a.z * r + c
  );
  return m * p;
}

vec3 sphereInverse(vec3 pos, vec3 circlePos, float circleR){
  return ((pos - circlePos) * circleR * circleR)/(distance(pos, circlePos) * distance(pos, circlePos) ) + circlePos;
}

const int ITERATIONS = 10;
float loopNum = 0.;
const vec3 ROTATION = vec3(1.0, 0.5, 0.5);
const float r2 = sphereR * sphereR;
float map(vec3 pos){
  pos = rotate(pos, radians(iTime * 10.0), ROTATION);
  float dr = 1.;
  bool cont = false;
  for(int i = 0 ; i < ITERATIONS ; i++){
    cont = false;
    if(distance(pos, spherePos1) < sphereR){
      vec3 diff = (pos - spherePos1);
      dr *= r2 / dot(diff, diff);
      pos = sphereInverse(pos, spherePos1, sphereR);
      cont = true;
      loopNum++;
    }else if(distance(pos, spherePos2) < sphereR){
        vec3 diff = (pos- spherePos2);
         dr *= r2 / dot(diff, diff);
      pos = sphereInverse(pos, spherePos2, sphereR);
      cont = true;
      loopNum++;
    }else if(distance(pos, spherePos3) < sphereR){
        vec3 diff = (pos- spherePos3);
         dr *= r2 / dot(diff, diff);
      pos = sphereInverse(pos, spherePos3, sphereR);
      cont = true;
      loopNum++;
    }else if(distance(pos, spherePos4) < sphereR){
        vec3 diff = (pos- spherePos4);
         dr *= r2 / dot(diff, diff);
      pos = sphereInverse(pos, spherePos4, sphereR);
      cont = true;
      loopNum++;
    }else if(distance(pos, spherePos5) < sphereR){
        vec3 diff = (pos- spherePos5);
         dr *= r2 / dot(diff, diff);
      pos = sphereInverse(pos, spherePos5, sphereR);
      cont = true;
      loopNum++;
    }else if(distance(pos, spherePos6) < sphereR){
        vec3 diff = (pos- spherePos6);
         dr *= r2 / dot(diff, diff);
      pos = sphereInverse(pos, spherePos6, sphereR);
      cont = true;
      loopNum++;
    }
    if(cont == false) break;
  }
//return (length(pos) - 300.) / abs(dr) * 0.08;
    return (length(pos) - 125.) / abs(dr) * 0.08;
}

float mapScaled(vec3 p, vec4 c)
{
	return map(p/0.1f).x * 0.1f;
}

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
void main()
{
    uvec3 id = gl_GlobalInvocationID;
	vec3 uv = vec3(id);

	//uv *= 1.0;

	//uncomment this for fractal noise
	//float n = fBm(uv, 4);

	//uncomment this for turbulent noise
	//float n = turbulence(uv, 4);

	//uncomment this for ridged multi fractal
	//float n = ridgedmf(uv, 4, 1.0);

	vec4 c = 0.45*cos( vec4(0.5,3.9,1.4,1.1) + _Frequency*vec4(1.2,1.7,1.3,2.5) ) - vec4(0.3,0.0,0.0,0.0);
	//vec4 c = vec4(0.4);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(20.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);
	_NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = vec4(0.);
}
