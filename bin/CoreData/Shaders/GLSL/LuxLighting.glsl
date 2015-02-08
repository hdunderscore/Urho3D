#line 2 3

#define OneOnLN2_x6 8.656170
#define Pi 3.14159265358979323846
#define WorldReflectionVector(IN) normalize(reflect(IN.worldRefl, IN.worldNormal))

#define LUX_LIGHTING_MR true
#define LUX_LIGHTING

#define PBR_CONSERVATIVE
//#define PBR_SANITIZE

uniform FLOAT1 cAmbientHDRScale;

uniform FLOAT1 cParallaxHeight;
uniform FLOAT1 cParallaxMip;

uniform FLOAT4x4 cCubeMatrixTrans;
uniform FLOAT4x4 cCubeMatrixInv;
uniform FLOAT3 cCubeMapSize;
uniform FLOAT3 cCubeMapPosition;

struct Input {
    HALF2 uv_MainTex;
    HALF2 uv_BumpMap;
    HALF2 uv_AO;
    HALF3 viewDir;
    HALF3 worldPos;
    HALF3 worldNormal;
    HALF3 worldRefl;
};

struct SurfaceOutputLux {
	HALF3 Albedo;
	HALF3 Normal;
	HALF4 Emission;
    HALF1 AmbientOcclusion;
    HALF3 DiffuseIBL;
    HALF3 SpecularIBL;
	HALF1 Specular;
	HALF3 SpecularColor;
	HALF1 Alpha;
	HALF1 DeferredFresnel;
};

#define DecodeHDR(IN) DecodeBGRM8(IN)
#define EncodeHDR(IN) EncodeBGRM8(IN)

FLOAT4 EncodeBGRM8(FLOAT4 rgba)
{
    FLOAT1 maxVal = max(rgba.r, max(rgba.g, rgba.b));
    const FLOAT1 MaxRange = 20.0f;
    const FLOAT1 MaxValue = 255.0f * MaxRange;
    FLOAT1 M = max(maxVal * 255.0f, 1.0f);
    const FLOAT1 scale = 1.0f / log2(MaxValue);
     FLOAT1 m = 255.0f / M;
    FLOAT4 rgbm;
    rgbm.rgb = rgba.rgb * m;
    rgbm.a = log2(M) * scale;
    return rgbm;
}

FLOAT4 DecodeBGRM8(in FLOAT4 rgbm)
{
    FLOAT4 r;
    const FLOAT1 MaxRange = 20.0f;
    const FLOAT1 MaxValue = 255.0f * MaxRange;
    const FLOAT1 scale = 1.0f / log2(MaxValue);
    FLOAT1 M = exp2(rgbm.a / scale);
    FLOAT1 m = M / (255.0f * 255.0f);
    r.rgb = rgbm.rgb * m;
    r.a = M;
    //r.rgb *= length(r.rgb) * 2.0f;
    return r;
}

FLOAT4 DecodeBGRE8(in FLOAT4 rgbe)
{
    FLOAT4 r;
    r.a = rgbe.a * 255 - 128;
    r.rgb = rgbe.rgb * exp2(r.a);
    r.a = length(r.rgb);
    return r;
}

FLOAT4 DecodeBGRD8(in FLOAT4 rgbd)
{
    FLOAT4 r;
    const FLOAT1 MaxRange = 20.0f;
    const FLOAT1 MaxValue = 255.0f * MaxRange;
    const FLOAT1 scale = 1.0f / log2(MaxValue);
    FLOAT1 D = MaxValue / exp2(rgbd.a / scale);
    FLOAT1 d = D / (255.0f * 255.0f);
    r.rgb = rgbd.rgb * d;
    r.a = D;
    //r.rgb *= length(r.rgb) * 2.0f;
    return r;
}

HALF3 ShadeSH9(HALF4 normal)
{
    /// \todo implement spherical harmonics
    return HALF3(0.0f,0.0f,0.0f);
}

