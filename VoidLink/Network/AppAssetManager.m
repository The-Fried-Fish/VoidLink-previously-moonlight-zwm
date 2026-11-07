//
//  AppManager.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/25/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "AppAssetManager.h"
#import <ImageIO/ImageIO.h>
#import "CryptoManager.h"
#import "Utils.h"
#import "HttpResponse.h"
#import "AppAssetRetriever.h"

@implementation AppAssetManager {
    NSOperationQueue* _opQueue;
    id<AppAssetCallback> _callback;
}

static const int MAX_REQUEST_COUNT = 4;

+ (NSString*) boxArtPathForApp:(TemporaryApp*)app {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *filePath = [paths objectAtIndex:0];
    
    // Keep app assets separate by host UUID
    filePath = [filePath stringByAppendingPathComponent:app.host.uuid];
    
    // Use the app ID as the file name
    filePath = [filePath stringByAppendingPathComponent:app.id];
    
    // Add a png extension
    filePath = [filePath stringByAppendingPathExtension:@"png"];
    
    return filePath;
}

+ (UIImage*)loadBoxArtForApp:(TemporaryApp*)app {
    const unsigned long long maxFileBytes = 6ULL * 1024 * 1024;
    const size_t maxPixelSize = 600;
    const size_t maxBitmapBytes = maxPixelSize * maxPixelSize * 4;
    NSString* path = [self boxArtPathForApp:app];
    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (attributes == nil || attributes.fileSize == 0 || attributes.fileSize > maxFileBytes) {
        return nil;
    }

    NSDictionary* options = @{(__bridge NSString*)kCGImageSourceShouldCache: @NO};
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],
                                                       (__bridge CFDictionaryRef)options);
    if (source == NULL) {
        return nil;
    }
    NSDictionary* properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    unsigned long long width = [properties[(__bridge NSString*)kCGImagePropertyPixelWidth] unsignedLongLongValue];
    unsigned long long height = [properties[(__bridge NSString*)kCGImagePropertyPixelHeight] unsignedLongLongValue];
    // Recognize GFE placeholder dimensions before resizing changes them.
    if (width == 0 || height == 0 || (width == 130 && height == 180) || (width == 628 && height == 888)) {
        CFRelease(source);
        return nil;
    }

    NSDictionary* thumbnailOptions = @{
        (__bridge NSString*)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString*)kCGImageSourceThumbnailMaxPixelSize: @(maxPixelSize),
        (__bridge NSString*)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (__bridge NSString*)kCGImageSourceShouldCacheImmediately: @YES
    };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)thumbnailOptions);
    CFRelease(source);
    if (image == NULL) {
        return nil;
    }
    size_t imageWidth = CGImageGetWidth(image);
    size_t imageHeight = CGImageGetHeight(image);
    size_t bytesPerRow = CGImageGetBytesPerRow(image);
    if (imageWidth == 0 || imageHeight == 0 || imageWidth > maxPixelSize || imageHeight > maxPixelSize ||
        bytesPerRow == 0 || bytesPerRow > maxBitmapBytes / imageHeight) {
        CGImageRelease(image);
        return nil;
    }
    UIImage* result = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    return result;
}

- (id) initWithCallback:(id<AppAssetCallback>)callback {
    self = [super init];
    _callback = callback;
    _opQueue = [[NSOperationQueue alloc] init];
    [_opQueue setMaxConcurrentOperationCount:MAX_REQUEST_COUNT];
    
    return self;
}

- (void) retrieveAssetsFromHost:(TemporaryHost*)host {
    for (TemporaryApp* app in host.appList) {
        // if (![[NSFileManager defaultManager] fileExistsAtPath:[AppAssetManager boxArtPathForApp:app]]) {
        if (true) {
            NSLog(@"retrieve appImage");
            AppAssetRetriever* retriever = [[AppAssetRetriever alloc] init];
            retriever.app = app;
            retriever.host = host;
            retriever.callback = _callback;
            
            [_opQueue addOperation:retriever];
        }
    }
}

- (void) stopRetrieving {
    [_opQueue cancelAllOperations];
}

- (void) sendCallBackForApp:(TemporaryApp*)app {
    [_callback receivedAssetForApp:app];
}

@end
