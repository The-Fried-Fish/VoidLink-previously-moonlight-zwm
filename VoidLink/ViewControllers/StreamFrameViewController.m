//
//  StreamFrameViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/18/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.1
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import <AVKit/AVKit.h>
#import "StreamFrameViewController.h"
#import "MainFrameViewController.h"
#import "VideoDecoderRenderer.h"
#import "StreamManager.h"
#import "SceneDelegate.h"
#import "ControllerSupport.h"
#import "DataManager.h"
#import "CustomEdgeSlideGestureRecognizer.h"
#import "CustomTapGestureRecognizer.h"
#import "LocalizationHelper.h"
#import "VoidLink-Swift.h"
#import "OSCProfilesManager.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <Limelight.h>

#if TARGET_OS_TV
#import <AVFoundation/AVDisplayCriteria.h>
#import <AVKit/AVDisplayManager.h>
#import <AVKit/UIWindow.h>
#endif

@interface AVDisplayCriteria()
@property(readonly) int videoDynamicRange;
@property(readonly, nonatomic) float refreshRate;
- (id)initWithRefreshRate:(float)arg1 videoDynamicRange:(int)arg2;
@end



@implementation StreamFrameViewController {
    ControllerSupport *_controllerSupport;
    StreamManager *_streamMan;
    TemporarySettings *_settings;
    NSTimer *_inactivityTimer;
    NSTimer *_statsUpdateTimer;
    UITapGestureRecognizer *_menuTapGestureRecognizer;
    UITapGestureRecognizer *_menuDoubleTapGestureRecognizer;
    UITapGestureRecognizer *_playPauseTapGestureRecognizer;
    UITextView *_overlayView;
    uint16_t overlayLevel;
    UILabel *_stageLabel;
    UILabel *_tipLabel;
    UIActivityIndicatorView *_spinner;
    StreamView *_streamView;
    UIScrollView *_scrollView;
    BOOL _userIsInteracting;
    bool viewJustLoaded;
    CGSize _keyboardSize;
    UIWindow *_extWindow;
    UIView *_streamVideoRenderView;
    /*
     * View architecture of this viewController:
     * self.view (named `streamFrameTopLayerView` in StreamView.m, where slide & tap gestures, and onScreenControls & OnScreenWidgetView buttons are registered)
     *   - streamView (where touchHandlers are registered)
     *     - streamVideoRenderView (where stream view is rendered)
     */
    UIWindow *_deviceWindow;
    dispatch_block_t _delayedRemoveExtScreen;
    VideoDecoderRenderer *_videoRenderer;
    BOOL _isRestoringFromPiP;
#if !TARGET_OS_TV
    CustomEdgeSlideGestureRecognizer *_slideToSettingsRecognizer;
    CustomEdgeSlideGestureRecognizer *_slideToCmdToolRecognizer;
    CustomTapGestureRecognizer *_oscLayoutTapRecoginizer;
    LayoutOnScreenControlsViewController *_layoutOnScreenControlsVC;
    ToolboxViewController* toolBoxViewController;
#endif

}

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    _streamView.hidden = YES;
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    Log(LOG_E, @"PiP Failed to Start: %@", error);
    _streamView.hidden = NO;
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    _streamView.hidden = NO;
    if (!_isRestoringFromPiP) {
        [self returnToMainFrame];
    }
    _isRestoringFromPiP = NO;
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    _isRestoringFromPiP = YES;
    _streamView.hidden = NO;
    completionHandler(YES);
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
           didTransitionToRenderSize:(CMVideoDimensions)newRenderSize API_AVAILABLE(ios(15.0)){
    Log(LOG_I, @"PiP transitioned to size: %d x %d", newRenderSize.width, newRenderSize.height);
 }

// Indicate that playback is never paused for a live stream
- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(14.0)) {
    return NO;
}

// Return an indefinite time range for a live stream
- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(14.0)) {
    return CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController setPlaying:(BOOL)playing API_AVAILABLE(ios(14.0)) {
}

// Live streams typically can't skip, so just call the completion handler.
- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController skipByInterval:(CMTime)skipInterval completionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(14.0)) {
    if (completionHandler) {
        completionHandler();
    }
}

- (BOOL)isFirstStreaming {
    NSString *key = @"hasStreamedBefore";
    BOOL streamedBefore = [[NSUserDefaults standardUserDefaults] boolForKey:key];

    if (!streamedBefore) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize]; // iOS 12+ 可省略
        return YES;
    }
    return NO;
}


- (bool)isOscLayoutToolEnabled{
    return (_settings.touchMode.intValue == RelativeTouch || _settings.touchMode.intValue == NativeTouch || _settings.touchMode.intValue == AbsoluteTouch) && _settings.onscreenControls.intValue == OnScreenControlsLevelCustom;
}

- (void)setupPiPControllerWithRenderer:(VideoDecoderRenderer *)videoRenderer {    // Ensure we have the renderer and its layer
    if (self.pipController) {
        return;
    }
    Log(LOG_I, @"Setting up PiP controller...");

    if (!videoRenderer || !videoRenderer.displayLayer) {
        Log(LOG_E, @"PiP setup failed: Video renderer or display layer not ready.");
        return;
    }

    AVSampleBufferDisplayLayer *streamLayer = videoRenderer.displayLayer;

    if ([AVPictureInPictureController isPictureInPictureSupported]) {
        if (@available(iOS 15.0, *)) {
            self.pipContentSource = [[AVPictureInPictureControllerContentSource alloc] initWithSampleBufferDisplayLayer:streamLayer playbackDelegate:(id<AVPictureInPictureSampleBufferPlaybackDelegate>)self];
            self.pipController = [[AVPictureInPictureController alloc] initWithContentSource:self.pipContentSource];
            self.pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
        } else {
            Log(LOG_E, @"PiP not fully supported on this device.");
            return;
        }

        if (self.pipController) {
            self.pipController.delegate = self;
            Log(LOG_I, @"PiP controller created successfully.");
        } else {
            Log(LOG_E, @"Failed to create PiP controller.");
        }
    } else {
        Log(LOG_E, @"PiP not supported on this device.");
    }
}

