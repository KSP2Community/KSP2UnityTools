#ifndef DEFERREDBIOME_CGINC
#define DEFERREDBIOME_CGINC

// ============================================================================
// DeferredBiome.cginc
//
// PASS_DEFERRED_BIOME fragment (passes 4..11).
//
// All eight additive passes are *single*-biome shaders that select different
// triangle subsets via the vertex `BIOME_MASK` clip-distance test.  The
// fragment body chooses which biome (R/G/B/A) to read uniforms for via
// `BIOME_FRAG_<X>` (set per pass in the .shader; named to avoid collision
// with `BIOME_CHANNEL_<X>` in Common.cginc which is the numeric channel-bit
// mask for the vertex clip-distance test).  Passes 4..7 use single-axis
// (Y-plane only) triplanar and clip on the single-channel masks
// (1/2/4/8 = R/G/B/A).  Passes 8..11 use full 3-axis triplanar and clip on
// the multi-channel masks (3/7/5/10 = R+G/R+G+B/R+B/G+A) -- same biome
// channels as 4..7 respectively, rendered on the harder-overlap triangle
// subsets.  Both use bit 31 (TRIPLANAR_BUCKET_ADDITIVE).
//
// Per-pass shader define matrix:
//      pass | BIOME_MASK   | BIOME_FRAG_? | TRIPLANAR_3AXIS
//      ---- | ------------ | ------------ | ---------------
//        4  |    1 (R)     |     R        |  no
//        5  |    2 (G)     |     G        |  no
//        6  |    4 (B)     |     B        |  no
//        7  |    8 (A)     |     A        |  no
//        8  |    3 (R+G)   |     R        |  yes
//        9  |    7 (R+G+B) |     G        |  yes
//       10  |    5 (R+B)   |     B        |  yes
//       11  |   10 (G+A)   |     A        |  yes
//
// The biome-specific math (per-layer SZ-weighted tint/brightness/heightWeight,
// 4× ProcessBiomeLayer triplanar sample, height-blend, 4-layer composition)
// is factored into `ProcessBiomeAdditive(BiomeMaterial, ...)`, which is
// biome-agnostic.  Each pass populates a `BiomeMaterial` via
// `MakeBiomeMaterial<X>()` (one per channel).
// ============================================================================

#include "Vertex.cginc"
#include "AntiTile.cginc"

// ---------------------------------------------------------------------------
// Pass-shared uniforms
// ---------------------------------------------------------------------------
float    _Transition;
float4   _AlbedoScaledFadeParams;
float4   _PackedScaledFadeParams;
float4   _HeightblendFactor;
float4   _AlphaToHeightFadeParams;
float4   _DistanceResampleFadeRangesPos;
float4   _DistanceResampleFadeRangesNeg;
float4   _DistanceResampleUVScales;
float4   _DistanceResampleAlbedoOpacity;
float4   _DistanceResampleNormalOpacity;
float4x4 TriplanarBasis;
float4x4 TriplanarToWorld;

// Atmospheric directional lights — populated from C# via
// CelestialBodyGIProbeData.ApplyGlobal() as Shader.SetGlobalVectorArray.
//   _SGAmplitudeAndSharpness[i]: .xyz = color * intensity, .w = sharpness
//   _SGAxis[i]                 : .xyz = world-space direction
// See DeferredBase.cginc for why these must be float4 (not half4).
float4 _SGAmplitudeAndSharpness[3];
float4 _SGAxis[3];

// Per-channel small-biome material uniforms — declared for all four channels
// since one of the four passes 4-7 binds each.  Unity tolerates unused
// property bindings, so the unused channels' uniforms read defaults harmlessly.
//
// SUB_ZONES_ENABLED replaces the per-layer scalar tint/brightness/heightWeight
// with per-subzone-weighted blends; the SZ uniforms are also declared per-channel.
// See the BIOME_MATERIAL_DECLS macro to read the per-channel block layout.
#define BIOME_MATERIAL_DECLS(CH) \
    float4 _SmallBiome##CH; \
    float4 _SmallHeightWeight##CH; \
    float4 _SmallWeightSoftness##CH; \
    float4 _SmallUVScale##CH; \
    float4 _SmallUVOffset##CH; \
    float4 _SmallTint##CH##1, _SmallTint##CH##2, _SmallTint##CH##3, _SmallTint##CH##4; \
    float4 _SmallBrightness##CH; \
    float4 _SmallContrast##CH; \
    float4 _SmallSaturation##CH; \
    float4 _SmallNormalStrength##CH; \
    float4 _SmallGlossStrength##CH; \
    float4 _SmallMetallicStrength##CH; \
    float4 _SmallAOStrength##CH; \
    float4 _SmallEnable##CH; \
    float4 _SmallDistanceResampleMax##CH; \
    float4 _SmallSubzoneWeight##CH##1, _SmallSubzoneWeight##CH##2, _SmallSubzoneWeight##CH##3, _SmallSubzoneWeight##CH##4; \
    float4 _SmallSubzoneBrightness##CH##1, _SmallSubzoneBrightness##CH##2, _SmallSubzoneBrightness##CH##3, _SmallSubzoneBrightness##CH##4; \
    float4 _SmallSubzoneTint##CH##1_R, _SmallSubzoneTint##CH##1_G, _SmallSubzoneTint##CH##1_B, _SmallSubzoneTint##CH##1_A; \
    float4 _SmallSubzoneTint##CH##2_R, _SmallSubzoneTint##CH##2_G, _SmallSubzoneTint##CH##2_B, _SmallSubzoneTint##CH##2_A; \
    float4 _SmallSubzoneTint##CH##3_R, _SmallSubzoneTint##CH##3_G, _SmallSubzoneTint##CH##3_B, _SmallSubzoneTint##CH##3_A; \
    float4 _SmallSubzoneTint##CH##4_R, _SmallSubzoneTint##CH##4_G, _SmallSubzoneTint##CH##4_B, _SmallSubzoneTint##CH##4_A

BIOME_MATERIAL_DECLS(R);
BIOME_MATERIAL_DECLS(G);
BIOME_MATERIAL_DECLS(B);
BIOME_MATERIAL_DECLS(A);

// Texture arrays for triplanar small-biome sampling.
Texture2DArray<float4> _SmallAlbedoArray;
Texture2DArray<float4> _SmallNormalArray;
Texture2DArray<float4> _SmallMetalArray;

// Prepass RTs (written by Prepass.cginc):
//   _LocalSpacePrepassTex0 = LAYERS4(R)        (per-layer biome-R weights)
//   _LocalSpacePrepassTex1 = LAYERS4(G)
//   _LocalSpacePrepassTex2 = LAYERS4(B)
//   _LocalSpacePrepassTex3 = LAYERS4(A)
//   _LocalSpacePrepassTex4 = world normal
// Each additive biome pass reads its own LAYERS4 slot for `layerWeight` and
// reads tex4 for the prepass world normal.
Texture2D<float4> _LocalSpacePrepassTex0;
Texture2D<float4> _LocalSpacePrepassTex1;
Texture2D<float4> _LocalSpacePrepassTex2;
Texture2D<float4> _LocalSpacePrepassTex3;
Texture2D<float4> _LocalSpacePrepassTex4;

// ---------------------------------------------------------------------------
// Dither alpha test (matches DeferredBase.cginc; copied here so the helper
// stays local to each pass-kind cginc).
// ---------------------------------------------------------------------------
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
// Per-layer biome processing
// ---------------------------------------------------------------------------
struct BiomeLayerResult
{
    float3 nearColor;       // saturation-graded albedo at farUV
    float3 farColor;        // saturation-graded albedo at nearUV
    float3 nearNormal;      // world-space normal from farUV sample, scaled by normalStrength
    float3 farNormal;       // world-space normal from nearUV sample, scaled by normalStrength
    float  nearHeightAlpha; // triWeight.y * albedo.w * tint.w (farUV)
    float  farHeightAlpha;  // triWeight.y * albedo.w * tint.w (nearUV)
    float  nearMetallic;    // metallic with 15.0 threshold (farUV)
    float  farMetallic;     // (nearUV)
    float  nearGloss;       // gloss with 15.0 threshold (farUV)
    float  farGloss;        // (nearUV)
    float  nearAO;          // pow(packed.z, aoStrength) (farUV)
    float  farAO;           // (nearUV)
};

