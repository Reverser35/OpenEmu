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
#include "dac.h"

@interface JaguarGameCore () <OEJaguarSystemResponderClient>
{
    int videoWidth, videoHeight;
    double sampleRate;
    uint32_t *buffer;
}
@end
@implementation JaguarGameCore

static JaguarGameCore *current;

- (id)init
{
    if (self = [super init]) {
        videoWidth = 1024;
        videoHeight = 512;
        sampleRate = DAC_AUDIO_RATE;
        buffer = new uint32_t[videoWidth * videoHeight];
    }
    
    current = self;
    
    return self;
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    NSString *batterySavesDirectory = [self batterySavesDirectoryPath];
    
    if([batterySavesDirectory length] != 0)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
        
        NSString *filePath = [batterySavesDirectory stringByAppendingString:@"/"];
        strcpy(vjs.EEPROMPath, [filePath UTF8String]);
    }
    
    //LogInit("vj.log");                                      // initialize log file for debugging
	vjs.GPUEnabled = true;
	vjs.audioEnabled = true;                                  // not used currently
	vjs.DSPEnabled = true;
	vjs.hardwareTypeNTSC = true;
	vjs.useJaguarBIOS = false;
	vjs.renderType = 0;
	
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

void audio_callback_batch(uint8 *buff, int len)
{
    for (int i = 0; i < len; i += 2) {
        int16_t *realBuff = (int16_t *)buff;
        [[current ringBufferAtIndex:0] write:realBuff+i maxLength:2];
        [[current ringBufferAtIndex:0] write:realBuff+i+1 maxLength:2];
    }
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (NSUInteger)audioBitDepth
{
    return 16;
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
    // fix for core crashing when two opposite d-pad directions register simultaneously
    // should only occur when using keyboard as controller
    if (player == 1) {
        if (button == OEJaguarButtonRight && joypad_0_buttons[OEJaguarButtonLeft]) {
            joypad_0_buttons[OEJaguarButtonLeft] = 0x00;
            joypad_0_buttons[OEJaguarButtonRight] = 0xff;
        }
        if (button == OEJaguarButtonLeft && joypad_0_buttons[OEJaguarButtonRight]) {
            joypad_0_buttons[OEJaguarButtonRight] = 0x00;
            joypad_0_buttons[OEJaguarButtonLeft] = 0xff;
        }
        if (button == OEJaguarButtonDown && joypad_0_buttons[OEJaguarButtonUp]) {
            joypad_0_buttons[OEJaguarButtonUp] = 0x00;
            joypad_0_buttons[OEJaguarButtonDown] = 0xff;
        }
        if (button == OEJaguarButtonUp && joypad_0_buttons[OEJaguarButtonDown]) {
            joypad_0_buttons[OEJaguarButtonDown] = 0x00;
            joypad_0_buttons[OEJaguarButtonUp] = 0xff;
        }
        else {
                joypad_0_buttons[button] = 0xff;
        }
    }
    else {
        if (button == OEJaguarButtonRight && joypad_1_buttons[OEJaguarButtonLeft]) {
            joypad_1_buttons[OEJaguarButtonLeft] = 0x00;
            joypad_1_buttons[OEJaguarButtonRight] = 0xff;
        }
        if (button == OEJaguarButtonLeft && joypad_1_buttons[OEJaguarButtonRight]) {
            joypad_1_buttons[OEJaguarButtonRight] = 0x00;
            joypad_1_buttons[OEJaguarButtonLeft] = 0xff;
        }
        if (button == OEJaguarButtonDown && joypad_1_buttons[OEJaguarButtonUp]) {
            joypad_1_buttons[OEJaguarButtonUp] = 0x00;
            joypad_1_buttons[OEJaguarButtonDown] = 0xff;
        }
        if (button == OEJaguarButtonUp && joypad_1_buttons[OEJaguarButtonDown]) {
            joypad_1_buttons[OEJaguarButtonDown] = 0x00;
            joypad_1_buttons[OEJaguarButtonUp] = 0xff;
        }
        else {
            joypad_1_buttons[button] = 0xff;
        }
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
