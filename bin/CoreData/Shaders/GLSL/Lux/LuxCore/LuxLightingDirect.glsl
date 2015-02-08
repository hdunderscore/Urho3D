#line 2 5

#ifndef LuxLightingDirect_CG_INCLUDED
#define LuxLightingDirect_CG_INCLUDED

// Lux Lighting Functions

// for Cook Torrence spec or roughness has to be in linear space
HALF1 LuxAdjustSpecular(HALF1 spec) {
	#if defined(LUX_LIGHTING_CT)
		return clamp(pow(spec, 1.0f/2.2f), 0.0f, 0.996f);
    #elif defined(LUX_LIGHTING_MR)
        return 1.0f - spec;
    #else
		return spec;
	#endif
}

/////////////////////////////// deferred lighting / uses faked fresnel

HALF4 LightingLuxDirect_PrePass (SurfaceOutputLux s, HALF4 light)
{
	// light.a is "compressed" to fit into the 0-1 range using log2(x + 1) which is the best compromise i have found
	HALF1 spec = exp2(light.a) - 1.0f;
	HALF4 c;
//	Diffuse
	c.rgb = s.Albedo * light.rgb;
//	Specular
	//s.DeferredFresnel based on dot N V (faked fresnel as it should be dot H V)
	//#if !defined (LUX_DIFFUSE)
    c.rgb += (s.SpecularColor.rgb
        + (1.0f - s.SpecularColor.rgb)
                * s.DeferredFresnel
                )
            * spec
            * light.rgb;
//	#else
//		c.rgb += s.SpecularColor.rgb * spec * light.rgb;
	//#endif
	// this here is not really worth it:
	// do not use light.rgb but only the cromatic part of it as we have stores luninance already in the lighting pass
	// HALF3 luminanceSensivity = HALF3(0.299,0.587, 0.114);
	// HALF1 crominanceSpecLight = spec / (dot(light.rgb, luminanceSensivity) + 0.0001);
	// see: http://www.realtimerendering.com/blog/deferred-lighting-approaches/
	// c.rgb += (s.SpecularColor.rgb + ( 1.0 - s.SpecularColor.rgb) * s.DeferredFresnel) * s.SpecularColor.rgb * light.rgb * crominanceSpecLight;
	c.a = s.Alpha; // + spec;
	return c;
}

HALF1 NormalDistributionGGX(SurfaceOutputLux s, HALF3 h)
{
    HALF1 alpha = s.Specular * s.Specular;
    alpha *= alpha;
    HALF1 NdotH = dot(s.Normal, h);
    HALF1 d = (Pi * (NdotH * NdotH * (alpha - 1.0f) + 1.0f));
    return (alpha) / (d * d);
}

HALF1 SpecularSchlick(SurfaceOutputLux s, HALF3 v)
{
    HALF1 k = pow(s.Specular + 1.0f, 2.0f) / 8.0f;
    return dot(s.Normal, v) / (dot(s.Normal, v) * (1.0f - k) + k);
}

//FLOAT1 FresnelSchlick()

/////////////////////////////// forward lighting

