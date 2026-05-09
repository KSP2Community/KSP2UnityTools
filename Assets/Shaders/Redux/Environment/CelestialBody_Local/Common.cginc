#ifndef COMMON_CGINC
#define COMMON_CGINC

// ============================================================================
// Common.cginc
//
// Shared declarations and helpers used by every pass kind: macro defines,
// GBuffer/PrepassOutput-adjacent types, texture/uniform declarations, and
// general normal-blending helpers.  Pass-specific code lives in the per-pass
// includes (DeferredBase, DeferredBiome, Prepass).
// ============================================================================

#include "UnityCG.cginc"
#include "QuadMeshData.cginc"
#include "WorldTBN.cginc"

#if defined(PASS_DEFERRED_BASE) || defined(PASS_DEFERRED_BIOME)
    #define PASS_DEFERRED
#endif

#define BIOME_CHANNEL_R     (1 << 0)
#define BIOME_CHANNEL_G     (1 << 1)
#define BIOME_CHANNEL_B     (1 << 2)
#define BIOME_CHANNEL_A     (1 << 3)

#define DECAL_MASK_NONE     (1 << 29)
#define DECAL_MASK_PACKED4  (1 << 28)
#define DECAL_MASK_INFINITE (1 << 27)
#define DECAL_MASK          (DECAL_MASK_NONE | DECAL_MASK_PACKED4 | DECAL_MASK_INFINITE)

// Triangle flag bits used by the per-pass vertex clip-distance test:
//   Pass 01..03 forward base:        (flags & 0xC0000000) != 0  -> either bucket bit
//   Pass 04..07 non-additive biome:  (flags & 0x80000000) != 0  -> bit 31
//   Pass 08..11 additive biome:      (flags & 0x40000000) != 0  -> bit 30
// Passes that want bit 30 instead of bit 31 must `#define ADDITIVE_BIOME`
// before including this header — Vertex.cginc switches arms accordingly.
#define TRIPLANAR_BUCKET_MASK       (3u << 30)
#define TRIPLANAR_BUCKET_NONADD     (1u << 31)
#define TRIPLANAR_BUCKET_ADDITIVE   (1u << 30)

#if defined(PASS_DEFERRED_BASE) || defined(PASS_DEFERRED_BIOME)
struct GBufferOutput
{
    float4 albedoSmoothness  : SV_Target0;
    float4 specularOcclusion : SV_Target1;
    float4 normalProjRatio   : SV_Target2;
    float4 emission          : SV_Target3;
};
#endif

SamplerState sampler_LinearRepeat;

// Slope-gradient input shared between the prepass height-map sampling and
// Decals.cginc's apply loop: `xy - zw` of each per-channel HmAccum, plus
// `aux` (subzone-mask diff in non-SZ; second biome-mask sample diff in SZ).
struct HmDiffs
{
    float2 large;
    float2 mid;
    float2 sz3;
    float2 sz4;
    float2 aux;
};

// File-scope declarations of texture / uniform inputs used across pass kinds.
// (Properties block in the .shader declares these as material slots; HLSL
// still needs the declaration to compile.)
Texture2D<float4> _NormalScaledTex;
Texture2D<float4> _BiomeMaskTex;
Texture2D<float4> _SubzoneMaskTex;
Texture2D<float4> _MidNormalR,    _MidNormalG,    _MidNormalB,    _MidNormalA;
Texture2D<float4> _LargeNormalR,  _LargeNormalG,  _LargeNormalB,  _LargeNormalA;
Texture2D<float4> _LargeGradienceR, _LargeGradienceG, _LargeGradienceB, _LargeGradienceA;
Texture2D<float4> _MidGradienceR,   _MidGradienceG,   _MidGradienceB,   _MidGradienceA;

