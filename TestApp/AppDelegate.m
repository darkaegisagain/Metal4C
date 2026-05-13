//
//  AppDelegate.m
//  Metal4C
//
//  Created by Michael Larson on 2/10/26.
//

#import "AppDelegate.h"

#import "metal4c_x11_colors.h"
#import "metal4c.h"
#import "metal_math_utils.h"

#import "LocalShaderTypes.h"

#define newPtr(_type_)                  (_type_ *)malloc(sizeof(_type_))
#define newArray(_type_, _count_)       (_type_ *)malloc(sizeof(_type_) * _count_)

enum {
    kRenderColorShift = 0,
    kRenderTextureShift,
    kRenderNormalShift
};

#define RENDER_MODE_BIT(_bit_)  (0x1 << _bit_)
#define RENDER_COLOR_BIT        RENDER_MODE_BIT(kRenderColorShift)
#define RENDER_TEXTURE_BIT      RENDER_MODE_BIT(kRenderTextureShift)
#define RENDER_NORMAL_BIT       RENDER_MODE_BIT(kRenderNormalShift)

#define RENDER_MODE_COLOR               RENDER_COLOR_BIT
#define RENDER_MODE_TEX                 RENDER_TEXTURE_BIT
#define RENDER_MODE_NORMAL              RENDER_NORMAL_BIT

#define RENDER_MODE_COLOR_TEX           (RENDER_COLOR_BIT | RENDER_TEXTURE_BIT)
#define RENDER_MODE_COLOR_NORMAL        (RENDER_COLOR_BIT | RENDER_NORMAL_BIT)
#define RENDER_MODE_TEX_NORMAL          (RENDER_TEXTURE_BIT | RENDER_NORMAL_BIT)

#define RENDER_MODE_COLOR_TEX_NORMAL    (RENDER_COLOR_BIT | RENDER_TEXTURE_BIT | RENDER_NORMAL_BIT)

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
{
    IBOutlet MTKView            *_view;
    IBOutlet NSPopUpButton      *_draw_type_popup_button;
    IBOutlet NSButton           *_enable_color;
    IBOutlet NSButton           *_enable_texture;
    IBOutlet NSButton           *_enable_normals;
    IBOutlet NSButton           *_enable_3D_view;
    IBOutlet NSButton           *_enable_vertex_arrays;
    IBOutlet NSButton           *_enable_depth_testing;
    IBOutlet NSButton           *_enable_stencil_testing;
    IBOutlet NSButton           *_enable_indexed_primitives;
    IBOutlet NSButton           *_enable_instancing;

    MTRenderContext             _ctx;
    
    vector_uint2                _viewportSize;
    
    MTuint                      _textures[8];
    MTuint                      _samplers[8];

    MTuint                      _render_primitive;
    MTuint                      _render_mode_bitmask;
    
    MTuint                      _shader_lib;
    
    MTbool                      _use_3d_rot;
    MTfloat                     _rot_angle;
    
    MTbool                      _use_vertex_arrays;
    MTbool                      _vertex_array_setup_required;
    MTuint                      _vao;
    MTuint                      _vertex_buffer;
    MTuint                      _index_buffer;

    MTbool                      _use_depth_testing;
    MTbool                      _use_stencil_testing;
    MTbool                      _use_index_primitives;
    MTbool                      _use_instancing;

    MTuint                      _instance_buffer_for_points;
    LocalInstanceState          *_instance_state_for_points;
    MTuint                      _sim_frame_count_for_points;
    MTbool                      _sim_direction_for_points;
}

- (void)initM4CView
{
    _ctx = mtCreateContext();
    assert(_ctx);
    
    mtSetCurrentContext(_ctx);
    
    MTbool res;
    
    res = mtBindMTKView((__bridge void *)(_view));
    
    assert(res);
}

- (void)initButton:(NSButton *)button name:(NSString *)name state:(unsigned)state
{
    [button setTitle:name];
    [button setAutoresizingMask: NSViewWidthSizable];
    [button sizeToFit];
    [button setState: state];
    [button setAction: @selector(buttonClick:)];
}

