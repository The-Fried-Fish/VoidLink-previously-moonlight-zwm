//
//  SettingsViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.1
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "SettingsViewController.h"
#import "TemporarySettings.h"
#import "DataManager.h"
#import "ThemeManager.h"

#import <UIKit/UIGestureRecognizerSubclass.h>
#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "LocalizationHelper.h"

@implementation SettingsViewController {
    NSLayoutConstraint *parentStackLeadingConstraint;
    NSLayoutConstraint *parentStackWidthConstraint;
    
    NSInteger _bitrate;
    NSInteger _lastSelectedResolutionIndex;
    bool justEnteredSettingsView;
    uint16_t oswLayoutFingers;
    CustomEdgeSlideGestureRecognizer *slideToCloseSettingsViewRecognizer;
    NSMutableDictionary *_settingStackDict;
    NSMutableArray *_favoriteSettingStackIdentifiers;
    bool settingStackWillBeRelocatedToLowestPosition;
    uint8_t currentSettingsMenuMode;
    UIView *snapshot;
    UIStackView* capturedStack;
    CADisplayLink *_autoScrollDisplayLink;
    CGFloat _scrollSpeed;
    CGFloat _currentRefreshRate;
    MenuSectionView *touchAndControlSection;
    NSMutableSet* hiddenStacks;
}

@dynamic overrideUserInterfaceStyle;


//static NSString* bitrateFormat;
static const int bitrateTable[] = {
    500,
    1000,
    1500,
    2000,
    2500,
    3000,
    4000,
    5000,
    6000,
    7000,
    8000,
    9000,
    10000,
    11000,
    12000,
    13000,
    14000,
    15000,
    16000,
    17000,
    18000,
    19000,
    20000,
    21000,
    22000,
    23000,
    24000,
    25000,
    26000,
    27000,
    28000,
    29000,
    30000,
    31000,
    32000,
    33000,
    34000,
    35000,
    36000,
    37000,
    38000,
    39000,
    40000,
    41000,
    42000,
    43000,
    44000,
    45000,
    46000,
    47000,
    48000,
    49000,
    50000,
    50000,
    51000,
    52000,
    53000,
    54000,
    55000,
    56000,
    57000,
    58000,
    59000,
    60000,
    61000,
    62000,
    63000,
    64000,
    65000,
    66000,
    67000,
    68000,
    69000,
    70000,
    80000,
    90000,
    100000,
    110000,
    120000,
    130000,
    140000,
    150000,
    160000,
    170000,
    180000,
    200000,
    220000,
    240000,
    260000,
    280000,
    300000,
    320000,
    340000,
    360000,
    380000,
    400000,
    420000,
    440000,
    460000,
    480000,
    500000,
};

const int RESOLUTION_TABLE_SIZE = 6;
const int RESOLUTION_TABLE_CUSTOM_INDEX = RESOLUTION_TABLE_SIZE - 1;
CGSize resolutionTable[RESOLUTION_TABLE_SIZE];

-(uint16_t)controllerTypeToSegmentIndex:(uint16_t)type{
    uint16_t index;
    switch (type) {
        case LI_CTYPE_XBOX:
            index = 0;
            break;
        case LI_CTYPE_PS:
            index = 1;
            break;
        default:
            index = 2;
            break;
    }
    return index;
}

-(uint16_t)segmentIndexToControllerType:(uint16_t)index{
    uint16_t type;
    switch (index) {
        case 0:
            type = LI_CTYPE_XBOX;
            break;
        case 1:
            type = LI_CTYPE_PS;
            break;
        default:
            type = LI_CTYPE_UNKNOWN;
            break;
    }
    return type;
}

-(int)getSliderValueForBitrate:(NSInteger)bitrate {
    int i;
    
    for (i = 0; i < (sizeof(bitrateTable) / sizeof(*bitrateTable)); i++) {
        if (bitrate <= bitrateTable[i]) {
            return i;
        }
    }
    
    // Return the last entry in the table
    return i - 1;
}

// This view is rooted at a ScrollView. To make it scrollable,
// we'll update content size here.
-(void)viewDidLayoutSubviews {
    CGFloat highestViewY = 0;
    
    // Enumerate the scroll view's subviews looking for the
    // highest view Y value to set our scroll view's content
    // size.
    
    for (UIView* view in self.scrollView.subviews) {
        // UIScrollViews have 2 default child views
        // which represent the horizontal and vertical scrolling
        // indicators. Ignore any views we don't recognize.
        if (![view isKindOfClass:[UILabel class]] &&
            ![view isKindOfClass:[UISegmentedControl class]] &&
            ![view isKindOfClass:[UISlider class]]) {
            continue;
        }
        
        CGFloat currentViewY = view.frame.origin.y + view.frame.size.height;
        if (currentViewY > highestViewY) {
            highestViewY = currentViewY;
        }
    }
    
    // Add a bit of padding so the view doesn't end right at the button of the display
    self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, _parentStack.frame.size.height + [self getStandardNavBarHeight] + 20);
    double delayInSeconds = 3;
    // Convert the delay into a dispatch_time_t value
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    // Perform some task after the delay
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{// Code to execute after the delay
        // [self updateResolutionAccordingly];
    });
}

// Adjust the subviews for the safe area on the iPhone X.
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
}

BOOL isCustomResolution(int resolutionSelected) {
    return resolutionSelected == RESOLUTION_TABLE_CUSTOM_INDEX;
}

+ (bool)isLandscapeNow {
    return CGRectGetWidth([[UIScreen mainScreen]bounds]) > CGRectGetHeight([[UIScreen mainScreen]bounds]);
}

- (bool)isFullScreenRequired {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSNumber *requiresFullScreen = infoDictionary[@"UIRequiresFullScreen"];
    
    if (requiresFullScreen != nil) {
        return [requiresFullScreen boolValue];
    }
    // Default behavior if the key is not set
    return true;
}

- (bool)isAirPlayEnabled{
    return [self.externalDisplayModeSelector selectedSegmentIndex] == 1;
}

- (void)updateResolutionTable{
    if(self.mainFrameViewController.settingsExpandedInStreamView) return;

    NSInteger externalDisplayMode = [self.externalDisplayModeSelector selectedSegmentIndex];
    // 调用主界面方法统一填充 resolutionTable
    [self.mainFrameViewController fillResolutionTable:resolutionTable externalDisplayMode:externalDisplayMode];

    [self updateResolutionDisplayLabel];
}

// this will also be called back when device orientation changes
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    double delayInSeconds = 0.7;
    // Convert the delay into a dispatch_time_t value
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    // Perform some task after the delay
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{// Code to execute after the delay
        [self updateResolutionTable];
    });
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:NO];
    [self updateParentStackHorizontalConstraints];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:) // handle orientation change since i made portrait mode available
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
 }

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:NO];
    [self updateResolutionTable];
    [self.customResolutionSwitch addTarget:self action:@selector(customResolutionSwitched:) forControlEvents:UIControlEventValueChanged];
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings *currentSettings = [dataMan getSettings];

    //CGSize currentResolution = CGSizeMake(currentSettings.width.intValue, currentSettings.height.intValue);
    [self.customResolutionSwitch setOn: isCustomResolution(currentSettings.resolutionSelected.intValue)];
    [self.resolutionSelector setEnabled:!self.customResolutionSwitch.isOn];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsViewClosedNotification" object:self]; // notify other view that settings view just closed
}


- (SettingsMenuMode)getSettingsMenuMode{
    return currentSettingsMenuMode;
}

- (void)edgeSwiped {
    [self.mainFrameViewController closeSettingViewAnimated:YES];
}

- (BOOL)isIPhone {
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
}

- (CGFloat)getStandardNavBarHeight{
    return [self isIPhone] ? UINavigationBarHeightIPhone : UINavigationBarHeightIPad;
}


- (void)initParentStack{
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    // 可选：确保 scrollView 开启垂直滚动
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;

    /*
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        // [self.scrollView.topAnchor constraintEqualToAnchor:],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
     */

    _parentStack = [[UIStackView alloc] init];
    _parentStack.axis = UILayoutConstraintAxisVertical;
    _parentStack.spacing = 0;
    _parentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:_parentStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [_parentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant: currentSettingsMenuMode == AllSettings ? [self getStandardNavBarHeight] : [self getStandardNavBarHeight]+10],
        [_parentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-20],
    ]];

    [self updateParentStackHorizontalConstraints];
}

-(void)deviceOrientationDidChange:(NSNotification *)notification {
    [self updateParentStackHorizontalConstraints];
}

- (void)updateParentStackHorizontalConstraints{
    if(![self isIPhone]){
        [NSLayoutConstraint activateConstraints:@[
            [_parentStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant: 0], //mark: settingMenuLayout
            [_parentStack.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-20] // section width adjusted here
        ]];
        return;
    }
    
    UIWindow *keyWindow = [UIApplication sharedApplication].windows.firstObject;
    
    if (@available(iOS 13.0, *)) {
        if(parentStackWidthConstraint && parentStackLeadingConstraint) [NSLayoutConstraint deactivateConstraints:@[parentStackLeadingConstraint, parentStackWidthConstraint]];
        UIInterfaceOrientation currentOrientation = keyWindow.windowScene.interfaceOrientation;
        switch (currentOrientation) {
            case UIInterfaceOrientationLandscapeRight:
                parentStackLeadingConstraint = [_parentStack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:0];
                parentStackWidthConstraint = [_parentStack.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-10];
                break;
            default:
                parentStackLeadingConstraint = [_parentStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10];
                parentStackWidthConstraint = [_parentStack.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-20];
                break;
        }
        [NSLayoutConstraint activateConstraints:@[parentStackLeadingConstraint, parentStackWidthConstraint]];
    } else {
        // Fallback on earlier versions
    }
    
    
    double delayInSeconds = 0.05;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self hideOverlappedDynamicLabels];
    });
}


- (UIButton* )findInfoButtonFromStack:(UIStackView* )stack{
    UIButton* button;
    for(UIView *view in stack.subviews){
        if([view isKindOfClass:[UIButton class]] && [view.accessibilityIdentifier isEqualToString:@"infoButton"]) button = (UIButton* )view;
    }
    return button;
}

- (UILabel* )findDynamicLabelFromStack:(UIStackView* )stack{
    UILabel* label;
    for(UIView *view in stack.subviews){
        if([view isKindOfClass:[UILabel class]] && [view.accessibilityIdentifier isEqualToString:@"dynamicLabel"]) label = (UILabel* )view;
    }
    return label;
}

- (void)hideOverlappedDynamicLabelWithinStack:(UIStackView* )stack{
    UILabel* label1 = [self findDynamicLabelFromStack:stack];
    for(UIView* view in stack.subviews){
        if([view isKindOfClass:[UILabel class]] && view != label1){
            UILabel* label2 = (UILabel* )view;
            CGRect textRect1 = [label1 textRectForBounds:label1.bounds limitedToNumberOfLines:label1.numberOfLines];
            CGRect textRect2 = [label2 textRectForBounds:label2.bounds limitedToNumberOfLines:label2.numberOfLines];
            CGRect textRect1InLabel2 = [label2 convertRect:textRect1 fromView:label1];
            if(CGRectIntersectsRect(textRect1InLabel2, textRect2)){
                label1.hidden = YES;return;
            }
        }
    }
    label1.hidden = NO;
}

