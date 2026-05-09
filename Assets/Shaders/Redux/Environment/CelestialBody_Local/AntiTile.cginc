#ifndef ANTITILE_CGINC
#define ANTITILE_CGINC

// ============================================================================
// AntiTile.cginc
//
// ANTI_TILE_QUALITY_ON stochastic anti-tile texture sampling for the small-
// biome Texture2DArray detail layers:
//
//   - Hex-grid hash on `_StochasticScale * baseUV` partitions UV space into
//     up/down equilateral triangles.
//   - Each pixel's containing triangle defines three corner cells; per-cell
//     `frac(sin(dot(C, c)) * 43758.5468)` produces a pseudo-random UV offset
//     that's added to the base UV.
//   - Three weighted SampleGrad lookups (barycentric weights from the
//     triangle position) blend the offset taps; per-tap `weight > 0.001`
//     gate skips degenerate samples.
//
// Uses ddx_coarse / ddy_coarse for the SampleGrad derivatives.
// `_StochasticScale` is a per-material Range(0.25, 2) property.
// ============================================================================

#include "UnityCG.cginc"

#ifdef ANTI_TILE_QUALITY_ON

float _StochasticScale;

struct StochasticHash
{
    float2 uv0, uv1, uv2;
    float3 weights;
};

// 3.464 ≈ 2*sqrt(3) — hex-tile aspect-correction factor.  Multiplied into
// `_StochasticScale` to produce the effective scale for the hex grid.
#define STOCHASTIC_HEX_SCALE 3.464

StochasticHash ComputeStochasticHash(float2 baseUV, float stochasticScale)
{
    StochasticHash r;
    float effectiveScale = stochasticScale * STOCHASTIC_HEX_SCALE;
    float2 scaled = effectiveScale * baseUV;
    float gridY   = dot(float2(-0.57735026, 1.15470052), scaled);

    // Cell indices roundtrip through `uint(int(floor(...)))` -- the unsigned
    // cast wraps negative cell values into a large positive range, which is
    // load-bearing because gridY goes negative wherever scaled.y < scaled.x/2
    // (roughly half the pixels).  Plain signed `floor` here would give a
    // different hash input in those pixels and visibly different smoothness.
    uint cellXi = (uint)((int)floor(scaled.x));
    uint cellYi = (uint)((int)floor(gridY));
    float fracX   = frac(scaled.x);
    float fracY   = frac(gridY);
    float triTest = 1.0 - fracX - fracY;
    bool  inUpper = triTest >= 0.0;

    // Corner cell indices: (cellX, cellY) base + the up/down adjustment, cast
    // back to float via `float(int(uint))`.  The unsigned add wraps consistently
    // for small positive offsets, so float-of-int gives identical results.
    float2 c0 = float2(float((int)(inUpper ? cellXi : (cellXi + 1u))),
                        float((int)(inUpper ? cellYi : (cellYi + 1u))));
    float2 c1 = float2(float((int)(inUpper ? cellXi : (cellXi + 1u))),
                        float((int)(inUpper ? (cellYi + 1u) : cellYi)));
    float2 c2 = float2(float((int)(inUpper ? (cellXi + 1u) : cellXi)),
                        float((int)(inUpper ? cellYi : (cellYi + 1u))));

    r.uv0 = float2(frac(sin(dot(float2(127.1, 311.7), c0)) * 43758.5468),
                   frac(sin(dot(float2(269.5, 183.3), c0)) * 43758.5468)) + baseUV;
    r.uv1 = float2(frac(sin(dot(float2(127.1, 311.7), c1)) * 43758.5468),
                   frac(sin(dot(float2(269.5, 183.3), c1)) * 43758.5468)) + baseUV;
    r.uv2 = float2(frac(sin(dot(float2(127.1, 311.7), c2)) * 43758.5468),
                   frac(sin(dot(float2(269.5, 183.3), c2)) * 43758.5468)) + baseUV;

    r.weights = max(float3(
        inUpper ? triTest : -triTest,
        inUpper ? fracY   : 1.0 - fracY,
        inUpper ? fracX   : 1.0 - fracX), 0.0);
    return r;
}

float4 StochSample(Texture2DArray<float4> tex, SamplerState samp,
                   StochasticHash h, float idx, float2 ddxUV, float2 ddyUV)
{
    float4 sum = 0.0;
    if (h.weights.x > 0.001)
        sum += tex.SampleGrad(samp, float3(h.uv0, idx), ddxUV, ddyUV) * h.weights.x;
    if (h.weights.y > 0.001)
        sum += tex.SampleGrad(samp, float3(h.uv1, idx), ddxUV, ddyUV) * h.weights.y;
    if (h.weights.z > 0.001)
        sum += tex.SampleGrad(samp, float3(h.uv2, idx), ddxUV, ddyUV) * h.weights.z;
    return sum;
}

#endif // ANTI_TILE_QUALITY_ON

// AT-aware Texture2DArray sample wrapper.  When ANTI_TILE_QUALITY_ON is on,
// computes the hex-grid stochastic hash and emits 3 weighted SampleGrad taps;
// when off, falls through to a single plain `Sample`.
//
// Caller MUST pass ddx/ddy of the un-hashed `uv` -- the AT path uses them as
// SampleGrad derivatives.  AT-off ignores them (plain Sample auto-computes
// derivatives from the rasterizer).
float4 SampleAT(Texture2DArray<float4> tex, SamplerState samp,
                float2 uv, float idx, float2 ddxUV, float2 ddyUV)
{
#ifdef ANTI_TILE_QUALITY_ON
    StochasticHash h = ComputeStochasticHash(uv, _StochasticScale);
    return StochSample(tex, samp, h, idx, ddxUV, ddyUV);
#else
    return tex.Sample(samp, float3(uv, idx));
#endif
}

#endif // ANTITILE_CGINC
