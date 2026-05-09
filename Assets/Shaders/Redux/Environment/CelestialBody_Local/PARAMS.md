# CelestialBody_Local — Authoring Reference

This document is for artists authoring or modifying planets that use
`Redux/Environment/CelestialBody/CelestialBody_Local_v3`. It explains how the
material parameters add up visually on the surface and which textures control
which features. It deliberately glosses over implementation details and
focuses on the questions you'll actually ask while painting a planet:
*"which texture do I edit to change how grass looks on the green biome?"*,
*"how do I make the snow only appear above 4000 m?"*, *"why doesn't my detail
texture appear from orbit?"*, and so on.

---

## 1. Overview

A KSP2 planet is rendered in two distinct visual "regimes" that the shader
cross-fades automatically based on camera distance:

* **Scaled space** — the view from far away (orbit, map view, or anything
  past a few kilometers). The surface is drawn as a single textured sphere
  using whole-planet **scaled-space** maps: an overall albedo, a normal map,
  a packed metallic/AO/emission/smoothness map, and an emission color map.
  These are the maps you typically bake out of the planet's Megatextures or
  hand-paint in equirectangular layout.
* **Local space** — the view up close (kilometers down to centimeters).
  The shader composites a *biome-driven detail stack* on top of the
  scaled-space backdrop. As you fly down, scaled-space maps fade out and
  the detail stack fades in.

The detail stack is what does the heavy lifting visually when the player is
walking, driving a rover, or hovering at low altitude. It's organised as
follows:

1. **Biomes (4 channels)** — the planet has up to 4 simultaneously-blended
   "biomes" identified by the four channels (R, G, B, A) of a single
   `_BiomeMaskTex`. Examples: R = grasslands, G = desert, B = mountains,
   A = polar.

2. **Layers within a biome (4 layers)** — each biome can show up to 4
   different surface materials (called *layers*). A "grasslands" biome might
   layer `dirt`, `short_grass`, `tall_grass`, and `flowers`. Which layer
   wins at a given pixel depends on:
   - the local **terrain height** (so e.g. tall grass only appears below
     the tree line),
   - the local **slope** (so cliffs show rock instead of grass),
   - the per-pixel **height-map values** sampled from the Large/Mid/Subzone
     gradience textures (so the same biome breaks up into patches that
     follow real terrain features rather than tiling perfectly).

3. **Subzones (optional, 4 channels)** — a second mask, `_SubzoneMaskTex`,
   adds *up to 4 additional* per-pixel weight controls *on top of* the
   biome mask. Subzones don't introduce new biomes: they re-tint, re-bias,
   and re-weight the existing per-biome layers. Use them for things like
   "this strip of grasslands has slightly redder dirt and slightly brighter
   flowers", or to create *wear patterns*, *shoreline tint bands*, or
   *transition strips* that don't warrant a full biome. Subzones are
   activated by the `SUB_ZONES_ENABLED` shader keyword (set per-material).

4. **Decals (optional)** — separately-managed "stickers" projected
   onto the surface (e.g. KSC tarmac, monolith outlines, scorch marks).
   These are not authored from the material; they're spawned at runtime by
   `PqsDecalInstance` components. The material only exposes their
   *texture arrays* and a *fade range*. Activated by the `DECALS_ENABLED`
   keyword.

The shader is a **deferred** shader: it writes to the Unity GBuffer
(albedo, specular F0, world normal, occlusion, emission). It does NOT
compute lighting itself; lighting is applied later by the deferred lighting
pass. So nothing you do in this material affects shadows or sun direction —
only what each surface pixel "looks like" before it gets lit.

---

## 2. Configuring the shader (the broad shape)

### 2.1 Texture stack from far to near

Conceptually each pixel composites *up to seven* textures in distance-fade
order. From orbit downward:

