
#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>

#define FRAME_QUEUE_VERBOSE

#import "FrameQueue.h"
#import "Logger.h"
#include "Limelight.h"

@interface FrameQueueTests : XCTestCase
@property (nonatomic, strong) FrameQueue *queue;
@end

@implementation FrameQueueTests {
    int _frameNumber;
}

- (void)setUp {
    [super setUp];
    self.queue = [FrameQueue sharedInstance];
    [self.queue setHighWaterMark:3];
    _frameNumber = 0;
}

- (void)tearDown {
    [self.queue clear];
    self.queue = nil;
    [super tearDown];
}

- (CMSampleBufferRef)makeEmptySampleBufferFor:(uint32_t)tick {
    CMSampleTimingInfo sampleTiming = {
        .duration              = kCMTimeInvalid,
        .presentationTimeStamp = CMTimeMake((int64_t)tick, 90000),
        .decodeTimeStamp       = kCMTimeInvalid,
    };

    CMSampleBufferRef sampleBuffer = NULL;
    OSStatus status = CMSampleBufferCreate(kCFAllocatorDefault,
                                           NULL, NO, NULL, NULL, NULL,
                                           1, 1, &sampleTiming, 0, NULL,
                                           &sampleBuffer);
    XCTAssertEqual(status, noErr, @"makeEmptySampleBufferFor:%d ok", tick);
    return sampleBuffer;
}

- (Frame *)makeFrameNumber:(int)num type:(int)type pts:(uint32_t)tick {
    CMSampleBufferRef buf = [self makeEmptySampleBufferFor:tick];
    CFRetain(buf); // emulate retain that happens in CMSampleBufferCreateReadyWithImageBuffer
    Frame *frame = [[Frame alloc] initWithSampleBuffer:buf
                                           frameNumber:num
                                             frameType:type];
    _frameNumber = num; // reset the counter
    return frame;
}

- (Frame *)makeFrame {
    const uint32_t ONE_FRAME = 90000 / 60;
    static uint32_t tick = 0;
    Frame *frame = [self makeFrameNumber:++_frameNumber
                                    type:FRAME_TYPE_PFRAME
                                    pts:tick];
    tick += ONE_FRAME;
    return frame;
}

- (void)testEnqueueThenDequeue {
    Frame *f1 = [self makeFrameNumber:1 type:FRAME_TYPE_IDR pts:0];
    Frame *f2 = [self makeFrame];

    [self.queue enqueue:f1];
    [self.queue enqueue:f2];
    XCTAssertEqual([self.queue count], 2);

    Frame *out1 = [self.queue dequeue];
    XCTAssertEqual(out1.frameNumber, 1);
    XCTAssertEqual([self.queue count], 1);

    Frame *out2 = [self.queue dequeue];
    XCTAssertEqual(out2.frameNumber, 2);
    XCTAssertEqual([self.queue count], 0);

    // empty now
    XCTAssertNil([self.queue dequeue]);
}

- (void)testOverflow {
    [self.queue setHighWaterMark:3];

    for (int i = 0; i < self.queue.highWaterMark; i++) {
        [self.queue enqueue:[self makeFrame]];
    }
    XCTAssertEqual([self.queue count], 3);

    // queue should be full at 3
    // 4: dropped, 5: queued, causes 1 to be dropped
    // 6: dropped, 7: queued, causes 2 to be dropped
    // 8: dropped, 9: queued, causes 3 to be dropped
    for (int i = 0; i < 6; i++) {
        [self.queue enqueue:[self makeFrame]];
    }
    XCTAssertEqual([self.queue count], 3);
    XCTAssertEqual([[self.queue frameDropMetrics] total], 6);
    Log(LOG_I, @"queue after overflow: %@", self.queue);
    for (NSNumber *expected in @[@5, @7, @9]) {
        Frame *frame = [self.queue dequeue];
        XCTAssertEqual(frame.frameNumber, expected.integerValue);
    }
}

- (void)testOverflowWithIDR {
    [self.queue setHighWaterMark:5];

    [self.queue enqueue:[self makeFrameNumber:1 type:FRAME_TYPE_IDR pts:0]];
    [self.queue enqueue:[self makeFrame]];
    [self.queue enqueue:[self makeFrameNumber:3 type:FRAME_TYPE_IDR pts:0]];
    [self.queue enqueue:[self makeFrame]];
    [self.queue enqueue:[self makeFrame]];
    XCTAssertEqual([self.queue count], 5);

    // queue should be full at 5
    // 6: dropped, 7: queued, does NOT drop 1 (IDR)
    // 8: dropped, 9: queued, does NOT drop 1 (IDR) - will be stuck here until it's dequeued
    // 10: dropped, 11: queued, does NOT drop 3 (IDR)
    for (int i = 0; i < 6; i++) {
        [self.queue enqueue:[self makeFrame]];
    }
    XCTAssertEqual([self.queue count], 8);
    XCTAssertEqual([[self.queue frameDropMetrics] total], 3);
    Log(LOG_I, @"queue after overflow: %@", self.queue);

    for (NSNumber *expected in @[@1, @2, @3, @4, @5, @7, @9, @11]) {
        XCTAssertEqual([self.queue dequeue].frameNumber, expected.integerValue);
    }
}

