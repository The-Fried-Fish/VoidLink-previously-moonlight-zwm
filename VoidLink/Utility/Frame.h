#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface Frame : NSObject
@property (nonatomic) int frameNumber;
@property (nonatomic) int frameType;
@property (nonatomic) CFTimeInterval decodedAt;
@property (nonatomic) CMTime pts90;
@property (nonatomic) CMTime duration90;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic) CMSampleBufferRef sampleBuffer;
@property (nonatomic) CVPixelBufferRef pixelBuffer;

- (instancetype)initWithPixelBufffer:(CVPixelBufferRef)pixelBuffer frameNumber:(int)frameNumber frameType:(int)frameType pts:(CMTime)pts;
- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer frameNumber:(int)frameNumber frameType:(int)frameType;
- (void)dealloc;
- (CFTimeInterval)pts;
- (CFTimeInterval)duration;
- (void)setDurationFromNext:(Frame *)nextFrame;
- (BOOL)durationIsValid;
- (CFDictionaryRef)getFormatDescExtensions;
- (size_t)width;
- (size_t)height;

@end
