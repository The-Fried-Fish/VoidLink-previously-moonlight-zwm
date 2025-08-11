//
//  LayoutOnScreenControlsViewController.m
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "LayoutOnScreenControlsViewController.h"
#import "OSCProfilesTableViewController.h"
#import "OnScreenButtonState.h"
//#import "OnScreenControls.h"
#import "OSCProfilesManager.h"
#import "LocalizationHelper.h"
#import "VoidLink-Swift.h"
#import "ThemeManager.h"

@interface LayoutOnScreenControlsViewController ()

@end


@implementation LayoutOnScreenControlsViewController {
    BOOL isToolbarHidden;
    OSCProfilesManager* profilesManager;
    OnScreenWidgetView* selectedWidgetView;
    CALayer* selectedControllerLayer;
    CGRect controllerLoadedBounds;
    bool widgetViewSelected;
    bool controllerLayerSelected;
    bool viewWillBeResized;
    __weak IBOutlet NSLayoutConstraint *toolbarTopConstraintiPhone;
    __weak IBOutlet NSLayoutConstraint *toolbarTopConstraintiPad;
    UIColor* trashCanStoryBoardColor;
    BOOL widgetPanelMovedByTouch;
    CGPoint widgetPanelStoredCenter;
    CGPoint latestTouchLocation;
    UIImpactFeedbackGenerator *vibrationGenerator;
}

@synthesize trashCanButton;
@synthesize undoButton;
@synthesize OSCSegmentSelected;
@synthesize toolbarRootView;
@synthesize chevronView;
@synthesize chevronImageView;

- (UIInterfaceOrientationMask)getCurrentOrientation{
    CGFloat screenHeightInPoints = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    CGFloat screenWidthInPoints = CGRectGetWidth([[UIScreen mainScreen] bounds]);
    //lock the orientation accordingly after streaming is started
    if(screenWidthInPoints > screenHeightInPoints) return UIInterfaceOrientationMaskLandscape;
    else return UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // Return the supported interface orientations acoordingly
    return [self getCurrentOrientation]; // 90 Degree rotation not allowed in streaming or app view
}

- (void) viewWillDisappear:(BOOL)animated{
    OnScreenWidgetView.editMode = false;
    for (OnScreenWidgetView* widgetView in self.onScreenWidgetViews){
        [widgetView.stickBallLayer removeFromSuperlayer];
        [widgetView.crossMarkLayer removeFromSuperlayer];
    }
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OscLayoutCloseNotification" object:self];
}

- (CGPoint)denormalizeWidgetPosition:(CGPoint)position {
    // NSLog(@"position: %f, %f", position.x, position.y);
    CGPoint newPosition = position;
    if(position.x < 1.0 && position.y < 1.0){
        newPosition.x = position.x * self.view.bounds.size.width;
        newPosition.y = position.y * self.view.bounds.size.height;
    }
    return newPosition;
}

- (void)reloadLegacyOnScreenControls{
    [self.layoutOSC updateControls];  // creates and saves a 'Default' OSC profile or loads the o//ne the user selected on the previous screen
    [self addInnerAnalogSticksToOuterAnalogLayers];
    [self.layoutOSC.layoutChanges removeAllObjects];  // since a new OSC profile is being loaded, this will remove all previous layout changes made from the array
    [self OSCLayoutChanged];    // fades the 'Undo Button' out
}

- (void)reloadOnScreenWidgetViews{
    NSLog(@"reloadOnScreenWidgets %f", CACurrentMediaTime());
    OnScreenWidgetView.editMode = true;
    [self clearStickIndicator];

    for (UIView *subview in self.view.subviews) {
        if ([subview isKindOfClass:[OnScreenWidgetView class]]) {
            [subview removeFromSuperview];
        }
    }
    
    [self.onScreenWidgetViews removeAllObjects];

    
    NSLog(@"reload os Key here");
    
    // _activeCustomOscButtonPositionDict will be updated every time when the osc profile is reloaded
    OSCProfile *oscProfile = [profilesManager getSelectedProfile]; //returns the currently selected OSCProfile
    for (NSData *buttonStateEncoded in oscProfile.buttonStates) {
        // OnScreenButtonState* buttonState = [NSKeyedUnarchiver unarchivedObjectOfClass:[OnScreenButtonState class] fromData:buttonStateEncoded error:nil];
        OnScreenButtonState* buttonState = [profilesManager unarchiveButtonStateEncoded:buttonStateEncoded];
        if(buttonState.buttonType == CustomOnScreenWidget){
            OnScreenWidgetView* widgetView = [[OnScreenWidgetView alloc] initWithCmdString:buttonState.name buttonLabel:buttonState.alias shape:buttonState.widgetShape]; //reconstruct widgetView
            widgetView.guidelineDelegate = (id<OnScreenWidgetGuidelineUpdateDelegate>)self;
            widgetView.translatesAutoresizingMaskIntoConstraints = NO; // weird but this is mandatory, or you will find no key views added to the right place
            widgetView.widthFactor = buttonState.widthFactor;
            widgetView.heightFactor = buttonState.heightFactor;
            widgetView.borderWidth = buttonState.borderWidth;
            [widgetView setVibrationWithStyle:buttonState.vibrationStyle];
            widgetView.mouseButtonAction = buttonState.mouseButtonAction;
            widgetView.sensitivityFactorX = buttonState.sensitivityFactorX;
            widgetView.sensitivityFactorY = buttonState.sensitivityFactorY;
            widgetView.trackballDecelerationRate = buttonState.decelerationRate;
            widgetView.stickIndicatorOffset = buttonState.stickIndicatorOffset;
            widgetView.minStickOffset = buttonState.minStickOffset;
            widgetView.slideMode = buttonState.slideMode;
            // Add the widgetView to the view controller's view
            [self.view insertSubview:widgetView belowSubview:self.widgetPanelStack];
            buttonState.position = [self denormalizeWidgetPosition:buttonState.position];
            [widgetView setLocationWithPosition:buttonState.position];
            [widgetView resizeWidgetView]; // resize must be called after relocation
            [widgetView adjustTransparencyWithAlpha:buttonState.backgroundAlpha];
            [widgetView adjustBorderWithWidth:buttonState.borderWidth];
            [self.onScreenWidgetViews addObject:widgetView];
        }
    }
}