- (void)testClear {
    for (int i = 0; i < self.queue.highWaterMark; i++) {
        [self.queue enqueue:[self makeFrame]];
    }
    XCTAssertEqual([self.queue count], self.queue.highWaterMark);

    [self.queue clear];
    XCTAssertEqual([self.queue count], 0);
    XCTAssertEqual([[self.queue frameDropMetrics] total], 0);
    XCTAssertNil([self.queue dequeue]);
}

- (void)testDequeueWithTimeout {
    [self.queue enqueue:[self makeFrame]];

    // should return immediately with an item in the queue
    CFTimeInterval t0 = CACurrentMediaTime();
    Frame *out = [self.queue dequeueWithTimeout:1];
    XCTAssertNotNil(out);
    XCTAssertEqual(out.frameNumber, 1);
    XCTAssertLessThan(CACurrentMediaTime() - t0, 0.9);

    // should return nil after waiting
    t0 = CACurrentMediaTime();
    XCTAssertNil([self.queue dequeueWithTimeout:0.2]);
    XCTAssertGreaterThan(CACurrentMediaTime() - t0, 0.2);

    // no timeout
    t0 = CACurrentMediaTime();
    XCTAssertNil([self.queue dequeueWithTimeout:0]);
    XCTAssertLessThan(CACurrentMediaTime() - t0, 0.1);
}

- (void)testDuration {
    // 2nd frame will compute 1st frame's duration. makeFrame generates sequential frames at 60fps
    [self.queue clear];
    [self.queue enqueue:[self makeFrame]];
    [self.queue enqueue:[self makeFrame]];
    XCTAssertEqual([self.queue count], 2);
    Frame *first = [self.queue dequeue];
    XCTAssertEqualWithAccuracy(first.duration, (float)1.0f / 60, 0.0001f);
}

- (void)testEstimatedFramerate {
    // prime the start point
    [self.queue estimatedFramerate];
    for (int i = 0; i < 24 * 5; i++) {
        // these will all get dropped but they are still counted for fps
        [self.queue enqueue:[self makeFrame]];
        [NSThread sleepForTimeInterval:1.0f / 24];
    }
    XCTAssertEqualWithAccuracy([self.queue estimatedFramerate], 24.0f, 4.0f);
}

- (void)testProducerConsumer {
    static const int TotalFrames = 500;

    // We expect exactly kTotalFrames dequeues.
    XCTestExpectation *dequeueAll = [self expectationWithDescription:@"consumer dequeued all frames"];
    dequeueAll.expectedFulfillmentCount = TotalFrames;

    // Producer
    dispatch_queue_t producerQ = dispatch_queue_create("moonlight.test.producer", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(producerQ, ^{
        for (int i = 0; i < TotalFrames; i++) {
            [self.queue enqueue:[self makeFrame]];
            [NSThread sleepForTimeInterval:0.002];
        }
    });

    // Consumer
    dispatch_queue_t consumerQ = dispatch_queue_create("moonlight.test.consumer", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(consumerQ, ^{
        for (int expected = 0; expected < TotalFrames; expected++) {
            Frame *frame = [self.queue dequeueWithTimeout:1.0];
            XCTAssertNotNil(frame, @"Expected frame %d, but got nil", expected);
            XCTAssertEqual(frame.frameNumber, expected + 1, @"Expected frameNumber %d but got %d", expected + 1, frame.frameNumber);
            [dequeueAll fulfill];
        }
    });

    // Wait up to 10s for all frames to be consumed
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Timed out waiting for consumer: %@", error);
        }
        XCTAssertEqual([self.queue count], 0, @"Queue should be empty at end");
    }];
}

- (void)testPerformance {
    XCTMeasureOptions *options = [[XCTMeasureOptions alloc] init];
    options.iterationCount = 20;
    if (@available(iOS 13.0, *)) {
        static const int TotalFrames = 1000;
        dispatch_queue_t producerQ = dispatch_queue_create("moonlight.test.producer", DISPATCH_QUEUE_CONCURRENT);
        dispatch_queue_t consumerQ = dispatch_queue_create("moonlight.test.consumer", DISPATCH_QUEUE_CONCURRENT);

        [self measureWithOptions:options block:^{
            XCTestExpectation *dequeueAll = [self expectationWithDescription:@"consumer dequeued all frames"];
            dequeueAll.expectedFulfillmentCount = TotalFrames;

            [self.queue setHighWaterMark:5];

            // Producer
            dispatch_async(producerQ, ^{
                for (int i = 0; i < TotalFrames; i++) {
                    //[self.queue enqueue:[self makeFrame]];
                    [self.queue enqueue:[self makeFrame] withSlackSize:3];
                    [NSThread sleepForTimeInterval:0.001];
                }
            });

            // Consumer
            dispatch_async(consumerQ, ^{
                for (int expected = 0; expected < TotalFrames; expected++) {
                    [self.queue dequeueWithTimeout:1.0f];
                    [dequeueAll fulfill];
                }
            });

            // Wait up to 10s for all frames to be consumed
            [self waitForExpectationsWithTimeout:100.0 handler:^(NSError * _Nullable error) {
                if (error) {
                    XCTFail(@"Timed out waiting for consumer: %@", error);

                    [self.queue clear];
                }
            }];
        }];
    }
}

@end
