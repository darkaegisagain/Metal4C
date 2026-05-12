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
#include "metal4c_Renderer_Extern.h"
#include "metal4c_hash_table.h"

void updateVengShaderModeState(MTPritiveDrawStyle type)
{
    switch(type)
    {
        case MTPrimitveDrawArray:
        case MTPrimitveDrawIndex:
            if (STATE(vertex_shader_mode) != MTVertexShaderModeNonInstanced)
            {
                STATE(vertex_shader_mode) = MTVertexShaderModeNonInstanced;
                
                _ctx->dirty_state |= DIRTY_PIPELINE;
            }
            break;
            
        case MTPrimitveDrawArrayInstance:
        case MTPrimitveDrawIndexInstance:
        case MTPrimitveDrawIndexInstanceBase:
        case MTPrimitveDrawIndexOffsetInstanceBase:
            if (STATE(vertex_shader_mode) != MTVertexShaderModeInstanced)
            {
                STATE(vertex_shader_mode) = MTVertexShaderModeInstanced;
                
                _ctx->dirty_state |= DIRTY_PIPELINE;
            }
            break;
    }
}

static inline void setBeginState(MTPrimitiveType type, MTPritiveDrawStyle style, MTuint instance_count, MTint base_vertex, MTuint base_instance)
{
    MTbool use_elements;
    
    switch(style)
    {
        case MTPrimitveDrawIndex:
        case MTPrimitveDrawIndexInstance:
        case MTPrimitveDrawIndexInstanceBase:
        case MTPrimitveDrawIndexOffsetInstanceBase:
            use_elements = 1;
            break;
            
        default:
            use_elements = 0;
            break;
    }
    
    STATE(in_begin_end)         = 1;
    STATE(in_element_begin_end) = use_elements;
    STATE(prim_type)            = type;
    VENG(instance_count)        = instance_count;
    VENG(base_vertex)           = base_vertex;
    VENG(base_instance)         = base_instance;
    VENG(current_vertex)        = 0;
    VENG(current_index)         = 0;
    VENG(max_index_submitted)   = 0;
    
    updateVengShaderModeState(style);
    
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}

#define CHECK_IN_BEGIN_END() \
if (STATE(in_begin_end)) \
{ \
    mtWarningFunc("%s in_begin_end, inside mtBegin block", __FUNCTION__); \
\
    return; \
}

#define CHECK_INSTANCE_BUFFER() \
if (STATE(instance_buffer) == NULL) \
{ \
    mtWarningFunc("%s no instance buffer bound", __FUNCTION__); \
\
    return; \
}

#define CHECK_VAO_BOUND() \
if (STATE(vao)) \
{ \
    mtWarningFunc("%s vao bound", __FUNCTION__); \
\
    return; \
}

