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

#define PHI (sqrt(5.)*0.5 + 0.5)
const float PI = 3.14159265359;
float snoise(vec3 v);

float sdrBox(vec3 p, vec3 b, float r) {
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0)) - r;
}

float sdCylinder(vec3 p, vec2 h) {
    return max( length(p.xz)-h.x, abs(p.y)-h.y );
}

float ruins(vec3 p) {
    vec3 q=p;
    
    //bumps
    //float o= texture(iChannel0, p.xy*0.1 ).x*texture(iChannel0, p.yz*0.1 ).x*0.005;
	float o= 0.0f;

    //pillars bottom
    p.x=clamp(p.x,-8.0,8.0);                                     //limit x
    if ((p.z<2.0 && p.z>-2.0) && (p.x<0.0 && p.x>-4.0)) p.x=0.0; //chop hole in middle 

    p.x=mod(p.x,2.0)-0.5*2.0;                                    //rep x

    p.z=clamp(p.z,-4.0,4.0);                                     //limit z
    if (q.x>2.0 || q.x<-6.0) p.z=clamp(p.z,-2.0,2.0);
    p.z=mod(p.z,2.0)-0.5*2.0;                                    //rep z

    float r= 0.5-clamp( sin(p.y*1.2+1.58)*0.5, 0.0,0.05);
    float d=sdCylinder(p, vec2(r,1.5)) -o;

    //pillars top
    p.y-=2.8;
    r= 0.4-clamp( sin(p.y*1.8+0.8)*0.5, 0.0,0.05);
    
    float h=1.5;
    if (q.x>2.0) { p.y-=0.5; h=2.0; r=0.4-clamp( sin(p.y*1.15+1.1)*0.5, 0.0,0.05); } //pull first 3x2 pillars up
    float t=sdCylinder(p, vec2(r,h)) -o;    

    //mid platform
    q.y-=1.8;
    float c=sdrBox(q, vec3(7.45,0.25,1.45), 0.05) -o;
    q.x+=2.0;
    c=min(c, sdrBox(q, vec3(3.45,0.25,3.45), 0.05) -o);

    //bottom platform
    q.y+=3.55;
    //c=min(c, sdrBox(q, vec3(3.65,0.2,3.65), 0.05) -o);
    q.x-=2.0;
    //c=min(c, sdrBox(q, vec3(7.65,0.2,1.65), 0.05) -o);
    
    //ground platform
    q.x+=2.0;
    q.y+=0.8;
    //c=min(c, sdrBox(q, vec3(4.65,0.6,4.65), 0.05) -o);
    q.x-=2.0;
    //c=min(c, sdrBox(q, vec3(8.65,0.6,2.65), 0.05) -o);
    
    //top part
    q.y-=8.0;
    q.x-=5.0;
    c=min(c, sdrBox(q, vec3(2.45,0.15,1.45), 0.05) -o);
    c=max(c, -sdrBox(q, vec3(1.45,0.25,0.45), 0.05) -o);    //left hole
    
    //top right part
    q.y+=1.0;
    q.x+=6.0;
    c=min(c, sdrBox(q, vec3(4.50,0.15,1.65), 0.05) -o);
    q.x+=1.0;
    q.z-=0.85;
    c=min(c, sdrBox(q, vec3(3.45,0.15,2.5), 0.05) -o);
    q.z+=0.85;
c=max(c, -sdrBox(q, vec3(2.25,4.5,2.25), 0.05) -o);    
    
    d=min(min(c,d),t);
	
    return d;
}

float mapScaled(vec3 p, vec4 c)
{
	//return map2(p/0.0025f, c) * 0.0025f;
	//return map3(p/0.0025f) * 0.0025f;
	//return sponge1(p / 0.0025) * 0.0025;
	//return sponge2(p / 0.0025) * 0.0025;
	
	//return ruins(p/0.000025f) * 0.000025f;
	return ruins(p/4.0f) * 4.0f;
}

layout(local_size_x = 8u, local_size_y = 8u, local_size_z = 8u) in;
void main()
{
    uvec3 id = gl_GlobalInvocationID;
	vec3 uv = vec3(id);

	//uv *= 0.1;

	//uncomment this for fractal noise
	//float n = fBm(uv, 4);

	//uncomment this for turbulent noise
	//float n = turbulence(uv, 4);

	//uncomment this for ridged multi fractal
	//float n = ridgedmf(uv, 4, 1.0);

	vec4 c = 0.45*cos( vec4(0.5,3.9,1.4,1.1) + _Frequency*vec4(1.2,1.7,1.3,2.5) ) - vec4(0.3,0.0,0.0,0.0);
	//vec4 c = vec4(0.4);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(26.0f, 21.0f, 19.9f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(1.5), vec3(1.5, 1.5, 1.5));

	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);
    _NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = vec4(0.0);
}
