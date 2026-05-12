//
//  metal4c_window.m
//  Metal4c
//
//  Created by Michael Larson on 5/9/26.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#include <dlfcn.h>

#include "metal4c.h"
#include "metal4c_context.h"
#include "metal4c_Renderer_Extern.h"
#include "metal4c_hash_table.h"

#import "metal4c_window.h"

NS_ASSUME_NONNULL_BEGIN

static HashTable *gWindowTable = NULL;

// globals used by metal4cApp
MTuint cursor_in_window = false;
MTuint mouse_x;
MTuint mouse_y;
MTuint prev_mouse_x;
MTuint prev_mouse_y;
MTushort key;
MTuint keycode;


@interface Metal4cView()

@end

#define MOUSE_LOCATION(_handler) \
do { \
    NSPoint loc; \
    \
    loc = [self convertPoint:[event locationInWindow] fromView:nil]; \
    \
    prev_mouse_x = mouse_x; \
    prev_mouse_y = mouse_y; \
    mouse_x = loc.x; \
    mouse_y = loc.y; \
    \
    if(_handler) \
    { \
        _handler(_mt_window, loc.x, loc.y); \
    } \
} while(0)

#define MOUSE_DELTA(_handler) \
do { \
    NSPoint loc; \
    \
    loc = [self convertPoint:[event locationInWindow] fromView:nil]; \
    \
    prev_mouse_x = mouse_x; \
    prev_mouse_y = mouse_y; \
    mouse_x = loc.x; \
    mouse_y = loc.y; \
    \
    if(_handler) \
    { \
        _handler(_mt_window, loc.x, loc.y, event.deltaX, event.deltaY); \
    } \
} while(0)

@implementation Metal4cView
- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    if (_trackingArea)
    {
        [self removeTrackingArea:_trackingArea];
    }

    NSTrackingAreaOptions options =
        NSTrackingMouseEnteredAndExited |
        NSTrackingActiveInKeyWindow |
        NSTrackingMouseMoved |
        NSTrackingActiveInKeyWindow |
        NSTrackingInVisibleRect;

    _trackingArea = [[NSTrackingArea alloc]
        initWithRect:NSZeroRect
             options:options
               owner:self
            userInfo:nil];

    [self addTrackingArea:_trackingArea];
}

- (void)mouseDown:(NSEvent *)event
{
    MOUSE_LOCATION(_mouse_down);
}

- (void)rightMouseDown:(NSEvent *)event
{
    MOUSE_LOCATION(_right_mouse_down);
}

- (void)otherMouseDown:(NSEvent *)event
{
    MOUSE_LOCATION(_other_mouse_down);
}

-(void)mouseUp:(NSEvent *)event
{
    MOUSE_LOCATION(_mouse_up);
}

- (void)rightMouseUp:(NSEvent *)event
{
    MOUSE_LOCATION(_right_mouse_up);
}

- (void)otherMouseUp:(NSEvent *)event
{
    MOUSE_LOCATION(_other_mouse_up);
}

- (void)mouseMoved:(NSEvent *)event
{
    MOUSE_DELTA(_mouse_moved);
}

- (void)mouseDragged:(NSEvent *)event
{
    MOUSE_DELTA(_mouse_dragged);
}

- (void)rightMouseDragged:(NSEvent *)event
{
    MOUSE_DELTA(_right_mouse_dragged);
}

- (void)otherMouseDragged:(NSEvent *)event
{
    MOUSE_DELTA(_other_mouse_dragged);
}

- (void)mouseEntered:(NSEvent *)event
{
    cursor_in_window = true;
    MOUSE_LOCATION(_mouse_entered);
}

- (void)mouseExited:(NSEvent *)event
{
    cursor_in_window = false;
    MOUSE_LOCATION(_mouse_exited);
}

- (void)keyDown:(NSEvent *)event
{
    key = event.keyCode;
    
    NSEventModifierFlags flags;
    
    flags = event.modifierFlags;

    // the global var keycode is set on keydown
    keycode = ((MTuint)flags << 16) | (MTuint)key;
    
    if(_keydown)
    {
        _keydown(_mt_window, keycode, (MTuint)flags);
    }
    
    [super keyDown:event];
}

- (void)keyUp:(NSEvent *)event
{
    if(_keyup)
    {
        unsigned short keycode;
        
        keycode = event.keyCode;
        
        NSEventModifierFlags flags;
        
        flags = event.modifierFlags;
        
        _keyup(_mt_window, keycode, (MTuint)flags);
    }
    
    [super keyUp:event];
}

@end


@implementation Metal4cWindow

-(Metal4cWindow *) initWithFrame:(NSRect) frame title:(const char *)title
{
    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:(NSWindowStyleMaskTitled |
                                                     NSWindowStyleMaskClosable |
                                                     NSWindowStyleMaskResizable)
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    
    _device = MTLCreateSystemDefaultDevice();
    
    [_window setTitle:[NSString stringWithUTF8String:title]];
    [_window makeKeyAndOrderFront:nil];
    [_window setAcceptsMouseMovedEvents:YES];
    
    // Create Metal4cView
    _view = [[Metal4cView alloc] initWithFrame:frame device:_device];
    _view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    [_window setContentView:_view];
    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    _ctx = mtCreateContext();
    assert(_ctx);
    
    mtSetCurrentContext(_ctx);
    
    return self;
}

- (void)drawInMTKView:(MTKView *)view
{
    Metal4cView *m4cview;
    
    m4cview = (Metal4cView *)view;
    
    if (_update)
    {
        _update(m4cview.mt_window);
    }
    
    if (_draw)
    {
        _draw(m4cview.mt_window);
        
        mtFlushToScreen();
    }
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    Metal4cView *m4cview;
    
    m4cview = (Metal4cView *)view;

    if (_resize)
    {
        _resize(m4cview.mt_window, (MTuint)size.width, (MTuint)size.height);
    }
}
@end



MTuint mtCreateWindow(MTuint width, MTuint height, const char *title)
{
    if (gWindowTable == NULL)
    {
        gWindowTable = newPtr(HashTable);
        
        initHashTable(gWindowTable, 32);
    }
    
    if (![NSApplication sharedApplication])
    {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    
    MTuint window;
    
    window = getNewName(gWindowTable);
    
    NSScreen *screen = [NSScreen mainScreen];
    NSRect vf = [screen visibleFrame];

    NSRect frame = NSMakeRect(
        vf.origin.x + 10,
        vf.origin.y + vf.size.height - height,
        width,
        height
    );
    
    Metal4cWindow *win;
    
    win = [[Metal4cWindow alloc] initWithFrame: frame title:title];
    
    insertHashElement(gWindowTable, window, (void *)CFBridgingRetain(win));

    return window;
}

Metal4cWindow *mtGetWindowPtr(MTuint window)
{
    Metal4cWindow *m4cwin;
    
    m4cwin = (__bridge Metal4cWindow *)getKeyData(gWindowTable, window);
    
    return m4cwin;
}

Metal4cView *mtGetViewPtr(MTuint window)
{
    Metal4cWindow *m4cwin;
    
    m4cwin = mtGetWindowPtr(window);
        
    if (m4cwin == NULL)
    {
        return NULL;
    }
    
    return [m4cwin view];
}


NS_ASSUME_NONNULL_END
