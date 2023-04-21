//
//  TSSpeexConverter.h
//  BroadcastExtention
//
//  Created by xiaobing yao on 2022/12/15.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSSpeexConverter : NSObject
- (instancetype)initWithSrcFormat:(AudioStreamBasicDescription)srcFormat
                         dstFormat:(AudioStreamBasicDescription)dstForamt;


/*
 1. 只支持单声道转换
 2. 需要调用方申请outputBuffer
 3. 需要调用方告知buffer的大小outputBufferSize
 
 调用成功返回YES
 outputLength 保存转换后的数据大小
 */
- (BOOL)convertMonoPCMWithSrc:(uint8_t *)srcData
                    srcLength:(uint32_t)srcLength
             outputBufferSize:(uint32_t)outputBufferSize
                  outputBuffer:(uint8_t *)outputBuffer
                 outputLength:(uint32_t *)outputLength;
@end

NS_ASSUME_NONNULL_END