- (void) viewDidLoad {
    [super viewDidLoad];
    profilesManager = [OSCProfilesManager sharedManager:self.view.bounds];
    self.onScreenWidgetViews = [[NSMutableSet alloc] init]; // will be revised to read persisted data , somewhere else
    [OSCProfilesManager setOnScreenWidgetViewsSet:self.onScreenWidgetViews];   // pass the keyboard button dict to profiles manager
    
    //isToolbarHidden = NO;   // keeps track if the toolbar is hidden up above the screen so that we know whether to hide or show it when the user taps the toolbar's hide/show button
    _quickSwitchEnabled = false;
    viewWillBeResized = false;
    
    /* add curve to bottom of chevron tab view */
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.chevronView.bounds byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight) cornerRadii:CGSizeMake(10.0, 10.0)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.view.bounds;
    maskLayer.path  = maskPath.CGPath;
    self.chevronView.layer.mask = maskLayer;
    
    /* Add swipe gesture to toolbar to allow user to swipe it up and off screen */
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(moveToolbar:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.toolbarRootView addGestureRecognizer:swipeUp];
    
    /* Add tap gesture to toolbar's chevron to allow user to tap it in order to move the toolbar on and off screen */
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(moveToolbar:)];
    [self.chevronView addGestureRecognizer:singleFingerTap];
    
    self.layoutOSC = [[LayoutOnScreenControls alloc] initWithView:self.view controllerSup:nil streamConfig:nil oscLevel:OSCSegmentSelected];
    self.layoutOSC._level = OnScreenControlsLevelCustom;
    self.layoutOSC.layoutToolVC = self;
    //[self.layoutOSC show];  // draw on screen controls
    [self.layoutOSC show];  // draw on screen controls

    [self addInnerAnalogSticksToOuterAnalogLayers]; // allows inner and analog sticks to be dragged together around the screen together as one unit which is the expected behavior
    
    self.undoButton.alpha = 0.3;    // no changes to undo yet, so fade out the undo button a bit
    
    NSMutableArray* allProfiles = [profilesManager getAllProfiles];
    /*
     if ([allProfiles count] == 0) { // if no saved OSC profiles exist yet then create one called 'Default' and associate it with Moonlight's legacy 'Full' OSC layout that's already been laid out on the screen at this point
     [profilesManager saveProfileWithName:@"Default" andButtonLayers:self.layoutOSC.OSCButtonLayers];
     [profilesManager importDefaultTemplates];
     }*/
    if (![profilesManager findProfileByName:DEFAULT_TEMPLATE_NAME1 inProfileArray:allProfiles]){
        [profilesManager importDefaultTemplates];
    }
        
    /* This will animate the toolbar with a subtle up and down motion intended to telegraph to the user that they can hide the toolbar if they wish*/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [UIView animateWithDuration:0.3
                              delay:0.25
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut animations:^{ // Animate toolbar up a a very small distance. Note the 0.35 time delay is necessary to avoid a bug that keeps animations from playing if the animation is presented immediately on a modally presented VC
            self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y - 25, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
        }
                         completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3
                                  delay:0
                 usingSpringWithDamping:0.7
                  initialSpringVelocity:1.0
                                options:UIViewAnimationOptionCurveEaseIn animations:^{ // Animate the toolbar back down that same distance
                self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y + 25, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
            }
                             completion:^(BOOL finished) {
                NSLog (@"done");
            }];
        }];
    });
    trashCanStoryBoardColor = trashCanButton.tintColor;
    self.toolbarRootView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.toolbarRootView.layer.shadowOffset = CGSizeMake(0, 0);
    self.toolbarRootView.layer.shadowOpacity = 0.5;
    self.toolbarRootView.layer.shadowRadius = 7;
    
    vibrationGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)viewDidDisappear:(BOOL)animated{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    OnScreenWidgetView.editMode = true;
    selectedWidgetView = nil;
    widgetPanelStoredCenter = self.widgetPanelStack.center;
    [super viewDidAppear:animated];
}

- (void)viewWillAppear:(BOOL)animated{
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(legacyOscLayerTapped:)
                                                 name:@"LegacyOscCALayerSelectedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleProfileTablViewDismiss)
                                                 name:@"OscLayoutTableViewCloseNotification"
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadOnScreenWidgetViews)
                                                 name:@"OscLayoutProfileSelctedInTableView"   // This is a special notification for reloading the on screen keyboard buttons. which can't be executed by _oscProfilesTableViewController.needToUpdateOscLayoutTVC code block, and has to be triggered by a notification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(widgetViewTapped:)
                                                 name:@"OnScreenWidgetViewSelected"
                                               object:nil];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OSCLayoutChanged) name:@"OSCLayoutChanged" object:nil];    // used to notifiy this view controller that the user made a change to the OSC layout so that the VC can either fade in or out its 'Undo button' which will signify to the user whether there are any OSC layout changes to undo
        
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleReturnToForeground)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnterBackground)
                                                 name: UIApplicationWillResignActiveNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange) // handle orientation change since i made portrait mode available
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    OnScreenWidgetView.editMode = true;
    [self handleMissingToolBarIcon:toolbarRootView];
    [self profileRefresh];
}

#pragma mark - Class Helper Functions

- (void)updateViewBounds{
    viewWillBeResized = false;
    selectedWidgetView = nil;
    selectedControllerLayer = nil;

    _oscProfilesTableViewController.layoutViewBounds = self.view.bounds;
    [OSCProfilesManager setOnScreenWidgetViewsSet:self.onScreenWidgetViews];   // pass the keyboard button dict to profiles manager
    [self reloadOnScreenWidgetViews];
    [self reloadLegacyOnScreenControls];
}

- (void)handleEnterBackground{
    [self saveTapped:nil];
}

- (void)handleReturnToForeground {
    // [OSCProfilesManager setOnScreenWidgetViewsSet:self.onScreenWidgetViews];   // pass the keyboard button dict to profiles manager
    [self setupWidgetPanel];
    [self updateViewBounds];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
    viewWillBeResized = true;
    [self clearStickIndicator];
    if(!_quickSwitchEnabled) [self saveTapped:nil];
}

- (void)deviceOrientationDidChange{
    [self performSelector:@selector(handleOrientationChangeForOnScreenWidgets) withObject:self afterDelay:0.0];
}

- (void)handleOrientationChangeForOnScreenWidgets{
    if(!viewWillBeResized) return;
    [self setupWidgetPanel];
    [self updateViewBounds];
}

/* fades the 'Undo Button' in or out depending on whether the user has any OSC layout changes to undo */
- (void) OSCLayoutChanged {
    if ([self.layoutOSC.layoutChanges count] > 0) {
        self.undoButton.alpha = 1.0;
    }
    else {
        self.undoButton.alpha = 0.3;
    }
}

/* animates the toolbar up and off the screen or back down onto the screen */
- (void) moveToolbar:(UISwipeGestureRecognizer *)sender {
    BOOL isPad = [[UIDevice currentDevice].model hasPrefix:@"iPad"];
    NSLayoutConstraint *toolbarTopConstraint = isPad ? self->toolbarTopConstraintiPad : self->toolbarTopConstraintiPhone;
    if (isToolbarHidden == NO) {
        [UIView animateWithDuration:0.2 animations:^{   // animates toolbar up and off screen
            toolbarTopConstraint.constant -= self.toolbarRootView.frame.size.height;
            [self.view layoutIfNeeded];
        }
        completion:^(BOOL finished) {
            if (finished) {
                self->isToolbarHidden = YES;
                self.chevronImageView.image = [UIImage imageNamed:@"ChevronCompactDown"];
            }
        }];
    }
    else {
        [UIView animateWithDuration:0.2 animations:^{   // animates the toolbar back down into the screen
            toolbarTopConstraint.constant += self.toolbarRootView.frame.size.height;
            [self.view layoutIfNeeded];
        }
        completion:^(BOOL finished) {
            if (finished) {
                self->isToolbarHidden = NO;
                self.chevronImageView.image = [UIImage imageNamed:@"ChevronCompactUp"];
            }
        }];
    }
}

/**
 * Makes the inner analog stick layers a child layer of its corresponding outer analog stick layers so that both the inner and its corresponding outer layers move together when the user drags them around the screen as is the expected behavior when laying out OSC. Note that this is NOT expected behavior on the game stream view where the inner analog sticks move to follow toward the user's touch and their corresponding outer analog stick layers do not move
 */
- (void)addInnerAnalogSticksToOuterAnalogLayers {
    // right stick
    [self.layoutOSC._rightStickBackground addSublayer: self.layoutOSC._rightStick];
    self.layoutOSC._rightStick.position = CGPointMake(self.layoutOSC._rightStickBackground.frame.size.width / 2, self.layoutOSC._rightStickBackground.frame.size.height / 2);
    
    // left stick
    [self.layoutOSC._leftStickBackground addSublayer: self.layoutOSC._leftStick];
    self.layoutOSC._leftStick.position = CGPointMake(self.layoutOSC._leftStickBackground.frame.size.width / 2, self.layoutOSC._leftStickBackground.frame.size.height / 2);
}


#pragma mark - UIButton Actions

