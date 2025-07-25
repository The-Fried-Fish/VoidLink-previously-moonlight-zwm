//
//  OSCProfilesManager.m
//  Moonlight
//
//  Created by Long Le on 1/1/23.
//  Copyright © 2023 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "OSCProfilesManager.h"
#import "OnScreenButtonState.h"
#import "VoidLink-Swift.h"
#import "LayoutOnScreenControlsViewController.h"
#import "OnScreenControls.h"

@implementation OSCProfilesManager

static NSMutableSet *OnScreenWidgetViews;
static CGRect streamViewBounds;

#pragma mark - Initializer

+ (OSCProfilesManager *) sharedManager:(CGRect)viewBounds {
    static OSCProfilesManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    streamViewBounds = viewBounds;
    NSLog(@"bounds width: %f, height: %f", streamViewBounds.size.width, streamViewBounds.size.height);
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    // _sharedManager.currentProfiles = [_sharedManager getAllProfiles];
    return _sharedManager;
}


#pragma mark - Class Helper Methods


+ (void) setOnScreenWidgetViewsSet:(NSMutableSet* )set{
    OnScreenWidgetViews = set;
}

/**
 * Returns the profile whose 'name' property has a value that is equal to the 'name' passed into the method
 */
- (OSCProfile *) OSCProfileWithName:(NSString*)name {
    NSMutableArray *profiles = [self getAllProfiles];
    
    for (OSCProfile *profile in profiles) {
                
        if ([profile.name isEqualToString:name]) {
            return profile;
        }
    }
    
    return nil;
}

/**
 * Returns an array of encoded 'OSCProfile' objects from the array of decoded 'OSCProfile' objects passed into this method
 */
- (NSMutableArray *) encodedProfilesFromArray:(NSMutableArray *)profiles {
    
    NSMutableArray *profilesEncoded = [[NSMutableArray alloc] init];
    /* encode each profile and add them back into an array */
    for (OSCProfile *profile in profiles) {   //
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profile requiringSecureCoding:YES error:nil];
        [profilesEncoded addObject:profileEncoded];
    }
    
    return profilesEncoded;
}


/**
 * Delete an 'OSCProfile' object of specific index for another in the 'OSCProfile' objects array stored in persistent storage
 */
-(void)deleteCurrentSelectedProfile{
    NSMutableArray *profiles = [self getAllProfiles];
    NSInteger selectedIndex = [self getIndexOfSelectedProfile];
    
    /* Remove the selected profile */
    if(selectedIndex != 0) [profiles removeObjectAtIndex:selectedIndex]; //deleting default profile (index 0) is not allowed
    else {
        NSLog(@"Default profile!"); // to be updated here.
    }
    
    selectedIndex--;
    if(selectedIndex < 0) selectedIndex = 0;
    OSCProfile *newSelectedProfile = [profiles objectAtIndex:selectedIndex];
    newSelectedProfile.isSelected = YES;
    
    NSMutableArray *profilesEncoded = [self encodedProfilesFromArray:profiles]; // encode each 'profile' object in the array and add them to a new array
    
    /* Encode the array itself, NOT the objects in the array, which are already encoded. Save array to persistent storage */
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
}


/**
 * Replaces one 'OSCProfile' object for another in the 'OSCProfile' objects array stored in persistent storage
 */
- (void) replaceProfile:(OSCProfile*)oldProfile withProfile:(OSCProfile*)newProfile {
    NSMutableArray *profiles = [self getAllProfiles];

    for (OSCProfile *profile in profiles) { // set all profiles' 'isSelected' property to NO since the new profile we're saving over the old profile with will be the 'selected' profile
        profile.isSelected = NO;
    }
    
    /* Set the new profile as the selected one. The reasoning behind this is that this method is currently being used when the user saves over an existing profile with another profile that has the same name. The expected behavior is that the newly saved profile becomes the selected profile which will show on screen when they launch the game stream view */
    newProfile.isSelected = YES;
  
    /* Remove the old profile from the array and insert the new profile into its place */
    int index = 0;
    for (int i = 0; i < profiles.count; i++) {
        
        if ([[profiles[i] name] isEqualToString: oldProfile.name]) {
            index = i;
        }
    }
    [profiles removeObjectAtIndex:index];
    [profiles insertObject:newProfile atIndex:index];
    
    NSMutableArray *profilesEncoded = [self encodedProfilesFromArray:profiles]; // encode each 'profile' object in the array and add them to a new array
    
    /* Encode the array itself, NOT the objects in the array, which are already encoded. Save array to persistent storage */
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSMutableArray *) getEncodedProfiles {
    NSMutableArray *profiles = [self getAllProfiles];
    NSMutableArray *profilesEncoded = [self encodedProfilesFromArray:profiles]; // encode each 'profile' object in the array and add them to a new array
    return profilesEncoded;
}

