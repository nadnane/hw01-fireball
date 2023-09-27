#version 300 es

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Pos;
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

uniform float u_Time;

uniform vec2 canvasSize;

uniform int FBM_Octaves;
uniform float FBM_Freq;
uniform float FBM_Amp;

// Triangle Wave
float triangle_wave(float x, float freq, float amp) {
    return abs(mod((x * freq), amp) - (0.5 * amp));
}

float parabola(float x, float k)
{
    return pow(4.0 * x * (1.0 - x), k);
}

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

float noise3D(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 721.5))) *
                 43758.5453);
}

float interpNoise3D(vec3 p) {
    int intX = int(floor(p.x)), intY = int(floor(p.y)), intZ = int(floor(p.z));
    float fractX = fract(p.x), fractY = fract(p.y), fractZ = fract(p.z);

    float v1 = noise3D(vec3(intX, intY, intZ));
    float v2 = noise3D(vec3(intX + 1, intY, intZ));
    float v3 = noise3D(vec3(intX, intY + 1, intZ));
    float v4 = noise3D(vec3(intX + 1, intY + 1, intZ));
    float v5 = noise3D(vec3(intX, intY, intZ + 1));
    float v6 = noise3D(vec3(intX + 1, intY, intZ + 1));
    float v7 = noise3D(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise3D(vec3(intX + 1, intY + 1, intZ + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    float i3 = mix(v5, v6, fractX);
    float i4 = mix(v7, v8, fractX);

    float j1 = mix(i1, i2, fractY);
    float j2 = mix(i3, i4, fractY);

    return mix(j1, j2, fractZ);
}

float surflet(vec3 p, vec3 gridPoint) {
    // Compute the distance between p and the grid point along each axis, and warp it with a
    // quintic function so we can smooth our cells
    vec3 t2 = abs(p - gridPoint);
    vec3 t = vec3(1.f) - 6.f * pow(t2, vec3(5.f)) + 15.f * pow(t2, vec3(4.f)) - 10.f * pow(t2, vec3(3.f));
    // Get the random vector for the grid point (assume we wrote a function random2
    // that returns a vec2 in the range [0, 1])
    vec3 gradient = random3(gridPoint) * 2. - vec3(1., 1., 1.);
    // Get the vector from the grid point to P
    vec3 diff = p - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * t.x * t.y * t.z;
}


float perlinNoise(vec3 p) {
	float surfletSum = 0.f;
	// Iterate over the four integer corners surrounding uv
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
			for (int dz = 0; dz <= 1; ++dz) {
                surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
            }
		}
	}
	return surfletSum;
}

float fbm(vec3 p) {
    float total = 0.0;
    float persistence = 1.f / 2.f;
    int octaves = 8;
    float freq = 16.f;
    float amp = 1.0f;
    for(int i = 1; i <= octaves; i++) {
        total += interpNoise3D(p * freq) * amp;

        freq *= 2.f;
        amp *= persistence;
    }
    return total;
}

float customfbm(vec3 p, int octaves, float freq, float amp) {
    float total = 0.0;
    float persistence = 1.f / 2.f;
    for(int i = 1; i <= octaves; i++) {
        total += interpNoise3D(p * freq) * amp;
        freq *= 2.f;
        amp *= persistence;
    }
    return total;
}

void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    fs_Pos = vs_Pos;

    vec4 modelposition = u_Model * fs_Pos;   // Temporarily store the transformed vertex positions for use below

    vec3 flame_dir = vec3(0., 1., 0.);
    float prod = dot(flame_dir, vec3(fs_Nor));

    if (prod > 0.0) {
        modelposition += vec4(flame_dir * prod, 0.0) * fbm(modelposition.xyz + flame_dir * sin(u_Time * 0.001));
    }
    //modelposition.y += sin(u_Time *0.01) / 6.0;

    // Add some wobble from side to side
    modelposition.x += customfbm(vec3(vs_Pos.xyz), 2, 0.1, sin(u_Time * 0.05));

    // Displace the sphere's surface with animation!~
    float d = abs(sin(vs_Pos.x + 1.5) + customfbm(vs_Pos.xyz, 3, 5.0, 1.0));
    modelposition.xyz *= 0.8 + (clamp(sin(u_Time * 0.04 + d), 0.1, 2.0));

    fs_LightVec = lightPos - modelposition;

    gl_Position = u_ViewProj * modelposition;
    
}
