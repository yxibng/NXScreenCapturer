//
//  NXLiveAudioConfiguration.m
//  NXLive
//
//  Created by Neuxnet on 2020/11/18.
//  Copyright © 2020 wangran. All rights reserved.
//

#import "NXLiveAudioConfiguration.h"
#import <sys/utsname.h>

@implementation NXLiveAudioConfiguration

+ (instancetype)defaultConfiguration {
    NXLiveAudioConfiguration *config = [NXLiveAudioConfiguration defaultConfigurationForQuality:NXLiveAudioQuality_Default];
    return config;
}

+ (instancetype)defaultConfigurationForQuality:(NXLiveAudioQuality)quality {
    NXLiveAudioConfiguration *config = [NXLiveAudioConfiguration new];
    config.numberOfChannels = 2;
    switch (quality) {
        case NXLiveAudioQuality_Low:
        {
            config.audioBitRate = config.numberOfChannels == 1 ? NXLiveAudioBitRate_32Kbps : NXLiveAudioBitRate_64Kbps;
            config.audioSampleRate = NXLiveAudioSampleRate_16000Hz;
        }
            break;
        case NXLiveAudioQuality_Medium:
        {
            config.audioBitRate = NXLiveAudioBitRate_96Kbps;
            config.audioSampleRate = NXLiveAudioSampleRate_44100Hz;

        }
            break;
        case NXLiveAudioQuality_High:
        {
            config.audioBitRate = NXLiveAudioBitRate_128Kbps;
            config.audioSampleRate = NXLiveAudioSampleRate_44100Hz;
        }
            break;
        case NXLiveAudioQuality_VeryHigh:
        {
            config.audioBitRate = NXLiveAudioBitRate_128Kbps;
            config.audioSampleRate = NXLiveAudioSampleRate_48000Hz;
        }
            break;
        default:
        {
            config.audioBitRate = NXLiveAudioBitRate_128Kbps;
            config.audioSampleRate = NXLiveAudioSampleRate_48000Hz;
            config.numberOfChannels = 1;
        }
            break;
    }
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _asc = malloc(2);
    }
    return self;
}

- (void)dealloc {
    if (_asc) {
        free(_asc);
    }
}

- (void)setAudioSampleRate:(NXLiveAudioSampleRate)audioSampleRate {
    _audioSampleRate = audioSampleRate;
    NSInteger sampleRateIndex = [self sampleRateIndex:audioSampleRate];
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x7);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((self.numberOfChannels & 0xF) << 3);
}

- (void)setNumberOfChannels:(NSUInteger)numberOfChannels {
    _numberOfChannels = numberOfChannels;
    NSInteger sampleRateIndex = [self sampleRateIndex:self.audioSampleRate];
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x7);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((numberOfChannels & 0xF) << 3);
}

- (NSUInteger)bufferLength {
    return 1024*2*self.numberOfChannels;
}

- (NSInteger)sampleRateIndex:(NSInteger)frequencyInHz {
    NSInteger sampleRateIndex = 0;
    switch (frequencyInHz) {
        case 96000:
            sampleRateIndex = 0;
            break;
        case 88200:
            sampleRateIndex = 1;
            break;
        case 64000:
            sampleRateIndex = 2;
            break;
        case 48000:
            sampleRateIndex = 3;
            break;
        case 44100:
            sampleRateIndex = 4;
            break;
        case 32000:
            sampleRateIndex = 5;
            break;
        case 24000:
            sampleRateIndex = 6;
            break;
        case 22050:
            sampleRateIndex = 7;
            break;
        case 16000:
            sampleRateIndex = 8;
            break;
        case 12000:
            sampleRateIndex = 9;
            break;
        case 11025:
            sampleRateIndex = 10;
            break;
        case 8000:
            sampleRateIndex = 11;
            break;
        case 7350:
            sampleRateIndex = 12;
            break;
        default:
            sampleRateIndex = 15;
    }
    return sampleRateIndex;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.numberOfChannels) forKey:@"numberOfChannels"];
    [coder encodeObject:@(self.audioSampleRate) forKey:@"audioSampleRate"];
    [coder encodeObject:@(self.audioBitRate) forKey:@"audioBitRate"];
    [coder encodeObject:[NSString stringWithUTF8String:self.asc] forKey:@"asc"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    _numberOfChannels = [[coder decodeObjectForKey:@"numberOfChannels"] unsignedIntegerValue];
    _audioSampleRate = [[coder decodeObjectForKey:@"audioSampleRate"] unsignedIntegerValue];
    _audioBitRate = [[coder decodeObjectForKey:@"audioBitRate"] unsignedIntegerValue];
    _asc = strdup([[coder decodeObjectForKey:@"asc"] cStringUsingEncoding:NSUTF8StringEncoding]);
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    } else if (![super isEqual:object]) {
        return NO;
    } else {
        NXLiveAudioConfiguration *config = object;
        return config.numberOfChannels == self.numberOfChannels &&
            config.audioBitRate == self.audioBitRate &&
            config.audioSampleRate == self.audioSampleRate &&
            strcmp(config.asc, self.asc);
    }
}

- (NSUInteger)hash {
    NSUInteger hash = 0;
    NSArray *values = @[@(_numberOfChannels),
                        @(_audioSampleRate),
                        @(_audioBitRate),
                        [NSString stringWithUTF8String:self.asc]];
    for (NSObject *value in values) {
        hash ^= value.hash;
    }
    return hash;
}

- (id)copyWithZone:(NSZone *)zone {
    NXLiveAudioConfiguration *config = [self.class defaultConfiguration];
    return config;
}

- (NSString *)description {
    NSMutableString *desc = @"".mutableCopy;
    [desc appendFormat:@"<NXLiveAudioConfiguration %p>", self];
    [desc appendFormat:@" numberOfChannels:%zi", self.numberOfChannels];
    [desc appendFormat:@" audioSampleRate:%zi", self.audioSampleRate];
    [desc appendFormat:@" audioBitRate:%zi", self.audioBitRate];
    [desc appendFormat:@" audioHeader:%@", [NSString stringWithUTF8String:self.asc]];
    return desc;
}

@end
