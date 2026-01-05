#include <metal_stdlib>
using namespace metal;

// -------------------------------------------------------------------------
// CONSTANTS & DEFINITIONS
// -------------------------------------------------------------------------
constant float PI = 3.14159265359;
constant float MAX_FLOAT = 3.402823466e+38;
constant float MIN_FLOAT = -3.402823466e+38;
constant int MAX_NUM_SPHERES = 7;
constant int MAX_STACK_SIZE = 64;

// -------------------------------------------------------------------------
// STRUCTURES
// -------------------------------------------------------------------------
struct LinearBVHNode {
    int rightChild;
    int triangleStartID;
    int triangleCount;
    // Padding logic: Metal arrays are tightly packed usually, but GLSL std430 aligns array elements
    // float[3] is tricky in structs. Using packed_float3 or float3 with padding is safer.
    // Assuming the C++ layout matches float3 aabbMin; float _pad1; float3 aabbMax; float _pad2;
    packed_float3 aabbMin; 
    float _pad1;
    packed_float3 aabbMax;
    float _pad2;
};

struct RTTriangles {
    packed_float3 v0; float _pad0;
    packed_float3 v1; float _pad1;
    packed_float3 v2; float _pad2;

    packed_float3 n0; float _pad3;
    packed_float3 n1; float _pad4;
    packed_float3 n2; float _pad5;

    packed_float2 uv0; 
    packed_float2 uv1; 
    packed_float2 uv2; 
    float2 _pad6; // To align to 8 bytes or 16 depending on packing

    // Bindless handles in Metal are usually resident resource IDs or indices into an argument buffer
    // For direct port, passing texture arrays is better, but here we keep uint64_t placeholders
    ulong tex_albedo; 
    ulong tex_roughness; 

    int materialID;
    int _pad7[3]; // Pad to 16 bytes alignment if necessary
};

struct Material {
    float4 color;
    float roughness;
    float metalness;
    float emissive_strength;
    float _pad0; // Alignment
    float4 emissive_col;
};

struct Ray {
    float3 origin;
    float3 dir;
};

struct HitInfo {
    bool isHit;
    float HitDist;
    float3 HitPos;
    float3 Normal;
    bool isEmitter;
    Material material;
};

struct Light {
    float3 emission_color;
    float emission_strength;
    float3 position;    
    float3 u;
    float3 v;
};

struct LightInfo {
    float3 emission_color;
    float3 normal;
    float emission_strength;
    float area;
    float3 direction;
    float LightDist;
    float pdf;
};

struct BRDFInformation {
    float3 totalBRDF;
    float brdfPDF;
    float3 reflectionDir;
};

struct Uniforms {
    int BVHNodeSize;
    int frame_num;
    int sample_count;
    float focal_length;
    float time;
    float3 camera_pos;
    float3 camera_viewdir;
    float3 light_dir;
    float light_intensity;
    int num_bounces;
    int samplesPerPixel;
    float3 LightPos;
    float u_LightStrength;
    float4x4 mat_view;
    float4x4 mat_proj;
    int EnvironmentEnabled;
    int TileIndex_X;
    int TileIndex_Y;
    float u_ImageWidth;
    float u_ImageHeight;
};

// -------------------------------------------------------------------------
// RANDOM NUMBER GENERATOR
// -------------------------------------------------------------------------
struct RandomState {
    uint4 seed;
};

void pcg4d(thread uint4& v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
    v = v ^ (v >> 16u);
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
}

float random(thread RandomState& rng) {
    pcg4d(rng.seed);
    return float(rng.seed.x) / float(0xffffffffu);
}

// -------------------------------------------------------------------------
// HELPER FUNCTIONS
// -------------------------------------------------------------------------
float3 randomDirInSphere(float3 normal, float alpha, thread RandomState& rng) {
    float cosTheta = pow(random(rng), 1.0f / (alpha + 1.0f));
    float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
    float phi = 2.0f * PI * random(rng);
    float3 tangentSpaceDir = float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);

    float3 up = abs(normal.x) > 0.99f ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent = normalize(cross(normal, up));
    float3 bitangent = cross(normal, tangent);

    return normalize(float3x3(tangent, bitangent, normal) * tangentSpaceDir);
}

