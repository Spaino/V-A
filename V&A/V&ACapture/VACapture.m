//
//  V&ACapture.m
//  V&A
//
//  Created by 梁立保 on 2017/11/7.
//  Copyright © 2017年 梁立保. All rights reserved.
//
//1.自定义虚拟类封装视频捕捉

#import <UIKit/UIKit.h>
#import "VACapture.h"
#import "H264Encoder.h"
#import <AVFoundation/AVFoundation.h>

@interface VACapture() <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) H264Encoder *encoder;
@property (nonatomic, strong) dispatch_queue_t mCaptureQueue;
@property (nonatomic, strong) dispatch_queue_t mEncodeQueue;
@end

@implementation VACapture
- (instancetype)init {
	if(self = [super init]) {
		self.mCaptureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		self.mEncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	}
	return self;
}
//01.开始捕捉
- (void)startCapturing:(UIView *)preView {
	// 0.准备编码
	self.encoder = [H264Encoder new];
	[self.encoder prepareEncodeWithWidth:720 height:1280];
	
	// 1.创建session
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	session.sessionPreset = AVCaptureSessionPreset1280x720;
	self.session = session;
	
	// 2.设置视频的输入
	// AVCaptureDevicePosition: 前置/后置
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	NSError *error;
	AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
	[session addInput :input] ;
	
	// 3.设置视频的输出
	AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
	[output setSampleBufferDelegate:self queue:self.mCaptureQueue];
	[output setAlwaysDiscardsLateVideoFrames:YES];
	
	// 设置录制视频的颜色空间为YUV420P
	output.videoSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange )};
	[session addOutput:output];
	
	// 视频输出的方向
	
	// 注意: 设置方向，必须在将output添加到session之后
	AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
	if (connection.isVideoOrientationSupported) {
		connection.videoOrientation = AVCaptureVideoOrientationPortrait;
	} else {
		NSLog(@"不支持设置方向");
	}
	
	// 4.添加预览图层
	AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	layer.frame = preView.bounds;
	[preView.layer insertSublayer:layer atIndex:0];
	self.previewLayer = layer;
	//5.开始采集
	[session startRunning];
}


//02.结束录制
- (void)stopCapturing {
	[self.previewLayer removeFromSuperlayer];
	[self.session stopRunning];
}

//03.实现代理方法
// 如果出现丢帧
- (void)captureOutput: (AVCaptureOutput *)captureOutput didDropSampleBuffer: (CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	
}


// 采集到视频帧画面
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer: (CMSampleBufferRef)sampleBuffer fromConnection: (AVCaptureConnection *)connection {
	NSLog(@"采集到视频画面");
	// 开始编码
	__weak typeof(self) weakSelf = self;
	dispatch_sync(self.mEncodeQueue, ^{
//		typeof(self) strongSelf = weakSelf;
		[weakSelf.encoder encodeFrame:sampleBuffer];
	});
}

@end

