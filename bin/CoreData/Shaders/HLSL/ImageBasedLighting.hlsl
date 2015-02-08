#include "LuxLighting.hlsl"

#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

#include "Lux/LuxCore/LuxUrhoMap.hlsl"
#include "Lux/LuxCore/LuxLightingAmbient.hlsl"
#line 12 "ImageBasedLighting.hlsl"

void VS(FLOAT4 iPos : POSITION,
    out FLOAT4 oPos : POSITION,
    out FLOAT2 oTexCoord : TEXCOORD0,
    out FLOAT4 oScreenPos : TEXCOORD1,
    out FLOAT3 oFarRay : TEXCOORD2
    #ifdef ORTHO
    , out FLOAT3 oNearRay : TEXCOORD3
    #endif
    )
{
    FLOAT4x3 modelMatrix = iModelMatrix;
    FLOAT3 worldPos = GetWorldPos(modelMatrix);

    oPos = GetClipPos(worldPos);

    oTexCoord = GetQuadTexCoord(oPos);
    oScreenPos = GetScreenPos(oPos);

    oFarRay = GetFarRay(oPos) * oPos.w;
    #ifdef ORTHO
        oNearRay = GetNearRay(oPos) * oPos.w;
    #endif
}

void PS(FLOAT2 iTexCoord : TEXCOORD0,
    FLOAT4 iScreenPos : TEXCOORD1,
    FLOAT3 iFarRay : TEXCOORD2,
    #ifdef ORTHO
        FLOAT3 iNearRay : TEXCOORD3,
    #endif
    out FLOAT4 oColor : COLOR0)
{
    FLOAT4 albedoInput = tex2D(sDiffMap, iScreenPos.xy);
    FLOAT4 specularInput = tex2D(sSpecMap, iScreenPos.xy);
    HALF4 normalInput = tex2D(sNormalMap, iScreenPos.xy);
    #ifdef HWDEPTH
        FLOAT1 depth = ReconstructDepth(texture2DProj(sDepthBuffer, vScreenPos).r);
    #else
    FLOAT1 depth = DecodeDepth(texture2DProj(sDepthBuffer, vScreenPos).rgb);
    #endif
    FLOAT4 viewport = tex2D(sEmissiveMap, iScreenPos.xy);
    #ifdef ORTHO
        HALF3 worldPos = lerp(iNearRay, iFarRay, depth) / iScreenPos.w;
    #else
        HALF3 worldPos = iFarRay * depth / iScreenPos.w;
    #endif
    worldPos += cCameraPosPS;
    HALF1 ao = normalInput.a;

    SurfaceOutputLux o;
    o.Normal = normalize(normalInput.rgb * 2.0f - 1.0f);
    o.Albedo = albedoInput.rgb;
    o.Emission = HALF4(0.0f, 0.0f, 0.0f, 0.0f);
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

    LightingLuxAmbient(IN, o, sEnvCubeMap, sZoneCubeMap, cAmbientHDRScale, cCubeMatrixTrans, cCubeMatrixInv, cCubeMapSize, cCubeMapPosition);

    oColor = viewport + ao * FLOAT4(o.DiffuseIBL + o.SpecularIBL, 1.0f);
}
