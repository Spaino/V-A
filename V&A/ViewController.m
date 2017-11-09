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
@property (weak, nonatomic) IBOutlet UIButton *startEncodeButton;
@property (weak, nonatomic) IBOutlet UIButton *stopEncodeButton;
@property (nonatomic, strong) VACapture *vaCapture;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.vaCapture = [VACapture new];
	self.stopEncodeButton.hidden = YES;
}
- (IBAction)startEncodeAction:(id)sender {
	[self.vaCapture startCapturing:self.view];
	self.startEncodeButton.hidden = YES;
	self.stopEncodeButton.hidden = NO;
}

- (IBAction)stopEncodeAction:(id)sender {
	[self.vaCapture stopCapturing];
	self.startEncodeButton.hidden = NO;
	self.stopEncodeButton.hidden = YES;
}
- (IBAction)changeCameraAction:(id)sender {
	[self.vaCapture swapFrontAndBackCameras];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


@end
