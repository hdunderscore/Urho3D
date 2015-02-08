#line 2 "LuxUrhoMap.hlsl"
// Mapping between Urho defines and Lux defines


#define TYPES_HLSL
//#define TYPES_GLSL
//#define TYPES_HLSL_FLOATS

#ifdef TYPES_HLSL_FLOATS
    #define FLOAT1 float
    #define FLOAT2 float2
    #define FLOAT3 float3
    #define FLOAT4 float4
    #define FLOAT4x4 float4x4
    #define FLOAT4x3 float4x3
    #define FLOAT3x3 float3x3
    #define HALF1 FLOAT1
    #define HALF2 FLOAT2
    #define HALF3 FLOAT3
    #define HALF4 FLOAT4
    #define HALF4x4 FLOAT4x4
    #define HALF4x3 FLOAT4x3
    #define HALF3x3 FLOAT3x3
    #define FIXED1 FLOAT1
    #define FIXED2 FLOAT2
    #define FIXED3 FLOAT3
    #define FIXED4 FLOAT4
    #define FIXED4x4 FLOAT4x4
    #define FIXED4x3 FLOAT4x3
    #define FIXED3x3 FLOAT3x3
#endif

#ifdef TYPES_HLSL
    #define HALF1 half
    #define HALF2 half2
    #define HALF3 half3
    #define HALF4 half4
    #define HALF4x4 half4x4
    #define HALF4x3 half4x3
    #define HALF3x3 half3x3
    #define FIXED1 fixed
    #define FIXED2 fixed2
    #define FIXED3 fixed3
    #define FIXED4 fixed4
    #define FIXED4x4 fixed4x4
    #define FIXED4x3 fixed4x3
    #define FIXED3x3 fixed3x3
    #define FLOAT1 float
    #define FLOAT2 float2
    #define FLOAT3 float3
    #define FLOAT4 float4
    #define FLOAT4x4 float4x4
    #define FLOAT4x3 float4x3
    #define FLOAT3x3 float3x3
#endif

#ifdef TYPES_GLSL
    #define FLOAT1 float
    #define FLOAT2 vec2
    #define FLOAT3 vec3
    #define FLOAT4 vec4
    #define FLOAT4x4 mat4x4
    #define FLOAT4x3 mat4x3
    #define FLOAT3x3 mat3x3
    #define HALF1 FLOAT1
    #define HALF2 FLOAT2
    #define HALF3 FLOAT3
    #define HALF4 FLOAT4
    #define HALF4x4 FLOAT4x4
    #define HALF4x3 FLOAT4x3
    #define HALF3x3 FLOAT3x3
    #define FIXED1 FLOAT1
    #define FIXED2 FLOAT2
    #define FIXED3 FLOAT3
    #define FIXED4 FLOAT4
    #define FIXED4x4 FLOAT4x4
    #define FIXED4x3 FLOAT4x3
    #define FIXED3x3 FLOAT3x3
#endif

#define MUL(X,Y) mul(X,Y)

#define LUX_LINEAR true
#define NORMAL_IS_WORLDNORMAL true
#define SPECCUBE true
//#define BOXPROJECTION
#define DIFFCUBE

// #ifdef SM3
// #define
// #endif

#ifdef SHADOW
#define SHADOWS_NATIVE
#endif

#ifdef SHADOWCMP
#define SHADOWS_DEPTH
#endif

#ifdef POINTLIGHT
#define POINT
#endif

#ifdef CUBEMASK
#define POINT_COOKIE
#endif

#ifdef SPOTLIGHT
#define SPOT
#endif

#ifdef DIRLIGHT
#define DIRECTIONAL
#endif

#ifndef LIGHTMAP
#define LUX_LIGHTMAP_OFF
#endif

// #ifdef NORMALMAP
// #define
// #endif

// #ifdef SKINNED
// #define
// #endif

// #ifdef INSTANCED
// #define
// #endif

// #ifdef BILLBOARD
// #define
// #endif

// #ifdef ENVCUBEMAP
// #define DIFFCUBE_ON
// #else
// #define DIFFCUBE_OFF
// #endif

// #ifdef PERPIXEL
// #define
// #endif

// #ifdef DEFERRED
// #define
// #endif

// #ifdef PREPASS
// #define
// #endif

#ifdef AO
#define LUX_AO_ON
#else
#define LUX_AO_OFF
#endif

// #ifdef SPECULAR
// #define
// #endif

// #ifdef ALPHAMASK
// #define
// #endif

// #ifdef SPECMAP
// #define
// #endif

// #ifdef HEIGHTFOG
// #define
// #endif

// #ifdef AMBIENT
// #define
// #endif

// #ifdef EMISSIVEMAP
// #define
// #endif

// #ifdef MATERIAL
// #define
// #endif