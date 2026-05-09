#ifndef VERTEX_CGINC
#define VERTEX_CGINC

// ============================================================================
// Vertex.cginc
//
// Shared vertex stage: Appdata, V2F interpolant struct, vert main, and the
// per-triangle debug-clip distance computation.  All 16 passes share this
// pipeline; per-pass differences come in via ZONE_BIT / BIOME_MASK / etc.
// ============================================================================

#include "Common.cginc"

struct Appdata
{
    float3 position    : POSITION;
    float3 normal      : NORMAL;
    float4 tangent     : TANGENT;
    float2 uv          : TEXCOORD;
    uint   vertexIndex : SV_VertexID;
};

int _DebugBiomeMask;
int _DebugTriplanarBucketing;
Buffer<uint> BucketedQuadInfoDecalIndices;
Buffer<uint> VisibleQuadMeshIndicesMask;

// ---------------------------------------------------------------------------
// Debug clip-distance computation
// ---------------------------------------------------------------------------
// Evaluates per-triangle debug flags from a flag buffer and returns +1.0 if
// the triangle passes all mask tests, or -1.0 (clip) if any fail.
// zoneBitMask: the bit(s) that must be set for the zone test (e.g. 1u << 29).
float ComputeDebugClipDistance(uint flags)
{
    float clip = 1.0;

#ifdef ZONE_BIT
    if ((flags & (1 << ZONE_BIT)) == 0u)
        clip = -1.0;
#endif

#if BIOME_MASK
    if ((flags & asuint(_DebugBiomeMask) & BIOME_MASK) == 0u)
        clip = -1.0;
#else
    if ((flags & asuint(_DebugBiomeMask)) == 0u)
        clip = -1.0;
#endif

#ifdef PASS_DEFERRED_BIOME
    #ifdef ADDITIVE_BIOME
        if ((flags & asuint(_DebugTriplanarBucketing) & TRIPLANAR_BUCKET_ADDITIVE) == 0u)
            clip = -1.0;
    #else
        if ((flags & asuint(_DebugTriplanarBucketing) & TRIPLANAR_BUCKET_NONADD) == 0u)
            clip = -1.0;
    #endif
#else
    if ((flags & asuint(_DebugTriplanarBucketing) & TRIPLANAR_BUCKET_MASK) == 0u)
        clip = -1.0;
#endif

    return clip;
}

struct V2F
{
    float4 clipPos          : SV_Position;
    float  clip             : SV_ClipDistance0;

#ifndef PASS_DEPTH
    float3 uvHeight         : TEXCOORD0; // .xy = UV, .z = height
    float4 worldNormalPosX  : TEXCOORD1; // .xyz = worldNormal,  .w = pos.x
    float4 bitangentPosY    : TEXCOORD2; // .xyz = bitangent,    .w = pos.y
    float4 worldTangentPosZ : TEXCOORD3; // .xyz = worldTangent, .w = pos.z
    float3 objectNormal     : TEXCOORD5;
#ifdef DECAL_MODE_PACKED4
    nointerpolation
    uint triangleData       : TEXCOORD6;
#endif
    float3 screenPos        : TEXCOORD7;
#ifdef PASS_DEFERRED
    float3 lighting         : TEXCOORD8;
#endif
#endif
};

// Triangle-data accessor used by Decals.cginc::ApplyDecals.  The interpolant
// only exists for PACKED4 (real bandwidth cost); other modes pass 0u and
// ApplyDecals ignores the arg.
#ifdef DECAL_MODE_PACKED4
    #define V2F_TRIANGLE_DATA(i) ((i).triangleData)
#else
    #define V2F_TRIANGLE_DATA(i) (0u)
#endif

V2F vert(Appdata input)
{
    uint triIndex  = input.vertexIndex / 3;
    uint quadIndex = VisibleQuadMeshIndices.Load(input.vertexIndex);

    uint flags     = VisibleQuadMeshIndicesMask.Load(input.vertexIndex / 3u);

    QuadMeshData q = GetQuadMeshData(quadIndex);

    V2F o;
    o.clipPos = mul(unity_MatrixVP, float4(q.position, 1.0));
    o.clip    = ComputeDebugClipDistance(flags);

#ifndef PASS_DEPTH
    WorldTBN tbn   = BuildWorldTBN(q);

    o.uvHeight          = float3(q.uv, q.height.w);
    o.worldNormalPosX   = float4(tbn.worldNormal,   q.position.x);
    o.bitangentPosY     = float4(tbn.bitangent,     q.position.y);
    o.worldTangentPosZ  = float4(tbn.worldTangent,  q.position.z);
    o.objectNormal      = q.normal;
    o.screenPos         = ComputeScreenPos(o.clipPos).xyw;

#ifdef DECAL_MODE_PACKED4
    o.triangleData      = BucketedQuadInfoDecalIndices.Load(triIndex);
#endif

#ifdef PASS_DEFERRED
    o.lighting          = SHEvalLinearL2(float4(tbn.worldTangent, 1.0));
#endif

#endif // PASS_DEPTH

    return o;
}

#endif // VERTEX_CGINC