| Distance | Source | Visual role |
|---|---|---|
| Farthest | `_AlbedoScaledTex` / `_NormalScaledTex` / `_PackedScaledTex` / `_EmissionScaledTex` | Whole-planet maps. The "thumbnail" of the planet. |
| Far | `_LargeNormal*`, `_LargeGradience*`, `_LargeCurvature*` | Per-biome large-scale surface variation (continent-sized streaks, regional erosion patterns). |
| Mid | `_MidNormal*`, `_MidGradience*`, `_MidCurvature*` | Per-biome mid-scale variation (ridge-sized features). |
| Mid (subzone-only) | `_Subzone3Normal*`, `_Subzone3Gradience*`, `_Subzone3Curvature*` | Additional mid-tier detail unlocked by subzones. |
| Mid (subzone-only) | `_Subzone4Normal*`, `_Subzone4Gradience*`, `_Subzone4Curvature*` | Additional mid-tier detail unlocked by subzones. |
| Near | `_SmallAlbedoArray`, `_SmallNormalArray`, `_SmallMetalArray` | Up-close detail tiles (4 layers × 4 biomes = up to 16 tiles per planet). |
| Closest | `_DecalAlbedo`, `_DecalNormalSAO`, `_DecalAlphaMask` | Projected stickers (optional). |

Every "Large", "Mid", "Subzone3", "Subzone4" texture exists *per biome
channel* (R/G/B/A), so e.g. `_LargeNormalR` only contributes where the R
biome is active.

### 2.2 The biome model

```
                _BiomeMaskTex (RGBA)
                    │   (one full-planet equirectangular)
                    ▼
       ┌────────────┴─────────────────┐
       │ R  G  B  A  ← per-pixel weights, normalised to sum to 1
       │
       │ For each biome, 4 layers:
       │   layer1, layer2, layer3, layer4
       │   each pointing to a slice in _SmallAlbedoArray etc.
       │
       │ A layer "wins" at a pixel depending on:
       │   • terrain height vs _SmallBiome*HeightParams*
       │   • terrain slope  vs _SmallBiome*SlopeParams*
       │   • height-map gradient (from _LargeGradience* + _MidGradience*)
       │   • subzone mask (if SUB_ZONES_ENABLED)
       └──────────────────────────────┘
```

A typical authoring loop:

1. Paint `_BiomeMaskTex` so each channel covers the regions of the planet
   that should display that biome's materials. Channels can overlap
   smoothly to crossfade.
2. Pick four detail tiles per biome from `_SmallAlbedoArray`/`_SmallNormalArray`/`_SmallMetalArray`
   and write their slice indices into `_SmallBiomeR`/`_SmallBiomeG`/
   `_SmallBiomeB`/`_SmallBiomeA` (each is a `Vector4` of slice indices for
   layers 1..4, with `-1` meaning "this layer is unused").
3. Per layer, decide *where* in altitude / slope it should appear via
   `_SmallBiome*HeightParams*` and `_SmallBiome*SlopeParams*`.
4. Optionally tint, brighten, contrast-adjust, saturate, or add emission via
   `_SmallTint*`, `_SmallBrightness*`, `_SmallContrast*`, etc.
5. If you need finer-grained variation than 4 biomes can give you, enable
   subzones and paint `_SubzoneMaskTex` to drive per-strip tint/weight
   overrides via the `_SmallSubzone*` family.

### 2.3 Distance cascades

Most "small" detail tiles can re-tile at multiple ranges. You'll pick a
"resample max" per layer (`_SmallDistanceResampleMax*`, integer 0..4) which
controls how aggressively that layer resamples at distance. The common
fade ranges live in `_DistanceResampleDistances`,
`_DistanceResampleUVScales`, `_DistanceResampleAlbedoOpacity`,
`_DistanceResampleNormalOpacity`. Use higher resample-max values on layers
where tiling is visible from a distance (rock, gravel, lichen) and 0 on
very smooth materials (snow, sand, mud) where retiling does nothing.

### 2.4 Quality / keyword toggles

Two checkbox-style controls flip large parts of the pipeline:

* **`_HighQualityEnabled` / `LOW_QUALITY` keyword** — currently a
  display-only toggle in this V3 port; reserved for future quality-tier
  switches. Leave it on.
