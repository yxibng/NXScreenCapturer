//
//  NXManager.h
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/20.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXManager : NSObject

+ (instancetype)sharedManager;

- (void)handleVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(int64_t)timestamp;



@end

NS_ASSUME_NONNULL_END
