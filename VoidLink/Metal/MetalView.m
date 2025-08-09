// This is based on the following Apple example
// https://developer.apple.com/documentation/metal/achieving-smooth-frame-rates-with-a-metal-display-link?language=objc
// https://developer.apple.com/wwdc23/10123/

#import "MetalView.h"
#import "MetalConfig.h"
#import <QuartzCore/CAMetalDisplayLink.h>

@implementation MetalView {
    // The secondary thread containing the render loop.
    NSThread *_renderThread;
    // Metal display link for vsync synchronization (iOS 17+)
    CAMetalDisplayLink *_metalDisplayLink API_AVAILABLE(ios(17.0));
}

#pragma mark - Initialization and Setup.

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initCommon];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initCommon];
    }
    return self;
}

- (void)initCommon {
    _metalLayer = (CAMetalLayer *)self.layer;
    self.layer.delegate = self;
}

- (void)setFramerate:(float)framerate {
    _framerate = framerate;
    
    if (@available(iOS 17.0, *)) {
        if (_metalDisplayLink) {
            _metalDisplayLink.preferredFrameRateRange = CAFrameRateRangeMake(framerate, framerate, framerate);
        }
    }
}

- (void)shutdown {
    // First cancel the thread to stop the run loop
    if (_renderThread) {
        Log(LOG_I, @"[MetalView] sending renderThread a cancel message");
        [_renderThread cancel];
        
        // Invalidate metal display link to stop callbacks
        if (@available(iOS 17.0, *)) {
            if (_metalDisplayLink) {
                Log(LOG_I, @"[MetalView] invalidating metal display link");
                [_metalDisplayLink invalidate];
                _metalDisplayLink = nil;
            }
        }
        
        // Now wait for thread to finish
        Log(LOG_I, @"[MetalView] waiting on renderThread to finish");
        NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0]; // 2 second timeout
        while (!_renderThread.isFinished && [timeout timeIntervalSinceNow] > 0) {
            usleep(1000);
        }
        
        if (_renderThread.isFinished) {
            Log(LOG_I, @"[MetalView] renderThread has finished");
        } else {
            Log(LOG_E, @"[MetalView] renderThread failed to finish in time");
        }
        _renderThread = nil;
    }
}

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (void)didMoveToWindow {
    [self movedToWindow];
}

// CAMetalDisplayLinkDelegate method (iOS 17+)
- (void)metalDisplayLink:(CAMetalDisplayLink *)link needsUpdate:(CAMetalDisplayLinkUpdate *)update API_AVAILABLE(ios(17.0)) {
    // Skip rendering if we're shutting down
    if ([NSThread currentThread].isCancelled) {
        return;
    }
    @autoreleasepool {
        [self.delegate waitToRenderTo:self.metalLayer];
        
        // Get the drawable from the update object
        id<CAMetalDrawable> drawable = update.drawable;
        if (drawable) {
            // Pass timing information to the renderer
            if ([self.delegate respondsToSelector:@selector(renderWithDrawable:toLayer:targetPresentationTimestamp:)]) {
                [self.delegate renderWithDrawable:drawable toLayer:self.metalLayer targetPresentationTimestamp:update.targetPresentationTimestamp];
            } else {
                [self.delegate renderWithDrawable:drawable toLayer:self.metalLayer];
            }
        }
    }
}

- (void)movedToWindow {
    if (!self.window) {
        Log(LOG_I, @"[MetalView] movedToWindow(nil): shutting down...");
        [self shutdown];
        return;
    }

    // Create CAMetalDisplayLink for vsync-synchronized rendering (iOS 17+ only)
    if (@available(iOS 17.0, *)) {
        _metalDisplayLink = [[CAMetalDisplayLink alloc] initWithMetalLayer:_metalLayer];
        _metalDisplayLink.delegate = self;
        _metalDisplayLink.preferredFrameRateRange = CAFrameRateRangeMake(_framerate, _framerate, _framerate);
        Log(LOG_I, @"[MetalView] Using CAMetalDisplayLink for optimal Metal rendering");
    }
    
    // Start the display link on a background thread
    _renderThread = [[NSThread alloc] initWithBlock:^{
        // Add metal display link to this thread's run loop
        if (@available(iOS 17.0, *)) {
            [self->_metalDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        }
        
        // Keep the run loop alive, checking for cancellation regularly
        while (![NSThread currentThread].isCancelled && self->_metalDisplayLink) {
            @autoreleasepool {
                // Run the run loop for a short time to allow checking cancellation
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            }
        }
        
        // Remove from run loop if still valid
        if (@available(iOS 17.0, *)) {
            if (self->_metalDisplayLink) {
                [self->_metalDisplayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            }
        }
        Log(LOG_I, @"[MetalView] renderThread is exiting");
    }];
    _renderThread.name = @"MetalVideoRenderer";
    _renderThread.qualityOfService = NSQualityOfServiceUserInteractive;
    [_renderThread start];
    Log(LOG_I, @"[MetalView] started renderThread with CAMetalDisplayLink at %f fps", _framerate);

    // Perform any actions that need to know the size and scale of the drawable. When UIKit calls
    // didMoveToWindow after the view initialization, this is the first opportunity to notify
    // components of the drawable's size.
#if AUTOMATICALLY_RESIZE
    [self resizeDrawable:self.window.screen.nativeScale];
#else
    // Notify the delegate of the default drawable size when the system can calculate it.
    CGSize defaultDrawableSize = self.bounds.size;
    defaultDrawableSize.width *= self.layer.contentsScale;
    defaultDrawableSize.height *= self.layer.contentsScale;
    [self.delegate drawableResize:defaultDrawableSize];
#endif
}

#pragma mark - Resizing

#if AUTOMATICALLY_RESIZE

// Override all methods that indicate the view's size has changed.

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor {
    [super setContentScaleFactor:contentScaleFactor];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)resizeDrawable:(CGFloat)scaleFactor {
    CGSize newSize = self.bounds.size;
    newSize.width *= scaleFactor;
    newSize.height *= scaleFactor;

    if (newSize.width <= 0 || newSize.width <= 0) {
        return;
    }

    // The system calls all AppKit and UIKit calls that notify of a resize on the main thread. Use
    // a synchronized block to ensure that resize notifications on the delegate are atomic.
    @synchronized(_metalLayer) {
        if (newSize.width == _metalLayer.drawableSize.width && newSize.height == _metalLayer.drawableSize.height) {
            return;
        }

        Log(LOG_I, @"[MetalView] resizeDrawable: %.2f x %.2f", newSize.width, newSize.height);

        _metalLayer.drawableSize = newSize;

        [_delegate drawableResize:newSize];
    }
}
#endif  // END AUTOMATICALLY_RESIZE

@end
