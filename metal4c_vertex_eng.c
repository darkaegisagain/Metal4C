//
//  metal_vertex_eng.c
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

void mtColorf(MTfloat r, MTfloat g, MTfloat b, MTfloat a)
{
    VENG(baseVertex.color.r) = r;
    VENG(baseVertex.color.g) = g;
    VENG(baseVertex.color.b) = b;
    VENG(baseVertex.color.a) = a;
}

void mtNormalf(MTfloat x, MTfloat y, MTfloat z)
{
    VENG(baseVertex.normal.x) = x;
    VENG(baseVertex.normal.y) = y;
    VENG(baseVertex.normal.z) = z;
    VENG(baseVertex.normal.w) = 0.0;
}

void mtTexf(MTfloat s, MTfloat t)
{
    VENG(baseVertex.st[0][0]) = s;
    VENG(baseVertex.st[0][1]) = t;
}

void mtTexfUnit(MTfloat s, MTfloat t, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("unit > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    VENG(baseVertex.st[unit][0]) = s;
    VENG(baseVertex.st[unit][1]) = t;
}

void mtVertex4f(MTfloat x, MTfloat y, MTfloat z, MTfloat w)
{
    VENG(vertices[VENG(current_vertex)].color)   = VENG(baseVertex.color);
    VENG(vertices[VENG(current_vertex)].normal)  = VENG(baseVertex.normal);

    if (STATE(enabled_fragment_textures))
    {
        for(int i=0; i<MAX_TEXTURE_UNITS; i++)
        {
            if (STATE(enabled_fragment_textures) & (0x1 << i))
            {
                VENG(vertices[VENG(current_vertex)].st[i]) = VENG(baseVertex.st[i]);
            }
        }
    }
    
    VENG(vertices[VENG(current_vertex++)].position.x) = x;
    VENG(vertices[VENG(current_vertex++)].position.y) = y;
    VENG(vertices[VENG(current_vertex++)].position.z) = z;
    VENG(vertices[VENG(current_vertex++)].position.w) = w;

    if (VENG(current_vertex) == VENG(num_vertices))
    {
        _ctx->mt_render_funcs.mtlFlushVertexEng(_ctx);
        
        VENG(current_vertex) = 0;
    }
}

void mtBegin(PrimitiveType type)
{
    if (VENG(prim_type) != PrimitiveTypeNone)
    {
        mtErrorFunc("%s render_mode != PrimitiveTypeNone, inside mtBegin block", __FUNCTION__);
        
        return;
    }
    
    VENG(prim_type) = type;
    VENG(current_vertex) = 0;

    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

void mtEnd(void)
{
    if (VENG(prim_type) == PrimitiveTypeNone)
    {
        mtErrorFunc("%s render_mode == PrimitiveTypeNone, call mtBegin", __FUNCTION__);
        
        return;
    }

    do {
        switch(VENG(prim_type))
        {
            case PrimitiveTypeLine:
            case PrimitiveTypeLineStrip:
                if (VENG(current_vertex) < 2)
                {
                    mtWarningFunc("insufficent verts for PrimitiveTypeLine", __FUNCTION__);
                    continue;
                }
                break;
                
            case PrimitiveTypeTriangle:
            case PrimitiveTypeTriangleStrip:
                if (VENG(current_vertex) < 3)
                {
                    mtWarningFunc("insufficent verts for PrimitiveTypeTriangle", __FUNCTION__);
                    continue;
                }
                break;
                
            default:
                break;
        }

        _ctx->mt_render_funcs.mtlEnd(_ctx);
    } while(0);
    
    // maintain C context types in C
    VENG(prim_type)             = PrimitiveTypeNone;

    VENG(baseVertex.position.x) =
    VENG(baseVertex.position.y) =
    VENG(baseVertex.position.z) =
    VENG(baseVertex.position.w) = 0.0;
    
    VENG(baseVertex.color.r) =
    VENG(baseVertex.color.g) =
    VENG(baseVertex.color.b) = 0.0;
    VENG(baseVertex.color.a) = 1.0;

    if (STATE(enabled_fragment_textures))
    {
        for(int i=0; i<MAX_TEXTURE_UNITS; i++)
        {
            if (STATE(enabled_fragment_textures) & (0x1 << i))
            {
                VENG(baseVertex.st[i][0]) =
                VENG(baseVertex.st[i][1]) = 0.0;
            }
        }
    }
}