- (void)cleanupPiPController {
    if (self.pipController) {
        self.pipController.delegate = nil;
        self.pipController = nil;
        if (@available(iOS 15.0, *)) {
            self.pipContentSource = nil;
        }

        Log(LOG_I, @"PiP controller cleaned up.");
    }
}

- (void)updateToolboxSpecialEntries{
    if([self isOscLayoutToolEnabled]){
        if(![toolBoxViewController.specialEntries containsObject:@"widgetLayoutTool"]) [toolBoxViewController.specialEntries insertObject:@"widgetLayoutTool" atIndex:0];
        if(![toolBoxViewController.specialEntries containsObject:@"widgetSwitchTool"]) [toolBoxViewController.specialEntries insertObject:@"widgetSwitchTool" atIndex:1];
    }
    else{
        [toolBoxViewController.specialEntries removeObject:@"widgetLayoutTool"];
        [toolBoxViewController.specialEntries removeObject:@"widgetSwitchTool"];
    }
    if(_settings.enablePIP){
        if(![toolBoxViewController.specialEntries containsObject:@"enterPip"]) [toolBoxViewController.specialEntries addObject:@"enterPip"];
    }
    else [toolBoxViewController.specialEntries removeObject:@"enterPip"];
    
    NSLog(@"toolBoxViewController.specialEntries %@", toolBoxViewController.specialEntries);
}

- (void)configOscLayoutTool{
    if([self isOscLayoutToolEnabled]){
        _oscLayoutTapRecoginizer = [[CustomTapGestureRecognizer alloc] initWithTarget:self action:@selector(openWidgetLayoutTool)];
        _oscLayoutTapRecoginizer.numberOfTouchesRequired = _settings.oscLayoutToolFingers.intValue; //tap a predefined number of fingers to open osc layout tool
        _oscLayoutTapRecoginizer.tapDownTimeThreshold = 0.2;
        _oscLayoutTapRecoginizer.delaysTouchesBegan = NO;
        _oscLayoutTapRecoginizer.delaysTouchesEnded = NO;
        if(_settings.touchMode.intValue == AbsoluteTouch) _oscLayoutTapRecoginizer.immediateTriggering = true; // make immediate triggering on for absolute touch mode
        
        [self.view addGestureRecognizer:_oscLayoutTapRecoginizer]; //
        /* sets a reference to the correct 'LayoutOnScreenControlsViewController' depending on whether the user is on an iPhone or iPad */
        // _layoutOnScreenControlsVC = [[LayoutOnScreenControlsViewController alloc] init];
        BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
        if (isIPhone) {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
            _layoutOnScreenControlsVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
        }
        else {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
            _layoutOnScreenControlsVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
            _layoutOnScreenControlsVC.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        _layoutOnScreenControlsVC.view.backgroundColor = UIColor.clearColor;
        _layoutOnScreenControlsVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    }
}

- (void)presentToolboxViewController{
    ToolboxViewController* oldToolboxVC = toolBoxViewController;
    toolBoxViewController = [[ToolboxViewController alloc] init];
    toolBoxViewController.specialEntryDelegate = self;
    toolBoxViewController.specialEntries = oldToolboxVC.specialEntries;
    [self configOscLayoutTool];
    [self presentViewController:toolBoxViewController animated:YES completion:^{
        //[self->toolBoxViewController setupConstraints];
    }];
}

- (void)configSwipeGestures{
    _slideToSettingsRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(edgeSwiped)];
    _slideToSettingsRecognizer.edges = _settings.slideToSettingsScreenEdge.intValue;
    _slideToSettingsRecognizer.normalizedThresholdDistance = _settings.slideToSettingsDistance.floatValue;
    _slideToSettingsRecognizer.delaysTouchesBegan = NO;
    _slideToSettingsRecognizer.delaysTouchesEnded = NO;
    [self.view addGestureRecognizer:_slideToSettingsRecognizer];
    
    
    _slideToCmdToolRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(presentToolboxViewController)];
    if(_settings.slideToSettingsScreenEdge.intValue == UIRectEdgeLeft) _slideToCmdToolRecognizer.edges = UIRectEdgeRight;
    else _slideToCmdToolRecognizer.edges = UIRectEdgeLeft;  // _commandManager triggered by sliding from another side.
    _slideToCmdToolRecognizer.normalizedThresholdDistance = _settings.slideToSettingsDistance.floatValue;
    _slideToCmdToolRecognizer.delaysTouchesBegan = NO;
    _slideToCmdToolRecognizer.delaysTouchesEnded = NO;
    [self.view addGestureRecognizer:_slideToCmdToolRecognizer];
}

- (void)configZoomGestureAndAddStreamView{
    if (_settings.touchMode.intValue == AbsoluteTouch) {
        _scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
#if !TARGET_OS_TV
        [_scrollView.panGestureRecognizer setMinimumNumberOfTouches:2];
        [_scrollView.panGestureRecognizer setMaximumNumberOfTouches:2]; // reduce competing with keyboardToggleRecognizer in StreamView.
#endif
        [_scrollView setShowsHorizontalScrollIndicator:NO];
        [_scrollView setShowsVerticalScrollIndicator:NO];
        [_scrollView setDelegate:self];
        [_scrollView setMaximumZoomScale:10.0f];
        
        // Add StreamView inside a UIScrollView for absolute mode
        [_scrollView addSubview:_streamView];
        [self.view addSubview:_scrollView];
    }
    else{
        // Add streamView directly to self.view in other touch modes
        [self.view addSubview:_streamView];
    }
}

