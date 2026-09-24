#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSNotificationName const VoidLinkTvOSRemoteMenuTappedNotification;
FOUNDATION_EXPORT NSNotificationName const VoidLinkTvOSRemotePlayPauseTappedNotification;

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow * window;

+ (void)setExternalDisplayRenderView:(UIView *)renderView;
+ (void)clearExternalDisplayRenderView;
- (void)updatePreferredDisplayMode:(BOOL)streamActive withRenderView:(UIView *)renderView;

@end
