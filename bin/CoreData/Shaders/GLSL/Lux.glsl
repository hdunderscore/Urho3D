#line 2 1
#ifdef _MSC_VER
    #define COMPILEVS
    #define COMPILEPS
    #define SKINNED
    #define NUMVERTEXLIGHTS
    #define INSTANCED
    #define PERPIXEL
#endif

#include "Lux/LuxCore/LuxUrhoMap.glsl"
#include "LuxLighting.glsl"

#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Lighting.glsl"
#include "Fog.glsl"
#line 20 1

#include "Lux/LuxCore/LuxLightingDirect.glsl"
#include "Lux/LuxCore/LuxLightingAmbient.glsl"
#line 25 1

// When rendering a shadowed point light, disable specular calculations on Shader Model 2 to avoid exceeding the instruction limit
#if !defined(SM3) && defined(SHADOW) && defined(POINTLIGHT)
    #undef SPECULAR
#endif

#ifdef NORMALMAP
    varying vec4 vTexCoord;
    varying vec4 vTangent;
#else
    varying vec2 vTexCoord;
#endif
varying vec3 vNormal;
varying vec4 vWorldPos;
#ifdef PERPIXEL
    #ifdef SHADOW
        varying vec4 vShadowPos[NUMCASCADES];
    #endif
    #ifdef SPOTLIGHT
        varying vec4 vSpotPos;
    #endif
    #ifdef POINTLIGHT
        varying vec3 vCubeMaskVec;
    #endif
#else
    varying vec3 vVertexLight;
    varying vec4 vScreenPos;
#endif

#if defined(LIGHTMAP) || defined(AO)
    varying vec2 vTexCoord2;
#endif


void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vNormal = GetWorldNormal(modelMatrix);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));

    #ifdef NORMALMAP
        vec3 tangent = GetWorldTangent(modelMatrix);
        vec3 bitangent = cross(tangent, vNormal) * iTangent.w;
        vTexCoord = vec4(GetTexCoord(iTexCoord), bitangent.xy);
        vTangent = vec4(tangent, bitangent.z);
    #else
        vTexCoord = GetTexCoord(iTexCoord);
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        vec4 projWorldPos = vec4(worldPos, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            for (int i = 0; i < NUMCASCADES; i++)
                vShadowPos[i] = GetShadowPos(i, projWorldPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            vSpotPos = cLightMatrices[0] * projWorldPos;
        #endif

        #ifdef POINTLIGHT
            vCubeMaskVec = mat3(cLightMatrices[0][0].xyz, cLightMatrices[0][1].xyz, cLightMatrices[0][2].xyz) * (worldPos - cLightPos.xyz);
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || defined(AO)
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
            vVertexLight = vec3(0.0, 0.0, 0.0);
        #else
            vVertexLight = GetAmbient(GetZonePos(worldPos));
        #endif

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                vVertexLight += GetVertexLight(i, worldPos, vNormal) * cVertexLights[i * 3].rgb;
        #endif

        vScreenPos = GetScreenPos(gl_Position);
    #endif

    #if defined(LIGHTMAP) || defined(AO)
        vTexCoord2 = iTexCoord;
    #endif
}

void PS()
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
    IN.worldNormal = normalize(vNormal);
    IN.viewDir = normalize(cCameraPosPS - vWorldPos.xyz);
    IN.worldRefl = -IN.viewDir;
    IN.uv_MainTex = vTexCoord.xy;
    IN.uv_BumpMap = vTexCoord.xy;
    #ifdef AO
        IN.uv_AO = vTexCoord2.xy;
    #else
        IN.uv_AO = IN.uv_MainTex;
    #endif
    IN.worldPos = vWorldPos.xyz;

    #ifdef NORMALMAP
        HALF3 binormal = HALF3(vTexCoord.zw, vTangent.w);
        HALF3x3 tbn = HALF3x3(vTangent.xyz, binormal, vNormal);
    #endif

    #ifdef PARALLAX_OFFSET
        HALF1 h = cMatDiffColor.a * texture2D(sDiffMap, IN.uv_BumpMap).a;
        FLOAT3 viewDirTS = normalize(MUL(tbn, IN.viewDir));
        FLOAT3 gNormalTS = normalize(MUL(tbn, vNormal.xyz));

        FLOAT3 offset = ParallaxOffset(h, viewDirTS, gNormalTS, cParallaxHeight);
        IN.uv_MainTex += offset;
        IN.uv_BumpMap += offset;
        o.AmbientOcclusion = cMatDiffColor.a * (offset.z + 1.0f - cParallaxHeight);
    #endif

    #ifdef PARALLAX_OCCLUSION
        FLOAT3 viewDirTS = normalize(MUL(tbn, IN.viewDir));
        FLOAT3 gNormalTS = normalize(MUL(tbn, vNormal.xyz));
        FLOAT3 offset = ParallaxOcclusion(sDiffMap, viewDirTS, vNormal.xyz, vTexCoord.xy, cParallaxHeight, cParallaxMip);
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
        HALF4 diff_albedo = matDiffColor * texture2D(sDiffMap, IN.uv_MainTex);
    #else
        HALF4 diff_albedo = HALF4(0.0f, 0.0f, 0.0f, 0.0f);// matDiffColor;
    #endif

    #ifdef SPECMAP
        HALF4 spec_albedo = cMatSpecColor * texture2D(sSpecMap, IN.uv_MainTex);
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

    o.Emission = texture2D(sEmissiveMap, IN.uv_MainTex).rgba;
    #ifdef AO
        o.AmbientOcclusion *= texture2D(sEmissiveMap, IN.uv_AO).r;
    #endif

    // Diffuse Albedo
    o.Albedo = diff_albedo.rgb;
    o.Alpha = diff_albedo.a;
    o.SpecularColor = spec_albedo.rgb * cMatSpecColor.rgb;
    // Roughness – gamma for BlinnPhong / linear for CookTorrence
    o.Specular = LuxAdjustSpecular(spec_albedo.a);

    #ifdef NORMALMAP
        HALF3 normalTS = DecodeNormal(texture2D(sNormalMap, IN.uv_BumpMap));
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
            final *= GetShadow(vShadowPos, vWorldPos.w);
        #endif

        gl_FragColor = final;
    #elif defined(PREPASS)
        /// \todo fix pre-pass?
        gl_FragData[0] = HALF4(normalize(IN.worldNormal) * 0.5 + 0.5, o.Specular);
        gl_FragData[1] = HALF4(EncodeDepth(vWorldPos.w), 0.0f);
    #elif defined(DEFERRED)
        gl_FragData[0] = HALF4(o.SpecularColor, o.Specular);
        gl_FragData[1] = HALF4(o.Albedo, o.Alpha);
        gl_FragData[2] = HALF4(o.Normal * 0.5 + 0.5, o.AmbientOcclusion);
        gl_FragData[3] = HALF4(EncodeDepth(vWorldPos.w), 0.0f);// vWorldPos.w;
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

        gl_FragColor = FLOAT4(finalColor, 1.0f);
    #endif
}
