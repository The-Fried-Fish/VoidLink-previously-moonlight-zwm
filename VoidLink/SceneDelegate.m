#import "SceneDelegate.h"
#import "StreamFrameViewController.h"

API_AVAILABLE(ios(13.0))
@implementation SceneDelegate

static UIView *_sharedStreamVideoRenderView = nil;
static UIWindow *_externalSceneWindow = nil;

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    if ([session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
        self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
        NSString *storyboardName;
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            storyboardName = @"iPad";
        } else {
            storyboardName = @"iPhone";
        }
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
        UIViewController *initialViewController = [storyboard instantiateInitialViewController];
        self.window.rootViewController = initialViewController;
        [self.window makeKeyAndVisible];
        Log(LOG_I, @"SceneDelegate: Main app scene connected.");

    } else if ([session.role isEqualToString:UIWindowSceneSessionRoleExternalDisplay]) {
        Log(LOG_I, @"SceneDelegate: External display scene connecting for screen: %@", ((UIWindowScene *)scene).screen.description);
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        _externalSceneWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
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
