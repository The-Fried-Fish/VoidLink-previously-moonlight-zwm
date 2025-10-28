//
//  Connection.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/19/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2025.9
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//

#import "Connection.h"
#import "Plot.h"
#import "Utils.h"
#import "DataManager.h"

#import <VideoToolbox/VideoToolbox.h>

#define SDL_MAIN_HANDLED
#import <SDL.h>

#include "Limelight.h"
#include "opus_multistream.h"
#include "VoidLink-Swift.h"

@implementation Connection {
    SERVER_INFORMATION _serverInfo;
    STREAM_CONFIGURATION _streamConfig;
    CONNECTION_LISTENER_CALLBACKS _clCallbacks;
    DECODER_RENDERER_CALLBACKS _drCallbacks;
    AUDIO_RENDERER_CALLBACKS _arCallbacks;
    char _hostString[256];
    char _appVersionString[32];
    char _gfeVersionString[32];
    char _rtspSessionUrl[128];
}

static NSLock* initLock;
static OpusMSDecoder* opusDecoder;
static id<ConnectionCallbacks> _callbacks;
static int lastFrameNumber;
static int activeVideoFormat;
static video_stats_t currentVideoStats;
static video_stats_t lastVideoStats;
static NSLock* videoStatsLock;

static SDL_AudioDeviceID audioDevice;
static OPUS_MULTISTREAM_CONFIGURATION audioConfig;
static void* audioBuffer;
static float volume = 1.0;
static int audioFrameSize;

static bool useSystemAudioEngine;
static AVAudioEngine *audioEngine;
static AVAudioPlayerNode *audioPlayerNode;
static AVAudioPCMBuffer *pcmBuffer;
static AVAudioFormat *audioFormat;

static VideoDecoderRenderer* renderer;

static BandwidthTracker *bwTracker;

int DrDecoderSetup(int videoFormat, int width, int height, int redrawRate, void* context, int drFlags)
{
    [renderer setupWithVideoFormat:videoFormat width:width height:height frameRate:redrawRate];
    lastFrameNumber = 0;
    activeVideoFormat = videoFormat;
    Log(LOG_I, @"Active video format: 0x%x", activeVideoFormat);
    memset(&currentVideoStats, 0, sizeof(currentVideoStats));
    memset(&lastVideoStats, 0, sizeof(lastVideoStats));
    bwTracker = [[BandwidthTracker alloc] initWithWindowSeconds:10 bucketIntervalMs:250];
    return 0;
}

void DrCleanup(void)
{
    [renderer cleanup];
}

-(BandwidthTracker *) getBwTracker
{
    return bwTracker;
}

-(BOOL) getVideoStats:(video_stats_t*)stats
{
    // We return lastVideoStats because it is a complete 1 second window
    [videoStatsLock lock];
    if (lastVideoStats.endTime != 0) {
        memcpy(stats, &lastVideoStats, sizeof(*stats));
        [videoStatsLock unlock];

        // Pull in the separately-collected renderer stats
        [renderer getAllStats:stats];

        return YES;
    }
    [videoStatsLock unlock];
    return NO;
}

-(NSString*) getActiveCodecName
{
    switch (activeVideoFormat)
    {
        case VIDEO_FORMAT_H264:
            return @"H.264";
        case VIDEO_FORMAT_H264_HIGH8_444:
            return @"H.264 YUV444";
        case VIDEO_FORMAT_H265:
            return @"HEVC";
        case VIDEO_FORMAT_H265_REXT8_444:
            return @"HEVC YUV444";
        case VIDEO_FORMAT_H265_MAIN10:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"HEVC Main 10 HDR";
            }
            else {
                return @"HEVC Main 10 SDR";
            }
        case VIDEO_FORMAT_H265_REXT10_444:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"HEVC Main 10 YUV444 HDR";
            }
            else {
                return @"HEVC Main 10 YUV444 SDR";
            }
        case VIDEO_FORMAT_AV1_MAIN8:
            return @"AV1";
        case VIDEO_FORMAT_AV1_HIGH8_444:
            return @"AV1 YUV444";
        case VIDEO_FORMAT_AV1_MAIN10:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"AV1 10-bit HDR";
            }
            else {
                return @"AV1 10-bit SDR";
            }
        case VIDEO_FORMAT_AV1_HIGH10_444:
            if (LiGetCurrentHostDisplayHdrMode()) {
                return @"AV1 10-bit YUV444 HDR";
            }
            else {
                return @"AV1 10-bit YUV444 SDR";
            }
        default:
            return @"UNKNOWN";
    }
}

