//
//  metal4c_shader_types.h
//  Metal4C
//
//  Created by Michael Larson on 2/10/26.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef enum MTPrimitiveType {
    MTPrimitiveTypePoint          = 0,
    MTPrimitiveTypeLine           = 1,
    MTPrimitiveTypeLineStrip      = 2,
    MTPrimitiveTypeTriangle       = 3,
    MTPrimitiveTypeTriangleStrip  = 4,
    MTPrimitiveTypeNone,
} MTPrimitiveType;

typedef enum MTPritiveDrawStyle {
    MTPrimitveDrawArray           = 0,
    MTPrimitveDrawArrayInstance,
    MTPrimitveDrawIndex,
    MTPrimitveDrawIndexInstance,
    MTPrimitveDrawIndexInstanceBase,
    MTPrimitveDrawIndexOffsetInstanceBase,
} MTPritiveDrawStyle;

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum VertexInputIndex
{
    VertexInputIndexVertices         = 0,
    VertexInputIndexUploadedState    = 1,
    VertexInputIndexInstanceArray    = 2,
} VertexInputIndex;

// Texture index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API texture set calls
typedef enum TextureIndex
{
    BaseColor               = 0,
    TextureIndexBaseColor   = 1,
} TextureIndex;

typedef struct
{
    vector_float2       viewport_size;
    unsigned            prim_type;
    float               point_size;
    matrix_float4x4     mvp_matrix;
} UploadedState;

typedef struct
{
    vector_float4       pos;
    vector_float4       color;
    vector_float2       st;
    vector_float4       rot;
    vector_float2       pad;
} InstanceState;

typedef struct
{
    vector_float2 position;
    simd_float4 color;
} Vertex2Color;

typedef struct
{
    vector_float2 position;
    vector_float2 st;
} Vertex2Tex;

typedef struct
{
    vector_float2 position;
    simd_float4 color;
    vector_float2 st;
} Vertex2ColorTex;

typedef simd_float4 MTVec4;
typedef vector_float2 MTVec2;
typedef simd_float4 MTColor;
typedef simd_float4 MTTexCord;

typedef struct
{
    MTVec4      position;
    MTColor     color;
    MTVec4      normal;
    MTVec2      st[8];
} Vertex4ColorNormalTex;


#endif /* ShaderTypes_h */