// Triplanar UDN (Unreal Derivative Normal) blend: decode tangent-space normal
// from packed.wy, recover Z, and reorient using triplanar blend weights.
float3 ReorientTriplanarNormal(
    float4 packed, float3 triN, float3 triWeight, float3 triSign, bool triN_zPositive)
{
    float tsX = mad(packed.w, 2.0, -1.0);
    float tsY = mad(packed.y, 2.0, -1.0);
    float tsZ = sqrt(1.0 - min(dot(float2(tsX, tsY), float2(tsX, tsY)), 1.0));

    float3 absN1 = abs(triN) + 1.0;

    float dotZY = dot(float2(triN.z, triN.y), 1.0.xx);
    float3 xBlend = triWeight.x * float3(
        triSign.x * dotZY,
        ((dotZY * triN.y) / absN1.x) - 1.0,
        ((dotZY * triN.z) / absN1.x) - 1.0);

    float negTsX = -tsX;
    float negTsY = -tsY;
    float yDot = dot(float3(triN.x, triN.z, absN1.y), float3(negTsX, negTsY, tsZ));

    float dotXY = dot(float2(triN.x, triN.y), 1.0.xx);
    float3 zBlend = float3(
        ((dotXY * triN.x) / absN1.z) - 1.0,
        ((dotXY * triN.y) / absN1.z) - 1.0,
        (triN_zPositive ? 1.0 : -1.0) * dotXY);

    float3 blended = triN
        + mad(triWeight.z, zBlend,
              mad(triWeight.y,
                  float3((-negTsX) + ((yDot * triN.x) / absN1.y),
                         triSign.y * ((-tsZ) + yDot),
                         (-negTsY) + ((yDot * triN.z) / absN1.y)),
                  xBlend));
    return normalize(blended);
}

BiomeLayerResult ProcessBiomeLayer(
    float distResampleMax,
    float biomeIdx,
    float uvScale,
    float uvOffset,
    float4 tint,
    float brightness,
    float contrast,
    float saturation,
    float normalStrength,
    float metallicStrength,
    float glossStrength,
    float aoStrength,
    float baseTriU, float baseTriV,
    float3 triN,
    float3 triWeight,
    float3 triSign, bool triN_zPositive,
    float4 cascadeT)
{
    BiomeLayerResult result;

    // Cascade UV-scale selection.
    float4 uvScales;
    if (3.0 < distResampleMax)       uvScales = _DistanceResampleUVScales;
    else if (2.0 < distResampleMax)  uvScales = float4(_DistanceResampleUVScales.x, _DistanceResampleUVScales.y, _DistanceResampleUVScales.z, _DistanceResampleUVScales.z);
    else if (1.0 < distResampleMax)  uvScales = float4(_DistanceResampleUVScales.x, _DistanceResampleUVScales.y, _DistanceResampleUVScales.y, _DistanceResampleUVScales.y);
    else if (0.0 < distResampleMax)  uvScales = _DistanceResampleUVScales.xxxx;
    else                              uvScales = 1.0.xxxx;

    float nearScale = 1.0, farScale = 1.0;
    float4 uvScalesExt = float4(1.0, uvScales.xyz);
    [unroll] for (int j = 0; j < 4; j++)
    {
        if (cascadeT[j] > 0.001)
        {
            nearScale = uvScales[j];
            farScale  = (cascadeT[j] >= 1.0) ? uvScales[j] : uvScalesExt[j];
        }
    }

    float2 nearUV = mad(float2(baseTriU, baseTriV), nearScale * uvScale, uvOffset);
    float2 farUV  = mad(float2(baseTriU, baseTriV), farScale  * uvScale, uvOffset);

    // ddx_coarse/ddy_coarse of the un-hashed near/far UVs feed SampleGrad
    // when ANTI_TILE_QUALITY_ON is on.  Ignored on the AT-off path.
    float2 ddxNearUV = ddx_coarse(nearUV), ddyNearUV = ddy_coarse(nearUV);
    float2 ddxFarUV  = ddx_coarse(farUV),  ddyFarUV  = ddy_coarse(farUV);

    float4 farAlbedo  = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, farUV,  biomeIdx, ddxFarUV,  ddyFarUV);
    float4 nearAlbedo = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, nearUV, biomeIdx, ddxNearUV, ddyNearUV);
    float4 farPacked  = SampleAT(_SmallNormalArray, sampler_LinearRepeat, farUV,  biomeIdx, ddxFarUV,  ddyFarUV);
    float4 nearPacked = SampleAT(_SmallNormalArray, sampler_LinearRepeat, nearUV, biomeIdx, ddxNearUV, ddyNearUV);

    float3 reorientedFar  = ReorientTriplanarNormal(farPacked,  triN, triWeight, triSign, triN_zPositive);
    float3 reorientedNear = ReorientTriplanarNormal(nearPacked, triN, triWeight, triSign, triN_zPositive);

    float3 gradedFar = mad(mad(triWeight.y * farAlbedo.xyz, tint.xyz, brightness) - 0.21763764, contrast, 0.21763764);
    float lumFar = dot(gradedFar, float3(0.2126729, 0.7151522, 0.072175));
    result.nearColor = mad(saturation, gradedFar - lumFar, lumFar);

    float3 gradedNear = mad(mad(triWeight.y * nearAlbedo.xyz, tint.xyz, brightness) - 0.21763764, contrast, 0.21763764);
    float lumNear = dot(gradedNear, float3(0.2126729, 0.7151522, 0.072175));
    result.farColor = mad(saturation, gradedNear - lumNear, lumNear);

    result.nearNormal = mul((float3x3)TriplanarToWorld, reorientedFar)  * normalStrength;
    result.farNormal  = mul((float3x3)TriplanarToWorld, reorientedNear) * normalStrength;

    result.nearHeightAlpha = (triWeight.y * farAlbedo.w)  * tint.w;
    result.farHeightAlpha  = (triWeight.y * nearAlbedo.w) * tint.w;

    bool  metOver       = metallicStrength >= 15.0;
    float metFlag       = metOver ? 1.0 : 0.0;
    float metScale      = metFlag + (metOver ? 0.0 : metallicStrength);
    float metOffset     = (metFlag * (metallicStrength - 15.0)) * 0.2;
    result.nearMetallic = mad(triWeight.y * SampleAT(_SmallMetalArray, sampler_LinearRepeat, farUV,  biomeIdx, ddxFarUV,  ddyFarUV).x, metScale, metOffset);
    result.farMetallic  = mad(triWeight.y * SampleAT(_SmallMetalArray, sampler_LinearRepeat, nearUV, biomeIdx, ddxNearUV, ddyNearUV).x, metScale, metOffset);

    bool  glsOver  = glossStrength >= 15.0;
    float glsFlag  = glsOver ? 1.0 : 0.0;
    float glsScale = glsFlag + (glsOver ? 0.0 : glossStrength);
    float glsOff   = ((glossStrength - 15.0) * glsFlag) * 0.2;
    result.nearGloss = mad(triWeight.y * farPacked.x,  glsScale, glsOff);
    result.farGloss  = mad(triWeight.y * nearPacked.x, glsScale, glsOff);

    result.nearAO = pow(triWeight.y * farPacked.z,  aoStrength);
    result.farAO  = pow(triWeight.y * nearPacked.z, aoStrength);

    return result;
}

