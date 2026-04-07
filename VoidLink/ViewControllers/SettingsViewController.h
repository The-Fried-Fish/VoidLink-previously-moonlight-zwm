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
#import "MainFrameViewController.h"
#import "CustomEdgeSlideGestureRecognizer.h"
#import "MenuSectionView.h"

@class LayoutOnScreenControlsViewController;
@class MicHandler;
@class WidgetPickerViewController;
@protocol WidgetPickerViewControllerDelegate;

@interface SettingsViewController : UIViewController <RearNavigationBarMenuDelegate, MenuSectionDelegate, UITextFieldDelegate, WidgetPickerViewControllerDelegate>

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
@property (strong, nonatomic) IBOutlet UIStackView *swapAbxyStack;
@property (strong, nonatomic) IBOutlet UIStackView *audioOnPcStack;
@property (strong, nonatomic) IBOutlet UISwitch *audioOnPcSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *codecStack;
@property (strong, nonatomic) IBOutlet UIStackView *yuv444Stack;
@property (strong, nonatomic) IBOutlet UIStackView *pipStack;
@property (strong, nonatomic) IBOutlet UIStackView *fullColorRangeStack;
@property (strong, nonatomic) IBOutlet UIStackView *hdrStack;
@property (strong, nonatomic) IBOutlet UIStackView *reverseMouseWheelDirectionStack;
@property (strong, nonatomic) IBOutlet UIStackView *citrixX1MouseStack;
@property (strong, nonatomic) IBOutlet UISwitch *citrixX1MouseSwitch;
@property (strong, nonatomic) IBOutlet UIStackView *statsOverlayStack;
@property (strong, nonatomic) IBOutlet UIStackView *unlockDisplayOrientationStack;
@property (strong, nonatomic) IBOutlet UIStackView *externalDisplayModeStack;
@property (strong, nonatomic) IBOutlet UIStackView *localMousePointerModeStack;
@property (strong, nonatomic) IBOutlet UIStackView *renderingBackendStack;
@property (strong, nonatomic) IBOutlet UIStackView *framePacingStack;
@property (strong, nonatomic) IBOutlet UIStackView *frameQueueSizeStack;
@property (strong, nonatomic) IBOutlet UIStackView *performanceGraphStack;

@property (strong, nonatomic) IBOutlet UILabel *bitrateLabel;
@property (strong, nonatomic) IBOutlet UISlider *bitrateSlider;
@property (strong, nonatomic) IBOutlet UISegmentedControl *framerateSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *resolutionSelector;
@property (strong, nonatomic) IBOutlet UISwitch *customResolutionSwitch;
@property (strong, nonatomic) IBOutlet UILabel *touchModeLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *touchModeSelector1;
@property (strong, nonatomic) IBOutlet UISwitch *enableOswForNativeTouchSwitch;
@property (strong, nonatomic) IBOutlet UILabel *onscreenControllerLabel;
@property (strong, nonatomic) IBOutlet UISegmentedControl *onScreenWidgetSelector;
//@property (strong, nonatomic) IBOutlet UISegmentedControl *asyncNativeTouchPrioritySelector;
@property (strong, nonatomic) IBOutlet UISwitch *swapAbxySwitch;
@property (strong, nonatomic) IBOutlet UISegmentedControl *codecSelector;
@property (strong, nonatomic) IBOutlet UISwitch *hdrSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *yuv444Switch;
@property (strong, nonatomic) IBOutlet UISwitch *pipSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *fullColorRangeSwitch;
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

@property (strong, nonatomic) IBOutlet UILabel *frameQueueSizeLabel;
@property (strong, nonatomic) IBOutlet UISlider *frameQueueSizeSlider;

@property (strong, nonatomic) IBOutlet UILabel *enableGraphsLabel;
@property (strong, nonatomic) IBOutlet UISwitch *enableGraphsSwitch;
@property (strong, nonatomic) IBOutlet UIStepper *graphOpacityStepper;
@property (strong, nonatomic) IBOutlet UIStackView *graphOpacityStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *renderingBackendSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *framePacingModeSelector;

