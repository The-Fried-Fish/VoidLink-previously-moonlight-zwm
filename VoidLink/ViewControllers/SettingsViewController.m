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
#import "TemporarySettings.h"
#import "DataManager.h"
#import "ThemeManager.h"
#import "Connection.h"
#import "Plot.h"
#import "OSCProfilesManager.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

#import "LocalizationHelper.h"

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
    bool settingsViewJustLoaded;
    bool settingsViewJustExpanded;
    bool settingsViewAlreadyAppeared;
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
    MenuSectionView *touchControlSection;
    MenuSectionView *controllerSection;
    MenuSectionView *motionControlSection;
    MenuSectionView *videoSection;
    MenuSectionView *otherSection;
    MenuSectionView *experimentalSection;
    NSMutableSet* hiddenStacks;
    
    GCController *capturedController;
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


- (void)micHandlerDidFinishPlayback:(MicHandler *)handler {
    NSLog(@"Playback finished");
}

- (void)micHandler:(MicHandler *)handler didFailWithError:(NSError *)error {
    NSLog(@"Mic error: %@", error);
}

- (void)reloadGameProfileConfigs{
    oscProfile = [oscProfileMan getSelectedProfile];

    self.controllerGyroSwitchButtonSetter.selectedSegmentIndex = oscProfile.controllerGyroSwitchMode;
    if(self.controllerGyroSwitchButtonSetter.selectedSegmentIndex != ControllerGyroSwitchDisabled){
        bool bothButtonsSet = oscProfile.controllerGyroSwitchHold != ControllerButtonNull && oscProfile.controllerGyroSwitchToggle != ControllerButtonNull;
        [self findDynamicLabelFromStack:self.controllerGyroSwitchButtonStack].text = bothButtonsSet ? [LocalizationHelper localizedStringForKey:@" both set "] : @"";
    }
    [self setHidden:oscProfile.controllerGyroSwitchMode==ControllerGyroSwitchDisabled forStack:self.reverseHoldButtonStack];
    
    [self.reverseHoldButtonSwitch setOn:oscProfile.reverseGyroHoldButton];

    [self.mapGyroToSelector setSelectedSegmentIndex:oscProfile.mapGyroTo];
    [self mapGyroToChanged:self.mapGyroToSelector];
    
    [self.yawPitchToRightStickSwitch setOn:oscProfile.yawPitchToRightStick];
    [self.rollToLeftStickSwitch setOn:oscProfile.rollToLeftStick];
    
    if(self.mapGyroToSelector.selectedSegmentIndex == mapGyroToControllerStick){
        [self yawPitchToRightStickSwitchFlipped:self.yawPitchToRightStickSwitch];
        [self rollToLeftStickSwitchFlipped:self.rollToLeftStickSwitch];
    }
    
    [self.yawSensitivitySlider setValue:[self map_SliderValue_fromVelocFactor:oscProfile.gyroSensitivityYaw]];
    [self yawSensitivitySliderMoved:self.yawSensitivitySlider];
    [self.pitchSensitivitySlider setValue:[self map_SliderValue_fromVelocFactor:oscProfile.gyroSensitivityPitch]];
    [self pitchSensitivitySliderMoved:self.pitchSensitivitySlider];
    [self.rollSensitivitySlider setValue:[self map_SliderValue_fromVelocFactor:oscProfile.gyroSensitivityRoll]];
    [self rollSensitivitySliderMoved:self.rollSensitivitySlider];
    [self.gyroToStickMinOffsetSlider setValue:(uint16_t)oscProfile.gyroToStickMinOffset];
    [self gyroMinStickOffsetSliderMoved:self.gyroToStickMinOffsetSlider];
    
    [self.leftStickMinOffsetSlider setValue:(uint16_t)oscProfile.physicalLeftStickMinOffset];
    [self leftStickMinOffsetSliderMoved:self.leftStickMinOffsetSlider];
    [self.rightStickMinOffsetSlider setValue:(uint16_t)oscProfile.physicalRightStickMinOffset];
    [self rightStickMinOffsetSliderMoved:self.rightStickMinOffsetSlider];
    
    [self.synthPhysicalInputSwitch setOn:oscProfile.synthesizePhysicalStick];
    
    [self.pressureCurveSwitch setOn:oscProfile.pressureCurveEnabled];
    [self.doubleTapShortcutSwitch setOn:oscProfile.doubleTapShorcutEnabled];
    [self.squeezeShortcutSwitch setOn:oscProfile.squeezeShorcutEnabled];
    [self.pencilPausesNativeTouchSwitch setOn:oscProfile.pencilPausesNativeTouch];
    [self.disablePencilSlideGestureSwitch setOn:oscProfile.disablePencilSlideGestures];
    self.hoverModeSelector.selectedSegmentIndex = oscProfile.pencilHoverMode;
}

- (void)saveGameProfileConfigs{
    
    CGFloat yawSensitivityPercent = [self map_velocFactorDisplay_fromSliderValue:self.yawSensitivitySlider.value];
    CGFloat pitchSensitivityPercent = [self map_velocFactorDisplay_fromSliderValue:self.pitchSensitivitySlider.value];
    CGFloat rollSensitivityPercent = [self map_velocFactorDisplay_fromSliderValue:self.rollSensitivitySlider.value];

    bool configNotChanged = (oscProfile.mapGyroTo == self.mapGyroToSelector.selectedSegmentIndex
                             && oscProfile.yawPitchToRightStick == self.yawPitchToRightStickSwitch.isOn
                             && oscProfile.rollToLeftStick == self.rollToLeftStickSwitch.isOn
                             && (int16_t)(oscProfile.gyroSensitivityYaw*100) == (int16_t)yawSensitivityPercent
                             && (int16_t)(oscProfile.gyroSensitivityPitch*100) == (int16_t)pitchSensitivityPercent
                             && (int16_t)(oscProfile.gyroSensitivityRoll*100) == (int16_t)rollSensitivityPercent
                             && (int16_t)(oscProfile.gyroToStickMinOffset) == (int16_t)self.gyroToStickMinOffsetSlider.value
                             && oscProfile.synthesizePhysicalStick == self.synthPhysicalInputSwitch.isOn
                             && oscProfile.controllerGyroSwitchMode == self.controllerGyroSwitchButtonSetter.selectedSegmentIndex
                             && oscProfile.reverseGyroHoldButton == self.reverseHoldButtonSwitch.isOn
                             && (int16_t)(oscProfile.physicalLeftStickMinOffset) == (int16_t)self.leftStickMinOffsetSlider.value
                             && (int16_t)(oscProfile.physicalRightStickMinOffset) == (int16_t)self.rightStickMinOffsetSlider.value
                             && oscProfile.pressureCurveEnabled == self.pressureCurveSwitch.isOn
                             && oscProfile.doubleTapShorcutEnabled == self.doubleTapShortcutSwitch.isOn
                             && oscProfile.squeezeShorcutEnabled == self.squeezeShortcutSwitch.isOn
                             && oscProfile.pencilPausesNativeTouch == self.pencilPausesNativeTouchSwitch.isOn
                             && oscProfile.disablePencilSlideGestures == self.disablePencilSlideGestureSwitch.isOn
                             && oscProfile.pencilHoverMode == self.hoverModeSelector.selectedSegmentIndex
                             );

    if(!configNotChanged){
        oscProfile = [oscProfileMan getSelectedProfile];
        oscProfile.mapGyroTo = self.mapGyroToSelector.selectedSegmentIndex;
        oscProfile.yawPitchToRightStick = self.yawPitchToRightStickSwitch.isOn;
        oscProfile.rollToLeftStick = self.rollToLeftStickSwitch.isOn;
        oscProfile.gyroSensitivityYaw = yawSensitivityPercent/100;
        oscProfile.gyroSensitivityPitch = pitchSensitivityPercent/100;
        oscProfile.gyroSensitivityRoll = rollSensitivityPercent/100;
        oscProfile.gyroToStickMinOffset = (int16_t)self.gyroToStickMinOffsetSlider.value;
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
        oscProfile.pencilHoverMode = self.hoverModeSelector.selectedSegmentIndex;
        [oscProfileMan replaceSelectedProfileWith:oscProfile overwriteDefault:YES];
        if(PencilHandler.shared) [PencilHandler.shared setupPressureLUTWithProfile:oscProfile];
    }
}

- (bool)contentOffsetRestored{
    return fabs(_scrollView.contentOffset.y - tempSettings.settingsMenuOffset.floatValue)<2;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:NO];

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
                                                 name:ThemeDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadGameProfileConfigs)
                                                 name:@"OscLayoutCloseNotification"
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
    
    if(currentSettingsMenuMode == AllSettings && MenuSectionView.overridePersistedFoldState){
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
                [weakSelf.onScreenWidgetSelector setSelectedSegmentIndex:OnScreenControlsLevelCustom];
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
    
    [self reloadGameProfileConfigs];
    
    self->tempSettings = [self->dataMan getSettings];
    
    if(!settingsViewAlreadyAppeared){
        _scrollView.contentOffset = CGPointMake(_scrollView.contentOffset.x, tempSettings.settingsMenuOffset.floatValue);
        _scrollView.hidden = true;
    }
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:NO];
    
    [self updateParentStackHorizontalConstraints];
    
    [self updateResolutionTable];
    
    [self.customResolutionSwitch addTarget:self action:@selector(customResolutionSwitched:) forControlEvents:UIControlEventValueChanged];
    [self.customResolutionSwitch setOn: isCustomResolution(self->tempSettings.resolutionSelected.intValue)];
    [self.resolutionSelector setEnabled:!self.customResolutionSwitch.isOn];
    
    [self touchModeChanged:self.touchModeSelector1]; // a special fix for iOS 14 to set hidden for the "enableOswStack"
    
    if(!settingsViewAlreadyAppeared && ![self contentOffsetRestored]) _scrollView.contentOffset = CGPointMake(_scrollView.contentOffset.x, tempSettings.settingsMenuOffset.floatValue);
    _scrollView.hidden = false;

    settingsViewJustExpanded = false;
    settingsViewAlreadyAppeared = true;
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(OnScreenControls.shared){
        [OnScreenControls.shared clearLeftStickTouchPadFlag];
        [OnScreenControls.shared clearRightStickTouchPadFlag];
    }
    else LiSendControllerEvent(0, 0, 0, 0, 0, 0, 0);
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsViewClosedNotification" object:self]; // notify other view that settings view just closed
    
    bool unlockDisplayOrientationFlipped = tempSettings.unlockDisplayOrientation != (_unlockDisplayOrientationSelector.selectedSegmentIndex == 1);
    if(unlockDisplayOrientationFlipped) [_mainFrameViewController setNeedsUpdateAllowedOrientation]; // handle allow portratit on & off
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

    _parentStack = [[UIStackView alloc] init];
    _parentStack.axis = UILayoutConstraintAxisVertical;
    _parentStack.spacing = 0;
    _parentStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    if(!_parentStack.superview){
        [self.scrollView addSubview:_parentStack];
        [NSLayoutConstraint activateConstraints:@[
            [_parentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant: currentSettingsMenuMode == AllSettings ? [self getStandardNavBarHeight] : [self getStandardNavBarHeight]+10],
            [_parentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-20],
        ]];
    }
    
    [self updateParentStackHorizontalConstraints];
}

