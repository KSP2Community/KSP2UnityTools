Shader "KSP2/Parts/Reentry" {
	Properties {
		[NoScaleOffset] _HeatGradient ("Texture", 2D) = "white" {}
		[KeywordEnum(None, Friction, UV, VertColor, BaseNoise, Heat, Normals)] _DebugMode ("Debug Mode", Float) = 0
		[KeywordEnum(Both, Noise1, Noise2)] _NoiseMode ("Noise Mode", Float) = 0
		[Header(Script Controlled)] [PerRendererData] VesselId ("Vessel ID", Float) = 0
		[PerRendererData] ShockwaveDistance ("Shockwave Distance", Float) = 0.1
	}
	//DummyShaderTextExporter
	SubShader{
		Tags { "RenderType" = "Opaque" }
		LOD 200
		CGPROGRAM
#pragma surface surf Standard
#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
		};

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			o.Albedo = 1;
		}
		ENDCG
	}
}