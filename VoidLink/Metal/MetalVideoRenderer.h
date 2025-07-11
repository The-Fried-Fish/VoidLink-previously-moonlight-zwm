//
//  MetalVideoRenderer.h
//  VoidLink
//
//  Created by Mason Chen on 2025/7/11.
//  Copyright © 2025 Moonlight Game Streaming Project. All rights reserved.
//


#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/QuartzCore.h>
#import "ConnectionCallbacks.h"
#import "Frame.h"
#import "Plot.h"

@interface MetalVideoRenderer : NSObject

@property (atomic) CFTimeInterval averageGPUTime;
@property (nonatomic) NSUInteger sampleCount;
@property (nonatomic) MTLPixelFormat colorPixelFormat;
@property (nonatomic, nonnull) CGColorSpaceRef colorspace;
@property (nonatomic) id<CAMetalDrawable> _Nullable nextDrawable;

- (nonnull instancetype)initWithMetalDevice:(nonnull id<MTLDevice>)device
                        drawablePixelFormat:(MTLPixelFormat)drawablePixelFormat
                                  framerate:(float)framerate;
- (void)renderFrame:(nonnull Frame *)frame toLayer:(nonnull CAMetalLayer *)layer;
- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer;
- (void)drawableResize:(CGSize)drawableSize;
- (void)plotFrametime:(CFTimeInterval)presentedTime;

@end
