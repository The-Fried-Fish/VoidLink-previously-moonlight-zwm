//
//  SettingsViewController.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.1
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "CustomOSCViewControl/LayoutOnScreenControlsViewController.h"
#import "MainFrameViewController.h"
#import "CustomEdgeSlideGestureRecognizer.h"
#import "MenuSectionView.h"

@interface SettingsViewController : UIViewController <RearNavigationBarMenuDelegate, MenuSectionDelegate>
@property (strong, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (strong, nonatomic) UIStackView *parentStack;
@property (strong, nonatomic) IBOutlet UIStackView *resolutionStack;
@property (strong, nonatomic) IBOutlet UIStackView *fpsStack;
@property (strong, nonatomic) IBOutlet UIStackView *bitrateStack;
@property (strong, nonatomic) IBOutlet UIStackView *touchModeStack;
@property (strong, nonatomic) IBOutlet UIStackView *enableOswSwitchStack;
//@property (strong, nonatomic) IBOutlet UIStackView *asyncTouchStack;
@property (strong, nonatomic) IBOutlet UISwitch *optimizeGamesSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *pointerVelocityDividerStack;
@property (strong, nonatomic) IBOutlet UIStackView *pointerVelocityFactorStack;
@property (strong, nonatomic) IBOutlet UIStackView *touchMoveEventIntervalStack;
@property (strong, nonatomic) IBOutlet UIStackView *mousePointerVelocityStack;
@property (strong, nonatomic) IBOutlet UIStackView *onScreenWidgetStack;
@property (strong, nonatomic) IBOutlet UIStackView *softKeyboardGestureStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *softKeyboardGestureSelector;
@property (strong, nonatomic) IBOutlet UIStackView *liftStreamViewForKeyboardStack;
@property (strong, nonatomic) IBOutlet UIStackView *softKeyboardToolbarStack;
@property (strong, nonatomic) IBOutlet UISwitch *softKeyboardToolbarSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *slideToSettingsScreenEdgeStack;
@property (strong, nonatomic) IBOutlet UIStackView *slideToToolboxScreenEdgeStack;
@property (strong, nonatomic) IBOutlet UIStackView *slideToSettingsDistanceStack;
@property (strong, nonatomic) IBOutlet UIStackView *optimizeGamesStack;
@property (strong, nonatomic) IBOutlet UIStackView *multiControllerStack;
@property (strong, nonatomic) IBOutlet UISwitch *multiControllerSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *swapAbaxyStack;
@property (strong, nonatomic) IBOutlet UIStackView *audioOnPcStack;
@property (strong, nonatomic) IBOutlet UISwitch *audioOnPcSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *codecStack;
@property (strong, nonatomic) IBOutlet UIStackView *yuv444Stack;
@property (strong, nonatomic) IBOutlet UIStackView *pipStack;
@property (strong, nonatomic) IBOutlet UIStackView *HdrStack;
@property (strong, nonatomic) IBOutlet UIStackView *framepacingStack;
@property (strong, nonatomic) IBOutlet UIStackView *reverseMouseWheelDirectionStack;
@property (strong, nonatomic) IBOutlet UIStackView *citrixX1MouseStack;
@property (strong, nonatomic) IBOutlet UISwitch *citrixX1MouseSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *statsOverlayStack;
@property (strong, nonatomic) IBOutlet UIStackView *unlockDisplayOrientationStack;
@property (strong, nonatomic) IBOutlet UIStackView *externalDisplayModeStack;
@property (strong, nonatomic) IBOutlet UIStackView *localMousePointerModeStack;

@property (strong, nonatomic) IBOutlet UILabel *bitrateLabel;
@property (strong, nonatomic) IBOutlet UISlider *bitrateSlider;
@property (strong, nonatomic) IBOutlet UISegmentedControl *framerateSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *resolutionSelector;
@property (strong, nonatomic) IBOutlet UISwitch *customResolutionSwitch;
@property (strong, nonatomic) IBOutlet UILabel *touchModeLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *touchModeSelector;
@property (strong, nonatomic) IBOutlet UISwitch *enableOswForNativeTouchSwitch;
@property (strong, nonatomic) IBOutlet UILabel *onscreenControllerLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *onScreenWidgetSelector;
//@property (strong, nonatomic) IBOutlet UISegmentedControl *asyncNativeTouchPrioritySelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *swapABXYButtonsSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *codecSelector;
@property (strong, nonatomic) IBOutlet UISwitch *hdrSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *yuv444Switch;
@property (strong, nonatomic) IBOutlet UISwitch *pipSwitch;
@property (strong, nonatomic) IBOutlet UISegmentedControl *framePacingSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *reverseMouseWheelDirectionSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *statsOverlaySelector;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UISegmentedControl *liftStreamViewForKeyboardSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *slideToSettingsScreenEdgeSelector;

@property (strong, nonatomic) IBOutlet UILabel *touchMoveEventIntervalLabel;
@property (strong, nonatomic) IBOutlet UISlider *touchMoveEventIntervalSlider;
@property (strong, nonatomic) IBOutlet UILabel *slideToSettingsScreenEdgeUILabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *slideToToolboxScreenEdgeSelector;
@property (strong, nonatomic) IBOutlet UILabel *slideToSettingsDistanceUILabel;
@property (strong, nonatomic) IBOutlet UISlider *slideToMenuDistanceSlider;
@property (strong, nonatomic) IBOutlet UISlider *pointerVelocityModeDividerSlider;
@property (strong, nonatomic) IBOutlet UILabel *pointerVelocityModeDividerUILabel;
@property (strong, nonatomic) IBOutlet UISlider *touchPointerVelocityFactorSlider;
@property (strong, nonatomic) IBOutlet UILabel *touchPointerVelocityFactorUILabel;
@property (strong, nonatomic) IBOutlet UISlider *mousePointerVelocityFactorSlider;
@property (strong, nonatomic) IBOutlet UILabel *mousePointerVelocityFactorUILabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *unlockDisplayOrientationSelector;
@property (strong, nonatomic) LayoutOnScreenControlsViewController *layoutOnScreenControlsVC;
@property (nonatomic, strong) MainFrameViewController *mainFrameViewController;

@property (strong, nonatomic) IBOutlet UISegmentedControl *externalDisplayModeSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *localMousePointerModeSelector;

@property (strong, nonatomic) IBOutlet UIStackView *gyroModeStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *gyroModeSelector;
@property (strong, nonatomic) IBOutlet UIStackView *gyroSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *gyroSensitivitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *audioConfigStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *audioConfigSelector;

@property (strong, nonatomic) IBOutlet UIStackView *backgroundSessionTimerStack;
@property (strong, nonatomic) IBOutlet UISlider *backgroundSessionTimerSlider;



#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

// This is okay because it's just an enum and access uses @available checks
@property(nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;

#pragma clang diagnostic pop

- (void)saveSettings;
+ (bool)isLandscapeNow;
- (void)updateResolutionTable;
- (void)widget:(UISlider*)widget setEnabled:(bool)enabled;
- (void)updateTheme;
- (void)hideDynamicLabelsWhenOverlapped:(UIView* )view;
- (void)setHidden:(BOOL)hidden forStack:(UIStackView* )stack;

@end