- (IBAction) closeTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) trashCanTapped:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Delete Buttons Here"] message:[LocalizationHelper localizedStringForKey:@"Drag and drop buttons onto this trash can to remove them from the interface"] preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction) undoTapped:(id)sender {
    UIAlertController * nothingToUndoAlertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@"Nothing to Undo"] message: [LocalizationHelper localizedStringForKey: @"There are no changes to undo"] preferredStyle:UIAlertControllerStyleAlert];
    [nothingToUndoAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [nothingToUndoAlertController dismissViewControllerAnimated:NO completion:nil];
    }]];

    
    if(!widgetViewSelected){
        if([self.layoutOSC.layoutChanges count] > 0) { // check if there are layout changes to roll back to
            OnScreenButtonState *buttonState = [self.layoutOSC.layoutChanges lastObject];   //  Get the 'OnScreenButtonState' object that contains the name, position, and visiblity state of the button the user last moved
            
            CALayer *buttonLayer = [self.layoutOSC controllerLayerFromName:buttonState.name];   // get the on screen button layer that corresponds with the 'OnScreenButtonState' object that we retrieved above
            
            /* Set the button's position and visiblity to what it was before the user last moved it */
            buttonLayer.position = buttonState.position;
            buttonLayer.hidden = buttonState.isHidden;
            
            /* if user is showing or hiding dPad, then show or hide all four dPad button child layers as well since setting the 'hidden' property on the parent CALayer is not automatically setting the individual dPad child CALayers */
            if ([buttonLayer.name isEqualToString:@"dPad"]) {
                self.layoutOSC._upButton.hidden = buttonState.isHidden;
                self.layoutOSC._rightButton.hidden = buttonState.isHidden;
                self.layoutOSC._downButton.hidden = buttonState.isHidden;
                self.layoutOSC._leftButton.hidden = buttonState.isHidden;
            }
            
            /* if user is showing or hiding the left or right analog sticks, then show or hide their corresponding inner analog stick child layers as well since setting the 'hidden' property on the parent analog stick doesn't automatically hide its child inner analog stick CALayer */
            if ([buttonLayer.name isEqualToString:@"leftStickBackground"]) {
                self.layoutOSC._leftStick.hidden = buttonState.isHidden;
            }
            if ([buttonLayer.name isEqualToString:@"rightStickBackground"]) {
                self.layoutOSC._rightStick.hidden = buttonState.isHidden;
            }
            
            [self.layoutOSC.layoutChanges removeLastObject];
            
            [self OSCLayoutChanged]; // will fade the undo button in or out depending on whether there are any further changes to undo
        }
        else {  // there are no changes to undo. let user know there are no changes to undo
            [self presentViewController:nothingToUndoAlertController animated:YES completion:nil];
        }
    }
    else{
        NSInteger recordChangesCount = selectedWidgetView.layoutChanges.count;
        if(recordChangesCount>1) [selectedWidgetView undoRelocation];
        else [self presentViewController:nothingToUndoAlertController animated:YES completion:nil];
        self.undoButton.alpha = selectedWidgetView.layoutChanges.count>1 ? 1.0 : 0.3;
    }
}

- (void) presentInvalidWidgetCommandAlert{
    UIAlertController *savedAlertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@"Invalid Input"] message: [LocalizationHelper localizedStringForKey:@"Check the command and parameter."] preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *readInstruction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Read Widget Instruction"]
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action){
        //[self saveTapped:nil];
        NSURL *url = [NSURL URLWithString:[LocalizationHelper localizedStringForKey:@"onScreenWidgetStackDoc"]];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                           style:UIAlertActionStyleDefault
                                                     handler:nil];
    [savedAlertController addAction:readInstruction];
    [savedAlertController addAction:okAction];
    
    [self presentViewController:savedAlertController animated:YES completion:nil];
}

- (IBAction) addTapped:(id)sender{
    
    NSMutableDictionary* widgetInitParams = [NSMutableDictionary dictionary];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@""]
                                                                             message:[LocalizationHelper localizedStringForKey:@"New On-Screen Widget"]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Command"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Alias label (optional)"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Minimum stick offset (0~32766)"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Shape (r - round, s - square)"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
    }];


    UIAlertAction *readInstruction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Read Widget Instruction"]
                                                           style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action){
        //[self saveTapped:nil];
        NSURL *url = [NSURL URLWithString:[LocalizationHelper localizedStringForKey:@"onScreenWidgetStackDoc"]];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }];
    
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [widgetInitParams setObject: alertController.textFields[0].text forKey:@"cmdString"]; // convert to uppercase
        [widgetInitParams setObject: alertController.textFields[1].text forKey:@"buttonLabel"]; // convert to uppercase
        [widgetInitParams setObject: alertController.textFields[2].text forKey:@"minStickOffsetString"]; // convert to uppercase
        [widgetInitParams setObject: alertController.textFields[3].text forKey:@"shape"]; // convert to uppercase
        [self createWidgetFromParams:widgetInitParams];
    }];
    [alertController addAction:readInstruction];
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}


