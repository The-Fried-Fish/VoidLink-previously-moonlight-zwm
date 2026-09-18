//
//  SettingsViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "SettingsViewController.h"
#import "MainFrameViewController.h"
#if !TARGET_OS_TV
#import "CustomEdgeSlideGestureRecognizer.h"
#endif
#import "TemporarySettings.h"
#import "DataManager.h"
#import "VoidLink-Swift.h"
#import "Connection.h"
#import "Plot.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

#import "LocalizationHelper.h"

#if TARGET_OS_TV
#endif


#if TARGET_OS_TV

@interface SettingsViewController () <UIScrollViewDelegate>
@property(nonatomic, assign) SettingsMenuMode currentSettingsMenuMode;
@end

# else
@interface SettingsViewController () <MenuSectionDelegate, WidgetPickerViewControllerDelegate, UIScrollViewDelegate>
@property(nonatomic, assign) SettingsMenuMode currentSettingsMenuMode;
@end

#endif

@implementation SettingsViewController {
    TemporarySettings* tempSettings;
    DataManager* dataMan;
    OSCProfilesManager* oscProfileMan;
    OSCProfile* oscProfile;
    
    NSLayoutConstraint *parentStackLeadingConstraint;
    NSLayoutConstraint *parentStackWidthConstraint;
    NSLayoutConstraint *parentStackCenterXConstraint;

    NSInteger _bitrate;
    NSInteger _lastSelectedResolutionIndex;
    CGFloat softKeyboardHeight;
    bool settingsViewJustLoaded;
    bool settingsViewJustExpanded;
    bool settingsViewAlreadyAppeared;
    uint16_t oswLayoutFingers;
#if !TARGET_OS_TV
    CustomEdgeSlideGestureRecognizer *slideToCloseSettingsViewRecognizer;
#endif
    NSMutableDictionary *_settingStackDict;
    NSMutableArray *_favoriteSettingStackIdentifiers;
    bool settingStackWillBeRelocatedToLowestPosition;
    UIView *snapshot;
    UIStackView* capturedStack;
    CADisplayLink *_autoScrollDisplayLink;
    CGFloat _scrollSpeed;
    CGFloat _currentRefreshRate;
    MenuSectionView *touchControlSection;
    MenuSectionView *controllerSection;
    MenuSectionView *motionControlSection;
    MenuSectionView *videoSection;
    MenuSectionView *otherSection;
    MenuSectionView *experimentalSection;
    NSMutableSet* hiddenStacks;

    // ControllerNavigator UI navigation state
    UIView *_controllerNavigationHighlightOverlayView;
        
    GCController *capturedController;
}

@dynamic overrideUserInterfaceStyle;
@synthesize controllerNavigationHighlightOverlayView = _controllerNavigationHighlightOverlayView;

- (void)viewDidLoad {
    self->dataMan = [[DataManager alloc] init];
    self->tempSettings = [self->dataMan getSettings];
    self.currentSettingsMenuMode = self->tempSettings.settingsMenuMode.intValue;

    if (@available(iOS 14.0, tvOS 14.0, *)) {
#if !TARGET_OS_TV
        self->slideToCloseSettingsViewRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(edgeSwiped)];
        self->slideToCloseSettingsViewRecognizer.edges = UIRectEdgeLeft;
        self->slideToCloseSettingsViewRecognizer.normalizedThresholdDistance = 0.0;
        self->slideToCloseSettingsViewRecognizer.edgeTolerance = 10;
        self->slideToCloseSettingsViewRecognizer.immediateTriggering = true;
        self->slideToCloseSettingsViewRecognizer.delaysTouchesBegan = NO;
        self->slideToCloseSettingsViewRecognizer.delaysTouchesEnded = NO;
        [self.view addGestureRecognizer:self->slideToCloseSettingsViewRecognizer];
#else
        self.restoresFocusAfterTransition = false;
#endif
        [self installSwiftUISettingsIfNeeded];
        return;
    }
    
#if !TARGET_OS_TV
    [self restoreCoreDataSettingsForUIKitMenu:tempSettings];
#endif
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:NO];

    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(updateTheme)
                                                         name:ThemeManager.ThemeDidChangeNotification
                                                       object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(reloadSwiftUISettings)
                                                         name:@"GameProfileSelectorCloseNotification"
                                                       object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(reloadSwiftUISettings)
                                                         name:@"GameProfileSelectedNotification"
                                                       object:nil];
            [self reloadSwiftUISettings];
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self viewWillAppearUIKit];
#endif
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:NO];

    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            [self refreshSectionHitTesting];
            if (@available(iOS 13.0, *)) if(ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self viewDidAppearUIKit];
#endif
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsViewClosedNotification" object:self]; // notify other view that settings view just closed

    if (@available(iOS 14.0, *)) if (self.usesSwiftUISettings) {
        [self applySwiftUIClosingEffects];
        return;
    }
    
#if !TARGET_OS_TV
    [self viewDidDisappearUIKit];
#endif
}

- (SettingsMenuMode)getSettingsMenuMode{
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            return (SettingsMenuMode)[self swiftUISettingsMenuModeRawValue];
        }
    }
    return self.currentSettingsMenuMode;
}

- (void)initParentStack{
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    self.scrollView.delegate = self;
    // 可选：确保 scrollView 开启垂直滚动
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;

    _parentStack = [[UIStackView alloc] init];
    _parentStack.axis = UILayoutConstraintAxisVertical;
    _parentStack.spacing = 0;
    _parentStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    if(!_parentStack.superview){
        [self.scrollView addSubview:_parentStack];
        [NSLayoutConstraint activateConstraints:@[
            [_parentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant: self.currentSettingsMenuMode == AllSettings ? GenericUtils.settingsMenuNavigationBarHeight : GenericUtils.settingsMenuNavigationBarHeight+10],
            [_parentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-20],
        ]];
    }
    
#if !TARGET_OS_TV
    [self updateParentStackHorizontalConstraints];
#endif
}

- (void)switchToFavoriteSettings{
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            self.currentSettingsMenuMode = FavoriteSettings;
            [self setSwiftUISettingsMenuMode:FavoriteSettings];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];
                [GamepadNavigationIllustrationHud updateHudWithForceDisplay:false];
                if (ControllerUtil.primaryGCController) [ControllerNavigator restoreSettingsModeSwitchHighlight];
            });
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self switchToFavoriteSettingsUIKit];
#endif
}

- (void)switchToAllSettings{
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            self.currentSettingsMenuMode = AllSettings;
            [self setSwiftUISettingsMenuMode:AllSettings];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];
                [GamepadNavigationIllustrationHud updateHudWithForceDisplay:false];
                if (ControllerUtil.primaryGCController) [ControllerNavigator restoreSettingsModeSwitchHighlight];
            });
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self switchToAllSettingsUIKit];
#endif
}


- (void)expandGamepadSection {
    if(_currentSettingsMenuMode == FavoriteSettings) [self switchToAllSettings];
    
#if !TARGET_OS_TV
    [controllerSection setExpanded:true];
#endif
}

- (void)enterRemoveSettingItemMode{
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            self.currentSettingsMenuMode = RemoveSettingItem;
            [self setSwiftUISettingsMenuMode:RemoveSettingItem];
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self enterRemoveSettingItemModeUIKit];
#endif
}

- (void)doneRemoveSettingItem{
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            self.currentSettingsMenuMode = FavoriteSettings;
            [self setSwiftUISettingsMenuMode:FavoriteSettings];
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self doneRemoveSettingItemUIKit];
#endif
}


- (void)mainFrameGameProfileButtonTapped:(bool)animated{
    self.definesPresentationContext = NO;

    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            [self persistSwiftUIGameProfileSettings];
        }
#if !TARGET_OS_TV
        else [self saveGameProfileConfigsUIKit];
#endif
    }
#if !TARGET_OS_TV
    else [self saveGameProfileConfigsUIKit];

    self.layoutOnScreenControlsVC = [self instantiateOscLayoutViewController];
    if (self.layoutOnScreenControlsVC == nil) {
        return;
    }

    // self.layoutOnScreenControlsVC.view.backgroundColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    
    self.layoutOnScreenControlsVC.view.backgroundColor = UIColor.clearColor;
    self.layoutOnScreenControlsVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    self.layoutOnScreenControlsVC.profileSelectorLoadingMode = ProfileSelectorLoadingModeSelectProfileFromMainFrame;
    [self presentViewController:self.layoutOnScreenControlsVC animated:NO completion:^{
        [self->_layoutOnScreenControlsVC presentProfileSelectorWith:ProfileSelectorLoadingModeSelectProfileFromMainFrame animated:animated];
    }];
    self->_layoutOnScreenControlsVC.toolbarStackView.hidden = true;
    self->_layoutOnScreenControlsVC.toolbarRootView.hidden = true;
#else
    ProfileSelectorViewController *profileSelectorVC = [[ProfileSelectorViewController alloc] init];
    profileSelectorVC.loadingMode = ProfileSelectorLoadingModeSelectProfileFromMainFrame;
    profileSelectorVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    [self presentViewController:profileSelectorVC animated:animated completion:nil];
#endif
}

#if !TARGET_OS_TV

- (void)edgeSwiped {
    [self.mainFrameViewController closeSettingViewAnimated:YES];
}


-(void)deviceOrientationDidChange:(NSNotification *)notification {
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            // [self refreshSwiftUISettingsGeometry];
            return;
        }
    }
    
    [self updateParentStackHorizontalConstraints];
}

- (LayoutOnScreenControlsViewController *)instantiateOscLayoutViewController {
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    NSString *storyboardName = isIPhone ? @"iPhone" : @"iPad";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];

    NSLog(@"[OSC] storyboard=%@ instantiated class=%@", storyboardName, NSStringFromClass([viewController class]));
    
    if (![viewController isKindOfClass:[LayoutOnScreenControlsViewController class]]) {
        NSAssert(NO, @"Expected LayoutOnScreenControlsViewController, got %@", NSStringFromClass([viewController class]));
        return nil;
    }

    LayoutOnScreenControlsViewController *layoutViewController = (LayoutOnScreenControlsViewController *)viewController;
    if (!isIPhone) {
        // layoutViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    
    layoutViewController.toolbarStackView.hidden = false;
    layoutViewController.toolbarRootView.hidden = false;

    return layoutViewController;
}

- (void)updateParentStackHorizontalConstraints{
    if(!PublicUtils.isIPhone){
        if(parentStackCenterXConstraint && parentStackWidthConstraint) [NSLayoutConstraint deactivateConstraints:@[parentStackCenterXConstraint, parentStackWidthConstraint]];
        parentStackCenterXConstraint = [_parentStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant: 0]; //mark: settingMenuLayout
        parentStackWidthConstraint = [_parentStack.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-20]; // section width adjusted here
        [NSLayoutConstraint activateConstraints:@[parentStackCenterXConstraint, parentStackWidthConstraint]];
        return;
    }
    
    UIWindow *keyWindow = [UIApplication sharedApplication].windows.firstObject;
    
    if (@available(iOS 13.0, *)) {
        if(parentStackWidthConstraint && parentStackLeadingConstraint) [NSLayoutConstraint deactivateConstraints:@[parentStackLeadingConstraint, parentStackWidthConstraint]];
        
        UIWindowScene *activeScene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
        UIInterfaceOrientation currentOrientation;
        if (activeScene.activationState == UISceneActivationStateForegroundActive) {
            currentOrientation = activeScene.interfaceOrientation;
        }
        else currentOrientation = keyWindow.windowScene.interfaceOrientation;
        
        if(parentStackLeadingConstraint && parentStackWidthConstraint) [NSLayoutConstraint deactivateConstraints:@[parentStackLeadingConstraint, parentStackWidthConstraint]];
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

// This view is rooted at a ScrollView. To make it scrollable,
// we'll update content size here.

-(void)viewDidLayoutSubviews {
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            [self refreshSwiftUISettings];
            return;
        }
    }
    
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
    self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, _parentStack.frame.size.height + GenericUtils.settingsMenuNavigationBarHeight + 20);
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

// this will also be called back when device orientation changes
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            [self stopSwiftUISettingsScrollViewImmediately];
            [coordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
                [self refreshSwiftUISettingsGeometry];
            }];
            return;
        }
    }
    
    double delayInSeconds = 0.7;
    // Convert the delay into a dispatch_time_t value
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    // Perform some task after the delay
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{// Code to execute after the delay
        [self updateResolutionTable];
    });
}

- (void)invokeOscLayout{
    // init CustomOSC stuff
    /* sets a reference to the correct 'LayoutOnScreenControlsViewController' depending on whether the user is on an iPhone or iPad */
    // self.layoutOnScreenControlsVC = [[LayoutOnScreenControlsViewController alloc] init];
    self.layoutOnScreenControlsVC = [self instantiateOscLayoutViewController];
    if (self.layoutOnScreenControlsVC == nil) {
        return;
    }

    self.layoutOnScreenControlsVC.view.backgroundColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    self.layoutOnScreenControlsVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:self.layoutOnScreenControlsVC animated:YES completion:nil];
}

#else

- (BOOL)canBecomeFocused {
    return NO;
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    NSLog(@"shouldUpdateFocusInContext .........");
    return context.nextFocusedItem == nil ||
        [NSStringFromClass([context.nextFocusedItem class]) containsString:@"VoidLinkFocusSinkView"];
}

#endif

- (void)layoutSettingsView{
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
            [self refreshSectionHitTesting];
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self.scrollView layoutSubviews];
    
    //switchToAll/Favorite 调用此方法时，这些hiddenStack已身处新的superView中， 可以正常执行hidden = YES
    for(UIStackView* stack in hiddenStacks) stack.hidden = YES;

    if(self.currentSettingsMenuMode == AllSettings){
        for(MenuSectionView* section in _parentStack.arrangedSubviews) [section updateViewForFoldState];
    }
    [self hideDynamicLabelsWhenOverlapped:self.parentStack];
#endif
}

// UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (GenericUtils.autoPopSoftKeyboard) {
        return YES;
    } else {
        GenericUtils.autoPopSoftKeyboard = YES;
        return NO;
    }
}

- (void)updateTheme{
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            self.view.backgroundColor = ThemeManager.menuBackgroundColor;
            [self refreshSwiftUISettingsTheme];
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self updateUIKitMenuTheme];
#endif
}

- (void) saveSettings {
    if (@available(iOS 14.0, *)) {
        if (self.usesSwiftUISettings) {
            [self persistSwiftUISettings];
            return;
        }
    }
    
#if !TARGET_OS_TV
    [self saveUIKitMenuSettings];
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




#pragma mark UIKit-only codes

#if !TARGET_OS_TV

- (void)viewWillAppearUIKit {
    settingsViewJustExpanded = true;

    // Ensure codec-dependent switches are in correct state when view appears
    // [self updateCodecDependentSwitches];

    /*
    [self checkAndRequestMicPermission];
    self.micHandler = [MicHandler new];
    [self.micHandler startTapping];
    */

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:) // handle orientation change since i made portrait mode available
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTheme)
                                                 name:ThemeManager.ThemeDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadGameProfileConfigsUIKit)
                                                 name:@"GameProfileSelectorCloseNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadGameProfileConfigsUIKit)
                                                 name:@"GameProfileSelectedNotification"
                                               object:nil];
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pencilProPurchaseAborted:)
                                                 name:@"PencilProPurchaseAbortedNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pencilProPurchaseSucceeded:)
                                                 name:@"PencilProPurchaseSucceededNotification"
                                               object:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if(self.mainFrameViewController.settingsExpandedInStreamView){
            NSInteger responseCode = [self.mainFrameViewController requestForBitrate:self->_bitrate];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self widget:self.bitrateSlider setEnabled:responseCode == 200];
            });
        }
        else dispatch_async(dispatch_get_main_queue(), ^{[self widget:self.bitrateSlider setEnabled:true];});
    });
    
    if(self.currentSettingsMenuMode == AllSettings && MenuSectionView.overridePersistedFoldState){
        for(UIView *subview in _parentStack.arrangedSubviews){
            if([subview isKindOfClass:[MenuSectionView class]]){
                MenuSectionView* section = (MenuSectionView* )subview;
                [section setExpanded:YES];
            }
        }
    }
    
    if(![self manuallyChangedFPS]) [self framerateChanged];
    
    /*
    // self->motionControlSection.expandable = [self isCustomOswEnabled];
    self->motionControlSection.expandable = true;
    // [self->motionControlSection setExpanded:self->motionControlSection.expandable];
    __weak typeof(self) weakSelf = self;
    self->motionControlSection.lockedSectionHandler = ^{
        [AlertControllerUtil showAlertIn:weakSelf
                                        title:[LocalizationHelper localizedStringForKey:@"Tips"]
                                      message:[LocalizationHelper localizedStringForKey:@"Tap 'OK' to set on-screen widget to 'Custom' and enable motion control."]
                                   withCancel:YES
                                  buttonTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                    countdown:0
                                       action:^{}
                                   completion:^{
            if(!AlertControllerUtil.actionCancelled){
                weakSelf.onScreenWidgetSelector.selectedSegmentIndex = OnScreenControlsLevelCustom;
                if(weakSelf.touchModeSelector1.selectedSegmentIndex == NativeTouch){
                    [weakSelf.enableOswForNativeTouchSwitch setOn:true];
                    [weakSelf enableOswForNativeTouchSwitchFlipped:weakSelf.enableOswForNativeTouchSwitch];
                }
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf->motionControlSection.expandable = true;
                [strongSelf->motionControlSection setExpanded:YES];
            }
        }];
    };
    */
    
    [self reloadGameProfileConfigsUIKit];
    
    self->tempSettings = [self->dataMan getSettings];
    
    if(!settingsViewAlreadyAppeared){
        _scrollView.contentOffset = CGPointMake(_scrollView.contentOffset.x, tempSettings.settingsMenuOffset.floatValue);
        _scrollView.hidden = true;
    }
}

- (void)viewDidAppearUIKit {
    [self updateParentStackHorizontalConstraints];
    
    [self updateResolutionTable];
    
    [self.customResolutionSwitch addTarget:self action:@selector(customResolutionSwitched:) forControlEvents:UIControlEventValueChanged];
    [self.customResolutionSwitch setOn: isCustomResolution(self->tempSettings.resolutionSelected.intValue)];
    [self.resolutionSelector setEnabled:!self.customResolutionSwitch.isOn];
    
    [self touchModeChanged:self.touchModeSelector1]; // a special fix for iOS 14 to set hidden for the "enableOswStack"
    
    if(!settingsViewAlreadyAppeared) {
        if(![self contentOffsetRestored]) _scrollView.contentOffset = CGPointMake(_scrollView.contentOffset.x, tempSettings.settingsMenuOffset.floatValue);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view layoutIfNeeded];
            [self updateResolutionTable];
            [self updateInterpolationLevelSliderWithMaximumDimension:self->tempSettings.interpolationMaximumDimension.integerValue];
            [self.streamDimensionScaleSlider sendActionsForControlEvents:UIControlEventValueChanged];
        });
    }
    if(@available(iOS 13.0, *)) if(ControllerUtil.primaryGCController) [self restoreControllerNavigationHighlight];
    
    _scrollView.hidden = false;
    
    settingsViewJustExpanded = false;
    settingsViewAlreadyAppeared = true;
    
    if (@available(iOS 13.0, *)) if(ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];

}

- (void)viewDidDisappearUIKit{
    bool unlockDisplayOrientationFlipped = tempSettings.unlockDisplayOrientation != (_unlockDisplayOrientationSelector.selectedSegmentIndex == 1);
    if(unlockDisplayOrientationFlipped) [_mainFrameViewController setNeedsUpdateAllowedOrientation]; // handle allow portratit on & off
    if (@available(iOS 13.0, *)) if(ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];
    
    if(self.framePacingModeSelector.selectedSegmentIndex == FramePacingModeInterpolation) {
        [VideoDecoderRenderer startOrRestartFrameInterpolation];
    }
    else {
        [VideoDecoderRenderer stopFrameInterpolation];
    }
}

- (void)switchToFavoriteSettingsUIKit {
    [self forceRestoreHeightTemporarilyForSettingStackParentView];
    [_parentStack removeFromSuperview];
    self.currentSettingsMenuMode = FavoriteSettings;
    [self initParentStack];
    [self updateTheme];
    Settings *currentSettings = [dataMan retrieveSettings];
    currentSettings.settingsMenuMode = [NSNumber numberWithInteger:self.currentSettingsMenuMode];
    [dataMan saveData];
    
    _parentStack.spacing = PublicUtils.isIPhone ? 10 : 12;
    
    [self loadFavoriteSettingStackIdentifiers];
    for(NSString* settingIdentifier in _favoriteSettingStackIdentifiers){
        [_parentStack addArrangedSubview:_settingStackDict[settingIdentifier]];
    }
    // hidden Stacks that does not belong to favorite stacks shall also be added secretely to avoid stack restoring bug
    for(UIStackView* stack in hiddenStacks){
        if(![_favoriteSettingStackIdentifiers containsObject:stack.accessibilityIdentifier]){
            [_parentStack addArrangedSubview:stack];
            stack.hidden = YES;
        }
    }

    [self hideDynamicLabelsWhenOverlapped:self.parentStack];
    [self layoutSettingsView];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 13.0, *)) {
            if(ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];
            [GamepadNavigationIllustrationHud updateHudWithForceDisplay:false];
            if(ControllerUtil.primaryGCController){
                [ControllerNavigator restoreSettingsModeSwitchHighlight];
            };
        }
    });
}

- (void)switchToAllSettingsUIKit {
    [self forceRestoreHeightTemporarilyForSettingStackParentView];
    self.currentSettingsMenuMode = AllSettings;
    [_parentStack removeFromSuperview];
    [self initParentStack];
    [self layoutSections];
    // [self updateCodecDependentSwitches]; // Ensure switches are in correct state after layout
    [self updateTheme];
        //[self doneRemoveSettingItem];
    Settings *currentSettings = [dataMan retrieveSettings];
    currentSettings.settingsMenuMode = [NSNumber numberWithInteger:self.currentSettingsMenuMode];
    [dataMan saveData];
    [self layoutSettingsView];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 13.0, *)){
            if(ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];
            [GamepadNavigationIllustrationHud updateHudWithForceDisplay:false];
            if(ControllerUtil.primaryGCController){
                [ControllerNavigator restoreSettingsModeSwitchHighlight];
            };
        }
    });
}

- (void)enterRemoveSettingItemModeUIKit {
    self.currentSettingsMenuMode = RemoveSettingItem;
    for(UIStackView* stack in _parentStack.arrangedSubviews){
        for(UIView* view in stack.subviews){
            if([view.accessibilityIdentifier isEqualToString:@"infoButton"]) view.hidden = YES;
            // view.userInteractionEnabled = false;
        }
        [self attachRemoveButtonForStack:stack];
        // stack.userInteractionEnabled = false;
    }
}

- (void)doneRemoveSettingItemUIKit{
    self.currentSettingsMenuMode = FavoriteSettings;
    for(UIStackView* stack in _parentStack.arrangedSubviews){
        //stack.userInteractionEnabled = true;
        for(UIView* view in stack.subviews){
            //view.
            if([view.accessibilityIdentifier isEqualToString:@"infoButton"]) view.hidden = NO;
            if([view.accessibilityIdentifier isEqualToString:@"removeButton"]) [view removeFromSuperview];
        }
    }
}