// key implementation of reconfiguring streamview after realtime setting menu is closed.
- (void)reConfigStreamViewRealtime{
    //[self.view removeGestureRecognizer:]
    //first, remove all gesture recognizers:
    for (UIGestureRecognizer *recognizer in _streamView.gestureRecognizers) {
        [_streamView removeGestureRecognizer:recognizer];
    }
    for (UIGestureRecognizer *recognizer in self.view.gestureRecognizers) {
        [self.view removeGestureRecognizer:recognizer];
    }
    
    _settings = [[[DataManager alloc] init] getSettings];  //StreamFrameViewController retrieve the settings here.
    overlayLevel = _settings.statsOverlayLevel.intValue;
    [self configOscLayoutTool];
    [self updateToolboxSpecialEntries];
    [self configSwipeGestures];
    [self configZoomGestureAndAddStreamView];
    [self->_streamView disableOnScreenControls]; //don't know why but this must be called outside the streamview class, just put it here. execute in streamview class cause hang
    [self.mainFrameViewcontroller reloadStreamConfig]; // reload streamconfig
    
    NSLog(@"viewJustloaded: %d", viewJustLoaded);
    if(!viewJustLoaded) [_controllerSupport updateControllerSupport:self.streamConfig delegate:self];
    else viewJustLoaded = false;
    // reload controllerSupport obj, this is mandatory for OSC reload,especially when the stream view is launched without OSC
    [_streamView setupStreamView:_controllerSupport interactionDelegate:self config:self.streamConfig streamFrameTopLayerView:self.view]; //reinitiate setupStreamView process.
        // we got self.view passed to streamView class as the topLayerView, will be useful in many cases
    [self->_streamView reloadOnScreenControlsRealtimeWith:(ControllerSupport*)_controllerSupport
                                        andConfig:(StreamConfiguration*)_streamConfig]; //reload OSC here.
    [self->_streamView reloadOnScreenWidgetViews]; //reload keyboard buttons here. the keyboard widget view will be added to the streamframe view instead streamview, the highest layer, which saves a lot of reengineering
    [self reloadAirPlayConfig];
    [self mousePresenceChanged];
    
    //reconfig statsOverlay
    self->_statsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                               target:self
                                                             selector:@selector(updateStatsOverlay)
                                                             userInfo:nil
                                                              repeats:_settings.statsOverlayEnabled];
    
    NSLog(@"frameview gestures: %d", (uint32_t)[self.view.gestureRecognizers count]);
    NSLog(@"streamview gestures: %d", (uint32_t)[_streamView.gestureRecognizers count]);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _deviceWindow = self.view.window;
    if (@available(iOS 13.0, *)) {
        UIScreen *currentScreen = self.view.window.windowScene.screen;
        if (UIScreen.screens.count > 1 && [self isAirPlayEnabled] && currentScreen == UIScreen.mainScreen) {
            [SceneDelegate setExternalDisplayRenderView:self->_streamVideoRenderView];
        }
        else {
            /*
             _settings.externalDisplayMode.intValue:
             0 - stage manager
             1 - airplay
             2 - disabled
             */
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_streamView insertSubview:self->_streamVideoRenderView atIndex:0];
            });
        }
    } else {
        // Fallback on earlier versions
    }

    self->_streamView.originalFrame = self->_streamView.frame;

    // check to see if external screen is connected/disconnected

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(extScreenDidConnect:)
                                                 name: UIScreenDidConnectNotification
                                               object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(extScreenDidDisconnect:)
                                                 name: UIScreenDidDisconnectNotification
                                               object: nil];
   
#if !TARGET_OS_TV
    [[self revealViewController] setPrimaryViewController:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reConfigStreamViewRealtime) // reconfig streamview when settings view is closed in stream view
                                                 name:@"SettingsViewClosedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(disconnectRemoteSession) //quit session when exit button is press in setting view during streaming
                                                 name:@"SessionDisconnectedBySettingsMenuNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(expandSettingsView) // //force expand settings view to update resolution table, and all setting includes current fullscreen resolution will be updated.
                                                 name:@"SettingsOverlayButtonPressedNotification"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    #endif
}

#if TARGET_OS_TV
- (void)controllerPauseButtonPressed:(id)sender { }
- (void)controllerPauseButtonDoublePressed:(id)sender {
    Log(LOG_I, @"Menu double-pressed -- backing out of stream");
    [self returnToMainFrame];
}
- (void)controllerPlayPauseButtonPressed:(id)sender {
    Log(LOG_I, @"Play/Pause button pressed -- backing out of stream");
    [self returnToMainFrame];
}
#endif

- (void)popFirstStreamingTip {
    // 初始化倒计时秒数
    __block NSInteger remainingSeconds = 16;

    NSString* settingsEdgeSide = _settings.slideToSettingsScreenEdge.intValue == UIRectEdgeLeft ? [LocalizationHelper localizedStringForKey:@"left"] : [LocalizationHelper localizedStringForKey:@"right"];
    NSString* cmdToolEdgeSide = _settings.slideToSettingsScreenEdge.intValue == UIRectEdgeLeft ? [LocalizationHelper localizedStringForKey:@"right"] : [LocalizationHelper localizedStringForKey:@"left"];
    uint8_t slideDist = (uint8_t)(_settings.slideToSettingsDistance.floatValue * 100);
    // 创建弹窗
    
    NSString* tipText = [LocalizationHelper localizedStringForKey:@"firstLaunchTip", settingsEdgeSide, slideDist, cmdToolEdgeSide, slideDist];
    
    UIAlertController *tipsAlertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@"First Launch Tips"] message: [LocalizationHelper localizedStringForKey:@"%@", tipText] preferredStyle:UIAlertControllerStyleAlert];

    
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

    // 添加确认按钮（初始禁用）
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Got it! (15)"]
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
    }];
    confirmAction.enabled = NO;
    [tipsAlertController addAction:confirmAction];

    // 显示弹窗
    [self presentViewController:tipsAlertController animated:YES completion:nil];

    // 使用dispatch_source_t实现精确倒计时
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);

    dispatch_source_set_event_handler(timer, ^{
        remainingSeconds--;

        if (remainingSeconds <= 0) {
            // 倒计时结束
            dispatch_source_cancel(timer);
            // 启用确认按钮
            confirmAction.enabled = YES;
            [confirmAction setValue:[LocalizationHelper localizedStringForKey:@"Got it!"] forKey:@"title"];
        } else {
            // 更新按钮标题和消息
            [confirmAction setValue:[NSString stringWithFormat:[LocalizationHelper localizedStringForKey:@"Got it! (%ld)", remainingSeconds], (long)remainingSeconds] forKey:@"title"];
        }
    });

    dispatch_resume(timer);

}