- (UIView *)findCommonSuperViewFor:(UIView *)view1 andView:(UIView *)view2 {
    if (!view1 || !view2) return nil;
    // 把 view1 的所有 superview 放入集合
    NSMutableSet<UIView *> *superviewsOfView1 = [NSMutableSet set];
    UIView *currentView = view1;
    while (currentView) {
        [superviewsOfView1 addObject:currentView];
        currentView = currentView.superview;
    }
    // 向上遍历 view2，找到第一个也在 view1 superview 集合里的视图
    currentView = view2;
    while (currentView) {
        if ([superviewsOfView1 containsObject:currentView]) {
            return currentView;
        }
        currentView = currentView.superview;
    }
    return nil; // 没有共同父视图（一般不会发生，除非来自不同的视图层次结构）
}

- (void)hideOverlappedDynamicLabels{
    [self hideDynamicLabelsWhenOverlapped:self.parentStack];
}

- (void)hideDynamicLabelsWhenOverlapped:(UIView* )view{
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIStackView class]]) {
            UIStackView *stack = (UIStackView *)subview;
            if(stack.accessibilityIdentifier != nil) {
                // NSLog(@"found stack: %@", stack.accessibilityIdentifier);
                [self hideOverlappedDynamicLabelWithinStack:stack];
            }
        }
        [self hideDynamicLabelsWhenOverlapped:subview];
    }
}

- (void)addDynamicLabelForStack:(UIStackView* )stack{
    UILabel* label = [self findDynamicLabelFromStack:stack];
    if(label) return;
    
    UIButton* button = [self findInfoButtonFromStack:stack];
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 20, 50)];
    label.textAlignment = NSTextAlignmentCenter;
    // label.adjustsFontSizeToFitWidth = YES;
    label.accessibilityIdentifier = @"dynamicLabel";
    label.textColor = [ThemeManager appPrimaryColor];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addSubview:label];
    if(button){
        [NSLayoutConstraint activateConstraints:@[
            [label.trailingAnchor constraintEqualToAnchor:button.leadingAnchor constant:-5],
            //[label.centerYAnchor constraintEqualToAnchor:stack.arrangedSubviews[0].centerYAnchor],
            [label.bottomAnchor constraintEqualToAnchor:stack.arrangedSubviews[0].bottomAnchor],
            [label.heightAnchor constraintEqualToAnchor:stack.arrangedSubviews[0].heightAnchor],
            [label.widthAnchor constraintEqualToConstant:150],
        ]];
    }
    else{
        [NSLayoutConstraint activateConstraints:@[
            [label.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor constant:-5],
            [label.heightAnchor constraintEqualToAnchor:stack.arrangedSubviews[0].heightAnchor],
            [label.widthAnchor constraintEqualToConstant:150],
        ]];
    }
}

- (void)addSetting:(UIStackView *)stack ofId:(NSString* )identifier withInfoTag:(BOOL)attched withDynamicLabel:(BOOL)added to:(MenuSectionView* )menuSection{
    stack.accessibilityIdentifier = identifier;
    [_settingStackDict setObject:stack forKey:identifier];
    if(attched) [self attachInfoTagForStack:stack];
    if(added) [self addDynamicLabelForStack:stack];
    [menuSection addSubStackView:stack];
}
    
