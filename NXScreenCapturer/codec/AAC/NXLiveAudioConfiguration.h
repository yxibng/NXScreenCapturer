//
//  NXLiveAudioConfiguration.h
//  NXLive
//
//  Created by Neuxnet on 2020/11/18.
//  Copyright © 2020 wangran. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, NXLiveAudioBitRate)
{
    /// 32Kbps 音频码率
    NXLiveAudioBitRate_32Kbps = 32000,
    /// 64Kbps 音频码率
    NXLiveAudioBitRate_64Kbps = 64000,
    /// 96Kbps 音频码率
    NXLiveAudioBitRate_96Kbps = 96000,
    /// 128Kbps 音频码率
    NXLiveAudioBitRate_128Kbps = 128000,
    /// 默认音频码率，96Kbps
    NXLiveAudioBitRate_Default = NXLiveAudioBitRate_96Kbps
};

typedef NS_ENUM(NSUInteger, NXLiveAudioSampleRate)
{
    /// 16KHz 采样率
    NXLiveAudioSampleRate_16000Hz = 16000,
    /// 44.1KHz 采样率
    NXLiveAudioSampleRate_44100Hz = 44100,
    /// 48KHz 采样率
    NXLiveAudioSampleRate_48000Hz = 48000,
    /// 默认采样率，44.1KHz
    NXLiveAudioSampleRate_Default = NXLiveAudioSampleRate_44100Hz
};

typedef NS_ENUM(NSInteger, NXLiveAudioQuality)
{
    /// 低音频质量 audio sample rate: 16KHz audio bitrate: numberOfChannels 1:32Kbps  2:64Kbps
    NXLiveAudioQuality_Low = 0,
    /// 中音频质量 audio sample rate: 44.1KHz audio bitrate: 96Kbps
    NXLiveAudioQuality_Medium = 1,
    /// 高音频质量 audio sample rate: 44.1KHz audio bitrate: 128Kbps
    NXLiveAudioQuality_High = 2,
    /// 超高音频质量 audio sample rate: 48KHz, audio bitrate: 128Kbps
    NXLiveAudioQuality_VeryHigh = 3,
    /// 默认音频质量
    NXLiveAudioQuality_Default = 99
};

NS_ASSUME_NONNULL_BEGIN

@interface NXLiveAudioConfiguration : NSObject<NSCoding, NSCopying>

/// 默认音频配置
+ (instancetype)defaultConfiguration;
/// 音频配置
+ (instancetype)defaultConfigurationForQuality:(NXLiveAudioQuality)quality;
/// 声道数
@property (nonatomic, assign) NSUInteger numberOfChannels;
/// 采样率
@property (nonatomic, assign) NXLiveAudioSampleRate audioSampleRate;
/// 码率
@property (nonatomic, assign) NXLiveAudioBitRate audioBitRate;
/// flv编码音频头 44100 为0x12 0x10
@property (nonatomic, assign, readonly) char *asc;
/// 缓存区长度
@property (nonatomic, assign, readonly) NSUInteger bufferLength;

@end

NS_ASSUME_NONNULL_END