int DrSubmitDecodeUnit(PDECODE_UNIT decodeUnit)
{
    int offset = 0;
    int ret;
    CFTimeInterval decodeStartTime = CACurrentMediaTime();

    unsigned char* data = (unsigned char*) malloc(decodeUnit->fullLength);
    if (data == NULL) {
        // A frame was lost due to OOM condition
        return DR_NEED_IDR;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (!lastFrameNumber) {
        currentVideoStats.startTime = now;
        lastFrameNumber = decodeUnit->frameNumber;
    }
    else {
        // Flip stats roughly every second
        if (now - currentVideoStats.startTime >= 1.0f) {
            currentVideoStats.endTime = now;
            
            [videoStatsLock lock];
            lastVideoStats = currentVideoStats;
            [videoStatsLock unlock];
            
            memset(&currentVideoStats, 0, sizeof(currentVideoStats));
            currentVideoStats.startTime = now;
        }
        
        // Any frame number greater than m_LastFrameNumber + 1 represents a dropped frame
        int droppedFrames = decodeUnit->frameNumber - (lastFrameNumber + 1);
        if (droppedFrames > 0) {
            currentVideoStats.networkDroppedFrames += droppedFrames;
            currentVideoStats.totalFrames += droppedFrames;

            Log(LOG_W, @"Network dropped %d frame(s): %d - %d", droppedFrames, lastFrameNumber + 1, decodeUnit->frameNumber - 1);
        }
        lastFrameNumber = decodeUnit->frameNumber;
    }
    
    if (decodeUnit->frameHostProcessingLatency != 0) {
        if (currentVideoStats.minHostProcessingLatency == 0 || decodeUnit->frameHostProcessingLatency < currentVideoStats.minHostProcessingLatency) {
            currentVideoStats.minHostProcessingLatency = decodeUnit->frameHostProcessingLatency;
        }
        
        if (decodeUnit->frameHostProcessingLatency > currentVideoStats.maxHostProcessingLatency) {
            currentVideoStats.maxHostProcessingLatency = decodeUnit->frameHostProcessingLatency;
        }
        
        currentVideoStats.framesWithHostProcessingLatency++;
        currentVideoStats.totalHostProcessingLatency += decodeUnit->frameHostProcessingLatency;
    }
    
    currentVideoStats.receivedFrames++;
    currentVideoStats.totalFrames++;

    [bwTracker addBytes:decodeUnit->fullLength];

    PLENTRY entry = decodeUnit->bufferList;
    while (entry != NULL) {
        // Submit parameter set NALUs directly since no copy is required by the decoder
        if (entry->bufferType != BUFFER_TYPE_PICDATA) {
            ret = [renderer submitDecodeBuffer:(unsigned char*)entry->data
                                        length:entry->length
                                    bufferType:entry->bufferType
                                    decodeUnit:decodeUnit
                               decodeStartTime:decodeStartTime];
            if (ret != DR_OK) {
                free(data);
                return ret;
            }
        }
        else {
            memcpy(&data[offset], entry->data, entry->length);
            offset += entry->length;
        }

        entry = entry->next;
    }

    // This function will take our picture data buffer
    return [renderer submitDecodeBuffer:data
                                 length:offset
                             bufferType:BUFFER_TYPE_PICDATA
                             decodeUnit:decodeUnit
                        decodeStartTime:decodeStartTime];
}

int ArInit(int audioConfiguration, POPUS_MULTISTREAM_CONFIGURATION opusConfig, void* context, int flags)
{
    int err;
    SDL_AudioSpec want, have;
    
    if (SDL_InitSubSystem(SDL_INIT_AUDIO) < 0) {
        Log(LOG_E, @"Failed to initialize audio subsystem: %s\n", SDL_GetError());
        return -1;
    }
        
    SDL_zero(want);
    want.freq = opusConfig->sampleRate;
    want.format = AUDIO_F32;
    want.channels = opusConfig->channelCount;
    want.samples = opusConfig->samplesPerFrame;

    audioDevice = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (audioDevice == 0) {
        Log(LOG_E, @"Failed to open audio device: %s\n", SDL_GetError());
        ArCleanup();
        return -1;
    }
    
    audioConfig = *opusConfig;
    audioFrameSize = opusConfig->samplesPerFrame * sizeof(float) * opusConfig->channelCount;
    audioBuffer = SDL_malloc(audioFrameSize);
    if (audioBuffer == NULL) {
        Log(LOG_E, @"Failed to allocate audio frame buffer");
        ArCleanup();
        return -1;
    }
    
    opusDecoder = opus_multistream_decoder_create(opusConfig->sampleRate,
                                                  opusConfig->channelCount,
                                                  opusConfig->streams,
                                                  opusConfig->coupledStreams,
                                                  opusConfig->mapping,
                                                  &err);
    if (opusDecoder == NULL) {
        Log(LOG_E, @"Failed to create Opus decoder");
        ArCleanup();
        return -1;
    }
    
    // Start playback
    SDL_PauseAudioDevice(audioDevice, 0);
    
    // Disable lowering volume of other audio streams (SDL sets AVAudioSessionCategoryOptionDuckOthers by default)
    // AVAudioSessionCategoryOptionAllowBluetoothA2DP
    // AVAudioSessionCategoryOptionAllowBluetooth
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* tempSettings = [dataMan getSettings];
    bool useBluetoothD2P = tempSettings.useBuiltinMic || !tempSettings.redirectMic;
    AVAudioSessionCategoryOptions bluetoothAudioOption = useBluetoothD2P ? AVAudioSessionCategoryOptionAllowBluetoothA2DP : AVAudioSessionCategoryOptionAllowBluetooth;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:tempSettings.redirectMic ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeDefault
                 options:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker|bluetoothAudioOption
                   error:nil];
    [session setActive:YES error:nil];
    
    AudioEngineInit(audioConfig.sampleRate, audioConfig.channelCount);

    return 0;
}

