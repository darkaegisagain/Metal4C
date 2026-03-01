//
//  Renderer.m
//  Metal4C
//
//  Created by Michael Larson on 2/21/26.
//

#import <MetalKit/MetalKit.h>

#import "Renderer.h"
#import "ShaderTypes.h"

#import "metal4c_context.h"

NS_ASSUME_NONNULL_BEGIN

@implementation Renderer
{
    // The device (aka GPU) used to render
    id<MTLDevice>               _device;
    
    MTKTextureLoader            *_textureLoader;
    
    // The current size of the view.
    vector_uint2                _viewportSize;
    
    MTRenderContext             _ctx;
    MTKView                     *_view;
    
    // The command Queue used to submit commands.
    id<MTLCommandQueue>         _commandQueue;
    id<MTLCommandBuffer>        _currentCommandBuffer;
    id<MTLRenderPipelineState>  _currentPipelineState;
    id<MTLRenderCommandEncoder> _currentRenderEncoder;
    id<MTLTexture>              _currentTexture;
    
    NSString                    *_renderModeStr[kRendermodeMax];
    
    id<MTLLibrary>              _defaultShaderLibrary;
    ShaderFunctionPair          _defaultShaderPairs[kRendermodeMax];
}


#pragma mark bindVertexTex
- (void)bindVertexTex:(nullable id<MTLTexture>)mtl_tex unit:(unsigned)unit
{
    switch(STATE(render_mode))
    {
        case kRendermodeTex:
        case kRendermodeColorTex:
        case kRendermodeTexNormal:
        case kRendermodeColorTexNormal:
            [_currentRenderEncoder setVertexTexture:mtl_tex
                                              atIndex:TextureIndexBaseColor + unit];
            
        default:
            break;
    }

}

#pragma mark bindFragmentTex
- (void)bindFragmentTex:(nullable id<MTLTexture>)mtl_tex unit:(unsigned)unit
{
    switch(STATE(render_mode))
    {
        case kRendermodeTex:
        case kRendermodeColorTex:
        case kRendermodeTexNormal:
        case kRendermodeColorTexNormal:
            [_currentRenderEncoder setFragmentTexture:mtl_tex
                                              atIndex:TextureIndexBaseColor + unit];
            
        default:
            break;
    }
}