- (void)viewDidLoad
{
    viewJustLoaded = true;
    [super viewDidLoad];

    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    _settings = [[[DataManager alloc] init] getSettings];  //StreamFrameViewController retrieve the settings here.
    
    _stageLabel = [[UILabel alloc] init];
    [_stageLabel setUserInteractionEnabled:NO];
    [_stageLabel setText:[NSString stringWithFormat:@"Starting %@...", self.streamConfig.appName]];
    [_stageLabel sizeToFit];
    _stageLabel.textAlignment = NSTextAlignmentCenter;
    _stageLabel.textColor = [UIColor whiteColor];
    _stageLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    
    _spinner = [[UIActivityIndicatorView alloc] init];
    [_spinner setUserInteractionEnabled:NO];
#if TARGET_OS_TV
    [_spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
#else
    [_spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
#endif
    [_spinner sizeToFit];
    [_spinner startAnimating];
    _spinner.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2 - _stageLabel.frame.size.height - _spinner.frame.size.height);
    
    _controllerSupport = [[ControllerSupport alloc] initWithConfig:self.streamConfig delegate:self];
    _inactivityTimer = nil;
    
    _streamView = [[StreamView alloc] initWithFrame:self.view.frame];
    
    toolBoxViewController = [[ToolboxViewController alloc] init];
    toolBoxViewController.specialEntryDelegate = self;

    _isRestoringFromPiP = NO;

    /*
     _settings.externalDisplayMode.intValue:
     0 - stage manager
     1 - airplay
     */
    // A separate render view is always created to support external displays.
    _streamVideoRenderView = (StreamView*)[[UIView alloc] initWithFrame:self.view.frame];
    _streamVideoRenderView.bounds = _streamView.bounds;
    _streamVideoRenderView.userInteractionEnabled = false;
    
    //[_streamView setupStreamView:_controllerSupport interactionDelegate:self config:self.streamConfig];
    [self reConfigStreamViewRealtime]; // call this method again to make sure all gestures are configured & added to the superview(self.view), including the gestures added from inside the streamview.
    
    if([self isFirstStreaming]) [self popFirstStreamingTip];

#if TARGET_OS_TV
    if (!_menuTapGestureRecognizer || !_menuDoubleTapGestureRecognizer || !_playPauseTapGestureRecognizer) {
        _menuTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controllerPauseButtonPressed:)];
        _menuTapGestureRecognizer.allowedPressTypes = @[@(UIPressTypeMenu)];

        _playPauseTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controllerPlayPauseButtonPressed:)];
        _playPauseTapGestureRecognizer.allowedPressTypes = @[@(UIPressTypePlayPause)];
        
        _menuDoubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controllerPauseButtonDoublePressed:)];
        _menuDoubleTapGestureRecognizer.numberOfTapsRequired = 2;
        [_menuTapGestureRecognizer requireGestureRecognizerToFail:_menuDoubleTapGestureRecognizer];
        _menuDoubleTapGestureRecognizer.allowedPressTypes = @[@(UIPressTypeMenu)];
    }
    
    [self.view addGestureRecognizer:_menuTapGestureRecognizer];
    [self.view addGestureRecognizer:_menuDoubleTapGestureRecognizer];
    [self.view addGestureRecognizer:_playPauseTapGestureRecognizer];

#else
    //[self configSwipeGestures]; // swipe & exit gesture configured here
    //[self configOscLayoutTool]; //_oscLayoutTapRecoginizer will be added or removed to the view here
#endif
    
    _tipLabel = [[UILabel alloc] init];
    [_tipLabel setUserInteractionEnabled:NO];
    
#if TARGET_OS_TV
    [_tipLabel setText:@"Tip: Tap the Play/Pause button on the Apple TV Remote to disconnect from your PC"];
#else
    [_tipLabel setText:[LocalizationHelper localizedStringForKey:@"Tip: Swipe from screen edge to a certiain distance (configured by Swipe & Exit settings) to disconnect from your PC"]];
#endif
    
    [_tipLabel sizeToFit];
    _tipLabel.textColor = [UIColor whiteColor];
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height * 0.9);
    
    _streamMan = [[StreamManager alloc] initWithConfig:self.streamConfig
                                            renderView:_streamVideoRenderView
                                   connectionCallbacks:self];
    NSOperationQueue* opQueue = [[NSOperationQueue alloc] init];
    [opQueue addOperation:_streamMan];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector: @selector(applicationDidBecomeActive:)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector: @selector(applicationDidEnterBackground:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(oscLayoutClosed)
                                                 name:@"OscLayoutCloseNotification"
                                               object:nil];

#if 0
    // FIXME: This doesn't work reliably on iPad for some reason. Showing and hiding the keyboard
    // several times in a row will not correctly restore the state of the UIScrollView.
    // TrueZhuanJia: Already fixed by my refactored keyboard toggle gesture recognizer, and the keyboardWillShow/Hide method in StreamView.m
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillShow:)
                                                 name: UIKeyboardWillShowNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillHide:)
                                                 name: UIKeyboardWillHideNotification
                                               object: nil];
#endif
    
    [self.view addSubview:_stageLabel];
    [self.view addSubview:_spinner];
    [self.view addSubview:_tipLabel];
}

- (void)keyboardWillShow:(NSNotification *)notification{
    [_streamView keyboardWillShow:notification];
}

- (void)keyboardWillHide{
    [_streamView keyboardWillHide];
}


- (void)openWidgetLayoutTool{
    [self->_streamView disableOnScreenControls];
    [self->_streamView clearOnScreenKeyboardButtons]; // clear all onScreenKeyboardButtons before entering edit mode
    _layoutOnScreenControlsVC.quickSwitchEnabled = false;
    _layoutOnScreenControlsVC.toolbarStackView.hidden = false;
    _layoutOnScreenControlsVC.toolbarRootView.hidden = false;
    [self presentViewController:_layoutOnScreenControlsVC animated:YES completion:nil];
}

