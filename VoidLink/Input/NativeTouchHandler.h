//
//  NativeTouchHandler.h
//  VoidLink
//
//  Created by True砖家 on 2024/6/1.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//


#import "StreamView.h"
#import "DataManager.h"
#include <Limelight.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeTouchHandler : UIResponder

@property (nonatomic, assign) NSMutableSet<UITouch *>* touchesCapturedByOnScreenButtons;

- (id)initWithView:(StreamView* )view andSettings:(TemporarySettings*)settings;
- (void)setAllowSingleTouchEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