#pragma mark updateRenderBuffer
- (void)updateRenderBuffer
{
    if (_currentCommandBuffer == NULL)
    {
        // Create a new command buffer for each render pass to the current drawable
        _currentCommandBuffer = [_commandQueue commandBuffer];
        assert(_currentCommandBuffer);
        
        _currentCommandBuffer.label = @"CommandBuffer";
    }
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = _view.currentRenderPassDescriptor;
    assert(renderPassDescriptor);

    if (_ctx->dirty_state & DIRTY_PIPELINE)
    {
        /// Create the render pipeline.
         
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = _renderModeStr[STATE(render_mode)];

        assert(_defaultShaderPairs[STATE(render_mode)].vertexFunction);
        assert(_defaultShaderPairs[STATE(render_mode)].fragmentFunction);

        pipelineStateDescriptor.vertexFunction = _defaultShaderPairs[STATE(render_mode)].vertexFunction;
        pipelineStateDescriptor.fragmentFunction = _defaultShaderPairs[STATE(render_mode)].fragmentFunction;
        assert(_defaultShaderPairs[STATE(render_mode)].vertexFunction);
        assert(_defaultShaderPairs[STATE(render_mode)].fragmentFunction);
        
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
        
        /// fill out vertex descriptor
        MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
        vertexDescriptor.attributes[0].bufferIndex = 0;
        vertexDescriptor.attributes[0].offset = 0;
        vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
        vertexDescriptor.layouts[0].stride = sizeof(Vertex4ColorNormalTex);
        vertexDescriptor.layouts[0].stepRate = 1;
        vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
        
        pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;

        NSError *error = NULL;
        _currentPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                        error:&error];
        
        NSAssert(_currentPipelineState, @"Failed to create pipeline state: %@", error);
    }
    
    // update render pass descriptor
    if (_ctx->dirty_state & DIRTY_RENDER_PASS)
    {
        MTColor color;
        
        color = STATE(clear_color);
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(color.r, color.g, color.b, color.a);
        if (STATE(clear_mask))
        {
            if (STATE(clear_mask) & MT_CLEAR_COLOR_BUFFER)
            {
                renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
            }
            else
            {
                renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
            }
            
            // need to deal with depth and stencil
            // printf("Need to deal with depth stencil clear");
            STATE(clear_mask) = 0;
        }
        else
        {
            renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
        }

        if (_currentRenderEncoder)
        {
            [_currentRenderEncoder endEncoding];
            _currentRenderEncoder = NULL;
        }
        
        // create new render encoder
        _currentRenderEncoder = [_currentCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        assert(_currentRenderEncoder);

        _currentRenderEncoder.label = @"RenderEncoder";
        
        // Set the region of the drawable to draw into.
        [_currentRenderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }];
        
        [_currentRenderEncoder setRenderPipelineState:_currentPipelineState];
    }

    if (_ctx->dirty_state & (DIRTY_PIPELINE | DIRTY_TEXTURE_UNIT | DIRTY_RENDER_PASS))
    {
        if (STATE(enabled_vertex_textures))
        {
            for(int i=0; i<MAX_TEXTURE_UNITS; i++)
            {
                if (STATE(enabled_vertex_textures & (0x1 << i)))
                {
                    unsigned name;
                    
                    name = STATE(vertex_textures[i]);
                    
                    if (isValidKey(STATE(texture_table), name))
                    {
                        MTTexture *tex;
                        
                        tex = getKeyData(STATE(texture_table), name);
                        
                        id<MTLTexture> mtl_tex;
                        
                        mtl_tex = (__bridge id<MTLTexture>)tex->mtl_tex;
                        
                        [self bindVertexTex:mtl_tex unit:i];
                    }
                }
                else
                {
                    [self bindVertexTex:NULL unit:i];
                }
                
                if ((STATE(enabled_vertex_textures) >> (i + 1)) == 0)
                {
                    break;
                }
            }
        }
        
        if (STATE(enabled_fragment_textures))
        {
            for(int i=0; i<MAX_TEXTURE_UNITS; i++)
            {
                if (STATE(enabled_fragment_textures) & (0x1 << i))
                {
                    unsigned name;
                    
                    name = STATE(fragment_textures[i]);
                    
                    if (isValidKey(STATE(texture_table), name))
                    {
                        MTTexture *tex;
                        
                        tex = getKeyData(STATE(texture_table), name);
                        
                        id<MTLTexture> mtl_tex;
                        
                        mtl_tex = (__bridge id<MTLTexture>)tex->mtl_tex;
                        
                        [self bindFragmentTex:mtl_tex unit:i];
                    }
                }
                else
                {
                    [self bindFragmentTex:NULL unit:i];
                }
                
                if ((STATE(enabled_fragment_textures) >> (i + 1)) == 0)
                {
                    break;
                }
            }
        }
    }

    if (_ctx->dirty_state & DIRTY_UPLOADED_STATE)
    {
        _ctx->uploaded_state.viewport_size[0]   = STATE(viewport.width);
        _ctx->uploaded_state.viewport_size[1]   = STATE(viewport.height);
        _ctx->uploaded_state.render_mode        = STATE(render_mode);
        _ctx->uploaded_state.prim_type          = VENG(prim_type);
        _ctx->uploaded_state.point_size         = STATE(point_size);
    }
    
    [_currentRenderEncoder setVertexBytes:&_ctx->uploaded_state length:sizeof(_ctx->uploaded_state) atIndex: VertexInputIndexUploadedState];
    
    // clear dirty state
    _ctx->dirty_state = 0;
}

#pragma mark mtlFlushVertexEng
- (void)mtlFlushVertexEng
{
    // vertex buffer
    size_t size;
    
    size = sizeof(Vertex4ColorNormalTex) * VENG(current_vertex);
    
    [_currentRenderEncoder setVertexBytes:VENG(vertices) length: size atIndex: VertexInputIndexVertices];
    
    [_currentRenderEncoder drawPrimitives:(MTLPrimitiveType)VENG(prim_type)
                              vertexStart:0
                              vertexCount:VENG(current_vertex)];
}

