//
//  OnScreenControls.m
//  Moonlight
//
//  Created by Diego Waxemberg on 12/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "OnScreenControls.h"
#import "CustomTapGestureRecognizer.h"
#import "VoidController.h"
#include "Limelight.h"
#if !TARGET_OS_TV
    #import <CoreMotion/CoreMotion.h>
#endif
#import "OnScreenButtonState.h"
#import "OSCProfilesManager.h"
#import "DataManager.h"

#define UPDATE_BUTTON(x, y) (buttonFlags = \
(y) ? (buttonFlags | (x)) : (buttonFlags & ~(x)))

static NSMutableSet* touchAddrsCapturedByOnScreenControls;
static CGRect standardRoundButtonBounds;
static CGRect standardRectangleButtonBounds;
static CGRect standardStickBounds;
static CGRect standardStickBackgroundBounds;
static CGRect standardUpDownButtonBounds;
static CGRect standardLeftRightButtonBounds;
static NSSet *validPositionButtonNames;



@implementation OnScreenControls {

    UITouch* _aTouch;
    UITouch* _bTouch;
    UITouch* _xTouch;
    UITouch* _yTouch;
    UITouch* _dpadTouch;
    UITouch* _upTouch;
    UITouch* _leftTouch;
    UITouch* _rightTouch;
    UITouch* _downTouch;
    UITouch* _lsTouch;
    UITouch* _rsTouch;
    UITouch* _startTouch;
    UITouch* _selectTouch;
    UITouch* _r1Touch;
    UITouch* _r2Touch;
    UITouch* _r3Touch;
    UITouch* _l1Touch;
    UITouch* _l2Touch;
    UITouch* _l3Touch;
    
    NSDate* l3TouchStart;
    NSDate* r3TouchStart;
    
    UIImpactFeedbackGenerator* vibrationGenerator;
    
    BOOL l3Set;
    BOOL r3Set;
    
    BOOL _iPad;
    CGRect _controlArea;
    UIView* _view; // the view passed to here, is the streamFrameTopLayerView
    BOOL _visible;
    
    ControllerSupport *_controllerSupport;
    VoidController *_controller;
    NSMutableArray* _deadTouches;
    BOOL _swapABXY;
    BOOL _largerStickLR1;
    CGFloat _oscTapExlusionAreaSizeFactor;
    OSCProfilesManager *profilesManager;
    NSMutableDictionary *_activeCustomOscButtonPositionDict;
    NSMutableDictionary *_originalControllerLayerOpacityDict;
}

@synthesize D_PAD_CENTER_X;
@synthesize D_PAD_CENTER_Y;
@synthesize _leftStickBackground;
@synthesize _leftStick;
@synthesize _rightStickBackground;
@synthesize _rightStick;
@synthesize _upButton;
@synthesize _downButton;
@synthesize _leftButton;
@synthesize _rightButton;
@synthesize _aButton;
@synthesize _bButton;
@synthesize _xButton;
@synthesize _yButton;
@synthesize _startButton;
@synthesize _selectButton;
@synthesize _r1Button;
@synthesize _r2Button;
@synthesize _r3Button;
@synthesize _l1Button;
@synthesize _l2Button;
@synthesize _l3Button;
@synthesize _level;
@synthesize OSCButtonLayers;
@synthesize _dPadBackground;

static const float EDGE_WIDTH = .05;

//static const float BUTTON_SIZE = 50;
static float BUTTON_CENTER_X;
static float BUTTON_CENTER_Y;


static const float DEAD_ZONE_PADDING = 15;

static const double STICK_CLICK_RATE = 100;
static const float STICK_DEAD_ZONE = .1;
static float RIGHT_STICK_INNER_SIZE;
static float RIGHT_STICK_OUTER_SIZE;
static float LEFT_STICK_INNER_SIZE;
static float LEFT_STICK_OUTER_SIZE;
static float LS_CENTER_X;
static float LS_CENTER_Y;
static float RS_CENTER_X;
static float RS_CENTER_Y;
static const float DEFAULT_STICK_OPACITY = 0.63;

static float START_X;
static float START_Y;

static float SELECT_X;
static float SELECT_Y;

static float R1_X;
static float R1_Y;
static float R2_X;
static float R2_Y;
static float R3_X;
static float R3_Y;
static float L1_X;
static float L1_Y;
static float L2_X;
static float L2_Y;
static float L3_X;
static float L3_Y;

+ (NSMutableSet* )touchAddrsCapturedByOnScreenControls{
    return touchAddrsCapturedByOnScreenControls;
}

- (void) sendRightStickTouchPadEvent:(CGFloat) stickX : (CGFloat) stickY{
    [_controllerSupport updateRightStick:_controller x: stickX y: stickY]; // stick value populated to the controllerSupport here
    [_controllerSupport updateFinished:_controller];
}

- (void) sendLeftStickTouchPadEvent:(CGFloat) stickX : (CGFloat) stickY{
    [_controllerSupport updateLeftStick:_controller x: stickX y: stickY]; // stick value populated to the controllerSupport here
    [_controllerSupport updateFinished:_controller];
}


- (void) clearRightStickTouchPadFlag{
    [_controllerSupport updateRightStick:_controller x:0 y:0];
    // [_controllerSupport clearButtonFlag:_controller flags:RS_CLK_FLAG];
    [_controllerSupport updateFinished:_controller];
}

- (void) clearLeftStickTouchPadFlag{
    [_controllerSupport updateLeftStick:_controller x:0 y:0];
    // [_controllerSupport clearButtonFlag:_controller flags:LS_CLK_FLAG];
    [_controllerSupport updateFinished:_controller];
}

- (void) pressDownControllerButton: (int)flag{
    [_controllerSupport setButtonFlag:_controller flags:flag];
    [_controllerSupport updateFinished:_controller];
}

- (void) releaseControllerButton: (int)flag{
    [_controllerSupport clearButtonFlag:_controller flags:flag];
    [_controllerSupport updateFinished:_controller];
}

- (void) updateLeftTrigger:(unsigned char)input{
    [_controllerSupport updateLeftTrigger:_controller left:input];
    [_controllerSupport updateFinished:_controller];
}

- (void) updateRightTrigger:(unsigned char)input{
    [_controllerSupport updateRightTrigger:_controller right:input];
    [_controllerSupport updateFinished:_controller];
}

// sending self as an instance to OnScreenWidgetView
- (void)sendInstance{
    NSLog(@"OnScreenControls is sending its instance...");
    if ([self.delegate respondsToSelector:@selector(getOnScreenControlsInstance:)]) {
        [self.delegate getOnScreenControlsInstance:self];
    } else {
        NSLog(@"Delegate not set or does not respond to getOnScreenControlsInstance:");
    }
}

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig {
    self = [self init];
    self.isLayingOut = false; // set false by default (play mode instead of layout mode)
    _view = view;
    
    profilesManager = [OSCProfilesManager sharedManager:view.bounds];
    
    self.OSCButtonLayers = [[NSMutableArray alloc] init];

    if (controllerSupport) {
        _controllerSupport = controllerSupport;
    }
    _controller = [controllerSupport getOscController];
    _deadTouches = [[NSMutableArray alloc] init];
    if (streamConfig) {
        _swapABXY = streamConfig.swapABXYButtons;
    }
    
    _originalControllerLayerOpacityDict = [[NSMutableDictionary alloc] init];
    // we have to retrieve largerStickLR1 setting direct from the database, since streamConfig is invalid in LayoutOnScreenControls
    // DataManager* dataMan = [[DataManager alloc] init];
    _largerStickLR1 = true;
    _oscTapExlusionAreaSizeFactor = 1.05;
        
    _iPad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
    _controlArea = CGRectMake(0, 0, _view.frame.size.width, _view.frame.size.height);
    if (_iPad)
    {
        // Cut down the control area on an iPad so the controls are more reachable
        _controlArea.size.height = _view.frame.size.height / 2.0;
        _controlArea.origin.y = _view.frame.size.height - _controlArea.size.height;
    }
    else
    {
        _controlArea.origin.x = _controlArea.size.width * EDGE_WIDTH;
        _controlArea.size.width -= _controlArea.origin.x * 2;
    }

    _aButton = [CALayer layer];
    _bButton = [CALayer layer];
    _xButton = [CALayer layer];
    _yButton = [CALayer layer];
    _upButton = [CALayer layer];
    _downButton = [CALayer layer];
    _leftButton = [CALayer layer];
    _rightButton = [CALayer layer];
    _l1Button = [CALayer layer];
    _r1Button = [CALayer layer];
    _l2Button = [CALayer layer];
    _r2Button = [CALayer layer];
    _l3Button = [CALayer layer];
    _r3Button = [CALayer layer];
    _startButton = [CALayer layer];
    _selectButton = [CALayer layer];
    _leftStickBackground = [CALayer layer];
    _rightStickBackground = [CALayer layer];
    _leftStick = [CALayer layer];
    _rightStick = [CALayer layer];
    
    [self.OSCButtonLayers addObject:_aButton];
    [self.OSCButtonLayers addObject:_bButton];
    [self.OSCButtonLayers addObject:_xButton];
    [self.OSCButtonLayers addObject:_yButton];
    [self.OSCButtonLayers addObject:_startButton];
    [self.OSCButtonLayers addObject:_selectButton];
    [self.OSCButtonLayers addObject:_r1Button];
    [self.OSCButtonLayers addObject:_r2Button];
    [self.OSCButtonLayers addObject:_r3Button];
    [self.OSCButtonLayers addObject:_l1Button];
    [self.OSCButtonLayers addObject:_l2Button];
    [self.OSCButtonLayers addObject:_l3Button];
    [self.OSCButtonLayers addObject:_upButton];
    [self.OSCButtonLayers addObject:_downButton];
    [self.OSCButtonLayers addObject:_leftButton];
    [self.OSCButtonLayers addObject:_rightButton];
    [self.OSCButtonLayers addObject:_leftStickBackground];
    [self.OSCButtonLayers addObject:_rightStickBackground];
    [self.OSCButtonLayers addObject:_leftStick];
    [self.OSCButtonLayers addObject:_rightStick];

    /* Name button layers to allow us to more easily associate them with 'OnScreenButtonState' objects by comparing their name properties */
    _leftStickBackground.name = @"leftStickBackground";
    _rightStickBackground.name = @"rightStickBackground";
    _leftStick.name = @"leftStick";
    _rightStick.name = @"rightStick";
    _aButton.name = @"aButton";
    _bButton.name = @"bButton";
    _xButton.name = @"xButton";
    _yButton.name = @"yButton";
    _startButton.name = @"startButton";
    _selectButton.name = @"selectButton";
    _r1Button.name = @"r1Button";
    _r2Button.name = @"r2Button";
    _r3Button.name = @"r3Button";
    _l1Button.name = @"l1Button";
    _l2Button.name = @"l2Button";
    _l3Button.name = @"l3Button";
    _upButton.name = @"upButton";
    _rightButton.name = @"rightButton";
    _downButton.name = @"downButton";
    _leftButton.name = @"leftButton";
    
    
    _standardRoundButtonBounds = standardRoundButtonBounds = CGRectMake(0, 0, [UIImage imageNamed:@"AButton"].size.width, [UIImage imageNamed:@"AButton"].size.height);
    _standardRectangleButtonBounds = standardRectangleButtonBounds = CGRectMake(0, 0, [UIImage imageNamed:@"StartButton"].size.width, [UIImage imageNamed:@"StartButton"].size.height);
    _standardStickBounds = standardStickBounds = CGRectMake(0, 0, [UIImage imageNamed:@"StickInner"].size.width * 1.33, [UIImage imageNamed:@"StickInner"].size.height * 1.33);
    _standardStickBackgroundBounds = standardStickBackgroundBounds = CGRectMake(0, 0, [UIImage imageNamed:@"StickOuter"].size.width * 1.10, [UIImage imageNamed:@"StickOuter"].size.height * 1.10);
    _standardUpDownButtonBounds = standardUpDownButtonBounds = CGRectMake(0, 0, [UIImage imageNamed:@"UpButton"].size.width, [UIImage imageNamed:@"UpButton"].size.height);
    _standardLeftRightButtonBounds = standardLeftRightButtonBounds = CGRectMake(0, 0, [UIImage imageNamed:@"LeftButton"].size.width, [UIImage imageNamed:@"LeftButton"].size.height);

    _activeCustomOscButtonPositionDict = [[NSMutableDictionary alloc] init];
    touchAddrsCapturedByOnScreenControls = [[NSMutableSet alloc] init];
    
    return self;
}

