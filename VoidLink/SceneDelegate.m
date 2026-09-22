#import "SceneDelegate.h"
#import "StreamFrameViewController.h"
#if TARGET_OS_TV
#import <GameController/GameController.h>
#import "MainFrameViewController.h"
#import "SettingsViewController.h"
#import "SWRevealViewController.h"
#endif

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
    NSLog(@"shouldUpdateFocusInContext .........");
    return context.nextFocusedItem == nil || VoidLinkTvOSFocusItemIsSink(context.nextFocusedItem);
}

@end

@interface VoidLinkNoFocusNavigationController : UINavigationController
@end

@implementation VoidLinkNoFocusNavigationController

- (BOOL)canBecomeFocused {
    return NO;
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    NSLog(@"shouldUpdateFocusInContext .........");
    return context.nextFocusedItem == nil || VoidLinkTvOSFocusItemIsSink(context.nextFocusedItem);
}

@end

@interface VoidLinkControllerRootViewController : GCEventViewController

- (instancetype)initWithContentViewController:(UIViewController *)contentViewController;
- (void)forceFocusSinkUpdate;

@end

@implementation VoidLinkControllerRootViewController {
    UIViewController *_contentViewController;
    VoidLinkFocusSinkView *_focusSinkView;
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

    [self installFocusSinkIfNeeded];
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
    [self installFocusSinkIfNeeded];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view bringSubviewToFront:self->_focusSinkView];
        [self setNeedsFocusUpdate];
        [self updateFocusIfNeeded];
    });
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    if (_focusSinkView) {
        return @[_focusSinkView];
    }
    return [super preferredFocusEnvironments];
}

- (BOOL)canBecomeFocused {
    return NO;
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    NSLog(@"shouldUpdateFocusInContext .........");
    return context.nextFocusedItem == nil || VoidLinkTvOSFocusItemIsSink(context.nextFocusedItem);
}

@end
#endif

API_AVAILABLE(ios(13.0), tvos(13.0))
@implementation SceneDelegate

static UIView *_sharedStreamVideoRenderView = nil;
static UIWindow *_externalSceneWindow = nil;

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
#if TARGET_OS_TV
        self.window.rootViewController = [[VoidLinkControllerRootViewController alloc] initWithContentViewController:initialViewController];
#else
        self.window.rootViewController = initialViewController;
#endif
        [self.window makeKeyAndVisible];
#if TARGET_OS_TV
        // SWReveal intentionally keeps its rear controller unloaded until the
        // first reveal. Build and lay out the SwiftUI settings tree now so
        // opening the menu later does not pay that one-time UI cost.
        [tvOSSettingsViewController loadViewIfNeeded];
        tvOSSettingsViewController.view.frame = self.window.bounds;
        [tvOSSettingsViewController.view setNeedsLayout];
        [tvOSSettingsViewController.view layoutIfNeeded];
        if (@available(tvOS 14.0, *)) {
            [tvOSSettingsViewController refreshSwiftUISettingsGeometry];
        }
#endif
        Log(LOG_I, @"SceneDelegate: Main app scene connected.");

    } else if ([session.role isEqualToString:UIWindowSceneSessionRoleExternalDisplay]) {
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

        if (_sharedStreamVideoRenderView) {
            _sharedStreamVideoRenderView.frame = _externalSceneWindow.bounds;
            [_externalSceneWindow.rootViewController.view addSubview:_sharedStreamVideoRenderView];
            Log(LOG_I, @"SceneDelegate: External display scene connected.");
        }
    }
}


// Method for StreamFrameViewController to provide its render view
+ (void)setExternalDisplayRenderView:(UIView *)renderView {
    _sharedStreamVideoRenderView = renderView;
    if (_externalSceneWindow && _externalSceneWindow.rootViewController && _sharedStreamVideoRenderView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Ensure it's removed from any previous parent (should have been done by StreamFrameVC)
            [_sharedStreamVideoRenderView removeFromSuperview];
            _sharedStreamVideoRenderView.frame = _externalSceneWindow.bounds; // Set frame for external window
            [_externalSceneWindow.rootViewController.view addSubview:_sharedStreamVideoRenderView];
            _externalSceneWindow.hidden = NO;
            Log(LOG_I, @"SceneDelegate: Added render view to external window's root view.");
        });
    } else {
        Log(LOG_E, @"SceneDelegate: External display window or root view controller not available.");
    }
}

+ (void)clearExternalDisplayRenderView {
    if (_sharedStreamVideoRenderView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_sharedStreamVideoRenderView removeFromSuperview];
            Log(LOG_I, @"SceneDelegate: Removed render view from external display.");
        });
    }
    _sharedStreamVideoRenderView = nil;
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

    if ([scene.session.role isEqualToString:UIWindowSceneSessionRoleExternalDisplay]) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (_externalSceneWindow == windowScene.windows.firstObject) { // Compare with the window from the disconnecting scene
                [SceneDelegate clearExternalDisplayRenderView]; // Clears the shared view
                _externalSceneWindow = nil;
                Log(LOG_I, @"SceneDelegate: External display scene fully disconnected and cleaned up.");
            } else {
                Log(LOG_W, @"SceneDelegate: Disconnecting scene is not the one holding our _externalSceneWindow.");
            }
        } else {
            Log(LOG_W, @"SceneDelegate: Disconnecting scene is not a UIWindowScene.");
        }
    }
}

@end
