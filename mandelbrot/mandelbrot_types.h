//
//  mandelbrot_types.h
//  Metal4C
//
//  Created by Michael Larson on 5/13/26.
//

#ifndef mandelbrot_types_h
#define mandelbrot_types_h

enum {
    MandelbrotVertexInputIndexVertices = 0,
};

enum {
    MandelbrotFragmentInputIndexUploadedState = 0,
};

typedef struct
{
    vector_float2 position;
    vector_float2 st;
} MandelbrotVertex;

typedef struct {
    float min_x, min_y;
    float max_x, max_y;
} MBUniform;

#endif /* mandelbrot_types_h */
