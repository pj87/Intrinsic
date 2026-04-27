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

// https://www.shadertoy.com/view/4lyBzK
// Fork of "2 * 2d -> 3d  " by TLC123. https://shadertoy.com/view/MlyfRW
// 2018-11-21 16:26:28

// Fork of "The Walking Raymarcher" by xorxor. https://shadertoy.com/view/Mt3XWH
// 2018-11-11 15:37:21


// tracer from  https://shadertoy.com/view/Mt3XWH
// sdPentagon from https://www.shadertoy.com/view/llVyWW
// roundrect forked fromm https://www.shadertoy.com/view/4sjyRz
// http://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
// https://www.shadertoy.com/view/XdfXDB
// http://mercury.sexy/hg_sdf/
// sexy union functions work just as great in 2D

// grass https://www.shadertoy.com/view/ls33W7
float  tile=24.0;

float hash1( vec2 n )
{
    return fract(sin(dot(n,vec2(1.0,113.0)))*43758.5453123);
}
float fOpPipe(float a, float b, float r) {
    return length(vec2(a, b)) - r;
}
vec2 pR45(  vec2 p) {
    p = (p + vec2(p.y, -p.x)) * sqrt(0.5);
    return (p);
}
vec2 pR90(  vec2 p) {
    p = (vec2(p.y, -p.x)) ;
    return (p);
}
float pMod1(inout float p, float size) {
    float halfsize = size * 0.5;
    float c = floor((p + halfsize) / size);
    p = mod(p + halfsize, size) - halfsize;
    return c;
}
// The "Columns" flavour makes n-1 circular columns at a 45 degree angle:
float fOpUnionColumns(float a, float b, float r, float n) {
    if ((a < r) && (b < r)) {
        vec2 p = vec2(a, b);
        float columnradius = r * sqrt(2.0) / ((n - 1.) * 2. + sqrt(2.));
        pR45(p);
        p.x -= sqrt(2.) / 2. * r;
        p.x += columnradius * sqrt(2.);
        if (mod(n, 2.) == 1.) {
            p.y += columnradius;
        }
        // At this point, we have turned 45 degrees and moved at a point on the
        // diagonal that we want to place the columns on.
        // Now, repeat the domain along this direction and place a circle.
        pMod1(p.y, columnradius * 2.);
        float result = length(p) - columnradius;
        result = min(result, p.x);
        result = min(result, a);
        return min(result, b);
    } else {
        return min(a, b);
    }
}
// first object gets a capenter-style groove cut out
float fOpGroove(float a, float b, float ra, float rb) {
    return max(a, min(a + ra, rb - abs(b)));
}

// first object gets a capenter-style tongue attached
float fOpTongue(float a, float b, float ra, float rb) {
    return min(a, max(a - ra, abs(b) - rb));
}

float fOpEngrave(float a, float b, float r) {
    return max(a, (a + r - abs(b)) * sqrt(0.5));
}

float fOpUnionStairs(float a, float b, float r, float n) {
    float s = r / n;
    float u = b - r;
    return min(min(a, b), 0.5 * (u + a + abs((mod(u - a + s, 2. * s)) - s)));
}

float sdBox( in vec2 p, in vec2 b) {
    vec2 d = abs(p) - b;
    return (max(d.x, d.y));
}


float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdTriangle( in vec2 p, in vec2 p0, in vec2 p1, in vec2 p2) {
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;

    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);

    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
            vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
        vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));

    return -sqrt(d.x) * sign(d.y);
}



float smin(float a, float b) {
    const float k = .26;
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);

}

float smax(float d1, float d2, float k) {

    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return mix(d2, -d1, h) + k * h * (1.0 - h);
}


float roundrect(vec2 p, vec2 c, vec2 r) {

    p = abs(p) - c + r;
    if (p.x >= 0.0 && p.y >= 0.0)
        return length(p) - r.x;
    else
        return max(p.x, p.y) - r.x;
}
float sdLine( in vec2 p, in vec2 a, in vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}


