//
//  Controller.h
//  Moonlight
//
//  Created by Cameron Gutman on 2/11/19.
//  Copyright © 2019 Moonlight Game Streaming Project. All rights reserved.
//

#import "HapticContext.h"

@import GameController;
@import CoreHaptics;
#if !TARGET_OS_TV
    @import CoreMotion;
#endif

@interface VoidController : NSObject

typedef struct {
    float lastX;
    float lastY;
} controller_touch_context_t;

typedef NS_ENUM(NSInteger, ControllerDeviceBatteryState) {
    ControllerDeviceBatteryStateUnknown = -1,
    ControllerDeviceBatteryStateDischarging,
    ControllerDeviceBatteryStateCharging,
    ControllerDeviceBatteryStateFull
};

@property (nullable, nonatomic, retain) GCController* gamepad;
@property (nonatomic)                   int playerIndex;
@property (nonatomic)                   int lastButtonFlags;
@property (nonatomic)                   int emulatingButtonFlags;
@property (nonatomic)                   int supportedEmulationFlags;
@property (nonatomic)                   unsigned char lastLeftTrigger;
@property (nonatomic)                   unsigned char lastRightTrigger;
@property (nonatomic)                   short lastLeftStickX;
@property (nonatomic)                   short lastLeftStickY;
@property (nonatomic)                   short lastRightStickX;
@property (nonatomic)                   short lastRightStickY;

@property (nonatomic)                   controller_touch_context_t primaryTouch;
@property (nonatomic)                   controller_touch_context_t secondaryTouch;

@property (nonatomic)                   HapticContext* _Nullable lowFreqMotor;
@property (nonatomic)                   HapticContext* _Nullable highFreqMotor;
@property (nonatomic)                   HapticContext* _Nullable leftTriggerMotor;
@property (nonatomic)                   HapticContext* _Nullable rightTriggerMotor;

@property (nonatomic)                   NSTimer* _Nullable accelTimer;
@property (nonatomic)                   GCAcceleration lastAccelSample;
@property (nonatomic)                   NSTimer* _Nullable gyroTimer;
@property (nonatomic)                   GCRotationRate lastGyroSample;

#if !TARGET_OS_TV
@property (nonatomic)                   CMMotionManager * _Nullable motionManager;
@property (nonatomic)                   CMAcceleration lastDeviceAccelSample;
@property (nonatomic)                   CMRotationRate lastDeviceGyroSample;
#endif

@property (nonatomic)                   NSTimer* _Nullable batteryTimer;
@property (nonatomic)                   ControllerDeviceBatteryState lastBatteryState; // self defined enum for compatibility
@property (nonatomic)                   float lastBatteryLevel;

@property (nonatomic)                   BOOL reportedArrival;
@property (nonatomic)                   VoidController* _Nullable mergedWithController;

@property(nonatomic, strong) NSMutableSet* _Nullable motionTypes;
@property(nonatomic, assign) uint16_t reportRateHz;
@property(nonatomic, assign) uint16_t controllerNumber;
@property(nonatomic, assign) BOOL hasAccelerometer;
@property(nonatomic, assign) BOOL hasGyroscope;


@end