- (void)switchWidgetProfile{
    [self->_streamView disableOnScreenControls];
    [self->_streamView clearOnScreenKeyboardButtons]; // clear all onScreenKeyboardButtons before entering edit mode
    _layoutOnScreenControlsVC.quickSwitchEnabled = true;
    _layoutOnScreenControlsVC.toolbarStackView.hidden = true;
    _layoutOnScreenControlsVC.toolbarRootView.hidden = true;
    [self presentViewController:_layoutOnScreenControlsVC animated:NO completion:^{
        [self->_layoutOnScreenControlsVC presentProfilesTableView];
    }];
}

- (void)bringUpSoftKeyboard{
    [self->_streamView readyToBringUpSoftKeyboardByToolbox];
}

- (void)enterPip{
    [self.pipController startPictureInPicture];
}

- (void)oscLayoutClosed{
    // Handle the callback
    [self->_streamView disableOnScreenControls]; // add this to get realtime back menu working.
    [self->_streamView reloadOnScreenControlsWith:(ControllerSupport*)_controllerSupport
                                        andConfig:(StreamConfiguration*)_streamConfig];
    [self->_streamView showOnScreenControls];
    [self->_streamView reloadOnScreenWidgetViews]; //update keyboard buttons here
}

- (void)setUserInteractionEnabledForStreamView:(bool)enabled{
    _streamView.userInteractionEnabled = enabled;
    for(UIView* view in self.view.subviews){
        if([view isKindOfClass:[OnScreenWidgetView class]]) view.userInteractionEnabled = enabled;
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _streamView;
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    // Only cleanup when we're being destroyed
    if (parent == nil) {
        //NSLog(@"gyro cleanup, count: %ld", _controller.count);
        [_controllerSupport cleanup];

        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [_streamMan stopStream];
        if (_inactivityTimer != nil) {
            [_inactivityTimer invalidate];
            _inactivityTimer = nil;
        }
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

#if 0
- (void)keyboardWillShow:(NSNotification *)notification {
    _keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self->_scrollView.frame;
        frame.size.height -= self->_keyboardSize.height;
        self->_scrollView.frame = frame;
    }];
}

-(void)keyboardWillHide:(NSNotification *)notification {
    // NOTE: UIKeyboardFrameEndUserInfoKey returns a different keyboard size
    // than UIKeyboardFrameBeginUserInfoKey, so it's unsuitable for use here
    // to undo the changes made by keyboardWillShow.
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self->_scrollView.frame;
        frame.size.height += self->_keyboardSize.height;
        self->_scrollView.frame = frame;
    }];
}
#endif

- (void)updateStatsOverlay {
    if(!_settings.statsOverlayEnabled){
        [_overlayView removeFromSuperview];
        return; // add this for realtime streamview reconfig
    }
    else [self.view addSubview:_overlayView]; // don't know why but this is necessary for reactivating overlay.

    NSString* overlayText = [self->_streamMan getStatsOverlayText:overlayLevel];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateOverlayText:overlayText];
    });
}

- (void)updateOverlayText:(NSString*)text {
    if (_overlayView == nil) {
        _overlayView = [[UITextView alloc] init];
#if !TARGET_OS_TV
        [_overlayView setEditable:NO];
#endif
        [_overlayView setUserInteractionEnabled:NO];
        [_overlayView setSelectable:NO];
        [_overlayView setScrollEnabled:NO];
        
        // HACK: If not using stats overlay, center the text
        if (_statsUpdateTimer == nil) {
            [_overlayView setTextAlignment:NSTextAlignmentCenter];
        }
        
        [_overlayView setTextColor:[UIColor lightGrayColor]];
        [_overlayView setBackgroundColor:[UIColor blackColor]];
#if TARGET_OS_TV
        [_overlayView setFont:[UIFont systemFontOfSize:24]];
#else
        if (@available(iOS 13.0, *)) {
            [_overlayView setFont:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]];
        } else {
            [_overlayView setFont:[UIFont systemFontOfSize:12]];// Fallback on earlier versions
        }
        //[_overlayView setFont:[UIFont fontWithName:@"Menlo" size:12]];

#endif
        [_overlayView setAlpha:0.5];
        [self.view addSubview:_overlayView];
    }
    
    if (text != nil) {
        // We set our bounds to the maximum width in order to work around a bug where
        // sizeToFit interacts badly with the UITextView's line breaks, causing the
        // width to get smaller and smaller each time as more line breaks are inserted.
        [_overlayView setBounds:CGRectMake(self.view.frame.origin.x,
                                           _overlayView.frame.origin.y,
                                           self.view.frame.size.width,
                                           _overlayView.frame.size.height)];
        [_overlayView setText:text];
        [_overlayView sizeToFit];
        [_overlayView setCenter:CGPointMake(self.view.frame.size.width / 2, _overlayView.frame.size.height / 2)];
        [_overlayView setHidden:NO];
    }
    else {
        [_overlayView setHidden:YES];
    }
}

- (void) returnToMainFrame {
    // Reset display mode back to default
    [self updatePreferredDisplayMode:NO];
    [SceneDelegate clearExternalDisplayRenderView];

    if (_settings.enablePIP) {
        [self cleanupPiPController];
    }

    [_statsUpdateTimer invalidate];
    _statsUpdateTimer = nil;
    
    [self.navigationController popToRootViewControllerAnimated:NO];
    
    _extWindow = nil;
}

// External Screen connected
- (void)extScreenDidConnect:(NSNotification *)notification {
    Log(LOG_I, @"External Screen Connected");
    if ([self isAirPlayEnabled] && [notification.object isKindOfClass:[UIScreen class]]) {
        UIScreen *extScreen = (UIScreen *)notification.object;
        if (_streamVideoRenderView) {
             // Remove from current superview before passing it
             [_streamVideoRenderView removeFromSuperview];
             [SceneDelegate setExternalDisplayRenderView:_streamVideoRenderView];
             NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
             [nc postNotificationName:@"ScreenChanged" object:self];
        } else {
             Log(LOG_W, @"_streamVideoRenderView is nil when external screen connected.");
        }
    }
}

