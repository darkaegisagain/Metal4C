//
//  metal4c_Renderer.m
//  Metal4C
//
//  Created by Michael Larson on 2/21/26.
//

#import <MetalKit/MetalKit.h>

#import "metal4c_Renderer.h"

#import "metal4c_shader_types.h"
#import "metal4c_context.h"

#define NUM_INFLIGHT_BUFFERS    16
#define NUM_VERTEX_BUFFERS      32

@implementation Renderer
{
    // The device (aka GPU) used to render
    id<MTLDevice>               _device;
    
    MTKTextureLoader            *_textureLoader;
    
    // The current size of the view.
    vector_uint2                _viewportSize;
    
    MTRenderContextRec          *_ctx;
    MTKView                     *_view;
    
    id<CAMetalDrawable>         _currentDrawable;
    
    // The command Queue used to submit commands.
    id<MTLCommandQueue>         _commandQueue;
    id<MTLCommandBuffer>        _currentCommandBuffer;
    id<MTLRenderPipelineState>  _currentPipelineState;
    id<MTLRenderCommandEncoder> _currentRenderEncoder;
    id<MTLTexture>              _currentTexture;
    
    MTuint                      _currentBufferSetInFlight;
    MTuint                      _currentVertexBuffer;
    MTsizei                     _vertexBufferOffset, _vertexBufferSize;
    id<MTLBuffer>               _vertexBuffers[NUM_INFLIGHT_BUFFERS][NUM_VERTEX_BUFFERS];
    
    id<MTLLibrary>              _defaultShaderLibrary;
    ShaderFunctionPair          _defaultShaderPairs[MTVertexShaderModeMax][MTFragmentShaderModeMax];
    
    MTuint                      _num_command_buffers_per_swap;
    MTuint                      _num_pipeline_state_per_swap;
    MTuint                      _num_render_encoders_per_swap;
}

#pragma mark bindVertexTex
- (void)bindVertexTex:(nullable id<MTLTexture>)mtl_tex unit:(unsigned)unit
{
    [_currentRenderEncoder setVertexTexture:mtl_tex
                                      atIndex:TextureIndexBaseColor + unit];
}

#pragma mark bindFragmentTex
- (void)bindFragmentTex:(nullable id<MTLTexture>)mtl_tex unit:(unsigned)unit
{
    [_currentRenderEncoder setFragmentTexture:mtl_tex
                                      atIndex:TextureIndexBaseColor + unit];
}

#pragma mark bindVertexSampler
- (void)bindVertexSampler:(nullable id<MTLSamplerState>)mtl_sampler unit:(unsigned)unit
{
    [_currentRenderEncoder setVertexSamplerState:mtl_sampler
                                      atIndex:TextureIndexBaseColor + unit];
}

#pragma mark bindFragmentTex
- (void)bindFragmentSampler:(nullable id<MTLSamplerState>)mtl_sampler unit:(unsigned)unit
{
    [_currentRenderEncoder setFragmentSamplerState:mtl_sampler
                                      atIndex:TextureIndexBaseColor + unit];
}

#pragma mark freeDirtyRegions
- (void)freeDirtyRegions:(MTBuffer *)buf
{
    if(buf->dirty_region.next)
    {
        MTDirtyRegion *dirty_rgn;
        
        dirty_rgn = &buf->dirty_region;

        do
        {
            if (dirty_rgn != &buf->dirty_region)
            {
                MTDirtyRegion *temp;
                
                temp = dirty_rgn->next;
                
                // put region on free list
                dirty_rgn->next = _ctx->free_dirty_region_list;
                _ctx->free_dirty_region_list = dirty_rgn;
                
                dirty_rgn = temp;
            }
            
            if (dirty_rgn)
            {
                dirty_rgn = dirty_rgn->next;
            }
        } while(dirty_rgn);
    }
    
    buf->dirty_region.size = 0;
    buf->dirty_region.offset = 0;
    buf->dirty_region.next = NULL;
}

- (void)fillStencilDesc: (MTLStencilDescriptor *)desc fromMTStencilDesc:(MTStencilDesc *)src_desc
{
    desc.stencilCompareFunction = src_desc->compare_func;
    desc.stencilFailureOperation = src_desc->stencil_failure_op;
    desc.depthFailureOperation = src_desc->depth_failure_op;
    desc.depthStencilPassOperation = src_desc->depth_stencil_pass_op;
    desc.readMask = src_desc->read_mask;
    desc.writeMask = src_desc->write_mask;
}

- (MTLSamplerDescriptor *) newMTLSamplerDescriptorFromMTSampler:(MTSampler *)sampler
{
    MTLSamplerDescriptor *desc;
    
    desc = [[MTLSamplerDescriptor alloc] init];
    
    // NSLog(@"%@", desc);
    
    desc.minFilter      = (MTLSamplerMinMagFilter)sampler->desc.min_filter;
    desc.magFilter      = (MTLSamplerMinMagFilter)sampler->desc.mag_filter;
    desc.mipFilter      = (MTLSamplerMipFilter)sampler->desc.mip_filter;
    desc.maxAnisotropy  = sampler->desc.max_anisotropy;
    desc.sAddressMode   = (MTLSamplerAddressMode)sampler->desc.s_address_mode;
    desc.tAddressMode   = (MTLSamplerAddressMode)sampler->desc.t_address_mode;
    desc.rAddressMode   = (MTLSamplerAddressMode)sampler->desc.r_address_mode;
    desc.borderColor    = (MTLSamplerBorderColor)sampler->desc.boarder_color;
    desc.normalizedCoordinates = sampler->desc.normalized_coordinates;
    desc.lodMinClamp    = sampler->desc.lod_min_clamp;
    desc.lodMaxClamp    = sampler->desc.lod_max_clamp;
    desc.lodBias        = sampler->desc.lod_average;
    desc.compareFunction = (MTLCompareFunction)sampler->desc.compare_function;
    desc.supportArgumentBuffers = sampler->desc.support_argument_buffers;
    
    return desc;
}

- (id)newDrawBufferWithCustomSize:(MTPixelFormat)pixelFormat isDepthStencil:(bool)depthStencil customSize:(CGSize)size
{
    id<MTLTexture> texture;
    MTLTextureDescriptor *tex_desc;

    tex_desc = [[MTLTextureDescriptor alloc] init];
    tex_desc.width = (NSUInteger)size.width;
    tex_desc.height = (NSUInteger)size.height;
    tex_desc.width = (NSUInteger)size.width;
    tex_desc.pixelFormat = (MTLPixelFormat)pixelFormat;
    tex_desc.usage = MTLTextureUsageRenderTarget;

    if (depthStencil)
    {
        tex_desc.storageMode = MTLStorageModePrivate;
    }

    texture = [_device newTextureWithDescriptor:tex_desc];
    assert(texture);

    return texture;
}

#pragma mark updateBuffer
- (id<MTLBuffer>)updateBuffer:(MTBuffer *)buf
{
    id<MTLBuffer> mtl_buf;

    mtl_buf = (__bridge id<MTLBuffer>)(buf->mtl_buffer);
    
    if (mtl_buf == NULL)
    {
        mtl_buf = [_device newBufferWithBytes:(void *)buf->data length: buf->size  options:MTLResourceCPUCacheModeWriteCombined | MTLResourceStorageModeManaged];
        mtl_buf.label = @"VertexBuffer";

        assert(mtl_buf);
        
        buf->mtl_buffer = (void *)CFBridgingRetain(mtl_buf);
        
        buf->dirty &= ~(DIRTY_BUFFER_DATA | DIRTY_BUFFER_ADDRESS);
    }
    else if (buf->dirty & DIRTY_BUFFER_ADDRESS)
    {
        CFBridgingRelease(buf->mtl_buffer);
        
        mtl_buf = [_device newBufferWithBytes:(void *)buf->data length: buf->size  options:MTLResourceCPUCacheModeWriteCombined | MTLResourceStorageModeManaged];
        mtl_buf.label = @"VertexBuffer";

        assert(mtl_buf);
        
        buf->mtl_buffer = (void *)CFBridgingRetain(mtl_buf);

        buf->dirty &= ~(DIRTY_BUFFER_DATA | DIRTY_BUFFER_ADDRESS);
    }
    else if (buf->dirty & DIRTY_BUFFER_DATA)
    {
        void *ptr;
        
        ptr = [mtl_buf contents];
        
        MTDirtyRegion *dirty_rgn;
        
        dirty_rgn = &buf->dirty_region;
        while(dirty_rgn)
        {
            memcpy(ptr + dirty_rgn->offset, (void *)buf->data + dirty_rgn->offset, dirty_rgn->size);
            
            NSRange range;
            
            range = NSMakeRange(dirty_rgn->offset, dirty_rgn->size);
            
            [mtl_buf didModifyRange: range];
         
            dirty_rgn = dirty_rgn->next;
        }
        
        [self freeDirtyRegions:buf];
        
        buf->dirty &= ~DIRTY_BUFFER_DATA;
    }
    
    return mtl_buf;
}

