//
//  HostCardView.m
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

#import "HostCardView.h"
#import "LocalizationHelper.h"
#import "ThemeManager.h"
#import "FixedTintImageView.h"


@interface HostCardView ()

@property (nonatomic, strong) UIView *iconBackgroundView;
@property (nonatomic, strong) UIImageView *hostIconView;
@property (nonatomic, strong) UILabel *hostNameLabel;
@property (nonatomic, strong) UIImageView *statusIcon;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *appButton;
@property (nonatomic, strong) UIButton *launchButton;
@property (nonatomic, strong) UIButton *pairButton;
@property (nonatomic, strong) UIButton *wakeupButton;
@property (nonatomic, strong) UIButton *transparentButton;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, assign) CGFloat cardContentpadding;
@property (nonatomic, assign) CGSize size;


@end


@implementation HostCardView {
    TemporaryHost* _host;
    UIActivityIndicatorView* _hostSpinner;
    UIImageView* lockIconView;
    CGFloat computerIconMonitorCenterYOffset;
    CGFloat buttonHeight;
    CGFloat buttonLabelFontSize;
    CGFloat iconAndButtonSpacing;
    UIColor *defaultBlue;
    UIColor *defaultGreen;
    CAGradientLayer *backgroundLayer;
    bool longPressFired;
}

static const float REFRESH_CYCLE = 2.0f;

- (BOOL)isIPhone{
    return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        buttonLabelFontSize = 15*_sizeFactor;
        longPressFired = false;
        computerIconMonitorCenterYOffset = [self isIPhone] ? -2.75*_sizeFactor : -3.2*_sizeFactor;
        iconAndButtonSpacing = 37*_sizeFactor;
        buttonHeight = 39*_sizeFactor;
        defaultBlue = [ThemeManager appPrimaryColor];
        defaultGreen = [UIColor colorWithRed:52.0/255.0 green:199.0/255.0 blue:89.0/255.0 alpha:1.0];
        // self.userIterfaceStyle = UIUserInterfaceStyleLight

        UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(hostCardLongPressed:)];
            [self addGestureRecognizer:longPressRecognizer];
        
        [self createBackgroundLayer];
        [self setupUI];
    }
    return self;
}

- (id) initWithHost:(TemporaryHost*)host {
    self.sizeFactor =  1.0;
    self = [self init];
    _host = host;
    
    // Use UIContextMenuInteraction on iOS 13.0+ and a standard UILongPressGestureRecognizer
    // for tvOS devices and iOS prior to 13.0.
    
    return self;
}

- (id) initWithHost:(TemporaryHost*)host andSizeFactor:(CGFloat)sizeFactor {
    _sizeFactor = sizeFactor;
    self = [self init];
    _host = host;
    
    // Use UIContextMenuInteraction on iOS 13.0+ and a standard UILongPressGestureRecognizer
    // for tvOS devices and iOS prior to 13.0.
    return self;
}




- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)appButtonTapped{
    if(longPressFired){
        longPressFired = false;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(appButtonTappedForHost:)]) {
        [self.delegate appButtonTappedForHost:_host];
    } else NSLog(@"Delegate not set or does not respond to appButtonTappedForHost:");
}

- (void)launchButtonTapped{
    if(longPressFired){
        longPressFired = false;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(launchButtonTappedForHost:)]) {
        [self.delegate launchButtonTappedForHost:_host];
    } else NSLog(@"Delegate not set or does not respond to launchButtonTappedForHost:");
}

- (void)wakeupButtonTapped{
    if(longPressFired){
        longPressFired = false;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(wakeupButtonTappedForHost:)]) {
        [self.delegate wakeupButtonTappedForHost:_host];
    } else NSLog(@"Delegate not set or does not respond to launchButtonTappedForHost:");
}


-(void)pairButtonTapped{
    if(longPressFired){
        longPressFired = false;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(pairButtonTappedForHost:)]) {
        [self.delegate pairButtonTappedForHost:_host];
    } else NSLog(@"Delegate not set or does not respond to pairButtonTappedForHost:");
    
}

