//
//  metal4c_context.h
//  Metal4C
//
//  Created by Michael Larson on 2/22/26.
//

#ifndef metal4c_ctx_h
#define metal4c_ctx_h

#include <mach/mach_vm.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include "metal4c_formats.h"

#include "metal4c_hash_table.h"
#include "metal_math_utils.h"

enum {
    kDirtyPipeline = 0,
    kDirtyRenderPass,
    kDirtyRenderState,
    kDirtyUploadedState,
    kDirtyTexture,
    kDirtyTextureUnit,
    kDirtyUniform,
    kDirtyBuffer,
    kDirtyVertexEngSizes,
};

#define DIRTY_STATE_BIT(_bit) (0x1 << _bit)
#define DIRTY_RENDER_PASS           DIRTY_STATE_BIT(kDirtyRenderPass)
#define DIRTY_RENDER_STATE          DIRTY_STATE_BIT(kDirtyRenderState)
#define DIRTY_PIPELINE              DIRTY_STATE_BIT(kDirtyPipeline)
#define DIRTY_UPLOADED_STATE        DIRTY_STATE_BIT(kDirtyUploadedState)
#define DIRTY_TEXTURE               DIRTY_STATE_BIT(kDirtyTexture)
#define DIRTY_TEXTURE_UNIT          DIRTY_STATE_BIT(kDirtyTextureUnit)
#define DIRTY_UNIFORM               DIRTY_STATE_BIT(kDirtyUniform)
#define DIRTY_BUFFER                DIRTY_STATE_BIT(kDirtyBuffer)
#define DIRTY_VERTEX_ENGINE_SIZES   DIRTY_STATE_BIT(kDirtyVertexEngSizes)

enum {
    kDirtyBufferData = 0,
    kDirtyBufferAddress,
};

#define DIRTY_BUFFER_BIT(_bit) (0x1 << _bit)
#define DIRTY_BUFFER_DATA       DIRTY_BUFFER_BIT(kDirtyBufferData)
#define DIRTY_BUFFER_ADDRESS    DIRTY_BUFFER_BIT(kDirtyBufferAddress)

#define MAX_VERTICES                    (1024 * 1024)
#define MAX_INDICES                     (3 * MAX_VERTICES)
#define NUM_VERTICES                    (36 * 4)
#define NUM_INDICES                     (3 * NUM_VERTICES)

#define STATE(_var_)            _ctx->state._var_
#define MAT(_var_)              _ctx->state.mat._var_
#define VENG(_var_)             _ctx->vert_eng._var_
#define DEVCAP(_var_)           _ctx->device_caps._var_
#define DEVFEATURE(_var_)       _ctx->device_caps.feature_support._var_

#define newPtr(_type_)                      (_type_ *)malloc(sizeof(_type_))
#define newArray(_type_, _count_)           (_type_ *)malloc(sizeof(_type_) * _count_)
#define zeroPtr(_ptr_, _type_)              bzero(_ptr_, sizeof(_type_))
#define zeroArray(_ptr_, _type_, _count_)   bzero(_ptr_, sizeof(_type_) * _count_)

typedef struct {
    MTuint              max_depth;
    MTuint              sp;
    matrix_float4x4     *stack;
} MTMatrixStack;

typedef struct {
    MTuint          name;
    MTTextureDesc   desc;
    void            *data;
    void            *mtl_tex;
} MTTexture;

typedef struct {
    MTuint          name;
    MTSamplerDesc   desc;
    void            *data;
    void            *mtl_sampler;
} MTSampler;

typedef struct {
    MTuint          name;
    char            *src;
    MTuint          function_count;
    const char      **function_names;
    void            *mtl_lib;           // MTLLibrary
    void            *mtl_lib_functions; // NSMutableArray
} MTShaderLibrary;

typedef struct MTDirtyRegion_t {
    struct MTDirtyRegion_t  *next;
    MTsizei                 offset;
    MTsizei                 size;
} MTDirtyRegion;

typedef struct {
    MTuint          name;
    MTsizei         size;
    MTuint          flags;
    MTsizei         vm_size;
    vm_address_t    data;
    MTuint          dirty;
    MTDirtyRegion   dirty_region;
    void            *mtl_buffer;
} MTBuffer;

typedef struct {
    MTuint          lib;
    const char      *shader;
    MTuint          shader_index;
    MTShaderLibrary *shader_lib;
    void            *mtl_func;
} MTShaderBinding;

