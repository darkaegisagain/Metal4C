//
//  metal4c_samplers.c
//  Metal4C
//
//  Created by Michael Larson on 3/27/26.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "metal4c.h"
#include "metal4c_context.h"
#include "Renderer_Extern.h"
#include "hash_table.h"

MTuint mtCreateSamplerDesc(void)
{
    MTuint name;
    
    name = getNewName(STATE(sampler_desc_table));
    MTSamplerDesc   *desc;
    
    desc = newPtr(MTSamplerDesc);
    zeroPtr(desc, MTSamplerDesc);
    
    /*
     this is the default created by metal
     
     minFilter = MTLSamplerMinMagFilterNearest
     magFilter = MTLSamplerMinMagFilterNearest
     mipFilter = MTLSamplerMipFilterNotMipmapped
     maxAnisotropy = 1
     sAddressMode = MTLSamplerAddressModeClampToEdge
     tAddressMode = MTLSamplerAddressModeClampToEdge
     rAddressMode = MTLSamplerAddressModeClampToEdge
     normalizedCoordinates = 1
     borderColor = MTLSamplerBorderColorTransparentBlack
     borderColorcustomValue0 = 0
     borderColorcustomValue1 = 0
     borderColorcustomValue2 = 0
     borderColorcustomValue3 = 0
     forceSeamsOnCubemapFiltering = 0
     lodMinClamp = 0
     lodMaxClamp = 3.402823e+38
     lodAverage = 0
     compareFunction = MTLCompareFunctionNever
     supportArgumentBuffers = 0
     reductionMode = MTLSamplerReductionModeWeightedAverage
     forceResourceIndex = 0
     resourceIndex = 0
     pixelFormat = MTLPixelFormatInvalid
     */
        
    desc->min_filter        = MTSamplerMinMagFilterNearest;
    desc->mag_filter        = MTSamplerMinMagFilterNearest;
    desc->mip_filter        = MTSamplerMipFilterNotMipmapped;
    desc->max_anisotropy    = 1;
    desc->s_address_mode    = MTSamplerAddressModeClampToEdge;
    desc->t_address_mode    = MTSamplerAddressModeClampToEdge;
    desc->r_address_mode    = MTSamplerAddressModeClampToEdge;
    desc->boarder_color     = MTSamplerBorderColorOpaqueBlack;
    desc->lod_min_clamp     = 0.0;
    desc->lod_max_clamp     = 3.402823e+38;
    desc->lod_average       = 0;
    desc->compare_function  = MTCompareFunctionNever;
    desc->support_argument_buffers = 0;
    desc->pixel_format      = MTPixelFormatInvalid;

    insertHashElement(STATE(sampler_desc_table), name, desc);
    
    return name;
}

void mtDeleteSamplerDesc(MTuint name)
{
    if (name == 0)
    {
        // quietly return
        return;
    }
    
    MTSamplerDesc   *desc;
    
    desc = getKeyData(STATE(sampler_desc_table), name);
    
    if (desc == NULL)
    {
        mtWarningFunc("invalid sampler desc", __FUNCTION__);
        return;
    }

    free(desc);
    
    deleteHashElement(STATE(sampler_desc_table), name);
}


static MTSamplerDesc *getSamplerDesc(MTuint name, const char *func)
{
    MTSamplerDesc *desc;

    desc = getKeyData(STATE(sampler_desc_table), name);
    
    if (desc == NULL)
    {
        mtWarningFunc("invalid sampler desc", func);
    }

    return desc;
}

static MTbool validSamplerMinMaxFilter(MTuint param)
{
    switch(param)
    {
        case MTSamplerMinMagFilterNearest:
        case MTSamplerMinMagFilterLinear:
            return true;
    }
    
    return false;
}

static MTbool validSamplerMipFilter(MTuint param)
{
    switch(param)
    {
        case MTSamplerMipFilterNotMipmapped:
        case MTSamplerMipFilterNearest:
        case MTSamplerMipFilterLinear:
            return true;
    }
    
    return false;
}

static MTbool validSamplerAddressMode(MTuint param)
{
    switch(param)
    {
        case MTSamplerAddressModeClampToEdge:
        case MTSamplerAddressModeMirrorClampToEdge:
        case MTSamplerAddressModeRepeat:
        case MTSamplerAddressModeMirrorRepeat:
        case MTSamplerAddressModeClampToZero:
        case MTSamplerAddressModeClampToBorderColor:
            return true;
    }
    
    return false;
}

static MTbool validSamplerBorderColor(MTuint param)
{
    switch(param)
    {
        case MTSamplerBorderColorTransparentBlack:
        case MTSamplerBorderColorOpaqueBlack:
        case MTSamplerBorderColorOpaqueWhite:
            return true;
    }
    
    return false;
}

