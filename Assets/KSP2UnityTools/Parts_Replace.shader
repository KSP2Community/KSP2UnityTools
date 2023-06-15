Shader "Parts Replace"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 1, 1)
        _MainTex("Albedo Map", 2D) = "white" {}
        _MetallicGlossMap("Metallic", 2D) = "white" {}
        _Metallic("Metallic/Smoothness Map", Range(0, 1)) = 0
        _GlossMapScale("Smoothness Scale", Range(0, 1)) = 1
        _MipBias("Mip Bias", Range(0, 1)) = 0.8
        _BumpMap("Normal Map", 2D) = "bump" {}
        _DetailBumpMap("Detail Normal Map", 2D) = "bump" {}
        _DetailMask("Detail Mask", 2D) = "white" {}
        _DetailBumpScale("Detail Normal Scale", Range(0, 1)) = 1
        _DetailBumpTiling("Detail Normal Tiling", Range(0.01, 10)) = 1
        _OcclusionMap("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength("Strength", Range(0, 1)) = 1
        _EmissionMap("Emission Map", 2D) = "white" {}
        _EmissionColor("Emission Color", Color) = (0, 0, 0, 0)
        _UseTimeOfDay("Use Time of Day", Float) = 0
        _TimeOfDayDotMin("Min", Range(-1, 1)) = -0.005
        _TimeOfDayDotMax("Max", Range(-1, 1)) = 0.005
        _PaintA("Paint Color A", Color) = (1, 0, 0, 0)
        _PaintB("Paint Color B", Color) = (0, 1, 0.1558626, 0)
        _PaintMaskGlossMap("Paint Mask (RG Masks B Dirt A Smooth)", 2D) = "white" {}
        _PaintGlossMapScale("Paint Smoothness Scale", Range(0, 1)) = 1
        _SmoothnessOverride("Use PaintMask for Paint Smoothness (And not the Metallic Map)?", Float) = 1
        _RimFalloff("_RimFalloff", Range(0.01, 5)) = 0.1
        _RimColor("_RimColor", Color) = (0, 0, 0, 0)
        [HideInInspector]_BUILTIN_QueueOffset("Float", Float) = 0
        [HideInInspector]_BUILTIN_QueueControl("Float", Float) = -1
    }

    FallBack "Hidden/Shader Graph/FallbackError"
}