typedef struct {
    MTVertexFormat          format;
    MTuint                  offset;
    MTuint                  buffer_index;
    MTuint                  stride;
    MTVertexStepFunction    step_function;
    MTuint                  step_rate;
} MTVertexArrayBinding;

typedef struct {
    MTVertexFormat          format;
    MTuint                  offset;
} MTIndexBinding;

typedef struct {
    MTuint                  name;
    MTuint                  bindings_mask;
    MTBuffer                *vertex_buffers[MAX_BUFFER_BINDINGS];
    MTuint                  vertex_desc_mask;
    MTVertexArrayBinding    vertex_arrays[MAX_BUFFER_BINDINGS];
    MTShaderBinding         vertex_shader_binding;
    MTShaderBinding         fragment_shader_binding;
} MTVertexArray;

typedef struct {
    MTenum              compare_func;
    MTenum              stencil_failure_op;
    MTenum              depth_failure_op;
    MTenum              depth_stencil_pass_op;
    MTuint              read_mask;
    MTuint              write_mask;
} MTStencilDesc;

typedef struct {
    MTPrimitiveType     type;
    MTPritiveDrawStyle  draw_style;
    MTIndexType         index_type;
    MTsizei             offset;
    MTsizei             count;
    MTsizei             instance_count;
    MTsizei             base_instance;
    MTsizei             base_vertex;
} MTDrawArrayPrimitive;

typedef unsigned int    MTuint;
typedef int             MTint;
typedef float           MTfloat;
typedef matrix_float4x4 MTmatrix;

typedef unsigned int    MTbitfield;
typedef size_t          MTintptr;
typedef unsigned int    MTenum;
typedef size_t          MTsizeiptr;
typedef size_t          MTsizei;
typedef _Bool           MTbool;

typedef struct MTRenderContextRec_t MTRenderContextRec;

struct MTRenderFuncs_t {
    void *mtlObj;
    void *mtlView;
    
    void (*mtlFlushVertexEng)(MTRenderContextRec *mt_ctx);
    void (*mtlBegin)(MTRenderContextRec *mt_ctx, MTPrimitiveType type);
    void (*mtlEnd)(MTRenderContextRec *mt_ctx);
        
    void (*mtlCFBridgingRelease)(void *ptr);
    
    void (*mtlTextureDescWithPixelFormat)(MTRenderContextRec *mt_ctx, MTTextureDesc *desc, MTuint *error);
    void (*mtlTextureCubeDescWithPixelFormat)(MTRenderContextRec *mt_ctx, MTTextureDesc *desc, MTuint *error);
    void (*mtlTextureBufferDescWithPixelFormat)(MTRenderContextRec *mt_ctx, MTTextureDesc *desc, MTuint *error);

    void (*mtlCreateTexture)(MTRenderContextRec *mt_ctx, MTTexture *tex, MTsizei src_pitch, void *data);
    void (*mtlCreateTextureFromPath)(MTRenderContextRec *mt_ctx, MTTexture *tex, const char *path);
    void (*mtlCreateTextureFromDesc)(MTRenderContextRec *mt_ctx, MTTexture *tex, MTTextureDesc *desc, MTsizei src_pitch, void *data);

    void (*mtlCreateShaderLibrary)(MTRenderContextRec *mt_ctx, MTShaderLibrary *shdr_lib);
    
    void (*mtlDrawArray)(MTRenderContextRec *mt_ctx, MTDrawArrayPrimitive *draw);
} ;