- (void) show {
    _visible = YES;
        
    [self updateControls];
}

- (void) setLevel:(OnScreenControlsLevel)level {
    _level = level;
    
    // Only update controls if we're showing, otherwise
    // show will do it for us.
    if (_visible) {
        [self updateControls];
    }
}

- (OnScreenControlsLevel) getLevel {
    return _level;
}

- (CGPoint) denormalizeWidgetPosition:(CGPoint)position {
    if(position.x < 1.0 && position.y < 1.0) {
        position.x = position.x * _view.bounds.size.width;
        position.y = position.y * _view.bounds.size.height;
        // NSLog(@"denormalizing position: %f, %f", position.x, position.y);
    }
    return position;
}

- (void) updateControls {
    if(self._level == OnScreenControlsLevelCustom){
        // mark all OSC buttons that has valid coords of positions
        validPositionButtonNames = [NSSet setWithObjects:
                                    @"l2Button",
                                    @"l1Button",
                                    @"dPad",
                                    @"selectButton",
                                    @"leftStickBackground",
                                    @"rightStickBackground",
                                    @"r2Button",
                                    @"r1Button",
                                    @"aButton",
                                    @"bButton",
                                    @"xButton",
                                    @"yButton",
                                    @"startButton",
                                    nil];
        
        // _activeCustomOscButtonPositionDict will be updated every time when the osc profile is reloaded
        OSCProfile *oscProfile = [profilesManager getSelectedProfile]; //returns the currently selected OSCProfile
        [_activeCustomOscButtonPositionDict removeAllObjects]; //reset the Dict.
        // NSLog(@"_activeCustomOscButtonPositionDict update: STARTOVER");
        for (NSData *buttonStateEncoded in oscProfile.buttonStates) {
            OnScreenButtonState* buttonState = [profilesManager unarchiveButtonStateEncoded:buttonStateEncoded];
            buttonState.position = [self denormalizeWidgetPosition:buttonState.position];
            [OnScreenControls.layerVibrationStyleDic setObject:@(buttonState.vibrationStyle) forKey:buttonState.name];
            if(!buttonState.isHidden && [validPositionButtonNames containsObject:buttonState.name] && (buttonState.buttonType == LegacyOscButton || [profilesManager getIndexOfSelectedProfile] == 0 ) ){
                [_activeCustomOscButtonPositionDict setObject:[NSValue valueWithCGPoint:buttonState.position] forKey:buttonState.name]; // we got a buttonname -> position dict here
                // NSLog(@"_activeCustomOscButtonPositionDict update, button name:%@,  position: %f, %f", buttonState.name, buttonState.position.x, buttonState.position.y);
            }
            
            // retrieve size factors & other necessary configurations for complex control
            if([buttonState.name isEqualToString:@"leftStick"]){
                _leftStickSizeFactor = buttonState.oscLayerSizeFactor;
                if(_leftStickSizeFactor == 0) _leftStickSizeFactor = 1.0; // dealing with invalid sizefactor
                _leftStickOpacity = buttonState.backgroundAlpha;
                if(_leftStickOpacity == 0 ) _leftStickOpacity = DEFAULT_STICK_OPACITY; // dealing with invalid sizefactor
            }
            if([buttonState.name isEqualToString:@"rightStick"]){
                _rightStickSizeFactor = buttonState.oscLayerSizeFactor;
                if(_rightStickSizeFactor == 0) _rightStickSizeFactor = 1.0; // dealing with invalid sizefactor
                _rightStickOpacity = buttonState.backgroundAlpha;
                if(_rightStickOpacity == 0) _rightStickOpacity = DEFAULT_STICK_OPACITY; // dealing with invalid sizefactor
            }
            if([buttonState.name isEqualToString:@"upButton"]){
                _dPadSizeFactor = buttonState.oscLayerSizeFactor / 0.982759;
                if(_dPadSizeFactor == 0) _dPadSizeFactor = 1.0; // dealing with invalid sizefactor
            }
        }
        //NSLog(@"_activeCustomOscButtonPositionDict update, active button number: %lu", (unsigned long)[_activeCustomOscButtonPositionDict count]);
    }
    else{
        // deal with simple & full mode configurations
        _leftStickSizeFactor = _rightStickSizeFactor = 1.0;
        _leftStickOpacity = _rightStickOpacity = DEFAULT_STICK_OPACITY;
    }
    
    //NSLog(@"rightStickOpacity: %f", _rightStickOpacity);
    
    // belows are orginal codes:
    switch (self._level) {
        case OnScreenControlsLevelOff:
            [self hideButtons];
            [self hideBumpers];
            [self hideTriggers];
            [self hideStartSelect];
            [self hideSticks];
            [self hideL3R3];
            break;
        case OnScreenControlsLevelAutoGCGamepad:
            // GCGamepad is missing triggers, both analog sticks,
            // and the select button
            [self setupGamepadControls];
            
            [self hideButtons];
            [self hideBumpers];
            [self hideL3R3];
            [self drawTriggers];
            [self drawStartSelect];
            [self drawSticks];
            break;
        case OnScreenControlsLevelAutoGCExtendedGamepad:
            // GCExtendedGamepad is missing R3, L3, and select
            [self setupExtendedGamepadControls];
            
            [self hideButtons];
            [self hideBumpers];
            [self hideTriggers];
            [self drawStartSelect];
            [self hideSticks];
            [self drawL3R3];
            break;
        case OnScreenControlsLevelAutoGCExtendedGamepadWithStickButtons:
            // This variant of GCExtendedGamepad has L3 and R3 but
            // is still missing Select
            [self setupExtendedGamepadControls];
            
            [self hideButtons];
            [self hideBumpers];
            [self hideTriggers];
            [self hideL3R3];
            [self drawStartSelect];
            [self hideSticks];
            break;
        case OnScreenControlsLevelSimple:
            
            [self setupSimpleControls];
            [self hideTriggers];
            [self hideL3R3];
            [self hideBumpers];
            [self hideSticks];
            [self drawStartSelect];
            [self drawButtons];
            [self setOpacityForStandardControllerLayers];
            break;
        case OnScreenControlsLevelFull:
            
            [self setupComplexControls];
            [self drawButtons];
            [self drawStartSelect];
            [self drawBumpers];
            [self drawTriggers];
            [self drawSticks];
            [self hideL3R3]; // Full controls don't need these they have the sticks
            [self setOpacityForStandardControllerLayers];
            break;
        case OnScreenControlsLevelCustom:
            
            [self setupComplexControls];    // Default postion for D-Pad set here
            [self setDPadCenter];    // Custom position for D-Pad set here
            [self setAnalogStickPositions]; // Custom position for analog sticks set here
            [self drawButtons];
            [self drawStartSelect];
            [self drawBumpers];
            [self drawTriggers];
            [self drawSticks];
            [self positionAndResizeSingleControllerLayers];
            [self setOpacityForCutsomControllerLayers];
            
            break;
        default:
            Log(LOG_W, @"Unknown on-screen controls level: %d", (int)_level);
            break;
    }
    
    // populate the controllerLayer.name -> Opacity dictionary...  have to do this in order to make touchdown visual effect consistent
    for (CALayer* controllerLayer in self.OSCButtonLayers){
        [_originalControllerLayerOpacityDict setObject:@(controllerLayer.opacity) forKey:controllerLayer.name];
    }
}

// For GCExtendedGamepad controls we move start, select, L3, and R3 to the button
- (void) setupExtendedGamepadControls {
    // Start with the default complex layout
    [self setupComplexControls];
    
    START_X = _controlArea.size.width * .95 + _controlArea.origin.x;
    START_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    SELECT_X = _controlArea.size.width * .05 + _controlArea.origin.x;
    SELECT_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    
    L3_Y = _controlArea.size.height * .85 + _controlArea.origin.y;
    R3_Y = _controlArea.size.height * .85 + _controlArea.origin.y;
    
    if (_iPad) {
        L3_X = _controlArea.size.width * .15 + _controlArea.origin.x;
        R3_X = _controlArea.size.width * .85 + _controlArea.origin.x;
    }
    else {
        L3_X = _controlArea.size.width * .25 + _controlArea.origin.x;
        R3_X = _controlArea.size.width * .75 + _controlArea.origin.x;
    }
}

// For GCGamepad controls we move triggers, start, and select
// to sit right above the analog sticks
- (void) setupGamepadControls {
    // Start with the default complex layout
    [self setupComplexControls];
    
    L2_Y = _controlArea.size.height * .75 + _controlArea.origin.y;
    L2_X = _controlArea.size.width * .05 + _controlArea.origin.x;
    
    R2_Y = _controlArea.size.height * .75 + _controlArea.origin.y;
    R2_X = _controlArea.size.width * .95 + _controlArea.origin.x;
    
    START_X = _controlArea.size.width * .95 + _controlArea.origin.x;
    START_Y = _controlArea.size.height * .95 + _controlArea.origin.y;
    SELECT_X = _controlArea.size.width * .05 + _controlArea.origin.x;
    SELECT_Y = _controlArea.size.height * .95 + _controlArea.origin.y;
    
    if (_iPad) {
        // The analog sticks are kept closer to the sides on iPad
        LS_CENTER_X = _controlArea.size.width * .15 + _controlArea.origin.x;
        RS_CENTER_X = _controlArea.size.width * .85 + _controlArea.origin.x;
    }
}

// For simple controls we move the triggers and buttons to the bottom
- (void) setupSimpleControls {
    // Start with the default complex layout
    [self setupComplexControls];
    
    START_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    SELECT_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    
    L2_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    L2_X = _controlArea.size.width * .1 + _controlArea.origin.x;

    R2_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    R2_X = _controlArea.size.width * .9 + _controlArea.origin.x;
    
    if (_iPad) {
        // Lower the D-pad and buttons on iPad
        D_PAD_CENTER_Y = _controlArea.size.height * .75 + _controlArea.origin.y;
        BUTTON_CENTER_Y = _controlArea.size.height * .75 + _controlArea.origin.y;
        
        // Move Start and Select closer to sides
        SELECT_X = _controlArea.size.width * .2 + _controlArea.origin.x;
        START_X = _controlArea.size.width * .8 + _controlArea.origin.x;
    }
    else {
        SELECT_X = _controlArea.size.width * .4 + _controlArea.origin.x;
        START_X = _controlArea.size.width * .6 + _controlArea.origin.x;
    }
}

