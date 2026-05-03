//
//  metal4c_context.c
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
#include "Renderer_Extern.h"
#include "hash_table.h"

static MTRenderContext      _currentContext = 0;
static HashTable            *_context_table = NULL;

static MTVec4 MakeVec4(MTfloat x, MTfloat y, MTfloat z, MTfloat w)
{
    MTVec4 vec;
    vec.x = x;
    vec.y = y;
    vec.z = z;
    vec.w = w;
    return vec;
}

static MTVec2 MakeVec2(MTfloat x, MTfloat y)
{
    MTVec2 vec;
    vec.x = x;
    vec.y = y;
    return vec;
}

static MTColor MakeColor(MTfloat r, MTfloat g, MTfloat b, MTfloat a)
{
    MTColor color;
    color.r = r;
    color.g = g;
    color.b = b;
    color.a = a;
    return color;
}

void mtErrorFunc(const char *err, const char *func)
{
    printf("Error: %s function: %s\n", err, func);
    assert(0);
}

void mtWarningFunc(const char *err, const char *func)
{
    printf("Warning: %s function: %s\n", err, func);
}

MTRenderContext mtCreateContext(void)
{
    MTRenderContextRec *ctx;
    
    ctx = newPtr(MTRenderContextRec);
    zeroPtr(ctx, MTRenderContextRec);
        
    ctx->state.clear_color = MakeVec4(0.0, 0.0, 0.0, 1.0);
    
    ctx->state.clear_depth = 1.0;
    ctx->state.depth_stencil_format = MTPixelFormatDepth32Float_Stencil8;
//    ctx->state.depth_format = MTPixelFormatDepth32Float;
    //    ctx->state.stencil_format = MTPixelFormatStencil8;
    ctx->state.depth_test_min_bound = 0.0;
    ctx->state.depth_test_max_bound = 1.0;
    ctx->state.depth_test_mode = MTCompareFunctionNever;
    ctx->state.front_stencil_desc.compare_func = MTStencilOperationKeep;
    ctx->state.back_stencil_desc.compare_func = MTStencilOperationKeep;

    ctx->state.vertex_shader_mode = MTVertexShaderModeNonInstanced;
    ctx->state.fragment_shader_mode = MTFragmentShaderModeColor;

    // force loading of default shader and clear color
    ctx->dirty_state = (DIRTY_PIPELINE | DIRTY_RENDER_PASS | DIRTY_TEXTURE | DIRTY_UPLOADED_STATE);
    
    ctx->state.prim_type                = MTPrimitiveTypeNone;
    
    ctx->vert_eng.max_vertices          = MAX_VERTICES;
    ctx->vert_eng.num_vertices          = NUM_VERTICES;
    ctx->vert_eng.vertices              = newArray(Vertex4ColorNormalTex, NUM_VERTICES);
    ctx->vert_eng.current_vertex        = 0;

    ctx->vert_eng.max_indices           = MAX_INDICES;
    ctx->vert_eng.num_indices           = NUM_INDICES;
    ctx->vert_eng.indices               = newArray(MTuint, NUM_INDICES);
    ctx->vert_eng.current_index         = 0;

    ctx->vert_eng.baseVertex.position   = MakeVec4(0.0, 0.0, 0.0, 0.0);
    ctx->vert_eng.baseVertex.color      = MakeColor(0.0, 0.0, 0.0, 1.0);
    
    ctx->state.enabled_vertex_textures        = 0;
    ctx->state.enabled_fragment_textures      = 0;

    for(int i=0; i<MAX_TEXTURE_UNITS; i++)
    {
        ctx->state.vertex_textures[i]         = 0;
        ctx->state.fragment_textures[i]       = 0;
        ctx->vert_eng.baseVertex.st[i]  = MakeVec2(0.0, 0.0);
    }

    ctx->state.buffer_table = newPtr(HashTable);
    ctx->state.texture_table = newPtr(HashTable);
    ctx->state.shader_table = newPtr(HashTable);
    ctx->state.sampler_table = newPtr(HashTable);
    ctx->state.vertex_array_table = newPtr(HashTable);
    ctx->state.texture_desc_table = newPtr(HashTable);
    ctx->state.sampler_desc_table = newPtr(HashTable);
    
    initHashTable(ctx->state.buffer_table, 32);
    initHashTable(ctx->state.texture_table, 32);
    initHashTable(ctx->state.shader_table, 4);
    initHashTable(ctx->state.sampler_table, 32);
    initHashTable(ctx->state.vertex_array_table, 4);
    initHashTable(ctx->state.texture_desc_table, 4);
    initHashTable(ctx->state.sampler_desc_table, 4);

    for(int mode = MTMatrixMode_ModelView; mode<MTMatrixMode_Max; mode++)
    {
        switch(mode)
        {
            case MTMatrixMode_ModelView:
                ctx->state.mat.stks[mode].max_depth = MAX_MODELVIEW_MATRIX_DEPTH;
                break;
                
            default:
                ctx->state.mat.stks[mode].max_depth = MAX_MATRIX_DEPTH;
                break;
        }
     
        ctx->state.mat.stks[mode].stack = newArray(matrix_float4x4, ctx->state.mat.stks[mode].max_depth);
        
        for(int i=0; i<ctx->state.mat.stks[mode].max_depth; i++)
        {
            ctx->state.mat.stks[mode].stack[i] = matrix_identity_float4x4;
        }
        
        ctx->state.mat.stks[mode].sp = 0;
    }

    ctx->state.mat.mode = MTMatrixMode_ModelView;
        
    if (_context_table == NULL)
    {
        _context_table = newPtr(HashTable);
        
        initHashTable(_context_table, 4);
    }
    
    MTRenderContext ret;
    
    ret = getNewName(_context_table);
    
    insertHashElement(_context_table, ret, ctx);

    return ret;
}

void mtSetCurrentContext(MTRenderContext ctx)
{
    if (_context_table == NULL)
    {
        mtWarningFunc("No contexts defined", __FUNCTION__);
        return;
    }
    
    if (ctx == 0)
    {
        _ctx = NULL;

        return;
    }
    
    if (isValidKey(_context_table, ctx))
    {
        _currentContext = ctx;

        _ctx = getKeyData(_context_table, ctx);
        
        return;
    }
}

MTRenderContext mtGetCurrentContext(void)
{
    return _currentContext;
}

MTRenderContextRec *mtGetContextPtr(MTRenderContext ctx)
{
    if (_context_table == NULL)
    {
        mtWarningFunc("No contexts defined", __FUNCTION__);
        return NULL;
    }
    
    if (isValidKey(_context_table, ctx))
    {
        return getKeyData(_context_table, ctx);
    }
    
    return NULL;
}

void mtSetPointSize(MTfloat size)
{
    STATE(point_size) = size;
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtSetViewport(MTfloat x, MTfloat y, MTfloat width, MTfloat height)
{
    STATE(viewport.x) = x;
    STATE(viewport.y) = y;
    STATE(viewport.width) = width;
    STATE(viewport.height) = height;

    _ctx->dirty_state |= (DIRTY_UPLOADED_STATE | DIRTY_RENDER_PASS);
}
