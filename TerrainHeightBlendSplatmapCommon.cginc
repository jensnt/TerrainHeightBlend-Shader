// The MIT License (MIT) (see LICENSE.txt)
// Copyright (c) 2016 Unity Technologies
// Copyright © 2021 Jens Neitzel

#ifndef TERRAIN_HEIGHTBLEND_SPLATMAP_COMMON_CGINC_INCLUDED
#define TERRAIN_HEIGHTBLEND_SPLATMAP_COMMON_CGINC_INCLUDED

#ifdef _NORMALMAP
    // Since 2018.3 we changed from _TERRAIN_NORMAL_MAP to _NORMALMAP to save 1 keyword.
    #define _TERRAIN_NORMAL_MAP
#endif

#ifdef USE_TEXTURE_NO_TILE
    #include "textureNoTile.cginc"
#endif

struct Input
{
    float4 tc;
    #ifndef TERRAIN_BASE_PASS
        UNITY_FOG_COORDS(0) // needed because finalcolor oppresses fog code generation.
    #endif
    half ViewDist;
    half3 viewDir;
};

UNITY_DECLARE_TEX2D(_Control);
float4 _Control_ST;
float4 _Control_TexelSize;
sampler2D _Splat0, _Splat1, _Splat2, _Splat3;
float4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;
sampler2D _HeightMap0, _HeightMap1, _HeightMap2, _HeightMap3;
UNITY_DECLARE_TEX2D_NOSAMPLER(_DistantMap);
half _DistMapBlendDistance;
fixed _DistMapInfluenceMin;
fixed _DistMapInfluenceMax;
half _OverlapDepth;
half _Parallax;

#if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X)
    sampler2D _TerrainHeightmapTexture;
    sampler2D _TerrainNormalmapTexture;
    float4    _TerrainHeightmapRecipSize;   // float4(1.0f/width, 1.0f/height, 1.0f/(width-1), 1.0f/(height-1))
    float4    _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
#endif

UNITY_INSTANCING_BUFFER_START(Terrain)
    UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData) // float4(xBase, yBase, skipScale, ~)
UNITY_INSTANCING_BUFFER_END(Terrain)

#ifdef _NORMALMAP
    sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
    float _NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3;
#endif

#if defined(TERRAIN_BASE_PASS) && defined(UNITY_PASS_META)
    // When we render albedo for GI baking, we actually need to take the ST
    float4 _MainTex_ST;
#endif

void SplatmapVert(inout appdata_full v, out Input data)
{
    UNITY_INITIALIZE_OUTPUT(Input, data);
    data.ViewDist = length(UnityObjectToViewPos(v.vertex).xyz);
    data.viewDir = normalize(ObjSpaceViewDir(v.vertex));

#if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X)

    float2 patchVertex = v.vertex.xy;
    float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);

    float4 uvscale = instanceData.z * _TerrainHeightmapRecipSize;
    float4 uvoffset = instanceData.xyxy * uvscale;
    uvoffset.xy += 0.5f * _TerrainHeightmapRecipSize.xy;
    float2 sampleCoords = (patchVertex.xy * uvscale.xy + uvoffset.xy);

    float hm = UnpackHeightmap(tex2Dlod(_TerrainHeightmapTexture, float4(sampleCoords, 0, 0)));
    v.vertex.xz = (patchVertex.xy + instanceData.xy) * _TerrainHeightmapScale.xz * instanceData.z;  //(x + xBase) * hmScale.x * skipScale;
    v.vertex.y = hm * _TerrainHeightmapScale.y;
    v.vertex.w = 1.0f;

    v.texcoord.xy = (patchVertex.xy * uvscale.zw + uvoffset.zw);
    v.texcoord3 = v.texcoord2 = v.texcoord1 = v.texcoord;

    #ifdef TERRAIN_INSTANCED_PERPIXEL_NORMAL
        v.normal = float3(0, 1, 0); // TODO: reconstruct the tangent space in the pixel shader. Seems to be hard with surface shader especially when other attributes are packed together with tSpace.
        data.tc.zw = sampleCoords;
    #else
        float3 nor = tex2Dlod(_TerrainNormalmapTexture, float4(sampleCoords, 0, 0)).xyz;
        v.normal = 2.0f * nor - 1.0f;
    #endif
#endif

    v.tangent.xyz = cross(v.normal, float3(0,0,1));
    v.tangent.w = -1;

    data.tc.xy = v.texcoord;
#ifdef TERRAIN_BASE_PASS
    #ifdef UNITY_PASS_META
        data.tc.xy = v.texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
    #endif
#else
    float4 pos = UnityObjectToClipPos(v.vertex);
    UNITY_TRANSFER_FOG(data, pos);
#endif
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

#ifndef TERRAIN_BASE_PASS