- (void) setupComplexControls
{
    D_PAD_CENTER_X = _controlArea.size.width * .1 + _controlArea.origin.x;
    D_PAD_CENTER_Y = _controlArea.size.height * .60 + _controlArea.origin.y;
    BUTTON_CENTER_X = _controlArea.size.width * .9 + _controlArea.origin.x;
    BUTTON_CENTER_Y = _controlArea.size.height * .60 + _controlArea.origin.y;
    
    if (_iPad)
    {
        // The analog sticks are kept closer to the sides on iPad
        LS_CENTER_X = _controlArea.size.width * .22 + _controlArea.origin.x;
        LS_CENTER_Y = _controlArea.size.height * .80 + _controlArea.origin.y;
        RS_CENTER_X = _controlArea.size.width * .77 + _controlArea.origin.x;
        RS_CENTER_Y = _controlArea.size.height * .80 + _controlArea.origin.y;
    }
    else
    {
        LS_CENTER_X = _controlArea.size.width * .35 + _controlArea.origin.x;
        LS_CENTER_Y = _controlArea.size.height * .75 + _controlArea.origin.y;
        RS_CENTER_X = _controlArea.size.width * .65 + _controlArea.origin.x;
        RS_CENTER_Y = _controlArea.size.height * .75 + _controlArea.origin.y;
    }
    
    START_X = _controlArea.size.width * .9 + _controlArea.origin.x;
    START_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    SELECT_X = _controlArea.size.width * .1 + _controlArea.origin.x;
    SELECT_Y = _controlArea.size.height * .9 + _controlArea.origin.y;
    
    L1_Y = _controlArea.size.height * .27 + _controlArea.origin.y;
    L2_Y = _controlArea.size.height * .1 + _controlArea.origin.y;
    R1_Y = _controlArea.size.height * .27 + _controlArea.origin.y;
    R2_Y = _controlArea.size.height * .1 + _controlArea.origin.y;
    
    if (_iPad) {
        // Move L/R buttons closer to the side on iPad
        L1_X = _controlArea.size.width * .05 + _controlArea.origin.x;
        L2_X = _controlArea.size.width * .05 + _controlArea.origin.x;
        R1_X = _controlArea.size.width * .95 + _controlArea.origin.x;
        R2_X = _controlArea.size.width * .95 + _controlArea.origin.x;
    }
    else {
        L1_X = _controlArea.size.width * .1 + _controlArea.origin.x;
        L2_X = _controlArea.size.width * .1 + _controlArea.origin.x;
        R1_X = _controlArea.size.width * .9 + _controlArea.origin.x;
        R2_X = _controlArea.size.width * .9 + _controlArea.origin.x;
    }
}

- (void) drawButtons {
    UIImage* aButtonImage = [UIImage imageNamed:@"AButton"];
    UIImage* aButtonHdImage = [UIImage imageNamed:@"AButtonHD"];
    UIImage* bButtonImage = [UIImage imageNamed:@"BButton"];
    UIImage* bButtonHdImage = [UIImage imageNamed:@"BButtonHD"];
    UIImage* xButtonImage = [UIImage imageNamed:@"XButton"];
    UIImage* xButtonHdImage = [UIImage imageNamed:@"XButtonHD"];
    UIImage* yButtonImage = [UIImage imageNamed:@"YButton"];
    UIImage* yButtonHdImage = [UIImage imageNamed:@"YButtonHD"];

    
    
    CGRect aButtonFrame = CGRectMake(BUTTON_CENTER_X - aButtonImage.size.width / 2, BUTTON_CENTER_Y + BUTTON_DIST, aButtonImage.size.width, aButtonImage.size.height);
    CGRect bButtonFrame = CGRectMake(BUTTON_CENTER_X + BUTTON_DIST, BUTTON_CENTER_Y - bButtonImage.size.height / 2, bButtonImage.size.width, bButtonImage.size.height);
    CGRect xButtonFrame = CGRectMake(BUTTON_CENTER_X - BUTTON_DIST - xButtonImage.size.width, BUTTON_CENTER_Y - xButtonImage.size.height/ 2, xButtonImage.size.width, xButtonImage.size.height);
    CGRect yButtonFrame = CGRectMake(BUTTON_CENTER_X - yButtonImage.size.width / 2, BUTTON_CENTER_Y - BUTTON_DIST - yButtonImage.size.height, yButtonImage.size.width, yButtonImage.size.height);
    
    // create A button
    _aButton.contents = (id) aButtonHdImage.CGImage;
    // Set the filtering mode for smooth downscaling
    _aButton.minificationFilter = kCAFilterLinear; // Smooth scaling down
    _aButton.magnificationFilter = kCAFilterLinear; // Smooth scaling up (if needed)
    _aButton.minificationFilterBias = 0.0f; // Trilinear-like effect

    // Enable anti-aliasing for smoother edges
    _aButton.allowsEdgeAntialiasing = YES;
    _aButton.edgeAntialiasingMask = kCALayerLeftEdge | kCALayerRightEdge | kCALayerBottomEdge | kCALayerTopEdge;

    _aButton.frame = _swapABXY ? bButtonFrame : aButtonFrame;
    [_view.layer addSublayer:_aButton];      // rendering OSC Button here
    
    // create B button
    _bButton.frame = _swapABXY ? aButtonFrame : bButtonFrame;
    _bButton.contents = (id) bButtonHdImage.CGImage;
    [_view.layer addSublayer:_bButton];
    
    // create X Button
    _xButton.frame = _swapABXY ? yButtonFrame : xButtonFrame;
    _xButton.contents = (id) xButtonHdImage.CGImage;
    [_view.layer addSublayer:_xButton];
    
    // create Y Button
    _yButton.frame = _swapABXY ? xButtonFrame : yButtonFrame;
    _yButton.contents = (id) yButtonHdImage.CGImage;
    [_view.layer addSublayer:_yButton];
    
    
    if(self._level == OnScreenControlsLevelFull ||
       self._level == OnScreenControlsLevelSimple){
        _dPadSizeFactor = 1.0;
    }
    
    // Calculate the distances of each button from the shared center based on their transformed positions
    CGFloat newDPadDistFactor = 0.2/_dPadSizeFactor;
    CGFloat newLongSideLength = standardLeftRightButtonBounds.size.width * _dPadSizeFactor;
    CGFloat newShortSideLength = standardLeftRightButtonBounds.size.height * _dPadSizeFactor;
    CGPoint sharedCenter = CGPointMake(D_PAD_CENTER_X, D_PAD_CENTER_Y); // this will anchor the center point of the dPad
    
    
    // dPad buttons are resized HERE
    // up button
    // UIImage* upButtonImage = [UIImage imageNamed:@"UpButton"];
    UIImage* upButtonHdImage = [UIImage imageNamed:@"UpButtonHD"];
    _upButton.contents = (id) upButtonHdImage.CGImage;
    [_view.layer addSublayer:_upButton];
    _upButton.anchorPoint = CGPointMake(0.5, 1 + newDPadDistFactor);
    _upButton.bounds = CGRectMake(0, 0, newShortSideLength, newLongSideLength);
    _upButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);
    
    // down button
    // UIImage* downButtonImage = [UIImage imageNamed:@"DownButton"];
    UIImage* downButtonHdImage = [UIImage imageNamed:@"DownButtonHD"];
    _downButton.contents = (id) downButtonHdImage.CGImage;
    [_view.layer addSublayer:_downButton];
    // Resize and reposition the button
    _downButton.anchorPoint = CGPointMake(0.5, 0 - newDPadDistFactor);
    _downButton.bounds = CGRectMake(0, 0, newShortSideLength, newLongSideLength);
    _downButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);
    
    // left button
    // UIImage* leftButtonImage = [UIImage imageNamed:@"LeftButton"];
    UIImage* leftButtonHdImage = [UIImage imageNamed:@"LeftButtonHD"];
    _leftButton.contents = (id) leftButtonHdImage.CGImage;
    [_view.layer addSublayer:_leftButton];
    _leftButton.anchorPoint = CGPointMake(1 + newDPadDistFactor, 0.5);
    _leftButton.bounds = CGRectMake(0, 0, newLongSideLength, newShortSideLength);
    _leftButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);
    
    // right button
    // UIImage* rightButtonImage = [UIImage imageNamed:@"RightButton"];
    UIImage* rightButtonHdImage = [UIImage imageNamed:@"RightButtonHD"];
    _rightButton.contents = (id) rightButtonHdImage.CGImage;
    [_view.layer addSublayer:_rightButton];
    _rightButton.anchorPoint = CGPointMake(0 - newDPadDistFactor, 0.5);
    _rightButton.bounds = CGRectMake(0, 0, newLongSideLength, newShortSideLength);
    _rightButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);
}

/**
 * Sets D-Pad position for class const var
 */
- (void) setDPadCenter {
    OSCProfile *oscProfile = [profilesManager getSelectedProfile]; //returns the currently selected OSCProfile
    
    for (NSData *buttonStateEncoded in oscProfile.buttonStates) {
        OnScreenButtonState* buttonState = [profilesManager unarchiveButtonStateEncoded:buttonStateEncoded];
        if ([buttonState.name isEqualToString:@"dPad"]) {
            buttonState.position = [self denormalizeWidgetPosition:buttonState.position];
            D_PAD_CENTER_X = buttonState.position.x;
            D_PAD_CENTER_Y = buttonState.position.y;
        }
    }
}

/**
 * Sets analog stick positions for class const var
 */
- (void) setAnalogStickPositions {
    OSCProfile *oscProfile = [profilesManager getSelectedProfile]; // returns the currently selected OSCProfile
    
    for (NSData *buttonStateEncoded in oscProfile.buttonStates) {
        OnScreenButtonState* buttonState = [profilesManager unarchiveButtonStateEncoded:buttonStateEncoded];
        buttonState.position = [self denormalizeWidgetPosition:buttonState.position];
        if ([buttonState.name isEqualToString:@"leftStickBackground"]) {
            LS_CENTER_X = buttonState.position.x;
            LS_CENTER_Y = buttonState.position.y;
        }
        if ([buttonState.name isEqualToString:@"rightStickBackground"]) {
            RS_CENTER_X = buttonState.position.x;
            RS_CENTER_Y = buttonState.position.y;
        }
    }
}

/**
 * Loads the selected OSC profile and lays out each button associated with that profile onto the screen
 */