- (void)hostCardLongPressed:(UILongPressGestureRecognizer* )gesture{
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    longPressFired = true;
    if ([self.delegate respondsToSelector:@selector(hostCardLongPressed:view:)]) {
        [self.delegate hostCardLongPressed:_host view:self];
    } else NSLog(@"Delegate not set or does not respond");
}

- (void)resizeBySizeFactor:(CGFloat)factor{
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.sizeFactor = factor;
    [self setupUI];
}

- (void)setupUI {
    self.userInteractionEnabled = YES;
    self.backgroundColor = [ThemeManager widgetBackgroundColor];  // theme
    self.cardContentpadding = 13 * _sizeFactor;
    self.clipsToBounds = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat appButtonWidth = 100*_sizeFactor;
    CGFloat launchButtonWidth = 120*_sizeFactor;
    CGFloat cardWidth = _cardContentpadding*2 + appButtonWidth + 15*_sizeFactor + launchButtonWidth;
    self.layer.cornerRadius = 2*(uint16_t)(cardWidth*0.0603/2) ;
    /*
     NSLayoutConstraint *topAnchorConstraint;
     topAnchorConstraint = [self.topAnchor constraintEqualToAnchor:self.superview.topAnchor constant:500];
     topAnchorConstraint.active = YES;
     */
    _heightConstraint = [self.heightAnchor constraintEqualToConstant:300];
    _heightConstraint.active = YES;
    _widthConstraint = [self.widthAnchor constraintEqualToConstant:300];
    _widthConstraint.active = YES;
    
    
    // 图标背景
    self.iconBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(_cardContentpadding, _cardContentpadding, 80*_sizeFactor, 80*_sizeFactor)];
    self.iconBackgroundView.backgroundColor = defaultBlue;
    self.iconBackgroundView.layer.cornerRadius = 2*(uint16_t)(20*_sizeFactor/2);
    [self addSubview:self.iconBackgroundView];
    
    // 图标图片
    self.hostIconView = [[UIImageView alloc] init];
    self.hostIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.hostIconView.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        self.hostIconView.image = [[UIImage imageNamed:@"display"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        self.hostIconView.image = [UIImage imageNamed:@"Computer"];
        [NSLayoutConstraint activateConstraints:@[
            [self.hostIconView.heightAnchor constraintEqualToConstant:57*_sizeFactor],
            [self.hostIconView.widthAnchor constraintEqualToConstant:57*_sizeFactor],
        ]];
    }
    self.hostIconView.tintColor = [UIColor whiteColor];
    [self.iconBackgroundView addSubview:self.hostIconView];
    [NSLayoutConstraint activateConstraints:@[
        [self.hostIconView.centerXAnchor constraintEqualToAnchor:self.iconBackgroundView.centerXAnchor constant:0],
        [self.hostIconView.centerYAnchor constraintEqualToAnchor:self.iconBackgroundView.centerYAnchor constant:0],
        [self.hostIconView.heightAnchor constraintEqualToConstant:53.9*_sizeFactor],
        [self.hostIconView.widthAnchor constraintEqualToConstant:53.9*_sizeFactor],
    ]];
    // [self.iconBackgroundView layoutIfNeeded];
    // [self.iconImageView layoutIfNeeded];
    
    //spinner
    bool oldiOS = false;
    if (@available(iOS 13.0, *)){}
    else oldiOS = true;

    _hostSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _hostSpinner.userInteractionEnabled = NO;
    _hostSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    _hostSpinner.hidesWhenStopped = YES;
    [self.iconBackgroundView addSubview:_hostSpinner];
    [NSLayoutConstraint activateConstraints:@[
        [_hostSpinner.centerXAnchor constraintEqualToAnchor:self.iconBackgroundView.centerXAnchor constant:0],
        [_hostSpinner.centerYAnchor constraintEqualToAnchor:self.iconBackgroundView.centerYAnchor constant:oldiOS ? -5.5*_sizeFactor :  computerIconMonitorCenterYOffset],
    ]];
    _hostSpinner.transform = CGAffineTransformMakeScale(_sizeFactor, _sizeFactor);
    [_hostSpinner stopAnimating];
    // [_hostSpinner startAnimating];
    
    
    // lockIcon
    lockIconView =[[UIImageView alloc] init];
    lockIconView.translatesAutoresizingMaskIntoConstraints = NO;
    lockIconView.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        lockIconView.image = [[UIImage imageNamed:@"lock.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        lockIconView.image = [UIImage imageNamed:@"LockedOverlayIcon"];
        computerIconMonitorCenterYOffset = -5 * _sizeFactor;
    }
    lockIconView.tintColor = [UIColor whiteColor];
    [self.iconBackgroundView insertSubview:lockIconView aboveSubview:_iconBackgroundView];
    [NSLayoutConstraint activateConstraints:@[
        [lockIconView.centerXAnchor constraintEqualToAnchor:_iconBackgroundView.centerXAnchor constant:0],
        [lockIconView.centerYAnchor constraintEqualToAnchor:_iconBackgroundView.centerYAnchor constant:computerIconMonitorCenterYOffset],
        [lockIconView.widthAnchor constraintEqualToConstant:17.05*_sizeFactor],
        [lockIconView.heightAnchor constraintEqualToConstant:17.05*_sizeFactor]
    ]];
    lockIconView.hidden = true;
    
    // 设备名
    CGFloat hostNameLabelCoordX = _cardContentpadding+_iconBackgroundView.frame.size.width+16*_sizeFactor;
    self.hostNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(hostNameLabelCoordX, _cardContentpadding+_iconBackgroundView.frame.size.height*0.02, cardWidth-hostNameLabelCoordX-_cardContentpadding, 30*_sizeFactor)];
    self.hostNameLabel.numberOfLines = 1;
    self.hostNameLabel.adjustsFontSizeToFitWidth = YES;
    self.hostNameLabel.minimumScaleFactor = 0.8; // 最小字体缩放比例
    self.hostNameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    
    self.hostIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.hostNameLabel.text = @"RazerBlade 16";
    self.hostNameLabel.textColor = [UIColor whiteColor]; //theme
    self.hostNameLabel.font = [UIFont boldSystemFontOfSize:18*_sizeFactor];
    [self addSubview:self.hostNameLabel];
    
    // 在线文字
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(205, 68, 100, 24)];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = [LocalizationHelper localizedStringForKey:@"Online"];
    self.statusLabel.font = [UIFont systemFontOfSize:14*_sizeFactor weight:UIFontWeightMedium];
    self.statusLabel.textColor = defaultGreen;
    // self.statusLabel.font = [UIFont systemFontOfSize:16*_sizeFactor];
    // 在线状态图标
    self.statusIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 16*_sizeFactor, 16*_sizeFactor)];
    self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.statusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIcon.image = [[UIImage imageNamed:@"wifi_green"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    // self.statusIcon.tintColor = defaultGreen;
    [self addSubview:self.statusIcon];
    [self addSubview:self.statusLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusIcon.trailingAnchor constant:3*_sizeFactor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.hostNameLabel.bottomAnchor constant:0*_sizeFactor],

        [self.statusIcon.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor constant:0],
        [self.statusIcon.leadingAnchor constraintEqualToAnchor:self.hostNameLabel.leadingAnchor],
        [self.statusIcon.widthAnchor constraintEqualToConstant:16*_sizeFactor]
    ]];
    
    // 启动应用按钮
    self.appButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.appButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.appButton.frame = CGRectMake(20, 200, 150, buttonHeight);
    [self.appButton setTitle:[LocalizationHelper localizedStringForKey:@"Applications"] forState:UIControlStateNormal];
    [self.appButton setTitleColor:[ThemeManager textColorGray] forState:UIControlStateNormal]; //theme
    self.appButton.titleLabel.font = [UIFont systemFontOfSize:buttonLabelFontSize];
    [self.appButton addTarget:self action:@selector(appButtonTapped) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self addSubview:self.appButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.appButton.leadingAnchor constraintEqualToAnchor:self.iconBackgroundView.leadingAnchor constant:0],
        [self.appButton.topAnchor constraintEqualToAnchor:self.iconBackgroundView.bottomAnchor constant:iconAndButtonSpacing],
        [self.appButton.widthAnchor constraintEqualToConstant:appButtonWidth],
        [self.appButton.heightAnchor constraintEqualToConstant:buttonHeight],
        // [self.launchButton.titleLabel.leadingAnchor constraintEqualToAnchor:self.launchButton.imageView.trailingAnchor constant:3*_sizeFactor]
    ]];
    
    
    // 开始串流按钮
    self.launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.launchButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.launchButton.frame = CGRectMake(0, 0, 150, 50);
    self.launchButton.backgroundColor = defaultBlue;
    
    self.launchButton.layer.cornerRadius = 2*(uint16_t)(cardWidth*0.0377/2);
    [self.launchButton setTitle:[LocalizationHelper localizedStringForKey:@"  Launch"] forState:UIControlStateNormal];
    [self.launchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; // theme
    self.launchButton.titleLabel.font = [UIFont boldSystemFontOfSize:buttonLabelFontSize];
    self.launchButton.tintColor = [UIColor whiteColor];
    [self.launchButton addTarget:self action:@selector(launchButtonTapped) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self addSubview:self.launchButton];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:buttonHeight*0.263];
        [self.launchButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:config] forState:UIControlStateNormal];
        
    } else {
        // Fallback on earlier versions
    }
    
    
    [NSLayoutConstraint activateConstraints:@[
        [self.launchButton.leadingAnchor constraintEqualToAnchor:self.appButton.trailingAnchor constant:15*_sizeFactor],
        [self.launchButton.centerYAnchor constraintEqualToAnchor:self.appButton.centerYAnchor constant:0],
        [self.launchButton.widthAnchor constraintEqualToConstant:launchButtonWidth],
        [self.launchButton.heightAnchor constraintEqualToConstant:buttonHeight],
        // [self.launchButton.titleLabel.leadingAnchor constraintEqualToAnchor:self.launchButton.imageView.trailingAnchor constant:3*_sizeFactor]
    ]];
    
    // 配对按钮
    self.pairButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pairButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.pairButton.frame = CGRectMake(0, 0, 150, 50);
    self.pairButton.backgroundColor = [ThemeManager textTintColorWithAlpha];
    self.pairButton.layer.cornerRadius =  2*(uint16_t)(cardWidth*0.0377/2);
    [self.pairButton setTitle:[LocalizationHelper localizedStringForKey:@"  Pair with PIN"] forState:UIControlStateNormal];
    [self.pairButton setTitleColor:defaultBlue forState:UIControlStateNormal]; // theme
    self.pairButton.titleLabel.font = [UIFont boldSystemFontOfSize:buttonLabelFontSize];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:buttonHeight/3.4 weight:UIImageSymbolWeightBold];
        UIImage *templateImage = [UIImage systemImageNamed:@"lock.open.fill" withConfiguration:config];
        UIImage *coloredImage = [templateImage imageWithTintColor:defaultBlue renderingMode:UIImageRenderingModeAlwaysOriginal];
        [self.pairButton setImage:coloredImage forState:UIControlStateNormal];
    } else {
        // Fallback on earlier versions
    }
    self.pairButton.backgroundColor = [ThemeManager textTintColorWithAlpha];
    [self.pairButton setTitleColor:defaultBlue forState:UIControlStateNormal]; // theme
    
    [self.pairButton addTarget:self action:@selector(pairButtonTapped) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self addSubview:self.pairButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.pairButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_cardContentpadding],
        [self.pairButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-_cardContentpadding],
        [self.pairButton.topAnchor constraintEqualToAnchor:self.iconBackgroundView.bottomAnchor constant:iconAndButtonSpacing],
        // [self.pairButton.widthAnchor constraintEqualToConstant:launchButtonWidth],
        [self.pairButton.heightAnchor constraintEqualToConstant:buttonHeight],
    ]];
    
    
    
    
    // 唤醒按钮
    self.wakeupButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.wakeupButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.wakeupButton.frame = CGRectMake(0, 0, 150, 50);
    self.wakeupButton.backgroundColor = [ThemeManager textTintColorWithAlpha];
    self.wakeupButton.layer.cornerRadius = 2*(uint16_t)(cardWidth*0.0377/2);
    [self.wakeupButton setTitle:[LocalizationHelper localizedStringForKey:@"  Wake-on-LAN"] forState:UIControlStateNormal];
    [self.wakeupButton setTitleColor:defaultBlue forState:UIControlStateNormal]; // theme
    self.wakeupButton.titleLabel.font = [UIFont boldSystemFontOfSize:buttonLabelFontSize];
    [self.wakeupButton addTarget:self action:@selector(wakeupButtonTapped) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self addSubview:self.wakeupButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.wakeupButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_cardContentpadding],
        [self.wakeupButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-_cardContentpadding],
        [self.wakeupButton.topAnchor constraintEqualToAnchor:self.iconBackgroundView.bottomAnchor constant:iconAndButtonSpacing],
        // [self.pairButton.widthAnchor constraintEqualToConstant:launchButtonWidth],
        [self.wakeupButton.heightAnchor constraintEqualToConstant:buttonHeight],
    ]];
    
    
    
    //分隔线
    _separatorLine = [[UIView alloc] init];
    _separatorLine.backgroundColor = [UIColor colorWithWhite:0.3 alpha:5.0];
    _separatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_separatorLine];
    [NSLayoutConstraint activateConstraints:@[
        [_separatorLine.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:_cardContentpadding],
        [_separatorLine.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-_cardContentpadding],
        [_separatorLine.centerYAnchor constraintEqualToAnchor:_iconBackgroundView.bottomAnchor constant: iconAndButtonSpacing/2],
        [_separatorLine.heightAnchor constraintEqualToConstant:1.0/UIScreen.mainScreen.scale]
    ]];
    
    // 透明按钮
    self.transparentButton = [UIButton buttonWithType:UIButtonTypeCustom];
    // self.transparentButton.frame = CGRectMake(50, 100, 100, 100); // 设置点击区域
    self.transparentButton.translatesAutoresizingMaskIntoConstraints = NO;
    // 设置透明背景和无内容
    self.transparentButton.backgroundColor = [UIColor clearColor];
    [self.transparentButton setTitle:@"" forState:UIControlStateNormal];
    [self.transparentButton setImage:nil forState:UIControlStateNormal];
    [self.transparentButton addTarget:self action:@selector(appButtonTapped) forControlEvents:UIControlEventPrimaryActionTriggered];
    
    [self addSubview:self.transparentButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.transparentButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
        [self.transparentButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:0],
        [self.transparentButton.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],
        [self.transparentButton.bottomAnchor constraintEqualToAnchor:self.separatorLine.topAnchor],
    ]];
    
    
    _widthConstraint.constant = _cardContentpadding*2 + appButtonWidth + 15*_sizeFactor + launchButtonWidth;
    _heightConstraint.constant = _cardContentpadding*2 + _iconBackgroundView.frame.size.height + iconAndButtonSpacing + buttonHeight + 1;
    
    _size = CGSizeMake(_widthConstraint.constant, _heightConstraint.constant);
    
    [self updateTheme:ThemeManager.userInterfaceStyle];
}

