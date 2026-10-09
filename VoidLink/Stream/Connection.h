//
//  Connection.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2025.9
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//


#import "ConnectionCallbacks.h"
#import "VideoDecoderRenderer.h"
#import "StreamConfiguration.h"
#import "BandwidthTracker.h"
#import "Plot.h"

#define CONN_TEST_SERVER "www.baidu.com"

@interface Connection : NSOperation <NSStreamDelegate>
@property (class, nonatomic, assign) bool muteInBackground;
@property (class, nonatomic, assign) bool useSystemAudioEngine;
@property (class, nonatomic, assign) bool useDualSenseHapticsIrV2;

-(id) initWithConfig:(StreamConfiguration*)config renderer:(VideoDecoderRenderer*)myRenderer connectionCallbacks:(id<ConnectionCallbacks>)callbacks;
-(void) terminate;
-(void) main;
-(BandwidthTracker *) getBwTracker;
-(BOOL) getVideoStats:(video_stats_t*)stats;
-(NSString*) getActiveCodecName;

+ (void)setVolume:(float)newVolume;
+ (void)resetSysAudioPlayback;
+ (void)logSysAudioPlaybackLatency;
#if TARGET_OS_TV
+ (BOOL)resumeSysAudioPlaybackBeforeMicWithError:(NSError **)error;
#endif

+ (bool)useDualSenseAuthoredPCM;
+ (void)setuseDualSenseAuthoredPCM:(bool)use;


@end
