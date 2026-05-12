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
#include "metal4c_Renderer_Extern.h"
#include "metal4c_hash_table.h"

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

static MTbool bindShaderFunc(MTuint name, const char *func_name, MTShaderBinding *binding, const char *_calling_func_)
{
    // handle null binding
    if (name == 0)
    {
        binding->lib    = 0;
        binding->shader = NULL;
        
        return true;
    }

    // handle bad params
    if (func_name == NULL)
    {
        mtWarningFunc("func_name == NULL, leaving state unchanged", _calling_func_);

        return false;
    }
    
    MTShaderLibrary *shader_lib;
    
    shader_lib = getKeyData(STATE(shader_table), name);
    
    if (shader_lib == NULL)
    {
        mtWarningFunc("Shader lib not found, leaving state unchanged", _calling_func_);
        return false;
    }
    
    MTbool shader_found;
    MTuint shader_index;
    const char *lib_func;

    // init to null so compiler won't bitch
    lib_func = NULL;
    
    shader_found = false;
    shader_index = 0;

    for(int i=0; i<shader_lib->function_count; i++)
    {
        if (shader_found == 0)
        {
            if (!strcmp(func_name, shader_lib->function_names[i]))
            {
                shader_found = true;
                shader_index = i;
                lib_func = shader_lib->function_names[i]; // use this pointer name to bind to

                binding->lib            = name;
                binding->shader         = lib_func;
                binding->shader_lib     = shader_lib;
                binding->shader_index   = shader_index;
                
                return true;
            }
        }
    }
    
    char warning[128];
    
    snprintf(warning, 128, "shader %s not found in library %d, leaving state unchanged\n", func_name, name);

    mtWarningFunc(warning, _calling_func_);
    
    return false;
}

static MTbool checkRendermodes(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode)
{
    switch(vertex_rendermode)
    {
        case MTVertexShaderModeNonInstanced:
        case MTVertexShaderModeInstanced:
            break;
            
        default:
            mtWarningFunc("invalid vertex rendermode", __FUNCTION__);
            return false;
    }

    switch(fragment_rendermode)
    {
        case MTFragmentShaderModeColor:
        case MTFragmentShaderModeNormal:
        case MTFragmentShaderModeColorNormal:
        case MTFragmentShaderModeTexture:
        case MTFragmentShaderModeColorTexture:
        case MTFragmentShaderModeNormalTexture:
        case MTFragmentShaderModeColorNormalTexture:
        case MTFragmentShaderModeAll:
            break;

        default:
            mtWarningFunc("invalid vertex rendermode", __FUNCTION__);
            return false;
    }

    return true;
}

void mtBindImmModeVertexShader(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode, MTuint name, const char *vertex)
{
    if (checkRendermodes(vertex_rendermode, fragment_rendermode))
    {
        if(fragment_rendermode == MTFragmentShaderModeAll)
        {
            for(int i=MTFragmentShaderModeColor; i<MTFragmentShaderModeMax; i++)
            {
                bindShaderFunc(name, vertex, &STATE(vertex_shader_binding[vertex_rendermode][i]), __FUNCTION__);
            }
        }
        else
        {
            bindShaderFunc(name, vertex, &STATE(vertex_shader_binding[vertex_rendermode][fragment_rendermode]), __FUNCTION__);
        }
    }
}

void mtBindImmModeFragmentShader(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode, MTuint name, const char *fragment)
{
    if (checkRendermodes(vertex_rendermode, fragment_rendermode))
    {
        if(fragment_rendermode == MTFragmentShaderModeAll)
        {
            for(int i=MTFragmentShaderModeColor; i<MTFragmentShaderModeMax; i++)
            {
                bindShaderFunc(name, fragment, &STATE(vertex_shader_binding[vertex_rendermode][i]), __FUNCTION__);
            }
        }
        else
        {
            bindShaderFunc(name, fragment, &STATE(fragment_shader_binding[vertex_rendermode][fragment_rendermode]), __FUNCTION__);
        }
    }
}

void mtBindVertexShaderToVertexArray(MTuint vao_name, MTuint lib_name, const char *vertex)
{
    MTVertexArray *vao;
    MTShaderBinding *binding;
    
    vao = getKeyData(STATE(vertex_array_table), vao_name);
    
    if (vao == NULL)
    {
        return;
    }
    
    binding = &vao->vertex_shader_binding;
    
    bindShaderFunc(lib_name, vertex, binding, __FUNCTION__);
}

void mtBindFragmentToVertexArray(MTuint vao_name, MTuint lib_name, const char *fragment)
{
    MTVertexArray *vao;
    MTShaderBinding *binding;
    
    vao = getKeyData(STATE(vertex_array_table), vao_name);
    
    if (vao == NULL)
    {
        return;
    }
    
    binding = &vao->vertex_shader_binding;
    
    bindShaderFunc(lib_name, fragment, binding, __FUNCTION__);
}