- (void) importEncodedProfiles:(NSMutableArray* )profilesEncoded {
    NSMutableArray* targetProfiles = [_currentProfiles mutableCopy]; //_currentProfiles is availabled as long as getAllProfiles was called before calling this method (_currentProfiles avoids frequent accessing persisted data)
    OSCProfile* profile;
    profile = [self findProfileByName:DEFAULT_TEMPLATE_NAME1 inProfileArray:targetProfiles];
    if(profile && targetProfiles.count > 1) [targetProfiles removeObject:profile];
    profile = [self findProfileByName:DEFAULT_TEMPLATE_NAME2 inProfileArray:targetProfiles];
    if(profile && targetProfiles.count > 1) [targetProfiles removeObject:profile];
    if(targetProfiles.count > 0) [targetProfiles removeObjectAtIndex:0];
    NSMutableArray* localEncodedPofiles = [self encodedProfilesFromArray:targetProfiles];
    [profilesEncoded addObjectsFromArray:localEncodedPofiles];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) importDefaultTemplates{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"widgetTemplates" ofType:@"bin"];
    if (filePath) {
        // 2. 读取二进制数据
        NSError *error;
        NSData *fileData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
        NSMutableArray *profilesEncoded;
        if (fileData && !error) {
            // 3. 成功读取
            NSSet *classes = [NSSet setWithObjects: [NSMutableData class], [NSMutableArray class], nil];
            profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:fileData error:&error];
            [self importEncodedProfiles:profilesEncoded];
        }
    }
}


#pragma mark - Globally Accessible Methods

#pragma mark - Getters

- (NSMutableArray *) getAllProfiles {
    
    NSData *profilesArrayEncoded = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];    // Get the encoded array of encoded OSC profiles from persistent storage
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profilesArrayEncoded error:nil];    // Decode the encoded array itself, NOT the objects contained in the array
    
    /* Decode each of the encoded profiles, place them into an array, then return the array */
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
    _currentProfiles = profilesDecoded;
    return profilesDecoded;
}

- (OSCProfile *) getSelectedProfile {
    NSMutableArray *profiles = [self getAllProfiles];

    for (OSCProfile *profile in profiles) {
                
        if (profile.isSelected) {
            return profile;
        }
    }
    return nil;
}

- (NSInteger) getIndexOfSelectedProfile {
    NSMutableArray *profiles = [self getAllProfiles];
    for (OSCProfile *profile in profiles) {
        
        if (profile.isSelected == YES) {
            return [profiles indexOfObject:profile];
        }
    }
    return 0;   // if none of the profiles in the array have their 'isSelected' property set to YES (which should not be possible) return the 'Default' profile as the 'selected' profile
}


#pragma mark - Setters

