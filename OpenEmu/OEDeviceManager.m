/*
 Copyright (c) 2009, OpenEmu Team

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

#import "OEDeviceManager.h"

#import "OEDeviceHandler.h"
#import "OEControllerDescription.h"
#import "OEHIDDeviceHandler.h"
#import "OEMultiHIDDeviceHandler.h"
#import "OEWiimoteHIDDeviceHandler.h"
#import "OEPS3HIDDeviceHandler.h"
#import "OEXBox360HIDDeviceHander.h"
#import "OEHIDEvent.h"
#import "NSApplication+OEHIDAdditions.h"

#import <objc/runtime.h>

#import <IOBluetooth/IOBluetooth.h>
#import <IOBluetooth/objc/IOBluetoothDeviceInquiry.h>
#import <IOBluetooth/objc/IOBluetoothDevice.h>

NSString *const OEWiimoteSupportEnabled = @"OEWiimoteSupportEnabled";

NSString *const OEDeviceManagerDidAddDeviceHandlerNotification    = @"OEDeviceManagerDidAddDeviceHandlerNotification";
NSString *const OEDeviceManagerDidRemoveDeviceHandlerNotification = @"OEDeviceManagerDidRemoveDeviceHandlerNotification";
NSString *const OEDeviceManagerDeviceHandlerUserInfoKey           = @"OEDeviceManagerDeviceHandlerUserInfoKey";


static void OEHandle_DeviceMatchingCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef);

static BOOL OE_isWiimoteControllerName(NSString *name)
{
    return [name hasPrefix:@"Nintendo RVL-CNT-01"];
}

static BOOL OE_isPS3ControllerName(NSString *name)
{
    return [name hasPrefix:@"PLAYSTATION(R)3 Controller"];
}

static BOOL OE_isXboxControllerName(NSString *name)
{
    return [name isEqualToString:@"Controller"];
}

static const void * kOEBluetoothDevicePairSyncStyleKey = &kOEBluetoothDevicePairSyncStyleKey;

@interface IOBluetoothDevicePair (SyncStyle)
@property(nonatomic, assign) BOOL attemptedHostToDevice;
@end

@implementation IOBluetoothDevicePair (SyncStyle)

- (BOOL)attemptedHostToDevice
{
    return [objc_getAssociatedObject(self, kOEBluetoothDevicePairSyncStyleKey) boolValue];
}

- (void)setAttemptedHostToDevice:(BOOL)attemptedHostToDevice
{
    objc_setAssociatedObject(self, kOEBluetoothDevicePairSyncStyleKey, @(attemptedHostToDevice), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface OEDeviceManager () <IOBluetoothDeviceInquiryDelegate>
{
    NSMutableSet             *_keyboardHandlers;
    NSMutableSet             *_deviceHandlers;
    NSMutableSet             *_multiDeviceHandlers;
    IOHIDManagerRef           _hidManager;

    id                        _keyEventMonitor;
    id                        _modifierMaskMonitor;

    IOBluetoothDeviceInquiry *_inquiry;

    NSUInteger _lastAttributedDeviceIdentifier;
    NSUInteger _lastAttributedMultiDeviceIdentifier;
    NSUInteger _lastAttributedKeyboardIdentifier;
}

- (void)OE_addKeyboardEventMonitor;

- (void)OE_addDeviceHandler:(OEDeviceHandler *)handler;
- (void)OE_removeDeviceHandler:(OEDeviceHandler *)handler;

- (void)OE_wiimoteDeviceDidDisconnect:(NSNotification *)notification;
- (void)OE_applicationWillTerminate:(NSNotification *)notification;

@end

@interface OEDeviceHandler ()
@property(readwrite) NSUInteger deviceNumber;
@property(readwrite) NSUInteger deviceIdentifier;
@end

@implementation OEDeviceManager

+ (OEDeviceManager *)sharedDeviceManager;
{
    static OEDeviceManager *sharedHIDManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHIDManager = [[self alloc] init];
    });

    return sharedHIDManager;
}

- (id)init
{
	if((self = [super init]))
	{
        _keyboardHandlers    = [[NSMutableSet alloc] init];
        _deviceHandlers      = [[NSMutableSet alloc] init];
        _multiDeviceHandlers = [[NSMutableSet alloc] init];
		_hidManager          = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);

		IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, OEHandle_DeviceMatchingCallback, (__bridge void *)self);

		IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

        [self OE_addKeyboardEventMonitor];

        NSArray *matchingTypes = @[ @{
                @ kIOHIDDeviceUsagePageKey : @(kHIDPage_GenericDesktop),
                @ kIOHIDDeviceUsageKey     : @(kHIDUsage_GD_Joystick)
            },
            @{
                @ kIOHIDDeviceUsagePageKey : @(kHIDPage_GenericDesktop),
                @ kIOHIDDeviceUsageKey     : @(kHIDUsage_GD_GamePad)
            },
            @{
                @ kIOHIDDeviceUsagePageKey : @(kHIDPage_GenericDesktop),
                @ kIOHIDDeviceUsageKey     : @(kHIDUsage_GD_Keyboard)
            } ];

        IOHIDManagerSetDeviceMatchingMultiple(_hidManager, (__bridge CFArrayRef)matchingTypes);

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OE_wiimoteDeviceDidDisconnect:) name:OEWiimoteDeviceHandlerDidDisconnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OE_applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    }
	return self;
}

- (void)OE_applicationWillTerminate:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	//we do this before release to ensure that we've properly cleaned up our HIDManager references and removed our devices from the runloop
	for(OEDeviceHandler *handler in [_deviceHandlers copy])
        [self OE_removeDeviceHandler:handler];

    [NSEvent removeMonitor:_keyEventMonitor];
    [NSEvent removeMonitor:_modifierMaskMonitor];
    _keyEventMonitor = nil;
    _modifierMaskMonitor = nil;

    if(_hidManager != NULL)
	{
		IOHIDManagerUnscheduleFromRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
		CFRelease(_hidManager);
    }
}

- (NSArray *)deviceHandlers
{
    return [_deviceHandlers copy];
}

- (NSArray *)controllerDeviceHandlers
{
    return [[_deviceHandlers allObjects] sortedArrayUsingComparator:
            ^ NSComparisonResult (OEDeviceHandler *obj1, OEDeviceHandler *obj2)
            {
                return [@([obj1 deviceIdentifier]) compare:@([obj2 deviceIdentifier])];
            }];
}

- (NSArray *)keyboardDeviceHandlers
{
    return [[_keyboardHandlers allObjects] sortedArrayUsingComparator:
            ^ NSComparisonResult (OEDeviceHandler *obj1, OEDeviceHandler *obj2)
            {
                return [@([obj1 deviceIdentifier]) compare:@([obj2 deviceIdentifier])];
            }];
}

#pragma mark - Keyboard management

- (void)OE_addKeyboardEventMonitor;
{
    _keyEventMonitor =
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask | NSKeyUpMask
                                          handler:
     ^ NSEvent * (NSEvent *anEvent)
     {
         /* Events with a process ID of 0 comes from the system, that is from the physical keyboard.
          * These events are already managed by their own device handler.
          * The events managed through this monitor are events coming from different applications.
          */
         if(CGEventGetIntegerValueField([anEvent CGEvent], kCGEventSourceUnixProcessID) != 0)
         {
             OEHIDEvent *event = [OEHIDEvent keyEventWithTimestamp:[anEvent timestamp] keyCode:[OEHIDEvent keyCodeForVirtualKey:[anEvent keyCode]] state:[anEvent type] == NSKeyDown cookie:OEUndefinedCookie];

             [NSApp postHIDEvent:event];
         }

         return anEvent;
     }];

    _modifierMaskMonitor =
    [NSEvent addLocalMonitorForEventsMatchingMask:NSFlagsChangedMask handler:
     ^ NSEvent * (NSEvent *anEvent)
     {
         /* Events with a process ID of 0 comes from the system, that is from the physical keyboard.
          * These events are already managed by their own device handler.
          * The events managed through this monitor are events coming from different applications.
          */
         if(CGEventGetIntegerValueField([anEvent CGEvent], kCGEventSourceUnixProcessID) != 0)
         {
             NSUInteger keyCode = [OEHIDEvent keyCodeForVirtualKey:[anEvent keyCode]];
             NSUInteger keyMask = 0;

             switch(keyCode)
             {
                 case kHIDUsage_KeyboardCapsLock     : keyMask = NSAlphaShiftKeyMask; break;

                 case kHIDUsage_KeyboardLeftControl  : keyMask = 0x0001; break;
                 case kHIDUsage_KeyboardLeftShift    : keyMask = 0x0002; break;
                 case kHIDUsage_KeyboardRightShift   : keyMask = 0x0004; break;
                 case kHIDUsage_KeyboardLeftGUI      : keyMask = 0x0008; break;
                 case kHIDUsage_KeyboardRightGUI     : keyMask = 0x0010; break;
                 case kHIDUsage_KeyboardLeftAlt      : keyMask = 0x0020; break;
                 case kHIDUsage_KeyboardRightAlt     : keyMask = 0x0040; break;
                 case kHIDUsage_KeyboardRightControl : keyMask = 0x2000; break;
             }

             OEHIDEvent *event = [OEHIDEvent keyEventWithTimestamp:[anEvent timestamp] keyCode:keyCode state:!!([anEvent modifierFlags] & keyMask) cookie:OEUndefinedCookie];

             [NSApp postHIDEvent:event];
         }

         return anEvent;
     }];
}

