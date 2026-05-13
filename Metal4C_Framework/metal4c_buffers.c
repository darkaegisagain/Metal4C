//
//  metal4c_buffers.c
//  Metal4C
//
//  Created by Michael Larson on 3/16/26.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <limits.h>

#include "metal4c.h"
#include "metal4c_context.h"
#include "metal4c_hash_table.h"

size_t page_size_align(size_t size)
{
    if (size & (4096-1))
    {
        size_t pad_size = 0;

        pad_size = 4096 - (size & (4096-1));

        size += pad_size;
    }

    return size;
}

static MTBuffer *getBuffer(MTuint name, const char *func)
{
    MTBuffer *buf;
    
    if (name == 0)
    {
        buf = NULL;
    }
    else
    {
        buf = getKeyData(STATE(buffer_table), name);
        
        if (buf == NULL)
        {
            mtWarningFunc("Invalid buffer", func);
            return buf;
        }
    }
    
    return buf;
}

MTuint mtCreateBuffer(MTsizei size, MTuint flags, void *data)
{
    MTBuffer    *buf;
    
    buf = newPtr(MTBuffer);
    zeroPtr(buf, MTBuffer);

    buf->size = size;
    buf->flags = flags;

    kern_return_t err;

    buf->vm_size = page_size_align(size);

    // Allocate directly from VM
    err = vm_allocate(mach_task_self(),
                      &buf->data,
                      buf->vm_size,
                      VM_FLAGS_ANYWHERE);
    if (err)
    {
        mtWarningFunc("Out of memory", __FUNCTION__);

        free(buf);
        
        return 0;
    }

    buf->dirty |= DIRTY_BUFFER_ADDRESS;

    if (data)
    {
        memcpy((void *)buf->data, data, size);

        buf->dirty_region.offset = 0;
        buf->dirty_region.size = size;
        buf->dirty_region.next = NULL;
        
        buf->dirty |= DIRTY_BUFFER_DATA;
    }
        
    MTuint name;

    name = getNewName(STATE(buffer_table));
    insertHashElement(STATE(buffer_table), name, buf);
    
    return name;
}

