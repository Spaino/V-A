

#import <UIKit/UIKit.h>

@interface UIView (VLAdditions)

@property(nonatomic) CGFloat x;
@property(nonatomic) CGFloat y;
@property(nonatomic) CGFloat width;
@property(nonatomic) CGFloat height;
@property(nonatomic) CGSize size;
@property(nonatomic) CGPoint origin;
@property(nonatomic) CGFloat top;
@property(nonatomic) CGFloat bottom;
@property(nonatomic) CGFloat left;
@property(nonatomic) CGFloat right;
@property (nonatomic) CGFloat centerX;
@property (nonatomic) CGFloat centerY;
- (BOOL)yk_intersectWithView:(UIView*)view;
@end
