/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The implementation of the cross-platform game view controller.
*/

#import "MetalViewController.h"
#import "FrameQueue.h"
#import "ImGuiRenderer.h"
#import "MetalVideoRenderer.h"

@implementation MetalViewController {
    /// A queue to initialize the renderer asynchronously from the main thread.
    dispatch_queue_t _dispatch_queue;
    FrameQueue *_frameQueue;
    float _framerate;
    BOOL _enableHdr;
    MetalView *_metalView;
    MetalVideoRenderer *_renderer;
    MetricsHandler _metricsHandler;
    BOOL _stopping;
}

- (nonnull instancetype)initWithFrame:(CGRect)bounds framerate:(float)framerate enableHdr:(BOOL)enableHdr metricsHandler:(MetricsHandler)metricsHandler {
    self = [super init];
    if (self) {
        _bounds = bounds;
        _frameQueue = [FrameQueue sharedInstance];
        _framerate = framerate;
        _enableHdr = enableHdr;
        _metricsHandler = metricsHandler;
        _stopping = NO;
        [_frameQueue clear];
    }
    return self;
}

- (void)loadView {
    self.view = [[MetalView alloc] initWithFrame:_bounds];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    /// A queue to initialize the renderer asynchronously from the main thread.
    _dispatch_queue = dispatch_queue_create("com.moonlight.Metal", DISPATCH_QUEUE_CONCURRENT);

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
        self.view = [[PlatformView alloc] initWithFrame:self.view.frame];
        return;
    }
    view.metalLayer.device = device;

    // Initialize the renderer.
    MetalVideoRenderer *renderer = [[MetalVideoRenderer alloc] initWithMetalDevice:device
                                                               drawablePixelFormat:MTLPixelFormatBGR10A2Unorm
                                                                         framerate:self->_framerate];
    if (!renderer) {
        Log(LOG_E, @"The renderer couldn't be initialized.");
        return;
    }

    // Initialize the renderer-dependent view properties.
    view.metalLayer.pixelFormat = renderer.colorPixelFormat;
    view.metalLayer.colorspace = renderer.colorspace;
    view.metalLayer.maximumDrawableCount = 3;

    self->_renderer = renderer;
}

- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer {
    if (!_stopping) {
        // Renderer obtains a nextDrawable, waiting if necessary
        [_renderer waitToRenderTo:layer];

        // If we don't have a frame yet, wait on that too
        if (!_stopping) {
            [_frameQueue waitForEnqueue];
        }
    }
}

/// Draw frame (used by manual loop)
- (void)renderTo:(nonnull CAMetalLayer *)layer {
    if (!_renderer) {
        return;
    }

    CFTimeInterval timeout = (1.0f / _framerate) - _renderer.averageGPUTime;
    Frame *frame = [_frameQueue dequeueWithTimeout:timeout];
    if (frame) {
        [_renderer renderFrame:frame toLayer:layer];
    }
}

- (void)drawableResize:(CGSize)size {
    [_renderer drawableResize:size];
}

#if TARGET_OS_IOS
/// Hides the Home indicator button automatically.
- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}
#endif

#if TARGET_OS_OSX
/// Makes the view controller the first responder to receive keyboard events.
- (void)viewDidAppear {
    [_metalView.window makeFirstResponder:self];
}

/// Receives the keydown events to avoid system beeps.
///
/// The `GameInputKeyboardMouse` class handles keyboard events.
- (void)keyDown:(NSEvent *)event {
    // Reference the parameter to avoid an unused parameter warning.
    (void)(event);
}

/// Receives the keyup events to avoid system beeps.
///
/// The `GameInputKeyboardMouse` class handles keyboard events.
- (void)keyUp:(NSEvent *)event {
    // Reference the parameter to avoid an unused parameter warning.
    (void)(event);
}
#endif

- (void)stop {
    // 1. Signal that we are stopping to prevent new work from starting.
    _stopping = YES;
    
    // 2. Invalidate the CAMetalLayer by removing its device.
    // This should cause any blocking calls like `nextDrawable` on the render thread to fail
    // and return immediately, breaking the deadlock.
    if (_metalView) {
        _metalView.metalLayer.device = nil;
    }

    // 3. Unblock the render thread from any other potential waiting points.
    if (_renderer) {
        [_renderer stop];
    }
    [_frameQueue stop];

    // 4. Now that the thread is unblocked, wait for it to finish its execution.
    if (_metalView) {
        [_metalView stop];
    }

    // 5. Once the thread has terminated, it's safe to deallocate all resources.
    _renderer = nil;
    _metalView = nil;
}

- (void)pause {
    if (_renderer) {
        // Add this line to discard any stale drawable before pausing the thread.
        // This forces the renderer to get a fresh one on resume.
        [_renderer discardNextDrawable];
    }
    
    if (_metalView) {
        [_metalView pause];
        Log(LOG_I, @"Metal rendering paused.");
    }
}

- (void)resume {
    if (_metalView) {
        [_metalView resume];
        Log(LOG_I, @"Metal rendering resumed.");
    }
}

@end
