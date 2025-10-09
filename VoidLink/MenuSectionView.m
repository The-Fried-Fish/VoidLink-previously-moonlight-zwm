//
//  MenuSectionView.h
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//
// MenuSectionView.m

#import "MenuSectionView.h"
#import "ThemeManager.h"


@interface MenuSectionView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *toggleArea;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) UIView *headerView;

@end

@implementation MenuSectionView

static BOOL overridePersistedFoldState = YES;

+ (BOOL)overridePersistedFoldState {
    return overridePersistedFoldState;
}

+ (void)setOverridePersistedFoldState:(BOOL)val {
    overridePersistedFoldState = val;
}


- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // 默认值
    _leadingTrailingPadding = 0;
    _separatorLinePadding = 40;
    _sectionTitle = @"Section";
    _isExpanded = YES;
    _expandable = true;
    _backgroundColor = [UIColor clearColor];
    _rootStackViewSpacing = [self isIPhone] ? 10 : 13.8;
    _subStackViews = [NSMutableArray array];
    _headerViewHeight = 37;
    _headerViewVerticalSpacing = 25;
    
    // 设置视图
    self.layer.cornerRadius = 10.0;
    self.layer.masksToBounds = YES;
    self.backgroundColor = _backgroundColor;
    
    // 头部视图（包含图标和标题）
    _headerView = [[UIView alloc] init];
    _headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_headerView];
    
    // 图标视图
    _iconImageView = [[UIImageView alloc] init];
    _iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    _iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconImageView.tintColor = [ThemeManager textColor];
    [_headerView addSubview:_iconImageView];
    
    // 标题标签
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = _sectionTitle;
    _titleLabel.font = [UIFont systemFontOfSize:23 weight:UIFontWeightMedium];
    _titleLabel.textColor = [ThemeManager textColor];
    _titleLabel.textAlignment = NSTextAlignmentLeft;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerView addSubview:_titleLabel];
    
    // 切换按钮
    _toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _toggleArea = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:_headerViewHeight*0.31 weight:UIImageSymbolWeightBold];
        [_toggleButton setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:config] forState:UIControlStateNormal];
    } else {
        // [_toggleButton setTitle:@"<" forState:UIControlStateNormal];
    }
    [_toggleButton addTarget:self action:@selector(toggleFold) forControlEvents:UIControlEventTouchUpInside];
    [_toggleArea addTarget:self action:@selector(toggleFold) forControlEvents:UIControlEventTouchUpInside];
    _toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    _toggleArea.translatesAutoresizingMaskIntoConstraints = NO;
    _toggleButton.contentEdgeInsets = UIEdgeInsetsMake(-10,-10,-10,-10); // 上下左右各扩展 20pt
    [_headerView addSubview:_toggleButton];
    [_headerView addSubview:_toggleArea];

    // 根stackView
    _rootStackView = [[UIStackView alloc] init];
    _rootStackView.axis = UILayoutConstraintAxisVertical;
    _rootStackView.spacing = _rootStackViewSpacing;
    _rootStackView.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:_rootStackView];
    
    // 分隔线
    _separatorLine = [[UIView alloc] init];
    _separatorLine.backgroundColor = [ThemeManager separatorColor];
    _separatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self addSubview:_separatorLine];
    
    // 高度约束
    _heightConstraint = [self.heightAnchor constraintEqualToConstant:44];
    _heightConstraint.active = YES;
    
    // 布局
    [self setupConstraints];
    [self updateViewForFoldState];
}