#ifdef TRIPLANAR_3AXIS
// ---------------------------------------------------------------------------
// 3-axis triplanar (passes 8..11)
// ---------------------------------------------------------------------------
// `ReorientTriplanarNormal3Axis` takes one (normal.w, normal.y) tangent-space
// pair per plane (X / Y / Z = sliced along world X / Y / Z axis), reconstructs
// per-plane TS normals, and blends them into a single object-space normal via
// triWeight.x/y/z.  `normalScale` is fixed at 1 here -- the outer per-pixel
// normalFade handles distance attenuation.
float3 ReorientTriplanarNormal3Axis(
    float2 normWY_X, float2 normWY_Y, float2 normWY_Z,
    float3 triN, float3 triWeight,
    float3 triSign, bool triN_zPositive)
{
    float3 tsX, tsY, tsZ;
    tsX.xy = normWY_X * 2.0 - 1.0;
    tsX.z  = sqrt(1.0 - min(dot(tsX.xy, tsX.xy), 1.0));
    tsY.xy = normWY_Y * 2.0 - 1.0;
    tsY.z  = sqrt(1.0 - min(dot(tsY.xy, tsY.xy), 1.0));
    tsZ.xy = normWY_Z * 2.0 - 1.0;
    tsZ.z  = sqrt(1.0 - min(dot(tsZ.xy, tsZ.xy), 1.0));

    float3 absN  = abs(triN) + 1.0;
    float  xDot  = dot(float3(triN.z, triN.y, absN.x), float3(-tsX.x, -tsX.y, tsX.z));
    float  yDot  = dot(float3(triN.x, triN.z, absN.y), float3(-tsY.x, -tsY.y, tsY.z));
    float  zDot  = dot(float3(triN.x, triN.y, absN.z), float3(-tsZ.x, -tsZ.y, tsZ.z));
    float  zSign = triN_zPositive ? 1.0 : -1.0;

    float3 blended;
    blended.x = triN.x
              + triWeight.z * (tsZ.x + (zDot * triN.x / absN.z))
              + triWeight.x * triSign.x * (-tsX.z + xDot)
              + triWeight.y * (tsY.x + (yDot * triN.x / absN.y));
    blended.y = triN.y
              + triWeight.z * (tsZ.y + (zDot * triN.y / absN.z))
              + triWeight.x * (tsX.y + (xDot * triN.y / absN.x))
              + triWeight.y * (triSign.y * (-tsY.z + yDot));
    blended.z = triN.z
              + triWeight.z * zSign * (-tsZ.z + zDot)
              + triWeight.x * (tsX.x + (xDot * triN.z / absN.x))
              + triWeight.y * (tsY.y + (yDot * triN.z / absN.y));
    return normalize(blended);
}

