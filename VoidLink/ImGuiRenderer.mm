#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import "ImGuiRenderer.h"
#import "ImGuiPlots.h"

// This will fully disable ImGui by compiling it out. The in-app setting enableGraphs
// will also remove all ImGui overhead.
//#define IMGUI_DISABLE

// If this is defined, ImGui takes over all touch control while using the app.
// This is only needed if you want to enable and interact with the demo. I'm sure it's possible
// to pass-through touch events when touching non-ImGui portions of the screen
// but I couldn't figure it out. I did not try to get controller support working.
//#define IMGUI_STEALS_TOUCH

#import "imgui.h"
#import "imgui_impl_metal.h"

// ImGui code needs to live in this file because it's an Objective-C++ class, and can call C++ code.

@implementation ImGuiRenderer

-(nonnull instancetype)initWithFrame:(CGRect)bounds
                           streamFps:(int)streamFps
                        enableGraphs:(BOOL)enableGraphs
                        graphOpacity:(int)graphOpacity
{
    self = [super init];

    _enableGraphs = enableGraphs;
    _graphOpacity = (float)(graphOpacity / 100.0);
    _bounds = bounds;
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    _plots = [ImGuiPlots sharedInstance].plots;

    return self;
}

-(void)ImGui_Init {
    // self-contained startup for ImGui so it can be dynamically toggled easily

#if !defined(IMGUI_DISABLE)
    if (_enableGraphs && !_imguiRunning) {
        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO(); (void)io;
        // io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
        // io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

        ImGui::StyleColorsDark();

        ImGui_ImplMetal_Init(_device);
        _imguiRunning = YES;
    }
#endif
}

-(void)ImGui_Deinit {
    if (_imguiRunning) {
#if !defined(IMGUI_DISABLE)
        ImGui_ImplMetal_Shutdown();
        ImGui::DestroyContext();
#endif
        _imguiRunning = NO;
    }
}

-(MTKView *)mtkView
{
    return (MTKView *)self.view;
}

-(void)loadView
{
    self.view = [[MTKView alloc] initWithFrame:self.bounds];
}

-(void)viewDidLoad
{
    [super viewDidLoad];

    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.preferredFramesPerSecond = 60; // ImGui overlay will always render at this rate
    self.mtkView.opaque = NO;
    self.mtkView.enableSetNeedsDisplay = NO;

    if (_enableGraphs) {
        [self ImGui_Init];
        self.mtkView.paused = NO;
    }
    else {
        self.mtkView.paused = YES;
    }
}

// start & stop are used to show/hide graphs when swiping stats in or out
-(void)start {
    [self ImGui_Init];
    if (_enableGraphs) {
        self.mtkView.paused = NO;
    }
}

-(void)show {
    [self.mtkView setHidden:NO];
}

-(void)hide {
    [self.mtkView setHidden:YES];
}

-(void)stop {
    self.mtkView.paused = YES;
    [self ImGui_Deinit];
}

// Only called when mtkView.paused is false
- (void)drawInMTKView:(MTKView *)view
{
#if !defined(IMGUI_DISABLE)
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor == nil) {
        [commandBuffer commit];
        return;
    }

    // Start the Dear ImGui frame
    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui::NewFrame();

    // 1. Show the big demo window (Most of the sample code is in ImGui::ShowDemoWindow()! You can browse its code to learn more about Dear ImGui!).
    static bool show_demo_window = false;
    if (show_demo_window)
        ImGui::ShowDemoWindow(&show_demo_window);

    // Custom Moonlight stuff goes here
    [self drawStatsGraphs];

    // Rendering
    ImGui::Render();
    ImDrawData* draw_data = ImGui::GetDrawData();

    // This looks silly when clear_color is all zeros but the original example uses this method to tint or make transparent the rest of the viewport
    static ImVec4 clear_color = ImVec4(0, 0, 0, 0);
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);

    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder pushDebugGroup:@"Dear ImGui rendering"];
    ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];

    // Present
#if TARGET_OS_SIMULATOR
    [commandBuffer presentDrawable:view.currentDrawable];
#else
    [commandBuffer presentDrawable:view.currentDrawable afterMinimumDuration:1.0 / view.preferredFramesPerSecond];
#endif
    [commandBuffer commit];
#endif
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    [self ImGui_Deinit];
}

//-----------------------------------------------------------------------------------
// Input processing
//-----------------------------------------------------------------------------------

// This touch mapping is super cheesy/hacky. We treat any touch on the screen
// as if it were a depressed left mouse button, and we don't bother handling
// multitouch correctly at all. This causes the "cursor" to behave very erratically
// when there are multiple active touches. But for demo purposes, single-touch
// interaction actually works surprisingly well.
#if !defined(IMGUI_DISABLE)
#  if defined(IMGUI_STEALS_TOUCH)
-(BOOL)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
    io.AddMousePosEvent(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
            hasActiveTouch = YES;
            break;
        }
    }
    io.AddMouseButtonEvent(0, hasActiveTouch);
    return YES;
}
#  endif
#endif