- (void)layoutSections{
    MenuSectionView *videoSection = [[MenuSectionView alloc] init];
    videoSection.delegate = self;
    videoSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Video"];
    if (@available(iOS 13.0, *)) {
        [videoSection setSectionWithIcon:[UIImage systemImageNamed:@"waveform"] andSize:20];
    }
    [self addSetting:self.resolutionStack ofId:@"resolutionStack" withInfoTag:NO withDynamicLabel:YES to:videoSection];
    [self addSetting:self.fpsStack ofId:@"fpsStack" withInfoTag:NO withDynamicLabel:NO to:videoSection];
    [self addSetting:self.bitrateStack ofId:@"bitrateStack" withInfoTag:YES withDynamicLabel:YES to:videoSection];
    [self addSetting:self.framepacingStack ofId:@"framepacingStack" withInfoTag:NO withDynamicLabel:NO to:videoSection];
    [self addSetting:self.codecStack ofId:@"codecStack" withInfoTag:NO withDynamicLabel:NO to:videoSection];
    [self addSetting:self.hdrStack ofId:@"hdrStack" withInfoTag:![self hdrSupported] withDynamicLabel:NO to:videoSection];
    [self addSetting:self.yuv444Stack ofId:@"yuv444Stack" withInfoTag:YES withDynamicLabel:NO to:videoSection];
    [self addSetting:self.pipStack ofId:@"pipStack" withInfoTag:YES withDynamicLabel:NO to:videoSection];
    [self addSetting:self.pipStack ofId:@"pipStack" withInfoTag:YES withDynamicLabel:NO to:videoSection];
    [videoSection addToParentStack:_parentStack];
    [videoSection setExpanded:YES];

    touchAndControlSection = [[MenuSectionView alloc] init];
    touchAndControlSection.delegate = self;
    touchAndControlSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Touch & Controller"];
    if (@available(iOS 13.0, *)) {
        [touchAndControlSection setSectionWithIcon:[UIImage imageNamed:@"arcade.stick.console"] andSize:20.5];
    }
    [self addSetting:self.touchModeStack ofId:@"touchModeStack" withInfoTag:YES withDynamicLabel:NO to:touchAndControlSection];
    [self addSetting:self.pointerVelocityDividerStack ofId:@"pointerVelocityDividerStack" withInfoTag:YES withDynamicLabel:YES to:touchAndControlSection];
    [self addSetting:self.pointerVelocityFactorStack ofId:@"pointerVelocityFactorStack" withInfoTag:YES withDynamicLabel:YES to:touchAndControlSection];
    [self addSetting:self.mousePointerVelocityStack ofId:@"mousePointerVelocityStack" withInfoTag:NO withDynamicLabel:YES to:touchAndControlSection];
    [self addSetting:self.onScreenWidgetStack ofId:@"onScreenWidgetStack" withInfoTag:YES withDynamicLabel:YES to:touchAndControlSection];
    [self addSetting:self.swapAbaxyStack ofId:@"swapAbaxyStack" withInfoTag:NO withDynamicLabel:NO to:touchAndControlSection];
    [self addSetting:self.emulatedControllerTypeStack ofId:@"emulatedControllerTypeStack" withInfoTag:YES withDynamicLabel:NO to:touchAndControlSection];
    [self addSetting:self.gyroModeStack ofId:@"gyroModeStack" withInfoTag:YES withDynamicLabel:YES to:touchAndControlSection];
    [self addSetting:self.gyroSensitivityStack ofId:@"gyroSensitivityStack" withInfoTag:NO withDynamicLabel:YES to:touchAndControlSection];
    [touchAndControlSection addToParentStack:_parentStack];
    [touchAndControlSection setExpanded:YES];

    MenuSectionView *gesturesSection = [[MenuSectionView alloc] init];
    gesturesSection.delegate = self;
    gesturesSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Gestures"];
    if (@available(iOS 13.0, *)) {
        [gesturesSection setSectionWithIcon:[UIImage systemImageNamed:@"hand.draw"] andSize:23];
    }
    
    [self addSetting:self.softKeyboardGestureStack ofId:@"softKeyboardGestureStack" withInfoTag:YES withDynamicLabel:NO to:gesturesSection];
    [self addSetting:self.slideToSettingsScreenEdgeStack ofId:@"slideToSettingsScreenEdgeStack" withInfoTag:NO withDynamicLabel:NO to:gesturesSection];
    [self addSetting:self.slideToToolboxScreenEdgeStack ofId:@"slideToToolboxScreenEdgeStack" withInfoTag:NO withDynamicLabel:NO to:gesturesSection];
    [self addSetting:self.slideToSettingsDistanceStack ofId:@"slideToSettingsDistanceStack" withInfoTag:YES withDynamicLabel:YES to:gesturesSection];
    [gesturesSection addToParentStack:_parentStack];
    [gesturesSection setExpanded:YES];

    MenuSectionView *peripheralSection = [[MenuSectionView alloc] init];
    peripheralSection.delegate = self;
    peripheralSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Peripherals"];
    if (@available(iOS 13.0, *)) {
        [peripheralSection setSectionWithIcon:[UIImage imageNamed:@"cable.connector.video"] andSize:20];
    }
    [self addSetting:self.externalDisplayModeStack ofId:@"externalDisplayModeStack" withInfoTag:YES withDynamicLabel:NO to:peripheralSection];
    [self addSetting:self.localMousePointerModeStack ofId:@"localMousePointerModeStack" withInfoTag:YES withDynamicLabel:NO to:peripheralSection];
    [self addSetting:self.reverseMouseWheelDirectionStack ofId:@"reverseMouseWheelDirectionStack" withInfoTag:NO withDynamicLabel:NO to:peripheralSection];
    [self addSetting:self.citrixX1MouseStack ofId:@"citrixX1MouseStack" withInfoTag:NO withDynamicLabel:NO to:peripheralSection];
    [peripheralSection addToParentStack:_parentStack];
    [peripheralSection setExpanded:YES];

    
    
    MenuSectionView *audioSection = [[MenuSectionView alloc] init];
    audioSection.delegate = self;
    audioSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Audio"];
    if (@available(iOS 13.0, *)) {
        [audioSection setSectionWithIcon:[UIImage imageNamed:@"speaker.wave.2"] andSize:20];
    }
    
    [self addSetting:self.audioOnPcStack ofId:@"audioOnPcStack" withInfoTag:NO withDynamicLabel:NO to:audioSection];
    [self addSetting:self.audioConfigStack ofId:@"audioConfigStack" withInfoTag:NO withDynamicLabel:NO to:audioSection];
    [audioSection addToParentStack:_parentStack];
    [audioSection setExpanded:YES];

    
    MenuSectionView *otherSection = [[MenuSectionView alloc] init];
    otherSection.delegate = self;
    otherSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Others"];
    if (@available(iOS 13.0, *)) {
        [otherSection setSectionWithIcon:[UIImage systemImageNamed:@"cube"] andSize:20.5];
    }
    [self addSetting:self.statsOverlayStack ofId:@"statsOverlayStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];
    [self addSetting:self.unlockDisplayOrientationStack ofId:@"unlockDisplayOrientationStack" withInfoTag:YES withDynamicLabel:NO to:otherSection];
    [self addSetting:self.backgroundSessionTimerStack ofId:@"backgroundSessionTimerStack" withInfoTag:NO withDynamicLabel:YES to:otherSection];
    [self addSetting:self.optimizeGamesStack ofId:@"optimizeGamesStack" withInfoTag:YES withDynamicLabel:NO to:otherSection];
    [self addSetting:self.multiControllerStack ofId:@"multiControllerStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];
    [self addSetting:self.softKeyboardToolbarStack ofId:@"softKeyboardToolbarStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];
    [otherSection addToParentStack:_parentStack];
    [otherSection setExpanded:YES];
    
    
    MenuSectionView *experimentalSection = [[MenuSectionView alloc] init];
    experimentalSection.delegate = self;
    experimentalSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Experimental"];
    if (@available(iOS 13.0, *)) {
        [experimentalSection setSectionWithIcon:[UIImage imageNamed:@"flask"] andSize:20];
    }
    [self addSetting:self.touchMoveEventIntervalStack ofId:@"touchMoveEventIntervalStack" withInfoTag:NO withDynamicLabel:YES to:experimentalSection];
    [experimentalSection addToParentStack:_parentStack];
    [experimentalSection setExpanded:YES];
}


- (void)handleAutoScroll:(CGPoint)location{
    bool scrollDown = location.y > self.view.bounds.size.height - 100;
    bool scrollUp = location.y < 150;
    
    //NSLog(@"%f flag: %d, %d, obj: %@, locY: %f", CACurrentMediaTime(), scrollUp, scrollDown, _autoScrollDisplayLink, location.y);
    
    if(!(scrollUp||scrollDown)) [self stopAutoScroll];
    
    if((scrollUp||scrollDown) && _autoScrollDisplayLink == nil ){
    
    // NSLog(@"_autoScrollDisplayLink: %@", _autoScrollDisplayLink);
    //if (!_autoScrollDisplayLink) {
        //[_autoScrollDisplayLink ]
        _scrollSpeed = fabs(120/_currentRefreshRate);
        // _scrollSpeed = 2;
        CGFloat scrollDirection = 0;
        if(scrollDown) scrollDirection = 1;
        if(scrollUp) scrollDirection = -1;
        _scrollSpeed = _scrollSpeed * scrollDirection;
        //NSLog(@"%f, scrollSpeed: %f", CACurrentMediaTime(), _scrollSpeed);

        _autoScrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(startScroll)];
        [_autoScrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }

    //}
}

- (void)stopAutoScroll {
    [_autoScrollDisplayLink invalidate];
    _autoScrollDisplayLink = nil;
}

- (BOOL)scrolledToTop {
    return self.scrollView.contentOffset.y <= 0;
}

- (BOOL)scrolledToBottom {
    CGFloat maxOffsetY = self.scrollView.contentSize.height - self.scrollView.bounds.size.height;
    return self.scrollView.contentOffset.y >= maxOffsetY + snapshot.bounds.size.height+50;
}


- (void)startScroll {
    
    if(![self scrolledToTop] && ![self scrolledToBottom]){
        CGPoint snapshotLocation = snapshot.center;
        snapshotLocation = CGPointMake(snapshotLocation.x, snapshotLocation.y+_scrollSpeed);
        snapshot.center = snapshotLocation;
    }
    
    CGPoint offset = self.scrollView.contentOffset;
    CGFloat newY = offset.y + _scrollSpeed;
    
    // 限制滚动范围
    newY = MAX(0, MIN(newY, self.scrollView.contentSize.height - self.scrollView.bounds.size.height+snapshot.bounds.size.height+50));

    [self.scrollView setContentOffset:CGPointMake(offset.x, newY) animated:NO];
    [self updateRelocationIndicatorFor:snapshot.center];
}

- (void)estimateFPSWithCompletion:(void (^)(CGFloat fps))completion {
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleTick:)];

    // 让系统决定刷新率
    link.preferredFramesPerSecond = 0;

    // 关联block和时间戳
    objc_setAssociatedObject(link, @"fpsCompletion", completion, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(link, @"lastTimestamp", @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)handleTick:(CADisplayLink *)link {
    NSTimeInterval lastTimestamp = [objc_getAssociatedObject(link, @"lastTimestamp") doubleValue];
    void (^completion)(CGFloat fps) = objc_getAssociatedObject(link, @"fpsCompletion");

    if (lastTimestamp > 0) {
        NSTimeInterval delta = link.timestamp - lastTimestamp;
        CGFloat fps = 1.0 / delta;

        // 先停止CADisplayLink，避免继续调用
        [link invalidate];
        link = nil;

        if (completion) {
            completion(fps);
        }

        // 清理关联，防止内存泄漏
        objc_setAssociatedObject(link, @"fpsCompletion", nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(link, @"lastTimestamp", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(link, @"lastTimestamp", @(link.timestamp), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}


- (NSInteger)parentStackIndexForLocation:(CGPoint)location {
    for (NSInteger i = _parentStack.arrangedSubviews.count-1; i >=0; i--) {
        UIView *subview = _parentStack.arrangedSubviews[i];
        // CGRect frame = [subview convertRect:subview.bounds toView:parentStack];
        CGFloat stackMinY = CGRectGetMinY(subview.frame);
        // NSLog(@" index: %ld, stackY: %f, touchY: %f", (long)i, CGRectGetMidY(subview.frame), location.y);
        if(stackMinY < location.y) return i;
    }
    return 0;
}

- (void)highlightedPurpleBackgroundForView:(UIView* )view{
    view.layer.cornerRadius = 6;
    view.layer.masksToBounds = YES;
    view.clipsToBounds = YES;
    view.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:1 alpha:0.35];
}

- (void)highlightedBackgroundForView:(UIView* )view{
    view.layer.cornerRadius = 6;
    view.layer.masksToBounds = YES;
    view.clipsToBounds = YES;
    view.backgroundColor = [ThemeManager appPrimaryColorWithAlpha];
}


- (void)updateRelocationIndicatorFor:(CGPoint)locationInParentStack{
    uint16_t currentIndex = [self parentStackIndexForLocation:locationInParentStack];
    UIStackView* currentStack;
    for (NSInteger i = _parentStack.arrangedSubviews.count-1; i >=0; i--) {
        currentStack = _parentStack.arrangedSubviews[i];

        if(currentIndex == i){
            settingStackWillBeRelocatedToLowestPosition = false;
            if(i == _parentStack.arrangedSubviews.count-1 && locationInParentStack.y > CGRectGetMaxY(currentStack.frame)){
                [self highlightedPurpleBackgroundForView:snapshot];
                currentStack.backgroundColor = [UIColor clearColor];
                settingStackWillBeRelocatedToLowestPosition = true;
            }
            else{
                [self highlightedBackgroundForView:currentStack];
                snapshot.backgroundColor = [UIColor clearColor];
            }
        }
        else{
            currentStack.layer.cornerRadius = 0;
            currentStack.backgroundColor = [UIColor clearColor];
        }
    }
}

- (void)clearRelocationIndicator{
    for (UIView* view in _parentStack.arrangedSubviews) {
        view.layer.cornerRadius = 0;
        view.backgroundColor = [UIColor clearColor];
    }
}

- (void)findCapturedStackByTouchLocation:(CGPoint)point{
    UIView *touchedView = [_parentStack hitTest:point withEvent:nil];
    while(touchedView){
        NSLog(@"view captured: %@, %@", touchedView, touchedView.accessibilityIdentifier);
        if([touchedView isKindOfClass:[UIStackView class]] && touchedView.accessibilityIdentifier != nil){
            capturedStack = (UIStackView *)touchedView;
            break;
        }
        touchedView = touchedView.superview;
    }
}

- (UIAlertController* )prepareAddToFavoriteActionSheet{
    // actionsheet
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *addFavoriteAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Add to favorite"]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self addSettingToFavorite:self->capturedStack];
        self->capturedStack.backgroundColor = [UIColor clearColor];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[self isIPhone] ? [LocalizationHelper localizedStringForKey:@"Cancel"] : @""
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * _Nonnull action) {
        self->capturedStack.backgroundColor = [UIColor clearColor];
    }];
    
    [actionSheet addAction:addFavoriteAction];
    [actionSheet addAction:cancelAction];
    return actionSheet;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    CGPoint locationInParentStack = [gesture locationInView:_parentStack];
    CGPoint locationInRootView = [gesture locationInView:self.view.superview];
    if(currentSettingsMenuMode == AllSettings &&gesture.state == UIGestureRecognizerStateBegan) {
        [self findCapturedStackByTouchLocation:locationInParentStack];
        if(capturedStack == nil) return;
        [self highlightedBackgroundForView:capturedStack];
        UIAlertController* actionSheet = [self prepareAddToFavoriteActionSheet];
        actionSheet.popoverPresentationController.sourceView = capturedStack;
        [self presentViewController:actionSheet animated:YES completion:nil];
    }
    
    
    static CGPoint originalCenter;
    static NSInteger originalIndex;
    if(gesture.state == UIGestureRecognizerStateBegan){
        
        [self estimateFPSWithCompletion:^(CGFloat fps) {
            self->_currentRefreshRate = fps;
        }];
        _autoScrollDisplayLink = nil;
    }

    if(currentSettingsMenuMode == FavoriteSettings){
        switch (gesture.state) {
            case UIGestureRecognizerStateBegan:
                // 创建快照视图
                [self findCapturedStackByTouchLocation:locationInParentStack];
                if(capturedStack == nil) return;

                snapshot = [capturedStack snapshotViewAfterScreenUpdates:YES];
                //snapshot.center = capturedStack.center;
                snapshot.center = locationInParentStack;
                [_parentStack addSubview:snapshot];
                capturedStack.hidden = YES;
                originalCenter = capturedStack.center;
                originalIndex = [_parentStack.arrangedSubviews indexOfObject:capturedStack];
                break;
                
            case UIGestureRecognizerStateChanged:
                if(capturedStack == nil) return;
                snapshot.center = locationInParentStack;
                // NSLog(@"coordY in rootView: %f", locationInRootView.y);
                [self handleAutoScroll:locationInRootView];
                [self updateRelocationIndicatorFor:locationInParentStack];
                
                
                break;
            case UIGestureRecognizerStateCancelled:
            case UIGestureRecognizerStateEnded:
                if(capturedStack == nil) return;
                // 更新快照视图位置
                [self stopAutoScroll];
                [snapshot removeFromSuperview];
                snapshot = nil;
                // 计算新的插入位置
                NSInteger newIndex = [self parentStackIndexForLocation:locationInParentStack];
                [self clearRelocationIndicator];
                NSInteger oldIndex = [_parentStack.arrangedSubviews indexOfObject:capturedStack];
                newIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
                //NSLog(@"newidx %ld, oldidx %ld", newIndex, oldIndex);
                if(settingStackWillBeRelocatedToLowestPosition){
                    newIndex = newIndex + 1;
                    settingStackWillBeRelocatedToLowestPosition = false;
                }
                
                if (newIndex != NSNotFound) {
                    if(newIndex >= _parentStack.arrangedSubviews.count) newIndex = _parentStack.arrangedSubviews.count-1;
                    [_parentStack removeArrangedSubview:capturedStack];
                    [_parentStack insertArrangedSubview:capturedStack atIndex:newIndex];
                    // [parentStack addSubview:capturedStack];
                    originalIndex = newIndex;
                    capturedStack.hidden = NO;
                    [self saveFavoriteSettingStackIdentifiers];
                }
                // 移除快照视图，显示原始视图
                break;
                
            default:break;
        }
    }
}
    

- (void)addSettingToFavorite:(UIStackView* )settingStack{
    
    if([_favoriteSettingStackIdentifiers containsObject:settingStack.accessibilityIdentifier]) return;
    
    [_favoriteSettingStackIdentifiers addObject:settingStack.accessibilityIdentifier];
    for(NSString *identifier in _favoriteSettingStackIdentifiers){
        NSLog(@"favorite setting: %@", identifier);
    }
    
    [self saveFavoriteSettingStackIdentifiers];
}

- (void)attachRemoveButtonForStack:(UIStackView* )stack{
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        [button setImage:[UIImage systemImageNamed:@"minus.circle" withConfiguration:config] forState:UIControlStateNormal];
    } else {
        [button setTitle:[LocalizationHelper localizedStringForKey:@"Remove"] forState:UIControlStateNormal];
    }
    button.accessibilityIdentifier = @"removeButton";
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = [UIColor redColor];
    
    [button addTarget:self action:@selector(removeSettingStackFromFavorites:) forControlEvents:UIControlEventTouchUpInside];
    
    [stack addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor constant:-8],
        [button.topAnchor constraintEqualToAnchor:stack.topAnchor],
    ]];
}

- (void)attachInfoTagForStack:(UIStackView* )stack{
    UIButton* button = [self findInfoButtonFromStack:stack];
    if(button) return;
    button = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13.5 weight:UIImageSymbolWeightBold];
        [button setImage:[UIImage systemImageNamed:@"info.circle" withConfiguration:config] forState:UIControlStateNormal];
    } else {
        [button setTitle:@"info" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    }
    button.accessibilityIdentifier = @"infoButton";
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = [ThemeManager appPrimaryColor];
    
    [button addTarget:self action:@selector(infoButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [stack addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor constant:-4],
        [button.centerYAnchor constraintEqualToAnchor:stack.arrangedSubviews[0].centerYAnchor constant:0],
    ]];
}

