//
//  NXManager.m
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/20.
//

#import "NXManager.h"
#import "TSHardwareEncoder.h"
#import "flv-muxer.h"

static int _flv_muxer_handler (void* param, int type, const void* data, size_t bytes, uint32_t timestamp);



@interface NXManager ()<TSHardwareEncoderDelegate>
{
    @public
    
    FILE *_flvFile;
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
    
    if (!manager->_flvFile) {
        
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"video.flv"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        manager->_flvFile = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
    }
    fwrite(data, 1, bytes, manager->_flvFile);
    
    return 0;
}

