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
typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface VACapture() <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) H264Encoder *encoder;
@property (nonatomic, strong) dispatch_queue_t mCaptureQueue;
@property (nonatomic, strong) dispatch_queue_t mEncodeQueue;
@property (nonatomic, strong) dispatch_queue_t mainQueue;

//是否在对焦
@property (assign, nonatomic) BOOL isFocus;
@property (nonatomic, strong) UIImageView *focusCursor;
@property (nonatomic, assign) BOOL voluntaryOpenTorch; // 是否自动开启过手电筒
@property (nonatomic, assign) BOOL manualCloseTorch; // 是否自动开启的手电筒的情况下手动关闭了.
@property (nonatomic, strong) UIButton *torchStateButton;
@end

@implementation VACapture
- (instancetype)init {
	if(self = [super init]) {
		self.mCaptureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		self.mEncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		self.mainQueue = dispatch_get_main_queue();
	}
	return self;
}

//01.开始捕捉
- (void)startCapturing:(UIView *)preView {
	// 没有摄像头,直接return
	if (![self isCameraAvailable]) {
		return;
	}
	// -3.注册通知
	[self setupObservers];
	// -2.给容器View添加Tap手势
	UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
	[preView addGestureRecognizer:tapGesture];
	
	// -1.添加聚焦的imageView
	UIImageView *focusCursor = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Group@3x.png"]];
	focusCursor.alpha = 0;
	[preView addSubview:focusCursor];
	self.focusCursor = focusCursor;
	
	UIButton *torchStateButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[torchStateButton setTitle:@"开启手电筒" forState:UIControlStateNormal];
	[torchStateButton setTitle:@"开启手电筒" forState:UIControlStateHighlighted];
	[torchStateButton setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
	[torchStateButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
	torchStateButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
	torchStateButton.frame = CGRectMake(preView.bounds.size.width - 150, 50, 100, 30);
	[preView addSubview:torchStateButton];
	self.torchStateButton = torchStateButton;
	self.torchStateButton.selected = NO;
	[torchStateButton addTarget:self action:@selector(torchStateButtonAction:) forControlEvents:UIControlEventTouchUpInside];
	
	// 0.准备编码
	self.encoder = [H264Encoder new];
	[self.encoder prepareEncodeWithWidth:1080 height:1920];
	
	// 1.创建session
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	session.sessionPreset = AVCaptureSessionPreset1920x1080;
	self.session = session;
	
	// 2.设置视频的输入
	// AVCaptureDevicePosition: 前置/后置
	AVCaptureDevice *device;
	NSError *error;
	// 默认是后置摄像头,如果后置摄像头不可用,直接return
	if (![self isRearCameraAvailable]) {
		return;
	}
	
	if (@available(iOS 10.0, *)) {
		device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];

	} else {

		device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	}
	self.device = device;
	
	AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
	[session addInput:input];
	
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
	
	// 5.开始采集
	[session startRunning];

	NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
	//会话出错
	[notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:session];

}

/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
	NSLog(@"会话发生错误.");
}


//02.结束录制
- (void)stopCapturing {
	
	self.manualCloseTorch = NO;
	self.voluntaryOpenTorch = NO;
	[self.previewLayer removeFromSuperlayer];
	[self.focusCursor removeFromSuperview];
	self.focusCursor = nil;
	[self.torchStateButton removeFromSuperview];
	self.torchStateButton = nil;
	
	__weak typeof(self) weakSelf = self;
	dispatch_async(self.mCaptureQueue, ^{
			if ([weakSelf.device lockForConfiguration:nil]) {
				[weakSelf.device setTorchMode:AVCaptureTorchModeOff];
				[weakSelf.device unlockForConfiguration];
			}
			
		
		[weakSelf.session stopRunning];
		weakSelf.device = nil;
		weakSelf.session = nil;
	});
	
	self.previewLayer = nil;
}

//03.实现代理方法
// 如果出现丢帧
- (void)captureOutput: (AVCaptureOutput *)captureOutput didDropSampleBuffer: (CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	
}


