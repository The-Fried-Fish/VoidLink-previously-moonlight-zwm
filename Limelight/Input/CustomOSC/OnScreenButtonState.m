//
//  OnScreenButtonState.m
//  Moonlight
//
//  Created by Long Le on 10/20/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
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
    [encoder encodeDouble:self.timestamp forKey:@"timestamp"];
    [encoder encodeInt:self.buttonType forKey:@"buttonType"];
    [encoder encodeCGPoint:self.position forKey:@"position"];
    [encoder encodeBool:self.isHidden forKey:@"isHidden"];
    [encoder encodeFloat:self.widthFactor forKey:@"widthFactor"];
    [encoder encodeFloat:self.heightFactor forKey:@"heightFactor"];
    [encoder encodeFloat:self.sensitivityFactorX forKey:@"velocityFactorX"];
    [encoder encodeFloat:self.sensitivityFactorY forKey:@"velocityFactorY"];
    [encoder encodeFloat:self.stickIndicatorOffset forKey:@"stickIndicatorOffset"];
    [encoder encodeFloat:self.oscLayerSizeFactor forKey:@"oscLayerSizeFactor"];
    [encoder encodeFloat:self.backgroundAlpha forKey:@"backgroundAlpha"];
    [encoder encodeFloat:self.borderWidth forKey:@"borderWidth"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.alias = [decoder decodeObjectForKey:@"alias"];
        self.timestamp = [decoder decodeDoubleForKey:@"timestamp"];
        self.buttonType = [decoder decodeIntForKey:@"buttonType"];
        self.position = [decoder decodeCGPointForKey:@"position"];
        self.isHidden = [decoder decodeBoolForKey:@"isHidden"];
        self.widthFactor = [decoder decodeFloatForKey:@"widthFactor"];
        self.heightFactor = [decoder decodeFloatForKey:@"heightFactor"];
        self.sensitivityFactorX = [decoder decodeFloatForKey:@"velocityFactorX"];
        self.sensitivityFactorY = [decoder decodeFloatForKey:@"velocityFactorY"];
        self.stickIndicatorOffset = [decoder decodeFloatForKey:@"stickIndicatorOffset"];
        self.oscLayerSizeFactor = [decoder decodeFloatForKey:@"oscLayerSizeFactor"];
        self.backgroundAlpha = [decoder decodeFloatForKey:@"backgroundAlpha"];
        self.borderWidth = [decoder decodeFloatForKey:@"borderWidth"];
    }
    return self;
}

@end
