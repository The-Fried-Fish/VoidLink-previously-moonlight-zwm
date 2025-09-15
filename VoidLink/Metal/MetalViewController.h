//
//  MetalViewController.h
//
//  Created by Andy Grundman.
//  Ported to VoidLink by Acaki.
//  Copyright (c) 2025 Moonlight Stream. All rights reserved.
//

#import <Metal/Metal.h>
#import <UIKit/UIKit.h>
#import "FrameQueue.h"
#import "ImGuiRenderer.h"
#import "MetalVideoRenderer.h"
#import "MetalView.h"
#import "TemporarySettings.h"

@interface MetalViewController : UIViewController <MetalViewDelegate>

@property (nonatomic) CGRect bounds;

- (nonnull instancetype)initWithFrame:(CGRect)bounds framerate:(float)framerate settings:(TemporarySettings* _Nonnull )settings metricsHandler:(MetricsHandler _Nonnull)metricsHandler;


- (void)pauseRendering;
- (void)resumeRendering;

@end
