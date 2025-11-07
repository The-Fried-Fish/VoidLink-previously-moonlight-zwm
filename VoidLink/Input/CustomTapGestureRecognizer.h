//
//  CustomTapGestureRecognizer.h
//  VoidLink
//
//  Created by True砖家 on 2024/5/15.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#ifndef CustomTapGestureRecognizer_h
#define CustomTapGestureRecognizer_h


@interface CustomTapGestureRecognizer : UIGestureRecognizer{
    CGFloat lowestTouchPointYCoord;
}

@property (nonatomic, weak) UIView* touchCapturingView;
@property (nonatomic, assign) uint8_t numberOfTouchesRequired;
@property (nonatomic, assign) bool immediateTriggering; // if enabled,  trigger the signal on touchesBegan stage.
@property (nonatomic, assign) double tapDownTimeThreshold; // tap down threshold in seconds.
@property (nonatomic, assign) bool isOnScreenControllerBeingPressed; // will be set by the onscreencontrol class
//@property (nonatomic, assign) bool haveOnScreenButtonsOnStreamview;
@property (nonatomic, readonly) CGFloat lowestTouchPointHeight;
@property (nonatomic, readonly) bool gestureCaptured;
@property (nonatomic, readonly) NSTimeInterval gestureCapturedTime;

@end
#endif /* CustomTapGestureRecognizer_h */
