//
//  NSString+ZSSCDT.h

//
//  Created by apple on 13/8/6.
//  快速创建沙盒缓存目录,文档mul,临时目录全路径分类
//  Copyright (c) 2013年 ZSS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (CDT)

/**
 *  生成缓存目录全路径
 */
- (instancetype)cacheDir;
/**
 *  生成文档目录全路径
 */
- (instancetype)docDir;
/**
 *  生成临时目录全路径
 */
- (instancetype)tmpDir;
@end