- (void)saveUIKitMenuSettings {
    [self preSavingActions];

    Settings* currentSettings = [dataMan retrieveSettings];
    
    [self populatePencilSettings:currentSettings];
    
    CGFloat settingsMenuOffset = _rememberFoldStateSwitch.isOn ? _scrollView.contentOffset.y : 0;
    
    CMVideoDimensions dimensions;
    if (self.mainFrameViewController.isStreaming) {
        dimensions.width = (int32_t)currentSettings.width.intValue;
        dimensions.height = (int32_t)currentSettings.height.intValue;
    } else {
        dimensions = [self getChosenStreamDimensions];
    }
    NSInteger height = dimensions.height;
    NSInteger width = dimensions.width;
    
    NSLog(@"saveSettings %d, %ld, %ld",self.mainFrameViewController.isStreaming, width, height);
    
    NSInteger framerate = [self getChosenFrameRate];

    NSInteger audioConfig = [@[@2, @3, @6, @8][self.audioConfigSelector.selectedSegmentIndex] integerValue];
    // 2 - stereo (system)
    // 3 - stereo (SDL)
    // 6 - 5.1 (SDL)
    // 8 - 7.1 (SDL)

    NSInteger renderingBackend = self.renderingBackendSelector.selectedSegmentIndex;
    NSInteger framePacingMode = self.framePacingModeSelector.selectedSegmentIndex;
    InterpolationResolutionConfiguration *interpolationConfiguration =
        [self getCurrentInterpolationResolutionConfiguration];
    NSInteger interpolationMaximumDimension = interpolationConfiguration.maximumDimension;
    NSInteger interpolationMaximumPixelCount = interpolationConfiguration.maximumPixelCount;
    CGFloat streamDimensionScale = self.streamDimensionScaleSlider.value;
    NSInteger onscreenControls = self.onScreenWidgetSelector.selectedSegmentIndex;
    NSInteger keyboardToggleFingers = self.softKeyboardGestureSelector.selectedSegmentIndex == 3 ? 20 : self.softKeyboardGestureSelector.selectedSegmentIndex+3;
    NSInteger oscLayoutToolFingers = (uint16_t)self->oswLayoutFingers;

    CGFloat slideToSettingsDistance = self.slideToMenuDistanceSlider.value;
    uint32_t slideToSettingsScreenEdge = [self getScreenEdgeFromSelector];
    CGFloat pointerVelocityModeDivider = (CGFloat)(uint8_t)self.pointerVelocityModeDividerSlider.value/100;
    CGFloat touchPointerVelocityFactor = (CGFloat)(uint16_t)[self map_velocFactorDisplay_fromSliderValue:self.touchPointerVelocityFactorSlider.value]/100;
    CGFloat mousePointerVelocityFactor = (CGFloat)(uint16_t)[self map_velocFactorDisplay_fromSliderValue:self.mousePointerVelocityFactorSlider.value]/100;
    CGFloat gyroSensitivity = (CGFloat)(uint16_t)self.gyroSensitivitySlider.value/100;
    
    CGFloat localVolume = self.localVolumeSlider.value/100;
    CGFloat micVolume = self.micVolumeSlider.value/100;

    uint16_t touchMoveEventInterval = 0;

    BOOL reverseMouseWheelDirection = self.reverseMouseWheelDirectionSelector.selectedSegmentIndex == 1;
    NSInteger asyncNativeTouchPriority = 1;
    //BOOL liftStreamViewForKeyboard = self.liftStreamViewForKeyboardSelector.selectedSegmentIndex == 1;
    BOOL liftStreamViewForKeyboard = YES; // enable and hide this option
    BOOL showKeyboardToolbar = self.softKeyboardToolbarSwitch.isOn;
    BOOL optimizeGames = self.optimizeGamesSwitch.isOn;
    BOOL multiController = self.multiControllerSwitch.isOn;
    BOOL swapABXYButtons = self.swapAbxySwitch.isOn;
    BOOL buttonVisualFeedback = self.buttonVisualFeedbackSwitch.isOn;
    BOOL touchPointTracking = self.trackTouchPointSwitch.isOn;
    NSInteger gyroMode = self.gyroModeSelector.selectedSegmentIndex;
    NSInteger emulatedControllerType = [self segmentIndexToControllerType:self.emulatedControllerTypeSelector.selectedSegmentIndex]; //self.emulatedControllerTypeSelector.selectedSegmentIndex;
    BOOL audioOnPC = self.audioOnPcSwitch.isOn;
    BOOL redirectMic = self.redirectMicSwitch.isOn;
    BOOL useBuiltinMic = self.useBuiltinMicSwitch.isOn;
    uint32_t preferredCodec = [self getChosenCodecPreference];
    BOOL enableYUV444 = self.yuv444Switch.isOn;
    BOOL sdrPerformanceWorkaround = self.sdrPerformanceWorkaroundSwitch.isOn;
    BOOL enablePIP = self.pipSwitch.isOn;
    BOOL fullColorRange = self.fullColorRangeSwitch.isOn;
    BOOL btMouseSupport = self.citrixX1MouseSwitch.isOn;
    NSInteger touchMode = self.touchModeSelector1.selectedSegmentIndex;
    NSInteger statsOverlayLevel = self.statsOverlaySelector.selectedSegmentIndex;
    BOOL statsOverlayEnabled = statsOverlayLevel != 0;
    BOOL enableHdr = self.hdrSwitch.isOn;
    BOOL unlockDisplayOrientation = self.unlockDisplayOrientationSelector.selectedSegmentIndex == 1;
    BOOL enableGraphs = self.enableGraphsSwitch.isOn;
    int graphOpacity = (int)self.graphOpacityStepper.value;
    int frameQueueSize = (int)self.frameQueueSizeSlider.value;
    NSInteger resolutionSelected = self.resolutionSelector.selectedSegmentIndex;
    if (self.customResolutionSwitch.isOn) {
        resolutionSelected = RESOLUTION_TABLE_CUSTOM_INDEX;
    }
    NSInteger externalDisplayMode = self.externalDisplayModeSelector.selectedSegmentIndex;
    NSInteger localMousePointerMode = self.localMousePointerModeSelector.selectedSegmentIndex;
    BOOL sendDummyEvent = self.sendDummyEventSwitch.isOn;
    BOOL rememberFoldState = self.rememberFoldStateSwitch.isOn;
    CGFloat singleTapSensitivity = self.singleTapSensitivitySlider.value;
    NSInteger hapticEngine = self.hapticEngineSelector.selectedSegmentIndex;
    CGFloat edgeSlidingSensitivity = self.edgeSlidingSensitivitySlider.value;
    NSInteger audioEngine = self.audioEngineSelector.selectedSegmentIndex;
    BOOL delayLeftClick = self.delayLeftClickSwitch.isOn;
    // BOOL delayLeftClick = true;
    BOOL duckOtherApps = self.duckOtherAppSwitch.isOn;
    BOOL muteInBackground = self.muteInBackgroundSwitch.isOn;
    CGFloat relativeTouchSlideThreshold = self.relativeTouchSlideThresholdSlider.value;
    BOOL enablePinch = self.pinchGestureSwitch.isOn;
    CGFloat scrollSensitivity = self.scrollSensitivitySlider.value;
    CGFloat pinchSensitivity = self.pinchSensitivitySlider.value;
    BOOL ctrlDownForPinch = self.ctrlDownForPinchSwitch.isOn;
    CGFloat leftClickDelayMs = self.leftClickDelaySlider.value;
    BOOL passthroughGestures = self.passthroughGesturesSwitch.isOn;
    BOOL enableControllerNavigation = self.controllerNavigationSwitch.isOn;
    CGFloat controllerMousePointerVelocity = self.controllerMouseVelocitySlider.value;
    CGFloat controllerMouseExpo = self.controllerMouseExpoSlider.value;
    NSInteger controllerGyroSwitchMode = self.controllerGyroSwitchButtonSetter.selectedSegmentIndex;
    BOOL enableFrameTimebase = false;
    BOOL asyncFrameDequeue = self.asyncFrameDequeueSwitch.isOn;
    CGFloat softKeyboardHeight = self.softKeyboardHeightSwitch.isOn ? self->softKeyboardHeight : 0;
    BOOL globeAsEscape = self.globeAsEscapeSwitch.isOn;
    CGFloat streamingRadialMenuDelay = self.streamingRadialMenuDelaySlider.value;
    NSInteger backgroundSessionTimer = self.backgroundSessionTimerSlider.value == self.backgroundSessionTimerSlider.maximumValue ? (uint32_t) INT16_MAX : (uint32_t)self.backgroundSessionTimerSlider.value;

    [dataMan saveSettings:currentSettings
                         withBitrate:_bitrate
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
                         localVolume:localVolume
                           micVolume:micVolume
              touchMoveEventInterval:touchMoveEventInterval
          reverseMouseWheelDirection:reverseMouseWheelDirection
            asyncNativeTouchPriority:asyncNativeTouchPriority
           liftStreamViewForKeyboard:liftStreamViewForKeyboard
                 showKeyboardToolbar:showKeyboardToolbar
                       optimizeGames:optimizeGames
                     multiController:multiController
                buttonVisualFeedback:buttonVisualFeedback
                  touchPointTracking:touchPointTracking
                     swapABXYButtons:swapABXYButtons
                           audioOnPC:audioOnPC
                         redirectMic:redirectMic
                       useBuiltinMic:useBuiltinMic
                      preferredCodec:preferredCodec
                        enableYUV444:enableYUV444
                           enablePIP:enablePIP
                      fullColorRange:fullColorRange
                           enableHdr:enableHdr
                      btMouseSupport:btMouseSupport
                           touchMode:touchMode
                   statsOverlayLevel:statsOverlayLevel
                 statsOverlayEnabled:statsOverlayEnabled
            unlockDisplayOrientation:unlockDisplayOrientation
                  resolutionSelected:resolutionSelected
                 externalDisplayMode:externalDisplayMode
               localMousePointerMode:localMousePointerMode
                      frameQueueSize:frameQueueSize
                        enableGraphs:enableGraphs
                        graphOpacity:graphOpacity
                    renderingBackend:renderingBackend
                     framePacingMode:framePacingMode
       interpolationMaximumDimension:interpolationMaximumDimension
      interpolationMaximumPixelCount:interpolationMaximumPixelCount
                streamDimensionScale:streamDimensionScale
                      sendDummyEvent:sendDummyEvent
                   rememberFoldState:rememberFoldState
                  singleTapSensitivy:singleTapSensitivity
                        hapticEngine:hapticEngine
              edgeSlidingSensitivity:edgeSlidingSensitivity
                         audioEngine:audioEngine
                     delayLeftClick:delayLeftClick
                       duckOtherApps:duckOtherApps
                    muteInBackground:muteInBackground
         relativeTouchSlideThreshold:relativeTouchSlideThreshold
                         enablePinch:enablePinch
                   scrollSensitivity:scrollSensitivity
                    pinchSensitivity:pinchSensitivity
                    ctrlDownForPinch:ctrlDownForPinch
                    leftClickDelayMs:leftClickDelayMs
                  settingsMenuOffset:settingsMenuOffset
                 passthroughGestures:passthroughGestures
          enableControllerNavigation:enableControllerNavigation
      controllerMousePointerVelocity:controllerMousePointerVelocity
                 controllerMouseExpo:controllerMouseExpo
            controllerGyroSwitchMode:controllerGyroSwitchMode
                 enableFrameTimebase:enableFrameTimebase
                   asyncFrameDequeue:asyncFrameDequeue
            sdrPerformanceWorkaround:sdrPerformanceWorkaround
                  softKeyboardHeight:softKeyboardHeight
                      globeAsEscape:globeAsEscape
           streamingRadialMenuDelay:streamingRadialMenuDelay
              backgroundSessionTimer:backgroundSessionTimer];
    
    if(_bitrate >= 50000) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [GenericUtils handleFirstSettingHighBitrateIn:self handler:^{
                if(AlertControllerUtil.actionCancelled){
                    [PublicUtils openUrl:[LocalizationHelper localizedStringForKey:@"awdlTipLink"]];
                }
            }];
        });
    }

}

- (void)updateUIKitMenuTheme {
    self.view.backgroundColor = [UIColor clearColor];
    self.view.backgroundColor = ThemeManager.menuBackgroundColor;
    [self updateThemeForMenuSections:self.view];
    [self updateThemeForLabels:self.view];
    [self updateThemeForSelectors:self.view];
    [self updateThemeForSliders:self.view];
    if(PublicUtils.liquidGlassEnabled) [self updateThemeForSwitches:self.view];
}

- (MenuSectionView *)touchControlSection {
    return touchControlSection;
}

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
    520000,
    540000,
    560000,
    580000,
    600000,
    620000,
    640000,
    660000,
    680000,
    700000,
    720000,
    740000,
    760000,
    780000,
    800000,
    /*
    820000,
    840000,
    860000,
    880000,
    900000,
    920000,
    940000,
    960000,
    980000,
    1000000,*/
};

const int RESOLUTION_TABLE_SIZE = 6;
const int RESOLUTION_TABLE_CUSTOM_INDEX = RESOLUTION_TABLE_SIZE - 1;
CMVideoDimensions resolutionTable[RESOLUTION_TABLE_SIZE];

-(uint16_t)controllerTypeToSegmentIndex:(uint16_t)type{
    uint16_t index;
    switch (type) {
        case ControllerEmulationXbox:
            index = 0;
            break;
        case ControllerEmulationPs:
            index = 1;
            break;
        case ControllerEmulationPsEnhancedHaptic:
            index = 2;
            break;
        case ControllerEmulationXboxAndPs:
            index = 3;
            break;
        default:
            index = 3;
            break;
    }
    return index;
}

