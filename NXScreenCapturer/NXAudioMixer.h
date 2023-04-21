//
//  NXAudioMixer.h
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/21.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>


NS_ASSUME_NONNULL_BEGIN

@class NXAudioMixer;
@protocol NXAudioMixerDelegate <NSObject>


- (void)audioMixer:(NXAudioMixer *)audioMixer
   didGotMixedData:(uint8_t *)data
            length:(uint32_t)length
        samplerate:(uint32_t)samplerate
         timestamp:(uint32_t)timestamp;

@end



@interface NXAudioMixer : NSObject
/*
 target format 48khz int16 mono pcm
 */

@property (nonatomic, weak) id<NXAudioMixerDelegate>delegate;

- (void)handleAppBuffer:(CMSampleBufferRef)appBuffer;
- (void)handleMicBuffer:(CMSampleBufferRef)micBuffer;

@end

NS_ASSUME_NONNULL_END