-  (void)infoButtonTapped:(UIButton* )sender{
    
    NSString* tipText = @"";
    NSString* onlineDocLink = @"";
    bool showOnlineDocAction = false;
    tipText = sender.superview.accessibilityIdentifier;
    if([sender.superview.accessibilityIdentifier isEqualToString: @"bitrateStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"bitrateStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"yuv444Stack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"yuv444StackTip"];
        showOnlineDocAction = true;
        onlineDocLink = @"https://voidlink.yuque.com/org-wiki-voidlink-znirha/fa3tgr/koeimmrvt4o17auc?singleDoc#";
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"touchModeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"touchModeStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"pointerVelocityDividerStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"pointerVelocityDividerStackTip"];
        showOnlineDocAction = true;
        onlineDocLink =[LocalizationHelper localizedStringForKey:@"pointerVelocityDividerStackDoc"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"pointerVelocityFactorStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"pointerVelocityFactorStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"pointerVelocityFactorStackDoc"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"hdrStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"hdrStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"pipStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"pipStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"softKeyboardGestureStack" ]){
        tipText = [LocalizationHelper localizedStringForKey:@"softKeyboardGestureStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"softKeyboardGestureStackDoc"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"slideToSettingsDistanceStack" ]){
        tipText = [LocalizationHelper localizedStringForKey:@"slideToSettingsDistanceStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"unlockDisplayOrientationStack" ]){
        tipText = [LocalizationHelper localizedStringForKey:@"unlockDisplayOrientationStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"optimizeGamesStack" ]){
        tipText = [LocalizationHelper localizedStringForKey:@"optimizeGamesStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"localMousePointerModeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"localMousePointerModeStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"localMousePointerModeStackDoc"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"onScreenWidgetStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"onScreenWidgetStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"onScreenWidgetStackDoc"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"externalDisplayModeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"externalDisplayModeStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"externalDisplayModeStackDoc"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"emulatedControllerTypeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"emulatedControllerTypeStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"emulatedControllerTypeStackDoc"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"gyroModeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"gyroModeStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"gyroModeStackDoc"];
    }

    
    UIAlertController *tipsAlertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@"Tips"] message:tipText preferredStyle:UIAlertControllerStyleAlert];

    
    /*
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;

    NSDictionary *attributes = @{
        NSParagraphStyleAttributeName: paragraphStyle,
        NSFontAttributeName: [UIFont systemFontOfSize:14]
    };

    NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:tipText
                                                                             attributes:attributes];

    // 使用 KVC 设置 attributedMessage（注意审核风险）
    [tipsAlertController setValue:attributedMessage forKey:@"attributedMessage"];
     */
    
    UIAlertAction *readInstruction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Online Documentation"]
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action){
        NSURL *url = [NSURL URLWithString:onlineDocLink];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }];

    
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                           style:UIAlertActionStyleDefault
                                                     handler:nil];
    
    
    if(showOnlineDocAction) [tipsAlertController addAction:readInstruction];
    [tipsAlertController addAction:okAction];
    [self presentViewController:tipsAlertController animated:YES completion:nil];
}



- (void)removeSettingStackFromFavorites:(UIButton* )sender{
    [sender.superview removeFromSuperview];
    [sender removeFromSuperview];
    [self saveFavoriteSettingStackIdentifiers];
}

- (void)layoutSettingsView{
    [self.scrollView layoutSubviews];
    
    //switchToAll/Favorite 调用此方法时，这些hiddenStack已身处新的superView中， 可以正常执行hidden = YES
    for(UIStackView* stack in hiddenStacks) stack.hidden = YES;

    if(currentSettingsMenuMode == AllSettings){
        for(MenuSectionView* section in _parentStack.arrangedSubviews) [section updateViewForFoldState];
    }
    [self hideDynamicLabelsWhenOverlapped:self.parentStack];
}