- (void)initUI
{
    struct {
        NSString *name;
        unsigned tag;
    } button_items[] = {
        {@"point", MTPrimitiveTypePoint},
        {@"line", MTPrimitiveTypeLine},
        {@"linestrip", MTPrimitiveTypeLineStrip},
        {@"triangle", MTPrimitiveTypeTriangle},
        {@"trianglestrip", MTPrimitiveTypeTriangleStrip},
        {NULL, -1}
    };
    
    [_draw_type_popup_button removeAllItems];
    for(int i=0; button_items[i].name; i++)
    {
        [_draw_type_popup_button addItemWithTitle:button_items[i].name];
        [[_draw_type_popup_button itemAtIndex: i] setTag: button_items[i].tag];
    }

    [_draw_type_popup_button setAutoresizingMask: NSViewWidthSizable];
    [_draw_type_popup_button sizeToFit];
    [_draw_type_popup_button setAction:@selector(buttonClick:)];

    [self initButton:_enable_color name:@"Color" state:1];
    [self initButton:_enable_texture name:@"Texture" state:0];
    [self initButton:_enable_normals name:@"Normal" state:0];
    [self initButton:_enable_3D_view name:@"Enable 3D" state:0];
    [self initButton:_enable_vertex_arrays name:@"Enable Vertex Arrays" state:0];
    [self initButton:_enable_depth_testing name:@"Enable Depth Testing" state:0];
    [self initButton:_enable_stencil_testing name:@"Enable Stencil Testing" state:0];
    [self initButton:_enable_indexed_primitives name:@"Enable Index Primitives" state:0];
    [self initButton:_enable_instancing name:@"Enable Instancing" state:0];

    _render_primitive = (MTuint)[_draw_type_popup_button tag];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    assert(_view);
    assert(_draw_type_popup_button);
    assert(_enable_color);
    assert(_enable_texture);
    assert(_enable_normals);
    assert(_enable_3D_view);
    assert(_enable_vertex_arrays);
    assert(_enable_depth_testing);
    assert(_enable_stencil_testing);
    assert(_enable_indexed_primitives);
    assert(_enable_instancing);

    [_view setDelegate: self];
    
    [self initM4CView];
    [self initUI];

    //_textures[0] = mtCreateTextureFromFile("/tmp/Lenna_test_image.png");
    //_textures[0] = mtCreateTextureFromFile("/Users/milarson/Projects/Metal4C/Metal4C/Lenna_test_image.png");
    _textures[0] = mtCreateTextureFromFile("Lenna_test_image.png");
        

    void *data;
    data = newArray(MTuint, 1024*1024);
    
    _textures[1] = mtCreateTexture2D(MTPixelFormatRGBA8Unorm, 1024, 1024, false, 0, NULL);
    assert(_textures[1]);
    
    // no texture created without src pitch
    _textures[2] = mtCreateTexture2D(MTPixelFormatRGBA8Unorm, 1024, 1024, false, 0, data);
    assert(_textures[2] == 0);
    
    _textures[3] = mtCreateTexture2D(MTPixelFormatRGBA8Unorm, 1024, 1024, false, 1024*sizeof(MTuint), data);
    assert(_textures[3]);
    
    _textures[4] = mtCreateTexture2D(MTPixelFormatRGBA8Unorm, 1024, 1024, true, 0, NULL);
    assert(_textures[4]);
    
    // data is ignored but texture created
    _textures[5] = mtCreateTexture2D(MTPixelFormatRGBA8Unorm, 1024, 1024, true, 1024*sizeof(MTuint), NULL);
    assert(_textures[5]);
    
    _textures[6] = mtCreateTexture2D(MTPixelFormatRGBA8Unorm, 1024, 1024, true, 1024*sizeof(MTuint), data);
    assert(_textures[6]);

    _textures[7] = mtCreateTexture3D(MTPixelFormatRGBA8Unorm, 1024, 1024, 1024, true, 1024*sizeof(MTuint), data);
    assert(_textures[7]);

    mtDeleteTexture(_textures[1]);
    mtDeleteTexture(_textures[2]);
    mtDeleteTexture(_textures[3]);
    mtDeleteTexture(_textures[4]);
    mtDeleteTexture(_textures[5]);
    mtDeleteTexture(_textures[6]);
    mtDeleteTexture(_textures[7]);

    MTuint tex_name;
    
    tex_name = mtCreateTexture1D(MTPixelFormatRGBA8Unorm, 1024, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);

    tex_name = mtCreateTexture1DArray(MTPixelFormatRGBA8Unorm, 1024, 8, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);

    tex_name = mtCreateTexture2DArray(MTPixelFormatRGBA8Unorm, 1024, 1024, true, 8, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);

    tex_name = mtCreateTexture2DMultiSampled(MTPixelFormatRGBA8Unorm, 1024, 1024, 2, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);

    tex_name = mtCreateTexture2DMultiSampledArray(MTPixelFormatRGBA8Unorm, 1024, 1024, 4, 8, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);

    tex_name = mtCreateTextureCube(MTPixelFormatRGBA8Unorm, 1024, true, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);

    tex_name = mtCreateTextureCubeArray(MTPixelFormatRGBA8Unorm, 1024, true, 8, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);

    tex_name = mtCreateTextureBuffer(MTPixelFormatRGBA8Unorm, 1024, MTResourceStorageModeManaged, MTTextureUsageShaderRead, 0, NULL);
    assert(tex_name);
    mtDeleteTexture(tex_name);


    MTuint desc[8];
    
    desc[0] = mtCreateTextureDesc();

    desc[1] = mtCreateTextureDescWithPixelFormat(MTPixelFormatRGBA8Unorm, 1024, 1024, false);
    desc[2] = mtCreateTextureDescWithPixelFormat(MTPixelFormatRGBA8Unorm, 1024, 1024, true);

    desc[3] = mtCreateTextureCubeDescWithPixelFormat(MTPixelFormatRGBA8Unorm, 1024, false);
    desc[4] = mtCreateTextureCubeDescWithPixelFormat(MTPixelFormatRGBA8Unorm, 1024, true);

    desc[5] = mtCreateTextureBufferDescWithPixelFormat(MTPixelFormatRGBA8Unorm, 1024, MTResourceCPUCacheModeDefaultCache, MTTextureUsageShaderRead);
    
    // create a depth texture
    desc[6] = mtCreateTextureBufferDescWithPixelFormat(MTPixelFormatDepth32Float, 1024, 0, MTTextureUsageShaderRead);

    _textures[1] = mtCreateTextureFromDesc(desc[1], 0, NULL);
    assert(_textures[1]);
    
    _textures[2] = mtCreateTextureFromDesc(desc[2], 0, data);
    assert(_textures[2] == 0);

    _textures[3] = mtCreateTextureFromDesc(desc[3], 1024*sizeof(MTuint), NULL);
    assert(_textures[3]);

    _textures[4] = mtCreateTextureFromDesc(desc[4], 1024*sizeof(MTuint), data);
    assert(_textures[4]);
    
    _textures[5] = mtCreateTextureFromDesc(desc[5], 0, NULL);
    assert(_textures[5]);

    _textures[6] = mtCreateTextureFromDesc(desc[6], 0, NULL);
    assert(_textures[6]);

    MTuint sampler_desc_name;
    
    sampler_desc_name = mtCreateSamplerDesc();
    
    mtSetSamplerDescParam(sampler_desc_name, MTSamplerParamMinFilter, MTSamplerMinMagFilterNearest);
    mtSetSamplerDescParam(sampler_desc_name, MTSamplerParamAddressMode_S, MTSamplerAddressModeClampToEdge);
    mtSetSamplerDescParam(sampler_desc_name, MTSamplerParamAddressMode_T, MTSamplerAddressModeClampToEdge);
    mtSetSamplerDescParam(sampler_desc_name, MTSamplerParamAddressMode_R, MTSamplerAddressModeClampToEdge);
    mtSetSamplerDescParam(sampler_desc_name, MTSamplerParamBoarderColor, MTSamplerBorderColorOpaqueBlack);

    _samplers[0] = mtCreateSampler(sampler_desc_name);
        
    NSRect frame;
    frame = [_view frame];
    
    NSSize size;
    size = frame.size;
    
    NSScreen *screen;
    screen = [NSScreen mainScreen];
    
    float scale;
    scale = [screen backingScaleFactor];
    
    mtSetRendermode(MTVertexShaderModeNonInstanced, MTFragmentShaderModeColor);
    
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width * scale;
    _viewportSize.y = size.height * scale;
    
    mtSetViewport(0, 0, _viewportSize.x, _viewportSize.y);
    
    // set clear to gray
    MTfloat color[4];
    mtGetX11ColorByName("grey", color);
    mtClearColor(color[0], color[1], color[2], color[3]);
    
    _render_mode_bitmask = RENDER_COLOR_BIT;
    
    _use_3d_rot = 0;
    _rot_angle = 0.0;
    
    _use_vertex_arrays = 0;
    _vertex_array_setup_required = 0;
    
    NSURL *shader_url;
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    shader_url = [mainBundle URLForResource:@"LocalShaders" withExtension:@"mtl"];
    
    if (shader_url)
    {
        NSError *error = nil;
        NSString *fileContents = [NSString stringWithContentsOfURL:shader_url encoding:NSUTF8StringEncoding error:&error];
        
        _shader_lib = mtCreateShaderLibrary([fileContents cStringUsingEncoding:NSUTF8StringEncoding]);
        assert(_shader_lib);
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return true;
}

#pragma mark Window Delegate
// Window Delegate
- (BOOL)windowShouldClose:(NSWindow *)sender
{
    return true;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    return frameSize;
}


#pragma mark MTKView Delegate
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    NSScreen *screen;
    screen = [NSScreen mainScreen];
    
    float scale;
    scale = [screen backingScaleFactor];
    
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width * scale;
    _viewportSize.y = size.height * scale;
    
    if (_ctx)
    {
        mtSetViewport(0, 0, _viewportSize.x, _viewportSize.y);
    }
}


- (void)getViewportWidth:(unsigned *)width Height:(unsigned *)height
{
    NSScreen *screen;
    screen = [NSScreen mainScreen];
    
    float scale;
    scale = [screen backingScaleFactor];
    
    // Save the size of the drawable to pass to the vertex shader.
    NSRect frame;
    
    frame = [_view frame];
    
    *width = frame.size.width * scale;
    *height = frame.size.height * scale;
}

#pragma mark NSTabView Delegate
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(nullable NSTabViewItem *)tabViewItem
{
    
    return true;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(nullable NSTabViewItem *)tabViewItem
{
    
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(nullable NSTabViewItem *)tabViewItem
{
    
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
    
}

#pragma mark button click action selector
- (void)setClearRendermodeBit:(unsigned)bit setClear:(NSInteger)set
{
    if (set)
    {
        _render_mode_bitmask |= bit;
    }
    else
    {
        _render_mode_bitmask &= ~bit;
    }
}

- (void)buttonClick:(nullable id)sender
{
    NSButton *button;
    
    button = sender;
    
    if (button == _draw_type_popup_button)
    {
        _render_primitive = (MTuint)[_draw_type_popup_button selectedTag];
    }
    else if (button == _enable_color)
    {
        [self setClearRendermodeBit:RENDER_COLOR_BIT setClear:[_enable_color state]];
    }
    else if (button == _enable_normals)
    {
        [self setClearRendermodeBit:RENDER_NORMAL_BIT setClear:[_enable_normals state]];
    }
    else if (button == _enable_texture)
    {
        [self setClearRendermodeBit:RENDER_TEXTURE_BIT setClear:[_enable_texture state]];
    }
    else if (button == _enable_3D_view)
    {
        _use_3d_rot = [_enable_3D_view state];
    }
    else if (button == _enable_vertex_arrays)
    {
        _use_vertex_arrays = [_enable_vertex_arrays state];
        if(_use_vertex_arrays)
        {
            _vertex_array_setup_required = 1;
        }
        else
        {
            mtBindVertexArray(0);
        }
    }
    else if (button == _enable_depth_testing)
    {
        _use_depth_testing = [_enable_depth_testing state];
    }
    else if (button == _enable_stencil_testing)
    {
        _use_stencil_testing = [_enable_stencil_testing state];
    }
    else if (button == _enable_indexed_primitives)
    {
        _use_index_primitives = [_enable_indexed_primitives state];
    }
    else if (button == _enable_instancing)
    {
        _use_instancing = [_enable_instancing state];
        if (_use_instancing)
        {
            if (_instance_buffer_for_points == 0)
            {
                [self setupInstancingBuffer];
            }
        }
    }
    else
    {
        assert(0);
    }
    
    MTVertexShaderMode  vertex_shader_mode;

    if (_use_instancing)
    {
        vertex_shader_mode = MTVertexShaderModeInstanced;
    }
    else
    {
        vertex_shader_mode = MTVertexShaderModeNonInstanced;
    }

    MTFragmentShaderMode fragment_shader_mode;
    
    switch(_render_mode_bitmask)
    {
        case RENDER_COLOR_BIT:
            fragment_shader_mode = MTFragmentShaderModeColor;
            break;

        case RENDER_NORMAL_BIT:
            fragment_shader_mode = MTFragmentShaderModeNormal;
            break;

        case RENDER_COLOR_BIT | RENDER_NORMAL_BIT:
            fragment_shader_mode = MTFragmentShaderModeColorNormal;
            break;

        case RENDER_TEXTURE_BIT:
            fragment_shader_mode = MTFragmentShaderModeTexture;
            break;

        case RENDER_TEXTURE_BIT | RENDER_COLOR_BIT:
            fragment_shader_mode = MTFragmentShaderModeColorTexture;
            break;

        case RENDER_TEXTURE_BIT | RENDER_NORMAL_BIT:
            fragment_shader_mode = MTFragmentShaderModeNormalTexture;
            break;

        case RENDER_TEXTURE_BIT | RENDER_COLOR_BIT | RENDER_NORMAL_BIT:
            fragment_shader_mode = MTFragmentShaderModeColorNormalTexture;
            break;

        default:
            fragment_shader_mode = MTFragmentShaderModeColor;
            [_enable_color setState: true];
    }
    
    mtSetRendermode(vertex_shader_mode, fragment_shader_mode);
    
    if (_use_instancing)
    {
        mtBindImmModeVertexShader(MTVertexShaderModeInstanced, MTFragmentShaderModeAll, _shader_lib, "vertexShaderInstancedLocal");

        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeColor, _shader_lib, "fragmentShaderLocalColor");
        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeNormal, _shader_lib, "fragmentShaderLocalNormal");
        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeColorNormal, _shader_lib, "fragmentShaderLocalColorNormal");
        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeTexture, _shader_lib, "fragmentShaderLocalTexture");
        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeColorTexture, _shader_lib, "fragmentShaderLocalColorTexture");
        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeNormalTexture, _shader_lib, "fragmentShaderLocalNormalTexture");
        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeColorNormalTexture, _shader_lib, "fragmentShaderLocalColorNormalTexture");
    }
    else
    {
        mtBindImmModeVertexShader(MTVertexShaderModeInstanced, MTFragmentShaderModeAll, 0, NULL);
        mtBindImmModeFragmentShader(MTVertexShaderModeInstanced, MTFragmentShaderModeAll, 0, NULL);
    }

    if (_render_mode_bitmask & RENDER_TEXTURE_BIT)
    {
        mtBindFragmentTexture(_textures[0], 0);
        mtBindFragmentSampler(_samplers[0], 0);
    }
    else
    {
        mtBindFragmentTexture(0, 0);
        mtBindFragmentSampler(0, 0);
    }
}


