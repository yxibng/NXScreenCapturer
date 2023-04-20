//
//  TSHardwareEncoder.h
//  ToseeBroadcastExtention
//
//  Created by xiaobing yao on 2022/11/23.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN
@class TSHardwareEncoder;

@protocol TSHardwareEncoderDelegate <NSObject>

- (void)encoder:(TSHardwareEncoder *)encoder gotEncoderData:(uint8_t *)data length:(int)length iskey:(BOOL)iskey timestamp:(int64_t)timestamp;

@end

@interface TSHardwareEncoder : NSObject

@property (nonatomic, weak) id<TSHardwareEncoderDelegate>delegate;

- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(int64_t)timestamp;

@end

NS_ASSUME_NONNULL_END
