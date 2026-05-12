//
//  metal4c_shaders.metal
//  Metal4C
//
//  Created by Michael Larson on 2/21/26.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#include "metal4c_shader_types.h"

struct RasterizerData
{
    float4 position [[position]];
    float4 color;
    float2 st;
    float4 normal;
    float point_size [[point_size]];
};

float4 genericVertexProcessing(float4 position, constant UploadedState *uploaded_state)
{
    float4 ret_position;

    ret_position = uploaded_state->mvp_matrix * position;
    
    return ret_position;
}

float getPointSize(constant UploadedState *uploaded_state)
{
    float point_size;
    
    // not sure if I have to set the point size for lines 
    if (uploaded_state->prim_type == MTPrimitiveTypePoint)
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
// Vertex Function
// ****************************************************************************************************
vertex RasterizerData
vertexShader(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
             constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
             uint vertexID [[ vertex_id ]])
{
    RasterizerData out;
    
    out.position = genericVertexProcessing(vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.color = vertexArray[vertexID].color;
    out.st = vertexArray[vertexID].st[0];
    out.normal = vertexArray[vertexID].normal;

    return out;
}

vertex RasterizerData
vertexShaderInstanced(constant Vertex4ColorNormalTex *vertexArray [[ buffer(VertexInputIndexVertices) ]],
                      constant UploadedState *uploaded_state  [[ buffer(VertexInputIndexUploadedState) ]],
                      constant InstanceState *instance_array  [[ buffer(VertexInputIndexInstanceArray) ]],
                      uint vertexID [[ vertex_id ]],
                      uint instanceID [[ instance_id]])
{
    RasterizerData out;
    
    out.position = genericVertexProcessing(instance_array[instanceID].pos + vertexArray[vertexID].position, uploaded_state);
    out.point_size = getPointSize(uploaded_state);

    out.color = vertexArray[vertexID].color;
    out.st = vertexArray[vertexID].st[0];
    out.normal = vertexArray[vertexID].normal;

    return out;
}

// ****************************************************************************************************
// Fragment functions
// ****************************************************************************************************
fragment float4
fragmentShaderColor(RasterizerData in [[stage_in]])
{
    return float4(in.color.x, in.color.y, in.color.z, in.color.w);
}

fragment float4
fragmentShaderNormal(RasterizerData in [[stage_in]])
{
    return float4(in.normal.x, in.normal.y, in.normal.z, 1.0);
}

fragment float4
fragmentShaderColorNormal(RasterizerData in [[stage_in]])
{
    float4 n = float4(in.normal.x, in.normal.y, in.normal.z, 1.0);
    float4 c = float4(in.color.x, in.color.y, in.color.z, 1.0);
    
    return n * c;
}

fragment float4
fragmentShaderTexture(RasterizerData in [[stage_in]],
                      texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample);
}

fragment float4
fragmentShaderColorTexture(RasterizerData in [[stage_in]],
                      texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    float4 c = float4(in.color.x, in.color.y, in.color.z, 1.0);

    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample) * c;
}

fragment float4
fragmentShaderNormalTexture(RasterizerData in [[stage_in]],
                      texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    float4 n = float4(in.normal.x, in.normal.y, in.normal.z, 1.0);

    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample) *n;
}

fragment float4
fragmentShaderColorNormalTexture(RasterizerData in [[stage_in]],
                      texture2d<half> colorTexture [[ texture(TextureIndexBaseColor) ]])
{
    float4 n = float4(in.normal.x, in.normal.y, in.normal.z, 1.0);
    float4 c = float4(in.color.x, in.color.y, in.color.z, 1.0);

    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    // Sample the texture to obtain a color
    const half4 colorSample = colorTexture.sample(textureSampler, in.st);

    // return the color of the texture
    return float4(colorSample) * n * c;
}

