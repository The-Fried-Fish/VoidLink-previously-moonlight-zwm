//
//  MetalViewController.m
//
//  Created by Andy Grundman.
//  Ported to VoidLink by Acaki.
//  Copyright (c) 2025 Moonlight Stream. All rights reserved.
//

#import "MetalViewController.h"
#import "FrameQueue.h"
#import "ImGuiRenderer.h"
#import "MetalVideoRenderer.h"

@implementation MetalViewController {
    FrameQueue *_frameQueue;
    float _framerate;
    BOOL _enableHdr;
    MetalView *_metalView;
    MetalVideoRenderer *_renderer;
    MetricsHandler _metricsHandler;
}

- (nonnull instancetype)initWithFrame:(CGRect)bounds framerate:(float)framerate enableHdr:(BOOL)enableHdr metricsHandler:(MetricsHandler)metricsHandler {
    self = [super init];
    if (self) {
        _bounds = bounds;
        _frameQueue = [FrameQueue sharedInstance];
        _framerate = framerate;
        _enableHdr = enableHdr;
        _metricsHandler = metricsHandler;
    }
    return self;
}

- (void)loadView {
    self.view = [[MetalView alloc] initWithFrame:_bounds];
    Log(LOG_I, @"[MetalViewController] created MetalView %@", (MetalView *)self.view);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    __block MetalView *view = (MetalView *)self.view;
    if (!view) {
        Log(LOG_E, @"The view attached to MetalViewController isn't a MetalView.");
        return;
    }
    _metalView = view;
    _metalView.delegate = self;
    _metalView.framerate = _framerate;

    // Select the device to render with.
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        Log(LOG_E, @"Metal isn't supported on this device.");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
        return;
    }
    view.metalLayer.device = device;

    // Initialize the renderer.
    MetalVideoRenderer *renderer = [[MetalVideoRenderer alloc] initWithMetalDevice:device
                                                               drawablePixelFormat:MTLPixelFormatBGR10A2Unorm
                                                                         framerate:self->_framerate
                                                                        hdrEnabled:self->_enableHdr];
    if (!renderer) {
        Log(LOG_E, @"The renderer couldn't be initialized.");
        return;
    }
    self->_renderer = renderer;
    Log(LOG_I, @"[MetalViewController] viewDidLoad, created renderer: %@", renderer);

    // Initialize the renderer-dependent view properties.
    view.metalLayer.pixelFormat = renderer.colorPixelFormat;
    view.metalLayer.maximumDrawableCount = 3;
}

- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer {
    // Skip waiting when renderer is paused
    if (_renderer.isStopping) {
        return;
    }

    // Renderer obtains a nextDrawable, waiting if necessary
    if (@available(iOS 13.0, *)) {
        [_renderer waitToRenderTo:layer];
    }

    // If we don't have a frame yet, wait on that too
    [_frameQueue waitForEnqueue];
}

- (void)renderWithDrawable:(nonnull id<CAMetalDrawable>)drawable toLayer:(nonnull CAMetalLayer *)layer API_AVAILABLE(ios(17.0)) {
    CFTimeInterval timeout = (1.0f / _framerate) - _renderer.averageGPUTime;
    Frame *frame = [_frameQueue dequeueWithTimeout:timeout];
    if (!_renderer.isStopping) {
        // Only render if not paused
        if (frame) {
            [_renderer renderFrame:frame withDrawable:drawable];
        }
    }
}

- (void)renderWithDrawable:(nonnull id<CAMetalDrawable>)drawable toLayer:(nonnull CAMetalLayer *)layer targetPresentationTimestamp:(CFTimeInterval)targetPresentationTimestamp API_AVAILABLE(ios(17.0)) {
    if (!_renderer.isStopping) {
        CFTimeInterval timeout = (1.0f / _framerate) - _renderer.averageGPUTime;
        Frame *frame = [_frameQueue dequeueWithTimeout:timeout];
        if (frame) {
            [_renderer renderFrame:frame withDrawable:drawable targetPresentationTimestamp:targetPresentationTimestamp];
        }
    } else {
        // When paused, we still dequeue frames to prevent accumulation
        // but don't render them. Also sleep a bit to reduce CPU usage
        usleep(100000);
    }
}

- (void)drawableResize:(CGSize)size {
    [_renderer drawableResize:size];
}

- (void)pauseRendering {
    if (_renderer) {
        _renderer.isStopping = YES;
    }
    Log(LOG_I, @"[MetalViewController] Rendering paused");
}

- (void)resumeRendering {
    if (_renderer) {
        _renderer.isStopping = NO;
    }
    Log(LOG_I, @"[MetalViewController] Rendering resumed");
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    Log(LOG_I, @"[MetalViewController] viewDidDisappear");

    // Shutdown the renderer first
    if (_renderer) {
        [_renderer shutdown];
        _renderer = nil;
    }
    
    // Then shutdown the view's display link
    if (_metalView) {
        _metalView.delegate = nil;
        [_metalView shutdown];
        _metalView = nil;
    }
}

#if TARGET_OS_IOS
// Hides the Home indicator button automatically.
- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}
#endif

@end
