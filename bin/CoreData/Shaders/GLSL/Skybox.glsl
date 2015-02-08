#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"

varying vec3 vTexCoord;
uniform float cAmbientHDRScale;

#define DecodeHDR(IN) DecodeBGRM8((IN))

vec4 DecodeBGRM8(in vec4 rgbm)
{
    vec4 r;
    const float MaxRange = 20.0f;
    const float MaxValue = 255.0f * MaxRange;
    const float scale = 1.0f / log2(MaxValue);
    float M = exp2(rgbm.a / scale);
    float m = M / (255.0f * 255.0f);
    r.rgb = rgbm.rgb * m;
    r.a = M;
    return r;
}

vec4 DecodeBGRE8(in vec4 rgbe)
{
    vec4 r;
    r.a = rgbe.a * 255 - 128;
    r.rgb = rgbe.rgb * exp2(r.a);
    r.a = length(r.rgb);
    return r;
}

vec4 DecodeBGRD8(in vec4 rgbd)
{
    vec4 r;
    const float MaxRange = 20.0f;
    const float MaxValue = 255.0f * MaxRange;
    const float scale = 1.0f / log2(MaxValue);
    float D = MaxValue / exp2(rgbd.a / scale);
    float d = D / (255.0f * 255.0f);
    r.rgb = rgbd.rgb * d;
    r.a = D;
    return r;
}

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);

    #ifndef GL_ES
    gl_Position.z = gl_Position.w;
    #else
    // On OpenGL ES force Z slightly in front of far plane to avoid clipping artifacts due to inaccuracy
    gl_Position.z = 0.999 * gl_Position.w;
    #endif
    vTexCoord = iPos.xyz;
}

void PS()
{
    vec4 sky = DecodeHDR(textureCube(sDiffCubeMap, vTexCoord.xyz));
    sky.rgb *= sky.a;
    sky.rgb *= cAmbientHDRScale;
    gl_FragColor = (cMatDiffColor * sky);
}
