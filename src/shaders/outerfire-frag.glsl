#version 300 es

precision highp float;

uniform vec4 u_FireColor;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_Col;
in vec4 fs_Pos;
in float fs_displacement;

uniform float u_Time;

uniform vec2 canvasSize;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.


//=====================================================================
// Noise Functions
//=====================================================================
vec3 random3(vec3 p)
{
    return fract(sin(vec3(dot(p,vec3(127.1f, 311.7f, 191.999f)),
                        dot(p, vec3(269.5f, 183.3f, 191.999f)),
                        dot(p, vec3(420.6f, 631.2f, 191.999f))))
                                * 43758.5453f);
}

const float PI = 3.14159265359;

float WorleyNoise(vec3 xyz, float columns, float rows, float aisle) {
	
	vec3 index_xyz = floor(vec3(xyz.x * columns, xyz.y * rows, xyz.z * aisle));
	vec3 fract_xyz = fract(vec3(xyz.x * columns, xyz.y * rows, xyz.z * aisle));
	
	float minimum_dist = 1.0;  
	
    for(int z= -1; z <= 1; z++){
	    for (int y= -1; y <= 1; y++) {
		    for (int x= -1; x <= 1; x++) {
                vec3 neighbor = vec3(float(x),float(y),float(z));
                vec3 point = random3(index_xyz + neighbor);
                
                vec3 diff = neighbor + point - fract_xyz;
                float dist = length(diff);
                minimum_dist = min(minimum_dist, dist);
            }
		}
	}
	
	return minimum_dist;
}

// procedural noise from IQ
vec2 hash( vec2 p )
{
	p = vec2( dot(p,vec2(127.1,311.7)),
			 dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p )
{
	const float K1 = 0.366025404; // (sqrt(3)-1)/2;
	const float K2 = 0.211324865; // (3-sqrt(3))/6;
	
	vec2 i = floor( p + (p.x+p.y)*K1 );
	
	vec2 a = p - i + (i.x+i.y)*K2;
	vec2 o = (a.x>a.y) ? vec2(1.0,0.0) : vec2(0.0,1.0);
	vec2 b = a - o + K2;
	vec2 c = a - 1.0 + 2.0*K2;
	
	vec3 h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	
	vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
	
	return dot( n, vec3(70.0) );
}


float fbm(vec2 uv)
{
	float f;
	mat2 m = mat2( 1.6,  1.2, -1.2,  1.6 );
	f  = 0.5000*noise( uv ); uv = m*uv;
	f += 0.2500*noise( uv ); uv = m*uv;
	f += 0.1250*noise( uv ); uv = m*uv;
	f += 0.0625*noise( uv ); uv = m*uv;
	f = 0.5 + 0.5*f;
	return f;
}

// Triangle Wave
float triangle_wave(float x, float freq, float amp) {
    return abs(mod((x * freq), amp) - (0.5 * amp));
}

float impulse(float k, float x) {
    float h = k * x;
    return h * exp(1.f - h);
}

float bias(float t, float b) 
{
    return pow(t, (log(b) / log(0.5)));
}

void main()
{ 
    // Correlate color with displacement using bias function
    float b = bias(fs_displacement * 1.05, 0.6);
    vec4 color1 = vec4(1.3, 0.1, 0.2, 1.) + impulse(0.2, u_Time * 0.3);
    vec4 color2 = vec4(0.5, 0., 0.5, 1.);
    vec4 newColor = mix(color1, color2, b);

    // Use worley noise and displacement to create some funky colors!~
    float w = WorleyNoise(vec3(fs_displacement * u_Time * 0.03), 0.6, 0.6, 0.6);
    out_Col = mix(u_FireColor, newColor, w);
}
