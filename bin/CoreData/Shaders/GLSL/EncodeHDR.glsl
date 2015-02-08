#include "LuxLighting.glsl"

#include "Uniforms.glsl"
#include "Transform.glsl"
#include "Samplers.glsl"
#include "ScreenPos.glsl"
#include "PostProcess.glsl"

void VS(float4 iPos : POSITION,
    out float4 oPos : POSITION,
    out float2 oTexCoord : TEXCOORD0,
    out float2 oScreenPos : TEXCOORD1)
{
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    oPos = GetClipPos(worldPos);

    oTexCoord = GetQuadTexCoord(oPos);
    oScreenPos = GetScreenPosPreDiv(oPos);
}

void PS(float2 iTexCoord : TEXCOORD0,
    float2 iScreenPos : TEXCOORD1,
    out float4 oColor : COLOR0)
{
    oColor = EncodeHDR(texture2D(sDiffMap, iScreenPos));
}
