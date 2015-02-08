#line 2 "Lux.hlsl"
#ifdef _MSC_VER
    #define COMPILEVS
    #define COMPILEPS
    #define SKINNED
    #define NUMVERTEXLIGHTS
    #define INSTANCED
    #define PERPIXEL
#endif

#include "Lux/LuxCore/LuxUrhoMap.hlsl"
#include "LuxLighting.hlsl"

#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"
#line 20 "Lux.hlsl"

#include "Lux/LuxCore/LuxLightingDirect.hlsl"
#include "Lux/LuxCore/LuxLightingAmbient.hlsl"
#line 25 "Lux.hlsl"
//#include "LuxBumpedDiffuse.hlsl"

// When rendering a shadowed point light, disable specular calculations on Shader Model 2 to avoid exceeding the instruction limit
#if !defined(SM3) && defined(SHADOW) && defined(POINTLIGHT)
    #undef SPECULAR
#endif

void VS(FLOAT4 iPos : POSITION,
    FLOAT3 iNormal : NORMAL,
    FLOAT2 iTexCoord : TEXCOORD0,
    #if defined(LIGHTMAP) || defined(AO)
        FLOAT2 iTexCoord2 : TEXCOORD1,
    #endif
    #ifdef NORMALMAP
        FLOAT4 iTangent : TANGENT,
    #endif
    #ifdef SKINNED
        FLOAT4 iBlendWeights : BLENDWEIGHT,
        int4 iBlendIndices : BLENDINDICES,
    #endif
    #ifdef INSTANCED
        FLOAT4x3 iModelInstance : TEXCOORD2,
    #endif
    #ifdef BILLBOARD
        FLOAT2 iSize : TEXCOORD1,
    #endif
    #ifndef NORMALMAP
        out FLOAT2 oTexCoordWS : TEXCOORD0,
    #else
        out FLOAT4 oTexCoordWS : TEXCOORD0,
        out FLOAT4 oTangentWS : TEXCOORD3,
    #endif
    out FLOAT3 oNormalWS : TEXCOORD1,
    out FLOAT4 oWorldPosWS : TEXCOORD2,
    #ifdef PERPIXEL
        #ifdef SHADOW
            out FLOAT4 oShadowPosWS[NUMCASCADES] : TEXCOORD4,
        #endif
        #ifdef SPOTLIGHT
            out FLOAT4 oSpotPosWS : TEXCOORD5,
        #endif
        #ifdef POINTLIGHT
            out FLOAT3 oCubeMaskVec : TEXCOORD5,
        #endif
    #else
        out FLOAT3 oVertexLightWS : TEXCOORD4,
        out FLOAT4 oScreenPos : TEXCOORD5,
    #endif
    #if defined(LIGHTMAP) || defined(AO)
            out FLOAT2 oTexCoord2 : TEXCOORD6,
    #endif
    out FLOAT4 oPos : POSITION)
{
    FLOAT4x3 modelMatrix = iModelMatrix;

    FLOAT3 worldPosWS = GetWorldPos(modelMatrix);
    oPos = GetClipPos(worldPosWS);
    oNormalWS = GetWorldNormal(modelMatrix);
    oWorldPosWS = FLOAT4(worldPosWS, GetDepth(oPos));

    #ifdef NORMALMAP
        FLOAT3 tangentWS = GetWorldTangent(modelMatrix);
        FLOAT3 bitangentWS = cross(tangentWS, oNormalWS) * iTangent.w;
        oTexCoordWS = FLOAT4(GetTexCoord(iTexCoord), bitangentWS.xy);
        oTangentWS = FLOAT4(tangentWS, bitangentWS.z);
    #else
        oTexCoordWS = GetTexCoord(iTexCoord);
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        FLOAT4 projWorldPos = FLOAT4(worldPosWS.xyz, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            GetShadowPos(projWorldPos, oShadowPosWS);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            oSpotPosWS = MUL(projWorldPos, cLightMatrices[0]);
        #endif

        #ifdef POINTLIGHT
            oCubeMaskVec = MUL(worldPosWS - cLightPos.xyz, (FLOAT3x3)cLightMatrices[0]);
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || defined(AO)
                // If using lightmap, disregard zone ambient light
                // If using AO, calculate ambient in the PS
                oVertexLightWS = FLOAT3(0.0, 0.0, 0.0);
        #else
                oVertexLightWS = GetAmbient(GetZonePos(worldPosWS));
        #endif
        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                oVertexLightWS += GetVertexLight(i, worldPosWS, oNormalWS) * cVertexLights[i * 3].rgb;
        #endif
        oScreenPos = GetScreenPos(oPos);
    #endif

    // Ambient & per-vertex lighting
    #if defined(LIGHTMAP) || defined(AO)
        oTexCoord2 = iTexCoord;
    #endif
}

void PS(
   #ifndef NORMALMAP
        FLOAT2 iTexCoord : TEXCOORD0,
    #else
        FLOAT4 iTexCoord : TEXCOORD0,
        FLOAT4 iTangentWS : TEXCOORD3,
    #endif
    FLOAT3 iNormalWS : TEXCOORD1,
    FLOAT4 iWorldPosWS : TEXCOORD2,
    #ifdef PERPIXEL
        #ifdef SHADOW
            FLOAT4 iShadowPosWS[NUMCASCADES] : TEXCOORD4,
        #endif
        #ifdef SPOTLIGHT
            FLOAT4 iSpotPosWS : TEXCOORD5,
        #endif
        #ifdef CUBEMASK
            FLOAT3 iCubeMaskVec : TEXCOORD5,
        #endif
    #else
        FLOAT3 iVertexLight : TEXCOORD4,
        FLOAT4 iScreenPos : TEXCOORD5,
    #endif
    #if defined(LIGHTMAP) || defined(AO)
        FLOAT2 iTexCoord2 : TEXCOORD6,
    #endif
    #ifdef PREPASS
        out FLOAT4 oDepth : COLOR1,
    #endif
    #ifdef DEFERRED
        out FLOAT4 oAlbedo : COLOR1,
        out FLOAT4 oNormal : COLOR2,
        out FLOAT4 oDepth : COLOR3,
    #endif
    out FLOAT4 oColor : COLOR0)
{
    SurfaceOutputLux o;
    o.Albedo = HALF3(1.0f, 0.0f, 0.0f);
    o.Normal = HALF3(0.5f, 0.5f, 1.0f);
    o.Emission = HALF4(0.0f, 0.0f, 0.0f, 0.0f);
    o.AmbientOcclusion = 1.0f;
    o.DiffuseIBL = HALF3(0.0f, 0.0f, 0.0f);
    o.SpecularIBL = HALF3(0.0f, 0.0f, 0.0f);
    o.Specular = 0.0f;
    o.SpecularColor = HALF3(0.0f, 0.0f, 0.0f);
    o.Alpha = 0.0f;
    o.DeferredFresnel = 0.0f;

    Input IN;
    IN.worldNormal = normalize(iNormalWS);
    IN.viewDir = normalize(cCameraPosPS - iWorldPosWS.xyz);
    IN.worldRefl = -IN.viewDir;
    IN.uv_MainTex = iTexCoord.xy;
    IN.uv_BumpMap = iTexCoord.xy;
    #ifdef AO
        IN.uv_AO = iTexCoord2.xy;
    #else
        IN.uv_AO = IN.uv_MainTex;
    #endif
    IN.worldPos = iWorldPosWS.xyz;

    #ifdef NORMALMAP
        HALF3 binormalWS = HALF3(iTexCoord.zw, iTangentWS.w);
        HALF3x3 tbn = HALF3x3(iTangentWS.xyz, binormalWS, iNormalWS);
    #endif

    #ifdef PARALLAX_OFFSET
        HALF1 h = cMatDiffColor.a * tex2D(sDiffMap, IN.uv_BumpMap).a;
        FLOAT3 viewDirTS = normalize(MUL(tbn, IN.viewDir));
        FLOAT3 gNormalTS = normalize(MUL(tbn, iNormalWS.xyz));

        FLOAT3 offset = ParallaxOffset(h, viewDirTS, gNormalTS, cParallaxHeight);
        IN.uv_MainTex += offset;
        IN.uv_BumpMap += offset;
        o.AmbientOcclusion = cMatDiffColor.a * (offset.z + 1.0f - cParallaxHeight);
    #endif

    #ifdef PARALLAX_OCCLUSION
        FLOAT3 viewDirTS = normalize(MUL(tbn, IN.viewDir));
        FLOAT3 gNormalTS = normalize(MUL(tbn, iNormalWS.xyz));
        FLOAT3 offset = ParallaxOcclusion(sDiffMap, viewDirTS, iNormalWS.xyz, iTexCoord.xy, cParallaxHeight, cParallaxMip);
        IN.uv_MainTex += offset;
        IN.uv_BumpMap += offset;
        o.AmbientOcclusion = cMatDiffColor.a * (offset.z + 1.0f - cParallaxHeight);
    #endif

    #ifdef LUX_LINEAR
        HALF4 matDiffColor = toLinearTrue(cMatDiffColor);
        HALF4 matSpecColor = toLinearTrue(cMatSpecColor);
    #else
        HALF4 matDiffColor = cMatDiffColor;
        HALF4 matSpecColor = cMatSpecColor;
    #endif

    #ifdef DIFFMAP
        HALF4 diff_albedo = matDiffColor * tex2D(sDiffMap, IN.uv_MainTex);
    #else
        HALF4 diff_albedo = HALF4(0.0f, 0.0f, 0.0f, 0.0f);// matDiffColor;
    #endif

    #ifdef SPECMAP
        HALF4 spec_albedo = cMatSpecColor * tex2D(sSpecMap, IN.uv_MainTex);
    #else
        HALF4 spec_albedo = HALF4(1.0f, 1.0f, 1.0f, 1.0f);// cMatSpecColor;
    #endif

    #ifdef PBR_SANITIZE
        diff_albedo = clamp(diff_albedo, 0.04f, 0.9f);
        spec_albedo.rgb = clamp(spec_albedo.rgb, 0.04f, 1.0f);
    #endif

    #ifdef PBR_CONSERVATIVE
        // Ensure that diffuse and specular values will conserve light
        // spec + diff <= 1.0f
        HALF3 sum = diff_albedo.rgb + spec_albedo.rgb;
        HALF3 cl = clamp(sum, 0.0f, 1.0f);
        diff_albedo.rgb = diff_albedo.rgb/sum * cl;
        spec_albedo.rgb = spec_albedo.rgb/sum * cl;
    #endif

    o.Emission = tex2D(sEmissiveMap, IN.uv_MainTex).rgba;
    #ifdef AO
        o.AmbientOcclusion *= tex2D(sEmissiveMap, IN.uv_AO).r;
    #endif

    // Diffuse Albedo
    o.Albedo = diff_albedo.rgb;
    o.Alpha = diff_albedo.a;
    o.SpecularColor = spec_albedo.rgb * cMatSpecColor.rgb;
    // Roughness – gamma for BlinnPhong / linear for CookTorrence
    o.Specular = LuxAdjustSpecular(spec_albedo.a);

    #ifdef NORMALMAP
        HALF3 normalTS = DecodeNormal(tex2D(sNormalMap, IN.uv_BumpMap));
        if (length(normalTS) < 0.0001f)
        {
            normalTS = HALF3(0.0f, 0.0f, 1.0f);
        }
        //normalTS = normalize((normalTS - HALF3(0.0f, 0.0f, 1.0f)) * cMatNormalHeight + HALF3(0.0f, 0.0f, 1.0f));
        o.Normal = normalize(MUL(normalTS, tbn));
        IN.worldNormal = o.Normal;
    #endif

    #ifdef AO
        o.SpecularColor *= o.AmbientOcclusion;
    #endif

    #if defined(PERPIXEL)
        HALF3 lightDir;
        HALF1 atten = GetDiffuse(IN.worldNormal, IN.worldPos, lightDir) / 2.0f;
        HALF1 spec = 0;

        #ifdef LUX_LIGHTING_URHO
            HALF1 specPower = exp2(10.0f * o.Specular + 1.0f) - 1.75f;
            spec = GetSpecular(o.Normal, IN.viewDir, lightDir, specPower);
        #endif

        HALF4 final = LightingLuxDirect(o, lightDir, IN.viewDir, atten, cLightColor, spec);

        #ifdef SHADOW
            final *= GetShadow(iShadowPosWS, iWorldPosWS.w);
        #endif

        oColor = final;
    #elif defined(PREPASS)
        /// \todo fix pre-pass?
        oColor = HALF4(normalize(IN.worldNormal) * 0.5 + 0.5, o.Specular);
        oDepth = iWorldPosWS.w;
    #elif defined(DEFERRED)
        oColor = HALF4(o.SpecularColor, o.Specular);
        oAlbedo = HALF4(o.Albedo, o.Alpha);
        oNormal = HALF4(o.Normal * 0.5 + 0.5, o.AmbientOcclusion);
        oDepth = HALF4(EncodeDepth(iWorldPosWS.w), 0.0f);
    #else
        HALF3 finalColor = HALF3(0.0f, 0.0f, 0.0f);
        HALF1 emissiveAO = 1.0f;

        #ifdef ENVCUBEMAP
        LightingLuxAmbient(IN, o, sEnvCubeMap, sZoneCubeMap, cAmbientHDRScale, cCubeMatrixTrans, cCubeMatrixInv, cCubeMapSize, cCubeMapPosition);
            #ifdef AO
                emissiveAO = o.AmbientOcclusion;
                o.DiffuseIBL *= emissiveAO;
                o.SpecularIBL *= emissiveAO;
            #endif

            finalColor += o.DiffuseIBL;
        #endif

        #ifdef ENVCUBEMAP
            finalColor += o.SpecularIBL;
        #endif

        oColor = FLOAT4(finalColor, 1.0f);
    #endif
}
