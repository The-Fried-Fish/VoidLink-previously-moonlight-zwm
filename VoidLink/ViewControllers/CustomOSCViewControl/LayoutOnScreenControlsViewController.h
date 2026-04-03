#import <UIKit/UIKit.h>
#import "ToolBarContainerView.h"

NS_ASSUME_NONNULL_BEGIN

@interface LayoutOnScreenControlsViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, assign) BOOL quickSwitchEnabled;
@property (weak, nonatomic) IBOutlet ToolBarContainerView *toolbarRootView;
@property (weak, nonatomic) IBOutlet UIStackView *toolbarStackView;

- (void)profileRefresh;
- (void)reloadOnScreenWidgetViews;
- (void)presentProfilesTableViewWithLoadingMode:(NSInteger)loadingMode;

@end

NS_ASSUME_NONNULL_END