-(void)deviceOrientationDidChange:(NSNotification *)notification {
    [self updateParentStackHorizontalConstraints];
}

- (void)updateParentStackHorizontalConstraints{
    if(![self isIPhone]){
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

- (void)addSetting:(UIStackView *)stack ofId:(NSString* )identifier withInfoTag:(BOOL)attached withDynamicLabel:(BOOL)added to:(MenuSectionView* )menuSection{
    stack.accessibilityIdentifier = identifier;
    [_settingStackDict setObject:stack forKey:identifier];
    if(attached) [self attachInfoTagForStack:stack];
    if(added) [self addDynamicLabelForStack:stack];
    [menuSection addSubStackView:stack];
}
    
- (void)layoutSections{
    videoSection = [[MenuSectionView alloc] init];
    videoSection.delegate = self;
    videoSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Video"];
    videoSection.identifier = @"SettingsSectionVideo";
    if (@available(iOS 13.0, *)) {
        [videoSection setSectionWithIcon:[UIImage systemImageNamed:@"waveform"] andSize:20];
    }
    [self addSetting:self.resolutionStack ofId:@"resolutionStack" withInfoTag:NO withDynamicLabel:YES to:videoSection];
    [self addSetting:self.fpsStack ofId:@"fpsStack" withInfoTag:NO withDynamicLabel:NO to:videoSection];
    [self addSetting:self.bitrateStack ofId:@"bitrateStack" withInfoTag:YES withDynamicLabel:YES to:videoSection];
    [self addSetting:self.codecStack ofId:@"codecStack" withInfoTag:NO withDynamicLabel:NO to:videoSection];
    [self addSetting:self.hdrStack ofId:@"hdrStack" withInfoTag:![Utils hdrSupported] withDynamicLabel:NO to:videoSection];
    [self addSetting:self.yuv444Stack ofId:@"yuv444Stack" withInfoTag:YES withDynamicLabel:NO to:videoSection];
    [self addSetting:self.sdrPerformanceWorkaroundStack ofId:@"sdrPerformanceWorkaroundStack" withInfoTag:YES withDynamicLabel:NO to:videoSection];
    [self addSetting:self.framePacingStack ofId:@"framePacingStack" withInfoTag:YES withDynamicLabel:NO to:videoSection];
    [self addSetting:self.frameQueueSizeStack ofId:@"frameQueueSizeStack" withInfoTag:NO withDynamicLabel:YES to:videoSection];
    [videoSection addToParentStack:_parentStack];
    [self addSetting:self.asyncFrameDequeueStack ofId:@"asyncFrameDequeueStack" withInfoTag:YES withDynamicLabel:NO to:videoSection];
    // [videoSection setExpanded:NO];
    [self addSetting:self.pipStack ofId:@"pipStack" withInfoTag:YES withDynamicLabel:NO to:videoSection];

    
    touchControlSection = [[MenuSectionView alloc] init];
    touchControlSection.delegate = self;
    touchControlSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Touch Control"];
    touchControlSection.identifier = @"SettingsSectionTouch&Controller";
    if (@available(iOS 13.0, *)) {
        [touchControlSection setSectionWithIcon:[UIImage imageNamed:@"arcade.stick.console"] andSize:20.5];
    }
    [self addSetting:self.touchModeStack ofId:@"touchModeStack" withInfoTag:YES withDynamicLabel:NO to:touchControlSection];
    [self addSetting:self.mousePointerVelocityStack ofId:@"mousePointerVelocityStack" withInfoTag:NO withDynamicLabel:YES to:touchControlSection];
    [self addSetting:self.pointerVelocityDividerStack ofId:@"pointerVelocityDividerStack" withInfoTag:YES withDynamicLabel:YES to:touchControlSection];
    [self addSetting:self.pointerVelocityFactorStack ofId:@"pointerVelocityFactorStack" withInfoTag:YES withDynamicLabel:YES to:touchControlSection];
    [self addSetting:self.delayLeftClickStack ofId:@"delayLeftClickStack" withInfoTag:YES withDynamicLabel:NO to:touchControlSection];
    [self addSetting:self.passthroughGesturesStack ofId:@"passthroughGesturesStack" withInfoTag:NO withDynamicLabel:NO to:touchControlSection];
    [self addSetting:self.pinchGestureStack ofId:@"pinchGestureStack" withInfoTag:NO withDynamicLabel:NO to:touchControlSection];
    [self addSetting:self.ctrlDownForPinchStack ofId:@"ctrlDownForPinchStack" withInfoTag:YES withDynamicLabel:NO to:touchControlSection];
    [self addSetting:self.scrollSensitivityStack ofId:@"scrollSensitivityStack" withInfoTag:NO withDynamicLabel:YES to:touchControlSection];
    [self addSetting:self.pinchSensitivityStack ofId:@"pinchSensitivityStack" withInfoTag:NO withDynamicLabel:YES to:touchControlSection];
    [self addSetting:self.mousePointerVelocityStack ofId:@"mousePointerVelocityStack" withInfoTag:NO withDynamicLabel:YES to:touchControlSection];
    [self addSetting:self.onScreenWidgetStack ofId:@"onScreenWidgetStack" withInfoTag:YES withDynamicLabel:YES to:touchControlSection];
    [self addSetting:self.buttonVisualFeedbackStack ofId:@"buttonVisualFeedbackStack" withInfoTag:NO withDynamicLabel:NO to:touchControlSection];
    [self addSetting:self.trackTouchPointStack ofId:@"trackTouchPointStack" withInfoTag:NO withDynamicLabel:NO to:touchControlSection];
    [touchControlSection addToParentStack:_parentStack];
    // [touchAndControlSection setExpanded:NO];
    
    controllerSection = [[MenuSectionView alloc] init];
    controllerSection.delegate = self;
    controllerSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Controller"];
    controllerSection.identifier = @"SettingsSectionController";
    if (@available(iOS 13.0, *)) {
        [controllerSection setSectionWithIcon:[UIImage systemImageNamed:@"gamecontroller"] andSize:30];
    }
    [self addSetting:self.swapAbxyStack ofId:@"swapAbaxyStack" withInfoTag:NO withDynamicLabel:NO to:controllerSection];
    [self addSetting:self.hapticEngineStack ofId:@"hapticEngineStack" withInfoTag:NO withDynamicLabel:NO to:controllerSection];
    [self addSetting:self.emulatedControllerTypeStack ofId:@"emulatedControllerTypeStack" withInfoTag:YES withDynamicLabel:NO to:controllerSection];
    [self addSetting:self.gyroModeStack ofId:@"gyroModeStack" withInfoTag:YES withDynamicLabel:YES to:controllerSection];
    [self addSetting:self.gyroSensitivityStack ofId:@"gyroSensitivityStack" withInfoTag:NO withDynamicLabel:YES to:controllerSection];
    [self addSetting:self.leftStickMinOffsetStack ofId:@"leftStickMinOffsetStack" withInfoTag:YES withDynamicLabel:YES to:controllerSection];
    [self addSetting:self.rightStickMinOffsetStack ofId:@"rightStickMinOffsetStack" withInfoTag:YES withDynamicLabel:YES to:controllerSection];
    [self addSetting:self.controllerToMouseStack ofId:@"controllerToMouseStack" withInfoTag:YES withDynamicLabel:YES to:controllerSection];
    [self addSetting:self.controllerMouseVelocityStack ofId:@"controllerMouseVelocityStack" withInfoTag:NO withDynamicLabel:YES to:controllerSection];
    [self addSetting:self.controllerMouseExpoStack ofId:@"controllerMouseExpoStack" withInfoTag:YES withDynamicLabel:YES to:controllerSection];
    [controllerSection addToParentStack:_parentStack];
    
    motionControlSection = [[MenuSectionView alloc] init];
    motionControlSection.delegate = self;
    motionControlSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Motion Control"];
    motionControlSection.identifier = @"SettingsSectionMotionControl";
    if (@available(iOS 13.0, *)) {
        // [motionControlSection setSectionWithIcon:[UIImage imageNamed:@"gyroscope"] andSize:23];
        [motionControlSection setSectionWithIcon:[UIImage imageNamed:@"gyroscope"] andSize:23];
    }
    [self addSetting:self.controllerGyroSwitchButtonStack ofId:@"controllerGyroSwitchButtonStack" withInfoTag:YES withDynamicLabel:YES to:motionControlSection];
    [self addSetting:self.reverseHoldButtonStack ofId:@"reverseHoldButtonStack" withInfoTag:YES withDynamicLabel:YES to:motionControlSection];
    [self addSetting:self.mapGyroToStack ofId:@"mapGyroToStack" withInfoTag:YES withDynamicLabel:NO to:motionControlSection];
    [self addSetting:self.gyroToStickSwitchStack ofId:@"gyroToStickStack" withInfoTag:NO withDynamicLabel:NO to:motionControlSection];
    [self addSetting:self.yawPitchSensitivityStack ofId:@"yawPitchSensitivityStack" withInfoTag:NO withDynamicLabel:NO to:motionControlSection];
    [self addDynamicLabelForStack:self.yawSensitivityStack];
    [self addDynamicLabelForStack:self.pitchSensitivityStack];
    [self addSetting:self.rollSensitivityStack ofId:@"rollSensitivityStack" withInfoTag:NO withDynamicLabel:YES to:motionControlSection];
    [self addSetting:self.gyroToStickMinOffsetStack ofId:@"gyroToStickMinOffsetStack" withInfoTag:NO withDynamicLabel:YES to:motionControlSection];
    [self addSetting:self.synthPhysicalInputStack ofId:@"synthPhysicalInputStack" withInfoTag:NO withDynamicLabel:NO to:motionControlSection];
    [motionControlSection addToParentStack:_parentStack];
    
    
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    bool loadPencilSection = ([bundleId isEqualToString:@"com.voidlink.iOS"]
                              || [bundleId isEqualToString:@"com.voidlinkextreme.iOS"]
                              || [bundleId isEqualToString:@"com.voidlink.tf.debug10.iOS"]);

    if([GenericUtils isIPad] && loadPencilSection){
        MenuSectionView* pencilSection = [[MenuSectionView alloc] init];
        pencilSection.delegate = self;
        pencilSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Drawing Toolkit"];
        pencilSection.identifier = @"SettingsSectionPencil";
        if (@available(iOS 13.0, *)) {
            [pencilSection setSectionWithIcon:[UIImage systemImageNamed:@"pencil.and.outline"] size:19 weight:UIImageSymbolWeightHeavy];
        }
        [self addSetting:self.pencilTickStack ofId:@"pencilTickStack" withInfoTag:YES withDynamicLabel:NO to:pencilSection];
        [self addSetting:self.pencilTickIntervalStack ofId:@"pencilTickIntervalStack" withInfoTag:NO withDynamicLabel:YES to:pencilSection];
        [self addSetting:self.pressureCurveStack ofId:@"pressureCurveStack" withInfoTag:NO withDynamicLabel:NO to:pencilSection];
        [self addSetting:self.doubleTapShortcutStack ofId:@"doubleTapShortcutStack" withInfoTag:YES withDynamicLabel:NO to:pencilSection];
        [self addSetting:self.squeezeShortcutStack ofId:@"squeezeShortcutStack" withInfoTag:YES withDynamicLabel:NO to:pencilSection];
        [self addSetting:self.hoverModeStack ofId:@"hoverModeStack" withInfoTag:YES withDynamicLabel:NO to:pencilSection];
        [self addSetting:self.pencilPausesNativeTouchStack ofId:@"pencilPausesNativeTouchStack" withInfoTag:NO withDynamicLabel:NO to:pencilSection];
        [self addSetting:self.disablePencilSlideGestureStack ofId:@"disablePencilSlideGestureStack" withInfoTag:NO withDynamicLabel:NO to:pencilSection];
        [pencilSection addToParentStack:_parentStack];
    }
    
    
    MenuSectionView *gesturesSection = [[MenuSectionView alloc] init];
    gesturesSection.delegate = self;
    gesturesSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Gestures"];  
    gesturesSection.identifier = @"SettingsSectionGestures";
    if (@available(iOS 13.0, *)) {
        [gesturesSection setSectionWithIcon:[UIImage systemImageNamed:@"hand.draw"] andSize:23];
    }
    
    [self addSetting:self.softKeyboardGestureStack ofId:@"softKeyboardGestureStack" withInfoTag:YES withDynamicLabel:NO to:gesturesSection];
    [self addSetting:self.slideToSettingsScreenEdgeStack ofId:@"slideToSettingsScreenEdgeStack" withInfoTag:NO withDynamicLabel:NO to:gesturesSection];
    [self addSetting:self.slideToToolboxScreenEdgeStack ofId:@"slideToToolboxScreenEdgeStack" withInfoTag:NO withDynamicLabel:NO to:gesturesSection];
    [self addSetting:self.slideToSettingsDistanceStack ofId:@"slideToSettingsDistanceStack" withInfoTag:YES withDynamicLabel:YES to:gesturesSection];
    [self addSetting:self.edgeSlidingSensitivityStack ofId:@"edgeSlidingSensitivityStack" withInfoTag:YES withDynamicLabel:YES to:gesturesSection];
    [gesturesSection addToParentStack:_parentStack];
    // [gesturesSection setExpanded:NO];

    MenuSectionView *peripheralSection = [[MenuSectionView alloc] init];
    peripheralSection.delegate = self;
    peripheralSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Peripherals"];
    peripheralSection.identifier = @"SettingsSectionPeripherals";
    if (@available(iOS 13.0, *)) {
        [peripheralSection setSectionWithIcon:[UIImage imageNamed:@"cable.connector.video"] andSize:20];
    }
    if (@available(iOS 13.0, *)) {
        [self addSetting:self.externalDisplayModeStack ofId:@"externalDisplayModeStack" withInfoTag:YES withDynamicLabel:NO to:peripheralSection];
    }
    [self addSetting:self.localMousePointerModeStack ofId:@"localMousePointerModeStack" withInfoTag:YES withDynamicLabel:NO to:peripheralSection];
    [self addSetting:self.reverseMouseWheelDirectionStack ofId:@"reverseMouseWheelDirectionStack" withInfoTag:NO withDynamicLabel:NO to:peripheralSection];
    [self addSetting:self.citrixX1MouseStack ofId:@"citrixX1MouseStack" withInfoTag:NO withDynamicLabel:NO to:peripheralSection];
    [peripheralSection addToParentStack:_parentStack];
    // [peripheralSection setExpanded:NO];

    
    
    MenuSectionView *audioSection = [[MenuSectionView alloc] init];
    audioSection.delegate = self;
    audioSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Audio"];
    audioSection.identifier = @"SettingsSectionAudio";
    if (@available(iOS 13.0, *)) {
        [audioSection setSectionWithIcon:[UIImage imageNamed:@"speaker.wave.2"] andSize:20];
    }
    
    [self addSetting:self.audioOnPcStack ofId:@"audioOnPcStack" withInfoTag:NO withDynamicLabel:NO to:audioSection];
    [self addSetting:self.localVolumeStack ofId:@"localVolumeStack" withInfoTag:NO withDynamicLabel:YES to:audioSection];
    [self addSetting:self.redirectMicStack ofId:@"redirectMicStack" withInfoTag:YES withDynamicLabel:NO to:audioSection];
    [self addSetting:self.useBuiltinMicStack ofId:@"useBuiltinMicStack" withInfoTag:YES withDynamicLabel:NO to:audioSection];
    [self addSetting:self.micVolumeStack ofId:@"micVolumeStack" withInfoTag:NO withDynamicLabel:YES to:audioSection];
    [self addSetting:self.duckOtherAppStack ofId:@"duckOtherAppStack" withInfoTag:NO withDynamicLabel:NO to:audioSection];
    [self addSetting:self.muteInBackgroundStack ofId:@"muteInBackgroundStack" withInfoTag:NO withDynamicLabel:NO to:audioSection];
    // [self addSetting:self.audioEngineStack ofId:@"audioEngineStack" withInfoTag:YES withDynamicLabel:NO to:audioSection];
    // cancel audio engine selector due to system engine is unable to playback multi-channel audio
    [self addSetting:self.audioConfigStack ofId:@"audioConfigStack" withInfoTag:YES withDynamicLabel:NO to:audioSection];
    [audioSection addToParentStack:_parentStack];
    // [audioSection setExpanded:NO];

    
    otherSection = [[MenuSectionView alloc] init];
    otherSection.delegate = self;
    otherSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Others"];
    otherSection.identifier = @"SettingsSectionOthers";
    if (@available(iOS 13.0, *)) {
        [otherSection setSectionWithIcon:[UIImage systemImageNamed:@"cube"] andSize:20.5];
    }
    [self addSetting:self.statsOverlayStack ofId:@"statsOverlayStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];
    [self addSetting:self.unlockDisplayOrientationStack ofId:@"unlockDisplayOrientationStack" withInfoTag:YES withDynamicLabel:NO to:otherSection];
    [self addSetting:self.backgroundSessionTimerStack ofId:@"backgroundSessionTimerStack" withInfoTag:NO withDynamicLabel:YES to:otherSection];
    [self addSetting:self.appThemeStack ofId:@"appThemeStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];
    [self addSetting:self.optimizeGamesStack ofId:@"optimizeGamesStack" withInfoTag:YES withDynamicLabel:NO to:otherSection];
    [self addSetting:self.multiControllerStack ofId:@"multiControllerStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];
    [self addSetting:self.softKeyboardToolbarStack ofId:@"softKeyboardToolbarStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];
    [self addSetting:self.rememberFoldStateStack ofId:@"rememberFoldStateStack" withInfoTag:NO withDynamicLabel:NO to:otherSection];

    [otherSection addToParentStack:_parentStack];
    // [otherSection setExpanded:NO];
    
    
    experimentalSection = [[MenuSectionView alloc] init];
    experimentalSection.delegate = self;
    experimentalSection.sectionTitle = [LocalizationHelper localizedStringForKey:@"Experimental"];
    experimentalSection.identifier = @"SettingsSectionExperimental";
    if (@available(iOS 13.0, *)) {
        [experimentalSection setSectionWithIcon:[UIImage imageNamed:@"flask"] andSize:20];
    }
    
    [self addSetting:self.touchModeStack2 ofId:@"touchModeStack2" withInfoTag:NO withDynamicLabel:NO to:experimentalSection];
    // [self.touchModeSelector2 setEnabled:false];
    [self addSetting:self.touchMoveEventIntervalStack ofId:@"touchMoveEventIntervalStack" withInfoTag:NO withDynamicLabel:YES to:experimentalSection];
    [self addSetting:self.relativeTouchSlideThresholdStack ofId:@"relativeTouchSlideThresholdStack" withInfoTag:YES withDynamicLabel:YES to:experimentalSection];
    [self addSetting:self.singleTapSensitivityStack ofId:@"singleTapSensitivityStack" withInfoTag:NO withDynamicLabel:YES to:experimentalSection];
    [self addSetting:self.leftClickDelayStack ofId:@"leftClickDelayStack" withInfoTag:NO withDynamicLabel:YES to:experimentalSection];
    [self addSetting:self.renderingBackendStack ofId:@"renderingBackendStack" withInfoTag:YES withDynamicLabel:NO to:experimentalSection];
    // [self addSetting:self.frameTimebaseStack ofId:@"frameTimebaseStack" withInfoTag:NO withDynamicLabel:NO to:videoSection];
    [self addSetting:self.fullColorRangeStack ofId:@"fullColorRangeStack" withInfoTag:NO withDynamicLabel:NO to:experimentalSection];
    [self addSetting:self.performanceGraphStack ofId:@"performanceGraphStack" withInfoTag:YES withDynamicLabel:NO to:experimentalSection];
    [self addDynamicLabelForStack:self.graphOpacityStack];

    [self addSetting:self.sendDummyEventStack ofId:@"sendDummyEventStack" withInfoTag:YES withDynamicLabel:NO to:experimentalSection];
    
    [experimentalSection addToParentStack:_parentStack];
    // [experimentalSection setExpanded:NO];
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
        view.backgroundColor = [ThemeManager appPrimaryColorWithAlpha];
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
        button.titleLabel.accessibilityIdentifier = @"infoButton";
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
    if([sender.superview.accessibilityIdentifier isEqualToString: @"controllerToMouseStack"]){
        tempSettings = [dataMan getSettings];
        tipText = [LocalizationHelper localizedStringForKey:@"controllerToMouseStackTip", [ControllerUtil stringFor:tempSettings.controllerMouseSwitch.intValue],  [LocalizationHelper localizedStringForKey:tempSettings.controllerMouseStick.intValue == LeftStickToMouse ? @"Left stick" : @"Right stick"],  [ControllerUtil stringFor:tempSettings.controllerMouseLeftButton.intValue], [ControllerUtil stringFor:tempSettings.controllerMouseRightButton.intValue]];
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
    if([sender.superview.accessibilityIdentifier isEqualToString: @"hoverModeStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"hoverModeStackTip"];
        showOnlineDocAction = false;
    }
    if([sender.superview.accessibilityIdentifier isEqualToString: @"pencilTickStack"]){
        tipText = [LocalizationHelper localizedStringForKey:@"pencilTickStackTip"];
        showOnlineDocAction = true;
        onlineDocLink = [LocalizationHelper localizedStringForKey:@"PencilProPackURL"];
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
    for(UIStackView* stack in hiddenStacks) {
        stack.hidden = NO;
    }
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
    Settings *currentSettings = [dataMan retrieveSettings];
    currentSettings.settingsMenuMode = [NSNumber numberWithInteger:currentSettingsMenuMode];
    [dataMan saveData];
    
    _parentStack.spacing = [self isIPhone] ? 10 : 12;
    
    [self loadFavoriteSettingStackIdentifiers];
    for(NSString* settingIdentifier in _favoriteSettingStackIdentifiers){
        [_parentStack addArrangedSubview:_settingStackDict[settingIdentifier]];
    }
    
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
}

- (void)switchToAllSettings{
    [self forceRestoreHeightTemporarilyForSettingStackParentView];
    currentSettingsMenuMode = AllSettings;
    [_parentStack removeFromSuperview];
    [self initParentStack];
    [self layoutSections];
    // [self updateCodecDependentSwitches]; // Ensure switches are in correct state after layout
    [self updateTheme];
        //[self doneRemoveSettingItem];
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

- (void)viewDidLoad {
    
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
        self->dataMan = [[DataManager alloc] init];
        self->tempSettings = [self->dataMan getSettings];
        [self.rememberFoldStateSwitch setOn:self->tempSettings.rememberFoldState];// Load old setting
        MenuSectionView.overridePersistedFoldState = !self->tempSettings.rememberFoldState;
        [self.rememberFoldStateSwitch addTarget:self action:@selector(rememberFoldStateSwitchFlipped:) forControlEvents:UIControlEventValueChanged];

        [self layoutSections];


        // [self swi];

        self->slideToCloseSettingsViewRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(edgeSwiped)];
        self->slideToCloseSettingsViewRecognizer.edges = UIRectEdgeLeft;
        self->slideToCloseSettingsViewRecognizer.normalizedThresholdDistance = 0.0;
        self->slideToCloseSettingsViewRecognizer.edgeTolerance = 10;
        self->slideToCloseSettingsViewRecognizer.immediateTriggering = true;
        self->slideToCloseSettingsViewRecognizer.delaysTouchesBegan = NO;
        self->slideToCloseSettingsViewRecognizer.delaysTouchesEnded = NO;
        [self.view addGestureRecognizer:self->slideToCloseSettingsViewRecognizer];

        self->settingsViewJustLoaded = true;
        self->settingsViewJustExpanded = true;
        self->settingsViewAlreadyAppeared = false;

        // Always run settings in dark mode because we want the light fonts
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }


        self->currentSettingsMenuMode = self->tempSettings.settingsMenuMode.intValue;
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

        [self.resolutionSelector removeSegmentAtIndex:0 animated:NO]; // remove 360p
        [self.resolutionSelector removeSegmentAtIndex:5 animated:NO]; // remove custom segment
        // iOS12 compatibility:
        self.resolutionSelector.selectedSegmentIndex = 3;
        [self.resolutionSelector setNeedsLayout];

        resolutionTable[5] = CGSizeMake([self->tempSettings.width integerValue], [self->tempSettings.height integerValue]); // custom initial value
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
        [self codecSelectorChanged:self.codecSelector];

        [self.pipSwitch setOn:self->tempSettings.enablePIP];
        if(@available(iOS 15.0, *)) {
            [self.pipSwitch setEnabled:true];
        } else{
            [self.pipSwitch setOn:false];
            [self.pipSwitch setEnabled:false];
        }
        
        [self.statsOverlaySelector setSelectedSegmentIndex:self->tempSettings.statsOverlayLevel.intValue];

        NSInteger renderingBackend = [self->tempSettings.renderingBackend integerValue];
        [self.renderingBackendSelector setSelectedSegmentIndex:renderingBackend];
        [self.renderingBackendSelector addTarget:self action:@selector(renderingBackendChanged:) forControlEvents:UIControlEventValueChanged];

        NSInteger framePacingMode = [self->tempSettings.framePacingMode integerValue];
        [self.framePacingModeSelector setSelectedSegmentIndex:framePacingMode];
        [self.framePacingModeSelector addTarget:self action:@selector(framePacingModeChanged:) forControlEvents:UIControlEventValueChanged];
        [self framePacingModeChanged:self.framePacingModeSelector];
        
        // [self.frameTimebaseSwitch setOn:self->tempSettings.enableFrameTimebase];
        [self.asyncFrameDequeueSwitch setOn:self->tempSettings.asyncFrameDequeue];
        [self.sdrPerformanceWorkaroundSwitch setOn:self->tempSettings.sdrPerformanceWorkaround];

        [self renderingBackendChanged:self.renderingBackendSelector]; // Update PiP and frame pacing state based on current selection

        [self.citrixX1MouseSwitch setOn:self->tempSettings.btMouseSupport];
        [self.optimizeGamesSwitch setOn: self->tempSettings.optimizeGames];
        [self.multiControllerSwitch setOn:self->tempSettings.multiController];
        [self.swapAbxySwitch setOn:self->tempSettings.swapABXYButtons];
        [self.buttonVisualFeedbackSwitch setOn:self->tempSettings.buttonVisualFeedback];
        
        [self.trackTouchPointSwitch setOn:self->tempSettings.touchPointTracking];
        [self.trackTouchPointSwitch addTarget:self action:@selector(trackTouchPointSwitchFlipped:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.

        [self.delayLeftClickSwitch setOn:self->tempSettings.delayLeftClick];

        [self.hapticEngineSelector setSelectedSegmentIndex:self->tempSettings.hapticEngine.intValue];
        bool hideHapticEngineStack = false;
        if(@available(iOS 13.0, tvOS 13.0, *)) hideHapticEngineStack = false;
        else hideHapticEngineStack = true;
        [self setHidden:hideHapticEngineStack forStack:self.hapticEngineStack];
        bool disableControllerRumble = false;
        if(@available(iOS 14.0, tvOS 14.0, *)) nil;
        else disableControllerRumble = true;
        [self.hapticEngineSelector setEnabled:!disableControllerRumble forSegmentAtIndex:LeftRightSwapped];
        [self.hapticEngineSelector setEnabled:!disableControllerRumble forSegmentAtIndex:HapticEngineAuto];
        [self.hapticEngineSelector setEnabled:[self isIPhone] forSegmentAtIndex:RumbleDevice];

        [self.gyroModeSelector setSelectedSegmentIndex:self->tempSettings.gyroMode.intValue];
        [self.gyroSensitivitySlider setValue: (uint16_t)(self->tempSettings.gyroSensitivity.floatValue * 100) animated:NO]; // Load old setting.
        [self.gyroSensitivitySlider addTarget:self action:@selector(gyroSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self gyroSensitivitySliderMoved:self.gyroSensitivitySlider];
        
        if (@available(iOS 14.0, tvOS 14.0, *)) nil;
        else{
            [self.gyroModeSelector setEnabled:false forSegmentAtIndex:1];
            [self.gyroModeSelector setEnabled:false forSegmentAtIndex:3];
        }
        CMMotionManager *motionManager = [[CMMotionManager alloc] init];
        [self.gyroModeSelector setEnabled:[motionManager isGyroAvailable] forSegmentAtIndex:2];
        
        [self.emulatedControllerTypeSelector setSelectedSegmentIndex:[self controllerTypeToSegmentIndex:self->tempSettings.emulatedControllerType.intValue]];
        [self.emulatedControllerTypeSelector addTarget:self action:@selector(emulatedControllerTypeChanged:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self emulatedControllerTypeChanged:self.emulatedControllerTypeSelector];
        
        [self.leftStickMinOffsetSlider addTarget:self action:@selector(leftStickMinOffsetSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self.rightStickMinOffsetSlider addTarget:self action:@selector(rightStickMinOffsetSliderMoved:) forControlEvents:UIControlEventValueChanged];

        [self.audioOnPcSwitch setOn:self->tempSettings.playAudioOnPC];
        
        [self.localVolumeSlider setValue:self->tempSettings.localVolume.floatValue*100];
        [self.localVolumeSlider addTarget:self action:@selector(localVolumeSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self localVolumeSliderMoved:self.localVolumeSlider];
        
        [self.duckOtherAppSwitch setOn:self->tempSettings.duckOtherApps];
        
        [self.muteInBackgroundSwitch setOn:self->tempSettings.muteInBackground];
        [self.muteInBackgroundSwitch addTarget:self action:@selector(muteInBackgroundSwitchFlipped:) forControlEvents:UIControlEventValueChanged];

        [self.micVolumeSlider setValue:self->tempSettings.micVolume.floatValue*100];
        [self.micVolumeSlider addTarget:self action:@selector(micVolumeSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self micVolumeSliderMoved:self.self.micVolumeSlider];
        
        [self.redirectMicSwitch setOn:self->tempSettings.redirectMic];
        [self.redirectMicSwitch addTarget:self action:@selector(redirectMicSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self redirectMicSwitchFlipped:self.redirectMicSwitch];
        
        [self.useBuiltinMicSwitch setOn:self->tempSettings.useBuiltinMic];
        
        self->_lastSelectedResolutionIndex = resolution;
        [self.resolutionSelector setSelectedSegmentIndex:resolution];
        [self.resolutionSelector addTarget:self action:@selector(newResolutionChosen) forControlEvents:UIControlEventValueChanged];

        [self.framerateSelector setSelectedSegmentIndex:framerate];
        [self.framerateSelector addTarget:self action:@selector(framerateChanged) forControlEvents:UIControlEventValueChanged];
        
        [self.bitrateSlider setMinimumValue:0];
        [self.bitrateSlider setMaximumValue:(sizeof(bitrateTable) / sizeof(*bitrateTable)) - 1];
        [self.bitrateSlider setValue:[self getSliderValueForBitrate:self->_bitrate] animated:NO];
        [self.bitrateSlider addTarget:self action:@selector(bitrateSliderMoved) forControlEvents:UIControlEventValueChanged];
        [self updateBitrateText];
        [self updateResolutionDisplayLabel];

        [self.frameQueueSizeSlider setMinimumValue:0];
        [self.frameQueueSizeSlider setMaximumValue:5];
        [self.frameQueueSizeSlider setValue:self->tempSettings.frameQueueSize.intValue];
        [self.frameQueueSizeSlider addTarget:self action:@selector(frameQueueSizeSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self frameQueueSizeSliderMoved:self.frameQueueSizeSlider];

        [self.enableGraphsSwitch setOn:self->tempSettings.enableGraphs animated:NO]; // Add this line
        [self.enableGraphsSwitch addTarget:self action:@selector(enableGraphsChanged:) forControlEvents:UIControlEventValueChanged];
        [self enableGraphsChanged:self.enableGraphsSwitch];
        [self.graphOpacityStepper setMinimumValue:0];
        [self.graphOpacityStepper setMaximumValue:100];
        [self.graphOpacityStepper setValue:(int)self->tempSettings.graphOpacity.intValue];
        [self.graphOpacityStepper addTarget:self action:@selector(graphOpacityStepperTapped:) forControlEvents:UIControlEventValueChanged];
        [self graphOpacityStepperTapped:self.graphOpacityStepper];
        
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
                [self.audioConfigSelector setSelectedSegmentIndex:0];
                break;
            case 3:
                [self.audioConfigSelector setSelectedSegmentIndex:1];
                break;
            case 6:
                [self.audioConfigSelector setSelectedSegmentIndex:2];
                break;
            case 8:
                [self.audioConfigSelector setSelectedSegmentIndex:3];
                break;
        }
        // 2 - stereo (system)
        // 3 - stereo (SDL)
        // 6 - 5.1 (SDL)
        // 8 - 7.1 (SDL)

        // Unlock Display Orientation setting
        bool unlockDisplayOrientationSelectorEnabled = [self isFullScreenRequired] || [self isIPhone];//need "requires fullscreen" enabled in the app bunddle to make runtime orientation limitation working
        if(unlockDisplayOrientationSelectorEnabled) [self.unlockDisplayOrientationSelector setSelectedSegmentIndex:self->tempSettings.unlockDisplayOrientation ? 1 : 0];
        else [self.unlockDisplayOrientationSelector setSelectedSegmentIndex:1]; // can't lock screen orientation in this mode = Display Orientation always unlocked
        [self.unlockDisplayOrientationSelector setEnabled:unlockDisplayOrientationSelectorEnabled];

        [self.backgroundSessionTimerSlider setValue:(uint32_t)self->tempSettings.backgroundSessionTimer.floatValue];
        [self.backgroundSessionTimerSlider addTarget:self action:@selector(backgroundSessionTimerSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self backgroundSessionTimerSliderMoved:self.backgroundSessionTimerSlider];
        
        [self.appThemeSelector setSelectedSegmentIndex:self->tempSettings.appTheme.intValue];
        [self.appThemeSelector addTarget:self action:@selector(appThemeChanged:) forControlEvents:UIControlEventValueChanged];
        if (@available(iOS 13.0, *)) nil;
        else{
            [self.appThemeSelector setSelectedSegmentIndex:UIUserInterfaceStyleDark];
            [self.appThemeSelector setEnabled:false];
        }
        
        // lift streamview setting
        [self.liftStreamViewForKeyboardSelector setSelectedSegmentIndex:self->tempSettings.liftStreamViewForKeyboard ? 1 : 0];// Load old setting

        // showkeyboard toolbar setting
        [self.softKeyboardToolbarSwitch setOn:self->tempSettings.showKeyboardToolbar];// Load old setting

        // reverse mouse wheel direction setting
        [self.reverseMouseWheelDirectionSelector setSelectedSegmentIndex:self->tempSettings.reverseMouseWheelDirection ? 1 : 0];// Load old setting

        //  slide to menu settings
        [self.slideToSettingsScreenEdgeSelector setSelectedSegmentIndex:[self getSelectorIndexFromScreenEdge:(uint32_t)self->tempSettings.slideToSettingsScreenEdge.integerValue]];
        // Load old setting
        [self.slideToToolboxScreenEdgeSelector setEnabled:false];
        [self.slideToSettingsScreenEdgeSelector addTarget:self action:@selector(slideToSettingsScreenEdgeChanged) forControlEvents:UIControlEventValueChanged];
        [self slideToSettingsScreenEdgeChanged];

        [self.slideToMenuDistanceSlider setValue:self->tempSettings.slideToSettingsDistance.floatValue];
        [self.slideToMenuDistanceSlider addTarget:self action:@selector(slideToMenuDistanceSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self slideToMenuDistanceSliderMoved:self.slideToMenuDistanceSlider];

        [self.edgeSlidingSensitivitySlider setValue:self->tempSettings.edgeSlidingSensitivity.floatValue];
        [self.edgeSlidingSensitivitySlider addTarget:self action:@selector(edgeSlidingSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self edgeSlidingSensitivitySliderMoved:self.edgeSlidingSensitivitySlider];

        //TouchMode & OSC Related Settings:

        // pointer veloc setting, will be enable/disabled by touchMode
        [self.pointerVelocityModeDividerSlider setValue: (uint8_t)(self->tempSettings.pointerVelocityModeDivider.floatValue * 100) animated:NO]; // Load old setting.
        [self.pointerVelocityModeDividerSlider addTarget:self action:@selector(pointerVelocityModeDividerSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self pointerVelocityModeDividerSliderMoved:self.pointerVelocityModeDividerSlider];

        // init pointer veloc setting,  will be enable/disabled by touchMode
        [self.touchPointerVelocityFactorSlider setValue: [self map_SliderValue_fromVelocFactor: self->tempSettings.touchPointerVelocityFactor.floatValue] animated:NO]; // Load old setting.
        [self.touchPointerVelocityFactorSlider addTarget:self action:@selector(touchPointerVelocityFactorSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self touchPointerVelocityFactorSliderMoved:self.touchPointerVelocityFactorSlider];

        // async native touch event
        // [self.asyncNativeTouchPrioritySelector setSelectedSegmentIndex:currentSettings.asyncNativeTouchPriority.intValue]; // load old setting of asyncNativeTouchPriority
        // [self.asyncNativeTouchPrioritySelector addTarget:self action:@selector(asyncNativeTouchPriorityChanged) forControlEvents:UIControlEventValueChanged];

        // init relative touch mouse pointer veloc setting,  will be enable/disabled by touchMode
        [self.mousePointerVelocityFactorSlider setValue:[self map_SliderValue_fromVelocFactor: self->tempSettings.mousePointerVelocityFactor.floatValue] animated:NO]; // Load old setting.
        [self.mousePointerVelocityFactorSlider addTarget:self action:@selector(mousePointerVelocityFactorSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self mousePointerVelocityFactorSliderMoved:self.mousePointerVelocityFactorSlider];
        
        [self.passthroughGesturesSwitch setOn:self->tempSettings.passthroughGestures];
        [self.passthroughGesturesSwitch addTarget:self action:@selector(passthroughGesturesSwitchFlipped:) forControlEvents:(UIControlEventValueChanged)];
        
        [self.pinchGestureSwitch setOn:self->tempSettings.enablePinch];
        [self.pinchGestureSwitch addTarget:self action:@selector(pinchGestureSwitchFlipped:) forControlEvents:(UIControlEventValueChanged)];

        [self.ctrlDownForPinchSwitch setOn:self->tempSettings.ctrlDownForPinch];
        
        [self.scrollSensitivitySlider setValue:self->tempSettings.scrollSensitivity.floatValue animated:NO];
        [self.scrollSensitivitySlider addTarget:self action:@selector(scrollSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self scrollSensitivitySliderMoved:self.scrollSensitivitySlider];
        
        [self.pinchSensitivitySlider setValue:self->tempSettings.pinchSensitivity.floatValue animated:NO];
        [self.pinchSensitivitySlider addTarget:self action:@selector(pinchSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self pinchSensitivitySliderMoved:self.pinchSensitivitySlider];

        [self.singleTapSensitivitySlider setValue:self->tempSettings.singleTapSensitivity.doubleValue animated:NO];
        [self.singleTapSensitivitySlider addTarget:self action:@selector(singleTapSensitivitySliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self singleTapSensitivitySliderMoved:self.singleTapSensitivitySlider];
        
        [self.relativeTouchSlideThresholdSlider setValue:self->tempSettings.relativeTouchSlideThreshold.floatValue animated:NO];
        [self.relativeTouchSlideThresholdSlider addTarget:self action:@selector(relativeTouchSlideThresholdSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
        [self relativeTouchSlideThresholdSliderMoved:self.relativeTouchSlideThresholdSlider];

        // these settings will be affected by onscreenControl & touchMode, must be loaded before them.
        // NSLog(@"osc tool fingers setting test: %d", currentSettings.oscLayoutToolFingers.intValue);
        self->oswLayoutFingers = (uint16_t)self->tempSettings.oscLayoutToolFingers.intValue; // load old setting of oscLayoutFingers
        uint8_t keyboardToggleFingers = self->tempSettings.keyboardToggleFingers.intValue;

        [self.softKeyboardGestureSelector setSelectedSegmentIndex:keyboardToggleFingers>=6 ? 3 : keyboardToggleFingers-3];



        // this setting will be affected by touchMode, must be loaded before them.
        NSInteger onscreenControlsLevel = [self->tempSettings.onscreenControls integerValue];
        [self.onScreenWidgetSelector setSelectedSegmentIndex:MIN(onscreenControlsLevel,OnScreenControlsLevelCustom)];
        [self.onScreenWidgetSelector addTarget:self action:@selector(onScreenWidgetChanged) forControlEvents:UIControlEventValueChanged];
        [self onScreenWidgetChanged];

        // touch move event interval for native-touch.
        [self.touchMoveEventIntervalSlider setValue:self->tempSettings.touchMoveEventInterval.intValue animated:NO]; // Load old setting.
        [self.touchMoveEventIntervalSlider addTarget:self action:@selector(touchMoveEventIntervalSliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];

        // touch move event interval for native-touch.
        [self.leftClickDelaySlider setValue:self->tempSettings.leftClickDelayMs.intValue animated:NO]; // Load old setting.
        [self.leftClickDelaySlider addTarget:self action:@selector(leftClickDelaySliderMoved:) forControlEvents:(UIControlEventValueChanged)]; // Update label display when slider is being moved.
        [self leftClickDelaySliderMoved:self.leftClickDelaySlider];

        // this part will enable/disable oscSelector & the asyncNativeTouchPriority selector
        uint8_t touchModeSelectorIndex = self->tempSettings.touchMode.intValue == NativeTouchOnly ? NativeTouch : self->tempSettings.touchMode.intValue;
        [self.touchModeSelector1 setSelectedSegmentIndex:touchModeSelectorIndex]; //Load old touchMode setting
        [self.touchModeSelector1 addTarget:self action:@selector(touchMode1Changed:) forControlEvents:UIControlEventValueChanged];
        [self touchModeChanged:self.touchModeSelector1];
        
        [self.touchModeSelector2 addTarget:self action:@selector(touchMode2Changed:) forControlEvents:UIControlEventValueChanged];
        self.touchModeSelector2.selectedSegmentIndex = self.touchModeSelector1.selectedSegmentIndex;

        // self.enableOswSwitchStack.hidden = !(self->tempSettings.touchMode.intValue == NativeTouch || self->tempSettings.touchMode.intValue == NativeTouchOnly); // do not use setHidden to stack wrapped by a settingStack
        
        [self.enableOswForNativeTouchSwitch setOn:self->tempSettings.touchMode.intValue != NativeTouchOnly];
        [self.enableOswForNativeTouchSwitch addTarget:self action:@selector(enableOswForNativeTouchSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self enableOswForNativeTouchSwitchFlipped:self.enableOswForNativeTouchSwitch];

        [self.externalDisplayModeSelector setSelectedSegmentIndex:self->tempSettings.externalDisplayMode.integerValue];
        [self.localMousePointerModeSelector setSelectedSegmentIndex:self->tempSettings.localMousePointerMode.integerValue];
        
        [self.sendDummyEventSwitch setOn:self->tempSettings.sendDummyEvent];// Load old setting
        
        [self.controllerToMouseSwitch setOn:self->tempSettings.mapControllerToMouse];
        [self.controllerToMouseSwitch addTarget:self action:@selector(controllerToMouseSwitchFlipped:) forControlEvents:UIControlEventValueChanged];
        [self controllerToMouseSwitchFlipped:self.controllerToMouseSwitch];
        
        [self.controllerGyroSwitchButtonSetter addTarget:self action:@selector(controllerGyroSwitchModeChanged:) forControlEvents:UIControlEventValueChanged];
        
        [self.controllerMouseVelocitySlider setValue:self->tempSettings.controllerMousePointerVelocity.floatValue];
        [self.controllerMouseVelocitySlider addTarget:self action:@selector(controllerMouseVelocitySliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self controllerMouseVelocitySliderMoved:self.controllerMouseVelocitySlider];
        
        [self.controllerMouseExpoSlider setValue:self->tempSettings.controllerMouseExpo.floatValue];
        [self.controllerMouseExpoSlider addTarget:self action:@selector(controllerMouseExpoSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self controllerMouseExpoSliderMoved:self.controllerMouseExpoSlider];

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

- (void)hdrSwitchFlipped:(UISwitch* )sender{
    /*
    if(!sender.isOn
       && [Utils hdrSupported]
       && ![self isIPhone]) [self.sdrPerformanceWorkaroundSwitch setOn:true];
     */
}

- (bool)isOswEnabled{
    return [self isNotNativeTouchOnly] && self.onScreenWidgetSelector.selectedSegmentIndex != OnScreenControlsLevelOff;
}

- (bool)isCustomOswEnabled{
    bool customOswEnabled = [self isOswEnabled] && self.onScreenWidgetSelector.selectedSegmentIndex == OnScreenControlsLevelCustom;
    // motionControlSection.expandable = customOswEnabled;
    // if(!(settingsViewJustExpanded || settingsViewJustLoaded)) [motionControlSection setExpanded:customOswEnabled];
    return customOswEnabled;
}

- (bool)isNotNativeTouchOnly{
    return (self.enableOswForNativeTouchSwitch.isOn && self.touchModeSelector1.selectedSegmentIndex == NativeTouch) || self.touchModeSelector1.selectedSegmentIndex != NativeTouch;
}

- (void)handleOswGestureChange{
    if(settingsViewJustLoaded) return;
    if([self isCustomOswEnabled] && oswLayoutFingers == self.softKeyboardGestureSelector.selectedSegmentIndex + 3 && oswLayoutFingers < 6){
        [_softKeyboardGestureSelector setSelectedSegmentIndex:_softKeyboardGestureSelector.selectedSegmentIndex-1];
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
        [self.framePacingModeSelector setSelectedSegmentIndex:FramePacingModeQueue];
        [self.framePacingModeSelector setEnabled:NO];
        [self setHidden:true forStack:self.asyncFrameDequeueStack];
    } else {
        // Balanced mode (AVSB renderer) - enable PiP toggle if iOS 15+
        if (@available(iOS 15.0, *)) {
            [self.pipSwitch setEnabled:YES];
        } else {
            [self.pipSwitch setOn:NO];
            [self.pipSwitch setEnabled:NO];
        }
        [self.framePacingModeSelector setEnabled:YES];
        [self setHidden:false forStack:self.asyncFrameDequeueStack];
    }

    // Get the current settings to compare with the new selection
    NSInteger previousBackend = [tempSettings.renderingBackend integerValue];

    // Check if the rendering backend has actually changed
    if (previousBackend != sender.selectedSegmentIndex) {
        // Show alert to prompt user to restart the app
        NSString *message = [LocalizationHelper localizedStringForKey: sender.selectedSegmentIndex == 1 ? @"metalRenderTip" : @"standardRenderTip"];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Restart Required"]
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *quitAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Quit Now"]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {

            Settings* directSettings = [self->dataMan retrieveSettings];
            directSettings.renderingBackend = [NSNumber numberWithInteger:sender.selectedSegmentIndex];
            [self->dataMan saveData];
            [self saveSettings];
            
            exit(0);
        }];
        
        UIAlertAction *laterAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Learn More"]
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * _Nonnull action) {
            self.renderingBackendSelector.selectedSegmentIndex = 0;
            [self renderingBackendChanged:self.renderingBackendSelector];
            NSURL *url = [NSURL URLWithString:[LocalizationHelper localizedStringForKey:@"betterPerformanceLink"]];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }
        }];
        
        [alertController addAction:laterAction];
        [alertController addAction:quitAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)framePacingModeChanged:(UISegmentedControl *)sender {
    // Hide frame queue size for Off and Legacy modes
    [self setHidden:(sender.selectedSegmentIndex == FramePacingModeOff || sender.selectedSegmentIndex == FramePacingModeLegacy) forStack:self.frameQueueSizeStack];
    // [self setHidden:(sender.selectedSegmentIndex != FramePacingModeQueue) forStack:self.frameTimebaseStack];
    [self setHidden:(sender.selectedSegmentIndex != FramePacingModeQueue
                    || self.renderingBackendSelector.selectedSegmentIndex != 0) forStack:self.asyncFrameDequeueStack];

    if(sender.selectedSegmentIndex == FramePacingModeOff || sender.selectedSegmentIndex == FramePacingModeLegacy){
        [self.enableGraphsSwitch setOn:NO];
        [self findDynamicLabelFromStack:_graphOpacityStack].hidden = YES;
    }
    [self.enableGraphsSwitch setEnabled:sender.selectedSegmentIndex == FramePacingModeQueue];
    [self.graphOpacityStepper setEnabled:self.enableGraphsSwitch.isOn];
    [self setHidden:(sender.selectedSegmentIndex == FramePacingModeOff || sender.selectedSegmentIndex == FramePacingModeLegacy) forStack:self.performanceGraphStack];

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
        [self yawPitchToRightStickSwitchFlipped:self.yawPitchToRightStickSwitch];
        [self rollToLeftStickSwitchFlipped:self.rollToLeftStickSwitch];
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
                [self.mapGyroToSelector setSelectedSegmentIndex:self->oscProfile.mapGyroTo];
                [self mapGyroToChanged:self.mapGyroToSelector];
            }
            else{
                MotionHandler* motionHandler = [MotionHandler sharedWithProfile:nil];
                [motionHandler calibrateGyroBiasWithDuration:5 completion:^{
                    Settings* currentSettings = [self->dataMan retrieveSettings];
                    currentSettings.gyroBiasX = [NSNumber numberWithDouble:motionHandler.gyroBiasX];
                    currentSettings.gyroBiasY = [NSNumber numberWithDouble:motionHandler.gyroBiasY];
                    currentSettings.gyroBiasZ = [NSNumber numberWithDouble:motionHandler.gyroBiasZ];
                    [self->dataMan saveData];
                }];
                [AlertControllerUtil showAlertIn:self
                                                title:[LocalizationHelper localizedStringForKey:@"Drift Correction"]
                                              message:[LocalizationHelper localizedStringForKey:@"Calibrating..."]
                                           withCancel:NO
                                          buttonTitle:[LocalizationHelper localizedStringForKey:@"Finished!"]
                                            countdown:6
                                               action:^{}
                                           completion:^{
                    [self.mapGyroToSelector setSelectedSegmentIndex:self->oscProfile.mapGyroTo];
                    [self mapGyroToChanged:self.mapGyroToSelector];
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
                                
                [ControllerUtil listenWithController:self->capturedController swapABXY:false handler:^(NSDictionary * buttonDict, GCExtendedGamepad * gamepad, GCControllerElement * element) {
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self) return;
                    for(NSNumber* buttonFlagId in buttonDict){
                        GCControllerButtonInput * button = (GCControllerButtonInput *)buttonDict[buttonFlagId];
                        if(button.isPressed){
                            if(sender.selectedSegmentIndex == ControllerGyroSwitchPressToToggle) self->oscProfile.controllerGyroSwitchToggle = buttonFlagId.intValue;
                            if(sender.selectedSegmentIndex == ControllerGyroSwitchHoldDown) self->oscProfile.controllerGyroSwitchHold = buttonFlagId.intValue;
                            
                            switchButtonCaptured = true;
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Finished"];
                            gamepad.valueChangedHandler = nil;
                            if(confirmAction) [confirmAction setValue:[LocalizationHelper localizedStringForKey:@"OK"] forKey:@"title"];
                            [self->oscProfileMan replaceSelectedProfileWith:self->oscProfile overwriteDefault:true];
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
                        [self controllerGyroSwitchModeChanged:sender];
                    }];
                }];
            }
        }
                                   completion:^{
            if(!switchButtonCaptured){
                if(sender.selectedSegmentIndex == ControllerGyroSwitchPressToToggle) self->oscProfile.controllerGyroSwitchToggle = ControllerButtonNull;
                if(sender.selectedSegmentIndex == ControllerGyroSwitchHoldDown) self->oscProfile.controllerGyroSwitchHold = ControllerButtonNull;
                [self->oscProfileMan replaceSelectedProfileWith:self->oscProfile overwriteDefault:true];
            }
            
            bool noSwitchButtonSet = self->oscProfile.controllerGyroSwitchHold == ControllerButtonNull && self->oscProfile.controllerGyroSwitchToggle == ControllerButtonNull;
            bool duplicatedButtons = self->oscProfile.controllerGyroSwitchHold == self->oscProfile.controllerGyroSwitchToggle && self->oscProfile.controllerGyroSwitchToggle != ControllerButtonNull;
            bool bothButtonsSet = self->oscProfile.controllerGyroSwitchHold != ControllerButtonNull && self->oscProfile.controllerGyroSwitchToggle != ControllerButtonNull && !duplicatedButtons;
            tipLabel.text = @"";
            if(bothButtonsSet) tipLabel.text = [LocalizationHelper localizedStringForKey:@" both set "];
            if(duplicatedButtons){
                sender.selectedSegmentIndex = ControllerGyroSwitchDisabled;
                tipLabel.text = [LocalizationHelper localizedStringForKey:@" duplicated ! "];
                [self->oscProfileMan replaceSelectedProfileWith:self->oscProfile overwriteDefault:true];
            }
            if(noSwitchButtonSet) sender.selectedSegmentIndex = ControllerGyroSwitchDisabled;
            if(!noSwitchButtonSet && !bothButtonsSet && !duplicatedButtons){
                sender.selectedSegmentIndex = self->oscProfile.controllerGyroSwitchToggle != ControllerButtonNull ? ControllerGyroSwitchPressToToggle : ControllerGyroSwitchHoldDown;
            }
            
            [self setHidden:sender.selectedSegmentIndex==ControllerGyroSwitchDisabled forStack:self.reverseHoldButtonStack];
            
            if(self->capturedController && self->capturedController.extendedGamepad) self->capturedController.extendedGamepad.valueChangedHandler = nil;
        }];
    }
}

- (void)controllerToMouseSwitchFlipped:(UISwitch* )sender{
    [self setHidden:!sender.isOn forStack:_controllerMouseVelocityStack];
    [self setHidden:!sender.isOn forStack:_controllerMouseExpoStack];
    if(!sender.isOn || settingsViewJustLoaded) return;
    [self.swapAbxySwitch setOn:false]; // swapAbxy can be enabled after mouse to controller is set
    __block bool switchButtonCaptured = false;
    __block bool stickCaptured = false;
    __block bool leftButtonCaptured = false;
    __block bool rightButtonCaptured = false;
    Settings* currentSettings = [dataMan retrieveSettings];
    [AlertControllerUtil showAlertIn:self
                                title:[LocalizationHelper localizedStringForKey:@"Map controller to mouse"]
                              message:[LocalizationHelper localizedStringForKey:@"Press a button for switching to controller mouse mode (long press for 1 second during streaming)"]
                           withCancel:YES
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

            [ControllerUtil listenWithController:self->capturedController swapABXY:false handler:^(NSDictionary * buttonDict, GCExtendedGamepad * gamepad, GCControllerElement * element) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                
                if(!switchButtonCaptured){
                    for(NSNumber* buttonFlagId in buttonDict){
                        GCControllerButtonInput * button = (GCControllerButtonInput *)buttonDict[buttonFlagId];
                        if(button.isPressed){
                            currentSettings.controllerMouseSwitch = buttonFlagId;
                            switchButtonCaptured = true;
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Move the stick you wish to use for mouse control. Another stick will be used for vertical & horizontal scroll."];
                            return;
                        }
                    }
                }
                
                if(!stickCaptured && switchButtonCaptured){
                    float leftStickOffset = hypotf(gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value);
                    float rightStickOffset = hypotf(gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value);
                    if(leftStickOffset>0.1||rightStickOffset>0.1){
                        ControllerMouseStick stick = leftStickOffset>rightStickOffset ? LeftStickToMouse : RightStickToMouse;
                        currentSettings.controllerMouseStick = @(stick);
                        stickCaptured = true;
                        AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Press the button for mouse left button"];
                    }
                    return;
                }
                
                if(!leftButtonCaptured && stickCaptured){
                    for(NSNumber* buttonFlagId in buttonDict){
                        GCControllerButtonInput * button = (GCControllerButtonInput *)buttonDict[buttonFlagId];
                        if(button.isPressed){
                            currentSettings.controllerMouseLeftButton = buttonFlagId;
                            leftButtonCaptured = true;
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Press the button for mouse right button"];
                            return;
                        }
                    }
                }

                if(!rightButtonCaptured && leftButtonCaptured){
                    for(NSNumber* buttonFlagId in buttonDict){
                        GCControllerButtonInput * button = (GCControllerButtonInput *)buttonDict[buttonFlagId];
                        if(button.isPressed){
                            currentSettings.controllerMouseRightButton = buttonFlagId;
                            rightButtonCaptured = true;
                            AlertControllerUtil.alertController.message = [LocalizationHelper localizedStringForKey:@"Finished"];
                            gamepad.valueChangedHandler = nil;
                            UIAlertAction* cancelAction = AlertControllerUtil.alertController.actions.firstObject;
                            if(cancelAction) [cancelAction setValue:[LocalizationHelper localizedStringForKey:@"OK"] forKey:@"title"];
                            [self->dataMan saveData];
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
                        [self.controllerToMouseSwitch setOn:NO];
                        [self controllerToMouseSwitchFlipped:self.controllerToMouseSwitch];
                        return;
                    }
                    [AlertControllerUtil.alertController dismissViewControllerAnimated:NO completion:^{}];
                    [self controllerToMouseSwitchFlipped:self.controllerToMouseSwitch];
                }];
            }];
        }
    }
                               completion:^{
        if(AlertControllerUtil.actionCancelled){
            if(!rightButtonCaptured){
                [self.controllerToMouseSwitch setOn:rightButtonCaptured];
                [self controllerToMouseSwitchFlipped:self.controllerToMouseSwitch];
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
    [self pitchSensitivitySliderMoved:self.pitchSensitivitySlider];
}

- (void)pitchSensitivitySliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:_pitchSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (int16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]];
}

- (void)rollSensitivitySliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:_rollSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (int16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]];
}

- (void)gyroMinStickOffsetSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:_gyroToStickMinOffsetStack].text = [NSString stringWithFormat:@"  %d  ", (int16_t)sender.value];
    if(settingsViewJustExpanded) return;
    LiSendControllerEvent(0, 0, 0, _rollToLeftStickSwitch.isOn?sender.value:0, 0, _yawPitchToRightStickSwitch.isOn?sender.value:0, 0);
}

- (void)leftStickMinOffsetSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:_leftStickMinOffsetStack].text = [NSString stringWithFormat:@"  %d  ", (int16_t)sender.value];
    if(settingsViewJustExpanded) return;
    LiSendControllerEvent(0, 0, 0, sender.value, 0, 0, 0);
}

- (void)rightStickMinOffsetSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:_rightStickMinOffsetStack].text = [NSString stringWithFormat:@"  %d  ", (int16_t)sender.value];
    if(settingsViewJustExpanded) return;
    LiSendControllerEvent(0, 0, 0, 0, 0, sender.value, 0);
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
    [self findDynamicLabelFromStack:self.pointerVelocityFactorStack].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]]; // Update label display
}

- (void) gyroSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:self.gyroSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)sender.value]; // Update label display
}

- (void) localVolumeSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:self.localVolumeStack].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)sender.value]; // Update label display
    if(_mainFrameViewController.settingsExpandedInStreamView) [Connection setVolume:sender.value/100];
}

- (void) micVolumeSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:self.micVolumeStack].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)sender.value]; // Update label display
    if(_mainFrameViewController.settingsExpandedInStreamView) [MicHandler setVolume:sender.value/100];
}

- (void) backgroundSessionTimerSliderMoved:(UISlider* )sender {
    NSString* labelString;
    labelString = [LocalizationHelper localizedStringForKey:@"  keep %d min  ", (uint16_t)sender.value];
    if(sender.value == 0) labelString = [LocalizationHelper localizedStringForKey:@"  disconnect  "];
    if(sender.value == sender.maximumValue) labelString = [LocalizationHelper localizedStringForKey:@"  keep alive  "];
    [self findDynamicLabelFromStack:self.backgroundSessionTimerStack].text = labelString; // Update label display
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
    [self findDynamicLabelFromStack:_mousePointerVelocityStack].text = [NSString stringWithFormat:@"  %d%%  ",(uint16_t)[self map_velocFactorDisplay_fromSliderValue:sender.value]];
}

- (void) singleTapSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:_singleTapSensitivityStack].text = [NSString stringWithFormat:@"  %.1f  ",sender.value];
}

- (void) scrollSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:_scrollSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)(sender.value*100)];
}

