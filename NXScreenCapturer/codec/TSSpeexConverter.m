//
//  TSSpeexConverter.m
//  BroadcastExtention
//
//  Created by xiaobing yao on 2022/12/15.
//

#import "TSSpeexConverter.h"
#include <speex/speex_resampler.h>

@interface TSSpeexConverter ()
{
    AudioStreamBasicDescription _srcFormat;
    AudioStreamBasicDescription _dstFormat;
    SpeexResamplerState *_resampler;
}
@end


@implementation TSSpeexConverter

- (void)dealloc {
    if (_resampler) {
        speex_resampler_destroy(_resampler);
        _resampler = NULL;
    }
}

- (instancetype)initWithSrcFormat:(AudioStreamBasicDescription)srcFormat dstFormat:(AudioStreamBasicDescription)dstForamt
{
    self = [super init];
    if (self) {
        _srcFormat = srcFormat;
        _dstFormat = dstForamt;
    
        int error = 0;
        _resampler = speex_resampler_init(1, _srcFormat.mSampleRate, _dstFormat.mSampleRate, 10, &error);
        if (!_resampler) return nil;;
    }
    return self;
}


- (BOOL)convertMonoPCMWithSrc:(uint8_t *)srcData
                    srcLength:(uint32_t)srcLength
             outputBufferSize:(uint32_t)outputBufferSize
                  outputBuffer:(uint8_t *)outputBuffer
                  outputLength:(uint32_t *)outputLength
{
    
    spx_int16_t *in_buffer = (spx_int16_t *)srcData;
    spx_uint32_t in_sample_count = srcLength / 2;
    
    spx_int16_t *out_buffer = (spx_int16_t *)outputBuffer;
    spx_uint32_t out_sample_count = outputBufferSize / 2;
    
    int ret = speex_resampler_process_interleaved_int(_resampler,
                                          in_buffer, &in_sample_count,
                                          out_buffer, &out_sample_count);
    if (ret && !out_sample_count) return NO;
    *outputLength = out_sample_count * 2;
    return YES;
}




@end
