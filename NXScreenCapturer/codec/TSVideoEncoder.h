//
//  TSVideoEncoder.h
//  ffmpeg-demo
//
//  Created by yxibng on 2021/1/19.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN


@class TSVideoEncoder;


typedef NS_ENUM(NSUInteger, TSVideoEncodePixFormat) {
    TSVideoEncodePixFormat_NV12,
    TSVideoEncodePixFormat_YUV420P
};


@interface TSVideoEncodeConfig : NSObject

//default 15
@property (nonatomic, assign) int fps;

//defaut is captured size
@property (nonatomic, assign) CGSize dimension;


@property (nonatomic, assign) TSVideoEncodePixFormat pixFormat; 


@end


@protocol TSVideoEncoderDelegate <NSObject>

- (void)videoEncoder:(TSVideoEncoder *)videoEncoder
       didEncodeH264:(void *)h264Data
          dataLength:(int)length
          isKeyFrame:(BOOL)isKeyFrame
           timestamp:(NSTimeInterval)timestamp
             bitrate:(int)bitrate;

@end


@interface TSVideoEncoder : NSObject

@property (nonatomic, weak) id<TSVideoEncoderDelegate>delegate;


@property (strong ,nonatomic, readonly) TSVideoEncodeConfig *encodeConfig;

@property (nonatomic, assign) int bitrate;

//nv12 pixelBuffer
- (void)encodeNv12PixelBuffer:(CVPixelBufferRef)pixelBuffer
                    timestamp:(NSTimeInterval)timestamp
                forceKeyFrame:(BOOL)forceKeyFrame;

@property (nonatomic, assign, readonly) int defaultBitrate;


+ (int)bitrateWithWidth:(int)width height:(int)height fps:(int)fps;


@end

NS_ASSUME_NONNULL_END