// External Screen disconnected
- (void)extScreenDidDisconnect:(NSNotification *)notification {
    Log(LOG_I, @"External Screen Disconnected");
    if(UIScreen.screens.count < 2) {
        [SceneDelegate clearExternalDisplayRenderView];
        // Add the render view back to the local StreamView if AirPlay was active
        if ([self isAirPlayEnabled]) {
            if (_streamVideoRenderView && _streamView) {
                [_streamView insertSubview:_streamVideoRenderView atIndex:0];
                [self handleViewResize]; // Adjust frames as needed
            }
        }
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:@"ScreenChanged" object:self]; // Your existing notification
    }
}

- (bool)shallDisableGyroHotSwitch{
    return _controllerSupport.shallDisableGyroHotSwitch;
}

- (BOOL) isAirPlaying{
    if (_settings.externalDisplayMode.intValue == 1 && _streamVideoRenderView) {
        return _streamVideoRenderView.hidden;
    }
    return NO;
}

- (BOOL) isAirPlayEnabled{
    return _settings.externalDisplayMode.intValue == 1;
}

- (void) reloadAirPlayConfig{
    if (UIScreen.screens.count == 1){return;}
    if (![self isAirPlaying] && [self isAirPlayEnabled]){
        [SceneDelegate setExternalDisplayRenderView:_streamVideoRenderView];
    }else if ([self isAirPlaying] && ![self isAirPlayEnabled]){
        [SceneDelegate clearExternalDisplayRenderView];
    }
}

- (void) handleViewResize{
    _streamView.bounds = _deviceWindow.bounds;
    _streamView.frame = _deviceWindow.frame;
    if(![self isAirPlaying]){
        _streamVideoRenderView.bounds = _deviceWindow.bounds;
        _streamVideoRenderView.frame = _deviceWindow.frame;
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:@"ScreenChanged" object:self];
    }
    [self reConfigStreamViewRealtime];
}


// This will fire if the user opens control center or gets a low battery message
- (void)applicationWillResignActive:(NSNotification *)notification {
    
    //[self.pipController startPictureInPicture];
    //sleep(1);
    
#if !TARGET_OS_TV
#endif
}

- (void)inactiveTimerExpired:(NSTimer*)timer {
    Log(LOG_I, @"Terminating stream after inactivity");
    
    [self returnToMainFrame];
    
    _inactivityTimer = nil;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    // Stop the background timer, since we're foregrounded again
    if (_inactivityTimer != nil) {
        Log(LOG_I, @"Stopping inactivity timer after becoming active again");
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }
    if (self.pipController && self.pipController.isPictureInPictureActive) {
        [self.pipController stopPictureInPicture];
    }
}

// This fires when the home button is pressed
- (void)applicationDidEnterBackground:(UIApplication *)application {

    NSLog(@"did enter background, %d, %@, %d", _settings.enablePIP, self.pipController, self.pipController.isPictureInPictureActive);
    if (_settings.enablePIP && self.pipController && self.pipController.isPictureInPictureActive) {
        //Log(LOG_I, @"PIP is active, not terminating stream");
    }
    
    if (_inactivityTimer != nil) {
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }
    
    // Terminate the stream if the app is inactive for ...
    Log(LOG_I, @"Starting inactivity termination timer with %d min", _settings.backgroundSessionTimer.intValue);
    _inactivityTimer = [NSTimer scheduledTimerWithTimeInterval:60*(double)_settings.backgroundSessionTimer.intValue
                                  target:self
                                selector:@selector(inactiveTimerExpired:)
                                userInfo:nil
                                 repeats:NO];

#if !TARGET_OS_TV

#endif
}

- (void)expandSettingsView{
    self.mainFrameViewcontroller.settingsExpandedInStreamView = true; //notify mainFrameViewContorller that this is a setting expansion in stream view, some settings shall be disabled.
    [self.mainFrameViewcontroller expandSettingsView];
}

- (void)edgeSwiped{
    /*
    if([self->_mainFrameViewcontroller isIPhonePortrait]){ // disable backmenu for iphone portrait mode;
        [self returnToMainFrame]; //directly quit the session
        return;
    } */
    [self expandSettingsView];  // expand settings view in other cases;
}

- (void)disconnectRemoteSession {
    Log(LOG_I, @"Settings view disconnect the session in stream view");
    self.mainFrameViewcontroller.settingsExpandedInStreamView = false; // reset this flag to false
    [self returnToMainFrame];
}

- (void) connectionStarted {
    Log(LOG_I, @"Connection started");
    dispatch_async(dispatch_get_main_queue(), ^{
        // Leave the spinner spinning until it's obscured by
        // the first frame of video.
        self->_stageLabel.hidden = YES;
        self->_tipLabel.hidden = YES;
        self->_spinner.hidden = YES;
        
        [self->_streamView showOnScreenControls];
        
        [self->_controllerSupport connectionEstablished];
        
        if (self->_settings.statsOverlayEnabled) {
            self->_statsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                                       target:self
                                                                     selector:@selector(updateStatsOverlay)
                                                                     userInfo:nil
                                                                      repeats:YES];
        }
    });
}

