//
//  OSCProfilesManager.h
//  Moonlight
//
//  Created by Long Le on 1/1/23.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSCProfile.h"

NS_ASSUME_NONNULL_BEGIN

/**
 This singleton object can be accessed from any class and provides methods to get and set on screen controller profile related data.
 Note that the implementation file contains a number of 'Helper' methods. These helper methods are only used in this class's implementation file and help to reduce re-writing large blocks of code that are called multiple times throughout the file
 */
@interface OSCProfilesManager : NSObject
@property NSMutableArray <OSCProfile *> *currentProfiles;


+ (OSCProfilesManager *)sharedManager:(CGRect)viewBounds;
+ (void)setOnScreenWidgetViewsSet:(NSMutableSet* )set;
+ (void)setLayoutViewBounds:(CGRect)bounds;


#pragma mark - Getters
/**
 * Returns an array of decoded profile objects 
 */
- (NSMutableArray *) getAllProfiles;

/**
 * Returns the OSC Profile that is currently selected to be displayed on screen during game streaming
 */
- (OSCProfile *) getSelectedProfile;

/**
 * Returns the index of the 'selected' profile within the array it's in
 */
- (NSInteger) getIndexOfSelectedProfile;

- (NSMutableArray *) getEncodedProfiles;
- (void) importEncodedProfiles:(NSMutableArray* )profilesEncoded;
- (OnScreenButtonState *)unarchiveButtonStateEncoded:(NSData *)data;
- (void) importDefaultTemplates;

#pragma mark - Setters
/**
 * Sets the profile object with the particular 'name' as the selected profile to be displayed on screen during game streaming
 */
- (void) setProfileToSelected:(NSString *)name;

/**
 * Saves a profile object with a particular 'name' and an array of button layers (the CALayer button layers are the objects currently visible on screen) to persistent storage
 */
- (void) saveProfileWithName:(NSString*)name andButtonLayers:(NSMutableArray *)buttonLayers;

- (bool) updateSelectedProfile:(NSMutableArray *) oscButtonLayers;
/**
 * Delete current selected profile.
 */
- (void) deleteCurrentSelectedProfile;

#pragma mark - Queries
/**
 * Lets the caller of this method know whether a profile with a given name already exists in persistent storage
 */
- (BOOL) profileNameAlreadyExist:(NSString*)name;
- (OSCProfile *) findProfileByName:(NSString*) name inProfileArray:(NSMutableArray*)profiles;

#pragma mark - Pairing Management
/**
 * 创建两个布局之间的配对关系
 */
- (BOOL) pairProfile:(NSString*)profile1Name withProfile:(NSString*)profile2Name isProfile1Landscape:(BOOL)isLandscape;

/**
 * 解除配对关系
 */
- (BOOL) unpairProfile:(NSString*)profileName;

/**
 * 获取指定布局的配对布局
 */
- (OSCProfile *) getPairedProfile:(NSString*)profileName;

/**
 * 检查布局是否已配对
 */
- (BOOL) isProfilePaired:(NSString*)profileName;

/**
 * 根据当前屏幕方向获取应该使用的布局
 */
- (OSCProfile *) getProfileForCurrentOrientation:(NSString*)profileName isLandscape:(BOOL)isLandscape;

/**
 * 获取当前屏幕方向
 */
- (BOOL) isCurrentOrientationLandscape;

/**
 * 获取所有可用于配对的布局（排除当前选中和已配对的布局）
 */
- (NSMutableArray *) getAvailableProfilesForPairing:(NSString*)currentProfileName;

#pragma mark - Template Management
/**
 * 检查指定名称的布局是否为模板布局（不可编辑、删除或配对）
 */
- (BOOL) isTemplateProfile:(NSString*)profileName;

@end

NS_ASSUME_NONNULL_END