// 旧版本iOS兼容必要
- (void)forceRestoreHeightTemporarilyForSettingStackParentView{
    for(UIStackView* stack in hiddenStacks) stack.hidden = NO;
    if(currentSettingsMenuMode == AllSettings){
        for(UIView* view in _parentStack.arrangedSubviews){
            if([view isKindOfClass:[MenuSectionView class]]){
                MenuSectionView* section = (MenuSectionView* )view;
                [section updateViewForFoldState];
            }
        }
    }
    else{
        NSLayoutConstraint* heightConstraint = [_parentStack.heightAnchor constraintEqualToConstant:666];
        heightConstraint.active = YES;
        CGSize fittingSize = [_parentStack systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        heightConstraint.constant = fittingSize.height;
    }
}

- (void)switchToFavoriteSettings{
    [self forceRestoreHeightTemporarilyForSettingStackParentView];
    [_parentStack removeFromSuperview];
    currentSettingsMenuMode = FavoriteSettings;
    [self initParentStack];
    [self updateTheme];
    DataManager* dataMan = [[DataManager alloc] init];
    Settings *currentSettings = [dataMan retrieveSettings];
    currentSettings.settingsMenuMode = [NSNumber numberWithInteger:currentSettingsMenuMode];
    [dataMan saveData];
    
    _parentStack.spacing = [self isIPhone] ? 10 : 15;
    
    [self loadFavoriteSettingStackIdentifiers];
    for(NSString* settingIdentifier in _favoriteSettingStackIdentifiers){
        [_parentStack addArrangedSubview:_settingStackDict[settingIdentifier]];
    }
    [self hideDynamicLabelsWhenOverlapped:self.parentStack];
    [self layoutSettingsView];
}

- (void)switchToAllSettings{
    [self forceRestoreHeightTemporarilyForSettingStackParentView];
    currentSettingsMenuMode = AllSettings;
    [_parentStack removeFromSuperview];
    [self initParentStack];
    [self layoutSections];
    [self updateTheme];
        //[self doneRemoveSettingItem];
    DataManager* dataMan = [[DataManager alloc] init];
    Settings *currentSettings = [dataMan retrieveSettings];
    currentSettings.settingsMenuMode = [NSNumber numberWithInteger:currentSettingsMenuMode];
    [dataMan saveData];
    [self layoutSettingsView];
}

- (void)enterRemoveSettingItemMode{
    currentSettingsMenuMode = RemoveSettingItem;
    for(UIStackView* stack in _parentStack.arrangedSubviews){
        for(UIView* view in stack.subviews){
            if([view.accessibilityIdentifier isEqualToString:@"infoButton"]) view.hidden = YES;
            // view.userInteractionEnabled = false;
        }
        [self attachRemoveButtonForStack:stack];
        // stack.userInteractionEnabled = false;
    }
}

- (void)doneRemoveSettingItem{
    currentSettingsMenuMode = FavoriteSettings;
    for(UIStackView* stack in _parentStack.arrangedSubviews){
        //stack.userInteractionEnabled = true;
        for(UIView* view in stack.subviews){
            //view.
            if([view.accessibilityIdentifier isEqualToString:@"infoButton"]) view.hidden = NO;
            if([view.accessibilityIdentifier isEqualToString:@"removeButton"]) [view removeFromSuperview];
        }
    }
}

/*
- (BOOL)isFirstLaunch {
    NSString *key = @"appHasLaunchedBefore";
    BOOL launchedBefore = [[NSUserDefaults standardUserDefaults] boolForKey:key];

    if (!launchedBefore) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize]; // iOS 12+ 可省略
        return YES;
    }
    return NO;
}
*/

- (void)saveFavoriteSettingStackIdentifiers {
    
    if(currentSettingsMenuMode != AllSettings){
        [_favoriteSettingStackIdentifiers removeAllObjects];
        //for(NSInteger i = 0; i < parentStack.arrangedSubviews.count; i++){
        for(NSInteger i = 0; i < _parentStack.arrangedSubviews.count; i++){
            [_favoriteSettingStackIdentifiers addObject:_parentStack.arrangedSubviews[i].accessibilityIdentifier];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:_favoriteSettingStackIdentifiers forKey:@"FavoriteSettingStackIdentifiers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadFavoriteSettingStackIdentifiers {
    NSArray *savedArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"FavoriteSettingStackIdentifiers"];
        
    if ([savedArray isKindOfClass:[NSArray class]]) {
        _favoriteSettingStackIdentifiers = [savedArray mutableCopy];
    } else {
        _favoriteSettingStackIdentifiers = [NSMutableArray array];
        [_favoriteSettingStackIdentifiers addObject:@"resolutionStack"];
        [_favoriteSettingStackIdentifiers addObject:@"fpsStack"];
        [_favoriteSettingStackIdentifiers addObject:@"bitrateStack"];
        [_favoriteSettingStackIdentifiers addObject:@"framepacingStack"];
        [_favoriteSettingStackIdentifiers addObject:@"codecStack"];
        [_favoriteSettingStackIdentifiers addObject:@"hdrStack"];
        [_favoriteSettingStackIdentifiers addObject:@"yuv444Stack"];
        [_favoriteSettingStackIdentifiers addObject:@"pipStack"];
        [_favoriteSettingStackIdentifiers addObject:@"touchModeStack"];
        [_favoriteSettingStackIdentifiers addObject:@"pointerVelocityDividerStack"];
        [_favoriteSettingStackIdentifiers addObject:@"pointerVelocityFactorStack"];
        [_favoriteSettingStackIdentifiers addObject:@"mousePointerVelocityStack"];
        [_favoriteSettingStackIdentifiers addObject:@"onScreenWidgetStack"];
        [_favoriteSettingStackIdentifiers addObject:@"pipStack"];
        [_favoriteSettingStackIdentifiers addObject:@"backgroundSessionTimerStack"];
        [_favoriteSettingStackIdentifiers addObject:@"statsOverlayStack"];
        [_favoriteSettingStackIdentifiers addObject:@"softKeyboardGestureStack"];
        [_favoriteSettingStackIdentifiers addObject:@"slideToSettingsScreenEdgeStack"];
        [_favoriteSettingStackIdentifiers addObject:@"slideToToolboxScreenEdgeStack"];
        [_favoriteSettingStackIdentifiers addObject:@"slideToSettingsDistanceStack"];
        [_favoriteSettingStackIdentifiers addObject:@"unlockDisplayOrientationStack"];
    }
    
    /*
    for(NSString* str in _favoriteSettingStackIdentifiers){
        NSLog(@"favarite setting loaded: %@", str);
    }
     */
}

- (void)viewDidLoad {
    //[self updateTheme];
    settingStackWillBeRelocatedToLowestPosition = false;
    hiddenStacks = [[NSMutableSet alloc] init];

    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.view addGestureRecognizer:longPress];

    _settingStackDict = [[NSMutableDictionary alloc] init];

 
    for(UIView* view in self.view.subviews){
        [view removeFromSuperview];
    }
    [self initParentStack];
    [self layoutSections];


    // [self swi];

    self->slideToCloseSettingsViewRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(edgeSwiped)];
    slideToCloseSettingsViewRecognizer.edges = UIRectEdgeLeft;
    slideToCloseSettingsViewRecognizer.normalizedThresholdDistance = 0.0;
    slideToCloseSettingsViewRecognizer.EDGE_TOLERANCE = 10;
    slideToCloseSettingsViewRecognizer.immediateTriggering = true;
    slideToCloseSettingsViewRecognizer.delaysTouchesBegan = NO;
    slideToCloseSettingsViewRecognizer.delaysTouchesEnded = NO;
    [self.view addGestureRecognizer:slideToCloseSettingsViewRecognizer];

    justEnteredSettingsView = true;

    // Always run settings in dark mode because we want the light fonts
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* currentSettings = [dataMan getSettings];

    currentSettingsMenuMode = currentSettings.settingsMenuMode.intValue;
    [self loadFavoriteSettingStackIdentifiers];
    if(currentSettings.settingsMenuMode.intValue == FavoriteSettings) [self switchToFavoriteSettings];

    // Ensure we pick a bitrate that falls exactly onto a slider notch
    _bitrate = bitrateTable[[self getSliderValueForBitrate:[currentSettings.bitrate intValue]]];

    // Get the size of the screen with and without safe area insets
    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
    CGFloat screenScale = window.screen.scale;
    CGFloat safeAreaWidth = (window.frame.size.width - window.safeAreaInsets.left - window.safeAreaInsets.right) * screenScale;
    CGFloat fullScreenWidth = window.frame.size.width * screenScale;
    CGFloat fullScreenHeight = window.frame.size.height * screenScale;

    [self.resolutionSelector removeSegmentAtIndex:0 animated:NO]; // remove 360p
    [self.resolutionSelector removeSegmentAtIndex:5 animated:NO]; // remove custom segment

    resolutionTable[5] = CGSizeMake([currentSettings.width integerValue], [currentSettings.height integerValue]); // custom initial value
    [self updateResolutionTable];


    NSInteger framerate;
    switch ([currentSettings.framerate integerValue]) {
        case 30:
            framerate = 0;
            break;
        default:
        case 60:
            framerate = 1;
            break;
        case 120:
            framerate = 2;
            break;
    }

    NSInteger resolution = currentSettings.resolutionSelected.integerValue;
    if(resolution >= RESOLUTION_TABLE_SIZE){
        resolution = 0;
    }

    // Only show the 120 FPS option if we have a > 60-ish Hz display
    bool enable120Fps = false;
    if (@available(iOS 10.3, tvOS 10.3, *)) {
        if ([UIScreen mainScreen].maximumFramesPerSecond > 62) {
            enable120Fps = true;
        }
    }
    if (!enable120Fps) {
        [self.framerateSelector removeSegmentAtIndex:2 animated:NO];
    }

    // Disable codec selector segments for unsupported codecs
    #if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
    if (!VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1))
    #endif
    {
        [self.codecSelector removeSegmentAtIndex:2 animated:NO];
    }
    if (!VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        [self.codecSelector removeSegmentAtIndex:1 animated:NO];
        
        // Only enable the 4K option for "recent" devices. We'll judge that by whether
        // they support HEVC decoding (A9 or later).
        [self.resolutionSelector setEnabled:NO forSegmentAtIndex:3];
    }
    switch (currentSettings.preferredCodec) {
        case CODEC_PREF_AUTO:
            [self.codecSelector setSelectedSegmentIndex:self.codecSelector.numberOfSegments - 1];
            break;
            
        case CODEC_PREF_AV1:
            [self.codecSelector setSelectedSegmentIndex:2];
            break;
            
        case CODEC_PREF_HEVC:
            [self.codecSelector setSelectedSegmentIndex:1];
            break;
            
        case CODEC_PREF_H264:
            [self.codecSelector setSelectedSegmentIndex:0];
            break;
    }

    if (![self hdrSupported]) {
        [self.hdrSwitch setOn:NO];
        [self.hdrSwitch setEnabled:NO];
    }
    else {
        [self.hdrSwitch setOn:currentSettings.enableHdr];
    }

    [self.yuv444Switch setOn:currentSettings.enableYUV444];
    
    [self.pipSwitch setOn:currentSettings.enablePIP];
    if(@available(iOS 15.0, *)) [self.pipSwitch setEnabled:true];
    else{
        [self.pipSwitch setOn:false];
        [self.pipSwitch setEnabled:false];
    }
    
    [self.statsOverlaySelector setSelectedSegmentIndex:currentSettings.statsOverlayLevel.intValue];
    [self.citrixX1MouseSwitch setOn:currentSettings.btMouseSupport];
    [self.optimizeGamesSwitch setOn: currentSettings.optimizeGames];
    [self.framePacingSelector setSelectedSegmentIndex:currentSettings.useFramePacing ? 1 : 0];
    [self.multiControllerSwitch setOn:currentSettings.multiController];
    [self.swapAbxySwitch setOn:currentSettings.swapABXYButtons];
    
    [self.gyroModeSelector setSelectedSegmentIndex:currentSettings.gyroMode.intValue];
    [self.gyroSensitivitySlider setValue: (uint16_t)(currentSettings.gyroSensitivity.floatValue * 100) animated:YES]; // Load old setting.
    [self.gyroSensitivitySlider addTarget:self action:@selector(gyroSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
    [self gyroSensitivitySliderMoved:self.gyroSensitivitySlider];
    
    if (@available(iOS 14.0, tvOS 14.0, *)) nil;
    else{
        [self.gyroModeSelector setEnabled:false forSegmentAtIndex:1];
        [self.gyroModeSelector setEnabled:false forSegmentAtIndex:3];
    }
    
    [self.emulatedControllerTypeSelector setSelectedSegmentIndex:[self controllerTypeToSegmentIndex:currentSettings.emulatedControllerType.intValue]];
    [self.emulatedControllerTypeSelector addTarget:self action:@selector(emulatedControllerTypeChanged:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
    [self emulatedControllerTypeChanged:self.emulatedControllerTypeSelector];
    


    [self.audioOnPcSwitch setOn:currentSettings.playAudioOnPC];
    _lastSelectedResolutionIndex = resolution;
    [self.resolutionSelector setSelectedSegmentIndex:resolution];
    [self.resolutionSelector addTarget:self action:@selector(newResolutionChosen) forControlEvents:UIControlEventValueChanged];

    [self.framerateSelector setSelectedSegmentIndex:framerate];
    [self.framerateSelector addTarget:self action:@selector(updateBitrate) forControlEvents:UIControlEventValueChanged];
    [self.bitrateSlider setMinimumValue:0];
    [self.bitrateSlider setMaximumValue:(sizeof(bitrateTable) / sizeof(*bitrateTable)) - 1];
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:YES];
    [self.bitrateSlider addTarget:self action:@selector(bitrateSliderMoved) forControlEvents:UIControlEventValueChanged];
    [self updateBitrateText];
    [self updateResolutionDisplayLabel];
    if (@available(iOS 18.0, tvOS 18.0, *)) {}else{
        [self.audioConfigSelector removeSegmentAtIndex:1 animated:false];
        [self.audioConfigSelector removeSegmentAtIndex:1 animated:false]; // segment 2 goes away when you remove index 2
        [self.audioConfigSelector setTitle:[LocalizationHelper localizedStringForKey:@"Stereo (surround sound available for iOS18+)"] forSegmentAtIndex:0];
        [self.audioConfigSelector setEnabled:NO];
    }
    switch ([currentSettings.audioConfig integerValue]) {
        case 2:
            [self.audioConfigSelector setSelectedSegmentIndex:0];
            break;
        case 6:
            [self.audioConfigSelector setSelectedSegmentIndex:1];
            break;
        case 8:
            [self.audioConfigSelector setSelectedSegmentIndex:2];
            break;
    }

    // Unlock Display Orientation setting
    bool unlockDisplayOrientationSelectorEnabled = [self isFullScreenRequired] || [self isIPhone];//need "requires fullscreen" enabled in the app bunddle to make runtime orientation limitation working
    if(unlockDisplayOrientationSelectorEnabled) [self.unlockDisplayOrientationSelector setSelectedSegmentIndex:currentSettings.unlockDisplayOrientation ? 1 : 0];
    else [self.unlockDisplayOrientationSelector setSelectedSegmentIndex:1]; // can't lock screen orientation in this mode = Display Orientation always unlocked
    [self.unlockDisplayOrientationSelector setEnabled:unlockDisplayOrientationSelectorEnabled];

    [self.backgroundSessionTimerSlider setValue:(uint32_t)currentSettings.backgroundSessionTimer.floatValue];
    [self.backgroundSessionTimerSlider addTarget:self action:@selector(backgroundSessionTimerSliderMoved:) forControlEvents:UIControlEventValueChanged];
    [self backgroundSessionTimerSliderMoved:self.backgroundSessionTimerSlider];

    // lift streamview setting
    [self.liftStreamViewForKeyboardSelector setSelectedSegmentIndex:currentSettings.liftStreamViewForKeyboard ? 1 : 0];// Load old setting

    // showkeyboard toolbar setting
    [self.softKeyboardToolbarSwitch setOn:currentSettings.showKeyboardToolbar];// Load old setting

    // reverse mouse wheel direction setting
    [self.reverseMouseWheelDirectionSelector setSelectedSegmentIndex:currentSettings.reverseMouseWheelDirection ? 1 : 0];// Load old setting

    //  slide to menu settings
    [self.slideToSettingsScreenEdgeSelector setSelectedSegmentIndex:[self getSelectorIndexFromScreenEdge:(uint32_t)currentSettings.slideToSettingsScreenEdge.integerValue]];
    // Load old setting
    [self.slideToToolboxScreenEdgeSelector setEnabled:false];
    [self.slideToSettingsScreenEdgeSelector addTarget:self action:@selector(slideToSettingsScreenEdgeChanged) forControlEvents:UIControlEventValueChanged];
    [self slideToSettingsScreenEdgeChanged];

    [self.slideToMenuDistanceSlider setValue:currentSettings.slideToSettingsDistance.floatValue];
    [self.slideToMenuDistanceSlider addTarget:self action:@selector(slideToMenuDistanceSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
    [self slideToMenuDistanceSliderMoved:self.slideToMenuDistanceSlider];



    //TouchMode & OSC Related Settings:

    // pointer veloc setting, will be enable/disabled by touchMode
    [self.pointerVelocityModeDividerSlider setValue: (uint8_t)(currentSettings.pointerVelocityModeDivider.floatValue * 100) animated:YES]; // Load old setting.
    [self.pointerVelocityModeDividerSlider addTarget:self action:@selector(pointerVelocityModeDividerSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
    [self pointerVelocityModeDividerSliderMoved:self.pointerVelocityModeDividerSlider];

    // init pointer veloc setting,  will be enable/disabled by touchMode
    [self.touchPointerVelocityFactorSlider setValue: [self map_SliderValue_fromVelocFactor: currentSettings.touchPointerVelocityFactor.floatValue] animated:YES]; // Load old setting.
    [self.touchPointerVelocityFactorSlider addTarget:self action:@selector(touchPointerVelocityFactorSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
    [self touchPointerVelocityFactorSliderMoved:self.touchPointerVelocityFactorSlider];

    // async native touch event
    // [self.asyncNativeTouchPrioritySelector setSelectedSegmentIndex:currentSettings.asyncNativeTouchPriority.intValue]; // load old setting of asyncNativeTouchPriority
    // [self.asyncNativeTouchPrioritySelector addTarget:self action:@selector(asyncNativeTouchPriorityChanged) forControlEvents:UIControlEventValueChanged];

    // init relative touch mouse pointer veloc setting,  will be enable/disabled by touchMode
    [self.mousePointerVelocityFactorSlider setValue:[self map_SliderValue_fromVelocFactor: currentSettings.mousePointerVelocityFactor.floatValue] animated:YES]; // Load old setting.
    [self.mousePointerVelocityFactorSlider addTarget:self action:@selector(mousePointerVelocityFactorSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
    [self mousePointerVelocityFactorSliderMoved:self.mousePointerVelocityFactorSlider];


    // these settings will be affected by onscreenControl & touchMode, must be loaded before them.
    // NSLog(@"osc tool fingers setting test: %d", currentSettings.oscLayoutToolFingers.intValue);
    self->oswLayoutFingers = (uint16_t)currentSettings.oscLayoutToolFingers.intValue; // load old setting of oscLayoutFingers
    uint8_t keyboardToggleFingers = currentSettings.keyboardToggleFingers.intValue;

    [self.softKeyboardGestureSelector setSelectedSegmentIndex:keyboardToggleFingers>=5 ? 3 : keyboardToggleFingers-3];



    // this setting will be affected by touchMode, must be loaded before them.
    NSInteger onscreenControlsLevel = [currentSettings.onscreenControls integerValue];
    [self.onScreenWidgetSelector setSelectedSegmentIndex:onscreenControlsLevel];
    [self.onScreenWidgetSelector addTarget:self action:@selector(onScreenWidgetChanged) forControlEvents:UIControlEventValueChanged];
    [self onScreenWidgetChanged];

    // touch move event interval for native-touch.
    [self.touchMoveEventIntervalSlider setValue:currentSettings.touchMoveEventInterval.intValue animated:YES]; // Load old setting.
    [self.touchMoveEventIntervalSlider addTarget:self action:@selector(touchMoveEventIntervalSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
    [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];


    // this part will enable/disable oscSelector & the asyncNativeTouchPriority selector
    uint8_t touchModeSelectorIndex = currentSettings.touchMode.intValue == NativeTouchOnly ? NativeTouch : currentSettings.touchMode.intValue;
    [self.touchModeSelector setSelectedSegmentIndex:touchModeSelectorIndex]; //Load old touchMode setting
    [self.touchModeSelector addTarget:self action:@selector(touchModeChanged:) forControlEvents:UIControlEventValueChanged];
    [self touchModeChanged:self.touchModeSelector];

    self.enableOswSwitchStack.hidden = !(currentSettings.touchMode.intValue == NativeTouch || currentSettings.touchMode.intValue == NativeTouchOnly);
    [self.enableOswForNativeTouchSwitch setOn:currentSettings.touchMode.intValue != NativeTouchOnly];
    [self.enableOswForNativeTouchSwitch addTarget:self action:@selector(enableOswForNativeTouchSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
    [self enableOswForNativeTouchSwitchFlipped:self.enableOswForNativeTouchSwitch];

    [self.externalDisplayModeSelector setSelectedSegmentIndex:currentSettings.externalDisplayMode.integerValue];
    [self.localMousePointerModeSelector setSelectedSegmentIndex:currentSettings.localMousePointerMode.integerValue];
    
    justEnteredSettingsView = false;
}

- (void)slideToSettingsScreenEdgeChanged{
    if([self.slideToSettingsScreenEdgeSelector selectedSegmentIndex] == 0) [self.slideToToolboxScreenEdgeSelector setSelectedSegmentIndex:1];
    else [self.slideToToolboxScreenEdgeSelector setSelectedSegmentIndex:0];
}

- (void)showCustomOswTip {
    NSString* edgeSide = self.slideToSettingsScreenEdgeSelector.selectedSegmentIndex == 1 ? [LocalizationHelper localizedStringForKey:@"left"] : [LocalizationHelper localizedStringForKey:@"right"];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Rebase in Streaming"]
                                                                             message:[LocalizationHelper localizedStringForKey:@"Open widget tool in streaming by:\nSliding from %@ screen edge to open cmd tool.\nOr tap %d fingers on stream view, number of fingers required:", edgeSide, self->oswLayoutFingers]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"%d", self->oswLayoutFingers];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"]
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
         UITextField *textField = alertController.textFields.firstObject;
         NSString *inputText = textField.text;
         NSInteger fingers = [inputText integerValue];
         if (inputText.length > 0 && fingers >= 4) {
             self->oswLayoutFingers = (uint16_t) fingers;
             NSLog(@"OK button tapped with %d fingers", (uint16_t)fingers);
         } else {
             NSLog(@"OK button tapped with no change");
         }
         
         // Continue execution after the alert is dismissed
         if (!self->_mainFrameViewController.settingsExpandedInStreamView) {
             [self invokeOscLayout]; // Don't open osc layout tool immediately during streaming
         }
                                                         
        [self findDynamicLabelFromStack:self.onScreenWidgetStack].text = [self isCustomOswEnabled] ? [LocalizationHelper localizedStringForKey:@"%d finger tap", self->oswLayoutFingers] : @"";
        [self handleOswGestureChange];}];
    
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (bool)isOswEnabled{
    return [self isNotNativeTouchOnly] && self.onScreenWidgetSelector.selectedSegmentIndex != OnScreenControlsLevelOff;
}

- (bool)isCustomOswEnabled{
    return [self isOswEnabled] && self.onScreenWidgetSelector.selectedSegmentIndex == OnScreenControlsLevelCustom;
}

- (bool)isNotNativeTouchOnly{
    return (self.enableOswForNativeTouchSwitch.isOn && self.touchModeSelector.selectedSegmentIndex == NativeTouch) || self.touchModeSelector.selectedSegmentIndex == RelativeTouch || self.touchModeSelector.selectedSegmentIndex == AbsoluteTouch;
}

- (void)handleOswGestureChange{
    if(justEnteredSettingsView) return;
    if([self isCustomOswEnabled] && oswLayoutFingers == self.softKeyboardGestureSelector.selectedSegmentIndex + 3 && oswLayoutFingers < 6){
        [_softKeyboardGestureSelector setSelectedSegmentIndex:_softKeyboardGestureSelector.selectedSegmentIndex-1];
    }
    for (NSInteger i = 0; i < _softKeyboardGestureSelector.numberOfSegments; i++) {
        [_softKeyboardGestureSelector setEnabled:![self isCustomOswEnabled] || i == 3 ? true : i+3 != oswLayoutFingers forSegmentAtIndex:i]; // 或 NO 来禁用
    }
}

- (void)onScreenWidgetChanged{
    
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    if (isIPhone) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
        self.layoutOnScreenControlsVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
    }
    else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
        self.layoutOnScreenControlsVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
        self.layoutOnScreenControlsVC.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    
    bool customOscEnabled = [self isCustomOswEnabled];
    NSLog(@"customOscEnabled %d", customOscEnabled);
    UILabel* oswDynamicLabel = [self findDynamicLabelFromStack:self.onScreenWidgetStack];
    NSString* labelText = customOscEnabled ? [LocalizationHelper localizedStringForKey:@"%d finger tap", self->oswLayoutFingers] : @"";
    oswDynamicLabel.text = [NSString stringWithFormat:@"  %@  ", labelText];
    oswDynamicLabel.hidden = !customOscEnabled;
    NSLog(@"oswDynamicLabel.hidden %d", oswDynamicLabel.hidden);
    [self handleOswGestureChange];
    if(customOscEnabled && !justEnteredSettingsView) {
        // [self.keyboardToggleFingerNumSlider setValue:3.0];
        // [self keyboardToggleFingerNumSliderMoved];
      [self showCustomOswTip];
    }
}

- (void)invokeOscLayout{
    // init CustomOSC stuff
    /* sets a reference to the correct 'LayoutOnScreenControlsViewController' depending on whether the user is on an iPhone or iPad */
    // self.layoutOnScreenControlsVC = [[LayoutOnScreenControlsViewController alloc] init];
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    if (isIPhone) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
        self.layoutOnScreenControlsVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
    }
    else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
        self.layoutOnScreenControlsVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
        self.layoutOnScreenControlsVC.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    
    self.layoutOnScreenControlsVC.view.backgroundColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    [self presentViewController:self.layoutOnScreenControlsVC animated:YES completion:nil];
}


- (void) pointerVelocityModeDividerSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:self.pointerVelocityDividerStack].text = [NSString stringWithFormat:@"  | %d%% | %d%% |  ", (uint8_t)sender.value, 100-(uint8_t)sender.value];
}

- (void) touchPointerVelocityFactorSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:self.pointerVelocityFactorStack].text = [NSString stringWithFormat:@"  %d%%  ", [self map_velocFactorDisplay_fromSliderValue:sender.value]]; // Update label display
}

- (void) gyroSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:self.gyroSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)sender.value]; // Update label display
}

- (void) backgroundSessionTimerSliderMoved:(UISlider* )sender {
    NSString* labelString;
    labelString = [LocalizationHelper localizedStringForKey:@"  keep %d min  ", (uint16_t)sender.value];
    if(sender.value == 0) labelString = [LocalizationHelper localizedStringForKey:@"  disconnect  "];
    if(sender.value == sender.maximumValue) labelString = [LocalizationHelper localizedStringForKey:@"  keep alive  "];
    [self findDynamicLabelFromStack:self.backgroundSessionTimerStack].text = labelString; // Update label display
}


// veloc factor upto 700%
- (uint16_t) map_velocFactorDisplay_fromSliderValue:(CGFloat)sliderValue{
    uint16_t velocFactorDisplay = 0;
    if(sliderValue > 200) velocFactorDisplay = 200 + ((uint16_t)sliderValue % 200) * 5;
    else velocFactorDisplay = (uint16_t) sliderValue;
    return velocFactorDisplay;
}

// veloc factor upto 700%

- (CGFloat) map_SliderValue_fromVelocFactor:(CGFloat)velocFactor{
    CGFloat sliderValue = 0.0f;
    if(velocFactor < 2.0f) sliderValue = velocFactor * 100;
    else sliderValue = (velocFactor - 2.0) * 100 / 5 + 200;
    return sliderValue;
}

- (void) mousePointerVelocityFactorSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:_mousePointerVelocityStack].text = [NSString stringWithFormat:@"  %d%%  ",[self map_velocFactorDisplay_fromSliderValue:sender.value]];
}

- (uint32_t) getScreenEdgeFromSelector {
    switch (self.slideToSettingsScreenEdgeSelector.selectedSegmentIndex) {
        case 0: return UIRectEdgeLeft;
        case 1: return UIRectEdgeRight;
        case 2: return UIRectEdgeLeft|UIRectEdgeRight;
        default: return UIRectEdgeLeft;
    }
}

- (uint32_t) getSelectorIndexFromScreenEdge: (uint32_t)edge {
    switch (edge) {
        case UIRectEdgeLeft: return 0;
        case UIRectEdgeRight: return 1;
        case UIRectEdgeLeft|UIRectEdgeRight: return 2;
        default: return 0;
    }
    return 0;
}

- (void) widget:(UIView*)widget setEnabled:(bool)enabled{
    if([widget isKindOfClass:[UISlider class]]){
        UISlider* widgetPtr = (UISlider* )widget;
        [widgetPtr setEnabled:enabled];
        if(enabled){
            widgetPtr.alpha = 1.0;
            [widgetPtr setValue:widgetPtr.value + 0.0001]; // this is for low iOS version (like iOS14), only setting this minor value change is able to make widget visibility clear
        }
        else widgetPtr.alpha = 0.5; // this is for updating widget visibility on low iOS version like mini5 ios14
    }
    
    if([widget isKindOfClass:[UISwitch class]]){
        widget.userInteractionEnabled = enabled;
        widget.alpha = enabled ? 1 : 0.5;
    }
}

/*
- (void) asyncNativeTouchPriorityChanged {
    bool isNativeTouch = [self.touchModeSelector selectedSegmentIndex] == NativeTouchOnly || [self.touchModeSelector selectedSegmentIndex] == NativeTouch;
    bool asyncNativeTouchEnabled = [self.asyncNativeTouchPrioritySelector selectedSegmentIndex] != AsyncNativeTouchOff;
    [self widget:self.touchMoveEventIntervalSlider setEnabled:isNativeTouch && asyncNativeTouchEnabled];
}
*/

- (void)touchModeChanged:(UISegmentedControl* )sender {
    // Disable On-Screen Controls & Widgets in non-relative touch mode
    // bool customOscEnabled = [self isOswEnabled] && [self.onScreenWidgetSelector selectedSegmentIndex] == OnScreenControlsLevelCustom;
    bool isNativeTouch = sender.selectedSegmentIndex == NativeTouch;
    //bool asyncNativeTouchEnabled = [self.asyncNativeTouchPrioritySelector selectedSegmentIndex] != AsyncNativeTouchOff;
    self.enableOswSwitchStack.hidden = !isNativeTouch;
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityDividerStack];

    // [self.asyncNativeTouchPrioritySelector setEnabled:![self showOswSelector]]; // this selector stay aligned with oscSelector
    [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityDividerStack];
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityFactorStack];

    [self setHidden:!(sender.selectedSegmentIndex == RelativeTouch) forStack:self.mousePointerVelocityStack];
    [self setHidden:![self isNotNativeTouchOnly] forStack:self.onScreenWidgetStack];
    [self setHidden:![self isNotNativeTouchOnly] forStack:self.swapAbaxyStack];
    [self handleOswGestureChange];

    [touchAndControlSection updateViewForFoldState];
}

