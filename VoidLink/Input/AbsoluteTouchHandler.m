//
//  AbsoluteTouchHandler.m
//  Moonlight
//
//  Created by Cameron Gutman on 11/1/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved
//
//  Modified by True砖家 since 2024.6.1
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved
//

#import "AbsoluteTouchHandler.h"

#include <Limelight.h>

// How long the fingers must be stationary to start a right click
#define LONG_PRESS_ACTIVATION_DELAY 0.650f

// How far the finger can move before it cancels a right click
#define LONG_PRESS_ACTIVATION_DELTA 0.02f

// How long the double tap deadzone stays in effect between touch up and touch down
#define DOUBLE_TAP_DEAD_ZONE_DELAY 0.250f

// How far the finger can move before it can override the double tap deadzone
#define DOUBLE_TAP_DEAD_ZONE_DELTA 0.025f

@implementation AbsoluteTouchHandler {
    StreamView* streamView;
    
    NSTimer* longPressTimer;
    UITouch* lastTouchDown;
    CGPoint lastTouchDownLocation;
    UITouch* lastTouchUp;
    CGPoint lastTouchUpLocation;
    
    UITouch* capturedTouch;
    
    CGPoint touchBeganLocation;
    CGPoint movingTouchLocation;

    NSTimeInterval touchBeganTimeStamp;
    NSTimeInterval leftClickTimeThreshold;
    
    // upper screen edge check
    bool touchPointSpawnedAtUpperScreenEdge;
    CGFloat slideGestureVerticalThreshold;
    CGFloat screenWidthWithThreshold;
    CGFloat _edgeTolerance;
    
    bool _delayMouseLeftClick;
    bool dragButtonDown;
    
    bool rightButtonClicked;
}

- (id)initWithView:(StreamView*)view andSettings:(TemporarySettings*)settings {
    self = [self init];
    self->streamView = view;
    
    // _delayMouseLeftClick = settings.delayLeftClick;
    _delayMouseLeftClick = true; // deprecate legacy absolute touch
    dragButtonDown = false;

    leftClickTimeThreshold = 0.15;
    
    // upper screen check
    _edgeTolerance = settings.edgeSlidingSensitivity.floatValue;
    slideGestureVerticalThreshold = CGRectGetHeight([[UIScreen mainScreen] bounds]) * 0.4;
    screenWidthWithThreshold = CGRectGetWidth([[UIScreen mainScreen] bounds]) - _edgeTolerance;
    self->touchPointSpawnedAtUpperScreenEdge = false;
    
    _mouseButtonForCursorMove = BUTTON_LEFT;
    
    return self;
}

- (void)onLongPressStart:(NSTimer*)timer {
    // Raise the left click and start a right click
    if([self touchDidntMoveOnScreen:movingTouchLocation]){
        if(_delayMouseLeftClick){
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
            if(_mouseButtonForCursorMove!=BUTTON_LEFT) LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, _mouseButtonForCursorMove);
        }
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
        dispatch_time_t delayShort = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC));
        dispatch_after(delayShort, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
            self->rightButtonClicked = true;
        });
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    rightButtonClicked = false;
    
    CGPoint initialPoint = [[touches anyObject] locationInView:streamView];
    if(initialPoint.y < slideGestureVerticalThreshold && (initialPoint.x < _edgeTolerance || initialPoint.x > screenWidthWithThreshold)) {
        self->touchPointSpawnedAtUpperScreenEdge = true;
        return; // we're done here. this touch event will not be sent to the remote PC.
    }
    
    touchPointSpawnedAtUpperScreenEdge = false; // reset this flag immediately if we get a touch event passing the check above, this fixes irresponsive touch after closing the command tool menu.

    // Ignore touch down events with more than one finger
    /*
    if ([[event allTouches] count] > 1) {
        return;
    }*/
    
    capturedTouch = [touches anyObject];
    CGPoint touchLocation = [capturedTouch locationInView:streamView];
    
    touchBeganTimeStamp = capturedTouch.timestamp;
    
    // Don't reposition for finger down events within the deadzone. This makes double-clicking easier.
    if (capturedTouch.timestamp - lastTouchUp.timestamp > DOUBLE_TAP_DEAD_ZONE_DELAY ||
        sqrt(pow((touchLocation.x / streamView.bounds.size.width) - (lastTouchUpLocation.x / streamView.bounds.size.width), 2) +
             pow((touchLocation.y / streamView.bounds.size.height) - (lastTouchUpLocation.y / streamView.bounds.size.height), 2)) > DOUBLE_TAP_DEAD_ZONE_DELTA) {
        [streamView updateCursorLocation:touchLocation isMouse:NO];
    }
    
    // Press the left button down
    if(!_delayMouseLeftClick){
        // _delayMouseLeftClick will always be true.
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT); //deprecated
    }
    
    // Start the long press timer
    longPressTimer = [NSTimer scheduledTimerWithTimeInterval:LONG_PRESS_ACTIVATION_DELAY
                                                      target:self
                                                    selector:@selector(onLongPressStart:)
                                                    userInfo:nil
                                                     repeats:NO];
    
    lastTouchDown = capturedTouch;
    lastTouchDownLocation = touchLocation;
    movingTouchLocation = touchLocation;
    touchBeganLocation = touchLocation;
}

