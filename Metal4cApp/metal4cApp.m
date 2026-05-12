//
//  metal4c_window.m
//  Metal4c
//
//  Created by Michael Larson on 5/7/26.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#include <dlfcn.h>

#include "metal4c.h"
#include "metal4c_context.h"
#include "metal4c_Renderer_Extern.h"
#include "metal4c_hash_table.h"
#include "metal4c_window.h"

NS_ASSUME_NONNULL_BEGIN

@interface MtAppDelegate : NSObject <NSApplicationDelegate>
    @property MTuint width, height;
    @property const char *title;
    @property MTuint mt_window;
    @property MTRenderContext ctx;
    @property void (*setup)(MTuint window);
    @property void (*update)(MTuint window);
    @property void (*draw)(MTuint window);
    @property void (*resize)(MTuint window, MTuint width, MTuint height);
    @property void (*keydown)(MTuint window, MTushort keycode, MTuint flags);
    @property void (*keyup)(MTuint window, MTushort keycode, MTuint flags);
    @property void (*mousedown)(MTuint window, MTuint x, MTuint y);
    @property void (*mouseup)(MTuint window, MTuint x, MTuint y);
    @property void (*mousedragged)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy);
@end

@implementation MtAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSMenu *menubar = [[NSMenu alloc] init];
    [NSApp setMainMenu:menubar];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *closeItem =
        [[NSMenuItem alloc] initWithTitle:@"Close"
                                  action:@selector(performClose:)
                           keyEquivalent:@"w"];

    [appMenu addItem:closeItem];

    NSMenuItem *quitItem =
        [[NSMenuItem alloc] initWithTitle:@"Quit"
                                  action:@selector(performClose:)
                           keyEquivalent:@"q"];

    [appMenu addItem:quitItem];
    
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    _mt_window = mtCreateWindow(_width, _height, _title);
    
    Metal4cWindow *win;
    
    win = mtGetWindowPtr(_mt_window);
    assert(win);

    // copy default handlers if defined in user code
    win.update  = _update;
    win.draw    = _draw;
    win.resize  = _resize;
    
    Metal4cView *view;
    
    view = mtGetViewPtr(_mt_window);
    assert(view);

    {
        MTbool res;
        
        res = mtBindMTKView((__bridge void *)(view));
        assert(res);

        // copy these from the delegate
        view.mt_window      = _mt_window;
        
        // copy default handlers if defined in user code
        view.keyup          = _keyup;
        view.keydown        = _keydown;
        view.mouse_up       = _mouseup;
        view.mouse_down     = _mousedown;
        view.mouse_dragged  = _mousedragged;

        [view setDelegate: win];
    }
    
    if (_setup)
    {
        _setup(_mt_window);
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end

MTuint mtRunApp(MTuint width, MTuint height, const char *title)
{
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];

        MtAppDelegate *delegate = [MtAppDelegate new];

        delegate.width = width;
        delegate.height = height;
        if (title)
        {
            delegate.title = strdup(title);
        }

        [app setDelegate:delegate];
        
        void (*fn)(MTuint);
        
        fn = dlsym(RTLD_DEFAULT, "setup");

        if (fn)
        {
            delegate.setup = fn;
        }
        else
        {
            printf("Error: no setup function found\n");
            return 1;
        }
        
        fn = dlsym(RTLD_DEFAULT, "update");

        if (fn)
        {
            delegate.update = fn;
        }
        
        fn = dlsym(RTLD_DEFAULT, "draw");

        if (fn)
        {
            delegate.draw = fn;
        }
        else
        {
            printf("Error: no draw function found\n");
            return 2;
        }

        void (*resize)(MTuint, MTuint, MTuint);

        resize = dlsym(RTLD_DEFAULT, "resize");

        if (resize)
        {
            delegate.resize = resize;
        }

        void (*keydown)(MTuint window, MTushort keycode, MTuint flags);
        
        keydown = dlsym(RTLD_DEFAULT, "keydown");

        if (keydown)
        {
            delegate.keydown = keydown;
        }

        void (*keyup)(MTuint window, MTushort keycode, MTuint flags);
        
        keyup = dlsym(RTLD_DEFAULT, "keyup");

        if (keyup)
        {
            delegate.keyup = keyup;
        }

        void (*mousedown)(MTuint window, MTuint x, MTuint y);
        
        mousedown = dlsym(RTLD_DEFAULT, "mousedown");

        if (mousedown)
        {
            delegate.mousedown = mousedown;
        }

        void (*mouseup)(MTuint window, MTuint x, MTuint y);
        
        mouseup = dlsym(RTLD_DEFAULT, "mouseup");

        if (mouseup)
        {
            delegate.mouseup = mouseup;
        }

        void (*mousedragged)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy);
        
        mousedragged = dlsym(RTLD_DEFAULT, "mousedragged");

        if (mousedragged)
        {
            delegate.mousedragged = mousedragged;
        }

        [app run];   // 🔥 required run loop
    }

    return 0;
}

