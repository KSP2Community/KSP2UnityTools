#ifndef DECALS_CGINC
#define DECALS_CGINC

// ============================================================================
// Decals.cginc
//
// Decal-application loop run during the prepass.  Up to N decals (4 in
// PACKED4 mode, decalInstanceCount in INFINITE) are projected onto the
// terrain after height-map sampling and before the per-channel LAYER
// expansion, mutating the per-pixel diffs (aux/large/mid) and the running
// world-normal accumulator.
// ============================================================================

#include "Common.cginc"

// HLSL mirror of `Assets/Code/Root/DecalInstance.cs` (49 floats, 196 bytes).
// Field order MUST match the C# struct exactly: it uses Sequential layout and
// PQSRenderer uploads a NativeArray<DecalInstance> directly into a
// StructuredBuffer with no transpose.
struct DecalInstance
{
    float4x4 worldToLocal;        // 16 floats (Unity column-major; HLSL
                                  //   column_major reads identical bytes,
                                  //   so mul(M, v) computes the math product)
    float3   position;             int   index;
    float    clipPos;              float cullDist;
    float    heightScale;          float heightOffset;
    int      blendParams;          float fadeStrength;
    float    verticalOffset;
    int      useAlphaMask;         int   useDecalTexturing;
    float    AlbedoOpacity;        float NormalOpacity;
    int      NormalBlend;          float GradientOpacity;
    float4   TintColor;
    int      UseTextureAlphaMask;  int   UseTextureHeightmapFade;
    float3   DecalUp;
    float3   DecalForward;
    float3   DecalRight;
    float    GradientScale;
};

// Bound by PQSRenderer.UpdateDecalInstances.  Declared unconditionally:
// Unity binds these slots harmlessly when DECALS_ENABLED is off
// (decalInstanceCount stays 0 and the texture arrays are bound to null).
StructuredBuffer<DecalInstance> decalInstances;
int    decalInstanceCount;
float  SphereRadius;
float4 _DecalFadeParams;
Texture2DArray<float4> _DecalAlbedo;
Texture2DArray<float4> _DecalNormalSAO;
Texture2DArray<float4> _DecalAlphaMask;

// Distance ramp on _DecalFadeParams.
float ComputeDecalFade(float cameraDist)
{
    return lerp(_DecalFadeParams.z, _DecalFadeParams.w,
                saturate((cameraDist - _DecalFadeParams.x)
                       / max(_DecalFadeParams.y - _DecalFadeParams.x, 0.001)));
}