#pragma mark - IOHIDDevice management

- (void)OE_addDeviceHandlerForDeviceRef:(IOHIDDeviceRef)device
{
    NSAssert(device != NULL, @"Passing NULL device.");

    OEHIDDeviceHandler *handler = nil;
    if(IOHIDDeviceConformsTo(device, kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard))
        handler = [[OEHIDDeviceHandler alloc] initWithIOHIDDevice:device deviceDescription:nil];
    else
        handler = [[OEHIDDeviceHandler deviceParser] deviceHandlerForIOHIDDevice:device];

    if([handler connect]) [self OE_addDeviceHandler:handler];
}

- (void)OE_addDeviceHandler:(OEDeviceHandler *)handler
{
    if([handler isKindOfClass:[OEMultiHIDDeviceHandler class]])
    {
        [handler setDeviceIdentifier:++_lastAttributedMultiDeviceIdentifier];
        [_multiDeviceHandlers addObject:handler];

        for(OEDeviceHandler *subhandler in [(OEMultiHIDDeviceHandler *)handler subdeviceHandlers])
            [self OE_addDeviceHandler:subhandler];
        return;
    }
    else if([handler isKeyboardDevice])
    {
        [handler setDeviceIdentifier:++_lastAttributedKeyboardIdentifier];
        [self willChangeValueForKey:@"keyboardDeviceHandlers"];
        [_keyboardHandlers addObject:handler];
        [self didChangeValueForKey:@"keyboardDeviceHandlers"];
    }
    else
    {
        NSAssert([[handler controllerDescription] numberOfControls] > 0, @"Handler %@ does not have any controls.", handler);
        [handler setDeviceIdentifier:++_lastAttributedDeviceIdentifier];
        [self willChangeValueForKey:@"controllerDeviceHandlers"];
        [_deviceHandlers addObject:handler];
        [self didChangeValueForKey:@"controllerDeviceHandlers"];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:OEDeviceManagerDidAddDeviceHandlerNotification object:self userInfo:@{ OEDeviceManagerDeviceHandlerUserInfoKey : handler }];
}