-(id<MTLFunction>) getMetalFunction:(MTShaderLibrary *)lib atIndex:(MTuint)index
{
    NSMutableArray *mtl_functions;
    
    mtl_functions = (__bridge NSMutableArray *)lib->mtl_lib_functions;
    
    return [mtl_functions objectAtIndex:index];
}

- (void)setPipelineStateShaders:(MTLRenderPipelineDescriptor *)pipelineStateDescriptor
{
    id<MTLFunction> vertex_function;
    id<MTLFunction> fragment_function;
    
    if (STATE(vao))
    {
        MTVertexArray   *vao;

        vao = STATE(vao);
        
        if (vao->vertex_shader_binding.lib)
        {
            MTuint          vertex_shader_index;

            vertex_shader_index = vao->vertex_shader_binding.shader_index;
            
            MTShaderLibrary *vertex_shader_lib;
            
            vertex_shader_lib = STATE(vao)->vertex_shader_binding.shader_lib;
            assert(vertex_shader_lib);
            
            vertex_function = [self getMetalFunction:vertex_shader_lib atIndex:vertex_shader_index];
        }
        else
        {
            vertex_function = _defaultShaderPairs[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].vertexFunction;
        }

        if (vao->vertex_shader_binding.lib)
        {
            MTuint          fragment_shader_index;

            fragment_shader_index = vao->fragment_shader_binding.shader_index;
            
            MTShaderLibrary *fragment_shader_lib;
            
            fragment_shader_lib = STATE(vao)->fragment_shader_binding.shader_lib;
            assert(fragment_shader_lib);
            
            fragment_function = [self getMetalFunction:fragment_shader_lib atIndex:fragment_shader_index];
        }
        else
        {
            fragment_function = _defaultShaderPairs[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].fragmentFunction;
        }
    }
    else
    {
        if (STATE(vertex_shader_binding[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].lib))
        {
            MTuint          vertex_shader_index;
            
            vertex_shader_index = STATE(vertex_shader_binding[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].shader_index);
            
            MTShaderLibrary *shader_lib;
            
            shader_lib = STATE(vertex_shader_binding[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].shader_lib);
            assert(shader_lib);
            
            vertex_function = [self getMetalFunction:shader_lib atIndex:vertex_shader_index];
        }
        else
        {
            vertex_function = _defaultShaderPairs[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].vertexFunction;
        }
        
        if (STATE(fragment_shader_binding[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].lib))
        {
            MTuint          fragment_shader_index;
            
            fragment_shader_index = STATE(fragment_shader_binding[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].shader_index);
            
            MTShaderLibrary *shader_lib;
            
            shader_lib = STATE(fragment_shader_binding[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].shader_lib);
            assert(shader_lib);
            
            fragment_function = [self getMetalFunction:shader_lib atIndex:fragment_shader_index];
        }
        else
        {
            fragment_function = _defaultShaderPairs[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].fragmentFunction;
        }
        
        // hard to fail at this point bind to something
        if ((vertex_function == NULL) || (fragment_function == NULL))
        {
            mtWarningFunc("invalid shader bindings", __FUNCTION__);
            
            vertex_function = _defaultShaderPairs[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].vertexFunction;
            fragment_function = _defaultShaderPairs[STATE(vertex_shader_mode)][STATE(fragment_shader_mode)].fragmentFunction;
        }
    }
    
    pipelineStateDescriptor.vertexFunction = vertex_function;
    pipelineStateDescriptor.fragmentFunction = fragment_function;
}

- (void) createNewRenderBuffer
{
    MTColor color;
    
    color = STATE(clear_color);
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = _view.currentRenderPassDescriptor;
    assert(renderPassDescriptor);

    // update the current drawable
    if (_currentDrawable == NULL)
    {
        _currentDrawable = _view.currentDrawable;
    }
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(color.r, color.g, color.b, color.a);
    if (STATE(clear_mask))
    {
        if (STATE(clear_mask) & MT_CLEAR_COLOR_BUFFER)
        {
            renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        }
        else
        {
            renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        }
        
        if (STATE(clear_mask) & MT_CLEAR_DEPTH_BUFFER)
        {
            renderPassDescriptor.depthAttachment.clearDepth = STATE(clear_depth);
            renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        }
        else
        {
            renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionDontCare;
        }
        
        if (STATE(clear_mask) & MT_CLEAR_STENCIL_BUFFER)
        {
            renderPassDescriptor.stencilAttachment.clearStencil = STATE(clear_stencil);
            renderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionClear;
        }
        else
        {
            renderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionDontCare;
        }
        
        // need to deal with depth and stencil
        // printf("Need to deal with depth stencil clear");
        STATE(clear_mask) = 0;
    }
    else
    {
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionDontCare;
        renderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionDontCare;
    }
    
    if (STATE(depth_enable))
    {
        // Obtain a renderPassDescriptor generated from the view's drawable textures
        MTLRenderPassDescriptor *renderPassDescriptor = _view.currentRenderPassDescriptor;
        assert(renderPassDescriptor);
        
        if (renderPassDescriptor.depthAttachment.texture == NULL)
        {
            id<MTLTexture> texture, depth_texture;
            
            texture = _view.currentDrawable.texture;
            
            depth_texture = [self newDrawBufferWithCustomSize:STATE(depth_stencil_format) isDepthStencil:true customSize: CGSizeMake(texture.width, texture.height) ];
            
            renderPassDescriptor.depthAttachment.texture = depth_texture;
            
            if (_view.depthStencilPixelFormat == MTLPixelFormatInvalid)
            {
                _view.depthStencilPixelFormat = (MTLPixelFormat)STATE(depth_stencil_format);
            }
        }
        else
        {
            id<MTLTexture> tex;
            
            tex = renderPassDescriptor.depthAttachment.texture;
            
            MTLPixelFormat format;
            
            format = [tex pixelFormat];
            
            if (format != (MTLPixelFormat)STATE(depth_stencil_format))
            {
                id<MTLTexture> texture, depth_texture;
                
                texture = _view.currentDrawable.texture;
                
                depth_texture = [self newDrawBufferWithCustomSize:STATE(depth_stencil_format) isDepthStencil:true customSize: CGSizeMake(texture.width, texture.height) ];
                
                renderPassDescriptor.depthAttachment.texture = depth_texture;
                
                if (_view.depthStencilPixelFormat == MTLPixelFormatInvalid)
                {
                    _view.depthStencilPixelFormat = (MTLPixelFormat)STATE(depth_stencil_format);
                }
            }
        }
        
        if (STATE(stencil_enable))
        {
            if (renderPassDescriptor.depthAttachment.texture == NULL)
            {
                id<MTLTexture> texture, stencil_texture;
                
                texture = _view.currentDrawable.texture;
                
                stencil_texture = [self newDrawBufferWithCustomSize:STATE(depth_stencil_format) isDepthStencil:true customSize: CGSizeMake(texture.width, texture.height) ];
                
                renderPassDescriptor.stencilAttachment.texture = stencil_texture;
                
                if (_view.depthStencilPixelFormat == MTLPixelFormatInvalid)
                {
                    _view.depthStencilPixelFormat = (MTLPixelFormat)STATE(depth_stencil_format);
                }
            }
        }
    }
    
    if (_currentRenderEncoder)
    {
        [_currentRenderEncoder endEncoding];
        _currentRenderEncoder = NULL;
    }
    
    // create new render encoder
    _currentRenderEncoder = [_currentCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    assert(_currentRenderEncoder);
    
    _num_render_encoders_per_swap++;
    
    _currentRenderEncoder.label = @"RenderEncoder";
            
    // set this so the renderstate gets loaded
    _ctx->dirty_state |= DIRTY_RENDER_STATE;
}

- (void) createNewRenderPipeline
{
    /// Create the render pipeline.
     
    // Set up a descriptor for creating a pipeline state object
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];

    pipelineStateDescriptor.depthAttachmentPixelFormat = (MTLPixelFormat)STATE(depth_stencil_format);
    pipelineStateDescriptor.stencilAttachmentPixelFormat = (MTLPixelFormat)STATE(depth_stencil_format);

    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;

    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = false;

#if 0
    pipelineStateDescriptor.colorAttachments[i].sourceRGBBlendFactor = _src_blend_rgb_factor[i];
    pipelineStateDescriptor.colorAttachments[i].destinationRGBBlendFactor = _dst_blend_rgb_factor[i];
    pipelineStateDescriptor.colorAttachments[i].sourceAlphaBlendFactor = _src_blend_alpha_factor[i];
    pipelineStateDescriptor.colorAttachments[i].destinationAlphaBlendFactor = _dst_blend_alpha_factor[i];

    pipelineStateDescriptor.colorAttachments[i].rgbBlendOperation = _rgb_blend_operation[i];
    pipelineStateDescriptor.colorAttachments[i].alphaBlendOperation = _alpha_blend_operation[i];

    pipelineStateDescriptor.colorAttachments[i].writeMask = _color_mask[i];
#endif
    
    [self setPipelineStateShaders:pipelineStateDescriptor];

    /// fill out vertex descriptor
    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    
    if (STATE(vao))
    {
        for(int i=0; i<MAX_VERTEX_ATTIBS; i++)
        {
            // early exit
            if ((STATE(vao)->vertex_desc_mask >> i) == 0)
            {
                break;
            }

            if (STATE(vao)->vertex_desc_mask & (0x1 << i))
            {
                vertexDescriptor.attributes[i].bufferIndex = STATE(vao)->vertex_arrays[i].buffer_index;
                vertexDescriptor.attributes[i].offset = STATE(vao)->vertex_arrays[i].offset;
                vertexDescriptor.attributes[i].format = (MTLVertexFormat)STATE(vao)->vertex_arrays[i].format;
                vertexDescriptor.layouts[i].stride = STATE(vao)->vertex_arrays[i].stride;
                vertexDescriptor.layouts[i].stepRate = STATE(vao)->vertex_arrays[i].step_rate;
                vertexDescriptor.layouts[i].stepFunction = (MTLVertexStepFunction)STATE(vao)->vertex_arrays[i].step_function;
            }
        }
    }
    else
    {
        // for now only Vertex4ColorNormalTex is used as a source descriptor
        vertexDescriptor.attributes[0].bufferIndex = 0;
        vertexDescriptor.attributes[0].offset = 0;
        vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
        vertexDescriptor.layouts[0].stride = sizeof(Vertex4ColorNormalTex);
        vertexDescriptor.layouts[0].stepRate = 1;
        vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    }
    
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;

    NSError *error = NULL;
    _currentPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                    error:&error];
    NSAssert(_currentPipelineState, @"Failed to create pipeline state: %@", error);

    _num_pipeline_state_per_swap++;
}

