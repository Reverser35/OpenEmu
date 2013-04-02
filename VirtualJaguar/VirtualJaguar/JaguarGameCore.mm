#import <OpenEmuBase/OERingBuffer.h>
#import <OpenGL/gl.h>
#import "JaguarGameCore.h"
#import "OEJaguarSystemResponderClient.h"
#import "jaguar.h"
#import "file.h"
#import "jagbios.h"
#include "memory.h"
#include "log.h"
#include "tom.h"

@interface JaguarGameCore () <OEJaguarSystemResponderClient>
{
    int videoWidth, videoHeight;
    double sampleRate;
    uint32_t *buffer;
}
@end
@implementation JaguarGameCore


- (id)init
{
    if (self = [super init]) {
        videoWidth = 320;
        videoHeight = 240;
        sampleRate = 415625 / 1;    // game specific with different values for 1...
        buffer = new uint32_t[1024 * 512];
    }
    
    return self;
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    LogInit("vj.log");                                      // initialize log file for debugging
    JaguarInit();                                           // set up hardware
    [self initVideo];
    SET32(jaguarMainRAM, 0, 0x00200000);                    // set up stack
    JaguarLoadFile((char *)[path UTF8String]);              // load rom
    memcpy(jagMemSpace + 0xE00000, jaguarBootROM, 0x20000); // load bios
    
    return YES;
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    JaguarExecuteNew();
}

- (void)initVideo
{
    JaguarSetScreenPitch(1024);
    JaguarSetScreenBuffer(buffer);
    memset(buffer, 0xFF, 1024 * 512 * sizeof(uint32_t));
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
    free(buffer);
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

- (const void *)videoBuffer
{
    return buffer;
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

- (oneway void)didReleaseJaguarButton:(OEJaguarButton)button forPlayer:(NSUInteger)player
{
    player -= 1;
}

@end
