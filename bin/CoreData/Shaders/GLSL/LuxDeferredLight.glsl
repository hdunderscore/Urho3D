#include "Lux/LuxCore/LuxUrhoMap.glsl"
#include "LuxLighting.glsl"

#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Lighting.glsl"

#include "Lux/LuxCore/LuxLightingDirect.glsl"
#line 12 6

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
            HALF3 worldPos = mix(vNearRay, vFarRay, depth);
        #else
            HALF3 worldPos = vFarRay * depth;
        #endif
        FLOAT4 specularInput = texture2D(sSpecMap, vScreenPos);
        FLOAT4 albedoInput = texture2D(sAlbedoBuffer, vScreenPos);
        FLOAT4 normalInput = texture2D(sNormalBuffer, vScreenPos);
    #else
        #ifdef HWDEPTH
            FLOAT1 depth = ReconstructDepth(texture2DProj(sDepthBuffer, vScreenPos).r);
        #else
            FLOAT1 depth = DecodeDepth(texture2DProj(sDepthBuffer, vScreenPos).rgb);
        #endif
        #ifdef ORTHO
            HALF3 worldPos = mix(vNearRay, vFarRay, depth) / vScreenPos.w;
        #else
            HALF3 worldPos = vFarRay * depth / vScreenPos.w;
        #endif
        FLOAT4 specularInput = texture2DProj(sSpecMap, vScreenPos);
        FLOAT4 albedoInput = texture2DProj(sAlbedoBuffer, vScreenPos);
        FLOAT4 normalInput = texture2DProj(sNormalBuffer, vScreenPos);
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
    IN.viewDir = normalize(-vFarRay);
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
        lightColor = spotPos.w > 0.0f ? texture2Dproj(sLightSpotMap, spotPos).rgb * cLightColor.rgb : 0.0f;
    #elif defined(CUBEMASK)
        lightColor = textureCube(sLightCubeMap, MUL(worldPos - cLightPosPS.xyz, FLOAT3x3(cLightMatricesPS[0]))).rgb * cLightColor.rgb;
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

        gl_FragColor = finalColor;
}
