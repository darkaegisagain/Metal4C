//
//  metal4c.h
//  Metal4C
//
//  Created by Michael Larson on 2/21/26.
//

#ifndef metal4c_h
#define metal4c_h

#include <stdint.h>
#include <stdbool.h>

#include <Metal4c/metal4c_defs.h>
#include <Metal4c/metal4c_formats.h>
#include <Metal4c/metal4c_shader_types.h>

/*
 Metal4C C API
 ----------------
 A lightweight C interface atop Metal that provides an immediate-mode style
 rendering path (Begin/End) and a vertex-array path (VAOs), plus utilities for
 textures, samplers, and shader libraries.

 This header declares the public C functions. Implementations are in C, with
 Objective-C used internally to talk to Metal.
*/

/* Rendering context handle and common typedef aliases used by the API. */
typedef MTuint          MTRenderContext;

typedef unsigned int    MTuint;
typedef unsigned short  MTushort;
typedef int             MTint;
typedef short           MTshort;
typedef float           MTfloat;
typedef double          MTdouble;

typedef unsigned int    MTbitfield;
typedef size_t          MTintptr;
typedef unsigned int    MTenum;
typedef size_t          MTsizeiptr;
typedef size_t          MTsizei;
typedef _Bool           MTbool;

/*
 Context management
 - mtCreateContext: Create a new rendering context.
 - mtSetCurrentContext: Make the given context current on the calling thread.
 - mtGetCurrentContext: Retrieve the current context for the calling thread.
*/
MTRenderContext mtCreateContext(void);
void mtSetCurrentContext(MTRenderContext ctx);
MTRenderContext mtGetCurrentContext(void);

MTbool mtBindMTKView(void *mtk_view);
void mtFlushToScreen(void);

/*
 Global render state
 - mtSetRendermode / mtSetVertexRendermode / mtSetFragmentRendermode: Select default vertex/fragment shader modes used when no explicit shader is bound.
 - mtSetPointSize: Set rasterized point size (for point primitives).
 - mtSetViewport: Set viewport rectangle in pixels.
 - mtEnable/mtDisable: Enable/disable capabilities (culling, depth, stencil, scissor, etc.).
 - mtClearColor/mtClearDepthValue/mtClearStencilValue: Set clear values.
 - mtClear: Clear color/depth/stencil buffers according to mask.
 - mtCullMode, mtWindingMode, mtDepthClipMode, mtTriangleFillMode: Fixed-function rasterization settings.
 - mtDepthMode/mtDepthTestBounds/mtDepthBias: Depth testing and bias configuration.
 - mtStencil* functions: Configure stencil testing for front/back faces.
 - mtScissorRect: Set scissor rectangle and enable with mtEnable(MT_SCISSOR_TEST).
*/
/* Note: Changes to viewport, primitive type, point size, and matrices mark DIRTY_UPLOADED_STATE internally so uniforms are re-uploaded before drawing. */
void mtSetRendermode(MTVertexShaderMode vertex_shader_mode, MTFragmentShaderMode fragment_shader_mode);
void mtSetVertexRendermode(MTVertexShaderMode vertex_shader_mode);
void mtSetFragmentRendermode(MTFragmentShaderMode fragment_shader_mode);

void mtSetPointSize(MTfloat size);

void mtSetViewport(MTfloat x, MTfloat y, MTfloat width, MTfloat height);

void mtEnable(MTenum cap);
void mtDisable(MTenum cap);

void mtClearColor(MTfloat r, MTfloat g, MTfloat b, MTfloat a);
void mtClearDepthValue(MTdouble depth);
void mtClearStencilValue(MTuint stencil);
void mtClear(MTbitfield mask);

void mtCullMode(MTCullMode mode);
void mtWindingMode(MTWinding mode);
void mtDepthClipMode(MTDepthClipMode mode);
void mtTriangleFillMode(MTTriangleFillMode mode);

void mtDepthMode(MTenum mode);
void mtDepthTestBounds(MTfloat min, MTfloat max);
void mtDepthBias(MTfloat bias, MTfloat scale, MTfloat clamp);

void mtStencilCompareFunc(MTenum buffer, MTenum compare_func);
void mtStencilCompareOp(MTenum buffer, MTenum pass_fail_op_sel, MTenum stencil_op);
void mtStencilReadMask(MTenum buffer, MTuint mask);
void mtStencilWriteMask(MTenum buffer, MTuint mask);

void mtScissorRect(MTuint x, MTuint y, MTuint width, MTuint height);