#ifdef TERRAIN_STANDARD_SHADER
void SplatmapMix(Input IN, half4 defaultAlpha, out half4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#else
void SplatmapMix(Input IN, out half4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#endif
{
    // adjust splatUVs so the edges of the terrain tile lie on pixel centers
    float2 splatUV = (IN.tc.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
    splat_control = UNITY_SAMPLE_TEX2D(_Control, splatUV);
    fixed4 texDistantMap = UNITY_SAMPLE_TEX2D_SAMPLER(_DistantMap, _Control, splatUV);
    weight = dot(splat_control, half4(1,1,1,1));

    #if !defined(SHADER_API_MOBILE) && defined(TERRAIN_SPLAT_ADDPASS)
        clip(weight == 0.0f ? -1 : 1);
    #endif

    // Normalize weights before lighting and restore weights in final modifier functions so that the overal
    // lighting result can be correctly weighted.
    splat_control /= (weight + 1e-3f);

    fixed2 uvSplat0 = TRANSFORM_TEX(IN.tc.xy, _Splat0);
    fixed2 uvSplat1 = TRANSFORM_TEX(IN.tc.xy, _Splat1);
    fixed2 uvSplat2 = TRANSFORM_TEX(IN.tc.xy, _Splat2);
    fixed2 uvSplat3 = TRANSFORM_TEX(IN.tc.xy, _Splat3);

    #ifdef USE_TEXTURE_NO_TILE
        NoTileUVs ntuvs0 = textureNoTileCalcUVs(uvSplat0);
        NoTileUVs ntuvs1 = textureNoTileCalcUVs(uvSplat1);
        NoTileUVs ntuvs2 = textureNoTileCalcUVs(uvSplat2);
        NoTileUVs ntuvs3 = textureNoTileCalcUVs(uvSplat3);
        fixed texture0Height = textureNoTile(_HeightMap0, ntuvs0);
        fixed texture1Height = textureNoTile(_HeightMap1, ntuvs1);
        fixed texture2Height = textureNoTile(_HeightMap2, ntuvs2);
        fixed texture3Height = textureNoTile(_HeightMap3, ntuvs3);
    #else
        fixed texture0Height = tex2D(_HeightMap0, uvSplat0);
        fixed texture1Height = tex2D(_HeightMap1, uvSplat1);
        fixed texture2Height = tex2D(_HeightMap2, uvSplat2);
        fixed texture3Height = tex2D(_HeightMap3, uvSplat3);
    #endif

    // Calculate Blend factors
    half textHeight1, textHeight2, textHeight3;
    half ctrlHeight1, ctrlHeight2, ctrlHeight3;
    half blendFactor01 = blendByHeight(texture0Height, texture1Height, splat_control.r, splat_control.g, _OverlapDepth, textHeight1, ctrlHeight1);
    half blendFactor12 = blendByHeight(textHeight1, texture2Height, ctrlHeight1, splat_control.b, _OverlapDepth, textHeight2, ctrlHeight2);
    half blendFactor23 = blendByHeight(textHeight2, texture3Height, ctrlHeight2, splat_control.a, _OverlapDepth, textHeight3, ctrlHeight3);

    // Calculate Parallax after final heigth is known
    fixed2 paraOffset = ParallaxOffset(textHeight3, _Parallax, IN.viewDir);

    // Calculate UVs again, now with Parallax Offset
    #ifdef USE_TEXTURE_NO_TILE
        ntuvs0 = textureNoTileCalcUVs(uvSplat0+paraOffset);
        ntuvs1 = textureNoTileCalcUVs(uvSplat1+paraOffset);
        ntuvs2 = textureNoTileCalcUVs(uvSplat2+paraOffset);
        ntuvs3 = textureNoTileCalcUVs(uvSplat3+paraOffset);
    #else
        fixed2 uvs0 = uvSplat0 + paraOffset;
        fixed2 uvs1 = uvSplat1 + paraOffset;
        fixed2 uvs2 = uvSplat2 + paraOffset;
        fixed2 uvs3 = uvSplat3 + paraOffset;
    #endif

    // Sample Textures using the modified UVs
    #ifdef USE_TEXTURE_NO_TILE
        #ifdef TERRAIN_STANDARD_SHADER
            fixed4 texture0 = textureNoTile(_Splat0, ntuvs0) * half4(1.0, 1.0, 1.0, defaultAlpha.r);
            fixed4 texture1 = textureNoTile(_Splat1, ntuvs1) * half4(1.0, 1.0, 1.0, defaultAlpha.g);
            fixed4 texture2 = textureNoTile(_Splat2, ntuvs2) * half4(1.0, 1.0, 1.0, defaultAlpha.b);
            fixed4 texture3 = textureNoTile(_Splat3, ntuvs3) * half4(1.0, 1.0, 1.0, defaultAlpha.a);
        #else
            fixed4 texture0 = textureNoTile(_Splat0, ntuvs0);
            fixed4 texture1 = textureNoTile(_Splat1, ntuvs1);
            fixed4 texture2 = textureNoTile(_Splat2, ntuvs2);
            fixed4 texture3 = textureNoTile(_Splat3, ntuvs3);
        #endif
    #else
        #ifdef TERRAIN_STANDARD_SHADER
            fixed4 texture0 = tex2D(_Splat0, uvs0) * half4(1.0, 1.0, 1.0, defaultAlpha.r);
            fixed4 texture1 = tex2D(_Splat1, uvs1) * half4(1.0, 1.0, 1.0, defaultAlpha.g);
            fixed4 texture2 = tex2D(_Splat2, uvs2) * half4(1.0, 1.0, 1.0, defaultAlpha.b);
            fixed4 texture3 = tex2D(_Splat3, uvs3) * half4(1.0, 1.0, 1.0, defaultAlpha.a);
        #else
            fixed4 texture0 = tex2D(_Splat0, uvs0);
            fixed4 texture1 = tex2D(_Splat1, uvs1);
            fixed4 texture2 = tex2D(_Splat2, uvs2);
            fixed4 texture3 = tex2D(_Splat3, uvs3);
        #endif
    #endif

    mixedDiffuse = 0.0f;

    // Blend Textures based on calculated blend factors
    mixedDiffuse = texture0 * blendFactor01 + texture1 * (1 - blendFactor01);
    mixedDiffuse = mixedDiffuse * blendFactor12 + texture2 * (1 - blendFactor12);
    mixedDiffuse = mixedDiffuse * blendFactor23 + texture3 * (1 - blendFactor23);
    
    // Blend with Distant Map
    fixed influenceDist = clamp(IN.ViewDist/_DistMapBlendDistance+_DistMapInfluenceMin, 0, _DistMapInfluenceMax);
    mixedDiffuse = texDistantMap * influenceDist + mixedDiffuse * (1-influenceDist);

    #ifdef _NORMALMAP
        // Sample Normal Maps using the modified UVs
        #ifdef USE_TEXTURE_NO_TILE
            fixed3 texture0normal = textureNoTileNormal(_Normal0, ntuvs0, _NormalScale0);
            fixed3 texture1normal = textureNoTileNormal(_Normal1, ntuvs1, _NormalScale1);
            fixed3 texture2normal = textureNoTileNormal(_Normal2, ntuvs2, _NormalScale2);
            fixed3 texture3normal = textureNoTileNormal(_Normal3, ntuvs3, _NormalScale3);
        #else
            fixed3 texture0normal = UnpackNormalWithScale( tex2D(_Normal0, uvs0), _NormalScale0 );
            fixed3 texture1normal = UnpackNormalWithScale( tex2D(_Normal1, uvs1), _NormalScale1 );
            fixed3 texture2normal = UnpackNormalWithScale( tex2D(_Normal2, uvs2), _NormalScale2 );
            fixed3 texture3normal = UnpackNormalWithScale( tex2D(_Normal3, uvs3), _NormalScale3 );
        #endif
        // Blend Normal maps based on calculated blend factors
        mixedNormal = texture0normal * blendFactor01 + texture1normal * (1 - blendFactor01);
        mixedNormal = mixedNormal * blendFactor12 + texture2normal * (1 - blendFactor12);
        mixedNormal = mixedNormal * blendFactor23 + texture3normal * (1 - blendFactor23);
        mixedNormal.z += 1e-5f; // to avoid nan after normalizing
    #endif

    #if defined(INSTANCING_ON) && defined(SHADER_TARGET_SURFACE_ANALYSIS) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
        mixedNormal = float3(0, 0, 1); // make sure that surface shader compiler realizes we write to normal, as UNITY_INSTANCING_ENABLED is not defined for SHADER_TARGET_SURFACE_ANALYSIS.
    #endif

    #if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
        float3 geomNormal = normalize(tex2D(_TerrainNormalmapTexture, IN.tc.zw).xyz * 2 - 1);
        #ifdef _NORMALMAP
            float3 geomTangent = normalize(cross(geomNormal, float3(0, 0, 1)));
            float3 geomBitangent = normalize(cross(geomTangent, geomNormal));
            mixedNormal = mixedNormal.x * geomTangent
                          + mixedNormal.y * geomBitangent
                          + mixedNormal.z * geomNormal;
        #else
            mixedNormal = geomNormal;
        #endif
        mixedNormal = mixedNormal.xzy;
    #endif
}

#ifndef TERRAIN_SURFACE_OUTPUT
    #define TERRAIN_SURFACE_OUTPUT SurfaceOutput
#endif

void SplatmapFinalColor(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
{
    color *= o.Alpha;
    #ifdef TERRAIN_SPLAT_ADDPASS
        UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0,0,0,0));
    #else
        UNITY_APPLY_FOG(IN.fogCoord, color);
    #endif
}

void SplatmapFinalPrepass(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 normalSpec)
{
    normalSpec *= o.Alpha;
}

void SplatmapFinalGBuffer(Input IN, TERRAIN_SURFACE_OUTPUT o, inout half4 outGBuffer0, inout half4 outGBuffer1, inout half4 outGBuffer2, inout half4 emission)
{
    UnityStandardDataApplyWeightToGbuffer(outGBuffer0, outGBuffer1, outGBuffer2, o.Alpha);
    emission *= o.Alpha;
}

#endif // TERRAIN_BASE_PASS

#endif // TERRAIN_HEIGHTBLEND_SPLATMAP_COMMON_CGINC_INCLUDED