#pragma mark drawing begins
float rndf(void)
{
    float f;
    
    do {
        f = (float)(random() & 0xffffff);
    } while(f == 0);
    
    f = f / (float)(0xffffff);
    
    return f;
}

float rndfr(float max)
{
    float f;
 
    f = rndf();
    
    f *= max;
    
    return f;
}

// random device coords
float rndfd(void)
{
    float f;
 
    f = rndf();
    
    f *= 2.0;
    
    f += -1.0;
    
    return f;
}

void submitRandomPoint(MTuint render_mode, float width, float height)
{
    if (render_mode & RENDER_MODE_COLOR)
    {
        mtColor3f(rndf(), rndf(), rndf());
    }
    
    if (render_mode & RENDER_MODE_TEX)
    {
        mtTexf(rndf(), rndf());
    }
    
    if (render_mode & RENDER_MODE_NORMAL)
    {
        mtNormalf(rndf(), rndf(), rndf());
    }
    
    mtVertex3f(rndfd(), rndfd(), rndf());
}

float deg2rad(float a)
{
    return a * (M_PI / 180.0);
}

void setPosition(Vertex4ColorNormalTex *verts, MTuint index, float x, float y, float z)
{
    verts[index].position.x = x;
    verts[index].position.y = y;
    verts[index].position.z = z;
    verts[index].position.w = 1.0;
}

void setColor(Vertex4ColorNormalTex *verts, MTuint index, float r, float g, float b)
{
    verts[index].color.x = r;
    verts[index].color.y = g;
    verts[index].color.z = b;
    verts[index].color.w = 1.0;
}

void setNormal(Vertex4ColorNormalTex *verts, MTuint index, float x, float y, float z)
{
    verts[index].normal.x = x;
    verts[index].normal.y = y;
    verts[index].normal.z = z;
    verts[index].normal.w = 1.0;
}

void setTex0(Vertex4ColorNormalTex *verts, MTuint index, float s, float t)
{
    verts[index].st[0].x = s;
    verts[index].st[0].y = t;
}

#define MAX_INSTANCES   1000

- (void)drawPoints
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    mtClearColor(0, 0, 0, 0);
    
    if (_use_instancing)
    {
        mtSetPointSize(4);
        
        mtBindInstanceBuffer(_instance_buffer_for_points);
        
        if (_use_vertex_arrays)
        {
            Vertex4ColorNormalTex   verts[1];

            setPosition(verts, 0, 0, 0, 0);
            setColor(verts, 0, 0, 0.8, 0.1);
            setTex0(verts, 0, 0, 0);

            mtBufferData(_vertex_buffer, sizeof(Vertex4ColorNormalTex), 0, verts);
            
            if (_use_index_primitives)
            {
                MTuint indices[1];
                
                indices[0] = 0;
                
                // yeah.. one index.
                mtBufferData(_index_buffer, sizeof(MTuint), 0, indices);
                
                mtBindIndexBuffer(_index_buffer);
                
                mtDrawElementsInstance(MTPrimitiveTypePoint, MTIndexTypeUInt32, 0, 1, MAX_INSTANCES);
            }
            else
            {
                mtDrawArrayInstance(MTPrimitiveTypePoint, 0, 1, MAX_INSTANCES, 0);
            }
        }
        else
        {
            if (_use_index_primitives)
            {
                mtColor3f(1.0, 1.0, 1.0);
                
                mtBeginElementInstance(MTPrimitiveTypePoint, MAX_INSTANCES);
                
                mtVertex3f(0.0, 0.0, 0.0);

                mtIndex(0);
                
                mtElementEnd();
            }
            else
            {
                mtColor3f(1.0, 1.0, 1.0);
                
                mtBeginInstance(MTPrimitiveTypePoint, MAX_INSTANCES);
                
                mtVertex3f(0.0, 0.0, 0.0);
                
                mtEnd();
            }
        }

        mtBindInstanceBuffer(0);
    }
    else if (_use_3d_rot)
    {
        mtSetPointSize(4);
        
        if (_use_vertex_arrays)
        {
            MTuint  vert_count;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            for(int pass=0; pass<2; pass++)
            {
                vert_count = 0;

                for(float y=-1.0; y<= 1.0; y+=0.05)
                {
                    float ry;
                    float rad;
                    
                    ry = sqrt(1 - y * y);
                    
                    for(float angle=0; angle<360; angle+= 5)
                    {
                        if (pass == 1)
                        {
                            float x, z;
                            
                            rad = deg2rad(angle);
                            
                            x = ry * sinf(rad);
                            z = ry * cosf(rad);
                            
                            setPosition(verts, vert_count, x, y, z);
                            setColor(verts, vert_count, 0, 0.8, 0.1);
                            setTex0(verts, vert_count, (x + 1)/2, (z + 1)/2);
                            
                            vert_count++;
                        }
                        else
                        {
                            vert_count++;
                        }
                    }
                }
                
                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);
                    vert_count = 0;
                }
                else
                {
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, verts);
                    
                    assert(vert_count);
                    
                    if (_use_index_primitives)
                    {
                        MTuint *indices;
                        
                        indices = newArray(MTuint, vert_count);
                        
                        for(int i=0; i<vert_count; i++)
                        {
                            indices[i] = i;
                        }
                        
                        mtBufferData(_index_buffer, vert_count * sizeof(MTuint), 0, indices);

                        free(indices);

                        mtBindIndexBuffer(_index_buffer);
                        
                        mtDrawElements(MTPrimitiveTypePoint, MTIndexTypeUInt32, 0, vert_count);
                    }
                    else
                    {
                        mtDrawArray(MTPrimitiveTypePoint, 0, vert_count);
                    }
                    
                    free(verts);
                }
            }
        }
        else
        {
            if (_use_index_primitives)
            {
                MTuint num_indices;
                
                num_indices = 0;
                
                mtBeginElement(MTPrimitiveTypePoint);
                
                // draw death star with points
                mtColor3f(0, 0.8, 0.1);
                
                for(float y=-1.0; y<= 1.0; y+=0.05)
                {
                    float ry;
                    float rad;
                    
                    ry = sqrt(1 - y * y);
                    
                    for(float angle=0; angle<360; angle+= 5)
                    {
                        float x, z;
                        
                        rad = deg2rad(angle);
                        
                        x = ry * sinf(rad);
                        z = ry * cosf(rad);
                        
                        mtTexf((x + 1)/2, (z + 1)/2);
                        mtVertex3f(x, y, z);
                        
                        num_indices++;
                    }
                }
                
                for(int i=0; i<num_indices; i++)
                {
                    mtIndex(i);
                }
                
                mtElementEnd();
            }
            else
            {
                mtBegin(MTPrimitiveTypePoint);
                
                // draw death star with points
                mtColor3f(0, 0.8, 0.1);
                
                for(float y=-1.0; y<= 1.0; y+=0.05)
                {
                    float ry;
                    float rad;
                    
                    ry = sqrt(1 - y * y);
                    
                    for(float angle=0; angle<360; angle+= 5)
                    {
                        float x, z;
                        
                        rad = deg2rad(angle);
                        
                        x = ry * sinf(rad);
                        z = ry * cosf(rad);
                        
                        mtTexf((x + 1)/2, (z + 1)/2);
                        mtVertex3f(x, y, z);
                    }
                }
                
                mtEnd();
            }
        }
    }
    else
    {
        mtSetPointSize(4.0);
        
        if (_use_vertex_arrays)
        {
            Vertex4ColorNormalTex   *verts;
            MTuint vert_count;
            
            vert_count = 100;
            
            verts = newArray(Vertex4ColorNormalTex, vert_count);

            for(int i=0; i<vert_count; i++)
            {
                setPosition(verts, i, rndfd(), rndfd(), rndfd());
                setColor(verts, i, rndf(), rndf(), rndf());
                setTex0(verts, i, rndf(), rndf());
            }

            // draw it twice to test dirty logic
            for(int pass=0; pass<2; pass++)
            {
                mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, verts);
                
                mtDrawArray(MTPrimitiveTypePoint, 0, vert_count);
            }
            
            // trace update renderbuffer thorugh this, there should be no dirty state
            mtDrawArray(MTPrimitiveTypePoint, 0, vert_count);

            free(verts);
        }
        else
        {
            if (_use_index_primitives)
            {
                mtBeginElement(MTPrimitiveTypePoint);
                
                for(int i=0; i<100; i++)
                {
                    submitRandomPoint(_render_mode_bitmask, width, height);
                }
                
                for(int i=0; i<100; i++)
                {
                    mtIndex(i);
                }
                
                mtElementEnd();
            }
            else
            {
                mtBegin(MTPrimitiveTypePoint);
                
                for(int i=0; i<100; i++)
                {
                    submitRandomPoint(_render_mode_bitmask, width, height);
                }
                
                mtEnd();
            }
        }
    }
}

