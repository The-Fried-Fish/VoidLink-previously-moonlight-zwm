//
//  DataManager.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.1
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "AppDelegate.h"
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "TemporarySettings.h"

@interface DataManager : NSObject

typedef NS_ENUM(NSUInteger, UINavigationBarHeight) {
    UINavigationBarHeightIPad = 50,
    UINavigationBarHeightIPhone = 44
};

typedef NS_ENUM(NSInteger, TouchMode) {
    RelativeTouch,
    NativeTouch,
    AbsoluteTouch,
    NativeTouchOnly
};

typedef NS_ENUM(NSInteger, TouchEventPriorityEnum) {
    AsyncNativeTouchOff,
    EqualPriority,
    TouchDownPriority,// deprecated by GUI
    TouchMovePriority// deprecated by GUI
};

typedef NS_ENUM(NSInteger, GyroMode) {
    GyroModeOff,
    GyroModeAuto,
    AlwaysDevice,
    AlwaysController
};


typedef NS_ENUM(NSInteger, SettingsMenuMode) {
    AllSettings,
    FavoriteSettings,
    RemoveSettingItem,
};

- (void) saveSettingsWithBitrate:(NSInteger)bitrate
                       framerate:(NSInteger)framerate
                          height:(NSInteger)height
                           width:(NSInteger)width
                     audioConfig:(NSInteger)audioConfig
                onscreenControls:(NSInteger)onscreenControls
                        gyroMode:(NSInteger)gyroMode
          emulatedControllerType:(NSInteger)emulatedControllerType
           keyboardToggleFingers:(NSInteger)keyboardToggleFingers
            oscLayoutToolFingers:(NSInteger)oscLayoutToolFingers
       slideToSettingsScreenEdge:(NSInteger)slideToSettingsScreenEdge
         slideToSettingsDistance:(CGFloat)slideToSettingsDistance
      pointerVelocityModeDivider:(CGFloat)pointerVelocityModeDivider
      touchPointerVelocityFactor:(CGFloat)touchPointerVelocityFactor
      mousePointerVelocityFactor:(CGFloat)mousePointerVelocityFactor
                 gyroSensitivity:(CGFloat)gyroSensitivity
          touchMoveEventInterval:(NSInteger)touchMoveEventInterval
      reverseMouseWheelDirection:(BOOL)reverseMouseWheelDirection
                  asyncNativeTouchPriority:(NSInteger)asyncNativeTouchPriority
       liftStreamViewForKeyboard:(BOOL)liftStreamViewForKeyboard
             showKeyboardToolbar:(BOOL)showKeyboardToolbar
                   optimizeGames:(BOOL)optimizeGames
                 multiController:(BOOL)multiController
                 swapABXYButtons:(BOOL)swapABXYButtons
                       audioOnPC:(BOOL)audioOnPC
                  preferredCodec:(uint32_t)preferredCodec
                       enableYUV444:(BOOL)enableYUV444
                       enablePIP:(BOOL)enablePIP
                  useFramePacing:(BOOL)useFramePacing
                       enableHdr:(BOOL)enableHdr
                  btMouseSupport:(BOOL)btMouseSupport
               // absoluteTouchMode:(BOOL)absoluteTouchMode
                       touchMode:(NSInteger)touchMode
               statsOverlayLevel:(NSInteger)statsOverlayLevel
                    statsOverlayEnabled:(BOOL)statsOverlayEnabled
                   unlockDisplayOrientation:(BOOL)unlockDisplayOrientation
              resolutionSelected:(NSInteger)resolutionSelected
             externalDisplayMode:(NSInteger)externalDisplayMode
           localMousePointerMode:(NSInteger)localMousePointerMode
           backgroundSessionTimer:(NSInteger)backgroundSessionTimer;

- (NSArray*) getHosts;
- (void) updateHost:(TemporaryHost*)host;
- (void) updateAppsForExistingHost:(TemporaryHost *)host;
- (void) removeHost:(TemporaryHost*)host;
- (void) removeApp:(TemporaryApp*)app;
- (Settings*) retrieveSettings;
- (void) saveData;
- (TemporarySettings*) getSettings;

- (void) updateUniqueId:(NSString*)uniqueId;
- (NSString*) getUniqueId;

@end