// Per-decal apply.  Mutates `diffs` (aux/large/mid lerp toward decalAlbedoDiff
// by decalBlendFactor) and `nrmAccum` (blend against decalQuatRotated or
// decalWorldNrm scaled by NormalOpacity*decalFade).
//
// The quat-rotate math below has a deliberate operator-precedence quirk: only
// the second cross-product term is divided by decalQuatLen.  Do NOT replace
// the inline math with Common.cginc::RotateByHalfArcQuat -- the "corrected"
// version produces a visibly different result.
void ApplyOneDecal(
    uint slot, float3 localPos, float decalFade, float3 surfTangent,
    inout HmDiffs diffs, inout float3 nrmAccum)
{
    DecalInstance decal = decalInstances[slot];

    // The .y row of worldToLocal is unused -- the box test only needs the
    // local-space x and z components, so the dual dot produces those directly.
    float4 lp4        = float4(localPos, 1.0);
    float2 decalLocal = float2(
        dot(float4(decal.worldToLocal[0][0], decal.worldToLocal[1][0],
                   decal.worldToLocal[2][0], decal.worldToLocal[3][0]), lp4),
        dot(float4(decal.worldToLocal[0][2], decal.worldToLocal[1][2],
                   decal.worldToLocal[2][2], decal.worldToLocal[3][2]), lp4));

    if (!(distance(localPos, decal.position) < SphereRadius
          && all(abs(decalLocal) < 0.5)))
        return;

    float2 decalUV  = saturate(decalLocal + 0.5);
    float3 decalUV3 = float3(decalUV, (float)decal.index);

    float4 decalAlbedoSample = _DecalAlbedo.Sample(sampler_LinearRepeat, decalUV3);
    float  decalMaskValue    = (decal.UseTextureAlphaMask != 0)
        ? _DecalAlphaMask.Sample(sampler_LinearRepeat, decalUV3).x
        : 1.0;

    float2 decalCenterOff = decalUV - 0.5;
    // blendParams' MSB picks edge-fade type (asfloat reinterpret of the int).
    float  decalEdgeFade  = pow(
        (asfloat(decal.blendParams) < 0.0)
            ? 1.0 - 2.0 * max(abs(decalCenterOff.x), abs(decalCenterOff.y))
            : max(1.0 - 2.0 * length(decalCenterOff), 0.0),
        decal.fadeStrength);
    float decalMaskFinal = (decal.UseTextureHeightmapFade != 0)
        ? decalMaskValue * min(decalEdgeFade + decalEdgeFade, 1.0)
        : decalMaskValue;

    float2 decalAlbedoDiff  = decalAlbedoSample.xy - decalAlbedoSample.zw;
    float  decalBlendFactor = decalFade * (decal.GradientOpacity * decalMaskFinal);

    // Decal-space normal -> world.  TBN is float3x3(DecalRight, DecalForward, DecalUp).
    float3 decalDecNrm   = DecodeDxt5nm(_DecalNormalSAO.Sample(sampler_LinearRepeat, decalUV3));
    float3 decalTbnNrm   = mul(decalDecNrm, float3x3(decal.DecalRight, decal.DecalForward, decal.DecalUp));
    float3 decalWorldNrm = normalize(mul((float3x3)_PQSToWorld, decalTbnNrm));

    // Half-arc quaternion blend.  The operator precedence on the cross
    // expression is intentional: only the second term divides by quatLen.
    float  decalQuatDot1   = dot(surfTangent, decalWorldNrm) + 1.0;
    float  decalQuatLen    = sqrt(decalQuatDot1 + decalQuatDot1);
    float3 decalQuatCross  = surfTangent.yzx * decalWorldNrm.zxy
                           - decalWorldNrm.yzx * surfTangent.zxy / decalQuatLen;
    float  decalQuatW      = decalQuatDot1 / decalQuatLen;
    float  decalQuatDiag   = decalQuatW * decalQuatW - dot(decalQuatCross, decalQuatCross);
    float  decalQuatNdotP  = dot(decalQuatCross, nrmAccum);
    bool   decalUseWorldNrm = decal.NormalBlend != 0;
    float3 decalQuatRotated = (decalQuatW + decalQuatW) * cross(decalQuatCross, nrmAccum)
                            + nrmAccum * decalQuatDiag
                            + (decalQuatNdotP + decalQuatNdotP) * decalQuatCross;
    float3 decalDirNrm     = (decalMaskFinal * decalUseWorldNrm) ? decalWorldNrm : decalQuatRotated;
    float3 decalBlendedNrm = decal.NormalOpacity * decalDirNrm * decalFade + nrmAccum;

    diffs.aux   = lerp(diffs.aux,   decalAlbedoDiff, decalBlendFactor);
    diffs.large = lerp(diffs.large, decalAlbedoDiff, decalBlendFactor);
    diffs.mid   = lerp(diffs.mid,   decalAlbedoDiff, decalBlendFactor);
    nrmAccum    = normalize(decalBlendedNrm);
}

// Mode dispatch.  PACKED4 unpacks 4 byte slots from `triangleData`; INFINITE
// iterates `decalInstanceCount` directly.  Pass 13 (DECAL_MODE_NONE) compiles
// to an empty body and the call is elided -- callers can invoke this
// unconditionally.
void ApplyDecals(
    inout HmDiffs diffs, inout float3 nrmAccum,
    float3 localPos, float3 surfTangent, float cameraDist, uint triangleData)
{
#if defined(DECALS_ENABLED) && defined(DECAL_MODE_PACKED4)
    float decalFade = ComputeDecalFade(cameraDist);
    [unroll]
    for (uint i = 0u; i < 4u; ++i)
    {
        uint slot = (triangleData >> (i * 8u)) & 0xFFu;
        if (slot != 0xFFu)
            ApplyOneDecal(slot, localPos, decalFade, surfTangent, diffs, nrmAccum);
    }
#elif defined(DECALS_ENABLED) && defined(DECAL_MODE_INFINITE)
    float decalFade = ComputeDecalFade(cameraDist);
    for (int i = 0; i < decalInstanceCount; ++i)
        ApplyOneDecal((uint)i, localPos, decalFade, surfTangent, diffs, nrmAccum);
#endif
}

#endif // DECALS_CGINC