-(uint16_t)segmentIndexToControllerType:(uint16_t)index{
    uint16_t type;
    switch (index) {
        case 0:
            type = ControllerEmulationXbox;
            break;
        case 1:
            type = ControllerEmulationPs;
            break;
        case 2:
            type = ControllerEmulationPsEnhancedHaptic;
            break;
        case 3:
            type = ControllerEmulationXboxAndPs;
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
    return self.externalDisplayModeSelector.selectedSegmentIndex == ExternalDisplayModeExtended;
}

- (void)updateResolutionTable{
    if(self.mainFrameViewController.settingsExpandedInStreamView) return;

    NSInteger externalDisplayMode = self.externalDisplayModeSelector.selectedSegmentIndex;
    // 调用主界面方法统一填充 resolutionTable
    [self.mainFrameViewController fillResolutionTable:resolutionTable externalDisplayMode:externalDisplayMode];

    [self updateResolutionDisplayLabel];
}

- (void)checkAndRequestMicPermission{
    if(![MicHandler permissionGranted]) [MicHandler requestPermission:nil];
/*
    AVAudioSessionRecordPermission permission = [MicHandler permissionGranted];
    switch (permission) {
        case AVAudioSessionRecordPermissionGranted:
            NSLog(@"AVAudioSessionRecordPermissionGranted");
            break;
        case AVAudioSessionRecordPermissionDenied:
        default:
            [MicHandler requestPermission:nil];
            NSLog(@"AVAudioSessionRecordPermissionDenied");
    }*/
}

- (void)micHandlerDidFinishPlayback:(MicHandler *)handler {
    NSLog(@"Playback finished");
}

- (void)micHandler:(MicHandler *)handler didFailWithError:(NSError *)error {
    NSLog(@"Mic error: %@", error);
}

- (void)reloadGameProfileConfigsUIKit{
    oscProfile = [oscProfileMan getSelectedProfile];
    
    // this part will enable/disable oscSelector & the asyncNativeTouchPriority selector
    uint8_t touchModeSelectorIndex = oscProfile.touchMode == NativeTouchOnly ? NativeTouch : oscProfile.touchMode;
    self.touchModeSelector1.selectedSegmentIndex = touchModeSelectorIndex; //Load old touchMode setting
    [self touchModeChanged:self.touchModeSelector1];
    
    [self.touchModeSelector2 addTarget:self action:@selector(touchMode2Changed:) forControlEvents:UIControlEventValueChanged];
    self.touchModeSelector2.selectedSegmentIndex = self.touchModeSelector1.selectedSegmentIndex;
    
    // [self.enableOswForNativeTouchSwitch setOn:oscProfile.touchMode != NativeTouchOnly];
    // [self.enableOswForNativeTouchSwitch sendActionsForControlEvents:UIControlEventValueChanged];

    [self.pointerVelocityModeDividerSlider setValue: (uint8_t)(oscProfile.pointerVelocityModeDivider * 100) animated:NO]; // Load old setting.
    [self.pointerVelocityModeDividerSlider sendActionsForControlEvents:UIControlEventValueChanged]; // Load old setting.

    [self.touchPointerVelocityFactorSlider setValue: [self map_SliderValue_fromVelocFactor: oscProfile.touchPointerVelocityFactor] animated:NO]; // Load old setting.
    [self.touchPointerVelocityFactorSlider sendActionsForControlEvents:UIControlEventValueChanged]; // Load old setting.

    self.controllerGyroSwitchButtonSetter.selectedSegmentIndex = oscProfile.controllerGyroSwitchMode;
    if(self.controllerGyroSwitchButtonSetter.selectedSegmentIndex != ControllerGyroSwitchDisabled){
        bool bothButtonsSet = oscProfile.controllerGyroSwitchHold != ControllerElementNull && oscProfile.controllerGyroSwitchToggle != ControllerElementNull;
        [self findDynamicLabelFromStack:self.controllerGyroSwitchButtonStack].text = bothButtonsSet ? [LocalizationHelper localizedStringForKey:@" both set "] : @"";
    }
    [self setHidden:oscProfile.controllerGyroSwitchMode==ControllerGyroSwitchDisabled forStack:self.reverseHoldButtonStack];
    
    [self.reverseHoldButtonSwitch setOn:oscProfile.reverseGyroHoldButton];

    self.gyroSourceSelector.selectedSegmentIndex = oscProfile.useBuiltinGyro ? 0 : 1;
    [self.gyroSourceSelector sendActionsForControlEvents:UIControlEventValueChanged];
    
    [self.swapYawAndRollSwitch setOn:oscProfile.swapYawAndRoll];
    
    self.mapGyroToSelector.selectedSegmentIndex = oscProfile.mapGyroTo;
    [self.mapGyroToSelector sendActionsForControlEvents:UIControlEventValueChanged];

    [self.yawPitchToRightStickSwitch setOn:oscProfile.yawPitchToRightStick];
    [self.rollToLeftStickSwitch setOn:oscProfile.rollToLeftStick];
    
    if(self.mapGyroToSelector.selectedSegmentIndex == mapGyroToControllerStick){
        [self.yawPitchToRightStickSwitch sendActionsForControlEvents:UIControlEventValueChanged];
        [self.rollToLeftStickSwitch sendActionsForControlEvents:UIControlEventValueChanged];
    }
    
    [self.yawSensitivitySlider setValue:[self map_SliderValue_fromVelocFactor:oscProfile.gyroSensitivityYaw]];
    [self.yawSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];
     
    [self.pitchSensitivitySlider setValue:[self map_SliderValue_fromVelocFactor:oscProfile.gyroSensitivityPitch]];
    [self.pitchSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];

    [self.rollSensitivitySlider setValue:[self map_SliderValue_fromVelocFactor:oscProfile.gyroSensitivityRoll]];
    [self.rollSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];

    [self.gyroToStickMinOffsetSlider setValue:(uint16_t)oscProfile.gyroToStickMinOffset];
    [self.gyroToStickMinOffsetSlider sendActionsForControlEvents:UIControlEventValueChanged];

    [self.leftStickMinOffsetSlider setValue:(uint16_t)oscProfile.physicalLeftStickMinOffset];
    [self.leftStickMinOffsetSlider sendActionsForControlEvents:UIControlEventValueChanged];

    [self.rightStickMinOffsetSlider setValue:(uint16_t)oscProfile.physicalRightStickMinOffset];
    [self.rightStickMinOffsetSlider sendActionsForControlEvents:UIControlEventValueChanged];

    [self.synthPhysicalInputSwitch setOn:oscProfile.synthesizePhysicalStick];
    
    [self.dualSenseTransientSlider setValue:oscProfile.dualSenseTransient];
    [self.dualSenseTransientSlider sendActionsForControlEvents:UIControlEventValueChanged];
    
    [self.pressureCurveSwitch setOn:oscProfile.pressureCurveEnabled];
    [self.doubleTapShortcutSwitch setOn:oscProfile.doubleTapShorcutEnabled];
    [self.squeezeShortcutSwitch setOn:oscProfile.squeezeShorcutEnabled];
    [self.pencilPausesNativeTouchSwitch setOn:oscProfile.pencilPausesNativeTouch];
    [self.disablePencilSlideGestureSwitch setOn:oscProfile.disablePencilSlideGestures];
    self.pencilModeSelector.selectedSegmentIndex = oscProfile.pencilAndHoverMode;
}

- (void)saveGameProfileConfigsUIKit{
    
    CGFloat touchPointerVelocityFactorPercent = [self map_velocFactorDisplay_fromSliderValue:self.touchPointerVelocityFactorSlider.value];
    CGFloat yawSensitivityPercent = [self map_velocFactorDisplay_fromSliderValue:self.yawSensitivitySlider.value];
    CGFloat pitchSensitivityPercent = [self map_velocFactorDisplay_fromSliderValue:self.pitchSensitivitySlider.value];
    CGFloat rollSensitivityPercent = [self map_velocFactorDisplay_fromSliderValue:self.rollSensitivitySlider.value];
    TouchMode touchMode = self.touchModeSelector1.selectedSegmentIndex;
    bool leftStickMinOffsetSliderNotMoved = (int16_t)(oscProfile.physicalLeftStickMinOffset) == (int16_t)self.leftStickMinOffsetSlider.value;
    bool rightStickMinOffsetSliderNotMoved = (int16_t)(oscProfile.physicalRightStickMinOffset) == (int16_t)self.rightStickMinOffsetSlider.value;

    bool configNotChanged = (
                             (int)oscProfile.touchMode == touchMode
                             && (int16_t)(oscProfile.pointerVelocityModeDivider*100) == (int16_t)(self.pointerVelocityModeDividerSlider.value)
                             && (int16_t)(oscProfile.touchPointerVelocityFactor*100) == (int16_t)touchPointerVelocityFactorPercent
                             && oscProfile.useBuiltinGyro == self.gyroSourceSelector.selectedSegmentIndex == 0
                             && oscProfile.swapYawAndRoll == self.swapYawAndRollSwitch.isOn
                             && oscProfile.mapGyroTo == self.mapGyroToSelector.selectedSegmentIndex
                             && oscProfile.yawPitchToRightStick == self.yawPitchToRightStickSwitch.isOn
                             && oscProfile.rollToLeftStick == self.rollToLeftStickSwitch.isOn
                             && (int16_t)(oscProfile.pointerVelocityModeDivider*100) == (int16_t)self.pointerVelocityModeDividerSlider.value
                             && (int16_t)(oscProfile.touchPointerVelocityFactor*100) == (int16_t)touchPointerVelocityFactorPercent
                             && (int16_t)(oscProfile.gyroSensitivityYaw*100) == (int16_t)yawSensitivityPercent
                             && (int16_t)(oscProfile.gyroSensitivityPitch*100) == (int16_t)pitchSensitivityPercent
                             && (int16_t)(oscProfile.gyroSensitivityRoll*100) == (int16_t)rollSensitivityPercent
                             && (int16_t)(oscProfile.gyroToStickMinOffset) == (int16_t)self.gyroToStickMinOffsetSlider.value
                             && (int16_t)(oscProfile.dualSenseTransient*100) == (int16_t)(self.dualSenseTransientSlider.value*100)
                             && oscProfile.synthesizePhysicalStick == self.synthPhysicalInputSwitch.isOn
                             && oscProfile.controllerGyroSwitchMode == self.controllerGyroSwitchButtonSetter.selectedSegmentIndex
                             && oscProfile.reverseGyroHoldButton == self.reverseHoldButtonSwitch.isOn
                             && leftStickMinOffsetSliderNotMoved
                             && rightStickMinOffsetSliderNotMoved
                             && oscProfile.pressureCurveEnabled == self.pressureCurveSwitch.isOn
                             && oscProfile.doubleTapShorcutEnabled == self.doubleTapShortcutSwitch.isOn
                             && oscProfile.squeezeShorcutEnabled == self.squeezeShortcutSwitch.isOn
                             && oscProfile.pencilPausesNativeTouch == self.pencilPausesNativeTouchSwitch.isOn
                             && oscProfile.disablePencilSlideGestures == self.disablePencilSlideGestureSwitch.isOn
                             && oscProfile.pencilAndHoverMode == self.pencilModeSelector.selectedSegmentIndex
                             );

    if(!configNotChanged){
        oscProfile = [oscProfileMan getSelectedProfile];
        oscProfile.touchMode = (int)touchMode;
        oscProfile.pointerVelocityModeDivider = self.pointerVelocityModeDividerSlider.value/100;
        oscProfile.touchPointerVelocityFactor = touchPointerVelocityFactorPercent/100;
        oscProfile.useBuiltinGyro = self.gyroSourceSelector.selectedSegmentIndex == 0;
        oscProfile.swapYawAndRoll = self.swapYawAndRollSwitch.isOn;
        oscProfile.mapGyroTo = self.mapGyroToSelector.selectedSegmentIndex;
        oscProfile.yawPitchToRightStick = self.yawPitchToRightStickSwitch.isOn;
        oscProfile.rollToLeftStick = self.rollToLeftStickSwitch.isOn;
        oscProfile.gyroSensitivityYaw = yawSensitivityPercent/100;
        oscProfile.gyroSensitivityPitch = pitchSensitivityPercent/100;
        oscProfile.gyroSensitivityRoll = rollSensitivityPercent/100;
        oscProfile.gyroToStickMinOffset = (int16_t)self.gyroToStickMinOffsetSlider.value;
        oscProfile.dualSenseTransient = self.dualSenseTransientSlider.value;
        oscProfile.synthesizePhysicalStick = self.synthPhysicalInputSwitch.isOn;
        oscProfile.controllerGyroSwitchMode = (int)self.controllerGyroSwitchButtonSetter.selectedSegmentIndex;
        oscProfile.reverseGyroHoldButton = self.reverseHoldButtonSwitch.isOn;
        oscProfile.physicalLeftStickMinOffset = (int16_t)self.leftStickMinOffsetSlider.value;
        oscProfile.physicalRightStickMinOffset = (int16_t)self.rightStickMinOffsetSlider.value;
        oscProfile.pressureCurveEnabled = self.pressureCurveSwitch.isOn;
        oscProfile.doubleTapShorcutEnabled = self.doubleTapShortcutSwitch.isOn;
        oscProfile.squeezeShorcutEnabled = self.squeezeShortcutSwitch.isOn;
        oscProfile.pencilPausesNativeTouch = self.pencilPausesNativeTouchSwitch.isOn;
        oscProfile.disablePencilSlideGestures = self.disablePencilSlideGestureSwitch.isOn;
        oscProfile.pencilAndHoverMode = self.pencilModeSelector.selectedSegmentIndex;
        [oscProfileMan replaceSelectedProfileWith:oscProfile overwriteDefault:YES];
        if(PencilHandler.shared) [PencilHandler.shared setupPressureLUTWithProfile:oscProfile];
    }
    
    if(!leftStickMinOffsetSliderNotMoved || !rightStickMinOffsetSliderNotMoved || ControllerUtil.gamepadArrivalReported){
        if(OnScreenControls.shared){
            [OnScreenControls.shared clearLeftStickTouchPadFlag];
            [OnScreenControls.shared clearRightStickTouchPadFlag];
        }
        else LiSendControllerEvent(0, 0, 0, 0, 0, 0, 0);
    }
}

- (bool)contentOffsetRestored{
    return fabs(_scrollView.contentOffset.y - tempSettings.settingsMenuOffset.floatValue)<2;
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
    label.textColor = ThemeManager.appPrimaryColor;
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

- (void)addSetting:(UIStackView *)stack ofId:(NSString* )identifier to:(MenuSectionView* )menuSection{
    stack.accessibilityIdentifier = identifier;
    [_settingStackDict setObject:stack forKey:identifier];
    if(stack.hasInfoTag || stack.isGameProfileSetting) [self attachInfoTagForStack:stack];
    if(stack.hasDynamicLabel) [self addDynamicLabelForStack:stack];
    [menuSection addSubStackView:stack];
}
    
- (void)layoutSections {
    videoSection = [[MenuSectionView alloc] init];
    videoSection.delegate = self;
    videoSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Video"];
    videoSection.identifier = @"SettingsSectionVideo";
    if (@available(iOS 13.0, *)) {
        [videoSection setSectionWithIcon:[UIImage systemImageNamed:@"waveform"] size:13 sizeConstraint:-15];
    }

    [self addDynamicLabelForStack:self.resolutionSelectorStack];
    [self addSetting:self.resolutionStack ofId:@"resolutionStack" to:videoSection];

    [self addSetting:self.fpsStack ofId:@"fpsStack" to:videoSection];

    self.bitrateStack.hasInfoTag = YES;
    self.bitrateStack.hasDynamicLabel = YES;
    [self addSetting:self.bitrateStack ofId:@"bitrateStack" to:videoSection];

    [self addSetting:self.codecStack ofId:@"codecStack" to:videoSection];

    self.hdrStack.hasInfoTag = ![Utils hdrSupported];
    [self addSetting:self.hdrStack ofId:@"hdrStack" to:videoSection];

    self.yuv444Stack.hasInfoTag = YES;
    [self addSetting:self.yuv444Stack ofId:@"yuv444Stack" to:videoSection];

    // self.sdrPerformanceWorkaroundStack.hasInfoTag = YES;
    // [self addSetting:self.sdrPerformanceWorkaroundStack ofId:@"sdrPerformanceWorkaroundStack" to:videoSection];

    self.framePacingStack.hasInfoTag = YES;
    [self addSetting:self.framePacingStack ofId:@"framePacingStack" to:videoSection];
    if(!FrameInterpolator.deviceSupportsInterpolation) [self.framePacingModeSelector setEnabled:false forSegmentAtIndex:FramePacingModeInterpolation];

    self.interpolationLevelStack.hasDynamicLabel = YES;
    self.interpolationLevelStack.hasInfoTag = YES;
    [self addSetting:self.interpolationLevelStack ofId:@"interpolationLevelStack" to:videoSection];

    self.streamDimensionScaleStack.hasDynamicLabel = YES;
    self.streamDimensionScaleStack.hasInfoTag = YES;
    [self addSetting:self.streamDimensionScaleStack ofId:@"streamDimensionScaleStack" to:videoSection];

    self.frameQueueSizeStack.hasDynamicLabel = YES;
    [self addSetting:self.frameQueueSizeStack ofId:@"frameQueueSizeStack" to:videoSection];

    self.asyncFrameDequeueStack.hasInfoTag = YES;
    [self addSetting:self.asyncFrameDequeueStack ofId:@"asyncFrameDequeueStack" to:videoSection];

    self.pipStack.hasInfoTag = YES;
    [self addSetting:self.pipStack ofId:@"pipStack" to:videoSection];

    [videoSection addToParentStack:_parentStack];


    touchControlSection = [[MenuSectionView alloc] init];
    touchControlSection.delegate = self;
    touchControlSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Touch Control"];
    touchControlSection.identifier = @"SettingsSectionTouch&Controller";
    if (@available(iOS 13.0, *)) {
        [touchControlSection setSectionWithIcon:[UIImage imageNamed:@"arcade.stick.console"] size:22 sizeConstraint:-13];
    }

    self.touchModeStack.hasInfoTag = YES;
    self.touchModeStack.isGameProfileSetting = YES;
    [self addSetting:self.touchModeStack ofId:@"touchModeStack" to:touchControlSection];

    self.mousePointerVelocityStack.hasDynamicLabel = YES;
    // self.mousePointerVelocityStack.isGameProfileSetting = YES;
    [self addSetting:self.mousePointerVelocityStack ofId:@"mousePointerVelocityStack" to:touchControlSection];

    self.pointerVelocityDividerStack.hasInfoTag = YES;
    self.pointerVelocityDividerStack.isGameProfileSetting = YES;
    self.pointerVelocityDividerStack.hasDynamicLabel = YES;
    [self addSetting:self.pointerVelocityDividerStack ofId:@"pointerVelocityDividerStack" to:touchControlSection];

    self.pointerVelocityFactorStack.hasInfoTag = YES;
    self.pointerVelocityFactorStack.isGameProfileSetting = YES;
    self.pointerVelocityFactorStack.hasDynamicLabel = YES;
    [self addSetting:self.pointerVelocityFactorStack ofId:@"pointerVelocityFactorStack" to:touchControlSection];

    self.delayLeftClickStack.hasInfoTag = YES;
    [self addSetting:self.delayLeftClickStack ofId:@"delayLeftClickStack" to:touchControlSection];

    [self addSetting:self.passthroughGesturesStack ofId:@"passthroughGesturesStack" to:touchControlSection];
    [self addSetting:self.pinchGestureStack ofId:@"pinchGestureStack" to:touchControlSection];

    self.ctrlDownForPinchStack.hasInfoTag = YES;
    [self addSetting:self.ctrlDownForPinchStack ofId:@"ctrlDownForPinchStack" to:touchControlSection];

    self.scrollSensitivityStack.hasDynamicLabel = YES;
    [self addSetting:self.scrollSensitivityStack ofId:@"scrollSensitivityStack" to:touchControlSection];

    self.pinchSensitivityStack.hasDynamicLabel = YES;
    [self addSetting:self.pinchSensitivityStack ofId:@"pinchSensitivityStack" to:touchControlSection];

    self.onScreenWidgetStack.hasInfoTag = YES; // ?????
    [self addSetting:self.onScreenWidgetStack ofId:@"onScreenWidgetStack" to:touchControlSection];

    [self addSetting:self.buttonVisualFeedbackStack ofId:@"buttonVisualFeedbackStack" to:touchControlSection];
    [self addSetting:self.trackTouchPointStack ofId:@"trackTouchPointStack" to:touchControlSection];

    [touchControlSection addToParentStack:_parentStack];


    controllerSection = [[MenuSectionView alloc] init];
    controllerSection.delegate = self;
    controllerSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Controller"];
    controllerSection.identifier = @"SettingsSectionController";
    if (@available(iOS 13.0, *)) {
        [controllerSection setSectionWithIcon:[UIImage systemImageNamed:@"gamecontroller"] size:30 sizeConstraint:-10];
    }
    
    self.controllerNavigationStack.hasInfoTag = YES;
    self.controllerNavigationStack.hasDynamicLabel = YES;
    [self addSetting:self.controllerNavigationStack ofId:@"controllerNavigationStack" to:controllerSection];
    
    self.streamingRadialMenuDelayStack.hasDynamicLabel = YES;
    [self addSetting:self.streamingRadialMenuDelayStack ofId:@"streamingRadialMenuDelayStack" to:controllerSection];

    self.controllerMouseVelocityStack.hasDynamicLabel = YES;
    [self addSetting:self.controllerMouseVelocityStack ofId:@"controllerMouseVelocityStack" to:controllerSection];

    self.controllerMouseExpoStack.hasInfoTag = YES;
    self.controllerMouseExpoStack.hasDynamicLabel = YES;
    [self addSetting:self.controllerMouseExpoStack ofId:@"controllerMouseExpoStack" to:controllerSection];

    [self addSetting:self.swapAbxyStack ofId:@"swapAbaxyStack" to:controllerSection];
    [self addSetting:self.hapticEngineStack ofId:@"hapticEngineStack" to:controllerSection];

    self.emulatedControllerTypeStack.hasInfoTag = YES;
    // self.emulatedControllerTypeStack.isGameProfileSetting = YES;
    [self addSetting:self.emulatedControllerTypeStack ofId:@"emulatedControllerTypeStack" to:controllerSection];
    
    self.dualSenseTransientStack.hasInfoTag = YES;
    self.dualSenseTransientStack.isGameProfileSetting = YES;
    self.dualSenseTransientStack.hasDynamicLabel = YES;
    [self addSetting:self.dualSenseTransientStack ofId:@"dualSenseTransientStack" to:controllerSection];

    self.gyroModeStack.hasInfoTag = YES;
    // self.gyroModeStack.isGameProfileSetting = YES;
    self.gyroModeStack.hasDynamicLabel = YES;
    [self addSetting:self.gyroModeStack ofId:@"gyroModeStack" to:controllerSection];

    self.gyroSensitivityStack.hasDynamicLabel = YES;
    // self.gyroSensitivityStack.isGameProfileSetting = YES;
    [self addSetting:self.gyroSensitivityStack ofId:@"gyroSensitivityStack" to:controllerSection];

    self.leftStickMinOffsetStack.hasInfoTag = YES;
    self.leftStickMinOffsetStack.isGameProfileSetting = YES;
    self.leftStickMinOffsetStack.hasDynamicLabel = YES;
    [self addSetting:self.leftStickMinOffsetStack ofId:@"leftStickMinOffsetStack" to:controllerSection];

    self.rightStickMinOffsetStack.hasInfoTag = YES;
    self.rightStickMinOffsetStack.isGameProfileSetting = YES;
    self.rightStickMinOffsetStack.hasDynamicLabel = YES;
    [self addSetting:self.rightStickMinOffsetStack ofId:@"rightStickMinOffsetStack" to:controllerSection];

    [controllerSection addToParentStack:_parentStack];


    motionControlSection = [[MenuSectionView alloc] init];
    motionControlSection.delegate = self;
    motionControlSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Motion Control"];
    motionControlSection.identifier = @"SettingsSectionMotionControl";
    if (@available(iOS 13.0, *)) {
        [motionControlSection setSectionWithIcon:[UIImage imageNamed:@"gyroscope"] size:23 sizeConstraint:-18];
    }

    self.controllerGyroSwitchButtonStack.hasInfoTag = YES;
    self.controllerGyroSwitchButtonStack.isGameProfileSetting = YES;
    self.controllerGyroSwitchButtonStack.hasDynamicLabel = YES;
    [self addSetting:self.controllerGyroSwitchButtonStack ofId:@"controllerGyroSwitchButtonStack" to:motionControlSection];

    self.reverseHoldButtonStack.hasInfoTag = YES;
    self.reverseHoldButtonStack.isGameProfileSetting = YES;
    self.reverseHoldButtonStack.hasDynamicLabel = YES;
    [self addSetting:self.reverseHoldButtonStack ofId:@"reverseHoldButtonStack" to:motionControlSection];

    self.gyroSourceStack.isGameProfileSetting = YES;
    [self addSetting:self.gyroSourceStack ofId:@"gyroSourceStack" to:motionControlSection];

    self.swapYawAndRollStack.hasInfoTag = YES;
    self.swapYawAndRollStack.isGameProfileSetting = YES;
    [self addSetting:self.swapYawAndRollStack ofId:@"swapYawAndRollStack" to:motionControlSection];

    self.mapGyroToStack.hasInfoTag = YES;
    self.mapGyroToStack.isGameProfileSetting = YES;
    [self addSetting:self.mapGyroToStack ofId:@"mapGyroToStack" to:motionControlSection];

    // self.gyroToStickSwitchStack.isGameProfileSetting = YES;
    self.yawPitchToRightStickStack.isGameProfileSetting = YES;
    [self attachInfoTagForStack:self.yawPitchToRightStickStack];
    self.rollToLeftStickStack.isGameProfileSetting = YES;
    [self attachInfoTagForStack:self.rollToLeftStickStack];
    [self addSetting:self.gyroToStickSwitchStack ofId:@"gyroToStickStack" to:motionControlSection];

    self.yawSensitivityStack.isGameProfileSetting = YES;
    self.pitchSensitivityStack.isGameProfileSetting = YES;
    [self addSetting:self.yawPitchSensitivityStack ofId:@"yawPitchSensitivityStack" to:motionControlSection];
    [self attachInfoTagForStack:self.yawSensitivityStack];
    [self addDynamicLabelForStack:self.yawSensitivityStack];
    [self attachInfoTagForStack:self.pitchSensitivityStack];
    [self addDynamicLabelForStack:self.pitchSensitivityStack];

    self.rollSensitivityStack.isGameProfileSetting = YES;
    self.rollSensitivityStack.hasDynamicLabel = YES;
    [self addSetting:self.rollSensitivityStack ofId:@"rollSensitivityStack" to:motionControlSection];

    self.gyroToStickMinOffsetStack.isGameProfileSetting = YES;
    self.gyroToStickMinOffsetStack.hasDynamicLabel = YES;
    [self addSetting:self.gyroToStickMinOffsetStack ofId:@"gyroToStickMinOffsetStack" to:motionControlSection];

    self.synthPhysicalInputStack.isGameProfileSetting = YES;
    [self addSetting:self.synthPhysicalInputStack ofId:@"synthPhysicalInputStack" to:motionControlSection];

    [motionControlSection addToParentStack:_parentStack];


    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    bool loadPencilSection = ([bundleId isEqualToString:@"com.voidlink.iOS"]
                              || [bundleId isEqualToString:@"com.voidlinkextreme.iOS"]
                              || [bundleId isEqualToString:@"com.voidlink.tf.debug10.iOS"]);

    if ([PublicUtils isIPad] && loadPencilSection) {
        MenuSectionView *pencilSection = [[MenuSectionView alloc] init];
        pencilSection.delegate = self;
        pencilSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"=drawingToolkit"];
        pencilSection.identifier = @"SettingsSectionPencil";
        if (@available(iOS 13.0, *)) {
            [pencilSection setSectionWithIcon:[UIImage systemImageNamed:@"pencil.and.outline"] size:19 weight:UIImageSymbolWeightHeavy sizeConstraint:-16.5];
        }

        self.pencilTickStack.hasInfoTag = YES;
        [self addSetting:self.pencilTickStack ofId:@"pencilTickStack" to:pencilSection];

        self.pencilTickIntervalStack.hasDynamicLabel = YES;
        [self addSetting:self.pencilTickIntervalStack ofId:@"pencilTickIntervalStack" to:pencilSection];

        [self addSetting:self.pencilTipOffsetStack ofId:@"pencilTipOffsetStack" to:pencilSection];

        self.pressureCurveStack.isGameProfileSetting = YES;
        [self addSetting:self.pressureCurveStack ofId:@"pressureCurveStack" to:pencilSection];

        self.doubleTapShortcutStack.isGameProfileSetting = YES;
        self.doubleTapShortcutStack.hasInfoTag = YES;
        [self addSetting:self.doubleTapShortcutStack ofId:@"doubleTapShortcutStack" to:pencilSection];

        self.squeezeShortcutStack.isGameProfileSetting = YES;
        self.squeezeShortcutStack.hasInfoTag = YES;
        [self addSetting:self.squeezeShortcutStack ofId:@"squeezeShortcutStack" to:pencilSection];

        self.pencilModeStack.isGameProfileSetting = YES;
        self.pencilModeStack.hasInfoTag = YES;
        [self addSetting:self.pencilModeStack ofId:@"pencilModeStack" to:pencilSection];

        self.pencilPausesNativeTouchStack.isGameProfileSetting = YES;
        [self addSetting:self.pencilPausesNativeTouchStack ofId:@"pencilPausesNativeTouchStack" to:pencilSection];
        
        self.disablePencilSlideGestureStack.isGameProfileSetting = YES;
        [self addSetting:self.disablePencilSlideGestureStack ofId:@"disablePencilSlideGestureStack" to:pencilSection];

        [pencilSection addToParentStack:_parentStack];
    }


    MenuSectionView *gesturesSection = [[MenuSectionView alloc] init];
    gesturesSection.delegate = self;
    gesturesSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Gestures"];
    gesturesSection.identifier = @"SettingsSectionGestures";
    if (@available(iOS 13.0, *)) {
        [gesturesSection setSectionWithIcon:[UIImage systemImageNamed:@"hand.draw"] size:23 sizeConstraint:-11.3];
    }

    self.softKeyboardGestureStack.hasInfoTag = YES;
    [self addSetting:self.softKeyboardGestureStack ofId:@"softKeyboardGestureStack" to:gesturesSection];

    [self addSetting:self.slideToSettingsScreenEdgeStack ofId:@"slideToSettingsScreenEdgeStack" to:gesturesSection];
    [self addSetting:self.slideToToolboxScreenEdgeStack ofId:@"slideToToolboxScreenEdgeStack" to:gesturesSection];

    self.slideToSettingsDistanceStack.hasInfoTag = YES;
    self.slideToSettingsDistanceStack.hasDynamicLabel = YES;
    [self addSetting:self.slideToSettingsDistanceStack ofId:@"slideToSettingsDistanceStack" to:gesturesSection];

    self.edgeSlidingSensitivityStack.hasInfoTag = YES;
    self.edgeSlidingSensitivityStack.hasDynamicLabel = YES;
    [self addSetting:self.edgeSlidingSensitivityStack ofId:@"edgeSlidingSensitivityStack" to:gesturesSection];

    [gesturesSection addToParentStack:_parentStack];


    MenuSectionView *peripheralSection = [[MenuSectionView alloc] init];
    peripheralSection.delegate = self;
    peripheralSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Peripherals"];
    peripheralSection.identifier = @"SettingsSectionPeripherals";
    if (@available(iOS 13.0, *)) {
        [peripheralSection setSectionWithIcon:[UIImage imageNamed:@"cable.connector.video"] size:20 sizeConstraint:-16.9];
    }

    if (@available(iOS 13.0, *)) {
        self.externalDisplayModeStack.hasInfoTag = YES;
        [self addSetting:self.externalDisplayModeStack ofId:@"externalDisplayModeStack" to:peripheralSection];
    }

    self.localMousePointerModeStack.hasInfoTag = YES;
    [self addSetting:self.localMousePointerModeStack ofId:@"localMousePointerModeStack" to:peripheralSection];

    [self addSetting:self.reverseMouseWheelDirectionStack ofId:@"reverseMouseWheelDirectionStack" to:peripheralSection];
    [self addSetting:self.citrixX1MouseStack ofId:@"citrixX1MouseStack" to:peripheralSection];
    
    self.globeAsEscapeStack.hasInfoTag = YES;
    [self addSetting:self.globeAsEscapeStack ofId:@"globeAsEscapeStack" to:peripheralSection];

    [peripheralSection addToParentStack:_parentStack];


    MenuSectionView *audioSection = [[MenuSectionView alloc] init];
    audioSection.delegate = self;
    audioSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Audio"];
    audioSection.identifier = @"SettingsSectionAudio";
    if (@available(iOS 13.0, *)) {
        [audioSection setSectionWithIcon:[UIImage imageNamed:@"speaker.wave.2"] size:20 sizeConstraint:-15.7];
    }

    [self addSetting:self.audioOnPcStack ofId:@"audioOnPcStack" to:audioSection];

    self.localVolumeStack.hasDynamicLabel = YES;
    [self addSetting:self.localVolumeStack ofId:@"localVolumeStack" to:audioSection];

    self.redirectMicStack.hasInfoTag = YES;
    [self addSetting:self.redirectMicStack ofId:@"redirectMicStack" to:audioSection];

    self.useBuiltinMicStack.hasInfoTag = YES;
    [self addSetting:self.useBuiltinMicStack ofId:@"useBuiltinMicStack" to:audioSection];

    self.micVolumeStack.hasDynamicLabel = YES;
    [self addSetting:self.micVolumeStack ofId:@"micVolumeStack" to:audioSection];

    [self addSetting:self.duckOtherAppStack ofId:@"duckOtherAppStack" to:audioSection];
    [self addSetting:self.muteInBackgroundStack ofId:@"muteInBackgroundStack" to:audioSection];

    self.audioConfigStack.hasInfoTag = YES;
    [self addSetting:self.audioConfigStack ofId:@"audioConfigStack" to:audioSection];

    [audioSection addToParentStack:_parentStack];


    otherSection = [[MenuSectionView alloc] init];
    otherSection.delegate = self;
    otherSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Others"];
    otherSection.identifier = @"SettingsSectionOthers";
    if (@available(iOS 13.0, *)) {
        [otherSection setSectionWithIcon:[UIImage systemImageNamed:@"cube"] size:19.5 sizeConstraint:-17];
    }

    [self addSetting:self.statsOverlayStack ofId:@"statsOverlayStack" to:otherSection];

    self.unlockDisplayOrientationStack.hasInfoTag = YES;
    [self addSetting:self.unlockDisplayOrientationStack ofId:@"unlockDisplayOrientationStack" to:otherSection];

    self.backgroundSessionTimerStack.hasDynamicLabel = YES;
    [self addSetting:self.backgroundSessionTimerStack ofId:@"backgroundSessionTimerStack" to:otherSection];

    [self addSetting:self.appThemeStack ofId:@"appThemeStack" to:otherSection];

    self.optimizeGamesStack.hasInfoTag = YES;
    [self addSetting:self.optimizeGamesStack ofId:@"optimizeGamesStack" to:otherSection];

    [self addSetting:self.multiControllerStack ofId:@"multiControllerStack" to:otherSection];
    [self addSetting:self.softKeyboardToolbarStack ofId:@"softKeyboardToolbarStack" to:otherSection];

    self.softKeyboardHeightStack.hasInfoTag = YES;
    [self addSetting:self.softKeyboardHeightStack ofId:@"softKeyboardHeightStack" to:otherSection];

    [self addSetting:self.rememberFoldStateStack ofId:@"rememberFoldStateStack" to:otherSection];

    [otherSection addToParentStack:_parentStack];


    experimentalSection = [[MenuSectionView alloc] init];
    experimentalSection.delegate = self;
    experimentalSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Experimental"];
    experimentalSection.identifier = @"SettingsSectionExperimental";
    if (@available(iOS 13.0, *)) {
        [experimentalSection setSectionWithIcon:[UIImage imageNamed:@"flask"] size:19 sizeConstraint:-19];
    }

    [self addSetting:self.touchModeStack2 ofId:@"touchModeStack2" to:experimentalSection];

    // self.touchMoveEventIntervalStack.hasDynamicLabel = YES;
    // [self addSetting:self.touchMoveEventIntervalStack ofId:@"touchMoveEventIntervalStack" to:experimentalSection];

    self.relativeTouchSlideThresholdStack.hasDynamicLabel = YES;
    [self addSetting:self.relativeTouchSlideThresholdStack ofId:@"relativeTouchSlideThresholdStack" to:experimentalSection];

    self.singleTapSensitivityStack.hasDynamicLabel = YES;
    [self addSetting:self.singleTapSensitivityStack ofId:@"singleTapSensitivityStack" to:experimentalSection];

    self.leftClickDelayStack.hasDynamicLabel = YES;
    [self addSetting:self.leftClickDelayStack ofId:@"leftClickDelayStack" to:experimentalSection];

    self.renderingBackendStack.hasInfoTag = YES;
    [self addSetting:self.renderingBackendStack ofId:@"renderingBackendStack" to:experimentalSection];

    [self addSetting:self.fullColorRangeStack ofId:@"fullColorRangeStack" to:experimentalSection];

    self.performanceGraphStack.hasInfoTag = YES;
    [self addSetting:self.performanceGraphStack ofId:@"performanceGraphStack" to:experimentalSection];

    [self addDynamicLabelForStack:self.graphOpacityStack];

    [self addSetting:self.sendDummyEventStack ofId:@"sendDummyEventStack" to:experimentalSection];

    [experimentalSection addToParentStack:_parentStack];
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

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) {
        return;
    }
    
    [self settingsScrollViewWillBeginDragging:scrollView];
}

