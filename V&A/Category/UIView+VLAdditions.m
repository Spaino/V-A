

#import "UIView+VLAdditions.h"

@implementation UIView (VLAdditions)

- (void)setX:(CGFloat)x {
    CGRect frame = CGRectMake(x, self.y, self.width, self.height);
    self.frame = frame;
}

- (CGFloat)x {
    return self.origin.x;
}

- (void)setY:(CGFloat)y {
    CGRect frame = CGRectMake(self.x, y, self.width, self.height);
    self.frame = frame;
}

- (CGFloat)y {
    return self.origin.y;
}

- (void)setWidth:(CGFloat)width {
    CGRect frame = CGRectMake(self.x, self.y, width, self.height);
    self.frame = frame;
}

- (CGFloat)width {
    return self.size.width;
}

- (void)setHeight:(CGFloat)height {
    CGRect frame = CGRectMake(self.x, self.y, self.width, height);
    self.frame = frame;
}

- (CGFloat)height {
    return self.size.height;
}

- (void)setSize:(CGSize)size {
    self.width = size.width;
    self.height = size.height;
}

- (CGSize)size {
    return self.frame.size;
}

- (void)setOrigin:(CGPoint)origin {
    self.x = origin.x;
    self.y = origin.y;
}

- (CGPoint)origin {
    return self.frame.origin;
}

- (void)setTop:(CGFloat)top {
    self.y = top;
}

- (CGFloat)top {
    return self.y;
}

- (void)setBottom:(CGFloat)bottom {
    self.y = bottom - self.height;
}

- (CGFloat)bottom {
    return self.y + self.height;
}

- (void)setLeft:(CGFloat)left {
    self.x = left;
}

- (CGFloat)left {
    return self.x;
}

- (void)setRight:(CGFloat)right {
    self.x = right - self.width;
}

- (CGFloat)right {
    return self.x + self.width;
}

- (CGFloat)centerX {
	return self.center.x;
}

-(void)setCenterX:(CGFloat)centerX {
	CGPoint center = self.center;
	center.x = centerX;
	self.center = center;
}

- (CGFloat)centerY{
	return self.center.y;
}

- (void)setCenterY:(CGFloat)centerY {
	CGPoint center = self.center;
	center.y = centerY;
	self.center = center;
}


/**
 *  判断一个控件是否与主窗口重叠
 * [self convertRect:self.bounds toView:nil] nil代表主窗口
 */
- (BOOL)yk_intersectWithView:(UIView*)view
{
	if (view == nil) view = [UIApplication sharedApplication].keyWindow;
	
	CGRect rect1 = [self convertRect:self.bounds toView:nil];
	
	CGRect rect2 = [view convertRect:view.bounds toView:nil];
	
	return CGRectIntersectsRect(rect1, rect2);
	
}


@end
