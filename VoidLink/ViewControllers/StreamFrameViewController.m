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
#import "PaddedLabel.h"
#import "ImGuiRenderer.h"
#import "MetalVideoRenderer.h"
#import "CustomEdgeSlideGestureRecognizer.h"
#import "CustomTapGestureRecognizer.h"
#import "LocalizationHelper.h"
#import "VoidLink-Swift.h"
#import "OSCProfilesManager.h"
#import "ThemeManager.h"
#import "NativeTouchPointer.h"

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
    OSCProfile* _oscProfile;
    NSTimer *_inactivityTimer;
    NSTimer *_statsUpdateTimer;
    PaddedLabel *_overlayView;
    UITapGestureRecognizer *_menuTapGestureRecognizer;
    UITapGestureRecognizer *_menuDoubleTapGestureRecognizer;
    UITapGestureRecognizer *_playPauseTapGestureRecognizer;
    uint16_t overlayLevel;
    UILabel *_stageLabel;
    UILabel *_tipLabel;
    UIActivityIndicatorView *_spinner;
    StreamView *_streamView;
    UIScrollView *_scrollView;
    BOOL _userIsInteracting;
    bool viewIsBeingResized;
    bool previousOnScreenWidgetEnabled;
    CGSize _keyboardSize;
    PlotMetrics _decodeMetrics;
    PlotMetrics _frameDropMetrics;
    PlotMetrics _frameQueueMetrics;
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
    SafeTimer* safeTimer;

#if !TARGET_OS_TV
    CustomEdgeSlideGestureRecognizer *_slideToSettingsRecognizer;
    CustomEdgeSlideGestureRecognizer *_slideToToolboxRecognizer;
    CustomTapGestureRecognizer *_oscLayoutTapRecoginizer;
    LayoutOnScreenControlsViewController *_layoutOnScreenControlsVC;
    ToolboxViewController* toolBoxViewController;
    MicHandler* micHandler;
    MotionHandler *_motionHandler;

#else
    UITapGestureRecognizer *_menuTapGestureRecognizer;
    UITapGestureRecognizer *_menuDoubleTapGestureRecognizer;
    UITapGestureRecognizer *_playPauseTapGestureRecognizer;
#endif

}

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    _streamView.hidden = YES;
    if (self.imguiView) {
        self.imguiView.mtkView.hidden = YES;
        Log(LOG_I, @"Hiding ImGui view for PiP start.");
    }
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
    if (self.imguiView) {
        self.imguiView.mtkView.hidden = NO;
        Log(LOG_I, @"Showing ImGui view after PiP stop.");
    }

    if (!_isRestoringFromPiP) {
        [self returnToMainFrame];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    _isRestoringFromPiP = YES;
    _streamView.hidden = NO;
    if (self.imguiView) {
        self.imguiView.mtkView.hidden = NO;
        Log(LOG_I, @"Showing ImGui view for PiP restore.");
    }
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
    return (_settings.touchMode.intValue == RelativeTouch || _settings.touchMode.intValue == NativeTouch || _settings.touchMode.intValue == AbsoluteTouch || _settings.touchMode.intValue == TouchDisabled) && _settings.onscreenControls.intValue == OnScreenControlsLevelCustom;
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
    //NSLog(@"in osc frameview gestures: %d", (uint32_t)[self.view.gestureRecognizers count]);
    //NSLog(@"in osc streamview gestures: %d", (uint32_t)[_streamView.gestureRecognizers count]);
}

- (void)bringUpToolboxMenu{
    [self configOscLayoutTool];
    ToolboxViewController* oldToolboxVC = toolBoxViewController;
    toolBoxViewController = [[ToolboxViewController alloc] init];
    toolBoxViewController.specialEntryDelegate = self;
    toolBoxViewController.specialEntries = oldToolboxVC.specialEntries;
    toolBoxViewController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    [self presentViewController:toolBoxViewController animated:YES completion:^{
        //[self->toolBoxViewController setupConstraints];
    }];
}

