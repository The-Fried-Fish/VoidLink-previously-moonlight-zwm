//
//  AppDelegate.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.7.12
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "AppDelegate.h"
#import "MainFrameViewController.h"
#import "VoidLink-Swift.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

static NSOperationQueue* mainQueue;

#if TARGET_OS_TV
static NSString* DB_NAME = @"Moonlight_tvOS.bin";
#else
static NSString* DB_NAME = @"Limelight_iOS.sqlite";
#endif

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0)){
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions API_AVAILABLE(ios(13.0)){
}


#if !TARGET_OS_TV

/*
// orietation limitatioin test
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    UIViewController *topController = window.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return [topController supportedInterfaceOrientations];
}
*/

/*
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    NSLog(@"orientation limit");
        return UIInterfaceOrientationMaskLandscape;
}
*/

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for command tool customization after application launch (works only when user default is nil)
    [CommandManager presetDefaultCommands];

    // Configure UIMainMenuSystem for iOS 26.0+
    if (@available(iOS 26.0, *)) {
        // Reset streaming state on app launch
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"VLIsCurrentlyStreaming"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self setupMainMenuSystem];
    }

    // For iOS 12 and below, we need to manually create the window
    if (@available(iOS 13.0, *)) {
        // Scene delegate will handle window creation
    } else {
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        
        NSString *storyboardName;
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            storyboardName = @"iPad";
        } else {
            storyboardName = @"iPhone";
        }
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
        UIViewController *initialViewController = [storyboard instantiateInitialViewController];
        
        self.window.rootViewController = initialViewController;
        [self.window makeKeyAndVisible];
    }
    
    return YES;
}


- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler {
    _pcUuidToLoad = (NSString*)[shortcutItem.userInfo objectForKey:@"UUID"];
    _shortcutCompletionHandler = completionHandler;
}
#endif

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext
{
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    if (managedObjectContext != nil) {
        [managedObjectContext performBlock:^{
            if (![managedObjectContext hasChanges]) {
                return;
            }
            NSError *error = nil;
            if (![managedObjectContext save:&error]) {
                Log(LOG_E, @"Critical database error: %@, %@", error, [error userInfo]);
            }
            
#if TARGET_OS_TV
            NSData* dbData = [NSData dataWithContentsOfURL:[[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:DB_NAME]];
            [[NSUserDefaults standardUserDefaults] setObject:dbData forKey:DB_NAME];
#endif
        }];
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    NSString* storeType;
    
#if TARGET_OS_TV
    // Use a binary store for tvOS since we will need exclusive access to the file
    // to serialize into NSUserDefaults.
    storeType = NSBinaryStoreType;
#else
    storeType = NSSQLiteStoreType;
#endif
    
    // We must ensure the persistent store is ready to opened
    [self preparePersistentStore];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:storeType configuration:nil URL:[self getStoreURL] options:options error:&error]) {
        // Log the error
        Log(LOG_E, @"Critical database error: %@, %@", error, [error userInfo]);
        
        // Drop the database
        [self dropDatabase];
        
        // Try again
        return [self persistentStoreCoordinator];
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void) dropDatabase
{
    // Delete the file on disk
    [[NSFileManager defaultManager] removeItemAtURL:[self getStoreURL] error:nil];
    
#if TARGET_OS_TV
    // Also delete the copy in the NSUserDefaults on tvOS
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:DB_NAME];
#endif
}

- (void) preparePersistentStore
{
#if TARGET_OS_TV
    // On tvOS, we may need to inflate the DB from NSUserDefaults
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [paths objectAtIndex:0];
    NSString *dbPath = [cacheDirectory stringByAppendingPathComponent:DB_NAME];
    
    // Always prefer the on disk version
    if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
        // If that is unavailable, inflate it from NSUserDefaults
        NSData* data = [[NSUserDefaults standardUserDefaults] dataForKey:DB_NAME];
        if (data != nil) {
            Log(LOG_I, @"Inflating database from NSUserDefaults");
            [data writeToFile:dbPath atomically:YES];
        }
        else {
            Log(LOG_I, @"No database on disk or in NSUserDefaults");
        }
    }
    else {
        Log(LOG_I, @"Using cached database");
    }
#endif
}

- (NSURL*) getStoreURL {
#if TARGET_OS_TV
    // We use the cache folder to store our database on tvOS
    return [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:DB_NAME];
#else
    return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:DB_NAME];
