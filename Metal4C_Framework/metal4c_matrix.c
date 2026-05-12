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
#include "metal4c_Renderer_Extern.h"
#include "metal4c_hash_table.h"
#include "metal_math_utils.h"

// current context
extern MTRenderContextRec *_ctx;

static inline MTMatrixStack *currentMat(void)
{
    MTenum mode;
    
    mode = MAT(mode);
    
    return &MAT(stks[mode]);
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

static inline MTuint projSP(void)
{
    return MAT(stks[MTMatrixMode_Projection].sp);
}

static inline MTuint mvSP(void)
{
    return MAT(stks[MTMatrixMode_ModelView].sp);
}

static inline MTuint curSP(void)
{
    MTuint mode;
    
    mode = MAT(mode);
    
    return MAT(stks[mode].sp);
}

void mtUpdateMVP(void)
{
    MAT(mvp) = matrix_multiply(MAT(stks[MTMatrixMode_Projection].stack[projSP()]),
                               MAT(stks[MTMatrixMode_ModelView].stack[mvSP()]));
}

void mtMatrixMode(MTenum mode)
{
    switch(mode)
    {
        case MTMatrixMode_ModelView:
        case MTMatrixMode_Projection:
        case MTMatrixMode_Texture:
        case MTMatrixMode_Color:
            break;
            
        default:
            mtWarningFunc("invalide matrix mode", __FUNCTION__);
            return;
    }
    
    MAT(mode) = mode;
}

void mtLoadMatrixf(MTfloat m[16])
{
    MTuint mode;
    
    mode = MAT(mode);
    
    memcpy(&MAT(stks[mode].stack[curSP()]), m, sizeof(matrix_float4x4));
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtMultMatrixf(MTfloat m[16])
{
    MTuint mode;
    
    mode = MAT(mode);
    
    matrix_float4x4 src;
    
    memcpy(&src, m, sizeof(matrix_float4x4));
    
    MAT(stks[mode].stack[curSP()]) = matrix_multiply(src, MAT(stks[mode].stack[curSP()]));
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtLoadTransposeMatrixf(MTfloat m[16])
{
    MTuint mode;
    
    mode = MAT(mode);
    
    matrix_float4x4 src;
    
    memcpy(&src, m, sizeof(matrix_float4x4));
    
    MAT(stks[mode].stack[curSP()]) = matrix_transpose(src);
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtMultTransposeMatrixf(MTfloat m[16])
{
    MTuint mode;
    
    mode = MAT(mode);
    
    matrix_float4x4 src;
    
    memcpy(&src, m, sizeof(matrix_float4x4));
    
    src = matrix_transpose(src);
    
    MAT(stks[mode].stack[curSP()]) = matrix_multiply(src, MAT(stks[mode].stack[curSP()]));

    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtLoadIdentityf(void)
{
    MTuint mode;
    
    mode = MAT(mode);

    MAT(stks[mode].stack[curSP()]) = matrix_identity_float4x4;
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtRotatef(MTfloat theata, MTfloat x, MTfloat y, MTfloat z)
{
    MTuint mode;
    
    mode = MAT(mode);
    
    MAT(stks[mode].stack[curSP()]) = matrix4x4_rotation(theata, x, y, z);
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtTranslatef(MTfloat x, MTfloat y, MTfloat z)
{
    MTuint mode;
    
    mode = MAT(mode);
    
    MAT(stks[mode].stack[curSP()]) = matrix4x4_translation(vector3(x, y, z));

    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtScalef(MTfloat x, MTfloat y, MTfloat z)
{
    MTuint mode;
    
    mode = MAT(mode);
    
    MAT(stks[mode].stack[curSP()]) = matrix4x4_scale(vector3(x, y, z));

    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtFrustrumf(MTfloat l, MTfloat r, MTfloat b, MTfloat t, MTfloat n, MTfloat f)
{
    MTuint mode;
    
    mode = MAT(mode);

    MAT(stks[mode].stack[curSP()]) = matrix_perspective_frustum_right_hand(l, r, b, t, n, f);
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

void mtOrthof(MTfloat l, MTfloat r, MTfloat b, MTfloat t, MTfloat n, MTfloat f)
{
    MTuint mode;
    
    mode = MAT(mode);

    MAT(stks[mode].stack[curSP()]) = matrix_ortho_right_hand(l, r, b, t, n, f);

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


void mtPerspectivef(MTfloat angle, MTfloat ratio, MTfloat n, MTfloat f,
                   MTfloat *b, MTfloat *t, MTfloat *l, MTfloat *r)
 {
    MTfloat scale;
    
    scale = tanf(angle * 0.5 * M_PI / 180) * n;

    *r = ratio * scale;
    *l = -*r;
    *t = scale;
    *b = -*t;
 }

void mtTexGenf(MTenum coord, MTenum pname, MTfloat param)
{
    
}

void mtTexGenfv(MTenum coord, MTenum pname, MTfloat *params)
{
    
}