void setLocationHandler(MTuint window, MTuint type, void (*handler)(MTuint window, MTuint x, MTuint y))
{
    Metal4cView *view;
    
    view = mtGetViewPtr(window);

    if (view)
    {
        switch(type)
        {
            case NSEventTypeLeftMouseDown:
                view.mouse_down = handler;
                break;
                
            case NSEventTypeLeftMouseUp:
                view.mouse_up = handler;
                break;
                
            case NSEventTypeRightMouseDown:
                view.right_mouse_down = handler;
                break;
                
            case NSEventTypeRightMouseUp:
                view.right_mouse_up = handler;
                break;
                
            case NSEventTypeOtherMouseDown:
                view.other_mouse_down = handler;
                break;
                
            case NSEventTypeOtherMouseUp:
                view.other_mouse_up = handler;
                break;
                
            case NSEventTypeMouseEntered:
                view.mouse_entered = handler;
                break;
                
            case NSEventTypeMouseExited:
                view.mouse_exited = handler;
                break;
                
            default:
                assert(0);
        }
    }
}

void setDraggedHandler(MTuint window, MTuint type, void (*handler)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy))
{
    Metal4cView *view;
    
    view = mtGetViewPtr(window);
    
    if (view)
    {
        switch(type)
        {
            case NSEventTypeLeftMouseDragged:
                view.mouse_dragged = handler;
                break;
                
            case NSEventTypeRightMouseDragged:
                view.right_mouse_dragged = handler;
                break;
                
            case NSEventTypeOtherMouseDragged:
                view.other_mouse_dragged = handler;
                break;
                
            default:
                assert(0);
        }
    }
}

void setKeyHandler(MTuint window, MTuint type, void (*handler)(MTuint window, MTushort keycode, MTuint flags))
{
    Metal4cView *view;
    
    view = mtGetViewPtr(window);
    
    if (view)
    {
        switch(type)
        {
            case NSEventTypeKeyDown:
                view.keydown = handler;
                break;
                
            case NSEventTypeKeyUp:
                view.keyup = handler;
                break;
                
            default:
                assert(0);
        }
    }
}

#define SET_LOCATION_HANDLER(_func, _type) \
void _func(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y)) \
{ \
    setLocationHandler(window, _type, mouse_event); \
}

SET_LOCATION_HANDLER(mtSetMouseDownHandler, NSEventTypeLeftMouseDown)
SET_LOCATION_HANDLER(mtSetMouseUpHandler, NSEventTypeLeftMouseUp)
SET_LOCATION_HANDLER(mtSetRightMouseDownHandler, NSEventTypeRightMouseDown)
SET_LOCATION_HANDLER(mtSetRightMouseUpHandler, NSEventTypeRightMouseUp)
SET_LOCATION_HANDLER(mtSetOtherMouseDownHandler, NSEventTypeOtherMouseDown)
SET_LOCATION_HANDLER(mtSetOtherMouseUpHandler, NSEventTypeOtherMouseUp)
SET_LOCATION_HANDLER(mtSetMouseEnteredHandler, NSEventTypeMouseEntered)
SET_LOCATION_HANDLER(mtSetMouseExitedHandler, NSEventTypeMouseExited)

#define SET_DRAGGED_HANDLER(_func, _type) \
void _func(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy)) \
{ \
    setDraggedHandler(window, _type, mouse_event); \
}

SET_DRAGGED_HANDLER(mtSetMouseDraggedHandler, NSEventTypeLeftMouseDragged)
SET_DRAGGED_HANDLER(mtSetRightMouseDraggedHandler, NSEventTypeRightMouseDragged)
SET_DRAGGED_HANDLER(mtSetOtherMouseDraggedHandler, NSEventTypeOtherMouseDragged)

#define SET_KEYCODE_HANDLER(_func, _type) \
void _func(MTuint window, void (*mouse_event)(MTuint window, MTushort keycode, MTuint flags)) \
{ \
    setKeyHandler(window, _type, mouse_event); \
}

SET_KEYCODE_HANDLER(mtKeyDownHandler, NSEventTypeKeyDown)
SET_KEYCODE_HANDLER(mtKeyUpHandler, NSEventTypeKeyUp)

NS_ASSUME_NONNULL_END
