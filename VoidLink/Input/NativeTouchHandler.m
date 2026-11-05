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
#import "VoidLink-Swift.h"

#include <Limelight.h>

@implementation NativeTouchHandler {
    __weak StreamView* streamView;
    bool activateCoordSelector;
    bool singleTouchDisabled;
    CGFloat pointerVelocityDividerLocationByPoints;
    
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
    dispatch_queue_t touchQueue;
    NSMutableSet *blacklistedTouches;
    
    bool trackPointEnabled;
    NSMutableArray<CAShapeLayer *> * trackPointPool; //pre-defined pool of pointerIds.

    NSMutableDictionary *pointerObjDict;

    CGFloat slideGestureVerticalThreshold;
    CGFloat screenWidthWithThreshold;
    CGFloat _edgeTolerance;
}

- (id)initWithView:(StreamView*)view settings:(TemporarySettings*)settings profile:(OSCProfile* )profile{
    self = [super init];
    self->streamView = view;
    self->activateCoordSelector = profile.pointerVelocityModeDivider != 1.0;

    self->touchQueue = dispatch_queue_create("com.voidlink.native-touch",
        dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0));
    self->pointerIdDict = [NSMutableDictionary dictionary];
    self->pointerIdPool = [NSMutableSet set];
    self->trackPointEnabled = settings.touchPointTracking;
    self->trackPointPool = [NSMutableArray array];
    for (uint8_t i = 0; i <= 10; i++) { //ipadOS supports upto 11 finger touches
        [self->pointerIdPool addObject:@(i)];
        [self->trackPointPool addObject:[GraphicUtils makeTouchTrackpointIn:streamView]];
    }

    self->activePointerIds = [NSMutableSet set];
    self->blacklistedTouches = [NSMutableSet set];
        
    self->asyncNativeTouch = settings.asyncNativeTouchPriority.intValue != TouchEventPriorityEnumAsyncNativeTouchOff;
    
    switch(settings.asyncNativeTouchPriority.intValue){
        case TouchEventPriorityEnumTouchDownPriority: // deprecated by GUI
            touchDownQos = QOS_CLASS_USER_INTERACTIVE;
            touchMoveQos = QOS_CLASS_USER_INITIATED;
            touchEndQos = QOS_CLASS_USER_INITIATED;
            break;
        case TouchEventPriorityEnumTouchMovePriority: // deprecated by GUI
            touchDownQos = QOS_CLASS_USER_INITIATED;
            touchMoveQos = QOS_CLASS_USER_INTERACTIVE;
            touchEndQos = QOS_CLASS_USER_INITIATED;
            break;
        case TouchEventPriorityEnumEqualPriority: // equals to async touch is true now
            touchDownQos = QOS_CLASS_USER_INTERACTIVE;
            touchMoveQos = QOS_CLASS_USER_INTERACTIVE;
            touchEndQos = QOS_CLASS_USER_INITIATED;
            break;
        default: break;
    }
    
    
    self->pointerObjDict = [NSMutableDictionary dictionary];
    
    _edgeTolerance = settings.edgeSlidingSensitivity.floatValue;
    slideGestureVerticalThreshold = CGRectGetHeight([[PublicUtils currentScreen] bounds]) * 0.4;
    screenWidthWithThreshold = CGRectGetWidth([[PublicUtils currentScreen] bounds]) - _edgeTolerance;

    self->pointerVelocityDividerLocationByPoints = self->streamView.bounds.size.width * profile.pointerVelocityModeDivider;
    
    [NativeTouchPointer initContextWithView:self->streamView profile:profile];
    //_touchesCapturedByOnScreenButtons = [[NSMutableSet alloc] init];
    return self;
}

