//
//  NativeTouchHandler.m
//  VoidLink
//
//  Created by True砖家 on 2024/6/1.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NativeTouchHandler.h"
#import "NativeTouchPointer.h"
#import "OnScreenControls.h"
#import "StreamView.h"

#include <Limelight.h>


@implementation NativeTouchHandler {
    StreamView* streamView;
    TemporarySettings* currentSettings;
    bool activateCoordSelector;
    CGFloat pointerVelocityDividerLocationByPoints;
    uint16_t touchMoveEventIntervalUs;
    
    bool asyncNativeTouch;
    unsigned int touchDownQos;
    unsigned int touchMoveQos;
    unsigned int touchEndQos;
    
    // Use a Dictionary to store UITouch object's memory address as key, and pointerId as value,字典存放UITouch对象地址和pointerId映射关系
    // pointerId will be generated from a pre-defined pool
    // Use a NSSet store active pointerId,
    NSMutableDictionary *pointerIdDict; //pointerId Dict for active touches.
    NSMutableSet<NSNumber *> *activePointerIds; //pointerId Set for active touches.
    NSMutableSet<NSNumber *> *pointerIdPool; //pre-defined pool of pointerIds.
    NSMutableSet<NSNumber *> *unassignedPointerIds;
    NSMutableSet *blacklistedTouches;

    NSMutableDictionary *pointerObjDict;

    CGFloat slideGestureVerticalThreshold;
    CGFloat screenWidthWithThreshold;
    CGFloat EDGE_TOLERANCE;
    
    CGRect streamViewBounds;
}

- (id)initWithView:(StreamView*)view andSettings:(TemporarySettings*)settings{
    self = [super init];
    self->streamView = view;
    self->currentSettings = settings;
    self->activateCoordSelector = currentSettings.pointerVelocityModeDivider.floatValue != 1.0;
    self->touchMoveEventIntervalUs = currentSettings.touchMoveEventInterval.intValue;
    self->streamViewBounds = view.bounds;
    
    self->pointerIdDict = [NSMutableDictionary dictionary];
    self->pointerIdPool = [NSMutableSet set];
    for (uint8_t i = 0; i <= 10; i++) { //ipadOS supports upto 11 finger touches
        [self->pointerIdPool addObject:@(i)];
    }
    self->activePointerIds = [NSMutableSet set];
    self->blacklistedTouches = [NSMutableSet set];
        
    self->asyncNativeTouch = settings.asyncNativeTouchPriority.intValue != AsyncNativeTouchOff;
    
    switch(settings.asyncNativeTouchPriority.intValue){
        case TouchDownPriority: // deprecated by GUI
            touchDownQos = QOS_CLASS_USER_INTERACTIVE;
            touchMoveQos = QOS_CLASS_USER_INITIATED;
            touchEndQos = QOS_CLASS_USER_INITIATED;
            break;
        case TouchMovePriority: // deprecated by GUI
            touchDownQos = QOS_CLASS_USER_INITIATED;
            touchMoveQos = QOS_CLASS_USER_INTERACTIVE;
            touchEndQos = QOS_CLASS_USER_INITIATED;
            break;
        case EqualPriority: // equals to async touch is true now
            touchDownQos = QOS_CLASS_USER_INTERACTIVE;
            touchMoveQos = QOS_CLASS_USER_INTERACTIVE;
            touchEndQos = QOS_CLASS_USER_INITIATED;
            break;
        default: break;
    }
    
    
    self->pointerObjDict = [NSMutableDictionary dictionary];
    
    EDGE_TOLERANCE = 10.0;
    slideGestureVerticalThreshold = CGRectGetHeight([[UIScreen mainScreen] bounds]) * 0.4;
    screenWidthWithThreshold = CGRectGetWidth([[UIScreen mainScreen] bounds]) - EDGE_TOLERANCE;

    self->pointerVelocityDividerLocationByPoints = self->streamView.bounds.size.width * settings.pointerVelocityModeDivider.floatValue;
    
    [NativeTouchPointer initContextWithView:self->streamView andSettings:settings];
    //_touchesCapturedByOnScreenButtons = [[NSMutableSet alloc] init];
    return self;
}

- (CGSize) getVideoAreaSize {
    if (self->streamViewBounds.size.width > self->streamViewBounds.size.height * streamView.streamAspectRatio) {
        return CGSizeMake(self->streamViewBounds.size.height * streamView.streamAspectRatio, self->streamViewBounds.size.height);
    } else {
        return CGSizeMake(self->streamViewBounds.size.width, self->streamViewBounds.size.width / streamView.streamAspectRatio);
    }
}


