//
//  ShaderTypes.h
//  Metal4C
//
//  Created by Michael Larson on 2/10/26.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef enum PrimitiveType {
    PrimitiveTypePoint          = 0,
    PrimitiveTypeLine           = 1,
    PrimitiveTypeLineStrip      = 2,
    PrimitiveTypeTriangle       = 3,
    PrimitiveTypeTriangleStrip  = 4,
    PrimitiveTypeNone,
} PrimitiveType;

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum VertexInputIndex
{
    VertexInputIndexVertices         = 0,
    VertexInputIndexUploadedState    = 1,
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
    vector_float2      viewport_size;
    unsigned           render_mode;
    unsigned           prim_type;
    float              point_size;
} UploadedState;

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
