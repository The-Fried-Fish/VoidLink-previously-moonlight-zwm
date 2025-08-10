//
//  OnScreenButtonState.h
//  Moonlight
//
//  Created by Long Le on 10/20/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This object is used to save positional and visibility information for any particular on screen virtual controller button.
 We are able to associate this 'OnScreenButtonState' object and its corresponding CALayer onscreen controller button by setting their 'name' properties equal; in our particular case we give them descriptive names such as 'aButton', 'upButton', 'leftStick', etc. By keeping references to the 19 on screen controller buttons (CALayers) in an array, and creating 19 'OnScreenButtonState' objects with names corresponding to these 19 CALayers and keeping them in an array, we can iterate through both arrays to find OSC buttons (CALayers) with the same name as one of the 'OnScreenButtonStateObjects' and then set the CALayer on screen control button's 'position' and 'hidden' property according to the value of the 'OnScreenButtonState' objects 'position' and 'isHidden' properties.
 Naturally we would like the user to be able to save their controller layout configurations so that they can load them between app launches, so we adopt encoding/decoding related protocols so we encode these 'OnScreenButtonState' objects and save them to NSUserDefaults
 */

// OS Button state info obj to be modified
@interface OnScreenButtonState : NSObject  <NSCoding, NSSecureCoding>

@property NSString *name;
@property NSString *alias;
@property CGPoint position;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, assign) uint8_t slideMode;
@property (nonatomic, assign) uint8_t buttonType;
@property (nonatomic, assign) CGFloat widthFactor; // for OnScreenWidgetView
@property (nonatomic, assign) CGFloat heightFactor; // for OnScreenWidgetView
@property (nonatomic, assign) CGFloat borderWidth; // for OnScreenWidgetView
@property (nonatomic, assign) CGFloat sensitivityFactorX; // for OnScreenWidgetView
@property (nonatomic, assign) CGFloat sensitivityFactorY; // for OnScreenWidgetView
@property (nonatomic, assign) CGFloat decelerationRate; // for OnScreenWidgetView
@property (nonatomic, assign) CGFloat stickIndicatorOffset; // for OnScreenWidgetView
@property (nonatomic, assign) CGFloat minStickOffset; // for OnScreenWidgetView
@property NSString* widgetShape; // for OnScreenWidgetView

@property (nonatomic, assign) CGFloat oscLayerSizeFactor; // for OnScreenController CALayer
@property (nonatomic, assign) CGFloat backgroundAlpha; // for OnScreenController CALayer
@property (nonatomic, assign) uint8_t vibrationStyle; // for OnScreenController CALayer
@property (nonatomic, assign) uint8_t mouseButtonAction; // for OnScreenController CALayer

// @property (nonatomic, assign) BOOL hasValidPosition;

typedef NS_ENUM(NSInteger, OnScreenButtonType) {
    LegacyOscButton,
    CustomOnScreenWidget
};

typedef NS_ENUM(NSInteger, MouseButtonAction) {
    hovering,
    leftButtonDown,
    middleButtonDown,
    rightButtonDown,
};

typedef NS_ENUM(NSInteger, ButtonSlideMode) {
    toggle,
    slideAndHold,
    disabled
};



- (id) initWithButtonName:(NSString*)name buttonType:(uint8_t)buttonType andPosition:(CGPoint)position;

+ (BOOL) supportsSecureCoding;
- (void) encodeWithCoder:(NSCoder*)encoder;
- (id) initWithCoder:(NSCoder*)decoder;

@end

NS_ASSUME_NONNULL_END
