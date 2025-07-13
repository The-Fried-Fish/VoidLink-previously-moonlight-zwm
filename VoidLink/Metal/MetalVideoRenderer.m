#import "MetalVideoRenderer.h"
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "ImGuiPlots.h"

#include <Limelight.h>

#define MAX_VIDEO_PLANES 3

struct CscParams {
    vector_float3 matrix[3];
    vector_float3 offsets;
};

struct ParamBuffer {
    struct CscParams cscParams;
};

static const struct CscParams k_CscParams_Bt601Lim = {
    // CSC Matrix
    {{1.1644f, 0.0f, 1.5960f}, {1.1644f, -0.3917f, -0.8129f}, {1.1644f, 2.0172f, 0.0f}},

    // Offsets
    {16.0f / 255.0f, 128.0f / 255.0f, 128.0f / 255.0f},
};
static const struct CscParams k_CscParams_Bt601Full = {
    {
        {1.0f, 0.0f, 1.4020f},
        {1.0f, -0.3441f, -0.7141f},
        {1.0f, 1.7720f, 0.0f},
    },
    {0.0f, 128.0f / 255.0f, 128.0f / 255.0f},
};
static const struct CscParams k_CscParams_Bt709Lim = {
    {
        {1.1644f, 0.0f, 1.7927f},
        {1.1644f, -0.2132f, -0.5329f},
        {1.1644f, 2.1124f, 0.0f},
    },
    {16.0f / 255.0f, 128.0f / 255.0f, 128.0f / 255.0f},
};
static const struct CscParams k_CscParams_Bt709Full = {
    {
        {1.0f, 0.0f, 1.5748f},
        {1.0f, -0.1873f, -0.4681f},
        {1.0f, 1.8556f, 0.0f},
    },
    {0.0f, 128.0f / 255.0f, 128.0f / 255.0f},
};
static const struct CscParams k_CscParams_Bt2020Lim = {
    {
        {1.1644f, 0.0f, 1.6781f},
        {1.1644f, -0.1874f, -0.6505f},
        {1.1644f, 2.1418f, 0.0f},
    },
    {16.0f / 255.0f, 128.0f / 255.0f, 128.0f / 255.0f},
};
static const struct CscParams k_CscParams_Bt2020Full = {
    {
        {1.0f, 0.0f, 1.4746f},
        {1.0f, -0.1646f, -0.5714f},
        {1.0f, 1.8814f, 0.0f},
    },
    {0.0f, 128.0f / 255.0f, 128.0f / 255.0f},
};

struct Vertex {
    vector_float4 position;
    vector_float2 texCoord;
};

static const NSUInteger MaxFramesInFlight = 3;

@implementation MetalVideoRenderer {
    dispatch_queue_t _sq;
    id<MTLDevice> _device;
    float _framerate;
    id<ConnectionCallbacks> _callbacks;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _shaderLibrary;
    id<MTLRenderPipelineState> _videoPipelineState;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    id<MTLTexture> _videoTexture;
    CVMetalTextureCacheRef _textureCache;
    CVMetalTextureRef _cvMetalTextures[MAX_VIDEO_PLANES];

    int _lastColorSpace;
    BOOL _lastFullRange;
    size_t _lastFrameWidth;
    size_t _lastFrameHeight;
    size_t _lastDrawableWidth;
    size_t _lastDrawableHeight;
    id<MTLBuffer> _CscParamsBuffer;
    id<MTLBuffer> _VideoVertexBuffer;
    CFTimeInterval _lastPresented;

    // https://developer.apple.com/documentation/metal/synchronizing-cpu-and-gpu-work?language=objc
    dispatch_semaphore_t _inFlightSemaphore;
}

- (instancetype)initWithMetalDevice:(id<MTLDevice>)device drawablePixelFormat:(MTLPixelFormat)drawablePixelFormat framerate:(float)framerate {
    self = [super init];
    if (self) {
        _sq = dispatch_queue_create("com.moonlight.MetalVideoRenderer",
                                    dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0));
        _averageGPUTime = (1.0f / framerate) / 2;
        _device = device;
        _nextDrawable = nil;
        _colorPixelFormat = MTLPixelFormatBGR10A2Unorm;
        _colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_PQ);
        _framerate = framerate;
        _commandQueue = [_device newCommandQueue];
        _lastColorSpace = -1;
        _lastFullRange = NO;
        _lastPresented = 0;
        _inFlightSemaphore = dispatch_semaphore_create(MaxFramesInFlight);

        CFStringRef keys[1] = {kCVMetalTextureUsage};
        NSUInteger values[1] = {MTLTextureUsageShaderRead};
        CFDictionaryRef cacheAttributes = CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 1, NULL, NULL);
        CVMetalTextureCacheCreate(kCFAllocatorDefault, cacheAttributes, _device, NULL, &_textureCache);
        CFRelease(cacheAttributes);

        _renderPassDescriptor = [MTLRenderPassDescriptor new];
        _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
        _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    }
    return self;
}

