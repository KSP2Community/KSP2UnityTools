#ifndef DEFERREDBASE_CGINC
#define DEFERREDBASE_CGINC

// ============================================================================
// DeferredBase.cginc
//
// PASS_DEFERRED_BASE fragment (passes 1, 2, 3).  Pass 1 is the no-decal
// variant; passes 2 / 3 fold a per-decal albedo blend (PACKED4 / INFINITE)
// onto the same base.  This file currently implements pass 1 only.
// ============================================================================

#include "Vertex.cginc"

// ---------------------------------------------------------------------------
// Pass-1 texture / uniform declarations
// ---------------------------------------------------------------------------
Texture2D<float4> _AlbedoScaledTex;
Texture2D<float4> _PackedScaledTex;            // metallic/occlusion/emission/smoothness
Texture2D<float4> _EmissionScaledTex;
Texture2D<float4> _LocalSpacePrepassTex4;      // world-space normal RT (sampled at screenUV)
// `_BiomeMaskTex` is declared in Common.cginc (used by the prepass too).

float    _Transition;
float4   _AlbedoScaledFadeParams;
float4   _PackedScaledFadeParams;
float4   _EmissionScaledFadeParams;
float    _EmissionScale;
float4   _DistanceResampleFadeRangesPos;
float4   _DistanceResampleFadeRangesNeg;
float4   _DistanceResampleAlbedoOpacity;
float4   _DistanceResampleNormalOpacity;

// Atmospheric directional lights — populated from C# via
// CelestialBodyGIProbeData.ApplyGlobal() as Shader.SetGlobalVectorArray.
//   _SGAmplitudeAndSharpness[i]: .xyz = color * intensity, .w = sharpness
//   _SGAxis[i]                 : .xyz = world-space direction
// NOTE: must be float4 (NOT half4) to match Unity's Shader.SetGlobalVectorArray
// binding ABI -- Vector4[] globals are 16 bytes per element.  Declaring as
// half4 produces a different cbuffer layout under DXC that strips the .w
// component (observed: .w reads as the property default regardless of what
// C# binds).
float4 _SGAmplitudeAndSharpness[3];
float4 _SGAxis[3];

// ---------------------------------------------------------------------------
// Dither alpha test
// ---------------------------------------------------------------------------
// 4x4 Bayer ordered-dither, n/17 for n in [1..16].
static const float4x4 kDitherMatrix = float4x4(
     1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
    13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
     4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
    16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0);

void DitherAlphaTest(float2 screenPx, float transition)
{
    uint2 dc = uint2(screenPx) & 3u;
    if ((1.0 - transition) < kDitherMatrix[dc.y][dc.x])
        discard;
}

// ---------------------------------------------------------------------------
// Distance-fade / resample / projection helpers
// ---------------------------------------------------------------------------
float ComputeDistanceFade(float dist, float4 p)
{
    float t = saturate((dist - p.x) / max(p.y, 0.01));
    return lerp(p.z, p.w, t);
}

float2 ComputeResampleOpacity(
    float normDist, float4 fadePos, float4 fadeNeg,
    float4 albedoOp, float4 normalOp)
{
    float4 fadeT = (normDist - fadeNeg.wzyx) / (fadePos.wzyx - fadeNeg.wzyx);
    if (0.001 < fadeT.x) { float t = saturate(fadeT.x);
        return float2(lerp(albedoOp.z, albedoOp.w, t), lerp(normalOp.z, normalOp.w, t)); }
    if (0.001 < fadeT.y) { float t = saturate(fadeT.y);
        return float2(lerp(albedoOp.y, albedoOp.z, t), lerp(normalOp.y, normalOp.z, t)); }
    if (0.001 < fadeT.z) { float t = saturate(fadeT.z);
        return float2(lerp(albedoOp.x, albedoOp.y, t), lerp(normalOp.x, normalOp.y, t)); }
    if (0.001 < fadeT.w) { float t = saturate(fadeT.w);
        return float2(lerp(1.0, albedoOp.x, t), lerp(1.0, normalOp.x, t)); }
    return float2(1.0, 1.0);
}

