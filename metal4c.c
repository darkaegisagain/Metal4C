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
#include "Renderer_Extern.h"
#include "hash_table.h"

// As a general rule we neeed to maintain C context types in C and let
// the renderer part deal with its stuff

MTRenderContext _ctx = NULL;

void mtClearColor(MTfloat r, MTfloat g, MTfloat b, MTfloat a)
{
    STATE(clear_color.r) = r;
    STATE(clear_color.g) = g;
    STATE(clear_color.b) = b;
    STATE(clear_color.a) = a;
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}

void mtClear(MTbitfield mask)
{
    STATE(clear_mask) = mask;
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}
