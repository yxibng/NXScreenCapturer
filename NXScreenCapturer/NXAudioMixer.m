//
//  NXAudioMixer.m
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/21.
//

#import "NXAudioMixer.h"
#import <AVFoundation/AVFoundation.h>
#import "TSSpeexConverter.h"


const int bufferSamples = 48000;
size_t dataPointerSize = bufferSamples;
int16_t dataPointer[bufferSamples];

int16_t appAudioData[bufferSamples];
int16_t micAudioData[bufferSamples];

uint64_t micAudioSize = 0;

const int bufferCapacityInByte = bufferSamples * sizeof(int16_t);



typedef NS_ENUM(NSInteger, AudioType) {
    AudioTypeApp,
    AudioTypeMic
};


static void writePCM(uint8_t * pcm, int length) {
    static FILE* m_pOutFile = NULL;
    if (!m_pOutFile) {
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"xx.pcm"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        m_pOutFile = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "a+");
        NSLog(@"pcm path = %@", path);
    }
    fwrite(pcm, 1, length, m_pOutFile);
}



@interface NXAudioMixer ()

{
    AudioStreamBasicDescription _dstDescription;
}

@property (nonatomic, strong) TSSpeexConverter *resamplerApp;
@property (nonatomic, strong) TSSpeexConverter *resamplerMic;


@end



@implementation NXAudioMixer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dstDescription = *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:48000 channels:1 interleaved:NO].streamDescription);
    }
    return self;
}


- (void)handleAppBuffer:(CMSampleBufferRef)appBuffer {
    
    [self receiveAudioSampleBuffer:appBuffer audioType:AudioTypeApp];
}


- (void)handleMicBuffer:(CMSampleBufferRef)micBuffer {
    return;
    [self receiveAudioSampleBuffer:micBuffer audioType:AudioTypeMic];
}

