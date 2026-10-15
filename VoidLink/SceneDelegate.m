#import "SceneDelegate.h"
#import "StreamFrameViewController.h"
#import <GameController/GameController.h>
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST && !TARGET_OS_VISION && __has_include(<UIKit/UISceneAccessory.h>)
#import <UIKit/UISceneAccessory.h>
#import <UIKit/UISceneAccessoryRegistration.h>
#define VL_HAS_EXTERNAL_DISPLAY_ACCESSORY 1
#else
#define VL_HAS_EXTERNAL_DISPLAY_ACCESSORY 0
#endif
#if TARGET_OS_TV
#import "MainFrameViewController.h"
#import "SettingsViewController.h"
#import "SWRevealViewController.h"
#endif

NSNotificationName const VoidLinkTvOSRemoteMenuTappedNotification = @"VoidLinkTvOSRemoteMenuTappedNotification";
NSNotificationName const VoidLinkTvOSRemotePlayPauseTappedNotification = @"VoidLinkTvOSRemotePlayPauseTappedNotification";

#if TARGET_OS_TV
static BOOL VoidLinkTvOSFocusItemIsSink(id item) {
    if (item == nil) {
        return NO;
    }
    return [NSStringFromClass([item class]) containsString:@"VoidLinkFocusSinkView"];
}

@interface VoidLinkFocusSinkView : UIView
@end

@implementation VoidLinkFocusSinkView

- (BOOL)canBecomeFocused {
    return YES;
}

@end

@interface VoidLinkNoFocusWindow : UIWindow
@end

@implementation VoidLinkNoFocusWindow

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    return VoidLinkTvOSShouldUpdateFocus(context, self);
}

@end

@interface VoidLinkNoFocusNavigationController : UINavigationController
@end

@implementation VoidLinkNoFocusNavigationController

- (BOOL)canBecomeFocused {
    return NO;
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    return VoidLinkTvOSShouldUpdateFocus(context, self.view.window);
}

@end

#endif

@interface VoidLinkControllerRootViewController : GCEventViewController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController;
#if TARGET_OS_TV
- (void)forceFocusSinkUpdate;
#endif

@end

@implementation VoidLinkControllerRootViewController {
    UIViewController *_contentViewController;
#if TARGET_OS_TV
    VoidLinkFocusSinkView *_focusSinkView;
#endif
}

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _contentViewController = contentViewController;
        self.controllerUserInteractionEnabled = NO;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        self.controllerUserInteractionEnabled = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.controllerUserInteractionEnabled = NO;
    if (!_contentViewController || _contentViewController.parentViewController == self) {
        return;
    }

    [self addChildViewController:_contentViewController];
    _contentViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_contentViewController.view];
    [NSLayoutConstraint activateConstraints:@[
        [_contentViewController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_contentViewController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_contentViewController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_contentViewController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [_contentViewController didMoveToParentViewController:self];

#if TARGET_OS_TV
    [self installFocusSinkIfNeeded];
#endif
}

#if TARGET_OS_TV
- (void)setControllerUserInteractionEnabled:(BOOL)enabled {
    BOOL changed = self.controllerUserInteractionEnabled != enabled;
    [super setControllerUserInteractionEnabled:enabled];
    _focusSinkView.hidden = enabled;
    if (_focusSinkView && changed && !enabled) {
        [self forceFocusSinkUpdate];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self forceFocusSinkUpdate];
}

- (void)installFocusSinkIfNeeded {
    if (_focusSinkView) {
        return;
    }

    _focusSinkView = [[VoidLinkFocusSinkView alloc] initWithFrame:CGRectZero];
    _focusSinkView.translatesAutoresizingMaskIntoConstraints = NO;
    _focusSinkView.backgroundColor = UIColor.clearColor;
    _focusSinkView.userInteractionEnabled = YES;
    _focusSinkView.hidden = NO;
    _focusSinkView.alpha = 1.0;
    _focusSinkView.accessibilityIdentifier = @"VoidLinkFocusSink";
    [self.view addSubview:_focusSinkView];
    [NSLayoutConstraint activateConstraints:@[
        [_focusSinkView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:1.0],
        [_focusSinkView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:1.0],
        [_focusSinkView.widthAnchor constraintEqualToConstant:2.0],
        [_focusSinkView.heightAnchor constraintEqualToConstant:2.0],
    ]];
    [self.view bringSubviewToFront:_focusSinkView];
}

- (void)forceFocusSinkUpdate {
    if (self.controllerUserInteractionEnabled) {
        return;
    }
    [self installFocusSinkIfNeeded];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.controllerUserInteractionEnabled) {
            return;
        }
        [self.view bringSubviewToFront:self->_focusSinkView];
        [self setNeedsFocusUpdate];
        [self updateFocusIfNeeded];
    });
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    if (_focusSinkView && !self.controllerUserInteractionEnabled) {
        return @[_focusSinkView];
    }
    return [super preferredFocusEnvironments];
}