- (CGPoint) adjustCoordinatesForVideoArea:(CGPoint)point {
    // These are now relative to the StreamView, however we need to scale them
    // further to make them relative to the actual video portion.
    float x = point.x - self->streamViewBounds.origin.x;
    float y = point.y - self->streamViewBounds.origin.y;
    
    // For some reason, we don't seem to always get to the bounds of the window
    // so we'll subtract 1 pixel if we're to the left/below of the origin and
    // and add 1 pixel if we're to the right/above. It should be imperceptible
    // to the user but it will allow activation of gestures that require contact
    // with the edge of the screen (like Aero Snap).
    if (x < self->streamViewBounds.size.width / 2) {
        x--;
    }
    else {
        x++;
    }
    if (y < self->streamViewBounds.size.height / 2) {
        y--;
    }
    else {
        y++;
    }
    
    // This logic mimics what iOS does with AVLayerVideoGravityResizeAspect
    CGSize videoSize = [self getVideoAreaSize];
    CGPoint videoOrigin = CGPointMake(self->streamViewBounds.size.width / 2 - videoSize.width / 2,
                                      self->streamViewBounds.size.height / 2 - videoSize.height / 2);
    
    // Confine the cursor to the video region. We don't just discard events outside
    // the region because we won't always get one exactly when the mouse leaves the region.
    return CGPointMake(MIN(MAX(x, videoOrigin.x), videoOrigin.x + videoSize.width) - videoOrigin.x,
                       MIN(MAX(y, videoOrigin.y), videoOrigin.y + videoSize.height) - videoOrigin.y);
}


- (uint16_t)getRotationFromAzimuthAngle:(float)azimuthAngle {
    // iOS reports azimuth of 0 when the stylus is pointing west, but Moonlight expects
    // rotation of 0 to mean the stylus is pointing north. Rotate the azimuth angle
    // clockwise by 90 degrees to convert from iOS to Moonlight rotation conventions.
    int32_t rotationAngle = (azimuthAngle - M_PI_2) * (180.f / M_PI);
    if (rotationAngle < 0) {
        rotationAngle += 360;
    }
    return (uint16_t)rotationAngle;
}

// generate & populate pointerId into NSDict & NSSet, called in touchesBegan
- (void)handleTouchDown:(UITouch*)touch{
    //populate pointerId
    NSNumber* touchAddrObj = @((uintptr_t)touch);
    unassignedPointerIds = [pointerIdPool mutableCopy]; //reset unassignedPointerIds
    [unassignedPointerIds minusSet:activePointerIds];
    NSNumber* pointerIdObj = @([[unassignedPointerIds anyObject] unsignedIntValue]);
    [pointerIdDict setObject:pointerIdObj forKey:touchAddrObj];
    [activePointerIds addObject:pointerIdObj];
    
    //check if touch point is spawned on the left or right upper half screen edges, event to remote PC. this is for better handling in-stream slide gesture
    CGPoint initialPoint = [touch locationInView:self->streamView];
    if(initialPoint.y < slideGestureVerticalThreshold && (initialPoint.x < EDGE_TOLERANCE || initialPoint.x > screenWidthWithThreshold)) {
        [blacklistedTouches addObject:touchAddrObj];
    }
}

// remove pointerId in touchesEnded or touchesCancelled
- (void)removePointerId:(UITouch*)touch{
    NSNumber* touchAddrObj = @((uintptr_t)touch);
    NSNumber* pointerIdObj = [pointerIdDict objectForKey:touchAddrObj];
    if(pointerIdObj != nil){
        [activePointerIds removeObject:pointerIdObj];
        [pointerIdDict removeObjectForKey:touchAddrObj];
        // if([excludedPointerIds containsObject:pointerIdObj]) [excludedPointerIds removeObject:pointerIdObj]; // remove pointer id from excludedPointerId NSSet
    }
}

// 从字典中获取UITouch事件对应的pointerId
// called in method of sendTouchEvent
- (uint8_t) retrievePointerIdFromDict:(UITouch*)touch{
    return [[pointerIdDict objectForKey:@((uintptr_t)touch)] unsignedIntValue];
}