* **`SUB_ZONES_ENABLED` (per-material keyword)** — enables the subzone
  pipeline. When off, all `_SmallSubzone*` and `_Subzone3*` / `_Subzone4*`
  parameters are ignored.
* **`ANTI_TILE_QUALITY_ON` (per-material keyword)** — enables stochastic
  hex-grid anti-tiling on the small-biome detail samples. Heavier on the
  GPU but eliminates obvious tile repetition on uniform fields.
  Controlled by `_StochasticScale`.
* **`UNITY_HDR_ON`** — set automatically by the renderer when the camera
  uses HDR. You should not flip this manually.

---

## 3. Parameter reference

Parameters are grouped by what they visually control. Within each group, the
R/G/B/A variants correspond to the four biome channels and behave
identically — pick whichever channel matches your biome. Parameters that
are "per layer" come in `1..4` variants, one per layer slot inside a biome.

### 3.1 Scaled-space (view from orbit)

The whole-planet equirectangular maps. These dominate the look from any
range past a few kilometers and provide a smooth transition into the local
detail stack as the camera approaches.

| Parameter | Type | What it does |
|---|---|---|
| `_AlbedoScaledTex` | 2D | Whole-planet base color (RGB). Diffuse appearance from orbit. |
| `_AlbedoScaledFadeParams` | Vector | `(start, range, nearOpacity, farOpacity)` distance fade for the scaled albedo. The scaled albedo gradually attenuates toward `farOpacity` over `range` meters starting at `start` so the local detail can take over. |
| `_NormalScaledTex` | 2D (Normal) | Whole-planet normal map. Drives lighting from orbit. |
| `_NormalScaledFadeParams` | Vector | Same `(start, range, near, far)` shape. Controls how aggressively the orbital normal map gives way to the per-biome Mid/Large/Small normal layers. |
| `_PackedScaledTex` | 2D | Channel-packed: `R = Metallic`, `G = Occlusion`, `B = Emission strength`, `A = Smoothness`. One texture covers PBR + emission for the scaled-space pass. |
| `_PackedScaledFadeParams` | Vector | Distance fade for the packed map. |
| `_EmissionScaledTex` | 2D | Whole-planet emission *color*. Multiplied by `_PackedScaledTex.B` (the emission strength channel) and then by `_EmissionScale`. Use for night-side city lights, lava glow, ice fluorescence. |
| `_EmissionScaledFadeParams` | Vector | Distance fade for emission. |
| `_EmissionScale` | Range(0..20) | Global emission intensity multiplier. 0 disables emission entirely. |

### 3.2 Biome control (the master mask)

These define which biome covers which part of the planet.

| Parameter | Type | What it does |
|---|---|---|
| `_BiomeMaskTex` | 2D (RGBA) | The single source of truth for biome coverage. `R/G/B/A` are 0..1 weights for biomes 1..4. Channels do not need to sum to 1 — the shader normalises them per-pixel — but you generally want a smooth crossfade where two biomes meet. |
| `_BiomeCutoffs` | Vector(4) | Per-channel hard cutoff thresholds. Reserved for biome gating; currently consumed by the editor only. |
| `_SubzoneMaskTex` | 2D (RGBA) | Subzone weight map (only meaningful when `SUB_ZONES_ENABLED`). 4 channels of 0..1 weights that re-bias the per-biome layers. Treat this as a "tint/wear/strip" layer over the top of the biome mask. |

### 3.3 Triplanar / projection setup

How the shader projects 2D detail tiles onto the (curved, deformed) planet
surface.

| Parameter | Type | What it does |
|---|---|---|
| `_TriplanarContrast` | Range(1..8) | How sharply the three triplanar projections blend at edges. Low = soft, smeared transitions across rock edges; high = crisp boundaries with little blending. 4 is the typical default. |
| `_TriplanarUVScaleOffset` | Vector | `(scaleX, scaleY, offsetU, offsetV)` shared by all triplanar samples. Adjusts the "world size" of the triplanar projection grid. Scaling down here makes every Small biome tile bigger; scaling up makes them smaller. |
| `_StochasticScale` | Range(0.25..2) | Hex-grid period for the anti-tiling system (only when `ANTI_TILE_QUALITY_ON`). Smaller = more frequent stochastic re-shuffles (better tile breakup, more sample blur); larger = larger uniform patches. |
| `_Radius` | Float | Planet radius in PQS units. Used by the decal apply loop to cull decals too far away to influence the local terrain. Should match the body's actual radius; usually set automatically by `PQSRenderer`. |

