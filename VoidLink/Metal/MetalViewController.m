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
    view.metalLayer.maximumDrawableCount = 3;

    self->_renderer = renderer;
}

- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer {
    // Renderer obtains a nextDrawable, waiting if necessary
    [_renderer waitToRenderTo:layer];

    // If we don't have a frame yet, wait on that too
    [_frameQueue waitForEnqueue];
}

/// Draw frame (used by manual loop)
- (void)renderTo:(nonnull CAMetalLayer *)layer {
    if (!_renderer.isStopping) {
        CFTimeInterval timeout = (1.0f / _framerate) - _renderer.averageGPUTime;
        Frame *frame = [_frameQueue dequeueWithTimeout:timeout];
        if (frame) {
            [_renderer renderFrame:frame toLayer:layer];
        }
    }
}

- (void)drawableResize:(CGSize)size {
    [_renderer drawableResize:size];
}

- (void)shutdown {
    [_renderer shutdown];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    Log(LOG_I, @"XXX MetalViewController viewDidDisappear");

    [_metalView shutdown];
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

@end
