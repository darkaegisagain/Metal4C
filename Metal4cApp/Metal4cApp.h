//
//  Metal4cApp.h
//  Metal4cApp
//
//  Created by Michael Larson on 5/9/26.
//

#include <stdint.h>
#include <stdbool.h>

typedef unsigned int MTuint;
typedef unsigned short MTushort;
typedef bool MTbool;


// the main entry point into the app, once the app is closed this returns
MTuint mtRunApp(MTuint width, MTuint height, const char *name);

// these must be defined by the app
extern void setup(MTuint window);
extern void draw(MTuint window);

// these are optional
extern void update(MTuint window);
extern void resize(MTuint window, MTuint width, MTuint height);
extern void keydown(MTuint window, MTushort keycode, MTuint flags);
extern void keyup(MTuint window, MTushort keycode, MTuint flags);
extern void mousedown(MTuint window, MTuint x, MTuint y);
extern void mouseup(MTuint window, MTuint x, MTuint y);
extern void mousedragged(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy);

// global variables for current state
extern MTuint width, height;
extern MTbool cursor_in_window;
extern MTuint mouse_x;
extern MTuint mouse_y;
extern MTuint prev_mouse_x;
extern MTuint prev_mouse_y;
extern MTushort key;
extern MTuint keycode;
extern MTbool keypressed;

// these allow the handlers to be defined and not found by the app
void mtSetMouseDownHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));
void mtSetMouseUpHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));
void mtSetRightMouseDownHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));
void mtSetRightMouseUpHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));
void mtSetOtherMouseDownHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));
void mtSetOtherMouseUpHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));
void mtSetMouseEnteredHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));
void mtSetMouseExitedHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y));

void mtSetMouseDraggedHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy));
void mtSetRightMouseDraggedHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy));
void mtSetOtherMouseDraggedHandler(MTuint window, void (*mouse_event)(MTuint window, MTuint x, MTuint y, MTuint dx, MTuint dy));

void mtKeyDownHandler(MTuint window, void (*mouse_event)(MTuint window, MTushort keycode, MTuint flags));
void mtKeyUpHandler(MTuint window, void (*mouse_event)(MTuint window, MTushort keycode, MTuint flags));

