//
//  metal4c_textures.c
//  Metal4C
//
//  Created by Michael Larson on 2/28/26.
//


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "metal4c.h"
#include "metal4c_context.h"
#include "metal4c_hash_table.h"

MTuint mtCreateTextureDesc(void)
{
    MTuint name;
    
    name = getNewName(STATE(texture_desc_table));
    MTTextureDesc   *desc;
    
    desc = newPtr(MTTextureDesc);
    zeroPtr(desc, MTTextureDesc);
    
    insertHashElement(STATE(texture_desc_table), name, desc);
    
    return name;
}

void mtDeleteTextureDesc(MTuint name)
{
    if (name == 0)
    {
        // quietly return
        return;
    }
    
    MTTextureDesc   *desc;
    
    desc = getKeyData(STATE(texture_desc_table), name);
    
    if (desc == NULL)
    {
        mtWarningFunc("invalid texture desc", __FUNCTION__);
        return;
    }

    free(desc);
    
    deleteHashElement(STATE(texture_desc_table), name);
}


static MTTextureDesc *getTexDesc(MTuint name, const char *func)
{
    MTTextureDesc *desc;

    desc = getKeyData(STATE(texture_desc_table), name);
    
    if (desc == NULL)
    {
        mtWarningFunc("invalid texture desc", func);
    }

    return desc;
}

static MTbool validTextureType(MTTextureType type)
{
    if ((type >= MTTextureType1D) && (type <= MTTextureTypeTextureBuffer))
    {
        return true;
    }
    
    return false;
}

static MTbool validPixelFormat(MTPixelFormat type)
{
    if ((type >= MTPixelFormatA8Unorm) && (type <= MTPixelFormatX24_Stencil8))
    {
        // there are a lot of holes in the MTPixelFormat enum table...
        return true;
    }
    
    return false;
}

static MTbool validCPUCacheMode(MTCPUCacheMode mode)
{
    switch(mode)
    {
        case MTCPUCacheModeDefaultCache:
        case MTCPUCacheModeWriteCombined:
            return true;
    }
    
    return false;
}

static MTbool validStorageMode(MTStorageMode mode)
{
    switch(mode)
    {
        case MTStorageModeShared:
        case MTStorageModeManaged:
        case MTStorageModePrivate:
        case MTStorageModeMemoryless:
            return true;
    }
    
    return false;
}

static MTbool validHazardTrackingMode(MTHazardTrackingMode mode)
{
    switch(mode)
    {
        case MTHazardTrackingModeDefault:
        case MTHazardTrackingModeUntracked:
        case MTHazardTrackingModeTracked:
            return true;
    }
    
    return false;
}

static MTbool validResourceOption(MTResourceOptions option)
{
    switch(option)
    {
        case MTResourceCPUCacheModeDefaultCache:
        case MTResourceCPUCacheModeWriteCombined:
        //case MTResourceStorageModeShared:
        case MTResourceStorageModeManaged:
        case MTResourceStorageModePrivate:
        case MTResourceStorageModeMemoryless:
        //case MTResourceHazardTrackingModeDefault:
        case MTResourceHazardTrackingModeUntracked:
        case MTResourceHazardTrackingModeTracked:
            return true;
    }
    
    return false;
}

#if 0
static MTbool validTextureSwizzle(MTTextureSwizzle mode)
{
    switch(mode)
    {
        case MTTextureSwizzleZero:
        case MTTextureSwizzleOne:
        case MTTextureSwizzleRed:
        case MTTextureSwizzleGreen:
        case MTTextureSwizzleBlue:
        case MTTextureSwizzleAlpha:
            return true;
    }
    
    return false;
}
#endif

static MTbool validTextureUsage(MTTextureUsage mode)
{
    switch(mode)
    {
        case MTTextureUsageUnknown:
        case MTTextureUsageShaderRead:
        case MTTextureUsageShaderWrite:
        case MTTextureUsageRenderTarget:
        case MTTextureUsagePixelFormatView:
        case MTTextureUsageShaderAtomic:
            return true;
    }
    
    return false;
}

static MTbool validCompressionType(MTTextureCompressionType mode)
{
    switch(mode)
    {
        case MTTextureCompressionTypeLossless:
        case MTTextureCompressionTypeLossy:
            return true;
    }
    
    return false;
}

static MTbool validSparsePageSize(MTSparsePageSize mode)
{
    switch(mode)
    {
        case MTSparsePageSize16:
        case MTSparsePageSize64:
        case MTSparsePageSize256:
            return true;
    }
    
    return false;
}

