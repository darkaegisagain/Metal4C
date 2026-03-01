//
//  metal4c_matrix.c
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
#include "matrix_lib.h"

// current context
extern MTRenderContext _ctx;

static inline MTMatrixStack *currentMat(void)
{
    MTenum mode;
    
    mode = MAT(mode);
    
    return &MAT(stks[mode]);
}

static inline mat4_t tos(void)
{
    MTMatrixStack *stk;
    
    stk = currentMat();
    
    MTuint sp;
    sp = stk->sp;
    
    return stk->stack[sp];
}

static inline float *tosf(void)
{
    MTMatrixStack *stk;
    
    stk = currentMat();
    
    MTuint sp;
    sp = stk->sp;
    
    return (float *)stk->stack[sp];
}

static inline bool validPush(void)
{
    MTMatrixStack *stk;

    stk = currentMat();
    
    if (stk->sp < stk->max_depth)
    {
        stk->sp++;
        
        return true;
    }
    
    return false;
}

static inline bool validPop(void)
{
    MTMatrixStack *stk;

    stk = currentMat();
    
    if (stk->sp > 0)
    {
        stk->sp--;
        
        return true;
    }
    
    return false;
}

void mtMatrixMode(MTenum mode)
{
    switch(mode)
    {
        case kMatrixMode_Modelview:
        case kMatrixMode_Projection:
        case kMatrixMode_Texture:
        case kMatrixMode_Color:
            break;
            
        default:
            mtWarningFunc("invalide matrix mode", __FUNCTION__);
            return;
    }
    
    MAT(mode) = mode;
}

void mtLoadMatrixf(MTfloat m[16])
{
    mat4_set(m, tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtMultMatrixf(MTfloat m[16])
{
    // the mat lib handles when src2 == dst
    mat4_multiply(m, tosf(), tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtLoadTransposeMatrixf(MTfloat m[16])
{
    mat4_set(m, tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtMultTransposeMatrixf(MTfloat m[16])
{
    mat4_transpose(m, tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtLoadIdentityf(void)
{
    mat4_identity(tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtRotatef(MTfloat theata, MTfloat x, MTfloat y, MTfloat z)
{
    float v[3];
    
    v[0] = x;
    v[1] = y;
    v[2] = z;

    mat4_rotate(tosf(), theata, v, tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtTranslatef(MTfloat x, MTfloat y, MTfloat z)
{
    float v[3];
    
    v[0] = x;
    v[1] = y;
    v[2] = z;

    mat4_translate(tosf(), v, tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtScalef(MTfloat x, MTfloat y, MTfloat z)
{
    float v[3];
    
    v[0] = x;
    v[1] = y;
    v[2] = z;

    mat4_scale(tosf(), v, tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtFrustrumf(MTfloat l, MTfloat r, MTfloat b, MTfloat t, MTfloat n, MTfloat f)
{
    mat4_frustum(l, r, b, t, n, f, tosf());
}

void mtOrthof(MTfloat l, MTfloat r, MTfloat b, MTfloat t, MTfloat n, MTfloat f)
{
    mat4_ortho(l, r, b, t, n, f, tosf());
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtPushMatrix(void)
{
    if(validPush())
    {
        mtLoadIdentityf();
        _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
        return;
    }
    
    mtWarningFunc("matrix push invalid", __FUNCTION__);
}

void mtPopMatrix(void)
{
    if(validPop())
    {
        _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
        return;
    }
    
    mtWarningFunc("matrix pop invalid", __FUNCTION__);
}

void mtTexGenf(MTenum coord, MTenum pname, MTfloat param)
{
    
}

void mtTexGenfv(MTenum coord, MTenum pname, MTfloat *params)
{
    
}

