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
    self.enableFrameTimebase = settings.enableFrameTimebase;
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
    self.interpolationMaximumDimension = settings.interpolationMaximumDimension;
    self.interpolationMaximumPixelCount = settings.interpolationMaximumPixelCount;
    self.streamDimensionScale = settings.streamDimensionScale;
    self.sendDummyEvent = settings.sendDummyEvent;
    self.rememberFoldState = settings.rememberFoldState;
    self.gyroBiasX = settings.gyroBiasX;
    self.gyroBiasY = settings.gyroBiasY;
    self.gyroBiasZ = settings.gyroBiasZ;
    self.controllerGyroBiasX = settings.controllerGyroBiasX;
    self.controllerGyroBiasY = settings.controllerGyroBiasY;
    self.controllerGyroBiasZ = settings.controllerGyroBiasZ;
    self.singleTapSensitivity = settings.singleTapSensitivity;
    self.backgroundSessionTimer = settings.backgroundSessionTimer;
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
    self.enableControllerNavigation = settings.enableControllerNavigation;
    self.controllerMouseLeftButton = settings.controllerMouseLeftButton;
    self.controllerMouseRightButton = settings.controllerMouseRightButton;
    self.localRadialMenuButton = settings.localRadialMenuButton;
    self.streamingRadialMenuButton = settings.streamingRadialMenuButton;
    self.controllerMouseStick = settings.controllerMouseStick;
    self.controllerMousePointerVelocity = settings.controllerMousePointerVelocity;
    self.controllerMouseExpo = settings.controllerMouseExpo;
    self.streamingRadialMenuDelay = settings.streamingRadialMenuDelay;
    self.globeAsEscape = settings.globeAsEscape;
    self.pencilTickMode = settings.pencilTickMode;
    self.pencilTickIntervalUs = settings.pencilTickIntervalUs;
    self.pencilTipOffsetX = settings.pencilTipOffsetX;
    self.pencilTipOffsetY = settings.pencilTipOffsetY;
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
    self.interpolationMaximumDimension = settings.interpolationMaximumDimension ?: @(0);
    self.interpolationMaximumPixelCount = settings.interpolationMaximumPixelCount ?: @(0);
    self.streamDimensionScale = settings.streamDimensionScale ?: @(1);
    self.sendDummyEvent = settings.sendDummyEvent;
    self.rememberFoldState = settings.rememberFoldState;
    self.gyroBiasX = settings.gyroBiasX;
    self.gyroBiasY = settings.gyroBiasY;
    self.gyroBiasZ = settings.gyroBiasZ;
    self.controllerGyroBiasX = settings.controllerGyroBiasX;
    self.controllerGyroBiasY = settings.controllerGyroBiasY;
    self.controllerGyroBiasZ = settings.controllerGyroBiasZ;
    self.singleTapSensitivity = settings.singleTapSensitivity;
    self.backgroundSessionTimer = settings.backgroundSessionTimer;
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
    self.enableControllerNavigation = settings.enableControllerNavigation;
    self.controllerMouseLeftButton = settings.controllerMouseLeftButton;
    self.controllerMouseRightButton = settings.controllerMouseRightButton;
    self.localRadialMenuButton = settings.localRadialMenuButton;
    self.streamingRadialMenuButton = settings.streamingRadialMenuButton;
    self.controllerMouseStick = settings.controllerMouseStick;
    self.controllerMousePointerVelocity = settings.controllerMousePointerVelocity;
    self.controllerMouseExpo = settings.controllerMouseExpo;
    self.streamingRadialMenuDelay = settings.streamingRadialMenuDelay;
    self.globeAsEscape = settings.globeAsEscape;
    
    // Pencil settings:
    self.pencilTickMode = settings.pencilTickMode;
    self.pencilTickIntervalUs = settings.pencilTickIntervalUs;
    self.pencilTipOffsetX = settings.pencilTipOffsetX;
    self.pencilTipOffsetY = settings.pencilTipOffsetY;

#endif
    
    return self;
}

@end
