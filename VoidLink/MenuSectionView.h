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

@property (class, nonatomic, assign) BOOL overridePersistedFoldState;

// 外部可访问属性
@property (nonatomic, strong) UIStackView *rootStackView;
@property (nonatomic, assign) CGFloat leadingTrailingPadding;
@property (nonatomic, assign) CGFloat separatorLinePadding;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL expandable;
@property (nonatomic, copy) void (^lockedSectionHandler)(void);
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) CGFloat rootStackViewSpacing;
@property (nonatomic, assign) CGFloat headerViewHeight;
@property (nonatomic, assign) CGFloat headerViewVerticalSpacing;
@property (nonatomic, strong) NSMutableArray<UIStackView *> *subStackViews;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, weak) id<MenuSectionDelegate> delegate; // Delegate property

// 方法
- (void)setSectionWithIcon:(UIImage *)icon size:(CGFloat)size sizeConstraint:(CGFloat)constant;
- (void)setSectionWithIcon:(UIImage *)icon size:(CGFloat)size weight:(UIImageSymbolWeight)weight sizeConstraint:(CGFloat)constant API_AVAILABLE(ios(13.0));
- (void)addSubStackView:(UIStackView *)stackView;
- (void)addToParentStack:(UIStackView *)parentStack;
- (void)removeSubStackView:(UIStackView *)stackView;
- (void)updateLayout;
- (void)updateViewForFoldState;
- (void)setExpanded:(BOOL)overridePersistedState;


@end