- (void)configGestures{
    _slideToSettingsRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(edgeSwiped)];
    _slideToSettingsRecognizer.excludePencilEvent = _oscProfile.disablePencilSlideGestures;
    _slideToSettingsRecognizer.edgeTolerance = _settings.edgeSlidingSensitivity.floatValue;
    _slideToSettingsRecognizer.edges = _settings.slideToSettingsScreenEdge.intValue;
    _slideToSettingsRecognizer.normalizedThresholdDistance = _settings.slideToSettingsDistance.floatValue;
    _slideToSettingsRecognizer.delaysTouchesBegan = NO;
    _slideToSettingsRecognizer.delaysTouchesEnded = NO;
    [self.view addGestureRecognizer:_slideToSettingsRecognizer];
    
    
    _slideToToolboxRecognizer = [[CustomEdgeSlideGestureRecognizer alloc] initWithTarget:self action:@selector(bringUpToolboxMenu)];
    _slideToToolboxRecognizer.excludePencilEvent = _oscProfile.disablePencilSlideGestures;
    _slideToToolboxRecognizer.edgeTolerance = _settings.edgeSlidingSensitivity.floatValue;
    if(_settings.slideToSettingsScreenEdge.intValue == UIRectEdgeLeft) _slideToToolboxRecognizer.edges = UIRectEdgeRight;
    else _slideToToolboxRecognizer.edges = UIRectEdgeLeft;  // _commandManager triggered by sliding from another side.
    _slideToToolboxRecognizer.normalizedThresholdDistance = _settings.slideToSettingsDistance.floatValue;
    _slideToToolboxRecognizer.delaysTouchesBegan = NO;
    _slideToToolboxRecognizer.delaysTouchesEnded = NO;
    [self.view addGestureRecognizer:_slideToToolboxRecognizer];
    
    if([self isOscLayoutToolEnabled]){
        _oscLayoutTapRecoginizer = [[CustomTapGestureRecognizer alloc] initWithTarget:self action:@selector(handleWidgetLayoutGesture)];
        _oscLayoutTapRecoginizer.numberOfTouchesRequired = _settings.oscLayoutToolFingers.intValue; //tap a predefined number of fingers to open osc layout tool
        _oscLayoutTapRecoginizer.tapDownTimeThreshold = 0.2;
        _oscLayoutTapRecoginizer.delaysTouchesBegan = NO;
        _oscLayoutTapRecoginizer.delaysTouchesEnded = NO;
        if(_settings.touchMode.intValue == AbsoluteTouch) _oscLayoutTapRecoginizer.immediateTriggering = true; // make immediate triggering on for absolute touch mode
        [self.view addGestureRecognizer:_oscLayoutTapRecoginizer];
        _oscLayoutTapRecoginizer.touchCapturingView = _streamView;
    }
    
}

- (void)configZoomGestureAndAddStreamView{
    if (_settings.touchMode.intValue == AbsoluteTouch && !_settings.passthroughGestures) {
        if(!_scrollView) _scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
#if !TARGET_OS_TV
        [_scrollView.panGestureRecognizer setMinimumNumberOfTouches:2];
        [_scrollView.panGestureRecognizer setMaximumNumberOfTouches:2]; // reduce competing with keyboardToggleRecognizer in StreamView.
#endif
        [_scrollView setShowsHorizontalScrollIndicator:NO];
        [_scrollView setShowsVerticalScrollIndicator:NO];
        [_scrollView setDelegate:self];
        [_scrollView setMaximumZoomScale:_settings.passthroughGestures ? 1.0 : 10.0f];
        if(!_mainFrameViewcontroller.settingsExpandedInStreamView){
            // Add StreamView inside a UIScrollView for absolute mode
            [_scrollView addSubview:_streamView];
            // Insert at index 0 to ensure it doesn't cover OSC controls (CALayers)
            [self.view insertSubview:_scrollView atIndex:0];
        }
        _scrollView.panGestureRecognizer.enabled = !_settings.passthroughGestures;
    }
    else{
        // Add streamView directly to self.view in other touch modes
        // Insert at index 0 to ensure it doesn't cover OSC controls (CALayers)
        if([_streamView.superview isKindOfClass:[UIScrollView class]]){
            [_streamView removeFromSuperview];
        }
        
        [self.view insertSubview:_streamView atIndex:0];
    }
}

- (void)reConfigStreamViewRealtime {
    //if(!viewJustLoaded) [self handleViewResize];
    [self reConfigStreamViewRealtimeAndReloadSettings:YES reloadOnscreenWidgets:NO];
}

