#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

uniform float cAmbientHDRScale;

#define DecodeHDR(IN) DecodeBGRM8((IN))

float4 DecodeBGRM8(in float4 rgbm)
{
    float4 r;
    const float MaxRange = 20.0f;
    const float MaxValue = 255.0f * MaxRange;
    const float scale = 1.0f / log2(MaxValue);
    float M = exp2(rgbm.a / scale);
    float m = M / (255.0f * 255.0f);
    r.rgb = rgbm.rgb * m;
    r.a = M;
    return r;
}

float4 DecodeBGRE8(in float4 rgbe)
{
    float4 r;
    r.a = rgbe.a * 255 - 128;
    r.rgb = rgbe.rgb * exp2(r.a);
    r.a = length(r.rgb);
    return r;
}

float4 DecodeBGRD8(in float4 rgbd)
{
    float4 r;
    const float MaxRange = 20.0f;
    const float MaxValue = 255.0f * MaxRange;
    const float scale = 1.0f / log2(MaxValue);
    float D = MaxValue / exp2(rgbd.a / scale);
    float d = D / (255.0f * 255.0f);
    r.rgb = rgbd.rgb * d;
    r.a = D;
    return r;
}

void VS(float4 iPos : POSITION,
    out float4 oPos : POSITION,
    out float3 oTexCoord : TEXCOORD0)
{
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    oPos = GetClipPos(worldPos);
    
    oPos.z = oPos.w;
    oTexCoord = iPos.xyz;
}

void PS(float3 iTexCoord : TEXCOORD0,
    out float4 oColor : COLOR0)
{
    float4 sky = DecodeHDR(texCUBE(sDiffCubeMap, iTexCoord.xyz));
    sky.rgb *= sky.a;
    sky.rgb *= cAmbientHDRScale;
    oColor = (cMatDiffColor * sky);
}
