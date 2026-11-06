//
//  DiscoveryWorker.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/2/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "DiscoveryWorker.h"
#import "Utils.h"
#import "HttpManager.h"
#import "ServerInfoResponse.h"
#import "HttpRequest.h"
#import "AppDelegate.h"
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "VoidLink-Swift.h"

@implementation DiscoveryWorker {
    TemporaryHost* _host;
    NSString* _uniqueId;
    void (^_onHostChanged)(TemporaryHost*);
}

static const float POLL_RATE = 2.0f; // Poll every 2 seconds
static const NSUInteger DISCOVERY_BATCH_SIZE = 3;

- (id) initWithHost:(TemporaryHost*)host
           uniqueId:(NSString*)uniqueId
     onHostChanged:(void (^)(TemporaryHost*))onHostChanged {
    self = [super init];
    _host = host;
    _uniqueId = uniqueId;
    _onHostChanged = [onHostChanged copy];
    return self;
}

- (TemporaryHost*) getHost {
    return _host;
}

- (void)main {
    while (!self.cancelled) {
        [self discoverHost];
        if (!self.cancelled) {
            [NSThread sleepForTimeInterval:POLL_RATE];
        }
    }
}

- (NSArray<NSString *> *)getHostAddressList {
    NSMutableArray<NSString *> *addresses = [NSMutableArray array];
    NSMutableSet<NSString *> *seenEndpoints = [NSMutableSet set];
    NSSet<NSString *> *history = [_host addressPoolSnapshot];
    // Try LAN and the last working address first, followed by the configured
    // endpoints and every remaining address from the history.
    NSArray<NSString *> *preferred = @[_host.localAddress ?: @"", _host.activeAddress ?: @"",
                                       _host.address ?: @"", _host.externalAddress ?: @"",
                                       _host.ipv6Address ?: @""];
    for (NSString *address in [preferred arrayByAddingObjectsFromArray:history.allObjects]) {
        if (address.length == 0) {
            continue;
        }
        NSString *hostName = [Utils addressPortStringToAddress:address];
        if (hostName.length == 0) {
            continue;
        }
        NSString *endpoint = [Utils addressAndPortToAddressPortString:hostName
                                                                port:[Utils addressPortStringToPort:address]];
        if (![seenEndpoints containsObject:endpoint]) {
            [seenEndpoints addObject:endpoint];
            [addresses addObject:address];
        }
    }
    return addresses;
}

- (ServerInfoResponse *)firstResponseInBatch:(NSArray<NSString *> *)addresses
                                       cert:(NSData *)cert
                                    address:(NSString **)workingAddress {
    NSMutableArray<HttpManager *> *managers = [NSMutableArray arrayWithCapacity:addresses.count];
    for (NSString *address in addresses) {
        [managers addObject:[[HttpManager alloc] initWithAddress:address httpsPort:0 serverCert:cert]];
    }

    NSObject *lock = [[NSObject alloc] init];
    dispatch_semaphore_t batchFinished = dispatch_semaphore_create(0);
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    __block NSUInteger pending = addresses.count;
    __block ServerInfoResponse *firstResponse = nil;
    __block NSString *firstAddress = nil;

    [managers enumerateObjectsUsingBlock:^(HttpManager *manager, NSUInteger index, BOOL *stop) {
        dispatch_async(queue, ^{
            ServerInfoResponse *response = nil;
            if (!self.cancelled) {
                response = [self requestInfoWithManager:manager];
            }
            BOOL valid = response && [self checkResponse:response];
            @synchronized (lock) {
                pending--;
                if (!firstResponse && valid) {
                    firstResponse = response;
                    firstAddress = addresses[index];
                    dispatch_semaphore_signal(batchFinished);
                } else if (!firstResponse && pending == 0) {
                    dispatch_semaphore_signal(batchFinished);
                }
            }
        });
    }];

    // A valid reply ends the batch immediately. Failure requires every reply.
    dispatch_semaphore_wait(batchFinished, DISPATCH_TIME_FOREVER);
    for (HttpManager *manager in managers) {
        [manager cancelRequests];
    }
    *workingAddress = firstAddress;
    return firstResponse;
}