- (void)drawLines
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];
    
    if (_use_instancing)
    {
        printf("No %s test for instancing\n", __FUNCTION__);
    }
    else if (_use_3d_rot)
    {
        if (_use_vertex_arrays)
        {
            MTuint  vert_count, strip_index;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            mtClearColor(0, 0, 0, 0);

            for(int pass=0; pass<2; pass++)
            {
                vert_count = 0;
                strip_index = 0;
                
                for(float y=-1.0; y<= 1.0; y+=0.01)
                {
                    float ry;
                    float rad;
                    
                    ry = sqrt(1 - y * y);
                    
                    for(float angle=0; angle<360; angle+= 2)
                    {
                        if (pass == 1)
                        {
                            float x, z;
                            
                            rad = deg2rad(angle);
                            
                            x = ry * sinf(rad);
                            z = ry * cosf(rad);
                            
                            setPosition(verts, vert_count, x, y, z);
                            setColor(verts, vert_count, 0, 0.8, 0.1);
                            setTex0(verts, vert_count, (x + 1)/2, (z + 1)/2);
                            
                            vert_count++;
                            
                            rad = deg2rad(angle + 2);
                            
                            x = ry * sinf(rad);
                            z = ry * cosf(rad);
                            
                            setPosition(verts, vert_count, x, y, z);
                            setColor(verts, vert_count, 0, 0.8, 0.1);
                            setTex0(verts, vert_count, (x + 1)/2, (z + 1)/2);
                            
                            vert_count++;
                        }
                        else
                        {
                            vert_count += 2;
                        }
                    }

                    if (pass == 1)
                    {
                        MTsizei offset, size;
                        
                        // copy data into buffer in strips to test dirty region logic
                        offset = strip_index * vert_count * sizeof(Vertex4ColorNormalTex);
                        size = vert_count * sizeof(Vertex4ColorNormalTex);
                        
                        // just to test data dirty region logic
                        if (strip_index == 1)
                        {
                            mtBufferData(_vertex_buffer, size, offset, verts);
                            mtBufferData(_vertex_buffer, size, offset * 2, verts);
                            mtBufferData(_vertex_buffer, size, offset * 3, verts);
                            mtBufferData(_vertex_buffer, size, offset * 4, verts);
                        }
                        else
                        {
                            mtBufferData(_vertex_buffer, size, offset, verts);
                        }
                        
                        if(_use_index_primitives)
                        {
                            MTuint *indices;
                            
                            indices = newArray(MTuint, vert_count);
                            
                            for(int i=0; i<vert_count; i++)
                            {
                                indices[i] = strip_index * vert_count + i;
                            }
                            
                            mtBufferData(_index_buffer, sizeof(MTuint) * vert_count, strip_index * vert_count * sizeof(MTuint), indices);
                            
                            free(indices);
                            
                            mtBindIndexBuffer(_index_buffer);
                            
                            mtDrawElements(MTPrimitiveTypeLine, MTIndexTypeUInt32, strip_index * vert_count * sizeof(MTuint), vert_count);
                        }
                        else
                        {
                            mtDrawArray(MTPrimitiveTypeLine, strip_index * vert_count, vert_count);
                        }

                        strip_index++;
                        vert_count = 0;
                    }
                }

                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);

                    // resize buffer
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, NULL);

                    // fill it with data to test full dirty logic
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, verts);

                    mtBufferData(_index_buffer, vert_count * sizeof(MTuint), 0, NULL);

                    vert_count = 0;
                }
            }

            free(verts);
        }
        else
        {
            for(float y=-1.0; y<= 1.0; y+=0.01)
            {
                float ry;
                float rad;
                
                ry = sqrt(1 - y * y);
                
                mtBegin(MTPrimitiveTypeLine);
                
                // draw death star with lines
                mtClearColor(0, 0, 0, 0);
                mtColor3f(0, 0.8, 0.1);
                
                for(float angle=0; angle<360; angle+= 2)
                {
                    float x, z;
                    
                    rad = deg2rad(angle);
                    
                    x = ry * sinf(rad);
                    z = ry * cosf(rad);
                    
                    mtTexf((x + 1)/2, (z + 1)/2);
                    mtVertex3f(x, y, z);
                    
                    rad = deg2rad(angle + 2);
                    
                    x = ry * sinf(rad);
                    z = ry * cosf(rad);
                    
                    mtTexf((x + 1)/2, (z + 1)/2);
                    mtVertex3f(x, y, z);
                }
                
                mtEnd();
            }
        }
    }
    else
    {
        if (_use_vertex_arrays)
        {
            MTuint  vert_count, strip_index;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            mtClearColor(0, 0, 0, 0);
            
            for(int pass=0; pass<2; pass++)
            {
                vert_count = 0;
                strip_index = 0;

                for(int i=0; i<100; i++)
                {
                    if (pass == 0)
                    {
                        vert_count += 2;
                    }
                    else
                    {
                        setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                        setColor(verts, vert_count, rndf(), rndf(), rndf());
                        setTex0(verts, vert_count, rndf(), rndf());
                        
                        vert_count++;
                        
                        setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                        setColor(verts, vert_count, rndf(), rndf(), rndf());
                        setTex0(verts, vert_count, rndf(), rndf());
                        
                        vert_count++;
                    }
                }
                
                MTsizei size;
                
                // copy data into buffer in strips to test dirty region logic
                size = vert_count * sizeof(Vertex4ColorNormalTex);


                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);

                    mtBufferData(_vertex_buffer, size, 0, verts);
                }
                else
                {
                    mtBufferData(_vertex_buffer, size, 0, verts);

                    if (_use_index_primitives)
                    {
                        if (vert_count < (1 << 16))
                        {
                            MTushort *indices;
                            
                            indices = newArray(MTushort, vert_count);
                            
                            for(int i=0; i<vert_count; i++)
                            {
                                indices[i] = i;
                            }
                            
                            mtBufferData(_index_buffer, sizeof(MTushort) * vert_count, 0, indices);
                            
                            free(indices);
                            
                            mtBindIndexBuffer(_index_buffer);
                            
                            mtDrawElements(MTPrimitiveTypeLine, MTIndexTypeUInt16, 0, vert_count);
                        }
                        else
                        {
                            MTuint *indices;
                            
                            indices = newArray(MTuint, vert_count);
                            
                            for(int i=0; i<vert_count; i++)
                            {
                                indices[i] = i;
                            }
                            
                            mtBufferData(_index_buffer, sizeof(MTuint) * vert_count, 0, indices);
                            
                            free(indices);
                            
                            mtBindIndexBuffer(_index_buffer);
                            
                            mtDrawElements(MTPrimitiveTypeLine, MTIndexTypeUInt32, 0, vert_count);
                        }
                    }
                    else
                    {
                        mtDrawArray(MTPrimitiveTypeLine, 0, vert_count);
                    }
                }
            }
            
            free(verts);
        }
        else
        {
            if (_use_index_primitives)
            {
                mtBeginElement(MTPrimitiveTypeLine);
                
                for(int i=0; i<100; i++)
                {
                    submitRandomPoint(_render_mode_bitmask, width, height);
                }

                for(int i=0; i<99; i++)
                {
                    mtIndex(i);
                    mtIndex(i+1);
                }

                mtElementEnd();
            }
            else
            {
                mtBegin(MTPrimitiveTypeLine);
                
                for(int i=0; i<100; i++)
                {
                    submitRandomPoint(_render_mode_bitmask, width, height);
                    
                    submitRandomPoint(_render_mode_bitmask, width, height);
                }
                
                mtEnd();
            }
        }
    }
}

