//
//  TemporarySettings.m
//  Moonlight
//
//  Created by Cameron Gutman on 12/1/15.
//  Copyright © 2015 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.1
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "TemporarySettings.h"
#import "OnScreenControls.h"

@implementation TemporarySettings

- (id) initFromSettings:(Settings*)settings {
    self = [self init];
    
    self.parent = settings;
    
#if TARGET_OS_TV
    // Apply default values from our Root.plist
    NSString* settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    NSDictionary* settingsData = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray* preferences = [settingsData objectForKey:@"PreferenceSpecifiers"];
    NSMutableDictionary* defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for (NSDictionary* prefSpecification in preferences) {
        NSString* key = [prefSpecification objectForKey:@"Key"];
        if (key != nil) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
    
    self.bitrate = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"bitrate"]];
    assert([self.bitrate intValue] != 0);
    self.framerate = [NSNumber numberWithDouble:[[NSUserDefaults standardUserDefaults] doubleForKey:@"framerate"]];
    assert([self.framerate doubleValue] != 0.0);
    self.audioConfig = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"audioConfig"]];
    assert([self.audioConfig intValue] != 0);
    self.preferredCodec = (typeof(self.preferredCodec))[[NSUserDefaults standardUserDefaults] integerForKey:@"preferredCodec"];
    self.enableYUV444 = [[NSUserDefaults standardUserDefaults] boolForKey:@"enableYUV444"];
    self.enablePIP = [[NSUserDefaults standardUserDefaults] boolForKey:@"enablePIP"];
    self.fullRange = [[NSUserDefaults standardUserDefaults] boolForKey:@"fullRange"];
    self.frameQueueSize = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"frameQueueSize"]];
    self.playAudioOnPC = [[NSUserDefaults standardUserDefaults] boolForKey:@"audioOnPC"];
    self.enableHdr = [[NSUserDefaults standardUserDefaults] boolForKey:@"enableHdr"];
    self.optimizeGames = [[NSUserDefaults standardUserDefaults] boolForKey:@"optimizeGames"];
    self.multiController = [[NSUserDefaults standardUserDefaults] boolForKey:@"multipleControllers"];
    self.swapABXYButtons = [[NSUserDefaults standardUserDefaults] boolForKey:@"swapABXYButtons"];
    self.btMouseSupport = [[NSUserDefaults standardUserDefaults] boolForKey:@"btMouseSupport"];
    self.statsOverlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"statsOverlay"];
    self.enableGraphs = [[NSUserDefaults standardUserDefaults] boolForKey:@"enableGraphs"];
    self.graphOpacity = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"graphOpacity"]];
    self.renderingBackend = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"renderingBackend"]];
    self.framePacingMode = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"framePacingMode"]];

    NSInteger _screenSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"streamResolution"];
    switch (_screenSize) {
        case 0:
            self.height = [NSNumber numberWithInteger:720];
            self.width = [NSNumber numberWithInteger:1280];
            break;
        case 1:
            self.height = [NSNumber numberWithInteger:1080];
            self.width = [NSNumber numberWithInteger:1920];
            break;
        case 2:
            self.height = [NSNumber numberWithInteger:2160];
            self.width = [NSNumber numberWithInteger:3840];
            break;
        case 3:
            self.height = [NSNumber numberWithInteger:1440];
            self.width = [NSNumber numberWithInteger:2560];
            break;
        default:
            abort();
    }
    self.onscreenControls = [NSNumber numberWithInteger:OnScreenControlsLevelOff];
