//
//  RelativeTouchHandler.m
//  VoidLink
//
//  Completely refactored by True砖家 on 2024.9.13
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import "RelativeTouchHandler.h"
#import "DataManager.h"
#import "VoidLink-Swift.h"

#include <Limelight.h>


static const float QUICK_TAP_TIME_INTERVAL = 0.2;

@implementation RelativeTouchHandler {
    TemporarySettings* currentSettings;
    CGPoint latestMousePointerLocation, initialMousePointerLocation;
    CGPoint twoFingerTouchLocation;
    NSTimeInterval mousePointerTimestamp;
    CGRect streamViewBounds;
    BOOL firstTouchMoved;
    BOOL mousePointerMoved;
    BOOL quickTapDetected;
    
    // upper screen edge check
    bool touchPointSpawnedAtUpperScreenEdge;
    CGFloat slideGestureVerticalThreshold;
    CGFloat screenWidthWithThreshold;
    CGFloat _edgeTolerance;

    UITouch* touchLockedForMouseMove;
    UITouch* quickTapTouch;

    bool multiTouchesDetected;
    
    CADisplayLink *displayLink;
    
    TouchpadZoomHandler* zoomHandler;
    CursorInertia* cursorInertia; // nil when Cursor Inertia is disabled
    
#if TARGET_OS_TV
    UIGestureRecognizer* remotePressRecognizer;
    UIGestureRecognizer* remoteLongPressRecognizer;
#endif
    
    __weak StreamView* streamView;
}

- (id)initWithView:(StreamView*)view andSettings:(TemporarySettings*)settings {
    self = [self init];
    self->streamView = view;
    self->streamViewBounds = view.bounds;
    self->currentSettings = settings;
    // replace righclick recoginizing with my CustomTapGestureRecognizer for better experience, higher recoginizing rate.
    _mouseRightClickTapRecognizer = [[CustomTapGestureRecognizer alloc] initWithTarget:self action:@selector(mouseRightClick)];
    _mouseRightClickTapRecognizer.numberOfTouchesRequired = 2;
    _mouseRightClickTapRecognizer.tapDownTimeThreshold = RIGHTCLICK_TAP_DOWN_TIME_THRESHOLD_S; // tap down time in seconds.
    _mouseRightClickTapRecognizer.delaysTouchesBegan = NO;
    _mouseRightClickTapRecognizer.delaysTouchesEnded = NO;
    [self->streamView.streamFrameTopLayerView addGestureRecognizer:_mouseRightClickTapRecognizer]; // add all additional gestures to the streamFrameTopLayerView instead of the streamview.
    _mouseRightClickTapRecognizer.touchCapturingView = streamView;
    
    firstTouchMoved = false;
    mousePointerMoved = false;
    mousePointerTimestamp = 0;
    
    // upper screen check
    _edgeTolerance = settings.edgeSlidingSensitivity.floatValue;
    slideGestureVerticalThreshold = CGRectGetHeight([[UIScreen mainScreen] bounds]) * 0.4;
    screenWidthWithThreshold = CGRectGetWidth([[UIScreen mainScreen] bounds]) - _edgeTolerance;
    self->touchPointSpawnedAtUpperScreenEdge = false;
    
    zoomHandler = [[TouchpadZoomHandler alloc] initWithStreamView:view];
    zoomHandler.pinchZoomEnabled = settings.enablePinch && settings.pinchZoom;
    if(settings.cursorInertia){
        __weak TouchpadZoomHandler* weakZoomHandler = zoomHandler;
        cursorInertia = [[CursorInertia alloc] initWithDeceleration:settings.cursorInertiaDeceleration.floatValue handler:^(CGVector delta) {
            [weakZoomHandler moveCursorBy:delta];
        }];
    }
    
    // self->displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    // [self->displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
#if TARGET_OS_TV
    remotePressRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(remoteButtonPressed:)];
    remotePressRecognizer.allowedPressTypes = @[@(UIPressTypeSelect)];
    
    remoteLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(remoteButtonLongPressed:)];
    remoteLongPressRecognizer.allowedPressTypes = @[@(UIPressTypeSelect)];
    
    [self->view addGestureRecognizer:remotePressRecognizer];
    [self->view addGestureRecognizer:remoteLongPressRecognizer];
#endif
    
    return self;
}

// Touch locations are taken from the unzoomed top layer view, so they stay in screen space while the stream view is zoomed or panned.
- (CGPoint)locationOfTouch:(UITouch*)touch {
    UIView* referenceView = streamView.streamFrameTopLayerView ?: streamView;
    return [touch locationInView:referenceView];
}

