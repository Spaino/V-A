//
//  VAHud.m
//  V&A
//
//  Created by 梁立保 on 2017/11/9.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import "VAHud.h"
#import "UIView+VLAdditions.h"
@interface VAHud ()
@property (nonatomic, strong) UILabel *messageLabel;

@end

@implementation VAHud
- (instancetype)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		self.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - 200) /2, ([UIScreen mainScreen].bounds.size.height - 200) /2, 200, 200);
		self.backgroundColor = [UIColor blackColor];
		self.alpha = 0.6;
		[self setupSubviews];
	}
	return self;
}

- (void)setupSubviews {
	_messageLabel = [UILabel new];
	_messageLabel.numberOfLines = 0;
	_messageLabel.font = [UIFont systemFontOfSize:21];
	_messageLabel.textColor = [UIColor whiteColor];
	[self addSubview:_messageLabel];
}

+ (void)showMessage:(NSString *)message ToView:(UIView *)parView {

}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
