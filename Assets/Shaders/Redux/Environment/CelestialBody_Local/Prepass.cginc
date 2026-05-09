#ifndef PREPASS_CGINC
#define PREPASS_CGINC

// ============================================================================
// Prepass.cginc
//
// PASS_PREPASS (passes 13/14/15) fragment + everything specific to the
// prepass: per-layer biome uniforms, the ComputeLayerPhi / LayerWeight /
// ComputeChannelLayerWeights helpers used to compute LAYERS4(*) outputs,
// and PrepassOutput.
// ============================================================================

#include "Vertex.cginc"
#include "Decals.cginc"

// Per-channel per-layer biome inputs used by the prepass to compute LAYERS4
// weights.  Each Vector is a per-layer scalar (xyzw = layer1..layer4) for
// one biome channel.  The reference uses these as gates: a layer is "active"
// when its slice index is non-negative AND the per-layer enable*heightWeight
// product is positive AND the biome channel itself has non-zero per-pixel
// weight.
float4 _SmallBiomeR,        _SmallBiomeG,        _SmallBiomeB,        _SmallBiomeA;
float4 _SmallHeightWeightR, _SmallHeightWeightG, _SmallHeightWeightB, _SmallHeightWeightA;
float4 _SmallEnableR,       _SmallEnableG,       _SmallEnableB,       _SmallEnableA;

// Per-layer ComputeLayerPhi inputs.  `*HeightEnable*` / `*SlopeEnable*` are
// per-channel float4s (xyzw = layer1..4 enable scalars); `*Params{1..4}`
// are per-layer float4 vectors.
float4 _SmallBiomeRHeightParams1, _SmallBiomeRHeightParams2, _SmallBiomeRHeightParams3, _SmallBiomeRHeightParams4;
float4 _SmallBiomeRSlopeParams1,  _SmallBiomeRSlopeParams2,  _SmallBiomeRSlopeParams3,  _SmallBiomeRSlopeParams4;
float4 _SmallBiomeRGradMapWeights1, _SmallBiomeRGradMapWeights2, _SmallBiomeRGradMapWeights3, _SmallBiomeRGradMapWeights4;
float4 _SmallBiomeHeightEnableR;
float4 _SmallBiomeSlopeEnableR;

float4 _SmallBiomeGHeightParams1, _SmallBiomeGHeightParams2, _SmallBiomeGHeightParams3, _SmallBiomeGHeightParams4;
float4 _SmallBiomeGSlopeParams1,  _SmallBiomeGSlopeParams2,  _SmallBiomeGSlopeParams3,  _SmallBiomeGSlopeParams4;
float4 _SmallBiomeGGradMapWeights1, _SmallBiomeGGradMapWeights2, _SmallBiomeGGradMapWeights3, _SmallBiomeGGradMapWeights4;
float4 _SmallBiomeHeightEnableG;
float4 _SmallBiomeSlopeEnableG;

float4 _SmallBiomeBHeightParams1, _SmallBiomeBHeightParams2, _SmallBiomeBHeightParams3, _SmallBiomeBHeightParams4;
float4 _SmallBiomeBSlopeParams1,  _SmallBiomeBSlopeParams2,  _SmallBiomeBSlopeParams3,  _SmallBiomeBSlopeParams4;
float4 _SmallBiomeBGradMapWeights1, _SmallBiomeBGradMapWeights2, _SmallBiomeBGradMapWeights3, _SmallBiomeBGradMapWeights4;
float4 _SmallBiomeHeightEnableB;
float4 _SmallBiomeSlopeEnableB;

float4 _SmallBiomeAHeightParams1, _SmallBiomeAHeightParams2, _SmallBiomeAHeightParams3, _SmallBiomeAHeightParams4;
float4 _SmallBiomeASlopeParams1,  _SmallBiomeASlopeParams2,  _SmallBiomeASlopeParams3,  _SmallBiomeASlopeParams4;
float4 _SmallBiomeAGradMapWeights1, _SmallBiomeAGradMapWeights2, _SmallBiomeAGradMapWeights3, _SmallBiomeAGradMapWeights4;
float4 _SmallBiomeHeightEnableA;
float4 _SmallBiomeSlopeEnableA;

#ifdef SUB_ZONES_ENABLED
// Subzone-only height-map textures (tier-2 detail above Large/Mid).
Texture2D<float4> _Subzone3GradienceR, _Subzone3GradienceG, _Subzone3GradienceB, _Subzone3GradienceA;
Texture2D<float4> _Subzone4GradienceR, _Subzone4GradienceG, _Subzone4GradienceB, _Subzone4GradienceA;
float4 _Subzone3HeightMapUVScales, _Subzone4HeightMapUVScales;

// Per-pixel filter vectors: dot(subzoneWeight, _<Pre><Ch>SubzoneFilter) yields a
// scalar that scales the corresponding height-map sample for that biome channel.
float4 _LargeRSubzoneFilter,    _LargeGSubzoneFilter,    _LargeBSubzoneFilter,    _LargeASubzoneFilter;
float4 _MidRSubzoneFilter,      _MidGSubzoneFilter,      _MidBSubzoneFilter,      _MidASubzoneFilter;
float4 _Subzone3RSubzoneFilter, _Subzone3GSubzoneFilter, _Subzone3BSubzoneFilter, _Subzone3ASubzoneFilter;
float4 _Subzone4RSubzoneFilter, _Subzone4GSubzoneFilter, _Subzone4BSubzoneFilter, _Subzone4ASubzoneFilter;

