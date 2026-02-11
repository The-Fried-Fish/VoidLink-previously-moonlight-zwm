//
//  OnScreenControls.h
//  Moonlight
//
//  Created by Diego Waxemberg on 12/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.7.7
//  Copyright © True砖家 @ Bilibili. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ControllerSupport.h"
#import "CustomTapGestureRecognizer.h"
#import "OSCProfile.h"
#define MIN_CONTROLLER_LAYER_ALPHA 0.23

@class ControllerSupport;
@class StreamConfiguration;
@class LayoutOnScreenControls;

static const float D_PAD_DIST = 10;
static const float BUTTON_DIST = 20;

@interface OnScreenControls : NSObject{
    @protected
    CGFloat _leftStickSizeFactor;
    CGFloat _leftStickOpacity;
    CGFloat _rightStickSizeFactor;
    CGFloat _rightStickOpacity;
    CGFloat _dPadSizeFactor;
}

+ (NSMutableDictionary *_Nullable)layerVibrationStyleDic;

typedef NS_ENUM(NSInteger, OnScreenControlsLevel) {
    OnScreenControlsLevelOff,
    OnScreenControlsLevelCustom,
    OnScreenControlsLevelSimple,
    OnScreenControlsLevelFull,
    OnScreenControlsLevelAuto, // move it here instead of delete , to ensure integrity of the codes

    // Internal levels selected by ControllerSupport
    OnScreenControlsLevelAutoGCGamepad,
    OnScreenControlsLevelAutoGCExtendedGamepad,
    OnScreenControlsLevelAutoGCExtendedGamepadWithStickButtons
};


// @property (nonatomic, assign) CustomTapGestureRecognizer* mouseRightClickTapRecognizer; // this object will be passed to onscreencontrols class for areVirtualControllerTaps flag setting
@property (nonatomic, assign) bool isLayingOut;
//@property (nonatomic) NSMutableSet<UITouch* >* touchesCapturedByOnScreenButtons;


@property (nonatomic, assign) CGRect standardRoundButtonBounds;
@property (nonatomic, assign) CGRect standardRectangleButtonBounds;
@property (nonatomic, assign) CGRect standardStickBounds;
@property (nonatomic, assign) CGRect standardStickBackgroundBounds;
@property (nonatomic, assign) CGRect standardUpDownButtonBounds;
@property (nonatomic, assign) CGRect standardLeftRightButtonBounds;

@property (nonatomic, assign) CGPoint leftStickCenter;
@property (nonatomic, assign) CGPoint rightStickCenter;

@property CALayer* _aButton;
@property (nonatomic, assign) CGFloat aButtonSizeFactor;
@property CALayer* _bButton;
@property (nonatomic, assign) CGFloat bButtonSizeFactor;
@property CALayer* _xButton;
@property (nonatomic, assign) CGFloat xButtonSizeFactor;
@property CALayer* _yButton;
@property (nonatomic, assign) CGFloat yButtonSizeFactor;


@property CALayer* _startButton;
@property CALayer* _selectButton;
@property CALayer* _r1Button;
@property CALayer* _r2Button;
@property CALayer* _r3Button;
@property CALayer* _l1Button;
@property CALayer* _l2Button;
@property CALayer* _l3Button;
@property CALayer* _upButton;
@property CALayer* _downButton;
@property CALayer* _leftButton;
@property CALayer* _rightButton;
@property CALayer* _leftStickBackground;
@property CALayer* _leftStick;
@property CALayer* _rightStickBackground;
@property CALayer* _rightStick;
@property CALayer* _dPadBackground;    // parent layer that contains each individual dPad button so user can drag them around the screen together

@property float D_PAD_CENTER_X;
@property float D_PAD_CENTER_Y;

@property OnScreenControlsLevel _level;

@property NSMutableSet *OSCButtonLayerPool;
@property NSMutableDictionary* layerVibrationStyleDic;



+ (NSMutableSet* )touchesCapturedByOnScreenControls;
+ (OnScreenControls* )shared;
+ (void)setShared:(OnScreenControls*)instance;

- (void) sendRightStickTouchPadEvent:(CGFloat) stickX : (CGFloat) stickY;
- (void) clearRightStickTouchPadFlag;
- (void) sendLeftStickTouchPadEvent:(CGFloat) stickX : (CGFloat) stickY;
- (void) clearLeftStickTouchPadFlag;
- (void) pressDownControllerButton: (int)flag;
- (void) releaseControllerButton: (int)flag;
- (void) updateLeftTrigger:(unsigned char)input;
- (void) updateRightTrigger:(unsigned char)input;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig;
- (BOOL) handleTouchDownEvent:(NSSet*)touches;
- (BOOL) handleTouchUpEvent:(NSSet*)touches;
- (BOOL) handleTouchMovedEvent:(NSSet*)touches;
- (void) setLevel:(OnScreenControlsLevel)level;
- (void) showLegacyWidgetsWith:(OSCProfile* )profile;
- (void) regenLayerPool;
- (void) setupComplexControls;
- (void) drawButtons:(OSCProfile* _Nullable)profile;
- (void) drawBumpers;
- (void) updateLegacyWidgetsWith:(OSCProfile* _Nullable )profile;
- (OnScreenControlsLevel) getLevel;
- (void) setDPadCenter:(OSCProfile *_Nonnull)profile;;
- (void) setAnalogStickPositions:(OSCProfile *_Nonnull)profile;
- (void) positionAndResizeSingleControllerLayers:(OSCProfile *_Nonnull)profile;
- (void) resizeControllerLayerWith:(CALayer*_Nonnull)layer and:(CGFloat)sizeFactor;
- (void) adjustControllerLayerOpacityWith:(CALayer*_Nonnull)layer and:(CGFloat)alpha;
+ (CGFloat) getControllerLayerSizeFactor:(CALayer*_Nonnull)layer;
- (CGFloat) getControllerLayerOpacity:(CALayer*_Nonnull)layer;

@end
