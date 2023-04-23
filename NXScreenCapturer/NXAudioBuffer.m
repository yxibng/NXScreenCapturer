//
//  NXAudioBuffer.m
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/21.
//

#import "NXAudioBuffer.h"
#import "TPCircularBuffer.h"

static float kSampleRate = 48000.0;


@interface NXAudioBuffer()
{
    TPCircularBuffer _buffer;
    
    uint32_t _timestamp;
    
    
}
@end


@implementation NXAudioBuffer

- (instancetype)init {
    if (self = [super init]) {
        TPCircularBufferInit(&_buffer, 40960);
    }
    return self;
}



- (void)enqueueData:(uint8_t *)data length:(uint32_t)length timestamp:(uint32_t)timestamp {
    
    bool ret = TPCircularBufferProduceBytes(&_buffer, data, length);
    
    NSLog(@"write length = %d, ret = %d", length, ret);

    
    if (!ret) {
        
        uint32_t availableBytes;
        TPCircularBufferHead(&_buffer, &availableBytes);
        NSLog(@"write availableBytes = %d, length = %d", availableBytes, length);
    }
    
    assert(ret);
    if (!_timestamp) {
        _timestamp = timestamp;
    } else {
        
        uint32_t availableBytes = 0;
        TPCircularBufferTail(&_buffer, &availableBytes);
        availableBytes -= length;
        int diff = availableBytes / 2.0 / kSampleRate * 1000.0;
        if (abs((int)_timestamp + diff - (int)timestamp) > 5) {
            //TODO: fix timestamp
            _timestamp = timestamp - diff;
            NSLog(@"fix timestamp, diff = %d", diff);
        }
    }
}

- (BOOL)dequeueData:(uint8_t *)data length:(uint32_t)length timestamp:(uint32_t *)timestamp {
    uint32_t availableBytes = 0;
    void *p = TPCircularBufferTail(&_buffer, &availableBytes);
    
    NSLog(@"read, availableBytes = %d, length = %d", availableBytes, length);
    if (length > availableBytes) {
        return NO;
    }
    
    
    //read
    memcpy(data, p, length);
    //consume
    TPCircularBufferConsume(&_buffer, length);
    {
        uint32_t sampleCount = length / 2;
        if (timestamp) {
            *timestamp = _timestamp;
        }
        uint32_t ts = sampleCount / kSampleRate * 1000;
        NSLog(@"ts ==== %d", ts);
        _timestamp += ts;
    }
    return YES;
}
@end
