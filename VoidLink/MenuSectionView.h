//
//  MenuSectionView.h
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

// MenuSectionView.h

#import <UIKit/UIKit.h>
#import "DataManager.h"

@protocol MenuSectionDelegate <NSObject>
- (void)hideOverlappedDynamicLabels;
- (SettingsMenuMode)getSettingsMenuMode;
@end


@interface MenuSectionView : UIView

// 外部可访问属性
@property (nonatomic, assign) CGFloat leadingTrailingPadding;
@property (nonatomic, assign) CGFloat separatorLinePadding;
@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) CGFloat rootStackViewSpacing;
@property (nonatomic, assign) CGFloat headerViewHeight;
@property (nonatomic, assign) CGFloat headerViewVerticalSpacing;
@property (nonatomic, strong) NSMutableArray<UIStackView *> *subStackViews;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, weak) id<MenuSectionDelegate> delegate; // Delegate property

// 方法
- (void)setSectionWithIcon:(UIImage *)icon andSize:(CGFloat)size;
- (void)addSubStackView:(UIStackView *)stackView;
- (void)addToParentStack:(UIStackView *)parentStack;
- (void)removeSubStackView:(UIStackView *)stackView;
- (void)updateLayout;
- (void)updateViewForFoldState;


@end