void mtBufferData(MTuint buffer, MTsizei size, MTsizei offset, void *data)
{
    MTBuffer *buf;
    
    if (size <= 0)
    {
        mtWarningFunc("size <= 0", __FUNCTION__);
        return;
    }
    
    if (offset < 0)
    {
        mtWarningFunc("offset <= 0", __FUNCTION__);
        return;
    }

    buf = getBuffer(buffer, __FUNCTION__);
    
    if (buf == NULL)
    {
        return;
    }
    
    if (buf->flags & BUFFER_DATA_IMMUTABLE)
    {
        mtWarningFunc("buffer data called on immutable data buffer", __FUNCTION__);
        return;
    }
    
    if (buf->flags & BUFFER_SIZE_IMMUTABLE)
    {
        if ((offset + size) > buf->size)
        {
            mtWarningFunc("(offset + size) > buf->size on immutable buffer", __FUNCTION__);
            return;
        }
    }
    else if ((offset + size) > buf->size)
    {
        kern_return_t err;
        size_t buffer_vm_size;
        vm_address_t new_buf;
        
        buffer_vm_size = page_size_align(offset + size);

        // Allocate directly from VM
        err = vm_allocate((vm_map_t) mach_task_self(),
                          &new_buf,
                          buffer_vm_size,
                          VM_FLAGS_ANYWHERE);
        if (err)
        {
            mtWarningFunc("Out of memory unable to resize buffer", __FUNCTION__);
            
            return;
        }

        // update new buffer with old data
        memcpy((void *)new_buf, (void *)buf->data, buf->size);

        // deallocate old buffer
        vm_deallocate((vm_map_t) mach_task_self(),
                      buf->data,
                      buf->vm_size);

        buf->size = size;
        buf->data = new_buf;
        buf->vm_size = buffer_vm_size;
        
        buf->dirty |= DIRTY_BUFFER_ADDRESS;
    }
    
    // if this is bound to the current vao we need to dirty the context state
    if (STATE(vao))
    {
        for(int i=0; i<MAX_VERTEX_ATTIBS; i++)
        {
            // early exit
            if (STATE(vertex_bindings_mask >> i) == 0)
            {
                break;
            }

            if (STATE(vertex_buffers[i]) == buf)
            {
                _ctx->dirty_state |= DIRTY_BUFFER;
                break;
            }
        }

        for(int i=0; i<MAX_VERTEX_ATTIBS; i++)
        {
            // early exit
            if (STATE(fragment_bindings_mask >> i) == 0)
            {
                break;
            }

            if (STATE(fragment_buffers[i]) == buf)
            {
                _ctx->dirty_state |= DIRTY_BUFFER;
                break;
            }
        }
    }
    
    if (data)
    {
        memcpy((void *)buf->data + offset, data, size);
        
        // if this is a partial fill add regions
        if ((offset != 0) || (size < buf->size))
        {
            // buffer is already dirty, need to alloc a new dirty region
            if (buf->dirty & DIRTY_BUFFER_DATA)
            {
                if ((buf->dirty_region.offset == 0) && (buf->dirty_region.size == buf->size))
                {
                    // do nothing all of buffer is dirty
                }
                else
                {
                    MTDirtyRegion   *ptr;
                    
                    ptr = &buf->dirty_region;
                    
                    // dirty region size is set to zero on clearing
                    if (ptr->size != 0)
                    {
                        // we are not dealing with first element, so add an element to the list
                        while(ptr->next)
                        {
                            ptr = ptr->next;
                        }
                        
                        if (_ctx->free_dirty_region_list)
                        {
                            ptr->next = _ctx->free_dirty_region_list;
                            _ctx->free_dirty_region_list = _ctx->free_dirty_region_list->next;
                        }
                        else
                        {
                            ptr->next = newPtr(MTDirtyRegion);
                        }
                        
                        ptr = ptr->next;
                    }
                    
                    ptr->offset = offset;
                    ptr->size = size;
                    ptr->next = NULL;
                }
            }
            else
            {
                buf->dirty_region.offset = offset;
                buf->dirty_region.size = size;
            }
        }
        else
        {
            // full fill
            buf->dirty_region.offset = offset;
            buf->dirty_region.size = size;
            
            // remove any regions if they were added
            // should be a warning here
            if (buf->dirty_region.next)
            {
                MTDirtyRegion *ptr;
                
                ptr = buf->dirty_region.next;
                
                while(ptr)
                {
                    MTDirtyRegion *temp;
                    
                    temp = ptr->next;
                    
                    ptr->next = _ctx->free_dirty_region_list;
                    _ctx->free_dirty_region_list = ptr;
                    
                    ptr = temp;
                }
            }
        }
        
        buf->dirty |= DIRTY_BUFFER_DATA;
    }
}

void mtBufferSubData(MTuint buffer, MTsizei size, MTsizei offset, void *data)
{
    assert(0);
}

void mtDeleteBuffer(MTuint buffer)
{
    if (buffer == 0)
    {
        // quietly return
        return;
    }
    
    MTBuffer *buf;
    
    buf = getBuffer(buffer, __FUNCTION__);
    
    if (buf == NULL)
    {
        return;
    }

    if (buf->mtl_buffer)
    {
        _ctx->mt_render_funcs.mtlCFBridgingRelease(buf->mtl_buffer);
        
        buf->mtl_buffer = NULL;
    }
    
    // deallocate buffer
    vm_deallocate((vm_map_t) mach_task_self(),
                  buf->data,
                  buf->size);

    deleteHashElement(STATE(buffer_table), buffer);
}

MTuint mtCreateVertexArray(void)
{
    MTVertexArray *vao;
    
    vao = newPtr(MTVertexArray);    
    zeroPtr(vao, MTVertexArray);
    
    vao->name = getNewName(STATE(vertex_array_table));
    insertHashElement(STATE(vertex_array_table), vao->name, vao);
    
    return vao->name;
}

