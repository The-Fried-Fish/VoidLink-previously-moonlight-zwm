//
//  Logger.h
//  Moonlight
//
//  Created by Diego Waxemberg on 2/10/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#ifndef Limelight_Logger_h
#define Limelight_Logger_h

#import <dispatch/dispatch.h>
#import <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LOG_D,
    LOG_I,
    LOG_W,
    LOG_E
} LogLevel;

#define PRFX_DEBUG @"<DEBUG>"
#define PRFX_INFO @"<INFO>"
#define PRFX_WARN @"<WARN>"
#define PRFX_ERROR @"<ERROR>"

void Log(LogLevel level, NSString* fmt, ...);
void LogTag(LogLevel level, NSString* tag, NSString* fmt, ...);

#ifdef __cplusplus
}
#endif

// LogOnce() is a one-time log message for use in hot areas of the code
#define CONCAT(a,b)   CONCAT2(a,b)
#define CONCAT2(a,b)  a##b

#define LogOnce(level, fmt, ...)                                    \
  do {                                                              \
    static dispatch_once_t CONCAT(_onceToken_, __LINE__);           \
    dispatch_once(&CONCAT(_onceToken_, __LINE__), ^{                \
      Log(level, fmt, ##__VA_ARGS__);                               \
    });                                                             \
  } while (0)

#endif

// Disable all logging in release mode for performance
#ifdef DEBUG
    #define Log(level, fmt, ...) \
        LogTag(level, NULL, fmt, ##__VA_ARGS__)
#else
    #define Log(level, fmt, ...) do {} while(0)
#endif

// FrameQueue log helpers FQLog() is a no-op unless FRAME_QUEUE_VERBOSE is defined

static inline NSString *FQQoSString(qos_class_t qos) {
    switch (qos) {
        case QOS_CLASS_USER_INTERACTIVE: return @"UI-25";
        case QOS_CLASS_USER_INITIATED:   return @"IN-19";
        case QOS_CLASS_DEFAULT:          return @"DF-15";
        case QOS_CLASS_UTILITY:          return @"UT-11";
        case QOS_CLASS_BACKGROUND:       return @"BG-09";
        default:                         return [NSString stringWithFormat:@"??-%d", qos];
    }
}

static inline NSString *FQLogPrefix(void) {
    CFTimeInterval now = CACurrentMediaTime();
    NSString *qos = FQQoSString(qos_class_self());
    return [NSString stringWithFormat:@"[%.3f] [%@]", now, qos];
}

#if defined(FRAME_QUEUE_VERBOSE)
  #define FQLog(level, fmt, ...) \
    Log(level, @"%@ " fmt, FQLogPrefix(), ##__VA_ARGS__)
#else
  #define FQLog(level, fmt, ...) do {} while(0)
#endif