HALF4 LightingLuxDirect (SurfaceOutputLux s, HALF3 lightDir, HALF3 viewDir, HALF1 atten, HALF4 lightColor, HALF1 spec_){
    // get base variables

	// normalizing lightDir makes fresnel smoother
	lightDir = normalize(lightDir);
	// normalizing viewDir does not help here, so we skip it
	HALF3 h = normalize (lightDir + viewDir);
	// dotNL has to have max
	HALF1 dotNL = max (0, dot (s.Normal, lightDir));
	HALF1 dotNH = max (0, dot (s.Normal, h));

    #if !defined (LUX_LIGHTING_BP) && !defined (LUX_LIGHTING_CT) && !defined(LUX_LIGHTING_URHO)
		    //#define LUX_LIGHTING_BP
	    #endif

    #ifdef LUX_LIGHTING_URHO
        HALF1 spec = spec_;
    #endif

    #ifdef LUX_LIGHTING_MR
        // GGX / Trowbridge-Ritz
        HALF1 spec = NormalDistributionGGX(s, h) * SpecularSchlick(s, lightDir) * SpecularSchlick(s, viewDir);
    #endif

//	////////////////////////////////////////////////////////////
//	Blinn Phong
	#if defined (LUX_LIGHTING_BP)
	    // bring specPower into a range of 0.25 ? 2048
	    HALF1 specPower = exp2(10.0f * s.Specular + 1.0f) - 1.75f;

    //	Normalized Lighting Model:
	    // L = (c_diff * dotNL + F_Schlick(c_spec, l_c, h) * ( (spec + 2)/8) * dotNH?spec * dotNL) * c_light

    //	Specular: Phong lobe normal distribution function
	    //FLOAT1 spec = ((specPower + 2.0) * 0.125 ) * pow(dotNH, specPower) * dotNL; // would be the correct term
	    // we use late * dotNL to get rid of any artifacts on the backsides
	    HALF1 spec = specPower * 0.125 * pow(dotNH, specPower);

    //	Visibility: Schlick-Smith
	    HALF1 alpha = 2.0f / sqrt( Pi * (specPower + 2.0f) );
	    HALF1 visibility = 1.0f / ( (dotNL * (1.0f - alpha) + alpha) * ( saturate(dot(s.Normal, viewDir)) * (1 - alpha) + alpha) );
	    spec *= visibility;
	#endif

//	////////////////////////////////////////////////////////////
//	Cook Torrrence like
//	from The Order 1886 // http://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf

	#if defined (LUX_LIGHTING_CT)
	    HALF1 dotNV = max(0.0f, dot(s.Normal, normalize(viewDir) ) );

    //	Please note: s.Specular must be linear
        HALF1 alpha = (1.0f - s.Specular); // alpha is roughness
	    alpha *= alpha;
        HALF1 alpha2 = alpha * alpha;

    //	Specular Normal Distribution Function: GGX Trowbridge Reitz
        HALF1 denominator = (dotNH * dotNH) * (alpha2 - 1.0f) + 1.0f;
	    denominator = Pi * denominator * denominator;
        HALF1 spec = alpha2 / denominator;

    //	Geometric Shadowing: Smith
        HALF1 V_ONE = dotNL + sqrt(alpha2 + (1.0f - alpha2) * dotNL * dotNL);
        HALF1 V_TWO = dotNV + sqrt(alpha2 + (1.0f - alpha2) * dotNV * dotNV);
	    spec /= V_ONE * V_TWO;
	#endif

//	Fresnel: Schlick
	// fast fresnel approximation:
	HALF3 fresnel = s.SpecularColor.rgb + ( 1.0 - s.SpecularColor.rgb) * exp2(-OneOnLN2_x6 * dot(h, lightDir));
	// from here on we use fresnel instead of spec as it is fixed3 = color
	fresnel *= spec;

// Final Composition
	HALF4 c;
	// we only use fresnel here / and apply late dotNL
    c.rgb = (s.Albedo + fresnel) * lightColor.rgb * dotNL * (atten * 2);
	c.a = s.Alpha; // + cLightColor.a * fresnel * atten;
	return c;
}

//////////////////////////////// directional lightmaps