### 3.4 Large and Mid normal/curvature/gradience layers (per biome)

These are the *low-frequency* biome-specific layers. They modulate normals
(for shading), heightmap gradients (for layer selection), and curvature
weights at large/mid scales. They sample once per pixel from per-biome
textures.

The four biome channels share the same parameter shape — only the names
change. Replacements: `R → G → B → A` for each variant.

#### 3.4.1 Large textures (Continent / region scale)

| Parameter group | Type | What it does |
|---|---|---|
| `_LargeNormalR`, `_LargeNormalG`, `_LargeNormalB`, `_LargeNormalA` | 2D (Normal) | Per-biome large-scale normal map. Adds long, sweeping normal variation across the biome — wind-shaped sand, eroded rock striations, glacial flow lines. |
| `_LargeNormalRUVParams`, `_LargeNormalGUVParams`, `_LargeNormalBUVParams`, `_LargeNormalAUVParams` | Vector | `(uScale, vScale, uOffset, vOffset)` UV transform for that biome's Large normal map. |
| `_LargeNormalRFadeParams`, …G/B/A | Vector | `(start, range, near, far)` distance fade. The Large normal layer fades out at extreme range so it doesn't double up with the scaled normal map. |
| `_LargeGradienceR`, …G/B/A | 2D | Per-biome large-scale **height** field (grayscale). Used both to bias which detail layer wins (peaks vs. valleys) and to feed the slope-gradient calculation. |
| `_LargeCurvatureR`, …G/B/A | 2D | Per-biome large-scale **curvature** map. Currently reserved (declared but not yet consumed by V3). When ported, it will modulate per-layer presence based on terrain concavity/convexity. |
| `_LargeHeightMapUVScales` | Vector(4) | One scalar per biome (`R, G, B, A`) — UV scale applied to its `_LargeGradience*`. Higher = the height field tiles more frequently. |
| `_LargeRSubzoneFilter`, …G/B/A | Vector(4) | Per-biome subzone-mask filter. Only used when `SUB_ZONES_ENABLED`: this is a 4-vector that's dotted with the 4-channel subzone mask to produce a per-pixel scalar; that scalar multiplies that biome's Large normal/gradience contribution. Use it to suppress the Large layer in specific subzone areas (e.g. zero out Large on a glassy lakebed strip). |

#### 3.4.2 Mid textures (Ridge / outcrop scale)

Identical shape to Large, but tiled at a finer rate and used for
mid-frequency variation (formations, smaller dune systems, eroded
ridgelines). Same parameter family with the `_Mid` prefix:

| Parameter | Notes |
|---|---|
| `_MidNormalR/G/B/A` | Per-biome mid normal map. Triplanar-sampled. |
| `_MidNormalRUVParams/…` | Per-biome UV transform. |
| `_MidNormalRFadeParams/…` | Per-biome distance fade. |
| `_MidGradienceR/G/B/A` | Per-biome mid-scale height field. |
| `_MidCurvatureR/G/B/A` | Per-biome mid-scale curvature (reserved). |
| `_MediumHeightMapUVScales` | Per-biome scalar UV scale, packed as `(R, G, B, A)`. |
| `_MidRSubzoneFilter/…` | Per-biome subzone-driven multiplier. |

### 3.5 Subzone-only mid layers (Subzone3, Subzone4)

Additional per-biome mid-tier layers that only contribute when
`SUB_ZONES_ENABLED`. Use these for *tier-2* detail above and beyond
Large/Mid — e.g. lichen patches on the rocks, cracked soil within
desert, drift snow patterns. There are TWO independent tiers (Subzone3 +
Subzone4) so you can stack effects.

