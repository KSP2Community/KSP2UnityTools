Shader "KSP2/Planets/Scaled"
{
    Properties {
        [Header(Textures)] [NoScaleOffset] _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Color ("Main Color", Vector) = (1,1,1,1)
        [Space(5)] [NoScaleOffset] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Float) = 1
        [Space(5)] [NoScaleOffset] _PackedMap ("Packed Map", 2D) = "black" {}
        _AOScale ("AO Strength", Range(0, 1)) = 1
        _EmissionTex ("Emission Map", 2D) = "black" {}
        _EmissionScale ("Emission Scale", Range(0, 20)) = 0
        [Space(5)] [Header(Scaled GI)] _Body1Color ("Color", Vector) = (0,0,0,0)
        _Body1Intensity ("Intensity", Float) = 0
        _Body1Direction ("Direction", Vector) = (0,0,0,0)
        _Body2Color ("Color", Vector) = (0,0,0,0)
        _Body2Intensity ("Intensity", Float) = 0
        _Body2Direction ("Direction", Vector) = (0,0,0,0)
        [Space(5)] _ShadowStrength ("Shadow Strength", Range(0, 1)) = 0.9
        [HideInInspector] _Transition ("Transition", Float) = 1
        [HideInInspector] _DitheringScale ("Dithering Scale", Range(0.001, 10)) = 1
        [Space(5)] [Header(Shared poles)] _PlanetScale ("PlanetScale", Float) = 1
        [Space(5)] [Header(North pole)] [NoScaleOffset] _NorthPoleDiffuse ("North pole diffuse", 2D) = "white" {}
        [NoScaleOffset] _NorthPoleNormal ("North pole normal", 2D) = "bump" {}
        _NorthPoleBlendStart ("North pole blend start", Range(0, 1)) = 0
        _NorthPoleBlend ("North pole blend", Range(0, 5)) = 0
        _NorthPoleScale ("North pole scale", Range(0, 10)) = 1
        [ShowAsVector2] _NorthPoleOffset ("North pole offset", Vector) = (0,0,0,0)
        [Space(5)] [Header(South pole)] [NoScaleOffset] _SouthPoleDiffuse ("South pole diffuse", 2D) = "white" {}
        [NoScaleOffset] _SouthPoleNormal ("South pole normal", 2D) = "bump" {}
        _SouthPoleBlendStart ("South pole blend start", Range(0, 1)) = 0
        _SouthPoleBlend ("South pole blend", Range(0, 5)) = 0
        _SouthPoleScale ("South pole scale", Range(0, 10)) = 1
        [ShowAsVector2] _SouthPoleOffset ("South pole offset", Vector) = (0,0,0,0)
    }
    
    SubShader{
        Tags { "RenderType"="Opaque" }
        LOD 200
        CGPROGRAM
#pragma surface surf Standard
#pragma target 3.0

        sampler2D _MainTex;
        fixed4 _Color;
        struct Input
        {
            float2 uv_MainTex;
        };
        
        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Diffuse"
}
