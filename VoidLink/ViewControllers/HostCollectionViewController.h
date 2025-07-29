//
//  HostCollectionViewController.h
//  VoidLink
//
//  Created by True砖家 on 2025/5/28.
//  Copyright 2025 True砖家 @ Bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>
// #import "HostCardView.h"

@class HostCardView;
@class TemporaryHost;

@interface HostCollectionViewController : UICollectionViewController

/// 横向 cell 间距
@property (nonatomic, assign) CGFloat interItemMinimumSpacing;

/// 纵向行间距
@property (nonatomic, assign) CGFloat minimumLineSpacing;

/// 固定的 cell 尺寸
@property (nonatomic, assign) CGSize cellSize;

@property (nonatomic, strong, readonly) NSMutableArray<TemporaryHost *> *items;

/// 添加一个 item
- (void)addHost:(TemporaryHost *)host;
- (void)removeHost:(TemporaryHost *)host;
- (void)updateTheme;

/// 移除最后一个 item（如果有）
- (void)removeLastItem;

@end


@interface HostCell : UICollectionViewCell
@property (nonatomic, strong) HostCardView *cardView;

- (void)configureWithHost:(TemporaryHost *)host;
@end