FLOAT4 toLinearTrue(FLOAT4 col)
{
    FLOAT4 ncol;

    if (col.r <= 0.04045)
    {
        ncol.r = col.r / 12.92;
    }
    else
    {
        ncol.r = pow((col.r + 0.055) / 1.055, 2.4);
    }

    if (col.g <= 0.04045)
    {
        ncol.g = col.g / 12.92;
    }
    else
    {
        ncol.g = pow((col.g + 0.055) / 1.055, 2.4);
    }

    if (col.b <= 0.04045)
    {
        ncol.b = col.b / 12.92;
    }
    else
    {
        ncol.b = pow((col.b + 0.055) / 1.055, 2.4);
    }

    if (col.a <= 0.04045)
    {
        ncol.a = col.a / 12.92;
    }
    else
    {
        ncol.a = pow((col.a + 0.055) / 1.055, 2.4);
    }

    return ncol;
}


FLOAT4 toGammaTrue(FLOAT4 col)
{
    FLOAT4 ncol;

    if (col.r <= 0.0031308)
    {
        ncol.r = col.r * 12.92;
    }
    else
    {
        ncol.r = 1.055 * pow(col.r, 1.0 / 2.4) - 0.055;
    }

    if (col.g <= 0.0031308)
    {
        ncol.g = col.g * 12.92;
    }
    else
    {
        ncol.g = 1.055 * pow(col.g, 1.0 / 2.4) - 0.055;
    }

    if (col.b <= 0.0031308)
    {
        ncol.b = col.b * 12.92;
    }
    else
    {
        ncol.b = 1.055 * pow(col.b, 1.0 / 2.4) - 0.055;
    }

    if (col.a <= 0.0031308)
    {
        ncol.a = col.a * 12.92;
    }
    else
    {
        ncol.a = 1.055 * pow(col.a, 1.0 / 2.4) - 0.055;
    }

    return ncol;
}

FLOAT3 ParallaxOffset(HALF1 height, HALF3 viewDir, HALF3 normal, HALF1 scale)
{
    FLOAT2 newV = viewDir.xy;
    newV.y = -newV.y;
    FLOAT1 bias = scale;
    return FLOAT3(newV * (height * 2.0 - 1.0) * bias, height);
}