// 3-axis variant of ProcessBiomeLayer.  Samples the small-biome arrays at
// three plane UVs (YZ / XZ / XY), accumulates albedo / metal / packed weighted
// by triWeight.x/y/z, then reorients all three TS normals into one
// object-space normal via ReorientTriplanarNormal3Axis.
BiomeLayerResult ProcessBiomeLayer3Axis(
    float distResampleMax,
    float biomeIdx,
    float uvScale,
    float uvOffset,
    float4 tint,
    float brightness,
    float contrast,
    float saturation,
    float normalStrength,
    float metallicStrength,
    float glossStrength,
    float aoStrength,
    float2 baseUV_X, float2 baseUV_Y, float2 baseUV_Z,
    float3 triN,
    float3 triWeight,
    float3 triSign, bool triN_zPositive,
    float4 cascadeT)
{
    BiomeLayerResult result = (BiomeLayerResult)0;

    // Cascade UV-scale: identical forward k=0..3 scan and uvScalesExt fallback
    // as the single-axis path.
    float4 uvScales;
    if (3.0 < distResampleMax)       uvScales = _DistanceResampleUVScales;
    else if (2.0 < distResampleMax)  uvScales = float4(_DistanceResampleUVScales.x, _DistanceResampleUVScales.y, _DistanceResampleUVScales.z, _DistanceResampleUVScales.z);
    else if (1.0 < distResampleMax)  uvScales = float4(_DistanceResampleUVScales.x, _DistanceResampleUVScales.y, _DistanceResampleUVScales.y, _DistanceResampleUVScales.y);
    else if (0.0 < distResampleMax)  uvScales = _DistanceResampleUVScales.xxxx;
    else                              uvScales = 1.0.xxxx;

    float nearScale = 1.0, farScale = 1.0;
    float4 uvScalesExt = float4(1.0, uvScales.xyz);
    [unroll] for (int j = 0; j < 4; j++)
    {
        if (cascadeT[j] > 0.001)
        {
            nearScale = uvScales[j];
            farScale  = (cascadeT[j] >= 1.0) ? uvScales[j] : uvScalesExt[j];
        }
    }
    float nearUVScale = nearScale * uvScale;
    float farUVScale  = farScale  * uvScale;

    float2 nearUV_X = baseUV_X * nearUVScale + uvOffset;
    float2 farUV_X  = baseUV_X * farUVScale  + uvOffset;
    float2 nearUV_Y = baseUV_Y * nearUVScale + uvOffset;
    float2 farUV_Y  = baseUV_Y * farUVScale  + uvOffset;
    float2 nearUV_Z = baseUV_Z * nearUVScale + uvOffset;
    float2 farUV_Z  = baseUV_Z * farUVScale  + uvOffset;

    // ddx_coarse/ddy_coarse hoisted to function scope so SampleAT inside the
    // per-plane `if (triWeight.* > 0.001)` blocks doesn't hit divergent-flow
    // derivative undefined behaviour.
    float2 ddxNearUV_X = ddx_coarse(nearUV_X), ddyNearUV_X = ddy_coarse(nearUV_X);
    float2 ddxFarUV_X  = ddx_coarse(farUV_X),  ddyFarUV_X  = ddy_coarse(farUV_X);
    float2 ddxNearUV_Y = ddx_coarse(nearUV_Y), ddyNearUV_Y = ddy_coarse(nearUV_Y);
    float2 ddxFarUV_Y  = ddx_coarse(farUV_Y),  ddyFarUV_Y  = ddy_coarse(farUV_Y);
    float2 ddxNearUV_Z = ddx_coarse(nearUV_Z), ddyNearUV_Z = ddy_coarse(nearUV_Z);
    float2 ddxFarUV_Z  = ddx_coarse(farUV_Z),  ddyFarUV_Z  = ddy_coarse(farUV_Z);

    // Per-plane near/far samples + accumulators.
    float3 albRGB_near = 0, albRGB_far = 0;
    float  albA_near = 0,   albA_far = 0;
    float  nrmX_near = 0,   nrmX_far = 0;
    float  nrmZ_near = 0,   nrmZ_far = 0;
    float  met_near  = 0,   met_far  = 0;
    float2 normWY_near_x = 0, normWY_far_x = 0;
    float2 normWY_near_y = 0, normWY_far_y = 0;
    float2 normWY_near_z = 0, normWY_far_z = 0;

    if (triWeight.x > 0.001)
    {
        float4 albN = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, nearUV_X, biomeIdx, ddxNearUV_X, ddyNearUV_X);
        float4 albF = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, farUV_X,  biomeIdx, ddxFarUV_X,  ddyFarUV_X);
        float4 nrmN = SampleAT(_SmallNormalArray, sampler_LinearRepeat, nearUV_X, biomeIdx, ddxNearUV_X, ddyNearUV_X);
        float4 nrmF = SampleAT(_SmallNormalArray, sampler_LinearRepeat, farUV_X,  biomeIdx, ddxFarUV_X,  ddyFarUV_X);
        float  metN = SampleAT(_SmallMetalArray,  sampler_LinearRepeat, nearUV_X, biomeIdx, ddxNearUV_X, ddyNearUV_X).x;
        float  metF = SampleAT(_SmallMetalArray,  sampler_LinearRepeat, farUV_X,  biomeIdx, ddxFarUV_X,  ddyFarUV_X).x;
        albRGB_near += triWeight.x * albN.xyz; albRGB_far += triWeight.x * albF.xyz;
        albA_near   += triWeight.x * albN.w;   albA_far   += triWeight.x * albF.w;
        nrmX_near   += triWeight.x * nrmN.x;   nrmX_far   += triWeight.x * nrmF.x;
        nrmZ_near   += triWeight.x * nrmN.z;   nrmZ_far   += triWeight.x * nrmF.z;
        met_near    += triWeight.x * metN;     met_far    += triWeight.x * metF;
        normWY_near_x = float2(nrmN.w, nrmN.y);
        normWY_far_x  = float2(nrmF.w, nrmF.y);
    }
    if (triWeight.y > 0.001)
    {
        float4 albN = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, nearUV_Y, biomeIdx, ddxNearUV_Y, ddyNearUV_Y);
        float4 albF = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, farUV_Y,  biomeIdx, ddxFarUV_Y,  ddyFarUV_Y);
        float4 nrmN = SampleAT(_SmallNormalArray, sampler_LinearRepeat, nearUV_Y, biomeIdx, ddxNearUV_Y, ddyNearUV_Y);
        float4 nrmF = SampleAT(_SmallNormalArray, sampler_LinearRepeat, farUV_Y,  biomeIdx, ddxFarUV_Y,  ddyFarUV_Y);
        float  metN = SampleAT(_SmallMetalArray,  sampler_LinearRepeat, nearUV_Y, biomeIdx, ddxNearUV_Y, ddyNearUV_Y).x;
        float  metF = SampleAT(_SmallMetalArray,  sampler_LinearRepeat, farUV_Y,  biomeIdx, ddxFarUV_Y,  ddyFarUV_Y).x;
        albRGB_near += triWeight.y * albN.xyz; albRGB_far += triWeight.y * albF.xyz;
        albA_near   += triWeight.y * albN.w;   albA_far   += triWeight.y * albF.w;
        nrmX_near   += triWeight.y * nrmN.x;   nrmX_far   += triWeight.y * nrmF.x;
        nrmZ_near   += triWeight.y * nrmN.z;   nrmZ_far   += triWeight.y * nrmF.z;
        met_near    += triWeight.y * metN;     met_far    += triWeight.y * metF;
        normWY_near_y = float2(nrmN.w, nrmN.y);
        normWY_far_y  = float2(nrmF.w, nrmF.y);
    }
    if (triWeight.z > 0.001)
    {
        float4 albN = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, nearUV_Z, biomeIdx, ddxNearUV_Z, ddyNearUV_Z);
        float4 albF = SampleAT(_SmallAlbedoArray, sampler_LinearRepeat, farUV_Z,  biomeIdx, ddxFarUV_Z,  ddyFarUV_Z);
        float4 nrmN = SampleAT(_SmallNormalArray, sampler_LinearRepeat, nearUV_Z, biomeIdx, ddxNearUV_Z, ddyNearUV_Z);
        float4 nrmF = SampleAT(_SmallNormalArray, sampler_LinearRepeat, farUV_Z,  biomeIdx, ddxFarUV_Z,  ddyFarUV_Z);
        float  metN = SampleAT(_SmallMetalArray,  sampler_LinearRepeat, nearUV_Z, biomeIdx, ddxNearUV_Z, ddyNearUV_Z).x;
        float  metF = SampleAT(_SmallMetalArray,  sampler_LinearRepeat, farUV_Z,  biomeIdx, ddxFarUV_Z,  ddyFarUV_Z).x;
        albRGB_near += triWeight.z * albN.xyz; albRGB_far += triWeight.z * albF.xyz;
        albA_near   += triWeight.z * albN.w;   albA_far   += triWeight.z * albF.w;
        nrmX_near   += triWeight.z * nrmN.x;   nrmX_far   += triWeight.z * nrmF.x;
        nrmZ_near   += triWeight.z * nrmN.z;   nrmZ_far   += triWeight.z * nrmF.z;
        met_near    += triWeight.z * metN;     met_far    += triWeight.z * metF;
        normWY_near_z = float2(nrmN.w, nrmN.y);
        normWY_far_z  = float2(nrmF.w, nrmF.y);
    }

    // Reorient per-plane TS normals into a single object-space normal,
    // transformed to world via TriplanarToWorld * normalStrength.
    float3 reorientedNear = ReorientTriplanarNormal3Axis(
        normWY_near_x, normWY_near_y, normWY_near_z,
        triN, triWeight, triSign, triN_zPositive);
    float3 reorientedFar  = ReorientTriplanarNormal3Axis(
        normWY_far_x,  normWY_far_y,  normWY_far_z,
        triN, triWeight, triSign, triN_zPositive);

    // Color grading: brightness/contrast/saturation around mid-gray.  Note
    // the *swapped* near/far convention here (`result.nearXxx` <- farUV
    // sample) -- it's shared with the single-axis ProcessBiomeLayer and is
    // what `ProcessBiomeAdditive` expects when treating `r.nearColor*wFar`
    // as the far-cascade composite.
    float3 gradedNear = mad(mad(albRGB_near, tint.xyz, brightness) - 0.21763764, contrast, 0.21763764);
    float3 gradedFar  = mad(mad(albRGB_far,  tint.xyz, brightness) - 0.21763764, contrast, 0.21763764);
    float  lumNear = dot(gradedNear, float3(0.2126729, 0.7151522, 0.072175));
    float  lumFar  = dot(gradedFar,  float3(0.2126729, 0.7151522, 0.072175));
    result.nearColor = mad(saturation, gradedFar  - lumFar,  lumFar);
    result.farColor  = mad(saturation, gradedNear - lumNear, lumNear);

    result.nearNormal = mul((float3x3)TriplanarToWorld, reorientedFar)  * normalStrength;
    result.farNormal  = mul((float3x3)TriplanarToWorld, reorientedNear) * normalStrength;

    result.nearHeightAlpha = albA_far  * tint.w;
    result.farHeightAlpha  = albA_near * tint.w;

    bool  metOver       = metallicStrength >= 15.0;
    float metFlag       = metOver ? 1.0 : 0.0;
    float metScale      = metFlag + (metOver ? 0.0 : metallicStrength);
    float metOffset     = (metFlag * (metallicStrength - 15.0)) * 0.2;
    result.nearMetallic = mad(met_far,  metScale, metOffset);
    result.farMetallic  = mad(met_near, metScale, metOffset);

    bool  glsOver  = glossStrength >= 15.0;
    float glsFlag  = glsOver ? 1.0 : 0.0;
    float glsScale = glsFlag + (glsOver ? 0.0 : glossStrength);
    float glsOff   = ((glossStrength - 15.0) * glsFlag) * 0.2;
    result.nearGloss = mad(nrmX_far,  glsScale, glsOff);
    result.farGloss  = mad(nrmX_near, glsScale, glsOff);

    result.nearAO = pow(nrmZ_far,  aoStrength);
    result.farAO  = pow(nrmZ_near, aoStrength);

    return result;
}
#endif // TRIPLANAR_3AXIS

// ---------------------------------------------------------------------------
// Per-biome material parameters bundle.  Each additive biome pass
// (R / G / B / A) owns its own `_Small*<ch>*` uniform family; the helper
// `ProcessBiomeAdditive` is biome-agnostic and consumes a `BiomeMaterial`.
// Each pass populates one via `MakeBiomeMaterial<X>()` (see below).
// ---------------------------------------------------------------------------
struct BiomeMaterial
{
    float4 biome;             // _SmallBiome<ch>          : per-layer texture-array indices (-1 = layer disabled)
    float4 enable;            // _SmallEnable<ch>         : per-layer enable flag (0/1)
    float4 heightWeight;      // _SmallHeightWeight<ch>   : per-layer scalar weight (NONE path only)
    float4 weightSoftness;    // _SmallWeightSoftness<ch> : per-layer pow exponent for height-blend
    float4 uvScale;
    float4 uvOffset;
    float4 tint1, tint2, tint3, tint4;       // _SmallTint<ch>{1..4}  (NONE path only)
    float4 brightness;        // _SmallBrightness<ch>     (NONE path only)
    float4 contrast;
    float4 saturation;
    float4 normalStrength;
    float4 metallicStrength;
    float4 glossStrength;
    float4 aoStrength;
    float4 distanceResampleMax;

