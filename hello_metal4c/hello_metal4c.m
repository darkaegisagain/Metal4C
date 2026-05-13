//
//  main.c
//  hello_metal4c
//
//  Created by Michael Larson on 5/3/26.
//

#include <stdlib.h>
#include <stdio.h>
#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import <Metal4c/metal4c.h>
#import <Metal4c/metal4c_types.h>


@interface AppDelegate : NSObject <NSApplicationDelegate, MTKViewDelegate>
@property (strong) NSWindow *window;
@property (strong) MTKView *mtkView;
@property MTRenderContext ctx;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    // Create window
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"Metal4c Test"];
    [self.window makeKeyAndOrderFront:nil];
    
    // Create MTKView
    self.mtkView = [[MTKView alloc] initWithFrame:frame device:MTLCreateSystemDefaultDevice()];
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0.1, 0.2, 0.3, 1.0);
    
    [self.window setContentView:self.mtkView];
    
    _ctx = mtCreateContext();
    assert(_ctx);
    
    mtSetCurrentContext(_ctx);
    
    MTbool res;
    
    res = mtBindMTKView((__bridge void *)(_mtkView));
    assert(res);

    mtSetRendermode(MTVertexShaderModeNonInstanced, MTFragmentShaderModeColor);
        
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(MTKView *)view
{
    mtClearColor(0, 0, 0, 1.0);
    mtClear(MT_CLEAR_COLOR_BUFFER);
    
    mtBegin(MTPrimitiveTypeTriangle);
    
    mtColor3f(1, 0, 0);
    mtVertex2f(-0.3, 0.5);
    
    mtColor3f(0, 1, 0);
    mtVertex2f(0.5, 0);

    mtColor3f(0, 0, 1);
    mtVertex2f(0.25, -0.75);

    mtEnd();
    
    mtFlushToScreen();
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    
}

@end

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];

        AppDelegate *delegate = [AppDelegate new];
        [app setDelegate:delegate];

        [app run];   // 🔥 required run loop
    }
    return 0;
}