void ArCleanup(void)
{
    if (opusDecoder != NULL) {
        opus_multistream_decoder_destroy(opusDecoder);
        opusDecoder = NULL;
    }
    
    if (audioDevice != 0) {
        SDL_CloseAudioDevice(audioDevice);
        audioDevice = 0;
    }
    
    if (audioBuffer != NULL) {
        SDL_free(audioBuffer);
        audioBuffer = NULL;
    }
    
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
}

+ (void)setVolume:(float)linearVolume{
    if (linearVolume <= 0.0f) linearVolume = 0.0f;
    if (linearVolume >= 1.0f) linearVolume = 1.0f;
    CGFloat exponent = 2.5;
    volume = powf(linearVolume, exponent);
}

+ (void)setUseSystemAudioEngine:(bool)useSysAudioEngine{
    useSystemAudioEngine = useSysAudioEngine;
}

void AudioEngineInit(int sampleRate, int channelCount) {
    
    audioEngine = [[AVAudioEngine alloc] init];
    audioPlayerNode = [[AVAudioPlayerNode alloc] init];
    
    [audioEngine attachNode:audioPlayerNode];
        
    AVAudioChannelLayout *layout;
    
    switch (channelCount) {
        case 2:
        default:
            audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                           sampleRate:sampleRate
                                                             channels:channelCount
                                                          interleaved:NO];
            break;
        case 6:
            layout =
                [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_MPEG_5_1_A];
            audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                           sampleRate:sampleRate
                                                          interleaved:NO
                                                        channelLayout:layout];
            break;
        case 8:
            layout =
                [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_MPEG_7_1_A];
            audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                           sampleRate:sampleRate
                                                          interleaved:NO
                                                        channelLayout:layout];
            break;
    }
    
    if(!audioFormat) return;
    
    [audioEngine connect:audioPlayerNode to:audioEngine.mainMixerNode format:audioFormat];

    NSError *err = nil;
    if (![audioEngine startAndReturnError:&err]) {
        NSLog(@"AudioEngine start error: %@", err);
    }
    
    [audioPlayerNode play];
}

