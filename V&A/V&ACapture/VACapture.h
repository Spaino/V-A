//
//  V&ACapture.h
//  V&A
//
//  Created by 梁立保 on 2017/11/7.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VACapture : NSObject
- (void)startCapturing:(UIView *)preView;
- (void)stopCapturing;
- (void)swapFrontAndBackCameras;
@end
