#ifndef CELESTIALBODY_LOCAL_CGINC
#define CELESTIALBODY_LOCAL_CGINC

// ============================================================================
// CelestialBody_Local.cginc
//
// Aggregator that pulls in the split per-pass cginc files.  Each .shader pass
// defines exactly one of PASS_DEFERRED_BASE / PASS_DEFERRED_BIOME /
// PASS_PREPASS / PASS_DEPTH / PASS_DECAL_MASK before including this file; the
// matching frag is brought in by the corresponding include below.  Each
// component pulls its own dependencies (guarded with include guards), so the
// order here doesn't matter.
//
// File layout (all in this folder):
//   - Common.cginc        : macros, GBufferOutput, texture/uniform decls,
//                           normal-blending helpers (used by every pass)
//   - Vertex.cginc        : Appdata / V2F / vert + debug-clip
//   - DeferredBase.cginc  : PASS_DEFERRED_BASE  frag (passes 1/2/3)
//   - DeferredBiome.cginc : PASS_DEFERRED_BIOME frag (passes 4..11)
//   - Prepass.cginc       : PASS_PREPASS       frag (passes 13/14/15)
//
// PASS_DEPTH and PASS_DECAL_MASK frags are 1-line stubs and stay inline below.
// ============================================================================

#ifdef PASS_DEFERRED_BASE
    #include "DeferredBase.cginc"
#endif

#ifdef PASS_DEFERRED_BIOME
    #include "DeferredBiome.cginc"
#endif

#ifdef PASS_PREPASS
    #include "Prepass.cginc"
#endif

#if defined(PASS_DEPTH) || defined(PASS_DECAL_MASK)
    #include "Vertex.cginc"
#endif

#ifdef PASS_DEPTH
// The depth pass has no color contribution, since this part of the shader is ignored.
float4 frag(V2F i) : SV_Target0
{
    return float4(0, 0, 0, 0);
}
#endif // PASS_DEPTH

#ifdef PASS_DECAL_MASK
// Sampled by Unity's deferred decal-projection lookup; the .x = 1 marks
// PQS terrain pixels as "accepts decals" so projected decals render here.
float4 frag(V2F i) : SV_Target0
{
    return float4(1, 0, 0, 1);
}
#endif // PASS_DECAL_MASK

#endif // CELESTIALBODY_LOCAL_CGINC
