//
//  OSCProfile.m
//  Moonlight
//
//  Created by Long Le on 12/22/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "OSCProfile.h"
#import "VoidLink-Swift.h"

@implementation OSCProfile

- (id) initWithName:(NSString*)name buttonStates:(NSMutableArray*)buttonStates isSelected:(BOOL)isSelected {
    if ((self = [self init])) {
        self.name = name;
        self.buttonStatesEncoded = buttonStates;
        self.isSelected = isSelected;
    }
    
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.buttonStatesEncoded forKey:@"buttonStates"];
    [encoder encodeBool:self.isSelected forKey:@"isSelected"];
    [encoder encodeInt64:self.mapGyroTo forKey:@"mapGyroTo"];
    [encoder encodeBool:self.yawPitchToRightStick forKey:@"yawPitchToRightStick"];
    [encoder encodeBool:self.rollToLeftStick forKey:@"rollToLeftStick"];
    [encoder encodeBool:self.synthesizePhysicalStick forKey:@"synthesizePhysicalStick"];
    [encoder encodeFloat:self.gyroSensitivityYaw forKey:@"gyroSensitivityYaw"];
    [encoder encodeFloat:self.gyroSensitivityPitch forKey:@"gyroSensitivityPitch"];
    [encoder encodeFloat:self.gyroSensitivityRoll forKey:@"gyroSensitivityRoll"];
    [encoder encodeFloat:self.accelSensitivityX forKey:@"accelSensitivityX"];
    [encoder encodeFloat:self.accelSensitivityY forKey:@"accelSensitivityY"];
    [encoder encodeFloat:self.accelSensitivityZ forKey:@"accelSensitivityZ"];
    [encoder encodeDouble:self.gyroToStickMinOffset forKey:@"gyroToStickMinOffset"];
    [encoder encodeDouble:self.physicalLeftStickMinOffset forKey:@"physicalLeftStickMinOffset"];
    [encoder encodeDouble:self.physicalRightStickMinOffset forKey:@"physicalRightStickMinOffset"];
    [encoder encodeInt:self.controllerGyroSwitchMode forKey:@"controllerGyroSwitchMode"];
    [encoder encodeBool:self.reverseGyroHoldButton forKey:@"reverseGyroHoldButton"];
    [encoder encodeInt:self.controllerGyroSwitchHold forKey:@"controllerGyroSwitchHold"];
    [encoder encodeInt:self.controllerGyroSwitchToggle forKey:@"controllerGyroSwitchToggle"];
    [encoder encodeObject:self.pressureCurvePoints forKey:@"pressureCurvePoints"];
    [encoder encodeBool:self.pressureCurveEnabled forKey:@"pressureCurveEnabled"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.buttonStatesEncoded =
            [decoder decodeObjectOfClasses:
                [NSSet setWithObjects:
                    [NSMutableArray class],
                    [NSArray class],
                    [NSData class],
                    nil]
                                       forKey:@"buttonStates"];
        self.isSelected = [decoder decodeBoolForKey:@"isSelected"];
        self.mapGyroTo = [decoder containsValueForKey:@"mapGyroTo"] ? [decoder decodeInt64ForKey:@"mapGyroTo"] : mapGyroToMouse;
        self.yawPitchToRightStick = [decoder containsValueForKey:@"yawPitchToRightStick"] ? [decoder decodeBoolForKey:@"yawPitchToRightStick"] : true;
        self.rollToLeftStick = [decoder containsValueForKey:@"rollToLeftStick"] ? [decoder decodeBoolForKey:@"rollToLeftStick"] : false;
        self.synthesizePhysicalStick = [decoder containsValueForKey:@"synthesizePhysicalStick"] ? [decoder decodeBoolForKey:@"synthesizePhysicalStick"] : true;
        self.gyroSensitivityYaw = [decoder containsValueForKey:@"gyroSensitivityYaw"] ? [decoder decodeFloatForKey:@"gyroSensitivityYaw"] : 1.0;
        self.gyroSensitivityPitch = [decoder containsValueForKey:@"gyroSensitivityPitch"] ? [decoder decodeFloatForKey:@"gyroSensitivityPitch"] : 1.0;
        self.gyroSensitivityRoll = [decoder containsValueForKey:@"gyroSensitivityRoll"] ? [decoder decodeFloatForKey:@"gyroSensitivityRoll"] : 1.0;
        self.accelSensitivityX = [decoder containsValueForKey:@"accelSensitivityX"] ? [decoder decodeFloatForKey:@"accelSensitivityX"] : 1.0;
        self.accelSensitivityY = [decoder containsValueForKey:@"accelSensitivityY"] ? [decoder decodeFloatForKey:@"accelSensitivityY"] : 1.0;
        self.accelSensitivityZ = [decoder containsValueForKey:@"accelSensitivityZ"] ? [decoder decodeFloatForKey:@"accelSensitivityZ"] : 1.0;
        self.gyroToStickMinOffset = [decoder containsValueForKey:@"gyroToStickMinOffset"] ? [decoder decodeDoubleForKey:@"gyroToStickMinOffset"] : 0;
        self.physicalLeftStickMinOffset = [decoder containsValueForKey:@"physicalLeftStickMinOffset"] ? [decoder decodeDoubleForKey:@"physicalLeftStickMinOffset"] : 0;
        self.physicalRightStickMinOffset = [decoder containsValueForKey:@"physicalRightStickMinOffset"] ? [decoder decodeDoubleForKey:@"physicalRightStickMinOffset"] : 0;
        self.controllerGyroSwitchMode = [decoder containsValueForKey:@"controllerGyroSwitchMode"] ? [decoder decodeIntForKey:@"controllerGyroSwitchMode"] : ControllerGyroSwitchDisabled;
        self.reverseGyroHoldButton = [decoder containsValueForKey:@"reverseGyroHoldButton"] ? [decoder decodeBoolForKey:@"reverseGyroHoldButton"] : false;
        self.controllerGyroSwitchHold = [decoder containsValueForKey:@"controllerGyroSwitchHold"] ? [decoder decodeIntForKey:@"controllerGyroSwitchHold"] : ControllerButtonNull;
        self.controllerGyroSwitchToggle = [decoder containsValueForKey:@"controllerGyroSwitchToggle"] ? [decoder decodeIntForKey:@"controllerGyroSwitchToggle"] : ControllerButtonNull;
        self.pressureCurvePoints =
            [decoder containsValueForKey:@"pressureCurvePoints"]
            ? [decoder decodeObjectOfClasses:
                    [NSSet setWithObjects:
                    [NSArray class],
                    [NSNumber class],
                                    nil]
                                            forKey:@"pressureCurvePoints"]
            : @[@0.0, @0.0, @1.0, @1.0];
        self.pressureCurveEnabled = [decoder containsValueForKey:@"pressureCurveEnabled"] ? [decoder decodeBoolForKey:@"pressureCurveEnabled"] : false;
    }
    
    return self;
}

