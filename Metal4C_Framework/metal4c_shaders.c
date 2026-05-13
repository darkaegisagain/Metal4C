//
//  metal4c_shaders.c
//  Metal4C
//
//  Created by Michael Larson on 2/28/26.
//
/*
 Shader management for Metal4C
 - Compiles/loads Metal shader libraries from source or file
 - Registers libraries in an internal name table
 - Binds specific functions (vertex/fragment) to immediate-mode and VAO state
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "metal4c.h"
#include "metal4c_context.h"
#include "metal4c_hash_table.h"

/*
 * mtCreateShaderLibrary
 * 
 * Inputs:
 *   - str: pointer to Metal shader source code string.
 * 
 * Behavior:
 *   - Allocates a new MTShaderLibrary structure.
 *   - Copies the source string.
 *   - Delegates compilation of the Metal shader library to the backend.
 *   - Registers the library in an internal shader table with a unique name.
 * 
 * Allocation:
 *   - Allocates memory for MTShaderLibrary and duplicates the source string.
 * 
 * Registration:
 *   - Inserts the library into the global shader table with a unique handle.
 * 
 * Errors:
 *   - On compilation failure or any error, frees allocated memory and returns 0.
 */
MTuint mtCreateShaderLibrary(const char *str)
{
    MTShaderLibrary *lib;
    
    // Allocate library wrapper and copy source string
    lib = newPtr(MTShaderLibrary);
    lib->src = strdup(str);
    
    // Delegate compilation to backend rendering functions
    _ctx->mt_render_funcs.mtlCreateShaderLibrary(_ctx, lib);
    
    if (lib->mtl_lib == NULL)
    {
        // Warn and return 0 if compilation failed
        mtWarningFunc("mtCreateShaderLibrary failed", __FUNCTION__);
        free(lib);
        return 0;
    }
    
    MTuint name;
    
    // Register the library in the shader table and assign a unique name
    name = getNewName(STATE(shader_table));
    insertHashElement(STATE(shader_table), name, lib);
    
    lib->name = name;
    
    return lib->name;
}

/*
 * mtCreateShaderLibraryFromFile
 * 
 * Loads Metal Shading Language (MSL) source code from disk,
 * reads the file safely and null-terminates the source string,
 * then compiles the shader library, registers it, and returns a handle.
 * Returns 0 on any failure.
 */
#include <mach-o/dyld.h>
#include <limits.h>
#include <libgen.h>