// update any state for the current RenderEncoder
- (void)updateCurrentRenderEncoder
{
    // Set the region of the drawable to draw into.
    [_currentRenderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];

    if (STATE(cull_mode))
    {
        [_currentRenderEncoder setCullMode: (MTLCullMode)STATE(cull_mode)];
    }
    
    if (STATE(winding_mode))
    {
        [_currentRenderEncoder setFrontFacingWinding:(MTLWinding)STATE(winding_mode)];
    }
    
    if (STATE(depth_clip_mode))
    {
        [_currentRenderEncoder setDepthClipMode:(MTLDepthClipMode)STATE(depth_clip_mode)];
    }
    
    if (STATE(triangle_fill_mode))
    {
        [_currentRenderEncoder setTriangleFillMode:(MTLTriangleFillMode)STATE(triangle_fill_mode)];
    }
    
    if (STATE(scissor_enable))
    {
        MTLScissorRect rect;
        
        rect.x = STATE(scissor_rect.x);
        rect.y = STATE(scissor_rect.y);
        rect.width = STATE(scissor_rect.width);
        rect.height = STATE(scissor_rect.height);
        
        [_currentRenderEncoder setScissorRect:rect];
    }

    if (STATE(depth_enable))
    {
        // setup depth stencil testing
        MTLDepthStencilDescriptor *depth_stencil_desc;
        
        depth_stencil_desc = [[MTLDepthStencilDescriptor alloc] init];
        
        depth_stencil_desc.depthCompareFunction = STATE(depth_test_mode);
        depth_stencil_desc.depthWriteEnabled = YES;
        
        if (STATE(stencil_enable))
        {
            [self fillStencilDesc: depth_stencil_desc.frontFaceStencil fromMTStencilDesc: &STATE(front_stencil_desc)];
            [self fillStencilDesc: depth_stencil_desc.backFaceStencil fromMTStencilDesc: &STATE(back_stencil_desc)];
        }
        
        id <MTLDepthStencilState> dsState = [_device newDepthStencilStateWithDescriptor:depth_stencil_desc];
        assert(dsState);
        
        [_currentRenderEncoder setDepthStencilState: dsState];
    }
    
    if (STATE(vao))
    {
        for(int i=0; i<MAX_VERTEX_ATTIBS; i++)
        {
            // early exit
            if ((STATE(vao)->bindings_mask >> i) == 0)
            {
                break;
            }

            if (STATE(vao)->vertex_buffers[i])
            {
                MTBuffer *buf;
                
                buf = STATE(vao)->vertex_buffers[i];

                id<MTLBuffer> mtl_buf;

                mtl_buf = (__bridge id<MTLBuffer>)(buf->mtl_buffer);

                if (buf->dirty & (DIRTY_BUFFER_DATA | DIRTY_BUFFER_ADDRESS))
                {
                    mtl_buf = [self updateBuffer:buf];
                }
                else if (mtl_buf == NULL)
                {
                    mtl_buf = [self updateBuffer:buf];
                }

                [_currentRenderEncoder setVertexBuffer: mtl_buf offset:0 atIndex: i];
            }
        }
    }
    else
    {
        [_currentRenderEncoder setVertexBuffer:_vertexBuffers[_currentBufferSetInFlight][_currentVertexBuffer] offset:0 atIndex:VertexInputIndexVertices];
    }
    
    if (STATE(instance_buffer))
    {
        MTBuffer *buf;
        
        buf = STATE(instance_buffer);

        id<MTLBuffer> mtl_buf;
        
        mtl_buf = [self updateBuffer: buf];
        
        [_currentRenderEncoder setVertexBuffer: mtl_buf offset:0 atIndex:VertexInputIndexInstanceArray];
    }
    else
    {
        [_currentRenderEncoder setVertexBuffer: NULL offset:0 atIndex:VertexInputIndexInstanceArray];
    }
}

- (void) updateVertexTextures
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

- (void) updateFragmentTextures
{
    for(int i=0; i<MAX_TEXTURE_UNITS; i++)
    {
        if ((STATE(enabled_fragment_textures) >> i) == 0)
        {
            break;
        }
        
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
    }
}

- (void) updateVertexSamplers
{
    for(int i=0; i<MAX_TEXTURE_UNITS; i++)
    {
        if (STATE(enabled_vertex_samplers & (0x1 << i)))
        {
            unsigned name;
            
            name = STATE(vertex_samplers[i]);
            
            if (isValidKey(STATE(sampler_table), name))
            {
                MTSampler *sampler;
                
                sampler = getKeyData(STATE(sampler_table), name);
                
                id<MTLSamplerState> mtl_sampler;
                
                if (sampler->mtl_sampler == NULL)
                {
                    MTLSamplerDescriptor *desc;
                    
                    desc = [self newMTLSamplerDescriptorFromMTSampler: sampler];

                    mtl_sampler = [_device newSamplerStateWithDescriptor:desc];
                    
                    sampler->mtl_sampler = (void *)CFBridgingRetain(mtl_sampler);
                }
                else
                {
                    mtl_sampler = (__bridge id<MTLSamplerState>)(sampler->mtl_sampler);
                }
                
                [self bindVertexSampler:mtl_sampler unit:i];
            }
        }
        else
        {
            [self bindVertexSampler:NULL unit:i];
        }
        
        if ((STATE(enabled_vertex_samplers) >> (i + 1)) == 0)
        {
            break;
        }
    }
}

