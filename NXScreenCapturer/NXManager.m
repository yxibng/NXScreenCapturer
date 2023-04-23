//
//  NXManager.m
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/20.
//

#import "NXManager.h"
#import "TSHardwareEncoder.h"
#import "NXAudioMixer.h"
#import "NXHardwareAudioEncoder.h"
#import "NXAudioBuffer.h"


#import "flv-muxer.h"
#import "flv-writer.h"
#import "mpeg4-aac.h"

static int _flv_muxer_handler (void* param, int type, const void* data, size_t bytes, uint32_t timestamp);

@interface NXManager ()<TSHardwareEncoderDelegate, NXAudioMixerDelegate, NXAudioEncodingDelegate>
{
    @public
    void *_flvWriter;
    int64_t _startVideoTimestamp;
    uint64_t _startAudioTimestamp;
    
    int64_t _startTimestamp;
    
    BOOL _hasAvccHeaderWriten;
    flv_muxer_t *_muxer;
}

@property (nonatomic, strong) TSHardwareEncoder *videoEncoder;
@property (nonatomic, strong) NXAudioMixer *audioMixer;
@property (nonatomic, strong) NXAudioBuffer *audioBuffer;
@property (nonatomic, strong) NXHardwareAudioEncoder *audioEncoder;


@end


@implementation NXManager
+ (instancetype)sharedManager {
    
    static NXManager *manager = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        manager = [[NXManager alloc] init];
    });
    return manager;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        _videoEncoder = [[TSHardwareEncoder alloc] init];
        _videoEncoder.delegate = self;
        
        _audioMixer = [[NXAudioMixer alloc] init];
        _audioMixer.delegate = self;
        
        _audioBuffer = [[NXAudioBuffer alloc] init];
        
        
        NXLiveAudioConfiguration *audioConfig = [[NXLiveAudioConfiguration alloc] init];
        audioConfig.audioSampleRate = 48000;
        audioConfig.numberOfChannels = 1;
        audioConfig.audioBitRate = NXLiveAudioBitRate_96Kbps;
        _audioEncoder = [[NXHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:audioConfig];
        [_audioEncoder setDelegate:self];
        
        
        [self createMuxer];
        
    }
    return self;
}



- (void)handleVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(int64_t)timestamp {
    [self.videoEncoder encodePixelBuffer:pixelBuffer timestamp:timestamp];
}


#pragma mark -

- (void)handleAppAudioBuffer:(CMSampleBufferRef)appAudioBuffer {
    [self.audioMixer  handleAppBuffer:appAudioBuffer];
}

- (void)handleMicAudioBuffer:(CMSampleBufferRef)micAudioBuffer {
    [self.audioMixer handleMicBuffer:micAudioBuffer];
}

#pragma mark -

- (void)audioMixer:(NXAudioMixer *)audioMixer didGotMixedData:(uint8_t *)data length:(uint32_t)length samplerate:(uint32_t)samplerate timestamp:(uint32_t)timestamp {
    NSLog(@"%s", __func__);
    
    [self.audioBuffer enqueueData:data length:length timestamp:timestamp];
    [self dequeueAndEncodeAudio];
}

- (void)dequeueAndEncodeAudio {
    
    
    const int bufferSize = 1024 * 2;
    uint8_t buffer[bufferSize];
    memset(buffer, 0, bufferSize);
    
    uint32_t timestamp;
    
    BOOL ret;
    do {
        memset(buffer, 0, bufferSize);
        timestamp = 0;
        ret = [self.audioBuffer dequeueData:buffer length:bufferSize timestamp:&timestamp];
        if (!ret) break;
        //encode
        NSData *data = [NSData dataWithBytes:buffer length:bufferSize];
        [self.audioEncoder encodeAudioData:data timeStamp:timestamp];
        
        NSLog(@"encode audio ts = %d", timestamp);
        
    } while (ret);
}

- (void)audioEncoder:(id<NXAudioEncoding>)encoder audioFrame:(NXLiveAudioFrame *)frame {
    
    NSLog(@"%s, ts = %llu", __func__, frame.timestamp);
    
    uint8_t adtsHeader[7];
    memset(adtsHeader, 0, 7);
    
    struct mpeg4_aac_t aac = (struct mpeg4_aac_t) {
        .profile = 2,
        .sampling_frequency_index = 3,
        .channel_configuration = 1
    };
    size_t payload = frame.data.length;
    mpeg4_aac_adts_save(&aac, payload, adtsHeader, 7);
    
    
    NSMutableData *data = [NSMutableData dataWithBytes:adtsHeader length:7];
    [data appendData:frame.data];
    
    
    if (!_startTimestamp) {
        _startTimestamp = frame.timestamp;
    }
    int32_t pts = (uint32_t)frame.timestamp - _startTimestamp;
    assert(pts >= 0);
    
    NSLog(@"audio pts = %d", pts);
    
    
    flv_muxer_aac(self->_muxer, data.bytes, data.length, pts, pts);
    
    
}


#pragma mark -

- (void)encoder:(TSHardwareEncoder *)encoder gotEncoderData:(uint8_t *)data length:(int)length iskey:(BOOL)iskey timestamp:(int64_t)timestamp {
    if (!_startTimestamp) {
        _startTimestamp = timestamp;
    }
    uint32_t pts = timestamp - _startTimestamp;
    flv_muxer_avc(_muxer, data, length, pts, pts);
}


- (void)createMuxer {
    if (!_muxer) {
        _muxer = flv_muxer_create(_flv_muxer_handler, (__bridge void *)(self));
    }
}

- (void)closeFile {
    
}

@end


static int _flv_muxer_handler (void* param, int type, const void* data, size_t bytes, uint32_t timestamp) {
    
    NXManager *manager = (__bridge NXManager *)(param);
    
    if (!manager->_flvWriter) {
        
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"video.flv"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        
        NSLog(@"path = %@",path);
        manager->_flvWriter = flv_writer_create1([path cStringUsingEncoding:NSUTF8StringEncoding], 1, 1);
    }
    
    flv_writer_input(manager->_flvWriter, type, data, bytes, timestamp);
    
    return 0;
}
