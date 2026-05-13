//
//  metal4c_defs.h
//  Metal4C
//
//  Created by Michael Larson on 3/17/26.
//

#ifndef metal4c_defs_h
#define metal4c_defs_h

#ifndef metal4c_types_h
#include <Metal4c/metal4c_types.h>
#endif

#define MAX_TEXTURE_UNITS               8
#define MAX_MODELVIEW_MATRIX_DEPTH      64
#define MAX_MATRIX_DEPTH                8
#define MAX_VERTEX_ATTIBS               8
#define MAX_BUFFER_BINDINGS             16

enum {
    kClearColorBuffer = 0,
    kClearDepthBuffer,
    kClearStencilBuffer,
};

#define MT_CLEAR_BUFFER_BIT(_bit_)  (0x1 << _bit_)
#define MT_CLEAR_COLOR_BUFFER       MT_CLEAR_BUFFER_BIT(kClearColorBuffer)
#define MT_CLEAR_DEPTH_BUFFER       MT_CLEAR_BUFFER_BIT(kClearDepthBuffer)
#define MT_CLEAR_STENCIL_BUFFER     MT_CLEAR_BUFFER_BIT(kClearStencilBuffer)

typedef enum MTVertexShaderMode {
    MTVertexShaderModeNonInstanced = 0,
    MTVertexShaderModeInstanced = 1,
    MTVertexShaderModeMax,
} MTVertexShaderMode;

typedef enum MTFragmentShaderMode {
    MTFragmentShaderModeColor = 0,
    MTFragmentShaderModeNormal,
    MTFragmentShaderModeColorNormal,
    MTFragmentShaderModeTexture,
    MTFragmentShaderModeColorTexture,
    MTFragmentShaderModeNormalTexture,
    MTFragmentShaderModeColorNormalTexture,
    MTFragmentShaderModeMax,
    MTFragmentShaderModeAll,
} MTFragmentShaderMode;

typedef enum MTMatrixMode {
    MTMatrixMode_ModelView = 0,
    MTMatrixMode_Projection,
    MTMatrixMode_Texture,
    MTMatrixMode_Color,
    MTMatrixMode_Max
} MTMatrixMode;

typedef enum MTPointerIndex {
    kVertexBuffer = 0,
    kColorBuffer,
    kNormalBuffer,
    kIndexBuffer,
    kTexCoodBuffer0,
    kAttributeBuffer0 = kTexCoodBuffer0 + MAX_TEXTURE_UNITS,
} MTPointerIndex;

typedef enum MTBufferFlags {
    kBufferSizeImmutable     = 0,
    kBufferDataImmutable,
} MTBufferFlags;

#define BUFFER_FLAG_BIT(_buffer_flag_)  (0x1 << _buffer_flag_)
#define BUFFER_SIZE_IMMUTABLE           BUFFER_FLAG_BIT(kBufferSizeImmutable)
#define BUFFER_DATA_IMMUTABLE           BUFFER_FLAG_BIT(kBufferDataImmutable)

#define BUFFER_MASK_BIT(_buf)           (0x1 << _buf)


#endif /* metal4c_defs_h */