- (void)connectionTerminated:(int)errorCode {
    Log(LOG_I, @"Connection terminated: %d", errorCode);
    
    unsigned int portFlags = LiGetPortFlagsFromTerminationErrorCode(errorCode);
    unsigned int portTestResults = LiTestClientConnectivity(CONN_TEST_SERVER, 443, portFlags);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        NSString* title;
        NSString* message;
        
        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
            title = [LocalizationHelper localizedStringForKey:@"Connection Error"];
            message = @"Your device's session connection is being blocked. Streaming may not work while connected to this network.";
        }
        else {
            switch (errorCode) {
                case ML_ERROR_GRACEFUL_TERMINATION:
                    [self returnToMainFrame];
                    return;
                    
                case ML_ERROR_NO_VIDEO_TRAFFIC:
                    title = [LocalizationHelper localizedStringForKey:@"Connection Error"];
                    message = [LocalizationHelper localizedStringForKey:@"No video received from host."];
                    if (portFlags != 0) {
                        char failingPorts[256];
                        LiStringifyPortFlags(portFlags, "\n", failingPorts, sizeof(failingPorts));
                        message = [message stringByAppendingString:[LocalizationHelper localizedStringForKey:@"ConnectionFailedFirewall", failingPorts]];
                    }
                    break;
                    
                case ML_ERROR_NO_VIDEO_FRAME:
                    title = [LocalizationHelper localizedStringForKey:@"Connection Error"];
                    message = [LocalizationHelper localizedStringForKey: @"Your network connection isn't performing well. Reduce your video bitrate setting or try a faster connection."];
                    break;
                    
                case ML_ERROR_UNEXPECTED_EARLY_TERMINATION:
                case ML_ERROR_PROTECTED_CONTENT:
                    title = [LocalizationHelper localizedStringForKey:@"Connection Error"];
                    message = @"Something went wrong on your host PC when starting the stream.\n\nMake sure you don't have any DRM-protected content open on your host PC. You can also try restarting your host PC.\n\nIf the issue persists, try reinstalling your GPU drivers and GeForce Experience.";
                    break;
                    
                case ML_ERROR_FRAME_CONVERSION:
                    title = [LocalizationHelper localizedStringForKey:@"Connection Error"];
                    message = @"The host PC reported a fatal video encoding error.\n\nTry disabling HDR mode, changing the streaming resolution, or changing your host PC's display resolution.";
                    break;
                    
                default:
                {
                    NSString* errorString;
                    if (abs(errorCode) > 1000) {
                        // We'll assume large errors are hex values
                        errorString = [NSString stringWithFormat:@"%08X", (uint32_t)errorCode];
                    }
                    else {
                        // Smaller values will just be printed as decimal (probably errno.h values)
                        errorString = [NSString stringWithFormat:@"%d", errorCode];
                    }
                    
                    title = [LocalizationHelper localizedStringForKey: @"Connection Terminated"];
                    message = [LocalizationHelper localizedStringForKey: @"The connection was terminated, Error code: %@", errorString];
                    break;
                }
            }
        }
        
        UIAlertController* conTermAlert = [UIAlertController alertControllerWithTitle:title
                                                                              message:message
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        [Utils addHelpOptionToDialog:conTermAlert];
        [conTermAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [self returnToMainFrame];
        }]];
        [self presentViewController:conTermAlert animated:YES completion:nil];
    });

    [_streamMan stopStream];
}

- (void) stageStarting:(const char*)stageName {
    Log(LOG_I, @"Starting %s", stageName);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* lowerCase = [NSString stringWithFormat:@"%s ...", stageName];
        NSString* titleCase = [[[lowerCase substringToIndex:1] uppercaseString] stringByAppendingString:[lowerCase substringFromIndex:1]];
        [self->_stageLabel setText:titleCase];
        [self->_stageLabel sizeToFit];
        self->_stageLabel.center = CGPointMake(self.view.frame.size.width / 2, self->_stageLabel.center.y);
    });
}

- (void) stageComplete:(const char*)stageName {
}

- (void) stageFailed:(const char*)stageName withError:(int)errorCode portTestFlags:(int)portTestFlags {
    Log(LOG_I, @"Stage %s failed: %d", stageName, errorCode);
    
    unsigned int portTestResults = LiTestClientConnectivity(CONN_TEST_SERVER, 443, portTestFlags);

    dispatch_async(dispatch_get_main_queue(), ^{
        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        NSString* message = [NSString stringWithFormat:@"%s failed with error %d", stageName, errorCode];
        if (portTestFlags != 0) {
            char failingPorts[256];
            LiStringifyPortFlags(portTestFlags, "\n", failingPorts, sizeof(failingPorts));
            message = [message stringByAppendingString:[LocalizationHelper localizedStringForKey:@"ConnectionFailedFirewall", failingPorts]];
        }
        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
            message = [message stringByAppendingString:[LocalizationHelper localizedStringForKey:@"!ML_TEST_RESULT_INCONCLUSIVE"]];
        }
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Connection Failed"]
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [Utils addHelpOptionToDialog:alert];
        [alert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [self returnToMainFrame];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
    
    [_streamMan stopStream];
}

- (void) launchFailed:(NSString*)message {
    Log(LOG_I, @"Launch failed: %@", message);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Allow the display to go to sleep now
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Connection Error"]
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [Utils addHelpOptionToDialog:alert];
        [alert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [self returnToMainFrame];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor {
    Log(LOG_I, @"Rumble on gamepad %d: %04x %04x", controllerNumber, lowFreqMotor, highFreqMotor);
    
    [_controllerSupport rumble:controllerNumber lowFreqMotor:lowFreqMotor highFreqMotor:highFreqMotor];
}

- (void) rumbleTriggers:(uint16_t)controllerNumber leftTrigger:(uint16_t)leftTrigger rightTrigger:(uint16_t)rightTrigger {
    Log(LOG_I, @"Trigger rumble on gamepad %d: %04x %04x", controllerNumber, leftTrigger, rightTrigger);
    
    [_controllerSupport rumbleTriggers:controllerNumber leftTrigger:leftTrigger rightTrigger:rightTrigger];
}

- (void) setMotionEventState:(uint16_t)controllerNumber motionType:(uint8_t)motionType reportRateHz:(uint16_t)reportRateHz {
    Log(LOG_I, @"Set motion state on gamepad %d: %02x %u Hz", controllerNumber, motionType, reportRateHz);
    
    [_controllerSupport setMotionEventState:controllerNumber motionType:motionType reportRateHz:reportRateHz];
}

- (void) setControllerLed:(uint16_t)controllerNumber r:(uint8_t)r g:(uint8_t)g b:(uint8_t)b {
    Log(LOG_I, @"Set controller LED on gamepad %d: l%02x%02x%02x", controllerNumber, r, g, b);
    
    [_controllerSupport setControllerLed:controllerNumber r:r g:g b:b];
}

- (void)connectionStatusUpdate:(int)status {
    Log(LOG_W, @"Connection status update: %d", status);

    // The stats overlay takes precedence over these warnings
    if (_statsUpdateTimer != nil) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (status) {
            case CONN_STATUS_OKAY:
                [self updateOverlayText:nil];
                break;
                
            case CONN_STATUS_POOR:
                if (self->_streamConfig.bitRate > 5000) {
                    [self updateOverlayText:[LocalizationHelper localizedStringForKey:@"Slow connection to PC, Reduce your bitrate"]];
                }
                else {
                    [self updateOverlayText:[LocalizationHelper localizedStringForKey:@"Poor connection to PC"]];
                }
                break;
        }
    });
}

- (void) updatePreferredDisplayMode:(BOOL)streamActive {
#if TARGET_OS_TV
    if (@available(tvOS 11.2, *)) {
        UIWindow* window = [[[UIApplication sharedApplication] delegate] window];
        AVDisplayManager* displayManager = [window avDisplayManager];
        
        // This logic comes from Kodi and MrMC
        if (streamActive) {
            int dynamicRange;
            
            if (LiGetCurrentHostDisplayHdrMode()) {
                dynamicRange = 2; // HDR10
            }
            else {
                dynamicRange = 0; // SDR
            }
            
            AVDisplayCriteria* displayCriteria = [[AVDisplayCriteria alloc] initWithRefreshRate:[_settings.framerate floatValue]
                                                                              videoDynamicRange:dynamicRange];
            displayManager.preferredDisplayCriteria = displayCriteria;
        }
        else {
            // Switch back to the default display mode
            displayManager.preferredDisplayCriteria = nil;
        }
    }
#endif
}

- (void) setHdrMode:(bool)enabled {
    Log(LOG_I, @"HDR is now: %s", enabled ? "active" : "inactive");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePreferredDisplayMode:YES];
    });
}