- (void)emulatedControllerTypeChanged:(UISegmentedControl* )sender{
    [self setHidden:sender.selectedSegmentIndex == 0 forStack:_gyroModeStack];
    [self setHidden:sender.selectedSegmentIndex == 0 forStack:_gyroSensitivityStack];
    [touchAndControlSection updateViewForFoldState];
}

- (void)setHidden:(BOOL)hidden forStack:(UIStackView* )stack{
    // CGFloat previousSpacing = stack.spacing;
    if(hidden){
        stack.hidden = YES;
        [hiddenStacks addObject:stack];
    }
    else{
        stack.hidden = NO;
        [hiddenStacks removeObject:stack];
    }
}

- (void)enableOswForNativeTouchSwitchFlipped:(UISwitch *)sender{
    //self.onScreenWidgetStack.hidden = !sender.isOn;
    [self setHidden:!sender.isOn forStack:_onScreenWidgetStack];
    //[self setHidden:!sender.isOn forStack:_swapAbaxyStack];
    [self handleOswGestureChange];
    //self.swapAbaxyStack.hidden = !sender.isOn;
    [touchAndControlSection updateViewForFoldState];
}

- (void) updateBitrate {
    NSInteger fps = [self getChosenFrameRate];
    NSInteger width = [self getChosenStreamWidth];
    NSInteger height = [self getChosenStreamHeight];
    NSInteger defaultBitrate;
    
    // This logic is shamelessly stolen from Moonlight Qt:
    // https://github.com/moonlight-stream/moonlight-qt/blob/master/app/settings/streamingpreferences.cpp
    
    // Don't scale bitrate linearly beyond 60 FPS. It's definitely not a linear
    // bitrate increase for frame rate once we get to values that high.
    float frameRateFactor = (fps <= 60 ? fps : (sqrtf(fps / 60.f) * 60.f)) / 30.f;

    // TODO: Collect some empirical data to see if these defaults make sense.
    // We're just using the values that the Shield used, as we have for years.
    struct {
        NSInteger pixels;
        int factor;
    } resTable[] = {
        { 640 * 360, 1 },
        { 854 * 480, 2 },
        { 1280 * 720, 5 },
        { 1920 * 1080, 10 },
        { 2560 * 1440, 20 },
        { 3840 * 2160, 40 },
        { -1, -1 }
    };

    // Calculate the resolution factor by linear interpolation of the resolution table
    float resolutionFactor;
    NSInteger pixels = width * height;
    for (int i = 0;; i++) {
        if (pixels == resTable[i].pixels) {
            // We can bail immediately for exact matches
            resolutionFactor = resTable[i].factor;
            break;
        }
        else if (pixels < resTable[i].pixels) {
            if (i == 0) {
                // Never go below the lowest resolution entry
                resolutionFactor = resTable[i].factor;
            }
            else {
                // Interpolate between the entry greater than the chosen resolution (i) and the entry less than the chosen resolution (i-1)
                resolutionFactor = ((float)(pixels - resTable[i-1].pixels) / (resTable[i].pixels - resTable[i-1].pixels)) * (resTable[i].factor - resTable[i-1].factor) + resTable[i-1].factor;
            }
            break;
        }
        else if (resTable[i].pixels == -1) {
            // Never go above the highest resolution entry
            resolutionFactor = resTable[i-1].factor;
            break;
        }
    }

    defaultBitrate = round(resolutionFactor * frameRateFactor) * 1000;
    _bitrate = MIN(defaultBitrate, 100000);
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:YES];
    
    [self updateBitrateText];
}