/*
 Immediate-mode style vertex submission
 Use mtBegin/mtEnd (and element variants) to stream vertices without explicit
 vertex buffers. The implementation batches into internal ring buffers and issues
 draw calls on mtEnd or when buffers are flushed.
 - mtBegin/mtEnd: Begin and end non-indexed primitive emission.
 - mtBeginInstance/mtBeginBaseInstance: Begin instanced emission with optional baseInstance.
 - Element variants (mtBeginElement* / mtElementEnd): Emit indexed primitives.
 - mtColor*, mtNormal*, mtTex*, mtVertex*: Specify per-vertex attributes.
 - mtIndex: Provide an index for element mode.
*/
void mtBegin(MTPrimitiveType type);
void mtBeginInstance(MTPrimitiveType type, MTuint instance_count);
void mtBeginBaseInstance(MTPrimitiveType type, MTuint instance_count, MTuint base_instance);
void mtEnd(void);

void mtBeginElement(MTPrimitiveType type);
void mtBeginElementInstance(MTPrimitiveType type, MTuint instance_count);
void mtBeginElementBaseInstance(MTPrimitiveType type, MTuint instance_count, MTuint base_instance);
void mtBeginElementBaseVertexInstance(MTPrimitiveType type, MTuint instance_count, MTuint base_vertex, MTuint base_instance);
void mtElementEnd(void);

void mtColor3f(MTfloat r, MTfloat g, MTfloat b);
void mtColor4f(MTfloat r, MTfloat g, MTfloat b, MTfloat a);
void mtColor3fv(MTfloat *ptr);
void mtColor4fv(MTfloat *ptr);

void mtNormalf(MTfloat x, MTfloat y, MTfloat z);
void mtNormalfv(MTfloat *ptr);

void mtTexf(MTfloat s, MTfloat);
void mtTexfv(MTfloat *ptr);

void mtTexfUnitf(MTfloat s, MTfloat t, MTuint unit);
void mtTexfUnitfv(MTfloat *ptr, MTuint unit);

void mtVertex4f(MTfloat x, MTfloat y, MTfloat z, MTfloat w);
void mtVertex3f(MTfloat x, MTfloat y, MTfloat z);
void mtVertex2f(MTfloat x, MTfloat y);

void mtVertex4fv(MTfloat *ptr);
void mtVertex3fv(MTfloat *ptr);
void mtVertex2fv(MTfloat *ptr);

void mtIndex(MTuint index);

/*
 Matrix stack utilities
 Classic model/view/projection-style stack operations. Values are consumed into
 the uploaded state and applied in shaders (MVP).
*/
void mtMatrixMode(MTenum mode);
void mtLoadMatrixf(MTfloat m[16]);
void mtMultMatrixf(MTfloat m[16]);
void mtLoadTransposeMatrixf(MTfloat m[16]);
void mtMultTransposeMatrixf(MTfloat m[16]);
void mtLoadIdentityf(void);
void mtRotatef(MTfloat theata, MTfloat x, MTfloat y, MTfloat z);
void mtTranslatef(MTfloat x, MTfloat y, MTfloat z);
void mtScalef(MTfloat x, MTfloat y, MTfloat z);
void mtFrustrumf(MTfloat l, MTfloat r, MTfloat b, MTfloat t, MTfloat n, MTfloat f);
void mtOrthof(MTfloat l, MTfloat r, MTfloat b, MTfloat t, MTfloat n, MTfloat f);
void mtPushMatrixf(void);
void mtPopMatrixf(void);

void mtPerspectivef(MTfloat angle, MTfloat ratio, MTfloat n, MTfloat f, MTfloat *b, MTfloat *t, MTfloat *l, MTfloat *r);

void mtTexGenf(MTenum coord, MTenum pname, MTfloat param);
void mtTexGenfv(MTenum coord, MTenum pname, MTfloat *params);

/*
 Textures
 Create texture descriptors for advanced control or use convenience creators
 for common 1D/2D/3D/cube/array/buffer textures.
 - mtCreateTexture*Desc: Allocate and configure a descriptor handle.
 - mtSetTexDesc*: Configure descriptor fields (usage, storage, swizzle, etc.).
 - mtCreateTexture* / mtCreateTextureFromDesc / mtCreateTextureFromFile: Create Metal textures.
 - mtDeleteTexture: Destroy a texture created by this API.
*/
MTuint mtCreateTextureDesc(void);
void mtDeleteTextureDesc(MTuint name);
MTuint mtCreateTextureDescWithPixelFormat(MTPixelFormat format, MTuint width, MTuint height, MTbool mipmapped);
MTuint mtCreateTextureCubeDescWithPixelFormat(MTPixelFormat format, MTuint size, MTbool mipmapped);
MTuint mtCreateTextureBufferDescWithPixelFormat(MTPixelFormat format, MTuint width, MTResourceOptions options, MTTextureUsage usage);

