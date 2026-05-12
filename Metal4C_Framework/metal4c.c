//
//  metal4c.c
//  Metal4C
//
//  Created by Michael Larson on 2/21/26.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "metal4c.h"
#include "metal4c_context.h"
#include "metal4c_Renderer_Extern.h"
#include "metal4c_hash_table.h"
#include "metal4c_x11_colors.h"

// As a general rule we neeed to maintain C context types in C and let
// the renderer part deal with its stuff

MTRenderContextRec          *_ctx = NULL;

void mtSetRendermode(MTVertexShaderMode vertex_shader_mode, MTFragmentShaderMode fragment_shader_mode)
{
    if (STATE(vertex_shader_mode) != vertex_shader_mode)
    {
        STATE(vertex_shader_mode) = vertex_shader_mode;
        
        _ctx->dirty_state |= DIRTY_PIPELINE;
    }
    
    if (STATE(fragment_shader_mode) != fragment_shader_mode)
    {
        STATE(fragment_shader_mode) = fragment_shader_mode;
        
        _ctx->dirty_state |= DIRTY_PIPELINE;
    }
}

void mtSetVertexRendermode(MTVertexShaderMode vertex_shader_mode)
{
    if (STATE(vertex_shader_mode) != vertex_shader_mode)
    {
        STATE(vertex_shader_mode) = vertex_shader_mode;
        
        _ctx->dirty_state |= DIRTY_PIPELINE;
    }
}

void mtSetFragmentRendermode(MTFragmentShaderMode fragment_shader_mode)
{
    if (STATE(fragment_shader_mode) != fragment_shader_mode)
    {
        STATE(fragment_shader_mode) = fragment_shader_mode;
        
        _ctx->dirty_state |= DIRTY_PIPELINE;
    }
}

void mtClearColor(MTfloat r, MTfloat g, MTfloat b, MTfloat a)
{
    STATE(clear_color.r) = r;
    STATE(clear_color.g) = g;
    STATE(clear_color.b) = b;
    STATE(clear_color.a) = a;
}

void mtClearDepthValue(MTdouble depth)
{
    if ((depth >= 0.0) && (depth <= 1.0))
    {
        STATE(clear_depth) = depth;
    }
}

void mtClearStencilValue(MTuint stencil)
{
    STATE(clear_stencil) = stencil;
}

void mtClear(MTbitfield mask)
{
    STATE(clear_mask) = mask;
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}

static MTbool validCompareFunc(MTenum mode, const char *func)
{
    switch(mode)
    {
        case MTCompareFunctionNever:
        case MTCompareFunctionLess:
        case MTCompareFunctionEqual:
        case MTCompareFunctionLessEqual:
        case MTCompareFunctionGreater:
        case MTCompareFunctionNotEqual:
        case MTCompareFunctionGreaterEqual:
        case MTCompareFunctionAlways:
            return true;
            break;
            
        default:
            mtWarningFunc("Invalid depth mode", func);
            return false;
    }
    
    return false;
}

static MTStencilDesc *getBuffDesc(MTenum buffer, const char *func)
{
    MTStencilDesc *desc;
    
    switch(buffer)
    {
        case MTStencilFrontBuffer:
            desc = &STATE(front_stencil_desc);
            break;
            
        case MTStencilBackBuffer:
            desc = &STATE(back_stencil_desc);
            break;
            
        default:
            mtWarningFunc("Invalid buffer", func);
            return NULL;
    }

    return desc;
}

static void enableDisableCap(MTenum cap, MTbool state, const char *func)
{
    switch(cap)
    {
        case MTCapDepthTest:
            if (STATE(depth_enable) != state)
            {
                STATE(depth_enable) = state;
                _ctx->dirty_state |= DIRTY_RENDER_PASS;
            }
            break;
            
        case MTCapStencilTest:
            if (STATE(stencil_enable) != state)
            {
                STATE(stencil_enable) = state;
                _ctx->dirty_state |= DIRTY_RENDER_PASS;
            }
            break;
            
        default:
            mtWarningFunc("invalid cap", func);
            return;
    }
}

void mtEnable(MTenum cap)
{
    enableDisableCap(cap, 1, __FUNCTION__);
}

void mtDisable(MTenum cap)
{
    enableDisableCap(cap, 0, __FUNCTION__);
}