- (void) pinchSensitivitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:_pinchSensitivityStack].text = [NSString stringWithFormat:@"  %d%%  ", (uint16_t)(sender.value*100)];
}

- (void) relativeTouchSlideThresholdSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:_relativeTouchSlideThresholdStack].text = [NSString stringWithFormat:@" %.1f ",sender.value];
}

- (void) controllerMouseVelocitySliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:_controllerMouseVelocityStack].text = [NSString stringWithFormat:@"  %.1f  ", sender.value];
}

- (void) controllerMouseExpoSliderMoved:(UISlider* )sender {
    [self findDynamicLabelFromStack:_controllerMouseExpoStack].text = [NSString stringWithFormat:@"  %.1f  ", sender.value];
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
    bool isNativeTouch = [self.touchModeSelector selectedSegmentIndex] == NativeTouchOnly || [self.touchModeSelector selectedSegmentIndex] == NativeTouch;
    bool asyncNativeTouchEnabled = [self.asyncNativeTouchPrioritySelector selectedSegmentIndex] != AsyncNativeTouchOff;
    [self widget:self.touchMoveEventIntervalSlider setEnabled:isNativeTouch && asyncNativeTouchEnabled];
}
*/

- (void)touchMode2Changed:(UISegmentedControl* )sender {
    // [UIView animateWithDuration:0 animations:^{
        [self.touchModeSelector1 setSelectedSegmentIndex: sender.selectedSegmentIndex];
    // } completion:^(BOOL finished) {
        // 动画完成时执行的代码
        [self touchModeChanged:sender];
    // }];
}

