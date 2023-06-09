//
//  Shader.metal
//  MetalMeshShaders
//
//  Created by Dayo Banjo on 3/21/23.
//
#include <metal_stdlib>
using namespace metal;

constexpr constant uint kMaxVerticesPerMeshlet = 256;
constexpr constant uint kMaxTrianglesPerMeshlet = 512;
constexpr constant uint kMeshletsPerObject = 16;

struct Vertex {
    packed_float3 position;
  packed_float3 normal;
    packed_float2 texCoords;
};

struct InstanceData {
    float4x4 modelViewProjectionMatrix;
    float4x4 inverseModelViewMatrix;
    float4x4 normalMatrix;
};

struct MeshletVertex {
    float4 position [[position]];
    float3 normal;
    float2 texCoords;
};

struct MeshletPrimitive {
    float4 color [[flat]];
};

struct MeshletDescriptor {
    uint vertexOffset;
    uint vertexCount;
    uint triangleOffset;
    uint triangleCount;
    packed_float3 boundsCenter;
    float boundsRadius;
    packed_float3 coneApex;
    packed_float3 coneAxis;
    float coneCutoff, pad;
};

struct ObjectPayload {
    uint meshletIndices[kMeshletsPerObject];
};

struct Constants {
    float animatedBy;
    float2 resolution;
};

/// Extracts the six frustum planes determined by the provided matrix.
/// The matrix can be a perspective projection matrix, or some combination of
/// projection, view, and model matrices; the planes will be in the space the
/// matrix transforms from.
static void extract_frustum_planes(constant float4x4 &matrix, thread float4 *planes) {
    float4x4 mt = transpose(matrix);
    planes[0] = mt[3] + mt[0]; // left
    planes[1] = mt[3] - mt[0]; // right
    planes[2] = mt[3] - mt[1]; // top
    planes[3] = mt[3] + mt[1]; // bottom
    planes[4] = mt[2];         // near
    planes[5] = mt[3] - mt[2]; // far
}

static bool sphere_intersects_frustum(thread float4 *planes, float3 center, float radius) {
    for(int i = 0; i < 6; ++i) {
        float D = dot(center, planes[i].xyz) + planes[i].w + radius;
        if (D < 0) {
            return false;
        }
    }
    return true;
}

static bool cone_is_backfacing(float3 coneApex, float3 coneAxis, float coneCutoff, float3 cameraPosition) {
    return (dot(normalize(coneApex - cameraPosition), coneAxis) >= coneCutoff);
}


static float3 hue2rgb(float hue) {
    hue = fract(hue); //only use fractional part of hue, making it loop
    float r = abs(hue * 0.5) - 1; 
    float g = 1 - abs(hue * 0.4); 
    float b = 1 - abs(hue * 0.2); 
    float3 rgb = float3(r,g,b); //combine components
    rgb = saturate(rgb); //clamp between 0 and 1
    return rgb;
}

[[object, max_total_threadgroups_per_mesh_grid(kMeshletsPerObject)]]
void object_main(device const MeshletDescriptor *meshlets [[buffer(0)]],
                 constant InstanceData &instance          [[buffer(1)]],
                 uint meshletIndex          [[thread_position_in_grid]],
                 uint threadIndex    [[thread_position_in_threadgroup]],
                 object_data ObjectPayload &outObject       [[payload]],
                 mesh_grid_properties outGrid)
{
    // Look up the meshlet this thread will determine the visibility of
    device const MeshletDescriptor &meshlet = meshlets[meshletIndex];
    
    // Perform culling tests and determine if our meshlet is potentially visible
    float4 frustumPlanes[6];
    extract_frustum_planes(instance.modelViewProjectionMatrix, frustumPlanes);
    bool frustumCulled = !sphere_intersects_frustum(frustumPlanes, meshlet.boundsCenter, meshlet.boundsRadius);
    
    float3 cameraPosition = (instance.inverseModelViewMatrix * float4(0.0f, 0.0f, 0.0f, 1.0f)).xyz;
    bool normalConeCulled = cone_is_backfacing(meshlet.coneApex, meshlet.coneAxis, meshlet.coneCutoff, cameraPosition);
    
    int passed = (!frustumCulled && !normalConeCulled) ? 1 : 0;
    
    // Perform a prefix scan to determine the number of meshlets not culled by lower-indexed threads
    // in our SIMDgroup, which tells us which payload index to write our meshlet index into iff it passed.
    int payloadIndex = simd_prefix_exclusive_sum(passed);
    
    if (passed) {
        // Our meshlet passed its culling tests, so write it into the payload
        outObject.meshletIndices[payloadIndex] = meshletIndex;
    }
    
    // If we are the first thread in our object, it is our responsibility to launch
    // a mesh shader grid for each potentially visible meshlet.
    uint visibleMeshletCount = simd_sum(passed);
    if (threadIndex == 0) {
        // The mesh threadgroup count is the number of potentially visible meshlets spawned by this object
        outGrid.set_threadgroups_per_grid(uint3(visibleMeshletCount, 1, 1));
    }
}

