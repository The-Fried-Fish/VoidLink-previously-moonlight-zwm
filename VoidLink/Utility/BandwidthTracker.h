#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The BandwidthTracker class tracks network bandwidth usage over a sliding time window (default 10s).
 *
 * Byte totals are grouped into fixed time interval buckets (default 250ms). This provides an element of smoothing
 * and deals well with spikes.
 *
 * GetAverageMbps() is calculated using the 25% most recent fully completed buckets. The default settings will
 * return an average of the past 2.5s of data, ignoring the in-progress bucket. Using only 2.5s of data for the
 * average provides a good balance of reactivity and smoothness.
 *
 * GetPeakMbps() returns the peak bandwidth seen during any one bucket interval across the full time window.
 *
 * All public methods are thread safe. A typical use case is calling AddBytes() in a data processing thread while
 * calling GetAverageMbps() from a UI thread.
 *
 * This class was mostly auto-converted from the C++ version to use Obj-C APIs and naming conventions.
 */
@interface BandwidthTracker : NSObject

/**
 * @brief Constructs a new BandwidthTracker object.
 *
 * Initializes the tracker to maintain statistics over a sliding window of time.
 * The window is divided into buckets of fixed duration (bucketIntervalMs).
 *
 * @param windowSeconds The duration of the tracking window in seconds. Default is 10 seconds.
 * @param bucketIntervalMs The interval for each bucket in milliseconds. Default is 250 ms.
 */
- (instancetype)initWithWindowSeconds:(NSUInteger)windowSeconds
                     bucketIntervalMs:(NSUInteger)bucketIntervalMs NS_DESIGNATED_INITIALIZER;

/// Convenience init → defaults to a 10 s window with 250 ms buckets.
- (instancetype)init;

/**
 * @brief Record bytes that were received or sent.
 *
 * This method updates the corresponding bucket for the current time interval with the new data.
 * It is thread-safe. Bytes are associated with the bucket for "now" and it is not possible to
 * submit data for old buckets. This function should be called as needed at the time the bytes
 * were received. Callers should not maintain their own byte totals.
 *
 * @param bytes The number of bytes to add.
 */
- (void)addBytes:(NSUInteger)bytes;

/**
 * @brief Computes and returns the average bandwidth in Mbps for the most recent 25% of buckets.
 *
 * @return The average bandwidth in megabits per second.
 */
- (double)averageMbps;

/**
 * @brief Returns the peak bandwidth in Mbps observed in any single bucket within the current window.
 *
 * This value represents the highest instantaneous throughput measured over one bucket interval.
 *
 * @return The peak bandwidth in megabits per second.
 */
- (double)peakMbps;

/**
 * @brief Retrieves the duration of the tracking window.
 *
 * This is useful when displaying the length of the peak, e.g.
 * @code
 *   printf("Bitrate: %.1f Mbps Peak (%us): %.1f\n",
 *          [bw averageMbps], [bw windowSeconds], [bw peakMbps]);
 * @endcode
 *
 * @return The window duration in seconds.
 */
- (NSUInteger)windowSeconds;

@end

NS_ASSUME_NONNULL_END