#else
    self.settingsMenuMode = settings.settingsMenuMode;
    self.settingsMenuWidth = settings.settingsMenuWidth;
    self.bitrate = settings.bitrate;
    self.framerate = settings.framerate;
    self.height = settings.height;
    self.width = settings.width;
    self.audioConfig = settings.audioConfig;
    self.preferredCodec = settings.preferredCodec;
    self.enableYUV444 = settings.enableYUV444;
    self.sdrPerformanceWorkaround = settings.sdrPerformanceWorkaround;
    self.enablePIP = settings.enablePIP;
    self.fullColorRange = settings.fullColorRange;
    self.frameQueueSize = settings.frameQueueSize;
    self.enableFrameTimebase  = settings.enableFrameTimebase;
    self.asyncFrameDequeue = settings.asyncFrameDequeue;
    self.playAudioOnPC = settings.playAudioOnPC;
    self.redirectMic = settings.redirectMic;
    self.useBuiltinMic = settings.useBuiltinMic;
    self.enableHdr = settings.enableHdr;
    self.optimizeGames = settings.optimizeGames;
    self.multiController = settings.multiController;
    self.buttonVisualFeedback = settings.buttonVisualFeedback;
    self.touchPointTracking = settings.touchPointTracking;
    self.swapABXYButtons = settings.swapABXYButtons;
    self.onscreenControls = settings.onscreenControls;
    self.gyroMode = settings.gyroMode;
    self.emulatedControllerType = settings.emulatedControllerType;
    self.reverseMouseWheelDirection = settings.reverseMouseWheelDirection;
    self.asyncNativeTouchPriority = settings.asyncNativeTouchPriority;
    self.btMouseSupport = settings.btMouseSupport;
    // self.absoluteTouchMode = settings.absoluteTouchMode;
    self.touchMode = settings.touchMode;
    self.statsOverlayLevel = settings.statsOverlayLevel;
    self.statsOverlayEnabled = settings.statsOverlayEnabled;
    self.keyboardToggleFingers = settings.keyboardToggleFingers;
    self.oscLayoutToolFingers = settings.oscLayoutToolFingers;
    self.slideToSettingsScreenEdge = settings.slideToSettingsScreenEdge;
    self.slideToSettingsDistance = settings.slideToSettingsDistance;
    self.liftStreamViewForKeyboard = settings.liftStreamViewForKeyboard;
    self.showKeyboardToolbar = settings.showKeyboardToolbar;
    self.softKeyboardHeight = settings.softKeyboardHeight;
    self.touchMoveEventInterval = settings.touchMoveEventInterval;
    self.touchPointerVelocityFactor = settings.touchPointerVelocityFactor;
    self.mousePointerVelocityFactor = settings.mousePointerVelocityFactor;
    self.gyroSensitivity = settings.gyroSensitivity;
    self.localVolume = settings.localVolume;
    self.micVolume = settings.micVolume;
    self.pointerVelocityModeDivider = settings.pointerVelocityModeDivider;
    self.unlockDisplayOrientation = settings.unlockDisplayOrientation;
    self.resolutionSelected = settings.resolutionSelected;
    self.externalDisplayMode = settings.externalDisplayMode;
    self.localMousePointerMode = settings.localMousePointerMode;
    self.enableGraphs = settings.enableGraphs;
    self.graphOpacity = settings.graphOpacity;
    self.renderingBackend = settings.renderingBackend;
    self.framePacingMode = settings.framePacingMode;
    self.sendDummyEvent = settings.sendDummyEvent;
    self.rememberFoldState = settings.rememberFoldState;
    self.gyroBiasX = settings.gyroBiasX;
    self.gyroBiasY = settings.gyroBiasY;
    self.gyroBiasZ = settings.gyroBiasZ;
    self.controllerGyroBiasX = settings.controllerGyroBiasX;
    self.controllerGyroBiasY = settings.controllerGyroBiasY;
    self.controllerGyroBiasZ = settings.controllerGyroBiasZ;
    self.singleTapSensitivity = settings.singleTapSensitivity;
    self.backgroundSessionTimer = settings.backroundSessionTimer;
    self.edgeSlidingSensitivity = settings.edgeSlidingSensitivity;
    self.appTheme = settings.appTheme;
    self.hapticEngine = settings.hapticEngine;
    self.uniqueId = settings.uniqueId;
    self.audioEngine = settings.audioEngine;
    self.delayLeftClick = settings.delayLeftClick;
    self.duckOtherApps = settings.duckOtherApps;
    self.muteInBackground = settings.muteInBackground;
    self.relativeTouchSlideThreshold = settings.relativeTouchSlideThreshold;
    self.enablePinch = settings.enablePinch;
    self.scrollSensitivity = settings.scrollSensitivity;
    self.pinchSensitivity = settings.pinchSensitivity;
    self.leftClickDelayMs = settings.leftClickDelayMs;
    self.ctrlDownForPinch = settings.ctrlDownForPinch;
    self.settingsMenuOffset = settings.settingsMenuOffset;
    self.passthroughGestures = settings.passthroughGestures;
    self.mapControllerToMouse = settings.mapControllerToMouse;
    self.controllerMouseLeftButton = settings.controllerMouseLeftButton;
    self.controllerMouseRightButton = settings.controllerMouseRightButton;
    self.controllerMouseSwitch = settings.controllerMouseSwitch;
    self.controllerMouseStick = settings.controllerMouseStick;
    self.controllerMousePointerVelocity = settings.controllerMousePointerVelocity;
    self.controllerMouseExpo = settings.controllerMouseExpo;
    
    
    // Pencil settings:
    self.pencilTickMode = settings.pencilTickMode;
    self.pencilTickIntervalUs = settings.pencilTickIntervalUs;

#endif
    
    return self;
}

@end