- (void) videoContentShown {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_spinner stopAnimating];
        [self.view setBackgroundColor:[UIColor blackColor]];

        if (@available(iOS 15.0, *)) {
            if (self->_settings.enablePIP) {
                if (self->_streamMan && self->_streamMan.videoRenderer) {
                    Log(LOG_I, @"Setting up PiP with renderer: %p", self->_streamMan.videoRenderer);
                    [self setupPiPControllerWithRenderer:self->_streamMan.videoRenderer];
                } else {
                    Log(LOG_I, @"No renderer available for PiP setup");
                }
            }
        }
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)gamepadPresenceChanged {
#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
#endif
}

- (void)mousePresenceChanged {
#if !TARGET_OS_TV
    if (@available(iOS 14.0, *)) {
        [self setNeedsUpdateOfPrefersPointerLocked];
    }
#endif
}

- (void) streamExitRequested {
    Log(LOG_I, @"Gamepad combo requested stream exit");
    
    [self returnToMainFrame];
}

- (void)userInteractionBegan {
    // Disable hiding home bar when user is interacting.
    // iOS will force it to be shown anyway, but it will
    // also discard our edges deferring system gestures unless
    // we willingly give up home bar hiding preference.
    _userIsInteracting = YES;
#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
#endif
}

- (void)userInteractionEnded {
    // Enable home bar hiding again if conditions allow
    _userIsInteracting = NO;
#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
#endif
}

- (void)toggleStatsOverlay{
    DataManager* dataMan = [[DataManager alloc] init];
    Settings *currentSettings = [dataMan retrieveSettings];
    
    currentSettings.statsOverlayEnabled = !currentSettings.statsOverlayEnabled;
    
    [dataMan saveData];
    [self reConfigStreamViewRealtime];
}

- (void)toggleMouseCapture{
    DataManager* dataMan = [[DataManager alloc] init];
    Settings *currentSettings = [dataMan retrieveSettings];
    
    if(currentSettings.localMousePointerMode.intValue == 0){
        currentSettings.localMousePointerMode = @1;
    }else{
        currentSettings.localMousePointerMode = @0;
    }
    
    
    [dataMan saveData];
    [self reConfigStreamViewRealtime];
}

- (void)toggleMouseVisible{
    DataManager* dataMan = [[DataManager alloc] init];
    Settings *currentSettings = [dataMan retrieveSettings];
    
    if(currentSettings.localMousePointerMode.intValue == 2){
        currentSettings.localMousePointerMode = @1;
    }else{
        currentSettings.localMousePointerMode = @2;
    }
    
    [dataMan saveData];
    [self reConfigStreamViewRealtime];
}

#if !TARGET_OS_TV
// Require a confirmation when streaming to activate a system gesture
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    return UIRectEdgeAll;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    if ( [_streamView getCurrentOscState] == OnScreenControlsLevelOff &&
        _userIsInteracting == NO) {
        // Autohide the home bar when a gamepad is connected
        // and the on-screen controls are disabled. We can't
        // do this all the time because any touch on the display
        // will cause the home indicator to reappear, and our
        // preferredScreenEdgesDeferringSystemGestures will also
        // be suppressed (leading to possible errant exits of the
        // stream).
        return YES;
    }
    
    return NO;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (BOOL)prefersPointerLocked {
    // Pointer lock breaks the UIKit mouse APIs, which is a problem because
    // GCMouse is horribly broken on iOS 14.0 for certain mice. Only lock
    // the cursor if there is a GCMouse present.
    return ([GCMouse mice].count > 0) && [_settings localMousePointerMode].intValue == 0;
}
#endif

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    Log(LOG_I, @"View size changed, terminating stream");
    
    double delayInSeconds = 0.2;
    if (_delayedRemoveExtScreen) {
        dispatch_block_cancel(_delayedRemoveExtScreen);
    }
    dispatch_block_t block = dispatch_block_create(0, ^{
        [self handleViewResize];
    });
    _delayedRemoveExtScreen = block;
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(delayTime, dispatch_get_main_queue(), block);
}

@end
