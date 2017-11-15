//
//  H264Deencoder.m
//  V&A
//
//  Created by 梁立保 on 2017/11/10.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import "H264Deencoder.h"
//#import "AAPLEAGLLayer.h"
#import <VideoToolbox/VideoToolbox.h>

const char pStartCode[]= "\x00\x00\x00\x01";

@interface H264Deencoder () {
	// 读取到的数据
	long inputMaxSize;
	long inputSize;
	uint8_t *inputBuffer;
	// 解析的数据
	long packetSize;
	uint8_t *packetBuffer;
	
	long spsSize;
	uint8_t *pSPS;
	
	long ppsSize;
	uint8_t *pPPS;
	VTDecompressionSessionRef decompressionSession;
	CMVideoFormatDescriptionRef formatDescription;
}

@property (nonatomic, weak) CADisplayLink *displayLink;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) dispatch_queue_t queue;
//@property (nonatomic, weak) AAPLEAGLLayer *glLayer;
@property (nonatomic, strong) CVImageBufferRefBlock imageBufferBlock;
@end;

@implementation H264Deencoder
- (instancetype)init {
	if (self = [super init]) {
		// 1.创建CADisplayLink
		CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
		self.displayLink = displayLink;
		self.displayLink.frameInterval = 2;
		[displayLink addToRunLoop: [NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
		[self.displayLink setPaused:YES];
		// 2.创建NSInputStream
		NSString *filePath = [sourceVideoName cacheDir];
		self.inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
		// 3.创建队列
		self.queue = dispatch_get_global_queue(0,0);
		// 4.创建用于渲染的layer
		//		AAPLEAGLLayer *layer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.bounds];
		//		[self.view.layer insertSublayer:layer atIndex:@];
		//		self.glLayer = layer;
	}
	return self;
}

- (void)play:(CVImageBufferRefBlock)imageBufferBlock {
	// 1.初始化一次读取多少数据，以及数据的长度，数据存放在哪里
//	inputMaxSize = 1920 * 1080;
	inputMaxSize = SCREEN_HEIGHT * SCREEN_WIDTH;
	inputSize = 0;
	inputBuffer = malloc(inputMaxSize);
	self.imageBufferBlock = imageBufferBlock;
	
	// 2.打开inputstream
	[self.inputStream open];
	
	// 3.开始读取数据
	[self.displayLink setPaused:NO];
}


#pragma mark- 初始化VTDecompressionSession
- (void)initDecompressSession {
	// 1.创建CMVideoFormatDescriptionRef
	const uint8_t *pParamSet[2] = {pSPS, pPPS};
	const size_t  pParamSizes[2] = {spsSize, ppsSize};
	
	CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, pParamSet, pParamSizes, 4, &formatDescription);
	// 2.创建VTVTDecompressionSessionRef YUV(YCrCb)/R
	// 4:4:4=12
	// three plane
	// 4:1:1= 6 YUV420 two plane
	NSDictionary *attrs = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
	VTDecompressionOutputCallbackRecord callbackRecord;
	callbackRecord.decompressionOutputCallback = decodecallback;
	callbackRecord.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
	// 只能反复初始化解码4次,第5次就会初始化session失败-12913
	OSStatus status = VTDecompressionSessionCreate(NULL, formatDescription, NULL, (__bridge CFDictionaryRef)attrs, &callbackRecord, &decompressionSession);
	
	NSLog(@"%d", (int)status);
}

// 解码成功的回调函数 
void decodecallback(void * CM_NULLABLE decompressionOutputRefCon, void * CM_NULLABLE sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CM_NULLABLE CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
	// 展示解码的视频
	
	H264Deencoder *mySelf = (__bridge H264Deencoder *)sourceFrameRefCon;
	__weak typeof(mySelf) weakSelf = mySelf;
//	dispatch_async(dispatch_get_main_queue(), ^{
		if (mySelf.imageBufferBlock) {
			weakSelf.imageBufferBlock(imageBuffer, NO, nil);
		}
//	});
	//	vc.glLayer.pixelBuffer = imageBuffer;
}


#pragma mark- 开始读取数据
- (void)updateFrame {
	dispatch_sync(_queue,^{
		// 1.读取数据
		[self readPacket];
		
		// 2.判断数据的类型
		if (packetSize == 0 && packetBuffer == NULL) {
			[self.displayLink setPaused:YES];
			[self.displayLink invalidate];
			self.displayLink = nil;
			[self.inputStream close];
			self.inputStream = nil;
			VTDecompressionSessionInvalidate(decompressionSession);
			decompressionSession = nil;
			CFRelease(formatDescription);
//			pSPS = nil;
//			pPPS = nil;
//			packetBuffer = nil;
//			inputBuffer = nil;
//			self.queue = nil;
			(void)(inputSize), (void)(inputMaxSize), (void)(packetSize), (void)(spsSize), ppsSize = 0;
			if (self.imageBufferBlock) {
				self.imageBufferBlock(nil, YES, self);
			}
			NSLog(@"数据已经读完了");
			return;
		}
		
		// 3.解码H264大端数数据是在内存中:系统端数据
		uint32_t nalSize = (uint32_t)(packetSize - 4);
		uint32_t *pNAL = (uint32_t *)packetBuffer;
		*pNAL = CFSwapInt32HostToBig(nalSize) ;
		// 4.获取类型SPS: ex27 pps: 8X28 IDR :8X25
		// 00 10 0111
		// 00 011111
		// 00 00 0111== 7
		// 00 10 10 00
		// 前五位: 0x07 SPS  0x08 pps 0x05 : i
		// 00 00 00 0A 27
		int nalType = packetBuffer[4] & 0x1F;
		switch (nalType) {
			case 0x07:
				spsSize = packetSize- 4;
				pSPS = malloc(spsSize);
				memcpy(pSPS, packetBuffer + 4, spsSize);
				break;
			case 0x08:
				ppsSize = packetSize- 4;
				pPPS = malloc(ppsSize);
				memcpy(pPPS, packetBuffer + 4, ppsSize);
				break;
			case 0x05:
				// 1.创建VTDecompressionSessionRef--> sps/pps--> gop
				[self initDecompressSession];
				// 2.解码I帧
				[self decodeFrame];
				break;
			default:
				// 解码B帧或P帧
				[self decodeFrame];
				break;
		}
		
	});
}

#pragma mark- 从文件中读取一个NALU的数据
// AVFrame(编码前的帧数据)/AVPacket(编码后的帧数据)
- (void)readPacket {
	// 1.每次读取的时候，必须保证之前的数据，清除掉
	if (packetSize || packetBuffer) {
		packetSize = 0;
		free(packetBuffer);
		packetBuffer = nil;
	}
	// 2.读取数据
	if (inputSize < inputMaxSize && _inputStream.hasBytesAvailable) {
		inputSize += [self.inputStream read:inputBuffer + inputSize maxLength:inputMaxSize - inputSize];
	}
	// inputSize == inputMaxSize
	// 3.获取解码想要的数据ex 88 08 08 81
	// -1:非正常日:正常
	if (memcmp(inputBuffer, pStartCode, 4) == 0) {
		uint8_t *pStart = inputBuffer + 4;
		uint8_t *pEnd = inputBuffer + inputSize;
		while (pStart != pEnd) {
			if (memcmp(pStart- 3, pStartCode, 4) == 0) {
				// 获取到下一个0x 00 00 00 01
				packetSize = pStart - 3 - inputBuffer;
				// 从inputBuffer中,拷贝数据到，packetBuffer
				packetBuffer = malloc(packetSize);
				memcpy(packetBuffer, inputBuffer, packetSize);
				// 将数据，移动到最前方
				memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize);
				// 改变inputSize的大小
				inputSize -= packetSize;
				break;
			}else {
				pStart++;
			}
		}
	}
}

#pragma mark- 解码数据
- (void)decodeFrame {
	// SPS/PPS CMblockBuffer
	// 1.通过数据创建一个CMblockBuffer
	CMBlockBufferRef blockBuffer;
	CMBlockBufferCreateWithMemoryBlock(NULL, (void *)packetBuffer, packetSize, kCFAllocatorNull, NULL, 0, packetSize, 0, &blockBuffer) ;
	// 2.准备CMSamp1eBufferRef
	size_t sizeArray[] = {packetSize};
	CMSampleBufferRef sampleBuffer;
	CMSampleBufferCreateReady(NULL, blockBuffer, formatDescription, 0, 0, NULL, 0, sizeArray, &sampleBuffer);
	// 3.开始解码操作
	OSStatus status = VTDecompressionSessionDecodeFrame(decompressionSession, sampleBuffer, 0, (__bridge void *_Nullable)(self), NULL);
	if (status == noErr)  {}
}

- (void)dealloc {
	
}
@end

