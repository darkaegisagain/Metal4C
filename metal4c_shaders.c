//
//  metal4c_shaders.c
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

MTuint mtCreateShaderLibrary(const char *str)
{
    MTShaderLibrary *lib;
    
    lib = newPtr(MTShaderLibrary);
    lib->src = strdup(str);
    
    _ctx->mt_render_funcs.mtlCreateShaderLibrary(_ctx, lib);
    
    if (lib->mtl_lib == NULL)
    {
        mtWarningFunc("mtCreateShaderLibrary failed", __FUNCTION__);
        free(lib);
        return 0;
    }
    
    MTuint name;
    
    name = getNewName(STATE(shader_table));
    insertHashElement(STATE(shader_table), name, lib);
    
    lib->name = name;
    
    return lib->name;
}

void mtBindShaderFunctions(MTuint name, const char *vertex, const char *fragment, MTuint rendermode)
{
    MTShaderLibrary *shader_lib;
    MTbool vertex_shader_found;
    MTbool fragment_shader_found;
    MTuint vertex_shader_index;
    MTuint fragment_shader_index;
    const char *vertex_func;
    const char *fragment_func;

    if (rendermode >= kRendermodeMax)
    {
        mtWarningFunc("unit >= kRendermodeMax", __FUNCTION__);
        return;
    }
    
    // handle null binding
    if (name == 0)
    {
        STATE(shader_bindings[rendermode].lib) = 0;
        STATE(shader_bindings[rendermode].vertex_shader) = NULL;
        STATE(shader_bindings[rendermode].fragment_shader) = NULL;
        
        return;
    }

    // handle bad params
    if ((vertex == NULL) || (fragment == NULL))
    {
        if (vertex == NULL)
        {
            mtWarningFunc("vertex == NULL, leaving state unchanged", __FUNCTION__);
        }

        if (fragment == NULL)
        {
            mtWarningFunc("fragment == NULL, leaving state unchanged", __FUNCTION__);
        }

        return;
    }
    
    shader_lib = getKeyData(STATE(shader_table), name);
    
    if (shader_lib == NULL)
    {
        mtWarningFunc("Shader lib not found, leaving state unchanged", __FUNCTION__);
        return;
    }
    
    // init to null so compiler won't bitch
    vertex_func = NULL;
    fragment_func = NULL;
    
    vertex_shader_found = false;
    fragment_shader_found = false;
    vertex_shader_index = 0;
    fragment_shader_index = 0;

    for(int i=0; i<shader_lib->function_count; i++)
    {
        printf("%s, %s vs %s\n", vertex, fragment, shader_lib->functions[i]);
        
        if (vertex_shader_found == 0)
        {
            if (!strcmp(vertex, shader_lib->functions[i]))
            {
                vertex_shader_found = true;
                vertex_shader_index = i;
                vertex_func = shader_lib->functions[i]; // use this pointer name to bind to
            }
        }
        
        if (fragment_shader_found == 0)
        {
            if (!strcmp(fragment, shader_lib->functions[i]))
            {
                fragment_shader_found = true;
                fragment_shader_index = i;
                fragment_func = shader_lib->functions[i]; // use this pointer name to bind to
            }
        }
        
        // we found both shaders so we can bind them
        if (vertex_shader_found &&
            fragment_shader_found)
        {
            STATE(shader_bindings[rendermode].lib) = name;
            STATE(shader_bindings[rendermode].vertex_shader)   = vertex_func;
            STATE(shader_bindings[rendermode].fragment_shader) = fragment_func;

            // for debugging
            STATE(shader_bindings[rendermode].vertex_shader_index)   = vertex_shader_index;
            STATE(shader_bindings[rendermode].fragment_shader_index) = fragment_shader_index;

            return;
        }
    }
    
    if (vertex_shader_found == false)
    {
        char warning[128];
        
        snprintf(warning, 128, "vertex shader %s not found in library %d, leaving state unchanged\n", vertex, name);

        mtWarningFunc(warning, __FUNCTION__);
    }

    if (fragment_shader_found == false)
    {
        char warning[128];
        
        snprintf(warning, 128, "fragment shader %s not found in library %d, leaving state unchanged\n", fragment, name);

        mtWarningFunc(warning, __FUNCTION__);
    }
}