    // SUB_ZONES_ENABLED params (declared unconditionally — Unity tolerates
    // unused property bindings).
    float4 szWeight1, szWeight2, szWeight3, szWeight4;
    float4 szBrightness1, szBrightness2, szBrightness3, szBrightness4;
    float4 szTint1_R, szTint1_G, szTint1_B, szTint1_A;
    float4 szTint2_R, szTint2_G, szTint2_B, szTint2_A;
    float4 szTint3_R, szTint3_G, szTint3_B, szTint3_A;
    float4 szTint4_R, szTint4_G, szTint4_B, szTint4_A;
};

// One MakeBiomeMaterial<X>() per channel.  Each is identical except for the
// channel letter pasted into every uniform name; the macro keeps the four
// definitions in sync.
#define BIOME_MAKE_FN(CH) \
    BiomeMaterial MakeBiomeMaterial##CH() { \
        BiomeMaterial m; \
        m.biome              = _SmallBiome##CH; \
        m.enable             = _SmallEnable##CH; \
        m.heightWeight       = _SmallHeightWeight##CH; \
        m.weightSoftness     = _SmallWeightSoftness##CH; \
        m.uvScale            = _SmallUVScale##CH; \
        m.uvOffset           = _SmallUVOffset##CH; \
        m.tint1              = _SmallTint##CH##1; m.tint2 = _SmallTint##CH##2; \
        m.tint3              = _SmallTint##CH##3; m.tint4 = _SmallTint##CH##4; \
        m.brightness         = _SmallBrightness##CH; \
        m.contrast           = _SmallContrast##CH; \
        m.saturation         = _SmallSaturation##CH; \
        m.normalStrength     = _SmallNormalStrength##CH; \
        m.metallicStrength   = _SmallMetallicStrength##CH; \
        m.glossStrength      = _SmallGlossStrength##CH; \
        m.aoStrength         = _SmallAOStrength##CH; \
        m.distanceResampleMax = _SmallDistanceResampleMax##CH; \
        m.szWeight1     = _SmallSubzoneWeight##CH##1;     m.szWeight2     = _SmallSubzoneWeight##CH##2; \
        m.szWeight3     = _SmallSubzoneWeight##CH##3;     m.szWeight4     = _SmallSubzoneWeight##CH##4; \
        m.szBrightness1 = _SmallSubzoneBrightness##CH##1; m.szBrightness2 = _SmallSubzoneBrightness##CH##2; \
        m.szBrightness3 = _SmallSubzoneBrightness##CH##3; m.szBrightness4 = _SmallSubzoneBrightness##CH##4; \
        m.szTint1_R = _SmallSubzoneTint##CH##1_R; m.szTint1_G = _SmallSubzoneTint##CH##1_G; \
        m.szTint1_B = _SmallSubzoneTint##CH##1_B; m.szTint1_A = _SmallSubzoneTint##CH##1_A; \
        m.szTint2_R = _SmallSubzoneTint##CH##2_R; m.szTint2_G = _SmallSubzoneTint##CH##2_G; \
        m.szTint2_B = _SmallSubzoneTint##CH##2_B; m.szTint2_A = _SmallSubzoneTint##CH##2_A; \
        m.szTint3_R = _SmallSubzoneTint##CH##3_R; m.szTint3_G = _SmallSubzoneTint##CH##3_G; \
        m.szTint3_B = _SmallSubzoneTint##CH##3_B; m.szTint3_A = _SmallSubzoneTint##CH##3_A; \
        m.szTint4_R = _SmallSubzoneTint##CH##4_R; m.szTint4_G = _SmallSubzoneTint##CH##4_G; \
        m.szTint4_B = _SmallSubzoneTint##CH##4_B; m.szTint4_A = _SmallSubzoneTint##CH##4_A; \
        return m; \
    }

// Each pass defines exactly one of BIOME_FRAG_R/G/B/A via the .shader.
// Only the matching MakeBiomeMaterial<X>() is compiled.
#ifdef BIOME_FRAG_R
BIOME_MAKE_FN(R)
#elif defined(BIOME_FRAG_G)
BIOME_MAKE_FN(G)
#elif defined(BIOME_FRAG_B)
BIOME_MAKE_FN(B)
#elif defined(BIOME_FRAG_A)
BIOME_MAKE_FN(A)
#endif

// ---------------------------------------------------------------------------
// Aggregate per-biome additive contribution (4-layer composition).  Caller
// applies the final `projRatio * lerp(far, near, uvResampleOp) * packedFade`
// composite plus the alpha-to-height fade, then quat-rotates the normal.
// Splitting the helper at this seam keeps the per-biome math (which depends
// on `_Small*<ch>*` uniforms) isolated from the cross-pixel compositing
// (which depends on per-pixel projRatio / cascade fades).
// ---------------------------------------------------------------------------
struct BiomeAggResult
{
    // For color: blended-with-wFar/wNear vs blended-with-normalizedBlend.
    // The caller lerps these by alphaToHeightFade.
    float3 blendedFarColor;
    float3 farNormalized;
    float3 blendedNearColor;
    float3 nearNormalized;
    // Far/near per-channel for normal/gloss/AO/metallic.
    float3 blendedFarNormal;
    float3 blendedNearNormal;
    float  blendedFarGloss,  blendedNearGloss;
    float  blendedFarAO,     blendedNearAO;
    float  blendedFarMet,    blendedNearMet;
};

