//
//  ViewController.m
//  V&A
//
//  Created by 梁立保 on 2017/11/7.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import "ViewController.h"
#import "V&ACapture/VACapture.h"
@interface ViewController ()
@property (nonatomic, strong) VACapture *vaCapture;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.vaCapture = [VACapture new];
}
- (IBAction)startEncodeAction:(id)sender {
	[self.vaCapture startCapturing:self.view];
}

- (IBAction)stopEncodeAction:(id)sender {
	[self.vaCapture stopCapturing];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


@end