- (void)dealloc {
    if (_CscParamsBuffer) {
        _CscParamsBuffer = nil;
    }

}

#if !TARGET_OS_TV
- (void)applyEDRFromFrame:(Frame *)frame toLayer:(CAMetalLayer *)layer {
    CFDictionaryRef ext = [frame getFormatDescExtensions];

    Log(LOG_I, @"ext: %@", ext);

    CFDataRef masteringData = CFDictionaryGetValue(ext, kCMFormatDescriptionExtension_MasteringDisplayColorVolume);
    CFDataRef contentDataRef = CFDictionaryGetValue(ext, kCMFormatDescriptionExtension_ContentLightLevelInfo);

    if (masteringData) {
        Log(LOG_I, @"ext MDCV %@", masteringData);
    }
    if (contentDataRef) {
        Log(LOG_I, @"ext CLLI %@", contentDataRef);
    }

    if (masteringData && CFDataGetLength(masteringData) == 24 && contentDataRef && CFDataGetLength(contentDataRef) == 4) {
        NSData *displayData = (__bridge NSData *)masteringData;
        NSData *contentData = (__bridge NSData *)contentDataRef;

        layer.wantsExtendedDynamicRangeContent = YES;
        layer.pixelFormat = MTLPixelFormatRGBA16Float;
        CFStringRef name = kCGColorSpaceExtendedLinearITUR_2020;
        CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(name);
        layer.colorspace = colorspace;

        layer.EDRMetadata = [CAEDRMetadata HDR10MetadataWithDisplayInfo:displayData contentInfo:contentData opticalOutputScale:100.0f];

        Log(LOG_I, @"EDRMetadata set from MDCV %@ and CLLI %@", displayData, contentData);
    } else {
        layer.wantsExtendedDynamicRangeContent = YES;
        layer.pixelFormat = MTLPixelFormatRGBA16Float;
        CFStringRef name = kCGColorSpaceExtendedLinearITUR_2020;
        CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(name);
        layer.colorspace = colorspace;

        layer.EDRMetadata = [CAEDRMetadata HDR10MetadataWithMinLuminance:0.0005f maxLuminance:1000.0f opticalOutputScale:100.0f];

        Log(LOG_I, @"EDRMetadata set for 1000 nits");
    }
}
#endif

- (int)getFrameColorspaceAndRange:(Frame *)frame isFullRange:(BOOL *)isFullRange {
    CFDictionaryRef ext = [frame getFormatDescExtensions];

    // FQLog(LOG_I, @"%@", ext);

    // Full Range boolean
    CFBooleanRef fullRangeRef = CFDictionaryGetValue(ext, kCMFormatDescriptionExtension_FullRangeVideo);
    *isFullRange = NO;
    if (fullRangeRef && CFGetTypeID(fullRangeRef) == CFBooleanGetTypeID()) {
        *isFullRange = CFBooleanGetValue(fullRangeRef);
    }

    // Colorspace
    CFStringRef frame_color = CFDictionaryGetValue(ext, kCVImageBufferColorPrimariesKey);
    if (CFEqual(frame_color, kCVImageBufferColorPrimaries_ITU_R_709_2)) {
        return COLORSPACE_REC_709;
    } else if (CFEqual(frame_color, kCVImageBufferColorPrimaries_ITU_R_2020)) {
        return COLORSPACE_REC_2020;
    }
    return COLORSPACE_REC_601;
}

