#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSNotificationName const VoidLinkTvOSRemoteMenuTappedNotification;
FOUNDATION_EXPORT NSNotificationName const VoidLinkTvOSRemotePlayPauseTappedNotification;

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow * window;

// Main-thread-only. The view stays local until an external scene is ready.
+ (void)setExternalDisplayRenderView:(UIView *)renderView localContainer:(UIView *)localContainer;
+ (void)clearExternalDisplayRenderView:(UIView *)renderView;
+ (BOOL)isExternalDisplayRenderView:(UIView *)renderView;
- (void)updatePreferredDisplayMode:(BOOL)streamActive withRenderView:(UIView *)renderView;

@end