// HALF4 LightingLuxDirect_DirLightmap (SurfaceOutputLux s, HALF4 color, HALF4 scale, HALF3 viewDir, bool surfFuncWritesNormal, out HALF3 specColor)
// {
// 	UNITY_DIRBASIS
// 	HALF3 scalePerBasisVector;
//
// 	HALF3 lm = DirLightmapDiffuse (unity_DirBasis, color, scale, s.Normal, surfFuncWritesNormal, scalePerBasisVector);
//
// 	HALF3 lightDir = normalize (scalePerBasisVector.x * unity_DirBasis[0] + scalePerBasisVector.y * unity_DirBasis[1] + scalePerBasisVector.z * unity_DirBasis[2]);
// 	HALF3 h = normalize (lightDir + viewDir);
//
// 	FLOAT1 dotNL = max (0, dot (s.Normal, lightDir));
// 	FLOAT1 dotNH = max (0, dot (s.Normal, h));
//
//
// 	#if !defined (LUX_LIGHTING_BP) && !defined (LUX_LIGHTING_CT)
// 		#define LUX_LIGHTING_BP
// 	#endif
//
// //	////////////////////////////////////////////////////////////
// //	Blinn Phong
// 	#if defined (LUX_LIGHTING_BP)
// 	// bring specPower into a range of 0.25 ? 2048
// 	FLOAT1 specPower = exp2(10 * s.Specular + 1) - 1.75;
//
// //	Normalized Lighting Model:
// 	// L = (c_diff * dotNL + F_Schlick(c_spec, l_c, h) * ( (spec + 2)/8) * dotNH?spec * dotNL) * c_light
//
// //	Specular: Phong lobe normal distribution function
// 	//FLOAT1 spec = ((specPower + 2.0) * 0.125 ) * pow(dotNH, specPower) * dotNL; // would be the correct term
// 	// we use late * dotNL to get rid of any artifacts on the backsides
// 	FLOAT1 spec = specPower * 0.125 * pow(dotNH, specPower);
//
// //	Visibility: Schlick-Smith
// 	FLOAT1 alpha = 2.0 / sqrt( Pi * (specPower + 2) );
// 	FLOAT1 visibility = 1.0 / ( (dotNL * (1 - alpha) + alpha) * ( saturate(dot(s.Normal, viewDir)) * (1 - alpha) + alpha) );
// 	spec *= visibility;
// 	#endif
//
// //	////////////////////////////////////////////////////////////
// //	Cook Torrrence like
// //	from The Order 1886 // http://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf
//
// 	#if defined (LUX_LIGHTING_CT)
// 	FLOAT1 dotNV = max(0, dot(s.Normal, normalize(viewDir) ) );
//
// //	Please note: s.Specular must be linear
// 	FLOAT1 alpha = (1.0 - s.Specular); // alpha is roughness
// 	alpha *= alpha;
// 	FLOAT1 alpha2 = alpha * alpha;
//
// //	Specular Normal Distribution Function: GGX Trowbridge Reitz
// 	FLOAT1 denominator = (dotNH * dotNH) * (alpha2 - 1) + 1;
// 	denominator = Pi * denominator * denominator;
// 	FLOAT1 spec = alpha2 / denominator;
//
// //	Geometric Shadowing: Smith
// 	// in order to make deferred fit forward lighting better we have to tweak roughness here
// 	// roughness = pow(roughness, .25);
// 	FLOAT1 V_ONE = dotNL + sqrt(alpha2 + (1 - alpha2) * dotNL * dotNL );
// 	FLOAT1 V_TWO = dotNV + sqrt(alpha2 + (1 - alpha2) * dotNV * dotNV );
// 	spec /= V_ONE * V_TWO;
// 	#endif
//
// //	Fresnel: Schlick
// 	// fixed3 fresnel = s.SpecularColor.rgb + ( 1.0 - s.SpecularColor.rgb) * pow(1.0f - saturate(dot(h, lightDir)), 5);
// 	// fast fresnel approximation:
// 	HALF3 fresnel = s.SpecularColor.rgb + ( 1.0 - s.SpecularColor.rgb) * exp2(-OneOnLN2_x6 * dot(h, lightDir));
//
// 	// from here on we use fresnel (in forward) instead of spec as it is fixed3 = color
// 	fresnel *= spec;
// 	// or spec for deferred (no fresnel term applied)
//
// 	// specColor used outside in the forward path, compiled out in prepass
// 	// here we drop spec and go with fresnel instead as it is FLOAT3
// //	forward
// 	//specColor = lm * _SpecColor.rgb * s.Gloss * spec;
// 	specColor = lm * fresnel;
// //	deferred
// 	// spec from the alpha component is used to calculate specular
// 	// in the Lighting*_Prepass function, it's not used in forward
// 	// we have to compress spec like we do in the "Internal-PrepassLighting" shader
// 	return HALF4(lm, log2(spec + 1));
// //}

#endif