float ComputeProjRatio(float4 projSample)
{
    return projSample.x / max(dot(projSample, 1.0), 0.001);
}

void ComputeMetallicSplit(float3 baseColor, float metallic,
                          out float3 diffuse, out float3 specularF0)
{
    specularF0 = mad(metallic, baseColor - 0.04, 0.04);
    diffuse    = mad(-metallic, 0.96, 0.96) * baseColor;
}

// ---------------------------------------------------------------------------
// SH / atmospheric / emission encoding
// ---------------------------------------------------------------------------
// Evaluates the SH L0+L1 + L2 (vertex-baked) bands, plus the LPPV (Light
// Probe Proxy Volume) path when `unity_ProbeVolumeParams.x == 1.0`.
float3 EvaluateSphericalHarmonics(float3 worldNormal, float3 worldPos)
{
    if (unity_ProbeVolumeParams.x != 1.0)
        return SHEvalLinearL0L1(float4(worldNormal, 1.0));

    float3 probePos = (unity_ProbeVolumeParams.y == 1.0)
        ? mul(unity_ProbeVolumeWorldToObject, float4(worldPos, 1.0)).xyz
        : worldPos;
    float3 probeUV = (probePos - unity_ProbeVolumeMin) * unity_ProbeVolumeSizeInv;
    float halfTexel = unity_ProbeVolumeParams.z * 0.5;
    float probeX    = clamp(probeUV.x * 0.25, halfTexel, 0.25 - halfTexel);

    float4 nW1 = float4(worldNormal, 1.0);
    float3 sh;
    sh.x = dot(unity_ProbeVolumeSH.Sample(samplerunity_ProbeVolumeSH, float3(probeX,        probeUV.yz)), nW1);
    sh.y = dot(unity_ProbeVolumeSH.Sample(samplerunity_ProbeVolumeSH, float3(probeX + 0.25, probeUV.yz)), nW1);
    sh.z = dot(unity_ProbeVolumeSH.Sample(samplerunity_ProbeVolumeSH, float3(probeX + 0.50, probeUV.yz)), nW1);
    return sh;
}

float3 EvaluateAtmosphericLighting(float3 worldNormal)
{
    float3x3 lightDirs = float3x3(_SGAxis[0].xyz, _SGAxis[1].xyz, _SGAxis[2].xyz);
    float3   shininess = float3(_SGAmplitudeAndSharpness[0].w,
                                _SGAmplitudeAndSharpness[1].w,
                                _SGAmplitudeAndSharpness[2].w);
    float3   spec      = exp((mul(lightDirs, worldNormal) - 1.0) * shininess);
    float3x3 lightCols = float3x3(_SGAmplitudeAndSharpness[0].xyz,
                                  _SGAmplitudeAndSharpness[1].xyz,
                                  _SGAmplitudeAndSharpness[2].xyz);
    return mul(spec, lightCols);
}

float4 EncodeEmission(float3 lighting)
{
#ifdef UNITY_HDR_ON
    return float4(lighting, 1.0);
#else
    return float4(exp2(-lighting), 1.0);
#endif
}

