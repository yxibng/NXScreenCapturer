//
//  NXManager.m
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/20.
//

#import "NXManager.h"
#import "TSHardwareEncoder.h"
#import "flv-muxer.h"
#import "flv-writer.h"

static int _flv_muxer_handler (void* param, int type, const void* data, size_t bytes, uint32_t timestamp);
static int _flv_writer_onwrite(void* param, const struct flv_vec_t* vec, int n);



@interface NXManager ()<TSHardwareEncoderDelegate>
{
    @public
    void *_flvWriter;
    int64_t _startVideoTimestamp;
    BOOL _hasAvccHeaderWriten;
    flv_muxer_t *_muxer;
}

@property (nonatomic, strong) TSHardwareEncoder *videoEncoder;

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
    }
    return self;
}



- (void)handleVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(int64_t)timestamp {
    [self.videoEncoder encodePixelBuffer:pixelBuffer timestamp:timestamp];
}


- (void)encoder:(TSHardwareEncoder *)encoder gotEncoderData:(uint8_t *)data length:(int)length iskey:(BOOL)iskey timestamp:(int64_t)timestamp {
    
    [self createMuxer];
    
    if (!_startVideoTimestamp) {
        _startVideoTimestamp = timestamp;
    }
    
    uint32_t pts = timestamp - _startVideoTimestamp;
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
        manager->_flvWriter = flv_writer_create1([path cStringUsingEncoding:NSUTF8StringEncoding], 0, 1);
    }
    
    flv_writer_input(manager->_flvWriter, 9, data, bytes, timestamp);
    
    return 0;
}

static int _flv_writer_onwrite(void* param, const struct flv_vec_t* vec, int n) {
    
    return 0;
}
