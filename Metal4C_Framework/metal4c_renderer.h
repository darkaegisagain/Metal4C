//
//  metal4c_Renderer.h
//  Metal4C
//
//  Created by Michael Larson on 2/21/26.
//


#include "metal4c_shader_types.h"
#include "metal4c.h"

#ifdef __OBJC__

#import <Foundation/Foundation.h>

typedef struct {
    id<MTLFunction> vertexFunction;
    id<MTLFunction> fragmentFunction;
} ShaderFunctionPair;

@interface Renderer : NSObject

- (Renderer *)initWithMTKView:(MTKView *)view context:(MTRenderContext)ctx;
- (void) flushToScreen;

@end
#endif // __OBJC__

#include "metal4c_Renderer_Extern.h"