- (void) updateFragmentSamplers
{
    for(int i=0; i<MAX_TEXTURE_UNITS; i++)
    {
        if ((STATE(enabled_fragment_samplers) >> i) == 0)
        {
            break;
        }

        if (STATE(enabled_fragment_samplers) & (0x1 << i))
        {
            unsigned name;
            
            name = STATE(fragment_samplers[i]);
            
            if (isValidKey(STATE(sampler_table), name))
            {
                MTSampler *sampler;
                
                sampler = getKeyData(STATE(sampler_table), name);
                
                id<MTLSamplerState> mtl_sampler;
                
                if (sampler->mtl_sampler == NULL)
                {
                    MTLSamplerDescriptor *desc;
                    
                    desc = [self newMTLSamplerDescriptorFromMTSampler: sampler];

                    mtl_sampler = [_device newSamplerStateWithDescriptor:desc];
                    
                    sampler->mtl_sampler = (void *)CFBridgingRetain(mtl_sampler);
                }
                else
                {
                    mtl_sampler = (__bridge id<MTLSamplerState>)(sampler->mtl_sampler);
                }
                
                [self bindFragmentSampler: mtl_sampler unit:i];
            }
        }
        else
        {
            [self bindFragmentSampler:NULL unit:i];
        }
    }
}

- (void) updateVAOBuffers
{
    for(int i=0; i<MAX_VERTEX_ATTIBS; i++)
    {
        if ((STATE(vao)->bindings_mask >> i) == 0)
        {
            break;
        }
        
        if (STATE(vao)->vertex_buffers[i])
        {
            MTBuffer *buf;
            
            buf = STATE(vao)->vertex_buffers[i];
            
            if (buf->dirty & DIRTY_BUFFER_DATA)
            {
                id<MTLBuffer> mtl_buf;
                
                mtl_buf = [self updateBuffer:buf];
                
                void *ptr;
                
                ptr = [mtl_buf contents];
                assert(ptr);
                
                MTDirtyRegion *dirty_rgn;
                
                unsigned dirty_region_count = 0;
                
                dirty_rgn = &buf->dirty_region;
                while(dirty_rgn)
                {
                    memcpy(ptr + dirty_rgn->offset, (void *)buf->data + dirty_rgn->offset, dirty_rgn->size);
                    
                    NSRange range;
                    
                    range = NSMakeRange(dirty_rgn->offset, dirty_rgn->size);
                    
                    [mtl_buf didModifyRange: range];
                    
                    dirty_region_count++;
                    // printf("dirty_region_count: %d offset:%zul size:%zul\n",
                    //        dirty_region_count, dirty_rgn->offset, dirty_rgn->size);
                    
                    if (dirty_rgn != &buf->dirty_region)
                    {
                        MTDirtyRegion *temp;
                        
                        temp = dirty_rgn->next;
                        
                        // put region on free list
                        dirty_rgn->next = _ctx->free_dirty_region_list;
                        _ctx->free_dirty_region_list = dirty_rgn;
                        
                        dirty_rgn = temp;
                    }
                    else
                    {
                        dirty_rgn = dirty_rgn->next;
                    }
                }
                
                buf->dirty_region.offset = 0;
                buf->dirty_region.size = 0;
                buf->dirty_region.next = NULL;
                
                buf->dirty &= ~DIRTY_BUFFER_DATA;
            }
        }
    }
}

#pragma mark updateRenderer
- (void)updateRenderer
{
    if (_currentCommandBuffer == NULL)
    {
        // Create a new command buffer for each render pass to the current drawable
        _currentCommandBuffer = [_commandQueue commandBuffer];
        assert(_currentCommandBuffer);
        
        _num_command_buffers_per_swap++;

        _currentCommandBuffer.label = @"CommandBuffer";
                
        // since render pass descriptors and pipelines are created with a command buffer
        // you should recreate these also
        _ctx->dirty_state |= (DIRTY_RENDER_PASS | DIRTY_PIPELINE);
    }
    
    // update render pass descriptor
    if (_ctx->dirty_state & DIRTY_RENDER_PASS)
    {
        [self createNewRenderBuffer];
    }
        
    if (_ctx->dirty_state & DIRTY_BUFFER)
    {
        if (STATE(vao))
        {
            [self updateVAOBuffers];
        }
    }

    if (_ctx->dirty_state & DIRTY_RENDER_STATE)
    {
        [self updateCurrentRenderEncoder];
    }
    
    if (_ctx->dirty_state & DIRTY_PIPELINE)
    {
        [self createNewRenderPipeline];

        [_currentRenderEncoder setRenderPipelineState: _currentPipelineState];
    }
    
    if (_ctx->dirty_state & (DIRTY_PIPELINE | DIRTY_RENDER_PASS | DIRTY_TEXTURE_UNIT))
    {
        if (STATE(enabled_vertex_textures))
        {
            [self updateVertexTextures];
        }
        
        if (STATE(enabled_fragment_textures))
        {
            [self updateFragmentTextures];
        }

        if (STATE(enabled_vertex_samplers))
        {
            [self updateVertexSamplers];
        }
        
        if (STATE(enabled_fragment_samplers))
        {
            [self updateFragmentSamplers];
        }
    }

    if (_ctx->dirty_state & DIRTY_UPLOADED_STATE)
    {
        _ctx->uploaded_state.viewport_size[0]   = STATE(viewport.width);
        _ctx->uploaded_state.viewport_size[1]   = STATE(viewport.height);
        _ctx->uploaded_state.prim_type          = STATE(prim_type);
        _ctx->uploaded_state.point_size         = STATE(point_size);
        
        mtUpdateMVP();
        memcpy(&_ctx->uploaded_state.mvp_matrix, &MAT(mvp), sizeof(MAT(mvp)));
    }

    // upload uniforms
    [_currentRenderEncoder setVertexBytes:&_ctx->uploaded_state length:sizeof(_ctx->uploaded_state) atIndex: VertexInputIndexUploadedState];
    
    // clear dirty state
    _ctx->dirty_state = 0;
}

