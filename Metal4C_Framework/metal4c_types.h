//
//  MTTypes.h
//  Metal4C
//
//  Created by Michael Larson on 3/24/26.
//

#ifndef metal4c_types_h
#define metal4c_types_h

#ifndef metal4c_formats_h
#include "metal4c_formats.h"
#endif

typedef unsigned int    MTuint;
typedef int             MTint;
typedef float           MTfloat;
typedef double          MTdouble;

typedef unsigned int    MTbitfield;
typedef size_t          MTintptr;
typedef unsigned int    MTenum;
typedef size_t          MTsizeiptr;
typedef size_t          MTsizei;
typedef _Bool           MTbool;

typedef MTuint          MTRenderContext;

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

typedef enum MTIndexType {
    MTIndexTypeUInt16 = 0,
    MTIndexTypeUInt32 = 1,
} MTIndexType;

typedef enum MTTextureType
{
    MTTextureType1D = 0,
    MTTextureType1DArray = 1,
    MTTextureType2D = 2,
    MTTextureType2DArray = 3,
    MTTextureType2DMultisample = 4,
    MTTextureTypeCube = 5,
    MTTextureTypeCubeArray = 6,
    MTTextureType3D = 7,
    MTTextureType2DMultisampleArray = 8,
    MTTextureTypeTextureBuffer = 9
} MTTextureType;

typedef enum MTCPUCacheMode
{
    MTCPUCacheModeDefaultCache = 0,
    MTCPUCacheModeWriteCombined = 1,
} MTCPUCacheMode;

typedef enum MTStorageMode
{
    MTStorageModeShared  = 0,
    MTStorageModeManaged  = 1,
    MTStorageModePrivate = 2,
    MTStorageModeMemoryless  = 3,
} MTStorageMode;

typedef enum MTHazardTrackingMode
{
    MTHazardTrackingModeDefault = 0,
    MTHazardTrackingModeUntracked = 1,
    MTHazardTrackingModeTracked = 2,
} MTHazardTrackingMode;

#define MTResourceCPUCacheModeShift            0
#define MTResourceCPUCacheModeMask             (0xfUL << MTResourceCPUCacheModeShift)

#define MTResourceStorageModeShift             4
#define MTResourceStorageModeMask              (0xfUL << MTResourceStorageModeShift)

#define MTResourceHazardTrackingModeShift      8
#define MTResourceHazardTrackingModeMask       (0x3UL << MTResourceHazardTrackingModeShift)

typedef enum MTResourceOptions
{
    MTResourceCPUCacheModeDefaultCache  = MTCPUCacheModeDefaultCache  << MTResourceCPUCacheModeShift,
    MTResourceCPUCacheModeWriteCombined = MTCPUCacheModeWriteCombined << MTResourceCPUCacheModeShift,

    MTResourceStorageModeShared  = MTStorageModeShared << MTResourceStorageModeShift,
    MTResourceStorageModeManaged = MTStorageModeManaged << MTResourceStorageModeShift,
    MTResourceStorageModePrivate = MTStorageModePrivate << MTResourceStorageModeShift,
    MTResourceStorageModeMemoryless  = MTStorageModeMemoryless << MTResourceStorageModeShift,
    
    MTResourceHazardTrackingModeDefault  = MTHazardTrackingModeDefault << MTResourceHazardTrackingModeShift,
    MTResourceHazardTrackingModeUntracked = MTHazardTrackingModeUntracked << MTResourceHazardTrackingModeShift,
    MTResourceHazardTrackingModeTracked = MTHazardTrackingModeTracked << MTResourceHazardTrackingModeShift,
} MTResourceOptions;

typedef enum MTTextureSwizzle {
    MTTextureSwizzleZero = 0,
    MTTextureSwizzleOne = 1,
    MTTextureSwizzleRed = 2,
    MTTextureSwizzleGreen = 3,
    MTTextureSwizzleBlue = 4,
    MTTextureSwizzleAlpha = 5,
} MTTextureSwizzle;

typedef struct
{
    MTTextureSwizzle red;
    MTTextureSwizzle green;
    MTTextureSwizzle blue;
    MTTextureSwizzle alpha;
} MTTextureSwizzleChannels;

typedef enum MTTextureUsage
{
    MTTextureUsageUnknown         = 0x0000,
    MTTextureUsageShaderRead      = 0x0001,
    MTTextureUsageShaderWrite     = 0x0002,
    MTTextureUsageRenderTarget    = 0x0004,
    MTTextureUsagePixelFormatView = 0x0010,
    MTTextureUsageShaderAtomic = 0x0020,
} MTTextureUsage;

typedef enum MTTextureCompressionType
{
    MTTextureCompressionTypeLossless = 0,
    MTTextureCompressionTypeLossy = 1,
} MTTextureCompressionType;

typedef enum MTSparsePageSize
{
    MTSparsePageSize16 = 101,
    MTSparsePageSize64 = 102,
    MTSparsePageSize256 = 103,
} MTSparsePageSize;