float3 ImportanceSamplingGGX(float3 N, float roughness, thread RandomState& rng) {
    float a2 = roughness * roughness;
    float r1 = random(rng);
    float r2 = random(rng);
    float phi = 2.0 * PI * r1;
    float cosTheta = sqrt((1.0 - r2) / (1.0 + (a2 * a2 - 1.0) * r2));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;

    float3 up = abs(N.x) > 0.99f ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);

    return normalize(float3x3(tangent, bitangent, N) * H);
}

float ImportanceSampleGGX_PDF(float NDF, float NdotH, float VdotH) {
    return NDF * NdotH / (4.0f * VdotH);
}

float CosinSamplingPDF(float NdotL) {
    return NdotL / PI;
}

float3 GetEnvironmentLight(Ray ray, constant Uniforms& u) {
    if (u.EnvironmentEnabled == 0) return float3(0.0f);
    
    float4 GroundColour = float4(0.664f, 0.887f, 1.000f, 1.000f);
    float4 SkyColourHorizon = float4(1.0, 1.0, 1.0, 1.0);
    float4 SkyColourZenith = float4(0.1, 0.4, 0.89, 1.0);
    float SunFocus = 20.0;
    
    float skyGradientT = pow(smoothstep(0.0, 0.8, ray.dir.y), 0.35);
    float groundToSkyT = smoothstep(-0.01, 0.0, ray.dir.y);
    float3 skyGradient = mix(SkyColourHorizon.rgb, SkyColourZenith.rgb, skyGradientT);
    float sun = pow(max(0.0, dot(ray.dir, -u.light_dir)), SunFocus) * u.light_intensity;
    
    return mix(GroundColour.rgb, skyGradient, groundToSkyT) + sun * (groundToSkyT >= 1.0 ? 1.0 : 0.0);
}

float intersectQuad(Ray ray, float3 u, float3 v, float3 normal, float3 QuadPos) {
    float denom = dot(ray.dir, normal);
    float t = dot((QuadPos - ray.origin), normal) / denom;
    
    if (t > 0.0003f) {
        float3 pointInPlane = ray.origin + t * ray.dir;
        float3 vi = (pointInPlane - QuadPos);
        float a1 = dot(vi, normalize(u));
        if (a1 >= 0.0f && a1 <= length(u)) {
            float a2 = dot(vi, normalize(v));
            if (a2 >= 0.0f && a2 <= length(v)) {
                return t;
            }
        }
    }
    return MAX_FLOAT;
}

bool intersectAABB(float3 aabbMin, float3 aabbMax, float t, Ray ray) {
    float3 invDir = 1.0 / ray.dir;
    float3 t1 = (aabbMin - ray.origin) * invDir;
    float3 t2 = (aabbMax - ray.origin) * invDir;
    
    float3 tmin = min(t1, t2);
    float3 tmax = max(t1, t2);
    
    float t_min = max(max(tmin.x, tmin.y), tmin.z);
    float t_max = min(min(tmax.x, tmax.y), tmax.z);
    
    return t_max >= t_min && t_min < t && t_max > 0;
}

int intersectTriangle(float3 v0, float3 v1, float3 v2, thread float& t, thread float& u, thread float& v, Ray ray) {
    float3 edge1 = v1 - v0;
    float3 edge2 = v2 - v0;
    float3 h = cross(ray.dir, edge2);
    float a = dot(edge1, h);
    
    if (a > -0.0001f && a < 0.0001f) return 0;
    
    float f = 1.0 / a;
    float3 s = ray.origin - v0;
    u = f * dot(s, h);
    if (u < 0.0 || u > 1.0) return 0;
    
    float3 q = cross(s, edge1);
    v = f * dot(ray.dir, q);
    if (v < 0.0 || u + v > 1.0) return 0;
    
    float p = f * dot(edge2, q);
    if (p > 0.0001f) {
        t = min(p, t);
        return 1;
    }
    return 0;
}