# define LR2_Y_UP_OFFSET 8
# define LR1_Y_DOWN_OFFSET 3.5
- (void) positionAndResizeSingleControllerLayers {
    OSCProfile *oscProfile = [profilesManager getSelectedProfile];
    bool defaultProfileSelected = [profilesManager getIndexOfSelectedProfile] == 0;
    
    for (NSData *buttonStateEncoded in oscProfile.buttonStates) {
        
        OnScreenButtonState *buttonStateDecoded = [profilesManager unarchiveButtonStateEncoded:buttonStateEncoded];


        for (CALayer *buttonLayer in self.OSCButtonLayers) {    // iterate through each button layer on screen and position and hide/unhide each according to the instructions of its associated 'buttonState'
            if ([buttonLayer.name isEqualToString:buttonStateDecoded.name]) {
                if ([buttonLayer.name isEqualToString:@"upButton"] == NO &&
                    [buttonLayer.name isEqualToString:@"rightButton"] == NO &&
                    [buttonLayer.name isEqualToString:@"downButton"] == NO &&
                    [buttonLayer.name isEqualToString:@"leftButton"] == NO &&
                    [buttonLayer.name isEqualToString:@"leftStick"] == NO &&
                    [buttonLayer.name isEqualToString:@"rightStick"] == NO) {   // Don't move these buttons since they've already been positioned correctly in the 'drawButtons' and 'drawSticks' methods called before this method is called. The 'buttonStateDecoded' object associated with these buttons contains positions relative to a parent CALayer which only exists on 'LayoutOnScreenControls'. These positions relative to the parent layers would translate incorrectly when placed on the game stream VC's 'view' layer
                    buttonStateDecoded.position = [self denormalizeWidgetPosition:buttonStateDecoded.position];
                    buttonLayer.position = buttonStateDecoded.position;
                }
                buttonLayer.hidden = buttonStateDecoded.isHidden;
                
                // adjust default layout for largerStickLR1
                if(defaultProfileSelected && _largerStickLR1){
                    if([buttonLayer.name isEqualToString:@"l2Button"] || [buttonLayer.name isEqualToString:@"r2Button"]) buttonLayer.position = CGPointMake(buttonLayer.position.x, buttonLayer.position.y - LR2_Y_UP_OFFSET);
                    if([buttonLayer.name isEqualToString:@"l1Button"] || [buttonLayer.name isEqualToString:@"r1Button"]) buttonLayer.position = CGPointMake(buttonLayer.position.x, buttonLayer.position.y + LR1_Y_DOWN_OFFSET);
                }
                // Here we deal with resizing single layer controllers only
                if ([buttonLayer.name isEqualToString:@"l1Button"] ||
                    [buttonLayer.name isEqualToString:@"r1Button"] ||
                    [buttonLayer.name isEqualToString:@"l2Button"] ||
                    [buttonLayer.name isEqualToString:@"r2Button"] ||
                    [buttonLayer.name isEqualToString:@"aButton"] ||
                    [buttonLayer.name isEqualToString:@"bButton"] ||
                    [buttonLayer.name isEqualToString:@"xButton"] ||
                    [buttonLayer.name isEqualToString:@"yButton"] ||
                    [buttonLayer.name isEqualToString:@"selectButton"] ||
                    [buttonLayer.name isEqualToString:@"startButton"]){
                    CGFloat sizeFactor = buttonStateDecoded.oscLayerSizeFactor;
                    if(sizeFactor == 0) sizeFactor = 1.0; // dealing with invalid sizefactor
                    [self resizeControllerLayerWith:buttonLayer and:sizeFactor];
                }
            }
        }
    }
}

- (void) setOpacityForStandardControllerLayers {
    for(CALayer* oscLayer in self.OSCButtonLayers){
        if(oscLayer == self._leftStick ||
           oscLayer == self._rightStick){
            oscLayer.opacity = DEFAULT_STICK_OPACITY;
        } else if(oscLayer == self._leftStickBackground ||
           oscLayer == self._rightStickBackground){
            oscLayer.opacity = 1.0;
        } else{
            oscLayer.opacity = 5.0f/6.0f;
        }
    }
}


- (void) setOpacityForCutsomControllerLayers {
    OSCProfile *oscProfile = [profilesManager getSelectedProfile];
    // bool defaultProfileSelected = [profilesManager getIndexOfSelectedProfile] == 0;
    
    for (NSData *buttonStateEncoded in oscProfile.buttonStates) {
        OnScreenButtonState* buttonStateDecoded = [profilesManager unarchiveButtonStateEncoded:buttonStateEncoded];

        for (CALayer *buttonLayer in self.OSCButtonLayers) {    // iterate through each button layer on screen
            // Here we deal with resizing single layer controllers only
            if ([buttonLayer.name isEqualToString:buttonStateDecoded.name]) {
                if ([buttonLayer.name isEqualToString:@"l1Button"] ||
                    [buttonLayer.name isEqualToString:@"r1Button"] ||
                    [buttonLayer.name isEqualToString:@"l2Button"] ||
                    [buttonLayer.name isEqualToString:@"r2Button"] ||
                    [buttonLayer.name isEqualToString:@"aButton"] ||
                    [buttonLayer.name isEqualToString:@"bButton"] ||
                    [buttonLayer.name isEqualToString:@"xButton"] ||
                    [buttonLayer.name isEqualToString:@"yButton"] ||
                    [buttonLayer.name isEqualToString:@"selectButton"] ||
                    [buttonLayer.name isEqualToString:@"startButton"] ||
                    [buttonLayer.name isEqualToString:@"upButton"] ||
                    [buttonLayer.name isEqualToString:@"rightButton"] ||
                    [buttonLayer.name isEqualToString:@"downButton"] ||
                    [buttonLayer.name isEqualToString:@"leftButton"]){
                    // NSLog(@"layerName: %@, alpha: %f", buttonLayer.name, buttonStateDecoded.backgroundAlpha);
                    [self adjustControllerLayerOpacityWith:buttonLayer and:buttonStateDecoded.backgroundAlpha];
                }
                if([buttonLayer.name isEqualToString:@"leftStickBackground"]){
                    [self adjustControllerLayerOpacityWith:buttonLayer and:_leftStickOpacity];
                }
                if([buttonLayer.name isEqualToString:@"rightStickBackground"]){
                    [self adjustControllerLayerOpacityWith:buttonLayer and:_rightStickOpacity];
                }
            }
        }
    }
}



- (void) drawStartSelect {
    // create Start button
    UIImage* startButtonImage = [UIImage imageNamed:@"StartButton"];
    UIImage* startButtonHdImage = [UIImage imageNamed:@"StartButtonHD"];
    _startButton.frame = CGRectMake(START_X - startButtonImage.size.width / 2, START_Y - startButtonImage.size.height / 2, startButtonImage.size.width, startButtonImage.size.height);
    _startButton.contents = (id) startButtonHdImage.CGImage;
    [_view.layer addSublayer:_startButton];
    
    // create Select button
    UIImage* selectButtonImage = [UIImage imageNamed:@"SelectButton"];
    UIImage* selectHdButtonImage = [UIImage imageNamed:@"SelectButtonHD"];
    _selectButton.frame = CGRectMake(SELECT_X - selectButtonImage.size.width / 2, SELECT_Y - selectButtonImage.size.height / 2, selectButtonImage.size.width, selectButtonImage.size.height);
    _selectButton.contents = (id) selectHdButtonImage.CGImage;
    [_view.layer addSublayer:_selectButton];
}

- (void) drawBumpers {
    // adjust layout for larger L2 & R2 button settings
    if(_largerStickLR1) L1_Y = R1_Y = L1_Y + LR1_Y_DOWN_OFFSET;
    
    // create L1 button
    UIImage* l1ButtonImage = [UIImage imageNamed:@"L1"];
    UIImage* l1ButtonHdImage = [UIImage imageNamed:@"L1HD"];
    _l1Button.frame = CGRectMake(L1_X - l1ButtonImage.size.width / 2, L1_Y - l1ButtonImage.size.height / 2, l1ButtonImage.size.width, l1ButtonImage.size.height);
    _l1Button.contents = (id) l1ButtonHdImage.CGImage;
    [_view.layer addSublayer:_l1Button];
    
    // create R1 button
    UIImage* r1ButtonImage = [UIImage imageNamed:@"R1"];
    UIImage* r1ButtonHdImage = [UIImage imageNamed:@"R1HD"];
    _r1Button.frame = CGRectMake(R1_X - r1ButtonImage.size.width / 2, R1_Y - r1ButtonImage.size.height / 2, r1ButtonImage.size.width, r1ButtonImage.size.height);
    _r1Button.contents = (id) r1ButtonHdImage.CGImage;
    
    // make l1 r1 the same size as l2 r2
    if(_largerStickLR1){
        UIImage* l2ButtonImage = [UIImage imageNamed:@"L2"];
        UIImage* l2ButtonHdImage = [UIImage imageNamed:@"L2HD"];
        _l1Button.bounds = _r1Button.bounds = CGRectMake(0, 0, l2ButtonImage.size.width, l2ButtonImage.size.height);
    }
    
    [_view.layer addSublayer:_r1Button];
}

- (void) drawTriggers {
    // adjust layout for larger L2 & R2 button settings
    if(_largerStickLR1) L2_Y = R2_Y = L2_Y - LR2_Y_UP_OFFSET;
    
    // create L2 button
    UIImage* l2ButtonImage = [UIImage imageNamed:@"L2"];
    UIImage* l2ButtonHdImage = [UIImage imageNamed:@"L2HD"];
    _l2Button.frame = CGRectMake(L2_X - l2ButtonImage.size.width / 2, L2_Y - l2ButtonImage.size.height / 2, l2ButtonImage.size.width, l2ButtonImage.size.height);
    _l2Button.contents = (id) l2ButtonHdImage.CGImage;
    [_view.layer addSublayer:_l2Button];
    
    // create R2 button
    UIImage* r2ButtonImage = [UIImage imageNamed:@"R2"];
    UIImage* r2ButtonHdImage = [UIImage imageNamed:@"R2HD"];
    _r2Button.frame = CGRectMake(R2_X - r2ButtonImage.size.width / 2, R2_Y - r2ButtonImage.size.height / 2, r2ButtonImage.size.width, r2ButtonImage.size.height);
    _r2Button.contents = (id) r2ButtonHdImage.CGImage;
    [_view.layer addSublayer:_r2Button];
}