- (nonnull id)mutableCopyWithZone:(nullable NSZone *)zone {
    OSCProfile *copy = [[[self class] allocWithZone:zone] init];
    copy.name = [self.name mutableCopy]; // NSString → NSMutableString
    copy.buttonStatesEncoded = [[NSMutableArray alloc] initWithArray:self.buttonStatesEncoded copyItems:YES];
    copy.isSelected = self.isSelected;
    copy.mapGyroTo = self.mapGyroTo;
    copy.yawPitchToRightStick = self.yawPitchToRightStick;
    copy.rollToLeftStick = self.rollToLeftStick;
    copy.synthesizePhysicalStick = self.synthesizePhysicalStick;
    copy.gyroSensitivityYaw = self.gyroSensitivityYaw;
    copy.gyroSensitivityPitch = self.gyroSensitivityPitch;
    copy.gyroSensitivityRoll = self.gyroSensitivityRoll;
    copy.accelSensitivityX = self.accelSensitivityX;
    copy.accelSensitivityY = self.accelSensitivityY;
    copy.accelSensitivityZ = self.accelSensitivityZ;
    copy.gyroToStickMinOffset = self.gyroToStickMinOffset;
    copy.physicalLeftStickMinOffset = self.physicalLeftStickMinOffset;
    copy.physicalRightStickMinOffset = self.physicalRightStickMinOffset;
    copy.controllerGyroSwitchMode = self.controllerGyroSwitchMode;
    copy.reverseGyroHoldButton = self.reverseGyroHoldButton;
    copy.controllerGyroSwitchHold = self.controllerGyroSwitchHold;
    copy.controllerGyroSwitchToggle = self.controllerGyroSwitchToggle;
    copy.pressureCurvePoints = [[NSMutableArray alloc] initWithArray:self.pressureCurvePoints copyItems:YES];
    copy.pressureCurveEnabled = self.pressureCurveEnabled;
    return copy;
}

@end