- (IBAction) editTapped:(id)sender{
    
    NSMutableDictionary* widgetInitParams = [NSMutableDictionary dictionary];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@""]
                                                                             message:[LocalizationHelper localizedStringForKey:@"Edit Selected Widget"]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    if(self->selectedWidgetView == nil) return;
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Command"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
        textField.text = [self->selectedWidgetView.cmdString lowercaseString];
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Alias label (optional)"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
        textField.text = self->selectedWidgetView.buttonLabel;
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Minimum stick offset (0~32766)"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
        if(self->selectedWidgetView.minStickOffset > 0) textField.text = [NSString stringWithFormat:@"%d", (int)self->selectedWidgetView.minStickOffset];
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [LocalizationHelper localizedStringForKey:@"Shape (r - round, s - square)"];
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
        textField.text = self->selectedWidgetView.shape;
        if([self->selectedWidgetView.shape isEqualToString: @"largeSquare"]) textField.enabled = false;
    }];
    

    UIAlertAction *createNewAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Create New"]
                                                           style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
        [widgetInitParams setObject: alertController.textFields[0].text forKey:@"cmdString"];
        [widgetInitParams setObject: alertController.textFields[1].text forKey:@"buttonLabel"];
        [widgetInitParams setObject: alertController.textFields[2].text forKey:@"minStickOffsetString"];
        [widgetInitParams setObject: alertController.textFields[3].text forKey:@"shape"];
        [self updateWidget:self->selectedWidgetView byParams:widgetInitParams createNew:true];
    }];

    UIAlertAction *modifyAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Modify"]
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [widgetInitParams setObject: alertController.textFields[0].text forKey:@"cmdString"];
        [widgetInitParams setObject: alertController.textFields[1].text forKey:@"buttonLabel"];
        [widgetInitParams setObject: alertController.textFields[2].text forKey:@"minStickOffsetString"];
        [widgetInitParams setObject: alertController.textFields[3].text forKey:@"shape"];
        [self updateWidget:self->selectedWidgetView byParams:widgetInitParams createNew:false];
    }];
    
    [alertController addAction:createNewAction];
    [alertController addAction:modifyAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (bool) isWidgetParamsValid:(NSMutableDictionary* )widgetInitParams{
    NSString *cmdString = [widgetInitParams[@"cmdString"] uppercaseString]; // convert to uppercase
    NSString *buttonLabel = widgetInitParams[@"buttonLabel"];
    NSString *minStickOffsetString = widgetInitParams[@"minStickOffsetString"];
    NSString *widgetShape = [widgetInitParams[@"shape"] lowercaseString];
        
    widgetInitParams[@"cmdString"] = cmdString;
    bool noValidKeyboardString = [CommandManager.shared extractKeyStringsFromComboCommandFrom:cmdString] == nil; // this is a invalid string.
    bool noValidSuperComboButtonString = [CommandManager.shared extractSinglCmdStringsFromComboKeysFrom:cmdString] == nil; // this is a invalid string.
    bool noValidMouseButtonString = ![CommandManager.mouseButtonMappings.allKeys containsObject:cmdString];
    bool noValidTouchPadString = ![CommandManager.touchPadCmds containsObject:cmdString];
    bool noValidOscButtonString = ![CommandManager.oscButtonMappings.allKeys containsObject:cmdString];
    bool noValidSpecialButtonString = ![CommandManager.specialOverlayButtonCmds containsObject:cmdString];
    bool paramInvalid = noValidKeyboardString && noValidMouseButtonString && noValidTouchPadString && noValidOscButtonString && noValidSpecialButtonString && noValidSuperComboButtonString;
    
    if([buttonLabel isEqualToString:@""]) widgetInitParams[@"buttonLabel"] = [[cmdString lowercaseString] capitalizedString];

    NSCharacterSet *nonDigitCharacterSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *trimmedString = [minStickOffsetString stringByTrimmingCharactersInSet:nonDigitCharacterSet];
    if(trimmedString.length != minStickOffsetString.length) paramInvalid = true;
    widgetInitParams[@"minStickOffsetString"] = trimmedString;
    
    NSSet* validShapes = [NSSet setWithObjects:@"round", @"square", @"largesquare", nil];
    if([widgetShape isEqualToString:@"r"]) widgetShape = @"round";
    else if([widgetShape isEqualToString:@"s"]) widgetShape = @"square";
    else if([widgetShape isEqualToString:@""]) widgetShape = @"default";
    else if(![validShapes containsObject:widgetShape]){
        paramInvalid = true;}
    widgetInitParams[@"shape"] = widgetShape;

    if(paramInvalid) [self presentInvalidWidgetCommandAlert];
    return !paramInvalid;
}

- (void) updateWidget:(OnScreenWidgetView* )widget byParams:(NSMutableDictionary* )widgetInitParams createNew:(bool)createNew{
    if(![self isWidgetParamsValid:widgetInitParams]) return;
    OnScreenWidgetView* newWidget = [[OnScreenWidgetView alloc] initWithCmdString:widgetInitParams[@"cmdString"] buttonLabel:widgetInitParams[@"buttonLabel"] shape:widgetInitParams[@"shape"]]; //reconstruct widgetView
    newWidget.guidelineDelegate = (id<OnScreenWidgetGuidelineUpdateDelegate>)self;
    newWidget.translatesAutoresizingMaskIntoConstraints = NO; // weird but this is mandatory, or you will find no key views added to the right place
    newWidget.widthFactor = widget.widthFactor;
    newWidget.heightFactor = widget.heightFactor;
    newWidget.borderWidth = widget.borderWidth;
    newWidget.sensitivityFactorX = widget.sensitivityFactorX;
    newWidget.sensitivityFactorY = widget.sensitivityFactorY;
    newWidget.trackballDecelerationRate = widget.trackballDecelerationRate;
    newWidget.stickIndicatorOffset = widget.stickIndicatorOffset;
    newWidget.minStickOffset = [widgetInitParams[@"minStickOffsetString"] floatValue];
    [newWidget setVibrationWithStyle:widget.vibrationStyle];
    newWidget.mouseButtonAction = widget.mouseButtonAction;
    newWidget.slideMode = widget.slideMode;
    [self.view insertSubview:newWidget belowSubview:self.widgetPanelStack];

    if(createNew) [newWidget setLocationWithPosition:CGPointMake(90, 130)];
    else [newWidget setLocationWithPosition:widget.center];
    [newWidget resizeWidgetView]; // resize must be called after relocation
    [newWidget adjustTransparencyWithAlpha:widget.backgroundAlpha];
    [newWidget adjustBorderWithWidth:widget.borderWidth];
    [self.onScreenWidgetViews addObject:newWidget];
    self->selectedWidgetView = newWidget;
    if(!createNew){
        [self.onScreenWidgetViews removeObject:widget];
        [widget removeFromSuperview];
    }
}


- (void) createWidgetFromParams: (NSMutableDictionary*) widgetInitParams{
    if(![self isWidgetParamsValid:widgetInitParams]) return;
    //saving & present the keyboard button:
    OnScreenWidgetView* widgetView = [[OnScreenWidgetView alloc] initWithCmdString:widgetInitParams[@"cmdString"] buttonLabel:widgetInitParams[@"buttonLabel"] shape:widgetInitParams[@"shape"]];
    widgetView.guidelineDelegate = (id<OnScreenWidgetGuidelineUpdateDelegate>)self;
    widgetView.translatesAutoresizingMaskIntoConstraints = NO; // weird but this is mandatory, or you will find no key views added to the right place
    widgetView.minStickOffset = [widgetInitParams[@"minStickOffsetString"] floatValue];
    [self.onScreenWidgetViews addObject:widgetView];
    // Add the widgetView to the view controller's view
    [self.view insertSubview:widgetView belowSubview:self.widgetPanelStack];
    [widgetView setLocationWithPosition:CGPointMake(90, 130)];
    [widgetView resizeWidgetView];
    [widgetView setVibrationWithStyle:UIImpactFeedbackStyleLight];
}


/* show pop up notification that lets users choose to save the current OSC layout configuration as a profile they can load when they want. User can also choose to cancel out of this pop up */
- (IBAction) saveTapped:(id)sender {
    [OSCProfilesManager setLayoutViewBounds:self.view.bounds];
    
    if([self->profilesManager updateSelectedProfile:self.layoutOSC.OSCButtonLayers]){
        UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [LocalizationHelper localizedStringForKey:@"Current profile updated successfully"] preferredStyle:UIAlertControllerStyleAlert];
        [savedAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }]];
        if(sender) [self presentViewController:savedAlertController animated:YES completion:nil];
    }
    else{
        UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [LocalizationHelper localizedStringForKey:@"Profile Default can not be overwritten"] preferredStyle:UIAlertControllerStyleAlert];
        [savedAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self.oscProfilesTableViewController profileViewRefresh]; // execute this will reset layout in OSC tool!
        }]];
        if(sender) [self presentViewController:savedAlertController animated:YES completion:nil];
    }
}

