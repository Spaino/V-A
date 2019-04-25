//
//  VAAACEncoder.m
//  V&A
//
//  Created by 梁立保 on 2017/11/15.
//  Copyright © 2017年 梁立保. All rights reserved.
//

#import "VAAACEncoder.h"
#import "NSString+CDT.h"

@interface VAAACEncoder()
@property (nonatomic) AudioConverterRef audioConverter; // 音频转换器
@property (nonatomic ) uint8_t *aacBuffer; // AAC数据
@property (nonatomic) NSUInteger aacBufferSize; // AAC数抓大小
@property (nonatomic) char *pcmBuffer; // pcm 数据
@property (nonatomic) size_t pcmBufferSize;//PCM 数据大小
@property (nonatomic, strong) NSFileHandle *audioFileHandle; // 文件操作句柄
@end


@implementation VAAACEncoder

- (void)dealloc{
	AudioConverterDispose(_audioConverter);
	free(_aacBuffer);
	[self.audioFileHandle closeFile];
	self.audioFileHandle = NULL;
}

- (instancetype)init {
	if (self = [super init]) {
		//创建编码队列
//		_encoderQueue = dispatch_queue_create("AAC Encoder Queue", DISPATCH_QUEUE_SERIAL) ;
		_callBackQueue = dispatch_queue_create("AAC Encoder Callback Queue",
											   DISPATCH_QUEUE_SERIAL) ;
		
		// 音频编码文件
		NSString *audioFile = [sourceAudioName cacheDir];
		[[NSFileManager defaultManager] removeItemAtPath:audioFile error:nil];
		[[NSFileManager defaultManager] createFileAtPath:audioFile contents:nil attributes:nil];
		_audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:audioFile];

		_audioConverter = NULL;
		_pcmBufferSize = 0;
		_pcmBuffer = NULL;
		_aacBufferSize = 1024;
		_aacBuffer= malloc(_aacBufferSize *sizeof(uint8_t));
		memset(_aacBuffer, 0, _aacBufferSize);
	}
	return self;
}

- (void)encodeSampleBuffer:(CMSampleBufferRef )sampleBuffer completionBlock: (void(^)(NSData *encodedData, NSError *error))completionBlock {
	// 1.将OC对象转换为Core Foundation对象
	CFRetain(sampleBuffer) ;
//	dispatch_async(_encoderQueue,^{
		// 1.要配置编码参数
		if (!_audioConverter) {
			// 配置编码参数，生成编码器
			[self setupEncoderFromSampleBuffer:sampleBuffer];
		}
		// 2.通过CMSampleBufferGetDataPointer 获取CMBlockBuffer
		CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBuffer);
		CFRetain(blockBufferRef) ;
		// 通过CMBlockBufferGetDataPointer 获取的_pcmBuffersize 和_pcmBuffer指针
		OSStatus status = CMBlockBufferGetDataPointer(blockBufferRef, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
		
		NSError *error = nil;
		if (status != kCMBlockBufferNoErr) {
			[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
			return;
		}
		// 设置_aacBuffer 为 0
		memset(_aacBuffer, 0, _aacBufferSize);
		// 设置缓冲列表
		AudioBufferList outAudioBufferList = {0};
		// 缓冲列表解码器个数
		outAudioBufferList.mNumberBuffers= 1;
		// 缓冲列表通道个数
		outAudioBufferList.mBuffers[0].mNumberChannels = 1;
		// 缓冲列表解析数据大小
		outAudioBufferList.mBuffers[0].mDataByteSize = (int)_aacBufferSize;
		outAudioBufferList.mBuffers[0].mData = _aacBuffer;
		
		AudioStreamPacketDescription *outPacketDescrioption = NULL;
		UInt32 inOutputDataPacketSize = 1;
		/**
		 参数1: 传入_audioConverter 引用
		 参数2:
		 用户自己实现的编码数据的callback方法
		 参数3: 获取的数据
		 参数4: 输出数据的长度
		 参数5: 输出的数据
		 参数6: 输出数据的描述
		 */
		
		status = AudioConverterFillComplexBuffer(_audioConverter, inInputDataProc, (__bridge void *)(self), &inOutputDataPacketSize, &outAudioBufferList, outPacketDescrioption );
		
		// 编码完成后
		NSData *data = nil;
		if (status ==0 ){
			// 获取缓冲区的原始AAC数据
			NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
			// 获取ADTS头
			NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
			// 创建可变data
			NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
			// 拼接rawAAC
			[fullData appendData:rawAAC];
			data = fullData;
		} else {
			error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
									userInfo:nil];
			return;
		}
		
		// 写入文件.
		[self.audioFileHandle writeData:data];
		
		if (completionBlock) {
			dispatch_async(_callBackQueue,^{
				completionBlock(data, error);
			});
		}
		// 释放
		CFRelease(sampleBuffer);
		CFRelease(blockBufferRef);
//	});
}

/**
 Add ADTS header at the beginning of each and every AAC packet.
 This is needed as MediaCodec encoder generates a packet of raw
 AAC data.
 Note the packetLen must count in the ADTS header itself.
 注意: packetLen 必须在ADTS头身计算
 See:  http://wiki.multimedia.cx/index.php?title=ADTS
 Also: http:l/wiki.multimedia.cx/index.php?title=MPEG-4Audio#
 Channel_Configurations
 */
