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

- (nonnull instancetype)initWithMetalDevice:(nonnull id<MTLDevice>)device drawablePixelFormat:(MTLPixelFormat)drawablePixelFormat framerate:(float)framerate;
- (void)renderFrame:(nonnull Frame *)frame withDrawable:(nonnull id<CAMetalDrawable>)drawable API_AVAILABLE(ios(17.0));
- (void)renderFrame:(nonnull Frame *)frame withDrawable:(nonnull id<CAMetalDrawable>)drawable targetPresentationTimestamp:(CFTimeInterval)targetPresentationTimestamp API_AVAILABLE(ios(17.0));
- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer;
- (void)drawableResize:(CGSize)drawableSize;
- (void)shutdown;

+ (NSString *_Nullable)currentColorSpace;

@end
