//
//  ThemeManager.h
//  VoidLink
//
//  Created by True砖家 on 2025.5.25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const ThemeDidChangeNotification;

@interface ThemeManager:NSObject

@property (class, nonatomic, assign) UIUserInterfaceStyle userInterfaceStyle;
+ (UIColor *)appPrimaryColor;
+ (UIColor *)appSecondaryColor;
+ (UIColor *)appPrimaryColorWithAlpha;
+ (UIColor *)widgetBackgroundColor;
+ (UIColor *)appBackgroundColor;
+ (UIColor *)separatorColor;
+ (UIColor *)textColor;
+ (UIColor *)textColorGray;
+ (UIColor *)lowProfileGray;
+ (UIColor *)textTintColorWithAlpha;

@end