// Per-layer subzone-driven gate.  In SZ the layer enable becomes
// `_SmallEnable<C>.<CH> * dot(subzoneWeight, _SmallSubzoneWeight<C><I>)`,
// replacing the base path's constant `_SmallHeightWeight * _SmallEnable`.
float4 _SmallSubzoneWeightR1, _SmallSubzoneWeightR2, _SmallSubzoneWeightR3, _SmallSubzoneWeightR4;
float4 _SmallSubzoneWeightG1, _SmallSubzoneWeightG2, _SmallSubzoneWeightG3, _SmallSubzoneWeightG4;
float4 _SmallSubzoneWeightB1, _SmallSubzoneWeightB2, _SmallSubzoneWeightB3, _SmallSubzoneWeightB4;
float4 _SmallSubzoneWeightA1, _SmallSubzoneWeightA2, _SmallSubzoneWeightA3, _SmallSubzoneWeightA4;

// Per-layer subzone tints.  Only the .w (alpha) of the _R / _G variants
// participates in the prepass: they multiply diffs.sz3 / diffs.sz4 in the
// slope-gradient sum.  Other components of these vectors drive albedo tinting
// in the deferred passes (not used by tex0..3).
float4 _SmallSubzoneTintR1_R, _SmallSubzoneTintR2_R, _SmallSubzoneTintR3_R, _SmallSubzoneTintR4_R;
float4 _SmallSubzoneTintG1_R, _SmallSubzoneTintG2_R, _SmallSubzoneTintG3_R, _SmallSubzoneTintG4_R;
float4 _SmallSubzoneTintB1_R, _SmallSubzoneTintB2_R, _SmallSubzoneTintB3_R, _SmallSubzoneTintB4_R;
float4 _SmallSubzoneTintA1_R, _SmallSubzoneTintA2_R, _SmallSubzoneTintA3_R, _SmallSubzoneTintA4_R;
float4 _SmallSubzoneTintR1_G, _SmallSubzoneTintR2_G, _SmallSubzoneTintR3_G, _SmallSubzoneTintR4_G;
float4 _SmallSubzoneTintG1_G, _SmallSubzoneTintG2_G, _SmallSubzoneTintG3_G, _SmallSubzoneTintG4_G;
float4 _SmallSubzoneTintB1_G, _SmallSubzoneTintB2_G, _SmallSubzoneTintB3_G, _SmallSubzoneTintB4_G;
float4 _SmallSubzoneTintA1_G, _SmallSubzoneTintA2_G, _SmallSubzoneTintA3_G, _SmallSubzoneTintA4_G;
#endif

// Per-layer enable gate for a biome channel.  Returns true if the layer is
// enabled here (biome channel has weight, slice index is valid, and the
// per-layer enable*heightWeight product is positive); false otherwise.
bool LayerGatePass(bool biomeActive, float biomeChan, float gateProduct)
{
    return biomeActive && biomeChan >= 0.0 && gateProduct > 0.0;
}

// Squared-ramp trapezoidal window, parameterised by p = (center, upRange,
// downRange, fadeOut):
//   axis < center - downRange           : 0
//   center - downRange <= axis < center : fadeIn^2 ramp
//   center <= axis < center + upRange   : 1
//   center + upRange <= axis < hi + w   : fadeOut^2 ramp
//   axis >= hi + w                      : 0
float ComputeFadeTri(float axis, float4 p)
{
    float hi = p.x + p.y;
    float lo = p.x - p.z;
    float fi = saturate((axis - lo) / max(p.x - lo, 0.001));
    float fo = 1.0 - saturate((axis - hi) / max(p.w, 0.001));
    return step(axis, hi + p.w) * step(hi, axis) * fo * fo
         + step(p.x, axis) * step(axis, hi)
         + fi * fi * step(lo, axis) * step(axis, p.x);
}

// ----------------------------------------------------------------------------
// Height-map sampling (used to drive the slope-gradient input to ComputeLayerPhi).
// Base path samples Large + Med only.  SZ adds Subzone3 + Subzone4 (multiplied
// by per-pixel `dot(subzoneWeight, _<Pre><Ch>SubzoneFilter)` factors) and
// switches `diffs.aux` from the subzone-mask sample to a second biome-mask
// sample.
// ----------------------------------------------------------------------------

// Per-biome-channel height-map accumulation.  sz3 / sz4 are populated only when
// SUB_ZONES_ENABLED is on; base callers leave them zero so the slope-gradient
// terms involving them collapse to zero in ComputeLayerPhi.
struct HmAccum
{
    float4 large;
    float4 med;
    float4 sz3;
    float4 sz4;
};

// HmDiffs lives in Common.cginc so Decals.cginc (also included from Common)
// can reference it without depending on inclusion order.

// Shared UVs for height-map sampling: face + local, blended by hmNormYBlend.
struct HmSampleCtx
{
    float2 faceUV;
    float2 localUV;
    float  hmNormYBlend;
};

