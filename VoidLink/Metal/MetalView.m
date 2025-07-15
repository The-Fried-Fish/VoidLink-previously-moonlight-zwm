// This is based on the following Apple example:
// https://developer.apple.com/documentation/metal/achieving-smooth-frame-rates-with-a-metal-display-link?language=objc
// https://developer.apple.com/wwdc23/10123/

#import "MetalView.h"
#import "MetalConfig.h"

@implementation MetalView {
    // The secondary thread containing the render loop.
    NSThread *_renderThread;

    // The flag to indicate that rendering needs to cease on the main thread.
    BOOL _continueRunLoop;
    dispatch_semaphore_t _renderThreadSemaphore;
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
#if TARGET_OS_OSX
    self.wantsLayer = YES;

    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
#endif

    _metalLayer = (CAMetalLayer *)self.layer;

    self.layer.delegate = self;
    _renderThreadSemaphore = dispatch_semaphore_create(0);
}

#if TARGET_OS_IOS || TARGET_OS_TV
+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (void)didMoveToWindow {
    [self movedToWindow];
}
#else
- (CALayer *)makeBackingLayer {
    return [CAMetalLayer layer];
}

- (void)viewDidMoveToWindow {
    [self movedToWindow];
}
#endif  // END TARGET_OS_IOS || TARGET_OS_TV

- (void)startRenderThread {
    @synchronized(self) {
        // Don't start a new thread if one is already running
        if (_renderThread) {
            return;
        }

        _continueRunLoop = YES;
        _renderThread = [[NSThread alloc] initWithTarget:self selector:@selector(runThread) object:nil];
        _renderThread.qualityOfService = NSQualityOfServiceUserInteractive;
        [_renderThread start];
    }
}

- (void)movedToWindow {
    if (self.window) {
        // The view was added to a window, so start rendering.
        [self resume];
        
        // Notify the delegate of the drawable's size.
        CGSize defaultDrawableSize = self.bounds.size;
        defaultDrawableSize.width *= self.layer.contentsScale;
        defaultDrawableSize.height *= self.layer.contentsScale;
        [self.delegate drawableResize:defaultDrawableSize];
    } else {
        // The view was removed from a window, so stop rendering.
        [self pause];
    }
}

- (void)pause {
    // Pausing is implemented by simply stopping the render thread.
    [self stop];
}

- (void)resume {
    // Resuming is implemented by starting a new render thread.
    [self startRenderThread];
}

- (void)runThread {
    // The system sets the '_continueRunLoop' ivar outside this thread, so it needs to synchronize. Create a
    // 'continueRunLoop' local var that the system can set from the _continueRunLoop ivar in a @synchronized block.
    BOOL continueRunLoop = YES;

    // Begin the run loop.
    while (continueRunLoop) {
        @autoreleasepool {
            [_delegate waitToRenderTo:_metalLayer];

            @synchronized(self) {
                continueRunLoop = _continueRunLoop;
            }
            if (!continueRunLoop) {
                break;
            }

            [_delegate renderTo:_metalLayer];

            @synchronized(self) {
                continueRunLoop = _continueRunLoop;
            }
        }
    }
    dispatch_semaphore_signal(self->_renderThreadSemaphore);
}

#pragma mark - Resizing

#if AUTOMATICALLY_RESIZE

// Override all methods that indicate the view's size has changed.

#if TARGET_OS_IOS || TARGET_OS_TV
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
#else
- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self resizeDrawable:self.window.screen.backingScaleFactor];
}

- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    [self resizeDrawable:self.window.screen.backingScaleFactor];
}

- (void)setBoundsSize:(NSSize)size {
    [super setBoundsSize:size];
    [self resizeDrawable:self.window.screen.backingScaleFactor];
}
#endif

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

- (void)stop {
    @synchronized(self) {
        // If already stopping, do nothing.
        if (!_continueRunLoop) {
            return;
        }
        _continueRunLoop = NO;
    }

    if (_renderThread && _renderThread != [NSThread currentThread]) {
        // Wait for the render thread to finish its loop and signal the semaphore.
        // We use a 1-second timeout to prevent the app from hanging indefinitely
        // if the thread gets stuck for some reason.
        long timeoutResult = dispatch_semaphore_wait(_renderThreadSemaphore, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC));
        if (timeoutResult != 0) {
            Log(LOG_E, @"MetalView render thread failed to stop gracefully within 1 second.");
        }
    }
    
    _renderThread = nil;
}
@end
