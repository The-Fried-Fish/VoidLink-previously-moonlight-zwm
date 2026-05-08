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
    [encoder encodeBool:self.folded forKey:@"folded"];
    [encoder encodeInt32:self.revealMode forKey:@"revealMode"];
    [encoder encodeBool:self.bulkMoveEnabled forKey:@"bulkMoveEnabled"];
    [encoder encodeInt32:self.sequence forKey:@"sequence"];
    [encoder encodeInt32:self.parentSequence forKey:@"parentSequence"];
    [encoder encodeObject:self.sequenceSet forKey:@"sequenceSet"];
    [encoder encodeInt32:self.autoDockTimer forKey:@"autoDockTimer"];
    [encoder encodeFloat:self.dockedAlpha forKey:@"dockedAlpha"];
    
    [encoder encodeObject:self.alias forKey:@"alias"];
    [encoder encodeInt:self.widgetType forKey:@"buttonType"]; // keep original key
    [encoder encodeInt:self.sizeReference forKey:@"sizeReference"];
    [encoder encodeInt:self.vibrationStyle forKey:@"vibrationStyle"];
    [encoder encodeInt:self.mouseButtonAction forKey:@"mouseButtonAction"];
    [encoder encodeBool:self.animatesTransition forKey:@"animatesTransition"];
    [encoder encodeInt:self.buttonMode forKey:@"slideMode"];  // buttonMode: previously slideMode, keep it for consistency
    [encoder encodeInt:self.autoTapInterval forKey:@"autoTapInterval"];
    [encoder encodeCGPoint:self.position forKey:@"position"];
    [encoder encodeBool:self.isHidden forKey:@"isHidden"];
    [encoder encodeFloat:self.widthFactor forKey:@"widthFactor"];
    [encoder encodeFloat:self.heightFactor forKey:@"heightFactor"];
    [encoder encodeFloat:self.componentSizeFactor forKey:@"componentSizeFactor"];
    [encoder encodeFloat:self.sensitivityFactorX forKey:@"sensitivityFactorX"];
    [encoder encodeFloat:self.sensitivityFactorY forKey:@"sensitivityFactorY"];
    [encoder encodeFloat:self.slideThreshold forKey:@"slideThreshold"];
    [encoder encodeFloat:self.yawFactor forKey:@"yawFactor"];
    [encoder encodeFloat:self.pitchFactor forKey:@"pitchFactor"];
    [encoder encodeFloat:self.rollFactor forKey:@"rollFactor"];
    [encoder encodeFloat:self.decelerationRateX forKey:@"decelerationRateX"];
    [encoder encodeFloat:self.decelerationRateY forKey:@"decelerationRateY"];
    [encoder encodeBool:self.touchPointAnchored forKey:@"touchPointAnchored"];
    [encoder encodeFloat:self.stickIndicatorOffset forKey:@"stickIndicatorOffset"];
    [encoder encodeFloat:self.oscLayerSizeFactor forKey:@"oscLayerSizeFactor"];
    [encoder encodeFloat:self.backgroundAlpha forKey:@"backgroundAlpha"];
    [encoder encodeFloat:self.labelAlpha forKey:@"labelAlpha"];
    [encoder encodeFloat:self.borderAlpha forKey:@"borderAlpha"];
    [encoder encodeFloat:self.highlightAlpha forKey:@"highlightAlpha"];
    [encoder encodeFloat:self.borderWidth forKey:@"borderWidth"];
    [encoder encodeFloat:self.highlightSizeFactor forKey:@"highlightSizeFactor"];
    [encoder encodeObject:self.widgetShape forKey:@"widgetShape"];
    [encoder encodeFloat:self.walkModeThreshold forKey:@"walkModeThreshold"];
    [encoder encodeFloat:self.minStickOffset forKey:@"minStickOffset"];
    [encoder encodeInt:self.sprintKeyActionType forKey:@"sprintKeyActionType"];
    [encoder encodeFloat:self.sprintKeyThreshold forKey:@"sprintKeyThreshold"];
    [encoder encodeInt:self.walkKeyActionType forKey:@"walkKeyActionType"];
    [encoder encodeFloat:self.walkKeyThreshold forKey:@"walkKeyThreshold"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.folded = [decoder containsValueForKey:@"folded"] ? [decoder decodeBoolForKey:@"folded"] : false;
        self.revealMode = [decoder containsValueForKey:@"revealMode"] ? [decoder decodeInt32ForKey:@"revealMode"] : coexist;
        self.bulkMoveEnabled = [decoder containsValueForKey:@"bulkMoveEnabled"] ? [decoder decodeBoolForKey:@"bulkMoveEnabled"] : true;
        self.sequence = [decoder containsValueForKey:@"sequence"] ? [decoder decodeInt32ForKey:@"sequence"] : -1;
        self.parentSequence = [decoder containsValueForKey:@"parentSequence"] ? [decoder decodeInt32ForKey:@"parentSequence"] : -1;
        self.sequenceSet = [decoder containsValueForKey:@"sequenceSet"] ? [decoder decodeObjectForKey:@"sequenceSet"] : [NSSet set];
        self.autoDockTimer = [decoder containsValueForKey:@"autoDockTimer"] ? [decoder decodeInt32ForKey:@"autoDockTimer"] : 0;
        self.dockedAlpha = [decoder containsValueForKey:@"dockedAlpha"] ? [decoder decodeFloatForKey:@"dockedAlpha"] : 0.2;
        
        self.alias = [decoder decodeObjectForKey:@"alias"];
        self.widgetType = [decoder decodeIntForKey:@"buttonType"];
        self.sizeReference = [decoder containsValueForKey:@"sizeReference"] ? [decoder decodeIntForKey:@"sizeReference"] : longSide;
        self.vibrationStyle = [decoder containsValueForKey:@"vibrationStyle"] ? [decoder decodeIntForKey:@"vibrationStyle"] : UIImpactFeedbackStyleLight;
        self.mouseButtonAction = [decoder decodeIntForKey:@"mouseButtonAction"];
        self.animatesTransition = [decoder containsValueForKey:@"animatesTransition"] ? [decoder decodeBoolForKey:@"animatesTransition"] : true;
        self.buttonMode = [decoder containsValueForKey:@"slideMode"] ? [decoder decodeIntForKey:@"slideMode"] : 0;
        self.autoTapInterval = [decoder containsValueForKey:@"autoTapInterval"] ? [decoder decodeIntForKey:@"autoTapInterval"] : 45;
        self.position = [decoder decodeCGPointForKey:@"position"];
        self.isHidden = [decoder decodeBoolForKey:@"isHidden"];
        self.widthFactor = [decoder decodeFloatForKey:@"widthFactor"];
        self.heightFactor = [decoder decodeFloatForKey:@"heightFactor"];
        self.componentSizeFactor = [decoder containsValueForKey:@"componentSizeFactor"] ? [decoder decodeFloatForKey:@"componentSizeFactor"] : 1.0;
        self.sensitivityFactorX = [decoder containsValueForKey:@"sensitivityFactorX"] ? [decoder decodeFloatForKey:@"sensitivityFactorX"] : 1.0;
        self.sensitivityFactorY = [decoder containsValueForKey:@"sensitivityFactorY"] ? [decoder decodeFloatForKey:@"sensitivityFactorY"] : 1.0;
        self.slideThreshold = [decoder containsValueForKey:@"slideThreshold"] ? [decoder decodeFloatForKey:@"slideThreshold"] : 6.0;
        self.yawFactor = [decoder containsValueForKey:@"yawFactor"] ? [decoder decodeFloatForKey:@"yawFactor"] : 1.0;
        self.pitchFactor = [decoder containsValueForKey:@"pitchFactor"] ? [decoder decodeFloatForKey:@"pitchFactor"] : 1.0;
        self.rollFactor = [decoder containsValueForKey:@"rollFactor"] ? [decoder decodeFloatForKey:@"rollFactor"] : 1.0;
        self.decelerationRateX = [decoder containsValueForKey:@"decelerationRateX"] ? [decoder decodeFloatForKey:@"decelerationRateX"] : 0.5;
        self.decelerationRateY = [decoder containsValueForKey:@"decelerationRateY"] ? [decoder decodeFloatForKey:@"decelerationRateY"] : 0.5;
        self.touchPointAnchored = [decoder containsValueForKey:@"touchPointAnchored"] ? [decoder decodeBoolForKey:@"touchPointAnchored"] : false;
        self.stickIndicatorOffset = [decoder decodeFloatForKey:@"stickIndicatorOffset"];
        self.oscLayerSizeFactor = [decoder decodeFloatForKey:@"oscLayerSizeFactor"];
        self.backgroundAlpha = [decoder containsValueForKey:@"backgroundAlpha"] ? [decoder decodeFloatForKey:@"backgroundAlpha"] : 0.5;
        self.labelAlpha = [decoder containsValueForKey:@"labelAlpha"] ? [decoder decodeFloatForKey:@"labelAlpha"] : 0.82;
        self.borderAlpha = [decoder containsValueForKey:@"borderAlpha"] ? [decoder decodeFloatForKey:@"borderAlpha"] : 0.19;
        self.highlightAlpha = [decoder containsValueForKey:@"highlightAlpha"] ? [decoder decodeFloatForKey:@"highlightAlpha"] : 0.77;
        self.borderWidth = [decoder decodeFloatForKey:@"borderWidth"];
        self.highlightSizeFactor = [decoder containsValueForKey:@"highlightSizeFactor"] ? [decoder decodeFloatForKey:@"highlightSizeFactor"] : 1.0;
        self.widgetShape = [decoder decodeObjectForKey:@"widgetShape"];
        self.walkModeThreshold = [decoder containsValueForKey:@"walkModeThreshold"] ? [decoder decodeFloatForKey:@"walkModeThreshold"] : 16383;
        self.minStickOffset = [decoder decodeFloatForKey:@"minStickOffset"];
        
        self.sprintKeyActionType = [decoder containsValueForKey:@"sprintKeyActionType"] ? [decoder decodeIntForKey:@"sprintKeyActionType"] : WalkSprintKeyActionTypeHold;
        self.sprintKeyThreshold = [decoder containsValueForKey:@"sprintKeyThreshold"] ? [decoder decodeFloatForKey:@"sprintKeyThreshold"] : 0.6;
        self.walkKeyActionType = [decoder containsValueForKey:@"walkKeyActionType"] ? [decoder decodeIntForKey:@"walkKeyActionType"] : WalkSprintKeyActionTypeHold;
        self.walkKeyThreshold = [decoder containsValueForKey:@"walkKeyThreshold"] ? [decoder decodeFloatForKey:@"walkKeyThreshold"] : 0.08;

    }
    return self;
}

@end