// ===========================================================================
// Fragment shader
// ===========================================================================
GBufferOutput frag(V2F i)
{
    float2 uv       = i.uvHeight.xy;
    float3 worldPos = float3(i.worldNormalPosX.w, i.bitangentPosY.w, i.worldTangentPosZ.w);
    float2 screenUV = i.screenPos.xy / i.screenPos.z;

    DitherAlphaTest(screenUV * _ScreenParams.xy, _Transition);

    // Sample the scaled-space satellite maps, the prepass world normal at
    // screenUV, and the biome mask + satellite maps at terrain UV.
    float3 normalSample   = _LocalSpacePrepassTex4.Sample(sampler_LinearRepeat, screenUV).xyz;
    float4 albedoSample   = _AlbedoScaledTex.Sample(sampler_LinearRepeat, uv);
    float4 packedSample   = _PackedScaledTex.Sample(sampler_LinearRepeat, uv);
    float4 emissionSample = _EmissionScaledTex.Sample(sampler_LinearRepeat, uv);
    // projRatio source: per-biome coverage from _BiomeMaskTex (R/G/B/A weights).
    // The eventual `R / sum(R,G,B,A)` is "how dominant is biome R at this pixel".
    float4 projSample     = _BiomeMaskTex.Sample(sampler_LinearRepeat, uv);

    float cameraDist   = distance(_WorldSpaceCameraPos, worldPos);
    float albedoFade   = ComputeDistanceFade(cameraDist, _AlbedoScaledFadeParams);
    float packedFade   = ComputeDistanceFade(cameraDist, _PackedScaledFadeParams);
    float emissionFade = ComputeDistanceFade(cameraDist, _EmissionScaledFadeParams);

    // Multi-cascade resample opacity.
    float  normDist       = min(cameraDist * 2e-5, 1.0);
    float2 resOp          = ComputeResampleOpacity(
        normDist,
        _DistanceResampleFadeRangesPos, _DistanceResampleFadeRangesNeg,
        _DistanceResampleAlbedoOpacity, _DistanceResampleNormalOpacity);
    float albedoResample  = resOp.x;
    float normalResample  = resOp.y;

    // Albedo: distance-fade then attenuate by resample opacity.
    float3 scaledAlbedo = albedoFade * albedoSample.xyz;
    float3 fadedAlbedo  = lerp(scaledAlbedo, 0.0, albedoResample * (1.0 - albedoFade));

    // Normal: blend scaled-space normal back toward unmodified geometry at range.
    //   worldNormal = normalSample * (1 - 0.5 * normalFade)
    float  normalFadeT = ComputeDistanceFade(cameraDist, _NormalScaledFadeParams);
    float  normalFade  = normalResample * (1.0 - normalFadeT);
    float3 worldNormal = mad(normalFade * normalSample, -0.5, normalSample);

    // Packed map: metallic / smoothness / occlusion via .xyw swizzle
    // (packed = metallic, occlusion, emission, smoothness; but the deferred
    // layout maps .xyw into (metallic, smoothness, occlusion) via swizzle:
    // .x = metallic, .y = smoothness, .w = occlusion).
    float  packedResample = normalResample * (1.0 - packedFade);
    float3 packedScaled   = packedFade * (1.0 - packedResample) * packedSample.xyw;
    float  metallic   = packedScaled.x;
    float  smoothness = packedScaled.y;
    float  occlusion  = packedScaled.z;

    // GBuffer split.
    float3 diffuse, specularF0;
    ComputeMetallicSplit(fadedAlbedo, metallic, diffuse, specularF0);

    // Indirect lighting: SH (LPPV or L0+L1) + per-vertex L2 + atmospheric specular.
    float3 sh        = EvaluateSphericalHarmonics(worldNormal, worldPos);
    float3 atmosSpec = EvaluateAtmosphericLighting(worldNormal);
    float3 shLight   = max(sh + i.lighting.xyz, 0.0);

    // Emission accumulation.
    float  projRatio = ComputeProjRatio(projSample);
    float3 emContrib = (emissionFade * normalResample)
                     * (emissionFade * (emissionSample.xyz * _EmissionScale));
    float3 lighting  = mad(
        emContrib,
        packedFade * packedSample.z,
        mad(shLight, mad(1.0 - projRatio, smoothness, smoothness), atmosSpec) * fadedAlbedo);

    GBufferOutput o;
    o.albedoSmoothness  = float4(diffuse,    smoothness);
    o.specularOcclusion = float4(specularF0, occlusion);
    o.normalProjRatio   = float4(worldNormal * 0.5 + 0.5, projRatio);
    o.emission          = EncodeEmission(lighting);
    return o;
}

#endif // DEFERREDBASE_CGINC