- (void)receiveAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer audioType:(AudioType)audioType {
    
    OSStatus err = noErr;
    
    CMBlockBufferRef audioBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    if (!audioBuffer) {
        return;
    }
    
    size_t totalBytes;
    char *samples;
    err = CMBlockBufferGetDataPointer(audioBuffer, 0, NULL, &totalBytes, &samples);
    if (!totalBytes || err != noErr) {
        return;
    }
    
    CMAudioFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription *description = CMAudioFormatDescriptionGetStreamBasicDescription(format);
    
    //多少个帧（双声道包含两个采样，一个左声道一个右声道）
    size_t totalFrames = totalBytes / description->mBytesPerFrame;
    //多少个采样（双声道 = totalFrames *2）
    size_t totalSamples = totalBytes / (description->mBitsPerChannel / 8);
    UInt32 channels = description->mChannelsPerFrame;
    
    memset(dataPointer, 0, bufferCapacityInByte);
    err = CMBlockBufferCopyDataBytes(audioBuffer,
                                     0,
                                     totalBytes,
                                     dataPointer);
    
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    float timestamp = CMTimeGetSeconds(pts) * 1000;
    
    BOOL isFloat = description->mFormatFlags & kAudioFormatFlagIsFloat;
    BOOL isBigEndian = description->mFormatFlags & kAudioFormatFlagIsBigEndian;
    BOOL isInterleaved = !(description->mFormatFlags & kAudioFormatFlagIsNonInterleaved);
    
    // big endian to little endian
    size_t bytesPerSample = description->mBitsPerChannel / 8;
    if (isBigEndian) {
        for (int i = 0; i < totalSamples; i++) {
            uint8_t* p = (uint8_t*)dataPointer + i * bytesPerSample;
            for (int j = 0; j < bytesPerSample / 2; j++) {
                uint8_t tmp;
                tmp = p[j];
                p[j] = p[bytesPerSample - j -1];
                p[bytesPerSample -j -1] = tmp;
            }
        }
    }
    
    // float to int
    if (isFloat) {
        float* floatData = (float*)dataPointer;
        int16_t* intData = (int16_t*)dataPointer;
        for (int i = 0; i < totalSamples; i++) {
            float tmp = floatData[i] * 32767;
            intData[i] = (tmp >= 32767) ?  32767 : tmp;
            intData[i] = (tmp < -32767) ? -32767 : tmp;
        }
        totalBytes = totalSamples * sizeof(int16_t);
    }

    
    
    //分离出单声道
    if (channels > 1) {
        if (isInterleaved) {
            int bytesPerFrame = (*description).mBytesPerFrame;
            for (int i = 0; i < totalFrames; i++) {
                memmove(dataPointer + i, (uint8_t *)dataPointer + i * bytesPerFrame, sizeof(int16_t));
            }
        }
    }

    //目前只是用了一个声道的数据
    size_t srcLength = totalBytes / channels;
    uint8_t *srcData = (uint8_t *)dataPointer;
    
    if (audioType == AudioTypeApp) {
        /*
         针对app采集的数据
         1. 经过float->int16, bigEndian->littleEndian, 之后分离出单声道
         2. 重采样到目标采样率，存入appAudioData， 保存重采样后的大小outputLength
         3. 重采样后的数据进行混音操作
            1）如果 outputLength > micAudioSize, 应该混音的数据大小为 micAudioSize
            2）如果 outputLength <= micAudioSize, 应该混音的数据大小为 outputLength
            3）执行混音，更新micAudioSize， 移动 micAudioData 内存
            4）将appAudioData 的数据发送出去
         */

        
        if (!_resamplerApp) {
            AudioStreamBasicDescription srcFormat = *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:description->mSampleRate channels:1 interleaved:NO].streamDescription);
            _resamplerApp = [[TSSpeexConverter alloc] initWithSrcFormat: srcFormat dstFormat:_dstDescription];
        }
        
        uint32_t capacity = bufferCapacityInByte;
        uint8_t *dstData = (uint8_t *)appAudioData;
        uint32_t outputLength = 0;
        
        BOOL ret = [self.resamplerApp convertMonoPCMWithSrc:srcData
                                                    srcLength:(uint32_t)srcLength
                                             outputBufferSize:capacity
                                                 outputBuffer:dstData
                                                 outputLength:&outputLength];
        
        assert(ret);
        if (!ret) {
            return;
        }
        
        int32_t mixSize = outputLength > micAudioSize ? (int32_t)micAudioSize : outputLength;
        int32_t mixCount = mixSize / sizeof(int16_t);
        
        for (int i = 0; i< mixCount; i++) {
            appAudioData[i]  = (appAudioData[i] + micAudioData[i]) / 2;
        }
        
        if (mixCount > 0) {
            memmove(micAudioData, (uint8_t *)micAudioData + mixSize, micAudioSize - mixSize);
            micAudioSize -= mixSize;
        }
        
        if ([self.delegate respondsToSelector:@selector(audioMixer:didGotMixedData:length:samplerate:timestamp:)]) {
            [self.delegate audioMixer:self didGotMixedData:(uint8_t *)appAudioData length:outputLength samplerate:_dstDescription.mSampleRate timestamp:timestamp];
        }
#if 0
        writePCM((uint8_t *)appAudioData, outputLength);
#endif
    } else {
        /*
         针对麦克风数据
         1. 经过float->int16, bigEndian->littleEndian, 之后分离出单声道
         2. 重采样到目标采样率，存入micAudioBuffer， 更新 micAudioSize
         */
        if (!_resamplerMic) {
            AudioStreamBasicDescription srcFormat = *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:description->mSampleRate channels:1 interleaved:NO].streamDescription);
            _resamplerMic = [[TSSpeexConverter alloc] initWithSrcFormat: srcFormat dstFormat:_dstDescription];
        }

        uint8_t tempBuffer[bufferCapacityInByte] = {0};
        uint32_t capacity = bufferCapacityInByte;
        uint8_t *dstData = tempBuffer;
        uint32_t outputLength = 0;
        BOOL ret = [self.resamplerMic convertMonoPCMWithSrc:srcData
                                                  srcLength:(uint32_t)srcLength
                                           outputBufferSize:capacity
                                               outputBuffer:dstData
                                               outputLength:&outputLength];
        assert(ret);
        if (!ret) {
            return;
        }
        memcpy((uint8_t *)micAudioData + micAudioSize, dstData, outputLength);
        micAudioSize += outputLength;
    }
}





@end
