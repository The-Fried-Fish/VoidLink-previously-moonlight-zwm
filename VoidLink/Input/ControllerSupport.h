//
//  ControllerSupport.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "StreamConfiguration.h"
#import "VoidController.h"

@class OnScreenControls;

@protocol ControllerSupportDelegate <NSObject>

- (void)gamepadPresenceChanged;
- (void)mousePresenceChanged;
- (void)streamExitRequested;

@end

@interface ControllerSupport : NSObject

@property (readonly) bool shallDisableGyroHotSwitch;

-(id) initWithConfig:(StreamConfiguration*)streamConfig delegate:(id<ControllerSupportDelegate>)delegate;
-(void) connectionEstablished;

-(void) initAutoOnScreenControlMode:(OnScreenControls*)osc;
-(void) cleanup;
-(VoidController*) getOscController;

-(void) updateLeftStick:(VoidController*)controller x:(short)x y:(short)y;
-(void) updateRightStick:(VoidController*)controller x:(short)x y:(short)y;

-(void) updateLeftTrigger:(VoidController*)controller left:(unsigned char)left;
-(void) updateRightTrigger:(VoidController*)controller right:(unsigned char)right;
-(void) updateTriggers:(VoidController*)controller left:(unsigned char)left right:(unsigned char)right;

-(void) updateButtonFlags:(VoidController*)controller flags:(int)flags;
-(void) setButtonFlag:(VoidController*)controller flags:(int)flags;
-(void) clearButtonFlag:(VoidController*)controller flags:(int)flags;

-(void) updateFinished:(VoidController*)controller;

-(void) rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor;
-(void) rumbleTriggers:(uint16_t)controllerNumber leftTrigger:(uint16_t)leftTrigger rightTrigger:(uint16_t)rightTrigger;
-(void) setMotionEventState:(uint16_t)controllerNumber motionType:(uint8_t)motionType reportRateHz:(uint16_t)reportRateHz;
-(void) setControllerLed:(uint16_t)controllerNumber r:(uint8_t)r g:(uint8_t)g b:(uint8_t)b;

-(uint16_t) getActiveGamepadMask;

+(int) getConnectedGamepadMask:(StreamConfiguration*)streamConfig;

-(NSUInteger) getConnectedGamepadCount;

-(void)updateControllerSupport:(StreamConfiguration*)streamConfig delegate:(id<ControllerSupportDelegate>)delegate;

@end