bool AnyHit(Ray ray, float range, int numLights, thread Light* lights,
            device LinearBVHNode* arrLinearBVHNode,
            device RTTriangles* arrRTTriangles,
            device int* triIndices) 
{
    float t = range;
    
    // Check Lights (Quad Area Lights)
    for (int k = 0; k < numLights; k++) {
        Light light = lights[k];
        float3 light_normal = cross(light.u, light.v);
        float light_area = length(light_normal);
        light_normal /= light_area;
        if (dot(light_normal, ray.dir) > 0.0) continue;

        float p = intersectQuad(ray, light.u, light.v, light_normal, light.position);
        if (p < t) return true;
    }

    // BVH Traversal (Stack-based)
    int i = 0;
    int toVisit = 0;
    int nodesToVisit[MAX_STACK_SIZE];

    while (true) {
        LinearBVHNode node = arrLinearBVHNode[i];
        if (intersectAABB(node.aabbMin, node.aabbMax, t, ray)) {
            if (node.triangleCount > 0) { // Leaf
                for (int k = 0; k < node.triangleCount; k++) {
                    int triIdx = triIndices[k + node.triangleStartID];
                    RTTriangles triangle = arrRTTriangles[triIdx];
                    
                    float p = MAX_FLOAT;
                    float u_0, v_0;
                    if (intersectTriangle(triangle.v0, triangle.v1, triangle.v2, p, u_0, v_0, ray) > 0 && p < t) {
                        return true;
                    }
                }
                if (toVisit == 0) break;
                i = nodesToVisit[--toVisit];
            } else { // Internal
                nodesToVisit[toVisit++] = node.rightChild;
                i = i + 1; // Left child is implicitly next in array
            }
        } else {
            if (toVisit == 0) break;
            i = nodesToVisit[--toVisit];
        }
    }
    return false;
}

HitInfo ClosestHit(Ray ray, thread LightInfo& light_info, int numLights, thread Light* lights,
                   device LinearBVHNode* arrLinearBVHNode,
                   device RTTriangles* arrRTTriangles,
                   device int* triIndices,
                   device Material* arrMaterials)
{
    HitInfo info;
    info.isHit = false;
    float t = MAX_FLOAT;
    int i = 0;
    int toVisit = 0;
    int nodesToVisit[MAX_STACK_SIZE];
    float u, v;
    RTTriangles nearestTriangle;
    
    // Check Lights
    for (int k = 0; k < numLights; k++) {
        Light light = lights[k];
        float3 light_normal = cross(light.u, light.v);
        float light_area = length(light_normal);
        light_normal /= light_area;
        if (dot(light_normal, ray.dir) > 0.0) continue;

        float p = intersectQuad(ray, light.u, light.v, light_normal, light.position);
        if (p < t) {
            t = p;
            info.isEmitter = true;
            light_info.pdf = t * t / (light_area * abs(dot(-ray.dir, light_normal)));
            light_info.emission_color = light.emission_color;
            light_info.emission_strength = light.emission_strength;
        }
    }

    // BVH Traversal
    while (true) {
        LinearBVHNode node = arrLinearBVHNode[i];
        if (intersectAABB(node.aabbMin, node.aabbMax, t, ray)) {
            if (node.triangleCount > 0) {
                for (int k = 0; k < node.triangleCount; k++) {
                    int triIdx = triIndices[k + node.triangleStartID];
                    RTTriangles triangle = arrRTTriangles[triIdx];
                    
                    float p = MAX_FLOAT;
                    float u_0, v_0;
                    if (intersectTriangle(triangle.v0, triangle.v1, triangle.v2, p, u_0, v_0, ray) > 0 && p < t) {
                        t = p;
                        u = u_0;
                        v = v_0;
                        nearestTriangle = triangle;
                        info.isEmitter = false;
                    }
                }
                if (toVisit == 0) break;
                i = nodesToVisit[--toVisit];
            } else {
                nodesToVisit[toVisit++] = node.rightChild;
                i = i + 1;
            }
        } else {
            if (toVisit == 0) break;
            i = nodesToVisit[--toVisit];
        }
    }

    info.HitDist = t;
    info.isHit = (t != MAX_FLOAT);
    info.HitPos = ray.origin + t * ray.dir;
    
    if (info.isHit && !info.isEmitter) {
        info.material = arrMaterials[nearestTriangle.materialID];
        
        // Barycentric interpolation for Normal
        float3 n0 = nearestTriangle.n0;
        float3 n1 = nearestTriangle.n1;
        float3 n2 = nearestTriangle.n2;
        info.Normal = normalize(n1 * u + n2 * v + n0 * (1.0 - u - v));
        
        // (Texture fetching would go here using nearestTriangle.uv0/1/2 and bindless handles)
    }
    
    return info;
}

