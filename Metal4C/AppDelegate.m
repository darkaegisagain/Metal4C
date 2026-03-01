//
//  AppDelegate.m
//  Metal4C
//
//  Created by Michael Larson on 2/10/26.
//

#import "AppDelegate.h"
#import "x11_colors.h"
#import "metal4c.h"

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
    IBOutlet M4CView            *_m4c_view;
    IBOutlet NSPopUpButton      *_draw_type_popup_button;
    IBOutlet NSButton           *_enable_color;
    IBOutlet NSButton           *_enable_texture;
    IBOutlet NSButton           *_enable_normals;
    IBOutlet NSButton           *_enable_3D_view;
    
    IBOutlet NSColorWell        *_clear_color_well;
    
    MTRenderContext             _ctx;
    Renderer                    *_renderer;
    
    vector_uint2                _viewportSize;
    
    MTuint                      _textures[8];
    
    MTuint                      _render_primitive;
    MTuint                      _render_mode_bitmask;
    
    MTuint                      _shader_lib;
}

- (void)initM4CView
{
    _ctx = mtCreateContext();
    assert(_ctx);
    
    mtSetCurrentContext(_ctx);
    
    _renderer = [[Renderer alloc] initWithMTKView: _m4c_view context:_ctx];
    assert(_renderer);
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
        {@"point", PrimitiveTypePoint},
        {@"line", PrimitiveTypeLine},
        {@"linestrip", PrimitiveTypeLine},
        {@"triangle", PrimitiveTypeTriangle},
        {@"trianglestrip", PrimitiveTypeTriangleStrip},
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
    
    _render_primitive = (MTuint)[_draw_type_popup_button tag];
    
    [_clear_color_well setAction:@selector(colorWellClick:)];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    assert(_m4c_view);
    assert(_draw_type_popup_button);
    assert(_enable_color);
    assert(_enable_texture);
    assert(_enable_normals);
    assert(_enable_3D_view);
    assert(_clear_color_well);
    
    [_m4c_view setDelegate: self];
    
    [self initM4CView];
    [self initUI];
    
    //_textures[0] = mtCreateTextureFromFile("/tmp/Lenna_test_image.png");
    //_textures[0] = mtCreateTextureFromFile("/Users/milarson/Projects/Metal4C/Metal4C/Lenna_test_image.png");
    _textures[0] = mtCreateTextureFromFile("Lenna_test_image.png");
        
    // mtSetRendermode(kRendermodeTex);
    mtSetRendermode(kRendermodeColor);
    
    NSRect frame;
    frame = [_m4c_view frame];
    
    NSSize size;
    size = frame.size;
    
    NSScreen *screen;
    screen = [NSScreen mainScreen];
    
    float scale;
    scale = [screen backingScaleFactor];
    
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width * scale;
    _viewportSize.y = size.height * scale;
    
    mtSetViewport(0, 0, _viewportSize.x, _viewportSize.y);
    
    // set clear to gray
    MTColor color;
    color = [self getColorByName:"grey"];
    mtClearColor(color.r, color.g, color.b, color.a);
    
    _render_mode_bitmask = RENDER_COLOR_BIT;
    
    NSURL *shader_url;
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    shader_url = [mainBundle URLForResource:@"LocalShaders" withExtension:@"mtl"];
    
    if (shader_url)
    {
        NSError *error = nil;
        NSString *fileContents = [NSString stringWithContentsOfURL:shader_url encoding:NSUTF8StringEncoding error:&error];
        
        _shader_lib = mtCreateShaderLibrary([fileContents cStringUsingEncoding:NSUTF8StringEncoding]);
        assert(_shader_lib);
        
        // bind a a bad unit
        mtBindShaderFunctions(0, NULL, NULL, kRendermodeMax + 1);
        
        // check for log warnings as these are not in the library
        mtBindShaderFunctions(_shader_lib, "vertexShaderNormal", "fragmentShaderNormal", kRendermodeNormal);
        
        // bind a null shader function to reset to default
        mtBindShaderFunctions(0, NULL, NULL, kRendermodeNormal);
        
        // bind this shader to normal render mode
        mtBindShaderFunctions(_shader_lib, "vertexShaderNormalLocal", "fragmentShaderNormalLocal", kRendermodeNormal);
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
    
    frame = [_m4c_view frame];
    
    *width = frame.size.width * scale;
    *height = frame.size.height * scale;
}

- (MTColor)getColorByName:(const char *)name
{
    X11Color *x11_color;
    
    x11_color = getX11Color(name);
    
    if (x11_color)
    {
        return simd_make_float4(x11_color->fr, x11_color->fg, x11_color->fb, 1.0);
    }
    
    NSLog(@"error finding color %s\n", name);
    
    return simd_make_float4(0.0, 0.0, 0.0, 0.0);
}

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

void submitRandomPoint(MTuint render_mode, float width, float height)
{
    if (render_mode & RENDER_MODE_COLOR)
    {
        mtColorf(rndf(), rndf(), rndf(), 1.0);
    }
    
    if (render_mode & RENDER_MODE_TEX)
    {
        mtTexf(rndf(), rndf());
    }
    
    if (render_mode & RENDER_MODE_NORMAL)
    {
        mtNormalf(rndf(), rndf(), rndf());
    }
    
    mtVertex4f(rndfr(width), rndfr(height), 0.0, 0.0);
}

- (void)drawPoints
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    mtSetPointSize(4.0);
    
    mtBegin(PrimitiveTypePoint);
    
    for(int i=0; i<100; i++)
    {
        submitRandomPoint(_render_mode_bitmask, width, height);
    }
    
    mtEnd();
}

