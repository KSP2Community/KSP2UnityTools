# Local-space prepass render targets

The local-space prepass (passes 13, 14, 15 of `CelestialBody_Local`) writes
five render targets via `SV_Target0..4`. These are bound on the renderer
side as `PqsPrepassRenderTarget0..4` and consumed at screen-UV by the
deferred passes.

The decompiled `pass13.hlsl` named these targets `biomeHeightWeightR/G/B/A`
+ `projection ratio` — but reading the deferred consumers shows the
**original Local shader actually writes per-layer biome weights to
SV_Target0..3 and the world normal to SV_Target4** (the `New` shader uses a
different mapping with the normal in `Tex0`; see notes below).

The pass13 reverse-engineering's struct field names line up with what the
shader actually writes — `LAYERS4(R, x)` to `SV_Target0`, etc.  The
captured PNGs from `Temp/ShaderComparison/<job>/perpass/{left,right}/prepass/`
confirm this: `tex0.png` shows the per-layer R-channel gate pattern (mostly
zero, with a thin enabled strip at the planet horizon), not a packed normal.

Empirical mapping (Local, the original shader and the v3 rebuild target):

| SV_Target | Renderer binding              | RT format | Content                                                            |
|-----------|-------------------------------|-----------|--------------------------------------------------------------------|
| `Tex0`    | `PqsPrepassRenderTarget0`     | ARGB32    | `LAYERS4(R, x)` — 4 per-layer height/slope gates for biome R       |
| `Tex1`    | `PqsPrepassRenderTarget1`     | ARGB32    | `LAYERS4(G, y)` — 4 per-layer height/slope gates for biome G       |
| `Tex2`    | `PqsPrepassRenderTarget2`     | ARGB32    | `LAYERS4(B, z)` — 4 per-layer height/slope gates for biome B       |
| `Tex3`    | `PqsPrepassRenderTarget3`     | ARGB32    | `LAYERS4(A, w)` — 4 per-layer height/slope gates for biome A       |
| `Tex4`    | `PqsPrepassRenderTarget4`     | ARGBHalf  | `float4(blendedNorm, 1.0)` — raw world-space blended terrain normal|

This mapping is what the *original* `CelestialBody_Local` shader uses (via
the decompiled `pass13.hlsl`). The deferred-pass consumer comments
(`_LocalSpacePrepassTex0` → "screen-space prepass normals", `Tex4` →
"projection-ratio") describe the `New` shader's intended Tex0/Tex4 swap;
the original Local shader does NOT match those comments. v3 follows the
original Local mapping for parity with the comparison reference.

## Notes

- The `_NormalScaledTex` rename in `pass13.hlsl` / `pass14.hlsl` / `pass15.hlsl`
  (commit `37068fd17`) is **unrelated** to these 5 RTs. SPIRV-Cross
  collapsed two distinct game textures to the name `_LocalSpacePrepassTex0`:
  the prepass writes to that name, *and* a separately bound texture (the
  planet's baked scaled-space normal map = `_NormalScaledTex`) was sampled
  through the same name at terrain UV with a DXT5nm decode. The deferred
  prepass-write target (the RT in this table) and the bound input map are
  two different textures — the rename broke the alias.
- "Source of truth": when reverse-engineering further, trust what the
  deferred consumers do with each sample over what the prepass shader's
  decompiled symbol names claim.
- Captures live under `Temp/ShaderComparison/<job>/perpass/{left,right}/prepass/`
  after a `--per-pass` run of `pqs-shader-compare.sh`. File names:
  `tex0.png`, `tex1.png`, `tex2.png`, `tex3.png` (RGB only — alpha
  forced opaque), `tex0_a.png`..`tex3_a.png` (alpha as 8-bit greyscale),
  and `normal.png` (Tex4, ARGBHalf, alpha is always 1.0).
