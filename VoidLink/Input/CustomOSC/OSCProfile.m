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
    [encoder encodeInt64:self.mapGyroTo forKey:@"mapGyroTo"];
    [encoder encodeFloat:self.gyroSensitivityYaw forKey:@"gyroSensitivityYaw"];
    [encoder encodeFloat:self.gyroSensitivityPitch forKey:@"gyroSensitivityPitch"];
    [encoder encodeFloat:self.gyroSensitivityRoll forKey:@"gyroSensitivityRoll"];
    [encoder encodeFloat:self.accelSensitivityX forKey:@"accelSensitivityX"];
    [encoder encodeFloat:self.accelSensitivityY forKey:@"accelSensitivityY"];
    [encoder encodeFloat:self.accelSensitivityZ forKey:@"accelSensitivityZ"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.buttonStatesEncoded = [decoder decodeObjectForKey:@"buttonStates"];
        self.isSelected = [decoder decodeBoolForKey:@"isSelected"];
        self.mapGyroTo = [decoder containsValueForKey:@"mapGyroTo"] ? [decoder decodeInt64ForKey:@"mapGyroTo"] : mapGyroToMouse;
        self.yawPitchToRightStick = [decoder containsValueForKey:@"yawPitchToRightStick"] ? [decoder decodeBoolForKey:@"yawPitchToRightStick"] : true;
        self.rollToLeftStick = [decoder containsValueForKey:@"rollToLeftStick"] ? [decoder decodeBoolForKey:@"rollToLeftStick"] : false;
        self.gyroSensitivityYaw = [decoder containsValueForKey:@"gyroSensitivityYaw"] ? [decoder decodeFloatForKey:@"gyroSensitivityYaw"] : 1.0;
        self.gyroSensitivityPitch = [decoder containsValueForKey:@"gyroSensitivityPitch"] ? [decoder decodeFloatForKey:@"gyroSensitivityPitch"] : 1.0;
        self.gyroSensitivityRoll = [decoder containsValueForKey:@"gyroSensitivityRoll"] ? [decoder decodeFloatForKey:@"gyroSensitivityRoll"] : 1.0;
        self.accelSensitivityX = [decoder containsValueForKey:@"accelSensitivityX"] ? [decoder decodeFloatForKey:@"accelSensitivityX"] : 1.0;
        self.accelSensitivityY = [decoder containsValueForKey:@"accelSensitivityY"] ? [decoder decodeFloatForKey:@"accelSensitivityY"] : 1.0;
        self.accelSensitivityZ = [decoder containsValueForKey:@"accelSensitivityZ"] ? [decoder decodeFloatForKey:@"accelSensitivityZ"] : 1.0;
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
    copy.gyroSensitivityYaw = self.gyroSensitivityYaw;
    copy.gyroSensitivityPitch = self.gyroSensitivityPitch;
    copy.gyroSensitivityRoll = self.gyroSensitivityRoll;
    copy.accelSensitivityX = self.accelSensitivityX;
    copy.accelSensitivityY = self.accelSensitivityY;
    copy.accelSensitivityZ = self.accelSensitivityZ;
    return copy;
}

@end