void mtSetTexDescParam(MTuint name, MTenum pname, MTuint param);
void mtSetTexDescResourceOptions(MTuint name, MTResourceOptions option);
void mtSetTexDescCPUCacheMode(MTuint name, MTCPUCacheMode mode);
void mtSetTexDescStorageMode(MTuint name, MTStorageMode mode);
void mtSetTexDescHazardTrackingMode(MTuint name, MTHazardTrackingMode mode);
void mtSetTexDescTextureUsage(MTuint name, MTTextureUsage usage);
void mtSetTexDescAllowGPUOptimizedContents(MTuint name, MTbool enable);
void mtSetTexDescSparsePageSize(MTuint name, MTSparsePageSize mode);
void mtSetTexDescSwizzle(MTuint name, MTTextureSwizzleChannels swizzle);

// create generic 2D texture no descriptor required
MTuint mtCreateTexture1D(MTuint format, MTuint width, size_t src_pitch, void *data);
MTuint mtCreateTexture2D(MTuint format, MTuint width, MTuint height, MTbool mipmapped, size_t src_pitch, void *data);
MTuint mtCreateTexture3D(MTuint format, MTuint width, MTuint height, MTuint depth, MTbool mipmapped, size_t src_pitch, void *data);
MTuint mtCreateTexture1DArray(MTuint format, MTuint width, MTuint array_length, size_t src_pitch, void *data);
MTuint mtCreateTexture2DArray(MTuint format, MTuint width, MTuint height, MTbool mipmapped, MTuint array_length, size_t src_pitch, void *data);
MTuint mtCreateTexture2DMultiSampled(MTuint format, MTuint width, MTuint height, MTuint sample_count, size_t src_pitch, void *data);
MTuint mtCreateTexture2DMultiSampledArray(MTuint format, MTuint width, MTuint height, MTuint sample_count, MTuint array_length, size_t src_pitch, void *data);
MTuint mtCreateTextureCube(MTuint format, MTuint width, MTbool mipmapped, size_t src_pitch, void *data);
MTuint mtCreateTextureCubeArray(MTuint format, MTuint width, MTbool mipmapped, MTuint array_length, size_t src_pitch, void *data);
MTuint mtCreateTextureBuffer(MTuint format, MTuint width, MTResourceOptions options, MTTextureUsage usage, size_t src_pitch, void *data);
MTuint mtCreateTextureFromDesc(MTuint name, MTsizei src_pitch, void *data);
MTuint mtCreateTextureFromFile(const char *path);


void mtDeleteTexture(MTuint tex);

/*
 Samplers
 Create sampler descriptors, configure filtering/addressing/compare, then create
 a sampler object.
*/
MTuint mtCreateSamplerDesc(void);
void mtDeleteSamplerDesc(MTuint name);

void mtSetSamplerDescParam(MTuint name, MTenum pname, MTuint param);
void mtSetSamplerDescParamf(MTuint name, MTenum pname, MTfloat param);

void mtSetSamplerDescMinFilter(MTuint name, MTSamplerMinMagFilter min_filter);
void mtSetSamplerDescMaxFilter(MTuint name, MTSamplerMinMagFilter max_filter);
void mtSetSamplerDescMipFilter(MTuint name, MTSamplerMipFilter mip_filter);
void mtSetSamplerDescMaxAnistropy(MTuint name, MTSamplerMipFilter max_anistropy);
void mtSetSamplerDescAddressMode_S(MTuint name, MTSamplerAddressMode mode);
void mtSetSamplerDescAddressMode_T(MTuint name, MTSamplerAddressMode mode);
void mtSetSamplerDescAddressMode_R(MTuint name, MTSamplerAddressMode mode);
void mtSetSamplerDescBoarderColor(MTuint name, MTSamplerBorderColor mode);
void mtSetSamplerDescNormalizedCoordinates(MTuint name, MTbool normalized_coordinates);
void mtSetSamplerDescLodMinClamp(MTuint name, MTfloat lod_min_clamp);
void mtSetSamplerDescLodMaxClamp(MTuint name, MTfloat lod_max_clamp);
void mtSetSamplerDescLodAverage(MTuint name, MTbool lod_average);
void mtSetSamplerDescLodBias(MTuint name, MTfloat lod_bias);
void mtSetSamplerDescCompareFunction(MTuint name, MTCompareFunction compare_function);
void mtSetSamplerDescSupportArgumentBuffers(MTuint name, MTbool support_argument_buffers);

MTuint  mtCreateSampler(MTuint desc_name);
void  mtDeleteSampler(MTuint name);

