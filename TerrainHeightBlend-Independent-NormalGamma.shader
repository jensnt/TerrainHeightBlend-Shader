// The MIT License (MIT) (see LICENSE.txt)
// Copyright © 2021 Jens Neitzel

Shader "Terrain/HeightBlend Independent, NormalMap Gamma Correction"
{
    Properties
    {
        _IndepControl ("Splat Map", 2D) = "red" {}
        
        _AlbedoMap0 ("Layer 0 Albedo Map", 2D) = "grey" {}
        _HeightMap0 ("Layer 0 Height Map", 2D) = "grey" {}
        _NormalMap0 ("Layer 0 Normal Map", 2D) = "bump" {}
        _NormalScale0 ("Layer 0 Normal Map Scale", Float) = 1.0
        _MetalFactor0 ("Layer 0 Metallic", Range(0.0, 1.0)) = 0.0
        _SmoothnessFactor0 ("Layer 0 Smoothness", Range(0.0, 1.0)) = 1.0
        _NormalGammaR0 ("Layer 0 Normal Gamma Red", Range(0.1, 10.0)) = 1.0
        _NormalGammaG0 ("Layer 0 Normal Gamma Green", Range(0.1, 10.0)) = 1.0
        
        _AlbedoMap1 ("Layer 1 Albedo Map", 2D) = "grey" {}
        _HeightMap1 ("Layer 1 Height Map", 2D) = "grey" {}
        _NormalMap1 ("Layer 1 Normal Map", 2D) = "bump" {}
        _NormalScale1 ("Layer 1 Normal Map Scale", Float) = 1.0
        _MetalFactor1 ("Layer 1 Metallic", Range(0.0, 1.0)) = 0.0
        _SmoothnessFactor1 ("Layer 1 Smoothness", Range(0.0, 1.0)) = 1.0
        _NormalGammaR1 ("Layer 1 Normal Gamma Red", Range(0.1, 10.0)) = 1.0
        _NormalGammaG1 ("Layer 1 Normal Gamma Green", Range(0.1, 10.0)) = 1.0
        
        _AlbedoMap2 ("Layer 2 Albedo Map", 2D) = "grey" {}
        _HeightMap2 ("Layer 2 Height Map", 2D) = "grey" {}
        _NormalMap2 ("Layer 2 Normal Map", 2D) = "bump" {}
        _NormalScale2 ("Layer 2 Normal Map Scale", Float) = 1.0
        _MetalFactor2 ("Layer 2 Metallic", Range(0.0, 1.0)) = 0.0
        _SmoothnessFactor2 ("Layer 2 Smoothness", Range(0.0, 1.0)) = 1.0
        _NormalGammaR2 ("Layer 2 Normal Gamma Red", Range(0.1, 10.0)) = 1.0
        _NormalGammaG2 ("Layer 2 Normal Gamma Green", Range(0.1, 10.0)) = 1.0
        
        _AlbedoMap3 ("Layer 3 Albedo Map", 2D) = "grey" {}
        _HeightMap3 ("Layer 3 Height Map", 2D) = "grey" {}
        _NormalMap3 ("Layer 3 Normal Map", 2D) = "bump" {}
        _NormalScale3 ("Layer 3 Normal Map Scale", Float) = 1.0
        _MetalFactor3 ("Layer 3 Metallic", Range(0.0, 1.0)) = 0.0
        _SmoothnessFactor3 ("Layer 3 Smoothness", Range(0.0, 1.0)) = 1.0
        _NormalGammaR3 ("Layer 3 Normal Gamma Red", Range(0.1, 10.0)) = 1.0
        _NormalGammaG3 ("Layer 3 Normal Gamma Green", Range(0.1, 10.0)) = 1.0
        
        _DistantMap ("Distant Map", 2D) = "grey" {}
        _DistantMapSmoothnessFactor ("Distant Map Smoothness", Range(0.0, 1.0)) = 1.0
        _DistMapBlendDistance("Distant Map Blend Distance", Range(0.0, 128)) = 64
        _DistMapInfluenceMin("Distant Map Influence Min", Range(0.0, 1.0)) = 0.2
        _DistMapInfluenceMax("Distant Map Influence Max", Range(0.0, 1.0)) = 0.8
        
        _OverlapDepth("Height Blend Overlap Depth", Range(0.001, 1.0)) = 0.07
        _Parallax ("Parallax Height", Range (0.005, 0.08)) = 0.02
    }

    SubShader
    {
        Tags {
            "RenderType" = "Opaque"
        }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard vertex:SplatmapVert addshadow fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0
        
        #include "textureNoTile.cginc"

        UNITY_DECLARE_TEX2D(_IndepControl);
        float4 _Control_TexelSize;
        sampler2D _AlbedoMap0, _AlbedoMap1, _AlbedoMap2, _AlbedoMap3;
        float4 _AlbedoMap0_ST, _AlbedoMap1_ST, _AlbedoMap2_ST, _AlbedoMap3_ST;
        sampler2D _HeightMap0, _HeightMap1, _HeightMap2, _HeightMap3;
        UNITY_DECLARE_TEX2D_NOSAMPLER(_DistantMap);
        half _DistMapBlendDistance;
        fixed _DistMapInfluenceMin;
        fixed _DistMapInfluenceMax;
        half _OverlapDepth;
        half _Parallax;
        sampler2D _NormalMap0, _NormalMap1, _NormalMap2, _NormalMap3;
        half _NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3;
        half _MetalFactor0, _MetalFactor1, _MetalFactor2, _MetalFactor3;
        half _SmoothnessFactor0, _SmoothnessFactor1, _SmoothnessFactor2, _SmoothnessFactor3, _DistantMapSmoothnessFactor;
        float _NormalGammaR0, _NormalGammaR1, _NormalGammaR2, _NormalGammaR3;
        float _NormalGammaG0, _NormalGammaG1, _NormalGammaG2, _NormalGammaG3;

        struct Input
        {
            float4 tc;
            half ViewDist;
            half3 viewDir;
        };

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void SplatmapVert (inout appdata_full v, out Input data)
        {
            UNITY_INITIALIZE_OUTPUT(Input, data);
            data.ViewDist = length(UnityObjectToViewPos(v.vertex).xyz);
            data.viewDir = normalize(ObjSpaceViewDir(v.vertex));
            v.tangent.w = -1;
            data.tc.xy = v.texcoord;
        }

        half blendByHeight(half texture1height,  half texture2height,  half control1height,  half control2height,  half overlapDepth,  out half textureHeightOut,  out half controlHeightOut)
        {
            half texture1heightPrefilter = texture1height * sign(control1height);
            half texture2heightPrefilter = texture2height * sign(control2height);
            half height1 = texture1heightPrefilter + control1height;
            half height2 = texture2heightPrefilter + control2height;
            half blendFactor = (clamp(((height1 - height2) / overlapDepth), -1, 1) + 1) / 2;
            // Substract positive differences of the other control height to not make one texture height benefit too much from the other.
            textureHeightOut = max(0, texture1heightPrefilter - max(0, control2height-control1height)) * blendFactor + max(0, texture2heightPrefilter - max(0, control1height-control2height)) * (1 - blendFactor);
            // Propagate sum of control heights to not loose height.
            controlHeightOut = control1height + control2height;
            return blendFactor;
        }

        fixed3 textureNoTileNormalGamma( sampler2D sampNorm, in NoTileUVs ntuvs, in half normalScale, float gammar, float gammag )
        {
            fixed3 mixedNormal;
            mixedNormal.r = lerp( lerp( (ntuvs.ofa.z) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uva, ntuvs.ddxa, ntuvs.ddya ), half4(1.0/gammar, 1.0/gammar, 1.0/gammar, 1.0/gammar)), normalScale).r,
                                        (ntuvs.ofb.z) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uvb, ntuvs.ddxb, ntuvs.ddyb ), half4(1.0/gammar, 1.0/gammar, 1.0/gammar, 1.0/gammar)), normalScale).r, ntuvs.b.x ), 
                                  lerp( (ntuvs.ofc.z) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uvc, ntuvs.ddxc, ntuvs.ddyc ), half4(1.0/gammar, 1.0/gammar, 1.0/gammar, 1.0/gammar)), normalScale).r,
                                        (ntuvs.ofd.z) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uvd, ntuvs.ddxd, ntuvs.ddyd ), half4(1.0/gammar, 1.0/gammar, 1.0/gammar, 1.0/gammar)), normalScale).r, ntuvs.b.x), ntuvs.b.y );
            
            mixedNormal.g = lerp( lerp( (ntuvs.ofa.w) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uva, ntuvs.ddxa, ntuvs.ddya ), half4(1.0/gammag, 1.0/gammag, 1.0/gammag, 1.0/gammag)), normalScale).g,
                                        (ntuvs.ofb.w) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uvb, ntuvs.ddxb, ntuvs.ddyb ), half4(1.0/gammag, 1.0/gammag, 1.0/gammag, 1.0/gammag)), normalScale).g, ntuvs.b.x ), 
                                  lerp( (ntuvs.ofc.w) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uvc, ntuvs.ddxc, ntuvs.ddyc ), half4(1.0/gammag, 1.0/gammag, 1.0/gammag, 1.0/gammag)), normalScale).g,
                                        (ntuvs.ofd.w) * UnpackNormalWithScale(pow(tex2D( sampNorm, ntuvs.uvd, ntuvs.ddxd, ntuvs.ddyd ), half4(1.0/gammag, 1.0/gammag, 1.0/gammag, 1.0/gammag)), normalScale).g, ntuvs.b.x), ntuvs.b.y );
            
            mixedNormal.b = lerp( lerp( UnpackNormalWithScale(tex2D( sampNorm, ntuvs.uva, ntuvs.ddxa, ntuvs.ddya ), normalScale).b,
                                        UnpackNormalWithScale(tex2D( sampNorm, ntuvs.uvb, ntuvs.ddxb, ntuvs.ddyb ), normalScale).b, ntuvs.b.x ),
                                  lerp( UnpackNormalWithScale(tex2D( sampNorm, ntuvs.uvc, ntuvs.ddxc, ntuvs.ddyc ), normalScale).b,
                                        UnpackNormalWithScale(tex2D( sampNorm, ntuvs.uvd, ntuvs.ddxd, ntuvs.ddyd ), normalScale).b, ntuvs.b.x), ntuvs.b.y );
            return mixedNormal;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 splat_control = UNITY_SAMPLE_TEX2D (_IndepControl, IN.tc.xy);
            fixed4 texDistantMap = UNITY_SAMPLE_TEX2D_SAMPLER (_DistantMap, _IndepControl, IN.tc.xy) * half4(1,1,1,_DistantMapSmoothnessFactor);

            fixed2 uvSplat0 = TRANSFORM_TEX(IN.tc.xy, _AlbedoMap0);
            fixed2 uvSplat1 = TRANSFORM_TEX(IN.tc.xy, _AlbedoMap1);
            fixed2 uvSplat2 = TRANSFORM_TEX(IN.tc.xy, _AlbedoMap2);
            fixed2 uvSplat3 = TRANSFORM_TEX(IN.tc.xy, _AlbedoMap3);
            
            NoTileUVs ntuvs0 = textureNoTileCalcUVs(uvSplat0);
            NoTileUVs ntuvs1 = textureNoTileCalcUVs(uvSplat1);
            NoTileUVs ntuvs2 = textureNoTileCalcUVs(uvSplat2);
            NoTileUVs ntuvs3 = textureNoTileCalcUVs(uvSplat3);
            fixed texture0Height = textureNoTile(_HeightMap0, ntuvs0);
            fixed texture1Height = textureNoTile(_HeightMap1, ntuvs1);
            fixed texture2Height = textureNoTile(_HeightMap2, ntuvs2);
            fixed texture3Height = textureNoTile(_HeightMap3, ntuvs3);

            // Calculate Blend factors
            half textHeight1, textHeight2, textHeight3;
            half ctrlHeight1, ctrlHeight2, ctrlHeight3;
            half blendFactor01 = blendByHeight(texture0Height, texture1Height, splat_control.r, splat_control.g, _OverlapDepth, textHeight1, ctrlHeight1);
            half blendFactor12 = blendByHeight(textHeight1, texture2Height, ctrlHeight1, splat_control.b, _OverlapDepth, textHeight2, ctrlHeight2);
            half blendFactor23 = blendByHeight(textHeight2, texture3Height, ctrlHeight2, splat_control.a, _OverlapDepth, textHeight3, ctrlHeight3);

            // Calculate Parallax after final heigth is known
            fixed2 paraOffset = ParallaxOffset(textHeight3, _Parallax, IN.viewDir);

            // Calculate UVs again, now with Parallax Offset
            ntuvs0 = textureNoTileCalcUVs(uvSplat0+paraOffset);
            ntuvs1 = textureNoTileCalcUVs(uvSplat1+paraOffset);
            ntuvs2 = textureNoTileCalcUVs(uvSplat2+paraOffset);
            ntuvs3 = textureNoTileCalcUVs(uvSplat3+paraOffset);

            // Sample Textures using the modified UVs
            fixed4 texture0 = textureNoTile(_AlbedoMap0, ntuvs0) * half4(1,1,1,_SmoothnessFactor0);
            fixed4 texture1 = textureNoTile(_AlbedoMap1, ntuvs1) * half4(1,1,1,_SmoothnessFactor1);
            fixed4 texture2 = textureNoTile(_AlbedoMap2, ntuvs2) * half4(1,1,1,_SmoothnessFactor2);
            fixed4 texture3 = textureNoTile(_AlbedoMap3, ntuvs3) * half4(1,1,1,_SmoothnessFactor3);

            // Blend Textures based on calculated blend factors
            fixed4 mixedDiffuse = texture0 * blendFactor01 + texture1 * (1 - blendFactor01);
            mixedDiffuse = mixedDiffuse * blendFactor12 + texture2 * (1 - blendFactor12);
            mixedDiffuse = mixedDiffuse * blendFactor23 + texture3 * (1 - blendFactor23);
    
            // Blend with Distant Map
            fixed influenceDist = clamp(IN.ViewDist/_DistMapBlendDistance+_DistMapInfluenceMin, 0, _DistMapInfluenceMax);
            mixedDiffuse = texDistantMap * influenceDist + mixedDiffuse * (1-influenceDist);

            // Sample Normal Maps using the modified UVs
            fixed3 texture0normal = textureNoTileNormalGamma(_NormalMap0, ntuvs0, _NormalScale0, _NormalGammaR0, _NormalGammaG0);
            fixed3 texture1normal = textureNoTileNormalGamma(_NormalMap1, ntuvs1, _NormalScale1, _NormalGammaR1, _NormalGammaG1);
            fixed3 texture2normal = textureNoTileNormalGamma(_NormalMap2, ntuvs2, _NormalScale2, _NormalGammaR2, _NormalGammaG2);
            fixed3 texture3normal = textureNoTileNormalGamma(_NormalMap3, ntuvs3, _NormalScale3, _NormalGammaR3, _NormalGammaG3);
            
            // Blend Normal maps based on calculated blend factors
            fixed3 mixedNormal = texture0normal * blendFactor01 + texture1normal * (1 - blendFactor01);
            mixedNormal = mixedNormal * blendFactor12 + texture2normal * (1 - blendFactor12);
            mixedNormal = mixedNormal * blendFactor23 + texture3normal * (1 - blendFactor23);
            mixedNormal.z += 1e-5f; // to avoid nan after normalizing
            
            // Blend Metallness based on calculated blend factors
            fixed mixedMetallic = _MetalFactor0 * blendFactor01 + _MetalFactor1 * (1 - blendFactor01);
            mixedMetallic = mixedMetallic * blendFactor12 + _MetalFactor2 * (1 - blendFactor12);
            mixedMetallic = mixedMetallic * blendFactor23 + _MetalFactor3 * (1 - blendFactor23);

            o.Albedo = mixedDiffuse.rgb;
            o.Smoothness = mixedDiffuse.a;
            o.Normal = mixedNormal;
            o.Metallic = mixedMetallic;
        }
        ENDCG
    }
    FallBack "Diffuse"
}