- (void) newResolutionChosen {
    [self updateBitrate];
    [self updateResolutionDisplayLabel];
    _lastSelectedResolutionIndex = [self.resolutionSelector selectedSegmentIndex];
    [self updateResolutionTable];
}

- (void)customResolutionSwitched:(UISwitch* )sender{
    if(sender.isOn) [self promptCustomResolutionDialog];
    else [self newResolutionChosen];
    [self.resolutionSelector setEnabled:!sender.isOn];
}

- (void) promptCustomResolutionDialog {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey: @"Enter Custom Resolution"] message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Video Width"];
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        
        if (resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width == 0) {
            textField.text = @"";
        }
        else {
            textField.text = [NSString stringWithFormat:@"%d", (int) resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width];
        }
    }];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Video Height"];
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        
        if (resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height == 0) {
            textField.text = @"";
        }
        else {
            textField.text = [NSString stringWithFormat:@"%d", (int) resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height];
        }
    }];

    [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray * textfields = alertController.textFields;
        UITextField *widthField = textfields[0];
        UITextField *heightField = textfields[1];
        
        long width = [widthField.text integerValue];
        long height = [heightField.text integerValue];
        if (width <= 0 || height <= 0) {
            // Restore the previous selection
            [self.resolutionSelector setSelectedSegmentIndex:self->_lastSelectedResolutionIndex];
            return;
        }
        
        // H.264 maximum
        int maxResolutionDimension = 4096;
        if (@available(iOS 11.0, tvOS 11.0, *)) {
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                // HEVC maximum
                maxResolutionDimension = 8192;
            }
        }
        
        // Cap to maximum valid dimensions
        width = MIN(width, maxResolutionDimension);
        height = MIN(height, maxResolutionDimension);
        
        // Cap to minimum valid dimensions
        width = MAX(width, 256);
        height = MAX(height, 256);

        resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX] = CGSizeMake(width, height);
        [self updateBitrate];
        [self updateResolutionDisplayLabel];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Custom Resolution Selected"] message: [LocalizationHelper localizedStringForKey:@"Custom resolutions are not officially supported by GeForce Experience, so it will not set your host display resolution. You will need to set it manually while in game.\n\nResolutions that are not supported by your client or host PC may cause streaming errors."] preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        // Restore the previous selection
        [self.customResolutionSwitch setOn:false];
        [self.resolutionSelector setEnabled:true];
    }]];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)resolutionDisplayViewTapped:(UITapGestureRecognizer *)sender {
}

