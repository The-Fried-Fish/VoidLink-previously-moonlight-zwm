//
//  OSCProfile.m
//  Moonlight
//
//  Created by Long Le on 12/22/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "OSCProfile.h"

@implementation OSCProfile

- (id) initWithName:(NSString*)name buttonStates:(NSMutableArray*)buttonStates isSelected:(BOOL)isSelected {
    if ((self = [self init])) {
        self.name = name;
        self.buttonStates = buttonStates;
        self.isSelected = isSelected;
        
        // 初始化配对相关属性
        self.pairedProfileName = nil;
        self.isLandscapeLayout = NO;
        self.isPaired = NO;
    }
    
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.buttonStates forKey:@"buttonStates"];
    [encoder encodeBool:self.isSelected forKey:@"isSelected"];
    
    // 编码配对相关属性
    [encoder encodeObject:self.pairedProfileName forKey:@"pairedProfileName"];
    [encoder encodeBool:self.isLandscapeLayout forKey:@"isLandscapeLayout"];
    [encoder encodeBool:self.isPaired forKey:@"isPaired"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.buttonStates = [decoder decodeObjectForKey:@"buttonStates"];
        self.isSelected = [decoder decodeBoolForKey:@"isSelected"];
        
        // 解码配对相关属性，提供默认值以保持向后兼容性
        self.pairedProfileName = [decoder decodeObjectForKey:@"pairedProfileName"];
        self.isLandscapeLayout = [decoder decodeBoolForKey:@"isLandscapeLayout"];
        self.isPaired = [decoder decodeBoolForKey:@"isPaired"];
        
        // 验证必要的数据是否有效
        if (self.name == nil) {
            NSLog(@"警告：OSCProfile解码时name为nil，使用默认名称");
            self.name = @"未命名配置";
        }
        
        if (self.buttonStates == nil) {
            NSLog(@"警告：OSCProfile解码时buttonStates为nil，使用空数组");
            self.buttonStates = [[NSMutableArray alloc] init];
        }
    }
    
    return self;
}

@end