@property (strong, nonatomic) IBOutlet UIStackView *backgroundSessionTimerStack;
@property (strong, nonatomic) IBOutlet UISlider *backgroundSessionTimerSlider;

@property (strong, nonatomic) IBOutlet UIStackView *emulatedControllerTypeStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *emulatedControllerTypeSelector;

@property (strong, nonatomic) IBOutlet UIStackView *redirectMicStack;
@property (strong, nonatomic) IBOutlet UISwitch *redirectMicSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *buttonVisualFeedbackStack;
@property (strong, nonatomic) IBOutlet UISwitch *buttonVisualFeedbackSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *sendDummyEventStack;
@property (strong, nonatomic) IBOutlet UISwitch *sendDummyEventSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *localVolumeStack;
@property (strong, nonatomic) IBOutlet UISlider *localVolumeSlider;

@property (strong, nonatomic) IBOutlet UIStackView *useBuiltinMicStack;
@property (strong, nonatomic) IBOutlet UISwitch *useBuiltinMicSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *micVolumeStack;
@property (strong, nonatomic) IBOutlet UISlider *micVolumeSlider;

@property (strong, nonatomic) IBOutlet UIStackView *rememberFoldStateStack;
@property (strong, nonatomic) IBOutlet UISwitch *rememberFoldStateSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *mapGyroToStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *mapGyroToSelector;

@property (strong, nonatomic) IBOutlet UIStackView *gyroToStickSwitchStack;
@property (strong, nonatomic) IBOutlet UISwitch *yawPitchToRightStickSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *rollToLeftStickSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *yawPitchSensitivityStack;
@property (strong, nonatomic) IBOutlet UIStackView *yawSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *yawSensitivitySlider;
@property (strong, nonatomic) IBOutlet UIStackView *pitchSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *pitchSensitivitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *rollSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *rollSensitivitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *gyroToStickMinOffsetStack;
@property (strong, nonatomic) IBOutlet UISlider *gyroToStickMinOffsetSlider;

@property (strong, nonatomic) IBOutlet UIStackView *singleTapSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *singleTapSensitivitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *hapticEngineStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *hapticEngineSelector;

@property (strong, nonatomic) IBOutlet UIStackView *edgeSlidingSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *edgeSlidingSensitivitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *appThemeStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *appThemeSelector;

@property (strong, nonatomic) IBOutlet UIStackView *audioEngineStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *audioEngineSelector;

@property (strong, nonatomic) IBOutlet UIStackView *delayLeftClickStack;
@property (strong, nonatomic) IBOutlet UISwitch *delayLeftClickSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *duckOtherAppStack;
@property (strong, nonatomic) IBOutlet UISwitch *duckOtherAppSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *muteInBackgroundStack;
@property (strong, nonatomic) IBOutlet UISwitch *muteInBackgroundSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *relativeTouchSlideThresholdStack;
@property (strong, nonatomic) IBOutlet UISlider *relativeTouchSlideThresholdSlider;

@property (strong, nonatomic) IBOutlet UIStackView *pinchGestureStack;
@property (strong, nonatomic) IBOutlet UISwitch *pinchGestureSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *scrollSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *scrollSensitivitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *pinchSensitivityStack;
@property (strong, nonatomic) IBOutlet UISlider *pinchSensitivitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *touchModeStack2;
@property (strong, nonatomic) IBOutlet UISegmentedControl *touchModeSelector2;

@property (strong, nonatomic) IBOutlet UIStackView *ctrlDownForPinchStack;
@property (strong, nonatomic) IBOutlet UISwitch *ctrlDownForPinchSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *leftClickDelayStack;
@property (strong, nonatomic) IBOutlet UISlider *leftClickDelaySlider;

