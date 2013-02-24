#include "SDLStubs.h"
#import "VectrexGameCore.h"

void SDL_GL_SwapBuffers(void)
{
    [g_core swapBuffers];
    [g_core videoInterrupt];
}