- (void) updateResolutionDisplayLabel {
    NSInteger width = [self getChosenStreamWidth];
    NSInteger height = [self getChosenStreamHeight];
    
    [self findDynamicLabelFromStack:_resolutionStack].text = [NSString stringWithFormat:@"%ld × %ld", (long)width, (long)height];
}

- (void) touchMoveEventIntervalSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:self.touchMoveEventIntervalStack].text = sender.enabled ?
    [NSString stringWithFormat:@"  %d μs  ", (uint16_t)self.touchMoveEventIntervalSlider.value] : @"";
}


- (void) slideToMenuDistanceSliderMoved:(UISlider* )sender{
    UILabel* displayLabel = [self findDynamicLabelFromStack:_slideToSettingsDistanceStack];
    // displayLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    NSString* labelText = [LocalizationHelper localizedStringForKey:@"%d%% screen width", (uint8_t)(sender.value * 100)];
    displayLabel.text = [NSString stringWithFormat:@"  %@  ", labelText];
}

- (void) bitrateSliderMoved {
    assert(self.bitrateSlider.value < (sizeof(bitrateTable) / sizeof(*bitrateTable)));
    _bitrate = bitrateTable[(int)self.bitrateSlider.value];
    [self updateBitrateText];
}

- (bool)hdrSupported{
    return VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10);
}

- (void) updateBitrateText {
    // Display bitrate in Mbps
    UILabel* label = [self findDynamicLabelFromStack:self.bitrateStack];
    [label setText:[LocalizationHelper localizedStringForKey:@"  %.1f Mbps  ", _bitrate / 1000.]];
}

- (NSInteger) getChosenFrameRate {
    switch ([self.framerateSelector selectedSegmentIndex]) {
        case 0:
            return 30;
        case 1:
            return 60;
        case 2:
            return 120;
        default:
            abort();
    }
}

- (uint32_t) getChosenCodecPreference {
    // Auto is always the last segment
    if (self.codecSelector.selectedSegmentIndex == self.codecSelector.numberOfSegments - 1) {
        return CODEC_PREF_AUTO;
    }
    else {
        switch (self.codecSelector.selectedSegmentIndex) {
            case 0:
                return CODEC_PREF_H264;
                
            case 1:
                return CODEC_PREF_HEVC;
                
            case 2:
                return CODEC_PREF_AV1;
                
            default:
                abort();
        }
    }
}

- (NSInteger) getChosenStreamHeight {
    // because the 4k resolution can be removed
    if (self.customResolutionSwitch.isOn) {
        return resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height;
    }

    return resolutionTable[[self.resolutionSelector selectedSegmentIndex]].height;
}

- (NSInteger) getChosenStreamWidth {
    // because the 4k resolution can be removed
    if (self.customResolutionSwitch.isOn) {
        return resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width;
    }

    return resolutionTable[[self.resolutionSelector selectedSegmentIndex]].width;
}

- (UIStackView *)findFlatStackViewFrom:(UIView *)view {
    while (view != nil) {
        if ([view isKindOfClass:[UIStackView class]]) {
            UIStackView *stack = (UIStackView *)view;
            BOOL hasNestedStack = NO;
            for (UIView *sub in stack.arrangedSubviews) {
                if ([sub isKindOfClass:[UIStackView class]]) {
                    hasNestedStack = YES;
                    break;
                }
            }
            if (!hasNestedStack) {
                return stack;
            }
        }
        view = view.superview;
    }
    return nil;
}


- (void)updateThemeForLabels:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if(label.accessibilityIdentifier != nil) break;
            if (@available(iOS 13.0, *)) {
                label.layer.filters = nil;
                label.textColor = [ThemeManager textColor];
            } else {
                // Fallback on earlier versions
            }
        }
        [self updateThemeForLabels:subview];
    }
}

- (void)updateThemeForSelectors:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UISegmentedControl class]]) {
            UISegmentedControl *selector = (UISegmentedControl *)subview;
            if (@available(iOS 13.0, *)) {
                selector.selectedSegmentTintColor = [ThemeManager appSecondaryColor];
            } else {
                // Fallback on earlier versions
            }
        }
        [self updateThemeForSelectors:subview];
    }
}

- (void)updateThemeForSliders:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UISlider class]]) {
            UISlider *slider = (UISlider *)subview;
            slider.tintColor = [ThemeManager appSecondaryColor];

        }
        [self updateThemeForSliders:subview];
    }
}


- (void)updateTheme{
    self.view.backgroundColor = [ThemeManager appBackgroundColor];
    if (@available(iOS 13.0, *)) {
        [self updateThemeForLabels:self.view];
        [self updateThemeForSelectors:self.view];
        [self updateThemeForSliders:self.view];
    }
}

- (void) saveSettings {
    DataManager* dataMan = [[DataManager alloc] init];
    Settings* currentSettings = [dataMan retrieveSettings];
    
    NSInteger height = self.mainFrameViewController.settingsExpandedInStreamView ? currentSettings.height.intValue : [self getChosenStreamHeight];
    NSInteger width = self.mainFrameViewController.settingsExpandedInStreamView ? currentSettings.width.intValue : [self getChosenStreamWidth];
    
    NSInteger framerate = [self getChosenFrameRate];

    NSInteger audioConfig = [@[@2, @6, @8][[self.audioConfigSelector selectedSegmentIndex]] integerValue];
    NSInteger onscreenControls = [self.onScreenWidgetSelector selectedSegmentIndex];
    NSInteger keyboardToggleFingers = self.softKeyboardGestureSelector.selectedSegmentIndex == 3 ? 20 : self.softKeyboardGestureSelector.selectedSegmentIndex+3;
    NSInteger oscLayoutToolFingers = (uint16_t)self->oswLayoutFingers;

    CGFloat slideToSettingsDistance = self.slideToMenuDistanceSlider.value;
    uint32_t slideToSettingsScreenEdge = [self getScreenEdgeFromSelector];
    CGFloat pointerVelocityModeDivider = (CGFloat)(uint8_t)self.pointerVelocityModeDividerSlider.value/100;
    CGFloat touchPointerVelocityFactor = (CGFloat)(uint16_t)[self map_velocFactorDisplay_fromSliderValue:self.touchPointerVelocityFactorSlider.value]/100;
    CGFloat mousePointerVelocityFactor = (CGFloat)(uint16_t)[self map_velocFactorDisplay_fromSliderValue:self.mousePointerVelocityFactorSlider.value]/100;
    CGFloat gyroSensitivity = (CGFloat)(uint16_t)self.gyroSensitivitySlider.value/100;

    uint16_t touchMoveEventInterval = (uint16_t)self.touchMoveEventIntervalSlider.value;

    BOOL reverseMouseWheelDirection = [self.reverseMouseWheelDirectionSelector selectedSegmentIndex] == 1;
    NSInteger asyncNativeTouchPriority = 1;
    //BOOL liftStreamViewForKeyboard = [self.liftStreamViewForKeyboardSelector selectedSegmentIndex] == 1;
    BOOL liftStreamViewForKeyboard = YES; // enable and hide this option
    BOOL showKeyboardToolbar = self.softKeyboardToolbarSwitch.isOn;
    BOOL optimizeGames = self.optimizeGamesSwitch.isOn;
    BOOL multiController = self.multiControllerSwitch.isOn;
    BOOL swapABXYButtons = self.swapAbxySwitch.isOn;
    NSInteger gyroMode = self.gyroModeSelector.selectedSegmentIndex;
    NSInteger emulatedControllerType = [self segmentIndexToControllerType:self.emulatedControllerTypeSelector.selectedSegmentIndex]; //self.emulatedControllerTypeSelector.selectedSegmentIndex;
    BOOL audioOnPC = self.audioOnPcSwitch.isOn;
    uint32_t preferredCodec = [self getChosenCodecPreference];
    BOOL enableYUV444 = self.yuv444Switch.isOn;
    BOOL enablePIP = self.pipSwitch.isOn;
    BOOL btMouseSupport = self.citrixX1MouseSwitch.isOn;
    BOOL useFramePacing = [self.framePacingSelector selectedSegmentIndex] == 1;
    NSInteger touchMode = [self isNotNativeTouchOnly] ? self.touchModeSelector.selectedSegmentIndex : NativeTouchOnly;
    NSInteger statsOverlayLevel = [self.statsOverlaySelector selectedSegmentIndex];
    BOOL statsOverlayEnabled = statsOverlayLevel != 0;
    BOOL enableHdr = self.hdrSwitch.isOn;
    BOOL unlockDisplayOrientation = [self.unlockDisplayOrientationSelector selectedSegmentIndex] == 1;
    NSInteger resolutionSelected = [self.resolutionSelector selectedSegmentIndex];
    if (self.customResolutionSwitch.isOn) {
        resolutionSelected = RESOLUTION_TABLE_CUSTOM_INDEX;
    }
    NSInteger externalDisplayMode = [self.externalDisplayModeSelector selectedSegmentIndex];
    NSInteger localMousePointerMode = [self.localMousePointerModeSelector selectedSegmentIndex];
    NSInteger backgroundSessionTimer = self.backgroundSessionTimerSlider.value == self.backgroundSessionTimerSlider.maximumValue ? (uint32_t) INT16_MAX : (uint32_t)self.backgroundSessionTimerSlider.value;
    
    [dataMan saveSettingsWithBitrate:_bitrate
                           framerate:framerate
                              height:height
                               width:width
                         audioConfig:audioConfig
                    onscreenControls:onscreenControls
                            gyroMode:gyroMode
              emulatedControllerType:emulatedControllerType
               keyboardToggleFingers:keyboardToggleFingers
                oscLayoutToolFingers:oscLayoutToolFingers
           slideToSettingsScreenEdge:slideToSettingsScreenEdge
             slideToSettingsDistance:slideToSettingsDistance
          pointerVelocityModeDivider:pointerVelocityModeDivider
          touchPointerVelocityFactor:touchPointerVelocityFactor
          mousePointerVelocityFactor:mousePointerVelocityFactor
                     gyroSensitivity:gyroSensitivity
              touchMoveEventInterval:touchMoveEventInterval
          reverseMouseWheelDirection:reverseMouseWheelDirection
            asyncNativeTouchPriority:asyncNativeTouchPriority
           liftStreamViewForKeyboard:liftStreamViewForKeyboard
                 showKeyboardToolbar:showKeyboardToolbar
                       optimizeGames:optimizeGames
                     multiController:multiController
                     swapABXYButtons:swapABXYButtons
                           audioOnPC:audioOnPC
                      preferredCodec:preferredCodec
                        enableYUV444:enableYUV444
                           enablePIP:enablePIP
                      useFramePacing:useFramePacing
                           enableHdr:enableHdr
                      btMouseSupport:btMouseSupport
                           touchMode:touchMode
                   statsOverlayLevel:statsOverlayLevel
                 statsOverlayEnabled:statsOverlayEnabled
            unlockDisplayOrientation:unlockDisplayOrientation
                  resolutionSelected:resolutionSelected
                 externalDisplayMode:externalDisplayMode
               localMousePointerMode:localMousePointerMode
              backgroundSessionTimer:backgroundSessionTimer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}

@end