void mtSetTexDescParam(MTuint name, MTenum pname, MTuint param)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc == NULL)
    {
        return;
    }
    
    switch((MTTextureDescParam)pname)
    {
        case MTTextureParamTextureType:
            validTextureType(param) ? desc->texture_type = param : 0;
            break;
            
        case MTTextureParamPixelFormat:
            validPixelFormat(param) ? desc->format = param : 0;
            desc->format = param;
            break;

        case MTTextureParamWidth:
            desc->width = param;
            break;

        case MTTextureHParameight:
            desc->height = param;
            break;

        case MTTextureParamDepth:
            desc->depth = param;
            break;

        case MTTextureParamMipmapLevelCount:
            desc->mipmap_level_count = param;
            break;

        case MTTextureParamSampleCount:
            desc->sample_count = param;
            break;

        case MTTextureParamArrayLength:
            desc->array_length = param;
            break;

        case MTTextureParamResourceOptions:
            validResourceOption(param) ? desc->resource_options = param : 0;
            break;

        case MTTextureParamCPUCacheMode:
            validResourceOption(param) ? desc->cpu_cache_mode = param : 0;
            desc->cpu_cache_mode = param;
            break;

        case MTTextureParamStorageMode:
            validStorageMode(param) ? desc->storage_mode = param : 0;
            desc->storage_mode = param;
            break;

        case MTTextureParamHazardTrackingMode:
            validHazardTrackingMode(param) ? desc->hazard_tracking_mode = param : 0;
            desc->hazard_tracking_mode = param;
            break;

        case MTTextureParamUsage:
            validTextureUsage(param) ? desc->usage = param : 0;
            desc->usage = param;
            break;

        case MTTextureParamAllowGPUOptimizedContents:
            desc->allow_gpu_optimized_contents = param ? true : false;
            break;

        case MTTextureParamCompressionType:
            validCompressionType(param) ? desc->compression_type = param : 0;
            desc->compression_type = param;
            break;

        case MTTextureParamSwizzle:
            mtWarningFunc("MTTextureParamSwizzle cannot be set with this function",  __FUNCTION__);
            return;

        case MTTextureParamPlacementSparsePageSize:
            validSparsePageSize(param) ? desc->placement_sparse_page_size = param : 0;
            desc->placement_sparse_page_size = param;
            break;
            
        default:
            mtWarningFunc("invalid pname",  __FUNCTION__);
            return;
    }
    
    return;
}

void mtSetTexDescResourceOptions(MTuint name, MTResourceOptions option)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc)
    {
        validResourceOption(option) ? desc->resource_options = option : 0;
    }
}

void mtSetTexDescCPUCacheMode(MTuint name, MTCPUCacheMode mode)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc)
    {
        validCPUCacheMode(mode) ? desc->cpu_cache_mode = mode : 0;
        desc->cpu_cache_mode = mode;
    }
}

void mtSetTexDescStorageMode(MTuint name, MTStorageMode mode)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc)
    {
        validStorageMode(mode) ? desc->storage_mode = mode : 0;
    }
}

void mtSetTexDescHazardTrackingMode(MTuint name, MTHazardTrackingMode mode)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc)
    {
        validHazardTrackingMode(mode) ? desc->hazard_tracking_mode = mode : 0;
    }
}

void mtSetTexDescTextureUsage(MTuint name, MTTextureUsage usage)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc)
    {
        validTextureUsage(usage) ? desc->usage = usage : 0;
    }
}

void mtSetTexDescAllowGPUOptimizedContents(MTuint name, MTbool enable)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc)
    {
        desc->allow_gpu_optimized_contents = enable;
    }
}

void mtSetTexDescSparsePageSize(MTuint name, MTSparsePageSize mode)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc)
    {
        validSparsePageSize(mode) ? desc->placement_sparse_page_size = mode : 0;
    }
}

void mtSetTexDescSwizzle(MTuint name, MTTextureSwizzleChannels swizzle)
{
    MTTextureDesc *desc;
    
    desc = getTexDesc(name, __FUNCTION__);

    if (desc == NULL)
    {
        return;
    }
    
   desc->swizzle = swizzle;
    
    return;
}

static MTbool checkDataPitchArgs(size_t src_pitch, void *data, const char *func)
{
    if (data)
    {
        if (src_pitch == 0)
        {
            mtWarningFunc("no src pitch given with data", __FUNCTION__);
            return false;
        }
    }
    else if(src_pitch)
    {
        mtWarningFunc("src pitch given with null data, no copy performed", __FUNCTION__);
    }

    return true;
}

