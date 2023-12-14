#shader vertex
#version 330 core

layout(location = 0) in vec2 aPos;
layout(location = 1) in vec2 aTex;

out vec2 texCoord;

void main()
{
	texCoord = aTex;
	gl_Position = vec4(aPos.x, aPos.y, 0.0f, 1.0f);
}

#shader fragment
#version 330 core

in vec2 texCoord;
out vec4 FragColor;

uniform vec2 iResolution;
uniform float iTime;

vec2 fragCoord = gl_FragCoord.xy;
vec3 camera = vec3(0.0, 0.0, 4.0);
vec3 col = vec3(0.0);

#define MAX_RAYMARCH_STEPS 250
#define PI 3.1415926535
#define GAMMA 2.2
#define nearPlane 0.00001
#define farPlane 100.0
#define aaON = 4;
#define aaOFF = 1;

const float attConst = 1.0;
const float attLinear = 0.0035f;
const float attQuad = 0.0005f;

struct Material
{
    vec3 ambientCol;
    vec3 diffCol;
    vec3 specCol;
    float alpha;
    float gloss;
    // The gloss number is based on how far it is from the number 1. ex) 0.2 = 1.8, 0.5 = 1.5, 0.0 = 2.0
    float ior;
    // IF 0 < ior < 1 THEN equivalent to 1/ior
    // IF 1 < ior THEN just use the ior
};

struct Surface
{
    float sd;
    Material mat;
};

//----------Materials----------//
Material Obsidian()
{
    vec3 a = vec3(0.0);
    vec3 d = vec3(0.0);
    vec3 s = vec3(1.0);
    float alpha = 135.0;
    float gloss = 1.0;
    float ior = 1.5;
    return Material(a, d, s, alpha, gloss, ior);
}

Material BurntCopper()
{
    vec3 a = vec3(0.05267, 0.007788, 0.00075625);
    vec3 d = vec3(0.30338, 0.044859, 0.004356);
    vec3 s = vec3(0.33709, 0.049844, 0.004831);
    float alpha = 51.1;
    float gloss = 1.5;
    float ior = 1.22;
    return Material(a, d, s, alpha, gloss, ior);
}

Material ShinyPenny()
{
    vec3 a = vec3(0.05267, 0.007788, 0.00075625);
    vec3 d = vec3(0.30338, 0.044859, 0.004356);
    vec3 s = vec3(1.0);
    float alpha = 51.1;
    float gloss = 1.5;
    float ior = 1.22;
    return Material(a, d, s, alpha, gloss, ior);
}

Material Checkerboard(vec3 p)
{
    vec3 a = vec3(mod(floor(p.x * 2.0) + floor(p.z * 2.0), 2.0)) * 0.5; //mod 2.0 with a floor will force it to either be 0.0(black) or 1.0(white)
    vec3 d = vec3(a * 0.2);
    vec3 s = vec3(0.2);
    float alpha = 100.0;
    float gloss = 1.0;
    float ior = 1.0;
    return Material(a, d, s, alpha, gloss, ior);
}

//----------Signed Distance Fields----------//
float rand(float fl)
{
    return fract(sin(fl));
}

float noise(float x)
{
    float fl = floor(x);
    float fc = fract(x);
    return mix(rand(fl), rand(fl + 1.0), fc);
}

Surface SDFfloor(vec3 p, Material mat) // Waves
{
    float d = p.y;
    float amplitude = 0.65;
    float frequency = 0.15;
    float t = iTime * 0.25;
    d += sin(p.y * frequency * 2.1 + t) - sin(p.z * frequency * 2.1 + t);
    d += sin(p.z * frequency * 1.72 + t * 0.437) - sin(p.x * frequency * 1.72 + t * 0.193);
    d += sin(p.x * frequency * 2.221 + t * 0.193) - sin(p.z * frequency * 2.221 + t * 0.437);
    d += sin(p.x * frequency * 3.1122 + t * 0.269) - sin(p.z * frequency * 3.1122 + t * 0.269);
    d *= amplitude;
    d += 1.0;

    const int octaves = 8;
    float lacunarity = 2.0;
    float gain = 0.65;

    //Loop of octaves
    for (int i = 0; i < octaves; i++)
    {
        d += amplitude * noise(sin(frequency * p.y));
        frequency *= lacunarity;
        amplitude *= gain;
    }

    d -= (0.25 * (cos(p.z + t + noise(p.y))) + 0.25 * cos(p.x + t + noise(p.y))) / 2.0 - 2.0;

    return Surface(d, mat);
}

