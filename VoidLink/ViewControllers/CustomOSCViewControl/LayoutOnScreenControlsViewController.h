//
//  LayoutOnScreenControlsViewController.h
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LayoutOnScreenControls.h"
#import "ToolBarContainerView.h"
#import "OSCProfilesManager.h"
#import "OSCProfilesTableViewController.h"
#import "VoidLink-Swift.h"

NS_ASSUME_NONNULL_BEGIN

/**
 This view controller provides the user interface which allows the user to position on screen controller buttons anywhere they'd like on the screen. It also provides the user with the abilities to undo a change, save the on screen controller layout for later retrieval, and load previously saved controller layouts
 */
@interface LayoutOnScreenControlsViewController : UIViewController <OnScreenWidgetGuidelineUpdateDelegate>
- (void)profileRefresh;
- (void)reloadOnScreenWidgetViews;
- (void)presentProfilesTableView;

@property LayoutOnScreenControls *layoutOSC;    // object that contains a view which contains the on screen controller buttons that allows the user to drag and positions each button on the screen using touch
@property (nonatomic) NSMutableSet* onScreenWidgetViews;

@property int OSCSegmentSelected;
@property (nonatomic, assign) bool quickSwitchEnabled;

@property (weak, nonatomic) IBOutlet UIButton *trashCanButton;
@property (weak, nonatomic) IBOutlet UIButton *undoButton;

@property (weak, nonatomic) IBOutlet ToolBarContainerView *toolbarRootView;
@property (weak, nonatomic) IBOutlet UIView *chevronView;
@property (weak, nonatomic) IBOutlet UIImageView *chevronImageView;
@property (weak, nonatomic) IBOutlet UIStackView *toolbarStackView;
@property (strong, nonatomic) OSCProfilesTableViewController *oscProfilesTableViewController;

@property (nonatomic, assign) NSString *currentProfileName;
@property (strong, nonatomic) IBOutlet UILabel *currentProfileLabel;

@property (weak, nonatomic) IBOutlet UILabel *widgetSizeLabel;
@property (weak, nonatomic) IBOutlet UISlider *widgetSizeSlider;
@property (weak, nonatomic) IBOutlet UIStackView *widgetSizeStack;

@property (weak, nonatomic) IBOutlet UILabel *widgetHeightLabel;
@property (weak, nonatomic) IBOutlet UISlider *widgetHeightSlider;

@property (weak, nonatomic) IBOutlet UIStackView *widgetHeightStack;

@property (weak, nonatomic) IBOutlet UILabel *widgetBorderWidthLabel;
@property (weak, nonatomic) IBOutlet UISlider *widgetBorderWidthSlider;
@property (weak, nonatomic) IBOutlet UILabel *widgetAlphaLabel;
@property (weak, nonatomic) IBOutlet UISlider *widgetAlphaSlider;
@property (weak, nonatomic) IBOutlet UIStackView *borderWidthAlphaStack;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;
@property (weak, nonatomic) IBOutlet UIButton *exitButton;
@property (weak, nonatomic) IBOutlet UIButton *loadButton;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIButton *editButton;




@property (weak, nonatomic) IBOutlet UILabel *stickIndicatorOffsetLabel;
@property (weak, nonatomic) IBOutlet UISlider *stickIndicatorOffsetSlider;
@property (weak, nonatomic) IBOutlet UIStackView *stickIndicatorOffsetStack;

@property (weak, nonatomic) IBOutlet UILabel *sensitivityXLabel;
@property (weak, nonatomic) IBOutlet UISlider *sensitivityXSlider;
@property (weak, nonatomic) IBOutlet UIStackView *sensitivityXStack;
@property (strong, nonatomic) IBOutlet UILabel *sensitivityYLabel;
@property (strong, nonatomic) IBOutlet UISlider *sensitivityYSlider;
@property (strong, nonatomic) IBOutlet UIStackView *sensitivityYStack;

@property (strong, nonatomic) IBOutlet UIStackView *decelerationRateStack;
@property (strong, nonatomic) IBOutlet UILabel *decelerationRateLabel;
@property (strong, nonatomic) IBOutlet UISlider *decelerationRateSlider;




@property (strong, nonatomic) IBOutlet UISegmentedControl *vibrationStyleSelector;
@property (strong, nonatomic) IBOutlet UIStackView *vibrationStyleStack;

@property (strong, nonatomic) IBOutlet UILabel *loadConfigTipLabel;

@property (strong, nonatomic) IBOutlet UIStackView *mouseDownButtonStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *mouseButtonDownSelector;

@property (strong, nonatomic) IBOutlet UIStackView *slidableStack;
@property (strong, nonatomic) IBOutlet UISegmentedControl *slidableSelector;



@property (weak, nonatomic) IBOutlet UIStackView *widgetPanelStack;


@end


NS_ASSUME_NONNULL_END