- (BOOL)updateColorSpaceForFrame:(Frame *)frame toLayer:(CAMetalLayer *)layer layerDidChange:(BOOL *)layerDidChange {
    BOOL fullRange = NO;
    int colorspace = [self getFrameColorspaceAndRange:frame isFullRange:&fullRange];
    if (colorspace != _lastColorSpace || fullRange != _lastFullRange) {
        CGColorSpaceRef newColorSpace = nil;
        MTLPixelFormat newPixelFormat = layer.pixelFormat;
        BOOL isHDR = NO;
        struct ParamBuffer paramBuffer;

        switch (colorspace) {
            case COLORSPACE_REC_709:
                newColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
                newPixelFormat = MTLPixelFormatBGRA8Unorm;
                paramBuffer.cscParams = (fullRange ? k_CscParams_Bt709Full : k_CscParams_Bt709Lim);
                break;
            case COLORSPACE_REC_2020: {
                CFDictionaryRef ext = [frame getFormatDescExtensions];
                CFStringRef frame_trc = CFDictionaryGetValue(ext, kCVImageBufferTransferFunctionKey);
                if (CFEqual(frame_trc, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ)) {
                    isHDR = YES;
                    newColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_PQ);
                    newPixelFormat = MTLPixelFormatBGR10A2Unorm;
                } else {
                    // SDR 2020
                    newColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
                    newPixelFormat = MTLPixelFormatBGR10A2Unorm;
                }
                paramBuffer.cscParams = (fullRange ? k_CscParams_Bt2020Full : k_CscParams_Bt2020Lim);
                break;
            }
            case COLORSPACE_REC_601:
                newColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                newPixelFormat = MTLPixelFormatBGRA8Unorm;
                paramBuffer.cscParams = (fullRange ? k_CscParams_Bt601Full : k_CscParams_Bt601Lim);
        }

        // The CAMetalLayer retains the CGColorSpace
        if (newColorSpace || newPixelFormat != layer.pixelFormat) {
            *layerDidChange = YES;
            if (newColorSpace) {
                Log(LOG_I,
                    @"Frame colorspace %@ - changing MetalLayer's colorspace to %@",
                    colorspace == COLORSPACE_REC_709        ? @"REC_709"
                        : colorspace == COLORSPACE_REC_2020 ? @"REC_2020"
                        : colorspace == COLORSPACE_REC_601  ? @"REC_601 (sRGB)"
                                                            : [NSString stringWithFormat:@"Unknown: %d", colorspace],
                    newColorSpace);
            }
            if (newPixelFormat != layer.pixelFormat) {
                Log(LOG_I,
                    @"Frame pixel format %@ - changing MetalLayer's pixel format to %@",
                    layer.pixelFormat == MTLPixelFormatBGRA8Unorm         ? @"MTLPixelFormatBGRA8Unorm"
                        : layer.pixelFormat == MTLPixelFormatBGR10A2Unorm ? @"MTLPixelFormatBGR10A2Unorm"
                                                                          : [NSString stringWithFormat:@"Unknown: %lu", layer.pixelFormat],
                    newPixelFormat == MTLPixelFormatBGRA8Unorm         ? @"MTLPixelFormatBGRA8Unorm"
                        : newPixelFormat == MTLPixelFormatBGR10A2Unorm ? @"MTLPixelFormatBGR10A2Unorm"
                                                                       : [NSString stringWithFormat:@"Unknown: %lu", (unsigned long)layer.pixelFormat]);
            }

            // These can only be changed on the main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
#if !TARGET_OS_TV
                if (isHDR) {
                    layer.wantsExtendedDynamicRangeContent = YES;
                }
#endif
                layer.colorspace = newColorSpace;
                layer.pixelFormat = newPixelFormat;
            });
            CGColorSpaceRelease(newColorSpace);
        }

        // Create the new colorspace parameter buffer for our fragment shader
        MTLResourceOptions bufferOptions = MTLResourceStorageModeShared;
        _CscParamsBuffer = [_device newBufferWithBytes:(void *)&paramBuffer length:sizeof(paramBuffer) options:bufferOptions];
        if (!_CscParamsBuffer) {
            Log(LOG_E, @"Failed to create CSC parameters buffer");
            return NO;
        }

        _lastColorSpace = colorspace;
        _lastFullRange = fullRange;
    }

    return YES;
}

- (void)scaleSource:(CGRect *)src toDest:(CGRect *)dst {
    int dstH = ceilf((float)dst->size.width * src->size.height / src->size.width);
    int dstW = ceilf((float)dst->size.height * src->size.width / src->size.height);

    if (dstH > dst->size.height) {
        dst->origin.x += (dst->size.width - dstW) / 2;
        dst->size.width = dstW;
    } else {
        dst->origin.y += (dst->size.height - dstH) / 2;
        dst->size.height = dstH;
    }
}

- (void)screenSpace:(CGRect *)src toNormalizedDeviceCoords:(CGRect *)dst withDrawableWidth:(int)viewportWidth drawableHeight:(int)viewportHeight {
    dst->origin.x = ((float)src->origin.x / (viewportWidth / 2.0f)) - 1.0f;
    dst->origin.y = ((float)src->origin.y / (viewportHeight / 2.0f)) - 1.0f;
    dst->size.width = (float)src->size.width / (viewportWidth / 2.0f);
    dst->size.height = (float)src->size.height / (viewportHeight / 2.0f);
}

