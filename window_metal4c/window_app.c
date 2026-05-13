//
//  main.c
//  window_metal4c
//
//  Created by Michael Larson on 5/7/26.
//

#include <stdlib.h>
#include <stdio.h>
#include <Metal4c/metal4c.h>
#include <Metal4cApp/metal4cApp.h>

#define USE_DEFAULT_HANDLERS 1

void mouseDownHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void mouseUpHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void rightMouseDownHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void rightMouseUpHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void otherMouseDownHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void otherMouseUpHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void mouseEnteredHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void mouseExitHandler(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void mouseDraggedHandler(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy)
{
    printf("%s window: %d x,y: %d, %d dx,dy: %d, %d\n", __FUNCTION__, window, x, y, dx, dy);
}

void rightMouseDraggedHandler(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy)
{
    printf("%s window: %d x,y: %d, %d dx,dy: %d, %d\n", __FUNCTION__, window, x, y, dx, dy);
}

void otherMouseDraggedHandler(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy)
{
    printf("%s window: %d x,y: %d, %d dx,dy: %d, %d\n", __FUNCTION__, window, x, y, dx, dy);
}

void keyDownHandler(MTuint window, MTushort keycode, MTuint flags)
{
    printf("%s window: %d keycode: %d flags:%d\n", __FUNCTION__, window, keycode, flags);
}

void keyUpHandler(MTuint window, MTushort keycode, MTuint flags)
{
    printf("%s window: %d keycode: %d flags:%d\n", __FUNCTION__, window, keycode, flags);
}

void setup(MTuint window)
{
    mtSetRendermode(MTVertexShaderModeNonInstanced, MTFragmentShaderModeColor);
    
#if USE_DEFAULT_HANDLERS == 0
    mtSetMouseDownHandler(window, mouseDownHandler);
    mtSetMouseUpHandler(window, mouseUpHandler);

    mtSetMouseDraggedHandler(window, mouseDraggedHandler);
    mtKeyDownHandler(window, keyDownHandler);
    mtKeyUpHandler(window, keyUpHandler);
#endif // USE_DEFAULT_HANDLERS == 0
    
    mtSetRightMouseDownHandler(window, rightMouseDownHandler);
    mtSetRightMouseUpHandler(window, rightMouseUpHandler);
    mtSetOtherMouseDownHandler(window, otherMouseDownHandler);
    mtSetOtherMouseUpHandler(window, otherMouseUpHandler);
    mtSetMouseEnteredHandler(window, mouseEnteredHandler);
    mtSetMouseExitedHandler(window, mouseExitHandler);
    
    mtSetRightMouseDraggedHandler(window, rightMouseDraggedHandler);
    mtSetOtherMouseDraggedHandler(window, otherMouseDraggedHandler);
}

void update(MTuint window)
{
    if(cursor_in_window)
    {
        printf("current mouse x,y: %d,%d\n", mouse_x, mouse_y);
    }
}

void draw(MTuint window)
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
}

void resize(MTuint window, MTuint width, MTuint height)
{
    mtSetViewport(0, 0, width, height);
}

#if USE_DEFAULT_HANDLERS == 1
void keydown(MTuint window, MTushort keycode, MTuint flags)
{
    printf("%s window: %d keycode: %d flags:%d\n", __FUNCTION__, window, keycode, flags);
}

void keyup(MTuint window, MTushort keycode, MTuint flags)
{
    printf("%s window: %d keycode: %d flags:%d\n", __FUNCTION__, window, keycode, flags);
}

void mousedown(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void mouseup(MTuint window, MTuint x, MTuint y)
{
    printf("%s window: %d x,y: %d, %d\n", __FUNCTION__, window, x, y);
}

void mousedragged(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy)
{
    printf("%s window: %d x,y: %d, %d dx,dy: %d, %d\n", __FUNCTION__, window, x, y, dx, dy);
}
#endif // USE_DEFAULT_HANDLERS == 1

int main(int argc, const char * argv[])
{
    return mtRunApp(512, 512, "test mtRunApp");
}