- (void)touchMode1Changed:(UISegmentedControl* )sender {
    // [UIView animateWithDuration:0 animations:^{
        self.touchModeSelector2.selectedSegmentIndex = sender.selectedSegmentIndex;
    // } completion:^(BOOL finished) {
        // 动画完成时执行的代码
        [self touchModeChanged:sender];
    // }];
}

- (void)touchModeChanged:(UISegmentedControl* )sender {
    // Disable On-Screen Controls & Widgets in non-relative touch mode
    // bool customOscEnabled = [self isOswEnabled] && [self.onScreenWidgetSelector selectedSegmentIndex] == OnScreenControlsLevelCustom;
    bool isNativeTouch = sender.selectedSegmentIndex == NativeTouch;
    bool isEgmerging = self.enableOswSwitchStack.hidden != !isNativeTouch && isNativeTouch;
    self.enableOswSwitchStack.hidden = !isNativeTouch;
    if(isEgmerging) [self highlightEmergingStack:self.enableOswSwitchStack];

    
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityDividerStack];

    [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityDividerStack];
    [self setHidden:!isNativeTouch forStack:self.pointerVelocityFactorStack];
    [self setHidden:!isNativeTouch forStack:self.touchMoveEventIntervalStack];

    /*
    [self setHidden:(sender.selectedSegmentIndex!=RelativeTouch
                     && sender.selectedSegmentIndex!=AbsoluteTouch) forStack:self.pinchGestureStack];
    [self setHidden:(sender.selectedSegmentIndex!=RelativeTouch
                     && sender.selectedSegmentIndex!=AbsoluteTouch) forStack:self.scrollSensitivityStack];*/
    
    [self setHidden:sender.selectedSegmentIndex!=AbsoluteTouch forStack:self.passthroughGesturesStack];
    UISwitch* dummySwitch = [[UISwitch alloc] init];
    [dummySwitch setOn:(sender.selectedSegmentIndex==RelativeTouch
                        || (sender.selectedSegmentIndex==AbsoluteTouch && _passthroughGesturesSwitch.isOn))];
    [self passthroughGesturesSwitchFlipped:dummySwitch];
    
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
    [self setHidden:![self isNotNativeTouchOnly] forStack:self.onScreenWidgetStack];
    [self setHidden:![self isNotNativeTouchOnly] forStack:self.buttonVisualFeedbackStack];
    [self setHidden:sender.selectedSegmentIndex!=AbsoluteTouch forStack:self.delayLeftClickStack];
    [self handleOswGestureChange];
}