// -------------------------------------------------------------------------
// PBR & BRDF
// -------------------------------------------------------------------------
float NormalDistribution_GGX(float NdotH, float alpha) {
    float alpha2 = pow(alpha, 4.0);
    float denom = (pow(NdotH, 2.0) * (alpha2 - 1.0) + 1.0);
    return alpha2 / (PI * denom * denom);
}

float Geometry_GGX(float dp, float alpha) {
    float k = pow(alpha + 1.0, 2.0) / 8.0;
    return dp / (dp * (1.0 - k) + k);
}

float3 Fresnel(float VdotH) {
    float3 F0 = float3(0.04);
    return F0 + (float3(1.0) - F0) * pow(1.0 - VdotH, 5.0);
}

float3 SpecularBRDF(float Dggx, float Gggx, float3 fresnel, float NdotV, float NdotL) {
    float denominator = 4.0 * NdotL * NdotV;
    return (Dggx * Gggx * fresnel) / max(denominator, 0.001);
}

BRDFInformation EvalBRDF(HitInfo info, float3 V, float3 L) {
    float alpha = info.material.roughness;
    BRDFInformation brdf_info;
    
    float diffuseRatio = 0.5f * (1.0f - info.material.metalness);
    float specularRatio = 1.0f - diffuseRatio;

    float3 H = normalize(V + L);
    float NdotL = max(dot(info.Normal, L), 0.001);
    float NdotH = max(dot(info.Normal, H), 0.001);
    float VdotH = max(dot(V, H), 0.001);
    float NdotV = max(dot(info.Normal, V), 0.001);

    float3 F0 = info.material.metalness > 0.0 ? float3(0.8) : float3(0.04);
    F0 = mix(F0, info.material.color.rgb, info.material.metalness);

    float Dggx = NormalDistribution_GGX(NdotH, alpha);
    float Gggx = Geometry_GGX(NdotV, alpha) * Geometry_GGX(NdotL, alpha);
    float3 fresnel = Fresnel(VdotH);
    float3 ks = fresnel;
    float3 kd = (float3(1.0) - ks) * (1.0f - info.material.metalness);

    float specularPDF = ImportanceSampleGGX_PDF(Dggx, NdotH, VdotH);
    float diffusePDF = CosinSamplingPDF(NdotL);
    brdf_info.brdfPDF = diffusePDF * diffuseRatio + specularPDF * specularRatio;

    float3 specularBRDF = SpecularBRDF(Dggx, Gggx, fresnel, NdotV, NdotL);
    float3 diffuseBRDF = info.material.color.rgb / PI;
    brdf_info.totalBRDF = (kd * diffuseBRDF + specularBRDF) * NdotL;

    return brdf_info;
}