- (void)drawLines
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    mtBegin(PrimitiveTypeLine);
    
    for(int i=0; i<100; i++)
    {
        submitRandomPoint(_render_mode_bitmask, width, height);

        submitRandomPoint(_render_mode_bitmask, width, height);
    }
    
    mtEnd();
}

- (void)drawLineStrip
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    submitRandomPoint(_render_mode_bitmask, width, height);
    mtBegin(PrimitiveTypeLineStrip);
    
    for(int i=0; i<100; i++)
    {
        submitRandomPoint(_render_mode_bitmask, width, height);
    }
    
    mtEnd();
}

- (void)drawTriangles
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    mtBegin(PrimitiveTypeTriangle);
    
    for(int i=0; i<100; i++)
    {
        submitRandomPoint(_render_mode_bitmask, width, height);

        submitRandomPoint(_render_mode_bitmask, width, height);

        submitRandomPoint(_render_mode_bitmask, width, height);
    }
    
    mtEnd();
}

- (void)drawTriangleStrips
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];

    mtBegin(PrimitiveTypeTriangle);
    
    submitRandomPoint(_render_mode_bitmask, width, height);

    for(int i=0; i<100; i++)
    {
        submitRandomPoint(_render_mode_bitmask, width, height);

        submitRandomPoint(_render_mode_bitmask, width, height);
    }
    
    mtEnd();
}