- (void)emulatedControllerTypeChanged:(UISegmentedControl* )sender{
    [self setHidden:sender.selectedSegmentIndex == 0 forStack:_gyroModeStack];
    [self setHidden:sender.selectedSegmentIndex == 0 forStack:_gyroSensitivityStack];
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
    if(!sender.isOn) [self pinchGestureSwitchFlipped:sender];
    else [self pinchGestureSwitchFlipped:_pinchGestureSwitch];
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
    
    // NSInteger fps = [self getChosenFrameRate];
    [self touchMoveEventIntervalSliderMoved:self.touchMoveEventIntervalSlider];
    [self updateBitrate];
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
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:NO];
    
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

- (void) leftClickDelaySliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:self.leftClickDelayStack].text = [NSString stringWithFormat:@"  %d ms  ", (uint16_t)sender.value];
}

- (void) slideToMenuDistanceSliderMoved:(UISlider* )sender{
    UILabel* displayLabel = [self findDynamicLabelFromStack:_slideToSettingsDistanceStack];
    // displayLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    NSString* labelText = [LocalizationHelper localizedStringForKey:@"%d%% screen width", (uint8_t)(sender.value * 100)];
    displayLabel.text = [NSString stringWithFormat:@"  %@  ", labelText];
}

- (void) edgeSlidingSensitivitySliderMoved:(UISlider* )sender{
    UILabel* displayLabel = [self findDynamicLabelFromStack:_edgeSlidingSensitivityStack];
    // displayLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    NSString* labelText = [LocalizationHelper localizedStringForKey:@"  %d  ", (uint8_t)sender.value];
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
                label.textColor = [UIColor clearColor];
                label.textColor = [ThemeManager textColor];
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
                selector.selectedSegmentTintColor = [ThemeManager appSecondaryColor];
            } else {
                selector.tintColor = [ThemeManager appSecondaryColor];
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
            slider.tintColor = [ThemeManager appSecondaryColor];
        }
        [self updateThemeForSliders:subview];
    }
}

