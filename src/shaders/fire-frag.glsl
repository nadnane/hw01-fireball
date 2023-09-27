#version 300 es

precision highp float;

uniform vec4 u_FireColor1;
uniform vec4 u_FireColor2;
uniform vec4 u_FireColor3;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_Col;
in vec4 fs_Pos;

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

// I used these as references to make the fire eyes/face!
// https://www.shadertoy.com/view/stjSDz
// https://www.shadertoy.com/view/XsXSWS

#define SCLERA_R 0.20
#define IRIS_R 0.05
#define BTW_EYES_DIST 0.47
#define MOUTH_TO_EYES_DIST -0.35
#define MOUTH_SIZE 0.08

float sclera(vec2 middle, vec2 uv){

    vec2 leftEyePos = middle - vec2(BTW_EYES_DIST, 0.) ;
    float leftSclera =  smoothstep(0.005, 0.,length(leftEyePos-uv)-SCLERA_R);
    
    vec2 rightEyePos = middle + vec2(BTW_EYES_DIST, 0.);
    float rightSclera =  smoothstep(0.005, 0.,length(rightEyePos-uv)-SCLERA_R);

    return (rightSclera + leftSclera);
}

float iris(vec2 middle, vec2 uv)
{
    vec2 leftEyePos = middle - vec2(BTW_EYES_DIST-0.01, 0.005) ;
    vec2 rightEyePos = middle + vec2(BTW_EYES_DIST-0.01, -0.005);

    float leftIris =  smoothstep(0.005, 0.,length(leftEyePos-uv)-IRIS_R);
    float rightIris =  smoothstep(0.005, 0.,length(rightEyePos-uv)-IRIS_R);
    
   return (rightIris + leftIris);

}

float mouth(vec2 middleEyes,vec2 uv)
{
  vec2 pos = vec2(middleEyes.x, middleEyes.y + MOUTH_TO_EYES_DIST); 
  float shape = smoothstep(0.005, 0.,length(pos-uv)- MOUTH_SIZE);
  return shape;
}

void main()
{

    if (fs_Pos.z > 0.0)
    {
        vec2 coord = fs_Pos.xy/canvasSize.xy;

        vec2 uv = fs_Pos.xy;
        vec2 q = uv;
        q.x *= 1.0;
        q.y *= 1.0;
        float strength = 0.5;
        float flameSpeed = 0.01;
        float T3 = max(3.0, 1.25*strength)* (u_Time * flameSpeed);
        
        q.x = mod(q.x, 1.0) - 0.5;
        q.y += 0.1;


        float n = fbm(strength * q - vec2(0.0, T3));

        float c = 1.0 - 16.0 
        * pow(max( 0.0, length(q * vec2(1.0 + q.y * 1.5, 0.75) ) - n 
        * max( 0., q.y + 0.25)), 1.2);

        float c1 = n * c * (1.5-pow(2.50*uv.y,4.));
        c1 = clamp(c1, 0.0, 1.0);

        vec3 col = vec3(1.5 * c1, 1.5*c1*c1*c1, pow(c1, 5.0));

        float a = c * (1.-pow(uv.y, 3.0));

        vec3 body = mix(vec3(0.), col, a);

        // face
        float sclera = sclera(vec2(0.),uv);   
        float iris = 1.-iris(vec2(0.),uv);   
        float mouth = mouth(vec2(0.),uv);
        body += sclera;

        out_Col = vec4(body * iris + mouth, 1.0);
    }
    else
    {
        out_Col = vec4(0.0);
    }
}
