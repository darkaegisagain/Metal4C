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
    
    ctx->state.render_mode = kRendermodeColor;
    ctx->state.clear_color = MakeVec4(0.0, 0.0, 0.0, 1.0);
    
    // force loading of default shader and clear color
    ctx->dirty_state = (DIRTY_PIPELINE | DIRTY_RENDER_PASS | DIRTY_TEXTURE | DIRTY_UPLOADED_STATE);
    
    ctx->vert_eng.prim_type             = PrimitiveTypeNone;
    ctx->vert_eng.num_vertices          = NUM_VERTICES;
    ctx->vert_eng.vertices              = newArray(Vertex4ColorNormalTex, NUM_VERTICES);
    ctx->vert_eng.current_vertex        = 0;
    
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

    initHashTable(ctx->state.buffer_table, 32);
    initHashTable(ctx->state.texture_table, 32);
    initHashTable(ctx->state.shader_table, 4);

    ctx->state.mat.mode = kMatrixMode_Modelview;
    for(int mode = kMatrixMode_Modelview; mode<kMatrixMode_Max; mode++)
    {
        switch(mode)
        {
            case kMatrixMode_Modelview:
                ctx->state.mat.stks[mode].max_depth = MAX_MODELVIEW_MATRIX_DEPTH;
                break;
                
            default:
                ctx->state.mat.stks[mode].max_depth = MAX_MATRIX_DEPTH;
                break;
        }
        
        for(int i=0; i<ctx->state.mat.stks[mode].max_depth; i++)
        {
            ctx->state.mat.stks[mode].stack[i] = mat4_create(NULL);
            mat4_identity(ctx->state.mat.stks[mode].stack[i]);
        }
        
        ctx->state.mat.stks[mode].sp = 0;
        mtLoadIdentityf();
    }
    
    return (MTRenderContext)ctx;
}

void mtSetCurrentContext(MTRenderContext ctx)
{
    _ctx = ctx;
}

MTRenderContext mtGetCurrentContext(void)
{
    return _ctx;
}

void mtSetRendermode(MTuint mode)
{
    if ((mode >= kRendermodeColor) && (mode < kRendermodeMax))
    {
        STATE(render_mode) = mode;
        _ctx->dirty_state |= (DIRTY_PIPELINE | DIRTY_UPLOADED_STATE);

        return;
    }
    
    mtWarningFunc("Invalid rendermode", __FUNCTION__);
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