- (CGPoint)adjustCoordinatesForVideoArea:(CGPoint)point geometry:(StreamInputGeometry)geometry {
    CGRect streamViewBounds = geometry.bounds;
    // These are now relative to the StreamView, however we need to scale them
    // further to make them relative to the actual video portion.
    float x = point.x - streamViewBounds.origin.x;
    float y = point.y - streamViewBounds.origin.y;
    
    // For some reason, we don't seem to always get to the bounds of the window
    // so we'll subtract 1 pixel if we're to the left/below of the origin and
    // and add 1 pixel if we're to the right/above. It should be imperceptible
    // to the user but it will allow activation of gestures that require contact
    // with the edge of the screen (like Aero Snap).
    if (x < streamViewBounds.size.width / 2) {
        x--;
    }
    else {
        x++;
    }
    if (y < streamViewBounds.size.height / 2) {
        y--;
    }
    else {
        y++;
    }
    
    // This logic mimics what iOS does with AVLayerVideoGravityResizeAspect
    CGSize videoSize = geometry.videoRect.size;
    CGPoint videoOrigin = CGPointMake(streamViewBounds.size.width / 2 - videoSize.width / 2,
                                      streamViewBounds.size.height / 2 - videoSize.height / 2);
    
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
- (BOOL)handleTouchDown:(UITouch*)touch{
    StreamView *view = streamView;
    if (!view) return NO;
    //populate pointerId
    NSNumber* touchAddrObj = @((uintptr_t)touch);
    if (pointerIdDict[touchAddrObj]) return NO;
    NSMutableSet<NSNumber *> *unassignedPointerIds = [pointerIdPool mutableCopy];
    [unassignedPointerIds minusSet:activePointerIds];
    NSNumber *pointerIdObj = unassignedPointerIds.anyObject;
    if (!pointerIdObj) return NO;
    [pointerIdDict setObject:pointerIdObj forKey:touchAddrObj];
    [activePointerIds addObject:pointerIdObj];
    
    //check if touch point is spawned on the left or right upper half screen edges, event to remote PC. this is for better handling in-stream slide gesture
    CGPoint initialPoint = [touch locationInView:view];
    CGRect bounds = view.bounds;
    slideGestureVerticalThreshold = CGRectGetHeight(bounds) * 0.4;
    screenWidthWithThreshold = CGRectGetWidth(bounds) - _edgeTolerance;
    if(initialPoint.y < slideGestureVerticalThreshold && (initialPoint.x < _edgeTolerance || initialPoint.x > screenWidthWithThreshold)) {
        [blacklistedTouches addObject:touchAddrObj];
    }
    return YES;
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
- (NSNumber *)retrievePointerIdFromDict:(UITouch *)touch {
    return pointerIdDict[@((uintptr_t)touch)];
}

- (void)sendTouchEvent:(UITouch *)touch pointerId:(uint8_t)pointerId type:(uint8_t)touchType {
    StreamView *view = streamView;
    if (!view || [blacklistedTouches containsObject:@((uintptr_t)touch)]) return;

    CGPoint targetCoords = activateCoordSelector ? [self selectCoordsFor:touch] : [touch locationInView:view];
    StreamInputGeometry geometry = view.inputGeometry;
    CGSize videoSize = geometry.videoRect.size;
    if (videoSize.width <= 0 || videoSize.height <= 0) return;
    CGPoint location = [self adjustCoordinatesForVideoArea:targetCoords geometry:geometry];
    CGFloat normalizedX = location.x / videoSize.width;
    CGFloat normalizedY = location.y / videoSize.height;

    NativeTouchPointer *pointer = [self getPointerObjFromDict:touch];
    if (touchType == LI_TOUCH_EVENT_MOVE && pointer.needResetCoords) {
        LiSendTouchEvent(LI_TOUCH_EVENT_UP, pointerId, normalizedX, normalizedY, 0, 0, 0, 0);
        LiSendTouchEvent(LI_TOUCH_EVENT_DOWN, pointerId, 0.3, 0.4, 0, 0, 0, 0);
    } else {
        CGFloat pressure = (touch.force / touch.maximumPossibleForce) / sin(touch.altitudeAngle);
        LiSendTouchEvent(touchType, pointerId, normalizedX, normalizedY, isfinite(pressure) ? pressure : 0,
                         0.0f, 0.0f, [self getRotationFromAzimuthAngle:[touch azimuthAngleInView:view]]);
    }
}

- (BOOL)shouldSendContactUpdateForEvent:(UIEvent *)event {
    StreamView *view = streamView;
    return view && (!singleTouchDisabled || [UITouchUtil touchesIn:view from:event].count == 2)
        && !(PencilHandler.pencilPausesNativeTouch && PencilHandler.isDrawing);
}

- (NSSet *)streamTouchesFrom:(NSSet *)touches ending:(BOOL)ending {
    NSMutableSet *streamTouches = [touches mutableCopy];
    NSMutableSet *captured = OnScreenControls.touchesCapturedByOnScreenControls;
    if (captured) {
        [streamTouches minusSet:captured];
        if (ending) [captured minusSet:touches];
    }
    return streamTouches;
}

- (void)updateTrackPoint:(NSNumber *)pointerId position:(CGPoint)position phase:(uint8_t)touchType {
    if (!trackPointEnabled) return;
    CAShapeLayer *layer = trackPointPool[pointerId.unsignedIntegerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        if (touchType != LI_TOUCH_EVENT_UP) layer.position = position;
        if (touchType != LI_TOUCH_EVENT_MOVE) layer.hidden = touchType == LI_TOUCH_EVENT_UP;
        [CATransaction commit];
    });
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSSet *streamTouches = [self streamTouchesFrom:touches ending:NO];
    BOOL shouldSend = [self shouldSendContactUpdateForEvent:event];
    dispatch_async(touchQueue, ^{
        for (UITouch *touch in streamTouches) {
            if (![self handleTouchDown:touch]) continue;
            NSNumber *pointerId = [self retrievePointerIdFromDict:touch];
            if (self->activateCoordSelector) [self populatePointerObjIntoDict:touch];
            if (shouldSend) [self sendTouchEvent:touch pointerId:pointerId.unsignedCharValue type:LI_TOUCH_EVENT_DOWN];
            if (self->trackPointEnabled) {
                [self updateTrackPoint:pointerId position:[touch locationInView:self->streamView] phase:LI_TOUCH_EVENT_DOWN];
            }
        }
    });
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    NSSet *streamTouches = [self streamTouchesFrom:touches ending:NO];
    BOOL shouldSend = [self shouldSendContactUpdateForEvent:event];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), touchQueue, ^{
        for (UITouch *touch in streamTouches) {
            NSNumber *pointerId = [self retrievePointerIdFromDict:touch];
            if (!pointerId) continue;
            if (self->activateCoordSelector) [self updatePointerObjInDict:touch];
            if (shouldSend) [self sendTouchEvent:touch pointerId:pointerId.unsignedCharValue type:LI_TOUCH_EVENT_MOVE];
            [[self getPointerObjFromDict:touch] doesNeedResetCoords];
            if (self->trackPointEnabled) {
                [self updateTrackPoint:pointerId position:[touch locationInView:self->streamView] phase:LI_TOUCH_EVENT_MOVE];
            }
        }
    });
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    NSSet *streamTouches = [self streamTouchesFrom:touches ending:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), touchQueue, ^{
        for (UITouch *touch in streamTouches) {
            NSNumber *pointerId = [self retrievePointerIdFromDict:touch];
            if (!pointerId) continue;
            [self sendTouchEvent:touch pointerId:pointerId.unsignedCharValue type:LI_TOUCH_EVENT_UP];
            [self updateTrackPoint:pointerId position:CGPointZero phase:LI_TOUCH_EVENT_UP];
            [self removePointerId:touch];
            if (self->activateCoordSelector) [self removePointerObjFromDict:touch];
            [self->blacklistedTouches removeObject:@((uintptr_t)touch)];
        }
    });
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

- (void)setAllowSingleTouchEnabled:(BOOL)enabled{
    singleTouchDisabled = !enabled;
}

- (void)dealloc{
    NSLog(@"dealloc nativeTouchHanlder %f", CACurrentMediaTime());
    pointerIdDict = nil;
    activePointerIds = nil;
    pointerIdPool= nil;
    blacklistedTouches = nil;
    NSArray<CAShapeLayer *> *layers = trackPointPool;
    void (^removeLayers)(void) = ^{
        for (CAShapeLayer *layer in layers) {
            [layer removeFromSuperlayer];
        }
    };
    if (NSThread.isMainThread) {
        removeLayers();
    } else {
        dispatch_async(dispatch_get_main_queue(), removeLayers);
    }
    pointerObjDict = nil;
}

@end
