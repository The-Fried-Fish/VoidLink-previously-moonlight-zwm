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
#import <CoreMedia/CoreMedia.h>
#import "DiscoveryManager.h"
#import "PairManager.h"
#import "StreamConfiguration.h"
#import "AppAssetManager.h"
#import "SWRevealViewController.h"

@class SettingsViewController;
@class TemporaryApp;
@class HostCollectionViewController;

@interface MainFrameViewController : UICollectionViewController <DiscoveryCallback, PairCallback, AppAssetCallback, NSURLConnectionDelegate, SWRevealViewControllerDelegate, UITextFieldDelegate>


@property (nonatomic, strong) IBOutlet UIBarButtonItem *settingsButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *profilesButton;
@property (weak, nonatomic) SettingsViewController *settingsViewController;
@property (nonatomic, strong) HostCollectionViewController *hostCollectionVC;
@property (nonatomic, strong, readonly) NSArray<TemporaryApp *> *sortedAppList;

@property (nonatomic, assign) bool settingsExpandedInStreamView;
@property (nonatomic, readonly) bool settingsViewExpanded;

#if !TARGET_OS_TV
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationItem;
#endif

- (void)expandSettingsView;
- (void)closeSettingViewAnimated:(BOOL)anaimated;
- (void)reloadStreamConfig;
- (bool)isIPhonePortrait;
- (bool)isInAppView;
- (bool)isStreaming;
- (TemporaryApp*)findRunningApp:(TemporaryHost*)host;
- (void)quitApp:(TemporaryApp* )app;
- (void)quitLaunchedApp;
- (void)launchApp:(TemporaryApp *)app;
- (void)quitRunningAppAndStart:(TemporaryApp *)app;
- (NSInteger)requestForBitrate:(NSInteger)bitrateKbps;

- (void)fillResolutionTable:(CMVideoDimensions *)resolutionTable externalDisplayMode:(NSInteger)externalDisplayMode;
- (void)setNeedsUpdateAllowedOrientation;

@end