- (void)drawLineStrip
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    if (_use_instancing)
    {
        printf("No %s test for instancing\n", __FUNCTION__);
    }
    else if (_use_3d_rot)
    {
        if (_use_vertex_arrays)
        {
            MTuint  total_vert_count, vert_count, strip_index;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            mtClearColor(0, 0, 0, 0);
            
            for(int pass=0; pass<2; pass++)
            {
                total_vert_count = 0;
                vert_count = 0;
                strip_index = 0;

                for(float y=-1.0; y<= 1.0; y+=0.01)
                {
                    float ry;
                    float rad;
                    
                    ry = sqrt(1 - y * y);
                    
                    vert_count = 0;

                    for(float angle=0; angle<360; angle+= 2)
                    {
                        if(pass == 0)
                        {
                            vert_count++;
                        }
                        else
                        {
                            float x, z;

                            rad = deg2rad(angle);
                            
                            x = ry * sinf(rad);
                            z = ry * cosf(rad);
                            
                            setPosition(verts, vert_count, x, y, z);
                            setColor(verts, vert_count, 0, 0.8, 0.1);
                            setTex0(verts, vert_count, (x + 1)/2, (z + 1)/2);
                            
                            vert_count++;
                        }
                    }
                    
                    if (pass == 1)
                    {
                        MTsizei offset, size;
                        
                        // copy data into buffer in strips to test dirty region logic
                        size = vert_count * sizeof(Vertex4ColorNormalTex);
                        offset = strip_index * size;

                        mtBufferData(_vertex_buffer, size, offset, verts);
                    }
                    
                    strip_index++;
                    total_vert_count += vert_count;
                }
                
                if (pass == 0)
                {
                    assert(strip_index * vert_count == total_vert_count);
                    
                    verts = newArray(Vertex4ColorNormalTex, vert_count);

                    // resize buffer
                    mtBufferData(_vertex_buffer, total_vert_count * sizeof(Vertex4ColorNormalTex), 0, NULL);

                    vert_count = 0;
                }
                else
                {
                    assert(vert_count);
                    
                    // draw all lines packed into buffer
                    if (_use_index_primitives)
                    {
                        MTuint  *indices;
                        
                        indices = newArray(MTuint, total_vert_count);
                        
                        for(int i=0; i<strip_index; i++)
                        {
                            MTuint strip_offset;
                            
                            strip_offset = i * vert_count;
                            
                            for(int j=0; j<vert_count; j++)
                            {
                                indices[strip_offset + j] = strip_offset + j;
                            }
                        }
                        
                        mtBufferData(_index_buffer, total_vert_count * sizeof(MTuint), 0, indices);
                        
                        free(indices);
                        
                        mtBindIndexBuffer(_index_buffer);
                        
                        for(int i=0; i<strip_index; i++)
                        {
                            mtDrawElements(MTPrimitiveTypeLineStrip,
                                           MTIndexTypeUInt32,
                                           i * vert_count * sizeof(MTuint),
                                           vert_count);
                        }
                    }
                    else
                    {
                        for(int i=0; i<strip_index; i++)
                        {
                            mtDrawArray(MTPrimitiveTypeLineStrip, i * vert_count, vert_count);
                        }
                    }
                    
                    free(verts);
                }
            }
        }
        else
        {
            for(float y=-1.0; y<= 1.0; y+=0.01)
            {
                float ry;
                float rad;
                unsigned point_count;
                
                ry = sqrt(1 - y * y);
                point_count = 0;
                
                if (_use_index_primitives)
                {
                    int index;

                    index = 0;
                    // draw death star with points
                    mtClearColor(0, 0, 0, 0);
                    mtColor3f(0, 0.8, 0.1);
                    mtNormalf(0.5, 0.5, 0.5);
                    
                    mtBeginElement(MTPrimitiveTypeLineStrip);
                    
                    for(float angle=0; angle<360; angle+= 2)
                    {
                        float x, z;
                        
                        rad = deg2rad(angle);
                        
                        x = ry * sinf(rad);
                        z = ry * cosf(rad);
                        
                        mtTexf((x + 1)/2, (z + 1)/2);
                        mtVertex3f(x, y, z);
                        mtIndex(index++);

                        point_count++;
                    }
                    
                    mtElementEnd();
                }
                else
                {
                    mtBegin(MTPrimitiveTypeLineStrip);
                    
                    // draw death star with points
                    mtClearColor(0, 0, 0, 0);
                    mtColor3f(0, 0.8, 0.1);
                    mtNormalf(0.5, 0.5, 0.5);
                    
                    for(float angle=0; angle<360; angle+= 2)
                    {
                        float x, z;
                        
                        rad = deg2rad(angle);
                        
                        x = ry * sinf(rad);
                        z = ry * cosf(rad);
                        
                        mtTexf((x + 1)/2, (z + 1)/2);
                        mtVertex3f(x, y, z);
                        point_count++;
                    }
                    
                    mtEnd();
                }
            }
        }
    }
    else
    {
        if (_use_vertex_arrays)
        {
            MTuint  vert_count;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            mtClearColor(0, 0, 0, 0);
            
            for(int pass=0; pass<2; pass++)
            {
                vert_count = 0;

                for(int i=0; i<100; i++)
                {
                    if (pass == 0)
                    {
                        vert_count++;
                    }
                    else
                    {
                        setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                        setColor(verts, vert_count, rndf(), rndf(), rndf());
                        setTex0(verts, vert_count, rndf(), rndf());
                        
                        vert_count++;
                    }
                }
                
                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);

                    // resize buffer
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, NULL);

                    vert_count = 0;
                }
                else
                {
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, verts);

                    if (_use_index_primitives)
                    {
                        MTuint *indices;
                        
                        indices = newArray(MTuint, vert_count);
                        
                        for(int i=0; i<vert_count; i++)
                        {
                            indices[i] = i;
                        }
                        
                        mtBufferData(_index_buffer, vert_count * sizeof(MTuint), 0, indices);
                        
                        free(indices);
                        
                        mtBindIndexBuffer(_index_buffer);

                        mtDrawElements(MTPrimitiveTypeLineStrip, MTIndexTypeUInt32, 0, vert_count);
                    }
                    else
                    {
                        mtDrawArray(MTPrimitiveTypeLineStrip, 0, vert_count);
                    }
                                        
                    free(verts);
                }
            }
        }
        else
        {
            if (_use_index_primitives)
            {
                mtBeginElement(MTPrimitiveTypeLineStrip);
                
                for(int i=0; i<100; i++)
                {
                    submitRandomPoint(_render_mode_bitmask, width, height);
                    
                    mtIndex(i);
                }
                
                mtElementEnd();
            }
            else
            {
                mtBegin(MTPrimitiveTypeLineStrip);
                
                for(int i=0; i<100; i++)
                {
                    submitRandomPoint(_render_mode_bitmask, width, height);
                }
                
                mtEnd();
            }
        }
    }
}