- (void) drawSticks {
    // create left analog stick
    UIImage* leftStickBgImage = [UIImage imageNamed:@"StickOuter"];
    UIImage* stickBgHdImage = [UIImage imageNamed:@"StickOuterHD"];

    _leftStickBackground.frame = CGRectMake(LS_CENTER_X - leftStickBgImage.size.width / 2, LS_CENTER_Y - leftStickBgImage.size.height / 2, leftStickBgImage.size.width, leftStickBgImage.size.height);
    _leftStickBackground.contents = (id) stickBgHdImage.CGImage;
    [_view.layer addSublayer:_leftStickBackground];
    
    UIImage* leftStickImage = [UIImage imageNamed:@"StickInner"];
    UIImage* stickHdImage = [UIImage imageNamed:@"StickInnerHD"];
    _leftStick.frame = CGRectMake(LS_CENTER_X - leftStickImage.size.width / 2, LS_CENTER_Y - leftStickImage.size.height / 2, leftStickImage.size.width, leftStickImage.size.height);
    _leftStick.contents = (id) stickHdImage.CGImage;
    _leftStick.opacity = _leftStickOpacity; // make stick half transparent when it's idle
    [_view.layer addSublayer:_leftStick];
    
    // create right analog stick
    UIImage* rightStickBgImage = [UIImage imageNamed:@"StickOuter"];
    _rightStickBackground.frame = CGRectMake(RS_CENTER_X - rightStickBgImage.size.width / 2, RS_CENTER_Y - rightStickBgImage.size.height / 2, rightStickBgImage.size.width, rightStickBgImage.size.height);
    _rightStickBackground.contents = (id) stickBgHdImage.CGImage;
    [_view.layer addSublayer:_rightStickBackground];
    
    
    
    UIImage* rightStickImage = [UIImage imageNamed:@"StickInner"];
    _rightStick.frame = CGRectMake(RS_CENTER_X - rightStickImage.size.width / 2, RS_CENTER_Y - rightStickImage.size.height / 2, rightStickImage.size.width, rightStickImage.size.height);
    
    _rightStick.contents = (id) stickHdImage.CGImage;
    _rightStick.opacity = _rightStickOpacity; // make stick half transparent when it's idle
    [_view.layer addSublayer:_rightStick];
    
    // make stick larger
    if(_largerStickLR1){
        // sticks are resized here by the sizefactor persisted in the osc profile.
        RIGHT_STICK_INNER_SIZE = rightStickImage.size.width *1.33 * _rightStickSizeFactor;
        RIGHT_STICK_OUTER_SIZE = rightStickBgImage.size.width *1.10 * _rightStickSizeFactor;
        _rightStick.bounds = CGRectMake(0, 0, RIGHT_STICK_INNER_SIZE, RIGHT_STICK_INNER_SIZE);
        _rightStickBackground.bounds = CGRectMake(0, 0, RIGHT_STICK_OUTER_SIZE, RIGHT_STICK_OUTER_SIZE);
        
        LEFT_STICK_INNER_SIZE = rightStickImage.size.width *1.33 * _leftStickSizeFactor;
        LEFT_STICK_OUTER_SIZE = rightStickBgImage.size.width *1.10 * _leftStickSizeFactor;
        _leftStick.bounds = CGRectMake(0, 0, LEFT_STICK_INNER_SIZE, LEFT_STICK_INNER_SIZE);
        _leftStickBackground.bounds = CGRectMake(0, 0, LEFT_STICK_OUTER_SIZE, LEFT_STICK_OUTER_SIZE);
    }
    else{
        // sticks are resized here by the sizefactor persisted in the osc profile.
        RIGHT_STICK_INNER_SIZE = rightStickImage.size.width * _rightStickSizeFactor;
        RIGHT_STICK_OUTER_SIZE = rightStickBgImage.size.width * _rightStickSizeFactor;
        _rightStick.bounds = CGRectMake(0, 0, RIGHT_STICK_INNER_SIZE, RIGHT_STICK_INNER_SIZE);
        _rightStickBackground.bounds = CGRectMake(0, 0, RIGHT_STICK_OUTER_SIZE, RIGHT_STICK_OUTER_SIZE);
        
        LEFT_STICK_INNER_SIZE = rightStickImage.size.width * _leftStickSizeFactor;
        LEFT_STICK_OUTER_SIZE = rightStickBgImage.size.width * _leftStickSizeFactor;
        _leftStick.bounds = CGRectMake(0, 0, LEFT_STICK_INNER_SIZE, LEFT_STICK_INNER_SIZE);
        _leftStickBackground.bounds = CGRectMake(0, 0, LEFT_STICK_OUTER_SIZE, LEFT_STICK_OUTER_SIZE);
    }
}

- (void) drawL3R3 {
    UIImage* l3ButtonImage = [UIImage imageNamed:@"L3"];
    _l3Button.frame = CGRectMake(L3_X - l3ButtonImage.size.width / 2, L3_Y - l3ButtonImage.size.height / 2, l3ButtonImage.size.width, l3ButtonImage.size.height);
    _l3Button.contents = (id) l3ButtonImage.CGImage;
    _l3Button.cornerRadius = l3ButtonImage.size.width / 2;
    _l3Button.borderColor = [UIColor colorWithRed:15.f/255 green:160.f/255 blue:40.f/255 alpha:1.f].CGColor;
    [_view.layer addSublayer:_l3Button];
    
    UIImage* r3ButtonImage = [UIImage imageNamed:@"R3"];
    _r3Button.frame = CGRectMake(R3_X - r3ButtonImage.size.width / 2, R3_Y - r3ButtonImage.size.height / 2, r3ButtonImage.size.width, r3ButtonImage.size.height);
    _r3Button.contents = (id) r3ButtonImage.CGImage;
    _r3Button.cornerRadius = r3ButtonImage.size.width / 2;
    _r3Button.borderColor = [UIColor colorWithRed:15.f/255 green:160.f/255 blue:40.f/255 alpha:1.f].CGColor;
    [_view.layer addSublayer:_r3Button];
}

- (void) hideButtons {
    [_aButton removeFromSuperlayer];
    [_bButton removeFromSuperlayer];
    [_xButton removeFromSuperlayer];
    [_yButton removeFromSuperlayer];
    [_upButton removeFromSuperlayer];
    [_downButton removeFromSuperlayer];
    [_leftButton removeFromSuperlayer];
    [_rightButton removeFromSuperlayer];
}

- (void) hideStartSelect {
    [_startButton removeFromSuperlayer];
    [_selectButton removeFromSuperlayer];
}

- (void) hideBumpers {
    [_l1Button removeFromSuperlayer];
    [_r1Button removeFromSuperlayer];
}

- (void) hideTriggers {
    [_l2Button removeFromSuperlayer];
    [_r2Button removeFromSuperlayer];
}

- (void) hideSticks {
    [_leftStickBackground removeFromSuperlayer];
    [_rightStickBackground removeFromSuperlayer];
    [_leftStick removeFromSuperlayer];
    [_rightStick removeFromSuperlayer];
}

- (void) hideL3R3 {
    [_l3Button removeFromSuperlayer];
    [_r3Button removeFromSuperlayer];
}

- (BOOL) handleTouchMovedEvent:touches {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    BOOL updated = false;
    BOOL buttonTouch = false;
    // we'll set fixed stick range despite stick & its background are resizable
    float rsMaxX = RS_CENTER_X + standardStickBackgroundBounds.size.width / 2;
    float rsMaxY = RS_CENTER_Y + standardStickBackgroundBounds.size.width / 2;
    float rsMinX = RS_CENTER_X - standardStickBackgroundBounds.size.width / 2;
    float rsMinY = RS_CENTER_Y - standardStickBackgroundBounds.size.width / 2;
    float lsMaxX = LS_CENTER_X + standardStickBackgroundBounds.size.width / 2;
    float lsMaxY = LS_CENTER_Y + standardStickBackgroundBounds.size.width / 2;
    float lsMinX = LS_CENTER_X - standardStickBackgroundBounds.size.width / 2;
    float lsMinY = LS_CENTER_Y - standardStickBackgroundBounds.size.width / 2;
    
    for (UITouch* touch in touches) {
        CGPoint touchLocation = [touch locationInView:_view];
        float xLoc = touchLocation.x;
        float yLoc = touchLocation.y;
        if (touch == _lsTouch) {
            if (xLoc > lsMaxX) xLoc = lsMaxX;
            if (xLoc < lsMinX) xLoc = lsMinX;
            if (yLoc > lsMaxY) yLoc = lsMaxY;
            if (yLoc < lsMinY) yLoc = lsMinY;
            
            _leftStick.frame = CGRectMake(xLoc - LEFT_STICK_INNER_SIZE / 2, yLoc - LEFT_STICK_INNER_SIZE / 2, LEFT_STICK_INNER_SIZE, LEFT_STICK_INNER_SIZE);
            
            float xStickVal = (xLoc - LS_CENTER_X) / (lsMaxX - LS_CENTER_X);
            float yStickVal = (yLoc - LS_CENTER_Y) / (lsMaxY - LS_CENTER_Y);
            
            if (fabsf(xStickVal) < STICK_DEAD_ZONE) xStickVal = 0;
            if (fabsf(yStickVal) < STICK_DEAD_ZONE) yStickVal = 0;
            
            [_controllerSupport updateLeftStick:_controller x:0x7FFE * xStickVal y:0x7FFE * -yStickVal];
            
            updated = true;
        } else if (touch == _rsTouch) { // stick move event handled here
            if (xLoc > rsMaxX) xLoc = rsMaxX;
            if (xLoc < rsMinX) xLoc = rsMinX;
            if (yLoc > rsMaxY) yLoc = rsMaxY;
            if (yLoc < rsMinY) yLoc = rsMinY;
            
            _rightStick.frame = CGRectMake(xLoc - RIGHT_STICK_INNER_SIZE / 2, yLoc - RIGHT_STICK_INNER_SIZE / 2, RIGHT_STICK_INNER_SIZE, RIGHT_STICK_INNER_SIZE);
            
            float xStickVal = (xLoc - RS_CENTER_X) / (rsMaxX - RS_CENTER_X);
            float yStickVal = (yLoc - RS_CENTER_Y) / (rsMaxY - RS_CENTER_Y);
            
            if (fabsf(xStickVal) < STICK_DEAD_ZONE) xStickVal = 0;
            if (fabsf(yStickVal) < STICK_DEAD_ZONE) yStickVal = 0;
            
            [_controllerSupport updateRightStick:_controller x:0x7FFE * xStickVal y:0x7FFE * -yStickVal]; // stick value populated to the controllerSupport here
            // NSLog(@"rStickValue, x: %f, y: %f", 0x7FFE * xStickVal, 0x7FFE * yStickVal);
            // NSLog(@"real controlled instance: %@", self);

            updated = true;
        } else if (touch == _dpadTouch) {
            [_controllerSupport clearButtonFlag:_controller
                                          flags:UP_FLAG | DOWN_FLAG | LEFT_FLAG | RIGHT_FLAG];
            
            // Allow the user to slide their finger to another d-pad button
            if ([_upButton.presentationLayer hitTest:touchLocation]) {
                [_controllerSupport setButtonFlag:_controller flags:UP_FLAG];
                [self oscButtonTouchDownFeedback:_upButton];
                updated = true;
            } else {
                _upButton.opacity = [_originalControllerLayerOpacityDict[_upButton.name] floatValue];
                _upButton.shadowOpacity = 0.0;
            }

            if ([_downButton.presentationLayer hitTest:touchLocation]) {
                [_controllerSupport setButtonFlag:_controller flags:DOWN_FLAG];
                [self oscButtonTouchDownFeedback:_downButton];
                updated = true;
            } else {
                _downButton.opacity = [_originalControllerLayerOpacityDict[_downButton.name] floatValue];
                _downButton.shadowOpacity = 0.0;
            }

            if ([_leftButton.presentationLayer hitTest:touchLocation]) {
                [_controllerSupport setButtonFlag:_controller flags:LEFT_FLAG];
                [self oscButtonTouchDownFeedback:_leftButton];
                updated = true;
            } else {
                _leftButton.opacity = [_originalControllerLayerOpacityDict[_leftButton.name] floatValue];
                _leftButton.shadowOpacity = 0.0;
            }
            
            if ([_rightButton.presentationLayer hitTest:touchLocation]) {
                [_controllerSupport setButtonFlag:_controller flags:RIGHT_FLAG];
                [self oscButtonTouchDownFeedback:_rightButton];
                updated = true;
            } else {
                _rightButton.opacity = [_originalControllerLayerOpacityDict[_rightButton.name] floatValue];
                _rightButton.shadowOpacity = 0.0;
            }
            
            buttonTouch = true;
        } else if (touch == _aTouch) {
            buttonTouch = true;
        } else if (touch == _bTouch) {
            buttonTouch = true;
        } else if (touch == _xTouch) {
            buttonTouch = true;
        } else if (touch == _yTouch) {
            buttonTouch = true;
        } else if (touch == _startTouch) {
            buttonTouch = true;
        } else if (touch == _selectTouch) {
            buttonTouch = true;
        } else if (touch == _l1Touch) {
            buttonTouch = true;
        } else if (touch == _r1Touch) {
            buttonTouch = true;
        } else if (touch == _l2Touch) {
            buttonTouch = true;
        } else if (touch == _r2Touch) {
            buttonTouch = true;
        } else if (touch == _l3Touch) {
            buttonTouch = true;
        } else if (touch == _r3Touch) {
            buttonTouch = true;
        }
        if ([_deadTouches containsObject:touch]) {
            updated = true;
        }
    }
    if (updated) {
        [_controllerSupport updateFinished:_controller]; // here's the method called to send controller event to the remote side
    }
    
    [CATransaction commit];// commit the transaction to disable animation

    return updated || buttonTouch;
}