static void setSamplerDescParam(MTuint name, MTenum pname, MTuint param, const char *func)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(name, func);
    
    if (desc == NULL)
    {
        return;
    }
    
    switch(pname)
    {
        case MTSamplerParamMinFilter:
            validSamplerMinMaxFilter(param) ? desc->min_filter = (MTSamplerMinMagFilter)param : 0;
            break;
            
        case MTSamplerParamMaxFilter:
            validSamplerMinMaxFilter(param) ? desc->mag_filter = (MTSamplerMinMagFilter)param : 0;
            break;
            
        case MTSamplerParamMipFilter:
            validSamplerMipFilter(param) ? desc->mip_filter = (MTSamplerMipFilter)param : 0;
            break;
            
        case MTSamplerParamMaxAnistropy:
            desc->max_anisotropy = param;
            break;
            
        case MTSamplerParamAddressMode_S:
            validSamplerAddressMode(param) ? desc->s_address_mode = (MTSamplerAddressMode)param : 0;
            break;
            
        case MTSamplerParamAddressMode_T:
            validSamplerAddressMode(param) ? desc->t_address_mode = (MTSamplerAddressMode)param : 0;
            break;
            
        case MTSamplerParamAddressMode_R:
            validSamplerAddressMode(param) ? desc->r_address_mode = (MTSamplerAddressMode)param : 0;
            break;
            
        case MTSamplerParamBoarderColor:
            validSamplerBorderColor(param) ? desc->boarder_color = (MTSamplerBorderColor)param : 0;
            desc->min_filter = (MTSamplerMinMagFilter)param;
            break;
            
        case MTSamplerParamNormallizedCoordinates:
            desc->normalized_coordinates = param > 0 ? true : false;
            break;
            
        case MTSamplerParamLodMinClamp:
        case MTSamplerParamLodMaxClamp:
            mtWarningFunc("Use mtSetSamplerDescParamf for this", func);
            break;
            
        case MTSamplerParamLodAverage:
            desc->lod_average = param > 0 ? true : false;
            break;
            
        case MTSamplerParamLodBias:
            mtWarningFunc("Use mtSetSamplerDescParamf for this", func);
            break;
            
        case MTSamplerParamSupportArgumentBuffers:
            desc->support_argument_buffers = param > 0 ? true : false;
            break;
            
        default:
            mtWarningFunc("invalid pname", func);
            break;
    }
}

void mtSetSamplerDescParam(MTuint name, MTenum pname, MTuint param)
{
    setSamplerDescParam(name, pname, param, __FUNCTION__);
}

void mtSetSamplerDescParamf(MTuint name, MTenum pname, MTfloat param)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(name, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    switch(pname)
    {
        case MTSamplerParamMinFilter:
        case MTSamplerParamMaxFilter:
        case MTSamplerParamMipFilter:
        case MTSamplerParamMaxAnistropy:
        case MTSamplerParamAddressMode_S:
        case MTSamplerParamAddressMode_T:
        case MTSamplerParamAddressMode_R:
        case MTSamplerParamBoarderColor:
        case MTSamplerParamNormallizedCoordinates:
            mtWarningFunc("Use mtSetSamplerDescParam for this", __FUNCTION__);
            break;

        case MTSamplerParamLodMinClamp:
            desc->lod_min_clamp = param;
            break;

        case MTSamplerParamLodMaxClamp:
            desc->lod_max_clamp = param;
            break;
            
        case MTSamplerParamLodAverage:
            mtWarningFunc("Use mtSetSamplerDescParam for this", __FUNCTION__);
            break;
            
        case MTSamplerParamLodBias:
            desc->lod_bias = param;
            break;
            
        case MTSamplerParamCompareFunction:
        case MTSamplerParamSupportArgumentBuffers:
            mtWarningFunc("Use mtSetSamplerDescParam for this", __FUNCTION__);
            break;
            
        default:
            mtWarningFunc("invalid pname", __FUNCTION__);
            break;
   }
}

void mtSetSamplerDescMinFilter(MTuint name, MTSamplerMinMagFilter min_filter)
{
    setSamplerDescParam(name, MTSamplerParamMinFilter, min_filter, __FUNCTION__);
}

void mtSetSamplerDescMaxFilter(MTuint name, MTSamplerMinMagFilter max_filter)
{
    setSamplerDescParam(name, MTSamplerParamMaxFilter, max_filter, __FUNCTION__);
}

void mtSetSamplerDescMipFilter(MTuint name, MTSamplerMipFilter mip_filter)
{
    setSamplerDescParam(name, MTSamplerParamMipFilter, mip_filter, __FUNCTION__);
}

void mtSetSamplerDescMaxAnistropy(MTuint name, MTSamplerMipFilter max_anistropy)
{
    setSamplerDescParam(name, MTSamplerParamMaxAnistropy, max_anistropy, __FUNCTION__);
}