- (void)drawTriangles
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    if (_use_instancing)
    {
        printf("No %s test for instancing\n", __FUNCTION__);
    }
    else if (_use_3d_rot)
    {
        float delta;
        
        delta = 0.05;
        
        mtClearColor(0, 0, 0, 0);

        if (_use_vertex_arrays)
        {
            MTuint  vert_count;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            mtClearColor(0, 0, 0, 0);
            
            for(int pass=0; pass<2; pass++)
            {
                vert_count = 0;
                
                vector_float3 p0, p1, p2, p3;
                
                for(float z=-1; z<1; z+=delta)
                {
                    float zd;
                    zd = z + delta;
                    
                    for(float x=-1; x<1; x+=delta)
                    {
                        if (pass == 0)
                        {
                            vert_count += 6;
                        }
                        else
                        {
                            float xd, y;
                            
                            xd = x + delta;
                            
                            vector_float3 color;
                            
                            y = x * x + z * z;
                            
                            color = vector3(x, y, z);
                            
                            color = color * color;
                            color = simd_length(color);
                            
                            y = x * x + z * z;
                            y = sqrtf(y);
                            p0 = vector3(x, y, z);
                            
                            y = x * x + zd * zd;
                            y = sqrtf(y);
                            p1 = vector3(x, y, zd);
                            
                            y = xd * xd + z * z;
                            y = sqrtf(y);
                            p2 = vector3(xd, y, z);
                            
                            y = xd * xd + zd * zd;
                            y = sqrtf(y);
                            p3 = vector3(xd, y, zd);
                            
                            // Triangle 0
                            // p0
                            setPosition(verts, vert_count, p0.x, p0.y, p0.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p0.x + 1)/2, (p0.z + 1)/2);
                            
                            vert_count++;
                            
                            // p1
                            setPosition(verts, vert_count, p1.x, p1.y, p1.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p1.x + 1)/2, (p1.z + 1)/2);
                            
                            vert_count++;
                            
                            // p2
                            setPosition(verts, vert_count, p2.x, p2.y, p2.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p2.x + 1)/2, (p2.z + 1)/2);
                            
                            vert_count++;
                            
                            // triangle 1
                            // p1
                            setPosition(verts, vert_count, p1.x, p1.y, p1.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p1.x + 1)/2, (p1.z + 1)/2);
                            
                            vert_count++;
                            
                            // p2
                            setPosition(verts, vert_count, p2.x, p2.y, p2.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p2.x + 1)/2, (p2.z + 1)/2);
                            
                            vert_count++;

                            // p3
                            setPosition(verts, vert_count, p3.x, p3.y, p3.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p3.x + 1)/2, (p3.z + 1)/2);
                            
                            vert_count++;
                        }
                    }
                }
                    
                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);
                    
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, NULL);
                }
                else
                {
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, verts);

                    if (_use_index_primitives)
                    {
                        MTuint *indices;
                        
                        indices = newArray(MTuint, vert_count);
                        
                        for(int i=0; i<vert_count; i++)
                        {
                            indices[i] = i;
                        }
                        
                        mtBufferData(_index_buffer, vert_count * sizeof(MTuint), 0, indices);
                        
                        free(indices);

                        mtBindIndexBuffer(_index_buffer);
                        
                        mtDrawElements(MTPrimitiveTypeTriangle, MTIndexTypeUInt32, 0, vert_count);
                    }
                    else
                    {
                        mtDrawArray(MTPrimitiveTypeTriangle, 0, vert_count);
                    }
                    
                    free(verts);
                }
            }
        }
        else
        {
            mtColor3f(0, 0.1, 0.8);
            
            vector_float3 p0, p1, p2, p3;
            
            for(float z=-1; z<1; z+=delta)
            {
                float zd;
                zd = z + delta;
                
                if (_use_index_primitives)
                {
                    mtBeginElement(MTPrimitiveTypeTriangle);
                }
                else
                {
                    mtBegin(MTPrimitiveTypeTriangle);
                }
                
                MTuint index;
                
                index = 0;
                
                for(float x=-1; x<1; x+=delta)
                {
                    float xd, y;
                    
                    xd = x + delta;
                    
                    vector_float3 color;
                    
                    y = x * x + z * z;
                    
                    color = vector3(x, y, z);
                    
                    color = color * color;
                    color = simd_length(color);
                    
                    mtColor3f(color.x, color.y, color.z);
                    mtNormalf(color.x, color.y, color.z);
                    
                    y = sqrtf(y);
                    p0 = vector3(x, y, z);
                    
                    y = xd * xd + z * z;
                    y = sqrtf(y);
                    p1 = vector3(xd, y, z);
                    
                    y = x * x + zd * zd;
                    y = sqrtf(y);
                    p2 = vector3(x, y, zd);
                    
                    y = xd * xd + zd * zd;
                    y = sqrtf(y);
                    p3 = vector3(xd, y, zd);
                    
                    // triangle 0
                    if (_use_index_primitives)
                    {
                        // p0
                        mtTexf((p0.x + 1)/2, (p0.z + 1)/2);
                        mtVertex3f(p0.x, p0.y, p0.z);
                        
                        // p1
                        mtTexf((p1.x + 1)/2, (p1.z + 1)/2);
                        mtVertex3f(p1.x, p1.y, p1.z);
                        
                        // p2
                        mtTexf((p2.x + 1)/2, (p2.z + 1)/2);
                        mtVertex3f(p2.x, p2.y, p2.z);
                        
                        // p3
                        mtTexf((p3.x + 1)/2, (p3.z + 1)/2);
                        mtVertex3f(p3.x, p3.y, p3.z);

                        mtIndex(index + 0);
                        mtIndex(index + 1);
                        mtIndex(index + 2);

                        mtIndex(index + 1);
                        mtIndex(index + 3);
                        mtIndex(index + 2);
                        
                        index += 4;
                    }
                    else
                    {
                        // p0
                        mtTexf((p0.x + 1)/2, (p0.z + 1)/2);
                        mtVertex3f(p0.x, p0.y, p0.z);
                        
                        // p1
                        mtTexf((p1.x + 1)/2, (p1.z + 1)/2);
                        mtVertex3f(p1.x, p1.y, p1.z);
                        
                        // p2
                        mtTexf((p2.x + 1)/2, (p2.z + 1)/2);
                        mtVertex3f(p2.x, p2.y, p2.z);
                        
                        // triangle 1
                        // p1
                        mtTexf((p1.x + 1)/2, (p1.z + 1)/2);
                        mtVertex3f(p1.x, p1.y, p1.z);
                        
                        // p3
                        mtTexf((p3.x + 1)/2, (p3.z + 1)/2);
                        mtVertex3f(p3.x, p3.y, p3.z);
                        
                        // p2
                        mtTexf((p2.x + 1)/2, (p2.z + 1)/2);
                        mtVertex3f(p2.x, p2.y, p2.z);
                    }
                }
                
                mtEnd();
            }
        }
    }
    else
    {
        if (_use_vertex_arrays)
        {
            MTuint  vert_count;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            mtClearColor(0, 0, 0, 0);
            
            for(int pass=0; pass<2; pass++)
            {
                vert_count = 0;

                for(int i=0; i<100; i++)
                {
                    if (pass == 0)
                    {
                        vert_count += 3;
                    }
                    else
                    {
                        // vert 0
                        setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                        setColor(verts, vert_count, rndf(), rndf(), rndf());
                        setTex0(verts, vert_count, rndf(), rndf());
                        
                        vert_count++;

                        // vert 1
                        setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                        setColor(verts, vert_count, rndf(), rndf(), rndf());
                        setTex0(verts, vert_count, rndf(), rndf());
                        
                        vert_count++;

                        // vert 2
                        setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                        setColor(verts, vert_count, rndf(), rndf(), rndf());
                        setTex0(verts, vert_count, rndf(), rndf());
                        
                        vert_count++;
                    }
                }
                
                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);

                    // resize buffer
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, NULL);

                    vert_count = 0;
                }
                else
                {
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, verts);

                    if (_use_index_primitives)
                    {
                        MTuint *indices;
                        
                        indices = newArray(MTuint, vert_count);
                        
                        for(int i=0; i<vert_count; i++)
                        {
                            indices[i] = i;
                        }
                        
                        mtBufferData(_index_buffer, vert_count * sizeof(MTuint), 0, indices);
                        
                        free(indices);
                        
                        mtBindIndexBuffer(_index_buffer);
                        
                        mtDrawElements(MTPrimitiveTypeTriangle, MTIndexTypeUInt32, 0, vert_count);
                    }
                    else
                    {
                        mtDrawArray(MTPrimitiveTypeTriangle, 0, vert_count);
                    }
                    
                    free(verts);
                }
            }
        }
        else
        {
            _use_index_primitives ? mtBeginElement(MTPrimitiveTypeTriangle) : mtBegin(MTPrimitiveTypeTriangle);

            MTuint index;
            
            index = 0;
            
            for(int i=0; i<100; i++)
            {
                submitRandomPoint(_render_mode_bitmask, width, height);
                _use_index_primitives ? mtIndex(index++) : 0;

                submitRandomPoint(_render_mode_bitmask, width, height);
                _use_index_primitives ? mtIndex(index++) : 0;

                submitRandomPoint(_render_mode_bitmask, width, height);
                _use_index_primitives ? mtIndex(index++) : 0;
            }
            
            _use_index_primitives ? mtElementEnd() : mtEnd();
        }
    }
}

