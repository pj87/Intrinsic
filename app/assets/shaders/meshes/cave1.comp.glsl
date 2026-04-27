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

// The far plane. I'd like this to be larger, but the extra iterations required to render the 
// additional scenery starts to slow things down on my slower machine.
#define FAR 80.


// 2x2 matrix rotation. Angle vector, courtesy of Fabrice.
mat2 rot2( float th ){ vec2 a = sin(vec2(1.5707963, 0) + th); return mat2(a, -a.y, a.x); }

// 1x1 and 3x1 hash functions.
float hash( float n ){ return fract(cos(n)*45758.5453); }
float hash( vec3 p ){ return fract(sin(dot(p, vec3(7, 157, 113)))*45758.5453); }


// Draw the object on the repeat tile. In this case, a sphere. The result it squared, but that can
// be taken into account after obtaining the minimum. See below.
float drawObject(in vec3 p){ p = fract(p)-.5; return dot(p, p); }


// Repeat cellular tile routine. The operation count is extremely low when compared to conventional
// methods. No loops, no flooring, no hash calls, etc. Conceptually speaking, this is the fastest way 
// to produce a reasonable 3D cellular pattern... Although, there's one with three objects and no 
// rotation, but quality really suffers at that point. 
float cellTile(in vec3 p){
    
    // Draw four overlapping objects (spheres, in this case) at various positions throughout the tile.
    vec4 d; 
    d.x = drawObject(p - vec3(.81, .62, .53));
    p.xy = vec2(p.y-p.x, p.y + p.x)*.7071;
    d.y = drawObject(p - vec3(.39, .2, .11));
    p.yz = vec2(p.z-p.y, p.z + p.y)*.7071;
    d.z = drawObject(p - vec3(.62, .24, .06));
    p.xz = vec2(p.z-p.x, p.z + p.x)*.7071;
    d.w = drawObject(p - vec3(.2, .82, .64));

    // Obtain the minimum, and you're done.
    d.xy = min(d.xz, d.yw);
        
    return min(d.x, d.y)*2.66; // Scale between zero and one... roughly.
}



// The path is a 2D sinusoid that varies over time, which depends upon the frequencies and amplitudes.
vec2 path(in float z){ return vec2(20.*sin(z * .04), 4.*cos(z * .09) + 3.*(sin(z*.025)  - 1.)); }


// The triangle function that Shadertoy user Nimitz has used in various triangle noise demonstrations.
// See Xyptonjtroz - Very cool.
//vec3 tri(in vec3 x){return abs(fract(x)-.5);} // Triangle function.

// The function used to perturb the walls of the passage structure: I came up with the tiled cellular
// routine in order to raymarch something that resembled Voronoi. Regular 3D Voronoi is so intensive
// that it's hard enough to bump map, let alone raymarch. Conceptually speaking, this algorithm is as
// fast as you're going to get, yet it's still only good for one raymarching layer. The other cellular
// layers (two more) have been bump mapped.
float surfFunc(in vec3 p){
    
    float c = cellTile(p/6.); // Resembles a standard 3D Voronoi layer.
    return mix(c, cos(c*6.283*2.)*.5 + .5, .125); // Mixing in a touch of sinusoidal variation.
    
    // Cheaper wall layering (although, not much), for comparison. 
    //p /= 2.;
    //float c = dot(tri(p*.5 + tri(p*0.25).yzx), vec3(0.666));
    //return mix(c, cos(c*6.283*1.5)*.5 + .5, .25);
    
    //p /= 5.;
    //return dot(tri(p + tri(p.zxy)), vec3(0.666));

}


// IQ's smooth minium function. 
float smin(float a, float b , float s){
    
    float h = clamp( 0.5 + 0.5*(b-a)/s, 0. , 1.);
    return mix(b, a, h) - h*(1.0-h)*s;
}

// Smooth maximum, based on IQ's smooth minimum.
float smax(float a, float b, float s){
    
    float h = clamp( 0.5 + 0.5*(a-b)/s, 0., 1.);
    return mix(b, a, h) + h*(1.0-h)*s;
}

// The desert passage scene. Use a gyroid object as the passage-system base layer, carve it out
// with the cellular function, put in a floor, then cap the whole thing off at roof height.
float map(vec3 p){
    
	// Surface function to perturb the walls.
    float sf = surfFunc(p);

    // A gyroid object to form the main passage base layer.
    float cav = dot(cos(p*3.14159265/8.), sin(p.yzx*3.14159265/8.)) + 2.;
    
    // Mold everything around the path.
    p.xy -= path(p.z);
    
    // The oval tunnel. Basically, a circle stretched along Y.
    float tun = 1.5 - length(p.xy*vec2(1, .4));
   
    // Smoothly combining the tunnel with the passage base layer,
    // then perturbing the walls.
    tun = smax(tun, 1.-cav, 2.) + .75 + (.5-sf);
    
    float gr = p.y + 7. - cav*.5 + (.5-sf)*.5; // The ground.
    float rf = p.y - 15.; // The roof cutoff point.
    
    // Smoothly combining the passage with the ground, and capping
    // it off at roof height.
    return smax(smin(tun, gr, .1), rf, 1.);
 
 
}

float mapScaled(vec3 p, vec4 c)
{
	return map(p / 1.0) * 1.0;
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
