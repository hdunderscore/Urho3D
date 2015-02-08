#include "Lux/LuxCore/LuxUrhoMap.hlsl"
#include "LuxLighting.hlsl"

#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"

#include "Lux/LuxCore/LuxLightingDirect.hlsl"
#line 12 "LuxDeferredLight.hlsl"

void VS(FLOAT4 iPos : POSITION,
    #ifdef DIRLIGHT
        out FLOAT2 oScreenPos : TEXCOORD0,
    #else
        out FLOAT4 oScreenPos : TEXCOORD0,
    #endif
    out FLOAT3 oFarRay : TEXCOORD1,
    #ifdef ORTHO
        out FLOAT3 oNearRay : TEXCOORD2,
    #endif
    out FLOAT4 oPos : POSITION)
{
    FLOAT4x3 modelMatrix = iModelMatrix;
    FLOAT3 worldPos = GetWorldPos(modelMatrix);
    oPos = GetClipPos(worldPos);
    #ifdef DIRLIGHT
        oScreenPos = GetScreenPosPreDiv(oPos);
        oFarRay = GetFarRay(oPos);
        #ifdef ORTHO
            oNearRay = GetNearRay(oPos);
        #endif
    #else
        oScreenPos = GetScreenPos(oPos);
        oFarRay = GetFarRay(oPos) * oPos.w;
        #ifdef ORTHO
            oNearRay = GetNearRay(oPos) * oPos.w;
        #endif
    #endif
}

void PS(
    #ifdef DIRLIGHT
        FLOAT2 iScreenPos : TEXCOORD0,
    #else
        FLOAT4 iScreenPos : TEXCOORD0,
    #endif
    FLOAT3 iFarRay : TEXCOORD1,
    #ifdef ORTHO
        FLOAT3 iNearRay : TEXCOORD2,
    #endif
    out FLOAT4 oColor : COLOR0)
{
    // If rendering a directional light quad, optimize out the w divide
    #ifdef DIRLIGHT
        #ifdef HWDEPTH
            FLOAT1 depth = ReconstructDepth(depth);
        #else
            FLOAT1 depth = Sample(sDepthBuffer, iScreenPos).r;
        #endif
        #ifdef ORTHO
            HALF3 worldPos = lerp(iNearRay, iFarRay, depth);
        #else
            HALF3 worldPos = iFarRay * depth;
        #endif
        FLOAT4 specularInput = Sample(sSpecMap, iScreenPos);
        FLOAT4 albedoInput = Sample(sAlbedoBuffer, iScreenPos);
        FLOAT4 normalInput = Sample(sNormalBuffer, iScreenPos);
    #else
        #ifdef HWDEPTH
            FLOAT1 depth = ReconstructDepth(depth);
        #else
            FLOAT1 depth = Sample(sDepthBuffer, iScreenPos).r;
        #endif
        #ifdef ORTHO
            HALF3 worldPos = lerp(iNearRay, iFarRay, depth) / iScreenPos.w;
        #else
            HALF3 worldPos = iFarRay * depth / iScreenPos.w;
        #endif
        FLOAT4 specularInput = tex2Dproj(sSpecMap, iScreenPos);
        FLOAT4 albedoInput = tex2Dproj(sAlbedoBuffer, iScreenPos);
        FLOAT4 normalInput = tex2Dproj(sNormalBuffer, iScreenPos);
    #endif

    SurfaceOutputLux o;
    o.Normal = normalize(normalInput.rgb * 2.0f - 1.0f);
    o.Albedo = albedoInput.rgb;
    o.Emission = HALF4(0.0f, 0.0f, 0.0f, 0.0f);
    o.AmbientOcclusion = 1.0f;
    o.DiffuseIBL = HALF3(0.0f, 0.0f, 0.0f);
    o.SpecularIBL = HALF3(0.0f, 0.0f, 0.0f);
    o.Specular = specularInput.a;
    o.SpecularColor = specularInput.rgb;
    o.Alpha = albedoInput.a;
    o.DeferredFresnel = 0.0f;

    Input IN;
    IN.worldNormal = o.Normal;
    IN.viewDir = normalize(-iFarRay);
    IN.worldRefl = -IN.viewDir;
    IN.uv_MainTex = HALF2(0.0f, 0.0f);
    IN.uv_BumpMap = HALF2(0.0f, 0.0f);
    IN.uv_AO = HALF2(0.0f, 0.0f);
    IN.worldPos = worldPos;

    HALF4 projWorldPos = HALF4(worldPos, 1.0f);
    HALF3 lightColor;
    HALF3 lightDir;
    HALF4 finalColor = HALF4(0.0f, 0.0f, 0.0f, 0.0f);

    // Accumulate light at HALF intensity to allow 2x "overburn"
    HALF1 atten = GetDiffuse(IN.worldNormal, IN.worldPos, lightDir) / 2.0f;
    lightDir = normalize(lightDir);

    #if defined(SPOTLIGHT)
        HALF4 spotPos = MUL(projWorldPos, cLightMatricesPS[0]);
        lightColor = spotPos.w > 0.0f ? tex2Dproj(sLightSpotMap, spotPos).rgb * cLightColor.rgb : 0.0f;
    #elif defined(CUBEMASK)
        lightColor = texCUBE(sLightCubeMap, MUL(worldPos - cLightPosPS.xyz, (FLOAT3x3)cLightMatricesPS[0])).rgb * cLightColor.rgb;
    #else
        lightColor = cLightColor.rgb;
    #endif

    HALF1 spec = 0.0f;
    #ifdef LUX_LIGHTING_URHO
        HALF1 specPower = exp2(10.0f * o.Specular + 1.0f) - 1.75f;
        spec = GetSpecular(o.Normal, IN.viewDir, lightDir, specPower);
    #endif

    finalColor = LightingLuxDirect(o, lightDir, IN.viewDir, atten, FLOAT4(lightColor, 1), spec);

    #ifdef SHADOW
        finalColor *= GetShadowDeferred(projWorldPos, depth);
    #endif

    #ifdef SPECULAR
        oColor = finalColor;
    #else
        oColor = finalColor;
    #endif
}
