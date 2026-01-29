//
//  NativeTouchPointer.h
//  VoidLink
//
//  Created by True砖家 on 2024/5/14.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import "StreamView.h"
#import "NativeTouchHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface NativeTouchPointer : NSObject
@property (nonatomic, assign) bool needResetCoords;
@property (nonatomic, assign) CGPoint initialPoint;
@property (nonatomic, assign) CGPoint latestPoint;
@property (nonatomic, assign) CGPoint previousPoint;
@property (nonatomic, assign) CGPoint latestRelativePoint;
@property (nonatomic, assign) CGPoint previousRelativePoint;
@property (nonatomic, assign) bool useRelativeCoords;


+ (void)initContextWithView:(StreamView*)view andSettings:(TemporarySettings*)settings;
+ (void)cleanUpContext;

- (bool)doesNeedResetCoords;
- (void)updatePointerCoords:(UITouch *)touch;


- (instancetype)initWithTouch:(UITouch *)touch;
@end




NS_ASSUME_NONNULL_END