BRDFInformation CalcBRDF(HitInfo info, float3 V, thread RandomState& rng) {
    float alpha = info.material.roughness;
    BRDFInformation brdf_info;
    float roulette = random(rng);
    float diffuseRatio = 0.5f * (1.0f - info.material.metalness);
    
    if (roulette < diffuseRatio) {
        brdf_info.reflectionDir = randomDirInSphere(info.Normal, 1.0f, rng);
    } else {
        float3 halfVec = ImportanceSamplingGGX(info.Normal, alpha, rng);
        brdf_info.reflectionDir = -normalize(reflect(V, halfVec));
    }
    
    float3 L = brdf_info.reflectionDir;
    BRDFInformation eval = EvalBRDF(info, V, L);
    brdf_info.totalBRDF = eval.totalBRDF;
    brdf_info.brdfPDF = eval.brdfPDF;
    
    return brdf_info;
}

float3 DirectLight(HitInfo hit_info, Ray ray, int numLights, thread Light* lights, thread RandomState& rng,
                   device LinearBVHNode* arrLinearBVHNode,
                   device RTTriangles* arrRTTriangles,
                   device int* triIndices) 
{
    int index = int(clamp(random(rng), 0.0, 0.9999f) * float(numLights));
    Light light = lights[index];
    LightInfo light_info;

    float3 scatterPos = hit_info.HitPos + hit_info.Normal * 0.0001;
    float r1 = random(rng);
    float r2 = random(rng);

    float3 lightSurfacePos = light.position + light.u * r1 + light.v * r2;
    light_info.direction = lightSurfacePos - scatterPos;
    light_info.LightDist = length(light_info.direction);
    float distSq = light_info.LightDist * light_info.LightDist;
    light_info.direction /= light_info.LightDist;
    light_info.normal = normalize(cross(light.u, light.v));
    light_info.area = length(cross(light.u, light.v));
    
    light_info.pdf = distSq / (light_info.area * abs(dot(light_info.normal, light_info.direction)));
    float3 Li = light.emission_color * light.emission_strength;
    float3 Ld = float3(0.0);

    if (dot(light_info.direction, light_info.normal) < 0.0) {
        Ray shadowRay; shadowRay.origin = scatterPos; shadowRay.dir = light_info.direction;
        if (!AnyHit(shadowRay, light_info.LightDist - 0.003, numLights, lights, arrLinearBVHNode, arrRTTriangles, triIndices)) {
            float misweight = 1.0;
            BRDFInformation brdf_info = EvalBRDF(hit_info, -ray.dir, light_info.direction);
            
            if (light_info.area > 0.0) {
                misweight = light_info.pdf * light_info.pdf / (light_info.pdf * light_info.pdf + brdf_info.brdfPDF * brdf_info.brdfPDF);
            }
            if (brdf_info.brdfPDF > 0.0) {
                Ld += misweight * Li * brdf_info.totalBRDF / light_info.pdf;
            }
        }
    }
    return Ld;
}

