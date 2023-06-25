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


//#import "flv-muxer.h"
//#import "flv-writer.h"
//#import "mpeg4-aac.h"

#import "flvmuxer.h"
#import "aac.h"
#include <memory>




static void writeH264(uint8_t * h264, int length) {
    static FILE* m_pOutFile = NULL;
    if (!m_pOutFile) {
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"xx.h264"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        m_pOutFile = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "a+");
        NSLog(@"h264 path = %@", path);
    }
    fwrite(h264, 1, length, m_pOutFile);
}


static void writeAac(uint8_t * aac, int length) {
    static FILE* m_pOutFile = NULL;
    if (!m_pOutFile) {
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"xx.aac"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        m_pOutFile = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "a+");
        NSLog(@"aac path = %@", path);
    }
    fwrite(aac, 1, length, m_pOutFile);
}




static int _flv_muxer_handler (void* param, int type, const void* data, size_t bytes, uint32_t timestamp);

@interface NXManager ()<TSHardwareEncoderDelegate, NXAudioMixerDelegate, NXAudioEncodingDelegate>
{
    @public
    void *_flvWriter;
    int64_t _startVideoTimestamp;
    uint64_t _startAudioTimestamp;
    
    int64_t _startTimestamp;
    
    BOOL _hasAvccHeaderWriten;
    
    std::shared_ptr<nx::FlvMuxer> _flvMuxer;
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


- (void)dealloc {
    _flvMuxer.reset();
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
        audioConfig.audioSampleRate = NXLiveAudioSampleRate_48000Hz;
        audioConfig.numberOfChannels = 1;
        audioConfig.audioBitRate = NXLiveAudioBitRate_96Kbps;
        _audioEncoder = [[NXHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:audioConfig];
        [_audioEncoder setDelegate:self];
        
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"video.flv"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        
        NSLog(@"path = %@",path);
        
        _flvMuxer = std::make_shared<nx::FlvMuxer>([path cStringUsingEncoding:NSUTF8StringEncoding], true, false);
    }
    return self;
}



- (void)handleVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(int64_t)timestamp {
    [self.videoEncoder encodePixelBuffer:pixelBuffer timestamp:timestamp];
}


- (void)stop {
    
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
    } while (ret);
}

- (void)audioEncoder:(id<NXAudioEncoding>)encoder audioFrame:(NXLiveAudioFrame *)frame {
    
    NSLog(@"%s, ts = %llu", __func__, frame.timestamp);
    
    uint8_t adtsHeader[7] = {0};
    nx::adts_header header(nx::adts_header::Profile::LC, 48000, 1, (int)frame.data.length);
    header.to_buf(adtsHeader);
    NSMutableData *data = [NSMutableData dataWithBytes:adtsHeader length:7];
    [data appendData:frame.data];
    if (!_startTimestamp) {
        _startTimestamp = frame.timestamp;
    }
    int64_t pts = (int64_t)frame.timestamp - _startTimestamp;
    if (pts < 0) pts = 0;
    assert(pts >= 0);
    
    writeAac((uint8_t *)data.bytes, data.length);
    NSLog(@"audio pts = %lld", pts);
    _flvMuxer->mux_aac((uint8_t *)data.bytes, data.length, (uint32_t)pts);
}


#pragma mark -

- (void)encoder:(TSHardwareEncoder *)encoder gotEncoderData:(uint8_t *)data length:(int)length iskey:(BOOL)iskey timestamp:(int64_t)timestamp {
    if (!_startTimestamp) {
        _startTimestamp = timestamp;
    }
    
//    NSLog(@"video timestamp = %lld", timestamp);
    
    int64_t pts = timestamp - _startTimestamp;
    _flvMuxer->mux_avc(data, length, (uint32_t)pts, (uint32_t)pts, iskey);
    
    
#if 0
    writeH264(data, length);
#endif
    
}

@end