void mtSetSamplerDescAddressMode_S(MTuint name, MTSamplerAddressMode mode)
{
    setSamplerDescParam(name, MTSamplerParamAddressMode_S, mode, __FUNCTION__);
}

void mtSetSamplerDescAddressMode_T(MTuint name, MTSamplerAddressMode mode)
{
    setSamplerDescParam(name, MTSamplerParamAddressMode_S, mode, __FUNCTION__);
}

void mtSetSamplerDescAddressMode_R(MTuint name, MTSamplerAddressMode mode)
{
    setSamplerDescParam(name, MTSamplerParamAddressMode_R, mode, __FUNCTION__);
}

void mtSetSamplerDescBoarderColor(MTuint name, MTSamplerBorderColor mode)
{
    setSamplerDescParam(name, MTSamplerParamBoarderColor, mode, __FUNCTION__);
}

void mtSetSamplerDescNormalizedCoordinates(MTuint name, MTbool normalized_coordinates)
{
    setSamplerDescParam(name, MTSamplerParamNormallizedCoordinates, normalized_coordinates, __FUNCTION__);
}

void mtSetSamplerDescLodMinClamp(MTuint name, MTfloat lod_min_clamp)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(name, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    desc->lod_min_clamp = lod_min_clamp;
}

void mtSetSamplerDescLodMaxClamp(MTuint name, MTfloat lod_max_clamp)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(name, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    desc->lod_max_clamp = lod_max_clamp;
}

void mtSetSamplerDescLodAverage(MTuint name, MTbool lod_average)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(name, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    desc->lod_average = lod_average;
}

void mtSetSamplerDescLodBias(MTuint name, MTfloat lod_bias)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(name, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    desc->lod_bias = lod_bias;
}

void mtSetSamplerDescCompareFunction(MTuint name, MTCompareFunction compare_function)
{
    setSamplerDescParam(name, MTSamplerParamCompareFunction, compare_function, __FUNCTION__);
}

void mtSetSamplerDescSupportArgumentBuffers(MTuint name, MTbool support_argument_buffers)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(name, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    desc->support_argument_buffers = support_argument_buffers;
}

MTuint mtCreateSampler(MTuint desc_name)
{
    MTSamplerDesc   *desc;
    
    desc = getSamplerDesc(desc_name, __FUNCTION__);
    
    if (desc == NULL)
    {
        return 0;
    }
    
    MTSampler *sampler;
    
    sampler = newPtr(MTSampler);
    zeroPtr(sampler, MTSampler);
    
    memcpy(&sampler->desc, desc, sizeof(MTSamplerDesc));
    
    MTuint name;
    
    name = getNewName(STATE(sampler_table));
    
    insertHashElement(STATE(sampler_table), name, sampler);
    
    return name;
}

void  mtDeleteSampler(MTuint name)
{
    if (name == 0)
    {
        // quietly return
        return;
    }
    
    MTSampler *sampler;
    
    sampler = getKeyData(STATE(sampler_table), name);
    
    if(sampler == NULL)
    {
        mtWarningFunc("Invalid sampler", __FUNCTION__);
        
        return;
    }
    
    // see if this is bound to the current state
    for(int i=0; i<MAX_TEXTURE_UNITS; i++)
    {
        if (STATE(vertex_samplers[i]) == name)
        {
            STATE(vertex_samplers[i]) = 0;
            STATE(enabled_vertex_samplers) &= ~(0x1 << i);
            _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
        }

        if (STATE(fragment_samplers[i]) == name)
        {
            STATE(fragment_samplers[i]) = 0;
            STATE(enabled_fragment_samplers) &= ~(0x1 << i);
            _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
        }
    }
    
    if (sampler->mtl_sampler)
    {
        _ctx->mt_render_funcs.mtlCFBridgingRelease(sampler->mtl_sampler);
        sampler->mtl_sampler = NULL;
    }
    
    free(sampler);
    
    deleteHashElement(STATE(sampler_table), name);
}

void mtBindVertexSampler(MTuint name, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("%s name > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    if (name)
    {
        STATE(enabled_vertex_samplers) |= (0x1 << unit);
    }
    else
    {
        STATE(enabled_vertex_samplers) &= ~(0x1 << unit);
    }
    
    STATE(vertex_samplers[unit]) = name;
    _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
}

void mtBindFragmentSampler(MTuint name, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("%s name > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    if (name)
    {
        STATE(enabled_fragment_samplers) |= (0x1 << unit);
    }
    else
    {
        STATE(enabled_fragment_samplers) &= ~(0x1 << unit);
    }
    
    STATE(fragment_samplers[unit]) = name;
    _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
}
