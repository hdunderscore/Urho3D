#include "Lux/LuxCore/LuxUrhoMap.glsl"
#include "LuxLighting.glsl"

#include "Uniforms.glsl"
#include "Transform.glsl"
#include "Samplers.glsl"
#include "ScreenPos.glsl"
#include "PostProcess.glsl"

#include "Lux/LuxCore/LuxLightingAmbient.glsl"
#line 12 7


varying vec4 vScreenPos;
varying vec3 vFarRay;
#ifdef ORTHO
    varying vec3 vNearRay;
#endif

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vScreenPos = GetScreenPos(gl_Position);
    vFarRay = GetFarRay(gl_Position) * gl_Position.w;
    #ifdef ORTHO
        vNearRay = GetNearRay(gl_Position) * gl_Position.w;
    #endif
}

void PS()
{
    FLOAT4 albedoInput = texture2D(sDiffMap, vScreenPos.xy);
    FLOAT4 specularInput = texture2D(sSpecMap, vScreenPos.xy);
    HALF4 normalInput = texture2D(sNormalMap, vScreenPos.xy);
    #ifdef HWDEPTH
        FLOAT1 depth = ReconstructDepth(texture2D(sDepthBuffer, vScreenPos).r);
    #else
        FLOAT1 depth = DecodeDepth(texture2D(sDepthBuffer, vScreenPos).rgb);
    #endif
    FLOAT4 viewport = texture2D(sEmissiveMap, vScreenPos);
    #ifdef ORTHO
        HALF3 worldPos = mix(vNearRay, vFarRay, depth) / vScreenPos.w;
    #else
        HALF3 worldPos = vFarRay * depth / vScreenPos.w;
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
    IN.viewDir = normalize(-vFarRay);
    IN.worldRefl = -IN.viewDir;
    IN.uv_MainTex = HALF2(0.0f, 0.0f);
    IN.uv_BumpMap = HALF2(0.0f, 0.0f);
    IN.uv_AO = HALF2(0.0f, 0.0f);
    IN.worldPos = worldPos;

    LightingLuxAmbient(IN, o, sEnvCubeMap, sZoneCubeMap, cAmbientHDRScale, cCubeMatrixTrans, cCubeMatrixInv, cCubeMapSize, cCubeMapPosition);

    gl_FragColor = viewport + ao * FLOAT4(o.DiffuseIBL + o.SpecularIBL, 1.0f);
}