- (void)settingsScrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self scheduleTouchVelocityPreviewDismiss];
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

- (void)clearBackgroundColorForView:(UIView* )view animateWithDuration:(CGFloat)duration{
    [UIView animateWithDuration:duration animations:^{
        view.backgroundColor = [UIColor clearColor];
    }];
}

- (void)highlightedBackgroundForView:(UIView* )view animateWithDuration:(CGFloat)duration completion: (void (^)(void))completion{
    [UIView animateWithDuration:duration animations:^{
        view.layer.cornerRadius = 6;
        view.layer.masksToBounds = YES;
        view.clipsToBounds = YES;
        view.backgroundColor = ThemeManager.appPrimaryColorWithAlpha;
    } completion:^(BOOL finished){
        if(completion) completion();
    }];
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
                [self highlightedBackgroundForView:currentStack animateWithDuration:0 completion:nil];
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
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:PublicUtils.isIPhone ? [LocalizationHelper localizedStringForKey:@"Cancel"] : @""
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
    if(self.currentSettingsMenuMode == AllSettings &&gesture.state == UIGestureRecognizerStateBegan) {
        [self findCapturedStackByTouchLocation:locationInParentStack];
        if(capturedStack == nil) return;
        [self highlightedBackgroundForView:capturedStack animateWithDuration:0 completion:nil];
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

    if(self.currentSettingsMenuMode == FavoriteSettings){
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
    
    if(settingStack.accessibilityIdentifier) [_favoriteSettingStackIdentifiers addObject:settingStack.accessibilityIdentifier];
    else if(settingStack.superview.accessibilityIdentifier) [_favoriteSettingStackIdentifiers addObject:settingStack.superview.accessibilityIdentifier];
    
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
        if(stack.isGameProfileSetting){
            UIImage* image;
            if(PublicUtils.iOS18Available){
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14.5 weight:UIImageSymbolWeightRegular];
                image = [UIImage systemImageNamed:@"gamecontroller.circle" withConfiguration:config];
            }
            else{
                image = [[UIImage imageNamed: @"gamecontroller.circle.tag"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            
            [button setImage:image forState:UIControlStateNormal];
        }
        else{
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13.5 weight:UIImageSymbolWeightMedium];
            [button setImage:[UIImage systemImageNamed:@"info.circle" withConfiguration:config] forState:UIControlStateNormal];
        }
    } else {
        [button setTitle:stack.isGameProfileSetting ? @"game" : @"info" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        button.titleLabel.accessibilityIdentifier = @"infoButton";
    }
    button.accessibilityIdentifier = @"infoButton";
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = ThemeManager.appPrimaryColor;
    
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

    
    tipText = @"";
    if([sender.superview.accessibilityIdentifier isEqualToString: @"bitrateStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"bitrateStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"yuv444Stack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"yuv444StackTip"];
        showOnlineDocAction = false;
        onlineDocLink = @"https://voidlink.yuque.com/org-wiki-voidlink-znirha/fa3tgr/koeimmrvt4o17auc";
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
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"yourMotionControlSoution"];
    }
        if([sender.superview.accessibilityIdentifier isEqualToString: @"mapGyroToStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"mapGyroToStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"yourMotionControlSoution"];
    }
    
    if([sender.superview.accessibilityIdentifier isEqualToString: @"renderingBackendStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"renderingBackendStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"performanceGraphStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"performanceGraphStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"framePacingStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"framePacingStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"redirectMicStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"redirectMicStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"sendDummyEventStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"sendDummyEventStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"useBuiltinMicStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"useBuiltinMicStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"delayLeftClickStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"delayLeftClickStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"relativeTouchSlideThresholdStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"relativeTouchSlideThresholdStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"relativeTouchSlideThresholdStackLink"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"ctrlDownForPinchStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"ctrlDownForPinchStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"controllerMouseExpoStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"controllerMouseExpoStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"edgeSlidingSensitivityStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"edgeSlidingSensitivityStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"controllerGyroSwitchButtonStack"]){
        oscProfile = [oscProfileMan getSelectedProfile];
        tipText = [LocalizationHelper localizedStringForKey:@"controllerGyroSwitchButtonStackTip", [ControllerUtil stringFor:oscProfile.controllerGyroSwitchToggle], [ControllerUtil stringFor:oscProfile.controllerGyroSwitchHold]];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"controllerNavigationStack"]){
        tempSettings = [dataMan getSettings];
        tipText = [LocalizationHelper localizedStringForKey:@"controllerNavigationStackTip", [ControllerUtil stringFor:tempSettings.localRadialMenuButton.intValue], [ControllerUtil stringFor:tempSettings.streamingRadialMenuButton.intValue],  [ControllerUtil stringFor:tempSettings.controllerMouseStick.intValue],  [ControllerUtil stringFor:tempSettings.controllerMouseLeftButton.intValue], [ControllerUtil stringFor:tempSettings.controllerMouseRightButton.intValue]];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"reverseHoldButtonStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"reverseHoldButtonStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"leftStickMinOffsetStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"physicaStickMinOffsetTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"rightStickMinOffsetStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"physicaStickMinOffsetTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"audioConfigStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"audioConfigStackTip"];
        showOnlineDocAction = false;
    }
    
    if([sender.superview.accessibilityIdentifier isEqualToString: @"doubleTapShortcutStack"]){
        oscProfile = [oscProfileMan getSelectedProfile];
        tipText = [LocalizationHelper localizedStringForKey:@"doubleTapShortcutStackTip"
                   , [oscProfile.brushShortcut isEqualToString:@""] ? [LocalizationHelper localizedStringForKey:@"Null"] : oscProfile.brushShortcut
                   , [oscProfile.eraserShortcut isEqualToString:@""] ? [LocalizationHelper localizedStringForKey:@"Null"] : oscProfile.eraserShortcut
        ];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"squeezeShortcutStack"]){
        oscProfile = [oscProfileMan getSelectedProfile];
        tipText = [LocalizationHelper localizedStringForKey:@"squeezeShortcutStackTip"
                   , [oscProfile.squeezeStartShortcut isEqualToString:@""] ? [LocalizationHelper localizedStringForKey:@"Null"] : oscProfile.squeezeStartShortcut
                   , [oscProfile.squeezeEndShortcut isEqualToString:@""] ? [LocalizationHelper localizedStringForKey:@"Null"] : oscProfile.squeezeEndShortcut
        ];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"sdrPerformanceWorkaroundStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"sdrPerformanceWorkaroundStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"asyncFrameDequeueStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"asyncFrameDequeueStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"pencilModeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"pencilModeStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"pencilTickStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"pencilTickStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"PencilProPackURL"];
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"softKeyboardHeightStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"softKeyboardHeightStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"swapYawAndRollStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"swapYawAndRollStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"globeAsEscapeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"globeAsEscapeStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"interpolationLevelStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"frameInterpolationResolutionTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"streamDimensionScaleStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"streamDimensionScaleStackTip"];
        showOnlineDocAction = false;
    }

    UIStackView* parentStack = (UIStackView* )sender.superview;
    NSString* edgeSide = self.slideToSettingsScreenEdgeSelector.selectedSegmentIndex == 1 ? [LocalizationHelper localizedStringForKey:@"left"] : [LocalizationHelper localizedStringForKey:@"right"];
    NSString* slideDist = [NSString stringWithFormat:@"%d%%", (int)(self.slideToMenuDistanceSlider.value*100)];
    NSString* gameProfileTip = [LocalizationHelper localizedStringForKey:@"gameProfileStackTip", edgeSide, slideDist];
    tipText = parentStack.isGameProfileSetting ? ([tipText isEqualToString:@""] ? gameProfileTip : [NSString stringWithFormat:@"%@ \n\n%@", gameProfileTip, tipText]) : tipText;
    
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
    
    UIAlertAction *readInstruction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Learn More"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action){
        [PublicUtils openUrl:onlineDocLink];
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


// 旧版本iOS兼容必要
- (void)forceRestoreHeightTemporarilyForSettingStackParentView{
    for(UIStackView* stack in hiddenStacks) {
        stack.hidden = NO;
    }
    if(self.currentSettingsMenuMode == AllSettings){
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
    
    if(self.currentSettingsMenuMode != AllSettings){
        [_favoriteSettingStackIdentifiers removeAllObjects];
        //for(NSInteger i = 0; i < parentStack.arrangedSubviews.count; i++){
        for(NSInteger i = 0; i < _parentStack.arrangedSubviews.count; i++){
            if(_parentStack.arrangedSubviews[i].accessibilityIdentifier) [_favoriteSettingStackIdentifiers addObject:_parentStack.arrangedSubviews[i].accessibilityIdentifier];
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

- (void)restoreCoreDataSettingsForUIKitMenu:(TemporarySettings* )tempSettings {
    [UIView animateWithDuration:0 animations:^{
    
        self->oscProfileMan = [OSCProfilesManager sharedManager:CGRectZero];

        self->settingStackWillBeRelocatedToLowestPosition = false;
        self->hiddenStacks = [[NSMutableSet alloc] init];

        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self.view addGestureRecognizer:longPress];

        self->_settingStackDict = [[NSMutableDictionary alloc] init];

     
        for(UIView* view in self.view.subviews){
            [view removeFromSuperview];
        }
        
        [self initParentStack];
        
        // load rememberFoldState before section layout
        [self.rememberFoldStateSwitch setOn:self->tempSettings.rememberFoldState];// Load old setting
        MenuSectionView.overridePersistedFoldState = !self->tempSettings.rememberFoldState;
        [self.rememberFoldStateSwitch addTarget:self action:@selector(rememberFoldStateSwitchFlipped:) forControlEvents:UIControlEventValueChanged];

        [self layoutSections];

        // [self swi];

#if !TARGET_OS_TV
        self->slideToCloseSettingsViewRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(edgeSwiped)];
        self->slideToCloseSettingsViewRecognizer.edges = UIRectEdgeLeft;
        self->slideToCloseSettingsViewRecognizer.normalizedThresholdDistance = 0.0;
        self->slideToCloseSettingsViewRecognizer.edgeTolerance = 10;
        self->slideToCloseSettingsViewRecognizer.immediateTriggering = true;
        self->slideToCloseSettingsViewRecognizer.delaysTouchesBegan = NO;
        self->slideToCloseSettingsViewRecognizer.delaysTouchesEnded = NO;
        [self.view addGestureRecognizer:self->slideToCloseSettingsViewRecognizer];
#endif

        self->settingsViewJustLoaded = true;
        self->settingsViewJustExpanded = true;
        self->settingsViewAlreadyAppeared = false;

        // Always run settings in dark mode because we want the light fonts
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }

        [self loadFavoriteSettingStackIdentifiers];
        if(self->tempSettings.settingsMenuMode.intValue == FavoriteSettings) [self switchToFavoriteSettings];

        // Ensure we pick a bitrate that falls exactly onto a slider notch
        self->_bitrate = bitrateTable[[self getSliderValueForBitrate:[self->tempSettings.bitrate intValue]]];

        // Get the size of the screen with and without safe area insets
        // UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
        // CGFloat screenScale = window.screen.scale;
        // CGFloat safeAreaWidth = (window.frame.size.width - window.safeAreaInsets.left - window.safeAreaInsets.right) * screenScale;
        // CGFloat fullScreenWidth = window.frame.size.width * screenScale;
        // CGFloat fullScreenHeight = window.frame.size.height * screenScale;
        
        self.resolutionSelectorStack.accessibilityIdentifier = @"resolutionSelectorStack";
        self.customResolutionStack.accessibilityIdentifier = @"customResolutionStack";

        [self.resolutionSelector removeSegmentAtIndex:0 animated:NO]; // remove 360p
        [self.resolutionSelector removeSegmentAtIndex:5 animated:NO]; // remove custom segment
        // iOS12 compatibility:
        self.resolutionSelector.selectedSegmentIndex = 3;
        [self.resolutionSelector setNeedsLayout];

        resolutionTable[5] = (CMVideoDimensions){
            .width = (int32_t)[self->tempSettings.width integerValue],
            .height = (int32_t)[self->tempSettings.height integerValue],
        }; // custom initial value
        [self updateResolutionTable];


        NSInteger framerate;
        switch ([self->tempSettings.framerate integerValue]) {
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

        NSInteger resolution = self->tempSettings.resolutionSelected.integerValue;
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

        [UIView animateWithDuration:0 animations:^{
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
                [self.resolutionSelector setEnabled:NO forSegmentAtIndex:2];
            }
            
            switch (self->tempSettings.preferredCodec) {
                case CODEC_PREF_AUTO:
                    self.codecSelector.selectedSegmentIndex = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) ? CODEC_PREF_HEVC-1 : CODEC_PREF_H264-1;
                    [self.codecSelector sendActionsForControlEvents:UIControlEventValueChanged];
                    break;
                    
                case CODEC_PREF_AV1:
                    self.codecSelector.selectedSegmentIndex = 2;
                    break;
                    
                case CODEC_PREF_HEVC:
                    self.codecSelector.selectedSegmentIndex = 1;
                    break;
                    
                case CODEC_PREF_H264:
                    self.codecSelector.selectedSegmentIndex = 0;
                    break;
            }
        }];

        if (![Utils hdrSupported]) {
            [self.hdrSwitch setOn:NO];
            [self.hdrSwitch setEnabled:NO];
        }
        else {
            [self.hdrSwitch setOn:self->tempSettings.enableHdr];
            [self.hdrSwitch addTarget:self action:@selector(hdrSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        }
        
        // Initialize codec-dependent switches together
        [self.yuv444Switch setOn:self->tempSettings.enableYUV444];
        [self.fullColorRangeSwitch setOn:self->tempSettings.fullColorRange];
        [self.codecSelector addTarget:self action:@selector(codecSelectorChanged:) forControlEvents:UIControlEventValueChanged];
        [self.codecSelector sendActionsForControlEvents:UIControlEventValueChanged];

        [self.pipSwitch setOn:self->tempSettings.enablePIP];
        if(@available(iOS 15.0, *)) {
            [self.pipSwitch setEnabled:true];
        } else{
            [self.pipSwitch setOn:false];
            [self.pipSwitch setEnabled:false];
        }
        
        self.statsOverlaySelector.selectedSegmentIndex = self->tempSettings.statsOverlayLevel.intValue;

        NSInteger renderingBackend = [self->tempSettings.renderingBackend integerValue];
        self.renderingBackendSelector.selectedSegmentIndex = renderingBackend;
        [self.renderingBackendSelector addTarget:self action:@selector(renderingBackendChanged:) forControlEvents:UIControlEventValueChanged];
        [self.renderingBackendSelector sendActionsForControlEvents:UIControlEventValueChanged];

        NSInteger framePacingMode = [self->tempSettings.framePacingMode integerValue];
        self.framePacingModeSelector.selectedSegmentIndex = framePacingMode;
        ((UILabel *)self.interpolationLevelStack.arrangedSubviews.firstObject).text =
            [LocalizationHelper localizedStringForKey:@"Interpolation Resolution"];
        [self.interpolationLevelSlider addTarget:self action:@selector(interpolationLevelSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.interpolationLevelSlider addTarget:self action:@selector(interpolationLevelSliderInteractionEnded:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
        ((UILabel *)self.streamDimensionScaleStack.arrangedSubviews.firstObject).text =
            [LocalizationHelper localizedStringForKey:@"Scaled Stream Resolution"];
        [self.streamDimensionScaleSlider addTarget:self action:@selector(streamDimensionScaleSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.framePacingModeSelector addTarget:self action:@selector(framePacingModeChanged:) forControlEvents:UIControlEventValueChanged];
        UITapGestureRecognizer *interpolationAvailabilityTap = [[UITapGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(framePacingModeSelectorTapped:)];
        interpolationAvailabilityTap.cancelsTouchesInView = NO;
        [self.framePacingModeSelector addGestureRecognizer:interpolationAvailabilityTap];
        [self.framePacingModeSelector sendActionsForControlEvents:UIControlEventValueChanged];

        // [self.frameTimebaseSwitch setOn:self->tempSettings.enableFrameTimebase];
        [self.asyncFrameDequeueSwitch setOn:self->tempSettings.asyncFrameDequeue];
        [self.sdrPerformanceWorkaroundSwitch setOn:self->tempSettings.sdrPerformanceWorkaround];


        [self.citrixX1MouseSwitch setOn:self->tempSettings.btMouseSupport];
        [self.globeAsEscapeSwitch setOn:self->tempSettings.globeAsEscape];
        
        [self.optimizeGamesSwitch setOn: self->tempSettings.optimizeGames];
        [self.multiControllerSwitch setOn:self->tempSettings.multiController];
        [self.swapAbxySwitch setOn:self->tempSettings.swapABXYButtons];
        [self.buttonVisualFeedbackSwitch setOn:self->tempSettings.buttonVisualFeedback];
        
        [self.trackTouchPointSwitch setOn:self->tempSettings.touchPointTracking];
        [self.trackTouchPointSwitch addTarget:self action:@selector(trackTouchPointSwitchFlipped:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.

        [self.delayLeftClickSwitch setOn:self->tempSettings.delayLeftClick];

        self.hapticEngineSelector.selectedSegmentIndex = self->tempSettings.hapticEngine.intValue;
        bool hideHapticEngineStack = false;
        if(@available(iOS 13.0, tvOS 13.0, *)) hideHapticEngineStack = false;
        else hideHapticEngineStack = true;
        [self setHidden:hideHapticEngineStack forStack:self.hapticEngineStack];
        bool disableControllerRumble = false;
        if(@available(iOS 14.0, tvOS 14.0, *)) nil;
        else disableControllerRumble = true;
        [self.hapticEngineSelector setEnabled:!disableControllerRumble forSegmentAtIndex:LeftRightSwapped];
        [self.hapticEngineSelector setEnabled:!disableControllerRumble forSegmentAtIndex:HapticEngineAuto];
        [self.hapticEngineSelector setEnabled:PublicUtils.isIPhone forSegmentAtIndex:RumbleDevice];
        
        [self.dualSenseTransientSlider addTarget:self action:@selector(dualSenseTransientSliderMoved:) forControlEvents:UIControlEventValueChanged];

        self.gyroModeSelector.selectedSegmentIndex = self->tempSettings.gyroMode.intValue;
        [self.gyroModeSelector addTarget:self action:@selector(emulatedGyroModeChanged:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        
        [self.gyroSensitivitySlider setValue: (uint16_t)(self->tempSettings.gyroSensitivity.floatValue * 100) animated:NO]; // Load old setting.
        [self.gyroSensitivitySlider addTarget:self action:@selector(gyroSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self.gyroSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged]; // Load old setting.

        if (@available(iOS 14.0, tvOS 14.0, *)) nil;
        else{
            [self.gyroModeSelector setEnabled:false forSegmentAtIndex:1];
            [self.gyroModeSelector setEnabled:false forSegmentAtIndex:3];
        }
        CMMotionManager *motionManager = [[CMMotionManager alloc] init];
        [self.gyroModeSelector setEnabled:[motionManager isGyroAvailable] forSegmentAtIndex:2];
        
        self.emulatedControllerTypeSelector.selectedSegmentIndex = [self controllerTypeToSegmentIndex:self->tempSettings.emulatedControllerType.intValue];
        [self.emulatedControllerTypeSelector addTarget:self action:@selector(emulatedControllerTypeChanged:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self.emulatedControllerTypeSelector sendActionsForControlEvents:UIControlEventValueChanged];

        [self.leftStickMinOffsetSlider addTarget:self action:@selector(leftStickMinOffsetSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.rightStickMinOffsetSlider addTarget:self action:@selector(rightStickMinOffsetSliderMoved:) forControlEvents:UIControlEventValueChanged];

        [self.audioOnPcSwitch setOn:self->tempSettings.playAudioOnPC];
        
        [self.localVolumeSlider setValue:self->tempSettings.localVolume.floatValue*100];
        [self.localVolumeSlider addTarget:self action:@selector(localVolumeSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.localVolumeSlider sendActionsForControlEvents:UIControlEventValueChanged]; // Load old setting.

        [self.duckOtherAppSwitch setOn:self->tempSettings.duckOtherApps];
        
        [self.muteInBackgroundSwitch setOn:self->tempSettings.muteInBackground];
        [self.muteInBackgroundSwitch addTarget:self action:@selector(muteInBackgroundSwitchFlipped:) forControlEvents:UIControlEventValueChanged];

        [self.micVolumeSlider setValue:self->tempSettings.micVolume.floatValue*100];
        [self.micVolumeSlider addTarget:self action:@selector(micVolumeSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.micVolumeSlider sendActionsForControlEvents:UIControlEventValueChanged]; // Load old setting.

        [self.redirectMicSwitch setOn:self->tempSettings.redirectMic];
        [self.redirectMicSwitch addTarget:self action:@selector(redirectMicSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self.redirectMicSwitch sendActionsForControlEvents:UIControlEventValueChanged];

        [self.useBuiltinMicSwitch setOn:self->tempSettings.useBuiltinMic];
        
        self->_lastSelectedResolutionIndex = resolution;
        self.resolutionSelector.selectedSegmentIndex = resolution;
        [self updateInterpolationLevelSliderWithMaximumDimension:self->tempSettings.interpolationMaximumDimension.integerValue];
        self.streamDimensionScaleSlider.minimumValue = 0;
        self.streamDimensionScaleSlider.maximumValue = 1;
        self.streamDimensionScaleSlider.value = MIN(1, MAX(0, self->tempSettings.streamDimensionScale.floatValue));
        [self.streamDimensionScaleSlider sendActionsForControlEvents:UIControlEventValueChanged];
        [self.resolutionSelector addTarget:self action:@selector(newResolutionChosen) forControlEvents:UIControlEventValueChanged];

        self.framerateSelector.selectedSegmentIndex = framerate;
        [self.framerateSelector addTarget:self action:@selector(framerateChanged) forControlEvents:UIControlEventValueChanged];
        
        [self.bitrateSlider setMinimumValue:0];
        [self.bitrateSlider setMaximumValue:(sizeof(bitrateTable) / sizeof(*bitrateTable)) - 1];
        [self.bitrateSlider setValue:[self getSliderValueForBitrate:self->_bitrate] animated:NO];
        [self.bitrateSlider addTarget:self action:@selector(bitrateSliderMoved) forControlEvents:UIControlEventValueChanged];
        [self.bitrateSlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.frameQueueSizeSlider setMinimumValue:0];
        [self.frameQueueSizeSlider setMaximumValue:5];
        [self.frameQueueSizeSlider setValue:self->tempSettings.frameQueueSize.intValue];
        [self.frameQueueSizeSlider addTarget:self action:@selector(frameQueueSizeSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.frameQueueSizeSlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.enableGraphsSwitch setOn:self->tempSettings.enableGraphs animated:NO]; // Add this line
        [self.enableGraphsSwitch addTarget:self action:@selector(enableGraphsChanged:) forControlEvents:UIControlEventValueChanged];
        [self.enableGraphsSwitch sendActionsForControlEvents:UIControlEventValueChanged];
        
        [self.graphOpacityStepper setMinimumValue:0];
        [self.graphOpacityStepper setMaximumValue:100];
        [self.graphOpacityStepper setValue:(int)self->tempSettings.graphOpacity.intValue];
        [self.graphOpacityStepper addTarget:self action:@selector(graphOpacityStepperTapped:) forControlEvents:UIControlEventValueChanged];
        [self.graphOpacityStepper sendActionsForControlEvents:UIControlEventValueChanged];

        self.audioEngineSelector.selectedSegmentIndex = self->tempSettings.audioEngine.intValue;
        
        if (@available(iOS 18.0, tvOS 18.0, *)) {}else{
            [self.audioConfigSelector removeSegmentAtIndex:2 animated:false];
            [self.audioConfigSelector removeSegmentAtIndex:2 animated:false]; // segment 2 goes away when you remove index 2
            /*
            [self.audioConfigSelector setTitle:[LocalizationHelper localizedStringForKey:@"Stereo (surround sound available for iOS18+)"] forSegmentAtIndex:0];
            [self.audioConfigSelector setEnabled:NO];*/
        }
        switch ([self->tempSettings.audioConfig integerValue]) {
            case 2:
                self.audioConfigSelector.selectedSegmentIndex = 0;
                break;
            case 3:
                self.audioConfigSelector.selectedSegmentIndex = 1;
                break;
            case 6:
                self.audioConfigSelector.selectedSegmentIndex = 2;
                break;
            case 8:
                self.audioConfigSelector.selectedSegmentIndex = 3;
                break;
        }
        // 2 - stereo (system)
        // 3 - stereo (SDL)
        // 6 - 5.1 (SDL)
        // 8 - 7.1 (SDL)

        // Unlock Display Orientation setting
        bool unlockDisplayOrientationSelectorEnabled = [self isFullScreenRequired] || PublicUtils.isIPhone;//need "requires fullscreen" enabled in the app bunddle to make runtime orientation limitation working
        if(unlockDisplayOrientationSelectorEnabled) self.unlockDisplayOrientationSelector.selectedSegmentIndex = self->tempSettings.unlockDisplayOrientation ? 1 : 0;
        else self.unlockDisplayOrientationSelector.selectedSegmentIndex = 1; // can't lock screen orientation in this mode = Display Orientation always unlocked
        [self.unlockDisplayOrientationSelector setEnabled:unlockDisplayOrientationSelectorEnabled];

        [self.backgroundSessionTimerSlider setValue:(uint32_t)self->tempSettings.backgroundSessionTimer.floatValue];
        [self.backgroundSessionTimerSlider addTarget:self action:@selector(backgroundSessionTimerSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.backgroundSessionTimerSlider sendActionsForControlEvents:UIControlEventValueChanged];

        self.appThemeSelector.selectedSegmentIndex = self->tempSettings.appTheme.intValue;
        [self.appThemeSelector addTarget:self action:@selector(appThemeChanged:) forControlEvents:UIControlEventValueChanged];
        if (@available(iOS 13.0, *)) nil;
        else{
            self.appThemeSelector.selectedSegmentIndex = UIUserInterfaceStyleDark;
            [self.appThemeSelector setEnabled:false];
        }
        
        // lift streamview setting
        self.liftStreamViewForKeyboardSelector.selectedSegmentIndex = self->tempSettings.liftStreamViewForKeyboard ? 1 : 0;// Load old setting

        // showkeyboard toolbar setting
        [self.softKeyboardToolbarSwitch setOn:self->tempSettings.showKeyboardToolbar];// Load old setting
        
        self->softKeyboardHeight = self->tempSettings.softKeyboardHeight;
        [self.softKeyboardHeightSwitch setOn:self->softKeyboardHeight!=0];// Load old setting
        [self.softKeyboardHeightSwitch addTarget:self action:@selector(softKeyboardHeightSwitchFlipped:) forControlEvents:UIControlEventValueChanged];


        // reverse mouse wheel direction setting
        self.reverseMouseWheelDirectionSelector.selectedSegmentIndex = self->tempSettings.reverseMouseWheelDirection ? 1 : 0;// Load old setting

        //  slide to menu settings
        self.slideToSettingsScreenEdgeSelector.selectedSegmentIndex = [self getSelectorIndexFromScreenEdge:(uint32_t)self->tempSettings.slideToSettingsScreenEdge.integerValue];
        // Load old setting
        [self.slideToToolboxScreenEdgeSelector setEnabled:false];
        [self.slideToSettingsScreenEdgeSelector addTarget:self action:@selector(slideToSettingsScreenEdgeChanged) forControlEvents:UIControlEventValueChanged];
        [self.slideToSettingsScreenEdgeSelector sendActionsForControlEvents:UIControlEventValueChanged];

        [self.slideToMenuDistanceSlider setValue:self->tempSettings.slideToSettingsDistance.floatValue];
        [self.slideToMenuDistanceSlider addTarget:self action:@selector(slideToMenuDistanceSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self.slideToMenuDistanceSlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.edgeSlidingSensitivitySlider setValue:self->tempSettings.edgeSlidingSensitivity.floatValue];
        [self.edgeSlidingSensitivitySlider addTarget:self action:@selector(edgeSlidingSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self.edgeSlidingSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];

        //TouchMode & OSC Related Settings:

        // pointer veloc setting, will be enable/disabled by touchMode
        [self.pointerVelocityModeDividerSlider addTarget:self action:@selector(pointerVelocityModeDividerSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        if (@available(iOS 13.0, *)) {
            [self.pointerVelocityModeDividerSlider addTarget:self action:@selector(cancelTouchVelocityPreviewDismiss) forControlEvents:UIControlEventTouchDown];
            [self.pointerVelocityModeDividerSlider addTarget:self action:@selector(scheduleTouchVelocityPreviewDismiss) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
        }

        // init pointer veloc setting,  will be enable/disabled by touchMode
        [self.touchPointerVelocityFactorSlider addTarget:self action:@selector(touchPointerVelocityFactorSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        if (@available(iOS 13.0, *)) {
            [self.touchPointerVelocityFactorSlider addTarget:self action:@selector(cancelTouchVelocityPreviewDismiss) forControlEvents:UIControlEventTouchDown];
            [self.touchPointerVelocityFactorSlider addTarget:self action:@selector(scheduleTouchVelocityPreviewDismiss) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
        }

        // async native touch event
        // self.asyncNativeTouchPrioritySelector.selectedSegmentIndex = currentSettings.asyncNativeTouchPriority.intValue; // load old setting of asyncNativeTouchPriority
        // [self.asyncNativeTouchPrioritySelector addTarget:self action:@selector(asyncNativeTouchPriorityChanged) forControlEvents:UIControlEventValueChanged];

        // init relative touch mouse pointer veloc setting,  will be enable/disabled by touchMode
        [self.mousePointerVelocityFactorSlider setValue:[self map_SliderValue_fromVelocFactor: self->tempSettings.mousePointerVelocityFactor.floatValue] animated:NO]; // Load old setting.
        [self.mousePointerVelocityFactorSlider addTarget:self action:@selector(mousePointerVelocityFactorSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self.mousePointerVelocityFactorSlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.passthroughGesturesSwitch setOn:self->tempSettings.passthroughGestures];
        [self.passthroughGesturesSwitch addTarget:self action:@selector(passthroughGesturesSwitchFlipped:) forControlEvents:(UIControlEventValueChanged)];
        
        [self.pinchGestureSwitch setOn:self->tempSettings.enablePinch];
        [self.pinchGestureSwitch addTarget:self action:@selector(pinchGestureSwitchFlipped:) forControlEvents:(UIControlEventValueChanged)];

        [self.ctrlDownForPinchSwitch setOn:self->tempSettings.ctrlDownForPinch];
        
        [self.scrollSensitivitySlider setValue:self->tempSettings.scrollSensitivity.floatValue animated:NO];
        [self.scrollSensitivitySlider addTarget:self action:@selector(scrollSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self.scrollSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.pinchSensitivitySlider setValue:self->tempSettings.pinchSensitivity.floatValue animated:NO];
        [self.pinchSensitivitySlider addTarget:self action:@selector(pinchSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self.pinchSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.singleTapSensitivitySlider setValue:self->tempSettings.singleTapSensitivity.doubleValue animated:NO];
        [self.singleTapSensitivitySlider addTarget:self action:@selector(singleTapSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self.singleTapSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.relativeTouchSlideThresholdSlider setValue:self->tempSettings.relativeTouchSlideThreshold.floatValue animated:NO];
        [self.relativeTouchSlideThresholdSlider addTarget:self action:@selector(relativeTouchSlideThresholdSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self.relativeTouchSlideThresholdSlider sendActionsForControlEvents:UIControlEventValueChanged];

        // these settings will be affected by onscreenControl & touchMode, must be loaded before them.
        // NSLog(@"osc tool fingers setting test: %d", currentSettings.oscLayoutToolFingers.intValue);
        self->oswLayoutFingers = (uint16_t)self->tempSettings.oscLayoutToolFingers.intValue; // load old setting of oscLayoutFingers
        uint8_t keyboardToggleFingers = self->tempSettings.keyboardToggleFingers.intValue;

        self.softKeyboardGestureSelector.selectedSegmentIndex = keyboardToggleFingers>=6 ? 3 : keyboardToggleFingers-3;



        // this setting will be affected by touchMode, must be loaded before them.
        NSInteger onscreenControlsLevel = [self->tempSettings.onscreenControls integerValue];
        self.onScreenWidgetSelector.selectedSegmentIndex = MIN(onscreenControlsLevel,OnScreenControlsLevelCustom);
        [self.onScreenWidgetSelector addTarget:self action:@selector(onScreenWidgetChanged) forControlEvents:UIControlEventValueChanged];
        [self.onScreenWidgetSelector sendActionsForControlEvents:UIControlEventValueChanged];

        /*
         // touch move event interval for native-touch.
        [self.touchMoveEventIntervalSlider setValue:self->tempSettings.touchMoveEventInterval.intValue animated:NO]; // Load old setting.
        [self.touchMoveEventIntervalSlider addTarget:self action:@selector(touchMoveEventIntervalSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];
         */

        [self.leftClickDelaySlider setValue:self->tempSettings.leftClickDelayMs.intValue animated:NO]; // Load old setting.
        [self.leftClickDelaySlider addTarget:self action:@selector(leftClickDelaySliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self.leftClickDelaySlider sendActionsForControlEvents:UIControlEventValueChanged];
        
        // touchMode refactored to game profile system
        [self.touchModeSelector1 addTarget:self action:@selector(touchMode1Changed:) forControlEvents:UIControlEventValueChanged];
        // [self.enableOswForNativeTouchSwitch addTarget:self action:@selector(enableOswForNativeTouchSwitchFlipped:) forControlEvents:UIControlEventValueChanged];

        self.externalDisplayModeSelector.selectedSegmentIndex = self->tempSettings.externalDisplayMode.integerValue;
        self.localMousePointerModeSelector.selectedSegmentIndex = self->tempSettings.localMousePointerMode.integerValue;
        
        [self.sendDummyEventSwitch setOn:self->tempSettings.sendDummyEvent];// Load old setting
        
        [self.controllerNavigationSwitch setOn:self->tempSettings.enableControllerNavigation];
        [self.controllerNavigationSwitch addTarget:self action:@selector(controllerNavigationSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self.controllerNavigationSwitch sendActionsForControlEvents:UIControlEventValueChanged];

        [self.controllerGyroSwitchButtonSetter addTarget:self action:@selector(controllerGyroSwitchModeChanged:) forControlEvents:UIControlEventValueChanged];
        
        [self.streamingRadialMenuDelaySlider setValue:self->tempSettings.streamingRadialMenuDelay.floatValue];
        [self.streamingRadialMenuDelaySlider addTarget:self action:@selector(streamingRadialMenuDelaySliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.streamingRadialMenuDelaySlider sendActionsForControlEvents:UIControlEventValueChanged];
        
        [self.controllerMouseVelocitySlider setValue:self->tempSettings.controllerMousePointerVelocity.floatValue];
        [self.controllerMouseVelocitySlider addTarget:self action:@selector(controllerMouseVelocitySliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.controllerMouseVelocitySlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.controllerMouseExpoSlider setValue:self->tempSettings.controllerMouseExpo.floatValue];
        [self.controllerMouseExpoSlider addTarget:self action:@selector(controllerMouseExpoSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.controllerMouseExpoSlider sendActionsForControlEvents:UIControlEventValueChanged];

        [self.gyroSourceSelector addTarget:self action:@selector(gyroSourceChanged:) forControlEvents:UIControlEventValueChanged];
        [self.mapGyroToSelector addTarget:self action:@selector(mapGyroToChanged:) forControlEvents:UIControlEventValueChanged];
        [self.yawPitchToRightStickSwitch addTarget:self action:@selector(yawPitchToRightStickSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self.rollToLeftStickSwitch addTarget:self action:@selector(rollToLeftStickSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        
        [self.yawSensitivitySlider addTarget:self action:@selector(yawSensitivitySliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.pitchSensitivitySlider addTarget:self action:@selector(pitchSensitivitySliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.rollSensitivitySlider addTarget:self action:@selector(rollSensitivitySliderMoved:) forControlEvents:UIControlEventValueChanged];
        
        [self.gyroToStickMinOffsetSlider addTarget:self action:@selector(gyroMinStickOffsetSliderMoved:) forControlEvents:UIControlEventValueChanged];

        
        
        // pencil support settings:
        [self loadPencilSettings:self->tempSettings];
        
        
        self->settingsViewJustLoaded = false;
    }];

}

- (void)slideToSettingsScreenEdgeChanged{
    if(self.slideToSettingsScreenEdgeSelector.selectedSegmentIndex == 0) self.slideToToolboxScreenEdgeSelector.selectedSegmentIndex = 1;
    else self.slideToToolboxScreenEdgeSelector.selectedSegmentIndex = 0;
}

- (void)showCustomOswTip {
    GenericUtils.autoPopSoftKeyboard = !PublicUtils.isIPhone;
    NSString* edgeSide = self.slideToSettingsScreenEdgeSelector.selectedSegmentIndex == 1 ? [LocalizationHelper localizedStringForKey:@"left"] : [LocalizationHelper localizedStringForKey:@"right"];
    NSString* slideDist = [NSString stringWithFormat:@"%d%%", (int)(self.slideToMenuDistanceSlider.value*100)];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Edit layout during streaming"]
                                                                             message:[LocalizationHelper localizedStringForKey:@"customOscTip", edgeSide, slideDist]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    /*
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"%d", self->oswLayoutFingers];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.delegate = self;
    }];
    */
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        /*
        UITextField *textField = alertController.textFields.firstObject;
        NSString *inputText = textField.text;
        NSInteger fingers = [inputText integerValue];
        if (inputText.length > 0 && fingers >= 4) {
            self->oswLayoutFingers = (uint16_t) fingers;
            NSLog(@"OK button tapped with %d fingers", (uint16_t)fingers);
        } else {
            NSLog(@"OK button tapped with no change");
        } */
        
        [alertController dismissViewControllerAnimated:true completion:^{
            // Continue execution after the alert is dismissed
            if (!self->_mainFrameViewController.settingsExpandedInStreamView) {
                [self invokeOscLayout]; // Don't open osc layout tool immediately during streaming
            }
        }];

        /*
        [self findDynamicLabelFromStack:self.onScreenWidgetStack].text = [self isCustomOswEnabled] ? [LocalizationHelper localizedStringForKey:@"%d finger tap", self->oswLayoutFingers] : @"";
        [self handleOswGestureChange]; */
    }];
    
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)hdrSwitchFlipped:(UISwitch* )sender{
    /*
    if(!sender.isOn
       && [Utils hdrSupported]
       && !PublicUtils.isIPhone) [self.sdrPerformanceWorkaroundSwitch setOn:true];
     */
}

- (bool)isOswEnabled{
    return self.onScreenWidgetSelector.selectedSegmentIndex != OnScreenControlsLevelOff;
}

- (bool)isCustomOswEnabled{
    bool customOswEnabled = [self isOswEnabled] && self.onScreenWidgetSelector.selectedSegmentIndex == OnScreenControlsLevelCustom;
    // motionControlSection.expandable = customOswEnabled;
    // if(!(settingsViewJustExpanded || settingsViewJustLoaded)) [motionControlSection setExpanded:customOswEnabled];
    return customOswEnabled;
}
/*
- (bool)isNotNativeTouchOnly{
    // return (self.enableOswForNativeTouchSwitch.isOn && self.touchModeSelector1.selectedSegmentIndex == NativeTouch) || self.touchModeSelector1.selectedSegmentIndex != NativeTouch;
    return true;
}
 */

- (void)handleOswGestureChange{
    if(settingsViewJustLoaded) return;
    if([self isCustomOswEnabled] && oswLayoutFingers == self.softKeyboardGestureSelector.selectedSegmentIndex + 3 && oswLayoutFingers < 6){
        _softKeyboardGestureSelector.selectedSegmentIndex = _softKeyboardGestureSelector.selectedSegmentIndex-1;
    }
    for (NSInteger i = 0; i < _softKeyboardGestureSelector.numberOfSegments; i++) {
        [_softKeyboardGestureSelector setEnabled:![self isCustomOswEnabled] || i == 3 ? true : i+3 != oswLayoutFingers forSegmentAtIndex:i]; // 或 NO 来禁用
    }
}

- (void)renderingBackendChanged:(UISegmentedControl *)sender {
    // Disable PiP toggle when Metal renderer is selected
    if (sender.selectedSegmentIndex == RENDER_METAL) {
        // Performance mode (Metal renderer) selected - disable PiP
        [self.pipSwitch setOn:NO animated:YES];
        [self.pipSwitch setEnabled:NO];
        // Set pacing method to Queue and disable selector
        self.framePacingModeSelector.selectedSegmentIndex = FramePacingModeQueue;
        [self.framePacingModeSelector setEnabled:NO];
        // [self setHidden:true forStack:self.frameQueueSizeStack];
        [self setHidden:true forStack:self.interpolationLevelStack];
        [self setHidden:true forStack:self.streamDimensionScaleStack];
    } else {
        // Balanced mode (AVSB renderer) - enable PiP toggle if iOS 15+
        if (@available(iOS 15.0, *)) {
            [self.pipSwitch setEnabled:YES];
        } else {
            [self.pipSwitch setOn:NO];
            [self.pipSwitch setEnabled:NO];
        }
        [self.framePacingModeSelector setEnabled:YES];
        [self setHidden:self.framePacingModeSelector.selectedSegmentIndex != FramePacingModeQueue forStack:self.frameQueueSizeStack];
        [self setHidden:self.framePacingModeSelector.selectedSegmentIndex != FramePacingModeInterpolation forStack:self.interpolationLevelStack];
        [self setHidden:self.framePacingModeSelector.selectedSegmentIndex != FramePacingModeInterpolation forStack:self.streamDimensionScaleStack];
        [self widget:self.frameQueueSizeSlider setEnabled:true];
    }

    // Get the current settings to compare with the new selection
    NSInteger previousBackend = [tempSettings.renderingBackend integerValue];

    // Check if the rendering backend has actually changed
    if (previousBackend != sender.selectedSegmentIndex) {
        // The renderer is picked up fresh at every stream start, so the change takes
        // effect on the next session — no app restart needed.
        void (^applyChange)(void) = ^{
            Settings* directSettings = [self->dataMan retrieveSettings];
            directSettings.renderingBackend = [NSNumber numberWithInteger:sender.selectedSegmentIndex];
            [self->dataMan saveData];
            [self saveSettings];
        };

        void (^revertChange)(void) = ^{
            self.renderingBackendSelector.selectedSegmentIndex = previousBackend;
            [self.renderingBackendSelector sendActionsForControlEvents:UIControlEventValueChanged];
        };

        if (sender.selectedSegmentIndex == RENDER_METAL) {
            // Metal is experimental: confirm its caveats before applying
            NSString *message = [LocalizationHelper localizedStringForKey:@"metalRenderTip"];

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Enable Metal Renderer?"]
                                                                                     message:message
                                                                              preferredStyle:UIAlertControllerStyleAlert];

            [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Apply"]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
                applyChange();
            }]];

            [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Learn More"]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
                revertChange();
                NSURL *url = [NSURL URLWithString:[LocalizationHelper localizedStringForKey:@"betterPerformanceLink"]];
                if ([[UIApplication sharedApplication] canOpenURL:url]) {
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                }
            }]];

            [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"]
                                                                style:UIAlertActionStyleCancel
                                                              handler:^(UIAlertAction * _Nonnull action) {
                revertChange();
            }]];

            [self presentViewController:alertController animated:YES completion:nil];
        } else {
            // Switching back to the standard renderer needs no confirmation
            applyChange();
        }
    }
}

- (void)framePacingModeChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == FramePacingModeInterpolation) {
        if (@available(iOS 26.0, tvOS 26.0, *)) {
            if (!FrameInterpolator.deviceSupportsInterpolation) {
                return;
            }
        }
        else {
            return;
        }
    }

    // Hide frame queue size for Off and Legacy modes
    [GenericUtils handleLegacyFramePacingTipIn:self with:sender passAlert:settingsViewJustExpanded uiAction:^{
        [self setHidden:(sender.selectedSegmentIndex != FramePacingModeQueue
                         || self->_mainFrameViewController.isStreaming) forStack:self.frameQueueSizeStack];
        // [self setHidden:(sender.selectedSegmentIndex != FramePacingModeQueue) forStack:self.frameTimebaseStack];
        [self setHidden:((sender.selectedSegmentIndex != FramePacingModeQueue
                        && sender.selectedSegmentIndex != FramePacingModeInterpolation)
                        || self.renderingBackendSelector.selectedSegmentIndex != 0) forStack:self.asyncFrameDequeueStack];

        if(sender.selectedSegmentIndex == FramePacingModeOff || sender.selectedSegmentIndex == FramePacingModeLegacy){
            [self.enableGraphsSwitch setOn:NO];
            [self findDynamicLabelFromStack:self->_graphOpacityStack].hidden = YES;
        }
        [self.enableGraphsSwitch setEnabled:sender.selectedSegmentIndex == FramePacingModeQueue];
        [self.graphOpacityStepper setEnabled:self.enableGraphsSwitch.isOn];
        [self setHidden:(sender.selectedSegmentIndex == FramePacingModeOff || sender.selectedSegmentIndex == FramePacingModeLegacy) forStack:self.performanceGraphStack];
        
        bool enableInterpolation = sender.selectedSegmentIndex == FramePacingModeInterpolation;
        [self setHidden:!enableInterpolation forStack:self.interpolationLevelStack];
        [self setHidden:!enableInterpolation || self->_mainFrameViewController.isStreaming forStack:self.streamDimensionScaleStack];
        [self widget:self.frameQueueSizeSlider setEnabled:!enableInterpolation];
        [self updateResolutionDisplayLabel];
        if(enableInterpolation){
            if(self.framerateSelector.selectedSegmentIndex == 2) self.framerateSelector.selectedSegmentIndex = 1;
            if(!FrameInterpolator.dimensionLimitsAreKnown){
                NSLog(@"FrameInterpolator dimensionLimitsUnknown");
            }
            if(!self->settingsViewJustExpanded){
                [GenericUtils handleFrameInterpolationPixelFormatTipIn:self];
            }
        }
    }];
    
    /*
    if (sender.selectedSegmentIndex == FramePacingModeLegacy) {
        // Legacy mode selected - disable frames to buffer and graph settings
        [self.frameQueueSizeSlider setEnabled:NO];
        [self.enableGraphsSwitch setOn:NO animated:YES];

        [self.enableGraphsSwitch setEnabled:NO];
        [self.graphOpacityStepper setEnabled:NO];
    } else {
        // Queue mode selected - enable frames to buffer and graph settings
        [self.frameQueueSizeSlider setEnabled:YES];
        [self.enableGraphsSwitch setEnabled:YES];

        if (self.enableGraphsSwitch.isOn) {
            [self.graphOpacityStepper setEnabled:YES];
        }
    }*/
}

- (void)framePacingModeSelectorTapped:(UITapGestureRecognizer *)recognizer {
    UISegmentedControl *selector = (UISegmentedControl *)recognizer.view;
    if (selector.numberOfSegments == 0) {
        return;
    }

    CGFloat segmentWidth = CGRectGetWidth(selector.bounds) / selector.numberOfSegments;
    NSInteger visualIndex = MIN((NSInteger)([recognizer locationInView:selector].x / segmentWidth),
                                selector.numberOfSegments - 1);
    NSInteger segmentIndex = selector.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft
        ? selector.numberOfSegments - visualIndex - 1
        : visualIndex;
    if (segmentIndex != FramePacingModeInterpolation) {
        return;
    }

    [GenericUtils handleFrameInterpolationAvailabilityTipIn:self];
}

- (void)onScreenWidgetChanged{
    self.layoutOnScreenControlsVC = [self instantiateOscLayoutViewController];
    
    bool customOscEnabled = [self isCustomOswEnabled];
    // NSLog(@"customOscEnabled %d", customOscEnabled);
    UILabel* oswDynamicLabel = [self findDynamicLabelFromStack:self.onScreenWidgetStack];
    NSString* labelText = customOscEnabled ? [LocalizationHelper localizedStringForKey:@"%d finger tap", self->oswLayoutFingers] : @"";
    oswDynamicLabel.text = [NSString stringWithFormat:@"  %@  ", labelText];
    oswDynamicLabel.hidden = !customOscEnabled;
    // NSLog(@"oswDynamicLabel.hidden %d", oswDynamicLabel.hidden);
    [self handleOswGestureChange];
    if(customOscEnabled && !settingsViewJustLoaded && !self.mainFrameViewController.settingsExpandedInStreamView) {
        // [self.keyboardToggleFingerNumSlider setValue:3.0];
        // [self keyboardToggleFingerNumSliderMoved];
      [self showCustomOswTip];
    }
}

- (void)gyroSourceChanged:(UISegmentedControl* )sender{
    [self setHidden:sender.selectedSegmentIndex != 1 forStack:_swapYawAndRollStack];
}

- (void)mapGyroToChanged:(UISegmentedControl* )sender{
    // [self setHidden:sender.selectedSegmentIndex != mapGyroToControllerStick forStack:_gyroToStickSwitchStack];
    bool mapGyroToMouseEnabled = sender.selectedSegmentIndex == mapGyroToMouse;
    bool mapGyroToControllerStickEnabled = sender.selectedSegmentIndex == mapGyroToControllerStick;
    if(mapGyroToMouseEnabled){
        [self setHidden:false forStack:_yawPitchSensitivityStack];
        [self setHidden:true forStack:_rollSensitivityStack];
    }
    [self setHidden:!mapGyroToControllerStickEnabled forStack:_gyroToStickSwitchStack];
    [self setHidden:!mapGyroToControllerStickEnabled forStack:self.gyroToStickMinOffsetStack];
    [self setHidden:!mapGyroToControllerStickEnabled forStack:self.synthPhysicalInputStack];

    if(mapGyroToControllerStickEnabled){
        [self.yawPitchToRightStickSwitch sendActionsForControlEvents:UIControlEventValueChanged];
        [self.rollToLeftStickSwitch sendActionsForControlEvents:UIControlEventValueChanged];
    }
    
    if(sender.selectedSegmentIndex == driftCorrection){

        [AlertControllerUtil showAlertIn:self
                                        title:[LocalizationHelper localizedStringForKey:@"Drift Correction"]
                                      message:[LocalizationHelper localizedStringForKey:@"Place the device flat on a surface and keep it still, then tap ‘Start’."]
                                   withCancel:YES
                                  buttonTitle:[LocalizationHelper localizedStringForKey:@"Start"]
                                    countdown:0
                                       action:^{}
                                   completion:^{
            if(AlertControllerUtil.actionCancelled){
                self.mapGyroToSelector.selectedSegmentIndex = self->oscProfile.mapGyroTo;
                [self mapGyroToChanged:self.mapGyroToSelector];
            }
            else{
                MotionHandler* motionHandler = [MotionHandler sharedWithProfile:nil];
                [motionHandler calibrateGyroBiasWithDuration:5 completion:^{
                    Settings* currentSettings = [self->dataMan retrieveSettings];
                    if(self.gyroSourceSelector.selectedSegmentIndex == 0){
                        currentSettings.gyroBiasX = [NSNumber numberWithDouble:motionHandler.gyroBiasX];
                        currentSettings.gyroBiasY = [NSNumber numberWithDouble:motionHandler.gyroBiasY];
                        currentSettings.gyroBiasZ = [NSNumber numberWithDouble:motionHandler.gyroBiasZ];
                    }
                    else{
                        currentSettings.controllerGyroBiasX = [NSNumber numberWithDouble:motionHandler.controllerGyroBiasX];
                        currentSettings.controllerGyroBiasY = [NSNumber numberWithDouble:motionHandler.controllerGyroBiasY];
                        currentSettings.controllerGyroBiasZ = [NSNumber numberWithDouble:motionHandler.controllerGyroBiasZ];
                    }
                    [self->dataMan saveData];
                }];
                [AlertControllerUtil.alertController dismissViewControllerAnimated:true completion:^{
                    [AlertControllerUtil showAlertIn:self
                                                    title:[LocalizationHelper localizedStringForKey:@"Drift Correction"]
                                                  message:[LocalizationHelper localizedStringForKey:@"Calibrating..."]
                                               withCancel:NO
                                              buttonTitle:[LocalizationHelper localizedStringForKey:@"Finished!"]
                                                countdown:6
                                                   action:^{}
                                               completion:^{
                        self.mapGyroToSelector.selectedSegmentIndex = self->oscProfile.mapGyroTo;
                        [self.mapGyroToSelector sendActionsForControlEvents:UIControlEventValueChanged];
                    }];
                }];
            }
        }];
    }
}

- (void)controllerGyroSwitchModeChanged:(UISegmentedControl* )sender{
    [self setHidden:sender.selectedSegmentIndex==ControllerGyroSwitchDisabled forStack:self.reverseHoldButtonStack];
    
    UILabel* tipLabel = [self findDynamicLabelFromStack:self.controllerGyroSwitchButtonStack];
    if(sender.selectedSegmentIndex == ControllerGyroSwitchDisabled){
        tipLabel.text = @"";
    }
    else{
        __block bool switchButtonCaptured = false;
        oscProfile = [oscProfileMan getSelectedProfile];

        [AlertControllerUtil showAlertIn:self
                                    title:[LocalizationHelper localizedStringForKey:@"Gyro button on controller"]
                                 message:sender.selectedSegmentIndex == ControllerGyroSwitchPressToToggle ? [LocalizationHelper localizedStringForKey:@"Press a button for switching gyro on & off with a press.\nYou can have 2 buttons for both press-toggle & hold-down switch."] : [LocalizationHelper localizedStringForKey:@"Press a button for keeping gyro active by holding down.\nYou can have 2 buttons for both press-toggle & hold-down switch."]
                              withCancel:NO
                             buttonTitle:sender.selectedSegmentIndex == ControllerGyroSwitchPressToToggle ? [LocalizationHelper localizedStringForKey:@"Disable press-toggle button"] : [LocalizationHelper localizedStringForKey:@"Disable hold-down button"]
                                countdown:0
                                   action:^{
            
            UIAlertAction* confirmAction = AlertControllerUtil.alertController.actions.firstObject;

            self->capturedController = [GCController controllers].firstObject;
            if(self->capturedController){
                __weak typeof(self) weakSelf = self;
                                
                [ControllerUtil listenWithController:self->capturedController swapABXY:false handler:^(NSDictionary * elementDict, GCExtendedGamepad * gamepad, GCControllerElement * element) {
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self) return;
                    for(NSNumber* elementEnumInstance in elementDict){
                        GCControllerElement * element = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if (![element isKindOfClass:[GCControllerButtonInput class]]) continue;

                        GCControllerButtonInput * button = (GCControllerButtonInput *)element;
                        if(button.isPressed){
                            if(sender.selectedSegmentIndex == ControllerGyroSwitchPressToToggle) self->oscProfile.controllerGyroSwitchToggle = elementEnumInstance.intValue;
                            if(sender.selectedSegmentIndex == ControllerGyroSwitchHoldDown) self->oscProfile.controllerGyroSwitchHold = elementEnumInstance.intValue;
                            
                            switchButtonCaptured = true;
                        
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Finished"];
                            for(UIAlertAction* action in AlertControllerUtil.alertController.actions) {
                                action.enabled = false;
                            }
                            gamepad.valueChangedHandler = nil;
                            if(confirmAction) [confirmAction setValue:[LocalizationHelper localizedStringForKey:@"OK"] forKey:@"title"];
                            [self->oscProfileMan replaceSelectedProfileWith:self->oscProfile overwriteDefault:true];
                            
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                [AlertControllerUtil.alertController dismissViewControllerAnimated:NO completion:nil];
                                if(AlertControllerUtil.completion) AlertControllerUtil.completion();
                            });
                        }
                    }
                }];
            }
            else{
                [AlertControllerUtil.alertController dismissViewControllerAnimated:NO completion:^{
                    [AlertControllerUtil showAlertIn:self
                                                title:[LocalizationHelper localizedStringForKey:@""]
                                              message:[LocalizationHelper localizedStringForKey:@"Waiting for controller..."]
                                           withCancel:YES
                                          buttonTitle:[LocalizationHelper localizedStringForKey:@"Continue"]
                                            countdown:3
                                              action:^{}
                                          completion:^{
                        if(AlertControllerUtil.actionCancelled){
                            self.controllerGyroSwitchButtonSetter.selectedSegmentIndex = self->oscProfile.controllerGyroSwitchMode;
                            [self setHidden:self.controllerGyroSwitchButtonSetter.selectedSegmentIndex==ControllerGyroSwitchDisabled forStack:self.reverseHoldButtonStack];
                            return;
                        }
                        [AlertControllerUtil.alertController dismissViewControllerAnimated:NO completion:^{}];
                        [self.controllerGyroSwitchButtonSetter sendActionsForControlEvents:UIControlEventValueChanged];
                    }];
                }];
            }
        }
                                   completion:^{
            if(!switchButtonCaptured){
                if(sender.selectedSegmentIndex == ControllerGyroSwitchPressToToggle) self->oscProfile.controllerGyroSwitchToggle = ControllerElementNull;
                if(sender.selectedSegmentIndex == ControllerGyroSwitchHoldDown) self->oscProfile.controllerGyroSwitchHold = ControllerElementNull;
                [self->oscProfileMan replaceSelectedProfileWith:self->oscProfile overwriteDefault:true];
            }
            
            bool noSwitchButtonSet = self->oscProfile.controllerGyroSwitchHold == ControllerElementNull && self->oscProfile.controllerGyroSwitchToggle == ControllerElementNull;
            bool duplicatedButtons = self->oscProfile.controllerGyroSwitchHold == self->oscProfile.controllerGyroSwitchToggle && self->oscProfile.controllerGyroSwitchToggle != ControllerElementNull;
            bool bothButtonsSet = self->oscProfile.controllerGyroSwitchHold != ControllerElementNull && self->oscProfile.controllerGyroSwitchToggle != ControllerElementNull && !duplicatedButtons;
            tipLabel.text = @"";
            if(bothButtonsSet) tipLabel.text = [LocalizationHelper localizedStringForKey:@" both set "];
            if(duplicatedButtons){
                sender.selectedSegmentIndex = ControllerGyroSwitchDisabled;
                tipLabel.text = [LocalizationHelper localizedStringForKey:@" duplicated ! "];
                [self->oscProfileMan replaceSelectedProfileWith:self->oscProfile overwriteDefault:true];
            }
            if(noSwitchButtonSet) sender.selectedSegmentIndex = ControllerGyroSwitchDisabled;
            if(!noSwitchButtonSet && !bothButtonsSet && !duplicatedButtons){
                sender.selectedSegmentIndex = self->oscProfile.controllerGyroSwitchToggle != ControllerElementNull ? ControllerGyroSwitchPressToToggle : ControllerGyroSwitchHoldDown;
            }
            
            [self setHidden:sender.selectedSegmentIndex==ControllerGyroSwitchDisabled forStack:self.reverseHoldButtonStack];
            
            if(self->capturedController && self->capturedController.extendedGamepad) self->capturedController.extendedGamepad.valueChangedHandler = nil;
        }];
    }
}

- (void)controllerNavigationSwitchFlipped:(UISwitch* )sender{
    
    [self setHidden:!sender.isOn forStack:_streamingRadialMenuDelayStack];
    [self setHidden:!sender.isOn forStack:_controllerMouseVelocityStack];
    [self setHidden:!sender.isOn forStack:_controllerMouseExpoStack];
    if(!sender.isOn || settingsViewJustLoaded) return;
    [self.swapAbxySwitch setOn:false]; // swapAbxy can be enabled after mouse to controller is set
    __block bool localRadialMenuButtonCaptured = false;
    __block bool streamingRadialMenuButtonCaptured = false;
    __block bool previousTriggerPressed = false;
    __block bool stickCaptured = false;
    __block bool leftButtonCaptured = false;
    __block bool rightButtonCaptured = false;
    __block bool metRadialButtonWithUndefinedPosition = false;
    __block NSMutableSet *capturedButtons = [NSMutableSet new];
    Settings* currentSettings = [dataMan retrieveSettings];
    [AlertControllerUtil showAlertIn:self
                                title:[LocalizationHelper localizedStringForKey:@"Controller Navigation"]
                              message:[LocalizationHelper localizedStringForKey:@"radialMenuButtonTip"]
                           withCancel:NO
                          buttonTitle:@""
                            countdown:0
                               action:^{
        self->capturedController = [GCController controllers].firstObject;
        if(self->capturedController){
            __weak typeof(self) weakSelf = self;
            
            if (@available(iOS 14.0, tvOS 14.0, *)) {
                for (GCControllerElement* element in self->capturedController.physicalInputProfile.allElements) {
                    element.preferredSystemGestureState = GCSystemGestureStateDisabled;
                }
            }
            
            [ControllerUtil stopListeningPrimaryControllerWithStopListenToRadialMenuButton:true];

            [ControllerUtil listenWithController:self->capturedController swapABXY:false handler:^(NSDictionary * elementDict, GCExtendedGamepad * gamepad, GCControllerElement * element) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                
                if(!localRadialMenuButtonCaptured){
                    for(NSNumber* elementEnumInstance in elementDict){
                        if (@available(iOS 13.0, *)) if(![ControllerNavigator.radialMenuButtonPool containsObject:elementEnumInstance]) continue;
                        GCControllerElement * element = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if (![element isKindOfClass:[GCControllerButtonInput class]]) continue;
                        GCControllerButtonInput * button = (GCControllerButtonInput *)element;
                        if(button.isPressed){
                            currentSettings.localRadialMenuButton = elementEnumInstance;
                            [capturedButtons addObject:elementEnumInstance];
                            ControllerElementPosition position = [ControllerUtil positionFor:(ControllerElement)currentSettings.localRadialMenuButton.intValue];
                            metRadialButtonWithUndefinedPosition = position == ControllerElementPositionUndefined || position == ControllerElementPositionMiddle;
                            localRadialMenuButtonCaptured = true;
                            if(button == gamepad.leftTrigger || button == gamepad.rightTrigger) previousTriggerPressed = true;
                            if(metRadialButtonWithUndefinedPosition) {
                                AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Which side of the controller is this button on?"];
                                if (@available(iOS 13.0, *)) [ControllerNavigator updateHudForCustomRadialMenuButtonPosition];
                                return;
                            }
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"streamingRadialMenuButtonTip"];
                            
                            return;
                        }
                        else if(button == gamepad.leftTrigger || button == gamepad.rightTrigger) previousTriggerPressed = false;
                    }
                }
                
                if(metRadialButtonWithUndefinedPosition && localRadialMenuButtonCaptured && !streamingRadialMenuButtonCaptured){
                    for(NSNumber* elementEnumInstance in elementDict){
                        GCControllerElement * element = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if (![element isKindOfClass:[GCControllerButtonInput class]]) continue;
                        GCControllerButtonInput * button = (GCControllerButtonInput *)element;
                        if(button.isPressed){
                            switch (elementEnumInstance.intValue) {
                                case ControllerElementDpadLeft:
                                    currentSettings.customLocalRadialMenuButtonPosition = @(ControllerElementPositionLeft);
                                    metRadialButtonWithUndefinedPosition = false;
                                    break;
                                case ControllerElementDpadRight:
                                    currentSettings.customLocalRadialMenuButtonPosition = @(ControllerElementPositionRight);
                                    metRadialButtonWithUndefinedPosition = false;
                                    break;
                                case ControllerElementDpadUp:
                                    currentSettings.customLocalRadialMenuButtonPosition = @(ControllerElementPositionMiddle);
                                    metRadialButtonWithUndefinedPosition = false;
                                    break;
                                default:
                                    break;
                            }
                            
                            if(!metRadialButtonWithUndefinedPosition){
                                if (@available(iOS 13.0, *)) [GamepadNavigationIllustrationHud clearHud];
                                AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"streamingRadialMenuButtonTip"];
                                return;
                            }
                        }
                    }
                }
                
                if(!streamingRadialMenuButtonCaptured && localRadialMenuButtonCaptured && !metRadialButtonWithUndefinedPosition){
                    for(NSNumber* elementEnumInstance in elementDict){
                        if (@available(iOS 13.0, *)) if(![ControllerNavigator.radialMenuButtonPool containsObject:elementEnumInstance]) continue;
                        GCControllerElement * element = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if (![element isKindOfClass:[GCControllerButtonInput class]]) continue;
                        GCControllerButtonInput * button = (GCControllerButtonInput *)element;
                        if(button == gamepad.leftTrigger || button == gamepad.rightTrigger) {
                            if(button.isPressed == previousTriggerPressed) continue;
                        }
                        if(button.isPressed){
                            currentSettings.streamingRadialMenuButton = elementEnumInstance;
                            [capturedButtons addObject:elementEnumInstance];
                            streamingRadialMenuButtonCaptured = true;
                            ControllerElementPosition position = [ControllerUtil positionFor:(ControllerElement)currentSettings.streamingRadialMenuButton.intValue];
                            metRadialButtonWithUndefinedPosition = currentSettings.streamingRadialMenuButton.intValue != currentSettings.localRadialMenuButton.intValue && (position == ControllerElementPositionUndefined || position == ControllerElementPositionMiddle);
                            if(currentSettings.streamingRadialMenuButton.intValue == currentSettings.localRadialMenuButton.intValue) currentSettings.customStreamingRadialMenuButtonPosition = currentSettings.customLocalRadialMenuButtonPosition;
                            if(metRadialButtonWithUndefinedPosition) {
                                AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Which side of the controller is this button on?"];
                                if (@available(iOS 13.0, *)) [ControllerNavigator updateHudForCustomRadialMenuButtonPosition];
                                return;
                            }
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Move the stick you want to use for mouse control. The other stick will be used for vertical and horizontal scrolling"];
                            return;
                        }
                    }
                }
                
                if(metRadialButtonWithUndefinedPosition && streamingRadialMenuButtonCaptured && localRadialMenuButtonCaptured){
                    for(NSNumber* elementEnumInstance in elementDict){
                        GCControllerElement * element = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if (![element isKindOfClass:[GCControllerButtonInput class]]) continue;
                        GCControllerButtonInput * button = (GCControllerButtonInput *)element;
                        if(button.isPressed){
                            switch (elementEnumInstance.intValue) {
                                case ControllerElementDpadLeft:
                                    currentSettings.customStreamingRadialMenuButtonPosition = @(ControllerElementPositionLeft);
                                    metRadialButtonWithUndefinedPosition = false;
                                    break;
                                case ControllerElementDpadRight:
                                    currentSettings.customStreamingRadialMenuButtonPosition = @(ControllerElementPositionRight);
                                    metRadialButtonWithUndefinedPosition = false;
                                    break;
                                case ControllerElementDpadUp:
                                    currentSettings.customStreamingRadialMenuButtonPosition = @(ControllerElementPositionMiddle);
                                    metRadialButtonWithUndefinedPosition = false;
                                    break;
                                default:
                                    break;
                            }
                            if(!metRadialButtonWithUndefinedPosition){
                                if (@available(iOS 13.0, *)) [GamepadNavigationIllustrationHud clearHud];
                                AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Move the stick you want to use for mouse control. The other stick will be used for vertical and horizontal scrolling"];
                                return;
                            }
                        }
                    }
                }
                                
                
                if(!stickCaptured && streamingRadialMenuButtonCaptured && !metRadialButtonWithUndefinedPosition){
                    float leftStickOffset = hypotf(gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value);
                    float rightStickOffset = hypotf(gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value);
                    if(leftStickOffset>0.1||rightStickOffset>0.1){
                        ControllerElement stick = leftStickOffset>rightStickOffset ? ControllerElementLeftStick : ControllerElementRightStick;
                        currentSettings.controllerMouseStick = @(stick);
                        stickCaptured = true;
                        AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Press the button for mouse left button"];
                        return;
                    }
                }
                
                    
            
                if(!leftButtonCaptured && stickCaptured){
                    for(NSNumber* elementEnumInstance in elementDict){
                        GCControllerElement * element = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if (![element isKindOfClass:[GCControllerButtonInput class]]) continue;
                        GCControllerButtonInput * button = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if(button.isPressed && ![capturedButtons containsObject:elementEnumInstance]){
                            currentSettings.controllerMouseLeftButton = elementEnumInstance;
                            [capturedButtons addObject:elementEnumInstance];
                            leftButtonCaptured = true;
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Press the button for mouse right button"];
                            return;
                        }
                    }
                }

                if(!rightButtonCaptured && leftButtonCaptured){
                    for(NSNumber* elementEnumInstance in elementDict){
                        GCControllerElement * element = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if (![element isKindOfClass:[GCControllerButtonInput class]]) continue;
                        GCControllerButtonInput * button = (GCControllerButtonInput *)elementDict[elementEnumInstance];
                        if(button.isPressed && ![capturedButtons containsObject:elementEnumInstance]){
                            currentSettings.controllerMouseRightButton = elementEnumInstance;
                            [capturedButtons addObject:elementEnumInstance];
                            rightButtonCaptured = true;
                            
                            if (@available(iOS 13.0, *)) {
                                // NSLog(@"custom posistion local %d , stream: %d", currentSettings.customLocalRadialMenuButtonPosition.intValue, currentSettings.customStreamingRadialMenuButtonPosition.intValue);
                                
                                ControllerNavigator.localRadialMenuButton = (ControllerElement)currentSettings.localRadialMenuButton.intValue;
                                ControllerNavigator.customPositionForLocalRadialMenuButton = (ControllerElementPosition)currentSettings.customLocalRadialMenuButtonPosition.intValue;
                                ControllerNavigator.streamingRadialMenuButton = (ControllerElement)currentSettings.streamingRadialMenuButton.intValue;
                                ControllerNavigator.customPositionForStreamingRadialMenuButton = (ControllerElementPosition)currentSettings.customStreamingRadialMenuButtonPosition.intValue;
                                ControllerNavigator.streamingRadialMenuDelay = (NSTimeInterval)currentSettings.streamingRadialMenuDelay.floatValue;
                                ControllerNavigator.enabled = true;
                                [ControllerNavigator setUINavigationDelegate:self];
                                // ControllerNavigator.controllerMouseStick = (ControllerElement)currentSettings.controllerMouseStick.intValue;
                                // ControllerNavigator.controllerMouseLeftButton = (ControllerElement)currentSettings.controllerMouseLeftButton.intValue;
                                // ControllerNavigator.controllerMouseRightButton = (ControllerElement)currentSettings.controllerMouseRightButton.intValue;
                                // ControllerNavigator.controllerMouseExpo = currentSettings.controllerMouseExpo.floatValue;
                            }
                            
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Finished"];
                            gamepad.valueChangedHandler = nil;
                            // deprecated:
                            UIAlertAction* cancelAction = AlertControllerUtil.alertController.actions.firstObject;
                            if(cancelAction) [cancelAction setValue:[LocalizationHelper localizedStringForKey:@"OK"] forKey:@"title"];
                            //
                            [self->dataMan saveData];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                if (@available(iOS 13.0, *)) [ControllerNavigator restartListening];
                                [AlertControllerUtil.alertController dismissViewControllerAnimated:NO completion:nil];
                            });
                        }
                    }
                }
            }];
        }
        else{
            [AlertControllerUtil.alertController dismissViewControllerAnimated:NO completion:^{
                [AlertControllerUtil showAlertIn:self
                                            title:[LocalizationHelper localizedStringForKey:@""]
                                          message:[LocalizationHelper localizedStringForKey:@"Waiting for controller..."]
                                       withCancel:YES
                                      buttonTitle:[LocalizationHelper localizedStringForKey:@"Continue"]
                                        countdown:3
                                          action:^{}
                                      completion:^{
                    if(AlertControllerUtil.actionCancelled){
                        [self.controllerNavigationSwitch setOn:NO];
                        [self.controllerNavigationSwitch sendActionsForControlEvents:UIControlEventValueChanged];
                        return;
                    }
                    [AlertControllerUtil.alertController dismissViewControllerAnimated:NO completion:^{}];
                    [self.controllerNavigationSwitch sendActionsForControlEvents:UIControlEventValueChanged];
                }];
            }];
        }
    }
                               completion:^{
        if(AlertControllerUtil.actionCancelled){
            if(!rightButtonCaptured){
                [self.controllerNavigationSwitch setOn:rightButtonCaptured];
                [self.controllerNavigationSwitch sendActionsForControlEvents:UIControlEventValueChanged];
            }
            if(self->capturedController && self->capturedController.extendedGamepad) self->capturedController.extendedGamepad.valueChangedHandler = nil;
        }
    }];
}

- (void)rollToLeftStickSwitchFlipped:(UISwitch* )sender{
    [self setHidden:!sender.isOn forStack:_rollSensitivityStack];
}

- (void)yawPitchToRightStickSwitchFlipped:(UISwitch* )sender{
    [self setHidden:!sender.isOn forStack:_yawPitchSensitivityStack];
}

- (void)yawSensitivitySliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:_yawSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (int16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]];
    [_pitchSensitivitySlider setValue:sender.value];
    [_pitchSensitivitySlider sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)pitchSensitivitySliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:_pitchSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (int16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]];
}

- (void)rollSensitivitySliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ", (int16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]];
}

- (void)gyroMinStickOffsetSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d  ", (int16_t)sender.value];
    if(settingsViewJustExpanded) return;
    LiSendControllerEvent(0, 0, 0, _rollToLeftStickSwitch.isOn?sender.value:0, 0, _yawPitchToRightStickSwitch.isOn?sender.value:0, 0);
    ControllerUtil.gamepadArrivalReported = true;
}

- (void)leftStickMinOffsetSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d  ", (int16_t)sender.value];
    if(settingsViewJustExpanded) return;
    LiSendControllerEvent(0, 0, 0, sender.value, 0, 0, 0);
    ControllerUtil.gamepadArrivalReported = true;
}

- (void)rightStickMinOffsetSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d  ", (int16_t)sender.value];
    if(settingsViewJustExpanded) return;
    LiSendControllerEvent(0, 0, 0, 0, 0, sender.value, 0);
    ControllerUtil.gamepadArrivalReported = true;
}

- (void) pointerVelocityModeDividerSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  | %d%% | %d%% |  ", (uint8_t)sender.value, 100-(uint8_t)sender.value];
    bool hasNoPresentedVC = self.presentedViewController == nil && self.view.window != nil;
    if (@available(iOS 13.0, *)) if(!settingsViewJustExpanded && hasNoPresentedVC) {
        [self showTouchVelocityPreviewWithDividerPercent:sender.value
                                         velocityPercent:[self map_velocFactorDisplay_fromSliderValue:self.touchPointerVelocityFactorSlider.value]];
    }
}

- (void) touchPointerVelocityFactorSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]]; // Update label display
    bool hasNoPresentedVC = self.presentedViewController == nil && self.view.window != nil;
    if (@available(iOS 13.0, *)) if(!settingsViewJustExpanded && hasNoPresentedVC) {
        [self showTouchVelocityPreviewWithDividerPercent:self.pointerVelocityModeDividerSlider.value
                                         velocityPercent:[self map_velocFactorDisplay_fromSliderValue:sender.value]];
    }
}

- (void)dualSenseTransientSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %.2f  ", sender.value]; // Update label display
    ControllerUtil.dualSenseHapticTransient = sender.value;
}

- (void) gyroSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)sender.value]; // Update label display
}

- (void)emulatedGyroModeChanged:(UISegmentedControl* )sender {
    if(sender.selectedSegmentIndex == GyroModeOff) return;
    [GenericUtils handleEmulatedGyroModeTipIn:self];
}

- (void) localVolumeSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)sender.value]; // Update label display
    if(_mainFrameViewController.settingsExpandedInStreamView) [Connection setVolume:sender.value/100];
}

- (void) micVolumeSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)sender.value]; // Update label display
    if(_mainFrameViewController.settingsExpandedInStreamView) [MicHandler setVolume:sender.value/100];
}

- (void) backgroundSessionTimerSliderMoved:(UISlider* )sender {
    NSString* labelString;
    labelString = [LocalizationHelper localizedStringForKey:@"  keep %d min  ", (uint16_t)sender.value];
    if(sender.value == 0) labelString = [LocalizationHelper localizedStringForKey:@"  disconnect  "];
    if(sender.value == sender.maximumValue) labelString = [LocalizationHelper localizedStringForKey:@"  keep alive  "];
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = labelString; // Update label display
}

- (void)appThemeChanged:(UISegmentedControl* )sender{
    [ThemeManager setUserInterfaceStyle:sender.selectedSegmentIndex];
    Settings* currentSettings = [self->dataMan retrieveSettings];
    currentSettings.appTheme = @(sender.selectedSegmentIndex);
    [dataMan saveData];
}

// veloc factor upto 700%
- (CGFloat) map_velocFactorDisplay_fromSliderValue:(CGFloat)sliderValue{
    CGFloat velocFactorDisplay = 0;
    if(sliderValue > 200) velocFactorDisplay = 200 + ((uint16_t)sliderValue % 200) * 5;
    else velocFactorDisplay = sliderValue;
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
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ",(uint16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]];
}

- (void) singleTapSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %.1f  ",sender.value];
}

- (void) scrollSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)(sender.value*100)];
}