@property (strong, nonatomic) IBOutlet UIStackView *passthroughGesturesStack;
@property (strong, nonatomic) IBOutlet UISwitch *passthroughGesturesSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *softKeyboardHeightStack;
@property (weak, nonatomic) IBOutlet UISwitch *softKeyboardHeightSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *controllerToMouseStack;
@property (strong, nonatomic) IBOutlet UISwitch *controllerToMouseSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *controllerMouseVelocityStack;
@property (strong, nonatomic) IBOutlet UISlider *controllerMouseVelocitySlider;

@property (strong, nonatomic) IBOutlet UIStackView *controllerMouseExpoStack;
@property (strong, nonatomic) IBOutlet UISlider *controllerMouseExpoSlider;

@property (strong, nonatomic) IBOutlet UIStackView *controllerGyroSwitchButtonStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *controllerGyroSwitchButtonSetter;

@property (strong, nonatomic) IBOutlet UIStackView *synthPhysicalInputStack;
@property (strong, nonatomic) IBOutlet UISwitch *synthPhysicalInputSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *reverseHoldButtonStack;
@property (strong, nonatomic) IBOutlet UISwitch *reverseHoldButtonSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *leftStickMinOffsetStack;
@property (strong, nonatomic) IBOutlet UISlider *leftStickMinOffsetSlider;

@property (strong, nonatomic) IBOutlet UIStackView *rightStickMinOffsetStack;
@property (strong, nonatomic) IBOutlet UISlider *rightStickMinOffsetSlider;

@property (strong, nonatomic) IBOutlet UIStackView *pressureCurveStack;
@property (strong, nonatomic) IBOutlet UISwitch *pressureCurveSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *frameTimebaseStack;
@property (weak, nonatomic) IBOutlet UISwitch *frameTimebaseSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *asyncFrameDequeueStack;
@property (weak, nonatomic) IBOutlet UISwitch *asyncFrameDequeueSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *sdrPerformanceWorkaroundStack;
@property (weak, nonatomic) IBOutlet UISwitch *sdrPerformanceWorkaroundSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *trackTouchPointStack;
@property (weak, nonatomic) IBOutlet UISwitch *trackTouchPointSwitch;

@property (strong, nonatomic) IBOutlet UIStackView *testStack;


@property (nonatomic, strong) MicHandler *micHandler;



@property (strong, nonatomic) IBOutlet UIStackView *pencilTickStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *pencilTickSelector;

@property (strong, nonatomic) IBOutlet UIStackView *pencilTickIntervalStack;
@property (strong, nonatomic) IBOutlet UISlider *pencilTickIntervalSlider;

@property (weak, nonatomic) IBOutlet UIStackView *doubleTapShortcutStack;
@property (weak, nonatomic) IBOutlet UISwitch *doubleTapShortcutSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *squeezeShortcutStack;
@property (weak, nonatomic) IBOutlet UISwitch *squeezeShortcutSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *pencilPausesNativeTouchStack;
@property (weak, nonatomic) IBOutlet UISwitch *pencilPausesNativeTouchSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *disablePencilSlideGestureStack;
@property (weak, nonatomic) IBOutlet UISwitch *disablePencilSlideGestureSwitch;

@property (weak, nonatomic) IBOutlet UIStackView *hoverModeStack;
@property (weak, nonatomic) IBOutlet UISegmentedControl *hoverModeSelector;



#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

// This is okay because it's just an enum and access uses @available checks
@property(nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;

#pragma clang diagnostic pop

- (bool)hdrSupported;
- (void)saveSettings;
+ (bool)isLandscapeNow;
- (void)updateResolutionTable;
- (void)widget:(UIView*)widget setEnabled:(bool)enabled;
- (void)updateTheme;
- (void)hideDynamicLabelsWhenOverlapped:(UIView* )view;
- (void)setHidden:(BOOL)hidden forStack:(UIStackView* )stack;
- (void)updateCodecDependentSwitches;

@end