// 采集到视频帧画面
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer: (CMSampleBufferRef)sampleBuffer fromConnection: (AVCaptureConnection *)connection {
//	NSLog(@"采集到视频画面");
	//	AVCaptureVideoDataOutput *output = [self.session.outputs firstObject];
	//	AVCaptureConnection *connect = [output.connections firstObject];
	//	NSLog(@"%ld", connect.videoOrientation);

	// 开始编码
	__weak typeof(self) weakSelf = self;
	dispatch_sync(self.mEncodeQueue, ^{
//		typeof(self) strongSelf = weakSelf;
		[weakSelf.encoder encodeFrame:sampleBuffer];
	});
	
	CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary *)metadataDict];
	CFRelease(metadataDict);
	NSDictionary * exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
	float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
	
	if (brightnessValue <= -1 && (self.device.position == AVCaptureDevicePositionBack)) {
		// 判断如果有手动关闭了闪光灯就不再自动开启
		if (self.manualCloseTorch) {
			return;
		}
		
		NSError *error;
		// TODO:还需要判断当从前置摄像头切换来时不能立马开启摄像头..(不然导致捕捉出错,画面暂停)
		
		if ([self.device lockForConfiguration:&error]) {
			// 首先判断是否有闪光灯.
			if (self.device.hasTorch) {
				[self.device setTorchMode:AVCaptureTorchModeOn];
			}
			// 自动根据环境条件开启闪光灯
			self.voluntaryOpenTorch = YES;
			[self.device unlockForConfiguration];
		}
		
					   
		dispatch_async(self.mainQueue, ^{
			[weakSelf.torchStateButton setTitle:@"关闭手电筒" forState:UIControlStateNormal];
			[weakSelf.torchStateButton setTitle:@"关闭手电筒" forState:UIControlStateHighlighted];
			weakSelf.torchStateButton.selected = YES;
		});
	}
	
	NSLog(@"%f", brightnessValue);
	
}

- (void)torchStateButtonAction:(UIButton *)torchStateButton {
	__weak typeof(self) weakSelf = self;
	if (torchStateButton.selected) {
		dispatch_async(self.mCaptureQueue, ^{
			if (weakSelf.voluntaryOpenTorch) {
				weakSelf.manualCloseTorch = YES;
			}
			if ([weakSelf.device lockForConfiguration:nil]) {
				if (weakSelf.device.torchActive) {
					[weakSelf.device setTorchMode:AVCaptureTorchModeOff];
				}
				[weakSelf.device unlockForConfiguration];
			}
		});
		
		[weakSelf.torchStateButton setTitle:@"开启手电筒" forState:UIControlStateNormal];
		[weakSelf.torchStateButton setTitle:@"开启手电筒" forState:UIControlStateHighlighted];
		weakSelf.torchStateButton.selected = NO;
		
	} else {
		
		dispatch_async(self.mCaptureQueue, ^{
			if ([weakSelf.device lockForConfiguration:nil]) {
				if (!weakSelf.device.torchActive) {
					[weakSelf.device setTorchMode:AVCaptureTorchModeOn];
				}
				[weakSelf.device unlockForConfiguration];
			}
		});
		
		[weakSelf.torchStateButton setTitle:@"关闭手电筒" forState:UIControlStateNormal];
		[weakSelf.torchStateButton setTitle:@"关闭手电筒" forState:UIControlStateHighlighted];
		weakSelf.torchStateButton.selected = YES;
	}
}