- (void) pinchSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)(sender.value*100)];
}

- (void) relativeTouchSlideThresholdSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@" %.1f ",sender.value];
}

- (void) controllerMouseVelocitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %.1f  ", sender.value];
}

- (void) streamingRadialMenuDelaySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %.1f s  ", sender.value];
}

- (void) controllerMouseExpoSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %.1f  ", sender.value];
    if (@available(iOS 13.0, *)) if(!settingsViewJustLoaded) {
        [self showControllerMouseCurvePreviewWithExpo:sender.value];
    }
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

// a setEnabled method for low iOS version UISlider
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
    bool isNativeTouch = self.touchModeSelector.selectedSegmentIndex == NativeTouchOnly || self.touchModeSelector.selectedSegmentIndex == NativeTouch;
    bool asyncNativeTouchEnabled = self.asyncNativeTouchPrioritySelector.selectedSegmentIndex != AsyncNativeTouchOff;
    [self widget:self.touchMoveEventIntervalSlider setEnabled:isNativeTouch && asyncNativeTouchEnabled];
}
*/

- (void)touchMode2Changed:(UISegmentedControl* )sender {
    // [UIView animateWithDuration:0 animations:^{
        self.touchModeSelector1.selectedSegmentIndex =  sender.selectedSegmentIndex;
    // } completion:^(BOOL finished) {
        // 动画完成时执行的代码
        [self touchModeChanged:sender];
    // }];
}

