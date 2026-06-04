// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// See http://www.iquilezles.org/www/articles/warp/warp.htm for details

#version 450

layout(binding = 0, RGBA8) uniform image2D _TextureTex;
layout(binding = 1) buffer _ParametersBuffer 
{
	float _Frequency;
	float _Lacunarity;
	float _Gain;
};

#define iTime 1.0
#define iResolution vec2(2048.0, 2048)

// https://www.shadertoy.com/view/WsSGWd

#define BLADES_SPACING 0.004
#define JITTER_MAX 0.004
// depends on size of grass blades in pixels
#define LOOKUP_DIST 5

#define HASHSCALE1 .1031
#define HASHSCALE3 vec3(.1031, .1030, .0973)

#define PI 3.14

float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

///  3 out, 2 in...
vec3 hash32(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yxz+19.19);
    return fract((p3.xxy+p3.yzz)*p3.zyx);
}

/// 2 out, 2 in...
vec2 hash22(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yzx+19.19);
    return fract((p3.xx+p3.yz)*p3.zy);

}

vec3 getGrassColor(float x) {
    vec3 a = vec3(0.2, 0.4, 0.3);
    vec3 b = vec3(0.3, 0.5, 0.2);
    vec3 c = vec3(0.2, 0.4, 0.2);
    vec3 d = vec3(0.66, 0.77, 0.33);
    vec3 col = a + b * cos(2. * PI * (c * x + d));
    return col;
}

float getGrassBlade(in vec2 position, in vec2 grassPos, out vec4 color) {
	// between {-1, -1, -1} and {1, 1, 1}
    vec3 grassVector3 = hash32(grassPos * 123512.41) * 2.0 - vec3(1);
    // keep grass z between 0 and 0.4
    grassVector3.z = grassVector3.z * 0.2 + 0.2;
    vec2 grassVector2 = normalize(grassVector3.xy);

    float grassLength = hash12(grassPos * 102348.7) * 0.01 + 0.012;

    // take coordinates in grass blade frame
    vec2 gv = position - grassPos;
    float gx = dot(grassVector2, gv);
    float gy = dot(vec2(-grassVector2.y, grassVector2.x), gv);
    float gxn = gx / grassLength;

    // TODO make gy depends to gx
    if (gxn >= 0.0 && gxn <= 1.0 && abs(gy) <= 0.0008 * (1. - gxn * gxn)) {
        vec3 thisGrassColor = getGrassColor(hash12(grassPos * 2631.6));
        color = vec4(thisGrassColor * (0.2 + 0.8 * gxn), 1.0);
    	return grassVector3.z * gxn;
    }
    else {
        color = vec4(0., 0., 0., 1.);
        return -1.0;
    }
}

float getPoint(in vec2 position, out vec4 color) {
   	int xcount = int(1. / BLADES_SPACING);
    int ycount = int(1. / BLADES_SPACING);
    int ox = int(position.x * float(xcount));
    int oy = int(position.y * float(ycount));

    float maxz = 0.0;

    for (int i = -LOOKUP_DIST; i < LOOKUP_DIST; ++i) {
        for (int j = -LOOKUP_DIST; j < LOOKUP_DIST; ++j) {
            vec2 upos = vec2(ox + i, oy + j);
            vec2 grassPos = (upos * BLADES_SPACING + hash22(upos) * JITTER_MAX);

            vec4 tempColor;
            float z = getGrassBlade(position, grassPos, tempColor);

            if (z > maxz) {
                maxz = z;
                color = tempColor;
            }
        }
    }
    if (maxz == 0.0) {
        color = vec4(0.);
    }

    return maxz;
}

void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID);
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_GlobalInvocationID.xy / iResolution.xy - 1.;
    
    vec4 color;
    float z = getPoint(uv, color);
    
    // Output to screen
    vec4 fragColor = color;
	
	imageStore(_TextureTex, id.xy, fragColor);
}
