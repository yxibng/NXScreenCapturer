//
//  TSVideoEncoder.m
//  ffmpeg-demo
//
//  Created by yxibng on 2021/1/19.
//

#import "TSVideoEncoder.h"
#import "TSBitrateHelper.hpp"
#import <OSLog/OSLog.h>

extern "C" {
    
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>

}



@implementation TSVideoEncodeConfig

- (instancetype)init
{
    self = [super init];
    if (self) {
        //默认编码15帧
        _fps = 15;
    }
    return self;
}

@end


@interface TSVideoEncoder()
{
    AVCodec *_codec;
    AVCodecContext *_context;
    AVFrame *_frame;
    AVPacket *_pkt;
    NSUInteger _pts;
}


@property (nonatomic, assign) BOOL setupSuccess;
@property (nonatomic) dispatch_queue_t encode_queue;

@end

@implementation TSVideoEncoder

- (void)dealloc
{
    [self destory];
}


- (instancetype)init{
    if (self = [super init]) {
        _encodeConfig = [TSVideoEncodeConfig new];
        _encode_queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)encodeNv12PixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(NSTimeInterval)timestamp forceKeyFrame:(BOOL)forceKeyFrame {

    if (!pixelBuffer) {
        return;
    }
    
    CVPixelBufferRetain(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    
    BOOL fullRange = NO;
    OSType pixelFormatType =  CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        fullRange = YES;
    }
    
    uint8_t *y = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint8_t *uv = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    int stride_y = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    int stride_uv = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    
    dispatch_async(self.encode_queue, ^{
        [self encode_y:y
                    uv:uv
              stride_y:stride_y
             stride_uv:stride_uv
                 width:width
                height:height
             timestamp:timestamp
         forceKeyFrame:forceKeyFrame
             fullRange:fullRange
        ];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
    });
    
}


- (void)encode_y:(uint8_t *)y
              uv:(uint8_t *)uv
        stride_y:(int)stride_y
       stride_uv:(int)stride_uv
           width:(int)width
          height:(int)height
       timestamp:(NSTimeInterval)timestamp
    forceKeyFrame:(BOOL)forceKeyFrame
    fullRange:(BOOL)fullRange

{
    TSVideoEncodeConfig *config = [TSVideoEncodeConfig new];
    config.dimension = CGSizeMake(width, height);
    config.pixFormat = TSVideoEncodePixFormat_NV12;
    if (!self.setupSuccess) {
        [self setupWithConfig:config];
    } else {
        BOOL shouldReset = !CGSizeEqualToSize(self.encodeConfig.dimension, CGSizeMake(width, height));
        if (shouldReset) {
            //分辨率改变，重新计算码率
            _bitrate = 0;
            [self destory];
            [self setupWithConfig:config];
        }
    }
    if (!self.setupSuccess) {
        return;
    }
    
    _encodeConfig.dimension = CGSizeMake(width, height);
    
    _frame->width = width;
    _frame->height = height;
    _frame->format = AV_PIX_FMT_NV12;
    if (fullRange) {
        _frame->color_range = AVCOL_RANGE_JPEG;
    } else {
        _frame->color_range = AVCOL_RANGE_MPEG;
    }
    _frame->data[0] = (uint8_t *)y;
    _frame->data[1] = (uint8_t *)uv;
    _frame->linesize[0] = stride_y;
    _frame->linesize[1] = stride_uv;
    if (forceKeyFrame) {
        _frame->pict_type = AV_PICTURE_TYPE_I;
    } else {
        _frame->pict_type = AV_PICTURE_TYPE_NONE;
    }
    _frame->pts = _pts++;
    
    int ret = avcodec_send_frame(_context, _frame);
    if (ret < 0) {
        os_log_error(OS_LOG_DEFAULT, "avcodec_send_frame failed %d", ret);
        return;
    }
    
    while (ret >= 0) {
        ret = avcodec_receive_packet(_context, _pkt);
        if (ret == AVERROR((EAGAIN)) || ret == AVERROR_EOF) {
            return;
        }
        
        if (ret < 0) {
            os_log_error(OS_LOG_DEFAULT, "avcodec_receive_packet failed %d", ret);
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(videoEncoder:didEncodeH264:dataLength:isKeyFrame:timestamp:bitrate:)]) {
            
            BOOL iskey = _pkt->flags & AV_PKT_FLAG_KEY;
            
            [self.delegate videoEncoder:self
                          didEncodeH264:_pkt->data
                             dataLength:_pkt->size
                             isKeyFrame:iskey
                              timestamp:timestamp
                                bitrate:self.bitrate
            ];
        }
        
        av_packet_unref(_pkt);
    }
}



