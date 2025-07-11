//
//  MetalView.h
//  VoidLink
//
//  Created by Mason Chen on 2025/7/11.
//  Copyright © 2025 Moonlight Game Streaming Project. All rights reserved.
//


#import <Metal/Metal.h>
#import <QuartzCore/CAMetalDisplayLink.h>
#import <QuartzCore/CAMetalLayer.h>
#import "MetalConfig.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#define PlatformView UIView
#else
#import <AppKit/AppKit.h>
#define PlatformView NSView
#endif

// The protocol to provide resize and redraw callbacks to a delegate.
@protocol MetalViewDelegate <NSObject>

- (void)drawableResize:(CGSize)size;
- (void)renderTo:(nonnull CAMetalLayer *)layer;
- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer;

@end

// The Metal game view base class.
@interface MetalView : PlatformView <CALayerDelegate>

@property (nonatomic, nonnull, readonly) CAMetalLayer *metalLayer;
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic, nullable) id<MetalViewDelegate> delegate;
@property (nonatomic) float framerate;

- (void)initCommon;
#if AUTOMATICALLY_RESIZE
- (void)resizeDrawable:(CGFloat)scaleFactor;
#endif

@end