// Subzone3/4 normals (SZ-only) live in a single Texture2DArray addressed
// per-biome-channel via NormalIndices.  Declared unconditionally — the
// uniform slots resolve to default sentinels (-1) when SZ is disabled
// and Unity skips binding the array; sampler is harmless.
Texture2DArray<float4> _SubZonesNormalTextureArray;
float4   _Subzone3NormalIndices, _Subzone4NormalIndices;
float4   _Subzone3NormalRUVParams,   _Subzone3NormalGUVParams,   _Subzone3NormalBUVParams,   _Subzone3NormalAUVParams;
float4   _Subzone3NormalRFadeParams, _Subzone3NormalGFadeParams, _Subzone3NormalBFadeParams, _Subzone3NormalAFadeParams;
float4   _Subzone4NormalRUVParams,   _Subzone4NormalGUVParams,   _Subzone4NormalBUVParams,   _Subzone4NormalAUVParams;
float4   _Subzone4NormalRFadeParams, _Subzone4NormalGFadeParams, _Subzone4NormalBFadeParams, _Subzone4NormalAFadeParams;

float4   _NormalScaledFadeParams;
float4   _MidNormalRUVParams,     _MidNormalGUVParams,     _MidNormalBUVParams,     _MidNormalAUVParams;
float4   _MidNormalRFadeParams,   _MidNormalGFadeParams,   _MidNormalBFadeParams,   _MidNormalAFadeParams;
float4   _LargeNormalRUVParams,   _LargeNormalGUVParams,   _LargeNormalBUVParams,   _LargeNormalAUVParams;
float4   _LargeNormalRFadeParams, _LargeNormalGFadeParams, _LargeNormalBFadeParams, _LargeNormalAFadeParams;
float4   _LargeHeightMapUVScales;     // (R, G, B, A) per-channel scalar UV scales for _LargeGradience*
float4   _MediumHeightMapUVScales;    // (R, G, B, A) per-channel scalar UV scales for _MidGradience*
float3   TriplanarContrastBoost;
float    _TriplanarContrast;
float4   _TriplanarUVScaleOffset;
float4x4 _PQSToLocal;

// Piecewise-linear ramp: from p.z to p.w over t in [p.x, p.x + p.y].
float RampFade(float t, float4 p)
{
	return lerp(p.z, p.w, saturate((t - p.x) / max(p.y, 0.01f)));
}

// Unity "RGorAG" normal-map decode (matches UnityCG's UnpackNormalmapRGorAG,
// which is what UnpackNormal() resolves to outside UNITY_NO_DXT5nm):
//   x' = s.w * s.x   (alpha pre-multiplies red, so a default "bump" sample at
//                     (1,1,1,1) decodes to a flat (0,0,1) normal)
//   xy = (x', s.y) * 2 - 1
//   z  = sqrt(1 - dot(xy, xy))
float3 DecodeDxt5nm(float4 s)
{
    float2 xy = float2(s.w * s.x, s.y) * 2.0 - 1.0;
    float  z  = sqrt(saturate(1.0 - dot(xy, xy)));
    return float3(xy, z);
}

// Per-layer normal-map result and its distance-fade params.  Used for the
// Mid / Large / Subzone normal layers fed into BlendLayerNormal.
struct NormalLayerResult
{
    float3 normal;
    float4 fade;
};

// Shared inputs for planar (Large) normal sampling: face + local UVs,
// derivatives at each, the normalised local-position frame, and the polar
// blend factors.
struct NormSampleCtx
{
    float2 faceUV;
    float2 faceDdx;
    float2 faceDdy;
    float2 localUV;
    float2 localDdx;
    float2 localDdy;
    float3 normLocalPos;
    float3 localPos;
    float  triSignYNorm;
    float  normYBlend;
};

