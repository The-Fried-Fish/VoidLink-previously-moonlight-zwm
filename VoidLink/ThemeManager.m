//
//  ThemeManager.h
//  VoidLink
//
//  Created by True砖家 on 2025.5.25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

#import "ThemeManager.h"

@implementation ThemeManager

static UIUserInterfaceStyle _privateUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
static UIUserInterfaceStyle _userInterfaceStyle;

+ (UIColor *)getUIStyle{
    if (@available(iOS 13.0, *)) {
        UITraitCollection *traitCollection = [UIScreen mainScreen].traitCollection;
            if(_privateUserInterfaceStyle == UIUserInterfaceStyleUnspecified) {
                _userInterfaceStyle = traitCollection.userInterfaceStyle;
            }
            else _userInterfaceStyle = _privateUserInterfaceStyle;
            return [UIColor clearColor];
    } else {
        return [UIColor clearColor];
    }
}



+ (UIUserInterfaceStyle)userInterfaceStyle {
    [ThemeManager getUIStyle];
    return _userInterfaceStyle;
}

+ (void)setUserInterfaceStyle:(UIUserInterfaceStyle)style {
    _privateUserInterfaceStyle = style;
    [ThemeManager getUIStyle];
}

+ (UIColor *)appBackgroundColor {
    [ThemeManager getUIStyle];
    switch (self.userInterfaceStyle) {
        case UIUserInterfaceStyleLight:
            return [UIColor colorWithRed:242.0/255.0 green:242.0/255.0 blue:247.0/255.0 alpha:1.0];
            break;
        case UIUserInterfaceStyleDark:
        default:
            return [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:30.0/255.0 alpha:1.0];
            //return [UIColor blackColor];
            break;
    }
}

+ (UIColor *)widgetBackgroundColor {
    [ThemeManager getUIStyle];
    switch (self.userInterfaceStyle) {
        case UIUserInterfaceStyleLight:
            return [UIColor whiteColor];
            break;
        case UIUserInterfaceStyleDark:
        default:
            return [UIColor colorWithRed:44.0/255.0 green:44.0/255.0 blue:46.0/255.0 alpha:1.0];
            break;
    }
}

+ (UIColor *)separatorColor {
    [ThemeManager getUIStyle];
        switch (self.userInterfaceStyle) {
            case UIUserInterfaceStyleLight:
                return [UIColor colorWithWhite:0.1 alpha:0.28];
                break;
            case UIUserInterfaceStyleDark:
            default:
                return [UIColor colorWithWhite:0.28 alpha:1.0];
                break;
        }
    }


+ (UIColor *)textColor {
    [ThemeManager getUIStyle];
        switch (self.userInterfaceStyle) {
        case UIUserInterfaceStyleLight:
            return [UIColor blackColor];
            break;
        case UIUserInterfaceStyleDark:
        default:
            return [UIColor whiteColor];
            break;
    }
}

+ (UIColor *)appPrimaryColor {
    return [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0]; // #0A84FF
}

+ (UIColor *)appSecondaryColor {
    // return [UIColor colorWithRed:0.0 green:0.319 blue:0.64 alpha:1.0]; // 可换其他常用色
    UIColor* originalColor = [ThemeManager appPrimaryColor];
    
    UIColor *grayColor = [UIColor grayColor];
    CGFloat mixRatio = 0.3; // 混合比例，0.0 到 1.0

    CGFloat r1, g1, b1, a1;
    CGFloat r2, g2, b2, a2;

    [originalColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [grayColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2];

    CGFloat r = r1 * (1 - mixRatio) + r2 * mixRatio;
    CGFloat g = g1 * (1 - mixRatio) + g2 * mixRatio;
    CGFloat b = b1 * (1 - mixRatio) + b2 * mixRatio;
    CGFloat a = a1 * (1 - mixRatio) + a2 * mixRatio;

    UIColor *tonedColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
    
    return tonedColor; // 可换其他常用色
}

+ (UIColor *)appPrimaryColorWithAlpha {
    [ThemeManager getUIStyle];
    switch (self.userInterfaceStyle) {
        case UIUserInterfaceStyleLight:
            return [[ThemeManager appPrimaryColor] colorWithAlphaComponent:0.24]; // #0A84FF
            break;
        case UIUserInterfaceStyleDark:
        default:
            return [[ThemeManager appPrimaryColor] colorWithAlphaComponent:0.24];
            break;
    }
}

+ (UIColor *)textTintColorWithAlpha{
    return [[ThemeManager appPrimaryColor] colorWithAlphaComponent:0.24];
}

+ (UIColor *)textColorGray{
    return [UIColor colorWithRed:0.55 green:0.55 blue:0.6 alpha:0.95];
}

+ (UIColor *)lowProfileGray{
    return [UIColor colorWithRed:0.65 green:0.65 blue:0.65 alpha:0.4];
}


@end
