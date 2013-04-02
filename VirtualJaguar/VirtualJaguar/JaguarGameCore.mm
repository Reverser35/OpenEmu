#import <OpenEmuBase/OERingBuffer.h>
#import <OpenGL/gl.h>
#import "JaguarGameCore.h"
#import "OEJaguarSystemResponderClient.h"
#import "jaguar.h"
#import "file.h"
#import "jagbios.h"
#include "memory.h"
#include <string.h>

@interface JaguarGameCore () <OEJaguarSystemResponderClient>
{
    int videoWidth, videoHeight;
    double sampleRate;
}
@end
@implementation JaguarGameCore


- (id)init
{
    if (self = [super init]) {
        videoWidth = 800;           // max value
        videoHeight = 576;          // max value
        sampleRate = 415625 / 1;    // game specific with different values for 1...
    }
    
    return self;
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    JaguarInit();                                           // set up hardware
    SET32(jaguarMainRAM, 0, 0x00200000);                    // set up stack
    JaguarLoadFile((char *)[path UTF8String]);              // load rom
    memcpy(jagMemSpace + 0xE00000, jaguarBootROM, 0x20000); // load bios
    
    return YES;
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    JaguarExecuteNew();
    // add code to update opengl here
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (NSUInteger)audioBitDepth
{
    return 16;
}

- (void)updateSound:(uint8_t *)buff len:(int)len
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
    JaguarReset();
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
    //or 25 for PAL
    return 29.97;
}

- (NSUInteger)channelCount
{
    return 2;
}

- (oneway void)didPushJaguarButton:(OEJaguarButton)button forPlayer:(NSUInteger)player
{
    player -= 1;
}

- (oneway void)didReleaseJaguarButton:(OEJaguarButton)button forPlayer:(NSUInteger)player;
{
    player -= 1;
}

@end
