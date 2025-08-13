#import <UIKit/UIKit.h>

API_AVAILABLE(ios(13.0))
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow * window;

+ (void)setExternalDisplayRenderView:(UIView *)renderView;
+ (void)clearExternalDisplayRenderView;
- (void)updatePreferredDisplayMode:(BOOL)streamActive withRenderView:(UIView *)renderView;

@end