#if !defined(IMGUI_DISABLE)
#  if defined(IMGUI_STEALS_TOUCH)
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event]; }
-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event]; }
-(void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event  { [self updateIOWithTouchEvent:event]; }
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event]; }
#  endif
#endif

#if !defined(IMGUI_DISABLE)
inline static float getValue(void *buffer, int idx) {
    float *fbuffer = (float *)buffer;
    float v = fbuffer[idx];
    // clip the top of frametime graphs so they're less ugly
    if (v > 50)
        v = 49.9;

    return v;
}

- (void) drawStatsGraphs {
    // we malloc a buffer for frametimes once and reuse it
    static float * buffers[8] = {
        (float *)malloc(sizeof(float) * 512),
        (float *)malloc(sizeof(float) * 512),
        (float *)malloc(sizeof(float) * 512),
        (float *)malloc(sizeof(float) * 512),
        (float *)malloc(sizeof(float) * 512),
        (float *)malloc(sizeof(float) * 512),
        (float *)malloc(sizeof(float) * 512),
        (float *)malloc(sizeof(float) * 512)
    };

    ImGuiIO &io = ImGui::GetIO();

    // Try to make the graphs suck less on common device sizes
    float graphW = 0.0f;
    float graphH = 0.0f;
    switch ((int)io.DisplaySize.x) {
        case 1920: // ATV 4K 1920x1080 2x
            graphW = 525.0f; graphH = 80.0f; break;
        case 1376: // iPad Pro 1376x1032 2x
            graphW = 450.0f; graphH = 45.0f; break;
        case 1366: // iPad Air 1366x1024 2x
            graphW = 446.0f; graphW = 44.0f; break;
        case 1194: // Vision Pro (iPad mode) 1194x834 2x
            graphW = 379.0f; graphH = 45.0f; break;
        case 1133: // iPad Mini 1133x744 2x
            graphW = 360.0f; graphH = 45.0f; break;
        case 874: // iPhone 16 Pro 874x402 3x
            graphW = 275.0f; graphH = 45.0f; break;
        // TODO:
        default:
            float x = io.DisplaySize.x;
            float y = io.DisplaySize.y;
            if (io.DisplayFramebufferScale.x > 2.0f) {
                x = x * io.DisplayFramebufferScale.x / 2.0f;
                y = y * io.DisplayFramebufferScale.y / 2.0f;
            }
            graphW = x * 0.327f;
            graphH = y * 0.044f;
    }

    LogOnce(LOG_I, @"Drawing graphs of size %.1f x %.1f in viewport %.1f x %.1f scale %.0f,%.0f using opacity %.2f",
            graphW, graphH,
            io.DisplaySize.x, io.DisplaySize.y,
            io.DisplayFramebufferScale.x, io.DisplayFramebufferScale.y,
            _graphOpacity);

    // Left side - 2 graphs
    ImVec2 windowSize(graphW, (graphH * 4));
    ImVec2 windowPos(10.0f, 10.0f);
    ImGui::SetNextWindowPos(windowPos, ImGuiCond_Always, ImVec2(0.0f, 0.0f));  // pivot (0,0) = top-left
    ImGui::SetNextWindowSize(windowSize, ImGuiCond_Always);
    ImGuiWindowFlags flags = ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoNavFocus | ImGuiWindowFlags_NoBackground |
        ImGuiWindowFlags_NoSavedSettings;
    ImGui::Begin("##StatsLeft", nullptr, flags);

    // Dimensions of each graph
    ImVec2 avail = ImGui::GetContentRegionAvail();
    float fullW = avail.x;

    // First 2 on left
    for (int i = 0; i < PlotCount; i++) {
        if (self.plots[i].side != PLOT_LEFT) continue;

        float minY = 0.0f;
        float maxY = 0.0f;
        int countF = [self.plots[i].buffer copyValuesIntoBuffer:buffers[i] min:&minY max:&maxY];
        float avgF = [self.plots[i].buffer averageValue];
        if (!countF) {
            continue;
        }

        // Ugly, but can't get ImPlot to build for iOS
        char label[64];
        switch (self.plots[i].labelType) {
            case PLOT_LABEL_MIN_MAX_AVG:
                sprintf(label, "%s  %.1f/%.1f/%.1f %s", self.plots[i].title, minY, maxY, avgF, self.plots[i].unit);
                break;
            case PLOT_LABEL_MIN_MAX_AVG_INT:
                sprintf(label, "%s  %d/%d/%.1f %s", self.plots[i].title, (int)minY, (int)maxY, avgF, self.plots[i].unit);
                break;
            case PLOT_LABEL_TOTAL_INT:
                sprintf(label, "%s  %d %s", self.plots[i].title, (int)[self.plots[i].buffer total], self.plots[i].unit);
                break;
        }
        float scaleMin = FLT_MAX;
        float scaleMax = FLT_MAX;
        if (self.plots[i].scaleTarget) {
            // optionally center the graph on a target such as the ideal frametime
            float ideal = (float)self.plots[i].scaleTarget;
            scaleMin = ideal - (2 * ideal);
            scaleMax = ideal + (2 * ideal);
        }
        if (self.plots[i].scaleMin)
            scaleMin = self.plots[i].scaleMin;
        if (self.plots[i].scaleMax)
            scaleMax = self.plots[i].scaleMax;
        ImGui::PushID(i);
        ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0.16f, 0.29f, 0.48f, _graphOpacity)); // dark
        //ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0.43f, 0.43f, 0.43f, 0.39f)); // classic
        ImGui::PushStyleColor(ImGuiCol_PlotLines, ImVec4(0.0f, 1.0f, 0.0f, 1.0f)); // green
        ImGui::PlotLines("##xx", buffers[i], countF, 0, (countF > 0 ? label : "no data"), scaleMin, scaleMax, ImVec2(fullW, graphH));
        ImGui::PopStyleColor(2);
        ImGui::PopID();
    }
    ImGui::End();

    // Right side - 2 graphs
    windowPos = ImVec2(io.DisplaySize.x - 10.0f, 10.0f);    // 10px margin
    ImGui::SetNextWindowPos(windowPos, ImGuiCond_Always, ImVec2(1.0f, 0.0f));  // pivot (1,0) = top-right
    ImGui::SetNextWindowSize(windowSize, ImGuiCond_Always);
    flags = ImGuiWindowFlags_NoDecoration |
    ImGuiWindowFlags_NoMove |
    ImGuiWindowFlags_NoNavFocus |
    ImGuiWindowFlags_NoBackground |
    ImGuiWindowFlags_NoSavedSettings;
    ImGui::Begin("##StatsRight", nullptr, flags);

    for (int i = 2; i < PlotCount; i++) {
        if (self.plots[i].side != PLOT_RIGHT) continue;

        float minY, maxY;
        int countF = [self.plots[i].buffer copyValuesIntoBuffer:buffers[i] min:&minY max:&maxY];
        float avgF = [self.plots[i].buffer averageValue];
        if (!countF) {
            continue;
        }

        // Ugly, but can't get ImPlot to build for iOS
        char label[64];
        switch (self.plots[i].labelType) {
            case PLOT_LABEL_MIN_MAX_AVG:
                sprintf(label, "%s  %.1f/%.1f/%.1f %s", self.plots[i].title, minY, maxY, avgF, self.plots[i].unit);
                break;
            case PLOT_LABEL_MIN_MAX_AVG_INT:
                sprintf(label, "%s  %d/%d/%.1f %s", self.plots[i].title, (int)minY, (int)maxY, avgF, self.plots[i].unit);
                break;
            case PLOT_LABEL_TOTAL_INT:
                sprintf(label, "%s  %d %s", self.plots[i].title, (int)[self.plots[i].buffer total], self.plots[i].unit);
                break;
        }
        float scaleMin = FLT_MAX;
        float scaleMax = FLT_MAX;
        if (self.plots[i].scaleTarget) {
            // optionally center the graph on a target such as the ideal frametime
            float ideal = (float)self.plots[i].scaleTarget;
            scaleMin = ideal - (2 * ideal);
            scaleMax = ideal + (2 * ideal);
        }
        if (self.plots[i].scaleMin)
            scaleMin = self.plots[i].scaleMin;
        if (self.plots[i].scaleMax)
            scaleMax = self.plots[i].scaleMax;
        ImGui::PushID(i);
        ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0.16f, 0.29f, 0.48f, _graphOpacity)); // dark
        ImGui::PushStyleColor(ImGuiCol_PlotLines, ImVec4(0.0f, 1.0f, 0.0f, 1.0f)); // green
        if (i == PLOT_FRAMETIME || i == PLOT_HOST_FRAMETIME) {
            // getValue() clips at max 50
            ImGui::PlotLines("##xx", getValue, buffers[i], countF, 0, (countF > 0 ? label : "no data"), scaleMin, scaleMax, ImVec2(fullW, graphH));
        } else {
            ImGui::PlotLines("##xx", buffers[i], countF, 0, (countF > 0 ? label : "no data"), scaleMin, scaleMax, ImVec2(fullW, graphH));
        }
        ImGui::PopStyleColor(2);
        ImGui::PopID();
    }
    ImGui::End();

#endif
}

@end

