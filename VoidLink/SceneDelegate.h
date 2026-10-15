#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSNotificationName const VoidLinkTvOSRemoteMenuTappedNotification;
FOUNDATION_EXPORT NSNotificationName const VoidLinkTvOSRemotePlayPauseTappedNotification;

#if TARGET_OS_TV
FOUNDATION_EXPORT BOOL VoidLinkTvOSShouldUpdateFocus(UIFocusUpdateContext *context, UIWindow *window);
#endif

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow * window;

+ (void)setExternalDisplayRenderView:(UIView *)renderView localContainer:(UIView *)localContainer;
+ (void)clearExternalDisplayRenderView:(UIView *)renderView;
+ (BOOL)isExternalDisplayRenderView:(UIView *)renderView;
- (void)updatePreferredDisplayMode:(BOOL)streamActive withRenderView:(UIView *)renderView;

@end