- (void)updateThemeForMenuSections:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[MenuSectionView class]]) {
            MenuSectionView *section = (MenuSectionView *)subview;
            section.iconImageView.tintColor = [UIColor clearColor];
            section.iconImageView.tintColor = [ThemeManager textColor];
            section.separatorLine.backgroundColor = [UIColor clearColor];
            section.separatorLine.backgroundColor = [ThemeManager separatorColor];
        }
        [self updateThemeForMenuSections:subview];
    }
}

- (void)updateTheme{
    self.view.backgroundColor = [UIColor clearColor];
    self.view.backgroundColor = [ThemeManager appBackgroundColor];
    [self updateThemeForMenuSections:self.view];
    [self updateThemeForLabels:self.view];
    [self updateThemeForSelectors:self.view];
    [self updateThemeForSliders:self.view];
}

- (void) frameQueueSizeSliderMoved:(UISlider* )sender {
    assert(self.frameQueueSizeSlider.value >= 0 && self.frameQueueSizeSlider.value <= 5);
    int queueSize = self.frameQueueSizeSlider.value;
    [self findDynamicLabelFromStack:_frameQueueSizeStack].text = queueSize==0 ? [LocalizationHelper localizedStringForKey:@"lowest latency"] : [NSString stringWithFormat: @"  %d  ", queueSize];
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
    if(self.mainFrameViewController.settingsExpandedInStreamView){
        [self.mainFrameViewController requestForBitrate:(uint32_t)_bitrate];
    }
    
    if(![MicHandler permissionGranted]) [self.redirectMicSwitch setOn:false];
    
    [self saveGameProfileConfigs];
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
        [self pencilTickModeChanged:self.pencilTickSelector];
        [self.pressureCurveSwitch setOn:false];
        [self.doubleTapShortcutSwitch setOn:false];
        [self.squeezeShortcutSwitch setOn:false];
        [self.pencilPausesNativeTouchSwitch setOn:false];
        [self.disablePencilSlideGestureSwitch setOn:false];
        
        
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
    self.onScreenWidgetSelector.selectedSegmentIndex = OnScreenControlsLevelCustom;
}