BiomeAggResult ProcessBiomeAdditive(
    BiomeMaterial mat,
    float4 layerWeight,        // prepass _LocalSpacePrepassTex<N> sample (LAYERS4(<ch>))
    float4 subzoneMask,        // _SubzoneMaskTex sample (only used when SUB_ZONES_ENABLED)
    float4 cascadeT,
    bool   biomeActive,        // projRatio > 0
#ifdef TRIPLANAR_3AXIS
    // 3-axis: per-plane base UVs (X/Y/Z planes); single-axis args unused.
    float2 baseUV_X, float2 baseUV_Y, float2 baseUV_Z,
#else
    float  baseTriU, float baseTriV,
#endif
    float3 triN, float3 triWeight, float3 triSign, bool triN_zPositive,
    float  heightblendFactorX) // _HeightblendFactor.x
{
    // ------- Per-layer tint / brightness / heightWeight -----------------
    // SZ replaces the per-layer scalars with subzone-mask-weighted blends:
    //   wm[i,ch]       = subzoneMask.ch * mat.szWeight{i}.ch
    //   tint{i}.rgb    = sum_ch (wm[i,ch] * mat.szTint{i}_<ch>.rgb)
    //   brightness.i   = dot(mat.szBrightness{i}, wm[i,*])
    //   heightWeight.i = mat.enable.i * dot(mat.szWeight{i}, subzoneMask)
    // Got-me: SZ drops the tint.w factor on nearHeightAlpha, so we override
    // tint{i}.w = 1 in the SZ branch to neutralise the multiplier in
    // `(triWeight.y * farAlbedo.w) * tint.w`.
    float4 tint1, tint2, tint3, tint4;
    float4 brightness;
    float4 heightWeight;
#ifdef SUB_ZONES_ENABLED
    float4 wm1 = subzoneMask * mat.szWeight1;
    float4 wm2 = subzoneMask * mat.szWeight2;
    float4 wm3 = subzoneMask * mat.szWeight3;
    float4 wm4 = subzoneMask * mat.szWeight4;
    tint1 = wm1.x * mat.szTint1_R + wm1.y * mat.szTint1_G + wm1.z * mat.szTint1_B + wm1.w * mat.szTint1_A;
    tint2 = wm2.x * mat.szTint2_R + wm2.y * mat.szTint2_G + wm2.z * mat.szTint2_B + wm2.w * mat.szTint2_A;
    tint3 = wm3.x * mat.szTint3_R + wm3.y * mat.szTint3_G + wm3.z * mat.szTint3_B + wm3.w * mat.szTint3_A;
    tint4 = wm4.x * mat.szTint4_R + wm4.y * mat.szTint4_G + wm4.z * mat.szTint4_B + wm4.w * mat.szTint4_A;
    tint1.w = 1.0; tint2.w = 1.0; tint3.w = 1.0; tint4.w = 1.0;
    brightness = float4(dot(mat.szBrightness1, wm1), dot(mat.szBrightness2, wm2),
                        dot(mat.szBrightness3, wm3), dot(mat.szBrightness4, wm4));
    heightWeight = mat.enable * float4(dot(mat.szWeight1, subzoneMask),
                                       dot(mat.szWeight2, subzoneMask),
                                       dot(mat.szWeight3, subzoneMask),
                                       dot(mat.szWeight4, subzoneMask));
#else
    tint1 = mat.tint1; tint2 = mat.tint2; tint3 = mat.tint3; tint4 = mat.tint4;
    brightness = mat.brightness;
    heightWeight = mat.heightWeight * mat.enable;
#endif

    // ------- Per-layer triplanar small-biome sampling -------------------
    BiomeLayerResult r1 = (BiomeLayerResult)0;
    BiomeLayerResult r2 = (BiomeLayerResult)0;
    BiomeLayerResult r3 = (BiomeLayerResult)0;
    BiomeLayerResult r4 = (BiomeLayerResult)0;

#ifdef TRIPLANAR_3AXIS
    // 3-axis path samples three plane UVs per layer.  Caller passes
    // (baseUV_X, baseUV_Y, baseUV_Z) packed into baseTriU/baseTriV unused
    // params — see frag-dispatch wrapper macros below.
    #define _PROC_LAYER(IDX_, TINT_, BR_) \
        ProcessBiomeLayer3Axis( \
            mat.distanceResampleMax[IDX_], mat.biome[IDX_], mat.uvScale[IDX_], mat.uvOffset[IDX_], \
            TINT_, BR_, mat.contrast[IDX_], mat.saturation[IDX_], \
            mat.normalStrength[IDX_], mat.metallicStrength[IDX_], mat.glossStrength[IDX_], mat.aoStrength[IDX_], \
            baseUV_X, baseUV_Y, baseUV_Z, triN, triWeight, triSign, triN_zPositive, cascadeT)
#else
    #define _PROC_LAYER(IDX_, TINT_, BR_) \
        ProcessBiomeLayer( \
            mat.distanceResampleMax[IDX_], mat.biome[IDX_], mat.uvScale[IDX_], mat.uvOffset[IDX_], \
            TINT_, BR_, mat.contrast[IDX_], mat.saturation[IDX_], \
            mat.normalStrength[IDX_], mat.metallicStrength[IDX_], mat.glossStrength[IDX_], mat.aoStrength[IDX_], \
            baseTriU, baseTriV, triN, triWeight, triSign, triN_zPositive, cascadeT)
#endif

    if (biomeActive && mat.biome.x >= 0.0 && heightWeight.x > 0.0)
        r1 = _PROC_LAYER(0, tint1, brightness.x);
    if (biomeActive && mat.biome.y >= 0.0 && heightWeight.y > 0.0)
        r2 = _PROC_LAYER(1, tint2, brightness.y);
    if (biomeActive && mat.biome.z >= 0.0 && heightWeight.z > 0.0)
        r3 = _PROC_LAYER(2, tint3, brightness.z);
    if (biomeActive && mat.biome.w >= 0.0 && heightWeight.w > 0.0)
        r4 = _PROC_LAYER(3, tint4, brightness.w);
#undef _PROC_LAYER

    // ------- Per-layer height-blend weights -----------------------------
    float4 enabledWeight    = layerWeight * mat.enable;
    float4 blendInput       = layerWeight * heightWeight;
    float4 normalizedBlend  = blendInput / max(dot(blendInput, 1.0.xxxx), 0.001);
    float4 soft             = max(mat.weightSoftness, 0.001);
    float4 nearHeightAlpha  = float4(r1.nearHeightAlpha, r2.nearHeightAlpha, r3.nearHeightAlpha, r4.nearHeightAlpha);
    float4 farHeightAlpha   = float4(r1.farHeightAlpha,  r2.farHeightAlpha,  r3.farHeightAlpha,  r4.farHeightAlpha);
    float4 heightBlendFar   = saturate(pow(mad(nearHeightAlpha, enabledWeight, heightWeight) - 0.5, soft) - 0.5);
    float4 heightBlendNear  = saturate(pow(mad(farHeightAlpha,  enabledWeight, heightWeight) - 0.5, soft) - 0.5);

    float4 hbFarProduct = heightWeight * heightBlendFar;
    float  thresholdFar = heightblendFactorX - max(max(hbFarProduct.x, hbFarProduct.y), max(hbFarProduct.z, hbFarProduct.w));
    float4 blendFar     = max(mad(heightBlendFar, heightWeight, thresholdFar), 0.0);
    float4 wFar         = blendFar / max(dot(blendFar, 1.0.xxxx), 0.001);

    float4 hbNearProduct = heightWeight * heightBlendNear;
    float  thresholdNear = heightblendFactorX - max(max(hbNearProduct.x, hbNearProduct.y), max(hbNearProduct.z, hbNearProduct.w));
    float4 blendNear     = max(mad(heightBlendNear, heightWeight, thresholdNear), 0.0);
    float4 wNear         = blendNear / max(dot(blendNear, 1.0.xxxx), 0.001);

    // ------- Layer composition ------------------------------------------
    BiomeAggResult agg;
    agg.blendedFarColor   = mad(r4.nearColor, wFar.w,           mad(r3.nearColor, wFar.z,           mad(r1.nearColor, wFar.x,           r2.nearColor * wFar.y)));
    agg.farNormalized     = mad(r4.nearColor, normalizedBlend.w, mad(r3.nearColor, normalizedBlend.z, mad(r1.nearColor, normalizedBlend.x, normalizedBlend.y * r2.nearColor)));
    agg.blendedNearColor  = mad(r4.farColor,  wNear.w,           mad(r3.farColor,  wNear.z,           mad(r1.farColor,  wNear.x,           wNear.y * r2.farColor)));
    agg.nearNormalized    = mad(r4.farColor,  normalizedBlend.w, mad(r3.farColor,  normalizedBlend.z, mad(r1.farColor,  normalizedBlend.x, normalizedBlend.y * r2.farColor)));

    agg.blendedFarNormal  = mad(r4.nearNormal, wFar.w, mad(r3.nearNormal, wFar.z, mad(r1.nearNormal, wFar.x, wFar.y * r2.nearNormal)));
    agg.blendedNearNormal = mad(r4.farNormal,  wNear.w, mad(r3.farNormal,  wNear.z, mad(r1.farNormal,  wNear.x, wNear.y * r2.farNormal)));

    agg.blendedFarGloss   = mad(r4.nearGloss,    wFar.w, mad(r3.nearGloss,    wFar.z, mad(r1.nearGloss,    wFar.x, wFar.y * r2.nearGloss)));
    agg.blendedNearGloss  = mad(r4.farGloss,     wNear.w, mad(r3.farGloss,     wNear.z, mad(r1.farGloss,     wNear.x, wNear.y * r2.farGloss)));
    agg.blendedFarAO      = mad(r4.nearAO,       wFar.w, mad(r3.nearAO,       wFar.z, mad(r1.nearAO,       wFar.x, wFar.y * r2.nearAO)));
    agg.blendedNearAO     = mad(r4.farAO,        wNear.w, mad(r3.farAO,        wNear.z, mad(r1.farAO,        wNear.x, wNear.y * r2.farAO)));
    agg.blendedFarMet     = mad(r4.nearMetallic, wFar.w, mad(r3.nearMetallic, wFar.z, mad(r1.nearMetallic, wFar.x, wFar.y * r2.nearMetallic)));
    agg.blendedNearMet    = mad(r4.farMetallic,  wNear.w, mad(r3.farMetallic,  wNear.z, mad(r1.farMetallic,  wNear.x, wNear.y * r2.farMetallic)));
    return agg;
}

