// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// See http://www.iquilezles.org/www/articles/warp/warp.htm for details

// https://www.shadertoy.com/view/MslXz8

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

vec3 color = vec3(.71, .65, .6);
vec3 blue = vec3(0.18, 0.47, .84);
vec3 red = vec3(1., 0., 0.);
vec3 white = vec3(1., 1., 1.);
vec3 lightblue = vec3(.36, .60, .88);
vec3 yellow = vec3(1., 1., 0.);
vec3 blue2 = vec3(0., 0., .63);

#define PATTERN 1


#define PI 3.141592
#define TWO_PI 6.2831

float random (in vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233)))*43758.5453123);
}

float createCircle(vec2 uv, vec2 center, float radius)
{
    float circle = step(distance(center,uv), radius);
    return circle;
}

// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (in vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,  // -1.0 + 2.0 * C.x
                        0.024390243902439); // 1.0 / 41.0
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i); // Avoid truncation effects in permutation
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
        + i.x + vec3(0.0, i1.x, 1.0 ));

    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float rectangle(vec2 uv, vec2 position, vec2 size)
{
    float leftSide = position.x;
    float rightSide = position.x + size.x;
    float bottom = position.y;
    float top = position.y + size.y;
    
    float rect = step(leftSide, uv.x) - step(rightSide, uv.x); 
    float rect2 = step(bottom, uv.y) - step(top, uv.y);
    
    return (rect * rect2);
}

#define OCTAVES 6
float fbm (in vec2 uv) {
    // Initial values
    float value = 0.0;
    float amplitud = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitud * noise(uv);
        uv *= 2.;
        amplitud *= .5;
    }
    return value;
}

float galaxy (in vec2 uv) {
    float layer1 = step(.99, random(uv)) * (sin(iTime) + 1.) / 2.;
    layer1  += step(.995, random(uv));
   	return layer1;
}



#if PATTERN == 1
//Wood
void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID);
	vec2 uv = gl_GlobalInvocationID.xy / iResolution.xy;
    float ratio = iResolution.x/iResolution.y;
    uv.x *= ratio;
    
    vec3 value = vec3(0.860, 0.806, 0.574);
    
    float planks;
    planks = abs(sin(uv.x*100.));
    //value *= planks;
    
    vec3 colorA = vec3(0.);
    value = mix(value, colorA, vec3(fbm(uv.xx * 10.)));  
   	
   	value = mix(value, vec3(0.390, 0.265, 0.192), vec3(fbm(uv.xx*22.)));
    value = mix(value, vec3(0.930, 0.493, 0.502), random(uv.xx)*.1);
    value -= (noise(uv*vec2(500., 14.) - noise(uv*vec2(1000., 64.))) * 0.1);
    
    vec4 fragColor = vec4(vec3(value) , 1.0);
	imageStore(_TextureTex, id.xy, fragColor);
}

//Lava
#elif PATTERN == 2
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
  	vec2 uv = fragCoord.xy / iResolution.xy;
   	uv += iTime/100.;
	float brightness = 1.7;
    yellow *= brightness;
    vec3 color = mix(yellow, red,vec3(fbm(uv*15.)*1.3));
    fragColor = vec4(vec3(color),1.0);
}

#elif PATTERN == 3
//Scottish
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   	vec2 uv = fragCoord.xy / iResolution.xy;
    float ratio = iResolution.x/iResolution.y;
    uv.x *= ratio;
    
    vec3 value = vec3(1., 0., 0.);
    
    float planks;
    planks = abs(sin(uv.x*20.) +.5 );
    value *= planks;
    
    vec3 colorA = vec3(0.);
    value = mix(value, colorA, vec3(fbm(uv.yy * 50.)));  
   	
   	value = mix(value, vec3(0.390, 0.265, 0.192), vec3(fbm(uv.xx*22.)));
    value = mix(value, vec3(0.930, 0.493, 0.502), random(uv.xx)*.1);
    value -= (noise(uv*vec2(500., 14.) - noise(uv*vec2(1000., 64.))) * 0.1);
    
    fragColor = vec4(vec3(value) , 1.0);
}


#elif PATTERN == 4
//Galaxy
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 clouds = mix(blue,vec3(0.),vec3(fbm(uv*10.)*2.));
    fragColor = vec4(vec3(galaxy(uv) + clouds), 1.0);
}

//Moon
#elif PATTERN == 5
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
  	vec2 uv = fragCoord.xy / iResolution.xy;
    
    float ratio = iResolution.x / iResolution.y;
   	uv.x *= ratio;
  
	vec3 circle = vec3(createCircle(uv, vec2(0.5 * ratio, -0.6), .99));
    vec3 color = mix(vec3(0.07,  0.1, .25), vec3(1.),vec3(fbm(uv*15.)*1.3));
	circle *= color;
    
    vec3 blue = vec3(0.07,  0.1, .25);
    vec3 clouds = mix(blue,vec3(0.),vec3(fbm(uv*10.)*2.)); 
    vec3 stars = vec3(galaxy(uv) + clouds);
    
    vec3 circle2 = vec3(createCircle(uv, vec2(0.5 * ratio, 0.5), .1)) * blue;
    
    if(circle.x == 0.){
    	fragColor = vec4(vec3(stars) , 1.0);
    }
    else {
        fragColor = vec4(vec3(circle), 1.0);
    }
}

//Rain
#elif PATTERN == 6
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
  	float ratio = iResolution.x / iResolution.y;
    uv.y *= -ratio;
	
    float value = 0.;
    float idy = floor(uv.x * 200.);
    float r = random(vec2(idy));
    float speed = fract(iTime * 2. * r );
    uv.y += r - speed;
    uv.y = fract(uv.y);
    
    value = step(0.14 * r, uv.y) - step(.17 *r, uv.y);
    fragColor = vec4(vec3(lightblue - (value * white)), 1.);
}

//Clouds
#elif PATTERN == 7
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv /= 2.;
   	uv += iTime / 100.;
	vec3 clouds = mix(blue,vec3(.8, .86, .91),vec3(fbm(uv*10.)*1.));
    fragColor = vec4(vec3(clouds),1.0);
}

//Granite
#elif PATTERN == 8
//https://2.imimg.com/data2/TS/UE/MY-2957688/black-granite-250x250.jpg
void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID);
	vec2 uv = gl_GlobalInvocationID.xy / iResolution.xy;
	vec3 clouds = mix(vec3(1.),vec3(0.),vec3(fbm(uv*50.)*2.5));
    vec4 fragColor = vec4(vec3(clouds),1.0);
	imageStore(_TextureTex, id.xy, vec4(fragColor, 1.0));
}
#endif