//
//  ViewController.m
//  V&A
//
//  Created by 梁立保 on 2017/11/7.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import "ViewController.h"
#import "V&ACapture/VACapture.h"
#import "UIView+VLAdditions.h"
#import "H264Decoder.h"
#import "AAPLEAGLLayer.h"
#import "VAAACDecoder.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *startEncodeButton;
@property (weak, nonatomic) IBOutlet UIButton *stopEncodeButton;
@property (weak, nonatomic) IBOutlet UIButton *changeCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *decoderButton;
@property (nonatomic, strong) VACapture *vaCapture;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.vaCapture = [VACapture new];
	self.stopEncodeButton.hidden = YES;
	self.changeCameraButton.hidden = YES;
	self.decoderButton.hidden = [self decoderButtonHidden];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.startEncodeButton.height = 30;
    self.stopEncodeButton.height = 30;
    self.changeCameraButton.height = 30;
    self.decoderButton.height = 30;
}

- (IBAction)startEncodeAction:(id)sender {
	[self.vaCapture startCapturing:self.view];
	self.startEncodeButton.hidden = YES;
	self.stopEncodeButton.hidden = NO;
	self.changeCameraButton.hidden = NO;
	self.decoderButton.hidden = YES;
}

- (IBAction)stopEncodeAction:(id)sender {
	[self.vaCapture stopCapturing];
	self.startEncodeButton.hidden = NO;
	self.stopEncodeButton.hidden = YES;
	self.changeCameraButton.hidden = YES;
	self.decoderButton.hidden = [self decoderButtonHidden];
}
- (IBAction)changeCameraAction:(id)sender {
	[self.vaCapture swapFrontAndBackCameras];
}

- (IBAction)decoderAction:(id)sender {
	AAPLEAGLLayer *layer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.bounds];
	[self.view.layer insertSublayer:layer atIndex:0];
	__weak typeof(AAPLEAGLLayer *) weakSelf = layer;
	// TODO:H264Decoder启动后只能反复解码4次,第5次就会初始化session失败-12913
	[[H264Decoder new] play:^(CVImageBufferRef imageBuffer, BOOL isOver, H264Decoder *deEncoder) {
		weakSelf.pixelBuffer = imageBuffer;
		if (isOver) {
			[weakSelf removeFromSuperlayer];
			deEncoder = nil;
		}
		
	}];
    
    [[VAAACDecoder new] play];
}

- (BOOL)decoderButtonHidden {
	NSString *filePath = [sourceVideoName cacheDir];
	return (filePath == nil);
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


@end
