//
//  TemporaryHost.m
//  Moonlight
//
//  Created by Cameron Gutman on 12/1/15.
//  Copyright © 2015 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.8.3
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

#import "DataManager.h"
#import "TemporaryHost.h"
#import "TemporaryApp.h"

@implementation TemporaryHost

- (id) init {
    self = [super init];
    self.appList = [[NSMutableSet alloc] init];
    self.currentGame = @"0";
    self.state = StateUnknown;
    
    return self;
}

- (id) initFromHost:(Host*)host {
    self = [self init];
    
    self.address = host.address;
    
    NSSet *classes = [NSSet setWithObjects: [NSMutableSet class], nil];
    NSError *error = nil;
    self.activeAddressPool = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:host.activeAddressPool error:&error];
    if(self.activeAddressPool){
        for(NSString* address in _activeAddressPool){
            NSLog(@"%@, persisted addr: %@", host.name, address);
        }
    }
    else self.activeAddressPool = [[NSMutableSet alloc] init];
    
    self.externalAddress = host.externalAddress;
    self.localAddress = host.localAddress;
    self.ipv6Address = host.ipv6Address;
    if(!(host.mac == nil || [host.mac isEqualToString:@"00:00:00:00:00:00"])) self.mac = host.mac; // try to fix invalid mac happens in some cases
    self.name = host.name;
    self.uuid = host.uuid;
    self.serverCodecModeSupport = host.serverCodecModeSupport;
    self.serverCert = host.serverCert;
    
    // Older clients stored a non-URL-escaped IPv6 string. Try to detect that and fix it up.
    if (![self.ipv6Address containsString:@"["]) {
        self.ipv6Address = [Utils addressAndPortToAddressPortString:self.ipv6Address port:47989];
    }
    
    // Ensure we don't use a stale cached pair state if we haven't pinned the cert yet
    self.pairState = host.serverCert ? [host.pairState intValue] : PairStateUnpaired;
    
    NSMutableSet *appList = [[NSMutableSet alloc] init];

    for (App* app in host.appList) {
        TemporaryApp *tempApp = [[TemporaryApp alloc] initFromApp:app withTempHost:self];
        [appList addObject:tempApp];
    }
    
    self.appList = appList;
    
    return self;
}

- (void) propagateChangesToParent:(Host*)parentHost { // update persisted host data
    // Avoid overwriting existing data with nil if
    // we don't have everything populated in the temporary
    // host.
    if (self.address != nil) {
        parentHost.address = self.address;
    }
    if (self.externalAddress != nil) {
        parentHost.externalAddress = self.externalAddress;
    }
    if (self.localAddress != nil) {
        parentHost.localAddress = self.localAddress;
    }
    if (self.ipv6Address != nil) {
        parentHost.ipv6Address = self.ipv6Address;
    }
    
    if(self.activeAddressPool.count>0){
        NSError *error;
        parentHost.activeAddressPool = [NSKeyedArchiver archivedDataWithRootObject:self.activeAddressPool requiringSecureCoding:YES error:&error];
    }
    else [self.activeAddressPool addObject:self.activeAddress];
    
    // NSLog(@"Persisting activeAddressPool, pool count %lu ... %f, host: %@", (unsigned long)self.activeAddressPool.count, CACurrentMediaTime(), self.name);
    
    // try to fix invalid mac happens in some cases
    // 添加主机crash问题重点关注
    if (!(self.mac == nil || [self.mac isEqualToString:@"00:00:00:00:00:00"])) parentHost.mac = self.mac;
    if (self.serverCert != nil) {
        parentHost.serverCert = self.serverCert;
    }
    parentHost.name = self.name;
    parentHost.uuid = self.uuid;
    parentHost.serverCodecModeSupport = self.serverCodecModeSupport;
    parentHost.pairState = [NSNumber numberWithInt:self.pairState];
}

- (NSComparisonResult)compareName:(TemporaryHost *)other {
    return [self.name caseInsensitiveCompare:other.name];
}

- (NSUInteger)hash {
    return [self.uuid hash];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self.uuid isEqualToString:((Host*)object).uuid];
}

@end
