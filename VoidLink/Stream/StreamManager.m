//
//  StreamManager.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.7.9
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "StreamManager.h"
#import "CryptoManager.h"
#import "HttpManager.h"
#import "Plot.h"
#import "Utils.h"
#import "DataManager.h"

#import "StreamView.h"
#import "ServerInfoResponse.h"
#import "HttpResponse.h"
#import "HttpRequest.h"
#import "IdManager.h"
#import "LocalizationHelper.h"

#include <Limelight.h>

@implementation StreamManager {
    StreamConfiguration* _config;

    UIView* _renderView;
    id<ConnectionCallbacks> _callbacks;
    Connection* _connection;
    VideoDecoderRenderer* _videoRenderer;
}

- (id) initWithConfig:(StreamConfiguration*)config renderView:(UIView*)view connectionCallbacks:(id<ConnectionCallbacks>)callbacks {
    self = [super init];
    _config = config;
    _renderView = view;
    _callbacks = callbacks;
    _config.riKey = [Utils randomBytes:16];
    _config.riKeyId = arc4random();
    return self;
}

- (void)main {
    [CryptoManager generateKeyPairUsingSSL];
    
    HttpManager* hMan = [[HttpManager alloc] initWithAddress:_config.host httpsPort:_config.httpsPort
                                                     serverCert:_config.serverCert];
    
    ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];
    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                       fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
    NSString* pairStatus = [serverInfoResp getStringTag:@"PairStatus"];
    NSString* appversion = [serverInfoResp getStringTag:@"appversion"];
    NSString* gfeVersion = [serverInfoResp getStringTag:@"GfeVersion"];
    NSString* serverState = [serverInfoResp getStringTag:@"state"];
    if (![serverInfoResp isStatusOk]) {
        [_callbacks launchFailed:serverInfoResp.statusMessage];
        return;
    }
    else if (pairStatus == NULL || appversion == NULL || serverState == NULL) {
        [_callbacks launchFailed:@"Failed to connect to PC"];
        return;
    }
    
    if (![pairStatus isEqualToString:@"1"]) {
        // Not paired
        [_callbacks launchFailed:@"Device not paired to PC"];
        return;
    }
    
    // Only perform this check on GFE (as indicated by MJOLNIR in state value)
    if ((_config.width > 4096 || _config.height > 4096) && [serverState containsString:@"MJOLNIR"]) {
        // Pascal added support for 8K HEVC encoding support. Maxwell 2 could encode HEVC but only up to 4K.
        // We can't directly identify Pascal, but we can look for HEVC Main10 which was added in the same generation.
        NSString* codecSupport = [serverInfoResp getStringTag:@"ServerCodecModeSupport"];
        if (codecSupport == nil || !([codecSupport intValue] & 0x200)) {
            [_callbacks launchFailed:@"Your host PC's GPU doesn't support streaming video resolutions over 4K."];
            return;
        }
    }
    
    // Populate the config's version fields from serverinfo
    _config.appVersion = appversion;
    _config.gfeVersion = gfeVersion;
    
    // resumeApp and launchApp handle calling launchFailed
    NSString* sessionUrl;
    if ([serverState hasSuffix:@"_SERVER_BUSY"]) {
        // App already running, resume it
        if (![self resumeApp:hMan receiveSessionUrl:&sessionUrl]) {
            return;
        }
    } else {
        // Start app
        if (![self launchApp:hMan receiveSessionUrl:&sessionUrl]) {
            return;
        }
    }
    
    // Populate RTSP session URL from launch/resume response
    _config.rtspSessionUrl = sessionUrl;
    
    // Initializing the renderer must be done on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_videoRenderer = [[VideoDecoderRenderer alloc] initWithView:self->_renderView callbacks:self->_callbacks streamAspectRatio:(float)self->_config.width / (float)self->_config.height];

        self->_connection = [[Connection alloc] initWithConfig:self->_config renderer:self->_videoRenderer connectionCallbacks:self->_callbacks];
        NSOperationQueue* opQueue = [[NSOperationQueue alloc] init];
        [opQueue addOperation:self->_connection];
    });
}

- (void) stopStream
{
    [_connection terminate];
}

- (BOOL) launchApp:(HttpManager*)hMan receiveSessionUrl:(NSString**)sessionUrl {
    HttpResponse* launchResp = [[HttpResponse alloc] init];
    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:launchResp withUrlRequest:[hMan newLaunchOrResumeRequest:@"launch" config:_config]]];
    NSString *gameSession = [launchResp getStringTag:@"gamesession"];
    if (![launchResp isStatusOk]) {
        [_callbacks launchFailed:launchResp.statusMessage];
        Log(LOG_E, @"Failed Launch Response: %@", launchResp.statusMessage);
        return FALSE;
    } else if (gameSession == NULL || [gameSession isEqualToString:@"0"]) {
        [_callbacks launchFailed:@"Failed to launch app"];
        Log(LOG_E, @"Failed to parse game session");
        return FALSE;
    }
    
    *sessionUrl = [launchResp getStringTag:@"sessionUrl0"];
    return TRUE;
}