- (void)drawTriangleStrips
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    if (_use_instancing)
    {
        printf("No %s test for instancing\n", __FUNCTION__);
    }
    else if (_use_3d_rot)
    {
        float delta;
        
        delta = 0.05;
        
        mtClearColor(0, 0, 0, 0);
        
        MTuint strip_index;
        
        if (_use_vertex_arrays)
        {
            MTuint  vert_count, total_vert_count;
            Vertex4ColorNormalTex *verts;
            MTuint *indices;
            
            verts = NULL;
            indices = NULL;
            
            mtClearColor(0, 0, 0, 0);
            
            vert_count = 0;
            total_vert_count = 0;
            strip_index = 0;
            
            for(int pass=0; pass<2; pass++)
            {
                total_vert_count = 0;
                vert_count = 0;
                strip_index = 0;
                
                indices = NULL;
                
                for(float z=-1; z<1; z+=delta)
                {
                    float zd;
                    zd = z + delta;
                    
                    vert_count = 0;
                    
                    for(float x=-1; x<=1; x+=delta)
                    {
                        if (pass == 0)
                        {
                            vert_count += 2;
                        }
                        else
                        {
                            vector_float3 color;
                            float y;
                            
                            y = x * x + z * z;
                            
                            color = vector3(x, y, z);
                            
                            color = color * color;
                            color = simd_length(color);
                            
                            vector_float3 p0, p1;
                            
                            y = x * x + z * z;
                            y = sqrtf(y);
                            p0 = vector3(x, y, z);
                            
                            y = x * x + zd * zd;
                            y = sqrtf(y);
                            p1 = vector3(x, y, zd);
                            
                            // p0
                            setPosition(verts, vert_count, p0.x, p0.y, p0.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p0.x + 1)/2, (p0.z + 1)/2);
                            
                            vert_count++;
                            
                            // p1
                            setPosition(verts, vert_count, p1.x, p1.y, p1.z);
                            setColor(verts, vert_count, color.x, color.y, color.z);
                            setNormal(verts, vert_count, color.x, color.y, color.z);
                            setTex0(verts, vert_count, (p1.x + 1)/2, (p1.z + 1)/2);
                            
                            vert_count++;
                        }
                    }
                    
                    if (pass == 1)
                    {
                        MTsizei size, offset;
                        
                        size =  vert_count * sizeof(Vertex4ColorNormalTex);
                        offset = size * strip_index;
                        
                        mtBufferData(_vertex_buffer, size, offset, verts);
                    }
                    
                    strip_index++;
                    total_vert_count += vert_count;
                }
                
                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);
                    
                    mtBufferData(_vertex_buffer, total_vert_count * sizeof(Vertex4ColorNormalTex), 0, NULL);
                }
            }
            
            assert(strip_index);
            assert(vert_count);
            
            if (_use_index_primitives)
            {
                indices = newArray(MTuint, total_vert_count);
                
                for(int i=0; i<total_vert_count; i++)
                {
                    indices[i] = i;
                }
                
                mtBufferData(_index_buffer, total_vert_count * sizeof(MTuint), 0, indices);
                
                free(indices);
                
                mtBindIndexBuffer(_index_buffer);
                
                for(int i=0; i<strip_index; i++)
                {
                    mtDrawElements(MTPrimitiveTypeTriangleStrip, MTIndexTypeUInt32, i * vert_count * sizeof(MTuint), vert_count);
                }
            }
            else
            {
                for(int i=0; i<strip_index; i++)
                {
                    mtDrawArray(MTPrimitiveTypeTriangleStrip, i * vert_count, vert_count);
                }
            }
        }
        else
        {
            mtClearColor(0, 0, 0, 0);
            
            for(float z=-1; z<=1; z+=delta)
            {
                float zd;
                zd = z + delta;
                
                MTuint index;
                
                index = 0;
                
                _use_index_primitives ? mtBeginElement(MTPrimitiveTypeTriangleStrip) : mtBegin(MTPrimitiveTypeTriangleStrip);
                
                for(float x=-1; x<=1; x+=delta)
                {
                    float xd, y;
                    
                    xd = x + delta;
                    
                    vector_float3 color;
                    
                    y = x * x + z * z;
                    
                    color = vector3(x, y, z);
                    
                    color = color * color;
                    color = simd_length(color);
                    
                    mtColor3f(color.x, color.y, color.z);
                    mtNormalf(color.x, color.y, color.z);
                    
                    vector_float3 p0, p1;
                    
                    y = x * x + z * z;
                    y = sqrtf(y);
                    p0 = vector3(x, y, z);
                    
                    y = x * x + zd * zd;
                    y = sqrtf(y);
                    p1 = vector3(x, y, zd);
                    
                    // p0
                    mtTexf((p0.x + 1)/2, (p0.z + 1)/2);
                    mtVertex3f(p0.x, p0.y, p0.z);
                    _use_index_primitives ? mtIndex(index++) : 0;
                    
                    // p1
                    mtTexf((p1.x + 1)/2, (p1.z + 1)/2);
                    mtVertex3f(p1.x, p1.y, p1.z);
                    _use_index_primitives ? mtIndex(index++) : 0;
                }
                
                _use_index_primitives ? mtElementEnd() : mtEnd();
            }
        }
    }
    else // !_use_3d_rot
    {
        if (_use_vertex_arrays)
        {
            MTuint  vert_count;
            Vertex4ColorNormalTex   *verts;
            
            verts = NULL;
            
            mtClearColor(0, 0, 0, 0);
            
            for(int pass=0; pass<2; pass++)
            {
                vert_count = 0;

                for(int i=0; i<100; i++)
                {
                    if (pass == 0)
                    {
                        if (i == 0)
                        {
                            vert_count += 3;
                        }
                        else
                        {
                            vert_count++;
                        }
                    }
                    else
                    {
                        if (i == 0)
                        {
                            // vert 0
                            setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                            setColor(verts, vert_count, rndf(), rndf(), rndf());
                            setTex0(verts, vert_count, rndf(), rndf());
                            
                            vert_count++;
                            
                            // vert 1
                            setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                            setColor(verts, vert_count, rndf(), rndf(), rndf());
                            setTex0(verts, vert_count, rndf(), rndf());
                            
                            vert_count++;
                        }
                        
                        // vert 2
                        setPosition(verts, vert_count, rndfd(), rndfd(), rndfd());
                        setColor(verts, vert_count, rndf(), rndf(), rndf());
                        setTex0(verts, vert_count, rndf(), rndf());
                        
                        vert_count++;
                    }
                }
                
                if (pass == 0)
                {
                    verts = newArray(Vertex4ColorNormalTex, vert_count);

                    // resize buffer
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, NULL);

                    vert_count = 0;
                }
                else
                {
                    mtBufferData(_vertex_buffer, vert_count * sizeof(Vertex4ColorNormalTex), 0, verts);

                    if (_use_index_primitives)
                    {
                        MTuint *indices;
                        
                        indices = newArray(MTuint, vert_count);
                        
                        for(int i=0; i<vert_count; i++)
                        {
                            indices[i] = i;
                        }
                        
                        mtBufferData(_index_buffer, vert_count * sizeof(MTuint), 0, indices);
                        
                        free(indices);
                        
                        mtBindIndexBuffer(_index_buffer);
                        
                        mtDrawElements(MTPrimitiveTypeTriangle, MTIndexTypeUInt32, 0, vert_count);
                    }
                    else
                    {
                        mtDrawArray(MTPrimitiveTypeTriangle, 0, vert_count);
                    }
                    
                    free(verts);
                }
            }
        }
        else
        {
            MTuint index;
            
            index = 0;
            
            _use_index_primitives ? mtBeginElement(MTPrimitiveTypeTriangleStrip) : mtBegin(MTPrimitiveTypeTriangleStrip);
            
            submitRandomPoint(_render_mode_bitmask, width, height);
            _use_index_primitives ? mtIndex(index++) : 0;
            
            submitRandomPoint(_render_mode_bitmask, width, height);
            _use_index_primitives ? mtIndex(index++) : 0;
            
            for(int i=0; i<100; i++)
            {
                submitRandomPoint(_render_mode_bitmask, width, height);
                _use_index_primitives ? mtIndex(index++) : 0;
            }
            
            _use_index_primitives ? mtElementEnd() : mtEnd();
        }
    }
}