void mtBindVertexArray(MTuint name)
{
    MTVertexArray *vao;
    
    if (name)
    {
        vao = getKeyData(STATE(vertex_array_table), name);
        
        if (vao == NULL)
        {
            mtWarningFunc("Invalid vertex array", __FUNCTION__);
            return;
        }
        
        STATE(vao) = vao;
    }
    else
    {
        STATE(vao) = NULL;
    }
    
    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtBindVertexBuffer(MTuint name, MTuint unit)
{
    if (unit >= MAX_BUFFER_BINDINGS)
    {
        mtWarningFunc("unit >= MAX_BUFFER_BINDINGS", __FUNCTION__);
        return;
    }
    
    MTBuffer *buf;

    if (name)
    {
        buf = getBuffer(name, __FUNCTION__);
        
        if (buf == NULL)
        {
            return;
        }

        STATE(vertex_bindings_mask) |= (0x1 << unit);
    }
    else
    {
        buf = NULL;

        STATE(vertex_bindings_mask) &= ~(0x1 << unit);
    }
    
    STATE(vertex_buffers[unit]) = buf;
    
    _ctx->dirty_state |= DIRTY_RENDER_STATE | DIRTY_BUFFER;
}

void mtBindFragmentBuffer(MTuint name, MTuint unit)
{
    if (unit >= MAX_BUFFER_BINDINGS)
    {
        mtWarningFunc("unit >= MAX_BUFFER_BINDINGS", __FUNCTION__);
        return;
    }
    
    MTBuffer *buf;

    if (name)
    {
        buf = getBuffer(name, __FUNCTION__);
        
        if (buf == NULL)
        {
            return;
        }

        STATE(fragment_bindings_mask) |= (0x1 << unit);
    }
    else
    {
        buf = NULL;

        STATE(fragment_bindings_mask) &= ~(0x1 << unit);
    }
    
    STATE(fragment_buffers[unit]) = buf;
    
    _ctx->dirty_state |= DIRTY_RENDER_STATE | DIRTY_BUFFER;
}

void mtDeleteVertexArray(MTuint name)
{
    if (name == 0)
    {
        // quietly return
        return;
    }
    
    MTVertexArray *vao;
    
    vao = getKeyData(STATE(vertex_array_table), name);
    
    if (vao == NULL)
    {
        mtWarningFunc("Invalid vertex array", __FUNCTION__);
        return;
    }

    deleteHashElement(STATE(vertex_array_table), name);
}

void mtVertexDescAttr(MTuint unit, MTenum format, MTuint offset, MTuint buffer_index)
{
    if (unit >= MAX_BUFFER_BINDINGS)
    {
        mtWarningFunc("unit >= MAX_BUFFER_BINDINGS", __FUNCTION__);
        return;
    }
    
    if (format >= MTVertexFormatMax)
    {
        mtWarningFunc("format >= MTVertexFormatMax", __FUNCTION__);
        return;
    }
    
    if (format == MTVertexFormatInvalid)
    {
        mtWarningFunc("format == MTVertexFormatInvalid", __FUNCTION__);
        return;
    }
    
    if (STATE(vao) == NULL)
    {
        mtWarningFunc("no current vertex array bound", __FUNCTION__);
        return;
    }
    
    STATE(vao)->vertex_desc_mask |= (0x1 << unit);
    STATE(vao)->vertex_arrays[unit].format = format;
    STATE(vao)->vertex_arrays[unit].offset = offset;
    STATE(vao)->vertex_arrays[unit].buffer_index = buffer_index;
    
    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtVertexDescLayout(MTuint unit, MTuint stride, MTenum step_function, MTuint step_rate)
{
    if (unit >= MAX_BUFFER_BINDINGS)
    {
        mtWarningFunc("unit >= MAX_BUFFER_BINDINGS", __FUNCTION__);
        return;
    }
    
    if (step_function >= MTVertexStepFunctionMax)
    {
        mtWarningFunc("format >= MTVertexFormatMax", __FUNCTION__);
        return;
    }
    
    if (step_rate == 0)
    {
        mtWarningFunc("step_rate == 0", __FUNCTION__);
        return;
    }
    
    STATE(vao)->vertex_arrays[unit].stride = stride;
    STATE(vao)->vertex_arrays[unit].step_function = step_function;
    STATE(vao)->vertex_arrays[unit].step_rate = step_rate;
    
    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

void mtVertexDesc(MTuint unit, MTenum format, MTuint offset, MTuint buffer_index,
                  MTuint stride, MTenum step_function, MTuint step_rate)
{
    if (unit >= MAX_BUFFER_BINDINGS)
    {
        mtWarningFunc("unit >= MAX_BUFFER_BINDINGS", __FUNCTION__);
        return;
    }
    
    if (format >= MTVertexFormatMax)
    {
        mtWarningFunc("format >= MTVertexFormatMax", __FUNCTION__);
        return;
    }
    
    if (format == MTVertexFormatInvalid)
    {
        mtWarningFunc("format == MTVertexFormatInvalid", __FUNCTION__);
        return;
    }
    
    if (step_function >= MTVertexStepFunctionMax)
    {
        mtWarningFunc("format >= MTVertexFormatMax", __FUNCTION__);
        return;
    }
    
    if (step_rate == 0)
    {
        mtWarningFunc("step_rate == 0", __FUNCTION__);
        return;
    }
    
    if (STATE(vao) == NULL)
    {
        mtWarningFunc("no current vertex array bound", __FUNCTION__);
        return;
    }
    
    STATE(vao)->vertex_desc_mask |= (0x1 << unit);
    
    STATE(vao)->vertex_arrays[unit].format = format;
    STATE(vao)->vertex_arrays[unit].offset = offset;
    STATE(vao)->vertex_arrays[unit].buffer_index = buffer_index;
    STATE(vao)->vertex_arrays[unit].stride = stride;
    STATE(vao)->vertex_arrays[unit].step_function = step_function;
    STATE(vao)->vertex_arrays[unit].step_rate = step_rate;
    
    _ctx->dirty_state |= DIRTY_RENDER_PASS;
}

void mtClearDesc(MTuint unit)
{
    if (unit >= MAX_BUFFER_BINDINGS)
    {
        mtWarningFunc("unit >= MAX_BUFFER_BINDINGS", __FUNCTION__);
        return;
    }

    if (STATE(vao) == NULL)
    {
        mtWarningFunc("no current vertex array bound", __FUNCTION__);
        return;
    }
    
    STATE(vao)->vertex_desc_mask &= ~(0x1 << unit);

    STATE(vao)->vertex_arrays[unit].format = MTVertexFormatInvalid;
    STATE(vao)->vertex_arrays[unit].offset = 0;
    STATE(vao)->vertex_arrays[unit].buffer_index = 0;
    STATE(vao)->vertex_arrays[unit].stride = 0;
    STATE(vao)->vertex_arrays[unit].step_function = 0;
    STATE(vao)->vertex_arrays[unit].step_rate = 0;

    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

#pragma mark mtBindIndexBuffer
void mtBindIndexBuffer(MTuint name)
{
    STATE(index_buffer) = getBuffer(name, __FUNCTION__);
}

#pragma mark mtBindInstanceBuffer
void mtBindInstanceBuffer(MTuint name)
{
    STATE(instance_buffer) = getBuffer(name, __FUNCTION__);
}

static MTbool checkDrawArrayArgs(MTPrimitiveType type, const char *func)
{
    if (type >= MTPrimitiveTypeNone)
    {
        mtWarningFunc("type >= MTPrimitiveTypeNone", func);
        
        return false;
    }
    
    if (STATE(vao) == NULL)
    {
        mtWarningFunc("no current vertex array bound", func);
        
        return false;
    }
    
    return true;
}

static MTbool checkDrawElementArgs(MTPrimitiveType type, const char *func)
{
    if (type >= MTPrimitiveTypeNone)
    {
        mtWarningFunc("type >= MTPrimitiveTypeNone", func);
        
        return false;
    }
    
    if (STATE(vao) == NULL)
    {
        mtWarningFunc("no current vertex array bound", func);
        
        return false;
    }

    if (STATE(index_buffer) == NULL)
    {
        mtWarningFunc("no current index buffer bound", __FUNCTION__);
        
        return false;
    }
    
    return true;
}

void updateShaderModeState(MTDrawArrayPrimitive *draw)
{
    switch(draw->draw_style)
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
    
    STATE(prim_type) = draw->type;
    _ctx->dirty_state |= DIRTY_UPLOADED_STATE;
}


void mtDrawArray(MTPrimitiveType type, MTsizei offset, MTsizei count)
{
    if (checkDrawArrayArgs(type, __FUNCTION__) == false)
    {
        return;
    }
    
    MTDrawArrayPrimitive draw;
    
    draw.type = type;
    draw.draw_style = MTPrimitveDrawArray;
    draw.offset = offset;
    draw.count = count;
    
    updateShaderModeState(&draw);
    
    _ctx->mt_render_funcs.mtlDrawArray(_ctx, &draw);
}

void mtDrawArrayInstance(MTPrimitiveType type, MTsizei offset, MTsizei count, MTuint instance_count, MTuint base_instance)
{
    if (checkDrawArrayArgs(type, __FUNCTION__) == false)
    {
        return;
    }
    
    MTDrawArrayPrimitive draw;
    
    draw.type = type;
    draw.draw_style = MTPrimitveDrawArrayInstance;
    draw.offset = offset;
    draw.count = count;
    draw.base_vertex = 0;
    draw.base_instance = base_instance;
    draw.instance_count = instance_count;

    updateShaderModeState(&draw);

    _ctx->mt_render_funcs.mtlDrawArray(_ctx, &draw);
}

void mtDrawElements(MTPrimitiveType type, MTIndexType index_type, MTsizei offset, MTsizei count)
{
    if (checkDrawElementArgs(type, __FUNCTION__) == false)
    {
        return;
    }
    
    MTDrawArrayPrimitive draw;
    
    draw.type = type;
    draw.draw_style = MTPrimitveDrawIndex;
    draw.index_type = index_type;
    draw.offset = offset;
    draw.count = count;
    draw.instance_count = 1;
    
    updateShaderModeState(&draw);

    _ctx->mt_render_funcs.mtlDrawArray(_ctx, &draw);
}

void mtDrawElementsInstance(MTPrimitiveType type, MTIndexType index_type, MTsizei offset, MTsizei count, MTuint instance_count)
{
    if (checkDrawElementArgs(type, __FUNCTION__) == false)
    {
        return;
    }
    
    MTDrawArrayPrimitive draw;
    
    draw.type = type;
    draw.draw_style = MTPrimitveDrawIndexInstance;
    draw.index_type = index_type;
    draw.offset = offset;
    draw.count = count;
    draw.instance_count = instance_count;
    draw.base_vertex = 0;
    draw.base_instance = 0;

    updateShaderModeState(&draw);

    _ctx->mt_render_funcs.mtlDrawArray(_ctx, &draw);
}

void mtDrawElementsInstanceBase(MTPrimitiveType type, MTIndexType index_type, MTsizei count, MTuint instance_count, MTuint base_instance)
{
    if (checkDrawElementArgs(type, __FUNCTION__) == false)
    {
        return;
    }
    
    MTDrawArrayPrimitive draw;
    
    draw.type = type;
    draw.draw_style = MTPrimitveDrawIndexInstanceBase;
    draw.index_type = index_type;
    draw.offset = 0;
    draw.count = count;
    draw.instance_count = instance_count;
    draw.base_vertex = 0;
    draw.base_instance = base_instance;
    
    updateShaderModeState(&draw);

_ctx->mt_render_funcs.mtlDrawArray(_ctx, &draw);
}

void mtDrawElementsOffsetInstanceBase(MTPrimitiveType type, MTIndexType index_type, MTsizei offset, MTsizei count, MTuint instance_count, MTuint base_vertex, MTuint base_instance)
{
    if (checkDrawElementArgs(type, __FUNCTION__) == false)
    {
        return;
    }
    
    MTDrawArrayPrimitive draw;
    
    draw.type = type;
    draw.draw_style = MTPrimitveDrawIndexOffsetInstanceBase;
    draw.index_type = index_type;
    draw.offset = offset;
    draw.count = count;
    draw.instance_count = instance_count;
    draw.base_vertex = base_vertex;
    draw.base_instance = base_instance;
    
    updateShaderModeState(&draw);

_ctx->mt_render_funcs.mtlDrawArray(_ctx, &draw);
}