- (BOOL)canBecomeFocused {
    return NO;
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    return VoidLinkTvOSShouldUpdateFocus(context, self.view.window);
}
#endif

- (UIViewController *)childViewControllerForStatusBarStyle {
    return _contentViewController;
}

- (UIViewController *)childViewControllerForStatusBarHidden {
    return _contentViewController;
}

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden {
    return _contentViewController;
}

- (UIViewController *)childViewControllerForScreenEdgesDeferringSystemGestures {
    return _contentViewController;
}

#if !TARGET_OS_TV
- (UIViewController *)childViewControllerForPointerLock {
    return _contentViewController;
}
#endif

- (BOOL)shouldAutorotate {
    return _contentViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return _contentViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return _contentViewController.preferredInterfaceOrientationForPresentation;
}

@end

#if TARGET_OS_TV
BOOL VoidLinkTvOSShouldUpdateFocus(UIFocusUpdateContext *context, UIWindow *window) {
    UIViewController *root = window.rootViewController;
    if ([root isKindOfClass:[VoidLinkControllerRootViewController class]] &&
        ((VoidLinkControllerRootViewController *)root).controllerUserInteractionEnabled) {
        return YES;
    }
    return context.nextFocusedItem == nil || VoidLinkTvOSFocusItemIsSink(context.nextFocusedItem);
}
#endif

API_AVAILABLE(ios(13.0), tvos(13.0))
@implementation SceneDelegate

static __weak UIView *_sharedStreamVideoRenderView = nil;
static __weak UIView *_localRenderContainer = nil;
static UIViewAutoresizing _localRenderAutoresizingMask;
static UIWindow *_externalSceneWindow = nil;
#if VL_HAS_EXTERNAL_DISPLAY_ACCESSORY
static UISceneAccessoryRegistration *_externalDisplayAccessoryRegistration API_AVAILABLE(ios(27.0));
#endif

static BOOL VLIsExternalDisplaySession(UISceneSession *session) {
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        if ([session.role isEqualToString:UIWindowSceneSessionRoleExternalDisplayNonInteractive]) {
            return YES;
        }
    }
    return [session.role isEqualToString:UIWindowSceneSessionRoleExternalDisplay];
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    if ([session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
#if TARGET_OS_TV
        SettingsViewController *tvOSSettingsViewController = nil;
#endif
#if TARGET_OS_TV
        self.window = [[VoidLinkNoFocusWindow alloc] initWithWindowScene:windowScene];
#else
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
#endif
        NSString *storyboardName;
#if TARGET_OS_TV
        storyboardName = @"Main";
#else
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            storyboardName = @"iPad";
        } else {
            storyboardName = @"iPhone";
        }
#endif
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
        UIViewController *initialViewController = [storyboard instantiateInitialViewController];
#if TARGET_OS_TV
        if ([initialViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *frontNavigationController = (UINavigationController *)initialViewController;
            SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
            tvOSSettingsViewController = settingsViewController;
            SWRevealViewController *revealViewController = [[SWRevealViewController alloc] initWithRearViewController:settingsViewController
                                                                                                   frontViewController:frontNavigationController];
            UIViewController *topViewController = frontNavigationController.topViewController;
            if ([topViewController isKindOfClass:[MainFrameViewController class]]) {
                MainFrameViewController *mainFrameViewController = (MainFrameViewController *)topViewController;
                mainFrameViewController.settingsViewController = settingsViewController;
                settingsViewController.mainFrameViewController = mainFrameViewController;
                [revealViewController setDelegate:mainFrameViewController];
                revealViewController.bounceBackOnOverdraw = NO;
            }
            initialViewController = revealViewController;
        }
#endif
        self.window.rootViewController = [[VoidLinkControllerRootViewController alloc] initWithContentViewController:initialViewController];
        [self.window makeKeyAndVisible];
#if VL_HAS_EXTERNAL_DISPLAY_ACCESSORY
        if (@available(iOS 27.0, *)) {
            UISceneConfiguration *configuration = [[UISceneConfiguration alloc]
                initWithName:@"VoidLink External Display"
                sessionRole:UIWindowSceneSessionRoleExternalDisplayNonInteractive];
            configuration.delegateClass = SceneDelegate.class;
            UISceneAccessory *accessory = [UISceneAccessory externalNonInteractiveSceneAccessoryWithConfiguration:configuration];
            _externalDisplayAccessoryRegistration = [self.window.rootViewController registerSceneAccessory:accessory];
        }
#endif
#if TARGET_OS_TV
        // SWReveal keeps the rear controller unloaded until it is revealed.
        // Preheat the SwiftUI settings hierarchy without consuming its
        // launch-time settings snapshot; the first real reveal consumes it.
        [tvOSSettingsViewController loadViewIfNeeded];
        tvOSSettingsViewController.view.frame = self.window.bounds;
        [tvOSSettingsViewController.view setNeedsLayout];
        [tvOSSettingsViewController.view layoutIfNeeded];
        if (@available(tvOS 14.0, *)) {
            [tvOSSettingsViewController refreshSwiftUISettingsGeometry];
        }
#endif
        Log(LOG_I, @"SceneDelegate: Main app scene connected.");

    } else if (VLIsExternalDisplaySession(session)) {
        Log(LOG_I, @"SceneDelegate: External display scene connecting for screen: %@", ((UIWindowScene *)scene).screen.description);
        UIWindowScene *windowScene = (UIWindowScene *)scene;
#if TARGET_OS_TV
        _externalSceneWindow = [[VoidLinkNoFocusWindow alloc] initWithWindowScene:windowScene];
#else
        _externalSceneWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
#endif
        UIViewController *externalVC = [[UIViewController alloc] init];
        externalVC.view.backgroundColor = [UIColor blackColor]; // Set a default background
        _externalSceneWindow.rootViewController = externalVC;

        [SceneDelegate attachExternalDisplayRenderViewIfReady];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenChanged" object:windowScene];
    }
}


