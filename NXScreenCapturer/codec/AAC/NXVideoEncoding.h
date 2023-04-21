//
//  NeuVideoEncoding.h
//  NXLive
//
//  Created by Neuxnet on 2020/11/21.
//  Copyright © 2020 wangran. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NXLiveVideoFrame.h"
#import "NXLiveVideoConfiguration.h"

@protocol NeuVideoEncoding;
@protocol NeuVideoEncodingDelegate <NSObject>
@required
- (void)videoEncoder:(nullable id<NeuVideoEncoding>)encoder videoFrame:(nullable NXLiveVideoFrame *)frame;
@end

@protocol NeuVideoEncoding <NSObject>
@required
- (void)encodeVideoData:(nullable CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timestamp;
@optional
@property (nonatomic, assign) NSInteger videoBitRate;
- (nullable instancetype)initWithVideoStreamConfiguration:(nullable NXLiveVideoConfiguration *)configuration;
- (void)setDelegate:(nullable id<NeuVideoEncodingDelegate>)delegate;
- (void)stopEncoder;
- (void)fillVideoFrame;
- (void)willEnterBackground;
- (void)willEnterForeground;
- (void)setSEI:(NSDictionary *_Nonnull)seiInfo;
@end