- (void)oscButtonTouchDownFeedback:(CALayer* )button{
    [CATransaction begin];
    [CATransaction setDisableActions:YES]; 
    
    /*
    if(![[_originalControllerLayerOpacityDict allKeys] containsObject:button.name]){
        [_originalControllerLayerOpacityDict setObject:@(button.opacity) forKey:button.name];
    }
     */
    
    button.opacity = 0.9; // set a high opacity to ensure visibility of visual effect
    button.borderColor = [UIColor clearColor].CGColor; // Color of the outline
    button.borderWidth = 20; // Width of the outline
    button.cornerRadius = button.bounds.size.width/2;
    
    // 使用 shadowPath 定义阴影形状和扩展范围
    CGFloat spread = 15;  // 扩散的大小
    if([button.name isEqualToString:@"leftStick"] || [button.name isEqualToString:@"rightStick"]) spread = 12;
    CGRect largerRect = CGRectInset(button.bounds, -spread, -spread);
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:largerRect cornerRadius:button.cornerRadius];
    button.shadowPath = shadowPath.CGPath;
    
    //button.shadowColor = [[UIColor colorWithRed:0/255.0 green:110/255.0 blue:255/255.0 alpha:1.0] colorWithAlphaComponent:0.7].CGColor;
    button.shadowColor = [[UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:1] colorWithAlphaComponent:1].CGColor;
    //button.shadowColor = [UIColor colorWithRed:0/255.0 green:51/255.0 blue:102/255.0 alpha:0.6].CGColor;
    button.shadowOffset = CGSizeZero;
    button.shadowOpacity = 1.0;
    button.shadowRadius = 0.0; // Adjust the radius to simulate border thickness
    
    NSNumber *style = [OnScreenControls.layerVibrationStyleDic objectForKey:button.name];
    uint8_t vibrationStyle = [style unsignedCharValue];
    
    bool vibraiontOn;
    if (@available(iOS 13.0, *)) {
        vibraiontOn = vibrationStyle < UIImpactFeedbackStyleRigid+1;
    } else {
        vibraiontOn = vibrationStyle < UIImpactFeedbackStyleHeavy+1;
    }
    // NSLog(@"vibration on: %d",vibraiontOn);

    if(vibraiontOn){
        vibrationGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:vibrationStyle];
        [vibrationGenerator prepare];
        [vibrationGenerator impactOccurred];
        NSLog(@"vibration instance: %@",vibrationGenerator);
    }

    
    [CATransaction commit];
}


// osc Button capturing here
- (BOOL)handleTouchDownEvent:touches {
    BOOL updated = false;
    BOOL stickTouch = false;
    for (UITouch* touch in touches) {
        
        bool touchEventCapturedByOsc = false; // this flag will be reset for every touch event in the for-loop
        
        CGPoint touchLocation = [touch locationInView:_view];
        
        if ([_aButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:A_FLAG];
            _aTouch = touch;
            [self oscButtonTouchDownFeedback:_aButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC A");
        } else if ([_bButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:B_FLAG];
            _bTouch = touch;
            [self oscButtonTouchDownFeedback:_bButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC B");
        } else if ([_xButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:X_FLAG];
            _xTouch = touch;
            [self oscButtonTouchDownFeedback:_xButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC X");
        } else if ([_yButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:Y_FLAG];
            _yTouch = touch;
            [self oscButtonTouchDownFeedback:_yButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC Y");
        } else if ([_upButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:UP_FLAG];
            _dpadTouch = touch;
            _upTouch = touch;
            [self oscButtonTouchDownFeedback:_upButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC UP");
        } else if ([_downButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:DOWN_FLAG];
            _dpadTouch = touch;
            _downTouch = touch;
            [self oscButtonTouchDownFeedback:_downButton];
            updated = true;
            touchEventCapturedByOsc = true;
        } else if ([_leftButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:LEFT_FLAG];
            _dpadTouch = touch;
            _leftTouch = touch;
            [self oscButtonTouchDownFeedback:_leftButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC LEFT");
        } else if ([_rightButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:RIGHT_FLAG];
            _dpadTouch = touch;
            _rightTouch = touch;
            [self oscButtonTouchDownFeedback:_rightButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC RIGHT");
        } else if ([_startButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:PLAY_FLAG];
            _startTouch = touch;
            [self oscButtonTouchDownFeedback:_startButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC PLAY");
        } else if ([_selectButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:BACK_FLAG];
            _selectTouch = touch;
            [self oscButtonTouchDownFeedback:_selectButton];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC BACK");
        } else if ([_l1Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:LB_FLAG];
            _l1Touch = touch;
            [self oscButtonTouchDownFeedback:_l1Button];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC LB");
        } else if ([_r1Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:RB_FLAG];
            _r1Touch = touch;
            [self oscButtonTouchDownFeedback:_r1Button];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC RB");
        } else if ([_l2Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport updateLeftTrigger:_controller left:0xFF];
            _l2Touch = touch;
            [self oscButtonTouchDownFeedback:_l2Button];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC LeftTrigger");
        } else if ([_r2Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport updateRightTrigger:_controller right:0xFF];
            _r2Touch = touch;
            [self oscButtonTouchDownFeedback:_r2Button];
            updated = true;
            touchEventCapturedByOsc = true;
            // NSLog(@"Captured OSC RightTrigger");
        } else if ([_l3Button.presentationLayer hitTest:touchLocation]) {
            if (l3Set) {
                [_controllerSupport clearButtonFlag:_controller flags:LS_CLK_FLAG];
                _l3Button.borderWidth = 0.0f;
                // NSLog(@"Captured OSC LS_CLK");
            } else {
                [_controllerSupport setButtonFlag:_controller flags:LS_CLK_FLAG];
                _l3Button.borderWidth = 2.0f;
                // NSLog(@"Captured OSC LS_CLK2");
            }
            l3Set = !l3Set;
            _l3Touch = touch;
            updated = true;
            touchEventCapturedByOsc = true;
        } else if ([_r3Button.presentationLayer hitTest:touchLocation]) {
            if (r3Set) {
                [_controllerSupport clearButtonFlag:_controller flags:RS_CLK_FLAG];
                _r3Button.borderWidth = 0.0f;
                // NSLog(@"Captured OSC RS_CLK");
            } else {
                [_controllerSupport setButtonFlag:_controller flags:RS_CLK_FLAG];
                _r3Button.borderWidth = 2.0f;
                // NSLog(@"Captured OSC RS_CLK2");
            }
            r3Set = !r3Set;
            _r3Touch = touch;
            updated = true;
            touchEventCapturedByOsc = true;
        } else if ([_leftStick.presentationLayer hitTest:touchLocation]) {
            _leftStick.opacity = 1.0; // make stick opaque while being moved
            if (l3TouchStart != nil) {
                // Find elapsed time and convert to milliseconds
                // Use (-) modifier to conversion since receiver is earlier than now
                double l3TouchTime = [l3TouchStart timeIntervalSinceNow] * -1000.0;
                if (l3TouchTime < STICK_CLICK_RATE) {
                    [_controllerSupport setButtonFlag:_controller flags:LS_CLK_FLAG];
                    [self oscButtonTouchDownFeedback:_leftStick];
                    updated = true;
                    touchEventCapturedByOsc = true;
                    // NSLog(@"Captured OSC LS_CLK3");

                }
            }
            _lsTouch = touch;
            stickTouch = true;
            touchEventCapturedByOsc = true;
        } else if ([_rightStick.presentationLayer hitTest:touchLocation]) {
            _rightStick.opacity = 1.0; // make stick opaque while being moved
            if (r3TouchStart != nil) {
                // Find elapsed time and convert to milliseconds
                // Use (-) modifier to conversion since receiver is earlier than now
                double r3TouchTime = [r3TouchStart timeIntervalSinceNow] * -1000.0;
                if (r3TouchTime < STICK_CLICK_RATE) {
                    [_controllerSupport setButtonFlag:_controller flags:RS_CLK_FLAG];
                    [self oscButtonTouchDownFeedback:_rightStick];
                    updated = true;
                    touchEventCapturedByOsc = true;
                    // NSLog(@"Captured OSC LS_CLK4");
                }
            }
            _rsTouch = touch;
            stickTouch = true;
            touchEventCapturedByOsc = true;
        }
        if (!updated && !stickTouch && [self isInDeadZone:touch]) {
            [_deadTouches addObject:touch];
            updated = true;
            touchEventCapturedByOsc = true;
        }
        // additionally, populate the touchesCapturedByOSButton set, for native/relative touch handler to deal with.
        if(touchEventCapturedByOsc) [touchAddrsCapturedByOnScreenControls addObject:@((uintptr_t)touch)];
    }
    if (updated) {
        [_controllerSupport updateFinished:_controller];
    }
    // NSLog(@"captured by OSB touches, OSC Class: %d", (uint32_t)[touchAddrsCapturedByOnScreenControls count]);

    
    bool oscTouched = updated || stickTouch;
    if(oscTouched){
        for (UIGestureRecognizer *gesture in _view.gestureRecognizers) { // we'll iterate the streamFrameTopLayerView, which was passed here as _view, where all the custom gestures are added) instead of the streamview, to check if that the osc buttons are pressed
            if ([gesture isKindOfClass:[CustomTapGestureRecognizer class]]) {
                // This is a CustomTapGestureRecognizer
                CustomTapGestureRecognizer *tapGesture = (CustomTapGestureRecognizer *)gesture;
                tapGesture.isOnScreenControllerBeingPressed = true;
                // Perform actions with tapGesture
            }
        }
    }
    
    return oscTouched;
}

- (BOOL)handleTouchUpEvent:touches {
    BOOL updated = false;
    BOOL touched = false;
    for (UITouch* touch in touches) {
        
        // remove the touch obj from touchesCapturedByOnScreenButtons
        if([touchAddrsCapturedByOnScreenControls containsObject:@((uintptr_t)touch)]) [touchAddrsCapturedByOnScreenControls removeObject:@((uintptr_t)touch)];
        
        if (touch == _aTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:A_FLAG];
            _aTouch = nil;
            _aButton.opacity = [_originalControllerLayerOpacityDict[_aButton.name] floatValue];
            _aButton.shadowOpacity = 0.0; // reset button shadow & background color
            updated = true;
        } else if (touch == _bTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:B_FLAG];
            _bTouch = nil;
            _bButton.opacity = [_originalControllerLayerOpacityDict[_bButton.name] floatValue];
            _bButton.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _xTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:X_FLAG];
            _xTouch = nil;
            _xButton.opacity = [_originalControllerLayerOpacityDict[_xButton.name] floatValue];
            _xButton.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _yTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:Y_FLAG];
            _yTouch = nil;
            _yButton.opacity = [_originalControllerLayerOpacityDict[_yButton.name] floatValue];
            _yButton.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _dpadTouch) {
            [_controllerSupport clearButtonFlag:_controller
                                          flags:UP_FLAG | DOWN_FLAG | LEFT_FLAG | RIGHT_FLAG];
            _dpadTouch = nil;
            _upButton.opacity = [_originalControllerLayerOpacityDict[_upButton.name] floatValue];
            _upButton.shadowOpacity = 0.0;
            _leftButton.opacity = [_originalControllerLayerOpacityDict[_leftButton.name] floatValue];
            _leftButton.shadowOpacity = 0.0;
            _rightButton.opacity = [_originalControllerLayerOpacityDict[_rightButton.name] floatValue];
            _rightButton.shadowOpacity = 0.0;
            _downButton.opacity = [_originalControllerLayerOpacityDict[_downButton.name] floatValue];
            _downButton.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _startTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:PLAY_FLAG];
            _startTouch = nil;
            _startButton.opacity = [_originalControllerLayerOpacityDict[_startButton.name] floatValue];
            _startButton.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _selectTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:BACK_FLAG];
            _selectTouch = nil;
            _selectButton.opacity = [_originalControllerLayerOpacityDict[_selectButton.name] floatValue];
            _selectButton.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _l1Touch) {
            [_controllerSupport clearButtonFlag:_controller flags:LB_FLAG];
            _l1Touch = nil;
            _l1Button.opacity = [_originalControllerLayerOpacityDict[_l1Button.name] floatValue];
            _l1Button.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _r1Touch) {
            [_controllerSupport clearButtonFlag:_controller flags:RB_FLAG];
            _r1Touch = nil;
            _r1Button.opacity = [_originalControllerLayerOpacityDict[_r1Button.name] floatValue];
            _r1Button.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _l2Touch) {
            [_controllerSupport updateLeftTrigger:_controller left:0];
            _l2Button.opacity = [_originalControllerLayerOpacityDict[_l2Button.name] floatValue];
            _l2Touch = nil;
            _l2Button.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _r2Touch) {
            [_controllerSupport updateRightTrigger:_controller right:0];
            _r2Button.opacity = [_originalControllerLayerOpacityDict[_r2Button.name] floatValue];
            _r2Touch = nil;
            _r2Button.shadowOpacity = 0.0;
            updated = true;
        } else if (touch == _lsTouch) {
            _leftStick.frame = CGRectMake(LS_CENTER_X - LEFT_STICK_INNER_SIZE / 2, LS_CENTER_Y - LEFT_STICK_INNER_SIZE / 2, LEFT_STICK_INNER_SIZE, LEFT_STICK_INNER_SIZE);
            _leftStick.opacity = [_originalControllerLayerOpacityDict[_leftStick.name] floatValue];
            _leftStick.shadowOpacity = 0.0;
            _leftStick.opacity = _leftStickOpacity; // reset stick to half transparent
            [_controllerSupport updateLeftStick:_controller x:0 y:0];
            [_controllerSupport clearButtonFlag:_controller flags:LS_CLK_FLAG];
            l3TouchStart = [NSDate date];
            _lsTouch = nil;
            updated = true;
        } else if (touch == _rsTouch) {
            _rightStick.frame = CGRectMake(RS_CENTER_X - RIGHT_STICK_INNER_SIZE / 2, RS_CENTER_Y - RIGHT_STICK_INNER_SIZE / 2, RIGHT_STICK_INNER_SIZE, RIGHT_STICK_INNER_SIZE);
            _rightStick.opacity = [_originalControllerLayerOpacityDict[_rightStick.name] floatValue];
            _rightStick.shadowOpacity = 0.0;
            _rightStick.opacity = _rightStickOpacity;
            [_controllerSupport updateRightStick:_controller x:0 y:0];
            [_controllerSupport clearButtonFlag:_controller flags:RS_CLK_FLAG];
            r3TouchStart = [NSDate date];
            _rsTouch = nil;
            updated = true;
        }
        else if (touch == _l3Touch) {
            _l3Touch = nil;
            touched = true;
        }
        else if (touch == _r3Touch) {
            _r3Touch = nil;
            touched = true;
        }
        if ([_deadTouches containsObject:touch]) {
            [_deadTouches removeObject:touch];
            updated = true;
        }
    }
    if (updated) {
        [_controllerSupport updateFinished:_controller];
    }
    
    return updated || touched;
}

- (BOOL) isInDeadZone:(UITouch*) touch {
    // Dynamically evaluate deadzones based on the controls
    // on screen at the time
    
    // DZ capturing shall be refactored in CustomOSC Mode & non-default profile condition
    if(self._level == OnScreenControlsLevelCustom){
        CGPoint touchLocation  = [touch locationInView:_view];
        for (NSString *key in _activeCustomOscButtonPositionDict) {
            NSValue *value = _activeCustomOscButtonPositionDict[key];
            CGPoint buttonPosition = [value CGPointValue];
            CGFloat xOffset = fabs(touchLocation.x - buttonPosition.x);
            CGFloat yOffset = fabs(touchLocation.y - buttonPosition.y);
            
            CGFloat dzHalfWidth;
            CGFloat dzHalfHeight;
            // CGFloat _oscTapExlusionAreaSizeFactor; // the factor to resize the DZ
            // NSLog(@"_AreaSize: %f", _oscTapExlusionAreaSizeFactor);

            if ([key isEqualToString:@"l2Button"]) {
                dzHalfWidth = _l2Button.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _l2Button.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"l1Button"]) {  // set the same DZ size as other buttons
                dzHalfWidth = _l2Button.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _l2Button.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"dPad"]) {
                dzHalfWidth = _leftButton.bounds.size.width * _oscTapExlusionAreaSizeFactor; // dPad specially handled
                dzHalfHeight = _upButton.bounds.size.height * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"selectButton"]) {
                dzHalfWidth = _selectButton.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _selectButton.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"leftStickBackground"]) {
                dzHalfWidth = _leftStickBackground.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor; // stick backgound size is too big to be the base line
                dzHalfHeight = _leftStickBackground.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"rightStickBackground"]) {
                dzHalfWidth = _rightStickBackground.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _rightStickBackground.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"r2Button"]) {
                dzHalfWidth = _r2Button.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _r2Button.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"r1Button"]) { // set the same DZ size as other buttons
                dzHalfWidth = _l2Button.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _l2Button.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"aButton"]) {
                dzHalfWidth = _aButton.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _aButton.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"bButton"]) {
                dzHalfWidth = _bButton.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _bButton.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"xButton"]) {
                dzHalfWidth = _xButton.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _xButton.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"yButton"]) {
                dzHalfWidth = _yButton.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _yButton.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else if ([key isEqualToString:@"startButton"]) {
                dzHalfWidth = _startButton.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _startButton.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            } else {
                dzHalfWidth = _aButton.bounds.size.width * 0.5 * _oscTapExlusionAreaSizeFactor;
                dzHalfHeight = _aButton.bounds.size.height * 0.5 * _oscTapExlusionAreaSizeFactor;
            }
            
            if (xOffset < dzHalfWidth && yOffset < dzHalfHeight) {
                //NSLog(@"captured in DZ");
                return true;
            }
        }
        return false;
    }
    

    // Here is the original non-custom DZ capturing
    if (_leftButton.superlayer != nil && [self isDpadDeadZone:touch]) {
        return true;
    }
    else if (_aButton.superlayer != nil && [self isAbxyDeadZone:touch]) {
        return true;
    }
    else if (_l2Button.superlayer != nil && [self isTriggerDeadZone:touch]) {
        return true;
    }
    else if (_l1Button.superlayer != nil && [self isBumperDeadZone:touch]) {
        return true;
    }
    else if (_startButton.superlayer != nil && [self isStartSelectDeadZone:touch]) {
        return true;
    }
    else if (_l3Button.superlayer != nil && [self isL3R3DeadZone:touch]) {
        return true;
    }
    else if (_leftStickBackground.superlayer != nil && [self isStickDeadZone:touch]) {
        return true;
    }
    
    return false;
}