- (BOOL)updateVideoRegionSizeForFrame:(Frame *)frame toLayer:(CAMetalLayer *)layer {
    int drawableWidth = layer.drawableSize.width;
    int drawableHeight = layer.drawableSize.height;

    // Check if anything has changed since the last vertex buffer upload
    if (_VideoVertexBuffer && [frame width] == _lastFrameWidth && [frame height] == _lastFrameHeight && drawableWidth == _lastDrawableWidth &&
        drawableHeight == _lastDrawableHeight) {
        // Nothing to do
        return YES;
    }

    // Determine the correct scaled size for the video region
    CGRect src = CGRectMake(0.0, 0.0, [frame width], [frame height]);
    CGRect dst = CGRectMake(0.0, 0.0, drawableWidth, drawableHeight);
    [self scaleSource:&src toDest:&dst];

    // Convert screen space to normalized device coordinates
    CGRect renderRect;
    [self screenSpace:&dst toNormalizedDeviceCoords:&renderRect withDrawableWidth:drawableWidth drawableHeight:drawableHeight];

    struct Vertex verts[] = {
        {{renderRect.origin.x, renderRect.origin.y, 0.0f, 1.0f}, {0.0f, 1.0f}},
        {{renderRect.origin.x, renderRect.origin.y + renderRect.size.height, 0.0f, 1.0f}, {0.0f, 0}},
        {{renderRect.origin.x + renderRect.size.width, renderRect.origin.y, 0.0f, 1.0f}, {1.0f, 1.0f}},
        {{renderRect.origin.x + renderRect.size.width, renderRect.origin.y + renderRect.size.height, 0.0f, 1.0f}, {1.0f, 0}},
    };

    MTLResourceOptions bufferOptions = MTLResourceStorageModeShared;
    _VideoVertexBuffer = [_device newBufferWithBytes:verts length:sizeof(verts) options:bufferOptions];
    if (!_VideoVertexBuffer) {
        Log(LOG_E, @"Failed to create video vertex buffer");
        return NO;
    }

    _lastFrameWidth = [frame width];
    _lastFrameHeight = [frame height];
    _lastDrawableWidth = drawableWidth;
    _lastDrawableHeight = drawableHeight;

    return YES;
}

- (void)discardNextDrawable {
    _nextDrawable = nil;
}

