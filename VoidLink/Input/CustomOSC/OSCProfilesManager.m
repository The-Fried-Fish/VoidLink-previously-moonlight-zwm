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
static CGRect layoutViewBounds;

#pragma mark - Initializer

+ (OSCProfilesManager *) sharedManager:(CGRect)viewBounds {
    static OSCProfilesManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    layoutViewBounds = viewBounds;
    // NSLog(@"bounds width: %f, height: %f", layoutViewBounds.size.width, layoutViewBounds.size.height);
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    // _sharedManager.currentProfiles = [_sharedManager getAllProfiles];
    return _sharedManager;
}


#pragma mark - Class Helper Methods


+ (void)setOnScreenWidgetViewsSet:(NSMutableSet* )set{
    OnScreenWidgetViews = set;
}

+ (void)setLayoutViewBounds:(CGRect)bounds{
    layoutViewBounds = bounds;
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
    
    if (profiles == nil) {
        NSLog(@"警告：尝试编码nil profiles数组，返回空数组");
        return profilesEncoded;
    }
    
    /* encode each profile and add them back into an array */
    for (OSCProfile *profile in profiles) {
        if (profile == nil) {
            NSLog(@"警告：跳过nil profile对象");
            continue;
        }
        
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profile requiringSecureCoding:YES error:nil];
        if (profileEncoded != nil) {
            [profilesEncoded addObject:profileEncoded];
        } else {
            NSLog(@"警告：profile编码失败，跳过该profile: %@", profile.name ?: @"未命名");
        }
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
    if(selectedIndex != 0) {
        OSCProfile *profileToDelete = [profiles objectAtIndex:selectedIndex];
        
        // 如果要删除的布局已配对，需要清理配对关系
        if (profileToDelete.isPaired) {
            [self unpairProfile:profileToDelete.name];
            // 重新获取profiles，因为unpairProfile会更新存储
            profiles = [self getAllProfiles];
            // 重新计算selectedIndex，因为profiles可能已经改变
            selectedIndex = [self getIndexOfSelectedProfile];
        }
        
        [profiles removeObjectAtIndex:selectedIndex];
    } else {
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


- (BOOL)isIPhone{
    return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
}


- (void) importDefaultTemplates{
    NSString *filePath = [[NSBundle mainBundle] pathForResource: [self isIPhone] ? @"widgetTemplatesIPhone": @"widgetTemplates" ofType:@"bin"];
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
    
    // 如果没有保存的配置文件数据，返回空数组
    if (profilesArrayEncoded == nil) {
        NSLog(@"没有找到保存的配置文件数据，返回空数组");
        _currentProfiles = [[NSMutableArray alloc] init];
        return _currentProfiles;
    }
    
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profilesArrayEncoded error:nil];    // Decode the encoded array itself, NOT the objects contained in the array
    
    // 如果解码失败，返回空数组
    if (profilesEncoded == nil) {
        NSLog(@"配置文件数据解码失败，返回空数组");
        _currentProfiles = [[NSMutableArray alloc] init];
        return _currentProfiles;
    }
    
    /* Decode each of the encoded profiles, place them into an array, then return the array */
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        if (profileDecoded != nil) {  // 添加nil检查，防止崩溃
            [profilesDecoded addObject: profileDecoded];
        } else {
            NSLog(@"警告：配置文件解码失败，跳过该配置文件");
        }
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
    
    // 检查当前选中的布局是否为模板布局
    OSCProfile *currentProfile = [self getSelectedProfile];
    if (currentProfile && [self isTemplateProfile:currentProfile.name]) {
        return false;
    }
    OSCProfile *newProfile = [[OSCProfile alloc] initWithName:currentProfile.name
                            buttonStates:buttonStatesEncoded isSelected:YES];        // create a new 'OSCProfile'. Set the array of encoded button states created above to the 'buttonStates' property of the new profile, along with a 'name'. Set 'isSelected' argument to YES which will set this saved profile as the one that will show up in the game stream view

    // 保留原有的配对信息
    newProfile.pairedProfileName = currentProfile.pairedProfileName;
    newProfile.isLandscapeLayout = currentProfile.isLandscapeLayout;
    newProfile.isPaired = currentProfile.isPaired;
    
    NSLog(@"🔄 updateSelectedProfile - 保留配对信息: %@ -> isPaired=%@, pairedWith=%@", 
          newProfile.name, 
          newProfile.isPaired ? @"YES" : @"NO",
          newProfile.pairedProfileName ?: @"nil");
    
    /* set all saved OSCProfiles 'isSelected' property to NO since the new profile you're adding will be set as the selected profile */
    NSMutableArray *profiles = [self getAllProfiles];
    for (OSCProfile *profile in profiles) {
        profile.isSelected = NO;
    }
    [self replaceProfile:currentProfile withProfile:newProfile];
    return true;
}


- (void) saveProfileWithName:(NSString*)name andButtonLayers:(NSMutableArray *)oscButtonLayers {
    NSMutableArray* buttonStatesEncoded = [self convertOnScreenControllerAndWidgetsToButtonStates:oscButtonLayers];
    OSCProfile *newProfile = [[OSCProfile alloc] initWithName:name
                            buttonStates:buttonStatesEncoded isSelected:YES];        // create a new 'OSCProfile'. Set the array of encoded button states created above to the 'buttonStates' property of the new profile, along with a 'name'. Set 'isSelected' argument to YES which will set this saved profile as the one that will show up in the game stream view
    
    // 如果是覆盖现有配置，保留原有的配对信息
    if ([self profileNameAlreadyExist:name]) {
        OSCProfile *existingProfile = [self OSCProfileWithName:name];
        if (existingProfile) {
            newProfile.pairedProfileName = existingProfile.pairedProfileName;
            newProfile.isLandscapeLayout = existingProfile.isLandscapeLayout;
            newProfile.isPaired = existingProfile.isPaired;
            
            NSLog(@"🔄 saveProfileWithName - 保留现有配对信息: %@ -> isPaired=%@, pairedWith=%@", 
                  newProfile.name, 
                  newProfile.isPaired ? @"YES" : @"NO",
                  newProfile.pairedProfileName ?: @"nil");
        }
    }
    
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
    CGPoint newPosition = position;
    if(position.x > 1.0 && position.y >1.0){
        position.x = position.x / layoutViewBounds.size.width;
        position.y = position.y / layoutViewBounds.size.height;
    }
    // asdfsda;
    NSLog(@"sef.view bounds: %f, %f", layoutViewBounds.size.width, layoutViewBounds.size.height);
    NSLog(@"position: %f, %f, denormalized position: %f, %f", position.x, position.y, newPosition.x, newPosition.y);
    return position;
}

- (CGPoint)denormalizeWidgetPosition:(CGPoint)position {
    if(position.x < 1.0 && position.y < 1.0){
        position.x = position.x * layoutViewBounds.size.width;
        position.y = position.y * layoutViewBounds.size.height;
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
        buttonState.widthFactor = [self normalizeSizeWidthFactor:widgetView];
        NSLog(@"logging widthFactor %f", buttonState.widthFactor);
        buttonState.heightFactor = [self normalizeSizeHeightFactor:widgetView];
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
        buttonState.slideMode = widgetView.slideMode;
        
        NSData *buttonStateEncoded = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [buttonStatesEncoded addObject: buttonStateEncoded];

    }
    return buttonStatesEncoded;
}

- (CGFloat)normalizeSizeWidthFactor:(OnScreenWidgetView* )widget{
    // 使用固定的基准宽度(1194)来避免旋转时的累积变化
    static const CGFloat baseScreenWidth = 1194.0f;
    return widget.bounds.size.width/baseScreenWidth * 10000;
}

- (CGFloat)normalizeSizeHeightFactor:(OnScreenWidgetView* )widget{
    // 使用固定的基准宽度(1194)来避免旋转时的累积变化
    static const CGFloat baseScreenWidth = 1194.0f;
    return widget.bounds.size.height/baseScreenWidth * 10000;
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
    if (data == nil) {
        NSLog(@"警告：尝试解码nil数据，返回nil");
        return nil;
    }
    
    OnScreenButtonState* buttonState;
    NSSet *classes = [NSSet setWithObjects:[NSString class], [OnScreenButtonState class], nil];
    buttonState = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                    fromData:data
                                                    error:nil];
    return buttonState;
}

