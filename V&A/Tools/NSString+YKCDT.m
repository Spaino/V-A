//
//  NSString+ZSSCDT.m

//
//  Created by apple on 13/8/6.
//  Copyright (c) 2013年 ZSS. All rights reserved.
//  快速创建沙盒缓存目录,文档mul,临时目录全路径分类

#import "NSString+YKCDT.h"

@implementation NSString (YKCDT)

- (instancetype)cacheDir
{
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    return [dir stringByAppendingPathComponent:[self lastPathComponent]];
}
- (instancetype)docDir
{
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    return [dir stringByAppendingPathComponent:[self lastPathComponent]];
}

- (instancetype)tmpDir
{
    NSString *dir = NSTemporaryDirectory();
    return [dir stringByAppendingPathComponent:[self lastPathComponent]];
}
@end