void mtBegin(MTPrimitiveType type)
{
    
    CHECK_IN_BEGIN_END();
    
    CHECK_VAO_BOUND();
    
    setBeginState(type, MTPrimitveDrawArray, 1, 0, 0);
    
    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

void mtBeginInstance(MTPrimitiveType type, MTuint instance_count)
{
    CHECK_IN_BEGIN_END();

    CHECK_VAO_BOUND();
    
    // setBeginState(MTPrimitiveType type, MTPritiveDrawStyle style, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
    setBeginState(type, MTPrimitveDrawArrayInstance, instance_count, 0, 0);
    
    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

void mtBeginBaseInstance(MTPrimitiveType type, MTuint instance_count, MTuint base_instance)
{
    CHECK_IN_BEGIN_END();

    CHECK_VAO_BOUND();
    
    // setBeginState(MTPrimitiveType type, MTPritiveDrawStyle style, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
    setBeginState(type, MTPrimitveDrawArrayInstance, instance_count, base_instance, 0);
    
    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

void mtBeginElement(MTPrimitiveType type)
{
    CHECK_IN_BEGIN_END();

    CHECK_VAO_BOUND();
    
    // setBeginState(MTPrimitiveType type, MTPritiveDrawStyle style, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
    setBeginState(type, MTPrimitveDrawIndex, 1, 0, 0);

    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

void mtBeginElementInstance(MTPrimitiveType type, MTuint instance_count)
{
    CHECK_IN_BEGIN_END();

    CHECK_INSTANCE_BUFFER();
    
    CHECK_VAO_BOUND();
    
    // setBeginState(MTPrimitiveType type, MTPritiveDrawStyle style, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
    setBeginState(type, MTPrimitveDrawIndexInstance, instance_count, 0, 0);
    
    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

void mtBeginElementBaseInstance(MTPrimitiveType type, MTuint instance_count, MTuint base_instance)
{
    CHECK_IN_BEGIN_END();

    CHECK_INSTANCE_BUFFER();

    CHECK_VAO_BOUND();
    
    // setBeginState(MTPrimitiveType type, MTPritiveDrawStyle style, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
    setBeginState(type, MTPrimitveDrawIndexInstanceBase, instance_count, 0, base_instance);

    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

void mtBeginElementBaseVertexInstance(MTPrimitiveType type, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
{
    CHECK_IN_BEGIN_END();

    CHECK_INSTANCE_BUFFER();

    CHECK_VAO_BOUND();
    
    // setBeginState(MTPrimitiveType type, MTPritiveDrawStyle style, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
    setBeginState(type, MTPrimitveDrawIndexInstanceBase, instance_count, base_vertex, base_instance);

    _ctx->mt_render_funcs.mtlBegin(_ctx, type);
}

static inline void clearEndState(void)
{
    STATE(prim_type)            = MTPrimitiveTypeNone;
    STATE(in_begin_end)         = 0;
    STATE(in_element_begin_end) = 0;
    VENG(instance_count)        = 0;
    VENG(base_instance)         = 0;
    VENG(base_vertex)           = 0;

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

#define CHECK_PRIMITIVE_TYPE_NONE() \
if (STATE(prim_type) == MTPrimitiveTypeNone) \
{ \
    mtWarningFunc("%s render_mode == MTPrimitiveTypeNone, call mtBegin", __FUNCTION__); \
\
    return; \
}

#define CHECK_NO_BEGIN_BLOCK() \
if (STATE(in_begin_end) == 0) \
{ \
    mtWarningFunc("%s no begin block", __FUNCTION__); \
\
    return; \
}

#define CHECK_NO_BEGIN_ELEMENT_BLOCK() \
if (STATE(in_begin_end) == 0) \
{ \
    mtWarningFunc("%s no begin element block", __FUNCTION__); \
\
    return; \
}

void mtEnd(void)
{
    CHECK_PRIMITIVE_TYPE_NONE();
    
    CHECK_NO_BEGIN_BLOCK();
    
    do {
        if (VENG(current_vertex) == 0)
            continue;
        
        if (STATE(vertex_shader_mode) == MTVertexShaderModeInstanced)
        {
            if (STATE(instance_buffer) == NULL)
            {
                mtWarningFunc("no instance buffer bound", __FUNCTION__);
                continue;
            }
        }
        
        switch(STATE(prim_type))
        {
            case MTPrimitiveTypePoint:
                if (VENG(current_vertex == 0))
                {
                    continue;
                }
                break;

            case MTPrimitiveTypeLine:
            case MTPrimitiveTypeLineStrip:
                if (VENG(current_vertex) < 2)
                {
                    mtWarningFunc("insufficent verts for MTPrimitiveTypeLine", __FUNCTION__);
                    continue;
                }
                break;
                
            case MTPrimitiveTypeTriangle:
            case MTPrimitiveTypeTriangleStrip:
                if (VENG(current_vertex) < 3)
                {
                    mtWarningFunc("insufficent verts for MTPrimitiveTypeTriangle", __FUNCTION__);
                    continue;
                }
                break;
                
            default:
                break;
        }

        _ctx->mt_render_funcs.mtlEnd(_ctx);
    } while(0);
    
    clearEndState();
}

void mtElementEnd(void)
{
    CHECK_PRIMITIVE_TYPE_NONE();

    CHECK_NO_BEGIN_ELEMENT_BLOCK();
    
    do {
        if (VENG(current_vertex) == 0)
            continue;
        
        if (STATE(vertex_shader_mode) == MTVertexShaderModeInstanced)
        {
            if (STATE(instance_buffer) == NULL)
            {
                mtWarningFunc("no instance buffer bound", __FUNCTION__);
                continue;
            }
        }
        
        if (VENG(max_index_submitted) >= VENG(current_vertex))
        {
            mtWarningFunc("max_index_submitted out of range with submitted vertex count", __FUNCTION__);
            continue;
        }
        
        switch(STATE(prim_type))
        {
            case MTPrimitiveTypePoint:
                if (VENG(current_vertex == 0))
                {
                    continue;
                }
                break;

            case MTPrimitiveTypeLine:
            case MTPrimitiveTypeLineStrip:
                if (VENG(current_vertex) < 2)
                {
                    mtWarningFunc("insufficent verts for MTPrimitiveTypeLine", __FUNCTION__);
                    continue;
                }
                break;
                
            case MTPrimitiveTypeTriangle:
            case MTPrimitiveTypeTriangleStrip:
                if (VENG(current_vertex) < 3)
                {
                    mtWarningFunc("insufficent verts for MTPrimitiveTypeTriangle", __FUNCTION__);
                    continue;
                }
                break;
                
            default:
                break;
        }

        _ctx->mt_render_funcs.mtlEnd(_ctx);
    } while(0);
    

    clearEndState();
}

void mtColor3f(MTfloat r, MTfloat g, MTfloat b)
{
    mtColor4f(r, g, b, 1.0);
}

void mtColor4f(MTfloat r, MTfloat g, MTfloat b, MTfloat a)
{
    VENG(baseVertex.color.r) = r;
    VENG(baseVertex.color.g) = g;
    VENG(baseVertex.color.b) = b;
    VENG(baseVertex.color.a) = a;
}

void mtColor3fv(MTfloat *ptr)
{
    VENG(baseVertex.color.r) = *ptr++;
    VENG(baseVertex.color.g) = *ptr++;
    VENG(baseVertex.color.b) = *ptr;
    VENG(baseVertex.color.a) = 1.0;
}

void mtColor4fv(MTfloat *ptr)
{
    VENG(baseVertex.color.r) = *ptr++;
    VENG(baseVertex.color.g) = *ptr++;
    VENG(baseVertex.color.b) = *ptr++;
    VENG(baseVertex.color.a) = *ptr;
}

void mtNormalf(MTfloat x, MTfloat y, MTfloat z)
{
    VENG(baseVertex.normal.x) = x;
    VENG(baseVertex.normal.y) = y;
    VENG(baseVertex.normal.z) = z;
    VENG(baseVertex.normal.w) = 0.0;
}

void mtNormalfv(MTfloat *ptr)
{
    VENG(baseVertex.normal.x) = *ptr++;
    VENG(baseVertex.normal.y) = *ptr++;
    VENG(baseVertex.normal.z) = *ptr++;
    VENG(baseVertex.normal.w) = 0.0;
}

void mtTexf(MTfloat s, MTfloat t)
{
    VENG(baseVertex.st[0][0]) = s;
    VENG(baseVertex.st[0][1]) = t;
}

void mtTexfv(MTfloat *ptr)
{
    VENG(baseVertex.st[0][0]) = *ptr++;
    VENG(baseVertex.st[0][1]) = *ptr;
}

void mtTexfUnitf(MTfloat s, MTfloat t, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("unit > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    VENG(baseVertex.st[unit][0]) = s;
    VENG(baseVertex.st[unit][1]) = t;
}

void mtTexfUnitfv(MTfloat *ptr, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("unit > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    VENG(baseVertex.st[unit][0]) = *ptr++;
    VENG(baseVertex.st[unit][1]) = *ptr;
}

void mtIndex(MTuint index)
{
    VENG(indices[VENG(current_index)]) = index;
         
    if (index > VENG(max_index_submitted))
    {
        VENG(max_index_submitted) = index;
    }
    
    VENG(current_index++);

    if (VENG(current_index) == VENG(num_indices))
    {
        if (VENG(num_indices) == VENG(max_indices))
        {
            mtErrorFunc("num indices maxed out", __FUNCTION__);
            return;
        }
        
        VENG(num_indices) *= 2;
        
        VENG(indices) = (MTuint *)realloc((void *)VENG(indices), VENG(num_indices) * sizeof(MTuint));
    }
}

void mtVertex2f(MTfloat x, MTfloat y)
{
    mtVertex4f(x, y, 0, 1);
}

void mtVertex3f(MTfloat x, MTfloat y, MTfloat z)
{
    mtVertex4f(x, y, z, 1);
}

void mtVertex4f(MTfloat x, MTfloat y, MTfloat z, MTfloat w)
{
    if (STATE(in_begin_end) == 0)
    {
        mtWarningFunc("%s no begin block", __FUNCTION__);
        
        return;
    }
    
    VENG(vertices[VENG(current_vertex)].color)   = VENG(baseVertex.color);
    VENG(vertices[VENG(current_vertex)].normal)  = VENG(baseVertex.normal);

    if (STATE(enabled_fragment_textures))
    {
        for(int i=0; i<MAX_TEXTURE_UNITS; i++)
        {
            if ((STATE(enabled_fragment_textures) >> i) == 0)
            {
                break;
            }

            if (STATE(enabled_fragment_textures) & (0x1 << i))
            {
                VENG(vertices[VENG(current_vertex)].st[i]) = VENG(baseVertex.st[i]);
            }
        }
    }
    
    VENG(vertices[VENG(current_vertex)].position.x) = x;
    VENG(vertices[VENG(current_vertex)].position.y) = y;
    VENG(vertices[VENG(current_vertex)].position.z) = z;
    VENG(vertices[VENG(current_vertex)].position.w) = w;

    VENG(current_vertex++);
    
    if (STATE(in_element_begin_end))
    {
        if (VENG(current_vertex) == VENG(num_vertices))
        {
            if (VENG(num_vertices) == VENG(max_vertices))
            {
                mtErrorFunc("num vertcies maxed out", __FUNCTION__);
                return;
            }
            
            VENG(num_vertices) *= 2;
            
            VENG(vertices) = (Vertex4ColorNormalTex *)realloc((void *)VENG(vertices), VENG(num_vertices) * sizeof(Vertex4ColorNormalTex));
            
            _ctx->dirty_state |= DIRTY_VERTEX_ENGINE_SIZES;
        }
    }
    else
    {
        if (VENG(current_vertex) == VENG(num_vertices))
        {
            _ctx->mt_render_funcs.mtlFlushVertexEng(_ctx);
            
            // strips need to be restarted
            if (STATE(prim_type) == MTPrimitiveTypeLineStrip)
            {
                // restart line strip
                VENG(vertices[0]) = VENG(vertices[VENG(current_vertex) - 1]);
                
                VENG(current_vertex) = 1;
            }
            else if (STATE(prim_type) == MTPrimitiveTypeTriangleStrip)
            {
                // restart triangle strip
                VENG(vertices[0]) = VENG(vertices[VENG(current_vertex) - 2]);
                VENG(vertices[1]) = VENG(vertices[VENG(current_vertex) - 1]);
                
                VENG(current_vertex) = 2;
            }
            else
            {
                VENG(current_vertex) = 0;
            }
        }
    }
}

void mtVertex2fv(MTfloat *ptr)
{
    mtVertex4f(ptr[0], ptr[1], 0, 1);
}

void mtVertex3fv(MTfloat *ptr)
{
    mtVertex4f(ptr[0], ptr[1], ptr[2], 1);
}

void mtVertex4fv(MTfloat *ptr)
{
    mtVertex4f(ptr[0], ptr[1], ptr[2], ptr[4]);
}

