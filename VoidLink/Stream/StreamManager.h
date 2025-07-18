//
//  StreamManager.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2025.2.1
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

#import "StreamConfiguration.h"
#import "Connection.h"

@interface StreamManager : NSOperation

@property (nonatomic, strong, readonly) VideoDecoderRenderer *videoRenderer;

- (id) initWithConfig:(StreamConfiguration*)config renderView:(UIView*)view connectionCallbacks:(id<ConnectionCallbacks>)callback;

- (void) stopStream;

- (NSString*) getStatsOverlayText: (uint16_t) overlayLevel;

@end
