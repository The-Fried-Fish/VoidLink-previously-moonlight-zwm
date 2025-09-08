//
//  LocalizationHelper.m
//  VoidLink
//
//  Created by True砖家 on 2024/6/30.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import "LocalizationHelper.h"

@implementation LocalizationHelper

/* Fallback localized strings for keys not found in Localizable.xcstrings.
 * This allows us to ship new strings without immediately editing the catalog.
 */
+ (NSString *)osc_languageCodePrefix {
    NSString *lang = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    if ([lang hasPrefix:@"zh"]) return @"zh";
    return @"en";
}

+ (NSDictionary *)osc_fallbackDictionaryForLanguage:(NSString *)prefix {
    static NSDictionary *zhDict; static NSDictionary *enDict; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zhDict = @{
            @"PairingHelpTitle": @"配对布局说明",
            @"PairingHelpMessage": @"你可以提前创建好偏好的横屏和竖屏布局，在这里进行绑定。绑定后，旋转屏幕将在绑定的两个布局之间切换。\n注意：默认布局和模板布局不支持绑定。",
            @"Unpair": @"解除配对",
            @"BindOrientationLayout:%@": @"绑定%@布局",
            @"PortraitShort": @"竖屏",
            @"LandscapeShort": @"横屏",
            @"ConfirmDelete": @"确认删除",
            @"ConfirmDeleteProfile:%@": @"确定要删除布局'%@'吗？",
            @"DeleteTemplateNotAllowed:%@": @"删除'%@'模板布局是不被允许的",
            @"UnnamedProfile": @"未命名配置",
            @"OK": @"我知道了",
            @"Save": @"保存",
            @"Cancel": @"取消",
            @"CurrentLayoutShort": @"当前布局",
            @"SelectLayoutToPair:%@": @"选择要绑定的%@布局"
        };
        enDict = @{
            @"PairingHelpTitle": @"Pairing Help",
            @"PairingHelpMessage": @"You can pre-create preferred landscape and portrait layouts and pair them here. After pairing, rotating the device switches between the two layouts.\nNote: Default and template layouts do not support pairing.",
            @"Unpair": @"Unpair",
            @"BindOrientationLayout:%@": @"Pair %@",
            @"PortraitShort": @"Portrait",
            @"LandscapeShort": @"Landscape",
            @"ConfirmDelete": @"Confirm Delete",
            @"ConfirmDeleteProfile:%@": @"Are you sure you want to delete '%@'?",
            @"DeleteTemplateNotAllowed:%@": @"Deleting template layout '%@' is not allowed",
            @"UnnamedProfile": @"Untitled",
            @"OK": @"OK",
            @"Save": @"Save",
            @"Cancel": @"Cancel",
            @"CurrentLayoutShort": @"Current",
            @"SelectLayoutToPair:%@": @"Select layout to pair: %@"
        };
    });
    return [prefix isEqualToString:@"zh"] ? zhDict : enDict;
}

+ (NSString *)localizedStringForKey:(NSString *)key, ... {
    va_list args;
    va_start(args, key);

    NSString *format = NSLocalizedStringFromTable(key, @"Localizable", nil);
    if ([format isEqualToString:key]) { // not found in catalog, use fallback
        NSString *lang = [self osc_languageCodePrefix];
        NSString *fallback = [[self osc_fallbackDictionaryForLanguage:lang] objectForKey:key];
        if (fallback) {
            format = fallback;
        }
    }
    NSString *result = [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);
    return result;
}

@end