- (BOOL) isDpadDeadZone:(UITouch*) touch {
    return [self isDeadZone:touch
                     startX:_view.frame.origin.x
                     startY:_upButton.frame.origin.y
                       endX:_rightButton.frame.origin.x + _rightButton.frame.size.width
                       endY:_view.frame.origin.y + _view.frame.size.height];
}

- (BOOL) isAbxyDeadZone:(UITouch*) touch {
    return [self isDeadZone:touch
                     startX:_xButton.frame.origin.x
                     startY:_yButton.frame.origin.y
                       endX:_view.frame.origin.x + _view.frame.size.width
                       endY:_view.frame.origin.y + _view.frame.size.height];
}

- (BOOL) isBumperDeadZone:(UITouch*) touch {
    return [self isDeadZone:touch
                     startX:_view.frame.origin.x
                     startY:_l2Button.frame.origin.y + _l2Button.frame.size.height
                       endX:_l1Button.frame.origin.x + _l1Button.frame.size.width
                       endY:_upButton.frame.origin.y]
    || [self isDeadZone:touch
                 startX:_r2Button.frame.origin.x
                 startY:_r2Button.frame.origin.y + _r2Button.frame.size.height
                   endX:_view.frame.origin.x + _view.frame.size.width
                   endY:_yButton.frame.origin.y];
}

- (BOOL) isTriggerDeadZone:(UITouch*) touch {
    return [self isDeadZone:touch
                     startX:_view.frame.origin.x
                     startY:_l2Button.frame.origin.y
                       endX:_l2Button.frame.origin.x + _l2Button.frame.size.width
                       endY:_view.frame.origin.y + _view.frame.size.height]
    || [self isDeadZone:touch
                 startX:_r2Button.frame.origin.x
                 startY:_r2Button.frame.origin.y
                   endX:_view.frame.origin.x + _view.frame.size.width
                   endY:_view.frame.origin.y + _view.frame.size.height];
}

- (BOOL) isL3R3DeadZone:(UITouch*) touch {
    return [self isDeadZone:touch
                     startX:_view.frame.origin.x
                     startY:_l3Button.frame.origin.y
                       endX:_view.frame.origin.x
                       endY:_view.frame.origin.y + _view.frame.size.height]
    || [self isDeadZone:touch
                 startX:_r3Button.frame.origin.x
                 startY:_r3Button.frame.origin.y
                   endX:_view.frame.origin.x + _view.frame.size.width
                   endY:_view.frame.origin.y + _view.frame.size.height];
}

- (BOOL) isStartSelectDeadZone:(UITouch*) touch {
    return [self isDeadZone:touch
                     startX:_startButton.frame.origin.x
                     startY:_startButton.frame.origin.y
                       endX:_view.frame.origin.x + _view.frame.size.width
                       endY:_view.frame.origin.y + _view.frame.size.height]
    || [self isDeadZone:touch
                 startX:_view.frame.origin.x
                 startY:_selectButton.frame.origin.y
                   endX:_selectButton.frame.origin.x + _selectButton.frame.size.width
                   endY:_view.frame.origin.y + _view.frame.size.height];
}

- (BOOL) isStickDeadZone:(UITouch*) touch {
    return [self isDeadZone:touch
                     startX:_leftStickBackground.frame.origin.x - 15
                     startY:_leftStickBackground.frame.origin.y - 15
                       endX:_leftStickBackground.frame.origin.x + _leftStickBackground.frame.size.width + 15
                       endY:_view.frame.origin.y + _view.frame.size.height]
    || [self isDeadZone:touch
                 startX:_rightStickBackground.frame.origin.x - 15
                 startY:_rightStickBackground.frame.origin.y - 15
                   endX:_rightStickBackground.frame.origin.x + _rightStickBackground.frame.size.width + 15
                   endY:_view.frame.origin.y + _view.frame.size.height];
}