void ArDecodeAndPlaySample(char* sampleData, int sampleLength)
{
    int decodeLen;
    
    // Don't queue if there's already more than 30 ms of audio data waiting
    // in Moonlight's audio queue.
    if (LiGetPendingAudioDuration() > 30) {
        return;
    }

    decodeLen = opus_multistream_decode_float(opusDecoder,
                                              (unsigned char*)sampleData,
                                              sampleLength,
                                              (float*)audioBuffer,
                                              audioConfig.samplesPerFrame,
                                              0);
    
    if (decodeLen > 0) {
        // Provide backpressure on the queue to ensure too many frames don't build up
        // in SDL's audio queue.
        
        float* fbuf = (float*)audioBuffer;
        
        if(useSystemAudioEngine) {
            // 创建 AVAudioPCMBuffer
            AVAudioFrameCount frameCount = decodeLen;
            AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:frameCount];
            buffer.frameLength = frameCount;
            
            // 拷贝数据到 buffer
            for (int ch = 0; ch < audioConfig.channelCount; ch++) {
                float *dst = buffer.floatChannelData[ch];
                for (int i = 0; i < decodeLen; i++) {
                    dst[i] = fbuf[i * audioConfig.channelCount + ch] * volume; // 非交错数据
                }
            }
            // 播放
            [audioPlayerNode scheduleBuffer:buffer completionHandler:nil];
        }
        
        else{
            if(volume != 1.0){
                int totalSamples = decodeLen * audioConfig.channelCount;
                for (int i = 0; i < totalSamples; i++) {
                    fbuf[i] *= volume;
                }
            }
            
            while (SDL_GetQueuedAudioSize(audioDevice) / audioFrameSize > 10) {
                [NSThread sleepForTimeInterval:0.001f];
            }
            
            if (SDL_QueueAudio(audioDevice,
                               audioBuffer,
                               sizeof(float) * decodeLen * audioConfig.channelCount) < 0) {
                Log(LOG_E, @"Failed to queue audio sample: %s\n", SDL_GetError());
            }
        }
    }
}

void ClStageStarting(int stage)
{
    [_callbacks stageStarting:LiGetStageName(stage)];
}

void ClStageComplete(int stage)
{
    [_callbacks stageComplete:LiGetStageName(stage)];
}

void ClStageFailed(int stage, int errorCode)
{
    [_callbacks stageFailed:LiGetStageName(stage) withError:errorCode portTestFlags:LiGetPortFlagsFromStage(stage)];
}

void ClConnectionStarted(void)
{
    [_callbacks connectionStarted];
}

void ClConnectionTerminated(int errorCode)
{
    [_callbacks connectionTerminated: errorCode];
}

void ClLogMessage(const char* format, ...)
{
    va_list va;
    va_start(va, format);
    vfprintf(stderr, format, va);
    va_end(va);
}

void ClRumble(unsigned short controllerNumber, unsigned short lowFreqMotor, unsigned short highFreqMotor)
{
    [_callbacks rumble:controllerNumber lowFreqMotor:lowFreqMotor highFreqMotor:highFreqMotor];
}