Important: unlike Large and Mid, these normal layers come from a
*Texture2DArray* (`_SubZonesNormalTextureArray`) and are addressed by
slice indices instead of being separate 2D textures. The slice indices
live in `_Subzone3NormalIndices` and `_Subzone4NormalIndices` (one
`Vector4` per subzone, with `(R, G, B, A)` = slice index for each biome).

| Parameter | Notes |
|---|---|
| `_SubZonesNormalTextureArray` | 2D Array shared by both Subzone3 and Subzone4 across all biomes. Slot index `-1` = "this biome doesn't use a subzone normal." |
| `_Subzone3NormalIndices` / `_Subzone4NormalIndices` | Per-biome slice-into-array. `(R = biome-R slice, G = biome-G slice, …)`. |
| `_Subzone3NormalRUVParams` / …G/B/A, plus `_Subzone4` variants | UV transform per biome, per subzone. |
| `_Subzone3NormalRFadeParams` / …, plus `_Subzone4` | Distance fade per biome, per subzone. |
| `_Subzone3GradienceR` / …G/B/A, `_Subzone4GradienceR` / … | Per-biome, per-subzone tier-2 height field (grayscale 2D). |
| `_Subzone3CurvatureR` / …, `_Subzone4CurvatureR` / … | Per-biome, per-subzone curvature (reserved). |
| `_Subzone3HeightMapUVScales`, `_Subzone4HeightMapUVScales` | Per-biome scalar UV scale, packed `(R, G, B, A)`. |
| `_Subzone3RSubzoneFilter` / …G/B/A, `_Subzone4RSubzoneFilter` / … | Per-biome subzone-mask weighting (same role as `_LargeRSubzoneFilter`). |

### 3.6 Small biome detail (per biome × per layer)

This is where the up-close visual identity of each biome is authored.
Each biome (R, G, B, A) has 4 layer slots. Each slot picks a slice in the
shared `_SmallAlbedoArray` / `_SmallNormalArray` / `_SmallMetalArray` and
applies a stack of color/grading/PBR controls.

In the table below, `<C>` stands for the biome channel (R, G, B, or A) and
`<i>` stands for the layer index (1..4). All four biome channels have
identical parameter shapes.

#### 3.6.1 Slice selection and per-layer enable

| Parameter | Type | What it does |
|---|---|---|
| `_SmallAlbedoArray` | 2D Array | The pool of albedo tiles. One slice per material (e.g. one for grass, one for sand, one for granite). |
| `_SmallNormalArray` | 2D Array | The pool of normal+packed tiles. Each slice's `RGBA` is `(metallic-influence, normalY, AO, normalX)` packed (DXT5nm-style). |
| `_SmallMetalArray` | 2D Array | The pool of metallic-mask tiles. Sampled `R` channel is the per-tile metallic value. |
| `_SmallBiome<C>` | Vector(4) | `(layer1, layer2, layer3, layer4)` slice indices for this biome. `-1` disables that layer slot. |
| `_SmallEnable<C>` | Vector(4) | Per-layer "active" toggle, 0 or 1 per layer. Use to mute a layer without resetting its slice index. |
| `_SmallHeightWeight<C>` | Vector(4) | Per-layer master weight applied before height/slope gating. Treat as the layer's "global intensity" — 0 hides it, 1 makes it eligible everywhere this biome is active. |
| `_SmallWeightSoftness<C>` | Vector(4) | Per-layer height-blend softness. Lower values produce sharper transitions between layers (e.g. crisp snow line); higher values produce softer feathering. |

#### 3.6.2 Per-layer placement (height / slope / peak/cavity)

Each layer can be gated by altitude *and* slope. The gating is a
"trapezoidal window" — the layer is fully active inside the window and
fades out at the edges.