#endif
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
- (void)setupMainMenuSystem API_AVAILABLE(ios(26.0)) {
    // Only setup main menu system on iPad where it makes sense
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        return;
    }

    UIMainMenuSystem *mainMenu = [UIMainMenuSystem sharedSystem];

    // Create configuration with default settings
    UIMainMenuSystemConfiguration *config = [[UIMainMenuSystemConfiguration alloc] init];

    // Set preferences for menu elements
    config.newScenePreference = UIMenuSystemElementGroupPreferenceAutomatic;
    config.documentPreference = UIMenuSystemElementGroupPreferenceAutomatic;
    config.printingPreference = UIMenuSystemElementGroupPreferenceAutomatic;
    config.findingPreference = UIMenuSystemElementGroupPreferenceAutomatic;
    config.toolbarPreference = UIMenuSystemElementGroupPreferenceAutomatic;
    config.sidebarPreference = UIMenuSystemElementGroupPreferenceAutomatic;
    config.inspectorPreference = UIMenuSystemElementGroupPreferenceAutomatic;
    config.textFormattingPreference = UIMenuSystemElementGroupPreferenceAutomatic;

    // Save the build handler for later use with setNeedsRebuild
    __weak typeof(self) weakSelf = self;
    self.mainMenuBuildHandler = ^(id<UIMenuBuilder> builder) {
        [weakSelf buildMainMenuWithBuilder:builder];
    };

    [mainMenu setBuildConfiguration:config buildHandler:self.mainMenuBuildHandler];

    // Listen for streaming state changes to rebuild menu dynamically
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(streamingStateChanged:)
                                                 name:@"VLStreamingStateChanged"
                                               object:nil];
}

- (void)buildMainMenuWithBuilder:(id<UIMenuBuilder>)builder API_AVAILABLE(ios(26.0)) {
    // Create Settings menu action
    UIAction *settingsAction = [UIAction actionWithTitle:@"Settings"
                                                    image:[UIImage systemImageNamed:@"sidebar.left"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self showSettingsFromMainMenu:action];
        }];

    // Create Settings menu
    UIMenu *settingsMenu = [UIMenu menuWithTitle:@"Settings"
                                            image:[UIImage systemImageNamed:@"sidebar.left"]
                                       identifier:@"com.voidlink.settings"
                                          options:UIMenuOptionsDisplayInline
                                         children:@[settingsAction]];

    // Create Toolbox menu action
    UIAction *toolboxAction = [UIAction actionWithTitle:@"Toolbox"
                                                   image:[UIImage systemImageNamed:@"wrench.and.screwdriver"]
                                              identifier:@"com.voidlink.toolbox.action"
                                                 handler:^(__kindof UIAction * _Nonnull action) {
            [self showToolboxFromMainMenu:action];
        }];

    // Hide toolbox menu when not streaming
    if (![self isCurrentlyStreaming]) {
        toolboxAction.attributes = UIMenuElementAttributesHidden;
    }

    // Create Toolbox menu
    UIMenu *toolboxMenu = [UIMenu menuWithTitle:@"Toolbox"
                                           image:[UIImage systemImageNamed:@"wrench.and.screwdriver"]
                                      identifier:@"com.voidlink.toolbox"
                                         options:UIMenuOptionsDisplayInline
                                        children:@[toolboxAction]];

    // Insert menus after the View menu
    [builder insertSiblingMenu:settingsMenu afterMenuForIdentifier:UIMenuView];
    [builder insertSiblingMenu:toolboxMenu afterMenuForIdentifier:settingsMenu.identifier];
}

- (BOOL)isCurrentlyStreaming API_AVAILABLE(ios(26.0)) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"VLIsCurrentlyStreaming"];
}


- (void)showSettingsFromMainMenu:(UIAction *)sender API_AVAILABLE(ios(26.0)) {
    // Post notification to show settings
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VLShowSettingsFromMainMenu"
                                                        object:self
                                                      userInfo:nil];
}

- (void)showToolboxFromMainMenu:(UIAction *)sender API_AVAILABLE(ios(26.0)) {
    // Check if we're in stream state before showing toolbox
    if ([self isCurrentlyStreaming]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VLShowToolboxFromMainMenu"
                                                            object:self
                                                          userInfo:nil];
    }
}

- (void)streamingStateChanged:(NSNotification *)notification API_AVAILABLE(ios(26.0)) {
    // Trigger menu rebuild when streaming state changes
    [[UIMainMenuSystem sharedSystem] setNeedsRebuild];
}
#endif

@end