- (void)setupConstraints {
    // 头部视图约束
    [NSLayoutConstraint activateConstraints:@[
        [_headerView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_headerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_headerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_headerView.heightAnchor constraintEqualToConstant:_headerViewHeight]
    ]];
    
    // 图标约束
    [NSLayoutConstraint activateConstraints:@[
        [_iconImageView.centerXAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:_leadingTrailingPadding+_headerViewHeight/2-3],
        [_iconImageView.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
        // [_iconImageView.topAnchor constraintEqualToAnchor:_headerView.topAnchor],
        [_iconImageView.widthAnchor constraintEqualToConstant:_headerViewHeight-6],
        //[_iconImageView.heightAnchor constraintEqualToConstant:_headerViewHeight-6]
    ]];
    
    // 标题约束
    if(@available(iOS 13.0, *)){
        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconImageView.trailingAnchor constant:8],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_toggleButton.leadingAnchor constant:-8]
        ]];
    }
    else [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_toggleButton.leadingAnchor constant:-8]
        ]];
    
    // 切换按钮约束
    [NSLayoutConstraint activateConstraints:@[
        [_toggleButton.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-_leadingTrailingPadding],
        [_toggleButton.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
        [_toggleButton.widthAnchor constraintEqualToConstant:_headerViewHeight*0.8],
        [_toggleButton.heightAnchor constraintEqualToConstant:_headerViewHeight*0.8]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [_toggleArea.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor],
        [_toggleArea.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
        [_toggleArea.trailingAnchor constraintEqualToAnchor:_toggleButton.leadingAnchor],
        //[_toggleArea.widthAnchor constraintEqualToConstant:_headerViewHeight],
        [_toggleArea.heightAnchor constraintEqualToConstant:_headerViewHeight]
    ]];

    [self layoutIfNeeded];
        
    // 根stackView约束
    [NSLayoutConstraint activateConstraints:@[
        [_rootStackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:_headerViewHeight+_headerViewVerticalSpacing],
        [_rootStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_leadingTrailingPadding],
        [_rootStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-_leadingTrailingPadding],
        [_rootStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-1] // 为分隔线留出空间
    ]];
    
    // 分隔线约束
    self.clipsToBounds = false;//mark: settingMenuLayout
    [NSLayoutConstraint activateConstraints:@[
        //[_separatorLine.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        //[_separatorLine.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_separatorLine.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_separatorLine.widthAnchor constraintEqualToConstant:1000], // //mark: settingMenuLayout
        [_separatorLine.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_separatorLine.heightAnchor constraintEqualToConstant:2]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],
        [self.rootStackView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:0],
    ]];
}

#pragma mark - Public Methods

- (void)setSectionWithIcon:(UIImage *)icon andSize:(CGFloat)size{
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config;
        if(icon.isSymbolImage) config = [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightBold];
        else{
            config = [UIImageSymbolConfiguration configurationWithPointSize:size];
            icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        _iconImageView.image = [icon imageWithConfiguration:config];
    } else {
        _iconImageView.image = icon;
    }
    _iconImageView.tintColor = [ThemeManager textColor];
    _iconImageView.hidden = (icon == nil);
    [self updateLayout];
}

- (void)setLeadingTrailingPadding:(CGFloat)leadingTrailingPadding {
    _leadingTrailingPadding = leadingTrailingPadding;
    [self updateLayout];
}

- (void)setSectionTitle:(NSString *)sectionTitle {
    _sectionTitle = sectionTitle;
    _titleLabel.text = sectionTitle;
}

- (void)setExpanded:(BOOL)isExpanded {
    self.isExpanded = !_expandable ? false : isExpanded;
    [self updateViewForFoldState];
    [[NSUserDefaults standardUserDefaults] setBool:self.isExpanded forKey:self.identifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    _backgroundColor = backgroundColor;
}

- (void)setRootStackViewSpacing:(CGFloat)rootStackViewSpacing {
    _rootStackViewSpacing = rootStackViewSpacing;
    _rootStackView.spacing = rootStackViewSpacing;
    [self updateLayout];
}

- (void)addSubStackView:(UIStackView *)stackView {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        if (![_subStackViews containsObject:stackView]) {
            [_subStackViews addObject:stackView];
            [_rootStackView addArrangedSubview:stackView];
            //[_rootStackView layoutIfNeeded];
            //[self updateLayout];
        }
    }];
    [CATransaction commit];
    // NSLog(@"rootStack height2: %f", _rootStackView.frame.size.height);
}

