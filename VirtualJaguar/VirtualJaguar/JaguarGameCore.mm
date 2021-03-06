#import <OpenEmuBase/OERingBuffer.h>
#import <OpenGL/gl.h>
#import "JaguarGameCore.h"
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

void audio_callback_batch(uint16_t *buff, int len)
{
    [[current ringBufferAtIndex:0] write:buff maxLength:len];
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
    uint8_t *currentController;
    
    if (player == 1) {
        currentController = joypad_0_buttons;
    }
    else {
        currentController = joypad_1_buttons;
    }
    
    // special cases to prevent invalid inputs
    if (button == OEJaguarButtonRight && currentController[BUTTON_L]) {
        currentController[BUTTON_L] = 0x00;
        currentController[BUTTON_R] = 0x01;
    }
    else if (button == OEJaguarButtonLeft && currentController[BUTTON_R]) {
        currentController[BUTTON_R] = 0x00;
        currentController[BUTTON_L] = 0x01;
    }
    else if (button == OEJaguarButtonDown && currentController[BUTTON_U]) {
        currentController[BUTTON_U] = 0x00;
        currentController[BUTTON_D] = 0x01;
    }
    else if (button == OEJaguarButtonUp && currentController[BUTTON_D]) {
        currentController[BUTTON_D] = 0x00;
        currentController[BUTTON_U] = 0x01;
    }
    else {
        int index = [self getIndexForOEJaguarButton:button];
        currentController[index] = 0x01;
    }
}

- (oneway void)didReleaseJaguarButton:(OEJaguarButton)button forPlayer:(NSUInteger)player
{
    uint8_t *currentController;
    
    if (player == 1) {
        currentController = joypad_0_buttons;
    }
    else {
        currentController = joypad_1_buttons;
    }
    
    int index = [self getIndexForOEJaguarButton:button];
    currentController[index] = 0x00;
}

- (int)getIndexForOEJaguarButton:(OEJaguarButton)btn {    
    switch (btn) {
        case OEJaguarButtonUp:
            return BUTTON_U;
        case OEJaguarButtonDown:
            return BUTTON_D;
        case OEJaguarButtonLeft:
            return BUTTON_L;
        case OEJaguarButtonRight:
            return BUTTON_R;
        case OEJaguarButtonA:
            return BUTTON_A;
        case OEJaguarButtonB:
            return BUTTON_B;
        case OEJaguarButtonC:
            return BUTTON_C;
        case OEJaguarButtonPause:
            return BUTTON_PAUSE;
        case OEJaguarButtonOption:
            return BUTTON_OPTION;
        case OEJaguarButton1:
            return BUTTON_1;
        case OEJaguarButton2:
            return BUTTON_2;
        case OEJaguarButton3:
            return BUTTON_3;
        case OEJaguarButton4:
            return BUTTON_4;
        case OEJaguarButton5:
            return BUTTON_5;
        case OEJaguarButton6:
            return BUTTON_6;
        case OEJaguarButton7:
            return BUTTON_7;
        case OEJaguarButton8:
            return BUTTON_8;
        case OEJaguarButton9:
            return BUTTON_9;
        case OEJaguarButton0:
            return BUTTON_0;
        case OEJaguarButtonAsterisk:
            return BUTTON_s;
        case OEJaguarButtonPound:
            return BUTTON_d;
        default:
            return -1;
    }
}

@end