- (NSData *)adtsDataForPacketLength:(NSUInteger)packetLength {
	int adtsLength = 7;
	char *packet = malloc(sizeof(char) *adtsLength);
	int profile = 2;
	int freqIdx = 4;
	int chanCfg= 1;
	NSUInteger fullLength = adtsLength + packetLength;
	packet[0] = (char)0xFF;
	packet[1] = (char)0xF9;
	packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) + (chanCfg>>2) );
	packet[3] = (char)(( (chanCfg&3)<<6) + (fullLength>>11)) ;
	packet[4] = (char)((fullLength&0x7FF) >> 3) ;
	packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
	packet[6] = (char)0xFC;
	NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES] ;
	return data;
}

// 设置编码参数
- (void)setupEncoderFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
	// 获取原音频声音格式设置
	AudioStreamBasicDescription inAudioStreamDecription = *CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer));
//	CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer));
	
	// 设置输出音频描述文件
	AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
	// 音频流码率
	outAudioStreamBasicDescription.mSampleRate = inAudioStreamDecription.mSampleRate;
	// 设置编码格式
	outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
	// 无损编码 0无损 
	outAudioStreamBasicDescription.mFormatFlags = kAudioFormatFlagIsAlignedHigh;
	// 每个mBytesPerPacket 的大小。0代表动态大小有outAudioStreamBasicDescription 去确定每个
	// packet的大小
	outAudioStreamBasicDescription.mBytesPerPacket = 0;
	// 每个packet帧数设置一个较大的固定值; 1024-AAC
	outAudioStreamBasicDescription.mFramesPerPacket = 1024;
	// 每一帧有多大。 0代表动态大小
	outAudioStreamBasicDescription.mBytesPerFrame = 0;
	// 声道数
	outAudioStreamBasicDescription.mChannelsPerFrame = 1;
	// 压缩格式
	outAudioStreamBasicDescription.mBitsPerChannel = 0;
	// 对齐方式
	outAudioStreamBasicDescription.mReserved = 0;
	
	AudioClassDescription *decription= [self getAudioClassDesicriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleHardwareAudioCodecManufacturer];
	/**
	 参数1: 传入的源音频格式
	 参数2: 目标音频格式
	 参数3: 传入的音频编码器的个数
	 参数4: 传入的音频编码的器的描述
	 参数5: 引用
	 */
	OSStatus status = AudioConverterNewSpecific(&inAudioStreamDecription, &outAudioStreamBasicDescription, 1, decription, &_audioConverter);
	if (status != 0) {
		NSLog(@"setup conver:%d", (int)status);
	}
}

// 获取编码器
- (AudioClassDescription *)getAudioClassDesicriptionWithType:(UInt32)type fromManufacturer: (UInt32)manufacturer {
	// 选择AAC编码器
	static AudioClassDescription desc;
	// 获取满足要求AAC编码的总大小
	UInt32 encoderSpecifier = type;
	OSStatus status;
	UInt32 size;
	/**
	 参数1: 编码ID,编码、解码
	 参数2: 编码说明大小
	 参数3: 编码说明
	 参数4: 属性当前值的大小
	 */
	status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size);
	
	// 用于计算AAC编码器的个数
	unsigned int count = size / sizeof(AudioClassDescription);
	// 创建一个包含count 个的编码器数组
	AudioClassDescription descripition[count];
	// 将编码数组信息写入到descripition
	status = AudioFormatGetProperty(kAudioFormatProperty_Encoders,sizeof(encoderSpecifier), &encoderSpecifier, &size, descripition);
	for(unsigned int i = 0; i < count; i++) {
		if (type == descripition[i].mSubType && manufacturer == descripition[i].mManufacturer) {
			// 拷贝编码器到desc
			memcpy(&desc, &(descripition[i]), sizeof(desc)) ;
			return &desc;
		}
	}
	return nil;
	
}

// 填充PCM到缓冲区
OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
	// 编码器
	VAAACEncoder *encoder = (__bridge VAAACEncoder *)(inUserData);
	//
	UInt32 requestPackets = *ioNumberDataPackets;
	// 将io中的PCM填充到缓冲区
	size_t copiedSamples = [encoder copyPCMSamplesIntoBuffer:ioData];
	if (copiedSamples < requestPackets) {
		*ioNumberDataPackets = 0;
		return -1;
	}
	*ioNumberDataPackets = 1;
	return noErr;
}

/**pcm->缓冲区*/
- (size_t)copyPCMSamplesIntoBuffer:(AudioBufferList *)ioData {
	// 获取PCM大小
	size_t originalBufferSize =_pcmBufferSize;
	if (!originalBufferSize) {
		return 0;
	}
	ioData->mBuffers[0].mData = _pcmBuffer;
	ioData->mBuffers[0].mDataByteSize = (int)_pcmBufferSize;
	// 清空
	_pcmBuffer = NULL;
	_pcmBufferSize = 0;
	return originalBufferSize;
}

@end