// Decode a face + local normal-sample pair and produce the final
// NormalLayerResult by reorienting the local normal into world space and
// blending with the face TBN.  Caller provides the per-vertex TBN frame.
NormalLayerResult DecodeAndReorientNormal(
    float4 faceSample, float4 localSample,
    NormSampleCtx ctx, float4 fadeParams,
    float3 worldNormal, float3 bitangent, float3 worldTangent)
{
    float3 faceN = UnpackNormal(faceSample);
    // TBN convention: N*x + B*y + T*z.
    float3 tbnNorm = normalize(worldNormal * faceN.x + bitangent * faceN.y + worldTangent * faceN.z);

    float3 localN     = UnpackNormal(localSample);
    float  absYP1     = abs(ctx.normLocalPos.y) + 1.0;
    float  reorientDot = dot(float3(ctx.normLocalPos.x, ctx.normLocalPos.z, absYP1),
                             float3(-localN.x,           -localN.y,         localN.z));
    // Anchor the reorient on `normLocalPos` (unit-length), not raw `localPos`
    // (planet-radius-scaled, ~600000 on Kerbin) -- raw magnitudes dwarf the
    // localN perturbation under the subsequent normalize and make the Large
    // normal map contribute nothing.
    float3 reorientVec = float3(
        ctx.normLocalPos.x + localN.x + (ctx.normLocalPos.x * reorientDot) / absYP1,
        ctx.normLocalPos.y + ctx.triSignYNorm * (reorientDot - localN.z),
        ctx.normLocalPos.z + localN.y + (ctx.normLocalPos.z * reorientDot) / absYP1);
    float3 worldNorm = normalize(mul((float3x3)_PQSToWorld, normalize(reorientVec)));

    NormalLayerResult r;
    r.normal = lerp(worldNorm, tbnNorm, ctx.normYBlend);
    r.fade   = fadeParams;
    return r;
}

// Planar Large-normal sample: face + local UVs with explicit derivatives.
NormalLayerResult SampleLargeNormal(
    Texture2D<float4> tex, SamplerState samp,
    float4 uvParams, float4 fadeParams,
    NormSampleCtx ctx,
    float3 worldNormal, float3 bitangent, float3 worldTangent)
{
    float2 faceUV   = ctx.faceUV   * uvParams.xy + uvParams.zw;
    float2 localUV  = ctx.localUV  * uvParams.xy + uvParams.zw;
    float2 faceDdx  = ctx.faceDdx  * uvParams.xy;
    float2 faceDdy  = ctx.faceDdy  * uvParams.xy;
    float2 localDdx = ctx.localDdx * uvParams.xy;
    float2 localDdy = ctx.localDdy * uvParams.xy;
    float4 faceSample  = tex.SampleGrad(samp, faceUV,  faceDdx,  faceDdy);
    float4 localSample = tex.SampleGrad(samp, localUV, localDdx, localDdy);
    return DecodeAndReorientNormal(faceSample, localSample, ctx, fadeParams,
                                   worldNormal, bitangent, worldTangent);
}

// Texture2DArray Subzone-normal sample (Subzone3 / Subzone4): same UV/derivative
// derivation as SampleLargeNormal, but indexes into an array slice via
// `arrayIndex` (sourced from `_Subzone{3,4}NormalIndices.<ch>`).
NormalLayerResult SampleArrayNormal(
    Texture2DArray<float4> tex, SamplerState samp,
    float4 uvParams, float4 fadeParams, float arrayIndex,
    NormSampleCtx ctx,
    float3 worldNormal, float3 bitangent, float3 worldTangent)
{
    float2 faceUV   = ctx.faceUV   * uvParams.xy + uvParams.zw;
    float2 localUV  = ctx.localUV  * uvParams.xy + uvParams.zw;
    float2 faceDdx  = ctx.faceDdx  * uvParams.xy;
    float2 faceDdy  = ctx.faceDdy  * uvParams.xy;
    float2 localDdx = ctx.localDdx * uvParams.xy;
    float2 localDdy = ctx.localDdy * uvParams.xy;
    float4 faceSample  = tex.SampleGrad(samp, float3(faceUV,  arrayIndex), faceDdx,  faceDdy);
    float4 localSample = tex.SampleGrad(samp, float3(localUV, arrayIndex), localDdx, localDdy);
    return DecodeAndReorientNormal(faceSample, localSample, ctx, fadeParams,
                                   worldNormal, bitangent, worldTangent);
}