- (bool)isOnScreenControllerBeingPressed:(NSSet* )touches{
    for(UITouch* touch in touches){
        if([OnScreenControls.touchesCapturedByOnScreenControls containsObject:touch]) return true;
    }
    return false;
}

- (void)mouseRightClick {
    multiTouchesDetected = false;
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
        Log(LOG_D, @"Sending right mouse button press");
        // Wait 100 ms to simulate a real button press
        dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
        });
    });
}

/*
- (BOOL)isConfirmedMove:(CGPoint)currentPoint from:(CGPoint)originalPoint {
    // Movements of greater than 1 point are considered confirmed
    return hypotf(originalPoint.x - currentPoint.x, originalPoint.y - currentPoint.y) >= 1;
}*/

- (BOOL)isAdjacentTouches:(CGPoint)currentPoint from:(CGPoint)originalPoint {
    return hypotf(originalPoint.x - currentPoint.x, originalPoint.y - currentPoint.y) <= 300;
}

- (BOOL)isAdjacentPoints:(CGPoint)currentPoint from:(CGPoint)originalPoint tolerance:(CGFloat)tolerance {
    bool isAdjacent = hypotf(originalPoint.x - currentPoint.x, originalPoint.y - currentPoint.y) <= hypot(tolerance, tolerance);
    return isAdjacent;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    firstTouchMoved = false;
    [cursorInertia stop]; // touching the screen stops a coasting cursor
    
    //check if touch point is spawned on the left or right upper half screen edges, this is the highest priority
    CGPoint initialPoint = [self locationOfTouch:[touches anyObject]];
    if(initialPoint.y < slideGestureVerticalThreshold && (initialPoint.x < _edgeTolerance || initialPoint.x > screenWidthWithThreshold)) {
        self->touchPointSpawnedAtUpperScreenEdge = true;
        return;
    }
    
    touchPointSpawnedAtUpperScreenEdge = false; // reset this flag immediately if we get a touch event passing the check above, this fixes irresponsive touch after closing the command tool menu.
     
    if([UITouchUtil touchesIn:streamView from:event].count>=2){
        multiTouchesDetected = true;
        return;
    }
    
    UITouch* candidateTouch = nil;
    
    // the onscreen controllers are implmented by CALayer, which can not intercept UITouch event, touch will penetrate to the streamView level and captured in the touches callback of this touchHandler class.
    // the onscreen button are UIViews, they intercept UITouch events, so we don't need to worry about them.
    for(UITouch* touch in touches){
        if([OnScreenControls.touchesCapturedByOnScreenControls containsObject:touch]){
            continue;
        }
        else candidateTouch = touch;
    }

    // quick double tap detection for dragging. simulates a real notebook computer touchpad
    CGPoint currentTouchLocation = [self locationOfTouch:candidateTouch];
    
    if([UITouchUtil touchesIn:streamView from:event].count == 1){
        NSTimeInterval tapInterval = CACurrentMediaTime() - mousePointerTimestamp;
        if(tapInterval < QUICK_TAP_TIME_INTERVAL
           && [self isAdjacentTouches:currentTouchLocation from:initialMousePointerLocation]) {
            quickTapDetected = true;
            NSLog(@"quick Tap Detected");
        }
        quickTapTouch = touches.anyObject;
    }
        
    // use [event allTouches] to check if touchLockedForMouseMove is captured, if already captured, don't update touchLockedForMouseMove
    if(candidateTouch != nil && ![[event allTouches] containsObject:touchLockedForMouseMove]){
        touchLockedForMouseMove = candidateTouch;
        // NSLog(@"Candidate touch for mouse movement locked");
        mousePointerTimestamp = CACurrentMediaTime();
        initialMousePointerLocation = latestMousePointerLocation = [self locationOfTouch:touchLockedForMouseMove];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
        
    NSSet* currentTouches = [UITouchUtil touchesIn:streamView from:event];
        
    if(![self isOnScreenControllerBeingPressed:currentTouches]) [TouchPadGestureHandler handleGestureIn:streamView with:event zoomHandler:zoomHandler];
         
    if(multiTouchesDetected) return;
    
    if([touches containsObject:touchLockedForMouseMove]){
        CGPoint currentLocation = [self locationOfTouch:touchLockedForMouseMove];
        bool isAdjacentPoints = [self isAdjacentPoints:initialMousePointerLocation from:currentLocation tolerance:currentSettings.singleTapSensitivity.doubleValue];
        if(!mousePointerMoved && !isAdjacentPoints){
            mousePointerMoved = true;
        }
        [self sendMouseMoveEvent:currentLocation timestamp:touchLockedForMouseMove.timestamp];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if(TouchPadGestureHandler.ctrlDown) LiSendKeyboardEvent(CommandManager.keyboardButtonMappings[@"CTRL"].shortValue,KEY_ACTION_UP,0);
    
    [TouchPadGestureHandler startInertialScroll];
    
    if(multiTouchesDetected){
        if([UITouchUtil touchesIn:streamView from:event].count == touches.count){
            multiTouchesDetected = false;
        }
        return;
    }
    if([UITouchUtil touchesIn:streamView from:event].count == touches.count) multiTouchesDetected = false;

    if([touches containsObject:touchLockedForMouseMove]){
        // let the cursor coast after a flick, but not after a tap or a double-tap drag
        if(mousePointerMoved && firstTouchMoved && !self->quickTapDetected && !touchPointSpawnedAtUpperScreenEdge){
            [cursorInertia liftOffAt:touchLockedForMouseMove.timestamp];
        }
        
        // dealing with a single first tap, whether the button will be released, is going to be decided in sendLongMouseLeftButtonClickEvent
        if(!mousePointerMoved && !self->quickTapDetected) [self sendLongMouseLeftButtonClickEvent];
        
        // dealing with a second quick tap following the first tap:
        if(self->quickTapDetected){
            // we're in at least the second tap release of the very short time interval after the first tap.
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT); // must release the button anyway, because the button is likely being held down since the long click turned into a dragging event.
            if(!mousePointerMoved) [self sendShortMouseLeftButtonClickEvent]; // if it is a quick tap and the pointer was not moved, we must send another click to simulate double click.
            self->quickTapDetected = false; // reset flag
        }
        touchLockedForMouseMove = nil;
        mousePointerMoved = false;
    }
    
    for(UITouch* touch in touches){
        [OnScreenControls.touchesCapturedByOnScreenControls removeObject:touch];
    }
        
    if([UITouchUtil touchesIn:streamView from:event].count == [touches count]){
        touchLockedForMouseMove = nil;
        mousePointerMoved = false; // need to reset this anyway
    }
        
    touchPointSpawnedAtUpperScreenEdge = false;
}

// Runs on the main thread: TouchpadZoomHandler may need to pan the zoomed stream view.
// It converts the delta into relative mouse movement, or absolute cursor positions while zoomed.
- (void)sendMouseMoveEvent:(CGPoint)currentLocation timestamp:(NSTimeInterval)timestamp{
    bool isAdjacentPoints = [self isAdjacentPoints:initialMousePointerLocation from:currentLocation tolerance:currentSettings.relativeTouchSlideThreshold.floatValue];

    if (!firstTouchMoved && !isAdjacentPoints) {
        latestMousePointerLocation = currentLocation;
        firstTouchMoved = true;
    }
    
    CGFloat velocityFactor = currentSettings.mousePointerVelocityFactor.floatValue;
    CGVector delta = CGVectorMake((currentLocation.x - latestMousePointerLocation.x) * velocityFactor,
                                  (currentLocation.y - latestMousePointerLocation.y) * velocityFactor);
    latestMousePointerLocation = currentLocation;
    
    if(touchPointSpawnedAtUpperScreenEdge) return; // we're done here. this touch event will not be sent to the remote PC.
    if(!firstTouchMoved || (delta.dx == 0 && delta.dy == 0)) return;
    
    [zoomHandler moveCursorBy:delta];
    [cursorInertia recordMove:delta timestamp:timestamp];
}

// this will turn into a dragging anytime...
- (void)sendLongMouseLeftButtonClickEvent{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        // if (!self->isDragging){
        Log(LOG_D, @"Sending left mouse button press");
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
        
        // Wait 100 ms to simulate a real button press
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(QUICK_TAP_TIME_INTERVAL * NSEC_PER_SEC));
        dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if(!self->quickTapDetected){
                LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
            }
            // else NSLog(@"Left mouse button release cancelled, keep pressing down, turning into dragging...");
        });
        // do not release the button if we're still dragging, this will prevent the dragging from being interrupted.
    });
}

- (void)sendShortMouseLeftButtonClickEvent{
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC));
    dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
        dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
        });
    });
}



#if TARGET_OS_TV
- (void)remoteButtonPressed:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        Log(LOG_D, @"Sending left mouse button press");
        
        // Mark this as touchMoved to avoid a duplicate press on touch up
        self->touchMoved = true;
        
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
        
        // Wait 100 ms to simulate a real button press
        usleep(100 * 1000);
            
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    });
}
- (void)remoteButtonLongPressed:(id)sender {
    Log(LOG_D, @"Holding left mouse button");
    
    isDragging = true;
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
}
#endif

@end