float3 perPixel(int numBounces, Ray ray, constant Uniforms& u, int numLights, thread Light* lights, thread RandomState& rng,
                device LinearBVHNode* arrLinearBVHNode,
                device RTTriangles* arrRTTriangles,
                device int* triIndices,
                device Material* arrMaterials)
{
    float3 color = float3(1.0);
    float3 incomingLight = float3(0.0);
    LightInfo light_info;
    BRDFInformation brdf_info;
    
    for (int k = 1; k <= numBounces; k++) {
        HitInfo info = ClosestHit(ray, light_info, numLights, lights, arrLinearBVHNode, arrRTTriangles, triIndices, arrMaterials);
        
        if (info.isHit) {
            float3 emittedLight = info.material.emissive_col.rgb * info.material.emissive_strength;
            incomingLight += emittedLight * color;

            if (info.isEmitter) {
                float misweight = 1.0;
                if (k > 1) {
                    misweight = brdf_info.brdfPDF * brdf_info.brdfPDF / (brdf_info.brdfPDF * brdf_info.brdfPDF + light_info.pdf * light_info.pdf);
                }
                incomingLight += misweight * light_info.emission_color * light_info.emission_strength * color;
                break;
            }

            if (random(rng) > info.material.color.a) {
                ray.origin = info.HitPos + ray.dir * 0.003;
                k--; // Doesn't count as a bounce
            } else {
                incomingLight += DirectLight(info, ray, numLights, lights, rng, arrLinearBVHNode, arrRTTriangles, triIndices) * color;
                
                brdf_info = CalcBRDF(info, -ray.dir, rng);
                if (brdf_info.brdfPDF > 0.0f) {
                    color *= brdf_info.totalBRDF / brdf_info.brdfPDF;
                } else {
                    break;
                }
                
                ray.dir = brdf_info.reflectionDir;
                ray.origin = info.HitPos + info.Normal * 0.003;
            }
        } else {
            incomingLight += GetEnvironmentLight(ray, u) * color;
            break;
        }
    }
    return incomingLight;
}

// -------------------------------------------------------------------------
// COMPUTE KERNEL
// -------------------------------------------------------------------------
kernel void compute_main(texture2d<float, access::read_write> FinalImage [[texture(0)]],
                         device LinearBVHNode* arr_LinearBVHNode         [[buffer(2)]],
                         device RTTriangles* arr_RTTriangles             [[buffer(3)]],
                         device int* arr_triIndices                      [[buffer(4)]],
                         device Material* arr_Materials                  [[buffer(5)]],
                         constant Uniforms& u                            [[buffer(6)]],
                         uint2 gid                                       [[thread_position_in_grid]])
{
    RandomState rng;
    rng.seed = uint4(gid.x, gid.y, uint(u.frame_num + u.sample_count), gid.x + gid.y);

    uint2 tile_res = uint2(8, 8) * uint2(u.u_ImageWidth / 8, u.u_ImageHeight / 8); // Simplification of dispatch size
    int2 uv = int2(gid) + int2(tile_res) * int2(u.TileIndex_X, u.TileIndex_Y);
    
    // Safety check
    if (uv.x >= int(u.u_ImageWidth) || uv.y >= int(u.u_ImageHeight)) return;

    float2 coord = float2(uv) / float2(u.u_ImageWidth, u.u_ImageHeight);
    coord = coord * 2.0 - 1.0;
    
    float4 target = u.mat_proj * float4(coord.x, coord.y, 1, 1); // Inverse logic handled in matrix? 
    // Metal matrices are usually passed already inverted if needed, or invert here
    
    Ray ray;
    ray.origin = u.camera_pos;
    ray.dir = normalize((u.mat_view * float4(target.xyz / target.w, 0)).xyz);

    // Setup Lights
    Light lights[1];
    int numLights = 1;
    lights[0].emission_color = float3(1.0);
    lights[0].emission_strength = u.u_LightStrength;
    lights[0].position = u.LightPos;
    lights[0].u = float3(20, 0, 0);
    lights[0].v = float3(0, 0, 20);

    float3 color = float3(0.0);
    for (int i = 0; i < u.samplesPerPixel; i++) {
        color += perPixel(u.num_bounces, ray, u, numLights, lights, rng, 
                          arr_LinearBVHNode, arr_RTTriangles, arr_triIndices, arr_Materials);
    }
    color /= float(u.samplesPerPixel);

    float weight = 1.0f / (float(u.sample_count) + 0.0f); // +1.0f maybe? 
    // Nsample_count usually starts at 0 or 1. GLSL code has +0.0f. Assuming u.sample_count is total accumulated so far
    
    float3 prevColor = FinalImage.read(uint2(uv)).rgb;
    color = color * weight + prevColor * (1.0f - weight);
    color = clamp(color, 0.0, 1.0);
    
    FinalImage.write(float4(color, 1.0), uint2(uv));
}