static MTuint createTexFromDesc(MTTexture *tex, size_t src_pitch, void *data)
{
    _ctx->mt_render_funcs.mtlCreateTexture(_ctx, tex, src_pitch, data);

    if (tex->mtl_tex == NULL)
    {
        mtWarningFunc("%s failed to create texture", __FUNCTION__);
        free(tex);
        return 0;
    }
    
    MTuint name;
    
    name = getNewName(STATE(texture_table));
    insertHashElement(STATE(texture_table), name, tex);
    
    tex->name = name;
    
    return name;
}

static void setCreateTexDesc(MTTexture *tex, MTTextureType type, MTPixelFormat format,
                             MTuint width, MTuint height, MTuint depth,
                             MTbool mipmapped, MTuint array_length)
{
    tex->desc.texture_type  = type;
    tex->desc.format        = format;
    tex->desc.width         = width;
    tex->desc.height        = height;
    tex->desc.depth         = depth;
    tex->desc.mipmapped     = mipmapped;
    tex->desc.array_length  = array_length;
}

MTuint mtCreateTexture1D(MTuint format, MTuint width, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureType1D, format, width, 1, 1, 0, 0);

    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTexture2D(MTuint format, MTuint width, MTuint height, MTbool mipmapped, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureType2D, format, width, height, 1, mipmapped, 0);

    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTexture3D(MTuint format, MTuint width, MTuint height, MTuint depth, MTbool mipmapped, size_t src_pitch, void *data)
{
    MTTexture *tex;

    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureType3D, format, width, height, depth, mipmapped, 0);

    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTexture1DArray(MTuint format, MTuint width, MTuint array_length, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureType1DArray, format, width, 1, 1, 0, array_length);

    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTexture2DArray(MTuint format, MTuint width, MTuint height, MTbool mipmapped, MTuint array_length, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureType2DArray, format, width, height, 1, mipmapped, array_length);
    
    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTexture2DMultiSampled(MTuint format, MTuint width, MTuint height, MTuint sample_count, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureType2DMultisample, format, width, height, 0, false, 1);
    tex->desc.sample_count = sample_count;
    
    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTexture2DMultiSampledArray(MTuint format, MTuint width, MTuint height, MTuint sample_count, MTuint array_length, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureType2DMultisampleArray, format, width, height, 0, false, array_length);
    tex->desc.sample_count = sample_count;

    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTextureCube(MTuint format, MTuint width, MTbool mipmapped, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureTypeCube, format, width, 1, 1, 0, 0);

    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTextureCubeArray(MTuint format, MTuint width, MTbool mipmapped, MTuint array_length, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureTypeCubeArray, format, width, 1, 1, 0, array_length);
    
    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTextureBuffer(MTuint format, MTuint width, MTResourceOptions options, MTTextureUsage usage, size_t src_pitch, void *data)
{
    if (checkDataPitchArgs(src_pitch, data, __FUNCTION__) == false)
    {
        return 0;
    }
    
    MTTexture *tex;

    tex = newPtr(MTTexture);
    
    // setCreateTexDesc(tex, type, format, width, height, depth, mipmapped, array_length)
    setCreateTexDesc(tex, MTTextureTypeTextureBuffer, format, width, 1, 1, 0, 0);
    
    tex->desc.resource_options = options;
    tex->desc.usage = usage;
    
    return createTexFromDesc(tex, src_pitch, data);
}

MTuint mtCreateTextureFromDesc(MTuint desc_name, MTsizei src_pitch, void *data)
{
    if (data)
    {
        if (src_pitch == 0)
        {
            mtWarningFunc("data given without src pitch", __FUNCTION__);
            return 0;
        }
    }
    else if (src_pitch)
    {
        mtWarningFunc("src_pitch given without data, no data copied", __FUNCTION__);
        data = NULL;
    }
    
    MTTextureDesc *desc;
    
    desc = getTexDesc(desc_name, __FUNCTION__);

    if (desc == NULL)
    {
        return 0;
    }

    MTTexture *tex;
    
    tex = newPtr(MTTexture);
    
    _ctx->mt_render_funcs.mtlCreateTextureFromDesc(_ctx, tex, desc, src_pitch, data);

    if (tex->mtl_tex == NULL)
    {
        mtWarningFunc("metal texture creation failed", __FUNCTION__);
        
        return 0;
    }
    
    MTuint name;
    
    name = getNewName(STATE(texture_table));
    
    insertHashElement(STATE(texture_table), name, tex);
        
    return name;
}

