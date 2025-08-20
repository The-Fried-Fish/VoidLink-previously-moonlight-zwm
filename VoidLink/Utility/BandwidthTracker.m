#import "BandwidthTracker.h"
#import <QuartzCore/QuartzCore.h> // for CACurrentMediaTime()

// A single time‐bucket: start time (ms) + bytes counted.
typedef struct {
    CFTimeInterval startMs;
    NSUInteger bytes;
} Bucket;

@interface BandwidthTracker () {
    // Configuration
    NSUInteger _windowSeconds;    // e.g. 10
    NSUInteger _bucketIntervalMs; // e.g. 250
    NSUInteger _bucketCount;      // = (_windowSeconds * 1000) / _bucketIntervalMs

    // State
    Bucket *_buckets; // C-array of _bucketCount entries
    NSLock *_lock;    // protects all bucket ops
}
@end

@implementation BandwidthTracker

- (instancetype)init {
    return [self initWithWindowSeconds:10 bucketIntervalMs:250];
}

- (instancetype)initWithWindowSeconds:(NSUInteger)windowSeconds bucketIntervalMs:(NSUInteger)bucketIntervalMs {
    self = [super init];
    if (self) {
        _windowSeconds = (windowSeconds > 0 ? windowSeconds : 10);
        _bucketIntervalMs = (bucketIntervalMs > 0 ? bucketIntervalMs : 250);

        _bucketCount = (_windowSeconds * 1000) / _bucketIntervalMs;
        _buckets = calloc(_bucketCount, sizeof(Bucket));
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dealloc {
    free(_buckets);
}

- (NSUInteger)windowSeconds {
    return _windowSeconds;
}

#pragma mark – Public API

- (void)addBytes:(NSUInteger)bytes {
    [_lock lock];
    CFTimeInterval nowMs = CACurrentMediaTime() * 1000.0;
    [self _updateBucketWithBytes:bytes nowMs:nowMs];
    [_lock unlock];
}

- (double)averageMbps {
    [_lock lock];
    CFTimeInterval nowMs = CACurrentMediaTime() * 1000.0;
    NSUInteger currentIndex = ((NSUInteger)nowMs / _bucketIntervalMs) % _bucketCount;
    NSUInteger maxBuckets = _bucketCount / 4;
    NSUInteger totalBytes = 0;
    CFTimeInterval oldestStart = nowMs;

    for (NSUInteger i = 0; i < maxBuckets; i++) {
        NSUInteger idx = (currentIndex + _bucketCount - i) % _bucketCount;
        Bucket b = _buckets[idx];
        if ([self _isBucketValid:&b nowMs:nowMs] && (nowMs - b.startMs >= _bucketIntervalMs)) {
            totalBytes += b.bytes;
            if (b.startMs < oldestStart)
                oldestStart = b.startMs;
        }
    }

    // elapsed time in seconds
    double elapsedSec = (nowMs - oldestStart) / 1000.0;
    double avg = (elapsedSec > 0.0 ? totalBytes * 8.0 / 1000000.0 / elapsedSec : 0.0);
    [_lock unlock];
    return avg;
}

- (double)peakMbps {
    [_lock lock];
    CFTimeInterval nowMs = CACurrentMediaTime() * 1000.0;
    double peak = 0.0;

    for (NSUInteger i = 0; i < _bucketCount; i++) {
        Bucket b = _buckets[i];
        if ([self _isBucketValid:&b nowMs:nowMs]) {
            double mbps = [self _bucketMbps:&b];
            if (mbps > peak)
                peak = mbps;
        }
    }

    [_lock unlock];
    return peak;
}

#pragma mark – Private Helpers

// Check if a bucket's data is still valid (within the window)
- (BOOL)_isBucketValid:(Bucket *)bucket nowMs:(CFTimeInterval)nowMs {
    return (nowMs - bucket->startMs) <= (_windowSeconds * 1000.0);
}

- (double)_bucketMbps:(Bucket *)bucket {
    // bucketIntervalMs is ms → divide by 1000 to get seconds
    return bucket->bytes * 8.0 / 1000000.0 / (_bucketIntervalMs / 1000.0);
}

- (void)_updateBucketWithBytes:(NSUInteger)bytes nowMs:(CFTimeInterval)nowMs {
    NSUInteger ms = (NSUInteger)nowMs;
    NSUInteger idx = (ms / _bucketIntervalMs) % _bucketCount;
    NSUInteger alignedMs = ms - (ms % _bucketIntervalMs);
    CFTimeInterval startMs = alignedMs;

    Bucket *b = &_buckets[idx];

    // If this bucket is stale (older than the window), reset it
    if (nowMs - b->startMs > (_windowSeconds * 1000.0)) {
        b->bytes = 0;
        b->startMs = startMs;
    }

    // If we’ve moved into a new sub-interval, overwrite; otherwise accumulate
    if (b->startMs != startMs) {
        b->bytes = bytes;
        b->startMs = startMs;
    } else {
        b->bytes += bytes;
    }
}

@end
