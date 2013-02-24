#ifndef VecXGL_SDLStubs_h
#define VecXGL_SDLStubs_h

#import <OpenGL/gl.h>
#import <GLUT/GLUT.h>
#include <stdio.h>
#include <stdint.h>

typedef struct{
    int freq;
    uint16_t format;
    uint8_t channels;
    uint8_t silence;
    uint16_t samples;
    uint32_t size;
    void (*callback)(void *userdata, uint8_t *stream, int len);
    void *userdata;
} SDL_AudioSpec;

void SDL_GL_SwapBuffers(void);

#endif
