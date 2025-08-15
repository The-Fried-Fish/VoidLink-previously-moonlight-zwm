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
#define LONG_PRESS_ACTIVATION_DELTA 0.01f

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
    
    // upper screen edge check
    bool touchPointSpawnedAtUpperScreenEdge;
    CGFloat slideGestureVerticalThreshold;
    CGFloat screenWidthWithThreshold;
    CGFloat EDGE_TOLERANCE;

}

- (id)initWithView:(StreamView*)view {
    self = [self init];
    self->streamView = view;
    
    // upper screen check
    EDGE_TOLERANCE = 10.0;
    slideGestureVerticalThreshold = CGRectGetHeight([[UIScreen mainScreen] bounds]) * 0.4;
    screenWidthWithThreshold = CGRectGetWidth([[UIScreen mainScreen] bounds]) - EDGE_TOLERANCE;
    self->touchPointSpawnedAtUpperScreenEdge = false;
    
    return self;
}

- (void)onLongPressStart:(NSTimer*)timer {
    // Raise the left click and start a right click
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    CGPoint initialPoint = [[touches anyObject] locationInView:streamView];
    if(initialPoint.y < slideGestureVerticalThreshold && (initialPoint.x < EDGE_TOLERANCE || initialPoint.x > screenWidthWithThreshold)) {
        self->touchPointSpawnedAtUpperScreenEdge = true;
        return; // we're done here. this touch event will not be sent to the remote PC.
    }
    
    touchPointSpawnedAtUpperScreenEdge = false; // reset this flag immediately if we get a touch event passing the check above, this fixes irresponsive touch after closing the command tool menu.

    // Ignore touch down events with more than one finger
    if ([[event allTouches] count] > 1) {
        return;
    }
    
    UITouch* touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:streamView];
    
    // Don't reposition for finger down events within the deadzone. This makes double-clicking easier.
    if (touch.timestamp - lastTouchUp.timestamp > DOUBLE_TAP_DEAD_ZONE_DELAY ||
        sqrt(pow((touchLocation.x / streamView.bounds.size.width) - (lastTouchUpLocation.x / streamView.bounds.size.width), 2) +
             pow((touchLocation.y / streamView.bounds.size.height) - (lastTouchUpLocation.y / streamView.bounds.size.height), 2)) > DOUBLE_TAP_DEAD_ZONE_DELTA) {
        [streamView updateCursorLocation:touchLocation isMouse:NO];
    }
    
    // Press the left button down
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
    
    // Start the long press timer
    longPressTimer = [NSTimer scheduledTimerWithTimeInterval:LONG_PRESS_ACTIVATION_DELAY
                                                      target:self
                                                    selector:@selector(onLongPressStart:)
                                                    userInfo:nil
                                                     repeats:NO];
    
    lastTouchDown = touch;
    lastTouchDownLocation = touchLocation;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if(touchPointSpawnedAtUpperScreenEdge) return; // we're done here. this touch event will not be sent to the remote PC.
    
    // Ignore touch move events with more than one finger
    if ([[event allTouches] count] > 1) {
        return;
    }
    
    UITouch* touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:streamView];
    
    if (sqrt(pow((touchLocation.x / streamView.bounds.size.width) - (lastTouchDownLocation.x / streamView.bounds.size.width), 2) +
             pow((touchLocation.y / streamView.bounds.size.height) - (lastTouchDownLocation.y / streamView.bounds.size.height), 2)) > LONG_PRESS_ACTIVATION_DELTA) {
        // Moved too far since touch down. Cancel the long press timer.
        [longPressTimer invalidate];
        longPressTimer = nil;
    }
    
    [streamView updateCursorLocation:[[touches anyObject] locationInView:streamView] isMouse:NO];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if(touchPointSpawnedAtUpperScreenEdge) return; // we're done here. this touch event will not be sent to the remote PC.

    // Only fire this logic if all touches have ended
    if ([[event allTouches] count] == [touches count]) {
        // Cancel the long press timer
        [longPressTimer invalidate];
        longPressTimer = nil;

        // Left button up on finger up
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);

        // Raise right button too in case we triggered a long press gesture
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
        
        // Remember this last touch for touch-down deadzoning
        lastTouchUp = [touches anyObject];
        lastTouchUpLocation = [lastTouchUp locationInView:streamView];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // Treat this as a normal touchesEnded event
    [self touchesEnded:touches withEvent:event];
}

@end
