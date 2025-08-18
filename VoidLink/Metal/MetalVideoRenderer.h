//
//  MetalVideoRenderer.h
//
//  Created by Andy Grundman.
//  Ported to VoidLink by Acaki.
//  Copyright (c) 2025 Moonlight Stream. All rights reserved.
//

#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>
#import "ConnectionCallbacks.h"
#import "Frame.h"
#import "Plot.h"

@interface MetalVideoRenderer : NSObject

@property (atomic) CFTimeInterval averageGPUTime;
@property (nonatomic) NSUInteger sampleCount;
@property (nonatomic) MTLPixelFormat colorPixelFormat;
@property (nonatomic) CFTimeInterval lastPresented;
@property (nonatomic) id<CAMetalDrawable> _Nullable nextDrawable;
@property (atomic) BOOL isStopping;

// iOS 15.0 and below frame timing properties
@property (nonatomic) BOOL useLegacyFrameTiming;
@property (nonatomic) CFTimeInterval lastDisplayLinkTime;
@property (nonatomic) CFTimeInterval displayLinkFrametime;

- (nonnull instancetype)initWithMetalDevice:(nonnull id<MTLDevice>)device drawablePixelFormat:(MTLPixelFormat)drawablePixelFormat framerate:(float)framerate;
- (void)renderFrame:(nonnull Frame *)frame toLayer:(nonnull CAMetalLayer *)layer API_AVAILABLE(ios(13.0));
- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer API_AVAILABLE(ios(13.0));
- (void)drawableResize:(CGSize)drawableSize;
- (void)shutdown;

// iOS 15.0 and below legacy timing support
- (void)updateLegacyFrameTiming:(CFTimeInterval)displayLinkTimestamp;
- (void)resetFrameTiming;

+ (NSString *_Nullable)currentColorSpace;

@end
