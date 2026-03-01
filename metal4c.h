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

#include "metal4c_formats.h"

#include "ShaderTypes.h"

enum {
    kClearColorBuffer = 0,
    kClearDepthBuffer,
    kClearStencilBuffer,
};
#define MT_CLEAR_BUFFER_BIT(_bit_)  (0x1 << _bit_)
#define MT_CLEAR_COLOR_BUFFER       MT_CLEAR_BUFFER_BIT(kClearColorBuffer)
#define MT_CLEAR_DEPTH_BUFFER       MT_CLEAR_BUFFER_BIT(kClearDepthBuffer)
#define MT_CLEAR_STENCIL_BUFFER     MT_CLEAR_BUFFER_BIT(kClearStencilBuffer)

typedef enum RenderMode {
    kRendermodeColor,
    kRendermodeTex,
    kRendermodeColorTex,
    kRendermodeNormal,
    kRendermodeColorNormal,
    kRendermodeTexNormal,
    kRendermodeColorTexNormal,
    kRendermodeMax
} RenderMode;

typedef enum MatrixMode {
    kMatrixMode_Modelview,
    kMatrixMode_Projection,
    kMatrixMode_Texture,
    kMatrixMode_Color,
    kMatrixMode_Max
} MatrixMode;

typedef struct MTRenderContextRec_t *MTRenderContext;

typedef unsigned int    MTuint;
typedef int             MTint;
typedef float           MTfloat;

typedef unsigned int    MTbitfield;
typedef size_t          MTintptr;
typedef unsigned int    MTenum;
typedef size_t          MTsizeiptr;
typedef size_t          MTsizei;
typedef _Bool           MTbool;


MTRenderContext mtCreateContext(void);
void mtSetCurrentContext(MTRenderContext ctx);
MTRenderContext mtGetCurrentContext(void);

void mtSetRendermode(MTuint mode);
void mtSetPointSize(MTfloat size);

void mtSetViewport(MTfloat x, MTfloat y, MTfloat width, MTfloat height);

void mtClearColor(MTfloat r, MTfloat g, MTfloat b, MTfloat a);
void mtClear(MTbitfield mask);

void mtColorf(MTfloat r, MTfloat g, MTfloat b, MTfloat a);
void mtNormalf(MTfloat x, MTfloat y, MTfloat z);
void mtTexf(MTfloat s, MTfloat);
void mtTexfUnit(MTfloat s, MTfloat t, MTuint unit);
void mtVertex4f(MTfloat x, MTfloat y, MTfloat z, MTfloat w);

void mtBegin(PrimitiveType type);
void mtEnd(void);

MTuint mtCreateTexture2D(MTuint format, MTuint width, MTuint height, size_t pitch, void *data);
MTuint mtCreateTexturePacked(MTuint format, MTuint width, MTuint height, size_t size, void *data);

MTuint mtCreateTextureFromFile(const char *path);

MTuint mtCreateShaderLibrary(const char *str);
void mtBindShaderFunctions(MTuint lib, const char *vertex, const char *fragment, MTuint rendermode);

void mtBindVertexTexture(MTuint name, MTuint index);
void mtBindFragmentTexture(MTuint name, MTuint index);

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

void mtTexGenf(MTenum coord, MTenum pname, MTfloat param);
void mtTexGenfv(MTenum coord, MTenum pname, MTfloat *params);


#endif /* metal4c_h */