// Triplanar Mid-normal sample with RNM-style reorientation.  Samples the
// texture on three object-space planes (YZ, XZ, XY), then reconstructs a
// single object-space normal via axis-permuted "half-dot" contributions
// weighted by triWeight.  Result is rotated into world space via _PQSToWorld.
NormalLayerResult SampleMidNormal(
    Texture2D<float4> tex, SamplerState samp,
    float4 uvParams, float4 fadeParams,
    float3 objNorm, float3 objectNormal, float3 triWeight, float3 triSign,
    float2 triUV_YZ, float2 triUV_XZ, float2 triUV_XY)
{
    float3 yz_n = UnpackNormal(tex.Sample(samp, triUV_YZ * uvParams.xy + uvParams.zw));
    float3 xz_n = UnpackNormal(tex.Sample(samp, triUV_XZ * uvParams.xy + uvParams.zw));
    float3 xy_n = UnpackNormal(tex.Sample(samp, triUV_XY * uvParams.xy + uvParams.zw));
    float3 absP1  = abs(objNorm) + 1.0;
    float  yz_dot = dot(float3(objNorm.z, objNorm.y, absP1.x), float3(-yz_n.x, -yz_n.y, yz_n.z));
    float  xz_dot = dot(float3(objNorm.x, objNorm.z, absP1.y), float3(-xz_n.x, -xz_n.y, xz_n.z));
    float  xy_dot = dot(float3(objNorm.x, objNorm.y, absP1.z), float3(-xy_n.x, -xy_n.y, xy_n.z));
    float3 reorient = float3(
        objectNormal.x + triWeight.z * (xy_n.x + (xy_dot * objNorm.x) / absP1.z) + triWeight.x * triSign.x * (yz_dot - yz_n.z) + triWeight.y * (xz_n.x + (xz_dot * objNorm.x) / absP1.y),
        objectNormal.y + triWeight.z * (xy_n.y + (xy_dot * objNorm.y) / absP1.z) + triWeight.x * (yz_n.y + (objNorm.y * yz_dot) / absP1.x) + triWeight.y * triSign.y * (xz_dot - xz_n.z),
        objectNormal.z + triWeight.z * triSign.z * (xy_dot - xy_n.z) + triWeight.x * (yz_n.x + (objNorm.z * yz_dot) / absP1.x) + triWeight.y * (xz_n.y + (xz_dot * objNorm.z) / absP1.y));
    NormalLayerResult r;
    r.normal = mul((float3x3)_PQSToWorld, normalize(reorient));
    r.fade   = fadeParams;
    return r;
}

// Shortest-arc quaternion rotation: rotates v by the rotation that maps
// `from` onto `to`.  q = (qW, qXYZ) where qXYZ = cross(from,to)/k,
// qW = (1+dot)/k, k = sqrt(2(1+dot)).
float3 RotateByHalfArcQuat(float3 from, float3 to, float3 v)
{
    float  quatDot = dot(from, to) + 1.0;
    float  quatLen = sqrt(2.0 * quatDot);
    float3 qXYZ    = cross(from, to) / quatLen;
    float  qW      = quatDot / quatLen;
    float  diag    = qW * qW - dot(qXYZ, qXYZ);
    return v * diag + 2.0 * qW * cross(qXYZ, v) + 2.0 * dot(qXYZ, v) * qXYZ;
}

// Fold 4 biome-channel normal layers into prevNorm via a shortest-arc
// rotation from worldTangentDir to the fade-weighted channel sum, scaled
// by (1 - normalScaleFade) and the summed blend weight.
float3 BlendLayerNormal(
    float3 prevNorm,
    NormalLayerResult r, NormalLayerResult g, NormalLayerResult b, NormalLayerResult a,
    float4 biomeWeightNorm, float3 worldTangentDir, float normalScaleFade, float cameraDist)
{
    float4 fades = float4(RampFade(cameraDist, r.fade), RampFade(cameraDist, g.fade),
                          RampFade(cameraDist, b.fade), RampFade(cameraDist, a.fade));
    float4 w           = biomeWeightNorm * fades;
    float  blendWeight = saturate(w.x + w.y + w.z + w.w);
    if (0.001 < blendWeight)
    {
        float3 blendNorm = w.x * r.normal + w.y * g.normal + w.z * b.normal + w.w * a.normal;
        float3 rotated   = RotateByHalfArcQuat(worldTangentDir, blendNorm, prevNorm);
        return lerp(prevNorm, rotated, (1.0 - normalScaleFade) * blendWeight);
    }
    return prevNorm;
}

#endif // COMMON_CGINC