MTuint mtCreateShaderLibraryFromFile(const char *path)
{
    MTShaderLibrary *lib;
    
    FILE            *fp;
    
    long             size;
    
    char            *src;
    
    //
    // Full resolved shader path
    //
    
    char fullpath[PATH_MAX];
    
    //
    // Executable path
    //
    
    char execpath[PATH_MAX];
    
    uint32_t execsize;
    
    //
    // Resolve executable directory
    //
    
    execsize = sizeof(execpath);
    
    if(_NSGetExecutablePath(execpath, &execsize) != 0)
    {
        mtWarningFunc("Failed to get executable path",
                      __FUNCTION__);
        
        return 0;
    }
    
    //
    // Build:
    //
    // executable_dir + "/" + relative shader path
    //
    
    snprintf(fullpath,
             sizeof(fullpath),
             "%s/%s",
             dirname(execpath),
             path);
    
    //
    // Open shader source file
    //
    
    fp = fopen(fullpath, "rb");
    
    if(fp == NULL)
    {
        mtWarningFunc(fullpath, __FUNCTION__);
        
        return 0;
    }
    
    //
    // Determine file size
    //
    
    fseek(fp, 0, SEEK_END);
    
    size = ftell(fp);
    
    rewind(fp);
    
    if(size <= 0)
    {
        fclose(fp);
        
        mtWarningFunc("Shader file empty",
                      __FUNCTION__);
        
        return 0;
    }
    
    //
    // Allocate source buffer
    //
    
    src = (char *)malloc(size + 1);
    
    if(src == NULL)
    {
        fclose(fp);
        
        mtWarningFunc("malloc failed",
                      __FUNCTION__);
        
        return 0;
    }
    
    //
    // Read shader source
    //
    
    if(fread(src, 1, size, fp) != (size_t)size)
    {
        fclose(fp);
        
        free(src);
        
        mtWarningFunc("Failed to read shader file",
                      __FUNCTION__);
        
        return 0;
    }
    
    fclose(fp);
    
    //
    // Null terminate source
    //
    
    src[size] = 0;
    
    //
    // Create shader library object
    //
    
    lib = newPtr(MTShaderLibrary);
    
    lib->src = src;
    
    //
    // Compile Metal library
    //
    
    _ctx->mt_render_funcs.mtlCreateShaderLibrary(_ctx,
                                                 lib);
    
    if(lib->mtl_lib == NULL)
    {
        mtWarningFunc("mtCreateShaderLibraryFromFile failed",
                      __FUNCTION__);
        
        free(src);
        free(lib);
        
        return 0;
    }
    
    //
    // Register object
    //
    
    MTuint name;
    
    name = getNewName(STATE(shader_table));
    
    insertHashElement(STATE(shader_table),
                      name,
                      lib);
    
    lib->name = name;
    
    return lib->name;
}
/*
 * bindShaderFunc
 *
 * Resolves a function name within a shader library by name and updates a shader binding structure.
 * Handles special cases:
 *   - If name == 0, clears (unbinds) the binding and returns true.
 *   - If func_name is NULL, warns and leaves binding unchanged.
 *   - If shader library not found or function name not found, warns and leaves binding unchanged.
 *
 * Returns true if binding succeeded or unbinding, false on error.
 */
static MTbool bindShaderFunc(MTuint name, const char *func_name, MTShaderBinding *binding, const char *_calling_func_)
{
    // Handle name == 0 by clearing binding (unbind)
    if (name == 0)
    {
        // Clear binding fields to represent no shader bound
        binding->lib    = 0;
        binding->shader = NULL;
        
        return true;
    }

    // Handle NULL function name by warning and leaving binding as-is
    if (func_name == NULL)
    {
        mtWarningFunc("func_name == NULL, leaving state unchanged", _calling_func_);

        return false;
    }
    
    MTShaderLibrary *shader_lib;
    
    // Fetch the shader library from the global table by name
    shader_lib = getKeyData(STATE(shader_table), name);
    
    // Validate handle is valid and found
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

    // Search the exported function names for exact match
    for(int i=0; i<shader_lib->function_count; i++)
    {
        if (shader_found == 0)
        {
            if (!strcmp(func_name, shader_lib->function_names[i]))
            {
                shader_found = true;
                shader_index = i;

                // Capture the pointer to the stored string to guarantee lifetime
                lib_func = shader_lib->function_names[i]; // use this pointer name to bind to

                // Fill in the binding struct with resolved info
                binding->lib            = name;
                binding->shader         = lib_func;
                binding->shader_lib     = shader_lib;
                binding->shader_index   = shader_index;
                
                return true;
            }
        }
    }
    
    // If function not found, format a warning and leave state unchanged
    char warning[128];
    
    snprintf(warning, 128, "shader %s not found in library %d, leaving state unchanged\n", func_name, name);

    mtWarningFunc(warning, _calling_func_);
    
    return false;
}

/*
 * checkRendermodes
 *
 * Validates that the given vertex and fragment shader modes are valid enums.
 * Warns and returns false if invalid values detected.
 */