+ (void)attachExternalDisplayRenderViewIfReady {
    NSAssert(NSThread.isMainThread, @"External display routing must run on the main thread");
    UIView *renderView = _sharedStreamVideoRenderView;
    UIView *container = _externalSceneWindow.rootViewController.view;
    if (!renderView || !container || renderView.superview == container) {
        return;
    }
    renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    renderView.frame = container.bounds;
    [container addSubview:renderView];
    _externalSceneWindow.hidden = NO;
    Log(LOG_I, @"SceneDelegate: Stream attached to external display.");
}

+ (void)restoreLocalRenderView {
    UIView *renderView = _sharedStreamVideoRenderView;
    UIView *container = _localRenderContainer;
    if (renderView && container && renderView.superview != container) {
        renderView.autoresizingMask = _localRenderAutoresizingMask;
        renderView.frame = container.bounds;
        [container insertSubview:renderView atIndex:0];
        Log(LOG_I, @"SceneDelegate: Stream restored to local display.");
    }
    _externalSceneWindow.hidden = YES;
}

+ (void)setExternalDisplayRenderView:(UIView *)renderView localContainer:(UIView *)localContainer {
    NSAssert(NSThread.isMainThread, @"External display routing must run on the main thread");
    if (!renderView || !localContainer) {
        return;
    }
    if (_sharedStreamVideoRenderView != renderView) {
        [self restoreLocalRenderView];
        _localRenderAutoresizingMask = renderView.autoresizingMask;
    }
    _sharedStreamVideoRenderView = renderView;
    _localRenderContainer = localContainer;
    [self attachExternalDisplayRenderViewIfReady];
}

+ (void)clearExternalDisplayRenderView:(UIView *)renderView {
    NSAssert(NSThread.isMainThread, @"External display routing must run on the main thread");
    if (!renderView || _sharedStreamVideoRenderView != renderView) {
        return;
    }
    [self restoreLocalRenderView];
    _sharedStreamVideoRenderView = nil;
    _localRenderContainer = nil;
}

+ (BOOL)isExternalDisplayRenderView:(UIView *)renderView {
    return renderView && renderView == _sharedStreamVideoRenderView &&
        _externalSceneWindow && !_externalSceneWindow.hidden &&
        renderView.superview == _externalSceneWindow.rootViewController.view;
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
#if TARGET_OS_TV
    if (scene == self.window.windowScene &&
        [self.window.rootViewController isKindOfClass:[VoidLinkControllerRootViewController class]]) {
        [(VoidLinkControllerRootViewController *)self.window.rootViewController forceFocusSinkUpdate];
    }
#endif
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    Log(LOG_I, @"SceneDelegate: Scene disconnected: %@, role: %@", scene.title, scene.session.role);

    if (VLIsExternalDisplaySession(scene.session)) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (_externalSceneWindow == windowScene.windows.firstObject) { // Compare with the window from the disconnecting scene
                [SceneDelegate restoreLocalRenderView];
                _externalSceneWindow = nil;
                Log(LOG_I, @"SceneDelegate: External display scene fully disconnected and cleaned up.");
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenChanged" object:windowScene];
            } else {
                Log(LOG_W, @"SceneDelegate: Disconnecting scene is not the one holding our _externalSceneWindow.");
            }
        } else {
            Log(LOG_W, @"SceneDelegate: Disconnecting scene is not a UIWindowScene.");
        }
    }
}

@end