#pragma mark mtlFlushVertexEng
- (void)mtlFlushVertexEng
{
    // vertex buffer
    size_t size;
    
    // buffer is always Vertex4ColorNormalTex
    size = sizeof(Vertex4ColorNormalTex) * VENG(current_vertex);
    
    if (_ctx->dirty_state & DIRTY_VERTEX_ENGINE_SIZES)
    {
        _currentVertexBuffer = 0;
        _vertexBufferOffset = 0;
        _vertexBufferSize = sizeof(Vertex4ColorNormalTex) * VENG(num_vertices) * 32;

        for(int j=0; j<NUM_INFLIGHT_BUFFERS; j++)
        {
            for(int i=0; i<NUM_VERTEX_BUFFERS; i++)
            {
                _vertexBuffers[j][i] = [_device newBufferWithLength:_vertexBufferSize  options:MTLResourceCPUCacheModeWriteCombined | MTLResourceStorageModeManaged];
                _vertexBuffers[j][i].label = @"VertexBuffer";
            }
        }
        
        _currentBufferSetInFlight = 0;
        
        _ctx->dirty_state &= ~DIRTY_VERTEX_ENGINE_SIZES;
    }
    else
    {
        if ((_vertexBufferOffset + size) > _vertexBufferSize)
        {
            // move to next vertex buffer
            _currentVertexBuffer++;
            _vertexBufferOffset = 0;
            
            if(_currentVertexBuffer >= NUM_VERTEX_BUFFERS)
            {
                _currentVertexBuffer = 0;
                _vertexBufferOffset = 0;
                
                _currentBufferSetInFlight++;
                
                if (_currentBufferSetInFlight >= NUM_INFLIGHT_BUFFERS)
                {
                    _currentBufferSetInFlight = 0;
                    
                    // we maxed out our vertex buffers move to new set
                    [_currentRenderEncoder endEncoding];
                    
                    [_currentCommandBuffer commit];
                    
                    _currentRenderEncoder = NULL;
                    _currentCommandBuffer = NULL;
                    
                    [self updateRenderer];
                }
            }
            
            // update the current vertex buffer
            [_currentRenderEncoder setVertexBuffer:_vertexBuffers[_currentBufferSetInFlight][_currentVertexBuffer] offset:0 atIndex:VertexInputIndexVertices];
        }
    }
    
    void *ptr;
    
    ptr = [_vertexBuffers[_currentBufferSetInFlight][_currentVertexBuffer] contents] + _vertexBufferOffset;
    memcpy(ptr, VENG(vertices), size);
    
    NSRange range;

    range.length = size;
    range.location = _vertexBufferOffset;
    
    assert(_vertexBuffers[_currentBufferSetInFlight][_currentVertexBuffer]);
    [_vertexBuffers[_currentBufferSetInFlight][_currentVertexBuffer] didModifyRange:range];

    MTsizei offset;
    
    offset = _vertexBufferOffset / sizeof(Vertex4ColorNormalTex);

    VENG(base_vertex) = (MTint)offset;
    
    if (VENG(instance_count) > 1)
    {
        size_t size;
        void *data;
        
        assert(STATE(instance_buffer));
               
        size = STATE(instance_buffer)->size;
        data = (void *)STATE(instance_buffer)->data;
        
        if (size < 4096)
        {
            [_currentRenderEncoder setVertexBytes:data length:size atIndex:VertexInputIndexInstanceArray];
        }
        else
        {
            id<MTLBuffer> instance_buffer;
            
            instance_buffer = [_device newBufferWithBytes:data length:size options:MTLResourceCPUCacheModeWriteCombined];
            
            [_currentRenderEncoder setVertexBuffer:instance_buffer offset:0 atIndex:VertexInputIndexInstanceArray];
        }
    }
    
    if (STATE(in_element_begin_end))
    {
        id<MTLBuffer>   index_buffer;
        MTsizei         size;
        
        size = VENG(current_index) * sizeof(MTuint);
        
        index_buffer = [_device newBufferWithBytes: VENG(indices) length:size  options:MTLResourceCPUCacheModeWriteCombined];
                
        if (VENG(instance_count) == 1)
        {
            [_currentRenderEncoder drawIndexedPrimitives:(MTLPrimitiveType)STATE(prim_type)
                                              indexCount:VENG(current_index)
                                               indexType: MTLIndexTypeUInt32
                                             indexBuffer:index_buffer indexBufferOffset:0
                                            instanceCount:1
                                              baseVertex:VENG(base_vertex)
                                            baseInstance:0];
        }
        else
        {
            if (VENG(base_vertex) == 0)
            {
                [_currentRenderEncoder drawIndexedPrimitives:(MTLPrimitiveType)STATE(prim_type)
                                                  indexCount:VENG(current_index)
                                                   indexType: MTLIndexTypeUInt32
                                                 indexBuffer:index_buffer indexBufferOffset:0
                                                instanceCount:VENG(instance_count)];
            }
            else
            {
                [_currentRenderEncoder drawIndexedPrimitives:(MTLPrimitiveType)STATE(prim_type)
                                                  indexCount:VENG(current_index)
                                                   indexType: MTLIndexTypeUInt32
                                                 indexBuffer:index_buffer indexBufferOffset:0
                                                instanceCount:VENG(instance_count)
                                                  baseVertex:VENG(base_vertex)
                                                baseInstance:VENG(base_instance)];
            }
        }
    }
    else
    {
        if (VENG(instance_count) == 1)
        {
            [_currentRenderEncoder drawPrimitives:(MTLPrimitiveType)STATE(prim_type)
                                      vertexStart:offset
                                      vertexCount:VENG(current_vertex)];
        }
        else
        {
            [_currentRenderEncoder drawPrimitives:(MTLPrimitiveType)STATE(prim_type)
                                      vertexStart:offset
                                      vertexCount:VENG(current_vertex)
                                    instanceCount:VENG(instance_count)
                                     baseInstance:VENG(base_instance)];
        }
    }
    
    _vertexBufferOffset += size;
}

void mtlFlushVertexEng(MTRenderContextRec *mt_ctx)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlFlushVertexEng];
}

#pragma mark mtlBegin
- (void)mtlBegin:(MTPrimitiveType)type
{
    // copy base vert to current pos
    [self updateRenderer];
}

void mtlBegin(MTRenderContextRec *mt_ctx, MTPrimitiveType type)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlBegin: type];
}


#pragma mark mtlEnd
- (void)mtlEnd
{
    [self mtlFlushVertexEng];
}

void mtlEnd(MTRenderContextRec *mt_ctx)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlEnd];
}

#pragma mark Vertex Array Draw Calls
- (void)mtlDrawArray: (MTDrawArrayPrimitive *)draw
{
    [self updateRenderer];

    switch(draw->draw_style)
    {
        case MTPrimitveDrawArray:
            [_currentRenderEncoder drawPrimitives:(MTLPrimitiveType)draw->type
                                      vertexStart:draw->offset
                                      vertexCount:draw->count];
            break;
            
        case MTPrimitveDrawArrayInstance:
            [_currentRenderEncoder drawPrimitives:(MTLPrimitiveType)draw->type
                                      vertexStart:draw->offset
                                      vertexCount:draw->count
                                    instanceCount:draw->instance_count
                                     baseInstance:draw->base_instance];
            break;

        case MTPrimitveDrawIndex:
        case MTPrimitveDrawIndexInstance:
        case MTPrimitveDrawIndexInstanceBase:
        case MTPrimitveDrawIndexOffsetInstanceBase:
        {
            MTBuffer    *index_buffer;
            
            index_buffer = STATE(index_buffer);
            
            assert(index_buffer);
            
            id<MTLBuffer> mtl_buf;
            
            mtl_buf = [self updateBuffer: index_buffer];
            
            switch(draw->draw_style)
            {
                case MTPrimitveDrawIndex:
                    [_currentRenderEncoder drawIndexedPrimitives:(MTLPrimitiveType)STATE(prim_type)
                                                      indexCount:draw->count
                                                       indexType:(MTLIndexType)draw->index_type
                                                     indexBuffer:mtl_buf
                                               indexBufferOffset:draw->offset];
                    break;
                    
                case MTPrimitveDrawIndexInstance:
                case MTPrimitveDrawIndexInstanceBase:
                case MTPrimitveDrawIndexOffsetInstanceBase:
                    [_currentRenderEncoder drawIndexedPrimitives:(MTLPrimitiveType)STATE(prim_type)
                                                      indexCount:draw->count
                                                       indexType:(MTLIndexType)draw->index_type
                                                     indexBuffer:mtl_buf
                                               indexBufferOffset:draw->offset
                                                   instanceCount:draw->instance_count
                                                      baseVertex:draw->base_vertex
                                                    baseInstance:draw->base_instance];
                    break;
                    
                default:
                    assert(0);
            }
        }
    }
}

void mtlDrawArray(MTRenderContextRec *mt_ctx, MTDrawArrayPrimitive *draw)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlDrawArray:draw];
}

#pragma mark cpyMTLTexDescToMTTexDesc
-(void)copyMTLTexDescToMTTexDesc:(MTTextureDesc *)dst src:(MTLTextureDescriptor *)src
{
    dst->texture_type = (MTTextureType)src.textureType;
    dst->format = (MTPixelFormat)src.pixelFormat;
    dst->width = (MTuint)src.width;
    dst->height = (MTuint)src.height;
    dst->depth = (MTuint)src.depth;
    dst->mipmap_level_count = (MTuint)src.mipmapLevelCount;
    dst->sample_count = (MTuint)src.sampleCount;
    dst->array_length = (MTuint)src.arrayLength;
    dst->resource_options = (MTResourceOptions)src.resourceOptions;
    dst->cpu_cache_mode = (MTCPUCacheMode)src.cpuCacheMode;
    dst->storage_mode = (MTStorageMode)src.storageMode;
    dst->hazard_tracking_mode = (MTHazardTrackingMode)src.hazardTrackingMode;
    dst->usage = (MTTextureUsage)src.usage;
    dst->allow_gpu_optimized_contents = src.allowGPUOptimizedContents;
    dst->compression_type = (MTTextureCompressionType)src.compressionType;
    dst->swizzle.red = (MTTextureSwizzle)src.swizzle.red;
    dst->swizzle.green = (MTTextureSwizzle)src.swizzle.green;
    dst->swizzle.blue = (MTTextureSwizzle)src.swizzle.blue;
    dst->swizzle.alpha = (MTTextureSwizzle)src.swizzle.alpha;
    dst->placement_sparse_page_size = (MTSparsePageSize)src.placementSparsePageSize;
}

