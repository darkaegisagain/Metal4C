//
//  x11_colors.h
//  Metal4C
//
//  Created by Michael Larson on 2/19/26.
//

#ifndef x11_colors_h
#define x11_colors_h

#include <stdio.h>

typedef struct {
    unsigned char r, g, b;
    const char *name;
    float fr, fg, fb, fa;
} X11Color;

X11Color *getX11Color(const char *name);

#endif /* x11_colors_h */