void mtCullMode(MTCullMode mode)
{
    switch(mode)
    {
        case MTCullModeNone:
        case MTCullModeFront:
        case MTCullModeBack:
            break;
            
        default:
            mtWarningFunc("invalid mode", __FUNCTION__);
            return;
    }
    
    STATE(cull_mode) = mode;

    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtWindingMode(MTWinding mode)
{
    switch(mode)
    {
        case MTWindingClockwise:
        case MTWindingCounterClockwise:
            break;
            
        default:
            mtWarningFunc("invalid mode", __FUNCTION__);
            return;
    }
    
    STATE(winding_mode) = mode;

    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtDepthClipMode(MTDepthClipMode mode)
{
    switch(mode)
    {
        case MTDepthClipModeClip:
        case MTDepthClipModeClamp:
            break;
            
        default:
            mtWarningFunc("invalid mode", __FUNCTION__);
            return;
    }
    
    STATE(depth_clip_mode) = mode;

    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtDepthTestBounds(MTfloat min, MTfloat max)
{
    if ((min < 0) || (max >1))
    {
        mtWarningFunc("invalid bounds", __FUNCTION__);
        return;
    }
    
    STATE(depth_test_min_bound) = min;
    STATE(depth_test_max_bound) = max;

    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtDepthBias(MTfloat bias, MTfloat scale, MTfloat clamp)
{
    STATE(depth_bias) = bias;
    STATE(depth_bias_scale) = scale;
    STATE(depth_bias_clamp) = clamp;

    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtTriangleFillMode(MTTriangleFillMode mode)
{
    switch(mode)
    {
        case MTTriangleFillModeFill:
        case MTTriangleFillModeLines:
            break;
            
        default:
            mtWarningFunc("invalid mode", __FUNCTION__);
            return;
    }
    
    STATE(triangle_fill_mode) = mode;
    
    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}


void mtDepthMode(MTenum mode)
{
    if (validCompareFunc(mode, __FUNCTION__) == false)
    {
        return;
    }
    
    if (mode != STATE(depth_test_mode))
    {
        STATE(depth_test_mode) = mode;
        
        _ctx->dirty_state |= DIRTY_RENDER_PASS;
    }
}

void mtStencilCompareFunc(MTenum buffer, MTenum compare_func)
{
    MTStencilDesc *desc;
    
    desc = getBuffDesc(buffer, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    if (validCompareFunc(compare_func, __FUNCTION__) == false)
    {
        return;
    }
    
    desc->compare_func = compare_func;
    
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}

void mtStencilCompareOp(MTenum buffer, MTenum pass_fail_op_sel, MTenum op)
{
    MTStencilDesc *desc;
    
    desc = getBuffDesc(buffer, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    switch(pass_fail_op_sel)
    {
        case MTStencilFailureOp:
        case MTDepthFailureOp:
        case MTDepthStencilPassOp:
            break;
            
        default:
            mtWarningFunc("Invalid pass_fail_op_sel", __FUNCTION__);
            return;
    }
    
    switch(op)
    {
        case MTStencilOperationKeep:
        case MTStencilOperationZero:
        case MTStencilOperationReplace:
        case MTStencilOperationIncrementClamp:
        case MTStencilOperationDecrementClamp:
        case MTStencilOperationInvert:
        case MTStencilOperationIncrementWrap:
        case MTStencilOperationDecrementWrap:
            break;
            
        default:
            mtWarningFunc("invalid stencil_op", __FUNCTION__);
            return;
    }

    assert(desc);
    
    switch(pass_fail_op_sel)
    {
        case MTStencilFailureOp:
            desc->stencil_failure_op = op;
            break;
            
        case MTDepthFailureOp:
            desc->depth_failure_op = op;
            break;
            
        case MTDepthStencilPassOp:
            desc->depth_stencil_pass_op = op;
            break;
            
        default:
            assert(0);
            return;
    }
    
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}

void mtStencilReadMask(MTenum buffer, MTuint mask)
{
    MTStencilDesc *desc;
    
    desc = getBuffDesc(buffer, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    desc->read_mask = mask;
    
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}

void mtStencilWriteMask(MTenum buffer, MTuint mask)
{
    MTStencilDesc *desc;
    
    desc = getBuffDesc(buffer, __FUNCTION__);
    
    if (desc == NULL)
    {
        return;
    }
    
    desc->write_mask = mask;
    
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}

void mtScissorRect(MTuint x, MTuint y, MTuint width, MTuint height)
{
    STATE(scissor_enable) = true;
    STATE(scissor_rect.x) = x;
    STATE(scissor_rect.y) = y;
    STATE(scissor_rect.width) = width;
    STATE(scissor_rect.height) = height;

    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtGetX11ColorByName(const char *name, MTfloat *color)
{
    X11Color *x11_color;
    
    x11_color = getX11Color(name);
    
    if (x11_color)
    {
        *color++ = x11_color->fr;
        *color++ = x11_color->fg;
        *color++ = x11_color->fb;
        *color   = x11_color->fa;

        return;
    }
    
    printf("%s error finding color %s\n", __FUNCTION__, name);
}