- (void) discoverHost {
    NSArray<NSString *> *addresses = [self getHostAddressList];
    NSData *cert = _host.serverCert;
    NSString *workingAddress = nil;
    ServerInfoResponse *workingResponse = nil;

    Log(LOG_D, @"%@ has %lu unique addresses", _host.name, (unsigned long)addresses.count);

    // Give known hosts a second full pass before declaring them offline.
    int attempts = _host.state == StateUnknown ? 1 : 2;
    for (int attempt = 0; attempt < attempts && !workingResponse; attempt++) {
        for (NSUInteger index = 0; index < addresses.count; index += DISCOVERY_BATCH_SIZE) {
            if (self.cancelled) {
                return;
            }
            NSRange range = NSMakeRange(index, MIN(DISCOVERY_BATCH_SIZE, addresses.count - index));
            NSArray<NSString *> *batch = [addresses subarrayWithRange:range];
            workingResponse = [self firstResponseInBatch:batch cert:cert address:&workingAddress];
            if (self.cancelled) {
                return;
            }
            if (workingResponse) {
                break;
            }
        }
    }
    if (self.cancelled) {
        return;
    }

    BOOL receivedResponse = workingResponse != nil;
    BOOL cardContentsChanged = NO;
    if (receivedResponse) {
        NSString *previousName = _host.name;
        NSString *previousMac = _host.mac;
        PairState previousPairState = _host.pairState;
        _host.activeAddress = workingAddress;
        [_host rememberAddress:workingAddress];
        [workingResponse populateHost:_host];
        cardContentsChanged = previousPairState != _host.pairState ||
            (previousName != _host.name && ![previousName isEqualToString:_host.name]) ||
            (previousMac != _host.mac && ![previousMac isEqualToString:_host.mac]);

        DataManager *dataManager = [[DataManager alloc] init];
        [dataManager updateHost:_host];
    }

    State state = receivedResponse ? StateOnline : StateOffline;
    if (_host.state != state) {
        _host.state = state;
        cardContentsChanged = YES;
    }
    if (cardContentsChanged && _onHostChanged) {
        _onHostChanged(_host);
    }
    if (receivedResponse) {
        Log(LOG_D, @"Received response from: %@\n{\n\t address:%@ \n\t localAddress:%@ \n\t externalAddress:%@ \n\t ipv6Address:%@ \n\t uuid:%@ \n\t mac:%@ \n\t pairState:%d \n\t online:%d \n\t activeAddress:%@ \n}", _host.name, _host.address, _host.localAddress, _host.externalAddress, _host.ipv6Address, _host.uuid, _host.mac, _host.pairState, _host.state, _host.activeAddress);
    }
}

- (ServerInfoResponse *)requestInfoWithManager:(HttpManager *)manager {
    ServerInfoResponse *response = [[ServerInfoResponse alloc] init];
    [manager executeRequestSynchronously:[HttpRequest requestForResponse:response
                                                         withUrlRequest:[manager newServerInfoRequest:true]
                                          fallbackError:401 fallbackRequest:[manager newHttpServerInfoRequest]]];
    return response;
}

- (BOOL) checkResponse:(ServerInfoResponse*)response {
    if ([response isStatusOk]) {
        // If the response is from a different host then do not update this host
        if ((_host.uuid == nil || [[response getStringTag:TAG_UNIQUE_ID] isEqualToString:_host.uuid])) {
            return YES;
        } else {
            Log(LOG_I, @"Received response from incorrect host: %@ expected: %@", [response getStringTag:TAG_UNIQUE_ID], _host.uuid);
        }
    }
    return NO;
}

@end
