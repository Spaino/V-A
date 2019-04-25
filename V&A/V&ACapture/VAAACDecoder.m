//
//  VAAACDecoder.m
//  V&A
//
//  Created by lianglibao on 2019/4/23.
//  Copyright © 2019 梁立保. All rights reserved.
//

#import "VAAACDecoder.h"
#import "NSString+CDT.h"
#import <AudioToolbox/AudioToolbox.h>

@interface VAAACDecoder ()
@property (nonatomic, strong) NSURL *audioURL;
@end

@implementation VAAACDecoder
- (instancetype)init {
    if (self = [super init]) {
        self.audioURL = [NSURL URLWithString:[sourceAudioName cacheDir]];
    }
    return self;
}

- (void)play {
    SystemSoundID soundID;
    //Creates a system sound object.
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)(self.audioURL), &soundID);
    //Registers a callback function that is invoked when a specified system sound finishes playing.
    AudioServicesAddSystemSoundCompletion(soundID, NULL, NULL, &playCallback, (__bridge void * _Nullable)(self));
    //    AudioServicesPlayAlertSound(soundID);
    AudioServicesPlaySystemSound(soundID);
    NSLog(@"%u", (unsigned int)soundID);
}

void playCallback() {
    NSLog(@"%s", __func__);
    
}
@end