float shape1(vec2 p ,float seed) {
   
    
 p=fract(p/tile)*tile;
  p = vec2(abs(p.x)-(tile*0.5)  ,p.y-(tile*0.5+3.)  ); 
    
if (fract(seed*7.1)<=0.5){p=pR90(p);           }
if (fract(seed*9.1)<=0.5){p=pR90(p);           }
   if (seed<=0.5){p=p.yx;           }
if (fract(seed*3.1)<=0.5){p=pR90(p);           }

    float d = roundrect(p - vec2(0, -3), vec2(6, 3),vec2(0.));

    if (fract(seed*13.1)<=0.5){p=pR90(p);           }
    
      p = vec2(  (p.x)  +cos(seed*17.)*1.25 ,p.y +sin(seed*27.)*1.25); 



    d = fOpUnionStairs(d, roundrect(p - vec2(0, -4.4), vec2(2.2, 3),vec2(0.)), .6, 2.);
    //d=min(d,   sdBox(p-vec2(0,-2),vec2(2,2) ) );
    // d=fOpUnionStairs(d, sdLine(p,vec2(0,0),vec2(0,-3))-2. ,.8,2.);

    d = fOpUnionStairs(d, sdLine(p, vec2(0, 0), vec2(0, -3)) - 1.9, .5, 2.);
    d = fOpUnionStairs(d, sdLine(p, vec2(0, 2), vec2(0, -3)), .5, 2.);
    d = fOpUnionStairs(d, sdLine(p, vec2(1.4, 1.4), vec2(0, 0)), .5, 2.);
    d = fOpUnionStairs(d, sdLine(p, vec2(-1.4, 1.4), vec2(0, 0)), .5, 2.);

      p= vec2(abs(p.x),p.y); // mirror p
    
    float g = sdBox(p - vec2(0, -3), vec2(4.45, 11));
    g = smin(g, sdBox(p - vec2(0, -3), vec2(12, 1.42)));
    //d=min(d,fOpGroove(d,g,0.2,0.51));
    // d=fOpGroove(d,g,0.2,0.51);
    d = (fOpTongue(d, g, 0.2, 0.7*seed*seed));

    float g1 = (sdBox(p - vec2(0, -6), vec2(1.3, 4)));
    d = smin(d, fOpPipe(d - .6, g1, 0.4*seed));

    return (d);
}


float shape2(vec2 p,float seed) {
    
    

    float d = sdTriangle(p, vec2(0.5, 3), vec2(-4.+sin(seed*10.)*2., 5.+seed*3.), vec2(-10., 5.+seed*3.)); //roof
    d = min(d, sdTriangle(p, vec2(0.5, 3), vec2(-10., 3), vec2(-10.,5.+seed*3.)));

    d = fOpUnionColumns(d, roundrect(p - vec2(-.4, 3), vec2(1.04, .1), vec2(0.1)), .19, 2.);


    d = min(d, roundrect(p - vec2(0, -.5), vec2(0.6, .4), vec2(0.03))); //base

    d = fOpUnionStairs(d, roundrect(p - vec2(-5, 0.4), vec2(5., 2.5), vec2(0.)), 0.3, 2.);

    d = fOpUnionStairs(d, roundrect(p - vec2(0, -1.34), vec2(2.6, .4), vec2(0.)), 0.6, 3.); //base

    d = min(d, roundrect(p - vec2(0, 0.9), vec2(.06, .06), vec2(0.)));
    d = min(d, roundrect(p - vec2(0, 1.9), vec2(.06, .06), vec2(0.)));
    //d=min(d, p.y + 0.9  );
 


    return   d ;
}

float noise( in vec2 x )
{
    vec2 p = floor(x);
    vec2 w = fract(x);
    vec2 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    
#if 0
    p *= 0.3183099;
    float kx0 = 50.0*fract( p.x );
    float kx1 = 50.0*fract( p.x+0.3183099 );
    float ky0 = 50.0*fract( p.y );
    float ky1 = 50.0*fract( p.y+0.3183099 );

    float a = fract( kx0*ky0*(kx0+ky0) );
    float b = fract( kx1*ky0*(kx1+ky0) );
    float c = fract( kx0*ky1*(kx0+ky1) );
    float d = fract( kx1*ky1*(kx1+ky1) );
#else
    float a = hash1(p+vec2(0,0));
    float b = hash1(p+vec2(1,0));
    float c = hash1(p+vec2(0,1));
    float d = hash1(p+vec2(1,1));
#endif
    
    return -1.0+2.0*( a + (b-a)*u.x + (c-a)*u.y + (a - b - c + d)*u.x*u.y );
}


vec3 grass(vec2 p){
    
    return vec3(mix(
        vec3(0.12,0.71,0.),
        vec3(0.07,0.47,0.),
        noise(p)
    ));
}


vec4 map(vec3 p) {
    float plane = abs(p.y + 0.9);

float r= hash1(floor(p.xz/tile))*0.5+0.5;    
float g= hash1(vec2(floor(p.xz/tile)+2.));    
float b= hash1(vec2(floor(p.z/tile)))*0.25;    



    float w = shape1(p.xz,r);
    float d = shape2(vec2(w, p.y),g);


    //return (p.y<-0.8 ?vec4(d,grass(  p.xz*0.04)):vec4(d, vec3(r,g,b)/ max(1.,4.*(p.y-2.2)) ));
	return vec4(d, vec3(r,g,b)/ max(1.,4.*(p.y-2.2)) );
}

float mapScaled(vec3 p, vec4 c)
{
	return map(p/3.0f).x * 3.0f;
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
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(1.01f, 0.0f, -5.0), c);
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(_Lacunarity, 0.0f, _Gain), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(1.5), vec3(1.5, 1.5, 1.5));

	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);
    _NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = vec4(0.0);
}
