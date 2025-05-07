#import <CoreVideo/CVImageBuffer.h>
#import "Frame.h"
#import "Logger.h"
#include <Limelight.h>

@implementation Frame {
    CFDictionaryRef _formatDescExt;
}

- (instancetype)initWithPixelBufffer:(CVPixelBufferRef)pixelBuffer
                         frameNumber:(int)frameNumber
                           frameType:(int)frameType
                                 pts:(CMTime)pts {
    self = [super init];
    if (self) {
        _decodedAt    = CACurrentMediaTime();
        _formatDescExt = nil;
        _frameNumber  = frameNumber;
        _frameType    = frameType;
        _pixelBuffer  = pixelBuffer; // already retained
        _sampleBuffer = nil;

        // 90 kHz pts from RTP
        _pts90        = pts;
        _duration90   = kCMTimeInvalid;

        FQLog(LOG_I, @"init Frame %d - type %@ [host pts %.3f]",
              _frameNumber, _frameType == FRAME_TYPE_IDR ? @"IDR" : @"P",
              CMTimeGetSeconds(_pts90));
    }
    return self;
}

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer frameNumber:(int)frameNumber frameType:(int)frameType {
    self = [super init];
    if (self) {
        _frameNumber  = frameNumber;
        _frameType    = frameType;
        _pixelBuffer  = nil;
        _sampleBuffer = sampleBuffer;

        // 90 kHz pts from RTP
        _pts90        = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
        _duration90   = kCMTimeInvalid;

        FQLog(LOG_I, @"init Frame %d - type %@ [host pts %.3f]",
            _frameNumber, _frameType == FRAME_TYPE_IDR ? @"IDR" : @"P",
            CMTimeGetSeconds(_pts90));
    }
    return self;
}

- (void)dealloc {
    FQLog(LOG_I, @"[%d / %f] Frame dealloc", _frameNumber, CMTimeGetSeconds(_pts90));

    if (_formatDesc) {
        CFRelease(_formatDesc);
        _formatDesc = nil;
    }
    if (_formatDescExt) {
        CFRelease(_formatDescExt);
        _formatDescExt = nil;
    }
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = nil;
    }

    // sampleBuffer comes from CMSampleBufferCreateReadyWithImageBuffer
    // so we don't need to CFRetain in init, but do need to release it
    if (_sampleBuffer) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = nil;
    }
}

- (void)setFormatDesc:(CMVideoFormatDescriptionRef)formatDesc {
    if (_formatDesc) {
        CFRelease(_formatDesc);
    }
    _formatDesc = CFRetain(formatDesc);
}

- (CFDictionaryRef)getFormatDescExtensions {
    if (!_formatDescExt && _formatDesc) {
        _formatDescExt = CFRetain(CMFormatDescriptionGetExtensions(_formatDesc));
    }
    return _formatDescExt;
}

- (CFTimeInterval)pts {
    return CMTimeGetSeconds(_pts90);
}

- (CFTimeInterval)duration {
    if (CMTIME_IS_VALID(_duration90)) {
        return CMTimeGetSeconds(_duration90);
    }
    return NAN;
}

- (void)setDurationFromNext:(Frame *)nextFrame {
    if (nextFrame.frameNumber == _frameNumber + 1) {
        _duration90 = CMTimeSubtract(nextFrame.pts90, _pts90);
        _duration90.flags = kCMTimeFlags_Valid;

        FQLog(LOG_I, @"frame [%d / %.3f] set duration %.3f ms",
            _frameNumber, CMTimeGetSeconds(_pts90),
            CMTimeGetSeconds(_duration90) * 1000.0);
    }
}

- (BOOL)durationIsValid {
    return CMTIME_IS_VALID(_duration90);
}

- (size_t)width {
    if (_pixelBuffer) {
        return CVPixelBufferGetWidth(_pixelBuffer);
    }
    return -1;
}

- (size_t)height {
    if (_pixelBuffer) {
        return CVPixelBufferGetHeight(_pixelBuffer);
    }
    return -1;
}

// Debug output when using %@
- (NSString *)description {
    return [NSString stringWithFormat:@"{Frame: %d, type %@, pts90 %lld, pts %.3f ms, duration %@}",
        self.frameNumber,
        self.frameType == 1 ? @"IDR" : @"PFRAME",
        self.pts90.value,
        self.pts * 1000.0,
        [self durationIsValid] ? [ NSString stringWithFormat:@"%.3f ms", self.duration * 1000.0] : @"--"
    ];
}

@end
