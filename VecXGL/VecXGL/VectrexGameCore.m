/*
 Copyright (c) 2010 OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// We need to mess with core internals

#import "VectrexGameCore.h"

#import <OpenEmuBase/OERingBuffer.h>
#import <OpenGL/gl.h>
#import "vecx.h"
#import "osint.h"

@interface VectrexGameCore () <OEVectrexSystemResponderClient>
{
    int videoWidth, videoHeight;
    double sampleRate;
}
@end

VectrexGameCore *g_core;

@implementation VectrexGameCore


- (id)init
{
    if (self = [super init]) {        
        videoWidth = 330;
        videoHeight = 410;
        sampleRate = 22050;
    }
    
    g_core = self;
    return self;
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    osint_defaults();           //setup defaults
    openCart([path UTF8String]);
    osint_gencolors();          //setup colors
    initSound();                //setup sound
    return YES;
}

- (void)videoInterrupt
{

}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    vecx_emu ((VECTREX_MHZ / 1000) * EMU_TIMER, 0);    
    glFlush();
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)startEmulation
{
    if(!isRunning)
    {
        [super startEmulation];
        vecx_reset();
    }
}

- (NSUInteger)audioBitDepth
{
    return 8;
}

- (void)updateSound:(uint8_t *)buff len:(int)len
{
    [[g_core ringBufferAtIndex:0] write:buff maxLength:len];
}

- (void)swapBuffers
{

}

- (void)setupEmulation
{
}

- (void)stopEmulation
{
}

- (void)resetEmulation
{
    vecx_reset();
}

- (void)dealloc
{
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    return YES;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    return YES;
}

- (OEIntSize)aspectSize
{
    return (OEIntSize){videoWidth, videoHeight};
}

- (OEIntRect)screenRect
{
    return OERectMake(0, 0, videoWidth, videoHeight);
}

- (OEIntSize)bufferSize
{
    return OESizeMake(videoWidth, videoHeight);
}

- (BOOL)rendersToOpenGL
{
    return YES;
}

- (const void *)videoBuffer
{
    return NULL;
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_INT_8_8_8_8;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB8;
}

- (double)audioSampleRate
{
    return sampleRate;
}

- (NSTimeInterval)frameInterval
{
    return 50;
}

- (NSUInteger)channelCount
{
    return 1;
}


- (oneway void)didMoveVectrexJoystickDirection:(OEVectrexButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
    player -= 1;
    switch (button)
    {
        case OEVectrexAnalogUp:
            yAxis[player][0] = value * INT8_MAX;
            break;
        case OEVectrexAnalogDown:
            yAxis[player][1] = value * INT8_MIN;
            break;
        case OEVectrexAnalogLeft:
            xAxis[player][0] = value * INT8_MIN;
            break;
        case OEVectrexAnalogRight:
            xAxis[player][1] = value * INT8_MAX;
            break;
        default:
            break;
    }
}


- (oneway void)didPushVectrexButton:(OEVectrexButton)button forPlayer:(NSUInteger)player
{
    player -= 1;
    padData[player][button] = 1;
    
    osint_btnDown(button);
}

- (oneway void)didReleaseVectrexButton:(OEVectrexButton)button forPlayer:(NSUInteger)player
{
    player -= 1;
    padData[player][button] = 0;
    
    osint_btnUp(button);
}


@end