Surface SDFplane(vec3 p, Material mat) // Flat
{
    float d = p.y + 1.0;
    return Surface(d, mat);
}

Surface SDFsphere(vec3 p, float radius, vec3 move, Material mat)
{
    float d = length(p - move) - radius;
    float amplitude = 0.65;
    float frequency = 0.15;
    const int octaves = 6;
    float lacunarity = 2.0;
    float gain = 0.65;

    return Surface(d, mat);
}


Surface minObjectDistance(Surface obj1, Surface obj2)
{
    if (obj1.sd < obj2.sd)
        return obj1;
    return obj2;
}

Surface map(vec3 p)
{
    Material Colorb;
    Surface d;
    Surface sphere = SDFsphere(p, 2.0, vec3(0.0, 2.0, -15.0), BurntCopper());
    //Surface balls = minObjectDistance(sphere, box);

    return minObjectDistance(sphere, SDFfloor(p, BurntCopper())); //Checkerboard(p) 
}

//----------Normals----------//
vec3 calcNormal(vec3 p)
{
    vec2 e = vec2(1.0, -1.0) * 0.0001;
    return normalize(e.xyy * map(p + e.xyy).sd +
        e.yyx * map(p + e.yyx).sd +
        e.yxy * map(p + e.yxy).sd +
        e.xxx * map(p + e.xxx).sd);
}

//----------Ray Marching Methods----------//
Surface rayMarch(vec3 ro, vec3 rd)
{
    float depth = nearPlane; //Starting depth
    Surface d;

    for (int i = 0; i < MAX_RAYMARCH_STEPS; i++)
    {
        d = map(ro + rd * depth); // Calculates the SDF
        depth += d.sd;// adds the SDF to the length of the ray

        if (d.sd < nearPlane || depth > farPlane)
            break;
    }
    d.sd = depth;
    return d;
}

float softShadow(vec3 fragPos, vec3 lightPos)
{
    float res = 1.0;
    float depth = 0.01; //Artifacts appear if you start lower
    vec3 lightDir = normalize(lightPos - fragPos);

    for (int i = 0; i < MAX_RAYMARCH_STEPS; i++)
    {
        float d = map(fragPos + lightDir * depth).sd;
        res = min(res, (d * 3.0) / depth);
        depth += d;

        if (d < nearPlane || depth > farPlane) //the lower limit of "d" needs to be lower than the one in the rayMarch function to avoid having a streak of light on overlapping shadows.
            break;
    }
    return clamp(res, 0.02, 1.0); //clamps the res value between nonzero numbers so it doesn't black out everything
}

float AmbientOcclusion(vec3 fragPos, vec3 normal)
{
    float occ = 0.0;
    float weight = 1.0;
    for (int i = 0; i < 8; i++)
    {
        float len = 0.01 + 0.02 * float(i * i);
        vec3 p = fragPos + normal * len;
        float dist = map(p).sd;
        occ += (len - dist) * weight;
        weight *= 0.85;
    }
    return 1.0 - clamp(0.6 * occ, 0.0, 1.0);
}

//----------BRDF (Blinn Phong)----------//
vec3 BlinnPhong(vec3 normal, vec3 lightPos, vec3 fragPos, Material mat)
{ 
    //ambient
    float occ = AmbientOcclusion(fragPos, normal);
    vec3 ambient = mat.ambientCol;
    //return vec3(0.9) * occ; //Occlusion test
    
    //diffuse
    vec3 lightDir = normalize(lightPos - fragPos);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * mat.diffCol;
    
    //specular with normalization
    vec3 reflectDir = reflect(-lightDir, normal);
    vec3 viewDir = normalize(camera - fragPos);
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float spec = max(dot(normal, halfwayDir), 0.0);
    spec = pow(spec, mat.alpha) * ((mat.alpha + 2.0) / (4.0 * PI * (2.0 - exp(-mat.alpha/2.0))));
    vec3 specular = spec * mat.specCol;
    
    //phong
    return (ambient*occ + diffuse + specular*occ);
}