// mtCreateTextureFromFile will try to load a file from a path
// if it fails from the path directly it will try to load it as a NSBundle file
MTuint mtCreateTextureFromFile(const char *path)
{
    MTTexture *tex;
    
    tex = newPtr(MTTexture);
    
    _ctx->mt_render_funcs.mtlCreateTextureFromPath(_ctx, tex, path);

    if (tex->mtl_tex == NULL)
    {
        mtWarningFunc("failed to create texture", __FUNCTION__);
        free(tex);
        return 0;
    }
    
    MTuint name;
    
    name = getNewName(STATE(texture_table));
    insertHashElement(STATE(texture_table), name, tex);
    
    tex->name = name;
    
    return name;

}

MTuint mtCreateTextureDescWithPixelFormat(MTPixelFormat format, MTuint width, MTuint height, MTbool mipmapped)
{
    MTuint name;
    
    name = mtCreateTextureDesc();
    
    MTTextureDesc *desc;
    
    desc = getKeyData(STATE(texture_desc_table), name);
    
    desc->format = format;
    desc->width = width;
    desc->height = height;
    desc->mipmapped = mipmapped;
 
    MTuint error;
    
    _ctx->mt_render_funcs.mtlTextureDescWithPixelFormat(_ctx, desc, &error);
    
    if (error)
    {
        deleteHashElement(STATE(texture_desc_table), name);
        
        return 0;
    }
    
    return name;
}

MTuint mtCreateTextureCubeDescWithPixelFormat(MTPixelFormat format, MTuint size, MTbool mipmapped)
{
    MTuint name;
    
    name = mtCreateTextureDesc();
    
    MTTextureDesc *desc;
    
    desc = getKeyData(STATE(texture_desc_table), name);
    
    desc->format = format;
    desc->width = size;
    desc->mipmapped = mipmapped;

    MTuint error;
    
    _ctx->mt_render_funcs.mtlTextureCubeDescWithPixelFormat(_ctx, desc, &error);

    if (error)
    {
        deleteHashElement(STATE(texture_desc_table), name);
        
        return 0;
    }
    
    return name;
}

MTuint mtCreateTextureBufferDescWithPixelFormat(MTPixelFormat format, MTuint width, MTResourceOptions options, MTTextureUsage usage)
{
    if (validTextureUsage(usage))
    {
        if(usage == MTTextureUsageUnknown)
        {
            mtWarningFunc("Texture buffers require read or write useage", __FUNCTION__);
            return 0;
        }
    }
    
    MTuint name;
    
    name = mtCreateTextureDesc();
    
    MTTextureDesc *desc;
    
    desc = getKeyData(STATE(texture_desc_table), name);
    
    desc->format = format;
    desc->width = width;
    desc->resource_options = options;
    desc->usage = usage;
    
    MTuint error;
    
    _ctx->mt_render_funcs.mtlTextureBufferDescWithPixelFormat(_ctx, desc, &error);

    if (error)
    {
        deleteHashElement(STATE(texture_desc_table), name);
        
        return 0;
    }
    
    return name;
}

void mtDeleteTexture(MTuint name)
{
    if (name == 0)
    {
        // quietly return
        return;
    }
    
    MTTexture *tex;
    
    tex = getKeyData(STATE(texture_table), name);
    
    if(tex == NULL)
    {
        mtWarningFunc("Invalid texture", __FUNCTION__);
        
        return;
    }
    
    if (tex->mtl_tex)
    {
        _ctx->mt_render_funcs.mtlCFBridgingRelease(tex->mtl_tex);
        tex->mtl_tex = NULL;
    }
    
    free(tex);
    
    deleteHashElement(STATE(texture_table), name);
}

void mtBindVertexTexture(MTuint name, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("%s name > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    if (name)
    {
        STATE(enabled_vertex_textures) |= (0x1 << unit);
    }
    else
    {
        STATE(enabled_vertex_textures) &= ~(0x1 << unit);
    }
    
    STATE(vertex_textures[unit]) = name;
    _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
}

void mtBindFragmentTexture(MTuint name, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("%s name > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    if (name)
    {
        STATE(enabled_fragment_textures) |= (0x1 << unit);
    }
    else
    {
        STATE(enabled_fragment_textures) &= ~(0x1 << unit);
    }
    
    STATE(fragment_textures[unit]) = name;
    _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
}

void mtTexSubImage(MTuint tex, MTuint src_format, MTuint x, MTuint y, MTuint width, MTuint height)
{
    assert(0);
}

