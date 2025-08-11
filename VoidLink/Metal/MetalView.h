//
//  MetalView.h
//
//  Created by Andy Grundman.
//  Ported to VoidLink by Acaki.
//  Copyright (c) 2025 Moonlight Stream. All rights reserved.
//

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalDisplayLink.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>
#import "MetalConfig.h"

// The protocol to provide resize and redraw callbacks to a delegate.
@protocol MetalViewDelegate <NSObject>

- (void)drawableResize:(CGSize)size;
- (void)renderWithDrawable:(nonnull id<CAMetalDrawable>)drawable toLayer:(nonnull CAMetalLayer *)layer API_AVAILABLE(ios(17.0));
- (void)renderWithDrawable:(nonnull id<CAMetalDrawable>)drawable toLayer:(nonnull CAMetalLayer *)layer targetPresentationTimestamp:(CFTimeInterval)targetPresentationTimestamp API_AVAILABLE(ios(17.0));
- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer;

@end

// The Metal game view base class.
@interface MetalView : UIView <CALayerDelegate, CAMetalDisplayLinkDelegate>

@property (nonatomic, nonnull, readonly) CAMetalLayer *metalLayer;
@property (nonatomic, nullable) id<MetalViewDelegate> delegate;
@property (nonatomic) float framerate;

- (void)initCommon;
- (void)shutdown;
#if AUTOMATICALLY_RESIZE
- (void)resizeDrawable:(CGFloat)scaleFactor;
#endif

@end
