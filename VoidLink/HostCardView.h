//
//  HostCardView.h
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "TemporaryHost.h"

@protocol HostCardActionDelegate <NSObject>
- (void)appButtonTappedForHost:(TemporaryHost *)host;
- (void)launchButtonTappedForHost:(TemporaryHost *)host;
- (void)wakeupButtonTappedForHost:(TemporaryHost *)host;
- (void)pairButtonTappedForHost:(TemporaryHost *)host;
- (void)hostCardLongPressed:(TemporaryHost *)host view:(UIView *)view;
- (bool)isStreaming;
@end


@interface HostCardView : UIView
@property (nonatomic, assign) CGFloat sizeFactor;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, weak) id<HostCardActionDelegate> delegate; // Delegate property

- (void)resizeBySizeFactor:(CGFloat)factor;
- (id) initWithHost:(TemporaryHost*)host;
- (id) initWithHost:(TemporaryHost*)host andSizeFactor:(CGFloat)sizeFactor;

@end