using Meshlet = metal::mesh<MeshletVertex, MeshletPrimitive, kMaxVerticesPerMeshlet, kMaxTrianglesPerMeshlet, topology::triangle>;

[[mesh]]
void mesh_main(object_data ObjectPayload const& object   [[payload]],
               device const Vertex *meshVertices       [[buffer(0)]],
               constant MeshletDescriptor *meshlets    [[buffer(1)]],
               constant uint *meshletVertices          [[buffer(2)]],
               constant uchar *meshletTriangles        [[buffer(3)]],
               constant InstanceData &instance         [[buffer(4)]],
               uint payloadIndex    [[threadgroup_position_in_grid]],
               uint threadIndex   [[thread_position_in_threadgroup]],
               Meshlet outMesh)
{
    uint meshletIndex = object.meshletIndices[payloadIndex];
    constant MeshletDescriptor &meshlet = meshlets[meshletIndex];
    
    if (threadIndex < meshlet.vertexCount) {
        device const Vertex &meshVertex = meshVertices[meshletVertices[meshlet.vertexOffset + threadIndex]];
        MeshletVertex v;
        v.position = instance.modelViewProjectionMatrix * float4(meshVertex.position, 1.0f);
        v.normal = (instance.normalMatrix * float4(meshVertex.normal, 0.0f)).xyz; // view-space normal
        v.texCoords = meshVertex.texCoords;
        outMesh.set_vertex(threadIndex, v);
    }
    
    if (threadIndex < meshlet.triangleCount) {
        uint i = threadIndex * 3;
        outMesh.set_index(i + 0, meshletTriangles[meshlet.triangleOffset + i + 0]);
        outMesh.set_index(i + 1, meshletTriangles[meshlet.triangleOffset + i + 1]);
        outMesh.set_index(i + 2, meshletTriangles[meshlet.triangleOffset + i + 2]);
        
        MeshletPrimitive prim = {
            // Map meshlet indices to widely-spaced values around the color wheel
            // to give each meshlet a pseudo-random color
            .color = float4(hue2rgb(meshletIndex * 1.71f), 1)
        };
        outMesh.set_primitive(threadIndex, prim);
    }
    
    if (threadIndex == 0) {
        outMesh.set_primitive_count(meshlet.triangleCount);
    }
}

struct FragmentIn {
    MeshletVertex vert;
    MeshletPrimitive prim;
};

float rand(float seed) {
    float t = fract(sin(seed) * 43758.5453123);
    return t;
}

[[fragment]]
float4 fragment_main(FragmentIn in [[stage_in]],device const Constants &constants        [[buffer(5)]]) {
    float4 color = in.prim.color;

    float3 N = normalize(in.vert.normal);
    float3 L = normalize(float3(1, 1, 1));

    float ambientIntensity = 0.1f;
    float diffuseIntensity = saturate(dot(L, N));
    float4 color_ =  float4(color.rgb * saturate(ambientIntensity + diffuseIntensity), 1.0f);
    return color_;
}


