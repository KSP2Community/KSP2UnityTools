// ============================================================================
// CelestialBody_Local.shader
//
// Properties and pass structure for the local-space (near-camera) PQS terrain
// shader.  Each Pass dispatches into one of the per-pass-kind cginc files via
// a PASS_* define; see CelestialBody_Local.cginc for the include graph.
// ============================================================================
Shader "Redux/Environment/CelestialBody_Local"
{
	Properties
	{
		// ===== Scaled-space maps (PARAMS §3.1) =====
		// Whole-planet equirectangular maps. Dominate the look from orbit and
		// crossfade out as the local detail stack takes over. Each *FadeParams
		// is (start, range, nearOpacity, farOpacity). _PackedScaledTex packs
		// (R=Metallic, G=Occlusion, B=Emission, A=Smoothness).
		_AlbedoScaledTex ("Scaled-space Albedo Map (RGB)", 2D) = "white" {}
		_AlbedoScaledFadeParams ("Scaled-space Albedo Fade Params", Vector) = (0,20000,0.5,1)
		_NormalScaledTex ("Scaled-space Normal Map", 2D) = "bump" {}
		_NormalScaledFadeParams ("Scaled-space Normal Fade Params", Vector) = (0,20000,0.5,1)
		_PackedScaledTex ("Scaled-space Packed Map (Metallic, Occlusion, Emission, Smoothness)", 2D) = "black" {}
		_PackedScaledFadeParams ("Scaled-space Packed Fade Params", Vector) = (0,20000,0.5,1)
		_EmissionScaledTex ("Scaled-space Emission Map", 2D) = "black" {}
		_EmissionScaledFadeParams ("Scaled-space Emission Fade Params", Vector) = (0,20000,0.5,1)
		_EmissionScale ("Scaled-space Emission Scale", Range(0, 20)) = 0

		// ===== LOD transition (PARAMS §3.11) =====
		// Dither alpha-test driven by PQSRenderer during quad LOD swaps.
		// Don't edit by hand.
		_Transition ("Transition", Float) = 0

		// ===== Biome control (PARAMS §3.2) =====
		// Master mask: which biome covers which part of the planet. R/G/B/A
		// are the four biome channels. _SubzoneMaskTex adds 4 extra weight
		// channels when SUB_ZONES_ENABLED.
		_BiomeMaskTex ("Biome Mask Map", 2D) = "red" {}
		_BiomeCutoffs ("Biome Cutoffs", Vector) = (0,0,0,0)
		_SubzoneMaskTex ("Subzone Mask Map", 2D) = "white" {}

		// ===== Global gradience / curvature (PARAMS §3.10, reserved) =====
		_GlobalGradienceTex ("Global Gradience Map", 2D) = "black" {}
		_GlobalCurvatureTex ("Global Curvature Map", 2D) = "black" {}

		// ===== Per-biome height-map UV scales (PARAMS §3.4 / §3.5) =====
		// One scalar per biome (R,G,B,A) -- UV scale on each tier's gradience map.
		_LargeHeightMapUVScales ("Large Grad Map UV Scales", Vector) = (1,1,1,1)
		_MediumHeightMapUVScales ("Medium Grad Map UV Scales", Vector) = (1,1,1,1)
		_Subzone3HeightMapUVScales ("Subzone 3 Grad Map UV Scales", Vector) = (1,1,1,1)
		_Subzone4HeightMapUVScales ("Subzone 4 Grad Map UV Scales", Vector) = (1,1,1,1)

		// ===== Triplanar projection (PARAMS §3.3) =====
		// Controls how 2D detail tiles project onto the curved planet surface.
		_TriplanarContrast ("Triplanar Contrast", Range(1, 8)) = 4
		_TriplanarUVScaleOffset ("Triplanar UV Scale/Offset", Vector) = (1,1,0,0)

		// ===== Subzone normal slice indices (PARAMS §3.5) =====
		// Per-biome (R,G,B,A) slice into _SubZonesNormalTextureArray. -1 disables.
		_SubZonesNormalTextureArray ("Sub Zones Normal Array", 2DArray) = "bump" {}
		_Subzone1NormalIndices ("Subzone 1 Normal Array Indices", Vector) = (-1,-1,-1,-1)
		_Subzone2NormalIndices ("Subzone 2 Normal Array Indices", Vector) = (-1,-1,-1,-1)
		_Subzone3NormalIndices ("Subzone 3 Normal Array Indices", Vector) = (-1,-1,-1,-1)
		_Subzone4NormalIndices ("Subzone 4 Normal Array Indices", Vector) = (-1,-1,-1,-1)

		// ===== Large per-biome layer: continent / region scale (PARAMS §3.4.1) =====
		// Low-frequency normal/gradience/curvature maps per biome (R/G/B/A).
		// Each only contributes where its biome mask is active. Curvature is
		// reserved (declared but not yet consumed by V3). _Large*SubzoneFilter
		// dotted with the subzone mask scales Large per zone.
		_LargeCurvatureR ("Large Curvature R", 2D) = "black" {}
		_LargeCurvatureG ("Large Curvature G", 2D) = "black" {}
		_LargeCurvatureB ("Large Curvature B", 2D) = "black" {}
		_LargeCurvatureA ("Large Curvature A", 2D) = "black" {}
		_LargeGradienceR ("Large Gradience R", 2D) = "black" {}
		_LargeGradienceG ("Large Gradience G", 2D) = "black" {}
		_LargeGradienceB ("Large Gradience B", 2D) = "black" {}
		_LargeGradienceA ("Large Gradience A", 2D) = "black" {}
		_LargeNormalR ("Large Normal R", 2D) = "bump" {}
		_LargeNormalG ("Large Normal G", 2D) = "bump" {}
		_LargeNormalB ("Large Normal B", 2D) = "bump" {}
		_LargeNormalA ("Large Normal A", 2D) = "bump" {}
		_LargeNormalRUVParams ("Large Normal R UV Params", Vector) = (1,1,0,0)
		_LargeNormalGUVParams ("Large Normal G UV Params", Vector) = (1,1,0,0)
		_LargeNormalBUVParams ("Large Normal B UV Params", Vector) = (1,1,0,0)
		_LargeNormalAUVParams ("Large Normal A UV Params", Vector) = (1,1,0,0)
		_LargeNormalRFadeParams ("Large Normal R Fade Params", Vector) = (0,10000,0.5,1)
		_LargeNormalGFadeParams ("Large Normal G Fade Params", Vector) = (0,10000,0.5,1)
		_LargeNormalBFadeParams ("Large Normal B Fade Params", Vector) = (0,10000,0.5,1)
		_LargeNormalAFadeParams ("Large Normal A Fade Params", Vector) = (0,10000,0.5,1)
		_LargeRSubzoneFilter ("Large R Subzone Filter", Vector) = (1,1,1,1)
		_LargeGSubzoneFilter ("Large G Subzone Filter", Vector) = (1,1,1,1)
		_LargeBSubzoneFilter ("Large B Subzone Filter", Vector) = (1,1,1,1)
		_LargeASubzoneFilter ("Large A Subzone Filter", Vector) = (1,1,1,1)

		// ===== Mid per-biome layer: ridge / outcrop scale (PARAMS §3.4.2) =====
		// Same shape as Large but tiled finer for mid-frequency variation.
		_MidCurvatureR ("Mid Curvature R", 2D) = "black" {}
		_MidCurvatureG ("Mid Curvature G", 2D) = "black" {}
		_MidCurvatureB ("Mid Curvature B", 2D) = "black" {}
		_MidCurvatureA ("Mid Curvature A", 2D) = "black" {}
		_MidGradienceR ("Mid Gradience R", 2D) = "black" {}
		_MidGradienceG ("Mid Gradience G", 2D) = "black" {}
		_MidGradienceB ("Mid Gradience B", 2D) = "black" {}
		_MidGradienceA ("Mid Gradience A", 2D) = "black" {}
		_MidNormalR ("Mid Normal R", 2D) = "bump" {}
		_MidNormalG ("Mid Normal G", 2D) = "bump" {}
		_MidNormalB ("Mid Normal B", 2D) = "bump" {}
		_MidNormalA ("Mid Normal A", 2D) = "bump" {}
		_MidNormalRUVParams ("Mid Normal R UV Params", Vector) = (1,1,0,0)
		_MidNormalGUVParams ("Mid Normal G UV Params", Vector) = (1,1,0,0)
		_MidNormalBUVParams ("Mid Normal B UV Params", Vector) = (1,1,0,0)
		_MidNormalAUVParams ("Mid Normal A UV Params", Vector) = (1,1,0,0)
		_MidNormalRFadeParams ("Mid Normal R Fade Params", Vector) = (0,10000,0.5,1)
		_MidNormalGFadeParams ("Mid Normal G Fade Params", Vector) = (0,10000,0.5,1)
		_MidNormalBFadeParams ("Mid Normal B Fade Params", Vector) = (0,10000,0.5,1)
		_MidNormalAFadeParams ("Mid Normal A Fade Params", Vector) = (0,10000,0.5,1)
		_MidRSubzoneFilter ("Mid R Subzone Filter", Vector) = (1,1,1,1)
		_MidGSubzoneFilter ("Mid G Subzone Filter", Vector) = (1,1,1,1)
		_MidBSubzoneFilter ("Mid B Subzone Filter", Vector) = (1,1,1,1)
		_MidASubzoneFilter ("Mid A Subzone Filter", Vector) = (1,1,1,1)

		// ===== Subzone 3: tier-2 per-biome mid layer (PARAMS §3.5) =====
		// Active only when SUB_ZONES_ENABLED. Stack with Subzone 4 for layered
		// effects (lichen patches, cracked soil, drift snow patterns).
		_Subzone3CurvatureR ("Subzone 3 Curvature R", 2D) = "black" {}
		_Subzone3CurvatureG ("Subzone 3 Curvature G", 2D) = "black" {}
		_Subzone3CurvatureB ("Subzone 3 Curvature B", 2D) = "black" {}
		_Subzone3CurvatureA ("Subzone 3 Curvature A", 2D) = "black" {}
		_Subzone3GradienceR ("Subzone 3 Gradience R", 2D) = "black" {}
		_Subzone3GradienceG ("Subzone 3 Gradience G", 2D) = "black" {}
		_Subzone3GradienceB ("Subzone 3 Gradience B", 2D) = "black" {}
		_Subzone3GradienceA ("Subzone 3 Gradience A", 2D) = "black" {}
		_Subzone3NormalR ("Subzone 3 Normal R", 2D) = "bump" {}
		_Subzone3NormalG ("Subzone 3 Normal G", 2D) = "bump" {}
		_Subzone3NormalB ("Subzone 3 Normal B", 2D) = "bump" {}
		_Subzone3NormalA ("Subzone 3 Normal A", 2D) = "bump" {}
		_Subzone3NormalRUVParams ("Subzone 3 Normal R UV Params", Vector) = (1,1,0,0)
		_Subzone3NormalGUVParams ("Subzone 3 Normal G UV Params", Vector) = (1,1,0,0)
		_Subzone3NormalBUVParams ("Subzone 3 Normal B UV Params", Vector) = (1,1,0,0)
		_Subzone3NormalAUVParams ("Subzone 3 Normal A UV Params", Vector) = (1,1,0,0)
		_Subzone3NormalRFadeParams ("Subzone 3 Normal R Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone3NormalGFadeParams ("Subzone 3 Normal G Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone3NormalBFadeParams ("Subzone 3 Normal B Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone3NormalAFadeParams ("Subzone 3 Normal A Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone3RSubzoneFilter ("Global3 R Subzone Filter", Vector) = (1,1,1,1)
		_Subzone3GSubzoneFilter ("Global3 G Subzone Filter", Vector) = (1,1,1,1)
		_Subzone3BSubzoneFilter ("Global3 B Subzone Filter", Vector) = (1,1,1,1)
		_Subzone3ASubzoneFilter ("Global3 A Subzone Filter", Vector) = (1,1,1,1)

		// ===== Subzone 4: tier-2 per-biome mid layer (PARAMS §3.5) =====
		// Independent second tier; combines with Subzone 3.
		_Subzone4CurvatureR ("Subzone 4 Curvature R", 2D) = "black" {}
		_Subzone4CurvatureG ("Subzone 4 Curvature G", 2D) = "black" {}
		_Subzone4CurvatureB ("Subzone 4 Curvature B", 2D) = "black" {}
		_Subzone4CurvatureA ("Subzone 4 Curvature A", 2D) = "black" {}
		_Subzone4GradienceR ("Subzone 4 Gradience R", 2D) = "black" {}
		_Subzone4GradienceG ("Subzone 4 Gradience G", 2D) = "black" {}
		_Subzone4GradienceB ("Subzone 4 Gradience B", 2D) = "black" {}
		_Subzone4GradienceA ("Subzone 4 Gradience A", 2D) = "black" {}
		_Subzone4NormalR ("Subzone 4 Normal R", 2D) = "bump" {}
		_Subzone4NormalG ("Subzone 4 Normal G", 2D) = "bump" {}
		_Subzone4NormalB ("Subzone 4 Normal B", 2D) = "bump" {}
		_Subzone4NormalA ("Subzone 4 Normal A", 2D) = "bump" {}
		_Subzone4NormalRUVParams ("Subzone 4 Normal R UV Params", Vector) = (1,1,0,0)
		_Subzone4NormalGUVParams ("Subzone 4 Normal G UV Params", Vector) = (1,1,0,0)
		_Subzone4NormalBUVParams ("Subzone 4 Normal B UV Params", Vector) = (1,1,0,0)
		_Subzone4NormalAUVParams ("Subzone 4 Normal A UV Params", Vector) = (1,1,0,0)
		_Subzone4NormalRFadeParams ("Subzone 4 Normal R Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone4NormalGFadeParams ("Subzone 4 Normal G Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone4NormalBFadeParams ("Subzone 4 Normal B Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone4NormalAFadeParams ("Subzone 4 Normal A Fade Params", Vector) = (0,10000,0.5,1)
		_Subzone4RSubzoneFilter ("Global4 R Subzone Filter", Vector) = (1,1,1,1)
		_Subzone4GSubzoneFilter ("Global4 G Subzone Filter", Vector) = (1,1,1,1)
		_Subzone4BSubzoneFilter ("Global4 B Subzone Filter", Vector) = (1,1,1,1)
		_Subzone4ASubzoneFilter ("Global4 A Subzone Filter", Vector) = (1,1,1,1)

		// ===== Sphere radius (PARAMS §3.3) =====
		// Used by the decal apply loop to cull far-away decals. Auto-set by PQSRenderer.
		_Radius ("Sphere Radius", Float) = 0

		// ===== Small detail tile arrays (PARAMS §3.6.1) =====
		// Shared pool of up-close detail materials. All biome layers index into
		// these by slice. Normal array uses DXT5nm-style packing.
		_SmallAlbedoArray ("Small Albedo Array", 2DArray) = "white" {}
		_SmallNormalArray ("Small Normal Array", 2DArray) = "bump" {}
		_SmallMetalArray ("Small Metal Array", 2DArray) = "white" {}

		// ===== Decals (PARAMS §3.8, DECALS_ENABLED) =====
		// Texture content for projected stickers. Placements come from
		// PqsDecalInstance at runtime, not from this material.
		_DecalAlbedo ("Decal Albedo", 2DArray) = "white" {}
		_DecalNormalSAO ("Decal Normal SAO", 2DArray) = "bump" {}
		_DecalAlphaMask ("Decal Alpha Mask", 2DArray) = "white" {}
		_DecalControl ("Decal Control", 2D) = "black" {}
		_DecalStaticData ("Decal Static Data", 2D) = "black" {}
		_DecalFadeParams ("Decal Fade Params", Vector) = (0,20000,1,0)

		// ===== Small biome: slice indices + master weight (PARAMS §3.6.1) =====
		// Per-biome 4-vector of (layer1..4) slice indices into _Small*Array
		// (-1 = unused), per-layer global intensity, and height-blend softness.
		_SmallBiomeR ("Small Biome R", Vector) = (-1,-1,-1,-1)
		_SmallBiomeG ("Small Biome G", Vector) = (-1,-1,-1,-1)
		_SmallBiomeB ("Small Biome B", Vector) = (-1,-1,-1,-1)
		_SmallBiomeA ("Small Biome A", Vector) = (-1,-1,-1,-1)
		_SmallHeightWeightR ("Small Height Weight R", Vector) = (0,0,0,0)
		_SmallHeightWeightG ("Small Height Weight G", Vector) = (0,0,0,0)
		_SmallHeightWeightB ("Small Height Weight B", Vector) = (0,0,0,0)
		_SmallHeightWeightA ("Small Height Weight A", Vector) = (0,0,0,0)
		_SmallWeightSoftnessR ("Small Height Weight Softness R", Vector) = (0,0,0,0)
		_SmallWeightSoftnessG ("Small Height Weight Softness G", Vector) = (0,0,0,0)
		_SmallWeightSoftnessB ("Small Height Weight Softness B", Vector) = (0,0,0,0)
		_SmallWeightSoftnessA ("Small Height Weight Softness A", Vector) = (0,0,0,0)

		// ===== Small biome: per-layer altitude window (PARAMS §3.6.2) =====
		// Trapezoidal (center, upRange, downRange, fadeOut) altitude window per
		// layer, in meters of terrain height. Use to keep snow above the snow
		// line, sand below the dunes, etc.
		_SmallBiomeHeightEnableR ("Small Biome R Height Enable", Vector) = (0,0,0,0)
		_SmallBiomeRHeightParams1 ("Small Biome R Height Params 1", Vector) = (0,0,0,0)
		_SmallBiomeRHeightParams2 ("Small Biome R Height Params 2", Vector) = (0,0,0,0)
		_SmallBiomeRHeightParams3 ("Small Biome R Height Params 3", Vector) = (0,0,0,0)
		_SmallBiomeRHeightParams4 ("Small Biome R Height Params 4", Vector) = (0,0,0,0)
		_SmallBiomeHeightEnableG ("Small Biome G Height Enable", Vector) = (0,0,0,0)
		_SmallBiomeGHeightParams1 ("Small Biome G Height Params 1", Vector) = (0,0,0,0)
		_SmallBiomeGHeightParams2 ("Small Biome G Height Params 2", Vector) = (0,0,0,0)
		_SmallBiomeGHeightParams3 ("Small Biome G Height Params 3", Vector) = (0,0,0,0)
		_SmallBiomeGHeightParams4 ("Small Biome G Height Params 4", Vector) = (0,0,0,0)
		_SmallBiomeHeightEnableB ("Small Biome B Height Enable", Vector) = (0,0,0,0)
		_SmallBiomeBHeightParams1 ("Small Biome B Height Params 1", Vector) = (0,0,0,0)
		_SmallBiomeBHeightParams2 ("Small Biome B Height Params 2", Vector) = (0,0,0,0)
		_SmallBiomeBHeightParams3 ("Small Biome B Height Params 3", Vector) = (0,0,0,0)
		_SmallBiomeBHeightParams4 ("Small Biome B Height Params 4", Vector) = (0,0,0,0)
		_SmallBiomeHeightEnableA ("Small Biome A Height Enable", Vector) = (0,0,0,0)
		_SmallBiomeAHeightParams1 ("Small Biome A Height Params 1", Vector) = (0,0,0,0)
		_SmallBiomeAHeightParams2 ("Small Biome A Height Params 2", Vector) = (0,0,0,0)
		_SmallBiomeAHeightParams3 ("Small Biome A Height Params 3", Vector) = (0,0,0,0)
		_SmallBiomeAHeightParams4 ("Small Biome A Height Params 4", Vector) = (0,0,0,0)

		// ===== Small biome: per-layer slope window + grad-map mix (PARAMS §3.6.2) =====
		// Slope window in degrees: (center, upRange, downRange, fadeOut). Place
		// grass on flats (center ~0), rock on cliffs (center ~90). GradMapWeights
		// = (aux/biome, large, mid, unused) mixes _LargeGradience* / _MidGradience*
		// into the effective slope so layers respond to height-map bumps too.
		_SmallBiomeSlopeEnableR ("Small Biome R Slope Enable", Vector) = (0,0,0,0)
		_SmallBiomeRSlopeParams1 ("Small Biome R Slope Params 1", Vector) = (0,0,0,0)
		_SmallBiomeRSlopeParams2 ("Small Biome R Slope Params 2", Vector) = (0,0,0,0)
		_SmallBiomeRSlopeParams3 ("Small Biome R Slope Params 3", Vector) = (0,0,0,0)
		_SmallBiomeRSlopeParams4 ("Small Biome R Slope Params 4", Vector) = (0,0,0,0)
		_SmallBiomeRGradMapWeights1 ("Small Biome R Gradient Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeRGradMapWeights2 ("Small Biome R Gradient Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeRGradMapWeights3 ("Small Biome R Gradient Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeRGradMapWeights4 ("Small Biome R Gradient Map Weights 4", Vector) = (1,1,1,1)
		_SmallBiomeSlopeEnableG ("Small Biome G Slope Enable", Vector) = (0,0,0,0)
		_SmallBiomeGSlopeParams1 ("Small Biome G Slope Params 1", Vector) = (0,0,0,0)
		_SmallBiomeGSlopeParams2 ("Small Biome G Slope Params 2", Vector) = (0,0,0,0)
		_SmallBiomeGSlopeParams3 ("Small Biome G Slope Params 3", Vector) = (0,0,0,0)
		_SmallBiomeGSlopeParams4 ("Small Biome G Slope Params 4", Vector) = (0,0,0,0)
		_SmallBiomeGGradMapWeights1 ("Small Biome G Gradient Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeGGradMapWeights2 ("Small Biome G Gradient Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeGGradMapWeights3 ("Small Biome G Gradient Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeGGradMapWeights4 ("Small Biome G Gradient Map Weights 4", Vector) = (1,1,1,1)
		_SmallBiomeSlopeEnableB ("Small Biome B Slope Enable", Vector) = (0,0,0,0)
		_SmallBiomeBSlopeParams1 ("Small Biome B Slope Params 1", Vector) = (0,0,0,0)
		_SmallBiomeBSlopeParams2 ("Small Biome B Slope Params 2", Vector) = (0,0,0,0)
		_SmallBiomeBSlopeParams3 ("Small Biome B Slope Params 3", Vector) = (0,0,0,0)
		_SmallBiomeBSlopeParams4 ("Small Biome B Slope Params 4", Vector) = (0,0,0,0)
		_SmallBiomeBGradMapWeights1 ("Small Biome B Gradient Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeBGradMapWeights2 ("Small Biome B Gradient Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeBGradMapWeights3 ("Small Biome B Gradient Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeBGradMapWeights4 ("Small Biome B Gradient Map Weights 4", Vector) = (1,1,1,1)
		_SmallBiomeSlopeEnableA ("Small Biome A Slope Enable", Vector) = (0,0,0,0)
		_SmallBiomeASlopeParams1 ("Small Biome A Slope Params 1", Vector) = (0,0,0,0)
		_SmallBiomeASlopeParams2 ("Small Biome A Slope Params 2", Vector) = (0,0,0,0)
		_SmallBiomeASlopeParams3 ("Small Biome A Slope Params 3", Vector) = (0,0,0,0)
		_SmallBiomeASlopeParams4 ("Small Biome A Slope Params 4", Vector) = (0,0,0,0)
		_SmallBiomeAGradMapWeights1 ("Small Biome A Gradient Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeAGradMapWeights2 ("Small Biome A Gradient Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeAGradMapWeights3 ("Small Biome A Gradient Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeAGradMapWeights4 ("Small Biome A Gradient Map Weights 4", Vector) = (1,1,1,1)

		// ===== Small biome: per-layer peak/cavity window (PARAMS §3.6.2, reserved) =====
		// Curvature-driven gating. Declared but not yet consumed by V3.
		_SmallBiomePeakCavEnableR ("Small Biome R Peak/Cavity Enable", Vector) = (0,0,0,0)
		_SmallBiomeRPeakCavParams1 ("Small Biome R Peak/Cavity Params 1", Vector) = (0,0,0,0)
		_SmallBiomeRPeakCavParams2 ("Small Biome R Peak/Cavity Params 2", Vector) = (0,0,0,0)
		_SmallBiomeRPeakCavParams3 ("Small Biome R Peak/Cavity Params 3", Vector) = (0,0,0,0)
		_SmallBiomeRPeakCavParams4 ("Small Biome R Peak/Cavity Params 4", Vector) = (0,0,0,0)
		_SmallBiomeRCurvMapWeights1 ("Small Biome R Curvature Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeRCurvMapWeights2 ("Small Biome R Curvature Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeRCurvMapWeights3 ("Small Biome R Curvature Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeRCurvMapWeights4 ("Small Biome R Curvature Map Weights 4", Vector) = (1,1,1,1)
		_SmallBiomePeakCavEnableG ("Small Biome G Peak/Cavity Enable", Vector) = (0,0,0,0)
		_SmallBiomeGPeakCavParams1 ("Small Biome G Peak/Cavity Params 1", Vector) = (0,0,0,0)
		_SmallBiomeGPeakCavParams2 ("Small Biome G Peak/Cavity Params 2", Vector) = (0,0,0,0)
		_SmallBiomeGPeakCavParams3 ("Small Biome G Peak/Cavity Params 3", Vector) = (0,0,0,0)
		_SmallBiomeGPeakCavParams4 ("Small Biome G Peak/Cavity Params 4", Vector) = (0,0,0,0)
		_SmallBiomeGCurvMapWeights1 ("Small Biome G Curvature Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeGCurvMapWeights2 ("Small Biome G Curvature Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeGCurvMapWeights3 ("Small Biome G Curvature Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeGCurvMapWeights4 ("Small Biome G Curvature Map Weights 4", Vector) = (1,1,1,1)
		_SmallBiomePeakCavEnableB ("Small Biome B Peak/Cavity Enable", Vector) = (0,0,0,0)
		_SmallBiomeBPeakCavParams1 ("Small Biome B Peak/Cavity Params 1", Vector) = (0,0,0,0)
		_SmallBiomeBPeakCavParams2 ("Small Biome B Peak/Cavity Params 2", Vector) = (0,0,0,0)
		_SmallBiomeBPeakCavParams3 ("Small Biome B Peak/Cavity Params 3", Vector) = (0,0,0,0)
		_SmallBiomeBPeakCavParams4 ("Small Biome B Peak/Cavity Params 4", Vector) = (0,0,0,0)
		_SmallBiomeBCurvMapWeights1 ("Small Biome B Curvature Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeBCurvMapWeights2 ("Small Biome B Curvature Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeBCurvMapWeights3 ("Small Biome B Curvature Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeBCurvMapWeights4 ("Small Biome B Curvature Map Weights 4", Vector) = (1,1,1,1)
		_SmallBiomePeakCavEnableA ("Small Biome A Peak/Cavity Enable", Vector) = (0,0,0,0)
		_SmallBiomeAPeakCavParams1 ("Small Biome A Peak/Cavity Params 1", Vector) = (0,0,0,0)
		_SmallBiomeAPeakCavParams2 ("Small Biome A Peak/Cavity Params 2", Vector) = (0,0,0,0)
		_SmallBiomeAPeakCavParams3 ("Small Biome A Peak/Cavity Params 3", Vector) = (0,0,0,0)
		_SmallBiomeAPeakCavParams4 ("Small Biome A Peak/Cavity Params 4", Vector) = (0,0,0,0)
		_SmallBiomeACurvMapWeights1 ("Small Biome A Curvature Map Weights 1", Vector) = (1,1,1,1)
		_SmallBiomeACurvMapWeights2 ("Small Biome A Curvature Map Weights 2", Vector) = (1,1,1,1)
		_SmallBiomeACurvMapWeights3 ("Small Biome A Curvature Map Weights 3", Vector) = (1,1,1,1)
		_SmallBiomeACurvMapWeights4 ("Small Biome A Curvature Map Weights 4", Vector) = (1,1,1,1)

		// ===== Small biome: per-layer UVs (PARAMS §3.6.3) =====
		// Bigger scale = smaller print on the surface; offset breaks alignment
		// between layers that share the same tile.
		_SmallUVScaleR ("Small UV Scale R", Vector) = (1,1,1,1)
		_SmallUVScaleG ("Small UV Scale G", Vector) = (1,1,1,1)
		_SmallUVScaleB ("Small UV Scale B", Vector) = (1,1,1,1)
		_SmallUVScaleA ("Small UV Scale A", Vector) = (1,1,1,1)
		_SmallUVOffsetR ("Small UV Offset R", Vector) = (1,1,1,1)
		_SmallUVOffsetG ("Small UV Offset G", Vector) = (1,1,1,1)
		_SmallUVOffsetB ("Small UV Offset B", Vector) = (1,1,1,1)
		_SmallUVOffsetA ("Small UV Offset A", Vector) = (1,1,1,1)

		// ===== Small biome: per-layer color grading (PARAMS §3.6.4) =====
		// Tint (RGB multiplies albedo, A multiplies layer height-blend coverage),
		// brightness (additive), contrast (around mid-gray ~0.218), saturation.
		_SmallTintR1 ("Small Tint R 1", Color) = (1,1,1,1)
		_SmallTintR2 ("Small Tint R 2", Color) = (1,1,1,1)
		_SmallTintR3 ("Small Tint R 3", Color) = (1,1,1,1)
		_SmallTintR4 ("Small Tint R 4", Color) = (1,1,1,1)
		_SmallTintG1 ("Small Tint G 1", Color) = (1,1,1,1)
		_SmallTintG2 ("Small Tint G 2", Color) = (1,1,1,1)
		_SmallTintG3 ("Small Tint G 3", Color) = (1,1,1,1)
		_SmallTintG4 ("Small Tint G 4", Color) = (1,1,1,1)
		_SmallTintB1 ("Small Tint B 1", Color) = (1,1,1,1)
		_SmallTintB2 ("Small Tint B 2", Color) = (1,1,1,1)
		_SmallTintB3 ("Small Tint B 3", Color) = (1,1,1,1)
		_SmallTintB4 ("Small Tint B 4", Color) = (1,1,1,1)
		_SmallTintA1 ("Small Tint A 1", Color) = (1,1,1,1)
		_SmallTintA2 ("Small Tint A 2", Color) = (1,1,1,1)
		_SmallTintA3 ("Small Tint A 3", Color) = (1,1,1,1)
		_SmallTintA4 ("Small Tint A 4", Color) = (1,1,1,1)
		_SmallBrightnessR ("Small Brightness R", Vector) = (0,0,0,0)
		_SmallBrightnessG ("Small Brightness G", Vector) = (0,0,0,0)
		_SmallBrightnessB ("Small Brightness B", Vector) = (0,0,0,0)
		_SmallBrightnessA ("Small Brightness A", Vector) = (0,0,0,0)
		_SmallContrastR ("Small Contrast R", Vector) = (1,1,1,1)
		_SmallContrastG ("Small Contrast G", Vector) = (1,1,1,1)
		_SmallContrastB ("Small Contrast B", Vector) = (1,1,1,1)
		_SmallContrastA ("Small Contrast A", Vector) = (1,1,1,1)
		_SmallSaturationR ("Small Saturation R", Vector) = (1,1,1,1)
		_SmallSaturationG ("Small Saturation G", Vector) = (1,1,1,1)
		_SmallSaturationB ("Small Saturation B", Vector) = (1,1,1,1)
		_SmallSaturationA ("Small Saturation A", Vector) = (1,1,1,1)

		// ===== Small biome: per-layer PBR (PARAMS §3.6.5) =====
		// Per-layer normal/gloss/metallic strength multipliers. Set Gloss or
		// Metallic >= 15 to switch from multiply to override mode (the layer
		// forces a fixed value instead of multiplying the source map).
		_SmallNormalStrengthR ("Small Normal Strength R", Vector) = (1,1,1,1)
		_SmallNormalStrengthG ("Small Normal Strength G", Vector) = (1,1,1,1)
		_SmallNormalStrengthB ("Small Normal Strength B", Vector) = (1,1,1,1)
		_SmallNormalStrengthA ("Small Normal Strength A", Vector) = (1,1,1,1)
		_SmallGlossStrengthR ("Small Gloss Strength R", Vector) = (1,1,1,1)
		_SmallGlossStrengthG ("Small Gloss Strength G", Vector) = (1,1,1,1)
		_SmallGlossStrengthB ("Small Gloss Strength B", Vector) = (1,1,1,1)
		_SmallGlossStrengthA ("Small Gloss Strength A", Vector) = (1,1,1,1)
		_SmallMetallicStrengthR ("Small Metallic Strength R", Vector) = (0,0,0,0)
		_SmallMetallicStrengthG ("Small Metallic Strength G", Vector) = (0,0,0,0)
		_SmallMetallicStrengthB ("Small Metallic Strength B", Vector) = (0,0,0,0)
		_SmallMetallicStrengthA ("Small Metallic Strength A", Vector) = (0,0,0,0)

		// ===== Small biome: per-layer emission (PARAMS §3.6.6) =====
		// Per-layer self-illumination strength + 4 HDR colors per biome.
		// Use for crystal veins, lava cracks, glowing fungi, bioluminescence.
		_SmallEmissionStrengthR ("Small Emission Strength R", Vector) = (0,0,0,0)
		_SmallEmissionStrengthG ("Small Emission Strength G", Vector) = (0,0,0,0)
		_SmallEmissionStrengthB ("Small Emission Strength B", Vector) = (0,0,0,0)
		_SmallEmissionStrengthA ("Small Emission Strength A", Vector) = (0,0,0,0)
		_SmallEmissionColorR1 ("Small Emission Color R 1", Color) = (1,1,1,1)
		_SmallEmissionColorR2 ("Small Emission Color R 2", Color) = (1,1,1,1)
		_SmallEmissionColorR3 ("Small Emission Color R 3", Color) = (1,1,1,1)
		_SmallEmissionColorR4 ("Small Emission Color R 4", Color) = (1,1,1,1)
		_SmallEmissionColorG1 ("Small Emission Color G 1", Color) = (1,1,1,1)
		_SmallEmissionColorG2 ("Small Emission Color G 2", Color) = (1,1,1,1)
		_SmallEmissionColorG3 ("Small Emission Color G 3", Color) = (1,1,1,1)
		_SmallEmissionColorG4 ("Small Emission Color G 4", Color) = (1,1,1,1)
		_SmallEmissionColorB1 ("Small Emission Color B 1", Color) = (1,1,1,1)
		_SmallEmissionColorB2 ("Small Emission Color B 2", Color) = (1,1,1,1)
		_SmallEmissionColorB3 ("Small Emission Color B 3", Color) = (1,1,1,1)
		_SmallEmissionColorB4 ("Small Emission Color B 4", Color) = (1,1,1,1)
		_SmallEmissionColorA1 ("Small Emission Color A 1", Color) = (1,1,1,1)
		_SmallEmissionColorA2 ("Small Emission Color A 2", Color) = (1,1,1,1)
		_SmallEmissionColorA3 ("Small Emission Color A 3", Color) = (1,1,1,1)
		_SmallEmissionColorA4 ("Small Emission Color A 4", Color) = (1,1,1,1)

		// ===== Small biome: per-layer AO (PARAMS §3.6.5) =====
		// Per-layer ambient-occlusion power.
		_SmallAOStrengthR ("Small AO Strength R", Vector) = (1,1,1,1)
		_SmallAOStrengthG ("Small AO Strength G", Vector) = (1,1,1,1)
		_SmallAOStrengthB ("Small AO Strength B", Vector) = (1,1,1,1)
		_SmallAOStrengthA ("Small AO Strength A", Vector) = (1,1,1,1)

		// ===== Small biome: per-layer distance-resample tier + enable (PARAMS §3.6.1 / §3.9) =====
		// ResampleMax 0..4 = how aggressively this layer re-tiles at far range.
		// Enable 0/1 = mute a slot without resetting its slice index.
		_SmallDistanceResampleMaxR ("Small R Distance Resample Max", Vector) = (4,4,4,4)
		_SmallDistanceResampleMaxG ("Small G Distance Resample Max", Vector) = (4,4,4,4)
		_SmallDistanceResampleMaxB ("Small B Distance Resample Max", Vector) = (4,4,4,4)
		_SmallDistanceResampleMaxA ("Small A Distance Resample Max", Vector) = (4,4,4,4)
		_SmallEnableR ("Small Enable R", Vector) = (0,0,0,0)
		_SmallEnableG ("Small Enable G", Vector) = (0,0,0,0)
		_SmallEnableB ("Small Enable B", Vector) = (0,0,0,0)
		_SmallEnableA ("Small Enable A", Vector) = (0,0,0,0)

		// ===== Subzone overrides: per-layer weight (PARAMS §3.7, SUB_ZONES_ENABLED) =====
		// (sz0,sz1,sz2,sz3) replaces _SmallHeightWeight<C>.<i> in SZ mode.
		_SmallSubzoneWeightR1 ("Small Subzone Weight R1", Vector) = (1,1,1,1)
		_SmallSubzoneWeightR2 ("Small Subzone Weight R2", Vector) = (1,1,1,1)
		_SmallSubzoneWeightR3 ("Small Subzone Weight R3", Vector) = (1,1,1,1)
		_SmallSubzoneWeightR4 ("Small Subzone Weight R4", Vector) = (1,1,1,1)
		_SmallSubzoneWeightG1 ("Small Subzone Weight G1", Vector) = (1,1,1,1)
		_SmallSubzoneWeightG2 ("Small Subzone Weight G2", Vector) = (1,1,1,1)
		_SmallSubzoneWeightG3 ("Small Subzone Weight G3", Vector) = (1,1,1,1)
		_SmallSubzoneWeightG4 ("Small Subzone Weight G4", Vector) = (1,1,1,1)
		_SmallSubzoneWeightB1 ("Small Subzone Weight B1", Vector) = (1,1,1,1)
		_SmallSubzoneWeightB2 ("Small Subzone Weight B2", Vector) = (1,1,1,1)
		_SmallSubzoneWeightB3 ("Small Subzone Weight B3", Vector) = (1,1,1,1)
		_SmallSubzoneWeightB4 ("Small Subzone Weight B4", Vector) = (1,1,1,1)
		_SmallSubzoneWeightA1 ("Small Subzone Weight A1", Vector) = (1,1,1,1)
		_SmallSubzoneWeightA2 ("Small Subzone Weight A2", Vector) = (1,1,1,1)
		_SmallSubzoneWeightA3 ("Small Subzone Weight A3", Vector) = (1,1,1,1)
		_SmallSubzoneWeightA4 ("Small Subzone Weight A4", Vector) = (1,1,1,1)

		// ===== Subzone overrides: per-layer additive brightness (PARAMS §3.7) =====
		// (sz0,sz1,sz2,sz3) additive brightness for layer <i> of biome <C>.
		_SmallSubzoneBrightnessR1 ("Small Subzone Brightness R1", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessR2 ("Small Subzone Brightness R2", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessR3 ("Small Subzone Brightness R3", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessR4 ("Small Subzone Brightness R4", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessG1 ("Small Subzone Brightness G1", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessG2 ("Small Subzone Brightness G2", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessG3 ("Small Subzone Brightness G3", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessG4 ("Small Subzone Brightness G4", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessB1 ("Small Subzone Brightness B1", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessB2 ("Small Subzone Brightness B2", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessB3 ("Small Subzone Brightness B3", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessB4 ("Small Subzone Brightness B4", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessA1 ("Small Subzone Brightness A1", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessA2 ("Small Subzone Brightness A2", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessA3 ("Small Subzone Brightness A3", Vector) = (0,0,0,0)
		_SmallSubzoneBrightnessA4 ("Small Subzone Brightness A4", Vector) = (0,0,0,0)

		// ===== Subzone overrides: per-layer tint (PARAMS §3.7) =====
		// _SmallSubzoneTint<C><i>_<S>: <C>=biome channel, <i>=layer 1..4,
		// <S>=subzone channel. The four <S> variants are blended by
		// _SubzoneMaskTex per pixel. .w of the _R and _G variants doubles as
		// the Subzone3 / Subzone4 height-mix scalar for that layer.
		_SmallSubzoneTintR1_R ("Small Subzone Tint R1 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintR1_G ("Small Subzone Tint R1 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintR1_B ("Small Subzone Tint R1 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintR1_A ("Small Subzone Tint R1 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintR2_R ("Small Subzone Tint R2 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintR2_G ("Small Subzone Tint R2 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintR2_B ("Small Subzone Tint R2 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintR2_A ("Small Subzone Tint R2 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintR3_R ("Small Subzone Tint R3 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintR3_G ("Small Subzone Tint R3 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintR3_B ("Small Subzone Tint R3 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintR3_A ("Small Subzone Tint R3 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintR4_R ("Small Subzone Tint R4 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintR4_G ("Small Subzone Tint R4 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintR4_B ("Small Subzone Tint R4 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintR4_A ("Small Subzone Tint R4 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintG1_R ("Small Subzone Tint G1 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintG1_G ("Small Subzone Tint G1 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintG1_B ("Small Subzone Tint G1 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintG1_A ("Small Subzone Tint G1 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintG2_R ("Small Subzone Tint G2 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintG2_G ("Small Subzone Tint G2 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintG2_B ("Small Subzone Tint G2 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintG2_A ("Small Subzone Tint G2 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintG3_R ("Small Subzone Tint G3 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintG3_G ("Small Subzone Tint G3 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintG3_B ("Small Subzone Tint G3 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintG3_A ("Small Subzone Tint G3 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintG4_R ("Small Subzone Tint G4 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintG4_G ("Small Subzone Tint G4 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintG4_B ("Small Subzone Tint G4 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintG4_A ("Small Subzone Tint G4 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintB1_R ("Small Subzone Tint B1 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintB1_G ("Small Subzone Tint B1 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintB1_B ("Small Subzone Tint B1 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintB1_A ("Small Subzone Tint B1 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintB2_R ("Small Subzone Tint B2 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintB2_G ("Small Subzone Tint B2 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintB2_B ("Small Subzone Tint B2 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintB2_A ("Small Subzone Tint B2 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintB3_R ("Small Subzone Tint B3 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintB3_G ("Small Subzone Tint B3 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintB3_B ("Small Subzone Tint B3 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintB3_A ("Small Subzone Tint B3 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintB4_R ("Small Subzone Tint B4 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintB4_G ("Small Subzone Tint B4 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintB4_B ("Small Subzone Tint B4 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintB4_A ("Small Subzone Tint B4 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintA1_R ("Small Subzone Tint A1 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintA1_G ("Small Subzone Tint A1 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintA1_B ("Small Subzone Tint A1 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintA1_A ("Small Subzone Tint A1 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintA2_R ("Small Subzone Tint A2 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintA2_G ("Small Subzone Tint A2 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintA2_B ("Small Subzone Tint A2 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintA2_A ("Small Subzone Tint A2 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintA3_R ("Small Subzone Tint A1 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintA3_G ("Small Subzone Tint A1 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintA3_B ("Small Subzone Tint A1 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintA3_A ("Small Subzone Tint A1 - A", Color) = (1,1,1,1)
		_SmallSubzoneTintA4_R ("Small Subzone Tint A1 - R", Color) = (1,1,1,1)
		_SmallSubzoneTintA4_G ("Small Subzone Tint A1 - G", Color) = (1,1,1,1)
		_SmallSubzoneTintA4_B ("Small Subzone Tint A1 - B", Color) = (1,1,1,1)
		_SmallSubzoneTintA4_A ("Small Subzone Tint A1 - A", Color) = (1,1,1,1)

		// ===== Cross-biome blend & distance cascade (PARAMS §3.9 / §3.10) =====
		// _HeightblendFactor / _GlobalBlend control how the four biomes composite.
		// _DistanceResample* drives the at-distance retiling cascade for the
		// small detail stack. _AlphaToHeightFadeParams fades the alpha-vs-
		// heightmap blend mode by range. HideInInspector entries are runtime-
		// driven from _DistanceResampleDistances; don't edit by hand.
		_HeightblendFactor ("Height Blend Factor", Vector) = (0.02,0.02,0.02,0.02)
		_DistanceResampleDistances ("Distance Resample Distances", Vector) = (0,0,0,0)
		_DistanceResampleUVScales ("Distance Resample UV Scales", Vector) = (1,1,1,1)
		_DistanceResampleAlbedoOpacity ("Distance Resample Albedo Opacity", Vector) = (1,1,1,1)
		_DistanceResampleNormalOpacity ("Distance Resample Normal Opacity", Vector) = (1,1,1,1)
		_GlobalBlend ("Global Blend", Vector) = (1,1,1,1)
		_AlphaToHeightFadeParams ("Alpha to Height Fade", Vector) = (1,1,1,1)
		[HideInInspector] _DistanceResampleFades ("Distance Resample Fades", Vector) = (1,1,1,1)
		[HideInInspector] _DistanceResampleFadeRangesPos ("Distance Resample Fade Ranges Pos", Vector) = (1,1,1,1)
		[HideInInspector] _DistanceResampleFadeRangesNeg ("Distance Resample Fade Ranges Ned", Vector) = (1,1,1,1)

		// ===== Anti-tile / shoreline (PARAMS §3.3 / §3.11) =====
		// _StochasticScale: hex-grid period for ANTI_TILE_QUALITY_ON.
		// _ShorelineTex: reserved (sea-level tinting; not yet consumed by V3).
		_StochasticScale ("Scale", Range(0.25, 2)) = 1
		_ShorelineTex ("Shoreline", 2D) = "white" {}

		// ===== Internal: prepass bindings + quality toggle (PARAMS §3.11) =====
		// _LocalSpacePrepassTex0..4: written by passes 13/14/15, consumed by
		// passes 1..11. _HighQualityEnabled: reserved quality-tier toggle.
		[HideInInspector] _LocalSpacePrepassTex0 ("Local Space Prepass Texture 0", 2D) = "white" {}
		[HideInInspector] _LocalSpacePrepassTex1 ("Local Space Prepass Texture 1", 2D) = "white" {}
		[HideInInspector] _LocalSpacePrepassTex2 ("Local Space Prepass Texture 2", 2D) = "white" {}
		[HideInInspector] _LocalSpacePrepassTex3 ("Local Space Prepass Texture 3", 2D) = "white" {}
		[HideInInspector] _LocalSpacePrepassTex4 ("Local Space Prepass Texture 4", 2D) = "white" {}
		[ToggleOff(LOW_QUALITY)] _HighQualityEnabled ("High Quality", Float) = 1
		// Note: Unity walks .shader timestamps but not include-graph timestamps,
		// so a .cginc-only edit won't recompile this shader.  After editing any
		// .cginc in this folder, save this .shader file (e.g. add or remove a
		// trailing space) and force-refresh.
	}
	SubShader
	{
		// Pass 1: Deferred Base (no decals, zone bit 29)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#define PASS_DEFERRED_BASE
			#define DECAL_MODE_NONE
			#define ZONE_BIT 29
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 2: Deferred Base + 4 packed decals (zone bit 28)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#define PASS_DEFERRED_BASE
			#define DECAL_MODE_PACKED4
			#define ZONE_BIT 28
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 3: Deferred Base + N decals (zone bit 27)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#define PASS_DEFERRED_BASE
			#define DECAL_MODE_INFINITE
			#define ZONE_BIT 27
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 4: Deferred Additive Biome R (single-axis triplanar, R-only triangles)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define BIOME_MASK 1
			#define BIOME_FRAG_R
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 5: Deferred Additive Biome G (single-axis triplanar)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define BIOME_MASK 2
			#define BIOME_FRAG_G
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 6: Deferred Additive Biome B (single-axis triplanar)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define BIOME_MASK 4
			#define BIOME_FRAG_B
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 7: Deferred Additive Biome A (single-axis triplanar)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define BIOME_MASK 8
			#define BIOME_FRAG_A
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 8: Deferred Additive Biome R, 3-axis triplanar (additive-bucket triangles)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define ADDITIVE_BIOME
			#define BIOME_MASK 1
			#define BIOME_FRAG_R
			#define TRIPLANAR_3AXIS
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 9: Deferred Additive Biome G, 3-axis triplanar (additive-bucket triangles)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define ADDITIVE_BIOME
			#define BIOME_MASK 2
			#define BIOME_FRAG_G
			#define TRIPLANAR_3AXIS
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 10: Deferred Additive Biome B, 3-axis triplanar (additive-bucket triangles)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define ADDITIVE_BIOME
			#define BIOME_MASK 4
			#define BIOME_FRAG_B
			#define TRIPLANAR_3AXIS
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 11: Deferred Additive Biome A, 3-axis triplanar (additive-bucket triangles)
		Pass
		{
			Tags { "LIGHTMODE" = "DEFERRED" }
			Blend 0 One One, One One
			Blend 1 Zero One, One One
			Blend 2 SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
			Blend 3 One One, One One
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ ANTI_TILE_QUALITY_ON
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_DEFERRED_BIOME
			#define ADDITIVE_BIOME
			#define BIOME_MASK 8
			#define BIOME_FRAG_A
			#define TRIPLANAR_3AXIS
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 12: Custom Depth / Shadow
		Pass
		{
			Name "CustomDepthPass"
			Tags { "SHADOWSUPPORT" = "true" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ SHADOWS_CUBE
			#pragma multi_compile _ SHADOWS_DEPTH
			#define PASS_DEPTH
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 13: Local Space Prepass (No Decals)
		Pass
		{
			Name "Local Space Prepass NoDecals"
			Tags { }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#define PASS_PREPASS
			#define DECAL_MODE_NONE
			#define ZONE_BIT 29
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 14: Local Space Prepass (4 Decals)
		Pass
		{
			Name "Local Space Prepass 4Decals"
			Tags { }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#pragma multi_compile _ DECALS_ENABLED
			#define PASS_PREPASS
			#define DECAL_MODE_PACKED4
			#define ZONE_BIT 28
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 15: Local Space Prepass (Infinite Decals)
		Pass
		{
			Name "Local Space Prepass InfDecals"
			Tags { }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#pragma multi_compile _ SUB_ZONES_ENABLED
			#pragma multi_compile _ UNITY_HDR_ON
			#pragma multi_compile _ DECALS_ENABLED
			#define PASS_PREPASS
			#define DECAL_MODE_INFINITE
			#define ZONE_BIT 27
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}

		// Pass 16: Deferred Decal Mask
		Pass
		{
			Name "Local Space Deferred Decal Mask Pass"
			Tags { }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			#define PASS_DECAL_MASK
			#include "CelestialBody_Local.cginc"
			ENDHLSL
		}
	}
	CustomEditor "CelestialBodyLocalEditor"
}
