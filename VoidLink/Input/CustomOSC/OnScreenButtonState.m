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

@implementation OnScreenButtonState


- (id) initWithButtonName:(NSString*)name buttonType:(uint8_t)buttonType andPosition:(CGPoint)position {
    if ((self = [self init])) {
        self.name = name;
        //self.isHidden = isHidden;
        self.position = position;
        self.buttonType = buttonType;
    }
    
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.alias forKey:@"alias"];
    [encoder encodeInt:self.buttonType forKey:@"buttonType"];
    [encoder encodeInt:self.vibrationStyle forKey:@"vibrationStyle"];
    [encoder encodeInt:self.mouseButtonAction forKey:@"mouseButtonAction"];
    [encoder encodeCGPoint:self.position forKey:@"position"];
    [encoder encodeBool:self.isHidden forKey:@"isHidden"];
    [encoder encodeFloat:self.widthFactor forKey:@"widthFactor"];
    [encoder encodeFloat:self.heightFactor forKey:@"heightFactor"];
    [encoder encodeFloat:self.sensitivityFactorX forKey:@"sensitivityFactorX"];
    [encoder encodeFloat:self.sensitivityFactorY forKey:@"sensitivityFactorY"];
    [encoder encodeFloat:self.decelerationRate forKey:@"decelerationRate"];
    [encoder encodeFloat:self.stickIndicatorOffset forKey:@"stickIndicatorOffset"];
    [encoder encodeFloat:self.oscLayerSizeFactor forKey:@"oscLayerSizeFactor"];
    [encoder encodeFloat:self.backgroundAlpha forKey:@"backgroundAlpha"];
    [encoder encodeFloat:self.borderWidth forKey:@"borderWidth"];
    [encoder encodeObject:self.widgetShape forKey:@"widgetShape"];
    [encoder encodeFloat:self.minStickOffset forKey:@"minStickOffset"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.alias = [decoder decodeObjectForKey:@"alias"];
        self.buttonType = [decoder decodeIntForKey:@"buttonType"];
        self.vibrationStyle = [decoder decodeIntForKey:@"vibrationStyle"];
        self.mouseButtonAction = [decoder decodeIntForKey:@"mouseButtonAction"];
        self.position = [decoder decodeCGPointForKey:@"position"];
        self.isHidden = [decoder decodeBoolForKey:@"isHidden"];
        self.widthFactor = [decoder decodeFloatForKey:@"widthFactor"];
        self.heightFactor = [decoder decodeFloatForKey:@"heightFactor"];
        self.sensitivityFactorX = [decoder decodeFloatForKey:@"sensitivityFactorX"];
        self.sensitivityFactorX = self.sensitivityFactorX == 0 ? 1.0 : self.sensitivityFactorX;
        self.sensitivityFactorY = [decoder decodeFloatForKey:@"sensitivityFactorY"];
        self.sensitivityFactorY = self.sensitivityFactorY == 0 ? 1.0 : self.sensitivityFactorY;
        self.decelerationRate = [decoder decodeFloatForKey:@"decelerationRate"];
        self.stickIndicatorOffset = [decoder decodeFloatForKey:@"stickIndicatorOffset"];
        self.oscLayerSizeFactor = [decoder decodeFloatForKey:@"oscLayerSizeFactor"];
        self.backgroundAlpha = [decoder decodeFloatForKey:@"backgroundAlpha"];
        self.borderWidth = [decoder decodeFloatForKey:@"borderWidth"];
        self.widgetShape = [decoder decodeObjectForKey:@"widgetShape"];
        self.minStickOffset = [decoder decodeFloatForKey:@"minStickOffset"];
    }
    return self;
}

@end
