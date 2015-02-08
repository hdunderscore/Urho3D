#line 2 9

HALF4 LightingLuxPrepass(HALF3 normal, HALF3 lightDir, HALF3 viewDir, FLOAT1 atten, HALF1 nspec, HALF3 wpos, HALF3 lightColor, FLOAT4 lightPos)
{
    //	////////////////////////////////////////////////////////////
    //	Lux Lighting
#define Pi 3.14159265358979323846
    // attention: sign of viewDir
    //FLOAT3 viewDir = normalize(wpos - _WorldSpaceCameraPos);
    // normalizing lightDir makes fresnel smoother
    lightDir = normalize(lightDir);
    // normalizing viewDir does not help here, so we skip it
    HALF3 h = normalize(lightDir + viewDir);
        // dotNL has to have max
        FLOAT1 dotNL = max(0, dot(normal, lightDir));
    FLOAT1 dotNH = max(0, dot(normal, h));

#if !defined (LUX_LIGHTING_BP) && !defined (LUX_LIGHTING_CT) && !defined(LUX_LIGHTING_URHO)
#define LUX_LIGHTING_BP
#endif

#ifdef LUX_LIGHTING_URHO
    FLOAT1 spec = spec_;
#endif

    //	////////////////////////////////////////////////////////////
    //	Blinn Phong
#if defined (LUX_LIGHTING_BP)
    // bring specPower into a range of 0.25 ? 2048
    FLOAT1 specPower = exp2(10 * nspec + 1) - 1.75;

    //	Normalized Lighting Model:
    // L = (c_diff * dotNL + F_Schlick(c_spec, l_c, h) * ( (spec + 2)/8) * dotNH?spec * dotNL) * c_light

    //	Specular: Phong lobe normal distribution function
    //FLOAT1 spec = ((specPower + 2.0) * 0.125 ) * pow(dotNH, specPower) * dotNL; // would be the correct term
    // we use late * dotNL to get rid of any artifacts on the backsides
    FLOAT1 spec = specPower * 0.125 * pow(dotNH, specPower);

    //	Visibility: Schlick-Smith
    FLOAT1 alpha = 2.0 / sqrt(Pi * (specPower + 2));
    FLOAT1 visibility = 1.0 / ((dotNL * (1 - alpha) + alpha) * (saturate(dot(normal, viewDir)) * (1 - alpha) + alpha));
    spec *= visibility;
#endif

    //	////////////////////////////////////////////////////////////
    //	Cook Torrrence like
    //	from The Order 1886 // http://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf

#if defined (LUX_LIGHTING_CT)
    FLOAT1 dotNV = max(0, dot(normal, normalize(viewDir)));

    //	Please note: s.Specular must be linear
    FLOAT1 alpha = (1.0 - nspec); // alpha is roughness
    alpha *= alpha;
    FLOAT1 alpha2 = alpha * alpha;

    //	Specular Normal Distribution Function: GGX Trowbridge Reitz
    FLOAT1 denominator = (dotNH * dotNH) * (alpha2 - 1) + 1;
    denominator = Pi * denominator * denominator;
    FLOAT1 spec = alpha2 / denominator;

    //	Geometric Shadowing: Smith
    FLOAT1 V_ONE = dotNL + sqrt(alpha2 + (1 - alpha2) * dotNL * dotNL);
    FLOAT1 V_TWO = dotNV + sqrt(alpha2 + (1 - alpha2) * dotNV * dotNV);
    spec /= V_ONE * V_TWO;
#endif

    //	Fresnel: Schlick
    // unfortunately fresnel does not work in deferred as we can’t access specularColorRGB
    // fresnel might be applied in "LightingLuxDirect_PrePass" if all needed params were passed in the surface function

    //	Final composition
    // Here we apply late "* dotNL" to eliminate all possible artifacts
    spec *= saturate(atten) * dotNL;
    HALF4 res;
    res.xyz = lightColor.rgb * (dotNL * atten * 2.0f);

    // calculate SpecularColor: here we only use luminance
    // see: http://www.realtimerendering.com/blog/deferred-lighting-approaches/
    //	HALF3 luminanceSensivity = HALF3(0.299,0.587, 0.114);
    //	HALF1 lightluminance = dot(_LightColor.rgb, luminanceSensivity);
    // compress SpecularColor
    //	res.w = log2(spec * lightluminance + 1);
    res.w = log2(spec + 1);
    //FLOAT1 fade = fadeDist;// *unity_LightmapFade.z + unity_LightmapFade.w;
    //res *= saturate(1.0 - fade);
    return res;
}
//
// c.rgb = (s.Albedo
//     + (s.SpecularColor.rgb
//     + (1 - s.SpecularColor.rgb)
//     * exp2(-OneOnLN2_x6 * dot(h, lightDir)))
//     * spec
//     )
//     * lightColor.rgb * dotNL * (atten * 2);
//
//
// c.rgb = (s.Albedo
//     + (s.SpecularColor.rgb
//     + (1 - s.SpecularColor.rgb)
//     * exp2(-OneOnLN2_x6 * dot(h, lightDir)))
//     * spec
//     )
//     * lightColor.rgb * dotNL * (atten * 2);
//
// res.xyz = *lightColor.rgb * dotNL * (atten * 2)