typedef struct MTRenderContextRec_t {
    struct MTRenderFuncs_t     mt_render_funcs;
    
    uint32_t            dirty_state;

    struct {
        MTuint          supported_sample_counts_bitfield;
        MTuint          supported_vertex_amplifaction_count;
        MTuint          max_threadgroup_memory_length;
        MTsizei         max_buffer_length;
        MTuint          minimum_texture_alignment[MTPixelFormatMax];
        MTuint          minimum_texture_buffer_alignment[MTPixelFormatMax];
        struct {
            MTuint width, height, depth;
        } max_threads_per_threadgroup;
        struct {
            MTbool  ray_tracing;
            MTbool  primitive_motion_blur;
            MTbool  raytracing_from_renderer;
            MTbool  _32bitMSAA;
            MTbool  pull_model_interpolation;
            MTbool  shader_barycentric_coordinates;
            MTbool  programmable_sample_positions;
            MTbool  raster_order_groups;
            MTbool  _32bit_float_filtering;
            MTbool  BC_texture_compression;
            MTbool  depth24_stencil8_pixel_format;
            MTbool  query_texture_LOD;
            MTbool  read_write_texture_support;
            MTbool  texture_format[MTPixelFormatMax];
        } feature_support;
    } device_caps;
        
    struct {
        MTuint          in_begin_end;
        MTuint          in_element_begin_end;
        MTPrimitiveType prim_type;
  
        MTfloat         point_size;

        MTColor         clear_color;
        MTbitfield      clear_mask;

        double          clear_depth;
        MTuint          clear_stencil;
        
        MTPixelFormat   depth_stencil_format;
//      MTPixelFormat   depth_format;
//      MTPixelFormat   stencil_format;
        MTbool          depth_enable;
        MTenum          depth_test_mode;
        MTfloat         depth_test_min_bound;
        MTfloat         depth_test_max_bound;
        MTfloat         depth_bias;
        MTfloat         depth_bias_scale;
        MTfloat         depth_bias_clamp;

        MTbool          stencil_enable;
        MTStencilDesc   front_stencil_desc;
        MTStencilDesc   back_stencil_desc;
        
        struct {
            float x, y;
            float width, height;
        } viewport;
        
        MTCullMode          cull_mode;
        MTWinding           winding_mode;
        MTDepthClipMode     depth_clip_mode;
        MTTriangleFillMode  triangle_fill_mode;
        
        MTbool              scissor_enable;
        struct {
            MTuint x, y, width, height;
        } scissor_rect;
        
        HashTable       *buffer_table;
        HashTable       *texture_table;
        HashTable       *shader_table;
        HashTable       *vertex_array_table;
        HashTable       *sampler_table;

        HashTable       *texture_desc_table;
        HashTable       *sampler_desc_table;

        unsigned        enabled_vertex_textures;
        MTuint          vertex_textures[MAX_TEXTURE_UNITS];

        unsigned        enabled_vertex_samplers;
        MTuint          vertex_samplers[MAX_TEXTURE_UNITS];

        unsigned        enabled_fragment_textures;
        MTuint          fragment_textures[MAX_TEXTURE_UNITS];
        
        unsigned        enabled_fragment_samplers;
        MTuint          fragment_samplers[MAX_TEXTURE_UNITS];
        
        MTVertexShaderMode      vertex_shader_mode;
        MTFragmentShaderMode    fragment_shader_mode;

        MTShaderBinding         vertex_shader_binding[MTVertexShaderModeMax][MTFragmentShaderModeMax];
        MTShaderBinding         fragment_shader_binding[MTVertexShaderModeMax][MTFragmentShaderModeMax];

        MTVertexArray   *vao;
        
        MTBuffer        *index_buffer;
        MTBuffer        *instance_buffer;

        struct {
            MTenum          mode;
            MTMatrixStack   stks[MTMatrixMode_Max];
            matrix_float4x4 mvp;
        } mat;
    } state;

    UploadedState   uploaded_state;
    
    struct {
        MTuint      max_texture_units;
        MTuint      max_vertex_attributes;
    } device_params;
    
    // any data specific to begin / end statements belongs here
    struct {
        size_t                  max_vertices;
        size_t                  max_indices;
        size_t                  num_vertices;
        size_t                  num_indices;
        Vertex4ColorNormalTex   baseVertex;
        
        size_t                  current_vertex;
        Vertex4ColorNormalTex   *vertices;

        size_t                  current_index;
        MTuint                  *indices;
        MTuint                  max_index_submitted;
        
        MTuint                  instance_count;
        MTint                   base_vertex; // can be negative
        MTuint                  base_instance;
    } vert_eng;
    
    MTDirtyRegion               *free_dirty_region_list;
} MTRenderContextRec;

extern MTRenderContextRec *_ctx;

MTRenderContextRec *mtGetContextPtr(MTRenderContext ctx);

void mtErrorFunc(const char *err, const char *func);
void mtWarningFunc(const char *err, const char *func);

void mtUpdateMVP(void);

void updateShaderModeState(MTDrawArrayPrimitive *draw);

#endif /* metal4c_ctx_h */
