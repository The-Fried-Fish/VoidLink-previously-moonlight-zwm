//
//  DataManager.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "AppDelegate.h"
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "TemporarySettings.h"

@interface DataManager : NSObject

- (void) saveSettingsWithBitrate:(NSInteger)bitrate
                       framerate:(NSInteger)framerate
                          height:(NSInteger)height
                           width:(NSInteger)width
                     audioConfig:(NSInteger)audioConfig
                onscreenControls:(NSInteger)onscreenControls
           keyboardToggleFingers:(NSInteger)keyboardToggleFingers
            oscLayoutToolFingers:(NSInteger)oscLayoutToolFingers
       slideToSettingsScreenEdge:(NSInteger)slideToSettingsScreenEdge
         slideToSettingsDistance:(CGFloat)slideToSettingsDistance
      pointerVelocityModeDivider:(CGFloat)pointerVelocityModeDivider
      touchPointerVelocityFactor:(CGFloat)touchPointerVelocityFactor
      mousePointerVelocityFactor:(CGFloat)mousePointerVelocityFactor
          oscTapExlusionAreaSize:(CGFloat)oscTapExlusionAreaSize
      reverseMouseWheelDirection:(BOOL)reverseMouseWheelDirection
                  largerStickLR1:(BOOL)largerStickLR1
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
                       localMousePointerMode:(NSInteger)localMousePointerMode;

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
