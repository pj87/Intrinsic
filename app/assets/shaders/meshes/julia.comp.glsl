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

vec3 fmod(vec3 x, float y)
{
	return (x - y * trunc(x/y));
}

vec3 fade(vec3 t)
{
	return t * t * t * (t * (t * 6 - 15) + 10);
}

vec4 perm2d(vec2 uv)
{
	return textureLod(_PermTable2D, uv, 0);
}

float gradperm(float x, vec3 p)
{
	vec3 g = textureLod(_Gradient3D, vec2(x, 0), .0).rgb * 2.0 - 1.0;
	return dot(g, p);
}
						
float inoise(vec3 p)
{
	vec3 P = fmod(floor(p), 256.0);	// FIND UNIT CUBE THAT CONTAINS POINT
  	p -= floor(p);                  // FIND RELATIVE X,Y,Z OF POINT IN CUBE.
	vec3 f = fade(p);               // COMPUTE FADE CURVES FOR EACH OF X,Y,Z.

	P = P / 256.0;
	const float one = 1.0 / 256.0;
	
    // HASH COORDINATES OF THE 8 CUBE CORNERS
	vec4 AA = perm2d(P.xy) + P.z;
 
	// AND ADD BLENDED RESULTS FROM 8 CORNERS OF CUBE
  	return mix( mix( mix( gradperm(AA.x, p ),  
                             gradperm(AA.z, p + vec3(-1, 0, 0) ), f.x),
                       mix( gradperm(AA.y, p + vec3(0, -1, 0) ),
                             gradperm(AA.w, p + vec3(-1, -1, 0) ), f.x), f.y),
                             
                 mix( mix( gradperm(AA.x+one, p + vec3(0, 0, -1) ),
                             gradperm(AA.z+one, p + vec3(-1, 0, -1) ), f.x),
                       mix( gradperm(AA.y+one, p + vec3(0, -1, -1) ),
                             gradperm(AA.w+one, p + vec3(-1, -1, -1) ), f.x), f.y), f.z);
}

// fractal sum, range -1.0 - 1.0
float fBm(vec3 p, int octaves)
{
	float freq = _Frequency, amp = 0.5;
	float sum = 0;	
	for(int i = 0; i < octaves; i++) 
	{
		sum += inoise(p * freq) * amp;
		freq *= _Lacunarity;
		amp *= _Gain;
	}
	return sum;
}

// fractal abs sum, range 0.0 - 1.0
float turbulence(vec3 p, int octaves)
{
	float sum = 0;
	float freq = _Frequency, amp = 1.0;
	for(int i = 0; i < octaves; i++) 
	{
		sum += abs(inoise(p*freq))*amp;
		freq *= _Lacunarity;
		amp *= _Gain;
	}
	return sum;
}

// Ridged multifractal, range 0.0 - 1.0
// See "Texturing & Modeling, A Procedural Approach", Chapter 12
float ridge(float h, float offset)
{
    h = abs(h);
    h = offset - h;
    h = h * h;
    return h;
}

float ridgedmf(vec3 p, int octaves, float offset)
{
	float sum = 0;
	float freq = _Frequency, amp = 0.5;
	float prev = 1.0;
	for(int i = 0; i < octaves; i++) 
	{
		float n = ridge(inoise(p*freq), offset);
		sum += n*amp*prev;
		prev = n;
		freq *= _Lacunarity;
		amp *= _Gain;
	}
	return sum;
}

float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}

