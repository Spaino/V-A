//
//  VAAACEncoder.h
//  V&A
//
//  Created by 梁立保 on 2017/11/15.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface VAAACEncoder : NSObject
@property(nonatomic) dispatch_queue_t encoderQueue; // 编码队列
@property(nonatomic) dispatch_queue_t callBackQueue; // 回调队列
// 编码sampleBuffer
- (void)encodeSampleBuffer:(CMSampleBufferRef )sampleBuffer completionBlock:(void(^)(NSData *encodedData, NSError *error))completionBlock;
@end
