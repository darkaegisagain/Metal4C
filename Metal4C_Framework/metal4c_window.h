//
//  metal4c_window.h
//  Metal4C
//
//  Created by Michael Larson on 5/7/26.
//



#include <stdint.h>
#include <stdbool.h>

#include <Metal4c/metal4c.h>

@interface Metal4cView : MTKView
    @property NSTrackingArea *trackingArea;
    @property MTuint mt_window;
    @property void (*mouse_down)(MTuint window, MTuint x, MTuint y);
    @property void (*right_mouse_down)(MTuint window, MTuint x, MTuint y);
    @property void (*other_mouse_down)(MTuint window, MTuint x, MTuint y);

    @property void (*mouse_up)(MTuint window, MTuint x, MTuint y);
    @property void (*right_mouse_up)(MTuint window, MTuint x, MTuint y);
    @property void (*other_mouse_up)(MTuint window, MTuint x, MTuint y);

    @property void (*mouse_moved)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy);
    @property void (*mouse_dragged)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy);

    @property void (*right_mouse_dragged)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy);
    @property void (*other_mouse_dragged)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy);

    @property void (*mouse_entered)(MTuint window, MTuint x, MTuint y);
    @property void (*mouse_exited)(MTuint window, MTuint x, MTuint y);

    @property void (*keydown)(MTuint window, MTushort keycode, MTuint flags);
    @property void (*keyup)(MTuint window, MTushort keycode, MTuint flags);
@end


@interface Metal4cWindow : NSObject <MTKViewDelegate>
    @property NSWindow          *window;
    @property Metal4cView       *view;
    @property id<MTLDevice>     device;
    @property MTRenderContext   ctx;

    @property void (*update)(MTuint window);
    @property void (*draw)(MTuint window);
    @property void (*resize)(MTuint window, MTuint width, MTuint height);

-(Metal4cWindow *)initWithFrame:(NSRect) frame title:(const char *)title;
@end


MTuint mtCreateWindow(MTuint width, MTuint height, const char *name);

Metal4cView *mtGetViewPtr(MTuint window);

Metal4cWindow *mtGetWindowPtr(MTuint window);
