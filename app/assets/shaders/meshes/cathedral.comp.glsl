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

const float PI = 3.14159265359;

// k should be negative. -4.0 works nicely.
float smin(float a, float b, float k)
{
	// I'm guessing that base 2 operations are the fastest.
	return log2(exp2(k*a)+exp2(k*b))/k;
}

vec3 RotateY(vec3 v, float rad)
{
	float cos = cos(rad);
	float sin = sin(rad);
	//if (RIGHT_HANDED_COORD)
	return vec3(cos * v.x - sin * v.z, v.y, sin * v.x + cos * v.z);
	//else return new float3(cos * x + sin * z, y, -sin * x + cos * z);
}

float dSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

float dBox(vec3 pos, vec3 b)
{
	return length(max(abs(pos)-(b),0.0));
}

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
	vec3 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h ) - r;
}

float dBoxSigned(vec3 p)
{
	float b = 1.0;
	vec3 b2 = vec3(6.0, 2.0, 2.0);
	vec3 center = vec3(0, -2.0, 0.0);
	vec3 d = abs(p - center) - b2;//*abs(cos(p.y + 0.5));
	return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float dBoxSlant(vec3 p, vec3 b)
{
	float size = b.x;
	float f = length(max(abs(p)-(b),0.0));
	//float f = length(max(abs(p.x)+abs(p.z)-(b),0.0));
	//f = max(f, p.y*0.5 + abs(p.x) + abs(p.z) - size * 0.995);
	return f;
}

float dFloor(vec3 p)
{
	return p.y + 1.0;
}

float sdColumn( vec3 p, vec3 c )
{
	float cyl = length(p.xz-c.xy)-c.z;// + abs(p.y);
	cyl -= cos(p.y*2.0)*0.045;
	float a = atan(p.x - c.x, p.z - c.y);
	a /= 2.0*PI;
	float subs = 48.0;
	a *= subs;
	//cyl *= pow(sin(a), 0.5) * 0.925 + 1.0;
	cyl += abs(sin(a)) * 0.015;

	cyl = max(cyl, p.y - 2.4);
	cyl = min(cyl, dBox(p + vec3(0.0, 1.0, 0.0), vec3(0.3, 0.2, 0.3)));
	cyl = smin(cyl, dBoxSlant(RotateY(p, PI/4.0) + vec3(0.0, -2.3, 0.0), vec3(0.3, 0.15, 0.3)), -24.0);
	//cyl = min(cyl, dBox(RotateY(p, PI/4.0) + vec3(0.0, -2.3, 0.0), vec3(0.3, 0.15, 0.3)));
	return cyl;
}

float length16(vec2 v)
{
	return pow(pow(abs(v.x),16.0) + pow(abs(v.y), 16.0), 1.0/16.0);
	//return pow((pow(v.x,16.0) + pow(v.y, 16.0)), (1.0/16.0));
}

float globalRadial;

float sdTorusBricks( vec3 p, vec2 t, vec3 center, float subs )
{
	p -= center;
	float a = globalRadial;// + PI/6.0;// atan(p.x, p.z);
	a = pow(abs(sin(a*subs)), 0.25);
	//a = mod(a,PI*2.0) - 0.5;
	//a = a *0.025 + 0.975;
	a = a *0.2 + 0.8;
	vec2 q = vec2(length(p.xz)-t.x,p.y);
	return length16(q)-t.y*a;
}
float sdTorusArch( vec3 p, vec2 t, vec3 center, float subs )
{
	p -= center;
	float a = atan(p.y, p.z);
	a = pow(abs(sin(a*subs)), 0.25);
	//a = mod(a,PI*2.0) - 0.5;
	//a = a *0.025 + 0.975;
	a = a *0.25 + 0.75;
	p.y -= cos(p.y)*0.4;
	vec2 q = vec2(length(p.yz)-t.x,p.x);
	return length16(q)-t.y*a;
}

// This makes the stained glass windows in the dome.
float dTiles(vec3 p)
{
	float subs = 16.0;
	float final = length(p) - 2.2;
	float a = globalRadial;// atan(p.x, p.z);
	a /= 2.0*PI;
	a *= subs;
	a = abs((fract(a) - 0.5))*2.0;	// triangle wave from 0.0 to 1.0
	a -= 0.15;
	a *= 6.0;
	a = max(0.0, a);
	a = min(0.75, a);

	float b = atan(length(p.xz), p.y);
	b /= 2.0*PI;
	b *= subs;
	b = abs((fract(b) - 0.5))*2.0;	// triangle wave from 0.0 to 1.0
	b -= 0.15;
	b *= 6.0;
	b = max(0.0, b);
	b = min(0.75, b);
	
	a = a*b;

	a = a *0.2 + 0.8;
	b = b *0.2 + 0.8;
	
	final = final - a;
	final = max(final, 0.5-p.y);
	final = min(final, length(p.xz) - 0.5);	// oculus - cylinder in middle
	return final/1.414;
}

float cathedral2(vec3 p)
{
	globalRadial = atan(p.x, p.z);
	// set up repeating spaces for pillars and arches
	vec3 c = vec3(1.0, 1.0, 1.0)* 4.0;
	float c2 = 5.2;
	vec3 q = mod(p,c)-0.5*c;
	float q2 = mod(p.x,c2)-0.5*c2;
	vec3 p2 = vec3(q.x, p.y, q.z);
	vec3 p3 = vec3(q2, p.y, p.z);

	float final = -sdCapsule(p, vec3(0.0,-0.5,0.0), vec3(0.0,2.25,0.0), 3.0);
	// This if condition is for a culling speedup and a cool bevel effect on the ceiling tiles.
	final = max(final, -dTiles(p + vec3(0.0, -2.75, 0.0)));
	final = min(final, sdTorusBricks(p, vec2(2.75, 0.25), vec3(0.0, -0.795, 0.0), 12.0));
	final = max(final, -sdCapsule(p, vec3(-6.0,0.0,0.0), vec3(6.0,0.0,0.0), 2.0));
	final = max(final, -sdCapsule(p, vec3(0.0,0.0,-16.0), vec3(0.0,0.0,16.0), 2.0));
	final = max(final, -dBoxSigned(p));
	final = max(final, -sdCapsule(p, vec3(0.0,0.0,0.0), vec3(0.0,5.5,0.0), 0.5));//oculus
	final = max(final, p.y - 5.3);	// open the sky
	//final = max(final, sdCapsule(p, vec3(0.0,-0.5,0.0), vec3(0.0,0.5,0.0), 3.05));
	final = max(final, -dSphere(p2, 0.08));
	//final = min(final, sdColumn(p2, vec3(0.0, 0.0, 0.25)));
	//final = max(final, -sdBox(p - vec3(0.0,0.5,0.0), vec3(0.5, 1.0, 3.5)));

	//final = min(final, sdTorusBricks(p, vec2(2.75, 0.25), vec3(0.0, 2.7, 0.0), 8.0));
	//final = min(final, sdTorusBricks(p, vec2(0.75, 0.25), vec3(0.0, -1.0, 0.0), 3.0));
	//final = min(final, sdTorusArch(p3, vec2(2.125, 0.3), vec3(0.0, 0.1, 0.0), 12.0));
	//final = min(final, sdTorusArch(p, vec2(2.125, 0.3), vec3(2.6, -0.1, 0.0), 6.0));
	//final = min(final, sdTorusArch(p, vec2(2.125, 0.3), vec3(-2.6, -0.1, 0.0), 6.0));
	final = min(final, dFloor(p));

	return final;
}

float mapScaled(vec3 p, vec4 c)
{
	//return map2(p/0.0025f, c) * 0.0025f;
	//return map3(p/0.0025f) * 0.0025f;
	
	return cathedral2(p / 3.0) * 3.0;
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
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(10.0f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);

}
