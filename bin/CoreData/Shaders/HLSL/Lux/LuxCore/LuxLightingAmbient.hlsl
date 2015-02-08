#line 2 "LuxLightingAmbient.hlsl"
#ifndef LuxIBL_CG_INCLUDED
#define LuxIBL_CG_INCLUDED

void LightingLuxAmbient(in Input IN, inout SurfaceOutputLux o, samplerCUBE _DiffCubeIBL, samplerCUBE _SpecCubeIBL, HALF1 hdrScale, HALF4x4 _CubeMatrix_Trans, HALF4x4 _CubeMatrix_Inv, HALF3 _CubemapSize, HALF3 _CubemapPosition)
{
    // Is set by script

    bool diffuseIsHDR = true;
    bool specularIsHDR = true;
    HALF1 Lux_HDR_Scale = hdrScale;
    HALF1 Lux_IBL_DiffuseExposure = 1.0f;
    HALF1 Lux_IBL_SpecularExposure = 1.0f;
    HALF1 DiffuseExposure, SpecularExposure;

    #ifdef LUX_LINEAR
        DiffuseExposure = Lux_IBL_DiffuseExposure;
        if (diffuseIsHDR)
        {
            DiffuseExposure *= pow(Lux_HDR_Scale, 2.2333333f);
        }

        SpecularExposure = Lux_IBL_SpecularExposure;
        if (specularIsHDR)
        {
            SpecularExposure *= pow(Lux_HDR_Scale, 2.2333333f);
        }
    #else
        DiffuseExposure = pow(Lux_IBL_DiffuseExposure, 1.0f / 2.2333333f);
        if (diffuseIsHDR)
        {
            DiffuseExposure *= Lux_HDR_Scale;
        }

        SpecularExposure = pow(Lux_IBL_SpecularExposure, 1.0f / 2.2333333f);
        if (specularIsHDR)
        {
            SpecularExposure *= Lux_HDR_Scale;
        }
    #endif

    HALF4 ExposureIBL = FLOAT4(DiffuseExposure, SpecularExposure, 1, 1);

    // Further functions to keep the surf function rather simple

    /////////////////////////////////////////
    // Lux IBL / ambient lighting
    HALF3 worldNormal = IN.worldNormal;

    // add diffuse IBL
    #ifdef DIFFCUBE
        HALF4 diff_ibl = DecodeHDR(texCUBE(_DiffCubeIBL, worldNormal));
        diff_ibl.rgb = diff_ibl.rgb * diff_ibl.a;
        o.DiffuseIBL = diff_ibl.rgb * ExposureIBL.x * o.Albedo;
    #endif

    // add specular IBL
    #ifdef SPECCUBE
        HALF1 NdotV = max(0, dot(o.Normal, normalize(IN.viewDir.xyz)));
        HALF3 worldRefl = WorldReflectionVector(IN);
        // Boxprojection / Rotation
        #ifdef BOXPROJECTION
            /// \todo Set up OOBB / geometric.
            // Bring worldRefl and worldPos into Cube Map Space
            HALF3 ReflCS = worldRefl;
            HALF3 PosCS = IN.worldPos - _CubemapPosition;
            HALF3 CS = _CubemapSize;
            HALF3 FirstPlaneIntersect = (CS - PosCS) / ReflCS;
            HALF3 SecondPlaneIntersect = (-CS - PosCS) / ReflCS;
            HALF3 FurthestPlane = max(FirstPlaneIntersect, SecondPlaneIntersect);

            HALF1 Distance = min(FurthestPlane.x, min(FurthestPlane.y, FurthestPlane.z));
            HALF3 intersectPosition = IN.worldPos + worldRefl * Distance;
            worldRefl = intersectPosition - _CubemapPosition;
        #endif

        #if defined (LUX_LIGHTING_CT)
            o.Specular *= o.Specular * (o.Specular * 0.305306011 + 0.682171111) + 0.012522878;
        #endif

        HALF1 mipSelect = 1.0f - o.Specular;
        mipSelect = mipSelect * 4.0f; // but * 6 would look better...
        HALF4 spec_ibl = DecodeHDR(texCUBElod(_SpecCubeIBL, FLOAT4(worldRefl, mipSelect)));

        spec_ibl.rgb = spec_ibl.rgb * spec_ibl.a;
        // fresnel based on spec_albedo.rgb and roughness (spec_albedo.a) / taken from: http://seblagarde.wordpress.com/2011/08/17/hello-world/
        HALF3 FresnelSchlickWithRoughness = o.SpecularColor + (max(o.Specular, o.SpecularColor) - o.SpecularColor) * exp2(-OneOnLN2_x6 * NdotV);
        // colorize fresnel highlights and make it look like marmoset:
        // FLOAT3 FresnelSchlickWithRoughness = o.SpecularColor + o.Specular.xxx * o.SpecularColor * exp2(-OneOnLN2_x6 * NdotV);
        spec_ibl.rgb *= FresnelSchlickWithRoughness * ExposureIBL.y;
        // add diffuse and specular and conserve energy
        o.SpecularIBL = (1.0f - spec_ibl.rgb) * clamp(o.DiffuseIBL, 0, 1.0f) + spec_ibl.rgb;
    #endif

    #ifdef LUX_METALNESS
        o.Emission *= spec_albedo.g;
    #endif
}
#endif
