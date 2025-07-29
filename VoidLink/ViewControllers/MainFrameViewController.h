//
//  MainFrameViewController.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.7.7
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DiscoveryManager.h"
#import "PairManager.h"
#import "StreamConfiguration.h"
#import "HostCardView.h"
#import "UIAppView.h"
#import "AppAssetManager.h"
#import "SWRevealViewController.h"
#import "HostCollectionViewController.h"


@interface MainFrameViewController : UICollectionViewController <DiscoveryCallback, PairCallback, AppCallback, AppAssetCallback, NSURLConnectionDelegate, SWRevealViewControllerDelegate, HostCardActionDelegate, AppViewUpdateLoopDelegate>

@property (nonatomic, strong) IBOutlet UIBarButtonItem *settingsButton;
#if !TARGET_OS_TV
@property (nonatomic, assign) bool settingsExpandedInStreamView;
@property (nonatomic, strong) HostCollectionViewController *hostCollectionVC;
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationItem;


-(void)expandSettingsView;
- (void)closeSettingViewAnimated:(BOOL)anaimated;
-(void)reloadStreamConfig;
-(bool)isIPhonePortrait;
#endif

@end