- (void)autoFitStack:(UIStackView* )stack{
    CGSize fittingSize = [stack systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    CGRect newFrame = stack.frame;
    newFrame.size = fittingSize;
    stack.frame = newFrame;
    [self updateClippedMaskForView:stack];
    if (@available(iOS 14, *)) nil;
    else [self applyShadowForiOS13:stack];
}

- (void)enableCommonWidgetTools{
    self.loadConfigTipLabel.hidden = YES;
    self.widgetSizeStack.hidden = NO;
    self.widgetHeightStack.hidden = NO;
    self.borderWidthAlphaStack.hidden = NO;
    if([self isIPhone]) self.vibrationStyleStack.hidden = NO;
}

- (void)autoFitLabel:(UILabel* )label{
    label.adjustsFontSizeToFitWidth = true;
    label.minimumScaleFactor = 0.3;
    label.numberOfLines = 1;
}

- (void)clearStickIndicator{
    [self->selectedWidgetView.stickBallLayer removeFromSuperlayer];
    [self->selectedWidgetView.crossMarkLayer removeFromSuperlayer];
}

/*
- (CGFloat)denormalizeSizeFactor:(CGFloat)sizeFactor{
    bool isNormalizedSizeFactor = sizeFactor > 6;
    return isNormalizedSizeFactor ? sizeFactor/10000*[UIScreen mainScreen].bounds.size.width
}
 */

- (void)widgetViewTapped: (NSNotification *)notification{
    //self.undoButton.alpha = selectedWidgetView.layoutChanges.count>1 && !CGPointEqualToPoint(selectedWidgetView.layoutChanges.lastObject.CGPointValue, selectedWidgetView.initialCenter)? 1.0 : 0.3;

    // receive the selected widgetView obj passed from the notification
    [self enableCommonWidgetTools];

    OnScreenWidgetView* widgetView = (OnScreenWidgetView* )notification.object;
    
    [self clearStickIndicator];
    self->widgetViewSelected = true;
    self->controllerLayerSelected = false;
    self->selectedWidgetView = widgetView;
    
    [self autoFitLabel:self.currentProfileLabel];
    self.currentProfileLabel.textAlignment = NSTextAlignmentLeft;
    [self.currentProfileLabel setText:
     [LocalizationHelper localizedStringForKey:@"  Profile: %@     Widget: %@",
      [profilesManager getSelectedProfile].name,
      selectedWidgetView.buttonLabel]];
    
    self.undoButton.alpha = selectedWidgetView.layoutChanges.count>1 ? 1.0 : 0.3;
    
    [self.layoutOSC updateGuidelinesForOnScreenWidget:self->selectedWidgetView]; // shows guideline immediately when widget is tapped
    // setup slider values
    [self.widgetSizeSlider setValue: self->selectedWidgetView.deNormalizedWidthFactor];
    [self.widgetHeightSlider setValue: self->selectedWidgetView.deNormalizedHeightFactor];
    [self.widgetAlphaSlider setValue: self->selectedWidgetView.backgroundAlpha];
    [self.widgetBorderWidthSlider setValue:self->selectedWidgetView.borderWidth];
    
    self.slidableStack.hidden = selectedWidgetView.widgetType != WidgetTypeEnumButton;
    [self.slidableSelector setSelectedSegmentIndex:selectedWidgetView.slideMode];
    
    bool showSensitivityFactorStack = selectedWidgetView.hasSensitivityTweak;
    bool showStickIndicatorOffsetStack = selectedWidgetView.hasStickIndicator;
        
    self.sensitivityXStack.hidden = self.sensitivityYStack.hidden = !showSensitivityFactorStack;
    self.stickIndicatorOffsetStack.hidden = !showStickIndicatorOffsetStack;
    self.mouseDownButtonStack.hidden = !([selectedWidgetView.cmdString containsString:@"MOUSEPAD"] && selectedWidgetView.widgetType == WidgetTypeEnumTouchPad);
    self.decelerationRateStack.hidden = !([selectedWidgetView.cmdString containsString:@"TRACKBALL"] && selectedWidgetView.widgetType == WidgetTypeEnumTouchPad);
    
    [self autoFitStack:self.widgetPanelStack];

    if(showSensitivityFactorStack){
        [self.sensitivityXSlider setValue:self->selectedWidgetView.sensitivityFactorX];
        [self autoFitLabel:self.sensitivityXLabel];
        [self.sensitivityXLabel setText:[LocalizationHelper localizedStringForKey:@"SensitivityX: %.2f", self->selectedWidgetView.sensitivityFactorX]];
        [self autoFitLabel:self.sensitivityYLabel];
        [self.sensitivityYSlider setValue:self->selectedWidgetView.sensitivityFactorY];
        [self.sensitivityYLabel setText:[LocalizationHelper localizedStringForKey:@"SensitivityY: %.2f", self->selectedWidgetView.sensitivityFactorY]];
    }
    if(showStickIndicatorOffsetStack){
        // illustrating the indicator offset,
        [self clearStickIndicator];
        selectedWidgetView.touchBeganLocation = CGPointMake(CGRectGetWidth(selectedWidgetView.frame)/2, CGRectGetHeight(selectedWidgetView.frame)/4);
        [selectedWidgetView showStickIndicator];// this will create the indicator CAShapeLayers
        [self.stickIndicatorOffsetSlider setValue:self->selectedWidgetView.stickIndicatorOffset];
        [self autoFitLabel:self.stickIndicatorOffsetLabel];
        [self.stickIndicatorOffsetLabel setText:[LocalizationHelper localizedStringForKey:@"Indicator Offset: %.0f", self->selectedWidgetView.stickIndicatorOffset]];
        [self->selectedWidgetView updateStickIndicator];
    }
    [self autoFitLabel:self.widgetSizeLabel];
    

    [self.widgetSizeLabel setText:[LocalizationHelper localizedStringForKey:@"Size: %.2f", self->selectedWidgetView.deNormalizedWidthFactor]];
    
    [self autoFitLabel:self.widgetHeightLabel];
    [self.widgetHeightLabel setText:[LocalizationHelper localizedStringForKey:@"Height: %.2f", self->selectedWidgetView.deNormalizedHeightFactor]];
    
    [self autoFitLabel:self.widgetAlphaLabel];
    [self.widgetAlphaLabel setText:[LocalizationHelper localizedStringForKey:@"Alpha: %.2f", self->selectedWidgetView.backgroundAlpha]];
    
    [self autoFitLabel:self.widgetBorderWidthLabel];
    [self.widgetBorderWidthLabel setText:[LocalizationHelper localizedStringForKey:@"Border Width: %.2f", self->selectedWidgetView.borderWidth]];
    
    [self.decelerationRateSlider setValue:selectedWidgetView.trackballDecelerationRate];
    [self autoFitLabel:self.decelerationRateLabel];
    [self.decelerationRateLabel setText:[LocalizationHelper localizedStringForKey:@"Deceleration Rate: %.3f  ", selectedWidgetView.trackballDecelerationRate]];
    self.mouseButtonDownSelector.selectedSegmentIndex = selectedWidgetView.mouseButtonAction;

    if([self isIPhone]){
        self.vibrationStyleStack.hidden =
        [widgetView.cmdString containsString:@"MOUSEPAD"] ||
        [widgetView.cmdString containsString:@"TRACKBALL"];
        [self autoFitStack:self.widgetPanelStack];
        self.vibrationStyleSelector.selectedSegmentIndex = self->selectedWidgetView.vibrationStyle;
    }
}


- (void)legacyOscLayerTapped: (NSNotification *)notification{
    [self enableCommonWidgetTools];
    CALayer* controllerLayer = (CALayer* )notification.object;
    [self clearStickIndicator];
    self->widgetViewSelected = false;
    self->selectedWidgetView = nil;
    
    self.stickIndicatorOffsetStack.hidden = true;
    self.sensitivityXStack.hidden = self.sensitivityYStack.hidden = true;
    self.mouseDownButtonStack.hidden = true;
    self.decelerationRateStack.hidden = true;
    
    self->controllerLayerSelected = true;
    self->selectedControllerLayer = controllerLayer;
    self->controllerLoadedBounds = controllerLayer.bounds;
    
    [self autoFitLabel:self.currentProfileLabel];
    self.currentProfileLabel.textAlignment = NSTextAlignmentLeft;
    [self.currentProfileLabel setText:
     [LocalizationHelper localizedStringForKey:@"  Profile: %@     Widget: %@",
      [profilesManager getSelectedProfile].name,
      selectedControllerLayer.name]];

    
    // setup slider values
    CGFloat sizeFactor = [OnScreenControls getControllerLayerSizeFactor:controllerLayer]; // calculated sizeFactor from loaded layer bounds.
    [self.widgetSizeSlider setValue:sizeFactor];
    [self.widgetHeightSlider setValue:sizeFactor];
    CGFloat alpha = [self.layoutOSC getControllerLayerOpacity:controllerLayer];
    [self.widgetAlphaSlider setValue:alpha];
    
    [self.widgetSizeLabel setText:[LocalizationHelper localizedStringForKey:@"Size: %.2f", sizeFactor]];
    [self.widgetHeightLabel setText:[LocalizationHelper localizedStringForKey:@"Height: %.2f", sizeFactor]];
    [self.widgetAlphaLabel setText:[LocalizationHelper localizedStringForKey:@"Alpha: %.2f", alpha]];
    if([self isIPhone]){
        self.vibrationStyleStack.hidden = NO;
        NSNumber *style = [OnScreenControls.layerVibrationStyleDic objectForKey:selectedControllerLayer.name];
        self.vibrationStyleSelector.selectedSegmentIndex = [style unsignedCharValue];
    }
    [self autoFitStack:_widgetPanelStack];
}

- (void)widgetSizeSliderMoved:(UISlider* )sender{
    [self.widgetSizeLabel setText:[LocalizationHelper localizedStringForKey:@"Size: %.2f", sender.value]];
    [self.widgetHeightLabel setText:[LocalizationHelper localizedStringForKey:@"Height: %.2f", sender.value]]; // resizing the whole button
    [self.widgetHeightSlider setValue: sender.value];
    
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        self->selectedWidgetView.translatesAutoresizingMaskIntoConstraints = true; // this is mandatory to prevent unexpected key view location change
        // when adjusting width, the widgetView height will be syncronized
        self->selectedWidgetView.widthFactor = self->selectedWidgetView.heightFactor = sender.value;
        [self->selectedWidgetView resizeWidgetView];
    }
    if(self->selectedControllerLayer != nil && self->controllerLayerSelected){
        [self.layoutOSC resizeControllerLayerWith:self->selectedControllerLayer and:sender.value];
    }
}

