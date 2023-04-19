//
//  TSHardwareEncoder.m
//  ToseeBroadcastExtention
//
//  Created by xiaobing yao on 2022/11/23.
//

#import "TSHardwareEncoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import "TSBitrateHelper.hpp"

void writeH264(uint8_t * h264, int length) {
    static FILE* m_pOutFile = NULL;
    if (!m_pOutFile) {

        NSURL *groudURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.tech.tosee.mobile"];
        NSString *path = [[groudURL path] stringByAppendingPathComponent:@"xx.h264"];
        m_pOutFile = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "a+");
        NSLog(@"path = %@", path);
    }
    fwrite(h264, 1, length, m_pOutFile);
}

#pragma mark -

static const uint8_t start_code[] = { 0, 0, 0, 1 };

static int copyParams(CMSampleBufferRef buffer, uint8_t *dst) {
    
    CMVideoFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(buffer);
    if (!fmt) {
        return 1;
    }
    
    
    size_t ps_count;
    int is_count_bad = 0;
    int status;
    status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt,
                                                                0,
                                                                NULL,
                                                                NULL,
                                                                &ps_count,
                                                                NULL);
    
    if (status) {
        is_count_bad = 1;
        ps_count = 0;
        status = 0;
    }
    
    for (int i = 0; i< ps_count || is_count_bad; i++) {
        const uint8_t *ps;
        size_t ps_size;
        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt,
                                                                    i,
                                                                    &ps,
                                                                    &ps_size,
                                                                    NULL,
                                                                    NULL);
        if (status) {
            if (i > 0 && is_count_bad) {
                status = 0;
                break;
            }
        }
        memcpy(dst, start_code, sizeof(start_code));
        dst += sizeof(start_code);
        memcpy(dst, ps, ps_size);
        dst += ps_size;
    }
    return 0;
}


static int copy_nalus(int startCodeSize, CMSampleBufferRef buffer, uint8_t *dst) {
    
    if (startCodeSize > 4) return -1;
    
    size_t offset = 0;
    int status;
    uint8_t size_buf[4];
    size_t src_size = CMSampleBufferGetTotalSampleSize(buffer);
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(buffer);
    while (offset < src_size) {
        size_t curr_src_len;
        size_t box_len = 0;
        //get length
        status = CMBlockBufferCopyDataBytes(block, offset, startCodeSize, size_buf);
        for (int i = 0; i< startCodeSize; i++) {
            box_len <<= 8;
            box_len |= size_buf[i];
        }
        //write start code
        memcpy(dst, start_code, sizeof(start_code));
        dst += sizeof(start_code);
        //write nalu
        CMBlockBufferCopyDataBytes(block, offset + startCodeSize, box_len, dst);
        dst += box_len - startCodeSize;
        curr_src_len = box_len + startCodeSize;
        offset += curr_src_len;
    }
    return 0;
}


static int getParamsLength(CMSampleBufferRef buffer, int *size) {
    
    CMVideoFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(buffer);
    if (!fmt) {
        return 1;
    }
    
    size_t total_size = 0;
    size_t ps_count;
    int is_count_bad = 0;
    int status;
    
    status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt,
                                                                0,
                                                                NULL,
                                                                NULL,
                                                                &ps_count,
                                                                NULL);
    
    if (status) {
        is_count_bad = 1;
        ps_count = 0;
        status = 0;
    }
    
    for (int i = 0; i< ps_count || is_count_bad; i++) {
        
        const uint8_t *ps;
        size_t ps_size;
        
        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt,
                                                                    i,
                                                                    &ps,
                                                                    &ps_size,
                                                                    NULL,
                                                                    NULL);
        if (status) {
            if (i > 0 && is_count_bad) {
                status = 0;
                break;
            }
        }
        
        total_size += ps_size + sizeof(start_code);
    }
    
    *size = (int)total_size;
    return 0;
}