float sdBox( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return length(max(d,0.0))
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

/*
float map(vec3 p, vec4 c)
{
	p/10.0;
    vec3 z = p;
    float m = dot(z,z);

    vec4 trap = vec4(abs(z),m);
	float dz = 1.0;
    
    
	for( int i=0; i<4; i++ )
    {
		dz = 8.0*pow(m,3.5)*dz;
                
        float r = length(z);
        float b = 8.0*acos( clamp(z.y/r, -1.0, 1.0));
        float a = 8.0*atan( z.x, z.z );
        z = c + pow(r,8.0) * vec3( sin(b)*sin(a), cos(b), sin(b)*cos(a) );

        trap = min( trap, vec4(abs(z),m) );

        m = dot(z,z);
		if( m > 2.0 )
            break;
    }

    return 10.0*0.25*log(m)*sqrt(m)/dz;
}
*/

vec4 qsqr( in vec4 a ) // square a quaterion
{
    return vec4( a.x*a.x - a.y*a.y - a.z*a.z - a.w*a.w,
                 2.0*a.x*a.y,
                 2.0*a.x*a.z,
                 2.0*a.x*a.w );
}

float map1(vec3 p, vec4 c)
{
    vec4 z = vec4(p,0.0);
    float md2 = 1.0;
    float mz2 = dot(z,z);

    //vec4 trap = vec4(abs(z.xyz),dot(z,z));

    for( int i=0; i<11; i++ )
    {
        md2 *= 4.0*mz2;   // dz -> 2·z·dz, meaning |dz| -> 2·|z|·|dz| (can take the 4 out of the loop and do an exp2() afterwards)
        z = qsqr(z) + c;  // z  -> z^2 + c

        //trap = min( trap, vec4(abs(z.xyz),dot(z,z)) );

        mz2 = dot(z,z);
        if(mz2>4.0) break;
    }

    return 0.25*sqrt(mz2/md2)*log(mz2);  // d = 0.5·|z|·log|z| / |dz|
}

/*
float opScale( in vec3 p, in float s)
{
    return -map(p/s)*s;
}
*/

vec4 qSquare( vec4 a )
{
    return vec4( a.x*a.x - dot(a.yzw,a.yzw), 2.0*a.x*(a.yzw) );
}

vec4 qCube( vec4 a )
{
	return a * ( 4.0*a.x*a.x - dot(a,a)*vec4(3.0,1.0,1.0,1.0) );
}

//--------------------------------------------------------------------------------

float lengthSquared( vec4 z ) { return dot(z,z); }

// animation

float map2( vec3 p, vec4 c )
{
    vec4 z = vec4( p, 0.2 );
	
	float m2 = 0.0;
	vec2  t = vec2( 1e10 );

	float dz2 = 1.0;
	for( int i=0; i<4; i++ ) 
	{
        // |dz|² = |3z²|²
		dz2 *= 9.0*lengthSquared(qSquare(z));
        
		// z = z^3 + c		
		z = qCube( z ) + c;
		
        // stop under divergence		
        m2 = dot(z, z);		
        if( m2>10000.0 ) break;				 

        // orbit trapping ( |z|² and z_x  )
		//t = min( t, vec2( m2, abs(z.x)) );

	}

	// distance estimator: d(z) = 0.5·log|z|·|z|/|dz|   (see http://iquilezles.org/www/articles/distancefractals/distancefractals.htm)
	float d = 0.25 * log(m2) * sqrt(m2/dz2 );
	//float d = log(m2);

	return d;
}

float map3( in vec3 p)
{
    vec3 w = p;
    float m = dot(w,w);
	float dz = 1.0;
    
	for( int i=0; i<1; i++ )
    {
        dz = 8.0*pow(sqrt(m),7.0)*dz + 1.0;
		//dz = 8.0*pow(m,3.5)*dz + 1.0;
        
        float r = length(w);
        float b = 8.0*acos( w.y/r);
        float a = 8.0*atan( w.x, w.z );
        w = p + pow(r,8.0) * vec3( sin(b)*sin(a), cos(b), sin(b)*cos(a) );

        m = dot(w,w);
		if( m > 256.0 )
            break;
    }

    return 0.25*log(m)*sqrt(m)/dz;
}

float mapScaled(vec3 p, vec4 c)
{
	return map2(p/12.5f, c) * 12.5f;
	//return map3(p/0.0025f) * 0.0025f;
}

layout(local_size_x = 6u, local_size_y = 6u, local_size_z = 6u) in;
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
	_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(12.5f), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -mapScaled(uv - vec3(100.0f * sin(_Frequency)), c);
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdTorus(uv - vec3(_Frequency), vec2(5.0, 2.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdBox(uv - vec3(10.0), vec3(10.0, 5.0, 5.0));
	//_Result[id.x + id.y * _Width + id.z * _Width * _Height] = -sdSphere(uv - vec3(10.0), 10.0);
	_NormalResult[id.x + id.y * _Width + id.z * _Width * _Height] = vec4(0.);
}
