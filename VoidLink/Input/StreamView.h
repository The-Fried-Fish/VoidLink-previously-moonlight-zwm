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

@end

#if TARGET_OS_TV
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate>
#else
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate, UIPointerInteractionDelegate>
#endif

@property (assign, nonatomic) UIView* streamFrameTopLayerView;
@property (assign, nonatomic) CGFloat streamAspectRatio;
@property (assign, nonatomic) CGRect originalFrame;


- (void) setupStreamView:(ControllerSupport*)controllerSupport
     interactionDelegate:(id<UserInteractionDelegate>)interactionDelegate
                  config:(StreamConfiguration*)streamConfig
 streamFrameTopLayerView:(UIView* )topLayerView
;
- (void) showOnScreenControls;
- (void) setOnScreenControls;
- (void) disableOnScreenControls;
- (void) reloadOnScreenControlsRealtimeWith:(ControllerSupport*)controllerSupport
                          andConfig:(StreamConfiguration*)streamConfig;
- (void) reloadOnScreenControlsWith:(ControllerSupport*)controllerSupport
                          andConfig:(StreamConfiguration*)streamConfig;
- (void) clearOnScreenKeyboardButtons;
- (void) reloadOnScreenWidgetViews;

- (CGSize) getVideoAreaSize;
- (CGPoint) adjustCoordinatesForVideoArea:(CGPoint)point;
- (uint16_t)getRotationFromAzimuthAngle:(float)azimuthAngle;

- (OnScreenControlsLevel) getCurrentOscState;

-(void)readyToBringUpSoftKeyboardByToolbox;
- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide;

#if !TARGET_OS_TV
- (void) updateCursorLocation:(CGPoint)location isMouse:(BOOL)isMouse;
#endif

@end
