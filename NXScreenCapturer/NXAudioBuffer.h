//
//  NXAudioBuffer.h
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXAudioBuffer : NSObject

- (void)enqueueData:(uint8_t *)data length:(uint32_t)length timestamp:(uint32_t)timestamp;

- (BOOL)dequeueData:(uint8_t *)data length:(uint32_t)length timestamp:(uint32_t *)timestamp;

@end

NS_ASSUME_NONNULL_END
