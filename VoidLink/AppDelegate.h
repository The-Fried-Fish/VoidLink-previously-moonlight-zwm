//
//  AppDelegate.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
#import <UIKit/UIMainMenuSystem.h>
#import <UIKit/UIMenuBuilder.h>
#import <UIKit/UIMenu.h>
#import <UIKit/UIAction.h>
#endif

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) NSString *pcUuidToLoad;
@property (strong, nonatomic) void (^shortcutCompletionHandler)(BOOL);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
@property (nonatomic, copy) void(^mainMenuBuildHandler)(id<UIMenuBuilder> builder) API_AVAILABLE(ios(26.0));
#endif

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;
- (NSURL*) getStoreURL;
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0));

@end
