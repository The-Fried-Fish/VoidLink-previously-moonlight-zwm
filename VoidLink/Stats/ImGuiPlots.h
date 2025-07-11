//
//  ImGuiPlots.h
//  VoidLink
//
//  Created by Mason Chen on 2025/7/11.
//  Copyright © 2025 Moonlight Game Streaming Project. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

#import "FloatBuffer.h"
#import "Plot.h"

@interface ImGuiPlots : NSObject

struct PlotDef {
    FloatBuffer * _Nonnull buffer;
    const char * _Nonnull title;
    PlotSide side;
    PlotLabelType labelType;
    const char * _Nonnull unit;
    double scaleMin, scaleMax, scaleTarget;
    float minY;
    float maxY;
};

@property (nonatomic) struct PlotDef * _Nonnull plots;

+ (instancetype _Nonnull)sharedInstance;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
+ (instancetype _Nonnull)new NS_UNAVAILABLE;

- (void)observeFloat:(int)plotId value:(CFTimeInterval)value;
- (void)observeFloatReturnMetrics:(int)plotId value:(CFTimeInterval)value plotMetrics:(PlotMetrics * _Nullable)plotMetrics;

@end