void ClConnectionStatusUpdate(int status)
{
    [_callbacks connectionStatusUpdate:status];
}

void ClSetHdrMode(bool enabled)
{
    [renderer setHdrMode:enabled];
    [_callbacks setHdrMode:enabled];
}

void ClRumbleTriggers(uint16_t controllerNumber, uint16_t leftTriggerMotor, uint16_t rightTriggerMotor)
{
    [_callbacks rumbleTriggers:controllerNumber leftTrigger:leftTriggerMotor rightTrigger:rightTriggerMotor];
}

void ClSetMotionEventState(uint16_t controllerNumber, uint8_t motionType, uint16_t reportRateHz)
{
    [_callbacks setMotionEventState:controllerNumber motionType:motionType reportRateHz:reportRateHz];
}

void ClSetControllerLED(uint16_t controllerNumber, uint8_t r, uint8_t g, uint8_t b)
{
    [_callbacks setControllerLed:controllerNumber r:r g:g b:b];
}

-(void) terminate
{
    // Interrupt any action blocking LiStartConnection(). This is
    // thread-safe and done outside initLock on purpose, since we
    // won't be able to acquire it if LiStartConnection is in
    // progress.
    LiInterruptConnection();
    [audioPlayerNode stop];
    [audioEngine stop];

    // We dispatch this async to get out because this can be invoked
    // on a thread inside common and we don't want to deadlock. It also avoids
    // blocking on the caller's thread waiting to acquire initLock.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [initLock lock];
        LiStopConnection();
        [initLock unlock];
    });
}