- (void)renderFrame:(Frame *)frame toLayer:(CAMetalLayer *)layer
{ @autoreleasepool {
    // Handle changes to the frame's colorspace from last time we rendered
    BOOL layerDidChange = NO;
    if (![self updateColorSpaceForFrame:frame toLayer:layer layerDidChange:&layerDidChange]) {
        return;
    }

    if (layerDidChange && frame.frameNumber > 1) {
        Log(LOG_I, @"Metal frame changed layer's colorspace and/or pixel format, returning for new drawable");
        [self discardNextDrawable];
        return;
    }

    // Handle changes to the video size or drawable size
    if (![self updateVideoRegionSizeForFrame:frame toLayer:layer]) {
        return;
    }

    FQLog(LOG_I, @"[%d / %.3f ms] Metal frame rendering", frame.frameNumber, frame.pts);

#if !TARGET_OS_TV
    // Experimental EDR handling based on frame metadata
    //[self applyEDRFromFrame:frame toLayer:layer];
#endif

    size_t planes = CVPixelBufferGetPlaneCount(frame.pixelBuffer);
    assert(planes <= MAX_VIDEO_PLANES);

    MTLRenderPipelineDescriptor *pipelineDesc = [MTLRenderPipelineDescriptor new];
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    pipelineDesc.vertexFunction = [defaultLibrary newFunctionWithName:@"vs_draw"];
    pipelineDesc.fragmentFunction = [defaultLibrary newFunctionWithName:planes == 2 ? @"ps_draw_biplanar" : @"ps_draw_triplanar"];
    pipelineDesc.colorAttachments[0].pixelFormat = layer.pixelFormat;
    pipelineDesc.vertexBuffers[0].mutability = MTLMutabilityImmutable;

    NSError *error = nil;
    _videoPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
    if (!_videoPipelineState) {
        Log(LOG_E, @"Failed to create video pipeline state: %@", error);
        return;
    }

    for (size_t i = 0; i < planes; i++) {
        MTLPixelFormat fmt;

        switch (CVPixelBufferGetPixelFormatType(frame.pixelBuffer)) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
        case kCVPixelFormatType_444YpCbCr8BiPlanarFullRange:
            fmt = (i == 0) ? MTLPixelFormatR8Unorm : MTLPixelFormatRG8Unorm;
            break;

        case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
        case kCVPixelFormatType_444YpCbCr10BiPlanarFullRange:
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
        case kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange:
            fmt = (i == 0) ? MTLPixelFormatR16Unorm : MTLPixelFormatRG16Unorm;
            break;

        default:
            Log(LOG_E, @"Unknown pixel format: %@", CVPixelBufferGetPixelFormatType(frame.pixelBuffer));
            return;
        }

        if (_cvMetalTextures[i]) {
            CVBufferRelease(_cvMetalTextures[i]);
        }
        CVReturn err = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                 _textureCache,
                                                                 frame.pixelBuffer,
                                                                 NULL,
                                                                 fmt,
                                                                 CVPixelBufferGetWidthOfPlane(frame.pixelBuffer, i),
                                                                 CVPixelBufferGetHeightOfPlane(frame.pixelBuffer, i),
                                                                 i,
                                                                 &_cvMetalTextures[i]);
        if (err != kCVReturnSuccess) {
            Log(LOG_E, @"CVMetalTextureCacheCreateTextureFromImage() failed: %d", err);
            return;
        }
    }

    if (!_nextDrawable) {
        Log(LOG_E, @"Lost nextDrawable, trying to get a new one");
        _nextDrawable = [layer nextDrawable];
        if (!_nextDrawable) {
            Log(LOG_E, @"Failed to get nextDrawable");
            return;
        }
    }
    _renderPassDescriptor.colorAttachments[0].texture = _nextDrawable.texture;

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];

    [renderEncoder setRenderPipelineState:_videoPipelineState];
    for (size_t i = 0; i < planes; i++) {
        [renderEncoder setFragmentTexture:CVMetalTextureGetTexture(_cvMetalTextures[i]) atIndex:i];
    }

    __block dispatch_semaphore_t block_semaphore = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb) {
        dispatch_semaphore_signal(block_semaphore);

        const CFTimeInterval GPUTime = cb.GPUEndTime - cb.GPUStartTime;
        const double alpha = 0.25f;
        self->_averageGPUTime = (GPUTime * alpha) + (self->_averageGPUTime * (1.0 - alpha));

        // Free textures after completion of rendering
        for (size_t i = 0; i < planes; i++) {
            if (self->_cvMetalTextures[i]) {
                CVBufferRelease(self->_cvMetalTextures[i]);
                self->_cvMetalTextures[i] = nil;
            }
        }

        CVMetalTextureCacheFlush(self->_textureCache, 0);
    }];

    [renderEncoder setFragmentBuffer:_CscParamsBuffer offset:0 atIndex:0];
    [renderEncoder setVertexBuffer:_VideoVertexBuffer offset:0 atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [renderEncoder endEncoding];

    __weak typeof(self) self_ = self;
    [_nextDrawable addPresentedHandler:^(id<MTLDrawable> d) {
        if (self_) {
            [self_ plotFrametime:d.presentedTime];
        }
    }];

#if TARGET_OS_SIMULATOR
    [commandBuffer presentDrawable:_nextDrawable];
#else
    // present for a minimum duration for best frame pacing
    [commandBuffer presentDrawable:_nextDrawable afterMinimumDuration:1.0f / _framerate];
#endif

    [commandBuffer commit];

    // Wait for the command buffer to complete and free our CVMetalTextureCache references
    [commandBuffer waitUntilCompleted];

    _nextDrawable = nil;
} }

- (void)plotFrametime:(CFTimeInterval)presentedTime {
    if (_lastPresented > 0) {
        CFTimeInterval frametime = presentedTime - _lastPresented;
        [[ImGuiPlots sharedInstance] observeFloat:PLOT_FRAMETIME value:(frametime * 1000.0)];
    }
    _lastPresented = presentedTime;
}

- (void)waitToRenderTo:(nonnull CAMetalLayer *)layer {
    if (!_nextDrawable) {
        // Wait for the next available drawable
        _nextDrawable = [layer nextDrawable];
        if (!_nextDrawable) {
            Log(LOG_E, @"Error getting nextDrawable from CAMetalLayer");
            return;
        }

        // Wait to ensure only `MaxFramesInFlight` number of frames are getting processed
        // by any stage in the Metal pipeline (CPU, GPU, Metal, Drivers, etc.).
        dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
    }
}

/// Responds to the drawable's size or orientation changes.
- (void)drawableResize:(CGSize)drawableSize {
    [self resize:drawableSize];
}

- (void)resize:(CGSize)size {

}

@end