- (void)drawScene
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];
    
    if (_use_instancing)
    {
        if ((_sim_frame_count_for_points++ % 100) == 0)
        {
            _sim_direction_for_points = !_sim_direction_for_points;
        }
        
        MTfloat dir;
        
        dir = 1.0;
        
        for(int i=0; i<MAX_INSTANCES; i++)
        {
            float dist;
            
            dist = (_instance_state_for_points[i].pos.x * _instance_state_for_points[i].pos.x ) +
            (_instance_state_for_points[i].pos.y * _instance_state_for_points[i].pos.y ) +
            (_instance_state_for_points[i].pos.z * _instance_state_for_points[i].pos.z);
            
            dist += 0.1 * rndf();
            
            if (dist < 5.0)
            {
                _instance_state_for_points[i].vel.x += _instance_state_for_points[i].accel.x * dir;
                _instance_state_for_points[i].vel.y += _instance_state_for_points[i].accel.y * dir;
                _instance_state_for_points[i].vel.z += _instance_state_for_points[i].accel.z * dir;
                
                _instance_state_for_points[i].pos.x += _instance_state_for_points[i].vel.x;
                _instance_state_for_points[i].pos.y += _instance_state_for_points[i].vel.y;
                _instance_state_for_points[i].pos.z += _instance_state_for_points[i].vel.z;
            }
            else
            {
                _instance_state_for_points[i].pos.x = 0.0;
                _instance_state_for_points[i].pos.y = 0.0;
                _instance_state_for_points[i].pos.z = 0.0;
                _instance_state_for_points[i].pos.w = 1.0;
                
                _instance_state_for_points[i].vel.x = rndfd() * 0.0001;
                _instance_state_for_points[i].vel.y = rndfd() * 0.0001;
                _instance_state_for_points[i].vel.z = rndfd() * 0.0001;
                _instance_state_for_points[i].vel.w = 1.0;
                
                _instance_state_for_points[i].accel.x = rndfd() * 0.01;
                _instance_state_for_points[i].accel.y = rndfd() * 0.01;
                _instance_state_for_points[i].accel.z = rndfd() * 0.01;
                _instance_state_for_points[i].accel.w = 1.0;
            }
        }
        
        MTsizei size;
        
        size = MAX_INSTANCES * sizeof(LocalInstanceState);
        
        mtBufferData(_instance_buffer_for_points, size, 0, _instance_state_for_points);
    }
    
    if (_use_depth_testing)
    {
        mtEnable(MTCapDepthTest);
        mtDepthMode(MTCompareFunctionLessEqual);
        
        mtClearDepthValue(1.0);
        mtClear(MT_CLEAR_COLOR_BUFFER | MT_CLEAR_DEPTH_BUFFER);
    }
    else
    {
        mtDisable(MTCapDepthTest);
        mtClear(MT_CLEAR_COLOR_BUFFER);
    }

    if (_use_stencil_testing)
    {
        mtEnable(MTCapStencilTest);
    }
    else
    {
        mtDisable(MTCapStencilTest);
    }

    if (_use_3d_rot)
    {
        float angle, ratio, near, far;
        float b, t, l, r;
        
        angle = 90;
        ratio = (float)width / (float)height;
        near = 0.1;
        far = 100;
        
        mtMatrixMode(MTMatrixMode_Projection);
        mtLoadIdentityf();
        mtPerspectivef(angle, ratio, near, far, &b, &t, &l, &r);
        mtFrustrumf(l, r, b, t, near, far);
        
        matrix_float4x4 mat;
        
        mat = matrix_look_at_right_hand(1, 2, 1, 0, 0, 0, 0, 1, 0);
        
        mtMatrixMode(MTMatrixMode_ModelView);
        mtLoadIdentityf();
        mtRotatef(_rot_angle, 0, 1, 0);
        _rot_angle += 0.01;
        mtMultMatrixf((MTfloat *)&mat);
    }
    else
    {
        mtMatrixMode(MTMatrixMode_ModelView);
        mtLoadIdentityf();
        
        mtMatrixMode(MTMatrixMode_Projection);
        mtLoadIdentityf();
    }
    
    if (_use_depth_testing)
    {
        if (_use_vertex_arrays)
        {
            mtBindVertexArray(0);
        }
        
        mtColor3f(0.2, 0.3, 0.9);
        
        mtBegin(MTPrimitiveTypeTriangleStrip);
        
        mtVertex3f(-1.0, -1.0, 0.5);
        mtVertex3f(-1.0,  1.0, 0.5);
        mtVertex3f( 1.0, -1.0, 0.5);
        mtVertex3f( 1.0,  1.0, 0.5);
        
        mtEnd();

        if (_use_vertex_arrays)
        {
            mtBindVertexArray(_vao);
        }
    }

    switch(_render_primitive)
    {
        case MTPrimitiveTypePoint:
            [self drawPoints];
            break;
            
        case MTPrimitiveTypeLine:
            [self drawLines];
            break;
            
        case MTPrimitiveTypeLineStrip:
            [self drawLineStrip];
            break;
            
        case MTPrimitiveTypeTriangle:
            [self drawTriangles];
            break;
            
        case MTPrimitiveTypeTriangleStrip:
            [self drawTriangleStrips];
            break;
    }
}

- (void)setupVertexArrays
{
    if (_vao)
    {
        mtDeleteVertexArray(_vao);
        _vao = 0;
    }
    
    if (_vertex_buffer)
    {
        mtDeleteBuffer(_vertex_buffer);
        _vertex_buffer = 0;
    }
    
    _vao = mtCreateVertexArray();
    
    mtBindVertexArray(_vao);
    
    // deliberately undersize it to test the resize logic
    _vertex_buffer = mtCreateBuffer(36 * sizeof(Vertex4ColorNormalTex), 0, NULL);
    _index_buffer = mtCreateBuffer(36 * sizeof(MTuint), 0, NULL);

    mtBindVertexBuffer(_vertex_buffer, 0);
    
    mtVertexDesc(0, MTVertexFormatFloat4, 0, 0, sizeof(Vertex4ColorNormalTex), 1, MTVertexStepFunctionPerVertex);
        
    _vertex_array_setup_required = 0;
}

- (void)setupInstancingBuffer
{
    size_t size;
    
    size = MAX_INSTANCES * sizeof(LocalInstanceState);
    
    _instance_state_for_points = newArray(LocalInstanceState, MAX_INSTANCES);
    
    for(int i=0; i<MAX_INSTANCES; i++)
    {
        _instance_state_for_points[i].pos.x = rndfd();
        _instance_state_for_points[i].pos.y = rndfd();
        _instance_state_for_points[i].pos.z = rndfd();
        _instance_state_for_points[i].pos.w = 1.0;

        _instance_state_for_points[i].vel.x = rndfd() * 0.0001;
        _instance_state_for_points[i].vel.y = rndfd() * 0.0001;
        _instance_state_for_points[i].vel.z = rndfd() * 0.0001;
        _instance_state_for_points[i].vel.w = 1.0;
        
        _instance_state_for_points[i].accel.x = rndfd() * 0.01;
        _instance_state_for_points[i].accel.y = rndfd() * 0.01;
        _instance_state_for_points[i].accel.z = rndfd() * 0.01;
        _instance_state_for_points[i].accel.w = 1.0;
        
        _instance_state_for_points[i].rot.x = rndf();
        _instance_state_for_points[i].rot.y = rndf();
        _instance_state_for_points[i].rot.z = rndf();
        _instance_state_for_points[i].rot.w = 1.0;
    }
    
    _instance_buffer_for_points = mtCreateBuffer(size, 0, _instance_state_for_points);
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    if (_vertex_array_setup_required)
    {
        [self setupVertexArrays];
    }
    
    [self drawScene];

    mtFlushToScreen();
}



@end