- (void)pauseLeftButtonDrag{
    if(dragButtonDown){
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC));
        dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, self->_mouseButtonForCursorMove);
        });
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if(touchPointSpawnedAtUpperScreenEdge) return; // we're done here. this touch event will not be sent to the remote PC.
    
    // Ignore touch move events with more than one finger
    /*
    if ([[event allTouches] count] > 1) {
        return;
    }*/
    
    if(![touches containsObject:capturedTouch]) return;
    
    movingTouchLocation = [capturedTouch locationInView:streamView];
    
    if (sqrt(pow((movingTouchLocation.x / streamView.bounds.size.width) - (lastTouchDownLocation.x / streamView.bounds.size.width), 2) +
             pow((movingTouchLocation.y / streamView.bounds.size.height) - (lastTouchDownLocation.y / streamView.bounds.size.height), 2)) > LONG_PRESS_ACTIVATION_DELTA) {
        // Moved too far since touch down. Cancel the long press timer.
        [longPressTimer invalidate];
        longPressTimer = nil;
        
        if(_delayMouseLeftClick && (CACurrentMediaTime()-touchBeganTimeStamp>leftClickTimeThreshold) && !dragButtonDown){
            LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, _mouseButtonForCursorMove);
            dragButtonDown = true;
        }
    }
    
   if(!rightButtonClicked) [streamView updateCursorLocation:movingTouchLocation isMouse:NO];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if(touchPointSpawnedAtUpperScreenEdge) return; // we're done here. this touch event will not be sent to the remote PC.

    // Only fire this logic if all touches have ended
    if ([touches containsObject:capturedTouch]) {
        // Cancel the long press timer
        [longPressTimer invalidate];
        longPressTimer = nil;
        
        // Remember this last touch for touch-down deadzoning
        CGPoint touchEndLocation = [capturedTouch locationInView:streamView];
        
        if(_delayMouseLeftClick){
            if(CACurrentMediaTime()-touchBeganTimeStamp<leftClickTimeThreshold) {
                if(CACurrentMediaTime()-lastTouchUp.timestamp<0.15
                   && ![self isAdjacentPoints:touchEndLocation from:lastTouchUpLocation tolerance:30]) [streamView updateCursorLocation:touchEndLocation isMouse:NO];
                if([self touchDidntMoveOnScreen:touchEndLocation] && !rightButtonClicked) [self sendShortMouseLeftButtonClickEvent];
            }
            else if(!rightButtonClicked){
                    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
                    if(_mouseButtonForCursorMove!=BUTTON_LEFT) LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, _mouseButtonForCursorMove);
                    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
            }
        }
        else{ // deprecated
            /*
            // Left button up on finger up
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);

            // Raise right button too in case we triggered a long press gesture
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT); */
        }
        
        lastTouchUp = [touches anyObject];
        lastTouchUpLocation = [lastTouchUp locationInView:streamView];
        
        dragButtonDown = false;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // Treat this as a normal touchesEnded event
    [self touchesEnded:touches withEvent:event];
}

- (void)sendShortMouseLeftButtonClickEvent{
    dispatch_time_t delayShort = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC));
    dispatch_time_t delayLong = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC));
    dispatch_after(delayShort, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
        dispatch_after(delayLong, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
        });
    });
}

- (bool)touchDidntMoveOnScreen:(CGPoint)touchLocation{
    return [self isAdjacentPoints:touchLocation from:touchBeganLocation tolerance:3];
}

- (BOOL)isAdjacentPoints:(CGPoint)currentPoint from:(CGPoint)originalPoint tolerance:(CGFloat)tolerance {
    bool isAdjacent = hypotf(originalPoint.x - currentPoint.x, originalPoint.y - currentPoint.y) <= hypot(tolerance, tolerance);
    return isAdjacent;
}


@end
