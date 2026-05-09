#ifndef WORLDTBN_CGINC
#define WORLDTBN_CGINC

#include "UnityCG.cginc"
#include "QuadMeshData.cginc"

float4x4 _PQSToWorld;

// World-space TBN frame derived from the quad-mesh tangent/normal pair.
// Note the apparent swap: the buffer's "tangent" field stores the geometric
// surface normal (post _PQSToWorld) and the "normal" field stores the tangent
// direction.  PQSRenderer fills the buffer this way; do not transpose here.
struct WorldTBN
{
    float3 worldNormal;
    float3 worldTangent;
    float3 bitangent;
};

// Build the world-space TBN frame for a quad-mesh vertex.
WorldTBN BuildWorldTBN(QuadMeshData quad)
{
    WorldTBN tbn;
    tbn.worldNormal  = normalize(mul((float3x3)_PQSToWorld, quad.tangent.xyz));
    tbn.worldTangent = normalize(mul((float3x3)_PQSToWorld, quad.normal));
    tbn.bitangent    = (quad.tangent.w * unity_WorldTransformParams.w)
                     * cross(tbn.worldTangent, tbn.worldNormal);
    return tbn;
}

#endif
