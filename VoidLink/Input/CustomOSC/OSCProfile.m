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
        self.buttonStatesEncoded = buttonStates;
        self.isSelected = isSelected;
    }
    
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.buttonStatesEncoded forKey:@"buttonStates"];
    [encoder encodeBool:self.isSelected forKey:@"isSelected"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.buttonStatesEncoded = [decoder decodeObjectForKey:@"buttonStates"];
        self.isSelected = [decoder decodeBoolForKey:@"isSelected"];
    }
    
    return self;
}

@end
