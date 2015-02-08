#include "Lux/LuxCore/LuxUrhoMap.glsl"
#include "LuxLighting.glsl"

#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Lighting.glsl"

#include "Lux/LuxCore/LuxPrepass.glsl"
#line 12 8

#ifdef DIRLIGHT
    varying vec2 vScreenPos;
#else
    varying vec4 vScreenPos;
#endif
varying vec3 vFarRay;
#ifdef ORTHO
    varying vec3 vNearRay;
#endif

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    #ifdef DIRLIGHT
        vScreenPos = GetScreenPosPreDiv(gl_Position);
        vFarRay = GetFarRay(gl_Position);
        #ifdef ORTHO
            vNearRay = GetNearRay(gl_Position);
        #endif
    #else
        vScreenPos = GetScreenPos(gl_Position);
        vFarRay = GetFarRay(gl_Position) * gl_Position.w;
        #ifdef ORTHO
            vNearRay = GetNearRay(gl_Position) * gl_Position.w;
        #endif
    #endif
}

void PS()
{
    // If rendering a directional light quad, optimize out the w divide
    #ifdef DIRLIGHT
        #ifdef HWDEPTH
            FLOAT1 depth = ReconstructDepth(texture2D(sDepthBuffer, vScreenPos).r);
        #else
            FLOAT1 depth = DecodeDepth(texture2D(sDepthBuffer, vScreenPos).rgb);
        #endif
        #ifdef ORTHO
            FLOAT3 worldPos = mix(vNearRay, vFarRay, depth);
        #else
            FLOAT3 worldPos = vFarRay * depth;
        #endif
        FLOAT4 normalInput = texture2D(sNormalBuffer, vScreenPos);
    #else
        #ifdef HWDEPTH
            FLOAT1 depth = ReconstructDepth(texture2DProj(sDepthBuffer, vScreenPos).r);
        #else
            FLOAT1 depth = DecodeDepth(texture2DProj(sDepthBuffer, vScreenPos).rgb);
        #endif
        #ifdef ORTHO
            FLOAT3 worldPos = mix(vNearRay, vFarRay, depth) / vScreenPos.w;
        #else
            FLOAT3 worldPos = vFarRay * depth / vScreenPos.w;
        #endif
        FLOAT4 normalInput = texture2DProj(sNormalBuffer, vScreenPos);
    #endif

    FLOAT3 normal = normalInput.rgb;
    FLOAT4 projWorldPos = FLOAT4(worldPos, 1.0);
    FLOAT3 lightColor;
    FLOAT3 lightDir;
    FLOAT4 finalColor = 0;
    FLOAT3 viewDir = normalize(-vFarRay);
    // Accumulate light at HALF intensity to allow 2x "overburn"
    FLOAT1 atten = GetDiffuse(normal, worldPos, lightDir) / 2.0f;
    lightDir = normalize(lightDir);
    #if defined(SPOTLIGHT)
        FLOAT4 spotPos = mul(projWorldPos, cLightMatricesPS[0]);
        lightColor = spotPos.w > 0.0 ? texture2DProj(sLightSpotMap, spotPos).rgb * cLightColor.rgb : 0.0;
    #elif defined(CUBEMASK)
        lightColor = texCUBE(sLightCubeMap, mul(worldPos - cLightPosPS.xyz, (FLOAT3x3)cLightMatricesPS[0])).rgb * cLightColor.rgb;
    #else
        lightColor = cLightColor.rgb;
    #endif

    finalColor = LightingLuxPrepass(normal, lightDir, viewDir, atten, normalInput.a, worldPos, cLightColor, cLightPosPS);
    #ifdef SHADOW
        finalColor *= GetShadowDeferred(projWorldPos, depth);
    #endif

    gl_FragColor = finalColor;
}