void mtlFlushVertexEng(MTRenderContext mt_ctx)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlFlushVertexEng];
}

#pragma mark mtlBegin
- (void)mtlBegin:(PrimitiveType)type
{
    // copy base vert to current pos
    [self updateRenderBuffer];
}

void mtlBegin(MTRenderContext mt_ctx, PrimitiveType type)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlBegin: type];
}


#pragma mark mtlEnd
- (void)mtlEnd
{
    // vertex buffer
    size_t size;
    
    size = sizeof(Vertex4ColorNormalTex) * VENG(current_vertex);
    
    [_currentRenderEncoder setVertexBytes:VENG(vertices) length: size atIndex: VertexInputIndexVertices];
    
    [_currentRenderEncoder drawPrimitives:(MTLPrimitiveType)VENG(prim_type)
                              vertexStart:0
                              vertexCount:VENG(current_vertex)];
}

void mtlEnd(MTRenderContext mt_ctx)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlEnd];
}

#pragma mark mtlCreateTexture2D
- (void)mtlCreateTexture2D:(MTTexture *)tex data:(void *)data
{
    MTLTextureDescriptor *tex_desc;
    tex_desc = [[MTLTextureDescriptor alloc] init];
    assert(tex_desc);
    
    tex_desc.width          = (NSUInteger)tex->width;
    tex_desc.height         = (NSUInteger)tex->height;
    tex_desc.pixelFormat    = tex->format;
    tex_desc.usage          = MTLTextureUsageShaderRead;
    
    id<MTLTexture> mtl_tex;
    mtl_tex = [_device newTextureWithDescriptor: tex_desc];
    assert(mtl_tex);
    
    MTLRegion region = {
        { 0, 0, 0 },                    // MTLOrigin
        {tex->width, tex->height, 1}    // MTLSize
    };
    
    // load texture data
    [mtl_tex replaceRegion:region
               mipmapLevel:0
                 withBytes:data
               bytesPerRow:tex->pitch];
    
    // retain to keep ownership to this texture
    tex->mtl_tex    = (void *)CFBridgingRetain(mtl_tex);
}

void mtlCreateTexture2D(MTRenderContext mt_ctx, MTTexture *tex, void *data)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlCreateTexture2D:tex data:data];
}


#pragma mark mtlCreateTextureFromPath
- (void)mtlCreateTextureFromPath:(MTTexture *)tex path:(const char*)path
{
    tex->mtl_tex = NULL;
    
    NSURL *url;
    url = [NSURL URLWithString:[NSString stringWithUTF8String:path]];
    
    if (url == NULL)
    {
        return;
    }
    
    id<MTLTexture> mtl_tex;
    NSError *err;
    
    mtl_tex = [_textureLoader newTextureWithContentsOfURL:url
                                                  options:NULL
                                                    error:&err];

    if (err)
    {
        NSLog(@"Error: %@", [err localizedDescription]);
    }
    
    // Get the file URL from the bundle
    NSBundle *mainBundle = [NSBundle mainBundle];
    url = [mainBundle URLForResource:[NSString stringWithCString:path encoding:NSUTF8StringEncoding] withExtension:nil];

    mtl_tex = [_textureLoader newTextureWithContentsOfURL:url
                                                  options:NULL
                                                    error:&err];

    if (err)
    {
        NSLog(@"Error: %@", [err localizedDescription]);
        return;
    }
    
    if (mtl_tex == NULL)
    {
        return;
    }
    
    tex->width  = (MTuint)[mtl_tex width];
    tex->height = (MTuint)[mtl_tex height];
    tex->format = (MTuint)[mtl_tex pixelFormat];
    tex->pitch  = 0;
    
    tex->mtl_tex    = (void *)CFBridgingRetain(mtl_tex);
}

void mtlCreateTextureFromPath(MTRenderContext mt_ctx, MTTexture *tex, const char *path)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlCreateTextureFromPath:tex path:path];
}

