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
#import "DataManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 This singleton object can be accessed from any class and provides methods to get and set on screen controller profile related data.
 Note that the implementation file contains a number of 'Helper' methods. These helper methods are only used in this class's implementation file and help to reduce re-writing large blocks of code that are called multiple times throughout the file
 */
@interface OSCProfilesManager : NSObject
@property NSMutableArray <OSCProfile *> *currentProfiles;
@property (atomic, assign) WidgetSizeTransition widgetSizeTransition;

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

- (uint32_t) getIndexOfLastProfile;

/**
 * Returns the index of the 'selected' profile within the array it's in
 */
- (NSInteger) getIndexOfSelectedProfile;
- (NSMutableArray *) getEncodedProfiles;
// - (NSData* )getSelectedEncodedProfile;
- (void) importEncodedProfiles:(NSMutableArray* )profilesEncoded;
- (OnScreenButtonState *)unarchiveButtonStateEncoded:(NSData *)data;
- (void) updateDefaultTemplates;
- (void) importDefaultTemplates;

#pragma mark - Setters
/**
 * Sets the profile object with the particular index as the selected profile to be displayed on screen during game streaming
 */
- (void) setProfileToSelected:(uint32_t)index;
- (void) replaceSelectedProfileWith:(OSCProfile*)newProfile overwriteDefault:(bool)overwriteDefault;
- (void) replaceProfile:(OSCProfile*)oldProfile withProfile:(OSCProfile*)newProfile;

/**
 * Saves a profile object with a particular 'name' and an array of button layers (the CALayer button layers are the objects currently visible on screen) to persistent storage
 */
- (void) duplicateSelectedProfileWithName:(NSString*)name;

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
- (CGPoint)normalizeWidgetPosition:(CGPoint)position;

@end

NS_ASSUME_NONNULL_END
