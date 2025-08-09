//
//  RelativeTouchHandler.m
//  Moonlight
//
//  Completely refactored by True砖家 on 2024.9.13
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import "RelativeTouchHandler.h"
#import "DataManager.h"

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
    BOOL isInMouseWheelScrollingMode;
    
    // upper screen edge check
    bool touchPointSpawnedAtUpperScreenEdge;
    CGFloat slideGestureVerticalThreshold;
    CGFloat screenWidthWithThreshold;
    CGFloat EDGE_TOLERANCE;

    UITouch* touchLockedForMouseMove;
    
#if TARGET_OS_TV
    UIGestureRecognizer* remotePressRecognizer;
    UIGestureRecognizer* remoteLongPressRecognizer;
#endif
    
    StreamView* streamView;
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
    
    isInMouseWheelScrollingMode = false;
    firstTouchMoved = false;
    mousePointerMoved = false;
    mousePointerTimestamp = 0;
    
    // upper screen check
    EDGE_TOLERANCE = 10.0;
    slideGestureVerticalThreshold = CGRectGetHeight([[UIScreen mainScreen] bounds]) * 0.4;
    screenWidthWithThreshold = CGRectGetWidth([[UIScreen mainScreen] bounds]) - EDGE_TOLERANCE;
    self->touchPointSpawnedAtUpperScreenEdge = false;
    
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

- (bool)isOnScreenControllerBeingPressed:(NSSet* )touches{
    for(UITouch* touch in touches){
        if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) return true;
    }
    return false;
}


- (bool)isOnScreenWidgetViewBeingPressed {
    bool gotOneButtonPressed = false;
    for(UIView* view in self->streamView.superview.subviews){  // iterates all on-screen widget views in StreamFrameView
        if ([view isKindOfClass:[OnScreenWidgetView class]]) {
            OnScreenWidgetView* widgetView = (OnScreenWidgetView*) view;
            if(widgetView.pressed){
                gotOneButtonPressed = true; //got one button pressed
            }
        }
    }
    return gotOneButtonPressed;
}

- (void)resetAllPressedFlagsForOnScreenWidgetViews {
    for(UIView* view in self->streamView.superview.subviews){  // iterates all on-screen widget views in StreamFrameView
        if ([view isKindOfClass:[OnScreenWidgetView class]]) {
            OnScreenWidgetView* widgetView = (OnScreenWidgetView*) view;
            widgetView.pressed = false;
        }
    }
}