#pragma mark mtlTextureDescWithPixelFormat
-(void)mtlTextureDescWithPixelFormat:(MTTextureDesc *)desc error:(MTuint *)error
{
    MTLTextureDescriptor *mtl_desc;
    
    mtl_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)desc->format width:desc->width height:desc->width  mipmapped:desc->mipmapped];

    if (mtl_desc)
    {
        [self copyMTLTexDescToMTTexDesc:desc src:mtl_desc];
        
        if (error)
        {
            error = 0;
        }
    }
    else if (error)
    {
        *error = 1;
    }
    else
    {
        zeroPtr(desc, MTTextureDesc);
    }
}

void mtlTextureDescWithPixelFormat(MTRenderContextRec *mt_ctx, MTTextureDesc *desc, MTuint *error)
{
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlTextureDescWithPixelFormat:desc error:error];
}

#pragma mark mtlTextureCubeDescWithPixelFormat
-(void)mtlTextureCubeDescWithPixelFormat:(MTTextureDesc *)desc error:(MTuint *)error
{
    MTLTextureDescriptor *mtl_desc;
    
    mtl_desc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:(MTLPixelFormat)desc->format size:desc->width mipmapped:desc->mipmapped];

    if (mtl_desc)
    {
        [self copyMTLTexDescToMTTexDesc:desc src:mtl_desc];
        
        if (error)
        {
            error = 0;
        }
    }
    else if (error)
    {
        *error = 1;
    }
    else
    {
        zeroPtr(desc, MTTextureDesc);
    }
}

void mtlTextureCubeDescWithPixelFormat(MTRenderContextRec *mt_ctx, MTTextureDesc *desc, MTuint *error)
{
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlTextureCubeDescWithPixelFormat:desc error:error];
}

#pragma mark mtlTextureBufferDescWithPixelFormat
-(void)mtlTextureBufferDescWithPixelFormat:(MTTextureDesc *)desc error:(MTuint *)error
{
    MTLTextureDescriptor *mtl_desc;
    
    mtl_desc = [MTLTextureDescriptor textureBufferDescriptorWithPixelFormat:(MTLPixelFormat)desc->format width:desc->width resourceOptions:(MTLResourceOptions)desc->resource_options usage:(MTLTextureUsage)desc->usage];

    if (mtl_desc)
    {
        [self copyMTLTexDescToMTTexDesc:desc src:mtl_desc];
        
        if (error)
        {
            error = 0;
        }
    }
    else if (error)
    {
        *error = 1;
    }
    else
    {
        zeroPtr(desc, MTTextureDesc);
    }
}

void mtlTextureBufferDescWithPixelFormat(MTRenderContextRec *mt_ctx, MTTextureDesc *desc, MTuint *error)
{
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlTextureBufferDescWithPixelFormat:desc error:error];
}


#pragma mark mtlCreateTexture
- (void)mtlCreateTexture:(MTTexture *)tex srcPitch:(MTsizei)src_pitch data:(void *)data
{
    MTLTextureDescriptor *tex_desc;
    
    switch(tex->desc.texture_type)
    {
        case MTTextureType1D:
        case MTTextureType2D:
        case MTTextureType3D:
            tex_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)tex->desc.format width:tex->desc.width height:tex->desc.height mipmapped:tex->desc.mipmapped];
            tex_desc.textureType = (MTLTextureType)tex->desc.texture_type;
            break;
            
        case MTLTextureType1DArray:
        case MTLTextureType2DArray:
            tex_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)tex->desc.format width:tex->desc.width height:tex->desc.height mipmapped:tex->desc.mipmapped];
            tex_desc.textureType = (MTLTextureType)tex->desc.texture_type;
            tex_desc.arrayLength = tex->desc.array_length;
            break;
            
        case MTLTextureType2DMultisample:
        case MTLTextureType2DMultisampleArray:
            tex_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)tex->desc.format width:tex->desc.width height:tex->desc.height mipmapped:tex->desc.mipmapped];
            tex_desc.textureType = (MTLTextureType)tex->desc.texture_type;
            tex_desc.arrayLength = tex->desc.array_length;
            tex_desc.sampleCount = tex->desc.sample_count;
            break;
            
        case MTTextureTypeCube:
            tex_desc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:(MTLPixelFormat)tex->desc.format size:tex->desc.width mipmapped:tex->desc.mipmapped];
            break;
            
        case MTLTextureTypeCubeArray:
            tex_desc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:(MTLPixelFormat)tex->desc.format size:tex->desc.width mipmapped:tex->desc.mipmapped];
            tex_desc.textureType = (MTLTextureType)tex->desc.texture_type;
            tex_desc.arrayLength = tex->desc.array_length;
            break;
            
        case MTTextureTypeTextureBuffer:
            tex_desc = [MTLTextureDescriptor textureBufferDescriptorWithPixelFormat:(MTLPixelFormat)tex->desc.format width:tex->desc.width resourceOptions:(MTLResourceOptions)tex->desc.resource_options usage:(MTLTextureUsage)tex->desc.usage];
            break;
            
        default:
            assert(0);
            return;
    }
    
    assert(tex_desc);

    id<MTLTexture> mtl_tex;
    mtl_tex = [_device newTextureWithDescriptor: tex_desc];
    assert(mtl_tex);
    
    if (data)
    {
        MTLRegion region = {
            { 0, 0, 0 },                    // MTLOrigin
            {tex->desc.width, tex->desc.height, 1}    // MTLSize
        };
        
        // load texture data
        [mtl_tex replaceRegion:region
                   mipmapLevel:0
                     withBytes:data
                   bytesPerRow:src_pitch];

        if (tex_desc.mipmapLevelCount > 1)
        {
            id<MTLCommandBuffer> tempCommandBuffer;

            tempCommandBuffer = [_commandQueue commandBuffer];
            assert(tempCommandBuffer);
            
            id<MTLBlitCommandEncoder> blit_command_encoder;
            
            blit_command_encoder = [tempCommandBuffer blitCommandEncoder];
            assert(blit_command_encoder);

            [blit_command_encoder generateMipmapsForTexture:mtl_tex];
            [blit_command_encoder endEncoding];
            
            [tempCommandBuffer commit];
            [tempCommandBuffer waitUntilCompleted];
        }
    }
    
    // retain to keep ownership to this texture
    tex->mtl_tex    = (void *)CFBridgingRetain(mtl_tex);
}

void mtlCreateTexture(MTRenderContextRec *mt_ctx, MTTexture *tex, MTsizei src_pitch, void *data)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlCreateTexture:tex srcPitch:src_pitch data:data];
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
    
    err = NULL;
    
    mtl_tex = [_textureLoader newTextureWithContentsOfURL:url
                                                  options:NULL
                                                    error:&err];

    if (err)
    {
        NSLog(@"Error: %@, will try to load from main bundle", [err localizedDescription]);
        
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
    }
    
    if (mtl_tex == NULL)
    {
        return;
    }
    
    tex->desc.width  = (MTuint)[mtl_tex width];
    tex->desc.height = (MTuint)[mtl_tex height];
    tex->desc.format = (MTuint)[mtl_tex pixelFormat];

    tex->mtl_tex    = (void *)CFBridgingRetain(mtl_tex);
}

void mtlCreateTextureFromPath(MTRenderContextRec *mt_ctx, MTTexture *tex, const char *path)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlCreateTextureFromPath:tex path:path];
}