// key implementation of reconfiguring streamview after realtime setting menu is closed.
- (void)reConfigStreamViewRealtimeAndReloadSettings:(BOOL)reloadSettings reloadOnscreenWidgets:(BOOL)reloadOnscreenWidgets{
    //[self.view removeGestureRecognizer:]
    //first, remove all gesture recognizers:
    for (UIGestureRecognizer *recognizer in _streamView.gestureRecognizers) {
        [_streamView removeGestureRecognizer:recognizer];
    }
    for (UIGestureRecognizer *recognizer in self.view.gestureRecognizers) {
        [self.view removeGestureRecognizer:recognizer];
    }
    
    if (reloadSettings) {
        _settings = [[[DataManager alloc] init] getSettings];  //StreamFrameViewController retrieve the settings here.
    }
    _oscProfile = [[OSCProfilesManager sharedManager:CGRectZero] getSelectedProfile];
    
    overlayLevel = _settings.statsOverlayLevel.intValue;
    [self setupOverlayView];
    
    if(viewIsBeingResized) viewIsBeingResized = false;
    else [self configOscLayoutTool];
    [self updateToolboxSpecialEntries];
    [self configGestures];
    [self configZoomGestureAndAddStreamView];
    [self->_streamView disableOnScreenControls]; //don't know why but this must be called outside the streamview class, just put it here. execute in streamview class cause hang
    [self.mainFrameViewcontroller reloadStreamConfig]; // reload streamconfig
    
    if([MicHandler permissionGranted] && _settings.redirectMic){
        [micHandler startTapping];
    }
    else [micHandler stopTappingWithStopEngine:false];
    
    Connection.muteInBackground = _settings.muteInBackground;
    
    if(!_viewJustLoaded) [_controllerSupport updateControllerSupport:self.streamConfig delegate:self];
    // reload controllerSupport obj, this is mandatory for OSC reload,especially when the stream view is launched without OSC
    [_streamView setupStreamView:_controllerSupport interactionDelegate:self config:self.streamConfig streamFrameTopLayerView:self.view]; //reinitiate setupStreamView process.
        // we got self.view passed to streamView class as the topLayerView, will be useful in many cases
    [self->_streamView reloadOnScreenControlsRealtimeWith:(ControllerSupport*)_controllerSupport
                                        andConfig:(StreamConfiguration*)_streamConfig]; //reload OSC here.
    
    bool onScreenWidgetSwitched = previousOnScreenWidgetEnabled != [_streamView isOnScreenWidgetEnabled];
    bool needReload = onScreenWidgetSwitched && !previousOnScreenWidgetEnabled;
    OnScreenWidgetView.trackPointEnabled = _settings.touchPointTracking;
    [_streamView reloadOnScreenWidgetViews:_viewJustLoaded||reloadOnscreenWidgets||needReload]; //reload keyboard buttons here. the keyboard widget view will be added to the streamframe view instead streamview, the highest layer, which saves a lot of reengineering
    
    if(onScreenWidgetSwitched && previousOnScreenWidgetEnabled) [_streamView clearOnScreenWidgets];
    previousOnScreenWidgetEnabled = [_streamView isOnScreenWidgetEnabled];
    
    [self reloadAirPlayConfig];
    [self mousePresenceChanged];
    
    // Invalidate the old timer to prevent duplicates
    if (self->_statsUpdateTimer) {
        [self->_statsUpdateTimer invalidate];
        self->_statsUpdateTimer = nil;
    }
    // Re-schedule the timer only if the overlay is enabled
    if (_settings.statsOverlayEnabled) {
        self->_statsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                                 target:self
                                                               selector:@selector(updateStatsOverlay)
                                                               userInfo:nil
                                                                repeats:YES];
    } else {
        // Ensure the overlay is removed when disabled
        [_overlayView removeFromSuperview];
    }
    
    // Re-create the ImGui view to properly apply the 'enableGraphs' setting
    if (self.imguiView && self.imguiView.mtkView) {
        [self.imguiView stop];
        [self.imguiView.mtkView removeFromSuperview];
        self.imguiView = nil;
    }
    self.imguiView = [[ImGuiRenderer alloc] initWithFrame:self.view.bounds
                                                streamFps:[_settings.framerate intValue]
                                             enableGraphs:_settings.enableGraphs
                                             graphOpacity:[_settings.graphOpacity intValue]];
    self.imguiView.mtkView.userInteractionEnabled = NO;
    [self.view addSubview:self.imguiView.mtkView];

    // Ensure views are layered correctly
    // Metal view should be at the bottom for video rendering
    if (self.metalViewController && self.metalViewController.view.superview) {
        [self.view sendSubviewToBack:self.metalViewController.view];
    }
    // StreamView should also be at the back so OSC CALayers on self.view show
    if (self->_streamView && self->_streamView.superview) {
        [self.view sendSubviewToBack:self->_streamView];
    }
    // ImGui view should be on top for debug graphs
    if (self.imguiView && self.imguiView.mtkView.superview) {
        [self.view bringSubviewToFront:self.imguiView.mtkView];
    }
    
    // [self pauseTimer];
    if(_settings.sendDummyEvent){
        if(!safeTimer) [self setupTimer];
        if(!_viewJustLoaded) [safeTimer start];
    }
    else [safeTimer pause];
    
    _motionHandler = [MotionHandler sharedWithProfile: nil];
    _motionHandler.gyroBiasX = _settings.gyroBiasX.doubleValue;
    _motionHandler.gyroBiasY = _settings.gyroBiasY.doubleValue;
    _motionHandler.gyroBiasZ = _settings.gyroBiasZ.doubleValue;    
    
    TouchPadGestureHandler.enablePinch = _settings.enablePinch;
    TouchPadGestureHandler.ctrlDownForPinch = _settings.ctrlDownForPinch;
    TouchPadGestureHandler.scrollSensitivity = _settings.scrollSensitivity.floatValue;
    TouchPadGestureHandler.pinchSensitivity = _settings.pinchSensitivity.floatValue;
    TouchPadGestureHandler.displayLinkRate = _settings.framerate.intValue;

    NSLog(@"frameview gestures: %d", (uint32_t)[self.view.gestureRecognizers count]);
    NSLog(@"streamview gestures: %d", (uint32_t)[_streamView.gestureRecognizers count]);
}