- (BOOL)OE_hasDeviceHandlerForDeviceRef:(IOHIDDeviceRef)deviceRef
{
    for(OEHIDDeviceHandler *handler in _deviceHandlers)
        if([handler isKindOfClass:[OEHIDDeviceHandler class]] && handler.device == deviceRef)
            return YES;

    return NO;
}

- (void)OE_removeDeviceHandler:(OEDeviceHandler *)handler
{
    if([handler isKindOfClass:[OEMultiHIDDeviceHandler class]])
    {
        if(![_multiDeviceHandlers containsObject:handler]) return;

        for(OEDeviceHandler *subhandler in [(OEMultiHIDDeviceHandler *)handler subdeviceHandlers])
            [self OE_addDeviceHandler:subhandler];
        [_multiDeviceHandlers removeObject:handler];

        [handler disconnect];
        return;
    }
    else if([handler isKeyboardDevice])
    {
        if(![_keyboardHandlers containsObject:handler]) return;

        [self willChangeValueForKey:@"keyboardDeviceHandlers"];
        [_keyboardHandlers removeObject:handler];
        [self didChangeValueForKey:@"keyboardDeviceHandlers"];
    }
    else
    {
        if(![_deviceHandlers containsObject:handler]) return;

        [self willChangeValueForKey:@"controllerDeviceHandlers"];
        [_deviceHandlers removeObject:handler];
        [self didChangeValueForKey:@"controllerDeviceHandlers"];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:OEDeviceManagerDidRemoveDeviceHandlerNotification object:self userInfo:@{ OEDeviceManagerDeviceHandlerUserInfoKey : handler }];

    [handler disconnect];
}

- (void)OE_wiimoteDeviceDidDisconnect:(NSNotification *)notification
{
    [self OE_removeDeviceHandler:[notification object]];
}

#pragma mark - Wiimote methods