// Sample one height texture at face + local UV and blend by hmNormYBlend.
float4 SampleAndBlendHeight(Texture2D<float4> tex, SamplerState samp, float uvScale, HmSampleCtx ctx)
{
    float4 F = tex.Sample(samp, ctx.faceUV  * uvScale);
    float4 L = tex.Sample(samp, ctx.localUV * uvScale);
    return lerp(L, F, ctx.hmNormYBlend);
}

// Accumulate Large + Med height-map samples for one biome channel weighted by
// `hmBiomeWeight.<ch>` (skipping the sample if the channel weight is ~0).
HmAccum AccumHeightBiome(
    float biomeWeight,
    Texture2D<float4> largeTex, SamplerState largeSamp, float largeUVScale,
    Texture2D<float4> medTex,   SamplerState medSamp,   float medUVScale,
    HmSampleCtx ctx, HmAccum prev)
{
    HmAccum a = prev;
    if (0.001 < biomeWeight)
    {
        a.large += biomeWeight * SampleAndBlendHeight(largeTex, largeSamp, largeUVScale, ctx);
        a.med   += biomeWeight * SampleAndBlendHeight(medTex,   medSamp,   medUVScale,   ctx);
    }
    return a;
}

#ifdef SUB_ZONES_ENABLED
// SUB_ZONES variant: scale Large + Med by their per-pixel subzone-filter factor
// and additionally accumulate Subzone3 + Subzone4 height maps (each filtered
// by their own per-pixel factor).  The four `szFilters` lanes correspond to
// (large, mid, sz3, sz4) and are precomputed by the caller via dot products
// of `subzoneWeight` with the family-specific filter uniforms.
HmAccum AccumHeightBiome_SZ(
    float biomeWeight, float4 szFilters,
    Texture2D<float4> largeTex, SamplerState largeSamp, float largeUVScale,
    Texture2D<float4> medTex,   SamplerState medSamp,   float medUVScale,
    Texture2D<float4> sz3Tex,   SamplerState sz3Samp,   float sz3UVScale,
    Texture2D<float4> sz4Tex,   SamplerState sz4Samp,   float sz4UVScale,
    HmSampleCtx ctx, HmAccum prev)
{
    HmAccum a = prev;
    if (0.001 < biomeWeight)
    {
        a.large += biomeWeight * szFilters.x * SampleAndBlendHeight(largeTex, largeSamp, largeUVScale, ctx);
        a.med   += biomeWeight * szFilters.y * SampleAndBlendHeight(medTex,   medSamp,   medUVScale,   ctx);
        a.sz3   += biomeWeight * szFilters.z * SampleAndBlendHeight(sz3Tex,   sz3Samp,   sz3UVScale,   ctx);
        a.sz4   += biomeWeight * szFilters.w * SampleAndBlendHeight(sz4Tex,   sz4Samp,   sz4UVScale,   ctx);
    }
    return a;
}
#endif

// One-layer phi: heightW * slopeW.  slopeAng comes from a length(grad)*90deg
// projection of the per-channel height-map diffs weighted by `gradWeights`
// (gradWeights.x = aux, .y = large, .z = mid).  In SZ, two extra terms scale
// diffs.sz3 / diffs.sz4 by per-layer tint .w components; base callers pass 0
// for tintGw / tintRw so those terms collapse out.  The slopeDegenerate
// short-circuit (`slopeParams.x == 0 && slopeParams.y == 0 && slopeEnable != 0`)
// produces a hard zero, killing the layer even if the gate passes.
float ComputeLayerPhi(
    float height,
    float4 heightParams, float heightEnable,
    float4 slopeParams,  float slopeEnable,
    float4 gradWeights,  float tintGw, float tintRw,
    HmDiffs diffs)
{
    float heightW = lerp(1.0 - heightEnable, 1.0, ComputeFadeTri(height, heightParams));
    float2 grad = diffs.sz4  * tintGw
                + diffs.sz3  * tintRw
                + diffs.mid   * gradWeights.z
                + diffs.aux   * gradWeights.x
                + diffs.large * gradWeights.y;
    float slopeAng = min(length(grad), 1.0) * 90.0;
    bool slopeDegenerate = slopeParams.x == 0.0 && slopeParams.y == 0.0 && slopeEnable != 0.0;
    float slopeW = slopeDegenerate
        ? 0.0
        : lerp(1.0 - slopeEnable, 1.0, ComputeFadeTri(slopeAng, slopeParams));
    return heightW * slopeW;
}

// Single-layer LAYER (gate + phi).  Returns 0 if the gate fails.
float LayerWeight(
    bool biomeActive, float biomeChan, float gateProduct,
    float height,
    float4 heightParams, float heightEnable,
    float4 slopeParams,  float slopeEnable,
    float4 gradWeights,  float tintGw, float tintRw,
    HmDiffs diffs)
{
    if (!LayerGatePass(biomeActive, biomeChan, gateProduct))
        return 0.0;
    return ComputeLayerPhi(height, heightParams, heightEnable,
                           slopeParams, slopeEnable,
                           gradWeights, tintGw, tintRw, diffs);
}

