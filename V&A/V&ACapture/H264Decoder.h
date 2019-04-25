//
//  H264Decoder.h
//  V&A
//
//  Created by 梁立保 on 2017/11/10.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSString+CDT.h"
@class H264Decoder;
typedef void (^CVImageBufferRefBlock)(CVImageBufferRef imageBuffer, BOOL isOver, H264Decoder *deEncoder);
@interface H264Decoder : NSObject
- (void)play:(CVImageBufferRefBlock)imageBufferBlock;
@end
