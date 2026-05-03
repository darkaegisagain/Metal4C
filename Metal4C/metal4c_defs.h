//
//  metal4c_defs.h
//  Metal4C
//
//  Created by Michael Larson on 3/17/26.
//

#ifndef metal4c_defs_h
#define metal4c_defs_h

#ifndef metal4c_types_h
#include "metal4c_types.h"
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

#define BUFFER_MASK_BIT(_buf)        (0x1 << _buf)

#if 0
typedef enum MTCap {
    MTCapDepthTest = 0,
    MTCapStencilTest,
} MTCap;

typedef enum MTCompareFunction {
    MTCompareFunctionNever = 0,
    MTCompareFunctionLess = 1,
    MTCompareFunctionEqual = 2,
    MTCompareFunctionLessEqual = 3,
    MTCompareFunctionGreater = 4,
    MTCompareFunctionNotEqual = 5,
    MTCompareFunctionGreaterEqual = 6,
    MTCompareFunctionAlways = 7,
} MTCompareFunction;

typedef enum MTStencilOperation {
    MTStencilOperationKeep = 0,
    MTStencilOperationZero = 1,
    MTStencilOperationReplace = 2,
    MTStencilOperationIncrementClamp = 3,
    MTStencilOperationDecrementClamp = 4,
    MTStencilOperationInvert = 5,
    MTStencilOperationIncrementWrap = 6,
    MTStencilOperationDecrementWrap = 7,
} MTStencilOperation;

typedef enum MTStencilBuffer {
    MTStencilFrontBuffer = 0,
    MTStencilBackBuffer = 1
} MTStencilBuffer;

typedef enum MTStencilBufferOperation {
    MTStencilFailureOp = 0,
    MTDepthFailureOp = 1,
    MTDepthStencilPassOp = 2,
} MTStencilBufferOperation;

typedef enum MTCullMode {
    MTCullModeNone = 0,
    MTCullModeFront = 1,
    MTCullModeBack = 2,
} MTCullMode;

typedef enum MTWinding {
    MTWindingClockwise = 0,
    MTWindingCounterClockwise = 1,
} MTWinding;

typedef enum MTDepthClipMode {
    MTDepthClipModeClip = 0,
    MTDepthClipModeClamp = 1,
} MTDepthClipMode;

typedef enum MTTriangleFillMode {
    MTTriangleFillModeFill = 0,
    MTTriangleFillModeLines = 1,
} MTTriangleFillMode;

#if 0
typedef enum MTTextureParam {
    MTTextureSampleCount      = 0,
    MTTextureResourceOptions,
    MTTextureCPUCacheMode,
    MTTextureStorageMode,
    MTTextureUsage,
    MTTextureAllowGPUOptimizedContents,
    MTTextureCompressionType,
    MTTextureSliceRange,
    MTTextureSwizzleChannels,
} MTTextureParam;
#endif

#endif


#endif /* metal4c_defs_h */
