//
//  metal4c_context.h
//  Metal4C
//
//  Created by Michael Larson on 2/22/26.
//

#ifndef metal4c_ctx_h
#define metal4c_ctx_h

#include "hash_table.h"
#include "matrix_lib.h"

enum {
    kDirtyPipeline = 0,
    kDirtyRenderPass,
    kDirtyUploadedState,
    kDirtyTexture,
    kDirtyTextureUnit,
    kDirtyUniform
};

#define DIRTY_STATE_BIT(_bit) (0x1 << _bit)
#define DIRTY_RENDER_PASS       DIRTY_STATE_BIT(kDirtyRenderPass)
#define DIRTY_PIPELINE          DIRTY_STATE_BIT(kDirtyPipeline)
#define DIRTY_UPLOADED_STATE    DIRTY_STATE_BIT(kDirtyUploadedState)
#define DIRTY_TEXTURE           DIRTY_STATE_BIT(kDirtyTexture)
#define DIRTY_TEXTURE_UNIT      DIRTY_STATE_BIT(kDirtyTextureUnit)
#define DIRTY_UNIFORM           DIRTY_STATE_BIT(kDirtyUniform)

#define MAX_TEXTURE_UNITS               8
#define MAX_MODELVIEW_MATRIX_DEPTH      64
#define MAX_MATRIX_DEPTH                8

#define NUM_VERTICES                    36

#define STATE(_var_)            _ctx->state._var_
#define MAT(_var_)              _ctx->state.mat._var_
#define VENG(_var_)             _ctx->vert_eng._var_

#define newPtr(_type_)                  (_type_ *)malloc(sizeof(_type_))
#define newArray(_type_, _count_)       (_type_ *)malloc(sizeof(_type_) * _count_)

typedef struct MTRenderContextRec_t *MTRenderContext;

typedef struct {
    MTuint      max_depth;
    MTuint      sp;
    mat4_t      *stack;
} MTMatrixStack;

typedef struct {
    MTuint          name;
    MTuint          width, height;
    size_t          pitch;
    MTuint          format;
    void            *mtl_tex;
} MTTexture;

typedef struct {
    MTuint          name;
    char            *src;
    MTuint          function_count;
    const char      **functions;
    void            *mtl_lib;
} MTShaderLibrary;

typedef struct {
    MTuint      lib;
    const char  *vertex_shader;
    const char  *fragment_shader;
    MTuint      vertex_shader_index;
    MTuint      fragment_shader_index;
} ShaderBinding;

typedef unsigned int    MTuint;
typedef int             MTint;
typedef float           MTfloat;
typedef mat4_t          MTmatrix;

typedef unsigned int    MTbitfield;
typedef size_t          MTintptr;
typedef unsigned int    MTenum;
typedef size_t          MTsizeiptr;
typedef size_t          MTsizei;
typedef _Bool           MTbool;

struct MTRenderFuncs_t {
    void *mtlObj;
    void *mtlView;
    
    void (*mtlFlushVertexEng)(MTRenderContext mt_ctx);
    void (*mtlBegin)(MTRenderContext mt_ctx, PrimitiveType type);
    void (*mtlEnd)(MTRenderContext mt_ctx);
        
    void (*mtlCreateTexture2D)(MTRenderContext mt_ctx, MTTexture *tex, void *data);
    void (*mtlCreateTextureFromPath)(MTRenderContext mt_ctx, MTTexture *tex, const char *path);

    void (*mtlCreateShaderLibrary)(MTRenderContext mt_ctx, MTShaderLibrary *shdr_lib);
} ;

typedef struct MTRenderContextRec_t {
    struct MTRenderFuncs_t     mt_render_funcs;
    
    uint32_t            dirty_state;

    struct {
        MTuint          render_mode;
        MTfloat         point_size;

        MTColor         clear_color;
        MTbitfield      clear_mask;

        struct {
            float x, y;
            float width, height;
        } viewport;
        
        HashTable       *buffer_table;
        HashTable       *texture_table;
        HashTable       *shader_table;

        unsigned        enabled_vertex_textures;
        MTuint          vertex_textures[MAX_TEXTURE_UNITS];

        unsigned        enabled_fragment_textures;
        MTuint          fragment_textures[MAX_TEXTURE_UNITS];
        
        ShaderBinding   shader_bindings[kRendermodeMax];
        
        struct {
            MTenum          mode;
            MTMatrixStack   stks[kMatrixMode_Max];
        } mat;
    } state;

    UploadedState   uploaded_state;
    
    struct {
        MTuint      max_texture_units;
        MTuint      max_vertex_attributes;
    } device_params;
    
    struct {
        PrimitiveType           prim_type;
        size_t                  num_vertices;
        Vertex4ColorNormalTex   baseVertex;
        
        size_t                  current_vertex;
        Vertex4ColorNormalTex   *vertices;
    } vert_eng;
} MTRenderContextRec;

extern MTRenderContext _ctx;

void mtErrorFunc(const char *err, const char *func);
void mtWarningFunc(const char *err, const char *func);

#endif /* metal4c_ctx_h */