- (void) setProfileToSelected:(NSString *)name {
    NSMutableArray *profiles = [self getAllProfiles];
    
    /* Iterate through each profile. If its name equals the value of the 'name' parameter passed into this method then set the profile's 'isSelected' property to YES, otherwise set the value to NO */
    for (OSCProfile *profile in profiles) {
                
        if ([profile.name isEqualToString:name]) {
            profile.isSelected = YES;
        }
        else {
            profile.isSelected = NO;
        }
    }
    
    NSMutableArray *profilesEncoded = [self encodedProfilesFromArray:profiles]; // encode each 'profile' object in the array and add them to a new array
        
    /* Encode the array itself, NOT the objects inside the array, which have already been encoded by this point */
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (bool) updateSelectedProfile:(NSMutableArray *) oscButtonLayers {
    NSMutableArray* buttonStatesEncoded = [self convertOnScreenControllerAndWidgetsToButtonStates:oscButtonLayers];
    if([self getIndexOfSelectedProfile]==0) return false;
    OSCProfile *newProfile = [[OSCProfile alloc] initWithName:[self getSelectedProfile].name
                            buttonStates:buttonStatesEncoded isSelected:YES];        // create a new 'OSCProfile'. Set the array of encoded button states created above to the 'buttonStates' property of the new profile, along with a 'name'. Set 'isSelected' argument to YES which will set this saved profile as the one that will show up in the game stream view

    
    /* set all saved OSCProfiles 'isSelected' property to NO since the new profile you're adding will be set as the selected profile */
    NSMutableArray *profiles = [self getAllProfiles];
    for (OSCProfile *profile in profiles) {
        profile.isSelected = NO;
    }
    [self replaceProfile:[self getSelectedProfile] withProfile:newProfile];
    return true;
}


- (void) saveProfileWithName:(NSString*)name andButtonLayers:(NSMutableArray *)oscButtonLayers {
    NSMutableArray* buttonStatesEncoded = [self convertOnScreenControllerAndWidgetsToButtonStates:oscButtonLayers];
    OSCProfile *newProfile = [[OSCProfile alloc] initWithName:name
                            buttonStates:buttonStatesEncoded isSelected:YES];        // create a new 'OSCProfile'. Set the array of encoded button states created above to the 'buttonStates' property of the new profile, along with a 'name'. Set 'isSelected' argument to YES which will set this saved profile as the one that will show up in the game stream view
    /* set all saved OSCProfiles 'isSelected' property to NO since the new profile you're adding will be set as the selected profile */
    NSMutableArray *profiles = [self getAllProfiles];
    for (OSCProfile *profile in profiles) {
        
        profile.isSelected = NO;
    }
    
    if ([self profileNameAlreadyExist:name]) {  // if a saved profile with the same 'name' already exists in persistent storage then overwrite it and save the change to persistent storage
        [self replaceProfile:[self OSCProfileWithName:name] withProfile:newProfile];
    }
    else {  // otherwise encode then add the new profile to the end of the OSCProfiles array
        NSData *newProfileEncoded = [NSKeyedArchiver archivedDataWithRootObject:newProfile requiringSecureCoding:YES error:nil];
        NSMutableArray *profilesEncoded = [self encodedProfilesFromArray:profiles];
        [profilesEncoded addObject:newProfileEncoded];
        
        /* Encode the 'profilesEncoded' array itself, NOT the objects in the 'profilesEncoded' array, all of which are already encoded by this point */
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // saving test:
        /*
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *path = [documentsPath stringByAppendingPathComponent:@"newDefault.bin"];
        
        [profiles writeToFile:path atomically:YES];
        NSLog(@"默认 Profile 数据已保存到: %@", path);
         */
    }
}

- (CGPoint)normalizeWidgetPosition:(CGPoint)position {
    if(position.x > 1.0 && position.y >1.0){
        position.x = position.x / streamViewBounds.size.width;
        position.y = position.y / streamViewBounds.size.height;
    }
    return position;
}

- (CGPoint)denormalizeWidgetPosition:(CGPoint)position {
    if(position.x < 1.0 && position.y < 1.0){
        position.x = position.x * streamViewBounds.size.width;
        position.y = position.y * streamViewBounds.size.height;
    }
    return position;
}

- (NSMutableArray* ) convertOnScreenControllerAndWidgetsToButtonStates:(NSMutableArray *) oscButtonLayers {
    /* iterate through each OSC button the user sees on screen, create an 'OnScreenButtonState' object from each button, encode each object, and then add each object to an array */
    /*
    NSSet *validPositionButtonNames = [NSSet setWithObjects:
        @"l2Button",
        @"l1Button",
        @"dPad",
        @"selectButton",
        @"leftStickBackground",
        @"rightStickBackground",
        @"r2Button",
        @"r1Button",
        @"aButton",
        @"bButton",
        @"xButton",
        @"yButton",
        @"startButton",
        nil]; */
    NSMutableArray *buttonStatesEncoded = [[NSMutableArray alloc] init];
    
    // save on-screen game controller buttons & sticks as buttonstate:
    for (CALayer *oscButtonLayer in oscButtonLayers) {
        CGPoint normalizedPosition = [self normalizeWidgetPosition:oscButtonLayer.position];
        OnScreenButtonState *buttonState = [[OnScreenButtonState alloc] initWithButtonName:oscButtonLayer.name buttonType:LegacyOscButton andPosition:normalizedPosition];
        // add hidden attr here
        buttonState.isHidden = oscButtonLayer.isHidden;
        buttonState.oscLayerSizeFactor = [OnScreenControls getControllerLayerSizeFactor:oscButtonLayer];
        buttonState.backgroundAlpha = oscButtonLayer.opacity;
        
        NSNumber *style = [OnScreenControls.layerVibrationStyleDic objectForKey:oscButtonLayer.name];
        if ([style isKindOfClass:[NSNumber class]]) {
            buttonState.vibrationStyle = [style unsignedCharValue];
            // 使用 val
        }
        else buttonState.vibrationStyle = UIImpactFeedbackStyleLight;

        // NSLog(@"oscLayerName: %@, opacity: %f, ", oscButtonLayer.name, buttonState.backgroundAlpha);

        
        // buttonState.oscLayerSizeFactor = oscButtonLayer.bounds;
        
        NSData *buttonStateEncoded = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [buttonStatesEncoded addObject: buttonStateEncoded];
    }
    
    // save on-screen widget views (keyboard & mouse command) as buttonstate:
    for(OnScreenWidgetView* widgetView in OnScreenWidgetViews){
        CGPoint normalizedPosition = [self normalizeWidgetPosition:widgetView.center];
        OnScreenButtonState *buttonState = [[OnScreenButtonState alloc] initWithButtonName:widgetView.cmdString buttonType:CustomOnScreenWidget andPosition:normalizedPosition];
        buttonState.alias = widgetView.buttonLabel;
        buttonState.widthFactor = widgetView.widthFactor;
        buttonState.heightFactor = widgetView.heightFactor;
        buttonState.backgroundAlpha = widgetView.backgroundAlpha;
        buttonState.borderWidth = widgetView.borderWidth;
        buttonState.vibrationStyle = widgetView.vibrationStyle;
        buttonState.mouseButtonAction = widgetView.mouseButtonAction;
        buttonState.sensitivityFactorX = widgetView.sensitivityFactorX;
        buttonState.sensitivityFactorY = widgetView.sensitivityFactorY;
        buttonState.decelerationRate = widgetView.trackballDecelerationRate;
        buttonState.stickIndicatorOffset = widgetView.stickIndicatorOffset;
        buttonState.widgetShape = widgetView.shape;
        buttonState.minStickOffset = widgetView.minStickOffset;
        
        NSData *buttonStateEncoded = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [buttonStatesEncoded addObject: buttonStateEncoded];

    }
    return buttonStatesEncoded;
}



#pragma mark - Queries

- (BOOL) profileNameAlreadyExist:(NSString*)name {
    NSMutableArray *profiles = [self getAllProfiles];
    /* Iterate through the decoded profiles and return 'YES' if one of the profiles' 'name' properties equals the 'name' passed into this method */
    for (OSCProfile *profile in profiles) {
        if ([profile.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

- (OSCProfile *) findProfileByName:(NSString*) name inProfileArray:(NSMutableArray*)profiles {
    /* Iterate through the decoded profiles and return 'YES' if one of the profiles' 'name' properties equals the 'name' passed into this method */
    for (OSCProfile *profile in profiles) {
        if ([profile.name isEqualToString:name]) {
            return profile;
        }
    }
    return nil;
}

- (OnScreenButtonState *)unarchiveButtonStateEncoded:(NSData *)data {
    OnScreenButtonState* buttonState;
    buttonState = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[NSString class], [OnScreenButtonState class], nil]
                                                    fromData:data
                                                    error:nil];
    return buttonState;
}

@end
