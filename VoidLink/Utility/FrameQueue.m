@import AVFoundation;
@import VideoToolbox;

#import <os/lock.h>
#import <Limelight.h>
#import "Logger.h"
#import "FloatBuffer.h"
#import "FrameQueue.h"
#import "ImGuiPlots.h"

@implementation FrameQueue {
    NSMutableArray<id> *_buffer;
    int _capacity;
    int _head;
    int _tail;
    int _count;

    BOOL _droppedLast;
    int _framesIn;
    CMTime _ptsCorrection;
    os_unfair_lock _lock;

    FloatBuffer *_queueSizeHistory;
    int _currentSoftCap;
    dispatch_queue_t _sq;
    dispatch_semaphore_t _frameSemaphore;
}

+ (instancetype)sharedInstance {
    static FrameQueue *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] _initSingleton];
    });
    return sharedInstance;
}

// Prevent others from using alloc/init directly
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

// If someone tries to copy it, just return the same instance
- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)_initSingleton {
    self = [super init];
    if (self) {
        _droppedLast       = NO;
        _frameDropMetrics  = [[FloatBuffer alloc] initWithCapacity:512];
        _framesIn          = 0;
        _highWaterMark     = 2;
        _maxCapacity       = 15;
        _ptsCorrection     = CMTimeMake(0, 90000);
        _queueSizeHistory  = [[FloatBuffer alloc] initWithCapacity:64];
        _lock              = OS_UNFAIR_LOCK_INIT;
        _isStopping        = NO;

	    // ring buffer
	    _capacity = _maxCapacity;
        _buffer = [NSMutableArray arrayWithCapacity:_capacity];
        for (int i = 0; i < _capacity; i++) {
            [_buffer addObject:[NSNull null]];
        }
        _head = _tail = _count = 0;

        _sq = dispatch_queue_create("com.moonlight.FrameQueue",
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0));
        _frameSemaphore = dispatch_semaphore_create(0);

        // ping estimatedFramerate to set initial last value
        [self estimatedFramerate];
    }
	return self;
}

// Push into buffer at _tail
- (void)_pushFrame:(Frame *)frame {
    [_buffer replaceObjectAtIndex:_tail withObject:frame];
    _tail = (_tail + 1) % _capacity;
    _count++;

    // I think it's ok to signal the cond from within the unfair lock, the render
    // loop will just end up waiting on it in a call to dequeue.
    dispatch_semaphore_signal(_frameSemaphore);

	FQLog(LOG_I, @"[-> %@ %d / %f] enqueue frame, queue size %d / %d",
		frame.frameType == FRAME_TYPE_IDR ? @"IDR" : @"P",
		frame.frameNumber, frame.pts, _count, _highWaterMark);
}

// Pop oldest frame from _head
- (Frame *)_popFrame {
    id obj = _buffer[_head];
    Frame *frame = (obj == [NSNull null] ? nil : obj);
    [_buffer replaceObjectAtIndex:_head withObject:[NSNull null]];
    _head = (_head + 1) % _capacity;
    _count--;
    return frame;
}

// Peek next frame (without removing)
- (Frame *)_peekFrame {
    id frame = (_count > 0) ? _buffer[_head] : nil;
    return (frame == [NSNull null]) ? nil : frame;
}

// enumerate in‐buffer frames
- (void)_enumerateFrames:(void(^)(Frame *frame, NSUInteger idx, BOOL *stop))block {
    BOOL stop = NO;
    for (int i = 0; i < _count; i++) {
        int idx = (_head + i) % _capacity;
        block([_buffer objectAtIndex:idx], i, &stop);
        if (stop) break;
    }
}

- (void)_noteDroppedFrame:(Frame *)frame {
    if ([frame durationIsValid]) {
        _ptsCorrection = CMTimeAdd(_ptsCorrection, frame.duration90);
		FQLog(LOG_W, @"dropped frame %d with duration %.3f ms", frame.frameNumber, frame.duration * 1000.0);
    } else {
		// count unknowns as 1 avg frametime
        CFTimeInterval fps = (_framesIn > 1000) ? [self _unsafeEstimatedFramerate] : 0.0f;
        CMTime oneFrame = (_framesIn > 1000) ? CMTimeMake((int)(90000.0f / fps), 90000) : kCMTimeZero;
        _ptsCorrection = CMTimeAdd(_ptsCorrection, oneFrame);
        FQLog(LOG_W, @"dropped frame %d with unknown duration, using %.3f ms (%.1f fps) instead",
            frame.frameNumber, CMTimeGetSeconds(oneFrame) * 1000.0, fps);
    }
}