#pragma mark - Pairing Management

- (BOOL) pairProfile:(NSString*)profile1Name withProfile:(NSString*)profile2Name isProfile1Landscape:(BOOL)isLandscape {
    // 检查是否为模板布局
    if ([self isTemplateProfile:profile1Name] || [self isTemplateProfile:profile2Name]) {
        NSLog(@"配对失败：模板布局不允许配对");
        return NO;
    }
    
    NSMutableArray *profiles = [self getAllProfiles];
    
    OSCProfile *profile1 = [self findProfileByName:profile1Name inProfileArray:profiles];
    OSCProfile *profile2 = [self findProfileByName:profile2Name inProfileArray:profiles];
    
    if (!profile1 || !profile2) {
        NSLog(@"配对失败：找不到指定的布局");
        return NO;
    }
    
    if (profile1.isPaired || profile2.isPaired) {
        NSLog(@"配对失败：布局已经配对");
        return NO;
    }
    
    // 设置配对关系
    profile1.pairedProfileName = profile2Name;
    profile1.isLandscapeLayout = isLandscape;
    profile1.isPaired = YES;
    
    profile2.pairedProfileName = profile1Name;
    profile2.isLandscapeLayout = !isLandscape;
    profile2.isPaired = YES;
    
    // 保存更改
    [self saveProfilesToStorage:profiles];
    
    NSLog(@"配对成功：%@ (%@) <-> %@ (%@)", 
          profile1Name, isLandscape ? @"横屏" : @"竖屏",
          profile2Name, !isLandscape ? @"横屏" : @"竖屏");
    
    return YES;
}