#pragma mark mtlCreateShaderLibrary
- (void)mtlCreateShaderLibrary:(MTShaderLibrary*)lib
{
    id<MTLLibrary> mtl_lib;

    NSString *src;
    
    src = [NSString stringWithUTF8String: lib->src];
    
    NSError *err;
    mtl_lib = [_device newLibraryWithSource:src options: NULL error:&err];

    if (err)
    {
        NSLog(@"%@", err);

        MTLCompileOptions *options;
        
        options = [MTLCompileOptions alloc];
        
        options.libraryType = MTLLibraryTypeExecutable;
        options.enableLogging = true;
        
        MTLLogStateDescriptor *logStateDesc = [MTLLogStateDescriptor new];
        logStateDesc.bufferSize = 2048;
        logStateDesc.level = MTLLogLevelDebug;
        
        id<MTLLogState> logState = [_device newLogStateWithDescriptor:logStateDesc error:&err];

        [logState addLogHandler:^(NSString *substring, NSString *category,
                                      MTLLogLevel level, NSString *message)
         {
           NSLog(@"%@", message);
        }];
        
        mtl_lib = [_device newLibraryWithSource:src options: NULL error:&err];
        
        return;
    }
    
    NSArray *function_names;
    function_names = [mtl_lib functionNames];

    lib->function_count = (MTuint)[function_names count];
    lib->functions = newArray(const char *, lib->function_count);
    
    NSLog(@"Compiled %d functions for library\n", lib->function_count);
    
    int i = 0;
    for (NSString *string in function_names)
    {
        NSLog(@"%@", string);
        
        lib->functions[i++] = strdup([string cStringUsingEncoding: NSUTF8StringEncoding]);
    }

    lib->mtl_lib = (void *)CFBridgingRetain(mtl_lib);
}

void mtlCreateShaderLibrary(MTRenderContext mt_ctx, MTShaderLibrary *lib)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlCreateShaderLibrary:lib];
}


#pragma mark C interface to context functions
- (void)bindObjFuncsMTRenderContext
{
    _ctx->mt_render_funcs.mtlObj = (__bridge void *)(self);
    
    // ObjC functions
    _ctx->mt_render_funcs.mtlFlushVertexEng = mtlFlushVertexEng;
    _ctx->mt_render_funcs.mtlBegin = mtlBegin;
    _ctx->mt_render_funcs.mtlEnd = mtlEnd;
    _ctx->mt_render_funcs.mtlCreateTextureFromPath = mtlCreateTextureFromPath;
    _ctx->mt_render_funcs.mtlCreateTexture2D = mtlCreateTexture2D;
    _ctx->mt_render_funcs.mtlCreateShaderLibrary = mtlCreateShaderLibrary;
}