FLOAT3 ParallaxOcclusion(sampler2D heightMap, FLOAT3 viewDirTS, FLOAT3 normalTS, FLOAT2 uv, FLOAT1 scale, FLOAT1 lod)
{
    //Source: http://members.gamedev.net/JasonZ/Parallax/Parallax_Occlusion_Mapping.txt
    FLOAT1 fHeightMapScale = scale;
    const int nMaxSamples = 10;
    const int nMinSamples = 4;
    const FLOAT1 minAngle = 0.1f;
    //lod = 3.0f;
    // Calculate the parallax offset vector max length.
    // This is equivalent to the tangent of the angle between the
    // viewer position and the fragment location.

    // Calculate the geometric surface normal vector, the vector from
    // the viewer to the fragment, and the vector from the fragment
    // to the light.
    FLOAT3 N = FLOAT3(0, 0, 1);// normalize(normalTS);
    FLOAT3 E = normalize(viewDirTS);
    FLOAT1 dotEN = dot(E, N);
    // Calculate how many samples should be taken along the view ray
    // to find the surface intersection.  This is based on the angle
    // between the surface normal and the view vector.
    int nNumSamples = int(mix(nMaxSamples, nMinSamples, dotEN));

    FLOAT1 fParallaxLimit = -length(viewDirTS.xy);// +1.0f - pow(dotEN, 2.0f);
    if (viewDirTS.z < 0)
    {
        fParallaxLimit /= clamp(viewDirTS.z, -1.0f, minAngle);
    }
    else
    {
        fParallaxLimit /= clamp(viewDirTS.z, minAngle, 1.0f);
    }

    // Scale the parallax limit according to heightmap scale.
    fParallaxLimit *= fHeightMapScale;
    // Calculate the parallax offset vector direction and maximum offset.
    FLOAT2 vOffsetDir = normalize(viewDirTS.xy);
    vOffsetDir.y = -vOffsetDir.y;
    FLOAT2 vMaxOffset = vOffsetDir * fParallaxLimit;


    // Specify the view ray step size.  Each sample will shift the current
    // view ray by this amount.
    FLOAT1 fStepSize = 1.0 / FLOAT1(nNumSamples);

    // Initialize the starting view ray height and the texture offsets.
    FLOAT1 fCurrRayHeight = 1.0;
    FLOAT3 vCurrOffset = FLOAT3(0, 0, 0);
    FLOAT2 vLastOffset = FLOAT2(0, 0);

    FLOAT1 fLastSampledHeight = 1;
    FLOAT1 fCurrSampledHeight = 1;

    int nCurrSample = 0;
    bool hit = false;

    while (nCurrSample < nNumSamples)
    {
        // Sample the heightmap at the current texcoord offset.  The heightmap
        // is stored in the alpha channel of the height/normal map.
        //fCurrSampledHeight = texture2Dgrad( NH_Sampler, IN.texcoord + vCurrOffset, dx, dy ).a;
        //fCurrSampledHeight = texture2Dgrad(heightMap, uv + vCurrOffset, dx, dy).r;
        fCurrSampledHeight = textureLod(heightMap, uv + vCurrOffset.xy, lod).a;

        // Test if the view ray has intersected the surface.
        if (fCurrSampledHeight > fCurrRayHeight)
        {
            hit = true;
            // Find the relative height delta before and after the intersection.
            // This provides a measure of how close the intersection is to
            // the final sample location.
            FLOAT1 delta1 = fCurrSampledHeight - fCurrRayHeight;
            FLOAT1 delta2 = (fCurrRayHeight + fStepSize) - fLastSampledHeight;
            FLOAT1 ratio = delta1 / (delta1 + delta2);

            // Interpolate between the final two segments to
            // find the true intersection point offset.
            vCurrOffset.xy = (ratio)* vLastOffset + (1.0 - ratio) * vCurrOffset;
            vCurrOffset.z = fLastSampledHeight * ratio + (1.0f - ratio) * fCurrSampledHeight;

            // Force the exit of the while loop
            nCurrSample = nNumSamples + 1;
        }
        else
        {
            // The intersection was not found.  Now set up the loop for the next
            // iteration by incrementing the sample count,
            nCurrSample++;

            // take the next view ray height step,
            fCurrRayHeight -= fStepSize;

            // save the current texture coordinate offset and increment
            // to the next sample location,
            vLastOffset = vCurrOffset.xy;
            vCurrOffset.xy += fStepSize * vMaxOffset;

            // and finally save the current heightmap height.
            fLastSampledHeight = fCurrSampledHeight;
        }
    }

//     if (uv.x + vCurrOffset.x > 1.0f)
//     {
//         discard;
//     }
//
//     if (uv.y + vCurrOffset.y > 1.0f)
//     {
//         discard;
//     }
//
//     if (uv.x + vCurrOffset.x < 0.0f)
//     {
//         discard;
//     }
//
//     if (uv.x + vCurrOffset.x < 0.0f)
//     {
//         discard;
//     }

    return vCurrOffset;
}