typedef enum MTTextureDescParam {
    MTTextureParamTextureType    = 0,
    MTTextureParamPixelFormat,
    MTTextureParamWidth,
    MTTextureHParameight,
    MTTextureParamDepth,
    MTTextureParamMipmapLevelCount,
    MTTextureParamSampleCount,
    MTTextureParamArrayLength,
    MTTextureParamResourceOptions,
    MTTextureParamCPUCacheMode,
    MTTextureParamStorageMode,
    MTTextureParamHazardTrackingMode,
    MTTextureParamUsage,
    MTTextureParamAllowGPUOptimizedContents,
    MTTextureParamCompressionType,
    MTTextureParamSwizzle,
    MTTextureParamPlacementSparsePageSize,
} MTTextureDescParam;

typedef struct MTRange {
    MTuint      offset;
    MTuint      size;
} MTRange;

typedef struct MTTextureDesc {
    MTTextureType       texture_type;
    MTPixelFormat       format;
    MTuint              width;
    MTuint              height;
    MTuint              depth;
    MTbool              mipmapped;
    MTuint              mipmap_level_count;
    MTuint              sample_count;
    MTuint              array_length;
    MTResourceOptions   resource_options;
    MTCPUCacheMode      cpu_cache_mode;
    MTStorageMode               storage_mode;
    MTHazardTrackingMode        hazard_tracking_mode;
    MTTextureUsage              usage;
    MTbool                      allow_gpu_optimized_contents;
    MTTextureCompressionType    compression_type;
    MTTextureSwizzleChannels    swizzle;
    MTSparsePageSize            placement_sparse_page_size;
} MTTextureDesc;

typedef enum MTSamplerMinMagFilter {
    MTSamplerMinMagFilterNearest = 0,
    MTSamplerMinMagFilterLinear = 1,
} MTSamplerMinMagFilter;

typedef enum MTSamplerMipFilter {
    MTSamplerMipFilterNotMipmapped = 0,
    MTSamplerMipFilterNearest = 1,
    MTSamplerMipFilterLinear = 2,
} MTSamplerMipFilter;

typedef enum MTSamplerAddressMode {
    MTSamplerAddressModeClampToEdge = 0,
    MTSamplerAddressModeMirrorClampToEdge = 1,
    MTSamplerAddressModeRepeat = 2,
    MTSamplerAddressModeMirrorRepeat = 3,
    MTSamplerAddressModeClampToZero = 4,
    MTSamplerAddressModeClampToBorderColor = 5,
} MTSamplerAddressMode;

typedef enum MTSamplerBorderColor {
    MTSamplerBorderColorTransparentBlack = 0,  // {0,0,0,0}
    MTSamplerBorderColorOpaqueBlack = 1,       // {0,0,0,1}
    MTSamplerBorderColorOpaqueWhite = 2,       // {1,1,1,1}
} MTSamplerBorderColor;

/// Configures how the sampler aggregates contributing samples to a final value.
typedef enum MTSamplerReductionMode {
    /// A reduction mode that adds together the product of each contributing sample value by its weight.
    MTSamplerReductionModeWeightedAverage = 0,
    /// A reduction mode that finds the minimum contributing sample value by separately evaluating each channel.
    MTSamplerReductionModeMinimum = 1,
    /// A reduction mode that finds the maximum contributing sample value by separately evaluating each channel.
    MTSamplerReductionModeMaximum = 2,
} MTSamplerReductionMode;

typedef enum MTSamplerDescParam {
    MTSamplerParamMinFilter = 0,
    MTSamplerParamMaxFilter,
    MTSamplerParamMipFilter,
    MTSamplerParamMaxAnistropy,
    MTSamplerParamAddressMode_S,
    MTSamplerParamAddressMode_T,
    MTSamplerParamAddressMode_R,
    MTSamplerParamBoarderColor,
    MTSamplerParamNormallizedCoordinates,
    MTSamplerParamLodMinClamp,
    MTSamplerParamLodMaxClamp,
    MTSamplerParamLodAverage,
    MTSamplerParamLodBias,
    MTSamplerParamCompareFunction,
    MTSamplerParamSupportArgumentBuffers,
} MTSamperDescParam;

typedef struct MTSamplerDesc {
    MTSamplerMinMagFilter   min_filter;
    MTSamplerMinMagFilter   mag_filter;
    MTSamplerMipFilter      mip_filter;
    MTuint                  max_anisotropy;
    MTSamplerAddressMode    s_address_mode;
    MTSamplerAddressMode    t_address_mode;
    MTSamplerAddressMode    r_address_mode;
    MTSamplerBorderColor    boarder_color;
    MTbool                  normalized_coordinates;
    MTfloat                 lod_min_clamp;
    MTfloat                 lod_max_clamp;
    MTbool                  lod_average;
    MTfloat                 lod_bias;
    MTCompareFunction       compare_function;
    MTbool                  support_argument_buffers;
    MTPixelFormat           pixel_format;
} MTSamplerDesc;

#endif /* metal4c_types_h */