- (void)touchMode1Changed:(UISegmentedControl* )sender {
    [GenericUtils handleTouchModeChangingTipIn:self];
    self.touchModeSelector2.selectedSegmentIndex = sender.selectedSegmentIndex;
    [self touchModeChanged:sender];
}

- (void)touchModeChanged:(UISegmentedControl* )sender {
    // Disable On-Screen Controls & Widgets in non-relative touch mode
    // bool customOscEnabled = [self isOswEnabled] && self.onScreenWidgetSelector.selectedSegmentIndex == OnScreenControlsLevelCustom;
    
    bool isNativeTouch = sender.selectedSegmentIndex == NativeTouch;
    // bool isEgmerging = self.enableOswSwitchStack.hidden != !isNativeTouch && isNativeTouch;
    bool isEgmerging = false;
    // self.enableOswSwitchStack.hidden = !isNativeTouch;
    // self.enableOswSwitchStack.hidden = true;
    // if(isEgmerging) [self highlightEmergingStack:self.enableOswSwitchStack];

    
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityDividerStack];

    // [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityFactorStack];
    // [self setHidden:!isNativeTouch forStack:self.touchMoveEventIntervalStack];

    /*
    [self setHidden:(sender.selectedSegmentIndex!=RelativeTouch
                     && sender.selectedSegmentIndex!=AbsoluteTouch) forStack:self.pinchGestureStack];
    [self setHidden:(sender.selectedSegmentIndex!=RelativeTouch
                     && sender.selectedSegmentIndex!=AbsoluteTouch) forStack:self.scrollSensitivityStack];*/
    
    [self setHidden:sender.selectedSegmentIndex!=AbsoluteTouch forStack:self.passthroughGesturesStack];
    UISwitch* dummySwitch = [[UISwitch alloc] init];
    [dummySwitch setOn:(sender.selectedSegmentIndex==RelativeTouch
                        || (sender.selectedSegmentIndex==AbsoluteTouch && _passthroughGesturesSwitch.isOn))];
    [self.passthroughGesturesSwitch sendActionsForControlEvents:UIControlEventValueChanged];
    
    /*
    [self setHidden:((sender.selectedSegmentIndex!=RelativeTouch
                     && sender.selectedSegmentIndex!=AbsoluteTouch)
                     || !_pinchGestureSwitch.isOn) forStack:self.pinchSensitivityStack];
    [self setHidden:((sender.selectedSegmentIndex!=RelativeTouch
                     && sender.selectedSegmentIndex!=AbsoluteTouch)
                     || !_pinchGestureSwitch.isOn) forStack:self.ctrlDownForPinchStack];*/
    
    [self setHidden:sender.selectedSegmentIndex!=AbsoluteTouch forStack:self.leftClickDelayStack];

    [self setHidden:sender.selectedSegmentIndex!=RelativeTouch forStack:self.mousePointerVelocityStack];
    [self setHidden:sender.selectedSegmentIndex!=RelativeTouch forStack:self.singleTapSensitivityStack];
    [self setHidden:sender.selectedSegmentIndex!=RelativeTouch forStack:self.relativeTouchSlideThresholdStack];
    [self setHidden:false forStack:self.onScreenWidgetStack];
    [self setHidden:false forStack:self.buttonVisualFeedbackStack];
    [self setHidden:sender.selectedSegmentIndex!=AbsoluteTouch forStack:self.delayLeftClickStack];
    
    
    bool gesturePassthroughUnavailable = sender.selectedSegmentIndex==NativeTouch
    || sender.selectedSegmentIndex==TouchDisabled
    || (sender.selectedSegmentIndex==AbsoluteTouch && !_passthroughGesturesSwitch.isOn);
    
    [self setHidden:gesturePassthroughUnavailable forStack:self.pinchGestureStack];
    [self setHidden:gesturePassthroughUnavailable forStack:self.scrollSensitivityStack];

    [self setHidden:gesturePassthroughUnavailable
     || !_pinchGestureSwitch.isOn
    forStack:self.ctrlDownForPinchStack];
    [self setHidden:gesturePassthroughUnavailable
     || !_pinchGestureSwitch.isOn
    forStack:self.pinchSensitivityStack];

    [self handleOswGestureChange];
}