- (void)addToParentStack:(UIStackView *)parentStack {
    [parentStack insertArrangedSubview:self atIndex:parentStack.arrangedSubviews.count];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.leadingAnchor constraintEqualToAnchor:parentStack.leadingAnchor constant:0],
        [self.trailingAnchor constraintEqualToAnchor:parentStack.trailingAnchor constant:0],
    ]];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL persistedFoldState = [defaults objectForKey:self.identifier] ? [defaults boolForKey:self.identifier] : YES;

    [self setExpanded: MenuSectionView.overridePersistedFoldState ? _expandable : persistedFoldState];
}

- (void)removeSubStackView:(UIStackView *)stackView {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if ([_subStackViews containsObject:stackView]) {
        [_subStackViews removeObject:stackView];
        [_rootStackView removeArrangedSubview:stackView];
        [stackView removeFromSuperview];
        [self updateLayout];
    }
    [CATransaction commit];
}


- (void)updateLayout {
    // 更新边距约束
    for (NSLayoutConstraint *constraint in self.constraints) {
        if (constraint.firstItem == _rootStackView && constraint.firstAttribute == NSLayoutAttributeLeading) {
            constraint.constant = _leadingTrailingPadding;
        } else if (constraint.firstItem == _rootStackView && constraint.firstAttribute == NSLayoutAttributeTrailing) {
            constraint.constant = -_leadingTrailingPadding;
        }
    }
    
    for (NSLayoutConstraint *constraint in _headerView.constraints) {
        if (constraint.firstItem == _iconImageView && constraint.firstAttribute == NSLayoutAttributeLeading) {
            constraint.constant = _leadingTrailingPadding;
        } else if (constraint.firstItem == _toggleButton && constraint.firstAttribute == NSLayoutAttributeTrailing) {
            constraint.constant = -_leadingTrailingPadding;
        }
    }
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Private Methods

- (BOOL)isIPhone {
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
}

- (void)toggleFold {
    self.isExpanded = !_expandable ? false : !self.isExpanded;
    [self updateViewForFoldState];
    if(!_expandable) self.lockedSectionHandler();
    [[NSUserDefaults standardUserDefaults] setBool:self.isExpanded forKey:self.identifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (SettingsMenuMode)getSettingsMenuMode {
    if ([self.delegate respondsToSelector:@selector(getSettingsMenuMode)]) {
        return [self.delegate getSettingsMenuMode];
    } else return AllSettings;
}


- (void)updateViewForFoldState {
    [self setupConstraints];
    NSInteger visibleCount = 0;
    for (UIView *subview in _rootStackView.arrangedSubviews) {
        if (!subview.isHidden) {
            visibleCount++;
        }
    }
    self.hidden = visibleCount == 0;
    if (_isExpanded) {
        _rootStackView.hidden = NO;
        _separatorLine.hidden = NO;
        CGSize fittingSize = [self.rootStackView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        //CGSize fittingSize = [self.rootStackView systemLayoutSizeFittingSize:UILayoutFittingExpandedSize];
        CGFloat rootStackViewHeight = fittingSize.height;
        fittingSize = [self.headerView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        CGFloat headerHeight = fittingSize.height;
        
        self.heightConstraint.constant = headerHeight + _headerViewVerticalSpacing + rootStackViewHeight + _separatorLinePadding + 1;
    
        [UIView animateWithDuration:0 animations:^{
            self.toggleButton.transform = CGAffineTransformMakeRotation(M_PI+M_PI_2);
            [NSLayoutConstraint activateConstraints:@[
                [self.rootStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-self.separatorLinePadding],
                // [self.rootStackView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:0],
            ]];
            [self layoutIfNeeded];
        }];
    } else {
        // 折叠状态
        CGSize fittingSize = [self.headerView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        _rootStackView.hidden = YES;
        _separatorLine.hidden = NO;
        _heightConstraint.constant = fittingSize.height + _headerViewVerticalSpacing;
        // [self updateLayout];
        [UIView animateWithDuration:0 animations:^{
            self.toggleButton.transform = CGAffineTransformIdentity;
            [NSLayoutConstraint activateConstraints:@[
                [self.headerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],
                // [self.rootStackView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:0],
            ]];
            [self layoutIfNeeded];
        }];
    }
    
    if ([self.delegate respondsToSelector:@selector(hideOverlappedDynamicLabels)]) {
        [self.delegate hideOverlappedDynamicLabels];
    }
}

@end