- (void)createBackgroundLayer{
    backgroundLayer = [CAGradientLayer layer];
    UIColor *gradientColorDark = [UIColor colorWithRed:0.0 green:0.319 blue:0.64 alpha:1.0];
    UIColor *gradientColorLight = [gradientColorDark colorWithAlphaComponent:0.52];
    CGColorRef gradientColorRef = ThemeManager.userInterfaceStyle == UIUserInterfaceStyleDark ? gradientColorDark.CGColor : gradientColorLight.CGColor;
    backgroundLayer.colors = @[
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)gradientColorRef
    ];
    
    backgroundLayer.locations = @[@0, @0.18, @0.5, @1];
    backgroundLayer.startPoint = CGPointMake(0.25, 0.5);
    backgroundLayer.endPoint = CGPointMake(0.75, 0.5);
    
    CGAffineTransform transform = CGAffineTransformMake(-1.01, -1, 1, -3.67, 0.5, 2.83);
    backgroundLayer.transform = CATransform3DMakeAffineTransform(transform);
    [self.layer insertSublayer:backgroundLayer atIndex:0];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    backgroundLayer.bounds = CGRectInset(self.bounds, -0.5 * self.bounds.size.width, -0.5 * self.bounds.size.height);
    backgroundLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    [self updateContentsForHost:_host]; // quick update before looping
}