- (void)emulatedControllerTypeChanged:(UISegmentedControl* )sender{
    [self setHidden:sender.selectedSegmentIndex == 0 forStack:_gyroModeStack];
    [self setHidden:sender.selectedSegmentIndex == 0 forStack:_gyroSensitivityStack];
    [self setHidden:sender.selectedSegmentIndex != 2 forStack:_dualSenseTransientStack];

    if(settingsViewJustExpanded) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [GenericUtils handleControllerEmulationTipIn:self];
    });
}


- (void)setHidden:(BOOL)hidden forStack:(UIStackView* )stack{
    // CGFloat previousSpacing = stack.spacing;
    if(!stack) return;
    if(hidden){
        stack.hidden = YES;
        [self->hiddenStacks addObject:stack];
        if(!settingsViewJustLoaded){ // when settingsViewJustLoaded is true, height will be updated somewhere else
            UIView* superView = stack.superview;
            while(superView){
                if([superView isKindOfClass:[MenuSectionView class]]){
                    MenuSectionView* section = (MenuSectionView* ) superView;
                    [section updateViewForFoldState];
                    break;
                }
                superView = superView.superview;
            }
        }
    }
    else{
        stack.hidden = NO;
        if(!settingsViewJustLoaded){
            UIView* superView = stack.superview;
            while(superView){
                if([superView isKindOfClass:[MenuSectionView class]]){
                    MenuSectionView* section = (MenuSectionView* ) superView;
                    [section updateViewForFoldState];
                    break;
                }
                superView = superView.superview;
            }
            if([hiddenStacks containsObject:stack]) [self highlightEmergingStack:stack];
        }
        [hiddenStacks removeObject:stack];
    }
}

- (void)passthroughGesturesSwitchFlipped:(UISwitch* )sender{
    [self setHidden:!sender.isOn forStack:_pinchGestureStack];
    [self setHidden:!sender.isOn forStack:_scrollSensitivityStack];
    if(!sender.isOn) [self.pinchGestureSwitch sendActionsForControlEvents:UIControlEventValueChanged];
    else [_pinchGestureSwitch sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)softKeyboardHeightSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        GenericUtils.autoPopSoftKeyboard = false;
        [GenericUtils setVerticalScaleWithView:self.view show:true];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@""]
                                                                                 message:[LocalizationHelper localizedStringForKey:@"Enter the relative height of the soft keyboard according to the scale (make sure app is in landscape fullscreen mode):"]
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = [LocalizationHelper localizedStringForKey:@"e.g. 0.45"];
            textField.keyboardType = UIKeyboardTypeASCIICapable;
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
            textField.spellCheckingType = UITextSpellCheckingTypeNo;
            textField.delegate = self;
            textField.text = self->softKeyboardHeight == 0 ? nil : [NSString stringWithFormat:@"%.2f", self->softKeyboardHeight];
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"]
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {
            [GenericUtils setVerticalScaleWithView:self.view show:false];
            [sender setOn:self->softKeyboardHeight!=0];
        }];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
            self->softKeyboardHeight = [PublicUtils toCGFloat:alertController.textFields[0].text];
            [GenericUtils setVerticalScaleWithView:self.view show:false];
            [sender setOn:self->softKeyboardHeight!=0];
        }];
        [alertController addAction:cancelAction];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}


- (void)pinchGestureSwitchFlipped:(UISwitch* )sender{
    [self setHidden:!sender.isOn forStack:_pinchSensitivityStack];
    [self setHidden:!sender.isOn forStack:_ctrlDownForPinchStack];
}

- (void)highlightEmergingStack:(UIStackView* )stack{
    [self highlightedBackgroundForView:stack animateWithDuration:0.2 completion:^{
        [self clearBackgroundColorForView:stack animateWithDuration:0.2];
    }];
}