// 判断设备是否有摄像头
- (BOOL)isCameraAvailable {
	return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

// 前面的摄像头是否可用

- (BOOL)isFrontCameraAvailable {
	return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}

// 后面的摄像头是否可用
- (BOOL)isRearCameraAvailable {
	return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
	
}

- (BOOL)hasMultipleCameras {
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	if (devices != nil && [devices count] > 1) return YES;
	
	return NO;
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position {
	
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	for (AVCaptureDevice *device in devices) {
		
		if (device.position == position) {
			
			return device;
			
		}
	}
	return nil ;
}

- (void)swapFrontAndBackCameras {
	//check for available cameras!
	if (![self hasMultipleCameras]) return;
	
	//assumes session is running
	NSArray *inputs = self.session.inputs; //should only be one value!
	for (AVCaptureDeviceInput *captureDeviceInput in inputs ) {
		
		AVCaptureDevice *device = captureDeviceInput.device;
		
		if ([device hasMediaType:AVMediaTypeVideo]) {
			
			AVCaptureDevicePosition position = device.position;
			
			AVCaptureDevice *newCamera = nil ;
			
			AVCaptureDeviceInput *newInput = nil ;
			// 切换置后置摄像头
			if (position == AVCaptureDevicePositionFront) {
				if (![self isRearCameraAvailable]) {
					return;
				}
				[self changeCaptureAnim:AVCaptureDevicePositionBack];
				newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
				dispatch_async(self.mainQueue, ^{
					self.torchStateButton.hidden = NO;
				});
			// 切换置前置摄像头
			} else {
				if (![self isFrontCameraAvailable]) {
					return;
				}
				[self changeCaptureAnim:AVCaptureDevicePositionFront];
				newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
				dispatch_async(self.mainQueue, ^{
					self.torchStateButton.hidden = YES;
				});
			}
			
			self.device = newCamera;
			
			newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
			AVCaptureVideoDataOutput *currentOutput = [self.session.outputs firstObject];
			
			// beginConfiguration ensures that pending changes are not applied immediately
			[self.session beginConfiguration];
			[self.session removeInput:captureDeviceInput]; // remove current
			[self.session addInput:newInput]; // add new
			
			// 视频输出的方向
			// 注意: 设置方向，必须在将output添加到session之后
			AVCaptureConnection *connection = [currentOutput connectionWithMediaType:AVMediaTypeVideo];
			if (connection.isVideoOrientationSupported) {
				connection.videoOrientation = AVCaptureVideoOrientationPortrait;
			} else {
				NSLog(@"不支持设置方向");
			}

			// Changes take effect once the outermost commitConfiguration is invoked.
			[self.session commitConfiguration];
			break ;
		}
	}
	
}

// 切换摄像头的转场动画
- (void)changeCaptureAnim:(AVCaptureDevicePosition)position {
	//创建转场动画
	CATransition *animation = [CATransition animation];
	// 时长
	animation.duration = 0.5;
	//设置动画的起始点(图片的右下角为0.0点)
	animation.startProgress = 0.0;
	//设置动画的截至点
	animation.endProgress = 1.0;
	animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	animation.type = @"oglFlip";
	
	if (position == AVCaptureDevicePositionFront) {
		animation.subtype = kCATransitionFromRight;
	} else {
		animation.subtype = kCATransitionFromLeft;
	}
	
	[self.previewLayer addAnimation:animation forKey:@"move in"];
	
}

// 注册进入后台/前台通知
- (void)setupObservers {
	NSNotificationCenter *notification = [NSNotificationCenter defaultCenter];
	[notification addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:[UIApplication sharedApplication]];
	[notification addObserver:self selector:@selector(applicationDidEnterFrontground:) name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
}

// 进入后台就暂停视频录制
- (void)applicationDidEnterBackground:(NSNotification *)notification {
	[self.session stopRunning];
}

// 进入前台就继续视频录制
- (void)applicationDidEnterFrontground:(NSNotification *)notification {
	[self.session startRunning];
}

// 点击自动聚焦及曝光.
- (void)tapScreen:(UITapGestureRecognizer *)tapGesture {
	if (self.device.position == AVCaptureDevicePositionFront) {
		self.focusCursor.alpha = 0;
		return;
	}
	if ([self.session isRunning] && self.session.inputs.firstObject) {
		CGPoint point = [tapGesture locationInView:tapGesture.view];
		// 将UI坐标转化为摄像头坐标
		CGPoint cameraPoint= [self.previewLayer captureDevicePointOfInterestForPoint:point];
		[self setFocusCursorWithPoint:point];
		[self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeContinuousAutoExposure atPoint:cameraPoint];
	}
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
- (void)setFocusCursorWithPoint:(CGPoint)point{
	if (!self.isFocus) {
		self.isFocus = YES;
		self.focusCursor.center = point;
		self.focusCursor.transform = CGAffineTransformMakeScale(2.0, 2.0);
		self.focusCursor.alpha = 1.0;
		[UIView animateWithDuration:0.5 animations:^{
			self.focusCursor.transform = CGAffineTransformIdentity;
		} completion:^(BOOL finished) {
			[self performSelector:@selector(onHiddenFocusCurSorAction) withObject:nil afterDelay:0.5];
		}];
	}
}

/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point {
	[self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
		if ([captureDevice isExposureModeSupported:exposureMode]) {
			[captureDevice setExposureMode:exposureMode];
			[captureDevice setExposurePointOfInterest:point];
		}
		if ([captureDevice isFocusModeSupported:focusMode]) {
			[captureDevice setFocusMode:focusMode];
			[captureDevice setFocusPointOfInterest:point];
		}
		// 自动白平衡
		if ([captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
			[captureDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
		}
		
		if ([captureDevice isFlashModeSupported:AVCaptureFlashModeAuto] && [captureDevice isTorchModeSupported:AVCaptureTorchModeAuto]) {
			[captureDevice setFlashMode:AVCaptureFlashModeAuto];
		}

	}];
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange {
	NSError *error;
	// 注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
	if ([self.device lockForConfiguration:&error]) {

		propertyChange(self.device);
		[self.device unlockForConfiguration];
	} else {
		NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
	}
}


- (void)onHiddenFocusCurSorAction {
	self.focusCursor.alpha = 0;
	self.isFocus = NO;
}

@end

