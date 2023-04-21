//
//  NXLiveAudioFrame.h
//  NXLive
//
//  Created by Neuxnet on 2020/11/20.
//  Copyright © 2020 wangran. All rights reserved.
//

#import "NXFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface NXLiveAudioFrame : NXFrame
/// flv打包中aac的header
@property (nonatomic, strong) NSData *audioInfo;
@end

NS_ASSUME_NONNULL_END