- (void)mouseRightClick {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        Log(LOG_D, @"Sending right mouse button press");
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
        // Wait 100 ms to simulate a real button press
        usleep(100 * 1000);
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
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


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    //check if touch point is spawned on the left or right upper half screen edges, this is the highest priority
    CGPoint initialPoint = [[touches anyObject] locationInView:streamView];
    if(initialPoint.y < slideGestureVerticalThreshold && (initialPoint.x < EDGE_TOLERANCE || initialPoint.x > screenWidthWithThreshold)) {
        self->touchPointSpawnedAtUpperScreenEdge = true;
        return;
    }
    
    firstTouchMoved = false;
    touchPointSpawnedAtUpperScreenEdge = false; // reset this flag immediately if we get a touch event passing the check above, this fixes irresponsive touch after closing the command tool menu.
    
    if([[event allTouches] count] == 2 && ![self isOnScreenWidgetViewBeingPressed] && ![self isOnScreenControllerBeingPressed:[event allTouches]]){
        NSLog(@"get in scrolling mode");
        isInMouseWheelScrollingMode = true;
        return; // if we got 2 touches on the blank area, it's gonna be a mouse scroll touch, and must prevent UITtouch object for mouse pointer being captured & locked
    }
    
    // NSLog(@"touches count in began stage: %llu", (uint64_t)[touches count]);
    
    UITouch* candidateTouch = nil;
    
    // the onscreen controllers are implmented by CALayer, which can not intercept UITouch event, touch will penetrate to the streamView level and captured in the touches callback of this touchHandler class.
    // the onscreen button are UIViews, they intercept UITouch events, so we don't need to worry about them.
    for(UITouch* touch in touches){
        // NSLog(@"candidate touch test: %llu", (uint64_t)touch);
        if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]){
            // NSLog(@"%f controller tap detected", CACurrentMediaTime());
            continue;
        }
        else candidateTouch = touch;
    }

    // quick double tap detection for dragging. simulates a real notebook computer touchpad
    CGPoint currentTouchLocation = [candidateTouch locationInView:streamView];
    NSTimeInterval tapInterval = CACurrentMediaTime() - mousePointerTimestamp;
    if(tapInterval < QUICK_TAP_TIME_INTERVAL && [self isAdjacentTouches:currentTouchLocation from:initialMousePointerLocation] ) {
        // NSLog(@"quick click detected");
        quickTapDetected = true;
        NSLog(@"quick Tap Detected");
        // LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT); // do not press down mouse button here, or it wiil easily turn to double click on remote PC
    }

    // we must use [event allTouches] to check if touchLockedForMouseMove is captured, because the UITouch object could be captured by upper layer of UIView(in cases like tap gestures), not passed to the touches callbacks in this class, but still available in [event allTouches]
    if(candidateTouch != nil && ![[event allTouches] containsObject:touchLockedForMouseMove]){
        touchLockedForMouseMove = candidateTouch;
        // NSLog(@"Candidate touch for mouse movement locked");
        mousePointerTimestamp = CACurrentMediaTime();
        initialMousePointerLocation = latestMousePointerLocation = [touchLockedForMouseMove locationInView:streamView];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    //NSLog(@"%f, touchesMoved callback, is scrolling: %d, touches count: %d", CACurrentMediaTime(), isInMouseWheelScrollingMode, (uint32_t)[touches count]);
    
    if(isInMouseWheelScrollingMode && [[event allTouches] count] == 2 && ![self isOnScreenWidgetViewBeingPressed] && ![self isOnScreenControllerBeingPressed:touches]){
        NSSet* twoTouches = [event allTouches];
        CGPoint firstLocation = [[[twoTouches allObjects] objectAtIndex:0] locationInView:streamView];
        CGPoint secondLocation = [[[twoTouches allObjects] objectAtIndex:1] locationInView:streamView];
        
        CGPoint avgLocation = CGPointMake((firstLocation.x + secondLocation.x) / 2, (firstLocation.y + secondLocation.y) / 2);
        if ((CACurrentMediaTime() - _mouseRightClickTapRecognizer.gestureCapturedTime > RIGHTCLICK_TAP_DOWN_TIME_THRESHOLD_S) && twoFingerTouchLocation.y != avgLocation.y) { //prevent sending scrollevent while right click gesture is being recognized. The time threshold is only 150ms, resulting in a barely noticeable delay before the scroll event is activated.
            // and we must exclude onscreen button taps & on-screen controller taps
            LiSendHighResScrollEvent((avgLocation.y - twoFingerTouchLocation.y) * 10);
        }
        twoFingerTouchLocation = avgLocation;
        return;
    }

    // NSLog(@"%f touchesMoved callback, locked touch: %llu", CACurrentMediaTime(), (uintptr_t)touchLockedForMouseMove);
    
    if([touches containsObject:touchLockedForMouseMove]){
        mousePointerMoved = true;
        [self sendMouseMoveEvent:touchLockedForMouseMove];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if(isInMouseWheelScrollingMode){
        isInMouseWheelScrollingMode = false;
        return;
    }
    
    if([touches containsObject:touchLockedForMouseMove]){
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
    
    if([[event allTouches] count] == [touches count]){
        isInMouseWheelScrollingMode = false;
        touchLockedForMouseMove = nil;
        mousePointerMoved = false; // need to reset this anyway
        [self resetAllPressedFlagsForOnScreenWidgetViews]; // reset all pressed flag for on-screen widget views after all fingers lifted from screen.
    }
    
    touchPointSpawnedAtUpperScreenEdge = false;
}


- (void)sendMouseMoveEvent:(UITouch* )touch{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        if(self->touchPointSpawnedAtUpperScreenEdge) return; // we're done here. this touch event will not be sent to the remote PC.
        
        CGPoint currentLocation = [touch locationInView:self->streamView];
        
        if (!self->firstTouchMoved) {
            self->latestMousePointerLocation = currentLocation;
            self->firstTouchMoved = true;
        }
        
        if (self->latestMousePointerLocation.x != currentLocation.x ||
            self->latestMousePointerLocation.y != currentLocation.y)
        {
            int deltaX = (currentLocation.x - self->latestMousePointerLocation.x) * 1.35 * self->currentSettings.mousePointerVelocityFactor.floatValue;
            int deltaY = (currentLocation.y - self->latestMousePointerLocation.y) * 1.35 * self->currentSettings.mousePointerVelocityFactor.floatValue;
            
            if (deltaX != 0 || deltaY != 0) {
                LiSendMouseMoveEvent(deltaX, deltaY);
                self->latestMousePointerLocation = currentLocation;
            }
        }
    });
}


// this will turn into a dragging anytime...
- (void)sendLongMouseLeftButtonClickEvent{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        // if (!self->isDragging){
        Log(LOG_D, @"Sending left mouse button press");
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
        // Wait 100 ms to simulate a real button press
        usleep(QUICK_TAP_TIME_INTERVAL * 1000000);
        if(!self->quickTapDetected){
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
        }
        // else NSLog(@"Left mouse button release cancelled, keep pressing down, turning into dragging...");

        // do not release the button if we're still dragging, this will prevent the dragging from being interrupted.
    });
}

- (void)sendShortMouseLeftButtonClickEvent{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        usleep(50 * 1000);
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
        usleep(50 * 1000);
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
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