| Parameter | What it does |
|---|---|
| `_SmallBiomeHeightEnable<C>` | Per-layer 0/1 enable for the height window. 0 = the layer ignores altitude. |
| `_SmallBiome<C>HeightParams<i>` | Per-layer altitude window: `(center, upRange, downRange, fadeOut)`. The layer is at full strength between `(center - downRange)` and `(center + upRange)` and fades out over `fadeOut` meters. Use this to keep snow above the snow line, sand below the dune line, etc. |
| `_SmallBiomeSlopeEnable<C>` | Per-layer 0/1 enable for the slope window. |
| `_SmallBiome<C>SlopeParams<i>` | Per-layer slope window in degrees: `(center, upRange, downRange, fadeOut)`. The layer is at full strength inside the angular window. Use this to put grass on flat ground (center ≈ 0°, narrow range) and rock on cliffs (center ≈ 90°). |
| `_SmallBiome<C>GradMapWeights<i>` | Per-layer 4-vector that mixes the per-pixel height-map gradient into the slope test. Components are `(aux/biome, large, mid, unused)` — use this to "add" the bumpiness from `_LargeGradience*` and `_MidGradience*` into the layer's effective slope. Higher values = the layer responds more to height-map bumps even on geometric flats. |
| `_SmallBiomePeakCavEnable<C>` | Per-layer 0/1 enable for the peak/cavity (curvature) window. *Reserved — declared but not yet consumed by V3.* |
| `_SmallBiome<C>PeakCavParams<i>` | Per-layer peak/cavity window. *Reserved.* |
| `_SmallBiome<C>CurvMapWeights<i>` | Per-layer curvature-map mix. *Reserved.* |
| `_SmallDistanceResampleMax<C>` | Per-layer distance-resample tier (0..4). 0 = no resample, 4 = aggressive resample at all 4 distance bands. Higher tiers cost more samples but reduce visible tile repetition at range. |

#### 3.6.3 Per-layer UVs

| Parameter | What it does |
|---|---|
| `_SmallUVScale<C>` | `(layer1, layer2, layer3, layer4)` UV scale. Bigger = the tile prints smaller on the surface; smaller = bigger prints. |
| `_SmallUVOffset<C>` | `(layer1..4)` UV offset. Use to break up alignment between two layers that share the same tile. |

#### 3.6.4 Per-layer color grading

