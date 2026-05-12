//
//  LocalShaderTypes.h
//  Metal4C
//
//  Created by Michael Larson on 4/1/26.
//

#ifndef LocalShaderTypes_h
#define LocalShaderTypes_h

#include <simd/simd.h>

typedef struct
{
    vector_float4       pos;
    vector_float4       rot;
    vector_float4       vel;
    vector_float4       accel;
    vector_float4       color;
} LocalInstanceState;


#endif /* LocalShaderTypes_h */