static int count_nalus(int startCodeSize,
                       CMSampleBufferRef buffer,
                       int *count){
    
    if (startCodeSize > 4) return -1;
    
    size_t offset = 0;
    int status;
    int nalu_ct = 0;
    uint8_t size_buf[4];
    size_t src_size = CMSampleBufferGetTotalSampleSize(buffer);
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(buffer);
    while (offset < src_size) {
        size_t curr_src_len;
        size_t box_len = 0;
        status = CMBlockBufferCopyDataBytes(block, offset, startCodeSize, size_buf);
        
        for (int i = 0; i< startCodeSize; i++) {
            box_len <<= 8;
            box_len |= size_buf[i];
        }
        
        curr_src_len = box_len + startCodeSize;
        offset += curr_src_len;
        nalu_ct++;
        
    }
    *count = nalu_ct;
    return 0;
}



static bool isKeyFrame(CMSampleBufferRef buffer) {
    
    CFArrayRef      attachments;
    CFDictionaryRef attachment;
    CFBooleanRef    not_sync;
    CFIndex         len;
    attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, false);
    len = !attachments ? 0 : CFArrayGetCount(attachments);

    if (!len) {
        return true;
    }
    
    attachment = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    
    if (CFDictionaryGetValueIfPresent(attachment,
                                      kCMSampleAttachmentKey_NotSync,
                                      (const void **)&not_sync))
    {
        return !CFBooleanGetValue(not_sync);
    } else {
        return true;
    }
}


static OSStatus getStartCodeSize(CMSampleBufferRef buffer, int *length) {
    
    
    CMVideoFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(buffer);
    if (!fmt) {
        return 1;
    }
    int size;
    OSStatus status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt,
                                                                         0,
                                                                         NULL,
                                                                         NULL,
                                                                         NULL,
                                                                         &size);
    *length = size;
    return status;
}



static void output_callback(void * outputCallbackRefCon,
                            void * sourceFrameRefCon,
                            OSStatus status,
                            VTEncodeInfoFlags infoFlags,
                            CMSampleBufferRef sampleBuffer) {
    
    if (status) return;
    if (!sampleBuffer) return;
    bool iskey = isKeyFrame(sampleBuffer);
    int startCodeSize = 0;
    OSStatus ret = getStartCodeSize(sampleBuffer, &startCodeSize);
    if (ret || startCodeSize > 4) return;
    
    int naluCount = 0;
    ret = count_nalus(startCodeSize, sampleBuffer, &naluCount);
    if (ret) return;
     
    bool addHeader = false;
    int headeLength = 0;
    if (iskey) {
        //[startcode + sps] + [startcoce + pps] + [startcode + nalu] + [startcode + nalu] + ...
        addHeader = true;
        ret = getParamsLength(sampleBuffer, &headeLength);
    } else {
        //[startcode + nalu] + [startcode + nalu] + ...
    }
    
    int sampleLength = (int)CMSampleBufferGetTotalSampleSize(sampleBuffer);
    int totalLength = headeLength + sampleLength + ((int)sizeof(start_code) - startCodeSize) * naluCount;
    
    int offset = 0;
    
    uint8_t *data = new uint8_t[totalLength];
    
    if (addHeader) {
        //copy sps, pps
        copyParams(sampleBuffer, data);
        offset += headeLength;
    }
    //copy nalu
    copy_nalus(startCodeSize, sampleBuffer, data + offset);
    
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    TSHardwareEncoder *encoder = (__bridge TSHardwareEncoder *)outputCallbackRefCon;
    [encoder.delegate encoder:encoder gotEncoderData:data length:totalLength iskey: iskey timestamp:pts.value];
    delete [] data;
}


@interface TSHardwareEncoder ()
{
    VTCompressionSessionRef _session;
    int _pts;
    
    int _width;
    int _height;
    dispatch_queue_t _encodeQueue;
}


@end


@implementation TSHardwareEncoder

