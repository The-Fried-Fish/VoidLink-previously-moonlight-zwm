//
//  OnScreenButtonState.m
//  Moonlight
//
//  Created by Long Le on 10/20/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "OnScreenButtonState.h"
#import "VoidLink-Swift.h"

@implementation OnScreenButtonState


- (id) initWithButtonName:(NSString*)name buttonType:(uint8_t)buttonType andPosition:(CGPoint)position {
    if ((self = [self init])) {
        self.name = name;
        //self.isHidden = isHidden;
        self.position = position;
        self.widgetType = buttonType;
    }
    
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:([self.identifier isEqualToString:@""]||!self.identifier) ? [UUIDHelper newUUID] : self.identifier forKey:@"identifier"];
    [encoder encodeObject:self.alias forKey:@"alias"];
    [encoder encodeInt:self.widgetType forKey:@"buttonType"]; // keep original key
    [encoder encodeInt:self.sizeReference forKey:@"sizeReference"];
    [encoder encodeInt:self.vibrationStyle forKey:@"vibrationStyle"];
    [encoder encodeInt:self.mouseButtonAction forKey:@"mouseButtonAction"];
    [encoder encodeInt:self.buttonMode forKey:@"slideMode"];  // buttonMode: previously slideMode, keep it for consistency
    [encoder encodeInt:self.autoTapInterval forKey:@"autoTapInterval"];
    [encoder encodeCGPoint:self.position forKey:@"position"];
    [encoder encodeBool:self.isHidden forKey:@"isHidden"];
    [encoder encodeFloat:self.widthFactor forKey:@"widthFactor"];
    [encoder encodeFloat:self.heightFactor forKey:@"heightFactor"];
    [encoder encodeFloat:self.sensitivityFactorX forKey:@"sensitivityFactorX"];
    [encoder encodeFloat:self.sensitivityFactorY forKey:@"sensitivityFactorY"];
    [encoder encodeFloat:self.yawFactor forKey:@"yawFactor"];
    [encoder encodeFloat:self.pitchFactor forKey:@"pitchFactor"];
    [encoder encodeFloat:self.decelerationRate forKey:@"decelerationRate"];
    [encoder encodeFloat:self.stickIndicatorOffset forKey:@"stickIndicatorOffset"];
    [encoder encodeFloat:self.oscLayerSizeFactor forKey:@"oscLayerSizeFactor"];
    [encoder encodeFloat:self.backgroundAlpha forKey:@"backgroundAlpha"];
    [encoder encodeFloat:self.labelAlpha forKey:@"labelAlpha"];
    [encoder encodeFloat:self.borderAlpha forKey:@"borderAlpha"];
    [encoder encodeFloat:self.borderWidth forKey:@"borderWidth"];
    [encoder encodeObject:self.widgetShape forKey:@"widgetShape"];
    [encoder encodeFloat:self.minStickOffset forKey:@"minStickOffset"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.identifier = [decoder containsValueForKey:@"identifier"] ? [decoder decodeObjectForKey:@"identifier"] : [UUIDHelper newUUID];
        self.alias = [decoder decodeObjectForKey:@"alias"];
        self.widgetType = [decoder decodeIntForKey:@"buttonType"];
        self.sizeReference = [decoder containsValueForKey:@"sizeReference"] ? [decoder decodeIntForKey:@"sizeReference"] : longSide;
        self.vibrationStyle = [decoder decodeIntForKey:@"vibrationStyle"];
        self.mouseButtonAction = [decoder decodeIntForKey:@"mouseButtonAction"];
        self.buttonMode = [decoder containsValueForKey:@"slideMode"] ? [decoder decodeIntForKey:@"slideMode"] : 0;
        self.autoTapInterval = [decoder containsValueForKey:@"autoTapInterval"] ? [decoder decodeIntForKey:@"autoTapInterval"] : 45;
        self.position = [decoder decodeCGPointForKey:@"position"];
        self.isHidden = [decoder decodeBoolForKey:@"isHidden"];
        self.widthFactor = [decoder decodeFloatForKey:@"widthFactor"];
        self.heightFactor = [decoder decodeFloatForKey:@"heightFactor"];
        self.sensitivityFactorX = [decoder containsValueForKey:@"sensitivityFactorX"] ? [decoder decodeFloatForKey:@"sensitivityFactorX"] : 1.0;
        self.sensitivityFactorY = [decoder containsValueForKey:@"sensitivityFactorY"] ? [decoder decodeFloatForKey:@"sensitivityFactorY"] : 1.0;
        self.yawFactor = [decoder containsValueForKey:@"yawFactor"] ? [decoder decodeFloatForKey:@"yawFactor"] : 1.0;
        self.pitchFactor = [decoder containsValueForKey:@"pitchFactor"] ? [decoder decodeFloatForKey:@"pitchFactor"] : 1.0;
        self.decelerationRate = [decoder decodeFloatForKey:@"decelerationRate"];
        self.stickIndicatorOffset = [decoder decodeFloatForKey:@"stickIndicatorOffset"];
        self.oscLayerSizeFactor = [decoder decodeFloatForKey:@"oscLayerSizeFactor"];
        self.backgroundAlpha = [decoder containsValueForKey:@"backgroundAlpha"] ? [decoder decodeFloatForKey:@"backgroundAlpha"] : 0.5;
        self.labelAlpha = [decoder containsValueForKey:@"labelAlpha"] ? [decoder decodeFloatForKey:@"labelAlpha"] : 0.82;
        self.borderAlpha = [decoder containsValueForKey:@"borderAlpha"] ? [decoder decodeFloatForKey:@"borderAlpha"] : 0.19;
        self.borderWidth = [decoder decodeFloatForKey:@"borderWidth"];
        self.widgetShape = [decoder decodeObjectForKey:@"widgetShape"];
        self.minStickOffset = [decoder decodeFloatForKey:@"minStickOffset"];
    }
    return self;
}

@end