- (int)_unsafeEnqueue:(Frame *)frame withDropTarget:(int)frameDropTarget {
    int dropCount = 0;
    // Always accept IDR frames, allow exceeding HWM
    if (frame.frameType == FRAME_TYPE_IDR || _count < frameDropTarget) {
        [self _pushFrame:frame];
        _droppedLast = NO;
    } else {
        if (!_droppedLast) {
			// alternate between: drop newest...
            [self _noteDroppedFrame:frame];
            dropCount = 1;
            _droppedLast = YES;
        } else {
            // and: drop oldest & enqueue new
            if ([self _peekFrame].frameType != FRAME_TYPE_IDR) {
				Frame *oldest = [self _popFrame];
                [oldest setDurationFromNext:[self _peekFrame]];
                [self _noteDroppedFrame:oldest];
                dropCount = 1;
            }
            [self _pushFrame:frame];
            _droppedLast = NO;
        }
    }
	// regardless of drop status, every enqueue is a frame
    // for estimatedFramerate purposes
    _framesIn++;
    [_frameDropMetrics addValue:(float)dropCount];

    // Stats displays the soft cap
    _currentSoftCap = frameDropTarget;
    return dropCount;
}

// enqueue with simple alternate-drop logic
- (int)enqueue:(Frame *)frame {
    os_unfair_lock_lock(&_lock);
    int dropCount = [self _unsafeEnqueue:frame withDropTarget:_highWaterMark];
    os_unfair_lock_unlock(&_lock);
    return dropCount;
}

// enqueue that is a bit more flexixble, using the same 500ms queue size history method as moonlight-qt.
- (int)enqueue:(Frame *)frame withSlackSize:(int)slack {
    os_unfair_lock_lock(&_lock);
    CFTimeInterval now = CACurrentMediaTime();

    // new data point for queue health
    [_queueSizeHistory addValue:(float)_count];

    // The "target" initially starts as the size of the buffer chosen by the user. 1-5 default 2. We drop a frame
    // when the queue size exceeds this amount.
    int frameDropTarget = _highWaterMark;

//    CFTimeInterval t0 = [_queueSizeHistory oldestTimestamp];
//    if (now - t0 > 0.5f) {
//        // Get the current drop percentage over the past 512 frames
//        // TODO: design a better API e.g. [ImGuiPlots PLOT_DROPPED].
//        float dropRate = [[ImGuiPlots sharedInstance].plots[PLOT_DROPPED].buffer averageValue];
//        if (dropRate > 0.25f) {
//            FQLog(LOG_I, @"queue is dropping at %.2f%%, forcing a drop", dropRate * 100.0);
//            frameDropTarget--;
//        } else if (_queueSizeHistory.minValue > 0 && _queueSizeHistory.minValue == _queueSizeHistory.maxValue) {
//            // If the queue has been in the same state for the entire period, it's possible to get stuck there for a while.
//            // Lower the FDT by 1 to force a frame to be dropped and hopefully unstick things.
//            FQLog(LOG_I, @"queue stuck at %.0f, forcing a drop", _queueSizeHistory.minValue);
//            frameDropTarget--;
//        } else if (_queueSizeHistory.minValue < 1.0f) {
//            // If the queue has cleared out at least once in the past history period, be more lenient about dropping frames.
//            frameDropTarget += slack;
//            //        FQLog(LOG_I, @"allowing frameDropTarget of %d (history %.0f/%.0f/%.2f)", frameDropTarget,
//            //            _queueSizeHistory.minValue, _queueSizeHistory.maxValue, _queueSizeHistory.averageValue);
//        }
//
//        // TODO: New logic
//        // Use timestamps, check initial interval is long enough
//        // Smarter when checking min==max, a steady state can be fine if no frames are being dropped
//        //   If min==max && frame drops are >= 25%, force a drop
//        //   Maybe only look at >= 25%.
//        // Test condition variables, manual present, no displaylink
//    }

    // original enqueue logic still applies if we're full
    int dropCount = [self _unsafeEnqueue:frame withDropTarget:frameDropTarget];

    os_unfair_lock_unlock(&_lock);
    return dropCount;
}

