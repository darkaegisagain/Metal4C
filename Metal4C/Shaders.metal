/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#include "ShaderTypes.h"

// data structs passed between vertex shader and fragment shader
struct RasterizerDataColor
{
    float4 position [[position]];
    float4 color;
    float point_size [[point_size]];
};

struct RasterizerDataTex
{
    float4 position [[position]];
    float2 st;
    float point_size [[point_size]];
};

struct RasterizerDataNormal
{
    float4 position [[position]];
    float3 normal;
    float point_size [[point_size]];
};

struct RasterizerDataColorTex
{
    float4 position [[position]];
    float4 color;
    float2 st;
    float point_size [[point_size]];
};

struct RasterizerDataColorNormal
{
    float4 position [[position]];
    float4 color;
    float3 normal;
    float point_size [[point_size]];
};

struct RasterizerDataTexNormal
{
    float4 position [[position]];
    float3 normal;
    float2 st;
    float point_size [[point_size]];
};

struct RasterizerDataColorTexNormal
{
    float4 position [[position]];
    float4 color;
    float2 st;
    float3 normal;
    float point_size [[point_size]];
};

float4 genericVertexProcessing(float4 position, constant UploadedState *uploaded_state)
{
    float4 ret_position;
    
    float2 pixelSpacePosition = position.xy;
    float2 viewportSize = uploaded_state->viewport_size;
    
    ret_position = simd_float4(0.0, 0.0, 0.0, 1.0);
    ret_position.xy = float2(-1.0, -1.0) + pixelSpacePosition / (viewportSize / 2);
    
    return ret_position;
}

float getPointSize(constant UploadedState *uploaded_state)
{
    float point_size;
    
    // not sure if I have to set the point size for lines 
    if (uploaded_state->prim_type == PrimitiveTypePoint)
    {
        point_size = uploaded_state->point_size;
    }
    else
    {
        point_size = 1.0;
    }
    
    return point_size;
}

// ****************************************************************************************************
// Color out vertex Function
// ****************************************************************************************************
vertex RasterizerDataColor
vertexShaderColor(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                    constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                    uint vertexID [[ vertex_id ]])
{
    RasterizerDataColor out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    // use the vertex color
    out.color = vertexArray[vertexID].color;
    out.point_size = 10.0;
    
    return out;
}

// Color only Fragment function
fragment float4
fragmentShaderColor(RasterizerDataColor in [[stage_in]])
{
    return float4(in.color);
}


// ****************************************************************************************************
// Tex Vertex Function
// ****************************************************************************************************
vertex RasterizerDataTex
vertexShaderTex(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                    constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                    uint vertexID [[ vertex_id ]])
{
    RasterizerDataTex out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.st = vertexArray[vertexID].st[0];

    return out;
}

// Fragment function
fragment float4
fragmentShaderTex(RasterizerDataTex in [[stage_in]],
                  texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample);
}

// ****************************************************************************************************
// Normal Vertex Function
// ****************************************************************************************************
vertex RasterizerDataNormal
vertexShaderNormal(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                    constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                    uint vertexID [[ vertex_id ]])
{
    RasterizerDataNormal out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.normal = vertexArray[vertexID].normal[0];

    return out;
}

// Fragment function
fragment float4
fragmentShaderNormal(RasterizerDataNormal in [[stage_in]],
                  texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    // return the color of the texture
    return float4(in.normal.x, in.normal.y, in.normal.z, 1.0);
}

// ****************************************************************************************************
// Color Tex Vertex Function
// ****************************************************************************************************
vertex RasterizerDataColorTex
vertexShaderColorTex(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                    constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                    uint vertexID [[ vertex_id ]])
{
    RasterizerDataColorTex out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.color = vertexArray[vertexID].color;
    out.st = vertexArray[vertexID].st[0];

    return out;
}

// Fragment function
fragment float4
fragmentShaderColorTex(RasterizerDataColorTex in [[stage_in]],
                  texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample) * in.color;
}

// ****************************************************************************************************
// Color Normal Vertex Function
// ****************************************************************************************************
vertex RasterizerDataColorNormal
vertexShaderColorNormal(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                    constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                    uint vertexID [[ vertex_id ]])
{
    RasterizerDataColorNormal out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.color = vertexArray[vertexID].color[0];
    out.normal = vertexArray[vertexID].normal[0];

    return out;
}

// Fragment function
fragment float4
fragmentShaderColorNormal(RasterizerDataColorNormal in [[stage_in]],
                  texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    return in.color * float4(in.normal.x, in.normal.y, in.normal.z, 1.0);
}

// ****************************************************************************************************
// Tex Normal Vertex Function
// ****************************************************************************************************
vertex RasterizerDataTexNormal
vertexShaderTexNormal(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                    constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                    uint vertexID [[ vertex_id ]])
{
    RasterizerDataTexNormal out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.st = vertexArray[vertexID].st[0];
    out.normal = vertexArray[vertexID].normal[0];

    return out;
}

// Fragment function
fragment float4
fragmentShaderTexNormal(RasterizerDataTexNormal in [[stage_in]],
                  texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample) * float4(in.normal.x, in.normal.y, in.normal.z, 1.0);
}

// ****************************************************************************************************
// Color Tex Normal Vertex Function
// ****************************************************************************************************
vertex RasterizerDataColorTexNormal
vertexShaderColorTexNormal(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                    constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                    uint vertexID [[ vertex_id ]])
{
    RasterizerDataColorTexNormal out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.color = vertexArray[vertexID].color[0];
    out.st = vertexArray[vertexID].st[0];
    out.normal = vertexArray[vertexID].normal[0];

    return out;
}

// Fragment function
fragment float4
fragmentShaderColorTexNormal(RasterizerDataColorTexNormal in [[stage_in]],
                  texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample) * float4(in.normal.x, in.normal.y, in.normal.z, 1.0);
}