static MTbool checkRendermodes(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode)
{
    // Check vertex shader mode against allowed values
    switch(vertex_rendermode)
    {
        case MTVertexShaderModeNonInstanced:
        case MTVertexShaderModeInstanced:
            break;
            
        default:
            mtWarningFunc("invalid vertex rendermode", __FUNCTION__);
            return false;
    }

    // Check fragment shader mode against allowed values
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

/*
 * mtBindImmModeVertexShader
 *
 * Binds a vertex shader function for immediate-mode rendering given a vertex and fragment shader mode.
 * If fragment_rendermode is MTFragmentShaderModeAll, binds the vertex shader across all fragment modes.
 */
void mtBindImmModeVertexShader(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode, MTuint name, const char *vertex)
{
    if (checkRendermodes(vertex_rendermode, fragment_rendermode))
    {
        // Bind across all fragment modes if requested
        if(fragment_rendermode == MTFragmentShaderModeAll)
        {
            for(int i=MTFragmentShaderModeColor; i<MTFragmentShaderModeMax; i++)
            {
                bindShaderFunc(name, vertex, &STATE(vertex_shader_binding[vertex_rendermode][i]), __FUNCTION__);
            }
        }
        else
        {
            // Bind just the specified fragment mode
            bindShaderFunc(name, vertex, &STATE(vertex_shader_binding[vertex_rendermode][fragment_rendermode]), __FUNCTION__);
        }
    }
}

/*
 * mtBindImmModeFragmentShader
 *
 * Binds a fragment shader function for immediate-mode rendering given a vertex and fragment shader mode.
 * If fragment_rendermode is MTFragmentShaderModeAll, binds the fragment shader across all fragment modes.
 */
void mtBindImmModeFragmentShader(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode, MTuint name, const char *fragment)
{
    if (checkRendermodes(vertex_rendermode, fragment_rendermode))
    {
        // Bind across all fragment modes if requested
        if(fragment_rendermode == MTFragmentShaderModeAll)
        {
            for(int i=MTFragmentShaderModeColor; i<MTFragmentShaderModeMax; i++)
            {
                bindShaderFunc(name, fragment, &STATE(vertex_shader_binding[vertex_rendermode][i]), __FUNCTION__);
            }
        }
        else
        {
            // Bind just the specified fragment mode
            bindShaderFunc(name, fragment, &STATE(fragment_shader_binding[vertex_rendermode][fragment_rendermode]), __FUNCTION__);
        }
    }
}

/*
 * mtBindVertexShaderToVertexArray
 *
 * Binds a vertex shader function to a specific vertex array object's (VAO) shader binding.
 * Validates the VAO handle before binding.
 */
void mtBindVertexShaderToVertexArray(MTuint vao_name, MTuint lib_name, const char *vertex)
{
    MTVertexArray *vao;
    MTShaderBinding *binding;
    
    // Fetch VAO by name from global table
    vao = getKeyData(STATE(vertex_array_table), vao_name);
    
    if (vao == NULL)
    {
        // Invalid VAO handle; do nothing
        return;
    }
    
    // Select the vertex shader binding within the VAO
    binding = &vao->vertex_shader_binding;
    
    // Bind the shader function
    bindShaderFunc(lib_name, vertex, binding, __FUNCTION__);
}

/*
 * mtBindFragmentToVertexArray
 *
 * Binds a fragment shader function to a specific VAO's shader binding.
 * Validates the VAO handle before binding.
 * 
 * NOTE: This function currently assigns to vao->vertex_shader_binding, which may be a bug.
 */
void mtBindFragmentToVertexArray(MTuint vao_name, MTuint lib_name, const char *fragment)
{
    MTVertexArray *vao;
    MTShaderBinding *binding;
    
    // Fetch VAO by name from global table
    vao = getKeyData(STATE(vertex_array_table), vao_name);
    
    if (vao == NULL)
    {
        // Invalid VAO handle; do nothing
        return;
    }
    
    // Select the fragment shader binding within the VAO
    binding = &vao->fragment_shader_binding;
    
    // Bind the shader function
    bindShaderFunc(lib_name, fragment, binding, __FUNCTION__);
}


