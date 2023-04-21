//
//  NXFrame.h
//  NXLive
//
//  Created by Neuxnet on 2020/11/18.
//  Copyright © 2020 wangran. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NXFrame : NSObject
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, strong) NSData *data;
/// flv或者rtmp包头
@property (nonatomic, strong) NSData *header;
@end

NS_ASSUME_NONNULL_END