// Allows the render loop to wait if the queue is empty
- (void)waitForEnqueue {
    while (!self.isStopping && [self isEmpty]) {
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)); // 100ms
        dispatch_semaphore_wait(_frameSemaphore, timeout);
    }
}

- (Frame *)dequeue {
    os_unfair_lock_lock(&_lock);
    Frame *frame = nil;
    if (_count > 0) {
        frame = [self _popFrame];
        // compute duration from next
        Frame *next = [self _peekFrame];
        if (next) {
			[frame setDurationFromNext:next];
		}
		FQLog(LOG_I, @"[<- %d / %f%@] dequeue frame, queue size %d",
			frame.frameNumber, frame.pts,
			[frame durationIsValid] ? [NSString stringWithFormat:@" dur %.3f ms", frame.duration * 1000.0] : @"",
			_count);
    }
    os_unfair_lock_unlock(&_lock);
    return frame;
}

- (Frame *)dequeueWithTimeout:(CFTimeInterval)timeout {
    CFTimeInterval start = CACurrentMediaTime();
    CFTimeInterval deadline = start + timeout;
    int round = 0;

    if (self.isStopping) {
        return nil;
    }

    // Always attempt to dequeue at least once
    do {
        if (round > 0) {
            usleep(100); // 0.1ms
        }
        Frame *frame = [self dequeue];
        if (frame) {
            return frame;
        }
        round++;
    } while (CACurrentMediaTime() < deadline);

    FQLog(LOG_I, @"dequeueWithTimeout timed out after %.3f ms", (CACurrentMediaTime() - start) * 1000.0);
    return nil;
}

- (NSUInteger)count {
    os_unfair_lock_lock(&_lock);
    NSUInteger c = _count;
    os_unfair_lock_unlock(&_lock);
    return c;
}

- (BOOL)isEmpty {
    return [self count] == 0;
}

- (void)clear {
    os_unfair_lock_lock(&_lock);
    _head = _tail = _count = 0;
    _frameDropMetrics = [[FloatBuffer alloc] initWithCapacity:512];
    os_unfair_lock_unlock(&_lock);
}

- (CFTimeInterval)_unsafeEstimatedFramerate {
    static CFTimeInterval lastTime = 0;
    static int lastFrames = 0;
    static CFTimeInterval estimate = 0;

    CFTimeInterval now = CACurrentMediaTime();
    if (now - lastTime > 1.0) {
        estimate = (_framesIn - lastFrames) / (now - lastTime);
//		FQLog(LOG_I, @"fps calc using framesIn %d - lastFrames %d / now %f - lastTime %f = %.1f fps",
//		              _framesIn, lastFrames, now, lastTime, estimate);
        lastTime   = now;
        lastFrames = _framesIn;
    }
    return estimate;
}

- (CFTimeInterval)estimatedFramerate {
    os_unfair_lock_lock(&_lock);
    CFTimeInterval fps = [self _unsafeEstimatedFramerate];
    os_unfair_lock_unlock(&_lock);
    return fps;
}

- (int)currentSoftCap {
    os_unfair_lock_lock(&_lock);
    int cap = _currentSoftCap;
    os_unfair_lock_unlock(&_lock);
    return cap;
}

- (void)shutdown {
    // new frames will no longer be coming in, make sure consumer side is not left waiting
    self.isStopping = YES;
    Log(LOG_I, @"XXX FrameQueue shutting down");
    dispatch_semaphore_signal(_frameSemaphore);
}

// For use with NSLog("%@", franeQueue);
- (NSString *)description {
    __block NSMutableArray *parts = [NSMutableArray arrayWithCapacity:_count];
    [self _enumerateFrames:^(Frame *frame, NSUInteger idx, BOOL *stop) {
        [parts addObject:[frame description]];
    }];
    return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@",\n"]];
}

@end