// All-4-layers LAYERS4(channel) computation: gate + per-layer phi for each of
// the 4 layers in one biome channel.
//
// Inputs are the per-channel per-layer uniforms:
//   - biomeChan      : _SmallBiome{R,G,B,A}            -- per-layer slice index
//   - gateProduct    : _SmallHeightWeight* * _SmallEnable* (per layer)
//   - heightParams{1..4} / heightEnable : _SmallBiome*HeightParams{1..4}, _SmallBiomeHeightEnable*
//   - slopeParams{1..4}  / slopeEnable  : _SmallBiome*SlopeParams{1..4},  _SmallBiomeSlopeEnable*
//   - gradWeights{1..4}                 : _SmallBiome*GradMapWeights{1..4}
//   - diffs                             : shared per-pixel height-map diffs
float4 ComputeChannelLayerWeights(
    bool biomeActive, float4 biomeChan, float4 gateProduct, float height,
    float4 heightParams1, float4 heightParams2, float4 heightParams3, float4 heightParams4,
    float4 heightEnable,
    float4 slopeParams1,  float4 slopeParams2,  float4 slopeParams3,  float4 slopeParams4,
    float4 slopeEnable,
    float4 gradWeights1,  float4 gradWeights2,  float4 gradWeights3,  float4 gradWeights4,
    float4 tintGw4,       float4 tintRw4,
    HmDiffs diffs)
{
    return float4(
        LayerWeight(biomeActive, biomeChan.x, gateProduct.x, height,
                    heightParams1, heightEnable.x, slopeParams1, slopeEnable.x,
                    gradWeights1, tintGw4.x, tintRw4.x, diffs),
        LayerWeight(biomeActive, biomeChan.y, gateProduct.y, height,
                    heightParams2, heightEnable.y, slopeParams2, slopeEnable.y,
                    gradWeights2, tintGw4.y, tintRw4.y, diffs),
        LayerWeight(biomeActive, biomeChan.z, gateProduct.z, height,
                    heightParams3, heightEnable.z, slopeParams3, slopeEnable.z,
                    gradWeights3, tintGw4.z, tintRw4.z, diffs),
        LayerWeight(biomeActive, biomeChan.w, gateProduct.w, height,
                    heightParams4, heightEnable.w, slopeParams4, slopeEnable.w,
                    gradWeights4, tintGw4.w, tintRw4.w, diffs));
}

struct PrepassOutput
{
    float4 tex0   : SV_Target0;
    float4 tex1   : SV_Target1;
    float4 tex2   : SV_Target2;
    float4 tex3   : SV_Target3;
    float4 normal : SV_Target4;
};