- (void)_encode_y:(uint8_t *)y
              u:(uint8_t *)u
              v:(uint8_t *)v
        stride_y:(int)stride_y
       stride_u:(int)stride_u
       stride_v:(int)stride_v
           width:(int)width
          height:(int)height
       timestamp:(NSTimeInterval)timestamp
   forceKeyFrame:(BOOL)forceKeyFrame
{
    TSVideoEncodeConfig *config = [TSVideoEncodeConfig new];
    config.dimension = CGSizeMake(width, height);
    config.pixFormat = TSVideoEncodePixFormat_YUV420P;
    if (!self.setupSuccess) {
        [self setupWithConfig:config];
    } else {
        BOOL shouldReset = !CGSizeEqualToSize(self.encodeConfig.dimension, CGSizeMake(width, height));
        if (shouldReset) {
            //分辨率改变，重新计算码率
            _bitrate = 0;
            [self destory];
            [self setupWithConfig:config];
        }
    }
    if (!self.setupSuccess) {
        return;
    }
    
    _encodeConfig.dimension = CGSizeMake(width, height);
    
    _frame->width = width;
    _frame->height = height;
    _frame->format = AV_PIX_FMT_YUV420P;
    _frame->data[0] = y;
    _frame->data[1] = u;
    _frame->data[2] = v;

    _frame->linesize[0] = stride_y;
    _frame->linesize[1] = stride_u;
    _frame->linesize[2] = stride_v;
    if (forceKeyFrame) {
        _frame->pict_type = AV_PICTURE_TYPE_I;
    } else {
        _frame->pict_type = AV_PICTURE_TYPE_NONE;
    }
    _frame->pts = _pts++;
    
    int ret = avcodec_send_frame(_context, _frame);
    if (ret < 0) {
        os_log_error(OS_LOG_DEFAULT, "avcodec_send_frame failed %d", ret);
        return;
    }
    
    while (ret >= 0) {
        ret = avcodec_receive_packet(_context, _pkt);
        if (ret == AVERROR((EAGAIN)) || ret == AVERROR_EOF) {
            return;
        }
        
        if (ret < 0) {
            os_log_error(OS_LOG_DEFAULT, "avcodec_receive_packet failed %d", ret);
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(videoEncoder:didEncodeH264:dataLength:isKeyFrame:timestamp:bitrate:)]) {
            
            BOOL iskey = _pkt->flags & AV_PKT_FLAG_KEY;
            
            [self.delegate videoEncoder:self
                          didEncodeH264:_pkt->data
                             dataLength:_pkt->size
                             isKeyFrame:iskey
                              timestamp:timestamp
                                bitrate:self.bitrate
            ];
        }
        av_packet_unref(_pkt);
    }
}


- (BOOL)setupWithConfig:(TSVideoEncodeConfig *)config  {
    
    [self destory];
    
    _codec = avcodec_find_encoder_by_name("h264_videotoolbox");
    if (!_codec) {
        os_log_error(OS_LOG_DEFAULT, "avcodec_find_encoder: AV_CODEC_ID_H264 failed");
        return NO;
    }
    
    _context = avcodec_alloc_context3(_codec);
    if (!_context) {
        os_log_error(OS_LOG_DEFAULT, "avcodec_alloc_context3 failed");
        return NO;
    }
    
    _context->codec_type = AVMEDIA_TYPE_VIDEO;
    
    if (config.pixFormat == TSVideoEncodePixFormat_NV12) {
        _context->pix_fmt = AV_PIX_FMT_NV12;
    } else if(config.pixFormat == TSVideoEncodePixFormat_YUV420P) {
        _context->pix_fmt = AV_PIX_FMT_YUV420P;
    } else {
        NSAssert(NO, @"NOT SUPPORT PIX FORMAT");
    }

    if (_bitrate == 0) {
        _bitrate = ts264::getBaseBitrate(config.dimension.width, config.dimension.height, config.fps);
    }
    _context->bit_rate = _bitrate;
    _context->width = config.dimension.width;
    _context->height = config.dimension.height;
    
    _context->time_base = (AVRational){1, config.fps};
    _context->framerate = (AVRational){config.fps, 1};
    //gop 2 秒
    _context->gop_size = 2 * config.fps;
    _context->max_b_frames = 0;
    
    av_opt_set(_context->priv_data, "coder", "cabac", 0);
    /*
     H.264有四种画质级别,分别是baseline, extended, main, high：
     　　1、Baseline Profile：基本画质。支持I/P 帧，只支持无交错（Progressive）和CAVLC；
     　　2、Extended profile：进阶画质。支持I/P/B/SP/SI 帧，只支持无交错（Progressive）和CAVLC；(用的少)
     　　3、Main profile：主流画质。提供I/P/B 帧，支持无交错（Progressive）和交错（Interlaced），
     　　　 也支持CAVLC 和CABAC 的支持；
     　　4、High profile：高级画质。在main Profile 的基础上增加了8x8内部预测、自定义量化、 无损视频编码和更多的YUV 格式；
     H.264 Baseline profile、Extended profile和Main profile都是针对8位样本数据、4:2:0格式(YUV)的视频序列。在相同配置情况下，High profile（HP）可以比Main profile（MP）降低10%的码率。
     */
    av_opt_set(_context->priv_data, "profile", "high", 0);

    /*
     open it
     */
    avcodec_open2(_context, _codec, NULL);
    
    _pkt = av_packet_alloc();
    if (!_pkt) {
        os_log_error(OS_LOG_DEFAULT, "av_packet_alloc failed");
        return NO;
    }
        
    _frame = av_frame_alloc();
    if (!_frame) {
        os_log_error(OS_LOG_DEFAULT, "av_frame_alloc failed");
        return NO;
    }
    _pts = 1;
    _setupSuccess = YES;
    return YES;
}


- (void)destory {
    if (_context) {
        avcodec_close(_context);
        avcodec_free_context(&_context);
    }
    if (_frame) {
        av_frame_free(&_frame);
    }
    if (_pkt) {
        av_packet_free(&_pkt);
    }
    _setupSuccess = NO;
}

- (void)setBitrate:(int)bitrate {
    if (_bitrate == bitrate) {
        return;
    }
    //更新码率
    _bitrate = bitrate;
    dispatch_async(self.encode_queue, ^{    
        [self destory];
    });
}

- (int)defaultBitrate {
    
    __block int bitrate = 0;
    dispatch_sync(self.encode_queue, ^{
        TSVideoEncodeConfig *config = self.encodeConfig;
        bitrate = ts264::getBaseBitrate(config.dimension.width, config.dimension.height, config.fps);
    });
    return bitrate;
}

+ (int)bitrateWithWidth:(int)width height:(int)height fps:(int)fps {
    return ts264::getBaseBitrate(width, height, fps);;
}

@end