// ---------------------------------------------------------------------------
// Spherical-harmonics evaluation for L0+L1 (or LPPV path).  Mirrors the
// DeferredBase EvaluateSphericalHarmonics helper but per-component (so we
// can return float3 = (R, G, B) directly).
// ---------------------------------------------------------------------------
float3 EvaluateSH(float3 worldNormal, float3 worldPos, float pX, float pY, float pZ)
{
    if (unity_ProbeVolumeParams.x != 1.0)
        return SHEvalLinearL0L1(float4(worldNormal, 1.0));

    float3 probePos = (unity_ProbeVolumeParams.y == 1.0)
        ? mul(unity_ProbeVolumeWorldToObject, float4(worldPos, 1.0)).xyz
        : float3(pX, pY, pZ);
    float3 probeUV = (probePos - unity_ProbeVolumeMin) * unity_ProbeVolumeSizeInv;
    float halfTexel = unity_ProbeVolumeParams.z * 0.5;
    float xMain = min(0.25 - halfTexel, max(halfTexel, probeUV.x * 0.25));

    float4 nW1 = float4(worldNormal, 1.0);
    float r = dot(unity_ProbeVolumeSH.Sample(samplerunity_ProbeVolumeSH, float3(xMain,        probeUV.yz)), nW1);
    float g = dot(unity_ProbeVolumeSH.Sample(samplerunity_ProbeVolumeSH, float3(xMain + 0.25, probeUV.yz)), nW1);
    float b = dot(unity_ProbeVolumeSH.Sample(samplerunity_ProbeVolumeSH, float3(xMain + 0.50, probeUV.yz)), nW1);
    return float3(r, g, b);
}