- (void)widgetHeightSliderMoved:(UISlider* )sender{
    [self.widgetHeightLabel setText:[LocalizationHelper localizedStringForKey:@"Height: %.2f", sender.value]];
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        self->selectedWidgetView.translatesAutoresizingMaskIntoConstraints = true; // this is mandatory to prevent unexpected key view location change
        if([self->selectedWidgetView.shape isEqualToString:@"round"]) return; // don't change height for round buttons, except for dPad buttons which are in rectangle shape
        self->selectedWidgetView.heightFactor = sender.value;
        [self->selectedWidgetView resizeWidgetView];
    }
}

- (void)widgetAlphaSliderMoved:(UISlider* )sender{
    [self.widgetAlphaLabel setText:[LocalizationHelper localizedStringForKey:@"Alpha: %.2f", sender.value]];
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        [self->selectedWidgetView adjustTransparencyWithAlpha:sender.value];
    }

    if(self->selectedControllerLayer != nil && self->controllerLayerSelected){
        [self.layoutOSC adjustControllerLayerOpacityWith:self->selectedControllerLayer and:sender.value];
    }
    return;
}

- (void)widgetBorderWidthSliderMoved:(UISlider* )sender{
    [self.widgetBorderWidthLabel setText:[LocalizationHelper localizedStringForKey:@"Border Width: %.2f", sender.value]];
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        [self->selectedWidgetView adjustBorderWithWidth:sender.value];
    }
    return;
}

- (void)mouseDownButtonChanged:(UISegmentedControl* )sender{
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        selectedWidgetView.mouseButtonAction = _mouseButtonDownSelector.selectedSegmentIndex;
    }
}

- (void)slideModeChanged:(UISegmentedControl* )sender{
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        selectedWidgetView.slideMode = _slidableSelector.selectedSegmentIndex;
    }
}

- (void)vibrationStyleChanged:(UISegmentedControl* )sender{
    bool vibraiontOn;
    if (@available(iOS 13.0, *)) {
        vibraiontOn = sender.selectedSegmentIndex < UIImpactFeedbackStyleRigid+1;
    } else {
        vibraiontOn = sender.selectedSegmentIndex < UIImpactFeedbackStyleHeavy+1;
    }
    if(vibraiontOn){
        vibrationGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:sender.selectedSegmentIndex];
        [vibrationGenerator prepare];
        [vibrationGenerator impactOccurred];
        NSLog(@"vibration instance: %@", vibrationGenerator);
    }
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        [self->selectedWidgetView setVibrationWithStyle:sender.selectedSegmentIndex];
    }
    if(self->selectedControllerLayer != nil && self->controllerLayerSelected){
        [OnScreenControls.layerVibrationStyleDic setObject:@(sender.selectedSegmentIndex) forKey:self->selectedControllerLayer.name];
    }
}

- (void)sensitivityXSliderMoved:(UISlider* )sender{
    [self.sensitivityXLabel setText:[LocalizationHelper localizedStringForKey:@"SensitivityX: %.2f", sender.value]];
    [self.sensitivityYLabel setText:[LocalizationHelper localizedStringForKey:@"SensitivityY: %.2f", sender.value]];
    [self.sensitivityYSlider setValue:sender.value];
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        self->selectedWidgetView.sensitivityFactorX = sender.value;
        self->selectedWidgetView.sensitivityFactorY = sender.value;
    }
    return;
}

- (void)sensitivityYSliderMoved:(UISlider* )sender{
    [self.sensitivityYLabel setText:[LocalizationHelper localizedStringForKey:@"SensitivityY: %.2f", sender.value]];
    if(self->selectedWidgetView != nil && self->widgetViewSelected) self->selectedWidgetView.sensitivityFactorY = sender.value;
    return;
}

- (void)decelerationRateSliderMoved:(UISlider* )sender{
    [self.decelerationRateLabel setText:[LocalizationHelper localizedStringForKey:@"Deceleration Rate: %.3f  ", sender.value]];
    if(self->selectedWidgetView != nil && self->widgetViewSelected) self->selectedWidgetView.trackballDecelerationRate = sender.value;
    return;
}


- (void)stickIndicatorOffsetSliderMoved:(UISlider* )sender{
    [self.stickIndicatorOffsetLabel setText:[LocalizationHelper localizedStringForKey:@"Indicator Offset: %.0f", sender.value]];
    if(self->selectedWidgetView != nil && self->widgetViewSelected){
        self->selectedWidgetView.stickIndicatorOffset = sender.value;
        [self->selectedWidgetView updateStickIndicator];
    }
    return;
}

- (void)showIndicatorOffset{
    selectedWidgetView.touchBeganLocation = CGPointMake(CGRectGetWidth(selectedWidgetView.frame)/2, CGRectGetHeight(selectedWidgetView.frame)/4);
    [selectedWidgetView showStickIndicator];
}


- (void)handleMissingToolBarIcon:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.imageView.image = [button.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            button.tintColor = [UIColor systemTealColor];
            if(!button.imageView.image){
                NSLog(@"missing image %d", button==_saveButton);
                button.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
                if(button==_exitButton) [button setTitle:[LocalizationHelper localizedStringForKey:@"Exit"] forState:UIControlStateNormal];
                if(button==trashCanButton) [button setTitle:[LocalizationHelper localizedStringForKey:@"Del"] forState:UIControlStateNormal];
                if(button==undoButton) [button setTitle:[LocalizationHelper localizedStringForKey:@"Undo"] forState:UIControlStateNormal];
                if(button==_saveButton) [button setTitle:[LocalizationHelper localizedStringForKey:@"Save"] forState:UIControlStateNormal];
                if(button==_loadButton) [button setTitle:[LocalizationHelper localizedStringForKey:@"Load"] forState:UIControlStateNormal];
                if(button==_addButton) [button setTitle:[LocalizationHelper localizedStringForKey:@"Add"] forState:UIControlStateNormal];
                if(button==_editButton) [button setTitle:[LocalizationHelper localizedStringForKey:@"Edit"] forState:UIControlStateNormal];
            }
        }
        [self handleMissingToolBarIcon:subview];
    }
}