| Parameter | What it does |
|---|---|
| `_SmallTint<C>1` … `_SmallTint<C>4` | Per-layer tint color (RGBA). RGB multiplies the layer's albedo; A multiplies the layer's height-blend alpha (so you can fade a layer's *coverage* without changing its color). |
| `_SmallBrightness<C>` | `(layer1..4)` additive brightness. Pushes the layer brighter (positive) or darker (negative) before contrast/saturation. |
| `_SmallContrast<C>` | `(layer1..4)` contrast multiplier around mid-gray (~0.218). 1 = neutral, &gt;1 = punchier, &lt;1 = washed out. |
| `_SmallSaturation<C>` | `(layer1..4)` saturation multiplier. 0 = grayscale, 1 = neutral, &gt;1 = oversaturated. |

#### 3.6.5 Per-layer PBR controls

| Parameter | What it does |
|---|---|
| `_SmallNormalStrength<C>` | `(layer1..4)` multiplier on the layer's normal map. 0 = flat, 1 = neutral, &gt;1 = exaggerated. |
| `_SmallGlossStrength<C>` | `(layer1..4)` smoothness multiplier. Set ≥ 15 to switch to *override* mode (the layer forces a fixed smoothness instead of multiplying the source map). |
| `_SmallMetallicStrength<C>` | `(layer1..4)` metallic multiplier. Same ≥ 15 override convention. |
| `_SmallAOStrength<C>` | `(layer1..4)` AO power. Higher = more aggressive ambient occlusion contribution from the layer. |

#### 3.6.6 Per-layer emission

Per-layer self-illumination. Useful for crystal veins, glowing fungi, lava
cracks, bioluminescent plankton in shallow water, etc.

| Parameter | What it does |
|---|---|
| `_SmallEmissionStrength<C>` | `(layer1..4)` emission strength multiplier. |
| `_SmallEmissionColor<C>1` … `_SmallEmissionColor<C>4` | Per-layer emission color (HDR). |

### 3.7 Subzone overrides (per biome × per layer × per subzone)

Active only when `SUB_ZONES_ENABLED`. These let you re-weight, re-tint, and
re-brighten the existing per-biome layers based on the 4-channel subzone
mask. They do *not* introduce new layers; they modulate the same 4 layers
defined above.

Naming convention: `_SmallSubzone<Property><C><i>` (where the property is
Weight/Brightness/Tint, `<C>` is the biome channel, and `<i>` is the layer
index 1..4). Each is a `Vector4` indexed by subzone channel.

| Parameter | What it does |
|---|---|
| `_SmallSubzoneWeight<C><i>` | `(sz0, sz1, sz2, sz3)` per-subzone-channel weight applied to layer `i` of biome `C`. Replaces the constant `_SmallHeightWeight<C>.<i>` in SZ mode — i.e. lets you say "layer 2 of biome R is twice as strong inside subzone 0, off inside subzone 2". |
| `_SmallSubzoneBrightness<C><i>` | `(sz0, sz1, sz2, sz3)` per-subzone-channel additive brightness for layer `i`. |
| `_SmallSubzoneTint<C><i>_R` / `_G` / `_B` / `_A` | Per-subzone-channel tint color for layer `i`. The four `_R/_G/_B/_A` suffix variants correspond to the four *subzone channels* (NOT the biome channels). At a pixel, the four subzone-channel tints are weighted-blended by `_SubzoneMaskTex` to produce the effective tint for that layer. So `_SmallSubzoneTintR2_G` = "the tint to apply to biome R's layer 2 inside subzone-G areas." |

The *alpha* (`.w`) of `_SmallSubzoneTint<C><i>_R` and `_SmallSubzoneTint<C><i>_G`
plays a *second* role: in the prepass it scales the contribution of the
Subzone3 and Subzone4 height maps respectively into that layer's slope
gradient. So this is also where you tell each layer "respond to Subzone3
height bumps with strength X, Subzone4 with strength Y."

### 3.8 Decals

Projected stickers managed by `PqsDecalInstance`. Activated by the
`DECALS_ENABLED` keyword. The shader exposes the *content* (texture arrays
+ a global fade range); the *placements* are bound at runtime via a
structured buffer.

| Parameter | Type | What it does |
|---|---|---|
| `_DecalAlbedo` | 2D Array | Decal albedo+coverage tiles. RGB = decal color, A = decal coverage / mask. |
| `_DecalNormalSAO` | 2D Array | Decal packed normal/SAO tiles. Same packing as `_SmallNormalArray`. |
| `_DecalAlphaMask` | 2D Array | Optional secondary alpha mask. Used per-decal when `UseTextureAlphaMask` is set. |
| `_DecalControl` | 2D | Reserved (declared but not yet consumed by V3). |
| `_DecalStaticData` | 2D | Reserved. |
| `_DecalFadeParams` | Vector | `(start, end, nearOpacity, farOpacity)` global decal distance fade. Decals fully appear within `start..end` meters and lerp toward `farOpacity` past that range. Use this to keep decals from drawing on far-LOD terrain where their projection accuracy degrades. |

### 3.9 Distance-cascade resample (shared)

These control the at-distance retiling of the small-biome detail. They
apply identically to all 4 biomes and all 4 layers; per-layer aggressiveness
is dialled in via `_SmallDistanceResampleMax<C>`.

| Parameter | What it does |
|---|---|
| `_DistanceResampleDistances` | Vector(4) | The four distance band centers, in meters. |
| `_DistanceResampleUVScales` | Vector(4) | UV scale at each band — typically a power-of-2 cascade like `(1, 2, 4, 8)` so each band tiles 2× larger than the previous. |
| `_DistanceResampleAlbedoOpacity` | Vector(4) | Per-band albedo opacity. Use to soften retiling at far range. |
| `_DistanceResampleNormalOpacity` | Vector(4) | Per-band normal opacity. Same idea for the per-layer normal contribution. |
| `_DistanceResampleFadeRangesPos` / `_DistanceResampleFadeRangesNeg` | Vector(4) | (Hidden / runtime-driven.) Computed at runtime from `_DistanceResampleDistances`; do not edit by hand. |
| `_DistanceResampleFades` | Vector(4) | (Hidden / runtime-driven.) |

### 3.10 Cross-biome blend controls

These tune *how* the four biomes' contributions are composited together.
You'll rarely change them per-planet — they're more like global "feel"
knobs.

| Parameter | What it does |
|---|---|
| `_HeightblendFactor` | Vector(4) | Bias applied to per-layer height-blend selection. Effectively controls how "harshly" the highest-weight layer takes over within a biome. The X component is the active one in the current shader; lower values = softer all-layers blend, higher values = the dominant layer wins more aggressively. |
| `_AlphaToHeightFadeParams` | Vector | `(start, range, nearMix, farMix)` distance fade for the alpha-vs-heightmap blend mode. Up close the blend uses the full height-map signal; at distance it falls back to a weight-normalised average. |
| `_GlobalBlend` | Vector(4) | Per-biome master blend strength. Multiplies the entire per-biome contribution. Useful for fading a biome out globally without zeroing every layer. |
| `_GlobalGradienceTex` | 2D | Reserved (declared but not yet consumed by V3). |
| `_GlobalCurvatureTex` | 2D | Reserved. |

### 3.11 Misc

| Parameter | What it does |
|---|---|
| `_Transition` | Float | Dither-fade alpha test value. 0 = fully visible, 1 = fully discarded. Used by `PQSRenderer` during quad LOD transitions to crossfade tiles. Don't edit manually. |
| `_ShorelineTex` | 2D | Reserved (declared but not yet consumed by V3). When ported, will drive per-pixel shoreline tinting near sea level. |
| `_HighQualityEnabled` | Float | Toggle for quality-tier branching. Reserved. Leave at 1. |
| `_LocalSpacePrepassTex0..4` | 2D (HideInInspector) | Internal — written by the prepass passes (passes 13/14/15) and consumed by the deferred passes (1..11). Do not edit. |

---

## 4. Practical authoring tips

* **Start at orbit, work down.** Author the scaled-space maps first and get
  the planet looking right at distance. Then add biomes; then per-biome
  Large/Mid layers; then small detail tiles; then subzones if needed; then
  decals.

* **Use the biome mask as a creative tool, not just a label.** The shader
  blends biomes smoothly per-pixel, so painting a soft green-to-tan
  transition in the mask will produce a soft grass-to-sand transition on
  the surface — no per-layer tinkering required.

* **Reuse small tiles aggressively.** All 4 biomes share `_SmallAlbedoArray`.
  A "rock" tile in slot 5 can be layer 4 of biome R *and* layer 3 of biome
  B with totally different tints — saves array memory and gives you
  free visual cohesion across biomes.

* **Match Large height ranges to your terrain elevation actual.** The
  altitude windows in `_SmallBiome<C>HeightParams<i>` are in meters of
  *terrain height* — set them with the actual terrain elevation in mind,
  not arbitrary numbers.

* **If a layer "refuses to appear":** verify (in this order) that
  `_SmallBiome<C>.<i>` is ≥ 0 (the slice index is set), `_SmallEnable<C>.<i>`
  is 1, `_SmallHeightWeight<C>.<i>` is &gt; 0, the height window contains
  the camera-pixel altitude, the slope window contains the local slope
  angle, and the biome mask channel is non-zero at that pixel. Layers
  silently drop out if any of these gates fail.

* **Anti-tile is per-material.** Toggle `ANTI_TILE_QUALITY_ON` in the
  material — don't try to global-toggle it. It's worth enabling on
  uniform terrain (deserts, ice fields) and disabling on complex,
  patterned biomes where the stochastic blur softens authored detail.

* **Subzones are not a substitute for biomes.** If two areas need
  different *materials*, use two biome channels. Use subzones only to
  modify *the same* materials with tints/weights/strips.
