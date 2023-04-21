//
//  NXHardwareAudioEncoder.h
//  NXLive
//
//  Created by Neuxnet on 2020/11/21.
//  Copyright © 2020 wangran. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NXAudioEncoding.h"

NS_ASSUME_NONNULL_BEGIN

@interface NXHardwareAudioEncoder : NSObject<NXAudioEncoding>
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;
@end

NS_ASSUME_NONNULL_END
