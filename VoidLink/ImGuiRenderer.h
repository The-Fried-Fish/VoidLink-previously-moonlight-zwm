#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

#import "FloatBuffer.h"
#import "Plot.h"

typedef void (^MetricsHandler)(int plotId, CFTimeInterval value);

@interface ImGuiRenderer : UIViewController
@end

@interface ImGuiRenderer () <MTKViewDelegate>
@property (nonatomic) CGRect bounds;
@property (nonatomic, readonly) MTKView * _Nonnull mtkView;
@property (nonatomic, strong) id <MTLDevice> _Nonnull device;
@property (nonatomic, strong) id <MTLCommandQueue> _Nonnull commandQueue;
@property (nonatomic) struct PlotDef * _Nonnull plots;
@property (nonatomic) FloatBuffer * _Nonnull frametimes;
@property (nonatomic) BOOL enableGraphs;
@property (nonatomic) float graphOpacity;
@property (nonatomic) BOOL imguiRunning;
@property (nonatomic) MetricsHandler _Nonnull metricsHandler;

-(nonnull instancetype) initWithFrame:(CGRect)bounds
                            streamFps:(int)streamFps
                         enableGraphs:(BOOL)enableGraphs
                         graphOpacity:(int)graphOpacity;
-(void) start;
-(void) show;
-(void) hide;
-(void) stop;
@end