-(id) initWithConfig:(StreamConfiguration*)config renderer:(VideoDecoderRenderer*)myRenderer connectionCallbacks:(id<ConnectionCallbacks>)callbacks
{
    self = [super init];

    // Use a lock to ensure that only one thread is initializing
    // or deinitializing a connection at a time.
    if (initLock == nil) {
        initLock = [[NSLock alloc] init];
    }
    
    if (videoStatsLock == nil) {
        videoStatsLock = [[NSLock alloc] init];
    }
    
    NSString *rawAddress = [Utils addressPortStringToAddress:config.host];
    strncpy(_hostString,
            [rawAddress cStringUsingEncoding:NSUTF8StringEncoding],
            sizeof(_hostString) - 1);
    strncpy(_appVersionString,
            [config.appVersion cStringUsingEncoding:NSUTF8StringEncoding],
            sizeof(_appVersionString) - 1);
    if (config.gfeVersion != nil) {
        strncpy(_gfeVersionString,
                [config.gfeVersion cStringUsingEncoding:NSUTF8StringEncoding],
                sizeof(_gfeVersionString) - 1);
    }
    if (config.rtspSessionUrl != nil) {
        strncpy(_rtspSessionUrl,
                [config.rtspSessionUrl cStringUsingEncoding:NSUTF8StringEncoding],
                sizeof(_rtspSessionUrl) - 1);
    }

    LiInitializeServerInformation(&_serverInfo);
    _serverInfo.address = _hostString;
    _serverInfo.serverInfoAppVersion = _appVersionString;
    if (config.gfeVersion != nil) {
        _serverInfo.serverInfoGfeVersion = _gfeVersionString;
    }
    if (config.rtspSessionUrl != nil) {
        _serverInfo.rtspSessionUrl = _rtspSessionUrl;
    }
    _serverInfo.serverCodecModeSupport = config.serverCodecModeSupport;

    renderer = myRenderer;
    _callbacks = callbacks;

    LiInitializeStreamConfiguration(&_streamConfig);
    _streamConfig.colorRange = 1; // Full range
    _streamConfig.width = config.width;
    _streamConfig.height = config.height;
    _streamConfig.fps = config.frameRate;
    _streamConfig.bitrate = config.bitRate;
    _streamConfig.supportedVideoFormats = config.supportedVideoFormats;
    _streamConfig.audioConfiguration = config.audioConfiguration;
    _streamConfig.redirectMic = config.redirectMic && [MicHandler permissionGranted];
    [Connection setVolume:config.localVolume];
    // Since we require iOS 12 or above, we're guaranteed to be running
    // on a 64-bit device with ARMv8 crypto instructions, so we don't
    // need to check for that here.
    _streamConfig.encryptionFlags = ENCFLG_ALL;
    
    if ([Utils isActiveNetworkVPN]) {
        // Force remote streaming mode when a VPN is connected
        _streamConfig.streamingRemotely = STREAM_CFG_REMOTE;
        _streamConfig.packetSize = 1024;
    }
    else {
        // Detect remote streaming automatically based on the IP address of the target
        _streamConfig.streamingRemotely = STREAM_CFG_AUTO;
        _streamConfig.packetSize = 1392;
    }

    memcpy(_streamConfig.remoteInputAesKey, [config.riKey bytes], [config.riKey length]);
    memset(_streamConfig.remoteInputAesIv, 0, 16);
    int riKeyId = htonl(config.riKeyId);
    memcpy(_streamConfig.remoteInputAesIv, &riKeyId, sizeof(riKeyId));

    LiInitializeVideoCallbacks(&_drCallbacks);
    _drCallbacks.setup = DrDecoderSetup;
    _drCallbacks.cleanup = DrCleanup;
    // Use pull renderer for legacy and off frame pacing, direct submit for queue-based frame pacing
    DataManager* dataMan = [[DataManager alloc] init];
    FramePacingMode framePacingMode = [[dataMan getSettings].framePacingMode integerValue];
    if (framePacingMode == FramePacingModeLegacy || framePacingMode == FramePacingModeOff) {
        _drCallbacks.capabilities = CAPABILITY_PULL_RENDERER |
                                    CAPABILITY_REFERENCE_FRAME_INVALIDATION_HEVC |
                                    CAPABILITY_REFERENCE_FRAME_INVALIDATION_AV1;
        _drCallbacks.submitDecodeUnit = NULL;
    } else {
        _drCallbacks.capabilities = CAPABILITY_DIRECT_SUBMIT |
                                    CAPABILITY_REFERENCE_FRAME_INVALIDATION_HEVC |
                                    CAPABILITY_REFERENCE_FRAME_INVALIDATION_AV1;
        _drCallbacks.submitDecodeUnit = DrSubmitDecodeUnit;
    }

    LiInitializeAudioCallbacks(&_arCallbacks);
    _arCallbacks.init = ArInit;
    _arCallbacks.cleanup = ArCleanup;
    _arCallbacks.decodeAndPlaySample = ArDecodeAndPlaySample;
    _arCallbacks.capabilities = CAPABILITY_SUPPORTS_ARBITRARY_AUDIO_DURATION;

    LiInitializeConnectionCallbacks(&_clCallbacks);
    _clCallbacks.stageStarting = ClStageStarting;
    _clCallbacks.stageComplete = ClStageComplete;
    _clCallbacks.stageFailed = ClStageFailed;
    _clCallbacks.connectionStarted = ClConnectionStarted;
    _clCallbacks.connectionTerminated = ClConnectionTerminated;
#ifdef DEBUG
    _clCallbacks.logMessage = ClLogMessage;
#endif
    _clCallbacks.rumble = ClRumble;
    _clCallbacks.connectionStatusUpdate = ClConnectionStatusUpdate;
    _clCallbacks.setHdrMode = ClSetHdrMode;
    _clCallbacks.rumbleTriggers = ClRumbleTriggers;
    _clCallbacks.setMotionEventState = ClSetMotionEventState;
    _clCallbacks.setControllerLED = ClSetControllerLED;

    return self;
}

-(void) main
{
    [initLock lock];
    LiStartConnection(&_serverInfo,
                      &_streamConfig,
                      &_clCallbacks,
                      &_drCallbacks,
                      &_arCallbacks,
                      NULL, 0,
                      NULL, 0);
    [initLock unlock];
}

@end