- (void)viewWillAppear:(BOOL)animated {
    // if(_settings.sendDummyEvent) [self startTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _viewJustLoaded = false;
    _deviceWindow = self.view.window;
    previousOnScreenWidgetEnabled = [_streamView isOnScreenWidgetEnabled];
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
        [self->_streamView insertSubview:self->_streamVideoRenderView atIndex:0];
        // Fallback on earlier versions
    }

    self->_streamView.originalFrame = self->_streamView.frame;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"pausing...");
        nil;
    });

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
    
    [safeTimer start];
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
    
    NSString* settingsEdgeSide = _settings.slideToSettingsScreenEdge.intValue == UIRectEdgeLeft ? [LocalizationHelper localizedStringForKey:@"left"] : [LocalizationHelper localizedStringForKey:@"right"];
    NSString* cmdToolEdgeSide = _settings.slideToSettingsScreenEdge.intValue == UIRectEdgeLeft ? [LocalizationHelper localizedStringForKey:@"right"] : [LocalizationHelper localizedStringForKey:@"left"];
    uint8_t slideDist = (uint8_t)(_settings.slideToSettingsDistance.floatValue * 100);
    // 创建弹窗
    NSString* tipText = [LocalizationHelper localizedStringForKey:@"firstLaunchTip", settingsEdgeSide, slideDist, cmdToolEdgeSide, slideDist];
    
    [AlertControllerUtil showAlertIn:self
                                    title:[LocalizationHelper localizedStringForKey:@"First Launch Tips"]
                                  message:tipText
                               withCancel:NO
                              buttonTitle:[LocalizationHelper localizedStringForKey:@"Got it!"]
                                countdown:16
                                   action:^{}
                               completion:^{}];
    
    return;
}

- (void)updateTheme {
    self.view.backgroundColor = [ThemeManager appBackgroundColor];
    _stageLabel.textColor = [[ThemeManager textColor] colorWithAlphaComponent:0.9];
    _spinner.color = [ThemeManager textColor];
}

- (void)viewDidLoad
{
    _viewJustLoaded = true;
    viewIsBeingResized = false;
    [super viewDidLoad];

    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
        
    _settings = [[[DataManager alloc] init] getSettings];  //StreamFrameViewController retrieve the settings here.
    
    _stageLabel = [[UILabel alloc] init];
    [_stageLabel setUserInteractionEnabled:NO];
    // [_stageLabel setText:[NSString stringWithFormat:@"Starting %@...", self.streamConfig.appName]];
    [_stageLabel setText: [LocalizationHelper localizedStringForKey:@"Connecting..."]];
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
    // [_tipLabel setText:[LocalizationHelper localizedStringForKey:@"Tip: Swipe from screen edge to a certiain distance (configured by Swipe & Exit settings) to disconnect from your PC"]];
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
    
    // for compatibility of iOS14 & lower
    self.view.backgroundColor = [UIColor systemGrayColor];
    _stageLabel.textColor = [UIColor systemGrayColor];
    _spinner.color = [UIColor systemGrayColor];
    
    [self updateTheme];
    
    [self.view addSubview:_stageLabel];
    [self.view addSubview:_spinner];
    [self.view addSubview:_tipLabel];

    if ([_settings.renderingBackend intValue] == RENDER_METAL) {
        // Metal view for video
        Log(LOG_I, @"StreamFrameViewController creating MetalViewController");
        self.metalViewController = [[MetalViewController alloc] initWithFrame:self.view.bounds
                                                                    framerate:[self->_settings.framerate floatValue]
                                                                    settings:self->_settings
                                                               metricsHandler:self.imguiView.metricsHandler];
        self.metalViewController.view.userInteractionEnabled = NO;
        [self addChildViewController:self.metalViewController];
        // Insert Metal view at the bottom of the view hierarchy
        [self.view insertSubview:self.metalViewController.view atIndex:0];
        [self.metalViewController didMoveToParentViewController:self];
    }
    
    _mainFrameViewcontroller.sessionLaunchedWithAbsoluteTouch = _settings.touchMode.intValue == AbsoluteTouch;
}

- (void)keyboardWillShow:(NSNotification *)notification{
    [_streamView keyboardWillShow:notification];
}

- (void)keyboardWillHide{
    [_streamView keyboardWillHide];
}

- (void)handleWidgetLayoutGesture{
    [self configOscLayoutTool];
    [self openWidgetLayoutTool];
}

- (void)openWidgetLayoutTool{
    [_streamView saveStreamViewWidgetChanges];
    _streamView.widgetToolOpened = true;
    [self->_streamView disableOnScreenControls];
    [self->_streamView clearOnScreenWidgets]; // clear all onScreenKeyboardButtons before entering edit mode
    _layoutOnScreenControlsVC.quickSwitchEnabled = false;
    _layoutOnScreenControlsVC.toolbarStackView.hidden = false;
    _layoutOnScreenControlsVC.toolbarRootView.hidden = false;
    [self presentViewController:_layoutOnScreenControlsVC animated:YES completion:nil];
}

