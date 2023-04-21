//
//  NXAudioEncoding.h
//  NXLive
//
//  Created by Neuxnet on 2020/11/21.
//  Copyright © 2020 wangran. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "NXLiveAudioFrame.h"
#import "NXLiveAudioConfiguration.h"

@protocol NXAudioEncoding;
@protocol NXAudioEncodingDelegate <NSObject>
@required
- (void)audioEncoder:(nullable id<NXAudioEncoding>)encoder audioFrame:(nullable NXLiveAudioFrame *)frame;
@end

@protocol NXAudioEncoding <NSObject>
@required
- (void)encodeAudioData:(nullable NSData *)audioData timeStamp:(uint64_t)timestamp;
- (void)stopEncoder;
@optional
- (nullable instancetype)initWithAudioStreamConfiguration:(nullable NXLiveAudioConfiguration *)configuration;
- (void)setDelegate:(nullable id<NXAudioEncodingDelegate>)delegate;
- (nullable NSData *)adtsData:(NSInteger)channel rawDataLength:(NSInteger)rawDataLength;
@end
