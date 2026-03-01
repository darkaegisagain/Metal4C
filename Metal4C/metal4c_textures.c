//
//  metal4c_textures.c
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

MTuint mtCreateTexture2D(MTuint format, MTuint width, MTuint height, size_t pitch, void *data)
{
    MTTexture *tex;
    
    tex = newPtr(MTTexture);
    
    tex->format     = format;
    tex->width      = width;
    tex->height     = height;
    tex->pitch      = pitch;
        
    _ctx->mt_render_funcs.mtlCreateTexture2D(_ctx, tex, data);

    if (tex->mtl_tex == NULL)
    {
        mtWarningFunc("%s failed to create texture", __FUNCTION__);
        free(tex);
        return 0;
    }
    
    MTuint name;
    
    name = getNewName(STATE(texture_table));
    insertHashElement(STATE(texture_table), name, tex);
    
    tex->name = name;
    
    return name;
}

// mtCreateTextureFromFile will try to load a file from a path
// if it fails from the path directly it will try to load it as a NSBundle file
MTuint mtCreateTextureFromFile(const char *path)
{
    MTTexture *tex;
    
    tex = newPtr(MTTexture);
    
    _ctx->mt_render_funcs.mtlCreateTextureFromPath(_ctx, tex, path);

    if (tex->mtl_tex == NULL)
    {
        mtWarningFunc("failed to create texture", __FUNCTION__);
        free(tex);
        return 0;
    }
    
    MTuint name;
    
    name = getNewName(STATE(texture_table));
    insertHashElement(STATE(texture_table), name, tex);
    
    tex->name = name;
    
    return name;

}


void mtBindVertexTexture(MTuint name, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("%s name > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    if (name)
    {
        STATE(enabled_vertex_textures) |= (0x1 << unit);
    }
    else
    {
        STATE(enabled_vertex_textures) &= ~(0x1 << unit);
    }
    
    STATE(vertex_textures[unit]) = name;
    _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
}

void mtBindFragmentTexture(MTuint name, MTuint unit)
{
    if (unit > MAX_TEXTURE_UNITS)
    {
        mtWarningFunc("%s name > MAX_TEXTURE_UNITS", __FUNCTION__);
        return;
    }
    
    if (name)
    {
        STATE(enabled_fragment_textures) |= (0x1 << unit);
    }
    else
    {
        STATE(enabled_fragment_textures) &= ~(0x1 << unit);
    }
    
    STATE(fragment_textures[unit]) = name;
    _ctx->dirty_state |= DIRTY_TEXTURE_UNIT;
}