// FLOAT3 ParallaxOcclusion2(sampler2D tangentMapOS, sampler2D normalMapOS, FLOAT3 viewDirTS, FLOAT3 normalTS, FLOAT2 uv, FLOAT scale, FLOAT lod)
// {
//     //Source: http://members.gamedev.net/JasonZ/Parallax/Parallax_Occlusion_Mapping.txt
//     const FLOAT fHeightMapScale = scale / 10.0f;
//     const int nMaxSamples = 60;
//     const int nMinSamples = 4;
//
//     FLOAT4 uvLoc = FLOAT4(uv, 0, lod);
//     FLOAT3 normalOS = texture2Dlod(normalMapOS, uvLoc);
//     FLOAT3 tangentOS = texture2Dlod(tangentMapOS, uvLoc);
//     normalOS = normalize(normalOS * 2.0f - 1.0f);
//     tangentOS = normalize(tangentOS * 2.0f - 1.0f);
//     FLOAT3 binormalOS = normalize(cross(tangentOS.xyz, normalOS.xyz));
//         FLOAT3x3 tbnOS = FLOAT3x3(tangentOS.xyz, binormalOS.xyz, normalOS.xyz);
//         viewDirTS.y = -viewDirTS.y;
//         FLOAT3 viewDirOS = normalize(MUL(tbnOS, viewDirTS));
//
//
//     FLOAT2 vMaxOffset;
//
//         FLOAT3 N = normalize(normalTS);
//         FLOAT3 E = normalize(viewDirTS);
//
//         int nNumSamples = nMaxSamples;// (int)lerp(nMaxSamples, nMinSamples, dot(E, N));
//
//     FLOAT1 fStepSize = 1.0 / (FLOAT1)nNumSamples;
//
//     FLOAT1 fCurrRayHeight = 1.0f;
//     FLOAT1 fLastRayHeight = fCurrRayHeight;
//     FLOAT3 vCurrOffset = FLOAT3(0, 0, 1.0f);
//     FLOAT3 vLastOffset = vCurrOffset;
//
//     FLOAT fLastSampledHeight = 1;
//     FLOAT fCurrSampledHeight = 1;
//
//     int nCurrSample = 0;
//     bool hit = false;
//     while (nCurrSample < nNumSamples)
//     {
//         FLOAT4 uvLoc = FLOAT4((uv + vCurrOffset.xy), 0, lod);
//         FLOAT4 normalOS = texture2Dlod(normalMapOS, uvLoc);
//         FLOAT4 tangentOS = texture2Dlod(tangentMapOS, uvLoc);
//         fCurrSampledHeight = tangentOS.w;
//         normalOS.xyz = normalize(normalOS.xyz * 2.0f - 1.0f);
//         tangentOS.xyz = normalize(tangentOS.xyz * 2.0f - 1.0f);
//         FLOAT3 binormalOS = normalize(cross(tangentOS.xyz, normalOS.xyz));
//             FLOAT3x3 tbnOS = FLOAT3x3(tangentOS.xyz, binormalOS.xyz, normalOS.xyz);
//
//             FLOAT3 vDirTS = normalize(MUL(viewDirOS, tbnOS));
//             vDirTS = normalize(vDirTS);
//         //vDirTS.y = -vDirTS.y;
//         //vDirTS.z = normalize(vDirTS).z;
//         FLOAT1 incr = fStepSize;
//         FLOAT3 dV = -viewDirTS * incr;
//             vMaxOffset = dV;
//         FLOAT zIncr = -vDirTS.z * incr / fHeightMapScale;
//
// //         vDirTS.xy = normalize(vDirTS.xy);
// //         vDirTS.y = -vDirTS.y;
// //         FLOAT2 m = 1.0f / vDirTS.xy / fHeightMapScale;
// //         FLOAT1 incr = fStepSize;
// //         vMaxOffset.xy = (incr - 1.0f) / m * incr;
// //         FLOAT1 f = length(m.xy * vMaxOffset.xy + 1.0f) * 1.0f;
// //         //vMaxOffset.xy /= f;
// //         FLOAT1 zIncr = -f;
//
// //         FLOAT1 incr = fStepSize * 1.0f;
// //         FLOAT3 f = -vDirTS.xyz;// / vDirTS.z;
// //         f *= fHeightMapScale;
// //         vMaxOffset = f * incr;
// //         FLOAT1 zIncr = -incr;// *(dot(vDirTS, nTS) * 16.0f);
//
//         // Test if the view ray has intersected the surface.
//         if (fCurrSampledHeight > fCurrRayHeight)
//         {
//             hit = true;
//             FLOAT1 delta1 = fCurrSampledHeight - fCurrRayHeight;
//             FLOAT1 delta2 = fLastRayHeight - fLastSampledHeight;
//             FLOAT1 ratio = delta1 / (delta1 + delta2);
//
//
//             //vCurrOffset.xy = (1.0f - fCurrRayHeight) * vMaxOffset.xy / vDirTS.z;
//             vCurrOffset.xy = (ratio)* vLastOffset + (1.0 - ratio) * vCurrOffset;
//             vCurrOffset.z = fLastSampledHeight * ratio + (1.0f - ratio) * fCurrSampledHeight;
//
//             nCurrSample = nNumSamples + 1;
//         }
//         else
//         {
//             nCurrSample++;
//
//             vLastOffset = vCurrOffset;
//             vCurrOffset.xy += vMaxOffset.xy;
//
//             fLastRayHeight = fCurrRayHeight;
//             fCurrRayHeight += zIncr;
//
//             fLastSampledHeight = fCurrSampledHeight;
//         }
//     }
//
//     if (!hit)
//     {
//         discard;
//     }
//
//     return vCurrOffset;
// }