- (void)openWidgetProfileTableWithPickProfile:(BOOL)pickProfile{
    [_streamView saveStreamViewWidgetChanges];
    _streamView.widgetToolOpened = true;
    [self->_streamView disableOnScreenControls];
    [self->_streamView clearOnScreenWidgets]; // clear all onScreenKeyboardButtons before entering edit mode
    _layoutOnScreenControlsVC.quickSwitchEnabled = true;
    _layoutOnScreenControlsVC.toolbarStackView.hidden = true;
    _layoutOnScreenControlsVC.toolbarRootView.hidden = true;
    [self presentViewController:_layoutOnScreenControlsVC animated:NO completion:^{
        [self->_layoutOnScreenControlsVC presentProfilesTableViewWithPickProfile:pickProfile];
    }];
}

- (void)bringUpSoftKeyboard{
    [self->_streamView readyToBringUpSoftKeyboardByToolbox];
}

- (void)enterPip{
    [self.pipController startPictureInPicture];
}

- (void)alterAbsTouchDragWithMouseButton:(int32_t)mouseButton{
    [_streamView alterAbsTouchDragWith:mouseButton];
}

- (void)oscLayoutClosed{
    // Handle the callback
    _streamView.widgetToolOpened = false;
    [self->_streamView disableOnScreenControls]; // add this to get realtime back menu working.
    [self->_streamView reloadOnScreenControlsWith:(ControllerSupport*)_controllerSupport
                                        andConfig:(StreamConfiguration*)_streamConfig];
    // [self->_streamView reloadLegacyWidgets];
    [self->_streamView reloadOnScreenWidgetViews:true]; //update keyboard buttons here
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
        _streamView = nil;
        [_streamView cleanUp];
        [_controllerSupport cleanup];

        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [_streamMan stopStream];
        if (_inactivityTimer != nil) {
            [_inactivityTimer invalidate];
            _inactivityTimer = nil;
        }
        if (self.metalViewController) {
            [self.metalViewController.view removeFromSuperview];
            [self.metalViewController removeFromParentViewController];
            self.metalViewController = nil;
            NSLog(@"Metal renderer stopped and cleaned up.");
        }
        [NativeTouchPointer cleanUpContext];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        for(UIView* view in self.view.subviews){
            [view removeFromSuperview];
        }
        
        [safeTimer pause];
        [safeTimer clean];
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
        // Invalidate the timer when stats overlay is disabled
        if (_statsUpdateTimer) {
            [_statsUpdateTimer invalidate];
            _statsUpdateTimer = nil;
        }
        return; // add this for realtime streamview reconfig
    }
    
    // Only add the overlay if it's not already in the view hierarchy
    if (_overlayView.superview == nil) {
        [self.view addSubview:_overlayView];
    }

    NSString* overlayText = [self->_streamMan getStatsOverlayText:overlayLevel];
                             
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateOverlayText:overlayText];
    });
}

- (void)setupOverlayView{
    if (_overlayView == nil) {
        _overlayView = [[PaddedLabel alloc] initWithFrame:CGRectZero];
        [_overlayView setTextInsets:UIEdgeInsetsMake([_mainFrameViewcontroller isIPhone]?4:6, 12, [_mainFrameViewcontroller isIPhone]?4:6, 12)];
        [_overlayView setUserInteractionEnabled:NO];
        [_overlayView setNumberOfLines:100];
        [_overlayView.layer setCornerRadius:[_mainFrameViewcontroller isIPhone]?7:10];
        [_overlayView.layer setMasksToBounds:YES];
        
        // HACK: If not using stats overlay, center the text
        if (_statsUpdateTimer == nil) {
            [_overlayView setTextAlignment:NSTextAlignmentCenter];
        }
        
        [_overlayView setTextColor:[UIColor lightGrayColor]];
        [_overlayView setBackgroundColor:[UIColor blackColor]];
#if TARGET_OS_TV
        [_overlayView setFont:[UIFont systemFontOfSize:24 weight:UIFontWeightMedium]];
#else
        [_overlayView setFont:[UIFont systemFontOfSize: [_mainFrameViewcontroller isIPhone]?10:12 weight:UIFontWeightMedium]];
#endif
        [_overlayView setAlpha:(float)[_settings.graphOpacity intValue]/ 100.0];
        [self.view addSubview:_overlayView];
    }
    if (@available(iOS 13.0, *)) {
       if(overlayLevel == 1) _overlayView.font = [UIFont monospacedSystemFontOfSize:[_mainFrameViewcontroller isIPhone]?10:12 weight:UIFontWeightMedium];
    }
    
    [_overlayView setHidden:YES];
}

