// The MIT License (MIT) (see LICENSE.txt)
// Copyright (c) 2016 Unity Technologies
// Copyright © 2021 Jens Neitzel

Shader "Terrain/HeightBlend UnityTerrain" {
    Properties {
        // used in fallback on old cards & base map
        [HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
        [HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)
        
        _HeightMap0 ("Height Map Layer 0", 2D) = "grey" {}
        _HeightMap1 ("Height Map Layer 1", 2D) = "grey" {}
        _HeightMap2 ("Height Map Layer 2", 2D) = "grey" {}
        _HeightMap3 ("Height Map Layer 3", 2D) = "grey" {}
        
        _DistantMap ("Distant Map", 2D) = "grey" {}
        _DistMapBlendDistance("Distant Map Blend Distance", Range(0.0, 128)) = 64
        _DistMapInfluenceMin("Distant Map Influence Min", Range(0.0, 1.0)) = 0.2
        _DistMapInfluenceMax("Distant Map Influence Max", Range(0.0, 1.0)) = 0.8
        
        _OverlapDepth("Height Blend Overlap Depth", Range(0.001, 1.0)) = 0.07
        
        _Parallax ("Parallax Height", Range (0.005, 0.08)) = 0.02
    }

    SubShader {
        Tags {
            "Queue" = "Geometry-100"
            "RenderType" = "Opaque"
        }

        CGPROGRAM
        #pragma surface surf Standard vertex:SplatmapVert finalcolor:SplatmapFinalColor finalgbuffer:SplatmapFinalGBuffer addshadow fullforwardshadows
        #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap forwardadd
        #pragma multi_compile_fog // needed because finalcolor oppresses fog code generation.
        #pragma target 3.0
        // needs more than 8 texcoords
        #pragma exclude_renderers gles
        #include "UnityPBSLighting.cginc"

        #pragma multi_compile __ _NORMALMAP

        #define TERRAIN_STANDARD_SHADER
        #define TERRAIN_INSTANCED_PERPIXEL_NORMAL
        #define TERRAIN_SURFACE_OUTPUT SurfaceOutputStandard
        #define USE_TEXTURE_NO_TILE
        #include "TerrainHeightBlendSplatmapCommon.cginc"

        half _Metallic0;
        half _Metallic1;
        half _Metallic2;
        half _Metallic3;

        half _Smoothness0;
        half _Smoothness1;
        half _Smoothness2;
        half _Smoothness3;

        void surf (Input IN, inout SurfaceOutputStandard o) {
            half4 splat_control;
            half weight;
            fixed4 mixedDiffuse;
            half4 defaultSmoothness = half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);
            SplatmapMix(IN, defaultSmoothness, splat_control, weight, mixedDiffuse, o.Normal);
            o.Albedo = mixedDiffuse.rgb;
            o.Alpha = weight;
            o.Smoothness = mixedDiffuse.a;
            o.Metallic = dot(splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3));
        }
        ENDCG

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }

    Dependency "AddPassShader"    = "Hidden/TerrainEngine/Splatmap/Standard-AddPass"
    Dependency "BaseMapShader"    = "Hidden/TerrainEngine/Splatmap/Standard-Base"
    Dependency "BaseMapGenShader" = "Hidden/TerrainEngine/Splatmap/Standard-BaseGen"

    Fallback "Nature/Terrain/Standard"
}
