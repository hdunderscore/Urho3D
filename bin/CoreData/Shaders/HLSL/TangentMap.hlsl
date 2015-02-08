#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"

#line 9 "TangentMap.hlsl"

void VS(float4 iPos : POSITION,
    float3 iNormalOS : NORMAL,
    float2 iTexCoord : TEXCOORD0,
    float4 iTangentOS : TANGENT,
    out float4 oTexCoord : TEXCOORD0,
    out float4 oTangentOS : TEXCOORD1,
    out float3 oNormalOS : TEXCOORD2,
    out float4 oScreenPos: TEXCOORD3,
    out float4 oPos : POSITION)
{
    float4x3 modelMatrix = iModelMatrix;
        //float3 worldPos = GetWorldPos(modelMatrix);
        //oNormalOS = iNormalOS;
        float3 iNormal = iNormalOS;
        oNormalOS = iNormal;// GetWorldNormal(modelMatrix);

    //float3 tangentOS = iTangentOS;
    float3 iTangent = iTangentOS;
        float3 tangentOS = iTangent;// GetWorldTangent(modelMatrix);
        float3 bitangentOS = cross(tangentOS, oNormalOS) *iTangentOS.w;
    oTexCoord = float4(GetTexCoord(iTexCoord), bitangentOS.xy);
    oTangentOS = float4(tangentOS, bitangentOS.z);

    oPos.xy = (iTexCoord.xy * 2.0f - 1.0f);
    oPos.z = 0.0f;
    oPos.w = 1.0f;// GetClipPos(iPos).w;
    oScreenPos = oPos;

    //oTexCoord = mul(modelMatrix, iPos);
}

void PS(
    float4 iTexCoord : TEXCOORD0,
    float4 iTangentOS : TEXCOORD1,
    float3 iNormalOS : TEXCOORD2,
    float4 iScreenPos : TEXCOORD3,
    out float4 oColor : COLOR0)
{
    // Get normal
    float3 binormalOS = float3(iTexCoord.zw, iTangentOS.w);
    float3x3 tbn = float3x3(iTangentOS.xyz, binormalOS, iNormalOS);

    //float3 normalTS = iNormalOS;
    float3 iNormalTS = mul(tbn, iNormalOS);
    float3 sNormalTS = tex2D(sNormalMap, iTexCoord.xy) * 2.0f - 1.0f;
    float3 combineNormalTS = iNormalTS + sNormalTS;
    float3 normalOS = mul(combineNormalTS, tbn);
    //float3 tangentTS = iTangentOS;
    float3 tangentOS = cross(normalOS, binormalOS);

    // finalize:
    normalOS = normalize(normalOS) * 0.5f + 0.5f;
    tangentOS = normalize(tangentOS) * 0.5f + 0.5f;

#ifdef OUTPUT_NORMALMAP
    oColor = float4(normalOS, 1.0f);
#else
    oColor = float4(normalOS, 1.0f);
#endif
}
