// This is based on the following Apple example:
// https://developer.apple.com/documentation/metal/achieving-smooth-frame-rates-with-a-metal-display-link?language=objc
// https://developer.apple.com/wwdc23/10123/

#import "MetalView.h"
#import "MetalConfig.h"

@implementation MetalView {
    // The secondary thread containing the render loop.
    NSThread *_renderThread;
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
}

- (void)shutdown {
    if (_renderThread) {
        [_renderThread cancel];
        // wait for thread to exist
        while (!_renderThread.isFinished) {
            Log(LOG_I, @"XXX MetalView waiting on renderThread to finish");
            usleep(100);
        }
    }
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

- (void)movedToWindow {
    if (!self.window) {
        return;

        // We have been removed
        if (_renderThread) {
            [_renderThread cancel];
            // wait for thread to exist
            while (!_renderThread.isFinished) {
                Log(LOG_I, @"XXX MetalView waiting on renderThread to finish");
                usleep(100);
            }
        }
        return;
    }

    // Render on a new thread
    _renderThread = [[NSThread alloc] initWithBlock:^{
        while (![NSThread currentThread].isCancelled) {
            @autoreleasepool {
                [self.delegate waitToRenderTo:self.metalLayer];
                [self.delegate renderTo:self.metalLayer];
            }
        }
        Log(LOG_I, @"XXX Metal renderThread shutting down");
    }];
    _renderThread.name = @"MetalVideoRenderer";
    _renderThread.qualityOfService = NSQualityOfServiceUserInteractive;
    [_renderThread start];

    // Perform any actions that need to know the size and scale of the drawable. When UIKit calls
    // didMoveToWindow after the view initialization, this is the first opportunity to notify
    // components of the drawable's size.
#if AUTOMATICALLY_RESIZE
#if TARGET_OS_IOS || TARGET_OS_TV
    [self resizeDrawable:self.window.screen.nativeScale];
#else
    [self resizeDrawable:self.window.screen.backingScaleFactor];
#endif
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

@end
