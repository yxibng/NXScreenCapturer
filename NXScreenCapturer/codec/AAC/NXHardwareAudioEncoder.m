//
//  NXHardwareAudioEncoder.m
//  NXLive
//
//  Created by Neuxnet on 2020/11/21.
//  Copyright © 2020 wangran. All rights reserved.
//

#import "NXHardwareAudioEncoder.h"

@interface NXHardwareAudioEncoder()
{
    AudioConverterRef m_converter;
    char *leftBuf;
    char *aacBuf;
    NSInteger leftLength;
}
@property (nonatomic, strong) NXLiveAudioConfiguration *configuration;
@property (nonatomic, weak) id<NXAudioEncodingDelegate> aacDelegate;
@end

@implementation NXHardwareAudioEncoder

- (instancetype)initWithAudioStreamConfiguration:(NXLiveAudioConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;

        if (!leftBuf) {
            leftBuf = malloc(_configuration.bufferLength);
        }

        if (!aacBuf) {
            aacBuf = malloc(_configuration.bufferLength);
        }
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s %@", __FUNCTION__, self);
    if (aacBuf) free(aacBuf);
    if (leftBuf) free(leftBuf);
}

#pragma mark -- LFAudioEncoder
- (void)setDelegate:(id<NXAudioEncodingDelegate>)delegate {
    _aacDelegate = delegate;
}

- (void)encodeAudioData:(nullable NSData*)audioData timeStamp:(uint64_t)timeStamp {
    if (![self createAudioConvert]) {
        return;
    }

    if(leftLength + audioData.length >= self.configuration.bufferLength){
        ///<  发送
        NSInteger totalSize = leftLength + audioData.length;
        NSInteger encodeCount = totalSize/self.configuration.bufferLength;
        char *totalBuf = malloc(totalSize);
        char *p = totalBuf;

        memset(totalBuf, 0, (int)totalSize);
        memcpy(totalBuf, leftBuf, leftLength);
        memcpy(totalBuf + leftLength, audioData.bytes, audioData.length);

        for(NSInteger index = 0;index < encodeCount;index++){
            [self encodeBuffer:p timeStamp:timeStamp];
            p += self.configuration.bufferLength;
        }

        leftLength = totalSize%self.configuration.bufferLength;
        memset(leftBuf, 0, self.configuration.bufferLength);
        memcpy(leftBuf, totalBuf + (totalSize -leftLength), leftLength);

        free(totalBuf);

    }else{
        ///< 积累
        memcpy(leftBuf+leftLength, audioData.bytes, audioData.length);
        leftLength = leftLength + audioData.length;
    }
}

- (void)encodeBuffer:(char*)buf timeStamp:(uint64_t)timeStamp{

    AudioBuffer inBuffer;
    inBuffer.mNumberChannels = 1;
    inBuffer.mData = buf;
    inBuffer.mDataByteSize = (UInt32)self.configuration.bufferLength;

    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = inBuffer;


    // 初始化一个输出缓冲列表
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers = 1;
    outBufferList.mBuffers[0].mNumberChannels = inBuffer.mNumberChannels;
    outBufferList.mBuffers[0].mDataByteSize = inBuffer.mDataByteSize;   // 设置缓冲区大小
    outBufferList.mBuffers[0].mData = aacBuf;           // 设置AAC缓冲区
    UInt32 outputDataPacketSize = 1;

    OSStatus status = AudioConverterFillComplexBuffer(m_converter,
                                                      inputDataProc,
                                                      &buffers,
                                                      &outputDataPacketSize,
                                                      &outBufferList,
                                                      NULL);
    if (status != noErr) {
        return;
    }

    NXLiveAudioFrame *audioFrame = [NXLiveAudioFrame new];
    audioFrame.timestamp = timeStamp;
    audioFrame.data = [NSData dataWithBytes:aacBuf length:outBufferList.mBuffers[0].mDataByteSize];

    char exeData[2];
    exeData[0] = _configuration.asc[0];
    exeData[1] = _configuration.asc[1];
    audioFrame.audioInfo = [NSData dataWithBytes:exeData length:2];
    if (self.aacDelegate && [self.aacDelegate respondsToSelector:@selector(audioEncoder:audioFrame:)]) {
        [self.aacDelegate audioEncoder:self audioFrame:audioFrame];
    }

}

- (void)stopEncoder {

}

#pragma mark -- CustomMethod
- (BOOL)createAudioConvert { //根据输入样本初始化一个编码转换器
    if (m_converter != nil) {
        return TRUE;
    }

    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mSampleRate = _configuration.audioSampleRate;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    inputFormat.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mBytesPerFrame = inputFormat.mBitsPerChannel / 8 * inputFormat.mChannelsPerFrame;
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;

    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = inputFormat.mSampleRate;       // 采样率保持一致
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;            // AAC编码 kAudioFormatMPEG4AAC kAudioFormatMPEG4AAC_HE_V2
    outputFormat.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;
    outputFormat.mFramesPerPacket = 1024;                     // AAC一帧是1024个字节

    const OSType subtype = kAudioFormatMPEG4AAC;
    AudioClassDescription requestedCodecs[2] = {
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };

    OSStatus result = AudioConverterNewSpecific(&inputFormat, &outputFormat, 2, requestedCodecs, &m_converter);;
    UInt32 outputBitrate = (UInt32)_configuration.audioBitRate;
    UInt32 propSize = sizeof(outputBitrate);


    if(result == noErr) {
        result = AudioConverterSetProperty(m_converter, kAudioConverterEncodeBitRate, propSize, &outputBitrate);
    } else {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                             code:result
                                         userInfo:nil];
    }

    return YES;
}


#pragma mark -- AudioCallBack
OSStatus inputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription * *outDataPacketDescription, void *inUserData) {
    //AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据</span>
    AudioBufferList bufferList = *(AudioBufferList *)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = bufferList.mBuffers[0].mDataByteSize;
    return noErr;
}

@end
