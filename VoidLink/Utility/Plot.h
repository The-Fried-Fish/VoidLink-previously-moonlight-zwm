typedef enum {
    PACING_MODE_VSYNC,
    PACING_MODE_PTS
} FramePacingMode;

typedef enum {
    PLOT_FRAMETIME = 0,
    PLOT_HOST_FRAMETIME,
    PLOT_QUEUED_FRAMES,
    PLOT_DROPPED,

    PLOT_DECODE,
    PlotCount
} PlotType;

typedef enum {
    PLOT_LABEL_MIN_MAX_AVG = 0,
    PLOT_LABEL_MIN_MAX_AVG_INT,
    PLOT_LABEL_TOTAL_INT
} PlotLabelType;

typedef enum {
    PLOT_HIDDEN,
    PLOT_LEFT,
    PLOT_RIGHT
} PlotSide;

typedef struct {
    float min;
    float max;
    float avg;
    float total;
    int nsamples;
    float samplerate;
} PlotMetrics;

typedef enum {
    RENDER_METAL = 0,
    RENDER_AVSB
} RenderingBackend;

typedef struct {
    CFTimeInterval startTime;
    CFTimeInterval endTime;
    int totalFrames;
    int receivedFrames;
    int networkDroppedFrames;
    int totalHostProcessingLatency;
    int framesWithHostProcessingLatency;
    int maxHostProcessingLatency;
    int minHostProcessingLatency;
    PlotMetrics decodeMetrics;
    PlotMetrics frameQueueMetrics;
    PlotMetrics frameDropMetrics;
    NSString *renderingBackendString;
} video_stats_t;
