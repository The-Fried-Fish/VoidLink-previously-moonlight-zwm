//
//  StreamView.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.16
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.


//

#import "ControllerSupport.h"
#import "OnScreenControls.h"
#import "VoidLink-Swift.h"
#import "StreamConfiguration.h"

@protocol UserInteractionDelegate <NSObject>

- (void)userInteractionBegan;
- (void)userInteractionEnded;
- (void)streamExitRequested;
- (void)toggleStatsOverlay;
- (void)toggleMouseCapture;
- (void)toggleMouseVisible;
- (void)disconnectAndQuitApp;

@end

#if TARGET_OS_TV
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate>
#else
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate, UIPointerInteractionDelegate>
#endif

@property (weak, nonatomic) UIView* streamFrameTopLayerView;
@property (weak, nonatomic) id<UserInteractionDelegate> interactionDelegate;
@property (assign, nonatomic) CGFloat streamAspectRatio;
@property (assign, nonatomic) CGRect originalFrame;
@property (assign, nonatomic) bool widgetToolOpened;
@property (strong, nonatomic) OnScreenControls* onScreenControls;
@property (weak, nonatomic) PencilHandler* pencilHandler;
@property (weak, nonatomic) UIViewController* streamFrameVC;

- (void) setupStreamViewWithControllerSupport:(ControllerSupport*)controllerSupport
                          interactionDelegate:(id<UserInteractionDelegate>)interactionDelegate
                                 streamConfig:(StreamConfiguration*)streamConfig
                                  gameProfile:(OSCProfile* )profile
                      streamFrameTopLayerView:(UIView* )topLayerView
;

- (void)cleanUp;

- (void) reloadLegacyWidgets:(OSCProfile* )profile;
- (void) setOnScreenControls;
- (void) disableOnScreenControls;
- (void) reloadOnScreenControlsRealtimeWithControllerSupport:(ControllerSupport*)controllerSupport
                          streamConfig:(StreamConfiguration*)streamConfig;
- (void) reloadOnScreenControlsWith:(ControllerSupport*)controllerSupport
                          andConfig:(StreamConfiguration*)streamConfig;
- (void) clearOnScreenWidgets;
- (void) reloadGameProfile:(OSCProfile* )profile reloadWidgets:(bool)reloadWidgets;
- (void) saveStreamViewWidgetChanges;
- (bool) isOnScreenWidgetEnabled;

- (CGSize) getVideoAreaSize;
- (CGPoint) adjustCoordinatesForVideoArea:(CGPoint)point;
- (uint16_t)getRotationFromAzimuthAngle:(float)azimuthAngle;

- (OnScreenControlsLevel) getCurrentOscState;

- (void)readyToBringUpSoftKeyboardByToolbox;
- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide;
- (void)handleAbnormalKeyboards:(NSNotification *)notification;
- (void)liftMetalVideoViewIfNeeded:(CGFloat)liftHeight;

- (void)alterAbsTouchDragWith:(int32_t)mouseButton;

- (void)enablePencilHover;
- (void)disablePencilHover;
- (void)setAllowSingleTouchEnabled:(BOOL)enabled;
- (void)toggleTouchDisabled:(bool)disabled;

#if !TARGET_OS_TV
- (void) updateCursorLocation:(CGPoint)location isMouse:(BOOL)isMouse;
#endif

@end