- (void)updateOverlayText:(NSString*)text {
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
        [_overlayView setCenter:CGPointMake(self.view.frame.size.width / 2, (4 + (_overlayView.frame.size.height / 2)))];
        [_overlayView setHidden:NO];
    }
    else {
        [_overlayView setHidden:YES];
    }
}

- (void) returnToMainFrame {
    [_streamView clearOnScreenWidgets];
    if(micHandler) [micHandler clean];
    PencilHandler.shared = nil;
    
    // Reset display mode back to default
    [self updatePreferredDisplayMode:NO];
    if (@available(iOS 13.0, *)) {
        [SceneDelegate clearExternalDisplayRenderView];
    }

    if (_settings.enablePIP) {
        [self cleanupPiPController];
    }

    [_statsUpdateTimer invalidate];
    _statsUpdateTimer = nil;
    
    [self.navigationController popToRootViewControllerAnimated:NO];
    
    _extWindow = nil;
    
    if(_streamConfig.redirectMic) [micHandler stopTappingWithStopEngine:true];

    self.mainFrameViewcontroller.settingsExpandedInStreamView = false; // reset this flag to false
}

// External Screen connected
- (void)extScreenDidConnect:(NSNotification *)notification {
    Log(LOG_I, @"External Screen Connected");
    if ([self isAirPlayEnabled] && [notification.object isKindOfClass:[UIScreen class]]) {
        // UIScreen *extScreen = (UIScreen *)notification.object;
        if (_streamVideoRenderView) {
             // Remove from current superview before passing it
             [_streamVideoRenderView removeFromSuperview];
             if (@available(iOS 13.0, *)) {
                 [SceneDelegate setExternalDisplayRenderView:_streamVideoRenderView];
             }
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
        if (@available(iOS 13.0, *)) {
            [SceneDelegate clearExternalDisplayRenderView];
        }
        // Add the render view back to the local StreamView if AirPlay was active
        if ([self isAirPlayEnabled]) {
            if (_streamVideoRenderView && _streamView) {
                [_streamView insertSubview:_streamVideoRenderView atIndex:0];
                [self handleViewResize]; // Adjust frames as needed
                [self reConfigStreamViewRealtimeAndReloadSettings:YES reloadOnscreenWidgets:YES];
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
        if (@available(iOS 13.0, *)) {
            [SceneDelegate setExternalDisplayRenderView:_streamVideoRenderView];
        }
    }else if ([self isAirPlaying] && ![self isAirPlayEnabled]){
        if (@available(iOS 13.0, *)) {
            [SceneDelegate clearExternalDisplayRenderView];
        }
    }
}

- (void) handleViewResize{
    viewIsBeingResized = true;
    
    _streamView.bounds = _deviceWindow.bounds;
    _streamView.frame = _deviceWindow.frame;
    
    if(![self isAirPlaying]){
        _streamVideoRenderView.bounds = _deviceWindow.bounds;
        _streamVideoRenderView.frame = _deviceWindow.frame;

        // Handle resize for meetal renderer
        if ([_settings.renderingBackend intValue] == RENDER_METAL && self.metalViewController) {
            self.metalViewController.view.frame = _deviceWindow.bounds;
            [self.metalViewController.view setNeedsLayout];
            [self.metalViewController.view layoutIfNeeded];
            Log(LOG_I, @"Updated Metal view bounds after resize");
        }
        
        // Handle resize for AVSB renderer
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:@"ScreenChanged" object:self];
    }
}


// This will fire if the user opens control center or gets a low battery message
- (void)applicationWillResignActive:(NSNotification *)notification {
    //[self.pipController startPictureInPicture];
    //sleep(1);
    appDidEnterBackgroundWithoutPip = true;

    [_streamView saveStreamViewWidgetChanges];

#if !TARGET_OS_TV
#endif
}

- (void)inactiveTimerExpired:(NSTimer*)timer {
    Log(LOG_I, @"Terminating stream after inactivity");

    [self returnToMainFrame];
    
    _inactivityTimer = nil;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    appDidEnterBackgroundWithoutPip = false;
    // Stop the background timer, since we're foregrounded again
    if (_inactivityTimer != nil) {
        Log(LOG_I, @"Stopping inactivity timer after becoming active again");
        [_inactivityTimer invalidate];
        _inactivityTimer = nil;
    }

    // Check if we were in PiP
    if (self.pipController && self.pipController.isPictureInPictureActive) {
        [self.pipController stopPictureInPicture];
    }
    
    if ([_settings.renderingBackend intValue] == RENDER_METAL && self.metalViewController) {
        Log(LOG_I, @"Resuming Metal renderer on foreground");
        [self.metalViewController resumeRendering];
    }
    
    if (self.imguiView && self.imguiView.mtkView && _settings.enableGraphs) {
        self.imguiView.mtkView.enableSetNeedsDisplay = YES;
        self.imguiView.mtkView.paused = NO;
        Log(LOG_I, @"Resuming ImGui renderer on foreground");
    }
    
    [self->_streamMan.videoRenderer resetFramePacing];
    _isRestoringFromPiP = NO;
}

// This fires when the home button is pressed
- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSLog(@"did enter background, %d, %@, %d", _settings.enablePIP, self.pipController, self.pipController.isPictureInPictureActive);
    if (_settings.enablePIP && self.pipController && self.pipController.isPictureInPictureActive) {
        //Log(LOG_I, @"PIP is active, not terminating stream");
        appDidEnterBackgroundWithoutPip = false;
    } else {
        appDidEnterBackgroundWithoutPip = true;

        if ([_settings.renderingBackend intValue] == RENDER_METAL && self.metalViewController) {
            Log(LOG_I, @"Pausing Metal renderer on background");
            [self.metalViewController pauseRendering];
        }
        
        if (self.imguiView && self.imguiView.mtkView) {
            self.imguiView.mtkView.paused = YES;
            self.imguiView.mtkView.enableSetNeedsDisplay = NO;
            Log(LOG_I, @"Pausing ImGui renderer on background");
        }
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
    [_streamView saveStreamViewWidgetChanges];
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
    [self returnToMainFrame];
}

- (void)disconnectAndQuitApp{
    [self returnToMainFrame];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1.5);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mainFrameViewcontroller quitRunningApp];
        });
    });
}