vec3 reflectBP(vec3 normal, vec3 lightPos, vec3 fragPos, Material mat, vec3 reflectDir)
{
    //ambient
    vec3 ambient = mat.ambientCol;
    
    //diffuse
    vec3 lightDir = normalize(lightPos - fragPos);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * mat.diffCol;
    
    //specular with normalization
    vec3 viewDir = normalize(camera - fragPos);
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float spec = max(dot(reflectDir, halfwayDir), 0.0);
    spec = pow(spec, mat.alpha) * ((mat.alpha + 2.0) / (4.0 * PI * (2.0 - exp(-mat.alpha/2.0))));
    vec3 specular = spec * mat.specCol;
    
    return ambient + diffuse + specular;
}

//----------Anti-Aliasing----------//
// Takes four evenly spaced rotated supersamples in each pixel
vec2 RGSS(int num)
{
    if (num == 0) return vec2(0.125, 0.375);
    if (num == 1) return vec2(-0.125, -0.375);
    if (num == 2) return vec2(0.375, -0.125);
    else return vec2(-0.375, 0.125);
}

float dielectricFresnel(vec3 normal, vec3 rd, Material object)
{
    float NdotV = dot(normal, -rd);
    float fresnel = clamp(pow(1.0 - NdotV, 5.0), 0.005, 1.0);
    float k = pow(1.0 - object.ior, 2.0) / pow(1.0 + object.ior, 2.0);
    fresnel += (1.0 - fresnel) * k;
    fresnel = fresnel + (1.0 - fresnel) * pow(NdotV, 5.0) * pow(1.0 - object.gloss, 2.0);
    return fresnel;
}

void main()
{
    vec3 background;
    Surface d;
    int i;

    for (i = 0; i < 1; i++)
    {
        vec2 uv = ((fragCoord + RGSS(i)) - 0.5 * iResolution.xy) / iResolution.y; //aspect ratio       
        vec3 rd = normalize(vec3(uv, -1.0)); //Turns the uv into a 3D vector by making it point outwards
        background = mix(vec3(0.9, 0.65, 0.55), vec3(0.65, 0.85, 1.0), uv.y + 0.25);

        //background = vec3(0.0);

        d = rayMarch(camera, rd);
        Material shine = d.mat;
        float attenuation = 1.0 / (attConst + attLinear * d.sd + attQuad * d.sd * d.sd); //inverse square law
        vec3 fragPos = camera + rd * d.sd;
        vec3 normal = vec3(calcNormal(fragPos));
        vec3 reflectDir = reflect(rd, normal);
        vec3 lightPos = vec3(10.0 * cos(iTime * 0.5), 10.0, 10.0 * sin(iTime * 0.5) - 5.0);

        if (d.sd <= farPlane)
        {
            float fresnel = dielectricFresnel(normal, rd, d.mat);
            vec3 ref = fragPos + normal * 0.005;   
            
            //Reflections - Adds the reflections to the colors before running through the BRDF
            for (int i = 0; i < 1; i++)
            {
                Surface bounce = rayMarch(ref, reflectDir);
                if (bounce.sd <= farPlane)
                    shine = Material(shine.ambientCol + bounce.mat.ambientCol * fresnel, 
                            shine.diffCol + bounce.mat.diffCol * fresnel, 
                            shine.specCol + bounce.mat.specCol * fresnel, 
                            shine.alpha, 
                            shine.gloss, 
                            shine.ior);

                else
                    shine = Material(shine.ambientCol + background * fresnel, 
                            shine.diffCol + background * fresnel, 
                            shine.specCol + background * fresnel, 
                            shine.alpha, 
                            shine.gloss, 
                            shine.ior);                   
            
            }
            
            //Blinn-Phong + softshadows
            vec3 b_phong = BlinnPhong(normal, lightPos, fragPos, shine);
            float softShadow = softShadow(fragPos + normal * 0.003, lightPos);
            col += b_phong * softShadow * attenuation ;            
        }
        else col += background; //Rays go into the v o i d ~
    }

    col /= float(i);
    col = mix(col, background, 1.0 - exp(-0.00001 * d.sd * d.sd * d.sd)); //fog
    FragColor.rgb = pow(col.rgb, vec3(1.0 / GAMMA));
} 