- (BOOL) resumeApp:(HttpManager*)hMan receiveSessionUrl:(NSString**)sessionUrl {
    HttpResponse* resumeResp = [[HttpResponse alloc] init];
    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:resumeResp withUrlRequest:[hMan newLaunchOrResumeRequest:@"resume" config:_config]]];
    NSString* resume = [resumeResp getStringTag:@"resume"];
    if (![resumeResp isStatusOk]) {
        [_callbacks launchFailed:resumeResp.statusMessage];
        Log(LOG_E, @"Failed Resume Response: %@", resumeResp.statusMessage);
        return FALSE;
    } else if (resume == NULL || [resume isEqualToString:@"0"]) {
        [_callbacks launchFailed:@"Failed to resume app"];
        Log(LOG_E, @"Failed to parse resume response");
        return FALSE;
    }
    
    *sessionUrl = [resumeResp getStringTag:@"sessionUrl0"];
    return TRUE;
}

- (NSString*) getStatsOverlayText: (uint16_t) overlayLevel {
    video_stats_t stats;

    if (!_connection) {
        return nil;
    }
    
    if (![_connection getVideoStats:&stats]) {
        return nil;
    }
    
    uint32_t rtt, variance;
    NSString* latencyString;
    if (LiGetEstimatedRttInfo(&rtt, &variance)) {
        latencyString = [LocalizationHelper localizedStringForKey:@"%3u ms (var: %3u ms)", rtt, variance];
    }
    else {
        latencyString = @"N/A";
    }
    
    NSString* hostProcessingString;
    if (stats.framesWithHostProcessingLatency != 0) {
        hostProcessingString = [LocalizationHelper localizedStringForKey:@"Host processing latency min/max/avg: %.1f/%.1f/%.1f ms\n",
                                stats.minHostProcessingLatency / 10.f,
                                stats.maxHostProcessingLatency / 10.f,
                                (float)stats.totalHostProcessingLatency / stats.framesWithHostProcessingLatency / 10.f];
    }
    else {
        // If all frames are duplicates this can happen, but let's avoid having the whole stats area change height
        hostProcessingString = @"Host processing latency min/max/avg: -/-/- ms\n";
    }
    
    float interval = stats.endTime - stats.startTime;
    
    // Get frame pacing mode
    DataManager* dataMan = [[DataManager alloc] init];
    FramePacingMode framePacingMode = [[dataMan getSettings].framePacingMode integerValue];

    // Calculate FPS differently based on pacing mode
    float fps;
    if (framePacingMode == FramePacingModeLegacy || framePacingMode == FramePacingModeOff) {
        fps = stats.totalFrames / interval;
    } else {
        float scalePlotMetrics = stats.frameDropMetrics.nsamples > 0 ? ((float)stats.frameDropMetrics.nsamples / stats.totalFrames) : 1.0f;
        fps = (stats.totalFrames - stats.networkDroppedFrames - (stats.frameDropMetrics.total / scalePlotMetrics)) / interval;
    }

    double avgVideoMbps = [_connection getBwTracker].averageMbps;
    double peakVideoMbps = [_connection getBwTracker].peakMbps;

    if(overlayLevel == 1) return [LocalizationHelper localizedStringForKey:@"simplifiedOsdText",
                 fps,
                 stats.networkDroppedFrames / interval,
                 avgVideoMbps,
                 latencyString];
    else {
        if (framePacingMode == FramePacingModeLegacy || framePacingMode == FramePacingModeOff) {
            NSString* rendererWithPacing = stats.renderingBackendString;
            if ([stats.renderingBackendString isEqualToString:@"AVSampleBuffer"]) {
                if (framePacingMode == FramePacingModeOff) {
                    rendererWithPacing = @"AVSampleBuffer (No Pacing)";
                } else {
                    rendererWithPacing = @"AVSampleBuffer (Legacy Pacing)";
                }
            }
            
            return [LocalizationHelper localizedStringForKey:@"Video stream: %dx%d %.2f FPS (Codec: %@)\n"
                     "Bitrate: %.1f Mbps, Peak: %.1f\n"
                     "%@"
                     "Renderer: %@\n"
                     "Frames dropped by network: %.1f%%\n"
                     "Average network latency: %@",
                     _config.width,
                     _config.height,
                     fps,
                     [_connection getActiveCodecName],
                     avgVideoMbps, peakVideoMbps,
                     hostProcessingString,
                     rendererWithPacing,
                     (stats.networkDroppedFrames / stats.totalFrames) * 100.0,
                     latencyString];
        } else {
            NSString* rendererWithPacing = stats.renderingBackendString;
            if ([stats.renderingBackendString isEqualToString:@"AVSampleBuffer"]) {
                rendererWithPacing = @"AVSampleBuffer (Queue Pacing)";
            }
            
            return [LocalizationHelper localizedStringForKey:@"Video stream: %dx%d %.2f FPS (Codec: %@)\n"
                     "Bitrate: %.1f Mbps, Peak: %.1f, Frames buffered: %.1f\n"
                     "%@"
                     "Renderer: %@\n"
                     "Frames dropped by network/pacing jitter: %.1f%% / %.1f%%\n"
                     "Average network latency: %@\n"
                     "Decode time: %.2f/%.2f/%.2f ms",
                     _config.width,
                     _config.height,
                     fps,
                     [_connection getActiveCodecName],
                     avgVideoMbps, peakVideoMbps, stats.frameQueueMetrics.avg,
                     hostProcessingString,
                     rendererWithPacing,
                     (stats.networkDroppedFrames / stats.totalFrames) * 100.0,
                     stats.frameDropMetrics.nsamples > 0 ? (stats.frameDropMetrics.total / stats.frameDropMetrics.nsamples) * 100.0 : 0.0f,
                     latencyString,
                     stats.decodeMetrics.min, stats.decodeMetrics.max, stats.decodeMetrics.avg];
        }
    }
}

@end