- (void)pencilTickIntervalSliderMoved:(UISlider* )sender{
    [self findDynamicLabelFromStack:self.pencilTickIntervalStack].text = [NSString stringWithFormat:@"  %d μs  ", (uint16_t)sender.value];
}

- (void)pressureCurveSwitchFlipped:(UISwitch* )sender{
    if(sender.isOn && !settingsViewJustLoaded){
        PressureCurveViewController* pressureCurveVC = [[PressureCurveViewController alloc] init];
        pressureCurveVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.definesPresentationContext = true;
        [self presentViewController:pressureCurveVC animated:YES completion:nil];
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
    if([GenericUtils isIPad]){
        self.pencilTickSelector.selectedSegmentIndex = tempSettings.pencilTickMode.intValue;
        [self.pencilTickSelector addTarget:self action:@selector(pencilTickModeChanged:) forControlEvents:UIControlEventValueChanged];
        [self pencilTickModeChanged:self.pencilTickSelector];
        
        [self.pencilTickIntervalSlider setValue:tempSettings.pencilTickIntervalUs.floatValue];
        [self.pencilTickIntervalSlider addTarget:self action:@selector(pencilTickIntervalSliderMoved:) forControlEvents:UIControlEventValueChanged];
        [self pencilTickIntervalSliderMoved:self.pencilTickIntervalSlider];
        
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
    if([GenericUtils isIPad]){
        currentSettings.pencilTickMode = @(self.pencilTickSelector.selectedSegmentIndex);
        currentSettings.pencilTickIntervalUs = @(self.pencilTickIntervalSlider.value);
    }
}

- (void) saveSettings {
    [self preSavingActions];

    Settings* currentSettings = [dataMan retrieveSettings];
    
    [self populatePencilSettings:currentSettings];
    
    CGFloat settingsMenuOffset = _rememberFoldStateSwitch.isOn ? _scrollView.contentOffset.y : 0;
    
    NSInteger height = self.mainFrameViewController.settingsExpandedInStreamView ? currentSettings.height.intValue : [self getChosenStreamHeight];
    NSInteger width = self.mainFrameViewController.settingsExpandedInStreamView ? currentSettings.width.intValue : [self getChosenStreamWidth];
    
    NSInteger framerate = [self getChosenFrameRate];

    NSInteger audioConfig = [@[@2, @3, @6, @8][[self.audioConfigSelector selectedSegmentIndex]] integerValue];
    // 2 - stereo (system)
    // 3 - stereo (SDL)
    // 6 - 5.1 (SDL)
    // 8 - 7.1 (SDL)

    NSInteger renderingBackend = [self.renderingBackendSelector selectedSegmentIndex];
    NSInteger framePacingMode = [self.framePacingModeSelector selectedSegmentIndex];
    NSInteger onscreenControls = [self.onScreenWidgetSelector selectedSegmentIndex];
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

    uint16_t touchMoveEventInterval = (uint16_t)self.touchMoveEventIntervalSlider.value;

    BOOL reverseMouseWheelDirection = [self.reverseMouseWheelDirectionSelector selectedSegmentIndex] == 1;
    NSInteger asyncNativeTouchPriority = 1;
    //BOOL liftStreamViewForKeyboard = [self.liftStreamViewForKeyboardSelector selectedSegmentIndex] == 1;
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
    NSInteger touchMode = [self isNotNativeTouchOnly] ? self.touchModeSelector1.selectedSegmentIndex : NativeTouchOnly;
    NSInteger statsOverlayLevel = [self.statsOverlaySelector selectedSegmentIndex];
    BOOL statsOverlayEnabled = statsOverlayLevel != 0;
    BOOL enableHdr = self.hdrSwitch.isOn;
    BOOL unlockDisplayOrientation = [self.unlockDisplayOrientationSelector selectedSegmentIndex] == 1;
    BOOL enableGraphs = self.enableGraphsSwitch.isOn;
    int graphOpacity = (int)self.graphOpacityStepper.value;
    int frameQueueSize = (int)self.frameQueueSizeSlider.value;
    NSInteger resolutionSelected = [self.resolutionSelector selectedSegmentIndex];
    if (self.customResolutionSwitch.isOn) {
        resolutionSelected = RESOLUTION_TABLE_CUSTOM_INDEX;
    }
    NSInteger externalDisplayMode = [self.externalDisplayModeSelector selectedSegmentIndex];
    NSInteger localMousePointerMode = [self.localMousePointerModeSelector selectedSegmentIndex];
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
    BOOL mapControllerToMouse = self.controllerToMouseSwitch.isOn;
    CGFloat controllerMousePointerVelocity = self.controllerMouseVelocitySlider.value;
    CGFloat controllerMouseExpo = self.controllerMouseExpoSlider.value;
    NSInteger controllerGyroSwitchMode = self.controllerGyroSwitchButtonSetter.selectedSegmentIndex;
    BOOL enableFrameTimebase = false;
    BOOL asyncFrameDequeue = self.asyncFrameDequeueSwitch.isOn;
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
                mapControllerToMouse:mapControllerToMouse
      controllerMousePointerVelocity:controllerMousePointerVelocity
                 controllerMouseExpo:controllerMouseExpo
            controllerGyroSwitchMode:controllerGyroSwitchMode
                 enableFrameTimebase:enableFrameTimebase
                   asyncFrameDequeue:asyncFrameDequeue
            sdrPerformanceWorkaround:sdrPerformanceWorkaround
              backgroundSessionTimer:backgroundSessionTimer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

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

@end