// Tex4 = world-space normal: scaledNormal then Mid then Large folded in.
// Large is sampled with explicit derivatives at both face UV (planet-cube
// face) and local UV (normalised local-position projection), reoriented via
// `DecodeAndReorientNormal`, and folded into the running normal by the
// same `BlendLayerNormal` quat rotation used for Mid.
PrepassOutput frag(V2F i)
{
    float2 uv           = i.uvHeight.xy;
    float3 worldNormal  = i.worldNormalPosX.xyz;
    float3 bitangent    = i.bitangentPosY.xyz;
    float3 worldTangent = i.worldTangentPosZ.xyz;
    float3 worldPos     = float3(i.worldNormalPosX.w, i.bitangentPosY.w, i.worldTangentPosZ.w);
    float3 objectNormal = i.objectNormal;
    float  cameraDist   = distance(_WorldSpaceCameraPos, worldPos);

    // Triplanar setup: contrast-boosted axis weights, per-plane UVs.
    float3 localPos     = mul(_PQSToLocal, float4(worldPos, 1.0)).xyz;
    float3 objNorm      = normalize(objectNormal);
    float3 triWeightRaw = pow(abs(objNorm), abs(_TriplanarContrast) * TriplanarContrastBoost);
    float3 triWeight    = triWeightRaw / max(triWeightRaw.x + triWeightRaw.y + triWeightRaw.z, 0.001);
    float3 triSign      = float3(sign(objNorm.xy), objNorm.z >= 0.0 ? 1.0 : -1.0);
    float2 triUVScale   = _TriplanarUVScaleOffset.xy * 0.01;
    float2 triUV_YZ     = float2(localPos.z, localPos.y) * triUVScale + _TriplanarUVScaleOffset.zw;
    float2 triUV_XZ     = float2(localPos.x, localPos.z) * triUVScale + _TriplanarUVScaleOffset.zw;
    float2 triUV_XY     = float2(localPos.x, localPos.y) * triUVScale + _TriplanarUVScaleOffset.zw;

    // Planar (Large) sampling context: face UV (planet-cube face) + local UV
    // (projected from normalised local-position), with derivatives for
    // SampleGrad, plus polar blend factors.
    float2 uvFace           = float2(2.0 * uv.x, uv.y);
    float3 normLocalPos     = normalize(localPos);
    float2 normLocalHalf_xz = normLocalPos.xz * 0.5;
    float  absY             = abs(normLocalPos.y);
    float  normYBlend       = 1.0 - absY * absY * absY;
    float  triSignYNorm     = sign(normLocalPos.y);

    NormSampleCtx normCtx;
    normCtx.faceUV       = uvFace;
    normCtx.faceDdx      = ddx_coarse(uvFace);
    normCtx.faceDdy      = ddy_coarse(uvFace);
    normCtx.localUV      = normLocalHalf_xz;
    normCtx.localDdx     = ddx_coarse(normLocalHalf_xz);
    normCtx.localDdy     = ddy_coarse(normLocalHalf_xz);
    normCtx.normLocalPos = normLocalPos;
    normCtx.localPos     = localPos;
    normCtx.triSignYNorm = triSignYNorm;
    normCtx.normYBlend   = normYBlend;

    // Base "scaled" world normal: sample _NormalScaledTex, decode, reorient
    // into world space via TBN, then distance-fade between worldTangent (the
    // bare geometry direction) and the shaded normal.
    float4 nsample      = _NormalScaledTex.Sample(sampler_LinearRepeat, uv);
    float3 ts           = DecodeDxt5nm(nsample);
    float3 tbnNormal    = worldNormal * ts.x + bitangent * ts.y + worldTangent * ts.z;
    float  normalFade   = RampFade(cameraDist, _NormalScaledFadeParams);
    float3 scaledNormal = lerp(worldTangent, normalize(tbnNormal), normalFade);

    // Per-channel biome weights, plus a renormalised version used to weight
    // height-map accumulation.
    float4 biomeMask         = _BiomeMaskTex.Sample(sampler_LinearRepeat, uv);
    float4 biomeWeightNorm   = biomeMask / max(biomeMask.x + biomeMask.y + biomeMask.z + biomeMask.w, 0.001);
    float4 subzoneWeight     = _SubzoneMaskTex.Sample(sampler_LinearRepeat, uv);
    float  invBiomeWeightSum = 1.0 / max(biomeWeightNorm.x + biomeWeightNorm.y + biomeWeightNorm.z + biomeWeightNorm.w, 0.001);
    float4 hmBiomeWeight     = invBiomeWeightSum * biomeWeightNorm;

    // Mid normal layers (triplanar).
    NormalLayerResult midR = SampleMidNormal(_MidNormalR, sampler_LinearRepeat,
        _MidNormalRUVParams, _MidNormalRFadeParams,
        objNorm, objectNormal, triWeight, triSign, triUV_YZ, triUV_XZ, triUV_XY);
    NormalLayerResult midG = SampleMidNormal(_MidNormalG, sampler_LinearRepeat,
        _MidNormalGUVParams, _MidNormalGFadeParams,
        objNorm, objectNormal, triWeight, triSign, triUV_YZ, triUV_XZ, triUV_XY);
    NormalLayerResult midB = SampleMidNormal(_MidNormalB, sampler_LinearRepeat,
        _MidNormalBUVParams, _MidNormalBFadeParams,
        objNorm, objectNormal, triWeight, triSign, triUV_YZ, triUV_XZ, triUV_XY);
    NormalLayerResult midA = SampleMidNormal(_MidNormalA, sampler_LinearRepeat,
        _MidNormalAUVParams, _MidNormalAFadeParams,
        objNorm, objectNormal, triWeight, triSign, triUV_YZ, triUV_XZ, triUV_XY);

    // Large normal layers (planar with face/local blend).
    NormalLayerResult largeR = SampleLargeNormal(_LargeNormalR, sampler_LinearRepeat,
        _LargeNormalRUVParams, _LargeNormalRFadeParams,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult largeG = SampleLargeNormal(_LargeNormalG, sampler_LinearRepeat,
        _LargeNormalGUVParams, _LargeNormalGFadeParams,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult largeB = SampleLargeNormal(_LargeNormalB, sampler_LinearRepeat,
        _LargeNormalBUVParams, _LargeNormalBFadeParams,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult largeA = SampleLargeNormal(_LargeNormalA, sampler_LinearRepeat,
        _LargeNormalAUVParams, _LargeNormalAFadeParams,
        normCtx, worldNormal, bitangent, worldTangent);

#ifdef SUB_ZONES_ENABLED
    // SZ filter projection: dot(subzoneWeight, _<Pre><Ch>SubzoneFilter) per
    // family-channel.  Used both here (to scale per-layer normals) and below
    // (to scale per-layer height-map samples).
    #define SZ_FILTER(PRE) float4( \
        dot(subzoneWeight, _##PRE##RSubzoneFilter), \
        dot(subzoneWeight, _##PRE##GSubzoneFilter), \
        dot(subzoneWeight, _##PRE##BSubzoneFilter), \
        dot(subzoneWeight, _##PRE##ASubzoneFilter))
    float4 largeSzFilter = SZ_FILTER(Large);
    float4 midSzFilter   = SZ_FILTER(Mid);
    float4 sz3SzFilter   = SZ_FILTER(Subzone3);
    float4 sz4SzFilter   = SZ_FILTER(Subzone4);
    #undef SZ_FILTER

    // SZ mode scales each per-layer normal by its szFilter and additionally
    // gates the channel on `0.001 < biomeWeightNorm[ch] * szFilter[ch]`,
    // zeroing .fade when the gate fails.  The gate is load-bearing:
    // BlendLayerNormal's blendWeight sums `biomeWeightNorm[ch] *
    // RampFade(camDist, .fade)`, so leaving .fade populated for an inactive
    // channel would inflate blendWeight and corrupt the running prev normal.
    // APPLY_SZ uses step() to do this: when biomeWeight*szFilter < 0.001,
    // .fade *= 0 → RampFade returns 0 → w[ch] = 0; otherwise unchanged.
    #define APPLY_SZ(r, szF, c) { \
        r.normal *= (szF); \
        r.fade   *= step(0.001, (szF) * (c)); \
    }
    APPLY_SZ(midR, midSzFilter.x, biomeWeightNorm.x);
    APPLY_SZ(midG, midSzFilter.y, biomeWeightNorm.y);
    APPLY_SZ(midB, midSzFilter.z, biomeWeightNorm.z);
    APPLY_SZ(midA, midSzFilter.w, biomeWeightNorm.w);
    APPLY_SZ(largeR, largeSzFilter.x, biomeWeightNorm.x);
    APPLY_SZ(largeG, largeSzFilter.y, biomeWeightNorm.y);
    APPLY_SZ(largeB, largeSzFilter.z, biomeWeightNorm.z);
    APPLY_SZ(largeA, largeSzFilter.w, biomeWeightNorm.w);

    // Subzone3 + Subzone4 normal layers (Texture2DArray slices via NormalIndices).
    NormalLayerResult sz3R = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone3NormalRUVParams, _Subzone3NormalRFadeParams, _Subzone3NormalIndices.x,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult sz3G = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone3NormalGUVParams, _Subzone3NormalGFadeParams, _Subzone3NormalIndices.y,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult sz3B = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone3NormalBUVParams, _Subzone3NormalBFadeParams, _Subzone3NormalIndices.z,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult sz3A = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone3NormalAUVParams, _Subzone3NormalAFadeParams, _Subzone3NormalIndices.w,
        normCtx, worldNormal, bitangent, worldTangent);
    APPLY_SZ(sz3R, sz3SzFilter.x, biomeWeightNorm.x);
    APPLY_SZ(sz3G, sz3SzFilter.y, biomeWeightNorm.y);
    APPLY_SZ(sz3B, sz3SzFilter.z, biomeWeightNorm.z);
    APPLY_SZ(sz3A, sz3SzFilter.w, biomeWeightNorm.w);

    NormalLayerResult sz4R = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone4NormalRUVParams, _Subzone4NormalRFadeParams, _Subzone4NormalIndices.x,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult sz4G = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone4NormalGUVParams, _Subzone4NormalGFadeParams, _Subzone4NormalIndices.y,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult sz4B = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone4NormalBUVParams, _Subzone4NormalBFadeParams, _Subzone4NormalIndices.z,
        normCtx, worldNormal, bitangent, worldTangent);
    NormalLayerResult sz4A = SampleArrayNormal(_SubZonesNormalTextureArray, sampler_LinearRepeat,
        _Subzone4NormalAUVParams, _Subzone4NormalAFadeParams, _Subzone4NormalIndices.w,
        normCtx, worldNormal, bitangent, worldTangent);
    APPLY_SZ(sz4R, sz4SzFilter.x, biomeWeightNorm.x);
    APPLY_SZ(sz4G, sz4SzFilter.y, biomeWeightNorm.y);
    APPLY_SZ(sz4B, sz4SzFilter.z, biomeWeightNorm.z);
    APPLY_SZ(sz4A, sz4SzFilter.w, biomeWeightNorm.w);
    #undef APPLY_SZ

    // SZ blend order: scaledNormal -> Subzone4 -> Subzone3 -> Mid -> Large.
    float3 blendedNormSz4 = BlendLayerNormal(scaledNormal, sz4R, sz4G, sz4B, sz4A,
                                             biomeWeightNorm, worldTangent, normalFade, cameraDist);
    float3 blendedNormSz3 = BlendLayerNormal(blendedNormSz4, sz3R, sz3G, sz3B, sz3A,
                                             biomeWeightNorm, worldTangent, normalFade, cameraDist);
    float3 blendedNormMid = BlendLayerNormal(blendedNormSz3, midR, midG, midB, midA,
                                             biomeWeightNorm, worldTangent, normalFade, cameraDist);
    float3 blendedNorm    = BlendLayerNormal(blendedNormMid, largeR, largeG, largeB, largeA,
                                             biomeWeightNorm, worldTangent, normalFade, cameraDist);
#else
    // Non-SZ blend order: scaledNormal -> Mid -> Large.
    float3 blendedNormMid = BlendLayerNormal(scaledNormal, midR, midG, midB, midA,
                                             biomeWeightNorm, worldTangent, normalFade, cameraDist);
    float3 blendedNorm    = BlendLayerNormal(blendedNormMid, largeR, largeG, largeB, largeA,
                                             biomeWeightNorm, worldTangent, normalFade, cameraDist);
#endif

    // Height-map sampling.  Per-biome-channel samples weighted by
    // `hmBiomeWeight.<ch>`, then `diffs = xy - zw` becomes the slope-gradient
    // input.  Non-SZ samples Large + Med only; SZ also samples Subzone3 +
    // Subzone4 and scales every sample by per-pixel filter factors built from
    // `subzoneWeight` dotted with the family's filter uniforms.  `diffs.aux`
    // comes from the subzone-mask sample in non-SZ, or a second biome-mask
    // sample in SZ.
    float2 hmFaceUV     = float2(2.0 * uv.x, uv.y);
    // Use normLocalPos.xz (unit-length), not raw localPos.xz -- raw localPos
    // is planet-radius-scaled (~600000 on Kerbin), which makes scale*localPos
    // huge and saturates the gradient.
    float2 hmLocalHalf  = normLocalPos.xz * 0.5;
    float  absY2        = absY * absY;
    float  hmNormYBlend = 1.0 - absY * absY2 * absY2;     // 1 - |y|^5
    HmSampleCtx hmCtx;
    hmCtx.faceUV       = hmFaceUV;
    hmCtx.localUV      = hmLocalHalf;
    hmCtx.hmNormYBlend = hmNormYBlend;

#ifdef SUB_ZONES_ENABLED
    // largeSzFilter / midSzFilter / sz3SzFilter / sz4SzFilter were computed
    // above (before the normal blend) for use in the per-layer normal scaling;
    // they're reused here to scale the per-channel height-map accumulation.
    HmAccum hmAcc0  = (HmAccum)0;
    HmAccum hmAccR  = AccumHeightBiome_SZ(hmBiomeWeight.x,
        float4(largeSzFilter.x, midSzFilter.x, sz3SzFilter.x, sz4SzFilter.x),
        _LargeGradienceR,    sampler_LinearRepeat, _LargeHeightMapUVScales.x,
        _MidGradienceR,      sampler_LinearRepeat, _MediumHeightMapUVScales.x,
        _Subzone3GradienceR, sampler_LinearRepeat, _Subzone3HeightMapUVScales.x,
        _Subzone4GradienceR, sampler_LinearRepeat, _Subzone4HeightMapUVScales.x,
        hmCtx, hmAcc0);
    HmAccum hmAccRG = AccumHeightBiome_SZ(hmBiomeWeight.y,
        float4(largeSzFilter.y, midSzFilter.y, sz3SzFilter.y, sz4SzFilter.y),
        _LargeGradienceG,    sampler_LinearRepeat, _LargeHeightMapUVScales.y,
        _MidGradienceG,      sampler_LinearRepeat, _MediumHeightMapUVScales.y,
        _Subzone3GradienceG, sampler_LinearRepeat, _Subzone3HeightMapUVScales.y,
        _Subzone4GradienceG, sampler_LinearRepeat, _Subzone4HeightMapUVScales.y,
        hmCtx, hmAccR);
    HmAccum hmAccRGB = AccumHeightBiome_SZ(hmBiomeWeight.z,
        float4(largeSzFilter.z, midSzFilter.z, sz3SzFilter.z, sz4SzFilter.z),
        _LargeGradienceB,    sampler_LinearRepeat, _LargeHeightMapUVScales.z,
        _MidGradienceB,      sampler_LinearRepeat, _MediumHeightMapUVScales.z,
        _Subzone3GradienceB, sampler_LinearRepeat, _Subzone3HeightMapUVScales.z,
        _Subzone4GradienceB, sampler_LinearRepeat, _Subzone4HeightMapUVScales.z,
        hmCtx, hmAccRG);
    HmAccum hmFinal = AccumHeightBiome_SZ(hmBiomeWeight.w,
        float4(largeSzFilter.w, midSzFilter.w, sz3SzFilter.w, sz4SzFilter.w),
        _LargeGradienceA,    sampler_LinearRepeat, _LargeHeightMapUVScales.w,
        _MidGradienceA,      sampler_LinearRepeat, _MediumHeightMapUVScales.w,
        _Subzone3GradienceA, sampler_LinearRepeat, _Subzone3HeightMapUVScales.w,
        _Subzone4GradienceA, sampler_LinearRepeat, _Subzone4HeightMapUVScales.w,
        hmCtx, hmAccRGB);
    // SZ sources `diffs.aux` from a second biome-mask sample at the same UV
    // (the runtime binds the same texture to two slots).
    float4 biomeMaskAuxSample = _BiomeMaskTex.Sample(sampler_LinearRepeat, uv);
#else
    HmAccum hmAcc0  = (HmAccum)0;
    HmAccum hmAccR  = AccumHeightBiome(hmBiomeWeight.x,
        _LargeGradienceR, sampler_LinearRepeat, _LargeHeightMapUVScales.x,
        _MidGradienceR,   sampler_LinearRepeat, _MediumHeightMapUVScales.x,
        hmCtx, hmAcc0);
    HmAccum hmAccRG = AccumHeightBiome(hmBiomeWeight.y,
        _LargeGradienceG, sampler_LinearRepeat, _LargeHeightMapUVScales.y,
        _MidGradienceG,   sampler_LinearRepeat, _MediumHeightMapUVScales.y,
        hmCtx, hmAccR);
    HmAccum hmAccRGB = AccumHeightBiome(hmBiomeWeight.z,
        _LargeGradienceB, sampler_LinearRepeat, _LargeHeightMapUVScales.z,
        _MidGradienceB,   sampler_LinearRepeat, _MediumHeightMapUVScales.z,
        hmCtx, hmAccRG);
    HmAccum hmFinal = AccumHeightBiome(hmBiomeWeight.w,
        _LargeGradienceA, sampler_LinearRepeat, _LargeHeightMapUVScales.w,
        _MidGradienceA,   sampler_LinearRepeat, _MediumHeightMapUVScales.w,
        hmCtx, hmAccRGB);
#endif

    HmDiffs diffs;
    diffs.large = hmFinal.large.xy - hmFinal.large.zw;
    diffs.mid   = hmFinal.med.xy   - hmFinal.med.zw;
#ifdef SUB_ZONES_ENABLED
    diffs.sz3 = hmFinal.sz3.xy - hmFinal.sz3.zw;
    diffs.sz4 = hmFinal.sz4.xy - hmFinal.sz4.zw;
    diffs.aux = biomeMaskAuxSample.xy - biomeMaskAuxSample.zw;
#else
    diffs.sz3 = (float2)0;
    diffs.sz4 = (float2)0;
    diffs.aux = subzoneWeight.xy - subzoneWeight.zw;
#endif

    // Apply decal loop -- mutates diffs.aux/large/mid and the running normal
    // accumulator.  Compiles to nothing when DECALS_ENABLED is off (pass 13).
    ApplyDecals(diffs, blendedNorm, localPos, worldTangent, cameraDist,
                V2F_TRIANGLE_DATA(i));

    // Tex0/1/2/3: per-layer ComputeLayerPhi gate*heightW*slopeW for each of
    // the four biome channels (LAYERS4(R, x), (G, y), (B, z), (A, w)).
    bool4 biomeActive = biomeWeightNorm > 0.0;
    float height      = i.uvHeight.z;

// Per-channel 4-layer weight expansion: binds the named `_SmallBiome<C>*`
// uniforms via ## token-pasting and forwards them to ComputeChannelLayerWeights
// along with the per-pixel gate `active` and the surrounding-scope `height`,
// `subzoneWeight`, and `diffs`.  Lets the frag write `LAYERS4(R, biomeActive.x)`
// instead of repeating 22 args per channel.
//
// Differences between branches:
//   - Base path's per-layer gate is the constant material product
//     `_SmallHeightWeight<C> * _SmallEnable<C>`; SZ replaces it with
//     `_SmallEnable<C> * dot(subzoneWeight, _SmallSubzoneWeight<C><I>)` so the
//     gate varies per-pixel along subzone seams.
//   - SZ also threads the per-layer `_SmallSubzoneTint<C><I>_{R,G}.w` scalars
//     into ComputeLayerPhi, where they multiply diffs.sz3 / diffs.sz4 in the
//     slope-gradient sum.  Base passes 0 for those tint factors.
#ifdef SUB_ZONES_ENABLED
#define LAYERS4(C, active) ComputeChannelLayerWeights( \
    active, _SmallBiome##C, \
    _SmallEnable##C * float4( \
        dot(subzoneWeight, _SmallSubzoneWeight##C##1), \
        dot(subzoneWeight, _SmallSubzoneWeight##C##2), \
        dot(subzoneWeight, _SmallSubzoneWeight##C##3), \
        dot(subzoneWeight, _SmallSubzoneWeight##C##4)), \
    height, \
    _SmallBiome##C##HeightParams1, _SmallBiome##C##HeightParams2, \
    _SmallBiome##C##HeightParams3, _SmallBiome##C##HeightParams4, \
    _SmallBiomeHeightEnable##C, \
    _SmallBiome##C##SlopeParams1,  _SmallBiome##C##SlopeParams2, \
    _SmallBiome##C##SlopeParams3,  _SmallBiome##C##SlopeParams4, \
    _SmallBiomeSlopeEnable##C, \
    _SmallBiome##C##GradMapWeights1, _SmallBiome##C##GradMapWeights2, \
    _SmallBiome##C##GradMapWeights3, _SmallBiome##C##GradMapWeights4, \
    float4(_SmallSubzoneTint##C##1_G.w, _SmallSubzoneTint##C##2_G.w, \
           _SmallSubzoneTint##C##3_G.w, _SmallSubzoneTint##C##4_G.w), \
    float4(_SmallSubzoneTint##C##1_R.w, _SmallSubzoneTint##C##2_R.w, \
           _SmallSubzoneTint##C##3_R.w, _SmallSubzoneTint##C##4_R.w), \
    diffs)
#else
#define LAYERS4(C, active) ComputeChannelLayerWeights( \
    active, _SmallBiome##C, _SmallHeightWeight##C * _SmallEnable##C, height, \
    _SmallBiome##C##HeightParams1, _SmallBiome##C##HeightParams2, \
    _SmallBiome##C##HeightParams3, _SmallBiome##C##HeightParams4, \
    _SmallBiomeHeightEnable##C, \
    _SmallBiome##C##SlopeParams1,  _SmallBiome##C##SlopeParams2, \
    _SmallBiome##C##SlopeParams3,  _SmallBiome##C##SlopeParams4, \
    _SmallBiomeSlopeEnable##C, \
    _SmallBiome##C##GradMapWeights1, _SmallBiome##C##GradMapWeights2, \
    _SmallBiome##C##GradMapWeights3, _SmallBiome##C##GradMapWeights4, \
    (float4)0, (float4)0, \
    diffs)
#endif

    PrepassOutput o;
    o.tex0   = LAYERS4(R, biomeActive.x);
    o.tex1   = LAYERS4(G, biomeActive.y);
    o.tex2   = LAYERS4(B, biomeActive.z);
    o.tex3   = LAYERS4(A, biomeActive.w);
    o.normal = float4(blendedNorm, 1.0);
    return o;
}

#endif // PREPASS_CGINC
