#ifndef QUADMESHDATA_CGINC
#define QUADMESHDATA_CGINC

// ----------------------------------------------------------------------------
// Quad-mesh streaming vertex system.  PQSRenderer binds these buffers by name
// (Shader.PropertyToID), not by register slot.
// ----------------------------------------------------------------------------
Buffer<float4> QuadMeshDataBuffer;
Buffer<uint>   VisibleQuadMeshIndices;

// Note the swap between `normal` and `tangent` field meanings -- see WorldTBN.cginc.
struct QuadMeshData
{
    float3 position;  // world-space vertex position (already in PQS local)
    float3 normal;    // tangent direction in object space
    float2 uv;        // surface texcoord
    float4 tangent;   // .xyz = geometric normal (object space), .w = bitangent sign
    float4 height;    // .w = scalar height (used by height blending later)
};

QuadMeshData GetQuadMeshData(uint index)
{
    uint base = index * 4u;
    float4 w0 = QuadMeshDataBuffer.Load(base + 0u);
    float4 w1 = QuadMeshDataBuffer.Load(base + 1u);

    QuadMeshData d;
    d.position = w0.xyz;
    d.normal   = float3(w0.w, w1.xy);
    d.uv       = w1.zw;
    d.tangent  = QuadMeshDataBuffer.Load(base + 2u);
    d.height   = QuadMeshDataBuffer.Load(base + 3u);
    return d;
}

#endif