/*
 Buffers
 Create and update generic GPU buffers (for use as vertex/index/instance data in
 the VAO path).
 - mtCreateBuffer: Allocate a buffer with optional initial data.
 - mtBufferData/mtBufferSubData: Replace or update a subrange.
 - mtDeleteBuffer: Destroy a buffer created by this API.
*/
MTuint mtCreateBuffer(MTsizei size, MTuint flags, void *data);
void mtBufferData(MTuint buffer, MTsizei size, MTsizei offset, void *data);
void mtBufferSubData(MTuint buffer, MTsizei size, MTsizei offset, void *data);
void mtDeleteBuffer(MTuint buffer);

/*
 Vertex Array Objects (VAO)
 Describe vertex layouts and bind buffers once, then issue draw calls without
 re-specifying attributes.
 - mtCreateVertexArray/mtDeleteVertexArray: Manage VAO objects.
 - mtBindVertexArray: Make a VAO active.
 - mtBindArrayBuffer/mtBindIndexBuffer/mtBindInstanceBuffer: Bind buffers to the active VAO.
 - mtVertexDesc
 - mtClearDesc: Describe attributes and layouts per binding unit.
*/
MTuint mtCreateVertexArray(void);
void mtBindVertexArray(MTuint vao);
void mtDeleteVertexArray(MTuint vao);

void mtVertexDescAttr(MTuint unit, MTenum format, MTuint offset, MTuint buffer_index);
void mtVertexDescLayout(MTuint unit, MTuint stride, MTenum step_function, MTuint step_rate);
void mtVertexDesc(MTuint unit, MTenum format, MTuint offset, MTuint buffer_index,
                  MTuint stride, MTenum step_function, MTuint step_rate);
void mtClearDesc(MTuint unit);

void mtBindVertexBuffer(MTuint name, MTuint unit);
void mtBindFragmentBuffer(MTuint name, MTuint unit);

void mtBindIndexBuffer(MTuint name);
void mtBindInstanceBuffer(MTuint name);

/*
 VAO draw calls
 Draw using the currently bound VAO and buffers. Indexed variants use the bound
 index buffer; instanced variants use the bound instance buffer or instance count.
*/
void mtDrawArray(MTPrimitiveType type, MTsizei offset, MTsizei count);
void mtDrawArrayInstance(MTPrimitiveType type, MTsizei offset, MTsizei count, MTuint instance_count, MTuint base_instance);
void mtDrawElements(MTPrimitiveType type, MTIndexType index_type, MTsizei offset, MTsizei count);
void mtDrawElementsInstance(MTPrimitiveType type, MTIndexType index_type, MTsizei offset, MTsizei count, MTuint instance_count);
void mtDrawElementsInstanceBase(MTPrimitiveType type, MTIndexType index_type, MTsizei count, MTuint instance_count, MTuint base_instance);
void mtDrawElementsOffsetInstanceBase(MTPrimitiveType type, MTIndexType index_type, MTsizei offset, MTsizei count, MTuint instance_count, MTuint base_vertex, MTuint base_instance);

/*
 Shaders
 - mtCreateShaderLibrary: Compile a shader library from Metal Shading Language source.
 - mtBindImmMode*Shader: Bind vertex/fragment functions for immediate-mode paths by (vertex/fragment mode).
 - mtBind*ShaderToVertexArray: Bind shader functions to a VAO.
 - mtBind*Texture/mtBind*Sampler: Bind textures and samplers to shader stages at indices.
*/
MTuint mtCreateShaderLibrary(const char *str);
MTuint mtCreateShaderLibraryFromFile(const char *path);

void mtBindImmModeVertexShader(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode, MTuint lib, const char *vertex);
void mtBindImmModeFragmentShader(MTVertexShaderMode vertex_rendermode, MTFragmentShaderMode fragment_rendermode, MTuint lib, const char *fragment);

void mtBindVertexShaderToVertexArray(MTuint vao, MTuint lib, const char *vertex);
void mtBindFragmentShaderShaderToVertexArray(MTuint vao,MTuint lib, const char *fragment);

void mtBindVertexTexture(MTuint name, MTuint index);
void mtBindVertexSampler(MTuint name, MTuint index);

void mtBindVertexTexture(MTuint name, MTuint index);
void mtBindVertexSampler(MTuint name, MTuint index);

void mtBindFragmentTexture(MTuint name, MTuint index);
void mtBindFragmentSampler(MTuint name, MTuint index);

#pragma mark Utility Functions
void mtGetX11ColorByName(const char *name, MTfloat *color);
#endif /* metal4c_h */