// ===========================================================================
// Fragment shader
// ===========================================================================
GBufferOutput frag(V2F i)
{
#if defined(BIOME_FRAG_R) || defined(BIOME_FRAG_G) || defined(BIOME_FRAG_B) || defined(BIOME_FRAG_A)
    // -----------------------------------------------------------------------
    // Single-channel biome additive frag (passes 4..11).  The body is
    // channel-agnostic past per-channel inputs: layerWeight tex slot,
    // projRatio component, MakeBiomeMaterial<X>().  TRIPLANAR_3AXIS guards
    // pick 3-axis vs single-axis (Y-plane) sampling.
    // -----------------------------------------------------------------------
    float2 uv           = i.uvHeight.xy;
    float  height       = i.uvHeight.z;
    float3 worldNormal  = i.worldNormalPosX.xyz;     // unused after blendedNormal; kept for context
    float3 bitangent    = i.bitangentPosY.xyz;       // unused
    float3 worldTangent = i.worldTangentPosZ.xyz;
    float3 worldPos     = float3(i.worldNormalPosX.w, i.bitangentPosY.w, i.worldTangentPosZ.w);
    float3 objectNormal = i.objectNormal;

    float screenU = i.screenPos.x / i.screenPos.z;
    float screenV = i.screenPos.y / i.screenPos.z;

    DitherAlphaTest(float2(screenU, screenV) * _ScreenParams.xy, _Transition);

    // Per-pixel screen-space prepass samples.  Each biome reads its own
    // LAYERS4(<ch>) slot; world normal is shared.
#ifdef BIOME_FRAG_R
    float4 layerWeight   = _LocalSpacePrepassTex0.Sample(sampler_LinearRepeat, float2(screenU, screenV));
#elif defined(BIOME_FRAG_G)
    float4 layerWeight   = _LocalSpacePrepassTex1.Sample(sampler_LinearRepeat, float2(screenU, screenV));
#elif defined(BIOME_FRAG_B)
    float4 layerWeight   = _LocalSpacePrepassTex2.Sample(sampler_LinearRepeat, float2(screenU, screenV));
#elif defined(BIOME_FRAG_A)
    float4 layerWeight   = _LocalSpacePrepassTex3.Sample(sampler_LinearRepeat, float2(screenU, screenV));
#endif
    float3 prepassNormal = _LocalSpacePrepassTex4.Sample(sampler_LinearRepeat, float2(screenU, screenV)).xyz;

    float cameraDist        = distance(_WorldSpaceCameraPos, worldPos);
    float3 normalizedFragNormal = normalize(objectNormal);

    float3 triplanarLocalPos    = mul(TriplanarBasis, mul(_PQSToLocal, float4(worldPos, 1.0))).xyz;
    float3 triplanarNormal      = mul((float3x3)TriplanarBasis, normalizedFragNormal);
    float3 triN                 = normalize(triplanarNormal);

    float3 triplanarContrast4   = float3(_TriplanarContrast * TriplanarContrastBoost.x,
                                         _TriplanarContrast * TriplanarContrastBoost.y,
                                         _TriplanarContrast * TriplanarContrastBoost.z);
    float3 triWeightRaw         = pow(abs(triN), triplanarContrast4);
    float  triWeightSum         = max(triWeightRaw.x + triWeightRaw.y + triWeightRaw.z, 0.001);
    float3 triWeight            = triWeightRaw / triWeightSum;
    float3 triSign              = sign(triN);
    bool   triN_zPositive       = triN.z >= 0.0;

#ifdef TRIPLANAR_3AXIS
    // 3-axis: per-plane base UVs.  The XY/XZ/YZ ordering matters -- each
    // plane projects out its own world axis.
    float2 triUVScale = _TriplanarUVScaleOffset.xy * 0.01;
    float2 triUVOffset = _TriplanarUVScaleOffset.zw;
    float2 baseUV_X = float2(triplanarLocalPos.z, triplanarLocalPos.y) * triUVScale + triUVOffset;
    float2 baseUV_Y = float2(triplanarLocalPos.x, triplanarLocalPos.z) * triUVScale + triUVOffset;
    float2 baseUV_Z = float2(triplanarLocalPos.x, triplanarLocalPos.y) * triUVScale + triUVOffset;
#else
    float baseTriU = mad(triplanarLocalPos.x * _TriplanarUVScaleOffset.x, 0.01, _TriplanarUVScaleOffset.z);
    float baseTriV = mad(triplanarLocalPos.z * _TriplanarUVScaleOffset.y, 0.01, _TriplanarUVScaleOffset.w);
#endif

    // ProjRatio: source is `_BiomeMaskTex` at terrain UV.  Per-biome ratio is
    // (this biome's mask channel) / (sum of all four channels).
    float4 projSample  = _BiomeMaskTex.Sample(sampler_LinearRepeat, uv);
    float  projSumAll  = max(projSample.x + projSample.y + projSample.z + projSample.w, 0.001);
#ifdef BIOME_FRAG_R
    float  projRatio   = projSample.x / projSumAll;
#elif defined(BIOME_FRAG_G)
    float  projRatio   = projSample.y / projSumAll;
#elif defined(BIOME_FRAG_B)
    float  projRatio   = projSample.z / projSumAll;
#elif defined(BIOME_FRAG_A)
    float  projRatio   = projSample.w / projSumAll;
#endif

    // Distance-driven cascade fade.  Same forward k=0..3 scan for both
    // single-axis and 3-axis paths.
    float alphaToHeightFade = lerp(_AlphaToHeightFadeParams.z, _AlphaToHeightFadeParams.w,
                                   saturate((cameraDist - _AlphaToHeightFadeParams.x) / max(_AlphaToHeightFadeParams.y, 0.01)));
    float normalizedDist    = min(cameraDist * 2.0e-05, 1.0);
    float4 cascadeT = (normalizedDist - _DistanceResampleFadeRangesNeg)
                    / (_DistanceResampleFadeRangesPos - _DistanceResampleFadeRangesNeg);
    float4 albedoOpLo = float4(1.0, _DistanceResampleAlbedoOpacity.xyz);
    float4 normalOpLo = float4(1.0, _DistanceResampleNormalOpacity.xyz);
    float uvResampleOp     = 1.0;
    float resampleAlbedoOp = 1.0;
    float normalResampleOp = 1.0;
    [unroll] for (int k = 0; k < 4; k++)
    {
        if (cascadeT[k] > 0.001)
        {
            float t = saturate(cascadeT[k]);
            uvResampleOp     = t;
            resampleAlbedoOp = lerp(albedoOpLo[k], _DistanceResampleAlbedoOpacity[k], t);
            normalResampleOp = lerp(normalOpLo[k], _DistanceResampleNormalOpacity[k], t);
        }
    }

    // Run the per-biome material through the additive helper.  Each biome
    // pass owns its own MakeBiomeMaterial<X>() that fills the struct from
    // its `_Small*<ch>*` uniforms; ProcessBiomeAdditive is biome-agnostic.
#ifdef SUB_ZONES_ENABLED
    float4 subzoneMask = _SubzoneMaskTex.Sample(sampler_LinearRepeat, uv);
#else
    float4 subzoneMask = 0.0;
#endif
    bool   biomeActive = projRatio > 0.0;
#ifdef BIOME_FRAG_R
    BiomeMaterial mat = MakeBiomeMaterialR();
#elif defined(BIOME_FRAG_G)
    BiomeMaterial mat = MakeBiomeMaterialG();
#elif defined(BIOME_FRAG_B)
    BiomeMaterial mat = MakeBiomeMaterialB();
#elif defined(BIOME_FRAG_A)
    BiomeMaterial mat = MakeBiomeMaterialA();
#endif
    BiomeAggResult agg = ProcessBiomeAdditive(
        mat, layerWeight, subzoneMask, cascadeT, biomeActive,
#ifdef TRIPLANAR_3AXIS
        baseUV_X, baseUV_Y, baseUV_Z,
#else
        baseTriU, baseTriV,
#endif
        triN, triWeight, triSign, triN_zPositive,
        _HeightblendFactor.x);

    // Final compositing: alphaToHeightFade between heightblend-weighted and
    // normalizedBlend-weighted; uvResampleOp between far cascade and near.
    float3 blendedColor = lerp(agg.blendedFarColor,  agg.farNormalized,  alphaToHeightFade);
    float3 nearComposed = lerp(agg.blendedNearColor, agg.nearNormalized, alphaToHeightFade);
    float3 finalColor   = projRatio * lerp(blendedColor, nearComposed, uvResampleOp);

    float albedoFade = resampleAlbedoOp * (1.0 - lerp(_AlbedoScaledFadeParams.z, _AlbedoScaledFadeParams.w,
                                                      saturate((cameraDist - _AlbedoScaledFadeParams.x) / max(_AlbedoScaledFadeParams.y, 0.01))));
    float normalFade = normalResampleOp * (1.0 - lerp(_NormalScaledFadeParams.z, _NormalScaledFadeParams.w,
                                                      saturate((cameraDist - _NormalScaledFadeParams.x) / max(_NormalScaledFadeParams.y, 0.01))));
    float packedFade = normalResampleOp * (1.0 - lerp(_PackedScaledFadeParams.z, _PackedScaledFadeParams.w,
                                                      saturate((cameraDist - _PackedScaledFadeParams.x) / max(_PackedScaledFadeParams.y, 0.01))));

    float3 blendedNormal = projRatio * lerp(agg.blendedFarNormal, agg.blendedNearNormal, uvResampleOp);

    // Shortest-arc rotation from worldTangent → blendedNormal applied to prepassNormal.
    float  quatDot   = dot(worldTangent, blendedNormal) + 1.0;
    float  quatLen   = sqrt(quatDot + quatDot);
    float3 quatCross = cross(worldTangent, blendedNormal) / quatLen;
    float  quatW     = quatDot / quatLen;
    float  quatDiag  = quatW * quatW - dot(quatCross, quatCross);
    float  quatNdotP = dot(quatCross, prepassNormal);
    float3 finalNormal = lerp(prepassNormal,
                              mad(quatW + quatW, cross(quatCross, prepassNormal),
                                  mad(prepassNormal, quatDiag, quatNdotP * (quatCross + quatCross))),
                              normalFade);

    float finalGlossOcc   = (projRatio * lerp(agg.blendedFarGloss, agg.blendedNearGloss, uvResampleOp)) * packedFade;
    float finalSmoothness = (projRatio * lerp(agg.blendedFarAO,    agg.blendedNearAO,    uvResampleOp)) * packedFade;
    float finalMetallic   = (projRatio * lerp(agg.blendedFarMet,   agg.blendedNearMet,   uvResampleOp)) * packedFade;

    // GBuffer split (additive).
    float3 albedoOut    = finalColor * albedoFade;
    float3 specOut      = mad(finalMetallic, mad(albedoFade, finalColor, -0.04), 0.04);
    float3 diffuseOut   = mad(-finalMetallic, 0.96, 0.96) * albedoOut;
    float  smoothOcc    = mad(1.0 - projRatio, finalSmoothness, finalSmoothness);

    // Emission accumulation: SH (LPPV/L0+L1) + per-vertex L2 + atmospheric specular.
    float3 sh         = EvaluateSH(finalNormal, worldPos, i.worldNormalPosX.w, i.bitangentPosY.w, i.worldTangentPosZ.w);
    float3 atmosSpec0 = exp((dot(finalNormal, _SGAxis[0].xyz) - 1.0) * _SGAmplitudeAndSharpness[0].w);
    float3 atmosSpec1 = exp((dot(finalNormal, _SGAxis[1].xyz) - 1.0) * _SGAmplitudeAndSharpness[1].w);
    float3 atmosSpec2 = exp((dot(finalNormal, _SGAxis[2].xyz) - 1.0) * _SGAmplitudeAndSharpness[2].w);
    float3 atmosSpec  = atmosSpec0 * _SGAmplitudeAndSharpness[0].xyz
                      + atmosSpec1 * _SGAmplitudeAndSharpness[1].xyz
                      + atmosSpec2 * _SGAmplitudeAndSharpness[2].xyz;
    float3 shLight    = max(sh + i.lighting, 0.0);
    float3 litColor   = (shLight * smoothOcc + atmosSpec) * albedoOut;

    GBufferOutput o;
    o.albedoSmoothness  = float4(diffuseOut, finalSmoothness);
    o.specularOcclusion = float4(specOut,   finalGlossOcc);
    o.normalProjRatio   = float4(finalNormal * 0.5 + 0.5, projRatio);
#ifdef UNITY_HDR_ON
    o.emission = float4(litColor, 1.0);
#else
    o.emission = float4(exp2(-litColor), 1.0);
#endif
    return o;

#else
    // Fallback for builds that don't set BIOME_FRAG_*.  Currently unreachable
    // -- every additive biome pass (4..11) defines exactly one of
    // BIOME_FRAG_R/G/B/A.  Emits no contribution so the additive blend
    // leaves the GBuffer unchanged.
    GBufferOutput o;
    o.albedoSmoothness  = float4(0, 0, 0, 0);
    o.specularOcclusion = float4(0, 0, 0, 0);
    o.normalProjRatio   = float4(0.5, 0.5, 0.5, 0);
    o.emission          = float4(0, 0, 0, 0);
    return o;
#endif
}

#endif // DEFERREDBIOME_CGINC
