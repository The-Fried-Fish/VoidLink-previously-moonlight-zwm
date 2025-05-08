#import "SceneDelegate.h"
#import "StreamFrameViewController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    if (!self.window) {
         NSLog(@"ERROR: Failed to create UIWindow in SceneDelegate.");
         return;
    }

    NSString *storyboardName;
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        storyboardName = @"iPad";
    } else {
        storyboardName = @"iPhone";
    }

    NSLog(@"Loading storyboard: %@", storyboardName);
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
    UIViewController *initialViewController = [storyboard instantiateInitialViewController];

    self.window.rootViewController = initialViewController;
    if (!self.window.rootViewController) {
         NSLog(@"ERROR: Failed to set rootViewController from storyboard '%@' in SceneDelegate.", storyboardName);
         return;
    }

    [self.window makeKeyAndVisible];
    NSLog(@"SceneDelegate: Window made key and visible with storyboard '%@'.", storyboardName);
}

@end
