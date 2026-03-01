//
//  Renderer.h
//  Metal4C
//
//  Created by Michael Larson on 2/21/26.
//


#include "ShaderTypes.h"
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

#include "Renderer_Extern.h"