- (void)sendTouchEvent:(UITouch*)touch withTouchtype:(uint8_t)touchType{
    //if(touchPointSpawnedAtUpperScreenEdge && touchType != LI_TOUCH_EVENT_UP) return; //  we're done here. this touch event will not be sent to the remote PC. and this must be checked after coord selector finishes populating new relative coords, or the app will crash
    if([blacklistedTouches containsObject:@((uintptr_t)touch)]) return;
    
    CGPoint targetCoords;
    //NSLog(@"selecting coords: %d", touch.phase == UITouchPhaseMoved);
    // NSLog(@"excluded count: %d", (uint32_t)[excludedPointerIds count]);
    
    targetCoords = activateCoordSelector ? [self selectCoordsFor:touch] : [touch locationInView:streamView];

    CGPoint location = [self adjustCoordinatesForVideoArea:targetCoords];
    CGSize videoSize = [self getVideoAreaSize];
    CGFloat normalizedX = location.x / videoSize.width;
    CGFloat normalizedY = location.y / videoSize.height;
    uint8_t pointerId = [self retrievePointerIdFromDict:touch];

    if([self getPointerObjFromDict:touch].needResetCoords){ // access whether the current pointer has reached the boundary, and need a coord reset.
        LiSendTouchEvent(LI_TOUCH_EVENT_UP, pointerId, normalizedX, normalizedY, 0, 0, 0, 0);  //event must sent from the lowest level directy by LiSendTouchEvent to simulate continous dragging to another point on screen
        LiSendTouchEvent(LI_TOUCH_EVENT_DOWN, pointerId, 0.3, 0.4, 0, 0, 0, 0);
    }else LiSendTouchEvent(touchType, pointerId, normalizedX, normalizedY,(touch.force / touch.maximumPossibleForce) / sin(touch.altitudeAngle),0.0f, 0.0f,[self getRotationFromAzimuthAngle:[touch azimuthAngleInView:streamView]]);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (asyncNativeTouch) dispatch_async(dispatch_get_global_queue(touchDownQos, 0), ^{
        for (UITouch* touch in touches){
            // continue to the next loop if current touch is already captured by OSC. works only in regular native touch
            if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) continue;
            [self handleTouchDown:touch]; //generate & populate pointerId
            if(self->activateCoordSelector) [self populatePointerObjIntoDict:touch];
            [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_DOWN];
        }
    });
    else{
        for (UITouch* touch in touches){
            // continue to the next loop if current touch is already captured by OSC. works only in regular native touch
            if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) continue;
            [self handleTouchDown:touch]; //generate & populate pointerId
            if(self->activateCoordSelector) [self populatePointerObjIntoDict:touch];
            [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_DOWN];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (asyncNativeTouch) dispatch_async(dispatch_get_global_queue(touchMoveQos, 0), ^{
        for (UITouch* touch in touches){
            // continue to the next loop if current touch is already captured by OSC. works only in regular native touch
            if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) continue;
            if(self->activateCoordSelector) [self updatePointerObjInDict:touch];
            [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_MOVE];
            [[self getPointerObjFromDict:touch] doesNeedResetCoords]; // execute the judging of doesReachBoundary for current pointer instance. (happens after the event is sent to Sunshine service)
            usleep(self->touchMoveEventIntervalUs);
        }
    });
    else {
        for (UITouch* touch in touches){
            // continue to the next loop if current touch is already captured by OSC. works only in regular native touch
            if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) continue;
            if(self->activateCoordSelector) [self updatePointerObjInDict:touch];
            [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_MOVE];
            [[self getPointerObjFromDict:touch] doesNeedResetCoords]; // execute the judging of doesReachBoundary for current pointer instance. (happens after the event is sent to Sunshine service)
            // usleep(self->touchMoveEventIntervalUs);
        }
    }
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if(asyncNativeTouch) dispatch_async(dispatch_get_global_queue(touchEndQos, 0), ^{
        for (UITouch* touch in touches){
            // continue to the next loop if current touch is already captured by OSC. works only in regular native touch
            if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) continue;
            [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_UP]; //send touch event before remove pointerId
            [self removePointerId:touch]; //then remove pointerId
            if(self->activateCoordSelector) [self removePointerObjFromDict:touch];
            [self->blacklistedTouches removeObject:@((uintptr_t)touch)];
        }
        //if(self->touchPointSpawnedAtUpperScreenEdge && [[event allTouches] count] == [touches count])
    });
    else{
        for (UITouch* touch in touches){
            // continue to the next loop if current touch is already captured by OSC. works only in regular native touch
            if([OnScreenControls.touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) continue;
            [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_UP]; //send touch event before remove pointerId
            [self removePointerId:touch]; //then remove pointerId
            if(self->activateCoordSelector) [self removePointerObjFromDict:touch];
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}


- (void)populatePointerObjIntoDict:(UITouch*)touch{
    NativeTouchPointer* pointer = [[NativeTouchPointer alloc] initWithTouch:touch];
    pointer.useRelativeCoords = pointer.initialPoint.x > pointerVelocityDividerLocationByPoints;
    [pointerObjDict setObject:pointer forKey:@((uintptr_t)touch)];
}

- (NativeTouchPointer* )getPointerObjFromDict:(UITouch*)touch{
    return [pointerObjDict objectForKey:@((uintptr_t)touch)];
}

- (void)removePointerObjFromDict:(UITouch*)touch{
    NSNumber* touchAddrObj = @((uintptr_t)touch);
    NativeTouchPointer* pointer = [pointerObjDict objectForKey:touchAddrObj];
    if(pointer != nil){
        [pointerObjDict removeObjectForKey:touchAddrObj];
    }
}

- (void)updatePointerObjInDict:(UITouch *)touch{
    [[pointerObjDict objectForKey:@((uintptr_t)touch)] updatePointerCoords:touch];
}

- (CGPoint)selectCoordsFor:(UITouch *)touch{
    NativeTouchPointer *pointer = [pointerObjDict objectForKey:@((uintptr_t)touch)];
    if(pointer == nil) return CGPointMake(0, 0);
    return pointer.useRelativeCoords ? pointer.latestRelativePoint : pointer.latestPoint;
}

@end
