#import "ImGuiPlots.h"

@implementation ImGuiPlots

+ (instancetype)sharedInstance {
    static ImGuiPlots *sharedInstance = nil;
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

-(nonnull instancetype)_initSingleton
{
    self = [super init];
    if (self) {
        _plots = (PlotDef *)calloc(PlotCount, sizeof(PlotDef));

        _plots[PLOT_FRAMETIME] = {
            .title  = "Frametime",
            .side   = PLOT_LEFT,
            .unit   = "ms",
            .scaleMin = (1000.0 / 120) - 1,
            .scaleMax = 50.0f, // (1000.0 / streamFps) * 3,
            .buffer = [[FloatBuffer alloc] initWithCapacity:512]
        };

        _plots[PLOT_HOST_FRAMETIME] = {
            .title  = "Host Frametime",
            .side   = PLOT_LEFT,
            .unit   = "ms",
            .scaleMin = (1000.0 / 120) - 1,
            .scaleMax = 50.0f, // (1000.0 / streamFps) * 3,
            .buffer = [[FloatBuffer alloc] initWithCapacity:512]
        };

        _plots[PLOT_QUEUED_FRAMES] = {
            .title       = "Frame queue",
            .side        = PLOT_RIGHT,
            .labelType   = PLOT_LABEL_MIN_MAX_AVG_INT,
            .unit        = "",
            .scaleMin    = -0.5,
            .scaleMax    = 15,
            .buffer      = [[FloatBuffer alloc] initWithCapacity:512]
        };

        _plots[PLOT_DROPPED] = {
            .title     = "Frames dropped",
            .side      = PLOT_RIGHT,
            .labelType = PLOT_LABEL_TOTAL_INT,
            .unit      = "",
            .scaleTarget = 2,
            .buffer    = [[FloatBuffer alloc] initWithCapacity:512]
        };

        // not graphed, but used for stats

        _plots[PLOT_DECODE] = {
            .title     = "Decode time",
            .labelType = PLOT_LABEL_MIN_MAX_AVG,
            .unit      = "ms",
            .buffer    = [[FloatBuffer alloc] initWithCapacity:512]
        };
    }

    return self;
}

- (void) observeFloat:(int)plotId value:(CFTimeInterval)value {
    [_plots[plotId].buffer addValue:(float)value];
}

- (void) observeFloatReturnMetrics:(int)plotId value:(CFTimeInterval)value plotMetrics:(PlotMetrics *)plotMetrics {
    [_plots[plotId].buffer addValue:(float)value];
    if (plotMetrics != nil) {
        [_plots[plotId].buffer copyMetrics:plotMetrics];
    }
}

@end
