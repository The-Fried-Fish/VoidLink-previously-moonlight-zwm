//
//  OSCProfilesTableViewController.h
//  Moonlight
//
//  Created by Long Le on 11/28/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This view displays a list of on screen controller profiles and gives the user the ability to select any of the profiles to be the 'Selected' profile whose on screen controller layout configuration will be shown on the game stream view, or in the on screen controller layout view.  This view also allows the user to swipe and delete any of the listed profiles.
 */
@interface OSCProfilesTableViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>

- (void)profileViewRefresh;

typedef NS_ENUM(NSUInteger, FileOperation) {
    Import,
    Export
};

@property (nonatomic, assign) FileOperation currentFileOperation;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, copy) void (^needToUpdateOscLayoutTVC)(void);
@property (nonatomic, assign) NSMutableArray *currentOSCButtonLayers;
@property (nonatomic, assign) CGRect layoutViewBounds;
@property (weak, nonatomic) IBOutlet UINavigationBar *profileTableViewNavigationBar;

@end

NS_ASSUME_NONNULL_END