- (void)muteInBackgroundSwitchFlipped:(UISwitch* )sender{
    Connection.muteInBackground = sender.isOn;
    // [VideoDecoderRenderer setFrameInterpolationEnabled:sender.isOn];
}

- (void)redirectMicSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn) [self checkAndRequestMicPermission];
    [self setHidden:!sender.isOn forStack:_useBuiltinMicStack];
    [self setHidden:!sender.isOn forStack:_micVolumeStack];
}

- (void)rememberFoldStateSwitchFlipped:(UISwitch* )sender{
    MenuSectionView.overridePersistedFoldState = !sender.isOn;
    Settings* currentSettings = [self->dataMan retrieveSettings];
    currentSettings.rememberFoldState = sender.isOn;
    [self->dataMan saveData];
}

- (void)enableOswForNativeTouchSwitchFlipped:(UISwitch *)sender{
    if(!settingsViewJustLoaded
       && sender.isOn==false
       && [GenericUtils isEnableOswForNativeTouchSwitchFirstFlipping]){
        [AlertControllerUtil showAlertIn:self
                                   title:[LocalizationHelper localizedStringForKey:@"Tips"]
                                 message:[LocalizationHelper localizedStringForKey:@"enableOswForNativeTouchSwitchTip"]
                              withCancel:NO
                             buttonTitle:[LocalizationHelper localizedStringForKey:@"This tip won't be shown again"]
                               countdown:6
                                  action:nil
                              completion:^{
            [self setHidden:!sender.isOn forStack:self.onScreenWidgetStack];
            [self setHidden:!sender.isOn forStack:self.buttonVisualFeedbackStack];
            [self handleOswGestureChange];
            if(!sender.isOn) self.onScreenWidgetSelector.selectedSegmentIndex = OnScreenControlsLevelOff;
        }];
    }
    
    [self setHidden:!sender.isOn forStack:self.onScreenWidgetStack];
    [self setHidden:!sender.isOn forStack:self.buttonVisualFeedbackStack];
    [self handleOswGestureChange];
    if(!sender.isOn) self.onScreenWidgetSelector.selectedSegmentIndex = OnScreenControlsLevelOff;
}

- (void)trackTouchPointSwitchFlipped:(UISwitch *)sender{
    OnScreenWidgetView.trackPointEnabled = sender.isOn;
}

- (BOOL)manuallyChangedFPS {
    NSString *key = @"manuallyChangedFPS";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:key] ? [defaults boolForKey:key] : NO;
}

- (void)framerateChanged{
    NSString *key = @"manuallyChangedFPS";
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if(self.framerateSelector.selectedSegmentIndex == self.framerateSelector.numberOfSegments - 1
       && self.framePacingModeSelector.selectedSegmentIndex == FramePacingModeInterpolation) self.framerateSelector.selectedSegmentIndex = self.framerateSelector.previousSelectedSegmentIndex;
    
    // NSInteger fps = [self getChosenFrameRate];
    // [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];
    [self updateBitrate];
}

- (void) updateBitrate {
    NSInteger fps = [self getChosenFrameRate];
    CMVideoDimensions dimensions = [self getChosenStreamDimensions];
    NSInteger width = dimensions.width;
    NSInteger height = dimensions.height;
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
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:NO];
    
    [self updateBitrateText];
}

- (void) newResolutionChosen {
    _lastSelectedResolutionIndex = self.resolutionSelector.selectedSegmentIndex;
    if (self.mainFrameViewController.settingsExpandedInStreamView) {
        [self updateResolutionDisplayLabel];
    } else {
        [self updateResolutionTable];
    }
    [self updateBitrate];
}

- (void)customResolutionSwitched:(UISwitch* )sender{
    if(sender.isOn) [self promptCustomResolutionDialog];
    else [self newResolutionChosen];
    [self.resolutionSelector setEnabled:!sender.isOn];
}

- (void) promptCustomResolutionDialog {
    GenericUtils.autoPopSoftKeyboard = !PublicUtils.isIPhone;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey: @"Enter Custom Resolution"] message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Video Width"];
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.delegate = self;
        
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
        textField.delegate = self;
        
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
            self.resolutionSelector.selectedSegmentIndex = self->_lastSelectedResolutionIndex;
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

        resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX] = (CMVideoDimensions){
            .width = (int32_t)width,
            .height = (int32_t)height,
        };
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
    CMVideoDimensions dimensions = [self getChosenPresetStreamDimensions];
    NSInteger width = dimensions.width;
    NSInteger height = dimensions.height;
    
    [self findDynamicLabelFromStack:_resolutionSelectorStack].text = [NSString stringWithFormat:@"%ld × %ld", (long)width, (long)height];
    if (self.interpolationLevelSlider != nil) {
        [self.interpolationLevelSlider sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

- (void)updateInterpolationLevelSliderWithMaximumDimension:(NSInteger)savedMaximumDimension {
    self.interpolationLevelSlider.minimumValue = 0;
    self.interpolationLevelSlider.maximumValue = 1;
    self.interpolationLevelSlider.value = [FrameInterpolator
        interpolationLevelForDimensions:[self getChosenPresetStreamDimensions]
        savedMaximumDimension:savedMaximumDimension];
    [self.interpolationLevelSlider sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)interpolationLevelSliderMoved:(UISlider *)sender {
    InterpolationResolutionConfiguration *configuration = [self getCurrentInterpolationResolutionConfiguration];
    [self findDynamicLabelFromStack:self.interpolationLevelStack].text =
        [NSString stringWithFormat:@"  %d × %d  ", configuration.dimensions.width, configuration.dimensions.height];
    if (self.streamDimensionScaleSlider != nil) {
        [self.streamDimensionScaleSlider sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

- (void)interpolationLevelSliderInteractionEnded:(UISlider *)sender {
    [GenericUtils handleFrameInterpolationResolutionTipIn:self];
}


- (InterpolationResolutionConfiguration *)getCurrentInterpolationResolutionConfiguration {
    return [FrameInterpolator
        resolutionConfigurationForDimensions:[self getChosenPresetStreamDimensions]
        level:self.interpolationLevelSlider.value];
}

- (void)streamDimensionScaleSliderMoved:(UISlider *)sender {
    CMVideoDimensions dimensions = [self getChosenStreamDimensions];
    [self findDynamicLabelFromStack:self.streamDimensionScaleStack].text =
        [NSString stringWithFormat:@"  %d × %d  ", dimensions.width, dimensions.height];
}

- (void) touchMoveEventIntervalSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = sender.enabled ?
    [NSString stringWithFormat:@"  %d μs  ", (uint16_t)self.touchMoveEventIntervalSlider.value] : @"";
}

- (void) leftClickDelaySliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d ms  ", (uint16_t)sender.value];
}

- (void) slideToMenuDistanceSliderMoved:(UISlider* )sender{
    UILabel* displayLabel = [self findDynamicLabelFromStack:(UIStackView*)sender.superview];
    // displayLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    NSString* labelText = [LocalizationHelper localizedStringForKey:@"    %d%% screen width", (uint8_t)(sender.value * 100)];
    displayLabel.text = [NSString stringWithFormat:@"  %@  ", labelText];
}

- (void) edgeSlidingSensitivitySliderMoved:(UISlider* )sender{
    UILabel* displayLabel = [self findDynamicLabelFromStack:(UIStackView*)sender.superview];
    // displayLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    NSString* labelText = [LocalizationHelper localizedStringForKey:@"  %d  ", (uint8_t)sender.value];
    displayLabel.text = [NSString stringWithFormat:@"  %@  ", labelText];
}


- (void) bitrateSliderMoved {
    assert(self.bitrateSlider.value < (sizeof(bitrateTable) / sizeof(*bitrateTable)));
    _bitrate = bitrateTable[(int)self.bitrateSlider.value];
    [self updateBitrateText];
    [self updateResolutionDisplayLabel];
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
    switch (self.framerateSelector.selectedSegmentIndex) {
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
        switch (self.codecSelector.selectedSegmentIndex) {
            case 0:
                return CODEC_PREF_H264;
            case 1:
                return CODEC_PREF_HEVC;
            case 2:
                return CODEC_PREF_AV1;
            default:
                return VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) ? CODEC_PREF_HEVC : CODEC_PREF_H264;
        }
}

- (CMVideoDimensions)getChosenPresetStreamDimensions {
    // because the 4k resolution can be removed
    CMVideoDimensions originalDimensions;
    if (self.customResolutionSwitch.isOn) {
        originalDimensions = resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX];
    } else {
        originalDimensions = resolutionTable[self.resolutionSelector.selectedSegmentIndex];
    }
    
    if(originalDimensions.width == 0 || originalDimensions.height == 0) {
        originalDimensions.width = tempSettings.width.intValue;
        originalDimensions.height = tempSettings.height.intValue;
    }
    
    /*
    CMVideoDimensions targetDimensions = self.framePacingModeSelector.selectedSegmentIndex == FramePacingModeInterpolation
        ? [FrameInterpolator interpolatableDimensionsBy:originalDimensions]
        : originalDimensions;
    
    if(targetDimensions.width == 0 || targetDimensions.height == 0) {
        targetDimensions = [FrameInterpolator interpolatableDimensionsBy720p:originalDimensions];
    }
    
    NSLog(@"dimensions: %d, %d", targetDimensions.width, targetDimensions.height);
    */
    
    return originalDimensions;
}

- (CMVideoDimensions)getChosenStreamDimensions {
    CMVideoDimensions presetDimensions = [self getChosenPresetStreamDimensions];
    if (self.framePacingModeSelector.selectedSegmentIndex != FramePacingModeInterpolation) return presetDimensions;
    if (self.streamDimensionScaleSlider == nil) {
        return [FrameInterpolator
            scaledStreamDimensionsWithPresetDimensions:presetDimensions
            interpolationDimensions:presetDimensions
            scale:1];
    }

    InterpolationResolutionConfiguration *configuration = [self getCurrentInterpolationResolutionConfiguration];
    return [FrameInterpolator
        scaledStreamDimensionsWithPresetDimensions:presetDimensions
        interpolationDimensions:configuration.dimensions
        scale:self.streamDimensionScaleSlider.value];
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
                label.textColor = [UIColor clearColor];
                label.textColor = ThemeManager.textColor;
            } else {
                UIView *view = label;
                bool isPartOfSelector = false;
                while (view) {
                    if ([view isKindOfClass:[UISegmentedControl class]]) {
                        isPartOfSelector = true;
                        break;
                    }
                    view = view.superview;
                }
                if(!isPartOfSelector) label.textColor = [UIColor whiteColor];
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
                selector.selectedSegmentTintColor = [UIColor clearColor];
                selector.selectedSegmentTintColor = ThemeManager.appSecondaryColor;
            } else {
                selector.tintColor = ThemeManager.appSecondaryColor;
            }
        }
        [self updateThemeForSelectors:subview];
    }
}

- (void)updateThemeForSliders:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UISlider class]]) {
            UISlider *slider = (UISlider *)subview;
            slider.tintColor = [UIColor clearColor];
            slider.tintColor = ThemeManager.appSecondaryColor;
            if(PublicUtils.liquidGlassEnabled) slider.maximumTrackTintColor = ThemeManager.liquidGlassSliderMaxTrackTint;
        }
        [self updateThemeForSliders:subview];
    }
}

- (void)updateThemeForSwitches:(UIView *)view {
    if (@available(iOS 26.0, *)) {
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:[UISwitch class]]) {
                UISwitch *uiSwitch = (UISwitch *)subview;
                [GenericUtils applyOffTintColor:uiSwitch];
            }
            [self updateThemeForSwitches:subview];
        }
    }
}

- (void)updateThemeForMenuSections:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[MenuSectionView class]]) {
            MenuSectionView *section = (MenuSectionView *)subview;
            section.titleLabel.textColor = ThemeManager.sectionLabelTextColor;
            section.iconImageView.tintColor = [UIColor clearColor];
            section.iconImageView.tintColor = ThemeManager.sectionLabelTextColor;
            section.separatorLine.backgroundColor = [UIColor clearColor];
            section.separatorLine.backgroundColor = ThemeManager.separatorColor;
        }
        [self updateThemeForMenuSections:subview];
    }
}


- (void) frameQueueSizeSliderMoved:(UISlider* )sender {
    assert(self.frameQueueSizeSlider.value >= 0 && self.frameQueueSizeSlider.value <= 5);
    int queueSize = self.frameQueueSizeSlider.value;
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = queueSize==0 ? [LocalizationHelper localizedStringForKey:@"lowest latency"] : [NSString stringWithFormat: @"  %d  ", queueSize];
}

- (void) enableGraphsChanged:(UISwitch* )sender {
    [self.graphOpacityStepper setEnabled:sender.isOn];
    [self findDynamicLabelFromStack:self.graphOpacityStack].hidden = !sender.isOn;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@"Tips"] message: [LocalizationHelper localizedStringForKey:@"This is an experimental feature that may cause stuttering or freezing in the stream view."] preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                           style:UIAlertActionStyleDefault
                                                     handler:nil];
    [alertController addAction:okAction];
    
    if(sender.isOn && !settingsViewJustLoaded) [self presentViewController:alertController animated:YES completion:nil];
}

- (void) graphOpacityStepperTapped:(UIStepper* )sender {
    assert(self.graphOpacityStepper.value >= 0 && sender.value <= 100);
    [self findDynamicLabelFromStack:_graphOpacityStack].text = [LocalizationHelper localizedStringForKey:@"  %d%% opacity  ",(int)sender.value];
}

- (void)preSavingActions{
    if(self.mainFrameViewController.isStreaming){
        [self.mainFrameViewController requestForBitrate:(uint32_t)_bitrate];
    }
    
    if(![MicHandler permissionGranted]) [self.redirectMicSwitch setOn:false];
    
    [self saveGameProfileConfigsUIKit];
    
    if (@available(iOS 13.0, *)) if(!self.controllerNavigationSwitch.isOn) ControllerNavigator.enabled = false;
}

- (void)pencilTickModeChanged:(UISegmentedControl* )sender{
    [self setHidden:sender.selectedSegmentIndex != ManualTick forStack:self.pencilTickIntervalStack];
    
    if(settingsViewJustExpanded) return;
    
    if(sender.selectedSegmentIndex != ManualTick) return;
    [IAPManager checkPurchaseInfo:AddOnProductPencilProPack completion:^(PurchaseInfo* info) {
        if(!info.valid){
            [IAPManager inAppPurchaseActionWithViewController:self product:AddOnProductPencilProPack];
        }
    }];
}

- (void)pencilProPurchaseAborted:(NSNotification *)notification{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.pencilTickSelector.selectedSegmentIndex = PencilTickDisabled;
        [self.pencilTickSelector sendActionsForControlEvents:UIControlEventValueChanged];
        [self.pressureCurveSwitch setOn:false];
        [self.doubleTapShortcutSwitch setOn:false];
        [self.squeezeShortcutSwitch setOn:false];
        [self.pencilPausesNativeTouchSwitch setOn:false];
        [self.disablePencilSlideGestureSwitch setOn:false];
        [self.pencilTipOffsetSwitch setOn:false];
        
        
        NSNumber *value = notification.userInfo[@"interruption"];
        if (!value) return;

        PurchaseInterruption interruption = value.intValue;

        if(interruption == PurchaseInterruptionLowOSVersion){
            [AlertControllerUtil showAlertIn:self
                                       title:@""
                                     message:[LocalizationHelper localizedStringForKey:@"PencilProPackLowOSVersionTip"]
                                  withCancel:NO
                                 buttonTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                   countdown:0
                                      action:nil
                                  completion:nil];
        }
    });
}

- (void)pencilProPurchaseSucceeded:(NSNotification *)notification{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onScreenWidgetSelector.selectedSegmentIndex = OnScreenControlsLevelCustom;
        self.pencilTickSelector.selectedSegmentIndex = ManualTick;
    });
}

- (void)pencilTickIntervalSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:(UIStackView*)sender.superview].text = [NSString stringWithFormat:@"  %d μs  ", (uint16_t)sender.value];
}

- (void)pressureCurveSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        PressureCurveViewController* pressureCurveVC = [[PressureCurveViewController alloc] init];
        pressureCurveVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.definesPresentationContext = true;
        [self presentViewController:pressureCurveVC animated:YES completion:nil];
    }
}

- (void)pencilTipOffsetSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        PencilTipOffsetCalibrationViewController* calibrationVC = [[PencilTipOffsetCalibrationViewController alloc] init];
        calibrationVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.definesPresentationContext = true;
        [self presentViewController:calibrationVC animated:YES completion:nil];
    }
}

- (void)doubleTapShortcutSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        [IAPManager checkPurchaseInfo:AddOnProductPencilProPack completion:^(PurchaseInfo* info) {
            if(info.valid) [PencilHandler enterDoubleTapShortcutsIn:self];
            else {
                [IAPManager inAppPurchaseActionWithViewController:self product:AddOnProductPencilProPack];
            }
        }];
    }
}

- (void)squeezeShortcutSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        [IAPManager checkPurchaseInfo:AddOnProductPencilProPack completion:^(PurchaseInfo* info) {
            if(info.valid) [PencilHandler enterSqueezeShortcutsIn:self];
            else {
                [IAPManager inAppPurchaseActionWithViewController:self product:AddOnProductPencilProPack];
            }
        }];
    }
}

- (void)disablePencilSlideGestureSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        [IAPManager checkPurchaseInfo:AddOnProductPencilProPack completion:^(PurchaseInfo* info) {
            if(info.valid) nil;
            else {
                [IAPManager inAppPurchaseActionWithViewController:self product:AddOnProductPencilProPack];
            }
        }];
    }
}

- (void)pencilPausesNativeTouchSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        [IAPManager checkPurchaseInfo:AddOnProductPencilProPack completion:^(PurchaseInfo* info) {
            if(info.valid) nil;
            else {
                [IAPManager inAppPurchaseActionWithViewController:self product:AddOnProductPencilProPack];
            }
        }];
    }
}

- (void)widgetPickerViewController:(WidgetPickerViewController *)controller didCreateWidget:(NSDictionary *)payload API_AVAILABLE(ios(13.0)){
    OSCProfilesManager * profileMan = [OSCProfilesManager sharedManager:CGRectZero];
    OSCProfile* profile = [profileMan getSelectedProfile];
    NSString* shortcutIdentifier = [payload objectForKey:@"shortcutIdentifier"];

    if([shortcutIdentifier isEqualToString:@"eraser"]) {
        profile.eraserShortcut = [payload objectForKey:@"cmdString"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [PencilHandler enterBrushShortcutIn:self];
        });
    }
    if([shortcutIdentifier isEqualToString:@"brush"]) {
        profile.brushShortcut = [payload objectForKey:@"cmdString"];
    }
    if([shortcutIdentifier isEqualToString:@"squeezePress"]) {
        profile.squeezeStartShortcut = [payload objectForKey:@"cmdString"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [PencilHandler enterSqueezeEndShortcutIn:self];
        });
    }
    if([shortcutIdentifier isEqualToString:@"squeezeRelease"]) {
        profile.squeezeEndShortcut = [payload objectForKey:@"cmdString"];
    }
    
    [profileMan replaceSelectedProfileWith:profile overwriteDefault:true];
}

/*
- (void)autoHoverSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        [IAPManager checkPurchaseInfo:AddOnProductPencilProPack completion:^(PurchaseInfo* info) {
            if(info.valid) nil;
            else {
                [IAPManager inAppPurchaseActionWithViewController:self product:AddOnProductPencilProPack];
            }
        }];
    }
}
*/

- (void)loadPencilSettings:(TemporarySettings*) tempSettings{
    if([PublicUtils isIPad]){
        self.pencilTickSelector.selectedSegmentIndex = tempSettings.pencilTickMode.intValue;
        [self.pencilTickSelector addTarget:self action:@selector(pencilTickModeChanged:) forControlEvents:UIControlEventValueChanged];
        [self.pencilTickSelector sendActionsForControlEvents:UIControlEventValueChanged];
                
        [self.pencilTickIntervalSlider setValue:tempSettings.pencilTickIntervalUs.floatValue];
        [self.pencilTickIntervalSlider addTarget:self action:@selector(pencilTickIntervalSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.pencilTickIntervalSlider sendActionsForControlEvents:UIControlEventValueChanged];
        
        [self.pencilTipOffsetSwitch setOn:(fabs(tempSettings.pencilTipOffsetX.floatValue) > 0.01 || fabs(tempSettings.pencilTipOffsetY.floatValue) > 0.01)];
        [self.pencilTipOffsetSwitch addTarget:self action:@selector(pencilTipOffsetSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        
        [self.pressureCurveSwitch addTarget:self action:@selector(pressureCurveSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self.doubleTapShortcutSwitch addTarget:self action:@selector(doubleTapShortcutSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        
        [self.squeezeShortcutSwitch addTarget:self action:@selector(squeezeShortcutSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        if (@available(iOS 17.5, *)) nil;
        else [self.squeezeShortcutSwitch setEnabled:false];
        
        [self.disablePencilSlideGestureSwitch addTarget:self action:@selector(disablePencilSlideGestureSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self.pencilPausesNativeTouchSwitch addTarget:self action:@selector(pencilPausesNativeTouchSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        // [self.autoHoverTerminationSwitch addTarget:self action:@selector(autoHoverSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
    }
}

- (void)populatePencilSettings:(Settings*)currentSettings{
    if([PublicUtils isIPad]){
        currentSettings.pencilTickMode = @(self.pencilTickSelector.selectedSegmentIndex);
        currentSettings.pencilTickIntervalUs = @(self.pencilTickIntervalSlider.value);
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}

- (void)codecSelectorChanged:(UISegmentedControl *)sender {
    [self updateCodecDependentSwitches];
}

- (void)updateCodecDependentSwitches {
    uint32_t codec = [self getChosenCodecPreference];
    BOOL isAV1 = (codec == CODEC_PREF_AV1);
    BOOL isH264 = (codec == CODEC_PREF_H264);
    BOOL isHEVC = (codec == CODEC_PREF_HEVC);
    
    if (isAV1) {
        // AV1 must use limited range, so disable fullRange and turn it off
        [self.fullColorRangeSwitch setOn:NO animated:NO];
        [self.fullColorRangeSwitch setEnabled:NO];

        // AV1 doesn't support YUV444, so disable it and turn it off
        [self.yuv444Switch setOn:NO animated:NO];
        [self.yuv444Switch setEnabled:NO];
    } else {
        [self.fullColorRangeSwitch setEnabled:YES];
        [self.fullColorRangeSwitch setOn:YES];
        [self.yuv444Switch setEnabled:YES];
    }
    
    if(isHEVC || isH264) [self.fullColorRangeSwitch setOn:YES animated:NO];

    // H264 doesn't support HDR, so disable it and turn it off
    if (isH264) {
        [self.hdrSwitch setOn:NO animated:NO];
        [self.hdrSwitch setEnabled:NO];
    } else {
        // Only enable HDR if the device supports it
        if ([Utils hdrSupported]) {
            [self.hdrSwitch setEnabled:YES];
        }
    }
    
    if(![Utils hdrSupported]) [self.hdrSwitch setOn:NO animated:NO];
}
#endif

@end
