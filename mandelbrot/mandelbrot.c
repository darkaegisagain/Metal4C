//
//  main.c
//  mandelbrot
//
//  Created by Michael Larson on 5/12/26.
//

#include <stdlib.h>
#include <stdio.h>

#include <Metal4cApp/Metal4cApp.h>
#include <Metal4c/Metal4c.h>

#include "mandelbrot_types.h"

MTuint vao;
MTuint vertex_buffer;
MTuint uniform_buffer;
MTuint null_texture;
MTuint shader_lib;

void setup(MTuint window)
{
    mtSetRendermode(MTVertexShaderModeNonInstanced, MTFragmentShaderModeTexture);
    
    mtClearColor(0,0,0,0);
    
    vertex_buffer = mtCreateBuffer(4 * sizeof(MandelbrotVertex), 0, NULL);
    uniform_buffer = mtCreateBuffer(sizeof(MBUniform), 0, NULL);
    
    null_texture = mtCreateTexture2D(MTPixelFormatRGBA8Unorm, width, height, false, 0, NULL);
    
    shader_lib =  mtCreateShaderLibraryFromFile("mandelbrot_shader.metal");
    
    vao = mtCreateVertexArray();
    
    mtBindVertexArray(vao);
    
    mtBindVertexBuffer(vertex_buffer, 0);

    mtBindFragmentBuffer(uniform_buffer, 0);
}

void draw(MTuint window)
{
    mtClear(MT_CLEAR_COLOR_BUFFER);
}


int main(int argc, const char * argv[])
{
    return mtRunApp(1200, 1024, "Mandelbrot");
}