- (instancetype)init
{
    
    if (self = [super init]) {
        _encodeQueue = dispatch_queue_create("cn.toosee.videotoolbox.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
    
}


- (void)dealloc {
    if (_session) {
        VTCompressionSessionCompleteFrames(_session, kCMTimeIndefinite);
        VTCompressionSessionInvalidate(_session);
        CFRelease(_session);
    }
}


- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(int64_t)timestamp {
    
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(_encodeQueue, ^{
        [self _encodePixelBuffer:pixelBuffer timestamp:timestamp];
        CVPixelBufferRelease(pixelBuffer);
    });
}



- (void)_encodePixelBuffer:(CVPixelBufferRef)pixelBuffer timestamp:(int64_t)timestamp {
    if (!pixelBuffer) return;
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    if (!_session) {
        OSStatus ret = [self setupSession:width height:height];
        _pts = 0;
        if (ret) {
            return;
        }
    } else {
        
        if (width != _width || height != _height) {
            VTCompressionSessionCompleteFrames(_session, kCMTimeIndefinite);
            VTCompressionSessionInvalidate(_session);
            CFRelease(_session);
            _session = nil;
            OSStatus ret = [self setupSession:width height:height];
            _width = width;
            _height = height;
            _pts = 0;
            if (ret) {
                return;
            }
        }
        
    }
    _pts++;
    CMTime time = CMTimeMake(timestamp, 1000);
    VTEncodeInfoFlags flags;
    OSStatus status =  VTCompressionSessionEncodeFrame(_session, pixelBuffer, time, kCMTimeInvalid, NULL, (__bridge void *)self, &flags);
    if (status) {
        return;
    }
}

- (OSStatus)setupSession:(int)width height:(int)height {
    OSStatus status = VTCompressionSessionCreate(NULL,
                                              width,
                                              height,
                                              kCMVideoCodecType_H264,
                                              NULL,
                                              NULL,
                                              NULL,
                                              output_callback,
                                              (__bridge void * _Nullable)(self),
                                              &_session);
    
    if (status) return status;
    const int fps = 15;
    int bit_rate = ts264::getLiveBitrate(width, height, fps);
    CFNumberRef bit_rate_num = CFNumberCreate(kCFAllocatorDefault,
                                   kCFNumberSInt32Type,
                                   &bit_rate);
    //bitrate
    status = VTSessionSetProperty(_session,
                                         kVTCompressionPropertyKey_AverageBitRate,
                                         bit_rate_num);
    
    //profile level
    status = VTSessionSetProperty(_session,
                                  kVTCompressionPropertyKey_ProfileLevel,
                                  kVTProfileLevel_H264_High_AutoLevel);
    
    if (status) {
        return status;
    }
    //gop
    int gop_size = 2*fps;
    CFNumberRef interval = CFNumberCreate(kCFAllocatorDefault,
                                          kCFNumberIntType,
                                          &gop_size);
    status = VTSessionSetProperty(_session,
                                  kVTCompressionPropertyKey_MaxKeyFrameInterval,
                                  interval);
    if (status) {
        return status;
    }
    //不允许b帧
    status = VTSessionSetProperty(_session,
                                       kVTCompressionPropertyKey_AllowFrameReordering,
                                       kCFBooleanFalse);
    if (status) {
        return status;
    }
    
    //实时编码
    status = VTSessionSetProperty(_session,
                                  kVTCompressionPropertyKey_RealTime,
                                  kCFBooleanTrue);
    
    if (status) {
        return status;
    }
    
    //cabac
     status = VTSessionSetProperty(_session,
                                   kVTCompressionPropertyKey_H264EntropyMode,
                                   kVTH264EntropyMode_CABAC);
    if (status) {
        NSLog(@"set Entropy failed, code = %d", status);
        return status;
    }
    
    //prepare encode
    status = VTCompressionSessionPrepareToEncodeFrames(_session);
    if (status) {
        return status;
    }
    return 0;
}


@end