- (BOOL) isDeadZone:(UITouch*) touch startX:(float)deadZoneStartX startY:(float)deadZoneStartY endX:(float)deadZoneEndX endY:(float)deadZoneEndY {
    deadZoneStartX -= DEAD_ZONE_PADDING;
    deadZoneStartY -= DEAD_ZONE_PADDING;
    deadZoneEndX += DEAD_ZONE_PADDING;
    deadZoneEndY += DEAD_ZONE_PADDING;
    
    CGPoint touchLocation = [touch locationInView:_view];
    return (touchLocation.x > deadZoneStartX && touchLocation.x < deadZoneEndX
            && touchLocation.y > deadZoneStartY && touchLocation.y < deadZoneEndY);
}

+ (CGFloat) getControllerLayerSizeFactor:(CALayer*)layer{
    CGFloat sizeFactor = 1.0;
    if([layer.name isEqualToString:@"aButton"]||
        [layer.name isEqualToString:@"bButton"] ||
        [layer.name isEqualToString:@"xButton"] ||
        [layer.name isEqualToString:@"yButton"] ||
        [layer.name isEqualToString:@"l1Button"] ||
        [layer.name isEqualToString:@"l2Button"] ||
        [layer.name isEqualToString:@"r1Button"] ||
        [layer.name isEqualToString:@"r2Button"]){
        sizeFactor = layer.bounds.size.width / standardRoundButtonBounds.size.width;
    }
    
    if([layer.name isEqualToString:@"selectButton"] ||
        [layer.name isEqualToString:@"startButton"]) {
        sizeFactor = layer.bounds.size.width / standardRectangleButtonBounds.size.width;
    }
    
    if([layer.name isEqualToString:@"rightStickBackground"]) {
        sizeFactor = layer.bounds.size.width / standardStickBackgroundBounds.size.width;
    }

    if([layer.name isEqualToString:@"leftStickBackground"]){
        sizeFactor = layer.bounds.size.width / standardStickBackgroundBounds.size.width;
    }

    if([layer.name isEqualToString:@"dPad"]){
        for(CALayer* subLayer in layer.sublayers){
            if([subLayer.name isEqualToString:@"upButton"]){
                sizeFactor = subLayer.bounds.size.height / standardUpDownButtonBounds.size.height;
                break;
            }
        }
    }
    
    // sub controller layers embedded in super layers
    if([layer.name isEqualToString:@"upButton"] ||
       [layer.name isEqualToString:@"downButton"]){
        sizeFactor = layer.bounds.size.height / standardUpDownButtonBounds.size.height;
    }
    
    if([layer.name isEqualToString:@"leftButton"] ||
       [layer.name isEqualToString:@"rightButton"]){
        sizeFactor = layer.bounds.size.width / standardUpDownButtonBounds.size.height; // left & right buttons are just 90 rotations of up & down buttons
    }
    
    if([layer.name isEqualToString:@"leftStick"] ||
       [layer.name isEqualToString:@"rightStick"]){
        sizeFactor = layer.bounds.size.width / standardStickBounds.size.width;
    }


    return sizeFactor;
}

- (CGFloat) getControllerLayerOpacity:(CALayer*)layer{
    CGFloat opacity = 0.5;
    if([layer.name isEqualToString:@"aButton"]||
        [layer.name isEqualToString:@"bButton"] ||
        [layer.name isEqualToString:@"xButton"] ||
        [layer.name isEqualToString:@"yButton"] ||
        [layer.name isEqualToString:@"l1Button"] ||
        [layer.name isEqualToString:@"l2Button"] ||
        [layer.name isEqualToString:@"r1Button"] ||
        [layer.name isEqualToString:@"r2Button"] ||
        [layer.name isEqualToString:@"selectButton"] ||
        [layer.name isEqualToString:@"startButton"]){
        opacity = layer.opacity;
    }
        
    if([layer.name isEqualToString:@"rightStickBackground"]){
        opacity = self._rightStick.opacity;
    }

    if([layer.name isEqualToString:@"leftStickBackground"]){
        opacity = self._leftStick.opacity;
    }
    
    if([layer.name isEqualToString:@"dPad"]){
        opacity = self._leftButton.opacity;
    }

    return opacity;
}

/*
- (void) resizeControllerLayers{
    
}
*/

- (void) resizeControllerLayerWith:(CALayer*)layer and:(CGFloat)sizeFactor{
    // CALayer* superLayer = layer.superlayer;
    // if(layerBeingDragged.name == @"")
    if (layer == self._aButton ||
        layer == self._bButton ||
        layer == self._xButton ||
        layer == self._yButton ||
        layer == self._l1Button ||
        layer == self._l2Button ||
        layer == self._r1Button ||
        layer == self._r2Button){
        layer.bounds = CGRectMake(layer.bounds.origin.x, layer.bounds.origin.y, standardRoundButtonBounds.size.width * sizeFactor, standardRoundButtonBounds.size.height * sizeFactor);
    }
    
    if (layer == self._selectButton ||
        layer == self._startButton) {
        layer.bounds = CGRectMake(layer.bounds.origin.x, layer.bounds.origin.y, standardRectangleButtonBounds.size.width * sizeFactor, standardRectangleButtonBounds.size.height * sizeFactor);
    }
    
    if (layer == self._rightStickBackground) {
        // Resize the rightStick & Background bounds
        self._rightStickBackground.bounds = CGRectMake(layer.bounds.origin.x, layer.bounds.origin.y, standardStickBackgroundBounds.size.width * sizeFactor, standardStickBackgroundBounds.size.height * sizeFactor);
        self._rightStick.bounds = CGRectMake(layer.bounds.origin.x, layer.bounds.origin.y, standardStickBounds.size.width * sizeFactor, standardStickBounds.size.height * sizeFactor);

        // Retrieve the current frame to account for transformations, this will update the coords for new position CGPointMake
        CGRect transformedBackgroundFrame = self._rightStickBackground.frame;

        // Explicitly adjust the position of _rightStickBackground using the transformed frame
        self._rightStickBackground.position = CGPointMake(CGRectGetMidX(transformedBackgroundFrame), CGRectGetMidY(transformedBackgroundFrame));

        // Update the position of _rightStick to match the new center of the transformed _rightStickBackground
        self._rightStick.position = CGPointMake(CGRectGetMidX(self._rightStickBackground.bounds), CGRectGetMidY(self._rightStickBackground.bounds));
    }

    if (layer == self._leftStickBackground){
        // Resize the rightStick & Background bounds
        self._leftStickBackground.bounds = CGRectMake(layer.bounds.origin.x, layer.bounds.origin.y, standardStickBackgroundBounds.size.width * sizeFactor, standardStickBackgroundBounds.size.height * sizeFactor);
        self._leftStick.bounds = CGRectMake(layer.bounds.origin.x, layer.bounds.origin.y, standardStickBounds.size.width * sizeFactor, standardStickBounds.size.height * sizeFactor);

        // Retrieve the current frame to account for transformations, this will update the coords for new position CGPointMake
        CGRect transformedBackgroundFrame = self._leftStickBackground.frame;

        // Explicitly adjust the position of _rightStickBackground using the transformed frame
        self._leftStickBackground.position = CGPointMake(CGRectGetMidX(transformedBackgroundFrame), CGRectGetMidY(transformedBackgroundFrame));

        // Update the position of _leftStick to match the new center of the transformed _rightStickBackground
        self._leftStick.position = CGPointMake(CGRectGetMidX(self._leftStickBackground.bounds), CGRectGetMidY(self._leftStickBackground.bounds));
    }

    if (layer == self._dPadBackground){
        // Calculate the distances of each button from the shared center based on their transformed positions
        CGFloat newDPadDistFactor = 0.2/sizeFactor;

        // 1. Resize and reposition the Down button
        
        CGFloat newLongSideLength = standardLeftRightButtonBounds.size.width * sizeFactor;
        CGFloat newShortSideLength = standardLeftRightButtonBounds.size.height * sizeFactor;

        
        // this will anchor the center point of the dPad
        // must * _dPadSizeFactor (the current size factor retrieved from selected osc profile)
        CGPoint sharedCenter = CGPointMake(standardLeftRightButtonBounds.size.width * _dPadSizeFactor + 10, standardLeftRightButtonBounds.size.width * _dPadSizeFactor + 10); //this will anchor the center point of the dPad

        // Resize and reposition the Up button
        _upButton.anchorPoint = CGPointMake(0.5, 1 + newDPadDistFactor);
        _upButton.bounds = CGRectMake(0, 0, newShortSideLength, newLongSideLength);
        _upButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);

        // Resize and reposition the Down button
        _downButton.anchorPoint = CGPointMake(0.5, 0 - newDPadDistFactor);
        _downButton.bounds = CGRectMake(0, 0, newShortSideLength, newLongSideLength);
        _downButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);

        // Resize and reposition the Right button
        _rightButton.anchorPoint = CGPointMake(0 - newDPadDistFactor, 0.5);
        _rightButton.bounds = CGRectMake(0, 0, newLongSideLength, newShortSideLength);
        _rightButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);

        // Resize and reposition the Left button
        _leftButton.anchorPoint = CGPointMake(1 + newDPadDistFactor, 0.5);
        _leftButton.bounds = CGRectMake(0, 0, newLongSideLength, newShortSideLength);
        _leftButton.position = CGPointMake(sharedCenter.x, sharedCenter.y);
    }
}



- (void) adjustControllerLayerOpacityWith:(CALayer*)layer and:(CGFloat)alpha{
    // CALayer* superLayer = layer.superlayer;
    // if(layerBeingDragged.name == @"")
    CGFloat targetAlpha;
    targetAlpha = alpha;
    if(alpha < 0.23) targetAlpha = 0.23;
    if(alpha == 0.0 || alpha == 1.0) targetAlpha = 5.0f/6.0f; // invalid alpha value
    
    // NSLog(@"alphas: %f",targetAlpha);

    if (layer == self._aButton ||
        layer == self._bButton ||
        layer == self._xButton ||
        layer == self._yButton ||
        layer == self._l1Button ||
        layer == self._l2Button ||
        layer == self._r1Button ||
        layer == self._r2Button ||
        layer == self._selectButton ||
        layer == self._startButton ||
        layer == self._upButton ||
        layer == self._rightButton ||
        layer == self._downButton ||
        layer == self._leftButton){
            // layer.backgroundColor = [UIColor clearColor].CGColor;
            layer.opacity = targetAlpha;
    }
    
    
    if (layer == self._dPadBackground ){
        self._upButton.opacity = targetAlpha;
        self._rightButton.opacity = targetAlpha;
        self._downButton.opacity = targetAlpha;
        self._leftButton.opacity = targetAlpha;
    }

    
    if (layer == self._rightStickBackground) {
        self._rightStick.opacity = targetAlpha;
        self._rightStickBackground.opacity = targetAlpha + 1.0f/6.0f;
        NSLog(@"right stick init alpha: %f", targetAlpha);
    }

    if (layer == self._leftStickBackground){
        self._leftStick.opacity = targetAlpha;
        self._leftStickBackground.opacity = targetAlpha + 1.0f/6.0f;
    }
}

+ (NSMutableDictionary *)layerVibrationStyleDic{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [NSMutableDictionary dictionary];
    });
    return dict;
}


@end
