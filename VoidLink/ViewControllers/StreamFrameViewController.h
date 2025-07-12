//
//  StreamFrameViewController.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/18/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.26
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "Connection.h"
#import "StreamConfiguration.h"
#import "StreamView.h"
#import "LayoutOnScreenControlsViewController.h"
#import "MainFrameViewController.h"
#import "StreamManager.h"

#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>

#if TARGET_OS_TV
@import GameController;

@interface StreamFrameViewController : GCEventViewController <ConnectionCallbacks, ControllerSupportDelegate, UserInteractionDelegate, UIScrollViewDelegate, AVPictureInPictureControllerDelegate>
#else
@interface StreamFrameViewController : UIViewController <ConnectionCallbacks, ControllerSupportDelegate, UserInteractionDelegate, UIScrollViewDelegate, ToolboxSpecialEntryDelegate, AVPictureInPictureControllerDelegate>

#endif
@property (nonatomic) StreamManager* streamMan;
@property (nonatomic) StreamConfiguration* streamConfig;
@property (nonatomic, strong) AVPictureInPictureController *pipController API_AVAILABLE(ios(9.0));
@property (nonatomic, strong) AVPictureInPictureControllerContentSource *pipContentSource API_AVAILABLE(ios(15.0)); // Needed for iOS 15+ layer-based PiP
@property (nonatomic, assign) MainFrameViewController *mainFrameViewcontroller;


-(void)updatePreferredDisplayMode:(BOOL)streamActive;
-(void)reConfigStreamViewRealtime;
- (void)setUserInteractionEnabledForStreamView:(bool)enabled;
- (bool)shallDisableGyroHotSwitch;

@end