- (void)startWiimoteSearch;
{
    @synchronized(self)
    {
        //NSLog(@"Searching for Wiimotes");

        _inquiry = [IOBluetoothDeviceInquiry inquiryWithDelegate:self];
        [_inquiry setInquiryLength:3];
        [_inquiry setUpdateNewDeviceNames:YES];

        IOReturn status = [_inquiry start];
        if(status != kIOReturnSuccess)
        {
            [_inquiry setDelegate:nil];
            _inquiry = nil;
            NSLog(@"Error: Inquiry did not start, error %d", status);
        }
    }
}

- (void)stopWiimoteSearch;
{
    @synchronized(self)
    {
        [_inquiry stop];
        [_inquiry setDelegate:nil];
        _inquiry = nil;
    }
}

#pragma mark - IOBluetoothDeviceInquiry Delegates

- (void)deviceInquiryDeviceFound:(IOBluetoothDeviceInquiry *)sender device:(IOBluetoothDevice *)device
{
    //NSLog(@"%@ %@", NSStringFromSelector(_cmd), device);
    // We do not stop the inquiry here because we want to find multiple Wii Remotes, and also because
    // our search criteria is wide, and we may find non-Wiimotes.
}

- (void)deviceInquiryComplete:(IOBluetoothDeviceInquiry *)sender error:(IOReturn)error aborted:(BOOL)aborted
{
    //NSLog(@"Devices: %@ Error: %d, Aborted: %s", [sender foundDevices], error, BOOL_STR(aborted));

    [[sender foundDevices] enumerateObjectsUsingBlock:
     ^(IOBluetoothDevice *obj, NSUInteger idx, BOOL *stop)
     {
         // Check to make sure BT device name has Wiimote prefix. Note that there are multiple
         // possible device names ("Nintendo RVL-CNT-01" and "Nintendo RVL-CNT-01-TR" at the
         // time of writing), so we don't do an exact string match.
         if(OE_isWiimoteControllerName([obj name]))
         {
             [obj openConnection];
             if(![obj isPaired])
             {
                 IOBluetoothDevicePair *pair = [IOBluetoothDevicePair pairWithDevice:obj];
                 [pair setDelegate:self];
                 [pair start];
             }
         }
     }];
}

#pragma mark - IOBluetoothPairDelegate

- (void)devicePairingPINCodeRequest:(IOBluetoothDevicePair*)sender
{
    NSLog(@"Attempting pair");
    NSString *localAddress = [[[IOBluetoothHostController defaultController] addressAsString] uppercaseString];
    NSString *remoteAddress = [[[sender device] addressString] uppercaseString];

    BluetoothPINCode code;
    NSScanner *scanner = [NSScanner scannerWithString:[sender attemptedHostToDevice]?localAddress:remoteAddress];
    int byte = 5;
    while(![scanner isAtEnd])
    {
        unsigned int data;
        [scanner scanHexInt:&data];
        code.data[byte] = data;
        [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] intoString:nil];
        byte--;
    }
    [sender replyPINCode:6 PINCode:&code];
}

- (void)devicePairingFinished:(IOBluetoothDevicePair*)sender error:(IOReturn)error
{
    if(error != kIOReturnSuccess)
    {
        if(![sender attemptedHostToDevice])
        {
            NSLog(@"Pairing failed, attempting inverse");
            IOBluetoothDevicePair *pair = [IOBluetoothDevicePair pairWithDevice:[sender device]];
            [[sender device] openConnection];
            [pair setAttemptedHostToDevice:YES];
            [pair setDelegate:self];
            [pair start];
        }
        else NSLog(@"Couldn't pair, what gives?");
    }

    NSLog(@"Pairing finished %@: %x", sender, error);
}

@end

#pragma mark - HIDManager Callbacks

static void OEHandle_DeviceMatchingCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
    NSLog(@"Found device: %s( context: %p, result: %#x, sender: %p, device: %p ).\n", __PRETTY_FUNCTION__, inContext, inResult, inSender, inIOHIDDeviceRef);

    if([(__bridge OEDeviceManager *)inContext OE_hasDeviceHandlerForDeviceRef:inIOHIDDeviceRef])
    {
        NSLog(@"Device is already being handled");
        return;
    }

    if(IOHIDDeviceOpen(inIOHIDDeviceRef, kIOHIDOptionsTypeNone) != kIOReturnSuccess)
    {
        NSLog(@"%s: failed to open device at %p", __PRETTY_FUNCTION__, inIOHIDDeviceRef);
        return;
    }

    NSLog(@"%@", IOHIDDeviceGetProperty(inIOHIDDeviceRef, CFSTR(kIOHIDProductKey)));

	//add a OEHIDDeviceHandler for our HID device
    [(__bridge OEDeviceManager *)inContext OE_addDeviceHandlerForDeviceRef:inIOHIDDeviceRef];
}
