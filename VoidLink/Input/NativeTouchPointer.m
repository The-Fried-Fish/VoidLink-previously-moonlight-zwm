//
//  NativeTouchPointer.m
//  VoidLink
//
//  Created by True砖家 on 2024/5/14.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NativeTouchPointer.h"
#include <Limelight.h>

// native touch pointer ojbect that stores & manipulates touch coordinates

static CGFloat pointerVelocityFactor;
static CGFloat streamViewHeight;
static CGFloat streamViewWidth;
static CGFloat fixedResetCoordX;
static CGFloat fixedResetCoordY;
static StreamView* streamView;

@implementation NativeTouchPointer{
}

- (instancetype)initWithTouch:(UITouch *)touch{
    self = [super init];
    _initialPoint = [touch locationInView:streamView];
    _latestPoint = _initialPoint;
    _latestRelativePoint = _initialPoint;
    return self;
}

- (bool)doesNeedResetCoords{
    bool boundaryReached = (_latestRelativePoint.x > streamViewWidth || _latestRelativePoint.x < 0.0f ||  _latestRelativePoint.y > streamViewHeight || _latestRelativePoint.y < 0.0f);
    bool withinExcludedArea =  (_initialPoint.x > streamViewWidth * (0.75) && _initialPoint.x < streamViewWidth) && (_initialPoint.y > streamViewHeight * (0.8) && _initialPoint.y < streamViewHeight);
    _needResetCoords = (pointerVelocityFactor > 1.0f) && _useRelativeCoords && boundaryReached && !withinExcludedArea; 
    // boundary detection & coordinates reset to the specific point for HK:StarTrail(needs a very high pointer velocity)
    // must exclude touch pointer that uses native coords instead of relative ones.
    // also exclude touch pointer created within  the bottom right corner
    
    return _needResetCoords;
}

- (void)updatePointerCoords:(UITouch *)touch{
    _previousPoint = _latestPoint;
    _latestPoint = [touch locationInView:streamView];
    _previousRelativePoint = _latestRelativePoint;
    if(_needResetCoords){// boundary detection & coordinates reset to the central screen point for HK:StarTrail(needs a very high pointer velocity); // boundary detection & coordinates reset to specific point for HK:StarTrail(needs a very high pointer velocity)
        _previousRelativePoint.x = fixedResetCoordX;
        _previousRelativePoint.y = fixedResetCoordY;
    }
    _latestRelativePoint.x = _previousRelativePoint.x + pointerVelocityFactor * (_latestPoint.x - _previousPoint.x);
    _latestRelativePoint.y = _previousRelativePoint.y + pointerVelocityFactor * (_latestPoint.y - _previousPoint.y);
}

+ (void)initContextWithView:(StreamView*)view andSettings:(TemporarySettings*)settings {
    streamView = view;
    streamViewWidth = streamView.frame.size.width;
    fixedResetCoordX = streamViewWidth * 0.3;
    streamViewHeight = streamView.frame.size.height;
    fixedResetCoordY = streamViewHeight * 0.4;
    pointerVelocityFactor = settings.touchPointerVelocityFactor.floatValue;
    NSLog(@"stream wdith %f, stream height %f", streamViewWidth, streamViewHeight);
}

+ (void)cleanUpContext {
    streamView = nil;
}

@end
