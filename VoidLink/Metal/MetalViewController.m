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
    CADisplayLink *_displayLink;
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

    // Determine supported pixel format before initializing renderer
    // Use TARGET_OS_SIMULATOR to detect simulator environment
    MTLPixelFormat pixelFormat;
#if TARGET_OS_SIMULATOR
    // iOS Simulator doesn't support BGR10A2Unorm
    pixelFormat = MTLPixelFormatBGRA8Unorm;
    Log(LOG_W, @"Running on iOS Simulator, using BGRA8Unorm pixel format");
#else
    // On real devices, check if we should enable HDR
    if (_enableHdr) {
        pixelFormat = MTLPixelFormatBGR10A2Unorm;
        Log(LOG_I, @"HDR enabled, using BGR10A2Unorm pixel format");
    } else {
        pixelFormat = MTLPixelFormatBGRA8Unorm;
        Log(LOG_I, @"HDR disabled, using BGRA8Unorm pixel format");
    }
#endif

    // Initialize the renderer.
    MetalVideoRenderer *renderer = [[MetalVideoRenderer alloc] initWithMetalDevice:device
                                                               drawablePixelFormat:pixelFormat
                                                                         framerate:self->_framerate];
    if (!renderer) {
        Log(LOG_E, @"The renderer couldn't be initialized.");
        return;
    }
    self->_renderer = renderer;
    Log(LOG_I, @"[MetalViewController] viewDidLoad, created renderer: %@", renderer);

    // Initialize the renderer-dependent view properties.
    view.metalLayer.pixelFormat = renderer.colorPixelFormat;
    view.metalLayer.maximumDrawableCount = 3;

    // We need a displaylink timer for iOS 15.0 and below to provide accurate frame timing,
    // or just as a no-op for iOS 16+ to prevent iOS from dropping to 60fps
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkHandler:)];
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        // iOS 16+: Use CAFrameRateRange, displaylink is just a no-op
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(_framerate, _framerate, _framerate);
        Log(LOG_I, @"MetalViewController: DisplayLink using iOS 16+ CAFrameRateRange");
    } else if (@available(iOS 15.0, tvOS 15.0, *)) {
        // iOS 15.0: Use legacy preferredFramesPerSecond to avoid CAFrameRateRange bugs
        _displayLink.preferredFramesPerSecond = _framerate;
        Log(LOG_I, @"MetalViewController: DisplayLink using iOS 15.0 legacy preferredFramesPerSecond");
    } else {
        // iOS 14 and below
        _displayLink.preferredFramesPerSecond = _framerate;
    }
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)displayLinkHandler:(CADisplayLink *)link {
    // For iOS 16+: This is just a no-op to fool iOS into keeping us running at the desired framerate
    // For iOS 15.0 and below: Update renderer with accurate frame timing to fix negative framerates
    if (@available(iOS 16.0, *)) {
        // No-op for iOS 16+, Metal's presentedTime is reliable
    } else {
        // iOS 15.0 and below: Use DisplayLink timing since Metal's presentedTime is unreliable
        if (_renderer) {
            [_renderer updateLegacyFrameTiming:link.timestamp];
        }
    }
}

- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer {
    // Renderer obtains a nextDrawable, waiting if necessary
    if (@available(iOS 13.0, *)) {
        [_renderer waitToRenderTo:layer];
    }

    // If we don't have a frame yet, wait on that too
    [_frameQueue waitForEnqueue];
}

/// Draw frame (used by manual loop)
- (void)renderTo:(nonnull CAMetalLayer *)layer {
    if (!_renderer.isStopping) {
        CFTimeInterval timeout = (1.0f / _framerate) - _renderer.averageGPUTime;
        Frame *frame = [_frameQueue dequeueWithTimeout:timeout];
        if (frame) {
            if (@available(iOS 13.0, *)) {
                [_renderer renderFrame:frame toLayer:layer];
            }
        }
    }
}

- (void)drawableResize:(CGSize)size {
    [_renderer drawableResize:size];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    Log(LOG_I, @"[MetalViewController] viewDidDisappear");

    if (_displayLink) {
        [_displayLink invalidate];
    }

    [_renderer shutdown];
    _renderer = nil;
}

#if TARGET_OS_IOS
// Hides the Home indicator button automatically.
- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}
#endif

- (void)resetFrameTiming {
    // Reset the renderer's frame timing state for iOS 15.0 and below compatibility
    if (_renderer) {
        [_renderer resetFrameTiming];
        Log(LOG_I, @"MetalViewController: Reset frame timing called");
    }
    
    // Reset DisplayLink timing for iOS 15.0 and below
    if (@available(iOS 16.0, *)) {
        // No additional DisplayLink reset needed for iOS 16+
    } else {
        // For iOS 15.0 and below, pause and resume DisplayLink to re-engage timing
        if (_displayLink) {
            _displayLink.paused = YES;
            
            // Re-apply frame rate (avoid CAFrameRateRange on iOS 15.0)
            if (@available(iOS 15.0, *)) {
                _displayLink.preferredFramesPerSecond = _framerate;
            } else {
                _displayLink.preferredFramesPerSecond = _framerate;
            }
            
            _displayLink.paused = NO;
            Log(LOG_I, @"MetalViewController: Reset DisplayLink timing for iOS 15.0 and below");
        }
    }
}

@end