#pragma mark mtlCreateTextureFromDesc
- (void)mtlCreateTexture:(MTTexture *)tex fromDesc:(MTTextureDesc *)desc src_pitch:(MTsizei) src_pitch data:(void *)data
{
    MTLTextureDescriptor *tex_desc;
    tex_desc = [[MTLTextureDescriptor alloc] init];
    assert(tex_desc);
    
    tex_desc.textureType                = (MTLTextureType)desc->texture_type;
    tex_desc.width                      = (NSUInteger)desc->width;
    tex_desc.height                     = (NSUInteger)desc->height;
    tex_desc.depth                      = (NSUInteger)desc->depth;
    tex_desc.mipmapLevelCount           = (NSUInteger)desc->mipmap_level_count;
    tex_desc.sampleCount                = (NSUInteger)desc->sample_count;
    tex_desc.arrayLength                = (NSUInteger)desc->array_length;
    tex_desc.resourceOptions            = (NSUInteger)desc->resource_options;
    tex_desc.cpuCacheMode               = (NSUInteger)desc->cpu_cache_mode;
    tex_desc.storageMode                = (NSUInteger)desc->storage_mode;
    tex_desc.hazardTrackingMode         = (MTLHazardTrackingMode)desc->hazard_tracking_mode;
    tex_desc.usage                      = (MTLTextureUsage)desc->usage;
    tex_desc.allowGPUOptimizedContents  = (bool)desc->allow_gpu_optimized_contents;
    tex_desc.compressionType            = (MTLTextureCompressionType)desc->compression_type;

    tex_desc.swizzle = MTLTextureSwizzleChannelsMake((MTLTextureSwizzle)desc->swizzle.red, (MTLTextureSwizzle)desc->swizzle.green, (MTLTextureSwizzle)desc->swizzle.blue, (MTLTextureSwizzle)desc->swizzle.alpha);
    tex_desc.placementSparsePageSize    = (MTLSparsePageSize)desc->placement_sparse_page_size;

    id<MTLTexture> mtl_tex;
    mtl_tex = [_device newTextureWithDescriptor: tex_desc];

    if (mtl_tex == NULL)
    {
        tex->mtl_tex = NULL;
        
        return;
    }
    
    if (data)
    {
        // load texture data
        if (src_pitch)
        {
            MTLRegion region = {
                { 0, 0, 0 },                                // MTLOrigin
                {desc->width, desc->height, desc->depth}    // MTLSize
            };
            
            [mtl_tex replaceRegion:region
                       mipmapLevel:0
                         withBytes:data
                       bytesPerRow:src_pitch];
        }
    }
    
    // retain to keep ownership to this texture
    tex->mtl_tex    = (void *)CFBridgingRetain(mtl_tex);
}

void mtlCreateTextureFromDesc(MTRenderContextRec *mt_ctx, MTTexture *tex, MTTextureDesc *desc, MTsizei src_pitch, void *data)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlCreateTexture:tex fromDesc:desc src_pitch: src_pitch data:data];
}


#pragma mark mtlCreateShaderLibrary
- (void)mtlCreateShaderLibrary:(MTShaderLibrary*)lib
{
    id<MTLLibrary> mtl_lib;

    NSString *src;
    
    src = [NSString stringWithUTF8String: lib->src];
    
    if (_device == NULL)
    {
        _device = MTLCreateSystemDefaultDevice();
    }
    
    NSError *err;
    
    err = NULL;
    
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
        
        // generate more errors
        [_device newLibraryWithSource:src options: NULL error:&err];
        
        return;
    }
    
    NSArray *function_names;
    function_names = [mtl_lib functionNames];

    lib->function_count = (MTuint)[function_names count];
    lib->function_names = newArray(const char *, lib->function_count);
    
    NSMutableArray *lib_functions;
    lib_functions = [NSMutableArray arrayWithCapacity: lib->function_count];
    
    NSLog(@"Compiled %d functions for library\n", lib->function_count);
    
    int i = 0;
    for (NSString *string in function_names)
    {
        id<MTLFunction> mtl_function;
        
        NSLog(@"%@", string);
        
        mtl_function = [mtl_lib newFunctionWithName:string];
        assert(mtl_function);
        
        [lib_functions insertObject: mtl_function atIndex:i];
        
        lib->function_names[i++] = strdup([string cStringUsingEncoding: NSUTF8StringEncoding]);
    }

    lib->mtl_lib = (void *)CFBridgingRetain(mtl_lib);
    lib->mtl_lib_functions = (void *)CFBridgingRetain(lib_functions);
}

void mtlCreateShaderLibrary(MTRenderContextRec *mt_ctx, MTShaderLibrary *lib)
{
    // Call the Objective-C method using Objective-C syntax
    [(__bridge id) mt_ctx->mt_render_funcs.mtlObj mtlCreateShaderLibrary:lib];
}

void mtlCFBridgingRelease(void *ptr)
{
    CFBridgingRelease(ptr);
}

#pragma mark C interface to context functions
- (void)bindObjFuncsMTRenderContext
{
    _ctx->mt_render_funcs.mtlObj = (__bridge void *)(self);
    
    // ObjC functions
    _ctx->mt_render_funcs.mtlFlushVertexEng = mtlFlushVertexEng;
    _ctx->mt_render_funcs.mtlBegin = mtlBegin;
    _ctx->mt_render_funcs.mtlEnd = mtlEnd;
    _ctx->mt_render_funcs.mtlCFBridgingRelease =  mtlCFBridgingRelease;
    
    _ctx->mt_render_funcs.mtlTextureDescWithPixelFormat =  mtlTextureDescWithPixelFormat;
    _ctx->mt_render_funcs.mtlTextureCubeDescWithPixelFormat =  mtlTextureCubeDescWithPixelFormat;
    _ctx->mt_render_funcs.mtlTextureBufferDescWithPixelFormat =  mtlTextureBufferDescWithPixelFormat;
    
    _ctx->mt_render_funcs.mtlCreateTextureFromPath = mtlCreateTextureFromPath;
    _ctx->mt_render_funcs.mtlCreateTextureFromDesc = mtlCreateTextureFromDesc;
    _ctx->mt_render_funcs.mtlCreateTexture = mtlCreateTexture;
    _ctx->mt_render_funcs.mtlCreateShaderLibrary = mtlCreateShaderLibrary;
    _ctx->mt_render_funcs.mtlDrawArray = mtlDrawArray;
}

- (void)scaleViewPortSize:(MTKView *)view
{
    NSRect frame;
    frame = [view frame];
    
    NSScreen *screen;
    screen = [NSScreen mainScreen];
    
    float scale;
    scale = [screen backingScaleFactor];
    
    _viewportSize.x = frame.size.width * scale;
    _viewportSize.y = frame.size.height * scale;
}

- (void)setDefaultShaders
{
    NSError *err;
    
    err = nil;

    NSBundle *frameworkBundle;
    
    frameworkBundle = [NSBundle bundleForClass:[Renderer class]];

    assert(frameworkBundle);
    
    _defaultShaderLibrary = [_device newDefaultLibraryWithBundle:frameworkBundle error:&err];
    
    assert(_defaultShaderLibrary);
    
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColor].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShader"];
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColor].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColor"];

    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShader"];
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderNormal"];

    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColorNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShader"];
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColorNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorNormal"];

    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShader"];
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderTexture"];

    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColorTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShader"];
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColorTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorTexture"];

    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeNormalTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShader"];
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeNormalTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderNormalTexture"];

    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColorNormalTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShader"];
    _defaultShaderPairs[MTVertexShaderModeNonInstanced][MTFragmentShaderModeColorNormalTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorNormalTexture"];

    // instancing
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColor].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderInstanced"];
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColor].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColor"];

    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderInstanced"];
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderNormal"];

    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColorNormal].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderInstanced"];
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColorNormal].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorNormal"];

    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderInstanced"];
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderTexture"];

    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColorTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderInstanced"];
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColorTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorTexture"];

    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeNormalTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderInstanced"];
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeNormalTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderNormalTexture"];

    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColorNormalTexture].vertexFunction = [_defaultShaderLibrary newFunctionWithName:@"vertexShaderInstanced"];
    _defaultShaderPairs[MTVertexShaderModeInstanced][MTFragmentShaderModeColorNormalTexture].fragmentFunction = [_defaultShaderLibrary newFunctionWithName:@"fragmentShaderColorNormalTexture"];

    for(int i=0; i<MTVertexShaderModeMax; i++)
    {
        for(int j=0; j<MTFragmentShaderModeMax; j++)
        {
            assert(_defaultShaderPairs[i][j].vertexFunction);
            assert(_defaultShaderPairs[i][j].fragmentFunction);
        }
    }
}