- (void)drawScene
{
    uint32_t  width, height;
    
    [self getViewportWidth:&width Height:&height];
    
    mtClear(MT_CLEAR_COLOR_BUFFER);

#if 0
    int iModelViewLoc = glGetUniformLocation(spMain.getProgramID(), "modelViewMatrix");
        int iProjectionLoc = glGetUniformLocation(spMain.getProgramID(), "projectionMatrix");
        glUniformMatrix4fv(iProjectionLoc, 1, GL_FALSE, glm::value_ptr(*oglControl->getProjectionMatrix()));

        glm::mat4 mModelView = glm::lookAt(glm::vec3(0, 15, 40), glm::vec3(0.0f), glm::vec3(0.0f, 1.0f, 0.0f));

        // Render rotating pyramid in the middle

        glm::mat4 mCurrent = glm::rotate(mModelView, fRotationAngle, glm::vec3(0.0f, 1.0f, 0.0f));
        glUniformMatrix4fv(iModelViewLoc, 1, GL_FALSE, glm::value_ptr(mCurrent));
        glDrawArrays(GL_TRIANGLES, 0, 12);
#endif
    

    switch(_render_primitive)
    {
        case PrimitiveTypePoint:
            [self drawPoints];
            break;
            
        case PrimitiveTypeLine:
            [self drawLines];
            break;

        case PrimitiveTypeLineStrip:
            [self drawLineStrip];
            break;

        case PrimitiveTypeTriangle:
            [self drawTriangles];
            break;

        case PrimitiveTypeTriangleStrip:
            [self drawTriangleStrips];
            break;

    }
    
#if 0
    mtBegin(PrimitiveTypeTriangleStrip);
    
    // lower left
    mtColorf(0.0, 1.0, 0.0, 1.0);
    mtTexf(0.0, 0.0);
    mtVertex4f(0, height, 0.0, 0.0);

    mtColorf(0.0, 0.0, 1.0, 1.0);
    mtTexf(0.0, 1.0);
    mtVertex4f(width, height, 0.0, 0.0);

    mtColorf(1.0, 0.0, 0.0, 1.0);
    mtTexf(1.0, 1.0);
    mtVertex4f(0.0, 0.0, 0.0, 0.0);

#if 0
    // upper right
    mtColorf(1.0, 0.0, 0.0, 1.0);
    mtTexf(0.0, 1.0);
    mtVertex4f(0.0, 0.0, 0.0, 0.0);

    mtColorf(0.0, 1.0, 0.0, 1.0);
    mtTexf(1.0, 1.0);
    mtVertex4f(width, height, 0.0, 0.0);
#endif
    
    mtColorf(0.0, 0.0, 1.0, 1.0);
    mtTexf(1.0, 0.0);
    mtVertex4f(width, 0.0, 0.0, 0.0);
    
    mtEnd();
#endif
    
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    [self drawScene];

    [_renderer flushToScreen];
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
    else if (button == _enable_texture)
    {
        [self setClearRendermodeBit:RENDER_TEXTURE_BIT setClear:[_enable_texture state]];
    }
    else if (button == _enable_normals)
    {
        [self setClearRendermodeBit:RENDER_NORMAL_BIT setClear:[_enable_normals state]];
    }
    else if (button == _enable_3D_view)
    {
        [self setClearRendermodeBit:RENDER_COLOR_BIT setClear:[_enable_3D_view state]];
    }
    else
    {
        assert(0);
    }
    
    switch(_render_mode_bitmask)
    {
        case RENDER_COLOR_BIT:
            mtSetRendermode(kRendermodeColor);
            break;
            
        case RENDER_COLOR_BIT | RENDER_TEXTURE_BIT:
            mtSetRendermode(kRendermodeColorTex);
            break;
            
        case RENDER_COLOR_BIT | RENDER_NORMAL_BIT:
            mtSetRendermode(kRendermodeColorNormal);
            break;
            
        case RENDER_COLOR_BIT | RENDER_TEXTURE_BIT | RENDER_NORMAL_BIT:
            mtSetRendermode(kRendermodeColorTexNormal);
            break;
            
        case RENDER_TEXTURE_BIT:
            mtSetRendermode(kRendermodeTex);
            break;
            
        case RENDER_TEXTURE_BIT | RENDER_NORMAL_BIT:
            mtSetRendermode(kRendermodeTexNormal);
            break;
            
        case RENDER_NORMAL_BIT:
            mtSetRendermode(kRendermodeNormal);
            break;
            
        default:
            printf("Unknown rendermode, setting to color");
            mtSetRendermode(kRendermodeColor);
            break;
    }
    
    if (_render_mode_bitmask & RENDER_TEXTURE_BIT)
    {
        mtBindFragmentTexture(_textures[0], 0);
    }
    else
    {
        mtBindFragmentTexture(0, 0);
    }
}

- (void)colorWellClick:(nullable id)sender
{
    NSColorWell *well;
    
    well = sender;
    
    if (well == _clear_color_well)
    {
        NSColor *color;
        
        color = [_clear_color_well color];
        
        float r, g, b, a;
        
        r = [color redComponent];
        g = [color greenComponent];
        b = [color blueComponent];
        a = [color alphaComponent];
        
        mtClearColor(r, g, b, a);
    }
    else
    {
        assert(0);
    }
}
@end