- (BOOL) unpairProfile:(NSString*)profileName {
    NSMutableArray *profiles = [self getAllProfiles];
    
    OSCProfile *profile = [self findProfileByName:profileName inProfileArray:profiles];
    if (!profile || !profile.isPaired) {
        NSLog(@"解除配对失败：布局未配对");
        return NO;
    }
    
    // 找到配对的布局
    OSCProfile *pairedProfile = [self findProfileByName:profile.pairedProfileName inProfileArray:profiles];
    
    // 清除配对关系
    profile.pairedProfileName = nil;
    profile.isLandscapeLayout = NO;
    profile.isPaired = NO;
    
    if (pairedProfile) {
        pairedProfile.pairedProfileName = nil;
        pairedProfile.isLandscapeLayout = NO;
        pairedProfile.isPaired = NO;
    }
    
    // 保存更改
    [self saveProfilesToStorage:profiles];
    
    NSLog(@"解除配对成功：%@", profileName);
    return YES;
}

- (OSCProfile *) getPairedProfile:(NSString*)profileName {
    NSMutableArray *profiles = [self getAllProfiles];
    
    OSCProfile *profile = [self findProfileByName:profileName inProfileArray:profiles];
    if (!profile || !profile.isPaired) {
        return nil;
    }
    
    return [self findProfileByName:profile.pairedProfileName inProfileArray:profiles];
}

- (BOOL) isProfilePaired:(NSString*)profileName {
    NSMutableArray *profiles = [self getAllProfiles];
    OSCProfile *profile = [self findProfileByName:profileName inProfileArray:profiles];
    return profile ? profile.isPaired : NO;
}

- (OSCProfile *) getProfileForCurrentOrientation:(NSString*)profileName isLandscape:(BOOL)isLandscape {
    NSLog(@"🔍 getProfileForCurrentOrientation - 输入: profileName=%@, isLandscape=%@", 
          profileName, isLandscape ? @"YES" : @"NO");
    
    NSMutableArray *profiles = [self getAllProfiles];
    
    OSCProfile *profile = [self findProfileByName:profileName inProfileArray:profiles];
    if (!profile || !profile.isPaired) {
        NSLog(@"🔍 布局未配对或不存在，返回原布局: %@", profile ? profile.name : @"nil");
        return profile; // 如果未配对，返回原布局
    }
    
    NSLog(@"🔍 找到配对布局 - 当前布局方向: %@, 请求方向: %@", 
          profile.isLandscapeLayout ? @"横屏" : @"竖屏",
          isLandscape ? @"横屏" : @"竖屏");
    
    // 如果当前布局的方向与请求的方向匹配，返回当前布局
    if (profile.isLandscapeLayout == isLandscape) {
        NSLog(@"🔍 方向匹配，返回当前布局: %@", profile.name);
        return profile;
    }
    
    // 否则返回配对的布局
    OSCProfile *pairedProfile = [self getPairedProfile:profileName];
    NSLog(@"🔍 方向不匹配，返回配对布局: %@", pairedProfile ? pairedProfile.name : @"nil");
    return pairedProfile;
}

- (BOOL) isCurrentOrientationLandscape {
    CGFloat screenHeightInPoints = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    CGFloat screenWidthInPoints = CGRectGetWidth([[UIScreen mainScreen] bounds]);
    return screenWidthInPoints > screenHeightInPoints;
}

- (NSMutableArray *) getAvailableProfilesForPairing:(NSString*)currentProfileName {
    NSMutableArray *allProfiles = [self getAllProfiles];
    NSMutableArray *availableProfiles = [[NSMutableArray alloc] init];
    
    if (currentProfileName == nil) {
        NSLog(@"警告：currentProfileName为nil，返回空数组");
        return availableProfiles;
    }
    
    for (OSCProfile *profile in allProfiles) {
        if (profile == nil) {
            NSLog(@"警告：发现nil profile，跳过");
            continue;
        }
        
        // 排除当前选中的布局、已配对的布局和模板布局
        if (profile.name && 
            ![profile.name isEqualToString:currentProfileName] && 
            !profile.isPaired &&
            ![self isTemplateProfile:profile.name]) {
            [availableProfiles addObject:profile];
        }
    }
    
    return availableProfiles;
}

// 辅助方法：保存配置文件到存储
- (void) saveProfilesToStorage:(NSMutableArray*)profiles {
    NSMutableArray *profilesEncoded = [self encodedProfilesFromArray:profiles];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Template Management

- (BOOL) isTemplateProfile:(NSString*)profileName {
    if (!profileName) {
        return NO;
    }
    
    // 检查是否为三个默认模板布局之一
    return [profileName isEqualToString:@"Default"] ||
           [profileName isEqualToString:DEFAULT_TEMPLATE_NAME1] ||
           [profileName isEqualToString:DEFAULT_TEMPLATE_NAME2];
}

@end
