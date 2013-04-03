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
#include "dsp.h"
#include "settings.h"
#include "joystick.h"

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
        videoWidth = 1024;
        videoHeight = 512;
        sampleRate = 415625 / 1;    // game specific with different values for 1...
        buffer = new uint32_t[videoWidth * videoHeight];
    }
    
    return self;
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    
    //LogInit("vj.log");                                      // initialize log file for debugging
	vjs.GPUEnabled = true;
	vjs.audioEnabled = false;
	vjs.DSPEnabled = false;
	vjs.hardwareTypeNTSC = true;
	vjs.useJaguarBIOS = false;
	vjs.renderType = 0;
	
	//strcpy(vjs.EEPROMPath, "/path/to/eeproms");
	JaguarInit();                                             // set up hardware
	memcpy(jagMemSpace + 0xE00000, jaguarBootROM, 0x20000);   // Use the stock BIOS
	[self initVideo];
	SET32(jaguarMainRAM, 0, 0x00200000);                      // set up stack
	JaguarLoadFile((char *)[path UTF8String]);                // load rom
	JaguarReset();
    return YES;
    
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    JaguarExecuteNew();
}

- (void)initVideo
{
    JaguarSetScreenPitch(videoWidth);
    JaguarSetScreenBuffer(buffer);
    for (int i = 0; i < videoWidth * videoHeight; ++i)
        buffer[i] = 0xFF00FFFF;
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
    JaguarDone();
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
    return NO;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    return NO;
}

- (OEIntRect)screenRect
{
    return OERectMake(0, 0, TOMGetVideoModeWidth(), TOMGetVideoModeHeight());
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
    return GL_RGBA;
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
    return 60;
}

- (NSUInteger)channelCount
{
    return 2;
}

- (oneway void)didPushJaguarButton:(OEJaguarButton)button forPlayer:(NSUInteger)player
{
    if (player == 1) {
        joypad_0_buttons[button] = 0xff;
    }
    else {
        joypad_1_buttons[button] = 0xff;
    }
}

- (oneway void)didReleaseJaguarButton:(OEJaguarButton)button forPlayer:(NSUInteger)player
{
    if (player == 1) {
        joypad_0_buttons[button] = 0x00;
    }
    else {
        joypad_1_buttons[button] = 0x00;
    }
}

@end