// FLOAT2 ReliefMap(FLOAT3 viewDirWS, sampler2D reliefMap, FLOAT3 normalWS)
// {
//     FLOAT1 scale = 0.1f;
//     FLOAT3 Z = normalize(-normalWS) * scale;
//     FLOAT1 relief_depth = length(Z);
//     FLOAT3 relief_normal = -Z / relief_depth;
// }
//
// FLOAT1 ray_intersect_rm(
//     in sampler2D reliefmap,
//     in FLOAT2 dp,
//     in FLOAT2 ds)
// {
//     const int linear_search_steps = 16;
//     const int binary_search_steps = 6;
//     FLOAT1 depth_step = 1.0 / linear_search_steps;
//
//     // current size of search window
//     FLOAT1 size = depth_step;
//
//     // current depth position
//     FLOAT1 depth = 0.0;
//     // best match found (starts with last position 1.0)
//     FLOAT1 best_depth = 1.0;
//
//     // search front to back for first point inside object
//     for (int i = 0; i < linear_search_steps - 1; i++)
//     {
//         depth += size;
//         FLOAT4 t = texture2D(reliefmap, dp + ds*depth);
//
//             if (best_depth > 0.996)   // if no depth found yet
//                 if (depth >= t.w)
//                     best_depth = depth;   // store best depth
//     }
//     depth = best_depth;
//
//     // recurse around first point (depth) for closest match
//     for (int i = 0; i < binary_search_steps; i++)
//     {
//         size *= 0.5;
//         FLOAT4 t = texture2D(reliefmap, dp + ds*depth);
//             if (depth >= t.w)
//             {
//                 best_depth = depth;
//                 depth -= 2 * size;
//             }
//         depth += size;
//     }
//
//     return best_depth;
// }

// FLOAT3 fix_cube_lookup(FLOAT3 v, FLOAT lod)
// {
//     // source: http://the-witness.net/news/2012/02/seamless-cube-map-filtering/
//     const FLOAT cube_size = 512;
//     FLOAT1 M = max(max(abs(v.x), abs(v.y)), abs(v.z));
//     FLOAT1 scale = 1 - exp2(lod) / cube_size;
//     //FLOAT1 scale = (cube_size - 1) / cube_size;
//     if (abs(v.x) != M) v.x *= scale;
//     if (abs(v.y) != M) v.y *= scale;
//     if (abs(v.z) != M) v.z *= scale;
//     return v;
// }