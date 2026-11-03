//
//  IdManager.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/31/15.
//  Copyright © 2015 Moonlight Stream. All rights reserved.
//

@interface IdManager : NSObject

+ (NSString*) getUniqueId;
+ (NSString * _Nonnull)generateUniqueId;

@end
