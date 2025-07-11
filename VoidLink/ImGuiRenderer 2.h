//
//  ImGuiRenderer 2.h
//  VoidLink
//
//  Created by Mason Chen on 2025/7/11.
//  Copyright © 2025 Moonlight Game Streaming Project. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

#import "FloatBuffer.h"
#import "Plot.h"

typedef void (^MetricsHandler)(int plotId, CFTimeInterval value);

@interface ImGuiRenderer : UIViewController
@end

@interface ImGuiRenderer () <MTKViewDelegate>
@property (nonatomic) CGRect bounds;
@property (nonatomic, readonly) MTKView * _Nonnull mtkView;
@property (nonatomic, strong) id <MTLDevice> _Nonnull device;
@property (nonatomic, strong) id <MTLCommandQueue> _Nonnull commandQueue;
@property (nonatomic) struct PlotDef * _Nonnull plots;
@property (nonatomic) FloatBuffer * _Nonnull frametimes;
@property (nonatomic) BOOL enableGraphs;
@property (nonatomic) float graphOpacity;
@property (nonatomic) BOOL imguiRunning;
@property (nonatomic) MetricsHandler _Nonnull metricsHandler;

-(nonnull instancetype) initWithFrame:(CGRect)bounds
                            streamFps:(int)streamFps
                         enableGraphs:(BOOL)enableGraphs
                         graphOpacity:(int)graphOpacity;
-(void) start;
-(void) show;
-(void) hide;
-(void) stop;
-(void) observeFloat:(int)plotId value:(CFTimeInterval)value;
-(void) observeFloatReturnMetrics:(int)plotId value:(CFTimeInterval)value plotMetrics:(PlotMetrics * _Nullable)plotMetrics;
@end