- (void) connectionStarted {
    Log(LOG_I, @"Connection started");
    dispatch_async(dispatch_get_main_queue(), ^{
        // Leave the spinner spinning until it's obscured by
        // the first frame of video.
        self->_stageLabel.hidden = YES;
        self->_tipLabel.hidden = YES;
        self->_spinner.hidden = YES;
        
        // Ensure correct view hierarchy before showing OSC
        if ([self->_settings.renderingBackend intValue] == RENDER_METAL && self.metalViewController) {
            [self.view sendSubviewToBack:self.metalViewController.view];
        }
        // For AVSB renderer, ensure streamView is at the back so OSC layers show
        if (self->_streamView && self->_streamView.superview) {
            [self.view sendSubviewToBack:self->_streamView];
        }
        
        // [self->_streamView showOnScreenControls];
        
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
    return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* lowerCase = [NSString stringWithFormat:@"%s ...", stageName];
        NSString* titleCase = [[[lowerCase substringToIndex:1] uppercaseString] stringByAppendingString:[lowerCase substringFromIndex:1]];
        [self->_stageLabel setText:titleCase];
        [self->_stageLabel sizeToFit];
        self->_stageLabel.center = CGPointMake(self.view.frame.size.width / 2, self->_stageLabel.center.y);
    });
}

- (void) stageComplete:(const char*)stageName {
    _micStreamInitialized = false;
    if(strcmp(stageName, "mic stream establishment")==0){
        if(self->_streamConfig.redirectMic){
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
            dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                self->_micStreamInitialized = true;
                self->micHandler = [[MicHandler alloc] initWithUseBuiltinMic:self->_settings.useBuiltinMic];
                [MicHandler setVolume:self->_settings.micVolume.floatValue];
                [self->micHandler startTapping];
            });
        }
    }
    
    if(strcmp(stageName, "mic stream unsupported or unintialized")==0){
        _micStreamInitialized = false;
    }
    
    // 8bit 444 degration workaround
    if(strcmp(stageName, "video stream establishment")==0){
        NSLog(@"sendAutoReleaseComboCommandWithCmdStrings %f", CACurrentMediaTime());
        if(!_settings.enableHdr
           && _settings.sdrPerformanceWorkaround
           && [Utils hdrSupported]
           ){
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
            dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if(LiGetCurrentHostDisplayHdrMode()){
                    NSArray* hdrCommand = [CommandManager.shared extractAutoReleaseButtonStringsFrom:@"WIN+ALT+B"];
                    [CommandManager.shared sendAutoReleaseComboCommandWithCmdStrings:hdrCommand delay:0.15 index:0 pressOnly:false releaseOnly:false];
                }
            });
        }
    }
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
    // Toggle the values on the current in-memory settings object for a temporary effect
    _settings.statsOverlayEnabled = !_settings.statsOverlayEnabled;
    // _settings.enableGraphs = _settings.statsOverlayEnabled;
    
    // Reconfigure the UI using the current in-memory settings, without reloading from disk
    [self reConfigStreamViewRealtimeAndReloadSettings:NO reloadOnscreenWidgets:NO];
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

