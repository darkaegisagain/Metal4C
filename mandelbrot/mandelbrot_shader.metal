//
//  mandelbrot.metal
//  mandelbrot
//
//  Created by Michael Larson on 5/13/26.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#include "mandelbrot_types.h"

struct RasterizerData
{
    float4 position [[position]];
    float2 st;
};

// ****************************************************************************************************
// Vertex Function
// ****************************************************************************************************
vertex RasterizerData
mandelbrotVertexShader(constant MandelbrotVertex *vertexArray [[ buffer(MandelbrotVertexInputIndexVertices) ]],
             uint vertexID [[ vertex_id ]])
{
    RasterizerData out;
    
    out.position = float4(vertexArray[vertexID].position.x, vertexArray[vertexID].position.y, 0, 1.0);
    out.st = vertexArray[vertexID].st[0];

    return out;
}

fragment float4
mandelbrotFragmentShader(RasterizerData in [[stage_in]],
                         constant MBUniform *uploaded_state  [[ buffer(MandelbrotFragmentInputIndexUploadedState) ]],
                         texture2d<half> null_texture [[ texture(MandelbrotFragmentInputTextureIndex) ]])
{
    float dx, dy, x, y;
    
    dx = uploaded_state->max_x - uploaded_state->min_x;
    dy = uploaded_state->min_y - uploaded_state->min_y;

    x = uploaded_state->min_x + dx + in.st[0];
    y = uploaded_state->min_y + dy + in.st[1];

    return float4(in.st[0], in.st[1], 0, 1.0);
}


