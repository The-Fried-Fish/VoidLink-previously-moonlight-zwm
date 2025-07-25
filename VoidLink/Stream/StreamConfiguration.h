//
//  StreamConfiguration.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.8.10
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

@interface StreamConfiguration : NSObject

@property NSString* host;
@property unsigned short httpsPort;
@property NSString* appVersion;
@property NSString* gfeVersion;
@property NSString* appID;
@property NSString* appName;
@property NSString* rtspSessionUrl;
@property int serverCodecModeSupport;
@property BOOL enableYUV444;
@property BOOL enablePIP;
@property int width;
@property int height;
@property int frameRate;
@property int bitRate;
@property int riKeyId;
@property NSData* riKey;
@property int gamepadMask;
@property BOOL optimizeGameSettings;
@property BOOL playAudioOnPC;
@property BOOL swapABXYButtons;
@property BOOL asyncNativeTouchPriority;
@property int gyroMode;
@property int emulatedControllerType;
@property int audioConfiguration;
@property int supportedVideoFormats;
@property BOOL multiController;
@property BOOL useFramePacing;
@property NSData* serverCert;
@property int localMousePointerMode;

@end