#pragma mark initWithMTKView
- (Renderer *)initWithMTKView:(MTKView *)view context:(MTRenderContext)ctx
{
    _device = MTLCreateSystemDefaultDevice();
    assert(_device);

    NSRect frame;
    frame = [view frame];
    
    view.device = _device;
    
    NSScreen *screen;
    screen = [NSScreen mainScreen];
    
    float scale;
    scale = [screen backingScaleFactor];
    
    _viewportSize.x = frame.size.width * scale;
    _viewportSize.y = frame.size.height * scale;

    _textureLoader = [[MTKTextureLoader alloc] initWithDevice: view.device];
    assert(_textureLoader);

    // Load the shaders from the default library
    _defaultShaderLibrary = [_device newDefaultLibrary];
    
    // move these somewhere else
    _renderModeStr[kRendermodeColor]            = @"kRendermodeColor";
    _renderModeStr[kRendermodeTex]              = @"kRendermodeTex";
    _renderModeStr[kRendermodeNormal]           = @"kRendermodeNormal";
    _renderModeStr[kRendermodeColorTex]         = @"kRendermodeColorTex";
    _renderModeStr[kRendermodeColorNormal]      = @"kRendermodeColorNormal";
    _renderModeStr[kRendermodeTexNormal]        = @"kRendermodeTexNormal";
    _renderModeStr[kRendermodeColorTexNormal]   = @"kRendermodeColorTexNormal";

    // these are "fixed function" shaders for now
    _defaultShaderPairs[kRendermodeColor].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderColor"];
    _defaultShaderPairs[kRendermodeColor].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColor"];
    
    _defaultShaderPairs[kRendermodeTex].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderTex"];
    _defaultShaderPairs[kRendermodeTex].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderTex"];
    
    _defaultShaderPairs[kRendermodeNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderNormal"];
    _defaultShaderPairs[kRendermodeNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderNormal"];
    
    _defaultShaderPairs[kRendermodeColorTex].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderColorTex"];
    _defaultShaderPairs[kRendermodeColorTex].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorTex"];

    _defaultShaderPairs[kRendermodeColorNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderColorNormal"];
    _defaultShaderPairs[kRendermodeColorNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorNormal"];

    _defaultShaderPairs[kRendermodeTexNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderTexNormal"];
    _defaultShaderPairs[kRendermodeTexNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderTexNormal"];

    _defaultShaderPairs[kRendermodeColorTexNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderColorTexNormal"];
    _defaultShaderPairs[kRendermodeColorTexNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorTexNormal"];

    for(int i=0; i<kRendermodeMax; i++)
    {
        assert(_defaultShaderPairs[i].vertexFunction);
        assert(_defaultShaderPairs[i].fragmentFunction);
    }

    _commandQueue = [_device newCommandQueue];
    
    _view = view;
    
    _ctx = ctx;
    
    // set this here until we get a getviewport size
    _ctx->state.viewport.width  = _viewportSize.x;
    _ctx->state.viewport.height = _viewportSize.y;

    [self bindObjFuncsMTRenderContext];
    
    return self;
}

- (void) flushToScreen
{
    if (_currentRenderEncoder)
    {
        [_currentRenderEncoder endEncoding];
        _currentRenderEncoder = NULL;
    }
    
    // Schedule a present once the framebuffer is complete using the current drawable
    [_currentCommandBuffer presentDrawable:_view.currentDrawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [_currentCommandBuffer commit];
    
    _currentCommandBuffer = NULL;
}

#pragma mark ##############################################################################################################
#pragma mark unused
#pragma mark ##############################################################################################################
#if 0

- (void)enableRenderMode:(unsigned)mode
{
    _currentDrawState.render_mode |= RM_STATE_BIT(mode);
}

- (void)disableRenderMode:(unsigned)mode
{
    _currentDrawState.render_mode &= ~RM_STATE_BIT(mode);
}

- (void)enableFill
{
    [self enableRenderMode: kRM_Fill];
}

- (void)disableFill
{
    [self disableRenderMode: kRM_Fill];
}

- (void)enableStroke
{
    [self enableRenderMode: kRM_Stroke];
}

- (void)disableStroke
{
    [self disableRenderMode: kRM_Stroke];
}

- (void)getViewportWidth:(unsigned *)width Height:(unsigned *)height
{
    *width  = _viewportSize[0];
    *height = _viewportSize[1];
}

- (void)setClearColor:(RGBAColor)color
{
    _currentDrawState.clear_color = color;
    _currentDrawState.dirty_state |= DIRTY_RENDER_PASS;
}

- (void)setStrokeColor:(RGBAColor)color
{
    _currentDrawState.stroke_color = color;
    _currentDrawState.dirty_state |= DIRTY_UPLOADED_STATE;
}

- (void)setFillColor:(RGBAColor)color
{
    _currentDrawState.fill_color = color;
    _currentDrawState.dirty_state |= DIRTY_UPLOADED_STATE;
}

- (void)drawLine2D:(Point2D)p1 to:(Point2D)p2
{
    _currentDrawState.uploaded_state.prim_type = PrimitiveTypeLine;
    
    [self updateRenderBuffer];
    
    Point2D vertices[2];
    
    vertices[0] = p1;
    vertices[1] = p2;
    
    [_currentRenderEncoder setVertexBytes:vertices length:sizeof(vertices) atIndex: VertexInputIndexVertices];
    
    // Draw the line.
    [_currentRenderEncoder drawPrimitives:MTLPrimitiveTypeLine
                              vertexStart:0
                              vertexCount:2];
}

- (void)begin:(PrimitiveType)prim_type
{
    if (_currentDrawState.prim_type != PrimitiveTypeNone)
    {
        printf("begin issued while in begin / end\n");
        return;
    }
    
    _currentDrawState.prim_type         = prim_type;
    _currentDrawState.current_vertex    = 0;
}

- (void)end
{
    [self updateRenderBuffer];

    // vertex buffer
    size_t size;
    
    size = sizeof(Vertex4ColorTex) * NUM_VERTICES;
    [_currentRenderEncoder setVertexBytes:_currentDrawState.vertices length: size atIndex: VertexInputIndexVertices];
}

- (void)drawArc:(Point2D)origin width:(float)width height:(float)height start:(float)start end:(float)end
{
    if ((end - start) > 360)
    {
        return;
    }
    
    if (width <= 0)
    {
        return;
    }
    
    if (height <= 0)
    {
        return;
    }
    
    if ((_currentDrawState.render_mode & (RM_FILL_BIT | RM_STROKE_BIT)) == 0)
    {
        NSLog(@"RM_FILL_BIT | RM_STROKE_BIT == 0, no draw");
        
        return;
    }
    
    [self updateRenderBuffer];
    
    float delta_sweep;
    delta_sweep = (end - start);
    
    // each triangle fills roughly 2 degress of arc, use temp to round this so delta is matched
    float temp;
    temp = delta_sweep / 2.0;
    temp = ceilf(temp);

    float delta_angle;
    delta_angle = delta_sweep / temp;
    delta_angle = ceilf(delta_angle);
    
    int num_triangles;
    num_triangles = delta_sweep / delta_angle + 1;
    
    int num_indices;
    num_indices = num_triangles + 2;    // include origin + last point
    
    Point2D *vertices;
    vertices = newArray(Point2D, num_indices);

    // vertex 0 is origin
    vertices[0] = origin;

    float a;
    a = start;
    
    for(int i=1; i<num_indices; i++)
    {
        float r;
        
        r = deg2rad(a);
        
        vertices[i].x = ceil(origin.x + width * cosf(r));
        vertices[i].y = ceil(origin.y + height * sinf(r));
        
        a += delta_angle;
    }
    
    NSUInteger index_count;
    index_count = num_triangles * 3;
    
    unsigned short *indices;
    indices = newArray(unsigned short, index_count);
    
    int vertex_index;
    vertex_index = 0;
    for(int i=0; i<index_count; i+=3)
    {
        // clockwise triangle from origin
        indices[i]      = 0;
        indices[i+1]    = vertex_index + 1;
        indices[i+2]    = vertex_index;
        
        vertex_index++;
    }

    size_t size;
    
    // vertex buffer
    size = sizeof(Point2D) * num_indices;
    [_currentRenderEncoder setVertexBytes:vertices length: size atIndex: VertexInputIndexVertices];

    // index buffer
    id<MTLBuffer>mtl_indices_buffer;

    size = sizeof(unsigned short) * index_count;
    mtl_indices_buffer = [_device newBufferWithBytes:indices
                                              length:size
                                             options:MTLResourceStorageModeManaged];
    assert(mtl_indices_buffer);
                          
    // Draw arc
    if (_currentDrawState.render_mode & RM_FILL_BIT)
    {
        _currentDrawState.uploaded_state.prim_type = PrimitiveTypeTriangle;

        [self forceUploadDrawState];
        
        [_currentRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                          indexCount:index_count
                                           indexType:MTLIndexTypeUInt16
                                         indexBuffer:mtl_indices_buffer
                                   indexBufferOffset:0];
    }

    if (_currentDrawState.render_mode & RM_STROKE_BIT)
    {
        vertex_index = 0;
        for(int i=0; i<num_indices-1; i++)
        {
            indices[i]      = i;
            vertex_index++;
        }
        
        size = sizeof(unsigned short) * vertex_index;
        mtl_indices_buffer = [_device newBufferWithBytes:indices
                                                  length:size
                                                 options:MTLResourceStorageModeManaged];
        
        _currentDrawState.uploaded_state.prim_type = PrimitiveTypeLine;
        
        [self forceUploadDrawState];
        
        [_currentRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeLineStrip
                                          indexCount:vertex_index
                                           indexType:MTLIndexTypeUInt16
                                         indexBuffer:mtl_indices_buffer
                                   indexBufferOffset:0];
    }
    
    free(vertices);
    free(indices);
}
#endif

@end

NS_ASSUME_NONNULL_END