- (void)tintAdjustmentModeDidChange {
    // [super tintAdjustmentModeDidChange];
    NSLog(@"tintChanged........");
    self.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
}


- (void)updateTheme:(UIUserInterfaceStyle)userIterfaceStyle{
    self.backgroundColor = [ThemeManager widgetBackgroundColor];
    _hostNameLabel.textColor = [ThemeManager textColor];
    [_appButton setTitleColor:[ThemeManager appPrimaryColor] forState:UIControlStateNormal];
    _separatorLine.backgroundColor = [ThemeManager separatorColor];
    backgroundLayer.hidden = NO;
    [self updateContentsForHost:_host];
}

- (void)didMoveToSuperview {
    // Start our update loop when we are added to our cell
    if (self.superview != nil && _host != nil) {
        NSLog(@"start update loop");
        [self updateLoop];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    /*
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateTheme:self.traitCollection.userInterfaceStyle];
        }
    } else {
        [self updateTheme:UIUserInterfaceStyleDark];
    }*/
}

- (bool)isDarkTheme{
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

- (void) updateLoop {
    // Stop immediately if the view has been detached
    if (self.superview == nil) {
        return;
    }
    
    NSLog(@"hostCard update loop %f", CACurrentMediaTime());
    
    [self updateContentsForHost:_host];
    
    // Queue the next refresh cycle
    if(![self.delegate isStreaming]) [self performSelector:@selector(updateLoop) withObject:self afterDelay:REFRESH_CYCLE];
}

- (void) updateContentsForHost:(TemporaryHost*)host {
    _hostNameLabel.text = host.name;
    backgroundLayer.hidden = !(host.state == StateOnline && host.pairState == PairStatePaired);
    
    switch (host.state) {
        case StateOnline:
            [_hostSpinner stopAnimating];
            _statusLabel.textColor = defaultGreen;
            _statusLabel.text = [LocalizationHelper localizedStringForKey:@"Online"];
            self.statusIcon.image = [[UIImage imageNamed:@"wifi_green"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            self.statusIcon.hidden = NO;
            _appButton.titleLabel.font = [UIFont systemFontOfSize:buttonLabelFontSize];
            if(host.pairState == PairStatePaired){
                _hostIconView.tintColor = [UIColor whiteColor];
                _iconBackgroundView.backgroundColor = defaultBlue;
                lockIconView.hidden = YES;
                [_appButton setTitle:[LocalizationHelper localizedStringForKey:@"Applications"] forState:UIControlStateNormal];
                [_launchButton setTitle:[LocalizationHelper localizedStringForKey:@"  Launch"] forState:UIControlStateNormal];
                [_appButton setEnabled:YES];
                [_launchButton setEnabled:YES];
                _appButton.hidden = NO;
                _launchButton.hidden = NO;
                _pairButton.hidden = YES;
                _wakeupButton.hidden = YES;
                                
                [_appButton setTitleColor:defaultBlue forState:UIControlStateNormal]; // theme
                if (@available(iOS 13.0, *)) {
                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:buttonHeight*0.263];
                    [self.launchButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:config] forState:UIControlStateNormal];
                } else {
                }
                _launchButton.backgroundColor = defaultBlue;
                [_launchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; // theme
            }
            else {
                _iconBackgroundView.backgroundColor = [ThemeManager appPrimaryColorWithAlpha];
                UIColor* iconColor = [[UIColor whiteColor] colorWithAlphaComponent:[self isDarkTheme] ? 0.63 : 1];
                _hostIconView.tintColor = iconColor;
                lockIconView.tintColor = iconColor;
                lockIconView.hidden = NO;
                _appButton.hidden = YES;
                _launchButton.hidden = YES;
                _pairButton.hidden = NO;
                _wakeupButton.hidden = YES;
            }
            break;
        case StateOffline:
            [_hostSpinner stopAnimating];
            // _iconBackgroundView.backgroundColor = _userIterfaceStyle == UIUserInterfaceStyleDark ? [UIColor appBackgroundColorDark] : [UIColor appBackgroundColorLight];
            _iconBackgroundView.backgroundColor = [ThemeManager appBackgroundColor];
            _statusLabel.textColor = [ThemeManager textColorGray];
            _statusLabel.text = [LocalizationHelper localizedStringForKey: @"Offline"];
            _statusIcon.tintColor = [ThemeManager textColorGray];
            if (@available(iOS 13.0, *)) {
                _statusIcon.image = [UIImage systemImageNamed:@"exclamationmark.triangle.fill"];
            } else {
                self.statusIcon.hidden = YES;
            }
            
            bool hostPaired = host.pairState == PairStatePaired;
            
            _hostIconView.tintColor = [ThemeManager lowProfileGray];
            lockIconView.tintColor = [ThemeManager lowProfileGray];
            lockIconView.hidden = hostPaired;
            _appButton.hidden = YES;
            _launchButton.hidden = YES;
            _pairButton.hidden = YES;
            _wakeupButton.hidden = NO;
            
            if (@available(iOS 13.0, *)) {
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:buttonHeight/3.45 weight:UIImageSymbolWeightBold];
                UIImage *templateImage = [UIImage systemImageNamed:@"power" withConfiguration:config];
                UIImage *coloredImage = [templateImage imageWithTintColor:hostPaired ? defaultBlue : [ThemeManager textColorGray] renderingMode:UIImageRenderingModeAlwaysOriginal];
                [self.wakeupButton setImage:coloredImage forState:UIControlStateNormal];
            } else {
                // Fallback on earlier versions
            }

            self.wakeupButton.backgroundColor = hostPaired ? [ThemeManager textTintColorWithAlpha] : [[ThemeManager textColorGray] colorWithAlphaComponent:0.2];
            [self.wakeupButton setTitleColor: hostPaired ? defaultBlue : [ThemeManager textColorGray] forState:UIControlStateNormal];
            
            break;
        case StateUnknown:
            _hostSpinner.color = [UIColor whiteColor];
            [_hostSpinner startAnimating];
            // _iconBackgroundView.backgroundColor = _userIterfaceStyle == UIUserInterfaceStyleDark ? [UIColor appBackgroundColorDark] : [UIColor appBackgroundColorLight];
            _iconBackgroundView.backgroundColor = [ThemeManager appPrimaryColorWithAlpha];
            _statusLabel.textColor = [ThemeManager textColorGray];
            _statusLabel.text = [LocalizationHelper localizedStringForKey: @"Detecting..."];
            _statusIcon.tintColor = [ThemeManager textColorGray];
            if (@available(iOS 13.0, *)) {
                _statusIcon.image = [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
            } else {
                self.statusIcon.hidden = YES;
            }
            // _hostIconView.tintColor = [UIColor lowProfileGray];
            _hostIconView.tintColor = defaultBlue;
            lockIconView.hidden = YES;
            _appButton.hidden = YES;
            _launchButton.hidden = YES;
            _pairButton.hidden = YES;
            _wakeupButton.hidden = NO;
            
            [_wakeupButton setTitleColor:[ThemeManager textColorGray] forState:UIControlStateNormal]; // theme
            if (@available(iOS 13.0, *)) {
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:buttonHeight/3.45 weight:UIImageSymbolWeightBold];
                UIImage *templateImage = [UIImage systemImageNamed:@"power" withConfiguration:config];
                UIImage *coloredImage = [templateImage imageWithTintColor:[ThemeManager textColorGray] renderingMode:UIImageRenderingModeAlwaysOriginal];
                [self.wakeupButton setImage:coloredImage forState:UIControlStateNormal];
            } else {
                // Fallback on earlier versions
            }
            self.wakeupButton.backgroundColor = [[ThemeManager textColorGray] colorWithAlphaComponent:0.2];
            [self.wakeupButton setTitleColor:[ThemeManager textColorGray] forState:UIControlStateNormal];
            break;
        default:break;
    }
}


@end
