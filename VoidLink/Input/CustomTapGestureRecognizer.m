//
//  CustomTapGestureRecognizer.m
//  VoidLink
//
//  Created by True砖家 on 2024/5/15.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "CustomTapGestureRecognizer.h"
#import "VoidLink-Swift.h"

// The most accurate & reliable tap gesture recognizer of iOS:
// - Almost 100% recoginition rate. UITapGestureRecognizer of Apple API fails frequently, just a piece of crap.
// - When immediateTriggering is set to false (for native multi-touch):
//   Gesture signal will be triggered on touchesEnded stage, multi finger touch operations will not be interrupted by the arising keyboard.
//   Instances of different [numberOfTouchesRequired] barely compete with each other, for example, the chance of 3-finger gesture get triggered by 4 or 5 finger tap is very small.
// - Set property immediateTriggering to true, to ensure the priority of keyboard toggle in non-native touch mode, in compete with 2-finger gestures.
// - This recognizer also provides properties like gestureCapturedTime, to be accessed outside the class for useful purpose.

@implementation CustomTapGestureRecognizer

static CGFloat screenHeightInPoints;
static CGFloat screenWidthInPoints;

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action {
    self = [super initWithTarget:target action:action];
    screenHeightInPoints = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    screenWidthInPoints = CGRectGetWidth([[UIScreen mainScreen] bounds]);
    lowestTouchPointYCoord = 0.0;
    _numberOfTouchesRequired = 3;
    _immediateTriggering = false;
    _tapDownTimeThreshold = 0.3;
    _gestureCaptured = false;
    _isOnScreenControllerBeingPressed = false;
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // Check if the number of touches and taps meets the required criteria
    if ([[event allTouches] count] == _numberOfTouchesRequired) {
        _gestureCapturedTime = CACurrentMediaTime();
        _gestureCaptured = true;
        for(UITouch *touch in [event allTouches]){
            if(lowestTouchPointYCoord < [touch locationInView:self.view].y) lowestTouchPointYCoord = [touch locationInView:self.view].y;
        }
        
        // this mechanism is deprecated.
        /* if(_numberOfTouchesRequired == 2){
            NSArray *twoTouches = [[event allTouches] allObjects];
            _areVirtualControllerTaps = fabs([twoTouches[1] locationInView:self.view].x - [twoTouches[0] locationInView:self.view].x) > screenWidthInPoints/3;
        } */
        
        _lowestTouchPointHeight = screenHeightInPoints - lowestTouchPointYCoord;
        // NSLog(@"gen _lowestTouchPointHeight %f markmark", _lowestTouchPointHeight);
        if(_immediateTriggering){
            lowestTouchPointYCoord = 0.0; //reset for next recoginition
            self.state = UIGestureRecognizerStateRecognized;
            return;
        }
        self.state = UIGestureRecognizerStatePossible;
    }
    if ([[event allTouches] count] > _numberOfTouchesRequired) {
        _gestureCaptured = false;
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // [super touchesEnded:touches withEvent:event];
    if(OnScreenWidgetView.tapGestureShallBeCancelled){
        self.state = UIGestureRecognizerStateFailed;
        OnScreenWidgetView.tapGestureShallBeCancelled = false;
        return;
    }
    
    if(_immediateTriggering) return;
    uint8_t allTouchesCount = [[event allTouches] count];
    if(allTouchesCount > _numberOfTouchesRequired) {
        _gestureCaptured = false;
        self.state = UIGestureRecognizerStateFailed;
    }
    else if(_gestureCaptured && allTouchesCount == [touches count] && !_isOnScreenControllerBeingPressed){  //must exclude virtual controller & onscreen button taps here to prevent stucked button, _areVirtualControllerTaps flag is set by onscreencontrols, containOnScreenButtonsTaps will be returned by iterating all widget views in streamframeview
        _gestureCaptured = false; //reset for next recognition
        if((CACurrentMediaTime() - _gestureCapturedTime) < _tapDownTimeThreshold){
            lowestTouchPointYCoord = 0.0; //reset for next recognition
            self.state = UIGestureRecognizerStateRecognized;
            // NSLog(@"gen _lowestTouchPointHeight %f markmark touchesEnd", _lowestTouchPointHeight);
        }
    }
    if (allTouchesCount == [touches count]){
        _isOnScreenControllerBeingPressed = false; // need to reset this flag anyway, when all fingers are lefting
        OnScreenWidgetView.tapGestureShallBeCancelled = false;
    }
}

@end