- (NSMutableDictionary *)startGyroUpdate:(OnScreenWidgetView *)sender yawFactor:(CGFloat)yawFactor pitchFactor:(CGFloat)pitchFactor rollFactor:(CGFloat)rollFactor{
    NSMutableDictionary* gyroControlPreviousStatus = [NSMutableDictionary dictionary];

    if(!_motionHandler.gyroControlStarted) [gyroControlPreviousStatus setObject:sender forKey:@"gyroControlStarter"];
    [gyroControlPreviousStatus setObject:@(_motionHandler.widgetYawFactor) forKey:@"previousYawFactor"];
    [gyroControlPreviousStatus setObject:@(_motionHandler.widgetPitchFactor) forKey:@"previousPitchFactor"];
    [gyroControlPreviousStatus setObject:@(_motionHandler.widgetRollFactor) forKey:@"previousRollFactor"];
    _motionHandler.widgetYawFactor = yawFactor;
    _motionHandler.widgetPitchFactor = pitchFactor;
    _motionHandler.widgetRollFactor = rollFactor;
    [_motionHandler startGyroUpdate];

    return gyroControlPreviousStatus;
}


- (NSMutableDictionary*)start:(CGFloat)yawFactor pitchFactor:(CGFloat)pitchFactor rollFactor:(CGFloat)rollFactor{
    NSMutableDictionary* gyroControlPreviousStatus = [NSMutableDictionary dictionary];
    if(!_motionHandler.gyroControlStarted){
        [gyroControlPreviousStatus setObject:@(_motionHandler.gyroControlStarted) forKey:@"gyroStarted"];
    }
    [gyroControlPreviousStatus setObject:@(_motionHandler.widgetYawFactor) forKey:@"previousYawFactor"];
    [gyroControlPreviousStatus setObject:@(_motionHandler.widgetPitchFactor) forKey:@"previousPitchFactor"];
    [gyroControlPreviousStatus setObject:@(_motionHandler.widgetRollFactor) forKey:@"previousRollFactor"];

    _motionHandler.widgetYawFactor = yawFactor;
    _motionHandler.widgetPitchFactor = pitchFactor;
    _motionHandler.widgetRollFactor = rollFactor;
    [_motionHandler startGyroUpdate];
    
    return gyroControlPreviousStatus;
}

- (void)startAccelUpdate{
    [_motionHandler startAccelUpdate];
}

- (void)stopGyroUpdateWithInterruptNoneGyroInput:(BOOL)interruption{
    [_motionHandler stopGyroUpdateWithInterruptNoneGyroInput:interruption resetLeftStick:false];
}

- (void)stopAccelUpdate{
    [_motionHandler stopAccelUpdate];
}

- (void)enablePencilHover{
    [_streamView enablePencilHover];
}

- (void)disablePencilHover{
    [_streamView disablePencilHover];
}

- (void)setAllowSingleTouchEnabled:(BOOL)enabled{
    [_streamView setAllowSingleTouchEnabled:enabled];
}

- (void)replaceBrushWithShortcut:(NSString *)shortcut{
    if(PencilHandler.shared){
        [PencilHandler.shared replaceBrushWith:shortcut];
    }
}

- (void)replaceEraserWithShortcut:(NSString *)shortcut{
    if(PencilHandler.shared){
        [PencilHandler.shared replaceEraserWith:shortcut];
    }
}

- (void)presentPressureCurveVC{
    PressureCurveViewController* pressureCurveVC = [[PressureCurveViewController alloc] init];
    pressureCurveVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [self presentViewController:pressureCurveVC animated:YES completion:nil];
}

#if !TARGET_OS_TV
// Require a confirmation when streaming to activate a system gesture
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
    return UIRectEdgeAll;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    if ( [_controllerSupport getConnectedGamepadCount] > 0 && [_streamView getCurrentOscState] == OnScreenControlsLevelOff &&
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
    [self->_streamView saveStreamViewWidgetChanges];

    if (_isRestoringFromPiP) {
        Log(LOG_I, @"View size changed during PiP restore, skipping redundant reconfiguration.");
        return;
    }

    Log(LOG_I, @"View size changed, terminating stream");
    
    double delayInSeconds = 0.2;
    if (_delayedRemoveExtScreen) {
        dispatch_block_cancel(_delayedRemoveExtScreen);
    }
    dispatch_block_t block = dispatch_block_create(0, ^{
        [self handleViewResize];
        [self reConfigStreamViewRealtimeAndReloadSettings:YES reloadOnscreenWidgets:YES];
    });
    _delayedRemoveExtScreen = block;
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(delayTime, dispatch_get_main_queue(), block);
}

- (void)dealloc {
    NSLog(@"dealloc StreamFrameViewController %f", CACurrentMediaTime());
}

- (void)setupTimer {
    TemporarySettings* tempSettings = [[[DataManager alloc] init] getSettings];  //StreamFrameViewController retrieve the settings here.
    safeTimer = [[SafeTimer alloc] initWithInterval:1.0/tempSettings.framerate.intValue delay:0 queueLabel:@"streamview.timer" handler:^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            LiSendKeyboardEvent(0xFF, KEY_ACTION_UP, 0);
            // LiSendTouchEvent(LI_TOUCH_EVENT_UP, 200, 1, 1, 0, 0, 0, 0);
        });
    }];
}

@end