- (void) initDevCaps
{
    DEVCAP(supported_sample_counts_bitfield) = 0;
    DEVCAP(supported_vertex_amplifaction_count) = 0;
    for(int i=0; i<16; i++)
    {
        if([_device supportsTextureSampleCount: (0x1 << i)])
        {
            DEVCAP(supported_sample_counts_bitfield) |= (0x1 << i);
        }
        
        if([_device supportsVertexAmplificationCount: (0x1 << i)])
        {
            DEVCAP(supported_vertex_amplifaction_count) |= (0x1 << i);
        }
    }
    
    // this will fail if metal validation is turned on...
#if __RELEASE__
    {
        MTLTextureDescriptor *tex_desc = [[MTLTextureDescriptor alloc] init];
        tex_desc.width = 4;
        tex_desc.height = 4;
        tex_desc.usage = MTLTextureUsageShaderRead;
        
        for(int i=MTPixelFormatA8Unorm; i<MTPixelFormatMax; i++)
        {
            tex_desc.pixelFormat = (MTLPixelFormat)i;
            
            id<MTLTexture> tex = [_device newTextureWithDescriptor:tex_desc];
            
            if (tex)
            {
                DEVFEATURE(texture_format[i]) = true;
                DEVCAP(minimum_texture_alignment[i]) = (MTuint)[_device minimumLinearTextureAlignmentForPixelFormat:(MTLPixelFormat) i];
                DEVCAP(minimum_texture_buffer_alignment[i]) = (MTuint)[_device minimumTextureBufferAlignmentForPixelFormat:(MTLPixelFormat) i];
            }
            else
            {
                DEVFEATURE(texture_format[i]) = false;
            }
        }
    }
#endif  // __RELEASE__
    
    DEVCAP(max_buffer_length) = (MTsizei)[_device maxBufferLength];
    
    MTLSize max_threadgroup_size;
    
    max_threadgroup_size = [_device maxThreadsPerThreadgroup];
    
    DEVCAP(max_threads_per_threadgroup.width) = (MTuint)max_threadgroup_size.width;
    DEVCAP(max_threads_per_threadgroup.height) = (MTuint)max_threadgroup_size.height;
    DEVCAP(max_threads_per_threadgroup.depth) = (MTuint)max_threadgroup_size.depth;

    DEVCAP(max_threadgroup_memory_length) = (MTuint)[_device maxThreadgroupMemoryLength];
    
    DEVFEATURE(ray_tracing) = [_device supportsRaytracing];
    DEVFEATURE(primitive_motion_blur) = [_device supportsRaytracing];
    DEVFEATURE(raytracing_from_renderer) = [_device supportsRaytracingFromRender];
    DEVFEATURE(_32bitMSAA) = [_device supports32BitMSAA];
    DEVFEATURE(pull_model_interpolation) = [_device supportsPullModelInterpolation];
    DEVFEATURE(shader_barycentric_coordinates) = [_device supportsShaderBarycentricCoordinates];
    DEVFEATURE(programmable_sample_positions) = [_device areProgrammableSamplePositionsSupported];
    DEVFEATURE(raster_order_groups) = [_device areRasterOrderGroupsSupported];
    DEVFEATURE(_32bit_float_filtering) = [_device supports32BitFloatFiltering];
    DEVFEATURE(BC_texture_compression) = [_device supportsBCTextureCompression];
    DEVFEATURE(depth24_stencil8_pixel_format) = [_device isDepth24Stencil8PixelFormatSupported];
    DEVFEATURE(query_texture_LOD) = [_device supportsQueryTextureLOD];
    DEVFEATURE(read_write_texture_support) = [_device readWriteTextureSupport];

}

- (void) initFragmentEngine
{
    _currentVertexBuffer = 0;
    _vertexBufferOffset = 0;
    _vertexBufferSize = sizeof(Vertex4ColorNormalTex) * VENG(num_vertices) * 32;
    
    for(int j=0; j<NUM_INFLIGHT_BUFFERS; j++)
    {
        for(int i=0; i<NUM_VERTEX_BUFFERS; i++)
        {
            _vertexBuffers[j][i] = [_device newBufferWithLength:_vertexBufferSize  options:MTLResourceCPUCacheModeWriteCombined | MTLResourceStorageModeManaged];
            _vertexBuffers[j][i].label = @"VertexBuffer";
        }
    }
}

#pragma mark initWithMTKView
- (Renderer *)initWithMTKView:(MTKView *)view context:(MTRenderContext)ctx
{
    _ctx = mtGetContextPtr(ctx);

    if (_ctx == NULL)
    {
        return NULL;
    }

    self = [super init];

    _device = MTLCreateSystemDefaultDevice();
    assert(_device);

    view.device = _device;

    _view = view;

    if (_view.depthStencilPixelFormat == MTLPixelFormatInvalid)
    {
        _view.depthStencilPixelFormat = (MTLPixelFormat)STATE(depth_stencil_format);
    }
    else if (_view.depthStencilPixelFormat != (MTLPixelFormat)STATE(depth_stencil_format))
    {
        _view.depthStencilPixelFormat = (MTLPixelFormat)STATE(depth_stencil_format);
    }

    _currentDrawable = _view.currentDrawable;
    
    _textureLoader = [[MTKTextureLoader alloc] initWithDevice: view.device];
    assert(_textureLoader);
    
    [self scaleViewPortSize:view];
    [self setDefaultShaders];
    [self initDevCaps];
    [self initFragmentEngine];
    [self bindObjFuncsMTRenderContext];
    
    _commandQueue = [_device newCommandQueue];
        
    // set this here until we get a getviewport size
    _ctx->state.viewport.width  = _viewportSize.x;
    _ctx->state.viewport.height = _viewportSize.y;

    _num_command_buffers_per_swap = 0;
    _num_pipeline_state_per_swap = 0;
    _num_render_encoders_per_swap = 0;
    
    return self;
}

- (void) flushToScreen
{
    if (_currentRenderEncoder)
    {
        [_currentRenderEncoder endEncoding];
        _currentRenderEncoder = NULL;
    }
    else if (STATE(clear_mask))
    {
        // we have an empty clear only flush
        [self updateRenderer];

        [_currentRenderEncoder endEncoding];
        _currentRenderEncoder = NULL;
    }
    
    // Schedule a present once the framebuffer is complete using the current drawable
    [_currentCommandBuffer presentDrawable: _currentDrawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [_currentCommandBuffer commit];
    
    // only used for immediate mode, probably doesn't hurt to cycle through these
    _currentBufferSetInFlight++;
    
    if (_currentBufferSetInFlight >= NUM_INFLIGHT_BUFFERS)
    {
        // probably should use a semaphore here..
        _currentBufferSetInFlight = 0;
    }
    
    _currentCommandBuffer = NULL;
    _currentDrawable = NULL;

    _currentVertexBuffer = 0;
    _vertexBufferOffset = 0;
    
    assert(_view.depthStencilPixelFormat == (MTLPixelFormat)STATE(depth_stencil_format));

    if ((_num_command_buffers_per_swap != 1) ||
        (_num_pipeline_state_per_swap != 1) ||
        (_num_render_encoders_per_swap != 1))
    {
        printf("Not a warning.. but these are one most of the time\n");
        printf("_num_command_buffers_per_swap: %d\n", _num_command_buffers_per_swap);
        printf("_num_pipeline_state_per_swap: %d\n", _num_pipeline_state_per_swap);
        printf("_num_render_encoders_per_swap: %d\n\n", _num_render_encoders_per_swap);
    }
    
    _num_command_buffers_per_swap = 0;
    _num_pipeline_state_per_swap = 0;
    _num_render_encoders_per_swap = 0;
}

@end


MTbool mtBindMTKView(void *mtk_view)
{
    MTRenderContextRec *ctx;
    
    ctx = mtGetContextPtr(mtGetCurrentContext());
    
    if (ctx == NULL)
    {
        return false;
    }
    
    Renderer *renderer;
    
    renderer = [[Renderer alloc] initWithMTKView:(__bridge MTKView *)(mtk_view) context:mtGetCurrentContext()];
    
    ctx->mt_render_funcs.mtlObj = (void *)CFBridgingRetain(renderer);
    
    return true;
}

void mtFlushToScreen(void)
{
    MTRenderContextRec *ctx;
    
    ctx = mtGetContextPtr(mtGetCurrentContext());
    
    if (ctx == NULL)
    {
        return;
    }
    
    Renderer *renderer;

    renderer = (__bridge Renderer *)(ctx->mt_render_funcs.mtlObj);
    
    [renderer flushToScreen];
}