- (void)setupWidgetPanel{
    self.widgetPanelStack.hidden = _quickSwitchEnabled;
    self.loadConfigTipLabel.hidden = NO;

    self.widgetPanelStack.layoutMargins = UIEdgeInsetsMake(10, 10, 10, 10);
    self.widgetPanelStack.layoutMarginsRelativeArrangement = YES;
    self.widgetPanelStack.layer.cornerRadius = 16;
    self.widgetPanelStack.clipsToBounds = YES;
    
    self.widgetPanelStack.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    
    [self.currentProfileLabel setText:[LocalizationHelper localizedStringForKey:@"Profile: %@",[profilesManager getSelectedProfile].name]];
    self.currentProfileLabel.layer.cornerRadius = [self isIPhone] ? 9 : 12;
    self.currentProfileLabel.clipsToBounds = YES;
    self.currentProfileLabel.textAlignment = NSTextAlignmentCenter;

    self.widgetSizeStack.userInteractionEnabled = YES;
    for(UIView* view in _widgetPanelStack.subviews){
        view.userInteractionEnabled = YES;
        if([view isKindOfClass:[UILabel class]]){
            UILabel* label = (UILabel* )view;
            label.font = [UIFont systemFontOfSize:18];
            label.textColor = [UIColor whiteColor];
        }
    }
    
    [self.widgetSizeSlider addTarget:self action:@selector(widgetSizeSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
    self.widgetSizeLabel.text = [LocalizationHelper localizedStringForKey:@"Size"];
    self.widgetSizeStack.hidden = YES;

    [self.widgetHeightSlider addTarget:self action:@selector(widgetHeightSliderMoved:) forControlEvents:(UIControlEventValueChanged)];

    self.widgetHeightLabel.text = [LocalizationHelper localizedStringForKey:@"Height"];
    self.widgetHeightStack.hidden = YES;

    [self.widgetAlphaSlider addTarget:self action:@selector(widgetAlphaSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
    self.widgetAlphaLabel.text = [LocalizationHelper localizedStringForKey:@"Alpha"];
   
    [self.widgetBorderWidthSlider addTarget:self action:@selector(widgetBorderWidthSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
    self.widgetBorderWidthLabel.text = [LocalizationHelper localizedStringForKey:@"Border Width"];
    self.borderWidthAlphaStack.hidden = YES;
  
    [self.sensitivityXSlider addTarget:self action:@selector(sensitivityXSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
    self.sensitivityXLabel.text = [LocalizationHelper localizedStringForKey:@"SensitivityX"];
    self.sensitivityXStack.hidden = YES;
    
    [self.sensitivityYSlider addTarget:self action:@selector(sensitivityYSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
    self.sensitivityYLabel.text = [LocalizationHelper localizedStringForKey:@"SensitivityY"];
    self.sensitivityYStack.hidden = YES;

    
    [self.decelerationRateSlider addTarget:self action:@selector(decelerationRateSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
    self.decelerationRateLabel.text = [LocalizationHelper localizedStringForKey:@"Deceleration Rate"];
    self.decelerationRateStack.hidden = YES;

    
    // stick indicator offset slider
    //self.stickIndicatorOffsetSlider.hidden = YES;
    [self.stickIndicatorOffsetSlider addTarget:self action:@selector(stickIndicatorOffsetSliderMoved:) forControlEvents:(UIControlEventValueChanged)];
    self.stickIndicatorOffsetLabel.text = [LocalizationHelper localizedStringForKey:@"Indicator Offset"];
    self.stickIndicatorOffsetStack.hidden = YES;
    
    NSDictionary *whiteFontAttributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor]
    };

    [self.mouseButtonDownSelector addTarget:self action:@selector(mouseDownButtonChanged:) forControlEvents:(UIControlEventValueChanged)];
    [self.mouseButtonDownSelector setTitleTextAttributes:whiteFontAttributes forState:UIControlStateNormal];
    self.mouseDownButtonStack.hidden = YES;

    [self.slidableSelector addTarget:self action:@selector(slideModeChanged:) forControlEvents:(UIControlEventValueChanged)];
    [self.slidableSelector setTitleTextAttributes:whiteFontAttributes forState:UIControlStateNormal];
    self.slidableStack.hidden = YES;

    
    if([self isIPhone]){
        [self.vibrationStyleSelector addTarget:self action:@selector(vibrationStyleChanged:) forControlEvents:(UIControlEventValueChanged)];
        self.vibrationStyleStack.hidden = YES;
        [self.vibrationStyleSelector setTitleTextAttributes:whiteFontAttributes forState:UIControlStateNormal];

    }
    
    [self.view bringSubviewToFront:self.toolbarRootView];
    [self.view insertSubview:self.widgetPanelStack belowSubview:self.toolbarRootView];
    self.widgetPanelStack.translatesAutoresizingMaskIntoConstraints = YES;
    
    
    CGRect frame = CGRectMake(0, 0, self.widgetPanelStack.frame.size.width, self.widgetPanelStack.frame.size.height);
    //frame.origin = CGPointMake(self.view.bounds.size.width/2, 100);
    frame.origin = CGPointMake(self.view.bounds.size.width/2-self.widgetPanelStack.frame.size.width/2, 100);
    self.widgetPanelStack.frame = frame;
    
    
    [self autoFitStack:self.widgetPanelStack];
    
    if([self isIPhone]) {
        for(UIView* view in _widgetPanelStack.arrangedSubviews){
            view.transform = CGAffineTransformMakeScale(0.83, 0.83);
        }
        self.widgetPanelStack.layoutMargins = UIEdgeInsetsMake(3, 2, 7, 2);
        
        self.widgetPanelStack.clipsToBounds = YES;

        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        CGRect visibleRect = CGRectInset(self.widgetPanelStack.bounds, 40, 0); // 左右各裁掉
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:visibleRect cornerRadius:12];
        maskLayer.path = path.CGPath;

        self.widgetPanelStack.layer.mask = maskLayer;
        
        if (@available(iOS 13.0, *) && self.vibrationStyleSelector.numberOfSegments == 6) {
        } else {
            [self.vibrationStyleSelector removeSegmentAtIndex:3 animated:NO];
            [self.vibrationStyleSelector removeSegmentAtIndex:3 animated:NO];
        }
    }
}

- (void)applyShadowForiOS13:(UIStackView* )stack {
    stack.backgroundColor = [UIColor clearColor];
    
    for(UIView* view in stack.arrangedSubviews){
        if([view isKindOfClass:[UIStackView class]]){
            UIStackView* subStack = (UIStackView* )view;
            for(UIView* view in subStack.arrangedSubviews){
                if([view isKindOfClass:[UILabel class]]){
                    view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
                    view.layer.cornerRadius = 6;
                    view.clipsToBounds = YES;
                    UILabel* label = (UILabel* )view;
                    label.textAlignment = NSTextAlignmentCenter;
                }
                else{
                    view.tintColor= [UIColor systemTealColor];
                    view.layer.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.9].CGColor;
                    //view.layer.shadowColor = [UIColor blackColor].CGColor;
                    view.layer.shadowOffset = CGSizeMake(1, 1);
                    view.layer.shadowOpacity = 1;
                    view.layer.shadowRadius = 5;
                }
            }
        }
        else{
            view.layer.cornerRadius = 10;
            view.clipsToBounds = YES;
            view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        }
    }
}


- (void)updateClippedMaskForView:(UIView* )view{
    if([self isIPhone]){
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        view.layer.mask = nil;
        CGRect visibleRect = CGRectInset(view.bounds, 40, 0); // 左右各裁掉 20pt
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:visibleRect cornerRadius:12];
        maskLayer.path = path.CGPath;
        view.layer.mask = maskLayer;
    }
}

- (BOOL)isIPhone{
    return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
}

- (void)handleProfileTablViewDismiss{
    [self profileRefresh];
    if(_quickSwitchEnabled) [self dismissViewControllerAnimated:NO completion:nil];
}

/* Basically the same method as loadTapped, without parameter*/
// Make sure whenever self view controller load the selected profile and layout its buttons.
- (void)profileRefresh{
    UIStoryboard *storyboard;
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    if (isIPhone) {
        storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
    }
    else {
        storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
    }
    
    // setup: current profile lable, button width slider, button height slider & button alpha slider
    [self setupWidgetPanel];
    
    //initialiaze _oscProfilesTableViewController
    self->_oscProfilesTableViewController = [storyboard instantiateViewControllerWithIdentifier:@"OSCProfilesTableViewController"];
    
    //this part is just for registration, will not be immediately executed.
    self->_oscProfilesTableViewController.needToUpdateOscLayoutTVC = ^() {   // a block that will be called when the modally presented 'OSCProfilesTableViewController' VC is dismissed. By the time the 'OSCProfilesTableViewController' VC is dismissed the user would have potentially selected a different OSC profile with a different layout and they want to see this layout on this 'LayoutOnScreenControlsViewController.' This block of code will load the profile and then hide/show and move each OSC button to their appropriate position
        NSLog(@"profile profile");
        [self reloadLegacyOnScreenControls];
        self->_oscProfilesTableViewController.currentOSCButtonLayers = self.layoutOSC.OSCButtonLayers; //pass updated OSCLayout to OSCProfileTableView again
    };
    
    [self.oscProfilesTableViewController profileViewRefresh]; // execute this will make sure OSCLayout is updated from persisted profile, not any cache.
    [self reloadOnScreenWidgetViews];

    // [self presentViewController:vc animated:YES completion:nil];
}

- (void) presentProfilesTableView{
    [self saveTapped:nil];
    [self clearStickIndicator];
    selectedWidgetView = nil;
    UIStoryboard *storyboard;
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    if (isIPhone) {
        storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
    }
    else {
        storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
    }
    
    _oscProfilesTableViewController = [storyboard instantiateViewControllerWithIdentifier:@"OSCProfilesTableViewController"];
    _oscProfilesTableViewController.layoutViewBounds = self.view.bounds;
    
    _oscProfilesTableViewController.needToUpdateOscLayoutTVC = ^() {   // a block that will be called when the modally presented 'OSCProfilesTableViewController' VC is dismissed. By the time the 'OSCProfilesTableViewController' VC is dismissed the user would have potentially selected a different OSC ofile with a different layout and they want to see this layout on this 'LayoutOnScreenControlsViewController.' This block of code will load the proffile and then hide/show and move each OSC button to their appropriate position
        [self reloadLegacyOnScreenControls];
    };

    self.widgetPanelStack.hidden = YES;
    
    _oscProfilesTableViewController.currentOSCButtonLayers = self.layoutOSC.OSCButtonLayers;
    
    [self presentViewController:_oscProfilesTableViewController animated:YES completion:nil];
}

/* Presents the view controller that lists all OSC profiles the user can choose from */
- (IBAction) loadTapped:(id)sender {
    [self presentProfilesTableView];
}


#pragma mark - Touch

- (void)updateGuidelinesForOnScreenWidget:(id)sender{
    OnScreenWidgetView* widget = (OnScreenWidgetView* )sender;
    [self.layoutOSC updateGuidelinesForOnScreenWidget:widget];
    [self.view bringSubviewToFront:widget];
    trashCanButton.tintColor = [self layerIsOverlappingWithTrashcanButton:widget.layer] ? [UIColor redColor] : trashCanStoryBoardColor;
    self.undoButton.alpha = 1.0;
}

- (BOOL) widgetPanelTouched:(UITouch *)touch{
    CGPoint touchPoint = [touch locationInView:_widgetPanelStack];
    UIView *touchedView = [_widgetPanelStack hitTest:touchPoint withEvent:nil];
    return touchedView != nil;
}

- (void) handleWidgetPanelMove:(UITouch *)touch{
    if(!widgetPanelMovedByTouch) return;
    CGPoint currentLocation = [touch locationInView:self.view];
    CGFloat offsetX = currentLocation.x - latestTouchLocation.x;
    CGFloat offsetY = currentLocation.y - latestTouchLocation.y;
    _widgetPanelStack.center = CGPointMake(_widgetPanelStack.center.x+offsetX, _widgetPanelStack.center.y+offsetY);
    latestTouchLocation = currentLocation;
    widgetPanelStoredCenter = _widgetPanelStack.center;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch* touch = touches.anyObject;
    widgetPanelMovedByTouch = [self widgetPanelTouched:touch];
    if(widgetPanelMovedByTouch){
        latestTouchLocation = [touch locationInView:self.view];
    }

    for (UITouch* touch in touches) {
        
        CGPoint touchLocation = [touch locationInView:self.view];
        touchLocation = [[touch view] convertPoint:touchLocation toView:nil];
        CALayer *layer = [self.view.layer hitTest:touchLocation];
        
        if (layer == self.toolbarRootView.layer ||
            layer == self.chevronView.layer ||
            layer == self.chevronImageView.layer ||
            layer == self.toolbarStackView.layer ||
            layer == self.view.layer) {  // don't let user move toolbar or toolbar UI buttons, toolbar's chevron 'pull tab', or the layer associated with this VC's view
            return;
        }
    }
    [self.layoutOSC touchesBegan:touches withEvent:event];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [self handleWidgetPanelMove:touches.anyObject];

    // -------- for OSC buttons
    [self.layoutOSC touchesMoved:touches withEvent:event];
    if ([self layerIsOverlappingWithTrashcanButton:self.layoutOSC.layerBeingDragged]) { // check if user is dragging around a button and hovering it over the trash can button
        trashCanButton.tintColor = [UIColor redColor];
    }
    else trashCanButton.tintColor = trashCanStoryBoardColor;
}

- (bool)touchWithinTashcanButton:(UITouch* )touch {
    CGPoint locationInView = [touch locationInView:self.view];
    
    // Convert the location to the button's coordinate system
    CGPoint locationInButton = [self.view convertPoint:locationInView toView:trashCanButton];
    bool ret = CGRectContainsPoint(trashCanButton.bounds, locationInButton);
    // NSLog(@"within button: %d", ret);
    // Check if the location is within the button's bounds
    return ret;
}

- (bool)layerIsOverlappingWithTrashcanButton:(CALayer* )layer{
    CALayer *commonLayer = self.view.layer; // 假设它们在同一个 superview 下

    CGRect rect1 = [layer convertRect:layer.bounds toLayer:commonLayer];
    CGRect rect2 = [trashCanButton.layer convertRect:trashCanButton.layer.bounds toLayer:commonLayer];
    return CGRectIntersectsRect(rect1, rect2);
}


- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    // removing keyboard buttons objs
    // UITouch *touch = [touches anyObject]; // Get the first touch in the set
    _widgetPanelStack.userInteractionEnabled = true;
    
    if(selectedWidgetView) [self.view insertSubview:selectedWidgetView belowSubview:_widgetPanelStack];

    
    if(!isToolbarHidden && self->selectedWidgetView != nil && [self layerIsOverlappingWithTrashcanButton:selectedWidgetView.layer]){
        [self->selectedWidgetView removeFromSuperview];
        [self.onScreenWidgetViews removeObject:self->selectedWidgetView];
        [self clearStickIndicator];
        [selectedWidgetView.buttonDownVisualEffectLayer removeFromSuperlayer];
    }
    
    
    //removing OSC buttons
    if (!isToolbarHidden && self.layoutOSC.layerBeingDragged != nil &&
        [self layerIsOverlappingWithTrashcanButton:self.layoutOSC.layerBeingDragged]) { // check if user wants to throw OSC button into the trash can
        // here we're going to delete something
        
        self.layoutOSC.layerBeingDragged.hidden = YES;
        
        if ([self.layoutOSC.layerBeingDragged.name isEqualToString:@"dPad"]) { // if user is hiding dPad, then hide all four dPad button child layers as well since setting the 'hidden' property on the parent dPad CALayer doesn't automatically hide the four child CALayer dPad buttons
            self.layoutOSC._upButton.hidden = YES;
            self.layoutOSC._rightButton.hidden = YES;
            self.layoutOSC._downButton.hidden = YES;
            self.layoutOSC._leftButton.hidden = YES;
        }
        
        /* if user is hiding left or right analog sticks, then hide their corresponding inner analog stick child layers as well since setting the 'hidden' property on the parent analog stick doesn't automatically hide its child inner analog stick CALayer */
        if ([self.layoutOSC.layerBeingDragged.name isEqualToString:@"leftStickBackground"]) {
            self.layoutOSC._leftStick.hidden = YES;
        }
        if ([self.layoutOSC.layerBeingDragged.name isEqualToString:@"rightStickBackground"]) {
            self.layoutOSC._rightStick.hidden = YES;
        }
    }
    [self.layoutOSC touchesEnded:touches withEvent:event];
    
    // in case of default profile OSC change, popup msgbox & remind user it's not allowed.
    if([profilesManager getIndexOfSelectedProfile] == 0 && [self.layoutOSC.layoutChanges count] > 0){
        UIAlertController * movedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [LocalizationHelper localizedStringForKey:@"Layout of the Default profile can not be changed"] preferredStyle:UIAlertControllerStyleAlert];
        [movedAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self.oscProfilesTableViewController profileViewRefresh];
        }]];
        [self presentViewController:movedAlertController animated:YES completion:nil];
    }
    
    
    trashCanButton.tintColor = trashCanStoryBoardColor;
    widgetPanelMovedByTouch = false;
}


@end
